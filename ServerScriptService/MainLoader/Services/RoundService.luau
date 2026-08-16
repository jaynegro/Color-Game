--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationUtil = require(script.Parent.AnimationUtil)
local ActivateMachine = require(script.Parent.RoundStates.ActivateMachine)
local Picking = require(script.Parent.RoundStates.Picking)
local Results = require(script.Parent.RoundStates.Results)
local Roll = require(script.Parent.RoundStates.Roll)
local Settle = require(script.Parent.RoundStates.Settle)
local Spawn = require(script.Parent.RoundStates.Spawn)
local Validate = require(script.Parent.RoundStates.Validate)

local RoundService = {}

local context: any
local stateFolder: Folder
local running = false

local function followPath(root: Instance, path: { string }): Instance
	local current = root
	for _, name in path do
		current = current:WaitForChild(name)
	end
	return current
end

local function setState(name: string, duration: number?)
	local endsAt = if duration then workspace:GetServerTimeNow() + duration else 0
	stateFolder:SetAttribute("State", name)
	stateFolder:SetAttribute("RoundId", context.RoundId)
	stateFolder:SetAttribute("EndsAt", endsAt)
	context.RoundDisplayService.SetMachineState(name, endsAt)
	context.Network.FireAll("State", name, context.RoundId, endsAt)
end

local function runRound()
	context.RoundId += 1

	setState("Spawning")
	Spawn.Run(context)

	setState("Picking", context.Config.PickingDuration)
	Picking.Run(context)

	setState("Activating")
	ActivateMachine.Run(context)

	setState("Rolling")
	Roll.Run(context)

	setState("Settling", context.Config.SettlingDuration)
	Settle.Run(context)

	setState("Validating")
	local results = Validate.Run(context)

	setState("Results", context.Config.ResultDuration)
	Results.Run(context, results)
end

function RoundService.Init(config, network, diceService, tableService, roundDisplayService, pusherService, ragdollTriggerService)
	local machine = followPath(workspace, config.MachinePath)
	local animations = followPath(ReplicatedStorage, config.AnimationsPath)

	stateFolder = ReplicatedStorage:FindFirstChild("ColorGameState") :: Folder
	if not stateFolder then
		stateFolder = Instance.new("Folder")
		stateFolder.Name = "ColorGameState"
		stateFolder.Parent = ReplicatedStorage
	end

	context = {
		Config = config,
		Network = network,
		DiceService = diceService,
		TableService = tableService,
		RoundDisplayService = roundDisplayService,
		PusherService = pusherService,
		RagdollTriggerService = ragdollTriggerService,
		AnimationUtil = AnimationUtil,
		NpcActivator = machine:WaitForChild("NpcActivator"),
		RollerModel = machine:WaitForChild("RollerModel"),
		SmashAnimation = animations:WaitForChild("Smash") :: Animation,
		RollAnimation = animations:WaitForChild("Roll") :: Animation,
		RoundId = 0,
	}
end

function RoundService.Start()
	if running then
		return
	end
	running = true
	task.spawn(function()
		while running do
			local ok, message = xpcall(runRound, debug.traceback)
			if not ok then
				warn(`[ColorGame] Round failed:\n{message}`)
				context.DiceService.SetImpactSoundsActive(false)
				context.TableService.SetPickingOpen(false, context.RoundId)
				setState("Recovering", 2)
				task.wait(2)
			end
		end
	end)
end

return RoundService
