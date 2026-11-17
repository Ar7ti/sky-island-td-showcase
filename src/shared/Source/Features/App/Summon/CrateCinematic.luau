-- The 3D summon opening (client only). CrateCinematic.play(styleId, results) yields until it is over:
--   1. a rune altar in a starry sky with floating islands (far above the lobby); a beam comes down on it
--   2. the chest (CrateModel) falls from the sky with a trail and slams into the altar: dust, a shockwave ring,
--      the rune circle flares, the camera shakes
--   3. it rattles and charges up: lightning arcs to the floor, sparks are pulled in, its light turns the color
--      of the best tower rolled
--   4. it bursts: flash, the lid flies off, sparks and smoke explode out, a column of light shoots up
--   5. every tower rolled shoots out as a glowing orb with its icon and rains down around the chest,
--      the best one last and in front
-- Every case has its own version (CrateTiers): a Wooden chest gets a short, simple drop; Standard and Golden the
-- full scene above; Epic and Event add lightning, a dimmed world and a title card; the Robux Royal chest descends on
-- a golden beam with letterbox bars, an orbiting camera, a slow-motion burst, god rays, fireworks and gold rain.
-- Tapping the screen skips to the end. The lobby UI, sky and clouds are swapped out meanwhile and come back when
-- it ends; the summon window then shows the cards (SummonReveal with SkipIntro).
-- Art: altar and islands are generated meshes (Studio MCP generate_mesh / generate_texture, 2026-11-10); the
-- particle and beam textures are the ones the tower auras use (docs/vfx/README.md).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ContentProvider = game:GetService("ContentProvider")
local TowersConfig = require(ReplicatedStorage.Shared.Features.Services.TowersServices.towersConfig)
local Banners = require(ReplicatedStorage.Shared.Features.Services.Summon.Banners)
local Ids = require(ReplicatedStorage.Shared.Source.Game.AssetsIds.Ids)
local CrateModel = require(script.Parent.CrateModel)
local CrateTiers = require(script.Parent.CrateTiers)
local CaseSounds = require(script.Parent.CaseSounds)
local useSummon = require(script.Parent.useSummon)

