--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundTimerController = {}

local WAITING_TEXT = "Waiting for the next round..."
local timerGeneration = 0

local function runCountdown(label: TextLabel, state: string, endsAt: number)
	timerGeneration += 1
	local generation = timerGeneration
	if state ~= "Picking" or endsAt <= 0 then
		label.Text = WAITING_TEXT
		return
	end

	task.spawn(function()
		local lastSecond: number? = nil
		while generation == timerGeneration and label.Parent do
			local remaining = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
			if remaining ~= lastSecond then
				lastSecond = remaining
				label.Text = if remaining > 0 then `Rolling in {remaining}...` else WAITING_TEXT
			end
			if remaining <= 0 then
				break
			end
			task.wait(0.1)
		end
	end)
end

function RoundTimerController.Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local mainGui = playerGui:WaitForChild("MainGui", 10)
	if not mainGui then
		warn("[ColorGame] Could not initialize round TimerLabel because PlayerGui.MainGui is missing.")
		return
	end

	local candidate = mainGui:FindFirstChild("TimerLabel", true)
	if not candidate or not candidate:IsA("TextLabel") then
		warn("[ColorGame] Expected a TextLabel named TimerLabel under PlayerGui.MainGui.")
		return
	end
	local timerLabel = candidate
	local stateFolder = ReplicatedStorage:WaitForChild("ColorGameState")

	local function syncTimer()
		runCountdown(
			timerLabel,
			stateFolder:GetAttribute("State") or "",
			stateFolder:GetAttribute("EndsAt") or 0
		)
	end

	stateFolder:GetAttributeChangedSignal("State"):Connect(syncTimer)
	stateFolder:GetAttributeChangedSignal("EndsAt"):Connect(syncTimer)
	syncTimer()
end

return RoundTimerController
