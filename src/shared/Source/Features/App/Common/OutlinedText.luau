-- White game text with a thick dark outline, scaled to fit its box.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)
local e = React.createElement

export type Props = {
	Text: string,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	StrokeColor: Color3?,
	StrokeThickness: number?,
	XAlignment: Enum.TextXAlignment?,
	ZIndex: number?,
	LayoutOrder: number?,
	RichText: boolean?,
}

local function OutlinedText(props: Props)
	return e("TextLabel", {
		Text = props.Text,
		RichText = props.RichText,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextScaled = true,
		TextColor3 = props.Color or Theme.Text,
		TextXAlignment = props.XAlignment or Enum.TextXAlignment.Center,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
	}, {
		Stroke = e("UIStroke", {
			Color = props.StrokeColor or Theme.Panel.Outline,
			Thickness = props.StrokeThickness or 3,
			LineJoinMode = Enum.LineJoinMode.Round,
		}),
	})
end

return OutlinedText
