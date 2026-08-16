local channel_state = require("../process/channel_state")
local types = require("../types")

local color3: types.DataType<Color3> = {
	__T = ... :: Color3,

	write = function(input: Color3)
		buffer.writef32(channel_state.buff, channel_state.cursor, input.R)
		buffer.writef32(channel_state.buff, channel_state.cursor + 4, input.G)
		buffer.writef32(channel_state.buff, channel_state.cursor + 8, input.B)
		channel_state.cursor += 12
	end,

	read = function(b: buffer, cursor: number)
		return Color3.new(
			buffer.readf32(b, cursor),
			buffer.readf32(b, cursor + 4),
			buffer.readf32(b, cursor + 8)
		), 12
	end,

	length = 12,
}

return function(): types.DataType<Color3>
	return color3
end
