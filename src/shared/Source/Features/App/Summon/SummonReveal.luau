-- Summon opening over the summon window: the banner's crate shakes while a glow in the best rolled
-- rarity's color grows, a white flash, then the tower cards pop in one after another
-- (one big card for x1, a 5x2 grid for x10). Clicking during the animation skips ahead.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Common = ReplicatedStorage.Shared.Source.Features.App.Common
local ArtImage = require(Common.ArtImage)
local ImageButton = require(Common.ImageButton)
local soundController = require(ReplicatedStorage.Shared.Features.Services.SoundController.soundController)
local CaseSounds = require(script.Parent.CaseSounds)
local TowersConfig = require(ReplicatedStorage.Shared.Features.Services.TowersServices.towersConfig)
local Banners = require(ReplicatedStorage.Shared.Features.Services.Summon.Banners)
local RewardsArt = require(ReplicatedStorage.Shared.Source.Features.App.Rewards.RewardsArt)
local RewardsText = require(ReplicatedStorage.Shared.Source.Features.App.Rewards.RewardsText)
local RewardsMotion = require(ReplicatedStorage.Shared.Source.Features.App.Rewards.RewardsMotion)
local useSummon = require(script.Parent.useSummon)
local e = React.createElement
local Text = RewardsText.Component

local SHAKE_TIME = 1.5
local FIRST_CARD = 0.15
local CARD_STAGGER = 0.14
local BIG_CARD = Vector2.new(320, 400)
local SMALL_CARD = Vector2.new(196, 250)
local COLUMNS = 5
local GAP = 18
local CONTENT_HEIGHT = 844 -- window height below the header (SummonWindow WINDOW.Y - PANEL_TOP)

