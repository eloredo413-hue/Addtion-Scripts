-- (Addtion-Scripts) The "2013 Camera" of the physics / camera setup step (Old physics camera addon.lua loads this
-- file; the Retro camera gist is the fallback). Changed here: FIRST PERSON works like the 2012-2013 Classic camera:
--   * zooming in straight into first person: the step that would bring the camera closer than 2 studs (where your
--     character starts being hidden) goes right into the head (the zoom is then 0.5), so there is one first person,
--     not a few steps inside the head first; one step out of it goes back to 2 studs (mouse wheel, I / O keys, and a
--     pinch on a phone)
--   * in first person the camera sits right in the head, with no smoothing, and the character is hidden, except
--     the tool in your hand, which stays visible; out of it the character is fully shown (no see-through stage
--     in between). The mouse stays locked in the middle, as before.
--   * zooming makes no sound (the switch3.wav tick left the default camera on January 30, 2012); the 2007 Camera
--     below keeps it
-- Everything else (third person, turning, the zoom steps further out) is the Retro camera as it was.
-- Run with CAMERA_ERA = "2007" put in front, it also follows behind you as you walk (the 2016 FollowCamera) and ticks
-- when zooming. At the end: Retro Studio's 2013 RootCameraAndControls (the other camera types, when a game switches to
-- them) and HumanoidRotate (an R6 character turned by a gyro towards where you walk). (The "2007 Camera" of the setup step is its own file now: Retro Studio's CameraScript, 2007 Camera.lua.)
local FOLLOW_2007 = (CAMERA_ERA == "2007")
-- [[ EXECUTOR CLEANUP & SAFETY ]]
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

if _G.RetroCameraHooks then
	RunService:UnbindFromRenderStep("RetroCamera")
	if _G.RetroCamMain then _G.RetroCamMain:DisconnectInputEvents() end
	if _G.RetroCamOpacityConn then _G.RetroCamOpacityConn:Disconnect() end
end
_G.RetroCameraHooks = true

-- [[ MODULE: MAIN CAMERA ]]
local Main = {}
do
	local Players = game:GetService("Players")
	local UserInputService = game:GetService("UserInputService")
	local StarterGui = game:GetService("StarterGui")
	local GuiService = game:GetService("GuiService")
	local ContextActionService = game:GetService("ContextActionService")
	local TeleportService = game:GetService("TeleportService")
	local Debris = game:GetService("Debris")

	local LocalPlayer = Players.LocalPlayer
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
	local GameSettings = UserSettings():GetService("UserGameSettings")

	local math_abs = math.abs
	local math_asin = math.asin
	local math_atan2 = math.atan2
	local math_floor = math.floor
	local math_min = math.min
	local math_max = math.max
	local math_pi = math.pi
	local math_rad = math.rad
	local Vector2_new = Vector2.new
	local Vector3_new = Vector3.new
	local CFrame_Angles = CFrame.Angles
	local CFrame_new = CFrame.new

	local MIN_Y = math_rad(-80)
	local MAX_Y = math_rad(80)

	local ZERO_VECTOR2 = Vector2_new()
	local ZERO_VECTOR3 = Vector3_new()
	local UP_VECTOR = Vector3_new(0, 1, 0)
	local XZ_VECTOR = Vector3_new(1, 0, 1)

	local TOUCH_SENSITIVTY = Vector2_new(math_pi*2.25, math_pi*2)
	local MOUSE_SENSITIVITY = Vector2_new(math_pi*4, math_pi*1.9)

	local THUMBSTICK_DEADZONE = 0.2
	local DEADZONE = 0.1
	local ZOOM_FACTOR = 0.25

	-- (Addtion-Scripts) first person like the 2012-2013 Classic camera
	local FIRST_PERSON_ZOOM = 0.5        -- the zoom first person is kept at (the camera itself sits in the head)
	local LEAVE_FIRST_PERSON_ZOOM = 0.5  -- a zoom past this is out of first person
	local ENTER_FIRST_PERSON_ZOOM = 2.0  -- zooming in closer than this goes into first person (your character is hidden
	                                     -- from here in, so a third person closer than this only looked like first person)
	local OUT_OF_FIRST_PERSON_ZOOM = 2.0 -- one step out of first person lands here

	local humanoid

	local function findPlayerHumanoid(player)
		local character = player and player.Character
		if character then
			if not (humanoid and humanoid.Parent == character) then
				humanoid = character:FindFirstChildOfClass("Humanoid")
			end
		end
		return humanoid
	end

	local function clamp(low, high, num)
		return (num > high and high or num < low and low or num)
	end

	local function findAngleBetweenXZVectors(vec2, vec1)
		return math_atan2(vec1.X*vec2.Z-vec1.Z*vec2.X, vec1.X*vec2.X + vec1.Z*vec2.Z)
	end

	local function IsFinite(num)
		return num == num and num ~= 1/0 and num ~= -1/0
	end

	local function SCurveTranform(t)
		t = clamp(-1,1,t)
		if t >= 0 then
			return (.35*t) / (.35 - t + 1)
		end
		return -((.8*-t) / (.8 + t + 1))
	end

	local function toSCurveSpace(t)
		return (1 + DEADZONE) * (2*math.abs(t) - 1) - DEADZONE
	end

	local function fromSCurveSpace(t)
		return t/2 + 0.5
	end

	local function gamepadLinearToCurve(thumbstickPosition)
		local function onAxis(axisValue)
			local sign = 1
			if axisValue < 0 then
				sign = -1
			end
			local point = fromSCurveSpace(SCurveTranform(toSCurveSpace(math_abs(axisValue))))
			point = point * sign
			return clamp(-1, 1, point)
		end
		return Vector2_new(onAxis(thumbstickPosition.x), onAxis(thumbstickPosition.y))
	end

	local SetCameraOnSpawn = true
	local this = Main

	local isFirstPerson = false
	local isRightMouseDown = false
	local isMiddleMouseDown = false

	this.Enabled = false
	this.RotateInput = ZERO_VECTOR2
	this.DefaultZoom = 10
	this.activeGamepad = nil
	this.PartSubjectHack = nil

	function this:GetHumanoid()
		local player = Players.LocalPlayer
		return findPlayerHumanoid(player)
	end

	function this:GetHumanoidRootPart()
		local humanoid = this:GetHumanoid()
		return humanoid and humanoid.Torso
	end

	function this:GetSubjectPosition()
		local camera = workspace.CurrentCamera
		local result = camera.Focus.p
		
		local cameraSubject = camera and camera.CameraSubject
		if cameraSubject then
			if cameraSubject:IsA("Humanoid") then
				local char = cameraSubject.Parent
				if char then
					local head = char:FindFirstChild("Head")
					if head and head:IsA("BasePart") then
						result = head.Position
					end
				end
				if this.PartSubjectHack then
					this:ZoomCamera(this.PartSubjectHack)
					this.PartSubjectHack = nil
					this:UpdateMouseBehavior()
				end
			elseif cameraSubject:IsA("BasePart") then
				result = cameraSubject.Position
				if not this.PartSubjectHack then
					this.PartSubjectHack = this:GetCameraZoom()
					this:ZoomCamera(10)
					this:UpdateMouseBehavior()
				end
			end
		end
		
		return result
	end

	function this:GetCameraLook()
		return workspace.CurrentCamera and workspace.CurrentCamera.CFrame.lookVector or Vector3.new(0,0,1)
	end

	function this:GetCameraZoom()
		if this.currentZoom == nil then
			local player = Players.LocalPlayer
			this.currentZoom = player and clamp(player.CameraMinZoomDistance, player.CameraMaxZoomDistance, this.DefaultZoom) or this.DefaultZoom
		end
		return this.currentZoom
	end

	function this:GetCameraActualZoom()
		local camera = workspace.CurrentCamera
		if camera then
			return (camera.CFrame.p - camera.Focus.p).Magnitude
		end
	end

	function this:ViewSizeX()
		local result = 1024
		local camera = workspace.CurrentCamera
		if camera then
			result = camera.ViewportSize.X
		end
		return result
	end

	function this:ViewSizeY()
		local result = 768
		local camera = workspace.CurrentCamera
		if camera then
			result = camera.ViewportSize.Y
		end
		return result
	end

	function this:ScreenTranslationToAngle(translationVector)
		local screenX = this:ViewSizeX()
		local screenY = this:ViewSizeY()
		local xTheta = (translationVector.x / screenX)
		local yTheta = (translationVector.y / screenY)
		return Vector2_new(xTheta, yTheta)
	end

	function this:MouseTranslationToAngle(translationVector)
		local xTheta = (translationVector.x / 1920)
		local yTheta = (translationVector.y / 1200)
		return Vector2_new(xTheta, yTheta)
	end

	function this:RotateVector(startVector, xyRotateVector)
		local startCFrame = CFrame_new(ZERO_VECTOR3, startVector)
		local resultLookVector = (CFrame_Angles(0, -xyRotateVector.x, 0) * startCFrame * CFrame_Angles(-xyRotateVector.y,0,0)).lookVector
		return resultLookVector, Vector2_new(xyRotateVector.x, xyRotateVector.y)
	end

	function this:RotateCamera(startLook, xyRotateVector)
		local startVertical = math_asin(startLook.y)
		local yTheta = clamp(-MAX_Y + startVertical, -MIN_Y + startVertical, xyRotateVector.y)
		return self:RotateVector(startLook, Vector2_new(xyRotateVector.x, yTheta))
	end

	function this:IsInFirstPerson()
		return isFirstPerson
	end

	function this:UpdateMouseBehavior()
		if isFirstPerson or this.PartSubjectHack then
			GameSettings.RotationType = Enum.RotationType.CameraRelative
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		else
			GameSettings.RotationType = Enum.RotationType.MovementRelative
			if isRightMouseDown or isMiddleMouseDown then
				UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
			else
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
		end
	end

	function this:PlayTick()
		-- (Addtion-Scripts) silent from 2012 on: only the 2007 Camera still ticks
		if not FOLLOW_2007 then return end
		local now = tick()
		local lastTickSound = this.LastTickSound
		if not lastTickSound then
			lastTickSound = 0
		end
		
		if (now - lastTickSound) > .03 then
			local s = Instance.new("Sound")
			s.SoundId = "rbxasset://sounds/switch3.wav"
			s.Parent = script
			s:Play()
			Debris:AddItem(s,1)
			this.LastTickSound = now
		end
	end

	function this:ZoomCamera(desiredZoom)
		this.currentZoom = clamp(0.25, 400, desiredZoom)
		isFirstPerson = self:GetCameraZoom() <= LEAVE_FIRST_PERSON_ZOOM
		self:UpdateMouseBehavior()
		return self:GetCameraZoom()
	end

	function this:ZoomCameraBy(input)
		local zoom = this:GetCameraActualZoom()
		if zoom then
			if isFirstPerson then
				-- (Addtion-Scripts) one step out of the head: 2 studs, where you see your character again
				zoom = input < 0 and OUT_OF_FIRST_PERSON_ZOOM or FIRST_PERSON_ZOOM
			elseif input > 0 then
				zoom = zoom / (1 + ZOOM_FACTOR*input)
				-- (Addtion-Scripts) closer than 2 studs: straight into first person
				if zoom < ENTER_FIRST_PERSON_ZOOM then zoom = FIRST_PERSON_ZOOM end
			elseif input < 0 then
				zoom = math.min(5000, zoom * (1 - ZOOM_FACTOR*input))
			end
			self:ZoomCamera(zoom)
		end
		
		self:PlayTick() -- (silent except in the 2007 Camera)
		return self:GetCameraZoom()
	end

	function this:ZoomCameraFixedBy(zoomIncrement)
		return self:ZoomCamera(self:GetCameraZoom() + zoomIncrement)
	end

	local startPos = nil
	local lastPos = nil
	local panBeginLook = nil
	local lastTapTime = nil
	local fingerTouches = {}
	local NumUnsunkTouches = 0
	local inputStartPositions = {}
	local inputStartTimes = {}
	local StartingDiff = nil
	local pinchBeginZoom = nil
	local dynamicThumbstickFrame = nil
	local flaggedDynamic = {}
	
	this.ZoomEnabled = true
	this.PanEnabled = true
	this.KeyPanEnabled = true

	local function inputIsDynamic(input)
		if flaggedDynamic[input] ~= nil then
			return flaggedDynamic[input]
		end
		if GameSettings.TouchMovementMode ~= Enum.TouchMovementMode.DynamicThumbstick then
			return false
		end
		flaggedDynamic[input] = false
		return false
	end
	
	local function OnTouchBegan(input, processed)
		if not inputIsDynamic(input) then
			fingerTouches[input] = processed
			if not processed then
				inputStartPositions[input] = input.Position
				inputStartTimes[input] = tick()
				NumUnsunkTouches = NumUnsunkTouches + 1
			end
		end
	end
	
	local function OnTouchChanged(input, processed)
		if inputIsDynamic(input) then return end
		if fingerTouches[input] == nil then
			fingerTouches[input] = processed
			if not processed then
				NumUnsunkTouches = NumUnsunkTouches + 1
			end
		end
		if NumUnsunkTouches == 1 then
			if fingerTouches[input] == false then
				panBeginLook = panBeginLook or this:GetCameraLook()
				startPos = startPos or input.Position
				lastPos = lastPos or startPos
				this.UserPanningTheCamera = true
				local delta = input.Position - lastPos		
				delta = Vector2.new(delta.X, delta.Y * GameSettings:GetCameraYInvertValue())
				if this.PanEnabled then
					local desiredXYVector = this:ScreenTranslationToAngle(delta) * TOUCH_SENSITIVTY
					this.RotateInput = this.RotateInput + desiredXYVector
				end
				lastPos = input.Position
			end
		else
			panBeginLook = nil
			startPos = nil
			lastPos = nil
			this.UserPanningTheCamera = false
		end
		
		if NumUnsunkTouches == 2 then
			local unsunkTouches = {}
			for touch, wasSunk in pairs(fingerTouches) do
				if not wasSunk then
					table.insert(unsunkTouches, touch)
				end
			end
			if #unsunkTouches == 2 then
				local difference = (unsunkTouches[1].Position - unsunkTouches[2].Position).magnitude
				if StartingDiff and pinchBeginZoom then
					local scale = difference / math_max(0.01, StartingDiff)
					local clampedScale = clamp(0.1, 10, scale)
					if this.ZoomEnabled then
						-- (Addtion-Scripts) in and out of first person like the wheel: fingers spread to closer than
						-- 2 studs -> straight into first person; in first person, fingers pinched in by one zoom step
						-- -> out to 2 studs
						local snapTo = nil
						if isFirstPerson then
							if clampedScale <= 1 / (1 + ZOOM_FACTOR) then snapTo = OUT_OF_FIRST_PERSON_ZOOM end
						else
							local desired = pinchBeginZoom / clampedScale
							if clampedScale > 1 and desired < ENTER_FIRST_PERSON_ZOOM then
								snapTo = FIRST_PERSON_ZOOM
							else
								this:ZoomCamera(math.max(desired, ENTER_FIRST_PERSON_ZOOM))
							end
						end
						if snapTo then
							this:ZoomCamera(snapTo)
							-- the pinch carries on from here
							StartingDiff = difference
							pinchBeginZoom = snapTo
						end
					end
				else
					StartingDiff = difference
					pinchBeginZoom = this:GetCameraActualZoom()
				end
			end
		else
			StartingDiff = nil
			pinchBeginZoom = nil
		end
	end
	
	local function OnTouchEnded(input, processed)
		if fingerTouches[input] == false then
			if NumUnsunkTouches == 1 then
				panBeginLook = nil
				startPos = nil
				lastPos = nil
				this.UserPanningTheCamera = false -- (Addtion-Scripts) the finger is up: no longer looking around
			elseif NumUnsunkTouches == 2 then
				StartingDiff = nil
				pinchBeginZoom = nil
			end
		end
		if fingerTouches[input] ~= nil and fingerTouches[input] == false then
			NumUnsunkTouches = NumUnsunkTouches - 1
		end
		fingerTouches[input] = nil
		inputStartPositions[input] = nil
		inputStartTimes[input] = nil
		flaggedDynamic[input] = nil
	end
	
	local function OnMousePanButtonPressed(input, processed)
		if processed then return end
		this:UpdateMouseBehavior()
		panBeginLook = panBeginLook or this:GetCameraLook()
		startPos = startPos or input.Position
		lastPos = lastPos or startPos
		this.UserPanningTheCamera = true
	end
	
	local function OnMousePanButtonReleased(input, processed)
		this:UpdateMouseBehavior()
		if not (isRightMouseDown or isMiddleMouseDown) then
			panBeginLook = nil
			startPos = nil
			lastPos = nil
			this.UserPanningTheCamera = false
		end
	end
	
	local function OnMouse2Down(input, processed)
		if processed then return end
		isRightMouseDown = true
		OnMousePanButtonPressed(input, processed)
	end
	
	local function OnMouse2Up(input, processed)
		isRightMouseDown = false
		OnMousePanButtonReleased(input, processed)
	end
	
	local function OnMouse3Down(input, processed)
		if processed then return end
		isMiddleMouseDown = true
		OnMousePanButtonPressed(input, processed)
	end
	
	local function OnMouse3Up(input, processed)
		isMiddleMouseDown = false
		OnMousePanButtonReleased(input, processed)
	end
	
	local function OnMouseMoved(input, processed)
		local inputDelta = input.Delta
		inputDelta = Vector2.new(inputDelta.X, inputDelta.Y * GameSettings:GetCameraYInvertValue())
		if startPos and lastPos and panBeginLook then
			local currPos = lastPos + input.Delta
			if this.PanEnabled then
				local desiredXYVector = this:MouseTranslationToAngle(inputDelta) * MOUSE_SENSITIVITY
				this.RotateInput = this.RotateInput + desiredXYVector
			end
			lastPos = currPos
		elseif (this:IsInFirstPerson() or this.PartSubjectHack) and this.PanEnabled then
			local desiredXYVector = this:MouseTranslationToAngle(inputDelta) * MOUSE_SENSITIVITY
			this.RotateInput = this.RotateInput + desiredXYVector
		end
	end
	
	local function OnMouseWheel(input, processed)
		if not processed and this.ZoomEnabled then
			this:ZoomCameraBy(clamp(-1, 1, input.Position.Z))
		end
	end
	
	local function round(num)
		return math_floor(num + 0.5)
	end
	local eight2Pi = math_pi / 4
	
	local function rotateVectorByAngleAndRound(camLook, rotateAngle, roundAmount)
		if camLook ~= ZERO_VECTOR3 then
			camLook = camLook.unit
			local currAngle = math_atan2(camLook.z, camLook.x)
			local newAngle = round((math_atan2(camLook.z, camLook.x) + rotateAngle) / roundAmount) * roundAmount
			return newAngle - currAngle
		end
		return 0
	end
	
	local function OnKeyDown(input, processed)
		if processed then return end
		if this.ZoomEnabled then
			if input.KeyCode == Enum.KeyCode.I then
				this:ZoomCameraBy(1)
			elseif input.KeyCode == Enum.KeyCode.O then
				this:ZoomCameraBy(-1)
			end
		end
		if panBeginLook == nil and this.KeyPanEnabled then
			if input.KeyCode == Enum.KeyCode.Left then
				this.TurningLeft = true
			elseif input.KeyCode == Enum.KeyCode.Right then
				this.TurningRight = true
			elseif input.KeyCode == Enum.KeyCode.Comma then
				local angle = rotateVectorByAngleAndRound(this:GetCameraLook() * Vector3.new(1,0,1), -eight2Pi * (3/4), eight2Pi)
				if angle ~= 0 then
					this.RotateInput = this.RotateInput + Vector2.new(angle, 0)
					this.LastUserPanCamera = tick()
					this.LastCameraTransform = nil
				end
				this:PlayTick()
			elseif input.KeyCode == Enum.KeyCode.Period then
				local angle = rotateVectorByAngleAndRound(this:GetCameraLook() * Vector3.new(1,0,1), eight2Pi * (3/4), eight2Pi)
				if angle ~= 0 then
					this.RotateInput = this.RotateInput + Vector2.new(angle, 0)
					this.LastUserPanCamera = tick()
					this.LastCameraTransform = nil
				end
				this:PlayTick()
			elseif input.KeyCode == Enum.KeyCode.PageUp then
				this.RotateInput = this.RotateInput + Vector2.new(0,math_pi/12)
				this.LastCameraTransform = nil
				this:PlayTick()
			elseif input.KeyCode == Enum.KeyCode.PageDown then
				this.RotateInput = this.RotateInput + Vector2.new(0,-math_pi/12)
				this.LastCameraTransform = nil
				this:PlayTick()
			end
		end
	end
	
	local function OnKeyUp(input, processed)
		if input.KeyCode == Enum.KeyCode.Left then
			this.TurningLeft = false
		elseif input.KeyCode == Enum.KeyCode.Right then
			this.TurningRight = false
		end
	end
	
	local lastThumbstickRotate = nil
	local numOfSeconds = 0.7
	local currentSpeed = 0
	local maxSpeed = 6
	local lastThumbstickPos = Vector2.new(0,0)
	local ySensitivity = 0.65
	local lastVelocity = nil
	
	function this:UpdateGamepad()
		local gamepadPan = this.GamepadPanningCamera
		if gamepadPan then
			gamepadPan = gamepadLinearToCurve(gamepadPan)
			local currentTime = tick()
			if gamepadPan.X ~= 0 or gamepadPan.Y ~= 0 then
				this.userPanningTheCamera = true
			elseif gamepadPan == ZERO_VECTOR2 then
				lastThumbstickRotate = nil
				if lastThumbstickPos == ZERO_VECTOR2 then
					currentSpeed = 0
				end
			end
			local finalConstant = 0
			if lastThumbstickRotate then
				local elapsed = (currentTime - lastThumbstickRotate) * 10
				currentSpeed = currentSpeed + (maxSpeed * ((elapsed*elapsed)/numOfSeconds))
				if currentSpeed > maxSpeed then currentSpeed = maxSpeed end
				if lastVelocity then
					local velocity = (gamepadPan - lastThumbstickPos)/(currentTime - lastThumbstickRotate)
					local velocityDeltaMag = (velocity - lastVelocity).magnitude
					if velocityDeltaMag > 12 then
						currentSpeed = currentSpeed * (20/velocityDeltaMag)
						if currentSpeed > maxSpeed then currentSpeed = maxSpeed end
					end
				end
				local gamepadCameraSensitivity = GameSettings.GamepadCameraSensitivity
				finalConstant = (gamepadCameraSensitivity * currentSpeed)
				lastVelocity = (gamepadPan - lastThumbstickPos)/(currentTime - lastThumbstickRotate)
			end
			lastThumbstickPos = gamepadPan
			lastThumbstickRotate = currentTime
			return Vector2_new( gamepadPan.X * finalConstant, gamepadPan.Y * finalConstant * ySensitivity * GameSettings:GetCameraYInvertValue())
		end
		return ZERO_VECTOR2
	end
	
	local InputEvents = {}

	function this:DisconnectInputEvents()
		while true do
			local signalName = next(InputEvents)
			if signalName then
				InputEvents[signalName]:Disconnect()
				InputEvents[signalName] = nil
			else
				break
			end
		end
		this.TurningLeft = false
		this.TurningRight = false
		this.LastCameraTransform = nil
		this.UserPanningTheCamera = false
		this.RotateInput = ZERO_VECTOR2
		this.GamepadPanningCamera = ZERO_VECTOR2
		startPos = nil
		lastPos = nil
		panBeginLook = nil
		isRightMouseDown = false
		isMiddleMouseDown = false
		fingerTouches = {}
		NumUnsunkTouches = 0
		StartingDiff = nil
		pinchBeginZoom = nil
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end
	
	local function resetInputStates()
		isRightMouseDown = false
		isMiddleMouseDown = false
		OnMousePanButtonReleased()
		if UserInputService.TouchEnabled then
			for inputObject, value in pairs(fingerTouches) do
				fingerTouches[inputObject] = nil
			end
			panBeginLook = nil
			startPos = nil
			lastPos = nil
			this.UserPanningTheCamera = false
			StartingDiff = nil
			pinchBeginZoom = nil
			NumUnsunkTouches = 0
		end
	end
	
	local function getGamepadPan(name, state, input)
		if input.UserInputType == this.activeGamepad and input.KeyCode == Enum.KeyCode.Thumbstick2 then
			if state == Enum.UserInputState.Cancel then
				this.GamepadPanningCamera = ZERO_VECTOR2
				return
			end		
			local inputVector = Vector2.new(input.Position.X, -input.Position.Y)
			if inputVector.magnitude > THUMBSTICK_DEADZONE then
				this.GamepadPanningCamera = Vector2_new(input.Position.X, -input.Position.Y)
			else
				this.GamepadPanningCamera = ZERO_VECTOR2
			end
		end
	end
	
	local function doGamepadZoom(name, state, input)
		if input.UserInputType == this.activeGamepad and input.KeyCode == Enum.KeyCode.ButtonR3 and state == Enum.UserInputState.Begin then
			if this.ZoomEnabled then
				if this:GetCameraZoom() > 0.5 then
					this:ZoomCamera(0)
				else
					this:ZoomCamera(10)
				end
			end
		end
	end

	local function assignActivateGamepad()
		local connectedGamepads = UserInputService:GetConnectedGamepads()
		if #connectedGamepads > 0 then
			for i = 1, #connectedGamepads do
				if this.activeGamepad == nil then
					this.activeGamepad = connectedGamepads[i]
				elseif connectedGamepads[i].Value < this.activeGamepad.Value then
					this.activeGamepad = connectedGamepads[i]
				end
			end
		end
		if this.activeGamepad == nil then 
			this.activeGamepad = Enum.UserInputType.Gamepad1
		end
	end
	
	local function onInputBegan(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch then
			OnTouchBegan(input, processed)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			OnMouse2Down(input, processed)
		elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
			OnMouse3Down(input, processed)
		end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			OnKeyDown(input, processed)
		end
	end
	
	local function onInputChanged(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch then
			OnTouchChanged(input, processed)
		elseif input.UserInputType == Enum.UserInputType.MouseMovement then
			OnMouseMoved(input, processed)
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			OnMouseWheel(input, processed)
		end
	end
	
	local function onInputEnded(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch then
			OnTouchEnded(input, processed)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			OnMouse2Up(input, processed)
		elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
			OnMouse3Up(input, processed)
		end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			OnKeyUp(input, processed)
		end
	end
	
	local inputPassCmds = { ZoomIn = Enum.KeyCode.I, ZoomOut = Enum.KeyCode.O, RotateUp = Enum.KeyCode.PageUp, RotateDown = Enum.KeyCode.PageDown }
	local function onInputPassed(command)
		local passKey = inputPassCmds[command]
		if passKey then
			OnKeyDown({KeyCode = passKey}, false)
		end
	end
	
	local function onGamepadConnected(gamepadEnum)
		if this.activeGamepad == nil then assignActivateGamepad() end
	end
	local function onGamepadDisconnected(gamepadEnum)
		if this.activeGamepad ~= gamepadEnum then return end
		this.activeGamepad = nil
		assignActivateGamepad()
	end
	
	function this:ConnectInputEvents()
		this.RotateInput = ZERO_VECTOR2
		this.activeGamepad = nil
		
		InputEvents = {
			InputBegan = UserInputService.InputBegan:Connect(onInputBegan),
			InputChanged = UserInputService.InputChanged:Connect(onInputChanged),
			InputEnded = UserInputService.InputEnded:Connect(onInputEnded),
			MenuOpened = GuiService.MenuOpened:Connect(resetInputStates),
			GamepadConnected = UserInputService.GamepadConnected:Connect(onGamepadConnected),
			GamepadDisconnected = UserInputService.GamepadDisconnected:Connect(onGamepadDisconnected),
		}
	
		ContextActionService:BindAction("RootCamGamepadPan", getGamepadPan, false, Enum.KeyCode.Thumbstick2)
		ContextActionService:BindAction("RootCamGamepadZoom", doGamepadZoom, false, Enum.KeyCode.ButtonR3)
		assignActivateGamepad()
		self:UpdateMouseBehavior()
	end
	
	function this:SetEnabled(newState)
		if newState ~= self.Enabled then
			self.Enabled = newState
			if self.Enabled then
				self:ConnectInputEvents()
			else
				self:DisconnectInputEvents()
			end
		end
	end
	
	local function OnPlayerAdded(player)
		player.Changed:Connect(function (prop)
			if this.Enabled then
				if prop == "CameraMode" or prop == "CameraMaxZoomDistance" or prop == "CameraMinZoomDistance" then
					this:ZoomCameraFixedBy(0)
				end
			end
		end)
		
		local function OnCharacterAdded(newCharacter)
			local humanoid = findPlayerHumanoid(player)
			local start = tick()
			while tick() - start < 0.3 and (humanoid == nil or humanoid.Torso == nil) do
				task.wait()
				humanoid = findPlayerHumanoid(player)
			end
	
			if humanoid and humanoid.Torso and player.Character == newCharacter then
				local newDesiredLook = (humanoid.Torso.CFrame.lookVector - Vector3.new(0,0.23,0)).unit
				local horizontalShift = findAngleBetweenXZVectors(newDesiredLook, this:GetCameraLook())
				local vertShift = math_asin(this:GetCameraLook().y) - math_asin(newDesiredLook.y)
				if not IsFinite(horizontalShift) then horizontalShift = 0 end
				if not IsFinite(vertShift) then vertShift = 0 end
				this.RotateInput = Vector2.new(horizontalShift, vertShift)
				this.LastCameraTransform = nil
			end
			task.wait()
			this:ZoomCamera(this.DefaultZoom)
		end
	
		player.CharacterAdded:Connect(function (character)
			if this.Enabled or SetCameraOnSpawn then
				OnCharacterAdded(character)
				SetCameraOnSpawn = false
			end
		end)
		
		if player.Character then
			task.spawn(function () OnCharacterAdded(player.Character) end)
		end
	end
	
	if Players.LocalPlayer then OnPlayerAdded(Players.LocalPlayer) end
	Players.ChildAdded:Connect(function (child)
		if child and Players.LocalPlayer == child then OnPlayerAdded(Players.LocalPlayer) end
	end)
	
	local tweenSpeed = math_rad(0)
	local timeBeforeAutoRotate = 2
	local lastUpdate = tick()
	this.LastUserPanCamera = lastUpdate
	
	function this:Update()
		local now = tick()
		local timeDelta = (now - lastUpdate)
		local userPanningTheCamera = (self.UserPanningTheCamera == true)
		local camera = 	workspace.CurrentCamera
		local humanoid = self:GetHumanoid()
		local cameraSubject = camera and camera.CameraSubject
		local isInVehicle = cameraSubject and cameraSubject:IsA('VehicleSeat')
		local isOnASkateboard = cameraSubject and cameraSubject:IsA('SkateboardPlatform')
		
		if isInVehicle and cameraSubject.Occupant == humanoid then
			cameraSubject = humanoid
			camera.CameraSubject = humanoid
			isInVehicle = false
		end
		
		if lastUpdate == nil or (now - lastUpdate) > 1 then
			self.LastCameraTransform = nil
		end
		
		if lastUpdate then
			local gamepadRotation = self:UpdateGamepad()
			local delta = math_min(0.1, now - lastUpdate)
			
			if gamepadRotation ~= ZERO_VECTOR2 then
				userPanningTheCamera = true
				self.RotateInput = self.RotateInput + (gamepadRotation * delta)
			end
			local angle = 0
			if not (isInVehicle or isOnASkateboard) then
				angle = angle + (self.TurningLeft and -120 or 0)
				angle = angle + (self.TurningRight and 120 or 0)
			end
			if angle ~= 0 then
				self.RotateInput = self.RotateInput +  Vector2.new(math_rad(angle * delta), 0)
				userPanningTheCamera = true
			end
		end
	
		if userPanningTheCamera then
			tweenSpeed = 0
			self.LastUserPanCamera = now
		end
		
		local subjectPosition = self:GetSubjectPosition()
		if subjectPosition and camera then
			local zoom = self:GetCameraZoom()
			if zoom < 0.25 then zoom = 0.25 end

			if FOLLOW_2007 or self.ForceFollow then
				-- (2007 Camera) the old FollowCamera: turns towards where you walk, unless you have just looked around
				local recentlyPanned = now - (self.LastUserPanCamera or 0) < 2
				if self.LastCameraTransform and not userPanningTheCamera and not recentlyPanned and not self:IsInFirstPerson() then
					local lastVec = -(self.LastCameraTransform.p - subjectPosition)
					local y = findAngleBetweenXZVectors(lastVec, self:GetCameraLook())
					if IsFinite(y) and math.abs(y) > 0.0001 and math.abs(y) > 0.4 * timeDelta then
						self.RotateInput = self.RotateInput + Vector2.new(y, 0)
					end
				end
			elseif TeleportService:GetTeleportSetting("FollowCamera") then
				if self.LastCameraTransform and not self:IsInFirstPerson() then
					local lastVec = -(self.LastCameraTransform.p - subjectPosition)
					local y = findAngleBetweenXZVectors(lastVec, self:GetCameraLook())
					if IsFinite(y) and math.abs(y) > 0.0001 then
						self.RotateInput = self.RotateInput + Vector2.new(y, 0)
					end
				end
			end

			camera.Focus = CFrame_new(subjectPosition)
			local newLookVector = self:RotateCamera(self:GetCameraLook(), self.RotateInput)
			self.RotateInput = ZERO_VECTOR2
			
			if self.LastZoom ~= zoom then
				self.LastZoom = zoom
				if camera.CameraSubject and camera.CameraSubject:IsA("Humanoid") then
					newLookVector = (newLookVector * XZ_VECTOR).Unit
					local upY = -math_min(6, zoom/40)
					newLookVector = (newLookVector + (UP_VECTOR * upY)).Unit
				end
			end
			
			if self:IsInFirstPerson() and camera.CameraSubject and camera.CameraSubject:IsA("Humanoid") then
				-- (Addtion-Scripts) first person like the 2012 camera: right in the head, no smoothing
				camera.CFrame = CFrame_new(subjectPosition, subjectPosition + newLookVector)
				-- (Addtion-Scripts) and you face where you look at once, so the tool in your hand turns with you
				-- instead of being left behind while the body catches up (not while sitting, climbing or ragdolled)
				local hum = camera.CameraSubject
				local root = hum.RootPart
				local me = Players.LocalPlayer
				if root and me and hum.Parent == me.Character and not hum.Sit and not hum.PlatformStand
					and hum:GetState() ~= Enum.HumanoidStateType.Climbing then
					local flat = newLookVector * XZ_VECTOR
					if flat.Magnitude > 0.01 then
						local pos = root.Position
						root.CFrame = CFrame_new(pos, pos + flat.Unit)
					end
				end
			else
				local newCF = CFrame_new(subjectPosition - (zoom * newLookVector), subjectPosition)
				camera.CFrame = camera.CFrame:Lerp(newCF,.8)
			end
			self.LastCameraTransform = camera.CFrame
		end
		lastUpdate = now
	end
	
	GameSettings:SetCameraYInvertVisible()
	GameSettings:SetGamepadCameraSensitivityVisible()

	_G.RetroCamMain = this
end


-- [[ MODULE: OPACITY ]]
local Opacity = {}
do
	local LastUpdate = tick()
	local TransparencyDirty = false
	local Enabled = false
	local LastTransparency = nil
	local DescendantAddedConn, DescendantRemovingConn = nil, nil
	local ToolDescendantAddedConns = {}
	local ToolDescendantRemovingConns = {}
	local CachedParts = {}

	local Character = nil -- the character being hidden in first person

	local function IsValidPartToModify(part)
		return part:IsA('BasePart') or part:IsA('Decal')
	end

	-- (Addtion-Scripts) a part of the tool in your hand (a Tool held by the character): it stays visible in first person
	local function IsInHeldTool(part)
		local tool = part:FindFirstAncestorOfClass("Tool")
		return tool ~= nil and Character ~= nil and tool.Parent == Character
	end

	local function TeardownTransparency()
		for child, _ in pairs(CachedParts) do
			if child:IsA("BasePart") or child:IsA("Decal") then
				child.LocalTransparencyModifier = 0
			end
		end
		CachedParts = {}
		Character = nil
		TransparencyDirty = true
		LastTransparency = nil

		if DescendantAddedConn then DescendantAddedConn:Disconnect(); DescendantAddedConn = nil end
		if DescendantRemovingConn then DescendantRemovingConn:Disconnect(); DescendantRemovingConn = nil end
		
		for object, conn in pairs(ToolDescendantAddedConns) do conn:Disconnect(); ToolDescendantAddedConns[object] = nil end
		for object, conn in pairs(ToolDescendantRemovingConns) do conn:Disconnect(); ToolDescendantRemovingConns[object] = nil end
	end

	local function SetupTransparency(character)
		TeardownTransparency()
		Character = character
		if DescendantAddedConn then DescendantAddedConn:Disconnect() end
		
		DescendantAddedConn = character.DescendantAdded:Connect(function (object)
			if IsValidPartToModify(object) then
				CachedParts[object] = true
				TransparencyDirty = true
			end
		end)
		
		if DescendantRemovingConn then DescendantRemovingConn:Disconnect() end
		DescendantRemovingConn = character.DescendantRemoving:Connect(function (object)
			if CachedParts[object] then
				CachedParts[object] = nil
				object.LocalTransparencyModifier = 0
			end
		end)
		
		for _,desc in pairs(character:GetDescendants()) do
			if IsValidPartToModify(desc) then
				CachedParts[desc] = true
				TransparencyDirty = true
			end
		end
	end

	function Opacity:SetEnabled(newState)
		if Enabled ~= newState then
			Enabled = newState
			self:Update()
		end
	end

	function Opacity:SetSubject(subject)
		local character = nil
		if subject and subject:IsA("Humanoid") then character = subject.Parent end
		if subject and subject:IsA("VehicleSeat") and subject.Occupant then character = subject.Occupant.Parent end
		if character then
			SetupTransparency(character)
		else
			TeardownTransparency()
		end
	end

	function Opacity:Update()
		local instant = false
		local now = tick()
		local currentCamera = workspace.CurrentCamera

		if currentCamera then
			local transparency = 0
			if not Enabled then
				instant = true
			else
				-- (Addtion-Scripts) like the 2012 camera: hidden in first person, fully shown out of it (also
				-- hidden when a wall pushes the camera into the character)
				local distance = (currentCamera.Focus.p - currentCamera.CFrame.p).magnitude
				if Main:IsInFirstPerson() or distance < 2 then transparency = 1
				else transparency = 0 end
			end

			if TransparencyDirty or LastTransparency ~= transparency then
				for child in pairs(CachedParts) do
					if child:IsA("BasePart") or child:IsA("Decal") then
						local value = IsInHeldTool(child) and 0 or transparency
						if child.ClassName == "Decal" then
							child.LocalTransparencyModifier = math.floor(value)
						else
							child.LocalTransparencyModifier = value
						end
					end
				end
				TransparencyDirty = false
				LastTransparency = transparency
			end
		end
		LastUpdate = now
	end
end


-- [[ MODULE: POPPER CAM ]]
local PopperCam = {}
do
	local POP_RESTORE_RATE = 0.3
	local MIN_CAMERA_ZOOM = 0.5
	local Players = game:GetService('Players')

	local Camera = nil
	local CameraSubjectChangeConn = nil
	local SubjectPart = nil
	local PlayerCharacters = {} 
	local VehicleParts = {} 

	local LastPopAmount = 0
	local LastZoomLevel = 0
	local PopperEnabled = true

	local CFrame_new = CFrame.new
	local math_abs = math.abs

	local function OnCharacterAdded(player, character)
		PlayerCharacters[player] = character
	end

	local function OnPlayersChildAdded(child)
		if child:IsA('Player') then
			child.CharacterAdded:Connect(function(character)
				OnCharacterAdded(child, character)
			end)
			if child.Character then
				OnCharacterAdded(child, child.Character)
			end
		end
	end

	local function OnPlayersChildRemoved(child)
		if child:IsA('Player') then
			PlayerCharacters[child] = nil
		end
	end

	function PopperCam:Update()
		if PopperEnabled then
			local Camera = workspace.CurrentCamera
			if not Camera or Camera.CameraType.Name == "Fixed" then return end
			
			local cameraCFrame = Camera.CFrame
			local focusPoint = Camera.Focus.p
			if SubjectPart then focusPoint = SubjectPart.CFrame.p end

			local ignoreList = {}
			for _, character in pairs(PlayerCharacters) do
				ignoreList[#ignoreList + 1] = character
			end
			for i = 1, #VehicleParts do
				ignoreList[#ignoreList + 1] = VehicleParts[i]
			end
			
			local largest = Camera:GetLargestCutoffDistance(ignoreList)
			local zoomLevel = (cameraCFrame.p - focusPoint).Magnitude
			if math_abs(zoomLevel - LastZoomLevel) > 0.001 then LastPopAmount = 0 end
			
			local popAmount = largest
			if LastPopAmount > popAmount then popAmount = LastPopAmount end

			if popAmount > 0 then
				Camera.CFrame = cameraCFrame + (cameraCFrame.lookVector * popAmount)
				LastPopAmount = popAmount - POP_RESTORE_RATE 
				if LastPopAmount < 0 then LastPopAmount = 0 end
			end
			LastZoomLevel = zoomLevel
		end
	end

	Players.ChildRemoved:Connect(OnPlayersChildRemoved)
	Players.ChildAdded:Connect(OnPlayersChildAdded)
	for _, player in pairs(Players:GetPlayers()) do
		OnPlayersChildAdded(player)
	end
end


-- [[ BOOTSTRAPPER & EVENT BINDING ]]
local function onCameraSubjectChanged()
	local currentCamera = workspace.CurrentCamera
	if currentCamera then
		local newSubject = currentCamera.CameraSubject
		Opacity:SetSubject(newSubject)
	end
end

local function onNewCamera()
	local currentCamera = workspace.CurrentCamera
	if currentCamera then
		if _G.RetroCamOpacityConn then _G.RetroCamOpacityConn:Disconnect() end
		
		local cameraSubjectChanged = currentCamera:GetPropertyChangedSignal("CameraSubject")
		_G.RetroCamOpacityConn = cameraSubjectChanged:Connect(onCameraSubjectChanged)
		
		onCameraSubjectChanged()
	end
end

-- Initialize cameras.
local cameraUpdated = workspace:GetPropertyChangedSignal("CurrentCamera")
cameraUpdated:Connect(onNewCamera)

onNewCamera()
Main:SetEnabled(true)
Opacity:SetEnabled(true)

-- Overload the camera update function.
-- (Addtion-Scripts) only the normal camera (Custom) is this one's: when a game switches to another camera type (a
-- cutscene's Scriptable, Attach, Watch...), RootCameraAndControls below drives it, as in Retro Studio
local function update()
	local cam = workspace.CurrentCamera
	if not cam or cam.CameraType == Enum.CameraType.Custom then
		Main:Update()
		if not Main:IsInFirstPerson() then PopperCam:Update() end -- (Addtion-Scripts) the camera stays in the head
	end
	Opacity:Update()

	-- Remove the default Roblox camera handler so our retro logic takes full priority
	RunService:UnbindFromRenderStep("cameraRenderUpdate")
end

-- Bind our update cycle right before rendering
RunService:BindToRenderStep("RetroCamera", 250, update)


--========================================================
-- RETRO STUDIO'S RootCameraAndControls AND HumanoidRotate (Addtion-Scripts)
-- Retro Studio's 2013 StarterPlayerScripts.RootCameraAndControls and StarterCharacterScripts.HumanoidRotate, as they
-- were given, made to run from an executor. Changed only where they used things that are Retro Studio's own:
--   * shared.UserSettings (Retro Studio's stand-in for the old client's features): here, the old client (no Lua
--     vehicle controller, not every camera in Lua), so the camera types are handled as Retro Studio's 2013 does
--   * ReplicatedStorage's "RobloxVersion" attribute: the game's, else 109 (a 2013 client)
--   * the modules they find next to them (CameraScript.RootCamera, ControlScript.MasterControl, script.Cameras,
--     script.VehicleController): written here, on top of this camera
-- HumanoidRotate turns an R6 character (Retro Studio leaves R15 to Roblox): towards where you walk with a gyro, and
-- at once to where you look in first person. It steps aside while the Old physics runs (that has Rowind's own).
--========================================================
do
	local ReplicatedStorageService = game:GetService("ReplicatedStorage")
	local RealRunService = game:GetService("RunService")
	local VERSION_2013 = 109

	local function robloxVersion()
		local value = nil
		pcall(function() value = ReplicatedStorageService:GetAttribute("RobloxVersion") end)
		return type(value) == "number" and value or VERSION_2013
	end

	-- what these scripts see as game:GetService: the real services, with RobloxVersion always there
	local function makeGame(onRenderStepped)
		local fakeStorage = setmetatable({}, { __index = function(_, key)
			if key == "GetAttribute" then
				return function(_, name)
					if name == "RobloxVersion" then return robloxVersion() end
					return ReplicatedStorageService:GetAttribute(name)
				end
			end
			local value = ReplicatedStorageService[key]
			if type(value) == "function" then return function(_, ...) return value(ReplicatedStorageService, ...) end end
			return value
		end })
		local fakeRunService = setmetatable({}, { __index = function(_, key)
			if key == "RenderStepped" and onRenderStepped then
				return { Connect = function(_, fn) return onRenderStepped(fn) end }
			end
			local value = RealRunService[key]
			if type(value) == "function" then return function(_, ...) return value(RealRunService, ...) end end
			return value
		end })
		return {
			GetService = function(_, name)
				if name == "ReplicatedStorage" then return fakeStorage end
				if name == "RunService" then return fakeRunService end
				return game:GetService(name)
			end,
		}
	end

	-- the old client: neither feature on
	local OldClientSettings = function()
		return { IsUserFeatureEnabled = function() return false end }
	end

	-- RootCamera for the other camera types, on top of this camera (Main)
	local function RootCamera()
		local this = { Enabled = false }
		function this:GetSubjectPosition() return Main:GetSubjectPosition() end
		function this:GetCameraLook() return Main:GetCameraLook() end
		function this:GetCameraZoom() return Main:GetCameraZoom() end
		function this:SetEnabled(on) self.Enabled = on end
		function this:Update() end
		return this
	end

	local CAMERA_MODULES = {
		FixedCamera = function(Root) return function() return Root() end end,
		ScriptableCamera = function(Root) return function() return Root() end end,
		TrackCamera = function(Root)
			return function()
				local cam = Root()
				function cam:Update() Main:Update() PopperCam:Update() end
				return cam
			end
		end,
		FollowCamera = function(Root)
			return function()
				local cam = Root()
				function cam:Update()
					Main.ForceFollow = true
					Main:Update()
					Main.ForceFollow = false
					PopperCam:Update()
				end
				return cam
			end
		end,
		WatchCamera = function(Root)
			return function()
				local cam = Root()
				function cam:Update()
					local camera = workspace.CurrentCamera
					local subjectPosition = self:GetSubjectPosition()
					if camera and subjectPosition then
						camera.Focus = CFrame.new(subjectPosition)
						camera.CFrame = CFrame.new(camera.CFrame.Position, subjectPosition)
					end
				end
				return cam
			end
		end,
		AttachCamera = function(Root)
			return function()
				local cam = Root()
				function cam:Update()
					local camera = workspace.CurrentCamera
					local subject = camera and camera.CameraSubject
					local part = subject and ((subject:IsA("Humanoid") and subject.RootPart) or (subject:IsA("BasePart") and subject))
					local subjectPosition = self:GetSubjectPosition()
					if camera and part and subjectPosition then
						camera.Focus = CFrame.new(subjectPosition)
						camera.CFrame = CFrame.new(subjectPosition - part.CFrame.LookVector * self:GetCameraZoom(), subjectPosition)
					end
				end
				return cam
			end
		end,
	}

	local function moduleNode(name, value)
		return { Name = name, __value = value }
	end
	local function folderNode(children)
		local node = { __children = children }
		function node:WaitForChild(name) return self.__children[name] end
		function node:FindFirstChild(name) return self.__children[name] end
		return node
	end
	local cameraNodes = {}
	for name, builder in pairs(CAMERA_MODULES) do cameraNodes[name] = moduleNode(name, builder) end
	local function fakeRequire(node)
		if type(node) == "table" and node.__value ~= nil then return node.__value end
		return require(node)
	end

	------------------------------------------------------------------------------------------------
	-- RootCameraAndControls, as given (StarterPlayerScripts.RootCameraAndControls)
	------------------------------------------------------------------------------------------------
	local function RootCameraAndControls(script, require, game, shared)
		local v1 = game:GetService("RunService")
		local v2 = game:GetService("UserInputService")
		local v3 = game:GetService("ReplicatedStorage")
		local v4 = shared.UserSettings
		local v5 = v3:GetAttribute("RobloxVersion")
		if v4():IsUserFeatureEnabled("UserUseLuaVehicleController") and v4():IsUserFeatureEnabled("UserAllCameraInLua") then
			task.defer(script.Destroy, script)
		else
			local v6 = script.Parent
			local v7 = v6:WaitForChild("CameraScript")
			local v8 = v6:WaitForChild("ControlScript")
			local v_u_9 = require(v7:WaitForChild("RootCamera"))
			local v10 = require(v8:WaitForChild("MasterControl"))
			local v_u_11 = nil
			local v_u_12 = nil
			local v_u_13 = {
				[Enum.CameraType.Attach] = "AttachCamera",
				[Enum.CameraType.Fixed] = "FixedCamera",
				[Enum.CameraType.Follow] = "FollowCamera",
				[Enum.CameraType.Scriptable] = "ScriptableCamera",
				[Enum.CameraType.Track] = "TrackCamera",
				[Enum.CameraType.Watch] = "WatchCamera"
			}
			local function v14() -- name: Update
				-- upvalues: (ref) v_u_12
				if v_u_12 then
					v_u_12:Update()
				end
			end
			local function v_u_17() -- name: OnCameraTypeChanged
				-- upvalues: (copy) v_u_13, (ref) v_u_12, (copy) v_u_9
				local v15 = v_u_13[workspace.CurrentCamera.CameraType]
				if v_u_12 then
					v_u_12:SetEnabled(false)
					v_u_12 = nil
				end
				if v15 then
					local v16 = script.Cameras:FindFirstChild(v15)
					if v16 then
						v16 = require(v16)(v_u_9)
					end
					if v16 then
						v_u_12 = v16()
						v_u_12:SetEnabled(true)
					end
				end
			end
			local function v19() -- name: CurrentCameraChanged
				-- upvalues: (ref) v_u_11, (copy) v_u_17
				local v18 = workspace.CurrentCamera
				if v_u_11 then
					v_u_11:Disconnect()
					v_u_11 = nil
				end
				if v18 then
					v_u_11 = v18:GetPropertyChangedSignal("CameraType"):Connect(v_u_17)
				end
			end
			if not v4():IsUserFeatureEnabled("UserUseLuaVehicleController") and (v5 >= 206 or not v2.TouchEnabled) then
				require(script.VehicleController)(v10)
			end
			if not v4():IsUserFeatureEnabled("UserAllCameraInLua") then
				local v20 = workspace.CurrentCamera
				if v_u_11 then
					v_u_11:Disconnect()
					v_u_11 = nil
				end
				if v20 then
					v_u_11 = v20:GetPropertyChangedSignal("CameraType"):Connect(v_u_17)
				end
				workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(v19)
				v1:BindToRenderStep("RootCameraTypeSignal", Enum.RenderPriority.Camera.Value + 1, v14)
			end
		end
	end

	local rootScript = {
		Parent = folderNode({
			CameraScript = folderNode({ RootCamera = moduleNode("RootCamera", RootCamera) }),
			-- (vehicles are Roblox's own PlayerModule's here)
			ControlScript = folderNode({ MasterControl = moduleNode("MasterControl", {}) }),
		}),
		Cameras = folderNode(cameraNodes),
		VehicleController = moduleNode("VehicleController", function() end),
		Destroy = function() end,
	}
	local okRoot, rootErr = pcall(RootCameraAndControls, rootScript, fakeRequire, makeGame(nil), { UserSettings = OldClientSettings })
	if not okRoot then warn("[2013 Camera] RootCameraAndControls: " .. tostring(rootErr)) end

	------------------------------------------------------------------------------------------------
	-- HumanoidRotate, as given (StarterCharacterScripts.HumanoidRotate), on each of your characters
	------------------------------------------------------------------------------------------------
	local function HumanoidRotate(script, game)
		local v1 = game:GetService("RunService")
		local v_u_2 = game:GetService("UserInputService")
		local v_u_3 = game:GetService("ReplicatedStorage"):GetAttribute("RobloxVersion")
		local v_u_4 = script.Parent:WaitForChild("Humanoid")
		if v_u_4.RigType == Enum.HumanoidRigType.R15 then
			task.defer(script.Destroy, script)
		else
			local v_u_5 = Instance.new("BodyGyro")
			v_u_5.D = 0
			v_u_5.P = 3800
			v_u_5.Name = "HumanoidRotate"
			v_u_5.Parent = script
			local v_u_6 = {
				[Enum.HumanoidStateType.Dead] = true,
				[Enum.HumanoidStateType.Ragdoll] = true,
				[Enum.HumanoidStateType.Seated] = true,
				[Enum.HumanoidStateType.PlatformStanding] = true,
				[Enum.HumanoidStateType.FallingDown] = true,
				[Enum.HumanoidStateType.Flying] = true,
				[Enum.HumanoidStateType.Climbing] = v_u_3 >= 98
			}
			v_u_4.Seated:Connect(function()
				-- upvalues: (copy) v_u_5
				v_u_5.Parent = script
			end)
			v_u_4.PlatformStanding:Connect(function()
				-- upvalues: (copy) v_u_5
				v_u_5.Parent = script
			end)
			v_u_4:GetPropertyChangedSignal("WalkToPoint"):Connect(function()
				-- upvalues: (copy) v_u_4
				v_u_4:SetAttribute("IsMoveTo", true)
			end)
			v_u_4:GetPropertyChangedSignal("WalkToPart"):Connect(function()
				-- upvalues: (copy) v_u_4
				v_u_4:SetAttribute("IsMoveTo", true)
			end)
			v_u_4:GetPropertyChangedSignal("MoveDirection"):Connect(function()
				-- upvalues: (copy) v_u_4
				if v_u_4:GetAttribute("IsMoveTo") then
					v_u_4:SetAttribute("IsMoveTo", nil)
				end
			end)
			v_u_4.MoveToFinished:Connect(function()
				-- upvalues: (copy) v_u_4
				v_u_4:SetAttribute("IsMoveTo", nil)
			end)
			local v_u_7 = 0
			v1.RenderStepped:Connect(function(p8)
				-- upvalues: (ref) v_u_7, (copy) v_u_4, (copy) v_u_2, (copy) v_u_6, (copy) v_u_3, (copy) v_u_5
				v_u_7 = v_u_7 + p8
				local v9 = v_u_7
				if v_u_7 >= 0.016666666666666666 then
					v_u_7 = v_u_7 % 0.016666666666666666
					local v10 = v_u_4:GetState()
					local v11 = v_u_4.RootPart
					local v12 = v_u_4:GetAttribute("IsMoveTo")
					local v13 = v_u_2.MouseBehavior == Enum.MouseBehavior.LockCenter
					v_u_4.AutoRotate = v12 or v10 == Enum.HumanoidStateType.Climbing
					if v11 and (v_u_4.MoveDirection.Magnitude > 0 or v13) and not (v_u_4.PlatformStand or (v_u_6[v10] or v12)) then
						local v14 = workspace.CurrentCamera.CFrame.LookVector
						local v15 = v14.X
						local v16 = v14.Z
						local v17 = Vector3.new(v15, 0, v16)
						if v13 then
							if v_u_3 >= 206 then
								v_u_5.Parent = script
								v_u_4.AutoRotate = true
								return
							elseif v_u_3 >= 109 then
								v_u_5.Parent = script
								v11.CFrame = CFrame.lookAt(v11.Position, v11.Position + v17)
							else
								v_u_5.MaxTorque = Vector3.new(0, 2000, 0)
								local v18 = v17.Magnitude > 0.1 and CFrame.lookAt(v11.Position, v11.Position + v17) or v_u_5.CFrame
								local v19 = v9 * 60
								local v20 = 1 - math.pow(0.8, v19)
								v_u_5.CFrame = v_u_5.CFrame:Lerp(v18, (math.clamp(v20, 0, 1)))
								v_u_5.Parent = v11
							end
						end
						if not v13 or v13 and v_u_3 > 109 then
							if not v13 then
								v_u_5.MaxTorque = Vector3.new(0, 2000, 0)
								v_u_5.Parent = v11
								v_u_4.AutoRotate = false
							end
							v_u_5.P = (v10 == Enum.HumanoidStateType.Jumping or v10 == Enum.HumanoidStateType.Freefall) and 1000 or 4000
							local v21 = CFrame.lookAt(v11.Position, v11.Position + v_u_4.MoveDirection)
							local v22 = v9 * 60
							local v23 = 1 - math.pow(0.8, v22)
							v_u_5.CFrame = v_u_5.CFrame:Lerp(v21, (math.clamp(v23, 0, 1)))
							return
						end
					else
						v_u_5.Parent = script
					end
				end
			end)
		end
	end

	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer

	local function onCharacter(character)
		task.wait(1) -- (the physics picked with this camera has started by then)
		if not character.Parent or character ~= LocalPlayer.Character then return end
		if _G.__RetroMasterCleanup then return end -- (the Old physics turns you with Rowind's own HumanoidRotate)
		local holder = Instance.new("Folder")
		holder.Name = "HumanoidRotate"
		holder.Parent = character
		local conns = {}
		local function stop()
			for _, c in ipairs(conns) do c:Disconnect() end
			conns = {}
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then pcall(function() humanoid.AutoRotate = true end) end
			pcall(function() holder:Destroy() end)
		end
		local fakeGame = makeGame(function(fn)
			local c = RealRunService.RenderStepped:Connect(function(dt)
				-- (this character is gone, or the Old physics has started: stepped aside)
				if not holder.Parent or not character.Parent or _G.__RetroMasterCleanup then
					stop()
					return
				end
				fn(dt)
			end)
			table.insert(conns, c)
			return c
		end)
		local ok, err = pcall(HumanoidRotate, holder, fakeGame)
		if not ok then warn("[2013 Camera] HumanoidRotate: " .. tostring(err)) stop() end
	end

	if LocalPlayer then
		if LocalPlayer.Character then task.spawn(onCharacter, LocalPlayer.Character) end
		LocalPlayer.CharacterAdded:Connect(onCharacter)
	end
end
