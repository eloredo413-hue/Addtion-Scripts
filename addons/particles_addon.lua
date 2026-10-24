-- [[ 2010/2013 PARTICLES WIZARD ADDON — forcefield-safe ]]

task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")

    local player = Players.LocalPlayer
    local pg = player:WaitForChild("PlayerGui", 30)

    local sg
    local elapsed = 0
    while elapsed < 60 do
        sg = pg:FindFirstChild("BloxyParadoxProject")
        if sg then break end
        task.wait(0.2)
        elapsed = elapsed + 0.2
    end
    if not sg then
        warn("[Particles Addon] GUI never appeared.")
        return
    end

    local TEMPLATE = [==[
local game = game

local CLASSIC_SPARKLE_URL = "rbxthumb://type=Asset&id=74652191390576&w=420&h=420"
local CLASSIC_SMOKE_URL = "rbxthumb://type=Asset&id=113441945769183&w=420&h=420"
local FIRE_URL = "__FIRE_URL__"

local Controllers = {}
local DestroyedSources = {}

local function destroyReplacement(controller)
    if not controller then return end
    controller.Destroyed = true
    if controller.Emitter then pcall(function() controller.Emitter:Destroy() end) end
    if controller.Attachment then pcall(function() controller.Attachment:Destroy() end) end
    Controllers[controller.Source] = nil
end

local function sourceExists(source)
    if not source then return false end
    if DestroyedSources[source] then return false end
    return source:IsDescendantOf(game)
end

------------------------------------------------------------
-- FORCEFIELD EXCLUSION
-- Walk up the whole hierarchy. If anything is a ForceField instance
-- or matches a forcefield name pattern, the particle is ignored.
------------------------------------------------------------
local FORCEFIELD_NAME_PATTERNS = {
    "forcefield",
    "force_field",
    "ffclone",
    "ff holder",
    "ffholder",
}

local function isInForcefield(obj)
    if not obj then return false end
    local current = obj
    local depth = 0
    while current and current ~= game and depth < 64 do
        if current:IsA("ForceField") then return true end
        local n = current.Name
        if type(n) == "string" then
            local lower = n:lower()
            for _, pat in ipairs(FORCEFIELD_NAME_PATTERNS) do
                if lower:find(pat, 1, true) then return true end
            end
        end
        current = current.Parent
        depth = depth + 1
    end
    return false
end

------------------------------------------------------------
-- SPARKLES
------------------------------------------------------------
local function setupSparkles(sparkles)
    if not sparkles:IsA("Sparkles") or Controllers[sparkles] then return end
    if isInForcefield(sparkles) then return end
    local parent = sparkles.Parent
    local controller = {Source=sparkles, Destroyed=false, Rebuilding=false}
    Controllers[sparkles] = controller
    local oldEnabled = sparkles.Enabled
    sparkles.Enabled = false

    local function make()
        local e = Instance.new("ParticleEmitter")
        e.Name = "Legacy_2010_Sparkles"
        e.Texture = CLASSIC_SPARKLE_URL
        e.Rate = 20
        e.Speed = NumberRange.new(1.0, 2.5)
        e.Lifetime = NumberRange.new(1.0, 1.6)
        e.Drag = 1
        e.Acceleration = Vector3.new(0, 4, 0)
        e.RotSpeed = NumberRange.new(-150, 150)
        e.Rotation = NumberRange.new(-360, 360)
        e.SpreadAngle = Vector2.new(0, 0)
        e.Color = ColorSequence.new(sparkles.SparkleColor)
        e.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.15, 0),
            NumberSequenceKeypoint.new(0.75, 0.1),
            NumberSequenceKeypoint.new(1, 1)
        })
        e.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.5),
            NumberSequenceKeypoint.new(0.3, 1.2),
            NumberSequenceKeypoint.new(0.8, 0.9),
            NumberSequenceKeypoint.new(1, 0)
        })
        e.LightEmission = 1
        e.Orientation = Enum.ParticleOrientation.FacingCamera
        return e
    end

    local e = make()
    e.Enabled = oldEnabled
    if parent and parent:IsA("BasePart") then e.Parent = parent end
    controller.Emitter = e

    local function rebuild()
        if controller.Destroyed or not sourceExists(sparkles) or controller.Rebuilding then return end
        if isInForcefield(sparkles) then return end
        controller.Rebuilding = true
        task.defer(function()
            controller.Rebuilding = false
            if controller.Destroyed or not sourceExists(sparkles) then return end
            if isInForcefield(sparkles) then return end
            local p = sparkles.Parent
            if not p or not p:IsA("BasePart") then return end
            if not controller.Emitter or not controller.Emitter.Parent then
                local ne = make()
                ne.Enabled = sparkles.Enabled
                ne.Parent = p
                controller.Emitter = ne
                if sparkles.Enabled then sparkles.Enabled = false end
            end
        end)
    end

    sparkles.AncestryChanged:Connect(function()
        if controller.Destroyed then return end
        task.defer(function()
            if controller.Destroyed then return end
            if not sourceExists(sparkles) then
                DestroyedSources[sparkles] = true
                destroyReplacement(controller)
                return
            end
            if isInForcefield(sparkles) then return end
            local p = sparkles.Parent
            if p and p:IsA("BasePart") then
                if controller.Emitter then controller.Emitter.Parent = p end
                rebuild()
            elseif controller.Emitter then
                controller.Emitter.Parent = nil
            end
        end)
    end)

    e.AncestryChanged:Connect(function(_, np)
        if controller.Destroyed or np then return end
        task.defer(function()
            if controller.Destroyed or not sourceExists(sparkles) then return end
            rebuild()
        end)
    end)

    sparkles:GetPropertyChangedSignal("SparkleColor"):Connect(function()
        if controller.Destroyed or not controller.Emitter then return end
        controller.Emitter.Color = ColorSequence.new(sparkles.SparkleColor)
    end)

    sparkles:GetPropertyChangedSignal("Enabled"):Connect(function()
        if controller.Destroyed then return end
        if controller.Emitter then controller.Emitter.Enabled = sparkles.Enabled end
        if sparkles.Enabled then
            task.defer(function()
                if sparkles.Parent and not controller.Destroyed then sparkles.Enabled = false end
            end)
        end
    end)
