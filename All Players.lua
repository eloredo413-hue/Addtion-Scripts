-- [[ ALL PLAYERS (Addtion-Scripts) ]]
-- Hammer stuff 2's "all players": your setup choices for how a character looks are shown on everyone
-- else's character too, on your screen only (nobody else sees it, and nothing is sent to the game):
--   * the forcefield: 2008 (the flashing outline) or 2012 (the blue bubble, the fixed one), when they
--     have a forcefield
--   * the animations (Bloxy's): 2008 R6 moves their joints the 2008 way; 2014 R6 plays its own
--     animations; 2006 R6 and the R15 sets play the same animations Bloxy put in YOUR character's
--     Animate script (read from it). Each set only goes on bodies of its own kind (R6 or R15), and
--     their own animations are stopped on your screen while ours play. The 2007 animation already
--     animates everyone by itself, so with it picked this leaves animations alone.
--   * the 2006 body (R6): the sharp classic body meshes
-- Not the physics, the camera or any GUI: those are only yours.
-- The choices are read from Bloxy's saved setup (BloxyParadoxConfig.json) and followed if you change
-- them. getgenv().BPAllPlayersCleanup() turns it all off and puts everyone back.

local Env = (getgenv and getgenv()) or _G
if Env.BPAllPlayersCleanup then pcall(Env.BPAllPlayersCleanup) end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local CONFIG_FILE = "BloxyParadoxConfig.json"
local ANIM_2007_FILE = "BloxyAnimation2007Choice.json"
local BODY_2006_ASSET = "rbxassetid://1112295249"

local alive = true
local globalConns = {}
local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(globalConns, c)
	return c
end

local function readJson(path)
	local data = nil
	pcall(function()
		if isfile and readfile and isfile(path) then data = HttpService:JSONDecode(readfile(path)) end
	end)
	return type(data) == "table" and data or nil
end

--========================================================
-- THE CHOICES
--========================================================
local choices = { forcefield = nil, anims = nil, body2006 = false }

local function anim2007On()
	local api = Env.Animation2007
	if type(api) == "table" and type(api.IsRunning) == "function" then
		local ok, on = pcall(api.IsRunning)
		if ok and on then return true end
	end
	local saved = readJson(ANIM_2007_FILE)
	return saved ~= nil and saved.Animation2007 == true
end

local function readChoices()
	local cfg = readJson(CONFIG_FILE)
	local c = cfg and type(cfg.Choices) == "table" and cfg.Choices or {}
	local ff = c.Forcefield
	return {
		forcefield = (ff == "2008" or ff == "2012") and ff or nil,
		anims = (not anim2007On()) and type(c.Anims) == "string" and c.Anims or nil,
		body2006 = c.Body2006 == true,
	}
end

--========================================================
-- THE PLAYERS (everyone but you)
--========================================================
local tracked = {} -- character -> { player, conns = {}, ... }

local function others()
	return pairs(tracked)
end

--========================================================
-- 1. FORCEFIELD
--========================================================
local FF_CYCLES = 60
local ffFolder = Instance.new("Folder")
ffFolder.Name = "BPAllPlayersForcefields"
ffFolder.Parent = workspace

local function sanitize(part)
	for _, side in ipairs({ "Top", "Bottom", "Left", "Right", "Front", "Back" }) do
		part[side .. "Surface"] = Enum.SurfaceType.Smooth
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

-- the 2012 bubble (the fixed one: no studs, nothing can stick to it)
local function build2012()
	local model = Instance.new("Model")
	model.Name = "Forcefield2012"

	local main = Instance.new("Part")
	main.Name = "VisualForcefield2012"
	sanitize(main)
	main.Transparency = 1
	main.Size = Vector3.new(1, 1, 1)
	main.Parent = model

	local function sphere(name, transparency, scale)
		local p = Instance.new("Part")
		p.Name = name
		sanitize(p)
		p.Color = Color3.fromRGB(0, 0, 128)
		p.Material = Enum.Material.Neon
		p.Transparency = transparency
		p.Size = Vector3.new(0.9, 0.9, 0.9)
		p.Parent = model
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Scale = Vector3.new(scale, scale, scale)
		m.Parent = p
		return p
	end
	local mc = sphere("MainCircle", 0.6, 7)
	local oc = sphere("OuterCircle", 0.95, 7.7)

	local sp = Instance.new("Part")
	sp.Name = "Sparkles83"
	sanitize(sp)
	sp.Transparency = 1
	sp.Size = Vector3.new(5, 1, 5)
	sp.Parent = model

	local old = Instance.new("ParticleEmitter")
	old.Name = "OldSparkles"
	old.Lifetime = NumberRange.new(3, 3)
	old.LightEmission = 1e9
	old.LockedToPart = true
	old.Rate = 7
	old.RotSpeed = NumberRange.new(25, 25)
	old.Rotation = NumberRange.new(8, 8)
	old.Size = NumberSequence.new(1)
	old.Speed = NumberRange.new(2, 4)
	old.Texture = "rbxassetid://6334617852"
	old.Transparency = NumberSequence.new(0.5, 1)
	old.Parent = sp

	local rays = Instance.new("ParticleEmitter")
	rays.Name = "Rays"
	rays.Lifetime = NumberRange.new(1, 1)
	rays.LightEmission = 1
	rays.LockedToPart = true
	rays.Rate = 100
	rays.RotSpeed = NumberRange.new(-50, 50)
	rays.Rotation = NumberRange.new(-180, 180)
	rays.Size = NumberSequence.new(2)
	rays.Speed = NumberRange.new(0, 0)
	rays.Texture = "rbxassetid://1084975295"
	rays.Transparency = NumberSequence.new(0.4, 1)
	rays.Parent = main

	model.Parent = ffFolder
	task.spawn(function()
		while model.Parent and alive do
			TweenService:Create(mc, TweenInfo.new(0.55, Enum.EasingStyle.Sine), { Transparency = 0.95 }):Play()
			TweenService:Create(oc, TweenInfo.new(0.7, Enum.EasingStyle.Sine), { Transparency = 0.6 }):Play()
			task.wait(0.55)
			TweenService:Create(oc, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Transparency = 0.95 }):Play()
			TweenService:Create(mc, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Transparency = 0.6 }):Play()
			task.wait(0.35)
		end
	end)

	local parts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(parts, d) end
	end
	return model, parts
