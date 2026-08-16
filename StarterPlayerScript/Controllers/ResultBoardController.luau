--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)

local ResultBoardController = {}

local COLORS: { [string]: Color3 } = {
	Red = Color3.fromRGB(235, 53, 49),
	Blue = Color3.fromRGB(20, 91, 232),
	Green = Color3.fromRGB(45, 199, 50),
	Pink = Color3.fromRGB(226, 70, 142),
	Yellow = Color3.fromRGB(255, 214, 25),
	White = Color3.fromRGB(255, 255, 255),
}

local SUMMARY_COLORS = { "Blue", "Green", "Pink", "Red", "White", "Yellow" }
local resultBalls: { GuiObject } = {}
local summaryLabels: { [string]: TextLabel } = {}
local winnersFrame: ScrollingFrame
local winnerTemplate: GuiObject
local thumbnailCache: { [number]: string } = {}

local function setText(root: Instance, name: string, text: string)
	local label = root:FindFirstChild(name, true)
	if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
		label.Text = text
	end
end

local function clearWinners()
	for _, child in winnersFrame:GetChildren() do
		if child:GetAttribute("ResultWinner") == true then
			child:Destroy()
		end
	end
end

local function loadAvatar(row: GuiObject, userId: number)
	local avatar = row:FindFirstChild("Winner1Avatar", true)
	if not avatar or not avatar:IsA("ImageLabel") then
		return
	end
	local cached = thumbnailCache[userId]
	if cached then
		avatar.Image = cached
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
			warn(`[ColorGame] Could not load winner avatar for {userId}: {content}`)
			return
		end
		thumbnailCache[userId] = content
		if row.Parent and avatar.Parent then
			avatar.Image = content
		end
	end)
end

local function renderResults(results: any, report: any)
	if type(results) ~= "table" or type(report) ~= "table" then
		return
	end

	for index, ball in resultBalls do
		local result = results[index]
		ball.BackgroundColor3 = COLORS[result] or Color3.fromRGB(90, 90, 90)
	end

	local summary = if type(report.Summary) == "table" then report.Summary else {}
	for _, color in SUMMARY_COLORS do
		local label = summaryLabels[color]
		if label then
			label.Text = tostring(summary[color] or 0)
		end
	end

	clearWinners()
	local winners = if type(report.Winners) == "table" then table.clone(report.Winners) else {}
	table.sort(winners, function(a, b)
		if a.Reward ~= b.Reward then
			return a.Reward > b.Reward
		end
		if a.Matches ~= b.Matches then
			return a.Matches > b.Matches
		end
		return tostring(a.DisplayName) < tostring(b.DisplayName)
	end)

	for rank, winner in winners do
		if type(winner.UserId) == "number" then
			local row = winnerTemplate:Clone()
			row.Name = `Winner_{rank}`
			row.Visible = true
			row.LayoutOrder = rank
			row:SetAttribute("ResultWinner", true)
			setText(row, "RankText", tostring(rank))
			setText(row, "Winner1Name", tostring(winner.DisplayName or "Player"))
			setText(row, "MatchText", `{tonumber(winner.Matches) or 0} Matches`)
			local reward = math.max(1, tonumber(winner.Reward) or 1)
			setText(row, "Winner1Reward", if reward == 1 then "+1" else `x{reward}`)
			row.Parent = winnersFrame
			loadAvatar(row, winner.UserId)
		end
	end
end

function ResultBoardController.Init()
	local resultModel = workspace:WaitForChild("ScriptableParts"):WaitForChild("ViewWindow"):WaitForChild("Result")
	local interface = resultModel:WaitForChild("ColorGameBoardUI")
	local resultPanel = interface:WaitForChild("Root"):WaitForChild("BoardFrame"):WaitForChild("ResultPanel")

	local diceResults = resultPanel:WaitForChild("DiceResults")
	for index = 1, 3 do
		local slot = diceResults:WaitForChild(`ResultSlot{index}`)
		local ball = slot:WaitForChild("ColorBall")
		assert(ball:IsA("GuiObject"), `[ColorGame] ResultSlot{index}.ColorBall must be a GuiObject`)
		resultBalls[index] = ball
	end

	local summaryPanel = resultPanel:WaitForChild("SummaryPanel")
	for _, color in SUMMARY_COLORS do
		local label = summaryPanel:WaitForChild(`{color}PlayerCount`)
		assert(label:IsA("TextLabel"), `[ColorGame] {color}PlayerCount must be a TextLabel`)
		summaryLabels[color] = label
		label.Text = "0"
	end

	local winnersPanel = resultPanel:WaitForChild("WinnersPanel")
	local scrolling = winnersPanel:WaitForChild("ScrollingFrame")
	assert(scrolling:IsA("ScrollingFrame"), "[ColorGame] WinnersPanel.ScrollingFrame must be a ScrollingFrame")
	winnersFrame = scrolling
	local template = winnersFrame:WaitForChild("Template")
	assert(template:IsA("GuiObject"), "[ColorGame] WinnersPanel Template must be a GuiObject")
	winnerTemplate = template
	winnerTemplate.Visible = false
	clearWinners()

	local remote = Remote.New("ColorGameEvent")
	remote.OnClientEvent:Connect(function(action: string, ...: any)
		if action ~= "Results" then
			return
		end
		local args = table.pack(...)
		renderResults(args[2], args[3])
	end)
end

return ResultBoardController
