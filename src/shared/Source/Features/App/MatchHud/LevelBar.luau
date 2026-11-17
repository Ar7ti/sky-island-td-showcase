-- The player's level and XP (art/matchhud), drawn under the tower hotbar at its width.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Level = require(ReplicatedStorage.Shared.Features.Services.LevelService.Level)
local Data = require(ReplicatedStorage.Shared.Features.Services.DataService.Data).client
local OutlinedText = require(ReplicatedStorage.Shared.Source.Features.App.Common.OutlinedText)
local HudArt = require(script.Parent.HudArt)
local e = React.createElement

local TRACK = { 0.21, 0.23, 0.75, 0.54 }

export type Props = {
	Width: number,
	Height: number,
	Position: UDim2,
}

local function useNumber(value: any): number
	local current, setCurrent = React.useState(tonumber(value()) or 0)
	React.useEffect(function()
		local function update()
			setCurrent(tonumber(value()) or 0)
		end
		local subscription = value.Changed(update)
		update()
		return function()
			if type(subscription) == "function" then
				subscription()
			elseif typeof(subscription) == "RBXScriptConnection" then
				subscription:Disconnect()
			end
		end
	end, {})
	return current
end

local function LevelBar(props: Props)
	local level = useNumber(Data.level)
	local experience = useNumber(Data.experiencelvl)
	local needed = tonumber(Level.GetNeededExperience(level)) or 0
	local height = props.Height

	return e("Frame", {
		Size = UDim2.fromOffset(props.Width, height),
		Position = props.Position,
		BackgroundTransparency = 1,
	}, {
		Housing = e(HudArt.Panel, { Art = HudArt.LevelHousing, Height = height, ZIndex = 1 }),
		Badge = e(HudArt.Panel, {
			Art = HudArt.LevelBadge,
			Rect = { 0.025, 0.19, 0.15, 0.62 },
			Height = height * 0.62,
			ZIndex = 2,
		}, {
			Text = e(OutlinedText, {
				Text = `LVL {level}`,
				Size = UDim2.fromScale(0.8, 0.8),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				StrokeThickness = 2,
				ZIndex = 5,
			}),
		}),
		Bar = e(HudArt.Bar, {
			Track = HudArt.LevelTrack,
			Fill = HudArt.LevelFill,
			Rect = TRACK,
			FillRect = { 0.016, 0.12, 0.968, 0.76 },
			Height = height * TRACK[4],
			Percent = if needed > 0 then experience / needed else 0,
		}, {
			Value = e(OutlinedText, {
				Text = `{HudArt.thousands(experience)} / {HudArt.thousands(needed)} XP`,
				Size = UDim2.fromScale(0.94, 1.1),
				Position = UDim2.fromScale(0.97, 0.5),
				AnchorPoint = Vector2.new(1, 0.5),
				XAlignment = Enum.TextXAlignment.Right,
				StrokeThickness = 2,
			}),
		}),
	})
end

return LevelBar