end

local function removeForcefield(data)
	local st = data.ff
	if not st then return end
	data.ff = nil
	if st.boxes then
		for _, box in ipairs(st.boxes) do pcall(function() box:Destroy() end) end
	end
	if st.model then pcall(function() st.model:Destroy() end) end
	if st.field and st.field.Parent then pcall(function() st.field.Visible = true end) end
end

local function checkForcefield(char, data)
	local field = char:FindFirstChildOfClass("ForceField")
	local style = field and choices.forcefield or nil
	local st = data.ff
	if st and (st.style ~= style or st.field ~= field) then
		removeForcefield(data)
		st = nil
	end
	if not style then return end
	pcall(function() field.Visible = false end) -- the modern forcefield hidden, as for you
	if st then return end
	st = { style = style, field = field }
	if style == "2008" then
		st.boxes = {}
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				local box = Instance.new("SelectionBox")
				box.Name = "BPAllPlayersFF2008"
				box.Adornee = part
				box.LineThickness = 0.1
				box.SurfaceTransparency = 1
				box.Parent = char
				table.insert(st.boxes, box)
			end
		end
	else
		st.model, st.parts = build2012()
	end
	data.ff = st
end

local function torsoOf(char)
	return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
end

--========================================================
-- 2. THE 2006 BODY (R6)
--========================================================
local packageMeshes = nil -- the classic package's CharacterMeshes, loaded once
local packageLoading = false
local function loadPackage()
	if packageMeshes or packageLoading then return end
	packageLoading = true
	task.spawn(function()
		local ok, objects = pcall(function() return game:GetObjects(BODY_2006_ASSET) end)
		local list = {}
		if ok and type(objects) == "table" and objects[1] then
			for _, d in ipairs(objects[1]:GetDescendants()) do
				if d:IsA("CharacterMesh") then table.insert(list, d) end
			end
		end
		if #list > 0 then
			packageMeshes = list
		else
			warn("[All Players] the 2006 body package couldn't be loaded (GetObjects)")
			packageMeshes = {}
		end
		packageLoading = false
	end)
end

local function refreshClothing(char)
	for _, item in ipairs(char:GetChildren()) do
		if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
			local parent = item.Parent
			item.Parent = nil
			item.Parent = parent
		end
	end
end

local function removeBody(data)
	local st = data.body
	if not st then return end
	data.body = nil
	if st.conn then st.conn:Disconnect() end
	for _, m in ipairs(st.ours) do pcall(function() m:Destroy() end) end
	for _, m in ipairs(st.stashed) do
		pcall(function() if data.char.Parent then m.Parent = data.char end end)
	end
	pcall(refreshClothing, data.char)
end

