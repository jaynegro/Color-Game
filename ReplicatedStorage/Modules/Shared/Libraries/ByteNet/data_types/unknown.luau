local channel_state = require("../process/channel_state")
local types = require("../types")

return function(): types.DataType<unknown>
	return {
		write = function(value: unknown)
			if typeof(value) == "Instance" then
				local path = (value :: Instance):GetFullName()
				buffer.writeu8(channel_state.buff, channel_state.cursor, 1)
				channel_state.cursor += 1
				local length = string.len(path)
				buffer.writeu16(channel_state.buff, channel_state.cursor, length)
				channel_state.cursor += 2
				buffer.writestring(channel_state.buff, channel_state.cursor, path)
				channel_state.cursor += length
				return
			end

			local text = tostring(value)
			buffer.writeu8(channel_state.buff, channel_state.cursor, 0)
			channel_state.cursor += 1
			local length = string.len(text)
			buffer.writeu16(channel_state.buff, channel_state.cursor, length)
			channel_state.cursor += 2
			buffer.writestring(channel_state.buff, channel_state.cursor, text)
			channel_state.cursor += length
		end,

		read = function(b: buffer, cursor: number)
			local kind = buffer.readu8(b, cursor)
			local length = buffer.readu16(b, cursor + 1)
			local text = buffer.readstring(b, cursor + 3, length)
			if kind == 1 then
				return resolvePath(text), length + 3
			end
			return text, length + 3
		end,
	}
end
