-- [[ PHYSICS + CAMERA WIZARD STEP — with None option ]]
-- (Addtion-Scripts copy: the "Old" physics is built on Super Nostalgia Zone's character scripts (GoofyMotion,
--  GoofyBalance, Bounciness, RetroClimbing...), the best-known recreation of old Roblox. It does not sink the player
--  into the ground on landing (it copies 2010-2013, which had none; the 2006 physics does it). It climbs as SNZ does:
--  a steady climb at 70% of WalkSpeed (the old Humanoid's climbing speed), going on while anything small is within
--  reach in front (toes to head), stick or no stick (SNZ's RetroClimbing climbs whenever a ladder is in front: pull
--  the stick away or jump to get off), facing the ladder the way you grabbed it, no kick up every frame (which
--  floated you up), and a step onto the top only at the real top. R6 and R15 alike. From SNZ too: a
--  small bounce on every landing, and tripping over when flung faster than 200 studs a second. Walk into a small part and the
--  character climbs it in the real Climbing state, and lets go when you stop moving or jump.
--  R15 avatars work too: the hip height moves around the avatar's own (an R15 body stands on it; R6 legs
--  hold an R6 body up at 0, which sank an R15 one into the floor), and the climbing check is measured
--  from the feet. The "2006" physics is this repo's copy (2006 Physics.lua), which also takes R15.)

