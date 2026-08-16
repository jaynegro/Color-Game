--!strict

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local FollowPart = (Character:FindFirstChild("UpperTorso")
	or Character:FindFirstChild("Torso")
	or Character:FindFirstChild("LowerTorso")
	or Character:WaitForChild("HumanoidRootPart")) :: BasePart

local MOVEMENT_ACTION = "DisableMovement"
local DefaultWalkSpeed = Humanoid.WalkSpeed
local DefaultJumpPower = Humanoid.JumpPower
local DefaultJumpHeight = Humanoid.JumpHeight

local function DisableMovement(actionName: string, inputState: Enum.UserInputState, inputObject: InputObject)
	return Enum.ContextActionResult.Sink
end

-- Lock or unlock player movement
local function ApplyRagdollInputLock(IsRagdolled: boolean)
	if IsRagdolled then
		ContextActionService:BindActionAtPriority(
			MOVEMENT_ACTION,
			DisableMovement,
			false,
			Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.W,
			Enum.KeyCode.A,
			Enum.KeyCode.S,
			Enum.KeyCode.D,
			Enum.KeyCode.Space
		)
		Humanoid.WalkSpeed = 0
		Humanoid.JumpPower = 0
	else
		ContextActionService:UnbindAction(MOVEMENT_ACTION)
		Humanoid.WalkSpeed = DefaultWalkSpeed
		Humanoid.JumpPower = DefaultJumpPower
		Humanoid.JumpHeight = DefaultJumpHeight
	end
end

local function UpdateCameraFollow()
	if Character:GetAttribute("Ragdoll") then
		Camera.CameraSubject = FollowPart
	else
		Camera.CameraSubject = Humanoid
	end
end

Character:GetAttributeChangedSignal("Ragdoll"):Connect(function()
	local ragdollState = Character:GetAttribute("Ragdoll") == true
	
	ApplyRagdollInputLock(ragdollState)
	UpdateCameraFollow()
end)

ApplyRagdollInputLock(Character:GetAttribute("Ragdoll") == true)
UpdateCameraFollow()
