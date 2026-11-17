local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Networker = require(ReplicatedStorage.Packages.Networker)
local React = require(ReplicatedStorage.Packages.React)
local soundController = require(ReplicatedStorage.Shared.Features.Services.SoundController.soundController)
local Notify = require(ReplicatedStorage.Shared.Features.Services.Notify.Notify)
local Data = require(ReplicatedStorage.Shared.Features.Services.DataService.Data).client

local Base = require(ReplicatedStorage.Shared.Source.Features.App.BaseGUI.Base)
local MatchMenu = require(ReplicatedStorage.Shared.Source.Features.App.MatchHud.MatchMenu)
local MatchMenuWindow = require(ReplicatedStorage.Shared.Source.Features.App.MatchHud.MatchMenuWindow)
local ReadyButton = require(ReplicatedStorage.Shared.Source.Features.App.MatchHud.ReadyButton)
local TutorialCoach = require(ReplicatedStorage.Shared.Source.Features.App.MatchHud.TutorialCoach)
local ActiveEffects = require(ReplicatedStorage.Shared.Source.Features.App.Lobby.Hud.ActiveEffects)
local Notifications = require(ReplicatedStorage.Shared.Source.Features.App.Notifications.Notifications)
local TowerHotbar = require(ReplicatedStorage.Shared.Source.Features.App.Units.TowerHotbar)
local Settings = require(ReplicatedStorage.Shared.Source.Features.App.Settings.Settings)
local unitsUpgrade = require(ReplicatedStorage.Shared.Source.Features.App.Units.unitsUpgrade)
local UpBar_healthBar = require(ReplicatedStorage.Shared.Source.Features.App.UpBar.UpBar_healthBar)
local TowerBillboards = require(ReplicatedStorage.Shared.Source.Features.App.Units.TowerBillboards)
local ZombiesBillboards = require(ReplicatedStorage.Shared.Source.Features.App.ZombiesBillboards.ZombiesBillboards)
local PlacementState = require(ReplicatedStorage.Shared.Features.Services.TowersServices.PlacementState)
local GameSettings = require(ReplicatedStorage.Shared.Features.Services.Settings.GameSettings)
local AttackRangeZone = require(ReplicatedStorage.Shared.Features.Services.TowersServices.AttackRangeZone)
local TowersConfig = require(ReplicatedStorage.Shared.Features.Services.TowersServices.towersConfig)
local PlacementHints = require(ReplicatedStorage.Shared.Source.Features.App.Units.PlacementHints)
local observeMatchState = require(ReplicatedStorage.Shared.Features.Services.MatchState.ObserveMatchState)
local VictoryScreen = require(ReplicatedStorage.Shared.Source.Features.App.Victory.VictoryScreen)
local Level = require(ReplicatedStorage.Shared.Features.Services.LevelService.Level)
local BaseModel = workspace:WaitForChild("Map"):WaitForChild("Base")

local zombies = Workspace:WaitForChild("ZombiesOnMap")

local e = React.createElement
local isTouch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local towersWorkspace = game.Workspace.Towers

-- ReturnService (match server) teleports the player back to the lobby.
local function requestReturnToLobby(playAgain: boolean)
	local remotes = ReplicatedStorage:FindFirstChild("ReturnRemotes")
	local remote = remotes and remotes:FindFirstChild("ReturnToLobby")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(playAgain)
	end
end

-- Leaving mid-match (match menu, after the player confirmed): ReturnService sends them to the lobby.
local function requestLeaveMatch()
	local remotes = ReplicatedStorage:FindFirstChild("ReturnRemotes")
	local remote = remotes and remotes:FindFirstChild("LeaveMatch")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer()
	end
end

local function getPlacedTower(target: Instance?): Model?
	while target and target.Parent ~= towersWorkspace do
		target = target.Parent
	end
	if target and target:IsA("Model") and target:GetAttribute("OwnerId") ~= nil then
		return target
	end
	return nil
end

