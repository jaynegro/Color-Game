--!strict

return table.freeze({
	PickingDuration = 10,
	DayCycleDuration = 10 * 60,
	RagdollEnabled = true,
	VIPWinMultiplier = 2,
	RoundCameraEnabled = true,
	DuelTargetScore = 20,
	DuelForfeitThreshold = 10,
	DuelInviteDuration = 5,
	DiceSpawnAnchorDuration = 1,
	DiceSpawnClearance = 0.03,
	DiceSpawnTransitionDuration = 0.35,
	DiceDespawnTransitionDuration = 0.35,
	DiceTransitionMinScale = 0.12,
	DiceImpactCooldown = 0.2,
	StreakCoinRewards = table.freeze({ 5, 10, 20, 40, 80 }),
	GroupReward = table.freeze({
		GroupId = 682016348,
		Category = "Chair",
		ItemId = "Jelly_Candy",
		PromptPath = table.freeze({ "ScriptableParts", "Misc", "Attachment", "ProximityPrompt" }),
	}),
	SettlingDuration = 3,
	ResultDuration = 3,
	AnimationTimeout = 12,
	SmashActivationDelay = 1,
	SmashRagdollDuration = 2.5,
	PusherDelay = 0.16,
	PusherTravelDuration = 0.3,
	PusherStartPosition = Vector3.new(90.681, 20.006, 70.916),
	PusherEndPosition = Vector3.new(84.205, 20.006, 70.916),

	DataStoreName = "ColorGame_PlayerData_v1",
	LeaderboardRefreshInterval = 120,
	LeaderboardSize = 50,
	TopWinsStoreName = "ColorGame_TopWins_v1",
	TopTimeStoreName = "ColorGame_TopTime_v1",
	TopStreakStoreName = "ColorGame_TopStreak_v1",
	TopRankStoreName = "ColorGame_TopRank_v1",
	-- Catalog emotes cannot play on NPCs. Upload the desired motion as an
	-- Animation owned by the experience owner/group, then place its ID here.
	LeaderboardDummyAnimationId = 86874512753435,
	SeatLockDuration = 3,

	MachinePath = { "ScriptableParts", "Machine" },
	TablesPath = { "ScriptableParts", "Tables" },
	DiceAssetPath = { "Assets", "Dices", "BasicDice" },
	AnimationsPath = { "Assets", "Animations" },

	-- The validator accepts any correctly named <Color>HB on BasicDice.
	-- These are the buttons accepted from a GameBoard.
	Colors = table.freeze({ "Blue", "Green", "Pink", "Red", "White", "Yellow" }),
	BoardControls = table.freeze({ "Orange", "Rainbow", "Random" }),
})
