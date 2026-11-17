-- Match HUD kit (art/matchhud, uploaded as Ids.MatchHud): 9-slice centers of the stretched
-- pieces, a filling bar, and placement of parts by the kit's layout.json rects.
-- layout.json rects are { x, y, width, height } as fractions of their module.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Ids = require(ReplicatedStorage.Shared.Source.Game.AssetsIds.Ids)
local UnitsArt = require(ReplicatedStorage.Shared.Source.Features.App.Units.UnitsArt)
local e = React.createElement

local images = Ids.MatchHud

local function sliced(image: string, left: number, top: number, right: number, bottom: number, height: number)
	-- height: the picture's pixel height, so a panel can scale its corners to its own height.
	return { image = image, center = Rect.new(left, top, right, bottom), height = height }
end

local HudArt = {
	HealthHousing = sliced(images.HealthHousing, 36, 32, 412, 99, 131),
	HealthTrack = sliced(images.HealthTrack, 28, 18, 405, 56, 74),
	HealthFill = sliced(images.HealthFill, 24, 16, 415, 57, 73),
	WaveHousing = sliced(images.WaveHousing, 32, 23, 397, 64, 87),
	LevelHousing = sliced(images.LevelHousing, 34, 24, 422, 57, 81),
	LevelTrack = sliced(images.LevelTrack, 25, 17, 414, 43, 60),
	LevelFill = sliced(images.LevelFill, 24, 17, 400, 49, 66),
	LevelBadge = sliced(images.LevelBadge, 28, 28, 254, 90, 118),
	CashHousing = sliced(images.CashHousing, 70, 65, 919, 283, 348),
	Images = images,
}

export type Sliced = typeof(HudArt.HealthHousing)

-- Size and Position for a layout.json rect.
function HudArt.place(rect: { number }): { Size: UDim2, Position: UDim2 }
	return { Size = UDim2.fromScale(rect[3], rect[4]), Position = UDim2.fromScale(rect[1], rect[2]) }
end

-- A sliced piece stretched over a rect; its corners follow the rect's pixel height.
function HudArt.Panel(props: { Art: Sliced, Rect: { number }?, Height: number, ZIndex: number?, children: any? })
	local place = HudArt.place(props.Rect or { 0, 0, 1, 1 })
	return e(UnitsArt.Panel, {
		Art = props.Art,
		Size = place.Size,
		Position = place.Position,
		SliceScale = props.Height / props.Art.height,
		ZIndex = props.ZIndex,
	}, props.children)
end

-- A picture fitted into a rect.
function HudArt.Image(props: { Image: string, Rect: { number }, ZIndex: number?, children: any? })
	local place = HudArt.place(props.Rect)
	return e("ImageLabel", {
		Image = props.Image,
		ScaleType = Enum.ScaleType.Fit,
		Size = place.Size,
		Position = place.Position,
		BackgroundTransparency = 1,
		ZIndex = props.ZIndex,
	}, props.children)
end

-- Empty track with the fill drawn over it. The fill keeps its full width inside a clipping
-- frame whose width follows Percent, so its slanted ends never squash.
function HudArt.Bar(props: {
	Track: Sliced,
	Fill: Sliced,
	Rect: { number },
	FillRect: { number }, -- inside the track
	Height: number, -- track height in px
	Percent: number,
	children: any?,
})
	local percent = math.clamp(props.Percent, 0, 1)
	local fill = HudArt.place(props.FillRect)
	return e(HudArt.Panel, { Art = props.Track, Rect = props.Rect, Height = props.Height, ZIndex = 2 }, {
		Area = e("Frame", {
			Size = fill.Size,
			Position = fill.Position,
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, {
			Clip = e("Frame", {
				Size = UDim2.fromScale(percent, 1),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Visible = percent > 0,
			}, {
				Fill = e(UnitsArt.Panel, {
					Art = props.Fill,
					Size = UDim2.fromScale(1 / math.max(percent, 0.001), 1),
					SliceScale = props.Height * props.FillRect[4] / props.Fill.height,
				}),
			}),
		}),
		Content = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 5,
		}, props.children),
	})
end

-- 37125 -> "37,125"
function HudArt.thousands(value: number): string
	local text = tostring(math.floor(value))
	local result = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (result:gsub("^,", ""))
end

return HudArt
