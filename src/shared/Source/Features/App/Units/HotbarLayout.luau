-- The match tower hotbar's footprint (TowerHotbar), shared so other HUD pieces (the upgrade panel) can keep clear
-- of it. Pixels on a 1080p screen, scaled by useUiScale; the bar sits centered at the bottom, EDGE screen pixels up.
local HotbarLayout = {}

HotbarLayout.CARD = Vector2.new(116, 120)
HotbarLayout.GAP = 10
HotbarLayout.PADDING = 16
HotbarLayout.EDGE = 12
HotbarLayout.LEVEL_GAP = 6
HotbarLayout.LEVEL_HEIGHT = 40
HotbarLayout.LEVEL_MIN_WIDTH = 420 -- room for the XP numbers when few slots are unlocked

-- Unscaled size of the whole bar (cards panel + level bar) for `count` unlocked slots.
function HotbarLayout.size(count: number): Vector2
	local width = math.max(count * HotbarLayout.CARD.X + (count - 1) * HotbarLayout.GAP + HotbarLayout.PADDING * 2, HotbarLayout.LEVEL_MIN_WIDTH)
	local height = HotbarLayout.CARD.Y + HotbarLayout.PADDING * 2 + HotbarLayout.LEVEL_GAP + HotbarLayout.LEVEL_HEIGHT
	return Vector2.new(width, height)
end

-- Its rect on a screen of `screen` size (left, top, right, bottom) at HUD scale `scale`.
function HotbarLayout.rect(count: number, screen: Vector2, scale: number): (number, number, number, number)
	local size = HotbarLayout.size(count) * scale
	local bottom = screen.Y - HotbarLayout.EDGE
	return (screen.X - size.X) / 2, bottom - size.Y, (screen.X + size.X) / 2, bottom
end

return HotbarLayout
