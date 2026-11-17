-- The menu of one case, a popup over the Crates list (CaseList). Left: every reward the case can drop, towers
-- grouped by rarity with their chances, plus a chest's coins, gems and items. Right: guarantees (banners) or
-- how many the player owns (chests), and the only buy / open buttons of the window: x1 and multi.
-- Banners: SUMMON x1 / x10 (Banners.costs). Chests: OPEN x1 / xN of the owned ones, BUY x1 / x5 / x10.
-- The window owns the requests and the reveal popups; closing a reveal comes back to this menu.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Common = ReplicatedStorage.Shared.Source.Features.App.Common
local ArtImage = require(Common.ArtImage)
local ImageButton = require(Common.ImageButton)
local TowersConfig = require(ReplicatedStorage.Shared.Features.Services.TowersServices.towersConfig)
local Banners = require(ReplicatedStorage.Shared.Features.Services.Summon.Banners)
local ChestsConfig = require(ReplicatedStorage.Shared.Features.Services.Chests.ChestsConfig)
local ItemsConfig = require(ReplicatedStorage.Shared.Features.Services.Items.ItemsConfig)
local App = ReplicatedStorage.Shared.Source.Features.App
local RewardsArt = require(App.Rewards.RewardsArt)
local RewardsText = require(App.Rewards.RewardsText)
local RewardsMotion = require(App.Rewards.RewardsMotion)
local ChestsTab = require(script.Parent.ChestsTab)
local useSummon = require(script.Parent.useSummon)
local CaseOdds = require(script.Parent.CaseOdds)
local e = React.createElement
local Text = RewardsText.Component

local PANEL = Vector2.new(1160, 744)
local HEADER_HEIGHT = 156
local PAD = 24
local SIDE_WIDTH = 372
local LIST_WIDTH = PANEL.X - PAD * 3 - SIDE_WIDTH
local BODY_TOP = HEADER_HEIGHT
local BODY_HEIGHT = PANEL.Y - BODY_TOP - PAD
local TILE = Vector2.new(122, 168)
local TILE_GAP = 12
local SCROLLBAR = 8
local BUTTON_HEIGHT = 88
local BUTTON_GAP = 10
local CLOSE = ArtImage.sizeForHeight(RewardsArt.ButtonClose, 84)
local PANEL_COLOR = Color3.fromRGB(30, 33, 46)
local DARK = Color3.fromRGB(18, 20, 30)
local BORDER = Color3.fromRGB(70, 76, 100)
local RED = Color3.fromRGB(255, 110, 110)
local GEM_COLOR = Color3.fromRGB(110, 200, 255)
local ITEM_COLOR = Color3.fromRGB(157, 245, 189)
local POP = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local ROCK = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local CHEST_BUY_COUNTS = { 1, 5, 10 }
local MAX_OPEN = 10 -- ChestService MAX_BATCH

export type Selected = { kind: string, id: string }

export type Props = {
	Selected: Selected,
	Snapshot: useSummon.Snapshot,
	Actions: any, -- ChestsTab.useActions
	Pending: boolean, -- a summon is on its way
	Error: string?,
	PanelTop: number, -- the window's panel starts this far below its top
	OnSummon: (count: number) -> (),
	OnClose: () -> (),
}

