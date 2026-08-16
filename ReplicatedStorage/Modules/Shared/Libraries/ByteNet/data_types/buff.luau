local channel_state = require("../process/channel_state")
local types = require("../types")

local buff = {
	read = function(b: buffer, cursor: number)
		local length = buffer.readu16(b, cursor)
		local freshBuffer = buffer.create(length)
		buffer.copy(freshBuffer, 0, b, cursor + 2, length)
		return freshBuffer, length + 2
	end,

	write = function(data: buffer)
		local length = buffer.len(data)
		buffer.writeu16(channel_state.buff, channel_state.cursor, length)
		channel_state.cursor += 2
		buffer.copy(channel_state.buff, channel_state.cursor, data, 0, length)
		channel_state.cursor += length
	end,
}

return function(): types.DataType<buffer>
	return buff
end
