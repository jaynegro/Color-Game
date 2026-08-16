--!strict

local Roll = {}

function Roll.Run(context)
	context.DiceService.SetImpactSoundsActive(true)
	local track = context.AnimationUtil.Play(
		context.RollerModel,
		context.RollAnimation,
		false,
		Enum.AnimationPriority.Action
	)
	task.wait(context.Config.PusherDelay)
	context.PusherService.Push()
	context.AnimationUtil.WaitForStop(track, context.Config.AnimationTimeout)
end

return Roll
