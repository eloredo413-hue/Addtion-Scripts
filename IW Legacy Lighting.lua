-- (Addtion-Scripts) Hammer stuff 2's "iw legacy lighting" loads this file; unticking calls
-- getgenv().LegacyLightingStop(), which puts the game back as it was: lighting, effects, colours and terrain.
--[[
	LEGACY 2017 LIGHTING  -  client side only
	Only YOU see any of this: it never touches the server, so nobody else in the game sees it.

	* Run it again whenever you like. The new run replaces the old one (it won't darken things twice).
	* The time of day is left to the game: morning, day, evening and night follow the game's own clock,
	  so a day/night cycle keeps working. There is no time box any more.
	* Everything you may want to change is in Settings below.

	(Addtion-Scripts changes)
	* Stopping it puts everything back: every darkened colour (parts, meshes, decals, clothes, terrain, sign
	  text), the lighting, the game's own effects, unions, lit signs, clouds/highlights, redrawn meshes.
	  It used to leave the colours darkened, the lighting changed and the game's effects off.
	* Works with Classic Face: the classic head gets the same light as the body (the two scripts no longer
	  fight over the head's colour every frame), and its face is lit like other decals.
	* Loads faster: the characters first, then the map in timed slices (as much as fits in a few milliseconds
	  a frame), then a second look for anything missed. It takes the time it needs: the light only comes up
	  once everything is done, so there is no washed-out white while it loads.
	* Its own changes are recognised by their value (not by switching the watcher off and on), so they never
	  set it off again: nothing gets darkened twice and the sun is never boosted twice, whatever the game does.
	* getgenv().LegacyLightingOriginal(instance, property) gives the game's own (undarkened) value.
	* No studs of its own are forced on. Only where Bloxy's "2016 textures" has put its stud textures (picked in
	  the wizard, also while this runs) is each one swapped for this script's stud, made for this lighting
	  (Bloxy's came out far too dark under it); when Bloxy's goes, this script's goes too, and stopping this
	  gives Bloxy's back. Never on players or NPCs (their body, hats or the tool in their hand).
	* Lamps show at night: light sources are made stronger by as much as the colours they light are darkened.
	  Nothing glows like neon that shouldn't: textured meshes in the map are darkened too (they kept their full
	  colour under the boosted light), and so are particles, beams and trails that take the scene's light.
]]

local Settings = {
	LegacyIntensity  = 3,     -- the original value
	LegacyStuds      = false, -- studs on every plain part that uses the Studs surface (off: none are forced on)
	RetroStudsWith2016Textures = true, -- (Addtion-Scripts) where Bloxy's "2016 textures" puts its stud textures, each
	                          -- is swapped for this script's (Bloxy's are hidden while this runs and come back when it
	                          -- stops; under this lighting they came out far too dark). Nowhere else.
	Voxel2019        = false, -- true = modern tonemapper instead of the retro one
	LitSurfaceGuis   = true,  -- text/images on parts follow the lighting like parts do
	NeonLight        = 1.5,   -- light given off by neon parts in the world (0 = off)
	NeonBloom        = 0,     -- screen glow. Leave at 0: under this lighting it also makes sunlit skin/eyes glow
	BloomSize        = 24,
	BloomThreshold   = 3,
	StripGameEffects = true,  -- switch off the game's own bloom/atmosphere/sunrays/blur so they don't fight the look
	ForceVoxel       = true,  -- try to switch a Future / ShadowMap game to Voxel lighting, the 2017 kind
	SoftLighting     = true,  -- move the game off Future-style lighting, which makes the map shiny and overbright
	SunBoost         = 2.1,   -- how much stronger the sun is made. Lower it (try 1.6) if a map is still too bright
	AmbientBoost     = 1.2,   -- how much stronger the shade light is made
	FutureSunBoost   = 1.2,   -- used instead when the game stays on Future lighting: a weaker sun means less white shine
	FutureAmbientBoost = 1.7, -- ...and more shade light, so the picture does not get darker overall
	AutoBrightness   = true,  -- weaker sun on maps built mostly from white / very pale parts, which otherwise wash out.
	                          -- Dark and mid-coloured maps are left as they are. Set false to always use SunBoost as written
	                          -- (Addtion-Scripts) it looks at what is around the camera every few seconds too, so a white
	                          -- town and a dark forest in one game each get their own
	PaleMapSun       = 0.85,  -- (Addtion-Scripts) the sun on the palest places, as a share of the game's (1 = as bright as the
	                          -- game without this lighting). It was never below about 1.1, which still washed white maps out
	PaleMapAmbient   = 1.0,   -- (Addtion-Scripts) the same for the shade light
	AutoBrightnessEvery = 3,  -- (Addtion-Scripts) seconds between two looks around the camera
	AutoBrightnessRadius = 160, -- (Addtion-Scripts) studs around the camera looked at
	FixTexturedMeshes = true, -- redraw textured mesh hats/hair/limbs on characters so they darken too (they went white in R15 games)
	FixWorldMeshes   = true,  -- (Addtion-Scripts: on) the same for textured meshes in the map (props, trees, furniture...),
	                          -- which otherwise kept their full colour under the boosted light and glowed like neon
	MaxMeshFixes     = 800,   -- upper limit for the characters' ones
	MaxWorldMeshFixes = 1000, -- (Addtion-Scripts) upper limit for the map's ones (counted apart, so players' hats always get theirs)
	BrightLamps      = true,  -- (Addtion-Scripts) lamps and other lights (PointLight, SpotLight, SurfaceLight) as bright as in the game:
	                          -- what they light is darkened, so they are made stronger by the same amount (they hardly showed at night)
	DimLitParticles  = true,  -- (Addtion-Scripts) particles, beams and trails that take the scene's light are darkened like colours
	                          -- (they took the whole boost and glowed)
	DarkenTerrain    = true,  -- darken terrain (ground, sand, rock and the grass blades) like parts, so it stops blowing out
	FixUnionColors   = true,  -- unions ignore their Color, so they never darkened and went pure white. This makes them use it.
	                          -- A union built from parts of several colours becomes one colour; set false if that looks wrong

	-- things Roblox did not have in 2016-2018, switched off on your client
	NoClouds         = true,  -- moving 3D clouds (2020)
	NoGrassBlades    = true,  -- grass blades on terrain (2019). Needs an executor that can write hidden properties
	NoHighlights     = true,  -- Highlight outlines / glows (2021). Set false if a game uses them to show you things
	OldMaterials     = true,  -- built-in materials only: removes the game's custom (2022) materials, and switches to the
	                          -- pre-2022 textures where the executor can write hidden properties
	NoPBR            = false, -- remove SurfaceAppearance (2020 shiny PBR textures). A mesh that has no plain texture turns flat-coloured

	-- (Addtion-Scripts) loading
	SliceTime        = 0.008, -- seconds of work a frame while it goes through the map the first time
	LightUpAfter     = false, -- false: the light comes up only once the whole map is done, however long that takes.
	                          -- A number of seconds: at most that long
}

----------------------------------------------------------------------------------------------------
-- replace the previous run
----------------------------------------------------------------------------------------------------
local genv = (getgenv and getgenv()) or _G
if type(genv.LegacyLightingStop) == "function" then
	pcall(genv.LegacyLightingStop)
end

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
while not player do
	task.wait()
	player = Players.LocalPlayer
end

local startedAt = os.clock()
local stopped = false
local conns = {}
local created = {}                                    -- instances this script made; stop() destroys them
local ownedSet = setmetatable({}, { __mode = "k" })   -- of those, the ones the colour pass leaves alone
local restores = {}                                   -- put something back; stop() runs them, last first

