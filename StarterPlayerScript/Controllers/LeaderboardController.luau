--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)

local LeaderboardController = {}

type Board = {
	ScrollingFrame: ScrollingFrame,
	Template: GuiObject,
	Kind: string,
}

local player = Players.LocalPlayer
local boards: { [string]: Board } = {}
local thumbnailCache: { [number]: string } = {}

local function setText(root: Instance, name: string, value: string)
	local object = root:FindFirstChild(name, true)
	if object and (object:IsA("TextLabel") or object:IsA("TextButton")) then
		object.Text = value
	end
end

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

local function clearRows(board: Board)
	for _, child in board.ScrollingFrame:GetChildren() do
		if child:GetAttribute("LeaderboardRow") == true then
			child:Destroy()
		end
	end
end

local function childSummary(parent: Instance): string
	local children = {}
	for _, child in parent:GetChildren() do
		table.insert(children, `[{child.Name}] ({child.ClassName})`)
	end
	table.sort(children)
	return if #children > 0 then table.concat(children, ", ") else "<none>"
end

local function loadAvatar(row: GuiObject, userId: number)
	local avatar = row:FindFirstChild("AvatarLabel", true)
	if not avatar or not avatar:IsA("ImageLabel") then
		return
	end
	local cached = thumbnailCache[userId]
	if cached then
		avatar.Image = cached
		return
	end
	task.spawn(function()
		local ok, image = pcall(
			Players.GetUserThumbnailAsync,
			Players,
			userId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size100x100
		)
		if ok and row.Parent and avatar.Parent then
			thumbnailCache[userId] = image
			avatar.Image = image
		end
	end)
end

local function render(board: Board, entries: any)
	clearRows(board)
	if type(entries) ~= "table" then
		return
	end
	for rank, entry in entries do
		if type(entry) == "table" and type(entry.UserId) == "number" then
			local row = board.Template:Clone()
			row.Name = `Rank_{rank}`
			row.LayoutOrder = rank
			row.Visible = true
			row:SetAttribute("LeaderboardRow", true)
			setText(row, "RankText", tostring(rank))
			setText(row, "NameLabel", tostring(entry.Name or `User {entry.UserId}`))
			local value = math.max(0, tonumber(entry.Value) or 0)
			local valueText = if board.Kind == "TopTime"
				then formatTime(value)
				elseif board.Kind == "TopStreak" then `{math.floor(value)} Streak`
				else `{math.floor(value)} Wins`
			setText(row, "ValueLabel", valueText)
			row.Parent = board.ScrollingFrame
			loadAvatar(row, entry.UserId)
		end
	end
end

local function findBoard(viewWindow: Instance, kind: string, interfaceName: string?): Board?
	local model = viewWindow:WaitForChild(kind, 10)
	if not model then
		warn(`[ColorGame] Missing ViewWindow.{kind} leaderboard model`)
		return nil
	end

	local expectedNames = { interfaceName or `${kind}BoardUI`, "Root", "BoardFrame", kind, "ScrollingFrame", "Template" }
	local current: Instance = model
	local exactPathValid = false
	local missingName = ""
	local missingParent: Instance = model
	local deadline = os.clock() + 10
	repeat
		current = model
		exactPathValid = true
		for _, expectedName in expectedNames do
			local child = current:FindFirstChild(expectedName)
			if not child then
				exactPathValid = false
				missingName = expectedName
				missingParent = current
				break
			end
			current = child
		end
		if not exactPathValid then
			task.wait(0.2)
		end
	until exactPathValid or os.clock() >= deadline

	if not exactPathValid then
		warn(
			`[ColorGame] Missing [{missingName}] under {missingParent:GetFullName()}. Actual children: {childSummary(missingParent)}`
		)
	end

	local scrolling: Instance? = nil
	local template: Instance? = nil
	if exactPathValid then
		template = current
		scrolling = template.Parent
	else
		-- Allows harmless extra wrapper Frames while still requiring the uniquely
		-- named ScrollingFrame and Template belonging to this board model.
		scrolling = model:FindFirstChild("ScrollingFrame", true)
		template = scrolling and scrolling:FindFirstChild("Template", true)
	end

	if not scrolling then
		warn(`[ColorGame] {model:GetFullName()} has no descendant named ScrollingFrame`)
		return nil
	elseif not scrolling:IsA("ScrollingFrame") then
		warn(`[ColorGame] {scrolling:GetFullName()} is {scrolling.ClassName}; it must be a ScrollingFrame`)
		return nil
	elseif not template then
		warn(`[ColorGame] {scrolling:GetFullName()} has no descendant named Template. Children: {childSummary(scrolling)}`)
		return nil
	elseif not template:IsA("GuiObject") then
		warn(`[ColorGame] {template:GetFullName()} is {template.ClassName}; Template must be a GuiObject such as Frame`)
		return nil
	end
	template.Visible = false
	return {
		ScrollingFrame = scrolling,
		Template = template,
		Kind = kind,
	}
end

function LeaderboardController.Init()
	local viewWindow = workspace:WaitForChild("ScriptableParts"):WaitForChild("ViewWindow")
	local topTime = findBoard(viewWindow, "TopTime")
	local topStreak = findBoard(viewWindow, "TopStreak", "TopTimeBoardUI")
	local topWins = findBoard(viewWindow, "TopWin")
	if topTime then
		boards.TopTime = topTime
	end
	if topWins then
		boards.TopWins = topWins
	end
	if topStreak then
		boards.TopStreak = topStreak
	end

	local remote = Remote.New("ColorGameEvent")
	remote.OnClientEvent:Connect(function(action: string, snapshot: any)
		if action ~= "LeaderboardSnapshot" or type(snapshot) ~= "table" then
			return
		end
		if boards.TopTime then
			render(boards.TopTime, snapshot.TopTime)
		end
		if boards.TopWins then
			render(boards.TopWins, snapshot.TopWins)
		end
		if boards.TopStreak then
			render(boards.TopStreak, snapshot.TopStreak)
		end
	end)
	remote:FireServer("LeaderboardReady")
	task.delay(1, function()
		remote:FireServer("LeaderboardReady")
	end)
end

return LeaderboardController
