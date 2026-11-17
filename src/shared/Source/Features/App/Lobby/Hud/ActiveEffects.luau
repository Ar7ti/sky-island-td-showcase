-- "ACTIVE EFFECTS" panel (art/hud/mockup.png): one tile per running boost from the Bag (Items/Boosts), with
-- its icon, name and time left; hidden while nothing runs. Lobby (bottom left) and match HUD.
-- Pixel sizes are 1080p; the parent ScaledGroup scales them. ActiveEffects.Measure(count) gives the size.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local React = require(ReplicatedStorage.Packages.React)
local ItemsConfig = require(ReplicatedStorage.Shared.Features.Services.Items.ItemsConfig)
local Boosts = require(ReplicatedStorage.Shared.Features.Services.Items.Boosts)
local Common = ReplicatedStorage.Shared.Source.Features.App.Common
local useDataValue = require(Common.useDataValue)
local RewardsText = require(ReplicatedStorage.Shared.Source.Features.App.Rewards.RewardsText)
local e = React.createElement
local Text = RewardsText.Component

local TILE = 92
local GAP = 10
local PAD = 10
local HEADER = 30
local MIN_WIDTH = 210 -- room for the "ACTIVE EFFECTS" header on one line
local OUTLINE = Color3.fromRGB(14, 16, 26)
local GOLD = { Color3.fromRGB(255, 222, 110), Color3.fromRGB(214, 140, 20) }

-- Rim and fill colors per boost.
local STYLE = {
	Coins = { Rim = Color3.fromRGB(255, 200, 60), Fill = { Color3.fromRGB(150, 100, 20), Color3.fromRGB(70, 44, 10) } },
	XP = { Rim = Color3.fromRGB(205, 130, 255), Fill = { Color3.fromRGB(110, 50, 170), Color3.fromRGB(50, 20, 90) } },
	Luck = { Rim = Color3.fromRGB(120, 240, 110), Fill = { Color3.fromRGB(40, 130, 50), Color3.fromRGB(18, 64, 26) } },
}

local ActiveEffects = {}

function ActiveEffects.Measure(count: number): Vector2
	local tiles = PAD * 2 + count * TILE + math.max(count - 1, 0) * GAP
	return Vector2.new(math.max(tiles, MIN_WIDTH), HEADER / 2 + PAD * 2 + TILE + 6)
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Running boosts, longest first: { itemId, boost, remaining }.
function ActiveEffects.Running(boosts: { [string]: number }?, now: number)
	local list = {}
	for id, item in ItemsConfig do
		if item.Kind == "Boost" and item.Boost then
			local remaining = Boosts.Remaining(boosts, item.Boost, now)
			if remaining > 0 then
				table.insert(list, { id = id, boost = item.Boost, remaining = remaining })
			end
		end
	end
	table.sort(list, function(a, b)
		return ItemsConfig[a.id].Order < ItemsConfig[b.id].Order
	end)
	return list
end

-- The running boosts, re-read every second (they end by time, not by a data change).
function ActiveEffects.useRunning()
	local boosts = useDataValue("boosts")
	local now, setNow = React.useState(Workspace:GetServerTimeNow())
	React.useEffect(function()
		local running = true
		task.spawn(function()
			while running do
				task.wait(1)
				if running then
					setNow(Workspace:GetServerTimeNow())
				end
			end
		end)
		return function()
			running = false
		end
	end, {})
	return ActiveEffects.Running(boosts, now)
end

local function Tile(props: { Id: string, Boost: string, Remaining: number, Index: number, Left: number })
	local item = ItemsConfig[props.Id]
	local style = STYLE[props.Boost] or STYLE.Coins
	local ending = props.Remaining <= 60
	return e("Frame", {
		Size = UDim2.fromOffset(TILE, TILE),
		Position = UDim2.fromOffset(props.Left + (props.Index - 1) * (TILE + GAP), HEADER / 2 + PAD),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
		Gradient = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(style.Fill[1], style.Fill[2]) }),
		Rim = e("UIStroke", { Color = style.Rim, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		Icon = e("ImageLabel", {
			Image = item.Icon,
			Size = UDim2.fromOffset(46, 46),
			Position = UDim2.new(0.5, 0, 0, 4),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
		}),
		Name = e(Text, {
			Text = item.Name,
			Size = UDim2.new(1, -8, 0, 18),
			Position = UDim2.new(0.5, 0, 0, 48),
			AnchorPoint = Vector2.new(0.5, 0),
			StrokeColor = OUTLINE,
			StrokeThickness = 2,
			ZIndex = 3,
		}),
		Timer = e("Frame", {
			Size = UDim2.new(1, -14, 0, 20),
			Position = UDim2.new(0.5, 0, 1, -5),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Color3.fromRGB(20, 22, 34),
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Label = e(Text, {
				Text = clock(props.Remaining),
				Size = UDim2.new(1, -8, 1, -4),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Color = if ending then Color3.fromRGB(255, 150, 150) else nil,
				StrokeColor = OUTLINE,
				StrokeThickness = 1.5,
				ZIndex = 4,
			}),
		}),
	})
end

-- props.Running: from ActiveEffects.useRunning() (the parent sizes the panel from its count).
function ActiveEffects.Component(props: { Running: { any } })
	local running = props.Running
	if #running == 0 then
		return nil
	end
	local size = ActiveEffects.Measure(#running)
	local tiles = {}
	-- Tiles centered (a single boost still gets the full-width panel).
	local tilesWidth = #running * TILE + (#running - 1) * GAP
	local left = (size.X - tilesWidth) / 2
	for index, entry in running do
		tiles[entry.id] = e(Tile, { Id = entry.id, Boost = entry.boost, Remaining = entry.remaining, Index = index, Left = left })
	end
	return e("Frame", {
		Size = UDim2.fromOffset(size.X, size.Y - HEADER / 2),
		Position = UDim2.fromOffset(0, HEADER / 2),
		BackgroundColor3 = Color3.fromRGB(24, 28, 42),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 18) }),
		Border = e("UIStroke", { Color = GOLD[1], Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		Header = e("Frame", {
			Size = UDim2.fromOffset(math.min(size.X - 24, 200), HEADER),
			Position = UDim2.new(0.5, 0, 0, -HEADER / 2 - 2),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 3,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Gradient = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(40, 42, 58), Color3.fromRGB(18, 20, 30)) }),
			Stroke = e("UIStroke", { Color = GOLD[1], Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			Label = e(Text, {
				Text = "ACTIVE EFFECTS",
				Size = UDim2.new(1, -16, 1, -8),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				StrokeColor = OUTLINE,
				StrokeThickness = 2,
				ZIndex = 4,
			}),
		}),
		Tiles = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(0, -HEADER / 2),
			BackgroundTransparency = 1,
		}, tiles),
	})
end

-- Match HUD: the panel in the bottom left corner (mouse screens only: on touch screens that corner is the
-- movement thumbstick, and the boosts were already seen in the lobby).
function ActiveEffects.MatchCorner()
	local ScaledGroup = require(Common.ScaledGroup)
	local useUiScale = require(Common.useUiScale)
	local IsTouch = require(Common.useIsTouch)
	local scale = useUiScale()
	local isTouch = IsTouch.use()
	local running = ActiveEffects.useRunning()
	if isTouch or #running == 0 then
		return nil
	end
	return e(ScaledGroup, {
		Scale = scale,
		Size = ActiveEffects.Measure(#running),
		Position = UDim2.new(0, 20, 1, -20),
		AnchorPoint = Vector2.new(0, 1),
	}, {
		Panel = e(ActiveEffects.Component, { Running = running }),
	})
end

return ActiveEffects
