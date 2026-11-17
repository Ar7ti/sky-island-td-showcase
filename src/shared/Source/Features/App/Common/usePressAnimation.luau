-- Springy hover/press scale shared by every pressable HUD element.
-- Returns a ref for a UIScale child and the event handlers to spread onto the GuiButton.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local React = require(ReplicatedStorage.Packages.React)
local soundController = require(ReplicatedStorage.Shared.Features.Services.SoundController.soundController)

local HOVER_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local PRESS_INFO = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_SCALE = 0.93

local function usePressAnimation(hoverScale: number, onClick: (() -> ())?)
	local scaleRef = React.useRef(nil :: UIScale?)
	local tweenRef = React.useRef(nil :: Tween?)
	local hovered = React.useRef(false)

	local function animate(goal: number, info: TweenInfo)
		local scale = scaleRef.current
		if not scale then
			return
		end
		if tweenRef.current then
			tweenRef.current:Cancel()
		end
		local tween = TweenService:Create(scale, info, { Scale = goal })
		tweenRef.current = tween
		tween:Play()
	end

	local events = {
		[React.Event.Activated] = function()
			if onClick then
				soundController:PlaySFX("leftBarClick")
				onClick()
			end
		end,
		[React.Event.MouseEnter] = function()
			hovered.current = true
			animate(hoverScale, HOVER_INFO)
		end,
		[React.Event.MouseLeave] = function()
			hovered.current = false
			animate(1, HOVER_INFO)
		end,
		[React.Event.MouseButton1Down] = function()
			animate(PRESS_SCALE, PRESS_INFO)
		end,
		[React.Event.MouseButton1Up] = function()
			animate(if hovered.current then hoverScale else 1, HOVER_INFO)
		end,
	}

	return scaleRef, events
end

return usePressAnimation
