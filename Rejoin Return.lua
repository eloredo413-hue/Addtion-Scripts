-- [[ REJOIN RETURN — Bloxy and the loader back after an FFlags GUI's rejoin ]]
-- The 2021 / 2023 old / 2023 new GUIs (and Bloxy's own "2024(fflags)") set Roblox flags and rejoin the game. In the server
-- they rejoin, only the GUI came back: Bloxy and this repo's loader were gone, so nothing could be changed any more.
-- The loader adds a line to whatever such a GUI queues for after the rejoin; that line runs this file there. It:
--   * starts Bloxy again (the copy of Bloxy's script remembered the last time Bloxy was run), then this repo's loader
--     ("Script") once Bloxy's GUI is up, the order they are normally run in: the hammer, the floppy disk, the setup
--     and the rest are all there to change things;
--   * keeps Bloxy from loading its saved topbar again while it starts ("skip setup" ticked): that GUI is already here,
--     and loading it again would rejoin again, and again;
--   * remembers Bloxy's script whenever Bloxy is run through loadstring here (BloxyParadoxScript.lua). The first time,
--     when no copy is remembered yet, run Bloxy once by hand after the rejoin: the loader follows by itself, and from
--     then on both come back on their own.
-- Runs once per server.
local Env = (getgenv and getgenv()) or _G
if Env.BPRejoinReturnStarted then return end
Env.BPRejoinReturnStarted = true

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local BLOXY_FILE = "BloxyParadoxScript.lua"
local CONFIG_FILE = "BloxyParadoxConfig.json"
local BLOXY_GUI = "BloxyParadoxProject"
local LOADER_URL = "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/Script"
local SIG_2023 = "111872120766790" -- Bloxy's 2023 topbar (the one More guis' 2017 - 2024 GUIs ride on)
local QUIET_AFTER = 10 -- seconds after Bloxy's GUI is up that its own topbar load is still held back

local guiHere = tostring(Env.BP_RejoinGui or "")
if guiHere == "" then guiHere = "FFlags" end

local function say(text) print("[Rejoin Return] " .. text) end

local function has(code, text) return string.find(code, text, 1, true) ~= nil end

-- Bloxy's own script (not one of this repo's, which name Bloxy's GUI too)
local function isBloxyMain(code)
	return #code > 20000 and has(code, BLOXY_GUI) and has(code, CONFIG_FILE) and not has(code, "Addtion")
end

-- a topbar Bloxy loads by itself as it starts: its 2023 one, or one that rejoins (queues code and teleports)
local function isTopbarAgain(code)
	if has(code, "Addtion") then return false end
	if has(code, SIG_2023) then return true end
	return (has(code, "queue_on_teleport") or has(code, "queue_teleport"))
		and (has(code, ":Teleport(") or has(code, ":TeleportToPlaceInstance("))
end

local function skipSetupOn()
	local ok, on = pcall(function()
		if not (isfile and readfile and isfile(CONFIG_FILE)) then return false end
		local cfg = HttpService:JSONDecode(readfile(CONFIG_FILE))
		return type(cfg) == "table" and cfg.isSkipped == true
	end)
	return ok and on == true
end

local realLoad = Env.loadstring or loadstring
local quietUntil = 0
local bloxyStarted = false
local loaderStarted = false

local function startLoader()
	if loaderStarted then return end
	loaderStarted = true
	say("Bloxy is up: starting the loader")
	local ok, err = pcall(function()
		local src = game:HttpGet(LOADER_URL)
		local fn = assert(realLoad(src, "Script"))
		fn()
	end)
	if not ok then warn("[Rejoin Return] the loader didn't start: " .. tostring(err)) end
end

local function afterBloxy()
	local player = Players.LocalPlayer
	while not player do task.wait() player = Players.LocalPlayer end
	local playerGui = player:WaitForChild("PlayerGui", 30)
	local gui = playerGui and playerGui:WaitForChild(BLOXY_GUI, 60)
	if quietUntil == math.huge then quietUntil = os.clock() + QUIET_AFTER end
	if not gui then
		warn("[Rejoin Return] Bloxy's GUI didn't come up: the loader isn't started")
		return
	end
	task.wait(0.5)
	startLoader()
end

local function bloxyComing()
	if bloxyStarted then return end
	bloxyStarted = true
	-- ("skip setup" ticked: Bloxy loads its saved topbar as it starts; that GUI is already here)
	if skipSetupOn() then quietUntil = math.huge end
	task.spawn(afterBloxy)
end

local function hooked(code, name)
	if type(code) == "string" then
		if isBloxyMain(code) then
			if writefile then pcall(writefile, BLOXY_FILE, code) end
			say("Bloxy's script remembered: after the next rejoin it starts by itself")
			bloxyComing()
		elseif os.clock() < quietUntil and isTopbarAgain(code) then
			say("Bloxy's saved topbar isn't loaded again: the " .. guiHere .. " GUI is already here (no second rejoin)")
			return function() end
		end
	end
	return realLoad(code, name)
end
pcall(function() Env.loadstring = hooked end)
pcall(function() _G.loadstring = hooked end)

task.spawn(function()
	-- (what is queued for after a rejoin runs while the new server is still loading, on the teleport screen: Bloxy
	-- waits until the game has loaded and the character is in it, so it shows right after the rejoin, the user asked)
	pcall(function()
		if not game:IsLoaded() then game.Loaded:Wait() end
	end)
	pcall(function()
		local player = Players.LocalPlayer
		while not player do task.wait() player = Players.LocalPlayer end
		if not player.Character then player.CharacterAdded:Wait() end
		local char = player.Character
		if char then char:WaitForChild("HumanoidRootPart", 15) end
	end)
	task.wait(1)
	local src = nil
	pcall(function()
		if isfile and readfile and isfile(BLOXY_FILE) then src = readfile(BLOXY_FILE) end
	end)
	if type(src) == "string" and #src > 0 then
		say("after the " .. guiHere .. " GUI's rejoin: starting Bloxy again, then the loader")
		bloxyComing()
		local fn, err = realLoad(src, "Bloxy")
		if fn then
			local ok, runErr = pcall(fn)
			if not ok then warn("[Rejoin Return] Bloxy stopped with an error: " .. tostring(runErr)) end
		else
			warn("[Rejoin Return] the remembered copy of Bloxy doesn't load (" .. tostring(err) .. "): run Bloxy again by hand")
		end
	else
		-- (no message on screen, the user asked: only the console says it)
		say("no copy of Bloxy remembered yet: run Bloxy now, and the loader follows by itself")
	end
end)
