-- [[ EMOTES HOOK (Addtion-Scripts) ]]
-- Bloxy's "Do you want better emotes?" Yes (and its "skip setup" when Yes was saved) runs a short script that
-- downloads the 7yd7 emote script from rawscripts.net. That address is swapped for this copy (a gist), as the
-- script is handed to loadstring. Nothing else changes: No still loads nothing.
-- Chains on top of any loadstring hook already there (FF fix, SafeChat, topbar...), like the SafeChat hook.
-- Works when executed before OR after Bloxy.

do
	local Env = (getgenv and getgenv()) or _G
	if Env.BPEmotesHookInstalled then return end
	Env.BPEmotesHookInstalled = true

	local EMOTES_URL = "https://gist.githubusercontent.com/eloredo413-hue/a7dd3d3c02dfb2766badb997a6313172/raw/713dd2eec2f8ab29e9cfbc6be264a5f840b0ee57/7yd7"
	-- the address in Bloxy's BetterEmotes script
	local OLD_URL_PATTERN = "https?://rawscripts%.net/raw/Universal%-Script%-7yd7%-I%-Emote%-Script%-%d+"

	-- the current loadstring (which may already be another hook), not the original
	local _orig = Env.loadstring or loadstring

	local function patched(code, name)
		-- (only a short script: Bloxy's whole source has this address in it too)
		if type(code) == "string" and #code < 4000 and string.find(code, OLD_URL_PATTERN) then
			local swapped, count = string.gsub(code, OLD_URL_PATTERN, EMOTES_URL)
			if count > 0 then
				print("[Emotes Hook] better emotes: loading the 7yd7 emote script from the gist")
				return _orig(swapped, name)
			end
		end
		return _orig(code, name)
	end

	pcall(function() Env.loadstring = patched end)
	pcall(function() _G.loadstring = patched end)
	print("[Emotes Hook] Installed.")
end
