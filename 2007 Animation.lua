-- [[ 2007 ANIMATION — adds "2007" to Bloxy's "Choose your animations" step (R6) ]]
-- The old avatar's animation (from Hammer stuff 2) as a wizard choice: the old Animate script's
-- procedural R6 motion. Arms out when standing, arms and legs swinging when running, arms up when
-- jumping or falling, legs forward when seated, arms up the ladder when climbing, tool slash and
-- lunge. It works on every player's R6 character; the game's own Animate is switched off.
--
-- It never changes Bloxy's own choices: "2007" is a fifth button next to 2008 / 2006 / 2014 /
-- Normal, and picking it moves the wizard on exactly as "Normal" does (so no Bloxy animation script
-- runs) while this script starts the 2007 animation. Picking any of Bloxy's own four turns it off.
--
-- Your pick is saved (BloxyAnimation2007Choice.json), so when Bloxy's "skip setup" box is ticked
-- the 2007 animation starts by itself, just like Bloxy's own saved choices. When you re-configure with
-- "skip" ticked it is only saved, not started (the same as Bloxy's own choices).
--
-- Works when executed before OR after Bloxy, on its own or loaded by the addition script.
-- Also usable by hand: getgenv().Animation2007.Start() / .Stop() / .IsRunning()

do
	local Players = game:GetService("Players")
	local HttpService = game:GetService("HttpService")
	local RunService = game:GetService("RunService")
	local CoreGui = game:GetService("CoreGui")

	local Env = (getgenv and getgenv()) or _G

	-- Running it again (or loading it twice) replaces the old copy
	if Env.Animation2007Cleanup then
		pcall(Env.Animation2007Cleanup)
	end

	local SAVE_FILE = "BloxyAnimation2007Choice.json"
	local BLOXY_CONFIG = "BloxyParadoxConfig.json"
	local BLOXY_GUI = "BloxyParadoxProject"
	-- Bloxy's step the button goes on (matched without caring about capitals). R15 has no 2007.
	local STEP_TEXT = "choose your animations: r6"
	local BUTTON_NAME = "Animation2007Button"

	local connections = {}
	local watched = {}                                 -- Bloxy GUIs being watched
	local handled = setmetatable({}, { __mode = "k" }) -- step frames already given the button
	local alive = true

	local function connect(signal, fn)
		local c = signal:Connect(fn)
		table.insert(connections, c)
		return c
	end

	local function disconnectAll(list)
		for _, c in ipairs(list) do
			pcall(function() c:Disconnect() end)
		end
		table.clear(list)
	end

	------------------------------------------------------------
	-- THE 2007 ANIMATION (the old avatar's, from Hammer stuff 2)
	------------------------------------------------------------
	local engine = {}
	do
		local player = Players.LocalPlayer
		while not player do
			task.wait()
			player = Players.LocalPlayer
		end

		local running = false
		local cleanup = {}     -- the engine's own connections
		local localConns = {}  -- [character] = connections of the local player's loop
		local localJoints = {} -- [character] = the local character's four joints
		local tracked = {}     -- other players' characters: [character] = entry

		local function runLocalCharacter(char)
			local humanoid = char:WaitForChild("Humanoid", 10)
			local torso = char:WaitForChild("Torso", 10)
			if not humanoid or not torso then return end

			local defaultAnimate = char:FindFirstChild("Animate")
			if defaultAnimate then defaultAnimate.Disabled = true end

			for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
				track:Stop()
			end

			local RightShoulder = torso:WaitForChild("Right Shoulder", 10)
			local LeftShoulder = torso:WaitForChild("Left Shoulder", 10)
			local RightHip = torso:WaitForChild("Right Hip", 10)
			local LeftHip = torso:WaitForChild("Left Hip", 10)
			if not (RightShoulder and LeftShoulder and RightHip and LeftHip) then return end

			-- Stopped (or respawned) while we were waiting for the character.
			if not running or not char.Parent or localConns[char] then return end

			local pose = "Standing"
			local toolAnim = "None"
			local toolAnimTime = 0
			local jumpMaxLimbVelocity = 0.75

			local function moveJump()
				RightShoulder.MaxVelocity = jumpMaxLimbVelocity
				LeftShoulder.MaxVelocity = jumpMaxLimbVelocity
				RightShoulder:SetDesiredAngle(3.14)
				LeftShoulder:SetDesiredAngle(-3.14)
				RightHip:SetDesiredAngle(0)
				LeftHip:SetDesiredAngle(0)
			end

			local function moveFreeFall()
				RightShoulder.MaxVelocity = jumpMaxLimbVelocity
				LeftShoulder.MaxVelocity = jumpMaxLimbVelocity
				RightShoulder:SetDesiredAngle(3.14)
				LeftShoulder:SetDesiredAngle(-3.14)
				RightHip:SetDesiredAngle(0)
				LeftHip:SetDesiredAngle(0)
			end

			local function moveSit()
				RightShoulder.MaxVelocity = 0.15
				LeftShoulder.MaxVelocity = 0.15
				RightShoulder:SetDesiredAngle(1.57)
				LeftShoulder:SetDesiredAngle(-1.57)
				RightHip:SetDesiredAngle(1.57)
				LeftHip:SetDesiredAngle(-1.57)
			end

			local function getTool()
				for _, kid in ipairs(char:GetChildren()) do
					if kid:IsA("Tool") then return kid end
				end
				return nil
			end

			local function getToolAnim(tool)
				for _, c in ipairs(tool:GetChildren()) do
					if c.Name == "toolanim" and c:IsA("StringValue") then return c end
				end
				return nil
			end

			local function animateTool()
				if (toolAnim == "None") then RightShoulder:SetDesiredAngle(1.57) return end
				if (toolAnim == "Slash") then RightShoulder.MaxVelocity = 0.5; RightShoulder:SetDesiredAngle(0) return end
				if (toolAnim == "Lunge") then
					RightShoulder.MaxVelocity = 0.5; LeftShoulder.MaxVelocity = 0.5; RightHip.MaxVelocity = 0.5; LeftHip.MaxVelocity = 0.5
					RightShoulder:SetDesiredAngle(1.57); LeftShoulder:SetDesiredAngle(1.0); RightHip:SetDesiredAngle(1.57); LeftHip:SetDesiredAngle(1.0)
					return
				end
			end

			local function move(time)
				if (pose == "Jumping") then moveJump() return end
				if (pose == "FreeFall") then moveFreeFall() return end
				if (pose == "Seated") then moveSit() return end

				local amplitude = 0.1
				local frequency = 1
				local climbFudge = 0

				if (pose == "Running") then
					if (RightShoulder.CurrentAngle > 1.5 or RightShoulder.CurrentAngle < -1.5) then
						RightShoulder.MaxVelocity = jumpMaxLimbVelocity
					else
						RightShoulder.MaxVelocity = 0.15
					end
					if (LeftShoulder.CurrentAngle > 1.5 or LeftShoulder.CurrentAngle < -1.5) then
						LeftShoulder.MaxVelocity = jumpMaxLimbVelocity
					else
						LeftShoulder.MaxVelocity = 0.15
					end
					amplitude = 1
					frequency = 9
				elseif (pose == "Climbing") then
					RightShoulder.MaxVelocity = 0.5; LeftShoulder.MaxVelocity = 0.5
					amplitude = 1; frequency = 9; climbFudge = 3.14
				end

				local desiredAngle = amplitude * math.sin(time * frequency)
				RightShoulder:SetDesiredAngle(desiredAngle + climbFudge)
				LeftShoulder:SetDesiredAngle(desiredAngle - climbFudge)
				RightHip:SetDesiredAngle(-desiredAngle)
				LeftHip:SetDesiredAngle(-desiredAngle)

				local tool = getTool()
				if tool then
					local animObj = getToolAnim(tool)
					if animObj then
						toolAnim = animObj.Value
						animObj:Destroy()
						toolAnimTime = time + .3
					end
					if time > toolAnimTime then toolAnimTime = 0; toolAnim = "None" end
					animateTool()
				else
					toolAnim = "None"
					toolAnimTime = 0
				end
			end

			local conns = {}
			localConns[char] = conns
			localJoints[char] = { RightShoulder, LeftShoulder, RightHip, LeftHip }

			table.insert(conns, humanoid.Running:Connect(function(speed) pose = (speed > 0) and "Running" or "Standing" end))
			table.insert(conns, humanoid.Died:Connect(function() pose = "Dead" end))
			table.insert(conns, humanoid.Jumping:Connect(function() pose = "Jumping" end))
			table.insert(conns, humanoid.Climbing:Connect(function() pose = "Climbing" end))
			table.insert(conns, humanoid.GettingUp:Connect(function() pose = "GettingUp" end))
			table.insert(conns, humanoid.FreeFalling:Connect(function() pose = "FreeFall" end))
			table.insert(conns, humanoid.FallingDown:Connect(function() pose = "FallingDown" end))
			table.insert(conns, humanoid.Seated:Connect(function() pose = "Seated" end))
			table.insert(conns, humanoid.PlatformStanding:Connect(function() pose = "PlatformStanding" end))
			table.insert(conns, humanoid.Swimming:Connect(function(speed) pose = (speed > 0) and "Running" or "Standing" end))

			table.insert(conns, RunService.RenderStepped:Connect(function()
				if char and char.Parent and humanoid.Health > 0 then
					move(os.clock())
				end
			end))

			table.insert(conns, char.AncestryChanged:Connect(function(_, p)
				if not p then
					disconnectAll(conns)
					if localConns[char] == conns then localConns[char] = nil end
					localJoints[char] = nil
				end
			end))
		end

		local function setupOther(char)
			if not char then return end
			local hum = char:WaitForChild("Humanoid", 10)
			local torso = char:WaitForChild("Torso", 10)
			if not hum or not torso then return end

			local anim = char:FindFirstChild("Animate")
			if anim then anim.Disabled = true end

			for _, t in ipairs(hum:GetPlayingAnimationTracks()) do t:Stop(0) end

			local rS = torso:WaitForChild("Right Shoulder", 10)
			local lS = torso:WaitForChild("Left Shoulder", 10)
			local rH = torso:WaitForChild("Right Hip", 10)
			local lH = torso:WaitForChild("Left Hip", 10)
			if not (rS and lS and rH and lH) then return end

			-- Stopped (or respawned) while we were waiting for the character.
			if not running or not char.Parent or tracked[char] then return end

			local entry = {
				char = char, hum = hum,
				rS = rS, lS = lS, rH = rH, lH = lH,
				pose = "Standing", conns = {}
			}

			table.insert(entry.conns, hum.AnimationPlayed:Connect(function(t) t:Stop(0) end))
			table.insert(entry.conns, hum.Running:Connect(function(s) entry.pose = (s > 0) and "Running" or "Standing" end))
			table.insert(entry.conns, hum.Jumping:Connect(function() entry.pose = "Jumping" end))
			table.insert(entry.conns, hum.FreeFalling:Connect(function() entry.pose = "FreeFall" end))
			table.insert(entry.conns, hum.Seated:Connect(function() entry.pose = "Seated" end))
			table.insert(entry.conns, hum.Climbing:Connect(function() entry.pose = "Climbing" end))

			table.insert(entry.conns, char.AncestryChanged:Connect(function(_, p)
				if not p then
					disconnectAll(entry.conns)
					tracked[char] = nil
				end
			end))

			tracked[char] = entry
		end

		-- Other players' characters, all driven from one RenderStepped.
		local function othersStep()
			local t = os.clock()
			for char, data in pairs(tracked) do
				if char.Parent and data.hum and data.hum.Health > 0 then
					local pose = data.pose
					local rS, lS, rH, lH = data.rS, data.lS, data.rH, data.lH

					if pose == "Jumping" or pose == "FreeFall" then
						rS.MaxVelocity = 0.75; lS.MaxVelocity = 0.75
						rS:SetDesiredAngle(3.14); lS:SetDesiredAngle(-3.14); rH:SetDesiredAngle(0); lH:SetDesiredAngle(0)
					elseif pose == "Seated" then
						rS.MaxVelocity = 0.15; lS.MaxVelocity = 0.15
						rS:SetDesiredAngle(1.57); lS:SetDesiredAngle(-1.57); rH:SetDesiredAngle(1.57); lH:SetDesiredAngle(-1.57)
					else
						local amp, freq, climb = 0.1, 1, 0
						if pose == "Running" then
							rS.MaxVelocity = 0.15; lS.MaxVelocity = 0.15; amp = 1; freq = 9
						elseif pose == "Climbing" then
							rS.MaxVelocity = 0.5; lS.MaxVelocity = 0.5; amp = 1; freq = 9; climb = 3.14
						end
						local ang = amp * math.sin(t * freq)
						rS:SetDesiredAngle(ang + climb)
						lS:SetDesiredAngle(ang - climb)
						rH:SetDesiredAngle(-ang)
						lH:SetDesiredAngle(-ang)
					end
				else
					disconnectAll(data.conns)
					tracked[char] = nil
				end
			end
		end

		local function handlePlayer(plr)
			if not plr then return end

			local function onCharacter(character)
				task.spawn(function()
					if not running then return end
					if plr == player then
						runLocalCharacter(character)
					else
						setupOther(character)
					end
				end)
			end

			if plr.Character then task.spawn(onCharacter, plr.Character) end
			table.insert(cleanup, plr.CharacterAdded:Connect(onCharacter))
		end

		function engine.IsRunning()
			return running
		end

		function engine.Start()
			if running then return end
			running = true
			-- Tells Old physics camera addon not to play its climb animation over this one.
			Env.BPProceduralAnimation = true

			table.insert(cleanup, RunService.RenderStepped:Connect(othersStep))
			for _, plr in ipairs(Players:GetPlayers()) do
				pcall(handlePlayer, plr)
			end
			table.insert(cleanup, Players.PlayerAdded:Connect(function(plr) pcall(handlePlayer, plr) end))
			print("[2007 Animation] On: the old avatar's animation for all R6 players.")
		end

		function engine.Stop()
			if not running then return end
			running = false
			Env.BPProceduralAnimation = nil

			-- Let the joints settle back to straight instead of staying in the last pose.
			local joints = {}
			for _, list in pairs(localJoints) do table.insert(joints, list) end
			for _, data in pairs(tracked) do table.insert(joints, { data.rS, data.lS, data.rH, data.lH }) end
			for _, list in ipairs(joints) do
				for _, joint in ipairs(list) do
					pcall(function()
						joint.MaxVelocity = 0.5
						joint:SetDesiredAngle(0)
					end)
				end
			end

			disconnectAll(cleanup)
			for _, conns in pairs(localConns) do disconnectAll(conns) end
			table.clear(localConns)
			table.clear(localJoints)
			for _, data in pairs(tracked) do disconnectAll(data.conns) end
			table.clear(tracked)

			-- Give the game's own Animate back.
			for _, plr in ipairs(Players:GetPlayers()) do
				local char = plr.Character
				local animate = char and char:FindFirstChild("Animate")
				if animate then animate.Disabled = false end
			end
			print("[2007 Animation] Off.")
		end
	end

	Env.Animation2007 = { Start = engine.Start, Stop = engine.Stop, IsRunning = engine.IsRunning }

	Env.Animation2007Cleanup = function()
		alive = false
		disconnectAll(connections)
		table.clear(watched)
		engine.Stop()
		Env.Animation2007 = nil
	end

	------------------------------------------------------------
	-- SAVE / LOAD
	------------------------------------------------------------
	local function readJson(file)
		if not (readfile and isfile) then return nil end
		local ok, data = pcall(function()
			if isfile(file) then return HttpService:JSONDecode(readfile(file)) end
		end)
		return ok and type(data) == "table" and data or nil
	end

	local function loadChoice()
		local data = readJson(SAVE_FILE)
		return data ~= nil and data.Animation2007 == true
	end

	local function saveChoice(on)
		if not writefile then return end
		pcall(function() writefile(SAVE_FILE, HttpService:JSONEncode({ Animation2007 = on })) end)
	end

	-- True when Bloxy's "skip setup" box is ticked
	local function bloxySkipOn()
		local data = readJson(BLOXY_CONFIG)
		return data ~= nil and data.isSkipped == true
	end

	------------------------------------------------------------
	-- THE "2007" BUTTON ON BLOXY'S ANIMATIONS STEP
	------------------------------------------------------------
	-- Presses one of Bloxy's buttons the way a click would (Bloxy's handler plays the click sound and
	-- moves the wizard on). Returns false when this executor has no way to do it.
	local function press(btn)
		if not btn or not btn.Parent then return false end
		if firesignal then
			if pcall(firesignal, btn.MouseButton1Click) then return true end
		end
		if getconnections then
			local ok, conns = pcall(getconnections, btn.MouseButton1Click)
			if ok and type(conns) == "table" and #conns > 0 then
				local fired = false
				for _, conn in ipairs(conns) do
					local fn = conn.Function
					if fn then
						task.spawn(pcall, fn)
						fired = true
					elseif conn.Fire then
						if pcall(function() conn:Fire() end) then fired = true end
					end
				end
				if fired then return true end
			end
		end
		return false
	end

	-- Our own press of "Normal" runs the other buttons' handlers below too; they must not count
	-- as the player picking one of Bloxy's animations.
	local pressing = false

	local function findStepLabel(frame)
		for _, d in ipairs(frame:GetChildren()) do
			if d:IsA("TextLabel") and string.find(string.lower(d.Text or ""), STEP_TEXT, 1, true) then
				return d
			end
		end
		return nil
	end

	local function buttonWithText(frame, text)
		for _, d in ipairs(frame:GetChildren()) do
			if d:IsA("TextButton") and d.Text == text and d.Name ~= BUTTON_NAME then
				return d
			end
		end
		return nil
	end

	-- Same look as Bloxy's own wizard buttons
	local function makeButton(frame, reference)
		local btn = Instance.new("TextButton")
		btn.Name = BUTTON_NAME
		btn.Size = reference.Size
		btn.Position = reference.Position
		btn.Text = "2007"
		btn.Font = Enum.Font.Legacy
		btn.TextScaled = true
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		btn.BorderColor3 = Color3.fromRGB(0, 0, 0)
		btn.TextColor3 = Color3.fromRGB(0, 0, 0)
		btn.ZIndex = reference.ZIndex
		btn.Parent = frame

		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = 16
		constraint.MinTextSize = 8
		constraint.Parent = btn

		btn.MouseEnter:Connect(function()
			btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			btn.BorderColor3 = Color3.fromRGB(255, 0, 0)
		end)
		btn.MouseLeave:Connect(function()
			btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			btn.TextColor3 = Color3.fromRGB(0, 0, 0)
			btn.BorderColor3 = Color3.fromRGB(0, 0, 0)
		end)
		return btn
	end

	-- Returns true when the button is on (or the frame is not the R6 animations step at all)
	local function addButton(frame)
		if frame:FindFirstChild(BUTTON_NAME) then return true end
		if not findStepLabel(frame) then return false end

		local b2008 = buttonWithText(frame, "2008")
		local b2006 = buttonWithText(frame, "2006")
		local b2014 = buttonWithText(frame, "2014")
		local bNormal = buttonWithText(frame, "Normal")
		if not (b2008 and b2006 and b2014 and bNormal) then return false end

		local btn = makeButton(frame, b2006)

		-- Five buttons in the box that held four: 2008, 2006, 2007, 2014, Normal
		local order = { b2008, b2006, btn, b2014, bNormal }
		local margin, gap = 10, 10
		local width = math.floor((frame.Size.X.Offset - margin * 2 - gap * (#order - 1)) / #order)
		local y = b2006.Position.Y.Offset
		for i, b in ipairs(order) do
			b.Size = UDim2.new(0, width, 0, b.Size.Y.Offset)
			b.Position = UDim2.new(0, margin + (i - 1) * (width + gap), 0, y)
		end

		-- Picking one of Bloxy's own: the 2007 animation goes off
		for _, other in ipairs({ b2008, b2006, b2014, bNormal }) do
			other.MouseButton1Click:Connect(function()
				if pressing or not alive then return end
				saveChoice(false)
				engine.Stop()
			end)
		end

		local picked = false
		btn.MouseButton1Click:Connect(function()
			if picked or not alive then return end
			picked = true

			saveChoice(true)
			-- Bloxy only saves (doesn't run) when you re-configure with "skip" ticked
			if not bloxySkipOn() then engine.Start() end

			-- Moves the wizard on the way "Normal" does (no Bloxy animation script)
			pressing = true
			local pressed = press(bNormal)
			-- (Bloxy's handlers run at once, or a moment later in the same frame)
			task.delay(0.25, function() pressing = false end)
			if not pressed then
				warn("[2007 Animation] Couldn't move the setup on: press Normal to continue (2007 is picked).")
				picked = false
			end
		end)
		return true
	end

	local function checkFrame(frame)
		if not alive or handled[frame] or not frame:IsA("Frame") then return end
		handled[frame] = true
		-- Bloxy makes the box and then fills it in; give it a few frames
		task.spawn(function()
			for _ = 1, 30 do
				if not alive or not frame.Parent then return end
				if addButton(frame) then return end
				task.wait()
			end
		end)
	end

	local function watchBloxy(sg)
		if not (sg:IsA("ScreenGui") and sg.Name == BLOXY_GUI) or watched[sg] then return end
		watched[sg] = true
		connect(sg.AncestryChanged, function()
			if not sg.Parent then watched[sg] = nil end
		end)

		for _, frame in ipairs(sg:GetChildren()) do checkFrame(frame) end
		connect(sg.ChildAdded, checkFrame)

		-- "Skip setup" ticked: Bloxy applies its saved choices, we apply the saved 2007 animation
		if bloxySkipOn() and loadChoice() then
			engine.Start()
		end
	end

	task.spawn(function()
		local plr = Players.LocalPlayer
		while not plr do
			task.wait()
			plr = Players.LocalPlayer
		end
		local pg = plr:WaitForChild("PlayerGui")

		-- Bloxy's GUI is normally in PlayerGui; some executors put GUIs in gethui() / CoreGui
		local containers = { pg }
		pcall(function()
			local hui = gethui and gethui()
			if hui and hui ~= pg then table.insert(containers, hui) end
		end)
		pcall(function()
			local _ = CoreGui:GetChildren()
			table.insert(containers, CoreGui)
		end)

		if not alive then return end
		for _, container in ipairs(containers) do
			pcall(function()
				for _, g in ipairs(container:GetChildren()) do watchBloxy(g) end
				connect(container.ChildAdded, watchBloxy)
			end)
		end
	end)

	print("[2007 Animation] Installed. Saved choice: " .. (loadChoice() and "2007" or "not 2007"))
end
