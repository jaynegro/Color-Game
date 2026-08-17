--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AdminConfig = require(ReplicatedStorage.Modules.Shared.Config.AdminConfig)
local ProfileStore = require(ServerScriptService.Library.ProfileStore)
local Replica = require(script.Parent.ReplicaServer)

local DataManager = {}

local TEMPLATE = {
	Wins = 0,
	Coins = 0,
	Streak = 0,
	BestStreak = 0,
	DuelRank = 0,
	Matches = 0,
	RainbowCredits = 0,
	StreakProtectionCredits = 0,
	ReceiptHistory = {},
	Inventory = {
		Chair = { Default = true },
		Table = { Default = true },
		Map = { Default = true },
	},
	Equipped = {
		Chair = "Default",
		Table = "Default",
		Map = "Default",
	},
}

local profiles: { [Player]: any } = {}
local replicas: { [Player]: any } = {}
local profileStore: any
local playerDataToken: any
local winsChanged = Instance.new("BindableEvent")
local statsChanged = Instance.new("BindableEvent")
local bestStreakChanged = Instance.new("BindableEvent")
local duelRankChanged = Instance.new("BindableEvent")
local profileLoaded = Instance.new("BindableEvent")
local streakCoinRewards: { number } = { 5, 10, 20, 40, 80 }

DataManager.WinsChanged = winsChanged.Event
DataManager.StatsChanged = statsChanged.Event
DataManager.BestStreakChanged = bestStreakChanged.Event
DataManager.DuelRankChanged = duelRankChanged.Event
DataManager.ProfileLoaded = profileLoaded.Event

local function normalizeInventory(data: any)
	if type(data.Coins) ~= "number" then
		data.Coins = 0
	end
	data.Coins = math.max(0, math.floor(data.Coins))
	if type(data.Inventory) ~= "table" then
		data.Inventory = {}
	end
	if type(data.Equipped) ~= "table" then
		data.Equipped = {}
	end
	for _, category in { "Chair", "Table", "Map" } do
		if type(data.Inventory[category]) ~= "table" then
			data.Inventory[category] = {}
		end
		data.Inventory[category].Default = true
		if type(data.Equipped[category]) ~= "string" or data.Inventory[category][data.Equipped[category]] ~= true then
			data.Equipped[category] = "Default"
		end
	end
end

