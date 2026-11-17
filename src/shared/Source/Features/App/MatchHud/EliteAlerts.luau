-- Match HUD pieces for the elite zombie (MatchBonuses):
--   * a banner sweeps across the screen when an elite spawns (MatchState.EliteSpawns changes);
--   * when one dies a chest pops out of it (MatchState.ChestDropAt) and flies into the chest
--     counter next to the top bar (MatchState.Chests). The chests are opened on the result screen.
-- EliteAlerts.Start() returns a stop function.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Ids = require(ReplicatedStorage.Shared.Source.Game.AssetsIds.Ids)
local observeMatchState = require(ReplicatedStorage.Shared.Features.Services.MatchState.ObserveMatchState)
local soundController = require(ReplicatedStorage.Shared.Features.Services.SoundController.soundController)
local UiScale = require(ReplicatedStorage.Shared.Source.Features.App.Common.UiScale)

local CHEST = Ids.Rewards.EpicChest
local SPARKLE = Ids.EndMenu.Sparkle
local OUTLINE = Color3.fromRGB(12, 16, 26)
local GOLD = Color3.fromRGB(255, 214, 92)
local PURPLE = Color3.fromRGB(196, 130, 255)
-- Pixels on a 1080p screen, like the top bar (UpBar_healthBar: health panel 640 x 86, 8 from the top).
local TOP_BAR_HALF = 320
local TOP_BAR_MIDDLE = 8 + 86 / 2
local CHIP = Vector2.new(124, 58)

