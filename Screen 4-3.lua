--[[ SCREEN 4:3 (Addtion-Scripts) ]]
-- Hammer stuff 2's "4:3 screen": the game shown 4:3, like an old monitor.
--   * black bars on the left and right (under every GUI, over the game's 3D view)
--   * the old era GUIs (2005 - 2016: the top bar, the bottom bar, the hotbar, the player list) moved in from the
--     sides so they sit inside the 4:3 part: a padding is added to their ScreenGui (or added to the one it
--     has), so their own layouts and scripts are left as they are
--   * nothing else is moved: Bloxy's setup and hammer, the saved settings panel, the game's own GUIs, the
--     touch controls, the executor's window and Roblox's own GUIs stay where they are (moving them all in
--     made them run into each other)
-- It follows the screen (turning the phone, resizing the window) and GUIs made later.
-- getgenv().BPScreen43 = { Enable, Disable, IsOn }

local Env = (getgenv and getgenv()) or _G
if Env.BPScreen43 and type(Env.BPScreen43.Disable) == "function" then
	pcall(Env.BPScreen43.Disable)
end

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local ASPECT = 4 / 3
-- "Paradox" in the name: the game GUI hider leaves it alone
local BARS_NAME = "ParadoxScreen43Bars"
local PAD_NAME = "BPScreen43Padding"
-- the old era GUIs moved in to the 4:3 part (nothing else is)
local ERA_GUIS = {
	Classic2010Gui = true,  -- 2005, 2006, 2008 and 2010
	Early2011Gui = true,    -- 2011
	BPOldHealthBar = true,  -- the 2011 - 2013 health bar
	NewRobloxGui = true,    -- 2012 - 2016 (the legacy package)
	CustomHealthGui = true, -- Bloxy's 2012 / 2013 health bar
}

local on = false
local connections = {}
local padded = setmetatable({}, { __mode = "k" }) -- ScreenGui -> what was done to it
local bars, leftBar, rightBar = nil, nil, nil

local function connect(signal, fn)
	local ok, c = pcall(function() return signal:Connect(fn) end)
	if ok and c then table.insert(connections, c) end
	return c
end

-- how wide each black bar is (0 when the screen is already 4:3 or narrower)
local function sideWidth()
	local camera = Workspace.CurrentCamera
	if not camera then return 0, 0 end
	local size = camera.ViewportSize
	local width = size.Y * ASPECT
	if size.X <= width + 1 then return 0, size.X end
	return math.floor((size.X - width) / 2), size.X
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

local function skip(gui)
	return not (gui:IsA("ScreenGui") and ERA_GUIS[gui.Name])
end

-- a GUI's pieces moved in from the sides: its own area on the screen (it may already stay out of the
-- phone's notch), less what is under the bars
local function padGui(gui)
	if not on or skip(gui) then return end
	local side, screenWidth = sideWidth()
	local entry = padded[gui]
	if not entry then
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
		padded[gui] = entry
		entry.conns = {}
		-- (the GUI's own scale: the 2008 and 2011 GUIs are shown smaller on a phone, and the padding with them)
		local scaler = gui:FindFirstChildOfClass("UIScale")
		if scaler then
			entry.scaler = scaler
			table.insert(entry.conns, scaler:GetPropertyChangedSignal("Scale"):Connect(function()
				task.defer(padGui, gui)
			end))
		end
		if not entry.ours then
			-- (the GUI's own code changing its padding: that is its new one, the bars' added on top again)
			for _, prop in ipairs({ "PaddingLeft", "PaddingRight" }) do
				local c = theirs:GetPropertyChangedSignal(prop):Connect(function()
					local key = (prop == "PaddingLeft") and "left" or "right"
					local mine = (prop == "PaddingLeft") and entry.setLeft or entry.setRight
					if theirs[prop] ~= mine then
						entry[key] = theirs[prop]
						task.defer(padGui, gui)
					end
				end)
				table.insert(entry.conns, c)
			end
		end
	end
	local pos, size = gui.AbsolutePosition, gui.AbsoluteSize
	local left = math.max(0, side - pos.X)
	local right = math.max(0, (pos.X + size.X) - (screenWidth - side))
	if side <= 0 then left, right = 0, 0 end
	local scale = (entry.scaler and entry.scaler.Parent == gui and entry.scaler.Scale > 0) and entry.scaler.Scale or 1
	left, right = math.ceil(left / scale), math.ceil(right / scale)
	entry.setLeft = UDim.new(entry.left.Scale, entry.left.Offset + left)
	entry.setRight = UDim.new(entry.right.Scale, entry.right.Offset + right)
	if entry.pad.PaddingLeft ~= entry.setLeft then entry.pad.PaddingLeft = entry.setLeft end
	if entry.pad.PaddingRight ~= entry.setRight then entry.pad.PaddingRight = entry.setRight end
end

local function unpadGui(gui, entry)
	for _, c in ipairs(entry.conns or {}) do pcall(function() c:Disconnect() end) end
	if entry.ours then
		pcall(function() entry.pad:Destroy() end)
	else
		pcall(function()
			entry.pad.PaddingLeft = entry.left
			entry.pad.PaddingRight = entry.right
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
	local side = sideWidth()
	if leftBar then leftBar.Size = UDim2.new(0, side, 1, 0) end
	if rightBar then rightBar.Size = UDim2.new(0, side, 1, 0) end
	for _, holder in ipairs(holders()) do
		for _, gui in ipairs(holder:GetChildren()) do
			pcall(padGui, gui)
		end
	end
end

local function watchCamera()
	local camera = Workspace.CurrentCamera
	if camera then
		connect(camera:GetPropertyChangedSignal("ViewportSize"), function() task.defer(refresh) end)
	end
end

local api = {}

function api.Enable()
	if on then return end
	on = true
	makeBars()
	watchCamera()
	connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
		watchCamera()
		task.defer(refresh)
	end)
	for _, holder in ipairs(holders()) do
		connect(holder.ChildAdded, function(child)
			-- (a GUI's own pieces are often made right after it)
			task.delay(0.1, function() pcall(padGui, child) end)
		end)
	end
	refresh()
	local side = sideWidth()
	print("[4:3 screen] On: black bars on the sides (" .. side .. " wide each) and the old era GUIs moved in to the 4:3 part")
end

function api.Disable()
	on = false
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	table.clear(connections)
	for gui, entry in pairs(padded) do unpadGui(gui, entry) end
	table.clear(padded)
	if bars then pcall(function() bars:Destroy() end) end
	bars, leftBar, rightBar = nil, nil, nil
	print("[4:3 screen] Off: the whole screen again")
end

function api.IsOn()
	return on
end

Env.BPScreen43 = api
api.Enable()
