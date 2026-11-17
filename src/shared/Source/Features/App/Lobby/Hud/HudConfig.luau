-- Everything the lobby HUD shows that is not player data: which buttons exist, their order and look.
-- Add or reorder buttons here; what a button does is passed to LobbyHud as props.actions[id],
-- and its notification bubble as props.badges[id].
--
-- Look: `art` is a ready-made button picture from HudArt. Without art the button is drawn in code
-- from `icon` + `label` + `colors`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Common = ReplicatedStorage.Shared.Source.Features.App.Common
local Theme = require(Common.Theme)
local ArtImage = require(Common.ArtImage)
local HudArt = require(script.Parent.HudArt)
local Loadout = require(ReplicatedStorage.Shared.Features.Services.TowersServices.Loadout)

export type ButtonConfig = {
	id: string,
	label: string,
	art: ArtImage.Art?,
	icon: string?,
	colors: Theme.ColorSet?,
}

-- Areas are fractions of the cropped art: { x, y, width, height }.
export type Area = { number }

export type CurrencyConfig = {
	id: string,
	dataKey: string?, -- Data.client field (see Economy/Currencies); nil shows 0
	art: ArtImage.Art,
	amountArea: Area, -- the empty field right of the icon where the number goes
}

local HudConfig = {}

HudConfig.LeftMenu = {
	{ id = "Towers", label = "Towers", art = HudArt.Towers },
	{ id = "Shop", label = "Shop", art = HudArt.Shop },
	{ id = "Crates", label = "Crates", art = HudArt.Crates },
	{ id = "Settings", label = "Settings", art = HudArt.Settings },
} :: { ButtonConfig }

HudConfig.RightMenu = {
	{ id = "Rewards", label = "Rewards", art = HudArt.Rewards },
	{ id = "Quests", label = "Quests", art = HudArt.Quests },
	{ id = "Codes", label = "Codes", art = HudArt.Codes },
} :: { ButtonConfig }

HudConfig.Currencies = {
	{
		id = "Coins",
		dataKey = "currency",
		art = HudArt.Coins,
		amountArea = { 0.31, 0.22, 0.62, 0.56 },
	},
	{
		id = "Gems",
		dataKey = "gems",
		art = HudArt.Gems,
		amountArea = { 0.31, 0.22, 0.62, 0.56 },
	},
} :: { CurrencyConfig }

HudConfig.Play = { id = "Play", label = "Play", art = HudArt.Play } :: ButtonConfig
HudConfig.Invite = { id = "Invite", label = "Invite friends", art = HudArt.Invite } :: ButtonConfig

-- Player card art and where the avatar, texts and XP bar sit on it.
HudConfig.PlayerCard = {
	art = HudArt.ProfileCard,
	avatarCenter = Vector2.new(0.1835, 0.5245),
	avatarHeight = 0.78, -- fraction of card height; the ring in the art frames it
	nameArea = { 0.365, 0.13, 0.56, 0.27 },
	levelArea = { 0.365, 0.41, 0.56, 0.19 },
	xpArea = { 0.346, 0.672, 0.585, 0.136 },
}

-- Tower loadout under the Play button.
HudConfig.Loadout = {
	slotCount = Loadout.SlotCount,
	emptyIcon = "+",
	lockedIcon = "🔒",
}

return HudConfig
