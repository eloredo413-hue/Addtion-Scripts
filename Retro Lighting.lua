-- [[ RETRO LIGHTING - copy and paste ]]
-- A lighting picker with its own window: pick an era's lighting, or each part of it, and see it at once. Only on
-- your screen. Run it again to replace it; the X puts the game's own lighting back and closes it. The last picks
-- are remembered (RetroLighting.json) and come back the next time it runs.
--
-- Era looks (each sets the options below at once; change any of them afterwards):
--   * Game's own        - nothing changed
--   * 2011-12 (Rowind)  - what Rowind's lighting script (Relegacy) is started with for its 2011-2013 clients:
--                         the Legacy technology (Roblox runs Legacy as Compatibility since 2019), shadows on,
--                         lights tweaked (no light shadows), brightness left alone; plus no modern effects
--   * 2013 Voxel        - the 2013 voxel lighting (Retro Studio's 2013 places): Voxel, its shadows on, no
--                         environment light, no modern effects, the Voxel tone (not the retro one)
--   * 2017 Old Graphics - the "OldGraphics" look of the legacy CoreGui changer: Compatibility, the retro tone,
--                         its flat colours (contrast -0.1), no bloom / sun rays / blur / depth of field / atmosphere
--   * 2019 ShadowMap / Future - the 2019 technologies
-- Options: Technology (Game / Legacy / Voxel / ShadowMap / Future), Shadows (game's / on / off), Retro tone, No
-- modern effects, Old Graphics colours, Lights without shadows, No environment light.
-- The technology is a hidden property: an executor that can set hidden properties is needed for it (where it can't,
-- the newer LightingStyle setting is still switched). Hammer stuff's own lighting options (legacy lighting, iw
-- legacy lighting, voxel lighting, remove pro) set the same things: turn those off while using this.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local genv = (getgenv and getgenv()) or _G
if type(genv.RetroLightingStop) == "function" then pcall(genv.RetroLightingStop) end

local SAVE_FILE = "RetroLighting.json"
local conns = {}
local stopped = false

----------------------------------------------------------------------------------------------------
-- reading and writing Lighting (hidden properties too), remembering the game's own value of each
----------------------------------------------------------------------------------------------------
local okStyle, StyleEnum = pcall(function() return Enum.LightingStyle end)
if not okStyle then StyleEnum = nil end

local function read(inst, prop)
	local ok, v = pcall(function() return inst[prop] end)
	if ok then return v end
	if type(gethiddenproperty) == "function" then
		local ok2, v2 = pcall(gethiddenproperty, inst, prop)
		if ok2 then return v2 end
	end
	return nil
end

local function write(inst, prop, value)
	if read(inst, prop) == nil then return false end -- this Roblox client doesn't have it
	if read(inst, prop) ~= value then
		pcall(function() inst[prop] = value end)
		if read(inst, prop) ~= value and type(sethiddenproperty) == "function" then
			pcall(sethiddenproperty, inst, prop, value)
		end
	end
	return read(inst, prop) == value
end

local gameValues = {} -- Lighting property -> the game's own value (while this has changed it)
local written = {}    -- Lighting property -> what this wrote

local function setLighting(prop, value)
	if gameValues[prop] == nil then
		local v = read(Lighting, prop)
		if v == nil then return false end
		gameValues[prop] = v
	end
	local ok = write(Lighting, prop, value)
	written[prop] = read(Lighting, prop)
	return ok
end

-- the game's own value back, unless the game has changed it since
local function giveBack(prop)
	local v = gameValues[prop]
	if v == nil then return end
	if read(Lighting, prop) == written[prop] then write(Lighting, prop, v) end
	gameValues[prop], written[prop] = nil, nil
end

----------------------------------------------------------------------------------------------------
-- the choices
----------------------------------------------------------------------------------------------------
local TECHS = { "Game", "Legacy", "Voxel", "ShadowMap", "Future" }
local STYLE_FOR = { -- (Roblox's newer setting for each technology: style, quality first)
	Legacy = { "Soft", false }, Voxel = { "Soft", false }, ShadowMap = { "Realistic", false }, Future = { "Realistic", true },
}

local DEFAULTS = {
	tech = "Game", shadows = "game", retroTone = false, noEffects = false, oldColors = false,
	lightsNoShadows = false, noEnvLight = false,
}
local ERAS = {
	{ name = "Game's own", set = {} },
	{ name = "2011-12 (Rowind)", set = { tech = "Legacy", shadows = "on", lightsNoShadows = true, noEffects = true, retroTone = true } },
	{ name = "2013 Voxel", set = { tech = "Voxel", shadows = "on", noEnvLight = true, noEffects = true } },
	{ name = "2017 Old Graphics", set = { tech = "Legacy", shadows = "on", retroTone = true, noEffects = true, oldColors = true, noEnvLight = true } },
	{ name = "2019 ShadowMap", set = { tech = "ShadowMap" } },
	{ name = "Future", set = { tech = "Future" } },
}

local settings = {}
for k, v in pairs(DEFAULTS) do settings[k] = v end
pcall(function()
	if readfile and isfile and isfile(SAVE_FILE) then
		local saved = HttpService:JSONDecode(readfile(SAVE_FILE))
		if type(saved) == "table" then
			for k in pairs(DEFAULTS) do
				if saved[k] ~= nil and type(saved[k]) == type(DEFAULTS[k]) then settings[k] = saved[k] end
			end
		end
	end
end)

local save -- (writes the picks; the window, below, adds where it is)
save = function()
	if not writefile then return end
	pcall(function() writefile(SAVE_FILE, HttpService:JSONEncode(settings)) end)
end

local status = "" -- shown at the bottom of the window

-- TECHNOLOGY
local techApplied = "Game"
local function applyTech()
	local want = settings.tech
	if want == techApplied then return end
	techApplied = want
	if want == "Game" then
		giveBack("Technology")
		giveBack("LightingStyle")
		giveBack("PrioritizeLightingQuality")
		status = "technology: the game's own"
		return
	end
	local name = (want == "Legacy") and "Compatibility" or want -- (Roblox runs Legacy as Compatibility since 2019)
	local okEnum, tech = pcall(function() return Enum.Technology[name] end)
	local techOk = okEnum and setLighting("Technology", tech)
	local styleOk = false
	local style = STYLE_FOR[want]
	if StyleEnum and style then
		setLighting("LightingStyle", StyleEnum[style[1]])
		-- (a game can read the new setting and still draw the old one until the quality setting really changes:
		-- it is switched the other way and back)
		setLighting("PrioritizeLightingQuality", not style[2])
		task.wait(0.15)
		if stopped or settings.tech ~= want then return end
		styleOk = setLighting("PrioritizeLightingQuality", style[2])
	end
	status = "technology: " .. (techOk and name or ("the executor refused " .. name .. (styleOk and " (lighting style set)" or "")))
end

-- SHADOWS
local function applyShadows()
	if settings.shadows == "game" then giveBack("GlobalShadows") else setLighting("GlobalShadows", settings.shadows == "on") end
end

-- NO ENVIRONMENT LIGHT (2019's reflections of the sky; none before)
local function applyEnv()
	if settings.noEnvLight then
		setLighting("EnvironmentDiffuseScale", 0)
		setLighting("EnvironmentSpecularScale", 0)
	else
		giveBack("EnvironmentDiffuseScale")
		giveBack("EnvironmentSpecularScale")
	end
end

-- RETRO TONE and OLD GRAPHICS COLOURS: effects of this script's own
local made = {}
local function ownEffect(key, class, props, on)
	local e = made[key]
	if on and not (e and e.Parent) then
		local ok, inst = pcall(function()
			local x = Instance.new(class)
			x.Name = "RetroLighting" .. key
			for k, v in pairs(props) do x[k] = v end
			x:SetAttribute("BPRetroLighting", true)
			x.Parent = Lighting
			return x
		end)
		made[key] = ok and inst or nil
	elseif not on and e then
		pcall(function() e:Destroy() end)
		made[key] = nil
	end
end
local function applyTone()
	ownEffect("Tone", "ColorGradingEffect", { TonemapperPreset = Enum.TonemapperPreset.Retro }, settings.retroTone)
end
local function applyColors()
	ownEffect("Colors", "ColorCorrectionEffect", { Saturation = 0, Contrast = -0.1 }, settings.oldColors)
end

-- NO MODERN EFFECTS: the game's bloom, sun rays, blur and depth of field off, its atmosphere cleared; kept that way
-- if the game switches them back, all given back when switched off
local effectWatch = {} -- instance -> { props = { prop = game's value }, conns = {} }
local function holdEffect(e)
	if effectWatch[e] or e:GetAttribute("BPRetroLighting") then return end
	local want
	if e:IsA("BloomEffect") or e:IsA("SunRaysEffect") or e:IsA("BlurEffect") or e:IsA("DepthOfFieldEffect") then
		want = { Enabled = false }
	elseif e:IsA("Atmosphere") then
		want = { Density = 0, Haze = 0, Glare = 0 }
	else
		return
	end
	local rec = { props = {}, conns = {} }
	effectWatch[e] = rec
	for prop, value in pairs(want) do
		rec.props[prop] = read(e, prop)
		pcall(function() e[prop] = value end)
		table.insert(rec.conns, e:GetPropertyChangedSignal(prop):Connect(function()
			if read(e, prop) ~= value then
				rec.props[prop] = read(e, prop)
				pcall(function() e[prop] = value end)
			end
		end))
	end
end
local effectsAdded
local function applyEffects()
	if settings.noEffects then
		for _, e in ipairs(Lighting:GetChildren()) do holdEffect(e) end
		local cam = workspace.CurrentCamera
		if cam then for _, e in ipairs(cam:GetChildren()) do holdEffect(e) end end
		if not effectsAdded then
			effectsAdded = Lighting.ChildAdded:Connect(function(e)
				task.defer(function() if settings.noEffects and not stopped then holdEffect(e) end end)
			end)
		end
	else
		if effectsAdded then effectsAdded:Disconnect() effectsAdded = nil end
		for e, rec in pairs(effectWatch) do
			for _, c in ipairs(rec.conns) do c:Disconnect() end
			for prop, value in pairs(rec.props) do pcall(function() e[prop] = value end) end
		end
		effectWatch = {}
	end
end

-- LIGHTS WITHOUT SHADOWS (lamps cast no shadows before 2019's ShadowMap / Future)
local lightWatch = {} -- light -> its own Shadows
local lightsAdded
local function holdLight(l)
	if lightWatch[l] ~= nil or not l:IsA("Light") then return end
	local before = read(l, "Shadows")
	if before == nil then return end
	lightWatch[l] = before
	pcall(function() l.Shadows = false end)
end
local function applyLights()
	if settings.lightsNoShadows then
		if not lightsAdded then
			for _, l in ipairs(workspace:GetDescendants()) do
				if l:IsA("Light") then holdLight(l) end
			end
			lightsAdded = workspace.DescendantAdded:Connect(function(l)
				if settings.lightsNoShadows and not stopped and l:IsA("Light") then holdLight(l) end
			end)
		end
	else
		if lightsAdded then lightsAdded:Disconnect() lightsAdded = nil end
		for l, before in pairs(lightWatch) do pcall(function() if l.Shadows == false then l.Shadows = before end end) end
		lightWatch = {}
	end
end

local refreshWindow -- (the window, below)
local function others()
	local list = {}
	if genv.BPVoxelLightingOn then list[#list + 1] = "voxel lighting" end
	if type(genv.LegacyLightingStop) == "function" then list[#list + 1] = "iw legacy lighting" end
	if genv.BPLegacyLightingOn then list[#list + 1] = "legacy lighting" end
	return list
end

local function applyAll()
	if stopped then return end
	pcall(applyShadows)
	pcall(applyEnv)
	pcall(applyTone)
	pcall(applyColors)
	pcall(applyEffects)
	pcall(applyLights)
	if refreshWindow then pcall(refreshWindow) end
	task.spawn(function()
		pcall(applyTech)
		local clash = others()
		if #clash > 0 then status = status .. " | Hammer stuff's " .. table.concat(clash, ", ") .. " also on" end
		if refreshWindow then pcall(refreshWindow) end
	end)
	save()
end

----------------------------------------------------------------------------------------------------
-- the window (made for phones too: bigger buttons on a touch screen, a whole option row is tappable, it scrolls
-- when it is taller than the screen, it can't be dragged off the screen, and it remembers where it was and
-- whether it was folded up)
----------------------------------------------------------------------------------------------------
local parent = nil
pcall(function() parent = gethui and gethui() end)
if not parent then parent = game:GetService("CoreGui") end
local old = parent:FindFirstChild("RetroLightingGui")
if old then old:Destroy() end

local TOUCH = UserInputService.TouchEnabled == true
local S = TOUCH and {
	width = 300, title = 36, button = 36, gap = 6, box = 32, row = 40, text = 17, small = 14, heading = 16,
} or {
	width = 250, title = 28, button = 24, gap = 4, box = 22, row = 26, text = 14, small = 12, heading = 14,
}

local GREY, DARK, LIGHT, TEXT = Color3.fromRGB(64, 64, 64), Color3.fromRGB(32, 32, 32), Color3.fromRGB(110, 110, 110), Color3.new(1, 1, 1)
local PICKED = Color3.fromRGB(0, 120, 215)

-- where the window was, and whether it was folded up (kept apart from the lighting picks)
local place = { x = nil, y = nil, minimized = false }
pcall(function()
	if readfile and isfile and isfile(SAVE_FILE) then
		local saved = HttpService:JSONDecode(readfile(SAVE_FILE))
		if type(saved) == "table" and type(saved.window) == "table" then
			if type(saved.window.x) == "number" then place.x = saved.window.x end
			if type(saved.window.y) == "number" then place.y = saved.window.y end
			place.minimized = saved.window.minimized == true
		end
	end
end)
save = function()
	if not writefile then return end
	pcall(function()
		local t = {}
		for k, v in pairs(settings) do t[k] = v end
		t.window = { x = place.x, y = place.y, minimized = place.minimized }
		writefile(SAVE_FILE, HttpService:JSONEncode(t))
	end)
end

local gui = Instance.new("ScreenGui")
gui.Name = "RetroLightingGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local window = Instance.new("Frame")
window.Name = "Window"
window.Size = UDim2.new(0, S.width, 0, S.title)
window.Position = UDim2.new(0.5, -S.width / 2, 0, 8)
window.BackgroundColor3 = GREY
window.BorderColor3 = DARK
window.Active = true
window.Parent = gui

local titleBar = Instance.new("TextButton") -- (a button, so dragging it doesn't move the camera on a phone)
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, S.title)
titleBar.BackgroundTransparency = 1
titleBar.Text = ""
titleBar.AutoButtonColor = false
titleBar.Parent = window

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -(S.title * 2 + 16), 1, 0)
title.Position = UDim2.new(0, 8, 0, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.SourceSansBold
title.TextSize = S.text + 2
title.TextColor3 = TEXT
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Retro Lighting"
title.Parent = titleBar

local function smallButton(text, fromRight)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, S.title - 6, 0, S.title - 6)
	b.Position = UDim2.new(1, -fromRight * (S.title - 2) - 2, 0, 3)
	b.BackgroundColor3 = LIGHT
	b.BorderColor3 = DARK
	b.Font = Enum.Font.SourceSansBold
	b.TextSize = S.text + 2
	b.TextColor3 = TEXT
	b.Text = text
	b.Parent = window
	return b
end
local minimize = smallButton("-", 2)
local close = smallButton("X", 1)

-- everything under the title bar, in a list that scrolls when it is taller than the screen
local body = Instance.new("ScrollingFrame")
body.Name = "Body"
body.Position = UDim2.new(0, 0, 0, S.title)
body.Size = UDim2.new(1, 0, 0, 0)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollingDirection = Enum.ScrollingDirection.Y
body.ScrollBarThickness = TOUCH and 8 or 6
body.ScrollBarImageColor3 = Color3.fromRGB(200, 200, 200)
body.ElasticBehavior = Enum.ElasticBehavior.Never
body.Parent = window

local inner = S.width - 16 - body.ScrollBarThickness -- (room left of the scroll bar)
local y = 4
local function heading(text)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(0, inner, 0, S.heading + 6)
	l.Position = UDim2.new(0, 8, 0, y)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.SourceSansBold
	l.TextSize = S.heading
	l.TextColor3 = Color3.fromRGB(255, 220, 120)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = body
	y += S.heading + 8
end

local function button(text, x, w, h)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, w, 0, h or S.button)
	b.Position = UDim2.new(0, x, 0, y)
	b.BackgroundColor3 = LIGHT
	b.BorderColor3 = DARK
	b.Font = Enum.Font.SourceSans
	b.TextSize = S.text
	b.TextColor3 = TEXT
	b.TextWrapped = true
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = body
	return b
end

-- era looks: two a row
heading("Era")
local eraButtons = {}
local half = math.floor((inner - S.gap) / 2)
for i, era in ipairs(ERAS) do
	local col = (i - 1) % 2
	local b = button(era.name, 8 + col * (half + S.gap), half)
	eraButtons[i] = b
	table.insert(conns, b.MouseButton1Click:Connect(function()
		for k, v in pairs(DEFAULTS) do settings[k] = v end
		for k, v in pairs(era.set) do settings[k] = v end
		applyAll()
	end))
	if col == 1 then y += S.button + S.gap end
end
y += 4

-- technology: three a row
heading("Technology")
local techButtons = {}
local third = math.floor((inner - 2 * S.gap) / 3)
for i, name in ipairs(TECHS) do
	local col = (i - 1) % 3
	local b = button(name, 8 + col * (third + S.gap), third)
	techButtons[name] = b
	table.insert(conns, b.MouseButton1Click:Connect(function()
		settings.tech = name
		applyAll()
	end))
	if col == 2 or i == #TECHS then y += S.button + S.gap end
end
y += 4

-- options: a box each; the whole row can be tapped
heading("Options")
local OPTIONS = {
	{ key = "shadows", label = "Shadows" },
	{ key = "retroTone", label = "Retro tone" },
	{ key = "noEffects", label = "No modern effects" },
	{ key = "oldColors", label = "Old Graphics colours" },
	{ key = "lightsNoShadows", label = "Lights without shadows" },
	{ key = "noEnvLight", label = "No environment light" },
}
local boxes = {}
for _, opt in ipairs(OPTIONS) do
	local row = Instance.new("TextButton")
	row.Name = "Option_" .. opt.key
	row.Size = UDim2.new(0, inner, 0, S.row - 4)
	row.Position = UDim2.new(0, 8, 0, y)
	row.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	row.BackgroundTransparency = 0.6
	row.BorderSizePixel = 0
	row.AutoButtonColor = true
	row.Text = ""
	row.Parent = body
	local box = Instance.new("TextLabel")
	box.Name = "Box"
	box.Size = UDim2.new(0, S.box, 0, S.box)
	box.Position = UDim2.new(0, 2, 0.5, -S.box / 2)
	box.BackgroundColor3 = LIGHT
	box.BorderColor3 = DARK
	box.Font = Enum.Font.SourceSansBold
	box.TextSize = S.text + 4
	box.TextColor3 = TEXT
	box.Text = ""
	box.Parent = row
	local l = Instance.new("TextLabel")
	l.Name = "Label"
	l.Size = UDim2.new(1, -(S.box + 12), 1, 0)
	l.Position = UDim2.new(0, S.box + 10, 0, 0)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.SourceSans
	l.TextSize = S.text
	l.TextColor3 = TEXT
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Text = opt.label
	l.Parent = row
	boxes[opt.key] = { box = box, label = l, row = row, opt = opt }
	table.insert(conns, row.MouseButton1Click:Connect(function()
		if opt.key == "shadows" then
			-- the game's own -> on -> off -> the game's own
			settings.shadows = ({ game = "on", on = "off", off = "game" })[settings.shadows] or "game"
		else
			settings[opt.key] = not settings[opt.key]
		end
		applyAll()
	end))
	y += S.row
end

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(0, inner, 0, S.small * 3)
statusLabel.Position = UDim2.new(0, 8, 0, y + 2)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.SourceSans
statusLabel.TextSize = S.small
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Text = ""
statusLabel.Parent = body
y += S.small * 3 + 8

local CONTENT_HEIGHT = y
body.CanvasSize = UDim2.new(0, 0, 0, CONTENT_HEIGHT)

-- the screen's size (without the top bar), for fitting and for keeping the window on it
local function screenSize()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
	local inset = 36
	pcall(function() inset = game:GetService("GuiService"):GetGuiInset().Y end)
	return vp.X, vp.Y - inset
end

-- keeps the window on the screen (it can still be dragged anywhere on it)
local function keepOnScreen()
	local w, h = screenSize()
	local x = window.Position.X.Offset + window.Position.X.Scale * w
	local top = window.Position.Y.Offset + window.Position.Y.Scale * h
	-- (the size this script gives it: AbsoluteSize is still 0 before the window is on the screen)
	x = math.clamp(x, 0, math.max(0, w - window.Size.X.Offset))
	top = math.clamp(top, 0, math.max(0, h - S.title))
	window.Position = UDim2.new(0, x, 0, top)
	place.x, place.y = x, top
end

local function layout()
	local _, h = screenSize()
	local top = window.Position.Y.Offset + window.Position.Y.Scale * h
	-- as tall as the list, but never past the bottom of the screen: the rest scrolls
	local room = math.max(S.row * 3, h - top - S.title - 8)
	local shown = math.min(CONTENT_HEIGHT, room)
	body.Visible = not place.minimized
	body.Size = UDim2.new(1, 0, 0, shown)
	window.Size = UDim2.new(0, S.width, 0, place.minimized and S.title or (S.title + shown))
	minimize.Text = place.minimized and "+" or "-"
end

if place.x and place.y then window.Position = UDim2.new(0, place.x, 0, place.y) end
layout()
keepOnScreen()

refreshWindow = function()
	for i, era in ipairs(ERAS) do
		local same = true
		for k, v in pairs(DEFAULTS) do
			local want = era.set[k]
			if want == nil then want = v end
			if settings[k] ~= want then same = false break end
		end
		eraButtons[i].BackgroundColor3 = same and PICKED or LIGHT
	end
	for name, b in pairs(techButtons) do b.BackgroundColor3 = (settings.tech == name) and PICKED or LIGHT end
	for key, rec in pairs(boxes) do
		if key == "shadows" then
			rec.box.Text = (settings.shadows == "on" and "✓") or (settings.shadows == "off" and "✗") or "-"
			rec.label.Text = "Shadows (" .. (settings.shadows == "game" and "the game's own" or settings.shadows) .. ")"
		else
			rec.box.Text = settings[key] and "✓" or ""
		end
	end
	statusLabel.Text = status
end
refreshWindow()

table.insert(conns, minimize.MouseButton1Click:Connect(function()
	place.minimized = not place.minimized
	layout()
	keepOnScreen()
	save()
end))

-- the screen turned or resized: fitted again
pcall(function()
	local cam = workspace.CurrentCamera
	if cam then
		table.insert(conns, cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			layout()
			keepOnScreen()
		end))
	end
end)

-- dragging by the title bar (mouse or finger)
local dragging, dragStart, startPos = nil, nil, nil
table.insert(conns, titleBar.InputBegan:Connect(function(input)
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
		dragging, dragStart, startPos = input, input.Position, window.Position
	end
end))
table.insert(conns, UserInputService.InputChanged:Connect(function(input)
	if not dragging then return end
	if input == dragging or (dragging.UserInputType == Enum.UserInputType.MouseButton1
		and input.UserInputType == Enum.UserInputType.MouseMovement) then
		local d = input.Position - dragStart
		window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		keepOnScreen()
		layout()
	end
end))
table.insert(conns, UserInputService.InputEnded:Connect(function(input)
	if not dragging then return end
	if input == dragging or input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = nil
		save()
	end
end))

gui.Parent = parent

----------------------------------------------------------------------------------------------------
-- stopping: everything given back
----------------------------------------------------------------------------------------------------
local function stop()
	if stopped then return end
	for k, v in pairs(DEFAULTS) do settings[k] = v end
	-- (the picks stay saved: only the window's X forgets them, see below)
	pcall(applyShadows)
	pcall(applyEnv)
	pcall(applyTone)
	pcall(applyColors)
	pcall(applyEffects)
	pcall(applyLights)
	pcall(applyTech)
	stopped = true
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	pcall(function() gui:Destroy() end)
	if genv.RetroLightingStop == stop then genv.RetroLightingStop = nil end
	print("[Retro Lighting] stopped: the game's own lighting is back.")
end
genv.RetroLightingStop = stop

table.insert(conns, close.MouseButton1Click:Connect(function()
	for k, v in pairs(DEFAULTS) do settings[k] = v end
	save() -- (closed with the X: next time it starts with the game's own)
	stop()
end))

applyAll()
print("[Retro Lighting] running. Pick an era or the options in its window.")
