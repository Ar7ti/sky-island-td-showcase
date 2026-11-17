-- Game text for the rewards window: outlined, optionally with a top-to-bottom gradient.
-- Without TextSize the text is scaled to fit its box; with TextSize the box grows with the text.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Source.Features.App.Common.Theme)
local e = React.createElement

export type Props = {
	Text: string,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	TextSize: number?,
	Color: Color3?,
	Gradient: { Color3 }?, -- top, bottom
	StrokeColor: Color3?,
	StrokeThickness: number?,
	XAlignment: Enum.TextXAlignment?,
	Rotation: number?,
	ZIndex: number?,
	LayoutOrder: number?,
	MaxTextSize: number?, -- caps a scaled text (short lines otherwise blow up to the box height)
	RichText: boolean?,
	Wrapped: boolean?, -- wraps a long scaled text over several lines instead of shrinking it to one
}

local RewardsText = {}

RewardsText.Gold = { Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 170, 30) }
RewardsText.Fire = { Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 110, 30) }
RewardsText.GoldColor = Color3.fromRGB(255, 205, 50)
RewardsText.GreenColor = Color3.fromRGB(130, 245, 90)
RewardsText.MutedColor = Color3.fromRGB(165, 175, 200)
RewardsText.Stroke = Color3.fromRGB(22, 16, 30)

function RewardsText.Component(props: Props)
	local fixed = props.TextSize ~= nil
	return e("TextLabel", {
		Text = props.Text,
		Size = props.Size or (if fixed then UDim2.fromOffset(0, props.TextSize :: number) else UDim2.fromScale(1, 1)),
		AutomaticSize = if fixed then Enum.AutomaticSize.X else nil,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Rotation = props.Rotation,
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextScaled = not fixed,
		TextSize = props.TextSize,
		TextColor3 = if props.Gradient then Color3.new(1, 1, 1) else (props.Color or Theme.Text),
		TextXAlignment = props.XAlignment or Enum.TextXAlignment.Center,
		RichText = props.RichText,
		TextWrapped = props.Wrapped,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
	}, {
		Stroke = e("UIStroke", {
			Color = props.StrokeColor or RewardsText.Stroke,
			Thickness = props.StrokeThickness or 3,
			LineJoinMode = Enum.LineJoinMode.Round,
		}),
		MaxSize = props.MaxTextSize and e("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize }),
		Gradient = props.Gradient and e("UIGradient", {
			Color = ColorSequence.new(props.Gradient[1], props.Gradient[2]),
			Rotation = 90,
		}),
	})
end

return RewardsText
