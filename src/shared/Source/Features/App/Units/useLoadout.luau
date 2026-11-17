-- The local player's resolved tower loadout (see TowersServices/Loadout), kept in sync with saved data.
-- SetSlot asks LoadoutService (lobby server) to change a slot; the new loadout replicates back.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker)
local Loadout = require(ReplicatedStorage.Shared.Features.Services.TowersServices.Loadout)
local useDataValue = require(ReplicatedStorage.Shared.Source.Features.App.Common.useDataValue)

local networker = nil

local function setSlot(slot: number, towerId: string?)
	if not networker then
		networker = Networker.client.new("LoadoutService", {})
	end
	networker:fire("SetSlot", slot, towerId)
end

export type State = {
	slots: Loadout.Slots,
	unlocked: number,
	SetSlot: (slot: number, towerId: string?) -> (),
}

local function useLoadout(): State
	local saved = useDataValue("loadout")
	local inventory = useDataValue("inventory")
	local unlocked = Loadout.UnlockedCount(useDataValue("unlockedLoadoutSlots"))

	return {
		slots = Loadout.Resolve(saved, inventory, unlocked),
		unlocked = unlocked,
		SetSlot = setSlot,
	}
end

return useLoadout
