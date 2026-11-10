--!optimize 2

-- [[ 2013 DYNAMIC LIGHTS (Addtion-Scripts copy; "2013 dyn" in Hammer stuff 2) ]]
-- Turns SurfaceLights into 2013-style SpotLights / PointLights. Press 8 to switch between the 2013 lights and the
-- SurfaceLights (or untick the option in Hammer stuff 2, which gives every SurfaceLight back).

local CONFIG = {
	-- Controls ----------------------------------------------------------------------------------
	ToggleKey = Enum.KeyCode.Eight,       -- press 8 to switch between 2013 lights and SurfaceLights
	StartEnabled = true,

	-- Conversion Behavior -----------------------------------------------------------------------
	Mode = "Auto",                        -- "Auto":      SpotLight when Angle < PointLightAngleThreshold,
	                                      --              PointLight when Angle >= PointLightAngleThreshold
	                                      -- "SpotLight": convert every SurfaceLight into a SpotLight
	                                      -- "PointLight": convert every SurfaceLight into a PointLight
	PointLightAngleThreshold = 150,       -- degrees; SurfaceLights at or above this Angle become PointLights
	BrightnessScale = 1.15,               -- slight boost so converted cones match SurfaceLight fill
	RangeScale = 1.0,                     -- multiplier applied to the SurfaceLight's Range
	SpotAngleScale = 1.15,                -- multiplier applied to SurfaceLight.Angle for SpotLights
	MinSpotAngle = 20,                    -- minimum SpotLight cone angle (degrees)
	MaxSpotAngle = 140,                   -- maximum SpotLight cone angle (degrees)

	-- Shadows -----------------------------------------------------------------------------------
	PreserveShadows = true,               -- copy SurfaceLight.Shadows onto the SpotLight / PointLight
	ForceShadows = false,                 -- true = force Shadows = true on all converted lights
	StencilShadowTag = true,              -- marks converted lights so StencilShadows_2013 casts
	                                      -- radial stencil shadows from them even if GlobalShadows is off

	-- Long Strip Lights (Optional) --------------------------------------------------------------
	SplitLongStripLights = false,         -- true = long fluorescent bars (e.g. 12+ stud ceiling strips)
	                                      --        get extra Attachment lights along their length;
	                                      -- false = classic 2013 single light source per part
	StripLengthRatio = 3.0,               -- length-to-width ratio on the emitting face to count as a strip
	MaxEmittersPerStrip = 3,              -- maximum lights created along a long strip when enabled

	-- Scope -------------------------------------------------------------------------------------
	ConvertToolsAndReplicated = true,     -- also watch ReplicatedStorage & StarterPack for tool lights
	IgnoreAttribute = "NoLightConvert",   -- set this attribute to true on a light or part to skip it
}

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")

local CONVERTED_NAME = "__2013ConvertedLight"
local CONVERTED_ATTACHMENT_NAME = "__2013ConvertedLightAttachment"
local CONVERTED_ATTR = "ConvertedFromSurfaceLight"
local STENCIL_SHADOW_ATTR = "StencilCastShadows"

do
	local envs = {_G}
	if typeof(getgenv) == "function" then
		local ok, env = pcall(getgenv)
		if ok and type(env) == "table" and env ~= _G then
			envs[2] = env
		end
	end
	for _, env in ipairs(envs) do
		local prev = env.__SurfaceLightConverterCleanup
		if type(prev) == "function" then
			pcall(prev)
			env.__SurfaceLightConverterCleanup = nil
		end
	end
end

local alive = true
local enabled = CONFIG.StartEnabled ~= false
local records = {}
local globalConns = {}
local stats = {
	converted = 0,
	spotLights = 0,
	pointLights = 0,
}

local function shouldIgnore(inst)
	if not inst then
		return true
	end
	local attr = CONFIG.IgnoreAttribute
	if attr and attr ~= "" then
		local cur = inst
		while cur and cur ~= game do
			if cur:GetAttribute(attr) == true then
				return true
			end
			cur = cur.Parent
		end
	end
	return false
end

local function chooseLightClass(sl)
	local mode = CONFIG.Mode
	if mode == "PointLight" then
		return "PointLight"
	elseif mode == "SpotLight" then
		return "SpotLight"
	end
	if sl.Angle >= (CONFIG.PointLightAngleThreshold or 150) then
		return "PointLight"
	end
	return "SpotLight"
end

local function faceAxes(part, face)
	local normal = Vector3.FromNormalId(face)
	local size = part.Size
	local ax, ay, az = math.abs(normal.X), math.abs(normal.Y), math.abs(normal.Z)
	local axisA, axisB, lenA, lenB
	if ax > 0.5 then
		axisA, lenA = Vector3.yAxis, size.Y
		axisB, lenB = Vector3.zAxis, size.Z
	elseif ay > 0.5 then
		axisA, lenA = Vector3.xAxis, size.X
		axisB, lenB = Vector3.zAxis, size.Z
	else
		axisA, lenA = Vector3.xAxis, size.X
		axisB, lenB = Vector3.yAxis, size.Y
	end
	if lenB > lenA then
		axisA, axisB = axisB, axisA
		lenA, lenB = lenB, lenA
	end
	return normal, axisA, lenA, axisB, lenB