local SHAKE = TweenInfo.new(0.06, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local GROW = TweenInfo.new(SHAKE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local SPIN = TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
local BREATHE = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local FLASH = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

export type Props = {
	Banner: Banners.Banner,
	Results: { useSummon.PullResult },
	AgainLabel: string?, -- "SUMMON x10 AGAIN"; nil hides the button (can't afford)
	SkipIntro: boolean?, -- the crate was already opened in 3D: start with the cards
	CaseId: string?, -- after a 3D opening the cards sound like that case (CaseSounds), not like the match
	OnAgain: () -> (),
	OnClose: () -> (),
}

local function bestRarity(results: { useSummon.PullResult }): string
	local best = "Common"
	for _, result in results do
		if Banners.Rank(result.rarity) > Banners.Rank(best) then
			best = result.rarity
		end
	end
	return best
end

local function pop(delay: number): TweenInfo
	return TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay)
end

local function Tag(props: { Text: string, Color: Color3, Position: UDim2, AnchorPoint: Vector2, Height: number })
	return e("Frame", {
		Size = UDim2.fromOffset(0, props.Height),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = props.Color,
		ZIndex = 4,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Stroke = e("UIStroke", { Color = RewardsText.Stroke, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
		Label = e(Text, { Text = props.Text, TextSize = props.Height - 8, StrokeThickness = 2, ZIndex = 5 }),
		Layout = e("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Center }),
	})
end

local function Card(props: { Result: useSummon.PullResult, Size: Vector2, Position: UDim2, Delay: number, CaseId: string? })
	local result = props.Result
	local config = TowersConfig[result.towerId]
	local color = useSummon.color(result.rarity)
	local shiny = Banners.Rank(result.rarity) >= Banners.Rank("Epic")
	local legendary = Banners.Rank(result.rarity) >= Banners.Rank("Legendary")
	local big = props.Size.X >= BIG_CARD.X
	local scaleRef = React.useRef(nil :: UIScale?)
	local bodyRef = React.useRef(nil :: Frame?)
	local strokeRef = React.useRef(nil :: UIStroke?)
	local raysRef = React.useRef(nil :: ImageLabel?)
	RewardsMotion.useEnter(scaleRef, { Scale = 0 }, { Scale = 1 }, pop(props.Delay))
	RewardsMotion.useEnter(bodyRef, { Rotation = -14 }, { Rotation = 0 }, pop(props.Delay))
	RewardsMotion.useLoop(strokeRef, { Thickness = if big then 12 else 9 }, BREATHE, shiny)
	RewardsMotion.useLoop(raysRef, { Rotation = 360 }, SPIN, legendary)

	React.useEffect(function()
		local thread = task.delay(props.Delay, function()
			local caseId = props.CaseId
			if caseId and CaseSounds.has(caseId, "card") then
				-- The case's own sounds (a softer card pop; its reveal chime for Legendary and up).
				CaseSounds.play(caseId, if legendary and CaseSounds.has(caseId, "best") then "best" else "card", nil, { volume = 0.8 })
			else
				soundController:PlaySFX(if legendary then "LevelUp" else "StarDing")
			end
		end)
		return function()
			pcall(task.cancel, thread)
		end
	end, {})

	local scale = props.Size.X / SMALL_CARD.X
	return e("Frame", {
		Size = UDim2.fromOffset(props.Size.X, props.Size.Y),
		Position = props.Position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	}, {
		Rays = legendary and e(RewardsArt.Icon, {
			ref = raysRef,
			Art = RewardsArt.Icons.Sparkle,
			Size = UDim2.fromOffset(props.Size.X * 1.6, props.Size.X * 1.6),
			Position = UDim2.fromScale(0.5, 0.45),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Color = color,
			Transparency = 0.4,
		}),
		Body = e("Frame", {
			ref = bodyRef,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 2,
		}, {
			Scale = e("UIScale", { ref = scaleRef, Scale = 1 }),
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 18 * scale) }),
			Gradient = e("UIGradient", {
				Color = ColorSequence.new(Color3.fromRGB(30, 33, 46), color:Lerp(Color3.fromRGB(30, 33, 46), 0.45)),
				Rotation = 90,
			}),
			Stroke = e("UIStroke", {
				ref = strokeRef,
				Color = color,
				Thickness = 5,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Badge = e(Tag, {
				Text = if result.isNew then "NEW!"
					elseif result.shards then `DUPLICATE → +{result.shards} SHARDS`
					else "DUPLICATE",
				Color = if result.isNew then Color3.fromRGB(80, 200, 60)
					elseif result.shards then Color3.fromRGB(120, 80, 200)
					else Color3.fromRGB(90, 96, 120),
				Position = UDim2.new(0.5, 0, 0, -14 * scale),
				AnchorPoint = Vector2.new(0.5, 0),
				Height = math.round(30 * scale),
			}),
			Icon = e("ImageLabel", {
				Image = if config then config.Icon else "",
				Size = UDim2.fromScale(0.82, 0.6),
				Position = UDim2.fromScale(0.5, 0.42),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 3,
			}),
			Featured = result.featured and e(Tag, {
				Text = "FEATURED",
				Color = Color3.fromRGB(235, 150, 20),
				Position = UDim2.fromScale(0.5, 0.71),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Height = math.round(24 * scale),
			}),
			Name = e(Text, {
				Text = if config then config.DisplayName else result.towerId,
				Size = UDim2.fromScale(0.9, 0.12),
				Position = UDim2.fromScale(0.5, 0.86),
				AnchorPoint = Vector2.new(0.5, 0.5),
				StrokeThickness = 3,
				ZIndex = 3,
			}),
			Rarity = e(Text, {
				Text = string.upper(result.rarity),
				Size = UDim2.fromScale(0.8, 0.08),
				Position = UDim2.fromScale(0.5, 0.95),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Color = color,
				StrokeThickness = 2,
				ZIndex = 3,
			}),
		}),
	})
end

local function Crate(props: { Banner: Banners.Banner, Color: Color3 })
	local crateRef = React.useRef(nil :: ImageLabel?)
	local crateScaleRef = React.useRef(nil :: UIScale?)
	local glowRef = React.useRef(nil :: ImageLabel?)
	local glowScaleRef = React.useRef(nil :: UIScale?)
	RewardsMotion.useLoop(crateRef, { Rotation = 7 }, SHAKE)
	RewardsMotion.useEnter(crateScaleRef, { Scale = 1 }, { Scale = 1.3 }, GROW)
	RewardsMotion.useLoop(glowRef, { Rotation = 360 }, SPIN)
	RewardsMotion.useEnter(glowScaleRef, { Scale = 0.3 }, { Scale = 1.4 }, GROW)
	RewardsMotion.useEnter(glowRef, { ImageTransparency = 0.9 }, { ImageTransparency = 0.1 }, GROW)

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Glow = e(RewardsArt.Icon, {
			ref = glowRef,
			Art = RewardsArt.Icons.Sparkle,
			Size = UDim2.fromOffset(640, 640),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Color = props.Color,
		}, {
			Scale = e("UIScale", { ref = glowScaleRef, Scale = 1 }),
		}),
		Crate = e(RewardsArt.Icon, {
			ref = crateRef,
			Art = RewardsArt.Icons[props.Banner.crate] or RewardsArt.Icons.Crate,
			Size = UDim2.fromOffset(300, 280),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 2,
		}, {
			Scale = e("UIScale", { ref = crateScaleRef, Scale = 1 }),
		}),
		Hint = e(Text, {
			Text = "Tap to skip",
			Size = UDim2.fromOffset(400, 34),
			Position = UDim2.new(0.5, 0, 1, -40),
			AnchorPoint = Vector2.new(0.5, 1),
			Color = RewardsText.MutedColor,
		}),
	})
end

local function SummonReveal(props: Props)
	local results = props.Results
	local best = bestRarity(results)
	local color = useSummon.color(best)
	-- After the 3D opening (CrateCinematic) the cards come straight away.
	local phase, setPhase = React.useState((if props.SkipIntro then "cards" else "crate") :: "crate" | "cards")
	local instant, setInstant = React.useState(false)
	local dimRef = React.useRef(nil :: TextButton?)
	local flashRef = React.useRef(nil :: Frame?)
	local titleRef = React.useRef(nil :: UIScale?)
	local buttonsRef = React.useRef(nil :: UIScale?)
	local cardsAt = React.useRef(if props.SkipIntro then os.clock() else 0)

	RewardsMotion.useEnter(dimRef, { BackgroundTransparency = 1 }, { BackgroundTransparency = 0.2 }, FADE)

	local function openCards()
		if phase ~= "crate" then
			return
		end
		setPhase("cards")
		cardsAt.current = os.clock()
		soundController:PlaySFX("TitleSlam")
		RewardsMotion.play(flashRef.current, { BackgroundTransparency = 0 }, { BackgroundTransparency = 1 }, FLASH)
	end

	React.useEffect(function()
		local thread = task.delay(SHAKE_TIME, openCards)
		return function()
			pcall(task.cancel, thread)
		end
	end, { phase })

	local lastDelay = if instant then 0 else FIRST_CARD + (#results - 1) * CARD_STAGGER
	RewardsMotion.useEnter(titleRef, { Scale = 0 }, { Scale = 1 }, pop(0.05), { phase })
	RewardsMotion.useEnter(buttonsRef, { Scale = 0 }, { Scale = 1 }, pop(lastDelay + 0.3), { phase, instant })

	local children = {}
	if phase == "crate" then
		children.Crate = e(Crate, { Banner = props.Banner, Color = color })
	else
		local single = #results == 1
		local size = if single then BIG_CARD else SMALL_CARD
		local rows = math.ceil(#results / COLUMNS)
		local gridHeight = if single then size.Y else rows * size.Y + (rows - 1) * GAP
		local top = CONTENT_HEIGHT / 2 - gridHeight / 2 - 20
		local cards = {}
		for index, result in results do
			local column, row = (index - 1) % COLUMNS, (index - 1) // COLUMNS
			local inRow = math.min(COLUMNS, #results - row * COLUMNS)
			local rowWidth = inRow * size.X + (inRow - 1) * GAP
			local x = -rowWidth / 2 + size.X / 2 + column * (size.X + GAP)
			local y = top + size.Y / 2 + row * (size.Y + GAP)
			-- Remounted with no delay when the player skips.
			cards[(if instant then "Now" else "Card") .. index] = e(Card, {
				Result = result,
				Size = size,
				Position = UDim2.new(0.5, x, 0, y),
				Delay = if instant then 0 else FIRST_CARD + (index - 1) * CARD_STAGGER,
				CaseId = if props.SkipIntro then props.CaseId else nil,
			})
		end
		children.Cards = e(React.Fragment, nil, cards)

		local button = ArtImage.sizeForHeight(RewardsArt.ButtonClaim, 92)
		children.Title = e("Frame", {
			Size = UDim2.fromOffset(700, 80),
			Position = UDim2.new(0.5, 0, 0, top - 30),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
		}, {
			Pop = e("UIScale", { ref = titleRef, Scale = 1 }),
			Text = e(Text, {
				Text = if single then "YOU GOT!" else `SUMMON x{#results}`,
				Gradient = RewardsText.Gold,
				StrokeThickness = 5,
			}),
		})
		children.Buttons = e("Frame", {
			Size = UDim2.fromOffset(button.X * 2 + 30, button.Y),
			Position = UDim2.new(0.5, 0, 0, top + gridHeight + 34),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
		}, {
			Pop = e("UIScale", { ref = buttonsRef, Scale = 1 }),
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 30),
			}),
			Again = props.AgainLabel and e(ImageButton, {
				Art = RewardsArt.ButtonClaim,
				Size = UDim2.fromOffset(button.X, button.Y),
				LayoutOrder = 1,
				OnClick = props.OnAgain,
			}, {
				Label = e(Text, {
					Text = props.AgainLabel,
					Size = UDim2.fromScale(0.8, 0.45),
					Position = UDim2.fromScale(0.5, 0.48),
					AnchorPoint = Vector2.new(0.5, 0.5),
					StrokeColor = Color3.fromRGB(16, 70, 8),
				}),
			}),
			Ok = e(ImageButton, {
				Art = RewardsArt.TabActive,
				Size = UDim2.fromOffset(button.X, button.Y),
				LayoutOrder = 2,
				OnClick = props.OnClose,
			}, {
				Label = e(Text, {
					Text = "OK",
					Size = UDim2.fromScale(0.6, 0.5),
					Position = UDim2.fromScale(0.5, 0.48),
					AnchorPoint = Vector2.new(0.5, 0.5),
					StrokeColor = Color3.fromRGB(110, 50, 0),
				}),
			}),
		})
	end

	return e("TextButton", {
		ref = dimRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 8, 16),
		BackgroundTransparency = 0.2,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 50,
		[React.Event.Activated] = function()
			if phase == "crate" then
				openCards()
			elseif not instant and os.clock() - cardsAt.current < lastDelay + 0.45 then
				-- Only while cards are still popping in: afterwards a skip would pop them all again.
				setInstant(true)
			end
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 40) }),
		Content = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, children),
		Flash = e("Frame", {
			ref = flashRef,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.6),
			BackgroundTransparency = 1,
			ZIndex = 60,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 40) }),
		}),
	})
end

return SummonReveal
