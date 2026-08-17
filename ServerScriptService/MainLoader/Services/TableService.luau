--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local BoardResultEffectService = require(script.Parent.BoardResultEffectService)

local TableService = {}

local NON_VIP_CHARACTER_GROUP = "ColorGameNonVIP"
local VIP_SEAT_GROUP = "ColorGameVIPSeat"

type Session = {
	Player: Player,
	Humanoid: Humanoid,
	Seat: Seat,
	Board: Instance,
	TableModel: Model,
	Id: string,
	Choice: string?,
	DisplayChoice: string?,
	RoundId: number?,
	RainbowLocked: boolean,
	ProtectionActive: boolean,
	LockedUntil: number,
}

local config: any
local network: any
local dataManager: any
local duelService: any = nil
local eventConnection: RBXScriptConnection?
local playerSessions: { [Player]: Session } = {}
local seatSessions: { [Seat]: Session } = {}
local seatConnections: { RBXScriptConnection } = {}
local chairRecords: { [Model]: { Parts: { BasePart }, SeatStates: { [Seat]: boolean } } } = {}
local chairHideGeneration = 0
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
local vipTouchDebounce: { [Humanoid]: number } = {}
local vipCharacterConnections: { [Player]: RBXScriptConnection } = {}
local vipAttributeConnections: { [Player]: RBXScriptConnection } = {}
local roundCameraPlayers: { [Player]: boolean } = {}
local tryAutoPick: ((Session) -> ())? = nil
local releaseSeat: ((Seat) -> ())?

local function followPath(root: Instance, path: { string }): Instance
	local current = root
	for _, name in path do
		current = current:WaitForChild(name)
	end
	return current
end

local function registerChairModel(chair: Model)
	if chairRecords[chair] then
		return
	end
	local seatStates: { [Seat]: boolean } = {}
	for _, descendant in chair:GetDescendants() do
		if descendant:IsA("Seat") then
			seatStates[descendant] = descendant.Disabled
		end
	end
	chairRecords[chair] = {
		SeatStates = seatStates,
	}
end

local function setChairModelVisible(chair: Model, visible: boolean)
	local record = chairRecords[chair]
	if not record then
		return
	end
	for _, descendant in chair:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") or descendant:IsA("Texture") then
			local part = descendant
			if visible then
				local originalTransparency = part:GetAttribute("AllChairsOriginalTransparency")
				if type(originalTransparency) == "number" then
					part.Transparency = originalTransparency
				end
				if part:IsA("BasePart") then
					part.CanCollide = part:GetAttribute("AllChairsOriginalCanCollide") ~= false
					part.CanTouch = part:GetAttribute("AllChairsOriginalCanTouch") ~= false
					part.CanQuery = part:GetAttribute("AllChairsOriginalCanQuery") ~= false
				end
			else
				if part:GetAttribute("AllChairsOriginalTransparency") == nil then
					part:SetAttribute("AllChairsOriginalTransparency", part.Transparency)
					if part:IsA("BasePart") then
						part:SetAttribute("AllChairsOriginalCanCollide", part.CanCollide)
						part:SetAttribute("AllChairsOriginalCanTouch", part.CanTouch)
						part:SetAttribute("AllChairsOriginalCanQuery", part.CanQuery)
					end
				end
				part.Transparency = 1
				if part:IsA("BasePart") then
					part.CanCollide = false
					part.CanTouch = false
					part.CanQuery = false
				end
			end
		end
		if descendant:IsA("Seat") then
			local seat = descendant :: Seat
			local seatDisabled = record.SeatStates[seat]
			if visible then
				seat.Disabled = if seatDisabled ~= nil then seatDisabled else false
			else
				seat.Disabled = true
			end
		end
	end
end

local function setAllChairsVisible(visible: boolean)
	for chair in chairRecords do
		setChairModelVisible(chair, visible)
	end
end

local function releaseAllSeatedPlayers()
	local sessions = {}
	for _, session in seatSessions do
		table.insert(sessions, session)
	end
	for _, session in sessions do
		session.Humanoid.Sit = false
		session.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		releaseSeat(session.Seat)
	end
end

function TableService.RemoveAllChairsForDuration(duration: number)
	chairHideGeneration += 1
	local generation = chairHideGeneration
	releaseAllSeatedPlayers()
	setAllChairsVisible(false)
	task.delay(math.max(0, duration), function()
		if generation ~= chairHideGeneration then
			return
		end
		setAllChairsVisible(true)
	end)
