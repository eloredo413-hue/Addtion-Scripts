-- [[ MODERN R6 ANIMATION — adds "Modern R6" to Bloxy's "Choose your animations" step (R15) ]]
-- The modern R6 animations (they came before R15) on an R15 character: dnezero's animation script, kept as
-- it was given. It works on your own R15 character; the game's own Animate is switched off while it runs.
--
-- It never changes Bloxy's own choices: "Modern R6" is a fifth button next to 2008 FE / 2014 FE / Old R15 /
-- Normal (before Old R15), and picking it moves the wizard on exactly as "Normal" does (so no Bloxy animation
-- script runs) while this script starts the animation. Picking any of Bloxy's own four turns it off.
--
-- Your pick is saved (BloxyModernR6Choice.json), so when Bloxy's "skip setup" box is ticked it starts by
-- itself, just like Bloxy's own saved choices. When you re-configure with "skip" ticked it is only saved, not
-- started (the same as Bloxy's own choices).
--
-- Works when executed before OR after Bloxy, on its own or loaded by the addition script.
-- Also usable by hand: getgenv().ModernR6Animation.Start() / .Stop() / .IsRunning()

do
	local Players = game:GetService("Players")
	local HttpService = game:GetService("HttpService")
	local CoreGui = game:GetService("CoreGui")

	local Env = (getgenv and getgenv()) or _G

	-- Running it again (or loading it twice) replaces the old copy
	if Env.ModernR6AnimationCleanup then
		pcall(Env.ModernR6AnimationCleanup)
	end

	local SAVE_FILE = "BloxyModernR6Choice.json"
	local BLOXY_CONFIG = "BloxyParadoxConfig.json"
	local BLOXY_GUI = "BloxyParadoxProject"
	-- Bloxy's step the button goes on (matched without caring about capitals)
	local STEP_TEXT = "choose your animations: r15"
	local BUTTON_NAME = "ModernR6Button"
	local BUTTON_TEXT = "Modern R6"

	local connections = {}
	local watched = {}                                 -- Bloxy GUIs being watched
	local handled = setmetatable({}, { __mode = "k" }) -- step frames already given the button
	local alive = true

	local function connect(signal, fn)
		local c = signal:Connect(fn)
		table.insert(connections, c)
		return c
	end

	local function disconnectAll(list)
		for _, c in ipairs(list) do
			pcall(function() c:Disconnect() end)
		end
		table.clear(list)
	end

	------------------------------------------------------------
	-- THE ANIMATION (dnezero's script, as it was given)
	-- (Addtion-Scripts) The only changes, marked below: its connections are kept (track) and its loop also
	-- stops when the animation is switched off, so it can be stopped; PlayEmote is waited for 5 seconds at
	-- most (a game whose Animate has none no longer holds the script up there).
	------------------------------------------------------------
	local running = false
	local generation = 0
	local runConnections = {}
	local function track(c) -- (Addtion-Scripts)
		table.insert(runConnections, c)
		return c
	end

	-- hello from dnezero :3

	local plr = game:GetService("Players").LocalPlayer

	local function RunCustomAnimation(Char)
		local myGeneration = generation -- (Addtion-Scripts)
		if Char:WaitForChild("Humanoid").RigType == Enum.HumanoidRigType.R6 then
			return
		end

		if Char:WaitForChild("Animate") ~= nil then
			Char.Animate.Disabled = true
		end
		if not running or myGeneration ~= generation then return end -- (Addtion-Scripts) switched off meanwhile

		for i,v in next, Char.Humanoid:GetPlayingAnimationTracks() do
			v:Stop()
		end

		--fake script
		local script = Char.Animate

		local Character = Char
		local Humanoid = Character:WaitForChild("Humanoid")
		local pose = "Standing"

		local UserGameSettings = UserSettings():GetService("UserGameSettings")

		local userNoUpdateOnLoopSuccess, userNoUpdateOnLoopValue = pcall(function() return UserSettings():IsUserFeatureEnabled("UserNoUpdateOnLoop") end)
		local userNoUpdateOnLoop = userNoUpdateOnLoopSuccess and userNoUpdateOnLoopValue

		local AnimationSpeedDampeningObject = script:FindFirstChild("ScaleDampeningPercent")
		local HumanoidHipHeight = 2

		local humanoidSpeed = 0 -- speed most recently sent to us from onRunning()
		local cachedRunningSpeed = 0 -- The most recent speed used to compute blends.  Tiny variations from cachedRunningSpeed will not cause animation updates.
		local cachedLocalDirection = {x=0.0, y=0.0} -- unit 2D object space direction of motion
		local smallButNotZero = 0.0001 -- We want weights to be small but not so small the animation stops
		local runBlendtime = 0.2
		local lastLookVector = Vector3.new(0.0, 0.0, 0.0) -- used to track whether rootPart orientation is changing.
		local lastBlendTime = 0 -- The last time we blended velocities
		local WALK_SPEED = 6.4
		local RUN_SPEED = 12.8

		local EMOTE_TRANSITION_TIME = 0.1

		local currentAnim = ""
		local currentAnimInstance = nil
		local currentAnimTrack = nil
		local currentAnimKeyframeHandler = nil
		local currentAnimSpeed = 1.0

		local PreloadedAnims = {}

		local animTable = {}
		local animNames = {
			idle = 	{
				{ id = "http://www.roblox.com/asset/?id=12521158637", weight = 9 },
				{ id = "http://www.roblox.com/asset/?id=12521162526", weight = 1 },
			},
			walk = 	{
				{ id = "http://www.roblox.com/asset/?id=12518152696", weight = 10 }
			},
			run = 	{
				{ id = "http://www.roblox.com/asset/?id=12518152696", weight = 10 }
			},
			jump = 	{
				{ id = "http://www.roblox.com/asset/?id=12520880485", weight = 10 }
			},
			fall = 	{
				{ id = "http://www.roblox.com/asset/?id=12520972571", weight = 10 }
			},
			climb = {
				{ id = "http://www.roblox.com/asset/?id=12520982150", weight = 10 }
			},
			sit = 	{
				{ id = "http://www.roblox.com/asset/?id=12520993168", weight = 10 }
			},
			toolnone = {
				{ id = "http://www.roblox.com/asset/?id=12520996634", weight = 10 }
			},
			toolslash = {
				{ id = "http://www.roblox.com/asset/?id=12520999032", weight = 10 }
			},
			toollunge = {
				{ id = "http://www.roblox.com/asset/?id=12521002003", weight = 10 }
			},
			wave = {
				{ id = "http://www.roblox.com/asset/?id=12521004586", weight = 10 }
			},
			point = {
				{ id = "http://www.roblox.com/asset/?id=12521007694", weight = 10 }
			},
			dance = {
				{ id = "http://www.roblox.com/asset/?id=12521009666", weight = 10 },
				{ id = "http://www.roblox.com/asset/?id=12521151637", weight = 10 },
				{ id = "http://www.roblox.com/asset/?id=12521015053", weight = 10 }
			},
			dance2 = {
				{ id = "http://www.roblox.com/asset/?id=12521169800", weight = 10 },
				{ id = "http://www.roblox.com/asset/?id=12521173533", weight = 10 },
				{ id = "http://www.roblox.com/asset/?id=12521027874", weight = 10 }
			},
			dance3 = {
				{ id = "http://www.roblox.com/asset/?id=12521178362", weight = 10 },
				{ id = "http://www.roblox.com/asset/?id=12521181508", weight = 10 },
				{ id = "http://www.roblox.com/asset/?id=12521184133", weight = 10 }
			},
			laugh = {
				{ id = "http://www.roblox.com/asset/?id=12521018724", weight = 10 }
			},
			cheer = {
				{ id = "http://www.roblox.com/asset/?id=12521021991", weight = 10 }
			},
		}


		local strafingLocomotionMap = {}
		local fallbackLocomotionMap = {}
		local locomotionMap = strafingLocomotionMap
		-- Existance in this list signifies that it is an emote, the value indicates if it is a looping emote
		local emoteNames = { wave = false, point = false, dance = true, dance2 = true, dance3 = true, laugh = false, cheer = false}

		math.randomseed(tick())

		function findExistingAnimationInSet(set, anim)
			if set == nil or anim == nil then
				return 0
			end

			for idx = 1, set.count, 1 do
				if set[idx].anim.AnimationId == anim.AnimationId then
					return idx
				end
			end

			return 0
		end

		function configureAnimationSet(name, fileList)
			if (animTable[name] ~= nil) then
				for _, connection in pairs(animTable[name].connections) do
					connection:disconnect()
				end
			end
			animTable[name] = {}
			animTable[name].count = 0
			animTable[name].totalWeight = 0
			animTable[name].connections = {}

			-- (dnezero's script had a commented-out block here that loads the player's own (non-classic)
			-- animations from Animate; it stays off)

			-- if you uncomment the above section, comment out this "if"-block
			if name == "run" or name == "walk" then
				local speed = name == "run" and RUN_SPEED or WALK_SPEED
				fallbackLocomotionMap[name] = {lv=Vector2.new(0.0, speed), speed = speed}
				locomotionMap = fallbackLocomotionMap
				-- If you don't have a linear velocity with your run or walk, you can't blend/strafe
				--warn("Strafe blending disabled. No linear velocity information for "..'"'.."walk"..'"'.." and "..'"'.."run"..'"'..".")
			end


			-- fallback to defaults
			if (animTable[name].count <= 0) then
				for idx, anim in pairs(fileList) do
					animTable[name][idx] = {}
					animTable[name][idx].anim = Instance.new("Animation")
					animTable[name][idx].anim.Name = name
					animTable[name][idx].anim.AnimationId = anim.id
					animTable[name][idx].weight = anim.weight
					animTable[name].count = animTable[name].count + 1
					animTable[name].totalWeight = animTable[name].totalWeight + anim.weight
				end
			end

			-- preload anims
			for i, animType in pairs(animTable) do
				for idx = 1, animType.count, 1 do
					if PreloadedAnims[animType[idx].anim.AnimationId] == nil then
						Humanoid:LoadAnimation(animType[idx].anim)
						PreloadedAnims[animType[idx].anim.AnimationId] = true
					end
				end
			end
		end

		-- Setup animation objects
		function scriptChildModified(child)
			local fileList = animNames[child.Name]
			if (fileList ~= nil) then
				configureAnimationSet(child.Name, fileList)
			else
				if child:isA("StringValue") then
					animNames[child.Name] = {}
					configureAnimationSet(child.Name, animNames[child.Name])
				end
			end
		end

		track(script.ChildAdded:connect(scriptChildModified)) -- (Addtion-Scripts: track)
		track(script.ChildRemoved:connect(scriptChildModified)) -- (Addtion-Scripts: track)

		-- Clear any existing animation tracks
		-- Fixes issue with characters that are moved in and out of the Workspace accumulating tracks
		local animator = if Humanoid then Humanoid:FindFirstChildOfClass("Animator") else nil
		if animator then
			local animTracks = animator:GetPlayingAnimationTracks()
			for i,track in ipairs(animTracks) do
				track:Stop(0)
				track:Destroy()
			end
		end

		for name, fileList in pairs(animNames) do
			configureAnimationSet(name, fileList)
		end
		for _,child in script:GetChildren() do
			if child:isA("StringValue") and not animNames[child.name] then
				animNames[child.Name] = {}
				configureAnimationSet(child.Name, animNames[child.Name])
			end
		end

		-- ANIMATION

		-- declarations
		local toolAnim = "None"
		local toolAnimTime = 0

		local jumpAnimTime = 0
		local jumpAnimDuration = 0.31

		local toolTransitionTime = 0.1
		local fallTransitionTime = 0.2

		local currentlyPlayingEmote = false

		-- functions

		function stopAllAnimations()
			local oldAnim = currentAnim

			-- return to idle if finishing an emote
			if (emoteNames[oldAnim] ~= nil and emoteNames[oldAnim] == false) then
				oldAnim = "idle"
			end

			if currentlyPlayingEmote then
				oldAnim = "idle"
				currentlyPlayingEmote = false
			end

			currentAnim = ""
			currentAnimInstance = nil
			if (currentAnimKeyframeHandler ~= nil) then
				currentAnimKeyframeHandler:disconnect()
			end

			if (currentAnimTrack ~= nil) then
				currentAnimTrack:Stop()
				currentAnimTrack:Destroy()
				currentAnimTrack = nil
			end

			for _,v in pairs(locomotionMap) do
				if v.track then
					v.track:Stop()
					v.track:Destroy()
					v.track = nil
				end
			end

			return oldAnim
		end

		function getHeightScale()
			if Humanoid then
				if not Humanoid.AutomaticScalingEnabled then
					return 1
				end

				local scale = Humanoid.HipHeight / HumanoidHipHeight
				if AnimationSpeedDampeningObject == nil then
					AnimationSpeedDampeningObject = script:FindFirstChild("ScaleDampeningPercent")
				end
				if AnimationSpeedDampeningObject ~= nil then
					scale = 1 + (Humanoid.HipHeight - HumanoidHipHeight) * AnimationSpeedDampeningObject.Value / HumanoidHipHeight
				end
				return scale
			end
			return 1
		end


		local function signedAngle(a, b)
			return -math.atan2(a.x * b.y - a.y * b.x, a.x * b.x + a.y * b.y)
		end

		local angleWeight = 2.0
		local function get2DWeight(px, p1, p2, sx, s1, s2)
			local avgLength = 0.5 * (s1 + s2)

			local p_1 = {x = (sx - s1)/avgLength, y = (angleWeight * signedAngle(p1, px))}
			local p12 = {x = (s2 - s1)/avgLength, y = (angleWeight * signedAngle(p1, p2))}
			local denom = smallButNotZero + (p12.x*p12.x + p12.y*p12.y)
			local numer = p_1.x * p12.x + p_1.y * p12.y
			local r = math.clamp(1.0 - numer/denom, 0.0, 1.0)
			return r
		end

		local function blend2D(targetVelo, targetSpeed)
			local h = {}
			local sum = 0.0
			for n,v1 in pairs(locomotionMap) do
				if targetVelo.x * v1.lv.x < 0.0 or targetVelo.y * v1.lv.y < 0 then
					-- Require same quadrant as target
					h[n] = 0.0
					continue
				end
				h[n] = math.huge
				for j,v2 in pairs(locomotionMap) do
					if targetVelo.x * v2.lv.x < 0.0 or targetVelo.y * v2.lv.y < 0 then
						-- Require same quadrant as target
						continue
					end
					h[n] = math.min(h[n], get2DWeight(targetVelo, v1.lv, v2.lv, targetSpeed, v1.speed, v2.speed))
				end
				sum += h[n]
			end

			--truncates below 10% contribution
			local sum2 = 0.0
			local weightedVeloX = 0
			local weightedVeloY = 0
			for n,v in pairs(locomotionMap) do

				if (h[n] / sum > 0.1) then
					sum2 += h[n]
					weightedVeloX += h[n] * v.lv.x
					weightedVeloY += h[n] * v.lv.y
				else
					h[n] = 0.0
				end
			end
			local animSpeed
			local weightedSpeedSquared = weightedVeloX * weightedVeloX + weightedVeloY * weightedVeloY
			if weightedSpeedSquared > smallButNotZero then
				animSpeed = math.sqrt(targetSpeed * targetSpeed / weightedSpeedSquared)
			else
				animSpeed = 0
			end

			animSpeed = animSpeed / getHeightScale()
			local groupTimePosition = 0
			for n,v in pairs(locomotionMap) do
				if v.track.IsPlaying then
					groupTimePosition = v.track.TimePosition
					break
				end
			end
			for n,v in pairs(locomotionMap) do
				-- if not loco
				if h[n] > 0.0 then
					if not v.track.IsPlaying then
						v.track:Play(runBlendtime)
						v.track.TimePosition = groupTimePosition
					end

					local weight = math.max(smallButNotZero, h[n] / sum2)
					v.track:AdjustWeight(weight, runBlendtime)
					v.track:AdjustSpeed(animSpeed)
				else
					v.track:Stop(runBlendtime)
				end
			end

		end

		local function getWalkDirection()
			local walkToPoint = Humanoid.WalkToPoint
			local walkToPart = Humanoid.WalkToPart
			if Humanoid.MoveDirection ~= Vector3.zero then
				return Humanoid.MoveDirection
			elseif walkToPart or walkToPoint ~= Vector3.zero then
				local destination
				if walkToPart then
					destination = walkToPart.CFrame:PointToWorldSpace(walkToPoint)
				else
					destination = walkToPoint
				end
				local moveVector = Vector3.zero
				if Humanoid.RootPart then
					moveVector = destination - Humanoid.RootPart.CFrame.Position
					moveVector = Vector3.new(moveVector.x, 0.0, moveVector.z)
					local mag = moveVector.Magnitude
					if mag > 0.01 then
						moveVector /= mag
					end
				end
				return moveVector
			else
				return Humanoid.MoveDirection
			end
		end

		local function updateVelocity(currentTime)

			local tempDir

			if locomotionMap == strafingLocomotionMap then

				local moveDirection = getWalkDirection()

				if not Humanoid.RootPart then
					return
				end

				local cframe = Humanoid.RootPart.CFrame
				if math.abs(cframe.UpVector.Y) < smallButNotZero or pose ~= "Running" or humanoidSpeed < 0.001 then
					-- We are horizontal!  Do something  (turn off locomotion)
					for n,v in pairs(locomotionMap) do
						if v.track then
							v.track:AdjustWeight(smallButNotZero, runBlendtime)
						end
					end
					return
				end
				local lookat = cframe.LookVector
				local direction = Vector3.new(lookat.X, 0.0, lookat.Z)
				direction = direction / direction.Magnitude --sensible upVector means this is non-zero.
				local ly = moveDirection:Dot(direction)
				if ly <= 0.0 and ly > -0.05 then
					ly = smallButNotZero -- break quadrant ties in favor of forward-friendly strafes
				end
				local lx = direction.X*moveDirection.Z - direction.Z*moveDirection.X
				local tempDir = Vector2.new(lx, ly) -- root space moveDirection
				local delta = Vector2.new(tempDir.x-cachedLocalDirection.x, tempDir.y-cachedLocalDirection.y)
				-- Time check serves the purpose of the old keyframeReached sync check, as it syncs anim timePosition
				if delta:Dot(delta) > 0.001 or math.abs(humanoidSpeed - cachedRunningSpeed) > 0.01 or currentTime - lastBlendTime > 1 then
					cachedLocalDirection = tempDir
					cachedRunningSpeed = humanoidSpeed
					lastBlendTime = currentTime
					blend2D(cachedLocalDirection, cachedRunningSpeed)
				end
			else
				if math.abs(humanoidSpeed - cachedRunningSpeed) > 0.01 or currentTime - lastBlendTime > 1 then
					cachedRunningSpeed = humanoidSpeed
					lastBlendTime = currentTime
					blend2D(Vector2.yAxis, cachedRunningSpeed)
				end
			end
		end

		function setAnimationSpeed(speed)
			if currentAnim ~= "walk" then
				if speed ~= currentAnimSpeed then
					currentAnimSpeed = speed
					currentAnimTrack:AdjustSpeed(currentAnimSpeed)
				end
			end
		end

		function keyFrameReachedFunc(frameName)
			if (frameName == "End") then
				local repeatAnim = currentAnim
				-- return to idle if finishing an emote
				if (emoteNames[repeatAnim] ~= nil and emoteNames[repeatAnim] == false) then
					repeatAnim = "idle"
				end

				if currentlyPlayingEmote then
					if currentAnimTrack.Looped then
						-- Allow the emote to loop
						return
					end

					repeatAnim = "idle"
					currentlyPlayingEmote = false
				end

				local animSpeed = currentAnimSpeed
				playAnimation(repeatAnim, 0.15, Humanoid)
				setAnimationSpeed(animSpeed)
			end
		end

		function rollAnimation(animName)
			local roll = math.random(1, animTable[animName].totalWeight)
			local origRoll = roll
			local idx = 1
			while (roll > animTable[animName][idx].weight) do
				roll = roll - animTable[animName][idx].weight
				idx = idx + 1
			end
			return idx
		end

		local maxVeloX, minVeloX, maxVeloY, minVeloY

		local function destroyRunAnimations()
			for _,v in pairs(strafingLocomotionMap) do
				if v.track then
					v.track:Stop()
					v.track:Destroy()
					v.track = nil
				end
			end
			for _,v in pairs(fallbackLocomotionMap) do
				if v.track then
					v.track:Stop()
					v.track:Destroy()
					v.track = nil
				end
			end
			cachedRunningSpeed = 0
		end

		local function resetVelocityBounds(velo)
			minVeloX = 0
			maxVeloX = 0
			minVeloY = 0
			maxVeloY = 0
		end

		local function updateVelocityBounds(velo)
			if velo then
				if velo.x > maxVeloX then maxVeloX = velo.x end
				if velo.y > maxVeloY then maxVeloY = velo.y end
				if velo.x < minVeloX then minVeloX = velo.x end
				if velo.y < minVeloY then minVeloY = velo.y end
			end
		end

		local function checkVelocityBounds(velo)
			if maxVeloX == 0 or minVeloX == 0 or maxVeloY == 0 or minVeloY == 0 then
				if locomotionMap == strafingLocomotionMap then
					warn("Strafe blending disabled.  Not all quadrants of motion represented.")
				end
				locomotionMap = fallbackLocomotionMap
			else
				locomotionMap = strafingLocomotionMap
			end
		end

		local function setupWalkAnimation(anim, animName, transitionTime, humanoid)
			resetVelocityBounds()
			-- check to see if we need to blend a walk/run animation
			for n,v in pairs(locomotionMap) do
				v.track = humanoid:LoadAnimation(animTable[n][1].anim)
				v.track.Priority = Enum.AnimationPriority.Core
				updateVelocityBounds(v.lv)
			end
			checkVelocityBounds()
		end

		local function switchToAnim(anim, animName, transitionTime, humanoid)
			-- switch animation
			if (anim ~= currentAnimInstance) then

				if (currentAnimTrack ~= nil) then
					currentAnimTrack:Stop(transitionTime)
					currentAnimTrack:Destroy()
				end
				if (currentAnimKeyframeHandler ~= nil) then
					currentAnimKeyframeHandler:disconnect()
				end


				currentAnimSpeed = 1.0

				currentAnim = animName
				currentAnimInstance = anim	-- nil in the case of locomotion

				if animName == "walk" then
					setupWalkAnimation(anim, animName, transitionTime, humanoid)
				else
					destroyRunAnimations()
					-- load it to the humanoid; get AnimationTrack
					currentAnimTrack = humanoid:LoadAnimation(anim)
					currentAnimTrack.Priority = Enum.AnimationPriority.Core

					currentAnimTrack:Play(transitionTime)

					-- set up keyframe name triggers
					currentAnimKeyframeHandler = currentAnimTrack.KeyframeReached:connect(keyFrameReachedFunc)
				end
			end
		end

		function playAnimation(animName, transitionTime, humanoid)
			local idx = rollAnimation(animName)
			local anim = animTable[animName][idx].anim

			switchToAnim(anim, animName, transitionTime, humanoid)
			currentlyPlayingEmote = false
		end

		function playEmote(emoteAnim, transitionTime, humanoid)
			switchToAnim(emoteAnim, emoteAnim.Name, transitionTime, humanoid)
			currentlyPlayingEmote = true
		end

		-------------------------------------------------------------------------------------------
		-------------------------------------------------------------------------------------------

		local toolAnimName = ""
		local toolAnimTrack = nil
		local toolAnimInstance = nil
		local currentToolAnimKeyframeHandler = nil

		function toolKeyFrameReachedFunc(frameName)
			if (frameName == "End") then
				playToolAnimation(toolAnimName, 0.0, Humanoid)
			end
		end


		function playToolAnimation(animName, transitionTime, humanoid, priority)
			local idx = rollAnimation(animName)
			local anim = animTable[animName][idx].anim

			if (toolAnimInstance ~= anim) then

				if (toolAnimTrack ~= nil) then
					toolAnimTrack:Stop()
					toolAnimTrack:Destroy()
					transitionTime = 0
				end

				-- load it to the humanoid; get AnimationTrack
				toolAnimTrack = humanoid:LoadAnimation(anim)
				if priority then
					toolAnimTrack.Priority = priority
				end

				-- play the animation
				toolAnimTrack:Play(transitionTime)
				toolAnimName = animName
				toolAnimInstance = anim

				currentToolAnimKeyframeHandler = toolAnimTrack.KeyframeReached:connect(toolKeyFrameReachedFunc)
			end
		end

		function stopToolAnimations()
			local oldAnim = toolAnimName

			if (currentToolAnimKeyframeHandler ~= nil) then
				currentToolAnimKeyframeHandler:disconnect()
			end

			toolAnimName = ""
			toolAnimInstance = nil
			if (toolAnimTrack ~= nil) then
				toolAnimTrack:Stop()
				toolAnimTrack:Destroy()
				toolAnimTrack = nil
			end

			return oldAnim
		end

		-------------------------------------------------------------------------------------------
		-------------------------------------------------------------------------------------------
		-- STATE CHANGE HANDLERS

		function onRunning(speed)
			local movedDuringEmote = currentlyPlayingEmote and Humanoid.MoveDirection == Vector3.new(0, 0, 0)
			local speedThreshold = movedDuringEmote and Humanoid.WalkSpeed or 0.75
			humanoidSpeed = speed
			if speed > speedThreshold then
				playAnimation("walk", 0.2, Humanoid)
				if pose ~= "Running" then
					pose = "Running"
					updateVelocity(0) -- Force velocity update in response to state change
				end
			else
				if emoteNames[currentAnim] == nil and not currentlyPlayingEmote then
					playAnimation("idle", 0.2, Humanoid)
					pose = "Standing"
				end
			end



		end

		function onDied()
			pose = "Dead"
		end

		function onJumping()
			playAnimation("jump", 0.1, Humanoid)
			jumpAnimTime = jumpAnimDuration
			pose = "Jumping"
		end

		function onClimbing(speed)
			local scale = 5.0
			playAnimation("climb", 0.1, Humanoid)
			setAnimationSpeed(speed / scale)
			pose = "Climbing"
		end

		function onGettingUp()
			pose = "GettingUp"
		end

		function onFreeFall()
			if (jumpAnimTime <= 0) then
				playAnimation("fall", fallTransitionTime, Humanoid)
			end
			pose = "FreeFall"
		end

		function onFallingDown()
			pose = "FallingDown"
		end

		function onSeated()
			pose = "Seated"
		end

		function onPlatformStanding()
			pose = "PlatformStanding"
		end

		-------------------------------------------------------------------------------------------
		-------------------------------------------------------------------------------------------

		function onSwimming(speed)
			if speed > 0 then
				pose = "Running"
			else
				pose = "Standing"
			end
		end

		function animateTool()
			if (toolAnim == "None") then
				playToolAnimation("toolnone", toolTransitionTime, Humanoid, Enum.AnimationPriority.Idle)
				return
			end

			if (toolAnim == "Slash") then
				playToolAnimation("toolslash", 0, Humanoid, Enum.AnimationPriority.Action)
				return
			end

			if (toolAnim == "Lunge") then
				playToolAnimation("toollunge", 0, Humanoid, Enum.AnimationPriority.Action)
				return
			end
		end

		function getToolAnim(tool)
			for _, c in ipairs(tool:GetChildren()) do
				if c.Name == "toolanim" and c.className == "StringValue" then
					return c
				end
			end
			return nil
		end

		local lastTick = 0

		function stepAnimate(currentTime)
			local amplitude = 1
			local frequency = 1
			local deltaTime = currentTime - lastTick
			lastTick = currentTime

			local climbFudge = 0
			local setAngles = false

			if (jumpAnimTime > 0) then
				jumpAnimTime = jumpAnimTime - deltaTime
			end

			if (pose == "FreeFall" and jumpAnimTime <= 0) then
				playAnimation("fall", fallTransitionTime, Humanoid)
			elseif (pose == "Seated") then
				playAnimation("sit", 0.5, Humanoid)
				return
			elseif (pose == "Running") then
				playAnimation("walk", 0.2, Humanoid)
				updateVelocity(currentTime)
			elseif (pose == "Dead" or pose == "GettingUp" or pose == "FallingDown" or pose == "Seated" or pose == "PlatformStanding") then
				stopAllAnimations()
				amplitude = 0.1
				frequency = 1
				setAngles = true
			end

			-- Tool Animation handling
			local tool = Character:FindFirstChildOfClass("Tool")
			if tool and tool:FindFirstChild("Handle") then
				local animStringValueObject = getToolAnim(tool)

				if animStringValueObject then
					toolAnim = animStringValueObject.Value
					-- message recieved, delete StringValue
					animStringValueObject.Parent = nil
					toolAnimTime = currentTime + .3
				end

				if currentTime > toolAnimTime then
					toolAnimTime = 0
					toolAnim = "None"
				end

				animateTool()
			else
				stopToolAnimations()
				toolAnim = "None"
				toolAnimInstance = nil
				toolAnimTime = 0
			end
		end


		-- connect events (Addtion-Scripts: each one kept with track, so they can be stopped)
		track(Humanoid.Died:connect(onDied))
		track(Humanoid.Running:connect(onRunning))
		track(Humanoid.Jumping:connect(onJumping))
		track(Humanoid.Climbing:connect(onClimbing))
		track(Humanoid.GettingUp:connect(onGettingUp))
		track(Humanoid.FreeFalling:connect(onFreeFall))
		track(Humanoid.FallingDown:connect(onFallingDown))
		track(Humanoid.Seated:connect(onSeated))
		track(Humanoid.PlatformStanding:connect(onPlatformStanding))
		track(Humanoid.Swimming:connect(onSwimming))

		-- setup emote chat hook
		track(game:GetService("Players").LocalPlayer.Chatted:connect(function(msg)
			local emote = ""
			if (string.sub(msg, 1, 3) == "/e ") then
				emote = string.sub(msg, 4)
			elseif (string.sub(msg, 1, 7) == "/emote ") then
				emote = string.sub(msg, 8)
			end

			if (pose == "Standing" and emoteNames[emote] ~= nil) then
				playAnimation(emote, EMOTE_TRANSITION_TIME, Humanoid)
			end
		end))

		-- emote bindable hook
		-- (Addtion-Scripts) waited for 5 seconds at most: a game whose Animate has no PlayEmote no longer holds
		-- the script up here (it was the last thing before the idle animation and the loop below)
		local playEmoteHook = script:WaitForChild("PlayEmote", 5)
		if playEmoteHook then
			playEmoteHook.OnInvoke = function(emote)
				-- Only play emotes when idling
				if pose ~= "Standing" then
					return
				end

				if emoteNames[emote] ~= nil then
					-- Default emotes
					playAnimation(emote, EMOTE_TRANSITION_TIME, Humanoid)

					return true, currentAnimTrack
				elseif typeof(emote) == "Instance" and emote:IsA("Animation") then
					-- Non-default emotes
					playEmote(emote, EMOTE_TRANSITION_TIME, Humanoid)

					return true, currentAnimTrack
				end

				-- Return false to indicate that the emote could not be played
				return false
			end
		end

		if Character.Parent ~= nil then
			-- initialize to idle
			playAnimation("idle", 0.1, Humanoid)
			pose = "Standing"
		end

		-- loop to handle timed state transitions and tool animations
		task.spawn(function()
			-- (Addtion-Scripts) also stops when the animation is switched off
			while Character.Parent ~= nil and running and myGeneration == generation do
				local _, currentGameTime = wait(0.1)
				if not running or myGeneration ~= generation then break end
				stepAnimate(currentGameTime)
			end
		end)
	end

	------------------------------------------------------------
	-- ON / OFF (Addtion-Scripts)
	------------------------------------------------------------
	local engine = {}
	local characterConn = nil

	function engine.Start()
		if running or not alive then return end
		running = true
		generation += 1
		if plr.Character then task.spawn(RunCustomAnimation, plr.Character) end
		characterConn = plr.CharacterAdded:Connect(function(Char)
			RunCustomAnimation(Char)
		end)
		print("[Modern R6 Animation] On (R15 characters).")
	end

	function engine.Stop()
		if not running then return end
		running = false
		generation += 1
		if characterConn then characterConn:Disconnect() characterConn = nil end
		disconnectAll(runConnections)
		-- the character's own Animate back (switching it on again restarts it)
		local char = plr.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			pcall(function()
				for _, t in ipairs(humanoid:GetPlayingAnimationTracks()) do t:Stop() end
			end)
		end
		local animate = char and char:FindFirstChild("Animate")
		if animate then pcall(function() animate.Disabled = false end) end
		print("[Modern R6 Animation] Off.")
	end

	function engine.IsRunning()
		return running
	end

	Env.ModernR6Animation = { Start = engine.Start, Stop = engine.Stop, IsRunning = engine.IsRunning }

	Env.ModernR6AnimationCleanup = function()
		alive = false
		disconnectAll(connections)
		table.clear(watched)
		engine.Stop()
		Env.ModernR6Animation = nil
	end

	------------------------------------------------------------
	-- SAVE / LOAD
	------------------------------------------------------------
	local function readJson(file)
		if not (readfile and isfile) then return nil end
		local ok, data = pcall(function()
			if isfile(file) then return HttpService:JSONDecode(readfile(file)) end
		end)
		return ok and type(data) == "table" and data or nil
	end

	local function loadChoice()
		local data = readJson(SAVE_FILE)
		return data ~= nil and data.ModernR6 == true
	end

	local function saveChoice(on)
		if not writefile then return end
		pcall(function() writefile(SAVE_FILE, HttpService:JSONEncode({ ModernR6 = on })) end)
	end

	-- True when Bloxy's "skip setup" box is ticked
	local function bloxySkipOn()
		local data = readJson(BLOXY_CONFIG)
		return data ~= nil and data.isSkipped == true
	end

	------------------------------------------------------------
	-- THE "MODERN R6" BUTTON ON BLOXY'S ANIMATIONS STEP (R15)
	------------------------------------------------------------
	-- Presses one of Bloxy's buttons the way a click would (Bloxy's handler plays the click sound and
	-- moves the wizard on). Returns false when this executor has no way to do it.
	local function press(btn)
		if not btn or not btn.Parent then return false end
		if firesignal then
			if pcall(firesignal, btn.MouseButton1Click) then return true end
		end
		if getconnections then
			local ok, conns = pcall(getconnections, btn.MouseButton1Click)
			if ok and type(conns) == "table" and #conns > 0 then
				local fired = false
				for _, conn in ipairs(conns) do
					local fn = conn.Function
					if fn then
						task.spawn(pcall, fn)
						fired = true
					elseif conn.Fire then
						if pcall(function() conn:Fire() end) then fired = true end
					end
				end
				if fired then return true end
			end
		end
		return false
	end

	-- Our own press of "Normal" runs the other buttons' handlers below too; they must not count
	-- as the player picking one of Bloxy's animations.
	local pressing = false

	local function findStepLabel(frame)
		for _, d in ipairs(frame:GetChildren()) do
			if d:IsA("TextLabel") and string.find(string.lower(d.Text or ""), STEP_TEXT, 1, true) then
				return d
			end
		end
		return nil
	end

	local function buttonWithText(frame, text)
		for _, d in ipairs(frame:GetChildren()) do
			if d:IsA("TextButton") and d.Text == text and d.Name ~= BUTTON_NAME then
				return d
			end
		end
		return nil
	end

	-- Same look as Bloxy's own wizard buttons
	local function makeButton(frame, reference)
		local btn = Instance.new("TextButton")
		btn.Name = BUTTON_NAME
		btn.Size = reference.Size
		btn.Position = reference.Position
		btn.Text = BUTTON_TEXT
		btn.Font = Enum.Font.Legacy
		btn.TextScaled = true
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		btn.BorderColor3 = Color3.fromRGB(0, 0, 0)
		btn.TextColor3 = Color3.fromRGB(0, 0, 0)
		btn.ZIndex = reference.ZIndex
		btn.Parent = frame

		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = 16
		constraint.MinTextSize = 8
		constraint.Parent = btn

		btn.MouseEnter:Connect(function()
			btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			btn.BorderColor3 = Color3.fromRGB(255, 0, 0)
		end)
		btn.MouseLeave:Connect(function()
			btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			btn.TextColor3 = Color3.fromRGB(0, 0, 0)
			btn.BorderColor3 = Color3.fromRGB(0, 0, 0)
		end)
		return btn
	end

	-- Returns true when the button is on (or the frame is not the R15 animations step at all)
	local function addButton(frame)
		if frame:FindFirstChild(BUTTON_NAME) then return true end
		if not findStepLabel(frame) then return false end

		local b2008 = buttonWithText(frame, "2008 FE")
		local b2014 = buttonWithText(frame, "2014 FE")
		local bOld = buttonWithText(frame, "Old R15")
		local bNormal = buttonWithText(frame, "Normal")
		if not (b2008 and b2014 and bOld and bNormal) then return false end

		local btn = makeButton(frame, bOld)

		-- Five buttons in the box that held four: 2008 FE, 2014 FE, Modern R6, Old R15, Normal
		local order = { b2008, b2014, btn, bOld, bNormal }
		local margin, gap = 10, 10
		local width = math.floor((frame.Size.X.Offset - margin * 2 - gap * (#order - 1)) / #order)
		local y = bOld.Position.Y.Offset
		for i, b in ipairs(order) do
			b.Size = UDim2.new(0, width, 0, b.Size.Y.Offset)
			b.Position = UDim2.new(0, margin + (i - 1) * (width + gap), 0, y)
		end

		-- Picking one of Bloxy's own: the modern R6 animation goes off
		for _, other in ipairs({ b2008, b2014, bOld, bNormal }) do
			other.MouseButton1Click:Connect(function()
				if pressing or not alive then return end
				saveChoice(false)
				engine.Stop()
			end)
		end

		local picked = false
		btn.MouseButton1Click:Connect(function()
			if picked or not alive then return end
			picked = true

			saveChoice(true)
			-- Bloxy only saves (doesn't run) when you re-configure with "skip" ticked
			if not bloxySkipOn() then engine.Start() end

			-- Moves the wizard on the way "Normal" does (no Bloxy animation script)
			pressing = true
			local pressed = press(bNormal)
			-- (Bloxy's handlers run at once, or a moment later in the same frame)
			task.delay(0.25, function() pressing = false end)
			if not pressed then
				warn("[Modern R6 Animation] Couldn't move the setup on: press Normal to continue (Modern R6 is picked).")
				picked = false
			end
		end)
		return true
	end

	local function checkFrame(frame)
		if not alive or handled[frame] or not frame:IsA("Frame") then return end
		handled[frame] = true
		-- Bloxy makes the box and then fills it in; give it a few frames
		task.spawn(function()
			for _ = 1, 30 do
				if not alive or not frame.Parent then return end
				if addButton(frame) then return end
				task.wait()
			end
		end)
	end

	local function watchBloxy(sg)
		if not (sg:IsA("ScreenGui") and sg.Name == BLOXY_GUI) or watched[sg] then return end
		watched[sg] = true
		connect(sg.AncestryChanged, function()
			if not sg.Parent then watched[sg] = nil end
		end)

		for _, frame in ipairs(sg:GetChildren()) do checkFrame(frame) end
		connect(sg.ChildAdded, checkFrame)

		-- "Skip setup" ticked: Bloxy applies its saved choices, we apply the saved modern R6 animation
		if bloxySkipOn() and loadChoice() then
			engine.Start()
		end
	end

	task.spawn(function()
		while not plr do
			task.wait()
			plr = Players.LocalPlayer
		end
		local pg = plr:WaitForChild("PlayerGui")

		-- Bloxy's GUI is normally in PlayerGui; some executors put GUIs in gethui() / CoreGui
		local containers = { pg }
		pcall(function()
			local hui = gethui and gethui()
			if hui and hui ~= pg then table.insert(containers, hui) end
		end)
		pcall(function()
			local _ = CoreGui:GetChildren()
			table.insert(containers, CoreGui)
		end)

		if not alive then return end
		for _, container in ipairs(containers) do
			pcall(function()
				for _, g in ipairs(container:GetChildren()) do watchBloxy(g) end
				connect(container.ChildAdded, watchBloxy)
			end)
		end
	end)

	print("[Modern R6 Animation] Installed. Saved choice: " .. (loadChoice() and "Modern R6" or "not Modern R6"))
end
