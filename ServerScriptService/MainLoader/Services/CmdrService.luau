--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminConfig = require(ReplicatedStorage.Modules.Shared.Config.AdminConfig)
local Cmdr = require(ReplicatedStorage.Modules.Shared.Libraries.Cmdr.Cmdr)

local CmdrService = {}

function CmdrService.Init(commandsFolder: Instance)
	Cmdr:RegisterCommandsIn(commandsFolder)
	Cmdr.Registry:RegisterHook("BeforeRun", function(context: any)
		local executor = context.Executor
		if not executor or not AdminConfig.IsAdmin(executor.UserId) then
			return "You are not authorized to use Color Game admin commands."
		end
		return nil
	end)
end

return CmdrService
