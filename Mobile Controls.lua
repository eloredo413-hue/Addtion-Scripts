--========================================================
-- MOBILE CONTROLS (Addtion-Scripts)
-- On-screen touch controls that go with any GUI, in two looks:
--   "2013": the 2013 mobile GUI's joystick and jump button (Roblox's 2013 TouchControlsSheet pictures). They were
--           taken out of that GUI so they can be used with any GUI: "mobile controls" in Hammer stuff.
--   "old":  the old Roblox app's thumbstick (the 2012 iPad app and the early Android app): "old thumbstick" in
--           Hammer stuff. A thin light ring with a see-through knob, and the round glass jump button with the
--           jumping figure on a bar. It works the way Roblox described it in 2012: touch anywhere in the
--           lower-left corner (a third of the screen's width and a third of its height) and the stick moves there,
--           under your thumb; the knob follows your thumb up to the ring, and how far you push it sets how fast you
--           walk (like a controller's stick), toward where the camera looks. Let go and it goes back to its place.
--           Buttons in that corner still get their taps.
-- Both: Roblox's own touch controls are hidden while these are on, and shown again when they stop. The stick is fed
-- into Roblox's control module, so cars and the game's own movement code react to it as to Roblox's own stick (in a
-- game without that module the character and a VehicleSeat are moved directly). Hold jump to keep jumping.
--
-- Run alone: set getgenv().BPMobileControlsStyle = "old" first for the old look ("2013" when it is not set).
-- Hammer stuff uses getgenv().BPMobileControls: Start(style), SetStyle(style), Stop(), Style().
--========================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local CoreGui = game:GetService("CoreGui")
local ContentProvider = game:GetService("ContentProvider")

local genv = (getgenv and getgenv()) or _G

-- a copy that is already running (the file run again) is stopped first: one set of controls at a time
if type(genv.BPMobileControls) == "table" and type(genv.BPMobileControls.Stop) == "function" then
	pcall(genv.BPMobileControls.Stop)
end

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
	task.wait()
	LocalPlayer = Players.LocalPlayer
end

local TOUCH_SHEET = "rbxasset://textures/ui/TouchControlsSheet.png"
local GUI_NAME = "LegacyTouchControls"
local STEP_VEHICLE = "Legacy2013VehicleDrive"
local ACTION_ZONE = "BPOldThumbstickZone"
local STYLES = { ["2013"] = true, old = true }
local ZERO = Vector3.new(0, 0, 0)

local style = nil         -- "2013", "old", or nil when stopped
local conns = {}          -- connections kept while running
local lookConns = {}      -- connections kept while one look is on screen
local screenGui = nil
local look = nil          -- the look on screen (see build2013 / buildOld)

-- the stick and the jump button, shared by both looks
local moveVector = ZERO        -- the stick's direction (x = right, z = down the screen), length 1 or 0
local walkSpeedFactor = 0      -- how far it is pushed, 0 .. 1
local isJumpButtonDown = false
local moveTouchObject = nil
local jumpTouchObject = nil
local movedByUs = false        -- LocalPlayer:Move was called by this script (no control module to do it)

local function track(list, conn)
	table.insert(list, conn)
	return conn
end
local function disconnectAll(list)
	for _, c in ipairs(list) do pcall(function() c:Disconnect() end) end
	table.clear(list)
end

pcall(function()
	task.spawn(function()
		pcall(function() ContentProvider:PreloadAsync({ TOUCH_SHEET }) end)
	end)
end)

----------------------------------------------------------------------------------------------------
-- the two looks
----------------------------------------------------------------------------------------------------
-- Each look gives: stick (the frame the stick is in), jump (the jump button), radius() (how far the knob can go),
-- deadZone, rest() (the stick back in its place, knob centred), placeKnob(dx, dy), center() (the stick's centre on
-- the screen), pressJump(down), and for the old look: floating = true, moveTo(position), inZone(position).

local function build2013(gui)
	local frame = Instance.new("Frame")
	frame.Name = "JoystickFrame"
	frame.Size = UDim2.new(0, 90, 0, 90)
	frame.Position = UDim2.new(0, 30, 1, -120)
	frame.BackgroundTransparency = 1
	frame.Active = true
	frame.Parent = gui

	local base = Instance.new("ImageLabel")
	base.Name = "Base"
	base.Size = UDim2.new(1, 0, 1, 0)
	base.Image = TOUCH_SHEET
	base.ImageRectOffset = Vector2.new(0, 0)
	base.ImageRectSize = Vector2.new(220, 220)
	base.BackgroundTransparency = 1
	base.Parent = frame

	local stick = Instance.new("ImageLabel")
	stick.Name = "Stick"
	stick.Size = UDim2.new(0, 42, 0, 42)
	stick.Position = UDim2.new(0.5, 0, 0.5, 0)
	stick.AnchorPoint = Vector2.new(0.5, 0.5)
	stick.Image = TOUCH_SHEET
	stick.ImageRectOffset = Vector2.new(220, 0)
	stick.ImageRectSize = Vector2.new(111, 111)
	stick.BackgroundTransparency = 1
	stick.ZIndex = 2
	stick.Parent = frame

	local jump = Instance.new("ImageButton")
	jump.Name = "JumpButton"
	jump.Size = UDim2.new(0, 90, 0, 90)
	jump.Position = UDim2.new(1, -120, 1, -120)
	jump.BackgroundTransparency = 1
	jump.Image = TOUCH_SHEET
	jump.ImageRectOffset = Vector2.new(176, 222)
	jump.ImageRectSize = Vector2.new(174, 174)
	jump.Active = true
	jump.Parent = gui

	return {
		stick = frame,
		jump = jump,
		deadZone = 0,
		radius = function() return 45 end,
		rest = function() stick.Position = UDim2.new(0.5, 0, 0.5, 0) end,
		placeKnob = function(dx, dy) stick.Position = UDim2.new(0.5, dx, 0.5, dy) end,
		center = function() return frame.AbsolutePosition + frame.AbsoluteSize / 2 end,
		pressJump = function(down)
			jump.ImageRectOffset = down and Vector2.new(0, 222) or Vector2.new(176, 222)
		end,
	}
end

-- the old app's look, drawn (there is no picture of it to use): sizes follow the screen's height, as in the app
local OLD_RING = Color3.fromRGB(208, 208, 208)
local OLD_RIM_DARK = Color3.fromRGB(92, 92, 92)
local OLD_RIM_LIGHT = Color3.fromRGB(222, 222, 222)
local OLD_FIGURE = Color3.fromRGB(150, 150, 150)
local OLD_FIGURE_DOWN = Color3.fromRGB(118, 118, 118)

local function circle(parent, name, size, position)
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = size
	f.Position = position
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = f
	f.Parent = parent
	return f
end
local function stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end
-- a block of the jump button's figure, in parts of the button (0 .. 1)
local function block(parent, name, x0, y0, x1, y1)
	local b = Instance.new("Frame")
	b.Name = name
	b.BorderSizePixel = 0
	b.BackgroundColor3 = OLD_FIGURE
	b.BackgroundTransparency = 0.05
	b.Position = UDim2.new(x0, 0, y0, 0)
	b.Size = UDim2.new(x1 - x0, 0, y1 - y0, 0)
	b.ZIndex = 3
	b.Parent = parent
	return b
end

local function buildOld(gui)
	-- the ring (the stick's base) with the knob in it
	local ring = circle(gui, "OldThumbstick", UDim2.new(0, 80, 0, 80), UDim2.new(0, 0, 0, 0))
	local ringStroke = stroke(ring, OLD_RING, 3, 0.12)
	local ringEdge = circle(ring, "Edge", UDim2.new(1, -6, 1, -6), UDim2.new(0.5, 0, 0.5, 0))
	stroke(ringEdge, OLD_RIM_DARK, 1, 0.75)

	local knob = circle(ring, "Knob", UDim2.new(0.48, 0, 0.48, 0), UDim2.new(0.5, 0, 0.5, 0))
	knob.BackgroundColor3 = Color3.fromRGB(196, 196, 196)
	knob.BackgroundTransparency = 0.72
	knob.ZIndex = 2
	local knobStroke = stroke(knob, OLD_RIM_DARK, 2, 0.35)
	local knobInner = circle(knob, "Inner", UDim2.new(0.84, 0, 0.84, 0), UDim2.new(0.5, 0, 0.5, 0))
	knobInner.ZIndex = 2
	stroke(knobInner, OLD_RIM_LIGHT, 1.5, 0.45)

	-- the jump button: a glass circle with the grey figure jumping, arms up, over a bar
	local jump = Instance.new("ImageButton")
	jump.Name = "JumpButton"
	jump.AnchorPoint = Vector2.new(0.5, 0.5)
	jump.Image = ""
	jump.AutoButtonColor = false
	jump.BackgroundColor3 = Color3.fromRGB(228, 228, 228)
	jump.BackgroundTransparency = 0.62
	jump.BorderSizePixel = 0
	jump.Active = true
	jump.ZIndex = 2
	local jumpCorner = Instance.new("UICorner")
	jumpCorner.CornerRadius = UDim.new(0.5, 0)
	jumpCorner.Parent = jump
	local jumpStroke = stroke(jump, Color3.fromRGB(168, 168, 168), 3, 0.08)
	local glass = circle(jump, "Glass", UDim2.new(1, -8, 1, -8), UDim2.new(0.5, 0, 0.5, 0))
	glass.ZIndex = 2
	stroke(glass, Color3.fromRGB(246, 246, 246), 1.5, 0.45)
	local figure = {
		block(jump, "Head", 0.445, 0.17, 0.555, 0.285),
		block(jump, "LeftArm", 0.29, 0.195, 0.375, 0.37),
		block(jump, "RightArm", 0.625, 0.195, 0.71, 0.37),
		block(jump, "Torso", 0.39, 0.295, 0.61, 0.505),
		block(jump, "LeftLeg", 0.395, 0.505, 0.495, 0.715),
		block(jump, "RightLeg", 0.505, 0.505, 0.605, 0.715),
		block(jump, "Bar", 0.3, 0.83, 0.7, 0.87),
	}
	jump.Parent = gui

	local size = 80
	local held = false
	-- sizes and places, from the screen (the screen can turn or change size)
	local function restPosition()
		local area = gui.AbsoluteSize
		local r = size / 2
		return Vector2.new(math.max(area.X * 0.10, r + 10), math.min(area.Y * 0.77, area.Y - r - 10))
	end
	local function layout()
		local area = gui.AbsoluteSize
		size = math.floor(math.clamp(area.Y * 0.19, 70, 140) + 0.5)
		ring.Size = UDim2.new(0, size, 0, size)
		ringStroke.Thickness = math.max(2, math.floor(size * 0.035 + 0.5))
		knobStroke.Thickness = math.max(1.5, size * 0.022)
		local jumpSize = math.floor(size * 1.06 + 0.5)
		jump.Size = UDim2.new(0, jumpSize, 0, jumpSize)
		jumpStroke.Thickness = math.max(2, math.floor(jumpSize * 0.035 + 0.5))
		local jr = jumpSize / 2
		jump.Position = UDim2.new(0, math.min(area.X * 0.86, area.X - jr - 10), 0, math.min(area.Y * 0.84, area.Y - jr - 10))
		if not held then
			local p = restPosition()
			ring.Position = UDim2.new(0, p.X, 0, p.Y)
		end
	end
	layout()
	track(lookConns, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout))

	return {
		stick = ring,
		jump = jump,
		floating = true,
		deadZone = 0.08,
		radius = function() return size / 2 end,
		rest = function()
			held = false
			knob.Position = UDim2.new(0.5, 0, 0.5, 0)
			local p = restPosition()
			ring.Position = UDim2.new(0, p.X, 0, p.Y)
		end,
		placeKnob = function(dx, dy) knob.Position = UDim2.new(0.5, dx, 0.5, dy) end,
		center = function() return ring.AbsolutePosition + ring.AbsoluteSize / 2 end,
		-- the stick moves to the touch (kept on the screen), knob in the middle
		moveTo = function(position)
			held = true
			local area = gui.AbsoluteSize
			local r = size / 2
			local x = position.X - gui.AbsolutePosition.X
			local y = position.Y - gui.AbsolutePosition.Y
			x = math.clamp(x, r + 2, math.max(r + 2, area.X - r - 2))
			y = math.clamp(y, r + 2, math.max(r + 2, area.Y - r - 2))
			ring.Position = UDim2.new(0, x, 0, y)
			knob.Position = UDim2.new(0.5, 0, 0.5, 0)
		end,
		-- the lower-left corner: a third of the width, a third of the height (and the ring itself)
		inZone = function(position)
			local x = position.X - gui.AbsolutePosition.X
			local y = position.Y - gui.AbsolutePosition.Y
			local area = gui.AbsoluteSize
			if x >= 0 and x <= area.X / 3 and y >= area.Y * 2 / 3 and y <= area.Y then return true end
			local c = ring.AbsolutePosition + ring.AbsoluteSize / 2
			return (Vector2.new(position.X, position.Y) - c).Magnitude <= size / 2
		end,
		pressJump = function(down)
			jump.BackgroundTransparency = down and 0.4 or 0.62
			for _, part in ipairs(figure) do
				part.BackgroundColor3 = down and OLD_FIGURE_DOWN or OLD_FIGURE
			end
		end,
	}
end

----------------------------------------------------------------------------------------------------
-- the stick and the jump button
----------------------------------------------------------------------------------------------------
local function releaseStick()
	moveTouchObject = nil
	moveVector = ZERO
	walkSpeedFactor = 0
	if look then look.rest() end
end
local function releaseJump()
	jumpTouchObject = nil
	isJumpButtonDown = false
	if look then look.pressJump(false) end
end

-- a touch's place: the knob goes there (up to the edge) and sets the direction and how fast
local function steer(position)
	if not look then return end
	local center = look.center()
	local diff = Vector2.new(position.X, position.Y) - center
	local radius = look.radius()
	local dist = math.min(diff.Magnitude, radius)
	local dir = diff.Magnitude > 0 and diff.Unit or Vector2.new(0, 0)
	look.placeKnob(dir.X * dist, dir.Y * dist)
	local factor = radius > 0 and dist / radius or 0
	if factor <= look.deadZone then factor = 0 end
	walkSpeedFactor = factor
	moveVector = factor > 0 and Vector3.new(dir.X, 0, dir.Y) or ZERO
end

local function grabStick(input)
	moveTouchObject = input
	if look.floating then look.moveTo(input.Position) end
	steer(input.Position)
end

local function touchIsOver(touch)
	return touch.UserInputState == Enum.UserInputState.End or touch.UserInputState == Enum.UserInputState.Cancel
end

----------------------------------------------------------------------------------------------------
-- Roblox's own touch controls: hidden while these are on, shown again after
----------------------------------------------------------------------------------------------------
local hiddenTouchGuis = {}
local function hideTouchGui(gui)
	if not (gui:IsA("ScreenGui") and gui.Name == "TouchGui") or hiddenTouchGuis[gui] then return end
	hiddenTouchGuis[gui] = true
	gui.Enabled = false
	track(conns, gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if style and gui.Enabled then gui.Enabled = false end
	end))
