--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local TableService = {}

type Session = {
	Player: Player,
	Humanoid: Humanoid,
	Seat: Seat,
	Board: Instance,
	Id: string,
	Choice: string?,
	RoundId: number?,
	RainbowLocked: boolean,
	ProtectionActive: boolean,
	LockedUntil: number,
}

local config: any
local network: any
local dataManager: any
local eventConnection: RBXScriptConnection?
local playerSessions: { [Player]: Session } = {}
local seatSessions: { [Seat]: Session } = {}
local seatConnections: { RBXScriptConnection } = {}
local pickingOpen = false
local currentRoundId = 0
local promptRainbow: ((Player) -> ())? = nil
local promptStreakProtection: ((Player) -> ())? = nil
local checkVIPAccess: ((Player) -> boolean)? = nil
local onVIPDenied: ((Player) -> ())? = nil
local checkAutoPickEnabled: ((Player) -> boolean)? = nil
local colorSet: { [string]: string } = {}
local selectableColors: { string } = {}
local lastRequestAt: { [Player]: number } = {}
local lastPromptAt: { [Player]: number } = {}
local lastVIPPromptAt: { [Player]: number } = {}
local vipChecks: { [Seat]: Humanoid } = {}
local vipEjectGenerations: { [Humanoid]: number } = {}
local tryAutoPick: ((Session) -> ())? = nil

local function followPath(root: Instance, path: { string }): Instance
	local current = root
	for _, name in path do
		current = current:WaitForChild(name)
	end
	return current
end

local function releaseSeat(seat: Seat)
	local session = seatSessions[seat]
	if not session then
		return
	end
	seatSessions[seat] = nil
	if playerSessions[session.Player] == session then
		playerSessions[session.Player] = nil
		network.FireAll("BoardVisibility", session.Board, false)
		if session.Choice then
			network.FireAll("LivePick", session.Player.UserId, nil)
		end
		network.FireClient(session.Player, "SeatReleased", session.Id)
	end
end

local function assignSeat(seat: Seat, board: Instance, player: Player, humanoid: Humanoid)
	local oldSession = playerSessions[player]
	if oldSession then
		releaseSeat(oldSession.Seat)
	end

	local session: Session = {
		Player = player,
		Humanoid = humanoid,
		Seat = seat,
		Board = board,
		Id = HttpService:GenerateGUID(false),
		Choice = nil,
		RoundId = nil,
		RainbowLocked = false,
		ProtectionActive = false,
		LockedUntil = os.clock() + config.SeatLockDuration,
	}
	seatSessions[seat] = session
	playerSessions[player] = session
	network.FireAll("BoardVisibility", board, true)
	network.FireClient(player, "SeatAssigned", session.Id, board)
	network.FireClient(player, "Picking", pickingOpen, currentRoundId)
	task.delay(config.SeatLockDuration, function()
		if playerSessions[player] == session and session.Humanoid.Parent and session.Humanoid.Health > 0 then
			network.FireClient(player, "SeatLockEnded", session.Id)
		end
	end)
	if pickingOpen and tryAutoPick then
		tryAutoPick(session)
	end
end

local function ejectFromVIPSeat(player: Player, humanoid: Humanoid)
	vipEjectGenerations[humanoid] = (vipEjectGenerations[humanoid] or 0) + 1
	local generation = vipEjectGenerations[humanoid]
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
	humanoid.Sit = false
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	network.FireClient(player, "Notice", "VIP Game Pass required to use this table.")

	task.delay(config.VIPReseatBlockDuration, function()
		if vipEjectGenerations[humanoid] ~= generation then
			return
		end
		vipEjectGenerations[humanoid] = nil
		if humanoid.Parent and humanoid.Health > 0 then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
		end
	end)
end

local function onSeatChanged(seat: Seat, board: Instance, isVIP: boolean)
	local humanoid = seat.Occupant
	local existing = seatSessions[seat]
	if existing and humanoid == existing.Humanoid then
		return
	end
	if existing and not humanoid and os.clock() < existing.LockedUntil
		and existing.Humanoid.Health > 0 and existing.Humanoid:IsDescendantOf(workspace) then
		task.defer(function()
			if seat.Occupant == nil and seatSessions[seat] == existing and os.clock() < existing.LockedUntil then
				existing.Humanoid.Sit = true
				seat:Sit(existing.Humanoid)
			end
		end)
		return
	end

	releaseSeat(seat)
	if not humanoid then
		return
	end
	local player = Players:GetPlayerFromCharacter(humanoid.Parent)
	if not player then
		return
	end

	if isVIP then
		if vipChecks[seat] == humanoid then
			return
		end
		vipChecks[seat] = humanoid
		local ok, allowed = pcall(function()
			return checkVIPAccess ~= nil and checkVIPAccess(player)
		end)
		if vipChecks[seat] == humanoid then
			vipChecks[seat] = nil
		end
		if seat.Occupant ~= humanoid then
			return
		end
		if not ok or allowed ~= true then
			if not ok then
				warn(`[ColorGame] VIP access check failed for {player.Name}: {allowed}`)
			end
			ejectFromVIPSeat(player, humanoid)
			local now = os.clock()
			if onVIPDenied and now - (lastVIPPromptAt[player] or 0) >= 5 then
				lastVIPPromptAt[player] = now
				onVIPDenied(player)
			end
			return
		end
	end

	assignSeat(seat, board, player, humanoid)
