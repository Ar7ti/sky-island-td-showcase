-- A stack of MenuButtons built from a HudConfig list. Every button gets the same width
-- (Fit = "Width") or the same height (Fit = "Height"); the other side follows the art's proportions.
-- With Columns > 1 the buttons fill a grid row by row instead (cells sized to the largest button).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ArtImage = require(ReplicatedStorage.Shared.Source.Features.App.Common.ArtImage)
local HudConfig = require(script.Parent.HudConfig)
local MenuButton = require(script.Parent.MenuButton)
local e = React.createElement

export type Props = {
	Buttons: { HudConfig.ButtonConfig },
	Layout: "Tile" | "Wide",
	Fit: "Width" | "Height",
	Extent: number, -- px: the shared width or height
	Gap: number,
	Columns: number?, -- default 1
	Alignment: Enum.HorizontalAlignment,
	actions: { [string]: () -> () },
	badges: { [string]: string },
}

local ButtonColumn = {}

-- Size of one button in this column; buttons drawn in code are square tiles or 3:1 wide bars.
function ButtonColumn.buttonSize(config: HudConfig.ButtonConfig, layout: "Tile" | "Wide", fit: "Width" | "Height", extent: number): Vector2
	if config.art then
		return if fit == "Width" then ArtImage.sizeForWidth(config.art, extent) else ArtImage.sizeForHeight(config.art, extent)
	end
	local aspect = if layout == "Tile" then 1 else 3
	return if fit == "Width" then Vector2.new(extent, extent / aspect) else Vector2.new(extent * aspect, extent)
end

local function largestButton(buttons: { HudConfig.ButtonConfig }, layout, fit, extent): Vector2
	local largest = Vector2.zero
	for _, config in buttons do
		largest = largest:Max(ButtonColumn.buttonSize(config, layout, fit, extent))
	end
	return largest
end

-- Total box the stack needs.
function ButtonColumn.measure(buttons: { HudConfig.ButtonConfig }, layout: "Tile" | "Wide", fit: "Width" | "Height", extent: number, gap: number, columns: number?): Vector2
	columns = columns or 1
	if columns > 1 then
		local cell = largestButton(buttons, layout, fit, extent)
		local rows = math.ceil(#buttons / columns)
		local used = math.min(columns, #buttons)
		return Vector2.new(used * cell.X + (used - 1) * gap, rows * cell.Y + (rows - 1) * gap)
	end
	local width, height = 0, 0
	for _, config in buttons do
		local size = ButtonColumn.buttonSize(config, layout, fit, extent)
		width = math.max(width, size.X)
		height += size.Y
	end
	return Vector2.new(width, height + math.max(#buttons - 1, 0) * gap)
end

function ButtonColumn.Component(props: Props)
	local columns = props.Columns or 1
	local layout
	if columns > 1 then
		local cell = largestButton(props.Buttons, props.Layout, props.Fit, props.Extent)
		layout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(cell.X, cell.Y),
			CellPadding = UDim2.fromOffset(props.Gap, props.Gap),
			FillDirection = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = columns,
			HorizontalAlignment = props.Alignment,
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
	else
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = props.Alignment,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, props.Gap),
		})
	end

	local children = { Layout = layout }
	for index, config in props.Buttons do
		local size = ButtonColumn.buttonSize(config, props.Layout, props.Fit, props.Extent)
		children[config.id] = e(MenuButton, {
			Config = config,
			Layout = props.Layout,
			Size = UDim2.fromOffset(size.X, size.Y),
			LayoutOrder = index,
			Badge = props.badges[config.id],
			OnClick = props.actions[config.id],
		})
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, children)
end

return ButtonColumn
