--[[ OLD GUI FIX (Addtion-Scripts) ]]
-- Bloxy's 2012 and 2013 GUIs (the legacy package's "NewRobloxGui"):
--   * their menu (and its other windows: help, report, save) is drawn above the hotbar: the menu sits at
--     ZIndex 1 - 5 and the hotbar's slot numbers at 4 - 9 in the same GUI, so the numbers showed through it
--   * while the menu is open, the GUI is put above every other GUI (a hotbar or inventory of another GUI
--     showed through the menu too)
--   * on a phone the menu (only the menu: the rest of the GUI keeps its size) is shown at a PC's size, so it
--     doesn't look zoomed in and fits on the screen (it ran past its top and bottom)
-- On a phone it also tells the safe chat to show at the same size for the GUIs before 2014 and 2013 mobile
-- (getgenv().BPSafeChatScale, read by Better SafeChat.lua).
-- 2013 mobile has its own layout and is left as it is.

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

local function onPhone()
	local ok, result = pcall(function()
		return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	end)
	return ok and result == true
end

-- what the topbar asks for: 2012 / 2013 (not 2013 mobile) get the menu raised (and zoomed down on a phone)
local function wanted()
	local pick = topbarPick()
	local year = pick and tonumber(string.match(pick, "(20%d%d)"))
	local mobile = pick ~= nil and string.find(pick, "mobile", 1, true) ~= nil
	local fix = (year == 2012 or year == 2013) and not mobile
	-- the safe chat's size: the GUIs before 2014 and 2013 mobile, on a phone
	local safeChat = onPhone() and year ~= nil and (year < 2014 or mobile)
	return fix, fix and onPhone(), safeChat
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

--========================================================
-- APPLYING IT
--========================================================
local said = {}
local function fixGui(gui)
	local fix, zoom = wanted()
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

	local key = tostring(gui) .. tostring(scale)
	if not said[key] then
		said[key] = true
		print("[Old Gui Fix] the 2012 / 2013 GUI: menu above the hotbar"
			.. (scale ~= 1 and (", the menu at a PC's size on this phone (" .. math.floor(scale * 100) .. "%)") or ""))
	end
end

local watched = setmetatable({}, { __mode = "k" })
local function watchGui(gui)
	if watched[gui] or gui.Name ~= "NewRobloxGui" then return end
	watched[gui] = true
	-- the menu windows and the hotbar are made a little after the GUI
	gui.ChildAdded:Connect(function() task.delay(0.2, function() pcall(fixGui, gui) end) end)
	local controls = gui:FindFirstChild("ControlFrame")
	if controls then
		controls.ChildAdded:Connect(function() task.delay(0.2, function() pcall(fixGui, gui) end) end)
	end
	pcall(fixGui, gui)
end

task.spawn(function()
	for _, child in ipairs(CoreGui:GetChildren()) do pcall(watchGui, child) end
	CoreGui.ChildAdded:Connect(function(child)
		task.defer(function() pcall(watchGui, child) end)
	end)
	-- the topbar is picked after this starts (and can change): looked at again every few seconds
	while true do
		local _, _, safeChat = wanted()
		Env.BPSafeChatScale = safeChat and PC_SCALE or nil
		for gui in pairs(watched) do
			if gui.Parent then pcall(fixGui, gui) end
		end
		task.wait(3)
	end
end)
