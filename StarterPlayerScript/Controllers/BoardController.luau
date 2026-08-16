--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ButtonEffects = require(ReplicatedStorage.Modules.Client.ButtonEffects)
local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)
local NotificationController = require(script.Parent.NotificationController)

local BoardController = {}

local ACTION_NAMES: { [string]: boolean } = {
	Blue = true,
	Green = true,
	Orange = true,
	Pink = true,
	Red = true,
	White = true,
	Yellow = true,
	Rainbow = true,
	Random = true,
}

local UI_BUTTON_CHOICES: { [string]: string } = {
	BlueBtn = "Blue",
	GreenBtn = "Green",
	PinkBtn = "Pink",
	RedBtn = "Red",
	WhiteBtn = "White",
	YellowBtn = "Yellow",
	Orange = "Orange",
	Rainbow = "Rainbow",
	Random = "Random",
}

local BUTTON_DEFAULT_COLOR = Color3.fromRGB(235, 231, 220)
local BUTTON_ACTIVE_COLOR = Color3.fromRGB(57, 255, 87)
local PANEL_ON_POSITION = UDim2.new(0.035, 0, 0.16, 0)
local PANEL_OFF_POSITION = UDim2.new(-0.349, 0, 0.16, 0)
local CHOICE_HEX: { [string]: string } = {
	Blue = "#145BE8",
	Green = "#2DC732",
	Orange = "#FF911E",
	Pink = "#E2468E",
	Red = "#EB3531",
	White = "#FFFFFF",
	Yellow = "#FFD619",
}
local RAINBOW_TEXT = table.concat({
	'<font color="#EB3531">R</font>',
	'<font color="#FF911E">a</font>',
	'<font color="#FFD619">i</font>',
	'<font color="#2DC732">n</font>',
	'<font color="#145BE8">b</font>',
	'<font color="#B446E6">o</font>',
	'<font color="#E2468E">w</font>',
})
local RAINBOW_COLORS = {
	Color3.fromRGB(235, 53, 49),
	Color3.fromRGB(255, 145, 30),
	Color3.fromRGB(255, 214, 25),
	Color3.fromRGB(45, 199, 50),
	Color3.fromRGB(20, 91, 232),
	Color3.fromRGB(180, 70, 230),
	Color3.fromRGB(226, 70, 142),
}
local RAINBOW_TWEEN_INFO = TweenInfo.new(1.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local player = Players.LocalPlayer
local remote: any
local tablesFolder: Instance
local sessionId: string? = nil
local activeBoard: Instance? = nil
local selectedPart: BasePart? = nil
local protectionPart: BasePart? = nil
local defaults: { [BasePart]: { CFrame: CFrame, Transparency: number, Color: Color3 } } = {}
local visibleBoards: { [Instance]: boolean } = {}
local boardGenerations: { [Instance]: number } = {}
local partTweens: { [BasePart]: Tween } = {}
local rainbowTweens: { [BasePart]: Tween } = {}
local rainbowGenerations: { [BasePart]: number } = {}
local uiChoiceButtons: { [string]: GuiButton } = {}
local selectedChoice: string? = nil
local protectionActive = false
local diceBoardPanel: GuiObject? = nil
local pickStatusLabel: TextLabel? = nil
local panelIsOpen = false
local lastUiChoice: string? = nil
local lastUiRequestAt = 0

local function richChoice(choice: string): string
	if choice == "Rainbow" then
		return RAINBOW_TEXT
	end
	local hex = CHOICE_HEX[choice] or "#FFFFFF"
	return `<font color="{hex}">{choice}</font>`
end

local function renderPickStatus()
	local label = pickStatusLabel
	if not label then
		return
	end
	label.RichText = true
	if selectedChoice then
		local protection = if protectionActive
			then ' <font color="#FF911E">+ PROTECTED</font>'
			else ""
		label.Text = `Picked: {richChoice(selectedChoice)}{protection}`
	elseif protectionActive then
		label.Text = '<font color="#FF911E">STREAK PROTECTION ACTIVE</font>'
	else
		label.Text = "Pick a Color"
	end
end

local function renderUiSelection()
	for choice, button in uiChoiceButtons do
		local isActive = choice == selectedChoice or (choice == "Orange" and protectionActive)
		local targetColor = if isActive then BUTTON_ACTIVE_COLOR else BUTTON_DEFAULT_COLOR
		TweenService:Create(button, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = targetColor,
		}):Play()
	end
	renderPickStatus()
