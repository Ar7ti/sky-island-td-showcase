-- Rewards window art (art/rewards, uploaded as Ids.Rewards) with the pixel bounds of each
-- picture's visible part. Panels that get stretched to other proportions are 9-sliced instead.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ArtImage = require(ReplicatedStorage.Shared.Source.Features.App.Common.ArtImage)
local Ids = require(ReplicatedStorage.Shared.Source.Game.AssetsIds.Ids)
local e = React.createElement

local art = ArtImage.art
local images = Ids.Rewards

export type Sliced = {
	image: string,
	center: Rect, -- SliceCenter in the uploaded image's pixels
}

local RewardsArt = {
	HeaderBanner = art(images.HeaderBanner, 4, 3, 508, 141),
	CardDefault = art(images.CardDefault, 3, 4, 363, 353),
	CardActive = art(images.CardActive, 3, 4, 372, 357),
	CardSpecial = art(images.CardSpecial, 4, 4, 368, 354),
	ButtonClaim = art(images.ButtonClaim, 3, 3, 470, 144),
	ButtonClose = art(images.ButtonClose, 4, 4, 271, 258),
	TabActive = art(images.TabActive, 3, 3, 466, 137),
	TabInactive = art(images.TabInactive, 3, 3, 468, 140),

	Window = { image = images.WindowPanel, center = Rect.new(55, 55, 408, 221) } :: Sliced,
	Footer = { image = images.FooterBar, center = Rect.new(45, 30, 418, 64) } :: Sliced,

	-- Reward icons by the names Rewards slots use, plus window decorations.
	Icons = {
		Gift = art(images.Gift, 5, 3, 311, 315),
		Coins = art(images.Coins, 5, 3, 333, 273),
		Gems = art(images.Gems, 4, 4, 333, 272),
		Diamond = art(images.Diamond, 4, 4, 322, 273),
		Crate = art(images.Crate, 3, 3, 297, 280),
		EpicChest = art(images.EpicChest, 4, 4, 400, 345),
		Claimed = art(images.Claimed, 3, 3, 281, 243),
		Locked = art(images.Locked, 3, 3, 227, 275),
		Clock = art(images.Clock, 5, 3, 284, 282),
		Streak = art(images.Streak, 5, 3, 269, 311),
		Sparkle = art(images.Sparkle, 5, 3, 259, 268),
	} :: { [string]: ArtImage.Art },
}

export type IconProps = {
	Art: ArtImage.Art,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Rotation: number?,
	Transparency: number?,
	Color: Color3?,
	ZIndex: number?,
	LayoutOrder: number?,
	ref: any?,
	children: any?,
}

-- The art fitted into its box without stretching.
function RewardsArt.Icon(props: IconProps)
	return e("ImageLabel", {
		Image = props.Art.image,
		ImageRectOffset = props.Art.rect.Min,
		ImageRectSize = Vector2.new(props.Art.rect.Width, props.Art.rect.Height),
		ScaleType = Enum.ScaleType.Fit,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Rotation = props.Rotation,
		ImageTransparency = props.Transparency,
		ImageColor3 = props.Color,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
		ref = props.ref,
	}, props.children)
end

-- A 9-sliced panel; SliceScale keeps the corners in proportion with the rest of the window.
function RewardsArt.Panel(props: { Art: Sliced, Size: UDim2, Position: UDim2?, AnchorPoint: Vector2?, SliceScale: number?, ZIndex: number?, children: any? })
	return e("ImageLabel", {
		Image = props.Art.image,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = props.Art.center,
		SliceScale = props.SliceScale or 1,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		ZIndex = props.ZIndex,
		BackgroundTransparency = 1,
	}, props.children)
end

return RewardsArt
