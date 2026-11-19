--========================================================
-- 2007 CAMERA (Addtion-Scripts)
-- The camera from Retro Studio's 2007 CameraScript, made to run from a script executor. That script loads the
-- 2016 camera modules (RootCamera: ClassicCamera, FollowCamera and so on) and then, at its very end, turns the
-- camera to Follow and keeps it there. An executor doesn't have those modules, but Roblox's own camera still has
-- the same Follow camera built in: this file turns it on and keeps it on, like the original does.
--   * the camera swings round behind you as you walk, instead of staying where you left it
--   * you can still drag (or right-click drag) to look around, and zoom as usual
-- Unlike the original, only the normal player camera is changed: a game that takes the camera over for a cutscene
-- or a menu (Scriptable and the like) keeps it, and Follow comes back when the game gives the camera back.
--
-- Run alone or from the physics / camera step. getgenv().Camera2007Stop() gives the normal camera back.
--========================================================

local genv = (getgenv and getgenv()) or _G
if type(genv.Camera2007Stop) == "function" then
	pcall(genv.Camera2007Stop)
end

local Workspace = game:GetService("Workspace")

local FOLLOW = Enum.CameraType.Follow
local CUSTOM = Enum.CameraType.Custom

local stopped = false
local typeConn, cameraConn = nil, nil
local held = nil -- the camera it changed

local function keep(cam)
	if stopped or not cam then return end
	if cam.CameraType == CUSTOM then
		pcall(function() cam.CameraType = FOLLOW end)
	end
end

local function watch(cam)
	if typeConn then typeConn:Disconnect() typeConn = nil end
	held = cam
	if not cam then return end
	keep(cam)
	typeConn = cam:GetPropertyChangedSignal("CameraType"):Connect(function()
		keep(cam)
	end)
end

cameraConn = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	watch(Workspace.CurrentCamera)
end)
watch(Workspace.CurrentCamera)

genv.Camera2007Stop = function()
	if stopped then return end
	stopped = true
	if typeConn then typeConn:Disconnect() typeConn = nil end
	if cameraConn then cameraConn:Disconnect() cameraConn = nil end
	if held and held.CameraType == FOLLOW then
		pcall(function() held.CameraType = CUSTOM end)
	end
	held = nil
	genv.Camera2007Stop = nil
	print("[2007 Camera] off: the normal camera is back.")
end

print("[2007 Camera] on: the Follow camera (it swings round behind you as you walk).")
