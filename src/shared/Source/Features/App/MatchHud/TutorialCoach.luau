-- First-match tutorial card (left side of the match HUD) for the step the server publishes in the
-- player attribute "TutorialStep" (MatchHud only shows; TutorialService decides). Skip any time;
-- the last step has the Collect button. Rules and texts: Shared Tutorial/Tutorial.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Common = ReplicatedStorage.Shared.Source.Features.App.Common
local Theme = require(Common.Theme)
local GameButton = require(Common.GameButton)
local OutlinedText = require(Common.OutlinedText)
local Panel = require(Common.Panel)
local ScaledGroup = require(Common.ScaledGroup)
local useUiScale = require(Common.useUiScale)
local usePlayerAttribute = require(Common.usePlayerAttribute)
local Tutorial = require(ReplicatedStorage.Shared.Features.Services.Tutorial.Tutorial)
local e = React.createElement

-- Pixels on a 1080p screen. Sits under the Cash panel and the TOWERS chip (MatchMenu).
local SIZE = Vector2.new(380, 236)
local TOP = 20 + 90 + 6 + 66 + 16 -- under Cash and the TOWERS housing (MatchMenu)
local EDGE = 20
local PADDING = 18

local function send(action: string)
	local remote = ReplicatedStorage:FindFirstChild(Tutorial.RemoteName)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(action)
	end
end

local function TutorialCoach()
	local scale = useUiScale()
	local step = usePlayerAttribute(Tutorial.StepAttribute)
	local info = type(step) == "number" and Tutorial.Steps[step] or nil
	if not info then
		return nil
	end
	local last = step == #Tutorial.Steps

	return e(ScaledGroup, {
		Scale = scale,
		Size = SIZE,
		-- The top part (Cash, TOWERS) is placed in screen px plus scaled sizes; follow the same rule.
		Position = UDim2.fromOffset(EDGE, EDGE + math.round((TOP - EDGE) * scale)),
		AnchorPoint = Vector2.new(0, 0),
	}, {
		Card = e(Panel, {
			Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
			CornerRadius = UDim.new(0, 20),
			AccentColor = Color3.fromRGB(255, 205, 50),
		}, {
			Header = e(OutlinedText, {
				Text = `TUTORIAL · STEP {step}/{#Tutorial.Steps}`,
				Size = UDim2.new(1, -PADDING * 2, 0, 22),
				Position = UDim2.fromOffset(PADDING, 14),
				XAlignment = Enum.TextXAlignment.Left,
				Color = Color3.fromRGB(255, 205, 50),
				StrokeThickness = 2,
			}),
			Title = e(OutlinedText, {
				Text = info.Title,
				Size = UDim2.new(1, -PADDING * 2, 0, 38),
				Position = UDim2.fromOffset(PADDING, 40),
				XAlignment = Enum.TextXAlignment.Left,
				StrokeThickness = 3,
			}),
			Body = e("TextLabel", {
				Text = info.Text,
				Size = UDim2.new(1, -PADDING * 2, 0, 70),
				Position = UDim2.fromOffset(PADDING, 84),
				BackgroundTransparency = 1,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Font = Enum.Font.FredokaOne,
				TextSize = 20,
				TextColor3 = Theme.TextMuted,
			}),
			Action = last and e(GameButton, {
				Colors = Theme.Colors.Green,
				Size = UDim2.fromOffset(220, 56),
				Position = UDim2.fromOffset(PADDING, SIZE.Y - PADDING - 56),
				CornerRadius = UDim.new(0, 14),
				OnClick = function()
					send("collect")
				end,
			}, {
				Label = e(OutlinedText, {
					Text = `COLLECT {Tutorial.Reward} COINS`,
					Size = UDim2.fromScale(0.86, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					StrokeThickness = 2.5,
				}),
			}),
			Skip = e(GameButton, {
				Colors = Theme.Colors.Dark,
				Size = UDim2.fromOffset(if last then 104 else 120, 44),
				Position = UDim2.new(1, -PADDING, 1, -PADDING),
				AnchorPoint = Vector2.new(1, 1),
				CornerRadius = UDim.new(0, 12),
				OnClick = function()
					send("skip")
				end,
			}, {
				Label = e(OutlinedText, {
					Text = if last then "CLOSE" else "SKIP",
					Size = UDim2.fromScale(0.7, 0.48),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					StrokeThickness = 2,
				}),
			}),
		}),
	})
end

return TutorialCoach
