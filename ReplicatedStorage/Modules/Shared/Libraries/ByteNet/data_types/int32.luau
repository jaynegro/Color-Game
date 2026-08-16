local channel_state = require("../process/channel_state")
local types = require("../types")

local int32 = {
	write = function(value: number)
		buffer.writei32(channel_state.buff, channel_state.cursor, value)
		channel_state.cursor += 4
	end,

	read = function(b: buffer, cursor: number)
		return buffer.readi32(b, cursor), 4
	end,
}

return function(): types.DataType<number>
	return int32
end