end

local function animateRainbowColorBall(rainbowButton: GuiButton)
	local colorBall = rainbowButton:FindFirstChild("ColorBall", true)
	if not colorBall or not colorBall:IsA("GuiObject") then
		warn("[ColorGame] MainGui.DiceBoard.Rainbow is missing GuiObject ColorBall")
		return
	end
	task.spawn(function()
		local index = 1
		colorBall.BackgroundColor3 = RAINBOW_COLORS[index]
		while colorBall.Parent do
			index = index % #RAINBOW_COLORS + 1
			local tween = TweenService:Create(
				colorBall,
				RAINBOW_TWEEN_INFO,
				{ BackgroundColor3 = RAINBOW_COLORS[index] }
			)
			tween:Play()
			tween.Completed:Wait()
		end
	end)
end

local function setPanelOpen(isOpen: boolean, animate: boolean)
	panelIsOpen = isOpen
	local panel = diceBoardPanel
	if not panel then
		return
	end
	local target = if isOpen then PANEL_ON_POSITION else PANEL_OFF_POSITION
	if animate then
		TweenService:Create(panel, TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Position = target,
		}):Play()
	else
		panel.Position = target
	end
end

local function toggleDiceBoard()
	if sessionId then
		setPanelOpen(not panelIsOpen, true)
	else
		setPanelOpen(false, true)
		NotificationController.Notify("Sit at a table to open the Dice Board.", "Warning", 2.5)
	end
end


local function requestChoice(choice: string)
	if not sessionId then
		return
	end
	local now = os.clock()
	if lastUiChoice == choice and now - lastUiRequestAt < 0.08 then
		return
	end
	lastUiChoice = choice
	lastUiRequestAt = now
	remote:FireServer("Select", sessionId, choice)
end

local function isPointInside(gui: GuiObject, point: Vector2): boolean
	local position = gui.AbsolutePosition
	local size = gui.AbsoluteSize
	return point.X >= position.X and point.X <= position.X + size.X
		and point.Y >= position.Y and point.Y <= position.Y + size.Y
end

local function requestUiChoiceAt(point: Vector2): boolean
	if not panelIsOpen or not sessionId then
		return false
	end
	for choice, button in uiChoiceButtons do
		if button.Visible and isPointInside(button, point) then
			requestChoice(choice)
			return true
		end
	end
	return false
end

local function childNames(parent: Instance): string
	local names = {}
	for _, child in parent:GetChildren() do
		table.insert(names, `{child.Name} ({child.ClassName})`)
	end
	table.sort(names)
	return if #names > 0 then table.concat(names, ", ") else "<none>"
end

