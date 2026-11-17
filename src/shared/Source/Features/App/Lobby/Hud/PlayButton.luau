-- The big Play button with a slow idle "breathing" pulse to draw the eye.
-- While the player stands on a party pad it turns into a red Leave button with the pad's status.
-- One line on top says what the next win pays extra (MatchBonuses): the first win of the day x2 and the
-- win streak bonus.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local React = require(ReplicatedStorage.Packages.React)
local PartyShared = require(ReplicatedStorage.Shared.Features.Services.Parties.PartyShared)
local Common = ReplicatedStorage.Shared.Source.Features.App.Common
local Theme = require(Common.Theme)
local GameButton = require(Common.GameButton)
local OutlinedText = require(Common.OutlinedText)
local HudConfig = require(script.Parent.HudConfig)
local MenuButton = require(script.Parent.MenuButton)
local usePartyState = require(script.Parent.usePartyState)
local useDataValue = require(Common.useDataValue)
local MatchBonuses = require(ReplicatedStorage.Shared.Features.Services.MatchBonuses.MatchBonuses)
local Ids = require(ReplicatedStorage.Shared.Source.Game.AssetsIds.Ids)
local e = React.createElement

local PULSE_INFO = TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

export type Props = {
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	OnClick: (() -> ())?,
	OnLeave: (() -> ())?,
}

local function partyLine(party: usePartyState.PartyState): string
	local players = if party.count and party.max then `{party.count}/{party.max}` else ""
	if party.status == PartyShared.Status.Teleporting then
		return "Teleporting..."
	elseif party.status == PartyShared.Status.Failed then
		return "Teleport failed"
	elseif party.timeLeft and party.timeLeft >= 0 then
		return `{players}  ·  Starting in {party.timeLeft}`
	end
	return players
end

local function LeaveButton(props: { party: usePartyState.PartyState, OnClick: (() -> ())? })
	local colors = Theme.Colors.Red
	return e(GameButton, {
		Colors = colors,
		Size = UDim2.fromScale(1, 1),
		CornerRadius = UDim.new(0, 22),
		HoverScale = 1.04,
		OnClick = props.OnClick,
	}, {
		Title = e(OutlinedText, {
			Text = "LEAVE",
			Size = UDim2.fromScale(0.6, 0.5),
			Position = UDim2.fromScale(0.5, 0.08),
			AnchorPoint = Vector2.new(0.5, 0),
			StrokeColor = colors.TextStroke,
			StrokeThickness = 4,
		}),
		Status = e(OutlinedText, {
			Text = partyLine(props.party),
			Size = UDim2.fromScale(0.86, 0.26),
			Position = UDim2.fromScale(0.5, 0.92),
			AnchorPoint = Vector2.new(0.5, 1),
			StrokeColor = colors.TextStroke,
			StrokeThickness = 2.5,
		}),
	})
end

local TAG_OUTLINE = Color3.fromRGB(12, 16, 26)
local GOLD = Color3.fromRGB(255, 214, 92)
local STREAK = Color3.fromRGB(255, 160, 70)

-- Server time, refreshed every half minute so the "first win" tag comes back at midnight UTC.
local function useServerNow(): number
	local now, setNow = React.useState(Workspace:GetServerTimeNow())
	React.useEffect(function()
		local running = true
		task.spawn(function()
			while running do
				task.wait(30)
				if running then setNow(Workspace:GetServerTimeNow()) end
			end
		end)
		return function()
			running = false
		end
	end, {})
	return now
end

