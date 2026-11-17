-- The party pad the local player stands on and its live state (set by the lobby PartyPads script).
-- Returns nil when the player is not on a pad.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local PartyShared = require(ReplicatedStorage.Shared.Features.Services.Parties.PartyShared)
local usePlayerAttribute = require(ReplicatedStorage.Shared.Source.Features.App.Common.usePlayerAttribute)

export type PartyState = {
	count: number?,
	max: number?,
	timeLeft: number?,
	status: string?,
	mapName: string?,
	leader: number?, -- UserId of the pad's first member, who picks the map
}

local function findPad(padId: number): Instance?
	for _, pad in CollectionService:GetTagged(PartyShared.Tag) do
		if pad:GetAttribute("PadId") == padId then
			return pad
		end
	end
	return nil
end

local function usePartyState(): PartyState?
	local padId = usePlayerAttribute(PartyShared.PlayerPadAttribute)
	local state, setState = React.useState({} :: PartyState)

	React.useEffect(function()
		local pad = if padId then findPad(padId) else nil
		if not pad then
			setState({})
			return
		end
		local function read()
			setState({
				count = pad:GetAttribute("Count"),
				max = pad:GetAttribute("Max"),
				timeLeft = pad:GetAttribute("TimeLeft"),
				status = pad:GetAttribute("Status"),
				mapName = pad:GetAttribute("MapName"),
				leader = pad:GetAttribute("Leader"),
			})
		end
		local connection = pad.AttributeChanged:Connect(read)
		read()
		return function()
			connection:Disconnect()
		end
	end, { padId })

	-- The pad model may still be streaming in; the player is in a party all the same.
	return if padId then state else nil
end

return usePartyState
