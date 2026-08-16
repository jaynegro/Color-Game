--!strict

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DiceImpactService = require(script.Parent.DiceImpactService)

local DiceService = {}

local ROUND_DICE_GROUP = "RoundDice"
local MACHINE_PUSHER_GROUP = "MachinePusher"
local activeDice: { Model } = {}
local diceAsset: Model
local spawners: { BasePart } = {}
local validator: BasePart
local availableColors: { string } = {}
local randomizer = Random.new()

local function followPath(root: Instance, path: { string }): Instance
	local current = root
	for _, name in path do
		current = current:WaitForChild(name)
	end
	return current
end

local function colorFromHitbox(part: BasePart): string?
	local color = string.match(part.Name, "^(.+)HB$")
	if color and color ~= "" then
		return color
	end
	return nil
end

local function prepareDice(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = ROUND_DICE_GROUP
			descendant.CanQuery = true
			descendant.CanTouch = descendant.Name == "BodyMesh"
			-- Anchor only the physical root. Anchoring every welded hitbox can
			-- split and rebuild the assembly, causing an explosive release.
			descendant.Anchored = descendant.Name == "BodyMesh"
			if colorFromHitbox(descendant) then
				-- Face hitboxes are only used by the result overlap query.
				descendant.CanCollide = false
				descendant.Massless = true
			elseif descendant.Name == "BodyMesh" then
				descendant.CanCollide = true
			end
		end
	end

end

local function releaseDice(model: Model)
	local body = model:FindFirstChild("BodyMesh", true)
	assert(body and body:IsA("BasePart"), "[ColorGame] BasicDice is missing its BodyMesh BasePart")

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= body then
			descendant.Anchored = false
		end
	end
	body.AssemblyLinearVelocity = Vector3.zero
	body.AssemblyAngularVelocity = Vector3.zero
	body.Anchored = false

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.AssemblyRootPart == descendant then
			local canSet = descendant:CanSetNetworkOwnership()
			if canSet then
				descendant:SetNetworkOwner(nil)
			end
		end
	end
end

local function placeOnSpawner(die: Model, spawner: BasePart, rotation: CFrame, clearance: number)
	-- Apply rotation first so the final bottom-face height can be measured accurately.
	die:PivotTo(spawner.CFrame * rotation)

	local body = die:FindFirstChild("BodyMesh", true)
	assert(body and body:IsA("BasePart"), "[ColorGame] BasicDice is missing its BodyMesh BasePart")

	local up = spawner.CFrame.UpVector
	local halfSize = body.Size * 0.5
	local lowestProjection = math.huge
	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				local corner = body.CFrame:PointToWorldSpace(Vector3.new(
					halfSize.X * x,
					halfSize.Y * y,
					halfSize.Z * z
				))
				lowestProjection = math.min(lowestProjection, corner:Dot(up))
			end
		end
	end

	local spawnerTop = spawner.Position + up * (spawner.Size.Y * 0.5)
	local liftDistance = spawnerTop:Dot(up) - lowestProjection + clearance
	die:PivotTo(die:GetPivot() + up * liftDistance)
end

local function preparePusher(machine: Instance)
	local rollerModel = machine:WaitForChild("RollerModel")
	local oldPusher = rollerModel:FindFirstChild("Pusher")
	if oldPusher and oldPusher:IsA("BasePart") then
		oldPusher.CanCollide = false
	end

	local pusher = machine:WaitForChild("PusherPart")
	assert(pusher:IsA("BasePart"), "[ColorGame] Machine.PusherPart must be a BasePart")

	pusher.CollisionGroup = MACHINE_PUSHER_GROUP
	pusher.CanCollide = true
	pusher.CanQuery = true
	pusher.CanTouch = false
	pusher.Massless = false
	pusher.Anchored = false
	local canSetOwnership = pusher:CanSetNetworkOwnership()
	if canSetOwnership then
		pusher:SetNetworkOwner(nil)
	end
end

function DiceService.Init(config)
	DiceImpactService.Init(config)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(ROUND_DICE_GROUP)
	end)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(MACHINE_PUSHER_GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(ROUND_DICE_GROUP, ROUND_DICE_GROUP, true)
	PhysicsService:CollisionGroupSetCollidable(ROUND_DICE_GROUP, MACHINE_PUSHER_GROUP, true)
	PhysicsService:CollisionGroupSetCollidable(ROUND_DICE_GROUP, "Default", true)

	diceAsset = followPath(ReplicatedStorage, config.DiceAssetPath) :: Model
	local seenColors: { [string]: boolean } = {}
	for _, descendant in diceAsset:GetDescendants() do
		if descendant:IsA("BasePart") then
			local color = colorFromHitbox(descendant)
			if color and not seenColors[color] then
				seenColors[color] = true
				table.insert(availableColors, color)
			end
		end
	end
	table.sort(availableColors)
	assert(#availableColors > 0, "[ColorGame] BasicDice needs BaseParts named <Color>HB")
	for _, expectedColor in config.Colors do
		if not seenColors[expectedColor] then
			warn(`[ColorGame] BasicDice has no {expectedColor}HB; that GameBoard color will stay disabled`)
		end
	end
	local machine = followPath(workspace, config.MachinePath)
	preparePusher(machine)
	validator = machine:WaitForChild("ResultValidatorPart") :: BasePart

	local platform = machine:WaitForChild("DicePlatform")
	for _, child in platform:GetChildren() do
		if child.Name == "DiceSpawner" and child:IsA("BasePart") then
			table.insert(spawners, child)
		end
	end
	table.sort(spawners, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)

	assert(#spawners == 3, `[ColorGame] Expected 3 DiceSpawner parts, found {#spawners}`)
end

function DiceService.Clear()
	for _, die in activeDice do
		if die.Parent then
			die:Destroy()
		end
	end
	table.clear(activeDice)
end

function DiceService.Spawn(anchorDuration: number?, clearance: number?): { Model }
	DiceService.Clear()
	for index, spawner in spawners do
		local die = diceAsset:Clone()
		die.Name = `RoundDice{index}`
		die.Parent = workspace
		local quarterTurn = math.pi / 2
		local randomRotation = CFrame.Angles(
			randomizer:NextInteger(0, 3) * quarterTurn,
			randomizer:NextInteger(0, 3) * quarterTurn,
			randomizer:NextInteger(0, 3) * quarterTurn
		)
		placeOnSpawner(die, spawner, randomRotation, clearance or 0.03)
		prepareDice(die)
		DiceImpactService.Attach(die)
		table.insert(activeDice, die)
	end

	task.wait(anchorDuration or 1)
	for _, die in activeDice do
		if die.Parent then
			releaseDice(die)
		end
	end
	return activeDice
end

function DiceService.SetImpactSoundsActive(active: boolean)
	DiceImpactService.SetActive(activeDice, active)
end

function DiceService.Validate(): { string }
	local filter = OverlapParams.new()
	filter.FilterType = Enum.RaycastFilterType.Include
	filter.FilterDescendantsInstances = activeDice
	filter.RespectCanCollide = false

	local touching = workspace:GetPartsInPart(validator, filter)
	local candidatesByDie: { [Model]: { BasePart } } = {}
	for _, part in touching do
		local color = colorFromHitbox(part)
		if color then
			for _, die in activeDice do
				if part:IsDescendantOf(die) then
					local candidates = candidatesByDie[die]
					if not candidates then
						candidates = {}
						candidatesByDie[die] = candidates
					end
					table.insert(candidates, part)
					break
				end
			end
		end
	end

	local results: { string } = {}
	for _, die in activeDice do
		local candidates = candidatesByDie[die] or {}
		if #candidates == 0 then
			-- A tiny gap can exist after physics settles; use the lowest hitbox as fallback.
			for _, descendant in die:GetDescendants() do
				if descendant:IsA("BasePart") and colorFromHitbox(descendant) then
					table.insert(candidates, descendant)
				end
			end
		end

		table.sort(candidates, function(a, b)
			return validator.CFrame:PointToObjectSpace(a.Position).Y < validator.CFrame:PointToObjectSpace(b.Position).Y
		end)
		local selected = candidates[1]
		local color = selected and colorFromHitbox(selected)
		if color then
			table.insert(results, color)
		else
			warn(`[ColorGame] Could not validate {die:GetFullName()}`)
		end
	end

	return results
end

function DiceService.GetActiveDice(): { Model }
	return activeDice
end

function DiceService.GetAvailableColors(): { string }
	return table.clone(availableColors)
end

return DiceService