end

local function recountStats()
	local total, spots, points = 0, 0, 0
	for _, rec in pairs(records) do
		total += 1
		if rec.className == "SpotLight" then
			spots += 1
		else
			points += 1
		end
	end
	stats.converted = total
	stats.spotLights = spots
	stats.pointLights = points
end

local function destroyReplacementInstances(rec)
	for i = #rec.lights, 1, -1 do
		pcall(rec.lights[i].Destroy, rec.lights[i])
		rec.lights[i] = nil
	end
	for i = #rec.attachments, 1, -1 do
		pcall(rec.attachments[i].Destroy, rec.attachments[i])
		rec.attachments[i] = nil
	end
end

local function buildReplacements(rec)
	destroyReplacementInstances(rec)
	local sl = rec.sl
	local parent = sl.Parent
	if not parent or not (parent:IsA("BasePart") or parent:IsA("Attachment")) then
		return
	end
	local className = chooseLightClass(sl)
	rec.className = className
	local emitterCount = 1
	local longAxis, longLen = nil, 0
	if CONFIG.SplitLongStripLights and parent:IsA("BasePart") then
		local _, axisA, lenA, _, lenB = faceAxes(parent, sl.Face)
		local ratio = lenA / math.max(lenB, 0.25)
		if lenA >= 8 and ratio >= (CONFIG.StripLengthRatio or 3.0) then
			emitterCount = math.clamp(math.floor(lenA / math.max(sl.Range * 0.6, 6) + 0.5), 1, CONFIG.MaxEmittersPerStrip or 3)
			longAxis, longLen = axisA, lenA
		end
	end
	if emitterCount <= 1 then
		local rep = Instance.new(className)
		rep.Name = CONVERTED_NAME
		rep:SetAttribute(CONVERTED_ATTR, true)
		if CONFIG.StencilShadowTag then
			rep:SetAttribute(STENCIL_SHADOW_ATTR, true)
		end
		rep.Parent = parent
		rec.lights[1] = rep
	else
		local span = longLen * 0.7
		for i = 1, emitterCount do
			local t = (i - 1) / (emitterCount - 1) - 0.5
			local att = Instance.new("Attachment")
			att.Name = CONVERTED_ATTACHMENT_NAME
			att.Position = longAxis * (t * span)
			att.Parent = parent
			rec.attachments[#rec.attachments + 1] = att
			local rep = Instance.new(className)
			rep.Name = CONVERTED_NAME
			rep:SetAttribute(CONVERTED_ATTR, true)
			if CONFIG.StencilShadowTag then
				rep:SetAttribute(STENCIL_SHADOW_ATTR, true)
			end
			rep.Parent = att
			rec.lights[#rec.lights + 1] = rep
		end
	end
end

local function syncRecord(rec)
	if rec.syncing or not alive then
		return
	end
	local sl = rec.sl
	if not sl or not sl.Parent then
		return
	end
	local desiredClass = chooseLightClass(sl)
	if rec.className ~= desiredClass or #rec.lights == 0 then
		buildReplacements(rec)
		recountStats()
	end
	rec.syncing = true
	pcall(function()
		if sl.Enabled then
			rec.wasEnabled = true
			if enabled then
				sl.Enabled = false
			end
		end
		local nLights = math.max(#rec.lights, 1)
		local bright = (sl.Brightness * (CONFIG.BrightnessScale or 1.15)) / math.sqrt(nLights)
		local range = math.clamp(sl.Range * (CONFIG.RangeScale or 1.0), 0, 60)
		local castShadows = CONFIG.ForceShadows or (CONFIG.PreserveShadows and sl.Shadows)
		local spotAngle = math.clamp(
			sl.Angle * (CONFIG.SpotAngleScale or 1.15),
			CONFIG.MinSpotAngle or 20,
			CONFIG.MaxSpotAngle or 140
		)
		for _, rep in ipairs(rec.lights) do
			if rep and rep.Parent then
				rep.Enabled = enabled and rec.wasEnabled
				rep.Color = sl.Color
				rep.Brightness = bright
				rep.Range = range
				rep.Shadows = castShadows
				if rep:IsA("SpotLight") then
					rep.Face = sl.Face
					rep.Angle = spotAngle
				end
			end
		end
		if not enabled then
			sl.Enabled = rec.wasEnabled
		end
	end)
	rec.syncing = false
end

local function unconvertSurfaceLight(sl)
	local rec = records[sl]
	if not rec then
		return
	end
	records[sl] = nil
	for _, c in ipairs(rec.conns) do
		pcall(c.Disconnect, c)
	end
	rec.syncing = true
	pcall(function()
		if sl and sl.Parent then
			sl.Enabled = rec.wasEnabled
		end
	end)
	destroyReplacementInstances(rec)
	recountStats()
end

local function convertSurfaceLight(sl)
	if not alive or not sl or not sl:IsA("SurfaceLight") then
		return
	end
	if records[sl] or shouldIgnore(sl) then
		return
	end
	local parent = sl.Parent
	if not parent or not (parent:IsA("BasePart") or parent:IsA("Attachment")) then
		return
	end
	for _, child in ipairs(parent:GetChildren()) do
		if child.Name == CONVERTED_NAME or child.Name == CONVERTED_ATTACHMENT_NAME then
			pcall(child.Destroy, child)
		end
	end
	local rec = {
		sl = sl,
		className = nil,
		lights = {},
		attachments = {},
		conns = {},
		wasEnabled = sl.Enabled,
		syncing = false,
	}
	records[sl] = rec
	buildReplacements(rec)
	syncRecord(rec)
	recountStats()
	rec.conns[#rec.conns + 1] = sl.Changed:Connect(function(prop)
		if rec.syncing or not alive then
			return
		end
		if prop == "Enabled" then
			if sl.Enabled then
				rec.wasEnabled = true
			else
				rec.wasEnabled = false
			end
		end
		syncRecord(rec)
	end)
	rec.conns[#rec.conns + 1] = sl.AncestryChanged:Connect(function(_, newParent)
		if not alive then
			return
		end
		if not newParent then
			unconvertSurfaceLight(sl)
		else
			buildReplacements(rec)
			syncRecord(rec)
			recountStats()
		end
	end)
	rec.conns[#rec.conns + 1] = sl.Destroying:Connect(function()
		unconvertSurfaceLight(sl)
	end)
end

local function watchContainer(root)
	if not root then
		return
	end
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("SurfaceLight") then
			convertSurfaceLight(inst)
		end
	end
	globalConns[#globalConns + 1] = root.DescendantAdded:Connect(function(inst)
		if not alive then
			return
		end
		if inst:IsA("SurfaceLight") then
			task.defer(convertSurfaceLight, inst)
		end
	end)
	globalConns[#globalConns + 1] = root.DescendantRemoving:Connect(function(inst)
		if inst:IsA("SurfaceLight") and records[inst] then
			unconvertSurfaceLight(inst)
		end
	end)
end

local function setEnabled(on)
	on = not not on
	if enabled == on then
		return
	end
	enabled = on
	for _, rec in pairs(records) do
		syncRecord(rec)
	end
end

local function rebuildAll()
	for _, rec in pairs(records) do
		buildReplacements(rec)
		syncRecord(rec)
	end
	recountStats()
end

local function shutdown()
	if not alive then
		return
	end
	alive = false
	for _, c in ipairs(globalConns) do
		pcall(c.Disconnect, c)
	end
	table.clear(globalConns)
	local all = {}
	for sl in pairs(records) do
		all[#all + 1] = sl
	end
	for _, sl in ipairs(all) do
		unconvertSurfaceLight(sl)
	end
	if _G.SurfaceLightConverter then
		_G.SurfaceLightConverter = nil
	end
end

watchContainer(Workspace)

if CONFIG.ConvertToolsAndReplicated then
	watchContainer(ReplicatedStorage)
	watchContainer(StarterPack)
	local lp = Players.LocalPlayer
	if lp then
		local backpack = lp:FindFirstChildOfClass("Backpack")
		if backpack then
			watchContainer(backpack)
		end
		globalConns[#globalConns + 1] = lp.ChildAdded:Connect(function(child)
			if child:IsA("Backpack") then
				watchContainer(child)
			end
		end)
	end
end

if CONFIG.ToggleKey then
	globalConns[#globalConns + 1] = UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == CONFIG.ToggleKey then
			setEnabled(not enabled)
		end
	end)
end

local api = {
	SetEnabled = setEnabled,
	Toggle = function()
		setEnabled(not enabled)
		return enabled
	end,
	IsEnabled = function()
		return enabled
	end,
	SetMode = function(mode)
		if mode == "Auto" or mode == "SpotLight" or mode == "PointLight" then
			CONFIG.Mode = mode
			rebuildAll()
		end
	end,
	Rebuild = rebuildAll,
	GetStats = function()
		return {
			enabled = enabled,
			mode = CONFIG.Mode,
			converted = stats.converted,
			spotLights = stats.spotLights,
			pointLights = stats.pointLights,
		}
	end,
	Destroy = shutdown,
}

_G.SurfaceLightConverter = api
_G.__SurfaceLightConverterCleanup = shutdown

if typeof(getgenv) == "function" then
	local ok, env = pcall(getgenv)
	if ok and type(env) == "table" then
		env.SurfaceLightConverter = api
		env.__SurfaceLightConverterCleanup = shutdown
	end
end
