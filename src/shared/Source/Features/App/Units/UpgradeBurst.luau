local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local function playUpgradeBurst(panel, tower)
	local objects, tweens = {}, {}
	local function animate(object, duration, goal)
		local tween = TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		table.insert(tweens, tween)
		tween:Play()
	end
	local function keep(object)
		table.insert(objects, object)
		Debris:AddItem(object, 1.3)
		return object
	end
	local flash = keep(Instance.new("Highlight"))
	flash.Adornee = tower
	flash.FillColor = Color3.fromRGB(130, 255, 180)
	flash.OutlineColor = Color3.new(1, 1, 1)
	flash.FillTransparency = 0.25
	flash.DepthMode = Enum.HighlightDepthMode.Occluded
	flash.Parent = tower
	animate(flash, 0.85, { FillTransparency = 1, OutlineTransparency = 1 })

	local layer = keep(Instance.new("Frame"))
	layer.Name = "UpgradeCelebration"
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundTransparency = 1
	layer.ZIndex = 20
	layer.Parent = panel
	local random = Random.new()
	local colors = { Color3.fromRGB(132, 255, 174), Color3.fromRGB(255, 218, 102), Color3.fromRGB(124, 211, 255), Color3.fromRGB(228, 160, 255) }
	for index = 1, 28 do
		local piece = Instance.new("Frame")
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.fromScale(0.5, 0.8)
		piece.Size = UDim2.fromOffset(random:NextInteger(5, 9), random:NextInteger(9, 16))
		piece.BackgroundColor3 = colors[(index - 1) % #colors + 1]
		piece.BorderSizePixel = 0
		piece.Rotation = random:NextNumber(-90, 90)
		piece.ZIndex = 21
		piece.Parent = layer
		animate(piece, random:NextNumber(0.65, 1.15), {
			Position = UDim2.fromScale(random:NextNumber(-0.15, 1.15), random:NextNumber(0.1, 0.65)),
			Rotation = random:NextNumber(-300, 300), BackgroundTransparency = 1,
		})
	end
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(0.88, 0.065)
	title.Position = UDim2.fromScale(0.06, 0.76)
	title.BackgroundTransparency = 1
	title.Text = "UPGRADED!"
	title.TextColor3 = Color3.fromRGB(177, 255, 203)
	title.TextStrokeTransparency = 0.3
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.ZIndex = 22
	title.Parent = layer
	animate(title, 1.1, { Position = UDim2.fromScale(0.06, 0.65), TextTransparency = 1, TextStrokeTransparency = 1 })
	return function()
		for _, tween in ipairs(tweens) do tween:Cancel() end
		for _, object in ipairs(objects) do object:Destroy() end
	end
end

return playUpgradeBurst
