-- "YOU GOT!" popup over the rewards window after a claim: one tile per granted item (coins, gems, a tower
-- framed in its rarity color, a Bag item, or a chest that went to the Crates window unopened).
-- Also shows what a chest gave when it is opened (Summon/ChestsTab).
-- The tiles pop in one after another, amounts count up, then the button appears.
-- Many items (level road "claim all"): coins and gems are added up, equal towers stacked (x2), the
-- tiles wrap into rows of COLUMNS and the whole popup shrinks to fit MAX_HEIGHT.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Common = ReplicatedStorage.Shared.Source.Features.App.Common
local ArtImage = require(Common.ArtImage)
local ImageButton = require(Common.ImageButton)
local TowersConfig = require(ReplicatedStorage.Shared.Features.Services.TowersServices.towersConfig)
local TowerRarities = require(ReplicatedStorage.Shared.Features.Services.TowersServices.towersRaritys)
local Rewards = require(ReplicatedStorage.Shared.Features.Services.Rewards.Rewards)
local ChestsConfig = require(ReplicatedStorage.Shared.Features.Services.Chests.ChestsConfig)
local ItemsConfig = require(ReplicatedStorage.Shared.Features.Services.Items.ItemsConfig)
local Ids = require(ReplicatedStorage.Shared.Source.Game.AssetsIds.Ids)
local RewardsArt = require(script.Parent.RewardsArt)
local RewardsText = require(script.Parent.RewardsText)
local useRewards = require(script.Parent.useRewards)
local RewardsMotion = require(script.Parent.RewardsMotion)
local e = React.createElement
local Text = RewardsText.Component

local SPIN = TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
local BREATHE = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local FADE = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FIRST_TILE = 0.25 -- s after the popup opens
local TILE_STAGGER = 0.18
local COUNT_TIME = 0.8
local TILE = Vector2.new(230, 270)
local GAP = 24
local COLUMNS = 5
local MAX_HEIGHT = 640 -- px the title, tiles and button may take before the popup shrinks
local MAX_STAGGER_TIME = 1.6 -- all tiles are in by then, however many there are
local TITLE_HEIGHT = 96
local SPACING = 40 -- between the title, the tiles and the button

export type Props = {
	Granted: { useRewards.Granted },
	OnClose: () -> (),
}

local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	return (text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local RARITY_COLORS = {
	Common = Color3.fromRGB(150, 236, 90),
	Rare = Color3.fromRGB(100, 202, 255),
	Epic = Color3.fromRGB(209, 146, 255),
	Legendary = Color3.fromRGB(255, 211, 70),
	Mythic = Color3.fromRGB(255, 150, 50),
}

local function describe(item: useRewards.Granted)
	if item.kind == "Chest" then
		local chest = item.crate and ChestsConfig.Chests[item.crate]
		local icon = chest and chest.Icon ~= "" and chest.Icon or Ids.Rewards.EpicChest
		return {
			image = icon,
			title = (if chest then chest.Name else "Chest") .. (if (item.count or 1) > 1 then ` x{item.count}` else ""),
			rare = true,
			subtitle = "Open it in Crates",
			color = chest and RARITY_COLORS[chest.Rarity] or RewardsText.GoldColor,
		}
	elseif item.kind == "Item" then
		local config = item.itemId and ItemsConfig[item.itemId]
		return {
			image = config and config.Icon,
			title = (if config then config.Name else "Item") .. (if (item.amount or 1) > 1 then ` x{item.amount}` else ""),
			rare = true,
			subtitle = if config and config.Kind == "Boost" then "Boost · in your Bag" else "In your Bag",
			color = config and RARITY_COLORS[config.Rarity] or RewardsText.GoldColor,
		}
	end
	if item.kind == "Tower" then
		local config = item.towerId and TowersConfig[item.towerId]
		local rarity = config and TowerRarities[config.Rarity]
		return {
			image = config and config.Icon,
			title = (if config then config.DisplayName else tostring(item.towerId))
				.. (if (item.count or 1) > 1 then ` x{item.count}` else ""),
			rare = true,
			-- A duplicate of a fully starred tower never reaches the inventory: it became shards.
			subtitle = if item.shards then `Duplicate → +{item.shards} Shards`
				elseif config then config.Rarity
				else "Tower",
			color = rarity and rarity.UIShadowColor or RewardsText.GoldColor,
			from = item.crate and ((ChestsConfig.Chests[item.crate] and ChestsConfig.Chests[item.crate].Name)
				or (Rewards.Crates[item.crate] and Rewards.Crates[item.crate].name)),
		}
	end
	return {
		art = if item.kind == "Gems" then RewardsArt.Icons.Gems else RewardsArt.Icons.Coins,
		amount = item.amount or 0,
		title = "+" .. formatNumber(item.amount or 0),
		subtitle = item.kind,
		color = if item.kind == "Gems" then Color3.fromRGB(80, 190, 255) else RewardsText.GoldColor,
	}
end

-- Coins and gems summed into one tile each, the same tower stacked into one tile with a count.
local function merge(granted: { useRewards.Granted }): { useRewards.Granted }
	local merged: { useRewards.Granted } = {}
	local byKey: { [string]: useRewards.Granted } = {}
	for _, item in granted do
		local key = if item.kind == "Tower" then "Tower:" .. tostring(item.towerId)
			elseif item.kind == "Chest" then "Chest:" .. tostring(item.crate)
			elseif item.kind == "Item" then "Item:" .. tostring(item.itemId)
			else item.kind
		local existing = byKey[key]
		if not existing then
			local copy = table.clone(item)
			copy.count = 1
			byKey[key] = copy
			table.insert(merged, copy)
		elseif item.kind == "Tower" or item.kind == "Chest" then
			existing.count = (existing.count or 1) + 1
			if item.shards then
				existing.shards = (existing.shards or 0) + item.shards
			end
			if existing.crate ~= item.crate then
				existing.crate = nil -- from different crates: don't name one
			end
		else
			existing.amount = (existing.amount or 0) + (item.amount or 0)
		end
	end
	return merged
end

local function pop(delay: number): TweenInfo
	return TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay)
