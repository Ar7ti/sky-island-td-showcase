local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyHandler = require(script.Parent.Parent.Enemy.EnemyHandler)
local EnemyConfig = require(script.Parent.Parent.Enemy.EnemyConfig)
local Base = require(script.Parent.Parent.BaseService.BaseService)
local Notify = require(ReplicatedStorage.Shared.Features.Services.Notify.Notify)
local MatchCash = require(script.Parent.Parent.Economy.MatchCash)
local Currencies = require(ReplicatedStorage.Shared.Features.Services.Economy.Currencies)
local MatchRewards = require(script.Parent.Parent.Economy.MatchRewards)
local Settings = require(script.Parent.MatchSettings)
local WaveSets = require(script.Parent.WavesConfig)
local buildSchedule = require(script.Parent.WaveSchedule)
local towerIncome = require(script.Parent.Parent.TowerService.towerIncome)
local towerDamage = require(script.Parent.Parent.TowerService.towerDamage)
local MatchBonuses = require(ReplicatedStorage.Shared.Features.Services.MatchBonuses.MatchBonuses)

local WaveService = { Started = false, Running = false }

-- READY (start the next wave early): during preparation every player may vote once; when everyone in the server
-- has voted, the countdown drops to READY_SECONDS. MatchState publishes ReadyVotes / ReadyNeeded for the button.
local READY_SECONDS = 3
WaveService.ReadyVotes = {} :: { [number]: boolean }

function WaveService:ReadyCount(): (number, number)
	local votes, needed = 0, 0
	for _, player in Players:GetPlayers() do
		needed += 1
		if self.ReadyVotes[player.UserId] then
			votes += 1
		end
	end
	return votes, needed
end

function WaveService:PublishReady()
	local votes, needed = self:ReadyCount()
	self.State:SetAttribute("ReadyVotes", votes)
	self.State:SetAttribute("ReadyNeeded", needed)
end

-- A vote from a player (ReadyRemote). Only during preparation, only while more than READY_SECONDS are left.
function WaveService:VoteReady(player: Player)
	if not self.Running or self.State:GetAttribute("Phase") ~= "Preparation" then
		return
	end
	if (self.State:GetAttribute("TimeRemaining") or 0) <= READY_SECONDS then
		return
	end
	self.ReadyVotes[player.UserId] = true
	self:PublishReady()
end

function WaveService:Publish(state, remaining)
	self.State:SetAttribute("Wave", self.Wave)
	self.State:SetAttribute("Alive", self.Alive)
	self.State:SetAttribute("TimeRemaining", remaining or 0)
	-- Set phase last so UI subscribers can read the other updated values.
	self.State:SetAttribute("Phase", state)
end

function WaveService:Wait(seconds)
	local deadline = os.clock() + seconds
	while self.Running and os.clock() < deadline do
		task.wait(math.min(0.1, math.max(0, deadline - os.clock())))
	end
	return self.Running
end

function WaveService:Finish(result)
	if not self.Running then return end
	self.Running = false
	if self.GameOverConnection then self.GameOverConnection:Disconnect() end
	-- Destroying enemies instead of killing them avoids death rewards on defeat.
	local models = {}
	for model in pairs(self.Active) do table.insert(models, model) end
	for _, model in ipairs(models) do
		self.Active[model]()
		model:Destroy()
	end
	-- Pay before publishing the result, so the result screen already has the amounts.
	local rewards = MatchRewards:Finish(result == "Victory")
	self.State:SetAttribute("RewardCoins", rewards.Coins)
	self.State:SetAttribute("RewardGems", rewards.Gems)
	self.State:SetAttribute("RewardXP", rewards.XP)
	self.State:SetAttribute("WavesCleared", MatchRewards.WavesCleared)
	self:Publish(result)
	if result == "Victory" then
		Notify:ShowAll("success", "Victory! All waves cleared.", 5)
	elseif result == "Defeat" then
		Notify:ShowAll("error", "Game over! The base was destroyed.", 5)
	elseif result == "Error" then
		Notify:ShowAll("error", "The match could not continue. Please rejoin.", 5)
	end
end

function WaveService:Track(model)
	self.Alive += 1
	local connections = {}
	local function resolve()
		if not self.Active[model] then return end
		-- A Bloater killed by the towers (not one that reached the base) bursts into Minis; they are
		-- counted before this one is let go, so the wave can't end in between.
		local humanoid = if typeof(model) == "Instance" then model:FindFirstChildOfClass("Humanoid") else nil
		if self.Running and humanoid and humanoid.Health <= 0 and model:GetAttribute("SplitInto") then
			local ok, message = pcall(self.SpawnSplit, self, model)
			if not ok then warn(message) end
		end
		self.Active[model] = nil
		self.Alive -= 1
		for _, connection in ipairs(connections) do connection:Disconnect() end
		if self.Running then self:Publish(self.State:GetAttribute("Phase")) end
	end
	self.Active[model] = resolve
	table.insert(connections, model.Humanoid.Died:Connect(resolve))
	table.insert(connections, model.Destroying:Connect(resolve))
	self:Publish("Spawning")
end

