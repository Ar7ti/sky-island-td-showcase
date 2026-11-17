-- Items tab of the Towers window (the Bag): category chips, a grid of item cards and a details panel with
-- a Use button. Built from the same kit as the Units tab (UnitsArt). Items: Shared Items/ItemsConfig;
-- using one goes through SharedServer ItemsService (checked there). The Star Stone's button crafts one from
-- shards (TowersServices/TowerStars, ItemsService:CraftStarStone); it is listed as soon as there are shards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local React = require(ReplicatedStorage.Packages.React)
local Networker = require(ReplicatedStorage.Packages.Networker)
local ItemsConfig = require(ReplicatedStorage.Shared.Features.Services.Items.ItemsConfig)
local Boosts = require(ReplicatedStorage.Shared.Features.Services.Items.Boosts)
local TowerStars = require(ReplicatedStorage.Shared.Features.Services.TowersServices.TowerStars)
local soundController = require(ReplicatedStorage.Shared.Features.Services.SoundController.soundController)
local useDataValue = require(ReplicatedStorage.Shared.Source.Features.App.Common.useDataValue)
local usePressAnimation = require(ReplicatedStorage.Shared.Source.Features.App.Common.usePressAnimation)
local RewardsText = require(ReplicatedStorage.Shared.Source.Features.App.Rewards.RewardsText)
local UnitsArt = require(script.Parent.UnitsArt)
local e = React.createElement
local Text = RewardsText.Component

local CATEGORIES = { "All", "Boosts", "Upgrades" }
local COLUMNS = 3
local CELL = Vector2.new(214, 214) -- square item cards (the mockup), card art 9-sliced to fit
local CELL_GAP = Vector2.new(20, 22)
local INSET = 22
local BUTTON_HEIGHT = 66
local ACTIVE_COLOR = Color3.fromRGB(120, 240, 140)

export type Props = {
	ChipsFrame: Rect, -- where the search bar is on the Units tab
	GridFrame: Rect,
	DetailsFrame: Rect,
}

local networker
local function ask(method: string, ...: any): (boolean, string?)
	if not networker then
		networker = Networker.client.new("ItemsService", {})
	end
	local ok, result = pcall(networker.fetch, networker, method, ...)
	if not ok or type(result) ~= "table" then
		return false, "No answer from the server"
	end
	return result.ok == true, result.error
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Server time, ticking every second while the tab is open (boost timers).
local function useNow(): number
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
	return now
end

-- Glossy blue (selected) or dark navy pill, as in art/inventory/mockup.png. Exported for the side tabs.
local BLUE = { Color3.fromRGB(70, 170, 255), Color3.fromRGB(20, 90, 220) }
local DARK = { Color3.fromRGB(44, 52, 74), Color3.fromRGB(26, 31, 46) }
local function GlossFrame(props: { Selected: boolean, Radius: number, children: any? })
	local colors = if props.Selected then BLUE else DARK
	local children = props.children or {}
	children.Corner = e("UICorner", { CornerRadius = UDim.new(0, props.Radius) })
	children.Gradient = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(colors[1], colors[2]) })
	children.Stroke = e("UIStroke", {
		Color = if props.Selected then Color3.fromRGB(150, 220, 255) else Color3.fromRGB(70, 82, 112),
		Thickness = if props.Selected then 3 else 2.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	-- Gloss on the top half.
	children.Shine = e("Frame", {
		Size = UDim2.new(1, -12, 0.42, 0),
		Position = UDim2.fromOffset(6, 4),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = if props.Selected then 0.78 else 0.94,
		BorderSizePixel = 0,
	}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, math.max(props.Radius - 4, 2)) }) })
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, children)
end

