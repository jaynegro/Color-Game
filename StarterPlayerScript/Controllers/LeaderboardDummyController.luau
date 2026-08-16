--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)

local LeaderboardDummyController = {}

local spawners: { [string]: BasePart } = {}
local dummies: { [string]: Model } = {}
local shownUserIds: { [string]: number } = {}
local generations: { [string]: number } = {}
local clientFolder: Folder
local overheadTemplate: Instance

local FRAME_BY_KIND = {
	TopWins = "WinFrame",
	TopTime = "TimeFrame",
	TopStreak = "StreakFrame",
}

local VALUE_BY_KIND = {
	TopWins = "Win",
	TopTime = "Time",
	TopStreak = "Streak",
}

local function formatTime(totalSeconds: number): string
	totalSeconds = math.max(0, math.floor(totalSeconds))
	local days = math.floor(totalSeconds / 86400)
	local hours = math.floor(totalSeconds % 86400 / 3600)
	local minutes = math.floor(totalSeconds % 3600 / 60)
	if days > 0 then
		return `{days}d {hours}h`
	elseif hours > 0 then
		return `{hours}h {minutes}m`
	end
	return `{minutes}m`
end

local function setText(root: Instance, name: string, value: string)
	local object = root:FindFirstChild(name, true)
	if object and (object:IsA("TextLabel") or object:IsA("TextButton")) then
		object.Text = value
	end
end

local function updateOverhead(model: Model, kind: string, entry: any)
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local overhead = head:FindFirstChild("DummyOverHead")
	if not overhead then
		overhead = overheadTemplate:Clone()
		overhead.Name = "DummyOverHead"
		overhead.Parent = head
	end
	local billboardInstance = if overhead:IsA("BillboardGui")
		then overhead
		else overhead:FindFirstChildWhichIsA("BillboardGui", true)
	if billboardInstance and billboardInstance:IsA("BillboardGui") then
		billboardInstance.Enabled = true
	end

	setText(overhead, "NameLabel", tostring(entry.Name or `User {entry.UserId}`))
	for _, frameName in { "WinFrame", "TimeFrame", "StreakFrame" } do
		local frame = overhead:FindFirstChild(frameName, true)
		if frame and frame:IsA("GuiObject") then
			frame.Visible = frameName == FRAME_BY_KIND[kind]
		end
	end
	local value = math.max(0, tonumber(entry.Value) or 0)
	local valueText = if kind == "TopTime" then formatTime(value) else tostring(math.floor(value))
	setText(overhead, VALUE_BY_KIND[kind], valueText)
end

local function destroyDummy(kind: string)
	local dummy = dummies[kind]
	if dummy then
		dummies[kind] = nil
		dummy:Destroy()
	end
	shownUserIds[kind] = nil
end

local function prepare(model: Model): (Humanoid, BasePart, Animator)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		error("R15 leaderboard dummy is missing Humanoid or HumanoidRootPart")
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant == root
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = descendant ~= root
		end
	end
	humanoid.AutoRotate = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local oldAnimator = humanoid:FindFirstChildOfClass("Animator")
	if oldAnimator then
		oldAnimator:Destroy()
	end
	local animator = Instance.new("Animator")
	animator.Parent = humanoid
	model.PrimaryPart = root
	return humanoid, root, animator
end

local function animate(model: Model, animator: Animator, animationId: number)
	local animation = Instance.new("Animation")
	animation.AnimationId = `rbxassetid://{animationId}`
	local ok, trackOrProblem = pcall(animator.LoadAnimation, animator, animation)
	animation:Destroy()
	if not ok then
		warn(`[ColorGame] Failed to load local leaderboard Animation {animationId}: {trackOrProblem}`)
		return
	end
	local track = trackOrProblem :: AnimationTrack
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = true
	track:Play(0, 1, 1)
	task.delay(5, function()
		if model.Parent and track.Length <= 0 then
			warn(
				`[ColorGame] Animation {animationId} data did not load. Verify that its owner matches the experience owner.`
			)
		end
	end)
