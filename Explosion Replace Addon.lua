-- (Addtion-Scripts copy of the Explosion Replace Addon gist: 2006 / 2007 are the gist's own; 2010 and 2013 are Retro
-- Studio's old explosions (its "2009" and "2012" templates, how it fires them and its three textures), 2010 in the
-- colours of the user's 2010 recording, 2013 fading darker and a bit quicker; the explosion step put on the "old
-- particles" question before the Particles addon)
-- [[ EXPLOSION PICKER WIZARD STEP ]]
-- Run AFTER the main Bloxy Paradox script.

task.spawn(function()
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")
	local SoundService = game:GetService("SoundService")

	local CONFIG_FILE = "BloxyParadoxConfig.json"

	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui", 15)
	local sg = pg:WaitForChild("BloxyParadoxProject", 15)

	local clickSfx = Instance.new("Sound")
	clickSfx.SoundId = "rbxassetid://12221967"
	clickSfx.Volume = 0.6
	clickSfx.Parent = SoundService
	local function playClick() clickSfx:Stop() clickSfx:Play() end

	------------------------------------------------------------
	-- EXPLOSION SCRIPTS
	------------------------------------------------------------
	local SCRIPT_NORMAL = [==[
if _G.BP_ExplosionHook then pcall(function() _G.BP_ExplosionHook:Disconnect() end) end
_G.BP_ExplosionHook = nil
print("[Explosion] Normal style (default Roblox).")
]==]

	local SCRIPT_2006 = [==[
if _G.BP_ExplosionHook then pcall(function() _G.BP_ExplosionHook:Disconnect() end) end
local Debris = game:GetService("Debris")
local NEON = Enum.Material.Neon
local RED = BrickColor.new("Really red")
-- The ball has to stay neon red. Other addons change parts as they are added to the
-- workspace (Hammer stuff 1's "Plastic" turns every material into SmoothPlastic, and the
-- old-colors limiters snap colors), so the ball puts its own material and color back
-- whenever something else changes them.
local function lockLook(part)
    local fixing = false
    local function restore()
        if fixing or not part.Parent then return end
        fixing = true
        pcall(function()
            if part.Material ~= NEON then part.Material = NEON end
            if part.MaterialVariant ~= "" then part.MaterialVariant = "" end
            if part.BrickColor ~= RED then part.BrickColor = RED end
        end)
        fixing = false
    end
    part:GetPropertyChangedSignal("Material"):Connect(restore)
    part:GetPropertyChangedSignal("MaterialVariant"):Connect(restore)
    part:GetPropertyChangedSignal("Color"):Connect(restore)
end
_G.BP_ExplosionHook = workspace.DescendantAdded:Connect(function(ex)
    if ex:IsA("Explosion") then
        ex.Visible = false
        local exPart = Instance.new("Part")
        exPart.Name = "BP_Explosion2006"
        local diameter = math.max(ex.BlastRadius * 2, 4)
        exPart.Size = Vector3.new(diameter, diameter, diameter)
        exPart.Shape = Enum.PartType.Ball
        exPart.BrickColor = RED
        exPart.Material = NEON
        exPart.TopSurface = Enum.SurfaceType.Smooth
        exPart.BottomSurface = Enum.SurfaceType.Smooth
        exPart.LeftSurface = Enum.SurfaceType.Smooth
        exPart.RightSurface = Enum.SurfaceType.Smooth
        exPart.FrontSurface = Enum.SurfaceType.Smooth
        exPart.BackSurface = Enum.SurfaceType.Smooth
        exPart.CastShadow = false
        exPart.Position = ex.Position
        exPart.CanCollide = false
        exPart.CanTouch = false
        exPart.CanQuery = false
        exPart.Anchored = true
        exPart:SetAttribute("BP_KeepMaterial", true)
        lockLook(exPart)
        exPart.Parent = workspace
        Debris:AddItem(exPart, 0.2)
    end
end)
print("[Explosion] 2006 style LOADED and HOOKED.")
]==]

	local SCRIPT_2007 = [==[
if _G.BP_ExplosionHook then pcall(function() _G.BP_ExplosionHook:Disconnect() end) end
local FORCE_RETRO_EXPLOSIONS = false
local classicExp = Instance.new("ParticleEmitter")
classicExp.Name = "ClassicExp"
classicExp.Enabled = false
classicExp.LightEmission = 1
classicExp.Rate = 500
classicExp.Speed = NumberRange.new(20, 25)
classicExp.SpreadAngle = Vector2.new(360, 360)
classicExp.Lifetime = NumberRange.new(0.3, 0.5)
classicExp.Texture = "rbxassetid://334788053"
classicExp.ZOffset = 3
classicExp.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(1, Color3.new(0.498039, 0.498039, 0.498039))
})
classicExp.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 3, 1.1875),
	NumberSequenceKeypoint.new(0.75, 2.62, 0),
	NumberSequenceKeypoint.new(1, 0, 0)
})
classicExp.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0, 0),
	NumberSequenceKeypoint.new(0.993111, 0.1625, 0),
	NumberSequenceKeypoint.new(1, 1, 0)
})
local baseExpAdorn = Instance.new("Part")
baseExpAdorn.Name = "ExplosionAdorn"
baseExpAdorn.Anchored = true
baseExpAdorn.CanCollide = false
baseExpAdorn.Locked = true
baseExpAdorn.Transparency = 1
baseExpAdorn.Size = Vector3.new(0.05, 0.05, 0.05)
local function onDescendantAdded(exp)
	if exp:IsA("Explosion") then
		local cf = CFrame.new(exp.Position)
		local expAdorn = baseExpAdorn:Clone()
		local lifeTime = 1.5
		exp.Visible = false
		if FORCE_RETRO_EXPLOSIONS then
			local expObj = Instance.new("SphereHandleAdornment")
			expObj.Adornee = expAdorn
			expObj.Radius = exp.BlastRadius
			expObj.Color3 = Color3.new(1, 0, 0)
			expObj.CFrame = CFrame.new()
			expObj.Parent = expAdorn
			lifeTime = 1
			if exp.BlastRadius > 1 then
				lifeTime = lifeTime - (1 / exp.BlastRadius)
			end
		else
			local e = classicExp:Clone()
			e.Parent = expAdorn
			task.spawn(function()
				for i = 1, 8 do
					if not e or not e.Parent then break end
					e:Emit(100)
					task.wait(0.125)
				end
			end)
		end
		expAdorn.CFrame = cf
		expAdorn.Parent = workspace.CurrentCamera
		task.delay(lifeTime, function()
			if expAdorn then expAdorn:Destroy() end
		end)
	end
