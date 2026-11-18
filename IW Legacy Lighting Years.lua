-- (Addtion-Scripts) Hammer stuff 2's "lighting era" dropdown loads this file for its eras (2014, 2015, 2016, 2017,
-- 2019, 2020). The year is handed over in getgenv().BPIWLightingYear before it runs (2017 when none is).
-- Hammer stuff 2's "iw legacy lighting" (its own option) is the other file, IW Legacy Lighting.lua, left as it was;
-- the two are the same lighting script underneath, so only one of them runs at a time. With both ticked, this file
-- runs the era with iw's overhaul (getgenv().BPIWLightingOverhaul: colours darkened, light boosted).
-- Unticking calls getgenv().LegacyLightingStop(), which puts the game back as it was (the lighting, the game's own
-- effects, the technology). Picking another year stops this one the same way first.
--[[
	LEGACY LIGHTING 2014 / 2015 / 2016 / 2017 / 2019 / 2020  -  client side only
	Only YOU see any of this: it never touches the server, so nobody else in the game sees it.

	The six year scripts are one script with different Settings; this is that script once, with the year's Settings
	picked below (YEARS). What each year changes from the Settings written here:
	  2014, 2015, 2016  the five year switches ON (NoGlass, NoGuiLighting, NoLitParticles, NoTrails, NoBeams): all five
	                    features arrived in 2017 or later. (The three are the same: their scripts have the same Settings.)
	  2017              the five switches OFF (as written below)
	  2019              2017 + Voxel2019 (the newer tonemapper of the 2018-2019 lighting update)
	  2020              2019 + 3D clouds, grass blades and the game's own Atmosphere / bloom / sun rays kept
	All of them: lighting only (KeepColours: nothing in the map is recoloured, sun 0.95, shade 1.05, matched to a
	January 2017 Studio build), soft voxel shadows on, the thin Outlines off.

	* The time of day is left to the game: a day/night cycle keeps working.
	* Not recreatable here: the older Brick / Wood Planks textures (before February 2017) and the tilted-O studs
	  (before 25 March 2017).

	(Addtion-Scripts changes, the same as in IW Legacy Lighting.lua)
	* Unticking it in Hammer stuff 2 (getgenv().LegacyLightingStop) puts the game back as it was: the lighting, the
	  game's own effects and the technology (and colours, terrain and unions, if a year ever darkens them).
	  The restarts after you respawn only hand over to the new run.
	* Where Bloxy's "2016 textures" has put its stud textures, they are hidden while this runs (this script's own stud
	  is on that face), so there are no double studs; they come back when it stops.
	* Works together with Hammer stuff's other "legacy lighting". (The soft voxel shadows are this script's own; Hammer
	  stuff's separate "voxel lighting" option has been taken out, and the code here that worked with it does nothing.)
	* getgenv().LegacyLightingOriginal(instance, property) gives the game's own value (Classic Face uses it).
]]

local Settings = {
	-- YEAR SWITCHES: all true = 2016, all false = 2017
	NoGlass          = false, -- the Glass material (6 December 2017): draw it as plain transparent plastic, like before it existed.
	                          -- The parts go back to Glass when the script stops
	NoGuiLighting    = false, -- lit 3D GUIs (SurfaceGui / BillboardGui LightInfluence, May 2017): kept at 0 = unlit, like before
	                          -- it existed. Has no effect while LitSurfaceGuis is on
	NoLitParticles   = false, -- particles lit by the scene (ParticleEmitter.LightInfluence, June 2017): kept at 0 so they show their
	                          -- own colours like before it existed
	NoTrails         = false, -- Trail effects (May-June 2017) hidden
	NoBeams          = false, -- Beam effects (November 2017) hidden

	KeepColours      = true ,  -- how the look is made:
	                          --   false = the legacy trick: darken every colour and boost the light to match
	                          --   true  = lighting only: nothing in the map is recoloured (sun/shade/tone settings only)
	                          -- The mode is fixed for a server once the script has run there: rejoin to change it
	KeepSun          = 0.95,  -- lighting-only mode: how much stronger the sun is made
	KeepAmbient      = 1.05,  -- lighting-only mode: how much stronger the shade light is made
	LegacyIntensity  = 3,     -- the original value
	LegacyStuds      = false, -- (Addtion-Scripts) off for the lighting eras: no classic studs are put on parts. true = studs on plain
	                          -- parts that use the Studs surface
	RetroStudsWith2016Textures = false, -- (Addtion-Scripts) off for the lighting eras (it swaps Bloxy's stud faces for this script's studs; false leaves Bloxy's as they are). Was: where Bloxy's "2016 textures" puts its stud textures, each
	                          -- is hidden while this runs (this script's stud is on that face instead, so there are no
	                          -- double studs) and comes back when it stops
	Voxel2019        = false, -- true = modern tonemapper instead of the retro one
	LitSurfaceGuis   = false, -- true = force every 3D GUI (text/images on parts) to be lit like parts, with its colours darkened.
	                          -- Off: 3D GUIs keep their own setting, unlit unless the game turns lighting on (lit 3D GUIs arrived May 2017)
	NeonLight        = 1.5,   -- light given off by neon parts in the world (0 = off)
	NeonBloom        = 0,     -- screen glow. Leave at 0: under this lighting it also makes sunlit skin/eyes glow
	BloomSize        = 24,
	BloomThreshold   = 3,
	StripGameEffects = true,  -- switch off the game's own bloom/atmosphere/sunrays/blur so they don't fight the look
	KeepGameFog      = true,  -- leave the game's own fog alone (classic fog existed in 2016). false = push fog out of sight
	ForceVoxel       = true,  -- try to switch a Future / ShadowMap game to Voxel lighting, the 2017 kind
	TryCompatibility = true,  -- ask for the retired "Compatibility" lighting instead of Voxel. Roblox took it out of the menu
	                          -- in 2024 and a script can still set it; in a side-by-side test it looked the same as Voxel.
	                          -- If a whole map turns dark, set it to false
	SoftLighting     = true,  -- move the game off Future-style lighting, which makes the map shiny and overbright
	SunBoost         = 2.1,   -- how much stronger the sun is made. Lower it (try 1.6) if a map is still too bright
	AmbientBoost     = 1.2,   -- how much stronger the shade light is made
	FutureSunBoost   = 1.2,   -- used instead when the game stays on Future lighting: a weaker sun means less white shine
	FutureAmbientBoost = 1.7, -- ...and more shade light, so the picture does not get darker overall
	PaleParts        = 0.3,   -- pale map parts (white, cream, light green ...) are darkened a little more than the rest, so the
	                          -- strong sun stops turning them pure white. 0 = off, 0.6 = strong. Characters are left alone
	DarkGames        = true,  -- a game whose own lighting is dark (horror, night, caves) stays dark instead of being given
	                          -- daylight. Games with normal daytime lighting are not changed by this
	LampBoost        = 2.7,   -- how much stronger the game's own lamps are made while Shadows is on or the game is dark.
	                          -- Colours are darkened, so without it lamp light is far too weak. 1 = leave lamps alone
	Shadows          = true,  -- true = the old soft, blurry shadows (only when the game is on Voxel lighting, see ForceVoxel).
	                          -- ON in both 2016 and 2017: soft shadows existed in both years. Set false for the
	                          -- flat look: with shadows the sun stops at roofs, and because the script does not boost
	                          -- a room's own lamps, indoor rooms can turn dull and grey
	IndoorAmbient    = 0.4,   -- with Shadows on: the shade light indoors / under cover. Outdoors is 0.5; 0.5 here = no difference
	Saturation       = 0,     -- extra colour strength added on top (old Roblox had none: 0)
	Contrast         = 0,     -- extra contrast added on top (old Roblox had none: 0)
	ToneBrightness   = 0.03,  -- extra brightness added to the whole picture (0 = none). Together with Contrast it spreads the
	                          -- picture out: whites brighter, darks darker
	Outlines         = false,  -- thin dark edges on bricks near you. On by default: Roblox had outlines on by default in games
	                          -- until September 2017 (new places then came with them off), so it depended on the game. A January
	                          -- 2017 Studio baseplate has them; the 2016 reference screenshot shows none. false removes them.
	                          -- Costs performance on big maps
	OutlineThickness = 0.01,  -- how thick the lines are, in studs. Measured on the 2017 Studio: about 1 pixel wide, so keep it small
	OutlineTransparency = 0.6,  -- 0 = solid black, 1 = invisible. The 2017 lines were only about 10-17% darker than the brick next to
	                          -- them (not black). 0.6 with the dark grey below measured about 8-20% darker in a side-by-side
	OutlineColor     = Color3.new(0.1, 0.1, 0.1), -- colour of the lines. Pure black came out far too dark (Transparency barely
	                          -- lightens a 1-pixel line), so a very dark grey is used. Darker = stronger lines
	OutlineDistance  = 120,   -- how far from the camera bricks get an outline (studs)
	MaxOutlines      = 1200,
	AutoBrightness   = true,  -- weaker sun on maps built mostly from white / very pale parts, which otherwise wash out.
	                          -- Dark and mid-coloured maps are left as they are. Set false to always use SunBoost as written
	FixTexturedMeshes = true, -- redraw textured mesh hats/hair/limbs on characters so they darken too (they went white in R15 games)
	FixLayeredClothing = true, -- 3D layered clothing you wear (catalog T-Shirts, Jackets, Pants...) and other skinned textured
	                          -- meshes you wear: their picture ignored the darkening and stayed too bright. This draws the same
	                          -- picture through a SurfaceAppearance that is darkened
	FixDynamicHeads  = true,  -- the same for the head of a character that uses a head texture (animated / dynamic heads): the
	                          -- head stayed full-bright while everything else was darkened. The face keeps animating.
	                          -- Also covers the face mesh some games put on the head (R6QualityHeadFace: glowing eye whites)
	FixWorldMeshes   = false, -- the same for textured meshes in the map. Try it when the MAP is too bright. Heavier on big maps
	MaxMeshFixes     = 800,   -- upper limit for the two settings above
	DarkenTerrain    = true,  -- darken terrain (ground, sand, rock and the grass blades) like parts, so it stops blowing out
	TerrainDarken    = 1.25,  -- terrain only: above 1 makes terrain darker than parts, below 1 lighter, 1 = the same.
	                          -- Raise it (try 1.6) if grass is too light, lower it if too dark
	TerrainHaze      = 0.006, -- takes off the pale grey film the strong sun leaves on terrain, which made grass look
	                          -- washed and less green. Raise it (try 0.01) for deeper colour, 0 = off
	FixUnionColors   = true,  -- unions ignore their Color, so they never darkened and went pure white. This makes them use it.
	                          -- A union built from parts of several colours becomes one colour; set false if that looks wrong
	DarkenLitEffects = true,  -- beams, trails and particles that take light from the scene are darkened like parts,
	                          -- otherwise the boosted sun turns them white. Glowing (unlit) ones are left alone

	-- things Roblox did not have in 2016-2018, switched off on your client
	NoClouds         = true,  -- moving 3D clouds (2020)
	NoGrassBlades    = true,  -- the swaying grass blades on terrain (added November 2019). Needs an executor that can write
	                          -- hidden properties; the console says if it was refused. Set false to keep the grass
	NoWind           = true,  -- wind (2023): it bends smoke, fire and particles and moves clouds. Kept at zero
	NoHighlights     = true,  -- hide Highlight outlines / glows (2021). Set false if a game uses them to show you
	                          -- objectives, items or teammates
	OldMaterials     = false, -- (Addtion-Scripts) off for the lighting eras: the game's materials are left as they are (the
	                          -- 2022 textures and its custom materials); old materials are Hammer stuff 1's own option.
	                          -- true = built-in materials only: removes the game's custom (2022) materials, and switches to the
	                          -- pre-2022 textures where the executor can write hidden properties
	NoPBR            = false, -- remove SurfaceAppearance (2020 shiny PBR textures). A mesh that has no plain texture turns flat-coloured

	-- respawning
	NoSpawnShield    = false,  -- hide the shimmer of the spawn shield (ForceField) that a game puts on a character after it
	                          -- respawns. It makes the body shiny and pale until the shield runs out. You stay protected
	RestartOnRespawn = {1},   -- after YOU respawn the script restarts itself once, this many seconds after you spawn,
	                          -- exactly like pressing execute again. More numbers = more restarts, e.g. {2, 6, 12}.
	                          -- Each restart rescans the whole map. {} = never restart
}

