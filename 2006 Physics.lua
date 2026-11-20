-- [[ 2006 PHYSICS (Addtion-Scripts copy) ]]
-- The 2006 physics gist, made to work with R15 avatars too (it only ran on R6). On R15:
--   * the upper torso stands in for the Torso, the hands for the arms (the tool's weight)
--   * the hip height stays the avatar's own (an R15 body stands on it; 0 sank it into the floor), with
--     no landing squash (Roblox's R15 Animate speeds the animations up when the hip height drops)
-- R6 works exactly as before.
-- Climbing is the 2013 climbing, the same as the Old physics' (Retro Studio's CustomClimbing; see CLIMBING below), in
-- place of FWM's "fly bug" climbing: ladders, trusses and the like are climbed while the stick is held, up at 70% of
-- WalkSpeed; let go and you drop.
-- Sinking into the ground after a fall from a high place, the way the old 2007 physics did it (Super Nostalgia Zone's
-- FloorDrag): once you have fallen further than HIGH_PLACE (more than an ordinary jump falls), the legs go into the
-- ground as you keep falling, the higher the fall the deeper (up to a stud), and once you are on the ground the body
-- comes back up out of it, a bit at a time, within about half a second. An ordinary jump or a step down: no sink.
-- FWM: FWM's own CharacterPhysics script is switched off, also when it comes into the character after this started,
-- and FWM's TimePeriod / ExtraUtil / Protocols are used when they are there. Run again (or the "Old" / "2007" physics
-- picked): the earlier copy stops first.
local Players = game:GetService("Players")
local BPGenv = (getgenv and getgenv()) or _G
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- Fallback configuration if executed outside the original game
-- (Addtion-Scripts) FWM's era number, used outside FWM (inside FWM the game's own TimePeriod is used). What each value
-- turns on, from FWM's CharacterPhysics: below 1 no jumping; below 11.5 the arms collide; up to 14 the jump glide,
-- the landing tilt and the old ladder climbing (not used here: see CLIMBING); 12 to 14 the tilt only half the
-- time; above 14 a turning delay after landing; 17 and up the landing squash. 10 is 2006: every one of the 2006 things
-- is on (colliding arms, glide, the tilt on every hard landing, the old climbing) and none of the later ones. (Any
-- value from 1 to 11 does exactly the same. FWM's script also has an arm fling for 6 and up, but never switches it
-- on.)
local DEFAULT_TIME_PERIOD = 10

-- Safe reference or fallback for ExtraUtil
local ExtraUtil
if ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("ExtraUtil") then
    ExtraUtil = require(ReplicatedStorage.Modules.ExtraUtil)
else
    ExtraUtil = {
        v = Vector3,
        c = CFrame,
        Create = function(className, properties)
            local inst = Instance.new(className)
            local parent = properties.Parent
            properties.Parent = nil
            for k, v in pairs(properties) do
                inst[k] = v
            end
            if parent then
                inst.Parent = parent
            end
            return inst
        end,
        Average = function(...)
            local args = { ... }
            local sum = 0
            for _, v in ipairs(args) do
                sum += v
            end
            return #args > 0 and (sum / #args) or 0
        end,
        Lerp = function(a, b, t)
            return a + (b - a) * t
        end,
    }
end

local Protocols = ReplicatedStorage:FindFirstChild("Protocols")

local function fireProtocol(name, ...)
    if Protocols and Protocols:FindFirstChild(name) then
        Protocols[name]:FireServer(...)
    end
end

local function getTimePeriod()
    local tp = ReplicatedStorage:FindFirstChild("TimePeriod")
    return tp and tp.Value or DEFAULT_TIME_PERIOD
end

local activeConnections = {}

-- (Addtion-Scripts) run again, or picked after the "Old" / "2007" physics: the earlier one stops first, so two
-- physics never fight over the character
if BPGenv.__Physics2006Cleanup then pcall(BPGenv.__Physics2006Cleanup) end
if BPGenv.__Physics2007Cleanup then pcall(BPGenv.__Physics2007Cleanup) end
for _, env in ipairs({ _G, BPGenv }) do
    if env.__RetroMasterCleanup then pcall(env.__RetroMasterCleanup) end
end

local function cleanupConnections()
    for i, conn in pairs(activeConnections) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
        activeConnections[i] = nil
    end
end

