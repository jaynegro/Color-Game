local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local buffer_writer = require("./buffer_writer")
local read = require("./read")
local types = require("../types")

local write_packet = buffer_writer.write_packet

local function onClientEvent(receivedBuffer, ref)
	read(receivedBuffer, ref)
end

local function create(): types.ChannelState
	return {
		cursor = 0,
		size = 65535,
		references = {},
		buff = buffer.create(65535),
	}
end

local function dump(channel: types.ChannelState): (buffer, { unknown }?)
	local cursor = channel.cursor
	local dumpBuffer = buffer.create(cursor)

	buffer.copy(dumpBuffer, 0, channel.buff, 0, cursor)

	return dumpBuffer, if #channel.references > 0 then channel.references else nil
end

local reliable: types.ChannelState = create()
local unreliable: types.ChannelState = create()

local client = {}

function client.send_reliable<T>(id: number, writer: (value: any) -> (), data: T)
	reliable = write_packet(reliable, id, writer, data)
end

function client.send_unreliable(id: number, writer: (value: any) -> (), data: { [string]: any })
	unreliable = write_packet(unreliable, id, writer, data)
end

function client.init()
	local reliableRemote = ReplicatedStorage:WaitForChild("ByteNetReliable")
	reliableRemote.OnClientEvent:Connect(onClientEvent)

	local unreliableRemote = ReplicatedStorage:WaitForChild("ByteNetUnreliable")
	unreliableRemote.OnClientEvent:Connect(onClientEvent)

	RunService.Heartbeat:Connect(function()
		-- Again, checking if there's anything in the channel before we send it.
		if reliable.cursor > 0 then
			local b, r = dump(reliable)
			reliableRemote:FireServer(b, r)

			-- effectively clears the channel
			reliable.cursor = 0
			table.clear(reliable.references)
		end

		if unreliable.cursor > 0 then
			local b, r = dump(unreliable)
			unreliableRemote:FireServer(b, r)

			unreliable.cursor = 0
			table.clear(unreliable.references)
		end
	end)
end

return client
