-- A box with a fixed 1080p pixel size that is pinned to a screen point and scaled with the screen.
-- UIScale scales around AnchorPoint, so a group anchored to a corner stays glued to that corner.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

export type Props = {
	Scale: number,
	Size: Vector2, -- px at 1080p
	Position: UDim2,
	AnchorPoint: Vector2,
	children: any?,
}

local function ScaledGroup(props: Props)
	return e("Frame", {
		Size = UDim2.fromOffset(props.Size.X, props.Size.Y),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
	}, {
		UIScale = e("UIScale", { Scale = props.Scale }),
		Children = React.createElement(React.Fragment, nil, props.children),
	})
end

return ScaledGroup
