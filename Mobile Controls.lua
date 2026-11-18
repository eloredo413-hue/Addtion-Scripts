--========================================================
-- MOBILE CONTROLS (Addtion-Scripts)
-- Two parts, each its own option in Hammer stuff 2 (one, the other, or both):
--   "mobile controls": the 2013 mobile GUI's joystick and jump button (Roblox's 2013 TouchControlsSheet pictures),
--      with any GUI. Roblox's own touch controls are hidden while it is on.
--   "old thumbstick": the classic thumbstick you can drag everywhere. A thin light ring with a see-through knob,
--      resting in the bottom-left corner. Put your thumb on it (or anywhere in the bottom-left corner: it jumps under
--      your thumb) and drag: the knob follows your thumb, and once your thumb goes past the ring's edge the whole
--      stick comes along with it, anywhere on the screen, so you keep walking that way. Let go and it goes back to
--      its corner. It only replaces the thumbstick: with mobile controls it takes the 2013 joystick's place next to
--      the 2013 jump button; with Roblox's regular controls it takes the place of Roblox's own thumbstick, and
--      Roblox's jump button (or Bloxy's old jump button) stays.
-- The stick is fed into Roblox's control module, so cars and the game's own movement code react to it as to
-- Roblox's own stick (in a game without that module the character and a VehicleSeat are moved directly). Hold jump
-- to keep jumping. Everything is put back when both are off.
--
-- Run alone: the 2013 controls (set getgenv().BPMobileControlsOldStick = true first for the old thumbstick in them).
-- Hammer stuff uses getgenv().BPMobileControls: Set(controls, oldThumbstick), Start(), Stop(), Style().
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
local ACTION_CORNER = "BPOldThumbstickCorner"
local ZERO = Vector3.new(0, 0, 0)

local controlsOn = false      -- "mobile controls": the 2013 joystick (unless the old thumbstick) and jump button
local oldStickOn = false      -- "old thumbstick": the draggable stick
local running = false
local conns = {}          -- connections kept while running
local lookConns = {}      -- connections kept while the controls on screen stay the same
local touchConns = {}     -- connections watching Roblox's touch controls
local screenGui = nil
local look = nil          -- what is on screen (see showLook)

-- the stick and the jump button
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
-- what goes on screen
----------------------------------------------------------------------------------------------------
-- A stick gives: frame, deadZone, radius(), center() (its middle on the screen), rest() (back in its place, knob
-- in the middle), placeKnob(dx, dy), and the old one also drags = true, moveCenter(position), inCorner(position).
-- A jump button gives: button, press(down).

local function build2013Stick(gui)
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

	return {
		frame = frame,
		deadZone = 0,
		radius = function() return 45 end,
		center = function() return frame.AbsolutePosition + frame.AbsoluteSize / 2 end,
		rest = function() stick.Position = UDim2.new(0.5, 0, 0.5, 0) end,
		placeKnob = function(dx, dy) stick.Position = UDim2.new(0.5, dx, 0.5, dy) end,
	}
end

local function build2013Jump(gui)
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
		button = jump,
		press = function(down)
			jump.ImageRectOffset = down and Vector2.new(0, 222) or Vector2.new(176, 222)
		end,
	}
end

-- the old thumbstick, drawn: a thin light ring and a see-through knob with a dark and a light rim
local function circle(parent, name, size)
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = size
	f.Position = UDim2.new(0.5, 0, 0.5, 0)
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

