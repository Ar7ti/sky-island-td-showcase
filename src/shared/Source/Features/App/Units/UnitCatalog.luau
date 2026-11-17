local Catalog = {}
Catalog.Rarities = { "All", "Common", "Normal", "Rare", "Epic", "Legendary", "Mythic" }
Catalog.Sorts = { "Rarity: High to Low", "Rarity: Low to High", "Name", "DPS", "Price" }
local ranks = {}
for rank, rarity in ipairs(Catalog.Rarities) do ranks[rarity] = rank end

function Catalog.GetVisible(items, configs, search, sort)
	local ids = {}
	local owned = 0
	local query = string.lower(search):match("^%s*(.-)%s*$")
	for id, item in pairs(items) do
		local config = configs[id]
		if config and (item.Amount or 0) > 0 then
			owned += 1
			local matches = string.find(string.lower(config.DisplayName or id), query, 1, true)
				or string.find(string.lower(id), query, 1, true)
			if matches then table.insert(ids, id) end
		end
	end
	table.sort(ids, function(a, b)
		local first, second = configs[a], configs[b]
		if sort == "Rarity: High to Low" or sort == "Rarity: Low to High" then
			local x, y = ranks[first.Rarity] or 0, ranks[second.Rarity] or 0
			if x ~= y then
				if sort == "Rarity: Low to High" then return x < y end
				return x > y
			end
		elseif sort == "DPS" then
			local x = first.Damage / math.max(first.Reload, 0.01)
			local y = second.Damage / math.max(second.Reload, 0.01)
			if x ~= y then return x > y end
		elseif sort == "Price" and first.Price ~= second.Price then
			return first.Price < second.Price
		end
		local x, y = string.lower(first.DisplayName or a), string.lower(second.DisplayName or b)
		return if x ~= y then x < y else a < b
	end)
	return ids, owned
end

return Catalog
