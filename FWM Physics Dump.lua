-- [[ FWM PHYSICS DUMP - copy and paste, run once inside FWM's (Flex's Wayback Machine's) 2008-2009 place ]]
-- Reads only: nothing in the game is changed. It writes down what FWM's own physics run on, so the 2008 physics can
-- be made to match the game exactly:
--   * FWM's era number (ReplicatedStorage.TimePeriod) and what is in Protocols / Modules
--   * the gravity and the StarterPlayer movement settings
--   * your character as FWM makes it: the Humanoid's settings and which states are switched on, and every part,
--     attachment, constraint (TorsoAttach.AngularTilt and the like), mover, joint and value in it, with the
--     properties that matter for physics (sizes, collisions, friction / bounciness, forces...)
--   * the scripts FWM puts in your character (with their code, if your executor can decompile)
--   * a 12-second recording: as soon as you run it, WALK AND JUMP 3 OR 4 TIMES on flat ground. It notes how FWM's
--     landing dip, jump pause and turning really behave (the humanoid's state, hip height, height above the floor,
--     speed up / down, turning on or off), only when something changes.
-- When it's done: the text is on your clipboard (if your executor can) and saved as FWMPhysicsDump.txt in the
-- executor's workspace folder. Paste it back in the chat. (Run it in FWM's 2006 place too, if that is a separate
-- place, and paste both.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local player = Players.LocalPlayer

local lines = {}
local function out(s) lines[#lines + 1] = s end
local function safe(f, ...)
	local ok, v = pcall(f, ...)
	if ok then return v end
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
	elseif t == "CFrame" then
		local c = { v:GetComponents() }
		for i, x in ipairs(c) do c[i] = num(x) end
		return "CFrame.new(" .. table.concat(c, ", ") .. ")"
	elseif t == "PhysicalProperties" then
		return ("PhysicalProperties.new(%s, %s, %s, %s, %s)"):format(num(v.Density), num(v.Friction), num(v.Elasticity),
			num(v.FrictionWeight), num(v.ElasticityWeight))
	elseif t == "NumberRange" then return ("NumberRange.new(%s, %s)"):format(num(v.Min), num(v.Max))
	elseif t == "EnumItem" then return tostring(v)
	elseif t == "BrickColor" then return ("BrickColor.new(%q)"):format(v.Name)
	elseif t == "Instance" then return "<" .. v.ClassName .. " " .. string.format("%q", v.Name) .. ">"
	end
	return nil
end

-- the properties that matter for a character's physics (each one is only kept where the object really has it)
local PROPS = {
	-- parts
	"Size", "CanCollide", "CanTouch", "CanQuery", "Massless", "Anchored", "CollisionGroup", "RootPriority",
	"CustomPhysicalProperties", "CurrentPhysicalProperties", "Material", "Shape",
	-- attachments
	"Position", "Orientation", "Axis", "SecondaryAxis",
	-- constraints
	"Enabled", "Attachment0", "Attachment1", "MaxTorque", "MaxForce", "MaxVelocity", "MaxAngularVelocity",
	"Responsiveness", "RigidityEnabled", "ReactionTorqueEnabled", "ReactionForceEnabled", "Mode", "AlignType",
	"PrimaryAxisOnly", "PrimaryAxis", "SecondaryAxis", "AngularVelocity", "RelativeTo", "Torque", "Force",
	"ApplyAtCenterOfMass", "VelocityConstraintMode", "LineDirection", "LineVelocity", "PlaneVelocity", "VectorVelocity",
	"ForceLimitMode", "ForceLimitsEnabled", "MaxAxesForce", "MaxPlanarAxesForce", "Visible",
	-- old movers
	"P", "D", "Velocity", "CFrame", "Location",
	-- joints
	"Part0", "Part1", "C0", "C1", "DesiredAngle", "CurrentAngle",
	-- values and scripts
	"Value", "Disabled", "RunContext",
}
local seenProp, PROP_LIST = {}, {}
for _, p in ipairs(PROPS) do
	if not seenProp[p] then seenProp[p] = true; table.insert(PROP_LIST, p) end
end

local function propsOf(inst)
	local props = {}
	for _, p in ipairs(PROP_LIST) do
		local ok, v = pcall(function() return inst[p] end)
		if ok and v ~= nil then
			local s = value(v)
			if s then props[#props + 1] = p .. " = " .. s end
		end
	end
	local attrs = safe(function() return inst:GetAttributes() end)
	if attrs and next(attrs) then
		for k, v in pairs(attrs) do
			local s = value(v)
			if s then props[#props + 1] = "@" .. tostring(k) .. " = " .. s end
		end
	end
	return props
end

local count = 0
local dumpRoot = nil -- (the character itself is written as "Character", not with your name)
local function dumpTree(inst, indent)
	count = count + 1
	local pad = string.rep("  ", indent)
	local props = propsOf(inst)
	local name = (inst == dumpRoot) and "Character" or inst.Name
	out(pad .. inst.ClassName .. " " .. string.format("%q", name) .. (#props > 0 and (": " .. table.concat(props, ", ")) or ""))
	for _, c in ipairs(inst:GetChildren()) do dumpTree(c, indent + 1) end
end

----------------------------------------------------------------------------------------------------
-- 1. the game
----------------------------------------------------------------------------------------------------
out("-- FWM physics dump, PlaceId " .. tostring(game.PlaceId) .. ", " .. tostring(safe(os.date, "!%Y-%m-%d %H:%M UTC") or ""))
local tp = ReplicatedStorage:FindFirstChild("TimePeriod")
out("TimePeriod: " .. (tp and (tp.ClassName .. " = " .. tostring(safe(function() return tp.Value end))) or "(not found)"))
for _, name in ipairs({ "Protocols", "Modules" }) do
	local f = ReplicatedStorage:FindFirstChild(name)
	if f then
		local names = {}
		for _, c in ipairs(f:GetChildren()) do names[#names + 1] = c.Name .. " (" .. c.ClassName .. ")" end
		out(name .. ": " .. table.concat(names, ", "))
	else
		out(name .. ": (not found)")
	end
end
out("workspace.Gravity: " .. tostring(safe(function() return workspace.Gravity end)))
local spProps = {}
for _, p in ipairs({ "CharacterWalkSpeed", "CharacterJumpPower", "CharacterJumpHeight", "CharacterUseJumpPower",
	"CharacterMaxSlopeAngle", "AutoJumpEnabled", "DevComputerMovementMode", "DevTouchMovementMode",
	"EnableMouseLockOption", "CameraMode", "LoadCharacterAppearance" }) do
	local v = safe(function() return StarterPlayer[p] end)
	if v ~= nil then spProps[#spProps + 1] = p .. " = " .. tostring(value(v) or v) end
end
out("StarterPlayer: " .. table.concat(spProps, ", "))

----------------------------------------------------------------------------------------------------
-- 2. your character as FWM makes it
----------------------------------------------------------------------------------------------------
local char = player.Character
if not char then
	local t0 = os.clock()
	repeat task.wait(0.2); char = player.Character until char or os.clock() - t0 > 15
end
local hum = char and char:FindFirstChildOfClass("Humanoid")
if hum then
	local hp = {}
	for _, p in ipairs({ "RigType", "HipHeight", "WalkSpeed", "JumpPower", "JumpHeight", "UseJumpPower", "MaxSlopeAngle",
		"AutoRotate", "AutomaticScalingEnabled", "PlatformStand", "Sit", "BreakJointsOnDeath", "RequiresNeck",
		"EvaluateStateMachine" }) do
		local v = safe(function() return hum[p] end)
		if v ~= nil then hp[#hp + 1] = p .. " = " .. tostring(value(v) or v) end
	end
	out("Humanoid: " .. table.concat(hp, ", "))
	local off = {}
	for _, st in ipairs(Enum.HumanoidStateType:GetEnumItems()) do
		local on = safe(function() return hum:GetStateEnabled(st) end)
		if on == false then off[#off + 1] = st.Name end
	end
	out("Humanoid states switched off: " .. (#off > 0 and table.concat(off, ", ") or "(none)"))
end
if char then
	out("-- the character, every object in it:")
	dumpRoot = char
	dumpTree(char, 0)
else
	out("-- (no character found)")
end

----------------------------------------------------------------------------------------------------
-- 3. the scripts FWM puts in your character (and its ExtraUtil), with their code when the executor can decompile
----------------------------------------------------------------------------------------------------
local scripts = {}
local function addScripts(root, depth)
	if not root then return end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			local level, p = 0, d.Parent
			while p and p ~= root do level = level + 1; p = p.Parent end
			if level <= depth then scripts[#scripts + 1] = d end
		end
	end
end
addScripts(safe(function() return StarterPlayer:FindFirstChildOfClass("StarterCharacterScripts") end), 2)
addScripts(char, 1)
local modules = ReplicatedStorage:FindFirstChild("Modules")
local extra = modules and modules:FindFirstChild("ExtraUtil")
if extra then scripts[#scripts + 1] = extra end
local playerScripts = player:FindFirstChildOfClass("PlayerScripts")
if playerScripts then
	local names = {}
	for _, c in ipairs(playerScripts:GetChildren()) do names[#names + 1] = c.Name .. " (" .. c.ClassName .. ")" end
	out("PlayerScripts: " .. table.concat(names, ", "))
end
out("-- character scripts: " .. #scripts)
local canDecompile = type(decompile) == "function"
for _, s in ipairs(scripts) do
	local disabled = safe(function() return s.Disabled end)
	local full = s:GetFullName()
	if char and s:IsDescendantOf(char) then
		local prefix = char:GetFullName()
		full = "Character" .. full:sub(#prefix + 1) -- (not your name)
	end
	out("--[==[ " .. full .. " (" .. s.ClassName .. (disabled and ", disabled" or "") .. ")")
	if canDecompile then
		local src = safe(decompile, s)
		if type(src) == "string" then
			if #src > 40000 then src = src:sub(1, 40000) .. "\n-- (cut: " .. #src .. " characters)" end
			out(src)
		else
			out("-- (couldn't decompile)")
		end
	else
		out("-- (the executor can't decompile)")
	end
	out("]==]")
end

----------------------------------------------------------------------------------------------------
-- 4. a 12-second recording: walk and jump a few times
----------------------------------------------------------------------------------------------------
local function save(text)
	local saved, copied = false, false
	if writefile then saved = pcall(writefile, "FWMPhysicsDump.txt", text) end
	if setclipboard then copied = pcall(setclipboard, text) end
	return saved, copied
end

local root = char and char:FindFirstChild("HumanoidRootPart")
if hum and root then
	print("[FWM Physics Dump] Recording for 12 seconds: WALK AND JUMP 3 OR 4 TIMES NOW, on flat ground.")
	out("-- recording (t, state, hip height, root height above the floor, root speed up/down, turning, in the air):")
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = { char }
	local t0 = os.clock()
	local last = {}
	local logged = 0
	local function height()
		local hit = safe(function() return workspace:Raycast(root.Position, Vector3.new(0, -20, 0), ray) end)
		return hit and (root.Position.Y - hit.Position.Y) or nil
	end
	local function rec(note)
		if logged > 600 then return end
		local st = hum:GetState().Name
		local hip = math.floor(hum.HipHeight * 100 + 0.5) / 100
		local h = height()
		h = h and math.floor(h * 100 + 0.5) / 100 or -1
		local vy = math.floor(root.AssemblyLinearVelocity.Y + 0.5)
		local turn = hum.AutoRotate
		local air = hum.FloorMaterial == Enum.Material.Air
		if note or st ~= last.st or hip ~= last.hip or math.abs(h - (last.h or h)) >= 0.05 or turn ~= last.turn or air ~= last.air then
			logged = logged + 1
			out(("%.2f %s hip=%s floor=%s vy=%d turn=%s air=%s%s"):format(os.clock() - t0, st, num(hip), num(h), vy,
				tostring(turn), tostring(air), note and (" " .. note) or ""))
			last = { st = st, hip = hip, h = h, turn = turn, air = air }
		end
	end
	local conns = {}
	conns[#conns + 1] = hum:GetPropertyChangedSignal("Jump"):Connect(function()
		rec("Jump=" .. tostring(hum.Jump))
	end)
	conns[#conns + 1] = RunService.RenderStepped:Connect(function() rec(nil) end)
	task.wait(12)
	for _, c in ipairs(conns) do c:Disconnect() end
	out("-- recording done: " .. logged .. " lines")
end

local text = table.concat(lines, "\n")
local saved, copied = save(text)
print(("[FWM Physics Dump] Done: %d objects, %d characters.%s%s"):format(count, #text,
	saved and " Saved as FWMPhysicsDump.txt." or "", copied and " Copied to the clipboard." or ""))
if not saved and not copied then
	-- neither: printed in pieces, so it can be copied from the console
	for i = 1, #text, 3000 do print(text:sub(i, i + 2999)) end
end