local function setupDiceBoardUi()
	local playerGui = player:WaitForChild("PlayerGui")
	local mainGui = playerGui:WaitForChild("MainGui", 10)
	if not mainGui then
		warn(`[ColorGame] Could not find PlayerGui.MainGui after 10 seconds. PlayerGui children: {childNames(playerGui)}`)
		return
	end
	local panel = mainGui:WaitForChild("DiceBoard", 10)
	if not panel then
		warn(`[ColorGame] Could not find PlayerGui.MainGui.DiceBoard after 10 seconds. MainGui children: {childNames(mainGui)}`)
		return
	end
	if not panel:IsA("GuiObject") then
		warn(`[ColorGame] PlayerGui.MainGui.DiceBoard must be a GuiObject, but found {panel.ClassName}`)
		return
	end
	diceBoardPanel = panel
	local statusLabel = panel:FindFirstChild("TextLabel")
	if statusLabel and statusLabel:IsA("TextLabel") then
		pickStatusLabel = statusLabel
		pickStatusLabel.RichText = true
	else
		warn("[ColorGame] PlayerGui.MainGui.DiceBoard is missing TextLabel for the pick status.")
	end

	for buttonName, choice in UI_BUTTON_CHOICES do
		local candidate = panel:FindFirstChild(buttonName, true)
		if candidate and candidate:IsA("GuiButton") then
			local requestedChoice = choice
			uiChoiceButtons[requestedChoice] = candidate
			candidate.Active = true
			candidate.Interactable = true
			candidate.Selectable = true
			candidate.BackgroundColor3 = BUTTON_DEFAULT_COLOR
			ButtonEffects.Bind(candidate, function()
				requestChoice(requestedChoice)
			end)
		else
			warn(`[ColorGame] PlayerGui.MainGui.DiceBoard is missing GuiButton {buttonName}. DiceBoard descendants: {childNames(panel)}`)
		end
	end
	local rainbowButton = uiChoiceButtons.Rainbow
	if rainbowButton then
		animateRainbowColorBall(rainbowButton)
	end

	local toggle = mainGui:FindFirstChild("BoardOpenAndClose", true)
		or panel:FindFirstChild("OnAndOff", true)
	if toggle and toggle:IsA("GuiButton") then
		toggle.Active = true
		toggle.Interactable = true
		toggle.Selectable = true
		ButtonEffects.Bind(toggle, toggleDiceBoard)
	else
		warn(
			`[ColorGame] Missing GuiButton MainGui.BoardOpenAndClose (legacy DiceBoard.OnAndOff also accepted). MainGui children: {childNames(mainGui)}`
		)
	end

	setPanelOpen(sessionId ~= nil, false)
	renderUiSelection()
end

local function isActionPart(instance: Instance): boolean
	return instance:IsA("BasePart") and ACTION_NAMES[instance.Name] == true
end

local function remember(part: BasePart)
	if not defaults[part] then
		defaults[part] = {
			CFrame = part.CFrame,
			Transparency = part.Transparency,
			Color = part.Color,
		}
	end
end

local function cancelPartTween(part: BasePart)
	local tween = partTweens[part]
	if tween then
		partTweens[part] = nil
		tween:Cancel()
	end
end

local function tweenPart(part: BasePart, info: TweenInfo, properties: { [string]: any })
	cancelPartTween(part)
	local tween = TweenService:Create(part, info, properties)
	partTweens[part] = tween
	tween.Completed:Connect(function()
		if partTweens[part] == tween then
			partTweens[part] = nil
		end
	end)
	tween:Play()
end

local function stopRainbowPart(part: BasePart)
	rainbowGenerations[part] = (rainbowGenerations[part] or 0) + 1
	local tween = rainbowTweens[part]
	if tween then
		rainbowTweens[part] = nil
		tween:Cancel()
	end
	local original = defaults[part]
	if original then
		part.Color = original.Color
	end
end

local function animateRainbowPart(part: BasePart, board: Instance)
	stopRainbowPart(part)
	rainbowGenerations[part] = (rainbowGenerations[part] or 0) + 1
	local generation = rainbowGenerations[part]
	part.Color = RAINBOW_COLORS[1]
	task.spawn(function()
		local index = 1
		while part.Parent and visibleBoards[board] and rainbowGenerations[part] == generation do
			index = index % #RAINBOW_COLORS + 1
			local tween = TweenService:Create(part, RAINBOW_TWEEN_INFO, {
				Color = RAINBOW_COLORS[index],
			})
			rainbowTweens[part] = tween
			tween:Play()
			tween.Completed:Wait()
			if rainbowTweens[part] == tween then
				rainbowTweens[part] = nil
			end
		end
	end)
end

