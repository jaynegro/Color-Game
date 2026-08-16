--!strict

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local DiceImpactService = {}

type DiceState = {
	Active: boolean,
	LastPlayedAt: number,
	Contacts: { [BasePart]: boolean },
	Connections: { RBXScriptConnection },
}

local soundSources: { Sound } = {}
local states: { [Model]: DiceState } = {}
local cooldown = 0.2
local randomizer = Random.new()

local function playImpact(body: BasePart)
	if #soundSources == 0 then
		return
	end
	local sound = soundSources[randomizer:NextInteger(1, #soundSources)]:Clone()
	sound.Parent = body
	sound:Play()
	Debris:AddItem(sound, math.max(sound.TimeLength + 1, 5))
end

local function cleanup(die: Model)
	local state = states[die]
	if not state then
		return
	end
	states[die] = nil
	for _, connection in state.Connections do
		connection:Disconnect()
	end
	table.clear(state.Contacts)
end

function DiceImpactService.Init(config)
	cooldown = config.DiceImpactCooldown
	local sfx = SoundService:WaitForChild("SFX")
	for _, child in sfx:GetChildren() do
		if child:IsA("Sound") and child.Name == "DiceImpact" then
			table.insert(soundSources, child)
		end
	end
	if #soundSources == 0 then
		warn("[ColorGame] SoundService.SFX has no DiceImpact sounds")
	end
end

function DiceImpactService.Attach(die: Model)
	cleanup(die)
	local body = die:FindFirstChild("BodyMesh", true)
	assert(body and body:IsA("BasePart"), "[ColorGame] DiceImpact requires BasicDice.BodyMesh")
	body.CanTouch = true

	local state: DiceState = {
		Active = false,
		LastPlayedAt = -math.huge,
		Contacts = {},
		Connections = {},
	}
	states[die] = state

	table.insert(state.Connections, body.Touched:Connect(function(otherPart)
		if not state.Active or not otherPart:IsA("BasePart")
			or not CollectionService:HasTag(otherPart, "WoodSurface")
			or state.Contacts[otherPart] then
			return
		end
		state.Contacts[otherPart] = true
		local now = os.clock()
		if now - state.LastPlayedAt >= cooldown then
			state.LastPlayedAt = now
			playImpact(body)
		end
	end))
	table.insert(state.Connections, body.TouchEnded:Connect(function(otherPart)
		state.Contacts[otherPart] = nil
	end))
	table.insert(state.Connections, die.Destroying:Connect(function()
		cleanup(die)
	end))
end

function DiceImpactService.SetActive(dice: { Model }, active: boolean)
	for _, die in dice do
		local state = states[die]
		if state then
			state.Active = active
			if not active then
				table.clear(state.Contacts)
			end
		end
	end
end

return DiceImpactService
