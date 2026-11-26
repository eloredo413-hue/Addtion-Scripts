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
	    that loads: the UGC item is just taken off. (Layered clothing too: a UGC jacket for Roblox's closest jacket.)
	  * UGC bodies (packages): R15 bodies get each UGC part's shape from the closest Roblox-made body part (by the
	    words of its name, the part's own size and clothes kept); with no Roblox part like it, the classic blocky
	    part. R6 bodies: the UGC package's meshes come off (the classic blocky body).
	  * UGC heads: the classic head with the classic face.
	  * UGC animations: your own character back on Roblox's own animations; other players' UGC walk, run, idle,
	    jump, fall, climb and swim shown with Roblox's own ones on your screen. UGC emotes are stopped.
	  * classic shirts, pants and T-shirts stay (they are the player's clothes, not UGC items).

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
-- BODIES (packages) and HEADS
------------------------------------------------------------------------------------------------------------------------
local BODY = {
	{ field = "Torso", asset = "Torso", r15 = { "UpperTorso", "LowerTorso" }, width = 2 },
	{ field = "LeftArm", asset = "LeftArm", r15 = { "LeftUpperArm", "LeftLowerArm", "LeftHand" }, width = 1 },
	{ field = "RightArm", asset = "RightArm", r15 = { "RightUpperArm", "RightLowerArm", "RightHand" }, width = 1 },
	{ field = "LeftLeg", asset = "LeftLeg", r15 = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" }, width = 1 },
	{ field = "RightLeg", asset = "RightLeg", r15 = { "RightUpperLeg", "RightLowerLeg", "RightFoot" }, width = 1 },
}
-- (words every body part has: they say nothing about which one is alike)
local BODY_WORDS = { body = true, arm = true, leg = true, torso = true, left = true, right = true, head = true,
	package = true, bundle = true, avatar = true, rig = true }

local function descValue(desc, field)
	local v = 0
	pcall(function() v = desc[field] end)
	return tonumber(v) or 0
end

-- the closest Roblox-made body part: only one sharing a word with the UGC one's name (else the classic block)
local bodyTemplates = {}
local function closestRobloxBody(assetType, ugcName)
	if not AvatarEditorService then return nil end
	local words = {}
	for _, w in ipairs((wordsOf(ugcName))) do
		if not BODY_WORDS[w] then table.insert(words, w) end
	end
	if #words == 0 then return nil end
	local best, bestScore = nil, 0
	local tried = {}
	local queries = { table.concat(words, " ", 1, math.min(#words, 3)) }
	for i = 1, math.min(#words, 2) do table.insert(queries, words[i]) end
	for _, q in ipairs(queries) do
		if not tried[q] then
			tried[q] = true
			local key = "body:" .. assetType .. "|" .. q
			local found = searchCache[key]
			if not found then
				found = {}
				lookupTurn()
				local ok = pcall(function()
					local params = CatalogSearchParams.new()
					params.SearchKeyword = q
					params.AssetTypes = { Enum.AvatarAssetType[assetType] }
					params.CreatorName = "Roblox"
					pcall(function() params.IncludeOffSale = true end)
					local pages = AvatarEditorService:SearchCatalog(params)
					for _, item in ipairs(pages:GetCurrentPage()) do
						if item.Id and (item.CreatorName == nil or item.CreatorName == "Roblox") then
							table.insert(found, { id = tonumber(item.Id), name = tostring(item.Name or "") })
						end
					end
				end)
				lookupDone()
				if ok then searchCache[key] = found end
			end
			for _, item in ipairs(found) do
				local have = {}
				for _, w in ipairs((wordsOf(item.name))) do have[w] = true end
				local sc = 0
				for _, w in ipairs(words) do if have[w] then sc = sc + 1 end end
				if sc > bestScore then best, bestScore = item, sc end
			end
			if best then break end
		end
	end
	return best
end

-- a Roblox body part's meshes (R15), by part name
local function bodyMeshes(assetId)
	local t = bodyTemplates[assetId]
	if t ~= nil then return t or nil end
	local model
	pcall(function()
		local objs = game:GetObjects("rbxassetid://" .. tostring(assetId))
		model = objs and objs[1]
	end)
	local byName = nil
	if model then
		local folder = model:FindFirstChild("R15ArtistIntent", true) or model:FindFirstChild("R15Fixed", true)
			or model:FindFirstChild("R15", true) or model
		for _, d in ipairs(folder:GetDescendants()) do
			if d:IsA("MeshPart") then
				byName = byName or {}
				byName[d.Name] = byName[d.Name] or d
			end
		end
	end
	bodyTemplates[assetId] = byName or false
	return byName
end

local function scaleOf(humanoid, name)
	local v = humanoid:FindFirstChild(name)
	return (v and v:IsA("NumberValue")) and v.Value or 1
end

-- the classic blocky part over a (hidden) body part
local function blockOver(part, width, humanoid, r)
	local block = Instance.new("Part")
	block.Name = "BPUGCBlock"
	block.Size = Vector3.new(width * scaleOf(humanoid, "BodyWidthScale"), part.Size.Y, 1 * scaleOf(humanoid, "BodyDepthScale"))
	block.Color = part.Color
	block.Material = Enum.Material.Plastic
	block.CanCollide = false
	pcall(function() block.CanTouch = false block.CanQuery = false end)
	block.Massless = true
	block.Anchored = false
	block.CFrame = part.CFrame
	block:SetAttribute(MARK, true)
	local weld = Instance.new("Weld")
	weld.Part0 = part
	weld.Part1 = block
	weld.Parent = block
	r.hidden[part] = r.hidden[part] or part.Transparency
	part.Transparency = 1
	block.Parent = part
	r.made[block] = true
	return block
end

local function swapBodyPart(part, roblox, width, humanoid, r)
	if roblox and roblox[part.Name] and part:IsA("MeshPart") then
		-- (a copy of the part's own mesh first, to put it back with)
		local okCopy, original = pcall(function() return part:Clone() end)
		if okCopy and original then
			for _, c in ipairs(original:GetChildren()) do c:Destroy() end
			local ok = pcall(function() part:ApplyMesh(roblox[part.Name]) end)
			if ok then
				r.meshes[part] = original
				return "roblox"
			end
			original:Destroy()
		end
	end
	blockOver(part, width, humanoid, r)
	return "block"
end

-- the classic head (2006's: the head shape, the smile) over a UGC head
local CLASSIC_FACE = "rbxasset://textures/face.png"
local function classicHead(character, humanoid, head, r)
	if character:FindFirstChild("BPClassicHeadMesh", true) then return false end -- (classic face already did it)
	if head:IsA("BasePart") and not head:IsA("MeshPart") then
		-- (an R6 head: its mesh made the classic one)
		local mesh = head:FindFirstChildWhichIsA("SpecialMesh")
		if mesh then
			r.headMesh = r.headMesh or { mesh = mesh, MeshType = mesh.MeshType, MeshId = mesh.MeshId,
				TextureId = mesh.TextureId, Scale = mesh.Scale }
			mesh.MeshType = Enum.MeshType.Head
			pcall(function() mesh.MeshId = "" mesh.TextureId = "" end)
			mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
		end
		if not head:FindFirstChildWhichIsA("Decal") then
			local face = Instance.new("Decal")
			face.Name = "face"
			face.Texture = CLASSIC_FACE
			face.Face = Enum.NormalId.Front
			face:SetAttribute(MARK, true)
			face.Parent = head
			r.made[face] = true
		end
		return true
	end
	-- (an R15 head: hidden, and the classic one on it)
	local scale = scaleOf(humanoid, "HeadScale")
	local fake = Instance.new("Part")
	fake.Name = "BPUGCClassicHead"
	fake.Size = Vector3.new(2, 1, 1) * scale
	fake.Color = head.Color
	fake.CanCollide = false
	pcall(function() fake.CanTouch = false fake.CanQuery = false end)
	fake.Massless = true
	fake.CFrame = head.CFrame
	fake:SetAttribute(MARK, true)
	local mesh = Instance.new("SpecialMesh")
	mesh.Name = "Mesh"
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = fake
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = CLASSIC_FACE
	face.Face = Enum.NormalId.Front
	face.Parent = fake
	local weld = Instance.new("Weld")
	weld.Part0 = head
	weld.Part1 = fake
	weld.Parent = fake
	r.hidden[head] = r.hidden[head] or head.Transparency
	head.Transparency = 1
	for _, d in ipairs(head:GetChildren()) do
		if d:IsA("Decal") then
			r.hidden[d] = r.hidden[d] or d.Transparency
			d.Transparency = 1
		end
	end
	fake.Parent = head
	r.made[fake] = true
	return true
end

local function doBody(character, humanoid, desc, r)
	local isR15 = humanoid.RigType == Enum.HumanoidRigType.R15
	for _, spec in ipairs(BODY) do
		local id = descValue(desc, spec.field)
		if id > 0 and not r.body[spec.field] then
			local info = productInfo(id)
			if not alive or not character.Parent then return end
			if info and not madeByRoblox(info) then
				r.body[spec.field] = true
				stats.ugc = stats.ugc + 1
				if isR15 then
					local found = closestRobloxBody(spec.asset, tostring(info.Name or ""))
					local roblox = found and bodyMeshes(found.id)
					local how
					for _, name in ipairs(spec.r15) do
						local part = character:FindFirstChild(name)
						if part and part:IsA("BasePart") then
							how = swapBodyPart(part, roblox, spec.width, humanoid, r)
						end
					end
					if how == "roblox" then stats.swapped = stats.swapped + 1 else stats.removedOnly = stats.removedOnly + 1 end
				else
					-- R6: the package's mesh for this part off (the classic blocky body)
					for _, cm in ipairs(character:GetChildren()) do
						if cm:IsA("CharacterMesh") and enumName(cm.BodyPart) == spec.field then
							r.removed[cm] = true
							cm.Parent = nil
						end
					end
					stats.removedOnly = stats.removedOnly + 1
				end
			end
		end
	end
	local headId = descValue(desc, "Head")
	if headId > 0 and not r.body.Head then
		local info = productInfo(headId)
		if not alive or not character.Parent then return end
		if info and not madeByRoblox(info) then
			r.body.Head = true
			stats.ugc = stats.ugc + 1
			local head = character:FindFirstChild("Head")
			if head and classicHead(character, humanoid, head, r) then
				stats.swapped = stats.swapped + 1
			end
		end
	end
end

------------------------------------------------------------------------------------------------------------------------
-- ANIMATIONS and EMOTES
------------------------------------------------------------------------------------------------------------------------
-- Roblox's own (the R15 Animate script's), by the Animate script's names
local DEFAULT_ANIMS = {
	walk = { WalkAnim = 913402848 }, run = { RunAnim = 913376220 }, jump = { JumpAnim = 507765000 },
	fall = { FallAnim = 507767968 }, climb = { ClimbAnim = 507765644 }, swim = { Swim = 913384386 },
	swimidle = { SwimIdle = 913389285 }, idle = { Animation1 = 507766666, Animation2 = 507766951 },
}
local FIRST_DEFAULT = { walk = 913402848, run = 913376220, jump = 507765000, fall = 507767968, climb = 507765644,
	swim = 913384386, swimidle = 913389285, idle = 507766666 }
local ANIM_FIELDS = {
	WalkAnimation = "walk", RunAnimation = "run", JumpAnimation = "jump", FallAnimation = "fall",
	ClimbAnimation = "climb", IdleAnimation = "idle", SwimAnimation = "swim",
}
local LOOPED = { walk = true, run = true, idle = true, climb = true, swim = true, swimidle = true, fall = true }
local animPackCache = {}

local function idOf(s)
	return tonumber(string.match(tostring(s or ""), "%d+$")) or tonumber(string.match(tostring(s or ""), "id=(%d+)"))
end

-- the animations inside a catalog animation (their ids, and which Animate slot each is for)
local function animationsIn(assetId)
	local t = animPackCache[assetId]
	if t ~= nil then return t or {} end
	local list = {}
	pcall(function()
		local objs = game:GetObjects("rbxassetid://" .. tostring(assetId))
		for _, o in ipairs(objs or {}) do
			for _, d in ipairs(o:GetDescendants()) do
				if d:IsA("Animation") then
					local id = idOf(d.AnimationId)
					if id then table.insert(list, { id = id, slot = d.Parent and string.lower(d.Parent.Name) or nil, name = d.Name }) end
				end
			end
		end
	end)
	animPackCache[assetId] = (#list > 0) and list or false
	return list
end

local function emoteIds(desc)
	local ids = {}
	pcall(function()
		for _, list in pairs(desc:GetEmotes()) do
			for _, id in ipairs(list) do table.insert(ids, tonumber(id)) end
		end
	end)
	return ids
end

-- [character] = { [animation id] = slot or "emote" }
local ugcAnims = {}

local function doAnimations(character, humanoid, desc, r)
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then return end
	local set = ugcAnims[character] or {}
	ugcAnims[character] = set
	for field, slot in pairs(ANIM_FIELDS) do
		local id = descValue(desc, field)
		if id > 0 and not r.anims[field] then
			local info = productInfo(id)
			if not alive or not character.Parent then return end
			r.anims[field] = true
			if info and not madeByRoblox(info) then
				stats.ugc = stats.ugc + 1
				for _, a in ipairs(animationsIn(id)) do
					set[a.id] = (a.slot and DEFAULT_ANIMS[a.slot]) and a.slot or slot
				end
				stats.swapped = stats.swapped + 1
			end
		end
	end
	for _, id in ipairs(emoteIds(desc)) do
		if id and id > 0 and not r.anims["emote" .. id] then
			r.anims["emote" .. id] = true
			local info = productInfo(id)
			if not alive or not character.Parent then return end
			if info and not madeByRoblox(info) then
				stats.ugc = stats.ugc + 1
				for _, a in ipairs(animationsIn(id)) do set[a.id] = "emote" end
				stats.removedOnly = stats.removedOnly + 1
			end
		end
	end
	if next(set) == nil then return end

	-- your own character: its Animate script back on Roblox's own (it picks the change up itself)
	if character == (Players.LocalPlayer and Players.LocalPlayer.Character) then
		local animate = character:FindFirstChild("Animate")
		if animate then
			for _, a in ipairs(animate:GetDescendants()) do
				if a:IsA("Animation") then
					local id = idOf(a.AnimationId)
					local slot = id and set[id]
					if slot and slot ~= "emote" then
						local slotName = a.Parent and string.lower(a.Parent.Name) or slot
						local want = (DEFAULT_ANIMS[slotName] and DEFAULT_ANIMS[slotName][a.Name]) or FIRST_DEFAULT[slot]
						if want then
							r.animate[a] = r.animate[a] or a.AnimationId
							a.AnimationId = "http://www.roblox.com/asset/?id=" .. tostring(want)
						end
					end
				end
			end
		end
	end

	-- every character: a UGC track that starts is stopped; a moving one is shown with Roblox's own instead
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator or r.animConn then return end
	local mine = {}   -- [slot] = our track (Roblox's own)
	r.ourTracks = mine
	local function stopOurs(except)
		for slot, tr in pairs(mine) do
			if slot ~= except then pcall(function() tr:Stop(0.15) end) end
		end
	end
	r.animConn = connect(animator.AnimationPlayed, function(track)
		if not alive then return end
		local anim = track.Animation
		local id = anim and idOf(anim.AnimationId)
		if not id then return end
		local slot = set[id]
		if slot then
			pcall(function() track:Stop(0.1) end)
			local isMine = character == (Players.LocalPlayer and Players.LocalPlayer.Character)
			if slot == "emote" or isMine or not FIRST_DEFAULT[slot] then return end
			stopOurs(slot)
			local ours = mine[slot]
			if not ours then
				local a = Instance.new("Animation")
				a.AnimationId = "http://www.roblox.com/asset/?id=" .. tostring(FIRST_DEFAULT[slot])
				local ok, t = pcall(function() return animator:LoadAnimation(a) end)
				if not ok or not t then return end
				ours = t
				pcall(function() ours.Looped = LOOPED[slot] == true end)
				mine[slot] = ours
			end
			pcall(function()
				if not ours.IsPlaying then ours:Play(0.15) end
				ours:AdjustSpeed(track.Speed or 1)
			end)
		else
			-- something else of the player's own (Roblox's, or the game's) took over: ours make way
			local ours = false
			for _, tr in pairs(mine) do if tr == track then ours = true end end
			if not ours then
				local prio = nil
				pcall(function() prio = enumName(track.Priority) end)
				if prio == "Core" or prio == "Idle" or prio == "Movement" then stopOurs(nil) end
			end
		end
	end)
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
		r = { removed = {}, added = {}, made = {}, hidden = {}, meshes = {}, body = {}, anims = {}, animate = {} }
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

local doAccessories
local function doCharacter(character)
	if not alive or not character.Parent then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local r = recordOf(character)
	doAccessories(character, humanoid, r)
	if not alive or not character.Parent then return end
	local ok, desc = pcall(function() return humanoid:GetAppliedDescription() end)
	if ok and desc then
		doBody(character, humanoid, desc, r)
		if not alive or not character.Parent then return end
		doAnimations(character, humanoid, desc, r)
	end
end

doAccessories = function(character, humanoid, r)

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
	if next(onIt) == nil then return end -- (nothing more to do for accessories)

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
		if (child:IsA("Accoutrement") and not child:GetAttribute(MARK)) or child.Name == "Animate"
			or child:IsA("CharacterMesh") then
			queueCharacter(character)
		end
	end)
	gone = connect(character.AncestryChanged, function(_, parent)
		if parent == nil then
			local r = records[character]
			if r and r.animConn then pcall(function() r.animConn:Disconnect() end) end
			records[character] = nil
			ugcAnims[character] = nil
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
		for thing in pairs(r.made) do pcall(function() thing:Destroy() end) end
		for thing, was in pairs(r.hidden) do pcall(function() thing.Transparency = was end) end
		for part, original in pairs(r.meshes) do
			pcall(function() part:ApplyMesh(original) end)
			pcall(function() original:Destroy() end)
		end
		if r.headMesh then
			local h = r.headMesh
			pcall(function()
				h.mesh.MeshType = h.MeshType
				h.mesh.MeshId = h.MeshId
				h.mesh.TextureId = h.TextureId
				h.mesh.Scale = h.Scale
			end)
		end
		for a, was in pairs(r.animate) do pcall(function() a.AnimationId = was end) end
		for _, tr in pairs(r.ourTracks or {}) do pcall(function() tr:Stop(0) tr:Destroy() end) end
		if character.Parent then
			for acc in pairs(r.removed) do
				pcall(function() acc.Parent = character end)
			end
		end
	end
	table.clear(records)
	table.clear(ugcAnims)
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
print("[UGC Remover] On: UGC items, bodies, heads and animations swapped for the closest Roblox-made ones (on your screen only).")