local function hidePart(part: BasePart)
	remember(part)
	cancelPartTween(part)
	if part.Name == "Rainbow" then
		stopRainbowPart(part)
	end
	local original = defaults[part]
	part.Transparency = 1
	part.CFrame = original.CFrame - original.CFrame.UpVector * math.max(part.Size.Y, 0.5)
end

local function getActionParts(board: Instance): { BasePart }
	local parts: { BasePart } = {}
	for _, descendant in board:GetDescendants() do
		if isActionPart(descendant) then
			local part = descendant :: BasePart
			remember(part)
			table.insert(parts, part)
		end
	end
	table.sort(parts, function(a, b)
		return a.Name < b.Name
	end)
	return parts
end

local function resetSelection()
	if selectedPart and defaults[selectedPart] and selectedPart:IsDescendantOf(game) then
		tweenPart(selectedPart, TweenInfo.new(0.12), {
			CFrame = defaults[selectedPart].CFrame,
		})
	end
	selectedPart = nil
	selectedChoice = nil
	renderUiSelection()
end

local function resetProtection()
	if protectionPart and defaults[protectionPart] and protectionPart:IsDescendantOf(game) then
		tweenPart(protectionPart, TweenInfo.new(0.12), {
			CFrame = defaults[protectionPart].CFrame,
		})
	end
	protectionPart = nil
	protectionActive = false
	renderUiSelection()
end

local function hideBoard(board: Instance?)
	if not board then
		return
	end
	boardGenerations[board] = (boardGenerations[board] or 0) + 1
	for _, part in getActionParts(board) do
		hidePart(part)
	end
end

local function showBoard(board: Instance)
	boardGenerations[board] = (boardGenerations[board] or 0) + 1
	local generation = boardGenerations[board]
	local randomizer = Random.new()

	for _, part in getActionParts(board) do
		local original = defaults[part]
		if part.Name == "Rainbow" then
			animateRainbowPart(part, board)
		end
		part.Transparency = 1
		part.CFrame = original.CFrame
			* CFrame.new(randomizer:NextNumber(-4, 4), randomizer:NextNumber(2, 7), randomizer:NextNumber(-4, 4))
			* CFrame.Angles(
				math.rad(randomizer:NextNumber(-140, 140)),
				math.rad(randomizer:NextNumber(-140, 140)),
				math.rad(randomizer:NextNumber(-140, 140))
			)

		tweenPart(part, TweenInfo.new(3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			CFrame = original.CFrame,
			Transparency = original.Transparency,
		})
	end

	task.delay(3, function()
		if generation ~= boardGenerations[board] or not visibleBoards[board] then
			return
		end
		for _, part in getActionParts(board) do
			local original = defaults[part]
			part.CFrame = original.CFrame
			part.Transparency = original.Transparency
		end
	end)
end

local function setSelection(choice: string?, _isLocked: boolean)
	resetSelection()
	if not choice or not activeBoard then
		return
	end
	selectedChoice = choice
	renderUiSelection()
	local candidate = activeBoard:FindFirstChild(choice, true)
	if not candidate or not candidate:IsA("BasePart") or not defaults[candidate] then
		return
	end
	selectedPart = candidate
	local original = defaults[candidate]
	local depressed = original.CFrame - original.CFrame.UpVector * (candidate.Size.Y * 0.5)
	tweenPart(candidate, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = depressed,
	})
end

local function setProtection(isActive: boolean)
	resetProtection()
	if not isActive or not activeBoard then
		return
	end
	protectionActive = true
	renderUiSelection()
	local candidate = activeBoard:FindFirstChild("Orange", true)
	if not candidate or not candidate:IsA("BasePart") or not defaults[candidate] then
		return
	end
	protectionPart = candidate
	local original = defaults[candidate]
	local depressed = original.CFrame - original.CFrame.UpVector * (candidate.Size.Y * 0.5)
	tweenPart(candidate, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = depressed,
	})
end

