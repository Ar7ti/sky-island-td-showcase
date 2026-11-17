local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local React = require(ReplicatedStorage.Packages.React)
local Notify = require(ReplicatedStorage.Shared.Features.Services.Notify.Notify)
local e = React.createElement

local ENTER_TIME = 0.5
local ENTER_TWEEN = TweenInfo.new(ENTER_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
local ITEM_SPACING = 8
-- Each kind can have its own color, maximum text size and row height.
local STYLES = {
	error = { Color = Color3.fromRGB(255, 100, 100), TextSize = 32, Height = 44 },
	success = { Color = Color3.fromRGB(120, 255, 150), TextSize = 32, Height = 44 },
	info = { Color = Color3.fromRGB(255, 253, 253), TextSize = 48, Height = 64 },
	warning = { Color = Color3.fromRGB(255, 210, 90), TextSize = 32, Height = 44 },
}

local function getStyle(kind: string)
	return STYLES[kind] or STYLES.info
end

local function NotificationItem(props: { Notification: Notify.Notification, OnFinished: (number) -> () })
	local notification = props.Notification
	local style = getStyle(notification.kind)
	local onFinished = props.OnFinished
	local textRef = React.useRef(nil :: TextLabel?)
	local scaleRef = React.useRef(nil :: UIScale?)
	local strokeRef = React.useRef(nil :: UIStroke?)

	React.useEffect(function()
		local label = textRef.current
		local scale = scaleRef.current
		local stroke = strokeRef.current
		if not label or not scale or not stroke then
			return
		end

		scale.Scale = 0
		label.TextTransparency = 0
		stroke.Transparency = 0
		local active = true
		local scaleTween = TweenService:Create(scale, ENTER_TWEEN, { Scale = 1 })
		local textTween = TweenService:Create(label, FADE_TWEEN, { TextTransparency = 1 })
		local strokeTween = TweenService:Create(stroke, FADE_TWEEN, { Transparency = 1 })
		local completed = textTween.Completed:Connect(function(playbackState)
			if active and playbackState == Enum.PlaybackState.Completed then
				-- RootUI removes the item from state; React removes its Instances.
				onFinished(notification.id)
			end
		end)

		scaleTween:Play()
		local fadeTask: thread? = task.delay(ENTER_TIME + notification.duration, function()
			if active then
				textTween:Play()
				strokeTween:Play()
			end
		end)

		return function()
			active = false
			completed:Disconnect()
			if fadeTask and coroutine.status(fadeTask) ~= "dead" then
				task.cancel(fadeTask)
			end
			for _, tween in ipairs({ scaleTween, textTween, strokeTween }) do
				tween:Cancel()
				tween:Destroy()
			end
		end
	end, { notification.id, notification.duration, onFinished })

	-- A fixed slot keeps the list stable while the text scales up inside it.
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, style.Height),
		BackgroundTransparency = 1,
		LayoutOrder = notification.id,
		ZIndex = 100,
	}, {
		TextLabel = e("TextLabel", {
			ref = textRef,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = notification.text,
			TextColor3 = style.Color,
			TextTransparency = 0,
			TextScaled = true,
			TextWrapped = true,
			Font = Enum.Font.FredokaOne,
			ZIndex = 100,
		}, {
			UIScale = e("UIScale", {
				ref = scaleRef,
				Scale = 0,
			}),
			UIStroke = e("UIStroke", {
				ref = strokeRef,
				Color = Color3.fromRGB(2, 2, 2),
				Thickness = 3,
				Transparency = 0,
			}),
			TextSizeConstraint = e("UITextSizeConstraint", {
				MinTextSize = 12,
				MaxTextSize = style.TextSize,
			}),
		}),
	})
end

-- How far the list moves up while the tower placement bar is on screen.
local RAISED_OFFSET = -70
local SHIFT_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function Notifications(props: { Items: { Notify.Notification }, OnFinished: (number) -> (), Raised: boolean? })
	local frameRef = React.useRef(nil :: Frame?)
	local targetPosition = UDim2.new(0.5, 0, 0.77, if props.Raised then RAISED_OFFSET else 0)
	-- Only the first position goes through props; later moves are tweened.
	local initialPosition = React.useRef(targetPosition).current
	React.useEffect(function()
		local frame = frameRef.current
		if not frame then return end
		local tween = TweenService:Create(frame, SHIFT_TWEEN, { Position = targetPosition })
		tween:Play()
		return function() tween:Cancel() end
	end, { props.Raised })

	local listHeight = math.max(0, #props.Items - 1) * ITEM_SPACING
	for _, notification in ipairs(props.Items) do
		listHeight += getStyle(notification.kind).Height
	end

	local children = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, ITEM_SPACING),
		}),
		SizeConstraint = e("UISizeConstraint", {
			MaxSize = Vector2.new(720, math.max(1, listHeight)),
		}),
	}

	for _, notification in ipairs(props.Items) do
		children["Notification_" .. notification.id] = e(NotificationItem, {
			Notification = notification,
			OnFinished = props.OnFinished,
		})
	end

	return e("Frame", {
		ref = frameRef,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = initialPosition,
		Size = UDim2.new(0.85, 0, 0, listHeight),
		BackgroundTransparency = 1,
		Visible = #props.Items > 0,
		ZIndex = 100,
	}, children)
end

return Notifications
