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

-- (Addtion-Scripts) CAMERA: the classic camera while this is on. 2006's camera stayed where you put it; on a phone
-- Roblox's camera follows behind you by default ("Follow", the touch default when the game leaves it to the player).
-- With Roblox's own turning (FWM's), holding the stick to the side then turned you after the camera and the camera
-- after you, round and round: the spin "in some games" (the ones that leave the camera mode to the player). FWM's game
-- has the classic one. Put back when this stops.
local cameraWas = nil
local function useClassicCamera()
    if cameraWas or not LocalPlayer then return end
    cameraWas = {}
    pcall(function()
        cameraWas.touch = LocalPlayer.DevTouchCameraMode
        LocalPlayer.DevTouchCameraMode = Enum.DevTouchCameraMovementMode.Classic
    end)
    pcall(function()
        cameraWas.computer = LocalPlayer.DevComputerCameraMode
        LocalPlayer.DevComputerCameraMode = Enum.DevComputerCameraMovementMode.Classic
    end)
    -- (if the game's setting can't be changed from here: the player's own camera setting, put back after too)
    local took = false
    pcall(function() took = LocalPlayer.DevTouchCameraMode == Enum.DevTouchCameraMovementMode.Classic end)
    if not took then
        pcall(function()
            local settings = UserSettings():GetService("UserGameSettings")
            cameraWas.userTouch = settings.TouchCameraMovementMode
            settings.TouchCameraMovementMode = Enum.TouchCameraMovementMode.Classic
        end)
    end
end
local function putCameraBack()
    local was = cameraWas
    cameraWas = nil
    if not was or not LocalPlayer then return end
    if was.touch ~= nil then pcall(function() LocalPlayer.DevTouchCameraMode = was.touch end) end
    if was.computer ~= nil then pcall(function() LocalPlayer.DevComputerCameraMode = was.computer end) end
    if was.userTouch ~= nil then
        pcall(function() UserSettings():GetService("UserGameSettings").TouchCameraMovementMode = was.userTouch end)
    end
end
useClassicCamera()

local walkLockOn = nil -- (Addtion-Scripts) whether the walking direction lock could start (see below)
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
-- (Addtion-Scripts) THE WOBBLY OLD-CLIENT FEEL (the user: "keep the easy climbing, but wobbly like actual old clients,
-- you can move anywhere"). The climb still starts as easily, but while on it:
--   * the stick moves you any way, sideways and away too (it used to be held to the wall), and your sideways speed is
--     only lightly held back (it was cut by a fifth every frame, which pinned you in place),
--   * you turn after the stick, loosely, instead of staying locked to the way you grabbed,
--   * the body rocks and tilts a little as you go (more while moving), and the climb speed bobs a little,
--     as the old physics did, instead of gliding up at one perfectly even speed
local CLIMB_SIDE_KEEP = 0.95    -- share of the sideways speed kept each 1/60 s while on a rung (was 0.8 a frame)
local CLIMB_TURN_RATE = 3       -- radians a second you turn after the stick while climbing
local CLIMB_WOBBLE_DEG = 7      -- how far the body rocks and tilts while climbing and moving (half that when still)
local CLIMB_WOBBLE_HZ = 2.2     -- how fast it rocks
local CLIMB_BOB = 0.22          -- the climb speed bobs this share up and down
local CLIMB_BOB_HZ = 2.6
local CLIMB_WOBBLE_TORQUE = 6000 -- how hard the rocking is pushed (a loose push: the body sways, it isn't held still)
local function startClimbingFWM(o)
    -- o: character, humanoid, rootPart, torso, isR15, hipBase() (R15: the body's own hip height), timePeriod,
    -- canStart() (FWM: not gliding, not tripped)
    local character, humanoid, rootPart, torso, isR15 = o.character, o.humanoid, o.rootPart, o.torso, o.isR15
    local damp = (o.timePeriod <= 14) and 0.8 or 0.4
    local wobbleT = 0 -- (Addtion-Scripts) the time on the climb, for the rocking and the bob
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
    -- (Addtion-Scripts) a loose hold on the tilt too, for the old rocking (the turning stays firm: no spinning)
    gyro.MaxTorque = Vector3.new(CLIMB_WOBBLE_TORQUE, math.huge, CLIMB_WOBBLE_TORQUE)
    gyro.P = 2500
    gyro.D = 220
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
        wobbleT = 0
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
            -- (Addtion-Scripts) the climb speed is eased to, not set each frame: the kick every frame, off and on between rungs,
            -- made the climb hop (the user: climbing a bit more smooth)
            local easeUp = 1 - math.exp(-9 * dt)
            -- (the wobbly feel: the speed bobs a little, and sideways you keep most of your speed)
            local kick = CLIMB_KICK * (1 + CLIMB_BOB * math.sin(wobbleT * CLIMB_BOB_HZ * 2 * math.pi))
            local keep = CLIMB_SIDE_KEEP ^ (dt * 60)
            rootPart.AssemblyLinearVelocity = v * (XZ * keep) + Vector3.new(0, v.Y + (kick - v.Y) * easeUp, 0)
        elseif now - lastGrab > CLIMB_GRACE then
            endClimb()
            return
        else
            -- (a gap between two rungs, inside the grace: the climb carries on at its speed instead of stalling)
            local v = rootPart.AssemblyLinearVelocity
            local keep = CLIMB_SIDE_KEEP ^ (dt * 60)
            rootPart.AssemblyLinearVelocity = Vector3.new(v.X * keep, v.Y + (CLIMB_KICK - v.Y) * (1 - math.exp(-8 * dt)), v.Z * keep)
        end
        -- FWM's handleClimbing, every frame of the climb
        wobbleT = wobbleT + dt
        if md.Magnitude < 0.1 then
            if dropOnRelease then drop() return end
            lift.Parent = nil
            gyro.Parent = nil
        else
            -- (Addtion-Scripts) the wobbly old feel: the stick moves you any way (sideways, up, away), and you turn
            -- after it loosely instead of staying locked to the way you grabbed
            local push = md * XZ
            lift.Velocity = push * CLIMB_PUSH
            if push.Magnitude > 0.01 then
                local want = push.Unit
                local cosA = math.clamp(facing:Dot(want), -1, 1)
                local angle = math.acos(cosA)
                local step = math.min(angle, CLIMB_TURN_RATE * dt)
                if angle > 1e-3 then
                    local sideSign = (facing:Cross(want).Y >= 0) and 1 or -1
                    facing = (CFrame.Angles(0, sideSign * step, 0) * facing).Unit
                end
            end
            -- the body rocks and tilts a little as you climb (more while you move)
            local amount = math.rad(CLIMB_WOBBLE_DEG) * math.clamp(0.5 + (rootPart.AssemblyLinearVelocity * XZ).Magnitude / 16, 0.5, 1)
            local w = wobbleT * CLIMB_WOBBLE_HZ * 2 * math.pi
            gyro.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + facing)
                * CFrame.Angles(amount * 0.6 * math.sin(w * 0.7 + 1.3), 0, amount * math.sin(w))
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

-- (Addtion-Scripts) WALKING DIRECTION LOCK: the 2008 physics' lock (you keep the way you jumped until you land)
-- carried onto the ground. Press the stick and the way you walk is locked in the world: it turns when you turn the
-- stick, or when you turn the camera yourself (dragging it, the mouse, the arrow keys, a gamepad's right stick), and
-- never when the camera turns by itself. Walking is relative to the camera, so with a camera that turns after you as
-- you walk (the 2007 camera, any camera on Follow, Roblox's own Follow mode) holding left, right or back went round
-- and round: the camera turned after you, your "left" turned with it and so did your body (it faces where you walk);
-- close up, a spin on the spot. Holding forward was the only way it stopped. Now holding left walks straight left.
-- Let go of the stick and it is unlocked. Not while climbing, sitting, swimming or tripped. The cameras themselves
-- are not changed.
local LOCK_PAN_GRACE = 0.25 -- seconds after the player turned the camera that its turning still steers
-- (Addtion-Scripts) THE WAY YOU WALK TURNS SMOOTHLY: the body turns to face the way it is walking, so a stick flicked to the
-- side and back, or a camera dragged quickly, swung the body 90 degrees in a fifth of a second and straight back (the user,
-- twice: "don't make it swing like that, make it more smooth, don't make it go back like it recognized its mistake").
-- The way handed to the humanoid now eases towards the way the stick points: at most TURN_RATE radians a second, easing in
-- over about 1 / TURN_EASE of a second, so a quick flick hardly moves it and a real turn takes its time. Roblox's own turning
-- still does the turning, to a way that no longer jumps. getgenv().BP2006TurnRate / BP2006TurnEase change them.
local TURN_RATE = 5.5 -- radians a second: the fastest the way (and so the body) goes round
local TURN_EASE = 9   -- the way closes the rest of a turn in about a ninth of a second
local TURN_ACCEL = 25 -- radians a second, each second: how quickly it gets up to that speed (and back down from it): a flick of
                      -- a tenth of a second moves the way by about 15 degrees, not 90
local function startWalkLock(o)
    -- o: humanoid, isOff() (true while the lock must stay out of the way)
    local humanoid, isOff = o.humanoid, o.isOff
    local controls = nil
    pcall(function()
        local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
        local module = scripts and scripts:FindFirstChild("PlayerModule")
        if module then controls = require(module):GetControls() end
    end)
    if not (type(controls) == "table" and type(controls.GetMoveVector) == "function") then
        return nil -- (a game with controls of its own: there is no stick to read, and walking is left as it is)
    end
    local alive = true
    local lockedDir, lastStick, lastYaw = nil, nil, nil
    local smoothDir, lastEaseAt, smoothW = nil, nil, 0 -- (the way handed to the humanoid: lockedDir, eased; how fast it is going round)
    local lastPan, lastMousePan = -1, -1
    local cameraTouches = {}
    local conns = {}
    local function viewportWidth()
        local cam = workspace.CurrentCamera
        return cam and cam.ViewportSize.X or 1000
    end
    table.insert(conns, UserInputService.InputBegan:Connect(function(input, processed)
        -- (a touch away from the thumbstick, on the right part of the screen, turns the camera)
        if input.UserInputType == Enum.UserInputType.Touch and not processed
            and input.Position.X > viewportWidth() * 0.4 then
            cameraTouches[input] = true
        end
    end))
    table.insert(conns, UserInputService.InputEnded:Connect(function(input)
        if cameraTouches[input] then
            cameraTouches[input] = nil
            -- (finger up: the camera turning from now on is its own again)
            if next(cameraTouches) == nil then lastPan = -1 end
        end
    end))
    table.insert(conns, UserInputService.InputChanged:Connect(function(input)
        local kind = input.UserInputType
        if kind == Enum.UserInputType.Touch then
            if cameraTouches[input] then lastPan = os.clock() end
        elseif kind == Enum.UserInputType.MouseMovement then
            if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
                or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                lastMousePan = os.clock()
            end
        elseif input.KeyCode == Enum.KeyCode.Thumbstick2 and input.Position.Magnitude > 0.2 then
            lastMousePan = os.clock()
        end
    end))
    local function keysTurningCamera()
        return UserInputService:IsKeyDown(Enum.KeyCode.Left) or UserInputService:IsKeyDown(Enum.KeyCode.Right)
            or UserInputService:IsKeyDown(Enum.KeyCode.Comma) or UserInputService:IsKeyDown(Enum.KeyCode.Period)
    end
    -- the player turning the camera now: a finger on the camera part of the screen (moved in the last moment), the
    -- mouse or a gamepad's right stick just now, or the arrow keys held
    local function playerTurningCamera()
        local now = os.clock()
        if next(cameraTouches) ~= nil and now - lastPan < LOCK_PAN_GRACE then return true end
        if now - lastMousePan < 0.1 then return true end
        return keysTurningCamera()
    end
    local function cameraLook()
        local cam = workspace.CurrentCamera
        if not cam then return nil end
        local l = cam.CFrame.LookVector
        local flat = Vector3.new(l.X, 0, l.Z)
        if flat.Magnitude < 1e-3 then return nil end
        return flat.Unit
    end
    -- (turning right on the screen: from looking along -Z towards +X)
    local function turnRight(v, a)
        local c, s = math.cos(a), math.sin(a)
        return Vector3.new(v.X * c - v.Z * s, 0, v.X * s + v.Z * c)
    end
    local function wrap(a) return (a + math.pi) % (2 * math.pi) - math.pi end
    -- the stick (or keys) as the controls have it: on the screen, x to the right, z backwards
    local function stickNow()
        local ok, flat = pcall(function()
            local raw = controls:GetMoveVector()
            return Vector3.new(raw.X, 0, raw.Z)
        end)
        if not ok or not flat or flat.Magnitude < 0.05 then return nil end
        return flat
    end
    local function walk(stick)
        humanoid:Move((smoothDir or lockedDir) * math.min(stick.Magnitude, 1), false)
    end
    -- smoothDir goes round towards lockedDir: the angle is that of turnRight (from -Z towards +X)
    local function easeWay()
        local now = os.clock()
        local dt = lastEaseAt and math.clamp(now - lastEaseAt, 0, 0.1) or 0
        lastEaseAt = now
        local rate = tonumber(getgenv().BP2006TurnRate) or TURN_RATE
        local ease = tonumber(getgenv().BP2006TurnEase) or TURN_EASE
        local accel = tonumber(getgenv().BP2006TurnAccel) or TURN_ACCEL
        if not smoothDir then
            -- (starting to walk: from the way the body faces, so it turns into the walk instead of being swung round)
            local from = nil
            pcall(function()
                local root = humanoid.RootPart
                local l = root and root.CFrame.LookVector
                if l and (l.X * l.X + l.Z * l.Z) > 1e-4 then from = Vector3.new(l.X, 0, l.Z).Unit end
            end)
            smoothDir = from or lockedDir
            smoothW = 0
        end
        local v, t = smoothDir, lockedDir
        local angle = math.atan2(v.X * t.Z - v.Z * t.X, v.X * t.X + v.Z * t.Z)
        if math.abs(angle) < 1e-4 then
            smoothDir, smoothW = t, 0
            return
        end
        -- the speed it wants (the rest of the turn, at most TURN_RATE), reached no quicker than TURN_ACCEL allows
        local want = math.clamp(angle * ease, -rate, rate)
        local dw = math.clamp(want - smoothW, -accel * dt, accel * dt)
        smoothW = smoothW + dw
        local move = smoothW * dt
        -- (never past the way: it stops on it)
        if (angle > 0 and move > angle) or (angle < 0 and move < angle) then move, smoothW = angle, 0 end
        smoothDir = turnRight(v, move)
        local m = smoothDir.Magnitude
        if m > 1e-6 then smoothDir = smoothDir / m else smoothDir = t end
    end
    local function step()
        if not alive then return end
        local stick = stickNow()
        local look = cameraLook()
        if not stick or not look or isOff() then
            lockedDir, lastStick = nil, nil
            smoothDir, lastEaseAt, smoothW = nil, nil, 0
            lastYaw = look and math.atan2(look.X, -look.Z) or nil
            return
        end
        local stickAngle = math.atan2(stick.X, -stick.Z) -- 0 forward, more to the right on the screen
        local yaw = math.atan2(look.X, -look.Z)
        if not lockedDir then
            -- pressed: this way from where the camera looks now, kept in the world
            local right = Vector3.new(-look.Z, 0, look.X)
            local dir = look * -stick.Z + right * stick.X
            lockedDir = Vector3.new(dir.X, 0, dir.Z).Unit
        else
            -- the stick turned: the way turns as much
            lockedDir = turnRight(lockedDir, wrap(stickAngle - lastStick))
            -- the player turned the camera: that still steers, as it always did
            if lastYaw and playerTurningCamera() then
                lockedDir = turnRight(lockedDir, wrap(yaw - lastYaw))
            end
        end
        lastStick, lastYaw = stickAngle, yaw
        easeWay()
        walk(stick)
    end
    local name = "BP2006WalkLock" .. tostring(math.random(1, 1000000000))
    -- right after the controls move you (Roblox's at Input, the mobile controls one after), so this way is kept
    RunService:BindToRenderStep(name, Enum.RenderPriority.Input.Value + 2, step)
    -- and again just before the physics step, after anything else that moved you later in the frame
    table.insert(conns, RunService.Stepped:Connect(function()
        if not (alive and lockedDir) or isOff() then return end
        local stick = stickNow()
        if stick then walk(stick) end
    end))
    return function()
        alive = false
        pcall(function() RunService:UnbindFromRenderStep(name) end)
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        table.clear(conns)
    end
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
    local lastLandAt = -math.huge -- (when the body last landed: the turn cap below only applies just after a landing)
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

    -- (Addtion-Scripts) WHAT TURNS AND TILTS THE BODY ON A JUMP: FWM put its glide, its sideways stop and its landing bounce on the
    -- torso (BodyVelocity, a force of 9,000,000,000). In FWM's own character a constraint on the torso (TorsoAttach.AngularTilt)
    -- holds the body steady against it; any other game's character has none, and a huge force on a part that is not at the
    -- body's centre is a huge turning force: the little tilt when you walk and jump, and the spin on a jump (the user's
    -- recordings). They are on the HumanoidRootPart now (the body's own centre: nothing for them to turn), and the body's
    -- own turning is held at zero while one of them pushes.
    local pushPart = rootPart or torso
    local fallLocked = false
    local landEaseUntil, landEaseOn = 0, false -- (after a landing the body eases round to where you walk: see THE LANDING TURN)
    local airYaw = nil -- (the way the body faced as it left the ground: it keeps facing it until it lands, see THE AIR LOCK)
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

    -- (Addtion-Scripts) the walking direction lock (see WALKING DIRECTION LOCK above)
    local noLockStates = {
        [Enum.HumanoidStateType.Climbing] = true, [Enum.HumanoidStateType.Swimming] = true,
        [Enum.HumanoidStateType.Seated] = true, [Enum.HumanoidStateType.Dead] = true,
        [Enum.HumanoidStateType.FallingDown] = true, [Enum.HumanoidStateType.Ragdoll] = true,
        [Enum.HumanoidStateType.Physics] = true, [Enum.HumanoidStateType.GettingUp] = true,
        [Enum.HumanoidStateType.PlatformStanding] = true,
    }
    -- (off: with it the stick's way was kept in the world instead of following the camera, and the controls felt
    -- wrong, the user said. The original FWM script leaves walking and turning to Roblox's own controls, and so does
    -- this; the spin it had in some games was the camera following behind you: see CAMERA at the top.)
    local USE_WALK_LOCK = false
    local stopWalkLock = USE_WALK_LOCK and startWalkLock({
        humanoid = humanoid,
        isOff = function()
            if humanoid.Health <= 0 or humanoid.Sit or humanoid.SeatPart or humanoid.PlatformStand then return true end
            if climbFWM.isClimbing() or checkIfTrippedState() then return true end
            return noLockStates[humanoid:GetState()] == true
        end,
    }) or nil
    if USE_WALK_LOCK and walkLockOn == nil and not stopWalkLock then
        print("[2006 Physics] the walking direction lock is off: this game has controls of its own (no stick to read)")
    end
    walkLockOn = stopWalkLock ~= nil
    if stopWalkLock then
        table.insert(activeConnections, {
            Connected = true,
            Disconnect = function(self)
                self.Connected = false
                stopWalkLock()
            end,
        })
    end

    local landTilt, landDip = 0, 0 -- (the landing tip and dip: see applyRootPose)
    local shownTilt, shownDip = 0, 0 -- (what is drawn: eased toward them, so nothing snaps)
    local LAND_TILT = 12      -- degrees aimed at landing at walking speed (FWM: speed / 16 * 9; eased in it shows about half way: 6)
    local LAND_TILT_MAX = 14
    local LAND_DIP = -0.4     -- studs into the ground on landing
    local FALL_OVER_SPEED = 110 -- (a landing this fast, from a high place: you fall over, as in the reference)
    local function triggerTilt()
        if not isTilting then
            isTilting = true
            task.spawn(function()
                tiltStopVel.Parent = pushPart
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
                tiltAngleTarget = tiltAngleTarget * (0.88 - (task.wait(0) or 0.016))
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

    -- the body's own turning held at zero (no tilt, no spin) while a push is on it
    local function noTurn(part)
        pcall(function()
            local w = part.AssemblyAngularVelocity
            if w.X ~= 0 or w.Y ~= 0 or w.Z ~= 0 then part.AssemblyAngularVelocity = Vector3.new(0, 0, 0) end
        end)
    end

    local function forceVelocity(upwardSpeed)
        -- (Addtion-Scripts) for the 2007 animation: this throws you up as a landing bounce, not a fall, so it keeps
        -- the arms coming down instead of putting them back up
        BPGenv.BPLandingBounce = os.clock()
        holdOffFall() -- (and no falling state for it: see above)
        local bv = ExtraUtil.Create("BodyVelocity", {
            MaxForce = Vector3.new(0, 9000000000, 0),
            Parent = pushPart,
            Velocity = Vector3.new(0, 1, 0) * upwardSpeed,
        })
        RunService.Heartbeat:Wait()
        noTurn(pushPart)
        RunService.Heartbeat:Wait()
        noTurn(pushPart)
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
            local lv = pushPart.CFrame.LookVector
            airYaw = math.atan2(-lv.X, -lv.Z)
            glideVelocity.Parent = pushPart
        end
    end

    local function onStateChanged(_, newState)
        if newState == Enum.HumanoidStateType.Landed then
            autoRotateTime = os.clock() + 0.25
            lastLandAt = os.clock()
            landEaseUntil = os.clock() + 0.5
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
                -- (Addtion-Scripts) the landing as in the user's reference: walking and jumping, you land tipping forward
                -- (the faster, the more), then stand up again; a jump on the spot doesn't tip. Every jump's landing goes
                -- a little into the ground and comes back up. Both are a look (the root joint, about the feet), so they
                -- always show and can't turn you.
                if timePeriod <= 14 then
                    local horiz = (torso.AssemblyLinearVelocity * xzVector).Magnitude
                    if horiz > 4 then
                        landTilt = math.min(LAND_TILT_MAX, horiz / 16 * LAND_TILT)
                        task.spawn(triggerTilt) -- (FWM's: stops your sideways speed as you land)
                    end
                    landDip = LAND_DIP
                    if velY <= -FALL_OVER_SPEED then
                        pcall(function()
                            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                            humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
                        end)
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

    local currentSquash = 0
    local currentTilt = 0

    -- (Addtion-Scripts) SPIN GUARD: the body going round one way faster than SPIN_RATE for SPIN_TIME is a spin, not a
    -- turn (turning to where you walk is half a turn at most, so it can never last that long), whatever is doing it:
    -- for SPIN_HOLD the body is then held still, facing where you walk (or the way it faced, with the stick let go),
    -- and the console says once what was turning it. On the ground (and in the 2006 jump glide); not while climbing,
    -- sitting, tripped or flung.
    local SPIN_RATE = 8     -- radians a second (more than a turn every 0.8 s)
    local SPIN_TIME = 0.4   -- seconds (more than half a turn at that speed)
    local SPIN_HOLD = 0.5   -- seconds held
    local TURN_LIMIT = 5   -- radians a second: the fastest the body is ever seen to turn (see below)
    local TURN_LIMIT_WINDOW = 1.0 -- seconds after a landing that the cap applies: walking turns are Roblox's own
    local SPIN_TURN = 1.25 * math.pi -- radians: going round this far one way is a spin at any speed (turning to where you walk is
                                    -- half a turn at most), the user's spin was slower than SPIN_RATE
    local GROUND_STATES = {
        [Enum.HumanoidStateType.Running] = true,
        [Enum.HumanoidStateType.RunningNoPhysics] = true,
        [Enum.HumanoidStateType.Landed] = true,
    }
    local lastYaw, spinFor, spinSign, holdUntil, holdLook, spinReported = nil, 0, 0, 0, nil, false
    local spinAccum, holdYaw, airSpinReported = 0, nil, false
    local lastStickYaw = nil -- (where the stick pointed last frame: a body that goes round with a stick going round is turning)
    local stickMoving = 0 -- (how fast the stick has been swinging round lately, rad/s, smoothed over about 0.1 s)
    local function flatLookOf(cframe)
        local look = cframe.LookVector * xzVector
        if look.Magnitude < 0.01 then return nil end
        return look.Unit
    end
    local function yawOf(look)
        return math.atan2(-look.X, -look.Z)
    end
    local function whatTurns()
        local found = {}
        for _, d in ipairs(character:GetDescendants()) do
            if d:IsA("BodyGyro") or d:IsA("BodyAngularVelocity") or d:IsA("AlignOrientation")
                or d:IsA("AngularVelocity") or d:IsA("Torque") then
                local on = true
                pcall(function() if d.Enabled == false then on = false end end)
                if on then table.insert(found, d.ClassName .. " " .. d.Name .. " (in " .. tostring(d.Parent and d.Parent.Name) .. ")") end
            end
        end
        table.insert(found, "AutoRotate " .. tostring(humanoid.AutoRotate))
        if glideVelocity.Parent then table.insert(found, "the jump glide") end
        if isTilting then table.insert(found, "the landing tilt") end
        if character:FindFirstChildWhichIsA("Tool") then table.insert(found, "a tool in hand") end
        return table.concat(found, ", ")
    end
    -- (Addtion-Scripts) THE TURN IS ROBLOX'S OWN, as in FWM at this time period (FWM never touches AutoRotate below 14): you turn
    -- to face the way you walk the way Roblox always turns you. Custom turns of ours (a spring, a turning speed through
    -- physics, a capped CFrame turn) were each rejected in the user's recordings: too quick, held the body, could not turn.
    local function spinGuard(dt)
        local body = rootPart or torso
        if not body or not body.Parent or not dt or dt <= 0 then return end
        local state = humanoid:GetState()
        local guarded = GROUND_STATES[state] or state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall
        if not guarded or climbFWM.isClimbing() or humanoid.Sit or humanoid.PlatformStand or checkIfTrippedState()
            or humanoid.Health <= 0 then
            lastYaw, spinFor, lastStickYaw, spinAccum, holdYaw, stickMoving = nil, 0, nil, 0, nil, 0
            return
        end
        local look = flatLookOf(body.CFrame)
        if not look then return end
        -- (Addtion-Scripts) FALLING: whatever the fall does to the body, it is never allowed to spin fast: the turn is held to a
        -- gentle 3 radians a second and any tumble (round the other axes) is taken out (the user: when you fall the spinning
        -- goes crazy). On the ground it is left to the guards below.
        if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
            local w = body.AssemblyAngularVelocity or Vector3.new(0, 0, 0)
            local wy = math.clamp(w.Y, -3, 3)
            if wy ~= w.Y or math.abs(w.X) > 0.01 or math.abs(w.Z) > 0.01 then
                body.AssemblyAngularVelocity = Vector3.new(0, wy, 0)
            end
        end
        local now = os.clock()
        if now < holdUntil then
            -- (held, but never frozen or snapped: the body is set, every frame, to a facing that eases round to where you
            -- walk (or the way it faced, with the stick let go), so whatever is turning it can't, and it never jumps)
            local md = humanoid.MoveDirection * xzVector
            local want = md.Magnitude > 0.1 and md.Unit or holdLook or look
            local v = body.AssemblyAngularVelocity
            body.AssemblyAngularVelocity = Vector3.new(v.X, 0, v.Z)
            local curYaw = yawOf(look)
            holdYaw = holdYaw or curYaw
            local toWant = (yawOf(want) - holdYaw + math.pi) % (2 * math.pi) - math.pi
            holdYaw = holdYaw + math.clamp(toWant * (1 - math.exp(-14 * dt)), -9 * dt, 9 * dt)
            local fix = (holdYaw - curYaw + math.pi) % (2 * math.pi) - math.pi
            if math.abs(fix) > 0.0005 then
                local cf0 = body.CFrame
                local pos = cf0.Position
                body.CFrame = CFrame.new(pos) * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), fix) * (CFrame.new(-pos) * cf0)
            end
            lastYaw, spinFor, spinAccum = holdYaw, 0, 0
            return
        end
        holdYaw = nil
        local yaw = yawOf(look)
        if lastYaw then
            local turned = (yaw - lastYaw + math.pi) % (2 * math.pi) - math.pi
            -- (where the stick points, and how fast it is swinging round)
            local mdv = humanoid.MoveDirection * xzVector
            local stickRate = 0
            if mdv.Magnitude > 0.1 then
                local stickYaw = yawOf(mdv.Unit)
                if lastStickYaw then stickRate = ((stickYaw - lastStickYaw + math.pi) % (2 * math.pi) - math.pi) / dt end
                lastStickYaw = stickYaw
            else
                lastStickYaw = nil
            end
            stickMoving = stickMoving * 0.85 + math.abs(stickRate) * 0.15
            -- (Addtion-Scripts) THE FASTEST TURN: Roblox's own turning is quick, and the moment a jump ends (the air lock held the
            -- body facing the way it jumped, and the stick has moved since) it swung the body round at 15 to 23 radians a second,
            -- 2 to 4 turns a second: the spin after every jump (the readout, in the user's recording). Whatever turns the body
            -- (Roblox's turning, a gyro, anything), it is never seen to turn faster than TURN_LIMIT: what is over is taken back
            -- each frame, so it eases round to where you walk instead. Ordinary turning (a few radians a second) is not touched.
            -- (a body set to a new facing in one frame - over 1.2 radians - is a teleport or a script facing it somewhere, not
            -- turning: that is left as it is). Not while the stick is itself swinging round (spinning the stick): the body has to
            -- keep up with it or it falls more than half a turn behind and goes back and forth, the user's "what is this" when
            -- spinning; it is for the body catching up with a stick that is still.
            -- (And only a turn the physics is making - the body's own turning speed matches it - not a script setting the facing.)
            local maxStep = TURN_LIMIT * dt
            local spinW = body.AssemblyAngularVelocity
            local spinNow = spinW and spinW.Y or 0
            local physical = spinNow * turned > 0 and math.abs(spinNow) > 0.4 * math.abs(turned / dt)
            -- (Addtion-Scripts) ONLY JUST AFTER A LANDING: that is the spin it was made for. On the ground, walking, the cap
            -- slowed every turn and pulled the body back by the excess each frame, so a turn started, was held back, and the
            -- body looked to turn and go back (the user's video): walking turns are Roblox's own now)
            local justLanded = now - lastLandAt < TURN_LIMIT_WINDOW
            if justLanded and math.abs(turned) > maxStep and math.abs(turned) < 1.2 and humanoid.AutoRotate and stickMoving < 1.5 and physical then
                local excess = turned - (turned > 0 and maxStep or -maxStep)
                local cf0 = body.CFrame
                local pos = cf0.Position
                body.CFrame = CFrame.new(pos) * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), -excess) * (CFrame.new(-pos) * cf0)
                yaw = yaw - excess
                turned = turned - excess
            end
            local rate = turned / dt
            local sign = rate > 0 and 1 or -1
            -- (going round with a stick that is going round is Roblox's normal turning, however fast you swing the stick: not a
            -- spin. A spin goes round with the stick still, or against it.)
            local followsStick = stickRate ~= 0 and stickRate * rate > 0 and math.abs(stickRate) > 0.5 * math.abs(rate)
            if math.abs(rate) > SPIN_RATE and not followsStick and (spinFor == 0 or sign == spinSign) then
                spinSign = sign
                spinFor = spinFor + dt
            else
                spinFor = 0
            end
            -- (how far it has gone round the same way, at any speed: a body that stopped, or goes round with the stick, starts again)
            if followsStick or math.abs(rate) < 0.5 then
                spinAccum = 0
            elseif spinAccum * turned > 0 or spinAccum == 0 then
                spinAccum = spinAccum + turned
            else
                spinAccum = turned
            end
            if spinFor >= SPIN_TIME or math.abs(spinAccum) >= SPIN_TURN then
                spinFor, spinAccum = 0, 0
                holdUntil = now + SPIN_HOLD
                holdLook = look
                holdYaw = yaw
                if not spinReported then
                    spinReported = true
                    warn(("[2006 Physics] stopped a spin (%.1f turns a second). Turning the body then: %s")
                        :format(math.abs(rate) / (2 * math.pi), whatTurns()))
                end
            end
        end
        lastYaw = yaw
    end

    -- (Addtion-Scripts) NO OVERSHOOT: the body turning past where you walk and then back (the user's video: it turns, "realizes it
    -- went too much, so it goes back a little"; they asked for it to be exact). Roblox's turning is left to do the turning, but
    -- the moment the body has gone past where you are walking (the way it is off from it changes side) it is put right on it and
    -- the turning it had is dropped, so nothing is left to swing it back. Only on the ground, walking, with Roblox's own turning
    -- on; a body already on its way (off by under half a degree) is never written, so walking straight writes nothing.
    local lastTurnErr = nil
    local OVERSHOOT_MIN = 0.01 -- radians: a smaller miss is left alone
    local function overshootGuard(dt)
        local body = rootPart or torso
        if not body or not body.Parent or not dt or dt <= 0 then return end
        if not GROUND_STATES[humanoid:GetState()] or glideVelocity.Parent ~= nil or climbFWM.isClimbing()
            or humanoid.Sit or humanoid.PlatformStand or humanoid.Health <= 0 or not humanoid.AutoRotate
            or os.clock() < holdUntil or checkIfTrippedState() then
            lastTurnErr = nil
            return
        end
        local md = humanoid.MoveDirection * xzVector
        local look = flatLookOf(body.CFrame)
        if md.Magnitude < 0.1 or not look then
            lastTurnErr = nil
            return
        end
        local err = (yawOf(md.Unit) - yawOf(look) + math.pi) % (2 * math.pi) - math.pi -- (where you walk, minus where it faces)
        local prev = lastTurnErr
        lastTurnErr = err
        -- (gone from one side of where you walk to the other: past it. Both small: not the half turn where the sides swap)
        if prev and prev * err < 0 and math.abs(err) > OVERSHOOT_MIN and math.abs(prev) + math.abs(err) < 2 then
            local w = body.AssemblyAngularVelocity
            body.AssemblyAngularVelocity = Vector3.new(w.X, 0, w.Z)
            local cf0 = body.CFrame
            local pos = cf0.Position
            body.CFrame = CFrame.new(pos) * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), err) * (CFrame.new(-pos) * cf0)
            lastTurnErr = 0
        end
    end

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

    -- R15: the body moved down on its root joint (LowerTorso.Root) for the sink, from whatever anything else sets it to
    local rootJoint, rootBase, rootWritten = nil, nil, nil
    local function findRootJoint()
        if isR15 then
            local lowerTorso = character:FindFirstChild("LowerTorso")
            return lowerTorso and lowerTorso:FindFirstChild("Root")
        end
        return rootPart and rootPart:FindFirstChild("RootJoint")
    end
    local function landPose(dt)
        -- (back up / upright again within about a third of a second, FWM's: its tilt fades by about 0.88 a frame)
        landTilt = landTilt * math.exp(-7 * dt)
        landDip = landDip * math.exp(-9 * dt)
        if math.abs(landTilt) < 0.05 then landTilt = 0 end
        if math.abs(landDip) < 0.005 then landDip = 0 end
        -- (smooth, the way FWM's tilt is: it rose a third of the way to its target each frame; set straight to the number it
        -- snapped, the user's "very unsmooth, very clunky")
        shownTilt = shownTilt + (landTilt - shownTilt) * (1 - math.exp(-18 * dt))
        shownDip = shownDip + (landDip - shownDip) * (1 - math.exp(-30 * dt))
        if math.abs(shownTilt) < 0.02 and landTilt == 0 then shownTilt = 0 end
        if math.abs(shownDip) < 0.002 and landDip == 0 then shownDip = 0 end
    end
    local function applyRootPose()
        if not (rootJoint and rootJoint.Parent) then
            rootJoint = findRootJoint()
            rootBase, rootWritten = nil, nil
            if not (rootJoint and rootJoint:IsA("Motor6D")) then rootJoint = nil return end
        end
        local current = rootJoint.C0
        if rootWritten == nil or current ~= rootWritten then rootBase = current end
        local want = rootBase
        if isR15 and sinkOffset ~= 0 then want = want + Vector3.new(0, sinkOffset, 0) end
        if shownDip ~= 0 then want = want + Vector3.new(0, shownDip, 0) end
        if shownTilt ~= 0 then
            -- (tipped forward about the feet, in the body's own space: forward is its -Z)
            local body = rootPart or torso
            local feet = ((body and body.Size and body.Size.Y / 2) or 1) + (isR15 and r15HipHeight or 2)
            local pivot = Vector3.new(0, -feet, 0)
            want = CFrame.new(pivot) * CFrame.fromAxisAngle(Vector3.new(1, 0, 0), -math.rad(shownTilt)) * CFrame.new(-pivot) * want
        end
        if current ~= want then
            rootJoint.C0 = want
        end
        rootWritten = rootJoint.C0
    end
    do
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

    -- (Addtion-Scripts) found once and as things come in, instead of every frame: FWM's climbing flag
    local function lookAtChild(child)
        if child:GetAttribute("FWMClimb") then fwmClimbValue = child end
    end
    for _, child in ipairs(character:GetChildren()) do lookAtChild(child) end
    table.insert(activeConnections, character.ChildAdded:Connect(lookAtChild))
    table.insert(activeConnections, character.ChildRemoved:Connect(function(child)
        if child == fwmClimbValue then fwmClimbValue = nil end
    end))

    -- (Addtion-Scripts) A READOUT OF WHAT THE BODY IS DOING (top left, small), OFF unless getgenv().BP_PhysicsDebug = true is set
    -- before running: so a screen recording can show the numbers behind "unstable" and "spin". Peaks are the highest in the last
    -- second. (It showed the spin: after every jump the body turned at 15 to 23 radians a second the moment it landed.)
    local debugLabel, debugGui = nil, nil
    local dbg = { yaw = nil, windowAt = os.clock(), textAt = 0, pYaw = 0, pTilt = 0, pCam = 0, pAng = 0, pAcc = 0,
        sYaw = 0, sTilt = 0, sCam = 0, sAng = 0, sAcc = 0, lastVel = nil, yawRate = 0, tilt = 0, cam = 0, ang = 0, acc = 0 }
    if BPGenv.BP_PhysicsDebug == true then
        pcall(function()
            local holder = (gethui and gethui()) or game:GetService("CoreGui")
            debugGui = Instance.new("ScreenGui")
            debugGui.Name = "BP2006Debug"
            debugGui.ResetOnSpawn = false
            debugGui.DisplayOrder = 100
            debugLabel = Instance.new("TextLabel")
            debugLabel.BackgroundColor3 = Color3.new(0, 0, 0)
            debugLabel.BackgroundTransparency = 0.45
            debugLabel.Position = UDim2.new(0, 4, 0, 52)
            debugLabel.Size = UDim2.new(0, 300, 0, 128)
            debugLabel.TextXAlignment = Enum.TextXAlignment.Left
            debugLabel.TextYAlignment = Enum.TextYAlignment.Top
            debugLabel.Font = Enum.Font.Code
            debugLabel.TextSize = 13
            debugLabel.TextColor3 = Color3.new(1, 1, 1)
            debugLabel.Text = "2006 physics readout"
            debugLabel.Parent = debugGui
            debugGui.Parent = holder
        end)
        table.insert(activeConnections, {
            Connected = true,
            Disconnect = function(self)
                self.Connected = false
                if debugGui then pcall(function() debugGui:Destroy() end) end
            end,
        })
    end
    local function debugTick(dt)
        if not debugLabel or not debugLabel.Parent or not dt or dt <= 0 then return end
        local body = rootPart or torso
        local cf = body.CFrame
        local look = cf.LookVector
        local yaw = math.atan2(-look.X, -look.Z)
        if dbg.yaw then
            local d = (yaw - dbg.yaw + math.pi) % (2 * math.pi) - math.pi
            dbg.yawRate = math.abs(d) / dt
        end
        dbg.yaw = yaw
        dbg.tilt = math.deg(math.acos(math.clamp(cf.UpVector.Y, -1, 1)))
        local cam = workspace.CurrentCamera
        dbg.cam = cam and math.deg(math.acos(math.clamp(cam.CFrame.UpVector.Y, -1, 1))) or 0
        local w = body.AssemblyAngularVelocity
        dbg.ang = w.Magnitude
        local v = body.AssemblyLinearVelocity
        if dbg.lastVel then dbg.acc = (v - dbg.lastVel).Magnitude / dt end
        dbg.lastVel = v
        dbg.pYaw = math.max(dbg.pYaw, dbg.yawRate)
        dbg.pTilt = math.max(dbg.pTilt, dbg.tilt)
        dbg.pCam = math.max(dbg.pCam, dbg.cam)
        dbg.pAng = math.max(dbg.pAng, dbg.ang)
        dbg.pAcc = math.max(dbg.pAcc, dbg.acc)
        local now = os.clock()
        if now - dbg.windowAt >= 1 then
            dbg.windowAt = now
            dbg.sYaw, dbg.sTilt, dbg.sCam, dbg.sAng, dbg.sAcc = dbg.pYaw, dbg.pTilt, dbg.pCam, dbg.pAng, dbg.pAcc
            dbg.pYaw, dbg.pTilt, dbg.pCam, dbg.pAng, dbg.pAcc = 0, 0, 0, 0, 0
        end
        if now - dbg.textAt < 0.1 then return end
        dbg.textAt = now
        local horiz = (v * xzVector).Magnitude
        local state = humanoid:GetState()
        debugLabel.Text = string.format(
            "2006 physics readout\nstate %s  walk %.1f  speed %.1f  up %.1f\nAutoRotate %s  glide %s  airlock %s\nyaw rate %.1f  (peak %.1f) rad/s\nbody tilt %.1f  (peak %.1f) deg\ncamera roll %.1f  (peak %.1f) deg\nbody spin %.1f  (peak %.1f) rad/s\nvelocity change %.0f  (peak %.0f)\ntool %s  camera %s",
            tostring(state):gsub("Enum.HumanoidStateType.", ""), humanoid.MoveDirection.Magnitude, horiz, v.Y,
            tostring(humanoid.AutoRotate), tostring(glideVelocity.Parent ~= nil), tostring(glideVelocity.Parent ~= nil and airYaw ~= nil),
            dbg.yawRate, dbg.sYaw, dbg.tilt, dbg.sTilt, dbg.cam, dbg.sCam, dbg.ang, dbg.sAng, dbg.acc, dbg.sAcc,
            tostring(character:FindFirstChildWhichIsA("Tool") ~= nil), tostring(cam and cam.CameraType and cam.CameraType.Name or "?"))
    end

    table.insert(activeConnections, RunService.RenderStepped:Connect(function(dt)
        if not torso.Parent then return end
        -- (FWM asked for the torso's connected parts here every frame and never used them: dropped, it costs)

        updateSink(math.min(dt, 0.1))
        landPose(math.min(dt, 0.1))
        applyRootPose()

        if timePeriod > 14 then
            humanoid.AutoRotate = autoRotateTime < os.clock()
        end

        -- (Addtion-Scripts) FWM's fly-bug climbing was here (walking into any small part climbed it); the 2013
        -- climbing climbs instead (see CLIMBING above)

        currentSquash = ExtraUtil.Lerp(currentSquash, squashOffsetTarget, 0.5)
        -- (Addtion-Scripts) R15: no landing squash on the hip height. Roblox's R15 Animate plays the
        -- animations faster the lower the hip height is, so the squash made them run twice as fast.
        setHipHeight(isR15 and targetHipHeight or (currentSquash + targetHipHeight))

        -- (the FWMClimb value is found as it comes in, not looked for every frame: see below)
        if fwmClimbValue then
            fwmClimbValue.Value = climbFWM.isClimbing() or humanoid:GetState() == Enum.HumanoidStateType.Climbing
        end

        currentTilt = ExtraUtil.Lerp(currentTilt, tiltAngleTarget, 0.3)

        -- (Addtion-Scripts) NO LEAN WITH A TOOL IN HAND. FWM turned its torso a little more every frame by (your turning speed x
        -- the weight of the tool in your hand): in FWM a torso constraint (TorsoAttach.AngularTilt) takes that back each frame; in
        -- any other game nothing does, the turns add up and the body goes round and over: the spin that would not go away
        -- (holding a sword, the user's recordings). It is not drawn at all now.

        spinGuard(dt) -- (see SPIN GUARD above)
        overshootGuard(dt) -- (see NO OVERSHOOT above)
        -- (Addtion-Scripts) THE AIR LOCK, as the 2008 physics': from a jump until you land you keep facing the way you
        -- jumped. The jump glide turns Roblox's turning off for the jump, but the body still had the turn it was making
        -- as it left the ground and kept going round in the air (turning left or right while jumping: a spin, the
        -- user's video). That turn is stopped here.
        -- (Addtion-Scripts) THE AIR LOCK ALSO FOR A FALL: walking off an edge (no jump, so no glide) the body was free to turn in the
        -- air, and every fall into a spin came from there. It keeps the way it faced as it left the ground, as in a jump.
        local fallState = humanoid:GetState()
        local falling = (fallState == Enum.HumanoidStateType.Freefall) and glideVelocity.Parent == nil
            and not climbFWM.isClimbing() and not humanoid.Sit and not humanoid.PlatformStand
        if falling then
            if not airYaw or not fallLocked then
                local lv0 = (rootPart or torso).CFrame.LookVector
                airYaw = math.atan2(-lv0.X, -lv0.Z)
                fallLocked = true
            end
        elseif fallLocked then
            fallLocked = false
            if glideVelocity.Parent == nil then airYaw = nil end
        end
        -- (Addtion-Scripts) THE LANDING TURN: Roblox's turning gets switched back on at the landing and snaps the body from the way it
        -- faced in the air to where you walk, the "recoil" the user saw on every jump. For half a second after a landing the body
        -- is eased round to where you walk instead (at most 5 radians a second), then Roblox's turning is back.
        if os.clock() < landEaseUntil and GROUND_STATES[fallState] and glideVelocity.Parent == nil then
            landEaseOn = true
            pcall(function() humanoid.AutoRotate = false end)
            local body = rootPart or torso
            local md = humanoid.MoveDirection * xzVector
            if md.Magnitude > 0.1 and body then
                local cf0 = body.CFrame
                local lv = cf0.LookVector
                local cur = math.atan2(-lv.X, -lv.Z)
                local want = math.atan2(-md.X, -md.Z)
                local d = (want - cur + math.pi) % (2 * math.pi) - math.pi
                local step = math.clamp(d * (1 - math.exp(-10 * math.min(dt, 0.1))), -5 * math.min(dt, 0.1), 5 * math.min(dt, 0.1))
                local w = body.AssemblyAngularVelocity or Vector3.new(0, 0, 0)
                body.AssemblyAngularVelocity = Vector3.new(w.X, 0, w.Z)
                if math.abs(step) > 1e-5 then
                    local pos = cf0.Position
                    body.CFrame = CFrame.new(pos) * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), step) * (CFrame.new(-pos) * cf0)
                end
            end
        elseif landEaseOn then
            landEaseOn = false
            if glideVelocity.Parent == nil then pcall(function() humanoid.AutoRotate = true end) end
        end
        if glideVelocity.Parent ~= nil or fallLocked then
            local body = rootPart or torso
            noTurn(body)
            -- (and it is set back to that facing every frame: a turn of a few radians a second, slower than the spin guard's
            -- limit, was still a spin in the air, the user's recording. FWM's body doesn't turn in the air at all.)
            if airYaw then
                pcall(function()
                    local cf0 = body.CFrame
                    local lv = cf0.LookVector
                    local cur = math.atan2(-lv.X, -lv.Z)
                    local d = (airYaw - cur + math.pi) % (2 * math.pi) - math.pi
                    if math.abs(d) > 0.0005 then
                        if math.abs(d) > 0.04 and not airSpinReported then
                            airSpinReported = true
                            warn(("[2006 Physics] the body was turning in the air (%.1f turns a second): held facing the way you jumped. Turning the body then: %s")
                                :format(math.abs(d) / math.max(dt, 0.001) / (2 * math.pi), whatTurns()))
                        end
                        local pos = cf0.Position
                        body.CFrame = CFrame.new(pos) * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), d) * (CFrame.new(-pos) * cf0)
                    end
                end)
            end
        end

        pcall(debugTick, dt)

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
    local lastGlideBounce = 0
    local GLIDE_BOUNCE_GAP = 0.3 -- (seconds: one bounce per wall; the next limb to touch it is not another)
    local GLIDE_HEAD_ON = 0.8    -- (how straight into the wall: the cosine of the angle, about 37 degrees)

    -- another player's body (or what it holds) is not a wall
    local function glideBodyHit(hit)
        local ok, other = pcall(function()
            local model = hit:FindFirstAncestorWhichIsA("Model")
            return model ~= nil and model ~= character and model:FindFirstChildOfClass("Humanoid") ~= nil
        end)
        return ok and other
    end

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
                -- (Addtion-Scripts) NO SWING SIDEWAYS. FWM sent the glide off along the touched surface's normal at full speed,
                -- from any touch of any part, by any limb, one touch after another: brushing a railing, a step, a slope, the side
                -- of a platform or another player's body threw the whole jump off to the left or right (and the second touch,
                -- from the next limb, threw it back), the user's "swings left and right when walking straight and jumping".
                -- Now the glide is only turned back by a wall it runs straight into (within about 37 degrees of head-on), once;
                -- anything else (a glancing touch, the side of something, the ground, a slope, a player) leaves it alone,
                -- Roblox's own collision stops you where it should.
                if tick() - lastGlideBounce < GLIDE_BOUNCE_GAP then
                    return
                end
                local minHeight = torso.Position.Y - 2
                if hit.Position.Y < minHeight or glideBodyHit(hit) then
                    return
                end
                local v = glideVelocity.Velocity
                local vxz = Vector3.new(v.X, 0, v.Z)
                local speed = vxz.Magnitude
                if speed < 2 then
                    return
                end
                local gotPoint, closestPoint = pcall(function() return hit:GetClosestPointOnSurface(part.Position) end)
                if not gotPoint or closestPoint == nil then
                    return
                end
                local dir = closestPoint - part.Position
                local castDir = dir.Magnitude <= 0 and Vector3.new(0, 0, 0) or dir.Unit
                local result = workspace:Shapecast(part, castDir, raycastParams)

                local normal
                if result then
                    if not result.Instance.CanCollide or minHeight >= result.Position.Y then
                        return
                    end
                    normal = result.Normal
                elseif castDir.Magnitude > 0 then
                    normal = -castDir -- (no hit from the cast: the wall's face is the way from the touched point back to the part)
                else
                    return
                end
                -- a wall: upright, not a floor, a slope you could walk up, or an underside
                local flat = Vector3.new(normal.X, 0, normal.Z)
                if math.abs(normal.Y) > 0.5 or flat.Magnitude < 0.5 then
                    return
                end
                flat = flat.Unit
                if vxz.Unit:Dot(flat) > -GLIDE_HEAD_ON then
                    return
                end
                lastGlideBounce = tick()
                local reflected = flat * speed
                glideVelocity.Velocity = Vector3.new(reflected.X, v.Y, reflected.Z)
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
    putCameraBack()
    BPGenv.__Physics2006Cleanup = nil
end

-- (so it can be seen in the console which copy is running)
print("[2006 Physics] On (time period " .. tostring(getTimePeriod()) .. "): FWM's physics with Roblox's own controls, a"
    .. " soft turn that never swings past (no spin), the classic camera, spin guard on.")