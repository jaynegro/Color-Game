--!strict

-- Add/edit skin prices, rarity, icons, and asset names here.
local function item(displayName: string, assetName: string, rarity: number, currency: string, price: number, icon: string?, gamePassName: string?)
	return table.freeze({
		DisplayName = displayName,
		AssetName = assetName,
		Rarity = rarity,
		Currency = currency,
		Price = price,
		Icon = icon or "",
		GamePassName = gamePassName,
	})
end

local ICONS = table.freeze({
	DefaultChair = "rbxassetid://85577666934099", -- REPLACE: Default Chair icon
	AmethystThroneChair = "rbxassetid://128820467753627", -- REPLACE: Amethyst Throne icon
	JellyCandyChair = "rbxassetid://0102614972902239", -- REPLACE: Jelly Candy icon
	MoonlithChair = "rbxassetid://82375988329661", -- REPLACE: Moonlith Chair icon
	MetalicChair = "rbxassetid://121881493090366", -- REPLACE: Metalic Chair icon
	NeonGodChair = "rbxassetid://71366171209480", -- REPLACE: Neon God Chair icon
	RSGCChair = "rbxassetid://104724524919219", -- REPLACE: RSGC Chair icon
	DefaultTable = "rbxassetid://137698642406862", -- REPLACE: Default Table icon
	CelestialDreamTable = "rbxassetid://123695743995263", -- REPLACE: Celestial Dream icon
	BigMetalTable = "rbxassetid://138543252947678", -- REPLACE: Big Metal icon
	SkyborneRoyalTable = "rbxassetid://116808393335268", -- REPLACE: Skyborne Royal icon
	SkyboundTimberTable = "rbxassetid://83399969397087", -- REPLACE: Skybound Timber icon
	DefaultMap = "rbxassetid://0", -- REPLACE: Default Map icon
	BeachMap = "rbxassetid://0", -- REPLACE: Beach Map icon
})

return table.freeze({
	CurrencyIcons = table.freeze({
		Coins = "rbxassetid://102313496548661", -- Example: rbxassetid://123
		Wins = "rbxassetid://125856476037267",
		Robux = "rbxassetid://107045214921758", -- Example: 456
	}),

	CategoryOrder = table.freeze({ "Chair", "Table", "Map" }),
	Categories = table.freeze({
		Chair = table.freeze({
			DisplayName = "Chair Skins",
			AssetFolder = "Chairs",
			Items = table.freeze({
				Default = item("Default Chair", "Default", 0, "Free", 0, ICONS.DefaultChair),
				Metalic = item("Metalic", "Metalic", 1, "Coins", 50, ICONS.MetalicChair),
				Neon_God = item("Neon God", "Neon_God", 2, "Coins", 200, ICONS.NeonGodChair),
				Jelly_Candy = item("Jelly Candy", "Jelly_Candy", 3, "Coins", 500, ICONS.JellyCandyChair),
				RSGC = item("RSGC", "RSGC", 4, "Coins", 5000, ICONS.RSGCChair),
				Moonlith = item("Moonlith", "Moonlith", 5, "Coins", 500, ICONS.MoonlithChair, "StarterPack"),
				Amethyst_Throne = item("Amethyst Throne", "Amethyst_Throne", 6, "Coins", 700, ICONS.AmethystThroneChair),
			}),
		}),
		Table = table.freeze({
			DisplayName = "Table Skins",
			AssetFolder = "Table",
			Items = table.freeze({
				Default = item("Default Table", "Default", 0, "Free", 0, ICONS.DefaultTable),
				Big_Metal = item("Big Metal", "Big_Metal", 1, "Wins", 20, ICONS.BigMetalTable),
				Skyborne_Royal = item("Skyborne Royal", "Skyborne_Royal", 2, "Wins", 100, ICONS.SkyborneRoyalTable),
				Skybound_Timber = item("Skybound Timber", "Skybound_Timber", 3, "Wins", 300, ICONS.SkyboundTimberTable),
				Celestial_Dream = item("Celestial Dream", "Celestial_Dream", 4, "Wins", 500, ICONS.CelestialDreamTable),
			}),
		}),
		Map = table.freeze({
			DisplayName = "Map Skins",
			AssetFolder = "Map",
			Items = table.freeze({
				Default = item("Default Map", "Default", 0, "Free", 0, ICONS.DefaultMap),
				Beach = item("Beach Map", "Beach", 1, "Robux", 0, ICONS.BeachMap, "BeachMap"),
			}),
		}),
	}),
})
