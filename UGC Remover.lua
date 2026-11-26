--[[
	UGC REMOVER (Addtion-Scripts)
	Every player's UGC items (hats, hair and the rest that players made, not Roblox) swapped, on your screen only, for
	the closest item Roblox made itself:

	  * which items are UGC: each item a player wears is looked up in the catalog (MarketplaceService:GetProductInfo);
	    anything not made by Roblox is UGC. Roblox's own items are left as they are.
	  * the closest Roblox item: the same kind of item (hair for hair, a hat for a hat, a face piece for a face
	    piece...), found with the game's own catalog search (AvatarEditorService:SearchCatalog), Roblox's items only,
	    by the words in the UGC item's name: "Black Messy Hair" finds Roblox's black hair, "Red Cap" a red cap. The one
	    sharing the most words (its colour counting extra) is picked; with nothing alike, Roblox's plainest one of that
	    kind for its colour (brown hair, a hat...).
	  * it is put on where the UGC one was (the same attachment), and the UGC one taken off. Nothing found or nothing
	    that loads: the UGC item is just taken off.
	  * dynamic heads' eyebrows and eyelashes are left alone (they belong to the head).

	New players, respawns and outfit changes are done as they come. Only a look: nothing is changed for anyone else.
	Lookups are kept, so the same item is only looked up once, and they go one at a time so the catalog isn't asked
	too much at once.
	Run again to start over; getgenv().__UGCRemoverCleanup() puts every item back.
]]

local Env = (getgenv and getgenv()) or _G
if type(Env.__UGCRemoverCleanup) == "function" then pcall(Env.__UGCRemoverCleanup) end

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local AvatarEditorService
pcall(function() AvatarEditorService = game:GetService("AvatarEditorService") end)

local ROBLOX_ID = 1
local MARK = "BPUGCReplacement"   -- (an attribute on the items this puts on)
local LOOKUP_GAP = 0.15            -- seconds between two catalog lookups
local SETTLE = 0.6                 -- seconds a character's items are left to settle before they're looked at