end

releaseSeat = function(seat: Seat)
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
		if duelService then
			duelService.OnSeatReleased(session.Player, session.TableModel)
		end
	end
end

local function assignSeat(seat: Seat, board: Instance, tableModel: Model, player: Player, humanoid: Humanoid)
	local oldSession = playerSessions[player]
	if oldSession then
		releaseSeat(oldSession.Seat)
	end

	local session: Session = {
		Player = player,
		Humanoid = humanoid,
		Seat = seat,
		Board = board,
		TableModel = tableModel,
		Id = HttpService:GenerateGUID(false),
		Choice = nil,
		DisplayChoice = nil,
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
	if pickingOpen and tryAutoPick then
		tryAutoPick(session)
	end
	if duelService then
		duelService.OnSeatAssigned(player, tableModel)
	end
end

local function ejectFromVIPSeat(seat: Seat, player: Player, humanoid: Humanoid)
	-- Let Roblox release the seat itself (Sit = false handles destroying its
	-- own SeatWeld and clearing Occupant/seated state atomically). Manually
	-- destroying SeatWeld first used to race that cleanup and could leave the
	-- Humanoid stuck thinking it was still seated, blocking it from sitting
	-- anywhere else until the character respawned.
	humanoid.Sit = false
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

	-- Temporarily disable this individual seat so Roblox cannot recreate its
	-- SeatWeld while the denied character is still touching it.
	local wasDisabled = seat.Disabled
	seat.Disabled = true

	local character = humanoid.Parent
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and character:IsA("Model") and root and root:IsA("BasePart") then
		local ejectPosition = seat.Position + seat.CFrame.LookVector * 3 + Vector3.new(0, 2, 0)
		character:PivotTo(CFrame.lookAt(ejectPosition, ejectPosition + seat.CFrame.LookVector))
	end

	task.delay(0.5, function()
		if seat.Parent then
			seat.Disabled = wasDisabled
		end
	end)
end

local function promptVIPPurchase(player: Player)
	local now = os.clock()
	if now - (lastVIPPromptAt[player] or 0) < 5 then
		return
	end
	lastVIPPromptAt[player] = now
	network.FireClient(player, "Notice", "VIP Game Pass required to use this table.")
	if onVIPDenied then
		onVIPDenied(player)
	end
end

local function guardVIPSeatTouch(seat: Seat, touchedPart: BasePart)
	local character = touchedPart:FindFirstAncestorOfClass("Model")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player or player:GetAttribute("IsVIP") == true then
		return
	end
	local now = os.clock()
	if now - (vipTouchDebounce[humanoid] or 0) < 0.75 then
		return
	end
	vipTouchDebounce[humanoid] = now
	local occupant = seat.Occupant
	local occupantName = if occupant and occupant.Parent then occupant.Parent.Name else "nil"
	warn(`[ColorGame][Debug] guardVIPSeatTouch ejecting {player.Name} from {seat:GetFullName()}, HumanoidState={humanoid:GetState()}, seat.Occupant={occupantName}`)
	ejectFromVIPSeat(seat, player, humanoid)
	promptVIPPurchase(player)
end

local function setCharacterVIPCollision(player: Player, character: Model)
	local collisionGroup = if player:GetAttribute("IsVIP") == true then "Default" else NON_VIP_CHARACTER_GROUP
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "RagdollCollider"
			and (collisionGroup == NON_VIP_CHARACTER_GROUP or descendant.CollisionGroup == NON_VIP_CHARACTER_GROUP) then
			descendant.CollisionGroup = collisionGroup
		end
	end
end

local function bindVIPCharacter(player: Player, character: Model)
	local oldConnection = vipCharacterConnections[player]
	if oldConnection then
		oldConnection:Disconnect()
	end
	setCharacterVIPCollision(player, character)
	vipCharacterConnections[player] = character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") and descendant.Name ~= "RagdollCollider"
			and player:GetAttribute("IsVIP") ~= true then
			descendant.CollisionGroup = NON_VIP_CHARACTER_GROUP
		end
	end)
end

