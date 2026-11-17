-- Red notification bubble ("!" or a counter) pinned to the top-right corner of its parent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)
local OutlinedText = require(script.Parent.OutlinedText)
local e = React.createElement

local function Badge(props: { Text: string, Size: number? })
	local size = props.Size or 40
	return e("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.new(1, size * 0.2, 0, -size * 0.3),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.Badge.Face,
		ZIndex = 20,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Stroke = e("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3 }),
		Label = e(OutlinedText, {
			Text = props.Text,
			Size = UDim2.fromScale(0.7, 0.7),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			StrokeColor = Theme.Badge.Outline,
			StrokeThickness = 2,
			ZIndex = 21,
		}),
	})
end

return Badge
