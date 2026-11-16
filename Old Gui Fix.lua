--[[ OLD GUI FIX (Addtion-Scripts) ]]
-- Bloxy's 2012 and 2013 GUIs (the legacy package's "NewRobloxGui"):
--   * their menu (and its other windows: help, report, save) is drawn above the hotbar: the menu sits at
--     ZIndex 1 - 5 and the hotbar's slot numbers and items at 2 - 10 in the same GUI, so they showed
--     through it
--   * while the menu is open, the GUI is put above every other GUI (a hotbar or inventory of another GUI
--     showed through the menu too)
--   * on a phone the menu (only the menu: the rest of the GUI keeps its size) is shown smaller, at about a
--     PC's size, so it doesn't look zoomed in and fits on the screen (it ran past its top and bottom)
--   * the backpack window fits between the top of the screen and the hotbar: 2012's ("Gear") ran under the
--     hotbar, 2013's ran off the top of a phone's screen (it is then shown smaller, with its button on top)
-- The menu's windows are made inside the GUI's "ControlFrame" (the menu's own code puts them there), so
-- they are looked for there. The GUI is told by what is in it (the old menu), not only by the topbar
-- picked: the topbar's name isn't always there to read.
-- The menu's dark shade covers the whole screen (it stopped at the phone's safe area: a strip at the bottom
-- and the sides was left bright).
-- 2012's zoom and tilt buttons (bottom right) work: nothing connected them. Pressed, they show the
-- November 2012 client's pictures.
-- 2012's health bar (Bloxy's) sits next to the Backpack button, on its row, as in the 2012 client (on a phone
-- the GUI is inside the safe area and the health bar isn't, so it was lower and apart from it).
-- On a phone it also tells the safe chat to show smaller (at the same size as those GUIs) with the 2006 - 2011
-- GUIs, the ones drawn at a smaller scale; with every other GUI (2012 and later, 2013 mobile, 2005) it keeps its
-- bigger, normal size (getgenv().BPSafeChatScale, read by Better SafeChat.lua).
-- 2013 mobile keeps its menu's size. 2014 (which has the same menu) is left to its own fixes.

local Env = (getgenv and getgenv()) or _G
if Env.BPOldGuiFixLoaded then return end
Env.BPOldGuiFixLoaded = true

local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PC_SCALE = 0.7  -- the menu's size on a phone (also the safe chat's, with the 2006 - 2011 GUIs)
local MENU_HEIGHT = 430 -- the 2012 / 2013 settings window's height (it should fit on the screen)
local LIFT = 20       -- how far the menu windows are raised above everything else in the GUI (the
                      -- hotbar, backpack, chat and player list go up to ZIndex 10)

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

-- where the menu's windows are: in the GUI's ControlFrame (and, in case, the GUI itself)
local function windowHolders(gui)
	local list = {}
	local controls = gui:FindFirstChild("ControlFrame")
	if controls then table.insert(list, controls) end
	table.insert(list, gui)
	return list
end

local function menuWindows(gui)
	local found = {}
	for _, holder in ipairs(windowHolders(gui)) do
		for _, child in ipairs(holder:GetChildren()) do
			if MENU_WINDOWS[child.Name] and child:IsA("GuiObject") then table.insert(found, child) end
		end
	end
	return found
end

-- 2012 or 2013: the old menu, and not 2014 (the same menu, with its own health script)
local function isOldGui(gui)
	local pick = topbarPick()
	local year = pick and tonumber(string.match(pick, "(20%d%d)"))
	if year == 2012 or year == 2013 then return #menuWindows(gui) > 0 end
	if year ~= nil and year >= 2014 and not string.find(pick, "mobile", 1, true) then return false end
	return #menuWindows(gui) > 0 and gui:FindFirstChild("HealthScript") == nil
end