local function buildOldStick(gui)
	local ring = circle(gui, "OldThumbstick", UDim2.new(0, 72, 0, 72))
	local ringStroke = stroke(ring, Color3.fromRGB(212, 212, 212), 3, 0.08)
	local ringEdge = circle(ring, "Edge", UDim2.new(1, -6, 1, -6))
	stroke(ringEdge, Color3.fromRGB(90, 90, 90), 1, 0.7)

	local knob = circle(ring, "Knob", UDim2.new(0.47, 0, 0.47, 0))
	knob.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
	knob.BackgroundTransparency = 0.72
	knob.ZIndex = 2
	local knobStroke = stroke(knob, Color3.fromRGB(95, 95, 95), 2, 0.3)
	local knobInner = circle(knob, "Inner", UDim2.new(0.84, 0, 0.84, 0))
	knobInner.ZIndex = 2
	stroke(knobInner, Color3.fromRGB(225, 225, 225), 1.5, 0.4)

	local size = 72
	local held = false
	local centerAt = Vector2.new(0, 0) -- the ring's middle, from the controls screen's top-left corner
	local function place(p)
		centerAt = p
		ring.Position = UDim2.new(0, p.X, 0, p.Y)
	end
	local function restPlace()
		local area = gui.AbsoluteSize
		local r = size / 2
		return Vector2.new(math.max(area.X * 0.12, r + 10), math.min(area.Y * 0.85, area.Y - r - 10))
	end
	-- the size follows the screen's height (the screen can turn or change size)
	local function layout()
		local area = gui.AbsoluteSize
		size = math.floor(math.clamp(area.Y * 0.18, 64, 140) + 0.5)
		ring.Size = UDim2.new(0, size, 0, size)
		ringStroke.Thickness = math.max(2, math.floor(size * 0.04 + 0.5))
		knobStroke.Thickness = math.max(1.5, size * 0.022)
		if not held then place(restPlace()) end
	end
	layout()
	track(lookConns, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout))

	return {
		frame = ring,
		drags = true,
		deadZone = 0.08,
		radius = function() return size / 2 end,
		center = function() return gui.AbsolutePosition + centerAt end,
		rest = function()
			held = false
			knob.Position = UDim2.new(0.5, 0, 0.5, 0)
			place(restPlace())
		end,
		placeKnob = function(dx, dy) knob.Position = UDim2.new(0.5, dx, 0.5, dy) end,
		-- the stick's middle to a place on the screen (from a touch)
		moveCenter = function(position)
			held = true
			place(Vector2.new(position.X, position.Y) - gui.AbsolutePosition)
		end,
		-- the bottom-left corner (a third of the width and of the height), or the ring itself
		inCorner = function(position)
			local x = position.X - gui.AbsolutePosition.X
			local y = position.Y - gui.AbsolutePosition.Y
			local area = gui.AbsoluteSize
			if x >= 0 and x <= area.X / 3 and y >= area.Y * 2 / 3 and y <= area.Y then return true end
			return (Vector2.new(x, y) - centerAt).Magnitude <= size / 2
		end,
	}
end

----------------------------------------------------------------------------------------------------
-- the stick and the jump button at work
----------------------------------------------------------------------------------------------------
local function releaseStick()
	moveTouchObject = nil
	moveVector = ZERO
	walkSpeedFactor = 0
	if look and look.stick then look.stick.rest() end
end
local function releaseJump()
	jumpTouchObject = nil
	isJumpButtonDown = false
	if look and look.jump then look.jump.press(false) end
end

-- a touch's place: the knob goes there (up to the ring) and sets the direction and how fast. The old thumbstick is
-- dragged along: past the ring's edge its middle follows the thumb, so the thumb stays on the edge.
local function steer(position)
	local stick = look and look.stick
	if not stick then return end
	local radius = stick.radius()
	local thumb = Vector2.new(position.X, position.Y)
	local center = stick.center()
	local diff = thumb - center
	if stick.drags and radius > 0 and diff.Magnitude > radius then
		center = thumb - diff.Unit * radius
		stick.moveCenter(center)
		diff = thumb - center
	end
	local dist = math.min(diff.Magnitude, radius)
	local dir = diff.Magnitude > 0 and diff.Unit or Vector2.new(0, 0)
	stick.placeKnob(dir.X * dist, dir.Y * dist)
	local factor = radius > 0 and dist / radius or 0
	if factor <= stick.deadZone then factor = 0 end
	walkSpeedFactor = factor
	moveVector = factor > 0 and Vector3.new(dir.X, 0, dir.Y) or ZERO
end

local function grabStick(input)
	moveTouchObject = input
	if look.stick.drags then look.stick.moveCenter(input.Position) end -- (it jumps under the thumb)
	steer(input.Position)
end

local function touchIsOver(touch)
	return touch.UserInputState == Enum.UserInputState.End or touch.UserInputState == Enum.UserInputState.Cancel
end

----------------------------------------------------------------------------------------------------
-- Roblox's own touch controls. With mobile controls: all hidden (TouchGui off). With only the old thumbstick:
-- only Roblox's thumbstick is hidden and shrunk to nothing (so it takes no touches), its jump button stays.
-- Everything is put back as it was when this stops.
----------------------------------------------------------------------------------------------------
local touchMode = nil -- "all", "stick" or nil
local hiddenTouchGuis = {}
local hiddenSticks = {} -- frame -> { Visible, Size } as Roblox wants them
local settingStick = false

