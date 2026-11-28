--========================================================
-- 2007 CAMERA (Addtion-Scripts)
-- Retro Studio's 2007 camera, its two scripts as they were given, made to run from a script executor:
--   * StarterPlayerScripts.CameraScript: loads its camera modules (RootCamera with AttachCamera, FixedCamera,
--     ScriptableCamera, TrackCamera, WatchCamera, OrbitalCamera, ClassicCamera and FollowCamera; PopperCam;
--     Invisicam) and sets the camera to Follow and keeps it there. An executor has no such modules, so they are
--     written out here. One line changed: ReplicatedStorage.TimePeriod (Retro Studio's own value) is read if the
--     game has it, instead of being waited for forever.
--   * StarterPlayerScripts.Camera: the Retro camera (Main, Popper, Opacity) that does the actual camera work, as in
--     Retro Studio: every frame it takes over from the CameraScript's update ("cameraRenderUpdate"). That is the zoom:
--     the camera glides to the new distance, never closer than 1 stud, and a tick for each step. (Addtion-Scripts: your
--     character is not made see-through on the way in, as in the user's 2007 recording; in first person, closer than
--     2 studs, only your head and what is on it is hidden, so you see your body when you look down.) Changed here: in first person you are not turned
--     to face where you look (that is the 2013 camera's), and it follows behind you while the camera is Follow (the
--     CameraScript keeps it Follow; in Retro Studio a teleport setting says so).
-- This is the original Retro camera, not the 2013 Camera's copy (that one is changed for 2013: its own first-person
-- zoom steps, turning you to face where you look, the tool kept with you).
-- The CameraScript's own camera modules don't take input here (the Retro camera does), so the two never fight.
-- Run alone or from the physics / camera step ("2007 Camera").
--========================================================

local genv = (getgenv and getgenv()) or _G
if genv.BP_Camera2007Running then
	print("[2007 Camera] already running")
	return
end
genv.BP_Camera2007Running = true

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local PlayersService = game:GetService("Players")

