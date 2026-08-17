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
local PANEL_ON_POSITION = UDim2.new(0.003, 0, 0.441, 0)
local PANEL_OFF_POSITION = UDim2.new(-100, 0, 0.441, 0)
local PANEL_TWEEN_INFO = TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
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
local CHOICE_LABEL_TWEEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local CHOICE_LABEL_BOTTOM_OFFSET = 10

type ChoiceLabelState = {
	Label: GuiObject,
	DefaultPosition: UDim2,
	TextTransparency: { [TextLabel | TextButton]: number },
	StrokeTransparency: { [TextLabel | TextButton]: number },
	UIStrokeTransparency: { [UIStroke]: number },
	Hovering: boolean,
	Tweens: { Tween },
}

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
local choiceLabelStates: { [string]: ChoiceLabelState } = {}
local selectedChoice: string? = nil
local selectedUiChoice: string? = nil
local protectionActive = false
local diceBoardPanel: GuiObject? = nil
local diceBoardTween: Tween? = nil
local leftFrame: GuiObject? = nil
local leftFrameDefaultPosition: UDim2? = nil
local leftFrameTween: Tween? = nil
local panelTweenGeneration = 0
local pickStatusLabel: TextLabel? = nil
local panelIsOpen = false
local lastUiChoice: string? = nil
local lastUiRequestAt = 0
local arrowLoopGeneration = 0
local arrowTweens: { [GuiObject]: { Tween } } = {}
local arrowDefaultPositions: { [GuiObject]: UDim2 } = {}
local arrowInstances: { GuiObject } = {}

local ARROW_BOUNCE_INFO_UP = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local ARROW_BOUNCE_INFO_DOWN = TweenInfo.new(0.24, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local ARROW_BOUNCE_OFFSET = 12

local function choiceIsActive(choice: string): boolean
	return choice == selectedUiChoice or (choice == "Orange" and protectionActive)
end

local function cancelChoiceLabelTweens(state: ChoiceLabelState)
	for _, tween in state.Tweens do
		tween:Cancel()
	end
	table.clear(state.Tweens)
end

local function setChoiceLabelVisible(choice: string, visible: boolean, animate: boolean)
	local state = choiceLabelStates[choice]
	if not state or not state.Label.Parent then
		return
	end
	cancelChoiceLabelTweens(state)
	local targetPosition = if visible
		then state.DefaultPosition
		else state.DefaultPosition + UDim2.fromOffset(0, CHOICE_LABEL_BOTTOM_OFFSET)
	if not animate then
		state.Label.Position = targetPosition
		for textObject, original in state.TextTransparency do
			textObject.TextTransparency = if visible then original else 1
			textObject.TextStrokeTransparency = if visible then state.StrokeTransparency[textObject] else 1
		end
		for stroke, original in state.UIStrokeTransparency do
			stroke.Transparency = if visible then original else 1
		end
		return
	end

	local positionTween = TweenService:Create(state.Label, CHOICE_LABEL_TWEEN_INFO, {
		Position = targetPosition,
	})
	table.insert(state.Tweens, positionTween)
	positionTween:Play()
	for textObject, original in state.TextTransparency do
		if textObject.Parent then
			local tween = TweenService:Create(textObject, CHOICE_LABEL_TWEEN_INFO, {
				TextTransparency = if visible then original else 1,
				TextStrokeTransparency = if visible then state.StrokeTransparency[textObject] else 1,
			})
			table.insert(state.Tweens, tween)
			tween:Play()
		end
	end
	for stroke, original in state.UIStrokeTransparency do
		if stroke.Parent then
			local tween = TweenService:Create(stroke, CHOICE_LABEL_TWEEN_INFO, {
				Transparency = if visible then original else 1,
			})
			table.insert(state.Tweens, tween)
			tween:Play()
		end
	end
end

local function setupChoiceLabel(choice: string, button: GuiButton)
	local label = button:FindFirstChild("Title")
	if not label or not label:IsA("GuiObject")
		or not (label:IsA("TextLabel") or label:IsA("TextButton")) then
		return
	end
	local textTransparency: { [TextLabel | TextButton]: number } = {}
	local strokeTransparency: { [TextLabel | TextButton]: number } = {}
	local uiStrokeTransparency: { [UIStroke]: number } = {}
	local textObjects: { TextLabel | TextButton } = { label :: any }
	for _, descendant in label:GetDescendants() do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			table.insert(textObjects, descendant)
		elseif descendant:IsA("UIStroke") then
			uiStrokeTransparency[descendant] = descendant.Transparency
		end
	end
	for _, textObject in textObjects do
		textObject.Text = choice
		textTransparency[textObject] = textObject.TextTransparency
		strokeTransparency[textObject] = textObject.TextStrokeTransparency
	end
	label.Visible = true
	choiceLabelStates[choice] = {
		Label = label,
		DefaultPosition = label.Position,
		TextTransparency = textTransparency,
		StrokeTransparency = strokeTransparency,
		UIStrokeTransparency = uiStrokeTransparency,
		Hovering = false,
		Tweens = {},
	}
	button.MouseEnter:Connect(function()
		local state = choiceLabelStates[choice]
		if state then
			state.Hovering = true
			setChoiceLabelVisible(choice, true, true)
		end
	end)
	button.MouseLeave:Connect(function()
		local state = choiceLabelStates[choice]
		if state then
			state.Hovering = false
			setChoiceLabelVisible(choice, choiceIsActive(choice), true)
		end
	end)
	setChoiceLabelVisible(choice, choiceIsActive(choice), false)
end

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
		local isActive = choiceIsActive(choice)
		local targetColor = if isActive then BUTTON_ACTIVE_COLOR else BUTTON_DEFAULT_COLOR
		TweenService:Create(button, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = targetColor,
		}):Play()
		local labelState = choiceLabelStates[choice]
		setChoiceLabelVisible(choice, isActive or (labelState and labelState.Hovering == true), true)
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
	panelTweenGeneration += 1
	local generation = panelTweenGeneration
	if diceBoardTween then
		diceBoardTween:Cancel()
		diceBoardTween = nil
	end
	if leftFrameTween then
		leftFrameTween:Cancel()
		leftFrameTween = nil
	end
	local target = if isOpen then PANEL_ON_POSITION else PANEL_OFF_POSITION
	local left = leftFrame
	local leftDefault = leftFrameDefaultPosition
	if left and leftDefault then
		local leftTarget = if isOpen
			then UDim2.new(-1, leftDefault.X.Offset, leftDefault.Y.Scale, leftDefault.Y.Offset)
			else leftDefault
		if animate then
			leftFrameTween = TweenService:Create(left, PANEL_TWEEN_INFO, { Position = leftTarget })
			leftFrameTween:Play()
		else
			left.Position = leftTarget
		end
	end
	if isOpen then
		panel.Visible = true
	end
	if animate then
		local tween = TweenService:Create(panel, PANEL_TWEEN_INFO, {
			Position = target,
		})
		diceBoardTween = tween
		tween.Completed:Connect(function(playbackState)
			if generation ~= panelTweenGeneration or diceBoardTween ~= tween then
				return
			end
			diceBoardTween = nil
			if playbackState == Enum.PlaybackState.Completed and not isOpen then
				panel.Visible = false
			end
		end)
		tween:Play()
	else
		panel.Position = target
		panel.Visible = isOpen
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

