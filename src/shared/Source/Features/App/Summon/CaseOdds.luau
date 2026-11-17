-- Tower odds of any case in one shape (Banners.RarityOdds, best rarity first), so the Crates list cards and
-- the case menu show the same numbers. Banners: Banners.Odds. Chests: the rarity's chance split evenly
-- between its towers, the way ChestService rolls.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowersConfig = require(ReplicatedStorage.Shared.Features.Services.TowersServices.towersConfig)
local Banners = require(ReplicatedStorage.Shared.Features.Services.Summon.Banners)
local ChestsConfig = require(ReplicatedStorage.Shared.Features.Services.Chests.ChestsConfig)

local CaseOdds = {}

-- "55%", "1.8%", "0.07%".
function CaseOdds.percent(chance: number): string
	local value = chance * 100
	if value >= 10 then
		return (string.format("%.1f%%", value):gsub("%.0%%$", "%%"))
	end
	return (string.format("%.2f%%", value):gsub("0+%%$", "%%"):gsub("%.%%$", "%%"))
end

function CaseOdds.chest(chest: ChestsConfig.Chest): { Banners.RarityOdds }
	local byRarity: { [string]: { string } } = {}
	for towerId, config in TowersConfig do
		byRarity[config.Rarity] = byRarity[config.Rarity] or {}
		table.insert(byRarity[config.Rarity], towerId)
	end
	local chances = ChestsConfig.TowerOdds(chest, function(rarity)
		return byRarity[rarity] ~= nil
	end)
	local odds = {}
	for index = #Banners.RarityOrder, 1, -1 do
		local rarity = Banners.RarityOrder[index]
		local chance = chances[rarity]
		local towers = byRarity[rarity]
		if chance and towers then
			table.sort(towers)
			local entries = {}
			for _, towerId in towers do
				table.insert(entries, { towerId = towerId, chance = chance / #towers })
			end
			table.insert(odds, { rarity = rarity, chance = chance, towers = entries })
		end
	end
	return odds
end

-- Odds of a case and the featured tower (event banners), for kind "Banner" | "Chest".
function CaseOdds.of(kind: string, id: string, now: number): ({ Banners.RarityOdds }, string?)
	if kind == "Banner" then
		local banner = Banners.ById[id]
		local featured = Banners.Featured(banner, now)
		local featuredId = featured and featured.towerId
		return Banners.Odds(banner, featuredId, 0), featuredId
	end
	return CaseOdds.chest(ChestsConfig.Chests[id]), nil
end

-- The best towers of a case: the featured one first, then by rarity (and chance within it).
function CaseOdds.top(odds: { Banners.RarityOdds }, featuredId: string?, count: number): { { towerId: string, rarity: string, chance: number } }
	local top = {}
	if featuredId then
		for _, rarityOdds in odds do
			for _, entry in rarityOdds.towers do
				if entry.towerId == featuredId then
					table.insert(top, { towerId = entry.towerId, rarity = rarityOdds.rarity, chance = entry.chance })
				end
			end
		end
	end
	for _, rarityOdds in odds do
		for _, entry in rarityOdds.towers do
			if #top >= count then
				return top
			end
			if entry.towerId ~= featuredId then
				table.insert(top, { towerId = entry.towerId, rarity = rarityOdds.rarity, chance = entry.chance })
			end
		end
	end
	return top
end

return CaseOdds
