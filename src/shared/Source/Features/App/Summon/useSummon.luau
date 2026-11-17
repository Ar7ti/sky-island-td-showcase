-- Summon window data: the player's coins, gems and guarantee counters, server time for the event timer,
-- whether paid random items are allowed here, and the Summon request to SummonService.
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local React = require(ReplicatedStorage.Packages.React)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Currencies = require(ReplicatedStorage.Shared.Features.Services.Economy.Currencies)
local Banners = require(ReplicatedStorage.Shared.Features.Services.Summon.Banners)
local useDataValue = require(ReplicatedStorage.Shared.Source.Features.App.Common.useDataValue)

-- shards: a duplicate of a fully starred tower, salvaged into this many shards (SharedServer TowerGrants).
export type PullResult = { towerId: string, rarity: string, featured: boolean, isNew: boolean, shards: number? }
export type SummonResult = { ok: boolean, error: string?, results: { PullResult }? }

export type Snapshot = {
	coins: number,
	gems: number,
	pity: { [string]: Banners.PityState },
	now: number,
	paidRandomAllowed: boolean?, -- nil while the policy is still loading
}

local useSummon = {}

-- Bright rarity colors for frames, glows and labels.
useSummon.RarityColors = {
	Common = Color3.fromRGB(170, 190, 200),
	Normal = Color3.fromRGB(90, 225, 200),
	Rare = Color3.fromRGB(70, 160, 255),
	Epic = Color3.fromRGB(190, 100, 255),
	Legendary = Color3.fromRGB(255, 200, 50),
	Mythic = Color3.fromRGB(255, 80, 70),
} :: { [string]: Color3 }

function useSummon.color(rarity: string?): Color3
	return rarity and useSummon.RarityColors[rarity] or useSummon.RarityColors.Common
end

function useSummon.balance(snapshot: Snapshot, currency: Banners.Currency): number
	return if currency == "Gems" then snapshot.gems else snapshot.coins
end

local policyAllowed: boolean? = nil
local function loadPolicy(): boolean
	if policyAllowed == nil then
		local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, Players.LocalPlayer)
		policyAllowed = ok and info.ArePaidRandomItemsRestricted ~= true
	end
	return policyAllowed :: boolean
end

function useSummon.use(): Snapshot
	local coins = useDataValue(Currencies.CoinsKey) or 0
	local gems = useDataValue(Currencies.GemsKey) or 0
	local pity = useDataValue("summon") or {}
	local now, setNow = React.useState(function()
		return Workspace:GetServerTimeNow()
	end)
	local allowed, setAllowed = React.useState(policyAllowed)

	React.useEffect(function()
		local running = true
		task.spawn(function()
			local value = loadPolicy()
			if running then
				setAllowed(value)
			end
		end)
		task.spawn(function()
			while running do
				setNow(Workspace:GetServerTimeNow())
				task.wait(1)
			end
		end)
		return function()
			running = false
		end
	end, {})

	return { coins = coins, gems = gems, pity = pity, now = now, paidRandomAllowed = allowed }
end

local networker
-- Yields until the server answers.
function useSummon.summon(bannerId: string, count: number): SummonResult
	if not networker then
		networker = Networker.client.new("SummonService", {})
	end
	local ok, result = pcall(networker.fetch, networker, "Summon", bannerId, count)
	if not ok or type(result) ~= "table" then
		return { ok = false, error = "Something went wrong, try again" }
	end
	return result
end

return useSummon
