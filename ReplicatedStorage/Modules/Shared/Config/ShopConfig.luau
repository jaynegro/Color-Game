--!strict

local function gamePassOffer(buttonTag: string, monetizationName: string, displayName: string, description: string)
	return table.freeze({
		Kind = "GamePass",
		ButtonTag = buttonTag,
		MonetizationName = monetizationName,
		DisplayName = displayName,
		Description = description,
	})
end

local function developerProductOffer(
	buttonTag: string,
	productName: string,
	displayName: string,
	price: number,
	description: string
)
	return table.freeze({
		Kind = "DeveloperProduct",
		ButtonTag = buttonTag,
		MonetizationName = productName,
		DisplayName = displayName,
		Price = math.max(0, math.floor(price)),
		Description = description,
	})
end

return table.freeze({
	CurrencySymbol = utf8.char(0xE002),
	Offers = table.freeze({
		StarterPack = gamePassOffer(
			"StarterPackBtnTag",
			"StarterPack",
			"Starter Pack",
			"250 Coins, Permanent Auto Pick, and Moonlith Chair"
		),
		VIP = gamePassOffer(
			"VIPBtnTag",
			"VIP",
			"VIP",
			"2x Wins, VIP Table access, and VIP perks"
		),
		Coins49 = developerProductOffer("Coins49BtnTag", "Coins49", "+49 Coins", 49, "Small coin bundle"),
		Coins299 = developerProductOffer("Coins299BtnTag", "Coins299", "+299 Coins", 299, "Medium coin bundle"),
		Coins599 = developerProductOffer("Coins599BtnTag", "Coins599", "+599 Coins", 599, "Large coin bundle"),
		Coins999 = developerProductOffer("Coins999BtnTag", "Coins999", "+999 Coins", 999, "Huge coin bundle"),
		Coins1499 = developerProductOffer("Coins1499BtnTag", "Coins1499", "+1499 Coins", 1499, "Mega coin bundle"),
	}),
})
