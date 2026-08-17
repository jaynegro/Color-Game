return {
	Name = "addcoins",
	Aliases = { "givecoins" },
	Description = "Permanently adds Coins to a player's data.",
	Group = "ColorGameAdmin",
	Args = {
		{
			Type = "player",
			Name = "player",
			Description = "Player receiving the Coins.",
		},
		{
			Type = "integer",
			Name = "amount",
			Description = "Positive amount, up to 1,000,000,000.",
		},
	},
}
