local channel_state = require("../process/channel_state")
local types = require("../types")

local float32: types.DataType<number> = {
	__T = ... :: number,

	write = function(value: number)
		buffer.writef32(channel_state.buff, channel_state.cursor, value)
		channel_state.cursor += 4
	end,

	read = function(b: buffer, cursor: number)
		return buffer.readf32(b, cursor), 4
	end,
}

return function(): types.DataType<number>
	return float32
end
