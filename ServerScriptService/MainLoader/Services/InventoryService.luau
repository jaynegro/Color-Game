--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Modules.Shared.Config.ItemCatalog)

local InventoryService = {}

type VisualState = {
	Transparency: number,
}

type TableRecord = {
	Model: Model,
	TableVisual: Model?,
	Seats: { Seat },
	Chairs: { [Seat]: Model },
}

local network: any
local dataManager: any
local monetization: any
local assets: Folder
local records: { TableRecord } = {}
local seatRecord: { [Seat]: TableRecord } = {}
local visualStates: { [Instance]: VisualState } = {}
local activeSkins: { [Instance]: Model } = {}
local lastRequestAt: { [Player]: number } = {}
local adminEquipOverrides: { [Player]: { [string]: string } } = {}
local LEGACY_ITEM_ALIASES = {
	Chair = { Candy = "Jelly_Candy" },
	Table = {
		Metal = "Big_Metal",
		TableModel = "Default",
	},
}

local function getItem(category: string, itemId: string): any?
	local categoryData = Catalog.Categories[category]
	return categoryData and categoryData.Items[itemId] or nil
end

local function canonicalCategory(requested: string): string?
	for categoryName in Catalog.Categories do
		if string.lower(categoryName) == string.lower(requested) then
			return categoryName
		end
	end
	return nil
end

local function canonicalItem(category: string, requested: string): string?
	local categoryData = Catalog.Categories[category]
	if not categoryData then
		return nil
	end
	local normalized = string.lower((string.gsub(requested, " ", "_")))
	for itemId, itemData in categoryData.Items do
		if string.lower(itemId) == normalized or string.lower(itemData.AssetName) == normalized then
			return itemId
		end
	end
	return nil
end

local function migrateLegacyItems(player: Player)
	local snapshot = dataManager.GetInventorySnapshot(player)
	if not snapshot then
		return
	end
	for category, aliases in LEGACY_ITEM_ALIASES do
		local categoryInventory = snapshot.Inventory[category]
		for oldItem, newItem in aliases do
			if categoryInventory and categoryInventory[oldItem] == true then
				dataManager.GrantItem(player, category, newItem)
				if snapshot.Equipped[category] == oldItem then
					dataManager.EquipItem(player, category, newItem)
				end
			end
		end
	end
end

local function effectiveEquipped(player: Player, category: string): string
	local overrides = adminEquipOverrides[player]
	return if overrides and overrides[category] then overrides[category] else dataManager.GetEquippedItem(player, category)
end

local function rememberAndSetVisible(root: Instance, visible: boolean)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") or descendant:IsA("Texture") then
			local state = visualStates[descendant]
			if not state then
				state = { Transparency = descendant.Transparency }
				visualStates[descendant] = state
			end
			descendant.Transparency = if visible then state.Transparency else 1
		end
	end
end

local function clearSkin(target: Instance)
	local active = activeSkins[target]
	if active then
		activeSkins[target] = nil
		active:Destroy()
	end
	rememberAndSetVisible(target, true)
end

