"""Phone preview of the match HUD in a running Studio Play session (no Device Emulator needed).

Usage (always run Python isolated):
  python3 -I tools/studio/playtest.py --keep-playing --out <scratch>/pt   # Play with a placed tower
  python3 -I tools/studio/phone_preview.py --out <scratch>/phone [--place 134681445336553] [--sizes 667x375,844x390]
  python3 -I tools/studio/phone_preview.py --lobby --place Lobby --out <scratch>/phone_lobby  # lobby HUD + windows

For every size it hides the real HUD, sets the Studio-only Workspace attributes UiPreviewViewport (the phone's
screen in points) and UiPreviewTouch (true), then mounts the match HUD pieces (MATCH corners, wave bar, READY,
tower hotbar, placement hints and the upgrade panel of the player's first tower) into a frame of that size in
the middle of the screen, below a 58 pt band standing in for Roblox's top bar, and saves a screen capture.
UiScale.compute / useIsTouch / PlacementHints / unitsUpgrade read those attributes, so the layout is the one a
phone would get. Afterwards it restores the HUD and removes the attributes. Never saves or publishes the place.
Limit: it is a layout check (sizes, overlaps, clipping), not a real device (no notch, no real touch input).
Variants (--only <name>): upgrade, placing, victory, menu, settings; lobby: hud, maps, crates, quests, shop, codes,
profile, settings. Known gap (2026-11-17): screen_capture tends to hang with the match menu open (the numbers
still come back). The match is kept alive with Base.God, since a lost base ends Play through the teleport.
"""
import json
import os
import subprocess
import sys
sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HERE = os.path.dirname(os.path.abspath(__file__))
args = sys.argv[1:]


def option(name, default):
    if name in args:
        return args[args.index(name) + 1]
    return default


place = option("--place", "134681445336553")
out = option("--out", "phone_preview")
# "WxH" = a touch screen; "WxHm" = mouse (desktop: no touch boost), e.g. 1366x768m.
sizes = []
for spec in option("--sizes", "667x375,844x390,932x430,1024x768,1366x768m").split(","):
    mouse = spec.endswith("m")
    w, h = (int(v) for v in spec.rstrip("m").split("x"))
    sizes.append((w, h, mouse))
os.makedirs(out, exist_ok=True)

MATCH_REQUIRES = r"""
local MatchMenu = require(App.MatchHud.MatchMenu)
local ReadyButton = require(App.MatchHud.ReadyButton)
local UpBar = require(App.UpBar.UpBar_healthBar)
local TowerHotbar = require(App.Units.TowerHotbar)
local PlacementHints = require(App.Units.PlacementHints)
local Upgrade = require(App.Units.unitsUpgrade)
"""

