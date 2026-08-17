return {
	Name = "deductwins",
	Aliases = { "removewins", "takewins" },
	Description = "Permanently deducts Wins from a player's data without going below zero.",
	Group = "ColorGameAdmin",
	Args = {
		{
			Type = "player",
			Name = "player",
			Description = "Player losing the Wins.",
		},
		{
			Type = "integer",
			Name = "amount",
			Description = "Positive amount, up to 1,000,000,000.",
		},
	},
}