-- Where the chest lands: the altar's rune floor, high up and far off to the side of the lobby (its map and water
-- end around 1,000 studs from the middle). At 8,500 studs the lobby still showed as a blue tile when the Royal
-- camera circled the altar; at 34,000 it is lost in the haze.
local STAGE = Vector3.new(24000, 900, 24000)
local SPARK = "rbxassetid://6490035152" -- soft spark
local SMOKE = "rbxassetid://6956634044"
local RUNES = "rbxassetid://13086890038" -- white rune circle
local LIGHTNING = "rbxassetid://4809471713" -- white lightning strip
local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
-- The altar is a MeshPart template in the place (ReplicatedStorage.CrateCinematicAssets.Altar, 46 x 17 x 46):
-- its texture is a SurfaceAppearance, which scripts can't create. Without the template the untextured-looking
-- first generation stands in (a SpecialMesh).
local ALTAR = {
	template = "Altar",
	mesh = "rbxassetid://74429232745550",
	texture = "rbxassetid://74188804409085",
	size = Vector3.new(11, 4, 11),
	floor = 1.75, -- the rune floor's height above the mesh center (measured with a raycast)
	scale = 4.2,
}
local ISLAND = {
	mesh = "rbxassetid://83616628073468",
	texture = "rbxassetid://140469018658207",
	size = Vector3.new(12.83, 26, 12.4),
}
-- "Purple Galaxy" skybox (Creator Store 100556987073859; only its six images are used).
local SKY = {
	Bk = "rbxassetid://99468191699832",
	Dn = "rbxassetid://121098906941255",
	Ft = "rbxassetid://106290292308760",
	Lf = "rbxassetid://102557334804626",
	Rt = "rbxassetid://97361097874537",
	Up = "rbxassetid://138727520721658",
}
-- Floating islands around the altar: direction (degrees from the camera's side), distance, height, scale.
local ISLANDS = {
	{ angle = 205, distance = 150, height = -10, scale = 2.6 },
	{ angle = 150, distance = 170, height = 25, scale = 2.0 },
	{ angle = 240, distance = 120, height = 35, scale = 1.4 },
	{ angle = 115, distance = 120, height = -30, scale = 1.6 },
	{ angle = 180, distance = 260, height = 60, scale = 3.2 },
	{ angle = 270, distance = 200, height = -45, scale = 2.2 },
	{ angle = 90, distance = 210, height = 10, scale = 2.4 },
}
local GOLD = Color3.fromRGB(255, 205, 70)
local WHITE = Color3.new(1, 1, 1)
local FOV = 62
local DROP_HEIGHT = 170
local ORB_SIZE = 1.8

local CrateCinematic = {}

-- Cases (banner or chest ids) with a CrateTiers profile get the 3D opening; anything else keeps the 2D one.
function CrateCinematic.supports(caseId: string): boolean
	return CrateTiers.get(caseId) ~= nil
end

-- Meshes, textures and the sky, loaded ahead (the summon window calls this when it opens) so the stage isn't
-- white for its first seconds. Safe to call more than once.
local preloadStarted, preloaded = false, false
function CrateCinematic.preload()
	if preloadStarted then
		return
	end
	preloadStarted = true
	-- PreloadAsync takes plain ids as images only, so meshes go in as unparented SpecialMeshes.
	local content: { Instance } = {}
	local function mesh(meshId: string, textureId: string)
		local special = Instance.new("SpecialMesh")
		special.MeshType = Enum.MeshType.FileMesh
		special.MeshId = meshId
		special.TextureId = textureId
		table.insert(content, special)
	end
	local assets = ReplicatedStorage:FindFirstChild("CrateCinematicAssets")
	mesh(ISLAND.mesh, ISLAND.texture)
	if not (assets and assets:FindFirstChild(ALTAR.template)) then
		mesh(ALTAR.mesh, ALTAR.texture)
	end
	for _, style in CrateModel.Styles do
		mesh(style.body.mesh, style.body.texture)
		mesh(style.lid.mesh, style.lid.texture)
	end
	for _, image in { SPARK, SMOKE, RUNES, LIGHTNING } do
		local decal = Instance.new("Decal")
		decal.Texture = image
		table.insert(content, decal)
	end
	local sky = Instance.new("Sky")
	sky.SkyboxBk, sky.SkyboxDn, sky.SkyboxFt = SKY.Bk, SKY.Dn, SKY.Ft
	sky.SkyboxLf, sky.SkyboxRt, sky.SkyboxUp = SKY.Lf, SKY.Rt, SKY.Up
	table.insert(content, sky)
	if assets then
		table.insert(content, assets)
	end
	task.spawn(CaseSounds.preload)
	pcall(ContentProvider.PreloadAsync, ContentProvider, content)
	for _, instance in content do
		if instance ~= assets then
			instance:Destroy()
		end
	end
	preloaded = true
end

-- Studio only: Workspace attribute CrateCinematicSpeed (e.g. 0.25) slows the scripted timing down for screenshots.
local function speed(): number
	if RunService:IsStudio() then
		local value = Workspace:GetAttribute("CrateCinematicSpeed")
		if type(value) == "number" and value > 0 then
			return value
		end
	end
	return 1
end

local function ease(alpha: number, style: Enum.EasingStyle, direction: Enum.EasingDirection): number
	return TweenService:GetValue(alpha, style, direction)
end

local function tween(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local t = TweenService:Create(instance, info, goal)
	t:Play()
	return t
end

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function meshed(parent: Instance, info: { mesh: string, texture: string, size: Vector3 }, scale: number, cframe: CFrame): Part
	local p = part(parent, { Size = info.size * scale, CFrame = cframe, CastShadow = true })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = info.mesh
	mesh.TextureId = info.texture
	mesh.Scale = Vector3.one * scale
	mesh.Parent = p
	return p
end

local function anchor(parent: Instance, position: Vector3): Part
	return part(parent, { Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(position) })
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	particles.Enabled = false
	particles.LightEmission = 1
	particles.Texture = SPARK
	for key, value in props do
		(particles :: any)[key] = value
	end
	particles.Parent = parent
	return particles
end

-- A flat image lying on the floor (rune circles, shockwave rings), on a see-through carrier.
local function floorImage(parent: Instance, image: string, diameter: number, y: number, color: Color3, transparency: number): (Part, Decal)
	local carrier = part(parent, {
		Size = Vector3.new(diameter, 0.05, diameter),
		CFrame = CFrame.new(STAGE + Vector3.new(0, y, 0)),
		Transparency = 1,
	})
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalId.Top
	decal.Texture = image
	decal.Color3 = color
	decal.Transparency = transparency
	decal.Parent = carrier
	return carrier, decal
end

-- A vertical beam from a point upward.
local function beamUp(parent: Instance, from: Vector3, height: number, width: number, color: Color3, transparency: number): Beam
	local bottom = anchor(parent, from)
	local top = anchor(parent, from + Vector3.new(0, height, 0))
	local a0 = Instance.new("Attachment")
	a0.Parent = bottom
	local a1 = Instance.new("Attachment")
	a1.Parent = top
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = width
	beam.Width1 = width * 0.15
	beam.Color = ColorSequence.new(color)
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, transparency),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Segments = 2
	beam.Parent = bottom
	return beam
end

type Stage = {
	runes: Part,
	runeDecal: Decal,
	pillars: { Beam },
	islands: { { part: BasePart, base: CFrame, phase: number } },
}

-- The altar, its rune circle and light pillars, drifting motes and the islands in the sky around it.
local function buildStage(folder: Folder, color: Color3, tier: CrateTiers.Tier): Stage
	local altarCenter = CFrame.new(STAGE - Vector3.new(0, ALTAR.floor * ALTAR.scale, 0))
	local assets = ReplicatedStorage:FindFirstChild("CrateCinematicAssets")
	local template = assets and assets:FindFirstChild(ALTAR.template)
	if template and template:IsA("BasePart") then
		local altar = template:Clone()
		altar.Anchored = true
		altar.CanCollide = false
		altar.CanQuery = false
		altar.CanTouch = false
		altar.CFrame = altarCenter
		altar.Parent = folder
	else
		meshed(folder, ALTAR, ALTAR.scale, altarCenter)
	end
	local runes, runeDecal = floorImage(folder, RUNES, 30, 0.08, color, 0.35)

	-- Faint pillars of light around the rim.
	local pillars = {}
	local rim = ALTAR.size.X * ALTAR.scale / 2 - 2.5
	for index = 1, tier.pillars do
		local angle = (index - 0.5) / tier.pillars * math.pi * 2
		table.insert(pillars, beamUp(folder, STAGE + Vector3.new(math.sin(angle) * rim, 0.6, math.cos(angle) * rim), 18, 0.7, color, 0.7))
	end

	-- Soft violet mist drifts below the altar.
	local mistCarrier = part(folder, {
		Size = Vector3.new(500, 2, 500),
		CFrame = CFrame.new(STAGE + Vector3.new(0, -70, -80)),
		Transparency = 1,
	})
	local mist = emitter(mistCarrier, {
		Texture = SMOKE,
		LightEmission = 0.4,
		Color = ColorSequence.new(Color3.fromRGB(120, 70, 200), Color3.fromRGB(200, 120, 230)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 40), NumberSequenceKeypoint.new(1, 70) }),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(10, 14),
		Speed = NumberRange.new(1, 3),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-5, 5),
		Shape = Enum.ParticleEmitterShape.Box,
		Rate = 12,
	})
	mist:Emit(90)
	mist.Enabled = true

	-- Motes drifting up all around.
	local air = part(folder, { Size = Vector3.new(90, 4, 90), CFrame = CFrame.new(STAGE + Vector3.new(0, -2, 0)), Transparency = 1 })
	local motes = emitter(air, {
		Color = ColorSequence.new(color:Lerp(WHITE, 0.4), GOLD),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.2, 0.45),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(4, 7),
		Speed = NumberRange.new(1.5, 4),
		SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box,
		Rate = 40,
	})
	motes.Enabled = true

	local islands = {}
	for index, spot in if tier.islands then ISLANDS else {} do
		-- The camera looks toward -Z; angle 180 is straight behind the altar.
		local angle = math.rad(spot.angle)
		local position = STAGE + Vector3.new(math.sin(angle) * spot.distance, spot.height, math.cos(angle) * spot.distance)
		local base = CFrame.new(position) * CFrame.Angles(0, index * 1.7, 0)
		local island = meshed(folder, ISLAND, spot.scale, base)
		island.CastShadow = false
		table.insert(islands, { part = island, base = base, phase = index })
	end
	return { runes = runes, runeDecal = runeDecal, pillars = pillars, islands = islands }
end

-- The lobby's sky, clouds and haze are swapped for the cinematic's and put back afterwards.
local function swapSky(): () -> ()
	local removed = {}
	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") then
			child.Parent = nil
			table.insert(removed, child)
		end
	end
	local sky = Instance.new("Sky")
	sky.SkyboxBk, sky.SkyboxDn, sky.SkyboxFt = SKY.Bk, SKY.Dn, SKY.Ft
	sky.SkyboxLf, sky.SkyboxRt, sky.SkyboxUp = SKY.Lf, SKY.Rt, SKY.Up
	sky.StarCount = 3000
	sky.CelestialBodiesShown = false
	sky.Parent = Lighting

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local density, haze = 0, 0
	if atmosphere then
		density, haze = atmosphere.Density, atmosphere.Haze
		atmosphere.Density = 0.2
		atmosphere.Haze = 0
	end
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	local cloudsOn = clouds and clouds.Enabled
	if clouds then
		clouds.Enabled = false
	end
	return function()
		sky:Destroy()
		for _, old in removed do
			old.Parent = Lighting
		end
		if atmosphere then
			atmosphere.Density, atmosphere.Haze = density, haze
		end
		if clouds then
			clouds.Enabled = cloudsOn
		end
	end
end

-- Every enabled ScreenGui is turned off for the opening and back on afterwards.
local function hideGuis(playerGui: PlayerGui): () -> ()
	local hidden = {}
	for _, gui in playerGui:GetChildren() do
		if gui:IsA("ScreenGui") and gui.Enabled then
			gui.Enabled = false
			table.insert(hidden, gui)
		end
	end
	return function()
		for _, gui in hidden do
			if gui.Parent then
				gui.Enabled = true
			end
		end
	end
end

local function controls(enabled: boolean)
	pcall(function()
		local module = require(Players.LocalPlayer.PlayerScripts:WaitForChild("PlayerModule", 1) :: ModuleScript) :: any
		local playerControls = module:GetControls()
		if enabled then
			playerControls:Enable()
		else
			playerControls:Disable()
		end
	end)
end

