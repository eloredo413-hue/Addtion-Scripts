-- (Addtion-Scripts) Hammer stuff 2's "pre-2018 camera" loads this file; unticking calls
-- getgenv().LegacyZoomStop(), which gives the game's camera back.
--[[
	LEGACY ZOOM  -  the scroll-wheel zoom from before the 2018 camera update. Client side only.

	* No smoothing: the camera jumps straight to the new distance on every wheel click, and snaps back
	  at once when a wall stops being in the way.
	* Old step size: each click moves the camera by the old amount (a small step up close, a bigger one
	  far away), instead of the modern x1.5 per click.
	* Run it again to replace the previous run. It prints what it managed to switch on.

	It works by reaching into Roblox's own camera scripts (PlayerModule), so it needs an executor with
	getgc or require, and it does nothing in a game that uses a fully custom camera.
]]

local Settings = {
	NoSmoothing  = true, -- jump to the new zoom instead of gliding there
	ClassicSteps = true, -- old step size per wheel click
	StepSpeed    = 1.4,  -- the old camera's wheel speed. Higher = bigger steps
}

----------------------------------------------------------------------------------------------------
local genv = (getgenv and getgenv()) or _G
if type(genv.LegacyZoomStop) == "function" then
	pcall(genv.LegacyZoomStop)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local stopped = false
local undo = {}
local goal = nil -- the zoom distance the game's camera is aiming for (studs)

----------------------------------------------------------------------------------------------------
-- the old camera's step: one wheel click = this integrator run for one "second" at speed 1.4
----------------------------------------------------------------------------------------------------
local function classicStep(position, velocity)
	local t = 1
	local direction = velocity < 0 and -1 or 1
	local function acceleration(p)
		return direction * math.max(1, (p / 3.3) + 0.5)
	end
	local p1 = position
	local v1 = velocity
	local a1 = acceleration(p1)
	local p2 = p1 + v1 * (t / 2)
	local v2 = v1 + a1 * (t / 2)
	local a2 = acceleration(p2)
	local p3 = p1 + v2 * (t / 2)
	local v3 = v1 + a2 * (t / 2)
	local a3 = acceleration(p3)
	local v4 = v1 + a3 * t
	return position + (v1 + 2 * v2 + 2 * v3 + v4) * (t / 6)
end

----------------------------------------------------------------------------------------------------
-- find the game's live camera modules
----------------------------------------------------------------------------------------------------
local function isZoomModule(t)
	return type(rawget(t, "SetZoomParameters")) == "function"
		and type(rawget(t, "GetZoomRadius")) == "function"
		and type(rawget(t, "Update")) == "function"
end

local function isInputModule(t)
	return type(rawget(t, "getZoomDelta")) == "function" and type(rawget(t, "getRotation")) == "function"
end

local zoomModules, inputModules = {}, {}
local seen = {}

