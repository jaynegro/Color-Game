--!strict

local Settle = {}

function Settle.Run(context)
	task.wait(context.Config.SettlingDuration)
end

return Settle
