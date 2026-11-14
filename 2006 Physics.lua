-- [[ 2006 PHYSICS (Addtion-Scripts copy) ]]
-- The 2006 physics gist, made to work with R15 avatars too (it only ran on R6). On R15:
--   * the upper torso stands in for the Torso, the hands for the arms (the tool's weight)
--   * the hip height stays the avatar's own (an R15 body stands on it; 0 sank it into the floor), and
--     the landing squash goes on top of it
--   * the climbing check (a small box in front of the feet) is measured from the feet, as on R6
-- R6 works exactly as before.
local Players = game:GetService("Players")
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
    local function setHipHeight(value)
        if isR15 then
            if lastSetHipHeight and math.abs(humanoid.HipHeight - lastSetHipHeight) > 0.001 then
                -- changed by something else (Roblox scaling the body): that is the new base
                r15HipHeight = humanoid.HipHeight - (lastSetHipHeight - r15HipHeight)
            end
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

    local function stopClimbing()
        repeat
            task.wait()
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
            climbLift.Parent = nil
            climbGyro.Parent = nil
        until humanoid:GetState() ~= Enum.HumanoidStateType.Climbing

        while humanoid:GetState() ~= Enum.HumanoidStateType.Landed and humanoid.Parent do
            task.wait()
        end
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
    end

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
            local checkPos = torso.Position - Vector3.new(0, 1, 0)
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
            if not climbConnection then
                climbConnection = RunService.RenderStepped:Connect(handleClimbing)
            end
        else
            if climbConnection then
                climbConnection:Disconnect()
                climbConnection = nil
            end
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

    table.insert(activeConnections, RunService.RenderStepped:Connect(function(dt)
        if not torso.Parent then return end
        torso:GetConnectedParts()

        if timePeriod > 14 then
            humanoid.AutoRotate = autoRotateTime < os.clock()
        end

        local canTrussClimb = isFlyBug() and not checkIfTrippedState()

        if not humanoid.Sit and humanoid.MoveDirection.Magnitude > 0.01 and glideVelocity.Parent == nil and canTrussClimb then
            local damp = timePeriod <= 14 and 0.8 or 0.4
            humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
            torso.AssemblyLinearVelocity = torso.AssemblyLinearVelocity * (xzVector * damp) + vec3.new(0, 13, 0)
        end

        currentSquash = ExtraUtil.Lerp(currentSquash, squashOffsetTarget, 0.5)
        setHipHeight(currentSquash + targetHipHeight)

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