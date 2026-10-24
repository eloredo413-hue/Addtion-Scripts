-- [[ 2010 HOOK — only fires when you click 2010 in the wizard ]]

do
	local _orig = getgenv().loadstring or loadstring
	local NEW_URL = "https://gist.githubusercontent.com/eloredo413-hue/f6db24cf262572fcab970e747e621238/raw/a81e87c6f444c16aeb1923d243a6de7b85c3d766/2010%2520core%2520gui"
	local SIG = 'game:GetService("CoreGui").TopBarApp.TopBarApp.Enabled = false'

	------------------------------------------------------------
	-- IS THE WIZARD ACTUALLY OPEN?
	-- Checked only when the 2010 GUI is about to load. It used to be
	-- re-checked ten times a second by walking the whole Bloxy GUI.
	------------------------------------------------------------
	local WIZARD_KEYWORDS = {
		"which topbar",
		"do you want",
		"choose your",
		"what textures",
		"do you want better",
	}

	local function isWizardActive()
		local player = game:GetService("Players").LocalPlayer
		local pg = player and player:FindFirstChild("PlayerGui")
		local sg = pg and pg:FindFirstChild("BloxyParadoxProject")
		if not sg then return false end

		for _, frame in ipairs(sg:GetChildren()) do
			if frame:IsA("Frame") then
				for _, d in ipairs(frame:GetDescendants()) do
					if d:IsA("TextLabel") and type(d.Text) == "string" then
						local t = d.Text:lower()
						for _, kw in ipairs(WIZARD_KEYWORDS) do
							if t:find(kw, 1, true) then
								return true
							end
						end
					end
				end
			end
		end
		return false
	end

	------------------------------------------------------------
	-- LOADSTRING HOOK
	------------------------------------------------------------
	local function patched(code, name)
		if type(code) == "string"
			and string.find(code, SIG, 1, true)
			and isWizardActive() then
			print("[2010 Hook] Wizard picked 2010 — loading NEW 2010 GUI...")
			local ok, nc = pcall(function() return game:HttpGet(NEW_URL) end)
			if ok and type(nc) == "string" and #nc > 100 then
				return _orig(nc, name)
			end
			warn("[2010 Hook] Fetch failed, using old 2010.")
		end
		return _orig(code, name)
	end

	pcall(function() getgenv().loadstring = patched end)
	pcall(function() _G.loadstring = patched end)
	pcall(function() loadstring = patched end)
	print("[2010 Hook] Installed (only fires when wizard is active).")
end
