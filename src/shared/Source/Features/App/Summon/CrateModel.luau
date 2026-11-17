-- The 3D summon crates for CrateCinematic: generated meshes (Studio MCP generate_mesh, 2026-11-10), body and lid
-- apart so the lid can rattle and fly off. They are SpecialMeshes (MeshId / TextureId can be set from code), so
-- nothing has to live in the place file.
-- CrateModel.build(styleId) -> { model, lid, body, glow, inner }. The model's pivot is the middle of its bottom;
-- the lid is its own Model, pivoting on the back hinge. Front (the lock) is local -Z.
-- Purely visual and client-side: nothing collides or replicates.
local CrateModel = {}

export type MeshInfo = {
	mesh: string,
	texture: string,
	size: Vector3, -- the mesh's own size (MeshPart.MeshSize)
	offset: Vector3, -- its center from the crate's bottom center, at scale 1
}

export type Style = {
	body: MeshInfo,
	lid: MeshInfo,
	hinge: Vector3, -- back edge of the lid, from the bottom center, at scale 1
	top: number, -- height of the body's open top, at scale 1
	scale: number,
	color: Color3, -- the crate's own color, for the stage and trails
	tint: Vector3?, -- SpecialMesh.VertexColor: recolors a shared mesh's texture (Event = the purple chest in pink)
}

export type Crate = {
	model: Model,
	lid: Model,
	body: BasePart,
	glow: PointLight,
	inner: BasePart,
}

CrateModel.Styles = {
	-- Purple chest with gold bands, rivets, a padlock and a handle ("stylized cartoon fantasy treasure chest").
	Standard = {
		body = {
			mesh = "rbxassetid://99725067903165",
			texture = "rbxassetid://97126372656813",
			size = Vector3.new(5.173, 3.333, 4.008),
			offset = Vector3.new(0.011, 1.657, 0.061),
		},
		lid = {
			mesh = "rbxassetid://78284355205792",
			texture = "rbxassetid://92289660352598",
			size = Vector3.new(5.297, 4.535, 4.334),
			offset = Vector3.new(0.007, 3.723, -0.036),
		},
		hinge = Vector3.new(0, 3.3, 2.1),
		top = 3.25,
		scale = 1.3,
		color = Color3.fromRGB(150, 70, 230),
	},
-- Generated 2026-11-16 in the lobby place (generate_mesh, segmentation explicit "chest body, lid"); the lock faces -Z.
	Wooden = { -- the Wooden chest (ChestsConfig Basic)
		body = {
			mesh = "rbxassetid://73926679820865",
			texture = "rbxassetid://126592400887659",
			size = Vector3.new(5.149, 2.829, 4),
			offset = Vector3.new(0, 1.415, 0),
		},
		lid = {
			mesh = "rbxassetid://110534555303070",
			texture = "rbxassetid://81145239825763",
			size = Vector3.new(4.885, 1.982, 3.966),
			offset = Vector3.new(0.002, 3.5, -0.013),
		},
		hinge = Vector3.new(0, 2.83, 1.98),
		top = 2.75,
		scale = 1.25,
		color = Color3.fromRGB(150, 100, 60),
	},
	Golden = {
		body = {
			mesh = "rbxassetid://90222840649117",
			texture = "rbxassetid://134460388775549",
			size = Vector3.new(5.2, 3.094, 3.93),
			offset = Vector3.new(0, 1.547, 0),
		},
		lid = {
			mesh = "rbxassetid://85629505087493",
			texture = "rbxassetid://85498007985258",
			size = Vector3.new(4.584, 1.869, 3.53),
			offset = Vector3.new(0.012, 3.659, 0.102),
		},
		hinge = Vector3.new(0, 3.09, 1.85),
		top = 3.0,
		scale = 1.3,
		color = Color3.fromRGB(255, 190, 50),
	},
	Royal = { -- the Robux chest: crimson velvet and gold
		body = {
			mesh = "rbxassetid://112122132902507",
			texture = "rbxassetid://73740321357690",
			size = Vector3.new(3.919, 2.045, 3.908),
			offset = Vector3.new(0, 1.023, 0),
		},
		lid = {
			mesh = "rbxassetid://72537266608925",
			texture = "rbxassetid://88762993315329",
			size = Vector3.new(4.028, 1.817, 4),
			offset = Vector3.new(0, 2.58, -0.005),
		},
		hinge = Vector3.new(0, 2.05, 2.0),
		top = 2.0,
		scale = 1.75,
		color = Color3.fromRGB(255, 200, 60),
	},
} :: { [string]: Style }
-- The Event summon: the Standard chest tinted pink.
CrateModel.Styles.Event = table.clone(CrateModel.Styles.Standard)
CrateModel.Styles.Event.color = Color3.fromRGB(255, 90, 200)
CrateModel.Styles.Event.tint = Vector3.new(1.35, 0.75, 1.05)

local function meshPart(parent: Instance, name: string, info: MeshInfo, scale: number, pivot: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = info.size * scale
	p.CFrame = pivot * CFrame.new(info.offset * scale)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = info.mesh
	mesh.TextureId = info.texture
	mesh.Scale = Vector3.one * scale
	mesh.Parent = p
	p.Parent = parent
	return p
end

local function tint(part: BasePart, color: Vector3?)
	local mesh = part:FindFirstChildOfClass("SpecialMesh")
	if mesh and color then
		mesh.VertexColor = color
	end
end

function CrateModel.build(styleId: string): Crate
	local style = CrateModel.Styles[styleId] or CrateModel.Styles.Standard
	local scale = style.scale
	local origin = CFrame.new()
	local model = Instance.new("Model")
	model.Name = "Crate_" .. styleId

	local body = meshPart(model, "Body", style.body, scale, origin)
	tint(body, style.tint)

	-- Seen once the lid is off: a dark inside that lights up when the crate bursts (CrateCinematic sets its color).
	local inner = Instance.new("Part")
	inner.Name = "Inner"
	inner.Size = Vector3.new(style.body.size.X * 0.8, 0.1, style.body.size.Z * 0.75) * Vector3.new(scale, 1, scale)
	inner.CFrame = CFrame.new(0, style.top * scale - 0.15, 0)
	inner.Color = Color3.fromRGB(30, 14, 60)
	inner.Material = Enum.Material.Neon
	inner.Anchored = true
	inner.CanCollide = false
	inner.CanQuery = false
	inner.CanTouch = false
	inner.CastShadow = false
	inner.Parent = model

	-- The light inside: off until the crate starts to charge.
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.one * 0.2
	core.CFrame = CFrame.new(0, style.top * scale + 0.8, 0)
	core.Transparency = 1
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.Parent = model
	local glow = Instance.new("PointLight")
	glow.Range = 0
	glow.Brightness = 0
	glow.Shadows = false
	glow.Parent = core

	local lid = Instance.new("Model")
	lid.Name = "Lid"
	local lidPart = meshPart(lid, "LidMesh", style.lid, scale, origin)
	tint(lidPart, style.tint)
	lid.PrimaryPart = lidPart
	-- Pivot on the back hinge, so turning the pivot opens the lid like a real chest.
	lidPart.PivotOffset = CFrame.new(style.hinge * scale - style.lid.offset * scale)
	lid.Parent = model

	model.PrimaryPart = body
	body.PivotOffset = CFrame.new(-style.body.offset * scale)
	return { model = model, lid = lid, body = body, glow = glow, inner = inner }
end

return CrateModel
