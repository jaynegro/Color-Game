--  --!strict

--  local ContentProvider = game:GetService("ContentProvider")
--  local Players = game:GetService("Players")
--  local RunService = game:GetService("RunService")
--  local StarterGui = game:GetService("StarterGui")
--  local TweenService = game:GetService("TweenService")

--  local LOCAL_PLAYER = Players.LocalPlayer

--  local CAMERA_BIND_NAME = "LoadingScreenCamera"
--  local CAMERA_PRIORITY = Enum.RenderPriority.Camera.Value + 1
--  local LOADING_CAMERA_CFRAME = CFrame.new(0.361, 5.178, 123.206)
--  	* CFrame.fromOrientation(math.rad(2.533), math.rad(-57.802), math.rad(0))
--  local LOADING_CAMERA_FOV = 20
--  local CLONE_CFRAME = CFrame.new(8.255, -1.188, 73.71)
--  	* CFrame.fromOrientation(math.rad(0), math.rad(30.26), math.rad(0))

--  local POSITION_DRIFT = 1.235
--  local ROTATION_DRIFT = math.rad(1.3)
--  local DRIFT_SPEED = 0.18
--  local PROGRESS_RESPONSE = 8
--  local PROGRESS_EDGE_WIDTH = 0.002
-- local COMPLETION_HOLD = 2
-- local CAMERA_BLEND_DURATION = 1.25
-- local UI_FADE_DURATION = 0.75
-- local APPEARANCE_LOAD_TIMEOUT = 20
--  local PRELOAD_WORKERS = 8
--  local PRELOAD_TIMEOUT = 45

--  local PRELOADABLE_CLASSES: { [string]: boolean } = {
--  	Animation = true,
--  	Beam = true,
--  	Decal = true,
--  	ImageButton = true,
--  	ImageLabel = true,
--  	MeshPart = true,
--  	ParticleEmitter = true,
--  	Pants = true,
--  	Shirt = true,
--  	ShirtGraphic = true,
--  	Sky = true,
--  	Sound = true,
--  	SpecialMesh = true,
--  	SurfaceAppearance = true,
--  	Texture = true,
--  	Trail = true,
--  	VideoFrame = true,
--  }

--  type HumanoidState = {
--  	WalkSpeed: number,
--  	JumpPower: number,
--  	JumpHeight: number,
--  	AutoRotate: boolean,
--  }

--  type GuiState = {
--  	Instance: Instance,
--  	Property: string,
--  	Value: any,
--  }

--  type FadeTargets = { [Instance]: { [string]: number } }

--  local camera: Camera? = nil
--  local character: Model? = nil
--  local humanoid: Humanoid? = nil
--  local characterClone: Model? = nil
--  local idleTrack: AnimationTrack? = nil
--  local controls: any = nil
--  local humanoidState: HumanoidState? = nil
--  local guiStates: { GuiState } = {}
--  local coreGuiStates: { [Enum.CoreGuiType]: boolean } = {}
-- local loadingScreen: GuiObject? = nil
-- local originalFieldOfView = 70
-- local characterRemovingConnection: RBXScriptConnection? = nil
--  local cameraBound = false
--  local aborted = false
--  local cleanedUp = false

--  local function waitForCamera(): Camera
--  	local currentCamera = workspace.CurrentCamera
--  	while not currentCamera do
--  		workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
--  		currentCamera = workspace.CurrentCamera
--  	end
--  	return currentCamera
--  end

--  local function rememberGuiProperty(instance: Instance, property: string, value: any)
--  	table.insert(guiStates, {
--  		Instance = instance,
--  		Property = property,
--  		Value = value,
--  	})
--  end

--  local function hideOtherInterfaces(playerGui: PlayerGui, mainGui: ScreenGui, screen: GuiObject)
--  	for _, child in ipairs(playerGui:GetChildren()) do
--  		if child:IsA("ScreenGui") and child ~= mainGui then
--  			rememberGuiProperty(child, "Enabled", child.Enabled)
--  			child.Enabled = false
--  		end
--  	end

--  	for _, child in ipairs(mainGui:GetChildren()) do
--  		if child ~= screen and child:IsA("GuiObject") then
--  			rememberGuiProperty(child, "Visible", child.Visible)
--  			child.Visible = false
--  		end
--  	end

