-- Run in Studio's SERVER Command Bar:
-- require(game.ServerScriptService.Server.Services.WaveService.Tests)()
return function()
	local Settings = require(script.Parent.MatchSettings)
	local Sets = require(script.Parent.WavesConfig)
	local Build = require(script.Parent.WaveSchedule)
	local Enemies = require(script.Parent.Parent.Enemy.EnemyConfig)
	local normal = Settings.Resolve({ Mode = "Normal", Season = "None" })
	assert(normal.Mode == "Normal" and #normal.Modifiers == 0, "Normal mode resolves without modifiers")
	local invalid = Settings.Resolve({ Mode = "MadeUp", Season = 42, Modifiers = { "Unknown" }, Health = 999 })
	assert(invalid.Mode == Settings.Defaults.Mode and invalid.Season == Settings.Defaults.Season, "Invalid settings fall back to defaults")
	assert(#invalid.Modifiers == 0, "Unknown modifiers are dropped")
	local winter = Settings.Resolve({ Mode = "Hard", Season = "Winter", Modifiers = { "FrostArmor", "SwiftEnemies", "SwiftEnemies" } })
	assert(#winter.Modifiers == 2, "Season and requested modifiers must be deduplicated")
	local stats = Settings.EnemyStats(Enemies.Zombie1, winter, { "FrostArmor" })
	assert(stats.Health == math.round(Enemies.Zombie1.Health * 1.4 * 1.2), "Health scales by mode and modifier once")
	assert(math.abs(stats.Speed - Enemies.Zombie1.Speed * 1.1 * 0.95 * 1.15) < 0.00001, "Speed scales by mode and modifiers")
	assert(Enemies.Zombie1.Health == 90, "Shared enemy config must not be mutated")
	local wave = {
		Preparation = 1, CompletionReward = 0,
		Groups = {
			{ Enemy = "Zombie1", Count = 3, Interval = 2, StartDelay = 0 },
			{ Enemy = "Zombie2", Count = 2, Interval = 2, StartDelay = 1 },
		},
	}
	local schedule = Build(wave, Enemies)
	assert(#schedule == 5, "Schedule has one spawn per enemy")
	for index, spawn in ipairs(schedule) do assert(spawn.Time == index - 1, "Groups should overlap in chronological order") end
	wave.Groups[1].Enemy = "Missing"
	assert(not pcall(Build, wave, Enemies), "Unknown enemies must fail validation")
	wave.Groups[1].Enemy, wave.Groups[1].Count = "Zombie1", -1
	assert(not pcall(Build, wave, Enemies), "Negative counts must fail validation")
	local totalKills, totalRewards = 0, 0
	for _, scenario in ipairs(Sets.Standard) do
		for _, spawn in ipairs(Build(scenario, Enemies)) do
			local enemy = Settings.EnemyStats(Enemies[spawn.Group.Enemy], normal, spawn.Group.Modifiers)
			totalKills += 1
			totalRewards += enemy.Reward
		end
		totalRewards += scenario.CompletionReward
	end
	-- 15 waves; Bloaters' Minis (9 x 3) and the elites come on top of the scheduled kills.
	assert(#Sets.Standard == 15 and totalKills == 292, "Standard set: 15 waves, 292 scheduled kills")
	assert(totalRewards == 24795, "Normal full-clear income changed; review economy")
	local rookie = Settings.Resolve({ Mode = "Normal", Season = "None", Modifiers = { "Rookie" } })
	assert(Settings.EnemyStats(Enemies.Zombie1, rookie).Health == math.round(Enemies.Zombie1.Health * 0.8), "Rookie enemies have 80% health")
	-- Rookie bonus: only the first levels, never negative.
	local MatchCash = require(script.Parent.Parent.Economy.MatchCash)
	assert(MatchCash.RookieBonus(0) == Settings.RookieCash and MatchCash.RookieBonus(Settings.RookieLevels - 1) == Settings.RookieCash, "Rookies get the bonus")
	assert(MatchCash.RookieBonus(Settings.RookieLevels) == 0 and MatchCash.RookieBonus(50) == 0, "Veterans get no bonus")
	-- Use an isolated service instance and signals, never the live match.
	local Service = require(script.Parent.WaveService)
	local state = Instance.new("Folder")
	local service = setmetatable({ Running = true, Wave = 1, Alive = 0, Active = {}, State = state }, { __index = Service })
	local died = Instance.new("BindableEvent")
	local destroyed = Instance.new("BindableEvent")
	local model = { Humanoid = { Died = died.Event }, Destroying = destroyed.Event }
	function model:Destroy() destroyed:Fire() end
	service:Track(model)
	assert(service.Alive == 1, "Tracked enemy counts as alive")
	died:Fire()
	destroyed:Fire()
	task.wait()
	assert(service.Alive == 0, "Death followed by destruction must resolve only once")
	service:Track(model)
	service:Finish("Stopped")
	assert(not service.Running and service.Alive == 0 and state:GetAttribute("Phase") == "Stopped", "Finish clears enemies and publishes the result")
	assert(not service:Wait(100), "Stopped matches must not wait or keep spawning")
	died:Destroy()
	destroyed:Destroy()
	state:Destroy()
	print("Wave configuration tests passed")
end
