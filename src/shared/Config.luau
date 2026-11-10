-- Global tuning knobs. Change numbers here to rebalance the game.
return {
	GameName = "Aura Packs",
	DataStoreName = "AuraPacks_v1",
	AutosaveInterval = 120,

	CardsPerPack = 3,
	BaseSlots = 4, -- display stands a new store starts with
	MaxSlots = 16,
	SellMultiplier = 20, -- sell price = card income per second * this
	AuraPullBonus = 30, -- instant aura on pulling an aura card = its aura/sec * this

	PlotCount = 8, -- set the experience's max players to this
	PlotSize = 64,

	Stealing = {
		Enabled = true,
		HoldTime = 2, -- seconds to hold the prompt on a card
		CarrySpeed = 11, -- thief walk speed while carrying (default is 16)
		CatchDistance = 8, -- owner gets the card back by getting this close to the thief
		JoinShield = 120, -- seconds of protection when you join
		ShieldTime = 45, -- seconds the lock pad protects the store
		ShieldCooldown = 60, -- seconds before the lock pad can be used again
	},
}