local function childNames(parent: Instance): string
	local names = {}
	for _, child in parent:GetChildren() do
		table.insert(names, `{child.Name} ({child.ClassName})`)
	end
	table.sort(names)
	return if #names > 0 then table.concat(names, ", ") else "<none>"
end

local function offsetPosition(position: UDim2, yOffset: number): UDim2
	return UDim2.new(position.X.Scale, position.X.Offset + yOffset, position.Y.Scale, position.Y.Offset)
end

local function cancelArrowTweens(arrow: GuiObject)
	local tweens = arrowTweens[arrow]
	if not tweens then
		return
	end
	arrowTweens[arrow] = nil
	for _, tween in tweens do
		tween:Cancel()
	end
end

local function animateArrowBounce(arrow: GuiObject, generation: number)
	cancelArrowTweens(arrow)
	local defaultPosition = arrowDefaultPositions[arrow] or arrow.Position
	arrowDefaultPositions[arrow] = defaultPosition

	task.spawn(function()
		while arrow.Parent and generation == arrowLoopGeneration do
			local upTween = TweenService:Create(arrow, ARROW_BOUNCE_INFO_UP, {
				Position = offsetPosition(defaultPosition, -ARROW_BOUNCE_OFFSET),
			})
			arrowTweens[arrow] = { upTween }
			upTween:Play()
			upTween.Completed:Wait()
			if generation ~= arrowLoopGeneration or not arrow.Parent then
				break
			end

			local downTween = TweenService:Create(arrow, ARROW_BOUNCE_INFO_DOWN, {
				Position = defaultPosition,
			})
			arrowTweens[arrow] = { downTween }
			downTween:Play()
			downTween.Completed:Wait()
		end
		if arrowTweens[arrow] then
			arrowTweens[arrow] = nil
		end
	end)
end

local function setupArrowBounce(panel: Instance)
	arrowLoopGeneration += 1
	local generation = arrowLoopGeneration

	for _, descendant in panel:GetDescendants() do
		if descendant.Name == "Arrows" and descendant:IsA("GuiObject") then
			local arrow = descendant :: GuiObject
			local alreadyTracked = false
			for _, tracked in arrowInstances do
				if tracked == arrow then
					alreadyTracked = true
					break
				end
			end
			if not alreadyTracked then
				table.insert(arrowInstances, arrow)
			end
			arrowDefaultPositions[arrow] = arrow.Position
			animateArrowBounce(arrow, generation)
		end
	end
end

local function setArrowsVisible(visible: boolean)
	if visible then
		arrowLoopGeneration += 1
		local generation = arrowLoopGeneration
		for _, arrow in arrowInstances do
			if arrow.Parent then
				arrow.Visible = true
				animateArrowBounce(arrow, generation)
			end
		end
		return
	end

	arrowLoopGeneration += 1
	for _, arrow in arrowInstances do
		cancelArrowTweens(arrow)
		if arrow.Parent then
			arrow.Visible = false
		end
	end
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
	panel.AnchorPoint = Vector2.new(0, 0.5)
	setupArrowBounce(panel)

	local hud = playerGui:FindFirstChild("HUD") or playerGui:WaitForChild("HUD", 10)
	local left = hud and hud:FindFirstChild("Left")
	if left and left:IsA("GuiObject") then
		leftFrame = left
		leftFrameDefaultPosition = left.Position
	else
		warn("[ColorGame] PlayerGui.HUD.Left must be a GuiObject for DiceBoard coordination.")
	end
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
			setupChoiceLabel(requestedChoice, candidate)
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
	selectedUiChoice = nil
	setArrowsVisible(true)
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

local function setSelection(choice: string?, _isLocked: boolean, displayedChoice: string?)
	resetSelection()
	if not choice or not activeBoard then
		return
	end
	selectedChoice = choice
	selectedUiChoice = displayedChoice or choice
	setArrowsVisible(false)
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
	if not sessionId or processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		selectAtPosition(UserInputService:GetMouseLocation())
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
		setSelection(args[1], args[2] == true, args[3])
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
