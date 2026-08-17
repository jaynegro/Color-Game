--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ButtonEffects = require(ReplicatedStorage.Modules.Client.ButtonEffects)
local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)

local DuelController = {}

local TRANSITION_INFO = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local thumbnailCache: { [number]: string } = {}
local panelGeneration = 0
local avatarGeneration = 0

local function findAmount(container: Instance): TextLabel | TextButton?
	local innerContainer = container:FindFirstChild("Container")
	local valueSource = innerContainer or container
	local value = valueSource:FindFirstChild("Value")
	if not value then
		value = container:FindFirstChild("Value", true)
	end
	local amount = value and value:FindFirstChild("Amount", true)
	if amount and (amount:IsA("TextLabel") or amount:IsA("TextButton")) then
		return amount
	end
	return nil
end

local function setDuelAmount(container: Instance, ownValue: number, opponentValue: number)
	local amount = findAmount(container)
	if not amount then
		return
	end
	amount.Text = `{math.max(0, math.floor(ownValue))}  /  {math.max(0, math.floor(opponentValue))}`
	local shadow = amount:FindFirstChild("Amount2")
	if shadow and (shadow:IsA("TextLabel") or shadow:IsA("TextButton")) then
		shadow.Text = amount.Text
	end
end

local function getScale(gui: GuiObject): UIScale
	local existing = gui:FindFirstChild("DuelTransitionScale")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local scale = Instance.new("UIScale")
	scale.Name = "DuelTransitionScale"
	scale.Parent = gui
	return scale
end

local function setPvpVisible(top: GuiObject, topPvp: GuiObject, active: boolean, animate: boolean)
	panelGeneration += 1
	local generation = panelGeneration
	local outgoing = if active then top else topPvp
	local incoming = if active then topPvp else top
	local outgoingScale = getScale(outgoing)
	local incomingScale = getScale(incoming)

	if not animate then
		outgoing.Visible = false
		outgoingScale.Scale = 1
		incoming.Visible = true
		incomingScale.Scale = 1
		return
	end

	incoming.Visible = true
	incomingScale.Scale = 0
	local hideTween = TweenService:Create(
		outgoingScale,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Scale = 0 }
	)
	hideTween:Play()
	hideTween.Completed:Once(function()
		if generation ~= panelGeneration then
			return
		end
		outgoing.Visible = false
		outgoingScale.Scale = 1
		TweenService:Create(incomingScale, TRANSITION_INFO, { Scale = 1 }):Play()
	end)
end

local function setAvatar(image: ImageLabel, userId: number, generation: number)
	local cached = thumbnailCache[userId]
	if cached then
		image.Image = cached
		return
	end
	task.spawn(function()
		local ok, content = pcall(
			Players.GetUserThumbnailAsync,
			Players,
			userId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size100x100
		)
		if ok then
			thumbnailCache[userId] = content
			if generation == avatarGeneration and image.Parent then
				image.Image = content
			end
		end
	end)
end

function DuelController.Init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local mainGui = playerGui:WaitForChild("MainGui")
	local hud = playerGui:WaitForChild("HUD")
	local invitationFrame = mainGui:WaitForChild("TablePvpFrame")
	local sendButton = invitationFrame:WaitForChild("SendBtn")
	local confirmButton = invitationFrame:WaitForChild("ConfirmationBtn")
	local top = hud:WaitForChild("Top")
	local topPvp = hud:WaitForChild("TopPvp")

	assert(invitationFrame:IsA("GuiObject"), "[ColorGame] MainGui.TablePvpFrame must be a GuiObject")
	assert(sendButton:IsA("GuiButton"), "[ColorGame] TablePvpFrame.SendBtn must be a GuiButton")
	assert(confirmButton:IsA("GuiButton"), "[ColorGame] TablePvpFrame.ConfirmationBtn must be a GuiButton")
	assert(top:IsA("GuiObject") and topPvp:IsA("GuiObject"), "[ColorGame] HUD.Top and HUD.TopPvp must be GuiObjects")

	local winContainer = topPvp:WaitForChild("WinContainer")
	local streakContainer = topPvp:WaitForChild("StreakContainer")
	local winInner = winContainer:WaitForChild("Container")
	local player1Icon = winInner:WaitForChild("Player1Icon")
	local player2Icon = winInner:WaitForChild("Player2Icon")
	assert(player1Icon:IsA("ImageLabel") and player2Icon:IsA("ImageLabel"), "[ColorGame] TopPvp WinContainer player icons must be ImageLabels")

	invitationFrame.Visible = false
	sendButton.Visible = false
	confirmButton.Visible = false
	setPvpVisible(top, topPvp, false, false)
	setDuelAmount(winContainer, 0, 0)
	setDuelAmount(streakContainer, 0, 0)

	local remote = Remote.New("ColorGameEvent")
	ButtonEffects.Bind(sendButton, function()
		sendButton.Visible = false
		remote:FireServer("DuelInvite")
	end)
	ButtonEffects.Bind(confirmButton, function()
		confirmButton.Visible = false
		remote:FireServer("DuelAccept")
	end)

	local duelActive = false
	remote.OnClientEvent:Connect(function(action: string, ...: any)
		local args = table.pack(...)
		if action == "DuelLobby" then
			local status = tostring(args[1] or "Hidden")
			local visible = status == "Available" or status == "Incoming"
			invitationFrame.Visible = visible
			sendButton.Visible = status == "Available"
			confirmButton.Visible = status == "Incoming"
		elseif action == "DuelState" then
			local active = args[1] == true
			if active then
				local opponentUserId = tonumber(args[2]) or 0
				setDuelAmount(winContainer, tonumber(args[3]) or 0, tonumber(args[4]) or 0)
				setDuelAmount(streakContainer, tonumber(args[5]) or 0, tonumber(args[6]) or 0)
				avatarGeneration += 1
				local generation = avatarGeneration
				setAvatar(player1Icon, player.UserId, generation)
				if opponentUserId > 0 then
					setAvatar(player2Icon, opponentUserId, generation)
				end
				invitationFrame.Visible = false
			end
			if duelActive ~= active then
				duelActive = active
				setPvpVisible(top, topPvp, active, true)
			end
		end
	end)

	remote:FireServer("DuelReady")
	task.delay(1, function()
		remote:FireServer("DuelReady")
	end)
end

return DuelController
