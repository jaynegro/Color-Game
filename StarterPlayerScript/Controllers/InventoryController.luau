--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ButtonEffects = require(ReplicatedStorage.Modules.Client.ButtonEffects)
local Catalog = require(ReplicatedStorage.Modules.Shared.Config.ItemCatalog)
local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)

local InventoryController = {}

local player = Players.LocalPlayer
local remote: RemoteEvent
local panel: GuiObject
local panelScale: UIScale
local gridContainer: GuiObject
local template: GuiObject
local headerTitle: TextLabel | TextButton?
local currentCategory = "Chair"
local snapshot: any = nil
local generatedRows: { GuiObject } = {}
local categoryButtons: { [string]: GuiButton } = {}
local localMapClone: Model? = nil
local originalMapTransparency: { [BasePart]: number } = {}
local warnedMapAssets: { [string]: boolean } = {}
local panelTween: Tween? = nil
local panelTweenGeneration = 0
local CATEGORY_ENABLED: { [string]: boolean } = {
	Chair = true,
	Table = true,
	Map = false,
}

local function enableButton(button: GuiButton)
	button.Active = true
	button.Interactable = true
	button.Selectable = true
end

local function findText(root: Instance, name: string): TextLabel | TextButton?
	if root.Name == name and (root:IsA("TextLabel") or root:IsA("TextButton")) then
		return root
	end
	for _, object in root:GetDescendants() do
		if object.Name == name and (object:IsA("TextLabel") or object:IsA("TextButton")) then
			return object
		end
	end
	return nil
end

local function setTextWithShadow(textObject: TextLabel | TextButton, value: string)
	textObject.Text = value
	local shadow = textObject:FindFirstChild("Title")
	if shadow and (shadow:IsA("TextLabel") or shadow:IsA("TextButton")) then
		shadow.Text = value
	end
end

local function setImage(root: Instance, name: string, image: string)
	if image == "" then
		return
	end
	for _, descendant in root:GetDescendants() do
		if descendant.Name == name and (descendant:IsA("ImageLabel") or descendant:IsA("ImageButton")) then
			descendant.Image = image
		end
	end
end

local function setOpen(open: boolean)
	panelScale = panelScale or (panel:FindFirstChildWhichIsA("UIScale") :: UIScale)
	panelTweenGeneration += 1
	local generation = panelTweenGeneration
	if panelTween then
		panelTween:Cancel()
		panelTween = nil
	end
	if open then
		panel.Visible = true
		panelScale.Scale = 0.82
		panelTween = TweenService:Create(panelScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		panelTween:Play()
	else
		local tween = TweenService:Create(panelScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.82 })
		panelTween = tween
		tween:Play()
		tween.Completed:Once(function()
			if generation == panelTweenGeneration and panelTween == tween then
				panelTween = nil
				panel.Visible = false
			end
		end)
	end
end

local function owned(category: string, itemId: string): boolean
	local inventory = snapshot and snapshot.Inventory
	local categoryInventory = inventory and inventory[category]
	return categoryInventory and categoryInventory[itemId] == true or false
end

local function equipped(category: string, itemId: string): boolean
	return snapshot and snapshot.Equipped and snapshot.Equipped[category] == itemId or false
end

local function clearRows()
	for _, row in generatedRows do
		row:Destroy()
	end
	table.clear(generatedRows)
end

local function updateCategoryLabels()
	local labels = {
		Chair = "Chair Skin",
		Table = "Table Skin",
		Map = "Map",
	}
	for categoryName, button in categoryButtons do
		local amount = findText(button, "Amount")
		if amount then
			amount.Text = labels[categoryName] or categoryName
		end
	end
end

local function render()
	if not snapshot then
		return
	end
	clearRows()
	local categoryData = Catalog.Categories[currentCategory]
	if not categoryData then
		return
	end
	if headerTitle then
		setTextWithShadow(headerTitle, categoryData.DisplayName)
	end
	updateCategoryLabels()

	local ordered = {}
	for itemId, itemData in categoryData.Items do
		table.insert(ordered, { Id = itemId, Data = itemData })
	end
	table.sort(ordered, function(a, b)
		if a.Data.Rarity == b.Data.Rarity then
			return a.Id < b.Id
		end
		return a.Data.Rarity < b.Data.Rarity
	end)

	for index, entry in ordered do
		local itemId = entry.Id
		local itemData = entry.Data
		local row = template:Clone()
		row.Name = `Item_{itemId}`
		row.LayoutOrder = index
		row.Visible = true
		row:SetAttribute("InventoryItem", true)
		local title = findText(row, "Title")
		if title then
			setTextWithShadow(title, itemData.DisplayName)
		end
		setImage(row, "Icon", itemData.Icon)
		setImage(row, "Icon2", itemData.Icon)

		local rewards = row:FindFirstChild("Rewards", true)
		local rewardAmount = rewards and findText(rewards, "Amount")
		local currencyImage = rewards and rewards:FindFirstChild("ImageLabel", true)
		local isOwned = owned(currentCategory, itemId)
		if rewards and rewards:IsA("GuiObject") then
			rewards.Visible = not isOwned and itemData.Currency ~= "Free"
		end
		if rewardAmount then
			if itemData.Currency == "Robux" then
				local info = snapshot.GamePassInfo and snapshot.GamePassInfo[`{currentCategory}:{itemId}`]
				rewardAmount.Text = if info and info.Configured then (if info.Price then tostring(info.Price) else "R$") else "N/A"
			else
				rewardAmount.Text = tostring(itemData.Price)
			end
		end
		if currencyImage and currencyImage:IsA("ImageLabel") then
			local configuredImage = Catalog.CurrencyIcons[itemData.Currency]
			if type(configuredImage) == "string" and configuredImage ~= "" then
				currencyImage.Image = configuredImage
			end
		end

		local claim = row:FindFirstChild("Claim", true)
		if claim and claim:IsA("GuiButton") then
			local label = findText(claim, "Amount") or findText(claim, "Title")
			if label then
				label.Text = if equipped(currentCategory, itemId) then "EQUIPPED" elseif isOwned then "EQUIP" else "BUY"
			end
			claim.Active = not equipped(currentCategory, itemId)
			claim.Interactable = not equipped(currentCategory, itemId)
			ButtonEffects.Bind(claim, function()
				if not equipped(currentCategory, itemId) then
					remote:FireServer("InventoryAction", currentCategory, itemId)
				end
			end)
		end
		row.Parent = gridContainer
		table.insert(generatedRows, row)
	end
