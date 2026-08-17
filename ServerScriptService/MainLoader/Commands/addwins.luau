return {
	Name = "addwins",
	Aliases = { "givewins" },
	Description = "Permanently adds Wins to a player's data.",
	Group = "ColorGameAdmin",
	Args = {
		{
			Type = "player",
			Name = "player",
			Description = "Player receiving the Wins.",
		},
		{
			Type = "integer",
			Name = "amount",
			Description = "Positive amount, up to 1,000,000,000.",
		},
	},
}
