-- The match menu (MENU button, top right): RESUME, SETTINGS and LEAVE TO LOBBY. Leaving asks first ("Leave the
-- match?"), then asks ReturnService (ReturnRemotes.LeaveMatch) to send the player back to the lobby; the server
-- pays a leaver for the waves cleared so far (MatchRewards), without the win bonus, and resets the win streak.
-- Drawn with the Units window kit (UnitsArt), like the lobby windows.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local React = require(ReplicatedStorage.Packages.React)
local App = ReplicatedStorage.Shared.Source.Features.App
local OutlinedText = require(App.Common.OutlinedText)
local Theme = require(App.Common.Theme)
local ImageButton = require(App.Common.ImageButton)
local useUiScale = require(App.Common.useUiScale)
local usePressAnimation = require(App.Common.usePressAnimation)
local UnitsArt = require(App.Units.UnitsArt)
local HudArt = require(script.Parent.HudArt)
local soundController = require(ReplicatedStorage.Shared.Features.Services.SoundController.soundController)
local e = React.createElement

local WINDOW = Vector2.new(560, 520)
local HEADER = Vector2.new(340, 92)
local BUTTON = Vector2.new(420, 92)
local CLOSE = Vector2.new(74, 74)
local OPEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local WARN = Color3.fromRGB(255, 196, 92)

export type Props = {
	Wave: number,
	TotalWaves: number,
	WavesCleared: number,
	OnClose: () -> (),
	OnSettings: () -> (),
	OnLeave: () -> (),
}

-- A wide menu button on one of the kit's bases: green (Equip), red (Red) or dark (Sort).
local function MenuButton(props: {
	Base: UnitsArt.Sliced,
	Text: string,
	Icon: string?,
	Order: number,
	Disabled: boolean?,
	OnClick: () -> (),
})
	local scaleRef, events = usePressAnimation(1.04, if props.Disabled then nil else props.OnClick)
	local buttonProps = {
		Size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
		LayoutOrder = props.Order,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
	}
	for key, handler in events do
		buttonProps[key] = handler
	end
	return e("TextButton", buttonProps, {
		Body = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, {
			Scale = e("UIScale", { ref = scaleRef, Scale = 1 }),
			Base = e(UnitsArt.Panel, {
				Art = props.Base,
				Size = UDim2.fromScale(1, 1),
				SliceScale = 0.8,
				Color = if props.Disabled then Color3.fromRGB(150, 150, 150) else nil,
			}),
			Icon = props.Icon and props.Icon ~= "" and e("ImageLabel", {
				Image = props.Icon,
				Size = UDim2.fromOffset(52, 52),
				Position = UDim2.new(0, 34, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 2,
			}),
			Label = e(OutlinedText, {
				Text = props.Text,
				Size = UDim2.new(1, -150, 0, 44),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				StrokeThickness = 3,
				ZIndex = 2,
			}),
		}),
	})
end

local function MatchMenuWindow(props: Props)
	local scale = useUiScale()
	local confirming, setConfirming = React.useState(false)
	local leaving, setLeaving = React.useState(false)
	local openRef = React.useRef(nil :: UIScale?)
	local mounted = React.useRef(true)
	React.useEffect(function()
		return function()
			mounted.current = false
		end
	end, {})
	React.useEffect(function()
		local open = openRef.current
		if open then
			open.Scale = 0.7
			TweenService:Create(open, OPEN_INFO, { Scale = 1 }):Play()
		end
	end, { confirming })

	local images = HudArt.Images
	local body
	if confirming then
		body = {
			Question = e(OutlinedText, {
				Text = "LEAVE THE MATCH?",
				Size = UDim2.fromOffset(460, 50),
				LayoutOrder = 1,
				Color = WARN,
				StrokeThickness = 4,
			}),
			Note = e(OutlinedText, {
				Text = if props.WavesCleared > 0
					then "You keep the coins for the waves you cleared,\nbut lose the victory bonus and your win streak."
					else "You haven't cleared a wave yet, so you get no coins.\nYour win streak resets.",
				Size = UDim2.fromOffset(470, 64),
				LayoutOrder = 2,
				Color = Theme.TextMuted,
				StrokeThickness = 2,
			}),
			Leave = e(MenuButton, {
				Base = UnitsArt.Red,
				Text = if leaving then "LEAVING..." else "YES, LEAVE",
				Order = 3,
				Disabled = leaving,
				OnClick = function()
					setLeaving(true)
					props.OnLeave()
					-- If the teleport fails (the server shows why), the buttons come back after a while.
					task.delay(12, function()
						if mounted.current then
							setLeaving(false)
						end
					end)
				end,
			}),
			Stay = e(MenuButton, {
				Base = UnitsArt.Equip,
				Text = "NO, KEEP PLAYING",
				Order = 4,
				Disabled = leaving,
				OnClick = function()
					soundController:PlaySFX("leftBarClick")
					setConfirming(false)
				end,
			}),
		}
	else
		body = {
			Wave = e(OutlinedText, {
				Text = `WAVE {props.Wave} / {props.TotalWaves}`,
				Size = UDim2.fromOffset(300, 40),
				LayoutOrder = 1,
				Color = Theme.TextMuted,
				StrokeThickness = 3,
			}),
			Resume = e(MenuButton, {
				Base = UnitsArt.Equip,
				Text = "RESUME",
				Order = 2,
				OnClick = props.OnClose,
			}),
			Settings = e(MenuButton, {
				Base = UnitsArt.Sort,
				Text = "SETTINGS",
				Icon = images.GlyphGear,
				Order = 3,
				OnClick = props.OnSettings,
			}),
			Leave = e(MenuButton, {
				Base = UnitsArt.Red,
				Text = "LEAVE TO LOBBY",
				Order = 4,
				OnClick = function()
					soundController:PlaySFX("leftBarClick")
					setConfirming(true)
				end,
			}),
		}
	end

	-- The dim behind closes the menu (not while leaving). It reaches over the top bar inset too.
	local inset = GuiService:GetGuiInset()
	return e("TextButton", {
		Size = UDim2.new(1, 0, 1, inset.Y),
		Position = UDim2.fromOffset(0, -inset.Y),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 40,
		[React.Event.Activated] = function()
			if not leaving then
				props.OnClose()
			end
		end,
	}, {
		Window = e("TextButton", {
			Size = UDim2.fromOffset(WINDOW.X, WINDOW.Y),
			Position = UDim2.fromScale(0.5, 0.52),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 41,
		}, {
			Fit = e("UIScale", { Scale = scale }),
			Body = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
			}, {
				Open = e("UIScale", { ref = openRef, Scale = 1 }),
				Panel = e(UnitsArt.Panel, {
					Art = UnitsArt.Window,
					Size = UDim2.fromScale(1, 1),
					SliceScale = 1.4,
				}),
				Header = e(UnitsArt.Panel, {
					Art = UnitsArt.Header,
					Size = UDim2.fromOffset(HEADER.X, HEADER.Y),
					Position = UDim2.new(0.5, 0, 0, -30),
					AnchorPoint = Vector2.new(0.5, 0),
					SliceScale = 0.9,
					ZIndex = 2,
				}, {
					Title = e(OutlinedText, {
						Text = if confirming then "LEAVE" else "MENU",
						ZIndex = 3, -- over the header tab when the ScreenGui uses global ZIndex
						Size = UDim2.new(1, -120, 0, 52),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						StrokeThickness = 4,
					}),
				}),
				Close = not leaving and e(ImageButton, {
					Art = UnitsArt.CloseButton,
					Size = UDim2.fromOffset(CLOSE.X, CLOSE.Y),
					Position = UDim2.new(1, -14, 0, 14),
					AnchorPoint = Vector2.new(1, 0),
					OnClick = props.OnClose,
				}, {
					X = e(UnitsArt.Icon, {
						Art = UnitsArt.Icons.CloseX,
						Size = UDim2.fromScale(0.52, 0.52),
						Position = UDim2.fromScale(0.5, 0.48),
						AnchorPoint = Vector2.new(0.5, 0.5),
					}),
				}),
				List = e("Frame", {
					Size = UDim2.new(1, 0, 1, -110),
					Position = UDim2.fromOffset(0, 90),
					BackgroundTransparency = 1,
					ZIndex = 3,
				}, {
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 18),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					Items = e(React.Fragment, nil, body),
				}),
			}),
		}),
	})
end

return MatchMenuWindow
