--!strict

return table.freeze({
	PickingDuration = 10,
	DiceSpawnAnchorDuration = 1,
	DiceSpawnClearance = 0.03,
	DiceImpactCooldown = 0.2,
	SettlingDuration = 3,
	ResultDuration = 2,
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
	-- Catalog emotes cannot play on NPCs. Upload the desired motion as an
	-- Animation owned by the experience owner/group, then place its ID here.
	LeaderboardDummyAnimationId = 86874512753435,
	SeatLockDuration = 3,
	VIPReseatBlockDuration = 0.75,

	MachinePath = { "ScriptableParts", "Machine" },
	TablesPath = { "ScriptableParts", "Tables" },
	DiceAssetPath = { "Assets", "Dices", "BasicDice" },
	AnimationsPath = { "Assets", "Animations" },

	-- The validator accepts any correctly named <Color>HB on BasicDice.
	-- These are the buttons accepted from a GameBoard.
	Colors = table.freeze({ "Blue", "Green", "Pink", "Red", "White", "Yellow" }),
	BoardControls = table.freeze({ "Orange", "Rainbow", "Random" }),
})
