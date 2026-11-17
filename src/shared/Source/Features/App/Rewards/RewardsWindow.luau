-- Rewards window (Rewards button in the lobby): daily login rewards and playtime rewards.
-- Layout is authored in pixels for a WINDOW-sized box and scaled to fit the screen.
-- Claims go to RewardsService; what they grant is shown in the RewardReveal popup.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Common = ReplicatedStorage.Shared.Source.Features.App.Common
local ArtImage = require(Common.ArtImage)
local ImageButton = require(Common.ImageButton)
local soundController = require(ReplicatedStorage.Shared.Features.Services.SoundController.soundController)
local Rewards = require(ReplicatedStorage.Shared.Features.Services.Rewards.Rewards)
local RewardsArt = require(script.Parent.RewardsArt)
local RewardsText = require(script.Parent.RewardsText)
local RewardCard = require(script.Parent.RewardCard)
local RewardReveal = require(script.Parent.RewardReveal)
local useRewards = require(script.Parent.useRewards)
local RewardsMotion = require(script.Parent.RewardsMotion)
local e = React.createElement
local Text = RewardsText.Component

local WINDOW = Vector2.new(1320, 900)
local PANEL_TOP = 56
local PAD = 52
local CARD = Vector2.new(232, 226)
local CARD_GAP = 18
local GRID_TOP = 272
local GRID = Vector2.new(CARD.X * 3 + CARD_GAP * 2, CARD.Y * 2 + CARD_GAP)
local SPECIAL_LEFT = PAD + GRID.X + 24
local FOOTER_TOP = GRID_TOP + GRID.Y + 22
local FOOTER_HEIGHT = 96
local TAB = ArtImage.sizeForHeight(RewardsArt.TabActive, 86)
local HEADER = ArtImage.sizeForHeight(RewardsArt.HeaderBanner, 150)
local CLOSE = ArtImage.sizeForHeight(RewardsArt.ButtonClose, 104)
local SCREEN_FILL = Vector2.new(0.96, 0.92) -- largest share of the screen the window may take
local MAX_SCALE = 1.3
local OPEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local FADE_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local DIM_TRANSPARENCY = 0.45
local CARD_STAGGER = 0.05 -- s between cards popping in
local CARD_FIRST_DELAY = 0.12 -- lets the window pop open first
local WOBBLE = TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local FLICKER = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local TICK = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out, -1, true, 0.76)

type Tab = "Daily" | "Playtime"

local TABS: { { id: Tab, label: string, subtitle: string } } = {
	{ id = "Daily", label = "DAILY REWARDS", subtitle = "Come back daily for bigger rewards!" },
	{ id = "Playtime", label = "PLAYTIME", subtitle = "Play longer to unlock more rewards!" },
}

export type Props = {
	OnClose: () -> (),
}

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours, minutes, secs = seconds // 3600, seconds // 60 % 60, seconds % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%02d:%02d", minutes, secs)
end

local function milestoneTitle(minutes: number): string
	if minutes % 60 == 0 then
		local hours = minutes // 60
		return `{hours} HOUR{if hours == 1 then "" else "S"}`
	end
	return `{minutes} MIN`
end

type CardModel = { slot: Rewards.Slot, title: string, status: RewardCard.Status, hint: string?, claim: () -> () }

local function dailyCards(snapshot: useRewards.Snapshot, claim: (string, ...any) -> ()): { CardModel }
	local state = Rewards.dailyState(snapshot.save, snapshot.today)
	local cards = {}
	for day, slot in Rewards.Daily do
		local status: RewardCard.Status = if day <= state.claimedCount
			then "Claimed"
			elseif state.canClaim and day == state.nextDay then "Ready"
			else "Locked"
		table.insert(cards, {
			slot = slot,
			title = `DAY {day}`,
			status = status,
			hint = if status == "Locked" and not state.canClaim and day == state.nextDay then "TOMORROW" else nil,
			claim = function()
				claim("ClaimDaily")
			end,
		})
	end
	return cards
end

