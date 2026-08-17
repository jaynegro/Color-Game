return {
	Name = "unequipskin",
	Aliases = { "unequip" },
	Description = "Uses the Default skin for a category for the rest of this server session.",
	Group = "ColorGameAdmin",
	Args = {
		{
			Type = "string",
			Name = "category",
			Description = "Chair, Table, or Map.",
		},
	},
}