local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	return (text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local percent = CaseOdds.percent

local function timeLeft(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days, hours, minutes, secs = seconds // 86400, seconds // 3600 % 24, seconds // 60 % 60, seconds % 60
	if days > 0 then
		return string.format("%dd %02d:%02d:%02d", days, hours, minutes, secs)
	end
	return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

local function currencyIcon(currency: string): ArtImage.Art
	return if currency == "Gems" then RewardsArt.Icons.Gems else RewardsArt.Icons.Coins
end

local function box(props: { Size: UDim2, Position: UDim2, Color: Color3?, LayoutOrder: number? }, children: any?)
	return e("Frame", {
		Size = props.Size,
		Position = props.Position,
		LayoutOrder = props.LayoutOrder,
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.2,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 18) }),
		Stroke = e("UIStroke", { Color = props.Color or BORDER, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		Children = children and e(React.Fragment, nil, children),
	})
end

-- One possible reward: picture framed in its color, name, chance.
type TileInfo = {
	key: string,
	image: string?,
	art: ArtImage.Art?,
	name: string,
	chance: string,
	color: Color3,
	star: boolean?,
}

local function Tile(props: { Info: TileInfo, LayoutOrder: number })
	local info = props.Info
	return e("Frame", {
		LayoutOrder = props.LayoutOrder,
		BackgroundColor3 = PANEL_COLOR,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 16) }),
		Stroke = e("UIStroke", { Color = info.color, Thickness = if info.star then 4 else 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		Glow = e("Frame", {
			Size = UDim2.new(1, 0, 0, 112),
			BackgroundColor3 = info.color,
			BackgroundTransparency = 0.78,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 16) }),
			Gradient = e("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1) }),
		}),
		Image = if info.image
			then e("ImageLabel", {
				Image = info.image,
				Size = UDim2.fromOffset(98, 98),
				Position = UDim2.new(0.5, 0, 0, 8),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 2,
			})
			else info.art and e(RewardsArt.Icon, {
				Art = info.art,
				Size = UDim2.fromOffset(92, 80),
				Position = UDim2.new(0.5, 0, 0, 16),
				AnchorPoint = Vector2.new(0.5, 0),
				ZIndex = 2,
			}),
		Star = info.star and e(Text, {
			Text = "★",
			Size = UDim2.fromOffset(34, 34),
			Position = UDim2.fromOffset(4, 2),
			Gradient = RewardsText.Gold,
			StrokeThickness = 2.5,
			ZIndex = 3,
		}),
		Name = e(Text, {
			Text = info.name,
			Size = UDim2.new(1, -12, 0, 24),
			Position = UDim2.new(0.5, 0, 0, 110),
			AnchorPoint = Vector2.new(0.5, 0),
			StrokeThickness = 2,
			MaxTextSize = 20,
			ZIndex = 2,
		}),
		Chance = e(Text, {
			Text = info.chance,
			Size = UDim2.new(1, -12, 0, 24),
			Position = UDim2.new(0.5, 0, 0, 136),
			AnchorPoint = Vector2.new(0.5, 0),
			Color = info.color,
			StrokeThickness = 2,
			MaxTextSize = 22,
			ZIndex = 2,
		}),
	})
end

-- A titled group of tiles: "LEGENDARY  1.8%" over its towers.
local function Section(props: { Title: string, Right: string?, Color: Color3?, Tiles: { TileInfo }, LayoutOrder: number })
	-- The scrolling list is 6 px narrower than its box and padded 16 + 16 + SCROLLBAR.
	local columns = math.max(1, math.floor((LIST_WIDTH - 6 - 32 - SCROLLBAR + TILE_GAP) / (TILE.X + TILE_GAP)))
	local rows = math.ceil(#props.Tiles / columns)
	local gridHeight = rows * TILE.Y + math.max(0, rows - 1) * TILE_GAP
	local tiles = {
		Grid = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(TILE.X, TILE.Y),
			CellPadding = UDim2.fromOffset(TILE_GAP, TILE_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, info in props.Tiles do
		tiles[info.key] = e(Tile, { Info = info, LayoutOrder = index })
	end
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 44 + gridHeight),
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
	}, {
		Title = e(Text, {
			Text = props.Title,
			Size = UDim2.new(0.7, 0, 0, 34),
			XAlignment = Enum.TextXAlignment.Left,
			Color = props.Color,
			StrokeThickness = 3,
			MaxTextSize = 30,
		}),
		Right = props.Right and e(Text, {
			Text = props.Right,
			Size = UDim2.new(0.3, 0, 0, 34),
			Position = UDim2.fromScale(1, 0),
			AnchorPoint = Vector2.new(1, 0),
			XAlignment = Enum.TextXAlignment.Right,
			Color = props.Color,
			StrokeThickness = 3,
			MaxTextSize = 30,
		}),
		Tiles = e("Frame", {
			Size = UDim2.new(1, 0, 0, gridHeight),
			Position = UDim2.fromOffset(0, 44),
			BackgroundTransparency = 1,
		}, tiles),
	})
end

