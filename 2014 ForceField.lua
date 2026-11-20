--========================================================
-- 2014 FORCEFIELD (Addtion-Scripts) — adds "2014" to Bloxy's "choose your forcefield" step
-- The 2014 client's forcefield, from its two particle systems (content/particles, the files the user gave):
--   * forceFieldBeam: light beams rising from a ring around your feet. A ring 2 to 2.5 studs out, 2 studs under the
--     middle of the body; 20 a second going straight up at 2 to 5 studs a second, each one half a stud wide and 2
--     tall, standing upright; it fades in over its first second and out over its second (2 s each).
--   * forceFieldRadial: big soft flares at the middle of the body. 2 a second, 5 studs and growing 6 a second, turned
--     any way and spinning (4 to 100 degrees a second), fading out over their 2 seconds.
-- Both glow (added light, "PE/lensflare"). The glow picture is this repo's assets/Roblox-loading-glow.png (a soft
-- white glow like the client's own glow.png, which no archive has); Roblox's sparkle texture if it can't be had.
-- Roblox's own forcefield is hidden while it shows. On every character with a forcefield (on your screen).
--
-- "2014" is a fourth button next to 2008 / 2012 / normal: picking it moves the setup on exactly as "normal" does (so no
-- Bloxy forcefield script runs) while this one starts. Picking one of Bloxy's own turns it off. The pick is saved
-- (BloxyForcefield2014Choice.json), so with Bloxy's "skip setup" box ticked it starts by itself.
-- By hand: getgenv().Forcefield2014.Start() / .Stop() / .IsRunning()
--========================================================

