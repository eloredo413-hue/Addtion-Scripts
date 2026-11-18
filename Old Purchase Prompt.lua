--========================================================
-- OLD PURCHASE PROMPT (Addtion-Scripts)
-- The 2016 purchase prompt (PurchasePromptScript2 and PurchasePromptScript3, the real 2016 core scripts) in place of
-- Roblox's modern one, for the 2015-2019 GUIs. It uses the same method as the "Roblox 2016 UI - Remaster" script by
-- Invisible_: the 2016 GUI asset (rbxassetid://9139773381) is loaded with game:GetObjects, and its core scripts are
-- run from their Source. Only the purchase prompt is taken from it: everything else the asset draws is thrown away.
--
-- Roblox's own prompt is switched off (hidden, not deleted) only AFTER the old one has started without an error, so
-- if the old one cannot run in your executor, you keep Roblox's own prompt and nothing is lost. Stop brings it back.
-- Buying: the old prompt's Buy button buys the item the way Roblox's own prompt does (it spends real Robux for items
-- that cost Robux). Try it on a free item first.
--
-- Needs an executor that can run game:GetObjects, read a script's Source, and setfenv. The console says what it did.
-- Run alone: this file starts it. getgenv().OldPurchasePrompt: Start(), Stop(), Running(), Status()
--========================================================

local CoreGui = game:GetService("CoreGui")
local genv = (getgenv and getgenv()) or _G

-- an earlier run (this file run again) is stopped first
if type(genv.OldPurchasePrompt) == "table" and type(genv.OldPurchasePrompt.Stop) == "function" then
	pcall(genv.OldPurchasePrompt.Stop)
end

local ASSET = "rbxassetid://9139773381" -- the 2016 RobloxGui
local GUI_NAME = "OldPurchasePrompt"
local SCRIPTS = { "PurchasePromptScript2", "PurchasePromptScript3" }

local running = false
local status = "off"
local host = nil
local token = nil
local hiddenNative = {}      -- modern purchase GUIs switched off: gui -> { was }
local nativeConns = {}

local function guiHolder()
	local h = CoreGui
	pcall(function()
		if gethui then h = gethui() end
	end)
	return h
end

----------------------------------------------------------------------------------------------------
-- running the 2016 scripts from their Source
----------------------------------------------------------------------------------------------------
local baseEnv = (getfenv and getfenv()) or _G
local bakrequire = genv.bakrequire or require
local moduleCache, LOADING = {}, {}
local customRequire

-- the 2016 scripts ask for settings():GetFFlag(...) of flags the modern client no longer has (that throws): an
-- unknown flag reads as false instead
local function safeSettings()
	local real = nil
	pcall(function() real = (settings or Settings)() end)
	return setmetatable({}, {
		__index = function(_, key)
			if key == "GetFFlag" or key == "GetFVariable" then
				return function(_, name)
					local ok, value = pcall(function() return real[key](real, name) end)
					if ok then return value end
					return false
				end
			end
			if real then
				local value = real[key]
				if type(value) == "function" then
					return function(self, ...) return value(real, ...) end
				end
				return value
			end
			return nil
		end,
	})
end

local function makeEnv(scriptInst)
	return setmetatable({
		script = scriptInst,
		require = customRequire,
		settings = safeSettings,
		Settings = safeSettings,
	}, { __index = baseEnv })
end

local function ours(inst)
	return host ~= nil and inst:IsDescendantOf(host)
end

local function runSource(source, scriptInst, chunkName)
	local fn, err = loadstring(source, chunkName)
	if not fn then error("compile error in " .. chunkName .. ": " .. tostring(err), 0) end
	if setfenv then
		setfenv(fn, makeEnv(scriptInst))
	end
	return fn()
end

customRequire = function(inst)
	if typeof(inst) ~= "Instance" or not inst:IsA("ModuleScript") or not ours(inst) then
		return bakrequire(inst)
	end
	local entry = moduleCache[inst]
	if entry == LOADING then error("cyclic require: " .. inst:GetFullName(), 2) end
	if entry then return entry.value end
	moduleCache[inst] = LOADING
	local ok, value = pcall(runSource, inst.Source, inst, inst:GetFullName())
	if not ok then
		moduleCache[inst] = nil
		error(value, 0)
	end
	moduleCache[inst] = { value = value }
	return value
end

----------------------------------------------------------------------------------------------------
-- Roblox's modern purchase GUIs: switched off once the old prompt runs, back when it stops
----------------------------------------------------------------------------------------------------
local function isModernPrompt(inst)
	if inst == host then return false end
	if not (inst:IsA("ScreenGui") or inst:IsA("LayerCollector")) then return false end
	return string.find(string.lower(inst.Name), "purchase", 1, true) ~= nil
end

local function hideNative(inst)
	if hiddenNative[inst] or not isModernPrompt(inst) then return end
	hiddenNative[inst] = { was = inst.Enabled }
	pcall(function() inst.Enabled = false end)
	-- the app turns itself on when it has a prompt to show: kept off while the old prompt runs
	local c = inst:GetPropertyChangedSignal("Enabled"):Connect(function()
		if running and inst.Enabled then pcall(function() inst.Enabled = false end) end
	end)
	table.insert(nativeConns, c)
end

local function hideAllNative()
	for _, container in ipairs({ CoreGui, guiHolder() }) do
		pcall(function()
			for _, child in ipairs(container:GetChildren()) do hideNative(child) end
			table.insert(nativeConns, container.ChildAdded:Connect(function(child)
				task.defer(function()
					if running then hideNative(child) end
				end)
			end))
		end)
	end
end

local function showNative()
	for _, c in ipairs(nativeConns) do pcall(function() c:Disconnect() end) end
	nativeConns = {}
	for inst, rec in pairs(hiddenNative) do
		pcall(function() if inst.Parent then inst.Enabled = rec.was end end)
	end
	hiddenNative = {}
end

----------------------------------------------------------------------------------------------------
-- on and off
----------------------------------------------------------------------------------------------------
local api = {}

function api.Stop()
	if not running then return end
	running = false
	token = nil
	showNative()
	if host then pcall(function() host:Destroy() end) end
	host = nil
	moduleCache = {}
	status = "off"
	if genv.OldPurchasePromptStop == api.Stop then genv.OldPurchasePromptStop = nil end
	print("[Old Purchase Prompt] off: Roblox's own prompt is back. (The old prompt's listeners stay until you rejoin.)")
end

function api.Start()
	if running then return end
	running = true
	status = "loading"
	local mine = {}
	token = mine

	local okObjects, objs = pcall(function() return game:GetObjects(ASSET) end)
	if token ~= mine then return end -- stopped while it loaded
	if not okObjects or type(objs) ~= "table" or not objs[1] then
		running, status = false, "failed: the 2016 GUI asset did not load (" .. tostring(objs) .. ")"
		warn("[Old Purchase Prompt] " .. status .. ". Roblox's own prompt is kept.")
		return
	end

	-- only what the purchase scripts need: the Modules and the script sources; everything the asset draws goes
	local root = objs[1]
	local modules = root:FindFirstChild("Modules")
	local syn = root:FindFirstChild("CoreScriptSyn")
	if not (modules and syn) then
		running, status = false, "failed: the 2016 GUI asset has no Modules / CoreScriptSyn"
		warn("[Old Purchase Prompt] " .. status .. ". Roblox's own prompt is kept.")
		return
	end
	for _, child in ipairs(root:GetChildren()) do
		if child ~= modules and child ~= syn then pcall(function() child:Destroy() end) end
	end
	root.Name = GUI_NAME
	root.ResetOnSpawn = false
	root.DisplayOrder = 1100
	host = root
	root.Parent = guiHolder()

	local started, errors, promptStarted = 0, {}, false
	for _, name in ipairs(SCRIPTS) do
		local src = syn:FindFirstChild(name)
		if not src then
			table.insert(errors, name .. ": not in the asset")
		else
			local fake = Instance.new("LocalScript")
			fake.Name = "CoreScripts/" .. name
			fake.Disabled = true
			fake.Parent = root
			local ok, err = pcall(runSource, tostring(src.Source), fake, "CoreScripts/" .. name)
			if ok then
				started = started + 1
				if name == SCRIPTS[1] then promptStarted = true end
			else
				table.insert(errors, name .. ": " .. tostring(err))
			end
		end
	end
	if token ~= mine then return end

	for _, e in ipairs(errors) do warn("[Old Purchase Prompt] " .. e) end
	-- PurchasePromptScript2 is the prompt itself: without it, nothing is switched off
	if not promptStarted then
		pcall(function() root:Destroy() end)
		host = nil
		running, status = false, "failed: the 2016 prompt did not start"
		warn("[Old Purchase Prompt] " .. status .. ". Roblox's own prompt is kept.")
		return
	end
	hideAllNative()
	status = "on"
	genv.OldPurchasePromptStop = api.Stop
	print("[Old Purchase Prompt] on: " .. started .. " of " .. #SCRIPTS .. " 2016 scripts started; Roblox's own prompt is hidden.")
end

function api.Running()
	return running and status == "on"
end

function api.Status()
	return status
end

genv.OldPurchasePrompt = api
task.spawn(api.Start)
