--!strict

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Modules.Shared.Config.Config)

local DayCycleController = {}

local initialized = false

function DayCycleController.Init()
	if initialized then
		return
	end
	initialized = true

	local cycleDuration = math.max(Config.DayCycleDuration, 1)
	local startingClockTime = Lighting.ClockTime
	local startedAt = time()

	RunService.RenderStepped:Connect(function()
		local elapsed = time() - startedAt
		local elapsedHours = (elapsed / cycleDuration) * 24
		Lighting.ClockTime = (startingClockTime + elapsedHours) % 24
	end)
end

return DayCycleController