local function checkBody(char, data)
	local want = choices.body2006 and data.hum and data.hum.RigType == Enum.HumanoidRigType.R6
	if not want then
		removeBody(data)
		return
	end
	if data.body then return end
	if not packageMeshes then loadPackage() return end
	if #packageMeshes == 0 then return end
	local st = { ours = {}, stashed = {}, mine = {} }
	local function stash(child)
		if child:IsA("CharacterMesh") and not st.mine[child] then
			table.insert(st.stashed, child)
			child.Parent = nil
		end
	end
	for _, child in ipairs(char:GetChildren()) do stash(child) end
	for _, mesh in ipairs(packageMeshes) do
		local copy = mesh:Clone()
		st.mine[copy] = true
		table.insert(st.ours, copy)
		copy.Parent = char
	end
	-- their own meshes can come in after (the avatar loading): put away too
	st.conn = char.ChildAdded:Connect(function(child)
		task.defer(function() if data.body == st and child.Parent == char then stash(child) end end)
	end)
	data.body = st
	refreshClothing(char)
end

--========================================================
-- 3. ANIMATIONS
--========================================================
-- Bloxy's 2014 R6 set (its own animations, not in the Animate script)
local R6_2014 = {
	idle = "rbxassetid://161100084", walk = "rbxassetid://161210451", jump = "rbxassetid://165167557",
	fall = "rbxassetid://165167632", climb = "rbxassetid://161235826", swim = "rbxassetid://144078604",
	sit = "rbxassetid://178130996",
}
-- the Animate script's folders: state -> folder name
local ANIMATE_FOLDERS = {
	idle = "idle", walk = "walk", run = "run", jump = "jump", fall = "fall", climb = "climb",
	sit = "sit", swim = "swim", swimidle = "swimidle",
}
local LOOPED = { idle = true, walk = true, run = true, climb = true, swim = true, swimidle = true, sit = true }

-- which animations to show on the others: { kind = "procedural" | "keyframes", rig = R6/R15, ids = {} }
local animSet = nil
local animSetKey = nil

-- the set Bloxy put in YOUR character's Animate script
local function readLocalAnimate()
	local char = LocalPlayer.Character
	local animate = char and char:FindFirstChild("Animate")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (animate and hum) then return nil end
	local ids = {}
	for state, folderName in pairs(ANIMATE_FOLDERS) do
		local folder = animate:FindFirstChild(folderName)
		local anim = folder and folder:FindFirstChildWhichIsA("Animation", true)
		if anim and anim.AnimationId ~= "" then ids[state] = anim.AnimationId end
	end
	if not next(ids) then return nil end
	return ids, hum.RigType
end

local function decideAnimSet()
	local a = choices.anims
	if not a then return nil end
	if a == "R6_2008" then
		return { kind = "procedural", rig = Enum.HumanoidRigType.R6 }
	elseif a == "R6_2014" then
		return { kind = "keyframes", rig = Enum.HumanoidRigType.R6, ids = R6_2014 }
	elseif a == "R6_2006" or a == "R15_2008" or a == "R15_2014" or a == "R15_Old" then
		local ids, rig = readLocalAnimate()
		local wantRig = (a == "R6_2006") and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15
		if ids and rig == wantRig then
			return { kind = "keyframes", rig = rig, ids = ids }
		end
	end
	return nil
end

local function setKey(set)
	if not set then return "none" end
	local parts = { set.kind, tostring(set.rig) }
	if set.ids then
		local names = {}
		for state in pairs(set.ids) do table.insert(names, state) end
		table.sort(names)
		for _, state in ipairs(names) do table.insert(parts, state .. "=" .. set.ids[state]) end
	end
	return table.concat(parts, "|")
end

local function removeAnim(data)
	local st = data.anim
	if not st then return end
	data.anim = nil
	for _, c in ipairs(st.conns) do pcall(function() c:Disconnect() end) end
	if st.tracks then
		for _, track in pairs(st.tracks) do pcall(function() track:Stop(0) track:Destroy() end) end
	end
	if st.joints then
		for _, joint in ipairs(st.joints) do
			pcall(function() joint.MaxVelocity = 0.5 joint:SetDesiredAngle(0) end)
		end
	end
end

-- their own (replicated) animations are stopped while ours show; ours are let through
local function holdTheirsOff(st, hum)
	local animator = hum:FindFirstChildOfClass("Animator") or hum
	for _, t in ipairs(hum:GetPlayingAnimationTracks()) do
		if not (st.ours and st.ours[t]) then pcall(function() t:Stop(0) end) end
	end
	table.insert(st.conns, animator.AnimationPlayed:Connect(function(t)
		if alive and not (st.ours and st.ours[t]) then pcall(function() t:Stop(0) end) end
	end))
	return animator
end

