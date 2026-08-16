--!strict

local PusherService = {}

local pusher: BasePart
local startCFrame: CFrame
local endCFrame: CFrame
local travelDuration = 0.45
local alignPosition: AlignPosition
local alignOrientation: AlignOrientation

local function followPath(root: Instance, path: { string }): Instance
	local current = root
	for _, name in path do
		current = current:WaitForChild(name)
	end
	return current
end

function PusherService.Init(config)
	local machine = followPath(workspace, config.MachinePath)
	local instance = machine:WaitForChild("PusherPart")
	assert(instance:IsA("BasePart"), "[ColorGame] Machine.PusherPart must be a BasePart")
	pusher = instance
	travelDuration = config.PusherTravelDuration
	pusher.Anchored = false
	pusher.Massless = false

	local attachment = pusher:FindFirstChild("ColorGamePusherAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		attachment = Instance.new("Attachment")
		attachment.Name = "ColorGamePusherAttachment"
		attachment.Parent = pusher
	end

	local positionConstraint = pusher:FindFirstChild("ColorGameAlignPosition")
	if not positionConstraint or not positionConstraint:IsA("AlignPosition") then
		positionConstraint = Instance.new("AlignPosition")
		positionConstraint.Name = "ColorGameAlignPosition"
		positionConstraint.Parent = pusher
	end
	alignPosition = positionConstraint
	alignPosition.Attachment0 = attachment
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.ApplyAtCenterOfMass = true
	alignPosition.MaxForce = 1_000_000_000
	alignPosition.Responsiveness = 200
	alignPosition.RigidityEnabled = false

	local orientationConstraint = pusher:FindFirstChild("ColorGameAlignOrientation")
	if not orientationConstraint or not orientationConstraint:IsA("AlignOrientation") then
		orientationConstraint = Instance.new("AlignOrientation")
		orientationConstraint.Name = "ColorGameAlignOrientation"
		orientationConstraint.Parent = pusher
	end
	alignOrientation = orientationConstraint
	alignOrientation.Attachment0 = attachment
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.MaxTorque = 1_000_000_000
	alignOrientation.MaxAngularVelocity = math.huge
	alignOrientation.Responsiveness = 200
	alignOrientation.RigidityEnabled = false

	local rotation = pusher.CFrame.Rotation
	startCFrame = CFrame.new(config.PusherStartPosition) * rotation
	endCFrame = CFrame.new(config.PusherEndPosition) * rotation
	alignPosition.MaxVelocity = (config.PusherStartPosition - config.PusherEndPosition).Magnitude / travelDuration
	alignOrientation.CFrame = rotation
	PusherService.Reset()
end

function PusherService.Reset()
	pusher.CFrame = startCFrame
	pusher.AssemblyLinearVelocity = Vector3.zero
	pusher.AssemblyAngularVelocity = Vector3.zero
	alignPosition.Position = startCFrame.Position
	alignOrientation.CFrame = startCFrame.Rotation
end

function PusherService.Push()
	alignPosition.Position = endCFrame.Position
	alignOrientation.CFrame = endCFrame.Rotation
	task.wait(travelDuration)
end

return PusherService
