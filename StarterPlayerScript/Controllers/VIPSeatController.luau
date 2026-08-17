--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local NotificationController = require(script.Parent.NotificationController)

local VIPSeatController = {}

local player = Players.LocalPlayer
local vipSeats: { Seat } = {}
local lastNoticeAt = 0
local initialized = false

local function refreshSeats()
	local disabled = player:GetAttribute("IsVIP") ~= true
	for _, seat in vipSeats do
		if seat.Parent then
			seat.Disabled = disabled
		end
	end
end

function VIPSeatController.Init()
	if initialized then
		return
	end
	initialized = true

	local scriptableParts = workspace:WaitForChild("ScriptableParts")
	local tables = scriptableParts:WaitForChild("Tables")
	for _, tableModel in tables:GetChildren() do
		if tableModel:IsA("Model") and tableModel.Name == "Table_VIP" then
			for _, descendant in tableModel:GetDescendants() do
				if descendant:IsA("Seat") then
					table.insert(vipSeats, descendant)
				end
			end
		end
	end

	player:GetAttributeChangedSignal("IsVIP"):Connect(refreshSeats)
	refreshSeats()

	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		if player:GetAttribute("IsVIP") == true then
			return
		end
		elapsed += deltaTime
		if elapsed < 0.2 then
			return
		end
		elapsed = 0

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		for _, seat in vipSeats do
			if not seat.Parent then
				continue
			end
			local localPosition = seat.CFrame:PointToObjectSpace(root.Position)
			local closeHorizontally = math.abs(localPosition.X) <= seat.Size.X * 0.5 + 1
				and math.abs(localPosition.Z) <= seat.Size.Z * 0.5 + 1
			local closeVertically = localPosition.Y >= -1 and localPosition.Y <= 4
			if closeHorizontally and closeVertically then
				local now = os.clock()
				if now - lastNoticeAt >= 2 then
					lastNoticeAt = now
					NotificationController.Notify("VIP Game Pass required to use this table.", "Error", 2.5)
				end
				break
			end
		end
	end)
end

return VIPSeatController
