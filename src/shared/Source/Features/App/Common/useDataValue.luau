-- Subscribes a component to one player data value (Data.client.<key>) and returns its current value.
-- A nil key returns nil, so callers can use the hook unconditionally for optional values.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Data = require(ReplicatedStorage.Shared.Features.Services.DataService.Data).client

local function disconnect(subscription)
	if type(subscription) == "function" then
		subscription()
	elseif typeof(subscription) == "RBXScriptConnection" then
		subscription:Disconnect()
	end
end

local function useDataValue(key: string?): any
	local value, setValue = React.useState(function()
		return if key then Data[key]() else nil
	end)

	React.useEffect(function()
		if not key then
			return
		end
		local subscription = Data[key].Changed(function()
			setValue(Data[key]())
		end)
		setValue(Data[key]())
		return function()
			disconnect(subscription)
		end
	end, { key })

	return value
end

return useDataValue