end
_G.BP_ExplosionHook = workspace.DescendantAdded:Connect(onDescendantAdded)
for _, desc in pairs(workspace:GetDescendants()) do
	if desc:IsA("Explosion") then task.spawn(onDescendantAdded, desc) end
end
print("[Explosion] 2007 style LOADED and HOOKED.")
]==]

	-- (Addtion-Scripts) 2010 and 2013: RETRO STUDIO's old explosions (its Engine.Rendering.Explosion: the "2009"
	-- template for 2008-2011 places, the "2012" one for 2012-2013). The way it fires them is copied as it is: the
	-- explosion's own look hidden, a cloud of puffs (100 of them; a single one for a small blast of radius 2 or
	-- less), BlastRadius x 2 pale clouds, and from radius 4 a fire cloud that keeps going for a tenth of a second per
	-- stud of radius (at most a second). Fired again if the explosion moves, gone 1.5 s after the fire stops. Its
	-- three textures: the fire cloud, the pale cloud and the white puff. Each emitter's sizes, colours and timings
	-- are ours (its templates weren't in what was decompiled): 2010 bright and creamy, as in the 2010 recording,
	-- 2013 more orange and fading darker, a bit quicker.
	local RETRO_EXPLOSION = [==[
if _G.BP_ExplosionHook then pcall(function() _G.BP_ExplosionHook:Disconnect() end) end
_G.BP_ExplosionHook = nil
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TEX_FIRE = "rbxassetid://4686786944"  -- orange / red / yellow fire cloud
local TEX_CLOUD = "rbxassetid://2306293207" -- pale cream cloud
local TEX_PUFF = "rbxassetid://4686802296"  -- white puff
local BOOM = "rbxassetid://12222084"

local function colours(list)
	local keys = {}
	for i, k in ipairs(list) do keys[i] = ColorSequenceKeypoint.new(k[1], Color3.fromRGB(k[2], k[3], k[4])) end
	return ColorSequence.new(keys)
end
local function numbers(list)
	local keys = {}
	for i, k in ipairs(list) do keys[i] = NumberSequenceKeypoint.new(k[1], k[2]) end
	return NumberSequence.new(keys)
end

-- one of the template's emitters. s = the size of this explosion (1 for a BlastRadius of 4, the default)
local function emitter(parent, name, texture, look, s)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = texture
	e.Color = colours(look.color)
	e.LightEmission = look.glow
	e.LightInfluence = 0
	e.Size = numbers({ { 0, look.size[1] * s }, { 0.3, look.size[2] * s }, { 1, look.size[3] * s } })
	e.Transparency = numbers(look.fade)
	e.Lifetime = NumberRange.new(look.life[1], look.life[2])
	e.Speed = NumberRange.new(look.speed[1] * s, look.speed[2] * s)
	e.Drag = look.drag
	e.Acceleration = Vector3.new(0, look.rise or 0, 0)
	e.Rate = look.rate or 0
	e.Rotation = NumberRange.new(-180, 180)
	e.RotSpeed = NumberRange.new(-look.spin, look.spin)
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(180, 180)
	e.ZOffset = look.z or 0
	e.Enabled = false
	e.Parent = parent
	return e
end

local function addExplosion(exp)
	local blastRadius = exp.BlastRadius
	exp.Visible = false
	local s = math.clamp(blastRadius / 4, 0.5, 3)
	local clone = Instance.new("Part")
	clone.Name = "Effect"
	clone.Archivable = false
	clone.Anchored = true
	clone.CanCollide = false
	clone.CanQuery = false
	clone.CanTouch = false
	clone.CastShadow = false
	clone.Transparency = 1
	clone.Size = Vector3.new(1, 1, 1) * math.max(0.5, s)
	clone.Position = exp.Position
	clone.Parent = Workspace.CurrentCamera or Workspace -- (only on your screen)
	local boom = Instance.new("Sound")
	boom.SoundId = BOOM
	boom.Volume = 1
	boom.Parent = clone
	boom:Play()

	local e1 = emitter(clone, "Explosion1", TEX_FIRE, STYLE.fire, s)
	local e2 = emitter(clone, "Explosion2", TEX_CLOUD, STYLE.cloud, s)
	local e3 = emitter(clone, "Explosion3", TEX_PUFF, STYLE.puff, s)
	local many = math.min(math.floor(blastRadius * 2), 60) -- (BlastRadius x 2, as Retro Studio; kept sane for huge ones)

	local function shootInitialParticles()
		if blastRadius > 2 then
			e3:Emit(100)
			e2:Emit(many)
			if blastRadius >= 4 then
				e1.Enabled = true
				e1:Emit(many)
			end
		else
			e3:Emit(1)
		end
	end
	exp:GetPropertyChangedSignal("Position"):Connect(function()
		if clone.Parent then
			clone.Position = exp.Position
			shootInitialParticles()
		end
	end)
	shootInitialParticles()

	task.delay(math.min(blastRadius * 0.1, 1), function()
		for _, child in ipairs(clone:GetChildren()) do
			if child:IsA("ParticleEmitter") then child.Enabled = false end
		end
		Debris:AddItem(clone, 1.5)
	end)
end

local function processItem(item)
	if item:IsA("Explosion") then
		pcall(addExplosion, item)
	end
end
for _, item in ipairs(Workspace:GetDescendants()) do processItem(item) end
_G.BP_ExplosionHook = Workspace.DescendantAdded:Connect(function(item)
	if item:IsA("Explosion") then task.defer(processItem, item) end
end)
print("[Explosion] " .. STYLE.name .. " style (Retro Studio's " .. STYLE.template .. ") LOADED and HOOKED.")
]==]

	-- 2010: Retro Studio's "2009" template. Bright and glowing, cream white to pale yellow, orange at the edges, then
	-- the salmon-pink haze of the 2010 recording
	local SCRIPT_2010 = [==[
local STYLE = {
	name = "2010", template = "2009 explosion",
	puff = { color = { { 0, 255, 252, 225 }, { 0.25, 250, 238, 172 }, { 0.55, 242, 170, 80 }, { 0.8, 232, 120, 100 }, { 1, 225, 100, 95 } },
		glow = 0.75, size = { 0.5, 1.1, 1.5 }, fade = { { 0, 0 }, { 0.55, 0.1 }, { 1, 1 } },
		life = { 0.45, 0.85 }, speed = { 6, 16 }, drag = 5, spin = 90, z = 2 },
	cloud = { color = { { 0, 255, 255, 240 }, { 0.3, 255, 240, 195 }, { 0.65, 245, 180, 125 }, { 1, 230, 120, 105 } },
		glow = 0.55, size = { 1.4, 3.2, 4.2 }, fade = { { 0, 0.05 }, { 0.5, 0.2 }, { 1, 1 } },
		life = { 0.6, 1.1 }, speed = { 2, 7 }, drag = 4, spin = 40, rise = 2, z = 1 },
	fire = { color = { { 0, 255, 255, 255 }, { 0.4, 255, 225, 185 }, { 1, 235, 140, 110 } },
		glow = 0.65, size = { 1.2, 2.6, 3.4 }, fade = { { 0, 0 }, { 0.6, 0.25 }, { 1, 1 } },
		life = { 0.5, 0.9 }, speed = { 1, 5 }, drag = 3, spin = 60, rate = 25, rise = 3, z = 0 },
}
]==] .. RETRO_EXPLOSION

	-- 2013: Retro Studio's "2012" template. More orange, and darker at the end (dark red, not black), a bit quicker
	local SCRIPT_2013 = [==[
local STYLE = {
	name = "2013", template = "2012 explosion",
	puff = { color = { { 0, 255, 215, 120 }, { 0.2, 245, 150, 45 }, { 0.5, 200, 90, 25 }, { 0.8, 120, 40, 14 }, { 1, 60, 16, 6 } },
		glow = 0.45, size = { 0.5, 1.1, 1.6 }, fade = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
		life = { 0.35, 0.7 }, speed = { 7, 18 }, drag = 5, spin = 90, z = 2 },
	cloud = { color = { { 0, 255, 230, 170 }, { 0.3, 235, 140, 55 }, { 0.65, 150, 60, 22 }, { 1, 70, 22, 10 } },
		glow = 0.3, size = { 1.4, 3.2, 4.4 }, fade = { { 0, 0.05 }, { 0.45, 0.15 }, { 1, 1 } },
		life = { 0.5, 0.9 }, speed = { 2, 8 }, drag = 4, spin = 40, rise = 3, z = 1 },
	fire = { color = { { 0, 255, 255, 255 }, { 0.35, 255, 190, 120 }, { 0.7, 190, 80, 35 }, { 1, 90, 28, 12 } },
		glow = 0.4, size = { 1.2, 2.6, 3.6 }, fade = { { 0, 0 }, { 0.55, 0.2 }, { 1, 1 } },
		life = { 0.4, 0.8 }, speed = { 1, 6 }, drag = 3, spin = 60, rate = 25, rise = 4, z = 0 },
}
]==] .. RETRO_EXPLOSION

	local SCRIPTS = {
		["2006"] = SCRIPT_2006,
		["2007"] = SCRIPT_2007,
		["2010"] = SCRIPT_2010,
		["2013"] = SCRIPT_2013,
		["Normal"] = SCRIPT_NORMAL,
	}

	local function runExplosionScript(style)
		local src = SCRIPTS[style]
		if not src then return end
		print("[Explosion] Loading style: " .. style)
		local fn, err = loadstring(src)
		if fn then
			local ok, e = pcall(fn)
			if not ok then warn("[Explosion] Runtime error: " .. tostring(e)) end
		else
			warn("[Explosion] loadstring failed: " .. tostring(err))
		end
	end

	local function saveStyle(style)
		local cfg = {}
		if readfile and isfile and isfile(CONFIG_FILE) then
			pcall(function() cfg = HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
		end
		if type(cfg) ~= "table" then cfg = {} end
		cfg.explosionStyle = style
		if writefile then
			pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(cfg)) end)
		end
	end

	local function makeButton(text, pos, width, parent)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, width, 0, 32)
		btn.Position = pos
		btn.Text = text
		btn.Font = Enum.Font.Legacy
		btn.TextScaled = true
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		btn.BorderColor3 = Color3.fromRGB(0, 0, 0)
		btn.TextColor3 = Color3.fromRGB(0, 0, 0)
		btn.ZIndex = 5
		btn.Parent = parent

		local c = Instance.new("UITextSizeConstraint", btn)
		c.MaxTextSize = 14
		c.MinTextSize = 8

		btn.MouseEnter:Connect(function()
			if btn.Active then
				btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
				btn.TextColor3 = Color3.fromRGB(255, 255, 255)
				btn.BorderColor3 = Color3.fromRGB(255, 0, 0)
			end
		end)
		btn.MouseLeave:Connect(function()
			btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			btn.TextColor3 = Color3.fromRGB(0, 0, 0)
			btn.BorderColor3 = Color3.fromRGB(0, 0, 0)
		end)

		return btn
	end

	local handled = setmetatable({}, {__mode = "k"})
	local busy = false

	-- The explosion step goes on Bloxy's "old particles" question BEFORE the Particles addon turns that
	-- question into its own step (after an explosion is picked, the question is put back for it). So a
	-- new question is looked at the moment it is added (it is built in one go, so it is complete a
	-- moment later), not by going through all of Bloxy's windows on every frame.
	local function tryFrame(frame)
		if frame:IsA("Frame") and not handled[frame] and not busy then
			local titleLabel, yesBtn, noBtn

			for _, d in ipairs(frame:GetDescendants()) do
				if d:IsA("TextLabel") and type(d.Text) == "string" then
					local t = d.Text:lower()
					if t:find("particle", 1, true) or t:find("explosion", 1, true) then
						titleLabel = d
					end
				end
				if d:IsA("TextButton") then
					if d.Text == "Yes" then yesBtn = d end
					if d.Text == "No" then noBtn = d end
				end
			end

			if titleLabel and yesBtn and noBtn then
				handled[frame] = true
				busy = true
				print("[Explosion Step] Frame detected: " .. titleLabel.Text)

				local originalTitle = titleLabel.Text

				titleLabel.Text = "Choose your explosion style:"
				yesBtn.Visible = false
				noBtn.Visible = false

				local opts = {
					{text = "2006",   x = 14,  width = 60, style = "2006"},
					{text = "2007",   x = 78,  width = 60, style = "2007"},
					{text = "2010",   x = 142, width = 60, style = "2010"},
					{text = "2013",   x = 206, width = 60, style = "2013"},
					{text = "Normal", x = 270, width = 76, style = "Normal"},
				}

				local myButtons = {}

				for _, opt in ipairs(opts) do
					local btn = makeButton(opt.text, UDim2.new(0, opt.x, 0, 45), opt.width, frame)
					table.insert(myButtons, btn)

					btn.MouseButton1Click:Connect(function()
						playClick()
						print("[Explosion] Picked " .. opt.style)
						saveStyle(opt.style)

						-- Run the script
						runExplosionScript(opt.style)

						-- Slide the frame up and out
						local upTween = TweenService:Create(
							frame,
							TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
							{ Position = UDim2.new(0.5, -180, 0, -250) }
						)
						upTween:Play()
						upTween.Completed:Wait()

						for _, b in ipairs(myButtons) do
							if b and b.Parent then b:Destroy() end
						end
						myButtons = {}

						titleLabel.Text = originalTitle
						yesBtn.Visible = true
						noBtn.Visible = true

						TweenService:Create(
							frame,
							TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
							{ Position = UDim2.new(0.5, -180, 0.5, -42) }
						):Play()

						task.wait(0.5)
						busy = false
					end)
				end

				return true
			end
		end
		return false
	end

	sg.ChildAdded:Connect(function(frame)
		task.defer(function() pcall(tryFrame, frame) end)
	end)
	-- (questions already there, and any missed: looked at twice a second)
	local lookAcc = 0
	RunService.RenderStepped:Connect(function(dt)
		if not sg or not sg.Parent then return end
		lookAcc = lookAcc + (dt or 0)
		if lookAcc < 0.5 then return end
		lookAcc = 0
		for _, frame in ipairs(sg:GetChildren()) do
			if tryFrame(frame) then return end
		end
	end)

	-- The saved style is only used by itself with Bloxy's "skip setup" on (no setup to pick it in), like the
	-- terrain and 2007 animation steps; otherwise the explosion is the one picked in the setup.
	local savedStyle, skipSetup = nil, false
	if readfile and isfile and isfile(CONFIG_FILE) then
		pcall(function()
			local cfg = HttpService:JSONDecode(readfile(CONFIG_FILE))
			if type(cfg) == "table" then
				savedStyle = cfg.explosionStyle
				skipSetup = cfg.isSkipped == true
			end
		end)
	end
	if skipSetup and savedStyle and savedStyle ~= "" then
		task.spawn(function()
			runExplosionScript(savedStyle)
		end)
	end

	print("[Explosion Step] Loaded.")
end)