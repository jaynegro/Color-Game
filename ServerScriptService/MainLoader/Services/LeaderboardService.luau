--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminConfig = require(ReplicatedStorage.Modules.Shared.Config.AdminConfig)

local LeaderboardService = {}

type Entry = {
	UserId: number,
	Name: string,
	Value: number,
}

local config: any
local network: any
local dataManager: any
local winsStore: OrderedDataStore
local timeStore: OrderedDataStore
local streakStore: OrderedDataStore
local rankStore: OrderedDataStore
local sessionCheckpoints: { [Player]: number } = {}
local latestWins: { [number]: number } = {}
local lastWrittenWins: { [number]: number } = {}
local latestBestStreaks: { [number]: number } = {}
local lastWrittenBestStreaks: { [number]: number } = {}
local latestRanks: { [number]: number } = {}
local lastWrittenRanks: { [number]: number } = {}
local mockWins: { [number]: number } = {}
local mockTime: { [number]: number } = {}
local mockStreaks: { [number]: number } = {}
local mockRanks: { [number]: number } = {}
local nameCache: { [number]: string } = {}
local cachedSnapshot = {
	TopWins = {} :: { Entry },
	TopTime = {} :: { Entry },
	TopStreak = {} :: { Entry },
	TopRank = {} :: { Entry },
	AnimationId = 0,
}
local studioMock = RunService:IsStudio()
local TOP_PLAYER_ATTRIBUTE = "IsLeaderboardTop1"

local function keyFor(userId: number): string
	return `Player_{userId}`
end

local function userIdFromKey(key: string): number?
	return tonumber(string.match(key, "(%d+)$"))
end

local function resolveName(userId: number): string
	local online = Players:GetPlayerByUserId(userId)
	if online then
		nameCache[userId] = online.DisplayName
		return online.DisplayName
	end
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local ok, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local name = if ok then tostring(result) else `User {userId}`
	nameCache[userId] = name
	return name
end

local function isExcluded(userId: number): boolean
	return AdminConfig.IsLeaderboardExcluded(userId)
end

local function writeWin(userId: number, value: number)
	if isExcluded(userId) then
		return
	end
	value = math.max(0, math.floor(value))
	if lastWrittenWins[userId] == value then
		return
	end
	if studioMock then
		mockWins[userId] = value
		lastWrittenWins[userId] = value
		return
	end
	local ok, problem = pcall(winsStore.SetAsync, winsStore, keyFor(userId), value)
	if not ok then
		warn(`[ColorGame] Could not update Top Wins for {userId}: {problem}`)
	else
		lastWrittenWins[userId] = value
	end
end

local function writeBestStreak(userId: number, value: number)
	if isExcluded(userId) then
		return
	end
	value = math.max(0, math.floor(value))
	if lastWrittenBestStreaks[userId] == value then
		return
	end
	if studioMock then
		mockStreaks[userId] = value
		lastWrittenBestStreaks[userId] = value
		return
	end
	local ok, problem = pcall(streakStore.SetAsync, streakStore, keyFor(userId), value)
	if not ok then
		warn(`[ColorGame] Could not update Top Streak for {userId}: {problem}`)
	else
		lastWrittenBestStreaks[userId] = value
	end
end

local function writeRank(userId: number, value: number)
	if isExcluded(userId) then
		return
	end
	value = math.max(0, math.floor(value))
	if lastWrittenRanks[userId] == value then
		return
	end
	if studioMock then
		mockRanks[userId] = value
		lastWrittenRanks[userId] = value
		return
	end
	local ok, problem = pcall(rankStore.SetAsync, rankStore, keyFor(userId), value)
	if not ok then
		warn(`[ColorGame] Could not update Top Rank for {userId}: {problem}`)
	else
		lastWrittenRanks[userId] = value
	end
end

