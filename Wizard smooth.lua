-- [[ WIZARD SKIP v10 — single sound, no lingering frame, no gap ]]
-- v9: never gets the setup stuck. It waits for the "No" button before hiding the
-- old materials prompt, can press it through getconnections when firesignal is
-- missing, and shows the prompt again if the press didn't go through (so forcefield,
-- old particles and the rest of the setup always come).
-- v10: no lag after the setup. The tween and method-call hooks used to stay on for the
-- whole game, and every method call of every script went through them (and every GUI
-- tween looked through its GUI for the materials prompt). Now they are only on while a
-- setup question is on screen (and a few seconds after), and Bloxy's own panel
-- (HammerBigPanel, which is never a question) is no longer searched on every frame.

task.spawn(function()
	local TweenService = game:GetService("TweenService")
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local SoundService = game:GetService("SoundService")

	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui", 30)

	local sg
	local elapsed = 0
	while elapsed < 60 do
		sg = pg:FindFirstChild("BloxyParadoxProject")
		if sg then break end
		task.wait(0.2)
		elapsed = elapsed + 0.2
	end
	if not sg then
		warn("[Wizard Skip] GUI never appeared.")
		return
	end

	-- On-screen timeline for debugging; prints still go to the console.
	local SHOW_LOG = false
	local t0 = os.clock()
	local logLabel
	if SHOW_LOG then
		pcall(function()
			local logGui = Instance.new("ScreenGui")
			logGui.Name = "WizardSkipLog"
			logGui.ResetOnSpawn = false
			logGui.IgnoreGuiInset = true
			logGui.DisplayOrder = 999999
			logLabel = Instance.new("TextLabel")
			logLabel.Size = UDim2.new(0, 440, 0, 230)
			logLabel.Position = UDim2.new(0.5, -220, 1, -240)
			logLabel.BackgroundColor3 = Color3.new(0, 0, 0)
			logLabel.BackgroundTransparency = 0.35
			logLabel.TextColor3 = Color3.new(1, 1, 0)
			logLabel.Font = Enum.Font.Code
			logLabel.TextSize = 14
			logLabel.TextXAlignment = Enum.TextXAlignment.Left
			logLabel.TextYAlignment = Enum.TextYAlignment.Bottom
			logLabel.Text = ""
			logLabel.Parent = logGui
			logGui.Parent = (gethui and gethui()) or pg
		end)
	end

	local logLines = {}
	local function log(msg)
		local line = string.format("%6.2f %s", os.clock() - t0, msg)
		print("[Wizard Skip] " .. line)
		if logLabel then
			table.insert(logLines, line)
			if #logLines > 14 then table.remove(logLines, 1) end
			logLabel.Text = table.concat(logLines, "\n")
		end
	end

	local function hasText(obj, needle)
		if not obj or typeof(obj) ~= "Instance" then return false end
		if not obj:IsA("GuiObject") then return false end
		local found = false
		pcall(function()
			for _, d in ipairs(obj:GetDescendants()) do
				if d:IsA("TextLabel")
				   and type(d.Text) == "string"
				   and d.Text:lower():find(needle, 1, true) then
					found = true
					return
				end
			end
		end)
		return found
	end

	local function isMaterialsFrame(obj) return hasText(obj, "old materials") end
	-- The prompt shown right before the materials one.
	local function isBodyFrame(obj) return hasText(obj, "2006 body") end

	-- Presses a button the way a click would. Returns false when this executor has no way
	-- to do it (no firesignal and no getconnections): a Roblox signal has no :Fire().
	local function fireClick(btn)
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

	-- The gap is the hidden materials prompt playing its full slide-in: the
	-- game only moves on to the forcefield prompt once it has finished. So
	-- every tween on that prompt is made to take 0s. It still finishes as
	-- "Completed", so the game's own flow carries on as normal.
	--
	-- The prompt can't always be recognised when its slide-in tween is
	-- created (its text may not be set yet), so from the moment the body
	-- prompt is answered until the materials prompt is recognised, tweens on
	-- anything other than the body prompt are made instant too.
	local handled = setmetatable({}, {__mode = "k"})
	local bodyFrame, armedAt

	-- Bloxy's own panel (the hammer menu) lives in the same GUI as the setup questions but is
	-- never one. It stays for the whole game, so it must not be searched over and over.
	local OWN_PANEL = "HammerBigPanel"
	-- true while a setup question is on screen (or just was): only then do the hooks do anything
	local hooksNeeded = false

	local function inside(obj, frame)
		return frame ~= nil and (obj == frame or obj:IsDescendantOf(frame))
	end

	local function isHiddenPromptTween(obj)
		if typeof(obj) ~= "Instance" or not obj:IsA("GuiObject") then return false end
		for frame in pairs(handled) do
			if inside(obj, frame) then return true end
		end
		if armedAt and os.clock() - armedAt < 2 and not inside(obj, bodyFrame) then
			return true
		end
		return isMaterialsFrame(obj)
	end

	local function createTween(create, self, obj, tweenInfo, goal)
		if hooksNeeded and typeof(tweenInfo) == "TweenInfo" and (tweenInfo.Time > 0 or tweenInfo.DelayTime > 0) then
			local ok, hidden = pcall(isHiddenPromptTween, obj)
			if ok and hidden then
				tweenInfo = TweenInfo.new(
					0,
					tweenInfo.EasingStyle,
					tweenInfo.EasingDirection,
					tweenInfo.RepeatCount,
					tweenInfo.Reverses,
					0
				)
			end
		end
		return create(self, obj, tweenInfo, goal)
	end

	-- Set when the hidden No is pressed so the game's click sound for it is
	-- swallowed; the player already heard one for the body prompt.
	local muteClickUntil = 0

	-- The two hooks are put on when a setup question appears and taken off again a few
	-- seconds after the last one is gone (and put on again if the setup is opened again).
	-- If this executor can't take a hook off, it stays on but does nothing while no question
	-- is up (the hooksNeeded check), as before.
	local createHook = nil     -- { original = ... } while the TweenService.Create hook is on
	local namecallHook = nil   -- { original = ... } while the __namecall hook is on

	local function installCreateHook()
		if createHook or not hookfunction then return end
		local ok, err = pcall(function()
			local oldCreate
			local createWrapper = function(self, obj, tweenInfo, goal)
				return createTween(oldCreate, self, obj, tweenInfo, goal)
			end
			if newcclosure then createWrapper = newcclosure(createWrapper) end
			oldCreate = hookfunction(TweenService.Create, createWrapper)
			createHook = { original = oldCreate }
		end)
		log("TweenService.Create" .. (ok and " hooked" or (" hook FAILED: " .. tostring(err))))
	end

	-- The game calls TweenService:Create(...), which goes through __namecall
	-- and skips the hookfunction hook above on many executors.
	local function installNamecallHook()
		if namecallHook or not (hookmetamethod and getnamecallmethod) then return end
		local ok, err = pcall(function()
			local oldNamecall
			local namecallWrapper = function(self, ...)
				if muteClickUntil > 0 and os.clock() < muteClickUntil then
					-- No Instance namecalls before oldNamecall below, or the pending
					-- method name changes; ClassName is a plain property read.
					-- Lowercase too: older games use the deprecated sound:play().
					local method = tostring(getnamecallmethod()):lower()
					if ((method == "play" or method == "resume")
					    and typeof(self) == "Instance" and self.ClassName == "Sound")
					   or (method == "playlocalsound" and self == SoundService) then
						return
					end
				end
				if hooksNeeded and self == TweenService and getnamecallmethod() == "Create" then
					-- Index call, not a namecall: anything namecalled while checking
					-- changes the pending method name, so oldNamecall can't be reused.
					return createTween(TweenService.Create, self, ...)
				end
				return oldNamecall(self, ...)
			end
			if newcclosure then namecallWrapper = newcclosure(namecallWrapper) end
			oldNamecall = hookmetamethod(game, "__namecall", namecallWrapper)
			namecallHook = { original = oldNamecall }
		end)
		log("__namecall" .. (ok and " hooked" or (" hook FAILED: " .. tostring(err))))
	end

	local function removeHooks()
		if namecallHook then
			-- every method call in the game goes through this hook: it must not stay for nothing
			local ok = pcall(function() hookmetamethod(game, "__namecall", namecallHook.original) end)
			if ok then
				namecallHook = nil
				log("__namecall hook taken off")
			end
		end
		if createHook then
			local ok = pcall(function() hookfunction(TweenService.Create, createHook.original) end)
			if ok then
				createHook = nil
				log("TweenService.Create hook taken off")
			end
		end
	end

	local function installHooks()
		installCreateHook()
		installNamecallHook()
	end

	-- The hook above only catches sound:Play() calls. To catch the click
	-- however the game plays it, any sound that starts within 0.3s of the
	-- hidden press is stopped. Sounds already playing (music) are left alone.
	local function soundsIn(roots)
		local list = {}
		for _, root in ipairs(roots) do
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("Sound") then table.insert(list, d) end
			end
		end
		return list
	end

	local function silenceNextPress()
		local roots = { player, SoundService }
		if workspace.CurrentCamera then table.insert(roots, workspace.CurrentCamera) end

		local before = {}
		for _, s in ipairs(soundsIn(roots)) do
			if s.IsPlaying then before[s] = s.TimePosition end
		end

		local function stopIfNew(s)
			if not s.IsPlaying then return end
			local t = before[s]
			-- Not playing before, or restarted from the beginning.
			if t == nil or s.TimePosition < t then s:Stop() end
		end

		local function sweep()
			for _, s in ipairs(soundsIn(roots)) do pcall(stopIfNew, s) end
		end

		local stopAt = os.clock() + 0.3
		muteClickUntil = stopAt

		-- Sounds created on the spot can be parented anywhere.
		local added = game.DescendantAdded:Connect(function(d)
			if d:IsA("Sound") then task.defer(pcall, stopIfNew, d) end
		end)
		local stepped
		stepped = RunService.RenderStepped:Connect(function()
			sweep()
			if os.clock() >= stopAt then
				stepped:Disconnect()
				added:Disconnect()
			end
		end)

		return sweep
	end

	local watchedBody = setmetatable({}, {__mode = "k"})

	local function watchBody(frame)
		if watchedBody[frame] or not frame:IsA("Frame") or not isBodyFrame(frame) then return end
		local buttons = {}
		for _, d in ipairs(frame:GetDescendants()) do
			if d:IsA("TextButton") then table.insert(buttons, d) end
		end
		if #buttons == 0 then return end
		watchedBody[frame] = true
		for _, btn in ipairs(buttons) do
			btn.MouseButton1Click:Connect(function()
				bodyFrame = frame
				armedAt = os.clock()
				log("body prompt answered")
			end)
		end
	end

	local function skipFrame(frame)
		if handled[frame] or not frame:IsA("Frame") or not isMaterialsFrame(frame) then return end

		-- Bloxy sets the question text BEFORE it makes the Yes / No buttons. In games where
		-- events run straight away, this check sees the text first: leave the prompt alone
		-- until "No" exists (the next check tries again), instead of hiding it for good.
		local noBtn
		for _, d in ipairs(frame:GetDescendants()) do
			if d:IsA("TextButton") and d.Text == "No" then
				noBtn = d
				break
			end
		end
		if not noBtn then return end

		handled[frame] = true
		armedAt = nil

		-- Where Bloxy shows its prompts (centre of the screen)
		local shownAt = UDim2.new(0.5, -frame.Size.X.Offset / 2, 0.5, -frame.Size.Y.Offset / 2)
		local function showAgain(reason)
			log(reason .. ": materials prompt shown again, answer it yourself")
			pcall(function()
				frame.Visible = true
				frame.Position = shownAt
			end)
		end

		log("materials prompt hidden")
		pcall(function()
			frame.Visible = false
			frame.Position = UDim2.new(0, 0, 0, -9999)
		end)

		-- Let the game's own No handler run, so it records the answer and
		-- shows the forcefield prompt itself.
		local sweep = silenceNextPress()
		local pressed = fireClick(noBtn)
		-- Stop it before it's heard if the handler played it straight away.
		sweep()

		-- Never leave the setup stuck on a hidden prompt: forcefield, old particles and
		-- everything after them only come once this prompt is answered.
		if not pressed then
			showAgain("this executor can't press No")
			return
		end
		-- Bloxy removes the prompt as soon as No goes through; still here = it didn't.
		task.delay(1.5, function()
			if frame.Parent then showAgain("No didn't go through") end
		end)
	end

	local function check(frame)
		skipFrame(frame)
		watchBody(frame)
	end

	-- Which setup questions are on screen decides when the hooks are on.
	local questions = {}
	local questionCount = 0
	local idleToken = 0

	local function isQuestion(obj)
		return obj:IsA("Frame") and obj.Name ~= OWN_PANEL
	end

	local function questionAdded(child)
		if questions[child] or not isQuestion(child) then return end
		questions[child] = true
		questionCount = questionCount + 1
		idleToken = idleToken + 1
		-- on before the game makes the tween for this question
		hooksNeeded = true
		installHooks()
	end

	local function questionGone(child)
		if not questions[child] then return end
		questions[child] = nil
		questionCount = questionCount - 1
		if questionCount > 0 then return end
		-- the next question comes about a third of a second after one leaves; a few seconds
		-- with none means the setup is over
		idleToken = idleToken + 1
		local token = idleToken
		task.delay(4, function()
			if token ~= idleToken or questionCount > 0 then return end
			hooksNeeded = false
			removeHooks()
		end)
	end

	sg.ChildRemoved:Connect(questionGone)

	-- React the moment the frame (or its question text) shows up instead of
	-- waiting for the next render step.
	sg.ChildAdded:Connect(function(child)
		questionAdded(child)
		if child.Name ~= OWN_PANEL then check(child) end
		if handled[child] or not child:IsA("Frame") then return end
		local conn
		conn = child.DescendantAdded:Connect(function(d)
			if d:IsA("TextLabel") then
				task.defer(check, child)
				d:GetPropertyChangedSignal("Text"):Connect(function()
					check(child)
				end)
			end
			if handled[child] then conn:Disconnect() end
		end)
	end)

	-- Every frame only while a setup question is on screen (the questions are also caught the moment
	-- they're added, above); after the setup a look twice a second is plenty. It went through Bloxy's
	-- whole GUI on every frame for the whole game.
	local idleAcc = 0
	RunService.RenderStepped:Connect(function(dt)
		if not sg or not sg.Parent then return end
		if questionCount <= 0 then
			idleAcc = idleAcc + (dt or 0)
			if idleAcc < 0.5 then return end
			idleAcc = 0
		end

		for _, frame in ipairs(sg:GetChildren()) do
			if frame.Name ~= OWN_PANEL then check(frame) end
		end
	end)

	-- questions that were already on screen when this script started
	for _, child in ipairs(sg:GetChildren()) do questionAdded(child) end

	log("v10 watching")
end)