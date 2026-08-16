--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)

local NpcAnimationController = {}

local initialized = false
local idleTrack: AnimationTrack? = nil
local smashTrack: AnimationTrack? = nil

local function getAnimator(target: Instance): Animator
	local existing = target:FindFirstChildWhichIsA("Animator", true)
	if existing then
		return existing
	end

	local humanoid = target:FindFirstChildWhichIsA("Humanoid", true)
	local controller = target:FindFirstChildWhichIsA("AnimationController", true)
	if not humanoid and not controller then
		controller = Instance.new("AnimationController")
		controller.Name = "ClientAnimationController"
		controller.Parent = target
	end

	local animator = Instance.new("Animator")
	animator.Parent = humanoid or controller
	return animator
end

local function loadTrack(
	animator: Animator,
	animation: Animation,
	looped: boolean,
	priority: Enum.AnimationPriority
): AnimationTrack?
	local ok, result = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok then
		warn(`[ColorGame] Client could not load {animation:GetFullName()}: {result}`)
		return nil
	end

	local track = result :: AnimationTrack
	track.Looped = looped
	track.Priority = priority
	return track
end

local function playSmash()
	local track = smashTrack
	if not track then
		return
	end
	if track.IsPlaying then
		track:Stop(0)
	end
	track.TimePosition = 0
	track:Play(0.08)
end

function NpcAnimationController.Init()
	if initialized then
		return
	end
	initialized = true

	local machine = workspace:WaitForChild("ScriptableParts"):WaitForChild("Machine")
	local npcActivator = machine:WaitForChild("NpcActivator")
	local animations = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Animations")
	local idleAnimation = animations:WaitForChild("Idle") :: Animation
	local smashAnimation = animations:WaitForChild("Smash") :: Animation
	local animator = getAnimator(npcActivator)

	idleTrack = loadTrack(animator, idleAnimation, true, Enum.AnimationPriority.Action)
	smashTrack = loadTrack(animator, smashAnimation, false, Enum.AnimationPriority.Action2)
	if idleTrack then
		idleTrack:Play(0.15)
	end

	local remote = Remote.New("ColorGameEvent")
	remote.OnClientEvent:Connect(function(action: string, ...: any)
		if action == "NpcAnimation" and select(1, ...) == "Smash" then
			playSmash()
		end
	end)
end

return NpcAnimationController
