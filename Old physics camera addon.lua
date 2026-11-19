-- [[ PHYSICS + CAMERA WIZARD STEP — with None option ]]
-- (Addtion-Scripts copy: three physics, one for each era, picked in the dropdown.
--  "Old" (2010-2013), with Rowind's character physics for its 2011-2012 clients (its PhysicsSimulation and
--  HumanoidRotate scripts, made to run from an executor and on R15 too): the body stands a tenth of a stud into the
--  ground and a little higher for 1.5 s after each landing; no jumping again for half a second after landing; a
--  landing faster than 200 studs a second springs back up at 75% of the speed; and the character is turned by a
--  gyro, a share of the way each frame and more weakly in the air (not snapped round, and still steerable in a
--  jump), facing the camera in first person / shift lock. Climbing is Retro Studio's CustomClimbing (see OLD:
--  CLIMBING below): ladders, trusses and the like are climbed while the stick is held, up at 70% of WalkSpeed and
--  along at the whole WalkSpeed; let go and you drop.
--  "2007": the same script, as the Old physics was first made from Super Nostalgia Zone's character scripts: the
--  small bounce on every landing (SNZ Bounciness), sinking into the ground on landing (SNZ FloorDrag) and tripping
--  when flung faster than 200 studs a second (SNZ GoofyMotion), with Roblox's own turning, and its own ladder
--  climbing: only while the stick is held, at 70% of WalkSpeed; let go and you hang a moment (HANG_TIME), then drop.
--  "2006": this repo's copy of FWM's (2006 Physics.lua).
--  R6 and R15 alike: the hip height moves around the avatar's own (an R15 body stands on it), the 2007 sink moves an
--  R15 body on its root joint, and the 2007 climbing check is measured from the feet.)

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
-- Which era (the wizard sets PHYSICS_ERA): "old" = 2010-2013, as Retro Studio and Rowind have it (no sinking into the
-- ground, no bounce on landing); "2007" = the Old physics as it was first made, with both.
local ERA_2007 = (PHYSICS_ERA == "2007")

