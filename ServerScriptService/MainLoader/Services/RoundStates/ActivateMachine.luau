--!strict

local ActivateMachine = {}

function ActivateMachine.Run(context)
	context.Network.FireAll("PlaySFX", "ActivationStart")
	local track = context.AnimationUtil.Play(
		context.NpcActivator,
		context.SmashAnimation,
		false,
		Enum.AnimationPriority.Action2
	)
	local reachedMarker = context.AnimationUtil.WaitForMarkerOrStop(
		track,
		"MachineActivated",
		context.Config.AnimationTimeout
	)
	if reachedMarker then
		context.Network.FireAll("PlaySFX", "ActivationHit")
		context.RagdollTriggerService.Trigger(context.Config.SmashRagdollDuration)
	end
	if not reachedMarker then
		warn("[ColorGame] Smash animation ended without the MachineActivated marker; continuing the round")
	end
end

return ActivateMachine
