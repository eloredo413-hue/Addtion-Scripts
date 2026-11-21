-- [[ 2006 PHYSICS (Addtion-Scripts copy) ]]
-- The 2006 physics gist, made to work with R15 avatars too (it only ran on R6). On R15:
--   * the upper torso stands in for the Torso, the hands for the arms (the tool's weight)
--   * the hip height stays the avatar's own (an R15 body stands on it; 0 sank it into the floor), with
--     no landing squash (Roblox's R15 Animate speeds the animations up when the hip height drops)
-- R6 works exactly as before.
-- Climbing is FWM's own ("fly bug" climbing), improved so it doesn't throw you up and off walls all the time, and the
-- jump glide ends instead of bouncing you off a part you could climb: see CLIMBING below. Trampolines bounce you as on
-- the Old physics: see TRAMPOLINES below.
-- Sinking into the ground after a fall from a high place, the way the old 2007 physics did it (Super Nostalgia Zone's
-- FloorDrag): once you have fallen further than HIGH_PLACE (more than an ordinary jump falls), the legs go into the
-- ground as you keep falling, the higher the fall the deeper (up to a stud), and once you are on the ground the body
-- comes back up out of it, a bit at a time, within about half a second. An ordinary jump or a step down: no sink.
-- FWM: FWM's own CharacterPhysics script is switched off, also when it comes into the character after this started,
-- and FWM's TimePeriod / ExtraUtil / Protocols are used when they are there. Run again (or the "Old" / "2008" physics
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
-- the landing tilt and the old ladder climbing (let go of the stick and you drop); 12 to 14 the tilt only half the
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

-- (Addtion-Scripts) run again, or picked after the "Old" / "2008" physics: the earlier one stops first, so two
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

-- (Addtion-Scripts) CLIMBING: FWM's own climbing (the "fly bug" ladders of old Roblox), improved.
-- FWM's, kept: walking into a part that isn't big (on average 3.5 studs or less, and under 3.5 studs tall) 1 to 2
-- studs above your feet, just in front, climbs it: each frame it is there while the stick is held you are put in the
-- Climbing state and kicked up at 13 studs a second (your sideways speed kept 0.8 a frame, 0.4 after era 14). While
-- climbing, a ClimbLift pushes you along the stick at 24 and a ClimbGyro turns you. Letting go of the stick (era 14
-- and below) or jumping drops you, and you can't climb again until you are on the ground. Roblox's own climbing stays
-- on, so trusses climb as they always did.
-- Improved, so it doesn't throw you up and off walls all the time:
--   * a climb only starts while you walk into the part and it holds you back (the stick pointing where you face,
--     slower than CLIMB_START_SPEED of WalkSpeed for CLIMB_START_TIME), and not when the part is trim on a wall: a
--     big part at chest height with nothing small there (no rungs) is a wall, not a ladder
--   * parts turned round count by their real size (FWM read a turned part's size as negative, so a turned wall could
--     count as small)
--   * the push and the turning work every frame of a climb (FWM only hooked them up when the stick moved, so holding
--     the stick still never pushed you into the ladder and you drifted off it); you keep facing the way you faced
--     when you grabbed (FWM turned you to the stick, off the ladder), and the push never points away from the wall
--   * across a gap between two rungs the climb holds on for CLIMB_GRACE (the kick still comes only when a rung is in
--     front, as FWM)
--   * back on the ground counts as landed (FWM waited for the Landed state itself, which can be missed, and then the
--     climbing stayed off)
local CLIMB_MAX_PART = 3.5      -- FWM: a part this big (on average) or this tall is not climbed
local CLIMB_KICK = 13           -- FWM: the upward speed each frame a part is in front
local CLIMB_PUSH = 24           -- FWM: the push along the stick while climbing
local CLIMB_START_SPEED = 0.35  -- (improved) a climb starts only while you are held back: slower than this share of WalkSpeed
local CLIMB_START_TIME = 0.15   -- ...for this long (seconds)
local CLIMB_START_FACING = 0.6  -- ...with the stick pointing where you face (at the part)
local CLIMB_CHEST = 2           -- (improved) studs above the climbing box: the chest box, where a wall shows up as big
local CLIMB_GRACE = 0.25        -- (improved) seconds a climb holds on across a gap between two rungs
local function startClimbingFWM(o)
    -- o: character, humanoid, rootPart, torso, isR15, hipBase() (R15: the body's own hip height), timePeriod,
    -- canStart() (FWM: not gliding, not tripped)
    local character, humanoid, rootPart, torso, isR15 = o.character, o.humanoid, o.rootPart, o.torso, o.isR15
    local damp = (o.timePeriod <= 14) and 0.8 or 0.4
    -- (Addtion-Scripts) let go of the stick and you drop: FWM's up to era 14, and asked for here too (o.dropOnRelease),
    -- as ladders didn't hold you until June 2014
    local dropOnRelease = o.dropOnRelease or o.timePeriod <= 14
    local RELEASE_GRACE = 0.15 -- seconds the stick can be let go (between thumb moves) before you drop
    local XZ = Vector3.new(1, 0, 1)
    local BOX = Vector3.new(1, 1, 1)
    local overlap = OverlapParams.new()
    overlap.FilterDescendantsInstances = { character, workspace.CurrentCamera }
    overlap.RespectCanCollide = true
    local lift = Instance.new("BodyVelocity") -- FWM's ClimbLift
    lift.Name = "ClimbLift"
    lift.Velocity = Vector3.new(0, 0, 0)
    lift.MaxForce = Vector3.new(5000, 0, 5000)
    lift.P = 1000
    local gyro = Instance.new("BodyGyro") -- FWM's ClimbGyro
    gyro.Name = "ClimbGyro"
    gyro.MaxTorque = Vector3.new(0, math.huge, 0)
    gyro.P = 4000
    gyro.D = 200
    local climbing, facing, lastGrab, blockedFor, dropping, alive = false, nil, 0, 0, false, true
    local releasedAt = nil -- when the stick was let go on Roblox's own ladders and trusses

    local function flatLook()
        local l = rootPart.CFrame.LookVector * XZ
        if l.Magnitude < 0.01 then return Vector3.new(0, 0, -1) end
        return l.Unit
    end
    -- FWM's box: 1 to 2 studs above the feet, just in front (R15: measured from the feet, as on R6)
    local function boxCFrame(up)
        local look = flatLook()
        if isR15 then
            local feet = rootPart.Position.Y - rootPart.Size.Y / 2 - o.hipBase()
            local ahead = rootPart.Position + look / 2
            return CFrame.new(ahead.X, feet + 1.5 + up, ahead.Z)
        end
        local p = torso.Position + look / 2
        return CFrame.new(p.X, p.Y - 1.5 + up, p.Z)
    end
    -- FWM's test, by the part's real size
    local function small(part)
        local s = part.CFrame:VectorToWorldSpace(part.Size)
        local x, y, z = math.abs(s.X), math.abs(s.Y), math.abs(s.Z)
        return not ((x + y + z) / 3 > CLIMB_MAX_PART or y >= CLIMB_MAX_PART)
    end
    local function partsAt(up)
        local ok, parts = pcall(function() return workspace:GetPartBoundsInBox(boxCFrame(up), BOX, overlap) end)
        return ok and parts or {}
    end
    local function smallIn(parts)
        for _, part in ipairs(parts) do
            if small(part) then return part end
        end
        return nil
    end
    -- (improved) trim on a wall is not a ladder: at chest height only something big (and nothing small) = a wall
    local function wallAbove()
        local parts = partsAt(CLIMB_CHEST)
        if #parts == 0 or smallIn(parts) then return false end
        return true
    end
    local function stickToward()
        local md = humanoid.MoveDirection * XZ
        if md.Magnitude < 0.01 then return false end
        return md.Unit:Dot(flatLook()) >= CLIMB_START_FACING
    end
    -- a part the climb could take hold of (the 2006 jump glide ends on one instead of bouncing you off it)
    local function canGrab(part)
        if dropping or not (part and part:IsA("BasePart") and part.CanCollide) then return false end
        return small(part) and stickToward() and smallIn(partsAt(0)) ~= nil and not wallAbove()
    end
    local function endClimb()
        climbing, facing = false, nil
        lift.Parent = nil
        gyro.Parent = nil
        if BPGenv.BPClimbing then BPGenv.BPClimbing = nil end
    end
    local function onGround()
        local st = humanoid:GetState()
        return st == Enum.HumanoidStateType.Landed or st == Enum.HumanoidStateType.Running
            or st == Enum.HumanoidStateType.RunningNoPhysics or humanoid.FloorMaterial ~= Enum.Material.Air
    end
    -- FWM's stopClimbing: off the ladder, and no climbing again until you are back on the ground
    local function drop()
        if dropping then return end
        dropping = true
        endClimb()
        task.spawn(function()
            local tries = 0
            repeat
                pcall(function()
                    humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
                    humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
                end)
                task.wait()
                tries = tries + 1
            until not alive or not humanoid.Parent or humanoid:GetState() ~= Enum.HumanoidStateType.Climbing or tries > 30
            local waited = 0
            while alive and humanoid.Parent and not onGround() and waited < 10 do
                waited = waited + (task.wait() or 1 / 60)
            end
            if humanoid.Parent then
                pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true) end)
            end
            dropping = false
        end)
    end

    local conn = RunService.RenderStepped:Connect(function(dt)
        if not alive or not character.Parent or humanoid.Health <= 0 then return end
        dt = math.min(dt or 1 / 60, 0.1)
        if dropping or humanoid.Sit or humanoid.SeatPart then
            if climbing then endClimb() end
            blockedFor = 0
            return
        end
        local now = os.clock()
        local md = humanoid.MoveDirection
        local moving = md.Magnitude > 0.01
        local part = moving and smallIn(partsAt(0)) or nil
        -- (Addtion-Scripts) Roblox's own ladder and truss climbing: before June 2014 it didn't hold you either, so
        -- letting go of the stick drops you off (as FWM's own climbing does with dropOnRelease)
        if not climbing and dropOnRelease and humanoid:GetState() == Enum.HumanoidStateType.Climbing then
            if md.Magnitude < 0.1 then
                releasedAt = releasedAt or now
                if now - releasedAt >= RELEASE_GRACE then releasedAt = nil drop() return end
            else
                releasedAt = nil
            end
        else
            releasedAt = nil
        end
        if not climbing then
            -- (improved) only while you walk into it and it holds you back, and not trim on a wall
            local speed = (rootPart.AssemblyLinearVelocity * XZ).Magnitude
            if part and o.canStart() and stickToward() and speed < humanoid.WalkSpeed * CLIMB_START_SPEED then
                blockedFor = blockedFor + dt
            else
                blockedFor = 0
            end
            if blockedFor >= CLIMB_START_TIME and not wallAbove() then
                climbing, facing, lastGrab = true, flatLook(), now
            end
            if not climbing then return end
            blockedFor = 0
        elseif not o.canStart() then
            -- (FWM: no climbing while jumping, tripped or gliding)
            endClimb()
            return
        end
        if part then
            -- FWM: the Climbing state, and the kick up
            lastGrab = now
            pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Climbing) end)
            local v = rootPart.AssemblyLinearVelocity
            rootPart.AssemblyLinearVelocity = v * (XZ * damp) + Vector3.new(0, CLIMB_KICK, 0)
        elseif now - lastGrab > CLIMB_GRACE then
            endClimb()
            return
        end
        -- FWM's handleClimbing, every frame of the climb
        if md.Magnitude < 0.1 then
            if dropOnRelease then drop() return end
            lift.Parent = nil
            gyro.Parent = nil
        else
            -- along the stick, never away from the wall; facing the way you grabbed
            local push = md * XZ
            local into = push:Dot(facing)
            if into < 0 then push = push - facing * into end
            lift.Velocity = push * CLIMB_PUSH
            gyro.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + facing)
            if lift.Parent ~= torso then lift.Parent = torso end
            if gyro.Parent ~= torso then gyro.Parent = torso end
        end
        BPGenv.BPClimbing = true -- (2007 Animation.lua reads this for its climbing pose)
    end)

    local function stop()
        alive = false
        conn:Disconnect()
        endClimb()
        pcall(function() lift:Destroy() end)
        pcall(function() gyro:Destroy() end)
        if dropping and humanoid.Parent then
            pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true) end)
        end
    end
    return {
        stop = stop,
        drop = drop,
        canGrab = canGrab,
        isClimbing = function() return climbing end,
    }
