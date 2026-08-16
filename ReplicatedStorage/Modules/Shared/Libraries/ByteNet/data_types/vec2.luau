local channel_state = require("../process/channel_state")
local types = require("../types")

local vec2 = {
	read = function(b: buffer, cursor: number)
		return Vector2.new(buffer.readf32(b, cursor), buffer.readf32(b, cursor + 4)), 8
	end,

	write = function(value: Vector2)
		buffer.writef32(channel_state.buff, channel_state.cursor, value.X)
		buffer.writef32(channel_state.buff, channel_state.cursor + 4, value.Y)
		channel_state.cursor += 8
	end,
}

return function(): types.DataType<Vector2>
	return vec2
end