-- (Addtion-Scripts) CLIMBING: the 2013 climbing, the same as the Old physics' (Retro Studio's CustomClimbing, its
-- clients before 0.123), in place of FWM's "fly bug" climbing (which climbed whatever small part you walked into, so
-- the climbing pose came up all the time on maps made of small parts). Roblox's own climbing is switched off. While
-- the stick is held (and you are not sitting), every frame 15 one-stud rays go straight out of the front of the body,
-- 0.225 studs apart, from 1.8 below its middle to 1.35 above (parts you can walk through are looked through). What is
-- in front is climbable when the rays find a TrussPart, or when what they hit starts and stops more than once going
-- up: ladder rungs, a step with nothing above it, a wall with a gap; not a plain wall. While it is, a lift is held on
-- the body: up at 70% of WalkSpeed, along with the stick at the whole WalkSpeed. Let go of the stick and the lift
-- goes: you drop. R15: the rays are as long as the body is deep (plus half a stud) and their heights go from the
-- feet, so a deeper or taller R15 body finds the same things. Roblox's Climbing state is put on only while this
-- climbs, so the animations show their climbing pose then, and only then.
local CLIMB_RAYS_FROM, CLIMB_RAYS_TO, CLIMB_RAY_STEP = 2, 16, 0.225 -- ray i is i * 0.225 - 2.25 studs above the middle
local CLIMB_LIFT_FORCE, CLIMB_LIFT_P = 25000, 100000
local CLIMB_SPEED_SHARE = 0.7 -- climbing speed: 70% of WalkSpeed (11.2 at 16)
local function startClimbing2013(character, humanoid, rootPart, isR15)
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances = { character }
    local lift = Instance.new("BodyVelocity")
    lift.Name = "ClimbLift"
    lift.MaxForce = Vector3.new(CLIMB_LIFT_FORCE, CLIMB_LIFT_FORCE, CLIMB_LIFT_FORCE)
    lift.P = CLIMB_LIFT_P
    lift.Velocity = Vector3.new(0, 11.2, 0)
    local climbing = false
    local robloxClimbOn = true
    local function setRobloxClimbing(on)
        if robloxClimbOn == on then return end
        robloxClimbOn = on
        pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, on) end)
    end
    -- how deep the body is (R15: its upper torso can be deeper than the root; R6: the torso)
    local function halfDepth()
        local d = rootPart.Size.Z
        local upper = character:FindFirstChild(isR15 and "UpperTorso" or "Torso")
        if upper and upper:IsA("BasePart") then d = math.max(d, upper.Size.Z) end
        return d / 2
    end
    local function climbable()
        local look = rootPart.CFrame.LookVector
        local length, base = 1, rootPart.Position
        if isR15 then
            length = math.max(1, halfDepth() + 0.5)
            -- (the same heights from the feet as on R6, whose body's middle is 3 studs above its feet)
            local feet = rootPart.Position.Y - rootPart.Size.Y / 2 - humanoid.HipHeight
            base = Vector3.new(rootPart.Position.X, feet + 3, rootPart.Position.Z)
        end
        local filter = { character }
        ray.FilterDescendantsInstances = filter
        local edges, inside, truss = 0, false, false
        for i = CLIMB_RAYS_FROM, CLIMB_RAYS_TO do
            local hit
            for _ = 1, 100 do
                hit = workspace:Raycast(base + Vector3.new(0, i * CLIMB_RAY_STEP - 2.25, 0), look * length, ray)
                if not hit or not hit.Instance or not hit.Instance:IsA("BasePart") or hit.Instance.CanCollide then break end
                table.insert(filter, hit.Instance) -- (walked through: looked through)
                ray.FilterDescendantsInstances = filter
            end
            local part = hit and hit.Instance
            if part and part:IsA("BasePart") and part.CanCollide and part:IsDescendantOf(workspace) then
                if not inside then
                    edges = edges + 1
                    inside = true
                end
                if part:IsA("TrussPart") then truss = true end
            elseif inside then
                edges = edges + 1
                inside = false
            end
        end
        return edges > 1 or truss
    end
    setRobloxClimbing(false)
    local conn = RunService.Heartbeat:Connect(function()
        if not character.Parent or humanoid.Health <= 0 then return end
        local md = humanoid.MoveDirection
        local climbingNow = false
        if not humanoid.SeatPart and md.Magnitude > 0 then
            local ok, yes = pcall(climbable)
            climbingNow = ok and yes == true
        end
        if climbingNow then
            local ws = humanoid.WalkSpeed
            lift.Velocity = Vector3.new(md.X * ws, ws * CLIMB_SPEED_SHARE, md.Z * ws)
            if lift.Parent ~= rootPart then lift.Parent = rootPart end
            -- (the climbing pose: Roblox's Climbing state, only while this climbs)
            setRobloxClimbing(true)
            if humanoid:GetState() ~= Enum.HumanoidStateType.Climbing then
                pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Climbing) end)
            end
        else
            lift.Parent = nil
            if robloxClimbOn then
                setRobloxClimbing(false)
                if humanoid:GetState() == Enum.HumanoidStateType.Climbing then
                    pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Freefall) end)
                end
            end
        end
        climbing = climbingNow
        BPGenv.BPClimbing = climbingNow or nil -- (2007 Animation.lua reads this for its climbing pose)
    end)
    -- stops it: the lift gone, Roblox's own climbing back on
    local function stop()
        conn:Disconnect()
        pcall(function() lift:Destroy() end)
        if climbing then BPGenv.BPClimbing = nil end
        climbing = false
        if humanoid.Parent then setRobloxClimbing(true) end
    end
    return stop, function() return climbing end
