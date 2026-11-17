local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local React = require(ReplicatedStorage.Packages.React)
local towersConfig = require(ReplicatedStorage.Shared.Features.Services.TowersServices.towersConfig)
local rarities = require(ReplicatedStorage.Shared.Features.Services.TowersServices.towersRaritys)

local e = React.createElement

local LEVEL_UP_TWEEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local MAX_COLOR = Color3.fromRGB(255, 204, 93)

local function TowerLabel(props)
	local tower = props.Tower
	local _, setRevision = React.useState(0)
	React.useEffect(function()
		local connections = {}
		local function refresh()
			setRevision(function(value)
				return value + 1
			end)
		end
		local function watch(instance)
			if instance.Name == "towerLevel" and instance:IsA("IntValue") then
				table.insert(connections, instance.Changed:Connect(refresh))
			end
		end
		for _, instance in ipairs(tower:GetDescendants()) do
			watch(instance)
		end
		table.insert(connections, tower.DescendantAdded:Connect(function(instance)
			watch(instance)
			refresh()
		end))
		table.insert(connections, tower.DescendantRemoving:Connect(refresh))
		table.insert(connections, tower:GetAttributeChangedSignal("OwnerId"):Connect(refresh))
		table.insert(connections, tower:GetPropertyChangedSignal("Name"):Connect(refresh))
		refresh()
		return function()
			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end
		end
	end, { tower })

	local config = towersConfig[tower.Name]
	local folder = tower:FindFirstChild("Instances")
	local level = folder and folder:FindFirstChild("towerLevel")
	local currentLevel = level and level.Value or (config and config.Level) or 1

	-- The level badge pops when the tower levels up.
	local badgeScaleRef = React.useRef(nil)
	local previousLevel = React.useRef(currentLevel)
	React.useEffect(function()
		local scale = badgeScaleRef.current
		local leveledUp = currentLevel > previousLevel.current
		previousLevel.current = currentLevel
		if not scale or not leveledUp then
			return
		end
		scale.Scale = 1.35
		local tween = TweenService:Create(scale, LEVEL_UP_TWEEN_INFO, { Scale = 1 })
		tween:Play()
		return function() tween:Cancel() end
	end, { currentLevel })

	local adornee = tower:FindFirstChild("Head") or tower:FindFirstChild("HumanoidRootPart")
	if not config or not adornee or not adornee:IsA("BasePart") or tower:GetAttribute("OwnerId") == nil then
		return nil
	end
	local rarity = rarities[config.Rarity]
	local accent = rarity and rarity.UIShadowColor or Color3.fromRGB(130, 200, 255)
	local maxLevel = config.Level or 1
	for upgradeLevel in pairs(config.Upgrades or {}) do maxLevel = math.max(maxLevel, upgradeLevel) end
	local progress = math.clamp((currentLevel - 1) / math.max(1, maxLevel - 1), 0, 1)
	local isMax = maxLevel > 1 and currentLevel >= maxLevel
	local tierColor = if isMax then MAX_COLOR else Color3.fromRGB(104, 197, 255):Lerp(MAX_COLOR, progress)
	local rarityColor = accent:Lerp(Color3.new(1, 1, 1), 0.5)
	return e("BillboardGui", {
		Adornee = adornee, Size = UDim2.fromScale(4.4, 1),
		SizeOffset = Vector2.new(0, 0.5),
		StudsOffsetWorldSpace = Vector3.new(0, adornee.Size.Y / 2 + (if adornee.Name == "Head" then 0.35 else 2), 0),
		AlwaysOnTop = true, MaxDistance = 80, LightInfluence = 0,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		Card = e("Frame", {
			Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(15, 24, 42), BackgroundTransparency = 0.08, BorderSizePixel = 0,
			ClipsDescendants = true,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.2, 0) }),
			Stroke = e("UIStroke", {
				Color = tierColor, Transparency = 0.3, Thickness = 1.5,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Gradient = e("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(53, 64, 89), Color3.fromRGB(15, 24, 42)), Rotation = 70 }),

			-- Level gets its own inset box so it reads apart from the name.
			Badge = e("Frame", {
				Position = UDim2.fromScale(8 / 220, 0.12), Size = UDim2.fromScale(52 / 220, 0.7),
				BackgroundColor3 = Color3.fromRGB(8, 14, 28), BackgroundTransparency = 0.25, BorderSizePixel = 0,
			}, {
				Scale = e("UIScale", { ref = badgeScaleRef }),
				Corner = e("UICorner", { CornerRadius = UDim.new(0.22, 0) }),
				Stroke = e("UIStroke", {
					Color = tierColor, Transparency = 0.55, Thickness = 1,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				Caption = e("TextLabel", {
					Position = UDim2.fromScale(0, 0.1), Size = UDim2.fromScale(1, 0.22),
					BackgroundTransparency = 1, Text = "LEVEL", Font = Enum.Font.GothamBlack,
					TextScaled = true, TextColor3 = Color3.fromRGB(182, 198, 220),
				}),
				Number = e("TextLabel", {
					Position = UDim2.fromScale(0.5, 0.64), Size = if isMax then UDim2.fromScale(0.86, 0.42) else UDim2.fromScale(0.86, 0.6),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1, Text = if isMax then "MAX" else tostring(currentLevel),
					Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = tierColor,
				}, {
					Stroke = e("UIStroke", { Color = Color3.fromRGB(5, 10, 20), Thickness = 1, Transparency = 0.2 }),
				}),
			}),
			Name = e("TextLabel", {
				Position = UDim2.fromScale(70 / 220, 0.12), Size = UDim2.fromScale(140 / 220, 0.4),
				BackgroundTransparency = 1, Text = config.DisplayName, TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
			}, {
				Stroke = e("UIStroke", { Color = Color3.fromRGB(5, 10, 20), Thickness = 1, Transparency = 0.3 }),
			}),
			Rarity = e("Frame", {
				Position = UDim2.fromScale(70 / 220, 0.56), Size = UDim2.fromScale(140 / 220, 0.24),
				BackgroundTransparency = 1,
			}, {
				-- Small rarity-coloured dot before the rarity name.
				Dot = e("Frame", {
					Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromScale(0.6, 0.6),
					AnchorPoint = Vector2.new(0, 0.5), SizeConstraint = Enum.SizeConstraint.RelativeYY,
					BackgroundColor3 = rarityColor, BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
				}),
				Text = e("TextLabel", {
					Position = UDim2.fromScale(0.09, 0), Size = UDim2.fromScale(0.91, 1),
					BackgroundTransparency = 1, Text = string.upper(config.Rarity),
					TextColor3 = rarityColor,
					TextScaled = true, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
				}),
			}),

			-- Thin strip along the bottom: how far the tower is from max level.
			Progress = e("Frame", {
				Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.07),
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = Color3.fromRGB(5, 10, 20), BackgroundTransparency = 0.3, BorderSizePixel = 0,
			}, {
				Fill = e("Frame", {
					Size = UDim2.fromScale(if isMax then 1 else math.max(progress, 0.04), 1),
					BackgroundColor3 = tierColor, BorderSizePixel = 0,
				}),
			}),
		}),
	})
end

local function TowerBillboards(props)
	local folder = props.Towers
	local towers, setTowers = React.useState(folder:GetChildren())
	local ids = React.useRef(setmetatable({}, { __mode = "k" }))
	local nextId = React.useRef(0)
	React.useEffect(function()
		local function refresh()
			setTowers(folder:GetChildren())
		end
		local added = folder.ChildAdded:Connect(refresh)
		local removed = folder.ChildRemoved:Connect(refresh)
		refresh()
		return function()
			added:Disconnect()
			removed:Disconnect()
		end
	end, { folder })
	local children = {}
	for _, tower in ipairs(towers) do
		if tower:IsA("Model") then
			if not ids.current[tower] then
				nextId.current += 1
				ids.current[tower] = "Tower_" .. tostring(nextId.current)
			end
			children[ids.current[tower]] = e(TowerLabel, { Tower = tower })
		end
	end
	return e(React.Fragment, nil, children)
end

return TowerBillboards