end
local function showTouchGuis()
	for gui in pairs(hiddenTouchGuis) do
		pcall(function()
			if gui.Parent then gui.Enabled = true end
		end)
	end
	table.clear(hiddenTouchGuis)
end

----------------------------------------------------------------------------------------------------
-- fed into Roblox's control module: when it asks its active controller for the move vector it gets this stick's
-- (only while the stick is held), so cars and the game's movement code react to it as to Roblox's own controls
----------------------------------------------------------------------------------------------------
local controls = nil
local nextLook = 0
local fed = {} -- controller -> { original, wrapper, own }
local lastConsulted = -1
local function controlsAreFed()
	return os.clock() - lastConsulted < 0.25
end
local function findControls()
	if controls then return controls end
	local ok, found = pcall(function()
		local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if not module then return nil end
		return require(module):GetControls()
	end)
	if ok and type(found) == "table" then controls = found end
	return controls
end
local function feed(controller)
	if fed[controller] then return end
	pcall(function()
		local original = controller.GetMoveVector
		if type(original) ~= "function" then return end
		local record = { original = original, own = rawget(controller, "GetMoveVector") ~= nil }
		record.wrapper = function(self, ...)
			if style and walkSpeedFactor > 0 and moveVector.Magnitude > 0 then
				lastConsulted = os.clock()
				return moveVector * walkSpeedFactor
			end
			return original(self, ...)
		end
		controller.GetMoveVector = record.wrapper
		fed[controller] = record
	end)