local EliteAlerts = {}

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(className)
	for key, value in pairs(props) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function tween(object: Instance, duration: number, goal, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(object, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

-- The HUD's own scale, so the counter lines up with the top bar.
local uiScale = UiScale.compute

local function outlinedText(props: { [string]: any }, parent: Instance, thickness: number): TextLabel
	local label = new("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.new(1, 1, 1),
	}, parent)
	for key, value in pairs(props) do
		(label :: any)[key] = value
	end
	new("UIStroke", { Color = OUTLINE, Thickness = thickness, LineJoinMode = Enum.LineJoinMode.Round }, label)
	return label
end

function EliteAlerts.Start(): () -> ()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = new("ScreenGui", {
		Name = "EliteAlerts", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 40,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
	local alive = true
	local connections: { RBXScriptConnection } = {}

	-- Chest counter, right of the top bar. Hidden until the first chest.
	local chip = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Visible = false, ZIndex = 2,
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, chip)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(182, 125, 255), Color3.fromRGB(106, 47, 214)) }, chip)
	local chipStroke = new("UIStroke", { Color = OUTLINE, Thickness = 3 }, chip)
	local chipScale = new("UIScale", { Scale = 1 }, chip)
	local chipIcon = new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.27, 0.4), Size = UDim2.fromScale(0.62, 1.32),
		BackgroundTransparency = 1, Image = CHEST, ScaleType = Enum.ScaleType.Fit, ZIndex = 3,
	}, chip)
	local chipText = outlinedText({
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.55, 0.5), Size = UDim2.fromScale(0.4, 0.62),
		Text = "x0", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
	}, chip, 2.5)

	local function layoutChip()
		local scale = uiScale()
		chip.Size = UDim2.fromOffset(CHIP.X * scale, CHIP.Y * scale)
		chip.Position = UDim2.new(0.5, (TOP_BAR_HALF + 22) * scale, 0, TOP_BAR_MIDDLE * scale)
		chipStroke.Thickness = 3 * scale
		local textStroke = chipText:FindFirstChildOfClass("UIStroke")
		if textStroke then textStroke.Thickness = 2.5 * scale end
	end
	layoutChip()
	local camera = Workspace.CurrentCamera
	if camera then
		table.insert(connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutChip))
	end

	local function sparkles(at: Vector2, color: Color3, count: number, spread: number)
		local scale = uiScale()
		for _ = 1, count do
			local size = math.random(18, 34) * scale
			local sparkle = new("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(at.X, at.Y), Size = UDim2.fromOffset(size, size),
				BackgroundTransparency = 1, Image = SPARKLE, ImageColor3 = color, Rotation = math.random(0, 90), ZIndex = 6,
			}, gui)
			local angle = math.random() * math.pi * 2
			local distance = (0.5 + math.random() * 0.5) * spread * scale
			tween(sparkle, 0.6, {
				Position = UDim2.fromOffset(at.X + math.cos(angle) * distance, at.Y + math.sin(angle) * distance),
				ImageTransparency = 1, Rotation = sparkle.Rotation + 160, Size = UDim2.fromOffset(size * 0.3, size * 0.3),
			}, Enum.EasingStyle.Quart)
			task.delay(0.65, function() sparkle:Destroy() end)
		end
	end

	-- "ELITE ZOMBIE" banner ---------------------------------------------------------------------

	local function showBanner()
		local scale = uiScale()
		soundController:PlaySFX("FinalWave")
		local band = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.27), Size = UDim2.new(1, 0, 0, 104 * scale),
			BackgroundColor3 = Color3.fromRGB(40, 10, 60), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4,
		}, gui)
		new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.1), NumberSequenceKeypoint.new(0.75, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, band)
		tween(band, 0.25, { BackgroundTransparency = 0 })
		-- Thin gold lines above and below the band.
		for _, y in { 0, 1 } do
			local line = new("Frame", {
				AnchorPoint = Vector2.new(0.5, y), Position = UDim2.fromScale(0.5, y), Size = UDim2.fromOffset(0, 3 * scale),
				BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 5,
			}, band)
			new("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
				}),
			}, line)
			tween(line, 0.5, { Size = UDim2.new(0.7, 0, 0, 3 * scale) }, Enum.EasingStyle.Quart)
		end
		local title = outlinedText({
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.3, 0.42), Size = UDim2.new(0, 620 * scale, 0.6, 0),
			Text = "ELITE ZOMBIE!", ZIndex = 6,
		}, band, 4 * scale)
		new("UIGradient", {
			Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 243, 176), Color3.fromRGB(255, 181, 46)),
		}, title)
		local subtitle = outlinedText({
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.86), Size = UDim2.new(0, 520 * scale, 0.24, 0),
			Text = "Defeat it and everyone gets a chest", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 233, 168),
			TextTransparency = 1, ZIndex = 6,
		}, band, 2 * scale)
		tween(title, 0.45, { Position = UDim2.fromScale(0.5, 0.42) }, Enum.EasingStyle.Back)
		task.delay(0.25, function()
			if subtitle.Parent then tween(subtitle, 0.3, { TextTransparency = 0 }) end
		end)
		task.delay(0.45, function()
			if not band.Parent then return end
			local center = band.AbsolutePosition + band.AbsoluteSize / 2
			sparkles(center, GOLD, 12, 260)
		end)
		task.delay(2.6, function()
			if not band.Parent then return end
			tween(title, 0.35, { Position = UDim2.fromScale(1.3, 0.42) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			tween(subtitle, 0.3, { TextTransparency = 1 })
			tween(band, 0.4, { BackgroundTransparency = 1 })
			for _, child in band:GetChildren() do
				if child:IsA("Frame") then tween(child, 0.3, { BackgroundTransparency = 1 }) end
				if child:IsA("TextLabel") then
					local stroke = child:FindFirstChildOfClass("UIStroke")
					if stroke then tween(stroke, 0.3, { Transparency = 1 }) end
				end
			end
			task.delay(0.45, function() band:Destroy() end)
		end)
	end

	-- Chest flying into the counter -------------------------------------------------------------

	local shownChests = 0
	local function setCount(count: number)
		chipText.Text = `x{count}`
	end

	local function flyChest(from: Vector3?, count: number)
		local scale = uiScale()
		local cam = Workspace.CurrentCamera
		local start: Vector2
		if from and cam then
			local point, onScreen = cam:WorldToViewportPoint(from)
			start = if onScreen then Vector2.new(point.X, point.Y) else cam.ViewportSize / 2
		else
			start = if cam then cam.ViewportSize / 2 else Vector2.new(960, 540)
		end
		local firstChest = not chip.Visible
		if firstChest then
			chip.Visible = true
			chipScale.Scale = 0
			tween(chipScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		local size = 110 * scale
		local chest = new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(start.X, start.Y), Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1, Image = CHEST, ScaleType = Enum.ScaleType.Fit, ZIndex = 7,
		}, gui)
		local chestScale = new("UIScale", { Scale = 0 }, chest)
		soundController:PlaySFX("StarDing")
		sparkles(start, PURPLE, 10, 120)
		sparkles(start, GOLD, 8, 90)
		-- Pop up out of the zombie, hang a moment, then arc into the counter.
		tween(chestScale, 0.35, { Scale = 1.25 }, Enum.EasingStyle.Back)
		tween(chest, 0.35, { Position = UDim2.fromOffset(start.X, start.Y - 70 * scale) }, Enum.EasingStyle.Quad)
		task.delay(0.65, function()
			if not alive then return end
			local target = chipIcon.AbsolutePosition + chipIcon.AbsoluteSize / 2
			local from2 = Vector2.new(start.X, start.Y - 70 * scale)
			local control = Vector2.new((from2.X + target.X) / 2, math.min(from2.Y, target.Y) - 160 * scale)
			local elapsed = 0
			local duration = 0.6
			local connection
			connection = RunService.RenderStepped:Connect(function(dt)
				elapsed += dt
				local t = math.min(elapsed / duration, 1)
				local eased = t * t
				local a = from2:Lerp(control, eased)
				local b = control:Lerp(target, eased)
				local point = a:Lerp(b, eased)
				chest.Position = UDim2.fromOffset(point.X, point.Y)
				chestScale.Scale = 1.25 - 0.85 * eased
				chest.Rotation = -20 * eased
				if t >= 1 then
					connection:Disconnect()
					chest:Destroy()
					setCount(count)
					chipScale.Scale = 1.35
					tween(chipScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
					sparkles(target, GOLD, 10, 80)
					soundController:PlaySFX("CoinTick")
					local plus = outlinedText({
						AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(target.X + 30 * scale, target.Y + 40 * scale),
						Size = UDim2.fromOffset(80 * scale, 34 * scale), Text = "+1", TextColor3 = Color3.fromRGB(232, 210, 255), ZIndex = 7,
					}, gui, 2.5 * scale)
					tween(plus, 0.9, { Position = UDim2.fromOffset(target.X + 30 * scale, target.Y + 80 * scale), TextTransparency = 1 })
					local stroke = plus:FindFirstChildOfClass("UIStroke")
					if stroke then tween(stroke, 0.9, { Transparency = 1 }) end
					task.delay(1, function() plus:Destroy() end)
				end
			end)
			table.insert(connections, connection)
		end)
	end

	local seenSpawns: number? = nil
	local stopObserving = observeMatchState(function(state)
		if not state or not alive then return end
		local spawns = state:GetAttribute("EliteSpawns") or 0
		if seenSpawns == nil then
			seenSpawns = spawns
		elseif spawns > seenSpawns then
			seenSpawns = spawns
			showBanner()
		end
		local chests = state:GetAttribute("Chests") or 0
		if chests > shownChests then
			local from = state:GetAttribute("ChestDropAt")
			shownChests = chests
			flyChest(if typeof(from) == "Vector3" then from else nil, chests)
		end
		local phase = state:GetAttribute("Phase")
		-- The result screen opens the chests: the counter leaves with the match HUD.
		if phase == "Victory" or phase == "Defeat" then
			chip.Visible = false
		end
	end)

	return function()
		alive = false
		stopObserving()
		for _, connection in connections do connection:Disconnect() end
		gui:Destroy()
	end
end

return EliteAlerts
