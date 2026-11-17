-- How grand each case's 3D opening is (CrateCinematic). Every case in the Crates window has its own profile; the
-- tiers climb with the case's price and best possible drop, so a better case always looks better:
--   1 Wooden chest      short and simple: a small drop, a rattle, a pop of dust and sparks
--   2 Standard, Golden  the full altar scene: islands, light pillars, rune shockwave, charge-up, a column of light
--                       (Golden adds a coin fountain)
--   3 Epic, Event       + lightning, the world dims while it charges, the camera pushes in, double shockwave,
--                       a title card
--   4 Royal (Robux)     + a slow descent on a golden beam with rings, letterbox bars, the camera circles the chest
--                       to a heartbeat, a slow-motion burst, god rays, fireworks and gold rain, a longer hold
-- On top of the tier, the best rarity rolled still colors the burst and adds its own flourishes (CrateCinematic).
local CrateTiers = {}

export type Tier = {
	level: number, -- 1..4
	style: string, -- CrateModel style
	color: Color3, -- the stage's own color (runes, pillars, trails)
	title: string?, -- a title card in the middle of the screen (tier 3+)
	islands: boolean, -- floating islands around the altar
	pillars: number, -- light pillars around the altar rim
	fallTime: number,
	lightning: boolean,
	chargeTime: number, -- before the best rarity adds its own
	burst: number, -- particle multiplier for the burst
	shockwaves: number,
	column: boolean, -- a column of light on the burst
	coins: boolean, -- a coin fountain on the burst
	dim: boolean, -- the world dims while it charges
	descent: boolean, -- comes down slowly on a beam instead of crashing in
	letterbox: boolean,
	orbit: boolean, -- the camera circles the chest while it charges
	slowmo: number?, -- time scale for a moment at the burst (lower = slower)
	godRays: boolean,
	fireworks: boolean,
	hold: number, -- seconds to look at the cards at the end
}

local BASE: Tier = {
	level = 2,
	style = "Standard",
	color = Color3.fromRGB(150, 70, 230),
	title = nil,
	islands = true,
	pillars = 8,
	fallTime = 0.85,
	lightning = false,
	chargeTime = 1.0,
	burst = 1,
	shockwaves = 1,
	column = true,
	coins = false,
	dim = false,
	descent = false,
	letterbox = false,
	orbit = false,
	slowmo = nil,
	godRays = false,
	fireworks = false,
	hold = 1.3,
}

local function tier(changes: { [string]: any }): Tier
	local out = table.clone(BASE)
	for key, value in changes do
		(out :: any)[key] = value
	end
	return out
end

CrateTiers.ByCase = {
	-- Chests (ChestsConfig ids)
	Basic = tier({
		level = 1,
		style = "Wooden",
		color = Color3.fromRGB(120, 200, 90),
		islands = false,
		pillars = 0,
		fallTime = 0.6,
		chargeTime = 0.6,
		burst = 0.5,
		shockwaves = 0,
		column = false,
		hold = 1.0,
	}),
	Golden = tier({
		style = "Golden",
		color = Color3.fromRGB(255, 190, 50),
		coins = true,
	}),
	Epic = tier({
		level = 3,
		style = "Standard",
		color = Color3.fromRGB(170, 80, 255),
		title = "EPIC CHEST",
		lightning = true,
		chargeTime = 1.3,
		burst = 1.4,
		shockwaves = 2,
		dim = true,
		hold = 1.5,
	}),
	Royal = tier({
		level = 4,
		style = "Royal",
		color = Color3.fromRGB(255, 200, 60),
		title = "ROYAL CHEST",
		lightning = true,
		chargeTime = 2.6,
		burst = 2.2,
		shockwaves = 3,
		coins = true,
		dim = true,
		descent = true,
		letterbox = true,
		orbit = true,
		slowmo = 0.2,
		godRays = true,
		fireworks = true,
		hold = 2.4,
	}),
	-- Summon banners (Banners ids)
	Standard = tier({}),
	Event = tier({
		level = 3,
		style = "Event",
		color = Color3.fromRGB(255, 90, 200),
		title = "EVENT SUMMON",
		lightning = true,
		chargeTime = 1.2,
		burst = 1.4,
		shockwaves = 2,
		dim = true,
		hold = 1.5,
	}),
} :: { [string]: Tier }

function CrateTiers.get(caseId: string): Tier?
	return CrateTiers.ByCase[caseId]
end

return CrateTiers
