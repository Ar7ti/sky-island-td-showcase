-- One reward slot. Status decides the look:
--   Ready   - gold card that gently pulses, a shine sweeping over it, the reward bobbing, a CLAIM button
--   Claimed - dimmed with a green check over the reward (stamped in when it was just claimed)
--   Locked  - dark card with a padlock; Hint (e.g. "TOMORROW", time left) shown in gold
-- Special cards (the last, biggest reward) are purple with a headline and twinkling sparkles.
-- Cards pop in when shown; Delay staggers them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local React = require(ReplicatedStorage.Packages.React)
local Common = ReplicatedStorage.Shared.Source.Features.App.Common
local ArtImage = require(Common.ArtImage)
local ImageButton = require(Common.ImageButton)
local Rewards = require(ReplicatedStorage.Shared.Features.Services.Rewards.Rewards)
local RewardsArt = require(script.Parent.RewardsArt)
local RewardsText = require(script.Parent.RewardsText)
local RewardsMotion = require(script.Parent.RewardsMotion)
local e = React.createElement
local Text = RewardsText.Component

export type Status = "Ready" | "Claimed" | "Locked"

export type Props = {
	Slot: Rewards.Slot,
	Title: string,
	Status: Status,
	Hint: string?,
	Special: boolean?,
	Pending: boolean?, -- a claim is on its way to the server
	Delay: number?, -- seconds before the card pops in
	Covered: boolean?, -- something (the reveal popup) is over the card; holds back the claim stamp
	OnClaim: () -> (),
	Size: UDim2,
	Position: UDim2?,
	LayoutOrder: number?,
}

local PULSE = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local BOB = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local SHINE = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 1.6)
local STAMP = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SLIDE = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local DIM = Color3.fromRGB(120, 120, 135)