type SectionInfo = { title: string, right: string?, color: Color3?, tiles: { TileInfo } }

local function towerSections(rarityOdds: { Banners.RarityOdds }, featuredId: string?): { SectionInfo }
	local sections = {}
	for _, odds in rarityOdds do
		local color = useSummon.color(odds.rarity)
		local tiles = {}
		for _, entry in odds.towers do
			local config = TowersConfig[entry.towerId]
			table.insert(tiles, {
				key = entry.towerId,
				image = config and config.Icon,
				name = if config then config.DisplayName else entry.towerId,
				chance = percent(entry.chance),
				color = color,
				star = entry.towerId == featuredId,
			})
		end
		table.insert(sections, { title = string.upper(odds.rarity), right = percent(odds.chance), color = color, tiles = tiles })
	end
	return sections
end

local function range(values: { number }): string
	if values[1] == values[2] then
		return formatNumber(values[1])
	end
	return `{formatNumber(values[1])}-{formatNumber(values[2])}`
end

-- Coins, gems and items of a chest (everything but the tower).
local function chestExtras(chest: ChestsConfig.Chest): SectionInfo?
	local tiles = {}
	if chest.Coins then
		table.insert(tiles, { key = "Coins", art = RewardsArt.Icons.Coins, name = `{range(chest.Coins)} coins`, chance = "100%", color = RewardsText.GoldColor })
	end
	if chest.Gems then
		table.insert(tiles, { key = "Gems", art = RewardsArt.Icons.Gems, name = `{range(chest.Gems)} gems`, chance = "100%", color = GEM_COLOR })
	end
	-- Equal rolls are added up into one tile per item (the Royal chest's three boost rolls).
	local items: { [string]: TileInfo } = {}
	local order: { string } = {}
	local counts: { [string]: number } = {}
	for _, roll in chest.Items or {} do
		local pool = if roll.Id then { roll.Id } else roll.Pool or {}
		for _, itemId in pool do
			local chance = roll.Chance / #pool
			local config = ItemsConfig[itemId]
			if not items[itemId] then
				table.insert(order, itemId)
				items[itemId] = {
					key = "Item" .. itemId,
					image = config and config.Icon,
					name = if config then config.Name else itemId,
					chance = "",
					color = ITEM_COLOR,
				}
				counts[itemId] = 0
			end
			local info = items[itemId]
			if chance >= 1 then
				counts[itemId] += roll.Count
			else
				info.chance = percent(chance)
			end
		end
	end
	for _, itemId in order do
		local info = items[itemId]
		if counts[itemId] > 0 then
			info.name = if counts[itemId] > 1 then `{counts[itemId]}x {info.name}` else info.name
			info.chance = if info.chance == "" then "100%" else info.chance
		end
		table.insert(tiles, info)
	end
	if #tiles == 0 then
		return nil
	end
	return { title = "INSIDE", right = "every chest", color = RewardsText.GoldColor, tiles = tiles }
end

-- Wide button: caption on the left, price (icon + amount) on the right.
local function ActionButton(props: {
	Kind: string, -- "Open" (green), "Coins" (yellow), "Gems" (blue)
	Label: string,
	Price: number?,
	Currency: string?,
	Affordable: boolean?,
	Disabled: boolean?,
	Size: Vector2,
	Position: Vector2,
	OnClick: () -> (),
})
	local art = if props.Kind == "Open" then RewardsArt.ButtonClaim elseif props.Kind == "Gems" then RewardsArt.TabInactive else RewardsArt.TabActive
	local stroke = if props.Kind == "Open" then Color3.fromRGB(16, 70, 8)
		elseif props.Kind == "Gems" then Color3.fromRGB(10, 30, 70)
		else Color3.fromRGB(110, 50, 0)
	local dim = props.Disabled or props.Affordable == false
	local hasPrice = props.Price ~= nil
	return e(ImageButton, {
		Art = art,
		Size = UDim2.fromOffset(props.Size.X, props.Size.Y),
		Position = UDim2.fromOffset(props.Position.X, props.Position.Y),
		HoverScale = if props.Disabled then 1 else 1.04,
		OnClick = if props.Disabled then nil else props.OnClick,
	}, {
		Label = e(Text, {
			Text = props.Label,
			Size = if hasPrice then UDim2.fromScale(0.46, 0.42) else UDim2.fromScale(0.86, 0.44),
			Position = if hasPrice then UDim2.fromScale(0.08, 0.47) else UDim2.fromScale(0.5, 0.47),
			AnchorPoint = if hasPrice then Vector2.new(0, 0.5) else Vector2.new(0.5, 0.5),
			XAlignment = if hasPrice then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			StrokeColor = stroke,
			StrokeThickness = 3,
			ZIndex = 2,
		}),
		Price = hasPrice and e("Frame", {
			Size = UDim2.fromScale(0.46, 0.56),
			Position = UDim2.fromScale(0.93, 0.47),
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Icon = e(RewardsArt.Icon, { Art = currencyIcon(props.Currency or "Coins"), Size = UDim2.fromOffset(42, 36), LayoutOrder = 1, ZIndex = 2 }),
			Amount = e(Text, {
				Text = formatNumber(props.Price :: number),
				TextSize = 32,
				Color = if props.Affordable == false then RED else nil,
				StrokeColor = stroke,
				StrokeThickness = 3,
				LayoutOrder = 2,
				ZIndex = 2,
			}),
		}),
		Dim = dim and e("Frame", {
			Size = UDim2.new(1, -8, 1, -12),
			Position = UDim2.fromScale(0.5, 0.47),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = if props.Disabled then 0.45 else 0.65,
			ZIndex = 3,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 22) }),
		}),
	})
