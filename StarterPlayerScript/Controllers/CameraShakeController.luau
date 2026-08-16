--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraShaker = require(ReplicatedStorage.Modules.Shared.Libraries.CameraShaker)
local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)

local CameraShakeController = {}

local IMPACT_MAGNITUDE = 0.8
local IMPACT_ROUGHNESS = 7
local IMPACT_FADE_IN = 0.03
local IMPACT_FADE_OUT = 0.38
local IMPACT_POSITION_INFLUENCE = Vector3.new(0.08, 0.1, 0.06)
local IMPACT_ROTATION_INFLUENCE = Vector3.new(0.55, 0.25, 0.35)

local initialized = false

function CameraShakeController.Init()
	if initialized then
		return
	end
	initialized = true

	local lastCamera: Camera? = nil
	local lastShake = CFrame.identity
	local shaker = CameraShaker.new(Enum.RenderPriority.Camera.Value + 1, function(shakeCFrame: CFrame)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		if camera ~= lastCamera then
			lastCamera = camera
			lastShake = CFrame.identity
		end

		-- Remove the previous frame's offset before applying the new one. This
		-- keeps Scriptable/topbar cameras from accumulating positional drift.
		camera.CFrame = camera.CFrame * lastShake:Inverse() * shakeCFrame
		lastShake = shakeCFrame
	end)
	shaker:Start()

	local remote = Remote.New("ColorGameEvent")
	remote.OnClientEvent:Connect(function(action: string, ...: any)
		if action ~= "PlaySFX" then
			return
		end
		local soundName = select(1, ...)
		if soundName == "ActivationHit" then
			shaker:ShakeOnce(
				IMPACT_MAGNITUDE,
				IMPACT_ROUGHNESS,
				IMPACT_FADE_IN,
				IMPACT_FADE_OUT,
				IMPACT_POSITION_INFLUENCE,
				IMPACT_ROTATION_INFLUENCE
			)
		end
	end)
end

return CameraShakeController
