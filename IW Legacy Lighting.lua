-- (Addtion-Scripts) Hammer stuff 2's "iw legacy lighting" loads this file; unticking calls
-- getgenv().LegacyLightingStop(), which puts the game's lighting back.
--[[
	LEGACY 2017 LIGHTING  -  client side only
	Only YOU see any of this: it never touches the server, so nobody else in the game sees it.

	* Run it again whenever you like. The new run replaces the old one (it won't darken things twice).
	* The time of day is left to the game: morning, day, evening and night follow the game's own clock,
	  so a day/night cycle keeps working. There is no time box any more.
	* Everything you may want to change is in Settings below.
]]

local Settings = {
	LegacyIntensity  = 3,     -- the original value
	LegacyStuds      = false, -- studs on plain parts that use the Studs surface
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
	FixTexturedMeshes = true, -- redraw textured mesh hats/hair/limbs on characters so they darken too (they went white in R15 games)
	FixWorldMeshes   = false, -- the same for textured meshes in the map. Try it when the MAP is too bright. Heavier on big maps
	MaxMeshFixes     = 800,   -- upper limit for the two settings above
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
local listening = setmetatable({}, {__mode = "k"})

----------------------------------------------------------------------------------------------------
-- colour helpers
----------------------------------------------------------------------------------------------------
local divisor = Settings.LegacyIntensity * 0.9

local function clamp01(c)
	return Color3.new(math.clamp(c.R, 0, 1), math.clamp(c.G, 0, 1), math.clamp(c.B, 0, 1))
end

local function div(v, d)
	if typeof(v) == "Color3" then
		return clamp01(Color3.new(v.R / d, v.G / d, v.B / d))
	elseif typeof(v) == "Vector3" then
		return v / d
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

local function SetProp(inst, Prop)
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

	local h, run = guarded(inst, Prop, function()
		if not exempt then
			inst[Prop] = div(inst[Prop], divisor)
		end
	end)

	if isPartColor then
		local function recheck()
			local now = colorExempt(inst)
			if now ~= exempt then
				exempt = now
				h.silently(function()
					if now then
						inst.Color = clamp01(mul(inst.Color, divisor))
					else
						inst.Color = div(inst.Color, divisor)
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

	if not already then run() end
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

local function addStuds(part)
	if not Settings.LegacyStuds then return end
	if not (part:IsA("Part") or part:IsA("WedgePart")) then return end
	if not studsAllowed(part) then return end
	local made = false
	for _, face in ipairs(FACES) do
		if part[face .. "Surface"] == Enum.SurfaceType.Studs then
			local name = "LegacyStuds" .. face
			if not part:FindFirstChild(name) then
				local t = Instance.new("Texture")
				t.Name = name
				t.Texture = "rbxassetid://13225057574"
				t.StudsPerTileU = 2
				t.StudsPerTileV = 2
				t.Face = Enum.NormalId[face]
				t.Transparency = 0
				t.Color3 = mul(part.Color, 2.5)
				t.Parent = part
				made = true
			end
		end
	end
	if made then
		track(part:GetPropertyChangedSignal("Color"):Connect(function()
			for _, t in ipairs(part:GetChildren()) do
				if t:IsA("Texture") and t.Name:sub(1, 11) == "LegacyStuds" then
					t.Color3 = mul(part.Color, 2.5)
				end
			end
		end))
		track(part.ChildAdded:Connect(function(child)
			if child:IsA("DataModelMesh") then
				for _, t in ipairs(part:GetChildren()) do
					if t:IsA("Texture") and t.Name:sub(1, 11) == "LegacyStuds" then t.Transparency = 1 end
				end
			end
		end))
	end
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
-- one entry point for everything that appears in the workspace
----------------------------------------------------------------------------------------------------
local unionFixCount = 0

-- AutoBrightness: the boosted sun is balanced by darkening colours, but that balance only holds for dark and
-- mid colours. A white or very pale surface in the sun still ends up above pure white, so a map that is
-- mostly white washes out. This adds up how pale the map's floors are (each part's real colour, weighted by
-- its footprint) so the sun can be turned down for pale maps once the first scan is done.
local tallyWeight, tallyLum, tallyDone = 0, 0, false
local setAutoSun -- set by setupLighting

local function tallyBrightness(part)
	if tallyDone or part.Transparency > 0.5 or colorExempt(part) then return end
	if part:IsA("MeshPart") and part.TextureID ~= "" then return end -- its texture decides the colour, not Color
	local size = part.Size
	local weight = math.min(size.X * size.Z, 10000)
	if weight < 4 then return end
	local c = part.Color -- already darkened, so multiply back to the real colour
	local lum = math.min((0.3 * c.R + 0.59 * c.G + 0.11 * c.B) * divisor, 1)
	tallyWeight += weight
	tallyLum += lum * weight
end
local cloudsOff, highlightsOff = 0, 0
local pbrRemoved = {}

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
		if v:IsA("MeshPart") and (Settings.FixTexturedMeshes or Settings.FixWorldMeshes) then
			pcall(fixTexturedMesh, v)
		end
		-- A union draws the colours of the parts it was built from and ignores its Color property while
		-- UsePartColor is off (the default), so darkening Color did nothing. Switch it on: Color is already darkened.
		if Settings.FixUnionColors and v:IsA("PartOperation") and v.Material ~= NEON then
			pcall(function()
				if not v.UsePartColor then
					v.UsePartColor = true
					unionFixCount += 1
				end
			end)
		end
	elseif v:IsA("SpecialMesh") then
		SetProp(v, "VertexColor")
	elseif v:IsA("Decal") then -- Texture is a Decal too
		SetProp(v, "Color3")
	elseif v:IsA("Shirt") or v:IsA("Pants") then
		SetProp(v, "Color3")
	elseif v:IsA("SurfaceAppearance") then
		if Settings.NoPBR then
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
	elseif v:IsA("CharacterMesh") then
		convertCharacterMesh(v)
	end
	if Settings.LitSurfaceGuis then lightSurfaceGui(v) end
end

----------------------------------------------------------------------------------------------------
-- lighting + post effects
----------------------------------------------------------------------------------------------------
local function setLighting(prop, value)
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

local function forceVoxelTechnology()
	local okVoxel, voxel = pcall(function() return Enum.Technology.Voxel end)
	if not okVoxel then return "not supported by this Roblox client" end
	local before = readTechnology()
	if before == nil then return "could not be read" end
	if before == voxel then return "already Voxel" end
	pcall(function() Lighting.Technology = voxel end)
	if readTechnology() ~= voxel and sethiddenproperty then
		pcall(function() sethiddenproperty(Lighting, "Technology", voxel) end)
	end
	if readTechnology() == voxel then return "switched " .. tostring(before) .. " -> Voxel" end
	return "is " .. tostring(before) .. " and the executor refused to change it"
end

local function setupLighting()
	local flat = Color3.new(0.5, 0.5, 0.5)
	setLighting("Brightness", 2)
	setLighting("Ambient", flat)
	setLighting("ColorShift_Top", Color3.new())
	setLighting("ColorShift_Bottom", Color3.new())
	hold(Lighting, "EnvironmentDiffuseScale", 0)  -- 2019+: kept at 0 even if the game writes it again
	hold(Lighting, "EnvironmentSpecularScale", 0)
	setLighting("GlobalShadows", false)
	setLighting("OutdoorAmbient", flat)
	-- ClockTime is deliberately not touched: the game's own time of day (and its day/night cycle) stays in charge
	setLighting("GeographicLatitude", 41.733)
	hold(Lighting, "ExposureCompensation", 0)
	setLighting("FogEnd", 100000)
	setLighting("FogStart", 0)
	setLighting("FogColor", Color3.fromRGB(192, 192, 192))

	-- brighter light, darker colours
	local intensity = Settings.LegacyIntensity
	local sunBoost = intensity * (Settings.SunBoost or 2.1)
	local ambientBoost = intensity * (Settings.AmbientBoost or 1.2)
	local hSun, runBrightness = guarded(Lighting, "Brightness", function()
		Lighting.Brightness = Lighting.Brightness * sunBoost
	end)
	runBrightness()
	local hAmbient = {}
	for _, prop in ipairs({"Ambient", "OutdoorAmbient"}) do
		local h, runAmbient = guarded(Lighting, prop, function()
			Lighting[prop] = mul(Lighting[prop], ambientBoost)
		end)
		hAmbient[prop] = h
		runAmbient()
	end

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

	-- lighting mode (see LIGHTING MODE above). On the side, because it has to wait a few frames.
	task.spawn(function()
		local report = {}
		if Settings.ForceVoxel then
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

		if isWashedMode() or (not accepted and isFutureTechnology()) then
			useBoost(intensity * (Settings.FutureSunBoost or 1.2), intensity * (Settings.FutureAmbientBoost or 1.7))
			report[#report + 1] = "game stays on Future lighting, so the weaker sun is used"
		end
		print("[LegacyLighting] lighting mode: " .. (#report > 0 and table.concat(report, "; ") or "left alone"))
	end)
end

local function stripEffect(e)
	if ownedSet[e] then return end
	pcall(function()
		if e:IsA("PostEffect") then -- bloom, sunrays, depth of field, blur, colour correction/grading
			e.Enabled = false
			if e:IsA("BloomEffect") or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect") then
				hold(e, "Enabled", false) -- stays off even if the game switches it back on
			end
		elseif e:IsA("Atmosphere") then -- 2020: haze and sun glare. Kept at zero even if the game tweens it
			hold(e, "Density", 0)
			hold(e, "Haze", 0)
			hold(e, "Glare", 0)
		end
	end)
end

local function setupEffects()
	local cc = own(Instance.new("ColorCorrectionEffect"))
	cc.Name = "LegacyCorrection"
	cc.Saturation = 0.2
	cc.Brightness = 0
	cc.TintColor = Color3.new(1, 1, 1)
	cc.Contrast = 0.08
	cc.Parent = Lighting

	pcall(function()
		local cg = own(Instance.new("ColorGradingEffect"))
		cg.Name = "LegacyGrading"
		cg.TonemapperPreset = Settings.Voxel2019 and Enum.TonemapperPreset.Default or Enum.TonemapperPreset.Retro
		cg.Parent = Lighting
	end)

	local bloom = own(Instance.new("BloomEffect"))
	bloom.Name = "LegacyBloom"
	bloom.Threshold = Settings.BloomThreshold
	bloom.Intensity = Settings.NeonBloom
	bloom.Size = Settings.BloomSize
	bloom.Parent = Lighting

	if Settings.StripGameEffects then
		for _, e in ipairs(Lighting:GetChildren()) do stripEffect(e) end
		track(Lighting.ChildAdded:Connect(stripEffect))
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
-- colour (or Roblox reset them), the new colour is darkened again.
----------------------------------------------------------------------------------------------------
local function sameColor(a, b)
	return math.abs(a.R - b.R) < 0.012 and math.abs(a.G - b.G) < 0.012 and math.abs(a.B - b.B) < 0.012
end

local function startTerrain()
	if not Settings.DarkenTerrain then return end
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if not terrain then return end

	-- remembers the colours this script wrote, across runs, so running it again never darkens terrain twice
	local state = genv.__LegacyLightingTerrain
	if type(state) ~= "table" or state.terrain ~= terrain then
		state = {terrain = terrain, set = {}}
		genv.__LegacyLightingTerrain = state
	end

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
			local ours = state.set[m.Name]
			if not (ours and sameColor(cur, ours)) then
				pcall(function() terrain:SetMaterialColor(m, div(cur, divisor)) end)
				state.set[m.Name] = terrain:GetMaterialColor(m)
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
						restores[#restores + 1] = function() ms:SetBaseMaterialOverride(m, name) end
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
	if genv.LegacyLightingStop == stop then genv.LegacyLightingStop = nil end
end
genv.LegacyLightingStop = stop

setupLighting()
setupEffects()
startTerrain()
pcall(startLegacyExtras)

track(workspace.DescendantAdded:Connect(function(v) pcall(handle, v) end))
task.spawn(function() -- big maps: work through the existing parts in chunks so the game does not freeze
	local n = 0
	for _, v in ipairs(workspace:GetDescendants()) do
		if stopped then return end
		pcall(handle, v)
		n += 1
		if n % 300 == 0 then task.wait() end
	end
	print("[LegacyLighting] textured meshes redrawn so they darken too: " .. meshFixCount .. " | unions switched to their darkened colour: " .. unionFixCount)
	if Settings.AutoBrightness and tallyWeight > 0 and setAutoSun and not stopped then
		tallyDone = true
		local mean = tallyLum / tallyWeight -- 0 = black map, 1 = white map
		local factor = 1 - math.clamp((mean - 0.45) / 0.35, 0, 1) * 0.45
		local okAuto, used = pcall(setAutoSun, factor)
		print(string.format("[LegacyLighting] auto brightness: map paleness %.2f -> SunBoost in use %s", mean, okAuto and string.format("%.2f", used) or "unchanged (failed)"))
	end
	local extras = {"clouds hidden: " .. cloudsOff, "highlights hidden: " .. highlightsOff, "PBR textures removed: " .. #pbrRemoved}
	for _, note in ipairs(extraNotes) do extras[#extras + 1] = note end
	print("[LegacyLighting] 2019+ extras: " .. table.concat(extras, " | "))
end)

if Settings.LitSurfaceGuis then
	task.spawn(function() -- SurfaceGuis parented to PlayerGui (with an Adornee) draw in the world too
		local pg = player:WaitForChild("PlayerGui", 10)
		if not pg or stopped then return end
		track(pg.DescendantAdded:Connect(function(v) pcall(lightSurfaceGui, v) end))
		local n = 0
		for _, v in ipairs(pg:GetDescendants()) do
			if stopped then return end
			pcall(lightSurfaceGui, v)
			n += 1
			if n % 300 == 0 then task.wait() end
		end
	end)
end

print("[LegacyLighting] running. The time of day follows the game. Run the script again to replace it.")