end
local function unfeedAll()
	for controller, record in pairs(fed) do
		pcall(function()
			if rawget(controller, "GetMoveVector") == record.wrapper then
				controller.GetMoveVector = record.own and record.original or nil
			end
		end)
	end
	table.clear(fed)
end

----------------------------------------------------------------------------------------------------
-- a VehicleSeat driven directly, only when the control module is not asking for the stick (a game without it)
----------------------------------------------------------------------------------------------------
local drivenSeat = nil
local function releaseSeat()
	if drivenSeat and drivenSeat.Parent then
		pcall(function()
			drivenSeat.ThrottleFloat = 0
			drivenSeat.SteerFloat = 0
		end)
	end
	drivenSeat = nil
end
local function vehicleStep()
	local character = LocalPlayer.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if seat and not seat:IsA("VehicleSeat") then seat = nil end
	if drivenSeat and drivenSeat ~= seat then releaseSeat() end
	if seat and walkSpeedFactor > 0 and not controlsAreFed() then
		local stick = moveVector * walkSpeedFactor
		pcall(function()
			seat.ThrottleFloat = -stick.Z
			seat.SteerFloat = stick.X
		end)
		drivenSeat = seat
	elseif drivenSeat then
		releaseSeat()
	end
end

----------------------------------------------------------------------------------------------------
-- every frame: nothing stays held that is not, walking without a control module, holding jump
----------------------------------------------------------------------------------------------------
local function frameStep()
	if not controls then
		local now = os.clock()
		if now >= nextLook then
			nextLook = now + 2
			findControls()
		end
	end
	if controls then
		local controller = controls.activeController
		if type(controller) == "table" and not fed[controller] then feed(controller) end
	end

	if jumpTouchObject and touchIsOver(jumpTouchObject) then releaseJump() end
	if moveTouchObject and touchIsOver(moveTouchObject) then releaseStick() end

	local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	-- (when the control module is being fed the stick, it does the moving itself)
	if walkSpeedFactor > 0 and moveVector.Magnitude > 0 and not controlsAreFed() then
		LocalPlayer:Move(moveVector * walkSpeedFactor, true)
		movedByUs = true
	elseif movedByUs then
		-- let go: stop the walk this script started (nothing else would)
		movedByUs = false
		pcall(function() LocalPlayer:Move(ZERO, true) end)
	end

	if isJumpButtonDown then
		local state = hum:GetState()
		local canJump = hum.FloorMaterial ~= Enum.Material.Air or hum.Sit
			or state == Enum.HumanoidStateType.Climbing or state == Enum.HumanoidStateType.Swimming
		if canJump then
			hum.Jump = true
			if state == Enum.HumanoidStateType.Climbing then
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- putting a look on screen
----------------------------------------------------------------------------------------------------
local function guiHolder()
	local holder = CoreGui
	pcall(function()
		if gethui then holder = gethui() end
	end)
	return holder
