-- (Addtion-Scripts) The "2013 Camera" of the physics / camera setup step (Old physics camera addon.lua loads this
-- file; the Retro camera gist is the fallback). Changed here: FIRST PERSON works like the classic 2012 camera:
--   * zooming in when the camera is 5 studs away or closer goes straight into first person, and zooming out
--     of it goes straight back to 5 studs (mouse wheel, I / O keys, and a pinch on a phone)
--   * in first person the camera sits right in the head, with no smoothing, and the whole character is hidden
--     (hats, face and the tool in your hand too); out of it the character is fully shown (no see-through
--     stage in between). The mouse stays locked in the middle, as before.
-- Everything else (third person, turning, the zoom steps further out) is the Retro camera as it was.
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

	-- (Addtion-Scripts) first person like the 2012 camera
	local FIRST_PERSON_ZOOM = 0.5       -- the zoom first person is kept at (the camera itself sits in the head)
	local LEAVE_FIRST_PERSON_ZOOM = 5   -- zooming out of first person lands here; zooming in from here or closer goes in
	local ENTER_FIRST_PERSON_ZOOM = LEAVE_FIRST_PERSON_ZOOM / (1 + ZOOM_FACTOR) -- a pinch past this goes in (4 studs)

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
		isFirstPerson = self:GetCameraZoom() < 1.5
		self:UpdateMouseBehavior()
		return self:GetCameraZoom()
	end

	function this:ZoomCameraBy(input)
		local zoom = this:GetCameraActualZoom()
		if zoom then
			if isFirstPerson then
				-- (Addtion-Scripts) out of first person: straight back to 5 studs
				zoom = input < 0 and LEAVE_FIRST_PERSON_ZOOM or FIRST_PERSON_ZOOM
			elseif input > 0 then
				if this:GetCameraZoom() <= LEAVE_FIRST_PERSON_ZOOM then
					-- (Addtion-Scripts) 5 studs or closer: straight into first person
					zoom = FIRST_PERSON_ZOOM
				else
					zoom = math.max(ENTER_FIRST_PERSON_ZOOM, zoom / (1 + ZOOM_FACTOR*input))
				end
			elseif input < 0 then
				zoom = math.min(5000, zoom * (1 - ZOOM_FACTOR*input))
			end
			self:ZoomCamera(zoom)
		end
		
		self:PlayTick()
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
						-- (Addtion-Scripts) in and out of first person like the 2012 camera: fingers spread past
						-- 4 studs -> first person; in first person, fingers pinched in by one zoom step -> 5 studs
						local snapTo = nil
						if isFirstPerson then
							if clampedScale <= 1 / (1 + ZOOM_FACTOR) then snapTo = LEAVE_FIRST_PERSON_ZOOM end
						else
							local desired = pinchBeginZoom / clampedScale
							if clampedScale > 1 and desired <= ENTER_FIRST_PERSON_ZOOM then
								snapTo = FIRST_PERSON_ZOOM
							else
								this:ZoomCamera(desired)
								this:PlayTick()
							end
						end
						if snapTo then
							this:ZoomCamera(snapTo)
							this:PlayTick()
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

			if TeleportService:GetTeleportSetting("FollowCamera") then
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

	-- (Addtion-Scripts) the tool in your hand is hidden in first person too, like the 2012 camera
	local function IsValidPartToModify(part)
		return part:IsA('BasePart') or part:IsA('Decal')
	end

	local function TeardownTransparency()
		for child, _ in pairs(CachedParts) do
			if child:IsA("BasePart") or child:IsA("Decal") then
				child.LocalTransparencyModifier = 0
			end
		end
		CachedParts = {}
		TransparencyDirty = true
		LastTransparency = nil

		if DescendantAddedConn then DescendantAddedConn:Disconnect(); DescendantAddedConn = nil end
		if DescendantRemovingConn then DescendantRemovingConn:Disconnect(); DescendantRemovingConn = nil end
		
		for object, conn in pairs(ToolDescendantAddedConns) do conn:Disconnect(); ToolDescendantAddedConns[object] = nil end
		for object, conn in pairs(ToolDescendantRemovingConns) do conn:Disconnect(); ToolDescendantRemovingConns[object] = nil end
	end

	local function SetupTransparency(character)
		TeardownTransparency()
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
						if child.ClassName == "Decal" then
							child.LocalTransparencyModifier = math.floor(transparency)
						else
							child.LocalTransparencyModifier = transparency
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
local function update()
	Main:Update()
	if not Main:IsInFirstPerson() then PopperCam:Update() end -- (Addtion-Scripts) the camera stays in the head
	Opacity:Update()

	-- Remove the default Roblox camera handler so our retro logic takes full priority
	RunService:UnbindFromRenderStep("cameraRenderUpdate")
end

-- Bind our update cycle right before rendering
RunService:BindToRenderStep("RetroCamera", 250, update)

