--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)

local NotificationController = {}

type Notification = {
	Text: string,
	Kind: string,
	Duration: number,
}

local COLORS: { [string]: Color3 } = {
	Info = Color3.fromRGB(235, 231, 220),
	Success = Color3.fromRGB(57, 255, 87),
	Warning = Color3.fromRGB(255, 214, 25),
	Error = Color3.fromRGB(255, 90, 90),
}

local container: GuiObject?
local template: GuiObject?
local queue: { Notification } = {}
local processing = false
local lastMessages: { [string]: number } = {}

local function setLabelText(root: GuiObject, value: string, color: Color3)
	if root:IsA("TextLabel") or root:IsA("TextButton") then
		root.Text = value
		root.TextColor3 = color
	end
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			descendant.Text = value
			descendant.TextColor3 = color
		end
	end
end

local function tweenAndWait(instance: Instance, info: TweenInfo, properties: { [string]: any })
	local tween = TweenService:Create(instance, info, properties)
	tween:Play()
	tween.Completed:Wait()
end

local function display(item: Notification)
	local currentContainer = container
	local currentTemplate = template
	if not currentContainer or not currentTemplate then
		return
	end
	local label = currentTemplate:Clone()
	label.Name = "Notification"
	label.Visible = true
	label.AutomaticSize = Enum.AutomaticSize.None
	local defaultSize = currentTemplate.Size
	local defaultBackgroundTransparency = currentTemplate.BackgroundTransparency
	local textDefaults: { [GuiObject]: number } = {}
	if label:IsA("TextLabel") or label:IsA("TextButton") then
		textDefaults[label] = label.TextTransparency
		label.TextTransparency = 1
	end
	for _, descendant in label:GetDescendants() do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			textDefaults[descendant] = descendant.TextTransparency
			descendant.TextTransparency = 1
		end
	end
	setLabelText(label, item.Text, COLORS[item.Kind] or COLORS.Info)
	label.Size = UDim2.new(defaultSize.X.Scale, defaultSize.X.Offset, 0, 0)
	label.BackgroundTransparency = 1
	label.Parent = currentContainer

	local openInfo = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(label, openInfo, {
		Size = defaultSize,
		BackgroundTransparency = defaultBackgroundTransparency,
	}):Play()
	for textObject, transparency in textDefaults do
		TweenService:Create(textObject, openInfo, { TextTransparency = transparency }):Play()
	end
	task.wait(0.32 + item.Duration)

	local closeInfo = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	for textObject in textDefaults do
		TweenService:Create(textObject, closeInfo, { TextTransparency = 1 }):Play()
	end
	tweenAndWait(label, closeInfo, {
		Size = UDim2.new(defaultSize.X.Scale, defaultSize.X.Offset, 0, 0),
		BackgroundTransparency = 1,
	})
	label:Destroy()
end

local function processQueue()
	if processing or not container or not template then
		return
	end
	processing = true
	task.spawn(function()
		while #queue > 0 do
			display(table.remove(queue, 1))
		end
		processing = false
	end)
end

local function tryBindUi(playerGui: PlayerGui): boolean
	if container and template and container:IsDescendantOf(playerGui) and template:IsDescendantOf(playerGui) then
		return true
	end
	local mainGui = playerGui:FindFirstChild("MainGui")
	local frame = mainGui and mainGui:FindFirstChild("NotificationFrame")
	local templateObject = frame and frame:FindFirstChild("TemplateLabel")
	if not frame or not frame:IsA("GuiObject") or not templateObject or not templateObject:IsA("GuiObject") then
		return false
	end
	container = frame
	template = templateObject
	templateObject.Visible = false
	processQueue()
	return true
end

function NotificationController.Notify(text: string, kind: string?, duration: number?)
	if text == "" then
		return
	end
	local now = os.clock()
	if now - (lastMessages[text] or 0) < 0.75 then
		return
	end
	lastMessages[text] = now
	table.insert(queue, {
		Text = text,
		Kind = kind or "Info",
		Duration = math.clamp(duration or 2.5, 0.5, 8),
	})
	processQueue()
end

function NotificationController.Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	tryBindUi(playerGui)
	playerGui.DescendantAdded:Connect(function()
		task.defer(tryBindUi, playerGui)
	end)

	local remote = Remote.New("ColorGameEvent")
	remote.OnClientEvent:Connect(function(action: string, ...: any)
		local args = table.pack(...)
		if action == "Notice" then
			NotificationController.Notify(tostring(args[1]), "Error")
		elseif action == "Notify" then
			NotificationController.Notify(tostring(args[1]), tostring(args[2] or "Warning"))
		elseif action == "Outcome" then
			local won = args[1] == true
			local reward = math.max(0, tonumber(args[2]) or 0)
			local protected = args[4] == true
			if won then
				local suffix = if reward == 1 then "Win" else "Wins"
				NotificationController.Notify(`YOU WON! +{reward} {suffix}`, "Success", 3)
			elseif protected then
				NotificationController.Notify("YOU LOST — STREAK PROTECTED", "Warning", 3)
			else
				NotificationController.Notify("YOU LOST — STREAK RESET", "Error", 3)
			end
		end
	end)
end

return NotificationController
