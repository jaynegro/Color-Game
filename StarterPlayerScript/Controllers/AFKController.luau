--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local AFKController = {}

local REJOIN_AFTER = 17 * 60 -- 17 minutes

local initialized = false
local rejoinRequested = false

local function createTeleportGui(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "AFKReconnectGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	background.BorderSizePixel = 0
	background.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.46)
	title.Size = UDim2.fromScale(0.8, 0.08)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "Refreshing your session..."
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.Parent = background

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
	subtitle.Position = UDim2.fromScale(0.5, 0.54)
	subtitle.Size = UDim2.fromScale(0.7, 0.05)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.Gotham
	subtitle.Text = "You've been inactive for a while."
	subtitle.TextColor3 = Color3.fromRGB(175, 175, 185)
	subtitle.TextScaled = true
	subtitle.Parent = background

	return gui
end

function AFKController.Init()
	if initialized then
		return
	end

	initialized = true

	local player = Players.LocalPlayer
	local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)
	local afkRejoinRemote = Remote.New("AFKRejoin") :: any

	player.Idled:Connect(function(idleTime: number)
		if rejoinRequested then
			return
		end

		if idleTime < REJOIN_AFTER then
			return
		end

		rejoinRequested = true

		print(`[ColorGame] Player AFK for ` .. `{math.floor(idleTime)} seconds. Rejoining...`)

		local teleportGui = createTeleportGui()
		TeleportService:SetTeleportGui(teleportGui)

		afkRejoinRemote:FireServer()
	end)
end

return AFKController
