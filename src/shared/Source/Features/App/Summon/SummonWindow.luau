-- Crates window (Crates button in the lobby): CaseList, every case in a scrolling list (banners from Shared
-- Summon/Banners, chests kept from rewards or bought). Tapping a case opens CaseMenu over the list: every reward
-- it can drop and the only buy / open buttons (x1 and multi). Summons go to SummonService and are shown in the
-- SummonReveal popup, chests go through ChestsTab.useActions; closing a reveal comes back to the same menu.
-- Same art and layout rules as the rewards window: pixels for a WINDOW-sized box, scaled to fit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Common = ReplicatedStorage.Shared.Source.Features.App.Common
local ArtImage = require(Common.ArtImage)
local ImageButton = require(Common.ImageButton)
local soundController = require(ReplicatedStorage.Shared.Features.Services.SoundController.soundController)
local Banners = require(ReplicatedStorage.Shared.Features.Services.Summon.Banners)
local RewardsArt = require(ReplicatedStorage.Shared.Source.Features.App.Rewards.RewardsArt)
local RewardsText = require(ReplicatedStorage.Shared.Source.Features.App.Rewards.RewardsText)
local RewardsMotion = require(ReplicatedStorage.Shared.Source.Features.App.Rewards.RewardsMotion)
local SummonReveal = require(script.Parent.SummonReveal)
local useSummon = require(script.Parent.useSummon)
local ChestsTab = require(script.Parent.ChestsTab)
local CaseList = require(script.Parent.CaseList)
local CaseMenu = require(script.Parent.CaseMenu)
local CrateCinematic = require(script.Parent.CrateCinematic)
local e = React.createElement
local Text = RewardsText.Component

local WINDOW = Vector2.new(1320, 900)
local PANEL_TOP = 56
local PAD = 52
local LIST_TOP = 176
local LIST_BOTTOM = WINDOW.Y - 46
local HEADER = ArtImage.sizeForHeight(RewardsArt.HeaderBanner, 150)
local CLOSE = ArtImage.sizeForHeight(RewardsArt.ButtonClose, 104)
local SCREEN_FILL = Vector2.new(0.96, 0.92)
local MAX_SCALE = 1.3
local OPEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local FADE_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local DIM_TRANSPARENCY = 0.45
local ERROR_TIME = 2.5

export type Props = {
	OnClose: () -> (),
}

