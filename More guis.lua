-- (Addtion-Scripts copy of the "More guis" gist, with 2011 added: the early 2011 client GUI, under 2012)
-- [[ 2024 / 2023 / 2021 / 2019 / 2017 / 2015 EARLY / 2013 MOBILE / 2011 / 2008 / 2006 / 2005 HOOKS + PLACEHOLDERS ]]
-- [[ + 2014 BACKPACK FIX (loads with the 2014 GUI) ]]
-- [[ + RETRO TOPBARPLUS HOOK (classic icons on the 2019 / 2017 / 2016 / 2015 top bars) ]]
-- Run AFTER the main Bloxy Paradox script.

------------------------------------------------------------
-- PART 1: LOADSTRING HOOK
------------------------------------------------------------
local _ORIG_LS = getgenv().BP_TrueLS
if not _ORIG_LS then
	_ORIG_LS = getgenv().loadstring or loadstring
	getgenv().BP_TrueLS = _ORIG_LS
end

do
	local URL_2024      = "https://gist.githubusercontent.com/eloredo413-hue/f0cf527c3c42f43fb90b33613f2f9a94/raw/2f8e97781c1403836df58510decebe961cc97074/2024%2520Gui"
	local URL_2023_NEW  = "https://gist.githubusercontent.com/eloredo413-hue/4a556148bc45d14ac710a87efef6bcc6/raw/4893deb9647440ba0f9058e0666272fb20e48eba/2023%2520New%2520Gui"
	local URL_2023_OLD  = "https://gist.githubusercontent.com/eloredo413-hue/44e796be1b5b79e8548c5d6dc564ceef/raw/af64fb124e52e9e1a339148d7f5b3e7ae34eb6e6/2023%2520old"
	local URL_2021      = "https://gist.githubusercontent.com/eloredo413-hue/af5130bac10fee921f0109950db368b7/raw/43dff4a41650829135f55674f098b3e8608a3740/2021%2520gui"
	local URL_2019      = "https://gist.githubusercontent.com/eloredo413-hue/c30bf30c51fb8116506e2015bbe0c3ec/raw/be760fc9ea32d86d73be6b6206a5f3d161ae5965/2019%2520gui"
	local URL_2017      = "https://gist.githubusercontent.com/eloredo413-hue/11756686e69413c5bc6933e2e800af6f/raw/69d595b5b51becaed1303b22a6f95a967ce0ad5e/2017%2520gui"
	local URL_2015EARLY = "https://gist.githubusercontent.com/eloredo413-hue/68973429a7a93b67dd0acfea666de508/raw/e461f4f6c1e169cc36f6b662b9265ce17b07effd/E2015%2520Gui"
	local URL_2013MOB   = "https://gist.githubusercontent.com/eloredo413-hue/86c21fe27caf9a3c358d15d1b74dff93/raw/2f73f4947a9f13c987141bdc8af5fe7e4c5dfafd/2013%2520Mobile%2520gui"
	local URL_2011      = "https://gist.githubusercontent.com/eloredo413-hue/d8af6f1767898993154225e9aed06301/raw/1fe72f4c693cd359aeadb743f3d4233a6c9f843d/2011gui"
	local URL_2008      = "https://gist.githubusercontent.com/eloredo413-hue/f60d1caf2307cefb517c11d84289ed1f/raw/1d45ddfb92fc749e5184f9a6cd05109fde9046c7/2008%2520gui"
	local URL_2006      = "https://gist.githubusercontent.com/eloredo413-hue/a0101af36dd4a890607d7788a59382cf/raw/d0f911e883289cb7444cdf7dc2b562119c2355c0/2006-2007%2520Gui"
	local URL_2005      = "https://gist.githubusercontent.com/eloredo413-hue/7eca661bd68389b3fb2ec5b762b3fb7a/raw/17af25bbea489d0e47334f0f72b183421522536e/2005%2520gui"
	-- (Addtion-Scripts) 1989: the Interactive Physics window (1989 Gui.lua), an Easter egg option: see STEP 11
	local URL_1989      = "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/1989%20Gui.lua"
	local SIG_2023      = "111872120766790"
	local SIG_2013      = "Year = 2013"
	local SIG_2014      = "h5AEhK7N" -- the 2014 topbar's pastebin
	local URL_2014FIX   = "https://gist.githubusercontent.com/eloredo413-hue/ed1b24318326687c9dc93033af880bf9/raw/2053cd3b7fb00377179c45194bd702a23e133819/2014%2520gui%2520fix"

	-- (Addtion-Scripts) each GUI's own gist, for when its link (this repo's copy, put in by the loader) doesn't answer:
	-- an older version, but the GUI still loads
	local GIST_FALLBACKS = {
		["2024"] = "https://gist.githubusercontent.com/eloredo413-hue/f0cf527c3c42f43fb90b33613f2f9a94/raw/2f8e97781c1403836df58510decebe961cc97074/2024%2520Gui",
		["2023 new"] = "https://gist.githubusercontent.com/eloredo413-hue/4a556148bc45d14ac710a87efef6bcc6/raw/4893deb9647440ba0f9058e0666272fb20e48eba/2023%2520New%2520Gui",
		["2023 old"] = "https://gist.githubusercontent.com/eloredo413-hue/44e796be1b5b79e8548c5d6dc564ceef/raw/af64fb124e52e9e1a339148d7f5b3e7ae34eb6e6/2023%2520old",
		["2021"] = "https://gist.githubusercontent.com/eloredo413-hue/af5130bac10fee921f0109950db368b7/raw/43dff4a41650829135f55674f098b3e8608a3740/2021%2520gui",
		["2019"] = "https://gist.githubusercontent.com/eloredo413-hue/c30bf30c51fb8116506e2015bbe0c3ec/raw/be760fc9ea32d86d73be6b6206a5f3d161ae5965/2019%2520gui",
		["2017"] = "https://gist.githubusercontent.com/eloredo413-hue/11756686e69413c5bc6933e2e800af6f/raw/69d595b5b51becaed1303b22a6f95a967ce0ad5e/2017%2520gui",
		["2015 early"] = "https://gist.githubusercontent.com/eloredo413-hue/68973429a7a93b67dd0acfea666de508/raw/e461f4f6c1e169cc36f6b662b9265ce17b07effd/E2015%2520Gui",
		["2013 mobile"] = "https://gist.githubusercontent.com/eloredo413-hue/86c21fe27caf9a3c358d15d1b74dff93/raw/2f73f4947a9f13c987141bdc8af5fe7e4c5dfafd/2013%2520Mobile%2520gui",
		["2011"] = "https://gist.githubusercontent.com/eloredo413-hue/d8af6f1767898993154225e9aed06301/raw/1fe72f4c693cd359aeadb743f3d4233a6c9f843d/2011gui",
		["2008"] = "https://gist.githubusercontent.com/eloredo413-hue/f60d1caf2307cefb517c11d84289ed1f/raw/1d45ddfb92fc749e5184f9a6cd05109fde9046c7/2008%2520gui",
		["2006"] = "https://gist.githubusercontent.com/eloredo413-hue/a0101af36dd4a890607d7788a59382cf/raw/d0f911e883289cb7444cdf7dc2b562119c2355c0/2006-2007%2520Gui",
		["2005"] = "https://gist.githubusercontent.com/eloredo413-hue/7eca661bd68389b3fb2ec5b762b3fb7a/raw/17af25bbea489d0e47334f0f72b183421522536e/2005%2520gui",
		["2014 fix"] = "https://gist.githubusercontent.com/eloredo413-hue/ed1b24318326687c9dc93033af880bf9/raw/2053cd3b7fb00377179c45194bd702a23e133819/2014%2520gui%2520fix",
	}

	local ownLegacy -- (below: the Legacy and RBXM Suite fixes, also used on every GUI downloaded here)

	-- (Addtion-Scripts) the 2006 GUI's lighting: its ColorShift_Bottom (122, 155, 128) with the green all the way up
	-- (122, 255, 128); the red and blue as they were
	local function greener2006(src)
		local patched, count = string.gsub(src,
			"(local LIGHTING_COLOR_SHIFT_BOTTOM = Color3%.fromRGB%(%s*%d+%s*,%s*)%d+(%s*,%s*%d+%s*%))", "%1255%2", 1)
		if count == 0 then warn("[2006] its lighting colour wasn't found: it stays as it was") end
		return patched
	end


	-- (Addtion-Scripts) a download is tried twice (a phone's connection drops a request now and then), then the gist
	local function fetchOnce(url)
		local ok, src = pcall(function()
			return game:HttpGet(url, true)
		end)
		if not ok then return nil, tostring(src) end
		if type(src) ~= "string" or #src < 50 or src:find("^%s*<") or src:find("^404") then
			return nil, "bad response (" .. tostring(type(src) == "string" and #src or 0) .. " bytes)"
		end
		return src
	end

	local function fetchURL(url, label)
		print("[" .. label .. "] Fetching...")
		local tries = { url, url }
		local gist = GIST_FALLBACKS[label]
		if gist and gist ~= url then table.insert(tries, gist) end
		local lastProblem = nil
		for i, link in ipairs(tries) do
			local src, problem = fetchOnce(link)
			if src then
				print("[" .. label .. "] Fetched " .. #src .. " bytes" .. (link ~= url and " (from its gist: the usual link didn't answer)" or "") .. ".")
				if ownLegacy then src = ownLegacy(src) end
				return src
			end
			lastProblem = problem
			if i < #tries then task.wait(1) end
		end
		warn("[" .. label .. "] HTTP fetch failed: " .. tostring(lastProblem))
		return nil
	end

	-- 2023 old only queues its GUI to load after a rejoin, so nothing
	-- shows up when the rejoin doesn't happen. Like 2023 new, also load
	-- the queued GUI in this server right away. Its payload runs once per
	-- server, so its own load-here fallback doesn't load it twice.
	local function alsoLoadHere(fn, ...)
		if type(fn) ~= "function" or not (setfenv and getfenv) then
			return fn, ...
		end
		local realQueue = queue_on_teleport or (syn and syn.queue_on_teleport)
		setfenv(fn, setmetatable({
			queue_on_teleport = function(payload)
				if not realQueue then error("queue_on_teleport is not available") end
				realQueue(payload)
				task.spawn(function()
					local ok, err = pcall(function() _ORIG_LS(payload)() end)
					if not ok then warn("[2023 old] Loading here failed: " .. tostring(err)) end
				end)
			end,
		}, { __index = getfenv(fn) }))
		return fn
	end

	-- (Addtion-Scripts) THE 2012-2016 GUIS ON OUR OWN COPY OF LEGACY: Bloxy's 2013 / 2015 / 2016 load yeku's
	-- Source.luau; that link goes to this repo's copy (Legacy Gui.lua: the original, made safe where it could stop).
	-- Code that has Legacy built in (the 2014 pastebin, also the early 2015 GUI's base) gets the same fixes here, with
	-- the loader's getgenv().BP_Legacy: another copy of RBXM Suite, the model from the release or an earlier download,
	-- no endless wait for the chat's bubbleChat, and no error on a phone without RobloxGui.NotificationFrame.
	local OWN_LEGACY_URL = "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/Legacy%20Gui.lua"
	local LEGACY_FIXES = {
		{ 'loadstring(game:HttpGet("https://raw.githubusercontent.com/yeku/forks/refs/heads/main/Scripts/RBXMSuite.luau"))()',
		  'getgenv().BP_Legacy.LoadSuite()' },
		{ 'Suite.download("yeku/legacy@latest", "Legacy.rbxm")', 'getgenv().BP_Legacy.Model(Suite)' },
		{ 'CoreGui:WaitForChild("ExperienceChat"):WaitForChild("bubbleChat")', 'getgenv().BP_Legacy.Bubbles()' },
		{ 'RobloxGui.NotificationFrame.Parent = LegacyGui',
		  'if RobloxGui:FindFirstChild("NotificationFrame") then RobloxGui.NotificationFrame.Parent = LegacyGui end' },
	}
	local function replacePlain(text, old, new)
		local out, from, count = {}, 1, 0
		while true do
			local a, b = string.find(text, old, from, true)
			if not a then break end
			table.insert(out, string.sub(text, from, a - 1))
			table.insert(out, new)
			from = b + 1
			count = count + 1
		end
		if count == 0 then return text, 0 end
		table.insert(out, string.sub(text, from))
		return table.concat(out), count
	end
	-- RBXM Suite, wherever a script loads it from yeku's link: the loader's (with this repo's copy as a backup) when the
	-- loader is there, else yeku's link as before (so code that runs after a rejoin, without the loader, still works)
	local SAFE_SUITE = '((type(getgenv().BP_Legacy) == "table" and getgenv().BP_Legacy.LoadSuite) and getgenv().BP_Legacy.LoadSuite()'
		.. ' or loadstring(game:HttpGet("https://raw.githubusercontent.com/yeku/forks/refs/heads/main/Scripts/" .. "RBXMSuite.luau"))())'
	ownLegacy = function(code)
		if string.find(code, "ADDTION_LEGACY", 1, true) then return code end -- (this repo's copy: already safe)
		local suites
		code, suites = string.gsub(code,
			'loadstring%(%s*game:HttpGet%(%s*["\']https://raw%.githubusercontent%.com/yeku/forks/refs/heads/main/Scripts/RBXMSuite%.luau["\']%s*%)%s*%)%(%)',
			function() return SAFE_SUITE end)
		if suites > 0 then print("[Hooks] RBXM Suite: with this repo's copy as a backup (" .. suites .. ")") end
		local redirected
		code, redirected = string.gsub(code, 'https://raw%.githubusercontent%.com/yeku/legacy/[^"\'%s]-/Source%.luau',
			function() return OWN_LEGACY_URL end) -- (a function: "%20" in the link is not a capture)
		if redirected > 0 then print("[Hooks] Legacy: loading this repo's copy (Legacy Gui.lua)") end
		if type(getgenv().BP_Legacy) == "table" and getgenv().BP_Legacy.Get2014 then
			local pastebin
			code, pastebin = string.gsub(code, 'game:HttpGet%(%s*["\']https?://pastebin%.com/raw/h5AEhK7N["\'][^%)]*%)',
				function() return 'getgenv().BP_Legacy.Get2014("h5AEhK7N")' end)
			if pastebin > 0 then print("[Hooks] 2014: pastebin first, this repo's copy if it doesn't answer") end
		end
		if type(getgenv().BP_Legacy) == "table" and string.find(code, "Suite.require(Legacy):Start(", 1, true)
			and not string.find(code, "ADDTION_LEGACY", 1, true) then
			local fixed = 0
			for _, fix in ipairs(LEGACY_FIXES) do
				local n
				code, n = replacePlain(code, fix[1], fix[2])
				fixed = fixed + n
			end
			if fixed > 0 then print("[Hooks] Legacy: " .. fixed .. " fixes in a built-in copy") end
		end
		return code
	end

	local heldSaid = false
	local function patched(code, name)
		if type(code) ~= "string" then
			return _ORIG_LS(code, name)
		end
		-- (Addtion-Scripts) With the setup's < > on (Setup Back Forward.lua), nothing loads until the last question:
		-- one of Bloxy's own picks (a topbar GUI, safe chat ...) run before then is held, and it loads at the end from
		-- the final answers. The topbar waiting here (BP_PendingTopbar) is left as it is for then.
		local wizard = getgenv().BPWizard
		if type(wizard) == "table" and type(wizard.holdCode) == "function" and wizard.holdCode(code) then
			if not heldSaid then
				heldSaid = true
				print("[Hooks] one of Bloxy's picks tried to load during the setup: it loads after the last question")
			end
			return function() end
		end
		code = ownLegacy(code)

		local pending = getgenv().BP_PendingTopbar
		local variant = getgenv().BP_2023Variant

		if pending then
			if pending == "2024" and code:find(SIG_2023, 1, true) then
				getgenv().BP_PendingTopbar = nil
				getgenv().BP_2023Variant = nil
				local src = fetchURL(URL_2024, "2024")
				if src then return _ORIG_LS(src, name) end
				return _ORIG_LS("-- [Hook] 2024 fetch failed", name)

			elseif pending == "2021" and code:find(SIG_2023, 1, true) then
				getgenv().BP_PendingTopbar = nil
				getgenv().BP_2023Variant = nil
				local src = fetchURL(URL_2021, "2021")
				if src then return _ORIG_LS(src, name) end
				return _ORIG_LS("-- [Hook] 2021 fetch failed", name)

			elseif pending == "2019" and code:find(SIG_2023, 1, true) then
				getgenv().BP_PendingTopbar = nil
				getgenv().BP_2023Variant = nil
				local src = fetchURL(URL_2019, "2019")
				if src then return _ORIG_LS(src, name) end
				return _ORIG_LS("-- [Hook] 2019 fetch failed", name)

			elseif pending == "2017" and code:find(SIG_2023, 1, true) then
				getgenv().BP_PendingTopbar = nil
				getgenv().BP_2023Variant = nil
				local src = fetchURL(URL_2017, "2017")
				if src then return _ORIG_LS(src, name) end
				return _ORIG_LS("-- [Hook] 2017 fetch failed", name)

			elseif pending == "2015early" and code:find(SIG_2014, 1, true) then
				getgenv().BP_PendingTopbar = nil
				getgenv().BP_2023Variant = nil
				local src = fetchURL(URL_2015EARLY, "2015 early")
				if src then return _ORIG_LS(src, name) end
				return _ORIG_LS("-- [Hook] 2015 early fetch failed", name)

			elseif pending == "2013mobile" and code:find(SIG_2013, 1, true) then
				getgenv().BP_PendingTopbar = nil
				getgenv().BP_2023Variant = nil
				local src = fetchURL(URL_2013MOB, "2013 mobile")
				if src then return _ORIG_LS(src, name) end
				return _ORIG_LS("-- [Hook] 2013 mobile fetch failed", name)

			elseif pending == "2011" and code:find(SIG_2013, 1, true) then
				getgenv().BP_PendingTopbar = nil
				getgenv().BP_2023Variant = nil
				local src = fetchURL(URL_2011, "2011")
				if src then return _ORIG_LS(src, name) end
				return _ORIG_LS("-- [Hook] 2011 fetch failed", name)

			elseif pending == "2008" and code:find(SIG_2013, 1, true) then
				getgenv().BP_PendingTopbar = nil
				getgenv().BP_2023Variant = nil
				local src = fetchURL(URL_2008, "2008")
				if src then return _ORIG_LS(src, name) end
				return _ORIG_LS("-- [Hook] 2008 fetch failed", name)

			elseif pending == "2006" and code:find(SIG_2013, 1, true) then
				getgenv().BP_PendingTopbar = nil
				getgenv().BP_2023Variant = nil
				local src = fetchURL(URL_2006, "2006")
				if src then return _ORIG_LS(greener2006(src), name) end
				return _ORIG_LS("-- [Hook] 2006 fetch failed", name)

			elseif pending == "2005" and code:find(SIG_2013, 1, true) then
				getgenv().BP_PendingTopbar = nil
				getgenv().BP_2023Variant = nil
				local src = fetchURL(URL_2005, "2005")
				if src then return _ORIG_LS(src, name) end
				return _ORIG_LS("-- [Hook] 2005 fetch failed", name)

			elseif pending == "1989" and code:find(SIG_2013, 1, true) then
				getgenv().BP_PendingTopbar = nil
				getgenv().BP_2023Variant = nil
				local src = fetchURL(URL_1989, "1989")
				if src then return _ORIG_LS(src, name) end
				return _ORIG_LS("-- [Hook] 1989 fetch failed", name)
			end
		end

		-- Plain 2014: load the 2014 GUI as usual, plus the 2014 fix
		-- (backpack, hotbar size, menu background). Only once per session:
		-- it keeps watching for the 2014 GUI by itself. Skipped for the
		-- 2015 early hook, which has its own backpack.
		if not pending and code:find(SIG_2014, 1, true)
		   and not code:find("2015 EARLY HOOK", 1, true)
		   and not getgenv().BP_2014FixLoaded then
			local fn, err = _ORIG_LS(code, name)
			if type(fn) ~= "function" then return fn, err end
			return function(...)
				if not getgenv().BP_2014FixLoaded then
					getgenv().BP_2014FixLoaded = true
					task.spawn(function()
						local src = fetchURL(URL_2014FIX, "2014 fix")
						if not src then
							getgenv().BP_2014FixLoaded = nil
							return
						end
						local fix, fixErr = _ORIG_LS(src, "2014GuiFix")
						if not fix then
							warn("[2014 fix] Compile failed: " .. tostring(fixErr))
							return
						end
						local ok, runErr = pcall(fix)
						if not ok then warn("[2014 fix] Error: " .. tostring(runErr)) end
					end)
				end
				return fn(...)
			end
		end

		if variant and code:find(SIG_2023, 1, true) then
			getgenv().BP_2023Variant = nil

			if variant == "new" then
				print("[2023 Hook] Loading NEW 2023 GUI...")
				local src = fetchURL(URL_2023_NEW, "2023 new")
				if src then return _ORIG_LS(src, name) end
				warn("[2023 Hook] NEW fetch failed — falling back to base 2023.")
			elseif variant == "old" then
				print("[2023 Hook] Loading OLD 2023 GUI...")
				local src = fetchURL(URL_2023_OLD, "2023 old")
				if src then return alsoLoadHere(_ORIG_LS(src, name)) end
				warn("[2023 Hook] OLD fetch failed — falling back to base 2023.")
			end
		end

		return _ORIG_LS(code, name)
	end

	pcall(function() getgenv().loadstring = patched end)
	pcall(function() _G.loadstring = patched end)
	print("[Hooks] Installed.")
end

------------------------------------------------------------
-- PART 1B: RETRO TOPBARPLUS HOOK
-- Redraws the game's TopbarPlus buttons as classic icons whenever the
-- old Legacy top bar is on screen (2019 / 2017 / 2016 / 2015) and puts
-- them back otherwise, so it runs once here and switches itself.
------------------------------------------------------------
task.spawn(function()
	local URL_RETRO_TOPBARPLUS = "https://gist.githubusercontent.com/eloredo413-hue/8089a272a2896d4bf743b8710f5b3be9/raw/1787e8a5b7364f6a5321c03925331ccfd2d18169/Retro%2520topbarplus%2520hook"

	print("[Retro TopbarPlus] Fetching...")
	local ok, src = pcall(function()
		return game:HttpGet(URL_RETRO_TOPBARPLUS, true)
	end)
	if not ok or type(src) ~= "string" or #src < 50 then
		warn("[Retro TopbarPlus] Fetch failed: " .. tostring(src))
		return
	end

	local fn, err = _ORIG_LS(src, "RetroTopbarPlus")
	if not fn then
		warn("[Retro TopbarPlus] Compile failed: " .. tostring(err))
		return
	end
	local ran, runErr = pcall(fn)
	if not ran then
		warn("[Retro TopbarPlus] Error: " .. tostring(runErr))
	end
end)

------------------------------------------------------------
-- PART 2: WIZARD DROPDOWN REWIRING
------------------------------------------------------------
task.spawn(function()
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")

	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui")
	local sg = pg:WaitForChild("BloxyParadoxProject", 30)
	if not sg then
		warn("[Topbar Addon] GUI never appeared.")
		return
	end

	local handled = setmetatable({}, {__mode = "k"})

	local CLICK_ID = "rbxassetid://12221967"
	local soundCache = nil

	local function playClick()
		if not soundCache then
			local SoundService = game:GetService("SoundService")
			soundCache = SoundService:FindFirstChild("BloxyParadoxClick")
			if not soundCache then
				soundCache = Instance.new("Sound")
				soundCache.Name = "BloxyParadoxClick"
				soundCache.SoundId = CLICK_ID
				soundCache.Volume = 0.6
				soundCache.Parent = SoundService
			end
		end
		soundCache:Stop()
		soundCache:Play()
	end

	local function addHover(btn)
		btn.MouseEnter:Connect(function()
			if btn.Active then
				btn.BackgroundColor3 = Color3.fromRGB(44, 179, 255)
				btn.TextColor3 = Color3.fromRGB(255, 255, 255)
				btn.BorderColor3 = Color3.fromRGB(0, 0, 0)
			end
		end)
		btn.MouseLeave:Connect(function()
			btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			btn.TextColor3 = Color3.fromRGB(0, 0, 0)
			btn.BorderColor3 = Color3.fromRGB(0, 0, 0)
		end)
	end

	local function addClickSound(btn)
		btn.MouseButton1Click:Connect(function()
			playClick()
		end)
	end

	local function findButton(slider, text)
		for _, child in ipairs(slider:GetChildren()) do
			if child:IsA("TextButton") and child.Text == text then
				return child
			end
		end
		return nil
	end

	-- The lowest button from a year newer than `year`. A button added
	-- right under it keeps the list in time order (newest first),
	-- whatever years the main script's dropdown already has.
	local function findNewerAnchor(slider, year)
		local anchor = nil
		for _, child in ipairs(slider:GetChildren()) do
			if child:IsA("TextButton") then
				local childYear = tonumber(child.Text:match("^%d%d%d%d"))
				if childYear and childYear > year
				   and (not anchor or child.Position.Y.Offset > anchor.Position.Y.Offset) then
					anchor = child
				end
			end
		end
		return anchor
	end

	local function shiftDown(slider, aboveY, amount, exclude)
		for _, child in ipairs(slider:GetChildren()) do
			if child:IsA("TextButton")
			   and child ~= exclude
			   and child.Position.Y.Offset > aboveY then
				child.Position = UDim2.new(0, 0, 0, child.Position.Y.Offset + amount)
			end
		end
		slider.CanvasSize = UDim2.new(0, 0, 0, slider.CanvasSize.Y.Offset + amount)
	end

	local function findToggle(frame)
		for _, child in ipairs(frame:GetChildren()) do
			if child:IsA("TextButton")
			   and (child.Text:find("▼", 1, true) or child.Text:find("▲", 1, true)) then
				return child
			end
		end
		return nil
	end

	-- Roblox auto-translation can reword labels like "2023 old" (it showed
	-- up as "2023 years old"), so it's turned off on the buttons we touch.
	local function noTranslate(obj)
		pcall(function() obj.AutoLocalize = false end)
	end

	-- Sets the dropdown's label, and keeps it for a moment in case the
	-- main script's own click handler rewrites it right after.
	local function updateToggle(frame, text)
		local wanted = text .. "  ▼"
		task.spawn(function()
			local deadline = os.clock() + 0.6
			repeat
				local toggle = findToggle(frame)
				if toggle then
					noTranslate(toggle)
					if toggle.Text ~= wanted then toggle.Text = wanted end
				end
				task.wait()
			until os.clock() > deadline
		end)
	end

	local function wipeHandlers(btn)
		if not getconnections then return end
		local ok, conns = pcall(getconnections, btn.MouseButton1Click)
		if not ok or type(conns) ~= "table" then return end
		for _, conn in ipairs(conns) do
			pcall(function() conn:Disconnect() end)
		end
	end

	local function fireOriginal(btn)
		if not btn or not getconnections then return end
		local ok, conns = pcall(getconnections, btn.MouseButton1Click)
		if not ok or type(conns) ~= "table" then return end
		for _, conn in ipairs(conns) do
			if conn.Function then
				pcall(conn.Function)
				return
			end
		end
	end

	-- (looked for 10 times a second: it went through Bloxy's windows on every frame for the whole game)
	-- (and each window only when it is new or something came into it, or every 2 s: Bloxy's windows that stay open
	-- were gone through 10 times a second)
	local lookedAt = setmetatable({}, { __mode = "k" })
	local changed = setmetatable({}, { __mode = "k" })
	local function needsLook(frame)
		local last = lookedAt[frame]
		if last == nil then
			frame.DescendantAdded:Connect(function() changed[frame] = true end)
			changed[frame] = true
		end
		if changed[frame] or os.clock() - (last or 0) > 2 then
			changed[frame] = nil
			lookedAt[frame] = os.clock()
			return true
		end
		return false
	end
	local lookAcc = 0
	RunService.RenderStepped:Connect(function(dt)
		if not sg or not sg.Parent then return end
		lookAcc = lookAcc + (dt or 0)
		if lookAcc < 0.1 then return end
		lookAcc = 0

		for _, frame in ipairs(sg:GetChildren()) do
			if frame:IsA("Frame") and not handled[frame] and needsLook(frame) then
				local slider = nil
				for _, d in ipairs(frame:GetDescendants()) do
					if d:IsA("ScrollingFrame") then
						for _, opt in ipairs(d:GetChildren()) do
							if opt:IsA("TextButton") and opt.Text:find("2023", 1, true) then
								slider = d
								break
							end
						end
					end
					if slider then break end
				end

				if slider then
					handled[frame] = true
					print("[Topbar Addon] Dropdown detected.")

					task.wait(0.1)

					-- STEP 1: Split 2023
					if not findButton(slider, "2023 old") then
						local btn2023 = findButton(slider, "2023(w.i.p)")
							or findButton(slider, "2023 new")
							or findButton(slider, "2023")

						if btn2023 then
							local originalHandler = nil
							if getconnections then
								local ok, conns = pcall(getconnections, btn2023.MouseButton1Click)
								if ok and type(conns) == "table" then
									for _, conn in ipairs(conns) do
										if conn.Function then
											originalHandler = conn.Function
											break
										end
									end
									for _, conn in ipairs(conns) do
										pcall(function() conn:Disconnect() end)
									end
								end
							end

							noTranslate(btn2023)
							btn2023.Text = "2023 new"
							btn2023.MouseButton1Click:Connect(function()
								playClick()
								getgenv().Force2008BubbleChat = false
								getgenv().BP_PendingTopbar = nil
								getgenv().BP_2023Variant = "new"
								print("[2023 new] Selected.")
								if originalHandler then pcall(originalHandler) end
								updateToggle(frame, "2023 new")
							end)

							local btn2023Old = btn2023:Clone()
							btn2023Old.Name = "Topbar2023OldButton"
							noTranslate(btn2023Old)
							btn2023Old.Text = "2023 old"
							btn2023Old.Position = UDim2.new(0, 0, 0, btn2023.Position.Y.Offset + 35)
							btn2023Old.Parent = slider

							wipeHandlers(btn2023Old)
							addHover(btn2023Old)

							btn2023Old.MouseButton1Click:Connect(function()
								playClick()
								getgenv().Force2008BubbleChat = false
								getgenv().BP_PendingTopbar = nil
								getgenv().BP_2023Variant = "old"
								print("[2023 old] Selected.")
								if originalHandler then pcall(originalHandler) end
								updateToggle(frame, "2023 old")
							end)

							shiftDown(slider, btn2023.Position.Y.Offset, 35, btn2023Old)
							print("[Topbar Addon] 2023 split done.")
						end
					end

					task.wait(0.1)

					-- STEP 2: Insert 2024 (top, above 2023 new)
					if not findButton(slider, "2024") then
						local top = findButton(slider, "2023 new")
						local btn2023Old = findButton(slider, "2023 old")
						if top and btn2023Old then
							local topY = top.Position.Y.Offset
							local clone = btn2023Old:Clone()
							clone.Name = "Topbar2024Button"
							clone.Text = "2024"
							clone.Position = UDim2.new(0, 0, 0, topY)
							clone.Parent = slider

							wipeHandlers(clone)
							noTranslate(clone)
							addHover(clone)

							clone.MouseButton1Click:Connect(function()
								playClick()
								fireOriginal(btn2023Old)
								getgenv().Force2008BubbleChat = false
								getgenv().BP_PendingTopbar = "2024"
								getgenv().BP_2023Variant = nil
								print("[2024] Selected — will load on confirm.")
								updateToggle(frame, "2024")
							end)

							shiftDown(slider, topY - 1, 35, clone)
						end
					end

					task.wait(0.1)

					-- STEP 3: Insert 2021
					if not findButton(slider, "2021") then
						local anchor = findButton(slider, "2023 old")
						if anchor then
							local clone = anchor:Clone()
							clone.Name = "Topbar2021Button"
							clone.Text = "2021"
							clone.Position = UDim2.new(0, 0, 0, anchor.Position.Y.Offset + 35)
							clone.Parent = slider

							wipeHandlers(clone)
							noTranslate(clone)
							addHover(clone)

							clone.MouseButton1Click:Connect(function()
								playClick()
								fireOriginal(anchor)
								getgenv().Force2008BubbleChat = false
								getgenv().BP_PendingTopbar = "2021"
								getgenv().BP_2023Variant = nil
								print("[2021] Selected — will load on confirm.")
								updateToggle(frame, "2021")
							end)

							shiftDown(slider, anchor.Position.Y.Offset, 35, clone)
						end
					end

					task.wait(0.1)

					-- STEP 4: Insert 2019
					if not findButton(slider, "2019") then
						local anchor = findButton(slider, "2021") or findButton(slider, "2023 old")
						if anchor then
							local clone = anchor:Clone()
							clone.Name = "Topbar2019Button"
							clone.Text = "2019"
							clone.Position = UDim2.new(0, 0, 0, anchor.Position.Y.Offset + 35)
							clone.Parent = slider

							wipeHandlers(clone)
							noTranslate(clone)
							addHover(clone)

							clone.MouseButton1Click:Connect(function()
								playClick()
								local btn2023Old = findButton(slider, "2023 old")
								if btn2023Old then fireOriginal(btn2023Old) end
								getgenv().Force2008BubbleChat = false
								getgenv().BP_PendingTopbar = "2019"
								getgenv().BP_2023Variant = nil
								print("[2019] Selected — will load on confirm.")
								updateToggle(frame, "2019")
							end)

							shiftDown(slider, anchor.Position.Y.Offset, 35, clone)
						end
					end

					task.wait(0.1)

					-- STEP 5: Insert 2017
					if not findButton(slider, "2017") then
						local anchor = findButton(slider, "2019")
						if anchor then
							local clone = anchor:Clone()
							clone.Name = "Topbar2017Button"
							clone.Text = "2017"
							clone.Position = UDim2.new(0, 0, 0, anchor.Position.Y.Offset + 35)
							clone.Parent = slider

							wipeHandlers(clone)
							noTranslate(clone)
							addHover(clone)

							clone.MouseButton1Click:Connect(function()
								playClick()
								local btn2023Old = findButton(slider, "2023 old")
								if btn2023Old then fireOriginal(btn2023Old) end
								getgenv().Force2008BubbleChat = false
								getgenv().BP_PendingTopbar = "2017"
								getgenv().BP_2023Variant = nil
								print("[2017] Selected — will load on confirm.")
								updateToggle(frame, "2017")
							end)

							shiftDown(slider, anchor.Position.Y.Offset, 35, clone)
						end
					end

					task.wait(0.1)

					-- STEP 6: Insert 2015 early (under 2015). It's the 2014
					-- GUI with the 2015 backpack, so it rides on the 2014
					-- button.
					if not findButton(slider, "2015 early") then
						local btn2014 = findButton(slider, "2014")
						local anchor = findButton(slider, "2015") or findNewerAnchor(slider, 2015)
						if btn2014 and anchor then
							local clone = anchor:Clone()
							clone.Name = "Topbar2015EarlyButton"
							clone.Text = "2015 early"
							clone.Position = UDim2.new(0, 0, 0, anchor.Position.Y.Offset + 35)
							clone.Parent = slider

							wipeHandlers(clone)
							noTranslate(clone)
							addHover(clone)

							clone.MouseButton1Click:Connect(function()
								playClick()
								fireOriginal(btn2014)
								getgenv().Force2008BubbleChat = false
								getgenv().BP_PendingTopbar = "2015early"
								getgenv().BP_2023Variant = nil
								print("[2015 early] Selected — will load on confirm.")
								updateToggle(frame, "2015 early")
							end)

							shiftDown(slider, anchor.Position.Y.Offset, 35, clone)
						end
					end

					task.wait(0.1)

					-- STEP 7: Insert 2013 mobile
					if not findButton(slider, "2013 mobile") then
						local anchor = findButton(slider, "2013")
						if anchor then
							local clone = anchor:Clone()
							clone.Name = "Topbar2013MobileButton"
							clone.Text = "2013 mobile"
							clone.Position = UDim2.new(0, 0, 0, anchor.Position.Y.Offset + 35)
							clone.Parent = slider

							wipeHandlers(clone)
							noTranslate(clone)
							addHover(clone)

							clone.MouseButton1Click:Connect(function()
								playClick()
								fireOriginal(anchor)
								getgenv().Force2008BubbleChat = true
								getgenv().BP_PendingTopbar = "2013mobile"
								getgenv().BP_2023Variant = nil
								print("[2013 mobile] Selected — will load mobile GUI on confirm.")
								updateToggle(frame, "2013 mobile")
							end)

							shiftDown(slider, anchor.Position.Y.Offset, 35, clone)
						end
					end

					task.wait(0.1)

					-- STEP 7b: Insert 2011 (under the oldest year newer than it, like 2012).
					-- Like 2008, it rides on the 2013 button.
					if not findButton(slider, "2011") then
						local btn2013 = findButton(slider, "2013")
						local anchor = findNewerAnchor(slider, 2011)
						if btn2013 and anchor then
							local clone = anchor:Clone()
							clone.Name = "Topbar2011Button"
							clone.Text = "2011"
							clone.Position = UDim2.new(0, 0, 0, anchor.Position.Y.Offset + 35)
							clone.Parent = slider

							wipeHandlers(clone)
							noTranslate(clone)
							addHover(clone)

							clone.MouseButton1Click:Connect(function()
								playClick()
								fireOriginal(btn2013)
								getgenv().Force2008BubbleChat = false
								getgenv().BP_PendingTopbar = "2011"
								getgenv().BP_2023Variant = nil
								print("[2011] Selected — will load on confirm.")
								updateToggle(frame, "2011")
							end)

							shiftDown(slider, anchor.Position.Y.Offset, 35, clone)
						end
					end

					task.wait(0.1)

					-- STEP 8: Insert 2008 (under the oldest year newer than it, like 2010).
					-- Like 2006, it rides on the 2013 button.
					if not findButton(slider, "2008") then
						local btn2013 = findButton(slider, "2013")
						local anchor = findNewerAnchor(slider, 2008)
						if btn2013 and anchor then
							local clone = anchor:Clone()
							clone.Name = "Topbar2008Button"
							clone.Text = "2008"
							clone.Position = UDim2.new(0, 0, 0, anchor.Position.Y.Offset + 35)
							clone.Parent = slider

							wipeHandlers(clone)
							noTranslate(clone)
							addHover(clone)

							clone.MouseButton1Click:Connect(function()
								playClick()
								fireOriginal(btn2013)
								getgenv().Force2008BubbleChat = false
								getgenv().BP_PendingTopbar = "2008"
								getgenv().BP_2023Variant = nil
								print("[2008] Selected — will load on confirm.")
								updateToggle(frame, "2008")
							end)

							shiftDown(slider, anchor.Position.Y.Offset, 35, clone)
						end
					end

					task.wait(0.1)

					-- STEP 9: Insert 2006 (under the oldest year newer than it)
					if not findButton(slider, "2006") then
						local btn2013 = findButton(slider, "2013")
						local anchor = findNewerAnchor(slider, 2006)
						if btn2013 and anchor then
							local clone = anchor:Clone()
							clone.Name = "Topbar2006Button"
							clone.Text = "2006"
							clone.Position = UDim2.new(0, 0, 0, anchor.Position.Y.Offset + 35)
							clone.Parent = slider

							wipeHandlers(clone)
							noTranslate(clone)
							addHover(clone)

							clone.MouseButton1Click:Connect(function()
								playClick()
								fireOriginal(btn2013)
								getgenv().Force2008BubbleChat = false
								getgenv().BP_PendingTopbar = "2006"
								getgenv().BP_2023Variant = nil
								print("[2006] Selected — will load on confirm.")
								updateToggle(frame, "2006")
							end)

							shiftDown(slider, anchor.Position.Y.Offset, 35, clone)
						end
					end

					task.wait(0.1)

					-- (Addtion-Scripts) EASTER EGG: tap the 2005 option 8 times, each tap within 1.5 s of the one before, and a
					-- "1989" option (the Interactive Physics window) appears under it. It is kept in BloxyEasterEgg1989.json,
					-- so once unlocked it is in the list every time and never goes away.
					local EGG_FILE = "BloxyEasterEgg1989.json"
					local function eggUnlocked()
						local env = getgenv()
						if env.BP_1989Unlocked then return true end
						local ok, there = pcall(function() return isfile and isfile(EGG_FILE) end)
						if ok and there then env.BP_1989Unlocked = true return true end
						return false
					end
					local function insert1989()
						if findButton(slider, "1989") then return end
						local btn2013 = findButton(slider, "2013")
						local anchor = findButton(slider, "2005")
						if not (btn2013 and anchor) then return end
						local clone = anchor:Clone()
						clone.Name = "Topbar1989Button"
						clone.Text = "1989"
						clone.Position = UDim2.new(0, 0, 0, anchor.Position.Y.Offset + 35)
						clone.Parent = slider

						wipeHandlers(clone)
						noTranslate(clone)
						addHover(clone)

						clone.MouseButton1Click:Connect(function()
							playClick()
							fireOriginal(btn2013)
							getgenv().Force2008BubbleChat = false
							getgenv().BP_PendingTopbar = "1989"
							getgenv().BP_2023Variant = nil
							print("[1989] Selected — will load on confirm.")
							updateToggle(frame, "1989")
						end)

						shiftDown(slider, anchor.Position.Y.Offset, 35, clone)
					end
					local function eggTap()
						if eggUnlocked() then return end
						local env = getgenv()
						local t = os.clock()
						if env.BP_EggLast and t - env.BP_EggLast < 1.5 then
							env.BP_EggTaps = (env.BP_EggTaps or 0) + 1
						else
							env.BP_EggTaps = 1
						end
						env.BP_EggLast = t
						if env.BP_EggTaps >= 8 then
							env.BP_1989Unlocked = true
							pcall(function() if writefile then writefile(EGG_FILE, '{"unlocked":true}') end end)
							print("[1989] Easter egg unlocked: the 1989 option is in the list now, for good.")
							insert1989()
						end
					end

					-- STEP 10: Insert 2005
					if not findButton(slider, "2005") then
						local btn2013 = findButton(slider, "2013")
						local anchor = findButton(slider, "2006")
						if btn2013 and anchor then
							local clone = anchor:Clone()
							clone.Name = "Topbar2005Button"
							clone.Text = "2005"
							clone.Position = UDim2.new(0, 0, 0, anchor.Position.Y.Offset + 35)
							clone.Parent = slider

							wipeHandlers(clone)
							noTranslate(clone)
							addHover(clone)

							clone.MouseButton1Click:Connect(function()
								playClick()
								fireOriginal(btn2013)
								getgenv().Force2008BubbleChat = false
								getgenv().BP_PendingTopbar = "2005"
								getgenv().BP_2023Variant = nil
								print("[2005] Selected — will load on confirm.")
								updateToggle(frame, "2005")
								pcall(eggTap)
							end)

							shiftDown(slider, anchor.Position.Y.Offset, 35, clone)
						end
					end

					task.wait(0.1)

					-- STEP 11: the 1989 option, once the Easter egg has been unlocked
					if eggUnlocked() then insert1989() end

					print("[Topbar Addon] Done. Dropdown rebuilt.")
				end
			end
		end
	end)

	print("[Topbar Addon] Watching.")
end)

------------------------------------------------------------
-- PART 3: REPORT BUTTON DEDUPE (fixes 2017 double report)
------------------------------------------------------------
task.spawn(function()
	local Players = game:GetService("Players")
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")

	local REPORT_MATCHERS = { "report" }

	local function isReportButton(obj)
		if not (obj:IsA("TextButton") or obj:IsA("ImageButton")) then
			return false
		end
		local hay = (obj.Name or ""):lower()
		if obj:IsA("TextButton") then
			hay = hay .. " " .. (obj.Text or ""):lower()
		end
		for _, needle in ipairs(REPORT_MATCHERS) do
			if hay:find(needle, 1, true) then
				return true
			end
		end
		return false
	end

	local function getBloxyRoot()
		for _, c in ipairs(pg:GetChildren()) do
			if c:IsA("ScreenGui") and c.Name:find("Bloxy", 1, true) then
				return c
			end
		end
		return nil
	end

	local firstSeen = setmetatable({}, { __mode = "k" })

	local function dedupe()
		local root = getBloxyRoot()
		if not root then return end

		local reports = {}
		for _, d in ipairs(root:GetDescendants()) do
			if isReportButton(d) and d.Parent then
				if not firstSeen[d] then
					firstSeen[d] = os.clock()
				end
				table.insert(reports, d)
			end
		end

		if #reports <= 1 then return end

		table.sort(reports, function(a, b)
			return firstSeen[a] < firstSeen[b]
		end)

		for i = 1, #reports - 1 do
			local btn = reports[i]
			if btn and btn.Parent then
				print("[Dedupe] Removing older report button: " .. btn:GetFullName())
				pcall(function() btn:Destroy() end)
			end
		end
	end

	while true do
		task.wait(0.2)
		pcall(dedupe)
	end
end)