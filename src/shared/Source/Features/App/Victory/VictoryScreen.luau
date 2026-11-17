-- Match result screen (Victory / Defeat) built from the end-menu kit (art/endmenu, Ids.EndMenu):
-- emblem + title banner, a stats panel, reward cards, the level/XP bar and two buttons.
-- Everything arrives in a sequence: the emblem drops, the banner slams, stat rows slide in and count
-- up, reward cards flip open one by one and count their amount, then the XP bar fills (with a
-- level-up if the reward crosses one) and the buttons rise. While it is open the player's controls,
-- the camera and world clicks are locked.
--
-- VictoryScreen.Show({
--     Mode = "Victory",                -- "Victory" or "Defeat"
--     Subtitle = "BASE SECURED",       -- optional, the theme has a default
--     Stats = {                        -- up to 3 rows; Kind "fraction" (From/To of Max) or "time" (seconds)
--         { Icon = "Swords", Label = "WAVES CLEARED", Kind = "fraction", From = 0, To = 30, Max = 30 },
--         { Icon = "Clock", Label = "TIME", Kind = "time", To = 1122 },
--         { Icon = "Shield", Label = "BASE HEALTH", Kind = "fraction", From = 0, To = 820, Max = 1000 },
--     },
--     Rewards = { Coins = 350, Gems = 25, XP = 1200 },   -- totals, bonuses applied (chest not included)
--     Base = { Coins = 175, Gems = 12, XP = 600 },       -- optional: before the bonuses
--     Bonuses = { FirstWin = true, Streak = 3, StreakBonus = 20 }, -- optional, StreakBonus in percent
--     Chest = { Count = 2, Coins = 240, Gems = 8 },      -- optional: elite chests, opened after the cards
--     Level = { Before = 12, XPBefore = 600, Gained = 1200, Needed = Level.GetNeededExperience },
--                                      -- the XP bar animates from here; Needed(level) = XP to the next level
--     OnPlayAgain = function() end,
--     OnMainMenu = function() end,
--     ReturnAt = function() return serverTime? end, -- optional: shows "Returning to lobby in N"
-- })
-- VictoryScreen.Hide()
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Ids = require(ReplicatedStorage.Shared.Source.Game.AssetsIds.Ids)
local PlacementState = require(ReplicatedStorage.Shared.Features.Services.TowersServices.PlacementState)
local soundController = require(ReplicatedStorage.Shared.Features.Services.SoundController.soundController)

local Art = Ids.EndMenu
local RewardArt = Ids.Rewards
local RETURN_TEXT = "Returning to lobby in %d"
local LEAVING_TEXT_TIME = 6 -- seconds "Teleporting..." stays after a button click
local MIN_BUTTON_HEIGHT = 46 -- screen pixels; Apple/Google finger guideline is 44

-- The layout is drawn on a W x H canvas (the mockup's pixels); the stage scales it to the screen.
local W, H = 1260, 990
-- The mockup's layout is shifted down by TOP so the emblem above the banner fits on the stage.
local TOP = 40
local TEXT_FONT = Enum.Font.GothamBlack
local OUTLINE = Color3.fromRGB(12, 16, 26)

-- Kit pieces drawn 9-sliced: SliceCenter in the picture's pixels and k = drawn canvas px per picture px.
local SLICE = {
	MainPanel = { Rect.new(44, 44, 554, 213), 1 },
	StatsPanel = { Rect.new(44, 44, 550, 185), 1 },
	StatRow = { Rect.new(40, 36, 562, 73), 0.59 },
	StatValue = { Rect.new(40, 40, 363, 93), 0.42 },
	LevelBadge = { Rect.new(40, 40, 435, 111), 0.52 },
	XPTrack = { Rect.new(44, 36, 556, 72), 0.76 },
	XPFill = { Rect.new(33, 12, 553, 54), 0.5 },
	Button = { Rect.new(44, 44, 561, 121), 0.64 },
}

local THEMES = {
	Victory = {
		Title = "VICTORY",
		Subtitle = "BASE SECURED",
		PlayText = "PLAY AGAIN",
		Art = Art.Victory,
		Accent = Color3.fromRGB(70, 230, 110),
		Glow = Color3.fromRGB(255, 214, 92),
		TitleGradient = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 250, 225), Color3.fromRGB(255, 226, 150) },
		Backdrop = { Color3.fromRGB(26, 40, 58), Color3.fromRGB(4, 8, 14) },
		ButtonStroke = Color3.fromRGB(10, 70, 24),
	},
	Defeat = {
		Title = "DEFEAT",
		Subtitle = "THE BASE WAS DESTROYED",
		PlayText = "TRY AGAIN",
		Art = Art.Defeat,
		Accent = Color3.fromRGB(255, 70, 70),
		Glow = Color3.fromRGB(255, 60, 50),
		TitleGradient = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(236, 238, 244), Color3.fromRGB(190, 194, 210) },
		Backdrop = { Color3.fromRGB(50, 14, 24), Color3.fromRGB(6, 4, 10) },
		ButtonStroke = Color3.fromRGB(90, 8, 16),
	},
}
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 214, 92), Color3.fromRGB(110, 240, 140), Color3.fromRGB(124, 211, 255),
	Color3.fromRGB(200, 150, 255), Color3.new(1, 1, 1),
}

local LOCK_ACTION = "VictoryScreenLock"
local LOCKED_KEYS = {
	Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down,
	Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Space, Enum.KeyCode.Tab, Enum.KeyCode.Q, Enum.KeyCode.E,
	Enum.KeyCode.R, Enum.KeyCode.F, Enum.KeyCode.X, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonA, Enum.KeyCode.Thumbstick1,
	Enum.KeyCode.Thumbstick2, Enum.UserInputType.MouseWheel,
}

local random = Random.new()
local VictoryScreen = {}
local current: { cleanup: () -> () }? = nil

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(className)
	for key, value in pairs(props) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function thousands(value: number): string
	local text = tostring(math.floor(value + 0.5))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function clock(seconds: number): string
	seconds = math.floor(seconds + 0.5)
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Position/Size of a box centered at (cx, cy) on the canvas.
local function at(cx: number, cy: number, w: number, h: number)
	return {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(cx / W, (cy + TOP) / H),
		Size = UDim2.fromScale(w / W, h / H),
	}
end

local function merge(a: { [string]: any }, b: { [string]: any }?)
	local result = table.clone(a)
	for key, value in pairs(b or {}) do
		result[key] = value
	end
	return result
end

-- Controls -------------------------------------------------------------------------------

local function lockControls(): () -> ()
	local player = Players.LocalPlayer
	local camera = Workspace.CurrentCamera
	local restore = {}

	PlacementState.Action("cancel")
	PlacementState.SetActive(false)

	local controls = nil
	pcall(function()
		local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 2) :: any)
		controls = playerModule:GetControls()
		controls:Disable()
	end)

	ContextActionService:BindActionAtPriority(LOCK_ACTION, function()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 100, table.unpack(LOCKED_KEYS))

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		restore.walkSpeed, restore.jumpPower, restore.jumpHeight = humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight
		humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = 0, 0, 0
	end

	if camera then
		restore.cameraType = camera.CameraType
		camera.CameraType = Enum.CameraType.Scriptable
	end
	restore.mouseBehavior = UserInputService.MouseBehavior
	restore.mouseIcon = UserInputService.MouseIconEnabled
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true

	return function()
		ContextActionService:UnbindAction(LOCK_ACTION)
		if controls then pcall(function() controls:Enable() end) end
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = restore.walkSpeed, restore.jumpPower, restore.jumpHeight
		end
		if camera and restore.cameraType then camera.CameraType = restore.cameraType end
		UserInputService.MouseBehavior = restore.mouseBehavior
		UserInputService.MouseIconEnabled = restore.mouseIcon
	end
