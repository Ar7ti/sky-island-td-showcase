-- Small 3D keyboard key with a label, used to show which key triggers a slot or action.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)
local e = React.createElement

export type Props = {
	Text: string,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Dimmed: boolean?,
	ZIndex: number?,
}

local FACE = Color3.fromRGB(240, 245, 255)
local SIDE = Color3.fromRGB(120, 128, 150)
local LABEL = Color3.fromRGB(20, 28, 44)

local function KeyCap(props: Props)
	return e("Frame", {
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = SIDE,
		BackgroundTransparency = if props.Dimmed then 0.5 else 0,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex,
	}, {
		Ratio = e("UIAspectRatioConstraint", { AspectRatio = 1 }),
		Corner = e("UICorner", { CornerRadius = UDim.new(0.25, 0) }),
		Face = e("TextLabel", {
			Size = UDim2.fromScale(1, 0.86),
			BackgroundColor3 = FACE,
			BackgroundTransparency = if props.Dimmed then 0.5 else 0,
			BorderSizePixel = 0,
			Text = props.Text,
			TextColor3 = LABEL,
			TextTransparency = if props.Dimmed then 0.4 else 0,
			TextScaled = true,
			Font = Theme.Font,
			ZIndex = props.ZIndex,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.25, 0) }),
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0.12, 0),
				PaddingBottom = UDim.new(0.12, 0),
			}),
		}),
	})
end

return KeyCap
