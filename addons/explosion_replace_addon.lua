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
_G.BP_ExplosionHook = workspace.DescendantAdded:Connect(function(ex)
    if ex:IsA("Explosion") then
        ex.Visible = false
        local exPart = Instance.new("Part")
        local diameter = math.max(ex.BlastRadius * 2, 4)
        exPart.Size = Vector3.new(diameter, diameter, diameter)
        exPart.Shape = Enum.PartType.Ball
        exPart.BrickColor = BrickColor.new("Really red")
        exPart.Material = Enum.Material.Neon
        exPart.TopSurface = Enum.SurfaceType.Smooth
        exPart.BottomSurface = Enum.SurfaceType.Smooth
        exPart.LeftSurface = Enum.SurfaceType.Smooth
        exPart.RightSurface = Enum.SurfaceType.Smooth
        exPart.FrontSurface = Enum.SurfaceType.Smooth
        exPart.BackSurface = Enum.SurfaceType.Smooth
        exPart.Position = ex.Position
        exPart.CanCollide = false
        exPart.Anchored = true
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

	local SCRIPT_2010 = [==[
if _G.BP_ExplosionHook then pcall(function() _G.BP_ExplosionHook:Disconnect() end) end
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local CLASSIC_SMOKE_URL = "rbxthumb://type=Asset&id=2825829181&w=420&h=420"
local ENGINE_SPARKLE_FALLBACK = "rbxasset://textures/particles/sparkles_main.dds"
local function spawnRetroExplosion(pos, scale)
	scale = (scale or 1) * 0.75
	local multiColorPalette = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 200, 50)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 110, 10)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(230, 40, 0)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(140, 10, 5))
	})
	local sparkPalette = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 230, 150)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 120, 30))
	})
	local attachment = Instance.new("Attachment")
	attachment.Position = pos
	attachment.Parent = Workspace.Terrain
	local boomSound = Instance.new("Sound")
	boomSound.SoundId = "rbxassetid://12222084"
	boomSound.Volume = 1
	boomSound.Parent = attachment
	boomSound:Play()
	local function makeEmit(name, sizeMult, speedRange, lifetimeRange, count)
		local emit = Instance.new("ParticleEmitter")
		emit.Name = name
		emit.Texture = CLASSIC_SMOKE_URL
		emit.Color = multiColorPalette
		emit.Enabled = false
		emit.LightEmission = 1
		emit.LightInfluence = 0
		local s = sizeMult * scale
		emit.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, s * 0.35),
			NumberSequenceKeypoint.new(0.2, s),
			NumberSequenceKeypoint.new(1, s * 1.25)
		})
		emit.Rotation = NumberRange.new(-360, 360)
		emit.RotSpeed = NumberRange.new(-120, 120)
		emit.Speed = NumberRange.new(speedRange.Min * scale, speedRange.Max * scale)
		emit.Lifetime = lifetimeRange
		emit.EmissionDirection = Enum.NormalId.Top
		emit.SpreadAngle = Vector2.new(360, 360)
		emit.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.6, 0.05),
			NumberSequenceKeypoint.new(1, 1)
		})
		emit.ZOffset = 1
		emit.Drag = 4
		emit.Parent = attachment
		return emit, count
	end
	local core, c1 = makeEmit("CoreMixed", 3.2, NumberRange.new(3, 8), NumberRange.new(0.7, 1.1), 22)
	local outer, c2 = makeEmit("OuterMixed", 4.0, NumberRange.new(8, 16), NumberRange.new(0.6, 1.2), 26)
	local burst, c3 = makeEmit("BurstMixed", 2.6, NumberRange.new(14, 24), NumberRange.new(0.5, 0.9), 18)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = ENGINE_SPARKLE_FALLBACK
	sparks.Color = sparkPalette
	sparks.Enabled = false
	sparks.LightEmission = 0.8
	sparks.LightInfluence = 0
	sparks.Speed = NumberRange.new(10 * scale, 32 * scale)
	sparks.Lifetime = NumberRange.new(0.4, 0.8)
	sparks.SpreadAngle = Vector2.new(360, 360)
	sparks.Drag = 2.5
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85 * scale),
		NumberSequenceKeypoint.new(1, 0)
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.75, 0.15),
		NumberSequenceKeypoint.new(1, 1)
	})
	sparks.ZOffset = 2
	sparks.Parent = attachment
	local density = math.clamp(scale, 0.8, 2.5)
	core:Emit(math.floor(c1 * density))
	outer:Emit(math.floor(c2 * density))
	burst:Emit(math.floor(c3 * density))
	sparks:Emit(math.floor(40 * density))
	Debris:AddItem(attachment, 4)
