local channel_state = require("../process/channel_state")
local types = require("../types")

local cframe: types.DataType<CFrame> = {
	__T = ... :: CFrame,

	read = function(b: buffer, cursor: number)
		local components = table.create(12)
		for i = 1, 12 do
			components[i] = buffer.readf32(b, cursor + ((i - 1) * 4))
		end
		return CFrame.new(table.unpack(components)), 48
	end,

	write = function(value: CFrame)
		local components = { value:GetComponents() }
		for i = 1, 12 do
			buffer.writef32(channel_state.buff, channel_state.cursor + ((i - 1) * 4), components[i])
		end
		channel_state.cursor += 48
	end,
}

return function(): types.DataType<CFrame>
	return cframe
end