local function prepareVisualClone(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			if descendant:IsA("Seat") then
				descendant.Disabled = true
			end
		end
	end
end

local function applySkin(target: Model, category: string, itemId: string)
	clearSkin(target)
	if itemId == "Default" then
		return
	end
	local itemData = getItem(category, itemId)
	local categoryData = Catalog.Categories[category]
	local folder = categoryData and assets:FindFirstChild(categoryData.AssetFolder)
	local source = folder and itemData and folder:FindFirstChild(itemData.AssetName)
	if not source or not source:IsA("Model") then
		warn(`[ColorGame] Missing skin model Assets.{categoryData and categoryData.AssetFolder or category}.{itemData and itemData.AssetName or itemId}`)
		return
	end
	local clone = source:Clone()
	clone.Name = `ColorGame{category}Skin`
	clone:SetAttribute("ColorGameSkin", true)
	prepareVisualClone(clone)
	-- Align the skin's authored Model pivot to the original Workspace model's
	-- exact pivot. This preserves X/Y/Z position and full orientation; chair
	-- height is never estimated from its bounding box.
	local workspacePivot = target:GetPivot()
	rememberAndSetVisible(target, false)
	clone:PivotTo(workspacePivot)
	clone.Parent = target
	activeSkins[target] = clone
end

local function occupantPlayer(seat: Seat): Player?
	local humanoid = seat.Occupant
	return if humanoid then Players:GetPlayerFromCharacter(humanoid.Parent) else nil
end

local function refreshChair(seat: Seat)
	local record = seatRecord[seat]
	local chair = record and record.Chairs[seat]
	if not chair then
		return
	end
	local player = occupantPlayer(seat)
	local equipped = if player then effectiveEquipped(player, "Chair") else "Default"
	applySkin(chair, "Chair", equipped)
end

local function refreshTable(record: TableRecord)
	local winningItem = "Default"
	local winningRarity = -math.huge
	for _, seat in record.Seats do
		local player = occupantPlayer(seat)
		if player then
			local equipped = effectiveEquipped(player, "Table")
			local itemData = getItem("Table", equipped)
			local rarity = if itemData and type(itemData.Rarity) == "number" then itemData.Rarity else 0
			if rarity > winningRarity or (rarity == winningRarity and equipped < winningItem) then
				winningItem = equipped
				winningRarity = rarity
			end
		end
	end
	if record.TableVisual then
		applySkin(record.TableVisual, "Table", winningItem)
	end
end

local function refreshPlayerCosmetics(player: Player)
	for _, record in records do
		local refreshShared = false
		for _, seat in record.Seats do
			if occupantPlayer(seat) == player then
				refreshChair(seat)
				refreshShared = true
			end
		end
		if refreshShared then
			refreshTable(record)
		end
	end
end

local function gamePassInfo(): any
	local info = {}
	for categoryName, categoryData in Catalog.Categories do
		for itemId, itemData in categoryData.Items do
			if itemData.Currency == "Robux" and type(itemData.GamePassName) == "string" then
				local gamePassName = itemData.GamePassName
				local configured = monetization.GetGamePassId(gamePassName) > 0
				info[`{categoryName}:{itemId}`] = {
					Configured = configured,
					Price = if configured then monetization.GetGamePassPrice(gamePassName) else nil,
				}
			end
		end
	end
	return info
end

local function sendSnapshot(player: Player)
	local snapshot = dataManager.GetInventorySnapshot(player)
	if snapshot then
		local overrides = adminEquipOverrides[player]
		if overrides then
			for category, itemId in overrides do
				snapshot.Equipped[category] = itemId
			end
		end
		snapshot.GamePassInfo = gamePassInfo()
		network.FireClient(player, "InventorySnapshot", snapshot)
	end
end

local function syncGamePassItems(player: Player)
	for categoryName, categoryData in Catalog.Categories do
		for itemId, itemData in categoryData.Items do
			if itemData.Currency == "Robux" and type(itemData.GamePassName) == "string"
				and monetization.OwnsGamePass(player, itemData.GamePassName) then
				dataManager.GrantItem(player, categoryName, itemId)
			end
		end
	end
end

local function handleItemAction(player: Player, category: any, itemId: any)
	if type(category) ~= "string" or type(itemId) ~= "string" or #category > 16 or #itemId > 48 then
		return
	end
	local itemData = getItem(category, itemId)
	if not itemData then
		return
	end
	local now = os.clock()
	if now - (lastRequestAt[player] or 0) < 0.25 then
		return
	end
	lastRequestAt[player] = now
	local overrides = adminEquipOverrides[player]
	if overrides then
		overrides[category] = nil
	end

	if dataManager.OwnsItem(player, category, itemId) then
		local equipped, message = dataManager.EquipItem(player, category, itemId)
		if equipped then
			refreshPlayerCosmetics(player)
		end
		network.FireClient(player, "Notify", message, if equipped then "Success" else "Warning")
		sendSnapshot(player)
		return
	end

	if itemData.Currency == "Robux" then
		local gamePassName = itemData.GamePassName
		if type(gamePassName) ~= "string" or not monetization.PromptGamePass(player, gamePassName) then
			network.FireClient(player, "Notice", "This game pass is not configured yet.")
		end
		return
	end

	local purchased, message = dataManager.PurchaseItem(player, category, itemId, itemData.Currency, itemData.Price)
	if purchased then
		dataManager.EquipItem(player, category, itemId)
		refreshPlayerCosmetics(player)
	end
	network.FireClient(player, "Notify", message, if purchased then "Success" else "Warning")
	sendSnapshot(player)
end

function InventoryService.SetAdminEquipOverride(player: Player, requestedCategory: string, requestedItem: string): (boolean, string)
	local category = canonicalCategory(requestedCategory)
	if not category or (category ~= "Chair" and category ~= "Table" and category ~= "Map") then
		return false, "Category must be Chair, Table, or Map."
	end
	local itemId = canonicalItem(category, requestedItem)
	if not itemId then
		return false, `{requestedItem} is not configured in the {category} catalog.`
	end
	local overrides = adminEquipOverrides[player] or {}
	adminEquipOverrides[player] = overrides
	overrides[category] = itemId
	refreshPlayerCosmetics(player)
	sendSnapshot(player)
	return true, `Admin-equipped {category} skin: {itemId}.`
end

function InventoryService.AdminUnequip(player: Player, requestedCategory: string): (boolean, string)
	local category = canonicalCategory(requestedCategory)
	if not category or (category ~= "Chair" and category ~= "Table" and category ~= "Map") then
		return false, "Category must be Chair, Table, or Map."
	end
	local overrides = adminEquipOverrides[player] or {}
	adminEquipOverrides[player] = overrides
	overrides[category] = "Default"
	refreshPlayerCosmetics(player)
	sendSnapshot(player)
	return true, `Admin-unequipped {category}; Default is active for this session.`
end

function InventoryService.GrantPermanentItem(player: Player, category: string, itemId: string): (boolean, string)
	if not getItem(category, itemId) then
		return false, `{itemId} is not configured in the {category} catalog.`
	end
	if dataManager.OwnsItem(player, category, itemId) then
		dataManager.EquipItem(player, category, itemId)
		refreshPlayerCosmetics(player)
		sendSnapshot(player)
		return true, "Already owned"
	end
	if not dataManager.GrantItem(player, category, itemId) then
		return false, "Your data is still loading. Please try again."
	end
	dataManager.EquipItem(player, category, itemId)
	refreshPlayerCosmetics(player)
	dataManager.Save(player)
	sendSnapshot(player)
	return true, "Granted"
end

local function bindTables()
	local tables = workspace:WaitForChild("ScriptableParts"):WaitForChild("Tables")
	for _, tableModel in tables:GetChildren() do
		if not tableModel:IsA("Model") or (tableModel.Name ~= "Table" and tableModel.Name ~= "Table_VIP") then
			continue
		end
		local record: TableRecord = {
			Model = tableModel,
			TableVisual = tableModel:FindFirstChild("TableModel") :: Model?,
			Seats = {},
			Chairs = {},
		}
		for _, chair in tableModel:GetChildren() do
			if chair:IsA("Model") and string.match(chair.Name, "^Chair%d+$") then
				local seat = chair:FindFirstChildWhichIsA("Seat", true)
				if seat then
					table.insert(record.Seats, seat)
					record.Chairs[seat] = chair
					seatRecord[seat] = record
					seat:GetPropertyChangedSignal("Occupant"):Connect(function()
						task.defer(function()
							refreshChair(seat)
							refreshTable(record)
						end)
					end)
				end
			end
		end
		table.insert(records, record)
	end
end

function InventoryService.Init(networkService, playerDataManager, monetizationService)
	network = networkService
	dataManager = playerDataManager
	monetization = monetizationService
	assets = ReplicatedStorage:WaitForChild("Assets") :: Folder
	bindTables()

	dataManager.ProfileLoaded:Connect(function(player: Player)
		task.spawn(function()
			migrateLegacyItems(player)
			syncGamePassItems(player)
			sendSnapshot(player)
		end)
	end)
	monetization.GamePassPurchased:Connect(function(player: Player, gamePassName: string)
		for categoryName, categoryData in Catalog.Categories do
			for itemId, itemData in categoryData.Items do
				if itemData.GamePassName == gamePassName then
					if dataManager.GrantItem(player, categoryName, itemId) then
						dataManager.EquipItem(player, categoryName, itemId)
						refreshPlayerCosmetics(player)
						sendSnapshot(player)
					end
					return
				end
			end
		end
	end)

	local remote = network.Event :: RemoteEvent
	remote.OnServerEvent:Connect(function(player, action, ...)
		if action == "InventoryReady" then
			task.spawn(function()
				migrateLegacyItems(player)
				syncGamePassItems(player)
				sendSnapshot(player)
			end)
		elseif action == "InventoryAction" then
			task.spawn(handleItemAction, player, ...)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequestAt[player] = nil
		adminEquipOverrides[player] = nil
	end)
end

return InventoryService
