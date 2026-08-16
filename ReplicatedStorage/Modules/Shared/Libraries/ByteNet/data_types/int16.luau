local channel_state = require("../process/channel_state")
local types = require("../types")

local int16 = {
	write = function(value: number)
		buffer.writei16(channel_state.buff, channel_state.cursor, value)
		channel_state.cursor += 2
	end,

	read = function(b: buffer, cursor: number)
		return buffer.readi16(b, cursor), 2
	end,
}

return function(): types.DataType<number>
	return int16
end
