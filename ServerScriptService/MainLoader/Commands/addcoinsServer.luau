--!strict

local DataManager = require(script.Parent.Parent.Services.DataManager)

return function(_context: any, player: Player, amount: number): string
	local added, total = DataManager.AddCoins(player, amount)
	if not added then
		return "Error: Amount must be positive (maximum 1,000,000,000), and the player's data must be loaded."
	end
	return `Added {math.floor(amount)} Coins to {player.Name}. New total: {total}.`
end