-- What the next victory pays extra (MatchBonuses), one line on top of the Play button:
-- "[gift] FIRST WIN x2  ·  [flame] STREAK 3 +30%". Fixed text size (the HUD's UIScale scales it) and nothing
-- changes size: only a light sweeps over the pill now and then and the icons rock a little.
local SHINE_INFO = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local ROCK_INFO = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local function BonusLine()
	local shineRef = React.useRef(nil :: UIGradient?)
	local pillRef = React.useRef(nil :: Frame?)
	local streak = useDataValue("matchStreak")
	local now = useServerNow()
	local nextWin = MatchBonuses.NextWin(streak, now)
	local wins = if streak then streak.wins or 0 else 0
	local parts = {}
	if nextWin.FirstWin then
		table.insert(parts, { Icon = Ids.Rewards.Gift, Text = "FIRST WIN x2", Color = GOLD })
	end
	if wins > 0 then
		table.insert(parts, { Icon = Ids.Rewards.Streak, Text = `STREAK {wins} +{math.round(nextWin.StreakBonus * 100)}%`, Color = STREAK })
	end
	-- Light sweep every few seconds; icons rock gently (rotation only).
	React.useEffect(function()
		local shine, pill = shineRef.current, pillRef.current
		if not shine or not pill then
			return
		end
		local running = true
		task.spawn(function()
			task.wait(0.6)
			while running do
				shine.Offset = Vector2.new(-1.2, 0)
				TweenService:Create(shine, SHINE_INFO, { Offset = Vector2.new(1.2, 0) }):Play()
				task.wait(3.5)
			end
		end)
		local rocks = {}
		for _, child in pill:GetChildren() do
			if child:IsA("ImageLabel") then
				child.Rotation = -8
				local rock = TweenService:Create(child, ROCK_INFO, { Rotation = 8 })
				rock:Play()
				table.insert(rocks, rock)
			end
		end
		return function()
			running = false
			for _, rock in rocks do
				rock:Cancel()
			end
		end
	end, { #parts })
	if #parts == 0 then
		return nil
	end
	local children = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12) }),
		Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Stroke = e("UIStroke", { Color = Color3.fromRGB(255, 200, 80), Thickness = 2, Transparency = 0.25, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		-- Dark warm pill with a light band; tweening Offset sweeps the band across.
		Gradient = e("UIGradient", {
			ref = shineRef,
			Rotation = 15,
			Offset = Vector2.new(-1.2, 0),
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 30, 38)),
				ColorSequenceKeypoint.new(0.42, Color3.fromRGB(44, 38, 40)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 120, 60)),
				ColorSequenceKeypoint.new(0.58, Color3.fromRGB(44, 38, 40)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(34, 30, 38)),
			}),
		}),
	}
	for index, part in parts do
		if index > 1 then
			children["Dot" .. index] = e("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 30),
				BackgroundTransparency = 1,
				Text = "·",
				Font = Enum.Font.GothamBlack,
				TextSize = 22,
				TextColor3 = Color3.fromRGB(200, 205, 220),
				LayoutOrder = index * 3 - 2,
			})
		end
		children["Icon" .. index] = e("ImageLabel", {
			Size = UDim2.fromOffset(26, 26),
			BackgroundTransparency = 1,
			Image = part.Icon,
			ScaleType = Enum.ScaleType.Fit,
			LayoutOrder = index * 3 - 1,
			ZIndex = 6,
		})
		children["Text" .. index] = e("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 30),
			BackgroundTransparency = 1,
			Text = part.Text,
			Font = Enum.Font.GothamBlack,
			TextSize = 20,
			TextColor3 = Color3.new(1, 1, 1),
			LayoutOrder = index * 3,
			ZIndex = 6,
		}, {
			Stroke = e("UIStroke", { Color = TAG_OUTLINE, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round }),
			-- Light on top, the bonus color below.
			Gradient = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 250, 220), part.Color) }),
		})
	end
	return e("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36),
		Position = UDim2.new(0.5, 0, 0, -6),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.12,
		ZIndex = 5,
		ref = pillRef,
	}, children)
end

local function PlayButton(props: Props)
	local pulseRef = React.useRef(nil :: UIScale?)
	local party = usePartyState()

	React.useEffect(function()
		local pulse = pulseRef.current
		if not pulse then
			return
		end
		-- Only the Play state breathes; Leave stays still.
		if party then
			pulse.Scale = 1
			return
		end
		local tween = TweenService:Create(pulse, PULSE_INFO, { Scale = 1.035 })
		tween:Play()
		return function()
			tween:Cancel()
		end
	end, { party ~= nil })

	return e("Frame", {
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
	}, {
		-- Centered so the pulse grows from the middle, not from the top-left corner.
		Body = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, {
			Pulse = e("UIScale", { ref = pulseRef, Scale = 1 }),
			Button = if party
				then e(LeaveButton, { party = party, OnClick = props.OnLeave })
				else e(MenuButton, {
					Config = HudConfig.Play,
					Layout = "Wide",
					Size = UDim2.fromScale(1, 1),
					OnClick = props.OnClick,
				}),
		}),
		Tags = if party then nil else e(BonusLine),
	})
end

return PlayButton
