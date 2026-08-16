--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicaClient = require(ReplicatedStorage.Modules.Client.ReplicaClient)

local HUDController = {}

local function setAmount(container: Instance, value: number)
	local amount = container:FindFirstChild("Amount", true)
	if not amount or not (amount:IsA("TextLabel") or amount:IsA("TextButton")) then
		return
	end
	amount.Text = tostring(value)
	local shadow = amount:FindFirstChild("Amount2")
	if shadow and (shadow:IsA("TextLabel") or shadow:IsA("TextButton")) then
		shadow.Text = amount.Text
	end
end

function HUDController.Init()
	local player = Players.LocalPlayer
	local hud = player:WaitForChild("PlayerGui"):WaitForChild("HUD")
	local top = hud:WaitForChild("Top")
	local winContainer = top:WaitForChild("WinContainer")
	local streakContainer = top:WaitForChild("StreakContainer")

	ReplicaClient.OnNew("PlayerData", function(replica)
		if replica.Tags.UserId ~= player.UserId then
			return
		end
		local function render()
			setAmount(winContainer, replica.Data.Wins or 0)
			setAmount(streakContainer, replica.Data.Streak or 0)
		end
		render()
		replica:OnChange(render)
	end)
	ReplicaClient.RequestData()
end

return HUDController