end

-- Hides every other ScreenGui so the result screen really owns the whole screen.
local function hideOtherGuis(playerGui: PlayerGui, keep: Instance): () -> ()
	local hidden = {}
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui ~= keep and gui:IsA("ScreenGui") and gui.Enabled then
			gui.Enabled = false
			table.insert(hidden, gui)
		end
	end
	return function()
		for _, gui in ipairs(hidden) do
			if gui.Parent then gui.Enabled = true end
		end
	end
end

-- Show / Hide ----------------------------------------------------------------------------

function VictoryScreen.Hide()
	if current then
		local cleanup = current.cleanup
		current = nil
		cleanup()
	end
end

function VictoryScreen.IsOpen(): boolean
	return current ~= nil
end

function VictoryScreen.Show(data)
	VictoryScreen.Hide()
	data = data or {}
	local mode = if data.Mode == "Defeat" then "Defeat" else "Victory"
	local theme = THEMES[mode]
	local won = mode == "Victory"
	local rewards = data.Rewards or {}

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local alive = true
	local tweens: { Tween } = {}
	local connections: { RBXScriptConnection } = {}
	local function tween(object: Instance, duration: number, goal, style: Enum.EasingStyle?, direction: Enum.EasingDirection?, delay: number?)
		local function start()
			if not alive or not object.Parent then return end
			local t = TweenService:Create(object, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
			table.insert(tweens, t)
			t:Play()
		end
		if delay and delay > 0 then task.delay(delay, start) else start() end
	end
	local function after(delay: number, callback: () -> ())
		task.delay(delay, function()
			if alive then callback() end
		end)
	end
	local function every(callback: (dt: number, time: number) -> ())
		local time = 0
		table.insert(connections, RunService.RenderStepped:Connect(function(dt)
			time += dt
			callback(dt, time)
		end))
	end

	-- Canvas px -> screen px; slices and outlines follow it when the screen size changes.
	local canvasScale = 1
	local slices: { { any } } = {}
	local strokes: { { any } } = {}

	local function image(props: { [string]: any }, parent: Instance?, slice: { any }?)
		local label = new(props.ClassName or "ImageLabel", merge({
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
		}, (function()
			local copy = table.clone(props)
			copy.ClassName = nil
			return copy
		end)()), parent)
		if slice then
			label.ScaleType = Enum.ScaleType.Slice
			label.SliceCenter = slice[1]
			label.SliceScale = slice[2] * canvasScale
			table.insert(slices, { label, slice[2] })
		end
		return label
	end
	local function outline(parent: Instance, thickness: number, color: Color3?)
		local stroke = new("UIStroke", {
			Color = color or OUTLINE,
			Thickness = thickness * canvasScale,
			LineJoinMode = Enum.LineJoinMode.Round,
		}, parent)
		table.insert(strokes, { stroke, thickness })
		return stroke
	end
	local function text(props: { [string]: any }, parent: Instance, thickness: number?, strokeColor: Color3?)
		local label = new("TextLabel", merge({
			BackgroundTransparency = 1,
			Font = TEXT_FONT,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
		}, props), parent)
		outline(label, thickness or 3, strokeColor)
		return label
	end
	local scales: { [Instance]: UIScale } = {}
	local function scaleOf(object: Instance): UIScale
		local found = scales[object]
		if not found then
			found = new("UIScale", { Scale = 1 }, object)
			scales[object] = found
		end
		return found :: UIScale
	end
	-- Scale punch: jumps to `from` and springs back to 1.
	local function pop(object: Instance, from: number, duration: number?, delay: number?)
		local scale = scaleOf(object)
		local function start()
			scale.Scale = from
			tween(scale, duration or 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		if delay and delay > 0 then after(delay, start) else start() end
	end
	-- Fades an element and everything in it in from fully transparent.
	local function fadeIn(root: Instance, duration: number, delay: number?)
		local objects = root:GetDescendants()
		table.insert(objects, root)
		for _, object in objects do
			local key = if object:IsA("ImageLabel") or object:IsA("ImageButton") then "ImageTransparency"
				elseif object:IsA("TextLabel") then "TextTransparency"
				elseif object:IsA("UIStroke") then "Transparency"
				else nil
			if key then
				local goal = (object :: any)[key]
				;(object :: any)[key] = 1
				tween(object, duration, { [key] = goal }, nil, nil, delay)
			end
		end
	end
	-- A white copy of a kit picture with a moving light band, masked to the picture's shape.
	local function shine(target: ImageLabel, slice: { any }?, strength: number?)
		local overlay = image({
			Image = target.Image,
			ScaleType = target.ScaleType,
			Size = UDim2.fromScale(1, 1),
			ImageColor3 = Color3.new(1, 1, 1),
			ZIndex = 40,
		}, target, slice)
		local peak = 1 - (strength or 0.55)
		local gradient = new("UIGradient", {
			Rotation = 20,
			Offset = Vector2.new(-1.5, 0),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(0.5, peak),
				NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1),
			}),
		}, overlay)
		return function(duration: number?)
			gradient.Offset = Vector2.new(-1.5, 0)
			tween(gradient, duration or 0.7, { Offset = Vector2.new(1.5, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		end
	end
	local function countUp(label: TextLabel, from: number, to: number, duration: number, format: (number) -> string, delay: number, ticks: number?)
		label.Text = format(from)
		after(delay, function()
			local value = Instance.new("NumberValue")
			value.Value = from
			value.Changed:Connect(function(shown)
				label.Text = format(shown)
			end)
			tween(value, duration, { Value = to }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			for step = 1, ticks or 0 do
				-- Ticks slow down with the Quart easing.
				after((step / (ticks or 1)) ^ 1.8 * duration, function()
					soundController:PlaySFX("CoinTick")
				end)
			end
			after(duration + 0.05, function()
				label.Text = format(to)
				value:Destroy()
			end)
		end)
	end

	-- Background -----------------------------------------------------------------------

	local gui = new("ScreenGui", {
		Name = "VictoryScreen", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 200,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local blur = new("BlurEffect", { Name = "VictoryBlur", Size = 0 }, Lighting)
	tween(blur, 0.4, { Size = 16 })
	-- Blocks every click behind the screen.
	local backdrop = new("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
		BorderSizePixel = 0, Text = "", AutoButtonColor = false, Active = true, Modal = true, ZIndex = 1,
	}, gui)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(theme.Backdrop[1], theme.Backdrop[2]) }, backdrop)
	tween(backdrop, 0.35, { BackgroundTransparency = 0.35 })
	-- Coloured glow from the top (gold for a win, red for a loss); it breathes slowly.
	local vignette = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.15), Size = UDim2.fromScale(1.3, 1.1),
		BackgroundColor3 = theme.Glow, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2,
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, vignette)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1),
		}),
	}, vignette)
	tween(vignette, 0.6, { BackgroundTransparency = 0 }, nil, nil, 0.1)
	local flash = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = theme.Glow, BackgroundTransparency = 0.45,
		BorderSizePixel = 0, ZIndex = 60,
	}, gui)
	tween(flash, 0.6, { BackgroundTransparency = 1 })

	-- The stage keeps the canvas proportions on any screen.
	local stage = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.96, 0.94), BackgroundTransparency = 1, ZIndex = 3,
	}, gui)
	new("UIAspectRatioConstraint", { AspectRatio = W / H }, stage)
	-- Sparkle bursts and confetti fly above everything.
	local effects = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20 }, stage)

	local function burst(cx: number, cy: number, count: number, color: Color3, spread: number, size: number?, parent: Instance?)
		for _ = 1, count do
			local sparkleSize = (size or 34) * random:NextNumber(0.6, 1.2)
			local sparkle = image(merge(at(cx, cy, sparkleSize, sparkleSize), {
				Image = Art.Sparkle, ImageColor3 = color, Rotation = random:NextNumber(0, 90),
			}), parent or effects)
			local angle = random:NextNumber(0, math.pi * 2)
			local distance = random:NextNumber(0.5, 1) * spread
			local duration = random:NextNumber(0.5, 0.8)
			tween(sparkle, duration, {
				Position = UDim2.fromScale((cx + math.cos(angle) * distance) / W, (cy + math.sin(angle) * distance + TOP) / H),
				Rotation = sparkle.Rotation + random:NextNumber(90, 200),
				ImageTransparency = 1,
				Size = UDim2.fromScale(sparkleSize * 0.3 / W, sparkleSize * 0.3 / H),
			}, Enum.EasingStyle.Quart)
			task.delay(duration + 0.05, function() sparkle:Destroy() end)
		end
	end

	-- Light rays (win) or a red pulse (loss) behind the emblem.
	local rays = new("Frame", merge(at(630, 85, 620, 620), { BackgroundTransparency = 1, ZIndex = 1 }), stage)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, rays)
	local raysScale = scaleOf(rays)
	raysScale.Scale = 0
	if won then
		for index = 1, 12 do
			local ray = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(if index % 2 == 0 then 0.045 else 0.075, 1), Rotation = (index - 1) * 15,
				BackgroundColor3 = theme.Glow, BorderSizePixel = 0, ZIndex = 1,
			}, rays)
			new("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.9),
					NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(0.7, 0.9), NumberSequenceKeypoint.new(1, 1),
				}),
			}, ray)
		end
	else
		-- Many faint stacked circles fake a soft radial glow (UI has no radial gradient).
		for step = 0, 9 do
			local size = 0.9 - step * 0.065
			local glow = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(size, size),
				BackgroundColor3 = theme.Glow, BackgroundTransparency = 0.955, BorderSizePixel = 0, ZIndex = 1,
			}, rays)
			new("UICorner", { CornerRadius = UDim.new(1, 0) }, glow)
		end
	end
	tween(raysScale, 0.7, { Scale = 1 }, Enum.EasingStyle.Back, nil, 0.15)

	-- Header: emblem + title banner ---------------------------------------------------------

	local emblem = image(merge(at(630, -140, 300, 216), { Image = theme.Art.Emblem, ZIndex = 3 }), stage)
	local EMBLEM_Y = 85
	tween(emblem, 0.6, { Position = UDim2.fromScale(0.5, (EMBLEM_Y + TOP) / H) }, Enum.EasingStyle.Bounce, nil, 0.1)
	if won then
		emblem.Rotation = -18
		tween(emblem, 0.8, { Rotation = 0 }, Enum.EasingStyle.Elastic, nil, 0.1)
	end
	local floating = false
	after(0.8, function()
		floating = true
		burst(630, EMBLEM_Y, 10, theme.Glow, 190, 40)
	end)

	local banner = image(merge(at(630, 206, 920, 232), { Image = theme.Art.Banner, ZIndex = 4 }), stage)
	local title = text({
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.39), Size = UDim2.fromScale(0.6, 0.4),
		Text = theme.Title, ZIndex = 5,
	}, banner, 5)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, theme.TitleGradient[1]), ColorSequenceKeypoint.new(0.5, theme.TitleGradient[2]),
			ColorSequenceKeypoint.new(1, theme.TitleGradient[3]),
		}),
	}, title)
	-- Shine sweeping over the title letters every few seconds.
	local titleShine = text({
		AnchorPoint = title.AnchorPoint, Position = title.Position, Size = title.Size, Text = theme.Title, ZIndex = 6,
	}, banner, 0)
	local titleShineGradient = new("UIGradient", {
		Rotation = 20, Offset = Vector2.new(-1.3, 0),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.05),
			NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1),
		}),
		Color = ColorSequence.new(if won then Color3.fromRGB(255, 240, 170) else Color3.fromRGB(255, 160, 150)),
	}, titleShine)
	local subtitle = text({
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.795), Size = UDim2.fromScale(0.58, 0.13),
		Text = string.upper(data.Subtitle or theme.Subtitle), MaxVisibleGraphemes = 0, ZIndex = 5,
	}, banner, 2.5)

	-- The banner slams in from big, the screen shakes, then the subtitle types itself out.
	pop(banner, 2.6, 0.45, 0.25)
	scaleOf(banner).Scale = 0
	banner.Rotation = if won then -5 else 4
	tween(banner, 0.45, { Rotation = 0 }, Enum.EasingStyle.Back, nil, 0.25)
	after(0.45, function()
		soundController:PlaySFX("TitleSlam")
		task.spawn(function()
			for step = 1, 7 do
				if not alive then return end
				local power = (8 - step) * (if won then 0.003 else 0.0045)
				stage.Position = UDim2.fromScale(0.5 + random:NextNumber(-power, power), 0.5 + random:NextNumber(-power, power))
				task.wait(0.03)
			end
			stage.Position = UDim2.fromScale(0.5, 0.5)
		end)
		local graphemes = Instance.new("IntValue")
		graphemes.Changed:Connect(function(value)
			subtitle.MaxVisibleGraphemes = value
		end)
		tween(graphemes, 0.5, { Value = utf8.len(subtitle.Text) or #subtitle.Text }, Enum.EasingStyle.Linear, nil, 0.15)
		after(0.8, function()
			subtitle.MaxVisibleGraphemes = -1
			graphemes:Destroy()
		end)
	end)
	task.spawn(function()
		task.wait(1)
		while alive do
			titleShineGradient.Offset = Vector2.new(-1.3, 0)
			tween(titleShineGradient, 0.8, { Offset = Vector2.new(1.3, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(3.2)
		end
	end)
	if not won then
		-- A broken title: it jitters a few times like a failing screen.
		task.spawn(function()
			task.wait(1.2)
			while alive do
				for _ = 1, 3 do
					title.Position = UDim2.fromScale(0.5 + random:NextNumber(-0.012, 0.012), 0.39 + random:NextNumber(-0.02, 0.02))
					title.TextColor3 = Color3.fromRGB(255, 190, 190)
					task.wait(0.04)
				end
				title.Position = UDim2.fromScale(0.5, 0.39)
				title.TextColor3 = Color3.new(1, 1, 1)
				task.wait(random:NextNumber(2.2, 3.6))
			end
		end)
	end

	-- Body: the main panel and everything on it rises from below ---------------------------

	local body = new("Frame", {
		Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0.1), BackgroundTransparency = 1, ZIndex = 2,
	}, stage)
	tween(body, 0.55, { Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Back, nil, 0.35)
	local mainPanel = image(merge(at(630, 577.5, 1260, 645), { Image = Art.MainPanel, ZIndex = 1 }), body, SLICE.MainPanel)
	fadeIn(mainPanel, 0.35, 0.35)

	-- Close: hides the results (the server still sends everyone back to the lobby).
	local close = image(merge(at(1196, 304, 58, 58), { ClassName = "ImageButton", Image = Art.Close, ZIndex = 5 }), body)
	scaleOf(close).Scale = 0
	pop(close, 0, 0.35, 3.2)
	close.MouseEnter:Connect(function()
		tween(close, 0.25, { Rotation = 90 }, Enum.EasingStyle.Back)
	end)
	close.MouseLeave:Connect(function()
		tween(close, 0.25, { Rotation = 0 }, Enum.EasingStyle.Back)
	end)
	close.Activated:Connect(function()
		task.defer(VictoryScreen.Hide)
	end)

	-- Stats -----------------------------------------------------------------------------

	local statsPanel = image(merge(at(327.5, 478.5, 585, 267), { Image = Art.StatsPanel, ZIndex = 2 }), body, SLICE.StatsPanel)
	fadeIn(statsPanel, 0.35, 0.45)
	for index, stat in ipairs(data.Stats or {}) do
		if index > 3 then break end
		local y = 401 + (index - 1) * 80
		local row = new("Frame", merge(at(328, y, 550, 64), { BackgroundTransparency = 1, ZIndex = 3 }), body)
		image({ Image = Art.StatRow, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, row, SLICE.StatRow)
		local icon = image({
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.0945, 0.5), Size = UDim2.fromScale(0.095, 0.82),
			Image = Art[stat.Icon] or Art.Swords, ZIndex = 2,
		}, row)
		text({
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.165, 0.5), Size = UDim2.fromScale(0.5, 0.44),
			Text = string.upper(stat.Label or ""), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2,
		}, row, 2.5)
		local badge = image({
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.845, 0.5), Size = UDim2.fromScale(0.31, 0.88),
			Image = theme.Art.StatValue, ZIndex = 2,
		}, row, SLICE.StatValue)
		local value = text({
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.56),
			Text = "", ZIndex = 3,
		}, badge, 2.5)

		local delay = 0.75 + (index - 1) * 0.14
		row.Position = UDim2.fromScale((328 - 70) / W, (y + TOP) / H)
		tween(row, 0.45, { Position = UDim2.fromScale(328 / W, (y + TOP) / H) }, Enum.EasingStyle.Back, nil, delay)
		fadeIn(row, 0.3, delay)
		scaleOf(icon).Scale = 0
		pop(icon, 0, 0.4, delay + 0.15)

		local format = if stat.Kind == "time" then clock
			else function(shown: number)
				return if stat.Max then `{thousands(shown)} / {thousands(stat.Max)}` else thousands(shown)
			end
		countUp(value, stat.From or 0, stat.To or 0, 0.9, format, delay + 0.2, 0)
		after(delay + 1.15, function()
			pop(badge, 1.18, 0.3)
			-- A loss stat that ended at zero (base health) shakes red.
			if not won and stat.Max and (stat.To or 0) <= 0 then
				value.TextColor3 = Color3.fromRGB(255, 120, 120)
				task.spawn(function()
					for step = 1, 8 do
						if not alive then return end
						badge.Rotation = (if step % 2 == 0 then 1 else -1) * (9 - step) * 0.8
						task.wait(0.035)
					end
					badge.Rotation = 0
				end)
			end
		end)
	end

	-- Rewards ---------------------------------------------------------------------------

	local rewardsPanel = image(merge(at(932.5, 478.5, 595, 262), { Image = Art.RewardsPanel, ScaleType = Enum.ScaleType.Stretch, ZIndex = 2 }), body)
	fadeIn(rewardsPanel, 0.35, 0.5)
	local base = data.Base or {}
	local bonuses = data.Bonuses or {}
	local chest = data.Chest or {}
	local streakBonus = bonuses.StreakBonus or 0
	local anyBoost = bonuses.BoostCoins == true or bonuses.BoostXP == true or bonuses.BoostLuck == true
	local hasBonus = (won and (bonuses.FirstWin == true or streakBonus > 0)) or anyBoost
	local hasChest = (chest.Count or 0) > 0 and ((chest.Coins or 0) > 0 or (chest.Gems or 0) > 0)
	if not hasBonus then
		local rewardsTitle = text(merge(at(933, 381, 240, 34), { Text = "REWARDS", ZIndex = 3 }), body, 2.5)
		scaleOf(rewardsTitle).Scale = 0
		pop(rewardsTitle, 0, 0.4, 1.1)
	end

	local cards = {
		{ Key = "Coins", Art = Art.CardGold, Icon = Art.Coins, Amount = rewards.Coins or 0, Format = "+%s", Glow = Color3.fromRGB(255, 214, 92) },
		{ Key = "Gems", Art = Art.CardBlue, Icon = Art.Crystals, Amount = rewards.Gems or 0, Format = "+%s", Glow = Color3.fromRGB(110, 210, 255) },
		{ Key = "XP", Art = Art.CardPurple, Icon = Art.XPBadge, Amount = rewards.XP or 0, Format = "+%s XP", Glow = Color3.fromRGB(196, 130, 255), XP = true },
	}
	-- What each card shows right now, so the bonus and chest steps can count on from there.
	type CardState = { key: string, amount: TextLabel, value: number, format: (number) -> string, holder: Frame, sweep: (number?) -> (), cx: number, cy: number, glow: Color3, face: Frame }
	local cardStates: { CardState } = {}
	local CARD_START = 1.35
	local CARD_STEP = 0.45
	local icons: { { label: ImageLabel, phase: number } } = {}
	for index, card in ipairs(cards) do
		local cx, cy = 744 + (index - 1) * 191, 509
		local holder = new("Frame", merge(at(cx, cy, 178, 156), { BackgroundTransparency = 1, ZIndex = 3 }), body)
		-- The face is squeezed to zero width and opens like a flipping card.
		local face = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0, 1),
			BackgroundTransparency = 1, ZIndex = 1,
		}, holder)
		local cardImage = image({ Image = card.Art, ScaleType = Enum.ScaleType.Stretch, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, face)
		local sweep = shine(cardImage, nil, 0.6)
		local icon = image({
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, -0.2), Size = UDim2.fromScale(0.7, 0.56),
			Image = card.Icon, ImageTransparency = 1, ZIndex = 2,
		}, face)
		if card.XP then
			-- The kit's XP badge is blank: the letters ride on it and appear with it.
			local letters = text({
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.42, 0.42),
				Text = "XP", ZIndex = 3,
			}, icon, 2.5, Color3.fromRGB(46, 10, 90))
			fadeIn(letters, 0.3, CARD_START + (index - 1) * CARD_STEP + 0.15)
		end
		local amount = text({
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.81), Size = UDim2.fromScale(0.86, 0.23),
			Text = "", ZIndex = 3,
		}, face, 3)
		local function format(shown: number)
			return string.format(card.Format, thousands(shown))
		end
		amount.Text = format(0)
		-- With bonuses the card first counts the base amount, the bonus step adds the rest.
		local first = if hasBonus then math.min(base[card.Key] or card.Amount, card.Amount) else card.Amount
		table.insert(cardStates, {
			key = card.Key, amount = amount, value = first, format = format, holder = holder, sweep = sweep,
			cx = cx, cy = cy, glow = card.Glow, face = face,
		})

		local delay = CARD_START + (index - 1) * CARD_STEP
		after(delay, function()
			tween(face, 0.4, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Back)
			local ding = soundController:PlaySFX("StarDing")
			if ding then
				ding.PlaybackSpeed = 1 + (index - 1) * 0.15
			end
		end)
		tween(icon, 0.55, { Position = UDim2.fromScale(0.5, 0.38), ImageTransparency = 0 }, Enum.EasingStyle.Bounce, nil, delay + 0.15)
		icon.Rotation = -25
		tween(icon, 0.55, { Rotation = 0 }, Enum.EasingStyle.Back, nil, delay + 0.15)
		countUp(amount, 0, first, 0.9, format, delay + 0.3, if first > 0 then 6 else 0)
		after(delay + 1.25, function()
			pop(amount, 1.35, 0.3)
			pop(holder, 1.08, 0.3)
			sweep(0.6)
			burst(cx, cy, 8, card.Glow, 120, 32)
		end)
		after(delay + 0.75, function()
			table.insert(icons, { label = icon, phase = index * 1.3 })
		end)
		-- Every few seconds a light runs over the cards again, one after another.
		task.spawn(function()
			task.wait(delay + 4)
			while alive do
				sweep(0.7)
				task.wait(4)
			end
		end)
	end

	-- Counts a card on from what it shows now; pops it with a burst when done.
	local function countCard(state: CardState, to: number, duration: number, ticks: number)
		local from = state.value
		state.value = to
		countUp(state.amount, from, to, duration, state.format, 0, if to > from then ticks else 0)
		after(duration + 0.05, function()
			pop(state.amount, 1.4, 0.3)
			pop(state.holder, 1.1, 0.3)
			state.sweep(0.6)
			burst(state.cx, state.cy, 10, state.glow, 130, 34)
		end)
	end

	-- Bonuses: chips slam in where the REWARDS title would be, then every card counts on to its total
	-- and keeps the base amount crossed out above it.
	local BONUS_AT = CARD_START + 2 * CARD_STEP + 1.5
	if hasBonus then
		local chips = {}
		if bonuses.FirstWin then
			table.insert(chips, {
				Icon = RewardArt.Gift, Text = "FIRST WIN x2", Width = 214,
				Colors = { Color3.fromRGB(255, 226, 122), Color3.fromRGB(240, 168, 28) },
			})
		end
		local boostColors = { Color3.fromRGB(110, 190, 255), Color3.fromRGB(40, 110, 230) }
		if bonuses.BoostCoins then
			table.insert(chips, { Icon = if Ids.Inventory.BoostCoins ~= "" then Ids.Inventory.BoostCoins else Art.Coins, Text = "2x COINS", Width = 214, Colors = boostColors })
		end
		if bonuses.BoostXP then
			table.insert(chips, { Icon = if Ids.Inventory.BoostXP ~= "" then Ids.Inventory.BoostXP else Art.XPBadge, Text = "2x XP", Width = 214, Colors = { Color3.fromRGB(205, 150, 255), Color3.fromRGB(120, 60, 220) } })
		end
		if bonuses.BoostLuck and hasChest then
			table.insert(chips, { Icon = if Ids.Inventory.Lucky ~= "" then Ids.Inventory.Lucky else Art.Sparkle, Text = "LUCKY", Width = 214, Colors = { Color3.fromRGB(140, 240, 120), Color3.fromRGB(50, 170, 60) } })
		end
		if streakBonus > 0 then
			table.insert(chips, {
				Icon = RewardArt.Streak, Text = `{bonuses.Streak or 0} WINS +{streakBonus}%`, Width = 214,
				Colors = { Color3.fromRGB(255, 154, 60), Color3.fromRGB(232, 70, 28) },
			})
		end
		-- Up to 5 chips share the width above the reward cards (centered on them).
		local chipWidth = math.min(214, math.floor((580 - (#chips - 1) * 10) / #chips))
		for index, chip in ipairs(chips) do
			chip.Width = chipWidth
			local cx = 933 + (index - (#chips + 1) / 2) * (chipWidth + 10)
			local holder = new("Frame", merge(at(cx, 381, chip.Width, 44), {
				BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 4,
			}), body)
			new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, holder)
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(chip.Colors[1], chip.Colors[2]) }, holder)
			outline(holder, 3)
			image({
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(26 / chip.Width, 0.36),
				Size = UDim2.fromScale(56 / chip.Width, 56 / 44), Image = chip.Icon, ZIndex = 5,
			}, holder)
			text({
				AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(56 / chip.Width, 0.5),
				Size = UDim2.fromScale(1 - 66 / chip.Width, 0.56), Text = chip.Text, ZIndex = 5,
			}, holder, 2.5)
			local delay = BONUS_AT + (index - 1) * 0.3
			scaleOf(holder).Scale = 0
			holder.Rotation = if index == 1 then -8 else 8
			after(delay, function()
				pop(holder, 2.2, 0.4)
				tween(holder, 0.4, { Rotation = 0 }, Enum.EasingStyle.Back)
				soundController:PlaySFX("TitleSlam")
				burst(cx, 381, 12, chip.Colors[1], 140, 36)
			end)
		end
		local COUNT_AT = BONUS_AT + 0.3 * #chips + 0.25
		for index, state in ipairs(cardStates) do
			local total = (cards[index].Amount or 0)
			local baseValue = state.value
			if total <= baseValue then continue end
			local crossed = text({
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.655), Size = UDim2.fromScale(0.46, 0.13),
				Text = `<s>{state.format(baseValue)}</s>`, RichText = true, TextColor3 = Color3.fromRGB(200, 210, 232),
				TextTransparency = 1, ZIndex = 4,
			}, state.face, 2)
			local crossedStroke = crossed:FindFirstChildOfClass("UIStroke")
			if crossedStroke then crossedStroke.Transparency = 1 end
			local delay = COUNT_AT + (index - 1) * 0.12
			after(delay, function()
				tween(crossed, 0.25, { TextTransparency = 0.1 })
				if crossedStroke then tween(crossedStroke, 0.25, { Transparency = 0 }) end
				countCard(state, total, 0.7, 5)
			end)
		end
	end

	-- Elite chests open in their own scene over the screen: the chest drops, wobbles and opens on a
	-- click (or by itself), the coins and gems fly into their cards.
	local CHEST_AT = if hasBonus then BONUS_AT + 1.9 else BONUS_AT - 0.1
	local CHEST_LENGTH = 4.4 -- until the scene is gone when it opens by itself
	local AUTO_OPEN = 2.3
	if hasChest then
		after(CHEST_AT, function()
			local layer = new("TextButton", {
				Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(4, 8, 16), BackgroundTransparency = 1,
				BorderSizePixel = 0, Text = "", AutoButtonColor = false, Active = true, ZIndex = 45,
			}, gui)
			tween(layer, 0.3, { BackgroundTransparency = 0.12 })
			local scene = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = stage.Size,
				BackgroundTransparency = 1, ZIndex = 46,
			}, gui)
			new("UIAspectRatioConstraint", { AspectRatio = W / H }, scene)
			local CHEST_Y = 430
			local glowColor = Color3.fromRGB(196, 130, 255)

			local sceneRays = new("Frame", merge(at(630, CHEST_Y, 780, 780), { BackgroundTransparency = 1, ZIndex = 1 }), scene)
			new("UIAspectRatioConstraint", { AspectRatio = 1 }, sceneRays)
			for index = 1, 14 do
				local ray = new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(if index % 2 == 0 then 0.04 else 0.07, 1), Rotation = (index - 1) * (180 / 14),
					BackgroundColor3 = glowColor, BorderSizePixel = 0, ZIndex = 1,
				}, sceneRays)
				new("UIGradient", {
					Rotation = 90,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.88),
						NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(0.7, 0.88), NumberSequenceKeypoint.new(1, 1),
					}),
				}, ray)
			end
			local raysScaleObject = scaleOf(sceneRays)
			raysScaleObject.Scale = 0
			tween(raysScaleObject, 0.6, { Scale = 1 }, Enum.EasingStyle.Back, nil, 0.3)
			for step = 0, 7 do
				local size = 440 - step * 44
				local glow = new("Frame", merge(at(630, CHEST_Y, size, size), {
					BackgroundColor3 = if step > 4 then Color3.fromRGB(255, 230, 140) else glowColor,
					BackgroundTransparency = 0.93, BorderSizePixel = 0, ZIndex = 2,
				}), scene)
				new("UICorner", { CornerRadius = UDim.new(1, 0) }, glow)
			end

			local count = chest.Count or 1
			local heading = text(merge(at(630, 140, 640, 64), {
				Text = if count > 1 then `ELITE CHEST x{count}` else "ELITE CHEST",
				TextColor3 = Color3.fromRGB(232, 210, 255), ZIndex = 10,
			}), scene, 4, Color3.fromRGB(40, 10, 70))
			scaleOf(heading).Scale = 0
			pop(heading, 0, 0.45, 0.15)
			local subheading = text(merge(at(630, 196, 700, 28), {
				Text = "FOR DEFEATING THE ELITE", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 210, 232), ZIndex = 10,
			}), scene, 2)
			fadeIn(subheading, 0.3, 0.35)

			local chestImage = image(merge(at(630, -180, 330, 286), {
				ClassName = "ImageButton", Image = RewardArt.EpicChest, AutoButtonColor = false, ZIndex = 8,
			}), scene)
			tween(chestImage, 0.6, { Position = UDim2.fromScale(0.5, (CHEST_Y + TOP) / H) }, Enum.EasingStyle.Bounce, nil, 0.1)
			after(0.55, function()
				soundController:PlaySFX("TitleSlam")
				burst(630, CHEST_Y + 120, 10, Color3.fromRGB(255, 226, 120), 200, 34, scene)
			end)

			local hint = new("Frame", merge(at(630, 670, 360, 58), {
				BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 9,
			}), scene)
			new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, hint)
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(169, 107, 255), Color3.fromRGB(106, 47, 214)) }, hint)
			outline(hint, 3)
			text({
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.48),
				Text = "TAP TO OPEN", ZIndex = 10,
			}, hint, 3, Color3.fromRGB(40, 10, 70))
			fadeIn(hint, 0.3, 0.8)

			local opened = false
			local started = os.clock()
			every(function(dt, time)
				sceneRays.Rotation = (sceneRays.Rotation + dt * (if opened then 70 else 18)) % 360
				if not opened and chestImage.Parent then
					-- The wobble grows while the chest waits to be opened.
					local wait = math.clamp((os.clock() - started - 0.7) / AUTO_OPEN, 0, 1)
					chestImage.Rotation = math.sin(time * (7 + wait * 10)) * (2 + wait * 6)
					hint.Rotation = math.sin(time * 3) * 2
				end
			end)

			local function open()
				if opened or not alive then return end
				opened = true
				soundController:PlaySFX("MaxUpgrade")
				tween(hint, 0.2, { BackgroundTransparency = 1 })
				for _, object in hint:GetDescendants() do
					if object:IsA("TextLabel") then tween(object, 0.2, { TextTransparency = 1 }) end
					if object:IsA("UIStroke") then tween(object, 0.2, { Transparency = 1 }) end
				end
				local hintStroke = hint:FindFirstChildOfClass("UIStroke")
				if hintStroke then tween(hintStroke, 0.2, { Transparency = 1 }) end

				chestImage.Rotation = 0
				pop(chestImage, 1.35, 0.25)
				-- Over the whole screen (the scene is only the canvas area).
				local flashScene = new("Frame", {
					Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 244, 214), BackgroundTransparency = 0.2,
					BorderSizePixel = 0, ZIndex = 47,
				}, gui)
				tween(flashScene, 0.5, { BackgroundTransparency = 1 })
				burst(630, CHEST_Y, 22, Color3.fromRGB(255, 226, 120), 300, 44, scene)
				burst(630, CHEST_Y, 14, glowColor, 240, 36, scene)
				tween(chestImage, 0.45, { ImageTransparency = 1, Size = UDim2.fromScale(330 * 1.5 / W, 286 * 1.5 / H) }, nil, nil, 0.2)

				local loot = {
					{ Key = "Coins", Icon = Art.Coins, Amount = chest.Coins or 0, Format = "+%s", X = 430, Color = Color3.fromRGB(255, 243, 176) },
					{ Key = "Gems", Icon = Art.Crystals, Amount = chest.Gems or 0, Format = "+%s", X = 830, Color = Color3.fromRGB(191, 234, 255) },
				}
				for index, item in ipairs(loot) do
					if item.Amount <= 0 then continue end
					local group = new("Frame", merge(at(630, CHEST_Y, 170, 160), { BackgroundTransparency = 1, ZIndex = 12 }), scene)
					image({ Size = UDim2.fromScale(1, 0.66), Image = item.Icon, ZIndex = 12 }, group)
					text({
						AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.7), Size = UDim2.fromScale(1, 0.28),
						Text = string.format(item.Format, thousands(item.Amount)), TextColor3 = item.Color, ZIndex = 13,
					}, group, 3)
					scaleOf(group).Scale = 0.2
					tween(scaleOf(group), 0.5, { Scale = 1 }, Enum.EasingStyle.Back, nil, 0.15)
					tween(group, 0.5, { Position = UDim2.fromScale(item.X / W, (CHEST_Y - 70 + TOP) / H) }, Enum.EasingStyle.Back, nil, 0.15)
					local state: CardState? = nil
					for _, candidate in cardStates do
						if candidate.key == item.Key then state = candidate end
					end
					-- Into the card it belongs to.
					after(1.15 + (index - 1) * 0.15, function()
						if not state then return end
						tween(group, 0.4, { Position = UDim2.fromScale(state.cx / W, (state.cy + TOP) / H) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
						tween(scaleOf(group), 0.4, { Scale = 0.35 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
						after(0.4, function()
							group:Destroy()
							soundController:PlaySFX("StarDing")
							countCard(state :: CardState, (state :: CardState).value + item.Amount, 0.6, 4)
						end)
					end)
				end
				after(1.5, function()
					tween(layer, 0.35, { BackgroundTransparency = 1 })
					for _, object in scene:GetDescendants() do
						if object:IsA("TextLabel") then tween(object, 0.3, { TextTransparency = 1 })
						elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then tween(object, 0.3, { ImageTransparency = 1 })
						elseif object:IsA("UIStroke") then tween(object, 0.3, { Transparency = 1 })
						elseif object:IsA("Frame") and object.BackgroundTransparency < 1 then tween(object, 0.3, { BackgroundTransparency = 1 })
						end
					end
				end)
				after(1.95, function()
					flashScene:Destroy()
					scene:Destroy()
					layer:Destroy()
				end)
			end
			layer.Activated:Connect(open)
			chestImage.Activated:Connect(open)
			after(AUTO_OPEN + 0.7, open)
		end)
	end

	-- Level and XP ----------------------------------------------------------------------

	local levelInfo = data.Level or {}
	local level = levelInfo.Before or 1
	local experience = levelInfo.XPBefore or 0
	local gained = levelInfo.Gained or 0
	local neededFor: (number) -> number = levelInfo.Needed or function()
		return 0
	end
	local XP_START = if hasChest then CHEST_AT + CHEST_LENGTH
		elseif hasBonus then BONUS_AT + 2.1
		else CARD_START + 2 * CARD_STEP + 1.4

	local levelBadge = image(merge(at(191.5, 677, 303, 78), { Image = Art.LevelBadge, ZIndex = 3 }), body, SLICE.LevelBadge)
	local levelText = text({
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.78, 0.56),
		Text = `LEVEL {level}`, ZIndex = 4,
	}, levelBadge, 3)
	local track = image(merge(at(785, 677, 890, 82), { Image = Art.XPTrack, ZIndex = 3 }), body, SLICE.XPTrack)
	local groove = new("Frame", {
		Position = UDim2.fromScale(0.0247, 0.29), Size = UDim2.fromScale(0.94, 0.4), BackgroundTransparency = 1, ZIndex = 4,
	}, track)
	local fill = image({ Image = Art.XPFill, Size = UDim2.fromScale(0, 1), ZIndex = 1 }, groove, SLICE.XPFill)
	local fillShine = shine(fill, SLICE.XPFill, 0.7)
	local xpText = text({
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.96, 0.5), Size = UDim2.fromScale(0.4, 0.33),
		TextXAlignment = Enum.TextXAlignment.Right, Text = "", ZIndex = 6,
	}, track, 2.5)
	local MIN_FILL = 33 / 838 -- the fill's rounded ends need at least its own height
	local function setBar(value: number, needed: number)
		local percent = if needed > 0 then math.clamp(value / needed, 0, 1) else 0
		fill.Visible = percent > 0
		fill.Size = UDim2.fromScale(math.max(percent, MIN_FILL), 1)
		xpText.Text = `{thousands(value)} / {thousands(needed)} XP`
	end
	setBar(experience, neededFor(level))
	fadeIn(levelBadge, 0.3, XP_START - 0.6)
	fadeIn(track, 0.3, XP_START - 0.6)
	pop(levelBadge, 0.4, 0.4, XP_START - 0.6)

	local function levelUp(newLevel: number)
		soundController:PlaySFX("LevelUp")
		levelText.Text = `LEVEL {newLevel}`
		pop(levelBadge, 1.45, 0.45)
		burst(191.5, 677, 14, Color3.fromRGB(255, 226, 120), 170, 40)
		fill.ImageColor3 = Color3.fromRGB(255, 255, 210)
		tween(fill, 0.4, { ImageColor3 = Color3.new(1, 1, 1) })
		local label = text(merge(at(191.5, 622, 260, 40), {
			Text = "LEVEL UP!", TextColor3 = Color3.fromRGB(255, 226, 92), ZIndex = 30,
		}), effects, 3, Color3.fromRGB(90, 40, 0))
		pop(label, 0, 0.35)
		tween(label, 1.2, { Position = UDim2.fromScale(191.5 / W, (585 + TOP) / H), TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.6)
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			tween(stroke, 1.2, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.6)
		end
		task.delay(2, function() label:Destroy() end)
	end

	after(XP_START, function()
		if gained <= 0 then return end
		-- "+N XP" flies up from the bar.
		local plus = text(merge(at(1050, 640, 260, 34), {
			Text = `+{thousands(gained)} XP`, TextColor3 = Color3.fromRGB(150, 255, 170), ZIndex = 30,
		}), effects, 2.5)
		pop(plus, 0, 0.3)
		tween(plus, 1.1, { Position = UDim2.fromScale(1050 / W, (600 + TOP) / H), TextTransparency = 1 }, nil, nil, 0.5)
		local plusStroke = plus:FindFirstChildOfClass("UIStroke")
		if plusStroke then tween(plusStroke, 1.1, { Transparency = 1 }, nil, nil, 0.5) end
		task.delay(1.8, function() plus:Destroy() end)

		task.spawn(function()
			local remaining = gained
			local rounds = 0
			while alive and remaining > 0 do
				local needed = neededFor(level)
				local step = math.min(needed - experience, remaining)
				local duration = if rounds >= 3 then 0.3 else math.clamp(step / needed * 1.8, 0.45, 1.4)
				local value = Instance.new("NumberValue")
				value.Value = experience
				value.Changed:Connect(function(shown)
					setBar(shown, needed)
				end)
				tween(value, duration, { Value = experience + step }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
				fillShine(duration)
				task.wait(duration + 0.05)
				value:Destroy()
				if not alive then return end
				experience += step
				remaining -= step
				rounds += 1
				if experience >= needed then
					level += 1
					experience = 0
					levelUp(level)
					task.wait(0.35)
					setBar(0, neededFor(level))
					task.wait(0.15)
				else
					setBar(experience, needed)
				end
			end
		end)
	end)

	-- Buttons ---------------------------------------------------------------------------

	local leavingUntil = 0
	local function makeButton(props: { [string]: any })
		local holder = new("Frame", merge(at(props.X, 804.5 + 140, props.Width, 105), { BackgroundTransparency = 1, ZIndex = 5 }), body)
		-- Finger-sized on phones: the canvas shrinks with the screen, so on short screens the button grows taller
		-- (never wider: the two buttons sit side by side) until it is at least MIN_BUTTON_HEIGHT pixels.
		local function fitHeight()
			local perCanvas = stage.AbsoluteSize.Y / H
			if perCanvas > 0 then
				local height = math.clamp(MIN_BUTTON_HEIGHT / perCanvas, 105, 160) -- 160: still clear of the XP bar above
				holder.Size = UDim2.fromScale(props.Width / W, height / H)
			end
		end
		fitHeight()
		stage:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitHeight)
		local button = image({
			ClassName = "ImageButton", Image = props.Image, Size = UDim2.fromScale(1, 1), ZIndex = 1, AutoButtonColor = false,
		}, holder, SLICE.Button)
		local icon = image({
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(props.IconX, 0.5), Size = UDim2.fromScale(0.13, 0.6),
			Image = props.Icon, ZIndex = 3,
		}, button)
		text({
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(props.TextX, 0.5), Size = UDim2.fromScale(props.TextWidth, 0.42),
			Text = props.Text, ZIndex = 3,
		}, button, 3, props.Stroke)
		local sweep = shine(button, SLICE.Button, 0.5)
		local hover = Instance.new("NumberValue")
		hover.Value = 1
		local scale = scaleOf(holder)
		every(function(_, time)
			local pulse = if props.Pulse then 1 + math.sin(time * 4) * 0.025 else 1
			scale.Scale = hover.Value * pulse
		end)
		local function to(value: number, duration: number)
			tween(hover, duration, { Value = value }, Enum.EasingStyle.Back)
		end
		button.MouseEnter:Connect(function()
			to(1.06, 0.15)
			soundController:PlaySFX("MouseEnter")
			icon.Rotation = 0
			tween(icon, 0.45, { Rotation = props.IconSpin or 0 }, Enum.EasingStyle.Back)
			pop(icon, 1.25, 0.3)
		end)
		button.MouseLeave:Connect(function() to(1, 0.15) end)
		button.MouseButton1Down:Connect(function() to(0.94, 0.08) end)
		button.MouseButton1Up:Connect(function() to(1.06, 0.12) end)
		button.Activated:Connect(function()
			leavingUntil = os.clock() + LEAVING_TEXT_TIME
			if props.OnClick then task.spawn(props.OnClick) end
		end)

		tween(holder, 0.55, { Position = UDim2.fromScale(props.X / W, (804.5 + TOP) / H) }, Enum.EasingStyle.Back, nil, props.Delay)
		fadeIn(holder, 0.3, props.Delay)
		if props.Pulse then
			task.spawn(function()
				task.wait(props.Delay + 0.8)
				while alive do
					sweep(0.8)
					task.wait(2.6)
				end
			end)
		end
		return holder
	end
	local BUTTONS_AT = XP_START - 0.2
	makeButton({
		X = 350, Width = 554, Image = theme.Art.Button, Icon = Art.Replay, IconX = 0.22, IconSpin = -360,
		Text = theme.PlayText, TextX = 0.6, TextWidth = 0.56, Stroke = theme.ButtonStroke, Pulse = true,
		Delay = BUTTONS_AT, OnClick = data.OnPlayAgain,
	})
	makeButton({
		X = 928.5, Width = 527, Image = Art.ButtonLobby, Icon = Art.Home, IconX = 0.16,
		Text = "RETURN TO LOBBY", TextX = 0.59, TextWidth = 0.66, Stroke = OUTLINE,
		Delay = BUTTONS_AT + 0.12, OnClick = data.OnMainMenu,
	})

	-- Auto-return countdown under the panel; data.ReturnAt() gives the server time of the return.
	local returnLabel = text(merge(at(630, 926, 700, 30), { Text = "", Font = Enum.Font.GothamBold, ZIndex = 5 }), stage, 2)
	task.spawn(function()
		while alive do
			local returnAt = data.ReturnAt and data.ReturnAt()
			if os.clock() < leavingUntil then
				returnLabel.Text = "Teleporting..."
			elseif returnAt then
				local seconds = math.max(0, math.ceil(returnAt - Workspace:GetServerTimeNow()))
				returnLabel.Text = if seconds > 0 then string.format(RETURN_TEXT, seconds) else "Teleporting..."
			else
				returnLabel.Text = ""
			end
			task.wait(0.2)
		end
	end)

	-- Idle motion: rays spin, the emblem floats, reward icons bob, the backdrop glow breathes.
	every(function(dt, time)
		rays.Rotation = (rays.Rotation + dt * (if won then 12 else 0)) % 360
		if not won then
			raysScale.Scale = if raysScale.Scale > 0.5 then 1 + math.sin(time * 3) * 0.06 else raysScale.Scale
			emblem.ImageColor3 = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 190, 190), (math.sin(time * 5) + 1) * 0.25)
		end
		if floating then
			emblem.Position = UDim2.fromScale(0.5, (EMBLEM_Y + TOP + math.sin(time * 2) * 5) / H)
		end
		for _, entry in icons do
			entry.label.Position = UDim2.fromScale(0.5, 0.38 + math.sin(time * 2.4 + entry.phase) * 0.025)
		end
		vignette.BackgroundTransparency = if time > 0.8 then 0.08 + math.sin(time * 1.3) * 0.08 else vignette.BackgroundTransparency
	end)

	-- Win: a confetti blast when the banner lands, then gold sparkles twinkle around the panel.
	if won then
		after(0.45, function()
			for index = 1, 70 do
				local piece = new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.22),
					Size = UDim2.fromOffset(random:NextInteger(6, 11) * canvasScale, random:NextInteger(11, 19) * canvasScale),
					BackgroundColor3 = CONFETTI_COLORS[(index - 1) % #CONFETTI_COLORS + 1], BorderSizePixel = 0,
					Rotation = random:NextNumber(0, 360), ZIndex = 25,
				}, effects)
				local angle = random:NextNumber(0, math.pi * 2)
				local distance = random:NextNumber(0.2, 0.6)
				local outX, outY = 0.5 + math.cos(angle) * distance, 0.22 + math.sin(angle) * distance * 0.6
				local outTime = random:NextNumber(0.45, 0.75)
				tween(piece, outTime, { Position = UDim2.fromScale(outX, outY), Rotation = piece.Rotation + random:NextNumber(-240, 240) }, Enum.EasingStyle.Quart)
				local fallTime = random:NextNumber(1.6, 2.6)
				tween(piece, fallTime, {
					Position = UDim2.fromScale(outX + random:NextNumber(-0.08, 0.08), outY + random:NextNumber(0.4, 0.7)),
					Rotation = piece.Rotation + random:NextNumber(-500, 500), BackgroundTransparency = 1,
				}, Enum.EasingStyle.Quad, Enum.EasingDirection.In, outTime)
				task.delay(outTime + fallTime + 0.1, function() piece:Destroy() end)
			end
		end)
		task.spawn(function()
			task.wait(1)
			while alive do
				-- Around the panel, not over the text: pick a spot near the edges of the canvas.
				local x = if random:NextNumber() < 0.5 then random:NextNumber(-60, 120) else random:NextNumber(1140, 1320)
				local y = random:NextNumber(60, 900)
				if random:NextNumber() < 0.35 then
					x, y = random:NextNumber(100, 1160), random:NextNumber(-20, 60)
				end
				local size = random:NextNumber(18, 36)
				local twinkle = image(merge(at(x, y, size, size), {
					Image = Art.Sparkle, ImageColor3 = Color3.fromRGB(255, 236, 150), ZIndex = 1,
				}), effects)
				local scale = scaleOf(twinkle)
				scale.Scale = 0
				tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
				tween(twinkle, 1.1, { Rotation = 90 })
				tween(scale, 0.4, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.7)
				task.delay(1.2, function()
					scales[twinkle] = nil
					twinkle:Destroy()
				end)
				task.wait(0.22)
			end
		end)
	else
		-- Loss: embers rise and ash drifts down behind everything.
		task.spawn(function()
			while alive do
				local ember = random:NextNumber() > 0.4
				local size = random:NextInteger(3, 7) * canvasScale
				local x = random:NextNumber(0, 1)
				local piece = new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, if ember then 1.03 else -0.03),
					Size = UDim2.fromOffset(size, size), Rotation = 45,
					BackgroundColor3 = if ember then Color3.fromRGB(255, 140, 60) else Color3.fromRGB(130, 130, 145),
					BackgroundTransparency = if ember then 0.1 else 0.45, BorderSizePixel = 0, ZIndex = 2,
				}, gui)
				local duration = random:NextNumber(4.5, 8)
				tween(piece, duration, {
					Position = UDim2.fromScale(x + random:NextNumber(-0.1, 0.1), if ember then 0.15 else 1.05),
					BackgroundTransparency = 1, Rotation = 45 + random:NextNumber(-180, 180),
				}, Enum.EasingStyle.Linear)
				task.delay(duration, function() piece:Destroy() end)
				task.wait(0.08)
			end
		end)
	end

	gui.Parent = playerGui
	local function rescale()
		canvasScale = stage.AbsoluteSize.X / W
		for _, entry in slices do
			if entry[1].Parent then entry[1].SliceScale = entry[2] * canvasScale end
		end
		for _, entry in strokes do
			if entry[1].Parent then entry[1].Thickness = entry[2] * canvasScale end
		end
	end
	rescale()
	table.insert(connections, stage:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale))
	local unlock = lockControls()
	local showGuis = hideOtherGuis(playerGui, gui)

	current = {
		cleanup = function()
			alive = false
			for _, connection in ipairs(connections) do connection:Disconnect() end
			for _, t in ipairs(tweens) do t:Cancel() end
			blur:Destroy()
			gui:Destroy()
			showGuis()
			unlock()
		end,
	}
end

return VictoryScreen