local function isRobloxStick(obj)
	if not obj:IsA("GuiObject") then return false end
	local name = string.lower(obj.Name)
	return string.find(name, "thumbstick", 1, true) ~= nil or string.find(name, "thumbpad", 1, true) ~= nil
end
local function underTouchGui(obj)
	local p = obj.Parent
	while p do
		if p:IsA("ScreenGui") then return p.Name == "TouchGui" end
		if isRobloxStick(p) then return false end -- (only the outer stick frame)
		p = p.Parent
	end
	return false
end
local function squash(frame)
	settingStick = true
	pcall(function()
		frame.Visible = false
		frame.Size = UDim2.new(0, 0, 0, 0)
	end)
	settingStick = false
end
local function hideRobloxStick(frame)
	if hiddenSticks[frame] or not isRobloxStick(frame) or not underTouchGui(frame) then return end
	local record = { Visible = frame.Visible, Size = frame.Size }
	hiddenSticks[frame] = record
	squash(frame)
	-- Roblox's controls show, hide and size their stick themselves: what they set is kept for later, and it
	-- stays hidden
	for _, prop in ipairs({ "Visible", "Size" }) do
		track(touchConns, frame:GetPropertyChangedSignal(prop):Connect(function()
			if settingStick or touchMode ~= "stick" then return end
			record[prop] = frame[prop]
			squash(frame)
		end))
	end
end
local function hideTouchGui(gui)
	if not (gui:IsA("ScreenGui") and gui.Name == "TouchGui") then return end
	if touchMode == "all" then
		if hiddenTouchGuis[gui] then return end
		hiddenTouchGuis[gui] = true
		gui.Enabled = false
		track(touchConns, gui:GetPropertyChangedSignal("Enabled"):Connect(function()
			if touchMode == "all" and gui.Enabled then gui.Enabled = false end
		end))
	elseif touchMode == "stick" then
		for _, d in ipairs(gui:GetDescendants()) do pcall(hideRobloxStick, d) end
		track(touchConns, gui.DescendantAdded:Connect(function(d)
			task.defer(function()
				if touchMode == "stick" then pcall(hideRobloxStick, d) end
			end)
		end))
	end
end
local function putTouchBack()
	disconnectAll(touchConns)
	for gui in pairs(hiddenTouchGuis) do
		pcall(function()
			if gui.Parent then gui.Enabled = true end
		end)
	end
	table.clear(hiddenTouchGuis)
	settingStick = true
	for frame, record in pairs(hiddenSticks) do
		pcall(function()
			frame.Size = record.Size
			frame.Visible = record.Visible
		end)
	end
	settingStick = false
	table.clear(hiddenSticks)
end
local function setTouchMode(mode)
	if mode == touchMode then return end
	touchMode = nil
	putTouchBack()
	touchMode = mode
	if not mode then return end
	local function watch(pg)
		for _, child in ipairs(pg:GetChildren()) do pcall(hideTouchGui, child) end
		track(touchConns, pg.ChildAdded:Connect(function(c)
			task.defer(function()
				if touchMode then pcall(hideTouchGui, c) end
			end)
		end))
	end
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then watch(playerGui) end
	track(touchConns, LocalPlayer.ChildAdded:Connect(function(child)
		if child:IsA("PlayerGui") then watch(child) end
	end))
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
			if running and walkSpeedFactor > 0 and moveVector.Magnitude > 0 then
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
-- putting the controls on screen
----------------------------------------------------------------------------------------------------
local function guiHolder()
	local holder = CoreGui
	pcall(function()
		if gethui then holder = gethui() end
	end)
	return holder
end

-- the bottom-left corner: touches there that no button took pick up the old thumbstick (and not the camera)
local function cornerAction(_, inputState, input)
	local stick = look and look.stick
	if not stick or not stick.drags or inputState ~= Enum.UserInputState.Begin
		or input.UserInputType ~= Enum.UserInputType.Touch or moveTouchObject or not stick.inCorner(input.Position) then
		return Enum.ContextActionResult.Pass
	end
	grabStick(input)
	return Enum.ContextActionResult.Sink
end

