--========================================================
-- OLD PURCHASE PROMPT (Addtion-Scripts)
-- The 2016 purchase prompt (PurchasePromptScript2 and PurchasePromptScript3, the real 2016 core scripts) in place of
-- Roblox's modern one, for the 2013-2019 GUIs. It uses the same method as the "Roblox 2016 UI - Remaster" script by
-- Invisible_: the 2016 GUI asset (rbxassetid://9139773381) is loaded with game:GetObjects, and its core scripts are
-- run from their Source. Only the purchase prompt is taken from it: everything else the asset draws is thrown away.
--
-- How a purchase goes:
--   * Roblox's own prompt is kept hidden. When a game asks for a purchase, the request is handed to a fresh copy of
--     the 2016 prompt scripts (so one purchase can never leave them stuck for the next).
--   * The request is heard from Roblox's purchase events, the old ones and the newer "V2" ones (the 2016 scripts only
--     know the old ones, and the modern client may only send the new ones: that is why the old prompt never showed).
--   * Buy (or Buy Robux) in the old prompt: the old prompt goes and Roblox's own prompt is shown for the same item, so
--     the purchase is made by Roblox (the 2016 prompt's own way of buying no longer exists). Cancel: both close.
--   * Never stuck: game passes, bundles, Premium and the like (which the 2016 prompt doesn't know) go straight to
--     Roblox's prompt; if the old prompt hasn't shown 4 s after a request, Roblox's prompt is shown; and if Roblox's
--     prompt opens for a purchase no event told us about, it is shown too.
-- The 2014 GUI gets the 2014 prompt instead (getgenv().OldPurchasePromptStyle = "2014", set by the loader): Roblox's
-- 2014 PurchasePromptScript (CoreScripts/2014 in this repo, the one the user gave), run from its source the same way:
-- the grey "Buy Item" box with "Would you like to buy the <item> <type> for R$<price>?", the item's picture, and the
-- Buy Now / Cancel buttons. Changed in it only where 2014's web calls are gone: the item's picture is Roblox's
-- thumbnail, "already own it" is asked with PlayerOwnsAsset, its balance line is left empty (the client can't know
-- your Robux), its own buying is switched off (Buy goes on in Roblox's prompt, as above), and its LoadLibrary
-- ("RbxUtility") JSON reader is the HttpService's.
-- Needs an executor that can run game:GetObjects, read a script's Source, and setfenv. The console says what it did.
-- Run alone: this file starts it. getgenv().OldPurchasePrompt: Start(), Stop(), Running(), Status(), Style()
--========================================================

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RealMarket = game:GetService("MarketplaceService")
local genv = (getgenv and getgenv()) or _G

-- an earlier run (this file run again) is stopped first
if type(genv.OldPurchasePrompt) == "table" and type(genv.OldPurchasePrompt.Stop) == "function" then
	pcall(genv.OldPurchasePrompt.Stop)
end

local ASSET = "rbxassetid://9139773381" -- the 2016 RobloxGui
local SOURCE_2014 = "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/CoreScripts/2014/PurchasePromptScript.lua"
local DIALOG_NAMES = { PurchaseDialog = true, PurchaseFrame = true } -- the 2016 dialog, the 2014 one
local GUI_NAME = "OldPurchasePrompt"
local SCRIPTS = { "PurchasePromptScript2", "PurchasePromptScript3" }
local WATCHDOG_SECONDS = 4 -- (the 2016 prompt looks the item up on the web first)

-- the requests the 2016 scripts know (they listen for these names)
local OLD_EVENTS = { "PromptPurchaseRequested", "PromptProductPurchaseRequested" }
-- the client's request events, and what each is for the 2016 scripts (nil: the 2016 prompt doesn't know it)
local REQUEST_EVENTS = {
	PromptPurchaseRequested = "PromptPurchaseRequested",
	PromptPurchaseRequestedV2 = "PromptPurchaseRequested",
	PromptProductPurchaseRequested = "PromptProductPurchaseRequested",
	PromptProductPurchaseRequestedV2 = "PromptProductPurchaseRequested",
	PromptGamePassPurchaseRequested = false,
	PromptBundlePurchaseRequested = false,
	PromptPremiumPurchaseRequested = false,
	PromptSubscriptionPurchaseRequested = false,
	PromptRobloxPurchaseRequested = false,
	PromptBulkPurchaseRequested = false,
	PromptCollectiblesPurchaseRequested = false,
}
local FINISHED_EVENTS = { "PromptPurchaseFinished", "PromptProductPurchaseFinished", "PromptGamePassPurchaseFinished", "PromptBundlePurchaseFinished" }

local running = false
local status = "off"
local host, modules, syn = nil, nil, nil
local token = nil
local hiddenNative = {}      -- modern purchase GUIs switched off: gui -> { was }
local nativeConns = {}
local requestConns = {}
local runConns = {}          -- connections for the current 2016 prompt (its buttons)
local fakeSignals = {}       -- the request events the 2016 scripts listen to: name -> BindableEvent
local watchdog = nil
local nativeShown = false    -- Roblox's own prompt given back for the purchase going on
local lastRequestAt = -100
local lastFed = { key = nil, at = -100 }
local style = "2016"         -- "2014": the 2014 prompt (its own source), "2016": the 2016 GUI asset's
local source2014 = nil       -- the 2014 PurchasePromptScript, made to run here (see patch2014)
local oldHeldHidden = nil    -- the old dialog, kept hidden after Buy / Cancel until the next purchase
local requests, fallbacks, handoffs = 0, 0, 0

-- what happens goes to the console only (no on-screen message)
local function say(text)
	print("[Old Purchase Prompt] " .. text)
end

local function guiHolder()
	local h = CoreGui
	pcall(function()
		if gethui then h = gethui() end
	end)
	return h
end

----------------------------------------------------------------------------------------------------
-- what the 2016 scripts see: the real game, except that MarketplaceService's request events are our own (fed from
-- the real ones, old and new), so a request always reaches them in the form they know
----------------------------------------------------------------------------------------------------
local function fakeSignal(name)
	local be = fakeSignals[name]
	if not be then
		be = Instance.new("BindableEvent")
		fakeSignals[name] = be
	end
	return be.Event
end

local KNOWN_FAKE = {}
for _, name in ipairs(OLD_EVENTS) do KNOWN_FAKE[name] = true end
KNOWN_FAKE.PromptGamePassPurchaseRequested = true
KNOWN_FAKE.PromptBundlePurchaseRequested = true
-- (the 2014 script listens for these too; they never fire here)
KNOWN_FAKE.ServerPurchaseVerification = true
KNOWN_FAKE.NativePurchaseFinished = true
KNOWN_FAKE.ClientLuaDialogRequested = true
-- what the old scripts tell Roblox when they close (only a core script may): nothing happens
local SILENT_CALLS = {
	SignalPromptPurchaseFinished = true, SignalPromptProductPurchaseFinished = true, SignalClientPurchaseSuccess = true,
	SignalServerLuaDialogClosed = true, PromptNativePurchase = true, SignalPromptGamePassPurchaseFinished = true,
}

local fakeMarket = setmetatable({}, {
	__index = function(_, key)
		if KNOWN_FAKE[key] then return fakeSignal(key) end
		if SILENT_CALLS[key] then return function() end end
		local value = RealMarket[key]
		if type(value) == "function" then
			return function(_, ...) return value(RealMarket, ...) end
		end
		return value
	end,
	__tostring = function() return "MarketplaceService" end,
})

-- a stand-in for a service (asked for only when the 2014 prompt uses it): its own fields first, the real service's
-- for the rest (methods called on the real one)
local function proxyService(serviceName, own, readOnly)
	local function real() return game:GetService(serviceName) end
	return setmetatable({}, {
		__index = function(_, key)
			if own[key] ~= nil then return own[key] end
			local service = real()
			local value = service[key]
			if type(value) == "function" then
				return function(_, ...) return value(service, ...) end
			end
			return value
		end,
		__newindex = function(_, key, value)
			if readOnly and readOnly[key] then return end
			real()[key] = value
		end,
		__tostring = function() return serviceName end,
	})
end

local fakeCoreGui = setmetatable({}, {
	__index = function(_, key)
		if key == "RobloxGui" then return host end
		if key == "FindFirstChild" or key == "WaitForChild" then
			return function(_, name, ...)
				if name == "RobloxGui" then return host end
				return CoreGui[key](CoreGui, name, ...)
			end
		end
		local value = CoreGui[key]
		if type(value) == "function" then return function(_, ...) return value(CoreGui, ...) end end
		return value
	end,
	__tostring = function() return "CoreGui" end,
})
local fakeGuiService = proxyService("GuiService", {
	-- (only core scripts may ask for the center of the screen: shown at once, and nothing to take back)
	AddCenterDialog = function(_, _dialog, _kind, show) if show then show() end end,
	RemoveCenterDialog = function() end,
	OpenBrowserWindow = function() end,
})
local fakeInput = proxyService("UserInputService", {}, { ModalEnabled = true })
local fakeContent = proxyService("ContentProvider", {
	Preload = function() end,
	BaseUrl = "https://www.roblox.com/",
})

local function serviceFor(name)
	if name == "MarketplaceService" then return fakeMarket end
	if style == "2014" then
		if name == "CoreGui" then return fakeCoreGui end
		if name == "GuiService" then return fakeGuiService end
		if name == "UserInputService" then return fakeInput end
		if name == "ContentProvider" then return fakeContent end
	end
	return game:GetService(name)
end

-- the 2014 script's web calls (those addresses are gone): whether you own the item, from PlayerOwnsAsset; the
-- balance: the client can't know it, so enough for anything (the balance line is left empty, see patch2014)
local function httpGet2014(_, url)
	url = tostring(url)
	if string.find(url, "ownership/hasAsset", 1, true) then
		local assetId = tonumber(string.match(url, "assetId=(%d+)"))
		local owns = false
		pcall(function() owns = RealMarket:PlayerOwnsAsset(Players.LocalPlayer, assetId) end)
		return owns and "true" or "false"
	end
	if string.find(url, "currency/balance", 1, true) then
		return '{"robux":999999999,"tickets":999999999}'
	end
	error("the 2014 prompt's web call isn't available: " .. url, 0)
end

local fakeGame = setmetatable({}, {
	__index = function(_, key)
		if key == "GetService" or key == "getService" or key == "service" or key == "FindService" then
			return function(_, name) return serviceFor(name) end
		end
		if key == "MarketplaceService" then return fakeMarket end
		if style == "2014" then
			if key == "CoreGui" or key == "GuiService" or key == "UserInputService" or key == "ContentProvider" then
				return serviceFor(key)
			end
			if key == "FindFirstChild" then
				return function(_, name, ...)
					if name == "CoreGui" then return fakeCoreGui end
					return game:FindFirstChild(name, ...)
				end
			end
			if key == "HttpGetAsync" or key == "HttpGet" then return httpGet2014 end
			if key == "HttpPostAsync" then
				return function() error("the 2014 prompt's own buying is off here", 0) end
			end
		end
		local value = game[key]
		if type(value) == "function" then
			return function(_, ...) return value(game, ...) end
		end
		return value
	end,
	__tostring = function() return "Game" end,
})

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

-- LoadLibrary("RbxUtility"), which the 2014 script reads JSON with, is gone: the HttpService's reader
local function loadLibrary(name)
	if name == "RbxUtility" then
		local http = game:GetService("HttpService")
		return {
			DecodeJSON = function(text)
				local ok, value = pcall(function() return http:JSONDecode(text) end)
				return ok and value or nil
			end,
			EncodeJSON = function(value) return http:JSONEncode(value) end,
		}
	end
	error("LoadLibrary " .. tostring(name) .. " isn't available", 0)
end

local function makeEnv(scriptInst)
	return setmetatable({
		LoadLibrary = loadLibrary,
		ypcall = pcall,
		script = scriptInst,
		require = customRequire,
		settings = safeSettings,
		Settings = safeSettings,
		game = fakeGame,
		Game = fakeGame,
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

-- the old dialog (PurchaseDialog) of the current run
local function findDialog()
	if not host then return nil end
	for _, d in ipairs(host:GetDescendants()) do
		if DIALOG_NAMES[d.Name] and d:IsA("GuiObject") then return d end
	end
	return nil
end

local function dialogVisible()
	local dialog = findDialog()
	return dialog ~= nil and dialog.Visible == true
end

-- a fresh run of the 2016 scripts: what the last run made is removed first, so its state (a purchase it is still
-- "prompting", an error box waiting for OK) never blocks the next purchase
local function clearRun()
	for _, c in ipairs(runConns) do pcall(function() c:Disconnect() end) end
	runConns = {}
	for _, be in pairs(fakeSignals) do pcall(function() be:Destroy() end) end
	fakeSignals = {}
	moduleCache = {}
	oldHeldHidden = nil
	if host then
		for _, child in ipairs(host:GetChildren()) do
			if child ~= modules and child ~= syn then pcall(function() child:Destroy() end) end
		end
	end
end

local function runScripts()
	clearRun()
	if style == "2014" then
		local fake = Instance.new("LocalScript")
		fake.Name = "CoreScripts/PurchasePromptScript"
		fake.Disabled = true
		fake.Parent = host
		local ok, err = pcall(runSource, source2014, fake, "CoreScripts/PurchasePromptScript")
		if ok then return 1, {}, true end
		return 0, { "PurchasePromptScript (2014): " .. tostring(err) }, false
	end
	local robloxGui = CoreGui:FindFirstChild("RobloxGui")
	local before = {}
	if robloxGui then
		for _, d in ipairs(robloxGui:GetChildren()) do before[d] = true end
	end
	local started, errors, promptStarted = 0, {}, false
	for _, name in ipairs(SCRIPTS) do
		local src = syn:FindFirstChild(name)
		if not src then
			table.insert(errors, name .. ": not in the asset")
		else
			local fake = Instance.new("LocalScript")
			fake.Name = "CoreScripts/" .. name
			fake.Disabled = true
			fake.Parent = host
			local ok, err = pcall(runSource, tostring(src.Source), fake, "CoreScripts/" .. name)
			if ok then
				started = started + 1
				if name == SCRIPTS[1] then promptStarted = true end
			else
				table.insert(errors, name .. ": " .. tostring(err))
			end
		end
	end
	-- a dialog the scripts put in Roblox's own RobloxGui (which some GUIs switch off) is brought here
	if robloxGui then
		for _, d in ipairs(robloxGui:GetChildren()) do
			if not before[d] and d.Name == "PurchaseDialog" then pcall(function() d.Parent = host end) end
		end
	end
	return started, errors, promptStarted
end

----------------------------------------------------------------------------------------------------
-- Roblox's modern purchase GUIs: kept hidden, given back when the old prompt can't do a purchase
----------------------------------------------------------------------------------------------------
local onNativeActivity -- (below)

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
	table.insert(nativeConns, inst:GetPropertyChangedSignal("Enabled"):Connect(function()
		if running and not nativeShown and inst.Enabled then pcall(function() inst.Enabled = false end) end
	end))
	-- a prompt opening in it: if no request told us about it, it is shown
	table.insert(nativeConns, inst.DescendantAdded:Connect(function(obj)
		if running and not nativeShown and obj:IsA("GuiButton") then onNativeActivity() end
	end))
end

local function hideAllNative()
	nativeShown = false
	for _, container in ipairs({ CoreGui, guiHolder() }) do
		pcall(function()
			for _, child in ipairs(container:GetChildren()) do hideNative(child) end
			table.insert(nativeConns, container.ChildAdded:Connect(function(child)
				task.defer(function()
					if running and not nativeShown then hideNative(child) end
				end)
			end))
		end)
	end
end

local function releaseNative()
	for _, c in ipairs(nativeConns) do pcall(function() c:Disconnect() end) end
	nativeConns = {}
	for inst, rec in pairs(hiddenNative) do
		pcall(function() if inst.Parent then inst.Enabled = rec.was end end)
	end
	hiddenNative = {}
end

-- Roblox's own prompt for this purchase (hidden again for the next one, once it is closed)
local function showNative(reason)
	if nativeShown then return end
	nativeShown = true
	watchdog = nil
	releaseNative()
	for _, container in ipairs({ CoreGui, guiHolder() }) do
		pcall(function()
			for _, child in ipairs(container:GetChildren()) do
				if isModernPrompt(child) then child.Enabled = true end
			end
		end)
	end
	if reason then say(reason) end
end

local function nativeHasPrompt()
	for _, container in ipairs({ CoreGui, guiHolder() }) do
		local found = false
		pcall(function()
			for _, child in ipairs(container:GetChildren()) do
				if isModernPrompt(child) then
					for _, d in ipairs(child:GetDescendants()) do
						if d:IsA("GuiButton") then found = true break end
					end
				end
				if found then break end
			end
		end)
		if found then return true end
	end
	return false
end

-- presses Roblox's own Cancel (with the executor's firesignal / getconnections)
local function pressNativeCancel()
	local pressed = false
	for _, container in ipairs({ CoreGui, guiHolder() }) do
		pcall(function()
			for _, child in ipairs(container:GetChildren()) do
				if isModernPrompt(child) then
					for _, d in ipairs(child:GetDescendants()) do
						if d:IsA("GuiButton") then
							local label = string.lower(d.Name .. " " .. (d:IsA("TextButton") and d.Text or ""))
							if string.find(label, "cancel", 1, true) or string.find(label, "close", 1, true) then
								for _, signalName in ipairs({ "Activated", "MouseButton1Click" }) do
									if firesignal then
										if pcall(firesignal, d[signalName]) then pressed = true end
									elseif getconnections then
										pcall(function()
											for _, c in ipairs(getconnections(d[signalName])) do c:Fire() pressed = true end
										end)
									end
								end
							end
						end
					end
				end
			end
		end)
	end
	return pressed
end

----------------------------------------------------------------------------------------------------
-- the old dialog's buttons: Buy goes on in Roblox's prompt, Cancel closes both
----------------------------------------------------------------------------------------------------
local function holdOldHidden(dialog)
	oldHeldHidden = dialog
	pcall(function() dialog.Visible = false end)
	table.insert(runConns, dialog:GetPropertyChangedSignal("Visible"):Connect(function()
		if oldHeldHidden == dialog and dialog.Visible then pcall(function() dialog.Visible = false end) end
	end))
end

local function buttonKind(button)
	local label = string.lower(button.Name .. " " .. (button:IsA("TextButton") and button.Text or ""))
	if string.find(label, "cancel", 1, true) or string.find(label, "close", 1, true) or string.find(label, "decline", 1, true) then
		return "cancel"
	end
	if string.find(label, "disabled", 1, true) then return nil end -- (the 2014 prompt's grey Buy: nothing to do)
	if string.find(label, "buy", 1, true) or string.find(label, "free", 1, true) or string.find(label, "purchase", 1, true)
		or string.find(label, "robux", 1, true) or string.find(label, "upgrade", 1, true) then
		return "buy"
	end
	return nil -- OK and the like: the 2016 prompt closes itself
end

local function onOldButton(button)
	if not running then return end
	local kind = buttonKind(button)
	local dialog = findDialog()
	if kind == "buy" then
		handoffs = handoffs + 1
		if dialog then holdOldHidden(dialog) end
		showNative("Buy pressed: Roblox's own prompt finishes the purchase.")
	elseif kind == "cancel" then
		if dialog then holdOldHidden(dialog) end
		watchdog = nil
		pressNativeCancel()
		-- Roblox's prompt is still open (its Cancel couldn't be pressed): shown, so it can be closed and a later
		-- purchase is not of this item
		task.delay(0.7, function()
			if running and not nativeShown and nativeHasPrompt() then
				showNative("Cancel pressed, but Roblox's own prompt is still open: it is shown so it can be closed.")
			end
		end)
	end
end

local hookedButtons = setmetatable({}, { __mode = "k" })
local function hookButton(button)
	if not button:IsA("GuiButton") or hookedButtons[button] then return end
	hookedButtons[button] = true
	local done = false
	local function pressed()
		if done then return end
		done = true
		task.defer(function() done = false end)
		onOldButton(button)
	end
	pcall(function() table.insert(runConns, button.Activated:Connect(pressed)) end)
	pcall(function() table.insert(runConns, button.MouseButton1Click:Connect(pressed)) end)
end

local hookedDialogs = setmetatable({}, { __mode = "k" })
local function hookDialog()
	local dialog = findDialog()
	if not dialog then return end
	for _, d in ipairs(dialog:GetDescendants()) do hookButton(d) end
	if hookedDialogs[dialog] then return end
	hookedDialogs[dialog] = true
	table.insert(runConns, dialog.DescendantAdded:Connect(function(d) task.defer(hookButton, d) end))
end

----------------------------------------------------------------------------------------------------
-- a purchase request
----------------------------------------------------------------------------------------------------
local function startWatchdog()
	local mine = {}
	watchdog = mine
	task.delay(WATCHDOG_SECONDS, function()
		if watchdog ~= mine or not running or nativeShown then return end
		if dialogVisible() then return end -- the old prompt is showing: all good
		fallbacks = fallbacks + 1
		warn("[Old Purchase Prompt] the old prompt did not appear " .. WATCHDOG_SECONDS .. " s after a purchase request: Roblox's own prompt is shown instead.")
		showNative()
	end)
end

local function onRequest(eventName, ...)
	if not running then return end
	lastRequestAt = os.clock()
	local oldName = REQUEST_EVENTS[eventName]
	local args = table.pack(...)
	-- the old and the V2 event for the same purchase: handled once
	local key = tostring(oldName or eventName) .. ":" .. tostring(args[2])
	if lastFed.key == key and os.clock() - lastFed.at < 1 then return end
	lastFed.key, lastFed.at = key, os.clock()
	requests = requests + 1
	if nativeShown then hideAllNative() end -- (given back for the last purchase: hidden again)

	if not oldName then
		showNative("A " .. eventName .. " (the 2016 prompt can't do that kind): Roblox's own prompt is shown.")
		return
	end
	say("A purchase was requested (" .. eventName .. ", " .. tostring(args[2]) .. "): the old prompt.")
	local ok, started, errors, promptStarted = pcall(runScripts)
	if not ok or not promptStarted then
		local why = not ok and tostring(started) or tostring(errors and errors[1])
		showNative("The " .. style .. " prompt couldn't start (" .. why .. "): Roblox's own prompt is shown.")
		return
	end
	hookDialog()
	if not fakeSignals[oldName] then
		showNative("The 2016 prompt doesn't listen for " .. oldName .. ": Roblox's own prompt is shown.")
		return
	end
	local be = fakeSignals[oldName]
	pcall(function() be:Fire(table.unpack(args, 1, args.n)) end)
	task.defer(hookDialog) -- (buttons it makes when the purchase comes in)
	startWatchdog()
end

-- Roblox's prompt is opening (a button appeared in it): a purchase no event told us about is shown there
onNativeActivity = function()
	if not running or nativeShown then return end
	local seen = lastRequestAt
	task.delay(0.4, function()
		if not running or nativeShown then return end
		if os.clock() - lastRequestAt < 1.5 or lastRequestAt ~= seen then return end -- a request we know about
		if dialogVisible() then return end
		fallbacks = fallbacks + 1
		showNative("Roblox's prompt opened for a purchase no event told us about: it is shown.")
	end)
end

local function onNativeFinished()
	if not running then return end
	watchdog = nil
	local dialog = findDialog()
	if dialog then holdOldHidden(dialog) end
	if nativeShown then
		-- hidden again for the next purchase, once Roblox's prompt has closed
		task.delay(0.5, function()
			if running and nativeShown then
				releaseNative()
				hideAllNative()
			end
		end)
	end
end

local function listenForRequests()
	local count = 0
	for eventName in pairs(REQUEST_EVENTS) do
		pcall(function()
			table.insert(requestConns, RealMarket[eventName]:Connect(function(...) onRequest(eventName, ...) end))
			count = count + 1
		end)
	end
	for _, eventName in ipairs(FINISHED_EVENTS) do
		pcall(function()
			table.insert(requestConns, RealMarket[eventName]:Connect(function(player)
				if player == nil or player == Players.LocalPlayer then onNativeFinished() end
			end))
		end)
	end
	return count
end

----------------------------------------------------------------------------------------------------
-- on and off
----------------------------------------------------------------------------------------------------
local api = {}

-- the 2014 PurchasePromptScript made to run here: only what its gone web calls and core-script powers need. Each change
-- is a plain find-and-replace; one that isn't found is said in the console (the rest still runs).
local PATCHES_2014 = {
	-- its pictures: "http://www.roblox.com/Asset/?id=..." as rbxassetid
	{ 'local assetUrl = "http://www.roblox.com/Asset/?id="', 'local assetUrl = "rbxassetid://"' },
	-- the item's picture: Roblox's thumbnail (thumbs/asset.ashx is gone)
	{ [[purchaseDialog.BodyFrame.ItemPreview.Image = baseUrl .. "thumbs/asset.ashx?assetid=" .. tostring(currentProductInfo["IconImageAssetId"]) .. '&x=100&y=100&format=png']],
	  [[purchaseDialog.BodyFrame.ItemPreview.Image = "rbxthumb://type=Asset&w=150&h=150&id=" .. tostring(currentProductInfo["IconImageAssetId"])]] },
	{ [[purchaseDialog.BodyFrame.ItemPreview.Image = baseUrl .. "thumbs/asset.ashx?assetid=" .. tostring(currentAssetId) .. '&x=100&y=100&format=png']],
	  [[purchaseDialog.BodyFrame.ItemPreview.Image = "rbxthumb://type=Asset&w=150&h=150&id=" .. tostring(currentAssetId)]] },
	-- today's product info has no MinimumMembershipLevel (comparing nothing threw)
	{ [[if tonumber(currentProductInfo["MinimumMembershipLevel"]) > membershipTypeToNumber(]],
	  [[if (tonumber(currentProductInfo["MinimumMembershipLevel"]) or 0) > membershipTypeToNumber(]] },
	-- the balance line: the client can't know your Robux, so it stays empty
	{ [[purchaseDialog.BodyFrame.AfterBalanceText.Text = tostring(balancePreText) .. tostring(afterBalanceNumber) .. " " .. currencyTypeToString(currentCurrencyType) .. "."]],
	  [[purchaseDialog.BodyFrame.AfterBalanceText.Text = "" -- (Addtion-Scripts) your balance isn't known here]] },
	{ [[purchaseDialog.BodyFrame.AfterBalanceText.Text = tostring(balancePreText) .. currencyTypeToString(currentCurrencyType) .. tostring(afterBalanceNumber) .. "."]],
	  [[purchaseDialog.BodyFrame.AfterBalanceText.Text = "" -- (Addtion-Scripts) your balance isn't known here]] },
	-- its own buying (a web call that is gone) is off: Buy goes on in Roblox's prompt (see onOldButton)
	{ "function doAcceptPurchase(currencyPreferredByUser)\n", "function doAcceptPurchase(currencyPreferredByUser)\n\tdo return end -- (Addtion-Scripts) Roblox's prompt buys\n" },
	{ "function openBuyCurrencyWindow()\n", "function openBuyCurrencyWindow()\n\tdo return end -- (Addtion-Scripts)\n" },
	{ "function buyEnoughCurrencyForProduct()\n", "function buyEnoughCurrencyForProduct()\n\tdo return end -- (Addtion-Scripts)\n" },
	{ "function openBCUpSellWindow()\n", "function openBCUpSellWindow()\n\tdo return end -- (Addtion-Scripts)\n" },
}

local function patch2014(src)
	src = string.gsub(src, "\r\n", "\n")
	local missed = 0
	for _, pair in ipairs(PATCHES_2014) do
		local a, b = string.find(src, pair[1], 1, true)
		if a then
			src = string.sub(src, 1, a - 1) .. pair[2] .. string.sub(src, b + 1)
		else
			missed = missed + 1
			warn("[Old Purchase Prompt] 2014: a change didn't fit the script: " .. string.sub(pair[1], 1, 60))
		end
	end
	-- (a few lines run twice in the script: the second copy of the item-picture line)
	src = string.gsub(src, 'baseUrl %.%. "thumbs/asset%.ashx%?assetid=" %.%. tostring%(([%w_]+)%) %.%. \'&x=100&y=100&format=png\'',
		'"rbxthumb://type=Asset&w=150&h=150&id=" .. tostring(%1)')
	return src, missed
end

function api.Style()
	return style
end

function api.Stop()
	if not running then return end
	running = false
	token = nil
	watchdog = nil
	for _, c in ipairs(requestConns) do pcall(function() c:Disconnect() end) end
	requestConns = {}
	clearRun()
	nativeShown = false
	releaseNative()
	if host then pcall(function() host:Destroy() end) end
	host, modules, syn = nil, nil, nil
	status = "off"
	if genv.OldPurchasePromptStop == api.Stop then genv.OldPurchasePromptStop = nil end
	print("[Old Purchase Prompt] off: Roblox's own prompt is back.")
end

function api.Start()
	if running then return end
	running = true
	status = "loading"
	local mine = {}
	token = mine

	style = (genv.OldPurchasePromptStyle == "2014") and "2014" or "2016"
	if style == "2014" then
		-- the 2014 prompt: its script from this repo, made to run here, in a ScreenGui of its own
		local okGet, src = pcall(function() return game:HttpGet(SOURCE_2014) end)
		if token ~= mine then return end
		if okGet and type(src) == "string" and string.find(src, "createPurchasePromptGui", 1, true) then
			source2014 = patch2014(src)
			local gui = Instance.new("ScreenGui")
			gui.Name = GUI_NAME
			gui.ResetOnSpawn = false
			gui.DisplayOrder = 1100
			gui.IgnoreGuiInset = true
			gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			host = gui
			gui.Parent = guiHolder()
			local okRun, started, errors, promptStarted = pcall(runScripts)
			if token ~= mine then return end
			if okRun and promptStarted then
				local heard = listenForRequests()
				hideAllNative()
				status = "on"
				genv.OldPurchasePromptStop = api.Stop
				say("On: the 2014 prompt; listening to " .. heard .. " purchase events. Roblox's prompt is hidden until it is needed.")
				return
			end
			for _, e in ipairs(okRun and errors or { tostring(started) }) do warn("[Old Purchase Prompt] " .. e) end
			pcall(function() gui:Destroy() end)
			host = nil
		else
			warn("[Old Purchase Prompt] the 2014 prompt's script couldn't be downloaded")
		end
		warn("[Old Purchase Prompt] the 2014 prompt didn't start: the 2016 one is used")
		style = "2016"
	end

	local okObjects, objs = pcall(function() return game:GetObjects(ASSET) end)
	if token ~= mine then return end -- stopped while it loaded
	if not okObjects or type(objs) ~= "table" or not objs[1] then
		running, status = false, "failed: the 2016 GUI asset did not load (" .. tostring(objs) .. ")"
		warn("[Old Purchase Prompt] " .. status .. ". Roblox's own prompt is kept.")
		return
	end

	-- only what the purchase scripts need: the Modules and the script sources; everything the asset draws goes
	local root = objs[1]
	modules = root:FindFirstChild("Modules")
	syn = root:FindFirstChild("CoreScriptSyn")
	if not (modules and syn) then
		modules, syn = nil, nil
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
	pcall(function() root.Enabled = true end)
	host = root
	root.Parent = guiHolder()

	-- a first run, to see that the 2016 prompt starts here (each purchase gets a fresh run of its own)
	local okRun, started, errors, promptStarted = pcall(runScripts)
	if token ~= mine then return end
	if not okRun then started, errors, promptStarted = 0, { tostring(started) }, false end
	for _, e in ipairs(errors) do warn("[Old Purchase Prompt] " .. e) end
	-- PurchasePromptScript2 is the prompt itself: without it, nothing is switched off
	if not promptStarted then
		pcall(function() root:Destroy() end)
		host, modules, syn = nil, nil, nil
		running, status = false, "failed: the 2016 prompt did not start"
		warn("[Old Purchase Prompt] " .. status .. ". Roblox's own prompt is kept.")
		return
	end
	local heard = listenForRequests()
	hideAllNative()
	status = "on"
	genv.OldPurchasePromptStop = api.Stop
	say("On: " .. started .. " of " .. #SCRIPTS .. " 2016 scripts started; listening to " .. heard
		.. " purchase events. Roblox's prompt is hidden until it is needed.")
end

function api.Running()
	return running and status == "on"
end

function api.Status()
	return status .. " (requests seen: " .. requests .. ", given back to Roblox's prompt: " .. fallbacks
		.. ", bought through Roblox's prompt: " .. handoffs .. ")"
end

genv.OldPurchasePrompt = api
task.spawn(api.Start)
