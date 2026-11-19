-- [[ 2007 PHYSICS (Addtion-Scripts) ]]
-- The CharacterPhysics script as it was given (StarterPlayer.StarterCharacterScripts.CharacterPhysics, FWM's), made to
-- run from a script executor, on R6 and R15: FWM's (Flex's Wayback Machine's) 2008-2009 physics. It is the same script
-- the 2006 physics is made from; what makes it 2008-2009 is FWM's era number, TIME_PERIOD below (2009's). It runs as
-- it came, with nothing of ours added:
--   * jumping keeps the speed you had (the jump glide) and bounces you off walls you hit mid-jump; you can't turn in
--     the air
--   * the first landing after a jump or fall throws you back up (at three quarters of the speed you landed with, for
--     two frames), and after a landing you can't jump again for 0.65 s
--   * a hard landing (48 studs a second or faster) tilts you forward half the time (every time in 2006), more the
--     faster you were going
--   * the arms don't collide (they did in 2006), and a heavy tool makes you lean when you turn
-- Climbing is the 2013 climbing, the same as the Old physics' (Retro Studio's CustomClimbing; see CLIMBING below), in
-- place of the script's own "fly bug" climbing (walking into any small part climbed it, so on a map made of small parts
-- the climbing pose kept coming up): ladders, trusses and the like are climbed while the stick is held, up at 70% of
-- WalkSpeed; let go and you drop.
-- Changed to run here (each marked "(Addtion-Scripts)" below):
--   * an executor has no ReplicatedStorage.TimePeriod, Protocols or Modules.ExtraUtil, which the script waited for
--     forever: TimePeriod is TIME_PERIOD, the remote events (DiscWalking, Climbing, Drop) are the game's own when it
--     has them and do nothing otherwise, and ExtraUtil is the game's own when it has it, else the same few helpers
--     written out here
--   * R15: the upper torso stands in for the Torso and the hands for the arms; the body keeps its own hip height (an
--     R15 body stands on it; the script's 0 or 2 is for R6 legs)
--   * the character's TorsoAttach.AngularTilt (part of the game's own characters, which steadies you after a hard
--     landing) is used when it is there; an executor's character has none, so that step is skipped
--   * math.huge where the decompile says "inf"
--   * it runs on each new character, the game's own CharacterPhysics is switched off, and it stops (everything it
--     made removed) when run again or when the Old or 2006 physics is picked
-- Run alone or from the physics / camera step ("2007" physics).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BPGenv = (getgenv and getgenv()) or _G
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

-- (Addtion-Scripts) FWM's era number. What each value turns on in this script: below 1 no jumping; below 11.5 the arms
-- collide; up to 14 the jump glide, the landing bounce and tilt, and the old climbing (not used here: see CLIMBING);
-- 12 to 14 the tilt only half the time; above 14 a turning delay after landing; 17 and up the landing squash.
-- FWM doesn't publish what number each year has. The 2006 physics this repo started from has 10 for 2006, which makes
-- 2009 13: FWM's 2008-2009 physics (12, 13 and 14 all do the same: no colliding arms, the tilt half the time). Set
-- getgenv().FWMTimePeriod to a number before running this to use another (the game's own TimePeriod in FWM reads it:
-- print(game.ReplicatedStorage.TimePeriod.Value)).
local TIME_PERIOD = 13
do
	local genv = (getgenv and getgenv()) or _G
	if type(genv.FWMTimePeriod) == "number" then TIME_PERIOD = genv.FWMTimePeriod end
end

-- (Addtion-Scripts) one copy at a time, and one physics at a time
if BPGenv.__Physics2007Cleanup then pcall(BPGenv.__Physics2007Cleanup) end
if BPGenv.__Physics2006Cleanup then pcall(BPGenv.__Physics2006Cleanup) end
for _, env in ipairs({ _G, BPGenv }) do
	if env.__RetroMasterCleanup then pcall(env.__RetroMasterCleanup) end
end