end

------------------------------------------------------------
-- SMOKE
------------------------------------------------------------
local function setupSmoke(smoke)
    if not smoke:IsA("Smoke") or Controllers[smoke] then return end
    if isInForcefield(smoke) then return end
    local parent = smoke.Parent
    local controller = {Source=smoke, Destroyed=false, Rebuilding=false}
    Controllers[smoke] = controller
    local oldEnabled = smoke.Enabled
    smoke.Enabled = false

    local att = Instance.new("Attachment")
    att.Name = "Legacy_Smoke_Wave_Center"
    att.Position = Vector3.new(0, 0, 0)
    if parent and parent:IsA("BasePart") then att.Parent = parent end
    controller.Attachment = att

    local function updateSize()
        if not controller.Emitter then return end
        local s = math.max(0.1, smoke.Size)
        controller.Emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.90 * s),
            NumberSequenceKeypoint.new(0.15, 2.00 * s),
            NumberSequenceKeypoint.new(0.40, 3.50 * s),
            NumberSequenceKeypoint.new(0.70, 4.80 * s),
            NumberSequenceKeypoint.new(1, 6.00 * s)
        })
    end
    local function updateColor()
        if controller.Emitter then controller.Emitter.Color = ColorSequence.new(smoke.Color) end
    end
    local function updateOpacity()
        if not controller.Emitter then return end
        local o = math.clamp(smoke.Opacity, 0, 1)
        local t = 1 - o
        controller.Emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, math.clamp(t + 0.1, 0, 1)),
            NumberSequenceKeypoint.new(0.1, t),
            NumberSequenceKeypoint.new(0.75, t),
            NumberSequenceKeypoint.new(1, 1)
        })
    end
    local function updateVelocity()
        if not controller.Emitter then return end
        local r = math.abs(smoke.RiseVelocity)
        controller.Emitter.Rate = math.clamp(r * 1.2, 3, 14)
        controller.Emitter.Speed = NumberRange.new(math.max(0.8, r * 0.4), math.max(1.5, r * 0.7))
    end

    local function make()
        local em = Instance.new("ParticleEmitter")
        em.Name = "Legacy_2010_Smoke_Wave"
        em.Texture = CLASSIC_SMOKE_URL
        em.Lifetime = NumberRange.new(2.2, 2.8)
        em.SpreadAngle = Vector2.new(12, 12)
        em.Drag = 0.5
        em.Acceleration = Vector3.new(0, 1.2, 0)
        em.Rotation = NumberRange.new(-30, 30)
        em.RotSpeed = NumberRange.new(-10, 10)
        em.LightEmission = 0
        em.Orientation = Enum.ParticleOrientation.FacingCamera
        return em
    end

    local e = make()
    controller.Emitter = e
    updateSize(); updateColor(); updateOpacity(); updateVelocity()
    e.Enabled = oldEnabled
    e.Parent = att

    local function rebuild()
        if controller.Destroyed or not sourceExists(smoke) or controller.Rebuilding then return end
        if isInForcefield(smoke) then return end
        controller.Rebuilding = true
        task.defer(function()
            controller.Rebuilding = false
            if controller.Destroyed or not sourceExists(smoke) then return end
            if isInForcefield(smoke) then return end
            local p = smoke.Parent
            if not p or not p:IsA("BasePart") then return end
            if not controller.Attachment or not controller.Attachment.Parent then
                local na = Instance.new("Attachment")
                na.Name = "Legacy_Smoke_Wave_Center"
                na.Position = Vector3.new(0, 0, 0)
                na.Parent = p
                controller.Attachment = na
            end
            if not controller.Emitter or not controller.Emitter.Parent then
                local ne = make()
                controller.Emitter = ne
                updateSize(); updateColor(); updateOpacity(); updateVelocity()
                ne.Enabled = smoke.Enabled
                ne.Parent = controller.Attachment
            end
            if smoke.Enabled then smoke.Enabled = false end
        end)
    end

    smoke.AncestryChanged:Connect(function()
        if controller.Destroyed then return end
        task.defer(function()
            if controller.Destroyed then return end
            if not sourceExists(smoke) then
                DestroyedSources[smoke] = true
                destroyReplacement(controller)
                return
            end
            if isInForcefield(smoke) then return end
            local p = smoke.Parent
            if p and p:IsA("BasePart") then
                if controller.Attachment then controller.Attachment.Parent = p end
                rebuild()
            elseif controller.Attachment then
                controller.Attachment.Parent = nil
            end
        end)
    end)

    e.AncestryChanged:Connect(function(_, np)
        if controller.Destroyed or np then return end
        task.defer(function()
            if controller.Destroyed or not sourceExists(smoke) then return end
            rebuild()
        end)
    end)

    att.AncestryChanged:Connect(function(_, np)
        if controller.Destroyed or np then return end
        task.defer(function()
            if controller.Destroyed or not sourceExists(smoke) then return end
            rebuild()
        end)
    end)

    smoke:GetPropertyChangedSignal("Size"):Connect(updateSize)
    smoke:GetPropertyChangedSignal("Color"):Connect(updateColor)
    smoke:GetPropertyChangedSignal("Opacity"):Connect(updateOpacity)
    smoke:GetPropertyChangedSignal("RiseVelocity"):Connect(updateVelocity)
    smoke:GetPropertyChangedSignal("Enabled"):Connect(function()
        if controller.Emitter then controller.Emitter.Enabled = smoke.Enabled end
        if smoke.Enabled then
            task.defer(function()
                if smoke.Parent and not controller.Destroyed then smoke.Enabled = false end
            end)
        end
    end)
