-- Client view of the player's rewards save (Data.client.rewards) plus the live clock the
-- rewards window needs: server time, today's UTC day and seconds played today.
-- The server writes playtime every few seconds; between writes it is counted up locally.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local React = require(ReplicatedStorage.Packages.React)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Data = require(ReplicatedStorage.Shared.Features.Services.DataService.Data).client
local Rewards = require(ReplicatedStorage.Shared.Features.Services.Rewards.Rewards)

-- A little over the server's write step (RewardsService PLAYTIME_STEP), so the counter never runs ahead for long.
local MAX_LOCAL_PLAYTIME = 12

export type Snapshot = {
	save: Rewards.SaveData,
	now: number, -- server time, seconds
	today: number,
	playtime: number, -- seconds played today
}

export type Granted = {
	kind: "Coins" | "Gems" | "Tower" | "Chest" | "Item",
	itemId: string?, -- kind "Item" (Items/ItemsConfig)
	amount: number?,
	towerId: string?,
	crate: string?,
	count: number?, -- the same tower several times (RewardReveal stacks them)
	shards: number?, -- kind "Tower": a duplicate of a fully starred tower, salvaged into shards (TowerGrants)
}

export type ClaimResult = {
	ok: boolean,
	granted: { Granted }?,
	error: string?,
}

local save: Rewards.SaveData = Rewards.Template
local receivedAt = os.clock()

local function readSave()
	local raw = Data.rewards()
	if type(raw) ~= "table" then
		return
	end
	local copy = table.clone(raw)
	copy.playtimeClaimed = table.clone(raw.playtimeClaimed or {})
	save = copy
	receivedAt = os.clock()
end
readSave()
Data.rewards.Changed(readSave)

local useRewards = {}

function useRewards.snapshot(): Snapshot
	local now = Workspace:GetServerTimeNow()
	local today = Rewards.dayOf(now)
	local playtime = Rewards.playtimeToday(save, today)
	if save.playtimeDay == today then
		playtime += math.min(os.clock() - receivedAt, MAX_LOCAL_PLAYTIME)
	end
	return { save = save, now = now, today = today, playtime = math.floor(playtime) }
end

-- Re-renders every second (timers) and whenever the save changes.
function useRewards.use(): Snapshot
	local snapshot, setSnapshot = React.useState(useRewards.snapshot)
	React.useEffect(function()
		local running = true
		local disconnect = Data.rewards.Changed(function()
			-- readSave (connected first) has already stored the new save.
			setSnapshot(useRewards.snapshot())
		end)
		task.spawn(function()
			while running do
				task.wait(1)
				if running then
					setSnapshot(useRewards.snapshot())
				end
			end
		end)
		return function()
			running = false
			disconnect()
		end
	end, {})
	return snapshot
end

-- Rewards waiting to be claimed, for the HUD bubble. Only re-renders when the count changes.
function useRewards.usePending(): number
	local count, setCount = React.useState(0)
	React.useEffect(function()
		local running = true
		task.spawn(function()
			while running do
				local snapshot = useRewards.snapshot()
				setCount(Rewards.pendingCount(snapshot.save, snapshot.now, snapshot.playtime))
				task.wait(1)
			end
		end)
		return function()
			running = false
		end
	end, {})
	return count
end

local networker
-- Yields until the server answers.
function useRewards.claim(method: "ClaimDaily" | "ClaimPlaytime", ...: any): ClaimResult
	if not networker then
		networker = Networker.client.new("RewardsService", {})
	end
	local ok, result = pcall(networker.fetch, networker, method, ...)
	if not ok or type(result) ~= "table" then
		return { ok = false, error = "Something went wrong, try again" }
	end
	return result
end

return useRewards
