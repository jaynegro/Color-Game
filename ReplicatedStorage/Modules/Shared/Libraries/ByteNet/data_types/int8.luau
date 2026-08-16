local channel_state = require("../process/channel_state")
local types = require("../types")

local int8 = {
	write = function(value: number)
		buffer.writei8(channel_state.buff, channel_state.cursor, value)
		channel_state.cursor += 1
	end,

	read = function(b: buffer, cursor: number)
		return buffer.readi8(b, cursor), 1
	end,
}

return function(): types.DataType<number>
	return int8
end