local function commitTime(player: Player)
	if isExcluded(player.UserId) then
		return
	end
	local checkpoint = sessionCheckpoints[player]
	if not checkpoint then
		return
	end
	local elapsed = math.floor(os.clock() - checkpoint)
	if elapsed <= 0 then
		return
	end
	sessionCheckpoints[player] = checkpoint + elapsed
	local userId = player.UserId
	if studioMock then
		mockTime[userId] = (mockTime[userId] or 0) + elapsed
		return
	end
	local ok, problem = pcall(function()
		timeStore:UpdateAsync(keyFor(userId), function(previous)
			return math.max(0, tonumber(previous) or 0) + elapsed
		end)
	end)
	if not ok then
		warn(`[ColorGame] Could not update Top Time for {userId}: {problem}`)
	end
end

local function entriesFromMock(values: { [number]: number }): { Entry }
	local entries = {}
	for userId, value in values do
		if not isExcluded(userId) then
			table.insert(entries, {
				UserId = userId,
				Name = resolveName(userId),
				Value = value,
			})
		end
	end
	table.sort(entries, function(a, b)
		if a.Value ~= b.Value then
			return a.Value > b.Value
		end
		return a.UserId < b.UserId
	end)
	while #entries > config.LeaderboardSize do
		table.remove(entries)
	end
	return entries
end

local function readOrdered(store: OrderedDataStore, label: string): { Entry }
	-- Read full pages so excluded old DataStore entries do not reduce the
	-- visible leaderboard size.
	local pageSize = math.clamp(config.LeaderboardSize, 1, 100)
	local ok, pagesOrProblem = pcall(store.GetSortedAsync, store, false, pageSize)
	if not ok then
		warn(`[ColorGame] Could not read {label}: {pagesOrProblem}`)
		return {}
	end
	local entries = {}
	local pages = pagesOrProblem :: DataStorePages
	while #entries < config.LeaderboardSize do
		for _, item in pages:GetCurrentPage() do
			local userId = userIdFromKey(tostring(item.key))
			if userId and not isExcluded(userId) then
				table.insert(entries, {
					UserId = userId,
					Name = resolveName(userId),
					Value = math.max(0, math.floor(tonumber(item.value) or 0)),
				})
				if #entries >= config.LeaderboardSize then
					break
				end
			end
		end
		if #entries >= config.LeaderboardSize or pages.IsFinished then
			break
		end
		local advanced, problem = pcall(pages.AdvanceToNextPageAsync, pages)
		if not advanced then
			warn(`[ColorGame] Could not advance {label} pages: {problem}`)
			break
		end
	end
	return entries
end

local function isTopPlayer(userId: number): boolean
	for _, entries in { cachedSnapshot.TopWins, cachedSnapshot.TopTime, cachedSnapshot.TopStreak, cachedSnapshot.TopRank } do
		local first = entries[1]
		if first and first.UserId == userId then
			return true
		end
	end
	return false
end

local function updateTopPlayerAttributes()
	for _, player in Players:GetPlayers() do
		player:SetAttribute(TOP_PLAYER_ATTRIBUTE, isTopPlayer(player.UserId))
	end
end

local function refresh()
	for player in sessionCheckpoints do
		commitTime(player)
	end
	for userId, wins in latestWins do
		writeWin(userId, wins)
	end
	for userId, bestStreak in latestBestStreaks do
		writeBestStreak(userId, bestStreak)
	end
	for userId, rank in latestRanks do
		writeRank(userId, rank)
	end

	if studioMock then
		cachedSnapshot.TopWins = entriesFromMock(mockWins)
		cachedSnapshot.TopTime = entriesFromMock(mockTime)
		cachedSnapshot.TopStreak = entriesFromMock(mockStreaks)
		cachedSnapshot.TopRank = entriesFromMock(mockRanks)
	else
		cachedSnapshot.TopWins = readOrdered(winsStore, "Top Wins")
		cachedSnapshot.TopTime = readOrdered(timeStore, "Top Time")
		cachedSnapshot.TopStreak = readOrdered(streakStore, "Top Streak")
		cachedSnapshot.TopRank = readOrdered(rankStore, "Top Rank")
	end
	updateTopPlayerAttributes()
	network.FireAll("LeaderboardSnapshot", cachedSnapshot)
