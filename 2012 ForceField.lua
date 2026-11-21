--========================================================
-- 2012 FORCEFIELD (Addtion-Scripts) — what Bloxy's "2012" forcefield choice shows
-- The old client's particle forcefield (the 2012 and 2014 clients had the same two particle systems,
-- content/particles, the files the user gave):
--   * forceFieldBeam: light beams rising from a ring around your feet. A ring 2 to 2.5 studs out, 2 studs under the
--     middle of the body; 20 a second going straight up at 2 to 5 studs a second, each one half a stud wide and 2
--     tall, standing upright; it fades in over its first second and out over its second (2 s each).
--   * forceFieldRadial: big soft flares at the middle of the body. 2 a second, 5 studs and growing 6 a second, turned
--     any way and spinning (4 to 100 degrees a second), fading out over their 2 seconds.
-- Both glow (added light), and both are the one texture the old forcefield used for them: the white star the user
-- found, recreated in high quality from the old clips (this repo's assets/forcefield2012.png, 512 x 512: a bright
-- core, a soft halo and thin rays, white going lavender at the edges, see-through round it), in its own colours. It is
-- downloaded once into the executor's folder and shown with getcustomasset; Roblox's own sparkle until then (or if
-- the executor can't).
-- With them, the sphere of Bloxy's original 2012 forcefield, coloured as in the user's old clips: a blue neon bubble
-- round the torso (6.93 studs) with a smaller one inside it (6.3), both see-through, the inside one more so. They stay
-- as they are (the original's pulse made them flicker). Roblox's own forcefield is hidden while it shows.
--
-- Picking "2012" on Bloxy's forcefield step (or having it saved) starts it: the FF Fix Hook hands Bloxy's 2012
-- forcefield code over to this (getgenv().Forcefield2012.Start), and if Bloxy's own blue bubble shows anyway
-- (workspace.FFCloneHolder) it is taken away and this starts in its place. Picking 2008 or normal stops it.
-- Your character only; everyone's with Hammer stuff 2's "all players" (All Players.lua calls SetEveryone).
-- (There is no "2014" choice any more.)
-- By hand: getgenv().Forcefield2012.Start() / .Stop() / .IsRunning() / .SetEveryone(true or false)
--========================================================

do
	local Players = game:GetService("Players")
	local HttpService = game:GetService("HttpService")
	local RunService = game:GetService("RunService")
	local CoreGui = game:GetService("CoreGui")

	local Env = (getgenv and getgenv()) or _G
	if Env.Forcefield2012Cleanup then pcall(Env.Forcefield2012Cleanup) end
	-- (the 2014 one this used to be: off, if a session still has it)
	if Env.Forcefield2014Cleanup then pcall(Env.Forcefield2014Cleanup) end

	local BLOXY_CONFIG = "BloxyParadoxConfig.json"
	local BLOXY_GUI = "BloxyParadoxProject"
	local STEP_TEXT = "choose your forcefield"
	local EFFECT_NAME = "Forcefield2012Particles"
	local BLOXY_HOLDER = "FFCloneHolder" -- (Bloxy's 2012 forcefield, the blue bubble, puts its model in this)
	local STAR_URL = "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/assets/forcefield2012.png"
	-- (a new name for each new picture: the executor keeps the file, so an old copy would otherwise stay)
	local STAR_FILE = "AddtionAssets/forcefield2012_v3.png"
	local STAR_FALLBACK = "rbxasset://textures/particles/sparkles_main.dds"
	local SPHERE_HOLDER = "Forcefield2012Spheres"
	-- the bubble in the user's clips: a strong mid blue (measured over three backgrounds: about 0, 29, 163 at 43% seen),
	-- a little darker here as neon shows brighter than its colour
	local SPHERE_COLOR = Color3.fromRGB(0, 25, 190) -- (a clear dark blue: deep, but plainly blue, not black)
	local OUTER_SEE_THROUGH = 0.62 -- (the bubble, at its strongest)
	local INNER_SEE_THROUGH = 0.8  -- (the little one inside: lighter, so you see yourself through it)
	-- the bubble flares in and out, as in the user's 2012 clip: smoothly from strong to more see-through and back,
	-- never gone. Measured there over two full rounds: one round about every 3.2 seconds, at its faintest about 40% as
	-- strong as at its strongest.
	local PULSE_PERIOD = 3.2
	local OUTER_FAINT = 0.85
	local INNER_FAINT = 0.92

	-- the particle files' numbers
	local BEAM = {
		rate = 20, lifetime = 2, speedMin = 2, speedMax = 5,
		ringOuter = 2.5, ringInner = 2.5 * 0.8, below = 2, -- (width / height 5, inner 0.8; position 0 -2 0)
		width = 0.5, height = 2,
		brightest = 0.3, -- (less flicker: never fully solid)
	}
	-- (less flicker than the files: spinning 4 to 30 degrees a second, not to 100)
	local RADIAL = { rate = 2, lifetime = 2, size = 5, grow = 6, spinMin = 4, spinMax = 30, brightest = 0.2 }

	local alive, running, everyone = true, false, false
	local connections = {}
	local engineConns = {}
	local effects = {} -- character -> { parts = {...}, ff = ForceField, conns = {...} }
	local hidden = setmetatable({}, { __mode = "k" }) -- forcefields this hid
	local watched = {}
	local handled = setmetatable({}, { __mode = "k" })
	local sphereHolder = nil
	local starImage = STAR_FALLBACK

	------------------------------------------------------------
	-- the star (this repo's, kept in the executor's folder)
	------------------------------------------------------------
	task.spawn(function()
		local getAsset = (type(getcustomasset) == "function" and getcustomasset)
			or (type(getsynasset) == "function" and getsynasset) or nil
		if not (getAsset and type(writefile) == "function" and type(isfile) == "function") then return end
		pcall(function()
			if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("AddtionAssets") then
				makefolder("AddtionAssets")
			end
			if not isfile(STAR_FILE) then
				local data = game:HttpGet(STAR_URL .. "?v=" .. tostring(os.time()))
				if type(data) == "string" and #data > 64 and string.sub(data, 2, 4) == "PNG" then writefile(STAR_FILE, data) end
			end
			if isfile(STAR_FILE) then
				local id = getAsset(STAR_FILE)
				if type(id) == "string" and id ~= "" then
					starImage = id
					for _, entry in pairs(effects) do
						for _, e in ipairs(entry.emitters) do e.Texture = id end
					end
				end
			end
		end)
	end)

	local function disconnectAll(list)
		for _, c in ipairs(list) do pcall(function() c:Disconnect() end) end
		table.clear(list)
	end
	local function connect(list, signal, fn)
		local c = signal:Connect(fn)
		table.insert(list, c)
		return c
	end

	------------------------------------------------------------
	-- THE EFFECT
	------------------------------------------------------------
	local function bodyOf(character)
		return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
			or character:FindFirstChild("UpperTorso")
	end
	-- (the sphere sits on the torso, as in the original)
	local function torsoOf(character)
		return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
			or character:FindFirstChild("HumanoidRootPart")
	end

	-- one of the original's spheres: a navy neon ball, only a look (no collision, touching or ray hits). (A ball
	-- part, not a sphere mesh, so nothing that takes meshes off parts takes it off this.)
	local function newSphere(name, diameter, transparency)
		if not (sphereHolder and sphereHolder.Parent) then
			sphereHolder = Instance.new("Folder")
			sphereHolder.Name = SPHERE_HOLDER
			sphereHolder.Parent = workspace
		end
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(diameter, diameter, diameter)
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		p.Massless = true
		p.Color = SPHERE_COLOR
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = transparency
		for _, side in ipairs({ "Top", "Bottom", "Left", "Right", "Front", "Back" }) do
			p[side .. "Surface"] = Enum.SurfaceType.Smooth
		end
		p.Parent = sphereHolder
		return p
	end

	local function removeEffect(character)
		local entry = effects[character]
		if not entry then return end
		effects[character] = nil
		disconnectAll(entry.conns)
		for _, inst in ipairs(entry.parts) do pcall(function() inst:Destroy() end) end
		local ff = entry.ff
		if ff and hidden[ff] then
			hidden[ff] = nil
			pcall(function() ff.Visible = true end)
		end
	end

	local function addEffect(character, ff)
		if effects[character] then return end
		local body = bodyOf(character)
		if not body then return end
		local entry = { parts = {}, emitters = {}, conns = {}, ff = ff }
		effects[character] = entry

		-- Roblox's own forcefield hidden (and kept hidden) while this one shows
		hidden[ff] = true
		pcall(function() ff.Visible = false end)
		connect(entry.conns, ff:GetPropertyChangedSignal("Visible"), function()
			if running and effects[character] == entry and ff.Visible then
				pcall(function() ff.Visible = false end)
			end
		end)

		-- forceFieldBeam: the ring under the body. The attachment is moved to a new point of the ring every frame, so
		-- each beam starts somewhere else around it (the Ring emitter's way)
		local ring = Instance.new("Attachment")
		ring.Name = EFFECT_NAME .. "Ring"
		ring.Position = Vector3.new(0, -BEAM.below, 0)
		local beams = Instance.new("ParticleEmitter")
		beams.Name = "Beam"
		beams.Texture = starImage
		beams.Color = ColorSequence.new(Color3.new(1, 1, 1)) -- (the star's own colours)
		beams.LightEmission = 1
		beams.LightInfluence = 0
		beams.Rate = BEAM.rate
		beams.Lifetime = NumberRange.new(BEAM.lifetime)
		beams.Speed = NumberRange.new(BEAM.speedMin, BEAM.speedMax)
		beams.EmissionDirection = Enum.NormalId.Top
		beams.SpreadAngle = Vector2.new(0, 0)
		beams.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp -- (billboard_type oriented_common, 0 1 0)
		-- half a stud wide and two tall: square particles stretched up (Squash 1: twice as tall, half as wide)
		beams.Size = NumberSequence.new(BEAM.width)
		pcall(function() beams.Squash = NumberSequence.new(1) end)
		-- ColourFader2: the alpha goes up for the first second, then down for the second. (Less flicker: at their
		-- brightest a little see-through, so many of them over each other don't flash)
		beams.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, BEAM.brightest),
			NumberSequenceKeypoint.new(1, 1),
		})
		beams.LockedToPart = false
		beams.Parent = ring
		ring.Parent = body
		table.insert(entry.parts, ring)
		table.insert(entry.emitters, beams)

		-- forceFieldRadial: at the middle of the body
		local middle = Instance.new("Attachment")
		middle.Name = EFFECT_NAME .. "Middle"
		local radial = Instance.new("ParticleEmitter")
		radial.Name = "Radial"
		radial.Texture = starImage
		radial.Color = ColorSequence.new(Color3.new(1, 1, 1))
		radial.LightEmission = 1
		radial.LightInfluence = 0
		radial.Rate = RADIAL.rate
		radial.Lifetime = NumberRange.new(RADIAL.lifetime)
		radial.Speed = NumberRange.new(0, 0.1)
		radial.SpreadAngle = Vector2.new(18, 18)
		radial.EmissionDirection = Enum.NormalId.Top
		radial.Rotation = NumberRange.new(0, 365)
		radial.RotSpeed = NumberRange.new(RADIAL.spinMin, RADIAL.spinMax)
		-- 5 studs growing 6 a second (17 at the end); a particle's Size is half its width
		radial.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, RADIAL.size / 2),
			NumberSequenceKeypoint.new(1, (RADIAL.size + RADIAL.grow * RADIAL.lifetime) / 2),
		})
		-- ColourFader alpha -0.5: from whole to gone over the 2 seconds. (Less flicker: each one fades in over its first
		-- fifth instead of popping up at full brightness)
		radial.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, RADIAL.brightest),
			NumberSequenceKeypoint.new(1, 1),
		})
		radial.LockedToPart = false
		radial.Parent = middle
		middle.Parent = body
		table.insert(entry.parts, middle)
		table.insert(entry.emitters, radial)

		-- the original's sphere: inner 0.9 x 7 = 6.3 studs, outer 0.9 x 7.7 = 6.93, on the torso; it flares in and out
		-- (smooth, starting strong; see PULSE_PERIOD)
		local inner = newSphere("MainCircle", 6.3, INNER_SEE_THROUGH)
		local outer = newSphere("OuterCircle", 6.93, OUTER_SEE_THROUGH)
		table.insert(entry.parts, inner)
		table.insert(entry.parts, outer)
		local born = os.clock()
		local function follow()
			local torso = torsoOf(character)
			if torso and inner.Parent then
				local at = torso.CFrame
				inner.CFrame = at
				outer.CFrame = at
			end
			local fade = 0.5 - 0.5 * math.cos((os.clock() - born) / PULSE_PERIOD * 2 * math.pi)
			outer.Transparency = OUTER_SEE_THROUGH + (OUTER_FAINT - OUTER_SEE_THROUGH) * fade
			inner.Transparency = INNER_SEE_THROUGH + (INNER_FAINT - INNER_SEE_THROUGH) * fade
		end
		follow()
		local okPre = pcall(function()
			connect(entry.conns, RunService.PreRender, follow)
		end)
		if not okPre then connect(entry.conns, RunService.RenderStepped, follow) end

		connect(entry.conns, RunService.Heartbeat, function()
			-- (the forcefield gone, however it went: this one goes too)
			if ff.Parent ~= character then removeEffect(character) return end
			if not ring.Parent then return end
			local angle = math.random() * math.pi * 2
			local radius = BEAM.ringInner + math.random() * (BEAM.ringOuter - BEAM.ringInner)
			ring.Position = Vector3.new(math.cos(angle) * radius, -BEAM.below, math.sin(angle) * radius)
		end)
		connect(entry.conns, ff.AncestryChanged, function(_, parent)
			if parent ~= character then removeEffect(character) end
		end)
	end

	local function wanted(player)
		return player == Players.LocalPlayer or everyone
	end

	local function watchCharacter(character, conns)
		local function check(child)
			if running and child:IsA("ForceField") then
				task.defer(function()
					if running and child.Parent == character then addEffect(character, child) end
				end)
			end
		end
		for _, child in ipairs(character:GetChildren()) do check(child) end
		connect(conns, character.ChildAdded, check)
		connect(conns, character.AncestryChanged, function(_, parent)
			if not parent then removeEffect(character) end
		end)
	end

	local watchedPlayers = {}
	local function watchPlayer(player)
		if watchedPlayers[player] or not wanted(player) then return end
		watchedPlayers[player] = true
		if player.Character then watchCharacter(player.Character, engineConns) end
		connect(engineConns, player.CharacterAdded, function(character)
			watchCharacter(character, engineConns)
		end)
	end

	local engine = {}
	function engine.IsRunning() return running end
	function engine.Start()
		if running or not alive then return end
		running = true
		for _, player in ipairs(Players:GetPlayers()) do pcall(watchPlayer, player) end
		connect(engineConns, Players.PlayerAdded, function(player) pcall(watchPlayer, player) end)
		print("[2012 ForceField] On: the sphere, beams and sparkles on "
			.. (everyone and "every character" or "your character") .. " with a forcefield.")
	end
	function engine.Stop()
		if not running then return end
		running = false
		disconnectAll(engineConns)
		table.clear(watchedPlayers)
		local list = {}
		for character in pairs(effects) do table.insert(list, character) end
		for _, character in ipairs(list) do removeEffect(character) end
		print("[2012 ForceField] Off.")
	end
	-- everyone's forcefield too (Hammer stuff 2's "all players"), or only yours
	function engine.SetEveryone(on)
		on = on == true
		if on == everyone then return end
		everyone = on
		if running then
			-- (started again, so the characters it draws on are picked afresh)
			running = false
			disconnectAll(engineConns)
			table.clear(watchedPlayers)
			local list = {}
			for character in pairs(effects) do table.insert(list, character) end
			for _, character in ipairs(list) do removeEffect(character) end
			engine.Start()
		end
	end

	Env.Forcefield2012 = {
		Start = engine.Start, Stop = engine.Stop, IsRunning = engine.IsRunning, SetEveryone = engine.SetEveryone,
	}
	Env.Forcefield2012Cleanup = function()
		alive = false
		disconnectAll(connections)
		table.clear(watched)
		engine.Stop()
		if sphereHolder then pcall(function() sphereHolder:Destroy() end) sphereHolder = nil end
		Env.Forcefield2012 = nil
	end

	------------------------------------------------------------
	-- BLOXY'S OWN 2012 FORCEFIELD (the blue bubble): taken away, this one in its place
	-- (when the FF Fix Hook couldn't hand its code over: its model is put in workspace.FFCloneHolder)
	------------------------------------------------------------
	local function takeAway(model)
		if not (alive and model:IsA("Model")) then return end
		task.defer(function()
			if model.Parent then pcall(function() model:Destroy() end) end
		end)
		engine.Start()
	end
	local function watchHolder(folder)
		if not (alive and folder:IsA("Folder") and folder.Name == BLOXY_HOLDER) then return end
		for _, model in ipairs(folder:GetChildren()) do takeAway(model) end
		connect(connections, folder.ChildAdded, takeAway)
		-- (Bloxy's 2012 forcefield was picked: this one shows when you get a forcefield)
		engine.Start()
	end
	for _, child in ipairs(workspace:GetChildren()) do watchHolder(child) end
	connect(connections, workspace.ChildAdded, watchHolder)

	------------------------------------------------------------
	-- BLOXY'S FORCEFIELD STEP: 2008 or normal picked, this one stops ("2012" starts it through the hook)
	------------------------------------------------------------
	local function findStepLabel(frame)
		for _, d in ipairs(frame:GetChildren()) do
			if d:IsA("TextLabel") and string.find(string.lower(d.Text or ""), STEP_TEXT, 1, true) then return d end
		end
		return nil
	end
	local function buttonWithText(frame, text)
		for _, d in ipairs(frame:GetChildren()) do
			if d:IsA("TextButton") and d.Text == text then return d end
		end
		return nil
	end

	local function watchStep(frame)
		if not findStepLabel(frame) then return false end
		local b2008 = buttonWithText(frame, "2008(r6 only)")
		local bNormal = buttonWithText(frame, "normal")
		if not (b2008 and bNormal) then return false end
		for _, other in ipairs({ b2008, bNormal }) do
			connect(connections, other.MouseButton1Click, function()
				if alive then engine.Stop() end
			end)
		end
		return true
	end

	local function checkFrame(frame)
		if not alive or handled[frame] or not frame:IsA("Frame") then return end
		handled[frame] = true
		task.spawn(function()
			for _ = 1, 30 do
				if not alive or not frame.Parent then return end
				if watchStep(frame) then return end
				task.wait()
			end
		end)
	end

	local function watchBloxy(sg)
		if not (sg:IsA("ScreenGui") and sg.Name == BLOXY_GUI) or watched[sg] then return end
		watched[sg] = true
		connect(connections, sg.AncestryChanged, function()
			if not sg.Parent then watched[sg] = nil end
		end)
		for _, frame in ipairs(sg:GetChildren()) do checkFrame(frame) end
		connect(connections, sg.ChildAdded, checkFrame)
	end

	task.spawn(function()
		local plr = Players.LocalPlayer
		while not plr do
			task.wait()
			plr = Players.LocalPlayer
		end
		local pg = plr:WaitForChild("PlayerGui")
		local containers = { pg }
		pcall(function()
			local hui = gethui and gethui()
			if hui and hui ~= pg then table.insert(containers, hui) end
		end)
		pcall(function()
			local _ = CoreGui:GetChildren()
			table.insert(containers, CoreGui)
		end)
		if not alive then return end
		for _, container in ipairs(containers) do
			pcall(function()
				for _, g in ipairs(container:GetChildren()) do watchBloxy(g) end
				connect(connections, container.ChildAdded, watchBloxy)
			end)
		end
	end)

	local saved = nil
	pcall(function()
		if readfile and isfile and isfile(BLOXY_CONFIG) then
			local data = HttpService:JSONDecode(readfile(BLOXY_CONFIG))
			saved = type(data) == "table" and type(data.Choices) == "table" and data.Choices.Forcefield or nil
		end
	end)
	print("[2012 ForceField] Installed. Bloxy's saved forcefield: " .. tostring(saved or "none"))
end
