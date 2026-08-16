--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OverheadService = {}

local TEMPLATE_NAME = "OverHeadTemplate"

local dataManager: any
local template: Instance
local currentOverheads: { [Player]: Instance } = {}
local cachedStats: { [Player]: { Wins: number, Streak: number } } = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}
local vipConnections: { [Player]: RBXScriptConnection } = {}

local function setText(root: Instance, name: string, value: string)
	local object = root:FindFirstChild(name, true)
	if object and (object:IsA("TextLabel") or object:IsA("TextButton")) then
		object.Text = value
	else
		warn(`[ColorGame] {root:GetFullName()} is missing text object {name}`)
	end
end

local function render(player: Player)
	local overhead = currentOverheads[player]
	if not overhead or not overhead.Parent then
		return
	end
	local stats = cachedStats[player]
	local wins = if stats then stats.Wins else 0
	local streak = if stats then stats.Streak else 0
	local billboard = if overhead:IsA("BillboardGui")
		then overhead
		else overhead:FindFirstChildWhichIsA("BillboardGui", true)
	if not billboard then
		return
	end
	local frames = billboard:FindFirstChild("Frames")
	local winFrame = frames and frames:FindFirstChild("WinFrame")
	local streakFrame = frames and frames:FindFirstChild("StreakFrame")
	local vipFrame = billboard:FindFirstChild("VIP")

	setText(billboard, "NameLabel", player.DisplayName)
	if winFrame then
		setText(winFrame, "Win", tostring(wins))
	else
		warn(`[ColorGame] {billboard:GetFullName()} is missing Frames.WinFrame`)
	end
	if streakFrame then
		setText(streakFrame, "Streak", tostring(streak))
	end
	if streakFrame and streakFrame:IsA("GuiObject") then
		streakFrame.Visible = streak > 0
	else
		warn(`[ColorGame] {billboard:GetFullName()} is missing GuiObject Frames.StreakFrame`)
	end
	if vipFrame and vipFrame:IsA("GuiObject") then
		vipFrame.Visible = player:GetAttribute("IsVIP") == true
	else
		warn(`[ColorGame] {billboard:GetFullName()} is missing GuiObject VIP`)
	end
end

local function attach(player: Player, character: Model)
	local head = character:WaitForChild("Head", 10)
	if not head or not head:IsA("BasePart") or character ~= player.Character then
		return
	end

	local previous = currentOverheads[player]
	if previous then
		previous:Destroy()
	end
	local existing = head:FindFirstChild(TEMPLATE_NAME)
	if existing then
		existing:Destroy()
	end

	local overhead = template:Clone()
	overhead.Name = TEMPLATE_NAME
	overhead.Parent = head
	local billboardInstance = if overhead:IsA("BillboardGui")
		then overhead
		else overhead:FindFirstChildWhichIsA("BillboardGui", true)
	if billboardInstance and billboardInstance:IsA("BillboardGui") then
		local billboard = billboardInstance :: BillboardGui
		billboard.Enabled = true
	else
		overhead:Destroy()
		warn(`[ColorGame] ReplicatedStorage.Assets.UI.{TEMPLATE_NAME} has no BillboardGui`)
		return
	end
	currentOverheads[player] = overhead
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	local wins, streak = dataManager.GetStats(player)
	if wins ~= nil and streak ~= nil then
		cachedStats[player] = { Wins = wins, Streak = streak }
	end
	render(player)
end

local function trackPlayer(player: Player)
	characterConnections[player] = player.CharacterAdded:Connect(function(character)
		task.spawn(attach, player, character)
	end)
	vipConnections[player] = player:GetAttributeChangedSignal("IsVIP"):Connect(function()
		render(player)
	end)
	if player.Character then
		task.spawn(attach, player, player.Character)
	end
end

function OverheadService.Init(playerDataManager)
	dataManager = playerDataManager
	template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("UI"):WaitForChild(TEMPLATE_NAME)

	dataManager.StatsChanged:Connect(function(player: Player, wins: number, streak: number)
		cachedStats[player] = {
			Wins = math.max(0, math.floor(wins)),
			Streak = math.max(0, math.floor(streak)),
		}
		render(player)
	end)

	Players.PlayerAdded:Connect(trackPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local connection = characterConnections[player]
		if connection then
			connection:Disconnect()
		end
		characterConnections[player] = nil
		local vipConnection = vipConnections[player]
		if vipConnection then
			vipConnection:Disconnect()
		end
		vipConnections[player] = nil
		cachedStats[player] = nil
		currentOverheads[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		trackPlayer(player)
	end
end

return OverheadService