end

local function updateDummy(kind: string, entry: any, animationId: number)
	local userId = if type(entry) == "table" then tonumber(entry.UserId) else nil
	if userId and shownUserIds[kind] == userId and dummies[kind] and dummies[kind].Parent then
		updateOverhead(dummies[kind], kind, entry)
		return
	end
	generations[kind] = (generations[kind] or 0) + 1
	local generation = generations[kind]
	destroyDummy(kind)
	if not userId or animationId <= 0 then
		return
	end

	task.spawn(function()
		local ok, modelOrProblem = pcall(function()
			local description = Players:GetHumanoidDescriptionFromUserId(userId)
			return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
		end)
		if not ok then
			warn(`[ColorGame] Client failed to create {kind} R15 dummy for {userId}: {modelOrProblem}`)
			return
		end
		local model = modelOrProblem :: Model
		if generation ~= generations[kind] then
			model:Destroy()
			return
		end
		local prepared, humanoidOrProblem, root, animator = pcall(prepare, model)
		if not prepared then
			model:Destroy()
			warn(`[ColorGame] Client failed to prepare {kind} dummy: {humanoidOrProblem}`)
			return
		end
		local humanoid = humanoidOrProblem :: Humanoid
		local typedRoot = root :: BasePart
		model.Name = `{kind}Leader_{userId}`
		model.Parent = clientFolder
		local spawner = spawners[kind]
		local height = humanoid.HipHeight + typedRoot.Size.Y * 0.5
		model:PivotTo(spawner.CFrame * CFrame.new(0, spawner.Size.Y * 0.5 + height, 0))
		dummies[kind] = model
		shownUserIds[kind] = userId
		updateOverhead(model, kind, entry)
		animate(model, animator :: Animator, animationId)
	end)
end

function LeaderboardDummyController.Init()
	overheadTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("UI"):WaitForChild("DummyOverHeadTemplate")
	local folder = workspace:WaitForChild("ScriptableParts"):WaitForChild("LeaderboardDummies")
	local winSpawner = folder:WaitForChild("WinSpawner")
	local timeSpawner = folder:WaitForChild("TimeSpawner")
	local streakSpawner = folder:WaitForChild("StreakSpawner")
	assert(winSpawner:IsA("BasePart"), "[ColorGame] WinSpawner must be a BasePart")
	assert(timeSpawner:IsA("BasePart"), "[ColorGame] TimeSpawner must be a BasePart")
	assert(streakSpawner:IsA("BasePart"), "[ColorGame] StreakSpawner must be a BasePart")
	spawners.TopWins = winSpawner
	spawners.TopTime = timeSpawner
	spawners.TopStreak = streakSpawner

	clientFolder = Instance.new("Folder")
	clientFolder.Name = "ClientLeaderboardDummies"
	clientFolder.Parent = folder

	local remote = Remote.New("ColorGameEvent")
	remote.OnClientEvent:Connect(function(action: string, snapshot: any)
		if action ~= "LeaderboardSnapshot" or type(snapshot) ~= "table" then
			return
		end
		local animationId = tonumber(snapshot.AnimationId) or 0
		local topWins = if type(snapshot.TopWins) == "table" then snapshot.TopWins[1] else nil
		local topTime = if type(snapshot.TopTime) == "table" then snapshot.TopTime[1] else nil
		local topStreak = if type(snapshot.TopStreak) == "table" then snapshot.TopStreak[1] else nil
		updateDummy("TopWins", topWins, animationId)
		updateDummy("TopTime", topTime, animationId)
		updateDummy("TopStreak", topStreak, animationId)
	end)
	remote:FireServer("LeaderboardReady")
	task.delay(1, function()
		remote:FireServer("LeaderboardReady")
	end)
end

return LeaderboardDummyController
