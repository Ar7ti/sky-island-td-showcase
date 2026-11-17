-- Loadout slot number (also the match hotkey) as a gold tile: on unit cards it marks where the unit
-- is equipped, on the loadout dock it labels each slot. Square, sized by props.Size (offset).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Source.Features.App.Common.Theme)
local e = React.createElement

export type Props = {
	Number: number,
	Size: number,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Dimmed: boolean?, -- empty slot: grey tile
	Rotation: number?,
	ZIndex: number?,
	LayoutOrder: number?,
}

local GOLD_TOP = Color3.fromRGB(255, 236, 120)
local GOLD_BOTTOM = Color3.fromRGB(255, 160, 24)
local GREY_TOP = Color3.fromRGB(150, 158, 180)
local GREY_BOTTOM = Color3.fromRGB(92, 100, 122)
local OUTLINE = Color3.fromRGB(46, 26, 6)
local NUMBER = Color3.fromRGB(255, 255, 255)

local function SlotBadge(props: Props)
	local size = props.Size
	local zIndex = props.ZIndex or 5
	local top = if props.Dimmed then GREY_TOP else GOLD_TOP
	local bottom = if props.Dimmed then GREY_BOTTOM else GOLD_BOTTOM
	return e("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Rotation = props.Rotation,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = zIndex,
		LayoutOrder = props.LayoutOrder,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0.28, 0) }),
		Gradient = e("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 }),
		Stroke = e("UIStroke", {
			Color = OUTLINE,
			Thickness = math.max(2, math.round(size / 14)),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		-- Shine across the upper half.
		Shine = e("Frame", {
			Size = UDim2.new(1, -size * 0.2, 0.32, 0),
			Position = UDim2.new(0.5, 0, 0, size * 0.08),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			ZIndex = zIndex,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		}),
		Number = e("TextLabel", {
			Text = tostring(props.Number),
			Size = UDim2.fromScale(0.86, 0.86),
			Position = UDim2.fromScale(0.5, 0.52),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = Theme.Font,
			TextScaled = true,
			TextColor3 = NUMBER,
			ZIndex = zIndex + 1,
		}, {
			Stroke = e("UIStroke", {
				Color = OUTLINE,
				Thickness = math.max(2, math.round(size / 12)),
				LineJoinMode = Enum.LineJoinMode.Round,
			}),
		}),
	})
end

return SlotBadge
