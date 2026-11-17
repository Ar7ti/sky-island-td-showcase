local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function buildSchedule(wave, enemies)
	assert(type(wave.Groups) == "table", "Wave needs Groups")
	assert(finite(wave.Preparation) and wave.Preparation >= 0 and wave.Preparation % 1 == 0, "Invalid preparation")
	assert(finite(wave.CompletionReward) and wave.CompletionReward >= 0, "Invalid wave reward")
	local schedule = {}
	for _, group in ipairs(wave.Groups) do
		assert(enemies[group.Enemy], "Unknown enemy: " .. tostring(group.Enemy))
		assert(finite(group.Count) and group.Count >= 0 and group.Count % 1 == 0, "Invalid enemy count")
		assert(finite(group.Interval) and group.Interval >= 0, "Invalid spawn interval")
		assert(finite(group.StartDelay) and group.StartDelay >= 0, "Invalid spawn delay")
		for index = 1, group.Count do
			table.insert(schedule, { Time = group.StartDelay + (index - 1) * group.Interval, Group = group, Order = #schedule + 1 })
		end
	end
	table.sort(schedule, function(a, b)
		return if a.Time == b.Time then a.Order < b.Order else a.Time < b.Time
	end)
	return schedule
end

return buildSchedule
