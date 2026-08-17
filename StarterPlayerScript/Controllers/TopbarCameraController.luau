--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Icon = require(ReplicatedStorage.Modules.Shared.Libraries.TopbarPlus)
local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)

local TopbarCameraController = {}

local CAMERA_ICON = 17723078608
local TWEEN_INFO = TweenInfo.new(1.15, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)

type CameraView = {
	CFrame: CFrame,
	FieldOfView: number,
}

local CAMERA_VIEWS: { CameraView } = {
	{
		CFrame = CFrame.new(30.892, 29.365, 69.688)
			* CFrame.fromOrientation(math.rad(-44.643), math.rad(-90.546), math.rad(0)),
		FieldOfView = 60,
	},
	{
		CFrame = CFrame.new(39.241, 14.943, 39.612)
			* CFrame.fromOrientation(math.rad(0.335), math.rad(-56.455), math.rad(0)),
		FieldOfView = 50,
	},
	{
		CFrame = CFrame.new(32.511, 15.344, 110.721)
			* CFrame.fromOrientation(math.rad(1.338), math.rad(-124.78), math.rad(0)),
		FieldOfView = 50,
	},
}

type CameraState = {
	CFrame: CFrame,
	FieldOfView: number,
	CameraType: Enum.CameraType,
	CameraSubject: Instance?,
}

local savedState: CameraState? = nil
local activeTween: Tween? = nil
local viewIcon: any = nil
local currentViewIndex = 0
local transitionGeneration = 0
local transitioning = false
local roundCameraActive = false

local function getFallbackSubject(): Instance?
	local character = Players.LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function finishTransition()
	transitioning = false
	if viewIcon then
		if roundCameraActive then
			viewIcon:lock()
		else
			viewIcon:unlock()
		end
	end
end

local function beginTransition(): boolean
	if transitioning or roundCameraActive then
		return false
	end
	transitioning = true
	if viewIcon then
		viewIcon:lock()
	end
	return true
end

local function tweenCamera(camera: Camera, goal: { [string]: any }, onFinished: (Enum.PlaybackState) -> ())
	if activeTween then
		transitionGeneration += 1
		local previousTween = activeTween
		activeTween = nil
		previousTween:Cancel()
	end

	transitionGeneration += 1
	local generation = transitionGeneration
	local tween = TweenService:Create(camera, TWEEN_INFO, goal)
	activeTween = tween
	tween.Completed:Connect(function(playbackState)
		if generation ~= transitionGeneration or activeTween ~= tween then
			return
		end
		activeTween = nil
		onFinished(playbackState)
	end)
	tween:Play()
end

local function beginForcedTransition()
	transitioning = true
	if viewIcon then
		viewIcon:lock()
	end
end

local function saveDefaultCamera(camera: Camera)
	if savedState then
		return
	end
	savedState = {
		CFrame = camera.CFrame,
		FieldOfView = camera.FieldOfView,
		CameraType = camera.CameraType,
		CameraSubject = camera.CameraSubject,
	}
end

local function advanceView()
	if not beginTransition() then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		finishTransition()
		return
	end

	local nextIndex = (currentViewIndex + 1) % (#CAMERA_VIEWS + 1)
	currentViewIndex = nextIndex

	if nextIndex > 0 then
		saveDefaultCamera(camera)
		local view = CAMERA_VIEWS[nextIndex]
		camera.CameraType = Enum.CameraType.Scriptable
		tweenCamera(camera, {
			CFrame = view.CFrame,
			FieldOfView = view.FieldOfView,
		}, function()
			finishTransition()
		end)
		return
	end

	local state = savedState
	savedState = nil
	if not state then
		finishTransition()
		return
	end

	camera.CameraType = Enum.CameraType.Scriptable
	tweenCamera(camera, {
		CFrame = state.CFrame,
		FieldOfView = state.FieldOfView,
	}, function(playbackState)
		if playbackState == Enum.PlaybackState.Completed and workspace.CurrentCamera == camera then
			local subject = state.CameraSubject
			camera.CameraSubject = if subject and subject.Parent then subject else getFallbackSubject()
			camera.CameraType = state.CameraType
		end
		finishTransition()
	end)
end

local function setRoundCameraActive(isActive: boolean)
	if roundCameraActive == isActive then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		roundCameraActive = false
		finishTransition()
		return
	end

	roundCameraActive = isActive
	beginForcedTransition()
	if isActive then
		saveDefaultCamera(camera)
		currentViewIndex = 1
		local machineView = CAMERA_VIEWS[1]
		camera.CameraType = Enum.CameraType.Scriptable
		tweenCamera(camera, {
			CFrame = machineView.CFrame,
			FieldOfView = machineView.FieldOfView,
		}, function()
			finishTransition()
		end)
		return
	end

	currentViewIndex = 0
	local state = savedState
	savedState = nil
	if not state then
		finishTransition()
		return
	end

	camera.CameraType = Enum.CameraType.Scriptable
	tweenCamera(camera, {
		CFrame = state.CFrame,
		FieldOfView = state.FieldOfView,
	}, function(playbackState)
		if playbackState == Enum.PlaybackState.Completed and workspace.CurrentCamera == camera then
			local subject = state.CameraSubject
			camera.CameraSubject = if subject and subject.Parent then subject else getFallbackSubject()
			camera.CameraType = state.CameraType
		end
		finishTransition()
	end)
end

function TopbarCameraController.Init()
	viewIcon = Icon.new()
		:setName("ViewCamera")
		:setImage(CAMERA_ICON)
		:setImageScale(0.62)
		:setLabel("View")
		:setCaption("Cycle Camera Views")
		:setOrder(1)
		:align("Left")
		:autoDeselect(false)

	-- TopbarPlus alternates between selected and deselected when clicked.
	-- Both events advance the cycle so every click moves to one view.
	viewIcon.selected:Connect(advanceView)
	viewIcon.deselected:Connect(advanceView)

	local remote = Remote.New("ColorGameEvent")
	remote.OnClientEvent:Connect(function(action: string, ...: any)
		if action ~= "RoundCamera" then
			return
		end
		local args = table.pack(...)
		setRoundCameraActive(args[1] == true)
	end)
end

return TopbarCameraController
