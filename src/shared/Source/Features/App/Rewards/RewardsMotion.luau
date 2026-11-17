-- Small tween hooks shared by the rewards window. Each one animates the instance behind a ref
-- and cancels its tween when the component unmounts (or the effect re-runs).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local React = require(ReplicatedStorage.Packages.React)

local RewardsMotion = {}

RewardsMotion.Pop = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

function RewardsMotion.play(instance: Instance?, from: { [string]: any }?, goal: { [string]: any }, info: TweenInfo): Tween?
	if not instance then
		return nil
	end
	if from then
		for property, value in from do
			(instance :: any)[property] = value
		end
	end
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	return tween
end

-- Plays from -> goal once when mounted, and again whenever a value in deps changes.
function RewardsMotion.useEnter(ref: { current: any }, from: { [string]: any }, goal: { [string]: any }, info: TweenInfo, deps: { any }?)
	React.useEffect(function()
		local tween = RewardsMotion.play(ref.current, from, goal, info)
		return function()
			if tween then
				tween:Cancel()
			end
		end
	end, deps or {})
end

-- Endless back-and-forth towards goal while enabled; the values snap back when it stops.
function RewardsMotion.useLoop(ref: { current: any }, goal: { [string]: any }, info: TweenInfo, enabled: boolean?)
	local active = enabled ~= false
	React.useEffect(function()
		local instance = ref.current
		if not instance or not active then
			return
		end
		local start = {}
		for property in goal do
			start[property] = instance[property]
		end
		local tween = RewardsMotion.play(instance, nil, goal, info)
		return function()
			if tween then
				tween:Cancel()
			end
			for property, value in start do
				instance[property] = value
			end
		end
	end, { active })
end

-- Counts from 0 up to target over the given time (for "+500" style numbers).
function RewardsMotion.useCountUp(target: number, duration: number, delay: number): number
	local value, setValue = React.useState(0)
	React.useEffect(function()
		local running = true
		task.spawn(function()
			task.wait(delay)
			local started = os.clock()
			while running do
				local alpha = math.min((os.clock() - started) / duration, 1)
				setValue(math.floor(target * (1 - (1 - alpha) ^ 3) + 0.5))
				if alpha >= 1 then
					break
				end
				task.wait()
			end
		end)
		return function()
			running = false
		end
	end, { target })
	return value
end

return RewardsMotion
