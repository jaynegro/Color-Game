--!strict

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local UIEffectsController = {}

local bound: { [GuiButton]: boolean } = {}
local lastHoverAt = 0

local function play(name: string)
	local sfx = SoundService:FindFirstChild("SFX")
	local source = sfx and sfx:FindFirstChild(name)
	if not source or not source:IsA("Sound") then
		return
	end
	local sound = source:Clone()
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, math.max(sound.TimeLength + 1, 3))
end

local function usable(button: GuiButton): boolean
	return button.Visible and button.Active and button.Interactable
end

local function bind(button: GuiButton)
	if bound[button] then
		return
	end
	bound[button] = true
	button.Destroying:Once(function()
		bound[button] = nil
	end)
	button.MouseEnter:Connect(function()
		if not usable(button) then
			return
		end
		local now = os.clock()
		if now - lastHoverAt >= 0.04 then
			lastHoverAt = now
			play("UI_Hover")
		end
	end)
	button.Activated:Connect(function()
		if usable(button) then
			play("UI_Click")
		end
	end)
end

function UIEffectsController.Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, descendant in playerGui:GetDescendants() do
		if descendant:IsA("GuiButton") then
			bind(descendant)
		end
	end
	playerGui.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("GuiButton") then
			bind(descendant)
		end
	end)
end

return UIEffectsController
