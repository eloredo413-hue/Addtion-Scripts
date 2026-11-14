--[[ OLD GUI FIX (Addtion-Scripts) ]]
-- Bloxy's 2012 and 2013 GUIs (the legacy package's "NewRobloxGui"):
--   * their menu (and its other windows: help, report, save) is drawn above the hotbar: the menu sits at
--     ZIndex 1 - 5 and the hotbar's slot numbers at 4 - 9 in the same GUI, so the numbers showed through it
--   * while the menu is open, the GUI is put above every other GUI (a hotbar or inventory of another GUI
--     showed through the menu too)
--   * on a phone the menu (only the menu: the rest of the GUI keeps its size) is shown at a PC's size, so it
--     doesn't look zoomed in and fits on the screen (it ran past its top and bottom)
--   * the backpack window ("Gear") ends above the hotbar instead of running under it (on a phone it did)
-- The GUI is told by what is in it (the old menu, "UserSettingsShield"), not only by the topbar picked: the
-- topbar's name wasn't always there to read, and then nothing was done.
-- On a phone it also tells the safe chat to show at the same size for the GUIs before 2014 and 2013 mobile
-- (getgenv().BPSafeChatScale, read by Better SafeChat.lua).
-- 2013 mobile keeps its menu's size.

local Env = (getgenv and getgenv()) or _G
if Env.BPOldGuiFixLoaded then return end
Env.BPOldGuiFixLoaded = true