--  	for _, coreGuiType in ipairs(Enum.CoreGuiType:GetEnumItems()) do
--  		if coreGuiType ~= Enum.CoreGuiType.All then
--  			local readSuccess, wasEnabled = pcall(function()
--  				return StarterGui:GetCoreGuiEnabled(coreGuiType)
--  			end)
--  			if readSuccess then
--  				local writeSuccess = pcall(function()
--  					StarterGui:SetCoreGuiEnabled(coreGuiType, false)
--  				end)
--  				if writeSuccess then
--  					coreGuiStates[coreGuiType] = wasEnabled
--  				end
--  			end
--  		end
--  	end
--  end

--  local function waitForCharacterAppearance(realCharacter: Model): boolean
--  	local appearanceLoaded = false
--  	local connection = LOCAL_PLAYER.CharacterAppearanceLoaded:Connect(function(loadedCharacter)
--  		if loadedCharacter == realCharacter then
--  			appearanceLoaded = true
--  		end
--  	end)

--  	local checkSuccess, alreadyLoaded = pcall(function()
--  		return LOCAL_PLAYER:HasAppearanceLoaded()
--  	end)
--  	if checkSuccess and alreadyLoaded and LOCAL_PLAYER.Character == realCharacter then
--  		appearanceLoaded = true
--  	end

--  	local deadline = os.clock() + APPEARANCE_LOAD_TIMEOUT
--  	while not appearanceLoaded
--  		and not aborted
--  		and realCharacter.Parent
--  		and LOCAL_PLAYER.Character == realCharacter
--  		and os.clock() < deadline do
--  		RunService.Heartbeat:Wait()
--  	end

--  	connection:Disconnect()
--  	if not appearanceLoaded and not aborted then
--  		warn(("[LoadingScreen] Character appearance did not finish within %d seconds; using the latest available appearance")
--  			:format(APPEARANCE_LOAD_TIMEOUT))
--  	end
--  	return appearanceLoaded
--  end

--  local function findIdleAnimationId(realCharacter: Model, realHumanoid: Humanoid): string?
--  	for _, track in ipairs(realHumanoid:GetPlayingAnimationTracks()) do
--  		local animation = track.Animation
--  		if animation and animation.AnimationId ~= ""
--  			and (track.Priority == Enum.AnimationPriority.Idle or track.Priority == Enum.AnimationPriority.Core) then
--  			return animation.AnimationId
--  		end
--  	end

--  	local animateScript = realCharacter:FindFirstChild("Animate")
--  	local idleFolder = animateScript and animateScript:FindFirstChild("idle")
--  	if idleFolder then
--  		for _, descendant in ipairs(idleFolder:GetDescendants()) do
--  			if descendant:IsA("Animation") and descendant.AnimationId ~= "" then
--  				return descendant.AnimationId
--  			end
--  		end
--  	end

--  	return nil
--  end

--  local function createCharacterClone(realCharacter: Model, realHumanoid: Humanoid): Model
--  	local idleAnimationId = findIdleAnimationId(realCharacter, realHumanoid)
--  	local wasArchivable = realCharacter.Archivable
--  	realCharacter.Archivable = true
--  	local cloneSuccess, cloneResult = pcall(function()
--  		return realCharacter:Clone()
--  	end)
--  	realCharacter.Archivable = wasArchivable
--  	assert(cloneSuccess and cloneResult, "The local character could not be cloned")
--  	local clone = cloneResult :: Model

--  	clone.Name = "LoadingCharacterClone"
-- 	for _, descendant in ipairs(clone:GetDescendants()) do
-- 		if descendant:IsA("LuaSourceContainer") or descendant:IsA("Tool") then
-- 			descendant:Destroy()
-- 		elseif descendant:IsA("BasePart") then
-- 			descendant.Anchored = descendant.Name == "HumanoidRootPart"
-- 			descendant.CanCollide = false
-- 			descendant.CanTouch = false
-- 			descendant.CanQuery = false
-- 			descendant.Massless = true
-- 			descendant.AssemblyLinearVelocity = Vector3.zero
-- 			descendant.AssemblyAngularVelocity = Vector3.zero
-- 		end
-- 	end

