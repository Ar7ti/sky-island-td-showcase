-- A configured HUD button: the ready-made art when the config has one, otherwise a button
-- drawn in code. "Tile" puts the icon above the label, "Wide" puts it left of the label.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Common = ReplicatedStorage.Shared.Source.Features.App.Common
local Theme = require(Common.Theme)
local GameButton = require(Common.GameButton)
local ImageButton = require(Common.ImageButton)
local Icon = require(Common.Icon)
local OutlinedText = require(Common.OutlinedText)
local HudConfig = require(script.Parent.HudConfig)
local e = React.createElement

export type Props = {
	Config: HudConfig.ButtonConfig,
	Layout: "Tile" | "Wide",
	Size: UDim2,
	LayoutOrder: number?,
	Badge: string?,
	OnClick: (() -> ())?,
}

local function MenuButton(props: Props)
	local config = props.Config

	if config.art then
		return e(ImageButton, {
			Art = config.art,
			Size = props.Size,
			LayoutOrder = props.LayoutOrder,
			Badge = props.Badge,
			OnClick = props.OnClick,
		})
	end

	local isTile = props.Layout == "Tile"
	local colors = config.colors or Theme.Colors.Dark
	return e(GameButton, {
		Colors = colors,
		Size = props.Size,
		LayoutOrder = props.LayoutOrder,
		Badge = props.Badge,
		OnClick = props.OnClick,
		CornerRadius = UDim.new(0, if isTile then 18 else 20),
	}, {
		Icon = config.icon and e(Icon, {
			Icon = config.icon,
			Size = if isTile then UDim2.fromScale(0.62, 0.58) else UDim2.fromScale(0.3, 0.8),
			Position = if isTile then UDim2.fromScale(0.5, 0.06) else UDim2.fromScale(0.05, 0.5),
			AnchorPoint = if isTile then Vector2.new(0.5, 0) else Vector2.new(0, 0.5),
		}),
		Label = e(OutlinedText, {
			Text = config.label,
			Size = if isTile then UDim2.fromScale(0.92, 0.28) else UDim2.fromScale(0.6, 0.42),
			Position = if isTile then UDim2.fromScale(0.5, 0.95) else UDim2.fromScale(0.37, 0.5),
			AnchorPoint = if isTile then Vector2.new(0.5, 1) else Vector2.new(0, 0.5),
			XAlignment = if isTile then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
			StrokeColor = colors.TextStroke,
		}),
	})
end

return MenuButton
