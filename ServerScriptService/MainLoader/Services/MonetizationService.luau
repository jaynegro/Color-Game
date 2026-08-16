--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local MonetizationService = {}

type Offer = {
	Id: number,
	DisplayName: string,
}

local config: any
local network: any
local productHandlers: { [number]: (Player, string) -> boolean } = {}
local ownedGamePasses: { [Player]: { [string]: boolean } } = {}
local autoPickEnabled: { [Player]: boolean } = {}
local gamePassPrices: { [string]: number? } = {}
local lastGamePassActionAt: { [Player]: number } = {}
local eventConnection: RBXScriptConnection?

local function getOffer(groupName: string, offerName: string): Offer?
	local group = config and config[groupName]
	local offer = group and group[offerName]
	if type(offer) ~= "table" or type(offer.Id) ~= "number" then
		warn(`[ColorGame] MonetizationConfig.{groupName}.{offerName} is missing or invalid`)
		return nil
	end
	return offer :: Offer
end

local function getOfferId(groupName: string, offerName: string): number
	local offer = getOffer(groupName, offerName)
	return if offer then math.floor(offer.Id) else 0
end

local function registerProduct(productName: string, handler: (Player, string) -> boolean)
	local productId = getOfferId("DeveloperProducts", productName)
	if productId <= 0 then
		return
	end
	assert(productHandlers[productId] == nil, `Duplicate developer product ID {productId}`)
	productHandlers[productId] = handler
end

function MonetizationService.GetDeveloperProductId(productName: string): number
	return getOfferId("DeveloperProducts", productName)
end

function MonetizationService.GetGamePassId(gamePassName: string): number
	return getOfferId("GamePasses", gamePassName)
end

function MonetizationService.PromptProduct(player: Player, productName: string): boolean
	local productId = MonetizationService.GetDeveloperProductId(productName)
	if productId <= 0 then
		return false
	end
	local ok, problem = pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, player, productId)
	if not ok then
		warn(`[ColorGame] Could not prompt developer product {productName} ({productId}): {problem}`)
	end
	return ok
end

function MonetizationService.OwnsGamePass(player: Player, gamePassName: string): boolean
	local gamePassId = MonetizationService.GetGamePassId(gamePassName)
	if gamePassId <= 0 then
		return false
	end
	local playerCache = ownedGamePasses[player]
	if playerCache and playerCache[gamePassName] ~= nil then
		return playerCache[gamePassName]
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, gamePassId)
	if not ok then
		warn(`[ColorGame] Could not check game pass {gamePassName} ({gamePassId}): {owns}`)
		return false
	end
	playerCache = playerCache or {}
	ownedGamePasses[player] = playerCache
	playerCache[gamePassName] = owns == true
	return owns == true
end

function MonetizationService.PromptGamePass(player: Player, gamePassName: string): boolean
	local gamePassId = MonetizationService.GetGamePassId(gamePassName)
	if gamePassId <= 0 then
		return false
	end
	local ok, problem = pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, gamePassId)
	if not ok then
		warn(`[ColorGame] Could not prompt game pass {gamePassName} ({gamePassId}): {problem}`)
	end
	return ok
end

local function getGamePassPrice(gamePassName: string): number?
	local cached = gamePassPrices[gamePassName]
	if cached ~= nil then
		return cached
	end
	local gamePassId = MonetizationService.GetGamePassId(gamePassName)
	if gamePassId <= 0 then
		return nil
	end
	local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, gamePassId, Enum.InfoType.GamePass)
	if not ok then
		warn(`[ColorGame] Could not load price for game pass {gamePassName} ({gamePassId}): {info}`)
		return nil
	end
	local price = if type(info.PriceInRobux) == "number" then math.floor(info.PriceInRobux) else nil
	gamePassPrices[gamePassName] = price
	return price
end

local function sendGamePassState(player: Player, gamePassName: string)
	local configured = MonetizationService.GetGamePassId(gamePassName) > 0
	local owned = if configured then MonetizationService.OwnsGamePass(player, gamePassName) else false
	local enabled = gamePassName == "AutoPick" and owned and autoPickEnabled[player] == true
	local price = if configured and not owned then getGamePassPrice(gamePassName) else nil
	if gamePassName == "VIP" then
		player:SetAttribute("IsVIP", owned)
	end
	network.FireClient(player, "GamePassState", gamePassName, configured, owned, enabled, price)
