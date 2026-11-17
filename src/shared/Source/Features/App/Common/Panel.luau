-- Dark rounded plate with a thick outline and a thin lighter inner border, used behind HUD widgets.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)
local e = React.createElement

export type Props = {
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	CornerRadius: UDim?,
	AccentColor: Color3?, -- optional colored border instead of the default gray one
	children: any?,
}

local function Panel(props: Props)
	local corner = props.CornerRadius or UDim.new(0, 18)
	return e("Frame", {
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = corner }),
		Gradient = e("UIGradient", {
			Color = ColorSequence.new(Theme.Panel.Face, Theme.Panel.FaceBottom),
			Rotation = 90,
		}),
		Outline = e("UIStroke", {
			Color = Theme.Panel.Outline,
			Thickness = 4,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Inner = e("Frame", {
			Size = UDim2.new(1, -8, 1, -8),
			Position = UDim2.fromOffset(4, 4),
			BackgroundTransparency = 1,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(corner.Scale, math.max(corner.Offset - 4, 0)) }),
			Stroke = e("UIStroke", {
				Color = props.AccentColor or Theme.Panel.Inner,
				Thickness = 2.5,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),
		Content = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, props.children),
	})
end

return Panel