-- (Addtion-Scripts) THE YEAR: what each year script changes from the Settings above (see the top of this file)
local YEARS = {
	["2014"] = {NoGlass = true, NoGuiLighting = true, NoLitParticles = true, NoTrails = true, NoBeams = true},
	["2015"] = {NoGlass = true, NoGuiLighting = true, NoLitParticles = true, NoTrails = true, NoBeams = true},
	["2016"] = {NoGlass = true, NoGuiLighting = true, NoLitParticles = true, NoTrails = true, NoBeams = true},
	["2017"] = {},
	["2019"] = {Voxel2019 = true},
	["2020"] = {Voxel2019 = true, StripGameEffects = false, NoClouds = false, NoGrassBlades = false},
}
local YEAR = "2017"
do
	local g0 = (getgenv and getgenv()) or _G
	local asked = tostring(g0.BPIWLightingYear or "2017")
	if YEARS[asked] then YEAR = asked end
	for key, value in pairs(YEARS[YEAR]) do Settings[key] = value end
	-- Hammer stuff's "iw legacy lighting" ticked too: the era's look with iw's overhaul, the legacy trick (every colour
	-- darkened and the light boosted to match) instead of lighting only
	if g0.BPIWLightingOverhaul then Settings.KeepColours = false end
	g0.BPIWLightingYearRunning = YEAR .. (g0.BPIWLightingOverhaul and " + iw" or "")
end

local genv0 = (getgenv and getgenv()) or _G
-- a fresh execute cancels restarts that an earlier copy of this script still had waiting
genv0.__LegacyLightingRespawnToken = {}
local scheduleRestarts -- defined below the main function
-- Lets a settings panel change a few values while the script runs. Each run fills it in again.
-- Nothing in this file uses it by itself.
local live = {}
-- a settings panel left open by the tuner copy of this script belongs to the run that is being replaced
if type(genv0.__LegacyLightingTunerClose) == "function" then pcall(genv0.__LegacyLightingTunerClose) end

local function LegacyLightingMain()
table.clear(live)

----------------------------------------------------------------------------------------------------
-- replace the previous run
----------------------------------------------------------------------------------------------------
local genv = (getgenv and getgenv()) or _G
-- (Addtion-Scripts) the previous run's hand-over stop (the colours stay darkened for this run). An older copy
-- of the script only has LegacyLightingStop.
if type(genv.__LegacyLightingReplace) == "function" then
	pcall(genv.__LegacyLightingReplace)
elseif type(genv.LegacyLightingStop) == "function" then
	pcall(genv.LegacyLightingStop)
end

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
while not player do
	task.wait()
	player = Players.LocalPlayer
end

local stopped = false
local conns, holders, created = {}, {}, {}
local ownedSet = setmetatable({}, {__mode = "k"})

