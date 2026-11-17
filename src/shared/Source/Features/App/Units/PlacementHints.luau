-- Compact control bar shown while a tower is being placed.
-- PC: mini mouse/key icons (LMB place, R rotate, Q cancel; RMB stays free for the camera) (Cancel and Rotate are also clickable). Touch: tappable round icon buttons.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local React = require(ReplicatedStorage.Packages.React)
local UiScale = require(ReplicatedStorage.Shared.Source.Features.App.Common.UiScale)
local PlacementState = require(ReplicatedStorage.Shared.Features.Services.TowersServices.PlacementState)
local soundController = require(ReplicatedStorage.Shared.Features.Services.SoundController.soundController)
local e = React.createElement
local IsTouch = require(ReplicatedStorage.Shared.Source.Features.App.Common.useIsTouch)
local touchDevice = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local FONT = Enum.Font.FredokaOne
local GREEN = Color3.fromRGB(112, 235, 150)
local RED = Color3.fromRGB(255, 110, 110)
local BLUE = Color3.fromRGB(120, 196, 255)
local CHIP_BG = Color3.fromRGB(26, 34, 52)
local CHIP_BG_HOVER = Color3.fromRGB(38, 50, 76)
local BAR_BG = Color3.fromRGB(10, 14, 24)
local CHIP_HEIGHT = 34
-- The match hotbar (TowerHotbar) is 198 px tall at 1080p (cards + padding + level bar), scaled by UiScale,
-- 12 screen px above the bottom edge. The bar sits just above it, so it never covers the tower cards
-- on short screens (phones in landscape, small windows).
local HOTBAR_HEIGHT = 198
local HOTBAR_EDGE = 12
local GAP_ABOVE_HOTBAR = 8

local function barPosition(lift: number): UDim2
	return UDim2.new(0.5, 0, 1, -(HOTBAR_EDGE + HOTBAR_HEIGHT * UiScale.compute() + GAP_ABOVE_HOTBAR) + lift)
end

local POP = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local QUICK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function corner(radius: number?)
	return e("UICorner", { CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0) })
end

-- Tiny mouse drawing with the left or right button lit up.
local function MouseIcon(props: { Side: string, Color: Color3 })
	local isLeft = props.Side == "Left"
	return e("Frame", {
		Size = UDim2.fromOffset(15, 21),
		BackgroundColor3 = Color3.fromRGB(14, 20, 32),
		BorderSizePixel = 0,
	}, {
		Corner = corner(7),
		Stroke = e("UIStroke", { Color = Color3.fromRGB(235, 241, 255), Thickness = 1.5 }),
		Button = e("Frame", {
			Position = if isLeft then UDim2.fromOffset(1, 1) else UDim2.new(0.5, 0, 0, 1),
			Size = UDim2.new(0.5, -1, 0.42, 0),
			BackgroundColor3 = props.Color,
			BorderSizePixel = 0,
		}, {
			Corner = corner(5),
		}),
		Split = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(0, 1, 0.45, 0),
			BackgroundColor3 = Color3.fromRGB(235, 241, 255),
			BorderSizePixel = 0,
		}),
	})
end

-- Tiny 3D keycap.
local function KeyIcon(props: { Key: string, Color: Color3 })
	return e("Frame", {
		Size = UDim2.fromOffset(22, 23),
		BackgroundColor3 = props.Color:Lerp(Color3.new(0, 0, 0), 0.45),
		BorderSizePixel = 0,
	}, {
		Corner = corner(6),
		Cap = e("TextLabel", {
			Size = UDim2.fromOffset(22, 20),
			BackgroundColor3 = Color3.fromRGB(240, 245, 255),
			BorderSizePixel = 0,
			Text = props.Key,
			TextColor3 = Color3.fromRGB(20, 28, 44),
			Font = FONT,
			TextSize = 15,
		}, {
			Corner = corner(6),
		}),
	})
end

-- Round glyph badge used for touch buttons. The marks are drawn with frames, not characters: Roblox's fonts have
-- no "↻" or "✕" (they showed as empty boxes on phones, 2026-11-17 phone preview).
local GLYPH_INK = Color3.fromRGB(14, 20, 32)
local function bar(width: number, height: number, rotation: number, position: UDim2?)
	return e("Frame", {
		Size = UDim2.fromOffset(width, height),
		Position = position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = rotation,
		BackgroundColor3 = GLYPH_INK,
		BorderSizePixel = 0,
	}, { Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
end

local function GlyphIcon(props: { Glyph: "check" | "rotate" | "cancel", Color: Color3 })
	local marks
	if props.Glyph == "check" then
		marks = {
			Short = bar(7, 3, 45, UDim2.fromOffset(9, 13)),
			Long = bar(12, 3, -50, UDim2.fromOffset(14.5, 11)),
		}
	elseif props.Glyph == "cancel" then
		marks = { A = bar(14, 3, 45), B = bar(14, 3, -45) }
	else
		-- A ring with its top right quarter left open, and an arrowhead at the open end.
		marks = {
			Ring = e("Frame", {
				Size = UDim2.fromOffset(12, 12),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
				Stroke = e("UIStroke", { Color = GLYPH_INK, Thickness = 2.5 }, {
					Gap = e("UIGradient", {
						Rotation = -45,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0),
							NumberSequenceKeypoint.new(0.68, 0),
							NumberSequenceKeypoint.new(0.7, 1),
							NumberSequenceKeypoint.new(1, 1),
						}),
					}),
				}),
			}),
			Head = e("Frame", {
				Size = UDim2.fromOffset(5, 5),
				Position = UDim2.fromOffset(17, 8),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = 45,
				BackgroundColor3 = GLYPH_INK,
				BorderSizePixel = 0,
			}),
		}
	end
	marks.Corner = corner()
	return e("Frame", {
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = props.Color,
		BorderSizePixel = 0,
	}, marks)
