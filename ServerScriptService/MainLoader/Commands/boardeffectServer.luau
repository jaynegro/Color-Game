--!strict

local BoardResultEffectService = require(script.Parent.Parent.Services.BoardResultEffectService)
local TableService = require(script.Parent.Parent.Services.TableService)

return function(context: any, color: string, multiplier: number): string
	local player = context.Executor
	local board = TableService.GetPlayerBoard(player)
	if not board then
		return "Sit at a table before using this command."
	end
	local played, message = BoardResultEffectService.Play(board, color, multiplier)
	return if played then message else `Error: {message}`
end
