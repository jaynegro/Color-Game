--!strict

local AnimationUtil = {}

local function getAnimator(target: Instance): Animator?
	local animator = target:FindFirstChildWhichIsA("Animator", true)
	if animator then
		return animator
	end

	local humanoid = target:FindFirstChildWhichIsA("Humanoid", true)
	if humanoid then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
		return animator
	end

	local controller = target:FindFirstChildWhichIsA("AnimationController", true)
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Name = "AnimationController"
		controller.Parent = target
	end

	animator = Instance.new("Animator")
	animator.Parent = controller
	return animator
end

function AnimationUtil.Play(
	target: Instance,
	animation: Animation,
	looped: boolean?,
	priority: Enum.AnimationPriority?
): AnimationTrack?
	local animator = getAnimator(target)
	if not animator then
		warn(`[ColorGame] No Animator could be created for {target:GetFullName()}`)
		return nil
	end

	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok then
		warn(`[ColorGame] Failed to load {animation:GetFullName()}: {track}`)
		return nil
	end

	local animationTrack = track :: AnimationTrack
	if looped ~= nil then
		animationTrack.Looped = looped
	end
	if priority then
		animationTrack.Priority = priority
	end
	animationTrack:Play(0.1)
	return animationTrack
end

function AnimationUtil.WaitForMarkerOrStop(track: AnimationTrack?, markerName: string, timeout: number): boolean
	if not track then
		return false
	end

	local completed = Instance.new("BindableEvent")
	local resolved = false
	local markerReached = false
	local connections: { RBXScriptConnection } = {}

	local function resolve(wasMarker: boolean)
		if resolved then
			return
		end
		resolved = true
		markerReached = wasMarker
		completed:Fire()
	end

	table.insert(connections, track:GetMarkerReachedSignal(markerName):Connect(function()
		resolve(true)
	end))
	table.insert(connections, track.Stopped:Connect(function()
		resolve(false)
	end))
	task.delay(timeout, resolve, false)
	completed.Event:Wait()

	for _, connection in connections do
		connection:Disconnect()
	end
	completed:Destroy()
	return markerReached
end

function AnimationUtil.WaitForStop(track: AnimationTrack?, timeout: number)
	if not track or not track.IsPlaying then
		return
	end

	local completed = Instance.new("BindableEvent")
	local resolved = false
	local connection: RBXScriptConnection?
	local function resolve()
		if resolved then
			return
		end
		resolved = true
		completed:Fire()
	end

	connection = track.Stopped:Connect(resolve)
	task.delay(timeout, resolve)
	completed.Event:Wait()
	if connection then
		connection:Disconnect()
	end
	completed:Destroy()
end

return AnimationUtil
