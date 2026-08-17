--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ButtonEffects = require(ReplicatedStorage.Modules.Client.ButtonEffects)
local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)
local ShopConfig = require(ReplicatedStorage.Modules.Shared.Config.ShopConfig)

local ShopController = {}
local ROBUX_SYMBOL = utf8.char(0xE002)

type Offer = {
	Kind: string,
	ButtonTag: string,
	MonetizationName: string,
	DisplayName: string,
	Description: string,
	Price: number?,
}

type PassState = {
	Configured: boolean,
	Owned: boolean,
	Enabled: boolean,
	Price: number?,
}

local player = Players.LocalPlayer
local remote: RemoteEvent
local shopFrame: GuiObject
local shopScale: UIScale
local hudShopButton: GuiButton?
local closeButton: GuiButton?
local currentStates: { [string]: PassState } = {}
local boundButtons: { [GuiButton]: boolean } = {}
local offerByButton: { [GuiButton]: Offer } = {}
local openGeneration = 0

local function findTextObject(root: Instance, name: string): TextLabel | TextButton?
	local object = root:FindFirstChild(name, true)
	if object and (object:IsA("TextLabel") or object:IsA("TextButton")) then
		return object
	end
	return nil
end

local function setShadowText(textObject: TextLabel | TextButton, value: string)
	textObject.Text = value
	local shadow = textObject:FindFirstChild("Amount2")
		or textObject:FindFirstChild("Title")
		or textObject:FindFirstChild("Text")
	if shadow and (shadow:IsA("TextLabel") or shadow:IsA("TextButton")) then
		shadow.Text = value
	end
end

local function formatRobux(value: number): string
	return `{ROBUX_SYMBOL} {math.max(0, math.floor(value))}`
end

local function getAmountLabel(button: GuiButton): TextLabel | TextButton?
	local amount = findTextObject(button, "Amount")
	if amount then
		return amount
	end
	return findTextObject(button, "Status")
end

local function getScale(gui: GuiObject): UIScale
	local existing = gui:FindFirstChild("ShopTransitionScale")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local scale = Instance.new("UIScale")
	scale.Name = "ShopTransitionScale"
	scale.Parent = gui
	return scale
end

local function setOpen(open: boolean)
	openGeneration += 1
	local generation = openGeneration
	local scale = getScale(shopFrame)
	scale.Scale = if open then 0.82 else 1
	if open then
		shopFrame.Visible = true
		TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	else
		local tween = TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = 0.82,
		})
		tween:Play()
		tween.Completed:Once(function()
			if generation == openGeneration then
				shopFrame.Visible = false
			end
		end)
	end
end

local function updateButton(button: GuiButton, offer: Offer)
	local amount = getAmountLabel(button)
	if not amount then
		return
	end
	local state = currentStates[offer.MonetizationName]
	if offer.Kind == "DeveloperProduct" then
		setShadowText(amount, formatRobux(offer.Price or 0))
		return
	end
	if not state then
		setShadowText(amount, ROBUX_SYMBOL)
		return
	end
	if not state.Configured then
		setShadowText(amount, "N/A")
	elseif state.Owned then
		setShadowText(amount, "OWNED")
	elseif type(state.Price) == "number" then
		setShadowText(amount, formatRobux(state.Price))
	else
		setShadowText(amount, ROBUX_SYMBOL)
	end
end

local function bindOfferButton(button: GuiButton, offer: Offer)
	if boundButtons[button] then
		offerByButton[button] = offer
		updateButton(button, offer)
		return
	end
	boundButtons[button] = true
	offerByButton[button] = offer
	button.Active = true
	button.Interactable = true
	button.Selectable = true
	ButtonEffects.Bind(button, function()
		if offer.Kind == "DeveloperProduct" then
			remote:FireServer("ShopProductAction", offer.MonetizationName)
		else
			remote:FireServer("GamePassAction", offer.MonetizationName)
		end
	end)
	updateButton(button, offer)
end

local function tryBindButton(instance: Instance)
	if not instance:IsA("GuiButton") or not instance:IsDescendantOf(shopFrame) then
		return
	end
	for _, offer in ShopConfig.Offers do
		if CollectionService:HasTag(instance, offer.ButtonTag) then
			bindOfferButton(instance, offer :: Offer)
		end
	end
end

local function bindTaggedOffers()
	for _, offer in ShopConfig.Offers do
		for _, tagged in CollectionService:GetTagged(offer.ButtonTag) do
			tryBindButton(tagged)
		end
		CollectionService:GetInstanceAddedSignal(offer.ButtonTag):Connect(tryBindButton)
	end
end

function ShopController.Init()
	remote = Remote.New("ColorGameEvent")
	local playerGui = player:WaitForChild("PlayerGui")
	local mainGui = playerGui:WaitForChild("MainGui")
	local hud = playerGui:WaitForChild("HUD")
	shopFrame = mainGui:WaitForChild("Shop") :: GuiObject
	local shopContainer = shopFrame:WaitForChild("Container")
	local top = shopContainer:WaitForChild("Top")
	local topContainer = top:WaitForChild("Container")
	closeButton = topContainer:FindFirstChild("Close") :: GuiButton?
	hudShopButton = hud:WaitForChild("Left"):WaitForChild("Shop") :: GuiButton
	shopScale = shopFrame:FindFirstChildWhichIsA("UIScale") or Instance.new("UIScale", shopFrame)
	shopFrame.Visible = false
	shopScale.Scale = 1

	if hudShopButton and hudShopButton:IsA("GuiButton") then
		hudShopButton.Active = true
		hudShopButton.Interactable = true
		hudShopButton.Selectable = true
		ButtonEffects.Bind(hudShopButton, function()
			setOpen(not shopFrame.Visible)
		end)
	end
	if closeButton and closeButton:IsA("GuiButton") then
		closeButton.Active = true
		closeButton.Interactable = true
		closeButton.Selectable = true
		ButtonEffects.Bind(closeButton, function()
			setOpen(false)
		end)
	end

	bindTaggedOffers()
	shopFrame.DescendantAdded:Connect(function(descendant)
		task.defer(tryBindButton, descendant)
	end)

	remote.OnClientEvent:Connect(function(action: string, ...: any)
		local args = table.pack(...)
		if action == "GamePassState" then
			local gamePassName = tostring(args[1] or "")
			currentStates[gamePassName] = {
				Configured = args[2] == true,
				Owned = args[3] == true,
				Enabled = args[4] == true,
				Price = if type(args[5]) == "number" then args[5] else nil,
			}
			for button, offer in offerByButton do
				if offer.Kind == "GamePass" and offer.MonetizationName == gamePassName then
					updateButton(button, offer)
				end
			end
		end
	end)

	remote:FireServer("MonetizationReady")
end

return ShopController