local function track(c)
	conns[#conns + 1] = c
	return c
end

local function own(i)
	created[#created + 1] = i
	ownedSet[i] = true
	return i
end

-- Remembers which (instance, property) pairs were already darkened, across runs, so running the script
-- again never darkens anything twice.
local divided = genv.__LegacyLightingDivided
if type(divided) ~= "table" then
	divided = setmetatable({}, {__mode = "k"})
	genv.__LegacyLightingDivided = divided
end
-- That table may let go of a part's note once nothing else refers to the part. While one run is being replaced
-- by the next there is a short gap in which nothing does, and a note lost there would mean darkening that part
-- a second time. So hold on to every noted part until the new run's first scan is done.
local pinned = {}
for inst in pairs(divided) do pinned[#pinned + 1] = inst end
local listening = setmetatable({}, {__mode = "k"})
-- (Addtion-Scripts) unions switched to their own colour (see FixUnionColors), kept across runs like the colours,
-- so the full stop can switch them back
local unionsSwitched = genv.__LegacyLightingUnions
if type(unionsSwitched) ~= "table" then
	unionsSwitched = setmetatable({}, {__mode = "k"})
	genv.__LegacyLightingUnions = unionsSwitched
end
-- (Addtion-Scripts) the signs' own LightInfluence, kept the same way for the full stop
local signsLit = genv.__LegacyLightingSigns
if type(signsLit) ~= "table" then
	signsLit = setmetatable({}, {__mode = "k"})
	genv.__LegacyLightingSigns = signsLit
end

----------------------------------------------------------------------------------------------------
-- colour helpers
----------------------------------------------------------------------------------------------------
local trickDivisor = Settings.LegacyIntensity * 0.9

-- lighting only? (see KeepColours in Settings)
local keepColours = Settings.KeepColours == true
local modeNote = keepColours and "lighting only (KeepColours = true)" or "legacy trick (colours darkened, light boosted)"
-- Colours darkened by an earlier run in this server stay darkened, so the mode cannot change until you rejoin.
local previousDivisor = genv.__LegacyLightingDivisor
-- true when no copy of this script has run on this server yet: the lighting is still the game's own
local freshServer = type(previousDivisor) ~= "number" and next(divided) == nil
if type(previousDivisor) ~= "number" and next(divided) ~= nil then
	previousDivisor = trickDivisor -- an older version of the script ran here
end
local divisor = keepColours and 1 or trickDivisor
if type(previousDivisor) == "number" and math.abs(previousDivisor - divisor) > 0.001 then
	divisor = previousDivisor
	keepColours = previousDivisor == 1
	modeNote = (keepColours and "lighting only" or "legacy trick") .. " (kept from the earlier run in this server: REJOIN the game to switch mode)"
end
genv.__LegacyLightingDivisor = divisor

local function clamp01(c)
	return Color3.new(math.clamp(c.R, 0, 1), math.clamp(c.G, 0, 1), math.clamp(c.B, 0, 1))
end

local function div(v, d)
	if typeof(v) == "Color3" then
		return clamp01(Color3.new(v.R / d, v.G / d, v.B / d))
	elseif typeof(v) == "Vector3" then
		return v / d
	elseif typeof(v) == "ColorSequence" then -- beams, trails, particles
		local keys = {}
		for i, k in ipairs(v.Keypoints) do
			keys[i] = ColorSequenceKeypoint.new(k.Time, clamp01(Color3.new(k.Value.R / d, k.Value.G / d, k.Value.B / d)))
		end
		return ColorSequence.new(keys)
	end
	return v
end

local function mul(c, m)
	return Color3.new(c.R * m, c.G * m, c.B * m)
end

-- Watches inst[Prop]. apply() runs on every change and when run() is called. The watcher is dropped while
-- apply() writes, so our own write does not trigger it again.
local function guarded(inst, Prop, apply)
	local h = {}
	holders[#holders + 1] = h
	local run
	local function connect()
		h.conn = inst:GetPropertyChangedSignal(Prop):Connect(run)
	end
	run = function()
		if h.conn then h.conn:Disconnect() end
		pcall(apply)
		connect()
	end
	h.silently = function(fn) -- change the property without triggering apply
		if h.conn then h.conn:Disconnect() end
		pcall(fn)
		connect()
	end
	connect()
	return h, run
end

-- Keeps inst[prop] at value, also when the game writes it again. restore = put the old value back when the
-- script is stopped or replaced.
local restores = {}
local function hold(inst, prop, value, restore)
	local ok, before = pcall(function() return inst[prop] end)
	if not ok then return false end
	local _, run = guarded(inst, prop, function()
		if inst[prop] ~= value then inst[prop] = value end
	end)
	run()
	if restore then
		restores[#restores + 1] = function() inst[prop] = before end
	end
	return true
end

-- NoGlass: Glass (December 2017) is switched to Plastic, which is what a transparent brick was before. A part that
-- turns into Glass later is caught by the Material watcher that every part already has (see SetProp).
local glassChanged = setmetatable({}, {__mode = "k"})
local function swapGlass(part)
	if stopped or Settings.NoGlass ~= true or part.Material ~= Enum.Material.Glass then return end
	glassChanged[part] = true
	part.Material = Enum.Material.Plastic
end
restores[#restores + 1] = function()
	for part in pairs(glassChanged) do
		pcall(function()
			if part.Material == Enum.Material.Plastic then part.Material = Enum.Material.Glass end
		end)
	end
end

----------------------------------------------------------------------------------------------------
-- neon: emissive, so it keeps its colour, and gives off a light (not when worn/held by a character)
----------------------------------------------------------------------------------------------------
local NEON = Enum.Material.Neon
local MAX_NEON_LIGHTS = 60
local neonLightCount = 0
local neonWatched = setmetatable({}, {__mode = "k"})

local function isWorn(part)
	local p = part.Parent
	while p and p ~= workspace do
		if p:FindFirstChildOfClass("Humanoid") then return true end
		p = p.Parent
	end
	return false
end

local function refreshNeonLight(part)
	if stopped then return end
	local light = part:FindFirstChild("LegacyNeonLight")
	if part.Material == NEON and part.Transparency < 0.9 and not isWorn(part) and part:IsDescendantOf(workspace) then
		if not light then
			if neonLightCount >= MAX_NEON_LIGHTS then return end
			neonLightCount += 1
			light = Instance.new("PointLight")
			light.Name = "LegacyNeonLight"
			light.Shadows = false
			light.Brightness = Settings.NeonLight
			light.Parent = part
			light.Destroying:Connect(function() neonLightCount -= 1 end)
		end
		light.Color = part.Color
		light.Range = math.clamp(math.max(part.Size.X, part.Size.Y, part.Size.Z) * 4, 8, 16)
	elseif light then
		light:Destroy()
	end
end

local function watchNeon(part)
	if neonWatched[part] then return end
	neonWatched[part] = true
	refreshNeonLight(part)
	track(part.AncestryChanged:Connect(function() refreshNeonLight(part) end))
	for _, prop in ipairs({"Color", "Transparency", "Size"}) do
		track(part:GetPropertyChangedSignal(prop):Connect(function() refreshNeonLight(part) end))
	end
end

----------------------------------------------------------------------------------------------------
-- darkening colours (parts, meshes, decals, clothes, gui) - the lighting is boosted to compensate
----------------------------------------------------------------------------------------------------
-- A part's colour is left undivided when it is emissive (Neon), or when it is a character Head drawn as a
-- textured SpecialMesh: there Part.Color tints the skin AND VertexColor multiplies the whole result, so only
-- one of the two may be divided. We keep Part.Color and divide VertexColor, which also darkens any opaque
-- (baked-in) parts of the head texture the same way hats are darkened. Works for any head texture.
local function colorExempt(part)
	if part.Material == NEON then return true end
	if part.Name == "Head" and part.Parent and part.Parent:IsA("Model") then
		local sm = part:FindFirstChildOfClass("SpecialMesh")
		if sm and sm.TextureId ~= "" then return true end
	end
	return false
end

-- PaleParts: how much of its darkened colour a map part keeps. 1 for dark and mid colours, less the paler it is.
-- The boosted sun only balances out for dark and mid colours; a pale part in the sun went past white.
local function paleFactor(real)
	local strength = math.clamp(tonumber(Settings.PaleParts) or 0, 0, 0.9)
	if strength <= 0 then return 1 end
	local top = math.max(real.R, real.G, real.B)
	return 1 - strength * math.clamp((top - 0.45) / 0.55, 0, 1)
end
local paleHandles = setmetatable({}, {__mode = "k"}) -- part -> the guard on its colour
-- Parts of a character (anything under a model with a Humanoid) never get the pale dimming: skin and clothes keep
-- their exact colours. A respawning character arrives part by part, and its Humanoid can arrive after its arms and
-- legs, so "is this part of a character?" cannot be decided once when the part appears. It is checked every time
-- a colour is written, and a part that was dimmed too early is put right when its Humanoid shows up.
local notPale = setmetatable({}, {__mode = "k"})

local function unpale(part)
	notPale[part] = true
	local flags = divided[part]
	local h = paleHandles[part]
	if h and flags and flags.real and flags.Color and (flags.pale or 1) < 0.999 then
		local okExempt, isExempt = pcall(colorExempt, part)
		if okExempt and not isExempt then
			flags.pale = 1
			local target = div(flags.real, divisor)
			h.silently(function() part.Color = target end)
		end
	end
end

local function SetProp(inst, Prop)
	if keepColours then return end -- lighting only: colours are left exactly as the game has them
	local l = listening[inst]
	if not l then
		l = {}
		listening[inst] = l
	end
	if l[Prop] then return end
	l[Prop] = true

	local flags = divided[inst]
	if not flags then
		flags = {}
		divided[inst] = flags
	end
	local already = flags[Prop]
	flags[Prop] = true

	local isPartColor = Prop == "Color" and inst:IsA("BasePart")
	local exempt = isPartColor and colorExempt(inst) or false

	-- the colour to write for a real colour. For parts the real colour is remembered, so PaleParts can be
	-- changed later (or undone for a character) without having to guess it back
	local function darkened(real)
		local target = div(real, divisor)
		if isPartColor then
			local f = 1
			if not notPale[inst] then
				if isWorn(inst) then
					notPale[inst] = true
				else
					f = paleFactor(real)
				end
			end
			flags.real, flags.pale = real, f
			if f < 1 then target = mul(target, f) end
		end
		return target
	end

	local h, run = guarded(inst, Prop, function()
		if not exempt then
			inst[Prop] = darkened(inst[Prop])
		end
	end)
	if isPartColor then paleHandles[inst] = h end

	if isPartColor then
		local function recheck()
			if Settings.NoGlass == true then pcall(swapGlass, inst) end
			local now = colorExempt(inst)
			if now ~= exempt then
				exempt = now
				h.silently(function()
					if now then
						inst.Color = flags.real or clamp01(mul(inst.Color, divisor))
					else
						inst.Color = darkened(inst.Color)
					end
				end)
			end
			if (Settings.NeonLight or 0) > 0 then
				if inst.Material == NEON then watchNeon(inst) else refreshNeonLight(inst) end
			end
		end
		-- keep the colour right if the material or the head mesh/texture changes later
		track(inst:GetPropertyChangedSignal("Material"):Connect(recheck))
		if inst.Name == "Head" then
			local function watchMesh(m)
				if m:IsA("SpecialMesh") then
					track(m:GetPropertyChangedSignal("TextureId"):Connect(recheck))
					recheck()
				end
			end
			for _, c in ipairs(inst:GetChildren()) do watchMesh(c) end
			track(inst.ChildAdded:Connect(watchMesh))
			track(inst.ChildRemoved:Connect(function(c)
				if c:IsA("SpecialMesh") then recheck() end
			end))
		end
	end

	if not already then
		run()
	elseif isPartColor and not exempt then
		-- darkened by an earlier run on this server: bring it to what it should be now (the PaleParts value in
		-- use, or no pale dimming at all for a part of a character)
		if not flags.real then -- that run was an older version, which darkened every part the same
			flags.real, flags.pale = clamp01(mul(inst.Color, divisor)), 1
		end
		local want = 1
		if not notPale[inst] then
			if isWorn(inst) then
				notPale[inst] = true
			else
				want = paleFactor(flags.real)
			end
		end
		if math.abs(want - (flags.pale or 1)) > 0.001 then
			local real = flags.real
			h.silently(function() inst.Color = darkened(real) end)
		end
	end
end

-- PaleParts was changed while running (the settings panel): rewrite the parts it affects, a few hundred per frame
local paleBusy, paleAgain = false, false
live.refreshParts = function()
	if keepColours or stopped then return end
	if paleBusy then
		paleAgain = true
		return
	end
	paleBusy = true
	task.spawn(function()
		repeat
			paleAgain = false
			local list = {}
			for inst, h in pairs(paleHandles) do list[#list + 1] = {inst, h} end
			local written = 0
			for _, entry in ipairs(list) do
				if stopped then break end
				local inst, h = entry[1], entry[2]
				local flags = divided[inst]
				local real = flags and flags.real
				if real and flags.Color and not notPale[inst] then
					local okExempt, isExempt = pcall(colorExempt, inst)
					local f = paleFactor(real)
					if okExempt and not isExempt and math.abs(f - (flags.pale or 1)) > 0.001 then
						flags.pale = f
						local target = mul(div(real, divisor), f)
						h.silently(function() inst.Color = target end)
						written += 1
						if written % 400 == 0 then task.wait() end
					end
				end
			end
		until not paleAgain or stopped
		paleBusy = false
	end)
end

----------------------------------------------------------------------------------------------------
-- studs: only plain block parts outside characters (a Top-face texture gets stretched over a whole mesh,
-- which showed up as skin-coloured patches on character limbs)
----------------------------------------------------------------------------------------------------
local FACES = {"Back", "Bottom", "Front", "Left", "Right", "Top"}

local function studsAllowed(part)
	if part:IsA("MeshPart") then return false end
	if part:FindFirstChildWhichIsA("DataModelMesh") then return false end
	local parent = part.Parent
	if parent and parent:FindFirstChildOfClass("Humanoid") then return false end
	return true
end

-- The studs take the part's colour and fade with the part. An invisible part (a hitbox, a trigger) therefore
-- has invisible studs: without this its studs hung in the air as a grid of white squares.
local function refreshStuds(part)
	local hidden = part:FindFirstChildWhichIsA("DataModelMesh") ~= nil
	for _, t in ipairs(part:GetChildren()) do
		if t:IsA("Texture") and t.Name:sub(1, 11) == "LegacyStuds" then
			t.Color3 = mul(part.Color, 2.5 * divisor / trickDivisor)
			t.Transparency = hidden and 1 or part.Transparency
		end
	end
end

local studWatched = setmetatable({}, {__mode = "k"})
local function watchStuds(part)
	if studWatched[part] then return end
	studWatched[part] = true
	track(part:GetPropertyChangedSignal("Color"):Connect(function() refreshStuds(part) end))
	track(part:GetPropertyChangedSignal("Transparency"):Connect(function() refreshStuds(part) end))
	track(part.ChildAdded:Connect(function(child)
		if child:IsA("DataModelMesh") then refreshStuds(part) end
	end))
end

-- this script's stud on one face (true when it was made now; one an earlier run left is used as it is)
local function makeStud(part, face)
	local name = "LegacyStuds" .. face
	if part:FindFirstChild(name) then return false end
	local t = Instance.new("Texture")
	t.Name = name
	t.Texture = "rbxassetid://13225057574"
	t.StudsPerTileU = 2
	t.StudsPerTileV = 2
	t.Face = Enum.NormalId[face]
	t.Transparency = part.Transparency
	t.Color3 = mul(part.Color, 2.5 * divisor / trickDivisor)
	t.Parent = part
	return true
end

local function addStuds(part)
	if not Settings.LegacyStuds then return end
	if not (part:IsA("Part") or part:IsA("WedgePart")) then return end
	if not studsAllowed(part) then return end
	local has = false -- also true for studs an earlier run of this script left on the part
	for _, face in ipairs(FACES) do
		if part[face .. "Surface"] == Enum.SurfaceType.Studs then
			makeStud(part, face)
			has = true
		end
	end
	if has then
		refreshStuds(part)
		watchStuds(part)
	end
end

----------------------------------------------------------------------------------------------------
-- (Addtion-Scripts) RETRO STUDS with Bloxy's "2016 textures": that choice puts a stud texture
-- ("TopSurface_ClassicTexture" ...) on the stud faces of Plastic parts, coloured from the part. Under this lighting
-- it came out far too dark (the part is darkened, and so was its texture), so while this runs the two are switched
-- one for one: each of Bloxy's stud faces is hidden (kept at Transparency 1) and gets this script's stud on the
-- same part and face; when Bloxy takes one away, this script's goes too. Stopping gives Bloxy's back.
----------------------------------------------------------------------------------------------------
local function isBloxyStud(v)
	return v.ClassName == "Texture" and string.find(v.Name, "Surface_ClassicTexture$") ~= nil
end

local bloxyHidden = setmetatable({}, {__mode = "k"})
local function hideBloxyStud(t)
	if bloxyHidden[t] then return end
	bloxyHidden[t] = true
	hold(t, "Transparency", 1, true)
	local part = t.Parent
	local face = string.match(t.Name, "^(%a+)Surface_ClassicTexture$")
	if not (part and part:IsA("BasePart") and face and Enum.NormalId[face]) then return end
	local function sync()
		if stopped then return end
		local ours = part:FindFirstChild("LegacyStuds" .. face)
		if t.Parent ~= part or not part:IsDescendantOf(workspace) or isWorn(part) then
			-- Bloxy took its stud away, or the part is on a character now (a tool picked up): ours goes too
			if ours then pcall(function() ours:Destroy() end) end
		elseif not ours then
			makeStud(part, face)
			refreshStuds(part)
			watchStuds(part)
		end
	end
	sync()
	track(t.AncestryChanged:Connect(sync))
	track(part.AncestryChanged:Connect(sync)) -- a tool picked up or put down again
end

local swapNoted = false
local function noteRetroStuds()
	if swapNoted then return end
	swapNoted = true
	print("[LegacyLighting] Bloxy's 2016 stud textures found: swapped for this lighting's, one for one")
end

----------------------------------------------------------------------------------------------------
-- text/images on SurfaceGuis: unlit by default, so they stayed full-bright. Light them like parts and
-- darken their colours the same way.
----------------------------------------------------------------------------------------------------
local GUI_PROPS = {
	{"GuiObject", {"BackgroundColor3", "BorderColor3"}},
	{"TextLabel", {"TextColor3", "TextStrokeColor3"}},
	{"TextButton", {"TextColor3", "TextStrokeColor3"}},
	{"TextBox", {"TextColor3", "TextStrokeColor3"}},
	{"ImageLabel", {"ImageColor3"}},
	{"ImageButton", {"ImageColor3"}},
	{"ScrollingFrame", {"ScrollBarImageColor3"}},
	{"UIStroke", {"Color"}},
}
local sgWatched = setmetatable({}, {__mode = "k"})

local function lightSurfaceGui(v)
	if v:IsA("SurfaceGui") then
		if not sgWatched[v] then
			sgWatched[v] = true
			if signsLit[v] == nil then signsLit[v] = v.LightInfluence end -- (Addtion-Scripts) for the full stop
			v.LightInfluence = 1
			track(v:GetPropertyChangedSignal("LightInfluence"):Connect(function()
				if v.LightInfluence ~= 1 then v.LightInfluence = 1 end
			end))
		end
		return
	end
	if not v:FindFirstAncestorWhichIsA("SurfaceGui") then return end
	for _, entry in ipairs(GUI_PROPS) do
		if v:IsA(entry[1]) then
			for _, prop in ipairs(entry[2]) do
				pcall(SetProp, v, prop)
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- CharacterMesh limbs (Ice Knight, Roblox 2.0 arms ...): their textures ignore Part.Color, so they never get
-- darkened and blow out. Draw them as a SpecialMesh instead, which the colour pass then darkens.
----------------------------------------------------------------------------------------------------
local LIMBS = {
	[Enum.BodyPart.Head] = "Head",
	[Enum.BodyPart.Torso] = "Torso",
	[Enum.BodyPart.LeftArm] = "Left Arm",
	[Enum.BodyPart.RightArm] = "Right Arm",
	[Enum.BodyPart.LeftLeg] = "Left Leg",
	[Enum.BodyPart.RightLeg] = "Right Leg",
}

local function convertCharacterMesh(cm)
	local tex = cm.OverlayTextureId ~= 0 and cm.OverlayTextureId or cm.BaseTextureId
	if tex == 0 or cm.MeshId == 0 then return end -- untextured ones are tinted by Part.Color already
	task.spawn(function()
		local char = cm.Parent
		if not char then return end
		local limb = char:WaitForChild(LIMBS[cm.BodyPart], 5)
		if not limb or not cm.Parent or stopped then return end
		local sm = limb:FindFirstChild("LegacyCharacterMesh")
		local fresh = sm == nil
		if fresh then sm = Instance.new("SpecialMesh") end
		sm.Name = "LegacyCharacterMesh"
		sm.MeshType = Enum.MeshType.FileMesh
		sm.MeshId = "rbxassetid://" .. cm.MeshId
		sm.TextureId = "rbxassetid://" .. tex
		if fresh then sm.Parent = limb end -- the colour pass darkens its VertexColor when it is added
		track(cm.AncestryChanged:Connect(function()
			if not cm:IsDescendantOf(workspace) then sm:Destroy() end
		end))
	end)
end

----------------------------------------------------------------------------------------------------
-- textured MeshParts: Roblox ignores Part.Color on a MeshPart that has a texture, so dividing the colour did
-- nothing and they blew out under the boosted light. That is every hat, hair and textured limb in games that
-- load avatars as R15 with mesh accessories (Jailbreak), while R6 games use SpecialMesh hats, which do darken.
-- Fix: draw the same mesh + texture through a welded Part + SpecialMesh (its VertexColor does tint the
-- texture, and the colour pass darkens that) and hide the original. Only on your client.
-- Limits: a limb redrawn this way no longer shows clothing painted on that limb, and if the game makes a
-- redrawn part fully invisible later, the stand-in stays visible.
----------------------------------------------------------------------------------------------------
local MESH_PROXY = "LegacyMeshProxy"
local meshFix = setmetatable({}, {__mode = "k"})
local meshFixCount = 0

local function meshScale(part)
	local ms = part.MeshSize
	if ms.X < 1e-4 or ms.Y < 1e-4 or ms.Z < 1e-4 then return nil end
	return Vector3.new(part.Size.X / ms.X, part.Size.Y / ms.Y, part.Size.Z / ms.Z)
end

local function meshFixWanted(part)
	if part.TextureID == "" or part.MeshId == "" then return false end
	if part.Material == NEON then return false end
	if part:FindFirstChildOfClass("SurfaceAppearance") then return false end -- has its own tint, darkened in handle()
	if part:FindFirstChildOfClass("WrapLayer") then return false end         -- layered clothing bends with the body
	if part:FindFirstChildWhichIsA("Bone", true) then return false end       -- skinned mesh
	local okSkin, skinned = pcall(function() return part.HasSkinnedMesh end)
	if okSkin and skinned then return false end
	if isWorn(part) then
		if part.Name == "Head" then return false end -- faces and animated heads stay as they are
		return Settings.FixTexturedMeshes == true
	end
	return Settings.FixWorldMeshes == true
end

local function fixTexturedMesh(part)
	if stopped or meshFix[part] then return end
	if not meshFixWanted(part) then return end
	if meshFixCount >= (Settings.MaxMeshFixes or 800) then return end
	local scale = meshScale(part)
	if not scale then return end

	local proxy = Instance.new("Part")
	proxy.Name = MESH_PROXY
	proxy.Anchored = false
	proxy.CanCollide = false
	proxy.CanTouch = false
	proxy.CanQuery = false
	proxy.Massless = true
	proxy.CastShadow = part.CastShadow
	proxy.Material = part.Material
	proxy.Reflectance = part.Reflectance
	proxy.Size = part.Size
	proxy.Color = part.Color -- already darkened; it only shows where the texture is see-through
	proxy.Transparency = part.Transparency
	proxy.CFrame = part.CFrame

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = part.MeshId
	mesh.TextureId = part.TextureID
	mesh.Scale = scale
	mesh.Parent = proxy

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = proxy
	weld.Parent = proxy

	local rec = {proxy = proxy, transparency = part.Transparency}
	meshFix[part] = rec
	meshFixCount += 1
	proxy.Destroying:Connect(function() meshFixCount -= 1 end)
	proxy.Parent = part -- the colour pass darkens the SpecialMesh's VertexColor when it appears

	-- hide the original; if the game changes its transparency, pass that on to the stand-in
	local _, hide = guarded(part, "Transparency", function()
		if part.Transparency < 1 then
			rec.transparency = part.Transparency
			proxy.Transparency = rec.transparency
		end
		part.Transparency = 1
	end)
	hide()

	track(part:GetPropertyChangedSignal("Color"):Connect(function() proxy.Color = part.Color end))
	track(part:GetPropertyChangedSignal("TextureID"):Connect(function() mesh.TextureId = part.TextureID end))
	track(part:GetPropertyChangedSignal("Size"):Connect(function()
		local s = meshScale(part)
		if s then
			mesh.Scale = s
			proxy.Size = part.Size
		end
	end))
end

----------------------------------------------------------------------------------------------------
-- worn MeshParts whose picture comes from MeshPart.TextureID and could not be redrawn as a stand-in part:
--   * layered clothing (the catalog's Tops > T-Shirts, Jackets, Bottoms...): a MeshPart with a WrapLayer that bends with the body
--   * the Head of a character (dynamic / animated heads are skinned meshes that carry their face in the texture)
-- Part.Color does not tint a textured MeshPart, so the picture stayed at full brightness under the boosted light while
-- everything else was darkened. A child SurfaceAppearance with the same picture is drawn instead of TextureID and has a
-- Color tint, which the colour pass darkens like everything else. The part itself stays, so it still bends and the face
-- still animates. (An item that already uses a SurfaceAppearance needs nothing: its tint is darkened in handle().)
-- Not with NoPBR on: that setting removes SurfaceAppearances, including this one.
----------------------------------------------------------------------------------------------------
local LAYERED_TEXTURE = "LegacyLayeredTexture"
local layeredCount = 0

local function isSkinnedMesh(part)
	local ok, skinned = pcall(function() return part.HasSkinnedMesh end)
	if ok and skinned then return true end
	return part:FindFirstChildWhichIsA("Bone", true) ~= nil
end

local function fixWornTexture(part)
	if stopped or keepColours or Settings.NoPBR then return end
	if part.TextureID == "" or part.Material == NEON then return end
	if meshFix[part] or part:FindFirstChild(LAYERED_TEXTURE) or part:FindFirstChildOfClass("SurfaceAppearance") then return end
	-- a head, or a mesh that sits on a head (some games draw the head from an extra skin mesh and face mesh)
	local headLike = part.Name == "Head"
		or (part.Parent ~= nil and part.Parent.Name == "Head" and part.Parent:IsA("BasePart"))
	if headLike then
		if Settings.FixDynamicHeads ~= true then return end
	else
		if Settings.FixLayeredClothing ~= true then return end
		if not (part:FindFirstChildOfClass("WrapLayer") or isSkinnedMesh(part)) then return end
	end
	if not isWorn(part) then return end

	local okMake, sa = pcall(function()
		local s = Instance.new("SurfaceAppearance")
		s.Name = LAYERED_TEXTURE
		s.ColorMap = part.TextureID
		-- AlphaMode: a part with Transparency above 0 is drawn blended, so the transparent areas of its picture are
		-- see-through (a face mesh laid over a skin mesh: the skin shows between the eyes and brows). Keep that.
		-- A part with Transparency 0 keeps the default (Overlay): transparent areas show the part's own colour, which
		-- is how a head gets its skin tone.
		if part.Transparency > 0 then s.AlphaMode = Enum.AlphaMode.Transparency end
		return s
	end)
	if not okMake or not sa then return end -- the executor was not allowed to set the picture: leave the item alone
	own(sa)
	layeredCount += 1
	sa.Destroying:Connect(function() layeredCount -= 1 end)
	track(part:GetPropertyChangedSignal("TextureID"):Connect(function()
		if sa.Parent == part and part.TextureID ~= "" then pcall(function() sa.ColorMap = part.TextureID end) end
	end))
	sa.Parent = part -- the colour pass darkens its Color when it appears
end

----------------------------------------------------------------------------------------------------
-- one entry point for everything that appears in the workspace
----------------------------------------------------------------------------------------------------
-- AutoBrightness: the boosted sun is balanced by darkening colours, but that balance only holds for dark and
-- mid colours. A white or very pale surface in the sun still ends up above pure white, so a map that is
-- mostly white washes out. This adds up how pale the map's floors are (each part's real colour, weighted by
-- its footprint) so the sun can be turned down for pale maps once the first scan is done.
-- The sums are kept up to date as parts come and go, so a game that swaps maps gets measured again.
local tallyWeight, tallyLum = 0, 0
local tallied = setmetatable({}, {__mode = "k"}) -- part -> {its weight, its weight x paleness}
local setAutoSun -- set by setupLighting

local function tallyBrightness(part)
	if tallied[part] or part.Transparency > 0.5 or colorExempt(part) then return end
	if part:IsA("MeshPart") and part.TextureID ~= "" then return end -- its texture decides the colour, not Color
	local size = part.Size
	local weight = math.min(size.X * size.Z, 10000)
	if weight < 4 then return end
	local flags = divided[part]
	local real = flags and flags.real
	local lum
	if real then
		lum = 0.3 * real.R + 0.59 * real.G + 0.11 * real.B
	else -- only the darkened colour is known: multiply it back
		local c = part.Color
		lum = (0.3 * c.R + 0.59 * c.G + 0.11 * c.B) * divisor
	end
	lum = math.min(lum, 1)
	tallied[part] = {weight, lum * weight}
	tallyWeight += weight
	tallyLum += lum * weight
end

local function untally(part)
	local rec = tallied[part]
	if rec then
		tallied[part] = nil
		tallyWeight = math.max(tallyWeight - rec[1], 0)
		tallyLum = math.max(tallyLum - rec[2], 0)
	end
end

-- The game's own lamps. Colours are darkened, so a lamp lights them far less than the game meant. While soft
-- shadows are on, or the game is a dark one, lamps are what you see by, so they are made stronger to match.
-- (Not in plain daylight without shadows: the sun already lights every room there.)
local lamps = setmetatable({}, {__mode = "k"}) -- light -> {h = its guard, factor = what its Brightness is multiplied by}
local lampFactor = 1

local function watchLamp(light)
	if lamps[light] or light.Name == "LegacyNeonLight" then return end
	local rec = {factor = 1}
	lamps[light] = rec
	local h, run = guarded(light, "Brightness", function() -- also when the game sets a new brightness (flicker, switches)
		rec.factor = lampFactor
		if lampFactor ~= 1 then light.Brightness = light.Brightness * lampFactor end
	end)
	rec.h = h
	run()
	restores[#restores + 1] = function() light.Brightness = light.Brightness / rec.factor end
end

local function setLampFactor(f)
	if f == lampFactor then return end
	lampFactor = f
	for light, rec in pairs(lamps) do
		local k = f / rec.factor
		rec.factor = f
		if k ~= 1 then
			rec.h.silently(function() light.Brightness = light.Brightness * k end)
		end
	end
end

local cloudsOff, highlightsOff, shieldsHidden = 0, 0, 0
local pbrRemoved = {}
local unionFixCount = 0
local effectsOff, guiUnlit = 0, 0

-- NoGuiLighting (2016): lit 3D GUIs (May 2017) did not exist, so a SurfaceGui / BillboardGui keeps LightInfluence 0
local function eraGuiFilter(v)
	if stopped or not Settings.NoGuiLighting or Settings.LitSurfaceGuis then return end
	if (v:IsA("SurfaceGui") or v:IsA("BillboardGui")) and hold(v, "LightInfluence", 0, true) then guiUnlit += 1 end
end
local function guiPass(v)
	if Settings.LitSurfaceGuis then lightSurfaceGui(v) end
	eraGuiFilter(v)
end

local function handle(v)
	if v.Name:sub(1, 11) == "LegacyStuds" or v.Name == MESH_PROXY then return end
	if v:IsA("BasePart") then
		if v:IsA("Terrain") then return end
		SetProp(v, "Color")
		if Settings.AutoBrightness then pcall(tallyBrightness, v) end
		addStuds(v)
		if (Settings.NeonLight or 0) > 0 and v.Material == NEON then watchNeon(v) end
		if Settings.OldMaterials and v.MaterialVariant ~= "" then -- a custom (2022) material on this one part
			hold(v, "MaterialVariant", "", true)
		end
		if Settings.NoGlass == true then pcall(swapGlass, v) end
		if not keepColours and v:IsA("MeshPart") and (Settings.FixTexturedMeshes or Settings.FixWorldMeshes) then
			pcall(fixTexturedMesh, v)
		end
		if v:IsA("MeshPart") then pcall(fixWornTexture, v) end
		-- A union draws the colours of the parts it was built from and ignores its Color property while
		-- UsePartColor is off (the default), so darkening Color did nothing and it took the whole brightness
		-- boost. Switch it on: Color is already darkened. (Not in lighting-only mode: nothing is darkened there.)
		if not keepColours and Settings.FixUnionColors and v:IsA("PartOperation") and v.Material ~= NEON then
			pcall(function()
				if not v.UsePartColor then
					v.UsePartColor = true
					unionsSwitched[v] = true
					unionFixCount += 1
				end
			end)
		end
	elseif v:IsA("SpecialMesh") then
		SetProp(v, "VertexColor")
	elseif Settings.RetroStudsWith2016Textures and isBloxyStud(v) then
		noteRetroStuds()
		hideBloxyStud(v)
	elseif v:IsA("Decal") then -- Texture is a Decal too
		SetProp(v, "Color3")
	elseif v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic") then -- ShirtGraphic = the t-shirt picture
		SetProp(v, "Color3")
	elseif v:IsA("SurfaceAppearance") then
		-- (Addtion-Scripts) a Roblox client whose SurfaceAppearance has no Color to darken: the shiny texture took
		-- the whole boost and glowed. Where the mesh has a plain texture of its own, that is shown instead
		local noTint = not pcall(function() return v.Color end)
		local plainTexture = v.Parent and v.Parent:IsA("MeshPart") and v.Parent.TextureID ~= ""
		if Settings.NoPBR or (noTint and plainTexture) then
			local part = v.Parent
			task.defer(function() -- not while Roblox is still adding it
				if stopped or v.Parent ~= part then return end
				pbrRemoved[#pbrRemoved + 1] = {v, part}
				v.Parent = nil
				if part then pcall(handle, part) end -- its plain texture shows now, so it may need redrawing
			end)
		else
			SetProp(v, "Color")
		end
	elseif v:IsA("Highlight") then
		if Settings.NoHighlights and hold(v, "Enabled", false, true) then highlightsOff += 1 end
	elseif v:IsA("Clouds") then
		if Settings.NoClouds and hold(v, "Enabled", false, true) then cloudsOff += 1 end
	elseif v:IsA("ForceField") then
		-- The spawn shield. Its modern look is a glowing shell drawn over the plain body parts (not over hats or
		-- mesh limbs), which shows up as a shiny, pale body until the shield runs out. Only the look is hidden.
		if Settings.NoSpawnShield and hold(v, "Visible", false, true) then
			shieldsHidden += 1
			print("[LegacyLighting] spawn shield shimmer hidden (" .. shieldsHidden .. " so far)")
		end
	elseif v:IsA("CharacterMesh") then
		if not keepColours then convertCharacterMesh(v) end
	elseif v:IsA("Beam") or v:IsA("Trail") or v:IsA("ParticleEmitter") then
		-- era filters (NoTrails / NoBeams / NoLitParticles): Trails (2017), Beams (November 2017) and lit particles (June 2017) did not exist yet
		if v:IsA("Beam") then
			if Settings.NoBeams and hold(v, "Enabled", false, true) then effectsOff += 1 end
		elseif v:IsA("Trail") then
			if Settings.NoTrails and hold(v, "Enabled", false, true) then effectsOff += 1 end
		elseif Settings.NoLitParticles and hold(v, "LightInfluence", 0, true) then
			effectsOff += 1
		end
		-- LightInfluence = how much the scene's light colours the effect. A lit one gets the boosted sun like a
		-- part does, so its colour needs the same darkening. An unlit one (0) glows by itself and is left alone.
		if Settings.DarkenLitEffects and v.LightInfluence >= 0.5 then
			SetProp(v, "Color")
		end
	elseif v:IsA("Light") then
		if not keepColours then watchLamp(v) end
	elseif v:IsA("WrapLayer") then -- its MeshPart may have arrived first
		local mp = v.Parent
		if mp and mp:IsA("MeshPart") then pcall(fixWornTexture, mp) end
	elseif v:IsA("Humanoid") then
		-- this model is a character: any of its parts that arrived before the Humanoid lose the pale dimming
		local model = v.Parent
		if model and not keepColours then
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then unpale(d) end
				if d:IsA("MeshPart") then pcall(fixWornTexture, d) end
			end
		end
	end
	if Settings.LitSurfaceGuis then lightSurfaceGui(v) end
	if Settings.NoGuiLighting then pcall(eraGuiFilter, v) end
end

----------------------------------------------------------------------------------------------------
-- lighting + post effects
----------------------------------------------------------------------------------------------------
local wroteLighting = {} -- (Addtion-Scripts) what this run wrote, to tell later whether the game has changed it since
local function setLighting(prop, value)
	wroteLighting[prop] = value
	pcall(function() Lighting[prop] = value end)
end

-- LIGHTING MODE
-- The brightness boost is tuned for the old Voxel look. Under Future-style lighting (Realistic style with
-- PrioritizeLightingQuality on, or the older Technology = Future) the boosted sun also puts a strong white shine
-- on every surface: glossy roads, blown-out hills and walls. Tested in Studio: Soft + quality on = fine,
-- Realistic + quality off = fine, Realistic + quality on = washed out. So the script moves the game off
-- Future-style lighting on your client only, and where the executor is not allowed to, it uses a weaker sun.
local okEnum, StyleEnum = pcall(function() return Enum.LightingStyle end)
if not okEnum then StyleEnum = nil end

local function readLighting(prop)
	local ok, v = pcall(function() return Lighting[prop] end)
	if ok then return v end
	return nil
end

-- returns true when the property ends up with that value
local function writeLighting(prop, value)
	if readLighting(prop) == nil then return false end -- this Roblox client doesn't have the property
	if readLighting(prop) ~= value then
		pcall(function() Lighting[prop] = value end)
		if readLighting(prop) ~= value and sethiddenproperty then
			pcall(function() sethiddenproperty(Lighting, prop, value) end)
		end
	end
	return readLighting(prop) == value
end

-- true while the game is in the washed-out combination
local function isWashedMode()
	return StyleEnum ~= nil
		and readLighting("LightingStyle") == StyleEnum.Realistic
		and readLighting("PrioritizeLightingQuality") == true
end

-- Technology is a hidden property; reading or writing it needs an executor that allows hidden properties.
local function readTechnology()
	local ok, v = pcall(function() return Lighting.Technology end)
	if ok then return v end
	if gethiddenproperty then
		local ok2, v2 = pcall(gethiddenproperty, Lighting, "Technology")
		if ok2 then return v2 end
	end
	return nil
end

local function isFutureTechnology()
	local ok, future = pcall(function() return Enum.Technology.Future end)
	return ok and readTechnology() == future
end

local function forceTechnology(name)
	local okTarget, target = pcall(function() return Enum.Technology[name] end)
	if not okTarget or target == nil then return "not supported by this Roblox client" end
	local before = readTechnology()
	if before == nil then return "could not be read" end
	if before == target then return "already " .. name end
	-- (Addtion-Scripts) the game's own, kept for whichever of Hammer stuff's lightings gives it back last
	if genv.BPGameTechnology == nil then genv.BPGameTechnology = before end
	pcall(function() Lighting.Technology = target end)
	if readTechnology() ~= target and sethiddenproperty then
		pcall(function() sethiddenproperty(Lighting, "Technology", target) end)
	end
	if readTechnology() == target then return "switched " .. tostring(before) .. " -> " .. name end
	return "is " .. tostring(before) .. " and the executor refused to change it"
end

local function forceVoxelTechnology()
	return forceTechnology("Voxel")
end

-- Voxel, or Compatibility (the same voxel lighting underneath)
local function isVoxelTechnology()
	local now = readTechnology()
	for _, name in ipairs({"Voxel", "Compatibility"}) do
		local ok, item = pcall(function() return Enum.Technology[name] end)
		if ok and item ~= nil and now == item then return true end
	end
	return false
end

-- (Addtion-Scripts) THE GAME'S OWN LIGHTING, for the full stop (Hammer stuff's untick), which puts it back. Read
-- once, before the first run on this server changes anything; runs that replace each other (executing again, the
-- restarts after a respawn) keep it. A value the game sets while this runs is noted too.
local GAME_PROPS = {"Brightness", "Ambient", "OutdoorAmbient", "ColorShift_Top", "ColorShift_Bottom", "GlobalShadows",
	"GeographicLatitude", "ExposureCompensation", "EnvironmentDiffuseScale", "EnvironmentSpecularScale",
	"FogEnd", "FogStart", "FogColor", "LightingStyle", "PrioritizeLightingQuality"}
local gameValues = genv.__LegacyLightingGameValues
if type(gameValues) ~= "table" then
	gameValues = {}
	for _, prop in ipairs(GAME_PROPS) do gameValues[prop] = readLighting(prop) end
	-- Hammer stuff's voxel lighting on first: what it set is not the game's; the game's own is what it kept
	local vx = genv.BPVoxelGameValues
	if genv.BPVoxelLightingOn and type(vx) == "table" then
		for prop, v in pairs(vx) do
			if prop ~= "Technology" and gameValues[prop] ~= nil then gameValues[prop] = v end
		end
	end
	genv.__LegacyLightingGameValues = gameValues
end
-- (Hammer stuff's voxel lighting reads GlobalShadows / LightingStyle / PrioritizeLightingQuality from here)
genv.LegacyLightingGameValues = gameValues

local function setupLighting()
	-- DarkGames. The script replaces the game's sun and shade light with standard daytime values, which turned a
	-- deliberately dark game into daylight. So the game's own values are read once, before anything is changed
	-- (they are kept for as long as you stay on the server), and the standard values are scaled down by how far
	-- below a normal daytime setup they are. A normal game gets a scale of 1, which changes nothing.
	local gameLight = genv.__LegacyLightingGameLight
	if type(gameLight) ~= "table" then
		gameLight = {}
		if freshServer then
			pcall(function()
				local a, o = Lighting.Ambient, Lighting.OutdoorAmbient
				gameLight.shade = math.max(0.3 * a.R + 0.59 * a.G + 0.11 * a.B, 0.3 * o.R + 0.59 * o.G + 0.11 * o.B)
				gameLight.sky = Lighting.EnvironmentDiffuseScale -- light from the sky, which this script switches off
				gameLight.exposure = Lighting.ExposureCompensation
				gameLight.brightness = Lighting.Brightness
			end)
		end
		genv.__LegacyLightingGameLight = gameLight
	end
	local sunScale, shadeScale, exposure = 1, 1, 0
	local darkNote = nil
	if Settings.DarkGames then
		if type(gameLight.brightness) == "number" then
			sunScale = math.clamp(gameLight.brightness, 0.05, 1) -- a sun of 1 or more counts as normal daytime
			shadeScale = math.clamp(((gameLight.shade or 0) + 0.3 * (gameLight.sky or 0)) / 0.25, 0.08, 1)
			exposure = math.clamp(math.min(gameLight.exposure or 0, 0), -2, 0) -- a game that darkens its picture keeps that
		else
			darkNote = "dark-game check skipped (an older copy of the script ran on this server first: rejoin to use it)"
		end
	end
	local darkness = 1 - math.min(sunScale, shadeScale) -- 0 = normal daytime game, towards 1 = a dark game
	if darkness > 0.02 or exposure < 0 then
		darkNote = string.format("dark game: sun x%.2f, shade x%.2f, exposure %.2f", sunScale, shadeScale, exposure)
	end

	local shadowsOn = false
	-- (Addtion-Scripts) whether this lighting wants the shadows on: Hammer stuff's voxel lighting, unticked while this
	-- runs, leaves GlobalShadows at this (it used to switch them off, and that was then noted as the game's own value)
	genv.LegacyLightingShadows = false
	local flat = Color3.new(0.5, 0.5, 0.5)
	setLighting("Brightness", 2 * sunScale)
	setLighting("Ambient", mul(flat, shadeScale))
	setLighting("ColorShift_Top", Color3.new())
	setLighting("ColorShift_Bottom", Color3.new())
	hold(Lighting, "EnvironmentDiffuseScale", 0)  -- 2019+: kept at 0 even if the game writes it again
	hold(Lighting, "EnvironmentSpecularScale", 0)
	local shadowsArmed = false -- (Addtion-Scripts) true while a change can only have come from the game
	local _, runShadows = guarded(Lighting, "GlobalShadows", function() -- off, or on once soft shadows are switched on
		-- (Addtion-Scripts) Hammer stuff's voxel lighting on: its soft voxel shadows stay
		if genv.BPVoxelLightingOn then return end
		if Lighting.GlobalShadows ~= shadowsOn then
			if shadowsArmed then gameValues.GlobalShadows = Lighting.GlobalShadows end
			Lighting.GlobalShadows = shadowsOn
		end
	end)
	runShadows()
	shadowsArmed = true
	setLighting("OutdoorAmbient", mul(flat, shadeScale))
	-- ClockTime is deliberately not touched: the game's own time of day (and its day/night cycle) stays in charge
	setLighting("GeographicLatitude", 41.733)
	hold(Lighting, "ExposureCompensation", exposure)
	if not Settings.KeepGameFog then
		setLighting("FogEnd", 100000)
		setLighting("FogStart", 0)
		setLighting("FogColor", Color3.fromRGB(192, 192, 192))
	end

	-- brighter light, darker colours
	local intensity = keepColours and 1 or Settings.LegacyIntensity
	local sunBoost = intensity * (Settings.SunBoost or 2.1)
	local ambientBoost = intensity * (Settings.AmbientBoost or 1.2)
	if keepColours then -- nothing was darkened, so only a mild boost
		sunBoost = Settings.KeepSun or 1.5
		ambientBoost = Settings.KeepAmbient or 1.3
	end
	local lightArmed = false -- (Addtion-Scripts) from here on a new value is the game's: noted for the full stop
	local hSun, runBrightness = guarded(Lighting, "Brightness", function()
		if lightArmed then gameValues.Brightness = Lighting.Brightness end
		Lighting.Brightness = Lighting.Brightness * sunBoost
	end)
	runBrightness()
	local hAmbient = {}
	local indoorFactor = 1 -- below 1 once soft shadows are on: the light under cover is dimmer than outdoors
	for _, prop in ipairs({"Ambient", "OutdoorAmbient"}) do
		local h, runAmbient = guarded(Lighting, prop, function()
			if lightArmed then gameValues[prop] = Lighting[prop] end
			Lighting[prop] = mul(Lighting[prop], ambientBoost * (prop == "Ambient" and indoorFactor or 1))
		end)
		hAmbient[prop] = h
		runAmbient()
	end
	lightArmed = true

	-- Soft shadows, 2016-2018 style. Voxel lighting draws sun shadows as soft blurry blobs, which is the old look.
	-- With GlobalShadows on, Roblox also lights open sky areas with OutdoorAmbient and covered areas with Ambient.
	local function lampTarget() -- full LampBoost with shadows on or in a dark game, none in plain daylight
		if keepColours then return 1 end
		local boost = math.max(tonumber(Settings.LampBoost) or 2.7, 1)
		return 1 + (boost - 1) * math.max(shadowsOn and 1 or 0, darkness)
	end
	local function setShadows(on)
		shadowsOn = on
		genv.LegacyLightingShadows = on
		shadowsArmed = false
		runShadows()
		shadowsArmed = true
		local f = on and math.clamp((tonumber(Settings.IndoorAmbient) or 0.4) / 0.5, 0.05, 1) or 1
		hAmbient.Ambient.silently(function() Lighting.Ambient = mul(Lighting.Ambient, f / indoorFactor) end)
		indoorFactor = f
		setLampFactor(lampTarget())
	end
	setLampFactor(lampTarget())

	-- swap to other boost values after the first ones were applied. The sun actually used is the chosen
	-- boost times the AutoBrightness factor, but never weaker than LegacyIntensity itself.
	local baseSun, baseAmbient, autoFactor = sunBoost, ambientBoost, 1
	local function refreshBoost()
		local newSun = math.max(baseSun * autoFactor, math.min(baseSun, intensity))
		local newAmbient = baseAmbient
		local ks, ka = newSun / sunBoost, newAmbient / ambientBoost
		sunBoost, ambientBoost = newSun, newAmbient
		hSun.silently(function() Lighting.Brightness = Lighting.Brightness * ks end)
		for prop, h in pairs(hAmbient) do
			h.silently(function() Lighting[prop] = mul(Lighting[prop], ka) end)
		end
	end
	local function useBoost(newSun, newAmbient)
		baseSun, baseAmbient = newSun, newAmbient
		refreshBoost()
	end
	setAutoSun = function(factor)
		autoFactor = factor
		refreshBoost()
		return sunBoost / intensity -- the SunBoost value now in use
	end

	local futureMode = false -- true once the game turned out to stay on Future lighting
	live.applyBoosts = function() -- the sun / shade settings were changed while running
		if stopped or keepColours then return end
		if futureMode then
			useBoost(intensity * (tonumber(Settings.FutureSunBoost) or 1.2), intensity * (tonumber(Settings.FutureAmbientBoost) or 1.7))
		else
			useBoost(intensity * (tonumber(Settings.SunBoost) or 2.1), intensity * (tonumber(Settings.AmbientBoost) or 1.2))
		end
	end
	live.status = function()
		return {sun = sunBoost / intensity, auto = autoFactor, future = futureMode, lightingOnly = keepColours,
			shadows = shadowsOn, lamps = lampFactor, sunScale = sunScale, shadeScale = shadeScale}
	end
	live.applyLamps = function() -- LampBoost was changed while running
		if not stopped then setLampFactor(lampTarget()) end
	end
	live.applyShadows = function() -- Shadows or IndoorAmbient was changed while running
		if stopped then return end
		pcall(setShadows, Settings.Shadows == true and isVoxelTechnology())
	end

	-- lighting mode (see LIGHTING MODE above). On the side, because it has to wait a few frames.
	task.spawn(function()
		local report = {}
		-- (Addtion-Scripts) Hammer stuff's voxel lighting or its other legacy lighting on: that one holds the technology
		local techHeld = genv.BPVoxelLightingOn or genv.BPLegacyLightingOn
		if techHeld then
			report[#report + 1] = "technology left to Hammer stuff's " .. (genv.BPVoxelLightingOn and "voxel" or "legacy") .. " lighting"
		elseif Settings.ForceVoxel then
			report[#report + 1] = "technology " .. forceVoxelTechnology()
		end

		local accepted = false
		if Settings.SoftLighting and StyleEnum then
			writeLighting("LightingStyle", StyleEnum.Soft)
			-- A game can READ Soft / off and still RENDER Future: Jailbreak does, its old Technology setting stays in
			-- charge until one of the new properties really changes. Writing the value a property already has changes
			-- nothing, so switch the quality setting on and back off to make the engine pick the mode up again.
			local flipped = writeLighting("PrioritizeLightingQuality", true)
			task.wait(0.15)
			local quality = writeLighting("PrioritizeLightingQuality", false)
			if stopped then return end
			accepted = flipped and quality
			for _, prop in ipairs({"LightingStyle", "PrioritizeLightingQuality"}) do
				track(Lighting:GetPropertyChangedSignal(prop):Connect(function() -- the game switched it back
					if not stopped and isWashedMode() then
						writeLighting("LightingStyle", StyleEnum.Soft)
						writeLighting("PrioritizeLightingQuality", false)
					end
				end))
			end
			report[#report + 1] = "soft lighting " .. (accepted and "applied" or "refused by the executor")
		end

		-- after the soft-lighting switch above, which makes the engine pick its mode again
		if Settings.TryCompatibility and not techHeld and not stopped then
			local result = forceTechnology("Compatibility")
			task.wait(0.5)
			if stopped then return end
			report[#report + 1] = "compatibility test: " .. result .. ", half a second later it reads " .. tostring(readTechnology())
		end

		if isWashedMode() or (not accepted and isFutureTechnology()) then
			futureMode = true
			useBoost(intensity * (Settings.FutureSunBoost or 1.2), intensity * (Settings.FutureAmbientBoost or 1.7))
			report[#report + 1] = "game stays on Future lighting, so the weaker sun is used"
		end
		if darkNote then report[#report + 1] = darkNote end
		if Settings.Shadows and not stopped then
			if isVoxelTechnology() then
				local okShadows = pcall(setShadows, true)
				report[#report + 1] = okShadows and "soft shadows on" or "soft shadows failed"
			else
				report[#report + 1] = "soft shadows left off (the game is not on Voxel lighting)"
			end
		end
		print("[LegacyLighting] lighting mode: " .. (#report > 0 and table.concat(report, "; ") or "left alone"))
	end)
end

local heldEffects = setmetatable({}, {__mode = "k"})

-- (Addtion-Scripts) the game's own effects as they were, for the full stop; kept across runs like the colours
local gameEffects = genv.__LegacyLightingEffects
if type(gameEffects) ~= "table" then
	gameEffects = setmetatable({}, {__mode = "k"})
	genv.__LegacyLightingEffects = gameEffects
end

local function stripEffect(e)
	if ownedSet[e] then return end
	pcall(function()
		-- (Addtion-Scripts) Hammer stuff's other legacy lighting's grey colour correction stays on
		if e:GetAttribute("BPLegacyLighting") or e:GetAttribute("BPIWLegacyLighting") then return end
		if gameEffects[e] == nil then
			if e:IsA("PostEffect") then
				gameEffects[e] = {Enabled = e.Enabled}
			elseif e:IsA("Atmosphere") then
				gameEffects[e] = {Density = e.Density, Haze = e.Haze, Glare = e.Glare}
			end
		end
		if e:IsA("PostEffect") then -- bloom, sunrays, depth of field, blur, colour correction/grading
			e.Enabled = false
			if not heldEffects[e] and (e:IsA("BloomEffect") or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect")) then
				heldEffects[e] = true
				hold(e, "Enabled", false) -- stays off even if the game switches it back on
			end
		elseif e:IsA("Atmosphere") then -- 2020: haze and sun glare. Kept at zero even if the game tweens it
			if not heldEffects[e] then
				heldEffects[e] = true
				hold(e, "Density", 0)
				hold(e, "Haze", 0)
				hold(e, "Glare", 0)
			end
		end
	end)
end

local function stripAllEffects()
	for _, e in ipairs(Lighting:GetChildren()) do stripEffect(e) end
	local cam = workspace.CurrentCamera
	if cam then
		for _, e in ipairs(cam:GetChildren()) do stripEffect(e) end
	end
end

local function setupEffects()
	local cc = own(Instance.new("ColorCorrectionEffect"))
	cc.Name = "LegacyCorrection"
	cc.Saturation = tonumber(Settings.Saturation) or 0.2
	cc.Brightness = tonumber(Settings.ToneBrightness) or 0
	cc.TintColor = Color3.new(1, 1, 1)
	cc.Contrast = tonumber(Settings.Contrast) or 0.08
	cc:SetAttribute("BPIWLegacyLighting", true) -- (Hammer stuff's other legacy lighting leaves these alone)
	cc.Parent = Lighting
	live.applyTone = function()
		if stopped then return end
		cc.Saturation = tonumber(Settings.Saturation) or 0.2
		cc.Contrast = tonumber(Settings.Contrast) or 0.08
		cc.Brightness = tonumber(Settings.ToneBrightness) or 0
	end

	pcall(function()
		local cg = own(Instance.new("ColorGradingEffect"))
		cg.Name = "LegacyGrading"
		cg.TonemapperPreset = Settings.Voxel2019 and Enum.TonemapperPreset.Default or Enum.TonemapperPreset.Retro
		cg:SetAttribute("BPIWLegacyLighting", true)
		cg.Parent = Lighting
	end)

	local bloom = own(Instance.new("BloomEffect"))
	bloom.Name = "LegacyBloom"
	bloom.Threshold = Settings.BloomThreshold
	bloom.Intensity = Settings.NeonBloom
	bloom.Size = Settings.BloomSize
	bloom:SetAttribute("BPIWLegacyLighting", true)
	bloom.Parent = Lighting

	if Settings.StripGameEffects then
		stripAllEffects()
		track(Lighting.ChildAdded:Connect(stripEffect))
		local cam = workspace.CurrentCamera
		if cam then
			track(cam.ChildAdded:Connect(stripEffect))
		end
	end
end

----------------------------------------------------------------------------------------------------
-- terrain: its colours are not Part.Color, so the colour pass never darkened it and it took the whole
-- brightness boost (pale ground, glowing grass, white sand). Terrain has one colour per material; divide
-- those the same way. The grass blades use the Grass material colour, so they follow.
-- There is no change event for these colours, so they are checked every 2 seconds: if the game set a new
-- colour (or Roblox reset them), the new colour is darkened again.
----------------------------------------------------------------------------------------------------
-- A terrain colour read back later can differ a little from the one that was written (a report showed 0.07
-- coming back as 0.06). The first version of this code took that for "the game changed the colour" and
-- darkened it again, every 2 seconds, until the terrain was nearly black and grey.
-- So a colour only counts as changed by the game when it is clearly BRIGHTER than the darkened one written
-- (a game sets real, full-strength colours), never when it has merely drifted.
local function clearlyBrighter(now, written)
	return now.R > written.R + 0.08 or now.G > written.G + 0.08 or now.B > written.B + 0.08
end

-- The colour written for a terrain material whose real colour is `real`: darkened like a part, then a bit more
-- and with the grey film taken off (measured on sunlit grass: about 1.25x too bright plus a constant grey).
-- The sums are done on linear light values, which is how Roblox adds light up.
local function terrainTarget(real)
	local d = div(real, divisor)
	local extra = math.max(tonumber(Settings.TerrainDarken) or 1, 0.1)
	local haze = math.max(tonumber(Settings.TerrainHaze) or 0, 0)
	if extra == 1 and haze == 0 then return d end
	local function channel(x)
		local linear = (x ^ 2.2) / extra
		-- never below 45% of the plain result, so dark rock or mud does not drop to black
		return math.clamp(math.max(linear - haze, linear * 0.45) ^ (1 / 2.2), 0, 1)
	end
	return Color3.new(channel(d.R), channel(d.G), channel(d.B))
end

local function closeColours(a, b)
	return math.abs(a.R - b.R) < 0.08 and math.abs(a.G - b.G) < 0.08 and math.abs(a.B - b.B) < 0.08
end

local function startTerrain()
	if keepColours or not Settings.DarkenTerrain then return end
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if not terrain then return end

	-- remembers the real colours and the ones this script wrote, across runs, so running it again never
	-- darkens terrain twice
	local state = genv.__LegacyLightingTerrain
	if type(state) == "table" and state.terrain == terrain and state.version ~= 2 then
		print("[LegacyLighting] terrain here was darkened by an older version of this script, which kept darkening it until it went grey. REJOIN the game to get its real colours back; it is left alone until then.")
		return
	end
	if type(state) ~= "table" or state.terrain ~= terrain then
		state = {version = 2, terrain = terrain, orig = {}, set = {}, count = {}}
		genv.__LegacyLightingTerrain = state
	end

	local materials = {}
	for _, m in ipairs(Enum.Material:GetEnumItems()) do
		if pcall(function() return terrain:GetMaterialColor(m) end) then
			materials[#materials + 1] = m
		end
	end

	-- The terrain settings differ from the ones the colours here were written with (an earlier copy of the script,
	-- or you changed TerrainDarken / TerrainHaze): write them again from the real colours. No rejoin needed.
	local function rewriteTerrain(quiet)
		local formula = string.format("%.3f/%.4f", tonumber(Settings.TerrainDarken) or 1, tonumber(Settings.TerrainHaze) or 0)
		if state.formula == formula then return end
		local redone = 0
		for _, m in ipairs(materials) do
			local name = m.Name
			local real, ours = state.orig[name], state.set[name]
			-- only where the colour is still the one this script wrote (the game has not set another since)
			if real and ours and closeColours(terrain:GetMaterialColor(m), ours) then
				local target = terrainTarget(real)
				state.set[name] = target
				pcall(function() terrain:SetMaterialColor(m, target) end)
				redone += 1
			end
		end
		state.formula = formula
		if redone > 0 and not quiet then print("[LegacyLighting] terrain colours rewritten with the current terrain settings: " .. redone) end
	end
	pcall(rewriteTerrain)
	live.refreshTerrain = function()
		if not stopped then pcall(rewriteTerrain, true) end
	end

	local function apply()
		local changed = 0
		for _, m in ipairs(materials) do
			local name = m.Name
			local cur = terrain:GetMaterialColor(m)
			local ours = state.set[name]
			local times = state.count[name] or 0
			-- darken when it has never been done, or when the game has clearly set a new colour since.
			-- Never more than 4 times for one material, whatever happens.
			if (ours == nil or clearlyBrighter(cur, ours)) and times < 4 then
				local target = terrainTarget(cur)
				state.orig[name] = cur
				state.set[name] = target
				state.count[name] = times + 1
				pcall(function() terrain:SetMaterialColor(m, target) end)
				changed += 1
			end
		end
		return changed
	end

	local okFirst, first = pcall(apply)
	print("[LegacyLighting] terrain materials darkened: " .. tostring(okFirst and first or ("failed: " .. tostring(first))))
	task.spawn(function()
		while not stopped do
			task.wait(2)
			if stopped then break end
			pcall(apply)
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- things that did not exist in 2016-2018 and are not instances in the workspace
----------------------------------------------------------------------------------------------------
local extraNotes = {}
local materialService -- set when OldMaterials is in use

local function readHidden(inst, prop)
	local ok, v = pcall(function() return inst[prop] end)
	if ok then return v end
	if gethiddenproperty then
		local ok2, v2 = pcall(gethiddenproperty, inst, prop)
		if ok2 then return v2 end
	end
	return nil
end

-- these two properties are not scriptable, so this only works where the executor can write hidden properties
local function switchHidden(inst, prop, value, label)
	if readHidden(inst, prop) ~= (not value) then return end -- already as wanted, or not readable
	pcall(function() inst[prop] = value end)
	if readHidden(inst, prop) ~= value and sethiddenproperty then
		pcall(function() sethiddenproperty(inst, prop, value) end)
	end
	if readHidden(inst, prop) == value then
		extraNotes[#extraNotes + 1] = label
		restores[#restores + 1] = function()
			pcall(function() inst[prop] = not value end)
			if readHidden(inst, prop) == value and sethiddenproperty then sethiddenproperty(inst, prop, not value) end
		end
	else
		extraNotes[#extraNotes + 1] = label .. " REFUSED by the executor"
	end
end

-- custom materials (2022) that a game puts in place of a built-in one, e.g. its own shiny cobblestone
local function clearMaterialOverrides(ms)
	local cleared = 0
	for _, m in ipairs(Enum.Material:GetEnumItems()) do
		pcall(function()
			local name = ms:GetBaseMaterialOverride(m)
			if name ~= "" then
				ms:SetBaseMaterialOverride(m, "")
				cleared += 1
				restores[#restores + 1] = function() ms:SetBaseMaterialOverride(m, name) end
			end
		end)
	end
	return cleared
end

local function startLegacyExtras()
	if Settings.NoWind then
		local okWind, wind = pcall(function() return workspace.GlobalWind end)
		if okWind and typeof(wind) == "Vector3" then
			local blowing = wind.Magnitude > 0.01
			if hold(workspace, "GlobalWind", Vector3.new(0, 0, 0), true) then
				extraNotes[#extraNotes + 1] = blowing and "wind stopped" or "no wind in this game"
			end
		end
	end
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if Settings.NoGrassBlades and terrain then
		switchHidden(terrain, "Decoration", false, "grass blades off")
	end
	if Settings.OldMaterials then
		local okMs, ms = pcall(function() return game:GetService("MaterialService") end)
		if okMs and ms then
			materialService = ms
			switchHidden(ms, "Use2022Materials", false, "pre-2022 material textures on")
			extraNotes[#extraNotes + 1] = "custom material overrides removed: " .. clearMaterialOverrides(ms)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- outlines (optional): thin dark edges on plain bricks near the camera, like 2016-2017. Only block-shaped
-- Parts get one (an outline box around a wedge or a mesh would be the wrong shape). Checked once a second.
----------------------------------------------------------------------------------------------------
local function startOutlines()
	if not Settings.Outlines then return end
	local radius = tonumber(Settings.OutlineDistance) or 120
	local maxBoxes = tonumber(Settings.MaxOutlines) or 1200
	local folder = own(Instance.new("Folder"))
	folder.Name = "LegacyOutlines"
	folder.Parent = workspace.CurrentCamera or workspace -- things under the camera exist on your client only

	local params = OverlapParams.new()
	params.MaxParts = maxBoxes * 4
	local boxes = {}
	local count = 0

	-- Parts of a character (limbs, tools, accessories) get no outline: the box would not follow the outfit, and
	-- it floated around the arm, torso and legs. Looked up per model once per refresh (a big map model can hold thousands of parts).
	local charCache = {}
	local function onCharacter(part)
		local p = part.Parent
		for _ = 1, 3 do
			if not p or p == workspace then return false end
			if p:IsA("Model") then
				local c = charCache[p]
				if c == nil then
					c = p:FindFirstChildOfClass("Humanoid") ~= nil
					charCache[p] = c
				end
				if c then return true end
			end
			p = p.Parent
		end
		return false
	end

	local function wanted(part)
		if part.ClassName ~= "Part" or part.Name == MESH_PROXY then return false end
		if onCharacter(part) then return false end
		if part.Shape ~= Enum.PartType.Block or part.Transparency > 0.5 then return false end
		if part.Size.X < 0.4 and part.Size.Y < 0.4 and part.Size.Z < 0.4 then return false end
		if part:FindFirstChildWhichIsA("DataModelMesh") then return false end
		return true
	end

	local function refresh()
		local cam = workspace.CurrentCamera
		if not cam then return end
		charCache = {}
		local near = {}
		for _, part in ipairs(workspace:GetPartBoundsInRadius(cam.CFrame.Position, radius, params)) do
			local ok, yes = pcall(wanted, part)
			if ok and yes then near[part] = true end
		end
		for part, box in pairs(boxes) do
			if not near[part] then
				box:Destroy()
				boxes[part] = nil
				count -= 1
			end
		end
		for part in pairs(near) do
			if count >= maxBoxes then break end
			if not boxes[part] then
				local box = Instance.new("SelectionBox")
				box.Name = "LegacyOutline"
				box.LineThickness = tonumber(Settings.OutlineThickness) or 0.01
				box.Color3 = typeof(Settings.OutlineColor) == "Color3" and Settings.OutlineColor or Color3.new(0, 0, 0)
				box.Transparency = tonumber(Settings.OutlineTransparency) or 0.85
				box.SurfaceTransparency = 1
				box.Adornee = part
				box.Parent = folder
				boxes[part] = box
				count += 1
			end
		end
	end

	task.spawn(function()
		while not stopped do
			pcall(refresh)
			task.wait(1)
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- start
----------------------------------------------------------------------------------------------------
local function stop()
	stopped = true
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	for _, h in ipairs(holders) do
		if h.conn then pcall(function() h.conn:Disconnect() end) end
	end
	for _, i in ipairs(created) do pcall(function() i:Destroy() end) end
	for _, fn in ipairs(restores) do pcall(fn) end -- clouds, highlights, grass blades ... back to how the game had them
	for _, r in ipairs(pbrRemoved) do pcall(function() r[1].Parent = r[2] end) end
	for part, rec in pairs(meshFix) do -- show the original meshes again
		pcall(function() part.Transparency = rec.transparency end)
		pcall(function() rec.proxy:Destroy() end)
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		if d.Name == "LegacyNeonLight" or d.Name == MESH_PROXY or d.Name:sub(1, 11) == "LegacyStuds" then
			pcall(function() d:Destroy() end)
		end
	end
	if genv.__LegacyLightingReplace == stop then
		genv.LegacyLightingShadows = nil
		genv.__LegacyLightingReplace = nil
		genv.LegacyLightingStop = nil
		genv.LegacyLightingOriginal = nil
	end
end

----------------------------------------------------------------------------------------------------
-- (Addtion-Scripts) THE FULL STOP: Hammer stuff's untick (getgenv().LegacyLightingStop). stop() above is what a
-- new run calls to take over (the colours stay darkened for it, so nothing is darkened twice); this one also puts
-- the game back as it was: colours, unions, terrain, the game's effects, the lighting and the technology.
----------------------------------------------------------------------------------------------------
local function undarken(v)
	if typeof(v) == "Color3" then
		return clamp01(mul(v, divisor))
	elseif typeof(v) == "Vector3" then
		return v * divisor
	elseif typeof(v) == "ColorSequence" then
		local keys = {}
		for i, k in ipairs(v.Keypoints) do
			keys[i] = ColorSequenceKeypoint.new(k.Time, clamp01(mul(k.Value, divisor)))
		end
		return ColorSequence.new(keys)
	end
	return v
end

-- the game's own value of a property this script darkens
local function originalValue(inst, prop)
	local value = inst[prop]
	local flags = divided[inst]
	if type(flags) ~= "table" or flags[prop] ~= true then return value end
	if prop == "Color" and inst:IsA("BasePart") then
		if colorExempt(inst) then return value end -- (never darkened)
		return flags.real or clamp01(mul(value, divisor))
	end
	return undarken(value)
end

local function sameValue(a, b)
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) <= 1e-3 * math.max(1, math.abs(b))
	elseif typeof(a) == "Color3" and typeof(b) == "Color3" then
		return math.abs(a.R - b.R) < 0.01 and math.abs(a.G - b.G) < 0.01 and math.abs(a.B - b.B) < 0.01
	end
	return a == b
end

local function putGameBack()
	-- colours (parts, meshes, decals, clothes, signs, effects), from the notes every run kept
	local colours = 0
	for inst, flags in pairs(divided) do
		if type(flags) == "table" then
			for prop, on in pairs(flags) do
				if on == true and pcall(function() inst[prop] = originalValue(inst, prop) end) then
					colours += 1
				end
			end
		end
	end
	for union in pairs(unionsSwitched) do
		pcall(function() union.UsePartColor = false end)
	end
	for sign, was in pairs(signsLit) do
		pcall(function() sign.LightInfluence = was end)
	end
	-- terrain: each material whose colour is still the one written here
	local tstate = genv.__LegacyLightingTerrain
	if type(tstate) == "table" and tstate.version == 2 and tstate.terrain then
		for name, real in pairs(tstate.orig) do
			pcall(function()
				local m = Enum.Material[name]
				local ours = tstate.set[name]
				if ours and closeColours(tstate.terrain:GetMaterialColor(m), ours) then
					tstate.terrain:SetMaterialColor(m, real)
				end
			end)
		end
	end
	-- the game's own effects
	for e, was in pairs(gameEffects) do
		for prop, v in pairs(was) do pcall(function() e[prop] = v end) end
	end
	-- the lighting. With Hammer stuff's voxel lighting still on, the shadows, the environment light and the
	-- lighting style stay its own (it gives the game's back, from the values it took from here).
	local voxelOn = genv.BPVoxelLightingOn
	for _, prop in ipairs({"Brightness", "Ambient", "OutdoorAmbient", "ExposureCompensation"}) do
		if gameValues[prop] ~= nil then setLighting(prop, gameValues[prop]) end
	end
	if not voxelOn then
		for _, prop in ipairs({"GlobalShadows", "EnvironmentDiffuseScale", "EnvironmentSpecularScale"}) do
			if gameValues[prop] ~= nil then setLighting(prop, gameValues[prop]) end
		end
	end
	-- only where this script's value is still there (the game's own later changes stay)
	for _, prop in ipairs({"ColorShift_Top", "ColorShift_Bottom", "GeographicLatitude", "FogEnd", "FogStart", "FogColor"}) do
		local ours = wroteLighting[prop]
		if ours ~= nil and gameValues[prop] ~= nil and sameValue(readLighting(prop), ours) then
			setLighting(prop, gameValues[prop])
		end
	end
	if not voxelOn and StyleEnum then
		if gameValues.LightingStyle ~= nil then writeLighting("LightingStyle", gameValues.LightingStyle) end
		if gameValues.PrioritizeLightingQuality ~= nil then
			writeLighting("PrioritizeLightingQuality", gameValues.PrioritizeLightingQuality)
		end
	end
	-- the technology: given back by the last of Hammer stuff's lightings to stop
	if not voxelOn and not genv.BPLegacyLightingOn and genv.BPGameTechnology ~= nil then
		local original = genv.BPGameTechnology
		genv.BPGameTechnology = nil
		if readTechnology() ~= original then
			pcall(function() Lighting.Technology = original end)
			if readTechnology() ~= original and sethiddenproperty then
				pcall(function() sethiddenproperty(Lighting, "Technology", original) end)
			end
		end
	end
	-- (CharacterMesh limbs drawn as a SpecialMesh)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d.Name == "LegacyCharacterMesh" and d:IsA("SpecialMesh") then pcall(function() d:Destroy() end) end
	end
	-- a fresh start next time: nothing darkened, the game's own values read again
	genv.__LegacyLightingDivided = nil
	genv.__LegacyLightingDivisor = nil
	genv.__LegacyLightingUnions = nil
	genv.__LegacyLightingSigns = nil
	genv.__LegacyLightingTerrain = nil
	genv.__LegacyLightingEffects = nil
	genv.__LegacyLightingGameValues = nil
	genv.__LegacyLightingGameLight = nil
	genv.LegacyLightingGameValues = nil
	genv0.__LegacyLightingRespawnToken = {} -- (restarts still waiting after a respawn are cancelled)
	return colours
end

local function fullStop()
	if genv.LegacyLightingStop == fullStop then genv.LegacyLightingStop = nil end
	stop()
	local ok, colours = pcall(putGameBack)
	print("[LegacyLighting] stopped: " .. (ok and ("the game is back as it was (" .. tostring(colours) .. " colours put back)")
		or ("putting the game back failed: " .. tostring(colours))))
end

genv.__LegacyLightingReplace = stop
genv.LegacyLightingStop = fullStop
genv.LegacyLightingOriginal = function(inst, prop)
	if stopped then return inst[prop] end
	return originalValue(inst, prop)
end

setupLighting()
setupEffects()
startTerrain()
pcall(startLegacyExtras)
pcall(startOutlines)

track(workspace.DescendantAdded:Connect(function(v) pcall(handle, v) end))
track(workspace.DescendantRemoving:Connect(function(v) untally(v) end))
task.spawn(function() -- big maps: work through the existing parts in chunks so the game does not freeze
	local n = 0
	for _, v in ipairs(workspace:GetDescendants()) do
		if stopped then return end
		pcall(handle, v)
		n += 1
		if n % 300 == 0 then task.wait() end
	end
	print("[LegacyLighting] textured meshes redrawn so they darken too: " .. meshFixCount .. " | unions switched to their darkened colour: " .. unionFixCount .. " | worn textures darkened (layered clothing and heads): " .. layeredCount)
	if Settings.AutoBrightness and setAutoSun and not stopped then
		-- measured now, and again every few seconds: when the map has changed enough (a game that swaps maps,
		-- a map that streams in) the sun is set again
		local lastFactor = nil
		local function evaluate(later)
			if tallyWeight <= 0 then return end
			local mean = tallyLum / tallyWeight -- 0 = black map, 1 = white map
			local factor = 1 - math.clamp((mean - 0.6) / 0.25, 0, 1) * 0.45 -- only clearly pale maps (above 0.6) get a weaker sun
			if lastFactor and math.abs(factor - lastFactor) < 0.04 then return end
			lastFactor = factor
			local okAuto, used = pcall(setAutoSun, factor)
			print(string.format("[LegacyLighting] auto brightness: map paleness %.2f -> SunBoost in use %s", mean, okAuto and string.format("%.2f", used) or "unchanged (failed)") .. (later and " (the map changed)" or ""))
		end
		evaluate(false)
		task.spawn(function()
			while not stopped do
				task.wait(4)
				if stopped then break end
				pcall(evaluate, true)
			end
		end)
	end
	local extras = {"clouds hidden: " .. cloudsOff, "highlights hidden: " .. highlightsOff, "spawn shields hidden: " .. shieldsHidden, "PBR textures removed: " .. #pbrRemoved, "3D GUIs kept unlit: " .. guiUnlit, "trails/beams hidden or particles unlit: " .. effectsOff}
	for _, note in ipairs(extraNotes) do extras[#extras + 1] = note end
	print("[LegacyLighting] 2019+ extras: " .. table.concat(extras, " | "))
	table.clear(pinned) -- every part is watched again now, so the notes are safe
end)

if Settings.LitSurfaceGuis or Settings.NoGuiLighting then
	task.spawn(function() -- SurfaceGuis parented to PlayerGui (with an Adornee) draw in the world too
		local pg = player:WaitForChild("PlayerGui", 10)
		if not pg or stopped then return end
		track(pg.DescendantAdded:Connect(function(v) pcall(guiPass, v) end))
		local n = 0
		for _, v in ipairs(pg:GetDescendants()) do
			if stopped then return end
			pcall(guiPass, v)
			n += 1
			if n % 300 == 0 then task.wait() end
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- respawning
----------------------------------------------------------------------------------------------------
-- After you respawn, the script is restarted a few times (see RestartOnRespawn), the same as pressing execute
-- again each time. The timing is handled below the main function, because every restart ends this run.
track(player.CharacterAdded:Connect(function(char)
	if not stopped then scheduleRestarts(char) end
end))

print("[LegacyLighting] colour mode: " .. modeNote)
print("[LegacyLighting] " .. YEAR .. " running. The time of day follows the game. Run the script again to replace it.")
end

-- One restart can come too early: a character arrives in pieces over several seconds, and pressing execute by
-- hand sometimes took two tries for the same reason. So there are several, spread out.
scheduleRestarts = function(char)
	local times = Settings.RestartOnRespawn
	if type(times) == "number" then times = {times} end
	if type(times) ~= "table" or #times == 0 then return end
	local token = {}
	genv0.__LegacyLightingRespawnToken = token -- a newer respawn, or a fresh execute, cancels these
	for i, seconds in ipairs(times) do
		if type(seconds) == "number" then
			task.delay(math.max(seconds, 0.5), function()
				if genv0.__LegacyLightingRespawnToken ~= token then return end
				if type(genv0.LegacyLightingStop) ~= "function" then return end -- the script was switched off
				if not char:IsDescendantOf(workspace) then return end -- that character is already gone
				print("[LegacyLighting] restart " .. i .. " of " .. #times .. " after respawn")
				LegacyLightingMain()
			end)
		end
	end
end

LegacyLightingMain()
