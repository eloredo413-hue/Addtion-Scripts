-- [[ SETUP BACK / FORWARD — round "<" and ">" buttons on Bloxy's setup questions ]]
-- Each question of the setup gets a round "<" at its bottom-left corner and a round ">" at its bottom-right one.
--   <  goes back to the question before (as many times as you like, up to the topbar question).
--   >  gives the question on screen the answer you gave it last time, so you go forward again without answering
--      every question again. (Greyed out on a question you haven't answered yet.)
-- While the setup is on, your answers are only remembered: nothing loads yet, so going back and changing an answer
-- never leaves the old one running. After the last question everything you picked loads together, the same way
-- it does when "skip setup" is ticked: Bloxy's own picks, and the picks of the addons' questions (explosion,
-- terrain, old particles, old physics / camera, the 2007 and modern R6 animations) and the loader's follow-up of
-- the GUI you picked (bubbles, loading screen, escape menu ...).
-- With Bloxy's own "configure" button (its answers are only saved for next time there) the buttons work the same,
-- and at the end only the addons' picks run, as they always did there.
-- How: Bloxy keeps a switch (its "configure" mode) that makes each answer only saved. It is turned on through the
-- functions Bloxy's buttons run (getconnections, debug.getupvalues / setupvalue), and each answer is remembered on
-- the way through. On an executor without those, or if anything about Bloxy's setup isn't as expected, there are
-- no buttons and the setup works exactly as before.
-- Other scripts: getgenv().BPWizard.later(key, fn) holds fn until the end of the setup (returns false when no setup
-- with these buttons is on: then run it yourself); getgenv().BPWizard.noteTap(button) remembers a press made by a
-- script (Saved Settings' answers) as an answer.

local Env = (getgenv and getgenv()) or _G
if type(Env.BPWizardCleanup) == "function" then pcall(Env.BPWizardCleanup) end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")

local BLOXY_GUI = "BloxyParadoxProject"
local BACK_NAME, FORWARD_NAME = "BPWizardBack", "BPWizardForward"
local CLICK_ID = "rbxassetid://12221967"
local STABLE = 0.25 -- seconds a question has to sit still before it counts (an addon may still be changing it)

local getConnections = getconnections or get_signal_cons
local dbg = debug or {}
local getUpvalues = dbg.getupvalues or getupvalues
local setUpvalue = dbg.setupvalue or setupvalue
local getConstants = dbg.getconstants or getconstants

local alive = true
local conns = {}
local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(conns, c)
	return c
end

local sfx = Instance.new("Sound")
sfx.Name = "BPWizardClick"
sfx.SoundId = CLICK_ID
sfx.Volume = 0.6
pcall(function() sfx.Parent = SoundService end)
local function playClick()
	pcall(function()
		sfx:Stop()
		sfx:Play()
	end)
end

------------------------------------------------------------
-- REACHING INTO BLOXY'S BUTTONS
------------------------------------------------------------
local function upvaluesOf(fn)
	if type(fn) ~= "function" or not getUpvalues then return nil end
	local ok, ups = pcall(getUpvalues, fn)
	if ok and type(ups) == "table" then return ups end
	return nil
end

local function handlersOf(btn)
	local list = {}
	if not getConnections then return list end
	local ok, cs = pcall(getConnections, btn.MouseButton1Click)
	if not ok or type(cs) ~= "table" then return list end
	for _, c in ipairs(cs) do
		local okFn, fn = pcall(function() return c.Function end)
		if okFn and type(fn) == "function" then table.insert(list, fn) end
	end
	return list
end

-- presses a button the way a tap would
local function press(btn)
	if not btn or not btn.Parent then return false end
	if firesignal then
		if pcall(firesignal, btn.MouseButton1Click) then return true end
	end
	local fired = false
	for _, fn in ipairs(handlersOf(btn)) do
		task.spawn(pcall, fn)
		fired = true
	end
	return fired
end

local W = {
	sg = nil,
	session = false,        -- a setup with the buttons on (answers only remembered)
	bloxyConfigure = false, -- started from Bloxy's "configure" (its answers are only saved for next time)
	flag = nil,             -- where Bloxy's "configure" switch is: { fn = a function using it, index = its place }
	startShow = nil,        -- Bloxy's function that shows the topbar question
}

local function readFlag()
	local f = W.flag
	if not f then return nil end
	local ups = upvaluesOf(f.fn)
	local v = ups and ups[f.index]
	if type(v) == "boolean" then return v end
	return nil
end

local function writeFlag(value)
	local f = W.flag
	if not (f and setUpvalue) then return false end
	if not pcall(setUpvalue, f.fn, f.index, value) then return false end
	return readFlag() == value
end

-- what a function Bloxy's answer button uses is:
--   "pick": one of its "On...Selected" functions (it saves the answer and runs it unless "configure" is on: it
--           uses that switch, the only true / false value Bloxy's functions use)
--   "show": a function that shows a question (it puts a frame in Bloxy's GUI)
--   "next": the mobile jump question's "which question comes next" (it only uses show functions)
local isWrapper = setmetatable({}, { __mode = "k" })
local function classify(fn, depth)
	if isWrapper[fn] then return "pick" end
	local ups = upvaluesOf(fn)
	if not ups then return nil end
	local hasBool, hasGui, allFns, n = false, false, true, 0
	for _, v in pairs(ups) do
		n = n + 1
		if type(v) == "boolean" then hasBool = true end
		if W.sg and typeof(v) == "Instance" and v == W.sg then hasGui = true end
		if type(v) ~= "function" then allFns = false end
	end
	if hasBool then return "pick" end
	if hasGui then return "show" end
	if allFns and n > 0 and (depth or 0) < 1 then
		for _, v in pairs(ups) do
			if classify(v, (depth or 0) + 1) == "show" then return "next" end
		end
	end
	return nil
end

-- the show functions by the question text they put up (when the executor can read a function's texts)
local showByText = {}
local function learnShow(fn)
	if not getConstants then return end
	local ok, consts = pcall(getConstants, fn)
	if not ok or type(consts) ~= "table" then return end
	for _, c in pairs(consts) do
		if type(c) == "string" and #c > 8 and string.find(c, "%a") then
			showByText[string.lower(c)] = showByText[string.lower(c)] or fn
		end
	end
end

-- Each "On...Selected" Bloxy's buttons call is swapped (in that button's function only) for one that remembers
-- what it was given, so it can be given again at the end.
local wrappers, originalOf = {}, setmetatable({}, { __mode = "k" })
local pickOrder, lastArgs = {}, {}
local function wrapPick(orig)
	if isWrapper[orig] then return orig end
	if wrappers[orig] then return wrappers[orig] end
	local w = function(...)
		if W.session then
			lastArgs[orig] = table.pack(...)
			local seen = false
			for _, f in ipairs(pickOrder) do
				if f == orig then seen = true break end
			end
			if not seen then table.insert(pickOrder, orig) end
		end
		return orig(...)
	end
	wrappers[orig] = w
	isWrapper[w] = true
	originalOf[w] = orig
	return w
end

------------------------------------------------------------
-- THE QUESTIONS
------------------------------------------------------------
local function isQuestionFrame(f)
	return W.sg ~= nil and f.Parent == W.sg and f:IsA("Frame") and f:FindFirstChild("HeaderImage") ~= nil
end

-- a question's title: the label drawn on top (an addon's question laid over Bloxy's box), else the longest
local function questionTitle(frame)
	local best, bestZ = nil, -math.huge
	for _, d in ipairs(frame:GetDescendants()) do
		if d:IsA("TextLabel") and d.Visible and type(d.Text) == "string" and string.find(d.Text, "%a")
			and not d:FindFirstAncestorWhichIsA("GuiButton") then
			local z = d.ZIndex or 1
			if z > bestZ or (z == bestZ and #d.Text > #best) then
				best, bestZ = d.Text, z
			end
		end
	end
	return best
end

local function isTopbar(title)
	return title ~= nil and string.find(string.lower(title), "topbar", 1, true) ~= nil
end

-- the question sitting in the middle of the screen (not one sliding in or out)
local function restingFrame()
	if not (W.sg and W.sg.Parent) then return nil end
	for _, f in ipairs(W.sg:GetChildren()) do
		if f:IsA("Frame") and f.Visible and f:FindFirstChild("HeaderImage") then
			local p = f.Position
			if math.abs(p.Y.Scale - 0.5) < 0.002 and math.abs(p.X.Scale - 0.5) < 0.002 then return f end
		end
	end
	return nil
end

local frameInfo = setmetatable({}, { __mode = "k" }) -- question frame -> { show, nextShow, pages, picks, bloxy }
local lastFrame = nil -- the last of Bloxy's questions made
local navShow = nil   -- the show function Back just called (the next question made is its)

local function scanHandlers(frame, info)
	for _, b in ipairs(frame:GetDescendants()) do
		if b:IsA("TextButton") then
			for _, fn in ipairs(handlersOf(b)) do
				local ups = upvaluesOf(fn)
				local mine = false
				if ups then
					for _, v in pairs(ups) do
						if typeof(v) == "Instance" and v == frame then mine = true break end
					end
				end
				if mine then -- Bloxy's own answer button (its function uses this question's frame)
					info.bloxy = true
					for i, up in pairs(ups) do
						if type(up) == "function" then
							local kind = classify(up)
							if kind == "pick" then
								if isWrapper[up] then
									info.picks = true
								elseif type(i) == "number" and setUpvalue then
									local w = wrapPick(up)
									if pcall(setUpvalue, fn, i, w) then
										local now = upvaluesOf(fn)
										if now and now[i] == w then
											info.picks = true
											info.pickFn = info.pickFn or up
										end
									end
								end
							elseif kind == "show" then
								info.nextShow = up
								learnShow(up)
							elseif kind == "next" then
								local ok, s = pcall(up)
								if ok and type(s) == "function" then
									info.nextShow = s
									learnShow(s)
								end
							end
						end
					end
				end
			end
		end
	end
end

------------------------------------------------------------
-- WHERE YOU ARE: the questions in order, and the answer each was given last
------------------------------------------------------------
local history = {}  -- { title, show, before = titles shown before it in the same box }
local index = 0     -- the question on screen in history
local answers = {}  -- title -> the taps of its last answer: { { text, name, pos }, ... }
local visit = { frame = nil, title = nil, taps = nil }
local current = nil -- { frame, title }
local queue, queueOrder = {}, {}
local busy = false
local replaying = false -- going through the questions before the one Back goes to
local navTarget = nil
local topbarShown = 0

local function pageTitleNow()
	local f = restingFrame()
	return f and questionTitle(f) or (current and current.title) or nil
end

local function clearQueued(title)
	for key, item in pairs(queue) do
		if item.page == title then queue[key] = nil end
	end
end

local function isAnswerText(text)
	return type(text) == "string" and text ~= "" and not string.find(text, "▼", 1, true)
		and not string.find(text, "▲", 1, true)
end

local function frameOf(obj)
	local f = obj
	while f and f.Parent ~= W.sg do f = f.Parent end
	if f and isQuestionFrame(f) then return f end
	return nil
end

------------------------------------------------------------
-- THE BUTTONS
------------------------------------------------------------
local buttonsOf = setmetatable({}, { __mode = "k" }) -- frame -> { back, forward }
local refreshButtons -- (below)

local function makeRound(frame, name, glyph, position, onPress)
	local b = Instance.new("ImageButton")
	b.Name = name
	b.Size = UDim2.new(0, 26, 0, 26)
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = position
	b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Image = ""
	b.ZIndex = 60
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	local label = Instance.new("TextLabel")
	label.Name = "Glyph"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = glyph
	label.Font = Enum.Font.SourceSansBold
	label.TextSize = 20
	label.TextColor3 = Color3.fromRGB(0, 0, 0)
	label.ZIndex = 61
	label.Parent = b
	local hovering = false
	local function look()
		local on = b:GetAttribute("Enabled") == true
		b.BackgroundTransparency = on and 0 or 0.45
		label.TextTransparency = on and 0 or 0.6
		stroke.Transparency = on and 0 or 0.5
		local dark = on and hovering
		b.BackgroundColor3 = dark and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
		label.TextColor3 = dark and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(0, 0, 0)
		stroke.Color = dark and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 0, 0)
	end
	b:GetAttributeChangedSignal("Enabled"):Connect(look)
	b.MouseEnter:Connect(function() hovering = true look() end)
	b.MouseLeave:Connect(function() hovering = false look() end)
	b.MouseButton1Click:Connect(function()
		if b:GetAttribute("Enabled") ~= true or busy or not W.session then return end
		playClick()
		task.spawn(onPress)
	end)
	b:SetAttribute("Enabled", false)
	look()
	b.Parent = frame
	return b
end

local goBack, goForward -- (below)

local function attachButtons(frame)
	local own = buttonsOf[frame]
	if own and own.back.Parent and own.forward.Parent then return end
	own = {
		back = makeRound(frame, BACK_NAME, "<", UDim2.new(0, -4, 1, 8), function() goBack() end),
		forward = makeRound(frame, FORWARD_NAME, ">", UDim2.new(1, 4, 1, 8), function() goForward() end),
	}
	buttonsOf[frame] = own
end

local function removeButtons()
	if not W.sg then return end
	for _, f in ipairs(W.sg:GetChildren()) do
		for _, name in ipairs({ BACK_NAME, FORWARD_NAME }) do
			local b = f:FindFirstChild(name)
			if b then pcall(function() b:Destroy() end) end
		end
	end
end

refreshButtons = function()
	if not current then return end
	local own = buttonsOf[current.frame]
	if not own then return end
	local prev = history[index - 1]
	local canBack = W.session and not busy and prev ~= nil and prev.show ~= nil
	local taps = answers[current.title]
	local canForward = W.session and not busy and taps ~= nil and #taps > 0
	own.back:SetAttribute("Enabled", canBack == true)
	own.forward:SetAttribute("Enabled", canForward == true)
end

------------------------------------------------------------
-- REMEMBERING TAPS
------------------------------------------------------------
-- one of Bloxy's own topbar options (its function uses the option's { text, id }), not one More guis added
local function isBloxyTopbarOption(btn)
	for _, fn in ipairs(handlersOf(btn)) do
		for _, v in pairs(upvaluesOf(fn) or {}) do
			if type(v) == "table" and type(rawget(v, "id")) == "string" and type(rawget(v, "text")) == "string" then
				return true
			end
		end
	end
	return false
end

local function remember(btn)
	if not W.session or replaying then return end
	local frame = frameOf(btn)
	if not frame then return end
	local title = questionTitle(frame)
	if not title then return end
	-- (the topbar list's own "none ▼" only opens the list: not part of an answer)
	if not isAnswerText(btn.Text) and btn.Name == "TextButton" then return end
	if isTopbar(title) and isBloxyTopbarOption(btn) then
		-- one of Bloxy's own years: a year of More guis' picked before it on this question doesn't stay waiting
		Env.BP_PendingTopbar = nil
		Env.BP_2023Variant = nil
	end
	if visit.frame ~= frame or visit.title ~= title then
		visit = { frame = frame, title = title, taps = {} }
	end
	if #visit.taps >= 10 then table.remove(visit.taps, 1) end
	table.insert(visit.taps, { text = btn.Text, name = btn.Name, pos = btn.Position })
	local copy = {}
	for i, t in ipairs(visit.taps) do copy[i] = t end
	answers[title] = copy
	task.defer(refreshButtons)
end

local hookedTaps = setmetatable({}, { __mode = "k" })
local function watchButton(d)
	if hookedTaps[d] or not d:IsA("TextButton") then return end
	hookedTaps[d] = true
	-- a real tap (Activated, or MouseButton1Up: whichever comes first, once). Presses made by scripts (an addon
	-- moving the setup on, More guis pressing Bloxy's own topbar) aren't answers of their own.
	local lastAt = -1
	local function tapped()
		local now = os.clock()
		if now - lastAt < 0.3 then return end
		lastAt = now
		remember(d)
	end
	d.Activated:Connect(tapped)
	d.MouseButton1Up:Connect(tapped)
end

-- the button that gives a remembered tap again: the same text (where two have it, the same name and place), else
-- for a dropdown whose text changes, the only one with its name
local function findTapButton(frame, tap)
	local best, bestScore = nil, -1
	local byName, nameCount = nil, 0
	local want = string.lower(tap.text or "")
	for _, d in ipairs(frame:GetDescendants()) do
		if d:IsA("TextButton") and d.Visible and d.Name ~= BACK_NAME and d.Name ~= FORWARD_NAME then
			if string.lower(d.Text or "") == want then
				local score = 0
				if d.Name == tap.name then score = score + 2 end
				if d.Position == tap.pos then score = score + 1 end
				if score > bestScore then best, bestScore = d, score end
			end
			if tap.name ~= "TextButton" and d.Name == tap.name then
				byName = d
				nameCount = nameCount + 1
			end
		end
	end
	if best then return best end
	if nameCount == 1 then return byName end
	return nil
end

-- Gives a question its remembered taps, one after the other, until the question goes (it starts moving away).
-- true when it went.
local function replay(frame, taps)
	local moved = false
	local c = frame:GetPropertyChangedSignal("Position"):Connect(function() moved = true end)
	for _, tap in ipairs(taps) do
		if moved or not frame.Parent then break end
		local btn = findTapButton(frame, tap)
		if btn then
			press(btn)
			local t0 = os.clock()
			repeat task.wait() until moved or not frame.Parent or os.clock() - t0 > 0.12
		end
	end
	if not moved and frame.Parent then
		local t0 = os.clock()
		repeat task.wait() until moved or not frame.Parent or os.clock() - t0 > 0.3
	end
	c:Disconnect()
	return moved or not frame.Parent
end

------------------------------------------------------------
-- THE END OF THE SETUP: everything picked loads
------------------------------------------------------------
local function saveAnswers()
	local api = Env.BPSavedSettings
	if not (type(api) == "table" and type(api.SetSetupAnswers) == "function") then return end
	local list = {}
	for i = 1, index do
		local page = history[i]
		for _, tap in ipairs(answers[page.title] or {}) do
			if isAnswerText(tap.text) then table.insert(list, { q = page.title, a = tap.text }) end
		end
	end
	if #list > 0 then pcall(api.SetSetupAnswers, list) end
end

local function finish(why)
	if not W.session then return end
	W.session = false
	busy = false
	replaying = false
	navTarget = nil
	removeButtons()
	local given = 0
	if not W.bloxyConfigure then
		-- Bloxy's own picks, in the order they were first given (the topbar first), each the last way it was given
		for _, orig in ipairs(pickOrder) do
			local args = lastArgs[orig]
			if args then
				local ok, err = pcall(orig, table.unpack(args, 1, args.n))
				if ok then given = given + 1 else warn("[Setup Back/Forward] a pick didn't load: " .. tostring(err)) end
			end
		end
	end
	-- the addons' picks and the loader's follow-up of the GUI, in the order they were first given
	local ran = 0
	for _, key in ipairs(queueOrder) do
		local item = queue[key]
		if item then
			ran = ran + 1
			task.spawn(function()
				local ok, err = pcall(item.fn)
				if not ok then warn("[Setup Back/Forward] \"" .. tostring(key) .. "\" didn't load: " .. tostring(err)) end
			end)
		end
	end
	table.clear(queue)
	table.clear(queueOrder)
	table.clear(lastArgs)
	table.clear(pickOrder)
	saveAnswers()
	print(string.format("[Setup Back/Forward] %s: %d of Bloxy's picks and %d of the addons' load now%s", why, given, ran,
		W.bloxyConfigure and " (Bloxy's \"configure\": its own picks are saved for next time, as always)" or ""))
end

------------------------------------------------------------
-- A QUESTION SHOWS
------------------------------------------------------------
local function hookFrame(frame)
	if frameInfo[frame] then return frameInfo[frame] end
	local info = { pages = {} }
	frameInfo[frame] = info
	if navShow then
		info.show = navShow
		navShow = nil
	elseif lastFrame and frameInfo[lastFrame] and frameInfo[lastFrame].nextShow then
		info.show = frameInfo[lastFrame].nextShow
	end
	lastFrame = frame
	pcall(scanHandlers, frame, info)
	if not info.show then
		local title = questionTitle(frame)
		if title then info.show = showByText[string.lower(title)] end
		if not info.show and isTopbar(title) then info.show = W.startShow end
	end
	for _, d in ipairs(frame:GetDescendants()) do watchButton(d) end
	frame.DescendantAdded:Connect(watchButton)
	return info
end

-- the same switch, read through the topbar answer's own function (it must be the one Bloxy's answers use)
local function pickSeesFlag(info, value)
	local ups = info.pickFn and upvaluesOf(info.pickFn)
	if not ups then return true end -- (nothing more to check with)
	for _, v in pairs(ups) do
		if type(v) == "boolean" then return v == value end
	end
	return true
end

-- the setup starts at the topbar question: Bloxy is put in its "configure" mode (answers only saved) for it
local function startSession(frame, info)
	if not (info.picks and W.flag) then return false end
	local was = readFlag()
	if was == nil then return false end
	if was == true then
		W.bloxyConfigure = true
	else
		W.bloxyConfigure = false
		if not writeFlag(true) then return false end
		if not pickSeesFlag(info, true) then
			writeFlag(false)
			return false
		end
	end
	W.session = true
	history, index, answers = {}, 0, {}
	table.clear(queue)
	table.clear(queueOrder)
	table.clear(lastArgs)
	table.clear(pickOrder)
	topbarShown = 0
	print("[Setup Back/Forward] on: your answers are only remembered until the last question, then everything loads"
		.. (W.bloxyConfigure and " (Bloxy's \"configure\")" or ""))
	return true
end

-- the switch Bloxy's topbar answer uses ("configure" mode), and the function that shows the topbar question:
-- from Bloxy's "configure" button, else from the topbar question's own button
local function findSwitch(frame, info)
	local cfg = W.sg and W.sg:FindFirstChild("ConfigureButton", true)
	if cfg and cfg:IsA("TextButton") then
		for _, fn in ipairs(handlersOf(cfg)) do
			local ups = upvaluesOf(fn)
			if ups then
				local bools, flagIndex = 0, nil
				for i, v in pairs(ups) do
					if type(v) == "boolean" then
						bools = bools + 1
						flagIndex = i
					elseif type(v) == "function" and classify(v) == "show" then
						W.startShow = W.startShow or v
					end
				end
				if bools == 1 and type(flagIndex) == "number" then W.flag = W.flag or { fn = fn, index = flagIndex } end
			end
		end
	end
	if not W.flag and info.pickFn then
		local ups = upvaluesOf(info.pickFn)
		local bools, flagIndex = 0, nil
		for i, v in pairs(ups or {}) do
			if type(v) == "boolean" then
				bools = bools + 1
				flagIndex = i
			end
		end
		if bools == 1 and type(flagIndex) == "number" then W.flag = { fn = info.pickFn, index = flagIndex } end
	end
	if W.startShow and not info.show then info.show = W.startShow end
end

-- a question of Bloxy's is made: hooked at once (before it can be answered); the topbar question starts the setup
local triedStart = setmetatable({}, { __mode = "k" })
local function questionMade(frame)
	local info = hookFrame(frame)
	if W.session or triedStart[frame] then return end
	local title = questionTitle(frame)
	if not isTopbar(title) then return end
	triedStart[frame] = true
	findSwitch(frame, info)
	startSession(frame, info)
end

local function onPage(frame, title)
	current = { frame = frame, title = title }
	local info = hookFrame(frame)
	if not W.session then return end
	local known = false
	for _, t in ipairs(info.pages) do
		if t == title then known = true break end
	end
	local before = {}
	for i, t in ipairs(info.pages) do before[i] = t end
	if not known then table.insert(info.pages, title) end
	-- this visit: its picks from before are gone (picked again here, or given again with ">")
	clearQueued(title)
	if isTopbar(title) then
		topbarShown = topbarShown + 1
		if topbarShown > 1 then
			-- back at the topbar: More guis' pick from before isn't kept (picked again, or given again with ">")
			Env.BP_PendingTopbar = nil
			Env.BP_2023Variant = nil
		end
	end
	if replaying then return end
	if navTarget and history[navTarget] and history[navTarget].title == title then
		index = navTarget
		history[index].show = info.show or history[index].show
	elseif history[index] and history[index].title == title then
		history[index].show = info.show or history[index].show
	elseif history[index + 1] and history[index + 1].title == title then
		index = index + 1
		history[index].show = info.show or history[index].show
		history[index].before = before
	else
		for i = #history, index + 1, -1 do table.remove(history, i) end
		table.insert(history, { title = title, show = info.show, before = before })
		index = #history
	end
	navTarget = nil
	-- a question of Bloxy's whose answer couldn't be reached: everything picked so far loads now, and the rest of
	-- the setup loads as you answer, as before
	if not (info.bloxy and info.picks) then
		warn("[Setup Back/Forward] couldn't reach the answers of \"" .. tostring(title) .. "\": everything "
			.. "picked so far loads now, and the rest loads as you answer (no < > from here)")
		if not W.bloxyConfigure then writeFlag(false) end
		finish("the setup goes on without < >")
		return
	end
	attachButtons(frame)
	refreshButtons()
end

------------------------------------------------------------
-- < AND >
------------------------------------------------------------
goForward = function()
	if busy or not current then return end
	local taps = answers[current.title]
	if not taps or #taps == 0 then return end
	busy = true
	refreshButtons()
	replay(current.frame, taps)
	busy = false
	refreshButtons()
end

goBack = function()
	if busy or not current then return end
	local targetIndex = index - 1
	local target = history[targetIndex]
	if not (target and target.show) then return end
	busy = true
	refreshButtons()
	replaying = true
	navTarget = targetIndex
	-- the question on screen goes, and the one before is shown again
	for _, f in ipairs(W.sg:GetChildren()) do
		if isQuestionFrame(f) then pcall(function() f:Destroy() end) end
	end
	current = nil
	navShow = target.show
	task.spawn(target.show)
	-- in its box, the questions before it are given their answers again (an addon's question comes first there)
	local before = {}
	for _, t in ipairs(target.before or {}) do before[t] = true end
	local deadline = os.clock() + 10
	local done = setmetatable({}, { __mode = "k" }) -- frame -> { [title] = true }: given once
	while alive and W.session and os.clock() < deadline do
		task.wait(0.05)
		local f = restingFrame()
		local t = f and questionTitle(f)
		if f and t then
			if t == target.title then break end
			local taps = answers[t]
			done[f] = done[f] or {}
			if before[t] and taps and #taps > 0 and not done[f][t] then
				done[f][t] = true
				task.wait(STABLE)
				if restingFrame() == f and questionTitle(f) == t then replay(f, taps) end
			elseif not before[t] then
				break -- (not one before it: it's left to you)
			end
		end
	end
	replaying = false
	current = nil -- (the page loop takes the question on screen as the current one again)
	busy = false
end

------------------------------------------------------------
-- WATCHING BLOXY'S GUI
------------------------------------------------------------
local candidate = { frame = nil, title = nil, since = 0 }
local endCheck = 0

local function step(dt)
	if not alive or not (W.sg and W.sg.Parent) then return end
	local f = restingFrame()
	local t = f and questionTitle(f)
	if f ~= candidate.frame or t ~= candidate.title then
		candidate = { frame = f, title = t, since = os.clock() }
	end
	if f and t and os.clock() - candidate.since >= STABLE then
		if not current or current.frame ~= f or current.title ~= t then onPage(f, t) end
	end
	if W.session then
		endCheck = endCheck + (dt or 0)
		if endCheck >= 0.2 then
			endCheck = 0
			-- the last question was answered: Bloxy turns its "configure" mode off itself
			if readFlag() == false then finish("setup done") end
		end
	end
end

local containers = {}
local watchGui
local function lookForGui()
	for _, container in ipairs(containers) do
		pcall(function()
			for _, g in ipairs(container:GetChildren()) do watchGui(g) end
		end)
	end
end

watchGui = function(sg)
	if W.sg or not (sg:IsA("ScreenGui") and sg.Name == BLOXY_GUI) then return end
	W.sg = sg
	connect(sg.ChildAdded, function(child)
		task.defer(function()
			if alive and child.Parent == sg and isQuestionFrame(child) then pcall(questionMade, child) end
		end)
	end)
	for _, child in ipairs(sg:GetChildren()) do
		if isQuestionFrame(child) then pcall(questionMade, child) end
	end
	connect(sg.AncestryChanged, function()
		if not sg.Parent and W.sg == sg then
			finish("Bloxy's GUI went")
			W.sg, W.flag, W.startShow = nil, nil, nil
			lastFrame, current = nil, nil
			-- (Bloxy run again: its new GUI may already be there)
			lookForGui()
		end
	end)
end

task.spawn(function()
	local plr = Players.LocalPlayer
	while not plr do
		task.wait()
		plr = Players.LocalPlayer
	end
	local pg = plr:WaitForChild("PlayerGui")
	table.insert(containers, pg)
	pcall(function()
		local hui = gethui and gethui()
		if hui and hui ~= pg then table.insert(containers, hui) end
	end)
	pcall(function()
		local _ = CoreGui:GetChildren()
		table.insert(containers, CoreGui)
	end)
	for _, container in ipairs(containers) do
		pcall(function()
			for _, g in ipairs(container:GetChildren()) do watchGui(g) end
			connect(container.ChildAdded, watchGui)
		end)
	end
end)

connect(RunService.RenderStepped, step)

------------------------------------------------------------
-- FOR THE OTHER SCRIPTS
------------------------------------------------------------
Env.BPWizard = {
	-- true while a setup with these buttons is on (answers only remembered)
	deferring = function() return W.session end,
	-- hold fn until the end of the setup (its question's last answer wins). false: no such setup, run it now.
	later = function(key, fn)
		if not W.session or type(fn) ~= "function" then return false end
		if queue[key] == nil then
			local listed = false
			for _, k in ipairs(queueOrder) do
				if k == key then listed = true break end
			end
			if not listed then table.insert(queueOrder, key) end
		end
		queue[key] = { fn = fn, page = pageTitleNow() }
		return true
	end,
	-- a press a script made on a question (Saved Settings giving saved answers): remembered as its answer
	noteTap = function(btn)
		if not (W.session and typeof(btn) == "Instance" and btn:IsA("TextButton")) then return end
		local frame = frameOf(btn)
		local title = frame and questionTitle(frame)
		if frame and title and not (current and current.frame == frame and current.title == title) then
			pcall(onPage, frame, title)
		end
		remember(btn)
	end,
}

Env.BPWizardCleanup = function()
	alive = false
	if W.session then
		writeFlag(false)
		finish("replaced")
	end
	removeButtons()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	table.clear(conns)
	pcall(function() sfx:Destroy() end)
	if Env.BPWizard then Env.BPWizard = nil end
end

if not (getConnections and getUpvalues and setUpvalue) then
	print("[Setup Back/Forward] this executor can't reach Bloxy's setup (getconnections / debug.getupvalues / "
		.. "debug.setupvalue): the setup works as before, without < >")
else
	print("[Setup Back/Forward] ready: < and > show on the setup's questions")
end
