-- Search box and sort button above the units grid. Pixel layout inside the Units window.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Source.Features.App.Common.Theme)
local usePressAnimation = require(ReplicatedStorage.Shared.Source.Features.App.Common.usePressAnimation)
local RewardsText = require(ReplicatedStorage.Shared.Source.Features.App.Rewards.RewardsText)
local UnitsArt = require(script.Parent.UnitsArt)
local e = React.createElement
local Text = RewardsText.Component

local sortLabels = {
	["Rarity: High to Low"] = "Rarity",
	["Rarity: Low to High"] = "Rarity: Low",
	Name = "Name A-Z",
	DPS = "DPS",
	Price = "Price",
}

export type Props = {
	Search: string,
	Sort: string,
	OnSearch: (string) -> (),
	OnSort: () -> (),
	SearchFrame: Rect, -- px in the window
	SortFrame: Rect,
}

local function SortButton(props: { Label: string, Frame: Rect, OnClick: () -> () })
	local scaleRef, events = usePressAnimation(1.03, props.OnClick)
	local buttonProps = {
		Size = UDim2.fromOffset(props.Frame.Width, props.Frame.Height),
		Position = UDim2.fromOffset(props.Frame.Min.X, props.Frame.Min.Y),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
	}
	for key, handler in events do
		buttonProps[key] = handler
	end
	return e("TextButton", buttonProps, {
		Body = e(UnitsArt.Panel, {
			Art = UnitsArt.Sort,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			SliceScale = 0.8,
		}, {
			Scale = e("UIScale", { ref = scaleRef, Scale = 1 }),
			Content = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 12),
				}),
				Label = e(Text, { Text = props.Label, TextSize = 32, LayoutOrder = 1 }),
				Arrow = e(UnitsArt.Icon, {
					Art = UnitsArt.Icons.DropdownArrow,
					Size = UDim2.fromOffset(24, 20),
					LayoutOrder = 2,
				}),
			}),
		}),
	})
end

local function UnitFilters(props: Props)
	local search = props.SearchFrame
	return e(React.Fragment, nil, {
		Search = e(UnitsArt.Panel, {
			Art = UnitsArt.Search,
			Size = UDim2.fromOffset(search.Width, search.Height),
			Position = UDim2.fromOffset(search.Min.X, search.Min.Y),
			SliceScale = 0.8,
		}, {
			Icon = e(UnitsArt.Icon, {
				Art = UnitsArt.Icons.Search,
				Size = UDim2.fromOffset(36, 36),
				Position = UDim2.new(0, 22, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
			}),
			Box = e("TextBox", {
				Size = UDim2.new(1, -94, 0, 34),
				Position = UDim2.new(0, 74, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Text = props.Search,
				PlaceholderText = "Search units...",
				ClearTextOnFocus = false,
				Font = Theme.Font,
				TextSize = 30,
				TextColor3 = Theme.Text,
				PlaceholderColor3 = Theme.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
				ClipsDescendants = true,
				[React.Change.Text] = function(box)
					props.OnSearch(box.Text)
				end,
			}),
		}),
		Sort = e(SortButton, {
			Label = sortLabels[props.Sort] or props.Sort,
			Frame = props.SortFrame,
			OnClick = props.OnSort,
		}),
	})
end

return UnitFilters
