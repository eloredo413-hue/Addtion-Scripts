--[[ SAVED SETTINGS (Addtion-Scripts) ]]
-- A panel like Bloxy's hammer one, opened by the floppy disk (decal 90842402386374) under the hammer:
-- save what is set now under a name, and load, rename or delete what was saved. They are kept in
-- BloxyParadoxSavedSettings.json, so they are still there after leaving the game or running the script again.
--
-- What one holds, exactly as it was:
--   * Bloxy's whole settings file (BloxyParadoxConfig.json): every setup (wizard) choice, skip setup, every
--     option of the hammer's side panel (Bloxy's, Hammer stuff 1's and Hammer stuff 2's, the dropdowns too),
--     and the old physics and explosion picks
--   * the setup steps that keep their pick in a file of their own: terrain (BloxyTerrainChoice.json) and the
--     2007 animation (BloxyAnimation2007Choice.json)
--
-- Loading puts those files back and ticks / unticks the hammer's boxes to match straight away (by pressing
-- them, so each option turns itself on or off as usual). Setup choices (topbar, physics, ...) are used the
-- next time the script runs; with "skip setup" ticked that is without going through the setup.
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

local LocalPlayer = Players.LocalPlayer
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
local SETTINGS_FILES = { CONFIG_FILE, ANIM_FILE, TERRAIN_FILE }
-- written when the saved settings had no such file (that step was never picked: the same as no file)
local WHEN_MISSING = {
	[ANIM_FILE] = '{"Animation2007":false}',
	[TERRAIN_FILE] = '{}',
}

local ICON_IMAGE = "rbxthumb://type=Asset&id=90842402386374&w=420&h=420"
local GUI_NAME = "BloxySavedSettings" -- ("Bloxy" in the name: the game GUI hider leaves it alone)
local BLOXY_GUI = "BloxyParadoxProject"
local MAX_NAME = 24
local CONFIRM_TIME = 3

-- where things go: the same places as Bloxy's hammer and its panel
local ICON_SIZE = 46
local ICON_HIDDEN = UDim2.new(1, 40, 0.5, 50)
local ICON_REST = UDim2.new(1, -38, 0.5, 50)
local ICON_OUT = UDim2.new(1, -58, 0.5, 50)
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
}
local OLD_DECAL_BUTTON, OLD_DECAL_KEY = "BPOldDecalButton", "isOldDecalEnabled"

------------------------------------------------------------
-- FILES
------------------------------------------------------------
local canRead = type(readfile) == "function" and type(isfile) == "function"
local canWrite = type(writefile) == "function"

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
	local ok = pcall(writefile, file, text)
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
end

local function writeStore()
	local text = encode({ version = 1, order = store.order, profiles = store.profiles, lastLoaded = store.lastLoaded })
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

local function loadSettings(name)
	local profile = store.profiles[name]
	if not profile then return false, "missing" end
	if not canWrite then
		warn("[Saved Settings] this executor can't write files, so nothing can be loaded")
		return false, "no files"
	end
	applying = true
	local config = decode(profile.files[CONFIG_FILE]) or {}
	local wanted = function(key) return config[key] == true end
	local changed, couldNot = 0, 0
	local function pressBox(box)
		if press(box) then changed = changed + 1 else couldNot = couldNot + 1 end
		task.wait(0.05)
	end

	local ok = pcall(function()
		-- 1. Bloxy's own boxes (each press writes Bloxy's whole file, so first)
		for boxName, key in pairs(BLOXY_BOXES) do
			local box = findIn(hammerPanel, boxName)
			if box and boxIsOn(box) ~= wanted(key) then pressBox(box) end
		end
		-- 2. the files
		putFilesBack(profile.files)
		-- 3. the hammer's options: the ones to turn off first, then the ones to turn on (some untick each other)
		local turnOn = {}
		for boxName, key in pairs(HAMMER_BOXES) do
			local box = findIn(hammerPanel, boxName)
			if box then
				local on = boxIsOn(box)
				if on and not wanted(key) then
					pressBox(box)
				elseif not on and wanted(key) then
					table.insert(turnOn, box)
				end
			end
		end
		for _, box in ipairs(turnOn) do
			if not boxIsOn(box) then pressBox(box) end
		end
		local decal = findIn(hammerPanel, OLD_DECAL_BUTTON)
		if decal and oldDecalIsOn(decal) ~= wanted(OLD_DECAL_KEY) then pressBox(decal) end
		-- 4. the files once more, exactly as saved (the presses wrote their own copies on the way)
		task.wait(0.3)
		putFilesBack(profile.files)
	end)
	applying = false

	store.lastLoaded = name
	writeStore()
	if not ok then
		warn("[Saved Settings] something went wrong while loading \"" .. name .. "\"; its files were put back")
		putFilesBack(profile.files)
	end
	print(string.format("[Saved Settings] loaded \"%s\": %d hammer option%s changed now%s; setup choices are used the next time the script runs",
		name, changed, changed == 1 and "" or "s",
		couldNot > 0 and (" (" .. couldNot .. " couldn't be pressed here: they change when the script runs again)") or ""))
	return true, changed, couldNot
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
		if applying then return end
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
	gui.DisplayOrder = 999 -- (Bloxy's)
	pcall(function() gui.ClipToDeviceSafeArea = false end)

	clickSound = Instance.new("Sound")
	clickSound.Name = "BPSavedSettingsClick"
	clickSound.SoundId = "rbxassetid://12221967"
	clickSound.Volume = 0.6
	clickSound.Parent = SoundService

	-- the icon: a floppy disk under the hammer, half out of the screen like it
	icon = Instance.new("ImageButton")
	icon.Name = "SavedSettingsIcon"
	icon.BackgroundTransparency = 1
	icon.Image = ICON_IMAGE
	icon.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
	icon.Position = ICON_HIDDEN
	icon.Rotation = -12
	icon.ZIndex = 100
	icon.Parent = gui

	panel = Instance.new("Frame")
	panel.Name = "SavedSettingsPanel"
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
	Load = function(name) local ok, a, b = loadSettings(name) refreshList() return ok, a, b end,
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

print(string.format("[Saved Settings] ready: %d saved%s", #store.order,
	(canRead and canWrite) and "" or " (this executor can't read or write files: saving is off)"))