local function raycastBoard(screenPosition: Vector2): BasePart?
	local board = activeBoard
	local camera = workspace.CurrentCamera
	if not board or not camera then
		return nil
	end
	-- ScreenPointToRay uses the same screen-space coordinates supplied by
	-- mouse and touch events and accounts for Roblox's top-bar inset.
	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { board }
	params.IgnoreWater = true
	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	if result and isActionPart(result.Instance) then
		return result.Instance :: BasePart
	end
	return nil
end

local function selectAtPosition(position: Vector2)
	if not sessionId then
		return
	end
	local part = raycastBoard(position)
	if part then
		requestChoice(part.Name)
	end
end

local function onInput(input: InputObject, processed: boolean)
	if not sessionId then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local position = UserInputService:GetMouseLocation()
		if requestUiChoiceAt(position) then
			return
		end
		if not processed then
			selectAtPosition(position)
		end
	elseif input.UserInputType == Enum.UserInputType.Touch then
		requestUiChoiceAt(Vector2.new(input.Position.X, input.Position.Y))
	else
		return
	end
end

local function onTouchTapInWorld(position: Vector2, processedByUI: boolean)
	if processedByUI then
		return
	end
	selectAtPosition(position)
end

local function onServerEvent(action: string, ...: any)
	local args = table.pack(...)
	if action == "SeatAssigned" then
		local wasSeated = sessionId ~= nil
		local assignedBoard = args[2]
		if activeBoard ~= assignedBoard then
			resetSelection()
			resetProtection()
		end
		sessionId = args[1]
		activeBoard = assignedBoard
		if not wasSeated then
			setPanelOpen(true, true)
		end
		if activeBoard and not visibleBoards[activeBoard] then
			visibleBoards[activeBoard] = true
			showBoard(activeBoard)
		end
	elseif action == "SeatReleased" then
		if sessionId == args[1] then
			resetSelection()
			resetProtection()
			sessionId = nil
			activeBoard = nil
			setPanelOpen(false, true)
		end
	elseif action == "Selection" then
		setSelection(args[1], args[2] == true)
	elseif action == "Protection" then
		setProtection(args[1] == true)
	elseif action == "BoardVisibility" then
		local board = args[1]
		if typeof(board) == "Instance" then
			local isVisible = args[2] == true
			if isVisible and not visibleBoards[board] then
				visibleBoards[board] = true
				showBoard(board)
			elseif not isVisible and visibleBoards[board] then
				visibleBoards[board] = nil
				hideBoard(board)
			end
		end
	elseif action == "BoardSnapshot" and type(args[1]) == "table" then
		local snapshotBoards: { [Instance]: boolean } = {}
		for _, board in args[1] do
			if typeof(board) == "Instance" then
				snapshotBoards[board] = true
				if not visibleBoards[board] then
					visibleBoards[board] = true
					showBoard(board)
				end
			end
		end
		for board in visibleBoards do
			if not snapshotBoards[board] then
				visibleBoards[board] = nil
				hideBoard(board)
			end
		end
	end
end

function BoardController.Init()
	task.defer(setupDiceBoardUi)
	tablesFolder = workspace:WaitForChild("ScriptableParts"):WaitForChild("Tables")
	for _, descendant in tablesFolder:GetDescendants() do
		if isActionPart(descendant) then
			hidePart(descendant :: BasePart)
		end
	end
	tablesFolder.DescendantAdded:Connect(function(descendant)
		if isActionPart(descendant) and (not activeBoard or not descendant:IsDescendantOf(activeBoard)) then
			task.defer(hidePart, descendant :: BasePart)
		end
	end)

	remote = Remote.New("ColorGameEvent")
	remote.OnClientEvent:Connect(onServerEvent)
	UserInputService.InputBegan:Connect(onInput)
	UserInputService.TouchTapInWorld:Connect(onTouchTapInWorld)
	remote:FireServer("ClientReady")
	task.delay(1, function()
		if not sessionId then
			remote:FireServer("ClientReady")
		end
	end)
end

return BoardController
