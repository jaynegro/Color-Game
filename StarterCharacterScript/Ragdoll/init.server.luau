--!strict

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Shared.Config.Config)
if not Config.RagdollEnabled then
	return
end

local Character = script.Parent
local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart") :: BasePart
local RootBody = (Character:FindFirstChild("LowerTorso")
	or Character:FindFirstChild("Torso")
	or Character:FindFirstChild("UpperTorso")) :: BasePart?

if not RootBody then
	warn(`[ColorGame] Cannot initialize ragdoll for {Character:GetFullName()}: no torso body part`)
	return
end

local COLLISION_GROUP = "ColorGameRagdoll"
pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, COLLISION_GROUP)
PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, false)

local GENERATED_NAMES: { [string]: boolean } = {
	RagdollAttachment = true,
	RagdollConstraint = true,
	RagdollCollider = true,
	RagdollColliderWeld = true,
}

local RootWeld = Instance.new("WeldConstraint")
RootWeld.Name = "RagdollRootWeld"
RootWeld.Part0 = HumanoidRootPart
RootWeld.Part1 = RootBody
RootWeld.Enabled = false
RootWeld.Parent = RootBody

local defaultRequiresNeck = Humanoid.RequiresNeck
Character:SetAttribute("Ragdoll", false)
Character:SetAttribute("LastRag", 0)

local function createCollider(bodyPart: BasePart)
	if bodyPart == HumanoidRootPart or bodyPart:FindFirstChild("RagdollCollider") then
		return
	end
	local collider = Instance.new("Part")
	collider.Name = "RagdollCollider"
	collider.Size = Vector3.new(
		math.max(bodyPart.Size.X / 1.7, 0.2),
		math.max(bodyPart.Size.Y / 1.7, 0.2),
		math.max(bodyPart.Size.Z / 1.7, 0.2)
	)
	collider.CFrame = bodyPart.CFrame
	collider.Transparency = 1
	collider.Massless = true
	collider.Anchored = false
	collider.CanCollide = true
	collider.CanTouch = false
	collider.CanQuery = false
	collider.CollisionGroup = COLLISION_GROUP

	local weld = Instance.new("WeldConstraint")
	weld.Name = "RagdollColliderWeld"
	weld.Part0 = collider
	weld.Part1 = bodyPart
	weld.Parent = collider
	collider.Parent = bodyPart
end

local function createConstraint(motor: Motor6D)
	local part0 = motor.Part0
	local part1 = motor.Part1
	if not part0 or not part1 then
		return
	end
	-- The root stays attached through RootWeld so the network root follows
	-- the physical body without adding a second loose constraint.
	if part0 == HumanoidRootPart or part1 == HumanoidRootPart then
		return
	end

	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "RagdollAttachment"
	attachment0.CFrame = motor.C0
	attachment0.Parent = part0

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "RagdollAttachment"
	attachment1.CFrame = motor.C1
	attachment1.Parent = part1

	local socket = Instance.new("BallSocketConstraint")
	socket.Name = "RagdollConstraint"
	socket.Attachment0 = attachment0
	socket.Attachment1 = attachment1
	socket.Radius = 0.15
	socket.LimitsEnabled = true
	socket.UpperAngle = if motor.Name == "Neck" then 45 else 90
	socket.TwistLimitsEnabled = true
	socket.TwistLowerAngle = if motor.Name == "Neck" then -70 else -45
	socket.TwistUpperAngle = if motor.Name == "Neck" then 70 else 45
	socket.MaxFrictionTorque = 0
	socket.Restitution = 0
	socket.Parent = motor.Parent
end

local function enableRagdoll()
	Humanoid.AutoRotate = false
	Humanoid.RequiresNeck = false
	Humanoid.PlatformStand = true
	Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	Character:SetAttribute("LastRag", workspace:GetServerTimeNow())
	RootWeld.Enabled = true

	for _, descendant in Character:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Part0 and descendant.Part1 then
			createConstraint(descendant)
			descendant.Enabled = false
		end
	end
	for _, child in Character:GetChildren() do
		if child:IsA("BasePart") then
			createCollider(child)
		end
	end
end

local function disableRagdoll()
	if Humanoid.Health <= 0 then
		return
	end
	local recoveryCFrame = RootBody.CFrame

	for _, descendant in Character:GetDescendants() do
		if GENERATED_NAMES[descendant.Name] then
			descendant:Destroy()
		elseif descendant:IsA("Motor6D") then
			descendant.Enabled = true
		end
	end

	RootWeld.Enabled = false
	HumanoidRootPart.CFrame = recoveryCFrame + Vector3.new(0, 2, 0)
	Humanoid.RequiresNeck = defaultRequiresNeck
	Humanoid.PlatformStand = false
	Humanoid.AutoRotate = true
	Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
end

local function updateRagdoll()
	if Character:GetAttribute("Ragdoll") == true then
		enableRagdoll()
	else
		disableRagdoll()
	end
end

Character:GetAttributeChangedSignal("Ragdoll"):Connect(updateRagdoll)
Humanoid.Died:Once(function()
	Character:SetAttribute("Ragdoll", true)
end)