--  	local cloneHumanoid = clone:FindFirstChildOfClass("Humanoid")
--  	assert(cloneHumanoid, "The loading character clone has no Humanoid")
--  	cloneHumanoid.WalkSpeed = 0
--  	cloneHumanoid.JumpPower = 0
--  	cloneHumanoid.JumpHeight = 0
--  	cloneHumanoid.AutoRotate = false
--  	cloneHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

--  	clone.Parent = workspace
--  	clone:PivotTo(CLONE_CFRAME)

--  	if idleAnimationId then
--  		local animator = cloneHumanoid:FindFirstChildOfClass("Animator")
--  		if not animator then
--  			animator = Instance.new("Animator")
--  			animator.Parent = cloneHumanoid
--  		end

--  		local animation = Instance.new("Animation")
--  		animation.Name = "LoadingIdleAnimation"
--  		animation.AnimationId = idleAnimationId
--  		animation.Parent = clone

--  		local success, loadedTrack = pcall(function()
--  			return animator:LoadAnimation(animation)
--  		end)
--  		if success then
--  			idleTrack = loadedTrack
--  			loadedTrack.Priority = Enum.AnimationPriority.Idle
--  			loadedTrack.Looped = true
--  			loadedTrack:Play(0.2)
--  		else
--  			warn("[LoadingScreen] Could not play the clone idle animation:", loadedTrack)
--  		end
--  	end

--  	return clone
--  end

--  local function disablePlayerMovement(realHumanoid: Humanoid)
--  	humanoidState = {
--  		WalkSpeed = realHumanoid.WalkSpeed,
--  		JumpPower = realHumanoid.JumpPower,
--  		JumpHeight = realHumanoid.JumpHeight,
--  		AutoRotate = realHumanoid.AutoRotate,
--  	}

--  	realHumanoid.WalkSpeed = 0
--  	realHumanoid.JumpPower = 0
--  	realHumanoid.JumpHeight = 0
--  	realHumanoid.AutoRotate = false
--  	realHumanoid:Move(Vector3.zero, false)

--  	local rootPart = realHumanoid.RootPart
--  	if rootPart then
--  		rootPart.AssemblyLinearVelocity = Vector3.zero
--  		rootPart.AssemblyAngularVelocity = Vector3.zero
--  	end

--  	local playerScripts = LOCAL_PLAYER:WaitForChild("PlayerScripts")
--  	local playerModule = playerScripts:FindFirstChild("PlayerModule")
--  	if playerModule and playerModule:IsA("ModuleScript") then
--  		local success, module = pcall(require, playerModule)
--  		if success then
--  			local getControlsSuccess, playerControls = pcall(function()
--  				return module:GetControls()
--  			end)
--  			if getControlsSuccess and playerControls then
--  				controls = playerControls
--  				pcall(function()
--  					playerControls:Disable()
--  				end)
--  			end
--  		end
--  	end
--  end

--  local function setProgressGradient(gradient: UIGradient, progress: number)
--  	local normalized = math.clamp(progress, 0, 1)
--  	if normalized <= 0 then
--  		gradient.Transparency = NumberSequence.new(1)
--  	elseif normalized >= 1 then
--  		gradient.Transparency = NumberSequence.new(0)
--  	else
--  		local edgeEnd = math.min(normalized + PROGRESS_EDGE_WIDTH, 1)
--  		if edgeEnd >= 1 then
--  			gradient.Transparency = NumberSequence.new({
--  				NumberSequenceKeypoint.new(0, 0),
--  				NumberSequenceKeypoint.new(normalized, 0),
--  				NumberSequenceKeypoint.new(1, 1),
--  			})
--  		else
--  			gradient.Transparency = NumberSequence.new({
--  				NumberSequenceKeypoint.new(0, 0),
--  				NumberSequenceKeypoint.new(normalized, 0),
--  				NumberSequenceKeypoint.new(edgeEnd, 1),
--  				NumberSequenceKeypoint.new(1, 1),
--  			})
--  		end
--  	end
--  end

--  local function collectPreloadableAssets(): { Instance }
--  	local assets = {}
--  	for _, descendant in ipairs(game:GetDescendants()) do
--  		if PRELOADABLE_CLASSES[descendant.ClassName] then
--  			table.insert(assets, descendant)
--  		end
--  	end
--  	return assets
--  end

