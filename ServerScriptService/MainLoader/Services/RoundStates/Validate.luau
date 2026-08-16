--!strict

local Validate = {}

function Validate.Run(context): { string }
	context.DiceService.SetImpactSoundsActive(false)
	return context.DiceService.Validate()
end

return Validate