-- The elite of a wave: a scaled-up copy of MatchBonuses.Elite.Base (see EnemyHandler).
function WaveService:SpawnElite(index)
	local elite = MatchBonuses.Elite
	local stats = Settings.EnemyStats(EnemyConfig[elite.Base], self.Match)
	stats.Health = math.round(stats.Health * elite.Health)
	stats.Speed *= elite.Speed
	stats.Damage = math.round(stats.Damage * elite.Damage)
	stats.Reward = math.round(stats.Reward * elite.Reward)
	stats.Experience = elite.Experience
	stats.Elite, stats.Scale = true, elite.Scale
	local model = EnemyHandler.Spawn(elite.Base, self.SpawnPoint.CFrame, stats, index)
	assert(model, "Failed to spawn the elite")
	self:Track(model)
	-- Clients show the "elite incoming" banner when this counter changes.
	self.State:SetAttribute("EliteSpawns", (self.State:GetAttribute("EliteSpawns") or 0) + 1)
end

-- Split: SplitCount copies of SplitInto appear around the dead enemy and walk on from its waypoint.
function WaveService:SpawnSplit(model: Model)
	local name = model:GetAttribute("SplitInto")
	local count = model:GetAttribute("SplitCount") or 0
	local root = model:FindFirstChild("HumanoidRootPart")
	if type(name) ~= "string" or not EnemyConfig[name] or not root then return end
	local index = model:GetAttribute("PathIndex")
	local stats = Settings.EnemyStats(EnemyConfig[name], self.Match)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * 1.6, 0, math.sin(angle) * 1.6)
		local cframe = CFrame.new(root.Position + offset) * root.CFrame.Rotation
		local child = EnemyHandler.Spawn(name, cframe, stats, model:GetAttribute("Wave"), if type(index) == "number" then index else nil)
		if child then
			self:Track(child)
		end
	end
	self.State:SetAttribute("SplitAt", root.Position)
	self.State:SetAttribute("Splits", (self.State:GetAttribute("Splits") or 0) + 1)
end

-- A killed elite gives every player a chest; clients fly a chest from ChestDropAt to the HUD counter.
function WaveService:OnKill(enemy: Model)
	if not self.Running or not enemy:GetAttribute("Elite") then return end
	MatchRewards:ChestEarned()
	local root = enemy:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		self.State:SetAttribute("ChestDropAt", root.Position)
	end
	self.State:SetAttribute("Chests", MatchRewards.Chests)
	Notify:ShowAll("success", "Elite defeated! Everyone gets a chest.", 3)
end

