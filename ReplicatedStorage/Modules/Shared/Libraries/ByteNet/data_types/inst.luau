local channel_state = require("../process/channel_state")
local types = require("../types")

local function resolvePath(path: string): Instance?
	local current: Instance = game
	for segment in string.split(path, ".") do
		local nextChild = current:FindFirstChild(segment)
		if not nextChild then
			return nil
		end
		current = nextChild
	end
	return current
end

return function(): types.DataType<Instance?>
	return {
		write = function(value)
			if value == nil then
				buffer.writeu8(channel_state.buff, channel_state.cursor, 0)
				channel_state.cursor += 1
				return
			end

			local path = value:GetFullName()
			buffer.writeu8(channel_state.buff, channel_state.cursor, 1)
			channel_state.cursor += 1
			local length = string.len(path)
			buffer.writeu16(channel_state.buff, channel_state.cursor, length)
			channel_state.cursor += 2
			buffer.writestring(channel_state.buff, channel_state.cursor, path)
			channel_state.cursor += length
		end,

		read = function(b: buffer, cursor: number)
			if buffer.readu8(b, cursor) == 0 then
				return nil, 1
			end

			local length = buffer.readu16(b, cursor + 1)
			local path = buffer.readstring(b, cursor + 3, length)
			return resolvePath(path), length + 3
		end,
	}
end
