-- [[ PHYSICS + CAMERA WIZARD STEP — with None option ]]
-- (Addtion-Scripts copy: the "Old" physics climbs like the 2006 physics: walk into a small part and the
--  character climbs it in the real Climbing state, and lets go when you stop moving or jump.)

task.spawn(function()
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")
	local SoundService = game:GetService("SoundService")

	local CONFIG_FILE = "BloxyParadoxConfig.json"
	local CAMERA_URL = "https://gist.githubusercontent.com/eloredo413-hue/81660979f9506a61e0344f32a8096f96/raw/05a2619b3a2737d7c4a97814650f8980e103c5ef/Retro%2520camera"
	local PHYSICS_2006_URL = "https://gist.githubusercontent.com/eloredo413-hue/03ef8e46682bfb53e26e6847abfde344/raw/0fb71153c3b4a369a0390228a2bec3a4a5655c56/2006%2520Physics"

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
local CLIMB_UP_SPEED = 13       -- upward kick each frame while climbing
local CLIMB_PUSH_SPEED = 24     -- push into the part
local TOP_OUT_TIME = 0.4        -- seconds after the last grab in which you are still topping out
local TOP_OUT_MIN_RISE = 1.5    -- studs climbed before the top-out hop counts
local TOP_OUT_SPEED = 14        -- hop forward over the top
local TOP_OUT_UP = 9            -- ...and a little up
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
		end
		lastFallSpeed = 0
	end))

	addConnection(humanoid.StateChanged:Connect(function(oldState, newState)
		if oldState == Enum.HumanoidStateType.Freefall and newState == Enum.HumanoidStateType.Landed then
			pcall(function()
				humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
			end)
			task.delay(0.5, function()
				if not destroyed and humanoid.Parent and humanoid.Health > 0 then
					pcall(function()
						humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
					end)
				end
			end)
		end
	end))

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

	local rayDown = Vector3.new(0, -5000, 0)
	local stepRate = 20 / 3
	local decayRate = 0.925

	local function moveTowards(value, goal, rate)
		if value < goal then return math.min(goal, value + rate)
		elseif value > goal then return math.max(goal, value - rate)
		else return goal end
	end

	local function getFloorLevel()
		local origin = rootPart.Position
		local ray = Ray.new(origin, rayDown)
		local _, position = Workspace:FindPartOnRay(ray, char)
		if not position then return origin.Y, 0 end
		return position.Y, math.clamp(math.abs(position.Y - origin.Y), -1, 1)
	end

	-- true while the 2006 climbing below is at work (set there, read here a frame later)
	local climbActive = false

	local lastLevel = getFloorLevel()
	local hipRenderName = "RetroHipHeight_" .. tostring(math.random(10000, 99999))
	table.insert(RenderNames, hipRenderName)

	RunService:BindToRenderStep(hipRenderName, 390, function(dt)
		if destroyed or not char.Parent or humanoid.Health <= 0 then
			pcall(function() RunService:UnbindFromRenderStep(hipRenderName) end)
			return
		end
		dt = math.min(0.1, dt)
		if humanoid.SeatPart then
			humanoid.HipHeight = 0
			lastLevel = getFloorLevel()
			return
		end
		-- The 2006 physics keeps the hip height at 0 while climbing; floating up with the climb
		-- kick would lift the feet-level search above the part being climbed.
		if climbActive then
			humanoid.HipHeight = 0
			lastLevel = getFloorLevel()
			return
		end
		local level, dist = getFloorLevel()
		local yVelocity = rootPart.AssemblyLinearVelocity.Y
		if math.abs(yVelocity) > 8 then
			humanoid.HipHeight = moveTowards(humanoid.HipHeight, math.sign(yVelocity), stepRate * dt)
		elseif lastLevel ~= level then
			humanoid.HipHeight = math.sign(lastLevel - level) * math.clamp(dist - 3, 0, 1)
			lastLevel = level
		else
			humanoid.HipHeight = humanoid.HipHeight * (decayRate ^ (dt * 60))
		end
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
	-- the real Climbing state: kicked upwards, pushed into the part and turned to face it. Let go
	-- (stop moving, or jump) and it drops. Big parts (floors, walls) are not climbed; a TrussPart
	-- is climbed by the Climbing state itself.
	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = { char, Workspace.CurrentCamera }
	overlapParams.RespectCanCollide = true

	local function climbablePartAhead()
		local checkPos = torso.Position - Vector3.new(0, 1, 0)
		local boxCFrame = CFrame.new(checkPos + torso.CFrame.LookVector / 2) * CFrame.new(0, -0.5, 0)
		local parts = Workspace:GetPartBoundsInBox(boxCFrame, CLIMB_BOX, overlapParams)
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

		-- Start (and keep) climbing while walking into a small part. The kick goes on every frame
		-- you walk into it, exactly as in the 2006 physics (while the Climbing state is switched
		-- off after letting go, the state change does nothing but the kick still lifts you).
		local velocity = torso.AssemblyLinearVelocity
		-- (not while letting go, and not in a real fall: dropping past a wall must not grab it)
		local walkingIntoPart = moving and not releasing and velocity.Y > -MAX_FALL_TO_GRAB
			and not cantClimbNow() and climbablePartAhead()
		if walkingIntoPart then
			humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
			-- the kick sets the upward speed instead of adding to it every frame, so it can't build up
			-- into being flung upwards
			torso.AssemblyLinearVelocity = Vector3.new(velocity.X * CLIMB_SIDE_DAMP,
				math.max(velocity.Y, CLIMB_UP_SPEED), velocity.Z * CLIMB_SIDE_DAMP)
		end

		-- Topping out: the part under your feet ran out (the top of a ladder or a ledge) while you are
		-- still walking into it: hop forward over the top, so you end up standing on it instead of
		-- sliding back down.
		local now = os.clock()
		if walkingIntoPart then
			if not grabStartY then grabStartY = torso.Position.Y end
			lastGrab = now
		elseif grabStartY then
			local sinceGrab = now - lastGrab
			if sinceGrab > TOP_OUT_TIME or humanoid:GetState() == Enum.HumanoidStateType.Running then
				grabStartY = nil
			elseif moving and not releasing and torso.Position.Y - grabStartY >= TOP_OUT_MIN_RISE then
				local v = torso.AssemblyLinearVelocity
				torso.AssemblyLinearVelocity = Vector3.new(moveDir.X * TOP_OUT_SPEED,
					math.max(v.Y, TOP_OUT_UP), moveDir.Z * TOP_OUT_SPEED)
			end
		end

		climbWanted = walkingIntoPart or humanoid:GetState() == Enum.HumanoidStateType.Climbing
		-- (2007 Animation.lua reads this to show its climbing pose, not its falling one)
		BPGenv.BPClimbing = climbWanted or nil
		climbActive = walkingIntoPart or releasing
			or humanoid:GetState() == Enum.HumanoidStateType.Climbing

		if humanoid:GetState() == Enum.HumanoidStateType.Climbing then
			if moveDir.Magnitude < 0.1 then
				stopClimbing()
			else
				climbLift.Parent = torso
				climbGyro.Parent = torso
				local pos = torso.Position
				climbGyro.CFrame = CFrame.lookAt(pos, pos + moveDir)
				climbLift.Velocity = moveDir * CLIMB_PUSH_SPEED
			end
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
		if climbWanted and not releasing and humanoid:GetState() ~= Enum.HumanoidStateType.Climbing
			and not cantClimbNow() then
			humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
		end
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
		local ok, src = pcall(function()
			return game:HttpGet(CAMERA_URL, true)
		end)
		if ok and type(src) == "string" and #src > 100 then
			CAMERA_SRC = src
			print("[Physics/Camera] Camera script fetched (" .. #src .. " bytes).")
			return src
		end
		warn("[Physics/Camera] Failed to fetch camera script.")
		return nil
	end

	local PHYSICS_2006_SRC = nil

	local function fetchPhysics2006Script()
		if PHYSICS_2006_SRC then return PHYSICS_2006_SRC end
		print("[Physics/Camera] Fetching 2006 physics script...")
		local ok, src = pcall(function()
			return game:HttpGet(PHYSICS_2006_URL, true)
		end)
		if ok and type(src) == "string" and #src > 100 then
			PHYSICS_2006_SRC = src
			print("[Physics/Camera] 2006 physics script fetched (" .. #src .. " bytes).")
			return src
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