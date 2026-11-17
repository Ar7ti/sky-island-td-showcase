-- A square tab stuck to the left edge of a window, outside it (Towers: Units / Items, Shop: Shop / Gems /
-- Passes), as in art/inventory/mockup.png. Put the tabs in a zero-width frame at the window's left edge,
-- behind the window panel (ZIndex 0), so the selected one looks attached.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local usePressAnimation = require(ReplicatedStorage.Shared.Source.Features.App.Common.usePressAnimation)
local RewardsText = require(ReplicatedStorage.Shared.Source.Features.App.Rewards.RewardsText)
local UnitsArt = require(script.Parent.UnitsArt)
local ItemsView = require(script.Parent.ItemsView)
local e = React.createElement
local Text = RewardsText.Component

-- Side tabs (Units / Items) stuck to the left edge of the window, outside it (art/inventory/mockup.png).
local TAB = Vector2.new(116, 116)
local TAB_TOP = 120
local TAB_GAP = 16

local function SideTab(props: { Label: string, Icon: string, FallbackArt: any?, Selected: boolean, Index: number, OnClick: () -> () })
	local scaleRef, events = usePressAnimation(1.06, props.OnClick)
	local size = if props.Selected then TAB + Vector2.new(10, 10) else TAB
	local buttonProps = {
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(if props.Selected then 6 else 0, TAB_TOP + (props.Index - 1) * (TAB.Y + TAB_GAP)),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 0,
	}
	for key, handler in events do
		buttonProps[key] = handler
	end
	return e("TextButton", buttonProps, {
		Scale = e("UIScale", { ref = scaleRef, Scale = 1 }),
		Body = e(ItemsView.GlossFrame, { Selected = props.Selected, Radius = 18 }, {
			Icon = if props.Icon ~= ""
				then e("ImageLabel", {
					Size = UDim2.fromScale(0.62, 0.52),
					Position = UDim2.fromScale(0.5, 0.06),
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					Image = props.Icon,
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = 2,
				})
				elseif props.FallbackArt then e(UnitsArt.Icon, {
					Art = props.FallbackArt,
					Size = UDim2.fromScale(0.6, 0.46),
					Position = UDim2.fromScale(0.5, 0.1),
					AnchorPoint = Vector2.new(0.5, 0),
					ZIndex = 2,
				})
				else nil,
			Label = e(Text, {
				Text = props.Label,
				Size = UDim2.new(1, -14, 0, 30),
				Position = UDim2.new(0.5, 0, 1, -8),
				AnchorPoint = Vector2.new(0.5, 1),
				StrokeThickness = 3,
				Color = if props.Selected then nil else Color3.fromRGB(205, 214, 235),
				ZIndex = 2,
			}),
		}),
	})
end

return SideTab