if _G.__RetroMasterCleanup then pcall(_G.__RetroMasterCleanup) end
-- the 2006 physics, if it was picked before: stopped, so two physics never fight over the character
if BPGenv.__Physics2006Cleanup then pcall(BPGenv.__Physics2006Cleanup) end

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
local TRIP_SPEED = 200          -- 2007 only: flung faster than this (studs a second): you trip (SNZ GoofyMotion's VelocityThreshold)
local CLIMB_PUSH_SPEED = 12     -- push into the part (gentle: it was 24)
local BLOCKED_SPEED = 0.35       -- slower than this share of WalkSpeed while walking = blocked by the part
local BLOCKED_TIME = 0.15        -- ...for this long (seconds) before a climb starts: stairs are walked up
local GRAB_GRACE = 0.25          -- seconds the climb is held between two rungs / bricks
local TOP_OUT_TIME = 0.4        -- seconds after the last grab in which you are still topping out
local TOP_OUT_MIN_RISE = 1.5    -- studs climbed before the top-out hop counts
local TOP_OUT_SPEED = 10        -- a step forward onto the top
local TOP_OUT_UP = 4            -- ...keeping (at least) a little of the climb's rise
local MAX_FALL_TO_GRAB = 8      -- falling faster than this: no grabbing
local HANG_TIME = 0.85          -- 2007: the stick let go on a ladder: you hang there this long (seconds), then drop
-- Old: Retro Studio's CustomClimbing (its clients before 0.123)
local RETRO_RAYS_FROM, RETRO_RAYS_TO = 2, 16 -- its rays, numbered as it does: ray i is i * 0.225 - 2.25 studs above the
local RETRO_RAY_STEP = 0.225                 -- middle of the body (1.8 below it to 1.35 above), one stud long
local RETRO_LIFT_FORCE, RETRO_LIFT_P = 25000, 100000
local SINK_RATE = 20 / 3        -- 2007 only: studs a second the body sinks / rises while falling / rising fast (SNZ FloorDrag)
local SINK_DECAY = 0.925        -- 2007 only: share of the sink kept each 1/60 s back on the ground
-- Old only: Rowind's character physics for the 2011-2012 clients (its PhysicsSimulation and HumanoidRotate scripts)
local ROWIND_SINK = -0.1        -- the body stands this far into the ground (hip height; R15: on its root joint)
local ROWIND_LANDED = 0.025     -- ...right after a landing it stands here instead
local ROWIND_LANDED_TIME = 1.5  -- ...for this long (seconds)
local ROWIND_SETTLE_TIME = 0.25 -- ...then eases back down over this long
local JUMP_COOLDOWN = 0.5       -- no jumping again for this long after landing
local JUMP_PAUSE_2007 = 0.5     -- 2007 only: no jumping for this long after each landing (the jump button goes away meanwhile)
local SPRING_SPEED = 200        -- landing faster than this (studs a second): springs back up...
local SPRING_KEEP = 0.75        -- ...with this share of the speed
local TURN_TORQUE = 2000        -- turning: the gyro's strength, so the character turns round rather than snapping
local TURN_P_GROUND, TURN_P_AIR = 4000, 1000 -- ...and how hard it pulls, on the ground and in the air
local TURN_SHARE = 0.2          -- ...the facing it aims for moves this share of the way each 1/60 s
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

	-- The real Climbing state is what the climbing runs on (an earlier copy of this script
	-- switched it off).
	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
	end)

	-- No climb animation of our own is played any more: it was Roblox's modern one, which showed up
	-- over whichever animation you picked in the wizard. The climbing state is kept up instead (below),
	-- so the animation you picked plays ITS OWN climbing animation.
	local climbWanted = false -- true while the climbing is at work
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

	-- (Old: when the last landing was, for Rowind's sink, and until when jumping is held off)
	local landedAt = nil
	local jumpBlockedUntil = 0

	-- 2007 only: THE PAUSE AFTER A LANDING before you can jump again, as in the user's recording of the old client:
	-- after each landing the phone's jump button goes away for about half a second, then comes back. The humanoid's
	-- jump power is put to 0 for JUMP_PAUSE_2007 (no jump can start, and Roblox takes the jump button off while it is
	-- 0), then the game's own is put back. If the game sets its own jump power during a pause, that is the one put
	-- back. Put back too when this physics stops or the character goes.
	local pauseProp, pauseSaved, pauseToken = nil, nil, nil
	local function jumpProp()
		local ok, use = pcall(function() return humanoid.UseJumpPower end)
		return (ok and use == false) and "JumpHeight" or "JumpPower"
	end
	local function endJumpPause()
		local prop, saved = pauseProp, pauseSaved
		pauseProp, pauseSaved, pauseToken = nil, nil, nil
		if prop and saved ~= nil and humanoid.Parent then
			pcall(function() if humanoid[prop] == 0 then humanoid[prop] = saved end end)
		end
	end
	local function startJumpPause()
		if not pauseProp then
			local prop = jumpProp()
			local ok, current = pcall(function() return humanoid[prop] end)
			if not ok or type(current) ~= "number" or current <= 0 then return end -- (jumping is off anyway)
			pauseProp, pauseSaved = prop, current
			pcall(function() humanoid[prop] = 0 end)
		end
		-- (a landing during a pause starts it again)
		local token = {}
		pauseToken = token
		task.delay(JUMP_PAUSE_2007, function()
			if pauseToken == token then endJumpPause() end
		end)
	end
	if ERA_2007 then
		for _, prop in ipairs({ "JumpPower", "JumpHeight" }) do
			addConnection(humanoid:GetPropertyChangedSignal(prop):Connect(function()
				-- the game set its own during a pause: kept as the one to put back
				if pauseProp == prop and humanoid[prop] ~= 0 then
					pauseSaved = humanoid[prop]
					humanoid[prop] = 0
				end
			end))
		end
		table.insert(CharacterObjects, { Parent = true, Destroy = endJumpPause })
	end

	addConnection(humanoid.StateChanged:Connect(function(oldState, newState)
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
		elseif ERA_2007 and lastFallSpeed > 0 and not climbWanted and climbForce.Parent == nil then
			-- 2007 only: SNZ's Bounciness, the small bounce on every landing, an upward push on the head of half the
			-- landing speed times gravity, for a 30th of a second (not on a ladder: feet on a rung). 2010-2013 (Retro
			-- Studio, Rowind) lands flat: a plain jump.
			local head = char:FindFirstChild("Head")
			if head then
				local bounce = Instance.new("BodyForce")
				bounce.Name = "Bounce"
				bounce.Force = Vector3.new(0, lastFallSpeed * Workspace.Gravity / 2, 0)
				bounce.Parent = head
				task.delay(1 / 30, function() pcall(function() bounce:Destroy() end) end)
			end
		elseif not ERA_2007 and not climbWanted and climbForce.Parent == nil then
			-- Old (Rowind's PhysicsSimulation for the 2011-2012 clients): no jumping again for half a second after
			-- a landing (from a fall, as Rowind has it: not straight out of a jump); a landing faster than
			-- SPRING_SPEED springs back up with 75% of the speed; any other landing stands the body a little higher
			-- for a moment (see the hip height below)
			if oldState ~= Enum.HumanoidStateType.Jumping then
				jumpBlockedUntil = os.clock() + JUMP_COOLDOWN
			end
			if lastFallSpeed > SPRING_SPEED then
				local v = rootPart.AssemblyLinearVelocity
				rootPart.AssemblyLinearVelocity = Vector3.new(v.X, lastFallSpeed * SPRING_KEEP, v.Z)
			else
				landedAt = os.clock()
			end
		end
		-- 2007: the pause before the next jump (not on a trampoline's launch, a ladder or a seat)
		if ERA_2007 and bounceMultiplier == 1 and not climbWanted and climbForce.Parent == nil and not humanoid.SeatPart then
			startJumpPause()
		end
		lastFallSpeed = 0
	end))

	-- Old: the jump held off after a landing. Not by switching the Jumping state off (that hid the phone's jump
	-- button and could leave a jump stuck in the walking state): the jump the controls ask for is taken back
	-- until the time is up (the controls ask again every frame while the button is held, so it jumps then).
	addConnection(humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
		if destroyed or ERA_2007 then return end
		if humanoid.Jump and os.clock() < jumpBlockedUntil then
			humanoid.Jump = false
		end
	end))

	-- (The Jumping state is never switched off for this: that could leave a jump made while walking stuck in the
	-- walking state. 2007's pause uses the jump power instead, above. The 2006 physics keeps its own.)

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

	-- true while the climbing below is at work (set there)
	local climbActive = false

	-- SINKING INTO THE GROUND (2007 only), as the Old physics first had it (SNZ's FloorDrag): falling or rising fast
	-- moves the body down or up (up to a stud), so a landing ends with the legs in the ground and the body rises back
	-- out within about half a second. Not while sitting, climbing or swimming. R6: through the hip height. R15: the
	-- body is moved on its root joint (LowerTorso.Root) instead, as the 2006 physics does it (a lower hip height makes
	-- Roblox's R15 animations run faster). The Old physics (2010-2013) has Rowind's stance instead: a tenth of a stud
	-- into the ground, a little higher for a moment after each landing (see the render step below), the same ways.
	local sinkOffset = 0
	local sinkRay = RaycastParams.new()
	sinkRay.FilterType = Enum.RaycastFilterType.Exclude
	sinkRay.FilterDescendantsInstances = { char }
	local function getFloorLevel()
		local origin = rootPart.Position
		local hit = Workspace:Raycast(origin, Vector3.new(0, -5000, 0), sinkRay)
		if not hit then return origin.Y, 0 end
		return hit.Position.Y, math.clamp(math.abs(hit.Position.Y - origin.Y), -1, 1)
	end
	local function moveTowards(value, goal, rate)
		if value < goal then return math.min(goal, value + rate)
		elseif value > goal then return math.max(goal, value - rate)
		else return goal end
	end

	-- R15: the body moved on its root joint, from whatever anything else sets it to; put back when this stops
	local rootJoint, rootBase, rootWritten = nil, nil, nil
	local function applyR15Sink()
		if not (rootJoint and rootJoint.Parent) then
			local lowerTorso = char:FindFirstChild("LowerTorso")
			rootJoint = lowerTorso and lowerTorso:FindFirstChild("Root")
			rootBase, rootWritten = nil, nil
			if not (rootJoint and rootJoint:IsA("Motor6D")) then rootJoint = nil return end
		end
		local current = rootJoint.C0
		if rootWritten == nil or current ~= rootWritten then rootBase = current end
		local want = rootBase + Vector3.new(0, sinkOffset, 0)
		if current ~= want then rootJoint.C0 = want end
		rootWritten = rootJoint.C0
	end
	do
		-- stopped mid-sink: the body put back up (and Roblox's own turning back on)
		table.insert(CharacterObjects, {
			Parent = true,
			Destroy = function()
				if humanoid.Parent then pcall(function() humanoid.AutoRotate = true end) end
				if isR15 then
					if rootJoint and rootJoint.Parent and rootBase and rootJoint.C0 == rootWritten then
						rootJoint.C0 = rootBase
					end
				elseif humanoid.Parent and lastSetHip and math.abs(humanoid.HipHeight - lastSetHip) < 0.001 then
					humanoid.HipHeight = baseHip
				end
			end,
		})
	end

	local hipRenderName = "RetroHipHeight_" .. tostring(math.random(10000, 99999))
	table.insert(RenderNames, hipRenderName)

	local lastLevel = ERA_2007 and getFloorLevel() or 0
	RunService:BindToRenderStep(hipRenderName, 390, function(dt)
		if destroyed or not char.Parent or humanoid.Health <= 0 then
			pcall(function() RunService:UnbindFromRenderStep(hipRenderName) end)
			return
		end
		if not ERA_2007 then
			-- Old: Rowind's stance (the 2011-2012 clients): a tenth of a stud into the ground, a little higher for
			-- 1.5 s after a landing, then easing back down
			local offset = ROWIND_SINK
			if landedAt then
				local t = os.clock() - landedAt
				if t < ROWIND_LANDED_TIME then
					offset = ROWIND_LANDED
				elseif t < ROWIND_LANDED_TIME + ROWIND_SETTLE_TIME then
					local a = (t - ROWIND_LANDED_TIME) / ROWIND_SETTLE_TIME
					a = 1 - (1 - a) * (1 - a) -- (eased out, as Rowind's tween)
					offset = ROWIND_LANDED + (ROWIND_SINK - ROWIND_LANDED) * a
				end
			end
			sinkOffset = offset
			if isR15 then
				hipOffset = 0
				applyR15Sink()
			else
				hipOffset = sinkOffset
			end
			applyHip()
			return
		end
		dt = math.min(0.1, dt or 1 / 60)
		if humanoid.SeatPart or humanoid.Sit or climbActive
			or humanoid:GetState() == Enum.HumanoidStateType.Swimming then
			sinkOffset = 0
			lastLevel = getFloorLevel()
		else
			local level, dist = getFloorLevel()
			local yVelocity = rootPart.AssemblyLinearVelocity.Y
			if math.abs(yVelocity) > 8 then
				sinkOffset = moveTowards(sinkOffset, math.sign(yVelocity), SINK_RATE * dt)
			elseif lastLevel ~= level then
				-- walked onto a higher or lower floor (SNZ's step change; it always comes to 0)
				sinkOffset = math.sign(lastLevel - level) * math.clamp(dist - 3, 0, 1)
				lastLevel = level
			else
				sinkOffset = sinkOffset * (SINK_DECAY ^ (dt * 60))
				if math.abs(sinkOffset) < 0.001 then sinkOffset = 0 end
			end
		end
		if isR15 then
			hipOffset = 0
			applyR15Sink()
		else
			hipOffset = sinkOffset
		end
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

	-- ===== Old: turning, as Rowind's HumanoidRotate does it (R6 and R15) =====
	-- The character is not snapped round to face where it walks (Roblox's own AutoRotate): a gyro turns it, a
	-- share of the way each frame, with limited strength, and more weakly in the air, so a jump can still be
	-- steered round but slowly (the Old physics used to switch turning off in the air altogether). In first
	-- person or shift lock it turns to face the camera. Not while sitting, climbing, tripped and so on, and not
	-- while walking to a clicked point (Roblox turns it then).
	local turnGyro = Instance.new("BodyGyro")
	turnGyro.Name = "HumanoidRotate"
	turnGyro.D = 0
	turnGyro.P = 3800
	turnGyro.MaxTorque = Vector3.new(0, TURN_TORQUE, 0)
	table.insert(CharacterObjects, turnGyro)
	local NO_TURN = {
		[Enum.HumanoidStateType.Dead] = true,
		[Enum.HumanoidStateType.Ragdoll] = true,
		[Enum.HumanoidStateType.Seated] = true,
		[Enum.HumanoidStateType.PlatformStanding] = true,
		[Enum.HumanoidStateType.FallingDown] = true,
		[Enum.HumanoidStateType.Flying] = true,
		[Enum.HumanoidStateType.Climbing] = true,
	}
	local isMoveTo = false
	if not ERA_2007 then
		addConnection(humanoid:GetPropertyChangedSignal("WalkToPoint"):Connect(function() isMoveTo = true end))
		addConnection(humanoid:GetPropertyChangedSignal("WalkToPart"):Connect(function() isMoveTo = true end))
		addConnection(humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function() isMoveTo = false end))
		addConnection(humanoid.MoveToFinished:Connect(function() isMoveTo = false end))
	end
	local turnTime = 0
	local function turnStep(dt, zoom)
		turnTime = turnTime + (dt or 1 / 60)
		if turnTime < 1 / 60 then return end -- (60 times a second at most, as Rowind)
		local elapsed = math.min(turnTime, 0.1)
		turnTime = turnTime % (1 / 60)
		local state = humanoid:GetState()
		local faceCamera = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter or zoom <= 1.5
		humanoid.AutoRotate = isMoveTo or state == Enum.HumanoidStateType.Climbing
		local moveDir = humanoid.MoveDirection
		local dir = (faceCamera and camera.CFrame.LookVector or moveDir) * XZ
		if (moveDir.Magnitude > 0 or faceCamera) and dir.Magnitude > 0.01 and not humanoid.PlatformStand
			and not humanoid.SeatPart and not NO_TURN[state] and not isMoveTo and climbLift.Parent == nil then
			if turnGyro.Parent == nil then turnGyro.CFrame = rootPart.CFrame end -- (from where it faces now)
			if not faceCamera then
				local inAir = state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall
				turnGyro.P = inAir and TURN_P_AIR or TURN_P_GROUND
			end
			local pos = rootPart.Position
			local share = 1 - (1 - TURN_SHARE) ^ (elapsed * 60)
			turnGyro.CFrame = turnGyro.CFrame:Lerp(CFrame.lookAt(pos, pos + dir.Unit), math.clamp(share, 0, 1))
			turnGyro.Parent = rootPart
			humanoid.AutoRotate = false
		else
			turnGyro.Parent = nil
		end
	end

	local goofyRenderName = "RetroGoofyMotion_" .. tostring(math.random(10000, 99999))
	table.insert(RenderNames, goofyRenderName)

	RunService:BindToRenderStep(goofyRenderName, 400, function(dt)
		if destroyed or not char.Parent or humanoid.Health <= 0 then
			pcall(function() RunService:UnbindFromRenderStep(goofyRenderName) end)
			return
		end
		-- 2007 (SNZ's GoofyMotion): flung faster than TRIP_SPEED, you trip (and get up again once still: FallingDown
		-- above). The Old physics springs back off a hard landing instead (Rowind, above).
		if ERA_2007 and rootPart.AssemblyLinearVelocity.Magnitude > TRIP_SPEED and not humanoid.SeatPart
			and humanoid:GetState() ~= Enum.HumanoidStateType.FallingDown
			and humanoid:GetState() ~= Enum.HumanoidStateType.Ragdoll then
			pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.FallingDown) end)
		end
		camera = Workspace.CurrentCamera
		if not camera then return end
		local zoom = (camera.Focus.Position - camera.CFrame.Position).Magnitude
		if not ERA_2007 then
			bg.Parent = nil
			turnStep(dt, zoom)
			return
		end
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

	-- ===== OLD: CLIMBING, as Retro Studio's CustomClimbing (its clients before 0.123) =====
	-- Retro Studio's own script, made to run from an executor and on R15. Roblox's own climbing is switched off.
	-- While the stick is held (and you are not sitting), every frame 15 one-stud rays go straight out of the front
	-- of the body, 0.225 studs apart, from 1.8 below its middle to 1.35 above (parts you can walk through are looked
	-- through). What is in front is climbable when the rays find a TrussPart, or when what they hit starts and stops
	-- more than once going up: ladder rungs, a step with nothing above it, a wall with a gap; not a plain wall. While
	-- it is, a lift is held on the body: up at 70% of WalkSpeed, along with the stick at the whole WalkSpeed. Let go
	-- of the stick and the lift goes: you drop. Ladders and trusses alike. R15: the rays are as long as the body is
	-- deep (plus half a stud) and their heights go from the feet, so a deeper or taller R15 body finds the same
	-- things. Roblox's Climbing state is put on only while this climbs, so every animation shows its climbing pose.
	local retroRay = RaycastParams.new()
	retroRay.FilterType = Enum.RaycastFilterType.Exclude
	retroRay.FilterDescendantsInstances = { char }
	local retroLift = Instance.new("BodyVelocity")
	retroLift.Name = "ClimbLift"
	retroLift.MaxForce = Vector3.new(RETRO_LIFT_FORCE, RETRO_LIFT_FORCE, RETRO_LIFT_FORCE)
	retroLift.P = RETRO_LIFT_P
	retroLift.Velocity = Vector3.new(0, 11.2, 0)
	table.insert(CharacterObjects, retroLift)
	local retroClimbing = false
	local robloxClimbOn = true
	local function setRobloxClimbing(on)
		if robloxClimbOn == on then return end
		robloxClimbOn = on
		pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, on) end)
	end
	-- how deep the body is (R15: its upper torso can be deeper than the root; R6: the torso)
	local function halfDepth()
		local d = rootPart.Size.Z
		local upper = isR15 and char:FindFirstChild("UpperTorso") or torso
		if upper and upper:IsA("BasePart") then d = math.max(d, upper.Size.Z) end
		return d / 2
	end
	local function retroClimbable()
		local look = rootPart.CFrame.LookVector
		local length, base = 1, rootPart.Position
		if isR15 then
			length = math.max(1, halfDepth() + 0.5)
			-- (the same heights from the feet as on R6, whose body's middle is 3 studs above its feet)
			local feet = rootPart.Position.Y - rootPart.Size.Y / 2 - humanoid.HipHeight
			base = Vector3.new(rootPart.Position.X, feet + 3, rootPart.Position.Z)
		end
		local filter = { char }
		retroRay.FilterDescendantsInstances = filter
		local edges, inside, truss = 0, false, false
		for i = RETRO_RAYS_FROM, RETRO_RAYS_TO do
			local hit
			for _ = 1, 100 do
				hit = Workspace:Raycast(base + Vector3.new(0, i * RETRO_RAY_STEP - 2.25, 0), look * length, retroRay)
				if not hit or not hit.Instance or not hit.Instance:IsA("BasePart") or hit.Instance.CanCollide then break end
				table.insert(filter, hit.Instance) -- (walked through: looked through)
				retroRay.FilterDescendantsInstances = filter
			end
			local part = hit and hit.Instance
			if part and part:IsA("BasePart") and part.CanCollide and part:IsDescendantOf(Workspace) then
				if not inside then
					edges += 1
					inside = true
				end
				if part:IsA("TrussPart") then truss = true end
			elseif inside then
				edges += 1
				inside = false
			end
		end
		return edges > 1 or truss
	end
	if not ERA_2007 then
		setRobloxClimbing(false)
		table.insert(CharacterObjects, { -- (stopped: Roblox's climbing back on)
			Parent = true,
			Destroy = function() if humanoid.Parent then setRobloxClimbing(true) end end,
		})
		addConnection(RunService.Heartbeat:Connect(function()
			if destroyed or not char.Parent or humanoid.Health <= 0 then return end
			local md = humanoid.MoveDirection
			local climbingNow = false
			if not humanoid.SeatPart and md.Magnitude > 0 then
				local ok, yes = pcall(retroClimbable)
				climbingNow = ok and yes == true
			end
			if climbingNow then
				local ws = humanoid.WalkSpeed
				retroLift.Velocity = Vector3.new(md.X * ws, ws * CLIMB_SPEED_SHARE, md.Z * ws)
				if retroLift.Parent ~= rootPart then retroLift.Parent = rootPart end
				-- (the climbing pose: Roblox's Climbing state, only while this climbs)
				setRobloxClimbing(true)
				if humanoid:GetState() ~= Enum.HumanoidStateType.Climbing then
					pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Climbing) end)
				end
			else
				retroLift.Parent = nil
				if robloxClimbOn then
					setRobloxClimbing(false)
					if humanoid:GetState() == Enum.HumanoidStateType.Climbing then
						pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Freefall) end)
					end
				end
			end
			retroClimbing = climbingNow
			climbWanted, climbActive = climbingNow, climbingNow
			BPGenv.BPClimbing = climbingNow or nil
		end))
	end
	-- ===== 2007: climbing (the Old physics as it was first made) =====
	-- Walk into any small part (a brick, a step, a ladder rung) and the character climbs it in
	-- the real Climbing state: a steady climb at 70% of WalkSpeed while the stick is held, pushed into the part and
	-- turned to face it. Let go of the stick and it hangs there; let go for HANG_TIME (or pull the stick away, or
	-- jump) and it drops. Nothing climbs you up on its own. Big parts (floors, walls) are not climbed; a TrussPart
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
	local lastStick = 0     -- when the stick was last held
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

		-- (the Old physics climbs as Retro Studio does, above: this is the 2007 climbing)
		if not ERA_2007 then return end

		local moveDir = humanoid.MoveDirection
		local moving = moveDir.Magnitude > 0.01

		local velocity = torso.AssemblyLinearVelocity
		local frameNow = os.clock()
		if moveDir.Magnitude >= 0.1 then lastStick = frameNow end

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

		-- CLIMBING (as Retro Studio and Rowind have it): a climb starts by walking into something small in front of
		-- the feet (not while letting go, and not in a real fall: dropping past a wall must not grab it), and goes on
		-- while anything small is within reach in front from the toes to the head (one tall box: a gap between two
		-- rungs never ends it). Stick held: a steady climb at 70% of WalkSpeed. Stick let go: hanging there, and
		-- after HANG_TIME dropping off. Pull the stick away from the ladder or jump to get off. Nothing in reach at
		-- all: the top (a step onto it) or, below a wall, hanging for a moment and then falling.
		local inReach
		if onLadder then
			inReach = climbablePartAhead(REACH_LIFT, REACH_HEIGHT)
		else
			inReach = climbablePartAhead(0)
		end
		local holding = inReach and not releasing and not cantClimbNow()
			and (onLadder or (moving and blocked and velocity.Y > -MAX_FALL_TO_GRAB))
		if holding and onLadder then
			local stickLetGo = frameNow - lastStick > HANG_TIME
			local pushedAway = climbFacing ~= nil and moveDir.Magnitude >= 0.1 and moveDir:Dot(climbFacing) < -0.3
			if stickLetGo or pushedAway then
				stopClimbing() -- hung there long enough, or the stick pulled away from the ladder: let go
				holding = false
			end
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
			-- climbing only while the stick is held; let go of it: hanging there
			local climbSpeed = (frameNow - lastStick <= 0.1) and humanoid.WalkSpeed * CLIMB_SPEED_SHARE or 0
			climbForce.Velocity = Vector3.new(0, climbSpeed, 0)
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

	-- Jump lets go of whatever you are climbing (2007; the Old physics leaves that to Roblox too).
	addConnection(UserInputService.JumpRequest:Connect(function()
		if destroyed or not ERA_2007 then return end
		if humanoid:GetState() == Enum.HumanoidStateType.Climbing then stopClimbing() end
	end))

	-- "Climbing" (for the fallback climb animation and the turning below) follows the state.
	addConnection(humanoid.StateChanged:Connect(function(_, newState)
		local isClimbing = (newState == Enum.HumanoidStateType.Climbing)
		if climbing.Value ~= isClimbing then
			climbing.Value = isClimbing
			if isClimbing then print("[Retro Master] Climbing.") end
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
		retroLift.Parent = nil
		climbForce.Parent = nil
		climbLift.Parent = nil
		climbGyro.Parent = nil
		BPGenv.BPClimbing = nil
	end))

	print("[Retro Master] Character system loaded (" .. (ERA_2007 and "2007" or "2010-2013") .. " physics).")
end

if LocalPlayer.Character then task.spawn(setupCharacter, LocalPlayer.Character) end

addConnection(LocalPlayer.CharacterAdded:Connect(function(character)
	if destroyed then return end
	task.wait(0.15)
	if not destroyed then setupCharacter(character) end
end))

print("[Retro Master] Full script loaded successfully.")
]==]

	-- three cameras, picked in the camera dropdown: 2018 (the zoom from before the 2018 camera update, Pre-2018
	-- Camera.lua), 2013 (the Retro camera with 2012 first person, Retro Camera.lua) and 2007 (Retro Studio's 2007
	-- camera: the same old camera with its FollowCamera on, so it swings round behind you as you walk)
	local CAMERA_VARIANTS = {
		{id = "2018", label = "2018", urls = { "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/Pre-2018%20Camera.lua" }},
		{id = "2013", label = "2013", urls = { CAMERA_URL, CAMERA_GIST }},
		{id = "2007", label = "2007", urls = { CAMERA_URL }, prefix = 'local CAMERA_ERA = "2007"\n'},
	}
	local selectedCamera = "2013"
	local cameraSources = {}

	local function cameraVariant(id)
		for _, v in ipairs(CAMERA_VARIANTS) do
			if v.id == id then return v end
		end
		return CAMERA_VARIANTS[2]
	end

	local function fetchCameraScript(id)
		local v = cameraVariant(id)
		if cameraSources[v.id] then return cameraSources[v.id] end
		print("[Physics/Camera] Fetching the " .. v.label .. " camera script...")
		for i, url in ipairs(v.urls) do
			local ok, src = pcall(function()
				return game:HttpGet(url, true)
			end)
			if ok and type(src) == "string" and #src > 100 and not src:find("^%s*<") and not src:find("^404") then
				cameraSources[v.id] = src
				print("[Physics/Camera] " .. v.label .. " camera script fetched (" .. #src .. " bytes)" .. (i > 1 and ", from the gist" or "") .. ".")
				return src
			end
		end
		warn("[Physics/Camera] Failed to fetch the " .. v.label .. " camera script.")
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

	-- One physics for each era: Old (2010-2013, as Retro Studio and Rowind have it), 2007 (the Old physics as it was
	-- first made: sinking into the ground and bouncing on landings) and 2006 (FWM's).
	local PHYSICS_VARIANTS = {
		{id = "old",  label = "Old"},
		{id = "2007", label = "2007"},
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
		elseif variant == "2007" then
			runScript("local PHYSICS_ERA = \"2007\"\n" .. PHYSICS_SRC, "2007 physics")
		else
			runScript("local PHYSICS_ERA = \"old\"\n" .. PHYSICS_SRC, "physics")
		end
	end

	local function saveChoice(choice, variant, camera)
		local cfg = {}
		if readfile and isfile and isfile(CONFIG_FILE) then
			pcall(function() cfg = HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
		end
		if type(cfg) ~= "table" then cfg = {} end
		cfg.physicsCameraChoice = choice
		cfg.physicsVariant = variant
		cfg.cameraVariant = camera
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

	-- (looked for 5 times a second: it went through Bloxy's windows on every frame for the whole game)
	local lookAcc = 0
	RunService.RenderStepped:Connect(function(dt)
		if not sg or not sg.Parent then return end
		lookAcc = lookAcc + (dt or 0)
		if lookAcc < 0.2 then return end
		lookAcc = 0

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

					-- [Camera][camera ▼][Physics][physics ▼][Both][None]: each dropdown next to the button it changes
					local W, GAP, X0 = 54, 4, 8
					local function col(i) return X0 + (i - 1) * (W + GAP) end
					local opts = {
						{text = "2013 Camera", x = col(1), width = W, choice = "camera"},
						{text = "Old Physics", x = col(3), width = W, choice = "physics"},
						{text = "Both",        x = col(5), width = W, choice = "both"},
						{text = "None",        x = col(6), width = W, choice = "none"},
					}

					local myButtons = {}
					local physicsBtn, cameraBtn
					local lists = {}

					local function setListOpen(which, open)
						for name, items in pairs(lists) do
							local show = open and name == which
							for _, item in ipairs(items) do item.Visible = show end
						end
					end
					local function closeLists() setListOpen(nil, false) end

					local function makeDropdown(name, x)
						local btn = makeButton("", UDim2.new(0, x, 0, 45), W, frame)
						btn.Name = name
						table.insert(myButtons, btn)
						local pad = Instance.new("UIPadding", btn)
						pad.PaddingRight = UDim.new(0, 12)
						local arrow = Instance.new("TextLabel")
						arrow.Size = UDim2.new(0, 12, 1, 0)
						arrow.Position = UDim2.new(1, 0, 0, 0)
						arrow.BackgroundTransparency = 1
						arrow.Text = "▼"
						arrow.FontFace = fontBold
						arrow.TextSize = 10
						arrow.TextColor3 = btn.TextColor3
						arrow.ZIndex = btn.ZIndex + 1
						arrow.Parent = btn
						btn:GetPropertyChangedSignal("TextColor3"):Connect(function()
							arrow.TextColor3 = btn.TextColor3
						end)
						return btn
					end

					-- Camera type dropdown (2018 / 2013 / 2007), between the Camera and Physics buttons
					local cameraDropdown = makeDropdown("CameraDropdown", col(2))
					-- Physics type dropdown, between the two buttons it affects (Physics and Both)
					local dropdownBtn = makeDropdown("PhysicsDropdown", col(4))

					local function refreshVariantText()
						local label = variantLabel(selectedVariant)
						dropdownBtn.Text = label
						if physicsBtn then physicsBtn.Text = label .. " Physics" end
						local cam = cameraVariant(selectedCamera).label
						cameraDropdown.Text = cam
						if cameraBtn then cameraBtn.Text = cam .. " Camera" end
					end

					-- (the list items are made before the answer buttons, so Saved Settings finds an item first)
					lists.camera = {}
					for i, v in ipairs(CAMERA_VARIANTS) do
						local item = makeButton(v.label .. " Camera", UDim2.new(0, col(2), 0, 45 + 32 * i), W, frame)
						item.ZIndex = 10
						item.Visible = false
						table.insert(lists.camera, item)
						table.insert(myButtons, item)
						item.MouseButton1Click:Connect(function()
							playClick()
							selectedCamera = v.id
							refreshVariantText()
							closeLists()
						end)
					end

					lists.physics = {}
					for i, v in ipairs(PHYSICS_VARIANTS) do
						local item = makeButton(v.label .. " Physics", UDim2.new(0, col(4), 0, 45 + 32 * i), W, frame)
						item.ZIndex = 10
						item.Visible = false
						table.insert(lists.physics, item)
						table.insert(myButtons, item)

						item.MouseButton1Click:Connect(function()
							playClick()
							selectedVariant = v.id
							refreshVariantText()
							closeLists()
						end)
					end

					cameraDropdown.MouseButton1Click:Connect(function()
						playClick()
						setListOpen("camera", not lists.camera[1].Visible)
					end)
					dropdownBtn.MouseButton1Click:Connect(function()
						playClick()
						setListOpen("physics", not lists.physics[1].Visible)
					end)

					for _, opt in ipairs(opts) do
						local btn = makeButton(opt.text, UDim2.new(0, opt.x, 0, 45), opt.width, frame)
						table.insert(myButtons, btn)
						if opt.choice == "physics" then physicsBtn = btn end
						if opt.choice == "camera" then cameraBtn = btn end

						btn.MouseButton1Click:Connect(function()
							playClick()
							closeLists()
							local variant = selectedVariant
							local camera = selectedCamera
							print("[Physics/Camera] Picked " .. opt.choice .. " (physics: " .. variant .. ", camera: " .. camera .. ")")
							saveChoice(opt.choice, variant, camera)

							if opt.choice == "physics" or opt.choice == "both" then
								task.spawn(function() runPhysics(variant) end)
							end
							if opt.choice == "camera" or opt.choice == "both" then
								task.spawn(function()
									local src = fetchCameraScript(camera)
									if src then runScript((cameraVariant(camera).prefix or "") .. src, camera .. " camera") end
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

	-- Only restore the dropdowns' last physics and camera types; nothing runs until a button is clicked.
	if readfile and isfile and isfile(CONFIG_FILE) then
		pcall(function()
			local cfg = HttpService:JSONDecode(readfile(CONFIG_FILE))
			if type(cfg) == "table" and type(cfg.physicsVariant) == "string" then
				selectedVariant = cfg.physicsVariant
			end
			if type(cfg) == "table" and type(cfg.cameraVariant) == "string" then
				selectedCamera = cameraVariant(cfg.cameraVariant).id
			end
		end)
	end

	print("[Physics/Camera Step] Loaded.")
end)