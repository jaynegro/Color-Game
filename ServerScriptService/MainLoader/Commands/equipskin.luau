return {
	Name = "equipskin",
	Aliases = { "equip" },
	Description = "Session-only admin equip bypass for a Chair, Table, or Map skin.",
	Group = "ColorGameAdmin",
	Args = {
		{
			Type = "string",
			Name = "category",
			Description = "Chair, Table, or Map.",
		},
		{
			Type = "string",
			Name = "skin",
			Description = "Catalog/asset name, such as Amethyst_Throne.",
		},
	},
}