-- Launch order: weakest first, so the best tower lands last.
local function launchOrder(results: { any }): { any }
	local order = table.clone(results)
	table.sort(order, function(a, b)
		local rankA, rankB = Banners.Rank(a.rarity), Banners.Rank(b.rarity)
		if rankA ~= rankB then
			return rankA < rankB
		end
		return (a.featured and 1 or 0) < (b.featured and 1 or 0)
	end)
	return order
end

-- Where each orb lands: an inner arc on both sides of the chest and a front arc toward the camera; the last
-- (best) orb lands in the middle of the front arc.
local function landingSpots(count: number): { Vector3 }
	if count == 1 then
		return { STAGE + Vector3.new(0, 0, 17) }
	end
	local front = math.ceil(count / 2)
	local back = count - front
	local spots = {}
	local left = math.ceil(back / 2)
	local right = back - left
	for index = 1, back do
		local side = if index <= left then -1 else 1
		local slot = if index <= left then index else index - left
		local slots = if index <= left then left else right
		local degrees = if slots == 1 then 60 else 35 + 80 * (slot - 1) / (slots - 1)
		local angle = math.rad(side * degrees)
		table.insert(spots, STAGE + Vector3.new(math.sin(angle) * 12, 0, math.cos(angle) * 12))
	end
	local frontSpots = {}
	for index = 1, front do
		local angle = if front == 1 then 0 else math.rad(-50 + 100 * (index - 1) / (front - 1))
		table.insert(frontSpots, STAGE + Vector3.new(math.sin(angle) * 19, 0, math.cos(angle) * 19))
	end
	local middle = math.ceil(front / 2)
	for index, spot in frontSpots do
		if index ~= middle then
			table.insert(spots, spot)
		end
	end
	table.insert(spots, frontSpots[middle])
	return spots
end

-- Where the camera ends up while the towers land; the cards turn to face it.
local CAMERA_RAIN = CFrame.lookAt(STAGE + Vector3.new(0, 18, 44), STAGE + Vector3.new(0, 3, 6))
local CARD = Vector3.new(3, 4, 0.15)
local CARD_CANVAS = Vector2.new(300, 400)

local function label(parent: Instance, text: string, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = WHITE
	for key, value in props do
		(l :: any)[key] = value
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(20, 14, 30)
	stroke.Parent = l
	l.Parent = parent
	return l
end

local function cardSide(card: BasePart, face: Enum.NormalId, color: Color3): Frame
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = CARD_CANVAS
	gui.LightInfluence = 0
	gui.Brightness = 1.3
	gui.Parent = card
	local base = Instance.new("Frame")
	base.Size = UDim2.fromScale(1, 1)
	base.BackgroundColor3 = WHITE
	base.ClipsDescendants = true
	base.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.08, 0)
	corner.Parent = base
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 10
	stroke.Color = color:Lerp(WHITE, 0.25)
	stroke.Parent = base
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(color:Lerp(WHITE, 0.1), color:Lerp(Color3.new(0, 0, 0), 0.65))
	gradient.Parent = base
	return base
end

-- A tower card in the world: the face shows the tower, the back its rarity color and a "?".
local function buildCard(parent: Instance, result: any, color: Color3, scale: number): { part: BasePart, shine: Frame }
	local config = TowersConfig[result.towerId]
	local card = part(parent, {
		Size = CARD * scale,
		Color = Color3.fromRGB(20, 16, 30),
	})

	local front = cardSide(card, Enum.NormalId.Front, color)
	local window = Instance.new("Frame")
	window.Size = UDim2.fromScale(0.86, 0.62)
	window.Position = UDim2.fromScale(0.5, 0.06)
	window.AnchorPoint = Vector2.new(0.5, 0)
	window.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
	window.BackgroundTransparency = 0.25
	window.Parent = front
	local windowCorner = Instance.new("UICorner")
	windowCorner.CornerRadius = UDim.new(0.1, 0)
	windowCorner.Parent = window
	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.fromScale(0.96, 0.96)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Image = config and config.Icon or ""
	icon.Parent = window
	label(front, if config then config.DisplayName else tostring(result.towerId), {
		Size = UDim2.fromScale(0.9, 0.12),
		Position = UDim2.fromScale(0.5, 0.75),
	})
	label(front, string.upper(result.rarity), {
		Size = UDim2.fromScale(0.7, 0.08),
		Position = UDim2.fromScale(0.5, 0.875),
		TextColor3 = color:Lerp(WHITE, 0.45),
	})
	if result.isNew then
		local badge = Instance.new("Frame")
		badge.Size = UDim2.fromScale(0.34, 0.1)
		badge.Position = UDim2.fromScale(0.04, 0.02)
		badge.BackgroundColor3 = Color3.fromRGB(230, 45, 55)
		badge.Rotation = -8
		badge.Parent = front
		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0.5, 0)
		badgeCorner.Parent = badge
		label(badge, "NEW!", { Size = UDim2.fromScale(0.85, 0.8), Position = UDim2.fromScale(0.5, 0.5) })
	end
	if result.featured then
		label(front, "★", {
			Size = UDim2.fromScale(0.18, 0.13),
			Position = UDim2.fromScale(0.86, 0.09),
			TextColor3 = GOLD,
		})
	end
	-- The glint: a slanted light band, swept across once the card has turned (CrateCinematic.play).
	local shine = Instance.new("Frame")
	shine.Size = UDim2.fromScale(0.3, 1.8)
	shine.Position = UDim2.fromScale(-0.6, 0.5)
	shine.AnchorPoint = Vector2.new(0.5, 0.5)
	shine.Rotation = 22
	shine.BackgroundColor3 = WHITE
	shine.BackgroundTransparency = 0.35
	shine.BorderSizePixel = 0
	shine.ZIndex = 5
	shine.Parent = front
	local shineFade = Instance.new("UIGradient")
	shineFade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	shineFade.Parent = shine

	local back = cardSide(card, Enum.NormalId.Back, color)
	local runes = Instance.new("ImageLabel")
	runes.Size = UDim2.fromScale(0.95, 0.72)
	runes.Position = UDim2.fromScale(0.5, 0.5)
	runes.AnchorPoint = Vector2.new(0.5, 0.5)
	runes.BackgroundTransparency = 1
	runes.ScaleType = Enum.ScaleType.Fit
	runes.Image = RUNES
	runes.ImageTransparency = 0.45
	runes.Parent = back
	label(back, "?", { Size = UDim2.fromScale(0.5, 0.4), Position = UDim2.fromScale(0.5, 0.5) })
	return { part = card, shine = shine }
end

-- A full-screen title over the scene for the grander cases ("ROYAL CHEST"): slams in, shimmers, fades out.
local function titleCard(gui: ScreenGui, text: string, color: Color3, hold: number)
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(0.8, 0.13)
	title.Position = UDim2.fromScale(0.5, 0.2)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = text
	title.TextColor3 = WHITE
	title.TextTransparency = 1
	title.ZIndex = 8
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 5
	stroke.Color = Color3.fromRGB(20, 14, 30)
	stroke.Transparency = 1
	stroke.Parent = title
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, WHITE),
		ColorSequenceKeypoint.new(0.45, color:Lerp(WHITE, 0.3)),
		ColorSequenceKeypoint.new(1, color),
	})
	gradient.Parent = title
	-- The shimmer: a light band slides across the letters.
	local scale = Instance.new("UIScale")
	scale.Scale = 1.8
	scale.Parent = title
	title.Parent = gui
	tween(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	tween(title, TweenInfo.new(0.25), { TextTransparency = 0 })
	tween(stroke, TweenInfo.new(0.25), { Transparency = 0 })
	task.delay(0.3, function()
		if not title.Parent then
			return
		end
		gradient.Offset = Vector2.new(0, -1)
		tween(gradient, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Offset = Vector2.new(0, 0) })
	end)
	task.delay(hold, function()
		if title.Parent then
			tween(title, TweenInfo.new(0.4), { TextTransparency = 1 })
			tween(stroke, TweenInfo.new(0.4), { Transparency = 1 })
			tween(scale, TweenInfo.new(0.4), { Scale = 0.85 })
		end
	end)