end

local function Chip(props: {
	Order: number,
	Label: string,
	Color: Color3,
	Icon: any,
	Action: string?,
	Dimmed: boolean?,
})
	local scaleRef = React.useRef(nil :: UIScale?)
	local strokeRef = React.useRef(nil :: UIStroke?)
	local buttonRef = React.useRef(nil :: GuiObject?)
	local clickable = props.Action ~= nil

	-- Staggered pop-in when the bar appears.
	React.useEffect(function()
		local scale = scaleRef.current
		if not scale then return end
		scale.Scale = 0.3
		local tween = TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.04 * props.Order), { Scale = 1 })
		tween:Play()
		return function() tween:Cancel() end
	end, {})

	local function animate(scaleValue: number, hovered: boolean)
		if scaleRef.current then
			TweenService:Create(scaleRef.current, QUICK, { Scale = scaleValue }):Play()
		end
		if strokeRef.current then
			TweenService:Create(strokeRef.current, QUICK, { Transparency = if hovered then 0.1 else 0.55 }):Play()
		end
		if buttonRef.current then
			TweenService:Create(buttonRef.current, QUICK, { BackgroundColor3 = if hovered then CHIP_BG_HOVER else CHIP_BG }):Play()
		end
	end

	local color = props.Color
	return e(if clickable then "TextButton" else "Frame", {
		ref = buttonRef,
		LayoutOrder = props.Order,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, CHIP_HEIGHT),
		BackgroundColor3 = CHIP_BG,
		BorderSizePixel = 0,
		Text = if clickable then "" else nil,
		AutoButtonColor = if clickable then false else nil,
		[React.Event.MouseEnter] = if clickable then function()
			animate(1.07, true)
			soundController:PlaySFX("MouseEnter")
		end else nil,
		[React.Event.MouseLeave] = if clickable then function() animate(1, false) end else nil,
		[React.Event.MouseButton1Down] = if clickable then function() animate(0.92, true) end else nil,
		[React.Event.MouseButton1Up] = if clickable then function() animate(1.07, true) end else nil,
		[React.Event.Activated] = if clickable then function()
			soundController:PlaySFX("leftBarClick")
			PlacementState.Action(props.Action :: string)
		end else nil,
	}, {
		Scale = e("UIScale", { ref = scaleRef, Scale = 0.3 }),
		Corner = corner(),
		Stroke = e("UIStroke", {
			ref = strokeRef,
			Color = color,
			Thickness = 1.5,
			Transparency = 0.55,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 13),
		}),
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 7),
		}),
		IconHolder = e("Frame", {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
		}, {
			Center = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
			}, { Icon = props.Icon }),
		}),
		Label = e("TextLabel", {
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, CHIP_HEIGHT),
			BackgroundTransparency = 1,
			Text = props.Label,
			TextColor3 = if props.Dimmed then color else Color3.fromRGB(240, 245, 255),
			Font = FONT,
			TextSize = 17,
		}),
	})
end

return function()
	local canPlace, setCanPlace = React.useState(PlacementState.CanPlace())
	React.useEffect(function()
		setCanPlace(PlacementState.CanPlace())
		return PlacementState.SubscribeCanPlace(setCanPlace)
	end, {})

	-- Scale with the screen; touch gets bigger targets.
	local previewTouch = IsTouch.preview()
	local isTouch = if previewTouch ~= nil then previewTouch else touchDevice
	local viewportY = UiScale.viewport().Y
	local uiScale = math.clamp(viewportY / 820, 0.8, 1.3) * (if isTouch then 1.3 else 1)

	-- Bar slides up and fades in.
	local groupRef = React.useRef(nil :: CanvasGroup?)
	React.useEffect(function()
		local group = groupRef.current
		if not group then return end
		group.GroupTransparency = 1
		group.Position = barPosition(24)
		local fade = TweenService:Create(group, TweenInfo.new(0.2), { GroupTransparency = 0 })
		local slide = TweenService:Create(group, POP, { Position = barPosition(0) })
		fade:Play()
		slide:Play()
		return function()
			fade:Cancel()
			slide:Cancel()
		end
	end, {})

	local placeColor = if canPlace then GREEN else RED
	local placeLabel = if canPlace then "Place" else "Can't place here"

	return e("CanvasGroup", {
		ref = groupRef,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = barPosition(24),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = BAR_BG,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		GroupTransparency = 1,
	}, {
		Scale = e("UIScale", { Scale = uiScale }),
		Corner = corner(),
		Stroke = e("UIStroke", {
			Color = Color3.new(1, 1, 1),
			Transparency = 0.85,
			Thickness = 1.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		-- On PC Place stays a hint: clicking a button would move the preview under the cursor.
		Place = e(Chip, {
			Order = 1,
			Label = placeLabel,
			Color = placeColor,
			Dimmed = not canPlace,
			Action = if isTouch then "place" else nil,
			Icon = if isTouch then e(GlyphIcon, { Glyph = "check", Color = placeColor }) else e(MouseIcon, { Side = "Left", Color = placeColor }),
		}),
		Rotate = e(Chip, {
			Order = 2,
			Label = "Rotate",
			Color = BLUE,
			Action = "rotate",
			Icon = if isTouch then e(GlyphIcon, { Glyph = "rotate", Color = BLUE }) else e(KeyIcon, { Key = "R", Color = BLUE }),
		}),
		Cancel = e(Chip, {
			Order = 3,
			Label = "Cancel",
			Color = RED,
			Action = "cancel",
			Icon = if isTouch then e(GlyphIcon, { Glyph = "cancel", Color = RED }) else e(KeyIcon, { Key = "Q", Color = RED }),
		}),
	})
end