local function bindVIPPlayer(player: Player)
	if vipAttributeConnections[player] then
		return
	end
	vipAttributeConnections[player] = player:GetAttributeChangedSignal("IsVIP"):Connect(function()
		local character = player.Character
		if character then
			setCharacterVIPCollision(player, character)
		end
	end)
	player.CharacterAdded:Connect(function(character)
		bindVIPCharacter(player, character)
	end)
	if player.Character then
		bindVIPCharacter(player, player.Character)
	end
end

local function onSeatChanged(seat: Seat, board: Instance, tableModel: Model, isVIP: boolean)
	local humanoid = seat.Occupant
	local existing = seatSessions[seat]
	local occupantCharacterName = if humanoid and humanoid.Parent then humanoid.Parent.Name else "nil"
	warn(`[ColorGame][Debug] onSeatChanged seat={seat:GetFullName()} isVIP={isVIP} occupant={occupantCharacterName} existing={existing ~= nil}`)
	if existing and humanoid == existing.Humanoid then
		warn(`[ColorGame][Debug]   -> same occupant as existing session, no-op`)
		return
	end
	if existing and not humanoid and os.clock() < existing.LockedUntil
		and existing.Humanoid.Health > 0 and existing.Humanoid:IsDescendantOf(workspace) then
		warn(`[ColorGame][Debug]   -> sticky-reseat armed for {existing.Player.Name}, LockedUntil in {existing.LockedUntil - os.clock()}s`)
		task.defer(function()
			if seat.Occupant == nil and seatSessions[seat] == existing and os.clock() < existing.LockedUntil then
				warn(`[ColorGame][Debug]   -> sticky-reseat FIRING for {existing.Player.Name} on {seat:GetFullName()} (humanoid current seat occupant elsewhere? checking) HumanoidState={existing.Humanoid:GetState()}`)
				existing.Humanoid.Sit = true
				seat:Sit(existing.Humanoid)
			else
				warn(`[ColorGame][Debug]   -> sticky-reseat SKIPPED (conditions no longer met) for {existing.Player.Name}`)
			end
		end)
		return
	end

	releaseSeat(seat)
	if not humanoid then
		warn(`[ColorGame][Debug]   -> no humanoid, seat now empty`)
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
			warn(`[ColorGame][Debug]   -> VIP check resolved but occupant changed already, aborting for {player.Name}`)
			return
		end
		if not ok or allowed ~= true then
			if not ok then
				warn(`[ColorGame] VIP access check failed for {player.Name}: {allowed}`)
			end
			warn(`[ColorGame][Debug]   -> VIP denied for {player.Name}, HumanoidState before eject={humanoid:GetState()}`)
			ejectFromVIPSeat(seat, player, humanoid)
			promptVIPPurchase(player)
			warn(`[ColorGame][Debug]   -> VIP eject done for {player.Name}, HumanoidState after eject={humanoid:GetState()}`)
			return
		end
	end

	warn(`[ColorGame][Debug]   -> assignSeat for {player.Name} on {seat:GetFullName()}`)
	assignSeat(seat, board, tableModel, player, humanoid)
end