end

local function setupCharacterPhysics(character)
    cleanupConnections()

    -- Disable the existing CharacterPhysics script to prevent conflicts
    local existingScript = character:FindFirstChild("CharacterPhysics")
    if existingScript and existingScript:IsA("LocalScript") then
        existingScript.Disabled = true
    end
    -- (Addtion-Scripts) FWM's own copies its scripts into the character as it spawns, which can be after this ran:
    -- switched off when it comes in too
    table.insert(activeConnections, character.ChildAdded:Connect(function(child)
        if child.Name == "CharacterPhysics" and child:IsA("LocalScript") then
            child.Disabled = true
        end
    end))

    local timePeriod = getTimePeriod()
    local vec3 = ExtraUtil.v
    local cf = ExtraUtil.c
    local xzVector = vec3.new(1, 0, 1)

    local humanoid = character:WaitForChild("Humanoid", 10)
    if not humanoid then
        warn("CharacterPhysics: no Humanoid.")
        return
    end
    -- (Addtion-Scripts) R15 too: the upper torso for the Torso, the hands for the arms
    local isR15 = humanoid.RigType == Enum.HumanoidRigType.R15
    local torso = character:WaitForChild(isR15 and "UpperTorso" or "Torso", 10)
    local rightArm = character:WaitForChild(isR15 and "RightHand" or "Right Arm", 10)
    local leftArm = character:WaitForChild(isR15 and "LeftHand" or "Left Arm", 10)
    local rootPart = character:WaitForChild("HumanoidRootPart", 10)

    if not (torso and rightArm and leftArm and rootPart) then
        warn("CharacterPhysics: the character's parts weren't found.")
        return
    end

    if not isR15 then
        torso:WaitForChild("Right Shoulder", 5)
        torso:WaitForChild("Left Shoulder", 5)
    end

    -- (Addtion-Scripts) the 2013 climbing (see CLIMBING above), stopped with the rest
    local stopClimbing2013, isClimbing2013 = startClimbing2013(character, humanoid, rootPart, isR15)
    table.insert(activeConnections, {
        Connected = true,
        Disconnect = function(self)
            self.Connected = false
            stopClimbing2013()
        end,
    })

    -- (Addtion-Scripts) an R15 body stands on its hip height (R6 legs hold it up at 0). Its own is kept
    -- (and followed if Roblox changes it, e.g. when the body is scaled).
    local r15HipHeight = humanoid.HipHeight > 0 and humanoid.HipHeight or 2
    local lastSetHipHeight = nil
    -- (Addtion-Scripts) SINKING INTO THE GROUND after a fall from a high place, as the old 2007 physics did it (Super
    -- Nostalgia Zone's FloorDrag): falling fast, the body moves down into the legs at SINK_RATE, up to SINK_DEPTH, and
    -- back on the ground it comes back up, keeping SINK_DECAY of the sink each 1/60 s. Here only once you have fallen
    -- further than HIGH_PLACE (the old 2007 physics did it on every jump and step down): about 0.2 of a stud from 10
    -- studs up, 0.4 from 12, 0.6 from 15 and about the whole stud from 18 up. FWM's landing bounce (it throws you back
    -- up as you land) keeps the sink until you are on the ground again. Walking onto a higher or lower floor brings it
    -- straight back up. R6: through the hip height. R15: the body is moved down on its root joint instead (a lower hip
    -- height makes Roblox's R15 animations run faster).
    local HIGH_PLACE = 8     -- studs fallen before the legs start going into the ground (an ordinary jump falls 6.4)
    local FAST_FALL = 8      -- studs a second: falling faster than this is falling fast (SNZ's FloorDrag)
    local SINK_RATE = 20 / 3 -- studs a second the body goes into the legs while falling fast (SNZ's FloorDrag)
    local SINK_DEPTH = 1     -- studs: the deepest it goes
    local SINK_DECAY = 0.925 -- kept each 1/60 s while coming back up (SNZ's FloorDrag)
    local sinkOffset = 0
    local sinkFloorY = nil
    local fallTop = nil -- where the root was when this fall began (the highest point since you were last going up)

    local function setHipHeight(value)
        if isR15 then
            if lastSetHipHeight and math.abs(humanoid.HipHeight - lastSetHipHeight) > 0.001 then
                -- changed by something else (Roblox scaling the body): that is the new base
                r15HipHeight = humanoid.HipHeight - (lastSetHipHeight - r15HipHeight)
            end
        else
            value = value + sinkOffset
        end
        humanoid.HipHeight = value
        lastSetHipHeight = value
    end

    local autoRotateTime = os.clock()
    local landCount = 0
    local targetHipHeight = isR15 and r15HipHeight or 0
    local tiltAngleTarget = 0
    local isLandingSquash = false
    local isTilting = false
    local canJump = timePeriod >= 1
    local squashOffsetTarget = 0
    local lastJumpTick = tick()
    local fwmClimbValue = nil

    if timePeriod < 1 then
        humanoid.JumpPower = 0
    end

    local glideVelocity = ExtraUtil.Create("BodyVelocity", {
        Name = "GlideVelocity",
        MaxForce = xzVector * 9000000000,
    })

    local tiltStopVel = ExtraUtil.Create("BodyVelocity", {
        Name = "TiltStopVel",
        MaxForce = Vector3.new(math.huge, 0, math.huge),
        Velocity = Vector3.new(0, 0, 0),
    })

    -- (Addtion-Scripts) removed when this stops (run again, another physics picked, or a new character)
    table.insert(activeConnections, {
        Connected = true,
        Disconnect = function(self)
            self.Connected = false
            for _, mover in ipairs({ glideVelocity, tiltStopVel }) do
                pcall(function() mover:Destroy() end)
            end
        end,
    })

    table.insert(activeConnections, humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
        if humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat") then
            humanoid.SeatPart.HeadsUpDisplay = false
        end
    end))

    local function moveDirectionChanged()
        if humanoid.MoveDirection.Magnitude < 1 then
            fireProtocol("DiscWalking", false)
        end
        -- (Addtion-Scripts) FWM's climbing handler was here; the 2013 climbing climbs instead
    end

    local function checkIfTrippedState()
        local state = humanoid:GetState()
        return state == Enum.HumanoidStateType.Ragdoll
            or state == Enum.HumanoidStateType.FallingDown
            or state == Enum.HumanoidStateType.Jumping
            or humanoid.Sit
            or state == Enum.HumanoidStateType.Swimming
    end

    local function triggerTilt()
        if not isTilting then
            isTilting = true
            task.spawn(function()
                tiltStopVel.Parent = torso
                task.wait()
                tiltStopVel.Parent = nil
            end)

            local horizVel = torso.AssemblyLinearVelocity * xzVector
            tiltAngleTarget = (horizVel.Magnitude / 16) * 9

            while tiltAngleTarget >= 0.1 or checkIfTrippedState() do
                if humanoid.Sit or not humanoid.Parent then
                    tiltAngleTarget = 0
                    break
                end
                tiltAngleTarget = tiltAngleTarget * (0.88 - task.wait(0))
            end
            isTilting = false
        end
    end

    local function forceVelocity(upwardSpeed)
        -- (Addtion-Scripts) for the 2007 animation: this throws you up as a landing bounce, not a fall, so it keeps
        -- the arms coming down instead of putting them back up
        BPGenv.BPLandingBounce = os.clock()
        local bv = ExtraUtil.Create("BodyVelocity", {
            MaxForce = Vector3.new(0, 9000000000, 0),
            Parent = torso,
            Velocity = Vector3.new(0, 1, 0) * upwardSpeed,
        })
        RunService.Heartbeat:Wait()
        RunService.Heartbeat:Wait()
        bv:Destroy()
    end

    local function delayJump()
        task.wait()
        canJump = false
        if timePeriod >= 1 then
            task.wait(0.65)
            canJump = true
            setHipHeight(targetHipHeight)
        end
    end

    local function handleJumping()
        setHipHeight(targetHipHeight)
        landCount = 0
        lastJumpTick = tick()
        if timePeriod <= 14 then
            glideVelocity.Velocity = torso.AssemblyLinearVelocity * xzVector
            glideVelocity.Parent = torso
        end
    end

    local function onStateChanged(_, newState)
        if newState == Enum.HumanoidStateType.Landed then
            autoRotateTime = os.clock() + 0.25
            local velY = torso.AssemblyLinearVelocity.Y
            if velY >= -250 then
                landCount += 1
            end
            glideVelocity.Parent = nil

            if landCount <= 1 then
                if velY >= 0 then
                    glideVelocity.Parent = nil
                    return
                end
                if math.ceil(velY) <= -48 then
                    if timePeriod >= 12 and timePeriod <= 14 then
                        if math.random(1, 2) == 2 then
                            task.spawn(triggerTilt)
                        end
                    elseif timePeriod <= 14 then
                        task.spawn(triggerTilt)
                    end
                end

                task.spawn(delayJump)

                if timePeriod <= 14 then
                    task.wait()
                    forceVelocity(math.abs(velY * 0.75))

                    local torsoAttach = torso:FindFirstChild("TorsoAttach")
                    local angularTilt = torsoAttach and torsoAttach:FindFirstChild("AngularTilt")
                    if angularTilt and not angularTilt.Enabled then
                        task.spawn(function()
                            angularTilt.Enabled = true
                            angularTilt.MaxTorque = 5000
                            while angularTilt.MaxTorque > 10 and angularTilt.Parent do
                                local dt = task.wait()
                                angularTilt.MaxTorque = angularTilt.MaxTorque * (0.75 + dt)
                            end
                            angularTilt.Enabled = false
                        end)
                    end
                end

                if timePeriod >= 17 and not isLandingSquash then
                    isLandingSquash = true
                    squashOffsetTarget = -0.7
                    while squashOffsetTarget < 0.05 and (not checkIfTrippedState() and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping) do
                        squashOffsetTarget = squashOffsetTarget * (0.8 + task.wait(0))
                    end
                    isLandingSquash = false
                    squashOffsetTarget = 0
                end
            end
        elseif newState == Enum.HumanoidStateType.Jumping then
            autoRotateTime = os.time()
            isLandingSquash = false
            task.spawn(handleJumping)
        elseif newState == Enum.HumanoidStateType.Swimming then
            isTilting = false
            glideVelocity.Parent = nil
        end
    end

    table.insert(activeConnections, humanoid.StateChanged:Connect(onStateChanged))

    table.insert(activeConnections, UserInputService.JumpRequest:Connect(function()
        if humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
            -- (Addtion-Scripts) jumping off a ladder is left to Roblox's climbing, as on the Old physics
            if canJump then
                task.spawn(handleJumping)
            end
        end
    end))

    local currentSway = 0
    local targetSway = 0
    local currentSquash = 0
    local currentTilt = 0

    -- (Addtion-Scripts) the sink (see SINKING INTO THE GROUND above)
    local sinkRay = RaycastParams.new()
    sinkRay.FilterType = Enum.RaycastFilterType.Exclude
    sinkRay.FilterDescendantsInstances = { character }
    local function floorBelow()
        local hit = workspace:Raycast(rootPart.Position, Vector3.new(0, -5000, 0), sinkRay)
        return hit and hit.Position.Y or nil
    end
    local function updateSink(dt)
        local state = humanoid:GetState()
        local level = floorBelow()
        local y = rootPart.Position.Y
        if humanoid.Sit or humanoid.SeatPart or humanoid.Health <= 0
            or state == Enum.HumanoidStateType.Climbing or state == Enum.HumanoidStateType.Swimming then
            sinkOffset = 0
            fallTop = y
        else
            local vy = rootPart.AssemblyLinearVelocity.Y
            local airborne = humanoid.FloorMaterial == Enum.Material.Air
                or state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
            if vy >= 0 or not airborne or not fallTop then
                fallTop = y -- (going up, or on the ground: a fall starts from here)
            end
            if vy < -FAST_FALL and airborne and fallTop - y > HIGH_PLACE then
                -- falling from a high place: into the legs, a bit more each moment
                sinkOffset = math.max(-SINK_DEPTH, sinkOffset - SINK_RATE * dt)
            elseif airborne then
                -- (in the air, e.g. thrown back up by FWM's landing bounce: the sink stays as it is)
            elseif level and sinkFloorY and math.abs(level - sinkFloorY) > 0.5 then
                sinkOffset = 0 -- walked onto a higher or lower floor
            else
                -- on the ground: coming back up out of it
                sinkOffset = sinkOffset * SINK_DECAY ^ (dt * 60)
                if math.abs(sinkOffset) < 0.001 then sinkOffset = 0 end
            end
        end
        -- (followed in the air too, so the floor you land on is the one compared with afterwards)
        sinkFloorY = level
    end

    -- R15: the body moved down on its root joint (LowerTorso.Root), from whatever it is set to by anything else
    local rootJoint, rootBase, rootWritten = nil, nil, nil
    local function applyR15Sink()
        if not (rootJoint and rootJoint.Parent) then
            local lowerTorso = character:FindFirstChild("LowerTorso")
            rootJoint = lowerTorso and lowerTorso:FindFirstChild("Root")
            rootBase, rootWritten = nil, nil
            if not (rootJoint and rootJoint:IsA("Motor6D")) then rootJoint = nil return end
        end
        local current = rootJoint.C0
        if rootWritten == nil or current ~= rootWritten then rootBase = current end
        local want = rootBase + Vector3.new(0, sinkOffset, 0)
        if current ~= want then
            rootJoint.C0 = want
        end
        rootWritten = rootJoint.C0
    end
    if isR15 then
        -- put back when this stops (run again, or the character dies)
        table.insert(activeConnections, {
            Connected = true,
            Disconnect = function(self)
                self.Connected = false
                if rootJoint and rootJoint.Parent and rootBase and rootJoint.C0 == rootWritten then
                    pcall(function() rootJoint.C0 = rootBase end)
                end
            end,
        })
    end

    table.insert(activeConnections, RunService.RenderStepped:Connect(function(dt)
        if not torso.Parent then return end
        torso:GetConnectedParts()

        updateSink(math.min(dt, 0.1))
        if isR15 then applyR15Sink() end

        if timePeriod > 14 then
            humanoid.AutoRotate = autoRotateTime < os.clock()
        end

        -- (Addtion-Scripts) FWM's fly-bug climbing was here (walking into any small part climbed it); the 2013
        -- climbing climbs instead (see CLIMBING above)

        currentSquash = ExtraUtil.Lerp(currentSquash, squashOffsetTarget, 0.5)
        -- (Addtion-Scripts) R15: no landing squash on the hip height. Roblox's R15 Animate plays the
        -- animations faster the lower the hip height is, so the squash made them run twice as fast.
        setHipHeight(isR15 and targetHipHeight or (currentSquash + targetHipHeight))

        for _, child in pairs(character:GetChildren()) do
            if child:GetAttribute("FWMClimb") then
                fwmClimbValue = child
            end
        end
        if fwmClimbValue then
            fwmClimbValue.Value = isClimbing2013() or humanoid:GetState() == Enum.HumanoidStateType.Climbing
        end

        currentTilt = ExtraUtil.Lerp(currentTilt, tiltAngleTarget, 0.3)

        local toolMass = 0
        local equippedTool = character:FindFirstChildWhichIsA("Tool")
        if equippedTool then
            local connectedParts = rightArm:GetConnectedParts()
            for _, desc in pairs(equippedTool:GetDescendants()) do
                if desc:IsA("Part") and table.find(connectedParts, desc) then
                    toolMass += desc:GetMass()
                end
            end
        end

        targetSway = targetSway * (0.9 + dt) + (torso.AssemblyAngularVelocity.Y / 2000) * toolMass
        currentSway = ExtraUtil.Lerp(currentSway, targetSway, 0.3)

        if not checkIfTrippedState() then
            local rollDivisor = torso.AssemblyAngularVelocity.Y < 0 and 2.5 or 5
            local pitchAngle = -currentSway / 5
            if isTilting then
                pitchAngle = -math.rad(currentTilt) - currentSway / 5
            end
            torso.CFrame = torso.CFrame * cf.fromEulerAnglesXYZ(pitchAngle, 0, currentSway / rollDivisor)
        end

        if tick() - lastJumpTick > 0.05
            and glideVelocity.Parent ~= nil
            and humanoid.FloorMaterial ~= Enum.Material.Air
            and torso.AssemblyLinearVelocity.Y < 1
            and torso.AssemblyLinearVelocity.Y > -1
        then
            glideVelocity.Parent = nil
        end

        if humanoid.Sit then
            glideVelocity.Parent = nil
        end

        if timePeriod < 11.5 then
            if character:FindFirstChild("Left Arm") then
                character["Left Arm"].CanCollide = true
            end
            if character:FindFirstChild("Right Arm") then
                character["Right Arm"].CanCollide = true
            end
        end

        if isR15 then
            -- (Addtion-Scripts) an R15 body stands on its own hip height
            targetHipHeight = r15HipHeight
        elseif character:FindFirstChild("Left Leg") or character:FindFirstChild("Right Leg") then
            targetHipHeight = ExtraUtil.Lerp(targetHipHeight, 0, 1)
        else
            targetHipHeight = ExtraUtil.Lerp(targetHipHeight, 2, 1)
        end

        if not isLandingSquash then
            setHipHeight(targetHipHeight)
        end
    end))

    local glideTouchConnections = {}
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = { character, workspace.CurrentCamera }
    raycastParams.RespectCanCollide = true
    local lastGlideBounce = tick()

    local function createGlideConnections()
        for _, part in pairs(character:GetChildren()) do
            if not part:IsA("BasePart") then
                continue
            end
            local conn = part.Touched:Connect(function(hit)
                if hit:IsDescendantOf(part.Parent) or not hit.CanCollide then
                    return
                end
                local minHeight = torso.Position.Y - 2
                if hit.Position.Y >= minHeight and tick() - lastGlideBounce > 0.01 then
                    lastGlideBounce = tick()
                    local closestPoint = hit:GetClosestPointOnSurface(part.Position)
                    local dir = closestPoint - part.Position
                    local castDir = dir.Magnitude <= 0 and Vector3.new(0, 0, 0) or dir.Unit
                    local result = workspace:Shapecast(part, castDir, raycastParams)

                    if result then
                        if not result.Instance.CanCollide then
                            return
                        end
                        if minHeight < result.Position.Y then
                            local speed = glideVelocity.Velocity.Magnitude
                            local reflected = result.Normal * speed
                            glideVelocity.Velocity = Vector3.new(reflected.X, glideVelocity.Velocity.Y, reflected.Z)
                        end
                    elseif minHeight < part.Position.Y then
                        glideVelocity.Velocity = glideVelocity.Velocity * Vector3.new(-1, 1, -1)
                    end
                end
            end)
            table.insert(glideTouchConnections, conn)
        end
    end

    table.insert(activeConnections, glideVelocity:GetPropertyChangedSignal("Parent"):Connect(function()
        humanoid.AutoRotate = glideVelocity.Parent == nil
        if glideVelocity.Parent == nil then
            for i, conn in pairs(glideTouchConnections) do
                conn:Disconnect()
                glideTouchConnections[i] = nil
            end
        else
            createGlideConnections()
        end
    end))

    table.insert(activeConnections, humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
        if not canJump then
            humanoid.Jump = false
        end
    end))

    table.insert(activeConnections, humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(moveDirectionChanged))

    table.insert(activeConnections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and (input.KeyCode == Enum.KeyCode.Equals or input.KeyCode == Enum.KeyCode.Plus) then
            fireProtocol("Drop")
        end
    end))

    humanoid.Died:Once(function()
        cleanupConnections()
        for i, conn in pairs(glideTouchConnections) do
            conn:Disconnect()
            glideTouchConnections[i] = nil
        end
    end)
end

-- Initialize on current character and re-apply on respawn
if LocalPlayer.Character then
    task.spawn(setupCharacterPhysics, LocalPlayer.Character)
end
local characterAddedConnection = LocalPlayer.CharacterAdded:Connect(setupCharacterPhysics)

-- (Addtion-Scripts) stops this copy (see the top)
BPGenv.__Physics2006Cleanup = function()
    characterAddedConnection:Disconnect()
    cleanupConnections()
    BPGenv.__Physics2006Cleanup = nil
end