task.spawn(function()
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")
	local SoundService = game:GetService("SoundService")

	local CONFIG_FILE = "BloxyParadoxConfig.json"
	-- the repo copy has first person like the 2012 camera (Retro Camera.lua); the gist is the fallback
	local CAMERA_URL = "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/Retro%20Camera.lua"
	local CAMERA_GIST = "https://gist.githubusercontent.com/eloredo413-hue/81660979f9506a61e0344f32a8096f96/raw/05a2619b3a2737d7c4a97814650f8980e103c5ef/Retro%2520camera"
	-- the repo copy works with R15 avatars too; the gist (R6 only) is the fallback
	local PHYSICS_2006_URL = "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/2006%20Physics.lua"
	local PHYSICS_2006_GIST = "https://gist.githubusercontent.com/eloredo413-hue/03ef8e46682bfb53e26e6847abfde344/raw/0fb71153c3b4a369a0390228a2bec3a4a5655c56/2006%2520Physics"

	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui", 15)
	local sg = pg:WaitForChild("BloxyParadoxProject", 15)

	local clickSfx = Instance.new("Sound")
	clickSfx.SoundId = "rbxassetid://12221967"
	clickSfx.Volume = 0.6
	clickSfx.Parent = SoundService
	local function playClick() clickSfx:Stop() clickSfx:Play() end

	local PHYSICS_SRC = [==[
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end
local BPGenv = (getgenv and getgenv()) or _G

if _G.__RetroMasterCleanup then pcall(_G.__RetroMasterCleanup) end

local Connections = {}
local RenderNames = {}
local CharacterObjects = {}
local destroyed = false

local function addConnection(c)
	if c then table.insert(Connections, c) end
	return c
end

local function disconnectAll()
	for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
	table.clear(Connections)
end

local function unbindAll()
	for _, n in ipairs(RenderNames) do pcall(function() RunService:UnbindFromRenderStep(n) end) end
	table.clear(RenderNames)
end

local function cleanupCharacterObjects()
	for _, o in ipairs(CharacterObjects) do
		pcall(function() if o and o.Parent then o:Destroy() end end)
	end
	table.clear(CharacterObjects)
end

local function cleanup()
	if destroyed then return end
	destroyed = true
	BPGenv.BPClimbing = nil
	disconnectAll()
	unbindAll()
	cleanupCharacterObjects()
end

_G.__RetroMasterCleanup = cleanup


-- 2006 physics climbing: a 1-stud box just in front of the feet; any part in it that is not big
-- (average size and height under MAX_CLIMB_PART) can be climbed while you walk into it.
local CLIMB_BOX = Vector3.new(1, 1, 1)
local MAX_CLIMB_PART = 3.5
local CLIMB_SPEED_SHARE = 0.7   -- climbing speed: 70% of WalkSpeed (11.2 at 16), the old Humanoid's (Roblox wiki, 2011;
                                -- Super Nostalgia Zone's RetroClimbing climbs at the same speed)
local CLIMB_REACH_UP = 2        -- studs above the climbing box: in front of the chest (the top check)
local REACH_LIFT, REACH_HEIGHT = 0.9, 4.2 -- while climbing: one tall box in front, from the toes to the head (0.3 to 4.5
                                -- studs above the feet), so a gap between two rungs never ends the climb
local TRIP_SPEED = 200          -- flung faster than this (studs a second): you trip (SNZ GoofyMotion's VelocityThreshold)
local CLIMB_PUSH_SPEED = 12     -- push into the part (gentle: it was 24)
local BLOCKED_SPEED = 0.35       -- slower than this share of WalkSpeed while walking = blocked by the part
local BLOCKED_TIME = 0.15        -- ...for this long (seconds) before a climb starts: stairs are walked up
local GRAB_GRACE = 0.25          -- seconds the climb is held between two rungs / bricks
local TOP_OUT_TIME = 0.4        -- seconds after the last grab in which you are still topping out
local TOP_OUT_MIN_RISE = 1.5    -- studs climbed before the top-out hop counts
local TOP_OUT_SPEED = 10        -- a step forward onto the top
local TOP_OUT_UP = 4            -- ...keeping (at least) a little of the climb's rise
local MAX_FALL_TO_GRAB = 8      -- falling faster than this: no grabbing
local CLIMB_SIDE_DAMP = 0.8     -- sideways speed kept each frame while climbing
local XZ = Vector3.new(1, 0, 1)

local function setupCharacter(char)
	if destroyed or not char then return end
	cleanupCharacterObjects()

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local rootPart = char:FindFirstChild("HumanoidRootPart")
	local head = char:FindFirstChild("Head")
	local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")

	local timeout = os.clock() + 10
	while not destroyed and char.Parent and os.clock() < timeout and (not humanoid or not rootPart or not torso) do
		humanoid = char:FindFirstChildOfClass("Humanoid")
		rootPart = char:FindFirstChild("HumanoidRootPart")
		head = char:FindFirstChild("Head")
		torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
		task.wait(0.05)
	end

	if destroyed or not char.Parent then return end
	if not humanoid or not rootPart or not torso then
		warn("[Retro Master] Character parts could not be found.")
		return
	end

	-- R15: the body stands on its hip height, so the hip-height changes below go around its own (R6: 0).
	-- Its own is followed if Roblox changes it (the body being scaled).
	local isR15 = humanoid.RigType == Enum.HumanoidRigType.R15
	local baseHip = isR15 and (humanoid.HipHeight > 0 and humanoid.HipHeight or 2) or 0
	local hipOffset = 0
	local lastSetHip = nil
	local function applyHip()
		if isR15 and lastSetHip and math.abs(humanoid.HipHeight - lastSetHip) > 0.001 then
			baseHip = humanoid.HipHeight - hipOffset -- changed by something else: that's the new base
		end
		local value = baseHip + hipOffset
		humanoid.HipHeight = value
		lastSetHip = value
	end

	local oldClimbing = char:FindFirstChild("Climbing")
	if oldClimbing then pcall(function() oldClimbing:Destroy() end) end

	for _, name in ipairs({ "ClimbForce", "ClimbLift", "ClimbGyro" }) do
		local old = rootPart:FindFirstChild(name) or torso:FindFirstChild(name)
		if old then pcall(function() old:Destroy() end) end
	end

	local climbing = Instance.new("BoolValue")
	climbing.Name = "Climbing"
	climbing.Value = false
	climbing.Parent = char
	table.insert(CharacterObjects, climbing)

	-- Pushes the character into the part it climbs, and turns it to face it (parented to the
	-- torso only while climbing).
	local climbLift = Instance.new("BodyVelocity")
	climbLift.Name = "ClimbLift"
	climbLift.Velocity = Vector3.zero
	climbLift.MaxForce = Vector3.new(5000, 0, 5000)
	climbLift.P = 1000
	table.insert(CharacterObjects, climbLift)

	-- The steady climb: holds the upward speed at the climbing speed while a rung is within reach (only up and down:
	-- the push into the part is the lift's). SNZ's RetroClimbing "ClimbForce".
	local climbForce = Instance.new("BodyVelocity")
	climbForce.Name = "ClimbForce"
	climbForce.Velocity = Vector3.zero
	climbForce.MaxForce = Vector3.new(0, 10e6, 0)
	table.insert(CharacterObjects, climbForce)

	local climbGyro = Instance.new("BodyGyro")
	climbGyro.Name = "ClimbGyro"
	climbGyro.MaxTorque = Vector3.new(0, math.huge, 0)
	climbGyro.P = 4000
	climbGyro.D = 200
	table.insert(CharacterObjects, climbGyro)

	-- The real Climbing state is what the 2006 climbing runs on (an earlier copy of this script
	-- switched it off).
	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
	end)

	-- No climb animation of our own is played any more: it was Roblox's modern one, which showed up
	-- over whichever animation you picked in the wizard. The climbing state is kept up instead (below),
	-- so the animation you picked plays ITS OWN climbing animation.
	local climbWanted = false -- true while the 2006 climbing is at work
	local grabbingNow = false -- a part is in front of the feet right now (this frame)
	local blockedFor = 0      -- how long (seconds) you have been walking without getting anywhere
	local lastFrame = os.clock()
	local grabStartY, lastGrab = nil, 0 -- where the current climb began, and when a part was last in front

	local lastFallSpeed = 0
	addConnection(RunService.Heartbeat:Connect(function()
		if destroyed or not char.Parent or humanoid.Health <= 0 then return end
		local v = rootPart.AssemblyLinearVelocity
		if v.Y < -2 then lastFallSpeed = math.abs(v.Y) end
	end))

	addConnection(humanoid.StateChanged:Connect(function(_, newState)
		if newState ~= Enum.HumanoidStateType.Landed then return end
		local bounceMultiplier = 1
		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = {char}
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		local hitResult = Workspace:Raycast(rootPart.Position, Vector3.new(0, -6, 0), rayParams)
		if hitResult and hitResult.Instance then
			local hit = hitResult.Instance
			local hitName = hit.Name:lower()
			local parentName = (hit.Parent and hit.Parent.Name:lower()) or ""
			local model = hit:FindFirstAncestorWhichIsA("Model")
			local modelName = (model and model.Name:lower()) or ""
			if hitName:match("trampoline") or hitName:match("bounce") or parentName:match("trampoline") or parentName:match("bounce") or modelName:match("trampoline") or modelName:match("bounce") then
				bounceMultiplier = 4
			end
		end
		if bounceMultiplier > 1 then
			local baseSpeed = math.max(lastFallSpeed, 35)
			local launchVelocity = math.clamp(baseSpeed * (0.6 * bounceMultiplier), 50, 300)
			pcall(function()
				humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
				humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			end)
			rootPart.AssemblyLinearVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, launchVelocity, rootPart.AssemblyLinearVelocity.Z)
		elseif lastFallSpeed > 0 and not climbWanted and climbForce.Parent == nil then
			-- SNZ's Bounciness: the old physics' small bounce on every landing, an upward push on the head of half
			-- the landing speed times gravity, for a 30th of a second (not on a ladder: feet on a rung)
			local head = char:FindFirstChild("Head")
			if head then
				local bounce = Instance.new("BodyForce")
				bounce.Name = "Bounce"
				bounce.Force = Vector3.new(0, lastFallSpeed * Workspace.Gravity / 2, 0)
				bounce.Parent = head
				task.delay(1 / 30, function() pcall(function() bounce:Destroy() end) end)
			end
		end
		lastFallSpeed = 0
	end))

	-- (No jump lock after landing: switching the Jumping state off hid the jump button and could leave a
	-- jump made while walking stuck in the walking state. The 2006 physics keeps its own.)

	addConnection(humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.RunningNoPhysics then
			pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
		elseif newState == Enum.HumanoidStateType.FallingDown then
			pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll) end)
			task.spawn(function()
				while not destroyed and humanoid.Parent and humanoid.Health > 0 do
					task.wait(0.5)
					if rootPart.AssemblyLinearVelocity.Magnitude < 0.1 then
						task.wait(2)
						if not destroyed and humanoid.Health > 0 then
							pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
						end
						break
					end
				end
			end)
		end
	end))

	-- true while the 2006 climbing below is at work (set there)
	local climbActive = false

	-- No sinking into the ground on landing any more: the Old physics copies 2010-2013, which had none (the 2006
	-- physics has it). The hip height is only kept at the body's own (R6: 0; R15: its own, followed if Roblox
	-- changes it), as before.
	local hipRenderName = "RetroHipHeight_" .. tostring(math.random(10000, 99999))
	table.insert(RenderNames, hipRenderName)

	RunService:BindToRenderStep(hipRenderName, 390, function()
		if destroyed or not char.Parent or humanoid.Health <= 0 then
			pcall(function() RunService:UnbindFromRenderStep(hipRenderName) end)
			return
		end
		hipOffset = 0
		applyHip()
	end)

	local camera = Workspace.CurrentCamera
	local bg = rootPart:FindFirstChild("FirstPersonGyro")
	if not bg then
		bg = Instance.new("BodyGyro")
		bg.Name = "FirstPersonGyro"
		bg.MaxTorque = Vector3.new(0, 10e6, 0)
		bg.D = 100
		bg.Parent = rootPart
		table.insert(CharacterObjects, bg)
	end

	local blankV3 = Vector3.zero
	local xz = Vector3.new(1, 0, 1)

	pcall(function() humanoid.AutoRotate = false end)
	if camera then camera.FieldOfView = 65 end

	local goofyRenderName = "RetroGoofyMotion_" .. tostring(math.random(10000, 99999))
	table.insert(RenderNames, goofyRenderName)

	RunService:BindToRenderStep(goofyRenderName, 400, function()
		if destroyed or not char.Parent or humanoid.Health <= 0 then
			pcall(function() RunService:UnbindFromRenderStep(goofyRenderName) end)
			return
		end
		-- SNZ's GoofyMotion: flung faster than TRIP_SPEED, you trip (and get up again once still: FallingDown above)
		if rootPart.AssemblyLinearVelocity.Magnitude > TRIP_SPEED and not humanoid.SeatPart
			and humanoid:GetState() ~= Enum.HumanoidStateType.FallingDown
			and humanoid:GetState() ~= Enum.HumanoidStateType.Ragdoll then
			pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.FallingDown) end)
		end
		camera = Workspace.CurrentCamera
		if not camera then return end
		local zoom = (camera.Focus.Position - camera.CFrame.Position).Magnitude
		if UserGameSettings.RotationType.Name == "CameraRelative" and not humanoid.SeatPart then
			local dir = zoom <= 1.5 and camera.CFrame.LookVector or nil
			if dir then
				bg.CFrame = CFrame.new(blankV3, dir * xz)
				bg.Parent = rootPart
			else
				bg.Parent = nil
			end
			humanoid.AutoRotate = false
		else
			humanoid.AutoRotate = (humanoid:GetState() == Enum.HumanoidStateType.Running) or climbing.Value
			bg.Parent = nil
		end
	end)

	-- ===== 2006 climbing =====
	-- Walk into any small part (a brick, a step, a ladder rung) and the character climbs it in
	-- the real Climbing state: a steady climb at 70% of WalkSpeed, pushed into the part and turned to face it. Let go
	-- (stop moving, or jump) and it drops. Big parts (floors, walls) are not climbed; a TrussPart
	-- is climbed by the Climbing state itself.
	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = { char, Workspace.CurrentCamera }
	overlapParams.RespectCanCollide = true

	-- what is in a 1-stud-wide box just in front, `lift` studs above the climbing box (0: 1 to 2 studs above the
	-- feet; CLIMB_REACH_UP: in front of the chest), `height` tall (1)
	local function partsAhead(lift, height)
		-- (the hip height is taken out: the Old physics squashes it after a fall, which would lower the
		-- search box into the ground and miss the bottom of a ladder)
		local boxCFrame
		if isR15 then
			-- R15: the same place as on R6, 1 to 2 studs above the feet, just in front
			local feet = rootPart.Position.Y - rootPart.Size.Y / 2 - baseHip - hipOffset
			local ahead = rootPart.Position + rootPart.CFrame.LookVector / 2
			boxCFrame = CFrame.new(ahead.X, feet + 1.5 + lift, ahead.Z)
		else
			local checkPos = torso.Position - Vector3.new(0, 1 + humanoid.HipHeight, 0)
			boxCFrame = CFrame.new(checkPos + torso.CFrame.LookVector / 2) * CFrame.new(0, -0.5 + lift, 0)
		end
		return Workspace:GetPartBoundsInBox(boxCFrame, Vector3.new(CLIMB_BOX.X, height or CLIMB_BOX.Y, CLIMB_BOX.Z), overlapParams)
	end

	local function climbablePartAhead(lift, height)
		local parts = partsAhead(lift or 0, height)
		for _, part in ipairs(parts) do
			local worldSize = part.CFrame:VectorToWorldSpace(part.Size)
			local average = (worldSize.X + worldSize.Y + worldSize.Z) / 3
			if not (average > MAX_CLIMB_PART or worldSize.Y >= MAX_CLIMB_PART) then
				return true
			end
		end
		return false
	end

	local function cantClimbNow()
		local state = humanoid:GetState()
		return humanoid.Sit
			or state == Enum.HumanoidStateType.Ragdoll
			or state == Enum.HumanoidStateType.FallingDown
			or state == Enum.HumanoidStateType.Jumping
			or state == Enum.HumanoidStateType.Swimming
	end

	-- Let go: drop out of the Climbing state and keep it off until the character has landed, so
	-- it does not grab the part again on the way down.
	local releasing = false
	local climbFacing = nil -- the way you faced the ladder when you grabbed it (flat)
	local function stopClimbing()
		if releasing then return end
		releasing = true
		grabStartY, climbFacing, grabbingNow = nil, nil, false
		climbForce.Parent = nil
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
			until destroyed or not humanoid.Parent
				or humanoid:GetState() ~= Enum.HumanoidStateType.Climbing or os.clock() > deadline

			local landDeadline = os.clock() + 3
			while not destroyed and humanoid.Parent and humanoid:GetState() ~= Enum.HumanoidStateType.Landed
				and os.clock() < landDeadline do
				task.wait()
			end
			if humanoid.Parent then
				pcall(function()
					humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
				end)
			end
			releasing = false
		end)
	end

	addConnection(RunService.RenderStepped:Connect(function()
		if destroyed or not char.Parent or humanoid.Health <= 0 then return end

		local moveDir = humanoid.MoveDirection
		local moving = moveDir.Magnitude > 0.01

		local velocity = torso.AssemblyLinearVelocity
		local frameNow = os.clock()
		local frameDt = math.min(frameNow - lastFrame, 0.1)
		lastFrame = frameNow

		-- Stairs are walked up, not climbed: a climb only STARTS once the part has really stopped you
		-- (you push and hardly move for BLOCKED_TIME). Going up stairs keeps you moving, so it never
		-- does. Once climbing, no such wait.
		local rootV = rootPart.AssemblyLinearVelocity
		local flatSpeed = math.sqrt(rootV.X * rootV.X + rootV.Z * rootV.Z)
		if moving and flatSpeed < humanoid.WalkSpeed * BLOCKED_SPEED then
			blockedFor = blockedFor + frameDt
		else
			blockedFor = 0
		end
		local onLadder = grabStartY ~= nil and frameNow - lastGrab <= GRAB_GRACE
		local blocked = blockedFor >= BLOCKED_TIME or onLadder

		-- CLIMBING (as SNZ's RetroClimbing): a climb starts by walking into something small in front of the
		-- feet (not while letting go, and not in a real fall: dropping past a wall must not grab it), and goes on
		-- while anything small is within reach in front from the toes to the head (one tall box: a gap between two
		-- rungs never ends it), stick or no stick, at a steady 70% of WalkSpeed. Pull the stick away from the
		-- ladder or jump to get off. Nothing in reach at all: the top (a step onto it) or, below a wall, hanging
		-- for a moment and then falling.
		local inReach
		if onLadder then
			inReach = climbablePartAhead(REACH_LIFT, REACH_HEIGHT)
		else
			inReach = climbablePartAhead(0)
		end
		local holding = inReach and not releasing and not cantClimbNow()
			and (onLadder or (moving and blocked and velocity.Y > -MAX_FALL_TO_GRAB))
		if holding and onLadder and climbFacing and moveDir.Magnitude >= 0.1 and moveDir:Dot(climbFacing) < -0.3 then
			stopClimbing() -- the stick pulled away from the ladder: let go
			holding = false
		end
		local now = frameNow
		local hanging = false
		if holding then
			if not grabStartY then
				grabStartY = torso.Position.Y
				local look = torso.CFrame.LookVector * XZ
				climbFacing = look.Magnitude > 0.01 and look.Unit or nil
			end
			lastGrab = now
			humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
			-- the sideways speed damped as before, but no kick up (it set 13 every frame, then gravity in between,
			-- which floated you up in hops): the climb force holds a steady climbing speed instead
			torso.AssemblyLinearVelocity = Vector3.new(velocity.X * CLIMB_SIDE_DAMP, velocity.Y, velocity.Z * CLIMB_SIDE_DAMP)
			climbForce.Velocity = Vector3.new(0, humanoid.WalkSpeed * CLIMB_SPEED_SHARE, 0)
			climbForce.Parent = rootPart
		elseif onLadder and not releasing and not cantClimbNow() then
			if torso.Position.Y - grabStartY >= TOP_OUT_MIN_RISE and #partsAhead(CLIMB_REACH_UP) == 0 then
				-- the real top (nothing at all in front of the chest): a step onto it, the way you were facing
				-- (SNZ steps you forward there). Between two rungs, or with the wall still there, the old hop shoved
				-- you into the ladder and you bounced off it.
				local v = torso.AssemblyLinearVelocity
				local dir = climbFacing or (moveDir * XZ)
				torso.AssemblyLinearVelocity = Vector3.new(dir.X * TOP_OUT_SPEED,
					math.max(v.Y, TOP_OUT_UP), dir.Z * TOP_OUT_SPEED)
				grabStartY, climbFacing = nil, nil
				climbForce.Parent = nil
			else
				-- nothing within reach for a moment (a wall above, the ladder's side): hang there, then fall
				hanging = true
				climbForce.Velocity = Vector3.zero
				climbForce.Parent = rootPart
			end
		else
			if grabStartY and now - lastGrab > GRAB_GRACE then grabStartY, climbFacing = nil, nil end
			climbForce.Parent = nil
		end

		grabbingNow = holding or hanging
		climbWanted = grabbingNow or humanoid:GetState() == Enum.HumanoidStateType.Climbing
		-- (2007 Animation.lua reads this to show its climbing pose, not its falling one)
		BPGenv.BPClimbing = climbWanted or nil
		climbActive = holding or releasing
			or humanoid:GetState() == Enum.HumanoidStateType.Climbing

		-- while holding on: pushed gently into the ladder and kept facing it, the way you faced it when you grabbed
		-- it (it turned you to the stick's direction, diagonal with the camera at an angle, which took you off a
		-- narrow ladder)
		if grabbingNow and climbFacing then
			climbLift.Parent = torso
			climbGyro.Parent = torso
			local pos = torso.Position
			climbGyro.CFrame = CFrame.lookAt(pos, pos + climbFacing)
			climbLift.Velocity = climbFacing * CLIMB_PUSH_SPEED
		else
			climbLift.Parent = nil
			climbGyro.Parent = nil
		end
	end))

	-- The physics step can flip the state to Freefall between two frames, and every animation
	-- script (Bloxy's 2008 / 2006 / 2014 ones included) shows what the last state was: falling.
	-- So after the physics step the Climbing state is put back while the climb is on.
	addConnection(RunService.Heartbeat:Connect(function()
		if destroyed or not char.Parent or humanoid.Health <= 0 then return end
		-- Only while a part really is in front of the feet. (Putting it back because "the state is
		-- Climbing" would keep itself going: once you leave the part you would hang in the Climbing
		-- state in mid-air instead of falling.)
		if grabbingNow and not releasing and humanoid:GetState() ~= Enum.HumanoidStateType.Climbing
			and not cantClimbNow() then
			humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
		end
		grabbingNow = false
	end))

	-- Jump lets go of whatever you are climbing.
	addConnection(UserInputService.JumpRequest:Connect(function()
		if destroyed then return end
		if humanoid:GetState() == Enum.HumanoidStateType.Climbing then stopClimbing() end
	end))

	-- "Climbing" (for the fallback climb animation and the turning below) follows the state.
	addConnection(humanoid.StateChanged:Connect(function(_, newState)
		local isClimbing = (newState == Enum.HumanoidStateType.Climbing)
		if climbing.Value ~= isClimbing then
			climbing.Value = isClimbing
			if isClimbing then print("[Retro Master] Climbing (2006 climbing).") end
		end
	end))

	local function onToolAdded(child)
		if not child:IsA("Tool") then return end
		local handle = child:FindFirstChild("Handle")
		if handle and child.RequiresHandle and handle:IsGrounded() then
			pcall(function() Workspace:UnjoinFromOutsiders({char}) end)
		end
	end

	for _, child in ipairs(char:GetChildren()) do onToolAdded(child) end
	addConnection(char.ChildAdded:Connect(onToolAdded))

	addConnection(humanoid.Died:Connect(function()
		climbForce.Parent = nil
		climbLift.Parent = nil
		climbGyro.Parent = nil
		BPGenv.BPClimbing = nil
	end))

	print("[Retro Master] Character system loaded (2006 climbing).")
end

if LocalPlayer.Character then task.spawn(setupCharacter, LocalPlayer.Character) end

addConnection(LocalPlayer.CharacterAdded:Connect(function(character)
	if destroyed then return end
	task.wait(0.15)
	if not destroyed then setupCharacter(character) end
end))

print("[Retro Master] Full script loaded successfully.")
]==]

	local CAMERA_SRC = nil

	local function fetchCameraScript()
		if CAMERA_SRC then return CAMERA_SRC end
		print("[Physics/Camera] Fetching camera script...")
		for _, url in ipairs({ CAMERA_URL, CAMERA_GIST }) do
			local ok, src = pcall(function()
				return game:HttpGet(url, true)
			end)
			if ok and type(src) == "string" and #src > 100 then
				CAMERA_SRC = src
				print("[Physics/Camera] Camera script fetched (" .. #src .. " bytes)" .. (url == CAMERA_GIST and ", from the gist" or "") .. ".")
				return src
			end
		end
		warn("[Physics/Camera] Failed to fetch camera script.")
		return nil
	end

	local PHYSICS_2006_SRC = nil

	local function fetchPhysics2006Script()
		if PHYSICS_2006_SRC then return PHYSICS_2006_SRC end
		print("[Physics/Camera] Fetching 2006 physics script...")
		for _, url in ipairs({ PHYSICS_2006_URL, PHYSICS_2006_GIST }) do
			local ok, src = pcall(function()
				return game:HttpGet(url, true)
			end)
			if ok and type(src) == "string" and #src > 100 and not src:find("^%s*<") and not src:find("^404") then
				PHYSICS_2006_SRC = src
				print("[Physics/Camera] 2006 physics script fetched (" .. #src .. " bytes"
					.. (url == PHYSICS_2006_GIST and ", the gist: R6 only" or ", works with R15 too") .. ").")
				return src
			end
		end
		warn("[Physics/Camera] Failed to fetch 2006 physics script.")
		return nil
	end

	local function runScript(src, label)
		if not src or #src < 100 then
			warn("[Physics/Camera] " .. (label or "") .. " script is empty.")
			return
		end
		local fn, err = loadstring(src)
		if not fn then
			warn("[Physics/Camera] loadstring failed for " .. (label or "") .. ": " .. tostring(err))
			return
		end
		local ok, e = pcall(fn)
		if not ok then warn("[Physics/Camera] Runtime " .. (label or "") .. ": " .. tostring(e)) end
	end

	local PHYSICS_VARIANTS = {
		{id = "old",  label = "Old"},
		{id = "2006", label = "2006"},
	}
	local selectedVariant = "old"

	local function variantLabel(id)
		for _, v in ipairs(PHYSICS_VARIANTS) do
			if v.id == id then return v.label end
		end
		return PHYSICS_VARIANTS[1].label
	end

	local function runPhysics(variant)
		if variant == "2006" then
			local src = fetchPhysics2006Script()
			if src then runScript(src, "2006 physics") end
		else
			runScript(PHYSICS_SRC, "physics")
		end
	end

	local function saveChoice(choice, variant)
		local cfg = {}
		if readfile and isfile and isfile(CONFIG_FILE) then
			pcall(function() cfg = HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
		end
		if type(cfg) ~= "table" then cfg = {} end
		cfg.physicsCameraChoice = choice
		cfg.physicsVariant = variant
		if writefile then
			pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(cfg)) end)
		end
	end

	local fontBold = Font.new("rbxasset://fonts/families/Arial.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

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
						if t:find("better emotes", 1, true) then
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
					print("[Physics/Camera Step] Detected, converting.")

					titleLabel.Text = "Old physics or old camera?"
					yesBtn.Visible = false
					noBtn.Visible = false

					-- The dropdown list hangs below the frame, so let it draw outside.
					local oldClips = frame.ClipsDescendants
					frame.ClipsDescendants = false

					local opts = {
						{text = "Old Camera",  x = 10,  width = 64, choice = "camera"},
						{text = "Old Physics", x = 79,  width = 64, choice = "physics"},
						{text = "Both",        x = 217, width = 64, choice = "both"},
						{text = "None",        x = 286, width = 64, choice = "none"},
					}

					local myButtons = {}
					local physicsBtn

					-- Physics type dropdown, sits between the two buttons it affects (Physics and Both)
					local dropdownBtn = makeButton("", UDim2.new(0, 148, 0, 45), 64, frame)
					table.insert(myButtons, dropdownBtn)

					local dropdownPad = Instance.new("UIPadding", dropdownBtn)
					dropdownPad.PaddingRight = UDim.new(0, 12)

					local arrow = Instance.new("TextLabel")
					arrow.Size = UDim2.new(0, 12, 1, 0)
					arrow.Position = UDim2.new(1, 0, 0, 0)
					arrow.BackgroundTransparency = 1
					arrow.Text = "▼"
					arrow.FontFace = fontBold
					arrow.TextSize = 10
					arrow.TextColor3 = dropdownBtn.TextColor3
					arrow.ZIndex = dropdownBtn.ZIndex + 1
					arrow.Parent = dropdownBtn
					dropdownBtn:GetPropertyChangedSignal("TextColor3"):Connect(function()
						arrow.TextColor3 = dropdownBtn.TextColor3
					end)

					local function refreshVariantText()
						local label = variantLabel(selectedVariant)
						dropdownBtn.Text = label
						if physicsBtn then physicsBtn.Text = label .. " Physics" end
					end

					local listItems = {}
					local function setListOpen(open)
						for _, item in ipairs(listItems) do item.Visible = open end
					end

					for i, v in ipairs(PHYSICS_VARIANTS) do
						local item = makeButton(v.label .. " Physics", UDim2.new(0, 148, 0, 45 + 32 * i), 64, frame)
						item.ZIndex = 10
						item.Visible = false
						table.insert(listItems, item)
						table.insert(myButtons, item)

						item.MouseButton1Click:Connect(function()
							playClick()
							selectedVariant = v.id
							refreshVariantText()
							setListOpen(false)
						end)
					end

					dropdownBtn.MouseButton1Click:Connect(function()
						playClick()
						setListOpen(not listItems[1].Visible)
					end)

					for _, opt in ipairs(opts) do
						local btn = makeButton(opt.text, UDim2.new(0, opt.x, 0, 45), opt.width, frame)
						table.insert(myButtons, btn)
						if opt.choice == "physics" then physicsBtn = btn end

						btn.MouseButton1Click:Connect(function()
							playClick()
							setListOpen(false)
							local variant = selectedVariant
							print("[Physics/Camera] Picked " .. opt.choice .. " (physics: " .. variant .. ")")
							saveChoice(opt.choice, variant)

							if opt.choice == "physics" or opt.choice == "both" then
								task.spawn(function() runPhysics(variant) end)
							end
							if opt.choice == "camera" or opt.choice == "both" then
								task.spawn(function()
									local src = fetchCameraScript()
									if src then runScript(src, "camera") end
								end)
							end

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
							frame.ClipsDescendants = oldClips

							titleLabel.Text = "Do you want better emotes?"
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

					refreshVariantText()

					return
				end
			end
		end
	end)

	-- Only restore the dropdown's last physics type; nothing runs until a button is clicked.
	if readfile and isfile and isfile(CONFIG_FILE) then
		pcall(function()
			local cfg = HttpService:JSONDecode(readfile(CONFIG_FILE))
			if type(cfg) == "table" and type(cfg.physicsVariant) == "string" then
				selectedVariant = cfg.physicsVariant
			end
		end)
	end

	print("[Physics/Camera Step] Loaded.")
end)