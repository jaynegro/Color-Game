--!strict

local Picking = {}

function Picking.Run(context)
	context.RoundDisplayService.StartNextRoundCountdown(context.Config.PickingDuration)
	context.TableService.SetPickingOpen(true, context.RoundId)
	task.wait(context.Config.PickingDuration)
	context.TableService.SetPickingOpen(false, context.RoundId)
	context.TableService.SetRoundCameraActive(true)
	context.RoundDisplayService.ShowRoundInProgress()
end

return Picking