local function RootUI()
	local selectedTower, setSelectedTower = React.useState(nil :: Model?)
	local isPlacing, setIsPlacing = React.useState(PlacementState.IsActive())
	React.useEffect(function()
		local function refresh(active)
			setIsPlacing(active)
			if active then setSelectedTower(nil) end
		end
		local unsubscribe = PlacementState.Subscribe(refresh)
		refresh(PlacementState.IsActive())
		return unsubscribe
	end, {})
	local settings, setSettings = React.useState(GameSettings.Get)
	React.useEffect(function()
		setSettings(GameSettings.Get())
		return GameSettings.Subscribe(setSettings)
	end, {})
	local upgradePanelRef = React.useRef(nil)
	local towerNetworkerRef = React.useRef(nil)

	-- A selected tower uses its live range value, which changes after upgrades.
	React.useEffect(function()
		if not selectedTower then return end
		local config = TowersConfig[selectedTower.Name]
		if not config then return end
		local zone = AttackRangeZone.new()
		local distanceValue = nil
		local distanceConnection = nil
		local function refresh()
			local root = selectedTower.PrimaryPart or selectedTower:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") then return end

			local instances = selectedTower:FindFirstChild("Instances")
			local currentValue = instances and instances:FindFirstChild("towerAttackDistance")
			if currentValue ~= distanceValue then
				if distanceConnection then distanceConnection:Disconnect() end
				distanceValue = currentValue
				distanceConnection = if currentValue and currentValue:IsA("NumberValue") then currentValue.Changed:Connect(refresh) else nil
			end

			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			local filter = { towersWorkspace }
			if Players.LocalPlayer.Character then
				table.insert(filter, Players.LocalPlayer.Character)
			end
			params.FilterDescendantsInstances = filter
			local result = Workspace:Raycast(root.Position, Vector3.new(0, -100, 0), params)
			local groundPosition = if result then result.Position else root.Position - Vector3.new(0, root.Size.Y / 2, 0)
			zone:Set(if currentValue and currentValue:IsA("NumberValue") then currentValue.Value else config.AttackDistance, groundPosition)
		end
		local addedConnection = selectedTower.DescendantAdded:Connect(refresh)
		local primaryPartConnection = selectedTower:GetPropertyChangedSignal("PrimaryPart"):Connect(refresh)
		refresh()
		return function()
			addedConnection:Disconnect()
			primaryPartConnection:Disconnect()
			if distanceConnection then distanceConnection:Disconnect() end
			zone:Destroy()
		end
	end, { selectedTower })

	React.useEffect(function()
		towerNetworkerRef.current = Networker.client.new("TowerService", {})
	end, {})

	local health, setHealth = React.useState(100)
	local maxHealth, setMaxHealth = React.useState(100)

	local isSettingsOpen, setIsSettingsOpen = React.useState(false)
	local isMenuOpen, setIsMenuOpen = React.useState(false)
	-- Never read: kept because the state change re-renders the HUD when towers are added or removed.
	local _towerCountOnMap, setTowerCountOnMap = React.useState(#towersWorkspace:GetChildren())

	local matchState, setMatchState = React.useState({ Wave = 0, TotalWaves = 10, Phase = "Waiting", Alive = 0, TimeRemaining = 0 })
	local wave = matchState.Wave

	local function networkerNew(Name: string, client: any)
		local networker = Networker.client.new(Name, client)
		return networker
	end

	-- Base health and tower count
	React.useEffect(function()
		local baseClient = {}

		function baseClient:HealthChanged(newHealth, newMaxHealth)
			setHealth(newHealth)
			setMaxHealth(newMaxHealth)
		end

		-- Register handlers before connecting: fetch yields and events can arrive meanwhile.
		local baseNetworker = networkerNew("BaseService", baseClient)
		local currentHealth, currentMaxHealth = baseNetworker:fetch("GetHealth")

		if currentHealth and currentMaxHealth then
			setHealth(currentHealth)
			setMaxHealth(currentMaxHealth)
		end

		local addedConnection = towersWorkspace.ChildAdded:Connect(function()
			setTowerCountOnMap(#towersWorkspace:GetChildren())
		end)

		local removedConnection = towersWorkspace.ChildRemoved:Connect(function()
			setTowerCountOnMap(#towersWorkspace:GetChildren())
		end)

		return function()
			addedConnection:Disconnect()
			removedConnection:Disconnect()
		end
	end, {})

	-- Replicated snapshots also work for players who join in the middle of a match.
	React.useEffect(function()
		local previousWave: number? = nil
		return observeMatchState(function(state)
			local snapshot = if state then state:GetAttributes() else { Wave = 0, Phase = "Waiting", Alive = 0, TimeRemaining = 0 }
			local nextWave = snapshot.Wave or 0
			setMatchState(snapshot)
			if previousWave ~= nil and nextWave > previousWave then
				soundController:PlaySFX("WaveStart")
			end
			previousWave = nextWave
		end)
	end, {})

	-- Base damage thud, plus a heartbeat loop while the base is at 25% HP or less.
	local previousHealthRef = React.useRef(nil :: number?)
	React.useEffect(function()
		local previous = previousHealthRef.current
		previousHealthRef.current = health
		if previous and health < previous then
			soundController:PlaySFX("BaseHit")
		end
	end, { health })
	React.useEffect(function()
		local ratio = if maxHealth > 0 then health / maxHealth else 1
		local finished = matchState.Phase == "Victory" or matchState.Phase == "Defeat"
		soundController:SetLoop("LowHealth", ratio <= 0.25 and health > 0 and not finished)
	end, { health, maxHealth, matchState.Phase } :: { any })

	-- Result screen (Victory / Defeat). The server pays the rewards and publishes them as
	-- MatchState.RewardCoins / RewardGems / RewardXP before switching the phase.
	local healthRef = React.useRef({ health = 100, max = 100 })
	healthRef.current = { health = health, max = maxHealth }
	local matchStartRef = React.useRef(nil :: { time: number }?)
	React.useEffect(function()
		local phase = matchState.Phase
		if matchStartRef.current == nil and phase ~= nil and phase ~= "Waiting" then
			matchStartRef.current = { time = os.clock() }
		end
		if phase ~= "Victory" and phase ~= "Defeat" then
			return
		end
		local won = phase == "Victory"
		setIsSettingsOpen(false)
		setIsMenuOpen(false)
		setSelectedTower(nil)

		local start = matchStartRef.current or { time = os.clock() }
		local totalWaves = matchState.TotalWaves or wave
		-- The server counts cleared waves; Wave alone lags behind during the next wave's preparation.
		local cleared = if won then totalWaves else (matchState.WavesCleared or math.max(0, wave - 1))
		local hp = healthRef.current
		local seconds = math.floor(os.clock() - start.time)
		-- The server pays and publishes RewardCoins/Gems/XP, and sets EndLevelBefore/EndXPBefore on the
		-- player before granting the XP, so the bar can fill from where it was.
		local player = Players.LocalPlayer
		-- The player's own amounts (MatchRewards: bonuses differ per player); MatchState has the base.
		local function own(name: string, fallback: number): number
			local value = player:GetAttribute("End" .. name)
			return if typeof(value) == "number" then value else fallback
		end
		local xp = own("XP", matchState.RewardXP or 0)
		local levelBefore = player:GetAttribute("EndLevelBefore")
		local xpBefore = player:GetAttribute("EndXPBefore")

		VictoryScreen.Show({
			Mode = phase,
			Stats = {
				{
					Icon = "Swords",
					Label = if won then "WAVES CLEARED" else "WAVE REACHED",
					Kind = "fraction",
					To = if won then totalWaves else math.min(cleared + 1, totalWaves),
					Max = totalWaves,
				},
				{ Icon = "Clock", Label = "TIME", Kind = "time", To = seconds },
				{
					Icon = "Shield",
					Label = "BASE HEALTH",
					Kind = "fraction",
					-- A loss drains the bar from full down to zero.
					From = if won then 0 else hp.max,
					To = if won then math.max(0, math.floor(hp.health)) else 0,
					Max = hp.max,
				},
			},
			Rewards = { Coins = own("Coins", matchState.RewardCoins or 0), Gems = own("Gems", matchState.RewardGems or 0), XP = xp },
			Base = { Coins = own("BaseCoins", 0), Gems = own("BaseGems", 0), XP = own("BaseXP", 0) },
			Bonuses = {
				FirstWin = player:GetAttribute("EndFirstWin") == true,
				Streak = own("Streak", 0),
				StreakBonus = own("StreakBonus", 0),
				-- Bag boosts that were running when the match ended (ItemsService).
				BoostCoins = player:GetAttribute("EndBoostCoins") == true,
				BoostXP = player:GetAttribute("EndBoostXP") == true,
				BoostLuck = player:GetAttribute("EndBoostLuck") == true,
			},
			Chest = { Count = own("Chests", 0), Coins = own("ChestCoins", 0), Gems = own("ChestGems", 0) },
			Level = if typeof(levelBefore) == "number" and typeof(xpBefore) == "number"
				then { Before = levelBefore, XPBefore = xpBefore, Gained = xp, Needed = Level.GetNeededExperience }
				else { Before = tonumber(Data.level()) or 1, XPBefore = tonumber(Data.experiencelvl()) or 0, Gained = 0, Needed = Level.GetNeededExperience },
			-- Both go back to the lobby; "play again" also puts the player straight on a party pad there.
			OnPlayAgain = function()
				requestReturnToLobby(true)
			end,
			OnMainMenu = function()
				requestReturnToLobby(false)
			end,
			ReturnAt = function()
				local state = ReplicatedStorage:FindFirstChild("MatchState")
				return state and state:GetAttribute("ReturnAt")
			end,
		})
		soundController:PlaySFX(if won then "Victory" else "Defeat")
		soundController:DuckMusic(if won then 9 else 6.5)
		return function()
			VictoryScreen.Hide()
		end
	end, { matchState.Phase })

	-- The Roblox player list overlaps the HUD.
	React.useEffect(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end, {})

	-- Notifications
	local notifications, setNotifications = React.useState({} :: { Notify.Notification })
	local notificationId = React.useRef(0)

	React.useEffect(function()
		local unsubscribe = Notify:Subscribe(function(kind, text, duration)
			if kind == "error" then
				local sound = if string.find(text, "Not enough money", 1, true) then "NotEnoughMoney" else "ErrorSound"
				soundController:PlaySFX(sound)
			end
			notificationId.current += 1
			local notification: Notify.Notification = {
				id = notificationId.current,
				kind = kind,
				text = text,
				duration = duration,
			}
			setNotifications(function(current)
				local updated = table.clone(current)
				table.insert(updated, notification)
				if #updated > Notify.MaxVisible then
					table.remove(updated, 1)
				end
				return updated
			end)
		end)

		return unsubscribe
	end, {})

	local removeNotification = React.useCallback(function(id: number)
		setNotifications(function(current)
			local updated = {}
			for _, notification in ipairs(current) do
				if notification.id ~= id then
					table.insert(updated, notification)
				end
			end
			return updated
		end)
	end, {})

	-- One client-only highlight follows the hovered placed tower.
	React.useEffect(function()
		if isTouch then return end
		local mouse = Players.LocalPlayer:GetMouse()
		local highlight = Instance.new("Highlight")
		highlight.Name = "TowerHoverHighlight"
		highlight.FillColor = Color3.fromRGB(90, 205, 255)
		highlight.OutlineColor = Color3.fromRGB(190, 240, 255)
		highlight.FillTransparency = 0.8
		highlight.OutlineTransparency = 0.1
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Enabled = false
		highlight.Parent = Workspace

		local connection = RunService.RenderStepped:Connect(function()
			local tower = getPlacedTower(mouse.Target)
			highlight.Adornee = tower
			highlight.Enabled = tower ~= nil
		end)
		return function()
			connection:Disconnect()
			highlight:Destroy()
		end
	end, {})

	--Click on tower
	React.useEffect(function()
		local mouse = Players.LocalPlayer:GetMouse()
		local connection = UserInputService.InputBegan:Connect(function(input, processed)
			if processed or UserInputService:GetFocusedTextBox() then
				return
			end
			if PlacementState.IsActive() then return end
			local isPointer = input.UserInputType == Enum.UserInputType.MouseButton1 or (isTouch and input.UserInputType == Enum.UserInputType.Touch)
			if not isPointer then
				return
			end
			local position = if isTouch then Vector2.new(input.Position.X, input.Position.Y) else UserInputService:GetMouseLocation()
			local panel = upgradePanelRef.current
			if panel then
				local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
				if playerGui then
					for _, gui in ipairs(playerGui:GetGuiObjectsAtPosition(position.X, position.Y)) do
						if gui == panel or gui:IsDescendantOf(panel) then
							return
						end
					end
				end
			end
			if isTouch then
				local camera = Workspace.CurrentCamera
				if not camera then return end
				local ray = camera:ScreenPointToRay(position.X, position.Y)
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = if Players.LocalPlayer.Character then { Players.LocalPlayer.Character } else {}
				local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
				setSelectedTower(getPlacedTower(if result then result.Instance else nil))
			else
				setSelectedTower(getPlacedTower(mouse.Target))
			end
		end)
		local removedConnection = towersWorkspace.ChildRemoved:Connect(function(tower)
			setSelectedTower(function(current)
				return if current == tower then nil else current
			end)
		end)
		local addedConnection = towersWorkspace.ChildAdded:Connect(function(tower)
			if tower:IsA("Model") and tower:GetAttribute("OwnerId") == Players.LocalPlayer.UserId then
				setSelectedTower(tower)
			end
		end)
		return function()
			connection:Disconnect()
			removedConnection:Disconnect()
			addedConnection:Disconnect()
		end
	end, {})

	return e(React.Fragment, nil, {
		PlacementHints = isPlacing and (isTouch or settings.placement_hints) and e(PlacementHints),
		BaseTower = e(Base, {
			Adornee = BaseModel,
			Health = health,
			MaxHealth = maxHealth,
		}),
		MatchMenu = e(MatchMenu, {
			actions = {
				Menu = function()
					setIsSettingsOpen(false)
					setIsMenuOpen(not isMenuOpen)
				end,
			},
		}),
		MatchMenuWindow = isMenuOpen and e(MatchMenuWindow, {
			Wave = wave,
			TotalWaves = matchState.TotalWaves or 15,
			WavesCleared = matchState.WavesCleared or 0,
			OnClose = function()
				setIsMenuOpen(false)
			end,
			OnSettings = function()
				setIsMenuOpen(false)
				setIsSettingsOpen(true)
			end,
			OnLeave = requestLeaveMatch,
		}),
		TutorialCoach = e(TutorialCoach),
		Settings = e(Settings, {
			isOpen = isSettingsOpen,
			OnClose = function()
				setIsSettingsOpen(false)
			end,
		}),
		TowerHotbar = e(TowerHotbar),
		-- Running Bag boosts (bottom left).
		ActiveEffects = e(ActiveEffects.MatchCorner),
		Units_upgrade = selectedTower and e(unitsUpgrade, {
			Tower = selectedTower,
			PanelRef = upgradePanelRef,
			OnUpgrade = function()
				if towerNetworkerRef.current then
					towerNetworkerRef.current:fire("UpgradeTower", selectedTower)
				end
			end,
			OnSell = function()
				if towerNetworkerRef.current then
					towerNetworkerRef.current:fire("SellTower", selectedTower)
				end
			end,
			OnClose = function()
				setSelectedTower(nil)
			end,
		}),
		UpBar_healthBar = e(UpBar_healthBar, {
			Health = health,
			MaxHealth = maxHealth,
			WaveText = "WAVE " .. tostring(wave) .. " / " .. tostring(matchState.TotalWaves or 10),
			WaveStatus = if matchState.Phase == "Preparation" then "Next wave in " .. tostring(matchState.TimeRemaining or 0) .. "s"
				elseif matchState.Phase == "Victory" then "VICTORY!"
				elseif matchState.Phase == "Defeat" then "DEFEAT"
				elseif matchState.Phase == "Error" then "MATCH STOPPED"
				else tostring(matchState.Alive or 0) .. " enemies left",
			Fighting = matchState.Phase == "Spawning" or matchState.Phase == "Clearing",
		}),
		ReadyButton = e(ReadyButton, {
			Phase = matchState.Phase,
			TimeRemaining = matchState.TimeRemaining,
			Wave = wave,
			Votes = matchState.ReadyVotes,
			Needed = matchState.ReadyNeeded,
		}),
		TowerBillboards = settings.tower_labels and e(TowerBillboards, { Towers = towersWorkspace }),
		ZombiesBillboards = settings.enemy_health_bars and e(ZombiesBillboards, {
			Zombies = zombies,
		}),
		Notifications = e(Notifications, {
			Items = notifications,
			OnFinished = removeNotification,
			-- Lift messages above the placement hint bar while it is shown.
			Raised = isPlacing and (isTouch or settings.placement_hints),
		}),
	})
end

return RootUI
