--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local RagdollTriggerService = {}

local releaseAt: { [Model]: number } = {}
local warnedCharacters: { [Model]: boolean } = {}

local function getPlayerCharacter(part: BasePart): (Player?, Model?)
	local current: Instance? = part
	while current and current ~= workspace do
		if current:IsA("Model") then
			local player = Players:GetPlayerFromCharacter(current)
			if player then
				return player, current
			end
		end
		current = current.Parent
	end
	return nil, nil
end

local function ragdollCharacter(character: Model, duration: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local currentState = character:GetAttribute("Ragdoll")
	if type(currentState) ~= "boolean" then
		if not warnedCharacters[character] then
			warn(`[ColorGame] {character:GetFullName()} has no Ragdoll attribute; check StarterCharacterScripts.Ragdoll`)
			warnedCharacters[character] = true
		end
		return
	end

	-- Do not cancel a ragdoll that another system already owns.
	if currentState and releaseAt[character] == nil then
		return
	end

	local deadline = os.clock() + duration
	releaseAt[character] = deadline
	if not currentState then
		character:SetAttribute("Ragdoll", true)
	end

	task.delay(duration, function()
		if releaseAt[character] ~= deadline or os.clock() < deadline then
			return
		end
		releaseAt[character] = nil
		if character.Parent and humanoid.Health > 0 and character:GetAttribute("Ragdoll") == true then
			character:SetAttribute("Ragdoll", false)
		end
	end)
end

function RagdollTriggerService.Trigger(duration: number): number
	local affectedCharacters: { [Model]: boolean } = {}
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.RespectCanCollide = false

	for _, tagged in CollectionService:GetTagged("RagdollTrigger") do
		if not tagged:IsA("BasePart") or not tagged:IsDescendantOf(workspace) then
			continue
		end
		for _, touchingPart in workspace:GetPartsInPart(tagged, overlap) do
			local _, character = getPlayerCharacter(touchingPart)
			if character then
				affectedCharacters[character] = true
			end
		end
	end

	local count = 0
	for character in affectedCharacters do
		count += 1
		ragdollCharacter(character, math.max(0.1, duration))
	end
	return count
end

Players.PlayerRemoving:Connect(function(player)
	local character = player.Character
	if character then
		releaseAt[character] = nil
		warnedCharacters[character] = nil
	end
end)

return RagdollTriggerService
