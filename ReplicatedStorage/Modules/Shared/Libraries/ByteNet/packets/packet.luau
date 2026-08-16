local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local client = require("../process/client")
local registry = require("../a")
local server = require("../process/server")
local types = require("../types")

local run_context: "server" | "client" = if RunService:IsServer() then "server" else "client"

return function(props: types.PacketProps<types.DataType<any>>, id: number)
	local reliabilityType = props.reliability or "Reliable"
	local listeners = {}
	local writer = props.value.write

	local serverSendFunction = if reliabilityType == "Reliable" then server.sendPlayerReliable else server.sendPlayerUnreliable
	local serverSendAllFunction = if reliabilityType == "Reliable" then server.sendAllReliable else server.sendAllUnreliable
	local clientSendFunction = if reliabilityType == "Reliable" then client.send_reliable else client.send_unreliable

	local exported = {}
	exported.reader = props.value.read

	registry.register(id, exported)

	setmetatable(exported, {
		__index = function(_, index)
			if (index == "sendTo" or index == "sendToAllExcept" or index == "sendToAll") and run_context == "client" then
				error("You cannot use sendTo, sendToAllExcept, or sendToAll on the client")
			elseif index == "send" and run_context == "server" then
				error("You cannot use send on the server")
			end
			return nil
		end,
	})

	if run_context == "server" then
		function exported.sendToList(data, playersList: { Player })
			for _, player in ipairs(playersList) do
				serverSendFunction(player, id, writer, data)
			end
		end

		function exported.sendTo(data, player: Player)
			serverSendFunction(player, id, writer, data)
		end

		function exported.sendToAllExcept(data, except: Player)
			for _, player: Player in ipairs(Players:GetPlayers()) do
				if player ~= except then
					serverSendFunction(player, id, writer, data)
				end
			end
		end

		function exported.sendToAll(data)
			serverSendAllFunction(id, writer, data)
		end
	else
		function exported.send(data)
			clientSendFunction(id, writer, data)
		end
	end

	function exported.wait()
		local index: number
		local runningThread = coroutine.running()
		table.insert(listeners, function(data, player)
			task.spawn(runningThread, data, player)
			table.remove(listeners, index)
		end)
		index = #listeners
		return coroutine.yield()
	end

	function exported.listen(callback)
		table.insert(listeners, callback)
	end

	function exported.getListeners()
		return listeners
	end

	return exported
end
