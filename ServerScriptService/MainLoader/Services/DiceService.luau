--!strict

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

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
local spawnTransitionDuration = 0.35
local despawnTransitionDuration = 0.35
local transitionMinScale = 0.12

type DiceTransition = {
	Model: Model,
	DefaultScale: number,
	Transparency: { [Instance]: number },
}

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

local function captureTransparency(model: Model): { [Instance]: number }
	local transparency: { [Instance]: number } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") or descendant:IsA("Texture") then
			transparency[descendant] = descendant.Transparency
		end
	end
	return transparency
end

local function setTransitionTransparency(values: { [Instance]: number }, alpha: number, fadeIn: boolean)
	for instance, original in values do
		if instance.Parent then
			local transparency = if fadeIn
				then 1 + (original - 1) * alpha
				else original + (1 - original) * alpha
			local visual = instance :: any
			visual.Transparency = transparency
		end
	end
end

local function animateDiceTransition(transitions: { DiceTransition }, duration: number, fadeIn: boolean)
	if #transitions == 0 then
		return
	end
	duration = math.max(0, duration)
	local startedAt = os.clock()
	repeat
		local alpha = if duration == 0 then 1 else math.clamp((os.clock() - startedAt) / duration, 0, 1)
		local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		for _, transition in transitions do
			if transition.Model.Parent then
				local scaleAlpha = if fadeIn
					then transitionMinScale + (1 - transitionMinScale) * eased
					else 1 + (transitionMinScale - 1) * eased
				transition.Model:ScaleTo(transition.DefaultScale * scaleAlpha)
				setTransitionTransparency(transition.Transparency, eased, fadeIn)
			end
		end
		if alpha >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	until false
end

local function freezeForDespawn(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
			if descendant.Name == "BodyMesh" then
				descendant.Anchored = true
			end
		end
	end
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
	spawnTransitionDuration = math.max(0, tonumber(config.DiceSpawnTransitionDuration) or 0.35)
	despawnTransitionDuration = math.max(0, tonumber(config.DiceDespawnTransitionDuration) or 0.35)
	transitionMinScale = math.clamp(tonumber(config.DiceTransitionMinScale) or 0.12, 0.01, 1)
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
	local oldDice = activeDice
	activeDice = {}
	DiceImpactService.SetActive(oldDice, false)
	local transitions: { DiceTransition } = {}
	for _, die in oldDice do
		if die.Parent then
			freezeForDespawn(die)
			table.insert(transitions, {
				Model = die,
				DefaultScale = die:GetScale(),
				Transparency = captureTransparency(die),
			})
		end
	end
	animateDiceTransition(transitions, despawnTransitionDuration, false)
	for _, die in oldDice do
		if die.Parent then
			die:Destroy()
		end
	end
end

function DiceService.Spawn(anchorDuration: number?, clearance: number?): { Model }
	DiceService.Clear()
	local transitions: { DiceTransition } = {}
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
		local transition = {
			Model = die,
			DefaultScale = die:GetScale(),
			Transparency = captureTransparency(die),
		}
		die:ScaleTo(transition.DefaultScale * transitionMinScale)
		setTransitionTransparency(transition.Transparency, 0, true)
		table.insert(transitions, transition)
		DiceImpactService.Attach(die)
		table.insert(activeDice, die)
	end

	local anchoredFor = math.max(0, anchorDuration or 1)
	local transitionStartedAt = os.clock()
	animateDiceTransition(transitions, spawnTransitionDuration, true)
	local remainingAnchorTime = anchoredFor - (os.clock() - transitionStartedAt)
	if remainingAnchorTime > 0 then
		task.wait(remainingAnchorTime)
	end
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