MATCH_MOUNT = r"""
local state = workspace:FindFirstChild("MatchState")
local function attr(name, fallback)
	local value = state and state:GetAttribute(name)
	return if value ~= nil then value else fallback
end
local tower
local towers = workspace:FindFirstChild("Towers")
for _, t in towers and towers:GetChildren() or {} do
	if t:GetAttribute("Owner") == player.UserId or t:GetAttribute("OwnerId") == player.UserId then tower = t break end
end
tower = tower or (towers and towers:FindFirstChildWhichIsA("Model"))
local root = ReactRoblox.createRoot(hud)
local function tree(settingsOpen)
	return e(React.Fragment, nil, {
	Menu = e(MatchMenu, {}),
	Bar = e(UpBar, { Health = attr("BaseHealth", 100), MaxHealth = attr("BaseMaxHealth", 100), WaveText = "WAVE 1 / 15",
		WaveStatus = "Next wave in 9s", Fighting = false }),
	Ready = e(ReadyButton, { Phase = "Preparation", TimeRemaining = 9, Wave = 1, Votes = 0, Needed = 1 }),
	Hotbar = e(TowerHotbar),
	Hints = __HINTS__ and e(PlacementHints),
	Upgrade = __UPGRADE__ and tower and e(Upgrade, { Tower = tower, PanelRef = React.createRef(), OnUpgrade = function() end,
		OnSell = function() end, OnClose = function() end }),
	MenuWindow = __MENU__ and e(require(App.MatchHud.MatchMenuWindow), { Wave = 5, TotalWaves = 15, WavesCleared = 4,
		OnClose = function() end, OnSettings = function() end, OnLeave = function() end }),
	SettingsWindow = __SETTINGS__ and e(require(App.Settings.Settings), { isOpen = settingsOpen, OnClose = function() end }),
})
end
-- Mounted closed, then opened, as RootUI does (Settings animates in on the change).
root:render(tree(false))
task.wait(0.3)
root:render(tree(true))
if __VICTORY__ then
	-- The result screen (imperative, its own ScreenGui): shown with the data RootUI passes at the end of a won match,
	-- then its content moves into the phone frame.
	local VictoryScreen = require(App.Victory.VictoryScreen)
	local Level = require(RS.Shared.Features.Services.LevelService.Level)
	root:render(nil)
	local before = {}
	for _, g in player.PlayerGui:GetChildren() do before[g] = true end
	VictoryScreen.Show({
		Mode = "Victory",
		Stats = {
			{ Icon = "Swords", Label = "WAVES CLEARED", Kind = "fraction", To = 15, Max = 15 },
			{ Icon = "Clock", Label = "TIME", Kind = "time", To = 754 },
			{ Icon = "Shield", Label = "BASE HEALTH", Kind = "fraction", From = 0, To = 82, Max = 100 },
		},
		Rewards = { Coins = 235, Gems = 12, XP = 410 },
		Base = { Coins = 150, Gems = 5, XP = 300 },
		Bonuses = { FirstWin = true, Streak = 3, StreakBonus = 35, BoostCoins = false, BoostXP = false, BoostLuck = false },
		Chest = { Count = 1, Coins = 50, Gems = 2 },
		Level = { Before = 11, XPBefore = 144, Gained = 410, Needed = Level.GetNeededExperience },
		OnPlayAgain = function() end,
		OnMainMenu = function() end,
		ReturnAt = function() return workspace:GetServerTimeNow() + 25 end,
	})
	task.wait(0.2)
	for _, g in player.PlayerGui:GetChildren() do
		if not before[g] and g:IsA("ScreenGui") and g ~= gui then
			for _, child in g:GetChildren() do child.Parent = hud end
			g.Enabled = false
		end
	end
	gui.Enabled = true
	task.wait(7) -- the entrance animations (buttons come last)
end
"""

# Lobby: the HUD alone or with one of its windows open (__WINDOW__ = "" or a window module path under App).
LOBBY_REQUIRES = r"""
local LobbyHud = require(App.Lobby.Hud.LobbyHud)
"""

LOBBY_MOUNT = r"""
local windowPath = "__WINDOW__"
local window = nil
local previewPad, padAttribute, oldPad
if windowPath == "@maps" then
	local shared = require(RS.Shared.Features.Services.Parties.PartyShared)
	padAttribute = shared.PlayerPadAttribute
	oldPad = player:GetAttribute(padAttribute)
	previewPad = Instance.new("Model")
	previewPad.Name = "PhonePreviewPartyPad"
	previewPad:SetAttribute("PadId", -1)
	previewPad:SetAttribute("Leader", player.UserId)
	previewPad:SetAttribute("MapName", "Sky Island")
	previewPad:SetAttribute("Status", shared.Status.Waiting)
	previewPad:SetAttribute("Count", 1)
	previewPad:SetAttribute("Max", 4)
	previewPad:SetAttribute("TimeLeft", 12)
	previewPad:AddTag(shared.Tag)
	previewPad.Parent = workspace
	player:SetAttribute(padAttribute, -1)
elseif windowPath ~= "" then
	local module = App
	for part in string.gmatch(windowPath, "[^.]+") do module = module[part] end
	window = require(module)
	if type(window) == "table" and window.Component then window = window.Component end
end
local root = ReactRoblox.createRoot(hud)
root:render(e(React.Fragment, nil, {
	Hud = e(LobbyHud, {
		OnSelectMap = previewPad and function(name) previewPad:SetAttribute("MapName", name) end,
		actions = previewPad and { Leave = function() end },
	}),
	-- UserId: the profile card shows the tester's own card (real numbers from the server).
	-- isOpen: the Settings window renders only while open.
	Window = window and e(window, { OnClose = function() end, UserId = player.UserId, isOpen = true }),
}))
"""

