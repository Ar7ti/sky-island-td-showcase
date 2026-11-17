-- An icon that is either an image ("rbxassetid://...", "rbxthumb://...") or a text glyph / emoji placeholder.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)
local e = React.createElement

export type Props = {
	Icon: string,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	ZIndex: number?,
	LayoutOrder: number?,
}

local function isImage(icon: string): boolean
	return string.find(icon, "^rbx") ~= nil or string.find(icon, "^http") ~= nil
end

local function Icon(props: Props)
	local common = {
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
	}

	if isImage(props.Icon) then
		common.Image = props.Icon
		common.ScaleType = Enum.ScaleType.Fit
		return e("ImageLabel", common)
	end

	common.Text = props.Icon
	common.TextScaled = true
	common.Font = Theme.Font
	common.TextColor3 = props.Color or Theme.Text
	return e("TextLabel", common)
end

return Icon
