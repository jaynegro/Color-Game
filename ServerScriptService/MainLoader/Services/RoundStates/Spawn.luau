--!strict

local Spawn = {}

function Spawn.Run(context)
	context.DiceService.Clear()
	context.PusherService.Reset()
	context.DiceService.Spawn(
		context.Config.DiceSpawnAnchorDuration,
		context.Config.DiceSpawnClearance
	)
end

return Spawn
