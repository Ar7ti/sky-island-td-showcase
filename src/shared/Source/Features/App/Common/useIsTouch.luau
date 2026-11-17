-- True while the player's primary input is a touch screen (UserInputService.PreferredInput).
-- Unlike TouchEnabled/KeyboardEnabled it follows a phone that gets a keyboard or gamepad connected.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local React = require(ReplicatedStorage.Packages.React)

-- Studio only: the phone preview (tools/studio/phone_preview.py) sets Workspace attribute UiPreviewTouch.
-- nil everywhere else, so real devices are never affected.
local function preview(): boolean?
	if not RunService:IsStudio() then
		return nil
	end
	local value = Workspace:GetAttribute("UiPreviewTouch")
	return if type(value) == "boolean" then value else nil
end

local function isTouch(): boolean
	local previewed = preview()
	if previewed ~= nil then
		return previewed
	end
	return UserInputService.PreferredInput == Enum.PreferredInput.Touch
end

local function useIsTouch(): boolean
	local touch, setTouch = React.useState(isTouch)

	React.useEffect(function()
		local connection = UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
			setTouch(isTouch())
		end)
		setTouch(isTouch())
		return function()
			connection:Disconnect()
		end
	end, {})

	return touch
end

return {
	isTouch = isTouch,
	preview = preview,
	use = useIsTouch,
}
