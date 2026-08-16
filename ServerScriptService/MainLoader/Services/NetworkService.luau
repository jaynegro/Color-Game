--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)

local NetworkService = {
	Event = nil :: RemoteEvent?,
}

function NetworkService.Init()
	if NetworkService.Event then
		return
	end

	NetworkService.Event = Remote.New("ColorGameEvent") :: any
end

function NetworkService.FireClient(player: Player, action: string, ...: any)
	local event = NetworkService.Event
	assert(event, "NetworkService is not initialized")
	event:FireClient(player, action, ...)
end

function NetworkService.FireAll(action: string, ...: any)
	local event = NetworkService.Event
	assert(event, "NetworkService is not initialized")
	event:FireAllClients(action, ...)
end

return NetworkService
