-- Global tuning knobs. Change numbers here to rebalance the game.
return {
	GameName = "Aura Packs",
	DataStoreName = "AuraPacks_v1",
	AutosaveInterval = 120,

	SetCompleteBonus = 0.25, -- +25% income for every set with all of its cards collected
	PackBulkSizes = { 1, 3, 10 }, -- how many packs can be opened in one go
	CollectionBonusPerCard = 0.005, -- +0.5% income for every card (and variant) in the collection book
	BaseSlots = 4, -- active deck slots a new store starts with
	MaxSlots = 64,
	FuseCount = 3, -- copies of the same card needed to fuse into the next variant
	OfflineRate = 0.25, -- share of normal income earned while offline
	OfflineMaxSeconds = 4 * 60 * 60,
	AuraPullBonus = 30, -- instant aura on pulling an aura card = its aura/sec * this

	GiftInterval = 15 * 60, -- seconds of play between free booster gifts
	GiftMax = 3, -- unclaimed gifts stop piling up here

	-- Game passes and developer products. Create each one on the Creator Dashboard and paste
	-- its id here; while an id is 0 the item shows as "coming soon" and cannot be bought.
	Monetization = {
		ExtraSlots = 8,
		VipLuck = 2,
		PassOrder = { "doubleCash", "autoCollect", "extraSlots", "vip" },
		Passes = {
			doubleCash = { id = 0, name = "2x Cash", text = "Your deck earns double cash, forever." },
			autoCollect = { id = 0, name = "Auto Collector", text = "Cash goes straight to your balance and survives rebirth." },
			extraSlots = { id = 0, name = "+8 Deck Slots", text = "Eight extra deck slots from the start of every run." },
			vip = { id = 0, name = "VIP", text = "A crown on your store sign and +2 luck." },
		},
		ProductOrder = { "auraSmall", "auraBig" },
		Products = {
			auraSmall = { id = 0, name = "Aura Bundle", aura = 5000 },
			auraBig = { id = 0, name = "Aura Chest", aura = 50000 },
		},
	},

	-- Server-wide lucky event: everyone gets bonus luck levels for a while.
	LuckEvent = { Interval = 20 * 60, Duration = 5 * 60, BonusLevels = 5 },
	BattleCooldown = 5, -- seconds between tower battles

	-- Built-in Roblox sounds. Swap for your own "rbxassetid://..." ids; "" turns a sound off.
	Sounds = {
		click = "rbxasset://sounds/clickfast.wav",
		flip = "rbxasset://sounds/electronicpingshort.wav",
		bigPull = "rbxasset://sounds/victory.wav",
		hit = "rbxasset://sounds/swordslash.wav",
	},

	PlotCount = 8, -- set the experience's max players to this
	PlotSize = 64,

	Market = { MaxListings = 8, MaxPrice = 1e15 },
	Trade = { MaxCards = 6, RequestTimeout = 60 },
}