end

-- Black bars top and bottom, like a film.
local function letterbox(gui: ScreenGui): () -> ()
	local bars = {}
	for _, top in { true, false } do
		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromScale(1, 0)
		bar.Position = UDim2.fromScale(0, if top then 0 else 1)
		bar.AnchorPoint = Vector2.new(0, if top then 0 else 1)
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.ZIndex = 9
		bar.Parent = gui
		tween(bar, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 0.11) })
		table.insert(bars, bar)
	end
	return function()
		for _, bar in bars do
			tween(bar, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromScale(1, 0) })
		end
	end
end

-- A firework: a glowing rocket climbs from the rim and bursts into sparks of one color.
-- The pop is on the burst at the top of the flight (0.7 s), so its sound is asked for at launch.
local function firework(folder: Instance, from: Vector3, color: Color3, caseId: string)
	CaseSounds.play(caseId, "firework", 0.7, { speed = 0.92 + math.random() * 0.2 })
	local rocket = part(folder, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.7,
		Material = Enum.Material.Neon,
		Color = color:Lerp(WHITE, 0.5),
		CFrame = CFrame.new(from),
	})
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = rocket
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = rocket
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.35
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = rocket
	local top = from + Vector3.new((math.random() - 0.5) * 10, 28 + math.random() * 14, (math.random() - 0.5) * 6)
	local start = os.clock()
	local frame = 1 / 60
	-- Bursts on the frame nearest 0.7 s, where its sound pops.
	while os.clock() - start + frame / 2 < 0.7 and rocket.Parent do
		local alpha = (os.clock() - start) / 0.7
		rocket.Position = from:Lerp(top, ease(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
		local before = os.clock()
		RunService.RenderStepped:Wait()
		frame = os.clock() - before
	end
	if not rocket.Parent then
		return
	end
	rocket.Transparency = 1
	emitter(rocket, {
		Texture = SPARKLES,
		Color = ColorSequence.new(WHITE, color),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.9, 1.5),
		Speed = NumberRange.new(14, 24),
		Drag = 2.5,
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -12, 0),
	}):Emit(70)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 40
	light.Brightness = 4
	light.Parent = rocket
	tween(light, TweenInfo.new(0.8), { Brightness = 0 })
	CaseSounds.beat(caseId, "firework")
end

