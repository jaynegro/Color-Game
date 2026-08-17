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
local topEffectTemplate: Instance
local RANK_ICON_IMAGE = "rbxassetid://108040974470585"

local function attachTopEffect(model: Model)
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
	if not head or not head:IsA("BasePart") or not torso or not torso:IsA("BasePart") then
		return
	end

	if not head:FindFirstChild("ColorGameTop1HeadAttachment") then
		local headTemplate = topEffectTemplate:FindFirstChild("HeadAttachment")
		if headTemplate then
			local attachment = headTemplate:Clone()
			attachment.Name = "ColorGameTop1HeadAttachment"
			attachment.Parent = head
		end
	end
	if not torso:FindFirstChild("ColorGameTop1TorsoAttachment") then
		local torsoTemplate = topEffectTemplate:FindFirstChild("TorsoAttachment")
		if torsoTemplate then
			local attachment = torsoTemplate:Clone()
			attachment.Name = "ColorGameTop1TorsoAttachment"
			attachment.Parent = torso
		end
	end
end

local FRAME_BY_KIND = {
	TopWins = "WinFrame",
	TopTime = "TimeFrame",
	TopStreak = "StreakFrame",
	TopRank1 = "RankFrame",
	TopRank2 = "RankFrame",
	TopRank3 = "RankFrame",
}

local VALUE_BY_KIND = {
	TopWins = "Win",
	TopTime = "Time",
	TopStreak = "Streak",
	TopRank1 = "RankText",
	TopRank2 = "RankText",
	TopRank3 = "RankText",
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

local function ensureRankFrame(billboard: BillboardGui): Frame
	local frame = billboard:FindFirstChild("RankFrame")
	if frame and frame:IsA("Frame") then
		return frame
	end
	if frame then
		frame:Destroy()
	end

	frame = Instance.new("Frame")
	frame.Name = "RankFrame"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Visible = false
	frame.Parent = billboard

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = frame

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Image = RANK_ICON_IMAGE
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromOffset(34, 34)
	icon.Parent = frame

	local text = Instance.new("TextLabel")
	text.Name = "RankText"
	text.BackgroundTransparency = 1
	text.BorderSizePixel = 0
	text.Size = UDim2.fromOffset(54, 34)
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextStrokeTransparency = 0
	text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Center
	text.Text = "1"
	text.Parent = frame

	return frame
end

local function updateOverhead(model: Model, kind: string, entry: any, rankPosition: number?)
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
	local rankFrame = if billboardInstance then ensureRankFrame(billboardInstance) else nil
	for _, frameName in { "WinFrame", "TimeFrame", "StreakFrame", "RankFrame" } do
		local frame = overhead:FindFirstChild(frameName, true)
		if frame and frame:IsA("GuiObject") then
			frame.Visible = frameName == FRAME_BY_KIND[kind]
		end
	end
	if rankFrame and (kind == "TopRank1" or kind == "TopRank2" or kind == "TopRank3") then
		rankFrame.Visible = true
		local rankText = rankFrame:FindFirstChild("RankText")
		local icon = rankFrame:FindFirstChild("Icon")
		if rankText and (rankText:IsA("TextLabel") or rankText:IsA("TextButton")) then
			rankText.Text = tostring(rankPosition or 1)
		end
		if icon and icon:IsA("ImageLabel") then
			icon.Image = RANK_ICON_IMAGE
		end
		for _, childName in { "Win", "Time", "Streak" } do
			setText(overhead, childName, "")
		end
	else
		local value = math.max(0, tonumber(entry.Value) or 0)
		local valueText = if kind == "TopTime" then formatTime(value) else tostring(math.floor(value))
		setText(overhead, VALUE_BY_KIND[kind], valueText)
	end
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

local function updateDummy(kind: string, entry: any, animationId: number, rankPosition: number?)
	local userId = if type(entry) == "table" then tonumber(entry.UserId) else nil
	if userId and shownUserIds[kind] == userId and dummies[kind] and dummies[kind].Parent then
		attachTopEffect(dummies[kind])
		updateOverhead(dummies[kind], kind, entry, rankPosition)
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
		attachTopEffect(model)
		updateOverhead(model, kind, entry, rankPosition)
		animate(model, animator :: Animator, animationId)
	end)
end

function LeaderboardDummyController.Init()
	local assets = ReplicatedStorage:WaitForChild("Assets")
	overheadTemplate = assets:WaitForChild("UI"):WaitForChild("DummyOverHeadTemplate")
	topEffectTemplate = assets:WaitForChild("Fx"):WaitForChild("Top1")
	local folder = workspace:WaitForChild("ScriptableParts"):WaitForChild("LeaderboardDummies")
	local winSpawner = folder:WaitForChild("WinSpawner")
	local timeSpawner = folder:WaitForChild("TimeSpawner")
	local streakSpawner = folder:WaitForChild("StreakSpawner")
	local rankSpawner1 = folder:WaitForChild("RankSpawner1")
	local rankSpawner2 = folder:WaitForChild("RankSpawner2")
	local rankSpawner3 = folder:WaitForChild("RankSpawner3")
	assert(winSpawner:IsA("BasePart"), "[ColorGame] WinSpawner must be a BasePart")
	assert(timeSpawner:IsA("BasePart"), "[ColorGame] TimeSpawner must be a BasePart")
	assert(streakSpawner:IsA("BasePart"), "[ColorGame] StreakSpawner must be a BasePart")
	assert(rankSpawner1:IsA("BasePart"), "[ColorGame] RankSpawner1 must be a BasePart")
	assert(rankSpawner2:IsA("BasePart"), "[ColorGame] RankSpawner2 must be a BasePart")
	assert(rankSpawner3:IsA("BasePart"), "[ColorGame] RankSpawner3 must be a BasePart")
	spawners.TopWins = winSpawner
	spawners.TopTime = timeSpawner
	spawners.TopStreak = streakSpawner
	spawners.TopRank1 = rankSpawner1
	spawners.TopRank2 = rankSpawner2
	spawners.TopRank3 = rankSpawner3

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
		local topRank = if type(snapshot.TopRank) == "table" then snapshot.TopRank else {}
		updateDummy("TopWins", topWins, animationId)
		updateDummy("TopTime", topTime, animationId)
		updateDummy("TopStreak", topStreak, animationId)
		updateDummy("TopRank1", topRank[1], animationId, 1)
		updateDummy("TopRank2", topRank[2], animationId, 2)
		updateDummy("TopRank3", topRank[3], animationId, 3)
	end)
	remote:FireServer("LeaderboardReady")
	task.delay(1, function()
		remote:FireServer("LeaderboardReady")
	end)
end

return LeaderboardDummyController