-- (Addtion-Scripts) FWM's ExtraUtil when the game has it, else the helpers the script uses
local ExtraUtil
do
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local found = modules and modules:FindFirstChild("ExtraUtil")
	local ok, result = false, nil
	if found then ok, result = pcall(require, found) end
	if ok and type(result) == "table" then
		ExtraUtil = result
	else
		ExtraUtil = {
			v = Vector3,
			c = CFrame,
			Create = function(className, properties)
				local inst = Instance.new(className)
				local parent = nil
				for k, v in pairs(properties) do
					if k == "Parent" then parent = v else inst[k] = v end
				end
				if parent then inst.Parent = parent end
				return inst
			end,
			Average = function(...)
				local args = { ... }
				local sum = 0
				for _, v in ipairs(args) do sum = sum + v end
				return #args > 0 and (sum / #args) or 0
			end,
			Lerp = function(a, b, t)
				return a + (b - a) * t
			end,
		}
	end
end

-- (Addtion-Scripts) the game's remote events when it has them; otherwise ones that do nothing
local NO_REMOTE = { FireServer = function() end }
local PROTOCOLS = setmetatable({}, {
	__index = function(_, name)
		local protocols = ReplicatedStorage:FindFirstChild("Protocols")
		local remote = protocols and protocols:FindFirstChild(name)
		if remote then return remote end
		return NO_REMOTE
	end,
})

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

local stopCurrent = nil -- stops the copy running on the current character