end

------------------------------------------------------------
-- FIRE
------------------------------------------------------------
local function setupFire(fire)
    if fire.ClassName ~= "Fire" or Controllers[fire] then return end
    if isInForcefield(fire) then return end
    local parent = fire.Parent
    local controller = {Source=fire, Destroyed=false, Rebuilding=false}
    Controllers[fire] = controller
    local oldEnabled = fire.Enabled
    fire.Enabled = false

    local att = Instance.new("Attachment")
    att.Name = "Legacy_Fire_Anchor"
    if parent and parent:IsA("BasePart") then att.Parent = parent end
    controller.Attachment = att

    local function updateFire()
        if not controller.Emitter then return end
        local size = math.clamp(fire.Size, 0, 30)
        local heat = math.clamp(fire.Heat, 0, 30)
        local sc = math.clamp(size / 5, 0.15, 6)
        local vs = 3.333 * sc
        controller.Emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, vs),
            NumberSequenceKeypoint.new(1, 0)
        })
        local sp = math.max(0.1, heat * 0.75)
        controller.Emitter.Speed = NumberRange.new(sp, sp)
    end

    local function updateFireColor()
        if not controller.Emitter then return end
        controller.Emitter.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, fire.Color),
            ColorSequenceKeypoint.new(1, fire.SecondaryColor)
        })
    end

    local function make()
        local em = Instance.new("ParticleEmitter")
        em.Name = "Legacy_2010_Fire"
        em.Texture = FIRE_URL
        em.Shape = Enum.ParticleEmitterShape.Box
        em.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
        em.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
        em.EmissionDirection = Enum.NormalId.Top
        em.Lifetime = NumberRange.new(1, 1)
        em.Rate = 30
        em.Rotation = NumberRange.new(0, 365)
        em.RotSpeed = NumberRange.new(0, 100)
        em.SpreadAngle = Vector2.new(10, 10)
        em.ZOffset = 0
        em.Brightness = 1
        em.LightEmission = __LIGHT_EMISSION__
        em.LightInfluence = 0
        em.Orientation = Enum.ParticleOrientation.FacingCamera
        em.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 0)
        })
        em.Squash = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 0)
        })
        return em
    end

    local e = make()
    controller.Emitter = e
    updateFire(); updateFireColor()
    e.Enabled = oldEnabled
    e.Parent = att

    local function rebuild()
        if controller.Destroyed or not sourceExists(fire) or controller.Rebuilding then return end
        if isInForcefield(fire) then return end
        controller.Rebuilding = true
        task.defer(function()
            controller.Rebuilding = false
            if controller.Destroyed or not sourceExists(fire) then return end
            if isInForcefield(fire) then return end
            local p = fire.Parent
            if not p or not p:IsA("BasePart") then return end
            if not controller.Attachment or not controller.Attachment.Parent then
                local na = Instance.new("Attachment")
                na.Name = "Legacy_Fire_Anchor"
                na.Parent = p
                controller.Attachment = na
            end
            if not controller.Emitter or not controller.Emitter.Parent then
                local ne = make()
                controller.Emitter = ne
                updateFire(); updateFireColor()
                ne.Parent = controller.Attachment
            end
            if fire.Enabled then fire.Enabled = false end
        end)
    end

    fire.AncestryChanged:Connect(function()
        if controller.Destroyed then return end
        task.defer(function()
            if controller.Destroyed then return end
            if not sourceExists(fire) then
                DestroyedSources[fire] = true
                destroyReplacement(controller)
                return
            end
            if isInForcefield(fire) then return end
            local p = fire.Parent
            if p and p:IsA("BasePart") then
                if controller.Attachment then controller.Attachment.Parent = p end
                rebuild()
            elseif controller.Attachment then
                controller.Attachment.Parent = nil
            end
        end)
    end)

    e.AncestryChanged:Connect(function(_, np)
        if controller.Destroyed or np then return end
        task.defer(function()
            if controller.Destroyed or not sourceExists(fire) then return end
            rebuild()
        end)
    end)

    att.AncestryChanged:Connect(function(_, np)
        if controller.Destroyed or np then return end
        task.defer(function()
            if controller.Destroyed or not sourceExists(fire) then return end
            rebuild()
        end)
    end)

    fire:GetPropertyChangedSignal("Size"):Connect(updateFire)
    fire:GetPropertyChangedSignal("Heat"):Connect(updateFire)
    fire:GetPropertyChangedSignal("Color"):Connect(updateFireColor)
    fire:GetPropertyChangedSignal("SecondaryColor"):Connect(updateFireColor)
    fire:GetPropertyChangedSignal("Enabled"):Connect(function()
        if controller.Emitter then controller.Emitter.Enabled = fire.Enabled end
        if fire.Enabled then
            task.defer(function()
                if fire.Parent and not controller.Destroyed then fire.Enabled = false end
            end)
        end
    end)
