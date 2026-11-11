-- Global tuning knobs. Change numbers here to rebalance the game.
return {
	GameName = "Aura Packs",
	DataStoreName = "AuraPacks_v1",
	AutosaveInterval = 120,

	SetCompleteBonus = 0.25, -- +25% income for every set with all of its cards collected
	PackBulkSizes = { 1, 2, 3 }, -- how many packs anyone can open in one go
	PassBulkSize = 10, -- opening this many at once needs the "megaOpen" game pass
	CollectionBonusPerCard = 0.005, -- +0.5% income for every card (and variant) in the collection book
	BaseSlots = 4, -- active deck slots a new store starts with
	MaxSlots = 64,
	FuseCount = 3, -- copies of the same card needed to fuse into the next variant
	OfflineRate = 0.25, -- share of normal income earned while offline
	OfflineMaxSeconds = 4 * 60 * 60,
	AuraPullBonus = 10, -- instant aura on pulling an aura card = its aura/sec * this

	-- Auto Packer "auto-sell": 0 = keep everything, 1 = sell spare Commons, 2 = Commons and
	-- Uncommons, 3 = up to Rares. Only plain cards you already own 3+ copies of are sold.
	AutoSellMax = 3,

	GiftInterval = 15 * 60, -- seconds of play between free booster gifts
	GiftMax = 3, -- unclaimed gifts stop piling up here

	-- Game passes and developer products. Create each one on the Creator Dashboard and paste
	-- its id here; while an id is 0 the item shows as "coming soon" and cannot be bought.
	Monetization = {
		ExtraSlots = 8,
		VipLuck = 2,
		LuckyLuck = 5,
		ExtraVaultSlots = 2,
		PotionLuck = 10,

		-- Game passes: bought once, kept forever. "robux" is only a suggested price; the real
		-- price is whatever you set on the Creator Dashboard.
		PassOrder = { "doubleCash", "doubleAura", "megaOpen", "autoCollect", "extraSlots", "bigVault", "lucky", "vip" },
		Passes = {
			doubleCash = { id = 0, robux = 399, name = "2x Cash", text = "Your deck earns double cash, forever." },
			doubleAura = { id = 0, robux = 299, name = "2x Aura", text = "Your cards radiate double aura, forever." },
			autoCollect = { id = 0, robux = 149, name = "Auto Collector", text = "Cash goes straight to your balance and survives rebirth." },
			extraSlots = { id = 0, robux = 249, name = "+8 Deck Slots", text = "Eight extra deck slots from the start of every run." },
			bigVault = { id = 0, robux = 199, name = "Bigger Vault", text = "Two extra vault slots: carry more cards through every rebirth." },
			lucky = { id = 0, robux = 349, name = "Lucky Clover", text = "+5 luck, forever." },
			megaOpen = { id = 0, robux = 199, name = "10x Pack Opening", text = "Open 10 packs at once with the x10 button in the Pack Shop." },
			vip = { id = 0, robux = 99, name = "VIP", text = "A crown on your store sign and +2 luck." },
		},

		-- Developer products: can be bought again and again.
		--   kind = "aura": adds aura.
		--   kind = "luck": +PotionLuck luck for `minutes`.
		--   kind = "cash": double cash for `minutes`.
		--   kind = "warp": `seconds` of your current income at once (up to the wallet cap).
		-- random = true marks products that hand out cash, which buys random packs; those are
		-- hidden where paid random items are restricted.
		ProductOrder = { "luckPotion", "cashPotion", "timeWarp", "auraSmall", "auraBig", "auraHuge" },
		Products = {
			luckPotion = { id = 0, robux = 49, kind = "luck", minutes = 30, name = "Luck Potion", text = "+10 luck for 30 minutes. Stacks up in time if you buy more." },
			cashPotion = { id = 0, robux = 49, kind = "cash", minutes = 30, name = "Cash Potion", text = "Double cash for 30 minutes. Stacks up in time if you buy more." },
			timeWarp = { id = 0, robux = 79, kind = "warp", seconds = 3600, random = true, name = "Time Warp", text = "One hour of your deck's income, right now." },
			auraSmall = { id = 0, robux = 49, kind = "aura", aura = 5000, name = "Aura Bundle", text = "+5,000 aura." },
			auraBig = { id = 0, robux = 199, kind = "aura", aura = 50000, name = "Aura Chest", text = "+50,000 aura." },
			auraHuge = { id = 0, robux = 799, kind = "aura", aura = 500000, name = "Aura Vault", text = "+500,000 aura." },
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
