-- "NEW ENEMY" card: the first time an enemy with a Tip (Enemies/EnemyInfo) shows up in a match, a card
-- slides in on the right with the zombie turning in a 3D window, its name and ability tag, the tip and
-- the towers that counter it. Several new enemies at once queue up. EnemyIntro.Start() returns a stop.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local EnemyInfo = require(ReplicatedStorage.Shared.Features.Services.Enemies.EnemyInfo)
local UiScale = require(ReplicatedStorage.Shared.Source.Features.App.Common.UiScale)
local soundController = require(ReplicatedStorage.Shared.Features.Services.SoundController.soundController)

local OUTLINE = Color3.fromRGB(12, 16, 26)
local CARD = Vector2.new(440, 190) -- 1080p pixels
local SHOW_TIME = 6

local EnemyIntro = {}

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

local function label(props: { [string]: any }, parent: Instance, stroke: number): TextLabel
	local text = new("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
	for key, value in pairs(props) do
		(text :: any)[key] = value
	end
	if stroke > 0 then
		new("UIStroke", { Color = OUTLINE, Thickness = stroke, LineJoinMode = Enum.LineJoinMode.Round }, text)
	end
	return text
end

-- A turning copy of the enemy template inside a ViewportFrame.
local function preview(name: string, parent: Instance): (() -> ())?
	local enemies = ReplicatedStorage:FindFirstChild("Game") and ReplicatedStorage.Game:FindFirstChild("Enemies")
	local template = enemies and enemies:FindFirstChild(name)
	if not template or not template:IsA("Model") then
		return nil
	end
	local viewport = new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(170, 170, 185),
		LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1, -1), ZIndex = 3,
	}, parent)
	local world = new("WorldModel", {}, viewport)
	local model = template:Clone()
	for _, object in model:GetDescendants() do
		if object:IsA("Script") or object:IsA("LocalScript") then
			object:Destroy()
		end
	end
	model:PivotTo(CFrame.new())
	model.Parent = world
	local center, size = model:GetBoundingBox()
	local camera = new("Camera", { FieldOfView = 30 }, viewport)
	viewport.CurrentCamera = camera
	local distance = math.max(size.Y, size.X) * 2.1
	local look = center.Position + Vector3.new(0, size.Y * 0.05, 0)
	camera.CFrame = CFrame.lookAt(look + Vector3.new(0, size.Y * 0.12, -distance), look)
	local base = model:GetPivot()
	local angle = math.pi -- facing the camera
	local connection = RunService.RenderStepped:Connect(function(dt)
		angle += dt * 0.9
		model:PivotTo(base * CFrame.Angles(0, angle, 0))
	end)
	return function()
		connection:Disconnect()
	end
end

