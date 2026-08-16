--!strict

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.Library.ProfileStore)
local Replica = require(script.Parent.ReplicaServer)

local DataManager = {}

local TEMPLATE = {
	Wins = 0,
	Streak = 0,
	BestStreak = 0,
	Matches = 0,
	RainbowCredits = 0,
	StreakProtectionCredits = 0,
	ReceiptHistory = {},
}

local profiles: { [Player]: any } = {}
local replicas: { [Player]: any } = {}
local profileStore: any
local playerDataToken: any
local winsChanged = Instance.new("BindableEvent")
local statsChanged = Instance.new("BindableEvent")
local bestStreakChanged = Instance.new("BindableEvent")

DataManager.WinsChanged = winsChanged.Event
DataManager.StatsChanged = statsChanged.Event
DataManager.BestStreakChanged = bestStreakChanged.Event

local function publish(player: Player)
	local profile = profiles[player]
	local replica = replicas[player]
	if profile and replica then
		replica:SetValues({}, {
			Wins = profile.Data.Wins,
			Streak = profile.Data.Streak,
			Matches = profile.Data.Matches,
			RainbowCredits = profile.Data.RainbowCredits,
			StreakProtectionCredits = profile.Data.StreakProtectionCredits,
		})
		statsChanged:Fire(player, profile.Data.Wins, profile.Data.Streak)
	end
end

local function loadPlayer(player: Player)
	local profile = profileStore:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		if player.Parent == Players then
			player:Kick("Your data could not be loaded. Please rejoin.")
		end
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.Data.BestStreak = math.max(profile.Data.BestStreak, profile.Data.Streak)
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		local replica = replicas[player]
		if replica then
			replicas[player] = nil
			replica:Destroy()
		end
		if player.Parent == Players then
			player:Kick("Your data session ended. Please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	winsChanged:Fire(player, profile.Data.Wins)
	statsChanged:Fire(player, profile.Data.Wins, profile.Data.Streak)
	bestStreakChanged:Fire(player, profile.Data.BestStreak)
	local replica = Replica.New({
		Token = playerDataToken,
		Tags = { UserId = player.UserId },
		Data = {
			Wins = profile.Data.Wins,
			Streak = profile.Data.Streak,
			Matches = profile.Data.Matches,
			RainbowCredits = profile.Data.RainbowCredits,
			StreakProtectionCredits = profile.Data.StreakProtectionCredits,
		},
	})
	replicas[player] = replica
	if Replica.ReadyPlayers[player] then
		replica:Subscribe(player)
	end
end

function DataManager.Init(config)
	profileStore = ProfileStore.New(config.DataStoreName, TEMPLATE)
	playerDataToken = Replica.Token("PlayerData")

	Replica.NewReadyPlayer:Connect(function(player: Player)
		local replica = replicas[player]
		if replica then
			replica:Subscribe(player)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadPlayer, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profile:EndSession()
		end
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
end

function DataManager.RecordWin(player: Player, reward: number?): boolean
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false
	end
	profile.Data.Wins += math.max(1, math.floor(reward or 1))
	profile.Data.Streak += 1
	local reachedNewBest = profile.Data.Streak > profile.Data.BestStreak
	if reachedNewBest then
		profile.Data.BestStreak = profile.Data.Streak
	end
	profile.Data.Matches += 1
	publish(player)
	winsChanged:Fire(player, profile.Data.Wins)
	if reachedNewBest then
		bestStreakChanged:Fire(player, profile.Data.BestStreak)
	end
	return true
end

function DataManager.RecordLoss(player: Player): boolean
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false
	end
	profile.Data.Streak = 0
	profile.Data.Matches += 1
	publish(player)
	return true
end

function DataManager.RecordProtectedLoss(player: Player): boolean
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false
	end
	profile.Data.Matches += 1
	publish(player)
	return true
end

function DataManager.GetMatches(player: Player): number
	local profile = profiles[player]
	return if profile then profile.Data.Matches else 0
end

function DataManager.GetWins(player: Player): number?
	local profile = profiles[player]
	return if profile then profile.Data.Wins else nil
end

function DataManager.GetBestStreak(player: Player): number?
	local profile = profiles[player]
	return if profile then profile.Data.BestStreak else nil
end

function DataManager.GetStats(player: Player): (number?, number?)
	local profile = profiles[player]
	if not profile then
		return nil, nil
	end
	return profile.Data.Wins, profile.Data.Streak
end

function DataManager.GetRainbowCredits(player: Player): number
	local profile = profiles[player]
	return if profile then profile.Data.RainbowCredits else 0
end

function DataManager.ConsumeRainbowCredit(player: Player): boolean
	local profile = profiles[player]
	if not profile or not profile:IsActive() or profile.Data.RainbowCredits <= 0 then
		return false
	end
	profile.Data.RainbowCredits -= 1
	publish(player)
	return true
end

function DataManager.ConsumeStreakProtectionCredit(player: Player): boolean
	local profile = profiles[player]
	if not profile or not profile:IsActive() or profile.Data.StreakProtectionCredits <= 0 then
		return false
	end
	profile.Data.StreakProtectionCredits -= 1
	publish(player)
	return true
end

function DataManager.GrantRainbowPurchase(player: Player, purchaseId: string): boolean
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false
	end

	if table.find(profile.Data.ReceiptHistory, purchaseId) then
		return true
	end
	profile.Data.RainbowCredits += 1
	table.insert(profile.Data.ReceiptHistory, purchaseId)
	while #profile.Data.ReceiptHistory > 50 do
		table.remove(profile.Data.ReceiptHistory, 1)
	end
	publish(player)
	profile:Save()
	return true
end

function DataManager.GrantStreakProtectionPurchase(player: Player, purchaseId: string): boolean
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false
	end

	if table.find(profile.Data.ReceiptHistory, purchaseId) then
		return true
	end
	profile.Data.StreakProtectionCredits += 1
	table.insert(profile.Data.ReceiptHistory, purchaseId)
	while #profile.Data.ReceiptHistory > 50 do
		table.remove(profile.Data.ReceiptHistory, 1)
	end
	publish(player)
	profile:Save()
	return true
end

return DataManager