end

local function PityRow(props: { Label: string, Left: number, Total: number, Color: Color3, LayoutOrder: number })
	local progress = math.clamp(1 - (props.Left - 1) / props.Total, 0, 1)
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 66),
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
	}, {
		Label = e(Text, {
			Text = props.Label,
			Size = UDim2.new(0.64, 0, 0, 28),
			XAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 26,
		}),
		Value = e(Text, {
			Text = if props.Left <= 1 then "NEXT!" else `in {props.Left}`,
			Size = UDim2.new(0.36, 0, 0, 28),
			Position = UDim2.fromScale(1, 0),
			AnchorPoint = Vector2.new(1, 0),
			XAlignment = Enum.TextXAlignment.Right,
			Color = props.Color,
			MaxTextSize = 26,
		}),
		Track = e("Frame", {
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.fromOffset(0, 38),
			BackgroundColor3 = Color3.fromRGB(10, 11, 18),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Fill = e("Frame", {
				Size = UDim2.fromScale(progress, 1),
				BackgroundColor3 = props.Color,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
		}),
	})
end

-- The player's coins or gems, on one line.
local function Wallet(props: { Currency: string, Amount: number, Position: Vector2 })
	return e("Frame", {
		Size = UDim2.fromOffset(SIDE_WIDTH, 44),
		Position = UDim2.fromOffset(props.Position.X, props.Position.Y),
		BackgroundTransparency = 1,
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
		Label = e(Text, { Text = "YOU HAVE", TextSize = 26, Color = RewardsText.MutedColor, StrokeThickness = 2, LayoutOrder = 1 }),
		Icon = e(RewardsArt.Icon, { Art = currencyIcon(props.Currency), Size = UDim2.fromOffset(44, 38), LayoutOrder = 2 }),
		Amount = e(Text, {
			Text = formatNumber(props.Amount),
			TextSize = 32,
			Gradient = if props.Currency == "Gems" then nil else RewardsText.Gold,
			Color = if props.Currency == "Gems" then GEM_COLOR else nil,
			StrokeThickness = 3,
			LayoutOrder = 3,
		}),
	})
end

local function CaseMenu(props: Props)
	local selected = props.Selected
	local snapshot = props.Snapshot
	local actions = props.Actions
	local popRef = React.useRef(nil :: UIScale?)
	local iconRef = React.useRef(nil :: GuiObject?)
	RewardsMotion.useEnter(popRef, { Scale = 0.85 }, { Scale = 1 }, POP)
	RewardsMotion.useLoop(iconRef, { Rotation = 5 }, ROCK)

	local sideX = PANEL.X - PAD - SIDE_WIDTH
	local name, info, rim, iconImage, iconArt, gold
	local sections: { SectionInfo } = {}
	local side = {}
	local owned = 0

	if selected.kind == "Banner" then
		local banner = Banners.ById[selected.id]
		local featured = Banners.Featured(banner, snapshot.now)
		local featuredConfig = featured and TowersConfig[featured.towerId]
		local pity = snapshot.pity[banner.id] or Banners.EmptyPity
		local balance = useSummon.balance(snapshot, banner.currency)
		name = banner.title
		info = if featuredConfig then `Featured: {featuredConfig.DisplayName}  ·  changes in {timeLeft(featured.endsAt - snapshot.now)}` else banner.subtitle
		rim = if featuredConfig then useSummon.color(featuredConfig.Rarity) else useSummon.color("Rare")
		iconImage = featuredConfig and featuredConfig.Icon
		iconArt = RewardsArt.Icons[banner.crate] or RewardsArt.Icons.Crate
		sections = towerSections(Banners.Odds(banner, featured and featured.towerId, 0), featured and featured.towerId)

		local topLeft = Banners.PullsToTop(banner, pity)
		local rows = {
			Layout = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 14),
				PaddingLeft = UDim.new(0, 18),
				PaddingRight = UDim.new(0, 18),
			}),
			Title = e(Text, {
				Text = "GUARANTEED",
				Size = UDim2.new(1, 0, 0, 30),
				LayoutOrder = 0,
				Color = RewardsText.MutedColor,
				MaxTextSize = 26,
			}),
			Epic = e(PityRow, {
				Label = "EPIC OR BETTER",
				Left = math.max(1, banner.epicPity - (pity.sinceEpic or 0)),
				Total = banner.epicPity,
				Color = useSummon.color("Epic"),
				LayoutOrder = 1,
			}),
			Top = topLeft and e(PityRow, {
				Label = if featured then "FEATURED TOWER" else `{string.upper(banner.topRarity or "")}+`,
				Left = topLeft,
				Total = banner.topPity or banner.featuredPity or 1,
				Color = if featuredConfig then useSummon.color(featuredConfig.Rarity) else useSummon.color(banner.topRarity),
				LayoutOrder = 2,
			}),
		}
		side.Pity = box({ Size = UDim2.fromOffset(SIDE_WIDTH, 216), Position = UDim2.fromOffset(sideX, BODY_TOP) }, rows)

		local counts = {}
		for _, count in Banners.PullCounts do
			if banner.costs[count] then
				table.insert(counts, count)
			end
		end
		local bottom = BODY_TOP + BODY_HEIGHT
		for index, count in counts do
			local price = banner.costs[count]
			side["Summon" .. count] = e(ActionButton, {
				Kind = if count > 1 then "Open" else banner.currency,
				Label = `SUMMON x{count}`,
				Price = price,
				Currency = banner.currency,
				Affordable = balance >= price,
				Disabled = props.Pending,
				Size = Vector2.new(SIDE_WIDTH, BUTTON_HEIGHT + 8),
				Position = Vector2.new(sideX, bottom - (#counts - index + 1) * (BUTTON_HEIGHT + 8 + BUTTON_GAP) + BUTTON_GAP),
				OnClick = function()
					props.OnSummon(count)
				end,
			})
		end
		side.Wallet = e(Wallet, {
			Currency = banner.currency,
			Amount = balance,
			Position = Vector2.new(sideX, bottom - #counts * (BUTTON_HEIGHT + 8 + BUTTON_GAP) - 50),
		})
	else
		local chest = ChestsConfig.Chests[selected.id]
		owned = actions.owned[selected.id] or 0
		name = chest.Name
		info = table.concat(chest.Lines, "  ·  ")
		rim = ChestsTab.Rim[chest.Rarity] or ChestsTab.Rim.Common
		iconImage = chest.Icon
		gold = chest.Robux ~= nil
		local extras = chestExtras(chest)
		if extras then
			table.insert(sections, extras)
		end
		local towers = towerSections(CaseOdds.chest(chest), nil)
		if #towers > 0 then
			table.insert(sections, { title = "ONE TOWER", color = RewardsText.MutedColor, tiles = {} })
			for _, section in towers do
				table.insert(sections, section)
			end
		end

		local y = BODY_TOP
		side.Owned = box({ Size = UDim2.fromOffset(SIDE_WIDTH, 96), Position = UDim2.fromOffset(sideX, y), Color = if owned > 0 then rim else nil }, {
			Label = e(Text, {
				Text = if owned > 0 then "YOU OWN" else "YOU OWN NONE",
				Size = UDim2.new(0.6, -20, 0, 36),
				Position = UDim2.new(0, 20, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				XAlignment = Enum.TextXAlignment.Left,
				Color = RewardsText.MutedColor,
				MaxTextSize = 30,
			}),
			Count = owned > 0 and e(Text, {
				Text = `x{owned}`,
				Size = UDim2.new(0.4, -20, 0, 56),
				Position = UDim2.new(1, -20, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				XAlignment = Enum.TextXAlignment.Right,
				Gradient = RewardsText.Gold,
				StrokeThickness = 4,
			}),
		})
		y += 96 + BUTTON_GAP + 4

		if owned > 0 then
			local multi = math.min(owned, MAX_OPEN)
			local half = (SIDE_WIDTH - BUTTON_GAP) / 2
			side.Open1 = e(ActionButton, {
				Kind = "Open",
				Label = "OPEN",
				Disabled = actions.busy,
				Size = Vector2.new(if multi > 1 then half else SIDE_WIDTH, BUTTON_HEIGHT),
				Position = Vector2.new(sideX, y),
				OnClick = function()
					actions.open(selected.id, 1)
				end,
			})
			side.OpenMany = multi > 1 and e(ActionButton, {
				Kind = "Open",
				Label = `OPEN x{multi}`,
				Disabled = actions.busy,
				Size = Vector2.new(half, BUTTON_HEIGHT),
				Position = Vector2.new(sideX + half + BUTTON_GAP, y),
				OnClick = function()
					actions.open(selected.id, multi)
				end,
			})
		else
			side.OpenHint = e(Text, {
				Text = if chest.Price then "Buy one to open it here" else "Get it from rewards to open it here",
				Size = UDim2.fromOffset(SIDE_WIDTH, 30),
				Position = UDim2.fromOffset(sideX, y + (BUTTON_HEIGHT - 30) / 2),
				Color = RewardsText.MutedColor,
				StrokeThickness = 2,
				MaxTextSize = 24,
			})
		end

		local bottom = BODY_TOP + BODY_HEIGHT
		if chest.Price then
			local currency = chest.Price.Currency
			local balance = useSummon.balance(snapshot, currency :: Banners.Currency)
			for index, count in CHEST_BUY_COUNTS do
				local price = chest.Price.Amount * count
				side["Buy" .. count] = e(ActionButton, {
					Kind = currency,
					Label = `BUY x{count}`,
					Price = price,
					Currency = currency,
					Affordable = balance >= price,
					Disabled = actions.busy,
					Size = Vector2.new(SIDE_WIDTH, BUTTON_HEIGHT),
					Position = Vector2.new(sideX, bottom - (#CHEST_BUY_COUNTS - index + 1) * (BUTTON_HEIGHT + BUTTON_GAP) + BUTTON_GAP),
					OnClick = function()
						actions.buy(selected.id, count)
					end,
				})
			end
			side.Wallet = e(Wallet, {
				Currency = currency,
				Amount = balance,
				Position = Vector2.new(sideX, bottom - #CHEST_BUY_COUNTS * (BUTTON_HEIGHT + BUTTON_GAP) - 50),
			})
		else
			-- Robux chests: not on sale yet.
			side.Robux = e(ActionButton, {
				Kind = "Coins",
				Label = `R$ {chest.Robux}  ·  SOON`,
				Disabled = true,
				Size = Vector2.new(SIDE_WIDTH, BUTTON_HEIGHT),
				Position = Vector2.new(sideX, bottom - BUTTON_HEIGHT),
				OnClick = function() end,
			})
		end
	end

	local list = {
		Layout = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 14) }),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 16),
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16 + SCROLLBAR),
		}),
	}
	for index, section in sections do
		list["Section" .. index] = e(Section, {
			Title = section.title,
			Right = section.right,
			Color = section.color,
			Tiles = section.tiles,
			LayoutOrder = index,
		})
	end

	return e("TextButton", {
		-- Dims the list; a click outside the menu closes it.
		Size = UDim2.new(1, 0, 1, -props.PanelTop),
		Position = UDim2.fromOffset(0, props.PanelTop),
		BackgroundColor3 = Color3.fromRGB(8, 8, 16),
		BackgroundTransparency = 0.3,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 30,
		[React.Event.Activated] = props.OnClose,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 40) }),
		Panel = e("TextButton", {
			Size = UDim2.fromOffset(PANEL.X, PANEL.Y),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = PANEL_COLOR,
			AutoButtonColor = false,
			Text = "",
		}, {
			Pop = e("UIScale", { ref = popRef, Scale = 1 }),
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 28) }),
			Stroke = e("UIStroke", { Color = rim, Thickness = 5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			Glow = e("Frame", {
				Size = UDim2.new(1, 0, 0, HEADER_HEIGHT + 40),
				BackgroundColor3 = rim,
				BackgroundTransparency = 0.8,
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 28) }),
				Gradient = e("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1) }),
			}),
			Icon = if iconImage
				then e("ImageLabel", {
					ref = iconRef,
					Image = iconImage,
					Size = UDim2.fromOffset(138, 138),
					Position = UDim2.fromOffset(PAD, 10),
					BackgroundTransparency = 1,
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = 2,
				})
				else e(RewardsArt.Icon, {
					ref = iconRef,
					Art = iconArt,
					Size = UDim2.fromOffset(138, 130),
					Position = UDim2.fromOffset(PAD, 14),
					ZIndex = 2,
				}),
			Owned = owned > 0 and e("Frame", {
				Size = UDim2.fromOffset(72, 42),
				Position = UDim2.fromOffset(PAD - 8, 8),
				BackgroundColor3 = Color3.fromRGB(220, 40, 50),
				ZIndex = 4,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
				Stroke = e("UIStroke", { Color = Color3.fromRGB(60, 8, 12), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				Label = e(Text, {
					Text = `x{owned}`,
					Size = UDim2.new(1, -10, 0, 30),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					StrokeThickness = 2.5,
					ZIndex = 5,
				}),
			}),
			Name = e(Text, {
				Text = name,
				Size = UDim2.new(1, -(PAD + 160 + CLOSE.X + 20), 0, 62),
				Position = UDim2.fromOffset(PAD + 160, 22),
				XAlignment = Enum.TextXAlignment.Left,
				Gradient = if gold then RewardsText.Gold else nil,
				StrokeThickness = 5,
				ZIndex = 2,
			}),
			Info = e(Text, {
				Text = props.Error or info,
				Size = UDim2.new(1, -(PAD + 160 + CLOSE.X + 20), 0, 32),
				Position = UDim2.fromOffset(PAD + 162, 94),
				XAlignment = Enum.TextXAlignment.Left,
				Color = if props.Error then RED else RewardsText.MutedColor,
				StrokeThickness = 2,
				MaxTextSize = 26,
				ZIndex = 2,
			}),
			Close = e(ImageButton, {
				Art = RewardsArt.ButtonClose,
				Size = UDim2.fromOffset(CLOSE.X, CLOSE.Y),
				Position = UDim2.fromOffset(PANEL.X + 16, -16),
				AnchorPoint = Vector2.new(1, 0),
				OnClick = props.OnClose,
			}),
			Rewards = box({
				Size = UDim2.fromOffset(LIST_WIDTH, BODY_HEIGHT),
				Position = UDim2.fromOffset(PAD, BODY_TOP),
			}, {
				List = e("ScrollingFrame", {
					Size = UDim2.new(1, -6, 1, -12),
					Position = UDim2.fromOffset(0, 6),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					CanvasSize = UDim2.new(),
					ScrollingDirection = Enum.ScrollingDirection.Y,
					ScrollBarThickness = SCROLLBAR,
					ScrollBarImageColor3 = Color3.fromRGB(255, 200, 80),
				}, list),
			}),
			Side = e(React.Fragment, nil, side),
		}),
	})
end

return CaseMenu
