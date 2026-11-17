-- Tower loadout under the Play button: one slot per tower the player takes into the match.
-- Only the look is here: which towers are equipped and how many slots are unlocked come in props.
-- Under each slot is the key that spawns its tower in the match (hidden on touch screens).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Common = ReplicatedStorage.Shared.Source.Features.App.Common
local Theme = require(Common.Theme)
local Panel = require(Common.Panel)
local GameButton = require(Common.GameButton)
local Icon = require(Common.Icon)
local OutlinedText = require(Common.OutlinedText)
local KeyCap = require(Common.KeyCap)
local IsTouch = require(Common.useIsTouch)
local Loadout = require(ReplicatedStorage.Shared.Features.Services.TowersServices.Loadout)
local HudConfig = require(script.Parent.HudConfig)
local e = React.createElement

export type SlotTower = {
	icon: string,
}

export type Props = {
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	towers: { [number]: SlotTower }, -- equipped tower per slot index
	unlockedSlots: number,
	selectedSlot: number?, -- slot being filled from the units list, outlined
	OnSlotClick: ((slot: number) -> ())?,
}

local PADDING = 10
local SELECTED_COLOR = Color3.fromRGB(255, 214, 64)

local function Slot(props: { index: number, tower: SlotTower?, locked: boolean, OnClick: (() -> ())? })
	local content
	if props.tower then
		content = e(Icon, { Icon = props.tower.icon, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
	elseif props.locked then
		content = e(Icon, { Icon = HudConfig.Loadout.lockedIcon, Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
	else
		content = e(OutlinedText, {
			Text = HudConfig.Loadout.emptyIcon,
			Size = UDim2.fromScale(0.6, 0.7),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Color = Theme.TextMuted,
		})
	end

	return e(GameButton, {
		Colors = Theme.Colors.Dark,
		Size = UDim2.fromScale(1, 1),
		CornerRadius = UDim.new(0, 14),
		OnClick = if props.locked then nil else props.OnClick,
	}, {
		Content = content,
	})
end

local function LoadoutBar(props: Props)
	local slotCount = HudConfig.Loadout.slotCount
	local isTouch = IsTouch.use()
	local children = {
		List = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, PADDING),
		}),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, PADDING + 2),
			PaddingBottom = UDim.new(0, PADDING + 2),
		}),
	}
	for index = 1, slotCount do
		local key = Loadout.Keys[index]
		local locked = index > props.unlockedSlots
		children["Slot" .. index] = e("Frame", {
			Size = UDim2.fromScale(1 / slotCount, 1),
			LayoutOrder = index,
			BackgroundTransparency = 1,
		}, {
			Ratio = e("UIAspectRatioConstraint", { AspectRatio = 1 }),
			Selected = props.selectedSlot == index and e("Frame", {
				Size = UDim2.new(1, 6, 1, 6),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ZIndex = 2,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 17) }),
				Stroke = e("UIStroke", { Color = SELECTED_COLOR, Thickness = 3 }),
			}),
			Key = key and not isTouch and e(KeyCap, {
				Text = key.Text,
				Size = UDim2.fromScale(0.34, 0.34),
				Position = UDim2.fromScale(0.5, 1),
				AnchorPoint = Vector2.new(0.5, 0.45),
				Dimmed = locked,
				ZIndex = 3,
			}),
			Slot = e(Slot, {
				index = index,
				tower = props.towers[index],
				locked = locked,
				OnClick = props.OnSlotClick and function()
					props.OnSlotClick(index)
				end,
			}),
		})
	end

	return e(Panel, {
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		CornerRadius = UDim.new(0, 20),
	}, children)
end

return LoadoutBar
