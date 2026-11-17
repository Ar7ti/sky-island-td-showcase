"""Release gate: a real playtest of the match place through StudioMCP.

Usage (always run Python isolated; push sources first, Rojo is usually not connected):
  python3 -I tools/studio/playtest.py [--place 134681445336553] [--out <dir>] [--waves 1] [--keep-playing]

Steps: start Play -> run WaveService/Tests.luau on the server -> place one loadout tower for the test
player through the live TowerService (temp server Script, removed afterwards) -> wait until wave N is
cleared (or the base falls) -> screen_capture -> scan the console for errors -> stop Play.
Prints a JSON summary and exits 1 when a check fails. Never saves or publishes the place.
Note: Play mode loads the developer's own profile (ProfileStore, session lock only); the test marks the
player as already paid in MatchRewards, so no match coins/gems/XP are written to that profile.
"""
import base64
import json
import os
import subprocess
import sys
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
import time

def _find_studio_mcp():
    """StudioMCP binary: $STUDIO_MCP, else the macOS app, else the newest Roblox Studio version on Windows."""
    import glob, os
    if os.environ.get("STUDIO_MCP"):
        return os.environ["STUDIO_MCP"]
    if sys.platform != "win32":
        return "/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP"
    root = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "Versions")
    found = [p for p in glob.glob(os.path.join(root, "*", "StudioMCP.exe"))
             if os.path.exists(os.path.join(os.path.dirname(p), "RobloxStudioBeta.exe"))]
    found = found or glob.glob(os.path.join(root, "*", "StudioMCP.exe"))
    if not found:
        raise SystemExit("StudioMCP.exe not found; set STUDIO_MCP")
    return max(found, key=os.path.getmtime)


def _line_reader(stream):
    """Lines from a pipe through a thread (select() does not work on Windows pipes): read(timeout) -> line|None|''."""
    import queue, threading
    lines = queue.Queue()

    def pump():
        for line in iter(stream.readline, ""):
            lines.put(line)
        lines.put("")

    threading.Thread(target=pump, daemon=True).start()

    def read(timeout):
        try:
            return lines.get(timeout=timeout)
        except queue.Empty:
            return None

    return read


STUDIO_MCP = _find_studio_mcp()

args = sys.argv[1:]


def option(name, default):
    if name in args:
        i = args.index(name)
        value = args[i + 1]
        del args[i : i + 2]
        return value
    return default


place = option("--place", "134681445336553")
out_dir = option("--out", ".")
waves = int(option("--waves", "1"))
keep = "--keep-playing" in args
full = "--full" in args  # kill every enemy on spawn, play all waves to Victory, check the return to lobby
if full:
    waves = 15
os.makedirs(out_dir, exist_ok=True)

proc = subprocess.Popen([STUDIO_MCP], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, encoding="utf-8", errors="replace", bufsize=1)
read_line = _line_reader(proc.stdout)
counter = [0]


def request(method, params=None, timeout=180):
    counter[0] += 1
    rid = counter[0]
    proc.stdin.write(json.dumps({"jsonrpc": "2.0", "id": rid, "method": method, "params": params or {}}) + "\n")
    proc.stdin.flush()
    end = time.time() + timeout
    while time.time() < end:
        line = read_line(1)
        if line is not None:
            if not line:
                break
            try:
                message = json.loads(line)
            except ValueError:
                continue
            if message.get("id") == rid:
                return message
    return {"error": f"timeout {method}"}


def text_of(result):
    return "".join(c.get("text", "") for c in result.get("result", {}).get("content", []))


def studio_id():
    for _ in range(30):
        try:
            listed = json.loads(text_of(request("tools/call", {"name": "list_roblox_studios", "arguments": {}})))
        except ValueError:
            listed = {}
        for studio in listed.get("studios", []):
            if place in str(studio.get("placeId")) or place in str(studio.get("name")):
                return studio["id"]
        time.sleep(2)
    raise SystemExit(f"no Studio with place {place}")


