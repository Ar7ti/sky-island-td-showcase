-- Match hotbar (bottom center): the towers of the loadout picked in the lobby, one slot each.
-- Clicking a slot or pressing its key (1, 2, ... from Loadout.Keys) starts placing that tower;
-- the same key again cancels placing. The key is shown in each card's corner. The player's level
-- bar sits under the hotbar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local React = require(ReplicatedStorage.Packages.React)
local Common = ReplicatedStorage.Shared.Source.Features.App.Common
local Theme = require(Common.Theme)
local OutlinedText = require(Common.OutlinedText)
local ScaledGroup = require(Common.ScaledGroup)
local useUiScale = require(Common.useUiScale)
local usePlayerAttribute = require(Common.usePlayerAttribute)
local usePressAnimation = require(Common.usePressAnimation)
local Currencies = require(ReplicatedStorage.Shared.Features.Services.Economy.Currencies)
local Loadout = require(ReplicatedStorage.Shared.Features.Services.TowersServices.Loadout)
local PlacementState = require(ReplicatedStorage.Shared.Features.Services.TowersServices.PlacementState)
local TowersConfig = require(ReplicatedStorage.Shared.Features.Services.TowersServices.towersConfig)
local soundController = require(ReplicatedStorage.Shared.Features.Services.SoundController.soundController)
local LevelBar = require(ReplicatedStorage.Shared.Source.Features.App.MatchHud.LevelBar)
local useLoadout = require(script.Parent.useLoadout)
local UnitsArt = require(script.Parent.UnitsArt)
local SlotBadge = require(script.Parent.SlotBadge)
local e = React.createElement

-- Pixels on a 1080p screen, scaled by useUiScale. Cards use the Units window's rarity art, cut to
-- a near-square so the bar is about as wide as the base health panel above.
local HotbarLayout = require(script.Parent.HotbarLayout)
local CARD = HotbarLayout.CARD
local CARD_SLICE = 0.28 -- corner size of the sliced card frame
local GAP = HotbarLayout.GAP
local PADDING = HotbarLayout.PADDING
local EDGE = HotbarLayout.EDGE
local LEVEL_GAP = HotbarLayout.LEVEL_GAP
local LEVEL_HEIGHT = HotbarLayout.LEVEL_HEIGHT
local KEY = 34
local PRICE_COLOR = Color3.fromRGB(255, 205, 50)
local NO_CASH_COLOR = Color3.fromRGB(255, 96, 96)

-- TowersPlacement (match client) listens to this and shows the placement preview.
local function startPlacing(towerId: string)
	local events = ReplicatedStorage:FindFirstChild("Events")
	local spawnEvent = events and events:FindFirstChild("TowerSpawn")
	if spawnEvent and spawnEvent:IsA("BindableEvent") then
		spawnEvent:Fire(towerId)
	end
end

