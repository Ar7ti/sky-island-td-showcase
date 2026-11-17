-- Match corners (art/matchhud): top left the Cash panel with the player's tower count under it, top right the MENU
-- button that opens the match menu (MatchMenuWindow: resume, settings, leave to lobby).
-- The lobby's left menu (Towers / Shop / Crates / Settings) is lobby-only (2026-11-16, user request).
-- Both new pieces use the wave bar's blue metal housing (HudArt.WaveHousing), so they read as one HUD set.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local React = require(ReplicatedStorage.Packages.React)
local Common = ReplicatedStorage.Shared.Source.Features.App.Common
local ScaledGroup = require(Common.ScaledGroup)
local OutlinedText = require(Common.OutlinedText)
local Theme = require(Common.Theme)
local useUiScale = require(Common.useUiScale)
local usePressAnimation = require(Common.usePressAnimation)
local usePlayerAttribute = require(Common.usePlayerAttribute)
local Currencies = require(ReplicatedStorage.Shared.Features.Services.Economy.Currencies)
local HudArt = require(script.Parent.HudArt)
local UnitsArt = require(ReplicatedStorage.Shared.Source.Features.App.Units.UnitsArt)
local e = React.createElement

-- Same pixel sizes as the lobby HUD (1080p, scaled with the screen).
local EDGE = 20

local CASH = Vector2.new(288, 90)
local TOWERS = Vector2.new(288, 66)
local MENU = Vector2.new(84, 84)
local images = HudArt.Images
local GlyphTower = images.GlyphTower
local GOLD = Color3.fromRGB(255, 205, 70)
local FULL = Color3.fromRGB(255, 110, 110)

-- Match Cash (art/matchhud): money icon, divider, "CASH" and the amount.
local function CashPanel(props: { Amount: number })
	return e(React.Fragment, nil, {
		Housing = e(HudArt.Panel, { Art = HudArt.CashHousing, Height = CASH.Y, ZIndex = 1 }),
		Icon = e(HudArt.Image, { Image = images.Money, Rect = { 0.065, 0.2, 0.23, 0.6 }, ZIndex = 2 }),
		Divider = e(HudArt.Image, { Image = images.CashDivider, Rect = { 0.355, 0.2, 0.014, 0.6 }, ZIndex = 2 }),
		Label = e(OutlinedText, {
			Text = "CASH",
			Size = UDim2.fromScale(0.49, 0.22),
			Position = UDim2.fromScale(0.42, 0.18),
			XAlignment = Enum.TextXAlignment.Left,
			Color = Theme.TextMuted,
			StrokeThickness = 2,
			ZIndex = 3,
		}),
		Value = e(OutlinedText, {
			Text = "$" .. HudArt.thousands(props.Amount),
			Size = UDim2.fromScale(0.49, 0.39),
			Position = UDim2.fromScale(0.42, 0.42),
			XAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 3,
			ZIndex = 3,
		}),
	})
end

-- The player's own towers on the map and their limit (server attributes, TowerService): the tower glyph,
-- "TOWERS 3/10" and one pip per slot that lights up gold per tower placed (red when full).
local function TowerCount(props: { Placed: number, Limit: number })
	local full = props.Placed >= props.Limit
	local pips = {}
	local count = math.clamp(props.Limit, 1, 20)
	for index = 1, count do
		local lit = index <= props.Placed
		pips["Pip" .. index] = e("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1 / count, -3, 1, 0),
			BackgroundColor3 = if lit then (if full then FULL else GOLD) else Color3.fromRGB(24, 30, 46),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 3) }),
			Stroke = e("UIStroke", { Color = Color3.fromRGB(8, 10, 18), Thickness = 1.5 }),
			Shine = lit and e("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
			}),
		})
	end
	return e(React.Fragment, nil, {
		Housing = e(HudArt.Panel, { Art = HudArt.WaveHousing, Height = TOWERS.Y, ZIndex = 1 }),
		Icon = GlyphTower ~= "" and e(HudArt.Image, { Image = GlyphTower, Rect = { 0.06, 0.18, 0.11, 0.64 }, ZIndex = 2 }),
		Label = e(OutlinedText, {
			Text = "TOWERS",
			Size = UDim2.fromScale(0.42, 0.3),
			Position = UDim2.fromScale(0.19, 0.17),
			XAlignment = Enum.TextXAlignment.Left,
			Color = Theme.TextMuted,
			StrokeThickness = 2,
			ZIndex = 3,
		}),
		Value = e(OutlinedText, {
			Text = `{props.Placed}/{props.Limit}`,
			Size = UDim2.fromScale(0.3, 0.38),
			Position = UDim2.fromScale(0.64, 0.12),
			XAlignment = Enum.TextXAlignment.Right,
			Color = if full then FULL else nil,
			StrokeThickness = 3,
			ZIndex = 3,
		}),
		Pips = e("Frame", {
			Size = UDim2.fromScale(0.75, 0.17),
			Position = UDim2.fromScale(0.19, 0.6),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 3),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Pips = e(React.Fragment, nil, pips),
		}),
	})