end

local function selectChoice(session: Session, choice: string, rainbowLocked: boolean)
	session.Choice = choice
	session.RoundId = currentRoundId
	session.RainbowLocked = rainbowLocked
	network.FireClient(session.Player, "Selection", choice, rainbowLocked)
	network.FireAll("LivePick", session.Player.UserId, choice)
end

tryAutoPick = function(session: Session)
	if not pickingOpen or #selectableColors == 0 or not checkAutoPickEnabled then
		return
	end
	local ok, enabled = pcall(checkAutoPickEnabled, session.Player)
	if not ok then
		warn(`[ColorGame] Auto Pick check failed for {session.Player.Name}: {enabled}`)
		return
	end
	if enabled == true then
		selectChoice(session, selectableColors[math.random(1, #selectableColors)], false)
	end
end

local function getLivePickSnapshot(): { { UserId: number, Choice: string } }
	local snapshot = {}
	for player, session in playerSessions do
		if session.RoundId == currentRoundId and session.Choice then
			table.insert(snapshot, {
				UserId = player.UserId,
				Choice = session.Choice,
			})
		end
	end
	return snapshot
end

local function getOccupiedBoardSnapshot(): { Instance }
	local snapshot = {}
	for _, session in playerSessions do
		table.insert(snapshot, session.Board)
	end
	return snapshot
end

local function handleSelection(player: Player, sessionId: any, requested: any)
	if type(sessionId) ~= "string" or type(requested) ~= "string" then
		return
	end
	if not pickingOpen then
		network.FireClient(player, "Notice", "Picking is currently closed.")
		return
	end
	if #requested > 32 then
		return
	end
	local now = os.clock()
	if now - (lastRequestAt[player] or 0) < 0.08 then
		return
	end
	lastRequestAt[player] = now
	local session = playerSessions[player]
	local occupant = session and session.Seat.Occupant
	if not session or session.Id ~= sessionId or not occupant
		or Players:GetPlayerFromCharacter(occupant.Parent) ~= player then
		network.FireClient(player, "Notice", "Your table seat session expired. Please sit again.")
		return
	end
	if session.RainbowLocked and session.RoundId == currentRoundId then
		network.FireClient(player, "Notice", "Rainbow is locked for this round.")
		return
	end

	if requested == "Orange" then
		if session.ProtectionActive and session.RoundId == currentRoundId then
			return
		end
		if dataManager.ConsumeStreakProtectionCredit(player) then
			session.ProtectionActive = true
			session.RoundId = currentRoundId
			network.FireClient(player, "Protection", true)
		elseif promptStreakProtection and now - (lastPromptAt[player] or 0) >= 2 then
			lastPromptAt[player] = now
			promptStreakProtection(player)
		else
			network.FireClient(player, "Notice", "Streak Protection is not configured yet.")
		end
		return
	end

	if requested == "Rainbow" then
		if session.ProtectionActive then
			network.FireClient(player, "Notice", "Rainbow cannot be combined with Streak Protection.")
			return
		end
		if dataManager.ConsumeRainbowCredit(player) then
			selectChoice(session, "Rainbow", true)
		elseif promptRainbow and now - (lastPromptAt[player] or 0) >= 2 then
			lastPromptAt[player] = now
			promptRainbow(player)
		else
			network.FireClient(player, "Notice", "Rainbow is not configured yet.")
		end
		return
	end

	if requested == "Random" then
		selectChoice(session, selectableColors[math.random(1, #selectableColors)], false)
		return
	end

	local normalized = colorSet[string.lower(requested)]
	if normalized then
		selectChoice(session, normalized, false)
	else
		network.FireClient(player, "Notice", `{requested} is not configured on BasicDice.`)
	end
end

function TableService.Init(gameConfig, networkService, playerDataManager, availableColors: { string })
	config = gameConfig
	network = networkService
	dataManager = playerDataManager
	selectableColors = table.clone(availableColors)
	for _, color in selectableColors do
		colorSet[string.lower(color)] = color
	end

	local tablesFolder = followPath(workspace, config.TablesPath)
	for _, tableModel in tablesFolder:GetChildren() do
		if tableModel:IsA("Model") and (tableModel.Name == "Table" or tableModel.Name == "Table_VIP") then
			local isVIP = tableModel.Name == "Table_VIP"
			for _, chair in tableModel:GetChildren() do
				local index = string.match(chair.Name, "^Chair(%d+)$")
				if index then
					local seat = chair:FindFirstChildWhichIsA("Seat", true)
					local board = tableModel:FindFirstChild(`GameBoard{index}`)
					if seat and board then
						local typedSeat = seat :: Seat
						table.insert(seatConnections, typedSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
							onSeatChanged(typedSeat, board, isVIP)
						end))
						if typedSeat.Occupant then
							task.defer(onSeatChanged, typedSeat, board, isVIP)
						end
					end
				end
			end
		end
	end

	local tableEvent = network.Event :: RemoteEvent
	eventConnection = tableEvent.OnServerEvent:Connect(function(player, action, ...)
		if action == "Select" then
			handleSelection(player, ...)
		elseif action == "ClientReady" then
			network.FireClient(player, "LivePickSnapshot", getLivePickSnapshot())
			network.FireClient(player, "BoardSnapshot", getOccupiedBoardSnapshot())
			local session = playerSessions[player]
			if session then
				network.FireClient(player, "SeatAssigned", session.Id, session.Board)
				network.FireClient(player, "Picking", pickingOpen, currentRoundId)
				if session.Choice then
					network.FireClient(player, "Selection", session.Choice, session.RainbowLocked)
				end
				if session.ProtectionActive then
					network.FireClient(player, "Protection", true)
				end
			end
		elseif action == "LivePickingReady" then
			network.FireClient(player, "LivePickSnapshot", getLivePickSnapshot())
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequestAt[player] = nil
		lastPromptAt[player] = nil
		lastVIPPromptAt[player] = nil
		local session = playerSessions[player]
		if session then
			releaseSeat(session.Seat)
		end
	end)
end

function TableService.SetRainbowPrompt(callback: (Player) -> ())
	promptRainbow = callback
end

function TableService.SetStreakProtectionPrompt(callback: (Player) -> ())
	promptStreakProtection = callback
end

function TableService.SetVIPAccessChecker(callback: (Player) -> boolean)
	checkVIPAccess = callback
end

function TableService.SetVIPDeniedHandler(callback: (Player) -> ())
	onVIPDenied = callback
end

function TableService.SetAutoPickChecker(callback: (Player) -> boolean)
	checkAutoPickEnabled = callback
end

function TableService.OnAutoPickEnabled(player: Player)
	local session = playerSessions[player]
	if session and tryAutoPick then
		tryAutoPick(session)
	end
end

function TableService.OnRainbowGranted(player: Player)
	local session = playerSessions[player]
	if pickingOpen and session and not session.RainbowLocked and not session.ProtectionActive
		and dataManager.ConsumeRainbowCredit(player) then
		selectChoice(session, "Rainbow", true)
	end
end

function TableService.OnStreakProtectionGranted(player: Player)
	local session = playerSessions[player]
	if pickingOpen and session and not session.RainbowLocked and not session.ProtectionActive
		and dataManager.ConsumeStreakProtectionCredit(player) then
		session.ProtectionActive = true
		session.RoundId = currentRoundId
		network.FireClient(player, "Protection", true)
	end
end

function TableService.SetPickingOpen(isOpen: boolean, roundId: number)
	pickingOpen = isOpen
	currentRoundId = roundId
	if isOpen then
		network.FireAll("LivePickSnapshot", {})
		for _, session in playerSessions do
			session.Choice = nil
			session.RoundId = nil
			session.RainbowLocked = false
			session.ProtectionActive = false
			network.FireClient(session.Player, "Selection", nil, false)
			network.FireClient(session.Player, "Protection", false)
			if tryAutoPick then
				tryAutoPick(session)
			end
		end
	end
	for player in playerSessions do
		network.FireClient(player, "Picking", isOpen, roundId)
	end
end

function TableService.Resolve(results: { string })
	local resultCounts: { [string]: number } = {}
	for _, result in results do
		local key = string.lower(result)
		resultCounts[key] = (resultCounts[key] or 0) + 1
	end

	local summary: { [string]: number } = {}
	local winners = {}
	for player, session in playerSessions do
		if session.RoundId == currentRoundId and session.Choice then
			summary[session.Choice] = (summary[session.Choice] or 0) + 1
			local matchedDice = resultCounts[string.lower(session.Choice)] or 0
			local won = session.RainbowLocked or matchedDice > 0
			local reward = if session.RainbowLocked then 1 else matchedDice
			if won then
				dataManager.RecordWin(player, reward)
				table.insert(winners, {
					UserId = player.UserId,
					DisplayName = player.DisplayName,
					Choice = session.Choice,
					Reward = reward,
					Matches = dataManager.GetMatches(player),
				})
			else
				if session.ProtectionActive then
					dataManager.RecordProtectedLoss(player)
				else
					dataManager.RecordLoss(player)
				end
			end
			network.FireClient(player, "Outcome", won, reward, session.Choice, session.ProtectionActive)
		end
	end

	return {
		Summary = summary,
		Winners = winners,
	}
end

return TableService
