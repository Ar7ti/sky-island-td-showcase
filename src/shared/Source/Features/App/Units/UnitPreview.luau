-- Details panel on the right of the Units window: the selected unit, its stars (TowersServices/TowerStars:
-- paid with spare copies of the tower, Star Stones cover missing copies) with the Star Up button, the
-- Salvage button (spare copies -> shards), its stats and the Equip / Unequip button.
-- Pixel layout for a props.Frame-sized box inside the window.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local React = require(ReplicatedStorage.Packages.React)
local usePressAnimation = require(ReplicatedStorage.Shared.Source.Features.App.Common.usePressAnimation)
local RewardsText = require(ReplicatedStorage.Shared.Source.Features.App.Rewards.RewardsText)
local UnitsArt = require(script.Parent.UnitsArt)
local towerMechanics = require(ReplicatedStorage.Shared.Features.Services.TowersServices.towerMechanics)
local TowerStars = require(ReplicatedStorage.Shared.Features.Services.TowersServices.TowerStars)
local ItemsConfig = require(ReplicatedStorage.Shared.Features.Services.Items.ItemsConfig)
local e = React.createElement
local Text = RewardsText.Component

local INSET = 22
local STAT_HEIGHT = 36
local STAT_GAP = 6
local MECHANIC_HEIGHT = 40 -- up to two lines of mechanic text
local STARS_TOP = 118
local STARS_HEIGHT = 44
local STAR_SIZE = 34
local COPIES_HEIGHT = 28 -- the line under the stars: copies and Star Stones owned, the Salvage button
local ICON_TOP = STARS_TOP + STARS_HEIGHT + COPIES_HEIGHT + 8
local BUTTON_HEIGHT = 66
local STAR_BUTTON_WIDTH = 188
local SALVAGE_WIDTH = 196
local SHARD_COLOR = Color3.fromRGB(190, 150, 255)
local STONE_ICON = ItemsConfig[TowerStars.ITEM].Icon

export type Action = {
	Text: string,
	Kind: "Equip" | "Unequip",
	Disabled: boolean?,
	OnClick: () -> (),
}

export type Stars = {
	Level: number, -- TowerStars level saved for the unit (1..TowerStars.MAX)
	Stones: number, -- Star Stones in the bag
	Duplicates: number, -- spare copies of the unit (Amount - 1)
	ShardsPerCopy: number, -- shards for salvaging one spare copy
	Status: string?, -- last Star Up / Salvage error
	Notice: string?, -- last Salvage result ("+3 Shards")
	OnStarUp: () -> (),
	OnSalvage: (count: number) -> (),
}

export type Props = {
	UnitId: string?,
	Config: any?, -- TowersConfig entry of the selected unit
	Action: Action?,
	Stars: Stars?,
	Frame: Rect, -- px in the window
}