local function Chip(props: { Label: string, Selected: boolean, Width: number, X: number, Height: number, OnClick: () -> () })
	local scaleRef, events = usePressAnimation(1.05, props.OnClick)
	local buttonProps = {
		Size = UDim2.fromOffset(props.Width, props.Height),
		Position = UDim2.fromOffset(props.X, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
	}
	for key, handler in events do
		buttonProps[key] = handler
	end
	return e("TextButton", buttonProps, {
		Scale = e("UIScale", { ref = scaleRef, Scale = 1 }),
		Body = e(GlossFrame, { Selected = props.Selected, Radius = 16 }, {
			Label = e(Text, {
				Text = props.Label,
				Size = UDim2.new(1, -30, 0, 30),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				StrokeThickness = 2.5,
				ZIndex = 2,
			}),
		}),
	})
end

local function ItemCard(props: { Id: string, Item: any, Count: number, Remaining: number, Selected: boolean, LayoutOrder: number, OnSelect: () -> () })
	local item = props.Item
	local background, frame = UnitsArt.CardImages(item.Rarity)
	local scaleRef = React.useRef(nil :: UIScale?)
	return e("Frame", {
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
		[React.Event.MouseEnter] = function()
			soundController:PlaySFX("MouseEnter")
			if scaleRef.current then
				TweenService:Create(scaleRef.current, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1.06 }):Play()
			end
		end,
		[React.Event.MouseLeave] = function()
			if scaleRef.current then
				TweenService:Create(scaleRef.current, TweenInfo.new(0.15), { Scale = 1 }):Play()
			end
		end,
	}, {
		Card = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, {
			Scale = e("UIScale", { ref = scaleRef, Scale = 1 }),
			Background = e(UnitsArt.FlexCardLayer, { Image = background, Sliced = false, SliceScale = 0.5, ZIndex = 1 }),
			Icon = e("ImageLabel", {
				Size = UDim2.fromOffset(CELL.X - 64, CELL.Y - 76),
				Position = UDim2.fromOffset(32, 52),
				BackgroundTransparency = 1,
				Image = item.Icon,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 2,
			}),
			Frame = e(UnitsArt.FlexCardLayer, { Image = frame, Sliced = true, SliceScale = 0.5, ZIndex = 3 }),
			Name = e(Text, {
				Text = item.Name,
				Size = UDim2.fromOffset(CELL.X - 40, 30),
				Position = UDim2.fromOffset(20, 16),
				StrokeThickness = 2.5,
				ZIndex = 4,
			}),
			-- Running boost: a green timer over the picture.
			Active = props.Remaining > 0 and e(UnitsArt.Panel, {
				Art = UnitsArt.Price,
				Size = UDim2.fromOffset(120, 34),
				Position = UDim2.fromOffset(18, CELL.Y - 18),
				AnchorPoint = Vector2.new(0, 1),
				SliceScale = 0.34,
				Color = Color3.fromRGB(150, 255, 170),
				ZIndex = 5,
			}, {
				Value = e(Text, {
					Text = clock(props.Remaining),
					Size = UDim2.new(1, -20, 0, 22),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Color = ACTIVE_COLOR,
					StrokeThickness = 2,
				}),
			}),
			Count = e(UnitsArt.Panel, {
				Art = UnitsArt.Duplicate,
				Size = UDim2.fromOffset(70, 38),
				Position = UDim2.fromOffset(CELL.X - 14, CELL.Y - 14),
				AnchorPoint = Vector2.new(1, 1),
				SliceScale = 0.38,
				ZIndex = 4,
			}, {
				Value = e(Text, {
					Text = `x{props.Count}`,
					Size = UDim2.new(1, -16, 0, 24),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					StrokeThickness = 2,
				}),
			}),
			Check = props.Selected and e(UnitsArt.Icon, {
				Art = UnitsArt.Icons.SelectedCheck,
				Size = UDim2.fromOffset(44, 44),
				Position = UDim2.fromOffset(CELL.X - 10, 12),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = 6,
			}),
			Select = e("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 7,
				[React.Event.Activated] = props.OnSelect,
			}),
		}),
	})
end

