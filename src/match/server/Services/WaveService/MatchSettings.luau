local Settings = {}

Settings.Defaults = { Mode = "Normal", Season = "None", Modifiers = {} }
-- Add the lobby place ID before enabling incoming lobby selections.
Settings.LobbyPlaceIds = { 86140743290043 }
Settings.ReturnDelay = 30 -- seconds after the match ends before everyone is sent back to the lobby
Settings.InitialPreparation = 12
Settings.BaseHealth = 1500

-- Economy. Cash is match-only money for placing and upgrading towers.
-- Coins are the saved currency, paid once when the match ends (scaled by the mode's Reward).
Settings.StartingCash = 600
-- New players (level below RookieLevels, i.e. their first 2-3 matches) start with extra Cash, per player,
-- so a first match with the four starter towers is winnable. Shown on their HUD as a notice.
Settings.RookieLevels = 3
Settings.RookieCash = 300
Settings.CoinsPerWave = 15 -- per cleared wave
Settings.VictoryCoins = 75 -- bonus for clearing every wave
-- Gems (saved premium currency) and player XP, paid together with the coins.
Settings.GemsPerFiveWaves = 2 -- per 5 cleared waves
Settings.VictoryGems = 10
Settings.XPPerWave = 10 -- per cleared wave
Settings.VictoryXPPerWave = 25 -- per wave when every wave is cleared

Settings.Modes = {
	Normal = { WaveSet = "Standard", Health = 1, Speed = 1, Damage = 1, Reward = 1 },
	Hard = { WaveSet = "Standard", Health = 1.4, Speed = 1.1, Damage = 1.2, Reward = 1.25 },
}
Settings.Seasons = {
	None = { Modifiers = {}, Music = "Normal" },
	Winter = { Modifiers = { "FrostArmor" }, Music = "Winter" },
}
Settings.Modifiers = {
	FrostArmor = { Health = 1.2, Speed = 0.95, Reward = 1.15 },
	SwiftEnemies = { Speed = 1.15, Reward = 1.1 },
	ToughEnemies = { Health = 1.25, Reward = 1.15 },
	-- Added by Match.server when the player who starts the match is a rookie (Settings.RookieLevels).
	Rookie = { Health = 0.8 },
}

function Settings.Resolve(raw)
	raw = if type(raw) == "table" then raw else {}
	local mode = if type(raw.Mode) == "string" and Settings.Modes[raw.Mode] then raw.Mode else Settings.Defaults.Mode
	local season = if type(raw.Season) == "string" and Settings.Seasons[raw.Season] then raw.Season else Settings.Defaults.Season
	local selected, seen = {}, {}
	local function add(name)
		if type(name) == "string" and Settings.Modifiers[name] and not seen[name] then
			seen[name] = true
			table.insert(selected, name)
		end
	end
	for _, name in ipairs(Settings.Seasons[season].Modifiers) do add(name) end
	local requested = if type(raw.Modifiers) == "table" then raw.Modifiers else Settings.Defaults.Modifiers
	for index = 1, math.min(#requested, 4) do add(requested[index]) end
	return { Mode = mode, Season = season, Modifiers = selected }
end

function Settings.FromPlayer(player)
	local ok, join = pcall(function() return player:GetJoinData() end)
	if ok and type(join) == "table" and join.SourceGameId == game.GameId and table.find(Settings.LobbyPlaceIds, join.SourcePlaceId) then
		local data = join.TeleportData
		if type(data) == "table" and data.Version == 1 then
			return Settings.Resolve(data.MatchSettings)
		end
	end
	return Settings.Resolve(Settings.Defaults)
end

-- Per-map difficulty from attributes on workspace.Map (harder maps); missing attributes count as 1.
-- Health/Speed/Damage scale the enemies, Reward scales the coins and XP paid when the match ends.
function Settings.MapScale(map: Instance?)
	local function read(name)
		local value = map and map:GetAttribute(name)
		return if type(value) == "number" and value > 0 then value else 1
	end
	return {
		Health = read("EnemyHealth"),
		Speed = read("EnemySpeed"),
		Damage = read("EnemyDamage"),
		Reward = read("RewardScale"),
	}
end

function Settings.EnemyStats(base, match, groupModifiers)
	local mode = Settings.Modes[match.Mode]
	local scales = { Health = mode.Health, Speed = mode.Speed, Damage = mode.Damage, Reward = mode.Reward }
	if match.MapScale then
		scales.Health *= match.MapScale.Health
		scales.Speed *= match.MapScale.Speed
		scales.Damage *= match.MapScale.Damage
	end
	local seen = {}
	local function apply(name)
		local modifier = Settings.Modifiers[name]
		assert(modifier, "Unknown enemy modifier: " .. tostring(name))
		if seen[name] then return end
		seen[name] = true
		for stat, multiplier in pairs(modifier) do scales[stat] *= multiplier end
	end
	for _, name in ipairs(match.Modifiers) do apply(name) end
	for _, name in ipairs(groupModifiers or {}) do apply(name) end
	-- Abilities (Armor, Hidden, Heal, Split...) and Boss are kept as they are.
	local stats = table.clone(base)
	stats.Health = math.max(1, math.round(base.Health * scales.Health))
	stats.Speed = base.Speed * scales.Speed
	stats.Damage = math.max(1, math.round(base.Damage * scales.Damage))
	stats.Reward = math.max(0, math.round(base.Reward * scales.Reward))
	return stats
end

return Settings