end

local function Tile(props: { Item: useRewards.Granted, LayoutOrder: number, Delay: number })
	local info = describe(props.Item)
	local scaleRef = React.useRef(nil :: UIScale?)
	local strokeRef = React.useRef(nil :: UIStroke?)
	RewardsMotion.useEnter(scaleRef, { Scale = 0 }, { Scale = 1 }, pop(props.Delay))
	-- Towers glow in their rarity color.
	RewardsMotion.useLoop(strokeRef, { Thickness = 9 }, BREATHE, info.rare == true)
	local counted = RewardsMotion.useCountUp(info.amount or 0, COUNT_TIME, props.Delay + 0.15)

	return e("Frame", {
		Size = UDim2.fromOffset(TILE.X, TILE.Y),
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
	}, {
		-- Centered, so the pop grows from the middle of the tile.
		Body = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(30, 33, 46),
		}, {
			Scale = e("UIScale", { ref = scaleRef, Scale = 1 }),
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 22) }),
			Stroke = e("UIStroke", {
				ref = strokeRef,
				Color = info.color,
				Thickness = 5,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			From = info.from and e(Text, {
				Text = info.from,
				Size = UDim2.new(1, -24, 0, 30),
				Position = UDim2.fromOffset(12, 10),
				Color = RewardsText.MutedColor,
			}),
			Art = if info.art
				then e(RewardsArt.Icon, {
					Art = info.art,
					Size = UDim2.fromOffset(150, 110),
					Position = UDim2.fromOffset(TILE.X / 2, 98),
					AnchorPoint = Vector2.new(0.5, 0.5),
				})
				else e("ImageLabel", {
					Image = info.image or "",
					Size = UDim2.fromOffset(120, 120),
					Position = UDim2.fromOffset(TILE.X / 2, 100),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					ScaleType = Enum.ScaleType.Fit,
				}),
			Title = e(Text, {
				Text = if info.amount then "+" .. formatNumber(counted) else info.title,
				Size = UDim2.new(1, -24, 0, 46),
				Position = UDim2.new(0.5, 0, 1, -62),
				AnchorPoint = Vector2.new(0.5, 1),
				Color = info.color,
				StrokeThickness = 4,
			}),
			Subtitle = e(Text, {
				Text = info.subtitle,
				Size = UDim2.new(1, -24, 0, 32),
				Position = UDim2.new(0.5, 0, 1, -18),
				AnchorPoint = Vector2.new(0.5, 1),
			}),
		}),
	})
end

