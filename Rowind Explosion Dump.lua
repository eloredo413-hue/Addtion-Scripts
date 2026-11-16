-- [[ ROWIND EXPLOSION DUMP - copy and paste, run once while in a Rowind game ]]
-- Rowind draws its old explosions from ready-made models in its client scripts
-- (PlayerScripts.RowindClientVisuals.Handler.Assets.Explosions, one per era). This copies that whole folder, every
-- object and every property it has (particle textures, colours, sizes, timings...), as text that rebuilds it, so the
-- Explosion addon can use Rowind's real 2010 / 2013 explosions. It also notes how Rowind picks one for an era, and
-- the game's era. Nothing in the game is changed.
-- When it's done: the text is on your clipboard (if your executor can) and saved as RowindExplosions.txt in the
-- executor's workspace folder. Paste it back in the chat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

----------------------------------------------------------------------------------------------------
-- find the folder
----------------------------------------------------------------------------------------------------
local function findExplosions()
	local roots = {}
	local scripts = player and player:FindFirstChildOfClass("PlayerScripts")
	if scripts then table.insert(roots, scripts) end
	for _, name in ipairs({ "ReplicatedStorage", "ReplicatedFirst", "StarterPlayer", "Workspace", "Lighting" }) do
		local ok, s = pcall(function() return game:GetService(name) end)
		if ok and s then table.insert(roots, s) end
	end
	for _, root in ipairs(roots) do
		local ok, list = pcall(function() return root:GetDescendants() end)
		if ok then
			for _, d in ipairs(list) do
				if d.Name == "Explosions" and d.Parent and d.Parent.Name == "Assets" then return d end
			end
		end
	end
	-- (things the game keeps out of the tree)
	if getnilinstances then
		for _, d in ipairs(getnilinstances()) do
			local ok, found = pcall(function()
				if d.Name == "Explosions" then return d end
				for _, x in ipairs(d:GetDescendants()) do
					if x.Name == "Explosions" and x.Parent and x.Parent.Name == "Assets" then return x end
				end
			end)
			if ok and found then return found end
		end
	end
	return nil
end

----------------------------------------------------------------------------------------------------
-- writing values as Lua
----------------------------------------------------------------------------------------------------
local function num(n)
	if n ~= n then return "0/0" end
	if n == math.huge then return "math.huge" end
	if n == -math.huge then return "-math.huge" end
	return string.format("%.6g", n)
end

