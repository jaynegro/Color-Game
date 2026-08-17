--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminConfig = require(ReplicatedStorage.Modules.Shared.Config.AdminConfig)
local Icon = require(ReplicatedStorage.Modules.Shared.Libraries.TopbarPlus)

local CmdrController = {}

function CmdrController.Init()
	if not AdminConfig.IsAdmin(Players.LocalPlayer.UserId) then
		return
	end
	local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient"))
	Cmdr:SetActivationKeys({ Enum.KeyCode.F2 })
	Cmdr:SetPlaceName("Color Game Admin")
	Cmdr:SetEnabled(true)

	local adminIcon = Icon.new()
		:setName("AdminCommands")
		:setLabel("Admin")
		:setCaption("Open Admin Commands")
		:setOrder(1)
		:align("Right")

	adminIcon.selected:Connect(function()
		Cmdr:Toggle()
	end)
	adminIcon:oneClick()
end

return CmdrController
