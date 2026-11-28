--[[ SAVED SETTINGS (Addtion-Scripts) ]]
-- A panel like Bloxy's hammer one, opened by the floppy disk under the hammer (the user's pixel floppy, this repo's
-- assets/floppy.png; decal 137454100118380 until it is there): save what is set now under a name, and load, rename
-- or delete what was saved. They are kept in BloxyParadoxSavedSettings.json, so they are still there after leaving
-- the game or running the script again.
-- The plus over the hammer (assets/plus.png) opens the PRESETS: a year in one tap (2005 to 2024, see PRESETS).
-- The plus, the hammer and the floppy stand on one straight line down the right of the screen (see THE ICON COLUMN).
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
--   * the hammer's options change straight away, all at once (their boxes are pressed one right after the other,
--     so each option turns itself on or off as usual), and then Paradox closes (this panel and Bloxy's hammer
--     panel) so the setup can be answered with nothing in the way
--   * the animations step on the other kind of avatar than the one it was saved on (R6 / R15): the same era
--     there: 2007 and 2008 (R6) -> 2008 FE (R15), 2014 -> 2014 FE, and back (2008 FE -> 2008, 2014 FE -> 2014,
--     Modern R6 -> Normal, R6's own modern animations); the rest as it was picked
--   * "skip setup" is left as it is (older versions turned it on, so Bloxy skipped the setup and loaded its
--     plain year: that is undone once)
--   * Bloxy writes its settings file with only its own settings in it, which dropped the other scripts' (the
--     hammer options were off at the next start); what it leaves out is kept now.
-- Nothing is loaded by itself at start.
--
-- The loader loads it, and so do the 2021 / 2023 old / 2023 new GUIs after the rejoin they do (the loader
-- doesn't run in the server they rejoin). Running it again replaces the earlier copy.
--
-- getgenv().BPSavedSettings = { Open, Close, Save, Load, Rename, Delete, List, Presets, LoadPreset, OpenPresets,
-- SetSetupAnswers, Destroy }

local Env = (getgenv and getgenv()) or _G
if Env.BPSavedSettings and type(Env.BPSavedSettings.Destroy) == "function" then
	pcall(Env.BPSavedSettings.Destroy)
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

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
local MODERN_R6_FILE = "BloxyModernR6Choice.json"
local TERRAIN_FILE = "BloxyTerrainChoice.json"
local TOPBAR_PICK_FILE = "BloxyTopbarPick.json"
local SETUP_FILE = "BloxySetupAnswers.json"
local SETTINGS_FILES = { CONFIG_FILE, ANIM_FILE, MODERN_R6_FILE, TERRAIN_FILE, TOPBAR_PICK_FILE, SETUP_FILE }
-- written when the saved settings had no such file (that step was never picked: the same as no file)
local WHEN_MISSING = {
	[ANIM_FILE] = '{"Animation2007":false}',
	[MODERN_R6_FILE] = '{"ModernR6":false}',
	[TERRAIN_FILE] = '{}',
	[TOPBAR_PICK_FILE] = '{}',
	[SETUP_FILE] = '{}',
}

local ICON_IMAGE = "rbxthumb://type=Asset&id=137454100118380&w=420&h=420"
-- "Paradox" in the name: the game GUI hider leaves it alone. Not "Bloxy": More guis takes the first GUI with
-- "Bloxy" in its name to be Bloxy's own. And no name here has "settings", "menu" or "chat" in it: the 2013 /
-- 2013 mobile GUIs (Bloxy's and ours) hide every button named like that, to get rid of the game's menu buttons.
local GUI_NAME = "ParadoxSaveDisk"
local BLOXY_GUI = "BloxyParadoxProject"
local MAX_NAME = 24
local CONFIRM_TIME = 3

-- THE ICON COLUMN on the right of the screen: the presets plus, Bloxy's hammer and the floppy disk, one above the
-- other on one straight line, evenly spaced, the plus and the floppy upright (the hammer keeps its own tilt). The
-- hammer is moved onto the line too: Bloxy leaves it with the middle of its picture on the very edge of the screen
-- (half of it off a screen without a notch), and the floppy stood further in and tilted, a bump in the line.
local ICON_SIZE = 46
local HALF_ICON = 23      -- (half of ICON_SIZE)
local COLUMN_X = -26      -- the line, from the right edge
local COLUMN_Y = -6       -- the hammer's picture is 6 above the middle of its 80 x 80 image (tilted -20)
local ICON_GAP = 70       -- from the hammer's middle to the plus's and the floppy's
local function columnSpot(dy, dx)
	return UDim2.new(1, COLUMN_X - HALF_ICON + (dx or 0), 0.5, COLUMN_Y + dy - HALF_ICON)
end
local ICON_REST = columnSpot(ICON_GAP)          -- the floppy: under the hammer
local ICON_OUT = columnSpot(ICON_GAP, -8)       -- (its panel open: a little over it)
local ICON_HIDDEN = UDim2.new(1, 40, 0.5, COLUMN_Y + ICON_GAP - HALF_ICON)
local PLUS_REST = columnSpot(-ICON_GAP)         -- the presets plus: over the hammer
local PLUS_OUT = columnSpot(-ICON_GAP, -8)
local PLUS_HIDDEN = UDim2.new(1, 40, 0.5, COLUMN_Y - ICON_GAP - HALF_ICON)
local PANEL_CLOSED = UDim2.new(1, 40, 0, -40)
local PANEL_OPEN = UDim2.new(0.65, -40, 0, -40)
-- Bloxy's hammer (80 x 80): resting with its middle on the line; open, 30 further in, as Bloxy pops it out
local HAMMER_REST = UDim2.new(1, COLUMN_X - 40, 0.5, -40)
local HAMMER_OPEN = UDim2.new(1, COLUMN_X - 70, 0.5, -40)
-- the icons' pictures (this repo's assets, kept in the executor's folder and shown with getcustomasset); the floppy
-- has the old decal until then (or if the executor can't), the plus a drawn "+"
local ASSET_URL = "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/assets/"
local FLOPPY_FILE, PLUS_FILE = "floppy.png", "plus.png"
local ASSET_VERSION = "v1"

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
	Skybox2009Checkbox = "isSkybox2009Enabled",
	Skybox2013Checkbox = "isSkybox2013Enabled",
	RemoveLightingCheckbox = "isRemoveLightingEnabled",
	SmoothPlasticCheckbox = "isSmoothPlasticEnabled",
	PlasticCheckbox = "isPlasticEnabled",
	Materials2009Checkbox = "is2009MaterialsEnabled",
	Materials2016Checkbox = "is2016MaterialsEnabled",
	Materials2005Checkbox = "is2005MaterialsEnabled",
	Materials2006Checkbox = "is2006MaterialsEnabled",
	Materials2008Checkbox = "is2008MaterialsEnabled",
	Materials2010Checkbox = "is2010MaterialsEnabled",
	LegacyMaterialsCheckbox = "isLegacyMaterialsEnabled",
	NoShadowsCheckbox = "isNoShadowsEnabled",
	-- Hammer stuff 2
	RemoveProCheckbox = "isRemoveProEnabled",
	RemoveEffectsCheckbox = "isRemoveEffectsEnabled",
	Lighting2006Checkbox = "is2006LightingEnabled",
	LegacyLightingCheckbox = "isLegacyLightingEnabled",
	Dynamic2013Checkbox = "is2013DynamicEnabled",
	OutlineCheckbox = "isOutlineEnabled",
	LensFlareCheckbox = "isLensFlareEnabled",
	Colors2012Checkbox = "is2012ColorsEnabled",
	Colors2006Checkbox = "is2006ColorsEnabled",
	Colors2005Checkbox = "is2005ColorsEnabled",
	OldAvatarCheckbox = "isOldAvatarEnabled",
	Avatar2006Checkbox = "is2006AvatarEnabled",
	Players2008Checkbox = "is2008PlayersEnabled",
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
	Shapes2006Checkbox = "is2006ShapesEnabled",
	UGCRemoverCheckbox = "isUGCRemoverEnabled",
	AllPlayersCheckbox = "isAllPlayersEnabled",
	FpsCapCheckbox = "isFpsCapEnabled",
	HideMobileControlsCheckbox = "isHideMobileControlsEnabled",
	MobileControlsCheckbox = "isMobileControlsEnabled",
	OldThumbstickCheckbox = "isOldThumbstickEnabled",
	IWLegacyLightingCheckbox = "isIWLegacyLightingEnabled",
	-- the lighting era dropdown
	IWLighting2014Checkbox = "isIWLighting2014Enabled",
	IWLighting2015Checkbox = "isIWLighting2015Enabled",
	IWLighting2016Checkbox = "isIWLighting2016Enabled",
	IWLighting2017Checkbox = "isIWLighting2017Enabled",
	IWLighting2019Checkbox = "isIWLighting2019Enabled",
	IWLighting2020Checkbox = "isIWLighting2020Enabled",
	OldMoonCheckbox = "isOldMoonEnabled",
	Shadows2014Checkbox = "is2014ShadowsEnabled",
	SlipperyWalkCheckbox = "isSlipperyWalkEnabled",
	ChatBarCheckbox = "isChatBarEnabled",
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

-- After a press that loads something (a GUI, an addon), the game stutters for a moment: the next press waits
-- until it runs smoothly again (a few smooth frames in a row; at most maxWait seconds), so the loads don't
-- pile up into one long freeze (or a crash).
local function settle(maxWait, frames)
	local deadline = os.clock() + (maxWait or 3)
	local smooth = 0
	while os.clock() < deadline and smooth < (frames or 5) do
		local ok, dt = pcall(function() return RunService.Heartbeat:Wait() end)
		if not ok then task.wait(0.1) break end
		if dt < 1 / 15 then smooth = smooth + 1 else smooth = 0 end
	end
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
local plusIcon, presetsPanel, presetsOpen = nil, nil, false
local closePresets -- (set further down)
local clickSound
local bloxyGui, hammer, hammerPanel, hammerClicker
local isOpen = false
local hammerOpen = false -- Bloxy's hammer panel (counted from its taps)
local applying = false   -- a load is going on
local closeParadox       -- closes this panel and Bloxy's hammer panel (set further down, once they exist)
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
local CAMERA_DROPDOWN = "\1dropdown camera" -- the physics step's camera dropdown (the other one is the physics one)

local function answerButton(frame, text)
	if text == DROPDOWN or text == CAMERA_DROPDOWN then
		local want = (text == CAMERA_DROPDOWN) and "CameraDropdown" or "PhysicsDropdown"
		for _, d in ipairs(frame:GetDescendants()) do
			if d:IsA("TextButton") and d.Visible and d.Name == want then return d end
		end
		if text == CAMERA_DROPDOWN then return nil end
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

-- THE ANIMATIONS STEP is "Choose your animations: R6 Mode" or "...: R15 Mode", after the avatar. A pick made on the
-- other kind of avatar is given as the same era on this one; the rest as it was picked.
local ANIM_ON_R15 = { ["2007"] = "2008 FE", ["2008"] = "2008 FE", ["2014"] = "2014 FE" }
local ANIM_ON_R6 = { ["2008 fe"] = "2008", ["2014 fe"] = "2014", ["modern r6"] = "Normal", ["old r15"] = "Normal" }
local function animRig(title)
	local t = string.lower(title or "")
	if not string.find(t, "choose your animations", 1, true) then return nil end
	if string.find(t, "r15", 1, true) then return "r15" end
	if string.find(t, "r6", 1, true) then return "r6" end
	return nil
end
local function animForRig(answer, rig)
	if type(answer) ~= "string" then return answer end
	local map = (rig == "r15") and ANIM_ON_R15 or ANIM_ON_R6
	return map[string.lower(answer)] or answer
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
		if choice == "none" then return { "None" } end
		-- the dropdowns show the types picked last time, which may not be these: open each, pick, then press
		-- (the physics saved as "2007" is labelled "2008" now)
		local label = ({ ["2006"] = "2006", ["2007"] = "2008", ["2008"] = "2008" })[config.physicsVariant] or "Old"
		local cam = ({ ["2018"] = "2018", ["2007"] = "2007" })[config.cameraVariant] or "2013"
		if choice == "camera" then return { CAMERA_DROPDOWN, cam .. " Camera", cam .. " Camera" } end
		if choice == "physics" then return { DROPDOWN, label .. " Physics", label .. " Physics" } end
		if choice == "both" then return { DROPDOWN, label .. " Physics", CAMERA_DROPDOWN, cam .. " Camera", "Both" } end
		return nil
	end
	if has("safe chat") then return yesNo(choices.SafeChat) end
	if has("backpack") then return pick({ none = "No", simple = "Simple 2008 remake", advanced = "Advanced" }, choices.Backpack) end
	if has("animations") then
		-- (2007 is on the R6 step, Modern R6 on the R15 one; picked on the other kind of avatar, the same era
		-- on this one: see THE ANIMATIONS STEP above)
		local rig = has("r15") and "r15" or "r6"
		local anim = decode(files[ANIM_FILE])
		local modernR6 = decode(files[MODERN_R6_FILE])
		local saved2007 = type(anim) == "table" and anim.Animation2007 == true
		local savedModernR6 = type(modernR6) == "table" and modernR6.ModernR6 == true
		if rig == "r15" and savedModernR6 then return { "Modern R6" } end
		if rig == "r6" and saved2007 then return { "2007" } end
		local picked = pick({ R6_2008 = "2008", R6_2006 = "2006", R6_2014 = "2014", normal = "Normal",
			R15_2008 = "2008 FE", R15_2014 = "2014 FE", R15_Old = "Old R15" }, choices.Anims)
		-- (2007 / Modern R6 move Bloxy's own pick on as Normal: picked on the other avatar, the same era here)
		if picked and picked[1] == "Normal" then
			if rig == "r15" and saved2007 then return { "2008 FE" } end
			if rig == "r6" and savedModernR6 then return { "Normal" } end
		end
		if picked then return { animForRig(picked[1], rig) } end
		return nil
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

-- the question on screen now (and its title); skip(frame, title) leaves out ones already answered
local function currentQuestion(skip)
	if not bloxyGui then return nil end
	for _, frame in ipairs(bloxyGui:GetChildren()) do
		if frame:IsA("Frame") and frame.Visible and frame ~= hammerPanel then
			local title = questionTitle(frame)
			if title and not (skip and skip(frame, title)) then return frame, title end
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
	-- A question given its last answer is never pressed again. (It used to be looked at again after 1.2
	-- seconds: with the game busy loading what was just picked, the question was often still sliding out
	-- then, and got a second answer, its neutral one: Bloxy then went on to its next step twice, and two
	-- setups showed.)
	local answered = setmetatable({}, { __mode = "k" }) -- frame -> { [title] = true }
	local function isAnswered(frame, title)
		local done = answered[frame]
		return done ~= nil and done[title] == true and not (queues[title] and #queues[title] > 0)
	end
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
			local frame, title = currentQuestion(isAnswered)
			if not frame then
				if os.clock() - idleSince > ((given == 0) and (firstWait or 20) or 12) then break end
				task.wait(0.25)
			elseif frame == lastFrame and title == lastTitle and os.clock() - lastAt < 1.2 then
				task.wait(0.1) -- (just answered: it is on its way out)
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
				-- the animations step recorded on the other kind of avatar (R6 / R15): its answers, the same era here
				local rig = animRig(title)
				if rig and (not queues[title] or #queues[title] == 0) then
					for otherTitle, otherQueue in pairs(queues) do
						local otherRig = animRig(otherTitle)
						if otherRig and otherRig ~= rig and #otherQueue > 0 then
							local mapped = {}
							for _, a in ipairs(otherQueue) do table.insert(mapped, animForRig(a, rig)) end
							queues[title] = mapped
							queues[otherTitle] = {}
							print("[Saved Settings] animations picked on " .. string.upper(otherRig) .. ", given as "
								.. table.concat(mapped, ", ") .. " on " .. string.upper(rig))
							break
						end
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
				task.wait(0.2) -- (it has just slid in; was 0.35: the presets go faster, the user asked)
				if tookOver then stopReason = "you answered the setup yourself: the rest of it is up to you" break end
				-- still the same question and button (an addon may have just turned it into its own step, like the
				-- Particles addon does with "old particles"): else looked at again
				local same = (text == DROPDOWN or text == CAMERA_DROPDOWN) and (answerButton(frame, text) == btn)
					or string.lower(btn.Text or "") == string.lower(text)
				if questionTitle(frame) == title and btn.Parent and btn.Visible and same then
					pressesOn[frame] = pressesOn[frame] or {}
					pressesOn[frame][title] = (pressesOn[frame][title] or 0) + 1
					if pressesOn[frame][title] > 6 then -- (the physics step can take 5: two dropdowns, two picks, Both)
						stopReason = "\"" .. title .. "\" doesn't go on when answered: the rest of the setup is up to you"
						break
					end
					if press(btn) then
						given = given + 1
						-- (the GUI picked, as the loader reads it: its loading screen, bubbles, purchase prompt and the
						-- rest follow this pick, not whatever year Bloxy's config held before)
						if isTopbar and text ~= "confirm" and text ~= DROPDOWN and text ~= CAMERA_DROPDOWN then
							Env.BloxyTopbarPick = text
						end
						-- (the setup's < > remember it as this question's answer: ">" gives it again)
						local wizard = Env.BPWizard
						if type(wizard) == "table" and type(wizard.noteTap) == "function" then pcall(wizard.noteTap, btn) end
					end
					lastFrame, lastTitle, lastAt = frame, title, os.clock()
					if not queues[title] or #queues[title] == 0 then
						answered[frame] = answered[frame] or {}
						answered[frame][title] = true
					end
					-- (what was picked may be loading: the next press waits for the game to run smoothly. With the setup's
					-- < > on, nothing loads until the last question, so only a short breath: the presets go faster)
					local w = Env.BPWizard
					local deferring = type(w) == "table" and type(w.deferring) == "function" and w.deferring()
					if deferring then settle(0.4, 3) else settle(2) end
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

-- puts a set of settings files in place and applies them (a saved file, or a preset); remember: it becomes the
-- "loaded" one in the list
local function loadFiles(sourceFiles, name, remember)
	if not canWrite then
		warn("[Saved Settings] this executor can't write files, so nothing can be loaded")
		return false, "no files"
	end
	-- one load at a time: a second one while the first is still putting its files in place or answering the setup
	-- mixed the two files (its files written over the first's while the first's answers were still being given)
	if applying or replaying then
		print("[Saved Settings] \"" .. tostring(name) .. "\" not loaded: another load is still going; try again when it's done")
		return false, "busy"
	end
	applying = true
	-- a GUI of More guis' picked before (waiting for its Confirm) mustn't come back instead of this file's
	local genvLoad = (getgenv and getgenv()) or _G
	genvLoad.BP_PendingTopbar = nil
	genvLoad.BP_2023Variant = nil
	local files = {}
	for file, text in pairs(sourceFiles) do files[file] = text end
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
	-- (all at once: each box is pressed right after the one before; each option starts its own loading)
	local function pressBox(box, boxName)
		local on = boxIsOn(box)
		if press(box) then
			table.insert(on and turnedOff or turnedOn, shortName(boxName))
		else
			table.insert(failed, shortName(boxName))
		end
	end

	local function applyHammer()
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
			if not boxIsOn(item.box) then
				pressBox(item.box, item.name)
				-- (one at a time: each option starts its own loading, and all of them at once, right as the GUI itself
				-- loads after the last question, froze the game for seconds: the 2013 loading screen's squares crawled at
				-- 5 frames a second in the user's recording. The next one waits until the game runs smoothly again.)
				settle(0.5, 3)
			end
		end
		local decal = findIn(hammerPanel, OLD_DECAL_BUTTON)
		if decal and oldDecalIsOn(decal) ~= wanted(OLD_DECAL_KEY) then pressBox(decal, "OldDecalRendering") end
		-- 4. Hammer stuff 2's FPS cap (a number box, not a tick box)
		local genv = (getgenv and getgenv()) or _G
		if type(genv.BPHammer2SetFpsCap) == "function" then
			pcall(genv.BPHammer2SetFpsCap, tonumber(config.fpsCap) or 0)
		end
		-- 5. the files once more, exactly as loaded (the presses wrote their own copies on the way)
		task.wait(0.3)
		putFilesBack(files)
	end
	-- With the setup's < > on (Setup Back Forward.lua) nothing loads until right after the last question, the hammer's
	-- options included. The files are put in place now; the boxes are pressed then.
	local wizard = Env.BPWizard
	local held = false
	if hammerPanel and type(wizard) == "table" and type(wizard.deferring) == "function" and wizard.deferring()
		and type(wizard.later) == "function" then
		putFilesBack(files)
		held = wizard.later("saved settings: the hammer's options", function()
			applying = true
			local done = pcall(applyHammer)
			applying = false
			if not done then putFilesBack(files) end
			print(string.format("[Saved Settings] \"%s\" after the setup: turned on: %s; turned off: %s", name,
				#turnedOn > 0 and table.concat(turnedOn, ", ") or "none", #turnedOff > 0 and table.concat(turnedOff, ", ") or "none"))
		end, true)
	end
	local ok = true
	if not held then ok = pcall(applyHammer) end
	applying = false

	if remember then
		store.lastLoaded = name
		writeStore()
	end
	if not ok then
		warn("[Saved Settings] something went wrong while loading \"" .. name .. "\"; its files were put back")
		putFilesBack(files)
	end
	-- the report
	if held then
		print("[Saved Settings] loaded \"" .. name .. "\": its hammer options wait with the setup's answers: they load right after the last question")
	elseif not hammerPanel then
		print("[Saved Settings] loaded \"" .. name .. "\": Bloxy's hammer panel isn't there, so its options are used at the next start")
	elseif #turnedOn + #turnedOff + #failed == 0 then
		print("[Saved Settings] loaded \"" .. name .. "\": the hammer's options were already like that")
	else
		print(string.format("[Saved Settings] loaded \"%s\": turned on: %s; turned off: %s%s", name,
			#turnedOn > 0 and table.concat(turnedOn, ", ") or "none", #turnedOff > 0 and table.concat(turnedOff, ", ") or "none",
			#failed > 0 and ("; couldn't press (used at the next start): " .. table.concat(failed, ", ")) or ""))
	end
	-- Paradox closes (this panel and Bloxy's hammer panel): the setup is answered with nothing in the way
	if closeParadox then pcall(closeParadox) end
	-- the setup (GUI, safe chat, explosion, ...): answered now if it is on screen, or as soon as it shows
	local onScreen = setupOnScreen()
	if not onScreen then
		print("[Saved Settings] the setup isn't on screen: it is answered if it shows in the next 20 seconds"
			.. " (load right after running the script, while the setup is showing)")
	end
	local setupNow = answerSetup(answers, files, name, onScreen and 5 or 20)
	return true, setupNow
end

local function loadSettings(name)
	local profile = store.profiles[name]
	if not profile then return false, "missing" end
	return loadFiles(profile.files, name, true)
end

------------------------------------------------------------
-- PRESETS (the plus over the hammer): a year in one tap
------------------------------------------------------------
-- Each one picks the year's GUI in the setup (the topbar question) and sets its era's look, from the user's run-through
-- of each preset: anything before 2013 with the mobile controls hidden; the year's plastic (2005, 2006 / 2007, 2008,
-- 2010 for 2010 - 2013); the era's sky (2008 up to 2008, 2009 for 2010 - 2012, 2013 for 2013 - 2014); 2006-07 lighting
-- for 2006 / 2007; iw legacy lighting with the year's lighting era for 2014 and early 2015 (with legacy lighting for
-- 2013 - early 2014), and the year's lighting era from 2016 on; 2006 without the old safe chat; 2006 with the 2006 avatar, 2007 (on
-- the 2008 GUI) with the old players (old avatar) and 2008 with the 2008 players, the UGC remover on in all of them but 2006, old decal rendering on for 2006 and 2007 (off for the others). Each preset sets every material, sky and lighting option, on or off, so
-- one picked after another leaves nothing of the one before. The other setup answers stay as last given, and the
-- hammer's other options as they are.
local SAFE_CHAT_QUESTION, FORCEFIELD_QUESTION = "Do you want the old safe chat?", "choose your forcefield"
-- The physics / camera step ("Old physics or old camera?"): a preset that says what it wants there doesn't keep the one
-- given last time (2006 physics picked once came back with the 2016 preset). From early 2015 to 2017 only the 2018
-- camera (no physics, nothing from before the year); from 2019 on neither. The other years keep the last one given.
local PHYSICS_QUESTION = "Old physics or old camera?"
local PHYSICS_CAMERA = {
	camera2018 = { config = { physicsCameraChoice = "camera", cameraVariant = "2018" },
		answers = { CAMERA_DROPDOWN, "2018 Camera", "2018 Camera" } },
	camera2013 = { config = { physicsCameraChoice = "camera", cameraVariant = "2013" },
		answers = { CAMERA_DROPDOWN, "2013 Camera", "2013 Camera" } },
	none = { config = { physicsCameraChoice = "none" }, answers = { "None" } },
	-- (the 2006 and 2007 presets, from the user's videos: the 2006 physics and the 2007 camera, "Both")
	both2006 = { config = { physicsCameraChoice = "both", physicsVariant = "2006", cameraVariant = "2007" },
		answers = { DROPDOWN, "2006 Physics", CAMERA_DROPDOWN, "2007 Camera", "Both" } },
	-- (the 2008 preset, from the user's video: the physics dropdown put on 2008, the camera one left on 2007, then "Both".
	-- The 2008 physics is saved as "2007": see the label map at the physics / camera answer)
	both2008 = { config = { physicsCameraChoice = "both", physicsVariant = "2007", cameraVariant = "2007" },
		answers = { DROPDOWN, "2008 Physics", CAMERA_DROPDOWN, "2007 Camera", "Both" } },
	-- (the 2011 and 2012 presets: the physics dropdown on Old, the camera one on 2007, then "Both"; the 2013 one: the 2013 camera)
	bothOld2007 = { config = { physicsCameraChoice = "both", physicsVariant = "old", cameraVariant = "2007" },
		answers = { DROPDOWN, "Old Physics", CAMERA_DROPDOWN, "2007 Camera", "Both" } },
	bothOld2013 = { config = { physicsCameraChoice = "both", physicsVariant = "old", cameraVariant = "2013" },
		answers = { DROPDOWN, "Old Physics", CAMERA_DROPDOWN, "2013 Camera", "Both" } },
}
local MATERIAL_KEYS = { "isSmoothPlasticEnabled", "isPlasticEnabled", "is2005MaterialsEnabled", "is2006MaterialsEnabled",
	"is2008MaterialsEnabled", "is2009MaterialsEnabled", "is2010MaterialsEnabled", "is2016MaterialsEnabled",
	"isLegacyMaterialsEnabled" }
local SKY_KEYS = { "isSkyboxEnabled", "isSkybox2009Enabled", "isSkybox2013Enabled", "is2008NightSkyEnabled" }
local LIGHTING_KEYS = { "is2006LightingEnabled", "isLegacyLightingEnabled", "isIWLegacyLightingEnabled",
	"isIWLighting2014Enabled", "isIWLighting2015Enabled", "isIWLighting2016Enabled", "isIWLighting2017Enabled",
	"isIWLighting2019Enabled", "isIWLighting2020Enabled" }
-- (the options the user's run-throughs of 2005 - 2008 show on or off: every preset says them, on or off, so one picked
-- after another leaves nothing of the one before)
local ERA_LOOK_KEYS = { "isRemoveLightingEnabled", "isNoShadowsEnabled", "isOldMoonEnabled", "isLensFlareEnabled",
	"isHideGameGuiEnabled", "isOldCameraSoundEnabled" }
-- (the options the 2005 - 2013 videos show on or off, set by those presets only: the years after them are not recorded yet)
local OLD_ERA_KEYS = { "isRemoveProEnabled", "isRemoveLeaderboardEnabled", "isChatBarEnabled", "isMobileControlsEnabled",
	"isOldThumbstickEnabled", "isOldHealthBarEnabled", "is2012ColorsEnabled", "is2006ColorsEnabled", "is2005ColorsEnabled" }
-- (2011 on: every option the videos of 2011 - 2024 show, on or off)
local RESET_ALL_KEYS = { "isRemoveProEnabled", "isRemoveLeaderboardEnabled", "isChatBarEnabled", "isMobileControlsEnabled",
	"isOldThumbstickEnabled", "isOldHealthBarEnabled", "is2012ColorsEnabled", "is2006ColorsEnabled", "is2005ColorsEnabled",
	"isOutlineEnabled", "is2013DynamicEnabled", "is2014ShadowsEnabled", "isSlipperyWalkEnabled", "is2015AudioEnabled",
	"is2016AudioEnabled", "isOldPartSoundsEnabled", "isClassicFaceEnabled", "isHealthESPEnabled", "isOldDecalEnabled",
	"isUGCRemoverEnabled", "isAllPlayersEnabled", "isOldAvatarEnabled", "is2006AvatarEnabled", "is2008PlayersEnabled" }
local function era(t)
	local config = {}
	for _, key in ipairs(ERA_LOOK_KEYS) do config[key] = false end
	if t.resetOld then
		for _, key in ipairs(OLD_ERA_KEYS) do config[key] = false end
	end
	if t.resetAll then
		for _, key in ipairs(RESET_ALL_KEYS) do config[key] = false end
	end
	for _, key in ipairs(MATERIAL_KEYS) do config[key] = false end
	for _, key in ipairs(SKY_KEYS) do config[key] = false end
	for _, key in ipairs(LIGHTING_KEYS) do config[key] = false end
	if t.material then config[t.material] = true end
	for _, key in ipairs(t.sky or {}) do config[key] = true end
	for _, key in ipairs(t.lighting or {}) do config[key] = true end
	config.isHideMobileControlsEnabled = t.hideControls == true
	for key, value in pairs(t.extra or {}) do config[key] = value end
	local answers = t.answers
	local step = t.physicsCamera and PHYSICS_CAMERA[t.physicsCamera]
	if step then
		for key, value in pairs(step.config) do config[key] = value end
		answers = {}
		for _, a in ipairs(t.answers or {}) do table.insert(answers, a) end
		for _, a in ipairs(step.answers) do table.insert(answers, { q = PHYSICS_QUESTION, a = a }) end
	end
	return { name = t.name, topbar = t.topbar, note = t.note, config = config, answers = answers, choices = t.choices }
end
local SKY_2008, SKY_2009, SKY_2013 = { "isSkyboxEnabled" }, { "isSkybox2009Enabled" }, { "isSkybox2013Enabled" }
-- the setup's questions (their titles as the setup shows them) and the answers the user's videos of 2005 - 2010 give them
local SQ = {
	safeChat = SAFE_CHAT_QUESTION, backpack = "Do you want a custom backpack?", animations = "Choose your animations: R6 Mode",
	sounds = "Do you want old sounds?", mouse = "Choose your mouse cursor", textures = "What textures do you want to use?",
	mobileJump = "Do you want the old mobile jump button?", body2006 = "Do you want the 2006 body?",
	forcefield = FORCEFIELD_QUESTION, explosion = "Choose your explosion style:", terrain = "What terrain do you want?",
	oldParticles = "Do you want old particles?", particles = "Which old particles?", emotes = "Do you want better emotes?",
}
local function setup(list)
	local out = {}
	for _, pair in ipairs(list) do table.insert(out, { q = SQ[pair[1]], a = pair[2] }) end
	return out
end
-- 2013 and early 2014 are separate presets (the user said so): 2013 is the 2013 mobile GUI with the old health bar; early
-- 2014 has the lighting and the rest of the hammer options of 2014, the old health bar OFF, and the setup's answers of 2013
-- (the 2013 recording: animations 2007, old sounds, normal cursor, 2012 textures, no old mobile jump button, no 2006 body, the
-- 2013 explosion, terrain and particles, the old physics with the 2013 camera). Every question is answered, so none is left as
-- it was last time (an old "2006" animations answer left over made walking not animate).
local function answers2013(textures, anim)
	return setup({ { "safeChat", "No" }, { "backpack", "No" }, { "animations", anim or "2008" }, { "sounds", "Yes" },
		{ "mouse", "normal" }, { "textures", textures }, { "mobileJump", "No" }, { "body2006", "No" }, { "forcefield", "2012" },
		{ "explosion", "2013" }, { "terrain", "2013" }, { "particles", "2013" }, { "emotes", "No" } })
end
local ANSWERS_2013 = answers2013("2012 textures")
local CHOICES_2013 = { SafeChat = false, Sounds = true, Mouse = "normal", Textures = "2012", MobileJump = false, Body2006 = false,
	Forcefield = "2012", Emotes = false }
local EXTRA_2014 = { is2014ShadowsEnabled = true, is2013DynamicEnabled = true, isOutlineEnabled = true, isClassicFaceEnabled = true,
	isOldPartSoundsEnabled = true, isHealthESPEnabled = true, isRemoveLeaderboardEnabled = true, isHideGameGuiEnabled = true,
	isOldThumbstickEnabled = true }
local function preset2013()
	return era { name = "2013", resetAll = true, resetOld = true, topbar = "2013 mobile", note = "the 2013 mobile GUI with the old health bar and no leaderboard, 2009 materials with smooth plastic, remove lighting, no shadows, old moon, remove pro, classic face, part sounds, health ESP, game GUI hidden, mobile controls and the old thumbstick, Old physics + 2013 camera",
		material = "is2009MaterialsEnabled",
		extra = { isSmoothPlasticEnabled = true, isRemoveLightingEnabled = true, isNoShadowsEnabled = true, isOldMoonEnabled = true,
			isRemoveProEnabled = true, is2012ColorsEnabled = true, isClassicFaceEnabled = true, isOldPartSoundsEnabled = true,
			isHealthESPEnabled = true, isHideGameGuiEnabled = true, isOldHealthBarEnabled = true, isRemoveLeaderboardEnabled = true,
			isMobileControlsEnabled = true, isOldThumbstickEnabled = true, isOutlineEnabled = true, isOldDecalEnabled = false, isUGCRemoverEnabled = false,
			isAllPlayersEnabled = true, isOldAvatarEnabled = false, is2006AvatarEnabled = false, is2008PlayersEnabled = false },
		physicsCamera = "bothOld2013", answers = ANSWERS_2013, choices = CHOICES_2013 }
end
local function presetEarly2014()
	local extra = {}
	for key, value in pairs(EXTRA_2014) do extra[key] = value end
	extra.isOldHealthBarEnabled = false
	extra.isMobileControlsEnabled = true -- (the user: it should enable the old mobile controls, as 2013 does)
	return era { name = "2013 - early 2014", resetAll = true, topbar = "2013 mobile", note = "the lighting and hammer options of 2014 (iw legacy lighting with the 2014 era, 2014 shadows, 2013 dyn, outline, classic face, no leaderboard), the old health bar off, the setup answers of 2013 with the 2016 textures (studs)",
		-- (no iw lighting: only 2014 to 2016 have it, the user said, not early 2014)
		lighting = {}, extra = extra,
		-- (and the 2016 studs: the textures question answered "2016 textures", as the user asked for early 2014)
		physicsCamera = "bothOld2013", answers = answers2013("2016 textures", "2014"),
		choices = { SafeChat = false, Sounds = true, Mouse = "normal", Textures = "2016", MobileJump = false, Body2006 = false,
			Forcefield = "2012", Emotes = false } }
end
local PRESETS = {
	-- 2005 - 2008: from the user's videos of each (the hammer's options and the setup's answers as they gave them). No skybox in
	-- any of them: the night sky, the old moon and "remove lighting" make the sky.
	era { name = "2005", resetOld = true, topbar = "2005", note = "2005 plastic, remove lighting, no shadows, 2008 night sky, old moon, game GUI hidden, no controls",
		hideControls = true, material = "is2005MaterialsEnabled", sky = { "is2008NightSkyEnabled" },
		extra = { isRemoveLightingEnabled = true, isNoShadowsEnabled = true, isOldMoonEnabled = true, isHideGameGuiEnabled = true,
			isUGCRemoverEnabled = true, isOldDecalEnabled = false, isHealthESPEnabled = true },
		physicsCamera = "none",
		answers = setup({ { "safeChat", "No" }, { "backpack", "No" }, { "animations", "2008" }, { "sounds", "No" },
			{ "mobileJump", "No" }, { "body2006", "No" }, { "explosion", "2006" }, { "terrain", "none" }, { "emotes", "No" } }),
		choices = { SafeChat = false, Sounds = false, MobileJump = false, Body2006 = false, Emotes = false } },
	era { name = "2006", resetOld = true, topbar = "2006", note = "2006 plastic, the 2006 avatar, remove lighting, no shadows, 2006-07 lighting, lens flare, night sky, old moon, old decal rendering, 2006 physics + 2007 camera",
		hideControls = true, material = "is2006MaterialsEnabled", sky = { "is2008NightSkyEnabled" }, lighting = { "is2006LightingEnabled" },
		-- (the hammer's avatar: one of its three at a time: the 2006 avatar here, the old avatar in 2007, 2008 players in 2008;
		-- the UGC remover on in every year but this one)
		extra = { isRemoveLightingEnabled = true, isNoShadowsEnabled = true, isOldMoonEnabled = true, isLensFlareEnabled = true,
			is2006AvatarEnabled = true, isOldAvatarEnabled = false, is2008PlayersEnabled = false, isUGCRemoverEnabled = false,
			isOldDecalEnabled = true, isHealthESPEnabled = true, isAllPlayersEnabled = true },
		physicsCamera = "both2006",
		answers = setup({ { "safeChat", "No" }, { "backpack", "No" }, { "animations", "2006" }, { "sounds", "Yes" },
			{ "mouse", "normal" }, { "textures", "2008 textures" }, { "mobileJump", "No" }, { "body2006", "No" },
			{ "forcefield", "normal" }, { "explosion", "2006" }, { "terrain", "none" }, { "oldParticles", "Yes" },
			{ "particles", "2008" }, { "emotes", "No" } }),
		choices = { SafeChat = false, Sounds = true, Forcefield = "normal", MobileJump = false, Body2006 = false, Emotes = false } },
	-- (2007 picks the 2008 GUI in the user's video: there is no 2007 GUI)
	era { name = "2007", resetOld = true, topbar = "2008", note = "the 2008 GUI, old players, 2006 plastic, 2006-07 lighting, old decal rendering, 2006 physics + 2007 camera, UGC remover",
		hideControls = true, material = "is2006MaterialsEnabled", sky = { "is2008NightSkyEnabled" }, lighting = { "is2006LightingEnabled" },
		extra = { isRemoveLightingEnabled = true, isNoShadowsEnabled = true, isOldMoonEnabled = true, isLensFlareEnabled = true,
			isOldAvatarEnabled = true, is2006AvatarEnabled = false, is2008PlayersEnabled = false, isAllPlayersEnabled = true,
			isUGCRemoverEnabled = true, isOldDecalEnabled = true, isHealthESPEnabled = true },
		physicsCamera = "both2006",
		answers = setup({ { "safeChat", "No" }, { "backpack", "No" }, { "animations", "2008" }, { "sounds", "Yes" },
			{ "mouse", "normal" }, { "textures", "2008 textures" }, { "mobileJump", "No" }, { "forcefield", "normal" },
			{ "explosion", "2007" }, { "terrain", "none" }, { "oldParticles", "Yes" }, { "particles", "2008" }, { "emotes", "No" } }),
		choices = { SafeChat = false, Sounds = true, Forcefield = "normal", MobileJump = false, Emotes = false } },
	era { name = "2008", resetOld = true, topbar = "2008", note = "2008 plastic, 2008 players, remove lighting, no shadows, 2006-07 lighting, lens flare, night sky, old moon, 2006 colours, camera sound, health ESP, UGC remover, 2008 physics + 2007 camera",
		hideControls = true, material = "is2008MaterialsEnabled", sky = { "is2008NightSkyEnabled" }, lighting = { "is2006LightingEnabled" },
		extra = { isRemoveLightingEnabled = true, isNoShadowsEnabled = true, isOldMoonEnabled = true, isLensFlareEnabled = true,
			is2006ColorsEnabled = true, isOldCameraSoundEnabled = true, isHealthESPEnabled = true,
			is2008PlayersEnabled = true, isOldAvatarEnabled = false, is2006AvatarEnabled = false, isUGCRemoverEnabled = true,
			isOldDecalEnabled = false, isAllPlayersEnabled = true },
		physicsCamera = "both2008",
		answers = setup({ { "safeChat", "Yes" }, { "animations", "2008" }, { "sounds", "No" }, { "textures", "2008 textures" },
			{ "mobileJump", "No" }, { "forcefield", "2008(r6 only)" }, { "terrain", "none" }, { "emotes", "No" } }),
		choices = { Forcefield = "2008", SafeChat = true, Sounds = false, MobileJump = false, Emotes = false } },
	-- (the user, round 3: no skybox, the UGC remover off (it was the lag), remove pro on (the over-contrast), all players on, and the
	-- 2008 physics; its camera is the 2007 one, as in the 2008 preset)
	era { name = "2010", resetOld = true, topbar = "2010", note = "2010 plastic, remove pro, old safe chat, all players, 2008 physics + 2007 camera",
		hideControls = true, material = "is2010MaterialsEnabled",
		extra = { isUGCRemoverEnabled = false, isOldDecalEnabled = false, isHealthESPEnabled = true, isRemoveProEnabled = true, isAllPlayersEnabled = true },
		physicsCamera = "both2008",
		answers = setup({ { "safeChat", "Yes" }, { "animations", "2008" }, { "mobileJump", "No" }, { "forcefield", "2008(r6 only)" }, { "terrain", "none" }, { "emotes", "No" } }),
		choices = { Forcefield = "2008", SafeChat = true, MobileJump = false, Emotes = false } },
	-- 2011 - 2013, from the user's videos (the hammer's options and the setup's answers as they gave them; the avatar and
	-- colour dropdowns and the 2012 / 2013 materials were shut in the 2012 and 2013 videos, so the 2011 video's are used).
	-- No skybox in any of them.
	era { name = "2011", resetAll = true, resetOld = true, topbar = "2011", note = "2009 materials with smooth plastic, remove lighting, no shadows, old moon, remove pro, 2012 colors, classic face, camera and part sounds, health ESP, all players, game GUI and controls hidden, Old physics + 2007 camera",
		hideControls = true, material = "is2009MaterialsEnabled",
		extra = { isSmoothPlasticEnabled = true, isRemoveLightingEnabled = true, isNoShadowsEnabled = true, isOldMoonEnabled = true,
			is2012ColorsEnabled = true, isClassicFaceEnabled = true, isOldCameraSoundEnabled = true, isOldPartSoundsEnabled = true,
			isHealthESPEnabled = true, isHideGameGuiEnabled = true, isOldDecalEnabled = false, isUGCRemoverEnabled = false,
			isAllPlayersEnabled = true, isRemoveProEnabled = true, isOldAvatarEnabled = false, is2006AvatarEnabled = false, is2008PlayersEnabled = false },
		physicsCamera = "bothOld2007",
		answers = setup({ { "safeChat", "Yes" }, { "animations", "2008" }, { "mouse", "normal" }, { "textures", "2012 textures" },
			{ "body2006", "No" }, { "forcefield", "2008(r6 only)" }, { "terrain", "2013" }, { "emotes", "No" } }),
		choices = { SafeChat = true, Mouse = "normal", Textures = "2012", Body2006 = false, Forcefield = "2008", Emotes = false } },
	era { name = "2012", resetAll = true, resetOld = true, topbar = "2012", note = "the 2011 options (remove pro, all players) with the chat bar, Old physics + 2007 camera",
		hideControls = true, material = "is2009MaterialsEnabled",
		extra = { isSmoothPlasticEnabled = true, isRemoveLightingEnabled = true, isNoShadowsEnabled = true, isOldMoonEnabled = true,
			is2012ColorsEnabled = true, isClassicFaceEnabled = true, isOldCameraSoundEnabled = true, isOldPartSoundsEnabled = true,
			isHealthESPEnabled = true, isHideGameGuiEnabled = true, isChatBarEnabled = true, isOldDecalEnabled = false,
			isUGCRemoverEnabled = false, isAllPlayersEnabled = true, isRemoveProEnabled = true, isOldAvatarEnabled = false, is2006AvatarEnabled = false,
			is2008PlayersEnabled = false },
		physicsCamera = "bothOld2007",
		answers = setup({ { "backpack", "No" }, { "animations", "2008" }, { "sounds", "Yes" }, { "body2006", "No" }, { "forcefield", "2012" }, { "terrain", "2013" },
			{ "particles", "2010" }, { "emotes", "No" } }),
		choices = { Backpack = "none", Sounds = true, Body2006 = false, Forcefield = "2012", Emotes = false } },
	preset2013(),
	presetEarly2014(),
	-- 2014 - 2024, from the user's recordings of each. No skybox in any of them; classic face on in all of them to 2023;
	-- the old physics step is only the 2013 camera in 2014, only the 2018 camera in 2015 - 2017, none from 2019
	era { name = "2014", resetAll = true, topbar = "2014", note = "iw lighting with the 2014 era, 2014 shadows, 2013 dyn, outline, classic face, part sounds, game GUI hidden, old thumbstick, 2013 camera",
		lighting = { "isIWLegacyLightingEnabled", "isIWLighting2014Enabled" },
		extra = EXTRA_2014,
		physicsCamera = "camera2013",
		answers = setup({ { "safeChat", "No" }, { "animations", "2014" }, { "sounds", "Yes" }, { "mouse", "normal" }, { "mobileJump", "Yes" }, { "body2006", "No" },
			{ "forcefield", "normal" }, { "explosion", "Normal" }, { "terrain", "2014" }, { "particles", "Normal" }, { "emotes", "No" } }),
		choices = { SafeChat = false, Sounds = true, Mouse = "normal", MobileJump = true, Body2006 = false, Forcefield = "normal", Emotes = false } },
	era { name = "early 2015", resetAll = true, topbar = "2015 early", note = "iw lighting with the 2015 era, outline, 2013 dyn, classic face, 2015 audio (no old sounds), slippery walk, game GUI hidden, 2018 camera",
		lighting = { "isIWLegacyLightingEnabled", "isIWLighting2015Enabled" },
		extra = { is2013DynamicEnabled = true, isOutlineEnabled = true, isClassicFaceEnabled = true, isOldPartSoundsEnabled = true,
			is2015AudioEnabled = true, isHealthESPEnabled = true, isRemoveLeaderboardEnabled = true, isHideGameGuiEnabled = true,
			isOldThumbstickEnabled = true, isSlipperyWalkEnabled = true },
		physicsCamera = "camera2018",
		answers = setup({ { "safeChat", "No" }, { "backpack", "No" }, { "animations", "Modern R6" }, { "sounds", "No" }, { "mouse", "normal" },
			{ "textures", "2016 textures" }, { "mobileJump", "Yes" }, { "body2006", "No" }, { "forcefield", "normal" },
			{ "explosion", "Normal" }, { "terrain", "2014" }, { "particles", "Normal" }, { "emotes", "No" } }),
		choices = { SafeChat = false, Sounds = false, Mouse = "normal", Textures = "2016", MobileJump = true, Body2006 = false, Forcefield = "normal", Emotes = false } },
	-- (2015 and 2016, as the user said to fix them: no 2013 dyn, no health ESP, no old mobile jump button)
	era { name = "2015", resetAll = true, topbar = "2015", note = "iw lighting with the 2015 era, classic face, 2015 audio (no old sounds), slippery walk, no leaderboard, 2018 camera, the 2016 loading screen",
		lighting = { "isIWLegacyLightingEnabled", "isIWLighting2015Enabled" },
		extra = { isClassicFaceEnabled = true, is2015AudioEnabled = true, isRemoveLeaderboardEnabled = true,
			isSlipperyWalkEnabled = true },
		physicsCamera = "camera2018",
		answers = setup({ { "safeChat", "No" }, { "backpack", "No" }, { "animations", "Modern R6" }, { "sounds", "No" }, { "mouse", "normal" },
			{ "textures", "2016 textures" }, { "mobileJump", "No" }, { "body2006", "No" }, { "forcefield", "normal" },
			{ "explosion", "Normal" }, { "terrain", "2014" }, { "particles", "Normal" }, { "emotes", "No" } }),
		choices = { SafeChat = false, Sounds = false, Mouse = "normal", Textures = "2016", MobileJump = false, Body2006 = false, Forcefield = "normal", Emotes = false } },
	era { name = "2016", resetAll = true, topbar = "2016", note = "2016 lighting and materials, classic face, 2016 audio, slippery walk, the old mobile jump button, no leaderboard, 2018 camera",
		material = "is2016MaterialsEnabled", lighting = { "isIWLegacyLightingEnabled", "isIWLighting2016Enabled" },
		extra = { isClassicFaceEnabled = true, is2016AudioEnabled = true, isRemoveLeaderboardEnabled = true,
			isSlipperyWalkEnabled = true },
		physicsCamera = "camera2018",
		answers = setup({ { "safeChat", "No" }, { "backpack", "No" }, { "animations", "Old R15" }, { "sounds", "No" }, { "mouse", "normal" },
			{ "textures", "2016 textures" }, { "mobileJump", "Yes" }, { "body2006", "No" }, { "forcefield", "normal" },
			{ "explosion", "Normal" }, { "terrain", "none" }, { "particles", "Normal" }, { "emotes", "No" } }),
		choices = { SafeChat = false, Sounds = false, Mouse = "normal", Textures = "2016", MobileJump = true, Body2006 = false, Forcefield = "normal", Emotes = false } },
	era { name = "2017", resetAll = true, topbar = "2017", note = "legacy materials, legacy lighting with the 2017 era, classic face, the old mobile jump button, no leaderboard, 2018 camera",
		material = "isLegacyMaterialsEnabled", lighting = { "isLegacyLightingEnabled", "isIWLighting2017Enabled" },
		extra = { isClassicFaceEnabled = true, isRemoveLeaderboardEnabled = true },
		physicsCamera = "camera2018",
		answers = setup({ { "safeChat", "No" }, { "backpack", "No" }, { "animations", "Old R15" }, { "sounds", "No" }, { "mouse", "normal" },
			{ "textures", "Normal" }, { "mobileJump", "Yes" }, { "body2006", "No" }, { "forcefield", "normal" },
			{ "explosion", "Normal" }, { "terrain", "none" }, { "particles", "Normal" }, { "emotes", "No" } }),
		choices = { SafeChat = false, Sounds = false, Mouse = "normal", MobileJump = true, Body2006 = false, Forcefield = "normal", Emotes = false } },
	-- 2019 and 2021: the 2017 options with legacy lighting off and the year's lighting; everything answered No / none / Normal
	era { name = "2019", resetAll = true, topbar = "2019", note = "legacy materials, 2019 lighting, classic face, no leaderboard, no physics or camera",
		material = "isLegacyMaterialsEnabled", lighting = { "isIWLighting2019Enabled" },
		extra = { isClassicFaceEnabled = true, isRemoveLeaderboardEnabled = true },
		physicsCamera = "none",
		answers = setup({ { "safeChat", "No" }, { "backpack", "No" }, { "animations", "Normal" }, { "sounds", "No" }, { "mouse", "normal" },
			{ "textures", "Normal" }, { "mobileJump", "No" }, { "body2006", "No" }, { "forcefield", "normal" },
			{ "explosion", "Normal" }, { "terrain", "none" }, { "particles", "Normal" }, { "emotes", "No" } }),
		choices = { SafeChat = false, Sounds = false, Mouse = "normal", MobileJump = false, Body2006 = false, Forcefield = "normal", Emotes = false } },
	era { name = "2021", resetAll = true, topbar = "2021", note = "legacy materials, 2020 lighting, classic face, no leaderboard, no physics or camera",
		material = "isLegacyMaterialsEnabled", lighting = { "isIWLighting2020Enabled" },
		extra = { isClassicFaceEnabled = true, isRemoveLeaderboardEnabled = true },
		physicsCamera = "none",
		answers = setup({ { "safeChat", "No" }, { "backpack", "No" }, { "animations", "Normal" }, { "sounds", "No" }, { "mouse", "normal" },
			{ "textures", "Normal" }, { "mobileJump", "No" }, { "body2006", "No" }, { "forcefield", "normal" },
			{ "explosion", "Normal" }, { "terrain", "none" }, { "particles", "Normal" }, { "emotes", "No" } }),
		choices = { SafeChat = false, Sounds = false, Mouse = "normal", MobileJump = false, Body2006 = false, Forcefield = "normal", Emotes = false } },
	-- 2023 old: everything off but the classic face; 2023 new the same; 2024: nothing on at all
	era { name = "2023 old", resetAll = true, topbar = "2023 old", note = "only the classic face on; everything answered No / none / Normal",
		extra = { isClassicFaceEnabled = true }, physicsCamera = "none",
		answers = setup({ { "safeChat", "No" }, { "backpack", "No" }, { "animations", "Normal" }, { "sounds", "No" }, { "mouse", "normal" },
			{ "textures", "Normal" }, { "mobileJump", "No" }, { "body2006", "No" }, { "forcefield", "normal" },
			{ "explosion", "Normal" }, { "terrain", "none" }, { "particles", "Normal" }, { "emotes", "No" } }),
		choices = { SafeChat = false, Sounds = false, Mouse = "normal", MobileJump = false, Body2006 = false, Forcefield = "normal", Emotes = false } },
	era { name = "2023 new", resetAll = true, topbar = "2023 new", note = "only the classic face on; everything answered No / none / Normal",
		extra = { isClassicFaceEnabled = true }, physicsCamera = "none",
		answers = setup({ { "safeChat", "No" }, { "backpack", "No" }, { "animations", "Normal" }, { "sounds", "No" }, { "mouse", "normal" },
			{ "textures", "Normal" }, { "mobileJump", "No" }, { "body2006", "No" }, { "forcefield", "normal" },
			{ "explosion", "Normal" }, { "terrain", "none" }, { "particles", "Normal" }, { "emotes", "No" } }),
		choices = { SafeChat = false, Sounds = false, Mouse = "normal", MobileJump = false, Body2006 = false, Forcefield = "normal", Emotes = false } },
	era { name = "2024", resetAll = true, topbar = "2024", note = "nothing on; everything answered No / none / Normal", physicsCamera = "none",
		answers = setup({ { "safeChat", "No" }, { "backpack", "No" }, { "animations", "Normal" }, { "sounds", "No" }, { "mouse", "normal" },
			{ "textures", "Normal" }, { "mobileJump", "No" }, { "body2006", "No" }, { "forcefield", "normal" },
			{ "explosion", "Normal" }, { "terrain", "none" }, { "particles", "Normal" }, { "emotes", "No" } }),
		choices = { SafeChat = false, Sounds = false, Mouse = "normal", MobileJump = false, Body2006 = false, Forcefield = "normal", Emotes = false } },
}
-- All players: on in every preset up to 2019 (the user: "enable all players for all of the presets, except for everything
-- above 2019"); 2021, 2023 old, 2023 new and 2024 keep it off
local ALL_PLAYERS_UP_TO = 2019
for _, preset in ipairs(PRESETS) do
	local year = tonumber(string.match(preset.name, "(%d%d%d%d)%s*$")) or tonumber(string.match(preset.name, "(%d%d%d%d)"))
	preset.config.isAllPlayersEnabled = (year ~= nil and year <= ALL_PLAYERS_UP_TO)
end
-- Bloxy's own ids for its own years (More guis' added ones are kept in the topbar pick file instead)
local BLOXY_TOPBAR_IDS = {
	["2024"] = "2024", ["2024(fflags)"] = "2023_FFlags", ["2023(w.i.p)"] = "2023_WIP", ["2019"] = "2019", ["2017"] = "2017",
	["2016(no chat)"] = "2016_Adv", ["2016"] = "2016_Simp", ["2015"] = "2015", ["2014"] = "2014",
	["2013 mobile"] = "2013mobile", ["2013"] = "2013", ["2012"] = "2012", ["2010"] = "2010",
}

-- The year Bloxy itself saves when one of More guis' GUIs is picked (More guis presses that year's button for it, then
-- swaps the GUI in). A preset writes it too: left alone, the config kept whatever year was in it before, and the
-- loader then gave 2008, 2006 and the like that year's loading screen, purchase prompt and bubbles.
local MORE_GUIS_BLOXY_IDS = { ["2011"] = "2013", ["2008"] = "2013", ["2006"] = "2013", ["2005"] = "2013",
	["1989"] = "2013", ["1988"] = "2013", ["2015 early"] = "2014" }

local function findPreset(name)
	for _, preset in ipairs(PRESETS) do
		if preset.name == name then return preset end
	end
	return nil
end

-- the settings files for a preset: today's, with the preset's year and settings put in
local function presetFiles(preset)
	local files = captureFiles()
	local config = decode(files[CONFIG_FILE])
	if type(config) ~= "table" then config = {} end
	for key, value in pairs(preset.config or {}) do config[key] = value end
	config.Choices = type(config.Choices) == "table" and config.Choices or {}
	local bloxyId = BLOXY_TOPBAR_IDS[preset.topbar] or MORE_GUIS_BLOXY_IDS[preset.topbar]
	if bloxyId then config.Choices.Topbar = bloxyId end
	for key, value in pairs(preset.choices or {}) do config.Choices[key] = value end
	files[CONFIG_FILE] = encode(config) or files[CONFIG_FILE] or "{}"
	files[TOPBAR_PICK_FILE] = encode({ Pick = preset.topbar }) or files[TOPBAR_PICK_FILE]
	-- the setup's answers: this year's GUI first, then the others as they were last given (a preset's own answers,
	-- when it has them, in place of those)
	local answers = { { q = TOPBAR_QUESTION, a = preset.topbar }, { q = TOPBAR_QUESTION, a = "confirm" } }
	local own = {}
	for _, step in ipairs(preset.answers or {}) do own[step.q] = true end
	for _, step in ipairs(savedAnswers(files) or {}) do
		local q = type(step.q) == "string" and step.q or ""
		if not string.find(string.lower(q), "topbar", 1, true) and not own[q] then table.insert(answers, step) end
	end
	for _, step in ipairs(preset.answers or {}) do table.insert(answers, step) end
	files[SETUP_FILE] = encode({ answers = answers, at = os.time() }) or files[SETUP_FILE]
	return files
end

local function loadPreset(name)
	local preset = findPreset(name)
	if not preset then return false, "missing" end
	print("[Saved Settings] preset " .. preset.name .. ": the " .. preset.topbar .. " GUI"
		.. (preset.note and (" (" .. preset.note .. ")") or "") .. ", everything else as it is")
	return loadFiles(presetFiles(preset), "preset " .. preset.name, false)
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
	-- the icon shows with Bloxy (after the 2023 old / FFlags GUIs' rejoin it waits for Bloxy to come up)
	if gui then gui.Enabled = true end
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
			if hammerOpen and presetsOpen and closePresets then closePresets() end
			-- (Bloxy slides the hammer to its own spots: right after, it goes to the same ones on the icon line)
			task.defer(function()
				if hammer and hammer.Parent and not destroyed then
					tween(hammer, { Position = hammerOpen and HAMMER_OPEN or HAMMER_REST, Rotation = hammerOpen and 5 or -20 })
				end
			end)
		end)
	end
	-- the hammer onto the icon line (after Bloxy's own slide in)
	if hammer and not hammerOpen then
		task.delay(0.2, function()
			if hammer and hammer.Parent and not destroyed and not hammerOpen then
				tween(hammer, { Position = HAMMER_REST }, 0.8)
			end
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

-- an icon's picture from this repo: downloaded once into the executor's folder and shown with getcustomasset
local function useAssetImage(file, apply)
	task.spawn(function()
		local getAsset = (type(getcustomasset) == "function" and getcustomasset)
			or (type(getsynasset) == "function" and getsynasset) or nil
		if not (getAsset and canRead and canWrite) then return end
		pcall(function()
			local path = "AddtionAssets/" .. ASSET_VERSION .. "_" .. file
			if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("AddtionAssets") then
				makefolder("AddtionAssets")
			end
			if not isfile(path) then
				local data = game:HttpGet(ASSET_URL .. file .. "?v=" .. tostring(os.time()))
				if type(data) == "string" and #data > 64 and string.sub(data, 2, 4) == "PNG" then rawWritefile(path, data) end
			end
			if isfile(path) then
				local id = getAsset(path)
				if type(id) == "string" and id ~= "" and not destroyed then apply(id) end
			end
		end)
	end)
end

local function buildPresetsPanel()
	presetsPanel = Instance.new("Frame")
	presetsPanel.Name = "PresetsPanel"
	presetsPanel.Size = UDim2.new(0.35, 0, 0.88, 60)
	presetsPanel.Position = PANEL_CLOSED
	presetsPanel.BackgroundColor3 = GREY
	presetsPanel.BackgroundTransparency = 0.5
	presetsPanel.BorderSizePixel = 0
	presetsPanel.ZIndex = 95
	presetsPanel.Parent = gui
	outline(presetsPanel, WHITE, 1.5)

	label(presetsPanel, "Title", "presets", UDim2.new(1, -30, 0, 22), UDim2.new(0, 15, 0, 44), 18)
	local hint = label(presetsPanel, "Hint", "a year in one tap: its GUI, the rest as you have it",
		UDim2.new(1, -30, 0, 16), UDim2.new(0, 15, 0, 68), 12)
	hint.TextTransparency = 0.15

	local plist = Instance.new("ScrollingFrame")
	plist.Name = "PresetList"
	plist.BackgroundTransparency = 1
	plist.BorderSizePixel = 0
	plist.Position = UDim2.new(0, 15, 0, 92)
	plist.Size = UDim2.new(1, -24, 1, -112)
	plist.CanvasSize = UDim2.new(0, 0, 0, 0)
	plist.AutomaticCanvasSize = Enum.AutomaticSize.Y
	plist.ScrollingDirection = Enum.ScrollingDirection.Y
	plist.ScrollBarThickness = 5
	plist.ZIndex = 96
	plist.Parent = presetsPanel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = plist
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 2)
	pad.PaddingLeft = UDim.new(0, 1)
	pad.Parent = plist

	for i, preset in ipairs(PRESETS) do
		local row = Instance.new("Frame")
		row.Name = "Preset_" .. i
		row.LayoutOrder = i
		row.Size = UDim2.new(1, -10, 0, 44)
		row.BackgroundColor3 = WHITE
		row.BackgroundTransparency = 0.85
		row.BorderSizePixel = 0
		row.ZIndex = 96
		row.Parent = plist
		outline(row, WHITE, 1)
		local nameLabel = label(row, "NameLabel", preset.name, UDim2.new(1, -90, 0, 18),
			UDim2.new(0, 8, 0, preset.note and 4 or 13), 15)
		nameLabel.ZIndex = 97
		if preset.note then
			local noteLabel = label(row, "NoteLabel", preset.note, UDim2.new(1, -90, 0, 12), UDim2.new(0, 8, 0, 24), 11)
			noteLabel.TextTransparency = 0.15
		end
		local loadBtn = button(row, "LoadButton", "load", "green", UDim2.new(0, 64, 0, 26), UDim2.new(1, -72, 0.5, -13))
		connect(loadBtn.MouseButton1Click, function()
			playClick()
			if applying or replaying then return end
			loadBtn.Text = "loading…"
			task.spawn(function()
				local ok = loadPreset(preset.name)
				if loadBtn.Parent then
					loadBtn.Text = "load"
					flash(loadBtn, ok and "loaded ✓" or "can't")
				end
			end)
		end)
	end
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

	-- the icons on the line (see THE ICON COLUMN at the top): the floppy disk under the hammer, the presets plus over it
	icon = Instance.new("ImageButton")
	icon.Name = "SaveDiskIcon"
	icon.BackgroundTransparency = 1
	icon.Image = ICON_IMAGE
	icon.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
	icon.Position = ICON_HIDDEN
	icon.Rotation = 0
	icon.ZIndex = 100
	icon.Parent = gui
	useAssetImage(FLOPPY_FILE, function(id) if icon then icon.Image = id end end)

	plusIcon = Instance.new("ImageButton")
	plusIcon.Name = "PresetsPlusIcon"
	plusIcon.BackgroundTransparency = 1
	plusIcon.Image = ""
	plusIcon.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
	plusIcon.Position = PLUS_HIDDEN
	plusIcon.ZIndex = 100
	plusIcon.Parent = gui
	local plusDrawn = Instance.new("TextLabel") -- (until its picture is there, or if the executor can't show it)
	plusDrawn.Name = "DrawnPlus"
	plusDrawn.BackgroundTransparency = 1
	plusDrawn.Size = UDim2.new(1, 0, 1, 0)
	plusDrawn.FontFace = fontBold
	plusDrawn.TextScaled = true
	plusDrawn.Text = "+"
	plusDrawn.TextColor3 = Color3.fromRGB(40, 170, 70)
	plusDrawn.TextStrokeTransparency = 0.4
	plusDrawn.ZIndex = 101
	plusDrawn.Parent = plusIcon
	useAssetImage(PLUS_FILE, function(id)
		if plusIcon then
			plusIcon.Image = id
			plusDrawn.Visible = false
		end
	end)

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

	local titleLabel = label(panel, "Title", "saved settings", UDim2.new(1, -30, 0, 22), UDim2.new(0, 15, 0, 44), 18)

	-- (Addtion-Scripts) THE 1989 EASTER EGG: tap the words "saved settings" at the top of this window 8 times, each tap within
	-- 1.5 s of the one before, and the title says "1989 unlocked". The 1989 GUI (the Interactive Physics window) is then
	-- in the topbar list from then on (More guis.lua), and the unlock is kept in a file so it never goes away.
	do
		local EGG_FILE = "BloxyEasterEgg1989.json"
		local taps, lastTap = 0, -math.huge
		local hit = Instance.new("TextButton")
		hit.Name = "TitleTap"
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.AutoButtonColor = false
		hit.Size = titleLabel.Size
		hit.Position = titleLabel.Position
		hit.ZIndex = titleLabel.ZIndex + 1
		hit.Parent = panel
		hit.MouseButton1Click:Connect(function()
			local env = (getgenv and getgenv()) or _G
			if env.BP_1989Unlocked then return end
			local okFile, there = pcall(function() return isfile and isfile(EGG_FILE) end)
			if okFile and there then env.BP_1989Unlocked = true return end
			local now = os.clock()
			if now - lastTap < 1.5 then taps = taps + 1 else taps = 1 end
			lastTap = now
			if taps >= 8 then
				env.BP_1989Unlocked = true
				pcall(function() if writefile then writefile(EGG_FILE, '{"unlocked":true}') end end)
				print("[1989] Easter egg unlocked: the 1989 option is in the GUI list from now on.")
				titleLabel.Text = "1989 unlocked"
				task.delay(2.5, function()
					if titleLabel.Parent then titleLabel.Text = "saved settings" end
				end)
			end
		end)
	end

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
		-- (Addtion-Scripts) THE 1988 EASTER EGG: type 1988 in the name box and press save. It does not save anything; the title says
		-- "1988 unlocked", and the 1988 GUI (the E Sprites joke GUI) is in the topbar list from then on (More guis.lua),
		-- under 1989 when that is unlocked too. The unlock is kept in a file so it never goes away.
		if string.match(nameBox.Text or "", "^%s*(.-)%s*$") == "1988" then
			local env = (getgenv and getgenv()) or _G
			local EGG_FILE_1988 = "BloxyEasterEgg1988.json"
			local already = env.BP_1988Unlocked
			if not already then
				local okFile, there = pcall(function() return isfile and isfile(EGG_FILE_1988) end)
				already = okFile and there
			end
			env.BP_1988Unlocked = true
			nameBox.Text = ""
			if not already then
				pcall(function() if writefile then writefile(EGG_FILE_1988, '{"unlocked":true}') end end)
				print("[1988] Easter egg unlocked: the 1988 option is in the GUI list from now on.")
				titleLabel.Text = "1988 unlocked"
				task.delay(2.5, function()
					if titleLabel.Parent then titleLabel.Text = "saved settings" end
				end)
			end
			flash(saveButton, "1988 ✓")
			return
		end
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
			if presetsOpen then closePresets() end
			tween(icon, { Position = ICON_OUT, Rotation = 0 })
			tween(panel, { Position = PANEL_OPEN })
		end
	end)

	-- the presets: the plus opens its panel (one panel open at a time: this, the saved settings or the hammer's)
	buildPresetsPanel()
	connect(plusIcon.MouseButton1Click, function()
		playClick()
		if presetsOpen then closePresets() else
			presetsOpen = true
			if isOpen then closePanel() end
			closeHammer()
			tween(plusIcon, { Position = PLUS_OUT })
			tween(presetsPanel, { Position = PANEL_OPEN })
		end
	end)

	-- (nothing here ever hides the icons: if another script does, they are shown again)
	connect(icon:GetPropertyChangedSignal("Visible"), function()
		if not icon.Visible then icon.Visible = true end
	end)
	connect(plusIcon:GetPropertyChangedSignal("Visible"), function()
		if not plusIcon.Visible then plusIcon.Visible = true end
	end)

	gui.Parent = playerGui
	task.defer(function()
		if icon and icon.Parent then tween(icon, { Position = ICON_REST }, 1.0) end
		if plusIcon and plusIcon.Parent then tween(plusIcon, { Position = PLUS_REST }, 1.0) end
	end)
	return true
end

closePanel = function()
	isOpen = false
	if nameBox then pcall(function() nameBox:ReleaseFocus() end) end
	if icon then tween(icon, { Position = ICON_REST, Rotation = 0 }) end
	if panel then tween(panel, { Position = PANEL_CLOSED }) end
end

closePresets = function()
	presetsOpen = false
	if plusIcon then tween(plusIcon, { Position = PLUS_REST }) end
	if presetsPanel then tween(presetsPanel, { Position = PANEL_CLOSED }) end
end

closeParadox = function()
	if isOpen then closePanel() end
	if presetsOpen then closePresets() end
	closeHammer()
end

local function destroy()
	destroyed = true
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	connections = {}
	if gui then pcall(function() gui:Destroy() end) end
	if clickSound then pcall(function() clickSound:Destroy() end) end
	gui, icon, panel, list, clickSound = nil, nil, nil, nil, nil
	plusIcon, presetsPanel, presetsOpen = nil, nil, false
	if Env.BPSavedSettings and Env.BPSavedSettings.Destroy == destroy then Env.BPSavedSettings = nil end
end

hideEverything = function()
	isOpen = false
	presetsOpen = false
	if not (icon and panel) then destroy() return end
	tween(icon, { Position = UDim2.new(1.3, 0, ICON_REST.Y.Scale, ICON_REST.Y.Offset) }, 0.6)
	if plusIcon then tween(plusIcon, { Position = UDim2.new(1.3, 0, PLUS_REST.Y.Scale, PLUS_REST.Y.Offset) }, 0.6) end
	if presetsPanel then tween(presetsPanel, { Position = UDim2.new(1.3, 0, 0, -40) }, 0.6) end
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
	Presets = function()
		local names = {}
		for i, preset in ipairs(PRESETS) do names[i] = preset.name end
		return names
	end,
	LoadPreset = function(name) return loadPreset(name) end,
	OpenPresets = function() if not presetsOpen and plusIcon then press(plusIcon) end end,
	-- the setup's answers as they finally were (Setup Back Forward.lua, after its last question: going back and
	-- forward left earlier answers in the recording)
	SetSetupAnswers = function(list)
		if type(list) ~= "table" then return false end
		local clean = {}
		for _, step in ipairs(list) do
			if type(step) == "table" and type(step.q) == "string" and type(step.a) == "string" then
				table.insert(clean, { q = step.q, a = step.a })
			end
		end
		recording = { answers = clean }
		saveRecording()
		return true
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

-- Hidden until Bloxy's GUI is there, and hidden again while it isn't (the 2023 old and FFlags GUIs rejoin
-- the game and load this again in the new server, before Bloxy is run there).
if gui then
	local playerGui = gui.Parent
	gui.Enabled = playerGui ~= nil and playerGui:FindFirstChild(BLOXY_GUI) ~= nil
end

task.spawn(function()
	local playerGui = gui and gui.Parent
	if not playerGui then return end
	connect(playerGui.ChildAdded, function(child)
		if child.Name == BLOXY_GUI then task.spawn(hookWhenReady, child) end
	end)
	connect(playerGui.ChildRemoved, function(child)
		if child == bloxyGui then
			bloxyGui = nil
			if isOpen and closePanel then pcall(closePanel) end
			if presetsOpen and closePresets then pcall(closePresets) end
			if gui and not playerGui:FindFirstChild(BLOXY_GUI) then gui.Enabled = false end
		end
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
