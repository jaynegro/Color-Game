local channel_state = require("../process/channel_state")
local types = require("../types")

local float64: types.DataType<number> = {
	__T = ... :: number,

	write = function(value: number)
		buffer.writef64(channel_state.buff, channel_state.cursor, value)
		channel_state.cursor += 8
	end,

	read = function(b: buffer, cursor: number)
		return buffer.readf64(b, cursor), 8
	end,
}

return function(): types.DataType<number>
	return float64
end