end
local function processItem(item)
	if item:IsA("Explosion") then
		pcall(function()
			item.Visible = false
			local exactScale = math.max(item.BlastRadius / 8, 1.15)
			spawnRetroExplosion(item.Position, exactScale)
		end)
	end
end
for _, item in ipairs(Workspace:GetDescendants()) do processItem(item) end
_G.BP_ExplosionHook = Workspace.DescendantAdded:Connect(function(item)
	task.defer(function() processItem(item) end)
end)
print("[Explosion] 2010 style LOADED and HOOKED.")
]==]

	local SCRIPT_2013 = [==[
if _G.BP_ExplosionHook then pcall(function() _G.BP_ExplosionHook:Disconnect() end) end
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local CLASSIC_SMOKE_URL = "rbxthumb://type=Asset&id=2825829181&w=420&h=420"
local ENGINE_SPARKLE_FALLBACK = "rbxasset://textures/particles/sparkles_main.dds"
local function spawnRetroExplosion(pos, scale)
	scale = (scale or 1) * 0.75
	local multiColorPalette = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(200, 100, 20)),
		ColorSequenceKeypoint.new(0.3, Color3.fromRGB(160, 60, 15)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(120, 30, 10)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(80, 10, 5))
	})
	local sparkPalette = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(220, 160, 80)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(180, 80, 30))
	})
	local attachment = Instance.new("Attachment")
	attachment.Position = pos
	attachment.Parent = Workspace.Terrain
	local boomSound = Instance.new("Sound")
	boomSound.SoundId = "rbxassetid://12222084"
	boomSound.Volume = 1
	boomSound.Parent = attachment
	boomSound:Play()
	local function makeEmit(name, sizeMult, speedRange, lifetimeRange, count)
		local emit = Instance.new("ParticleEmitter")
		emit.Name = name
		emit.Texture = CLASSIC_SMOKE_URL
		emit.Color = multiColorPalette
		emit.Enabled = false
		emit.LightEmission = 0
		emit.LightInfluence = 1
		local s = sizeMult * scale
		emit.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, s * 0.35),
			NumberSequenceKeypoint.new(0.2, s),
			NumberSequenceKeypoint.new(1, s * 1.25)
		})
		emit.Rotation = NumberRange.new(-360, 360)
		emit.RotSpeed = NumberRange.new(-120, 120)
		emit.Speed = NumberRange.new(speedRange.Min * scale, speedRange.Max * scale)
		emit.Lifetime = lifetimeRange
		emit.EmissionDirection = Enum.NormalId.Top
		emit.SpreadAngle = Vector2.new(360, 360)
		emit.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.6, 0.05),
			NumberSequenceKeypoint.new(1, 1)
		})
		emit.ZOffset = 1
		emit.Drag = 4
		emit.Parent = attachment
		return emit, count
	end
	local core, c1 = makeEmit("CoreMixed", 3.2, NumberRange.new(3, 8), NumberRange.new(0.7, 1.1), 22)
	local outer, c2 = makeEmit("OuterMixed", 4.0, NumberRange.new(8, 16), NumberRange.new(0.6, 1.2), 26)
	local burst, c3 = makeEmit("BurstMixed", 2.6, NumberRange.new(14, 24), NumberRange.new(0.5, 0.9), 18)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = ENGINE_SPARKLE_FALLBACK
	sparks.Color = sparkPalette
	sparks.Enabled = false
	sparks.LightEmission = 0
	sparks.LightInfluence = 1
	sparks.Speed = NumberRange.new(10 * scale, 32 * scale)
	sparks.Lifetime = NumberRange.new(0.4, 0.8)
	sparks.SpreadAngle = Vector2.new(360, 360)
	sparks.Drag = 2.5
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85 * scale),
		NumberSequenceKeypoint.new(1, 0)
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.75, 0.15),
		NumberSequenceKeypoint.new(1, 1)
	})
	sparks.ZOffset = 2
	sparks.Parent = attachment
	local density = math.clamp(scale, 0.8, 2.5)
	core:Emit(math.floor(c1 * density))
	outer:Emit(math.floor(c2 * density))
	burst:Emit(math.floor(c3 * density))
	sparks:Emit(math.floor(40 * density))
	Debris:AddItem(attachment, 4)
end
local function processItem(item)
	if item:IsA("Explosion") then
		pcall(function()
			item.Visible = false
			local exactScale = math.max(item.BlastRadius / 8, 1.15)
			spawnRetroExplosion(item.Position, exactScale)
		end)
	end
end
for _, item in ipairs(Workspace:GetDescendants()) do processItem(item) end
_G.BP_ExplosionHook = Workspace.DescendantAdded:Connect(function(item)
	task.defer(function() processItem(item) end)
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

	RunService.RenderStepped:Connect(function()
		if not sg or not sg.Parent then return end

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