local function stat(icon, name: string, value: string, y: number, width: number)
	return e(UnitsArt.Panel, {
		Art = UnitsArt.StatRow,
		Size = UDim2.fromOffset(width, STAT_HEIGHT),
		Position = UDim2.fromOffset(INSET, y),
		SliceScale = 0.6,
	}, {
		Icon = e(UnitsArt.Icon, {
			Art = icon,
			Size = UDim2.fromOffset(24, 24),
			Position = UDim2.new(0, 14, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
		}),
		Name = e(Text, {
			Text = name,
			Size = UDim2.new(0.6, -50, 0, 20),
			Position = UDim2.new(0, 50, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			XAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 2,
		}),
		Value = e(Text, {
			Text = value,
			Size = UDim2.new(0.4, -16, 0, 22),
			Position = UDim2.new(1, -14, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			XAlignment = Enum.TextXAlignment.Right,
			StrokeThickness = 2,
		}),
	})
end

local function ActionButton(props: { Action: Action, Width: number, Y: number })
	local action = props.Action
	local scaleRef, events = usePressAnimation(if action.Disabled then 1 else 1.04, if action.Disabled then nil else action.OnClick)
	local buttonProps = {
		Size = UDim2.fromOffset(props.Width, BUTTON_HEIGHT),
		Position = UDim2.fromOffset(INSET, props.Y),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
	}
	for key, handler in events do
		buttonProps[key] = handler
	end
	return e("TextButton", buttonProps, {
		Body = e(UnitsArt.Panel, {
			Art = if action.Kind == "Unequip" then UnitsArt.Red else UnitsArt.Equip,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			SliceScale = if action.Kind == "Unequip" then 0.45 else 0.75,
			Color = if action.Disabled then Color3.fromRGB(85, 85, 85) else nil,
		}, {
			Scale = e("UIScale", { ref = scaleRef, Scale = 1 }),
			Label = e(Text, {
				Text = action.Text,
				Size = UDim2.new(1, -40, 0, 40),
				Position = UDim2.fromScale(0.5, 0.47),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Color = if action.Disabled then Color3.fromRGB(200, 200, 200) else nil,
				StrokeThickness = 3.5,
			}),
		}),
	})
end

local function plural(count: number, one: string, many: string): string
	return `{count} {if count == 1 then one else many}`
end

-- What the next star will take: "2 copies", "1 copy + 1 Star Stone", "2 Star Stones".
local function priceText(plan: TowerStars.Plan): string
	local parts = {}
	if plan.Duplicates > 0 then
		table.insert(parts, plural(plan.Duplicates, "copy", "copies"))
	end
	if plan.Stones > 0 then
		table.insert(parts, plural(plan.Stones, "Star Stone", "Star Stones"))
	end
	return table.concat(parts, " + ")
end

-- Row under the rarity pill: TowerStars.MAX stars (Star Stone art, lit up to the level) and the Star Up button
-- with what it will spend (spare copies first, Star Stones for the rest).
local function StarsRow(props: { Stars: Stars, Width: number })
	local stars = props.Stars
	local plan = TowerStars.Plan(stars.Level, stars.Duplicates, stars.Stones)
	local canBuy = plan ~= nil and plan.Enough
	local scaleRef, events = usePressAnimation(if canBuy then 1.05 else 1, if canBuy then stars.OnStarUp else nil)
	local icons = {}
	for index = 1, TowerStars.MAX do
		local lit = index <= stars.Level
		icons[`Star{index}`] = e("ImageLabel", {
			Size = UDim2.fromOffset(STAR_SIZE, STAR_SIZE),
			Position = UDim2.new(0, (index - 1) * (STAR_SIZE + 2), 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = STONE_ICON,
			ImageColor3 = if lit then Color3.new(1, 1, 1) else Color3.fromRGB(40, 46, 64),
			ImageTransparency = if lit then 0 else 0.25,
			ScaleType = Enum.ScaleType.Fit,
		})
	end
	local buttonProps = {
		Size = UDim2.fromOffset(STAR_BUTTON_WIDTH, STARS_HEIGHT),
		Position = UDim2.fromScale(1, 0.5),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
	}
	for key, handler in events do
		buttonProps[key] = handler
	end
	local textColor = if canBuy then nil else Color3.fromRGB(200, 200, 200)
	return e("Frame", {
		Size = UDim2.fromOffset(props.Width, STARS_HEIGHT),
		Position = UDim2.fromOffset(INSET, STARS_TOP),
		BackgroundTransparency = 1,
	}, {
		Stars = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, icons),
		StarUp = e("TextButton", buttonProps, {
			Body = e(UnitsArt.Panel, {
				Art = UnitsArt.Equip,
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				SliceScale = 0.5,
				Color = if canBuy then nil else Color3.fromRGB(85, 85, 85),
			}, {
				Scale = e("UIScale", { ref = scaleRef, Scale = 1 }),
				Label = e(Text, {
					Text = if plan then "Star Up" else "Max stars",
					Size = UDim2.new(1, -20, 0, if plan then 20 else 24),
					Position = UDim2.new(0.5, 0, 0, if plan then 4 else 10),
					AnchorPoint = Vector2.new(0.5, 0),
					Color = textColor,
					StrokeThickness = 2.5,
				}),
				Price = plan and e(Text, {
					Text = priceText(plan),
					Size = UDim2.new(1, -20, 0, 15),
					Position = UDim2.new(0.5, 0, 0, 24),
					AnchorPoint = Vector2.new(0.5, 0),
					Color = if canBuy then Color3.fromRGB(255, 240, 150) else textColor,
					StrokeThickness = 2,
				}),
			}),
		}),
	})
end

-- Under the stars: what the player has for the next star, and Salvage (spare copies -> shards).
-- A fully starred tower salvages every spare copy at once; otherwise one per click, the rest may pay for stars.
local function CopiesRow(props: { Stars: Stars, Width: number })
	local stars = props.Stars
	local maxed = TowerStars.Cost(stars.Level) == nil
	local count = if maxed then stars.Duplicates else math.min(stars.Duplicates, 1)
	local canSalvage = count > 0
	local scaleRef, events = usePressAnimation(if canSalvage then 1.05 else 1, if canSalvage
		then function()
			stars.OnSalvage(count)
		end
		else nil)
	local buttonProps = {
		Size = UDim2.fromOffset(SALVAGE_WIDTH, COPIES_HEIGHT),
		Position = UDim2.fromScale(1, 0.5),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
	}
	for key, handler in events do
		buttonProps[key] = handler
	end
	local holdings = `{plural(stars.Duplicates, "copy", "copies")} · {plural(stars.Stones, "Star Stone", "Star Stones")}`
	return e("Frame", {
		Size = UDim2.fromOffset(props.Width, COPIES_HEIGHT),
		Position = UDim2.fromOffset(INSET, STARS_TOP + STARS_HEIGHT + 4),
		BackgroundTransparency = 1,
	}, {
		Status = e(Text, {
			Text = stars.Status or stars.Notice or holdings,
			Size = UDim2.new(1, if canSalvage then -(SALVAGE_WIDTH + 8) else 0, 0, 20),
			Position = UDim2.fromScale(0, 0.5),
			AnchorPoint = Vector2.new(0, 0.5),
			XAlignment = if canSalvage then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			Color = if stars.Status then Color3.fromRGB(255, 140, 140)
				elseif stars.Notice then SHARD_COLOR
				else RewardsText.MutedColor,
			StrokeThickness = 2,
			MaxTextSize = 18,
		}),
		Salvage = canSalvage and e("TextButton", buttonProps, {
			Scale = e("UIScale", { ref = scaleRef, Scale = 1 }),
			Body = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(58, 44, 96),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Stroke = e("UIStroke", { Color = SHARD_COLOR, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				Label = e(Text, {
					Text = `Salvage {if maxed and count > 1 then "all" else count} → +{count * stars.ShardsPerCopy} Shards`,
					Size = UDim2.new(1, -14, 0, 18),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					StrokeThickness = 2,
				}),
			}),
		}),
	})
end

local function UnitPreview(props: Props)
	local config = props.Config
	local mechanic = towerMechanics.DescribeConfig(config)
	local frame = props.Frame
	local inner = frame.Width - INSET * 2
	local accent = config and UnitsArt.RarityColors[config.Rarity] or UnitsArt.RarityColors.Common
	local buttonY = frame.Height - INSET - BUTTON_HEIGHT
	-- Laid out bottom-up so the picture only takes the space left above the text: button, three stat rows,
	-- the mechanic line, then the icon (it used to sit on top of the mechanic line).
	local function statY(row: number) -- row 1 = Damage (top) .. 3 = Cooldown
		return buttonY - (4 - row) * (STAT_HEIGHT + STAT_GAP) - 4
	end
	local mechanicY = statY(1) - MECHANIC_HEIGHT - 4
	local iconBottom = (if mechanic then mechanicY else statY(1)) - 6
	local iconHeight = math.max(iconBottom - ICON_TOP, 40)

	-- Small pop whenever another unit is selected.
	local scaleRef = React.useRef(nil)
	React.useEffect(function()
		local scale = scaleRef.current
		if not scale then
			return
		end
		scale.Scale = 0.96
		local tween = TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
		tween:Play()
		return function()
			tween:Cancel()
		end
	end, { props.UnitId })
	local stars = if config then props.Stars else nil
	local starLevel = if stars then stars.Level else 1
	local damageText = if not config or config.NoAttack then "–"
		elseif starLevel > 1 then `{TowerStars.Damage(config.Damage, starLevel)} (+{math.round((TowerStars.DamageMultiplier(starLevel) - 1) * 100)}%)`
		else tostring(config.Damage)

	return e(UnitsArt.Panel, {
		Art = UnitsArt.Details,
		Size = UDim2.fromOffset(frame.Width, frame.Height),
		Position = UDim2.fromOffset(frame.Min.X, frame.Min.Y),
		SliceScale = 1.2,
	}, {
		-- Blocks clicks so they don't reach the dimmer behind the window.
		Content = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
		}, {
			Scale = e("UIScale", { ref = scaleRef }),
			Title = e(Text, {
				Text = if config then config.DisplayName else "Select a unit",
				Size = UDim2.fromOffset(inner, 50),
				Position = UDim2.fromOffset(INSET, 16),
				StrokeThickness = 4,
			}),
			Rarity = e(UnitsArt.Panel, {
				Art = UnitsArt.Rarity,
				Size = UDim2.fromOffset(200, 40),
				Position = UDim2.fromOffset(frame.Width / 2, 72),
				AnchorPoint = Vector2.new(0.5, 0),
				SliceScale = 0.4,
			}, {
				Label = e(Text, {
					Text = if config then string.upper(config.Rarity) else "YOUR COLLECTION",
					Size = UDim2.new(1, -36, 0, 26),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Color = accent,
					StrokeThickness = 2,
				}),
			}),
			StarsRow = stars and e(StarsRow, { Stars = stars, Width = inner }),
			CopiesRow = stars and e(CopiesRow, { Stars = stars, Width = inner }),
			Icon = config and e("ImageLabel", {
				Size = UDim2.fromOffset(inner, iconHeight),
				Position = UDim2.fromOffset(INSET, ICON_TOP),
				BackgroundTransparency = 1,
				Image = config.Icon,
				ScaleType = Enum.ScaleType.Fit,
			}),
			Hint = not config and e(Text, {
				Text = "Choose a unit to see its stats and add it to your loadout.",
				Size = UDim2.fromOffset(inner - 20, 120),
				Position = UDim2.fromOffset(INSET + 10, 170),
				Color = RewardsText.MutedColor,
				StrokeThickness = 2,
			}),
			-- Slow / chain / buff / income... of the tower at level 1, one line above the stats.
			Mechanic = mechanic and e(Text, {
				Text = mechanic,
				Size = UDim2.fromOffset(inner, MECHANIC_HEIGHT),
				Position = UDim2.fromOffset(INSET, mechanicY),
				Color = Color3.fromRGB(157, 245, 189),
				StrokeThickness = 2,
				MaxTextSize = 20,
			}),
			Damage = config and stat(UnitsArt.Icons.Damage, "Damage", damageText, statY(1), inner),
			Range = config and stat(UnitsArt.Icons.Range, "Range", (if config.Global then "Global" else tostring(config.AttackDistance or "–")), statY(2), inner),
			Cooldown = config and stat(UnitsArt.Icons.Cooldown, "Cooldown", if config.NoAttack then "–" else `{config.Reload}s`, statY(3), inner),
			Action = config and props.Action and e(ActionButton, { Action = props.Action, Width = inner, Y = buttonY }),
		}),
	})
end

return UnitPreview
