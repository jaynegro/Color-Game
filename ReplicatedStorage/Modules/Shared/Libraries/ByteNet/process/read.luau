local packetIDs = require("../a")
local readRefs = require("./readRefs")

local ref = packetIDs.ref()

local function run_listener(fn, ...)
	task.spawn(fn, ...)
end

local function read(incoming_buff: buffer, references: { [number]: unknown }?, player: Player?)
	local length = buffer.len(incoming_buff)
	local read_cursor = 0

	readRefs.set(references)

	while read_cursor < length do
		local packet = ref[buffer.readu8(incoming_buff, read_cursor)]
		if not packet then
			return
		end
		read_cursor += 1

		local value, value_len = packet.reader(incoming_buff, read_cursor)

		read_cursor += value_len

		for _, listener in packet.getListeners() do
			run_listener(listener, value, player)
		end
	end
end

return read