function CrateCinematic.play(caseId: string, results: { any })
	local player = Players.LocalPlayer
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local camera = Workspace.CurrentCamera
	if not playerGui or not camera or #results == 0 then
		return
	end

	-- Usually done already (the window preloads); a short extra wait otherwise.
	task.spawn(CrateCinematic.preload)
	local waited = os.clock()
	while not preloaded and os.clock() - waited < 2 do
		task.wait()
	end
	local tier = CrateTiers.get(caseId) or CrateTiers.ByCase.Standard
	local order = launchOrder(results)
	local best = order[#order]
	local bestColor = useSummon.color(best.rarity)
	local bestRank = Banners.Rank(best.rarity)
	local stageColor = tier.color
	local grand = tier.level >= 4

	local skipped = false
	local playerSkipped = false
	local cleanups: { () -> () } = {}
	local function onCleanup(fn: () -> ())
		table.insert(cleanups, fn)
	end
	local slow = 1 / speed()
	-- The scene's own clock runs at timeScale (the Royal chest's slow-motion burst sets it below 1).
	local timeScale = 1

	-- Both end on the frame nearest their end time (not the first frame after it), so a beat is never more than
	-- half a frame off the sound cued for it (CaseSounds); the clock is real time scaled by timeScale.
	local frame = 1 / 60
	local function nextFrame(): number
		local before = os.clock()
		RunService.RenderStepped:Wait()
		frame = os.clock() - before
		return frame * timeScale
	end
	-- Waits, unless the player skipped.
	local function wait(seconds: number)
		local elapsed = 0
		while not skipped and elapsed + frame * timeScale / 2 < seconds * slow do
			elapsed += nextFrame()
		end
	end
	-- Calls step(alpha) every frame for `seconds` (alpha 0 -> 1).
	local function run(seconds: number, step: (number) -> ())
		local elapsed = 0
		local total = seconds * slow
		while not skipped do
			local alpha = if elapsed + frame * timeScale / 2 >= total then 1 else elapsed / total
			step(alpha)
			if alpha >= 1 then
				return
			end
			elapsed += nextFrame()
		end
	end

	-- UI: everything hidden; ours has the flash and the skip button.
	onCleanup(hideGuis(playerGui))
	local gui = Instance.new("ScreenGui")
	gui.Name = "CrateCinematic"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.ResetOnSpawn = false
	local skip = Instance.new("TextButton")
	skip.Size = UDim2.fromScale(1, 1)
	skip.BackgroundTransparency = 1
	skip.Text = ""
	skip.Parent = gui
	skip.Activated:Connect(function()
		skipped = true
		playerSkipped = true
	end)
	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, 0, 0, 34)
	hint.Position = UDim2.new(0.5, 0, 1, -24)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.BackgroundTransparency = 1
	hint.Text = "Tap to skip"
	hint.Font = Enum.Font.FredokaOne
	hint.TextSize = 26
	hint.TextColor3 = Color3.fromRGB(220, 225, 240)
	hint.TextTransparency = 0.25
	hint.ZIndex = 11
	hint.Parent = gui
	local hintStroke = Instance.new("UIStroke")
	hintStroke.Thickness = 2
	hintStroke.Transparency = 0.3
	hintStroke.Parent = hint
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = if grand then Color3.new(0, 0, 0) else WHITE
	flash.BackgroundTransparency = 0
	flash.ZIndex = 10
	flash.Parent = gui
	gui.Parent = playerGui
	onCleanup(function()
		gui:Destroy()
	end)

	-- World: the stage, the sky, a little extra glow.
	local folder = Instance.new("Folder")
	folder.Name = "CrateCinematic"
	folder.Parent = Workspace
	onCleanup(function()
		folder:Destroy()
	end)
	local stage = buildStage(folder, stageColor, tier)
	onCleanup(swapSky())
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = if tier.level >= 3 then 0.6 else 0.4
	bloom.Size = 24
	bloom.Threshold = 0.95
	bloom.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Saturation = 0.15
	grade.Contrast = 0.08
	grade.Parent = Lighting
	onCleanup(function()
		bloom:Destroy()
		grade:Destroy()
	end)
	-- Slow motion also slows every particle in the scene.
	local function setTimeScale(value: number)
		timeScale = value
		for _, descendant in folder:GetDescendants() do
			if descendant:IsA("ParticleEmitter") then
				descendant.TimeScale = value
			end
		end
	end

	-- Camera: scripted, with a shake that decays on its own. The same loop turns the runes and floats the islands.
	local oldType, oldFov, oldSubject = camera.CameraType, camera.FieldOfView, camera.CameraSubject
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = FOV
	controls(false)
	onCleanup(function()
		camera.CameraType = oldType
		camera.FieldOfView = oldFov
		camera.CameraSubject = oldSubject
		controls(true)
	end)
	-- Starts looking up into the sky, where the chest will come from.
	local camFrom = CFrame.lookAt(STAGE + Vector3.new(0, 13, 38), STAGE + Vector3.new(0, 60, 0))
	local camCF = camFrom
	local shake = 0
	local clock = 0
	local runeSpin = 0.25
	local spinners: { { part: BasePart, base: () -> CFrame, speed: number } } = {}
	RunService:BindToRenderStep("CrateCinematic", Enum.RenderPriority.Camera.Value + 1, function(dt)
		dt *= timeScale
		clock += dt
		shake = math.max(0, shake - dt * 2.2)
		local offset = CFrame.new(math.noise(clock * 18, 0) * shake, math.noise(0, clock * 18) * shake, 0)
			* CFrame.Angles(0, 0, math.noise(clock * 12, 7) * shake * 0.03)
		camera.CFrame = camCF * offset
		stage.runes.CFrame = CFrame.new(STAGE + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, clock * runeSpin, 0)
		for _, island in stage.islands do
			island.part.CFrame = island.base * CFrame.new(0, math.sin(clock * 0.5 + island.phase) * 1.5, 0)
				* CFrame.Angles(0, clock * 0.03, 0)
		end
		for _, spinner in spinners do
			if spinner.part.Parent then
				spinner.part.CFrame = spinner.base() * CFrame.Angles(0, clock * spinner.speed, 0)
			end
		end
	end)
	onCleanup(function()
		RunService:UnbindFromRenderStep("CrateCinematic")
	end)

	local liftLetterbox: (() -> ())? = nil
	-- A skipped opening fades its sounds out; a finished one lets the last chime / fanfare ring into the popup.
	onCleanup(function()
		if playerSkipped then
			CaseSounds.stopAll(0.3)
		end
	end)

	local ok, err = pcall(function()
		-- 1. The beam comes down on the altar (the Royal chest fades in from black, under film bars).
		tween(flash, TweenInfo.new(if grand then 0.9 else 0.3), { BackgroundTransparency = 1 })
		if tier.letterbox then
			liftLetterbox = letterbox(gui)
		end
		local beam = beamUp(folder, STAGE, 400, if tier.level == 1 then 4 else 9, if grand then GOLD:Lerp(WHITE, 0.5) else WHITE, 1)
		local beamFade = Instance.new("NumberValue")
		beamFade.Value = 1
		beamFade.Changed:Connect(function(value)
			beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, value), NumberSequenceKeypoint.new(1, 1) })
		end)
		beamFade.Parent = folder
		tween(beamFade, TweenInfo.new(0.3), { Value = 0.35 })
		CaseSounds.beat(caseId, "intro")
		CaseSounds.play(caseId, "intro")
		if tier.title then
			-- After the fade-in, so it isn't hidden under the black; its sound lands with it.
			local titleAt = if grand then 0.6 else 0.15
			CaseSounds.play(caseId, "title", titleAt)
			task.delay(titleAt, function()
				if gui.Parent and not skipped then
					CaseSounds.beat(caseId, "title")
					titleCard(gui, tier.title :: string, stageColor, if grand then 2.4 else 1.4)
				end
			end)
		end
		wait(if grand then 0.9 else 0.4)

		-- 2. The chest falls from the sky (the Royal chest comes down slowly on the beam, wrapped in turning rings).
		local crate = CrateModel.build(tier.style)
		-- Its front (lock, local -Z) faces the camera (+Z), turned a little for depth.
		local landed = CFrame.new(STAGE + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, math.rad(180 - 18), 0)
		local high = if tier.descent
			then landed * CFrame.new(0, 46, 0) * CFrame.Angles(0, math.pi * 2, 0)
			else landed * CFrame.new(0, DROP_HEIGHT, 0) * CFrame.Angles(0.3, 1.4, 0.2)
		crate.model:PivotTo(high)
		crate.model.Parent = folder
		local trailA = Instance.new("Attachment")
		trailA.Position = Vector3.new(-2.8, 1.5, 0)
		trailA.Parent = crate.body
		local trailB = Instance.new("Attachment")
		trailB.Position = Vector3.new(2.8, 1.5, 0)
		trailB.Parent = crate.body
		local trail = Instance.new("Trail")
		trail.Attachment0 = trailA
		trail.Attachment1 = trailB
		trail.Lifetime = 0.4
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.Color = ColorSequence.new(WHITE, stageColor)
		trail.Transparency = NumberSequence.new(0.15, 1)
		trail.Parent = crate.body
		local fallSparks = emitter(crate.body, {
			Texture = SPARKLES,
			Color = ColorSequence.new(GOLD, stageColor),
			Size = NumberSequence.new(1.2, 0),
			Lifetime = NumberRange.new(0.4, 0.8),
			Speed = NumberRange.new(2, 6),
			SpreadAngle = Vector2.new(180, 180),
			Rate = if tier.level == 1 then 30 else 80,
		})
		fallSparks.Enabled = true
		local rings: { Part } = {}
		if tier.descent then
			for index = 1, 3 do
				local ring, ringDecal = floorImage(folder, RUNES, 9 + index * 2.5, 0, GOLD, 0.15)
				ringDecal.Color3 = GOLD:Lerp(WHITE, 0.2)
				table.insert(rings, ring)
				local height = index * 1.6
				table.insert(spinners, {
					part = ring,
					base = function()
						return CFrame.new(crate.model:GetPivot().Position + Vector3.new(0, height, 0))
					end,
					speed = if index % 2 == 0 then -1.6 else 1.2,
				})
			end
		end

		local camLand = CFrame.lookAt(STAGE + Vector3.new(0, 15, 36), STAGE + Vector3.new(0, 4, 0))
		if tier.descent then
			-- A slow, heavy descent; the camera tilts down with it.
			local camHigh = CFrame.lookAt(STAGE + Vector3.new(0, 20, 40), STAGE + Vector3.new(0, 40, 0))
			run(0.6, function(alpha)
				camCF = camFrom:Lerp(camHigh, ease(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
			end)
			CaseSounds.play(caseId, "descent", 2.4 * slow)
			run(2.4, function(alpha)
				local eased = ease(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				crate.model:PivotTo(high:Lerp(landed, eased))
				camCF = camHigh:Lerp(camLand, eased)
			end)
		else
			CaseSounds.play(caseId, "fall", tier.fallTime * slow)
			run(tier.fallTime, function(alpha)
				crate.model:PivotTo(high:Lerp(landed, ease(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.In)))
				camCF = camFrom:Lerp(camLand, ease(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
			end)
		end
		crate.model:PivotTo(landed)
		camCF = camLand
		fallSparks.Enabled = false
		trail.Enabled = false

		-- Impact.
		shake = if tier.level == 1 then 0.8 elseif tier.descent then 1.2 else 1.6
		CaseSounds.beat(caseId, "land")
		CaseSounds.play(caseId, "land")
		tween(beamFade, TweenInfo.new(0.35), { Value = 1 })
		local ground = anchor(folder, STAGE + Vector3.new(0, 0.4, 0))
		emitter(ground, {
			Texture = SMOKE,
			LightEmission = 0.15,
			Color = ColorSequence.new(Color3.fromRGB(225, 215, 245)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 7) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.8, 1.3),
			Speed = NumberRange.new(22, 34),
			Drag = 5,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-60, 60),
			SpreadAngle = Vector2.new(85, 85),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, -5, 0),
		}):Emit(if tier.level == 1 then 30 else 60)
		emitter(ground, {
			Color = ColorSequence.new(GOLD),
			Size = NumberSequence.new(0.6, 0),
			Lifetime = NumberRange.new(0.4, 0.8),
			Speed = NumberRange.new(20, 40),
			SpreadAngle = Vector2.new(80, 80),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, -40, 0),
		}):Emit(if tier.level == 1 then 15 else 40)
		-- Shockwaves of runes race out across the floor, one after another.
		for index = 1, tier.shockwaves do
			task.delay((index - 1) * 0.16, function()
				if not folder.Parent then
					return
				end
				local wave, waveDecal = floorImage(folder, RUNES, 6, 0.15 + index * 0.02, if index == 1 then WHITE else stageColor, 0)
				local reach = 60 + (index - 1) * 25
				tween(wave, TweenInfo.new(0.7 + index * 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(reach, 0.05, reach) })
				tween(waveDecal, TweenInfo.new(0.7 + index * 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 })
			end)
		end
		for _, ring in rings do
			local decal = ring:FindFirstChildOfClass("Decal")
			if decal then
				tween(decal, TweenInfo.new(0.8), { Transparency = 1 })
			end
		end
		if tier.level >= 2 then
			stage.runeDecal.Color3 = WHITE
			stage.runeDecal.Transparency = 0
			tween(stage.runeDecal, TweenInfo.new(0.9), { Color3 = stageColor, Transparency = 0.2 })
			runeSpin = 2.5
			task.delay(0.5, function()
				runeSpin = 0.4
			end)
		end
		-- A little bounce on landing.
		run(0.26, function(alpha)
			crate.model:PivotTo(landed * CFrame.new(0, math.sin(alpha * math.pi) * 0.9, 0))
		end)
		crate.model:PivotTo(landed)
		wait(0.15)

		-- 3. Charge: rattling, sparks pulled in, light in the best rarity's color; lightning to the floor from
		-- tier 3; the world dims around it; the Royal chest gets an orbiting camera and a heartbeat.
		CaseSounds.beat(caseId, "charge")
		local pull = part(folder, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 18,
			CFrame = CFrame.new(STAGE + Vector3.new(0, 4.5, 0)),
			Transparency = 1,
		})
		local inward = emitter(pull, {
			Color = ColorSequence.new(WHITE, bestColor),
			Size = NumberSequence.new(0.6, 0.1),
			Lifetime = NumberRange.new(0.5, 0.8),
			Speed = NumberRange.new(14, 20),
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			Rate = 90,
		})
		inward.Enabled = tier.level >= 2
		-- Lightning: beams from the chest to points on the floor, re-aimed a few times a second.
		local arcTop = anchor(folder, STAGE + Vector3.new(0, 5, 0))
		local arcStart = Instance.new("Attachment")
		arcStart.Parent = arcTop
		local arcs = {}
		for index = 1, if tier.lightning then (if grand then 7 else 4) else 0 do
			local foot = anchor(folder, STAGE)
			local footAttachment = Instance.new("Attachment")
			footAttachment.Parent = foot
			local arc = Instance.new("Beam")
			arc.Attachment0 = arcStart
			arc.Attachment1 = footAttachment
			arc.Texture = LIGHTNING
			arc.TextureMode = Enum.TextureMode.Stretch
			arc.TextureSpeed = 0
			arc.Width0 = 1.4
			arc.Width1 = 0.8
			arc.LightEmission = 1
			arc.FaceCamera = true
			arc.Color = ColorSequence.new(bestColor:Lerp(WHITE, 0.35))
			arc.Transparency = NumberSequence.new(1)
			arc.Parent = arcTop
			table.insert(arcs, { beam = arc, foot = foot, index = index })
		end
		if tier.dim then
			tween(grade, TweenInfo.new(0.8), { Brightness = -0.18, TintColor = Color3.fromRGB(205, 195, 235) })
		end
		crate.glow.Color = bestColor
		local lidClosed = crate.lid:GetPivot()
		local camCharge = CFrame.lookAt(STAGE + Vector3.new(0, 11, 25), STAGE + Vector3.new(0, 4, 0))
		local chargeTime = tier.chargeTime + (if bestRank >= Banners.Rank("Epic") then 0.3 else 0)
		-- The riser (and the Royal chest's rumble with its heartbeat) peaks on the burst.
		CaseSounds.play(caseId, "charge", chargeTime * slow)
		CaseSounds.play(caseId, "rumble", chargeTime * slow)
		local nextArc = 0
		run(chargeTime, function(alpha)
			local strength = alpha * alpha
			local jitter = CFrame.new((math.random() - 0.5) * 0.5 * strength, 0, (math.random() - 0.5) * 0.5 * strength)
				* CFrame.Angles(0, 0, (math.random() - 0.5) * 0.12 * strength)
			crate.model:PivotTo(landed * jitter)
			crate.lid:PivotTo(crate.model:GetPivot() * landed:ToObjectSpace(lidClosed) * CFrame.Angles(math.random() * 0.18 * strength, 0, 0))
			crate.glow.Range = 4 + 16 * strength
			crate.glow.Brightness = 0.5 + 2.5 * strength
			if tier.orbit then
				-- Half a circle around the chest, ending in front of it, closing in as it goes.
				local angle = math.pi * (1 - ease(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
				local radius = 30 - 6 * alpha
				local height = 14 - 4 * alpha
				camCF = CFrame.lookAt(STAGE + Vector3.new(math.sin(angle) * radius, height, math.cos(angle) * radius), STAGE + Vector3.new(0, 4, 0))
			else
				camCF = camLand:Lerp(camCharge, ease(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
			end
			shake = math.max(shake, (if tier.level == 1 then 0.12 else 0.25) * strength)
			inward.Rate = 90 + 160 * strength * tier.burst
			runeSpin = 0.4 + 3 * strength
			if #arcs > 0 and os.clock() >= nextArc and alpha > 0.25 then
				nextArc = os.clock() + 0.07
				for _, arc in arcs do
					local visible = math.random() < 0.35 + 0.6 * strength
					local angle = math.random() * math.pi * 2
					local reach = 6 + math.random() * 7
					arc.foot.CFrame = CFrame.new(STAGE + Vector3.new(math.sin(angle) * reach, 0.2, math.cos(angle) * reach))
					arc.beam.CurveSize0 = (math.random() - 0.5) * 8
					arc.beam.CurveSize1 = (math.random() - 0.5) * 8
					arc.beam.Transparency = NumberSequence.new(if visible then 0.1 else 1)
				end
			end
		end)
		if tier.orbit then
			camCharge = CFrame.lookAt(STAGE + Vector3.new(0, 10, 24), STAGE + Vector3.new(0, 4, 0))
			camCF = camCharge
		end
		inward.Enabled = false
		for _, arc in arcs do
			arc.beam.Enabled = false
		end
		crate.model:PivotTo(landed)

		-- 4. Burst.
		CaseSounds.beat(caseId, "open")
		CaseSounds.play(caseId, "open")
		CaseSounds.play(caseId, "shimmer")
		if tier.coins then
			CaseSounds.play(caseId, "coins")
		end
		if tier.dim then
			tween(grade, TweenInfo.new(0.5), { Brightness = 0.05, TintColor = WHITE })
		end
		flash.BackgroundColor3 = bestColor:Lerp(WHITE, 0.6)
		flash.BackgroundTransparency = if tier.level == 1 then 0.5 else 0.05
		tween(flash, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
		shake = if tier.level == 1 then 0.9 else 2
		camera.FieldOfView = FOV + (if grand then 14 else 8)
		tween(camera, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { FieldOfView = FOV })
		local blast = anchor(folder, STAGE + Vector3.new(0, 5, 0))
		emitter(blast, {
			Texture = SPARKLES,
			Color = ColorSequence.new(WHITE, bestColor),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.7, 1.3),
			Speed = NumberRange.new(28, 55),
			Drag = 3,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-200, 200),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, -20, 0),
		}):Emit(math.floor((if bestRank >= Banners.Rank("Legendary") then 140 else 90) * tier.burst))
		emitter(blast, {
			Color = ColorSequence.new(bestColor),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 20) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.4, 0.5),
			Speed = NumberRange.new(0, 0),
		}):Emit(3)
		emitter(blast, {
			Texture = SMOKE,
			LightEmission = 0.3,
			Color = ColorSequence.new(bestColor:Lerp(WHITE, 0.5)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.9, 1.4),
			Speed = NumberRange.new(8, 16),
			Drag = 3,
			Rotation = NumberRange.new(0, 360),
			SpreadAngle = Vector2.new(180, 180),
		}):Emit(math.floor(20 * tier.burst))
		if tier.coins then
			-- Coins spray out of the chest and bounce off the floor.
			emitter(blast, {
				Texture = Ids.Rewards.Coins,
				LightEmission = 0,
				Color = ColorSequence.new(WHITE),
				Size = NumberSequence.new(0.9),
				Lifetime = NumberRange.new(1.4, 2),
				Speed = NumberRange.new(22, 34),
				SpreadAngle = Vector2.new(35, 35),
				EmissionDirection = Enum.NormalId.Top,
				Acceleration = Vector3.new(0, -45, 0),
				Rotation = NumberRange.new(-30, 30),
				RotSpeed = NumberRange.new(-180, 180),
			}):Emit(if grand then 60 else 30)
		end
		-- A column of light in the best rarity's color, and the altar takes that color too.
		if tier.column then
			local column = beamUp(folder, STAGE + Vector3.new(0, 3, 0), 260, if grand then 11 else 7, bestColor, 0.1)
			local columnFade = Instance.new("NumberValue")
			columnFade.Value = 0.1
			columnFade.Changed:Connect(function(value)
				column.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, value), NumberSequenceKeypoint.new(1, 1) })
				column.Width0 = (if grand then 11 else 7) * (1 - value) + 1
			end)
			columnFade.Parent = folder
			tween(columnFade, TweenInfo.new(if grand then 3 else 1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 1 })
		end
		if tier.godRays then
			-- A fan of light rays from the open chest, turning slowly, fading over a few seconds.
			-- They fan out behind the chest, so the camera in front sees all of them against the sky.
			for index = 1, 11 do
				local angle = math.rad(-85 + (index - 1) * 17)
				local tip = STAGE + Vector3.new(math.sin(angle) * 60, 22 + math.cos(angle) * 40 + (index % 2) * 10, -50)
				local from = anchor(folder, STAGE + Vector3.new(0, 4, 0))
				local to = anchor(folder, tip)
				local a0 = Instance.new("Attachment")
				a0.Parent = from
				local a1 = Instance.new("Attachment")
				a1.Parent = to
				local ray = Instance.new("Beam")
				ray.Attachment0 = a0
				ray.Attachment1 = a1
				ray.Width0 = 1.4
				ray.Width1 = 12
				ray.LightEmission = 1
				ray.FaceCamera = true
				ray.Segments = 2
				ray.Color = ColorSequence.new(GOLD:Lerp(WHITE, 0.4), bestColor)
				ray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
				ray.Parent = from
				local fade = Instance.new("NumberValue")
				fade.Value = 0.2
				fade.Changed:Connect(function(value)
					ray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, value), NumberSequenceKeypoint.new(1, 1) })
				end)
				fade.Parent = from
				tween(fade, TweenInfo.new(4.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 1 })
			end
			-- Gold rain over the whole altar until the end.
			local sky = part(folder, { Size = Vector3.new(70, 1, 70), CFrame = CFrame.new(STAGE + Vector3.new(0, 45, 0)), Transparency = 1 })
			local rain = emitter(sky, {
				Texture = SPARKLES,
				Color = ColorSequence.new(GOLD, WHITE),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.2) }),
				Lifetime = NumberRange.new(3, 4),
				Speed = NumberRange.new(8, 14),
				EmissionDirection = Enum.NormalId.Bottom,
				Shape = Enum.ParticleEmitterShape.Box,
				Rate = 60,
			})
			rain.Enabled = true
		end
		tween(stage.runeDecal, TweenInfo.new(0.4), { Color3 = bestColor })
		for _, pillar in stage.pillars do
			pillar.Color = ColorSequence.new(bestColor)
		end
		crate.inner.Color = bestColor
		crate.glow.Range = 26
		crate.glow.Brightness = 5
		tween(crate.glow, TweenInfo.new(1.2), { Range = 14, Brightness = 2 })

		-- The lid flies off, spinning, and falls behind the chest.
		local lidStart = crate.lid:GetPivot()
		local lidParts = {}
		for _, descendant in crate.lid:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(lidParts, descendant)
			end
		end
		task.spawn(function()
			run(0.9, function(alpha)
				local rise = math.sin(alpha * math.pi * 0.85) * (if tier.level == 1 then 8 else 16)
				crate.lid:PivotTo(lidStart * CFrame.new(0, rise, 14 * alpha) * CFrame.Angles(-alpha * 9, alpha * 3, alpha * 2))
				for _, lidPart in lidParts do
					lidPart.Transparency = math.max(0, (alpha - 0.6) / 0.4)
				end
			end)
		end)
		if tier.slowmo then
			-- Slow motion: the burst hangs in the air for a moment, then time speeds back up.
			setTimeScale(tier.slowmo)
			CaseSounds.play(caseId, "slowmo")
			local hang = os.clock()
			while not skipped and os.clock() - hang < 1.1 * slow do
				RunService.RenderStepped:Wait()
			end
			local ramp = os.clock()
			while not skipped and os.clock() - ramp < 0.4 * slow do
				setTimeScale(tier.slowmo + (1 - tier.slowmo) * (os.clock() - ramp) / (0.4 * slow))
				RunService.RenderStepped:Wait()
			end
			setTimeScale(1)
		end
		if tier.fireworks then
			for index = 1, 8 do
				task.delay(0.15 + index * 0.28, function()
					if not folder.Parent or skipped then
						return
					end
					local angle = math.rad(-150 + (index - 1) * 300 / 7)
					local from = STAGE + Vector3.new(math.sin(angle) * 20, 0.5, math.cos(angle) * 20 - 6)
					local colors = { GOLD, bestColor, Color3.fromRGB(255, 90, 200), Color3.fromRGB(90, 200, 255) }
					firework(folder, from, colors[index % #colors + 1], caseId)
				end)
			end
		end
		wait(0.18)

		-- 5. The towers rain down around the chest.
		local camRain = CAMERA_RAIN
		task.spawn(function()
			run(0.85, function(alpha)
				camCF = camCharge:Lerp(camRain, ease(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
			end)
		end)
		local spots = landingSpots(#order)
		local stagger = if #order > 1 then 0.13 else 0
		local flying = #order
		for index, result in order do
			local isBest = index == #order
			task.spawn(function()
				local color = useSummon.color(result.rarity)
				local rank = Banners.Rank(result.rarity)
				local orb = part(folder, {
					Shape = Enum.PartType.Ball,
					Size = Vector3.one * (if isBest then ORB_SIZE * 1.3 else ORB_SIZE),
					Color = color,
					Material = Enum.Material.Neon,
					CFrame = CFrame.new(STAGE + Vector3.new(0, 6, 0)),
				})
				local light = Instance.new("PointLight")
				light.Color = color
				light.Range = if rank >= Banners.Rank("Epic") then 12 else 7
				light.Brightness = 2
				light.Parent = orb
				local a0 = Instance.new("Attachment")
				a0.Position = Vector3.new(0, 0.5, 0)
				a0.Parent = orb
				local a1 = Instance.new("Attachment")
				a1.Position = Vector3.new(0, -0.5, 0)
				a1.Parent = orb
				local orbTrail = Instance.new("Trail")
				orbTrail.Attachment0 = a0
				orbTrail.Attachment1 = a1
				orbTrail.Lifetime = 0.3
				orbTrail.LightEmission = 1
				orbTrail.FaceCamera = true
				orbTrail.Color = ColorSequence.new(color)
				orbTrail.Transparency = NumberSequence.new(0.1, 1)
				orbTrail.Parent = orb
				-- A soft halo that keeps sparkling while it hovers.
				local halo = emitter(orb, {
					Color = ColorSequence.new(color),
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }),
					Lifetime = NumberRange.new(0.5, 0.9),
					Speed = NumberRange.new(1, 2.5),
					SpreadAngle = Vector2.new(180, 180),
					Rate = if rank >= Banners.Rank("Epic") then 30 else 12,
				})
				halo.Enabled = true

				local start = STAGE + Vector3.new(0, 6, 0)
				local target = spots[index] + Vector3.new(0, ORB_SIZE / 2 + 0.3, 0)
				local apex = 12 + (if isBest then 6 else math.random() * 5)
				run(if isBest then 0.8 else 0.6, function(alpha)
					orb.Position = start:Lerp(target, alpha) + Vector3.new(0, apex * 4 * alpha * (1 - alpha), 0)
				end)
				orb.Position = target
				orbTrail.Enabled = false

				local landing = anchor(folder, target)
				emitter(landing, {
					Texture = SPARKLES,
					Color = ColorSequence.new(WHITE, color),
					Size = NumberSequence.new(1, 0),
					Lifetime = NumberRange.new(0.4, 0.7),
					Speed = NumberRange.new(8, 16),
					SpreadAngle = Vector2.new(70, 70),
					EmissionDirection = Enum.NormalId.Top,
					Acceleration = Vector3.new(0, -25, 0),
				}):Emit(if isBest then 40 else 14)
				local ring, ringDecal = floorImage(folder, RUNES, 2, target.Y - STAGE.Y - ORB_SIZE / 2 - 0.2, color, 0)
				ring.Position = Vector3.new(target.X, ring.Position.Y, target.Z)
				tween(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(if isBest then 12 else 7, 0.05, if isBest then 12 else 7) })
				tween(ringDecal, TweenInfo.new(0.5), { Transparency = 1 })
				CaseSounds.beat(caseId, if isBest then "best" else "card")
				if isBest then
					-- The Royal chest (always Legendary or better) gets its fanfare instead of the chime.
					CaseSounds.play(caseId, if CaseSounds.has(caseId, "fanfare") then "fanfare" else "best")
				else
					CaseSounds.play(caseId, "card")
				end
				if isBest or rank >= Banners.Rank("Legendary") then
					shake = math.max(shake, 0.8)
					beamUp(folder, target, 50, if grand then 3.6 else 2.6, color, 0.2)
				end

				-- The orb pops into a card: it jumps up showing its back, spins and turns its face to the camera.
				-- One tower gets one big card; out of ten the best is a little bigger than the rest.
				local card = buildCard(folder, result, color, if #order == 1 then 1.9 elseif isBest then 1.4 else 1.1)
				local size = card.part.Size
				local floorY = spots[index].Y
				local rest = Vector3.new(target.X, floorY + 0.5 + size.Y / 2, target.Z)
				local facing = CAMERA_RAIN.Position
				local orbSize = orb.Size
				light.Parent = card.part
				halo.Parent = card.part
				halo.Rate = if rank >= Banners.Rank("Epic") then 40 else 16
				halo.Speed = NumberRange.new(2, 4)
				halo.Shape = Enum.ParticleEmitterShape.Box
				halo.EmissionDirection = Enum.NormalId.Back
				local function place(position: Vector3, spin: number, scale: number)
					card.part.Size = size * math.max(scale, 0.02)
					card.part.CFrame = CFrame.lookAt(position, Vector3.new(facing.X, position.Y + 4, facing.Z))
						* CFrame.Angles(0, spin, 0)
				end
				place(target, math.pi * 3, 0)
				-- A smooth hop and turn to its face; the best one hops higher and turns a little longer.
				run(if isBest then 0.85 else 0.7, function(alpha)
					local grow = ease(alpha, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
					local turn = ease(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					local hop = math.sin(alpha * math.pi) * (if isBest then 3 else 2)
					place(target:Lerp(rest, turn) + Vector3.new(0, hop, 0), math.pi * 3 * (1 - turn), grow)
					orb.Size = orbSize * math.max(0, 1 - alpha * 4)
				end)
				orb:Destroy()
				place(rest, 0, 1)
				-- A glint runs across the face once it is turned.
				tween(card.shine, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(1.6, 0.5) })
				if rank >= Banners.Rank("Epic") then
					emitter(card.part, {
						Texture = SPARKLES,
						Color = ColorSequence.new(WHITE, color),
						Size = NumberSequence.new(0.8, 0),
						Lifetime = NumberRange.new(0.5, 0.8),
						Speed = NumberRange.new(6, 12),
						SpreadAngle = Vector2.new(180, 180),
					}):Emit(if isBest then 30 else 16)
				end

				-- Floating and swaying gently until the end.
				local phase = math.random() * math.pi * 2
				local started = os.clock()
				flying -= 1
				while not skipped and card.part.Parent do
					local t = os.clock() - started
					place(rest + Vector3.new(0, math.sin(t * 2.2 + phase) * 0.18, 0), math.sin(t * 1.4 + phase) * 0.12, 1)
					RunService.RenderStepped:Wait()
				end
			end)
			wait(if isBest then stagger + 0.35 else stagger)
		end
		while flying > 0 and not skipped do
			RunService.RenderStepped:Wait()
		end
		-- A moment to look at them all.
		wait(tier.hold + (if bestRank >= Banners.Rank("Legendary") then 0.3 else 0))
	end)
	if not ok then
		warn("CrateCinematic: " .. tostring(err))
	end
	if liftLetterbox then
		liftLetterbox()
	end

	-- Out: a quick white flash hides the switch back to the lobby.
	skipped = true
	flash.BackgroundColor3 = WHITE
	flash.BackgroundTransparency = 0
	task.wait()
	for index = #cleanups, 1, -1 do
		pcall(cleanups[index])
	end
end

return CrateCinematic