end

function LeaderboardService.Init(gameConfig, networkService, playerDataManager)
	config = gameConfig
	network = networkService
	dataManager = playerDataManager
	winsStore = DataStoreService:GetOrderedDataStore(config.TopWinsStoreName)
	timeStore = DataStoreService:GetOrderedDataStore(config.TopTimeStoreName)
	streakStore = DataStoreService:GetOrderedDataStore(config.TopStreakStoreName)
	rankStore = DataStoreService:GetOrderedDataStore(config.TopRankStoreName)
	cachedSnapshot.AnimationId = config.LeaderboardDummyAnimationId

	local function track(player: Player)
		player:SetAttribute(TOP_PLAYER_ATTRIBUTE, isTopPlayer(player.UserId))
		if isExcluded(player.UserId) then
			return
		end
		sessionCheckpoints[player] = os.clock()
		if studioMock and mockTime[player.UserId] == nil then
			mockTime[player.UserId] = 0
		end
		local wins = dataManager.GetWins(player)
		if wins ~= nil then
			latestWins[player.UserId] = wins
		end
		local bestStreak = dataManager.GetBestStreak(player)
		if bestStreak ~= nil then
			latestBestStreaks[player.UserId] = bestStreak
		end
		local rank = dataManager.GetDuelRank(player)
		if rank ~= nil then
			latestRanks[player.UserId] = rank
		end
	end

	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		commitTime(player)
		sessionCheckpoints[player] = nil
		local wins = latestWins[player.UserId]
		if wins ~= nil then
			writeWin(player.UserId, wins)
		end
		local bestStreak = latestBestStreaks[player.UserId]
		if bestStreak ~= nil then
			writeBestStreak(player.UserId, bestStreak)
		end
		local rank = latestRanks[player.UserId]
		if rank ~= nil then
			writeRank(player.UserId, rank)
		end
	end)
	for _, player in Players:GetPlayers() do
		track(player)
	end

	dataManager.WinsChanged:Connect(function(player: Player, wins: number)
		if isExcluded(player.UserId) then
			return
		end
		latestWins[player.UserId] = wins
		if studioMock then
			mockWins[player.UserId] = wins
		end
	end)
	dataManager.BestStreakChanged:Connect(function(player: Player, bestStreak: number)
		if isExcluded(player.UserId) then
			return
		end
		latestBestStreaks[player.UserId] = bestStreak
		if studioMock then
			mockStreaks[player.UserId] = bestStreak
		end
	end)
	dataManager.DuelRankChanged:Connect(function(player: Player, rank: number)
		if isExcluded(player.UserId) then
			return
		end
		latestRanks[player.UserId] = rank
		if studioMock then
			mockRanks[player.UserId] = rank
		end
	end)

	local leaderboardEvent = network.Event :: RemoteEvent
	leaderboardEvent.OnServerEvent:Connect(function(player, action)
		if action == "LeaderboardReady" then
			network.FireClient(player, "LeaderboardSnapshot", cachedSnapshot)
		end
	end)

	game:BindToClose(function()
		for trackedPlayer in sessionCheckpoints do
			commitTime(trackedPlayer)
		end
		for userId, wins in latestWins do
			writeWin(userId, wins)
		end
		for userId, bestStreak in latestBestStreaks do
			writeBestStreak(userId, bestStreak)
		end
		for userId, rank in latestRanks do
			writeRank(userId, rank)
		end
	end)

	task.spawn(function()
		task.wait(1)
		while true do
			refresh()
			task.wait(config.LeaderboardRefreshInterval)
		end
	end)
end

return LeaderboardService
