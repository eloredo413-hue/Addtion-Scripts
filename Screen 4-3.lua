--[[ SCREEN 4:3 (Addtion-Scripts) ]]
-- Hammer stuff 2's "4:3 screen": the game shown 4:3, like an old monitor.
--   * black bars on the left and right (under every GUI, over the game's 3D view), sized from the screen
--     they are drawn on (the camera's viewport size isn't always the screen's on a phone)
--   * the old era GUIs (2005 - 2016: the top bar, the bottom bar, the hotbar, the player list) and the touch
--     controls (joystick, jump) moved in from the sides so they sit inside the 4:3 part: a padding is added to
--     their ScreenGui (or added to the one it has). Where each GUI's area really ends up is measured (a
--     see-through frame the size of its area) and the padding corrected, so it fits however the GUI is scaled.
--   * the 2005 - 2011 GUIs are also shown as big as they would be on a 4:3 screen (they size themselves from
--     the whole screen's width, so in the narrower part their pieces ran into each other)
--   * nothing else is moved: Bloxy's setup and hammer, the saved settings panel, the game's own GUIs, the
--     executor's window and Roblox's own GUIs stay where they are (moving them all in made them run into each
--     other)
-- It follows the screen (turning the phone, resizing the window) and GUIs made later.
-- getgenv().BPScreen43 = { Enable, Disable, IsOn }

local Env = (getgenv and getgenv()) or _G
if Env.BPScreen43 and type(Env.BPScreen43.Disable) == "function" then
	pcall(Env.BPScreen43.Disable)
end

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local ASPECT = 4 / 3
-- "Paradox" in the name: the game GUI hider leaves it alone
local BARS_NAME = "ParadoxScreen43Bars"
local PAD_NAME = "BPScreen43Padding"
local PROBE_NAME = "BPScreen43Probe"
-- what is moved in to the 4:3 part (nothing else is)
local MOVED = {
	Classic2010Gui = true,  -- 2005, 2006, 2008 and 2010
	Early2011Gui = true,    -- 2011
	BPOldHealthBar = true,  -- the 2011 - 2013 health bar
	NewRobloxGui = true,    -- 2012 - 2016 (the legacy package)
	CustomHealthGui = true, -- Bloxy's 2012 / 2013 health bar
	TouchGui = true,        -- the joystick and the jump button
}
-- The GUIs that size themselves (a UIScale) from the screen: the size each was made for, so they are shown
-- as big as on a 4:3 screen of the same height (never bigger than they make themselves).
local DESIGN = {
	Classic2010Gui = { width = 1200, height = 900, low = 0.35, high = 1 },
	Early2011Gui = { width = 1200, height = 720, low = 0.35, high = 1.25 },
	BPOldHealthBar = { width = 1200, height = 720, low = 0.35, high = 1.25 },
}

local on = false
local connections = {}
local moved = setmetatable({}, { __mode = "k" }) -- ScreenGui -> what was done to it
local bars, leftBar, rightBar = nil, nil, nil

local function connect(signal, fn)
	local ok, c = pcall(function() return signal:Connect(fn) end)
	if ok and c then table.insert(connections, c) end
	return c
end

local function waitFrames(n)
	for _ = 1, n do
		if not pcall(function() RunService.Heartbeat:Wait() end) then task.wait() end
	end
end

-- the 4:3 part of the screen: its left and right edges (on the screen) and its height
local function region()
	if not (bars and bars.Parent) then return nil end
	local pos, size = bars.AbsolutePosition, bars.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then return nil end
	local width = size.Y * ASPECT
	local side = (size.X > width + 1) and math.floor((size.X - width) / 2) or 0
	return pos.X + side, pos.X + size.X - side, size.Y, side
end

local function holders()
	local list = {}
	pcall(function()
		local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if playerGui then table.insert(list, playerGui) end
	end)
	table.insert(list, CoreGui)
	pcall(function()
		local hui = gethui and gethui()
		if hui and hui ~= CoreGui then table.insert(list, hui) end
	end)
	return list
end

-- the padding (ours added to the GUI's own) and the scale
local function setPadding(entry, left, right)
	entry.addLeft, entry.addRight = math.max(0, math.ceil(left)), math.max(0, math.ceil(right))
	entry.setLeft = UDim.new(entry.left.Scale, entry.left.Offset + entry.addLeft)
	entry.setRight = UDim.new(entry.right.Scale, entry.right.Offset + entry.addRight)
	if entry.pad.PaddingLeft ~= entry.setLeft then entry.pad.PaddingLeft = entry.setLeft end
	if entry.pad.PaddingRight ~= entry.setRight then entry.pad.PaddingRight = entry.setRight end
end

local function setScale(gui, entry)
	local design = DESIGN[gui.Name]
	local scaler = entry.scaler
	if not (design and scaler and scaler.Parent == gui) then return end
	local theirs = entry.theirScale or scaler.Scale
	local want = theirs
	local left, right, height = region()
	if left and right - left > 0 then
		local fit = math.min((right - left) / design.width, height / design.height)
		fit = math.clamp(fit, design.low, design.high)
		want = math.min(theirs, fit)
	end
	entry.ourScale = want
	if scaler.Scale ~= want then scaler.Scale = want end
end

-- where the GUI's area is on the screen now (its probe: a see-through frame the size of its area)
local function measure(entry)
	local probe = entry.probe
	if not (probe and probe.Parent) then return nil end
	local pos, size = probe.AbsolutePosition, probe.AbsoluteSize
	return pos.X, pos.X + size.X
end

-- 2012's hotbar is centred by its own script from the whole screen's width (an offset), so under the padding
-- it sat off to the right: it is centred in the GUI's area instead while this is on.
local function centreLoadout(gui, entry)
	local loadout = gui:FindFirstChild("CurrentLoadout")
	if not (loadout and loadout:IsA("GuiObject")) then return end
	local function fix()
		if not on or moved[gui] ~= entry then return end
		local p = loadout.Position
		if p.X.Scale == 0 and p ~= entry.loadoutOurs then
			entry.loadoutTheirs = p
			entry.loadoutOurs = UDim2.new(0.5, -loadout.AbsoluteSize.X / 2, p.Y.Scale, p.Y.Offset)
			loadout.Position = entry.loadoutOurs
		end
	end
	if not entry.loadoutWatched then
		entry.loadoutWatched = true
		entry.loadout = loadout
		table.insert(entry.conns, loadout:GetPropertyChangedSignal("Position"):Connect(function() task.defer(fix) end))
	end
	fix()
end

local fitGui
local function prepare(gui)
	local entry = moved[gui]
	if entry then return entry end
	local theirs = nil
	for _, child in ipairs(gui:GetChildren()) do
		if child:IsA("UIPadding") and child.Name ~= PAD_NAME then theirs = child break end
	end
	if theirs then
		entry = { pad = theirs, ours = false, left = theirs.PaddingLeft, right = theirs.PaddingRight }
	else
		local pad = Instance.new("UIPadding")
		pad.Name = PAD_NAME
		entry = { pad = pad, ours = true, left = UDim.new(0, 0), right = UDim.new(0, 0) }
		pad.Parent = gui
	end
	entry.conns = {}
	entry.token = 0
	entry.addLeft, entry.addRight = 0, 0
	moved[gui] = entry

	local probe = Instance.new("Frame")
	probe.Name = PROBE_NAME
	probe.Size = UDim2.new(1, 0, 1, 0)
	probe.Position = UDim2.new(0, 0, 0, 0)
	probe.BackgroundTransparency = 1
	probe.Active = false
	probe.Visible = false
	probe.Parent = gui
	entry.probe = probe

	if DESIGN[gui.Name] then
		local scaler = gui:FindFirstChildOfClass("UIScale")
		if scaler then
			entry.scaler = scaler
			entry.theirScale = scaler.Scale
			-- (the GUI sets its own scale when the screen changes: that is its new one, ours worked out again)
			table.insert(entry.conns, scaler:GetPropertyChangedSignal("Scale"):Connect(function()
				if scaler.Scale ~= entry.ourScale then
					entry.theirScale = scaler.Scale
					task.defer(fitGui, gui)
				end
			end))
		end
	end
	if not entry.ours then
		-- (the GUI's own code changing its padding: that is its new one, ours added on top again)
		for _, prop in ipairs({ "PaddingLeft", "PaddingRight" }) do
			table.insert(entry.conns, theirs:GetPropertyChangedSignal(prop):Connect(function()
				local key = (prop == "PaddingLeft") and "left" or "right"
				local mine = (prop == "PaddingLeft") and entry.setLeft or entry.setRight
				if theirs[prop] ~= mine then
					entry[key] = theirs[prop]
					task.defer(fitGui, gui)
				end
			end))
		end
	end
	return entry
end

-- moves one GUI in: its scale, then its padding, measured and corrected
fitGui = function(gui)
	if not on or not (gui:IsA("ScreenGui") and MOVED[gui.Name]) or not gui.Parent then return end
	local entry = prepare(gui)
	entry.token = entry.token + 1
	local token = entry.token
	task.spawn(function()
		setScale(gui, entry)
		local left, right = region()
		if not left then return end
		-- where its area is without our padding
		setPadding(entry, 0, 0)
		waitFrames(2)
		if token ~= entry.token or not on then return end
		local x0, x1 = measure(entry)
		if not x0 then return end
		local needLeft, needRight = math.max(0, left - x0), math.max(0, x1 - right)
		if needLeft < 0.5 and needRight < 0.5 then return end
		-- a first guess (the padding is in the GUI's own units), then corrected from where that put it
		local scale = (entry.scaler and entry.scaler.Scale > 0) and entry.scaler.Scale or 1
		local guessLeft, guessRight = needLeft / scale, needRight / scale
		setPadding(entry, guessLeft, guessRight)
		waitFrames(2)
		if token ~= entry.token or not on then return end
		for _ = 1, 2 do
			local y0, y1 = measure(entry)
			if not y0 then return end
			local errLeft, errRight = left - y0, y1 - right
			if math.abs(errLeft) < 1 and math.abs(errRight) < 1 then break end
			-- (how far one unit of padding moves the edge, from the two measurements)
			local kLeft = guessLeft > 0 and (y0 - x0) / guessLeft or 0
			local kRight = guessRight > 0 and (x1 - y1) / guessRight or 0
			if kLeft > 0.05 then guessLeft = needLeft / kLeft end
			if kRight > 0.05 then guessRight = needRight / kRight end
			setPadding(entry, guessLeft, guessRight)
			waitFrames(2)
			if token ~= entry.token or not on then return end
		end
		if gui.Name == "NewRobloxGui" then pcall(centreLoadout, gui, entry) end
	end)
end

local function undo(gui, entry)
	entry.token = (entry.token or 0) + 1
	for _, c in ipairs(entry.conns or {}) do pcall(function() c:Disconnect() end) end
	if entry.ours then
		pcall(function() entry.pad:Destroy() end)
	else
		pcall(function()
			entry.pad.PaddingLeft = entry.left
			entry.pad.PaddingRight = entry.right
		end)
	end
	pcall(function() entry.probe:Destroy() end)
	if entry.scaler and entry.theirScale then
		pcall(function() entry.scaler.Scale = entry.theirScale end)
	end
	if entry.loadout and entry.loadoutTheirs and entry.loadout.Position == entry.loadoutOurs then
		pcall(function()
			-- (centred again the way its own script does it: from the whole screen's width)
			local width = gui.AbsoluteSize.X
			local p = entry.loadoutTheirs
			entry.loadout.Position = UDim2.new(0, width / 2 - entry.loadout.AbsoluteSize.X / 2, p.Y.Scale, p.Y.Offset)
		end)
	end
end

local function makeBars()
	local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	bars = Instance.new("ScreenGui")
	bars.Name = BARS_NAME
	bars.ResetOnSpawn = false
	bars.IgnoreGuiInset = true
	pcall(function() bars.ScreenInsets = Enum.ScreenInsets.None end)
	pcall(function() bars.ClipToDeviceSafeArea = false end)
	-- under every other GUI (the game's too), over the 3D view
	bars.DisplayOrder = -2147483647
	bars.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local function bar(name, anchorX)
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BorderSizePixel = 0
		frame.Active = false
		frame.AnchorPoint = Vector2.new(anchorX, 0)
		frame.Position = UDim2.new(anchorX, 0, 0, 0)
		frame.Size = UDim2.new(0, 0, 1, 0)
		frame.Parent = bars
		return frame
	end
	leftBar = bar("Left", 0)
	rightBar = bar("Right", 1)
	bars.Parent = playerGui or CoreGui
end

local function refresh()
	if not on then return end
	local _, _, _, side = region()
	side = side or 0
	if leftBar then leftBar.Size = UDim2.new(0, side, 1, 0) end
	if rightBar then rightBar.Size = UDim2.new(0, side, 1, 0) end
	for _, holder in ipairs(holders()) do
		for _, gui in ipairs(holder:GetChildren()) do
			pcall(fitGui, gui)
		end
	end
end

local api = {}

function api.Enable()
	if on then return end
	on = true
	makeBars()
	-- (the screen they are drawn on: turning the phone, resizing the window)
	connect(bars:GetPropertyChangedSignal("AbsoluteSize"), function() task.defer(refresh) end)
	for _, holder in ipairs(holders()) do
		connect(holder.ChildAdded, function(child)
			-- (a GUI's own pieces are often made right after it)
			task.delay(0.2, function() pcall(fitGui, child) end)
		end)
	end
	task.spawn(function()
		waitFrames(2) -- (the bars' size is known a frame after they are made)
		refresh()
		local _, _, _, side = region()
		print("[4:3 screen] On: black bars on the sides (" .. tostring(side) .. " wide each); the old era GUIs and"
			.. " the touch controls moved in to the 4:3 part")
	end)
end

function api.Disable()
	on = false
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	table.clear(connections)
	for gui, entry in pairs(moved) do undo(gui, entry) end
	table.clear(moved)
	if bars then pcall(function() bars:Destroy() end) end
	bars, leftBar, rightBar = nil, nil, nil
	print("[4:3 screen] Off: the whole screen again")
end

function api.IsOn()
	return on
end

Env.BPScreen43 = api
api.Enable()
