"""Load probe for CRITERIA 7 (performance): a crowded match in Studio Play, server and client frame times.

Usage (always run Python isolated):
  python3 -I tools/studio/perf_probe.py [--place 134681445336553] [--towers 10] [--enemies 60] [--seconds 20]

Starts Play with the NoProgress guard (nothing is paid into the profile), then a temporary server Script:
the base is made invulnerable (Base.God), the player gets match cash, up to --towers towers from their loadout are
placed through the live TowerService (the same server checks as a click), and --enemies enemies (every EnemyConfig
type in turn, 0.1 s apart) are spawned through EnemyHandler and counted by the wave. While they walk and the towers
fight, it samples the server's Heartbeat frame time and the client's render frame time for --seconds, then prints
one JSON line: p50 / p95 / max frame ms, enemies alive, towers placed, memory. Stops Play at the end.
Studio on this Mac is not a phone: compare runs with each other (before/after a change), not with a target fps.
"""
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
args = sys.argv[1:]


def option(name, default):
    return args[args.index(name) + 1] if name in args else default


place = option("--place", "134681445336553")
towers = int(option("--towers", "10"))
enemies = int(option("--enemies", "60"))
seconds = float(option("--seconds", "20"))

SERVER = r"""
local s = Instance.new("Script")
s.Name = "__PerfProbe"
s.Source = [==[
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local StatsService = game:GetService("Stats")
local function set(k, v) workspace:SetAttribute(k, v) end
local ok, err = pcall(function()
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	player:SetAttribute("NoProgress", true)
	local Services = SSS.Server.Services
	require(Services.Economy.MatchRewards).Paid[player.UserId] = true
	local Data = require(RS.Shared.Features.Services.DataService.Data).server
	local data = Data.Service:waitForData(player)
	local WaveService = require(Services.WaveService.WaveService)
	local deadline = os.clock() + 40
	while not (WaveService.Running and WaveService.SpawnPoint) and os.clock() < deadline do task.wait(0.25) end
	assert(WaveService.Running, "match not running")
	require(Services.BaseService.BaseService).God = true
	local Cash = require(Services.Economy.MatchCash)
	Cash.Add(player, 10000000)
	-- Towers: the loadout's towers in turn, on TowerArea tops, spread out (the server rejects bad spots).
	local Loadout = require(RS.Shared.Features.Services.TowersServices.Loadout)
	local Config = require(RS.Shared.Features.Services.TowersServices.towersConfig)
	local slots = {}
	for _, id in Loadout.Resolve(data.loadout(), data.inventory(), data.unlockedLoadoutSlots()) do
		if Config[id] then table.insert(slots, id) end
	end
	assert(#slots > 0, "empty loadout")
	local TowerService = require(Services.TowerService.towerService)
	local spots = {}
	for _, d in workspace.Map:GetDescendants() do
		if d:IsA("BasePart") and d.Parent and d.Parent.Name == "TowerArea" then
			for gx = -1, 1 do
				for gz = -1, 1 do
					local offset = Vector3.new(gx * d.Size.X / 3, d.Size.Y / 2, gz * d.Size.Z / 3)
					table.insert(spots, (d.CFrame * CFrame.new(offset)).Position)
				end
			end
		end
	end
	local placed = 0
	for index, spot in spots do
		if placed >= __TOWERS__ then break end
		local name = slots[(placed % #slots) + 1]
		local tpl = RS.Game.Towers[name]
		local y = spot.Y + tpl.Humanoid.HipHeight - 1 + tpl.PrimaryPart.Size.Y / 2
		local tower = TowerService:SpawnTower(player, name, CFrame.new(spot.X, y, spot.Z))
		if tower then placed += 1 end
	end
	set("PerfTowers", placed)
	-- Enemies: every type in turn, counted by the wave.
	local EnemyConfig = require(Services.Enemy.EnemyConfig)
	local EnemyHandler = require(Services.Enemy.EnemyHandler)
	local Settings = require(Services.WaveService.MatchSettings)
	local names = {}
	for name in EnemyConfig do table.insert(names, name) end
	table.sort(names)
	for index = 1, __ENEMIES__ do
		local name = names[(index - 1) % #names + 1]
		local stats = Settings.EnemyStats(EnemyConfig[name], WaveService.Match)
		local model = EnemyHandler.Spawn(name, WaveService.SpawnPoint.CFrame, stats, WaveService.Wave)
		if model then WaveService:Track(model) end
		task.wait(0.1)
	end
	-- Measure.
	local frames, alive = {}, {}
	local connection = RunService.Heartbeat:Connect(function(dt) table.insert(frames, dt * 1000) end)
	local stop = os.clock() + __SECONDS__
	while os.clock() < stop do
		local folder = workspace:FindFirstChild("ZombiesOnMap")
		table.insert(alive, folder and #folder:GetChildren() or -1)
		task.wait(1)
	end
	connection:Disconnect()
	table.sort(frames)
	local function pct(p) return frames[math.max(1, math.ceil(#frames * p))] or 0 end
	local sum = 0
	for _, a in alive do sum += a end
	set("PerfServer", game:GetService("HttpService"):JSONEncode({
		frames = #frames, p50 = pct(0.5), p95 = pct(0.95), max = frames[#frames] or 0,
		aliveAvg = sum / math.max(1, #alive), aliveMax = math.max(table.unpack(alive)),
		memoryMb = StatsService:GetTotalMemoryUsageMb(), physicsFps = workspace:GetRealPhysicsFPS(),
	}))
end)
if not ok then set("PerfError", tostring(err)) end
]==]
s.Parent = game.ServerScriptService
return "probe started"
"""