-- the Retro camera (Retro Studio's "Camera" script, at the end) does the camera work and takes the input
local RETRO_CAMERA_DRIVES = true
local VRService = game:GetService("VRService")
local GameSettings = UserSettings().GameSettings

local ZERO_VECTOR2 = Vector2.new(0, 0)
local ZERO_VECTOR3 = Vector3.new(0, 0, 0)
local UP_VECTOR = Vector3.new(0, 1, 0)
local XZ_VECTOR = Vector3.new(1, 0, 1)

local function clamp(low, high, num)
	return (num > high and high or num < low and low or num)
end

local function findAngleBetweenXZVectors(vec2, vec1)
	return math.atan2(vec1.X * vec2.Z - vec1.Z * vec2.X, vec1.X * vec2.X + vec1.Z * vec2.Z)
end

local function IsFinite(num)
	return num == num and num ~= 1 / 0 and num ~= -1 / 0
end

local function IsFiniteVector3(vec3)
	return IsFinite(vec3.X) and IsFinite(vec3.Y) and IsFinite(vec3.Z)
end

----------------------------------------------------------------------------------------------------
-- THE CAMERA MODULES (what the CameraScript requires), each a function that builds the module
----------------------------------------------------------------------------------------------------
local MODULES = {}

-- ShiftLockController: no shift lock in 2007
MODULES.ShiftLockController = function()
	return {
		IsShiftLocked = function() return false end,
		SetIsInFirstPerson = function() end,
	}
end

-- RootCamera: everything the cameras share (input, zoom, turning)
MODULES.RootCamera = function(require)
	local ShiftLockController = require("ShiftLockController")

	local MIN_Y = math.rad(-80)
	local MAX_Y = math.rad(80)
	local TOUCH_SENSITIVTY = Vector2.new(math.pi * 2.25, math.pi * 2)
	local MOUSE_SENSITIVITY = Vector2.new(math.pi * 4, math.pi * 1.9)
	local SEAT_OFFSET = Vector3.new(0, 5, 0)
	local HEAD_OFFSET = Vector3.new(0, 1.5, 0)
	local R15_HEAD_OFFSET = Vector3.new(0, 2.0, 0)

	local humanoidCache = {}
	local function findPlayerHumanoid(player)
		local character = player and player.Character
		if character then
			local resultHumanoid = humanoidCache[player]
			if resultHumanoid and resultHumanoid.Parent == character then
				return resultHumanoid
			else
				humanoidCache[player] = nil
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoidCache[player] = humanoid
				end
				return humanoid
			end
		end
	end

	-- (Addtion-Scripts) zooming as the 2013 Camera does: each wheel click, I / O key a quarter of the way in or out,
	-- straight to the new distance (its first person isn't taken: this camera's own stays, under 2 studs)
	local ZOOM_FACTOR = 0.25

	local function CreateCamera()
		local this = {}

		this.ShiftLock = false
		this.Enabled = false
		local isFirstPerson = false
		local isRightMouseDown = false
		local isMiddleMouseDown = false
		this.RotateInput = ZERO_VECTOR2
		this.DefaultZoom = 12.5
		this.lastSubject = nil
		this.lastSubjectPosition = Vector3.new(0, 5, 0)

		function this:GetShiftLock()
			return ShiftLockController:IsShiftLocked()
		end

		function this:GetHumanoid()
			local player = PlayersService.LocalPlayer
			return findPlayerHumanoid(player)
		end

		function this:GetHumanoidRootPart()
			local humanoid = this:GetHumanoid()
			return humanoid and humanoid.RootPart
		end

		function this:GetSubjectPosition()
			local result = nil
			local camera = workspace.CurrentCamera
			local cameraSubject = camera and camera.CameraSubject
			if cameraSubject then
				if cameraSubject:IsA("Humanoid") then
					local root = cameraSubject.RootPart
					if root then
						local subjectCFrame = root.CFrame
						local heightOffset = (cameraSubject.RigType == Enum.HumanoidRigType.R15) and R15_HEAD_OFFSET or HEAD_OFFSET
						result = subjectCFrame.p + subjectCFrame:VectorToWorldSpace(heightOffset + cameraSubject.CameraOffset)
					end
				elseif cameraSubject:IsA("VehicleSeat") then
					result = cameraSubject.CFrame.p + cameraSubject.CFrame:VectorToWorldSpace(SEAT_OFFSET)
				elseif cameraSubject:IsA("SkateboardPlatform") then
					result = cameraSubject.CFrame.p + SEAT_OFFSET
				elseif cameraSubject:IsA("BasePart") then
					result = cameraSubject.CFrame.p
				elseif cameraSubject:IsA("Model") then
					result = cameraSubject:GetPivot().p
				end
			end
			this.lastSubject = cameraSubject
			this.lastSubjectPosition = result
			return result
		end

		function this:ResetCameraLook()
		end

		function this:GetCameraLook()
			return workspace.CurrentCamera and workspace.CurrentCamera.CFrame.LookVector or Vector3.new(0, 0, 1)
		end

		function this:GetCameraZoom()
			if this.currentZoom == nil then
				local player = PlayersService.LocalPlayer
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

		function this:GetCameraHeight()
			return 0
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
			local xTheta = (translationVector.X / screenX)
			local yTheta = (translationVector.Y / screenY)
			return Vector2.new(xTheta, yTheta)
		end

		function this:MouseTranslationToAngle(translationVector)
			local xTheta = (translationVector.X / 1920)
			local yTheta = (translationVector.Y / 1200)
			return Vector2.new(xTheta, yTheta)
		end

		function this:RotateVector(startVector, xyRotateVector)
			local startCFrame = CFrame.new(ZERO_VECTOR3, startVector)
			local resultLookVector = (CFrame.Angles(0, -xyRotateVector.X, 0) * startCFrame * CFrame.Angles(-xyRotateVector.Y, 0, 0)).LookVector
			return resultLookVector, Vector2.new(xyRotateVector.X, xyRotateVector.Y)
		end

		function this:RotateCamera(startLook, xyRotateVector)
			local startVertical = math.asin(startLook.Y)
			local yTheta = clamp(-MAX_Y + startVertical, -MIN_Y + startVertical, xyRotateVector.Y)
			return self:RotateVector(startLook, Vector2.new(xyRotateVector.X, yTheta))
		end

		function this:IsInFirstPerson()
			return isFirstPerson
		end

		function this:UpdateMouseBehavior()
			if RETRO_CAMERA_DRIVES then return end -- (the Retro camera below sets the mouse)
			if isFirstPerson or self:GetShiftLock() then
				pcall(function() GameSettings.RotationType = Enum.RotationType.CameraRelative end)
				if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
					UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
				end
			else
				pcall(function() GameSettings.RotationType = Enum.RotationType.MovementRelative end)
				if isRightMouseDown or isMiddleMouseDown then
					UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
				else
					UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				end
			end
		end

		function this:ZoomCamera(desiredZoom)
			local player = PlayersService.LocalPlayer
			if player then
				if player.CameraMode == Enum.CameraMode.LockFirstPerson then
					this.currentZoom = 0
				else
					this.currentZoom = clamp(player.CameraMinZoomDistance, player.CameraMaxZoomDistance, desiredZoom)
				end
			end
			isFirstPerson = self:GetCameraZoom() < 2
			ShiftLockController:SetIsInFirstPerson(isFirstPerson)
			self:UpdateMouseBehavior()
			return self:GetCameraZoom()
		end

		-- input > 0: in, < 0: out (one step each)
		function this:ZoomCameraBy(input)
			local zoom = this:GetCameraActualZoom()
			if zoom then
				if input > 0 then
					zoom = zoom / (1 + ZOOM_FACTOR * input)
				elseif input < 0 then
					zoom = zoom * (1 - ZOOM_FACTOR * input)
				end
				self:ZoomCamera(zoom)
			end
			return self:GetCameraZoom()
		end

		function this:ZoomCameraFixedBy(zoomIncrement)
			return self:ZoomCamera(self:GetCameraZoom() + zoomIncrement)
		end

		function this:Update()
		end

		function this:UpdateGamepad()
			return ZERO_VECTOR2
		end

		-- input
		local startPos = nil
		local lastPos = nil
		local panBeginLook = nil
		local fingerTouches = {}
		local NumUnsunkTouches = 0
		local StartingDiff = nil
		local pinchBeginZoom = nil

		this.ZoomEnabled = true
		this.PanEnabled = true
		this.KeyPanEnabled = true

		local function OnTouchBegan(input, processed)
			fingerTouches[input] = processed
			if not processed then
				NumUnsunkTouches = NumUnsunkTouches + 1
			end
		end

		local function OnTouchChanged(input, processed)
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
					local difference = (unsunkTouches[1].Position - unsunkTouches[2].Position).Magnitude
					if StartingDiff and pinchBeginZoom then
						local scale = difference / math.max(0.01, StartingDiff)
						local clampedScale = clamp(0.1, 10, scale)
						if this.ZoomEnabled then
							this:ZoomCamera(pinchBeginZoom / clampedScale)
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
					this.UserPanningTheCamera = false
				elseif NumUnsunkTouches == 2 then
					StartingDiff = nil
					pinchBeginZoom = nil
				end
			end
			if fingerTouches[input] ~= nil and fingerTouches[input] == false then
				NumUnsunkTouches = NumUnsunkTouches - 1
			end
			fingerTouches[input] = nil
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
			elseif this:IsInFirstPerson() or this:GetShiftLock() then
				if this.PanEnabled then
					local desiredXYVector = this:MouseTranslationToAngle(inputDelta) * MOUSE_SENSITIVITY
					this.RotateInput = this.RotateInput + desiredXYVector
				end
			end
		end

		local function OnMouseWheel(input, processed)
			if not processed and this.ZoomEnabled then
				this:ZoomCameraBy(clamp(-1, 1, input.Position.Z))
			end
		end

		local eight2Pi = math.pi / 4
		local function rotateVectorByAngleAndRound(camLook, rotateAngle, roundAmount)
			if camLook ~= ZERO_VECTOR3 then
				camLook = camLook.Unit
				local currAngle = math.atan2(camLook.Z, camLook.X)
				local newAngle = math.floor(((currAngle + rotateAngle) / roundAmount) + 0.5) * roundAmount
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
					local angle = rotateVectorByAngleAndRound(this:GetCameraLook() * XZ_VECTOR, -eight2Pi * (3 / 4), eight2Pi)
					if angle ~= 0 then
						this.RotateInput = this.RotateInput + Vector2.new(angle, 0)
						this.LastUserPanCamera = tick()
						this.LastCameraTransform = nil
					end
				elseif input.KeyCode == Enum.KeyCode.Period then
					local angle = rotateVectorByAngleAndRound(this:GetCameraLook() * XZ_VECTOR, eight2Pi * (3 / 4), eight2Pi)
					if angle ~= 0 then
						this.RotateInput = this.RotateInput + Vector2.new(angle, 0)
						this.LastUserPanCamera = tick()
						this.LastCameraTransform = nil
					end
				elseif input.KeyCode == Enum.KeyCode.PageUp then
					this.RotateInput = this.RotateInput + Vector2.new(0, math.rad(15))
					this.LastCameraTransform = nil
				elseif input.KeyCode == Enum.KeyCode.PageDown then
					this.RotateInput = this.RotateInput + Vector2.new(0, math.rad(-15))
					this.LastCameraTransform = nil
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

		local inputConns = {}

		function this:ConnectInputEvents()
			if RETRO_CAMERA_DRIVES then return end -- (the Retro camera below takes the input)
			this.RotateInput = ZERO_VECTOR2
			table.insert(inputConns, UserInputService.InputBegan:Connect(function(input, processed)
				if input.UserInputType == Enum.UserInputType.Touch then
					OnTouchBegan(input, processed)
				elseif input.UserInputType == Enum.UserInputType.MouseButton2 and not processed then
					isRightMouseDown = true
					OnMousePanButtonPressed(input, processed)
				elseif input.UserInputType == Enum.UserInputType.MouseButton3 and not processed then
					isMiddleMouseDown = true
					OnMousePanButtonPressed(input, processed)
				elseif input.UserInputType == Enum.UserInputType.Keyboard then
					OnKeyDown(input, processed)
				end
			end))
			table.insert(inputConns, UserInputService.InputChanged:Connect(function(input, processed)
				if input.UserInputType == Enum.UserInputType.Touch then
					OnTouchChanged(input, processed)
				elseif input.UserInputType == Enum.UserInputType.MouseMovement then
					OnMouseMoved(input, processed)
				elseif input.UserInputType == Enum.UserInputType.MouseWheel then
					OnMouseWheel(input, processed)
				end
			end))
			table.insert(inputConns, UserInputService.InputEnded:Connect(function(input, processed)
				if input.UserInputType == Enum.UserInputType.Touch then
					OnTouchEnded(input, processed)
				elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
					isRightMouseDown = false
					OnMousePanButtonReleased(input, processed)
				elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
					isMiddleMouseDown = false
					OnMousePanButtonReleased(input, processed)
				elseif input.UserInputType == Enum.UserInputType.Keyboard then
					OnKeyUp(input, processed)
				end
			end))
			this:ZoomCamera(this:GetCameraZoom())
		end

		function this:DisconnectInputEvents()
			for _, c in ipairs(inputConns) do c:Disconnect() end
			inputConns = {}
			this.TurningLeft = false
			this.TurningRight = false
			this.LastCameraTransform = nil
			this.UserPanningTheCamera = false
			this.RotateInput = ZERO_VECTOR2
			panBeginLook = nil
			startPos = nil
			lastPos = nil
			fingerTouches = {}
			NumUnsunkTouches = 0
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

		return this
	end

	return CreateCamera
end

-- (Addtion-Scripts) While the 2006 physics is running the camera stays where you put it, as in 2006: the Follow camera turning
-- itself behind you as you walk, together with the 2006 physics' own turning, swung the camera and the body left and
-- right as you walked ("turn and it goes back", the user's video: walking with the 2006 physics and this camera).
-- The 2006 physics keeps a hook in getgenv() while it runs.
local function physics2006On()
	return type(genv.__Physics2006Cleanup) == "function"
end

-- ClassicCamera / FollowCamera: the same Update, the Follow one turning behind you as you walk
local function MakeOrbitingCamera(require, follow)
	local RootCamera = require("RootCamera")

	return function()
		local module = RootCamera()

		local tweenAcceleration = math.rad(220)
		local tweenSpeed = math.rad(0)
		local tweenMaxSpeed = math.rad(250)
		local timeBeforeAutoRotate = 2

		local lastUpdate = tick()
		module.LastUserPanCamera = tick()

		function module:Update()
			local now = tick()
			local timeDelta = (now - lastUpdate)

			local userPanningTheCamera = (self.UserPanningTheCamera == true)
			local camera = workspace.CurrentCamera
			local player = PlayersService.LocalPlayer
			local humanoid = self:GetHumanoid()
			local cameraSubject = camera and camera.CameraSubject
			local isInVehicle = cameraSubject and cameraSubject:IsA("VehicleSeat")
			local isOnASkateboard = cameraSubject and cameraSubject:IsA("SkateboardPlatform")

			if lastUpdate == nil or now - lastUpdate > 1 then
				module:ResetCameraLook()
				self.LastCameraTransform = nil
			end

			if lastUpdate then
				local gamepadRotation = self:UpdateGamepad()
				local delta = math.min(0.1, now - lastUpdate)
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
					self.RotateInput = self.RotateInput + Vector2.new(math.rad(angle * delta), 0)
					userPanningTheCamera = true
				end
			end

			-- Reset tween speed if user is panning
			if userPanningTheCamera then
				tweenSpeed = 0
				module.LastUserPanCamera = tick()
			end

			local userRecentlyPannedCamera = now - module.LastUserPanCamera < timeBeforeAutoRotate
			local subjectPosition = self:GetSubjectPosition()

			if subjectPosition and player and camera then
				local zoom = self:GetCameraZoom()
				if zoom < 0.5 then
					zoom = 0.5
				end

				if self:GetShiftLock() and not self:IsInFirstPerson() then
					local newLookVector = self:RotateCamera(self:GetCameraLook(), self.RotateInput)
					local offset = ((newLookVector * XZ_VECTOR):Cross(UP_VECTOR).Unit * 1.75)
					if IsFiniteVector3(offset) then
						subjectPosition = subjectPosition + offset
					end
				else
					if self.LastCameraTransform and not userPanningTheCamera then
						local isInFirstPerson = self:IsInFirstPerson()
						if (isInVehicle or isOnASkateboard) and lastUpdate and humanoid and humanoid.RootPart then
							if isInFirstPerson then
								if self.LastSubjectCFrame and cameraSubject:IsA("BasePart") then
									local y = -findAngleBetweenXZVectors(self.LastSubjectCFrame.LookVector, cameraSubject.CFrame.LookVector)
									if IsFinite(y) then
										self.RotateInput = self.RotateInput + Vector2.new(y, 0)
									end
									tweenSpeed = 0
								end
							elseif not userRecentlyPannedCamera then
								local forwardVector = humanoid.RootPart.CFrame.LookVector
								if isOnASkateboard then
									forwardVector = cameraSubject.CFrame.LookVector
								end
								tweenSpeed = clamp(0, tweenMaxSpeed, tweenSpeed + tweenAcceleration * timeDelta)
								local percent = clamp(0, 1, tweenSpeed * timeDelta)
								if not isInVehicle and isInFirstPerson then
									percent = 1
								end
								local y = findAngleBetweenXZVectors(forwardVector, self:GetCameraLook())
								if IsFinite(y) and math.abs(y) > 0.0001 then
									self.RotateInput = self.RotateInput + Vector2.new(y * percent, 0)
								end
							end
						elseif follow and not (isInFirstPerson or userRecentlyPannedCamera or physics2006On()) then
							-- (FollowCamera) turn towards where the character went; a dead zone keeps small steps from
							-- swinging the camera
							local lastVec = -(self.LastCameraTransform.p - subjectPosition)
							local y = findAngleBetweenXZVectors(lastVec, self:GetCameraLook())
							local thetaCutoff = 0.4
							if IsFinite(y) and math.abs(y) > 0.0001 and math.abs(y) > thetaCutoff * timeDelta then
								self.RotateInput = self.RotateInput + Vector2.new(y, 0)
							end
						end
					end
				end

				local newLookVector = self:RotateCamera(self:GetCameraLook(), self.RotateInput)
				self.RotateInput = ZERO_VECTOR2

				camera.Focus = CFrame.new(subjectPosition)
				camera.CFrame = CFrame.new(camera.Focus.p - (zoom * newLookVector), camera.Focus.p) + Vector3.new(0, self:GetCameraHeight(), 0)
				self.LastCameraTransform = camera.CFrame
				if (isInVehicle or isOnASkateboard) and cameraSubject:IsA("BasePart") then
					self.LastSubjectCFrame = cameraSubject.CFrame
				else
					self.LastSubjectCFrame = nil
				end
			end

			lastUpdate = now
		end

		return module
	end
end

MODULES.ClassicCamera = function(require) return MakeOrbitingCamera(require, false) end
MODULES.FollowCamera = function(require) return MakeOrbitingCamera(require, true) end
MODULES.TrackCamera = function(require) return MakeOrbitingCamera(require, false) end
MODULES.OrbitalCamera = function(require) return MakeOrbitingCamera(require, false) end

-- the camera types a game sets itself (the CameraScript keeps Follow on, so these are rarely used)
MODULES.ScriptableCamera = function(require)
	local RootCamera = require("RootCamera")
	return function()
		local module = RootCamera()
		function module:Update() end
		return module
	end
end
MODULES.FixedCamera = MODULES.ScriptableCamera
MODULES.WatchCamera = function(require)
	local RootCamera = require("RootCamera")
	return function()
		local module = RootCamera()
		function module:Update()
			local camera = workspace.CurrentCamera
			local subjectPosition = self:GetSubjectPosition()
			if camera and subjectPosition then
				camera.Focus = CFrame.new(subjectPosition)
				camera.CFrame = CFrame.new(camera.CFrame.p, subjectPosition)
			end
		end
		return module
	end
end
MODULES.AttachCamera = function(require)
	local RootCamera = require("RootCamera")
	return function()
		local module = RootCamera()
		function module:Update()
			local camera = workspace.CurrentCamera
			local subject = camera and camera.CameraSubject
			local subjectPosition = self:GetSubjectPosition()
			local part = subject and (subject:IsA("Humanoid") and subject.RootPart or (subject:IsA("BasePart") and subject))
			if camera and subjectPosition and part then
				local look = part.CFrame.LookVector
				camera.Focus = CFrame.new(subjectPosition)
				camera.CFrame = CFrame.new(subjectPosition - look * self:GetCameraZoom(), subjectPosition)
			end
		end
		return module
	end
end

-- PopperCam: the camera pops in front of whatever is between it and you, and eases back out
MODULES.PopperCam = function()
	local POP_RESTORE_RATE = 0.3
	local VALID_SUBJECTS = { "Humanoid", "VehicleSeat", "SkateboardPlatform" }

	local Camera = nil
	local CameraChangeConn = nil
	local PlayerCharacters = {}
	local VehicleParts = {}
	local LastPopAmount = 0
	local LastZoomLevel = 0
	local PopperEnabled = false

	local function OnCharacterAdded(player, character)
		PlayerCharacters[player] = character
	end

	local function OnPlayersChildAdded(child)
		if child:IsA("Player") then
			child.CharacterAdded:Connect(function(character)
				OnCharacterAdded(child, character)
			end)
			if child.Character then
				OnCharacterAdded(child, child.Character)
			end
		end
	end

	local function OnPlayersChildRemoved(child)
		if child:IsA("Player") then
			PlayerCharacters[child] = nil
		end
	end

	local function OnCameraChanged(property)
		if property == "CameraSubject" then
			VehicleParts = {}
			local newSubject = Camera.CameraSubject
			if newSubject then
				PopperEnabled = false
				for _, subjectType in pairs(VALID_SUBJECTS) do
					if newSubject:IsA(subjectType) then
						PopperEnabled = true
						break
					end
				end
				if newSubject:IsA("VehicleSeat") then
					VehicleParts = newSubject:GetConnectedParts(true)
				end
			end
		end
	end

	local function OnWorkspaceChanged(property)
		if property == "CurrentCamera" then
			local newCamera = workspace.CurrentCamera
			if newCamera then
				Camera = newCamera
				if CameraChangeConn then
					CameraChangeConn:Disconnect()
				end
				CameraChangeConn = Camera.Changed:Connect(OnCameraChanged)
				OnCameraChanged("CameraSubject")
			end
		end
	end

	local PopperCam = {}

	function PopperCam:Update()
		if PopperEnabled and Camera then
			local cameraCFrame = Camera.CFrame
			local focusPoint = Camera.Focus.p

			local ignoreList = {}
			for _, character in pairs(PlayerCharacters) do
				ignoreList[#ignoreList + 1] = character
			end
			for i = 1, #VehicleParts do
				ignoreList[#ignoreList + 1] = VehicleParts[i]
			end

			local largest = 0
			pcall(function() largest = Camera:GetLargestCutoffDistance(ignoreList) end)

			local zoomLevel = (cameraCFrame.p - focusPoint).Magnitude
			if math.abs(zoomLevel - LastZoomLevel) > 0.001 then
				LastPopAmount = 0
			end

			local popAmount = largest
			if LastPopAmount > popAmount then
				popAmount = LastPopAmount
			end

			if popAmount > 0 then
				Camera.CFrame = cameraCFrame + (cameraCFrame.LookVector * popAmount)
				LastPopAmount = popAmount - POP_RESTORE_RATE
				if LastPopAmount < 0 then
					LastPopAmount = 0
				end
			end

			LastZoomLevel = zoomLevel
		end
	end

	workspace.Changed:Connect(OnWorkspaceChanged)
	OnWorkspaceChanged("CurrentCamera")
	PlayersService.ChildAdded:Connect(OnPlayersChildAdded)
	PlayersService.ChildRemoved:Connect(OnPlayersChildRemoved)
	for _, player in pairs(PlayersService:GetPlayers()) do
		OnPlayersChildAdded(player)
	end

	return PopperCam
end

-- Invisicam (only for a game that asks for it): in this copy the camera pops in front of walls instead
MODULES.Invisicam = function(require)
	local PopperCam = require("PopperCam")
	return {
		Update = function(_, ...) return PopperCam:Update(...) end,
		Cleanup = function() end,
	}
end

-- TransparencyController (2016): in first person the character is hidden, the tool in your hand isn't
MODULES.TransparencyController = function()
	local MAX_TWEEN_RATE = 2.8
	local controller = { cached = {}, character = nil, last = nil, lastUpdate = tick() }

	local function valid(part)
		if part:FindFirstAncestorOfClass("Tool") then return false end
		return part:IsA("BasePart") or part:IsA("Decal")
	end

	local conns = {}
	function controller:SetSubject(subject)
		for _, c in ipairs(conns) do c:Disconnect() end
		conns = {}
		for part in pairs(self.cached) do pcall(function() part.LocalTransparencyModifier = 0 end) end
		self.cached = {}
		self.last = nil
		local character = subject and subject:IsA("Humanoid") and subject.Parent or nil
		self.character = character
		if not character then return end
		for _, d in ipairs(character:GetDescendants()) do
			if valid(d) then self.cached[d] = true end
		end
		table.insert(conns, character.DescendantAdded:Connect(function(d)
			if valid(d) then self.cached[d] = true self.last = nil end
		end))
		table.insert(conns, character.DescendantRemoving:Connect(function(d)
			if self.cached[d] then self.cached[d] = nil pcall(function() d.LocalTransparencyModifier = 0 end) end
		end))
	end

	function controller:Update()
		local camera = workspace.CurrentCamera
		if not camera or not self.character then return end
		local now = tick()
		local distance = (camera.Focus.p - camera.CFrame.p).Magnitude
		-- (Addtion-Scripts) the body is gone well before the camera is in the head: from 4 studs it fades, and by 2.2 it is invisible, so
		-- the big yellow head no longer fills the screen on the way into first person (the user's recording)
		local transparency = (distance < 4) and ((4 - distance) / 1.8) or 0
		if transparency < 0.05 then transparency = 0 end
		if self.last and transparency < 1 and self.last < 0.95 then
			local maxDelta = MAX_TWEEN_RATE * (now - self.lastUpdate)
			transparency = self.last + clamp(-maxDelta, maxDelta, transparency - self.last)
		end
		transparency = clamp(0, 1, math.floor(transparency * 100 + 0.5) / 100)
		if transparency ~= self.last then
			for part in pairs(self.cached) do
				if part:FindFirstAncestorOfClass("Tool") then
					part.LocalTransparencyModifier = 0
				elseif part:IsA("Decal") then
					part.LocalTransparencyModifier = math.floor(transparency)
				else
					part.LocalTransparencyModifier = transparency
				end
			end
			self.last = transparency
		end
		self.lastUpdate = now
	end

	return controller
end

----------------------------------------------------------------------------------------------------
-- where the CameraScript finds its modules: script.RootCamera.<Camera>, script.PopperCam, script.Invisicam
----------------------------------------------------------------------------------------------------
local loaded = {}
local function requireModule(name)
	if loaded[name] == nil then
		loaded[name] = MODULES[name](requireModule)
	end
	return loaded[name]
end

local function moduleNode(name, children)
	local node = { Name = name, ClassName = children and "Folder" or "ModuleScript", __module = (not children) and name or nil, __children = children or {} }
	function node:WaitForChild(childName)
		local child = self.__children[childName]
		if not child then error(childName .. " is not one of the 2007 camera's modules", 2) end
		return child
	end
	node.FindFirstChild = function(self, childName) return self.__children[childName] end
	return node
end

local cameraTypes = {}
for _, name in ipairs({ "AttachCamera", "FixedCamera", "ScriptableCamera", "TrackCamera", "WatchCamera", "OrbitalCamera", "ClassicCamera", "FollowCamera" }) do
	cameraTypes[name] = moduleNode(name)
end
local FakeScript = moduleNode("CameraScript", {
	RootCamera = moduleNode("RootCamera", cameraTypes),
	PopperCam = moduleNode("PopperCam"),
	Invisicam = moduleNode("Invisicam"),
})

local realRequire = require
local function FakeRequire(target)
	if type(target) == "table" and target.__module then
		return requireModule(target.__module)
	end
	return realRequire(target)
end

----------------------------------------------------------------------------------------------------
-- Roblox's own camera steps aside (its update is unbound; the CameraScript binds its own under the same name),
-- and the 2013 Camera, if it was running
----------------------------------------------------------------------------------------------------
pcall(function() RunService:UnbindFromRenderStep("cameraRenderUpdate") end)
if _G.RetroCameraHooks then
	pcall(function() RunService:UnbindFromRenderStep("RetroCamera") end)
	pcall(function() if _G.RetroCamMain then _G.RetroCamMain:DisconnectInputEvents() end end)
	_G.RetroCameraHooks = nil
end

----------------------------------------------------------------------------------------------------
-- THE CAMERASCRIPT, as given (Retro Studio, StarterPlayerScripts.CameraScript; the other CameraScript there only
-- destroys itself)
----------------------------------------------------------------------------------------------------
local function CameraScript(script, require)
	local v_u_1 = game:GetService("RunService")
	local v2 = game:GetService("ReplicatedStorage")
	local v_u_3 = game:GetService("UserInputService")
	local v_u_4 = game:GetService("Players")
	local v_u_5 = game:GetService("VRService")
	game:GetService("StarterPlayer")
	local v6 = script:WaitForChild("RootCamera")
	local v7 = require(v6:WaitForChild("AttachCamera"))()
	local v8 = require(v6:WaitForChild("FixedCamera"))()
	local v9 = require(v6:WaitForChild("ScriptableCamera"))()
	local v10 = require(v6:WaitForChild("TrackCamera"))()
	local v11 = require(v6:WaitForChild("WatchCamera"))()
	local v_u_12 = require(v6:WaitForChild("OrbitalCamera"))()
	local v_u_13 = require(v6:WaitForChild("ClassicCamera"))()
	local v_u_14 = require(v6:WaitForChild("FollowCamera"))()
	local v_u_15 = require(script:WaitForChild("PopperCam"))
	local v_u_16 = require(script:WaitForChild("Invisicam"))
	-- (Addtion-Scripts: the one changed line. It was "local _ = v2:WaitForChild("TimePeriod").Value": Retro Studio's own
	-- value, which other games don't have, so it waited forever.)
	local _ = v2:FindFirstChild("TimePeriod") and v2.TimePeriod.Value
	local v_u_17 = UserSettings().GameSettings
	local v_u_18 = false
	local function v19()
	    -- upvalues: (ref) v_u_18
	    v_u_18 = true
	end
	local v20, v21 = pcall(v19)
	if not v20 then
	    print("Couldn\'t get feature UserAllCamerasInLua because:", v21)
	end
	local v22, v23 = pcall(function()
	    return UserSettings():IsUserFeatureEnabled("UserNoCameraClickToMove")
	end)
	local v_u_24 = v22 and v23
	local v_u_25 = pcall(function()
	    local _ = Enum.CameraType.Orbital
	end)
	local v_u_26 = v_u_4.LocalPlayer:WaitForChild("PlayerScripts")
	if pcall(function()
	    -- upvalues: (copy) v_u_26
	    v_u_26:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Default)
	end) then
	    v_u_26:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Follow)
	    v_u_26:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Classic)
	    v_u_26:RegisterComputerCameraMovementMode(Enum.ComputerCameraMovementMode.Default)
	    v_u_26:RegisterComputerCameraMovementMode(Enum.ComputerCameraMovementMode.Follow)
	    v_u_26:RegisterComputerCameraMovementMode(Enum.ComputerCameraMovementMode.Classic)
	end
	local v_u_27 = {
	    [Enum.CameraType.Attach] = v7,
	    [Enum.CameraType.Fixed] = v8,
	    [Enum.CameraType.Scriptable] = v9,
	    [Enum.CameraType.Track] = v10,
	    [Enum.CameraType.Watch] = v11,
	    [Enum.CameraType.Follow] = v_u_14
	}
	if v_u_25 then
	    v_u_27[Enum.CameraType.Orbital] = v_u_12
	end
	local v_u_28 = nil
	local v_u_29 = nil
	local v_u_30 = nil
	local v_u_31 = nil
	local v_u_32 = nil
	local v_u_33 = false
	local function v_u_38() -- name: isClickToMoveOn
	    -- upvalues: (copy) v_u_4, (ref) v_u_18, (copy) v_u_25, (ref) v_u_33, (ref) v_u_32, (copy) v_u_3, (copy) v_u_17
	    local v34 = v_u_4.LocalPlayer
	    local v35 = workspace.CurrentCamera
	    local v36 = v_u_18 and true or (v34 and (v35 == nil or (v35.CameraType == Enum.CameraType.Custom or v_u_25 and v35.CameraType == Enum.CameraType.Orbital)) and true or false)
	    local v37 = v_u_4.LocalPlayer
	    if v36 and v37 then
	        if v_u_33 and v_u_32 == Enum.UserInputType.Touch or v_u_3.TouchEnabled then
	            if v37.DevTouchMovementMode == Enum.DevTouchMovementMode.ClickToMove or v37.DevTouchMovementMode == Enum.DevTouchMovementMode.UserChoice and v_u_17.TouchMovementMode == Enum.TouchMovementMode.ClickToMove then
	                return true
	            end
	        elseif v37.DevComputerMovementMode == Enum.DevComputerMovementMode.ClickToMove or v37.DevComputerMovementMode == Enum.DevComputerMovementMode.UserChoice and v_u_17.ComputerMovementMode == Enum.ComputerMovementMode.ClickToMove then
	            return true
	        end
	    end
	    return false
	end
	local function v_u_45() -- name: getCurrentCameraMode
	    -- upvalues: (copy) v_u_4, (ref) v_u_18, (copy) v_u_25, (ref) v_u_33, (ref) v_u_32, (copy) v_u_3, (copy) v_u_24, (copy) v_u_38, (copy) v_u_17
	    local v39 = v_u_4.LocalPlayer
	    local v40 = workspace.CurrentCamera
	    local v41 = v_u_18 and true or (v39 and (v40 == nil or (v40.CameraType == Enum.CameraType.Custom or v_u_25 and v40.CameraType == Enum.CameraType.Orbital)) and true or false)
	    local v42 = v_u_4.LocalPlayer
	    if v41 and v42 then
	        if v_u_33 and v_u_32 == Enum.UserInputType.Touch or v_u_3.TouchEnabled then
	            if v_u_24 or not v_u_38() then
	                if v42.DevTouchCameraMode == Enum.DevTouchCameraMovementMode.UserChoice then
	                    local v43 = v_u_17.TouchCameraMovementMode
	                    if v43 == Enum.TouchCameraMovementMode.Default then
	                        return Enum.TouchCameraMovementMode.Follow.Name
	                    else
	                        return v43.Name
	                    end
	                else
	                    return v42.DevTouchCameraMode.Name
	                end
	            else
	                return Enum.DevTouchMovementMode.ClickToMove.Name
	            end
	        elseif v_u_24 or not v_u_38() then
	            if v42.DevComputerCameraMode == Enum.DevComputerCameraMovementMode.UserChoice then
	                local v44 = v_u_17.ComputerCameraMovementMode
	                if v44 == Enum.ComputerCameraMovementMode.Default then
	                    return Enum.ComputerCameraMovementMode.Classic.Name
	                else
	                    return v44.Name
	                end
	            else
	                return v42.DevComputerCameraMode.Name
	            end
	        else
	            return Enum.DevComputerMovementMode.ClickToMove.Name
	        end
	    else
	        return
	    end
	end
	local function v_u_48() -- name: Update
	    -- upvalues: (ref) v_u_28, (ref) v_u_29, (copy) v_u_5, (copy) v_u_4, (ref) v_u_18, (copy) v_u_25
	    if v_u_28 then
	        v_u_28:Update()
	    end
	    if v_u_29 and not v_u_5.VREnabled then
	        v_u_29:Update(v_u_28)
	    end
	    local v46 = v_u_4.LocalPlayer
	    local v47 = workspace.CurrentCamera
	    local _ = v_u_18 and true or (v46 and (v47 == nil or (v47.CameraType == Enum.CameraType.Custom or v_u_25 and v47.CameraType == Enum.CameraType.Orbital)) and true or false)
	end
	local function v_u_61(p49) -- name: OnCameraMovementModeChange
	    -- upvalues: (copy) v_u_24, (ref) v_u_28, (copy) v_u_5, (ref) v_u_18, (copy) v_u_13, (copy) v_u_14, (copy) v_u_25, (copy) v_u_12, (copy) v_u_27, (copy) v_u_4, (ref) v_u_29, (copy) v_u_16, (copy) v_u_15
	    if p49 == Enum.DevComputerMovementMode.ClickToMove.Name then
	        if v_u_24 then
	            return
	        end
	        if v_u_28 ~= nil then
	            if v_u_28 then
	                v_u_28:SetEnabled(false)
	            end
	            v_u_28 = nil
	            if v_u_28 then
	                v_u_28:SetEnabled(true)
	            end
	        end
	    else
	        local v50 = workspace.CurrentCamera
	        if v50 then
	            v50 = workspace.CurrentCamera.CameraType
	        end
	        if not v_u_5.VREnabled or v50 == Enum.CameraType.Scriptable then
	            if (v50 == Enum.CameraType.Custom or not v_u_18) and p49 == Enum.ComputerCameraMovementMode.Classic.Name then
	                local v51 = v_u_13
	                if v_u_28 ~= v51 then
	                    if v_u_28 then
	                        v_u_28:SetEnabled(false)
	                    end
	                    v_u_28 = v51
	                    if v_u_28 then
	                        v_u_28:SetEnabled(true)
	                    end
	                end
	            elseif (v50 == Enum.CameraType.Custom or not v_u_18) and p49 == Enum.ComputerCameraMovementMode.Follow.Name then
	                local v52 = v_u_14
	                if v_u_28 ~= v52 then
	                    if v_u_28 then
	                        v_u_28:SetEnabled(false)
	                    end
	                    v_u_28 = v52
	                    if v_u_28 then
	                        v_u_28:SetEnabled(true)
	                    end
	                end
	            elseif (v50 == Enum.CameraType.Custom or not v_u_18) and (v_u_25 and p49 == Enum.ComputerCameraMovementMode.Orbital.Name) then
	                local v53 = v_u_12
	                if v_u_28 ~= v53 then
	                    if v_u_28 then
	                        v_u_28:SetEnabled(false)
	                    end
	                    v_u_28 = v53
	                    if v_u_28 then
	                        v_u_28:SetEnabled(true)
	                    end
	                end
	            elseif v_u_18 and v_u_27[v50] then
	                local v54 = v_u_27[v50]
	                if v_u_28 ~= v54 then
	                    if v_u_28 then
	                        v_u_28:SetEnabled(false)
	                    end
	                    v_u_28 = v54
	                    if v_u_28 then
	                        v_u_28:SetEnabled(true)
	                    end
	                end
	            elseif v_u_28 ~= nil then
	                if v_u_28 then
	                    v_u_28:SetEnabled(false)
	                end
	                v_u_28 = nil
	                if v_u_28 then
	                    v_u_28:SetEnabled(true)
	                end
	            end
	        end
	    end
	    local v55 = v_u_4.LocalPlayer and (workspace.CurrentCamera and workspace.CurrentCamera.CameraType == Enum.CameraType.Custom) and true or false
	    local v56 = v_u_4.LocalPlayer
	    local v57 = workspace.CurrentCamera
	    local v58 = v_u_18 and true or (v56 and (v57 == nil or (v57.CameraType == Enum.CameraType.Custom or v_u_25 and v57.CameraType == Enum.CameraType.Orbital)) and true or false)
	    local v59 = v_u_4.LocalPlayer
	    local v60
	    if v58 and v59 then
	        v60 = v59.DevCameraOcclusionMode
	    else
	        v60 = nil
	    end
	    if v_u_29 == v_u_16 and (v60 ~= Enum.DevCameraOcclusionMode.Invisicam or not v55) then
	        v_u_16:Cleanup()
	    end
	    if v55 then
	        if v60 == Enum.DevCameraOcclusionMode.Zoom and (v_u_25 and p49 ~= Enum.ComputerCameraMovementMode.Orbital.Name) then
	            v_u_29 = v_u_15
	            return
	        elseif v60 == Enum.DevCameraOcclusionMode.Invisicam then
	            v_u_29 = v_u_16
	        else
	            v_u_29 = v_u_15
	        end
	    else
	        v_u_29 = v_u_15
	        return
	    end
	end
	local function v_u_63() -- name: OnNewCamera
	    -- upvalues: (copy) v_u_61, (copy) v_u_45, (ref) v_u_30, (ref) v_u_31, (copy) v_u_3
	    v_u_61(v_u_45())
	    local v_u_62 = workspace.CurrentCamera
	    if v_u_62 then
	        if v_u_30 then
	            v_u_30:disconnect()
	        end
	        if v_u_31 then
	            v_u_31:disconnect()
	        end
	        v_u_30 = v_u_62:GetPropertyChangedSignal("CameraSubject"):connect(function()
	            -- upvalues: (copy) v_u_62
	            local _ = v_u_62.CameraSubject
	        end)
	        v_u_31 = v_u_62:GetPropertyChangedSignal("CameraType"):connect(function()
	            -- upvalues: (ref) v_u_61, (ref) v_u_45, (copy) v_u_62, (ref) v_u_3
	            v_u_61(v_u_45())
	            if v_u_62.CameraType == Enum.CameraType.Scriptable then
	                v_u_3.MouseBehavior = Enum.MouseBehavior.Default
	            end
	        end)
	        local _ = v_u_62.CameraSubject
	        if v_u_62.CameraType == Enum.CameraType.Scriptable then
	            v_u_3.MouseBehavior = Enum.MouseBehavior.Default
	        end
	    end
	end
	local v_u_64 = v_u_32
	local function v67(p65) -- name: OnPlayerAdded
	    -- upvalues: (copy) v_u_63, (copy) v_u_61, (copy) v_u_45, (copy) v_u_17, (copy) v_u_1, (copy) v_u_48
	    workspace.Changed:connect(function(p66)
	        -- upvalues: (ref) v_u_63
	        if p66 == "CurrentCamera" then
	            v_u_63()
	        end
	    end)
	    p65.Changed:connect(function(_)
	        -- upvalues: (ref) v_u_61, (ref) v_u_45
	        v_u_61(v_u_45())
	    end)
	    v_u_17.Changed:connect(function(_)
	        -- upvalues: (ref) v_u_61, (ref) v_u_45
	        v_u_61(v_u_45())
	    end)
	    v_u_1:BindToRenderStep("cameraRenderUpdate", Enum.RenderPriority.Camera.Value, v_u_48)
	    v_u_63()
	    v_u_61(v_u_45())
	end
	while v_u_4.LocalPlayer == nil do
	    v_u_4.PlayerAdded:wait()
	end
	v_u_33 = pcall(function()
	    -- upvalues: (ref) v_u_64, (copy) v_u_3
	    v_u_64 = v_u_3:GetLastInputType()
	    v_u_3.LastInputTypeChanged:connect(function(p68)
	        -- upvalues: (ref) v_u_64
	        v_u_64 = p68
	    end)
	end)
	v67(v_u_4.LocalPlayer)
	v_u_5:GetPropertyChangedSignal("VREnabled"):connect(function() -- name: OnVREnabled
	    -- upvalues: (copy) v_u_61, (copy) v_u_45
	    v_u_61(v_u_45())
	end)
	workspace.Camera.CameraType = Enum.CameraType.Follow
	workspace.Camera:GetPropertyChangedSignal("CameraType"):Connect(function()
	    workspace.Camera.CameraType = Enum.CameraType.Follow
	end)
end

local ok, err = pcall(CameraScript, FakeScript, FakeRequire)
if ok then
	print("[2007 Camera] on: Retro Studio's 2007 CameraScript (Follow camera) and its Retro camera.")
else
	genv.BP_Camera2007Running = nil
	warn("[2007 Camera] the CameraScript stopped: " .. tostring(err))
end

----------------------------------------------------------------------------------------------------
-- THE RETRO CAMERA, as given (Retro Studio, StarterPlayerScripts.Camera: Main, Popper, Opacity); it takes over
-- the camera every frame (it unbinds "cameraRenderUpdate", the CameraScript's update), as in Retro Studio
----------------------------------------------------------------------------------------------------
do
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
				-- (Addtion-Scripts) 2007: you are not turned to face where you look in first person
				GameSettings.RotationType = Enum.RotationType.MovementRelative
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
				s.Parent = (typeof(script) == "Instance" and script) or game:GetService("SoundService") -- (an executor has no script)
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
				if input > 0 then
					zoom = math.max(1, zoom / (1 + ZOOM_FACTOR*input))
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
							this:ZoomCamera(pinchBeginZoom / clampedScale)
							this:PlayTick()
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

				-- (Addtion-Scripts) also while the camera is Follow (the CameraScript keeps it Follow)
				if (TeleportService:GetTeleportSetting("FollowCamera") or camera.CameraType == Enum.CameraType.Follow) and not physics2006On() then
					if self.LastCameraTransform and not self:IsInFirstPerson() then
						local lastVec = -(self.LastCameraTransform.p - subjectPosition)
						local y = findAngleBetweenXZVectors(lastVec, self:GetCameraLook())
						if IsFinite(y) and math.abs(y) > 0.0001 then
							self.RotateInput = self.RotateInput + Vector2.new(y, 0)
						end
					end
				end

				-- (Addtion-Scripts) FIRST PERSON TURNS WITH YOU (the user's old-client video): in first person the view swings
				-- left and right as your character turns (walking round with the stick), as the old client's did, on top of
				-- any turning you do yourself. (In third person the camera is left as it is.)
				do
					-- (dragging the screen turns the view any way in first person too, up, down, sideways and right round
					-- behind you, the user asked.) Walking turns you as the old turning keys did: the stick pushed to the side
					-- swings the view round that way steadily (up to 180 degrees a second, less on a slant), straight ahead
					-- or back doesn't turn it. It goes by the stick, not by the body, so turning the view by hand while you
					-- walk never feeds back into a spin.
					if self:IsInFirstPerson() and humanoid then
						local move = humanoid.MoveDirection * XZ_VECTOR
						local look = self:GetCameraLook() * XZ_VECTOR
						if move.Magnitude > 0.05 and look.Magnitude > 0.01 then
							local y = findAngleBetweenXZVectors(move.Unit, look.Unit)
							if IsFinite(y) and math.abs(y) > 0.05 and math.abs(y) < 2.6 then
								local dt = math.min(0.1, timeDelta)
								local rate = math.rad(180) * math.sin(math.abs(y)) * math.min(1, move.Magnitude)
								local step = math.min(math.abs(y), rate * dt)
								self.RotateInput = self.RotateInput + Vector2.new((y > 0) and step or -step, 0)
							end
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
			
				local newCF = CFrame_new(subjectPosition - (zoom * newLookVector), subjectPosition)
				camera.CFrame = camera.CFrame:Lerp(newCF,.8)
				self.LastCameraTransform = camera.CFrame
			end
			lastUpdate = now
		end
	
		GameSettings:SetCameraYInvertVisible()
		GameSettings:SetGamepadCameraSensitivityVisible()

		_G.RetroCamMain = this
	end


	-- [[ MODULE: OPACITY ]]
	local IsHeadThing
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

		local function HasToolAncestor(object)
			return (object:FindFirstAncestorWhichIsA("Tool")) ~= nil
		end

		local function IsValidPartToModify(part)
			if part:IsA('BasePart') or part:IsA('Decal') then
				return not HasToolAncestor(part)
			end
			return false
		end

		-- (Addtion-Scripts) the head and what sits on it: the Head, its face, hats / hair / face accessories (welded to the
		-- head or on a head attachment) and Classic Face's classic head
		local HEAD_ATTACHMENTS = { HatAttachment = true, HairAttachment = true, FaceFrontAttachment = true, FaceCenterAttachment = true }
		local headThing = setmetatable({}, { __mode = "k" })
		function IsHeadThing(object)
			local known = headThing[object]
			if known ~= nil then return known end
			local result = false
			pcall(function()
				local character = object:FindFirstAncestorWhichIsA("Model")
				local head = character and character:FindFirstChild("Head")
				if object == head or (head and object.Parent == head) then
					result = true
				elseif object.Name == "ClassicHead" or (object.Parent and object.Parent.Name == "ClassicHead") then
					result = true
				else
					local accessory = object:FindFirstAncestorWhichIsA("Accoutrement")
					local handle = accessory and accessory:FindFirstChild("Handle")
					if handle then
						for _, d in ipairs(handle:GetChildren()) do
							if d:IsA("Attachment") and HEAD_ATTACHMENTS[d.Name] then result = true break end
							if d:IsA("JointInstance") and head and (d.Part0 == head or d.Part1 == head) then result = true break end
						end
					end
				end
			end)
			headThing[object] = result
			return result
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
				elseif object:IsA('Tool') then
					if ToolDescendantAddedConns[object] then ToolDescendantAddedConns[object]:Disconnect() end
					ToolDescendantAddedConns[object] = object.DescendantAdded:Connect(function (toolChild)
						CachedParts[toolChild] = nil
						if toolChild:IsA('BasePart') or toolChild:IsA('Decal') then
							toolChild.LocalTransparencyModifier = 0
						end
					end)
				
					if ToolDescendantRemovingConns[object] then ToolDescendantRemovingConns[object]:Disconnect() end
					ToolDescendantRemovingConns[object] = object.DescendantRemoving:Connect(function (formerToolChild)
						task.wait() 
						if character and formerToolChild and formerToolChild:IsDescendantOf(character) then
							if IsValidPartToModify(formerToolChild) then
								CachedParts[formerToolChild] = true
								TransparencyDirty = true
							end
						end
					end)
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
					local distance = (currentCamera.Focus.p - currentCamera.CFrame.p).magnitude
					if distance < 2 then transparency = 1
					elseif distance < 6 then transparency = 0.5
					else transparency = 0 end
				end

				-- (Addtion-Scripts) as in the user's 2007 recording: the body never turns see-through as the camera comes
				-- close (it goes right up to the head), and in first person only the head and what is on it (face, hats,
				-- hair, Classic Face's classic head) are hidden: looking down you see your own body and arms
				local firstPerson = transparency >= 1
				if TransparencyDirty or LastTransparency ~= firstPerson then
					for child in pairs(CachedParts) do
						if child:IsA("BasePart") or child:IsA("Decal") then
							local hide = firstPerson and IsHeadThing(child)
							child.LocalTransparencyModifier = hide and 1 or 0
						end
					end
					TransparencyDirty = false
					LastTransparency = firstPerson
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
		PopperCam:Update()
		Opacity:Update()

		-- Remove the default Roblox camera handler so our retro logic takes full priority
		RunService:UnbindFromRenderStep("cameraRenderUpdate")
	end

	-- Bind our update cycle right before rendering
	RunService:BindToRenderStep("RetroCamera", 250, update)
end
