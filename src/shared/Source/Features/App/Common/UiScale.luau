-- The factor that turns 1080p pixel sizes into the current screen size (see useUiScale, the React
-- hook around it). Imperative UI (e.g. MatchHud/EliteAlerts) calls UiScale.compute() directly.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Theme = require(script.Parent.Theme)
local IsTouch = require(script.Parent.useIsTouch)

local MIN_SCALE = 0.3
local MAX_SCALE = 1.5
local MIN_WIDTH = 1100 -- px at scale 1 the HUD needs side by side (player card + currencies)
local TOUCH_BOOST = 1.2
-- Wide, short windows (e.g. Studio or a laptop window) look tiny when only the height counts, so
-- with a mouse the width wider than 16:9 lifts the scale a little. Phones keep the room for the game.
local WIDE_ASPECT = 16 / 9
local MAX_WIDE_BOOST = 1.15

-- The screen size the HUD lays out for. Studio only: the phone preview (tools/studio/phone_preview.py) sets
-- Workspace attribute UiPreviewViewport to stand in for a phone screen.
local function viewport(): Vector2
	if RunService:IsStudio() then
		local previewed = Workspace:GetAttribute("UiPreviewViewport")
		if typeof(previewed) == "Vector2" then
			return previewed
		end
	end
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1920, Theme.ReferenceHeight)
end

-- The player's "Interface size" setting (SettingsDefaults.ui_size, 0..1) as a factor: 0 -> 80%, 0.5 -> 100%, 1 -> 120%.
local function sizeFactor(value: number?): number
	return 0.8 + 0.4 * math.clamp(tonumber(value) or 0.5, 0, 1)
end

-- GameSettings mirrors ui_size into this local-player attribute (client only, not replicated), so this module needs
-- no require of the player data (tools and stories require it without any).
local function userFactor(): number
	local player = game:GetService("Players").LocalPlayer
	local value = player and player:GetAttribute("UiSize")
	return sizeFactor(if type(value) == "number" then value else nil)
end

local function compute(): number
	local screen = viewport()
	local isTouch = IsTouch.isTouch()
	local wideBoost = if isTouch then 1 else math.clamp(screen.X / screen.Y / WIDE_ASPECT, 1, MAX_WIDE_BOOST)
	local byHeight = screen.Y / Theme.ReferenceHeight * (if isTouch then TOUCH_BOOST else wideBoost) * userFactor()
	-- The width cap stays: a bigger interface never pushes the top row off a narrow screen.
	local byWidth = screen.X / MIN_WIDTH
	return math.clamp(math.min(byHeight, byWidth), MIN_SCALE, MAX_SCALE)
end

return { compute = compute, viewport = viewport, sizeFactor = sizeFactor }
