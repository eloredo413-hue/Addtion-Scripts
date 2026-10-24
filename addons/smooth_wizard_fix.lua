-- [[ WIZARD SKIP v8.1 — single sound, no lingering frame, no gap ]]
-- v8.1: waits for the materials prompt's No button before pressing it (the game
-- creates its buttons after the question text), so the wizard no longer stops there.

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

	local function fireClick(btn)
		if not btn or not btn.Parent then return end
		if firesignal then
			if pcall(firesignal, btn.MouseButton1Click) then return end
		end
		-- No firesignal: run the button's handlers directly.
		if getconnections then
			local ok, conns = pcall(getconnections, btn.MouseButton1Click)
			if ok and type(conns) == "table" then
				for _, conn in ipairs(conns) do
					if conn.Function then pcall(conn.Function) end
				end
			end
		end
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
		if typeof(tweenInfo) == "TweenInfo" and (tweenInfo.Time > 0 or tweenInfo.DelayTime > 0) then
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

	-- hookfunction returns the original; calling the hooked function from
	-- inside its wrapper would recurse into the wrapper.
	if hookfunction then
		local ok, err = pcall(function()
			local oldCreate
			local createWrapper = function(self, obj, tweenInfo, goal)
				return createTween(oldCreate, self, obj, tweenInfo, goal)
			end
			if newcclosure then createWrapper = newcclosure(createWrapper) end
			oldCreate = hookfunction(TweenService.Create, createWrapper)
		end)
		log("TweenService.Create" .. (ok and " hooked" or (" hook FAILED: " .. tostring(err))))
	end

	-- Set when the hidden No is pressed so the game's click sound for it is
	-- swallowed; the player already heard one for the body prompt.
	local muteClickUntil = 0

	-- The game calls TweenService:Create(...), which goes through __namecall
	-- and skips the hookfunction hook above on many executors.
	if hookmetamethod and getnamecallmethod then
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
				if self == TweenService and getnamecallmethod() == "Create" then
					-- Index call, not a namecall: anything namecalled while checking
					-- changes the pending method name, so oldNamecall can't be reused.
					return createTween(TweenService.Create, self, ...)
				end
				return oldNamecall(self, ...)
			end
			if newcclosure then namecallWrapper = newcclosure(namecallWrapper) end
			oldNamecall = hookmetamethod(game, "__namecall", namecallWrapper)
		end)
		log("__namecall" .. (ok and " hooked" or (" hook FAILED: " .. tostring(err))))
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

	local waitingForNo = setmetatable({}, {__mode = "k"})

	local function skipFrame(frame)
		if handled[frame] or not frame:IsA("Frame") or not isMaterialsFrame(frame) then return end
		armedAt = nil

		pcall(function()
			frame.Visible = false
			frame.Position = UDim2.new(0, 0, 0, -9999)
		end)

		-- The game sets the question text before it creates the Yes / No
		-- buttons, so the prompt is often recognised before No exists. It
		-- stays hidden and is checked again until the button is there.
		local noBtn
		for _, d in ipairs(frame:GetDescendants()) do
			if d:IsA("TextButton") and d.Text == "No" then
				noBtn = d
				break
			end
		end

		if not noBtn then
			if not waitingForNo[frame] then
				waitingForNo[frame] = true
				log("materials prompt hidden, waiting for its No button")
			end
			return
		end

		handled[frame] = true
		log("materials prompt hidden")

		-- Let the game's own No handler run, so it records the answer and
		-- shows the forcefield prompt itself. Deferred so the game has
		-- finished building the prompt and connecting its buttons first.
		task.defer(function()
			for attempt = 1, 2 do
				local sweep = silenceNextPress()
				fireClick(noBtn)
				-- Stop it before it's heard if the handler played it straight away.
				sweep()

				-- The game's No handler slides the prompt out and destroys it.
				local waited = 0
				while frame.Parent and waited < 1.5 do
					waited = waited + task.wait()
				end
				if not frame.Parent then return end
				log("No press did not register (attempt " .. attempt .. ")")
			end

			-- It could not be answered for the player: show it so they can
			-- answer it themselves instead of the wizard stopping here.
			log("showing the materials prompt")
			pcall(function()
				frame.Position = UDim2.new(0.5, -frame.Size.X.Offset / 2, 0.5, -frame.Size.Y.Offset / 2)
				frame.Visible = true
			end)
		end)
	end

	local function check(frame)
		skipFrame(frame)
		watchBody(frame)
	end

	-- React the moment the frame (or its question text) shows up instead of
	-- waiting for the next render step.
	sg.ChildAdded:Connect(function(child)
		check(child)
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

	RunService.RenderStepped:Connect(function()
		if not sg or not sg.Parent then return end

		for _, frame in ipairs(sg:GetChildren()) do
			check(frame)
		end
	end)

	log("v8.1 watching")
end)