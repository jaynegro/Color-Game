--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local MINIMUM_SESSION_TIME = 15 * 60

local MAX_TELEPORT_RETRIES = 3
local RETRY_DELAY = 3

local AFKService = {}

local joinedAt: { [Player]: number } = {}
local teleporting: { [Player]: boolean } = {}
local retryCount: { [Player]: number } = {}

local function teleportPlayer(player: Player)
	if not player.Parent then
		return
	end

	local options = Instance.new("TeleportOptions")

	local success, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)

	if not success then
		teleporting[player] = false

		warn(`[ColorGame] Failed to start AFK rejoin for {player.Name}: {tostring(err)}`)
	end
end

local function onPlayerAdded(player: Player)
	joinedAt[player] = os.clock()
	teleporting[player] = false
	retryCount[player] = 0
end

local function onPlayerRemoving(player: Player)
	joinedAt[player] = nil
	teleporting[player] = nil
	retryCount[player] = nil
end

function AFKService.Init()
	local Remote = require(ReplicatedStorage.Modules.Shared.ReplicaShared.Remote)
	local afkRejoinRemote = Remote.New("AFKRejoin") :: any

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	afkRejoinRemote.OnServerEvent:Connect(function(player: Player)
		if teleporting[player] then
			return
		end

		local joinTime = joinedAt[player]

		if not joinTime then
			return
		end

		local sessionTime = os.clock() - joinTime

		if sessionTime < MINIMUM_SESSION_TIME then
			warn(`[ColorGame] {player.Name} requested AFK rejoin too early.`)

			return
		end

		teleporting[player] = true
		retryCount[player] = 0

		print(`[ColorGame] Rejoining AFK player {player.Name}...`)

		teleportPlayer(player)
	end)

	TeleportService.TeleportInitFailed:Connect(
		function(
			player: Player,
			teleportResult: Enum.TeleportResult,
			errorMessage: string,
			placeId: number,
			teleportOptions: TeleportOptions
		)
			if not teleporting[player] then
				return
			end

			local attempts = retryCount[player] or 0
			attempts += 1

			retryCount[player] = attempts

			if attempts > MAX_TELEPORT_RETRIES then
				teleporting[player] = false

				warn(
					`[ColorGame] AFK rejoin failed permanently for {player.Name}: `
						.. `{teleportResult.Name} - {errorMessage}`
				)

				return
			end

			warn(
				`[ColorGame] AFK rejoin failed for {player.Name}. `
					.. `Retry {attempts}/{MAX_TELEPORT_RETRIES} in {RETRY_DELAY}s. `
					.. `{teleportResult.Name}: {errorMessage}`
			)

			task.delay(RETRY_DELAY, function()
				if not player.Parent then
					return
				end

				local success, err = pcall(function()
					TeleportService:TeleportAsync(placeId, { player }, teleportOptions)
				end)

				if not success then
					teleporting[player] = false

					warn(`[ColorGame] AFK teleport retry errored for ` .. `{player.Name}: {tostring(err)}`)
				end
			end)
		end
	)
end

return AFKService
