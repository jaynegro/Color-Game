local channel_state = require("../process/channel_state")
local types = require("../types")

local vec3: types.DataType<Vector3> = {
	__T = ... :: Vector3,

	read = function(b: buffer, cursor: number)
		return Vector3.new(
			buffer.readf32(b, cursor),
			buffer.readf32(b, cursor + 4),
			buffer.readf32(b, cursor + 8)
		), 12
	end,

	write = function(value: Vector3)
		buffer.writef32(channel_state.buff, channel_state.cursor, value.X)
		buffer.writef32(channel_state.buff, channel_state.cursor + 4, value.Y)
		buffer.writef32(channel_state.buff, channel_state.cursor + 8, value.Z)
		channel_state.cursor += 12
	end,

	length = 12,
}

return function(): types.DataType<Vector3>
	return vec3
end
