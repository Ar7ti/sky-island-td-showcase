local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local Data = require(ReplicatedStorage.Shared.Features.Services.DataService.Data).client
local TowersConfig = require(ReplicatedStorage.Shared.Features.Services.TowersServices.towersConfig)
local ImageButton = require(ReplicatedStorage.Shared.Source.Features.App.Common.ImageButton)
local RewardsText = require(ReplicatedStorage.Shared.Source.Features.App.Rewards.RewardsText)

local UnitsArt = require(script.Parent.UnitsArt)
local UnitCard = require(script.Parent.UnitCard)
local UnitPreview = require(script.Parent.UnitPreview)
local UnitFilters = require(script.Parent.UnitFilters)
local Catalog = require(script.Parent.UnitCatalog)
local Loadout = require(ReplicatedStorage.Shared.Features.Services.TowersServices.Loadout)
local Ids = require(ReplicatedStorage.Shared.Source.Game.AssetsIds.Ids)
local ItemsConfig = require(ReplicatedStorage.Shared.Features.Services.Items.ItemsConfig)
local ItemsView = require(script.Parent.ItemsView)
local useDataValue = require(ReplicatedStorage.Shared.Source.Features.App.Common.useDataValue)
local Networker = require(ReplicatedStorage.Packages.Networker)
local TowerStars = require(ReplicatedStorage.Shared.Features.Services.TowersServices.TowerStars)
local soundController = require(ReplicatedStorage.Shared.Features.Services.SoundController.soundController)

-- Lobby collection: every owned unit, with Equip/Unequip into the loadout under the Play button.
-- props.Loadout is useLoadout()'s state; props.PickSlot is the loadout slot being filled (opened from a slot click).
-- Layout is authored in pixels for a WINDOW-sized box and scaled to fit the screen; while open the
-- game behind is dimmed and blurred.

local e = React.createElement
local Text = RewardsText.Component

local WINDOW = Vector2.new(1280, 800)
local HEADER = Rect.new(30, 22, 530, 112)
local CLOSE = Vector2.new(88, 86)
local COUNTER = Rect.new(958, 34, 1148, 96)
local SEARCH = Rect.new(40, 130, 792, 194)
local SORT = Rect.new(816, 130, 1240, 194)
local GRID = Rect.new(34, 214, 798, 774)
local DETAILS = Rect.new(816, 214, 1240, 774)

local COLUMNS = 3
local CELL = UnitCard.Size
local CELL_GAP = Vector2.new(18, 36) -- rows leave room for the Mythic crown above the card
local GRID_TOP = 40
local GRID_BOTTOM = 16
local GRID_LEFT = 20

local SCREEN_FILL = Vector2.new(0.84, 0.88) -- largest share of the screen the window may take (side tabs stick out left)
local MAX_SCALE = 1.2
local DIM_TRANSPARENCY = 0.5
local BLUR_SIZE = 12
local OPEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local FADE_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SideTab = require(script.Parent.SideTab)
local LoadoutDock = require(script.Parent.LoadoutDock)

-- The loadout strip hangs under the window; the fitted box is the window plus the strip.
local DOCK_GAP = 14
local TOTAL = Vector2.new(WINDOW.X, WINDOW.Y + DOCK_GAP + LoadoutDock.Size.Y)

-- Star Up (spare copies, then Star Stones) and Salvage (spare copies -> shards) of a tower: the client only
-- asks, SharedServer ItemsService checks and does it. Returns ok, the error text and the whole answer.
local SHARDS = Rect.new(748, 34, 944, 96) -- shards balance, left of the counter
local SHARD_COLOR = Color3.fromRGB(190, 150, 255)
local itemsNetworker
local function askItems(method: string, ...: any): (boolean, string?, any)
	if not itemsNetworker then
		itemsNetworker = Networker.client.new("ItemsService", {})
	end
	local ok, result = pcall(itemsNetworker.fetch, itemsNetworker, method, ...)
	if not ok or type(result) ~= "table" then
		return false, "No answer from the server", nil
	end
	return result.ok == true, result.error, result
