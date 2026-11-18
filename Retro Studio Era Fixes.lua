--========================================================
-- RETRO STUDIO ERA FIXES (standalone, from Retro Studio's own scripts)
-- Two small client scripts from Retro Studio's engine (StarterPlayerScripts._RetroStudio.Engine), made to run in
-- any game from an executor instead of reading the game's PlaceSettings:
--   * Rendering.Decal: every face decal ("/face" in its Texture) is switched to the classic face, and the
--     SpawnLocation decal to Retro Studio's old spawn picture. A decal that is changed back is changed again.
--   * TerrainEraLockHack: any MeshPart that appears under Terrain gets Retro Studio's terrain texture.
-- Only you see the changes. Run it again to replace the earlier run; getgenv().RetroStudioEraFixesStop() undoes it.
--
-- Settings (set before running, or edit the defaults below):
--   getgenv().RetroStudioNewFace = true   the newer face (rbxassetid://100092223376461) instead of the classic one
--
-- Retro Studio's other engine scripts (Forcefield, Explosion, ParticleModule, the message and purchase GUIs) need that
-- game's own prefabs, modules and remotes, so they cannot run anywhere else.
--========================================================

local genv = (getgenv and getgenv()) or _G
if type(genv.RetroStudioEraFixesStop) == "function" then pcall(genv.RetroStudioEraFixesStop) end

local OLD_FACE = "rbxassetid://4542464998"
local NEW_FACE = "rbxassetid://100092223376461"
local SPAWN_PICTURE = "rbxassetid://2079801754"
local TERRAIN_TEXTURE = "rbxassetid://122075600833378"

local face = (genv.RetroStudioNewFace == true) and NEW_FACE or OLD_FACE
local conns = {}
local changed = {} -- decal -> its own Texture, to put back when stopped
local meshes = {}  -- terrain mesh -> its own TextureID

local function track(c) conns[#conns + 1] = c return c end

local function fixDecal(d)
	local tex = d.Texture
	local target = nil
	if string.find(tex, "/face", 1, true) then
		target = face
	elseif string.find(tex, "/SpawnLocation", 1, true) then
		target = SPAWN_PICTURE
	end
	if target and tex ~= target then
		if changed[d] == nil then changed[d] = tex end
		d.Texture = target
	end
end

local function watchDecal(d)
	if not d:IsA("Decal") then return end -- Texture is a Decal too, which is fine
	pcall(fixDecal, d)
	track(d:GetPropertyChangedSignal("Texture"):Connect(function()
		pcall(fixDecal, d)
	end))
end

local function fixMesh(m)
	if m:IsA("MeshPart") then
		if meshes[m] == nil then meshes[m] = m.TextureID end
		m.TextureID = TERRAIN_TEXTURE
	end
end

for _, d in ipairs(workspace:GetDescendants()) do watchDecal(d) end
track(workspace.DescendantAdded:Connect(watchDecal))

local terrain = workspace:FindFirstChildOfClass("Terrain")
if terrain then
	for _, m in ipairs(terrain:GetDescendants()) do pcall(fixMesh, m) end
	track(terrain.DescendantAdded:Connect(function(m) pcall(fixMesh, m) end))
end

local function stop()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	conns = {}
	for d, tex in pairs(changed) do pcall(function() d.Texture = tex end) end
	for m, tex in pairs(meshes) do pcall(function() m.TextureID = tex end) end
	changed, meshes = {}, {}
	if genv.RetroStudioEraFixesStop == stop then genv.RetroStudioEraFixesStop = nil end
	print("[Retro Studio Era Fixes] off.")
end
genv.RetroStudioEraFixesStop = stop
print("[Retro Studio Era Fixes] on (" .. ((face == NEW_FACE) and "new" or "classic") .. " face). getgenv().RetroStudioEraFixesStop() undoes it.")
