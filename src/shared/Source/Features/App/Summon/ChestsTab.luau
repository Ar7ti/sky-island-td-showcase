-- Chests in the Crates window (Shared Chests/ChestsConfig): their rows live in CaseList, their menu in CaseMenu.
-- This has what both use: which chests are shown, the rim colors and the actions (ChestsTab.useActions).
-- Opening: the chest shakes in the middle while the server opens it, then its 3D opening plays (CrateCinematic,
-- the chest's own tier) with the towers it gave, then the RewardReveal popup shows everything it gave.
-- SharedServer ChestService decides everything; this only asks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Common = ReplicatedStorage.Shared.Source.Features.App.Common
local useDataValue = require(Common.useDataValue)
local soundController = require(ReplicatedStorage.Shared.Features.Services.SoundController.soundController)
local ChestsConfig = require(ReplicatedStorage.Shared.Features.Services.Chests.ChestsConfig)
local App = ReplicatedStorage.Shared.Source.Features.App
local RewardsText = require(App.Rewards.RewardsText)
local RewardReveal = require(App.Rewards.RewardReveal)
local TowersConfig = require(ReplicatedStorage.Shared.Features.Services.TowersServices.towersConfig)
local CrateCinematic = require(script.Parent.CrateCinematic)
local CaseSounds = require(script.Parent.CaseSounds)
local e = React.createElement
local Text = RewardsText.Component

local RIM = {
	Common = Color3.fromRGB(120, 230, 80),
	Rare = Color3.fromRGB(70, 190, 255),
	Epic = Color3.fromRGB(200, 110, 255),
	Mythic = Color3.fromRGB(255, 200, 60),
}
local SHAKE_TIME = 1.0 -- the chest shakes at least this long before the loot shows

local ChestsTab = {}
ChestsTab.Rim = RIM

local networker
local function call(method: string, chestId: string, count: number): any
	if not networker then
		networker = Networker.client.new("ChestService", {})
	end
	local ok, result = pcall(networker.fetch, networker, method, chestId, count)
	if not ok or type(result) ~= "table" then
		return { ok = false, error = "No answer from the server" }
	end
	return result
end

-- The chest shaking in the middle while the server opens it.
local function Opening(props: { Id: string, Count: number })
	local chest = ChestsConfig.Chests[props.Id]
	local iconRef = React.useRef(nil :: ImageLabel?)
	React.useEffect(function()
		local icon = iconRef.current
		if not icon then
			return
		end
		local running = true
		task.spawn(function()
			local step = 0
			while running and icon.Parent do
				step += 1
				local strength = math.min(step / 10, 1) * 10
				icon.Rotation = (if step % 2 == 0 then 1 else -1) * strength
				task.wait(0.05)
			end
		end)
		return function()
			running = false
		end
	end, {})
	-- A TextButton, so clicks while it shakes don't reach the window behind it.
	return e("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 45,
	}, {
		Glow = e("Frame", {
			Size = UDim2.fromOffset(420, 420),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = RIM[chest.Rarity] or RIM.Common,
			BackgroundTransparency = 0.7,
			ZIndex = 46,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),
		Icon = e("ImageLabel", {
			ref = iconRef,
			Image = chest.Icon,
			Size = UDim2.fromOffset(340, 300),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 47,
		}),
		Label = e(Text, {
			Text = if props.Count > 1 then `Opening {props.Count} x {chest.Name}...` else `Opening {chest.Name}...`,
			Size = UDim2.fromOffset(700, 44),
			Position = UDim2.new(0.5, 0, 0.5, 200),
			AnchorPoint = Vector2.new(0.5, 0),
			StrokeThickness = 4,
			ZIndex = 47,
		}),
	})
end

-- Chest ids the player sees, in display order (the Royal chest is hidden where paid random items are
-- restricted, unless they already own one).
function ChestsTab.Visible(owned: { [string]: number }, paidRandomAllowed: boolean): { string }
	local ids = {}
	for _, id in ChestsConfig.Ordered() do
		local chest = ChestsConfig.Chests[id]
		if not chest.PaidRandom or paidRandomAllowed or (owned[id] or 0) > 0 then
			table.insert(ids, id)
		end
	end
	return ids
end

-- Owned chests, open / buy, and the overlays they show (mount Overlays once in the window, above CaseMenu).
-- count: how many to open (up to the owned ones) or buy; ChestService allows 1..10.
function ChestsTab.useActions(setError: (string?) -> ())
	local owned = useDataValue("chests") or {}
	local busy, setBusy = React.useState(false)
	local opening, setOpening = React.useState(nil :: { id: string, count: number }?)
	local reveal, setReveal = React.useState(nil :: { any }?)
	local mounted = React.useRef(true)
	React.useEffect(function()
		return function()
			mounted.current = false
		end
	end, {})

	local function open(id: string, count: number?)
		if busy then
			return
		end
		local amount = math.clamp(math.min(count or 1, owned[id] or 0), 1, 10)
		setBusy(true)
		setOpening({ id = id, count = amount })
		setError(nil)
		-- The chest's own rattle while it shakes in the middle (every chest has one; StarDing is the old fallback).
		if CaseSounds.has(id, "shake") then
			CaseSounds.play(id, "shake")
		else
			soundController:PlaySFX("StarDing")
		end
		local started = os.clock()
		task.spawn(function()
			local result = call("Open", id, amount)
			task.wait(math.max(0, SHAKE_TIME - (os.clock() - started)))
			if not mounted.current then
				return
			end
			setOpening(nil)
			if result.ok and result.granted then
				-- The towers it gave come out of the chest in the 3D opening first (yields until it is over).
				local towers = {}
				for _, item in result.granted do
					local config = item.kind == "Tower" and TowersConfig[item.towerId]
					if config then
						table.insert(towers, { towerId = item.towerId, rarity = config.Rarity, featured = false, isNew = item.isNew == true })
					end
				end
				local cinematic = #towers > 0 and CrateCinematic.supports(id)
				if cinematic then
					CrateCinematic.play(id, towers)
					if not mounted.current then
						return
					end
				end
				if cinematic and CaseSounds.has(id, "popup") then
					-- Its whoosh leads in, the window opens on its chime.
					local lead = CaseSounds.lead(id, "popup")
					CaseSounds.play(id, "popup", lead)
					task.wait(lead)
					if not mounted.current then
						return
					end
					CaseSounds.beat(id, "popup")
				else
					soundController:PlaySFX("MaxUpgrade")
				end
				setBusy(false)
				setReveal(result.granted)
			else
				setBusy(false)
				soundController:PlaySFX("ErrorSound")
				setError(result.error or "Couldn't open it")
			end
		end)
	end

	local function buy(id: string, count: number?)
		if busy then
			return
		end
		setBusy(true)
		setError(nil)
		task.spawn(function()
			local result = call("Buy", id, count or 1)
			if not mounted.current then
				return
			end
			setBusy(false)
			if result.ok then
				soundController:PlaySFX("MoneySound")
			else
				soundController:PlaySFX("NotEnoughMoney")
				setError(result.error or "Purchase failed")
			end
		end)
	end

	return {
		owned = owned,
		busy = busy,
		open = open,
		buy = buy,
		revealing = reveal ~= nil or opening ~= nil,
		Overlays = e(React.Fragment, nil, {
			Opening = opening and e(Opening, { Id = opening.id, Count = opening.count }),
			Reveal = reveal and e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 50,
			}, {
				Popup = e(RewardReveal, {
					Granted = reveal,
					OnClose = function()
						setReveal(nil)
					end,
				}),
			}),
		}),
	}
end

return ChestsTab