--  local function preloadAssets(onProgress: (number) -> ()): number
--  	local assets = collectPreloadableAssets()
--  	local total = #assets
--  	if total == 0 then
--  		onProgress(1)
--  		return 0
--  	end

--  	local nextIndex = 0
--  	local completed = 0
--  	local failed = 0
--  	local startedAt = os.clock()

--  	for _ = 1, math.min(PRELOAD_WORKERS, total) do
--  		task.spawn(function()
--  			while true do
--  				nextIndex += 1
--  				local index = nextIndex
--  				local asset = assets[index]
--  				if not asset then
--  					return
--  				end

--  				local success = pcall(function()
--  					ContentProvider:PreloadAsync({ asset })
--  				end)
--  				if not success then
--  					failed += 1
--  				end
--  				completed += 1
--  			end
--  		end)
--  	end

--  	while completed < total and not aborted do
--  		if os.clock() - startedAt >= PRELOAD_TIMEOUT then
--  			warn(("[LoadingScreen] Asset preloading timed out after %d seconds (%d/%d completed)")
--  				:format(PRELOAD_TIMEOUT, completed, total))
--  			break
--  		end
--  		onProgress(completed / total)
--  		RunService.Heartbeat:Wait()
--  	end

--  	onProgress(1)
--  	if failed > 0 then
--  		warn(("[LoadingScreen] %d preload request(s) failed; loading continued safely"):format(failed))
--  	end
--  	return total
--  end

--  local function captureFadeProperties(screen: GuiObject): FadeTargets
--  	local fadeTargets: FadeTargets = {}
--  	local candidates = screen:GetDescendants()
--  	table.insert(candidates, screen)

--  	for _, instance in ipairs(candidates) do
--  		local properties: { [string]: number } = {}
--  		if instance:IsA("GuiObject") then
--  			properties.BackgroundTransparency = instance.BackgroundTransparency
--  		end
--  		if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
--  			properties.ImageTransparency = instance.ImageTransparency
--  		end
--  		if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
--  			properties.TextTransparency = instance.TextTransparency
--  			properties.TextStrokeTransparency = instance.TextStrokeTransparency
--  		end
--  		if instance:IsA("ScrollingFrame") then
--  			properties.ScrollBarImageTransparency = instance.ScrollBarImageTransparency
--  		end
--  		if instance:IsA("CanvasGroup") then
--  			properties.GroupTransparency = instance.GroupTransparency
--  		end
--  		if instance:IsA("UIStroke") then
--  			properties.Transparency = instance.Transparency
--  		end
--  		if next(properties) then
--  			fadeTargets[instance] = properties
--  		end
--  	end

--  	return fadeTargets
--  end

--  local function playLoadingScreenFade(fadeTargets: FadeTargets)
--  	local tweenInfo = TweenInfo.new(UI_FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
--  	for instance, originalProperties in pairs(fadeTargets) do
--  		if instance.Parent then
--  			local goals: { [string]: number } = {}
--  			for property in pairs(originalProperties) do
--  				goals[property] = 1
--  			end
--  			TweenService:Create(instance, tweenInfo, goals):Play()
--  		end
--  	end
--  end

--  local function restoreFadeProperties(fadeTargets: FadeTargets)
--  	for instance, properties in pairs(fadeTargets) do
--  		if instance.Parent then
--  			for property, value in pairs(properties) do
--  				pcall(function()
--  					(instance :: any)[property] = value
--  				end)
--  			end
--  		end
--  	end
--  end

--  local function bindLoadingCamera(activeCamera: Camera)
--  	local startedAt = os.clock()
--  	RunService:BindToRenderStep(CAMERA_BIND_NAME, CAMERA_PRIORITY, function()
--  		local elapsed = (os.clock() - startedAt) * DRIFT_SPEED
--  		local x = math.noise(elapsed, 11.7) * POSITION_DRIFT
--  		local y = math.noise(29.3, elapsed) * POSITION_DRIFT
--  		local pitch = math.noise(elapsed, 53.1) * ROTATION_DRIFT
--  		local yaw = math.noise(71.9, elapsed) * ROTATION_DRIFT

--  		activeCamera.CFrame = LOADING_CAMERA_CFRAME
--  			* CFrame.new(x, y, 0)
--  			* CFrame.fromOrientation(pitch, yaw, 0)
--  		activeCamera.FieldOfView = LOADING_CAMERA_FOV
--  	end)
--  	cameraBound = true
--  end

-- local function transitionToPlayerCamera(
-- 	activeCamera: Camera,
-- 	targetHumanoid: Humanoid,
-- 	fadeTargets: FadeTargets
-- )
--  	if cameraBound then
--  		RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)
--  		cameraBound = false
--  	end

