-- Lobby welcome for a brand-new player (Tutorial.IsEligible): one line pointing at PLAY. The guided steps
-- run in their first match (TutorialService); the banner disappears once the tutorial is done or skipped.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Common = ReplicatedStorage.Shared.Source.Features.App.Common
local OutlinedText = require(Common.OutlinedText)
local Panel = require(Common.Panel)
local ScaledGroup = require(Common.ScaledGroup)
local useUiScale = require(Common.useUiScale)
local useDataValue = require(Common.useDataValue)
local usePlayerAttribute = require(Common.usePlayerAttribute)
local Tutorial = require(ReplicatedStorage.Shared.Features.Services.Tutorial.Tutorial)
local e = React.createElement

local SIZE = Vector2.new(620, 104)
local ABOVE_PLAY = 336 -- px at 1080p above the bottom edge: over the Play button, its FIRST WIN chip and the loadout

local function WelcomeBanner(props: { Hidden: boolean? })
	local scale = useUiScale()
	local done = useDataValue("tutorialDone")
	local level = useDataValue("level")
	local experience = useDataValue("experiencelvl")
	-- Studio test hook: the server-only TutorialForce attribute (set by test scripts) shows it on any profile.
	local forced = usePlayerAttribute("TutorialForce") == true
	if props.Hidden or not (forced or Tutorial.IsEligible(done, level, experience)) then
		return nil
	end
	return e(ScaledGroup, {
		Scale = scale,
		Size = SIZE,
		Position = UDim2.new(0.5, 0, 1, -math.round(ABOVE_PLAY * scale)),
		AnchorPoint = Vector2.new(0.5, 1),
	}, {
		Card = e(Panel, {
			Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
			CornerRadius = UDim.new(0, 20),
			AccentColor = Color3.fromRGB(255, 205, 50),
		}, {
			Title = e(OutlinedText, {
				Text = "WELCOME, DEFENDER!",
				Size = UDim2.new(1, -36, 0, 40),
				Position = UDim2.fromOffset(18, 12),
				Color = Color3.fromRGB(255, 205, 50),
				StrokeThickness = 3,
			}),
			Text = e(OutlinedText, {
				Text = "Press PLAY for your first match - we'll show you the basics.",
				Size = UDim2.new(1, -36, 0, 30),
				Position = UDim2.fromOffset(18, 58),
				StrokeThickness = 2,
			}),
		}),
	})
end

return WelcomeBanner
