-- A button whose whole look is one ready-made picture (frame, icon and text baked in),
-- with the same hover/press animation and notification bubble as GameButton.
-- Extra children (e.g. a live number drawn over the art) are placed over the picture.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ArtImage = require(script.Parent.ArtImage)
local Badge = require(script.Parent.Badge)
local usePressAnimation = require(script.Parent.usePressAnimation)
local e = React.createElement

export type Props = {
	Art: ArtImage.Art,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	HoverScale: number?,
	Badge: string?,
	OnClick: (() -> ())?,
	children: any?,
}

local function ImageButton(props: Props)
	local scaleRef, events = usePressAnimation(props.HoverScale or 1.06, props.OnClick)

	local buttonProps = {
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
	}
	for key, handler in events do
		buttonProps[key] = handler
	end

	-- The body is centered so the hover/press scale grows from the middle of the button.
	return e("TextButton", buttonProps, {
		Body = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, {
			Scale = e("UIScale", { ref = scaleRef, Scale = 1 }),
			Art = e(ArtImage.Image, { Art = props.Art }),
			Overlay = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 2,
			}, props.children),
			Badge = props.Badge and e(Badge, { Text = props.Badge }),
		}),
	})
end

return ImageButton
