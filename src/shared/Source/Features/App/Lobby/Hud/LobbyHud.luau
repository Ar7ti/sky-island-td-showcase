-- Lobby HUD layout (art/hud/mockup.png): player card (top left), currencies (top right), main menu (left),
-- rewards/quests/codes (right), active effects (bottom left; next to the player card on touch screens),
-- invite (bottom right; under the right menu on touch screens), Play + tower loadout (bottom center).
-- Pure view: what each button does comes from props.actions[buttonId], bubbles from props.badges.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Common = ReplicatedStorage.Shared.Source.Features.App.Common
local ScaledGroup = require(Common.ScaledGroup)
local ArtImage = require(Common.ArtImage)
local useUiScale = require(Common.useUiScale)
local UiScale = require(Common.UiScale)
local IsTouch = require(Common.useIsTouch)
local HudConfig = require(script.Parent.HudConfig)
local PlayerCard = require(script.Parent.PlayerCard)
local CurrencyPill = require(script.Parent.CurrencyPill)
local ButtonColumn = require(script.Parent.ButtonColumn)
local PlayButton = require(script.Parent.PlayButton)
local LoadoutBar = require(script.Parent.LoadoutBar)
local MenuButton = require(script.Parent.MenuButton)
local ActiveEffects = require(script.Parent.ActiveEffects)
local MapPicker = require(script.Parent.MapPicker)
local usePartyState = require(script.Parent.usePartyState)
local PartyShared = require(ReplicatedStorage.Shared.Features.Services.Parties.PartyShared)
local e = React.createElement

-- All sizes are pixels on a 1080p screen; the other side of each art box follows the art's proportions.
local EDGE = 20
local GAP = 14
local CARD_WIDTH = 470
local CURRENCY_HEIGHT = 72
local TILE_HEIGHT = 112 -- left menu
local TOUCH_TILE_HEIGHT = 140 -- bigger on touch screens so the tiles stay finger-sized
local WIDE_WIDTH = 250 -- right menu
local INVITE_HEIGHT = 78
local PLAY_WIDTH = 340
local MIN_LEAVE_TOUCH_HEIGHT = 45 -- keep 44 points after UIScale rounds to screen pixels
local LOADOUT = Vector2.new(560, 116)

local CARD = ArtImage.sizeForWidth(HudConfig.PlayerCard.art, CARD_WIDTH)
local PLAY = ArtImage.sizeForWidth(HudConfig.Play.art :: ArtImage.Art, PLAY_WIDTH)
local INVITE = ArtImage.sizeForHeight(HudConfig.Invite.art :: ArtImage.Art, INVITE_HEIGHT)
-- On touch screens the left menu is a 2-column grid, so it ends well above the movement thumbstick.
local TOUCH_LEFT_COLUMNS = 2
local LEFT = ButtonColumn.measure(HudConfig.LeftMenu, "Tile", "Height", TILE_HEIGHT, GAP)
local LEFT_TOUCH = ButtonColumn.measure(HudConfig.LeftMenu, "Tile", "Height", TOUCH_TILE_HEIGHT, GAP, TOUCH_LEFT_COLUMNS)
local RIGHT = ButtonColumn.measure(HudConfig.RightMenu, "Wide", "Width", WIDE_WIDTH, GAP)

export type Props = {
	actions: { [string]: () -> () }?,
	badges: { [string]: string }?,
	loadout: { [number]: LoadoutBar.SlotTower }?,
	unlockedSlots: number?,
	selectedSlot: number?,
	OnSlotClick: ((slot: number) -> ())?,
	OnSelectMap: ((mapName: string) -> ())?, -- party pad leader picked a map card
	hidePlayArea: boolean?, -- the Units window shows its own loadout strip in the same place
}

local function currencyRow(actions: { [string]: () -> () })
	local children = {
		List = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, GAP),
		}),
	}
	local width = 0
	for index, config in HudConfig.Currencies do
		local size = ArtImage.sizeForHeight(config.art, CURRENCY_HEIGHT)
		width += size.X + (if index > 1 then GAP else 0)
		children[config.id] = e(CurrencyPill, {
			Config = config,
			Size = UDim2.fromOffset(size.X, size.Y),
			LayoutOrder = index,
			OnAdd = actions[config.id],
		})
	end
	return children, Vector2.new(width, CURRENCY_HEIGHT)
end

