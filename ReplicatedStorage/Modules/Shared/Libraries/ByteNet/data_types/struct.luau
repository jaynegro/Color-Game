local types = require("../types")

local function struct<T, V>(input: T & { [string]: types.DataType<V> }): types.DataType<T>
	local index_value_type_pairs: { [number]: types.DataType<any> } = {}
	local index_key_pairs: { [number]: string } = {}

	local keys = {}
	local count = 0
	for key in pairs(input :: any) do
		count += 1
		keys[count] = key
	end

	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)

	for index, key in ipairs(keys) do
		index_value_type_pairs[index] = input[key]
		index_key_pairs[index] = key
	end

	return {
		__T = nil :: T,

		read = function(b: buffer, cursor: number)
			local constructed = table.clone(input)
			local struct_cursor = cursor

			for index, value_type in ipairs(index_value_type_pairs) do
				local value, length = value_type.read(b, struct_cursor)
				constructed[index_key_pairs[index]] = value
				struct_cursor += length
			end

			return constructed, struct_cursor - cursor
		end,

		write = function(struct_value)
			for index, value_type in ipairs(index_value_type_pairs) do
				value_type.write(struct_value[index_key_pairs[index]])
			end
		end,
	}
end

return struct