local function playtimeCards(snapshot: useRewards.Snapshot, claim: (string, ...any) -> ()): { CardModel }
	local cards = {}
	for index, slot in Rewards.Playtime do
		local left = slot.minutes * 60 - snapshot.playtime
		local status: RewardCard.Status = if Rewards.isPlaytimeClaimed(snapshot.save, snapshot.today, index)
			then "Claimed"
			elseif left <= 0 then "Ready"
			else "Locked"
		table.insert(cards, {
			slot = slot,
			title = milestoneTitle(slot.minutes),
			status = status,
			hint = if status == "Locked" then clock(left) else nil,
			claim = function()
				claim("ClaimPlaytime", index)
			end,
		})
	end
	return cards
end

-- Footer: what drives this tab on the left, when the next reward unlocks on the right.
local function footerInfo(tab: Tab, snapshot: useRewards.Snapshot)
	local untilTomorrow = clock(Rewards.secondsUntilNextDay(snapshot.now))
	if tab == "Daily" then
		local state = Rewards.dailyState(snapshot.save, snapshot.today)
		return {
			icon = RewardsArt.Icons.Streak,
			left = if state.streak > 0 then `{state.streak} DAY STREAK` else "START YOUR STREAK!",
			rightLabel = if state.canClaim then "Your reward is ready!" else "Next reward in",
			rightValue = if state.canClaim then nil else untilTomorrow,
		}
	end

	local nextLeft, anyReady = nil, false
	for index, slot in Rewards.Playtime do
		if Rewards.isPlaytimeClaimed(snapshot.save, snapshot.today, index) then
			continue
		end
		local left = slot.minutes * 60 - snapshot.playtime
		if left <= 0 then
			anyReady = true
		elseif not nextLeft or left < nextLeft then
			nextLeft = left
		end
	end
	return {
		icon = RewardsArt.Icons.Clock,
		left = `PLAYED TODAY  {clock(snapshot.playtime)}`,
		rightLabel = if anyReady then "Rewards ready to claim!" elseif nextLeft then "Next reward in" else "New rewards in",
		rightValue = if anyReady then nil elseif nextLeft then clock(nextLeft) else untilTomorrow,
	}
end

local function TabButton(props: { Label: string, Active: boolean, Badge: string?, Position: UDim2, OnClick: () -> () })
	return e(ImageButton, {
		Art = if props.Active then RewardsArt.TabActive else RewardsArt.TabInactive,
		Size = UDim2.fromOffset(TAB.X, TAB.Y),
		Position = props.Position,
		HoverScale = if props.Active then 1 else 1.04,
		Badge = props.Badge,
		OnClick = props.OnClick,
	}, {
		Label = e(Text, {
			Text = props.Label,
			Size = UDim2.fromScale(0.78, 0.46),
			Position = UDim2.fromScale(0.5, 0.48),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Color = if props.Active then nil else RewardsText.MutedColor,
			StrokeColor = if props.Active then Color3.fromRGB(110, 50, 0) else RewardsText.Stroke,
		}),
	})
end

local function Footer(props: { Info: any })
	local info = props.Info
	local half = (WINDOW.X - PAD * 2) / 2
	-- The flame flickers, the clock hand "ticks" once a second.
	local leftScaleRef = React.useRef(nil :: UIScale?)
	local clockRef = React.useRef(nil :: ImageLabel?)
	RewardsMotion.useLoop(leftScaleRef, { Scale = 1.12 }, FLICKER)
	RewardsMotion.useLoop(clockRef, { Rotation = 12 }, TICK)
	return e(RewardsArt.Panel, {
		Art = RewardsArt.Footer,
		Size = UDim2.fromOffset(WINDOW.X - PAD * 2 + 20, FOOTER_HEIGHT),
		Position = UDim2.fromOffset(PAD - 10, FOOTER_TOP),
	}, {
		Left = e("Frame", {
			Size = UDim2.new(0, half, 1, 0),
			BackgroundTransparency = 1,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 14),
			}),
			Icon = e(RewardsArt.Icon, { Art = info.icon, Size = UDim2.fromOffset(60, 66), LayoutOrder = 1 }, {
				Scale = e("UIScale", { ref = leftScaleRef, Scale = 1 }),
			}),
			Text = e(Text, { Text = info.left, TextSize = 44, Gradient = RewardsText.Fire, StrokeThickness = 4, LayoutOrder = 2 }),
		}),
		Divider = e("Frame", {
			Size = UDim2.new(0, 3, 0.5, 0),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
		}),
		Right = e("Frame", {
			Size = UDim2.new(0, half, 1, 0),
			Position = UDim2.fromScale(1, 0),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 14),
			}),
			Icon = e(RewardsArt.Icon, { ref = clockRef, Art = RewardsArt.Icons.Clock, Size = UDim2.fromOffset(62, 62), LayoutOrder = 1 }),
			Label = e(Text, {
				Text = info.rightLabel,
				TextSize = 36,
				Color = if info.rightValue then nil else RewardsText.GreenColor,
				LayoutOrder = 2,
			}),
			Value = info.rightValue and e(Text, {
				Text = info.rightValue,
				TextSize = 44,
				Gradient = RewardsText.Gold,
				StrokeThickness = 4,
				LayoutOrder = 3,
			}),
		}),
	})
