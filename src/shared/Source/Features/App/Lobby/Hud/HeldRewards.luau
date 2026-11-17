-- Values the lobby HUD holds back while match rewards fly into it (see RewardArrival):
--   HeldRewards.Set("currency", 350)   -- the coin pill shows its saved amount minus 350
--   HeldRewards.Set("Level", { Level = 12, Experience = 600 }) -- the player card shows this instead
-- Set a key to nil to show the real value again.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local values: { [string]: any } = {}
local changed = Instance.new("BindableEvent")

local HeldRewards = {}

function HeldRewards.Set(key: string, value: any)
	values[key] = value
	changed:Fire(key)
end

function HeldRewards.Get(key: string): any
	return values[key]
end

-- React hook: the held value for a key (nil when nothing is held), re-rendering on change.
function HeldRewards.use(key: string?): any
	local value, setValue = React.useState(function()
		return if key then values[key] else nil
	end)
	React.useEffect(function()
		if not key then
			return
		end
		setValue(values[key])
		local connection = changed.Event:Connect(function(changedKey)
			if changedKey == key then
				setValue(values[key])
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { key })
	return value
end

return HeldRewards
