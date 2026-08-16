local channel_state = require("../process/channel_state")
local types = require("../types")

local function array<T>(value_ty: types.DataType<T>): types.DataType<{ T }>
	local val_write = value_ty.write
	local val_read = value_ty.read

	return {
		__T = nil :: T,

		read = function(buff: buffer, cursor: number)
			local array_length = buffer.readu16(buff, cursor)
			local array_cursor = cursor + 2
			local array = table.create(array_length)

			for i = 1, array_length do
				local item, length = val_read(buff, array_cursor)
				array[i] = item
				array_cursor += length
			end

			return array, array_cursor - cursor
		end,

		write = function(value: any)
			local length = #value
			buffer.writeu16(channel_state.buff, channel_state.cursor, length)
			channel_state.cursor += 2

			for i = 1, length do
				val_write(value[i])
			end
		end,
	}
end

return array