function WaveService:Run()
	local waves = WaveSets[Settings.Modes[self.Match.Mode].WaveSet]
	assert(waves and #waves > 0, "No waves configured")
	-- Validate every scenario before the first enemy is spawned.
	local schedules = {}
	for index, wave in ipairs(waves) do
		schedules[index] = buildSchedule(wave, EnemyConfig)
		for _, group in ipairs(wave.Groups) do Settings.EnemyStats(EnemyConfig[group.Enemy], self.Match, group.Modifiers) end
	end
	self.State:SetAttribute("TotalWaves", #waves)
	Notify:ShowAll("info", self.Match.Mode .. " | Season: " .. self.Match.Season, 4)
	if table.find(self.Match.Modifiers, "Rookie") then
		Notify:ShowAll("success", "Rookie mode: enemies are 20% weaker in your first matches.", 5)
	end
	for index, wave in ipairs(waves) do
		if not self.Running then return end
		self.State:SetAttribute("WaveName", wave.Name)
		local preparation = if index == 1 then Settings.InitialPreparation else wave.Preparation
		self.ReadyVotes = {}
		self:PublishReady()
		local remaining = preparation
		while remaining >= 1 do
			self:Publish("Preparation", remaining)
			if not self:Wait(1) then return end
			remaining -= 1
			local votes, needed = self:ReadyCount()
			if needed > 0 and votes >= needed and remaining > READY_SECONDS then
				remaining = READY_SECONDS
				Notify:ShowAll("success", "Everyone is ready! Next wave in " .. READY_SECONDS .. "s", 2)
			end
		end
		self.ReadyVotes = {}
		self:PublishReady()
		self.Wave = index
		self:Publish("Spawning")
		Notify:ShowAll("info", "Wave " .. index .. ": " .. wave.Name, 3)
		local started = os.clock()
		-- Every EliteEvery-th wave the elite walks in the middle of the wave.
		local schedule = schedules[index]
		local eliteAt = if index % MatchBonuses.EliteEvery == 0 and #schedule > 0 then math.ceil(#schedule / 2) else nil
		self.State:SetAttribute("EliteWave", eliteAt ~= nil)
		for order, spawn in ipairs(schedule) do
			if not self:Wait(math.max(0, started + spawn.Time - os.clock())) then return end
			if order == eliteAt then
				self:SpawnElite(index)
			end
			local group = spawn.Group
			local stats = Settings.EnemyStats(EnemyConfig[group.Enemy], self.Match, group.Modifiers)
			local model = EnemyHandler.Spawn(group.Enemy, self.SpawnPoint.CFrame, stats, index)
			assert(model, "Failed to spawn " .. group.Enemy)
			self:Track(model)
		end
		self:Publish("Clearing")
		while self.Running and self.Alive > 0 do self:Wait(0.1) end
		if not self.Running then return end
		local currentHealth = Base:GetHealth()
		if currentHealth and currentHealth <= 0 then
			self:Finish("Defeat")
			return
		end
		self:Publish("WaveComplete")
		MatchRewards:WaveCleared()
		self.State:SetAttribute("WavesCleared", MatchRewards.WavesCleared)
		local reward = math.round(wave.CompletionReward * Settings.Modes[self.Match.Mode].Reward)
		for _, player in ipairs(Players:GetPlayers()) do
			MatchCash.Add(player, reward)
		end
		self.CatchUp = (self.CatchUp or 0) + reward
		Notify:ShowAll("success", "Wave cleared! +$" .. reward, 2)
		-- Merchants pay their owners on top of the wave reward.
		towerIncome.PayWave()
	end
	self:Finish("Victory")
end

function WaveService:Start(match)
	if self.Started then return end
	self.Started, self.Running = true, true
	self.Match = Settings.Resolve(match)
	self.Wave, self.Alive, self.Active = 0, 0, {}
	MatchRewards:Start(self.Match.Mode)
	-- Keep the same instance clients subscribed to during profile loading.
	self.State = ReplicatedStorage:FindFirstChild("MatchState") or Instance.new("Folder")
	self.State.Name = "MatchState"
	self.State:SetAttribute("Mode", self.Match.Mode)
	self.State:SetAttribute("Season", self.Match.Season)
	self.State:SetAttribute("Modifiers", table.concat(self.Match.Modifiers, ", "))
	self.State:SetAttribute("MusicCategory", Settings.Seasons[self.Match.Season].Music)
	self.State:SetAttribute("Chests", 0)
	self.State:SetAttribute("EliteSpawns", 0)
	self.State:SetAttribute("EliteEvery", MatchBonuses.EliteEvery)
	table.insert(towerDamage.KillHandlers, function(enemy: Model)
		self:OnKill(enemy)
	end)
	self:Publish("Waiting")
	local readyRemote = Instance.new("RemoteEvent")
	readyRemote.Name = "ReadyRemote"
	readyRemote.OnServerEvent:Connect(function(player)
		self:VoteReady(player)
	end)
	readyRemote.Parent = self.State
	-- A late joiner (slow teleport, rejoin) gets the wave-clear Cash the others already got, once MatchCash has given
	-- them the starting Cash, so they can still help. Kill Cash isn't caught up.
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			local waited = 0
			while player.Parent == Players and player:GetAttribute(Currencies.CashAttribute) == nil and waited < 10 do
				task.wait(0.25)
				waited += 0.25
			end
			local catchUp = self.CatchUp or 0
			if catchUp > 0 and player.Parent == Players and self.Running then
				MatchCash.Add(player, catchUp)
				Notify:ShowSuccess(`You joined at wave {self.Wave}: +${catchUp} to catch up!`, player, 4)
			end
		end)
	end)
	-- A player leaving can complete the vote of the ones left: the count is taken over current players.
	Players.PlayerRemoving:Connect(function(player)
		self.ReadyVotes[player.UserId] = nil
		task.defer(function()
			if self.State then
				self:PublishReady()
			end
		end)
	end)
	self.State.Parent = ReplicatedStorage
	local ok, message = xpcall(function()
		local map = workspace:WaitForChild("Map", 10)
		assert(map, "Match map is missing")
		local path = map:WaitForChild("Path", 10)
		assert(path, "Map path is missing")
		self.SpawnPoint = path:WaitForChild("1", 10)
		assert(self.SpawnPoint and self.SpawnPoint:IsA("BasePart"), "Path needs a BasePart named 1")
		-- The route for client decor (MapNeon): with StreamingEnabled far waypoints aren't on the client.
		local route = {}
		for _, point in path:GetChildren() do
			local index = tonumber(point.Name)
			if point:IsA("BasePart") and index then
				table.insert(route, { index, point.Position })
			end
		end
		table.sort(route, function(a, b)
			return a[1] < b[1]
		end)
		local encoded = {}
		for i, entry in route do
			local p = entry[2]
			encoded[i] = string.format("%.1f,%.1f,%.1f", p.X, p.Y, p.Z)
		end
		self.State:SetAttribute("Route", table.concat(encoded, ";"))
		-- harder maps carry their own enemy and reward multipliers (Settings.MapScale)
		self.Match.MapScale = Settings.MapScale(map)
		MatchRewards.RewardScale = self.Match.MapScale.Reward
		self.State:SetAttribute("MapName", map:GetAttribute("MapName") or "")
		Base:Init()
		Base:Setup(map, Settings.BaseHealth)
		self.GameOverConnection = ReplicatedStorage.Events.Bindable.GameOver.Event:Connect(function() self:Finish("Defeat") end)
		self:Run()
	end, debug.traceback)
	if not ok then
		warn(message)
		self:Finish("Error")
	end
end

return WaveService
