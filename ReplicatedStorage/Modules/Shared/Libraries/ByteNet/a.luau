local packetsById: { [number]: any } = {}
local nextPacketId = 0

local registry = {}

function registry.allocateId(): number
	local id = nextPacketId
	nextPacketId += 1
	return id
end

function registry.register(id: number, packet: any)
	packetsById[id] = packet
end

function registry.ref()
	return packetsById
end

return registry