local function UseButton(props: { Label: string, Disabled: boolean, Width: number, Y: number, OnClick: () -> () })
	local scaleRef, events = usePressAnimation(if props.Disabled then 1 else 1.04, if props.Disabled then nil else props.OnClick)
	local buttonProps = {
		Size = UDim2.fromOffset(props.Width, BUTTON_HEIGHT),
		Position = UDim2.fromOffset(INSET, props.Y),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
	}
	for key, handler in events do
		buttonProps[key] = handler
	end
	return e("TextButton", buttonProps, {
		Body = e(UnitsArt.Panel, {
			Art = UnitsArt.Equip,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			SliceScale = 0.75,
			Color = if props.Disabled then Color3.fromRGB(85, 85, 85) else nil,
		}, {
			Scale = e("UIScale", { ref = scaleRef, Scale = 1 }),
			Label = e(Text, {
				Text = props.Label,
				Size = UDim2.new(1, -40, 0, 40),
				Position = UDim2.fromScale(0.5, 0.47),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Color = if props.Disabled then Color3.fromRGB(200, 200, 200) else nil,
				StrokeThickness = 3.5,
			}),
		}),
	})
end

local function statRow(label: string, value: string, y: number, width: number, color: Color3?)
	return e(UnitsArt.Panel, {
		Art = UnitsArt.StatRow,
		Size = UDim2.fromOffset(width, 36),
		Position = UDim2.fromOffset(INSET, y),
		SliceScale = 0.6,
	}, {
		Name = e(Text, {
			Text = label,
			Size = UDim2.new(0.55, -20, 0, 20),
			Position = UDim2.new(0, 18, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			XAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 2,
		}),
		Value = e(Text, {
			Text = value,
			Size = UDim2.new(0.45, -16, 0, 22),
			Position = UDim2.new(1, -14, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			XAlignment = Enum.TextXAlignment.Right,
			StrokeThickness = 2,
			Color = color,
		}),
	})
end

local function Details(props: { Id: string?, Item: any?, Count: number, Remaining: number, Shards: number, Frame: Rect, Status: string?, OnUse: () -> () })
	local item = props.Item
	local frame = props.Frame
	local inner = frame.Width - INSET * 2
	local accent = item and UnitsArt.RarityColors[item.Rarity] or UnitsArt.RarityColors.Common
	local buttonY = frame.Height - INSET - BUTTON_HEIGHT
	local scaleRef = React.useRef(nil)
	React.useEffect(function()
		local scale = scaleRef.current
		if not scale then
			return
		end
		scale.Scale = 0.96
		local tween = TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
		tween:Play()
		return function()
			tween:Cancel()
		end
	end, { props.Id })

	local isBoost = item and item.Kind == "Boost"
	local isCraft = props.Id == TowerStars.ITEM
	local craftPrice = TowerStars.SHARDS_PER_STONE
	local rows = {}
	if item then
		local y = buttonY - 46
		if isBoost then
			rows.Effect = statRow("Effect", `x{item.Multiplier} {item.Boost}`, y - 42, inner, Color3.fromRGB(157, 245, 189))
			rows.Duration = statRow("Duration", `{math.floor(item.Duration / 60)} min`, y, inner)
		else
			rows.Use = statRow("Used for", "Tower stars (Units)", if isCraft then y - 42 else y, inner, Color3.fromRGB(157, 245, 189))
			if isCraft then
				rows.Shards = statRow("Shards", `{props.Shards} / {craftPrice}`, y, inner, Color3.fromRGB(190, 150, 255))
			end
		end
	end
	local canUse = if isCraft then props.Shards >= craftPrice else (item ~= nil and isBoost and props.Count > 0)
	local label = if not item then "Pick an item"
		elseif isCraft then `Craft 1 · {craftPrice} Shards`
		elseif not isBoost then "Used in Units"
		elseif props.Count <= 0 then "None left"
		elseif props.Remaining > 0 then "Use (+15 min)"
		else "Use"

	return e(UnitsArt.Panel, {
		Art = UnitsArt.Details,
		Size = UDim2.fromOffset(frame.Width, frame.Height),
		Position = UDim2.fromOffset(frame.Min.X, frame.Min.Y),
		SliceScale = 1.2,
	}, {
		Content = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
		}, {
			Scale = e("UIScale", { ref = scaleRef }),
			Title = e(Text, {
				Text = if item then item.Name else "Your items",
				Size = UDim2.fromOffset(inner, 50),
				Position = UDim2.fromOffset(INSET, 16),
				StrokeThickness = 4,
			}),
			Rarity = e(UnitsArt.Panel, {
				Art = UnitsArt.Rarity,
				Size = UDim2.fromOffset(200, 40),
				Position = UDim2.fromOffset(frame.Width / 2, 72),
				AnchorPoint = Vector2.new(0.5, 0),
				SliceScale = 0.4,
			}, {
				Label = e(Text, {
					Text = if item then string.upper(item.Rarity) else "INVENTORY",
					Size = UDim2.new(1, -36, 0, 26),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Color = accent,
					StrokeThickness = 2,
				}),
			}),
			Icon = item and e("ImageLabel", {
				Size = UDim2.fromOffset(inner, 128),
				Position = UDim2.fromOffset(INSET, 120),
				BackgroundTransparency = 1,
				Image = item.Icon,
				ScaleType = Enum.ScaleType.Fit,
			}),
			Description = item and e(Text, {
				Text = item.Description,
				Size = UDim2.fromOffset(inner, 50),
				Position = UDim2.fromOffset(INSET, 256),
				Color = Color3.fromRGB(157, 245, 189),
				StrokeThickness = 2,
				MaxTextSize = 20,
			}),
			Hint = not item and e(Text, {
				Text = "Boosts and materials from quests, chests and the shop show up here.",
				Size = UDim2.fromOffset(inner - 20, 120),
				Position = UDim2.fromOffset(INSET + 10, 170),
				Color = RewardsText.MutedColor,
				StrokeThickness = 2,
			}),
			ActiveTimer = item and props.Remaining > 0 and e(UnitsArt.Panel, {
				Art = UnitsArt.Price,
				Size = UDim2.fromOffset(190, 36),
				Position = UDim2.fromOffset(frame.Width / 2, 316),
				AnchorPoint = Vector2.new(0.5, 0),
				SliceScale = 0.36,
				Color = Color3.fromRGB(150, 255, 170),
			}, {
				Value = e(Text, {
					Text = `Active {clock(props.Remaining)}`,
					Size = UDim2.new(1, -24, 0, 24),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Color = ACTIVE_COLOR,
					StrokeThickness = 2,
				}),
			}),
			Rows = e(React.Fragment, nil, rows),
			Status = props.Status and e(Text, {
				Text = props.Status,
				Size = UDim2.fromOffset(inner, 22),
				Position = UDim2.fromOffset(INSET, buttonY - 30),
				Color = Color3.fromRGB(255, 140, 140),
				StrokeThickness = 2,
				MaxTextSize = 18,
			}),
			Use = e(UseButton, {
				Label = label,
				Disabled = not canUse,
				Width = inner,
				Y = buttonY,
				OnClick = props.OnUse,
			}),
		}),
	})
