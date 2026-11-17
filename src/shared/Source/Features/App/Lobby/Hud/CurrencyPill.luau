-- One currency counter on its ready-made art: the live amount from player data sits in the empty
-- field right of the icon. The whole pill is a button (props.OnAdd, e.g. open the shop).
-- props.Amount shows a value from elsewhere instead (e.g. the match-only Cash attribute), and
-- props.Icon (an element) covers the icon in the art with another one (e.g. the match Cash icon).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Common = ReplicatedStorage.Shared.Source.Features.App.Common
local ArtImage = require(Common.ArtImage)
local ImageButton = require(Common.ImageButton)
local OutlinedText = require(Common.OutlinedText)
local useDataValue = require(Common.useDataValue)
local HudConfig = require(script.Parent.HudConfig)
local HeldRewards = require(script.Parent.HeldRewards)
local e = React.createElement

export type Props = {
	Config: HudConfig.CurrencyConfig,
	Size: UDim2,
	LayoutOrder: number?,
	Amount: number?,
	Icon: React.ReactElement?,
	OnAdd: (() -> ())?,
}

local function CurrencyPill(props: Props)
	local config = props.Config
	local saved = tonumber(useDataValue(if props.Amount == nil then config.dataKey else nil)) or 0
	-- Match rewards still flying in (RewardArrival) are not counted yet.
	local held = tonumber(HeldRewards.use(if props.Amount == nil then config.dataKey else nil)) or 0
	local amount = if props.Amount ~= nil then props.Amount else math.max(0, saved - held)
	local amountSize, amountPosition = ArtImage.area(config.amountArea)

	return e(ImageButton, {
		Art = config.art,
		Size = props.Size,
		LayoutOrder = props.LayoutOrder,
		HoverScale = 1.04,
		OnClick = props.OnAdd,
	}, {
		Amount = e(OutlinedText, {
			Text = tostring(amount),
			Size = amountSize,
			Position = amountPosition,
			StrokeThickness = 3,
			ZIndex = 3,
		}),
		Icon = props.Icon and e("Frame", {
			Size = UDim2.fromScale(1.05, 1.05),
			Position = UDim2.fromScale(0.15, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundTransparency = 1,
			ZIndex = 4,
		}, { Icon = props.Icon }),
	})
end

return CurrencyPill
