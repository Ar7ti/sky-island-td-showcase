-- Units window art (art/units, uploaded as Ids.UnitsKit) with the pixel bounds of each picture's
-- visible part. Panels and pills that get stretched to other proportions are 9-sliced instead.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ArtImage = require(ReplicatedStorage.Shared.Source.Features.App.Common.ArtImage)
local Ids = require(ReplicatedStorage.Shared.Source.Game.AssetsIds.Ids)
local e = React.createElement

local art = ArtImage.art
local images = Ids.UnitsKit

export type Sliced = {
	image: string,
	center: Rect, -- SliceCenter in the uploaded image's pixels
}

local function sliced(image: string, left: number, top: number, right: number, bottom: number): Sliced
	return { image = image, center = Rect.new(left, top, right, bottom) }
end

-- Card pictures share a 428x616 canvas; the card itself (frame outline) fills BODY, the space
-- above it is for decorations such as the Mythic crown.
local CARD_CANVAS = Vector2.new(428, 616)
local CARD_BODY = Rect.new(16, 92, 412, 600)

local UnitsArt = {
	Window = sliced(images.Window, 30, 30, 344, 196),
	Header = sliced(images.HeaderTab, 70, 30, 267, 67),
	Details = sliced(images.DetailsPanel, 25, 25, 258, 297),
	Search = sliced(images.SearchBase, 35, 25, 343, 53),
	Sort = sliced(images.SortBase, 32, 25, 269, 62),
	Equip = sliced(images.EquipButton, 34, 24, 281, 75),
	Red = sliced(images.CloseButton, 45, 45, 144, 140),
	Counter = sliced(images.Counter, 32, 30, 234, 91),
	StatRow = sliced(images.StatRow, 30, 25, 322, 67),
	Rarity = sliced(images.RarityBadge, 40, 28, 289, 85),
	Price = sliced(images.PriceBadge, 30, 25, 213, 75),
	Duplicate = sliced(images.DuplicateBadge, 30, 25, 210, 80),

	CloseButton = art(images.CloseButton, 4, 4, 184, 180),
	LevelCircle = art(images.LevelCircle, 4, 4, 128, 130),

	Icons = {
		Collection = art(images.Collection, 4, 4, 220, 168),
		Search = art(images.Search, 4, 5, 188, 192),
		CloseX = art(images.CloseX, 4, 4, 181, 182),
		SelectedCheck = art(images.SelectedCheck, 4, 4, 190, 194),
		DropdownArrow = art(images.DropdownArrow, 5, 4, 167, 126),
		Coin = art(images.Coin, 4, 4, 217, 221),
		Damage = art(images.Damage, 5, 4, 425, 410),
		Range = art(images.Range, 4, 4, 461, 468),
		Cooldown = art(images.Cooldown, 4, 5, 340, 425),
	} :: { [string]: ArtImage.Art },

	-- Card color per tower rarity (Ids.UnitsKit.CardBackground / CardFrame keys).
	CardColors = {
		Common = "Green",
		Normal = "Green",
		Rare = "Blue",
		Epic = "Purple",
		Legendary = "Yellow",
		Mythic = "Orange",
	} :: { [string]: string },

	-- Text accent per rarity, for names and the rarity badge.
	RarityColors = {
		Common = Color3.fromRGB(150, 236, 90),
		Normal = Color3.fromRGB(150, 236, 90),
		Rare = Color3.fromRGB(100, 202, 255),
		Epic = Color3.fromRGB(209, 146, 255),
		Legendary = Color3.fromRGB(255, 211, 70),
		Mythic = Color3.fromRGB(255, 150, 50),
	} :: { [string]: Color3 },

	-- Width/height of the card body, for sizing grid cells.
	CardAspect = CARD_BODY.Width / CARD_BODY.Height,
}

export type IconProps = {
	Art: ArtImage.Art,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	ZIndex: number?,
	LayoutOrder: number?,
	children: any?,
}

-- The art fitted into its box without stretching.
function UnitsArt.Icon(props: IconProps)
	return e("ImageLabel", {
		Image = props.Art.image,
		ImageRectOffset = props.Art.rect.Min,
		ImageRectSize = Vector2.new(props.Art.rect.Width, props.Art.rect.Height),
		ScaleType = Enum.ScaleType.Fit,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		ImageColor3 = props.Color,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
	}, props.children)
end

-- A 9-sliced panel; SliceScale sets how big the corners are drawn.
function UnitsArt.Panel(props: {
	Art: Sliced,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	SliceScale: number?,
	Color: Color3?,
	ZIndex: number?,
	children: any?,
})
	return e("ImageLabel", {
		Image = props.Art.image,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = props.Art.center,
		SliceScale = props.SliceScale or 1,
		ImageColor3 = props.Color,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		ZIndex = props.ZIndex,
		BackgroundTransparency = 1,
	}, props.children)
end

-- One card layer (background or frame) placed so the card outline fills the parent box.
function UnitsArt.CardLayer(props: { Image: string, ZIndex: number? })
	return e("ImageLabel", {
		Image = props.Image,
		ScaleType = Enum.ScaleType.Stretch,
		Size = UDim2.fromScale(CARD_CANVAS.X / CARD_BODY.Width, CARD_CANVAS.Y / CARD_BODY.Height),
		Position = UDim2.fromScale(-CARD_BODY.Min.X / CARD_BODY.Width, -CARD_BODY.Min.Y / CARD_BODY.Height),
		ZIndex = props.ZIndex,
		BackgroundTransparency = 1,
	})
end

-- One card layer cut to the card outline and drawn at any proportions: the frame is 9-sliced so
-- its corners stay sharp, the background is simply stretched. SliceScale sets the corner size.
function UnitsArt.FlexCardLayer(props: { Image: string, Sliced: boolean, SliceScale: number, ZIndex: number? })
	return e("ImageLabel", {
		Image = props.Image,
		ImageRectOffset = CARD_BODY.Min,
		ImageRectSize = Vector2.new(CARD_BODY.Width, CARD_BODY.Height),
		ScaleType = if props.Sliced then Enum.ScaleType.Slice else Enum.ScaleType.Stretch,
		SliceCenter = Rect.new(110, 120, 286, 388), -- relative to the cut-out card
		SliceScale = props.SliceScale,
		Size = UDim2.fromScale(1, 1),
		ZIndex = props.ZIndex,
		BackgroundTransparency = 1,
	})
end

function UnitsArt.CardImages(rarity: string): (string, string)
	local color = UnitsArt.CardColors[rarity] or "Green"
	return images.CardBackground[color], images.CardFrame[color]
end

return UnitsArt
