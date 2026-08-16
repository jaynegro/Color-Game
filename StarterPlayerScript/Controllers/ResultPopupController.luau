--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)

local ResultPopupController = {}

local COLORS: { [string]: Color3 } = {
	Red = Color3.fromRGB(235, 53, 49),
	Blue = Color3.fromRGB(20, 91, 232),
	Green = Color3.fromRGB(45, 199, 50),
	Pink = Color3.fromRGB(226, 70, 142),
	Yellow = Color3.fromRGB(255, 214, 25),
	White = Color3.fromRGB(255, 255, 255),
}

local SLOT_NAMES = { "1st", "2nd", "3rd" }
local DROP_DISTANCE_SCALE = 0.45
local DROP_DISTANCE_OFFSET = 40
local SLOT_DELAY = 0.16
local DISPLAY_DURATION = 3

local resultFrame: GuiObject
local slots: { GuiObject } = {}
local defaultPositions: { [GuiObject]: UDim2 } = {}
local animationGeneration = 0

local function positionAbove(position: UDim2): UDim2
	return UDim2.new(
		position.X.Scale,
		position.X.Offset,
		position.Y.Scale - DROP_DISTANCE_SCALE,
		position.Y.Offset - DROP_DISTANCE_OFFSET
	)
end

local function hide()
	animationGeneration += 1
	resultFrame.Visible = false
	for _, slot in slots do
		slot.Visible = false
		slot.Position = defaultPositions[slot]
	end
end

local function show(results: any)
	if type(results) ~= "table" then
		return
	end

	animationGeneration += 1
	local generation = animationGeneration
	resultFrame.Visible = true

	for index, slot in slots do
		local colorBall = slot:FindFirstChild("ColorBall", true)
		if colorBall and colorBall:IsA("GuiObject") then
			colorBall.BackgroundColor3 = COLORS[results[index]] or Color3.fromRGB(90, 90, 90)
		end
		slot.Visible = false
		slot.Position = positionAbove(defaultPositions[slot])
	end

	for index, slot in slots do
		task.delay((index - 1) * SLOT_DELAY, function()
			if generation ~= animationGeneration then
				return
			end
			slot.Visible = true
			TweenService:Create(
				slot,
				TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Position = defaultPositions[slot] }
			):Play()
		end)
	end

	task.delay(DISPLAY_DURATION, function()
		if generation == animationGeneration then
			hide()
		end
	end)
end

function ResultPopupController.Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local mainGui = playerGui:WaitForChild("MainGui")
	local frame = mainGui:WaitForChild("ResultFrame")
	assert(frame:IsA("GuiObject"), "[ColorGame] MainGui.ResultFrame must be a GuiObject")
	resultFrame = frame

	for _, name in SLOT_NAMES do
		local slot = resultFrame:WaitForChild(name)
		assert(slot:IsA("GuiObject"), `[ColorGame] ResultFrame.{name} must be a GuiObject`)
		local colorBall = slot:WaitForChild("ColorBall")
		assert(colorBall:IsA("GuiObject"), `[ColorGame] ResultFrame.{name}.ColorBall must be a GuiObject`)
		table.insert(slots, slot)
		defaultPositions[slot] = slot.Position
	end

	hide()
	local remote = Remote.New("ColorGameEvent")
	remote.OnClientEvent:Connect(function(action: string, ...: any)
		if action ~= "Results" then
			return
		end
		local args = table.pack(...)
		show(args[2])
	end)
end

return ResultPopupController