local function selectChoice(session: Session, choice: string, rainbowLocked: boolean, displayChoice: string?)
	session.Choice = choice
	session.DisplayChoice = displayChoice or choice
	session.RoundId = currentRoundId
	session.RainbowLocked = rainbowLocked
	network.FireClient(session.Player, "Selection", choice, rainbowLocked, session.DisplayChoice)
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
		network.FireClient(player, "Notice", "Please wait for the next round.")
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
		selectChoice(session, selectableColors[math.random(1, #selectableColors)], false, "Random")
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
	pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, NON_VIP_CHARACTER_GROUP)
	pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, VIP_SEAT_GROUP)
	PhysicsService:CollisionGroupSetCollidable(NON_VIP_CHARACTER_GROUP, VIP_SEAT_GROUP, false)

	local tablesFolder = followPath(workspace, config.TablesPath)
	for _, tableModel in tablesFolder:GetChildren() do
		if tableModel:IsA("Model") and (tableModel.Name == "Table" or tableModel.Name == "Table_VIP") then
			local isVIP = tableModel.Name == "Table_VIP"
			for _, chair in tableModel:GetChildren() do
				local index = string.match(chair.Name, "^Chair(%d+)$")
				if index then
					if chair:IsA("Model") then
						registerChairModel(chair)
					end
					local seat = chair:FindFirstChildWhichIsA("Seat", true)
					local board = tableModel:FindFirstChild(`GameBoard{index}`)
					if seat and board then
						local typedSeat = seat :: Seat
						if isVIP then
							typedSeat.CollisionGroup = VIP_SEAT_GROUP
							table.insert(seatConnections, typedSeat.Touched:Connect(function(touchedPart)
								guardVIPSeatTouch(typedSeat, touchedPart)
							end))
						end
						table.insert(seatConnections, typedSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
							onSeatChanged(typedSeat, board, tableModel, isVIP)
						end))
						if typedSeat.Occupant then
							task.defer(onSeatChanged, typedSeat, board, tableModel, isVIP)
						end
					end
				end
			end
		end
	end
	Players.PlayerAdded:Connect(bindVIPPlayer)
	for _, player in Players:GetPlayers() do
		bindVIPPlayer(player)
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
					network.FireClient(player, "Selection", session.Choice, session.RainbowLocked, session.DisplayChoice)
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
		roundCameraPlayers[player] = nil
		lastRequestAt[player] = nil
		lastPromptAt[player] = nil
		lastVIPPromptAt[player] = nil
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			vipTouchDebounce[humanoid] = nil
		end
		local characterConnection = vipCharacterConnections[player]
		if characterConnection then
			characterConnection:Disconnect()
			vipCharacterConnections[player] = nil
		end
		local attributeConnection = vipAttributeConnections[player]
		if attributeConnection then
			attributeConnection:Disconnect()
			vipAttributeConnections[player] = nil
		end
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

function TableService.SetDuelService(service: any)
	duelService = service
	for player, session in playerSessions do
		duelService.OnSeatAssigned(player, session.TableModel)
	end
end

function TableService.GetPlayerBoard(player: Player): Instance?
	local session = playerSessions[player]
	return if session then session.Board else nil
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
			session.DisplayChoice = nil
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

function TableService.SetRoundCameraActive(isActive: boolean)
	if isActive then
		if config.RoundCameraEnabled ~= true then
			return
		end
		for player, session in playerSessions do
			if session.RoundId == currentRoundId and session.Choice then
				roundCameraPlayers[player] = true
				network.FireClient(player, "RoundCamera", true)
			end
		end
		return
	end

	for player in roundCameraPlayers do
		roundCameraPlayers[player] = nil
		if player.Parent == Players then
			network.FireClient(player, "RoundCamera", false)
		end
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
	local duelOutcomes: { [Player]: { Matches: number } } = {}
	for player, session in playerSessions do
		if session.RoundId == currentRoundId and session.Choice then
			summary[session.Choice] = (summary[session.Choice] or 0) + 1
			local matchedDice = if session.RainbowLocked
				then 3
				else resultCounts[string.lower(session.Choice)] or 0
			local won = matchedDice > 0
			if duelService and duelService.IsActive(player) then
				duelOutcomes[player] = { Matches = matchedDice }
				if matchedDice >= 2 then
					local effectPlayed, effectProblem = BoardResultEffectService.Play(
						session.Board,
						session.Choice,
						math.min(matchedDice, 3)
					)
					if not effectPlayed then
						warn(`[ColorGame] Could not play duel {matchedDice}x board effect for {player.Name}: {effectProblem}`)
					end
				end
				continue
			end
			local vipMultiplier = if player:GetAttribute("IsVIP") == true
				then math.max(1, math.floor(tonumber(config.VIPWinMultiplier) or 2))
				else 1
			local reward = matchedDice * vipMultiplier
			if won then
				local recorded, earnedCoins, newStreak = dataManager.RecordWin(player, reward)
				if recorded and earnedCoins > 0 then
					network.FireClient(player, "CoinEarned", earnedCoins, newStreak)
				end
				if matchedDice >= 2 then
					local effectPlayed, effectProblem = BoardResultEffectService.Play(
						session.Board,
						session.Choice,
						math.min(matchedDice, 3)
					)
					if not effectPlayed then
						warn(`[ColorGame] Could not play {matchedDice}x board effect for {player.Name}: {effectProblem}`)
					end
				end
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
	if duelService then
		duelService.ResolveRound(currentRoundId, duelOutcomes)
	end

	return {
		Summary = summary,
		Winners = winners,
	}
end

return TableService
