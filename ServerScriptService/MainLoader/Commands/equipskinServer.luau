--!strict

local InventoryService = require(script.Parent.Parent.Services.InventoryService)

return function(context: any, category: string, skin: string): string
	local equipped, message = InventoryService.SetAdminEquipOverride(context.Executor, category, skin)
	return if equipped then message else `Error: {message}`
end
