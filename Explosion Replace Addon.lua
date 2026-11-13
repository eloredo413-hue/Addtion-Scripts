-- (Addtion-Scripts copy of the Explosion Replace Addon gist: 2010 and 2013 made to look like recordings of them)
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

	-- 2010: a white-hot flash that spreads out wide and fades through yellow and orange to red in under
	-- a second, lighting what is around it red-orange (from a 2010 recording). No sparks, no smoke.
	local SCRIPT_2010 = [==[
if _G.BP_ExplosionHook then pcall(function() _G.BP_ExplosionHook:Disconnect() end) end
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local GLOW_TEXTURE = "rbxthumb://type=Asset&id=2825829181&w=420&h=420"
local function spawnRetroExplosion(pos, scale)
	local attachment = Instance.new("Attachment")
	attachment.Position = pos
	attachment.Parent = Workspace.Terrain
	local boomSound = Instance.new("Sound")
	boomSound.SoundId = "rbxassetid://12222084"
	boomSound.Volume = 1
	boomSound.Parent = attachment
	boomSound:Play()
	-- white in the middle, then pale yellow, orange and red as it fades (additive, so it glows)
	local flashColors = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 255, 245)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 240, 160)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(255, 165, 90)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(235, 70, 45))
	})
	local function makeEmit(name, size, speedMin, speedMax, lifeMin, lifeMax)
		local emit = Instance.new("ParticleEmitter")
		emit.Name = name
		emit.Texture = GLOW_TEXTURE
		emit.Color = flashColors
		emit.Enabled = false
		emit.LightEmission = 1
		emit.LightInfluence = 0
		pcall(function() emit.Brightness = 2 end)
		emit.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, size * 0.6),
			NumberSequenceKeypoint.new(0.25, size),
			NumberSequenceKeypoint.new(1, size * 1.3)
		})
		emit.Rotation = NumberRange.new(-360, 360)
		emit.RotSpeed = NumberRange.new(-60, 60)
		emit.Speed = NumberRange.new(speedMin, speedMax)
		emit.Lifetime = NumberRange.new(lifeMin, lifeMax)
		emit.SpreadAngle = Vector2.new(360, 360)
		emit.Drag = 5
		emit.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.45, 0.1),
			NumberSequenceKeypoint.new(1, 1)
		})
		emit.ZOffset = 2
		emit.Parent = attachment
		return emit
	end
	local core = makeEmit("FlashCore", 7 * scale, 1 * scale, 5 * scale, 0.45, 0.7)
	local wide = makeEmit("FlashWide", 6 * scale, 8 * scale, 16 * scale, 0.4, 0.75)
	core:Emit(math.floor(14 * math.clamp(scale, 1, 2)))
	wide:Emit(math.floor(22 * math.clamp(scale, 1, 2)))
	-- the light it throws on what is around it, fading with it
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 70)
	light.Brightness = 8
	light.Range = math.clamp(10 * scale, 12, 60)
	light.Shadows = false
	light.Parent = attachment
	TweenService:Create(light, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	Debris:AddItem(attachment, 3)
end
local function processItem(item)
	if item:IsA("Explosion") then
		pcall(function()
			item.Visible = false
			spawnRetroExplosion(item.Position, math.max(item.BlastRadius / 6, 1))
		end)
	end
end
for _, item in ipairs(Workspace:GetDescendants()) do processItem(item) end
_G.BP_ExplosionHook = Workspace.DescendantAdded:Connect(function(item)
	if item:IsA("Explosion") then task.defer(processItem, item) end
end)
print("[Explosion] 2010 style LOADED and HOOKED.")
]==]

	-- 2013: a thick, bright orange-red cloud of puffs that billows up for most of a second, then thins
	-- into a darker red haze and is gone after about a second and a half (from a 2013 recording).
	-- Not lit by the scene (it is as bright in the shade), not glowing.
	local SCRIPT_2013 = [==[
if _G.BP_ExplosionHook then pcall(function() _G.BP_ExplosionHook:Disconnect() end) end
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local CLOUD_TEXTURE = "rbxthumb://type=Asset&id=2825829181&w=420&h=420"
local function spawnRetroExplosion(pos, scale)
	local attachment = Instance.new("Attachment")
	attachment.Position = pos
	attachment.Parent = Workspace.Terrain
	local boomSound = Instance.new("Sound")
	boomSound.SoundId = "rbxassetid://12222084"
	boomSound.Volume = 1
	boomSound.Parent = attachment
	boomSound:Play()
	local cloudColors = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(235, 90, 50)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 75, 42)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(165, 50, 35))
	})
	local function makeEmit(name, size, speedMin, speedMax, lifeMin, lifeMax, colors, emission)
		local emit = Instance.new("ParticleEmitter")
		emit.Name = name
		emit.Texture = CLOUD_TEXTURE
		emit.Color = colors
		emit.Enabled = false
		emit.LightEmission = emission or 0
		emit.LightInfluence = 0
		emit.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, size * 0.5),
			NumberSequenceKeypoint.new(0.3, size),
			NumberSequenceKeypoint.new(1, size * 1.45)
		})
		emit.Rotation = NumberRange.new(-360, 360)
		emit.RotSpeed = NumberRange.new(-40, 40)
		emit.Speed = NumberRange.new(speedMin, speedMax)
		emit.Lifetime = NumberRange.new(lifeMin, lifeMax)
		emit.SpreadAngle = Vector2.new(360, 360)
		emit.Acceleration = Vector3.new(0, 4 * scale, 0) -- the cloud billows upward
		emit.Drag = 3
		emit.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.55, 0.05),
			NumberSequenceKeypoint.new(0.8, 0.55),
			NumberSequenceKeypoint.new(1, 1)
		})
		emit.ZOffset = 1
		emit.Parent = attachment
		return emit
	end
	local inner = makeEmit("CloudInner", 5 * scale, 1 * scale, 5 * scale, 1.0, 1.4, cloudColors)
	local outer = makeEmit("CloudOuter", 6 * scale, 5 * scale, 11 * scale, 0.9, 1.3, cloudColors)
	-- a few lighter puffs inside the cloud
	local spots = makeEmit("CloudSpots", 1.6 * scale, 2 * scale, 7 * scale, 0.5, 0.9, ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 160, 120)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 110, 80))
	}), 0.4)
	spots.ZOffset = 2
	local n = math.clamp(scale, 1, 2)
	inner:Emit(math.floor(16 * n))
	outer:Emit(math.floor(22 * n))
	spots:Emit(math.floor(5 * n))
	Debris:AddItem(attachment, 3)