end

local function loadoutAction(loadout, pickSlot: number?, unitId: string, onClose: (() -> ())?): UnitPreview.Action
	local equippedSlot = Loadout.SlotOf(loadout.slots, unitId)
	if pickSlot and equippedSlot ~= pickSlot then
		return {
			Text = (if equippedSlot then "Move to slot " else "Equip to slot ") .. pickSlot,
			Kind = "Equip",
			OnClick = function()
				loadout.SetSlot(pickSlot, unitId)
				if onClose then
					onClose()
				end
			end,
		}
	elseif equippedSlot then
		local equippedCount = 0
		for index = 1, loadout.unlocked do
			if loadout.slots[index] then
				equippedCount += 1
			end
		end
		return {
			Text = if equippedCount > 1 then "Unequip" else "Last unit",
			Kind = "Unequip",
			Disabled = equippedCount <= 1,
			OnClick = function()
				loadout.SetSlot(equippedSlot, nil)
			end,
		}
	end
	local emptySlot = nil
	for index = 1, loadout.unlocked do
		if not loadout.slots[index] then
			emptySlot = index
			break
		end
	end
	return {
		Text = if emptySlot then "Equip" else "Pick a slot below",
		Kind = "Equip",
		Disabled = emptySlot == nil,
		OnClick = function()
			if emptySlot then
				loadout.SetSlot(emptySlot, unitId)
			end
		end,
	}
end

