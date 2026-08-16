--!strict

local RoundDisplayService = {}

local nextRoundText: TextLabel
local machineStateText: TextLabel
local countdownGeneration = 0
local machineStateGeneration = 0

local MACHINE_STATE_TEXT: { [string]: string } = {
	Spawning = "SPAWNING DICE...",
	Picking = "PICK A COLOR!",
	Activating = "ACTIVATING MACHINE...",
	Rolling = "ROLLING DICE...",
	Settling = "DICE SETTLING...",
	Validating = "CHECKING RESULTS...",
	Results = "ROUND RESULTS!",
	Recovering = "MACHINE RECOVERING...",
}

local function findNextRoundText(): TextLabel
	local viewWindow = workspace:WaitForChild("ScriptableParts"):WaitForChild("ViewWindow")
	local result = viewWindow:WaitForChild("Result")
	local boardUI = result:WaitForChild("ColorGameBoardUI")
	local label = boardUI:FindFirstChild("NextRoundText", true)
	assert(label and label:IsA("TextLabel"), "[ColorGame] ViewWindow.Result is missing the NextRoundText TextLabel")
	return label
end

local function findMachineStateText(): TextLabel
	local viewWindow = workspace:WaitForChild("ScriptableParts"):WaitForChild("ViewWindow")
	local machineState = viewWindow:WaitForChild("MachineState")
	local surfaceGui = machineState:WaitForChild("SurfaceGui")
	local frame = surfaceGui:WaitForChild("Frame")
	local label = frame:WaitForChild("TextLabel")
	assert(label:IsA("TextLabel"), "[ColorGame] ViewWindow.MachineState.SurfaceGui.Frame.TextLabel must be a TextLabel")
	return label
end

function RoundDisplayService.Init()
	nextRoundText = findNextRoundText()
	machineStateText = findMachineStateText()
	nextRoundText.Text = "NEXT ROUND STARTS SOON..."
	machineStateText.Text = "PREPARING MACHINE..."
end

function RoundDisplayService.SetMachineState(stateName: string, endsAt: number?)
	machineStateGeneration += 1
	local generation = machineStateGeneration
	local baseText = MACHINE_STATE_TEXT[stateName] or string.upper(stateName)
	if not endsAt or endsAt <= 0 then
		machineStateText.Text = baseText
		return
	end

	task.spawn(function()
		local lastDisplayed: number? = nil
		while generation == machineStateGeneration do
			local remaining = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
			if remaining ~= lastDisplayed then
				lastDisplayed = remaining
				machineStateText.Text = `{baseText} {remaining}s`
			end
			if remaining <= 0 then
				break
			end
			task.wait(0.1)
		end
	end)
end

function RoundDisplayService.StartNextRoundCountdown(duration: number)
	countdownGeneration += 1
	local generation = countdownGeneration
	local endsAt = workspace:GetServerTimeNow() + duration

	task.spawn(function()
		local lastDisplayed: number? = nil
		while generation == countdownGeneration do
			local remaining = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
			if remaining ~= lastDisplayed then
				lastDisplayed = remaining
				nextRoundText.Text = `NEXT ROUND STARTS IN {remaining}s...`
			end
			if remaining <= 0 then
				break
			end
			task.wait(0.1)
		end
	end)
end

function RoundDisplayService.ShowRoundInProgress()
	countdownGeneration += 1
	nextRoundText.Text = "ROUND IN PROGRESS..."
end

function RoundDisplayService.ShowResults()
	countdownGeneration += 1
	nextRoundText.Text = "NEXT ROUND STARTS SOON..."
end

return RoundDisplayService
