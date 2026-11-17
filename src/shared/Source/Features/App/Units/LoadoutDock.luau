-- Loadout strip under the Units window: the towers the player takes into a match, one slot each,
-- above the dimmer so it stays usable while the window is open (Tab / Towers).
-- Clicking a slot puts the unit picked in the window there (a unit already in another slot swaps
-- places, see LoadoutService.SetSlot); the red X on a filled slot takes its tower out.
-- Authored in pixels; LoadoutDock.Size is the box it needs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Common = ReplicatedStorage.Shared.Source.Features.App.Common
local usePressAnimation = require(Common.usePressAnimation)
local IsTouch = require(Common.useIsTouch)
local RewardsText = require(ReplicatedStorage.Shared.Source.Features.App.Rewards.RewardsText)
local TowersConfig = require(ReplicatedStorage.Shared.Features.Services.TowersServices.towersConfig)
local Loadout = require(ReplicatedStorage.Shared.Features.Services.TowersServices.Loadout)
local UnitsArt = require(script.Parent.UnitsArt)
local SlotBadge = require(script.Parent.SlotBadge)
local e = React.createElement
local Text = RewardsText.Component

local CARD = Vector2.new(108, 112)
local CARD_SLICE = 0.26
local GAP = 14
local PADDING = 16
local HINT_HEIGHT = 44
local BADGE = 38
local REMOVE = 30
local HIGHLIGHT_COLOR = Color3.fromRGB(255, 214, 64)
local TARGET_COLOR = Color3.fromRGB(130, 245, 90)

local SLOTS_WIDTH = Loadout.SlotCount * CARD.X + (Loadout.SlotCount - 1) * GAP
local SIZE = Vector2.new(SLOTS_WIDTH + PADDING * 2, HINT_HEIGHT + CARD.Y + PADDING * 2)

export type Props = {
	Slots: Loadout.Slots,
	Unlocked: number,
	ShownUnit: string?, -- unit picked in the window: what a slot click equips
	PickSlot: number?, -- slot the window was opened to fill (outlined)
	Position: UDim2?,
	AnchorPoint: Vector2?,
	OnEquip: (slot: number, unitId: string) -> (),
	OnRemove: (slot: number) -> (),
}