end

local function restoreDefaultMap()
	if localMapClone then
		localMapClone:Destroy()
		localMapClone = nil
	end
	for part, transparency in originalMapTransparency do
		if part.Parent then
			part.LocalTransparencyModifier = transparency
		end
	end
	table.clear(originalMapTransparency)
end

local function validMapAsset(model: Model): boolean
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and string.match(descendant.Name, "HB$") then
			return false
		end
	end
	return model:FindFirstChildWhichIsA("BasePart", true) ~= nil
end

local function applyLocalMap(itemId: string)
	restoreDefaultMap()
	if itemId == "Default" then
		return
	end
	local itemData = Catalog.Categories.Map.Items[itemId]
	local mapFolder = ReplicatedStorage.Assets:FindFirstChild(Catalog.Categories.Map.AssetFolder)
	local source = mapFolder and itemData and mapFolder:FindFirstChild(itemData.AssetName)
	local worldMap = workspace:FindFirstChild("Models")
	if not source or not source:IsA("Model") or not worldMap or not worldMap:IsA("Model") or not validMapAsset(source) then
		if not warnedMapAssets[itemId] then
			warn(`[ColorGame] Map skin {itemId} is missing or invalid. Replace ReplicatedStorage.Assets.Map.{itemData and itemData.AssetName or itemId} with a real map Model.`)
			warnedMapAssets[itemId] = true
		end
		return
	end
	for _, descendant in worldMap:GetDescendants() do
		if descendant:IsA("BasePart") then
			originalMapTransparency[descendant] = descendant.LocalTransparencyModifier
			descendant.LocalTransparencyModifier = 1
		end
	end
	local clone = source:Clone()
	clone.Name = "ColorGameLocalMap"
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end
	clone:PivotTo(worldMap:GetPivot())
	clone.Parent = workspace
	localMapClone = clone
end

local function bindCategoryButton(category: string, buttonName: string, buttons: Instance)
	local button = buttons:FindFirstChild(buttonName)
	if not button or not button:IsA("GuiButton") then
		warn(`[ColorGame] Backpack is missing category button {buttonName}`)
		return
	end
	categoryButtons[category] = button
	if CATEGORY_ENABLED[category] == false then
		button.Active = false
		button.Interactable = false
		button.Selectable = false
		button.AutoButtonColor = false
		return
	end
	enableButton(button)
	ButtonEffects.Bind(button, function()
		currentCategory = category
		render()
	end)
end

function InventoryController.Init()
	remote = Remote.New("ColorGameEvent")
	local playerGui = player:WaitForChild("PlayerGui")
	local mainGui = playerGui:WaitForChild("MainGui")
	local hud = playerGui:WaitForChild("HUD")
	panel = mainGui:WaitForChild("Backpack") :: GuiObject
	local outer = panel:WaitForChild("Container")
	local buttons = outer:WaitForChild("Buttons")
	local content = outer:WaitForChild("Container")
	local scroll = content:WaitForChild("Scroll") :: ScrollingFrame
	gridContainer = scroll:WaitForChild("Container") :: GuiObject
	template = gridContainer:WaitForChild("Template") :: GuiObject
	template.Visible = false
	gridContainer.AutomaticSize = Enum.AutomaticSize.Y
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local top = outer:WaitForChild("Top")
	local topContainer = top:WaitForChild("Container")
	local titleContainer = topContainer:FindFirstChild("Title")
	headerTitle = if titleContainer then findText(titleContainer, "Title") else nil
	local close = topContainer:FindFirstChild("Close")
	local openButton = hud:WaitForChild("Left"):WaitForChild("Backpack")
	if not close or not close:IsA("GuiButton") or not openButton:IsA("GuiButton") then
		warn("[ColorGame] Backpack open/close buttons are invalid")
		return
	end
	enableButton(openButton)
	enableButton(close)
	panelScale = panel:FindFirstChildWhichIsA("UIScale") or Instance.new("UIScale", panel)
	panel.Visible = false
	panelScale.Scale = 1
	ButtonEffects.Bind(openButton, function()
		setOpen(not panel.Visible)
	end)
	ButtonEffects.Bind(close, function()
		setOpen(false)
	end)

	bindCategoryButton("Chair", "ChairSkin", buttons)
	bindCategoryButton("Table", "TableSkin", buttons)
	bindCategoryButton("Map", "MapSkin", buttons)

	remote.OnClientEvent:Connect(function(action: string, payload: any)
		if action ~= "InventorySnapshot" or type(payload) ~= "table" then
			return
		end
		local oldMap = snapshot and snapshot.Equipped and snapshot.Equipped.Map
		snapshot = payload
		render()
		local newMap = snapshot.Equipped and snapshot.Equipped.Map or "Default"
		if oldMap ~= newMap then
			applyLocalMap(newMap)
		end
	end)
	remote:FireServer("InventoryReady")
end

return InventoryController
