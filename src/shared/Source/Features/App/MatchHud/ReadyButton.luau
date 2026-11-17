-- READY under the wave bar during preparation: votes to start the next wave early (WaveService.VoteReady).
-- Shows how many players are ready ("READY 1/2") from MatchState; once this player voted it turns into a
-- waiting label. Hidden outside preparation and in the last seconds of the countdown.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local React = require(ReplicatedStorage.Packages.React)
local Common = ReplicatedStorage.Shared.Source.Features.App.Common
local GameButton = require(Common.GameButton)
local OutlinedText = require(Common.OutlinedText)
local ScaledGroup = require(Common.ScaledGroup)
local Theme = require(Common.Theme)
local useUiScale = require(Common.useUiScale)
local soundController = require(ReplicatedStorage.Shared.Features.Services.SoundController.soundController)
local Ids = require(ReplicatedStorage.Shared.Source.Game.AssetsIds.Ids)
local e = React.createElement

local SIZE = Vector2.new(250, 64)
local BAR_TOP = 8 -- UpBar_healthBar's TOP (not scaled)
local BAR_HEIGHT = 86 + 4 + 54 + 10 -- its health + gap + wave pill, plus a gap (scaled)
local READY_SECONDS = 3

export type Props = {
	Phase: string?,
	TimeRemaining: number?,
	Wave: number?,
	Votes: number?,
	Needed: number?,
}

local function ReadyButton(props: Props)
	local scale = useUiScale()
	local voted, setVoted = React.useState(false)
	-- A new countdown (next wave) clears this player's vote.
	React.useEffect(function()
		setVoted(false)
	end, { props.Wave })

	local visible = props.Phase == "Preparation" and (props.TimeRemaining or 0) > READY_SECONDS
	if not visible then
		return nil
	end
	local votes, needed = props.Votes or 0, math.max(props.Needed or 1, 1)
	local label = if voted then (if needed > 1 then `WAITING {votes}/{needed}` else "STARTING...")
		else (if needed > 1 then `READY {votes}/{needed}` else "START WAVE")
	local topbar = GuiService:GetGuiInset().Y
	return e(ScaledGroup, {
		Scale = scale,
		Size = SIZE,
		Position = UDim2.new(0.5, 0, 0, BAR_TOP - topbar + math.round(BAR_HEIGHT * scale)),
		AnchorPoint = Vector2.new(0.5, 0),
	}, {
		Button = e(GameButton, {
			Colors = if voted then Theme.Colors.Dark else Theme.Colors.Green,
			Size = UDim2.fromScale(1, 1),
			CornerRadius = UDim.new(0, 16),
			OnClick = function()
				if voted then
					return
				end
				local state = ReplicatedStorage:FindFirstChild("MatchState")
				local remote = state and state:FindFirstChild("ReadyRemote")
				if remote and remote:IsA("RemoteEvent") then
					soundController:PlaySFX("leftBarClick")
					remote:FireServer()
					setVoted(true)
				end
			end,
		}, {
			Icon = e("ImageLabel", {
				Image = Ids.MatchHud.GlyphPlay or "",
				Size = UDim2.fromScale(0.16, 0.56),
				Position = UDim2.fromScale(0.06, 0.45),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
			}),
			Label = e(OutlinedText, {
				Text = label,
				Size = UDim2.fromScale(0.7, 0.56),
				Position = UDim2.fromScale(0.58, 0.45),
				AnchorPoint = Vector2.new(0.5, 0.5),
				StrokeThickness = 3,
			}),
		}),
	})
end

return ReadyButton
