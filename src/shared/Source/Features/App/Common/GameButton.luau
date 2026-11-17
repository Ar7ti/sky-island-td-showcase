-- Chunky 3D button: dark outline, darker lip under a gradient face, a glossy highlight
-- and a springy hover/press animation. Content goes in as children and is placed on the face.
-- The button does nothing by itself: behaviour comes from props.OnClick.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)
local Badge = require(script.Parent.Badge)
local usePressAnimation = require(script.Parent.usePressAnimation)
local e = React.createElement

local OUTLINE = 4 -- px of the dark border
local LIP = 7 -- px of the darker bottom edge that gives the 3D look

export type Props = {
	Colors: Theme.ColorSet,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	CornerRadius: UDim?,
	HoverScale: number?,
	Badge: string?,
	OnClick: (() -> ())?,
	children: any?,
}

local function GameButton(props: Props)
	local corner = props.CornerRadius or UDim.new(0, 16)
	local colors = props.Colors
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

			Outline = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = colors.Outline,
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = corner }),

				Lip = e("Frame", {
					Size = UDim2.new(1, -OUTLINE * 2, 1, -OUTLINE * 2),
					Position = UDim2.fromOffset(OUTLINE, OUTLINE),
					BackgroundColor3 = colors.Lip,
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = corner }),
				}),

				Face = e("Frame", {
					Size = UDim2.new(1, -OUTLINE * 2, 1, -OUTLINE * 2 - LIP),
					Position = UDim2.fromOffset(OUTLINE, OUTLINE),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BorderSizePixel = 0,
					ZIndex = 2,
				}, {
					Corner = e("UICorner", { CornerRadius = corner }),
					Gradient = e("UIGradient", {
						Color = ColorSequence.new(colors.Top, colors.Bottom),
						Rotation = 90,
					}),
					Highlight = e("Frame", {
						Size = UDim2.new(1, -16, 0.38, 0),
						Position = UDim2.new(0.5, 0, 0, 5),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Color3.new(1, 1, 1),
						BackgroundTransparency = 0.78,
						BorderSizePixel = 0,
						ZIndex = 3,
					}, {
						Corner = e("UICorner", { CornerRadius = corner }),
						Fade = e("UIGradient", {
							Rotation = 90,
							Transparency = NumberSequence.new(0, 1),
						}),
					}),
					Content = e("Frame", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						ZIndex = 4,
					}, props.children),
				}),
			}),

			Badge = props.Badge and e(Badge, { Text = props.Badge }),
		}),
	})
end

return GameButton