INNER = r"""
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local React = require(RS.Packages.React)
local ReactRoblox = require(RS.Packages.ReactRoblox)
local App = RS.Shared.Source.Features.App
__MOUNT_REQUIRES__
local e = React.createElement
local player = Players.LocalPlayer
local W, H, TOPBAR = __W__, __H__, 58

workspace:SetAttribute("UiPreviewViewport", Vector2.new(W, H))
workspace:SetAttribute("UiPreviewTouch", __TOUCH__)
local hidden = {}
for _, gui in player.PlayerGui:GetChildren() do
	if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "PhonePreview" then
		gui.Enabled = false
		table.insert(hidden, gui)
	end
end
local old = player.PlayerGui:FindFirstChild("PhonePreview")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "PhonePreview"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 500
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ResetOnSpawn = false
gui.Parent = player.PlayerGui
-- The phone: its outline, a dark band for Roblox's top bar, and the HUD area below it.
local phone = Instance.new("Frame")
phone.Size = UDim2.fromOffset(W, H)
phone.Position = UDim2.fromScale(0.5, 0.5)
phone.AnchorPoint = Vector2.new(0.5, 0.5)
phone.BackgroundTransparency = 1
phone.Parent = gui
-- --fit: shown smaller when the Studio window is smaller than the phone. Only for looking: windows that size
-- themselves from their parent's AbsoluteSize (Crates, Shop) shrink twice under the zoom, so their numbers and
-- look are wrong with --fit; without it the capture may be cropped but every number is the phone's.
local zoom = if __FIT__ then math.min(1, (gui.AbsoluteSize.X - 16) / W, (gui.AbsoluteSize.Y - 16) / H) else 1
local zoomScale = Instance.new("UIScale")
zoomScale.Scale = zoom
zoomScale.Parent = phone
local stroke = Instance.new("UIStroke")
stroke.Thickness = 4
stroke.Color = Color3.fromRGB(255, 60, 200)
stroke.Parent = phone
local band = Instance.new("Frame")
band.Size = UDim2.new(1, 0, 0, TOPBAR)
band.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
band.BackgroundTransparency = 0.75
band.ZIndex = 0
band.BorderSizePixel = 0
band.Parent = phone
local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, -20, 1, 0)
label.Position = UDim2.fromOffset(10, 0)
label.BackgroundTransparency = 1
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextColor3 = Color3.new(1, 1, 1)
label.Font = Enum.Font.GothamBold
label.TextSize = 16
label.TextTransparency = 0.4
label.ZIndex = 0
label.Text = ("top bar | %dx%d %s"):format(W, H, if __TOUCH__ then "touch" else "mouse")
label.Parent = band
local hud = Instance.new("Frame")
hud.Size = UDim2.new(1, 0, 1, -TOPBAR)
hud.Position = UDim2.fromOffset(0, TOPBAR)
hud.BackgroundTransparency = 1
hud.ClipsDescendants = false -- the wave bar sits in the top bar row on purpose (UpBar_healthBar)
hud.Parent = phone
__MOUNT__
task.wait(1.5)
-- Overlap report: every visible GuiObject's screen rect, grouped by mounted piece.
local report = { size = { W, H }, zoom = zoom, scale = require(App.Common.UiScale).compute(), pieces = {} }
local hudPos, hudSize = hud.AbsolutePosition, hud.AbsoluteSize
for _, top in hud:GetChildren() do
	if top:IsA("GuiObject") then
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		for _, d in top:GetDescendants() do
			-- Contents of a scroll list count as its visible area (the list itself), not where they scrolled to.
			local inScroll = d:FindFirstAncestorWhichIsA("ScrollingFrame") ~= nil
			local drawn = d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("ImageLabel") or d:IsA("ImageButton") or d:IsA("ScrollingFrame")
			if d:IsA("GuiObject") and d.Visible and d.AbsoluteSize.X > 2 and drawn and not inScroll then
				minX = math.min(minX, d.AbsolutePosition.X); minY = math.min(minY, d.AbsolutePosition.Y)
				maxX = math.max(maxX, d.AbsolutePosition.X + d.AbsoluteSize.X); maxY = math.max(maxY, d.AbsolutePosition.Y + d.AbsoluteSize.Y)
			end
		end
		if minX < math.huge then
			table.insert(report.pieces, { name = top.Name, x = math.floor((minX - hudPos.X) / zoom), y = math.floor((minY - hudPos.Y) / zoom),
				w = math.floor((maxX - minX) / zoom), h = math.floor((maxY - minY) / zoom),
				outside = minX < hudPos.X - 1 or minY < hudPos.Y - 1 or maxX > hudPos.X + hudSize.X + 1 or maxY > hudPos.Y + hudSize.Y + 1 })
		end
	end
end
-- Result screen buttons: their height in points (finger guideline 44).
report.buttons = {}
if __MAPS__ then
	report.mapCards = {}
	for _, d in hud:GetDescendants() do
		if d:IsA("TextButton") and d.Parent.Name == "Cards" then
			local preview = d.Body.Preview
			local localPos = (d.AbsolutePosition - hudPos) / zoom
			local localSize = d.AbsoluteSize / zoom
			report.mapCards[d.Name] = {
				w = math.floor(localSize.X), h = math.floor(localSize.Y),
				loaded = preview.IsLoaded, selected = d.Body:FindFirstChild("Selected") ~= nil,
				interactive = d.Interactable,
				outside = localPos.X < -1 or localPos.Y < -1
					or localPos.X + localSize.X > hudSize.X / zoom + 1
					or localPos.Y + localSize.Y > hudSize.Y / zoom + 1,
			}
		end
		if d:IsA("TextLabel") and d.Text == "LEAVE" then
			local button = d:FindFirstAncestorWhichIsA("TextButton")
			report.buttons.LEAVE = button and math.floor(button.AbsoluteSize.Y / zoom * 10) / 10
		end
	end
end
for _, d in hud:GetDescendants() do
	if d:IsA("TextLabel") and (d.Text == "PLAY AGAIN" or d.Text == "TRY AGAIN" or d.Text == "RETURN TO LOBBY") and d.Parent:IsA("GuiObject") then
		report.buttons[d.Text] = math.floor(d.Parent.AbsoluteSize.Y / zoom * 10) / 10
	end
end
workspace:SetAttribute("PhonePreviewReport", game:GetService("HttpService"):JSONEncode(report))
workspace:SetAttribute("PhonePreviewCleanup", true)
workspace:GetAttributeChangedSignal("PhonePreviewCleanup"):Wait()
root:unmount()
__CLEANUP__
pcall(function() require(App.Victory.VictoryScreen).Hide() end)
gui:Destroy()
for _, g in hidden do g.Enabled = true end
workspace:SetAttribute("UiPreviewViewport", nil)
workspace:SetAttribute("UiPreviewTouch", nil)
"""

