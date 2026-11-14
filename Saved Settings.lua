--[[ SAVED SETTINGS (Addtion-Scripts) ]]
-- A panel like Bloxy's hammer one, opened by the floppy disk (decal 90842402386374) under the hammer:
-- save what is set now under a name, and load, rename or delete what was saved. They are kept in
-- BloxyParadoxSavedSettings.json, so they are still there after leaving the game or running the script again.
--
-- What one holds, exactly as it was:
--   * Bloxy's whole settings file (BloxyParadoxConfig.json): every setup (wizard) choice, skip setup, every
--     option of the hammer's side panel (Bloxy's, Hammer stuff 1's and Hammer stuff 2's, the dropdowns too),
--     and the old physics and explosion picks
--   * the setup steps that keep their pick in a file of their own: terrain (BloxyTerrainChoice.json), the
--     2007 animation (BloxyAnimation2007Choice.json) and the topbar picked in More guis (BloxyTopbarPick.json)
--   * the answers given in the setup, in order (BloxySetupAnswers.json: recorded here each time the setup is
--     answered, by whichever Bloxy and More guis are running)
--
-- How it is used: go through the setup and pick the hammer's options, then save. Later (after a rejoin), run
-- the script and, while the setup is showing, load the file:
--   * the setup answers itself with the saved answers, press by press, with whichever Bloxy and More guis are
--     running (the GUI, safe chat, explosion, terrain...). Tapping an answer yourself meanwhile stops it, and so
--     does an answer that isn't there (More guis' 2013 mobile, say), so nothing else gets confirmed instead.
--   * the hammer's options change straight away (their boxes are pressed, so each option turns itself on or
--     off as usual)
--   * "skip setup" is left as it is (older versions turned it on, so Bloxy skipped the setup and loaded its
--     plain year: that is undone once)
--   * Bloxy writes its settings file with only its own settings in it, which dropped the other scripts' (the
--     hammer options were off at the next start); what it leaves out is kept now.
-- Nothing is loaded by itself at start.
--
-- The loader loads it, and so do the 2021 / 2023 old / 2023 new GUIs after the rejoin they do (the loader
-- doesn't run in the server they rejoin). Running it again replaces the earlier copy.
--
-- getgenv().BPSavedSettings = { Open, Close, Save, Load, Rename, Delete, List, Destroy }

local Env = (getgenv and getgenv()) or _G
if Env.BPSavedSettings and type(Env.BPSavedSettings.Destroy) == "function" then
	pcall(Env.BPSavedSettings.Destroy)
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

-- (loaded right after a rejoin by the 2021 / 2023 GUIs, the player may not be there yet)
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	pcall(function() Players:GetPropertyChangedSignal("LocalPlayer"):Wait() end)
	LocalPlayer = Players.LocalPlayer
end
if not LocalPlayer then
	warn("[Saved Settings] no LocalPlayer")
	return
end

------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------
local STORE_FILE = "BloxyParadoxSavedSettings.json"
local CONFIG_FILE = "BloxyParadoxConfig.json"
local ANIM_FILE = "BloxyAnimation2007Choice.json"
local TERRAIN_FILE = "BloxyTerrainChoice.json"
local TOPBAR_PICK_FILE = "BloxyTopbarPick.json"
local SETUP_FILE = "BloxySetupAnswers.json"
local SETTINGS_FILES = { CONFIG_FILE, ANIM_FILE, TERRAIN_FILE, TOPBAR_PICK_FILE, SETUP_FILE }
-- written when the saved settings had no such file (that step was never picked: the same as no file)
local WHEN_MISSING = {
	[ANIM_FILE] = '{"Animation2007":false}',
	[TERRAIN_FILE] = '{}',
	[TOPBAR_PICK_FILE] = '{}',
	[SETUP_FILE] = '{}',
}

local ICON_IMAGE = "rbxthumb://type=Asset&id=90842402386374&w=420&h=420"
-- "Paradox" in the name: the game GUI hider leaves it alone. Not "Bloxy": More guis takes the first GUI with
-- "Bloxy" in its name to be Bloxy's own. And no name here has "settings", "menu" or "chat" in it: the 2013 /
-- 2013 mobile GUIs (Bloxy's and ours) hide every button named like that, to get rid of the game's menu buttons.
local GUI_NAME = "ParadoxSaveDisk"
local BLOXY_GUI = "BloxyParadoxProject"
local MAX_NAME = 24
local CONFIRM_TIME = 3

-- where things go: the same places as Bloxy's hammer and its panel
local ICON_SIZE = 46
local ICON_HIDDEN = UDim2.new(1, 40, 0.5, 50)
local ICON_REST = UDim2.new(1, -38, 0.5, 50)
local ICON_OUT = UDim2.new(1, -46, 0.5, 50) -- (only a little over the open panel)
local PANEL_CLOSED = UDim2.new(1, 40, 0, -40)
local PANEL_OPEN = UDim2.new(0.65, -40, 0, -40)
local HAMMER_REST = UDim2.new(1, -40, 0.5, -40)

-- Bloxy's own boxes: pressing one makes Bloxy write its whole settings file, so these are pressed before
-- the saved files go back
local BLOXY_BOXES = {
	SkipCheckbox = "isSkipped",
	SkyboxCheckbox = "isSkyboxEnabled",
	WalkingSound2016Checkbox = "isWalkingSound2016Enabled",
}
local BLOXY_OWN_KEYS = { "isSkipped", "isSkyboxEnabled", "isWalkingSound2016Enabled", "dontShowHidePopup" }

-- Hammer stuff 1 and 2's boxes and the setting each one saves
local HAMMER_BOXES = {
	-- Hammer stuff 1
	Skybox2013Checkbox = "isSkybox2013Enabled",
	RemoveLightingCheckbox = "isRemoveLightingEnabled",
	SmoothPlasticCheckbox = "isSmoothPlasticEnabled",
	PlasticCheckbox = "isPlasticEnabled",
	Materials2009Checkbox = "is2009MaterialsEnabled",
	LegacyMaterialsCheckbox = "isLegacyMaterialsEnabled",
	NoShadowsCheckbox = "isNoShadowsEnabled",
	-- Hammer stuff 2
	RemoveProCheckbox = "isRemoveProEnabled",
	LegacyLightingCheckbox = "isLegacyLightingEnabled",
	Dynamic2013Checkbox = "is2013DynamicEnabled",
	OutlineCheckbox = "isOutlineEnabled",
	LensFlareCheckbox = "isLensFlareEnabled",
	Colors2012Checkbox = "is2012ColorsEnabled",
	Colors2006Checkbox = "is2006ColorsEnabled",
	Colors2005Checkbox = "is2005ColorsEnabled",
	OldAvatarCheckbox = "isOldAvatarEnabled",
	Avatar2006Checkbox = "is2006AvatarEnabled",
	ClassicFaceCheckbox = "isClassicFaceEnabled",
	OldCameraSoundCheckbox = "isOldCameraSoundEnabled",
	OldPartSoundsCheckbox = "isOldPartSoundsEnabled",
	Audio2015Checkbox = "is2015AudioEnabled",
	Audio2016Checkbox = "is2016AudioEnabled",
	HealthESPCheckbox = "isHealthESPEnabled",
	HideGameGuiCheckbox = "isHideGameGuiEnabled",
	RemoveLeaderboardCheckbox = "isRemoveLeaderboardEnabled",
	OldHealthBarCheckbox = "isOldHealthBarEnabled",
	NightSky2008Checkbox = "is2008NightSkyEnabled",
}
local OLD_DECAL_BUTTON, OLD_DECAL_KEY = "BPOldDecalButton", "isOldDecalEnabled"

------------------------------------------------------------
-- FILES
------------------------------------------------------------
-- the executor's own writefile (kept from the first run: later the global one is the hook below)
local rawWritefile = Env.BPRawWritefile or writefile
Env.BPRawWritefile = rawWritefile
local canRead = type(readfile) == "function" and type(isfile) == "function"
local canWrite = type(rawWritefile) == "function"

local function readText(file)
	if not canRead then return nil end
	local ok, text = pcall(function()
		if isfile(file) then return readfile(file) end
		return nil
	end)
	if ok and type(text) == "string" then return text end
	return nil
end

local function writeText(file, text)
	if not canWrite then return false end
	local ok = pcall(rawWritefile, file, text)
	return ok
end

local function decode(text)
	if type(text) ~= "string" or text == "" then return nil end
	local ok, value = pcall(function() return HttpService:JSONDecode(text) end)
	if ok then return value end
	return nil
end

local function encode(value)
	local ok, text = pcall(function() return HttpService:JSONEncode(value) end)
	if ok then return text end
	return nil
end

-- Bloxy writes its settings file with only its own settings in it, which dropped every other script's (the
-- hammer options, the explosion / physics picks...): those were then off at the next start. Writes to that
-- file by the other scripts now keep what the new text leaves out (nothing is ever removed on purpose).
if canWrite and canRead then
	local function keepingWritefile(path, text)
		if path == CONFIG_FILE and type(text) == "string" then
			local new, old = decode(text), decode(readText(CONFIG_FILE))
			if type(new) == "table" and type(old) == "table" then
				local added = false
				for key, value in pairs(old) do
					if new[key] == nil then new[key] = value added = true end
				end
				if added then text = encode(new) or text end
			end
		end
		return rawWritefile(path, text)
	end
	pcall(function() Env.writefile = keepingWritefile end)
end

local function indexOf(list, value)
	for i, v in ipairs(list) do
		if v == value then return i end
	end
	return nil
end

------------------------------------------------------------
-- THE SAVED SETTINGS
-- { order = { names, newest first }, profiles = { [name] = { savedAt, files = { [file] = text } } } }
------------------------------------------------------------
local store = { order = {}, profiles = {}, lastLoaded = nil }

local function readStore()
	store = { order = {}, profiles = {}, lastLoaded = nil }
	local data = decode(readText(STORE_FILE))
	if type(data) ~= "table" then return end
	if type(data.profiles) == "table" then
		for name, profile in pairs(data.profiles) do
			if type(name) == "string" and type(profile) == "table" and type(profile.files) == "table" then
				store.profiles[name] = profile
			end
		end
	end
	if type(data.order) == "table" then
		for _, name in ipairs(data.order) do
			if store.profiles[name] and not indexOf(store.order, name) then
				table.insert(store.order, name)
			end
		end
	end
	for name in pairs(store.profiles) do
		if not indexOf(store.order, name) then table.insert(store.order, name) end
	end
	if type(data.lastLoaded) == "string" and store.profiles[data.lastLoaded] then
		store.lastLoaded = data.lastLoaded
	end
	store.skipRepaired = data.skipRepaired == true or nil
end

local function writeStore()
	local text = encode({ version = 1, order = store.order, profiles = store.profiles, lastLoaded = store.lastLoaded,
		skipRepaired = store.skipRepaired })
	return text ~= nil and writeText(STORE_FILE, text)
end

-- a name as typed: no line breaks or spaces round it, at most MAX_NAME letters
local function cleanName(text)
	text = string.gsub(tostring(text or ""), "%c", "")
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	if utf8 and utf8.len(text) and utf8.len(text) > MAX_NAME then
		text = string.sub(text, 1, utf8.offset(text, MAX_NAME + 1) - 1)
	elseif #text > MAX_NAME * 4 then
		text = string.sub(text, 1, MAX_NAME)
	end
	return text
end

-- the saved name that is this one, whatever the capitals
local function findName(name)
	local lower = string.lower(name)
	for _, saved in ipairs(store.order) do
		if string.lower(saved) == lower then return saved end
	end
	return nil
end

local function freeName()
	local i = #store.order + 1
	while findName("settings " .. i) do i = i + 1 end
	return "settings " .. i
end

local function savedWhen(profile)
	local t = tonumber(profile.savedAt)
	if not t then return "" end
	local ok, d = pcall(os.date, "*t", t)
	if not ok or type(d) ~= "table" then return "" end
	local hour = d.hour % 12
	if hour == 0 then hour = 12 end
	return string.format("saved %d/%d %d:%02d %s", d.month, d.day, hour, d.min, d.hour < 12 and "AM" or "PM")
end

------------------------------------------------------------
-- PRESSING BUTTONS OF THE OTHER SCRIPTS (so they do what a tap does)
------------------------------------------------------------
local function press(button)
	if not button then return false end
	if type(firesignal) == "function" then
		if pcall(firesignal, button.MouseButton1Click) then return true end
	end
	if type(getconnections) == "function" then
		local ok = pcall(function()
			local list = getconnections(button.MouseButton1Click)
			if #list == 0 then error("no connections") end
			for _, c in ipairs(list) do
				if c.Fire then
					c:Fire()
				elseif c.Function then
					c.Function()
				end
			end
		end)
		if ok then return true end
	end
	return false
end

local function boxIsOn(box)
	return string.find(box.Text or "", "✓", 1, true) ~= nil
end

local function oldDecalIsOn(button)
	return string.find(button.Text or "", ": ON", 1, true) ~= nil
end

-- "Colors2012Checkbox" -> "Colors2012", for the console
local function shortName(boxName)
	return (string.gsub(boxName, "Checkbox$", ""))
end

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local connections = {}
local gui, icon, panel, nameBox, saveButton, list, emptyLabel
local clickSound
local bloxyGui, hammer, hammerPanel, hammerClicker
local isOpen = false
local hammerOpen = false -- Bloxy's hammer panel (counted from its taps)
local applying = false   -- a load is going on
local destroyed = false
local refreshList
local replaying = false  -- the setup is being answered with saved answers
local tookOver = false   -- the player tapped an answer themselves meanwhile: the rest is theirs

local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(connections, c)
	return c
end

local function playClick()
	if clickSound then pcall(function() clickSound:Stop() clickSound:Play() end) end
end

local function tween(obj, goal, time)
	local t = TweenService:Create(obj, TweenInfo.new(time or 0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

------------------------------------------------------------
-- SAVE / LOAD / RENAME / DELETE
------------------------------------------------------------
local function captureFiles()
	local files = {}
	for _, file in ipairs(SETTINGS_FILES) do
		local text = readText(file)
		if text then files[file] = text end
	end
	return files
end

local function putFilesBack(files)
	local ok = true
	for _, file in ipairs(SETTINGS_FILES) do
		local text = files[file] or WHEN_MISSING[file]
		if text and not writeText(file, text) then ok = false end
	end
	return ok
end

local function saveSettings(name)
	if not (canRead and canWrite) then
		warn("[Saved Settings] this executor can't read or write files, so nothing can be saved")
		return false, "no files"
	end
	name = cleanName(name)
	if name == "" then name = freeName() end
	local files = captureFiles()
	if not files[CONFIG_FILE] then
		warn("[Saved Settings] nothing to save yet: Bloxy hasn't saved any settings (finish the setup first)")
		return false, "nothing"
	end
	local existing = findName(name)
	if existing and existing ~= name then
		-- the same name with other capitals: it takes the new spelling, in the same place
		store.profiles[existing] = nil
		store.order[indexOf(store.order, existing)] = name
		if store.lastLoaded == existing then store.lastLoaded = name end
	elseif not existing then
		table.insert(store.order, 1, name)
	end
	store.profiles[name] = { savedAt = os.time(), files = files }
	if not writeStore() then
		warn("[Saved Settings] couldn't write " .. STORE_FILE)
		return false, "write"
	end
	print(string.format("[Saved Settings] %s \"%s\"", existing and "replaced" or "saved", name))
	return true, name
end

local function renameSettings(old, new)
	new = cleanName(new)
	if not store.profiles[old] then return false, "missing" end
	if new == "" then return false, "empty" end
	if new == old then return true, new end
	local taken = findName(new)
	if taken and taken ~= old then
		print("[Saved Settings] there is already one called \"" .. taken .. "\"")
		return false, "taken"
	end
	store.profiles[new] = store.profiles[old]
	store.profiles[old] = nil
	store.order[indexOf(store.order, old)] = new
	if store.lastLoaded == old then store.lastLoaded = new end
	if not writeStore() then
		warn("[Saved Settings] couldn't write " .. STORE_FILE)
		return false, "write"
	end
	print(string.format("[Saved Settings] renamed \"%s\" to \"%s\"", old, new))
	return true, new
end

local function deleteSettings(name)
	if not store.profiles[name] then return false end
	store.profiles[name] = nil
	table.remove(store.order, indexOf(store.order, name))
	if store.lastLoaded == name then store.lastLoaded = nil end
	writeStore()
	print("[Saved Settings] deleted \"" .. name .. "\"")
	return true
end

local function findIn(parent, name)
	if not parent then return nil end
	local found = parent:FindFirstChild(name, true)
	if found and found:IsA("GuiButton") then return found end
	return nil
end

------------------------------------------------------------
-- THE SETUP: ITS ANSWERS RECORDED, AND ANSWERED WITH SAVED ONES
-- Each question of Bloxy's setup (and of the addons' steps in it) is a frame in Bloxy's GUI with a title
-- ("Which topbar do you prefer?", "Choose your explosion style:") and answer buttons. Every answer tapped is
-- recorded (title and button), so a saved file can answer the same questions again later, the same way,
-- with whichever Bloxy and More guis are running.
------------------------------------------------------------
local recording = { answers = {} }

-- the setup question a button is in (a frame right inside Bloxy's GUI, not its hammer panel), or nil
local function questionFrameOf(obj)
	if not bloxyGui then return nil end
	local frame = obj
	while frame and frame.Parent ~= bloxyGui do frame = frame.Parent end
	if not frame or not frame:IsA("Frame") or frame == hammerPanel or frame.Name == "HammerBigPanel" then
		return nil
	end
	return frame
end

-- a question's title: its longest label. A setup question is one with Bloxy's "SETUP" picture on it (all of
-- Bloxy's, and the addons' steps drawn on them: some titles have no "?" or ":", like "Choose your mouse
-- cursor" and "choose your forcefield"), or one whose title reads like a question
local function questionTitle(frame)
	local best, bestZ = nil, -math.huge
	for _, d in ipairs(frame:GetDescendants()) do
		if d:IsA("TextLabel") and d.Visible and type(d.Text) == "string" and string.find(d.Text, "%a")
		   and not d:FindFirstAncestorWhichIsA("GuiButton") then
			-- the one drawn on top (an addon's question laid over Bloxy's box), else the longest
			-- (labels inside buttons, like the physics dropdown's "▼", and ones without letters aren't titles)
			local z = d.ZIndex or 1
			if z > bestZ or (z == bestZ and #d.Text > #best) then
				best, bestZ = d.Text, z
			end
		end
	end
	if not best or best == "" then return nil end
	if frame:FindFirstChild("HeaderImage", true) or string.find(best, "?", 1, true) or string.find(best, ":", 1, true) then
		return best
	end
	return nil
end

local function isAnswerText(text)
	return type(text) == "string" and text ~= "" and not string.find(text, "▼", 1, true)
		and not string.find(text, "▲", 1, true)
end

local function saveRecording()
	local text = encode({ answers = recording.answers, at = os.time() })
	if text then writeText(SETUP_FILE, text) end
end

-- What Bloxy's own saves leave out of its settings file is put back (also done by the writefile hook above,
-- this is for executors where Bloxy doesn't go through it): the latest value seen for every setting.
local knownSettings = {}
local function keepOtherSettings()
	local now = decode(readText(CONFIG_FILE))
	if type(now) ~= "table" then return end
	local added = false
	for key, value in pairs(knownSettings) do
		if now[key] == nil then now[key] = value added = true end
	end
	for key, value in pairs(now) do knownSettings[key] = value end
	if added then
		local text = encode(now)
		if text then writeText(CONFIG_FILE, text) end
	end
end

local hookedAnswers = setmetatable({}, { __mode = "k" })
local function hookAnswerButton(btn)
	if hookedAnswers[btn] or not btn:IsA("TextButton") then return end
	if hammerPanel and btn:IsDescendantOf(hammerPanel) then return end
	hookedAnswers[btn] = true
	-- (a real tap presses down first; the saved answers are given without that)
	connect(btn.MouseButton1Down, function()
		if replaying then tookOver = true end
	end)
	-- Recorded from a real tap (Activated, or MouseButton1Up: whichever comes first, once), not from
	-- MouseButton1Click: More guis calls the first MouseButton1Click connection of Bloxy's buttons to press
	-- them, and clears those of its own copies, so that one is left alone.
	local lastAt = -1
	local function recordTap()
		if replaying then return end
		local now = os.clock()
		if now - lastAt < 0.3 then return end
		lastAt = now
		local frame = questionFrameOf(btn)
		local title = frame and questionTitle(frame)
		local text = btn.Text
		if not title or not isAnswerText(text) then return end
		-- the topbar question starts the setup: a new set of answers
		local last = recording.answers[#recording.answers]
		if string.find(string.lower(title), "topbar", 1, true) and (not last or last.q ~= title) then
			recording = { answers = {} }
		end
		table.insert(recording.answers, { q = title, a = text })
		saveRecording()
		task.delay(0.5, keepOtherSettings)
	end
	connect(btn.Activated, recordTap)
	connect(btn.MouseButton1Up, recordTap)
end

local function setupOnScreen()
	if not bloxyGui then return false end
	for _, frame in ipairs(bloxyGui:GetChildren()) do
		if frame:IsA("Frame") and frame.Visible and frame ~= hammerPanel and questionTitle(frame) then return true end
	end
	return false
end

-- (an answer that means "open the dropdown": the button with a "▼" label in it, as in the physics step)
local DROPDOWN = "\1dropdown"

local function answerButton(frame, text)
	if text == DROPDOWN then
		for _, d in ipairs(frame:GetDescendants()) do
			if d:IsA("TextButton") and d.Visible then
				for _, c in ipairs(d:GetChildren()) do
					if c:IsA("TextLabel") and c.Text == "▼" then return d end
				end
			end
		end
		return nil
	end
	local lower = string.lower(text)
	for _, d in ipairs(frame:GetDescendants()) do
		if d:IsA("TextButton") and d.Visible and string.lower(d.Text or "") == lower then return d end
	end
	return nil
end

-- The answers to give: of the taps on one question only the last pick before its last tap ("2019", then
-- "2013 mobile", then "confirm" gives "2013 mobile", "confirm"), so a change of mind isn't pressed again.
local function finalAnswers(answers)
	local out = {}
	local i = 1
	while i <= #answers do
		local q = answers[i].q
		local j = i
		while j + 1 <= #answers and answers[j + 1].q == q do j = j + 1 end
		if j > i then table.insert(out, answers[j - 1]) end
		table.insert(out, answers[j])
		i = j + 1
	end
	return out
end

-- A file saved before answers were kept: at least its topbar (More guis' pick, else Bloxy's)
local TOPBAR_QUESTION = "Which topbar do you prefer?"
local TOPBAR_TEXTS = { ["2013mobile"] = "2013 mobile", ["2023_WIP"] = "2023 new", ["2023_FFlags"] = "2024(fflags)",
	["2016_Adv"] = "2016(no chat)", ["2016_Simp"] = "2016", ["2015early"] = "2015 early" }
local function topbarAnswers(files)
	local pick = decode(files[TOPBAR_PICK_FILE])
	local text = type(pick) == "table" and type(pick.Pick) == "string" and pick.Pick or nil
	if not text then
		local config = decode(files[CONFIG_FILE])
		local id = type(config) == "table" and type(config.Choices) == "table" and config.Choices.Topbar or nil
		text = type(id) == "string" and (TOPBAR_TEXTS[id] or id) or nil
	end
	if not text or text == "" or text == "none" then return nil end
	return { { q = TOPBAR_QUESTION, a = TOPBAR_TEXTS[text] or text }, { q = TOPBAR_QUESTION, a = "confirm" } }
end

-- The answer to a question from the saved settings (for a question without a recorded answer: a file saved
-- before answers were kept, or a question the recording missed). Bloxy's questions, and the addons' steps
-- whose pick is saved. nil when it isn't known.
local function fromSettings(title, files)
	local t = string.lower(title or "")
	local config = decode(files[CONFIG_FILE])
	config = type(config) == "table" and config or {}
	local choices = type(config.Choices) == "table" and config.Choices or {}
	local function yesNo(v)
		if v == true then return { "Yes" } elseif v == false then return { "No" } end
		return nil
	end
	local function pick(map, v)
		local text = v ~= nil and map[v] or nil
		return text and { text } or nil
	end
	local function has(word) return string.find(t, word, 1, true) ~= nil end
	if has("topbar") then
		local a = topbarAnswers(files)
		return a and { a[1].a, "confirm" } or nil
	end
	if has("explosion") then
		-- (the Explosion addon saves it as "explosionStyle")
		local style = config.explosionStyle or config.ExplosionStyle
		return style and { tostring(style) } or nil
	end
	if has("terrain") then
		local terrain = decode(files[TERRAIN_FILE])
		local v = type(terrain) == "table" and terrain.Terrain or nil
		return v and { tostring(v) } or nil
	end
	if has("physics") and has("camera") then
		local choice = config.physicsCameraChoice
		if choice == "camera" then return { "Old Camera" } end
		if choice == "none" then return { "None" } end
		if choice == "physics" or choice == "both" then
			-- the dropdown shows the type picked last time, which may not be this one: open it, pick, then press
			local label = (config.physicsVariant == "2006") and "2006" or "Old"
			return { DROPDOWN, label .. " Physics", choice == "both" and "Both" or (label .. " Physics") }
		end
		return nil
	end
	if has("safe chat") then return yesNo(choices.SafeChat) end
	if has("backpack") then return pick({ none = "No", simple = "Simple 2008 remake", advanced = "Advanced" }, choices.Backpack) end
	if has("animations") then
		local anim = decode(files[ANIM_FILE])
		if type(anim) == "table" and anim.Animation2007 == true then return { "2007" } end
		return pick({ R6_2008 = "2008", R6_2006 = "2006", R6_2014 = "2014", normal = "Normal",
			R15_2008 = "2008 FE", R15_2014 = "2014 FE", R15_Old = "Old R15" }, choices.Anims)
	end
	if has("old sounds") then return yesNo(choices.Sounds) end
	if has("cursor") or has("mouse") then
		return pick({ ["2008_full"] = "full 2008 mouse", ["2008_aspects"] = "2008 mouse aspects", ["2016"] = "2016 mouse",
			normal = "normal" }, choices.Mouse)
	end
	if has("textures") then
		return pick({ ["2008"] = "2008 textures", ["2012"] = "2012 textures", ["2016"] = "2016 textures", normal = "Normal" }, choices.Textures)
	end
	if has("mobile jump") then return yesNo(choices.MobileJump) end
	if has("2006 body") then return yesNo(choices.Body2006) end
	if has("old materials") then return yesNo(choices.Materials) end
	if has("forcefield") then return pick({ ["2008"] = "2008(r6 only)", ["2012"] = "2012", normal = "normal" }, choices.Forcefield) end
	if has("old particles") and not has("which") then return yesNo(choices.Particles) end
	if has("emotes") then return yesNo(choices.Emotes) end
	return nil
end

-- A question with no saved answer anywhere (the Particles addon's 2010 / 2013, which it doesn't save; a step
-- added later): its neutral answer ("Normal", "No", "None"...), else its first one, so the setup goes on.
local NEUTRAL_ANSWERS = { "normal", "no", "none", "default", "off" }
local function neutralAnswer(frame)
	local buttons = {}
	for _, d in ipairs(frame:GetDescendants()) do
		if d:IsA("TextButton") and d.Visible and isAnswerText(d.Text) then table.insert(buttons, d) end
	end
	for _, word in ipairs(NEUTRAL_ANSWERS) do
		for _, b in ipairs(buttons) do
			if string.lower(b.Text) == word then return b.Text end
		end
	end
	return buttons[1] and buttons[1].Text or nil
end

-- the question on screen now (and its title)
local function currentQuestion()
	if not bloxyGui then return nil end
	for _, frame in ipairs(bloxyGui:GetChildren()) do
		if frame:IsA("Frame") and frame.Visible and frame ~= hammerPanel then
			local title = questionTitle(frame)
			if title then return frame, title end
		end
	end
	return nil
end

-- Answer the setup: each question on screen gets its recorded answer (in the order they were given), else the
-- one in the saved settings. It stops when a question has no saved answer at all (it is left to the player,
-- and named in the console), when the player taps an answer themselves, or when no question shows for a while.
local function answerSetup(answers, files, name, firstWait)
	if replaying then return false end
	replaying = true
	tookOver = false
	local queues = {}
	for _, step in ipairs(finalAnswers(answers or {})) do
		queues[step.q] = queues[step.q] or {}
		table.insert(queues[step.q], step.a)
	end
	local fromFile = {}
	task.spawn(function()
		print(string.format("[Saved Settings] answering the setup with \"%s\"", name))
		local given, fromSettingsCount, guessed = 0, 0, {}
		local idleSince = os.clock()
		local lastFrame, lastTitle, lastAt = nil, nil, -math.huge
		local stopReason = nil
		local pressesOn = setmetatable({}, { __mode = "k" }) -- frame -> { [title] = presses }
		local lookedAgain = 0
		while not destroyed do
			if tookOver then stopReason = "you answered the setup yourself: the rest of it is up to you" break end
			local frame, title = currentQuestion()
			if not frame then
				if os.clock() - idleSince > ((given == 0) and (firstWait or 20) or 12) then break end
				task.wait(0.25)
			elseif frame == lastFrame and title == lastTitle and os.clock() - lastAt < 1.2 then
				task.wait(0.2) -- (just answered: it is on its way out)
			else
				-- its answers: recorded ones first, then (once) the saved settings'. The physics step from the
				-- saved settings first: its recorded taps depend on what its dropdown showed back then.
				local lowerTitle = string.lower(title)
				if not fromFile[title] and string.find(lowerTitle, "physics", 1, true) and string.find(lowerTitle, "camera", 1, true) then
					local list = fromSettings(title, files)
					if list then
						fromFile[title] = true
						queues[title] = list
						fromSettingsCount = fromSettingsCount + #list
					end
				end
				if (not queues[title] or #queues[title] == 0) and not fromFile[title] then
					fromFile[title] = true
					local list = fromSettings(title, files)
					if list then
						queues[title] = list
						fromSettingsCount = fromSettingsCount + #list
					end
				end
				local queue = queues[title]
				local isTopbar = string.find(string.lower(title), "topbar", 1, true) ~= nil
				local btn, text = nil, nil
				while queue and #queue > 0 and not btn and not tookOver do
					local candidate = queue[1]
					-- More guis may still be adding its topbars to the list: those get longer
					local deadline = os.clock() + ((isTopbar and candidate ~= "confirm") and 40 or 3)
					repeat
						btn = answerButton(frame, candidate)
						if not btn then task.wait(0.25) end
					until btn or os.clock() > deadline or tookOver or not frame.Parent
					table.remove(queue, 1)
					if btn then
						text = candidate
					elseif isTopbar and candidate ~= "confirm" then
						stopReason = "\"" .. candidate .. "\" isn't in the topbar list here: the rest of the setup is up to you"
						break
					end
				end
				if stopReason then break end
				if not btn and not tookOver then
					if isTopbar then
						-- (a GUI isn't guessed)
						stopReason = "no saved topbar: the rest of the setup is up to you"
						break
					end
					text = neutralAnswer(frame)
					btn = text and answerButton(frame, text) or nil
					if btn then
						table.insert(guessed, title .. " -> " .. text)
					else
						stopReason = "no answer found for \"" .. title .. "\": the rest of the setup is up to you"
						break
					end
				end
				if tookOver then stopReason = "you answered the setup yourself: the rest of it is up to you" break end
				task.wait(0.35) -- (it has just slid in)
				if tookOver then stopReason = "you answered the setup yourself: the rest of it is up to you" break end
				-- still the same question and button (an addon may have just turned it into its own step, like the
				-- Particles addon does with "old particles"): else looked at again
				local same = (text == DROPDOWN) and (answerButton(frame, DROPDOWN) == btn)
					or string.lower(btn.Text or "") == string.lower(text)
				if questionTitle(frame) == title and btn.Parent and btn.Visible and same then
					pressesOn[frame] = pressesOn[frame] or {}
					pressesOn[frame][title] = (pressesOn[frame][title] or 0) + 1
					if pressesOn[frame][title] > 3 then
						stopReason = "\"" .. title .. "\" doesn't go on when answered: the rest of the setup is up to you"
						break
					end
					if press(btn) then given = given + 1 end
					lastFrame, lastTitle, lastAt = frame, title, os.clock()
				else
					-- (its answer is put back for when it comes again)
					queues[title] = queues[title] or {}
					table.insert(queues[title], 1, text)
					lookedAgain = lookedAgain + 1
					if lookedAgain > 40 then
						stopReason = "the setup keeps changing under it: the rest of the setup is up to you"
						break
					end
				end
				idleSince = os.clock()
			end
		end
		replaying = false
		task.delay(1, keepOtherSettings)
		if stopReason then print("[Saved Settings] " .. stopReason) end
		if #guessed > 0 then
			print("[Saved Settings] no saved answer, so the neutral one: " .. table.concat(guessed, "; ")
				.. " (save the file again after a setup to keep these)")
		end
		print(string.format("[Saved Settings] setup answered with \"%s\": %d answer%s given%s", name, given,
			given == 1 and "" or "s", fromSettingsCount > 0 and (" (some from its saved settings)") or ""))
	end)
	return true
end

local function savedAnswers(files)
	local data = decode(files[SETUP_FILE])
	local answers = type(data) == "table" and data.answers or nil
	if type(answers) == "table" and #answers > 0 then return answers end
	return nil
end

local function loadSettings(name)
	local profile = store.profiles[name]
	if not profile then return false, "missing" end
	if not canWrite then
		warn("[Saved Settings] this executor can't write files, so nothing can be loaded")
		return false, "no files"
	end
	applying = true
	local files = {}
	for file, text in pairs(profile.files) do files[file] = text end
	local answers = savedAnswers(files) -- (nil for a file saved before answers were kept: its settings answer)
	-- "skip setup" stays as it is now (the player's own choice, not part of a file: a file with it on made
	-- Bloxy skip the setup and load its plain year, 2013 for 2013 mobile)
	local config = decode(files[CONFIG_FILE])
	if type(config) ~= "table" then config = {} end
	local current = decode(readText(CONFIG_FILE))
	local skipNow = type(current) == "table" and current.isSkipped == true
	if config.isSkipped ~= skipNow then
		config.isSkipped = skipNow
		files[CONFIG_FILE] = encode(config) or files[CONFIG_FILE]
	end
	-- what is kept from now on is exactly this file (not settings it doesn't have, from before)
	table.clear(knownSettings)
	for key, value in pairs(config) do knownSettings[key] = value end
	local wanted = function(key) return config[key] == true end
	local turnedOn, turnedOff, failed = {}, {}, {}
	local function pressBox(box, boxName)
		local on = boxIsOn(box)
		if press(box) then
			table.insert(on and turnedOff or turnedOn, shortName(boxName))
		else
			table.insert(failed, shortName(boxName))
		end
		task.wait(0.05)
	end

	local ok = pcall(function()
		-- 1. Bloxy's own boxes (each press writes Bloxy's whole file, so first)
		for boxName, key in pairs(BLOXY_BOXES) do
			local box = findIn(hammerPanel, boxName)
			if box and boxIsOn(box) ~= wanted(key) then pressBox(box, boxName) end
		end
		-- 2. the files
		putFilesBack(files)
		-- 3. the hammer's options: the ones to turn off first, then the ones to turn on (some untick each other)
		local turnOn = {}
		for boxName, key in pairs(HAMMER_BOXES) do
			local box = findIn(hammerPanel, boxName)
			if box then
				local on = boxIsOn(box)
				if on and not wanted(key) then
					pressBox(box, boxName)
				elseif not on and wanted(key) then
					table.insert(turnOn, { box = box, name = boxName })
				end
			end
		end
		for _, item in ipairs(turnOn) do
			if not boxIsOn(item.box) then pressBox(item.box, item.name) end
		end
		local decal = findIn(hammerPanel, OLD_DECAL_BUTTON)
		if decal and oldDecalIsOn(decal) ~= wanted(OLD_DECAL_KEY) then pressBox(decal, "OldDecalRendering") end
		-- 4. the files once more, exactly as loaded (the presses wrote their own copies on the way)
		task.wait(0.3)
		putFilesBack(files)
	end)
	applying = false

	store.lastLoaded = name
	writeStore()
	if not ok then
		warn("[Saved Settings] something went wrong while loading \"" .. name .. "\"; its files were put back")
		putFilesBack(files)
	end
	-- the report
	if not hammerPanel then
		print("[Saved Settings] loaded \"" .. name .. "\": Bloxy's hammer panel isn't there, so its options are used at the next start")
	elseif #turnedOn + #turnedOff + #failed == 0 then
		print("[Saved Settings] loaded \"" .. name .. "\": the hammer's options were already like that")
	else
		print(string.format("[Saved Settings] loaded \"%s\": turned on: %s; turned off: %s%s", name,
			#turnedOn > 0 and table.concat(turnedOn, ", ") or "none", #turnedOff > 0 and table.concat(turnedOff, ", ") or "none",
			#failed > 0 and ("; couldn't press (used at the next start): " .. table.concat(failed, ", ")) or ""))
	end
	-- the setup (GUI, safe chat, explosion, ...): answered now if it is on screen, or as soon as it shows
	local onScreen = setupOnScreen()
	if not onScreen then
		print("[Saved Settings] the setup isn't on screen: it is answered if it shows in the next 20 seconds"
			.. " (load right after running the script, while the setup is showing)")
	end
	local setupNow = answerSetup(answers, files, name, onScreen and 5 or 20)
	return true, setupNow
end

------------------------------------------------------------
-- BLOXY'S HAMMER
------------------------------------------------------------
-- Bloxy writes only its own settings when one of its boxes is tapped, with the setup choices it read when it
-- started. That would undo loaded setup choices (and drops the other scripts' settings), so what was in the
-- file just before the tap is put back round Bloxy's own settings.
local function guardBloxyBox(box)
	local before
	connect(box.MouseButton1Down, function()
		if not applying then before = decode(readText(CONFIG_FILE)) end
	end)
	connect(box.MouseButton1Click, function()
		if applying then return end
		local snapshot = before
		before = nil
		if type(snapshot) ~= "table" then return end
		task.delay(0.1, function()
			local now = decode(readText(CONFIG_FILE))
			if type(now) ~= "table" then return end
			for key, value in pairs(snapshot) do
				if now[key] == nil then now[key] = value end
			end
			now.Choices = snapshot.Choices
			local text = encode(now)
			if text then writeText(CONFIG_FILE, text) end
			for key, value in pairs(now) do knownSettings[key] = value end
		end)
	end)
end

local closePanel
local hideEverything

local function hookBloxy(sg)
	if bloxyGui == sg then return end
	bloxyGui = sg
	hammerOpen = false
	hammer = sg:FindFirstChild("DecorativeHammer", true)
	hammerPanel = sg:FindFirstChild("HammerBigPanel", true)
	hammerClicker = hammer and hammer:FindFirstChild("HammerClicker", true)
	-- the same screen room as Bloxy's GUI, so the icon lines up under the hammer
	if gui then
		for _, prop in ipairs({ "IgnoreGuiInset", "ScreenInsets", "ClipToDeviceSafeArea", "SafeAreaCompatibility" }) do
			pcall(function() gui[prop] = sg[prop] end)
		end
	end
	if hammerClicker then
		connect(hammerClicker.MouseButton1Click, function()
			hammerOpen = not hammerOpen
			if hammerOpen and isOpen then closePanel() end
		end)
	end
	if hammerPanel then
		for boxName in pairs(BLOXY_BOXES) do
			local box = findIn(hammerPanel, boxName)
			if box then guardBloxyBox(box) end
		end
	end
	-- the setup's answer buttons (recorded when tapped)
	for _, d in ipairs(sg:GetDescendants()) do
		if d:IsA("TextButton") then hookAnswerButton(d) end
	end
	connect(sg.DescendantAdded, function(d)
		if d:IsA("TextButton") then task.defer(hookAnswerButton, d) end
	end)
	keepOtherSettings()
	if hammer then
		-- "hide hammer ui" removes the hammer: this goes too (running the script again brings both back)
		connect(hammer.AncestryChanged, function(child, parent)
			if child == hammer and parent == nil and not destroyed then hideEverything() end
		end)
	end
end

local function closeHammer()
	if not hammerOpen then return end
	if hammerClicker and press(hammerClicker) then return end -- (the tap is counted above)
	hammerOpen = false
	if hammer then tween(hammer, { Position = HAMMER_REST, Rotation = -20 }) end
	if hammerPanel then tween(hammerPanel, { Position = PANEL_CLOSED }) end
end

------------------------------------------------------------
-- THE PANEL
------------------------------------------------------------
local fontBold = Font.new("rbxasset://fonts/families/Arial.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
local WHITE = Color3.fromRGB(255, 255, 255)
local GREY = Color3.fromRGB(220, 220, 220)

local function outline(obj, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or WHITE
	stroke.Thickness = thickness or 1.2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	stroke.Parent = obj
	return stroke
end

local function label(parent, name, text, size, pos, textSize)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.FontFace = fontBold
	l.TextSize = textSize
	l.TextColor3 = WHITE
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Text = text
	l.ZIndex = 97
	l.Parent = parent
	return l
end

local BUTTON_COLORS = {
	green = { Color3.fromRGB(30, 140, 30), Color3.fromRGB(80, 220, 80) },
	grey = { Color3.fromRGB(70, 70, 70), Color3.fromRGB(160, 160, 160) },
	red = { Color3.fromRGB(200, 40, 40), Color3.fromRGB(255, 80, 80) },
}

local function button(parent, name, text, kind, size, pos)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = size
	b.Position = pos or UDim2.new(0, 0, 0, 0)
	b.BorderSizePixel = 0
	b.FontFace = fontBold
	b.TextSize = 12
	b.TextColor3 = WHITE
	b.Text = text
	b.AutoButtonColor = true
	b.ZIndex = 98
	b.Parent = parent
	local stroke = outline(b)
	local function paint(k)
		local c = BUTTON_COLORS[k] or BUTTON_COLORS.grey
		b.BackgroundColor3 = c[1]
		stroke.Color = c[2]
	end
	paint(kind)
	return b, paint
end

local function textBox(parent, name, size, pos, placeholder)
	local box = Instance.new("TextBox")
	box.Name = name
	box.Size = size
	box.Position = pos
	box.BackgroundColor3 = GREY
	box.BackgroundTransparency = 0.5
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.FontFace = fontBold
	box.TextSize = 14
	box.TextColor3 = WHITE
	box.PlaceholderText = placeholder or ""
	box.PlaceholderColor3 = Color3.fromRGB(245, 245, 245)
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Text = ""
	box.ZIndex = 98
	box.Parent = parent
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = box
	outline(box)
	return box
end

-- a button that needs a second tap within a few seconds ("sure?")
local function twoTap(b, paint, idleText, idleKind, askText, onConfirm)
	local askedAt = nil
	connect(b.MouseButton1Click, function()
		playClick()
		local now = os.clock()
		if askedAt and now - askedAt <= CONFIRM_TIME then
			askedAt = nil
			b.Text = idleText
			paint(idleKind)
			onConfirm()
			return
		end
		askedAt = now
		b.Text = askText
		paint("red")
		task.delay(CONFIRM_TIME, function()
			if askedAt == now and b.Parent then
				askedAt = nil
				b.Text = idleText
				paint(idleKind)
			end
		end)
	end)
end

local function flash(b, text)
	local was = b.Text
	b.Text = text
	task.delay(1.2, function()
		if b.Parent and b.Text == text then b.Text = was end
	end)
end

local function makeRow(name, order)
	local profile = store.profiles[name]
	local loaded = store.lastLoaded == name

	local row = Instance.new("Frame")
	row.Name = "Saved_" .. order
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -10, 0, 60)
	row.BackgroundColor3 = WHITE
	row.BackgroundTransparency = 0.85
	row.BorderSizePixel = 0
	row.ZIndex = 96
	row.Parent = list
	outline(row, loaded and Color3.fromRGB(120, 255, 120) or WHITE, loaded and 1.5 or 1)

	local nameLabel = label(row, "NameLabel", name, UDim2.new(1, -16, 0, 18), UDim2.new(0, 8, 0, 4), 15)
	if loaded then nameLabel.TextColor3 = Color3.fromRGB(150, 255, 150) end
	local whenLabel = label(row, "WhenLabel", savedWhen(profile) .. (loaded and "  •  loaded" or ""),
		UDim2.new(1, -16, 0, 12), UDim2.new(0, 8, 0, 22), 11)
	whenLabel.TextTransparency = 0.15

	-- the box the new name is typed in (where the name is, only while renaming)
	local renameBox = textBox(row, "RenameBox", UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 4), "new name")
	renameBox.Visible = false

	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.BackgroundTransparency = 1
	buttons.Size = UDim2.new(1, -16, 0, 18)
	buttons.Position = UDim2.new(0, 8, 0, 37)
	buttons.ZIndex = 97
	buttons.Parent = row
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = buttons

	local third = UDim2.new(1 / 3, -4, 1, 0)
	local loadBtn = button(buttons, "LoadButton", "load", "green", third)
	loadBtn.LayoutOrder = 1
	local renameBtn = button(buttons, "RenameButton", "rename", "grey", third)
	renameBtn.LayoutOrder = 2
	local deleteBtn, paintDelete = button(buttons, "DeleteButton", "delete", "red", third)
	deleteBtn.LayoutOrder = 3

	local renaming = false
	local function setRenaming(on)
		renaming = on
		nameLabel.Visible = not on
		whenLabel.Visible = not on
		renameBox.Visible = on
		loadBtn.Text = on and "ok" or "load"
		renameBtn.Text = on and "cancel" or "rename"
		deleteBtn.Visible = not on
		if on then
			renameBox.Text = name
			pcall(function() renameBox:CaptureFocus() end)
		end
	end
	local function finishRename()
		local ok, result = renameSettings(name, renameBox.Text)
		if ok then
			refreshList()
		elseif result == "taken" then
			flash(loadBtn, "taken")
		elseif result == "empty" then
			flash(loadBtn, "name?")
		else
			setRenaming(false)
		end
	end

	connect(loadBtn.MouseButton1Click, function()
		playClick()
		if renaming then
			finishRename()
			return
		end
		if applying or replaying then return end
		loadBtn.Text = "loading…"
		task.spawn(function()
			local ok = loadSettings(name)
			if ok then
				refreshList()
			elseif loadBtn.Parent then
				loadBtn.Text = "load"
				flash(loadBtn, "can't")
			end
		end)
	end)
	connect(renameBtn.MouseButton1Click, function()
		playClick()
		setRenaming(not renaming)
	end)
	connect(renameBox.FocusLost, function(enterPressed)
		if renaming and enterPressed then finishRename() end
	end)
	twoTap(deleteBtn, paintDelete, "delete", "red", "sure?", function()
		deleteSettings(name)
		refreshList()
	end)
	return row
end

refreshList = function()
	if not list then return end
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	for i, name in ipairs(store.order) do
		makeRow(name, i)
	end
	emptyLabel.Visible = #store.order == 0
end

local function buildGui()
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 30)
	if not playerGui then
		warn("[Saved Settings] PlayerGui wasn't found")
		return false
	end
	local old = playerGui:FindFirstChild(GUI_NAME)
	if old then old:Destroy() end

	gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.ResetOnSpawn = false
	-- above the era GUIs (999999999): the 2013 GUIs' leaderboard was over the panel and took its taps
	gui.DisplayOrder = 2000000000
	pcall(function() gui.ClipToDeviceSafeArea = false end)

	clickSound = Instance.new("Sound")
	clickSound.Name = "BPSaveDiskClick"
	clickSound.SoundId = "rbxassetid://12221967"
	clickSound.Volume = 0.6
	clickSound.Parent = SoundService

	-- the icon: a floppy disk under the hammer, half out of the screen like it
	icon = Instance.new("ImageButton")
	icon.Name = "SaveDiskIcon"
	icon.BackgroundTransparency = 1
	icon.Image = ICON_IMAGE
	icon.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
	icon.Position = ICON_HIDDEN
	icon.Rotation = -12
	icon.ZIndex = 100
	icon.Parent = gui

	panel = Instance.new("Frame")
	panel.Name = "SaveDiskPanel"
	panel.Size = UDim2.new(0.35, 0, 0.88, 60)
	panel.Position = PANEL_CLOSED
	panel.BackgroundColor3 = GREY
	panel.BackgroundTransparency = 0.5
	panel.BorderSizePixel = 0
	panel.ZIndex = 95
	panel.Parent = gui
	outline(panel, WHITE, 1.5)

	label(panel, "Title", "saved settings", UDim2.new(1, -30, 0, 22), UDim2.new(0, 15, 0, 44), 18)

	nameBox = textBox(panel, "NameBox", UDim2.new(1, -106, 0, 26), UDim2.new(0, 15, 0, 72), "name (optional)")
	local paintSave
	saveButton, paintSave = button(panel, "SaveButton", "save", "green", UDim2.new(0, 70, 0, 26), UDim2.new(1, -85, 0, 72))
	saveButton.TextSize = 14

	list = Instance.new("ScrollingFrame")
	list.Name = "SavedList"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.new(0, 15, 0, 108)
	list.Size = UDim2.new(1, -24, 1, -128)
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ScrollBarThickness = 5
	list.ZIndex = 96
	list.Parent = panel
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list
	local listPad = Instance.new("UIPadding")
	listPad.PaddingTop = UDim.new(0, 2)
	listPad.PaddingLeft = UDim.new(0, 1)
	listPad.Parent = list

	emptyLabel = label(list, "EmptyLabel", "nothing saved yet: type a name (or don't) and press save",
		UDim2.new(1, -10, 0, 40), UDim2.new(0, 0, 0, 0), 13)
	emptyLabel.TextWrapped = true
	emptyLabel.TextTruncate = Enum.TextTruncate.None
	emptyLabel.TextYAlignment = Enum.TextYAlignment.Top
	emptyLabel.LayoutOrder = 0

	-- save: a name that is already there is replaced after a second tap
	local askedAt, askedName = nil, nil
	connect(saveButton.MouseButton1Click, function()
		playClick()
		local name = cleanName(nameBox.Text)
		local taken = name ~= "" and findName(name)
		local now = os.clock()
		if taken and not (askedAt and askedName == taken and now - askedAt <= CONFIRM_TIME) then
			askedAt, askedName = now, taken
			saveButton.Text = "replace?"
			paintSave("red")
			task.delay(CONFIRM_TIME, function()
				if askedAt == now and saveButton.Parent then
					askedAt = nil
					saveButton.Text = "save"
					paintSave("green")
				end
			end)
			return
		end
		askedAt, askedName = nil, nil
		saveButton.Text = "save"
		paintSave("green")
		local ok, result = saveSettings(name)
		if ok then
			nameBox.Text = ""
			refreshList()
			flash(saveButton, "saved ✓")
		else
			flash(saveButton, result == "nothing" and "nothing yet" or "can't")
		end
	end)

	connect(icon.MouseButton1Click, function()
		playClick()
		if isOpen then closePanel() else
			isOpen = true
			readStore() -- (another copy of the script, or the game, may have changed it)
			refreshList()
			closeHammer()
			tween(icon, { Position = ICON_OUT, Rotation = 0 })
			tween(panel, { Position = PANEL_OPEN })
		end
	end)

	-- (nothing here ever hides the icon: if another script does, it is shown again)
	connect(icon:GetPropertyChangedSignal("Visible"), function()
		if not icon.Visible then icon.Visible = true end
	end)

	gui.Parent = playerGui
	task.defer(function()
		if icon and icon.Parent then tween(icon, { Position = ICON_REST }, 1.0) end
	end)
	return true
end

closePanel = function()
	isOpen = false
	if nameBox then pcall(function() nameBox:ReleaseFocus() end) end
	if icon then tween(icon, { Position = ICON_REST, Rotation = -12 }) end
	if panel then tween(panel, { Position = PANEL_CLOSED }) end
end

local function destroy()
	destroyed = true
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	connections = {}
	if gui then pcall(function() gui:Destroy() end) end
	if clickSound then pcall(function() clickSound:Destroy() end) end
	gui, icon, panel, list, clickSound = nil, nil, nil, nil, nil
	if Env.BPSavedSettings and Env.BPSavedSettings.Destroy == destroy then Env.BPSavedSettings = nil end
end

hideEverything = function()
	isOpen = false
	if not (icon and panel) then destroy() return end
	tween(icon, { Position = UDim2.new(1.3, 0, 0.5, 50) }, 0.6)
	local t = tween(panel, { Position = UDim2.new(1.3, 0, 0, -40) }, 0.6)
	t.Completed:Connect(function() destroy() end)
end

------------------------------------------------------------
-- START
------------------------------------------------------------
readStore()
if not buildGui() then return end
refreshList()

Env.BPSavedSettings = {
	Open = function() if not isOpen and icon then press(icon) end end,
	Close = function() if isOpen then closePanel() end end,
	Save = function(name) local ok, r = saveSettings(name) if ok then refreshList() end return ok, r end,
	Load = function(name) local ok, a = loadSettings(name) refreshList() return ok, a end,
	Rename = function(old, new) local ok, r = renameSettings(old, new) refreshList() return ok, r end,
	Delete = function(name) local ok = deleteSettings(name) refreshList() return ok end,
	List = function()
		local names = {}
		for i, name in ipairs(store.order) do names[i] = name end
		return names
	end,
	Destroy = destroy,
}

-- Bloxy's GUI: now, and again whenever Bloxy is run again. Its hammer and panel are made right after its GUI.
local function hookWhenReady(sg)
	if destroyed or bloxyGui == sg then return end
	sg:WaitForChild("DecorativeHammer", 15)
	sg:WaitForChild("HammerBigPanel", 15)
	task.wait(0.5) -- (the boxes on the panel)
	if sg.Parent and not destroyed then hookBloxy(sg) end
end

task.spawn(function()
	local playerGui = gui and gui.Parent
	if not playerGui then return end
	connect(playerGui.ChildAdded, function(child)
		if child.Name == BLOXY_GUI then task.spawn(hookWhenReady, child) end
	end)
	local sg = playerGui:FindFirstChild(BLOXY_GUI) or playerGui:WaitForChild(BLOXY_GUI, 120)
	if sg then hookWhenReady(sg) end
end)

-- Older versions of this panel turned "skip setup" on when loading, so Bloxy skipped the setup and loaded
-- its plain year (2013 for 2013 mobile) at every start. Turned off again, once.
do
	local raw = decode(readText(STORE_FILE))
	local config = decode(readText(CONFIG_FILE))
	if type(raw) == "table" and raw.lastLoaded and not raw.skipRepaired and type(config) == "table" then
		if config.isSkipped == true then
			config.isSkipped = false
			local text = encode(config)
			if text then writeText(CONFIG_FILE, text) end
			print("[Saved Settings] \"skip setup\" had been turned on by an older version of this panel: it is off"
				.. " again, so the setup shows the next time you run the script")
			-- Bloxy's own box too, so it doesn't write it back on
			task.spawn(function()
				local t0 = os.clock()
				while not hammerPanel and os.clock() - t0 < 60 and not destroyed do task.wait(1) end
				local box = findIn(hammerPanel, "SkipCheckbox")
				if box and boxIsOn(box) then
					applying = true
					press(box)
					task.wait(0.2)
					applying = false
					keepOtherSettings()
				end
			end)
		end
		store.skipRepaired = true
		writeStore()
	end
end

print(string.format("[Saved Settings] ready: %d saved%s", #store.order,
	(canRead and canWrite) and "" or " (this executor can't read or write files: saving is off)"))
