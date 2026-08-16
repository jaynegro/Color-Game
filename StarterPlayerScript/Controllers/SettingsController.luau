--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local ButtonEffects = require(ReplicatedStorage.Modules.Client.ButtonEffects)

local SettingsController = {}

type SettingDefinition = {
	Name: string,
	Group: SoundGroup,
	DefaultVolume: number,
}

local ON_COLOR = Color3.fromRGB(57, 255, 87)
local OFF_COLOR = Color3.fromRGB(235, 53, 49)
local TOGGLE_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PANEL_TWEEN = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local PANEL_CLOSE_TWEEN = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local initialized = false
local panelTween: Tween? = nil

local function getGuiButton(root: Instance, name: string): GuiButton?
	local candidate = root:FindFirstChild(name, true)
	return if candidate and candidate:IsA("GuiButton") then candidate else nil
end

local function getTextLabel(root: Instance, name: string): TextLabel?
	local candidate = root:FindFirstChild(name)
	return if candidate and candidate:IsA("TextLabel") then candidate else nil
end

local function renderToggle(button: GuiButton, enabled: boolean)
	local title = getTextLabel(button, "Title")
	if title then
		title.Text = if enabled then "ON" else "OFF"
	end
	TweenService:Create(button, TOGGLE_TWEEN, {
		BackgroundColor3 = if enabled then ON_COLOR else OFF_COLOR,
	}):Play()
end

local function bindSettingRow(template: Frame, definition: SettingDefinition, order: number)
	local row = template:Clone()
	row.Name = definition.Name
	row.LayoutOrder = order
	row.Visible = true
	row.Parent = template.Parent

	local rowTitle = getTextLabel(row, "Title")
	local button = getGuiButton(row, "Button")
	if not rowTitle or not button then
		warn(`[ColorGame] Settings template is missing Title or Button for {definition.Name}`)
		row:Destroy()
		return
	end

	rowTitle.Text = definition.Name
	button.Active = true
	button.Interactable = true
	button.Selectable = true

	local enabled = true
	local function apply()
		definition.Group.Volume = if enabled then definition.DefaultVolume else 0
		renderToggle(button, enabled)
	end

	ButtonEffects.Bind(button, function()
		enabled = not enabled
		apply()
	end)
	apply()
end

local function getOrCreateScale(panel: GuiObject): UIScale
	local existing = panel:FindFirstChild("SettingsPanelScale")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local scale = Instance.new("UIScale")
	scale.Name = "SettingsPanelScale"
	scale.Parent = panel
	return scale
end

local function setPanelVisible(panel: GuiObject, scale: UIScale, visible: boolean)
	if panelTween then
		panelTween:Cancel()
		panelTween = nil
	end

	if visible then
		panel.Visible = true
		scale.Scale = 0.82
		panelTween = TweenService:Create(scale, PANEL_TWEEN, { Scale = 1 })
		panelTween:Play()
	else
		panelTween = TweenService:Create(scale, PANEL_CLOSE_TWEEN, { Scale = 0.82 })
		local closingTween = panelTween
		closingTween.Completed:Once(function(playbackState)
			if panelTween == closingTween and playbackState == Enum.PlaybackState.Completed then
				panel.Visible = false
				panelTween = nil
			end
		end)
		closingTween:Play()
	end
end

function SettingsController.Init()
	if initialized then
		return
	end
	initialized = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", 10)
	if not playerGui or not playerGui:IsA("PlayerGui") then
		warn("[ColorGame] Settings could not find PlayerGui")
		return
	end
	local mainGui = playerGui:WaitForChild("MainGui", 10)
	local hud = playerGui:WaitForChild("HUD", 10)
	if not mainGui or not hud then
		warn("[ColorGame] Settings requires PlayerGui.MainGui and PlayerGui.HUD")
		return
	end

	local panel = mainGui:FindFirstChild("Settings")
	local scroll = panel and panel:FindFirstChild("Scroll")
	local template = scroll and scroll:FindFirstChild("Template")
	local openButton = getGuiButton(hud, "Settings")
	local closeButton = panel and getGuiButton(panel, "Close")
	if not panel or not panel:IsA("GuiObject") or not scroll or not template or not template:IsA("Frame")
		or not openButton or not closeButton then
		warn("[ColorGame] Invalid Settings hierarchy; expected MainGui.Settings.Scroll.Template, Settings.Top.Container.Close, and HUD.Left.Settings")
		return
	end

	local musicGroup = SoundService:WaitForChild("Music", 10)
	local sfxGroup = SoundService:WaitForChild("SFX", 10)
	if not musicGroup or not musicGroup:IsA("SoundGroup") or not sfxGroup or not sfxGroup:IsA("SoundGroup") then
		warn("[ColorGame] Settings requires SoundService.Music and SoundService.SFX SoundGroups")
		return
	end

	local definitions: { SettingDefinition } = {
		{ Name = "Music", Group = musicGroup, DefaultVolume = musicGroup.Volume },
		{ Name = "SFX", Group = sfxGroup, DefaultVolume = sfxGroup.Volume },
	}
	template.Visible = false
	for index, definition in definitions do
		bindSettingRow(template, definition, template.LayoutOrder + index - 1)
	end

	panel.Active = true
	local panelScale = getOrCreateScale(panel)
	panelScale.Scale = 0.82
	panel.Visible = false
	openButton.Active = true
	openButton.Interactable = true
	openButton.Selectable = true
	closeButton.Active = true
	closeButton.Interactable = true
	closeButton.Selectable = true

	ButtonEffects.Bind(openButton, function()
		setPanelVisible(panel, panelScale, not panel.Visible)
	end)
	ButtonEffects.Bind(closeButton, function()
		setPanelVisible(panel, panelScale, false)
	end)
end

return SettingsController
