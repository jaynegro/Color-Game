local channel_state = require("../process/channel_state")
local types = require("../types")

local function map(keyType: types.DataType<any>, valueType: types.DataType<any>): types.DataType<{ [any]: any }>
	local key_write = keyType.write
	local value_write = valueType.write

	return {
		read = function(b: buffer, cursor: number)
			local result = {}
			local mapCursor = cursor
			local mapLength = buffer.readu16(b, mapCursor)
			mapCursor += 2

			for _ = 1, mapLength do
				local key, keyLength = keyType.read(b, mapCursor)
				mapCursor += keyLength

				local value, valueLength = valueType.read(b, mapCursor)
				mapCursor += valueLength

				result[key] = value
			end

			return result, mapCursor - cursor
		end,

		write = function(mapValue: any)
			local keys = {}
			local count = 0
			for key in pairs(mapValue) do
				count += 1
				keys[count] = key
			end

			table.sort(keys, function(a, b)
				return tostring(a) < tostring(b)
			end)

			buffer.writeu16(channel_state.buff, channel_state.cursor, count)
			channel_state.cursor += 2

			for i = 1, count do
				local key = keys[i]
				key_write(key)
				value_write(mapValue[key])
			end
		end,
	}
end

return map