local RUN_MIN = 0.5
local function poseOf(data)
	local hum, root = data.hum, data.root
	local state = hum:GetState()
	local v = root and root.AssemblyLinearVelocity or Vector3.zero
	local flat = Vector3.new(v.X, 0, v.Z).Magnitude
	if hum.Sit or state == Enum.HumanoidStateType.Seated then return "sit", flat end
	if state == Enum.HumanoidStateType.Climbing then return "climb", flat end
	if state == Enum.HumanoidStateType.Swimming then return (flat > 1) and "swim" or "swimidle", flat end
	if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall or math.abs(v.Y) > 8 then
		return (v.Y > 0) and "jump" or "fall", flat
	end
	if flat > RUN_MIN then return "walk", flat end
	return "idle", flat
end

local function setupKeyframes(char, data, set)
	local hum = data.hum
	if hum.RigType ~= set.rig then return end
	local st = { conns = {}, tracks = {}, ours = {}, current = nil, currentName = nil }
	local animator = holdTheirsOff(st, hum)
	local function track(name)
		if st.tracks[name] ~= nil then return st.tracks[name] or nil end
		local id = set.ids[name]
		-- a state the set has no animation for: a close one
		if not id then
			local near = ({ run = "walk", fall = "jump", jump = "fall", swim = "walk", swimidle = "idle",
				climb = "walk", sit = "idle" })[name]
			id = near and set.ids[near]
		end
		if not id then st.tracks[name] = false return nil end
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, t = pcall(function() return animator:LoadAnimation(anim) end)
		if not ok or not t then st.tracks[name] = false return nil end
		st.ours[t] = true
		pcall(function() t.Looped = LOOPED[name] == true end)
		st.tracks[name] = t
		return t
	end
	st.step = function()
		local name, speed = poseOf(data)
		if name == "walk" and set.ids.run and speed > 12 then name = "run" end
		if name ~= st.currentName then
			local t = track(name)
			if st.current and st.current ~= t then pcall(function() st.current:Stop(0.15) end) end
			if t and st.current ~= t then pcall(function() t:Play(0.15) end) end
			st.current, st.currentName = t, name
		end
		if st.current and (name == "walk" or name == "run") then
			-- the walk keeps pace with how fast they go, like Roblox's own
			pcall(function() st.current:AdjustSpeed(math.clamp(speed / 16, 0.5, 2)) end)
		end
	end
	data.anim = st
end

-- the 2008 way: the arms and legs swing on their joints (as the old Animate script did)
local function setupProcedural(char, data)
	local hum = data.hum
	if hum.RigType ~= Enum.HumanoidRigType.R6 then return end
	local torso = char:FindFirstChild("Torso")
	if not torso then return end
	local rS, lS = torso:FindFirstChild("Right Shoulder"), torso:FindFirstChild("Left Shoulder")
	local rH, lH = torso:FindFirstChild("Right Hip"), torso:FindFirstChild("Left Hip")
	if not (rS and lS and rH and lH) then return end
	local st = { conns = {}, ours = {}, joints = { rS, lS, rH, lH } }
	holdTheirsOff(st, hum)
	st.step = function(now)
		local pose = poseOf(data)
		if pose == "jump" or pose == "fall" then
			rS.MaxVelocity = 0.75; lS.MaxVelocity = 0.75
			rS:SetDesiredAngle(3.14); lS:SetDesiredAngle(-3.14); rH:SetDesiredAngle(0); lH:SetDesiredAngle(0)
		elseif pose == "sit" then
			rS.MaxVelocity = 0.15; lS.MaxVelocity = 0.15
			rS:SetDesiredAngle(1.57); lS:SetDesiredAngle(-1.57); rH:SetDesiredAngle(1.57); lH:SetDesiredAngle(-1.57)
		else
			local amp, freq, climb = 0.1, 1, 0
			if pose == "walk" or pose == "swim" then
				rS.MaxVelocity = 0.15; lS.MaxVelocity = 0.15; amp = 1; freq = 9
			elseif pose == "climb" then
				rS.MaxVelocity = 0.5; lS.MaxVelocity = 0.5; amp = 1; freq = 9; climb = 3.14
			end
			local ang = amp * math.sin(now * freq)
			rS:SetDesiredAngle(ang + climb)
			lS:SetDesiredAngle(ang - climb)
			rH:SetDesiredAngle(-ang)
			lH:SetDesiredAngle(-ang)
		end
	end
	data.anim = st
end

local function checkAnim(char, data)
	if data.anim and data.animKey == animSetKey then return end
	removeAnim(data)
	data.animKey = animSetKey
	if not animSet or not data.hum then return end
	if animSet.kind == "procedural" then
		setupProcedural(char, data)
	else
		setupKeyframes(char, data, animSet)
	end
