-- The first page of the Crates window: every case (summon banners, then chests) as a bright store card in one
-- list that scrolls top to bottom. A card shows the case big over a turning sunburst in its own color, what it can
-- drop (one tower per rarity with that rarity's chance, weakest to best) and a big button. Nothing is bought here:
-- the button and the card open that case's menu (CaseMenu) with every reward and the buy / open buttons.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local TowersConfig = require(ReplicatedStorage.Shared.Features.Services.TowersServices.towersConfig)
local Banners = require(ReplicatedStorage.Shared.Features.Services.Summon.Banners)
local ChestsConfig = require(ReplicatedStorage.Shared.Features.Services.Chests.ChestsConfig)
local App = ReplicatedStorage.Shared.Source.Features.App
local ImageButton = require(App.Common.ImageButton)
local usePressAnimation = require(App.Common.usePressAnimation)
local RewardsArt = require(App.Rewards.RewardsArt)
local RewardsText = require(App.Rewards.RewardsText)
local RewardsMotion = require(App.Rewards.RewardsMotion)
local ChestsTab = require(script.Parent.ChestsTab)
local CaseOdds = require(script.Parent.CaseOdds)
local useSummon = require(script.Parent.useSummon)
local e = React.createElement
local Text = RewardsText.Component

local CARD_HEIGHT = 286
local CARD_GAP = 14
local SCROLLBAR = 10
local ART = 230 -- the case picture
local CONTENT_LEFT = 290
local TILE = Vector2.new(118, 126)
local TILE_GAP = 12
local MAX_TILES = 4 -- every case has 2 to 4 tower rarities
local TILES_TOP = 76
local BUTTON = Vector2.new(300, 86)
local OUTLINE = Color3.fromRGB(28, 20, 48)
local WHITE = Color3.new(1, 1, 1)
local SPIN = TweenInfo.new(24, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
local BOB = TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

-- Each case's card colors: top and bottom of the background.
local THEMES = {
	Standard = { Color3.fromRGB(80, 200, 255), Color3.fromRGB(40, 100, 230) },
	Event = { Color3.fromRGB(255, 110, 210), Color3.fromRGB(160, 40, 230) },
	Basic = { Color3.fromRGB(140, 230, 90), Color3.fromRGB(40, 150, 70) },
	Golden = { Color3.fromRGB(255, 225, 80), Color3.fromRGB(255, 140, 20) },
	Epic = { Color3.fromRGB(200, 120, 255), Color3.fromRGB(100, 45, 220) },
	Royal = { Color3.fromRGB(255, 205, 70), Color3.fromRGB(200, 70, 40) },
} :: { [string]: { Color3 } }
local DEFAULT_THEME = THEMES.Standard

local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	return (text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function timeLeft(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days, hours, minutes = seconds // 86400, seconds // 3600 % 24, seconds // 60 % 60
	if days > 0 then
		return string.format("%dd %02dh %02dm", days, hours, minutes)
	end
	return string.format("%02dh %02dm %02ds", hours, minutes, seconds % 60)
end

-- Light rays turning slowly behind the case picture.
local function Sunburst(props: { Center: Vector2, Size: number })
	local spinRef = React.useRef(nil :: Frame?)
	RewardsMotion.useLoop(spinRef, { Rotation = 360 }, SPIN)
	local rays = {}
	local count = 9 -- each bar makes two opposite rays
	for index = 1, count do
		rays["Ray" .. index] = e("Frame", {
			Size = UDim2.fromScale(0.11, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = (index - 1) * 180 / count,
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			Fade = e("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0.5),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	end
	return e("Frame", {
		ref = spinRef,
		Size = UDim2.fromOffset(props.Size, props.Size),
		Position = UDim2.fromOffset(props.Center.X, props.Center.Y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 2, -- over the card's color layer
	}, rays)
end

-- One rarity of the case: a tower of it, the rarity's name and its chance.
local function DropTile(props: { TowerId: string, Rarity: string, Chance: number, Best: boolean, X: number, Y: number })
	local config = TowersConfig[props.TowerId]
	local color = useSummon.color(props.Rarity)
	return e("Frame", {
		Size = UDim2.fromOffset(TILE.X, TILE.Y),
		Position = UDim2.fromOffset(props.X, props.Y),
		BackgroundColor3 = WHITE,
		ZIndex = 3,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 16) }),
		-- The best rarity gets a white rim instead of the dark one.
		Stroke = e("UIStroke", {
			Color = if props.Best then WHITE else OUTLINE,
			Thickness = if props.Best then 4 else 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Fill = e("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(color:Lerp(WHITE, 0.25), color:Lerp(Color3.new(0, 0, 0), 0.45)),
		}),
		Label = e(Text, {
			Text = string.upper(props.Rarity),
			Size = UDim2.new(1, -10, 0, 20),
			Position = UDim2.fromOffset(5, 4),
			StrokeThickness = 2,
			MaxTextSize = 18,
			ZIndex = 4,
		}),
		Icon = e("ImageLabel", {
			Image = config and config.Icon or "",
			Size = UDim2.fromOffset(92, 92),
			Position = UDim2.new(0.5, 0, 0, 24),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 4,
		}),
		Chance = e(Text, {
			Text = CaseOdds.percent(props.Chance),
			Size = UDim2.new(1, -10, 0, 28),
			Position = UDim2.new(0, 5, 1, -30),
			XAlignment = Enum.TextXAlignment.Right,
			StrokeThickness = 3,
			MaxTextSize = 26,
			ZIndex = 5,
		}),
	})
end

type CardProps = {
	Width: number,
	Order: number,
	Kind: string,
	Id: string,
	Now: number, -- for the odds: changes only with the featured tower
	Name: string,
	Info: string,
	Theme: { Color3 },
	Owned: number?,
	Image: string?, -- a picture, or
	Art: any?, -- a RewardsArt icon
	Tag: string?, -- "NEW!" / "FEATURED"
	Timer: string?,
	ButtonLabel: string,
	ButtonPrice: number?,
	ButtonCurrency: string?,
	ButtonGreen: boolean,
	OnClick: () -> (),
}

local function Card(props: CardProps)
	local owned = props.Owned or 0
	local scaleRef, events = usePressAnimation(1.01, props.OnClick)
	local bobRef = React.useRef(nil :: Frame?)
	RewardsMotion.useLoop(bobRef, { Position = UDim2.new(0, 30 + ART / 2, 0.5, -8) }, BOB)
	local width = props.Width - 8
	local height = CARD_HEIGHT - 8
	local contentWidth = width - CONTENT_LEFT - 30

	-- One tile per rarity, weakest on the left; the best rarity's most likely tower stands for it.
	local odds = CaseOdds.of(props.Kind, props.Id, props.Now)
	local picks = {}
	for index = #odds, 1, -1 do
		local rarityOdds = odds[index]
		table.insert(picks, { towerId = rarityOdds.towers[1].towerId, rarity = rarityOdds.rarity, chance = rarityOdds.chance })
	end
	while #picks > MAX_TILES do
		table.remove(picks, 1)
	end
	-- The tiles start at the left of the content; the button stands to their right, at the same height.
	local tiles = {}
	for index, pick in picks do
		tiles["Tile" .. index] = e(DropTile, {
			TowerId = pick.towerId,
			Rarity = pick.rarity,
			Chance = pick.chance,
			Best = index == #picks,
			X = CONTENT_LEFT + (index - 1) * (TILE.X + TILE_GAP),
			Y = TILES_TOP,
		})
	end

	local buttonProps = {
		Size = UDim2.fromOffset(props.Width, CARD_HEIGHT),
		LayoutOrder = props.Order,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
	}
	for key, handler in events do
		buttonProps[key] = handler
	end
	local theme = props.Theme
	return e("TextButton", buttonProps, {
		Body = e("Frame", {
			Size = UDim2.fromOffset(width, height),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, {
			Scale = e("UIScale", { ref = scaleRef, Scale = 1 }),
			-- The background: color gradient and rays, clipped to the rounded card.
			Back = e("CanvasGroup", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 26) }),
				-- On its own layer: a gradient on the CanvasGroup itself would tint the rays too.
				Fill = e("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = WHITE,
					BorderSizePixel = 0,
					ZIndex = 1,
				}, {
					Gradient = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(theme[1], theme[2]) }),
				}),
				Rays = e(Sunburst, { Center = Vector2.new(30 + ART / 2, height / 2), Size = 900 }),
				Shade = e("Frame", {
					Size = UDim2.new(1, 0, 0, 96),
					Position = UDim2.fromScale(0, 1),
					AnchorPoint = Vector2.new(0, 1),
					BackgroundColor3 = Color3.new(0, 0, 0),
					BackgroundTransparency = 0.75,
					BorderSizePixel = 0,
					ZIndex = 3,
				}, {
					Fade = e("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.2) }),
				}),
			}),
			Outline = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 2,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 26) }),
				Stroke = e("UIStroke", { Color = OUTLINE, Thickness = 5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			}),
			Inner = e("Frame", {
				Size = UDim2.new(1, -10, 1, -10),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ZIndex = 2,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 22) }),
				Stroke = e("UIStroke", { Color = WHITE, Thickness = 2, Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			}),
			Picture = e("Frame", {
				ref = bobRef,
				Size = UDim2.fromOffset(ART, ART),
				Position = UDim2.new(0, 30 + ART / 2, 0.5, 4),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Rotation = -6,
				ZIndex = 3,
			}, {
				Art = if props.Image
					then e("ImageLabel", {
						Image = props.Image,
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						ScaleType = Enum.ScaleType.Fit,
						ZIndex = 3,
					})
					else e(RewardsArt.Icon, {
						Art = props.Art,
						Size = UDim2.fromScale(0.92, 0.92),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						ZIndex = 3,
					}),
			}),
			Tag = props.Tag and e(Text, {
				Text = props.Tag,
				Size = UDim2.fromOffset(170, 50),
				Position = UDim2.fromOffset(14, 8),
				Rotation = -10,
				Color = Color3.fromRGB(255, 50, 70),
				StrokeColor = WHITE,
				StrokeThickness = 4,
				ZIndex = 6,
			}),
			Owned = owned > 0 and e("Frame", {
				Size = UDim2.fromOffset(78, 46),
				-- Sits on the button's top-left corner.
				Position = UDim2.fromOffset(width - 24 - BUTTON.X + 10, TILES_TOP + TILE.Y / 2 + 6 - BUTTON.Y / 2 - 26),
				BackgroundColor3 = Color3.fromRGB(230, 40, 55),
				ZIndex = 6,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
				Stroke = e("UIStroke", { Color = OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				Label = e(Text, {
					Text = `x{owned}`,
					Size = UDim2.new(1, -10, 0, 30),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					StrokeThickness = 2.5,
					ZIndex = 7,
				}),
			}),
			Title = e(Text, {
				Text = props.Name,
				Size = UDim2.fromOffset(contentWidth, 60),
				Position = UDim2.fromOffset(CONTENT_LEFT, 14),
				StrokeColor = OUTLINE,
				StrokeThickness = 5,
				ZIndex = 4,
			}),
			Timer = props.Timer and e("Frame", {
				Size = UDim2.fromOffset(0, 34),
				AutomaticSize = Enum.AutomaticSize.X,
				Position = UDim2.fromOffset(width - 24, 22),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = OUTLINE,
				BackgroundTransparency = 0.3,
				ZIndex = 4,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
				Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
				Label = e(Text, { Text = `⏰ {props.Timer}`, TextSize = 22, StrokeThickness = 2, ZIndex = 5 }),
			}),
			Tiles = e(React.Fragment, nil, tiles),
			Info = e(Text, {
				Text = props.Info,
				Size = UDim2.fromOffset(width - CONTENT_LEFT - 40, 30),
				Position = UDim2.fromOffset(CONTENT_LEFT + 4, height - 50),
				XAlignment = Enum.TextXAlignment.Left,
				StrokeColor = OUTLINE,
				StrokeThickness = 2.5,
				MaxTextSize = 24,
				ZIndex = 4,
			}),
			-- Opens the menu like the rest of the card; the real buying happens there.
			Button = e(ImageButton, {
				Art = if props.ButtonGreen then RewardsArt.ButtonClaim else RewardsArt.TabActive,
				Size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
				Position = UDim2.fromOffset(width - 24, TILES_TOP + TILE.Y / 2 + 6),
				AnchorPoint = Vector2.new(1, 0.5),
				HoverScale = 1.05,
				OnClick = props.OnClick,
			}, {
				Row = e("Frame", {
					Size = UDim2.new(1, -30, 0.6, 0),
					Position = UDim2.fromScale(0.5, 0.46),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					ZIndex = 2,
				}, {
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 10),
					}),
					Label = e(Text, {
						Text = props.ButtonLabel,
						TextSize = 34,
						StrokeColor = if props.ButtonGreen then Color3.fromRGB(16, 70, 8) else Color3.fromRGB(110, 50, 0),
						StrokeThickness = 3,
						LayoutOrder = 1,
						ZIndex = 2,
					}),
					Icon = props.ButtonPrice and e(RewardsArt.Icon, {
						Art = if props.ButtonCurrency == "Gems" then RewardsArt.Icons.Gems else RewardsArt.Icons.Coins,
						Size = UDim2.fromOffset(40, 34),
						LayoutOrder = 2,
						ZIndex = 2,
					}),
					Price = props.ButtonPrice and e(Text, {
						Text = formatNumber(props.ButtonPrice),
						TextSize = 32,
						StrokeColor = if props.ButtonGreen then Color3.fromRGB(16, 70, 8) else Color3.fromRGB(110, 50, 0),
						StrokeThickness = 3,
						LayoutOrder = 3,
						ZIndex = 2,
					}),
				}),
			}),
		}),
	})