local alive = true
local conns = {}
local records = {}       -- [character] = { removed = { [accessory] = true }, added = { [accessory] = true } }
local pending = {}       -- [character] = true while it waits to be looked at
local infoCache = {}     -- [assetId] = product info (or false: couldn't be looked up)
local searchCache = {}   -- [kind .. "|" .. words] = list of found items
local templates = {}     -- [assetId] = the loaded Roblox item (or false)
local stats = { ugc = 0, swapped = 0, removedOnly = 0 }

local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(conns, c)
	return c
end

------------------------------------------------------------------------------------------------------------------------
-- one lookup at a time
------------------------------------------------------------------------------------------------------------------------
local lastLookup = 0
local busy = false
local function lookupTurn()
	while busy and alive do task.wait() end
	busy = true
	local wait = LOOKUP_GAP - (os.clock() - lastLookup)
	if wait > 0 then task.wait(wait) end
end
local function lookupDone()
	lastLookup = os.clock()
	busy = false
end

-- the catalog's page for an item, kept (tried again a couple of times when the catalog says no)
local function productInfo(assetId)
	local cached = infoCache[assetId]
	if cached ~= nil then return cached or nil end
	local info
	for try = 1, 3 do
		if not alive then return nil end
		lookupTurn()
		local ok, result = pcall(function()
			return MarketplaceService:GetProductInfo(assetId, Enum.InfoType.Asset)
		end)
		lookupDone()
		if ok and type(result) == "table" then info = result break end
		task.wait(1.5 * try)
	end
	infoCache[assetId] = info or false
	return info
end

local function madeByRoblox(info)
	local c = info and info.Creator
	if type(c) ~= "table" then return false end
	if c.CreatorTargetId == ROBLOX_ID or c.Id == ROBLOX_ID then
		return c.CreatorType == nil or c.CreatorType == "User" or c.CreatorType == Enum.CreatorType.User
	end
	return c.Name == "Roblox"
end

------------------------------------------------------------------------------------------------------------------------
-- WORDS of a name
------------------------------------------------------------------------------------------------------------------------
local COLORS = {
	black = true, white = true, brown = true, blonde = true, blond = true, red = true, orange = true, yellow = true,
	green = true, blue = true, purple = true, pink = true, grey = true, gray = true, silver = true, gold = true,
	golden = true, ginger = true, teal = true, cyan = true, navy = true, lime = true, beige = true, tan = true,
	dark = true, light = true, pastel = true, crimson = true, violet = true, cream = true,
}
local SKIP = {
	ugc = true, the = true, ["and"] = true, ["with"] = true, ["for"] = true, ["of"] = true, ["in"] = true,
	["on"] = true, ["a"] = true, ["an"] = true, new = true, limited = true, accessory = true, item = true,
	version = true, edition = true, cute = true, aesthetic = true, kawaii = true, y2k = true, emo = true,
	free = true, sale = true, cheap = true, style = true, styled = true, outfit = true, model = true,
}
local function wordsOf(name)
	local list, seen, colors = {}, {}, {}
	for word in string.gmatch(string.lower(tostring(name or "")), "%a+") do
		local w = (word == "blond" and "blonde") or (word == "gray" and "grey") or word
		if #w >= 3 and not SKIP[w] and not seen[w] then
			seen[w] = true
			if COLORS[w] then
				table.insert(colors, w)
			else
				table.insert(list, w)
			end
		end
	end
	return list, colors
end

------------------------------------------------------------------------------------------------------------------------
-- KINDS of items: the item's AccessoryType -> the catalog's kind, and Roblox's plainest one of that kind
------------------------------------------------------------------------------------------------------------------------
local KINDS = {
	Hat = { asset = "Hat", plain = "hat" },
	Hair = { asset = "HairAccessory", plain = "hair" },
	Face = { asset = "FaceAccessory", plain = "glasses" },
	Neck = { asset = "NeckAccessory", plain = "scarf" },
	Shoulder = { asset = "ShoulderAccessory", plain = "shoulder" },
	Front = { asset = "FrontAccessory", plain = "medal" },
	Back = { asset = "BackAccessory", plain = "cape" },
	Waist = { asset = "WaistAccessory", plain = "belt" },
	TShirt = { asset = "TShirtAccessory", plain = "shirt" },
	Shirt = { asset = "ShirtAccessory", plain = "shirt" },
	Pants = { asset = "PantsAccessory", plain = "pants" },
	Jacket = { asset = "JacketAccessory", plain = "jacket" },
	Sweater = { asset = "SweaterAccessory", plain = "sweater" },
	Shorts = { asset = "ShortsAccessory", plain = "shorts" },
	LeftShoe = { asset = "LeftShoeAccessory", plain = "shoe" },
	RightShoe = { asset = "RightShoeAccessory", plain = "shoe" },
	DressSkirt = { asset = "DressSkirtAccessory", plain = "skirt" },
}
local LEAVE_ALONE = { Eyebrow = true, Eyelash = true } -- (a dynamic head's)

local ATTACHMENT_KIND = {
	HatAttachment = "Hat", HairAttachment = "Hair", FaceFrontAttachment = "Face", FaceCenterAttachment = "Face",
	NeckAttachment = "Neck", LeftShoulderAttachment = "Shoulder", RightShoulderAttachment = "Shoulder",
	LeftCollarAttachment = "Shoulder", RightCollarAttachment = "Shoulder", BodyFrontAttachment = "Front",
	BodyBackAttachment = "Back", WaistFrontAttachment = "Waist", WaistBackAttachment = "Waist",
	WaistCenterAttachment = "Waist",
}

local function enumName(v)
	if typeof and typeof(v) == "EnumItem" then return v.Name end
	if type(v) == "userdata" or type(v) == "table" then
		local ok, n = pcall(function() return v.Name end)
		if ok and type(n) == "string" then return n end
	end
	if type(v) == "string" then return (string.gsub(v, "^Enum%.%w+%.", "")) end
	return tostring(v)
end

local function kindOfAccessory(acc)
	local ok, t = pcall(function() return acc.AccessoryType end)
	local name = ok and t and enumName(t) or nil
	if name and name ~= "Unknown" then return name end
	local handle = acc:FindFirstChild("Handle")
	if handle then
		for _, a in ipairs(handle:GetChildren()) do
			if a:IsA("Attachment") and ATTACHMENT_KIND[a.Name] then return ATTACHMENT_KIND[a.Name] end
		end
	end
	return "Hat"
end

------------------------------------------------------------------------------------------------------------------------
-- THE CLOSEST ROBLOX ITEM
------------------------------------------------------------------------------------------------------------------------
local function search(kind, words)
	local spec = KINDS[kind]
	if not spec or not AvatarEditorService then return {} end
	local key = kind .. "|" .. words
	if searchCache[key] then return searchCache[key] end
	local found = {}
	lookupTurn()
	local ok = pcall(function()
		local params = CatalogSearchParams.new()
		params.SearchKeyword = words
		params.AssetTypes = { Enum.AvatarAssetType[spec.asset] }
		params.CreatorName = "Roblox"
		pcall(function() params.IncludeOffSale = true end)
		pcall(function() params.SortType = Enum.CatalogSortType.Relevance end)
		pcall(function() params.Limit = 30 end)
		local pages = AvatarEditorService:SearchCatalog(params)
		for _, item in ipairs(pages:GetCurrentPage()) do
			local by = item.CreatorName
			local isAsset = item.ItemType == nil or enumName(item.ItemType) == "Asset"
			if isAsset and item.Id and (by == nil or by == "Roblox") then
				table.insert(found, { id = tonumber(item.Id), name = tostring(item.Name or "") })
			end
		end
	end)
	lookupDone()
	if ok then searchCache[key] = found end
	return found
end

-- how alike two names are: each word shared, and the colour (for hair the colour counts most: black hair should stay
-- black before it stays messy)
local function score(kind, candidateName, words, colors)
	local cw, cc = wordsOf(candidateName)
	local have = {}
	for _, w in ipairs(cw) do have[w] = true end
	for _, c in ipairs(cc) do have[c] = true end
	local colorWeight = (kind == "Hair") and 4 or 2
	local s = 0
	for _, w in ipairs(words) do if have[w] then s = s + 3 end end
	for _, c in ipairs(colors) do if have[c] then s = s + colorWeight end end
	return s
end

local function closestRobloxItem(kind, ugcName)
	local spec = KINDS[kind]
	if not spec then return nil end
	local words, colors = wordsOf(ugcName)
	local tries = {}
	local function try(q) if q ~= "" then table.insert(tries, q) end end
	local main = {}
	for i = 1, math.min(#words, 3) do main[i] = words[i] end
	local firstColor = colors[1] or ""
	try(((firstColor ~= "" and firstColor .. " " or "") .. table.concat(main, " ")))
	-- the longest words alone (the item itself: "fedora", "ponytail", "headphones")
	local byLength = { table.unpack(words) }
	table.sort(byLength, function(a, b) return #a > #b end)
	for i = 1, math.min(#byLength, 2) do
		try((firstColor ~= "" and firstColor .. " " or "") .. byLength[i])
		try(byLength[i])
	end
	local plain = (firstColor ~= "" and firstColor .. " " or "") .. spec.plain
	try(plain)
	try(spec.plain)

	local best, bestScore, firstSeen = nil, -1, nil
	local looked = {}
	for _, q in ipairs(tries) do
		if not looked[q] then
			looked[q] = true
			local found = search(kind, q)
			for _, item in ipairs(found) do
				firstSeen = firstSeen or item
				local s = score(kind, item.name, words, colors)
				if s > bestScore then best, bestScore = item, s end
			end
			if best and bestScore >= 3 then break end
		end
		if not alive then return nil end
	end
	return best or firstSeen
end

------------------------------------------------------------------------------------------------------------------------
-- LOADING the Roblox item (once each)
------------------------------------------------------------------------------------------------------------------------
local function loadItem(assetId)
	local t = templates[assetId]
	if t ~= nil then return t or nil end
	local model
	pcall(function()
		local objs = game:GetObjects("rbxassetid://" .. tostring(assetId))
		model = objs and objs[1]
	end)
	if not model then
		pcall(function()
			model = game:GetService("InsertService"):LoadLocalAsset("rbxassetid://" .. tostring(assetId))
		end)
	end
	local acc = nil
	if model then
		if model:IsA("Accoutrement") then
			acc = model
		else
			acc = model:FindFirstChildWhichIsA("Accoutrement", true)
		end
	end
	templates[assetId] = acc or false
	return acc
end

-- put it on: Roblox's own way, or (if that isn't allowed here) welded to the matching attachment by hand
local function wear(character, humanoid, acc)
	local handle = acc:FindFirstChild("Handle")
	if not handle then return false end
	for _, d in ipairs(acc:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			pcall(function() d.CanTouch = false d.CanQuery = false end)
			d.Massless = true
		end
	end
	acc:SetAttribute(MARK, true)
	local ok = pcall(function() humanoid:AddAccessory(acc) end)
	if ok and acc.Parent == character and (handle:FindFirstChildWhichIsA("Weld")
		or handle:FindFirstChildWhichIsA("WeldConstraint") or handle:FindFirstChildWhichIsA("RigidConstraint")) then
		return true
	end
	if acc.Parent ~= nil then pcall(function() acc.Parent = nil end) end
	-- by hand
	local mine
	for _, a in ipairs(handle:GetChildren()) do
		if a:IsA("Attachment") then mine = a break end
	end
	local theirs = mine and character:FindFirstChild(mine.Name, true)
	if not (theirs and theirs:IsA("Attachment") and theirs.Parent and theirs.Parent:IsA("BasePart")) then
		local head = character:FindFirstChild("Head")
		if not head then return false end
		acc.Parent = character
		local w = Instance.new("Weld")
		w.Name = "AccessoryWeld"
		w.Part0 = handle
		w.Part1 = head
		w.C1 = CFrame.new(0, 0.6, 0)
		w.Parent = handle
		return true
	end
	acc.Parent = character
	local w = Instance.new("Weld")
	w.Name = "AccessoryWeld"
	w.Part0 = handle
	w.Part1 = theirs.Parent
	w.C0 = mine.CFrame
	w.C1 = theirs.CFrame
	w.Parent = handle
	return true
end

------------------------------------------------------------------------------------------------------------------------
-- A CHARACTER
------------------------------------------------------------------------------------------------------------------------
local function normal(s)
	return (string.gsub(string.lower(tostring(s or "")), "[^%w]", ""))
end

local function recordOf(character)
	local r = records[character]
	if not r then
		r = { removed = {}, added = {} }
		records[character] = r
	end
	return r
end

-- the items a player wears, from their avatar (kind, asset id)
local function wornItems(humanoid)
	local list = {}
	local ok, desc = pcall(function() return humanoid:GetAppliedDescription() end)
	if not ok or not desc then return list end
	local got = pcall(function()
		for _, a in ipairs(desc:GetAccessories(true)) do
			local kind = enumName(a.AccessoryType)
			if a.AssetId and tonumber(a.AssetId) and tonumber(a.AssetId) > 0 then
				table.insert(list, { id = tonumber(a.AssetId), kind = kind })
			end
		end
	end)
	if got and #list > 0 then return list end
	-- (older: the comma lists)
	local FIELDS = {
		HatAccessory = "Hat", HairAccessory = "Hair", FaceAccessory = "Face", NeckAccessory = "Neck",
		ShouldersAccessory = "Shoulder", FrontAccessory = "Front", BackAccessory = "Back", WaistAccessory = "Waist",
	}
	for field, kind in pairs(FIELDS) do
		local s = ""
		pcall(function() s = desc[field] end)
		for id in string.gmatch(tostring(s or ""), "%d+") do
			table.insert(list, { id = tonumber(id), kind = kind })
		end
	end
	return list
end

local function doCharacter(character)
	if not alive or not character.Parent then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local r = recordOf(character)

	-- the accessories on it now (not ours), by kind
	local onIt, byKind = {}, {}
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accoutrement") and not child:GetAttribute(MARK) and not r.removed[child] then
			local kind = kindOfAccessory(child)
			if not LEAVE_ALONE[kind] then
				onIt[child] = kind
				byKind[kind] = byKind[kind] or {}
				table.insert(byKind[kind], child)
			end
		end
	end
	if next(onIt) == nil then return end

	-- which of the items worn are UGC
	local ugcByKind, robloxByKind = {}, {}
	for _, item in ipairs(wornItems(humanoid)) do
		if not alive then return end
		if not LEAVE_ALONE[item.kind] then
			local info = productInfo(item.id)
			if info then
				item.name = tostring(info.Name or "")
				local into = madeByRoblox(info) and robloxByKind or ugcByKind
				into[item.kind] = into[item.kind] or {}
				table.insert(into[item.kind], item)
			end
		end
	end
	if not character.Parent then return end

	-- the accessory on the character an item is: the one named like it
	local function takeNamed(left, item)
		local want = normal(item.name)
		if want == "" then return nil end
		for i, acc in ipairs(left) do
			local have = normal(acc.Name)
			if have == want or have:find(want, 1, true) or (#have >= 4 and want:find(have, 1, true)) then
				table.remove(left, i)
				return acc
			end
		end
		return nil
	end

	-- each UGC item -> the accessory on the character it is: the one named like it; or, once Roblox's own items of
	-- that kind are told apart by their names, the ones left over
	for kind, items in pairs(ugcByKind) do
		local left = {}
		for _, acc in ipairs(byKind[kind] or {}) do
			if acc.Parent == character then table.insert(left, acc) end
		end
		local pairsFound, unmatched = {}, {}
		for _, item in ipairs(items) do
			local acc = takeNamed(left, item)
			if acc then
				table.insert(pairsFound, { item = item, acc = acc })
			else
				table.insert(unmatched, item)
			end
		end
		local robloxLeft = 0
		for _, item in ipairs(robloxByKind[kind] or {}) do
			if not takeNamed(left, item) then robloxLeft = robloxLeft + 1 end
		end
		if #unmatched > 0 and robloxLeft == 0 then
			-- every one of this kind left is UGC: the rest of them are these
			for i, item in ipairs(unmatched) do
				local acc = left[i]
				if acc then table.insert(pairsFound, { item = item, acc = acc }) end
			end
		end

		for _, p in ipairs(pairsFound) do
			if not alive or not character.Parent then return end
			local acc, item = p.acc, p.item
			stats.ugc = stats.ugc + 1
			local found = closestRobloxItem(kind, item.name)
			local replacement = found and loadItem(found.id)
			if not alive or not character.Parent then return end
			if acc.Parent == character then
				r.removed[acc] = true
				acc.Parent = nil
				if replacement then
					local copy = replacement:Clone()
					if wear(character, humanoid, copy) then
						r.added[copy] = true
						stats.swapped = stats.swapped + 1
					else
						copy:Destroy()
						stats.removedOnly = stats.removedOnly + 1
					end
				else
					stats.removedOnly = stats.removedOnly + 1
				end
			end
		end
	end
end

-- looked at once its items have settled (and again after an outfit change)
local function queueCharacter(character)
	if pending[character] or not alive then return end
	pending[character] = true
	task.delay(SETTLE, function()
		pending[character] = nil
		if alive and character.Parent then
			local ok, err = pcall(doCharacter, character)
			if not ok then warn("[UGC Remover] " .. tostring(err)) end
		end
	end)
end

local function watchCharacter(character)
	if not character then return end
	queueCharacter(character)
	local added, gone
	added = connect(character.ChildAdded, function(child)
		if child:IsA("Accoutrement") and not child:GetAttribute(MARK) then
			queueCharacter(character)
		end
	end)
	gone = connect(character.AncestryChanged, function(_, parent)
		if parent == nil then
			records[character] = nil
			added:Disconnect()
			gone:Disconnect()
		end
	end)
end

local function watchPlayer(player)
	if player.Character then task.spawn(watchCharacter, player.Character) end
	connect(player.CharacterAdded, function(character)
		-- (its looks come in after it does)
		local loaded = false
		pcall(function() loaded = player:HasAppearanceLoaded() end)
		if not loaded then
			local t = 0
			while alive and t < 6 and character.Parent do
				local ok, done = pcall(function() return player:HasAppearanceLoaded() end)
				if ok and done then break end
				t = t + (task.wait(0.25) or 0.25)
			end
		end
		watchCharacter(character)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do watchPlayer(player) end
connect(Players.PlayerAdded, watchPlayer)

------------------------------------------------------------------------------------------------------------------------
-- PUT BACK
------------------------------------------------------------------------------------------------------------------------
Env.__UGCRemoverCleanup = function()
	alive = false
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	table.clear(conns)
	for character, r in pairs(records) do
		for acc in pairs(r.added) do pcall(function() acc:Destroy() end) end
		if character.Parent then
			for acc in pairs(r.removed) do
				pcall(function() acc.Parent = character end)
			end
		end
	end
	table.clear(records)
	Env.__UGCRemoverCleanup = nil
end

Env.UGCRemover = {
	Stats = function() return { ugc = stats.ugc, swapped = stats.swapped, removedOnly = stats.removedOnly } end,
}

task.delay(12, function()
	if alive then
		print(("[UGC Remover] %d UGC items so far: %d swapped for Roblox's own, %d just taken off")
			:format(stats.ugc, stats.swapped, stats.removedOnly))
	end
end)
print("[UGC Remover] On: UGC items swapped for the closest Roblox-made ones (on your screen only).")