end

--========================================================
-- EACH CHARACTER
--========================================================
local function forgetCharacter(char)
	local data = tracked[char]
	if not data then return end
	tracked[char] = nil
	removeForcefield(data)
	removeBody(data)
	removeAnim(data)
	for _, c in ipairs(data.conns) do pcall(function() c:Disconnect() end) end
end

local function watchCharacter(player, char)
	if tracked[char] or player == LocalPlayer then return end
	task.spawn(function()
		local hum = char:WaitForChild("Humanoid", 10)
		local root = char:WaitForChild("HumanoidRootPart", 10)
		if not (alive and hum and root and char.Parent) or tracked[char] then return end
		local data = { player = player, char = char, hum = hum, root = root, conns = {} }
		tracked[char] = data
		table.insert(data.conns, char.AncestryChanged:Connect(function(_, parent)
			if not parent then forgetCharacter(char) end
		end))
		pcall(checkForcefield, char, data)
		pcall(checkBody, char, data)
		pcall(checkAnim, char, data)
	end)
end

local function watchPlayer(player)
	if player == LocalPlayer then return end
	if player.Character then watchCharacter(player, player.Character) end
	connect(player.CharacterAdded, function(char) watchCharacter(player, char) end)
end

for _, player in ipairs(Players:GetPlayers()) do watchPlayer(player) end
connect(Players.PlayerAdded, watchPlayer)
connect(Players.PlayerRemoving, function(player)
	for char, data in pairs(tracked) do
		if data.player == player then forgetCharacter(char) end
	end
end)

--========================================================
-- THE LOOPS
--========================================================
local function refreshChoices()
	choices = readChoices()
	local set = decideAnimSet()
	local key = setKey(set)
	if key ~= animSetKey then
		animSet, animSetKey = set, key
	end
	for char, data in others() do
		pcall(checkBody, char, data)
		pcall(checkAnim, char, data)
	end
end
refreshChoices()

local sinceChoices, sinceFF = 0, 0
local ffStart = os.clock()
connect(RunService.Heartbeat, function(dt)
	if not alive then return end
	sinceChoices = sinceChoices + dt
	if sinceChoices >= 3 then
		sinceChoices = 0
		refreshChoices()
	end
	sinceFF = sinceFF + dt
	local checkFF = sinceFF >= 0.1
	if checkFF then sinceFF = 0 end

	local now = os.clock()
	-- the 2008 forcefield's colour, red to blue and back
	local cycle = math.floor(((now - ffStart) * 2) * FF_CYCLES) % (FF_CYCLES * 2)
	if cycle > FF_CYCLES then cycle = FF_CYCLES - (cycle - FF_CYCLES) end
	local ffColor = Color3.new(cycle / FF_CYCLES, 0, (FF_CYCLES - cycle) / FF_CYCLES)

	for char, data in others() do
		if checkFF then pcall(checkForcefield, char, data) end
		local ff = data.ff
		if ff and ff.boxes then
			for _, box in ipairs(ff.boxes) do box.Color3 = ffColor end
		end
		local anim = data.anim
		if anim and anim.step and data.hum.Health > 0 then pcall(anim.step, now) end
	end
end)

-- the 2012 bubbles follow their torso, just before the frame is drawn
connect(RunService.RenderStepped, function()
	for char, data in others() do
		local ff = data.ff
		if ff and ff.parts then
			local torso = torsoOf(char)
			if torso then
				local cf = torso.CFrame
				for _, p in ipairs(ff.parts) do p.CFrame = cf end
			end
		end
	end
end)

--========================================================
-- OFF
--========================================================
local function cleanup()
	if not alive then return end
	alive = false
	for _, c in ipairs(globalConns) do pcall(function() c:Disconnect() end) end
	table.clear(globalConns)
	local chars = {}
	for char in pairs(tracked) do table.insert(chars, char) end
	for _, char in ipairs(chars) do forgetCharacter(char) end
	pcall(function() ffFolder:Destroy() end)
	if Env.BPAllPlayersCleanup == cleanup then Env.BPAllPlayersCleanup = nil end
	print("[All Players] Off: everyone else looks as they did.")
end
Env.BPAllPlayersCleanup = cleanup

print("[All Players] On: your forcefield, animations and 2006 body choices on everyone (your screen only)."
	.. " Forcefield: " .. tostring(choices.forcefield or "theirs")
	.. ", animations: " .. tostring(choices.anims or (anim2007On() and "2007 (already on everyone)" or "theirs"))
	.. ", 2006 body: " .. tostring(choices.body2006))
