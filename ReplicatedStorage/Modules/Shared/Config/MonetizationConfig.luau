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
		RemoveAllChairs = offer(3708415122, "Remove All Chairs"),
		Coins49 = offer(3708407358, "+49 Coins"),
		Coins299 = offer(3708407463, "+299 Coins"),
		Coins599 = offer(3708407898, "+599 Coins"),
		Coins999 = offer(3708407974, "+999 Coins"),
		Coins1499 = offer(3708408029, "+1499 Coins"),
	}),

	GamePasses = table.freeze({
		-- Replace 0 with the game pass IDs from Creator Dashboard.
		StarterPack = offer(1949253233, "Starter Pack"),
		AutoPick = offer(1947890983, "Auto Pick"),
		VIP = offer(1949294974, "VIP"),
		BeachMap = offer(0, "Beach Map"),
	}),
})
