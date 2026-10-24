-- [[ PHYSICS + CAMERA WIZARD STEP — with None option ]]

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
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

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
	disconnectAll()
	unbindAll()
	cleanupCharacterObjects()
end

_G.__RetroMasterCleanup = cleanup

local FALLBACK_CLIMB_ANIMATION = "rbxassetid://165167632"
local CLIMB_SPEED_MULTIPLIER = 0.7
local SEARCH_DEPTH = 0.7
local MAX_CLIMB_DISTANCE = 2.45
local SAMPLE_SPACING = 1 / 7
local LOW_LADDER_SEARCH = 2.7
local LADDER_SEARCH_DISTANCE = 2.0

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

	local oldForce = rootPart:FindFirstChild("ClimbForce")
	if oldForce then pcall(function() oldForce:Destroy() end) end

	local climbing = Instance.new("BoolValue")
	climbing.Name = "Climbing"
	climbing.Value = false
	climbing.Parent = char
	table.insert(CharacterObjects, climbing)

	local bv = Instance.new("BodyVelocity")
	bv.Name = "ClimbForce"
	bv.MaxForce = Vector3.zero
	bv.Velocity = Vector3.zero
	bv.Parent = rootPart
	table.insert(CharacterObjects, bv)

	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	end)

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Name = "RetroClimbingAnimator"
		animator.Parent = humanoid
	end

	local fallbackAnimation = Instance.new("Animation")
	fallbackAnimation.Name = "RetroFallbackClimb"
	fallbackAnimation.AnimationId = FALLBACK_CLIMB_ANIMATION
	table.insert(CharacterObjects, fallbackAnimation)

	local fallbackTrack
	pcall(function()
		fallbackTrack = animator:LoadAnimation(fallbackAnimation)
		fallbackTrack.Priority = Enum.AnimationPriority.Action
		fallbackTrack.Looped = true
	end)

	local function getAnimationId(track)
		if not track then return "" end
		local a = track.Animation
		if not a then return "" end
		local id = a.AnimationId
		if not id then return "" end
		return tostring(id):lower()
	end

	local function isFallback(track)
		if not track then return false end
		return getAnimationId(track) == FALLBACK_CLIMB_ANIMATION:lower()
	end

	local function findCustomClimbAnimation()
		local tracks
		pcall(function() tracks = animator:GetPlayingAnimationTracks() end)
		if not tracks then return nil end
		for _, track in ipairs(tracks) do
			if track and track.IsPlaying and track ~= fallbackTrack and not isFallback(track) then
				return track
			end
		end
		return nil
	end

	local fallbackStartedByUs = false
	local function stopFallback()
		if fallbackTrack and fallbackTrack.IsPlaying then
			pcall(function() fallbackTrack:Stop(0.1) end)
		end
		fallbackStartedByUs = false
	end
	local function startFallback()
		if not fallbackTrack then return end
		if not fallbackTrack.IsPlaying then
			pcall(function() fallbackTrack:Play(0.1) end)
			fallbackStartedByUs = true
		end
	end

	local function updateClimbAnimation()
		if destroyed or not char.Parent or humanoid.Health <= 0 then return end
		if not climbing.Value then
			if fallbackStartedByUs then stopFallback() end
			return
		end
		task.defer(function()
			if destroyed or not char.Parent or humanoid.Health <= 0 or not climbing.Value then return end
			local customTrack = findCustomClimbAnimation()
			if customTrack then
				stopFallback()
				return
			end
			startFallback()
		end)
	end

	addConnection(climbing.Changed:Connect(updateClimbAnimation))

	local animationRenderName = "RetroClimbAnimationDetector_" .. tostring(math.random(10000, 99999))
	table.insert(RenderNames, animationRenderName)
	RunService:BindToRenderStep(animationRenderName, 410, function()
		if destroyed or not char.Parent or humanoid.Health <= 0 then
			pcall(function() RunService:UnbindFromRenderStep(animationRenderName) end)
			return
		end
		if not climbing.Value then return end
		local customTrack = findCustomClimbAnimation()
		if customTrack then
			if fallbackTrack and fallbackTrack.IsPlaying then stopFallback() end
		else
			if fallbackTrack and not fallbackTrack.IsPlaying then startFallback() end
		end
	end)

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

	task.spawn(function()
		local stepForwardFrames = 0

		local function findLadder()
			if destroyed or not char.Parent then return false end
			local cf = rootPart.CFrame
			local top = -humanoid.HipHeight
			local bottom = -LOW_LADDER_SEARCH + top
			local radius = 0.5 * LADDER_SEARCH_DISTANCE
			local center = cf.Position + (cf.LookVector * LADDER_SEARCH_DISTANCE * 0.5)
			local region = Region3.new(
				center + Vector3.new(-radius, bottom, -radius),
				center + Vector3.new(radius, top, radius)
			)
			local parts
			pcall(function()
				parts = Workspace:FindPartsInRegion3(region, char, math.huge)
			end)
			if not parts or #parts == 0 then return false end

			local torsoCoord = rootPart.CFrame
			local firstSpace = 0
			local firstStep = 0
			local lookForSpace = true
			local lookForStep = false
			local topRay = math.floor(LOW_LADDER_SEARCH / SAMPLE_SPACING)

			for i = 1, topRay do
				local distFromBottom = i * SAMPLE_SPACING
				local origin = torsoCoord.Position + Vector3.new(0, -LOW_LADDER_SEARCH + distFromBottom, 0)
				local ray = Ray.new(origin, torsoCoord.LookVector * LADDER_SEARCH_DISTANCE)
				local hitPrim, hitPos = Workspace:FindPartOnRay(ray, char)
				if hitPrim then
					if hitPrim:IsA("TrussPart") or hitPrim.Name == "Ladder" or hitPrim.Name == "Climbable" then
						return true
					end
				end
				local magnitude = LADDER_SEARCH_DISTANCE
				if hitPrim and hitPos then
					magnitude = (hitPos - ray.Origin).Magnitude
				end
				if magnitude < SEARCH_DEPTH then
					if lookForSpace then
						firstSpace = distFromBottom
						lookForSpace = false
						lookForStep = true
					end
				elseif lookForStep then
					firstStep = distFromBottom - firstSpace
					lookForStep = false
				end
			end

			return (firstSpace < MAX_CLIMB_DISTANCE and firstStep > 0 and firstStep < MAX_CLIMB_DISTANCE)
		end

		while not destroyed and char.Parent and humanoid.Health > 0 do
			task.wait()
			if destroyed then break end
			local canClimb = false
			local state = humanoid:GetState()
			if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Running then
				canClimb = findLadder()
			end
			if canClimb then
				local climbSpeed = humanoid.WalkSpeed * CLIMB_SPEED_MULTIPLIER
				bv.Velocity = Vector3.new(0, climbSpeed, 0)
				bv.MaxForce = Vector3.new(climbSpeed * 100, 10e6, climbSpeed * 100)
			else
				if climbing.Value then stepForwardFrames = 2 end
				bv.MaxForce = Vector3.zero
				bv.Velocity = Vector3.zero
			end
			if stepForwardFrames > 0 then
				pcall(function() humanoid:Move(rootPart.CFrame.LookVector) end)
				stepForwardFrames -= 1
			end
			if climbing.Value ~= canClimb then climbing.Value = canClimb end
		end
	end)

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
		if fallbackTrack then pcall(function() fallbackTrack:Stop(0) end) end
		pcall(function()
			bv.MaxForce = Vector3.zero
			bv.Velocity = Vector3.zero
		end)
	end))

	print("[Retro Master] Character system loaded.")
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

				-- The prompt's label and buttons sit right inside it. Reading
				-- every descendant walked the whole hammer panel every frame.
				for _, d in ipairs(frame:GetChildren()) do
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