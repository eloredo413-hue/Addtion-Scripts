--========================================================
-- MOBILE CONTROLS (Addtion-Scripts)
-- The 2013 mobile GUI's joystick and jump button (Roblox's 2013 TouchControlsSheet pictures), taken out of that
-- GUI so they can be used with any GUI: "mobile controls" in Hammer stuff.
-- Roblox's own touch controls are hidden while these are on, and shown again when they stop. The joystick is fed
-- into Roblox's control module, so cars and the game's own movement code react to it as to Roblox's own stick (in a
-- game without that module the character and a VehicleSeat are moved directly). Hold jump to keep jumping.
--
-- Hammer stuff uses getgenv().BPMobileControls: Start(), Stop(), Style() ("2013" while on, nil when off).
--========================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
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
local ZERO = Vector3.new(0, 0, 0)

local style = nil         -- "2013" while on, nil when stopped
local conns = {}          -- connections kept while running
local lookConns = {}      -- connections kept while one look is on screen
local screenGui = nil
local look = nil          -- the controls on screen (see build2013)

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
-- the joystick and the jump button on screen
----------------------------------------------------------------------------------------------------
-- It gives: stick (the frame the stick is in), jump (the jump button), radius() (how far the knob can go),
-- deadZone, rest() (knob centred), placeKnob(dx, dy), center() (the stick's centre on the screen), pressJump(down).

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
-- putting the controls on screen
----------------------------------------------------------------------------------------------------
local function guiHolder()
	local holder = CoreGui
	pcall(function()
		if gethui then holder = gethui() end
	end)
	return holder
end

local function showLook()
	disconnectAll(lookConns)
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

	look = build2013(gui)
	track(lookConns, look.stick.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and not moveTouchObject then grabStick(input) end
	end))

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
-- start and stop
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

-- (kept for an older Hammer stuff that still asks for a look: there is only the 2013 one now)
function api.SetStyle()
	if not style then return api.Start() end
end

function api.Start()
	if style then return end
	style = "2013"
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
	print("[Mobile Controls] 2013 controls on.")
end

function api.Style()
	return style
end

genv.BPMobileControls = api
api.Start()
