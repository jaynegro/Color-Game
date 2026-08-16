--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ButtonEffects = require(ReplicatedStorage.Modules.Client.ButtonEffects)
local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)

local GamePassController = {}

type PassState = {
	Configured: boolean,
	Owned: boolean,
	Enabled: boolean,
	Price: number?,
}

local states: { [string]: PassState } = {}
local buttons: { [string]: GuiButton } = {}
local buttonContainers: { [string]: Instance } = {}
local boundButtons: { [GuiButton]: boolean } = {}
local uiBound = false
local remote: RemoteEvent

local function getTextObject(root: Instance, name: string): TextLabel | TextButton?
	local candidate = root:FindFirstChild(name, true)
	if candidate and (candidate:IsA("TextLabel") or candidate:IsA("TextButton")) then
		return candidate
	end
	return nil
end

local function classifyButton(candidate: GuiButton, boundary: Instance): (string?, Instance?)
	if not candidate:IsA("GuiButton") then
		return nil, nil
	end
	local current: Instance? = candidate
	while current and current ~= boundary do
		local title = getTextObject(current, "Title")
		if title then
			local titleText = string.lower(title.Text)
			if string.find(titleText, "vip", 1, true) then
				return "VIP", current
			end
			if string.find(titleText, "auto", 1, true) then
				return "AutoPick", current
			end
		end
		local instanceName = string.lower(current.Name)
		if string.find(instanceName, "vip", 1, true) then
			return "VIP", current
		end
		if string.find(instanceName, "auto", 1, true) then
			return "AutoPick", current
		end
		current = current.Parent
	end
	return nil, nil
end

local function render(gamePassName: string)
	local button = buttons[gamePassName]
	local state = states[gamePassName]
	if not button or not state then
		return
	end
	local status = getTextObject(buttonContainers[gamePassName] or button, "Status")
	if not status then
		return
	end
	if not state.Configured then
		status.Text = "N/A"
	elseif not state.Owned then
		status.Text = if state.Price then `R${state.Price}` else "BUY"
	elseif gamePassName == "AutoPick" then
		status.Text = if state.Enabled then "ON" else "OFF"
	else
		status.Text = "OWNED"
	end
end

local function bindButton(gamePassName: string, button: GuiButton, container: Instance)
	buttons[gamePassName] = button
	buttonContainers[gamePassName] = container
	button.Active = true
	button.Interactable = true
	button.Selectable = true
	if not boundButtons[button] then
		boundButtons[button] = true
		local actionName = gamePassName
		ButtonEffects.Bind(button, function()
			remote:FireServer("GamePassAction", actionName)
		end)
	end
	render(gamePassName)
end

local function findRight(playerGui: PlayerGui): Instance?
	local hud = playerGui:FindFirstChild("HUD") or playerGui:FindFirstChild("HUD", true)
	if not hud then
		return nil
	end
	local exact = hud:FindFirstChild("Right")
		or hud:FindFirstChild("RightFrame")
		or hud:FindFirstChild("Right", true)
		or hud:FindFirstChild("RightFrame", true)
	if exact then
		return exact
	end
	for _, descendant in hud:GetDescendants() do
		local normalized = string.lower(descendant.Name)
		if normalized == "right" or normalized == "rightframe" then
			return descendant
		end
	end
	return nil
end

local function diagnostic(playerGui: PlayerGui): string
	local right = findRight(playerGui)
	if not right then
		return "HUD exists, but Right/RightFrame was not found"
	end
	local found = {}
	for _, descendant in right:GetDescendants() do
		if descendant:IsA("GuiButton") then
			local title = getTextObject(descendant, "Title")
			local titleText = if title then title.Text else "<none>"
			table.insert(found, `{descendant:GetFullName()} [{descendant.ClassName}] Title={titleText}`)
		end
	end
	if #found == 0 then
		for _, child in right:GetChildren() do
			table.insert(found, `{child.Name} [{child.ClassName}]`)
		end
	end
	return if #found > 0 then table.concat(found, "; ") else "Right is empty"
end

local function tryBindUi(playerGui: PlayerGui): boolean
	if uiBound then
		local autoButton = buttons.AutoPick
		local vipButton = buttons.VIP
		if autoButton and vipButton and autoButton:IsDescendantOf(playerGui) and vipButton:IsDescendantOf(playerGui) then
			return true
		end
		table.clear(buttons)
		table.clear(buttonContainers)
		uiBound = false
	end

	local right = findRight(playerGui)
	if not right then
		return false
	end

	local foundAutoPick: GuiButton? = nil
	local foundVip: GuiButton? = nil
	local autoContainer: Instance? = nil
	local vipContainer: Instance? = nil
	for _, candidate in right:GetDescendants() do
		if candidate:IsA("GuiButton") then
			local parent = candidate.Parent
			local nestedInsideButton = false
			while parent and parent ~= right do
				if parent:IsA("GuiButton") then
					nestedInsideButton = true
					break
				end
				parent = parent.Parent
			end
			if nestedInsideButton then
				continue
			end
			local gamePassName, offerContainer = classifyButton(candidate, right)
			if gamePassName == "VIP" then
				foundVip = candidate
				vipContainer = offerContainer
			elseif gamePassName == "AutoPick" then
				if not foundAutoPick then
					foundAutoPick = candidate
					autoContainer = offerContainer
				elseif not foundVip and candidate ~= foundAutoPick then
					-- Supports a duplicated HUD entry that has not yet been renamed to VIP.
					foundVip = candidate
					vipContainer = offerContainer
					local title = getTextObject(offerContainer or candidate, "Title")
					if title then
						title.Text = "VIP"
					end
				end
			end
		end
	end
	if foundAutoPick then
		bindButton("AutoPick", foundAutoPick, autoContainer or foundAutoPick)
	end
	if foundVip then
		bindButton("VIP", foundVip, vipContainer or foundVip)
	end
	uiBound = foundAutoPick ~= nil and foundVip ~= nil
	return foundAutoPick ~= nil or foundVip ~= nil
end

function GamePassController.Init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	remote = Remote.New("ColorGameEvent")
	tryBindUi(playerGui)
	playerGui.DescendantAdded:Connect(function()
		task.defer(tryBindUi, playerGui)
	end)
	task.delay(10, function()
		tryBindUi(playerGui)
		local details = diagnostic(playerGui)
		if not buttons.AutoPick or not buttons.AutoPick:IsDescendantOf(playerGui) then
			warn(`[ColorGame] AutoPick button was not recognized. Found: {details}`)
		end
		if not buttons.VIP or not buttons.VIP:IsDescendantOf(playerGui) then
			warn(`[ColorGame] VIP button was not recognized. Found: {details}`)
		end
	end)

	remote.OnClientEvent:Connect(function(action, ...)
		if action ~= "GamePassState" then
			return
		end
		local gamePassName, configured, owned, enabled, price = ...
		if type(gamePassName) ~= "string" then
			return
		end
		states[gamePassName] = {
			Configured = configured == true,
			Owned = owned == true,
			Enabled = enabled == true,
			Price = if type(price) == "number" then price else nil,
		}
		render(gamePassName)
	end)

	remote:FireServer("MonetizationReady")
end

return GamePassController