end
local function processItem(item)
	if item:IsA("Explosion") then
		pcall(function()
			item.Visible = false
			spawnRetroExplosion(item.Position, math.max(item.BlastRadius / 6, 1))
		end)
	end
end
for _, item in ipairs(Workspace:GetDescendants()) do processItem(item) end
_G.BP_ExplosionHook = Workspace.DescendantAdded:Connect(function(item)
	if item:IsA("Explosion") then task.defer(processItem, item) end
end)
print("[Explosion] 2013 style LOADED and HOOKED.")
]==]

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

	-- The explosion question is looked for about 7 times a second, not every frame (it went through every
	-- one of Bloxy's windows and everything in them on every frame).
	local lookAcc = 0
	RunService.RenderStepped:Connect(function(dt)
		if not sg or not sg.Parent then return end
		lookAcc = lookAcc + (dt or 0)
		if lookAcc < 0.15 then return end
		lookAcc = 0

		for _, frame in ipairs(sg:GetChildren()) do
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

					return
				end
			end
		end
	end)

	local savedStyle
	if readfile and isfile and isfile(CONFIG_FILE) then
		pcall(function()
			local cfg = HttpService:JSONDecode(readfile(CONFIG_FILE))
			if type(cfg) == "table" and cfg.explosionStyle then
				savedStyle = cfg.explosionStyle
			end
		end)
	end
	if savedStyle and savedStyle ~= "" then
		task.spawn(function()
			runExplosionScript(savedStyle)
		end)
	end

	print("[Explosion Step] Loaded.")
end)