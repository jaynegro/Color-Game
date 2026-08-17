return {
	Name = "deductcoins",
	Aliases = { "removecoins", "takecoins" },
	Description = "Permanently deducts Coins from a player's data without going below zero.",
	Group = "ColorGameAdmin",
	Args = {
		{
			Type = "player",
			Name = "player",
			Description = "Player losing the Coins.",
		},
		{
			Type = "integer",
			Name = "amount",
			Description = "Positive amount, up to 1,000,000,000.",
		},
	},
}
