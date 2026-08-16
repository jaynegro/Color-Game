local packet = require("./packet")
local types = require("../types")

local function define_packet(props: types.PacketProps<any>)
	return function(id: number)
		return packet(props, id)
	end
end

return define_packet