local function UnitsWindow(props)
	local isOpen = props.isOpen
	-- "Units" or "Items" (the Bag); opening the window to fill a loadout slot always shows Units.
	local tab, setTab = React.useState("Units")
	local showItems = tab == "Items" and not props.PickSlot
	local bag = useDataValue("bag") or {}
	local shards = useDataValue("shards") or 0
	local starStatus, setStarStatus = React.useState(nil :: string?)
	local starNotice, setStarNotice = React.useState(nil :: string?)
	local search, setSearch = React.useState("")
	local sortIndex, setSortIndex = React.useState(1)
	local selectedUnit, setSelectedUnit = React.useState(nil :: string?)
	local items, setItems = React.useState(Data.inventory() or {})
	local maxInventorySlots, setMaxInventorySlots = React.useState(Data.maxInventorySlots() or 10)
	local fit, setFit = React.useState(1)
	local scrollRef = React.useRef(nil)
	local dimRef = React.useRef(nil :: TextButton?)
	local openRef = React.useRef(nil :: UIScale?)
	local blurRef = React.useRef(nil :: BlurEffect?)

	React.useEffect(function()
		if scrollRef.current then
			scrollRef.current.CanvasPosition = Vector2.zero
		end
	end, { search, sortIndex })
	React.useEffect(function()
		local function refresh()
			setItems(table.clone(Data.inventory() or {}))
		end
		local unsubscribe = Data.inventory.Changed(refresh)
		refresh()
		return unsubscribe
	end, {})
	React.useEffect(function()
		local function refresh()
			setMaxInventorySlots(Data.maxInventorySlots() or 10)
		end
		local unsubscribe = Data.maxInventorySlots.Changed(refresh)
		refresh()
		return unsubscribe
	end, {})

	-- Blurs the game behind the window while it is mounted.
	React.useEffect(function()
		local blur = Instance.new("BlurEffect")
		blur.Name = "UnitsWindowBlur"
		blur.Size = 0
		blur.Parent = Lighting
		blurRef.current = blur
		return function()
			blurRef.current = nil
			blur:Destroy()
		end
	end, {})

	-- Pops in (and dims/blurs the game) when opened; plays out, then unmounts, when closed.
	React.useEffect(function()
		local scale, dim, blur = openRef.current, dimRef.current, blurRef.current
		if not (scale and dim and blur) then
			return
		end
		local tweens
		if isOpen then
			scale.Scale = 0.6
			tweens = {
				TweenService:Create(scale, OPEN_INFO, { Scale = 1 }),
				TweenService:Create(dim, FADE_INFO, { BackgroundTransparency = DIM_TRANSPARENCY }),
				TweenService:Create(blur, FADE_INFO, { Size = BLUR_SIZE }),
			}
		else
			tweens = {
				TweenService:Create(scale, CLOSE_INFO, { Scale = 0 }),
				TweenService:Create(dim, CLOSE_INFO, { BackgroundTransparency = 1 }),
				TweenService:Create(blur, CLOSE_INFO, { Size = 0 }),
			}
			tweens[1].Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed then
					props.OnClosed()
				end
			end)
		end
		for _, tween in tweens do
			tween:Play()
		end
		return function()
			for _, tween in tweens do
				tween:Cancel()
			end
		end
	end, { isOpen })

	local visibleIds, ownedCount = Catalog.GetVisible(items, TowersConfig, search, Catalog.Sorts[sortIndex])
	local function owns(unitId: string?)
		return unitId ~= nil and items[unitId] ~= nil and (items[unitId].Amount or 0) > 0 and TowersConfig[unitId] ~= nil
	end
	-- Shows the first unit until the player picks one.
	local shownUnit = if owns(selectedUnit) then selectedUnit else visibleIds[1]
	local shownConfig = if shownUnit then TowersConfig[shownUnit] else nil
	local loadout = props.Loadout
	local pickSlot = props.PickSlot
	local action = if shownUnit and loadout then loadoutAction(loadout, pickSlot, shownUnit, props.OnClose) else nil
	React.useEffect(function()
		setStarStatus(nil)
		setStarNotice(nil)
	end, { shownUnit })
	local stars: UnitPreview.Stars? = if shownUnit
		then {
			Level = TowerStars.LevelOf(items[shownUnit]),
			Stones = bag[TowerStars.ITEM] or 0,
			Duplicates = TowerStars.DuplicatesOf(items[shownUnit]),
			ShardsPerCopy = TowerStars.ShardsFor(shownConfig and shownConfig.Rarity),
			Status = starStatus,
			Notice = starNotice,
			OnStarUp = function()
				local unitId = shownUnit
				task.spawn(function()
					local ok, message = askItems("StarUp", unitId)
					soundController:PlaySFX(if ok then "MaxUpgrade" else "ErrorSound")
					setStarStatus(if ok then nil else message)
					setStarNotice(nil)
				end)
			end,
			OnSalvage = function(count: number)
				local unitId = shownUnit
				task.spawn(function()
					local ok, message, result = askItems("Salvage", unitId, count)
					soundController:PlaySFX(if ok then "MaxUpgrade" else "ErrorSound")
					setStarStatus(if ok then nil else message)
					setStarNotice(if ok then `Salvaged {result.salvaged} → +{result.shards} Shards` else nil)
				end)
			end,
		}
		else nil

	local cards = {}
	for order, unitId in visibleIds do
		local config = TowersConfig[unitId]
		cards[unitId] = e(UnitCard.Component, {
			Config = config,
			Amount = items[unitId].Amount or 0,
			EquippedSlot = loadout and Loadout.SlotOf(loadout.slots, unitId),
			Selected = unitId == shownUnit,
			LayoutOrder = order,
			OnSelect = function()
				setSelectedUnit(unitId)
			end,
		})
	end
	local rows = math.ceil(#visibleIds / COLUMNS)
	local canvasHeight = GRID_TOP + GRID_BOTTOM + rows * CELL.Y + math.max(rows - 1, 0) * CELL_GAP.Y

	return e("TextButton", {
		-- Dims the game and closes the window when clicked outside it.
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 10,
		ref = dimRef,
		[React.Change.AbsoluteSize] = function(rbx: GuiObject)
			local size = rbx.AbsoluteSize
			setFit(math.min(size.X * SCREEN_FILL.X / TOTAL.X, size.Y * SCREEN_FILL.Y / TOTAL.Y, MAX_SCALE))
		end,
		[React.Event.Activated] = function()
			if props.OnClose then
				props.OnClose()
			end
		end,
	}, {
		Window = e("TextButton", {
			-- A button so clicks inside the window don't reach the dimmer behind it.
			Size = UDim2.fromOffset(TOTAL.X, TOTAL.Y),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
		}, {
			Fit = e("UIScale", { Scale = fit }),
			Body = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
			}, {
				Open = e("UIScale", { ref = openRef, Scale = 0.6 }),
				Panel = e(UnitsArt.Panel, {
					Art = UnitsArt.Window,
					Size = UDim2.fromOffset(WINDOW.X, WINDOW.Y),
					SliceScale = 1.6,
				}),
				Dock = loadout and e(LoadoutDock.Component, {
					Slots = loadout.slots,
					Unlocked = loadout.unlocked,
					ShownUnit = if showItems then nil else shownUnit,
					PickSlot = pickSlot,
					Position = UDim2.fromScale(0.5, 1),
					AnchorPoint = Vector2.new(0.5, 1),
					OnEquip = function(slot, unitId)
						loadout.SetSlot(slot, unitId)
					end,
					OnRemove = function(slot)
						loadout.SetSlot(slot, nil)
					end,
				}),
				Header = e(UnitsArt.Panel, {
					Art = UnitsArt.Header,
					Size = UDim2.fromOffset(HEADER.Width, HEADER.Height),
					Position = UDim2.fromOffset(HEADER.Min.X, HEADER.Min.Y),
					SliceScale = 0.95,
				}, {
					Icon = if showItems and Ids.Inventory.TabItems ~= ""
						then e("ImageLabel", {
							Image = Ids.Inventory.TabItems,
							Size = UDim2.fromOffset(72, 64),
							Position = UDim2.new(0, 72, 0.5, 0),
							AnchorPoint = Vector2.new(0, 0.5),
							BackgroundTransparency = 1,
							ScaleType = Enum.ScaleType.Fit,
						})
						else e(UnitsArt.Icon, {
							Art = UnitsArt.Icons.Collection,
							Size = UDim2.fromOffset(72, 56),
							Position = UDim2.new(0, 72, 0.5, 0),
							AnchorPoint = Vector2.new(0, 0.5),
						}),
					Title = e(Text, {
						Text = if showItems then "Inventory" elseif pickSlot then `Units: slot {pickSlot}` else "Units",
						Size = UDim2.new(1, -230, 0, 60),
						Position = UDim2.new(0, 160, 0.5, 0),
						AnchorPoint = Vector2.new(0, 0.5),
						XAlignment = Enum.TextXAlignment.Left,
						StrokeThickness = 4,
					}),
				}),
				Counter = e(UnitsArt.Panel, {
					Art = UnitsArt.Counter,
					Size = UDim2.fromOffset(COUNTER.Width, COUNTER.Height),
					Position = UDim2.fromOffset(COUNTER.Min.X, COUNTER.Min.Y),
					SliceScale = 0.6,
				}, {
					Value = e(Text, {
						Text = if showItems then (function()
								local total = 0
								for itemId, count in bag do
									if ItemsConfig[itemId] then total += count end
								end
								return `{total} items`
							end)() else `{ownedCount} / {maxInventorySlots}`,
						Size = UDim2.new(1, -40, 0, 36),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						StrokeThickness = 3,
					}),
				}),
				-- Shards from salvaged duplicates (TowerStars): crafted into Star Stones in the Items tab.
				Shards = e(UnitsArt.Panel, {
					Art = UnitsArt.Counter,
					Size = UDim2.fromOffset(SHARDS.Width, SHARDS.Height),
					Position = UDim2.fromOffset(SHARDS.Min.X, SHARDS.Min.Y),
					SliceScale = 0.6,
				}, {
					Value = e(Text, {
						Text = `{shards} Shards`,
						Size = UDim2.new(1, -40, 0, 32),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Color = SHARD_COLOR,
						StrokeThickness = 3,
					}),
				}),
				Close = e(ImageButton, {
					Art = UnitsArt.CloseButton,
					Size = UDim2.fromOffset(CLOSE.X, CLOSE.Y),
					Position = UDim2.fromOffset(WINDOW.X - 26, 22),
					AnchorPoint = Vector2.new(1, 0),
					OnClick = props.OnClose,
				}, {
					X = e(UnitsArt.Icon, {
						Art = UnitsArt.Icons.CloseX,
						Size = UDim2.fromScale(0.52, 0.52),
						Position = UDim2.fromScale(0.5, 0.48),
						AnchorPoint = Vector2.new(0.5, 0.5),
					}),
				}),
				Tabs = not pickSlot and e("Frame", {
					Size = UDim2.fromOffset(0, WINDOW.Y),
					Position = UDim2.fromOffset(14, 0),
					BackgroundTransparency = 1,
					ZIndex = 0,
				}, {
					Units = e(SideTab, {
						Label = "Units",
						Icon = Ids.Inventory.TabUnits,
						FallbackArt = UnitsArt.Icons.Collection,
						Selected = not showItems,
						Index = 1,
						OnClick = function()
							setTab("Units")
						end,
					}),
					Items = e(SideTab, {
						Label = "Items",
						Icon = Ids.Inventory.TabItems,
						Selected = showItems,
						Index = 2,
						OnClick = function()
							setTab("Items")
						end,
					}),
				}),
				Bag = showItems and e(ItemsView.Component, {
					ChipsFrame = Rect.new(SEARCH.Min.X, SEARCH.Min.Y, SORT.Max.X, SORT.Max.Y),
					GridFrame = GRID,
					DetailsFrame = DETAILS,
				}),
				Filters = not showItems and e(UnitFilters, {
					Search = search,
					Sort = Catalog.Sorts[sortIndex],
					OnSearch = setSearch,
					OnSort = function()
						setSortIndex(sortIndex % #Catalog.Sorts + 1)
					end,
					SearchFrame = SEARCH,
					SortFrame = SORT,
				}),
				Empty = not showItems and #visibleIds == 0 and e(Text, {
					Text = "No units found",
					Size = UDim2.fromOffset(GRID.Width - 80, 44),
					Position = UDim2.fromOffset(GRID.Min.X + GRID.Width / 2, GRID.Min.Y + GRID.Height / 2),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Color = RewardsText.MutedColor,
				}),
				Grid = not showItems and e("ScrollingFrame", {
					ref = scrollRef,
					Size = UDim2.fromOffset(GRID.Width, GRID.Height),
					Position = UDim2.fromOffset(GRID.Min.X, GRID.Min.Y),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					CanvasSize = UDim2.fromOffset(0, canvasHeight),
					ScrollingDirection = Enum.ScrollingDirection.Y,
					ScrollBarImageColor3 = Color3.fromRGB(120, 130, 155),
					ScrollBarThickness = 8,
					ClipsDescendants = true,
				}, {
					Padding = e("UIPadding", {
						PaddingTop = UDim.new(0, GRID_TOP),
						PaddingBottom = UDim.new(0, GRID_BOTTOM),
						PaddingLeft = UDim.new(0, GRID_LEFT),
					}),
					Layout = e("UIGridLayout", {
						CellSize = UDim2.fromOffset(CELL.X, CELL.Y),
						CellPadding = UDim2.fromOffset(CELL_GAP.X, CELL_GAP.Y),
						FillDirectionMaxCells = COLUMNS,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					Cards = e(React.Fragment, nil, cards),
				}),
				Preview = not showItems and e(UnitPreview, {
					UnitId = shownUnit,
					Config = shownConfig,
					Action = action,
					Stars = stars,
					Frame = DETAILS,
				}),
			}),
		}),
	})
end

-- Keeps the window mounted while its close animation plays.
local function Units(props)
	local isMounted, setIsMounted = React.useState(props.isOpen)
	React.useEffect(function()
		if props.isOpen then
			setIsMounted(true)
		end
	end, { props.isOpen })

	if not (isMounted or props.isOpen) then
		return nil
	end
	return e(UnitsWindow, {
		isOpen = props.isOpen,
		Loadout = props.Loadout,
		PickSlot = props.PickSlot,
		OnClose = props.OnClose,
		OnClosed = function()
			setIsMounted(false)
		end,
	})
end

return Units