end

-- (Addtion-Scripts) TRAMPOLINES, as the Old physics has them: landing on a part whose name (or its parent's, or its
-- model's) has "trampoline" or "bounce" in it launches you up at 2.4 times the speed you fell at (50 to 300 studs a
-- second), instead of any landing of the physics' own.
local function startTrampolines(character, humanoid, rootPart)
    local lastFallSpeed = 0
    local conn = RunService.Heartbeat:Connect(function()
        if not character.Parent then return end
        local v = rootPart.AssemblyLinearVelocity
        if v.Y < -2 then lastFallSpeed = -v.Y end
    end)
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances = { character }
    local function has(name)
        name = string.lower(tostring(name or ""))
        return name:find("trampoline", 1, true) ~= nil or name:find("bounce", 1, true) ~= nil
    end
    local function isTrampoline(part)
        if has(part.Name) or (part.Parent and has(part.Parent.Name)) then return true end
        local model = part:FindFirstAncestorWhichIsA("Model")
        return model ~= nil and has(model.Name)
    end
    -- on a landing: true if a trampoline launched you
    local function onLanded()
        local fall = lastFallSpeed
        lastFallSpeed = 0
        local ok, hit = pcall(function() return workspace:Raycast(rootPart.Position, Vector3.new(0, -6, 0), ray) end)
        local part = ok and hit and hit.Instance
        if not (part and isTrampoline(part)) then return false end
        local launch = math.clamp(math.max(fall, 35) * 0.6 * 4, 50, 300)
        pcall(function()
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        end)
        local v = rootPart.AssemblyLinearVelocity
        rootPart.AssemblyLinearVelocity = Vector3.new(v.X, launch, v.Z)
        return true
    end
    return onLanded, function() conn:Disconnect() end
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

    -- (Addtion-Scripts) trampolines (see TRAMPOLINES above), stopped with the rest
    local trampolineLanding, stopTrampolines = startTrampolines(character, humanoid, rootPart)
    table.insert(activeConnections, {
        Connected = true,
        Disconnect = function(self)
            self.Connected = false
            stopTrampolines()
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
        -- (Addtion-Scripts) FWM's climbing handler: see CLIMBING above (it runs every frame of a climb)
    end

    local function checkIfTrippedState()
        local state = humanoid:GetState()
        return state == Enum.HumanoidStateType.Ragdoll
            or state == Enum.HumanoidStateType.FallingDown
            or state == Enum.HumanoidStateType.Jumping
            or humanoid.Sit
            or state == Enum.HumanoidStateType.Swimming
    end

    -- (Addtion-Scripts) the climbing, FWM's improved (see CLIMBING above): not while gliding or tripped, as FWM
    local climbFWM = startClimbingFWM({
        character = character, humanoid = humanoid, rootPart = rootPart, torso = torso, isR15 = isR15,
        timePeriod = timePeriod,
        hipBase = function() return r15HipHeight end,
        canStart = function() return glideVelocity.Parent == nil and not checkIfTrippedState() end,
    })
    table.insert(activeConnections, {
        Connected = true,
        Disconnect = function(self)
            self.Connected = false
            climbFWM.stop()
        end,
    })

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

    -- (Addtion-Scripts) FWM's landing bounce holds off the falling state until you're back on the ground (a second at
    -- most): otherwise every animation (ours, Bloxy's R6 and R15 ones) takes the bounce for a fall and puts the arms
    -- back up (the user's recording: down, up again, down)
    local fallHeld = false
    local function holdOffFall()
        if fallHeld then return end
        fallHeld = true
        pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false) end)
        task.spawn(function()
            local t0, left = os.clock(), false
            while fallHeld and humanoid.Parent and os.clock() - t0 < 1 do
                if humanoid.FloorMaterial == Enum.Material.Air then
                    left = true
                elseif left then
                    break
                end
                task.wait()
            end
            if fallHeld then
                fallHeld = false
                pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true) end)
            end
        end)
    end
    table.insert(activeConnections, {
        Connected = true,
        Disconnect = function(self)
            self.Connected = false
            if fallHeld then
                fallHeld = false
                pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true) end)
            end
        end,
    })

    local function forceVelocity(upwardSpeed)
        -- (Addtion-Scripts) for the 2007 animation: this throws you up as a landing bounce, not a fall, so it keeps
        -- the arms coming down instead of putting them back up
        BPGenv.BPLandingBounce = os.clock()
        holdOffFall() -- (and no falling state for it: see above)
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

            -- (Addtion-Scripts) a trampoline under the feet launches you, as on the Old physics; nothing else happens
            -- (and the next landing counts as the first again, as after a jump)
            if trampolineLanding() then
                landCount = 0
                return
            end

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
            if climbFWM.isClimbing() or humanoid:GetState() == Enum.HumanoidStateType.Climbing then
                climbFWM.drop() -- (FWM: jumping lets go of the ladder)
                return
            end
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
            fwmClimbValue.Value = climbFWM.isClimbing() or humanoid:GetState() == Enum.HumanoidStateType.Climbing
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

        -- (Addtion-Scripts) the sway fades the same at any frame rate: FWM's 0.9 + dt stopped fading at all on a slow
        -- frame (a tenth of a second), and with a tool in hand the turning then fed it until it spun you round
        targetSway = targetSway * (0.9 + math.min(dt, 0.05)) + (torso.AssemblyAngularVelocity.Y / 2000) * toolMass
        currentSway = ExtraUtil.Lerp(currentSway, targetSway, 0.3)

        -- (Addtion-Scripts) the lean and the landing tilt only while there is one to give, and turned on the body's root
        -- (HumanoidRootPart). FWM set the torso's CFrame to itself every frame, also with nothing to lean: the torso's
        -- CFrame holds what the walk animation does to the waist joint, so writing it back turned the whole body by that
        -- again every frame you walked, a spin (holding left, right or up: the user's recording). FWM's own animations
        -- don't turn that joint; other games' and Bloxy's can. (The 2008 physics already only leans when there is one.)
        if not checkIfTrippedState() and (isTilting or math.abs(currentSway) > 0.0001) then
            local rollDivisor = torso.AssemblyAngularVelocity.Y < 0 and 2.5 or 5
            local pitchAngle = -currentSway / 5
            if isTilting then
                pitchAngle = -math.rad(currentTilt) - currentSway / 5
            end
            local body = rootPart or torso
            body.CFrame = body.CFrame * cf.fromEulerAnglesXYZ(pitchAngle, 0, currentSway / rollDivisor)
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
                -- (Addtion-Scripts) a part the climbing can take hold of: the glide ends, so you grab it instead of
                -- being bounced off it
                if climbFWM.canGrab(hit) then
                    glideVelocity.Parent = nil
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