local function Slot(props: {
	index: number,
	towerId: string?,
	locked: boolean,
	highlighted: boolean,
	target: boolean, -- clicking would equip the shown unit here
	canRemove: boolean,
	showRemove: boolean,
	OnClick: (() -> ())?,
	OnRemove: () -> (),
	OnHover: (hovered: boolean) -> (),
})
	local config = props.towerId and TowersConfig[props.towerId]
	local scaleRef, events = usePressAnimation(1.08, props.OnClick)

	local body
	if config then
		local background, frame = UnitsArt.CardImages(config.Rarity)
		body = {
			Background = e(UnitsArt.FlexCardLayer, { Image = background, Sliced = false, SliceScale = CARD_SLICE, ZIndex = 1 }),
			Unit = e("ImageLabel", {
				Size = UDim2.fromOffset(CARD.X - 20, CARD.Y - 26),
				Position = UDim2.fromOffset(10, 12),
				BackgroundTransparency = 1,
				Image = config.Icon,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 2,
			}),
			Frame = e(UnitsArt.FlexCardLayer, { Image = frame, Sliced = true, SliceScale = CARD_SLICE, ZIndex = 3 }),
		}
	else
		body = {
			Empty = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(22, 24, 32),
				BackgroundTransparency = if props.locked then 0.35 else 0,
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
				Stroke = e("UIStroke", {
					Color = Color3.fromRGB(70, 76, 95),
					Thickness = 2,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				Mark = e(Text, {
					Text = if props.locked then "🔒" else "+",
					Size = UDim2.fromScale(0.5, 0.45),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Color = RewardsText.MutedColor,
				}),
			}),
		}
	end
	body.Scale = e("UIScale", { ref = scaleRef, Scale = 1 })
	body.Badge = e(SlotBadge, {
		Number = props.index,
		Size = BADGE,
		Position = UDim2.fromOffset(-10, -10),
		Rotation = -6,
		Dimmed = config == nil,
		ZIndex = 6,
	})
	local outline = if props.highlighted then HIGHLIGHT_COLOR elseif props.target then TARGET_COLOR else nil
	body.Outline = outline and e("Frame", {
		Size = UDim2.new(1, 8, 1, 8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 16) }),
		Stroke = e("UIStroke", { Color = outline, Thickness = 3 }),
	})
	body.Remove = config and props.showRemove and props.canRemove and e("TextButton", {
		Size = UDim2.fromOffset(REMOVE, REMOVE),
		Position = UDim2.new(1, -2, 0, -6),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(225, 52, 52),
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Text = "",
		ZIndex = 8,
		[React.Event.Activated] = props.OnRemove,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Stroke = e("UIStroke", { Color = Color3.fromRGB(60, 10, 10), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		X = e(UnitsArt.Icon, {
			Art = UnitsArt.Icons.CloseX,
			Size = UDim2.fromScale(0.55, 0.55),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 9,
		}),
	})

	local buttonProps = {
		Size = UDim2.fromOffset(CARD.X, CARD.Y),
		LayoutOrder = props.index,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
	}
	for key, handler in events do
		buttonProps[key] = handler
	end
	local enter, leave = buttonProps[React.Event.MouseEnter], buttonProps[React.Event.MouseLeave]
	buttonProps[React.Event.MouseEnter] = function(...)
		enter(...)
		props.OnHover(true)
	end
	buttonProps[React.Event.MouseLeave] = function(...)
		leave(...)
		props.OnHover(false)
	end
	-- The body is centered so the hover/press scale grows from the middle of the card.
	return e("TextButton", buttonProps, {
		Body = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, body),
	})
end

local function hintText(props: Props, hoveredSlot: number?): (string, Color3)
	local shown = props.ShownUnit
	local shownConfig = shown and TowersConfig[shown]
	if not shownConfig then
		return "Pick a unit, then click a slot", RewardsText.MutedColor
	end
	local name = shownConfig.DisplayName or shown
	local currentSlot = Loadout.SlotOf(props.Slots, shown)
	if hoveredSlot and hoveredSlot <= props.Unlocked and hoveredSlot ~= currentSlot then
		local other = props.Slots[hoveredSlot]
		local otherConfig = other and TowersConfig[other]
		if otherConfig and currentSlot then
			return `Swap {name} with {otherConfig.DisplayName or other}`, RewardsText.GreenColor
		elseif otherConfig then
			return `Replace {otherConfig.DisplayName or other} with {name}`, RewardsText.GreenColor
		end
		return `Put {name} in slot {hoveredSlot}`, RewardsText.GreenColor
	end
	if currentSlot then
		return `{name} is in slot {currentSlot} · press {currentSlot} in a match`, RewardsText.GoldColor
	end
	return `Click a slot to equip {name}`, Color3.new(1, 1, 1)
end

local function LoadoutDock(props: Props)
	local isTouch = IsTouch.use()
	local hoveredSlot, setHoveredSlot = React.useState(nil :: number?)

	local equippedCount = 0
	for index = 1, props.Unlocked do
		if props.Slots[index] then
			equippedCount += 1
		end
	end
	local shown = props.ShownUnit
	local shownSlot = shown and Loadout.SlotOf(props.Slots, shown)

	local slots = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, GAP),
		}),
	}
	for index = 1, Loadout.SlotCount do
		local towerId = props.Slots[index]
		local locked = index > props.Unlocked
		local canEquip = not locked and shown ~= nil and towerId ~= shown
		slots["Slot" .. index] = e(Slot, {
			index = index,
			towerId = if locked then nil else towerId,
			locked = locked,
			highlighted = index == props.PickSlot or (shownSlot ~= nil and index == shownSlot),
			target = canEquip and hoveredSlot == index,
			canRemove = equippedCount > 1,
			showRemove = isTouch or hoveredSlot == index,
			OnClick = if canEquip
				then function()
					props.OnEquip(index, shown :: string)
				end
				else nil,
			OnRemove = function()
				props.OnRemove(index)
			end,
			OnHover = function(hovered)
				setHoveredSlot(function(current)
					if hovered then
						return index
					end
					return if current == index then nil else current
				end)
			end,
		})
	end

	local hint, hintColor = hintText(props, hoveredSlot)
	-- A button so clicks on the strip don't reach the dimmer (which closes the window).
	return e("TextButton", {
		Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
	}, {
		Panel = e(UnitsArt.Panel, {
			Art = UnitsArt.Window,
			Size = UDim2.fromScale(1, 1),
			SliceScale = 0.6,
		}),
		Hint = e(Text, {
			Text = hint,
			Size = UDim2.new(1, -PADDING * 2, 0, HINT_HEIGHT - 8),
			Position = UDim2.new(0.5, 0, 0, PADDING - 2),
			AnchorPoint = Vector2.new(0.5, 0),
			Color = hintColor,
			StrokeThickness = 2.5,
			MaxTextSize = 26,
			ZIndex = 2,
		}),
		Slots = e("Frame", {
			Size = UDim2.fromOffset(SLOTS_WIDTH, CARD.Y),
			Position = UDim2.new(0.5, 0, 1, -PADDING),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, slots),
	})
end

return {
	Component = LoadoutDock,
	Size = SIZE,
}