local function Slot(props: {
	index: number,
	towerId: string?,
	active: boolean,
	affordable: boolean,
	OnClick: () -> (),
})
	local config = props.towerId and TowersConfig[props.towerId]
	local scaleRef, events = usePressAnimation(1.06, if config then props.OnClick else nil)

	local body
	if config then
		local background, frame = UnitsArt.CardImages(config.Rarity)
		body = {
			Background = e(UnitsArt.FlexCardLayer, { Image = background, Sliced = false, SliceScale = CARD_SLICE, ZIndex = 1 }),
			Unit = e("ImageLabel", {
				Size = UDim2.fromOffset(CARD.X - 24, CARD.Y * 0.64),
				Position = UDim2.fromOffset(12, CARD.Y * 0.08),
				BackgroundTransparency = 1,
				Image = config.Icon,
				ImageColor3 = if props.affordable then Color3.new(1, 1, 1) else Color3.fromRGB(150, 150, 150),
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 2,
			}),
			Frame = e(UnitsArt.FlexCardLayer, { Image = frame, Sliced = true, SliceScale = CARD_SLICE, ZIndex = 3 }),
			Price = e(OutlinedText, {
				Text = "$" .. config.Price,
				Size = UDim2.fromOffset(CARD.X - 24, CARD.Y * 0.23),
				Position = UDim2.new(0.5, 0, 1, -CARD.Y * 0.07),
				AnchorPoint = Vector2.new(0.5, 1),
				Color = if props.affordable then PRICE_COLOR else NO_CASH_COLOR,
				StrokeThickness = 2.5,
				ZIndex = 4,
			}),
			Check = props.active and e(UnitsArt.Icon, {
				Art = UnitsArt.Icons.SelectedCheck,
				Size = UDim2.fromOffset(28, 28),
				Position = UDim2.new(1, -4, 0, 6),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = 5,
			}),
		}
	else
		body = {
			Empty = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(22, 24, 32),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
				Stroke = e("UIStroke", { Color = Color3.fromRGB(70, 76, 95), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				Dash = e(OutlinedText, {
					Text = "-",
					Size = UDim2.fromScale(0.5, 0.4),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Color = Theme.TextMuted,
				}),
			}),
		}
	end
	body.Scale = e("UIScale", { ref = scaleRef, Scale = 1 })
	body.Key = e(SlotBadge, {
		Number = props.index,
		Size = KEY,
		Position = UDim2.fromOffset(-8, -8),
		Rotation = -6,
		Dimmed = config == nil,
		ZIndex = 5,
	})

	local buttonProps = {
		Size = UDim2.fromOffset(CARD.X, CARD.Y),
		LayoutOrder = props.index,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
	}
	for key, handler in events do
		buttonProps[key] = handler
	end
	-- The body is centered so the hover/press scale grows from the middle of the card.
	return e("TextButton", buttonProps, {
		Body = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, body),
	})
end

local function TowerHotbar()
	local loadout = useLoadout()
	local cash = usePlayerAttribute(Currencies.CashAttribute) or 0
	local scale = useUiScale()

	-- Tower whose preview is being placed, for the slot outline and the cancel-on-same-key toggle.
	local activeTower, setActiveTower = React.useState(nil :: string?)
	React.useEffect(function()
		return PlacementState.Subscribe(function(active)
			-- Switching towers ends the old preview right before the new one starts: only a placement
			-- that is still off a moment later really ended.
			if not active then
				task.defer(function()
					if not PlacementState.IsActive() then
						setActiveTower(nil)
					end
				end)
			end
		end)
	end, {})

	local slotsRef = React.useRef(loadout.slots)
	slotsRef.current = loadout.slots
	local activeRef = React.useRef(activeTower)
	activeRef.current = activeTower

	local selectTower = React.useCallback(function(towerId: string)
		if activeRef.current == towerId and PlacementState.IsActive() then
			PlacementState.Action("cancel")
			return
		end
		soundController:PlaySFX("leftBarClick")
		startPlacing(towerId)
		setActiveTower(towerId)
	end, {})

	React.useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input, processed)
			if processed or UserInputService:GetFocusedTextBox() then
				return
			end
			for index, key in Loadout.Keys do
				if input.KeyCode == key.KeyCode then
					local towerId = slotsRef.current[index]
					if towerId then
						selectTower(towerId)
					end
					return
				end
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	local count = loadout.unlocked
	local children = {
		List = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, GAP),
		}),
	}
	for index = 1, count do
		local towerId = loadout.slots[index]
		local config = towerId and TowersConfig[towerId]
		children["Slot" .. index] = e(Slot, {
			index = index,
			towerId = towerId,
			active = towerId ~= nil and towerId == activeTower,
			affordable = config ~= nil and cash >= config.Price,
			OnClick = function()
				if towerId then
					selectTower(towerId)
				end
			end,
		})
	end

	local size = HotbarLayout.size(count)
	local width, height = size.X, size.Y
	local panelHeight = CARD.Y + PADDING * 2

	return e(ScaledGroup, {
		Scale = scale,
		Size = Vector2.new(width, height),
		Position = UDim2.new(0.5, 0, 1, -EDGE),
		AnchorPoint = Vector2.new(0.5, 1),
	}, {
		Panel = e(UnitsArt.Panel, {
			Art = UnitsArt.Window,
			Size = UDim2.fromOffset(width, panelHeight),
			SliceScale = 0.6,
		}, children),
		Level = e(LevelBar, {
			Width = width,
			Height = LEVEL_HEIGHT,
			Position = UDim2.fromOffset(0, panelHeight + LEVEL_GAP),
		}),
	})
end

return TowerHotbar