function EnemyIntro.Start(): () -> ()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = new("ScreenGui", {
		Name = "EnemyIntro", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 41,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
	local alive = true
	local seen: { [string]: boolean } = {}
	local queue: { string } = {}
	local showing = false

	local function showNext()
		if showing or not alive then
			return
		end
		local name = table.remove(queue, 1)
		if not name then
			return
		end
		local info = EnemyInfo[name]
		showing = true
		local scale = UiScale.compute()
		local color = info.Color

		local card = new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 20, 0.42, 0),
			Size = UDim2.fromOffset(CARD.X * scale, CARD.Y * scale),
			BackgroundColor3 = Color3.fromRGB(22, 26, 40), BackgroundTransparency = 0.06, BorderSizePixel = 0, ZIndex = 1,
		}, gui)
		new("UICorner", { CornerRadius = UDim.new(0, 18 * scale) }, card)
		new("UIStroke", { Color = OUTLINE, Thickness = 4 * scale }, card)
		new("UIGradient", {
			Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(46, 54, 80), Color3.fromRGB(18, 20, 32)),
		}, card)
		-- Colored band on the left edge in the enemy's color.
		local band = new("Frame", {
			Size = UDim2.new(0, 10 * scale, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 2,
		}, card)
		new("UICorner", { CornerRadius = UDim.new(0, 18 * scale) }, band)

		local window = new("Frame", {
			Position = UDim2.fromOffset(18 * scale, 14 * scale), Size = UDim2.fromOffset(150 * scale, 162 * scale),
			BackgroundColor3 = color, BackgroundTransparency = 0.75, BorderSizePixel = 0, ZIndex = 2,
		}, card)
		new("UICorner", { CornerRadius = UDim.new(0, 14 * scale) }, window)
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.9) }),
		}, window)
		local stopPreview = preview(name, window)

		local left = 182 * scale
		local textWidth = CARD.X * scale - left - 16 * scale
		local heading = label({
			Position = UDim2.fromOffset(left, 14 * scale), Size = UDim2.fromOffset(textWidth, 20 * scale),
			Text = "NEW ENEMY!", TextColor3 = Color3.fromRGB(255, 214, 92), ZIndex = 3,
		}, card, 2 * scale)
		local title = label({
			Position = UDim2.fromOffset(left, 36 * scale), Size = UDim2.fromOffset(textWidth * 0.62, 40 * scale),
			Text = info.Name, TextColor3 = color, ZIndex = 3,
		}, card, 3 * scale)
		if info.Tag then
			local pill = new("Frame", {
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(left + textWidth, 42 * scale),
				Size = UDim2.fromOffset(textWidth * 0.34, 28 * scale), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 3,
			}, card)
			new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, pill)
			new("UIStroke", { Color = OUTLINE, Thickness = 2.5 * scale }, pill)
			label({
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.62),
				Text = info.Tag, TextColor3 = OUTLINE, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4,
			}, pill, 0)
		end
		label({
			Position = UDim2.fromOffset(left, 84 * scale), Size = UDim2.fromOffset(textWidth, 52 * scale),
			Text = info.Tip or "", Font = Enum.Font.GothamBold, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Color3.fromRGB(225, 232, 245), ZIndex = 3,
		}, card, 0)
		if info.Counter then
			label({
				Position = UDim2.fromOffset(left, 144 * scale), Size = UDim2.fromOffset(textWidth, 34 * scale),
				Text = `<font color="#8FE38F">Counter:</font> {info.Counter}`, RichText = true, Font = Enum.Font.GothamBold,
				TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(200, 210, 230), ZIndex = 3,
			}, card, 0)
		end

		soundController:PlaySFX("FinalWave")
		tween(card, 0.45, { Position = UDim2.new(1, -(CARD.X + 24) * scale, 0.42, 0) }, Enum.EasingStyle.Back)
		heading.TextTransparency = 1
		task.delay(0.3, function()
			if heading.Parent then tween(heading, 0.25, { TextTransparency = 0 }) end
		end)
		-- The title pulses once in the enemy's color.
		task.delay(0.45, function()
			if not title.Parent then return end
			local stroke = title:FindFirstChildOfClass("UIStroke")
			local size = title.Size
			title.Size = UDim2.fromOffset(size.X.Offset * 1.12, size.Y.Offset * 1.12)
			tween(title, 0.3, { Size = size }, Enum.EasingStyle.Back)
			if stroke then
				stroke.Color = color
				tween(stroke, 0.5, { Color = OUTLINE })
			end
		end)
		task.delay(SHOW_TIME, function()
			if not card.Parent then return end
			tween(card, 0.35, { Position = UDim2.new(1, 20, 0.42, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			task.delay(0.4, function()
				if stopPreview then stopPreview() end
				card:Destroy()
				showing = false
				showNext()
			end)
		end)
	end

	local folder = Workspace:WaitForChild("ZombiesOnMap")
	local function onEnemy(model: Instance)
		local info = EnemyInfo[model.Name]
		if not info or not info.Tip or seen[model.Name] or model:GetAttribute("Elite") then
			return
		end
		seen[model.Name] = true
		table.insert(queue, model.Name)
		showNext()
	end
	local added = folder.ChildAdded:Connect(onEnemy)
	for _, model in folder:GetChildren() do
		onEnemy(model)
	end

	return function()
		alive = false
		added:Disconnect()
		gui:Destroy()
	end
end

return EnemyIntro