local function LobbyHud(props: Props)
	local scale = useUiScale()
	local isTouch = IsTouch.use()
	local actions = props.actions or {}
	local badges = props.badges or {}
	local currencies, currencySize = currencyRow(actions)
	local running = ActiveEffects.useRunning()
	local effectsSize = ActiveEffects.Measure(#running)
	local party = usePartyState()
	local compactMapPicker = isTouch and UiScale.viewport().Y <= 430
	local playHeight = if party and isTouch then math.max(PLAY.Y, MIN_LEAVE_TOUCH_HEIGHT / scale) else PLAY.Y
	local playAreaHeight = playHeight + GAP + LOADOUT.Y

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		PlayerCard = e(ScaledGroup, {
			Scale = scale,
			Size = CARD,
			Position = UDim2.fromOffset(EDGE, EDGE),
			AnchorPoint = Vector2.new(0, 0),
		}, {
			Card = e(PlayerCard, {
				Size = UDim2.fromScale(1, 1),
				OnClick = actions.Profile,
				Badge = badges.Profile,
			}),
		}),

		Currencies = e(ScaledGroup, {
			Scale = scale,
			Size = currencySize,
			Position = UDim2.new(1, -EDGE, 0, EDGE),
			AnchorPoint = Vector2.new(1, 0),
		}, currencies),

		-- Centered on the left edge, mirroring the right menu.
		LeftMenu = e(ScaledGroup, {
			Scale = scale,
			Size = if isTouch then LEFT_TOUCH else LEFT,
			Position = UDim2.new(0, EDGE, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
		}, {
			Column = e(ButtonColumn.Component, {
				Buttons = HudConfig.LeftMenu,
				Layout = "Tile",
				Fit = "Height",
				Extent = if isTouch then TOUCH_TILE_HEIGHT else TILE_HEIGHT,
				Gap = GAP,
				Columns = if isTouch then TOUCH_LEFT_COLUMNS else 1,
				Alignment = Enum.HorizontalAlignment.Left,
				actions = actions,
				badges = badges,
			}),
		}),

		RightMenu = e(ScaledGroup, {
			Scale = scale,
			Size = RIGHT,
			Position = UDim2.new(1, -EDGE, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
		}, {
			Column = e(ButtonColumn.Component, {
				Buttons = HudConfig.RightMenu,
				Layout = "Wide",
				Fit = "Width",
				Extent = WIDE_WIDTH,
				Gap = GAP,
				Alignment = Enum.HorizontalAlignment.Right,
				actions = actions,
				badges = badges,
			}),
		}),

		-- Running boosts. Bottom left is the movement thumbstick on touch screens: there they sit right of the card.
		Effects = #running > 0 and e(ScaledGroup, {
			Scale = scale,
			Size = effectsSize,
			Position = if isTouch
				then UDim2.fromOffset((EDGE + CARD.X + GAP) * scale, EDGE * scale)
				else UDim2.new(0, EDGE, 1, -EDGE),
			AnchorPoint = if isTouch then Vector2.new(0, 0) else Vector2.new(0, 1),
		}, {
			Panel = e(ActiveEffects.Component, { Running = running }),
		}),

		-- Bottom right; on touch screens under the right menu (clear of the jump button).
		Invite = e(ScaledGroup, {
			Scale = scale,
			Size = INVITE,
			Position = if isTouch
				then UDim2.new(1, -EDGE, 0.5, (RIGHT.Y / 2 + GAP) * scale)
				else UDim2.new(1, -EDGE, 1, -EDGE),
			AnchorPoint = if isTouch then Vector2.new(1, 0) else Vector2.new(1, 1),
		}, {
			Button = e(MenuButton, {
				Config = HudConfig.Invite,
				Layout = "Wide",
				Size = UDim2.fromScale(1, 1),
				OnClick = actions[HudConfig.Invite.id],
			}),
		}),

		-- On a party pad: the map cards, right above Play/Leave. Gone once the teleport starts.
		MapPicker = party ~= nil and not props.hidePlayArea and party.status ~= PartyShared.Status.Teleporting and e(ScaledGroup, {
			Scale = scale,
			Size = MapPicker.Measure(compactMapPicker),
			Position = UDim2.new(0.5, 0, 1, -EDGE - (playAreaHeight + GAP) * scale),
			AnchorPoint = Vector2.new(0.5, 1),
		}, {
			Picker = e(MapPicker.Component, {
				party = party :: usePartyState.PartyState,
				compact = compactMapPicker,
				OnSelect = props.OnSelectMap,
			}),
		}),

		PlayArea = not props.hidePlayArea and e(ScaledGroup, {
			Scale = scale,
			Size = Vector2.new(math.max(PLAY.X, LOADOUT.X), playAreaHeight),
			Position = UDim2.new(0.5, 0, 1, -EDGE),
			AnchorPoint = Vector2.new(0.5, 1),
		}, {
			Play = e(PlayButton, {
				Size = UDim2.fromOffset(PLAY.X, playHeight),
				Position = UDim2.fromScale(0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				OnClick = actions[HudConfig.Play.id],
				OnLeave = actions.Leave,
			}),
			Loadout = e(LoadoutBar, {
				Size = UDim2.fromOffset(LOADOUT.X, LOADOUT.Y),
				Position = UDim2.fromScale(0.5, 1),
				AnchorPoint = Vector2.new(0.5, 1),
				towers = props.loadout or {},
				unlockedSlots = props.unlockedSlots or HudConfig.Loadout.slotCount,
				selectedSlot = props.selectedSlot,
				OnSlotClick = props.OnSlotClick,
			}),
		}),
	})
end

return LobbyHud
