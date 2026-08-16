--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationUtil = require(script.Parent.AnimationUtil)

local MachineAnimationService = {}

local idleTrack: AnimationTrack? = nil

local function followPath(root: Instance, path: { string }): Instance
	local current = root
	for _, name in path do
		current = current:WaitForChild(name)
	end
	return current
end

function MachineAnimationService.Init(config)
	local machine = followPath(workspace, config.MachinePath)
	local animations = followPath(ReplicatedStorage, config.AnimationsPath)
	local npcActivator = machine:WaitForChild("NpcActivator")
	local idleAnimation = animations:WaitForChild("Idle")
	assert(idleAnimation:IsA("Animation"), "[ColorGame] Assets.Animations.Idle must be an Animation")

	idleTrack = AnimationUtil.Play(
		npcActivator,
		idleAnimation,
		true,
		Enum.AnimationPriority.Action
	)
	if not idleTrack then
		warn("[ColorGame] NpcActivator Idle animation could not be started")
	end
end

function MachineAnimationService.GetIdleTrack(): AnimationTrack?
	return idleTrack
end

return MachineAnimationService
