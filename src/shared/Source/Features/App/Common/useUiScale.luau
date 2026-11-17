-- Returns the factor that turns 1080p pixel sizes into the current screen size.
-- Height drives the scale; width caps it so narrow screens still fit the top row.
-- Touch screens get a boost so buttons stay big enough for fingers on small phones.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local React = require(ReplicatedStorage.Packages.React)

local compute = require(script.Parent.UiScale).compute

local function useUiScale(): number
	local scale, setScale = React.useState(compute)

	React.useEffect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local function update()
			setScale(compute())
		end
		local viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		local inputConnection = UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(update)
		-- The "Interface size" setting changes the scale too (GameSettings mirrors it into this attribute).
		local player = game:GetService("Players").LocalPlayer
		local sizeConnection = if player then player:GetAttributeChangedSignal("UiSize"):Connect(update) else nil
		update()
		return function()
			viewportConnection:Disconnect()
			inputConnection:Disconnect()
			if sizeConnection then
				sizeConnection:Disconnect()
			end
		end
	end, {})

	return scale
end

return useUiScale
