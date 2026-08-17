--!strict

local InventoryService = require(script.Parent.Parent.Services.InventoryService)

return function(context: any, category: string): string
	local unequipped, message = InventoryService.AdminUnequip(context.Executor, category)
	return if unequipped then message else `Error: {message}`
end