do
	local Players = game:GetService("Players")
	local HttpService = game:GetService("HttpService")
	local RunService = game:GetService("RunService")
	local CoreGui = game:GetService("CoreGui")

	local Env = (getgenv and getgenv()) or _G
	if Env.Forcefield2014Cleanup then pcall(Env.Forcefield2014Cleanup) end

	local SAVE_FILE = "BloxyForcefield2014Choice.json"
	local BLOXY_CONFIG = "BloxyParadoxConfig.json"
	local BLOXY_GUI = "BloxyParadoxProject"
	local STEP_TEXT = "choose your forcefield"
	local BUTTON_NAME = "Forcefield2014Button"
	local EFFECT_NAME = "Forcefield2014"
	local GLOW_URL = "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/assets/Roblox-loading-glow.png"
	local GLOW_FILE = "AddtionAssets/Roblox-loading-glow.png"
	local GLOW_FALLBACK = "rbxasset://textures/particles/sparkles_main.dds"
	local COLOR = Color3.fromRGB(200, 225, 255) -- (a slight blue: the glow picture itself is white)

	-- the particle files' numbers
	local BEAM = {
		rate = 20, lifetime = 2, speedMin = 2, speedMax = 5,
		ringOuter = 2.5, ringInner = 2.5 * 0.8, below = 2, -- (width / height 5, inner 0.8; position 0 -2 0)
		width = 0.5, height = 2,
	}
	local RADIAL = { rate = 2, lifetime = 2, size = 5, grow = 6, spinMin = 4, spinMax = 100 }

	local alive, running = true, false
	local connections = {}
	local engineConns = {}
	local effects = {} -- character -> { parts = {...}, ff = ForceField, conns = {...} }
	local hidden = setmetatable({}, { __mode = "k" }) -- forcefields this hid
	local watched = {}
	local handled = setmetatable({}, { __mode = "k" })
	local glowImage = GLOW_FALLBACK

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
	-- the glow picture (this repo's, cached on the executor's disk)
	------------------------------------------------------------
	task.spawn(function()
		local getAsset = (type(getcustomasset) == "function" and getcustomasset)
			or (type(getsynasset) == "function" and getsynasset) or nil
		if not (getAsset and type(writefile) == "function" and type(isfile) == "function") then return end
		pcall(function()
			if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("AddtionAssets") then
				makefolder("AddtionAssets")
			end
			if not isfile(GLOW_FILE) then
				local data = game:HttpGet(GLOW_URL)
				if type(data) == "string" and #data > 64 and string.sub(data, 2, 4) == "PNG" then writefile(GLOW_FILE, data) end
			end
			if isfile(GLOW_FILE) then
				local id = getAsset(GLOW_FILE)
				if type(id) == "string" and id ~= "" then
					glowImage = id
					for _, entry in pairs(effects) do
						for _, e in ipairs(entry.emitters) do e.Texture = id end
					end
				end
			end
		end)
	end)

	------------------------------------------------------------
	-- THE EFFECT
	------------------------------------------------------------
	local function bodyOf(character)
		return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
			or character:FindFirstChild("UpperTorso")
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
		beams.Texture = glowImage
		beams.Color = ColorSequence.new(COLOR)
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
		-- ColourFader2: the alpha goes up 1 a second for the first second, then down 1 a second
		beams.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
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
		radial.Texture = glowImage
		radial.Color = ColorSequence.new(COLOR)
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
		-- ColourFader alpha -0.5: from whole to gone over the 2 seconds
		radial.Transparency = NumberSequence.new(0, 1)
		radial.LockedToPart = false
		radial.Parent = middle
		middle.Parent = body
		table.insert(entry.parts, middle)
		table.insert(entry.emitters, radial)

		connect(entry.conns, RunService.Heartbeat, function()
			-- (the forcefield gone, however it went: the 2014 one goes too)
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

	local function watchPlayer(player)
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
		print("[2014 ForceField] On: the 2014 forcefield (beams and flares) on every character with a forcefield.")
	end
	function engine.Stop()
		if not running then return end
		running = false
		disconnectAll(engineConns)
		local list = {}
		for character in pairs(effects) do table.insert(list, character) end
		for _, character in ipairs(list) do removeEffect(character) end
		print("[2014 ForceField] Off.")
	end

	Env.Forcefield2014 = { Start = engine.Start, Stop = engine.Stop, IsRunning = engine.IsRunning }
	Env.Forcefield2014Cleanup = function()
		alive = false
		disconnectAll(connections)
		table.clear(watched)
		engine.Stop()
		Env.Forcefield2014 = nil
	end

	------------------------------------------------------------
	-- SAVE / LOAD
	------------------------------------------------------------
	local function readJson(file)
		if not (readfile and isfile) then return nil end
		local ok, data = pcall(function()
			if isfile(file) then return HttpService:JSONDecode(readfile(file)) end
		end)
		return ok and type(data) == "table" and data or nil
	end
	local function loadChoice()
		local data = readJson(SAVE_FILE)
		return data ~= nil and data.Forcefield2014 == true
	end
	local function saveChoice(on)
		if not writefile then return end
		pcall(function() writefile(SAVE_FILE, HttpService:JSONEncode({ Forcefield2014 = on })) end)
	end
	local function bloxySkipOn()
		local data = readJson(BLOXY_CONFIG)
		return data ~= nil and data.isSkipped == true
	end

	------------------------------------------------------------
	-- THE "2014" BUTTON ON BLOXY'S FORCEFIELD STEP
	------------------------------------------------------------
	local function press(btn)
		if not btn or not btn.Parent then return false end
		if firesignal and pcall(firesignal, btn.MouseButton1Click) then return true end
		if getconnections then
			local ok, conns = pcall(getconnections, btn.MouseButton1Click)
			if ok and type(conns) == "table" and #conns > 0 then
				local fired = false
				for _, conn in ipairs(conns) do
					local fn = conn.Function
					if fn then
						task.spawn(pcall, fn)
						fired = true
					elseif conn.Fire then
						if pcall(function() conn:Fire() end) then fired = true end
					end
				end
				if fired then return true end
			end
		end
		return false
	end

	local pressing = false

	local function findStepLabel(frame)
		for _, d in ipairs(frame:GetChildren()) do
			if d:IsA("TextLabel") and string.find(string.lower(d.Text or ""), STEP_TEXT, 1, true) then return d end
		end
		return nil
	end
	local function buttonWithText(frame, text)
		for _, d in ipairs(frame:GetChildren()) do
			if d:IsA("TextButton") and d.Text == text and d.Name ~= BUTTON_NAME then return d end
		end
		return nil
	end

	local function makeButton(frame, reference)
		local btn = Instance.new("TextButton")
		btn.Name = BUTTON_NAME
		btn.Size = reference.Size
		btn.Position = reference.Position
		btn.Text = "2014"
		btn.Font = Enum.Font.Legacy
		btn.TextScaled = true
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		btn.BorderColor3 = Color3.fromRGB(0, 0, 0)
		btn.TextColor3 = Color3.fromRGB(0, 0, 0)
		btn.ZIndex = reference.ZIndex
		btn.Parent = frame
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = 16
		constraint.MinTextSize = 8
		constraint.Parent = btn
		btn.MouseEnter:Connect(function()
			btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			btn.BorderColor3 = Color3.fromRGB(255, 0, 0)
		end)
		btn.MouseLeave:Connect(function()
			btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			btn.TextColor3 = Color3.fromRGB(0, 0, 0)
			btn.BorderColor3 = Color3.fromRGB(0, 0, 0)
		end)
		return btn
	end

	local function addButton(frame)
		if frame:FindFirstChild(BUTTON_NAME) then return true end
		if not findStepLabel(frame) then return false end
		local b2008 = buttonWithText(frame, "2008(r6 only)")
		local b2012 = buttonWithText(frame, "2012")
		local bNormal = buttonWithText(frame, "normal")
		if not (b2008 and b2012 and bNormal) then return false end

		local btn = makeButton(frame, b2012)
		-- four buttons in the box that held three: 2008, 2012, 2014, normal
		local order = { b2008, b2012, btn, bNormal }
		local margin, gap = 10, 10
		local width = math.floor((frame.Size.X.Offset - margin * 2 - gap * (#order - 1)) / #order)
		local y = b2012.Position.Y.Offset
		for i, b in ipairs(order) do
			b.Size = UDim2.new(0, width, 0, b.Size.Y.Offset)
			b.Position = UDim2.new(0, margin + (i - 1) * (width + gap), 0, y)
		end

		-- one of Bloxy's own: the 2014 forcefield goes off
		for _, other in ipairs({ b2008, b2012, bNormal }) do
			other.MouseButton1Click:Connect(function()
				if pressing or not alive then return end
				saveChoice(false)
				engine.Stop()
			end)
		end

		local picked = false
		btn.MouseButton1Click:Connect(function()
			if picked or not alive then return end
			picked = true
			saveChoice(true)
			if not bloxySkipOn() then engine.Start() end
			pressing = true
			local pressed = press(bNormal) -- (moves the setup on as "normal": no Bloxy forcefield)
			task.delay(0.25, function() pressing = false end)
			if not pressed then
				warn("[2014 ForceField] Couldn't move the setup on: press normal to continue (2014 is picked).")
				picked = false
			end
		end)
		return true
	end

	local function checkFrame(frame)
		if not alive or handled[frame] or not frame:IsA("Frame") then return end
		handled[frame] = true
		task.spawn(function()
			for _ = 1, 30 do
				if not alive or not frame.Parent then return end
				if addButton(frame) then return end
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
		-- "skip setup" ticked: Bloxy applies its saved choices, this the saved 2014 forcefield
		if bloxySkipOn() and loadChoice() then engine.Start() end
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

	print("[2014 ForceField] Installed. Saved choice: " .. (loadChoice() and "2014" or "not 2014"))
end