local function showLook()
	disconnectAll(lookConns)
	pcall(function() ContextActionService:UnbindAction(ACTION_CORNER) end)
	if screenGui then
		local old = screenGui
		screenGui = nil
		pcall(function() old:Destroy() end)
	end
	look = nil
	if not running then return end

	local gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 999
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	screenGui = gui
	gui.Parent = guiHolder()

	look = {}
	look.stick = oldStickOn and buildOldStick(gui) or build2013Stick(gui)
	if controlsOn then look.jump = build2013Jump(gui) end

	if look.stick.drags then
		-- (a little above Roblox's own thumbstick, so the corner is this stick's first)
		local bound = pcall(function()
			ContextActionService:BindActionAtPriority(ACTION_CORNER, cornerAction, false,
				Enum.ContextActionPriority.High.Value + 1, Enum.UserInputType.Touch)
		end)
		if not bound then
			-- no ContextActionService here: a see-through frame over the corner takes the touches instead
			local corner = Instance.new("Frame")
			corner.Name = "OldThumbstickCorner"
			corner.BackgroundTransparency = 1
			corner.Size = UDim2.new(1 / 3, 0, 1 / 3, 0)
			corner.Position = UDim2.new(0, 0, 2 / 3, 0)
			corner.Active = true
			corner.Parent = gui
			track(lookConns, corner.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch and not moveTouchObject then grabStick(input) end
			end))
		end
	else
		track(lookConns, look.stick.frame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch and not moveTouchObject then grabStick(input) end
		end))
	end

	if look.jump then
		local jump = look.jump
		track(lookConns, jump.button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch and not jumpTouchObject then
				jumpTouchObject = input
				isJumpButtonDown = true
				jump.press(true)
			end
		end))
		track(lookConns, jump.button.InputEnded:Connect(function(input)
			if input == jumpTouchObject then releaseJump() end
		end))
	end

	-- something removed the controls (a GUI clearing out old screens): they come back
	track(lookConns, gui.AncestryChanged:Connect(function()
		if running and screenGui == gui and not gui.Parent then
			task.defer(function()
				if running and screenGui == gui and not gui.Parent then
					releaseStick()
					releaseJump()
					showLook()
				end
			end)
		end
	end))
end

----------------------------------------------------------------------------------------------------
-- on and off
----------------------------------------------------------------------------------------------------
local function startEngine()
	track(conns, UserInputService.InputChanged:Connect(function(input)
		if input == moveTouchObject then
			steer(input.Position)
		elseif input == jumpTouchObject and look and look.jump then
			-- the finger slid off the jump button: let go of it
			local pos = input.Position
			local button = look.jump.button
			local absPos, absSize = button.AbsolutePosition, button.AbsoluteSize
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
end

local function stopEngine()
	if movedByUs then
		movedByUs = false
		pcall(function() LocalPlayer:Move(ZERO, true) end)
	end
	disconnectAll(conns)
	pcall(function() RunService:UnbindFromRenderStep(STEP_VEHICLE) end)
	releaseSeat()
	unfeedAll()
end

local function describe()
	if controlsOn and oldStickOn then return "2013+old" end
	if controlsOn then return "2013" end
	if oldStickOn then return "old" end
	return nil
end

local api = {}

-- controls: the 2013 joystick and jump button; oldThumbstick: the draggable stick (in place of either joystick)
function api.Set(controlsWanted, oldStickWanted)
	controlsWanted = controlsWanted == true
	oldStickWanted = oldStickWanted == true
	if controlsWanted == controlsOn and oldStickWanted == oldStickOn then return end
	releaseStick()
	releaseJump()
	local wasRunning = running
	controlsOn, oldStickOn = controlsWanted, oldStickWanted
	running = controlsOn or oldStickOn
	if not running then
		showLook() -- (with nothing on: the controls are taken off the screen)
		stopEngine()
		setTouchMode(nil)
		genv.BPMobileControlsRunning = nil
		print("[Mobile Controls] off: Roblox's own controls are back.")
		return
	end
	if not wasRunning then startEngine() end
	setTouchMode(controlsOn and "all" or "stick")
	showLook()
	genv.BPMobileControlsRunning = describe()
	print("[Mobile Controls] on: " .. (controlsOn and "2013 controls" or "Roblox's jump button")
		.. (oldStickOn and " with the old thumbstick" or "") .. ".")
end

function api.Start()
	api.Set(true, oldStickOn)
end

function api.Stop()
	api.Set(false, false)
end

-- (older Hammer stuff: "old" for the old thumbstick with the 2013 controls, anything else for the 2013 ones)
function api.SetStyle(style)
	api.Set(true, style == "old")
end

function api.Style()
	return describe()
end

genv.BPMobileControls = api
do
	local want = genv.BPMobileControlsWant
	if type(want) == "table" then
		api.Set(want.controls, want.oldThumbstick)
	else
		api.Set(true, genv.BPMobileControlsOldStick == true)
	end
end
