-- The leader requests a map here. Selection comes back from the pad's replicated state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local PartyMaps = require(ReplicatedStorage.Shared.Features.Services.Parties.PartyMaps)
local App = ReplicatedStorage.Shared.Source.Features.App
local Theme = require(App.Common.Theme)
local usePressAnimation = require(App.Common.usePressAnimation)
local RewardsText = require(App.Rewards.RewardsText)
local UnitsArt = require(App.Units.UnitsArt)
local usePartyState = require(script.Parent.usePartyState)
local e = React.createElement

local CARD_WIDTH = 336
local CARD_FOOTER = 82
local GAP = 22
local INSET = 18
local HEADER = 44
local MAX_VISIBLE_CARDS = 2

local maps: { PartyMaps.Map } = {}
for _, map in PartyMaps do
	if not map.Hidden then
		table.insert(maps, map)
	end
end

local MapPicker = {}

local function artHeight(compact: boolean): number
	return if compact then 106 else 142
end

function MapPicker.Measure(compact: boolean): Vector2
	local count = math.min(#maps, MAX_VISIBLE_CARDS)
	return Vector2.new(INSET * 2 + count * CARD_WIDTH + math.max(count - 1, 0) * GAP,
		HEADER + artHeight(compact) + CARD_FOOTER + INSET * 2)
end

local function Card(props: {
	map: PartyMaps.Map,
	order: number,
	selected: boolean,
	compact: boolean,
	onSelect: ((string) -> ())?,
})
	local map = props.map
	local onSelect = props.onSelect
	local choose = if onSelect and not props.selected then function()
		onSelect(map.Name)
	end else nil
	local scaleRef, events = usePressAnimation(1, choose)
	local previewHeight = artHeight(props.compact)
	local footerY = 12 + previewHeight
	local button = {
		Size = UDim2.fromOffset(CARD_WIDTH, previewHeight + CARD_FOOTER),
		LayoutOrder = props.order,
		Text = map.Name,
		TextTransparency = 1,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Interactable = choose ~= nil,
		Selectable = choose ~= nil,
	}
	if choose then
		for key, handler in events do
			button[key] = handler
		end
	end
	local background, border = UnitsArt.CardImages(if props.selected then "Normal" elseif choose then "Rare" else "Epic")

	return e("TextButton", button, {
		Body = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, {
			Scale = e("UIScale", { ref = scaleRef, Scale = 1 }),
			Background = e(UnitsArt.FlexCardLayer, { Image = background, Sliced = false, SliceScale = 1 }),
			Frame = e(UnitsArt.FlexCardLayer, { Image = border, Sliced = true, SliceScale = 0.65, ZIndex = 2 }),
			Preview = e("ImageLabel", {
				Image = map.PreviewImage,
				ScaleType = Enum.ScaleType.Crop,
				Size = UDim2.new(1, -28, 0, previewHeight),
				Position = UDim2.fromOffset(14, 12),
				BackgroundColor3 = Theme.Panel.FaceBottom,
				BorderSizePixel = 0,
				ZIndex = 3,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 11) }),
				Difficulty = map.Difficulty and e(UnitsArt.Panel, {
					Art = UnitsArt.StatRow,
					Size = UDim2.fromOffset(108, 34),
					Position = UDim2.fromOffset(10, 9),
					SliceScale = 0.5,
					ZIndex = 4,
				}, {
					Label = e(RewardsText.Component, {
						Text = string.upper(map.Difficulty),
						Size = UDim2.new(1, -12, 1, -6),
						Position = UDim2.fromOffset(6, 3),
						Color = if map.Difficulty == "Normal" then Theme.Text else RewardsText.GoldColor,
						MaxTextSize = 23,
						StrokeThickness = 2,
						ZIndex = 5,
					}),
				}),
			}),
			Shade = e("Frame", {
				Size = UDim2.new(1, -28, 0, 57),
				Position = UDim2.fromOffset(14, footerY),
				BackgroundColor3 = Theme.Panel.FaceBottom,
				BorderSizePixel = 0,
				ZIndex = 3,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 9) }),
			}),
			Name = e(RewardsText.Component, {
				Text = map.Name,
				Size = UDim2.new(1, -48, 0, 30),
				Position = UDim2.fromOffset(24, footerY + 1),
				MaxTextSize = 28,
				XAlignment = Enum.TextXAlignment.Left,
				StrokeThickness = 2,
				ZIndex = 4,
			}),
			Rewards = map.RewardScale and e(RewardsText.Component, {
				Text = `×{map.RewardScale} Coins & XP`,
				Size = UDim2.new(1, -48, 0, 25),
				Position = UDim2.fromOffset(24, footerY + 27),
				Color = RewardsText.GoldColor,
				MaxTextSize = 22,
				XAlignment = Enum.TextXAlignment.Left,
				StrokeThickness = 2,
				ZIndex = 4,
			}),
			Selected = props.selected and e(UnitsArt.Panel, {
				Art = UnitsArt.Equip,
				Size = UDim2.fromOffset(124, 34),
				Position = UDim2.new(1, -24, 0, 21),
				AnchorPoint = Vector2.new(1, 0),
				SliceScale = 0.5,
				ZIndex = 5,
			}, {
				Text = e(RewardsText.Component, {
					Text = "SELECTED",
					Size = UDim2.new(1, -12, 1, -6),
					Position = UDim2.fromOffset(6, 3),
					MaxTextSize = 21,
					StrokeThickness = 2,
					ZIndex = 6,
				}),
			}),
		}),
	})
end

export type Props = {
	party: usePartyState.PartyState,
	compact: boolean,
	OnSelect: ((mapName: string) -> ())?,
}

function MapPicker.Component(props: Props)
	local party = props.party
	local isLeader = party.leader == Players.LocalPlayer.UserId
	local leader = if party.leader then Players:GetPlayerByUserId(party.leader) else nil
	local heading = if isLeader then "CHOOSE A MAP"
		elseif leader then `{leader.DisplayName} picks the map` else "The party leader picks the map"

	local cards = {
		List = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, GAP),
		}),
	}
	for index, map in maps do
		cards[map.Name] = e(Card, {
			map = map,
			order = index,
			selected = party.mapName == map.Name,
			compact = props.compact,
			onSelect = if isLeader then props.OnSelect else nil,
		})
	end

	return e(UnitsArt.Panel, {
		Art = UnitsArt.Window,
		Size = UDim2.fromScale(1, 1),
	}, {
		Header = e(UnitsArt.Panel, {
			Art = UnitsArt.Header,
			Size = UDim2.new(1, -2 * INSET, 0, HEADER),
			Position = UDim2.fromOffset(INSET, INSET / 2),
			SliceScale = 0.8,
		}, {
			Label = e(RewardsText.Component, {
				Text = heading,
				Size = UDim2.new(1, -32, 1, -12),
				Position = UDim2.fromOffset(16, 6),
				MaxTextSize = 28,
			}),
		}),
		Cards = e("ScrollingFrame", {
			Size = UDim2.new(1, -2 * INSET, 0, artHeight(props.compact) + CARD_FOOTER + INSET / 2),
			Position = UDim2.fromOffset(INSET, INSET + HEADER),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(#maps * CARD_WIDTH + math.max(#maps - 1, 0) * GAP, 0),
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollingEnabled = #maps > MAX_VISIBLE_CARDS,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.TextMuted,
		}, cards),
	})
end

return MapPicker
