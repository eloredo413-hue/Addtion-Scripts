--========================================================
-- 2007 CAMERA (Addtion-Scripts)
-- Retro Studio's 2007 CameraScript (PlayerScripts.CameraScript), the script as it was given, made to run from a
-- script executor. That script loads its camera modules from inside itself (RootCamera with AttachCamera,
-- FixedCamera, ScriptableCamera, TrackCamera, WatchCamera, OrbitalCamera, ClassicCamera and FollowCamera; PopperCam;
-- Invisicam). An executor has no such modules, so they are written out here, as the 2016-era camera modules they
-- were, and the CameraScript below finds them where it looks for them. The CameraScript itself is unchanged except
-- for one line: ReplicatedStorage.TimePeriod (Retro Studio's own value) is read if the game has it, instead of being
-- waited for forever. (The newer copy of it, decompiled more cleanly.)
-- What it does, like the original: Roblox's own camera is replaced by these modules, and the camera is set to Follow
-- and kept there: it swings round behind you as you walk, waits 2 s after you look around, PopperCam (the camera pops
-- in front of walls and eases back out). Zooming is the 2013 Camera's: a quarter in or out a click, no gliding.
-- Added, because the CameraScript leaves it to a module it doesn't include: in first person your character is hidden,
-- except the tool in your hand (the 2016 TransparencyController).
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
						elseif follow and not (isInFirstPerson or userRecentlyPannedCamera) then
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
		local transparency = (distance < 2) and (1.0 - (distance - 0.5) / 1.5) or 0
		if transparency < 0.5 then transparency = 0 end
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

-- first person: the character hidden (the CameraScript has no TransparencyController of its own)
do
	local transparency = requireModule("TransparencyController")
	local function follow()
		local camera = workspace.CurrentCamera
		transparency:SetSubject(camera and camera.CameraSubject)
	end
	local cameraConn = nil
	local function watchCamera()
		if cameraConn then cameraConn:Disconnect() end
		local camera = workspace.CurrentCamera
		if camera then
			cameraConn = camera:GetPropertyChangedSignal("CameraSubject"):Connect(follow)
		end
		follow()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
	RunService:BindToRenderStep("BP2007Transparency", Enum.RenderPriority.Camera.Value + 1, function()
		transparency:Update()
	end)
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
	print("[2007 Camera] on: Retro Studio's 2007 CameraScript (Follow camera).")
else
	genv.BP_Camera2007Running = nil
	warn("[2007 Camera] the CameraScript stopped: " .. tostring(err))
end
