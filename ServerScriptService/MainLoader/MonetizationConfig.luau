--!strict

local function offer(id: number, displayName: string)
	return table.freeze({
		Id = id,
		DisplayName = displayName,
	})
end

return table.freeze({
	DeveloperProducts = table.freeze({
		Rainbow = offer(3708268643, "Rainbow Pick"),
		StreakProtection = offer(3708268737, "Streak Protection"),
	}),

	GamePasses = table.freeze({
		-- Replace 0 with the game pass IDs from Creator Dashboard.
		AutoPick = offer(1947890983, "Auto Pick"),
		VIP = offer(1949294974, "VIP"),
	}),
})
