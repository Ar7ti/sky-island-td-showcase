-- One unit in the Units window grid: rarity card (background, unit picture, frame) with the name,
-- loadout slot, price and copies owned. Authored in pixels for a UnitCard.Size cell.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local React = require(ReplicatedStorage.Packages.React)
local soundController = require(ReplicatedStorage.Shared.Features.Services.SoundController.soundController)
local RewardsText = require(ReplicatedStorage.Shared.Source.Features.App.Rewards.RewardsText)
local UnitsArt = require(script.Parent.UnitsArt)
local SlotBadge = require(script.Parent.SlotBadge)
local e = React.createElement
local Text = RewardsText.Component

local isTouch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local WIDTH = 226
local SIZE = Vector2.new(WIDTH, math.round(WIDTH / UnitsArt.CardAspect))
local BADGE_HEIGHT = 36
local BADGE_SLICE = BADGE_HEIGHT / 100 -- badge art is ~100 px tall
local SLOT_BADGE = 52

local HOVER_SCALE = 1.06
local HOVER_ANGLE = 4
local WOBBLE_SPEED = 4.5 -- radians/sec fed into sin(), controls wobble speed
local HOVER_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local UNHOVER_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Rotation/scale are applied to "Card", not to the cell: UIGridLayout manages the cell's
-- Position/Size every layout pass, so animating those fights the layout.
local activeHovers = setmetatable({}, { __mode = "k" })

local function stopHover(cell)
	local hover = activeHovers[cell]
	if not hover then
		return
	end
	hover.connection:Disconnect()
	hover.scaleTween:Cancel()
	activeHovers[cell] = nil
end

local function onHoverStart(cell)
	if isTouch then
		return
	end
	stopHover(cell)
	soundController:PlaySFX("MouseEnter")
	local card = cell:FindFirstChild("Card")
	local scale = card and card:FindFirstChildOfClass("UIScale")
	if not scale then
		return
	end
	local scaleTween = TweenService:Create(scale, HOVER_INFO, { Scale = HOVER_SCALE })
	scaleTween:Play()
	local startTime = os.clock()
	local connection = RunService.Heartbeat:Connect(function()
		if not card.Parent then
			stopHover(cell)
			return
		end
		card.Rotation = math.sin((os.clock() - startTime) * WOBBLE_SPEED) * HOVER_ANGLE
	end)
	activeHovers[cell] = { scaleTween = scaleTween, connection = connection }
end

local function onHoverEnd(cell)
	if isTouch then
		return
	end
	stopHover(cell)
	local card = cell:FindFirstChild("Card")
	if not card then
		return
	end
	local scale = card:FindFirstChildOfClass("UIScale")
	if scale then
		TweenService:Create(scale, UNHOVER_INFO, { Scale = 1 }):Play()
	end
	TweenService:Create(card, UNHOVER_INFO, { Rotation = 0 }):Play()
end

-- Dark pill (price / copies) that grows with its contents.
local function pill(art: UnitsArt.Sliced, order: number, children: any)
	children.Layout = e("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	})
	children.Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 10) })
	return e("ImageLabel", {
		Image = art.image,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = art.center,
		SliceScale = BADGE_SLICE,
		Size = UDim2.fromOffset(0, BADGE_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, children)
end

export type Props = {
	Config: any, -- TowersConfig entry
	Amount: number,
	EquippedSlot: number?,
	Selected: boolean,
	LayoutOrder: number,
	OnSelect: () -> (),
}

local function UnitCard(props: Props)
	local config = props.Config
	local background, frame = UnitsArt.CardImages(config.Rarity)
	return e("Frame", {
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
		[React.Event.MouseEnter] = onHoverStart,
		[React.Event.MouseLeave] = onHoverEnd,
	}, {
		Card = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, {
			UIScale = e("UIScale", { Scale = 1 }),
			Background = e(UnitsArt.CardLayer, { Image = background, ZIndex = 1 }),
			Unit = e("ImageLabel", {
				Size = UDim2.fromOffset(SIZE.X - 40, 172),
				Position = UDim2.fromOffset(20, 52),
				BackgroundTransparency = 1,
				Image = config.Icon,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 2,
			}),
			Frame = e(UnitsArt.CardLayer, { Image = frame, ZIndex = 3 }),
			Name = e(Text, {
				Text = config.DisplayName or "Unknown Unit",
				Size = UDim2.fromOffset(SIZE.X - 44, 32),
				Position = UDim2.fromOffset(22, 20),
				StrokeThickness = 2.5,
				ZIndex = 4,
			}),
			Badges = e("Frame", {
				Size = UDim2.fromOffset(SIZE.X - 16, 46),
				Position = UDim2.fromOffset(8, SIZE.Y - 66),
				BackgroundTransparency = 1,
				ZIndex = 4,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				Price = pill(UnitsArt.Price, 2, {
					Coin = e(UnitsArt.Icon, { Art = UnitsArt.Icons.Coin, Size = UDim2.fromOffset(24, 24), LayoutOrder = 1 }),
					Value = e(Text, { Text = `{config.Price}$`, TextSize = 22, StrokeThickness = 2, LayoutOrder = 2 }),
				}),
				-- Copies owned; duplicates are kept for upgrades later.
				Copies = props.Amount > 1 and pill(UnitsArt.Duplicate, 3, {
					Value = e(Text, { Text = `x{props.Amount}`, TextSize = 20, StrokeThickness = 2, LayoutOrder = 1 }),
				}),
			}),
			-- Loadout slot this unit is equipped in (= its hotkey in a match), on the card's left edge.
			Slot = props.EquippedSlot and e("Frame", {
				Size = UDim2.fromOffset(SLOT_BADGE, SLOT_BADGE + 18),
				Position = UDim2.fromOffset(4, 54),
				BackgroundTransparency = 1,
				Rotation = -8,
				ZIndex = 5,
			}, {
				Badge = e(SlotBadge, {
					Number = props.EquippedSlot,
					Size = SLOT_BADGE,
					ZIndex = 5,
				}),
				Label = e(Text, {
					Text = "SLOT",
					Size = UDim2.new(1, 8, 0, 18),
					Position = UDim2.fromScale(0.5, 1),
					AnchorPoint = Vector2.new(0.5, 1),
					Color = RewardsText.GoldColor,
					StrokeThickness = 2,
					ZIndex = 6,
				}),
			}),
			Check = props.Selected and e(UnitsArt.Icon, {
				Art = UnitsArt.Icons.SelectedCheck,
				Size = UDim2.fromOffset(44, 44),
				Position = UDim2.fromOffset(SIZE.X - 10, 12),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = 5,
			}),
			SelectButton = e("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 6,
				[React.Event.Activated] = props.OnSelect,
			}),
		}),
	})
end

return {
	Component = UnitCard,
	Size = SIZE,
}
