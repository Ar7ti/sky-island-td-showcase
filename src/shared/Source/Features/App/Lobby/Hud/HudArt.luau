-- Lobby HUD art: each uploaded picture with the pixel bounds of its visible part
-- (measured on the uploaded image). Re-measure the bounds when an image is replaced.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArtImage = require(ReplicatedStorage.Shared.Source.Features.App.Common.ArtImage)
local Ids = require(ReplicatedStorage.Shared.Source.Game.AssetsIds.Ids)

local art = ArtImage.art
local images = Ids.Lobby

return {
	Towers = art(images.Towers, 98, 127, 922, 904),
	Shop = art(images.Shop, 109, 111, 913, 875),
	Crates = art(images.Crates, 106, 108, 918, 899),
	Settings = art(images.Settings, 83, 108, 941, 916),
	Rewards = art(images.Rewards, 86, 86, 935, 420),
	Quests = art(images.Quests, 83, 34, 939, 308),
	Codes = art(images.Codes, 64, 93, 960, 418),
	Play = art(images.Play, 63, 31, 959, 303),
	Invite = art(images.Invite, 49, 61, 973, 277),
	Coins = art(images.Coins, 46, 33, 976, 299),
	Gems = art(images.Gems, 52, 35, 971, 305),
	ProfileCard = art(images.ProfileCard, 44, 38, 980, 345),
}
