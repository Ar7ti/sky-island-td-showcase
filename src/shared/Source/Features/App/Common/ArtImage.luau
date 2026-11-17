-- Ready-made UI art cropped to its visible part, so the box size equals the drawn button
-- (the uploaded PNGs have transparent margins of different sizes).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

export type Art = {
	image: string,
	rect: Rect, -- visible part of the uploaded image, in its pixels
}

local ArtImage = {}

-- Pixel bounds of the visible part (inclusive, as measured on the uploaded image).
function ArtImage.art(image: string, minX: number, minY: number, maxX: number, maxY: number): Art
	return { image = image, rect = Rect.new(minX, minY, maxX + 1, maxY + 1) }
end

function ArtImage.aspect(art: Art): number
	return art.rect.Width / art.rect.Height
end

-- Box size for the art at a given height or width (px).
function ArtImage.sizeForHeight(art: Art, height: number): Vector2
	return Vector2.new(math.round(height * ArtImage.aspect(art)), height)
end

function ArtImage.sizeForWidth(art: Art, width: number): Vector2
	return Vector2.new(width, math.round(width / ArtImage.aspect(art)))
end

-- Size and Position for an area given as fractions of the art: { x, y, width, height }.
function ArtImage.area(area: { number }): (UDim2, UDim2)
	return UDim2.fromScale(area[3], area[4]), UDim2.fromScale(area[1], area[2])
end

function ArtImage.Image(props: { Art: Art, ZIndex: number? })
	return e("ImageLabel", {
		Image = props.Art.image,
		ImageRectOffset = props.Art.rect.Min,
		ImageRectSize = Vector2.new(props.Art.rect.Width, props.Art.rect.Height),
		ScaleType = Enum.ScaleType.Stretch,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = props.ZIndex,
	})
end

return ArtImage