local function CharacterPhysics(script, R15)
	-- (the script as given from here on; "(Addtion-Scripts)" marks each change)
	local v_u_1 = {}
	local v_u_2 = PROTOCOLS -- (Addtion-Scripts) was game.ReplicatedStorage:WaitForChild("Protocols")
	local v_u_3 = TIME_PERIOD -- (Addtion-Scripts) was game.ReplicatedStorage:WaitForChild("TimePeriod").Value
	game:GetService("TweenService")
	local v_u_4 = ExtraUtil -- (Addtion-Scripts) was require(game.ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ExtraUtil"))
	local v_u_5 = v_u_4.v
	local v_u_6 = v_u_4.c
	local v_u_7 = os.clock()
	local v_u_8 = v_u_5.new(1, 0, 1)
	v_u_5.new(0, 1, 0)
	local v_u_9 = script.Parent
	local v_u_10 = v_u_9:WaitForChild("Humanoid")
	-- (Addtion-Scripts) R15: the upper torso for the Torso, the hands for the arms
	if R15 == nil then R15 = v_u_10.RigType == Enum.HumanoidRigType.R15 end
	local v_u_11 = v_u_9:WaitForChild(R15 and "UpperTorso" or "Torso")
	local v_u_12 = v_u_9:WaitForChild(R15 and "RightHand" or "Right Arm")
	local v13 = v_u_9:WaitForChild(R15 and "LeftHand" or "Left Arm")
	local v_root = v_u_9:WaitForChild("HumanoidRootPart") -- (Addtion-Scripts) R15: where the feet are
	if not R15 then
		v_u_11:WaitForChild("Right Shoulder")
		v_u_11:WaitForChild("Left Shoulder")
	end
	-- (Addtion-Scripts) the 2013 climbing (see CLIMBING above); stopped with the rest (it is in v_u_1)
	local v_stopClimbing, v_climbing = startClimbing2013(v_u_9, v_u_10, v_root, R15)
	local _, _, _ = v13.CFrame:ToEulerAnglesXYZ()
	local _, _, _ = v_u_12.CFrame:ToEulerAnglesXYZ()
	local v_u_14 = 0
	-- (Addtion-Scripts) R15: the body's own hip height (followed if Roblox changes it, e.g. when the body is scaled)
	local v_u_15 = R15 and (v_u_10.HipHeight > 0 and v_u_10.HipHeight or 2) or 0
	local v_u_16 = 0
	local v_u_17 = v_u_4.Create("BodyVelocity", {
		["Name"] = "GlideVelocity",
		["MaxForce"] = v_u_8 * 9000000000
	})
	local v_u_18 = false
	local v_u_19 = false
	local v_u_20 = v_u_3 >= 1
	if v_u_3 < 1 then
		v_u_10.JumpPower = 0
	end
	local v_u_21 = 0
	local v_u_22 = tick()
	local v_u_23 = nil
	local _ = nil
	-- (Addtion-Scripts) the script's ClimbLift / ClimbGyro (its own climbing) are not made: the 2013 climbing climbs
	local v_u_26 = nil
	table.insert(v_u_1, { Disconnect = function() v_stopClimbing() end }) -- (Addtion-Scripts) the 2013 climbing
	-- (Addtion-Scripts) kept with the others, so it is disconnected when this stops
	table.insert(v_u_1, v_u_10:GetPropertyChangedSignal("SeatPart"):Connect(function()
		-- upvalues: (copy) v_u_10
		if v_u_10.SeatPart and v_u_10.SeatPart:IsA("VehicleSeat") then
			v_u_10.SeatPart.HeadsUpDisplay = false
		end
	end))
	-- (Addtion-Scripts) the script's stopClimbing, handleClimbing and isFlyBug (its own climbing) were here
	local function v37() -- name: moveDirectionChanged
		-- upvalues: (copy) v_u_10, (copy) v_u_2, (copy) v_u_11, (ref) v_u_23, (copy) v_u_30, (copy) v_u_24, (ref) v_u_26, (copy) v_u_25
		if v_u_10.MoveDirection.Magnitude < 1 then
			v_u_2.DiscWalking:FireServer(false)
		end
		-- (Addtion-Scripts) the script's climbing handler was here; the 2013 climbing climbs instead
	end
	local function v_u_38() -- name: checkIfTrippedState
		-- upvalues: (copy) v_u_10
		return v_u_10:GetState() == Enum.HumanoidStateType.Ragdoll and true or (v_u_10:GetState() == Enum.HumanoidStateType.FallingDown and true or (v_u_10:GetState() == Enum.HumanoidStateType.Jumping and true or (v_u_10.Sit and true or v_u_10:GetState() == Enum.HumanoidStateType.Swimming)))
	end
	local v_u_39 = v_u_4.Create("BodyVelocity", {
		["Name"] = "TiltStopVel",
		["MaxForce"] = Vector3.new(math.huge, 0, math.huge), -- (Addtion-Scripts) was inf
		["Velocity"] = Vector3.new(0, 0, 0)
	})
	local function v_u_41() -- name: Tilt
		-- upvalues: (ref) v_u_19, (copy) v_u_39, (copy) v_u_11, (copy) v_u_8, (ref) v_u_16, (copy) v_u_38, (copy) v_u_10
		if not v_u_19 then
			v_u_19 = true
			task.spawn(function()
				-- upvalues: (ref) v_u_39, (ref) v_u_11
				v_u_39.Parent = v_u_11
				task.wait()
				v_u_39.Parent = nil
			end)
			local v40 = v_u_11.AssemblyLinearVelocity * v_u_8
			local _, _, _ = v_u_11.CFrame:ToEulerAnglesXYZ()
			v_u_16 = v40.Magnitude / 16 * 9
			while v_u_16 >= 0.1 or v_u_38() do
				if v_u_10.Sit or not v_u_10.Parent then -- (Addtion-Scripts) or not v_u_10.Parent
					v_u_16 = 0
					break
				end
				v_u_16 = v_u_16 * (0.88 - task.wait(0))
			end
			v_u_19 = false
		end
	end
	local function v_u_44(p42) -- name: forceVelocity
		-- upvalues: (copy) v_u_4, (copy) v_u_11
		local v43 = v_u_4.Create("BodyVelocity", {
			["MaxForce"] = Vector3.new(0, 9000000000, 0),
			["Parent"] = v_u_11,
			["Velocity"] = Vector3.new(0, 1, 0) * p42
		})
		game["Run Service"].Heartbeat:Wait()
		game["Run Service"].Heartbeat:Wait()
		v43:Destroy()
	end
	local function v_u_45() -- name: delayJump
		-- upvalues: (ref) v_u_20, (copy) v_u_3, (copy) v_u_10, (ref) v_u_15
		task.wait()
		v_u_20 = false
		if v_u_3 >= 1 then
			task.wait(0.65)
			v_u_20 = true
			v_u_10.HipHeight = v_u_15
		end
	end
	local function v_u_46() -- name: handleJumping
		-- upvalues: (copy) v_u_10, (ref) v_u_15, (ref) v_u_14, (ref) v_u_22, (copy) v_u_3, (copy) v_u_11, (copy) v_u_8, (copy) v_u_17
		v_u_10.HipHeight = v_u_15
		v_u_14 = 0
		v_u_22 = tick()
		if v_u_3 <= 14 then
			v_u_17.Velocity = v_u_11.AssemblyLinearVelocity * v_u_8
			v_u_17.Parent = v_u_11
		end
	end
	local function v_u_47() end -- name: HipHeight
	local v48 = v_u_10.StateChanged
	local function v54(_, p49)
		-- upvalues: (ref) v_u_7, (copy) v_u_11, (ref) v_u_14, (copy) v_u_17, (copy) v_u_3, (copy) v_u_41, (copy) v_u_45, (copy) v_u_44, (ref) v_u_18, (ref) v_u_21, (copy) v_u_38, (copy) v_u_10, (copy) v_u_47, (copy) v_u_46, (ref) v_u_19
		if p49 == Enum.HumanoidStateType.Landed then
			v_u_7 = os.clock() + 0.25
			local v50 = v_u_11.AssemblyLinearVelocity.Y
			if v50 >= -250 then
				v_u_14 = v_u_14 + 1
			end
			v_u_17.Parent = nil
			if v_u_14 <= 1 then
				if v50 >= 0 then
					v_u_17.Parent = nil
					return
				end
				if math.ceil(v50) <= -48 then
					if v_u_3 >= 12 and v_u_3 <= 14 then
						if math.random(1, 2) == 2 then
							task.spawn(v_u_41)
						end
					elseif v_u_3 <= 14 then
						task.spawn(v_u_41)
					end
				end
				task.spawn(v_u_45)
				if v_u_3 <= 14 then
					task.wait()
					local v51 = v50 * 0.75
					v_u_44((math.abs(v51)))
					-- (Addtion-Scripts) only when the character has one (the game's own do; an executor's doesn't)
					local v_attach = v_u_11:FindFirstChild("TorsoAttach")
					local v_tilt = v_attach and v_attach:FindFirstChild("AngularTilt")
					if v_tilt and not v_tilt.Enabled then
						task.spawn(function()
							-- upvalues: (ref) v_u_11
							v_tilt.Enabled = true
							v_tilt.MaxTorque = 5000
							while v_tilt.MaxTorque > 10 and v_tilt.Parent do
								local v52 = task.wait()
								local v53 = v_tilt
								v53.MaxTorque = v53.MaxTorque * (0.75 + v52)
							end
							v_tilt.Enabled = false
						end)
					end
				end
				if v_u_3 >= 17 and not v_u_18 then
					v_u_18 = true
					v_u_21 = -0.7
					while v_u_21 < 0.05 and (not v_u_38() and v_u_10:GetState() ~= Enum.HumanoidStateType.Jumping) do
						v_u_21 = v_u_21 * (0.8 + task.wait(0))
					end
					v_u_18 = false
					v_u_21 = 0
					return
				end
			elseif v_u_14 == 2 and v_u_3 <= 14 then
				task.spawn(v_u_47)
				return
			end
		else
			if p49 == Enum.HumanoidStateType.Jumping then
				v_u_7 = os.time()
				v_u_18 = false
				task.spawn(v_u_46)
				return
			end
			if p49 == Enum.HumanoidStateType.Swimming then
				v_u_19 = false
				v_u_17.Parent = nil
			end
		end
	end
	table.insert(v_u_1, v48:Connect(v54))
	local v55 = game.UserInputService.JumpRequest
	table.insert(v_u_1, v55:Connect(function()
		-- upvalues: (copy) v_u_10, (copy) v_u_27, (ref) v_u_20, (copy) v_u_46
		if v_u_10:GetState() ~= Enum.HumanoidStateType.Jumping then
			-- (Addtion-Scripts) jumping off a ladder is left to Roblox's climbing, as on the Old physics
			if v_u_20 then
				task.spawn(v_u_46)
			end
		end
	end))
	local v_u_56 = 0
	local v_u_57 = 0
	local v_u_58 = 0
	local v_u_59 = 0
	tick()
	local v60 = game:GetService("RunService").RenderStepped
	local function v73(p61)
		-- upvalues: (copy) v_u_11, (copy) v_u_3, (copy) v_u_10, (ref) v_u_7, (copy) v_u_36, (copy) v_u_38, (copy) v_u_17, (copy) v_u_8, (copy) v_u_5, (ref) v_u_58, (copy) v_u_4, (ref) v_u_21, (ref) v_u_15, (copy) v_u_9, (ref) v_u_26, (ref) v_u_59, (ref) v_u_16, (copy) v_u_12, (ref) v_u_57, (ref) v_u_56, (ref) v_u_19, (copy) v_u_6, (ref) v_u_22, (ref) v_u_18
		if not v_u_11.Parent then return end -- (Addtion-Scripts) the character is gone
		v_u_11:GetConnectedParts()
		if v_u_3 > 14 then
			v_u_10.AutoRotate = v_u_7 < os.clock()
		end
		-- (Addtion-Scripts) the script's fly-bug climbing was here (walking into any small part climbed it); the 2013
		-- climbing climbs instead
		-- (Addtion-Scripts) R15: its own hip height is the base, followed if something else (Roblox scaling the body)
		-- changes it
		if R15 and math.abs(v_u_10.HipHeight - (v_u_58 + v_u_15)) > 0.001 then
			v_u_15 = v_u_10.HipHeight - v_u_58
		end
		v_u_58 = v_u_4.Lerp(v_u_58, v_u_21, 0.5)
		v_u_10.HipHeight = v_u_58 + v_u_15
		for _, v64 in pairs(v_u_9:GetChildren()) do
			if not v64:GetAttribute("FWMClimb") then
				continue
			end
			v_u_26 = v64
		end
		if v_u_26 then
			v_u_26.Value = v_climbing() or v_u_10:GetState() == Enum.HumanoidStateType.Climbing -- (Addtion-Scripts) the 2013 climbing
		end
		v_u_59 = v_u_4.Lerp(v_u_59, v_u_16, 0.3)
		local v65 = 0
		if v_u_9:FindFirstChildWhichIsA("Tool") then
			for _, v66 in pairs(v_u_9:FindFirstChildWhichIsA("Tool"):GetDescendants()) do
				if not (v66:IsA("Part") and table.find(v_u_12:GetConnectedParts(), v66)) then
					continue
				end
				v65 = v65 + v66:GetMass()
			end
		end
		v_u_57 = v_u_57 * (0.9 + p61)
		v_u_57 = v_u_57 + v_u_11.AssemblyAngularVelocity.Y / 2000 * v65
		v_u_56 = v_u_4.Lerp(v_u_56, v_u_57, 0.3)
		if not v_u_38() then
			if v_u_19 then
				if v_u_11.AssemblyAngularVelocity.Y < 0 then
					local v67 = v_u_11
					local v68 = v_u_59
					v67.CFrame = v67.CFrame * v_u_6.fromEulerAnglesXYZ(-math.rad(v68) - v_u_56 / 5, 0, v_u_56 / 2.5)
				else
					local v69 = v_u_11
					local v70 = v_u_59
					v69.CFrame = v69.CFrame * v_u_6.fromEulerAnglesXYZ(-math.rad(v70) - v_u_56 / 5, 0, v_u_56 / 5)
				end
			elseif v_u_11.AssemblyAngularVelocity.Y < 0 then
				local v71 = v_u_11
				v71.CFrame = v71.CFrame * v_u_6.fromEulerAnglesXYZ(-v_u_56 / 5, 0, v_u_56 / 2.5)
			else
				local v72 = v_u_11
				v72.CFrame = v72.CFrame * v_u_6.fromEulerAnglesXYZ(-v_u_56 / 5, 0, v_u_56 / 5)
			end
		end
		if tick() - v_u_22 > 0.05 and (v_u_17.Parent ~= nil and (v_u_10.FloorMaterial ~= Enum.Material.Air and (v_u_11.AssemblyLinearVelocity.Y < 1 and v_u_11.AssemblyLinearVelocity.Y > -1))) then
			v_u_17.Parent = nil
		end
		if sit then
			v_u_17.Parent = nil
		end
		if v_u_3 < 11.5 then
			if v_u_9:FindFirstChild("Left Arm") then
				v_u_9["Left Arm"].CanCollide = true
			end
			if v_u_9:FindFirstChild("Right Arm") then
				v_u_9["Right Arm"].CanCollide = true
			end
		end
		if R15 then
			-- (Addtion-Scripts) an R15 body stands on its own hip height (kept above)
		elseif v_u_9:FindFirstChild("Left Leg") or v_u_9:FindFirstChild("Right Leg") then
			v_u_15 = v_u_4.Lerp(v_u_15, 0, 1)
		else
			v_u_15 = v_u_4.Lerp(v_u_15, 2, 1)
		end
		if not v_u_18 then
			v_u_10.HipHeight = v_u_15
		end
	end
	table.insert(v_u_1, v60:Connect(v73))
	local v_u_74 = {}
	local v_u_75 = RaycastParams.new()
	v_u_75.FilterDescendantsInstances = { v_u_9, workspace.CurrentCamera }
	v_u_75.RespectCanCollide = true
	local v_u_76 = tick()
	local function v_u_95() -- name: CreateGlideCons
		-- upvalues: (copy) v_u_74, (copy) v_u_11, (ref) v_u_76, (copy) v_u_75, (copy) v_u_17, (copy) v_u_9
		for _, v_u_77 in pairs(v_u_9:GetChildren()) do
			if not v_u_77:IsA("BasePart") then
				continue
			end
			local v78 = v_u_74
			local v79 = v_u_77.Touched
			local function v94(p80)
				-- upvalues: (copy) v_u_77, (ref) v_u_11, (ref) v_u_76, (ref) v_u_75, (ref) v_u_17
				if p80:IsDescendantOf(v_u_77.Parent) then
					return
				elseif p80.CanCollide then
					local v81 = v_u_11.Position.Y - 2
					if p80.Position.Y >= v81 then
						if tick() - v_u_76 > 0.01 then
							v_u_76 = tick()
							local v82 = p80:GetClosestPointOnSurface(v_u_77.Position)
							local v83 = workspace
							local v84 = v_u_77
							local v85 = v82 - v_u_77.Position
							local v86 = v83:Shapecast(v84, v85.Magnitude <= 0 and Vector3.new(0, 0, 0) or v85.Unit, v_u_75)
							if v86 then
								if v86.Instance.CanCollide == false then
									return
								end
								if v81 < v86.Position.Y then
									local v87 = v_u_17.Velocity.Magnitude
									local v88 = v86.Normal * v87
									local v89 = v_u_17
									local v90 = v88.X
									local v91 = v_u_17.Velocity.Y
									local v92 = v88.Z
									v89.Velocity = Vector3.new(v90, v91, v92)
									return
								end
							elseif v81 < v_u_77.Position.Y then
								local v93 = v_u_17
								v93.Velocity = v93.Velocity * Vector3.new(-1, 1, -1)
								return
							end
						end
					end
				else
					return
				end
			end
			table.insert(v78, v79:Connect(v94))
		end
	end
	local v96 = v_u_17:GetPropertyChangedSignal("Parent")
	table.insert(v_u_1, v96:Connect(function()
		-- upvalues: (copy) v_u_10, (copy) v_u_17, (copy) v_u_95, (copy) v_u_74
		v_u_10.AutoRotate = v_u_17.Parent == nil
		if v_u_17.Parent == nil then
			for v97, v98 in pairs(v_u_74) do
				v98:Disconnect()
				v_u_74[v97] = nil
			end
		else
			v_u_95()
		end
	end))
	local v99 = v_u_10:GetPropertyChangedSignal("Jump")
	table.insert(v_u_1, v99:Connect(function()
		-- upvalues: (ref) v_u_20, (copy) v_u_10
		if not v_u_20 then
			v_u_10.Jump = false
		end
	end))
	local v100 = v_u_10:GetPropertyChangedSignal("MoveDirection")
	table.insert(v_u_1, v100:Connect(v37))
	local v101 = game.UserInputService.InputBegan
	table.insert(v_u_1, v101:Connect(function(p102, p103)
		-- upvalues: (copy) v_u_2
		if not p103 and (p102.KeyCode == Enum.KeyCode.Equals or p102.KeyCode == Enum.KeyCode.Plus) then
			v_u_2.Drop:FireServer()
		end
	end))
	v_u_10.Died:Once(function()
		-- upvalues: (copy) v_u_1
		for v104, v105 in pairs(v_u_1) do
			v105:Disconnect()
			v_u_1[v104] = nil
		end
	end)

	-- (Addtion-Scripts) stops this copy: everything it connected or made goes, and the character is left as Roblox
	-- has it (turning on, climbing on, R6 hip height 0)
	return function()
		for v104, v105 in pairs(v_u_1) do
			pcall(function() v105:Disconnect() end)
			v_u_1[v104] = nil
		end
		for v97, v98 in pairs(v_u_74) do
			pcall(function() v98:Disconnect() end)
			v_u_74[v97] = nil
		end
		for _, v_mover in ipairs({ v_u_17, v_u_39 }) do
			pcall(function() v_mover:Destroy() end)
		end
		if v_u_10.Parent then
			pcall(function()
				v_u_10.AutoRotate = true
				if not R15 then v_u_10.HipHeight = 0 end
			end)
		end
	end
end

-- (Addtion-Scripts) run on each character, as a StarterCharacterScripts script is
local function onCharacter(character)
	if stopCurrent then pcall(stopCurrent) stopCurrent = nil end
	if not character then return end
	-- the game's own CharacterPhysics (FWM's) switched off, also when it comes in after this started
	local function disableOwn(child)
		if child.Name == "CharacterPhysics" and child:IsA("LocalScript") then
			child.Disabled = true
		end
	end
	for _, child in ipairs(character:GetChildren()) do disableOwn(child) end
	local ownConn = character.ChildAdded:Connect(disableOwn)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not character.Parent then ownConn:Disconnect() return end
	local ok, stop = pcall(CharacterPhysics, { Parent = character }, humanoid.RigType == Enum.HumanoidRigType.R15)
	if not ok then
		ownConn:Disconnect()
		warn("[2007 Physics] could not start: " .. tostring(stop))
		return
	end
	stopCurrent = function()
		ownConn:Disconnect()
		if type(stop) == "function" then stop() end
	end
end

if LocalPlayer.Character then task.spawn(onCharacter, LocalPlayer.Character) end
local characterAddedConnection = LocalPlayer.CharacterAdded:Connect(onCharacter)

BPGenv.__Physics2007Cleanup = function()
	characterAddedConnection:Disconnect()
	if stopCurrent then pcall(stopCurrent) stopCurrent = nil end
	BPGenv.__Physics2007Cleanup = nil
end
print("[2007 Physics] on: FWM's CharacterPhysics, its 2008-2009 physics (time period " .. tostring(TIME_PERIOD) .. ").")
