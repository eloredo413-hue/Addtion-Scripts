--[[
	UGC REMOVER (Addtion-Scripts)
	Everything UGC (made by players, not by Roblox) on every player, swapped on your screen only for the closest thing
	Roblox made itself:

	  * hats, hair, layered clothes and the rest: taken off as soon as they're known to be UGC, then the closest
	    Roblox item of the same kind (hair for hair, a hat for a hat) put on in their place, found with the game's
	    catalog search (Roblox's items only) by the words of the UGC item's name; colour counts most for hair. With
	    nothing close, or nothing that loads, it just stays off.
	  * UGC bodies (packages): R15: each UGC part gets the shape of the closest Roblox-made body part (its own size
	    and clothes kept), else the classic blocky part. R6: the package's meshes come off (the classic blocky body).
	  * UGC heads: the classic head with the classic face.
	  * UGC animations: your own character back on Roblox's own; other players' UGC walk, run, idle, jump, fall,
	    climb and swim shown with Roblox's own. UGC emotes are stopped.
	  * classic shirts, pants and T-shirts stay (they are clothes, not UGC items).

	HOW IT KEEPS FROM LAGGING: what everyone wears is looked up in batches (one catalog request for up to 50 items,
	AvatarEditorService:GetBatchItemDetailsAsync), not one item at a time; each item is looked up only once. Nothing
	runs every frame: one worker does the lookups, the catalog searches and the loading, one thing at a time with a
	pause between, your own character first; it sleeps when there's nothing to do.
	Run again to start over; getgenv().__UGCRemoverCleanup() puts everything back.
]]

local Env = (getgenv and getgenv()) or _G
if type(Env.__UGCRemoverCleanup) == "function" then pcall(Env.__UGCRemoverCleanup) end

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local AvatarEditorService
pcall(function() AvatarEditorService = game:GetService("AvatarEditorService") end)

local ROBLOX_ID = 1
local MARK = "BPUGCReplacement"   -- (an attribute on what this puts on)
local SETTLE = 0.6                 -- seconds a character's items are left to settle before they're looked at
local BATCH = 50                   -- items per catalog request
local BUSY_PAUSE = 0.15            -- seconds between two pieces of work
local IDLE_PAUSE = 0.5             -- seconds between looks when there's nothing to do
local LOAD_PAUSE = 0.3             -- seconds after loading an item (loading is the heavy part)

local alive = true
local conns = {}
local records = {}       -- [character] = what was done to it (to put it back)
local info = {}          -- [asset id] = { name = ..., roblox = true/false }
local wanted = {}        -- [asset id] = tries so far (waiting to be looked up)
local waiting = {}       -- [character] = its items, waiting for their lookups
local pending = {}       -- [character] = true while it waits to be scanned
local jobs = {}          -- searches and loads, in order (your own character's first)
local searchCache = {}   -- [kind | words] = found items
local closestCache = {}  -- [ugc asset id] = the Roblox item picked (or false)
local templates = {}     -- [asset id] = the loaded Roblox item (or false)
local bodyTemplates = {} -- [asset id] = { [part name] = MeshPart } (or false)
local animPackCache = {} -- [asset id] = { { id, slot } } (or false)
local ugcAnims = {}      -- [character] = { [animation id] = slot or "emote" }
local stats = { ugc = 0, swapped = 0, removedOnly = 0 }

local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(conns, c)
	return c
end

local function localCharacter()
	return Players.LocalPlayer and Players.LocalPlayer.Character
end

local function enumName(v)
	if typeof and typeof(v) == "EnumItem" then return v.Name end
	if type(v) == "userdata" or type(v) == "table" then
		local ok, n = pcall(function() return v.Name end)
		if ok and type(n) == "string" then return n end
	end
	if type(v) == "string" then return (string.gsub(v, "^Enum%.%w+%.", "")) end
	return tostring(v)
end

------------------------------------------------------------------------------------------------------------------------
-- LOOKUPS (in batches)
------------------------------------------------------------------------------------------------------------------------
local function isRoblox(targetId, name, ctype)
	targetId = tonumber(targetId)
	local typeName = ctype and enumName(ctype) or nil
	if targetId == ROBLOX_ID and (typeName == nil or typeName == "User") then return true end
	return name == "Roblox"
end

local batchWorks = true
local function lookupBatch(ids)
	if not (AvatarEditorService and batchWorks) then return false end
	local ok, res = pcall(function()
		return AvatarEditorService:GetBatchItemDetailsAsync(ids, Enum.AvatarItemType.Asset)
	end)
	if not ok then
		ok, res = pcall(function()
			return AvatarEditorService:GetBatchItemDetails(ids, Enum.AvatarItemType.Asset)
		end)
	end
	if not ok or type(res) ~= "table" then
		batchWorks = false -- (not here: one at a time from now on)
		return false
	end
	for _, d in ipairs(res) do
		local id = tonumber(d.Id)
		if id then
			info[id] = { name = tostring(d.Name or ""), roblox = isRoblox(d.CreatorTargetId, d.CreatorName, d.CreatorType) }
			wanted[id] = nil
		end
	end
	return true
end

local function lookupOne(id)
	local ok, res = pcall(function() return MarketplaceService:GetProductInfo(id, Enum.InfoType.Asset) end)
	if ok and type(res) == "table" then
		local c = type(res.Creator) == "table" and res.Creator or {}
		info[id] = { name = tostring(res.Name or ""),
			roblox = isRoblox(c.CreatorTargetId or c.Id, c.Name, c.CreatorType) }
		wanted[id] = nil
		return true
	end
	return false
end

------------------------------------------------------------------------------------------------------------------------
-- WORDS of a name
------------------------------------------------------------------------------------------------------------------------
local COLORS = {
	black = true, white = true, brown = true, blonde = true, red = true, orange = true, yellow = true,
	green = true, blue = true, purple = true, pink = true, grey = true, silver = true, gold = true,
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
			if COLORS[w] then table.insert(colors, w) else table.insert(list, w) end
		end
	end
	return list, colors
end

------------------------------------------------------------------------------------------------------------------------
-- KINDS of items
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
-- THE CLOSEST ROBLOX ITEM (at most two catalog searches each, kept)
------------------------------------------------------------------------------------------------------------------------
local function search(assetType, words)
	if not AvatarEditorService then return {} end
	local key = assetType .. "|" .. words
	if searchCache[key] then return searchCache[key] end
	local found = {}
	local ok = pcall(function()
		local params = CatalogSearchParams.new()
		params.SearchKeyword = words
		params.AssetTypes = { Enum.AvatarAssetType[assetType] }
		params.CreatorName = "Roblox"
		pcall(function() params.IncludeOffSale = true end)
		pcall(function() params.Limit = 30 end)
		local pages = AvatarEditorService:SearchCatalog(params)
		for _, item in ipairs(pages:GetCurrentPage()) do
			local by = item.CreatorName
			if item.Id and (by == nil or by == "Roblox") then
				table.insert(found, { id = tonumber(item.Id), name = tostring(item.Name or "") })
			end
		end
	end)
	if ok then searchCache[key] = found end
	return found
end

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

local function closestRobloxItem(kind, ugcId, ugcName)
	if closestCache[ugcId] ~= nil then return closestCache[ugcId] or nil end
	local spec = KINDS[kind]
	if not spec then closestCache[ugcId] = false return nil end
	local words, colors = wordsOf(ugcName)
	local color = colors[1] and (colors[1] .. " ") or ""
	local main = {}
	for i = 1, math.min(#words, 3) do main[i] = words[i] end
	local queries = {}
	if #main > 0 then table.insert(queries, color .. table.concat(main, " ")) end
	table.insert(queries, color .. spec.plain)
	local best, bestScore, first = nil, -1, nil
	for _, q in ipairs(queries) do
		for _, item in ipairs(search(spec.asset, q)) do
			first = first or item
			local sc = score(kind, item.name, words, colors)
			if sc > bestScore then best, bestScore = item, sc end
		end
		if best and bestScore >= 3 then break end
		if not alive then return nil end
	end
	best = best or first
	closestCache[ugcId] = best or false
	return best
end

local function loadModel(assetId)
	local model
	pcall(function()
		local objs = game:GetObjects("rbxassetid://" .. tostring(assetId))
		model = objs and objs[1]
	end)
	return model
end

local function loadItem(assetId)
	local t = templates[assetId]
	if t ~= nil then return t or nil end
	local model = loadModel(assetId)
	local acc = nil
	if model then
		acc = model:IsA("Accoutrement") and model or model:FindFirstChildWhichIsA("Accoutrement", true)
	end
	templates[assetId] = acc or false
	return acc
end

-- put it on: Roblox's own way, or welded to the matching attachment by hand
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
	local mine
	for _, a in ipairs(handle:GetChildren()) do
		if a:IsA("Attachment") then mine = a break end
	end
	local theirs = mine and character:FindFirstChild(mine.Name, true)
	local w = Instance.new("Weld")
	w.Name = "AccessoryWeld"
	w.Part0 = handle
	if theirs and theirs:IsA("Attachment") and theirs.Parent and theirs.Parent:IsA("BasePart") then
		w.Part1 = theirs.Parent
		w.C0 = mine.CFrame
		w.C1 = theirs.CFrame
	else
		local head = character:FindFirstChild("Head")
		if not head then w:Destroy() return false end
		w.Part1 = head
		w.C1 = CFrame.new(0, 0.6, 0)
	end
	acc.Parent = character
	w.Parent = handle
	return true
end

------------------------------------------------------------------------------------------------------------------------
-- BODIES and HEADS
------------------------------------------------------------------------------------------------------------------------
local BODY = {
	{ field = "Torso", r15 = { "UpperTorso", "LowerTorso" }, width = 2 },
	{ field = "LeftArm", r15 = { "LeftUpperArm", "LeftLowerArm", "LeftHand" }, width = 1 },
	{ field = "RightArm", r15 = { "RightUpperArm", "RightLowerArm", "RightHand" }, width = 1 },
	{ field = "LeftLeg", r15 = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" }, width = 1 },
	{ field = "RightLeg", r15 = { "RightUpperLeg", "RightLowerLeg", "RightFoot" }, width = 1 },
}
local BODY_WORDS = { body = true, arm = true, leg = true, torso = true, left = true, right = true, head = true,
	package = true, bundle = true, avatar = true, rig = true }

local function closestRobloxBody(assetType, ugcId, ugcName)
	if closestCache[ugcId] ~= nil then return closestCache[ugcId] or nil end
	local words = {}
	for _, w in ipairs((wordsOf(ugcName))) do
		if not BODY_WORDS[w] then table.insert(words, w) end
	end
	local best, bestScore = nil, 0
	if #words > 0 then
		for _, item in ipairs(search(assetType, table.concat(words, " ", 1, math.min(#words, 3)))) do
			local have = {}
			for _, w in ipairs((wordsOf(item.name))) do have[w] = true end
			local sc = 0
			for _, w in ipairs(words) do if have[w] then sc = sc + 1 end end
			if sc > bestScore then best, bestScore = item, sc end
		end
	end
	closestCache[ugcId] = best or false
	return best
end

local function bodyMeshes(assetId)
	local t = bodyTemplates[assetId]
	if t ~= nil then return t or nil end
	local model = loadModel(assetId)
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

local function blockOver(part, width, humanoid, r)
	local block = Instance.new("Part")
	block.Name = "BPUGCBlock"
	block.Size = Vector3.new(width * scaleOf(humanoid, "BodyWidthScale"), part.Size.Y, 1 * scaleOf(humanoid, "BodyDepthScale"))
	block.Color = part.Color
	block.Material = Enum.Material.Plastic
	block.CanCollide = false
	pcall(function() block.CanTouch = false block.CanQuery = false end)
	block.Massless = true
	block.CFrame = part.CFrame
	block:SetAttribute(MARK, true)
	local weld = Instance.new("Weld")
	weld.Part0 = part
	weld.Part1 = block
	weld.Parent = block
	if r.hidden[part] == nil then r.hidden[part] = part.Transparency end
	part.Transparency = 1
	block.Parent = part
	r.made[block] = true
end

local function swapBodyPart(part, roblox, width, humanoid, r)
	if roblox and roblox[part.Name] and part:IsA("MeshPart") then
		local okCopy, original = pcall(function() return part:Clone() end)
		if okCopy and original then
			for _, c in ipairs(original:GetChildren()) do c:Destroy() end
			if pcall(function() part:ApplyMesh(roblox[part.Name]) end) then
				r.meshes[part] = original
				return "roblox"
			end
			original:Destroy()
		end
	end
	blockOver(part, width, humanoid, r)
	return "block"
end

local CLASSIC_FACE = "rbxasset://textures/face.png"
local function classicHead(character, humanoid, head, r)
	if character:FindFirstChild("BPClassicHeadMesh", true) then return false end -- (classic face did it already)
	if not head:IsA("MeshPart") then
		-- R6: its mesh made the classic one
		local mesh = head:FindFirstChildWhichIsA("SpecialMesh")
		if mesh and not r.headMesh then
			r.headMesh = { mesh = mesh, MeshType = mesh.MeshType, MeshId = mesh.MeshId, TextureId = mesh.TextureId,
				Scale = mesh.Scale }
			mesh.MeshType = Enum.MeshType.Head
			pcall(function() mesh.MeshId = "" mesh.TextureId = "" end)
			mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
		end
		if not head:FindFirstChildWhichIsA("Decal") then
			local face = Instance.new("Decal")
			face.Name = "face"
			face.Texture = CLASSIC_FACE
			face.Face = Enum.NormalId.Front
			face.Parent = head
			r.made[face] = true
		end
		return true
	end
	-- R15: hidden, the classic head on it
	local fake = Instance.new("Part")
	fake.Name = "BPUGCClassicHead"
	fake.Size = Vector3.new(2, 1, 1) * scaleOf(humanoid, "HeadScale")
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
	if r.hidden[head] == nil then r.hidden[head] = head.Transparency end
	head.Transparency = 1
	for _, d in ipairs(head:GetChildren()) do
		if d:IsA("Decal") then
			if r.hidden[d] == nil then r.hidden[d] = d.Transparency end
			d.Transparency = 1
		end
	end
	fake.Parent = head
	r.made[fake] = true
	return true
end

------------------------------------------------------------------------------------------------------------------------
-- ANIMATIONS and EMOTES
------------------------------------------------------------------------------------------------------------------------
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

local function idOf(s)
	return tonumber(string.match(tostring(s or ""), "id=(%d+)")) or tonumber(string.match(tostring(s or ""), "(%d+)$"))
end

local function animationsIn(assetId)
	local t = animPackCache[assetId]
	if t ~= nil then return t or {} end
	local list = {}
	local model = loadModel(assetId)
	if model then
		local all = model:GetDescendants()
		table.insert(all, model)
		for _, d in ipairs(all) do
			if d:IsA("Animation") then
				local id = idOf(d.AnimationId)
				if id then table.insert(list, { id = id, slot = d.Parent and string.lower(d.Parent.Name) or nil }) end
			end
		end
	end
	animPackCache[assetId] = (#list > 0) and list or false
	return list
end

-- your own Animate script back on Roblox's own animations
local function fixMyAnimate(character, set, r)
	local animate = character:FindFirstChild("Animate")
	if not animate then return end
	for _, a in ipairs(animate:GetDescendants()) do
		if a:IsA("Animation") then
			local id = idOf(a.AnimationId)
			local slot = id and set[id]
			if slot and slot ~= "emote" then
				local slotName = a.Parent and string.lower(a.Parent.Name) or slot
				local want = (DEFAULT_ANIMS[slotName] and DEFAULT_ANIMS[slotName][a.Name]) or FIRST_DEFAULT[slot]
				if want then
					if r.animate[a] == nil then r.animate[a] = a.AnimationId end
					a.AnimationId = "http://www.roblox.com/asset/?id=" .. tostring(want)
				end
			end
		end
	end
end

-- every character: a UGC track that starts is stopped; a moving one shown with Roblox's own instead
local function watchTracks(character, humanoid, set, r)
	if r.animConn then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end
	local mine = {}
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
			if slot == "emote" or character == localCharacter() or not FIRST_DEFAULT[slot] then return end
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
			for _, tr in pairs(mine) do if tr == track then return end end
			local prio = nil
			pcall(function() prio = enumName(track.Priority) end)
			if prio == "Core" or prio == "Idle" or prio == "Movement" then stopOurs(nil) end
		end
	end)
end

------------------------------------------------------------------------------------------------------------------------
-- A CHARACTER
------------------------------------------------------------------------------------------------------------------------
local function recordOf(character)
	local r = records[character]
	if not r then
		r = { removed = {}, added = {}, made = {}, hidden = {}, meshes = {}, animate = {}, done = {} }
		records[character] = r
	end
	return r
end

local function descValue(desc, field)
	local v = 0
	pcall(function() v = desc[field] end)
	return tonumber(v) or 0
end

-- everything a player wears that could be UGC: { id, what, kind / field / slot }
local function itemsOf(humanoid)
	local list = {}
	local ok, desc = pcall(function() return humanoid:GetAppliedDescription() end)
	if not ok or not desc then return list end
	pcall(function()
		for _, a in ipairs(desc:GetAccessories(true)) do
			local id = tonumber(a.AssetId)
			local kind = enumName(a.AccessoryType)
			if id and id > 0 and not LEAVE_ALONE[kind] then
				table.insert(list, { id = id, what = "accessory", kind = kind })
			end
		end
	end)
	for _, spec in ipairs(BODY) do
		local id = descValue(desc, spec.field)
		if id > 0 then table.insert(list, { id = id, what = "body", spec = spec }) end
	end
	local headId = descValue(desc, "Head")
	if headId > 0 then table.insert(list, { id = headId, what = "head" }) end
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		for field, slot in pairs(ANIM_FIELDS) do
			local id = descValue(desc, field)
			if id > 0 then table.insert(list, { id = id, what = "anim", slot = slot }) end
		end
		pcall(function()
			for _, ids in pairs(desc:GetEmotes()) do
				for _, id in ipairs(ids) do
					id = tonumber(id)
					if id and id > 0 then table.insert(list, { id = id, what = "emote" }) end
				end
			end
		end)
	end
	return list
end

local function normal(s)
	return (string.gsub(string.lower(tostring(s or "")), "[^%w]", ""))
end

local function addJob(job)
	if job.character == localCharacter() then
		table.insert(jobs, 1, job)
	else
		table.insert(jobs, job)
	end
end

-- the items are all looked up: UGC accessories off now (their Roblox ones come after), heads now, the rest queued
local function apply(character, items)
	if not alive or not character.Parent then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local r = recordOf(character)

	-- accessories
	local byKind = {}
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accoutrement") and not child:GetAttribute(MARK) and not r.removed[child] then
			local kind = kindOfAccessory(child)
			byKind[kind] = byKind[kind] or {}
			table.insert(byKind[kind], child)
		end
	end
	local ugcByKind, robloxByKind = {}, {}
	for _, item in ipairs(items) do
		local known = info[item.id]
		if item.what == "accessory" and known then
			item.name = known.name
			local into = known.roblox and robloxByKind or ugcByKind
			into[item.kind] = into[item.kind] or {}
			table.insert(into[item.kind], item)
		end
	end
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
	for kind, list in pairs(ugcByKind) do
		local left = {}
		for _, acc in ipairs(byKind[kind] or {}) do table.insert(left, acc) end
		local found, unmatched = {}, {}
		for _, item in ipairs(list) do
			local acc = takeNamed(left, item)
			if acc then table.insert(found, { item = item, acc = acc }) else table.insert(unmatched, item) end
		end
		local robloxLeft = 0
		for _, item in ipairs(robloxByKind[kind] or {}) do
			if not takeNamed(left, item) then robloxLeft = robloxLeft + 1 end
		end
		if #unmatched > 0 and robloxLeft == 0 then
			for i, item in ipairs(unmatched) do
				if left[i] then table.insert(found, { item = item, acc = left[i] }) end
			end
		end
		for _, p in ipairs(found) do
			if p.acc.Parent == character then
				stats.ugc = stats.ugc + 1
				r.removed[p.acc] = true
				p.acc.Parent = nil -- (off now; Roblox's closest goes on when it's found)
				addJob({ what = "accessory", character = character, kind = kind, id = p.item.id, name = p.item.name })
			end
		end
	end

	-- bodies, heads, animations, emotes
	local isR15 = humanoid.RigType == Enum.HumanoidRigType.R15
	for _, item in ipairs(items) do
		local known = info[item.id]
		if known and not known.roblox and not r.done[item.what .. ":" .. item.id] then
			r.done[item.what .. ":" .. item.id] = true
			if item.what == "head" then
				stats.ugc = stats.ugc + 1
				local head = character:FindFirstChild("Head")
				if head and classicHead(character, humanoid, head, r) then stats.swapped = stats.swapped + 1 end
			elseif item.what == "body" then
				stats.ugc = stats.ugc + 1
				if isR15 then
					addJob({ what = "body", character = character, spec = item.spec, id = item.id, name = known.name })
				else
					for _, cm in ipairs(character:GetChildren()) do
						if cm:IsA("CharacterMesh") and enumName(cm.BodyPart) == item.spec.field then
							r.removed[cm] = true
							cm.Parent = nil
						end
					end
					stats.removedOnly = stats.removedOnly + 1
				end
			elseif item.what == "anim" or item.what == "emote" then
				stats.ugc = stats.ugc + 1
				addJob({ what = item.what, character = character, id = item.id, slot = item.slot })
			end
		end
	end
end

-- a queued search / load
local function runJob(job)
	local character = job.character
	if not character.Parent then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local r = recordOf(character)
	if job.what == "accessory" then
		local found = closestRobloxItem(job.kind, job.id, job.name)
		local template = found and loadItem(found.id)
		if not alive or not character.Parent then return end
		if template then
			local copy = template:Clone()
			if wear(character, humanoid, copy) then
				r.added[copy] = true
				stats.swapped = stats.swapped + 1
				return
			end
			copy:Destroy()
		end
		stats.removedOnly = stats.removedOnly + 1
	elseif job.what == "body" then
		local found = closestRobloxBody(job.spec.field, job.id, job.name)
		local roblox = found and bodyMeshes(found.id)
		if not alive or not character.Parent then return end
		local how
		for _, name in ipairs(job.spec.r15) do
			local part = character:FindFirstChild(name)
			if part and part:IsA("BasePart") then how = swapBodyPart(part, roblox, job.spec.width, humanoid, r) end
		end
		if how == "roblox" then stats.swapped = stats.swapped + 1 else stats.removedOnly = stats.removedOnly + 1 end
	else
		local set = ugcAnims[character] or {}
		ugcAnims[character] = set
		for _, a in ipairs(animationsIn(job.id)) do
			if job.what == "emote" then
				set[a.id] = "emote"
			else
				set[a.id] = (a.slot and DEFAULT_ANIMS[a.slot]) and a.slot or job.slot
			end
		end
		if not alive or not character.Parent then return end
		if job.what == "emote" then stats.removedOnly = stats.removedOnly + 1 else stats.swapped = stats.swapped + 1 end
		if character == localCharacter() then fixMyAnimate(character, set, r) end
		watchTracks(character, humanoid, set, r)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- THE WORKER: lookups in batches, then one search / load at a time; asleep when there's nothing to do
------------------------------------------------------------------------------------------------------------------------
local function scan(character)
	if not alive or not character.Parent then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local items = itemsOf(humanoid)
	for _, item in ipairs(items) do
		if info[item.id] == nil and wanted[item.id] == nil then wanted[item.id] = 0 end
	end
	waiting[character] = items
end

local function worker()
	while alive do
		local busy = false
		-- 1. lookups: up to BATCH at a time
		local ids = {}
		for id in pairs(wanted) do
			table.insert(ids, id)
			if #ids >= BATCH then break end
		end
		if #ids > 0 then
			busy = true
			if not lookupBatch(ids) then
				-- (no batch lookups here: one at a time)
				local id = ids[1]
				if not lookupOne(id) then
					wanted[id] = (wanted[id] or 0) + 1
					if wanted[id] >= 3 then wanted[id] = nil info[id] = { name = "", roblox = true, unknown = true } end
				end
			else
				-- (anything the batch didn't know: the old way, one at a time, a couple of tries)
				for _, id in ipairs(ids) do
					if wanted[id] ~= nil then
						wanted[id] = wanted[id] + 1
						if wanted[id] >= 2 and not lookupOne(id) and wanted[id] >= 3 then
							wanted[id] = nil
							info[id] = { name = "", roblox = true, unknown = true }
						end
					end
				end
			end
		end
		if not alive then return end
		-- 2. characters whose items are all known
		for character, items in pairs(waiting) do
			local ready = true
			for _, item in ipairs(items) do
				if info[item.id] == nil then ready = false break end
			end
			if ready then
				waiting[character] = nil
				local ok, err = pcall(apply, character, items)
				if not ok then warn("[UGC Remover] " .. tostring(err)) end
				busy = true
			end
		end
		-- 3. one search / load
		local job = table.remove(jobs, 1)
		if job then
			busy = true
			local ok, err = pcall(runJob, job)
			if not ok then warn("[UGC Remover] " .. tostring(err)) end
			task.wait(LOAD_PAUSE)
		end
		task.wait(busy and BUSY_PAUSE or IDLE_PAUSE)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- WATCHING
------------------------------------------------------------------------------------------------------------------------
local function queueCharacter(character)
	if pending[character] or not alive then return end
	pending[character] = true
	task.delay(SETTLE, function()
		pending[character] = nil
		if alive and character.Parent then
			local ok, err = pcall(scan, character)
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
			waiting[character] = nil
			added:Disconnect()
			gone:Disconnect()
		end
	end)
end

local function watchPlayer(player)
	if player.Character then watchCharacter(player.Character) end
	connect(player.CharacterAdded, watchCharacter)
end

for _, player in ipairs(Players:GetPlayers()) do watchPlayer(player) end
connect(Players.PlayerAdded, watchPlayer)
task.spawn(worker)

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
			for thing in pairs(r.removed) do pcall(function() thing.Parent = character end) end
		end
	end
	table.clear(records)
	table.clear(ugcAnims)
	table.clear(jobs)
	table.clear(waiting)
	Env.__UGCRemoverCleanup = nil
end

Env.UGCRemover = {
	Stats = function() return { ugc = stats.ugc, swapped = stats.swapped, removedOnly = stats.removedOnly } end,
}

task.delay(15, function()
	if alive then
		print(("[UGC Remover] %d UGC things found so far: %d swapped for Roblox's own, %d just taken off%s")
			:format(stats.ugc, stats.swapped, stats.removedOnly,
				batchWorks and "" or " (batch lookups not allowed here: one at a time)"))
	end
end)
print("[UGC Remover] On: everything UGC swapped for the closest Roblox-made thing (on your screen only).")