end

local function sendAllGamePassStates(player: Player)
	for gamePassName in config.GamePasses do
		sendGamePassState(player, gamePassName)
	end
end

function MonetizationService.Init(monetizationConfig, dataManager, tableService, networkService)
	config = monetizationConfig
	network = networkService
	table.clear(productHandlers)

	registerProduct("Rainbow", function(player, purchaseId)
		local granted = dataManager.GrantRainbowPurchase(player, purchaseId)
		if granted then
			tableService.OnRainbowGranted(player)
		end
		return granted
	end)
	registerProduct("StreakProtection", function(player, purchaseId)
		local granted = dataManager.GrantStreakProtectionPurchase(player, purchaseId)
		if granted then
			tableService.OnStreakProtectionGranted(player)
		end
		return granted
	end)

	tableService.SetRainbowPrompt(function(player)
		if not MonetizationService.PromptProduct(player, "Rainbow") then
			network.FireClient(player, "Notice", "Rainbow is not available yet.")
		end
	end)
	tableService.SetStreakProtectionPrompt(function(player)
		if not MonetizationService.PromptProduct(player, "StreakProtection") then
			network.FireClient(player, "Notice", "Streak Protection is not available yet.")
		end
	end)
	tableService.SetVIPAccessChecker(function(player)
		return MonetizationService.OwnsGamePass(player, "VIP")
	end)
	tableService.SetVIPDeniedHandler(function(player)
		if not MonetizationService.PromptGamePass(player, "VIP") then
			network.FireClient(player, "Notice", "VIP Game Pass is not configured yet.")
		end
	end)
	tableService.SetAutoPickChecker(function(player)
		return autoPickEnabled[player] == true
	end)

	local remote = network.Event :: RemoteEvent
	eventConnection = remote.OnServerEvent:Connect(function(player, action, gamePassName)
		if action == "MonetizationReady" then
			task.spawn(sendAllGamePassStates, player)
			return
		end
		if action ~= "GamePassAction" or type(gamePassName) ~= "string"
			or config.GamePasses[gamePassName] == nil then
			return
		end
		local now = os.clock()
		if now - (lastGamePassActionAt[player] or 0) < 0.5 then
			return
		end
		lastGamePassActionAt[player] = now
		task.spawn(function()
			if not MonetizationService.OwnsGamePass(player, gamePassName) then
				if not MonetizationService.PromptGamePass(player, gamePassName) then
					network.FireClient(player, "Notice", `{gamePassName} Game Pass is not configured yet.`)
				end
				return
			end
			if gamePassName == "AutoPick" then
				autoPickEnabled[player] = not (autoPickEnabled[player] == true)
				sendGamePassState(player, gamePassName)
				if autoPickEnabled[player] then
					tableService.OnAutoPickEnabled(player)
				end
			else
				sendGamePassState(player, gamePassName)
			end
		end)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, purchasedPassId, wasPurchased)
		if not wasPurchased then
			return
		end
		for gamePassName, offer in config.GamePasses do
			if offer.Id == purchasedPassId then
				local playerCache = ownedGamePasses[player] or {}
				ownedGamePasses[player] = playerCache
				playerCache[gamePassName] = true
				if gamePassName == "VIP" then
					player:SetAttribute("IsVIP", true)
				end
				autoPickEnabled[player] = if gamePassName == "AutoPick" then false else autoPickEnabled[player]
				task.defer(sendGamePassState, player, gamePassName)
				break
			end
		end
	end)

	local function initializeVIP(player: Player)
		player:SetAttribute("IsVIP", false)
		task.spawn(function()
			local owned = MonetizationService.OwnsGamePass(player, "VIP")
			if player.Parent then
				player:SetAttribute("IsVIP", owned)
			end
		end)
	end
	Players.PlayerAdded:Connect(initializeVIP)
	for _, player in Players:GetPlayers() do
		initializeVIP(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ownedGamePasses[player] = nil
		autoPickEnabled[player] = nil
		lastGamePassActionAt[player] = nil
	end)

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local handler = productHandlers[receiptInfo.ProductId]
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not handler or not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, granted = pcall(handler, player, tostring(receiptInfo.PurchaseId))
		if ok and granted then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		if not ok then
			warn(`[ColorGame] Receipt {receiptInfo.PurchaseId} failed: {granted}`)
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

return MonetizationService