CLIENT = r"""
local RunService = game:GetService("RunService")
local frames = {}
local connection = RunService.RenderStepped:Connect(function(dt) table.insert(frames, dt * 1000) end)
task.wait(__SECONDS__)
connection:Disconnect()
table.sort(frames)
local function pct(p) return frames[math.max(1, math.ceil(#frames * p))] or 0 end
return game:GetService("HttpService"):JSONEncode({ frames = #frames, p50 = pct(0.5), p95 = pct(0.95), max = frames[#frames] or 0 })
"""

READ = """return game:GetService("HttpService"):JSONEncode({ server = workspace:GetAttribute("PerfServer"),
  towers = workspace:GetAttribute("PerfTowers"), error = workspace:GetAttribute("PerfError") })"""

spawn_time = enemies * 0.1
server = SERVER.replace("__TOWERS__", str(towers)).replace("__ENEMIES__", str(enemies)).replace("__SECONDS__", str(seconds))
steps = [
    {"play": True},
    {"sleep": 8},
    {"label": "server probe", "tool": "execute_luau", "args": {"studio_id": "$STUDIO", "datamodel_type": "Server", "code": server}},
    # Wave 1 starts after the preparation; then the towers go in and the enemies spawn.
    {"sleep": 16 + spawn_time},
    {"label": "client frames", "max": 2000, "tool": "execute_luau",
     "args": {"studio_id": "$STUDIO", "datamodel_type": "Client", "code": CLIENT.replace("__SECONDS__", str(min(seconds, 15)))}},
    {"sleep": max(1, seconds - min(seconds, 15) + 3)},
    {"label": "server result", "max": 4000, "tool": "execute_luau", "args": {"studio_id": "$STUDIO", "datamodel_type": "Server", "code": READ}},
    {"label": "stop", "tool": "start_stop_play", "args": {"studio_id": "$STUDIO", "is_start": False}},
]
with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
    json.dump(steps, f)
    path = f.name
try:
    subprocess.run([sys.executable, "-I", os.path.join(HERE, "studio_mcp.py"), "--place", place, "batch", path], check=False)
finally:
    os.remove(path)