INJECT = """
local p = game.Players:GetPlayers()[1]
for _, old in p.PlayerGui:GetChildren() do if old.Name == "PhonePreviewScript" then old:Destroy() end end
local ls = Instance.new("LocalScript")
ls.Name = "PhonePreviewScript"
ls.Source = [==[__SRC__]==]
ls.Parent = p.PlayerGui
return "injected"
"""

lobby = "--lobby" in args
if lobby:
    variants = [("hud", ""), ("maps", "@maps"), ("crates", "Summon.SummonWindow"), ("quests", "Quests.QuestsWindow"), ("shop", "Shop.ShopWindow"),
                ("codes", "Codes.CodesWindow"), ("profile", "Profile.ProfileCard"), ("settings", "Settings.Settings")]
else:
    variants = [("upgrade", None), ("placing", None), ("victory", None), ("menu", None), ("settings", None)]
if "--only" in args:
    variants = [v for v in variants if v[0] == option("--only", "")]

steps = []
if not lobby:
    # Keep the match from ending under the preview (a lost base ends it, and the return teleport closes Play).
    steps.append({"label": "god base", "tool": "execute_luau", "args": {"studio_id": "$STUDIO", "datamodel_type": "Server",
                  "code": "require(game.ServerScriptService.Server.Services.BaseService.BaseService).God = true return 'god base on'"}})
