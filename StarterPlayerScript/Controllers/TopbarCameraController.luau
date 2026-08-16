--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Icon = require(ReplicatedStorage.Modules.Shared.Libraries.TopbarPlus)

local TopbarCameraController = {}

local CAMERA_ICON = 17723078608
local TWEEN_INFO = TweenInfo.new(1.15, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)

type CameraView = {
	CFrame: CFrame,
	FieldOfView: number,
}

local CAMERA_VIEWS: { [string]: CameraView } = {
	Machine = {
		CFrame = CFrame.new(30.892, 29.365, 69.688)
			* CFrame.fromOrientation(math.rad(-44.643), math.rad(-90.546), math.rad(0)),
		FieldOfView = 60,
	},
	LivePicking = {
		CFrame = CFrame.new(39.241, 14.943, 39.612)
			* CFrame.fromOrientation(math.rad(0.335), math.rad(-56.455), math.rad(0)),
		FieldOfView = 50,
	},
	ResultSummary = {
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
local activeViewName: string? = nil
local transitionGeneration = 0
local transitioning = false
local suppressIconEvents = false
local viewIcons: { [string]: any } = {}

local function cancelTween()
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
end

local function getFallbackSubject(): Instance?
	local character = Players.LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function setIconsLocked(locked: boolean)
	for _, icon in viewIcons do
		if locked then
			icon:lock()
		else
			icon:unlock()
		end
	end
end

local function finishTransition()
	transitioning = false
	setIconsLocked(false)
end

local function beginTransition(): boolean
	if transitioning then
		return false
	end
	transitioning = true
	setIconsLocked(true)
	return true
end

local function tweenCamera(camera: Camera, goal: { [string]: any }, onFinished: ((Enum.PlaybackState) -> ())?)
	cancelTween()
	transitionGeneration += 1
	local generation = transitionGeneration
	local tween = TweenService:Create(camera, TWEEN_INFO, goal)
	activeTween = tween
	tween.Completed:Connect(function(playbackState)
		if generation ~= transitionGeneration or activeTween ~= tween then
			return
		end
		activeTween = nil
		if onFinished then
			onFinished(playbackState)
		end
	end)
	tween:Play()
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

local function deselectOtherView(selectedViewName: string)
	suppressIconEvents = true
	for viewName, icon in viewIcons do
		if viewName ~= selectedViewName then
			icon:deselect()
		end
	end
	suppressIconEvents = false
end

local function openCameraView(viewName: string)
	if suppressIconEvents then
		return
	end

	local view = CAMERA_VIEWS[viewName]
	if not view or not beginTransition() then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		finishTransition()
		return
	end

	saveDefaultCamera(camera)
	deselectOtherView(viewName)
	activeViewName = viewName
	camera.CameraType = Enum.CameraType.Scriptable
	tweenCamera(camera, {
		CFrame = view.CFrame,
		FieldOfView = view.FieldOfView,
	}, function()
		finishTransition()
	end)
end

local function closeCameraView(viewName: string)
	if suppressIconEvents or activeViewName ~= viewName or not beginTransition() then
		return
	end

	local camera = workspace.CurrentCamera
	local state = savedState
	activeViewName = nil
	savedState = nil
	if not camera or not state then
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

local function createViewIcon(viewName: string, label: string, caption: string, order: number)
	local icon = Icon.new()
		:setName(`{viewName}Camera`)
		:setImage(CAMERA_ICON)
		:setImageScale(0.62)
		:setLabel(label)
		:setCaption(caption)
		:setOrder(order)
		:align("Left")
		:autoDeselect(false)

	viewIcons[viewName] = icon
	icon.selected:Connect(function()
		openCameraView(viewName)
	end)
	icon.deselected:Connect(function()
		closeCameraView(viewName)
	end)
end

function TopbarCameraController.Init()
	createViewIcon("Machine", "Machine", "Machine Camera", 1)
	createViewIcon("LivePicking", "Live Picking", "Live Picking Camera", 2)
	createViewIcon("ResultSummary", "Result Summary", "Result Summary Camera", 3)
end

return TopbarCameraController
