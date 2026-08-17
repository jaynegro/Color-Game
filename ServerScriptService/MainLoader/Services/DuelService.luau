--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DuelService = {}

type DuelOutcome = {
	Matches: number,
}

type Invite = {
	Sender: Player,
	Receiver: Player,
	TableModel: Model,
	Token: {},
}

type Duel = {
	Players: { Player },
	TableModel: Model,
	Scores: { [Player]: number },
	Streaks: { [Player]: number },
	LastRoundId: number?,
}

local config: any
local network: any
local dataManager: any
local tableService: any
local pvpIndicatorTemplate: Attachment?
local seatedTables: { [Player]: Model } = {}
local sentInvites: { [Player]: Invite } = {}
local receivedInvites: { [Player]: Invite } = {}
local duelsByPlayer: { [Player]: Duel } = {}
local lastInviteAt: { [Player]: number } = {}
local indicatorTokens: { [Model]: number } = {}

local function notify(player: Player, text: string, kind: string?)
	if player.Parent == Players then
		network.FireClient(player, "Notify", text, kind or "Warning")
	end
end

local function sendLobby(player: Player, status: string, opponent: Player?)
	if player.Parent == Players then
		network.FireClient(player, "DuelLobby", status, if opponent then opponent.UserId else 0)
	end
end

local function playersAtTable(tableModel: Model): { Player }
	local result = {}
	for player, seatedTable in seatedTables do
		if seatedTable == tableModel and player.Parent == Players then
			table.insert(result, player)
		end
	end
	table.sort(result, function(a, b)
		return a.UserId < b.UserId
	end)
	return result
end

local function opponentAtTable(player: Player): Player?
	local tableModel = seatedTables[player]
	if not tableModel then
		return nil
	end
	for _, candidate in playersAtTable(tableModel) do
		if candidate ~= player then
			return candidate
		end
	end
	return nil
end

local function refreshLobby(tableModel: Model)
	local players = playersAtTable(tableModel)
	for _, player in players do
		if duelsByPlayer[player] then
			sendLobby(player, "Hidden")
		elseif sentInvites[player] then
			sendLobby(player, "Outgoing", sentInvites[player].Receiver)
		elseif receivedInvites[player] then
			sendLobby(player, "Incoming", receivedInvites[player].Sender)
		elseif #players == 2 then
			local opponent = if players[1] == player then players[2] else players[1]
			sendLobby(player, "Available", opponent)
		else
			sendLobby(player, "Hidden")
		end
	end
end

local function getTableBasePart(tableModel: Model): BasePart?
	if tableModel.PrimaryPart and tableModel.PrimaryPart:IsA("BasePart") then
		return tableModel.PrimaryPart
	end
	return tableModel:FindFirstChildWhichIsA("BasePart", true)
end

local function clearPvpIndicator(tableModel: Model)
	indicatorTokens[tableModel] = (indicatorTokens[tableModel] or 0) + 1
	for _, descendant in tableModel:GetDescendants() do
		if descendant.Name == "PvpIndicator" and (descendant:IsA("Attachment") or descendant:IsA("BillboardGui")) then
			descendant:Destroy()
		end
	end
end

local function animatePvpIndicator(tableModel: Model, clone: Attachment, token: number)
	local billboard = clone:FindFirstChild("BillboardGui")
	if not billboard or not billboard:IsA("BillboardGui") then
		clone:Destroy()
		return
	end

	local rightSword = billboard:FindFirstChild("RightSword")
	local leftSword = billboard:FindFirstChild("LeftSword")
	if not rightSword or not rightSword:IsA("ImageLabel") or not leftSword or not leftSword:IsA("ImageLabel") then
		clone:Destroy()
		return
	end

	rightSword.Rotation = -83
	leftSword.Rotation = -4

	task.spawn(function()
		local openInfo = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local closeInfo = TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		while clone.Parent and indicatorTokens[tableModel] == token do
			local openRight = TweenService:Create(rightSword, openInfo, { Rotation = -25 })
			local openLeft = TweenService:Create(leftSword, openInfo, { Rotation = -64 })
			openRight:Play()
			openLeft:Play()
			task.wait(0.34)
			if not clone.Parent or indicatorTokens[tableModel] ~= token then
				break
			end

			local closeRight = TweenService:Create(rightSword, closeInfo, { Rotation = -83 })
			local closeLeft = TweenService:Create(leftSword, closeInfo, { Rotation = -4 })
			closeRight:Play()
			closeLeft:Play()
			task.wait(0.30)
		end
	end)
end