end

local function RewardsWindow(props: Props)
	local snapshot = useRewards.use()
	local tab, setTab = React.useState("Daily" :: Tab)
	local pending, setPending = React.useState(false)
	local reveal, setReveal = React.useState(nil :: { useRewards.Granted }?)
	local fit, setFit = React.useState(1)
	local openRef = React.useRef(nil :: UIScale?)
	local dimRef = React.useRef(nil :: TextButton?)
	local giftRef = React.useRef(nil :: ImageLabel?)
	local mounted = React.useRef(true)
	local closing = React.useRef(false)

	RewardsMotion.useEnter(openRef, { Scale = 0.6 }, { Scale = 1 }, OPEN_INFO)
	RewardsMotion.useEnter(dimRef, { BackgroundTransparency = 1 }, { BackgroundTransparency = DIM_TRANSPARENCY }, FADE_INFO)
	RewardsMotion.useLoop(giftRef, { Rotation = 6 }, WOBBLE)
	React.useEffect(function()
		return function()
			mounted.current = false
		end
	end, {})

	-- Shrinks and fades out, then lets the parent unmount the window.
	local function close()
		if closing.current then
			return
		end
		closing.current = true
		RewardsMotion.play(openRef.current, nil, { Scale = 0.75 }, CLOSE_INFO)
		RewardsMotion.play(dimRef.current, nil, { BackgroundTransparency = 1 }, CLOSE_INFO)
		task.delay(CLOSE_INFO.Time, props.OnClose)
	end

	local function claim(method: string, ...: any)
		if pending then
			return
		end
		setPending(true)
		local args = table.pack(...)
		task.spawn(function()
			local result = useRewards.claim(method :: any, table.unpack(args, 1, args.n))
			if not mounted.current then
				return
			end
			setPending(false)
			if result.ok and result.granted then
				soundController:PlaySFX("LevelUp")
				setReveal(result.granted)
			else
				soundController:PlaySFX("ErrorSound")
			end
		end)
	end

	local cards = if tab == "Daily" then dailyCards(snapshot, claim) else playtimeCards(snapshot, claim)
	local subtitle = TABS[1].subtitle
	local tabButtons = {}
	for index, info in TABS do
		if info.id == tab then
			subtitle = info.subtitle
		end
		local list = if info.id == "Daily" then dailyCards(snapshot, claim) else playtimeCards(snapshot, claim)
		local ready = 0
		for _, card in list do
			if card.status == "Ready" then
				ready += 1
			end
		end
		tabButtons["Tab" .. info.id] = e(TabButton, {
			Label = info.label,
			Active = info.id == tab,
			Badge = if ready > 0 and info.id ~= tab then tostring(ready) else nil,
			Position = UDim2.fromOffset(PAD + 20 + (index - 1) * (TAB.X + 16), 168),
			OnClick = function()
				setTab(info.id)
			end,
		})
	end

	local grid = {}
	for index, card in cards do
		local isSpecial = index == #cards
		local column, row = (index - 1) % 3, (index - 1) // 3
		-- Keyed by tab, so switching tabs pops the new cards in.
		grid[tab .. index] = e(RewardCard, {
			Delay = CARD_FIRST_DELAY + (index - 1) * CARD_STAGGER,
			Covered = reveal ~= nil,
			Slot = card.slot,
			Title = card.title,
			Status = card.status,
			Hint = card.hint,
			Special = isSpecial,
			Pending = pending,
			OnClaim = card.claim,
			Size = if isSpecial
				then UDim2.fromOffset(WINDOW.X - PAD - SPECIAL_LEFT, GRID.Y)
				else UDim2.fromOffset(CARD.X, CARD.Y),
			Position = if isSpecial
				then UDim2.fromOffset(SPECIAL_LEFT, GRID_TOP)
				else UDim2.fromOffset(PAD + column * (CARD.X + CARD_GAP), GRID_TOP + row * (CARD.Y + CARD_GAP)),
		})
	end

	return e("TextButton", {
		-- Dims the game and closes the window when clicked outside it.
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = DIM_TRANSPARENCY,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 10,
		ref = dimRef,
		[React.Change.AbsoluteSize] = function(rbx: GuiObject)
			local size = rbx.AbsoluteSize
			setFit(math.min(size.X * SCREEN_FILL.X / WINDOW.X, size.Y * SCREEN_FILL.Y / WINDOW.Y, MAX_SCALE))
		end,
		[React.Event.Activated] = close,
	}, {
		Window = e("TextButton", {
			-- A button so clicks inside the window don't reach the dimmer behind it.
			Size = UDim2.fromOffset(WINDOW.X, WINDOW.Y),
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
				Open = e("UIScale", { ref = openRef, Scale = 1 }),
				Panel = e(RewardsArt.Panel, {
					Art = RewardsArt.Window,
					Size = UDim2.fromOffset(WINDOW.X, WINDOW.Y - PANEL_TOP),
					Position = UDim2.fromOffset(0, PANEL_TOP),
					SliceScale = 1.6,
				}),
				Header = e("Frame", {
					Size = UDim2.fromOffset(HEADER.X, HEADER.Y),
					Position = UDim2.fromOffset(PAD - 10, 0),
					BackgroundTransparency = 1,
					ZIndex = 2,
				}, {
					Banner = e(ArtImage.Image, { Art = RewardsArt.HeaderBanner }),
					Gift = e(RewardsArt.Icon, {
						ref = giftRef,
						Art = RewardsArt.Icons.Gift,
						Size = UDim2.fromOffset(150, 152),
						Position = UDim2.fromOffset(-14, HEADER.Y / 2 - 6),
						AnchorPoint = Vector2.new(0, 0.5),
						Rotation = -8,
						ZIndex = 3,
					}),
					Title = e(Text, {
						Text = "REWARDS",
						Size = UDim2.fromOffset(HEADER.X - 210, 72),
						Position = UDim2.fromOffset(150, 20),
						XAlignment = Enum.TextXAlignment.Left,
						StrokeThickness = 5,
						ZIndex = 3,
					}),
					Subtitle = e(Text, {
						Text = subtitle,
						Size = UDim2.fromOffset(HEADER.X - 200, 34),
						Position = UDim2.fromOffset(152, 94),
						XAlignment = Enum.TextXAlignment.Left,
						ZIndex = 3,
					}),
				}),
				Close = e(ImageButton, {
					Art = RewardsArt.ButtonClose,
					Size = UDim2.fromOffset(CLOSE.X, CLOSE.Y),
					Position = UDim2.fromOffset(WINDOW.X + 18, PANEL_TOP - 30),
					AnchorPoint = Vector2.new(1, 0),
					OnClick = close,
				}),
				Tabs = e(React.Fragment, nil, tabButtons),
				Grid = e(React.Fragment, nil, grid),
				Footer = e(Footer, { Info = footerInfo(tab, snapshot) }),
				Reveal = reveal and e("Frame", {
					Size = UDim2.new(1, 0, 1, -PANEL_TOP),
					Position = UDim2.fromOffset(0, PANEL_TOP),
					BackgroundTransparency = 1,
					ZIndex = 50,
				}, {
					Popup = e(RewardReveal, {
						Granted = reveal,
						OnClose = function()
							setReveal(nil)
						end,
					}),
				}),
			}),
		}),
	})
end

return RewardsWindow
