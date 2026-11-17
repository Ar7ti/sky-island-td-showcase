-- Top-left card on its ready-made art: avatar headshot inside the ring, name, level and XP bar.
-- The whole card is a button (OnClick opens the level road); Badge shows rewards waiting there.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Level = require(ReplicatedStorage.Shared.Features.Services.LevelService.Level)
local Common = ReplicatedStorage.Shared.Source.Features.App.Common
local Theme = require(Common.Theme)
local ArtImage = require(Common.ArtImage)
local OutlinedText = require(Common.OutlinedText)
local useDataValue = require(Common.useDataValue)
local HudConfig = require(script.Parent.HudConfig)
local HeldRewards = require(script.Parent.HeldRewards)
local Badge = require(Common.Badge)
local usePressAnimation = require(Common.usePressAnimation)
local e = React.createElement

local XP_FILL_TOP = Color3.fromRGB(150, 240, 70)
local XP_FILL_BOTTOM = Color3.fromRGB(60, 180, 20)

local function PlayerCard(props: { Size: UDim2, OnClick: (() -> ())?, Badge: string? })
	local config = HudConfig.PlayerCard
	local player = Players.LocalPlayer
	-- While match XP flies in (RewardArrival) the card shows the animated level instead of the saved one.
	local held = HeldRewards.use("Level")
	local savedLevel = tonumber(useDataValue("level")) or 0
	local savedExperience = tonumber(useDataValue("experiencelvl")) or 0
	local level = if held then held.Level else savedLevel
	local experience = if held then held.Experience else savedExperience
	local progress = math.clamp(experience / Level.GetNeededExperience(level), 0, 1)

	local aspect = ArtImage.aspect(config.art)
	local avatarWidth = config.avatarHeight / aspect -- same pixel size as the height
	local nameSize, namePosition = ArtImage.area(config.nameArea)
	local levelSize, levelPosition = ArtImage.area(config.levelArea)
	local xpSize, xpPosition = ArtImage.area(config.xpArea)
	local scaleRef, events = usePressAnimation(1.04, props.OnClick)

	local buttonProps = {
		Size = props.Size,
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
		}, {
			Scale = e("UIScale", { ref = scaleRef, Scale = 1 }),
			Badge = props.Badge and e(Badge, { Text = props.Badge, Size = 48 }),
			-- Drawn under the art: the ring's hole in the art frames the headshot.
			Avatar = e("ImageLabel", {
				Size = UDim2.fromScale(avatarWidth, config.avatarHeight),
				Position = UDim2.fromScale(config.avatarCenter.X, config.avatarCenter.Y),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Theme.Panel.FaceBottom,
				Image = `rbxthumb://type=AvatarHeadShot&id={player.UserId}&w=150&h=150`,
				ZIndex = 1,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
			Art = e(ArtImage.Image, { Art = config.art, ZIndex = 2 }),
			Name = e(OutlinedText, {
				Text = player.DisplayName,
				Size = nameSize,
				Position = namePosition,
				XAlignment = Enum.TextXAlignment.Left,
				ZIndex = 3,
			}),
			Level = e(OutlinedText, {
				Text = `Level {level}`,
				Size = levelSize,
				Position = levelPosition,
				XAlignment = Enum.TextXAlignment.Left,
				Color = Theme.TextMuted,
				StrokeThickness = 2,
				ZIndex = 3,
			}),
			XpBar = e("Frame", {
				Size = xpSize,
				Position = xpPosition,
				BackgroundTransparency = 1,
				ZIndex = 3,
			}, {
				Fill = e("Frame", {
					Size = UDim2.fromScale(progress, 1),
					BackgroundColor3 = Color3.new(1, 1, 1),
					Visible = progress > 0,
					ZIndex = 3,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
					Gradient = e("UIGradient", {
						Color = ColorSequence.new(XP_FILL_TOP, XP_FILL_BOTTOM),
						Rotation = 90,
					}),
				}),
			}),
		}),
	})
end

return PlayerCard