end

local function ItemsView(props: Props)
	local bag = useDataValue("bag") or {}
	local boosts = useDataValue("boosts") or {}
	local shards = useDataValue("shards") or 0
	local now = useNow()
	local category, setCategory = React.useState("All")
	local selected, setSelected = React.useState(nil :: string?)
	local status, setStatus = React.useState(nil :: string?)

	-- Owned items (and running boosts even when none are left), in ItemsConfig order.
	local ids = {}
	for id, item in ItemsConfig do
		local owned = (bag[id] or 0) > 0
		local running = item.Kind == "Boost" and Boosts.Remaining(boosts, item.Boost, now) > 0
		local craftable = id == TowerStars.ITEM and shards > 0
		if (owned or running or craftable) and (category == "All" or item.Category == category) then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return ItemsConfig[a].Order < ItemsConfig[b].Order
	end)
	local shown = if selected and table.find(ids, selected) then selected else ids[1]
	local shownItem = shown and ItemsConfig[shown]
	local function remainingOf(id: string): number
		local item = ItemsConfig[id]
		return if item.Kind == "Boost" then Boosts.Remaining(boosts, item.Boost, now) else 0
	end

	local cards = {}
	for order, id in ids do
		cards[id] = e(ItemCard, {
			Id = id,
			Item = ItemsConfig[id],
			Count = bag[id] or 0,
			Remaining = remainingOf(id),
			Selected = id == shown,
			LayoutOrder = order,
			OnSelect = function()
				setSelected(id)
				setStatus(nil)
			end,
		})
	end
	local rows = math.ceil(#ids / COLUMNS)
	local canvasHeight = 24 + 16 + rows * CELL.Y + math.max(rows - 1, 0) * CELL_GAP.Y

	local chipsFrame = props.ChipsFrame
	local chipWidth = math.floor((chipsFrame.Width - 2 * 14) / #CATEGORIES)
	local chips = {}
	for index, name in CATEGORIES do
		chips[name] = e(Chip, {
			Label = name,
			Selected = name == category,
			Width = chipWidth,
			Height = chipsFrame.Height,
			X = (index - 1) * (chipWidth + 14),
			OnClick = function()
				setCategory(name)
			end,
		})
	end

	local grid = props.GridFrame
	return e(React.Fragment, nil, {
		Chips = e("Frame", {
			Size = UDim2.fromOffset(chipsFrame.Width, chipsFrame.Height),
			Position = UDim2.fromOffset(chipsFrame.Min.X, chipsFrame.Min.Y),
			BackgroundTransparency = 1,
		}, chips),
		Empty = #ids == 0 and e(Text, {
			Text = if category == "All" then "Your bag is empty. Quests and chests fill it!" else `No {string.lower(category)} yet`,
			Size = UDim2.fromOffset(grid.Width - 80, 60),
			Position = UDim2.fromOffset(grid.Min.X + grid.Width / 2, grid.Min.Y + grid.Height / 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Color = RewardsText.MutedColor,
		}),
		Grid = e("ScrollingFrame", {
			Size = UDim2.fromOffset(grid.Width, grid.Height),
			Position = UDim2.fromOffset(grid.Min.X, grid.Min.Y),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(0, canvasHeight),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarImageColor3 = Color3.fromRGB(120, 130, 155),
			ScrollBarThickness = 8,
			ClipsDescendants = true,
		}, {
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 24),
				PaddingBottom = UDim.new(0, 16),
				PaddingLeft = UDim.new(0, 20),
			}),
			Layout = e("UIGridLayout", {
				CellSize = UDim2.fromOffset(CELL.X, CELL.Y),
				CellPadding = UDim2.fromOffset(CELL_GAP.X, CELL_GAP.Y),
				FillDirectionMaxCells = COLUMNS,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Cards = e(React.Fragment, nil, cards),
		}),
		Details = e(Details, {
			Id = shown,
			Item = shownItem,
			Count = if shown then bag[shown] or 0 else 0,
			Remaining = if shown then remainingOf(shown) else 0,
			Shards = shards,
			Frame = props.DetailsFrame,
			Status = status,
			OnUse = function()
				if not shown then
					return
				end
				task.spawn(function()
					local ok, message
					if shown == TowerStars.ITEM then
						ok, message = ask("CraftStarStone", 1)
					else
						ok, message = ask("Use", shown)
					end
					if ok then
						soundController:PlaySFX("MaxUpgrade")
						setStatus(nil)
					else
						soundController:PlaySFX("ErrorSound")
						setStatus(message)
					end
				end)
			end,
		}),
	})
end

return {
	Component = ItemsView,
	GlossFrame = GlossFrame,
}