--  	local startCFrame = activeCamera.CFrame
--  	local startFov = activeCamera.FieldOfView
-- 	local startedAt = os.clock()
-- 	local fadeStarted = false
-- 	local fadeStartTime = CAMERA_BLEND_DURATION - UI_FADE_DURATION

-- 	activeCamera.CameraSubject = targetHumanoid
-- 	activeCamera.CameraType = Enum.CameraType.Custom

--  	RunService:BindToRenderStep(CAMERA_BIND_NAME, CAMERA_PRIORITY, function()
--  		local elapsed = os.clock() - startedAt
-- 		local alpha = math.clamp(elapsed / CAMERA_BLEND_DURATION, 0, 1)
-- 		local easedAlpha = TweenService:GetValue(alpha, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
-- 		local desiredCFrame = activeCamera.CFrame

-- 		activeCamera.CFrame = startCFrame:Lerp(desiredCFrame, easedAlpha)
-- 		activeCamera.FieldOfView = startFov + (originalFieldOfView - startFov) * easedAlpha
-- 	end)
--  	cameraBound = true

--  	while os.clock() - startedAt < CAMERA_BLEND_DURATION and not aborted do
--  		local elapsed = os.clock() - startedAt
--  		if not fadeStarted and elapsed >= fadeStartTime then
--  			fadeStarted = true
--  			playLoadingScreenFade(fadeTargets)
--  		end
--  		RunService.Heartbeat:Wait()
--  	end

--  	if not fadeStarted then
--  		playLoadingScreenFade(fadeTargets)
--  	end

--  	if cameraBound then
--  		RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)
--  		cameraBound = false
--  	end
-- 	activeCamera.FieldOfView = originalFieldOfView
-- end

--  local function cleanup(fadeTargets: FadeTargets?)
--  	if cleanedUp then
--  		return
--  	end
--  	cleanedUp = true

--  	if cameraBound then
--  		RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)
--  		cameraBound = false
--  	end
--  	if characterRemovingConnection then
--  		characterRemovingConnection:Disconnect()
--  		characterRemovingConnection = nil
--  	end
--  	if idleTrack then
--  		pcall(function()
--  			idleTrack:Stop(0.1)
--  		end)
--  	end
--  	if characterClone then
--  		characterClone:Destroy()
--  		characterClone = nil
--  	end
-- 	if controls then
--  		pcall(function()
--  			controls:Enable()
--  		end)
--  	end
--  	if humanoid and humanoid.Parent and humanoidState then
--  		humanoid.WalkSpeed = humanoidState.WalkSpeed
--  		humanoid.JumpPower = humanoidState.JumpPower
--  		humanoid.JumpHeight = humanoidState.JumpHeight
--  		humanoid.AutoRotate = humanoidState.AutoRotate
--  	end

--  	for _, state in ipairs(guiStates) do
--  		if state.Instance.Parent then
--  			pcall(function()
--  				(state.Instance :: any)[state.Property] = state.Value
--  			end)
--  		end
--  	end
--  	for coreGuiType, wasEnabled in pairs(coreGuiStates) do
--  		pcall(function()
--  			StarterGui:SetCoreGuiEnabled(coreGuiType, wasEnabled)
--  		end)
--  	end

--  	if loadingScreen then
--  		loadingScreen.Visible = false
--  	end
--  	if fadeTargets then
--  		restoreFadeProperties(fadeTargets)
--  	end

--  	if camera then
--  		local currentCharacter = LOCAL_PLAYER.Character
--  		local currentHumanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
--  		if currentHumanoid then
--  			camera.CameraSubject = currentHumanoid
--  		end
--  		camera.CameraType = Enum.CameraType.Custom
--  		camera.FieldOfView = originalFieldOfView
--  	end
--  end

