--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)

local MobileJumpController = {}

local player = Players.LocalPlayer
local characterConnections: { RBXScriptConnection } = {}
local currentHumanoid: Humanoid? = nil
local refreshGeneration = 0

local function disconnectCharacterConnections()
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	table.clear(characterConnections)
end

local function findJumpButton(): GuiObject?
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
	if not touchGui then
		return nil
	end
	local jumpButton = touchGui:FindFirstChild("JumpButton", true)
	return if jumpButton and jumpButton:IsA("GuiObject") then jumpButton else nil
end

local function refreshJumpButton()
	if not UserInputService.TouchEnabled then
		return
	end

	refreshGeneration += 1
	local generation = refreshGeneration
	task.defer(function()
		if generation ~= refreshGeneration then
			return
		end
		local humanoid = currentHumanoid
		local character = humanoid and humanoid.Parent
		if not humanoid or not character or humanoid.Health <= 0 or character:GetAttribute("Ragdoll") == true then
			return
		end

		-- Pulsing the enabled state makes Roblox's TouchJump module recalculate
		-- visibility after a forced Seat -> GettingUp -> Seat sequence.
		if humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping) then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
			task.defer(function()
				if currentHumanoid == humanoid and humanoid.Parent and character:GetAttribute("Ragdoll") ~= true then
					humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
					local jumpButton = findJumpButton()
					if jumpButton then
						jumpButton.Visible = true
					end
				end
			end)
		end

		-- Recover only invalid zero values left by an interrupted movement lock.
		if humanoid.JumpPower <= 0 then
			humanoid.JumpPower = StarterPlayer.CharacterJumpPower
		end
		if humanoid.JumpHeight <= 0 then
			humanoid.JumpHeight = StarterPlayer.CharacterJumpHeight
		end
	end)
end

local function bindCharacter(character: Model)
	disconnectCharacterConnections()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	currentHumanoid = humanoid

	table.insert(characterConnections, humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
		if currentHumanoid == humanoid and humanoid.SeatPart == nil then
			task.delay(0.1, refreshJumpButton)
		end
	end))
	table.insert(characterConnections, character:GetAttributeChangedSignal("Ragdoll"):Connect(function()
		if character:GetAttribute("Ragdoll") ~= true then
			task.delay(0.1, refreshJumpButton)
		end
	end))
end

function MobileJumpController.Init()
	if not UserInputService.TouchEnabled then
		return
	end

	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)

	local event = Remote.New("ColorGameEvent")
	event.OnClientEvent:Connect(function(action)
		if action == "SeatLockEnded" or action == "SeatReleased" then
			refreshJumpButton()
		end
	end)
end

return MobileJumpController