end

------------------------------------------------------------
-- PROCESS
------------------------------------------------------------
local function process(item)
    if not item then return end
    if isInForcefield(item) then return end
    if item:IsA("Sparkles") then
        pcall(function() setupSparkles(item) end)
    elseif item:IsA("Smoke") then
        pcall(function() setupSmoke(item) end)
    elseif item.ClassName == "Fire" then
        pcall(function() setupFire(item) end)
    end
end

for _, item in ipairs(game:GetDescendants()) do
    process(item)
end

game.DescendantAdded:Connect(function(item)
    if item:IsA("Fire") or item:IsA("Smoke") or item:IsA("Sparkles") then
        task.defer(function() process(item) end)
    end
end)
]==]

    local function build(fireUrl, le)
        local s = TEMPLATE:gsub("__FIRE_URL__", function() return fireUrl end)
        s = s:gsub("__LIGHT_EMISSION__", function() return tostring(le) end)
        return s
    end

    local SCRIPT_2010 = build("rbxassetid://10789085133", 0.8)
    local SCRIPT_2013 = build("rbxassetid://3691827674", 0)

    local function runScript(src)
        local fn, err = loadstring(src)
        if not fn then
            warn("[Particles Addon] loadstring failed: " .. tostring(err))
            return
        end
        local ok, runErr = pcall(fn)
        if not ok then
            warn("[Particles Addon] Runtime: " .. tostring(runErr))
        end
    end

    local function fireBtn(btn)
        if not btn or not btn.Parent then return end
        if firesignal then
            if pcall(firesignal, btn.MouseButton1Click) then return end
        end
        pcall(function() btn.MouseButton1Click:Fire() end)
    end

    local function applyHover(btn)
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
    end

    local handled = setmetatable({}, {__mode = "k"})
    local processing = false

    RunService.RenderStepped:Connect(function()
        if not sg or not sg.Parent then return end
        for _, frame in ipairs(sg:GetChildren()) do
            if frame:IsA("Frame") and not handled[frame] then
                local title, yesBtn, noBtn
                for _, d in ipairs(frame:GetDescendants()) do
                    if d:IsA("TextLabel") and type(d.Text) == "string"
                       and d.Text:lower():find("old particles") then
                        title = d
                    end
                    if d:IsA("TextButton") then
                        if d.Text == "Yes" then yesBtn = d end
                        if d.Text == "No" then noBtn = d end
                    end
                end
                if title and yesBtn and noBtn then
                    handled[frame] = true
                    print("[Particles Addon] Customizing particle step.")

                    title.Text = "Which old particles?"
                    yesBtn.Visible = false

                    noBtn.Text = "Normal"
                    noBtn.Position = UDim2.new(0, 245, 0, 45)
                    noBtn.Size = UDim2.new(0, 100, 0, 32)

                    local style = {
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        TextColor3 = Color3.fromRGB(0, 0, 0),
                        Font = Enum.Font.Legacy,
                        TextScaled = true,
                        AutoButtonColor = false,
                        BorderSizePixel = 1,
                    }

                    local btn2010 = Instance.new("TextButton")
                    btn2010.Name = "Particles2010Button"
                    btn2010.Size = UDim2.new(0, 100, 0, 32)
                    btn2010.Position = UDim2.new(0, 15, 0, 45)
                    btn2010.Text = "2010"
                    btn2010.ZIndex = 5
                    for k, v in pairs(style) do
                        pcall(function() btn2010[k] = v end)
                    end
                    btn2010.Parent = frame
                    local c1 = Instance.new("UITextSizeConstraint", btn2010)
                    c1.MaxTextSize = 16
                    c1.MinTextSize = 8

                    local btn2013 = Instance.new("TextButton")
                    btn2013.Name = "Particles2013Button"
                    btn2013.Size = UDim2.new(0, 100, 0, 32)
                    btn2013.Position = UDim2.new(0, 130, 0, 45)
                    btn2013.Text = "2013"
                    btn2013.ZIndex = 5
                    for k, v in pairs(style) do
                        pcall(function() btn2013[k] = v end)
                    end
                    btn2013.Parent = frame
                    local c2 = Instance.new("UITextSizeConstraint", btn2013)
                    c2.MaxTextSize = 16
                    c2.MinTextSize = 8

                    applyHover(btn2010)
                    applyHover(btn2013)

                    btn2010.MouseButton1Click:Connect(function()
                        if processing then return end
                        processing = true
                        print("[Particles Addon] Running 2010 particles.")
                        task.spawn(function() runScript(SCRIPT_2010) end)
                        task.wait(0.1)
                        fireBtn(noBtn)
                    end)

                    btn2013.MouseButton1Click:Connect(function()
                        if processing then return end
                        processing = true
                        print("[Particles Addon] Running 2013 particles.")
                        task.spawn(function() runScript(SCRIPT_2013) end)
                        task.wait(0.1)
                        fireBtn(noBtn)
                    end)

                    print("[Particles Addon] Particle step ready.")
                    return
                end
            end
        end
    end)

    print("[Particles Addon] Watching for particle step.")
end)