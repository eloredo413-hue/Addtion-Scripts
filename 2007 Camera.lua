--========================================================
-- 2007 CAMERA (Addtion-Scripts)
-- Retro Studio's 2007 CameraScript, made to run from a script executor. That script runs the old (2016) camera
-- modules and switches on their Follow camera. An executor doesn't have those modules, so this runs the old camera
-- of this repo (Retro Camera.lua, the "2013 Camera": the old camera code in place of Roblox's own) with that same
-- FollowCamera switched on:
--   * as you walk, the camera swings round behind you
--   * dragging to look around stops that for 2 seconds, then it follows again
--   * small sideways steps are let through, so it doesn't twitch; never in first person
-- (Just switching Roblox's own camera to Follow, as the original does, changes nothing on a phone: there Roblox's
-- camera is already Follow.)
-- Run alone or from the physics / camera step ("2007 Camera").
--========================================================

local URL = "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/Retro%20Camera.lua"

local ok, src = pcall(function() return game:HttpGet(URL, true) end)
if not ok or type(src) ~= "string" or #src < 100 then
	warn("[2007 Camera] couldn't download the old camera: " .. tostring(src))
	return
end
local fn, err = loadstring('local CAMERA_ERA = "2007"\n' .. src, "2007 Camera")
if not fn then
	warn("[2007 Camera] the old camera didn't compile: " .. tostring(err))
	return
end
fn()
print("[2007 Camera] on: the old camera, following behind you as you walk.")
