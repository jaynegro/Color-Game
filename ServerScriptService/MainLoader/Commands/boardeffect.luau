return {
	Name = "boardeffect",
	Aliases = { "fakeboardeffect", "testboardeffect" },
	Description = "Plays a fake double or triple effect on your occupied GameBoard.",
	Group = "ColorGameAdmin",
	Args = {
		{
			Type = "string",
			Name = "color",
			Description = "GameBoard color, such as Blue.",
		},
		{
			Type = "integer",
			Name = "multiplier",
			Description = "Use 2 for Double or 3 for Triple.",
		},
	},
}
