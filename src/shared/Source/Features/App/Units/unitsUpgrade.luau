-- The selected tower's panel in a match (click a placed tower): drawn with the Units window kit (UnitsArt) so it
-- matches the lobby's Units / Summon windows. Top to bottom: the tower's card in its rarity's frame with the name,
-- rarity badge and level pips; its mechanic line; Damage / Range / Cooldown rows "now -> after upgrade"; the
-- UPGRADE button with its price (red when the player's Cash is short) and the SELL button with the refund.
-- Everything shown comes from the live tower (server-set values and attributes) and towersConfig.
-- Landscape: top right under the MENU button; on short screens (phones, small windows) where it would run off the
-- bottom or over the tower hotbar it moves beside MENU and, only if it still must, gets smaller (fitLandscape).
-- Touch portrait: centered at the bottom.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local React = require(ReplicatedStorage.Packages.React)
local towersConfig = require(ReplicatedStorage.Shared.Features.Services.TowersServices.towersConfig)
local towerSellPrice = require(ReplicatedStorage.Shared.Features.Services.TowersServices.towerSellPrice)
local towerMechanics = require(ReplicatedStorage.Shared.Features.Services.TowersServices.towerMechanics)
local Currencies = require(ReplicatedStorage.Shared.Features.Services.Economy.Currencies)
local App = ReplicatedStorage.Shared.Source.Features.App
local usePressAnimation = require(App.Common.usePressAnimation)
local usePlayerAttribute = require(App.Common.usePlayerAttribute)
local useUiScale = require(App.Common.useUiScale)
local ImageButton = require(App.Common.ImageButton)
local RewardsText = require(App.Rewards.RewardsText)
local UnitsArt = require(script.Parent.UnitsArt)
local playUpgradeBurst = require(script.Parent.UpgradeBurst)
local HotbarLayout = require(script.Parent.HotbarLayout)
local useLoadout = require(script.Parent.useLoadout)

local e = React.createElement
local Text = RewardsText.Component
local IsTouch = require(App.Common.useIsTouch)
local UiScale = require(App.Common.UiScale)
local touchDevice = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

-- Pixel layout at 1080p (scaled with the screen like the rest of the HUD).
local PANEL = Vector2.new(440, 660)
local EDGE = 20
local MENU = 84 -- the MENU button (MatchMenu): EDGE screen pixels from the top right corner, MENU x scale big
local TOP_ROOM = 34 -- under MENU: room for the panel's header tab
local TAB = 22 -- the header tab sticks out this far above the panel
local CLEAR = 8 -- screen pixels kept free around MENU and the hotbar
-- The top center of the HUD: the base health / wave bar (UpBar_healthBar: 640 wide, 86 + 4 + 54 tall, 8 px from the
-- top of the screen, so it starts in Roblox's top bar row) and the READY button under it (ReadyButton: 250 x 64).
local BAR_WIDTH, BAR_HEIGHT, BAR_TOP = 640, 144, 8
local READY_WIDTH, READY_HEIGHT = 250, 64
local INSET = 24
local INNER = PANEL.X - INSET * 2
local CARD = Vector2.new(132, 170)
local STAT_HEIGHT = 50
local STAT_GAP = 8
local BUTTON_HEIGHT = 74
local SELL_HEIGHT = 58
local GOOD = Color3.fromRGB(123, 235, 168)
local MUTED = RewardsText.MutedColor
local SHORT = Color3.fromRGB(255, 120, 120)
local GOLD = Color3.fromRGB(255, 225, 110)

-- 1.5 -> "1.5", 2 -> "2", 0.35 -> "0.35"
local function number(value: number): string
	local text = string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
	return text
end

-- One stat row on the kit's row base: icon, name, the value now and (green) after the upgrade.
local function StatRow(props: {
	Icon: any,
	Name: string,
	Now: number?,
	After: number?,
	Suffix: string?,
	Y: number,
})
	local now, after = props.Now, props.After
	local suffix = props.Suffix or ""
	local difference = if now and after then after - now else nil
	local valueText = if now == nil then "–"
		elseif after == nil or difference == 0 then number(now) .. suffix
		else `{number(now)}{suffix} <font color="#9DF5BD">→ {number(after)}{suffix}</font>`
	return e(UnitsArt.Panel, {
		Art = UnitsArt.StatRow,
		Size = UDim2.fromOffset(INNER, STAT_HEIGHT),
		Position = UDim2.fromOffset(INSET, props.Y),
		SliceScale = 0.7,
	}, {
		Icon = e(UnitsArt.Icon, {
			Art = props.Icon,
			Size = UDim2.fromOffset(30, 30),
			Position = UDim2.new(0, 16, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
		}),
		Name = e(Text, {
			Text = props.Name,
			Size = UDim2.fromOffset(120, 22),
			Position = UDim2.new(0, 58, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			XAlignment = Enum.TextXAlignment.Left,
			Color = MUTED,
			StrokeThickness = 2,
		}),
		Value = e(Text, {
			Text = valueText,
			RichText = true,
			Size = UDim2.new(1, -190, 0, 26),
			Position = UDim2.new(1, -16, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			XAlignment = Enum.TextXAlignment.Right,
			StrokeThickness = 2.5,
		}),
	})
end

-- A wide kit button: green (Equip) for UPGRADE, red (Red) for SELL; grey when disabled.
local function ActionButton(props: {
	Base: UnitsArt.Sliced,
	Title: string,
	Price: string?,
	PriceColor: Color3?,
	Height: number,
	Y: number,
	Disabled: boolean?,
	OnClick: (() -> ())?,
})
	local scaleRef, events = usePressAnimation(if props.Disabled then 1 else 1.03, if props.Disabled then nil else props.OnClick)
	local buttonProps = {
		Size = UDim2.fromOffset(INNER, props.Height),
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
			Art = props.Base,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			SliceScale = if props.Base == UnitsArt.Red then 0.45 else 0.75,
			Color = if props.Disabled then Color3.fromRGB(95, 95, 95) else nil,
		}, {
			Scale = e("UIScale", { ref = scaleRef, Scale = 1 }),
			Title = e(Text, {
				Text = props.Title,
				Size = UDim2.new(if props.Price then 0.5 else 0.9, 0, 0, props.Height * 0.46),
				Position = UDim2.new(0, if props.Price then 26 else INNER / 2, 0.47, 0),
				AnchorPoint = Vector2.new(if props.Price then 0 else 0.5, 0.5),
				XAlignment = if props.Price then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
				Color = if props.Disabled then Color3.fromRGB(205, 205, 205) else nil,
				StrokeThickness = 3.5,
			}),
			Price = props.Price and e(UnitsArt.Panel, {
				Art = UnitsArt.Price,
				Size = UDim2.new(0.42, 0, 0, props.Height * 0.62),
				Position = UDim2.new(1, -14, 0.47, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				SliceScale = 0.5,
			}, {
				Coin = e(UnitsArt.Icon, {
					Art = UnitsArt.Icons.Coin,
					Size = UDim2.fromOffset(props.Height * 0.36, props.Height * 0.36),
					Position = UDim2.new(0, 12, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
				}),
				Amount = e(Text, {
					Text = props.Price,
					Size = UDim2.new(1, -props.Height * 0.36 - 30, 0.62, 0),
					Position = UDim2.new(1, -12, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					XAlignment = Enum.TextXAlignment.Right,
					Color = props.PriceColor,
					StrokeThickness = 2.5,
				}),
			}),
		}),
	})
end

-- The tower's card: its rarity's background and frame from the Units kit with the tower's picture.
local function TowerCard(props: { Config: any, Level: number })
	local background, frame = UnitsArt.CardImages(props.Config.Rarity)
	return e("Frame", {
		Size = UDim2.fromOffset(CARD.X, CARD.Y),
		Position = UDim2.fromOffset(INSET, 60),
		BackgroundTransparency = 1,
	}, {
		Background = e(UnitsArt.FlexCardLayer, { Image = background, Sliced = false, SliceScale = 0.3, ZIndex = 1 }),
		Icon = e("ImageLabel", {
			Size = UDim2.fromScale(0.86, 0.72),
			Position = UDim2.fromScale(0.5, 0.44),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = props.Config.Icon or "",
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 2,
		}),
		Frame = e(UnitsArt.FlexCardLayer, { Image = frame, Sliced = true, SliceScale = 0.3, ZIndex = 3 }),
		Level = e(UnitsArt.Icon, {
			Art = UnitsArt.LevelCircle,
			Size = UDim2.fromOffset(52, 52),
			Position = UDim2.new(1, 8, 1, 6),
			AnchorPoint = Vector2.new(1, 1),
			ZIndex = 4,
		}, {
			Value = e(Text, {
				Text = tostring(props.Level),
				Size = UDim2.fromScale(0.6, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				StrokeThickness = 2.5,
			}),
		}),
	})
end

-- One pip per upgrade level, lit up to the current level in the rarity's color.
local function LevelPips(props: { Level: number, MaxLevel: number, Color: Color3, Width: number })
	local pips = {}
	local count = math.clamp(props.MaxLevel, 1, 12)
	for index = 1, count do
		local lit = index <= props.Level
		pips["Pip" .. index] = e("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1 / count, -4, 1, 0),
			BackgroundColor3 = if lit then props.Color else Color3.fromRGB(24, 30, 46),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			Stroke = e("UIStroke", { Color = Color3.fromRGB(8, 10, 18), Thickness = 1.5 }),
			Shine = lit and e("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 175, 175)),
			}),
		})
	end
	return e("Frame", {
		Size = UDim2.fromOffset(props.Width, 14),
		BackgroundTransparency = 1,
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Pips = e(React.Fragment, nil, pips),
	})
end

-- Where the panel goes in landscape and how big: the largest scale (at most the HUD's) at which it stays on the
-- screen and off the hotbar, trying under MENU first (the desktop spot) and beside MENU second. Returns the scale
-- and the panel's top right corner in screen pixels.
local function fitLandscape(screen: Vector2, scale: number, slots: number, inset: number): (number, number, number)
	local _, hotbarTop, hotbarRight = HotbarLayout.rect(slots, screen, scale)
	local barBottom = BAR_TOP - inset + BAR_HEIGHT * scale
	local readyBottom = barBottom + READY_HEIGHT * scale
	-- How low the panel's top (with its tab) must start when its left edge is at `left`.
	local function clearOfTop(left: number, panelScale: number): number
		if left < screen.X / 2 + READY_WIDTH * scale / 2 + CLEAR then
			return readyBottom + CLEAR + TAB * panelScale
		elseif left < screen.X / 2 + BAR_WIDTH * scale / 2 + CLEAR then
			return barBottom + CLEAR + TAB * panelScale
		end
		return 0
	end
	-- The largest scale (from the HUD's down, 0.005 steps) at which the panel touches nothing; its top too.
	local function fit(right: number, top: (number) -> number): (number, number)
		local panelScale = scale
		while true do
			local left = right - PANEL.X * panelScale
			local at = math.max(top(panelScale), clearOfTop(left, panelScale))
			local bottom = if left < hotbarRight + CLEAR then hotbarTop - CLEAR else screen.Y - EDGE * scale
			if at + PANEL.Y * panelScale <= bottom or panelScale <= 0.2 then
				return panelScale, at
			end
			panelScale -= 0.005
		end
	end
	local underRight = screen.X - EDGE * scale
	local underTop = function(_: number)
		return EDGE + (MENU + TOP_ROOM) * scale
	end
	local besideRight = screen.X - EDGE - MENU * scale - CLEAR
	local besideTop = function(panelScale: number)
		return EDGE + TAB * panelScale
	end
	local under, underAt = fit(underRight, underTop)
	local beside, besideAt = fit(besideRight, besideTop)
	if under >= beside - 0.01 then
		return under, underRight, underAt
	end
	return beside, besideRight, besideAt
end

local function Upgrade(props)
	local tower = props.Tower
	local scale = useUiScale()
	local cash = usePlayerAttribute(Currencies.CashAttribute) or 0
	local viewport, setViewport = React.useState(function()
		return UiScale.viewport()
	end)
	React.useEffect(function()
		local camera = workspace.CurrentCamera
		local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			setViewport(UiScale.viewport())
		end)
		return function() connection:Disconnect() end
	end, {})
	local previewTouch = IsTouch.preview()
	local portrait = (if previewTouch ~= nil then previewTouch else touchDevice) and viewport.X < viewport.Y
	local loadout = useLoadout()
	-- The match ScreenGui starts below Roblox's top bar.
	local inset = GuiService:GetGuiInset().Y
	local screen = viewport - Vector2.new(0, inset)
	local panelScale, panelRight, panelTop = scale, 0, 0
	if not portrait then
		panelScale, panelRight, panelTop = fitLandscape(screen, scale, loadout.unlocked, inset)
	end
	local _, setRevision = React.useState(0)
	local panelRef = props.PanelRef
	local slideRef = React.useRef(nil)

	-- Slides in from the right (from the bottom in portrait) with a small pop.
	React.useEffect(function()
		local slide = slideRef.current
		if not slide then
			return
		end
		slide.Position = if portrait then UDim2.fromOffset(0, 220) else UDim2.fromOffset(260, 0)
		local tween = TweenService:Create(slide, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(0, 0),
		})
		tween:Play()
		return function()
			tween:Cancel()
		end
	end, { tower, portrait } :: { any })

	React.useEffect(function()
		local connections = {}
		local cleanupBurst = nil
		local function refresh()
			setRevision(function(revision)
				return revision + 1
			end)
		end
		local function watch(instance)
			if instance:IsA("ValueBase") then
				local previous = instance.Value
				table.insert(connections, instance.Changed:Connect(function()
					if instance.Name == "towerLevel" and instance:IsA("IntValue") then
						if instance.Value > previous and panelRef.current then
							if cleanupBurst then cleanupBurst() end
							cleanupBurst = playUpgradeBurst(panelRef.current, tower)
						end
						previous = instance.Value
					end
					refresh()
				end))
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
		table.insert(connections, tower.AttributeChanged:Connect(refresh))
		table.insert(connections, tower:GetPropertyChangedSignal("Name"):Connect(refresh))
		return function()
			if cleanupBurst then cleanupBurst() end
			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end
		end
	end, { tower })

	local config = towersConfig[tower.Name]
	if not config then
		return nil
	end
	local instances = tower:FindFirstChild("Instances")
	local function readValue(name, fallback)
		local value = instances and instances:FindFirstChild(name)
		return if value and (value:IsA("NumberValue") or value:IsA("IntValue")) then value.Value else fallback
	end
	local level = readValue("towerLevel", tower:GetAttribute("Level") or config.Level or 1)
	local levelStats = (config.Upgrades and config.Upgrades[level]) or config
	local current = {
		Damage = readValue("towerDamage", levelStats.Damage),
		AttackDistance = readValue("towerAttackDistance", levelStats.AttackDistance),
		Reload = readValue("towerReload", levelStats.Reload),
	}
	local nextStats = config.Upgrades and config.Upgrades[level + 1]
	-- Slow / chain / buff / income... of the live tower (attributes set by the server), one line.
	local mechanic = towerMechanics.Describe(tower:GetAttributes(), config)
	local accent = UnitsArt.RarityColors[config.Rarity] or UnitsArt.RarityColors.Common
	local maxLevel = config.Level or 1
	for upgradeLevel in pairs(config.Upgrades or {}) do
		maxLevel = math.max(maxLevel, upgradeLevel)
	end
	local cost = nextStats and nextStats.UpgradeCost
	local short = cost ~= nil and cash < cost
	local sellPrice = towerSellPrice(config, level) or 0
	local noAttack = config.NoAttack == true

	-- Bottom up: SELL, UPGRADE, three stat rows, then the mechanic line fills what is left under the card.
	local sellY = PANEL.Y - INSET - SELL_HEIGHT
	local upgradeY = sellY - 10 - BUTTON_HEIGHT
	local function statY(row: number)
		return upgradeY - 14 - (4 - row) * (STAT_HEIGHT + STAT_GAP) + STAT_GAP
	end
	local infoX = INSET + CARD.X + 18
	local infoWidth = PANEL.X - infoX - INSET

	return e("Frame", {
		ref = panelRef,
		Active = true,
		Size = UDim2.fromOffset(PANEL.X, PANEL.Y),
		Position = if portrait then UDim2.new(0.5, 0, 1, -EDGE) else UDim2.new(1, panelRight - screen.X, 0, panelTop),
		AnchorPoint = if portrait then Vector2.new(0.5, 1) else Vector2.new(1, 0),
		BackgroundTransparency = 1,
	}, {
		Scale = e("UIScale", { Scale = panelScale }),
		Slide = e("Frame", {
			ref = slideRef,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			Panel = e(UnitsArt.Panel, {
				Art = UnitsArt.Window,
				Size = UDim2.fromScale(1, 1),
				SliceScale = 1.2,
			}),
			Header = e(UnitsArt.Panel, {
				Art = UnitsArt.Header,
				Size = UDim2.fromOffset(260, 66),
				Position = UDim2.new(0.5, 0, 0, -22),
				AnchorPoint = Vector2.new(0.5, 0),
				SliceScale = 0.7,
				ZIndex = 2,
			}, {
				Title = e(Text, {
					Text = "UPGRADE",
					Size = UDim2.new(1, -90, 0, 36),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					StrokeThickness = 3.5,
				}),
			}),
			Close = e(ImageButton, {
				Art = UnitsArt.CloseButton,
				Size = UDim2.fromOffset(56, 56),
				Position = UDim2.new(1, -10, 0, 10),
				AnchorPoint = Vector2.new(1, 0),
				OnClick = props.OnClose,
			}, {
				X = e(UnitsArt.Icon, {
					Art = UnitsArt.Icons.CloseX,
					Size = UDim2.fromScale(0.52, 0.52),
					Position = UDim2.fromScale(0.5, 0.48),
					AnchorPoint = Vector2.new(0.5, 0.5),
				}),
			}),
			Card = e(TowerCard, { Config = config, Level = level }),
			Name = e(Text, {
				Text = config.DisplayName or tower.Name,
				Size = UDim2.fromOffset(infoWidth, 40),
				Position = UDim2.fromOffset(infoX, 66),
				XAlignment = Enum.TextXAlignment.Left,
				StrokeThickness = 3.5,
			}),
			Rarity = e(UnitsArt.Panel, {
				Art = UnitsArt.Rarity,
				Size = UDim2.fromOffset(math.min(infoWidth, 170), 36),
				Position = UDim2.fromOffset(infoX, 112),
				SliceScale = 0.36,
			}, {
				Label = e(Text, {
					Text = string.upper(config.Rarity),
					Size = UDim2.new(1, -30, 0, 22),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Color = accent,
					StrokeThickness = 2,
				}),
			}),
			LevelLabel = e(Text, {
				Text = if nextStats then `LEVEL {level} / {maxLevel}` else `LEVEL {level} · MAX`,
				Size = UDim2.fromOffset(infoWidth, 24),
				Position = UDim2.fromOffset(infoX, 162),
				XAlignment = Enum.TextXAlignment.Left,
				Color = if nextStats then MUTED else GOLD,
				StrokeThickness = 2,
			}),
			LevelPips = e("Frame", {
				Size = UDim2.fromOffset(infoWidth, 14),
				Position = UDim2.fromOffset(infoX, 194),
				BackgroundTransparency = 1,
			}, {
				Pips = e(LevelPips, { Level = level, MaxLevel = maxLevel, Color = accent, Width = infoWidth }),
			}),
			Description = e(Text, {
				Text = config.Description or "",
				Size = UDim2.fromOffset(INNER, statY(1) - 250 - (if mechanic then 30 else 0)),
				Position = UDim2.fromOffset(INSET, 244),
				XAlignment = Enum.TextXAlignment.Left,
				Color = MUTED,
				StrokeThickness = 2,
				MaxTextSize = 19,
				Wrapped = true,
			}),
			Mechanic = mechanic and e(Text, {
				Text = mechanic,
				Size = UDim2.fromOffset(INNER, 24),
				Position = UDim2.fromOffset(INSET, statY(1) - 32),
				XAlignment = Enum.TextXAlignment.Left,
				Color = GOOD,
				StrokeThickness = 2,
				MaxTextSize = 20,
			}),
			Damage = e(StatRow, {
				Icon = UnitsArt.Icons.Damage,
				Name = "Damage",
				Now = if noAttack then nil else current.Damage,
				After = nextStats and nextStats.Damage,
				Y = statY(1),
			}),
			Range = e(StatRow, {
				Icon = UnitsArt.Icons.Range,
				Name = "Range",
				Now = current.AttackDistance,
				After = nextStats and nextStats.AttackDistance,
				Y = statY(2),
			}),
			Cooldown = e(StatRow, {
				Icon = UnitsArt.Icons.Cooldown,
				Name = "Cooldown",
				Now = if noAttack then nil else current.Reload,
				After = nextStats and nextStats.Reload,
				Suffix = "s",
				Y = statY(3),
			}),
			Upgrade = e(ActionButton, {
				Base = UnitsArt.Equip,
				Title = if nextStats then "UPGRADE" else "MAX LEVEL",
				Price = cost and ("$" .. tostring(cost)),
				PriceColor = if short then SHORT else nil,
				Height = BUTTON_HEIGHT,
				Y = upgradeY,
				Disabled = nextStats == nil,
				OnClick = props.OnUpgrade,
			}),
			Sell = e(ActionButton, {
				Base = UnitsArt.Red,
				Title = "SELL",
				Price = "+$" .. tostring(sellPrice),
				Height = SELL_HEIGHT,
				Y = sellY,
				OnClick = props.OnSell,
			}),
		}),
	})
end

return Upgrade
