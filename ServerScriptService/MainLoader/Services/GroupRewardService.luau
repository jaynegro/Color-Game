--!strict

local Players = game:GetService("Players")

local GroupRewardService = {}

local VERIFY_WINDOW = 45
local VERIFY_COOLDOWN = 1

local network: any
local inventoryService: any
local groupId = 0
local rewardCategory = "Chair"
local rewardItemId = "Jelly_Candy"
local eligibleUntil: { [Player]: number } = {}
local lastVerifyAt: { [Player]: number } = {}

local function followPath(root: Instance, path: { string }): Instance
	local current = root
	for _, name in path do
		current = current:WaitForChild(name)
	end
	return current
end

local function verifyAndGrant(player: Player)
	local now = os.clock()
	if now > (eligibleUntil[player] or 0) or now - (lastVerifyAt[player] or 0) < VERIFY_COOLDOWN then
		return
	end
	lastVerifyAt[player] = now

	local checked, isMember = pcall(player.IsInGroupAsync, player, groupId)
	if not checked then
		warn(`[ColorGame] Group membership check failed for {player.Name}: {isMember}`)
		network.FireClient(player, "Notice", "Could not verify your group membership. Please try again.")
		return
	end
	if isMember ~= true then
		network.FireClient(player, "Notice", "Join the group first, then try claiming again.")
		return
	end

	local granted, message = inventoryService.GrantPermanentItem(player, rewardCategory, rewardItemId)
	if not granted then
		network.FireClient(player, "Notice", message)
		return
	end
	eligibleUntil[player] = nil
	if message == "Already owned" then
		network.FireClient(player, "Notify", `You already own {rewardItemId}.`, "Success")
	else
		network.FireClient(player, "Notify", `{rewardItemId} permanently claimed!`, "Success")
	end
end

function GroupRewardService.Init(config: any, networkService: any, playerInventoryService: any)
	network = networkService
	inventoryService = playerInventoryService
	local rewardConfig = config.GroupReward
	assert(type(rewardConfig) == "table", "[ColorGame] Config.GroupReward is missing")
	groupId = math.floor(tonumber(rewardConfig.GroupId) or 0)
	rewardCategory = tostring(rewardConfig.Category or "Chair")
	rewardItemId = tostring(rewardConfig.ItemId or "Jelly_Candy")
	assert(groupId > 0, "[ColorGame] Config.GroupReward.GroupId must be positive")
	assert(type(rewardConfig.PromptPath) == "table", "[ColorGame] Config.GroupReward.PromptPath is missing")

	local prompt = followPath(workspace, rewardConfig.PromptPath)
	assert(prompt:IsA("ProximityPrompt"), "[ColorGame] Group reward path must point to a ProximityPrompt")
	prompt.Triggered:Connect(function(player: Player)
		eligibleUntil[player] = os.clock() + VERIFY_WINDOW
		network.FireClient(player, "GroupClaimPrompt", groupId)
	end)

	local remote = network.Event :: RemoteEvent
	remote.OnServerEvent:Connect(function(player, action)
		if action == "VerifyGroupClaim" then
			task.spawn(verifyAndGrant, player)
		elseif action == "GroupClaimPending" and os.clock() <= (eligibleUntil[player] or 0) then
			network.FireClient(player, "Notice", "Your group join request is still pending.")
		elseif action == "GroupClaimPromptFailed" and os.clock() <= (eligibleUntil[player] or 0) then
			network.FireClient(player, "Notice", "The group join prompt could not open.")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		eligibleUntil[player] = nil
		lastVerifyAt[player] = nil
	end)
end

return GroupRewardService