local function SummonWindow(props: Props)
	local snapshot = useSummon.use()
	-- The open case's menu: { kind = "Banner" | "Chest", id }; nil = only the list.
	local selected, setSelected = React.useState(nil :: CaseMenu.Selected?)
	local pending, setPending = React.useState(false)
	local reveal, setReveal =
		React.useState(nil :: { results: { useSummon.PullResult }, count: number, bannerId: string, skipIntro: boolean? }?)
	local errorText, setErrorText = React.useState(nil :: string?)
	local fit, setFit = React.useState(1)
	local openRef = React.useRef(nil :: UIScale?)
	local dimRef = React.useRef(nil :: TextButton?)
	local crateRef = React.useRef(nil :: ImageLabel?)
	local mounted = React.useRef(true)
	local closing = React.useRef(false)

	RewardsMotion.useEnter(openRef, { Scale = 0.6 }, { Scale = 1 }, OPEN_INFO)
	RewardsMotion.useEnter(dimRef, { BackgroundTransparency = 1 }, { BackgroundTransparency = DIM_TRANSPARENCY }, FADE_INFO)
	RewardsMotion.useLoop(crateRef, { Rotation = 6 }, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true))
	React.useEffect(function()
		-- The 3D opening's meshes and sky load while the player looks at the cases.
		task.spawn(CrateCinematic.preload)
		return function()
			mounted.current = false
		end
	end, {})
	React.useEffect(function()
		if not errorText then
			return
		end
		local thread = task.delay(ERROR_TIME, function()
			setErrorText(nil)
		end)
		return function()
			pcall(task.cancel, thread)
		end
	end, { errorText })

	-- Paid random banners are hidden where they aren't allowed (and while that is still unknown).
	local visible = {}
	for _, banner in Banners.List do
		if not banner.paidRandom or snapshot.paidRandomAllowed == true then
			table.insert(visible, banner)
		end
	end
	local chestActions = ChestsTab.useActions(setErrorText)
	-- A banner that became hidden closes its menu.
	local menu = selected
	if menu and menu.kind == "Banner" and not table.find(visible, Banners.ById[menu.id]) then
		menu = nil
	end

	local function close()
		if closing.current then
			return
		end
		closing.current = true
		RewardsMotion.play(openRef.current, nil, { Scale = 0.75 }, CLOSE_INFO)
		RewardsMotion.play(dimRef.current, nil, { BackgroundTransparency = 1 }, CLOSE_INFO)
		task.delay(CLOSE_INFO.Time, props.OnClose)
	end

	local function summon(count: number, summoned: Banners.Banner)
		if pending then
			return
		end
		if useSummon.balance(snapshot, summoned.currency) < (summoned.costs[count] or math.huge) then
			soundController:PlaySFX("ErrorSound")
			setErrorText(`Not enough {string.lower(summoned.currency)}!`)
			return
		end
		setPending(true)
		setErrorText(nil)
		local bannerId = summoned.id
		task.spawn(function()
			local result = useSummon.summon(bannerId, count)
			if not mounted.current then
				return
			end
			if result.ok and result.results and #result.results > 0 then
				soundController:PlaySFX("MoneySound")
				-- Banners with a 3D crate open it in the world first (yields), then the cards come straight away.
				local cinematic = CrateCinematic.supports(bannerId)
				if cinematic then
					CrateCinematic.play(bannerId, result.results)
					if not mounted.current then
						return
					end
				end
				setPending(false)
				setReveal({ results = result.results, count = count, bannerId = bannerId, skipIntro = cinematic })
			else
				setPending(false)
				soundController:PlaySFX("ErrorSound")
				setErrorText(result.error or "Something went wrong, try again")
			end
		end)
	end

	local function selectCase(kind: string, id: string)
		setSelected({ kind = kind, id = id })
		setErrorText(nil)
	end

	local again = nil
	local revealBanner = if reveal then Banners.ById[reveal.bannerId] else nil
	if reveal then
		local price = revealBanner.costs[reveal.count]
		if price and useSummon.balance(snapshot, revealBanner.currency) >= price then
			again = `SUMMON x{reveal.count}`
		end
	end
	-- Something is being opened or shown: a click on the dim around the window must not close it.
	local busy = reveal ~= nil or pending or chestActions.busy or chestActions.revealing

	return e("TextButton", {
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
		[React.Event.Activated] = function()
			if busy then
				return
			end
			-- Outside the window: the open menu closes first, then the window.
			if menu then
				setSelected(nil)
			else
				close()
			end
		end,
	}, {
		Window = e("TextButton", {
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
					Crate = e(RewardsArt.Icon, {
						ref = crateRef,
						Art = RewardsArt.Icons.EpicChest,
						Size = UDim2.fromOffset(150, 140),
						Position = UDim2.fromOffset(-14, HEADER.Y / 2 - 6),
						AnchorPoint = Vector2.new(0, 0.5),
						Rotation = -8,
						ZIndex = 3,
					}),
					Title = e(Text, {
						Text = "CRATES",
						Size = UDim2.fromOffset(HEADER.X - 210, 72),
						Position = UDim2.fromOffset(150, 20),
						XAlignment = Enum.TextXAlignment.Left,
						StrokeThickness = 5,
						ZIndex = 3,
					}),
					Subtitle = e(Text, {
						Text = "Tap a case to see what's inside and buy it.",
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
				List = e(CaseList, {
					Frame = Rect.new(PAD - 10, LIST_TOP, WINDOW.X - PAD + 10, LIST_BOTTOM),
					Banners = visible,
					Snapshot = snapshot,
					Actions = chestActions,
					OnSelectBanner = function(id: string)
						selectCase("Banner", id)
					end,
					OnSelectChest = function(id: string)
						selectCase("Chest", id)
					end,
				}),
				-- Keyed by case, so another case pops in fresh.
				Menu = menu and e(CaseMenu, {
					key = menu.kind .. menu.id,
					Selected = menu,
					Snapshot = snapshot,
					Actions = chestActions,
					Pending = pending,
					Error = errorText,
					PanelTop = PANEL_TOP,
					OnSummon = function(count: number)
						summon(count, Banners.ById[menu.id])
					end,
					OnClose = function()
						setSelected(nil)
						setErrorText(nil)
					end,
				}),
				ChestOverlays = chestActions.Overlays,
				Reveal = reveal and e("Frame", {
					Size = UDim2.new(1, 0, 1, -PANEL_TOP),
					Position = UDim2.fromOffset(0, PANEL_TOP),
					BackgroundTransparency = 1,
					ZIndex = 50,
				}, {
					-- A new key per summon, so "summon again" plays the opening from the start.
					Popup = e(SummonReveal, {
						key = tostring(reveal),
						Banner = revealBanner,
						Results = reveal.results,
						AgainLabel = again,
						SkipIntro = reveal.skipIntro,
						CaseId = reveal.bannerId,
						OnAgain = function()
							local count = reveal.count
							setReveal(nil)
							summon(count, revealBanner)
						end,
						OnClose = function()
							setReveal(nil)
						end,
					}),
				}),
			}),
		}),
	})
end

return SummonWindow