def call(tool, arguments, timeout=180):
    arguments = dict(arguments, studio_id=SID)
    return request("tools/call", {"name": tool, "arguments": arguments}, timeout)


def luau(code, model="Server", timeout=180):
    return text_of(call("execute_luau", {"datamodel_type": model, "code": code}, timeout))


request("initialize", {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "playtest", "version": "1"}})
proc.stdin.write(json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}) + "\n")
proc.stdin.flush()
time.sleep(2)
SID = studio_id()
summary = {"place": place, "checks": {}}
failed = []


def check(name, ok, detail):
    summary["checks"][name] = {"ok": bool(ok), "detail": detail}
    if not ok:
        failed.append(name)


state = text_of(call("get_studio_state", {}))
if "Server" not in state:
    call("start_stop_play", {"is_start": True})
for _ in range(60):
    state = text_of(call("get_studio_state", {}))
    if "Server" in state and "Client" in state:
        break
    time.sleep(2)
check("play_started", "Server" in state, state[:200])

if "Server" in state:
    tests = luau(
        """
local ok, err = pcall(function()
	local t = game.ServerScriptService:WaitForChild("Server"):WaitForChild("Services"):WaitForChild("WaveService"):WaitForChild("Tests", 20)
	require(t)()
end)
return if ok then "PASS" else "FAIL " .. tostring(err)
""",
        timeout=120,
    )
    check("wave_tests", tests.strip().startswith("PASS"), tests.strip()[:400])

    # Place one tower through the live TowerService (a temp Script shares the game's require cache).
    place_tower = luau(
        """
local SSS = game.ServerScriptService
local s = Instance.new("Script")
s.Name = "__PlaytestPlaceTower"
s.Source = [==[
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local function set(k, v) script:SetAttribute(k, v) end
local ok, err = pcall(function()
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	local Data = require(RS.Shared.Features.Services.DataService.Data).server
	local data = Data.Service:waitForData(player)
	-- Test runs never pay match rewards into the developer's saved profile.
	require(SSS.Server.Services.Economy.MatchRewards).Paid[player.UserId] = true
	player:SetAttribute("NoProgress", true) -- no kill XP either (towerDamage)
	local Loadout = require(RS.Shared.Features.Services.TowersServices.Loadout)
	local Config = require(RS.Shared.Features.Services.TowersServices.towersConfig)
	local slots = Loadout.Resolve(data.loadout(), data.inventory(), data.unlockedLoadoutSlots())
	local name
	for _, id in slots do
		if Config[id] and (not name or Config[id].Price < Config[name].Price) then name = id end
	end
	assert(name, "empty loadout")
	local path = workspace.Map.Path
	local target = (path:FindFirstChild("3") or path:FindFirstChild("2")).Position
	local best, bestD
	for _, d in workspace.Map:GetDescendants() do
		if d:IsA("BasePart") and d.Parent and d.Parent.Name == "TowerArea" then
			local top = d.Position + Vector3.new(0, d.Size.Y / 2, 0)
			local dist = (top - target).Magnitude
			if dist > 6 and (not bestD or dist < bestD) then best, bestD = top, dist end
		end
	end
	assert(best, "no TowerArea part")
	local tpl = RS.Game.Towers[name]
	local y = best.Y + tpl.Humanoid.HipHeight - 1 + tpl.PrimaryPart.Size.Y / 2
	local TowerService = require(SSS.Server.Services.TowerService.towerService)
	-- Ten towers of another player (far away) must not count against this player's limit.
	local others = {}
	for i = 1, 10 do
		local m = Instance.new("Model")
		m.Name = "__OtherPlayersTower"
		local p = Instance.new("Part")
		p.Name = "HumanoidRootPart"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Transparency = 1
		p.Position = Vector3.new(5000 + i * 10, -500, 5000)
		p.Parent = m
		m.PrimaryPart = p
		m:SetAttribute("OwnerId", -1)
		m.Parent = workspace.Towers
		table.insert(others, m)
	end
	local tower = TowerService:SpawnTower(player, name, CFrame.new(best.X, y, best.Z))
	for _, m in others do m:Destroy() end
	set("Tower", name)
	set("Placed", tower ~= nil)
	set("At", tower and tower:GetPivot().Position or best)
	-- Bad spots are rejected before any cash is taken.
	local Cash = require(SSS.Server.Services.Economy.MatchCash)
	Cash.Add(player, 100000)
	local before = Cash.Get(player)
	local bad = {
		same_spot = CFrame.new(best.X + 0.5, y, best.Z),
		on_path = CFrame.new(target + Vector3.new(0, 3, 0)),
		nan = CFrame.new(0 / 0, 0, 0),
		far_away = CFrame.new(100000, 50, 100000),
		not_a_cframe = "x",
	}
	local accepted = {}
	for label, cf in bad do
		local t = TowerService:SpawnTower(player, name, cf)
		if t then table.insert(accepted, label) t:Destroy() end
	end
	set("BadAccepted", table.concat(accepted, ","))
	set("CashKept", Cash.Get(player) == before)
	-- Upgrade costs exactly the next level's price; selling refunds towerSellPrice and removes the tower.
	local cfg = Config[name]
	if tower and cfg.Upgrades and cfg.Upgrades[2] then
		local c0 = Cash.Get(player)
		TowerService:UpgradeTower(player, tower)
		set("UpgradeOk", tower.Instances.towerLevel.Value == 2 and c0 - Cash.Get(player) == cfg.Upgrades[2].UpgradeCost)
	end
	local sellPrice = require(RS.Shared.Features.Services.TowersServices.towerSellPrice)
	for _, offset in { Vector3.new(4, 0, 0), Vector3.new(-4, 0, 0), Vector3.new(0, 0, 4), Vector3.new(0, 0, -4) } do
		local second = TowerService:SpawnTower(player, name, CFrame.new(best.X + offset.X, y, best.Z + offset.Z))
		if second then
			local c1 = Cash.Get(player)
			TowerService:SellTower(player, second)
			set("SellOk", second.Parent == nil and Cash.Get(player) - c1 == sellPrice(cfg, 1))
			break
		end
	end
	Cash.TrySpend(player, 100000)
end)
set("Done", true)
set("Error", if ok then nil else tostring(err))
]==]
s.Parent = SSS
local t0 = os.clock()
while not s:GetAttribute("Done") and os.clock() - t0 < 60 do task.wait(0.2) end
local r = { tower = s:GetAttribute("Tower"), placed = s:GetAttribute("Placed"), err = s:GetAttribute("Error"), at = tostring(s:GetAttribute("At")),
	bad_accepted = s:GetAttribute("BadAccepted"), cash_kept = s:GetAttribute("CashKept"),
	upgrade_ok = s:GetAttribute("UpgradeOk"), sell_ok = s:GetAttribute("SellOk") }
s:Destroy()
return game:GetService("HttpService"):JSONEncode(r)
""",
        timeout=120,
    )
    try:
        placed = json.loads(place_tower)
    except ValueError:
        placed = {"raw": place_tower[:300]}
    check("tower_placed", placed.get("placed") is True, placed)
    check("upgrade_and_sell", placed.get("upgrade_ok") is not False and placed.get("sell_ok") is not False, placed)
    check("bad_spots_rejected", placed.get("bad_accepted") == "" and placed.get("cash_kept") is True, placed)

    if full:
        # Every enemy dies on spawn through towerDamage.Deal (shared require cache), so all waves clear.
        luau(
            """
local s = Instance.new("Script")
s.Name = "__PlaytestKiller"
s.Source = [==[
local towerDamage = require(game.ServerScriptService.Server.Services.TowerService.towerDamage)
local player = game.Players:GetPlayers()[1]
workspace.ZombiesOnMap.ChildAdded:Connect(function(m)
	task.wait(0.3)
	if m.Parent then pcall(towerDamage.Deal, m, 1e7, player) end
end)
]==]
s.Parent = game.ServerScriptService
return "ok"
"""
        )

    # Wait for the waves to be cleared (or the base to fall).
    deadline = time.time() + 120 + 90 * waves
    progress = ""
    while time.time() < deadline:
        progress = luau(
            """
local s = game.ReplicatedStorage:FindFirstChild("MatchState")
local base = workspace.Map:FindFirstChild("Base")
return string.format("%s|%s|%s|%s", tostring(s:GetAttribute("Phase")), tostring(s:GetAttribute("Wave")), tostring(s:GetAttribute("Alive")), tostring(s:GetAttribute("WavesCleared")))
""",
            timeout=60,
        ).strip()
        parts = progress.split("|")
        if len(parts) == 4 and (parts[0] in ("Defeat", "Victory", "Error") or (not full and parts[3].isdigit() and int(parts[3]) >= waves)):
            break
        time.sleep(4)
    parts = progress.split("|")
    check("wave_cleared", len(parts) == 4 and parts[3].isdigit() and int(parts[3]) >= waves and parts[0] != "Error", progress)

    cam = {}
    if full:
        check("victory", parts[0] == "Victory", progress)
        return_at = luau('return tostring(game.ReplicatedStorage.MatchState:GetAttribute("ReturnAt"))').strip()
        check("return_scheduled", return_at not in ("", "nil"), return_at)
        time.sleep(4)
    else:
        # Screenshot near the placed tower.
        at = placed.get("at", "")
        try:
            x, y, z = [float(v) for v in str(at).split(",")]
            cam = {"camera_position": [x + 22, y + 26, z + 22], "look_at_position": [x, y, z]}
        except ValueError:
            cam = {}
    shot = call("screen_capture", dict(cam, capture_id="Playtest_1"), timeout=90)
    saved = None
    for content in shot.get("result", {}).get("content", []):
        if content.get("type") == "image":
            saved = os.path.join(out_dir, "playtest.png" if content.get("mimeType", "").endswith("png") else "playtest.jpg")
            with open(saved, "wb") as file:
                file.write(base64.b64decode(content["data"]))
    summary["screenshot"] = saved
    check("screenshot", saved is not None, saved or str(shot)[:200])

    if full:
        # Studio can't teleport, so the automatic return fails and must be retried (ReturnService).
        time.sleep(52)
        console = text_of(call("get_console_output", {}))
        # Informational only: a Studio teleport either errors (then it is retried) or ends the profile session.
        summary["return_attempts_failed"] = console.count("return to lobby failed")
        summary["kicked_by_teleport"] = "Profile session end" in console
        console = "\n".join(line for line in console.splitlines() if "return to lobby failed" not in line and "TeleportService" not in line and "teleport" not in line.lower())
    else:
        console = text_of(call("get_console_output", {}))
    # Known transient noise: CDN hiccups while assets stream.
    console = "\n".join(line for line in console.splitlines() if "HttpError: NetFail" not in line)
    errors = [line for line in console.splitlines() if ("Error" in line or "error" in line.lower().split(":")[0] or "Stack Begin" in line or "attempt to" in line) and "__Playtest" not in line]
    summary["console_errors"] = errors[-25:]
    with open(os.path.join(out_dir, "console.txt"), "w", encoding="utf-8") as file:
        file.write(console)
    check("no_console_errors", not errors, f"{len(errors)} lines (see console.txt)")

if not keep:
    call("start_stop_play", {"is_start": False})
summary["failed"] = failed
print(json.dumps(summary, indent=1, default=str))
proc.terminate()
sys.exit(1 if failed else 0)
