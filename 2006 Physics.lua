-- [[ 2006 PHYSICS (Addtion-Scripts copy) ]]
-- The 2006 physics gist, made to work with R15 avatars too (it only ran on R6). On R15:
--   * the upper torso stands in for the Torso, the hands for the arms (the tool's weight)
--   * the hip height stays the avatar's own (an R15 body stands on it; 0 sank it into the floor), with
--     no landing squash (Roblox's R15 Animate speeds the animations up when the hip height drops)
--   * the climbing check (a small box in front of the feet) is measured from the feet, as on R6
-- R6 works exactly as before.
-- Climbing holds on between two rungs (a ladder is climbed in one go, as in 2006), keeps pushing into what you
-- climb, hops over the top, and a let-go never leaves the climbing switched off for good.
-- Sinking into the ground, as in 2006 (and as the "Old" physics does): falling lowers the body up to a stud,
-- so a landing ends with the legs in the ground, and the body rises back out within about half a second.
local Players = game:GetService("Players")
local BPGenv = (getgenv and getgenv()) or _G
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- Fallback configuration if executed outside the original game
local DEFAULT_TIME_PERIOD = 10 -- Adjusts physics era behavior (e.g., <1, <=14, >=17)

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

local function cleanupConnections()
    for i, conn in pairs(activeConnections) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
        activeConnections[i] = nil
    end
end

local function setupCharacterPhysics(character)
    cleanupConnections()

    -- Disable the existing CharacterPhysics script to prevent conflicts
    local existingScript = character:FindFirstChild("CharacterPhysics")
    if existingScript and existingScript:IsA("LocalScript") then
        existingScript.Disabled = true
    end

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

    -- (Addtion-Scripts) an R15 body stands on its hip height (R6 legs hold it up at 0). Its own is kept
    -- (and followed if Roblox changes it, e.g. when the body is scaled).
    local r15HipHeight = humanoid.HipHeight > 0 and humanoid.HipHeight or 2
    local lastSetHipHeight = nil
    -- (Addtion-Scripts) SINKING INTO THE GROUND, as in 2006 and as the "Old" physics does it: falling fast lowers
    -- the body (up to a stud), so a landing ends with the legs in the ground, and the body rises back out within
    -- about half a second (rising fast lifts it a little instead). Walking onto a higher or lower floor brings it
    -- straight back up. Unlike the Old physics, a landing lower down than where you jumped from (off a ledge)
    -- sinks too. R6: through the hip height. R15: the body is moved down on its root joint instead (a lower hip
    -- height makes Roblox's R15 animations run faster).
    local SINK_RATE = 20 / 3 -- studs a second the sink moves while falling or rising fast
    local SINK_DECAY = 0.925 -- kept each 1/60 s once back on the ground
    local sinkOffset = 0
    local sinkFloorY = nil

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
    local climbConnection = nil
    local fwmClimbValue = nil
    -- (Addtion-Scripts) climbing: held between two rungs, hop over the top (as the "Old" physics does)
    local GRAB_GRACE = 0.25       -- seconds the climb is held between two rungs / bricks
    local TOP_OUT_TIME = 0.4      -- seconds after the last grab in which you are still topping out
    local TOP_OUT_MIN_RISE = 1.5  -- studs climbed before the top-out hop counts
    local TOP_OUT_SPEED = 14      -- hop forward over the top
    local TOP_OUT_UP = 9          -- ...and a little up
    local MAX_FALL_TO_GRAB = 8    -- falling faster than this: no grabbing
    local grabStartY, lastGrab, grabbingNow = nil, 0, false

    if timePeriod < 1 then
        humanoid.JumpPower = 0
    end

    local glideVelocity = ExtraUtil.Create("BodyVelocity", {
        Name = "GlideVelocity",
        MaxForce = xzVector * 9000000000,
    })

    local climbLift = ExtraUtil.Create("BodyVelocity", {
        Name = "ClimbLift",
        Velocity = Vector3.new(0, 0, 0),
        MaxForce = Vector3.new(5000, 0, 5000),
        P = 1000,
    })

    local climbGyro = ExtraUtil.Create("BodyGyro", {
        Name = "ClimbGyro",
        MaxTorque = Vector3.new(0, math.huge, 0),
        P = 4000,
        D = 200,
    })

    local tiltStopVel = ExtraUtil.Create("BodyVelocity", {
        Name = "TiltStopVel",
        MaxForce = Vector3.new(math.huge, 0, math.huge),
        Velocity = Vector3.new(0, 0, 0),
    })

    table.insert(activeConnections, humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
        if humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat") then
            humanoid.SeatPart.HeadsUpDisplay = false
        end
    end))

    -- (Addtion-Scripts) let go: once at a time, and never longer than a few seconds (it used to wait for a
    -- landing with no end, which could leave climbing switched off, and it was started again every frame)
    local releasing = false
    local function stopClimbing()
        if releasing then return end
        releasing = true
        task.spawn(function()
            local deadline = os.clock() + 2
            repeat
                task.wait()
                pcall(function()
                    humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
                    humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
                end)
                climbLift.Parent = nil
                climbGyro.Parent = nil
            until not humanoid.Parent or humanoid:GetState() ~= Enum.HumanoidStateType.Climbing or os.clock() > deadline

            local landDeadline = os.clock() + 3
            while humanoid.Parent and humanoid:GetState() ~= Enum.HumanoidStateType.Landed and os.clock() < landDeadline do
                task.wait()
            end
            if humanoid.Parent then
                pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true) end)
            end
            releasing = false
        end)
    end

    -- (Addtion-Scripts) run every frame from the main loop below: it was only hooked up when the move direction
    -- changed, so holding the stick still on a ladder never pushed you into it and you slid off the rungs
    local function handleClimbing()
        if humanoid:GetState() == Enum.HumanoidStateType.Climbing then
            if humanoid.MoveDirection.Magnitude < 0.1 then
                if timePeriod <= 14 then
                    stopClimbing()
                    return
                end
            else
                climbLift.Parent = torso
                climbGyro.Parent = torso
                local pos = torso.Position
                local moveDir = humanoid.MoveDirection
                climbGyro.CFrame = CFrame.lookAt(pos, pos + moveDir)
                climbLift.Velocity = moveDir * 24
            end
        end
    end

    local overlapParams = OverlapParams.new()
    overlapParams.FilterDescendantsInstances = { character, workspace.CurrentCamera }
    overlapParams.RespectCanCollide = true

    local function isFlyBug()
        local boxCFrame
        if isR15 then
            -- (Addtion-Scripts) the same place as on R6: 1 to 2 studs above the feet, just in front
            local feet = rootPart.Position.Y - rootPart.Size.Y / 2 - r15HipHeight
            local ahead = rootPart.Position + rootPart.CFrame.LookVector / 2
            boxCFrame = CFrame.new(ahead.X, feet + 1.5, ahead.Z)
        else
            -- (Addtion-Scripts) the sink taken out: just after a landing the body is lower, which would put the box
            -- into the ground and miss the bottom rung of a ladder
            local checkPos = torso.Position - Vector3.new(0, 1 + sinkOffset, 0)
            torso:GetConnectedParts()
            boxCFrame = CFrame.new(checkPos + torso.CFrame.LookVector / 2) * CFrame.new(0, -0.5, 0)
        end
        local parts = workspace:GetPartBoundsInBox(boxCFrame, Vector3.new(1, 1, 1), overlapParams)

        for _, part in pairs(parts) do
            local worldSize = part.CFrame:VectorToWorldSpace(part.Size)
            if ExtraUtil.Average(worldSize.X, worldSize.Y, worldSize.Z) > 3.5 or worldSize.Y >= 3.5 then
                continue
            end
            return true
        end
        return false
    end

    local function moveDirectionChanged()
        if humanoid.MoveDirection.Magnitude < 1 then
            fireProtocol("DiscWalking", false)
        end
        if humanoid:GetState() == Enum.HumanoidStateType.Climbing and torso then
            -- (Addtion-Scripts) the push into the ladder is done every frame by the main loop now
        else
            if climbLift.Parent and fwmClimbValue then
                fwmClimbValue.Value = false
                fireProtocol("Climbing", false)
            end
            climbLift.Parent = nil
            climbGyro.Parent = nil
        end
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
            if humanoid:GetState() == Enum.HumanoidStateType.Climbing then
                stopClimbing()
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
        if humanoid.Sit or humanoid.SeatPart or humanoid.Health <= 0
            or state == Enum.HumanoidStateType.Climbing or state == Enum.HumanoidStateType.Swimming then
            sinkOffset = 0
        else
            local vy = rootPart.AssemblyLinearVelocity.Y
            if math.abs(vy) > 8 then
                local goal = vy > 0 and 1 or -1
                local step = SINK_RATE * dt
                if sinkOffset < goal then
                    sinkOffset = math.min(goal, sinkOffset + step)
                else
                    sinkOffset = math.max(goal, sinkOffset - step)
                end
            elseif level and sinkFloorY and math.abs(level - sinkFloorY) > 0.5 then
                sinkOffset = 0 -- walked onto a higher or lower floor
            else
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

        local canTrussClimb = isFlyBug() and not checkIfTrippedState()

        -- (Addtion-Scripts) not while letting go, and not in a real fall (dropping past a wall must not grab it)
        local moving = humanoid.MoveDirection.Magnitude > 0.01
        local fallingFast = torso.AssemblyLinearVelocity.Y < -MAX_FALL_TO_GRAB
        local walkingIntoPart = not humanoid.Sit and moving and glideVelocity.Parent == nil and canTrussClimb
            and not releasing and not fallingFast
        if walkingIntoPart then
            local damp = timePeriod <= 14 and 0.8 or 0.4
            humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
            torso.AssemblyLinearVelocity = torso.AssemblyLinearVelocity * (xzVector * damp) + vec3.new(0, 13, 0)
        end
        -- (Addtion-Scripts) between two rungs nothing is in front of the feet for a moment: the climb is held through
        -- that (it used to drop you back down the ladder at every gap); the top of a ladder or a ledge: a hop
        -- forward over it, so you end up standing on it instead of sliding back down
        local now = os.clock()
        if walkingIntoPart then
            if not grabStartY then grabStartY = torso.Position.Y end
            lastGrab = now
        elseif grabStartY then
            if now - lastGrab > TOP_OUT_TIME then
                grabStartY = nil
            elseif moving and not releasing and torso.Position.Y - grabStartY >= TOP_OUT_MIN_RISE then
                local v = torso.AssemblyLinearVelocity
                local dir = humanoid.MoveDirection
                torso.AssemblyLinearVelocity = Vector3.new(dir.X * TOP_OUT_SPEED, math.max(v.Y, TOP_OUT_UP), dir.Z * TOP_OUT_SPEED)
            end
        end
        grabbingNow = walkingIntoPart
            or (grabStartY ~= nil and moving and not releasing and not fallingFast and now - lastGrab <= GRAB_GRACE
                and not checkIfTrippedState() and not humanoid.Sit)
        -- (2007 Animation.lua reads this to show its climbing pose, not its falling one)
        BPGenv.BPClimbing = (grabbingNow or humanoid:GetState() == Enum.HumanoidStateType.Climbing) or nil
        handleClimbing()
        if humanoid:GetState() ~= Enum.HumanoidStateType.Climbing then
            climbLift.Parent = nil
            climbGyro.Parent = nil
        end

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
            fwmClimbValue.Value = (canTrussClimb and humanoid.MoveDirection.Magnitude > 0.01)
                or humanoid:GetState() == Enum.HumanoidStateType.Climbing
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

    -- (Addtion-Scripts) the physics step can flip the state to Freefall between two frames (and the animation
    -- with it): put Climbing back while holding on to a ladder, only while really holding on
    table.insert(activeConnections, RunService.Heartbeat:Connect(function()
        if not character.Parent or humanoid.Health <= 0 then return end
        if grabbingNow and not releasing and humanoid:GetState() ~= Enum.HumanoidStateType.Climbing
            and not checkIfTrippedState() and not humanoid.Sit then
            pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Climbing) end)
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
        BPGenv.BPClimbing = nil
        cleanupConnections()
        if climbConnection then
            climbConnection:Disconnect()
            climbConnection = nil
        end
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
LocalPlayer.CharacterAdded:Connect(setupCharacterPhysics)