local function value(v)
	local t = typeof(v)
	if t == "number" then return num(v)
	elseif t == "boolean" then return tostring(v)
	elseif t == "string" then return string.format("%q", v)
	elseif t == "Vector3" then return ("Vector3.new(%s, %s, %s)"):format(num(v.X), num(v.Y), num(v.Z))
	elseif t == "Vector2" then return ("Vector2.new(%s, %s)"):format(num(v.X), num(v.Y))
	elseif t == "Color3" then return ("Color3.new(%s, %s, %s)"):format(num(v.R), num(v.G), num(v.B))
	elseif t == "UDim" then return ("UDim.new(%s, %s)"):format(num(v.Scale), num(v.Offset))
	elseif t == "UDim2" then
		return ("UDim2.new(%s, %s, %s, %s)"):format(num(v.X.Scale), num(v.X.Offset), num(v.Y.Scale), num(v.Y.Offset))
	elseif t == "CFrame" then
		local c = { v:GetComponents() }
		for i, x in ipairs(c) do c[i] = num(x) end
		return "CFrame.new(" .. table.concat(c, ", ") .. ")"
	elseif t == "NumberRange" then return ("NumberRange.new(%s, %s)"):format(num(v.Min), num(v.Max))
	elseif t == "NumberSequence" then
		local k = {}
		for _, p in ipairs(v.Keypoints) do
			k[#k + 1] = ("NumberSequenceKeypoint.new(%s, %s, %s)"):format(num(p.Time), num(p.Value), num(p.Envelope))
		end
		return "NumberSequence.new({" .. table.concat(k, ", ") .. "})"
	elseif t == "ColorSequence" then
		local k = {}
		for _, p in ipairs(v.Keypoints) do
			k[#k + 1] = ("ColorSequenceKeypoint.new(%s, Color3.new(%s, %s, %s))"):format(num(p.Time), num(p.Value.R), num(p.Value.G), num(p.Value.B))
		end
		return "ColorSequence.new({" .. table.concat(k, ", ") .. "})"
	elseif t == "EnumItem" then return tostring(v)
	elseif t == "BrickColor" then return ("BrickColor.new(%q)"):format(v.Name)
	elseif t == "Rect" then return ("Rect.new(%s, %s, %s, %s)"):format(num(v.Min.X), num(v.Min.Y), num(v.Max.X), num(v.Max.Y))
	elseif t == "Content" then
		local ok, uri = pcall(function() return v.Uri end)
		return ok and uri and string.format("%q", uri) or nil
	end
	return nil -- (instances and anything else: left out)
end

-- every property worth having on the things an explosion model is made of (each one is only kept where the
-- object really has it)
local PROPS = {
	"Archivable",
	-- parts and meshes
	"Size", "CFrame", "PivotOffset", "Color", "Material", "Transparency", "Reflectance", "Anchored", "CanCollide",
	"CanTouch", "CanQuery", "CastShadow", "Massless", "Shape", "TopSurface", "BottomSurface", "LeftSurface",
	"RightSurface", "FrontSurface", "BackSurface", "MeshId", "TextureID", "TextureId", "MeshType", "Scale", "Offset",
	"VertexColor", "DoubleSided", "RenderFidelity",
	-- attachments
	"Position", "Orientation", "Axis", "SecondaryAxis", "Visible",
	-- particles (and fire / smoke / sparkles)
	"Enabled", "Texture", "Lifetime", "Rate", "Speed", "SpreadAngle", "Rotation", "RotSpeed", "Acceleration", "Drag",
	"LightEmission", "LightInfluence", "ZOffset", "EmissionDirection", "LockedToPart", "VelocityInheritance",
	"Squash", "TimeScale", "Brightness", "FlipbookLayout", "FlipbookMode", "FlipbookFramerate",
	"FlipbookStartRandom", "FlipbookIncompatible", "ShapeInOut", "ShapeStyle", "ShapePartial", "WindAffectsDrag",
	"Heat", "SecondaryColor", "Opacity", "RiseVelocity", "SparkleColor",
	-- lights
	"Range", "Shadows", "Angle", "Face",
	-- sounds
	"SoundId", "Volume", "PlaybackSpeed", "Looped", "PlayOnRemove", "RollOffMaxDistance", "RollOffMinDistance",
	"RollOffMode", "TimePosition",
	-- decals / textures
	"Color3", "StudsPerTileU", "StudsPerTileV", "OffsetStudsU", "OffsetStudsV", "ZIndex",
	-- billboards and pictures
	"StudsOffset", "StudsOffsetWorldSpace", "ExtentsOffset", "ExtentsOffsetWorldSpace", "AlwaysOnTop",
	"MaxDistance", "SizeOffset", "Image", "ImageColor3", "ImageTransparency", "ImageRectOffset", "ImageRectSize",
	"ScaleType", "SliceCenter", "BackgroundColor3", "BackgroundTransparency", "BorderSizePixel", "AnchorPoint",
	"ResampleMode",
	-- beams / trails
	"Width0", "Width1", "CurveSize0", "CurveSize1", "Segments", "TextureLength", "TextureMode", "TextureSpeed",
	"FaceCamera", "MinLength", "MaxLength", "WidthScale",
	-- tweens / values a model may carry
	"Value",
}
local seenProp = {}
local PROP_LIST = {}
for _, p in ipairs(PROPS) do
	if not seenProp[p] then
		seenProp[p] = true
		table.insert(PROP_LIST, p)
	end
end

local count = 0
local lines = {}
local function out(s) lines[#lines + 1] = s end

local function dump(inst, indent)
	count += 1
	local pad = string.rep("\t", indent)
	out(pad .. "{ class = " .. string.format("%q", inst.ClassName) .. ", name = " .. string.format("%q", inst.Name) .. ",")
	local props = {}
	for _, p in ipairs(PROP_LIST) do
		local ok, v = pcall(function() return inst[p] end)
		if ok and v ~= nil then
			local s = value(v)
			if s then props[#props + 1] = p .. " = " .. s end
		end
	end
	if #props > 0 then out(pad .. "\tprops = { " .. table.concat(props, ", ") .. " },") end
	local okA, attrs = pcall(function() return inst:GetAttributes() end)
	if okA and attrs and next(attrs) then
		local a = {}
		for k, v in pairs(attrs) do
			local s = value(v)
			if s then a[#a + 1] = "[" .. string.format("%q", k) .. "] = " .. s end
		end
		if #a > 0 then out(pad .. "\tattributes = { " .. table.concat(a, ", ") .. " },") end
	end
	local kids = inst:GetChildren()
	if #kids > 0 then
		out(pad .. "\tchildren = {")
		for _, c in ipairs(kids) do dump(c, indent + 2) end
		out(pad .. "\t},")
	end
	out(pad .. "},")
end

----------------------------------------------------------------------------------------------------
-- go
----------------------------------------------------------------------------------------------------
local folder = findExplosions()
if not folder then
	warn("[Rowind Explosion Dump] Rowind's Assets.Explosions folder wasn't found. Run this while in a Rowind game.")
	return
end

out("-- Rowind explosions, dumped from " .. folder:GetFullName())
local okV, version = pcall(function() return ReplicatedStorage:GetAttribute("RobloxVersion") end)
out("-- this game's RobloxVersion: " .. tostring(okV and version))
out("-- eras in the folder: " .. (function()
	local names = {}
	for _, c in ipairs(folder:GetChildren()) do names[#names + 1] = c.Name .. " (" .. c.ClassName .. ")" end
	return table.concat(names, ", ")
end)())

-- how Rowind picks the model for an era (its Handler's GetFromTimePeriod), when the executor can show it
local handler = folder.Parent and folder.Parent.Parent
if handler and handler:IsA("ModuleScript") and type(decompile) == "function" then
	local okD, src = pcall(decompile, handler)
	if okD and type(src) == "string" then
		local a = src:find("GetFromTimePeriod", 1, true)
		if a then
			local from = math.max(1, (src:sub(1, a):match(".*()\n[^\n]*$") or a))
			out("--[==[ Handler:GetFromTimePeriod (decompiled)")
			out(src:sub(from, math.min(#src, a + 1500)))
			out("]==]")
		end
	end
end

out("return {")
dump(folder, 1)
out("}")

local text = table.concat(lines, "\n")
local saved, copied = false, false
if writefile then saved = pcall(writefile, "RowindExplosions.txt", text) end
if setclipboard then copied = pcall(setclipboard, text) end
print(("[Rowind Explosion Dump] %d objects dumped (%d characters).%s%s"):format(count, #text,
	saved and " Saved as RowindExplosions.txt." or "", copied and " Copied to the clipboard." or ""))
if not saved and not copied then
	-- neither: printed in pieces, so it can be copied from the console
	for i = 1, #text, 3000 do print(text:sub(i, i + 2999)) end
end