--  local fadeTargets: FadeTargets? = nil
--  local success, failure = xpcall(function()
--  	local playerGui = LOCAL_PLAYER:WaitForChild("PlayerGui") :: PlayerGui
--  	local mainGui = playerGui:WaitForChild("MainGui", 15)
--  	assert(mainGui and mainGui:IsA("ScreenGui"), "MainGui ScreenGui was not found")

--  	local screen = mainGui:WaitForChild("LoadingScreen", 15)
--  	assert(screen and screen:IsA("GuiObject"), "MainGui.LoadingScreen GuiObject was not found")
--  	loadingScreen = screen

--  	local progressBar = screen:WaitForChild("ProgressBar", 15)
--  	local progressImage = progressBar and progressBar:WaitForChild("ProgressImageLabel", 15)
--  	local progressGradient = progressImage and progressImage:WaitForChild("UIGradient", 15)
--  	local loadingLabel = screen:WaitForChild("LoadingLabel", 15)
--  	assert(progressGradient and progressGradient:IsA("UIGradient"), "ProgressImageLabel.UIGradient was not found")
--  	assert(loadingLabel and loadingLabel:IsA("TextLabel"), "LoadingScreen.LoadingLabel TextLabel was not found")

--  	local realCharacter = LOCAL_PLAYER.Character or LOCAL_PLAYER.CharacterAdded:Wait()
--  	local foundHumanoid = realCharacter:WaitForChild("Humanoid", 15)
--  	assert(foundHumanoid and foundHumanoid:IsA("Humanoid"), "The local character Humanoid was not found")
--  	local realHumanoid = foundHumanoid
--  	local activeCamera = waitForCamera()
--  	character = realCharacter
--  	humanoid = realHumanoid
--  	camera = activeCamera
--  	originalFieldOfView = activeCamera.FieldOfView

--  	screen.Visible = true
--  	loadingLabel.Text = "0 / 100"
--  	setProgressGradient(progressGradient, 0)
--  	fadeTargets = captureFadeProperties(screen)
--  	hideOtherInterfaces(playerGui, mainGui, screen)
--  	disablePlayerMovement(realHumanoid)

--  	characterRemovingConnection = LOCAL_PLAYER.CharacterRemoving:Connect(function(removingCharacter)
--  		if removingCharacter == realCharacter then
--  			aborted = true
--  		end
--  	end)

--  	activeCamera.CameraType = Enum.CameraType.Scriptable
--  	activeCamera.FieldOfView = LOADING_CAMERA_FOV
--  	activeCamera.CFrame = LOADING_CAMERA_CFRAME
--  	bindLoadingCamera(activeCamera)

--  	waitForCharacterAppearance(realCharacter)
--  	assert(not aborted and realCharacter.Parent, "The character was removed while its appearance was loading")
--  	characterClone = createCharacterClone(realCharacter, realHumanoid)

--  	if not game:IsLoaded() then
--  		game.Loaded:Wait()
--  	end

--  	local displayedProgress = 0
--  	local targetProgress = 0
--  	local preloadFinished = false
--  	task.spawn(function()
--  		preloadAssets(function(progress)
--  			targetProgress = progress * 100
--  		end)
--  		preloadFinished = true
--  	end)

--  	while not aborted do
--  		local dt = RunService.Heartbeat:Wait()
--  		local alpha = 1 - math.exp(-PROGRESS_RESPONSE * dt)
--  		displayedProgress += (targetProgress - displayedProgress) * alpha

--  		if preloadFinished and targetProgress >= 100 and displayedProgress >= 99.95 then
--  			displayedProgress = 100
--  		end

--  		local shownProgress = math.clamp(math.floor(displayedProgress), 0, 100)
--  		loadingLabel.Text = ("%d / 100"):format(shownProgress)
--  		setProgressGradient(progressGradient, displayedProgress / 100)

--  		if displayedProgress >= 100 then
--  			break
--  		end
--  	end

--  	assert(not aborted, "The character was removed during loading")
--  	task.wait(COMPLETION_HOLD)
--  	assert(not aborted and realHumanoid.Parent, "The character became unavailable before the camera transition")
-- 	transitionToPlayerCamera(activeCamera, realHumanoid, fadeTargets :: FadeTargets)
--  end, debug.traceback)

--  cleanup(fadeTargets)

--  if not success then
--  	warn("[LoadingScreen] Loading sequence recovered from an error:\n" .. tostring(failure))
--  end