for w, h, mouse in sizes:
    for variant, window in variants:
        if lobby:
            src = INNER.replace("__MOUNT_REQUIRES__", LOBBY_REQUIRES).replace("__MOUNT__", LOBBY_MOUNT.replace("__WINDOW__", window))
        else:
            hints = "true" if variant == "placing" else "false"
            upgrade = "true" if variant in ("upgrade", "victory") else "false"
            src = INNER.replace("__MOUNT_REQUIRES__", MATCH_REQUIRES).replace("__MOUNT__", MATCH_MOUNT)
            src = src.replace("__HINTS__", hints).replace("__UPGRADE__", upgrade).replace("__VICTORY__", "true" if variant == "victory" else "false")
            src = src.replace("__MENU__", "true" if variant == "menu" else "false").replace("__SETTINGS__", "true" if variant == "settings" else "false")
        src = src.replace("__MAPS__", "true" if variant == "maps" else "false")
        src = src.replace("__CLEANUP__", 'player:SetAttribute(padAttribute, oldPad)\npreviewPad:Destroy()' if variant == "maps" else "")
        src = src.replace("__W__", str(w)).replace("__H__", str(h)).replace("__TOUCH__", "false" if mouse else "true").replace("__FIT__", "true" if "--fit" in args else "false")
        tag = f"{w}x{h}{'m' if mouse else ''}_{variant}"
        steps += [
            {"label": f"mount {tag}", "tool": "execute_luau", "args": {"studio_id": "$STUDIO", "datamodel_type": "Server", "code": INJECT.replace("__SRC__", src)}},
            {"sleep": 12 if variant == "victory" else 4},
            {"label": f"report {tag}", "max": 8000, "tool": "execute_luau", "args": {"studio_id": "$STUDIO", "datamodel_type": "Client",
             "code": "local r = workspace:GetAttribute('PhonePreviewReport') workspace:SetAttribute('PhonePreviewReport', nil) return r or 'none'"}},
            {"label": f"shot {tag}", "tool": "screen_capture", "save": os.path.join(os.path.abspath(out), f"phone_{tag}.jpg"),
             "args": {"studio_id": "$STUDIO", "capture_id": f"Phone{w}{h}{variant}"}},
            {"label": f"shot2 {tag}", "tool": "screen_capture", "save": os.path.join(os.path.abspath(out), f"phone_{tag}.jpg"),
             "args": {"studio_id": "$STUDIO", "capture_id": f"Phone{w}{h}{variant}b"}},
            {"label": f"cleanup {tag}", "tool": "execute_luau", "args": {"studio_id": "$STUDIO", "datamodel_type": "Client",
             "code": "workspace:SetAttribute('PhonePreviewCleanup', false) return 'ok'"}},
            {"sleep": 1},
        ]
steps_path = os.path.join(os.path.abspath(out), "steps.json")
with open(steps_path, "w", encoding="utf-8") as f:
    json.dump(steps, f)
subprocess.run([sys.executable, "-I", os.path.join(HERE, "studio_mcp.py"), "--place", place, "batch", steps_path], check=False)