local function setPvpIndicator(tableModel: Model, active: boolean)
	clearPvpIndicator(tableModel)
	if not active then
		return
	end

	local template = pvpIndicatorTemplate
	if not template then
		warn("[ColorGame] Missing ReplicatedStorage.Assets.UI.PvpIndicator.")
		return
	end

	local basePart = getTableBasePart(tableModel)
	if not basePart then
		warn(`[ColorGame] Could not find a BasePart to attach PvP indicator on {tableModel:GetFullName()}.`)
		return
	end

	local token = indicatorTokens[tableModel]
	local clone = template:Clone()
	clone.Name = "PvpIndicator"
	clone.Visible = true
	clone.Parent = basePart
	animatePvpIndicator(tableModel, clone, token)
end

local function clearInvite(invite: Invite)
	if sentInvites[invite.Sender] == invite then
		sentInvites[invite.Sender] = nil
	end
	if receivedInvites[invite.Receiver] == invite then
		receivedInvites[invite.Receiver] = nil
	end
end

local function cancelInvite(invite: Invite, message: string?)
	clearInvite(invite)
	if message then
		notify(invite.Sender, message, "Warning")
		notify(invite.Receiver, message, "Warning")
	end
	refreshLobby(invite.TableModel)
end

local function otherPlayer(duel: Duel, player: Player): Player?
	if duel.Players[1] == player then
		return duel.Players[2]
	elseif duel.Players[2] == player then
		return duel.Players[1]
	end
	return nil
end

local function sendDuelState(player: Player, duel: Duel)
	local opponent = otherPlayer(duel, player)
	if not opponent or player.Parent ~= Players then
		return
	end
	network.FireClient(
		player,
		"DuelState",
		true,
		opponent.UserId,
		duel.Scores[player] or 0,
		duel.Scores[opponent] or 0,
		duel.Streaks[player] or 0,
		duel.Streaks[opponent] or 0,
		math.max(1, math.floor(tonumber(config.DuelTargetScore) or 20))
	)
end

local function broadcastDuelState(duel: Duel)
	for _, player in duel.Players do
		sendDuelState(player, duel)
	end
end

local function finishDuel(duel: Duel, winner: Player?, reason: string)
	setPvpIndicator(duel.TableModel, false)
	for _, player in duel.Players do
		if duelsByPlayer[player] == duel then
			duelsByPlayer[player] = nil
		end
		if player.Parent == Players then
			network.FireClient(player, "DuelState", false)
		end
	end

	if winner then
		local awarded, newRank = dataManager.AwardDuelRank(winner)
		dataManager.AddWins(winner, 1)
		if awarded then
			notify(winner, `You won the duel! Duel Rank: {newRank}.`, "Success")
		end
		local loser = otherPlayer(duel, winner)
		if loser then
			notify(loser, `{winner.DisplayName} won the duel.`, "Error")
		end
	else
		for _, player in duel.Players do
			notify(player, reason, "Warning")
		end
	end

	refreshLobby(duel.TableModel)
end

local function startDuel(invite: Invite)
	clearInvite(invite)
	local sender = invite.Sender
	local receiver = invite.Receiver
	local duel: Duel = {
		Players = { sender, receiver },
		TableModel = invite.TableModel,
		Scores = { [sender] = 0, [receiver] = 0 },
		Streaks = { [sender] = 0, [receiver] = 0 },
		LastRoundId = nil,
	}
	duelsByPlayer[sender] = duel
	duelsByPlayer[receiver] = duel
	setPvpIndicator(invite.TableModel, true)
	refreshLobby(invite.TableModel)
	broadcastDuelState(duel)
	notify(sender, `Duel accepted! First to {config.DuelTargetScore or 20}.`, "Success")
	notify(receiver, `Duel accepted! First to {config.DuelTargetScore or 20}.`, "Success")
end

local function handleInvite(player: Player)
	local opponent = opponentAtTable(player)
	local tableModel = seatedTables[player]
	if not opponent or not tableModel then
		notify(player, "Sit beside another player to send a duel invitation.", "Warning")
		return
	end
	if duelsByPlayer[player] or duelsByPlayer[opponent] then
		notify(player, "A duel is already active at this table.", "Warning")
		return
	end
	if sentInvites[player] or receivedInvites[player] or sentInvites[opponent] or receivedInvites[opponent] then
		notify(player, "A duel invitation is already pending.", "Warning")
		return
	end
	local now = os.clock()
	if now - (lastInviteAt[player] or 0) < 1 then
		return
	end
	lastInviteAt[player] = now

	local invite: Invite = {
		Sender = player,
		Receiver = opponent,
		TableModel = tableModel,
		Token = {},
	}
	sentInvites[player] = invite
	receivedInvites[opponent] = invite
	refreshLobby(tableModel)
	notify(player, `Duel invitation sent to {opponent.DisplayName}.`, "Success")
	notify(opponent, `{player.DisplayName} invited you to a duel.`, "Warning")

	local inviteDuration = math.max(1, tonumber(config.DuelInviteDuration) or 5)
	task.delay(inviteDuration, function()
		if sentInvites[player] ~= invite or receivedInvites[opponent] ~= invite then
			return
		end
		cancelInvite(invite, "Duel invitation was not accepted.")
	end)