end

-- Three white bars with a dark outline, the same look as the HUD's glyphs.
local function MenuGlyph()
	local bars = {}
	for index = 1, 3 do
		bars["Bar" .. index] = e("Frame", {
			Size = UDim2.fromScale(1, 0.2),
			Position = UDim2.fromScale(0, (index - 1) * 0.4),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Stroke = e("UIStroke", { Color = Color3.fromRGB(10, 12, 20), Thickness = 2.5 }),
		})
	end
	return e("Frame", {
		Size = UDim2.fromScale(0.44, 0.3),
		Position = UDim2.fromScale(0.5, 0.38),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, bars)
end

-- The MENU button (top right): opens the match menu.
local function MenuButton(props: { OnClick: (() -> ())? })
	local scaleRef, events = usePressAnimation(1.06, props.OnClick)
	local buttonProps = {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
	}
	for key, handler in events do
		buttonProps[key] = handler
	end
	return e("TextButton", buttonProps, {
		Body = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, {
			Scale = e("UIScale", { ref = scaleRef, Scale = 1 }),
			Housing = e(HudArt.Panel, { Art = HudArt.WaveHousing, Height = MENU.Y, ZIndex = 1 }),
			Glyph = if images.GlyphMenu and images.GlyphMenu ~= ""
				then e("ImageLabel", {
					Image = images.GlyphMenu,
					Size = UDim2.fromScale(0.5, 0.42),
					Position = UDim2.fromScale(0.5, 0.38),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = 3,
				})
				else e(MenuGlyph),
			Label = e(OutlinedText, {
				Text = "MENU",
				Size = UDim2.fromScale(0.62, 0.17),
				Position = UDim2.fromScale(0.5, 0.71),
				AnchorPoint = Vector2.new(0.5, 0.5),
				StrokeThickness = 2,
				ZIndex = 3,
			}),
		}),
	})
end

-- The match menu window (MatchMenuWindow) is drawn with the lobby's Units kit, which nothing in a match has
-- loaded yet: load it once when the HUD mounts, so the menu doesn't open with blank buttons.
local preloaded = false
local function preloadMenuArt()
	if preloaded then
		return
	end
	preloaded = true
	local decals = {}
	for _, art in { UnitsArt.Window, UnitsArt.Header, UnitsArt.Equip, UnitsArt.Sort, UnitsArt.Red } do
		local decal = Instance.new("Decal")
		decal.Texture = art.image
		table.insert(decals, decal)
	end
	for _, art in { UnitsArt.CloseButton, UnitsArt.Icons.CloseX } do
		local decal = Instance.new("Decal")
		decal.Texture = art.image
		table.insert(decals, decal)
	end
	pcall(ContentProvider.PreloadAsync, ContentProvider, decals)
	for _, decal in decals do
		decal:Destroy()
	end
end

export type Props = {
	actions: { [string]: () -> () }?,
}

local function MatchMenu(props: Props)
	local scale = useUiScale()
	local cash = usePlayerAttribute(Currencies.CashAttribute) or 0
	local placed = usePlayerAttribute("TowersPlaced") or 0
	local limit = usePlayerAttribute("TowerLimit")
	React.useEffect(function()
		task.spawn(preloadMenuArt)
	end, {})

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Cash = e(ScaledGroup, {
			Scale = scale,
			Size = CASH,
			Position = UDim2.fromOffset(EDGE, EDGE),
			AnchorPoint = Vector2.new(0, 0),
		}, {
			Panel = e(CashPanel, { Amount = cash }),
		}),
		Towers = type(limit) == "number" and e(ScaledGroup, {
			Scale = scale,
			Size = TOWERS,
			Position = UDim2.fromOffset(EDGE, EDGE + math.round((CASH.Y + 6) * scale)),
			AnchorPoint = Vector2.new(0, 0),
		}, {
			Count = e(TowerCount, { Placed = placed, Limit = limit }),
		}),
		Menu = e(ScaledGroup, {
			Scale = scale,
			Size = MENU,
			Position = UDim2.new(1, -EDGE, 0, EDGE),
			AnchorPoint = Vector2.new(1, 0),
		}, {
			Button = e(MenuButton, { OnClick = props.actions and props.actions.Menu }),
		}),
	})
end

return MatchMenu
