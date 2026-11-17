-- Walks an enemy along Map.Path (numbered waypoint parts). The waypoint it is heading to is kept in the
-- model's PathIndex attribute, so PushBack can move it back along the path and the walk carries on from
-- there (forward again, never turned around).
local TweenService = game:GetService("TweenService")

local EnemyMovement = {}

local PUSH_IMMUNITY = 2 -- seconds after a push before the same enemy can be pushed again

local walking: { [Model]: { points: { Vector3 }, start: Vector3 } } = {}

local function alive(model, humanoid)
	return model.Parent ~= nil and humanoid.Health > 0
end

-- Walks to points[index]. Returns "reached", "moved" (PathIndex changed by a push) or "failed".
local function moveTo(points, index, model, humanoid)
	local point = points[index]
	local reached = false
	local connection = humanoid.MoveToFinished:Connect(function(success)
		reached = success
	end)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		connection:Disconnect()
		return "failed"
	end
	local timeout = math.clamp((root.Position - point).Magnitude / math.max(humanoid.WalkSpeed, 1) * 3, 20, 120)
	local deadline = os.clock() + timeout
	local nextRetry = 0
	local result = "failed"
	while alive(model, humanoid) and os.clock() < deadline do
		if model:GetAttribute("Pushing") then
			-- Anchored while being pushed: the walk resumes once the push sets the new PathIndex.
			reached = false
			nextRetry = 0
			deadline = os.clock() + timeout
			task.wait(0.05)
			continue
		end
		if model:GetAttribute("PathIndex") ~= index then
			result = "moved"
			break
		end
		if reached then
			result = "reached"
			break
		end
		if os.clock() >= nextRetry then
			humanoid:MoveTo(point)
			nextRetry = os.clock() + 6
		end
		task.wait(0.1)
	end
	connection:Disconnect()
	if result == "failed" and alive(model, humanoid) then
		warn("Enemy stuck at waypoint: " .. model.Name)
	end
	return result
end

function EnemyMovement.StartMovement(path, model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return false
	end
	local waypoints = {}
	for _, point in ipairs(path:GetChildren()) do
		if point:IsA("BasePart") and tonumber(point.Name) then
			table.insert(waypoints, point)
		end
	end
	table.sort(waypoints, function(a, b)
		return tonumber(a.Name) < tonumber(b.Name)
	end)
	if #waypoints == 0 then
		return false
	end
	local points = {}
	for i, part in waypoints do
		points[i] = part.Position
	end
	walking[model] = { points = points, start = root.Position }

	-- Split children start where their parent was heading.
	local index = math.clamp(tonumber(model:GetAttribute("StartPathIndex")) or 1, 1, #points)
	model:SetAttribute("PathIndex", index)
	local finished = false
	while alive(model, humanoid) do
		local result = moveTo(points, index, model, humanoid)
		if result == "failed" then
			break
		elseif result == "moved" then
			index = model:GetAttribute("PathIndex")
		else
			index += 1
			if index > #points then
				finished = true
				break
			end
			model:SetAttribute("PathIndex", index)
		end
	end
	walking[model] = nil
	return finished and alive(model, humanoid)
end

-- Moves a walking enemy `distance` studs back along the path over `duration` seconds, still facing the
-- way it walks, then lets it walk on. Returns false when it can't be pushed now (not walking, mid-push
-- or pushed less than PUSH_IMMUNITY seconds ago).
function EnemyMovement.PushBack(model: Model, distance: number, duration: number?): boolean
	local info = walking[model]
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not info or not humanoid or not root or humanoid.Health <= 0 or distance <= 0 then
		return false
	end
	if model:GetAttribute("Pushing") or (model:GetAttribute("PushImmuneUntil") or 0) > os.clock() then
		return false
	end
	local index = model:GetAttribute("PathIndex")
	if type(index) ~= "number" then
		return false
	end

	-- Walk back from the current position through the previous waypoints (the spawn point before the first).
	local function pointAt(i)
		return if i >= 1 then info.points[i] else info.start
	end
	local here = root.Position
	local flat = Vector3.new(1, 0, 1)
	local current = here
	local target = index -- the waypoint the enemy heads to after the push
	local left = distance
	while left > 0 and target >= 1 do
		local previous = pointAt(target - 1)
		local gap = ((previous - current) * flat).Magnitude
		if gap >= left then
			current += ((previous - current) * flat).Unit * left
			left = 0
		else
			current = Vector3.new(previous.X, current.Y, previous.Z)
			left -= gap
			target -= 1
		end
	end
	target = math.max(target, 1)
	if ((current - here) * flat).Magnitude < 0.5 then
		return false
	end

	-- Ground height at the destination (path may climb); keep the root's height above the ground.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model, workspace:FindFirstChild("Towers"), workspace:FindFirstChild("ZombiesOnMap") }
	local hipToRoot = humanoid.HipHeight + root.Size.Y / 2
	local destinationY = here.Y
	local hit = workspace:Raycast(Vector3.new(current.X, here.Y + 6, current.Z), Vector3.new(0, -20, 0), params)
	if hit then
		destinationY = hit.Position.Y + hipToRoot
	end
	local destination = Vector3.new(current.X, destinationY, current.Z)
	local ahead = pointAt(target)
	local look = (ahead - destination) * flat
	local cframe = if look.Magnitude > 0.1
		then CFrame.lookAt(destination, destination + look)
		else CFrame.new(destination) * root.CFrame.Rotation

	model:SetAttribute("Pushing", true)
	model:SetAttribute("PushCount", (model:GetAttribute("PushCount") or 0) + 1)
	root.Anchored = true
	local tween = TweenService:Create(root, TweenInfo.new(duration or 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = cframe })
	tween:Play()
	task.delay(duration or 0.35, function()
		if root.Parent then
			root.Anchored = false
		end
		model:SetAttribute("PushImmuneUntil", os.clock() + PUSH_IMMUNITY)
		model:SetAttribute("PathIndex", target)
		model:SetAttribute("Pushing", nil)
		if humanoid.Health > 0 and model.Parent then
			humanoid:MoveTo(info.points[target])
		end
	end)
	return true
end

return EnemyMovement