-- what is done: fix (the menu raised, the backpack fitted), zoom (on a phone, not 2013 mobile's)
local function wanted(gui)
	local pick = topbarPick()
	local mobile = pick ~= nil and string.find(pick, "mobile", 1, true) ~= nil
	local fix = gui ~= nil and isOldGui(gui)
	return fix, fix and onPhone() and not mobile
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
-- THE MENU SMALLER ON A PHONE
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

-- the menu's size on this phone: a PC's, or smaller if the settings window wouldn't fit
local function menuScale(gui)
	local height = gui.AbsoluteSize.Y
	if height <= 0 then return PC_SCALE end
	return math.max(0.4, math.min(PC_SCALE, height * 0.92 / MENU_HEIGHT))
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
local function keepOnTopWhileOpen(gui, windows)
	local state = topWatch[gui]
	if not state then
		state = { order = gui.DisplayOrder, windows = setmetatable({}, { __mode = "k" }) }
		topWatch[gui] = state
	end
	local function update()
		local open = false
		for window in pairs(state.windows) do
			if window.Parent ~= nil and window:IsDescendantOf(gui) and window.Visible then open = true break end
		end
		if open then
			if gui.DisplayOrder ~= ON_TOP then
				state.order = gui.DisplayOrder
				gui.DisplayOrder = ON_TOP
			end
		elseif gui.DisplayOrder == ON_TOP then
			gui.DisplayOrder = state.order
		end
		-- (if the GUI draws its frames by their parents' order, the menu's frame goes above the hotbar's)
		pcall(function()
			if gui.ZIndexBehavior ~= Enum.ZIndexBehavior.Sibling then return end
			local controls = gui:FindFirstChild("ControlFrame")
			if not controls then return end
			if open then
				if not state.controlsZ then state.controlsZ = controls.ZIndex end
				controls.ZIndex = 50
			elseif state.controlsZ then
				controls.ZIndex = state.controlsZ
				state.controlsZ = nil
			end
		end)
	end
	for _, window in ipairs(windows) do
		if not state.windows[window] then
			state.windows[window] = true
			window:GetPropertyChangedSignal("Visible"):Connect(update)
		end
	end
	update()
end

--========================================================
-- THE BACKPACK BETWEEN THE TOP OF THE SCREEN AND THE HOTBAR
--========================================================
-- The backpack's own code opens it with a tween to where it wants it. Each time it moves it, where it
-- wanted it is kept, and it is put where it fits instead: moved up (2012: it ran under the hotbar), or, if
-- it is taller than the room there, also shown smaller (2013 on a phone: it ran off the top of the
-- screen). 2013's backpack button, on top of the window while it is open, goes with it.

-- the GUI's area its frames are placed in (inside its padding)
local function areaOf(holder)
	local pos, size = holder.AbsolutePosition, holder.AbsoluteSize
	local x, y, w, h = pos.X, pos.Y, size.X, size.Y
	local pad = holder:FindFirstChildOfClass("UIPadding")
	if pad then
		local l = pad.PaddingLeft.Scale * size.X + pad.PaddingLeft.Offset
		local r = pad.PaddingRight.Scale * size.X + pad.PaddingRight.Offset
		local t = pad.PaddingTop.Scale * size.Y + pad.PaddingTop.Offset
		local b = pad.PaddingBottom.Scale * size.Y + pad.PaddingBottom.Offset
		x, y, w, h = x + l, y + t, w - l - r, h - t - b
	end
	return x, y, w, h
end

-- where the GUI's own code put an object (not where it was put here)
local function newSpot(obj)
	return { want = obj.Position, ours = nil }
end
local function wantedSpot(spot, obj)
	local now = obj.Position
	if spot.ours == nil or now ~= spot.ours then spot.want = now end
	return spot.want
end
local function putAt(spot, obj, position)
	if obj.Position ~= position then
		spot.ours = position
		obj.Position = position
	end
end

local backpackFixed = setmetatable({}, { __mode = "k" })
local function fitBackpack(gui)
	local backpack = gui:FindFirstChild("Backpack")
	local loadout = gui:FindFirstChild("CurrentLoadout")
	if not (backpack and loadout and backpack:IsA("GuiObject") and loadout:IsA("GuiObject")) then return end
	if backpackFixed[backpack] then return end
	backpackFixed[backpack] = true

	local controls = gui:FindFirstChild("ControlFrame")
	local button = controls and controls:FindFirstChild("BackpackButton")
	if button and not button:IsA("GuiObject") then button = nil end
	local backpackSpot = newSpot(backpack)
	local buttonSpot = button and newSpot(button)
	local scaler = nil
	local busy = false
	local said = false

	local function setScale(scale)
		if scale >= 0.999 then
			if scaler then scaler.Scale = 1 end
			return
		end
		if not scaler or scaler.Parent ~= backpack then
			scaler = Instance.new("UIScale")
			scaler.Name = "BPFitScale"
			scaler.Parent = backpack
		end
		if scaler.Scale ~= scale then scaler.Scale = scale end
	end

	local function update()
		if busy then return end
		busy = true
		local ok, err = pcall(function()
			local want = wantedSpot(backpackSpot, backpack)
			local buttonWant = button and wantedSpot(buttonSpot, button)
			local place, scale, newTop, oldTop = want, 1, nil, nil
			if backpack.Visible and loadout.Visible and backpack.Parent == gui then
				local ox, oy, aw, ah = areaOf(gui)
				local size = backpack.Size
				local w = size.X.Scale * aw + size.X.Offset
				local h = size.Y.Scale * ah + size.Y.Offset
				local left = ox + want.X.Scale * aw + want.X.Offset
				local top = oy + want.Y.Scale * ah + want.Y.Offset
				local topLimit = oy + math.floor(ah * 0.04)
				local bottomLimit = loadout.AbsolutePosition.Y - 6
				local room = bottomLimit - topLimit
				if h > 1 and room > 60 and (top < topLimit - 0.5 or top + h > bottomLimit + 0.5) then
					scale = math.min(1, room / h)
					local shownW, shownH = w * scale, h * scale
					newTop = math.max(topLimit, math.min(top, bottomLimit - shownH))
					oldTop = top
					local newLeft = left + (w - shownW) / 2
					place = UDim2.new(0, math.floor(newLeft - ox + 0.5), 0, math.floor(newTop - oy + 0.5))
				end
			end
			setScale(scale)
			putAt(backpackSpot, backpack, place)

			-- 2013's backpack button: on top of the window while it is open (just above where the window
			-- wanted to be): kept just above where it is now
			if button then
				local buttonPlace = buttonWant
				if newTop and button.Parent then
					local cx, cy, cw, ch = areaOf(button.Parent)
					local bTop = cy + buttonWant.Y.Scale * ch + buttonWant.Y.Offset
					local gap = oldTop - bTop
					if gap > 0 and gap < 40 then
						buttonPlace = UDim2.new(buttonWant.X.Scale, buttonWant.X.Offset, 0,
							math.floor(newTop - gap - cy + 0.5))
					end
				end
				putAt(buttonSpot, button, buttonPlace)
			end

			if newTop and not said then
				said = true
				print("[Old Gui Fix] backpack window fitted above the hotbar")
			end
		end)
		busy = false
		if not ok then warn("[Old Gui Fix] backpack: " .. tostring(err)) end
	end

	backpack:GetPropertyChangedSignal("Position"):Connect(update)
	backpack:GetPropertyChangedSignal("Size"):Connect(update)
	backpack:GetPropertyChangedSignal("Visible"):Connect(update)
	loadout:GetPropertyChangedSignal("Visible"):Connect(update)
	loadout:GetPropertyChangedSignal("AbsolutePosition"):Connect(update)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	if button then button:GetPropertyChangedSignal("Position"):Connect(update) end
	update()
end

--========================================================
-- THE MENU'S SHADE OVER THE WHOLE SCREEN
--========================================================
-- The GUI is laid out inside the phone's safe area, and the menu's dark shield (a full-size window) with it:
-- a strip at the bottom and the sides stayed bright. The shade is drawn by a frame far bigger than the screen
-- just under the window (the window itself still takes the taps), and the GUI may draw outside the safe area.
local shades = setmetatable({}, { __mode = "k" })
local function shadeWholeScreen(window, gui)
	if shades[window] then return end
	local shade = Instance.new("Frame")
	shade.Name = window.Name .. "BPShade"
	shade.BorderSizePixel = 0
	shade.Active = false
	shade.Position = UDim2.new(0, -2000, 0, -2000)
	shade.Size = UDim2.new(1, 4000, 1, 4000)
	shade.BackgroundColor3 = window.BackgroundColor3
	shade.BackgroundTransparency = 1
	shade.Visible = false
	shades[window] = shade -- (before it goes in: going in tells this script again that the GUI changed)
	shade.Parent = gui
	pcall(function() gui.ClipToDeviceSafeArea = false end)

	local function look()
		if window.BackgroundTransparency < 1 then
			shade.BackgroundColor3 = window.BackgroundColor3
			shade.BackgroundTransparency = window.BackgroundTransparency
			window.BackgroundTransparency = 1
		end
	end
	local function update()
		shade.ZIndex = math.max(1, window.ZIndex - 1)
		shade.Visible = window.Visible and window:IsDescendantOf(gui)
	end
	look()
	update()
	window:GetPropertyChangedSignal("BackgroundTransparency"):Connect(look)
	window:GetPropertyChangedSignal("Visible"):Connect(update)
	window:GetPropertyChangedSignal("ZIndex"):Connect(update)
	window.AncestryChanged:Connect(function()
		if window:IsDescendantOf(game) then update() else shade:Destroy() end
	end)
end

--========================================================
-- 2012'S ZOOM AND TILT BUTTONS
--========================================================
-- ControlFrame.ZoomControls: ScrollUp / ScrollDown (tilt the camera up / down) and ZoomIn / ZoomOut. Pressed
-- (and under the mouse on a PC) they show the November 14, 2012 client's pictures.
local TEXTURES_2012 = "https://archive.roblonium.com/Client/Windows/RobloxApp/2012/11.2012/"
	.. "November%2014%20%280.79.0.712%29/version-dae27a273ec947e2/content/textures/"
local ZOOM_BUTTONS = {
	ScrollUp = "CameraTiltUp_ovr.png", ScrollDown = "CameraTiltDown_ovr.png",
	ZoomIn = "CameraZoomIn_ovr.png", ZoomOut = "CameraZoomOut_ovr.png",
}
local ZOOM_STEP = 0.75        -- each zoom press: 3/4 of the distance (or 4/3)
local TILT_STEP = math.rad(10) -- each tilt press
local TILT_LIMIT = math.rad(80)

local texture2012Cache = {}
local function texture2012(file)
	if texture2012Cache[file] ~= nil then return texture2012Cache[file] or nil end
	local result = false
	pcall(function()
		local asset = getcustomasset or getsynasset
		if type(asset) ~= "function" or type(writefile) ~= "function" or type(isfile) ~= "function" then return end
		local path = "BPOld2012_" .. file
		if not isfile(path) then
			local bytes = game:HttpGet(TEXTURES_2012 .. file)
			-- (a PNG: the archive's "not found" page is HTML)
			if type(bytes) ~= "string" or #bytes < 64 or bytes:sub(2, 4) ~= "PNG" then return end
			writefile(path, bytes)
		end
		local id = asset(path)
		if type(id) == "string" and id ~= "" then result = id end
	end)
	texture2012Cache[file] = result
	return result or nil
end

local function zoomCamera(factor)
	local camera = workspace.CurrentCamera
	local player = Players.LocalPlayer
	if not (camera and player) then return end
	local minZoom, maxZoom = player.CameraMinZoomDistance, player.CameraMaxZoomDistance
	local distance = (camera.CFrame.Position - camera.Focus.Position).Magnitude
	local want = math.clamp(distance * factor, minZoom, maxZoom)
	if math.abs(want - distance) < 0.05 then return end
	-- the camera goes to that distance (held there a moment), then the game's own limits come back
	player.CameraMinZoomDistance = want
	player.CameraMaxZoomDistance = want
	task.spawn(function()
		RunService.RenderStepped:Wait()
		RunService.RenderStepped:Wait()
		player.CameraMaxZoomDistance = maxZoom
		player.CameraMinZoomDistance = minZoom
	end)
end

local function tiltCamera(angle)
	local camera = workspace.CurrentCamera
	if not camera then return end
	local focus = camera.Focus.Position
	local cframe = camera.CFrame
	local distance = (cframe.Position - focus).Magnitude
	local look = cframe.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 or distance < 1e-3 then return end
	flat = flat.Unit
	local pitch = math.asin(math.clamp(look.Y, -1, 1))
	local newPitch = math.clamp(pitch + angle, -TILT_LIMIT, TILT_LIMIT)
	local newLook = flat * math.cos(newPitch) + Vector3.new(0, math.sin(newPitch), 0)
	camera.CFrame = CFrame.lookAt(focus - newLook * distance, focus)
end

local ZOOM_ACTIONS = {
	ZoomIn = function() zoomCamera(ZOOM_STEP) end,
	ZoomOut = function() zoomCamera(1 / ZOOM_STEP) end,
	ScrollUp = function() tiltCamera(TILT_STEP) end,    -- look up
	ScrollDown = function() tiltCamera(-TILT_STEP) end, -- look down
}

local zoomHooked = setmetatable({}, { __mode = "k" })
local function hookZoomButtons(gui)
	local controls = gui:FindFirstChild("ControlFrame")
	local zoom = controls and controls:FindFirstChild("ZoomControls")
	-- (2013's are hidden: only shown ones, looked at again every few seconds)
	if not (zoom and zoom:IsA("GuiObject") and zoom.Visible) then return 0 end
	local count = 0
	for name, file in pairs(ZOOM_BUTTONS) do
		local button = zoom:FindFirstChild(name)
		if button and button:IsA("GuiButton") and not zoomHooked[button] then
			zoomHooked[button] = true
			count = count + 1
			local action = ZOOM_ACTIONS[name]
			local ok = pcall(function()
				button.Activated:Connect(function() pcall(action) end)
			end)
			if not ok then button.MouseButton1Click:Connect(function() pcall(action) end) end
			task.spawn(function()
				local pressed = texture2012(file)
				if pressed and button:IsA("ImageButton") then
					button.PressedImage = pressed
					if UserInputService.MouseEnabled then button.HoverImage = pressed end
				end
			end)
		end
	end
	return count
end

--========================================================
-- 2012'S HEALTH BAR NEXT TO THE BACKPACK BUTTON
--========================================================
-- Bloxy's health bar (CustomHealthGui.HealthFrame, at the bottom middle of the whole screen) goes just right
-- of 2012's Backpack button (bottom middle, left of where the health bar was), bottoms lined up, as in the
-- 2012 client. 2013's Backpack button is a tab above the hotbar: there the health bar is left alone.
local healthPlaced = setmetatable({}, { __mode = "k" }) -- the health bar -> where Bloxy put it
local HEALTH_GAP = 3

local function healthFrame()
	local holders = { CoreGui }
	pcall(function()
		local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if playerGui then table.insert(holders, playerGui) end
	end)
	for _, holder in ipairs(holders) do
		local healthGui = holder:FindFirstChild("CustomHealthGui")
		local frame = healthGui and healthGui:FindFirstChild("HealthFrame")
		if frame and frame:IsA("GuiObject") then return frame end
	end
	return nil
end

-- 2012's Backpack button: shown, at the bottom of the GUI
local function bottomBackpackButton(gui)
	local controls = gui and gui:FindFirstChild("ControlFrame")
	local button = controls and controls:FindFirstChild("BackpackButton")
	if not (button and button:IsA("GuiObject") and button.Visible) then return nil end
	local bottom = button.AbsolutePosition.Y + button.AbsoluteSize.Y
	local guiBottom = gui.AbsolutePosition.Y + gui.AbsoluteSize.Y
	if guiBottom - bottom > 40 or button.AbsoluteSize.X < 10 then return nil end
	return button
end

local function placeHealth(gui)
	local frame = healthFrame()
	if not frame then return end
	local button = bottomBackpackButton(gui)
	local state = healthPlaced[frame]
	if not button then
		-- (not 2012's: back where Bloxy put it)
		if state and frame.Position == state.ours then frame.Position = state.original end
		return
	end
	if not state then
		state = { original = frame.Position }
		healthPlaced[frame] = state
	elseif frame.Position ~= state.ours then
		state.original = frame.Position -- (Bloxy moved it itself)
	end
	local holder = frame.Parent
	if not (holder and holder:IsA("GuiBase2d")) then return end
	local x = button.AbsolutePosition.X + button.AbsoluteSize.X + HEALTH_GAP
	local y = button.AbsolutePosition.Y + button.AbsoluteSize.Y - frame.AbsoluteSize.Y
	local want = UDim2.new(0, math.floor(x - holder.AbsolutePosition.X + 0.5), 0,
		math.floor(y - holder.AbsolutePosition.Y + 0.5))
	if frame.Position ~= want then
		state.ours = want
		frame.Position = want
	end
	if not state.said then
		state.said = true
		print("[Old Gui Fix] the health bar is next to the Backpack button")
	end
end

local healthWatched = setmetatable({}, { __mode = "k" })
local function watchHealth(gui)
	local controls = gui:FindFirstChild("ControlFrame")
	local button = controls and controls:FindFirstChild("BackpackButton")
	if button and button:IsA("GuiObject") and not healthWatched[button] then
		healthWatched[button] = true
		local function soon() task.defer(function() pcall(placeHealth, gui) end) end
		button:GetPropertyChangedSignal("AbsolutePosition"):Connect(soon)
		button:GetPropertyChangedSignal("AbsoluteSize"):Connect(soon)
		button:GetPropertyChangedSignal("Visible"):Connect(soon)
	end
	pcall(placeHealth, gui)
end

--========================================================
-- APPLYING IT
--========================================================
local said = {}
local oldGuiUp = false
local function fixGui(gui)
	local fix, zoom = wanted(gui)
	if not fix then return end
	oldGuiUp = true
	local scale = zoom and menuScale(gui) or 1

	local windows = menuWindows(gui)
	for _, window in ipairs(windows) do
		raiseWindow(window)
		pcall(fitWindow, window, scale)
		pcall(shadeWholeScreen, window, gui)
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
	keepOnTopWhileOpen(gui, windows)

	-- the backpack window above the hotbar
	pcall(fitBackpack, gui)

	-- 2012's zoom and tilt buttons
	local ok, hooked = pcall(hookZoomButtons, gui)
	if ok and hooked and hooked > 0 then
		print("[Old Gui Fix] the zoom and tilt buttons work (" .. hooked .. ")")
	end

	-- 2012's health bar next to the Backpack button
	watchHealth(gui)

	local key = tostring(gui) .. "|" .. #windows .. "|" .. tostring(scale)
	if not said[key] then
		said[key] = true
		local names = {}
		for _, window in ipairs(windows) do table.insert(names, window.Name) end
		print("[Old Gui Fix] the 2012 / 2013 GUI (topbar " .. tostring(topbarPick()) .. "): "
			.. #windows .. " menu window(s) raised above the hotbar (" .. table.concat(names, ", ") .. ")"
			.. (scale ~= 1 and (", the menu at " .. math.floor(scale * 100) .. "% on this phone") or ""))
	end
end

local watched = setmetatable({}, { __mode = "k" })
local function watchGui(gui)
	if watched[gui] or gui.Name ~= "NewRobloxGui" then return end
	watched[gui] = true
	print("[Old Gui Fix] found " .. gui:GetFullName() .. " (phone: " .. tostring(onPhone())
		.. ", topbar: " .. tostring(topbarPick()) .. "): waiting for its menu")
	-- the menu windows and the hotbar are made a little after the GUI
	local function soon() task.delay(0.2, function() pcall(fixGui, gui) end) end
	gui.ChildAdded:Connect(soon)
	local hooked = setmetatable({}, { __mode = "k" })
	local function hookControls()
		local controls = gui:FindFirstChild("ControlFrame")
		if controls and not hooked[controls] then
			hooked[controls] = true
			controls.ChildAdded:Connect(function(child)
				if MENU_WINDOWS[child.Name] or child.Name == "BackpackButton" or child.Name == "ZoomControls" then soon() end
			end)
		end
	end
	hookControls()
	gui.ChildAdded:Connect(hookControls)
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
		oldGuiUp = false
		for gui in pairs(watched) do
			if gui.Parent then pcall(fixGui, gui) end
		end
		-- the safe chat's size on a phone: smaller only with the 2006 - 2011 GUIs (they are drawn at a smaller
		-- scale); with every other GUI (2012 and later, 2013 mobile, 2005) its bigger, normal size
		local pick = topbarPick()
		local year = pick and tonumber(string.match(pick, "(20%d%d)"))
		local small = onPhone() and year ~= nil and year >= 2006 and year <= 2011
		Env.BPSafeChatScale = small and PC_SCALE or nil
		task.wait(3)
	end
end)
