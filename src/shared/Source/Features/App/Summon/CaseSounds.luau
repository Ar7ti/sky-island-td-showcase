-- Each case's own opening sounds (Sounds.luau, Cases): one synthesized sprite per case (tools/audio/case_sounds.py),
-- every cue a region of it. Nothing here is shared with the match or with another case.
--
-- CaseSounds.play(caseId, cue, hitIn?) plays a cue so its `hit` lands on the animation beat:
--   * no hitIn: the cue starts now and its hit is now + hit (impacts, chimes: hit = 0);
--   * hitIn = seconds until the beat (the fall whoosh and the charge riser end on it, a firework pops on it).
--     When the beat comes sooner than the cue's lead-in, the cue starts part-way in (with a short fade); when it
--     comes later, the cue waits. Either way its hit is on the beat.
-- Through soundController:PlayRegion, so the SFX volume and on/off settings apply.
--
-- Studio timing check: with Workspace attribute CaseSoundLog = true, every beat (CaseSounds.beat) and every cue
-- (when it was asked, when Studio's audio really started moving, when its hit is heard) goes to CaseSounds.log.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Sounds = require(ReplicatedStorage.Shared.Source.Game.AssetsIds.Sounds)
local soundController = require(ReplicatedStorage.Shared.Features.Services.SoundController.soundController)

local CaseSounds = {}

type Cue = { start: number, length: number, hit: number }
type Case = { id: string, cues: { [string]: Cue } }

local FADE_IN = 0.03
local MAX_LOG = 400

CaseSounds.log = {} :: { { [string]: any } }
local playing: { Sound } = {}

-- Studio measured it (2026-11-17): a sound whose asset no other Sound holds starts ~330 ms late once it has been
-- idle for a second; with one stopped Sound of the same asset kept around it starts at once. So every case keeps
-- one stopped Sound of its sprite in SoundService.
local held: { [string]: Sound } = {}
local function hold(id: string)
	if held[id] or not RunService:IsClient() then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "CaseSoundsHold"
	sound.SoundId = id
	sound.Volume = 0
	sound.Archivable = false
	sound.Parent = game:GetService("SoundService")
	held[id] = sound
end

local function logging(): boolean
	return RunService:IsStudio() and Workspace:GetAttribute("CaseSoundLog") == true
end

local function record(entry: { [string]: any })
	if #CaseSounds.log < MAX_LOG then
		table.insert(CaseSounds.log, entry)
	end
end

function CaseSounds.get(caseId: string): Case?
	return (Sounds :: any).Cases and (Sounds :: any).Cases[caseId]
end

function CaseSounds.has(caseId: string, cue: string): boolean
	local case = CaseSounds.get(caseId)
	return case ~= nil and case.cues[cue] ~= nil
end

-- Marks an animation beat for the Studio timing check.
function CaseSounds.beat(caseId: string, name: string)
	if logging() then
		record({ kind = "beat", case = caseId, name = name, t = os.clock() })
	end
end

function CaseSounds.play(caseId: string, cueName: string, hitIn: number?, options: { speed: number?, volume: number? }?)
	local case = CaseSounds.get(caseId)
	local cue = case and case.cues[cueName]
	if not case or not cue then
		return
	end
	hold(case.id)
	local speed = options and options.speed or 1
	local asked = os.clock()
	-- The beat is `hitIn` seconds away: start part-way in when it comes sooner than the cue's own lead-in, start a
	-- little later when it comes after it.
	local skip, delay = 0, 0
	if hitIn then
		local lead = cue.hit / speed
		if hitIn < lead then
			skip = (lead - hitIn) * speed
		else
			delay = hitIn - lead
		end
	end
	local entry = if logging()
		then { kind = "cue", case = caseId, name = cueName, t = asked, hitAt = asked + delay + (cue.hit - skip) / speed, skip = skip }
		else nil
	if entry then
		record(entry)
	end
	local function start()
		local sound = soundController:PlayRegion(case.id, cue.start + skip, cue.length - skip, options and options.volume, speed, if skip > 0 then FADE_IN else nil)
		if not sound then
			return
		end
		if #playing > 40 then
			local alive = {}
			for _, other in playing do
				if other.Parent then
					table.insert(alive, other)
				end
			end
			playing = alive
		end
		table.insert(playing, sound)
		if entry then
			-- When Studio's audio really starts: the first frame the play head has moved past the region start.
			local regionStart = cue.start + skip
			local began = os.clock()
			task.spawn(function()
				while sound.Parent and os.clock() - began < 3 do
					local position = sound.TimePosition
					if sound.IsPlaying and position > regionStart + 0.0005 then
						local startedAt = os.clock() - (position - regionStart) / speed
						entry.started = startedAt
						entry.heardHit = startedAt + (cue.hit - skip) / speed
						entry.loaded = sound.IsLoaded
						return
					end
					RunService.Heartbeat:Wait()
				end
				entry.loaded = sound.IsLoaded
			end)
		end
	end
	if delay > 0 then
		task.delay(delay, start)
	else
		start()
	end
end

-- Seconds from the start of a cue to its hit (e.g. the popup's whoosh before its chime); 0 if there is none.
function CaseSounds.lead(caseId: string, cueName: string): number
	local case = CaseSounds.get(caseId)
	local cue = case and case.cues[cueName]
	return if cue then cue.hit else 0
end

-- Fades out every cue still playing (the player skipped the opening).
function CaseSounds.stopAll(fade: number?)
	local list = playing
	playing = {}
	for _, sound in list do
		if sound.Parent and sound.IsPlaying then
			local steps = math.max(1, math.floor((fade or 0.25) / 0.03))
			local from = sound.Volume
			task.spawn(function()
				for step = 1, steps do
					if not sound.Parent then
						return
					end
					sound.Volume = from * (1 - step / steps)
					task.wait(0.03)
				end
				sound:Destroy()
			end)
		end
	end
end

-- Loads every case's sprite ahead (the summon window calls CrateCinematic.preload when it opens).
function CaseSounds.preload()
	local cases = (Sounds :: any).Cases
	if not cases then
		return
	end
	local list = {}
	for _, case in cases do
		hold(case.id)
		table.insert(list, held[case.id])
	end
	pcall(ContentProvider.PreloadAsync, ContentProvider, list)
end

return CaseSounds