-- A light band that sweeps across the card every couple of seconds.
local function Shine(props: { ZIndex: number })
	local gradientRef = React.useRef(nil :: UIGradient?)
	RewardsMotion.useLoop(gradientRef, { Offset = Vector2.new(1.2, 0) }, SHINE)
	return e("Frame", {
		Size = UDim2.fromScale(0.9, 0.9),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.45,
		ZIndex = props.ZIndex,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0.08, 0) }),
		Band = e("UIGradient", {
			ref = gradientRef,
			Rotation = 20,
			Offset = Vector2.new(-1.2, 0),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.42, 1),
				NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(0.58, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
end

-- The green check; stamped in big-to-normal when the card was claimed while on screen,
-- as soon as nothing covers the card any more.
local function Check(props: { Special: boolean, Stamp: boolean, Covered: boolean })
	local scaleRef = React.useRef(nil :: UIScale?)
	local played = React.useRef(false)
	React.useEffect(function()
		local scale = scaleRef.current
		if not scale or not props.Stamp or played.current then
			return
		end
		if props.Covered then
			scale.Scale = 0
			return
		end
		played.current = true
		scale.Scale = 2.4
		local tween = RewardsMotion.play(scale, nil, { Scale = 1 }, STAMP)
		return function()
			if tween then
				tween:Cancel()
			end
		end
	end, { props.Covered })
	return e(RewardsArt.Icon, {
		Art = RewardsArt.Icons.Claimed,
		Size = UDim2.fromScale(if props.Special then 0.34 else 0.46, if props.Special then 0.3 else 0.4),
		Position = UDim2.fromScale(0.5, if props.Special then 0.56 else 0.47),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = if props.Stamp then -8 else 0,
		ZIndex = 4,
	}, {
		Scale = e("UIScale", { ref = scaleRef, Scale = 1 }),
	})
end

-- A sparkle that slowly grows, shrinks and turns, starting at its own delay.
local function Sparkle(props: { Position: UDim2, Size: number, Delay: number, ZIndex: number? })
	local ref = React.useRef(nil :: ImageLabel?)
	React.useEffect(function()
		local image = ref.current
		if not image then
			return
		end
		local info = TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, props.Delay)
		local tween = TweenService:Create(image, info, {
			Size = UDim2.fromScale(props.Size * 0.45, props.Size * 0.45),
			Rotation = 35,
			ImageTransparency = 0.6,
		})
		tween:Play()
		return function()
			tween:Cancel()
		end
	end, {})
	return e(RewardsArt.Icon, {
		ref = ref,
		Art = RewardsArt.Icons.Sparkle,
		Size = UDim2.fromScale(props.Size, props.Size),
		Position = props.Position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = props.ZIndex,
	})
end

local function ClaimButton(props: { Pending: boolean?, OnClaim: () -> (), Width: number, Bottom: number })
	local size = ArtImage.sizeForWidth(RewardsArt.ButtonClaim, 100)
	-- Full card height, narrowed by the aspect constraint to the button's own proportions.
	return e("Frame", {
		Size = UDim2.fromScale(props.Width, 1),
		Position = UDim2.fromScale(0.5, props.Bottom),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, {
		Aspect = e("UIAspectRatioConstraint", { AspectRatio = size.X / size.Y }),
		Button = e(ImageButton, {
			Art = RewardsArt.ButtonClaim,
			Size = UDim2.fromScale(1, 1),
			OnClick = if props.Pending then nil else props.OnClaim,
		}, {
			Label = e(Text, {
				Text = if props.Pending then "..." else "CLAIM",
				Size = UDim2.fromScale(0.7, 0.58),
				Position = UDim2.fromScale(0.5, 0.48),
				AnchorPoint = Vector2.new(0.5, 0.5),
				StrokeColor = Color3.fromRGB(16, 70, 8),
				StrokeThickness = 3,
			}),
		}),
	})
end

local function RewardCard(props: Props)
	local status = props.Status
	local ready = status == "Ready"
	local claimed = status == "Claimed"
	local special = props.Special == true
	local slot = props.Slot

	local appearRef = React.useRef(nil :: UIScale?)
	local bodyRef = React.useRef(nil :: Frame?)
	local pulseRef = React.useRef(nil :: UIScale?)
	local floatRef = React.useRef(nil :: Frame?)
	local popIn = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, props.Delay or 0)
	local slideIn = TweenInfo.new(SLIDE.Time, SLIDE.EasingStyle, SLIDE.EasingDirection, 0, false, props.Delay or 0)
	RewardsMotion.useEnter(appearRef, { Scale = 0 }, { Scale = 1 }, popIn)
	RewardsMotion.useEnter(bodyRef, { Position = UDim2.new(0.5, 0, 0.5, 40) }, { Position = UDim2.fromScale(0.5, 0.5) }, slideIn)
	RewardsMotion.useLoop(pulseRef, { Scale = 1.035 }, PULSE, ready)
	-- Loops only animate props the render never changes, so React and the tweens don't fight.
	RewardsMotion.useLoop(floatRef, { Position = UDim2.fromScale(0.5, 0.47) }, BOB, ready and not special)

	-- Only a card that turns Claimed while shown gets the stamp animation.
	local previousStatus = React.useRef(status)
	local stamp = React.useRef(false)
	if claimed and previousStatus.current == "Ready" then
		stamp.current = true
	elseif not claimed then
		stamp.current = false
	end
	React.useEffect(function()
		previousStatus.current = status
	end, { status })

	local cardArt = if special then RewardsArt.CardSpecial elseif ready then RewardsArt.CardActive else RewardsArt.CardDefault
	local hasFooter = ready or props.Hint ~= nil
	local icon = RewardsArt.Icons[slot.icon] or RewardsArt.Icons.Gift

	local children: { [string]: any } = {
		Pulse = e("UIScale", { ref = pulseRef, Scale = 1 }),
		Card = e(ArtImage.Image, { Art = cardArt }),
		Shine = ready and e(Shine, { ZIndex = 2 }),
		Shade = claimed and e("Frame", {
			Size = UDim2.fromScale(0.9, 0.9),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.45,
			ZIndex = 2,
		}, { Corner = e("UICorner", { CornerRadius = UDim.new(0.08, 0) }) }),
		Title = e(Text, {
			Text = props.Title,
			Size = UDim2.fromScale(0.62, if special then 0.075 else 0.13),
			Position = UDim2.fromScale(0.5, if special then 0.05 else 0.07),
			AnchorPoint = Vector2.new(0.5, 0),
			Color = if claimed then RewardsText.MutedColor else nil,
			ZIndex = 3,
		}),
		Lock = status == "Locked" and e(RewardsArt.Icon, {
			Art = RewardsArt.Icons.Locked,
			Size = UDim2.fromScale(if special then 0.09 else 0.15, if special then 0.11 else 0.18),
			Position = UDim2.fromScale(0.93, 0.05),
			AnchorPoint = Vector2.new(1, 0),
			ZIndex = 4,
		}),
		Check = claimed and e(Check, { Special = special, Stamp = stamp.current, Covered = props.Covered == true }),
		Claim = ready and e(ClaimButton, {
			Pending = props.Pending,
			OnClaim = props.OnClaim,
			Width = if special then 0.52 else 0.7,
			Bottom = if special then 0.955 else 0.95,
		}),
		Hint = not ready and props.Hint and e(Text, {
			Text = props.Hint,
			Size = UDim2.fromScale(0.7, if special then 0.065 else 0.11),
			Position = UDim2.fromScale(0.5, if special then 0.94 else 0.92),
			AnchorPoint = Vector2.new(0.5, 1),
			Gradient = RewardsText.Gold,
			ZIndex = 3,
		}),
	}

	if special then
		children.Headline = e(Text, {
			Text = slot.title or "",
			Size = UDim2.fromScale(0.86, 0.22),
			Position = UDim2.fromScale(0.5, 0.13),
			AnchorPoint = Vector2.new(0.5, 0),
			Rotation = -3,
			Gradient = RewardsText.Gold,
			StrokeThickness = 4,
			Color = if claimed then RewardsText.MutedColor else nil,
			ZIndex = 3,
		})
		children.Icon = e(RewardsArt.Icon, {
			Art = icon,
			Size = UDim2.fromScale(0.66, if hasFooter then 0.34 else 0.38),
			Position = UDim2.fromScale(0.5, if hasFooter then 0.56 else 0.58),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Color = if claimed then DIM else nil,
			ZIndex = 2,
		})
		children.Label = e(Text, {
			Text = slot.label,
			Size = UDim2.fromScale(0.86, 0.06),
			Position = UDim2.fromScale(0.5, if hasFooter then 0.79 else 0.86),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Color = if claimed then RewardsText.MutedColor else nil,
			ZIndex = 3,
		})
		if not claimed then
			children.Sparkle1 = e(Sparkle, { Position = UDim2.fromScale(0.16, 0.42), Size = 0.1, Delay = 0, ZIndex = 3 })
			children.Sparkle2 = e(Sparkle, { Position = UDim2.fromScale(0.86, 0.36), Size = 0.08, Delay = 0.4, ZIndex = 3 })
			children.Sparkle3 = e(Sparkle, { Position = UDim2.fromScale(0.82, 0.68), Size = 0.07, Delay = 0.8, ZIndex = 3 })
			children.Sparkle4 = e(Sparkle, { Position = UDim2.fromScale(0.2, 0.7), Size = 0.06, Delay = 1.2, ZIndex = 3 })
		end
	else
		children.Float = e("Frame", {
			ref = floatRef,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, {
			Icon = e(RewardsArt.Icon, {
				Art = icon,
				Size = UDim2.fromScale(if ready then 0.5 elseif hasFooter then 0.58 else 0.66, if ready then 0.33 elseif hasFooter then 0.38 else 0.46),
				Position = UDim2.fromScale(0.5, if ready then 0.39 elseif hasFooter then 0.45 else 0.49),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Color = if claimed then DIM else nil,
			}),
		})
		children.Label = e(Text, {
			Text = slot.label,
			Size = UDim2.fromScale(0.84, if ready then 0.11 else 0.12),
			Position = UDim2.fromScale(0.5, if ready then 0.635 elseif hasFooter then 0.7 else 0.82),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Color = if claimed then RewardsText.MutedColor else nil,
			ZIndex = 3,
		})
		if ready then
			children.Sparkle1 = e(Sparkle, { Position = UDim2.fromScale(0.2, 0.3), Size = 0.12, Delay = 0, ZIndex = 3 })
			children.Sparkle2 = e(Sparkle, { Position = UDim2.fromScale(0.82, 0.52), Size = 0.1, Delay = 0.6, ZIndex = 3 })
		end
	end

	return e("Frame", {
		Size = props.Size,
		Position = props.Position,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
	}, {
		Appear = e("UIScale", { ref = appearRef, Scale = 1 }),
		Body = e("Frame", {
			ref = bodyRef,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, children),
	})
end

return RewardCard
