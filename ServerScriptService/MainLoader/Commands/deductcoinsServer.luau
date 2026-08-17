--!strict

local DataManager = require(script.Parent.Parent.Services.DataManager)

return function(_context: any, player: Player, amount: number): string
	local success, total, deducted = DataManager.DeductCoins(player, amount)
	if not success then
		return "Error: Amount must be positive (maximum 1,000,000,000), and the player's data must be loaded."
	end
	return `Deducted {deducted} Coins from {player.Name}. New total: {total}.`
end
