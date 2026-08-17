--!strict

-- Put numeric Roblox UserIds here, not usernames.
-- Admins are automatically hidden from every global leaderboard.
local ADMIN_WHITELIST = table.freeze({
	7097830180,
})

-- Use this for non-admin accounts that should also be hidden from every
-- global leaderboard (test accounts, banned accounts, bots, and so on).
local LEADERBOARD_BLACKLIST = table.freeze({
	7097830180,
})

-- Players listed here keep their other data, but their Wins and Coins are
-- reset to zero every time their profile loads after joining.
local BALANCE_RESET_BLACKLIST = table.freeze({
	7097830180,
})

local adminSet: { [number]: boolean } = {}
local leaderboardBlacklistSet: { [number]: boolean } = {}
local balanceResetBlacklistSet: { [number]: boolean } = {}

for _, userId in ADMIN_WHITELIST do
	if type(userId) == "number" and userId > 0 then
		adminSet[math.floor(userId)] = true
	end
end

for _, userId in LEADERBOARD_BLACKLIST do
	if type(userId) == "number" and userId > 0 then
		leaderboardBlacklistSet[math.floor(userId)] = true
	end
end

for _, userId in BALANCE_RESET_BLACKLIST do
	if type(userId) == "number" and userId > 0 then
		balanceResetBlacklistSet[math.floor(userId)] = true
	end
end

return table.freeze({
	AdminWhitelist = ADMIN_WHITELIST,
	LeaderboardBlacklist = LEADERBOARD_BLACKLIST,
	BalanceResetBlacklist = BALANCE_RESET_BLACKLIST,

	IsAdmin = function(userId: number): boolean
		return adminSet[math.floor(userId)] == true
	end,

	IsLeaderboardExcluded = function(userId: number): boolean
		userId = math.floor(userId)
		return adminSet[userId] == true or leaderboardBlacklistSet[userId] == true
	end,

	ShouldResetBalanceOnJoin = function(userId: number): boolean
		return balanceResetBlacklistSet[math.floor(userId)] == true
	end,
})