local function consider(t)
	if type(t) ~= "table" or seen[t] then return end
	local okZ, z = pcall(isZoomModule, t)
	local okI, i = pcall(isInputModule, t)
	if okZ and z then
		seen[t] = true
		zoomModules[#zoomModules + 1] = t
	elseif okI and i then
		seen[t] = true
		inputModules[#inputModules + 1] = t
	end
end

if getgc then -- the tables the game itself is using
	local okGc, objects = pcall(getgc, true)
	if okGc and type(objects) == "table" then
		for _, t in ipairs(objects) do
			consider(t)
		end
	end
end

if #zoomModules == 0 or #inputModules == 0 then -- fall back to requiring them
	pcall(function()
		local scripts = player:FindFirstChildOfClass("PlayerScripts")
		local cameraModule = scripts and scripts:FindFirstChild("PlayerModule") and scripts.PlayerModule:FindFirstChild("CameraModule")
		if not cameraModule then return end
		for _, name in ipairs({"ZoomController", "CameraInput"}) do
			local m = cameraModule:FindFirstChild(name)
			if m then
				local okReq, t = pcall(require, m)
				if okReq then consider(t) end
			end
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- hooks
----------------------------------------------------------------------------------------------------
local function currentZoom()
	if type(goal) == "number" then return goal end
	for _, Zoom in ipairs(zoomModules) do
		local ok, z = pcall(Zoom.GetZoomRadius)
		if ok and type(z) == "number" then return z end
	end
	return nil
end

local smoothingOff, stepsOn = 0, 0

for _, Zoom in ipairs(zoomModules) do
	local origSet = rawget(Zoom, "SetZoomParameters")
	local origUpdate = rawget(Zoom, "Update")
	local release = rawget(Zoom, "ReleaseSpring")

	-- remember what distance the camera is told to go to
	local okSet = pcall(function()
		Zoom.SetZoomParameters = function(targetZoom, ...)
			if type(targetZoom) == "number" then goal = targetZoom end
			return origSet(targetZoom, ...)
		end
	end)
	if okSet then
		undo[#undo + 1] = function() Zoom.SetZoomParameters = origSet end
	end

	if Settings.NoSmoothing then
		-- the modern camera glides to the target with a spring. Put the spring on its target before every
		-- update (or, where that helper is missing, run the spring for a very long step so it arrives at once).
		-- Walls still push the camera in, exactly like before.
		local okUpdate = pcall(function()
			Zoom.Update = function(renderDt, ...)
				if stopped then return origUpdate(renderDt, ...) end
				if type(release) == "function" then
					release()
					return origUpdate(renderDt, ...)
				end
				return origUpdate(1000, ...)
			end
		end)
		if okUpdate then
			undo[#undo + 1] = function() Zoom.Update = origUpdate end
			smoothingOff += 1
		elseif type(release) == "function" then
			-- the module cannot be edited: snap the spring just before the camera updates instead
			local name = "LegacyZoomRelease" .. tostring(#undo)
			local okBind = pcall(function()
				RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value - 1, function()
					if not stopped then pcall(release) end
				end)
			end)
			if okBind then
				undo[#undo + 1] = function() RunService:UnbindFromRenderStep(name) end
				smoothingOff += 1
			end
		end
	end
end

if Settings.ClassicSteps then
	-- The modern camera turns a wheel click into "delta = 1" and then uses
	--     out: new = zoom + delta * (1 + zoom * 0.5)      in: new = (zoom + delta) / (1 - delta * 0.5)
	-- Work out the old step, then hand back the delta that makes the modern formula land exactly on it.
	local CURVATURE = 0.5
	for _, Input in ipairs(inputModules) do
		local orig = rawget(Input, "getZoomDelta")
		local okHook = pcall(function()
			Input.getZoomDelta = function(...)
				local raw = orig(...)
				if stopped or type(raw) ~= "number" or math.abs(raw) < 0.5 then
					return raw -- nothing, the I/O keys or a pinch: left alone
				end
				local zoom = currentZoom()
				if type(zoom) ~= "number" then return raw end
				local direction = raw > 0 and 1 or -1 -- + = zoom out
				local clicks = math.clamp(math.floor(math.abs(raw) + 0.5), 1, 6)
				local target = zoom
				for _ = 1, clicks do
					target = classicStep(target, direction * Settings.StepSpeed)
				end
				target = math.max(target, 0.5)
				if direction > 0 then
					return (target - zoom) / (1 + zoom * CURVATURE)
				end
				return (target - zoom) / (1 + target * CURVATURE)
			end
		end)
		if okHook then
			undo[#undo + 1] = function() Input.getZoomDelta = orig end
			stepsOn += 1
		end
	end
end

----------------------------------------------------------------------------------------------------
local function stop()
	stopped = true
	for i = #undo, 1, -1 do
		pcall(undo[i])
	end
	if genv.LegacyZoomStop == stop then genv.LegacyZoomStop = nil end
end
genv.LegacyZoomStop = stop

local function yesNo(wanted, count)
	if not wanted then return "off in Settings" end
	return count > 0 and "ON" or "could NOT be switched on"
end

print("[LegacyZoom] camera modules found: zoom " .. #zoomModules .. ", input " .. #inputModules
	.. " | no smoothing: " .. yesNo(Settings.NoSmoothing, smoothingOff)
	.. " | classic steps: " .. yesNo(Settings.ClassicSteps, stepsOn))
if #zoomModules == 0 and #inputModules == 0 then
	print("[LegacyZoom] Roblox's camera scripts were not found. The game uses its own camera, or the executor has neither getgc nor require.")
end