local function track(c)
	conns[#conns + 1] = c
	return c
end

local function own(i) -- made by this script and left alone by the colour pass
	created[#created + 1] = i
	ownedSet[i] = true
	return i
end

local function made(i) -- made by this script, but darkened like the game's own
	created[#created + 1] = i
	return i
end

local function onStop(fn)
	restores[#restores + 1] = fn
end

----------------------------------------------------------------------------------------------------
-- colour helpers
----------------------------------------------------------------------------------------------------
local divisor = Settings.LegacyIntensity * 0.9

local function clamp01(c)
	return Color3.new(math.clamp(c.R, 0, 1), math.clamp(c.G, 0, 1), math.clamp(c.B, 0, 1))
end

local function mul(c, m)
	return Color3.new(c.R * m, c.G * m, c.B * m)
end

local function darken(v)
	if typeof(v) == "Color3" then
		return clamp01(Color3.new(v.R / divisor, v.G / divisor, v.B / divisor))
	elseif typeof(v) == "Vector3" then
		return v / divisor
	end
	return v
end

local function lighten(v) -- the other way round (for colours darkened by an older version of this script)
	if typeof(v) == "Color3" then
		return clamp01(mul(v, divisor))
	elseif typeof(v) == "Vector3" then
		return v * divisor
	end
	return v
end

local function read(inst, prop)
	local ok, v = pcall(function() return inst[prop] end)
	if ok then return v end
	return nil
end

-- Keeps inst[prop] at value, also when the game writes it again (the game's last value is remembered).
-- restore = put the game's value back when the script stops.
local function hold(inst, prop, value, restore)
	local before = read(inst, prop)
	if before == nil then return false end
	local rec = { game = before }
	local function apply()
		if stopped then return end
		local cur = read(inst, prop)
		if cur ~= value then
			rec.game = cur
			pcall(function() inst[prop] = value end)
		end
	end
	track(inst:GetPropertyChangedSignal(prop):Connect(apply))
	apply()
	if restore then
		onStop(function()
			if read(inst, prop) == value then inst[prop] = rec.game end
		end)
	end
	return true
end

----------------------------------------------------------------------------------------------------
-- darkening colours (parts, meshes, decals, clothes, gui) - the lighting is boosted to compensate
----------------------------------------------------------------------------------------------------
-- For each (instance, property) darkened: orig = the game's own value, last = what this script wrote (nil
-- while it is left as the game has it). A change that reads back as `last` is this script's own; anything
-- else is the game's, and is darkened once. Kept in getgenv so a new run knows what an old one left.
local colorState = genv.__LegacyLightingColors
if type(colorState) ~= "table" then
	colorState = setmetatable({}, { __mode = "k" })
	genv.__LegacyLightingColors = colorState
end
-- what the previous version of this script darkened (it never put colours back)
local oldFlags = genv.__LegacyLightingDivided
if type(oldFlags) ~= "table" then oldFlags = nil end

local handledProp = setmetatable({}, { __mode = "k" }) -- instance -> { [prop] = true } in this run

genv.LegacyLightingOriginal = function(inst, prop)
	local recs = colorState[inst]
	local rec = recs and recs[prop]
	if rec and not stopped then return rec.orig end
	return inst[prop]
end

local NEON = Enum.Material.Neon

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

local function writeDark(inst, prop, rec)
	rec.writing = true -- (games with immediate signals call the watcher during the write itself)
	local ok = pcall(function() inst[prop] = darken(rec.orig) end)
	rec.writing = false
	if ok then rec.last = read(inst, prop) end -- read back: a part's colour is kept with 8 bits a channel
end

local function onColorChanged(inst, prop)
	if stopped then return end
	local recs = colorState[inst]
	local rec = recs and recs[prop]
	if not rec or rec.writing then return end
	local cur = read(inst, prop)
	if cur == nil or (rec.last ~= nil and cur == rec.last) then return end -- our own write coming back
	rec.orig = cur
	if rec.exempt then
		rec.last = nil
	else
		pcall(writeDark, inst, prop, rec)
	end
end

local refreshNeonLight, watchNeon -- (neon lights, below)
local studsFollowMaterial -- (studs, below)

-- the material or the head's mesh changed: neon / a textured head keep their colour, the rest is darkened
local function recheck(part)
	if stopped then return end
	local recs = colorState[part]
	local rec = recs and recs.Color
	if rec then
		local now = colorExempt(part)
		if now ~= rec.exempt then
			rec.exempt = now
			if now then
				if rec.last ~= nil and part.Color == rec.last then
					rec.writing = true
					pcall(function() part.Color = rec.orig end)
					rec.writing = false
				end
				rec.last = nil
			else
				rec.orig = part.Color
				pcall(writeDark, part, "Color", rec)
			end
		end
	end
	if (Settings.NeonLight or 0) > 0 then
		if part.Material == NEON then watchNeon(part) else refreshNeonLight(part) end
	end
	if studsFollowMaterial then pcall(studsFollowMaterial, part) end
end

local function watchHeadMesh(head)
	local function watchMesh(m)
		if m:IsA("SpecialMesh") then
			track(m:GetPropertyChangedSignal("TextureId"):Connect(function() recheck(head) end))
			recheck(head)
		end
	end
	for _, c in ipairs(head:GetChildren()) do watchMesh(c) end
	track(head.ChildAdded:Connect(watchMesh))
	track(head.ChildRemoved:Connect(function(c)
		if c:IsA("SpecialMesh") then recheck(head) end
	end))
end

local function SetProp(inst, prop)
	local done = handledProp[inst]
	if not done then
		done = {}
		handledProp[inst] = done
	end
	if done[prop] then return end
	done[prop] = true

	local cur = read(inst, prop)
	if cur == nil then return end
	local recs = colorState[inst]
	if not recs then
		recs = {}
		colorState[inst] = recs
	end
	local isPartColor = prop == "Color" and inst:IsA("BasePart")
	local exempt = isPartColor and colorExempt(inst) or false
	local rec = recs[prop]
	if rec and rec.last ~= nil and cur == rec.last then
		-- still darkened by a run that was never stopped: kept as it is
	else
		local old = oldFlags and oldFlags[inst]
		if old and old[prop] and not exempt then
			rec = { orig = lighten(cur), last = cur } -- darkened by the previous version of this script
		else
			rec = { orig = cur, last = nil }
		end
		if old then old[prop] = nil end
		recs[prop] = rec
	end
	rec.exempt = exempt
	if rec.exempt then
		if rec.last ~= nil then
			rec.writing = true
			pcall(function() inst[prop] = rec.orig end)
			rec.writing = false
			rec.last = nil
		end
	elseif rec.last == nil then
		pcall(writeDark, inst, prop, rec)
	end

	if isPartColor then
		-- one watcher for the colour and the material
		track(inst.Changed:Connect(function(changed)
			if changed == "Color" then
				onColorChanged(inst, "Color")
			elseif changed == "Material" then
				recheck(inst)
			end
		end))
		if inst.Name == "Head" then watchHeadMesh(inst) end
	else
		track(inst:GetPropertyChangedSignal(prop):Connect(function() onColorChanged(inst, prop) end))
	end
end

local function restoreColors()
	for inst, recs in pairs(colorState) do
		for prop, rec in pairs(recs) do
			if rec.last ~= nil then
				pcall(function()
					if inst[prop] == rec.last then inst[prop] = rec.orig end
				end)
			end
		end
		colorState[inst] = nil
	end
end

----------------------------------------------------------------------------------------------------
-- neon: emissive, so it keeps its colour, and gives off a light (not when worn/held by a character)
----------------------------------------------------------------------------------------------------
local MAX_NEON_LIGHTS = 60
local neonLightCount = 0
local neonWatched = setmetatable({}, { __mode = "k" })

local function isWorn(part)
	local p = part.Parent
	while p and p ~= workspace do
		if p:FindFirstChildOfClass("Humanoid") then return true end
		p = p.Parent
	end
	return false
end

refreshNeonLight = function(part)
	if stopped then return end
	local light = part:FindFirstChild("LegacyNeonLight")
	if part.Material == NEON and part.Transparency < 0.9 and not isWorn(part) and part:IsDescendantOf(workspace) then
		if not light then
			if neonLightCount >= MAX_NEON_LIGHTS then return end
			neonLightCount += 1
			light = own(Instance.new("PointLight"))
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

watchNeon = function(part)
	if neonWatched[part] then return end
	neonWatched[part] = true
	refreshNeonLight(part)
	track(part.AncestryChanged:Connect(function() refreshNeonLight(part) end))
	for _, prop in ipairs({ "Color", "Transparency", "Size" }) do
		track(part:GetPropertyChangedSignal(prop):Connect(function() refreshNeonLight(part) end))
	end
end

----------------------------------------------------------------------------------------------------
-- studs: only plain block parts, never on players or NPCs (a Top-face texture gets stretched over a whole
-- mesh, which showed up as skin-coloured patches on character limbs; and players don't get studs at all:
-- their body, hats and the tool in their hand)
----------------------------------------------------------------------------------------------------
local FACES = { "Back", "Bottom", "Front", "Left", "Right", "Top" }

-- part of a character: its body, a hat (in an accessory) or a tool it holds, at any depth
local function onCharacter(part)
	local p = part.Parent
	while p and p ~= workspace do
		if p:FindFirstChildOfClass("Humanoid") then return true end
		if p:IsA("Model") and Players:GetPlayerFromCharacter(p) then return true end
		p = p.Parent
	end
	return false
end

local function studsAllowed(part)
	if part:IsA("MeshPart") then return false end
	if part:FindFirstChildWhichIsA("DataModelMesh") then return false end
	if onCharacter(part) then return false end
	return true
end

local function studTextures(part)
	local list = {}
	for _, t in ipairs(part:GetChildren()) do
		if t:IsA("Texture") and ownedSet[t] then list[#list + 1] = t end
	end
	return list
end

-- studs on every Studs face only with LegacyStuds; with Bloxy's "2016 textures" only where Bloxy's are (RETRO STUDS)
local retroStuds = Settings.LegacyStuds == true
local studWatched = setmetatable({}, { __mode = "k" })

-- this script's stud texture on one face of a part (made once; true when it is there)
local function ensureStud(part, face)
	local name = "LegacyStuds" .. face
	if part:FindFirstChild(name) then return false end
	local t = own(Instance.new("Texture"))
	t.Name = name
	t.Texture = "rbxassetid://13225057574"
	t.StudsPerTileU = 2
	t.StudsPerTileV = 2
	t.Face = Enum.NormalId[face]
	t.Transparency = 0
	t.Color3 = mul(part.Color, 2.5)
	t.Parent = part
	return true
end

local watchStudPart -- (below)

-- (only Plastic, as in 2016 and as Bloxy's 2016 textures do: called again when the material changes)
local function addStuds(part)
	if not retroStuds then return end
	if not (part:IsA("Part") or part:IsA("WedgePart")) then return end
	if part.Material ~= Enum.Material.Plastic or not studsAllowed(part) then
		local list = studTextures(part)
		local worn = #list > 0 and onCharacter(part)
		for _, t in ipairs(list) do
			-- (a face mirrored from Bloxy's 2016 studs stays while Bloxy's is there, see RETRO STUDS, but not
			-- on a character)
			local face = string.sub(t.Name, 12)
			if worn or not part:FindFirstChild(face .. "Surface_ClassicTexture") then t:Destroy() end
		end
		-- on a character for now (a tool in a hand): watched, so it gets its studs once it is put down
		if part.Material == Enum.Material.Plastic and not studWatched[part] and onCharacter(part) then
			for _, face in ipairs(FACES) do
				if part[face .. "Surface"] == Enum.SurfaceType.Studs then
					watchStudPart(part)
					break
				end
			end
		end
		return
	end
	local madeAny = false
	for _, face in ipairs(FACES) do
		if part[face .. "Surface"] == Enum.SurfaceType.Studs then
			if ensureStud(part, face) then madeAny = true end
		end
	end
	if madeAny then watchStudPart(part) end
end

-- this script's studs off a part that is on a character now
local function clearWornStuds(part)
	if stopped or not onCharacter(part) then return end
	for _, t in ipairs(studTextures(part)) do pcall(function() t:Destroy() end) end
end

watchStudPart = function(part)
	if not studWatched[part] then
		studWatched[part] = true
		track(part:GetPropertyChangedSignal("Color"):Connect(function()
			for _, t in ipairs(studTextures(part)) do t.Color3 = mul(part.Color, 2.5) end
		end))
		track(part.ChildAdded:Connect(function(child)
			if child:IsA("DataModelMesh") then
				for _, t in ipairs(studTextures(part)) do t.Transparency = 1 end
			end
		end))
		-- picked up (a tool from the ground) or put on a character: its studs go; put down again: back
		track(part.AncestryChanged:Connect(function()
			if stopped then return end
			if onCharacter(part) then
				clearWornStuds(part)
			elseif part:IsDescendantOf(workspace) then
				pcall(addStuds, part)
			end
		end))
		-- (a character whose Humanoid shows up a moment after its parts)
		task.defer(clearWornStuds, part)
	end
end
studsFollowMaterial = addStuds

----------------------------------------------------------------------------------------------------
-- RETRO STUDS with Bloxy's "2016 textures": that choice puts a stud texture ("TopSurface_ClassicTexture" ...)
-- on every stud face of the Plastic parts, coloured from the part. Under this lighting it came out far too dark
-- (the part is darkened, and so was its texture), so while this runs the two are switched one for one: each of
-- Bloxy's stud faces is hidden (kept at Transparency 1) and gets this script's stud on the same part and face,
-- made for this lighting; when Bloxy takes one away, this script's goes too. Stopping gives Bloxy's back as they
-- were (this script's are removed).
----------------------------------------------------------------------------------------------------
local function isBloxyStud(v)
	return v.ClassName == "Texture" and string.find(v.Name, "Surface_ClassicTexture$") ~= nil
end

local bloxyHidden = setmetatable({}, { __mode = "k" })
local function hideBloxyStud(t)
	if bloxyHidden[t] then return end
	bloxyHidden[t] = true
	hold(t, "Transparency", 1, true)
	-- this script's stud on the same face ("TopSurface_ClassicTexture" -> "Top")
	local part = t.Parent
	local face = string.match(t.Name, "^(%a+)Surface_ClassicTexture$")
	if not (part and part:IsA("BasePart") and face and Enum.NormalId[face]) then return end
	-- (on a player or NPC: Bloxy's stays hidden and none of ours either)
	if not onCharacter(part) and ensureStud(part, face) then watchStudPart(part) end
	track(t.AncestryChanged:Connect(function()
		if stopped then return end
		local ours = part:FindFirstChild("LegacyStuds" .. face)
		if t.Parent ~= part or onCharacter(part) then
			-- Bloxy took its stud away (the face isn't studs any more, or the part isn't Plastic), or the part
			-- is on a character now (a tool picked up): ours goes too
			if ours and ownedSet[ours] then pcall(function() ours:Destroy() end) end
		elseif not ours and part:IsDescendantOf(workspace) then
			-- off the character again (a tool put down): ours back
			if ensureStud(part, face) then watchStudPart(part) end
		end
	end))
end

-- Bloxy's saved texture choice
local function bloxyTextures()
	local ok, choice = pcall(function()
		if not (readfile and isfile and isfile("BloxyParadoxConfig.json")) then return nil end
		local cfg = game:GetService("HttpService"):JSONDecode(readfile("BloxyParadoxConfig.json"))
		return type(cfg) == "table" and type(cfg.Choices) == "table" and cfg.Choices.Textures or nil
	end)
	return ok and choice or nil
end

if Settings.RetroStudsWith2016Textures and tostring(bloxyTextures()) == "2016" then
	print("[LegacyLighting] Bloxy's 2016 textures are picked: its stud textures are swapped for this lighting's")
end

-- Bloxy's stud textures seen (picked while this runs, or put on a part): only noted. The swap itself is one for
-- one, in hideBloxyStud, for the texture that showed up (no studs anywhere Bloxy has none).
local swapNoted = false
local function enableRetroStuds()
	if swapNoted or stopped or not Settings.RetroStudsWith2016Textures then return end
	swapNoted = true
	print("[LegacyLighting] Bloxy's 2016 stud textures found: swapped for this lighting's, one for one")
end

----------------------------------------------------------------------------------------------------
-- text/images on SurfaceGuis: unlit by default, so they stayed full-bright. Light them like parts and
-- darken their colours the same way.
----------------------------------------------------------------------------------------------------
local GUI_PROPS = {
	{ "GuiObject", { "BackgroundColor3", "BorderColor3" } },
	{ "TextLabel", { "TextColor3", "TextStrokeColor3" } },
	{ "TextButton", { "TextColor3", "TextStrokeColor3" } },
	{ "TextBox", { "TextColor3", "TextStrokeColor3" } },
	{ "ImageLabel", { "ImageColor3" } },
	{ "ImageButton", { "ImageColor3" } },
	{ "ScrollingFrame", { "ScrollBarImageColor3" } },
	{ "UIStroke", { "Color" } },
}
local sgWatched = setmetatable({}, { __mode = "k" })

local function lightSurfaceGui(v)
	if v:IsA("SurfaceGui") then
		if not sgWatched[v] then
			sgWatched[v] = true
			hold(v, "LightInfluence", 1, true)
		end
		return
	end
	-- (the class first: looking up the ancestors of everything in the map was the slowest part of loading)
	if not (v:IsA("GuiObject") or v:IsA("UIStroke")) then return end
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
		if fresh then sm = made(Instance.new("SpecialMesh")) end
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
local meshFix = setmetatable({}, { __mode = "k" })
local meshFixCount = 0      -- on characters
local worldMeshFixCount = 0 -- in the map
-- (Addtion-Scripts) every textured mesh in the map that wants redrawing, redrawn or not. A big map has more than
-- MaxWorldMeshFixes; the ones left over kept their full colour and glowed like neon wherever you went. Now the
-- nearest ones to the camera are the redrawn ones, swapped as you move (see NEAREST MESHES below).
local worldCandidates = setmetatable({}, { __mode = "k" })

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
	local worn = isWorn(part)
	if worn then
		if meshFixCount >= (Settings.MaxMeshFixes or 800) then return end
	else
		worldCandidates[part] = true
		if worldMeshFixCount >= (Settings.MaxWorldMeshFixes or 1000) then return end
	end
	local scale = meshScale(part)
	if not scale then return end

	local proxy = own(Instance.new("Part"))
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

	local rec = { proxy = proxy, transparency = part.Transparency, conns = {}, counted = true, worn = worn }
	meshFix[part] = rec
	if worn then
		meshFixCount += 1
	else
		worldMeshFixCount += 1
	end
	proxy.Destroying:Connect(function()
		if not rec.counted then return end -- (already taken off the count when it was undone)
		rec.counted = false
		if rec.worn then meshFixCount -= 1 else worldMeshFixCount -= 1 end
	end)
	local function keep(c) -- (its own watchers, kept with it: undoing it, or stopping, disconnects them)
		rec.conns[#rec.conns + 1] = c
		return c
	end
	proxy.Parent = part -- the colour pass darkens the SpecialMesh's VertexColor when it appears

	-- hide the original; if the game changes its transparency, pass that on to the stand-in
	local function hide()
		if stopped then return end
		local t = part.Transparency
		if t ~= 1 then
			rec.transparency = t
			proxy.Transparency = t
			part.Transparency = 1
		end
	end
	keep(part:GetPropertyChangedSignal("Transparency"):Connect(hide))
	hide()

	keep(part:GetPropertyChangedSignal("Color"):Connect(function() proxy.Color = part.Color end))
	keep(part:GetPropertyChangedSignal("TextureID"):Connect(function() mesh.TextureId = part.TextureID end))
	keep(part:GetPropertyChangedSignal("Size"):Connect(function()
		local s = meshScale(part)
		if s then
			mesh.Scale = s
			proxy.Size = part.Size
		end
	end))
end

-- a redrawn map mesh back as the game has it (it is far away now: a nearer one gets the redraw)
local function unfixTexturedMesh(part)
	local rec = meshFix[part]
	if not rec then return end
	meshFix[part] = nil
	for _, c in ipairs(rec.conns) do pcall(function() c:Disconnect() end) end
	if rec.counted then
		rec.counted = false
		if rec.worn then meshFixCount -= 1 else worldMeshFixCount -= 1 end
	end
	pcall(function()
		if part.Transparency == 1 then part.Transparency = rec.transparency end
	end)
	pcall(function() rec.proxy:Destroy() end)
end

-- NEAREST MESHES: with more textured meshes in the map than MaxWorldMeshFixes, the redrawn ones are the nearest
-- to the camera. Run every few seconds: far redrawn ones (well past the nearest MaxWorldMeshFixes, so nothing
-- flickers at the edge) are undone and the near ones redrawn, at most MESH_SWAPS of each a time.
local MESH_SWAPS = 150
local function nearestMeshes()
	local cap = Settings.MaxWorldMeshFixes or 1000
	local cam = workspace.CurrentCamera
	if stopped or not cam then return end
	local camPos = cam.CFrame.Position
	local list = {}
	for part in pairs(worldCandidates) do
		if part.Parent and part:IsDescendantOf(workspace) then
			list[#list + 1] = { part = part, d = (part.Position - camPos).Magnitude }
		else
			worldCandidates[part] = nil
		end
	end
	local swaps = 0
	if #list > cap then
		table.sort(list, function(a, b) return a.d < b.d end)
		local edge = list[cap].d * 1.15 + 10
		for i = #list, cap + 1, -1 do
			local e = list[i]
			if e.d <= edge then break end
			if meshFix[e.part] then
				unfixTexturedMesh(e.part)
				swaps += 1
				if swaps >= MESH_SWAPS then break end
			end
		end
	end
	local fixed = 0
	for i = 1, math.min(#list, cap) do
		local part = list[i].part
		if not meshFix[part] then
			if worldMeshFixCount >= cap then break end
			pcall(fixTexturedMesh, part)
			fixed += 1
			if fixed >= MESH_SWAPS then break end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- (Addtion-Scripts) light sources and lit particles. The colours are darkened and the sun and shade light
-- boosted to make up for it, but a lamp's own light (PointLight, SpotLight, SurfaceLight) was not boosted, so
-- what it lit came out at about a third of the game's brightness: at night lamps hardly showed. Their
-- Brightness is raised by as much as the colours are lowered. Particles, beams and trails that take the
-- scene's light (LightInfluence above 0) are the other way round: they took the whole boost and glowed, so the
-- lit share of their Brightness is lowered like a colour. Kept when the game changes them again (a flickering
-- lamp), recognised by value like the colours, and put back when this stops.
----------------------------------------------------------------------------------------------------
local LIGHT_CLASSES = { PointLight = true, SpotLight = true, SurfaceLight = true }
local LIT_FX_CLASSES = { ParticleEmitter = true, Beam = true, Trail = true }

-- instance -> { orig = the game's Brightness, last = what this script wrote }, kept in getgenv like the colours
local brightState = genv.__LegacyLightingBrightness
if type(brightState) ~= "table" then
	brightState = setmetatable({}, { __mode = "k" })
	genv.__LegacyLightingBrightness = brightState
end

local function brightnessFactor(inst)
	if LIGHT_CLASSES[inst.ClassName] then return divisor end
	local influence = math.clamp(read(inst, "LightInfluence") or 0, 0, 1)
	return 1 - influence + influence / divisor
end

local function writeBrightness(inst, rec)
	rec.writing = true -- (games with immediate signals call the watcher during the write itself)
	pcall(function() inst.Brightness = rec.orig * brightnessFactor(inst) end)
	rec.writing = false
	rec.last = read(inst, "Brightness")
end

local function adjustBrightness(inst)
	if LIGHT_CLASSES[inst.ClassName] then
		if not Settings.BrightLamps then return end
	elseif not Settings.DimLitParticles then
		return
	end
	local cur = read(inst, "Brightness")
	if type(cur) ~= "number" then return end -- (an older Roblox client without it)
	local rec = brightState[inst]
	if not (rec and rec.last ~= nil and cur == rec.last) then -- (still set by a run that was never stopped: kept)
		rec = { orig = cur }
		brightState[inst] = rec
	end
	writeBrightness(inst, rec)
	track(inst:GetPropertyChangedSignal("Brightness"):Connect(function()
		if stopped or rec.writing then return end
		local now = read(inst, "Brightness")
		if now == nil or now == rec.last then return end -- our own write coming back
		rec.orig = now
		writeBrightness(inst, rec)
	end))
	if LIT_FX_CLASSES[inst.ClassName] then
		track(inst:GetPropertyChangedSignal("LightInfluence"):Connect(function()
			if not stopped then writeBrightness(inst, rec) end
		end))
	end
end

onStop(function()
	for inst, rec in pairs(brightState) do
		pcall(function()
			if rec.last ~= nil and inst.Brightness == rec.last then inst.Brightness = rec.orig end
		end)
		brightState[inst] = nil
	end
end)

----------------------------------------------------------------------------------------------------
-- one entry point for everything that appears in the workspace
----------------------------------------------------------------------------------------------------
local unionFixCount = 0

-- AutoBrightness: the boosted sun is balanced by darkening colours, but that balance only holds for dark and
-- mid colours. A white or very pale surface in the sun still ends up above pure white, so a map that is
-- mostly white washes out. This adds up how pale the map's floors are (each part's real colour, weighted by
-- its footprint) so the sun can be turned down for pale maps once the first scan is done.
local tallyWeight, tallyLum, tallyDone = 0, 0, false

local function tallyBrightness(part)
	if tallyDone or part.Transparency > 0.5 or colorExempt(part) then return end
	if part:IsA("MeshPart") and part.TextureID ~= "" then return end -- its texture decides the colour, not Color
	local size = part.Size
	local weight = math.min(size.X * size.Z, 10000)
	if weight < 4 then return end
	local recs = colorState[part]
	local c = (recs and recs.Color and recs.Color.orig) or part.Color -- the game's own colour
	local lum = math.min(0.3 * c.R + 0.59 * c.G + 0.11 * c.B, 1)
	tallyWeight += weight
	tallyLum += lum * weight
end
local cloudsOff, highlightsOff = 0, 0
local pbrRemoved = {}
local handled = setmetatable({}, { __mode = "k" }) -- everything handled in this run (once each)

local function handle(v)
	if handled[v] or ownedSet[v] then return end
	handled[v] = true
	if v:IsA("BasePart") then
		if v:IsA("Terrain") or v.Name == MESH_PROXY then return end
		SetProp(v, "Color")
		if Settings.AutoBrightness then pcall(tallyBrightness, v) end
		addStuds(v)
		if (Settings.NeonLight or 0) > 0 and v.Material == NEON then watchNeon(v) end
		if Settings.OldMaterials and v.MaterialVariant ~= "" then -- a custom (2022) material on this one part
			hold(v, "MaterialVariant", "", true)
		end
		if v:IsA("MeshPart") and (Settings.FixTexturedMeshes or Settings.FixWorldMeshes) then
			pcall(fixTexturedMesh, v)
			if not meshFix[v] and v.TextureID == "" and isWorn(v) then
				-- its texture can come a moment later (an avatar still loading): it is redrawn then
				local c
				c = v:GetPropertyChangedSignal("TextureID"):Connect(function()
					if stopped or meshFix[v] then c:Disconnect() return end
					pcall(fixTexturedMesh, v)
					if meshFix[v] then c:Disconnect() end
				end)
				track(c)
			end
		end
		-- A union draws the colours of the parts it was built from and ignores its Color property while
		-- UsePartColor is off (the default), so darkening Color did nothing. Switch it on: Color is already darkened.
		if Settings.FixUnionColors and v:IsA("PartOperation") and v.Material ~= NEON then
			pcall(function()
				if not v.UsePartColor then
					v.UsePartColor = true
					unionFixCount += 1
					onStop(function()
						if v.UsePartColor then v.UsePartColor = false end
					end)
				end
			end)
		end
		return
	end
	local class = v.ClassName
	if class == "SpecialMesh" then
		SetProp(v, "VertexColor")
	elseif class == "Decal" or class == "Texture" then
		if string.sub(v.Name, 1, 11) == "LegacyStuds" then return end -- (left by an older run)
		if Settings.RetroStudsWith2016Textures and isBloxyStud(v) then
			enableRetroStuds()
			hideBloxyStud(v)
			return
		end
		SetProp(v, "Color3")
	elseif class == "Shirt" or class == "Pants" then
		SetProp(v, "Color3")
	elseif class == "SurfaceAppearance" then
		-- (Addtion-Scripts) a Roblox client whose SurfaceAppearance has no Color to darken: the shiny texture took
		-- the whole boost and glowed. Where the mesh has a plain texture of its own, that is shown instead (it gets
		-- redrawn and darkened); otherwise it is left
		local noTint = read(v, "Color") == nil
		local plainTexture = v.Parent and v.Parent:IsA("MeshPart") and v.Parent.TextureID ~= ""
		if Settings.NoPBR or (noTint and plainTexture) then
			local part = v.Parent
			task.defer(function() -- not while Roblox is still adding it
				if stopped or v.Parent ~= part then return end
				pbrRemoved[#pbrRemoved + 1] = { v, part }
				v.Parent = nil
				-- its plain texture shows now, so it may need redrawing
				if part and part:IsA("MeshPart") then pcall(fixTexturedMesh, part) end
			end)
		else
			SetProp(v, "Color")
		end
	elseif class == "Highlight" then
		if Settings.NoHighlights and hold(v, "Enabled", false, true) then highlightsOff += 1 end
	elseif class == "Clouds" then
		if Settings.NoClouds and hold(v, "Enabled", false, true) then cloudsOff += 1 end
	elseif class == "CharacterMesh" then
		convertCharacterMesh(v)
	elseif LIGHT_CLASSES[class] or LIT_FX_CLASSES[class] then
		adjustBrightness(v)
	elseif Settings.LitSurfaceGuis then
		lightSurfaceGui(v)
	end
end

----------------------------------------------------------------------------------------------------
-- lighting + post effects
----------------------------------------------------------------------------------------------------
-- the game's lighting as it was, put back by stop() wherever this script's value is still there
local SNAPSHOT_PROPS = {
	"Brightness", "Ambient", "OutdoorAmbient", "ColorShift_Top", "ColorShift_Bottom", "GlobalShadows",
	"GeographicLatitude", "FogEnd", "FogStart", "FogColor",
}
local snapshot = {}
for _, prop in ipairs(SNAPSHOT_PROPS) do
	snapshot[prop] = read(Lighting, prop)
end
-- (Addtion-Scripts) the game's own values of what Hammer stuff's "voxel lighting" changes too, so that one can be on
-- together with this and still give the game's back (see VOXEL LIGHTING TOGETHER below)
local gameShadows = snapshot.GlobalShadows
if genv.BPVoxelLightingOn and type(genv.BPVoxelGameValues) == "table" and genv.BPVoxelGameValues.GlobalShadows ~= nil then
	gameShadows = genv.BPVoxelGameValues.GlobalShadows -- (voxel lighting on first: the game's own is the one it kept)
end
genv.LegacyLightingGameValues = { GlobalShadows = gameShadows }
onStop(function() genv.LegacyLightingGameValues = nil end)

local function setLighting(prop, value)
	pcall(function() Lighting[prop] = value end)
	local ours = read(Lighting, prop)
	if ours ~= nil and snapshot[prop] ~= nil and prop ~= "Brightness" and prop ~= "Ambient" and prop ~= "OutdoorAmbient" then
		onStop(function()
			if read(Lighting, prop) == ours then Lighting[prop] = snapshot[prop] end
		end)
	end
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
	return read(Lighting, prop)
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

local function writeTechnology(value)
	pcall(function() Lighting.Technology = value end)
	if readTechnology() ~= value and sethiddenproperty then
		pcall(function() sethiddenproperty(Lighting, "Technology", value) end)
	end
end

local function isFutureTechnology()
	local ok, future = pcall(function() return Enum.Technology.Future end)
	return ok and readTechnology() == future
end

-- (Addtion-Scripts) Only Future / ShadowMap are switched: Compatibility (what Hammer stuff's other "legacy
-- lighting" uses) and Legacy are old-style already and are left as they are, so the two can be on together.
-- The game's own technology is kept in getgenv().BPGameTechnology by whichever of the two changed it first,
-- and given back by the last one to stop.
local function giveTechnologyBack()
	-- (Hammer stuff's other legacy lighting, or its voxel lighting, still on: the old-style lighting stays, and
	-- that one gives the game's back)
	if genv.BPLegacyLightingOn or genv.BPVoxelLightingOn then return end
	local original = genv.BPGameTechnology
	genv.BPGameTechnology = nil
	if original ~= nil and readTechnology() ~= original then writeTechnology(original) end
end

local function forceVoxelTechnology()
	local okVoxel, voxel = pcall(function() return Enum.Technology.Voxel end)
	if not okVoxel then return "not supported by this Roblox client" end
	-- whether or not it is changed here: the last of the two to stop gives the game's technology back
	onStop(giveTechnologyBack)
	local before = readTechnology()
	if before == nil then return "could not be read" end
	if before == voxel then return "already Voxel" end
	local modern = false
	for _, name in ipairs({ "Future", "ShadowMap" }) do
		local ok, item = pcall(function() return Enum.Technology[name] end)
		if ok and before == item then modern = true end
	end
	if not modern then return "is " .. tostring(before) .. " (old-style already, left as it is)" end
	if genv.BPGameTechnology == nil then genv.BPGameTechnology = before end
	writeTechnology(voxel)
	if readTechnology() == voxel then
		return "switched " .. tostring(before) .. " -> Voxel"
	end
	return "is " .. tostring(before) .. " and the executor refused to change it"
end

-- THE BOOST: the sun (Brightness) and the shade light (Ambient, OutdoorAmbient) are made stronger to make up
-- for the darkened colours. The game's own value is remembered and the boosted one written from it, so a
-- game that sets its lighting again (a day/night cycle) gets boosted once, never on top of the last boost.
-- It only comes up once the map has been darkened (see the end of this file).
local boostActive = false
local boostFactor = { Brightness = 1, Ambient = 1, OutdoorAmbient = 1 }
local boostRec = {}
local setAutoSun, startBoost, useBoost, paleShares -- set by setupLighting

local function applyBoost(prop)
	local b = boostRec[prop]
	if not b or stopped then return end
	local f = boostActive and boostFactor[prop] or 1
	local v = (prop == "Brightness") and b.orig * f or mul(b.orig, f)
	b.writing = true
	pcall(function() Lighting[prop] = v end)
	b.writing = false
	b.last = readLighting(prop)
end

local function setupLighting()
	local flat = Color3.new(0.5, 0.5, 0.5)
	setLighting("Brightness", 2)
	setLighting("Ambient", flat)
	setLighting("ColorShift_Top", Color3.new())
	setLighting("ColorShift_Bottom", Color3.new())
	hold(Lighting, "EnvironmentDiffuseScale", 0, true)  -- 2019+: kept at 0 even if the game writes it again
	hold(Lighting, "EnvironmentSpecularScale", 0, true)
	-- (Addtion-Scripts) VOXEL LIGHTING TOGETHER: with Hammer stuff's "voxel lighting" on, its 2013 voxel shadows
	-- stay on; it gives the game's own shadows, lighting style and technology back when it stops
	if not genv.BPVoxelLightingOn then
		setLighting("GlobalShadows", false)
	else
		-- (voxel lighting on: its shadows stay. If it is switched off before this stops, it leaves this lighting's
		-- "no shadows", which is put back to the game's own here)
		onStop(function()
			if not genv.BPVoxelLightingOn and gameShadows ~= nil and read(Lighting, "GlobalShadows") == false then
				Lighting.GlobalShadows = gameShadows
			end
		end)
	end
	setLighting("OutdoorAmbient", flat)
	-- ClockTime is deliberately not touched: the game's own time of day (and its day/night cycle) stays in charge
	setLighting("GeographicLatitude", 41.733)
	hold(Lighting, "ExposureCompensation", 0, true)
	setLighting("FogEnd", 100000)
	setLighting("FogStart", 0)
	setLighting("FogColor", Color3.fromRGB(192, 192, 192))

	-- the boost (written from the values above, or from what the game writes later)
	for prop in pairs(boostFactor) do
		local now = readLighting(prop)
		if now ~= nil then
			local b = { orig = now, last = now, gameWrote = false }
			boostRec[prop] = b
			track(Lighting:GetPropertyChangedSignal(prop):Connect(function()
				if stopped or b.writing then return end
				local cur = readLighting(prop)
				if cur == nil or cur == b.last then return end -- our own write coming back
				b.orig = cur
				b.gameWrote = true
				applyBoost(prop)
			end))
			onStop(function()
				if readLighting(prop) == b.last then
					local back = b.gameWrote and b.orig or snapshot[prop]
					if back ~= nil then Lighting[prop] = back end
				end
			end)
		end
	end

	local intensity = Settings.LegacyIntensity
	local baseSun = intensity * (Settings.SunBoost or 2.1)
	local baseAmbient = intensity * (Settings.AmbientBoost or 1.2)
	local autoFactor, autoAmbient = 1, 1
	-- the sun actually used is the chosen boost times the AutoBrightness factor, but never weaker than PaleMapSun
	-- of the game's (the colours are divided by `divisor`, so a sun of divisor x PaleMapSun is that share). The shade
	-- light the same way, down to PaleMapAmbient.
	local function refreshBoost()
		local sun = math.max(baseSun * autoFactor, math.min(baseSun, divisor * (Settings.PaleMapSun or 0.85)))
		local ambient = math.max(baseAmbient * autoAmbient, math.min(baseAmbient, divisor * (Settings.PaleMapAmbient or 1)))
		boostFactor.Brightness = sun
		boostFactor.Ambient = ambient
		boostFactor.OutdoorAmbient = ambient
		if boostActive then
			for prop in pairs(boostRec) do applyBoost(prop) end
		end
		return sun / intensity, ambient / intensity -- the SunBoost / AmbientBoost values in use
	end
	refreshBoost()
	useBoost = function(newSun, newAmbient)
		baseSun, baseAmbient = newSun, newAmbient
		refreshBoost()
	end
	setAutoSun = function(factor, ambientFactor)
		autoFactor = factor
		autoAmbient = ambientFactor or 1
		return refreshBoost()
	end
	paleShares = function()
		-- (the factors that bring the sun / shade light down to PaleMapSun / PaleMapAmbient of the game's)
		return divisor * (Settings.PaleMapSun or 0.85) / baseSun, divisor * (Settings.PaleMapAmbient or 1) / baseAmbient
	end
	startBoost = function()
		if boostActive or stopped then return end
		boostActive = true
		for prop in pairs(boostRec) do applyBoost(prop) end
	end

	-- lighting mode (see LIGHTING MODE above). On the side, because it has to wait a few frames.
	task.spawn(function()
		local report = {}
		if Settings.ForceVoxel then
			report[#report + 1] = "technology " .. forceVoxelTechnology()
		end

		local accepted = false
		if Settings.SoftLighting and StyleEnum then
			local styleBefore = readLighting("LightingStyle")
			local qualityBefore = readLighting("PrioritizeLightingQuality")
			-- (with voxel lighting already on these are its values: the game's own are the ones it kept)
			local vxGame = genv.BPVoxelGameValues
			if genv.BPVoxelLightingOn and type(vxGame) == "table" then
				if vxGame.LightingStyle ~= nil then styleBefore = vxGame.LightingStyle end
				if vxGame.PrioritizeLightingQuality ~= nil then qualityBefore = vxGame.PrioritizeLightingQuality end
			end
			if genv.LegacyLightingGameValues then
				genv.LegacyLightingGameValues.LightingStyle = styleBefore
				genv.LegacyLightingGameValues.PrioritizeLightingQuality = qualityBefore
			end
			writeLighting("LightingStyle", StyleEnum.Soft)
			-- A game can READ Soft / off and still RENDER Future: Jailbreak does, its old Technology setting stays in
			-- charge until one of the new properties really changes. Writing the value a property already has changes
			-- nothing, so switch the quality setting on and back off to make the engine pick the mode up again.
			local flipped = writeLighting("PrioritizeLightingQuality", true)
			task.wait(0.15)
			local quality = writeLighting("PrioritizeLightingQuality", false)
			if stopped then return end
			accepted = flipped and quality
			for _, prop in ipairs({ "LightingStyle", "PrioritizeLightingQuality" }) do
				track(Lighting:GetPropertyChangedSignal(prop):Connect(function() -- the game switched it back
					if not stopped and isWashedMode() then
						writeLighting("LightingStyle", StyleEnum.Soft)
						writeLighting("PrioritizeLightingQuality", false)
					end
				end))
			end
			onStop(function()
				if genv.BPVoxelLightingOn then return end -- (voxel lighting keeps Soft and gives the game's back)
				if styleBefore ~= nil and readLighting("LightingStyle") == StyleEnum.Soft then
					writeLighting("LightingStyle", styleBefore)
				end
				if qualityBefore ~= nil and readLighting("PrioritizeLightingQuality") == false then
					writeLighting("PrioritizeLightingQuality", qualityBefore)
				end
			end)
			report[#report + 1] = "soft lighting " .. (accepted and "applied" or "refused by the executor")
		end

		if isWashedMode() or (not accepted and isFutureTechnology()) then
			useBoost(intensity * (Settings.FutureSunBoost or 1.2), intensity * (Settings.FutureAmbientBoost or 1.7))
			report[#report + 1] = "game stays on Future lighting, so the weaker sun is used"
		end
		print("[LegacyLighting] lighting mode: " .. (#report > 0 and table.concat(report, "; ") or "left alone"))
	end)
end

local strippedOnce = setmetatable({}, { __mode = "k" })

local function stripEffect(e)
	if ownedSet[e] or stopped then return end
	-- (the grey colour correction of Hammer stuff's other "legacy lighting": both can be on together)
	if e:GetAttribute("BPLegacyLighting") then return end
	pcall(function()
		if e:IsA("PostEffect") then -- bloom, sunrays, depth of field, blur, colour correction/grading
			if e:IsA("BloomEffect") or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect") then
				hold(e, "Enabled", false, true) -- stays off even if the game switches it back on
			elseif not strippedOnce[e] and e.Enabled then
				-- switched off once (the game may use it for a moment, e.g. a red flash when hurt)
				strippedOnce[e] = true
				e.Enabled = false
				onStop(function()
					if not e.Enabled then e.Enabled = true end
				end)
			end
		elseif e:IsA("Atmosphere") then -- 2020: haze and sun glare. Kept at zero even if the game tweens it
			hold(e, "Density", 0, true)
			hold(e, "Haze", 0, true)
			hold(e, "Glare", 0, true)
		end
	end)
end

local function setupEffects()
	local cc = own(Instance.new("ColorCorrectionEffect"))
	cc.Name = "LegacyCorrection"
	cc:SetAttribute("BPIWLegacyLighting", true) -- (Hammer stuff's other legacy lighting leaves these alone)
	cc.Saturation = 0.2
	cc.Brightness = 0
	cc.TintColor = Color3.new(1, 1, 1)
	cc.Contrast = 0.08
	cc.Parent = Lighting

	pcall(function()
		local cg = own(Instance.new("ColorGradingEffect"))
		cg.Name = "LegacyGrading"
		cg:SetAttribute("BPIWLegacyLighting", true)
		cg.TonemapperPreset = Settings.Voxel2019 and Enum.TonemapperPreset.Default or Enum.TonemapperPreset.Retro
		cg.Parent = Lighting
	end)

	local bloom = own(Instance.new("BloomEffect"))
	bloom.Name = "LegacyBloom"
	bloom:SetAttribute("BPIWLegacyLighting", true)
	bloom.Threshold = Settings.BloomThreshold
	bloom.Intensity = Settings.NeonBloom
	bloom.Size = Settings.BloomSize
	bloom.Parent = Lighting

	if Settings.StripGameEffects then
		for _, e in ipairs(Lighting:GetChildren()) do stripEffect(e) end
		-- (a moment later: whoever added it may mark it first, see stripEffect)
		track(Lighting.ChildAdded:Connect(function(e) task.defer(stripEffect, e) end))
		local cam = workspace.CurrentCamera
		if cam then
			for _, e in ipairs(cam:GetChildren()) do stripEffect(e) end
			track(cam.ChildAdded:Connect(stripEffect))
		end
	end
end

----------------------------------------------------------------------------------------------------
-- terrain: its colours are not Part.Color, so the colour pass never darkened it and it took the whole
-- brightness boost (pale ground, glowing grass, white sand). Terrain has one colour per material; divide
-- those the same way. The grass blades use the Grass material colour, so they follow.
-- There is no change event for these colours, so they are checked every 2 seconds: if the game set a new
-- colour (or Roblox reset them), the new colour is darkened again. Stopping puts the game's colours back.
----------------------------------------------------------------------------------------------------
local function sameColor(a, b)
	return math.abs(a.R - b.R) < 0.012 and math.abs(a.G - b.G) < 0.012 and math.abs(a.B - b.B) < 0.012
end

local function startTerrain()
	if not Settings.DarkenTerrain then return end
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if not terrain then return end

	-- material name -> { orig = the game's colour, last = ours }, kept in getgenv like the colours above
	local state = genv.__LegacyLightingTerrainColors
	if type(state) ~= "table" or state.terrain ~= terrain then
		state = { terrain = terrain, mats = {} }
		genv.__LegacyLightingTerrainColors = state
	end
	-- what the previous version of this script darkened (it never put terrain back)
	local old = genv.__LegacyLightingTerrain
	if type(old) ~= "table" or old.terrain ~= terrain or type(old.set) ~= "table" then old = nil end

	local materials = {}
	for _, m in ipairs(Enum.Material:GetEnumItems()) do
		if pcall(function() return terrain:GetMaterialColor(m) end) then
			materials[#materials + 1] = m
		end
	end

	local function apply()
		local changed = 0
		for _, m in ipairs(materials) do
			local cur = terrain:GetMaterialColor(m)
			local rec = state.mats[m.Name]
			if not (rec and rec.last == cur) then
				local prev = old and old.set[m.Name]
				if not rec and prev and sameColor(cur, prev) then
					state.mats[m.Name] = { orig = lighten(cur), last = cur }
					old.set[m.Name] = nil
				else
					rec = rec or {}
					rec.orig = cur
					pcall(function() terrain:SetMaterialColor(m, darken(cur)) end)
					rec.last = terrain:GetMaterialColor(m)
					state.mats[m.Name] = rec
					changed += 1
				end
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
	onStop(function()
		for name, rec in pairs(state.mats) do
			pcall(function()
				local m = Enum.Material[name]
				if terrain:GetMaterialColor(m) == rec.last then terrain:SetMaterialColor(m, rec.orig) end
			end)
			state.mats[name] = nil
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- things that did not exist in 2016-2018 and are not instances in the workspace
----------------------------------------------------------------------------------------------------
local extraNotes = {}

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
		onStop(function()
			pcall(function() inst[prop] = not value end)
			if readHidden(inst, prop) == value and sethiddenproperty then sethiddenproperty(inst, prop, not value) end
		end)
	else
		extraNotes[#extraNotes + 1] = label .. " REFUSED by the executor"
	end
end

local function startLegacyExtras()
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if Settings.NoGrassBlades and terrain then
		switchHidden(terrain, "Decoration", false, "grass blades off")
	end
	if Settings.OldMaterials then
		local okMs, ms = pcall(function() return game:GetService("MaterialService") end)
		if okMs and ms then
			switchHidden(ms, "Use2022Materials", false, "pre-2022 material textures on")
			-- custom materials (2022) that a game puts in place of a built-in one, e.g. its own shiny cobblestone
			local cleared = 0
			for _, m in ipairs(Enum.Material:GetEnumItems()) do
				pcall(function()
					local name = ms:GetBaseMaterialOverride(m)
					if name ~= "" then
						ms:SetBaseMaterialOverride(m, "")
						cleared += 1
						onStop(function() ms:SetBaseMaterialOverride(m, name) end)
					end
				end)
			end
			extraNotes[#extraNotes + 1] = "custom material overrides removed: " .. cleared
		end
	end
end

----------------------------------------------------------------------------------------------------
-- start
----------------------------------------------------------------------------------------------------
local function stop()
	if stopped then return end
	stopped = true
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	restoreColors()
	for i = #restores, 1, -1 do pcall(restores[i]) end -- lighting, effects, terrain, unions, signs, extras
	for _, r in ipairs(pbrRemoved) do pcall(function() r[1].Parent = r[2] end) end
	for part, rec in pairs(meshFix) do -- show the original meshes again
		for _, c in ipairs(rec.conns or {}) do pcall(function() c:Disconnect() end) end
		pcall(function() part.Transparency = rec.transparency end)
	end
	for _, i in ipairs(created) do pcall(function() i:Destroy() end) end
	if genv.LegacyLightingStop == stop then genv.LegacyLightingStop = nil end
	print("[LegacyLighting] stopped: the game's lighting, effects and colours are back")
end
genv.LegacyLightingStop = stop

-- each part of the set-up on its own, so one that fails (an older Roblox client, a refused property) doesn't
-- keep the rest from running
local function setUp(name, fn)
	local ok, err = pcall(fn)
	if not ok then warn("[LegacyLighting] " .. name .. " failed: " .. tostring(err)) end
end
setUp("lighting", setupLighting)
setUp("effects", setupEffects)
setUp("terrain", startTerrain)
setUp("2019+ extras", startLegacyExtras)

-- an object whose handling failed is tried again (by the second look, or when it appears again)
local function safeHandle(v)
	if not pcall(handle, v) then handled[v] = nil end
end
track(workspace.DescendantAdded:Connect(safeHandle))
print("[LegacyLighting] loading the map: the light comes up once everything is done")

-- (Addtion-Scripts) AUTO BRIGHTNESS, stronger and live. Paleness 0.45 or darker: the full boost (the legacy look, as
-- before: maps that looked right stay as they were);
-- 0.8 or paler: the sun and shade light down to PaleMapSun / PaleMapAmbient of the game's; in between, in
-- proportion. Worked out for the whole map once it is loaded, then every few seconds for what is around the
-- camera (each part's real colour weighted by its size; textured meshes, see-through parts and neon left out), so
-- the light follows where you are, eased in steps so it doesn't jump.
local function autoFactors(mean)
	local t = math.clamp((mean - 0.45) / 0.35, 0, 1)
	local sunShare, ambientShare = 0.37, 0.75
	if paleShares then
		local ok, a, b = pcall(paleShares)
		if ok then sunShare, ambientShare = a, b end
	end
	return 1 - t * (1 - math.min(sunShare, 1)), 1 - t * (1 - math.min(ambientShare, 1))
end

local function palenessOf(parts)
	local weight, lum = 0, 0
	for _, part in ipairs(parts) do
		if part.Transparency <= 0.5 and not ownedSet[part] and part.Name ~= MESH_PROXY and not colorExempt(part)
			and not (part:IsA("MeshPart") and part.TextureID ~= "") and not part:IsA("Terrain") then
			local size = part.Size
			local w = math.min(size.X * size.Z + size.X * size.Y + size.Y * size.Z, 20000)
			if w >= 4 then
				local recs = colorState[part]
				local c = (recs and recs.Color and recs.Color.orig) or part.Color -- the game's own colour
				weight += w
				lum += math.min(0.3 * c.R + 0.59 * c.G + 0.11 * c.B, 1) * w
			end
		end
	end
	if weight <= 0 then return nil, 0 end
	return lum / weight, weight
end

local nearParams
pcall(function()
	nearParams = OverlapParams.new()
	nearParams.MaxParts = 4000
	nearParams.FilterType = Enum.RaycastFilterType.Exclude
	local chars = {}
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then chars[#chars + 1] = p.Character end end
	nearParams.FilterDescendantsInstances = chars
end)

local function nearPaleness()
	local cam = workspace.CurrentCamera
	if not (cam and nearParams) then return nil, 0 end
	local ok, parts = pcall(function()
		return workspace:GetPartBoundsInRadius(cam.Focus.Position, Settings.AutoBrightnessRadius or 160, nearParams)
	end)
	if not ok or type(parts) ~= "table" then return nil, 0 end
	return palenessOf(parts)
end

local NEAR_ENOUGH = 300 -- (studs of surface around the camera needed to go by it)
local paleness = nil     -- the paleness the light is set for now

local function lightUp()
	if stopped or not startBoost then return end
	if Settings.AutoBrightness and not tallyDone and setAutoSun then
		tallyDone = true
		local mapMean = tallyWeight > 0 and tallyLum / tallyWeight or nil -- 0 = black map, 1 = white map
		local near, nearWeight = nearPaleness()
		local mean = mapMean
		if near and nearWeight >= NEAR_ENOUGH then mean = mapMean and (near * 0.7 + mapMean * 0.3) or near end
		if mean then
			paleness = mean
			local okAuto, used, usedAmbient = pcall(setAutoSun, autoFactors(mean))
			print(string.format("[LegacyLighting] auto brightness: paleness %.2f (map %s, around you %s) -> SunBoost in use %s, AmbientBoost in use %s",
				mean, mapMean and string.format("%.2f", mapMean) or "-", near and string.format("%.2f", near) or "-",
				okAuto and string.format("%.4f", used) or "unchanged (failed)", okAuto and string.format("%.4f", usedAmbient) or "-"))
		end
	end
	startBoost()
	if Settings.AutoBrightness and setAutoSun then
		task.spawn(function()
			while not stopped do
				task.wait(Settings.AutoBrightnessEvery or 3)
				if stopped then return end
				local near, nearWeight = nearPaleness()
				if near and nearWeight >= NEAR_ENOUGH then
					local eased = paleness and (paleness + (near - paleness) * 0.35) or near
					if not paleness or math.abs(eased - paleness) > 0.01 then
						paleness = eased
						pcall(setAutoSun, autoFactors(eased))
					end
				end
			end
		end)
	end
end
if type(Settings.LightUpAfter) == "number" then
	task.delay(Settings.LightUpAfter, lightUp)
end

task.spawn(function()
	-- The first pass, in slices of a few milliseconds a frame so the game keeps running: the characters
	-- first (you see yourself right away), then the rest of the map one top-level object at a time.
	local slice = Settings.SliceTime or 0.008
	local deadline = os.clock() + slice
	local count = 0
	local function visit(v)
		safeHandle(v)
		count += 1
		if os.clock() > deadline then
			task.wait()
			deadline = os.clock() + slice
		end
	end
	local function visitTree(root)
		visit(root)
		for _, v in ipairs(root:GetDescendants()) do
			if stopped then return end
			visit(v)
		end
	end
	local first = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local character = p.Character
		if character and character:IsDescendantOf(workspace) then
			first[character] = true
			visitTree(character)
		end
	end
	for _, child in ipairs(workspace:GetChildren()) do
		if stopped then return end
		if not first[child] then visitTree(child) end
	end
	-- a second look through everything: whatever the first pass missed (or failed on) is done now
	local missed = 0
	for _, v in ipairs(workspace:GetDescendants()) do
		if stopped then return end
		if not handled[v] and not ownedSet[v] then
			missed += 1
			visit(v)
		elseif os.clock() > deadline then
			task.wait()
			deadline = os.clock() + slice
		end
	end
	if stopped then return end
	print(string.format("[LegacyLighting] map done in %.1f s (%d objects, %d caught by the second look) | textured meshes redrawn so they darken too: %d | unions switched to their darkened colour: %d",
		os.clock() - startedAt, count, missed, meshFixCount + worldMeshFixCount, unionFixCount))
	lightUp()
	if Settings.FixWorldMeshes then
		task.spawn(function() -- (NEAREST MESHES)
			while not stopped do
				pcall(nearestMeshes)
				task.wait(2.5)
			end
		end)
	end
	local extras = { "clouds hidden: " .. cloudsOff, "highlights hidden: " .. highlightsOff, "PBR textures removed: " .. #pbrRemoved }
	for _, note in ipairs(extraNotes) do extras[#extras + 1] = note end
	print("[LegacyLighting] 2019+ extras: " .. table.concat(extras, " | "))
end)

if Settings.LitSurfaceGuis then
	task.spawn(function() -- SurfaceGuis parented to PlayerGui (with an Adornee) draw in the world too
		local pg = player:WaitForChild("PlayerGui", 10)
		if not pg or stopped then return end
		track(pg.DescendantAdded:Connect(function(v) pcall(lightSurfaceGui, v) end))
		local slice = Settings.SliceTime or 0.008
		local deadline = os.clock() + slice
		for _, v in ipairs(pg:GetDescendants()) do
			if stopped then return end
			pcall(lightSurfaceGui, v)
			if os.clock() > deadline then
				task.wait()
				deadline = os.clock() + slice
			end
		end
	end)
end

print("[LegacyLighting] running. The time of day follows the game. Run the script again to replace it.")