end

local function handleAccept(player: Player)
	local invite = receivedInvites[player]
	if not invite then
		notify(player, "This duel invitation is no longer available.", "Warning")
		return
	end
	if seatedTables[player] ~= invite.TableModel or seatedTables[invite.Sender] ~= invite.TableModel
		or opponentAtTable(player) ~= invite.Sender then
		cancelInvite(invite, "Duel invitation cancelled because a player left the table.")
		return
	end
	if duelsByPlayer[player] or duelsByPlayer[invite.Sender] then
		cancelInvite(invite, "Duel invitation is no longer available.")
		return
	end
	startDuel(invite)
end

function DuelService.Init(gameConfig: any, networkService: any, playerDataManager: any, playerTableService: any)
	config = gameConfig
	network = networkService
	dataManager = playerDataManager
	tableService = playerTableService
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local uiFolder = assets:WaitForChild("UI")
	local indicator = uiFolder:FindFirstChild("PvpIndicator")
	if indicator and indicator:IsA("Attachment") then
		pvpIndicatorTemplate = indicator
	else
		warn("[ColorGame] ReplicatedStorage.Assets.UI.PvpIndicator must be an Attachment.")
	end

	local event = network.Event :: RemoteEvent
	event.OnServerEvent:Connect(function(player, action)
		if action == "DuelInvite" then
			handleInvite(player)
		elseif action == "DuelAccept" then
			handleAccept(player)
		elseif action == "DuelReady" then
			local duel = duelsByPlayer[player]
			if duel then
				sendDuelState(player, duel)
				return
			end
			local tableModel = seatedTables[player]
			if tableModel then
				refreshLobby(tableModel)
			else
				sendLobby(player, "Hidden")
			end
		end
	end)
end

function DuelService.OnSeatAssigned(player: Player, tableModel: Model)
	seatedTables[player] = tableModel
	refreshLobby(tableModel)
end

function DuelService.OnSeatReleased(player: Player, tableModel: Model)
	if seatedTables[player] == tableModel then
		seatedTables[player] = nil
	end
	sendLobby(player, "Hidden")

	local invite = sentInvites[player] or receivedInvites[player]
	if invite then
		cancelInvite(invite, "Duel invitation cancelled because a player left the table.")
	end

	local duel = duelsByPlayer[player]
	if duel then
		local remaining = otherPlayer(duel, player)
		local threshold = math.max(0, math.floor(tonumber(config.DuelForfeitThreshold) or 10))
		local highScore = math.max(duel.Scores[duel.Players[1]] or 0, duel.Scores[duel.Players[2]] or 0)
		if remaining and highScore > threshold then
			finishDuel(duel, remaining, "")
		else
			finishDuel(duel, nil, "Duel interrupted. No Rank was awarded.")
		end
	end
	refreshLobby(tableModel)
end

function DuelService.IsActive(player: Player): boolean
	return duelsByPlayer[player] ~= nil
end

function DuelService.ResolveRound(roundId: number, outcomes: { [Player]: DuelOutcome })
	local handled: { [Duel]: boolean } = {}
	local target = math.max(1, math.floor(tonumber(config.DuelTargetScore) or 20))
	for _, duel in duelsByPlayer do
		if handled[duel] or duel.LastRoundId == roundId then
			continue
		end
		handled[duel] = true
		duel.LastRoundId = roundId

		for _, player in duel.Players do
			local outcome = outcomes[player]
			local matches = if outcome then math.clamp(math.floor(outcome.Matches), 0, 3) else 0
			if matches > 0 then
				local streak = (duel.Streaks[player] or 0) + 1
				duel.Streaks[player] = streak
				duel.Scores[player] = (duel.Scores[player] or 0) + matches * streak
			else
				duel.Streaks[player] = 0
			end
		end

		broadcastDuelState(duel)
		local player1 = duel.Players[1]
		local player2 = duel.Players[2]
		local score1 = duel.Scores[player1] or 0
		local score2 = duel.Scores[player2] or 0
		if (score1 >= target or score2 >= target) and score1 ~= score2 then
			finishDuel(duel, if score1 > score2 then player1 else player2, "")
		end
	end
end

return DuelService
