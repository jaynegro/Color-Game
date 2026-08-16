local channel_state = require("../process/channel_state")
local types = require("../types")

local str = {
	read = function(b: buffer, cursor: number)
		local length = buffer.readu16(b, cursor)
		return buffer.readstring(b, cursor + 2, length), length + 2
	end,

	write = function(data: string)
		local length = string.len(data)
		buffer.writeu16(channel_state.buff, channel_state.cursor, length)
		channel_state.cursor += 2
		buffer.writestring(channel_state.buff, channel_state.cursor, data)
		channel_state.cursor += length
	end,
}

return function(): types.DataType<string>
	return str
end
