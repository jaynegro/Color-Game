--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ButtonEffects = require(ReplicatedStorage.Modules.Client.ButtonEffects)
local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)
local MonetizationConfig = require(ReplicatedStorage.Modules.Shared.Config.MonetizationConfig)

local RemoveAllChairsController = {}

local player = Players.LocalPlayer
local remote: RemoteEvent
local rightFrame: Instance?
local boundButton: GuiButton?
local statusLabel: TextLabel?
local productPrice: number?

local function getTextObject(root: Instance, name: string): TextLabel | TextButton?
	local object = root:FindFirstChild(name, true)
	if object and (object:IsA("TextLabel") or object:IsA("TextButton")) then
		return object
	end
	return nil
end

local function normalize(name: string): string
	return string.lower((name:gsub("%s+", "")))
end

local function resolvePrice(): number?
	local offer = MonetizationConfig.DeveloperProducts.RemoveAllChairs
	if not offer or type(offer.Id) ~= "number" or offer.Id <= 0 then
		return nil
	end
	if productPrice ~= nil then
		return productPrice
	end
	local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, offer.Id, Enum.InfoType.Product)
	if not ok then
		return nil
	end
	local price = if type(info.PriceInRobux) == "number" then math.floor(info.PriceInRobux) else nil
	productPrice = price
	return price
end

local function refresh()
	if not statusLabel then
		return
	end
	local offer = MonetizationConfig.DeveloperProducts.RemoveAllChairs
	local price = resolvePrice()
	if not offer or type(offer.Id) ~= "number" or offer.Id <= 0 then
		statusLabel.Text = "N/A"
	elseif price then
		statusLabel.Text = `R{price}`
	else
		statusLabel.Text = "BUY"
	end
end

local function bindButton(button: GuiButton)
	if boundButton == button then
		return
	end
	boundButton = button
	button.Active = true
	button.Interactable = true
	button.Selectable = true
	statusLabel = getTextObject(button, "Status") :: TextLabel?
	ButtonEffects.Bind(button, function()
		remote:FireServer("ShopProductAction", "RemoveAllChairs")
	end)
	refresh()
end

local function tryBind(right: Instance?)
	if not right then
		return
	end
	for _, descendant in right:GetDescendants() do
		if descendant:IsA("GuiButton") and normalize(descendant.Name):find("removeallchairs", 1, true) then
			bindButton(descendant)
			return
		end
		if descendant:IsA("GuiButton") then
			local title = getTextObject(descendant, "Title")
			if title and normalize(title.Text):find("removeallchairs", 1, true) then
				bindButton(descendant)
				return
			end
		end
	end
end

function RemoveAllChairsController.Init()
	remote = Remote.New("ColorGameEvent")
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD")
	rightFrame = hud:FindFirstChild("Right") or hud:FindFirstChild("RightFrame") or hud:WaitForChild("Right", 10)
	tryBind(rightFrame)
	playerGui.DescendantAdded:Connect(function()
		task.defer(function()
			rightFrame = hud:FindFirstChild("Right") or hud:FindFirstChild("RightFrame") or rightFrame
			tryBind(rightFrame)
		end)
	end)
	remote.OnClientEvent:Connect(function(action: string, ...)
		if action ~= "PurchaseSuccess" then
			return
		end
		local kind, value = ...
		if kind == "DeveloperProduct" and value == MonetizationConfig.DeveloperProducts.RemoveAllChairs.Id then
			refresh()
		end
	end)
end

return RemoveAllChairsController
