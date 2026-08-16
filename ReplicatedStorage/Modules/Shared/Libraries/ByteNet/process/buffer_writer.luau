local channelState = require("./channel_state")

local BUFFER_SIZE = 65535

local function write_packet(channel, id: number, writer: (value: any) -> (), data: any)
	if channel.buff == nil or buffer.len(channel.buff) < BUFFER_SIZE then
		channel.buff = buffer.create(BUFFER_SIZE)
	end

	channel.cursor = 0
	buffer.writeu8(channel.buff, channel.cursor, id)
	channel.cursor += 1

	channelState.buff = channel.buff
	channelState.cursor = channel.cursor
	writer(data)
	channel.cursor = channelState.cursor

	return channel
end

return {
	write_packet = write_packet,
}