end

local function CaseList(props: {
	Frame: Rect,
	Banners: { Banners.Banner },
	Snapshot: any,
	Actions: any,
	OnSelectBanner: (string) -> (),
	OnSelectChest: (string) -> (),
})
	local frame = props.Frame
	local actions = props.Actions
	local now = props.Snapshot.now
	-- The odds only change with the featured tower; a whole-second clock would rebuild them every second.
	local week = math.floor(now / Banners.EventLength) * Banners.EventLength
	local width = frame.Width - SCROLLBAR - 12
	local cards = {
		Layout = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, CARD_GAP - 8) }),
		Padding = e("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 4) }),
	}
	local order = 0

	for _, banner in props.Banners do
		order += 1
		local featured = Banners.Featured(banner, now)
		local config = featured and TowersConfig[featured.towerId]
		cards[banner.id] = e(Card, {
			Width = width,
			Order = order,
			Kind = "Banner",
			Id = banner.id,
			Now = week,
			Name = banner.title,
			Info = if config then `Featured: {config.DisplayName}  ·  boosted chance` else banner.subtitle,
			Theme = THEMES[banner.id] or DEFAULT_THEME,
			Image = config and config.Icon,
			Art = RewardsArt.Icons[banner.crate] or RewardsArt.Icons.Crate,
			Tag = if featured then "NEW!" else nil,
			Timer = featured and timeLeft(featured.endsAt - now),
			ButtonLabel = "SUMMON",
			ButtonPrice = banner.costs[1],
			ButtonCurrency = banner.currency,
			ButtonGreen = true,
			OnClick = function()
				props.OnSelectBanner(banner.id)
			end,
		})
	end

	for _, id in ChestsTab.Visible(actions.owned, props.Snapshot.paidRandomAllowed == true) do
		order += 1
		local chest = ChestsConfig.Chests[id]
		local owned = actions.owned[id] or 0
		cards[id] = e(Card, {
			Width = width,
			Order = order,
			Kind = "Chest",
			Id = id,
			Now = week,
			Name = chest.Name,
			Info = table.concat(chest.Lines, "  ·  "),
			Theme = THEMES[id] or DEFAULT_THEME,
			Owned = owned,
			Image = chest.Icon,
			Tag = if chest.Robux then "BEST!" else nil,
			ButtonLabel = if owned > 0 then "OPEN" elseif chest.Price then "BUY" else "VIEW",
			ButtonPrice = if owned > 0 then nil else chest.Price and chest.Price.Amount,
			ButtonCurrency = chest.Price and chest.Price.Currency,
			ButtonGreen = owned > 0 or chest.Price == nil,
			OnClick = function()
				props.OnSelectChest(id)
			end,
		})
	end

	return e("ScrollingFrame", {
		Size = UDim2.fromOffset(frame.Width, frame.Height),
		Position = UDim2.fromOffset(frame.Min.X, frame.Min.Y),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = SCROLLBAR,
		ScrollBarImageColor3 = Color3.fromRGB(255, 200, 80),
	}, cards)
end

return CaseList
