--!strict

local ActivateMachine = {}

function ActivateMachine.Run(context)
	context.Network.FireAll("PlaySFX", "ActivationStart")
	context.Network.FireAll("NpcAnimation", "Smash")
	task.wait(context.Config.SmashActivationDelay)
	context.Network.FireAll("PlaySFX", "ActivationHit")
	context.RagdollTriggerService.Trigger(context.Config.SmashRagdollDuration)
end

return ActivateMachine
