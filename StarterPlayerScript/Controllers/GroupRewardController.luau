--!strict

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)

local GroupRewardController = {}

local busy = false

function GroupRewardController.Init()
	local player = Players.LocalPlayer
	local remote = Remote.New("ColorGameEvent")
	remote.OnClientEvent:Connect(function(action: string, requestedGroupId: any)
		if action ~= "GroupClaimPrompt" or busy or type(requestedGroupId) ~= "number" then
			return
		end
		busy = true
		task.spawn(function()
			local checked, alreadyMember = pcall(player.IsInGroupAsync, player, requestedGroupId)
			if checked and alreadyMember == true then
				remote:FireServer("VerifyGroupClaim")
				busy = false
				return
			end

			local prompted, status = pcall(GroupService.PromptJoinAsync, GroupService, requestedGroupId)
			if prompted and (status == Enum.GroupMembershipStatus.Joined
				or status == Enum.GroupMembershipStatus.AlreadyMember) then
				remote:FireServer("VerifyGroupClaim")
			elseif prompted and status == Enum.GroupMembershipStatus.JoinRequestPending then
				remote:FireServer("GroupClaimPending")
			elseif not prompted then
				warn(`[ColorGame] Group join prompt failed: {status}`)
				remote:FireServer("GroupClaimPromptFailed")
			end
			busy = false
		end)
	end)
end

return GroupRewardController