end

-- the old look's corner: touches there that no button took go to the stick (and not to the camera)
local function zoneAction(_, inputState, input)
	if style ~= "old" or not look or inputState ~= Enum.UserInputState.Begin
		or input.UserInputType ~= Enum.UserInputType.Touch or moveTouchObject or not look.inZone(input.Position) then
		return Enum.ContextActionResult.Pass
	end
	grabStick(input)
	return Enum.ContextActionResult.Sink
end

local function showLook()
	disconnectAll(lookConns)
	pcall(function() ContextActionService:UnbindAction(ACTION_ZONE) end)
	if screenGui then
		local old = screenGui
		screenGui = nil
		pcall(function() old:Destroy() end)
	end
	look = nil
	if not style then return end

	local gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 999
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	screenGui = gui
	gui.Parent = guiHolder()

	look = (style == "old") and buildOld(gui) or build2013(gui)

	if look.floating then
		local bound = pcall(function()
			ContextActionService:BindActionAtPriority(ACTION_ZONE, zoneAction, false,
				Enum.ContextActionPriority.High.Value, Enum.UserInputType.Touch)
		end)
		if not bound then
			-- no ContextActionService here: a see-through frame over the corner takes the touches instead
			local zone = Instance.new("Frame")
			zone.Name = "OldThumbstickZone"
			zone.BackgroundTransparency = 1
			zone.Size = UDim2.new(1 / 3, 0, 1 / 3, 0)
			zone.Position = UDim2.new(0, 0, 2 / 3, 0)
			zone.Active = true
			zone.Parent = gui
			track(lookConns, zone.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch and not moveTouchObject then grabStick(input) end
			end))
		end
	else
		track(lookConns, look.stick.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch and not moveTouchObject then grabStick(input) end
		end))
	end

	local jump = look.jump
	track(lookConns, jump.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and not jumpTouchObject then
			jumpTouchObject = input
			isJumpButtonDown = true
			look.pressJump(true)
		end
	end))
	track(lookConns, jump.InputEnded:Connect(function(input)
		if input == jumpTouchObject then releaseJump() end
	end))

	-- something removed the controls (a GUI clearing out old screens): they come back
	track(lookConns, gui.AncestryChanged:Connect(function()
		if style and screenGui == gui and not gui.Parent then
			task.defer(function()
				if style and screenGui == gui and not gui.Parent then
					releaseStick()
					releaseJump()
					showLook()
				end
			end)
		end
	end))