local function RewardReveal(props: Props)
	local dimRef = React.useRef(nil :: TextButton?)
	local raysRef = React.useRef(nil :: ImageLabel?)
	local raysScaleRef = React.useRef(nil :: UIScale?)
	local titleRef = React.useRef(nil :: UIScale?)
	local titleBreatheRef = React.useRef(nil :: UIScale?)
	local buttonRef = React.useRef(nil :: UIScale?)
	local items = merge(props.Granted)
	local stagger = math.min(TILE_STAGGER, MAX_STAGGER_TIME / math.max(#items, 1))
	local buttonDelay = FIRST_TILE + #items * stagger + 0.2

	RewardsMotion.useEnter(dimRef, { BackgroundTransparency = 1 }, { BackgroundTransparency = 0.35 }, FADE)
	RewardsMotion.useEnter(raysScaleRef, { Scale = 0 }, { Scale = 1 }, pop(0.1))
	RewardsMotion.useLoop(raysRef, { Rotation = 360 }, SPIN)
	RewardsMotion.useEnter(titleRef, { Scale = 0 }, { Scale = 1 }, pop(0.05))
	RewardsMotion.useLoop(titleBreatheRef, { Scale = 1.06 }, BREATHE)
	RewardsMotion.useEnter(buttonRef, { Scale = 0 }, { Scale = 1 }, pop(buttonDelay))

	-- One horizontal row per COLUMNS tiles, rows stacked top to bottom.
	local rowCount = math.max(1, math.ceil(#items / COLUMNS))
	local tiles = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, GAP),
		}),
	}
	for row = 1, rowCount do
		local rowTiles = {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, GAP),
			}),
		}
		for index = (row - 1) * COLUMNS + 1, math.min(row * COLUMNS, #items) do
			rowTiles["Item" .. index] = e(Tile, {
				Item = items[index],
				LayoutOrder = index,
				Delay = FIRST_TILE + (index - 1) * stagger,
			})
		end
		tiles["Row" .. row] = e("Frame", {
			Size = UDim2.new(1, 0, 0, TILE.Y),
			LayoutOrder = row,
			BackgroundTransparency = 1,
		}, rowTiles)
	end
	local tilesHeight = rowCount * TILE.Y + (rowCount - 1) * GAP

	local button = ArtImage.sizeForWidth(RewardsArt.ButtonClaim, 300)
	local contentWidth = COLUMNS * TILE.X + (COLUMNS - 1) * GAP
	local contentHeight = TITLE_HEIGHT + SPACING + tilesHeight + SPACING + button.Y
	local fit = math.min(1, MAX_HEIGHT / contentHeight)
	return e("TextButton", {
		ref = dimRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 50,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 40) }),
		Rays = e(RewardsArt.Icon, {
			ref = raysRef,
			Art = RewardsArt.Icons.Sparkle,
			Size = UDim2.fromOffset(620, 620),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Transparency = 0.75,
		}, {
			Scale = e("UIScale", { ref = raysScaleRef, Scale = 1 }),
		}),
		Content = e("Frame", {
			Size = UDim2.fromOffset(contentWidth, contentHeight),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, {
			Fit = e("UIScale", { Scale = fit }),
			Title = e("Frame", {
				Size = UDim2.fromOffset(600, TITLE_HEIGHT),
				Position = UDim2.fromScale(0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
			}, {
				Pop = e("UIScale", { ref = titleRef, Scale = 1 }),
				Inner = e("Frame", {
					Size = UDim2.fromScale(1, 1),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
				}, {
					Breathe = e("UIScale", { ref = titleBreatheRef, Scale = 1 }),
					Text = e(Text, {
						Text = "YOU GOT!",
						Gradient = RewardsText.Gold,
						StrokeThickness = 5,
					}),
				}),
			}),
			Tiles = e("Frame", {
				Size = UDim2.new(1, 0, 0, tilesHeight),
				Position = UDim2.fromOffset(0, TITLE_HEIGHT + SPACING),
				BackgroundTransparency = 1,
			}, tiles),
			Collect = e("Frame", {
				Size = UDim2.fromOffset(button.X, button.Y),
				Position = UDim2.fromScale(0.5, 1),
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
			}, {
				Pop = e("UIScale", { ref = buttonRef, Scale = 1 }),
				Button = e(ImageButton, {
					Art = RewardsArt.ButtonClaim,
					Size = UDim2.fromScale(1, 1),
					OnClick = props.OnClose,
				}, {
					Label = e(Text, {
						Text = "AWESOME!",
						Size = UDim2.fromScale(0.7, 0.55),
						Position = UDim2.fromScale(0.5, 0.48),
						AnchorPoint = Vector2.new(0.5, 0.5),
						StrokeColor = Color3.fromRGB(16, 70, 8),
					}),
				}),
			}),
		}),
	})
end

return RewardReveal
