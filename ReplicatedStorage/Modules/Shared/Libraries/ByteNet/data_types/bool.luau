local channel_state = require("../process/channel_state")
local types = require("../types")

local bool_modifier = {
	[1] = true,
	[0] = false,
}
local bool_modifier2 = {
	[true] = 1,
	[false] = 0,
}

local bool_data_type = {
	__T = (nil :: any) :: boolean,

	read = function(b: buffer, cursor: number)
		return bool_modifier[buffer.readu8(b, cursor)], 1
	end,

	length = 1,

	write = function(value: boolean)
		buffer.writeu8(channel_state.buff, channel_state.cursor, bool_modifier2[value] or 0)
		channel_state.cursor += 1
	end,
}

local function bool(): types.DataType<boolean>
	return bool_data_type
end

return bool
