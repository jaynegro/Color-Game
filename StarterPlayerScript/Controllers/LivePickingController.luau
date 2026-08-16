--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)

local LivePickingController = {}

type CardInfo = {
	Card: Instance,
	ScrollingFrame: ScrollingFrame,
	Template: GuiObject,
	PlayerCount: TextLabel,
}

local cards: { [string]: CardInfo } = {}
local entries: { [number]: { Choice: string, Gui: GuiObject } } = {}
local thumbnailCache: { [number]: string } = {}
local timerText: TextLabel
local timerGeneration = 0

local function findInterface(): Instance
	local livePicking = workspace:WaitForChild("ScriptableParts"):WaitForChild("ViewWindow"):WaitForChild("LivePicking")
	return livePicking:WaitForChild("ColorGameBoardUI")
end

local function updateCount(choice: string)
	local card = cards[choice]
	if not card then
		return
	end
	local count = 0
	for _, entry in entries do
		if entry.Choice == choice then
			count += 1
		end
	end
	card.PlayerCount.Text = tostring(count)
end

local function removeEntry(userId: number)
	local oldEntry = entries[userId]
	if not oldEntry then
		return
	end
	entries[userId] = nil
	if oldEntry.Gui.Parent then
		oldEntry.Gui:Destroy()
	end
	updateCount(oldEntry.Choice)
end

local function setAvatar(gui: GuiObject, userId: number)
	local image = gui:FindFirstChild("ImageLabel", true)
	if not image or not image:IsA("ImageLabel") then
		return
	end

	local cached = thumbnailCache[userId]
	if cached then
		image.Image = cached
		return
	end

	task.spawn(function()
		local ok, content = pcall(
			Players.GetUserThumbnailAsync,
			Players,
			userId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size100x100
		)
		if not ok then
			warn(`[ColorGame] Could not load avatar for user {userId}: {content}`)
			return
		end
		thumbnailCache[userId] = content
		local current = entries[userId]
		if current and current.Gui == gui and gui.Parent and image.Parent then
			image.Image = content
		end
	end)
end

local function setPick(userId: number, choice: string?)
	removeEntry(userId)
	if not choice then
		return
	end

	local card = cards[choice]
	if not card then
		-- The current UI has no card for special picks such as Rainbow.
		return
	end
	local clone = card.Template:Clone()
	clone.Name = `Player_{userId}`
	clone.Visible = true
	clone:SetAttribute("LivePickUserId", userId)
	clone.Parent = card.ScrollingFrame
	entries[userId] = {
		Choice = choice,
		Gui = clone,
	}
	setAvatar(clone, userId)
	updateCount(choice)
end

local function clearEntries()
	local userIds = {}
	for userId in entries do
		table.insert(userIds, userId)
	end
	for _, userId in userIds do
		removeEntry(userId)
	end
end

local function applySnapshot(snapshot: any)
	if type(snapshot) ~= "table" then
		return
	end
	clearEntries()
	for _, item in snapshot do
		if type(item) == "table" and type(item.UserId) == "number" and type(item.Choice) == "string" then
			setPick(item.UserId, item.Choice)
		end
	end
end

local function startTimer(state: string, endsAt: number)
	timerGeneration += 1
	local generation = timerGeneration
	if state ~= "Picking" then
		timerText.Text = "0s"
		return
	end

	task.spawn(function()
		local lastSecond: number? = nil
		while generation == timerGeneration do
			local remaining = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
			if remaining ~= lastSecond then
				lastSecond = remaining
				timerText.Text = `{remaining}s`
			end
			if remaining <= 0 then
				break
			end
			task.wait(0.1)
		end
	end)
end

function LivePickingController.Init()
	local interface = findInterface()
	local root = interface:WaitForChild("Root")
	local boardFrame = root:WaitForChild("BoardFrame")
	local livePanel = boardFrame:WaitForChild("LivePickingPanel")
	local colorCards = livePanel:WaitForChild("ColorCards")
	local header = livePanel:WaitForChild("Header")
	local timer = header:WaitForChild("Timer")
	local timerLabel = timer:WaitForChild("TimerText")
	assert(timerLabel:IsA("TextLabel"), "[ColorGame] LivePicking TimerText must be a TextLabel")
	timerText = timerLabel

	for _, cardInstance in colorCards:GetChildren() do
		local choice = string.match(cardInstance.Name, "^(.+)Card$")
		if choice then
			local scrollingFrame = cardInstance:FindFirstChild("ScrollingFrame")
			local playerCount = cardInstance:FindFirstChild("PlayerCount")
			if scrollingFrame and scrollingFrame:IsA("ScrollingFrame")
				and playerCount and playerCount:IsA("TextLabel") then
				local template = scrollingFrame:FindFirstChild("PlayerTemplate")
				if template and template:IsA("GuiObject") then
					template.Visible = false
					cards[choice] = {
						Card = cardInstance,
						ScrollingFrame = scrollingFrame,
						Template = template,
						PlayerCount = playerCount,
					}
					playerCount.Text = "0"
					for _, child in scrollingFrame:GetChildren() do
						if child:GetAttribute("LivePickUserId") ~= nil then
							child:Destroy()
						end
					end
				end
			end
		end
	end

	local stateFolder = ReplicatedStorage:WaitForChild("ColorGameState")
	local function syncTimer()
		startTimer(
			stateFolder:GetAttribute("State") or "",
			stateFolder:GetAttribute("EndsAt") or 0
		)
	end
	stateFolder:GetAttributeChangedSignal("State"):Connect(syncTimer)
	stateFolder:GetAttributeChangedSignal("EndsAt"):Connect(syncTimer)
	syncTimer()

	local remote = Remote.New("ColorGameEvent")
	remote.OnClientEvent:Connect(function(action: string, ...: any)
		local args = table.pack(...)
		if action == "LivePick" and type(args[1]) == "number" then
			setPick(args[1], if type(args[2]) == "string" then args[2] else nil)
		elseif action == "LivePickSnapshot" then
			applySnapshot(args[1])
		end
	end)
	remote:FireServer("LivePickingReady")
end

return LivePickingController