end

----------------------------------------------------------------------------------------------------
-- start, switch, stop
----------------------------------------------------------------------------------------------------
local api = {}

function api.Stop()
	if not style then return end
	style = nil
	releaseStick()
	releaseJump()
	if movedByUs then
		movedByUs = false
		pcall(function() LocalPlayer:Move(ZERO, true) end)
	end
	disconnectAll(conns)
	showLook() -- (with no style: the controls are taken off the screen)
	pcall(function() RunService:UnbindFromRenderStep(STEP_VEHICLE) end)
	releaseSeat()
	unfeedAll()
	showTouchGuis()
	genv.BPMobileControlsRunning = nil
	print("[Mobile Controls] off: Roblox's own controls are back.")
end

function api.SetStyle(newStyle)
	newStyle = tostring(newStyle or "2013")
	if not STYLES[newStyle] then newStyle = "2013" end
	if not style then return api.Start(newStyle) end
	if newStyle == style then return end
	releaseStick()
	releaseJump()
	style = newStyle
	genv.BPMobileControlsRunning = style
	showLook()
	print("[Mobile Controls] " .. (style == "old" and "old thumbstick" or "2013 controls") .. " on.")
end

function api.Start(newStyle)
	newStyle = tostring(newStyle or "2013")
	if not STYLES[newStyle] then newStyle = "2013" end
	if style then return api.SetStyle(newStyle) end
	style = newStyle
	genv.BPMobileControlsRunning = style

	-- Roblox's touch controls hidden (and any that appear later)
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		for _, child in ipairs(playerGui:GetChildren()) do pcall(hideTouchGui, child) end
	end
	track(conns, LocalPlayer.ChildAdded:Connect(function(child)
		if child:IsA("PlayerGui") then
			for _, c in ipairs(child:GetChildren()) do pcall(hideTouchGui, c) end
			track(conns, child.ChildAdded:Connect(function(c)
				task.defer(function() if style then pcall(hideTouchGui, c) end end)
			end))
		end
	end))
	if playerGui then
		track(conns, playerGui.ChildAdded:Connect(function(c)
			task.defer(function() if style then pcall(hideTouchGui, c) end end)
		end))
	end

	track(conns, UserInputService.InputChanged:Connect(function(input)
		if input == moveTouchObject then
			steer(input.Position)
		elseif input == jumpTouchObject and look then
			-- the finger slid off the jump button: let go of it
			local pos = input.Position
			local absPos = look.jump.AbsolutePosition
			local absSize = look.jump.AbsoluteSize
			local inside = pos.X >= absPos.X and pos.X <= absPos.X + absSize.X
				and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y
			if not inside then releaseJump() end
		end
	end))
	track(conns, UserInputService.InputEnded:Connect(function(input)
		if input == moveTouchObject then releaseStick() end
		if input == jumpTouchObject then releaseJump() end
	end))
	track(conns, RunService.RenderStepped:Connect(frameStep))
	pcall(function() RunService:UnbindFromRenderStep(STEP_VEHICLE) end)
	pcall(function()
		RunService:BindToRenderStep(STEP_VEHICLE, Enum.RenderPriority.Input.Value + 1, vehicleStep)
	end)

	showLook()
	print("[Mobile Controls] " .. (style == "old" and "old thumbstick" or "2013 controls") .. " on.")
end

function api.Style()
	return style
end

genv.BPMobileControls = api
api.Start(genv.BPMobileControlsStyle or "2013")