local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local PC_SCALE = 0.7  -- the size on a phone (the same as the safe chat's)
local LIFT = 10       -- how far the menu windows are raised above everything else in the GUI

local MENU_WINDOWS = {
	UserSettingsShield = true, HelpDialogShield = true, SaveDialogShield = true, ReportAbuseShield = true,
}

local function topbarPick()
	for _, value in ipairs({ Env.BloxyTopbarPick, Env.BP_PendingTopbar, Env.BloxyTopbarRaw }) do
		if value ~= nil and tostring(value) ~= "" and tostring(value) ~= "nil" then
			return string.lower(tostring(value))
		end
	end
	return nil
end

-- a phone (or a small tablet): a touch screen without a mouse, or a short one (some phones say they have a
-- keyboard)
local function onPhone()
	local ok, result = pcall(function()
		if not UserInputService.TouchEnabled then return false end
		if not UserInputService.MouseEnabled then return true end
		local camera = workspace.CurrentCamera
		return camera ~= nil and camera.ViewportSize.Y < 700
	end)
	return ok and result == true
end

-- a GUI with the old menu (2012 / 2013): the menu raised (and, on a phone, zoomed down; not 2013 mobile's)
local function wanted(gui)
	local pick = topbarPick()
	local year = pick and tonumber(string.match(pick, "(20%d%d)"))
	local mobile = pick ~= nil and string.find(pick, "mobile", 1, true) ~= nil
	local fix = gui ~= nil and gui:FindFirstChild("UserSettingsShield") ~= nil
	-- the safe chat's size: the GUIs before 2014 and 2013 mobile, on a phone
	local safeChat = onPhone() and year ~= nil and (year < 2014 or mobile)
	return fix, fix and onPhone() and not mobile, safeChat
end

--========================================================
-- THE MENU ABOVE THE HOTBAR
--========================================================
local raised = setmetatable({}, { __mode = "k" }) -- object -> the ZIndex set here
local function raise(obj)
	if not obj:IsA("GuiObject") or raised[obj] then return end
	raised[obj] = obj.ZIndex + LIFT
	obj.ZIndex = raised[obj]
	-- the menu's own code changes a ZIndex now and then: raised again on top of its new one
	obj:GetPropertyChangedSignal("ZIndex"):Connect(function()
		if raised[obj] and obj.ZIndex ~= raised[obj] then
			raised[obj] = obj.ZIndex + LIFT
			obj.ZIndex = raised[obj]
		end
	end)
end
local raisedWindows = setmetatable({}, { __mode = "k" })
local function raiseWindow(window)
	if raisedWindows[window] then return end
	raisedWindows[window] = true
	raise(window)
	for _, d in ipairs(window:GetDescendants()) do raise(d) end
	window.DescendantAdded:Connect(function(d) task.defer(raise, d) end)
end

--========================================================
-- A PC'S SIZE ON A PHONE
--========================================================
local function scaleOf(obj, scale)
	local s = obj:FindFirstChild("BPPcScale")
	if scale == 1 then
		if s then s:Destroy() end
		return
	end
	if not s then
		s = Instance.new("UIScale")
		s.Name = "BPPcScale"
		s.Parent = obj
	end
	if s.Scale ~= scale then s.Scale = scale end
end

-- a full-screen window (the menu's dark shield): made bigger by as much as it is zoomed down, so it still
-- covers the screen and the menu in it stays in the middle
local windowBase = setmetatable({}, { __mode = "k" })
local function fitWindow(window, scale)
	local state = windowBase[window]
	if not state then
		state = { base = window.Size }
		windowBase[window] = state
		window:GetPropertyChangedSignal("Size"):Connect(function()
			if window.Size ~= state.ours then
				state.base = window.Size
				state.ours = nil
				if state.scale and state.scale ~= 1 then fitWindow(window, state.scale) end
			end
		end)
	end
	state.scale = scale
	scaleOf(window, scale)
	local b = state.base
	local want = UDim2.new(b.X.Scale / scale, b.X.Offset, b.Y.Scale / scale, b.Y.Offset)
	if window.Size ~= want then
		state.ours = want
		window.Size = want
	end
end

-- While a menu window is open, the whole GUI goes above every other GUI (and back when it closes).
local ON_TOP = 1000000000 -- (below this script's own panels: the save disk, the safe chat)
local topWatch = setmetatable({}, { __mode = "k" })
local function keepOnTopWhileOpen(gui)
	local state = topWatch[gui]
	if not state then
		state = { order = gui.DisplayOrder, windows = setmetatable({}, { __mode = "k" }) }
		topWatch[gui] = state
	end
	local function update()
		local open = false
		for window in pairs(state.windows) do
			if window.Parent == gui and window.Visible then open = true break end
		end
		if open then
			if gui.DisplayOrder ~= ON_TOP then
				state.order = gui.DisplayOrder
				gui.DisplayOrder = ON_TOP
			end
		elseif gui.DisplayOrder == ON_TOP then
			gui.DisplayOrder = state.order
		end
	end
	for _, child in ipairs(gui:GetChildren()) do
		if MENU_WINDOWS[child.Name] and child:IsA("GuiObject") and not state.windows[child] then
			state.windows[child] = true
			child:GetPropertyChangedSignal("Visible"):Connect(update)
		end
	end
	update()
end

-- The backpack window ("Gear") opens over the middle of the screen (60% of its height, from 20% down),
-- which on a short screen runs under the hotbar. Once it has opened, it is made to end just above the hotbar
-- (a little higher up, a little shorter).
local backpackFixed = setmetatable({}, { __mode = "k" })
local function fitBackpack(gui)
	local backpack = gui:FindFirstChild("Backpack")
	local loadout = gui:FindFirstChild("CurrentLoadout")
	if not (backpack and loadout and backpack:IsA("GuiObject") and loadout:IsA("GuiObject")) then return end
	if backpackFixed[backpack] then return end
	backpackFixed[backpack] = true
	local ours = nil
	local function fit()
		if not backpack.Visible or not loadout.Visible then return end
		local size = backpack.Size
		if size == ours then return end
		-- (only once it has opened: the opening and closing tweens run through small sizes)
		if size.X.Scale < 0.5 and size.X.Offset < 200 then return end
		local guiTop = gui.AbsolutePosition.Y
		local screenH = gui.AbsoluteSize.Y
		local hotbarTop = loadout.AbsolutePosition.Y - guiTop
		local top = math.floor(screenH * 0.06)
		local bottom = math.floor(hotbarTop - 8)
		local nowBottom = backpack.AbsolutePosition.Y - guiTop + backpack.AbsoluteSize.Y
		if nowBottom <= bottom or bottom - top < 120 then return end
		ours = UDim2.new(size.X.Scale, size.X.Offset, 0, bottom - top)
		backpack.Position = UDim2.new(backpack.Position.X.Scale, backpack.Position.X.Offset, 0, top)
		backpack.Size = ours
	end
	backpack:GetPropertyChangedSignal("Size"):Connect(function() task.defer(fit) end)
	backpack:GetPropertyChangedSignal("Visible"):Connect(function() task.defer(fit) end)
	fit()
end

--========================================================
-- APPLYING IT
--========================================================
local said = {}
local function fixGui(gui)
	local fix, zoom = wanted(gui)
	if not fix then return end
	local scale = zoom and PC_SCALE or 1

	for _, child in ipairs(gui:GetChildren()) do
		if MENU_WINDOWS[child.Name] and child:IsA("GuiObject") then
			raiseWindow(child)
			pcall(fitWindow, child, scale)
		end
	end

	-- (the hotbar and the corner buttons keep their own size: only the menu is zoomed down)
	local loadout = gui:FindFirstChild("CurrentLoadout")
	if loadout and loadout:IsA("GuiObject") and loadout:FindFirstChild("BPPcScale") then
		scaleOf(loadout, 1)
	end
	local controls = gui:FindFirstChild("ControlFrame")
	if controls then
		for _, name in ipairs({ "BottomLeftControl", "BottomRightControl", "TopLeftControl" }) do
			local corner = controls:FindFirstChild(name)
			if corner and corner:FindFirstChild("BPPcScale") then scaleOf(corner, 1) end
		end
	end

	-- above every other GUI while the menu is open
	keepOnTopWhileOpen(gui)

	-- the backpack window above the hotbar
	pcall(fitBackpack, gui)

	local key = tostring(gui) .. tostring(scale)
	if not said[key] then
		said[key] = true
		print("[Old Gui Fix] the 2012 / 2013 GUI (" .. gui:GetFullName() .. ", topbar " .. tostring(topbarPick())
			.. "): menu above the hotbar, backpack above the hotbar"
			.. (scale ~= 1 and (", the menu at a PC's size on this phone (" .. math.floor(scale * 100) .. "%)") or ""))
	end
end

local watched = setmetatable({}, { __mode = "k" })
local function watchGui(gui)
	if watched[gui] or gui.Name ~= "NewRobloxGui" then return end
	watched[gui] = true
	print("[Old Gui Fix] found " .. gui:GetFullName() .. " (old menu: "
		.. tostring(gui:FindFirstChild("UserSettingsShield") ~= nil) .. ", phone: " .. tostring(onPhone())
		.. ", topbar: " .. tostring(topbarPick()) .. ")")
	-- the menu windows and the hotbar are made a little after the GUI
	gui.ChildAdded:Connect(function() task.delay(0.2, function() pcall(fixGui, gui) end) end)
	local controls = gui:FindFirstChild("ControlFrame")
	if controls then
		controls.ChildAdded:Connect(function() task.delay(0.2, function() pcall(fixGui, gui) end) end)
	end
	pcall(fixGui, gui)
end

local function holders()
	local list = { CoreGui }
	pcall(function()
		local hui = gethui and gethui()
		if hui and hui ~= CoreGui then table.insert(list, hui) end
	end)
	return list
end

task.spawn(function()
	for _, holder in ipairs(holders()) do
		pcall(function()
			holder.ChildAdded:Connect(function(child)
				task.defer(function() pcall(watchGui, child) end)
			end)
		end)
	end
	-- the topbar is picked after this starts (and can change), and the GUI can come in at any time:
	-- looked at again every few seconds (the CoreGui's own list too, in case one was missed)
	while true do
		for _, holder in ipairs(holders()) do
			pcall(function()
				local gui = holder:FindFirstChild("NewRobloxGui")
				if gui then watchGui(gui) end
			end)
		end
		local _, _, safeChat = wanted(nil)
		Env.BPSafeChatScale = safeChat and PC_SCALE or nil
		for gui in pairs(watched) do
			if gui.Parent then pcall(fixGui, gui) end
		end
		task.wait(3)
	end
end)