local function publish(player: Player)
	local profile = profiles[player]
	local replica = replicas[player]
	if profile and replica then
		replica:SetValues({}, {
			Wins = profile.Data.Wins,
			Coins = profile.Data.Coins,
			Streak = profile.Data.Streak,
			DuelRank = profile.Data.DuelRank,
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
	normalizeInventory(profile.Data)
	profile.Data.DuelRank = math.max(0, math.floor(tonumber(profile.Data.DuelRank) or 0))
	if AdminConfig.ShouldResetBalanceOnJoin(player.UserId) then
		profile.Data.Wins = 0
		profile.Data.Coins = 0
		profile:Save()
	end
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
	profileLoaded:Fire(player)
	winsChanged:Fire(player, profile.Data.Wins)
	statsChanged:Fire(player, profile.Data.Wins, profile.Data.Streak)
	bestStreakChanged:Fire(player, profile.Data.BestStreak)
	duelRankChanged:Fire(player, profile.Data.DuelRank)
	local replica = Replica.New({
		Token = playerDataToken,
		Tags = { UserId = player.UserId },
		Data = {
			Wins = profile.Data.Wins,
			Coins = profile.Data.Coins,
			Streak = profile.Data.Streak,
			DuelRank = profile.Data.DuelRank,
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
	if type(config.StreakCoinRewards) == "table" and #config.StreakCoinRewards > 0 then
		local configuredRewards = {}
		for _, reward in config.StreakCoinRewards do
			if type(reward) == "number" then
				table.insert(configuredRewards, math.max(0, math.floor(reward)))
			end
		end
		if #configuredRewards > 0 then
			streakCoinRewards = configuredRewards
		end
	end
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

local function streakCoinReward(streak: number): number
	local tier = math.clamp(math.floor(streak), 1, #streakCoinRewards)
	return streakCoinRewards[tier]
end

function DataManager.RecordWin(player: Player, reward: number?): (boolean, number, number)
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false, 0, 0
	end
	local earned = math.max(1, math.floor(reward or 1))
	local newStreak = profile.Data.Streak + 1
	local earnedCoins = streakCoinReward(newStreak)
	profile.Data.Wins += earned
	profile.Data.Coins += earnedCoins
	profile.Data.Streak = newStreak
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
	return true, earnedCoins, newStreak
end

function DataManager.GetInventorySnapshot(player: Player): any?
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return nil
	end
	normalizeInventory(profile.Data)
	return {
		Coins = profile.Data.Coins,
		Wins = profile.Data.Wins,
		Inventory = table.clone(profile.Data.Inventory),
		Equipped = table.clone(profile.Data.Equipped),
	}
end

function DataManager.OwnsItem(player: Player, category: string, itemId: string): boolean
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false
	end
	normalizeInventory(profile.Data)
	local categoryInventory = profile.Data.Inventory[category]
	return type(categoryInventory) == "table" and categoryInventory[itemId] == true
end

function DataManager.GetEquippedItem(player: Player, category: string): string
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return "Default"
	end
	normalizeInventory(profile.Data)
	return profile.Data.Equipped[category] or "Default"
end

function DataManager.GrantItem(player: Player, category: string, itemId: string): boolean
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false
	end
	normalizeInventory(profile.Data)
	profile.Data.Inventory[category][itemId] = true
	return true
end

function DataManager.Save(player: Player): boolean
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false
	end
	profile:Save()
	return true
end

local function validAdminAmount(amount: number): number?
	if amount ~= amount or amount == math.huge or amount == -math.huge then
		return nil
	end
	amount = math.floor(amount)
	if amount <= 0 or amount > 1_000_000_000 then
		return nil
	end
	return amount
end

function DataManager.AddWins(player: Player, amount: number): (boolean, number)
	local profile = profiles[player]
	local validAmount = validAdminAmount(amount)
	if not profile or not profile:IsActive() or not validAmount then
		return false, 0
	end
	profile.Data.Wins += validAmount
	publish(player)
	winsChanged:Fire(player, profile.Data.Wins)
	profile:Save()
	return true, profile.Data.Wins
end

function DataManager.AddCoins(player: Player, amount: number): (boolean, number)
	local profile = profiles[player]
	local validAmount = validAdminAmount(amount)
	if not profile or not profile:IsActive() or not validAmount then
		return false, 0
	end
	profile.Data.Coins += validAmount
	publish(player)
	profile:Save()
	return true, profile.Data.Coins
end

function DataManager.DeductWins(player: Player, amount: number): (boolean, number, number)
	local profile = profiles[player]
	local validAmount = validAdminAmount(amount)
	if not profile or not profile:IsActive() or not validAmount then
		return false, 0, 0
	end
	local deducted = math.min(profile.Data.Wins, validAmount)
	profile.Data.Wins -= deducted
	publish(player)
	winsChanged:Fire(player, profile.Data.Wins)
	profile:Save()
	return true, profile.Data.Wins, deducted
end

function DataManager.DeductCoins(player: Player, amount: number): (boolean, number, number)
	local profile = profiles[player]
	local validAmount = validAdminAmount(amount)
	if not profile or not profile:IsActive() or not validAmount then
		return false, 0, 0
	end
	local deducted = math.min(profile.Data.Coins, validAmount)
	profile.Data.Coins -= deducted
	publish(player)
	profile:Save()
	return true, profile.Data.Coins, deducted
end

function DataManager.PurchaseItem(player: Player, category: string, itemId: string, currency: string, price: number): (boolean, string)
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false, "Your data is still loading."
	end
	normalizeInventory(profile.Data)
	if profile.Data.Inventory[category][itemId] == true then
		return true, "Owned"
	end
	price = math.max(0, math.floor(price))
	if currency == "Coins" then
		if profile.Data.Coins < price then
			return false, "You do not have enough Coins."
		end
		profile.Data.Coins -= price
	elseif currency == "Wins" then
		if profile.Data.Wins < price then
			return false, "You do not have enough Wins."
		end
		profile.Data.Wins -= price
		winsChanged:Fire(player, profile.Data.Wins)
	elseif currency ~= "Free" or price ~= 0 then
		return false, "This item cannot be bought with that currency."
	end
	profile.Data.Inventory[category][itemId] = true
	publish(player)
	return true, "Purchased"
end

function DataManager.EquipItem(player: Player, category: string, itemId: string): (boolean, string)
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false, "Your data is still loading."
	end
	normalizeInventory(profile.Data)
	if profile.Data.Inventory[category][itemId] ~= true then
		return false, "You do not own this item."
	end
	profile.Data.Equipped[category] = itemId
	return true, "Equipped"
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

function DataManager.GetDuelRank(player: Player): number?
	local profile = profiles[player]
	return if profile then profile.Data.DuelRank else nil
end

function DataManager.AwardDuelRank(player: Player): (boolean, number)
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false, 0
	end
	profile.Data.DuelRank += 1
	publish(player)
	duelRankChanged:Fire(player, profile.Data.DuelRank)
	profile:Save()
	return true, profile.Data.DuelRank
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
