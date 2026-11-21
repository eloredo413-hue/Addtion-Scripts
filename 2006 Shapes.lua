--[[
	2006 SHAPES (Addtion-Scripts)
	Meshes and the other shapes 2006 Roblox didn't have, shown as the basic parts it did have: bricks (blocks), balls
	and cylinders, bricks with studs on top and inlets underneath. On your screen only.

	  * a part with a mesh in it (SpecialMesh, BlockMesh, CylinderMesh): the mesh comes off, so the part shows as the
	    plain part it is underneath (the size you collide with). A sphere, cylinder or head mesh shows as a ball or a
	    cylinder, and a stretched brick mesh as a brick that size.
	  * a MeshPart or a union: a ball or a cylinder when it is one (by its shape: how much of its box it fills, and
	    which of its sides are alike), one brick when it fills its box, and otherwise built out of bricks the way 2006
	    builders did: a grid of up to 4 x 4 x 4 over it, each cell the shape is in becoming a brick, and bricks next to
	    each other joined into bigger ones (a tree: a trunk and a block of leaves; an arch: two sides and a top).
	  * a truss: a brick (trusses came later).
	  * a mesh with a picture on it (a texture, its own colour left plain white or grey): coloured by its name or its
	    material (leaves green, wood brown, rock grey...), one colour, as parts were in 2006.
	The game itself isn't changed: what you collide with, stand on and touch stays exactly as it was (the bricks are
	only a look, welded on, and the old shape is hidden on your screen), so nothing breaks. Players are never changed:
	every player's character, anything welded to one, any other character (NPCs), hats and tools are left alone.
	Parts that come in later (streaming, spawning) are done as they come.
	Run again to start over; getgenv().__Shapes2006Cleanup() puts every shape back.
]]

local Env = (getgenv and getgenv()) or _G
if type(Env.__Shapes2006Cleanup) == "function" then pcall(Env.__Shapes2006Cleanup) end

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = workspace

local PARTS_PER_FRAME = 120   -- parts looked at each frame
local TESTS_PER_FRAME = 300   -- shape tests each frame (building a shape out of bricks)
local MAX_GRID = 4            -- a shape built out of bricks: at most this many cells along each side...
local CELL = 2                -- ...each about this many studs
local ROUND = 0.12            -- sides this close (a share of the bigger one) are the round sides of a ball / cylinder
local MAX_BRICKS = 40000      -- bricks made at most (a huge map stops there)
local STUDS = true            -- 2006 bricks: studs on top, inlets underneath

local folder = Instance.new("Folder")
folder.Name = "BP2006Shapes"
folder.Parent = Workspace

local records = {}            -- [the game's part] = what was done to it (to put it back)
local queue, queued = {}, {}
local conns = {}
local alive = true
local made = 0
local testsLeft = 0
local counts = { solids = 0, meshes = 0, trusses = 0 }

------------------------------------------------------------------------------------------------------------------------
-- COLOURS for a mesh that had a picture on it
------------------------------------------------------------------------------------------------------------------------
local GREEN = Color3.fromRGB(75, 151, 75)       -- Bright green
local DARK_GREEN = Color3.fromRGB(39, 70, 45)   -- Earth green
local BROWN = Color3.fromRGB(105, 64, 40)       -- Reddish brown
local GREY = Color3.fromRGB(163, 162, 165)      -- Medium stone grey
local DARK_GREY = Color3.fromRGB(99, 95, 98)    -- Dark stone grey
local SAND = Color3.fromRGB(215, 197, 154)      -- Brick yellow
local RED = Color3.fromRGB(196, 40, 28)         -- Bright red
local ICE = Color3.fromRGB(175, 221, 255)       -- Pastel light blue
local WATER = Color3.fromRGB(13, 105, 172)      -- Bright blue
local WHITE = Color3.fromRGB(242, 243, 243)     -- White
local NAME_COLORS = {
	{ { "leaf", "leaves", "bush", "hedge", "foliage", "fern", "shrub", "vine", "moss", "plant", "grass", "palm", "tree" }, GREEN },
	{ { "trunk", "wood", "log", "branch", "plank", "fence", "crate", "barrel", "table", "chair", "bench", "stump",
		"shelf", "door" }, BROWN },
	{ { "rock", "stone", "boulder", "cliff", "pebble", "statue", "pillar", "column", "concrete", "metal", "pipe" }, GREY },
	{ { "water", "ocean", "lake", "river" }, WATER },
	{ { "ice" }, ICE },
	{ { "sand", "dune" }, SAND },
	{ { "brick" }, RED },
	{ { "snow", "cloud" }, WHITE },
}
local MATERIAL_COLORS = {}
for name, color in pairs({
	Grass = GREEN, LeafyGrass = DARK_GREEN, Wood = BROWN, WoodPlanks = BROWN, Slate = DARK_GREY, Rock = GREY,
	Basalt = DARK_GREY, Concrete = GREY, Cobblestone = GREY, Pavement = GREY, Granite = GREY, Limestone = SAND,
	Pebble = GREY, Marble = WHITE, Sand = SAND, Sandstone = SAND, Brick = RED, Ice = ICE, Glacier = ICE, Snow = WHITE,
	Mud = BROWN, Ground = BROWN, Metal = GREY, DiamondPlate = GREY, CorrodedMetal = DARK_GREY, Foil = GREY,
	Salt = WHITE, Asphalt = DARK_GREY,
}) do
	local ok, material = pcall(function() return Enum.Material[name] end)
	if ok and material then MATERIAL_COLORS[material] = color end
end

local function plainColor(c)
	if c.R > 0.9 and c.G > 0.9 and c.B > 0.9 then return true end
	return math.abs(c.R - GREY.R) < 0.03 and math.abs(c.G - GREY.G) < 0.03 and math.abs(c.B - GREY.B) < 0.03
end

-- the colour a textured shape gets: by its name (or its model's), else by its material; nil when it keeps its own
local function guessColor(part)
	local name = string.lower(part.Name .. " " .. ((part.Parent and part.Parent.Name) or ""))
	for _, rule in ipairs(NAME_COLORS) do
		for _, word in ipairs(rule[1]) do
			if string.find(name, word, 1, true) then return rule[2] end
		end
	end
	return MATERIAL_COLORS[part.Material]
end

local function textured(part)
	if part:FindFirstChildOfClass("SurfaceAppearance") then return true end
	local ok, id = pcall(function() return part.TextureID end)
	return ok and type(id) == "string" and id ~= ""
end

------------------------------------------------------------------------------------------------------------------------
-- WHICH PARTS
------------------------------------------------------------------------------------------------------------------------
-- PLAYERS ARE NEVER CHANGED: every player's character and anything in it, anything welded to a character (a body
-- built of parts welded on, a cape, something carried: one assembly with it), characters of any kind (a model with
-- a Humanoid or an AnimationController: NPCs too), hats and tools. Also the camera's own parts and ours.
local function characterModel(model)
	return model:FindFirstChildOfClass("Humanoid") ~= nil or model:FindFirstChildOfClass("AnimationController") ~= nil
end
local function onCharacter(part)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character and part:IsDescendantOf(character) then return true end
	end
	local ok, root = pcall(function() return part.AssemblyRootPart end)
	if ok and root and root ~= part then
		local model = root:FindFirstAncestorOfClass("Model")
		while model do
			if characterModel(model) then return true end
			model = model:FindFirstAncestorOfClass("Model")
		end
	end
	return false
end
local function leftAlone(part)
	local node = part.Parent
	while node and node ~= Workspace do
		if node == folder or node:IsA("Accessory") or node:IsA("Accoutrement") or node:IsA("Tool")
			or node:IsA("Camera") then
			return true
		end
		if node:IsA("Model") and characterModel(node) then return true end
		node = node.Parent
	end
	if node ~= Workspace then return true end
	return onCharacter(part)
end

local function solid(part)
	return part:IsA("MeshPart") or (part:IsA("PartOperation") and not part:IsA("NegateOperation"))
end

local function meshIn(part)
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("DataModelMesh") then return child end
	end
	return nil
end

local function enqueue(part)
	if queued[part] or records[part] then return end
	queued[part] = true
	queue[#queue + 1] = part
end

local function consider(inst)
	if inst:IsA("BasePart") then
		if solid(inst) or inst:IsA("TrussPart") then enqueue(inst) end
	elseif inst:IsA("DataModelMesh") then
		local parent = inst.Parent
		if parent and parent:IsA("BasePart") then enqueue(parent) end
	end
end

------------------------------------------------------------------------------------------------------------------------
-- MAKING THE BASIC PARTS
------------------------------------------------------------------------------------------------------------------------
local function near(a, b)
	return math.abs(a - b) <= ROUND * math.max(a, b, 1e-3)
end

-- how much of its box a shape fills (its volume, from its mass, over its box); nil when it can't be told
local function fillOf(part)
	local ok, fill = pcall(function()
		local density = part.CurrentPhysicalProperties.Density
		local s = part.Size
		local box = s.X * s.Y * s.Z
		if density and density > 0 and box > 0 then return (part.Mass / density) / box end
		return nil
	end)
	if ok and type(fill) == "number" and fill == fill and fill > 0 then return math.min(fill, 1) end
	return nil
end

-- a basic part of shape ("Block", "Ball", "Cylinder"), welded on: only a look (no collision, touching or ray hits)
local function newBrick(rec, original, shape, size, cframe, color)
	local p = Instance.new("Part")
	p.Name = "2006 " .. shape
	p.Shape = Enum.PartType[shape]
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = original.Material
	p.Reflectance = original.Reflectance
	p.Transparency = original.Transparency
	p.CastShadow = original.CastShadow
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.Anchored = false
	if STUDS and shape == "Block" then
		p.TopSurface = Enum.SurfaceType.Studs
		p.BottomSurface = Enum.SurfaceType.Inlet
	else
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = original
	weld.Part1 = p
	weld.Parent = p
	p.Parent = folder
	made = made + 1
	rec.bricks[#rec.bricks + 1] = p
	return p
end

-- a cylinder along one side of the box ("X", "Y", "Z"): Roblox's cylinder lies along its own X
local function cylinderAlong(axis, size, cframe)
	if axis == "Y" then
		local d = math.min(size.X, size.Z)
		return Vector3.new(size.Y, d, d), cframe * CFrame.Angles(0, 0, math.pi / 2)
	elseif axis == "Z" then
		local d = math.min(size.X, size.Y)
		return Vector3.new(size.Z, d, d), cframe * CFrame.Angles(0, math.pi / 2, 0)
	end
	local d = math.min(size.Y, size.Z)
	return Vector3.new(size.X, d, d), cframe
end

-- which side a cylinder of this box lies along: the one unlike the other two (standing up when all are alike)
local function roundAxis(size)
	if near(size.X, size.Z) then return "Y" end
	if near(size.Y, size.Z) then return "X" end
	if near(size.X, size.Y) then return "Z" end
	return nil
end

-- the game's part hidden on this screen only (its decals too); what you collide with stays
local function hide(rec, part)
	pcall(function() part.LocalTransparencyModifier = 1 end)
	rec.hidden = true
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("Decal") then -- (a Texture is a Decal too)
			pcall(function() child.LocalTransparencyModifier = 1 end)
			rec.hiddenDecals[#rec.hiddenDecals + 1] = child
		end
	end
end

-- a single brick standing in for the part carries its decals, as 2006 bricks did
local function copyDecals(part, brick)
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("Decal") then
			pcall(function()
				local copy = child:Clone()
				copy.LocalTransparencyModifier = 0
				copy.Parent = brick
			end)
		end
	end
end

-- the shape built out of bricks: a grid over its box, a brick in each cell it is in, neighbours joined.
-- Returns the bricks' boxes in cells and the cell size, or nil (one cell, nothing found, or every cell full)
local probe = Instance.new("Part")
probe.Name = "ShapeProbe"
probe.Anchored = true
probe.CanCollide = false
probe.CanQuery = false
probe.CanTouch = false
probe.Transparency = 1
probe.CastShadow = false
probe.Parent = folder
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
pcall(function() overlap.RespectCanCollide = false end)

local function cellsOf(part, size, cframe)
	local nx = math.clamp(math.floor(size.X / CELL + 0.5), 1, MAX_GRID)
	local ny = math.clamp(math.floor(size.Y / CELL + 0.5), 1, MAX_GRID)
	local nz = math.clamp(math.floor(size.Z / CELL + 0.5), 1, MAX_GRID)
	if nx * ny * nz <= 1 then return nil end
	local cell = Vector3.new(size.X / nx, size.Y / ny, size.Z / nz)
	-- (the test only sees parts that can be found: one that can't is made findable on this screen for the test)
	local couldQuery = part.CanQuery
	if not couldQuery then pcall(function() part.CanQuery = true end) end
	overlap.FilterDescendantsInstances = { part }
	probe.Size = cell * 0.8 -- (a cell only grazed at its edge doesn't count)
	local grid, any, all = {}, false, true
	for i = 0, nx - 1 do
		for j = 0, ny - 1 do
			for k = 0, nz - 1 do
				local at = Vector3.new(-size.X / 2 + cell.X * (i + 0.5), -size.Y / 2 + cell.Y * (j + 0.5),
					-size.Z / 2 + cell.Z * (k + 0.5))
				probe.CFrame = cframe * CFrame.new(at)
				local ok, hits = pcall(function() return Workspace:GetPartsInPart(probe, overlap) end)
				local hit = ok and type(hits) == "table" and #hits > 0
				if hit then grid[(i * ny + j) * nz + k] = true end
				any = any or hit
				all = all and hit
			end
		end
	end
	testsLeft = testsLeft - nx * ny * nz
	if not couldQuery then pcall(function() part.CanQuery = false end) end
	if not any or all then return nil end

	local function filled(i, j, k)
		if i < 0 or i >= nx or k < 0 or k >= nz then return nil end
		return grid[(i * ny + j) * nz + k]
	end
	local function rowFull(i0, i1, j, k)
		for i = i0, i1 do
			if not filled(i, j, k) then return false end
		end
		return true
	end
	-- the layer above spreads out past the brick's sides (a trunk meeting the leaves, a pillar meeting a beam):
	-- the brick stops below it, so the wider layer becomes one brick of its own
	local function spreadsOut(i0, i1, j, k0, k1)
		for k = k0, k1 do
			if filled(i0 - 1, j, k) or filled(i1 + 1, j, k) then return true end
		end
		for i = i0, i1 do
			if filled(i, j, k0 - 1) or filled(i, j, k1 + 1) then return true end
		end
		return false
	end
	local boxes = {}
	for j = 0, ny - 1 do
		for k = 0, nz - 1 do
			for i = 0, nx - 1 do
				if filled(i, j, k) then
					local i1 = i
					while i1 + 1 < nx and filled(i1 + 1, j, k) do i1 = i1 + 1 end
					local k1 = k
					while k1 + 1 < nz and rowFull(i, i1, j, k1 + 1) do k1 = k1 + 1 end
					local j1 = j
					while j1 + 1 < ny and not spreadsOut(i, i1, j1 + 1, k, k1) do
						local full = true
						for kk = k, k1 do
							if not rowFull(i, i1, j1 + 1, kk) then full = false break end
						end
						if not full then break end
						j1 = j1 + 1
					end
					for ii = i, i1 do
						for jj = j, j1 do
							for kk = k, k1 do grid[(ii * ny + jj) * nz + kk] = nil end
						end
					end
					boxes[#boxes + 1] = { i, j, k, i1, j1, k1 }
				end
			end
		end
	end
	return boxes, cell
end

------------------------------------------------------------------------------------------------------------------------
-- EACH KIND OF PART
------------------------------------------------------------------------------------------------------------------------
local function newRecord(part)
	local rec = { bricks = {}, conns = {}, meshes = {}, hiddenDecals = {}, hidden = false }
	records[part] = rec
	return rec
end

-- a MeshPart or a union
local function doSolid(rec, part)
	local size, cframe = part.Size, part.CFrame
	local color = part.Color
	if textured(part) and plainColor(color) then
		local guess = guessColor(part)
		if guess then
			color = guess
			rec.ownColor = true
		end
	end
	local fill = fillOf(part)
	local x, y, z = size.X, size.Y, size.Z
	hide(rec, part)
	if fill and fill < 0.9 then
		if near(x, y) and near(y, z) and near(x, z) and fill > 0.4 and fill < 0.68 then
			local d = math.min(x, y, z)
			copyDecals(part, newBrick(rec, part, "Ball", Vector3.new(d, d, d), cframe, color))
			return
		end
		local axis = (fill >= 0.66) and roundAxis(size) or nil
		if axis then
			local s, c = cylinderAlong(axis, size, cframe)
			copyDecals(part, newBrick(rec, part, "Cylinder", s, c, color))
			return
		end
	end
	if (not fill or fill < 0.9) and math.max(x, y, z) >= CELL * 1.5 then
		local boxes, cell = cellsOf(part, size, cframe)
		if boxes then
			for _, b in ipairs(boxes) do
				local bs = Vector3.new((b[4] - b[1] + 1) * cell.X, (b[5] - b[2] + 1) * cell.Y, (b[6] - b[3] + 1) * cell.Z)
				local at = Vector3.new(-x / 2 + cell.X * (b[1] + b[4] + 1) / 2, -y / 2 + cell.Y * (b[2] + b[5] + 1) / 2,
					-z / 2 + cell.Z * (b[3] + b[6] + 1) / 2)
				newBrick(rec, part, "Block", bs, cframe * CFrame.new(at), color)
			end
			return
		end
	end
	copyDecals(part, newBrick(rec, part, "Block", size, cframe, color))
end

-- a part with a mesh in it: the mesh comes off
local function doMesh(rec, part, mesh)
	local kind = nil      -- "Ball", "Cylinder" or "Block" (a brick its own size), else the part shows as itself
	local axis = nil
	local scale, offset = Vector3.new(1, 1, 1), Vector3.new(0, 0, 0)
	pcall(function() scale, offset = mesh.Scale, mesh.Offset end)
	local picture = false
	if mesh:IsA("CylinderMesh") then
		kind, axis = "Cylinder", "Y"
	elseif mesh:IsA("BlockMesh") then
		kind = "Block"
	elseif mesh:IsA("SpecialMesh") then
		local t = mesh.MeshType
		if t == Enum.MeshType.Sphere then
			kind = "Ball"
		elseif t == Enum.MeshType.Cylinder then
			kind = "Cylinder"
		elseif t == Enum.MeshType.Head then
			kind, axis = "Cylinder", "Y"
		elseif t == Enum.MeshType.Brick then
			kind = "Block"
		else
			pcall(function() picture = mesh.TextureId ~= "" end)
		end
	end
	-- (a brick mesh not stretched or moved is just the brick)
	if kind == "Block" and (scale - Vector3.new(1, 1, 1)).Magnitude < 0.01 and offset.Magnitude < 0.01 then kind = nil end
	if kind == "Ball" and part:IsA("Part") and part.Shape == Enum.PartType.Ball and (scale - Vector3.new(1, 1, 1)).Magnitude < 0.01 then
		kind = nil
	end

	rec.meshes[#rec.meshes + 1] = mesh
	mesh.Parent = nil

	if not kind then
		-- the part as it is underneath; a brick gets its studs, a picture-mesh its guessed colour
		if part:IsA("Part") and part.Shape == Enum.PartType.Block then
			if STUDS then
				rec.surfaces = { part.TopSurface, part.BottomSurface }
				part.TopSurface = Enum.SurfaceType.Studs
				part.BottomSurface = Enum.SurfaceType.Inlet
			end
		end
		if picture and plainColor(part.Color) then
			local guess = guessColor(part)
			if guess then
				rec.oldColor = part.Color
				part.Color = guess
			end
		end
		return
	end
	local size = part.Size * scale
	local cframe = part.CFrame * CFrame.new(offset)
	hide(rec, part)
	local brick
	if kind == "Ball" then
		local d = math.min(size.X, size.Y, size.Z)
		brick = newBrick(rec, part, "Ball", Vector3.new(d, d, d), cframe, part.Color)
	elseif kind == "Cylinder" then
		local s, c = cylinderAlong(axis or roundAxis(size) or "X", size, cframe)
		brick = newBrick(rec, part, "Cylinder", s, c, part.Color)
	else
		brick = newBrick(rec, part, "Block", size, cframe, part.Color)
	end
	copyDecals(part, brick)
end

------------------------------------------------------------------------------------------------------------------------
-- PUTTING BACK, KEEPING UP
------------------------------------------------------------------------------------------------------------------------
local function undo(part)
	local rec = records[part]
	if not rec then return end
	records[part] = nil
	for _, c in ipairs(rec.conns) do c:Disconnect() end
	for _, b in ipairs(rec.bricks) do
		pcall(function() b:Destroy() end)
		made = made - 1
	end
	if rec.hidden then pcall(function() part.LocalTransparencyModifier = 0 end) end
	for _, d in ipairs(rec.hiddenDecals) do pcall(function() d.LocalTransparencyModifier = 0 end) end
	for _, m in ipairs(rec.meshes) do pcall(function() m.Parent = part end) end
	if rec.surfaces then
		pcall(function()
			part.TopSurface = rec.surfaces[1]
			part.BottomSurface = rec.surfaces[2]
		end)
	end
	if rec.oldColor then pcall(function() part.Color = rec.oldColor end) end
end

local function track(rec, part)
	-- gone from the game (removed, streamed out), or now part of a player or character (picked up, put in a
	-- character): its bricks go and it is put back as it was
	rec.conns[#rec.conns + 1] = part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(Workspace) or leftAlone(part) then undo(part) end
	end)
	if #rec.bricks > 0 then
		-- the game fading it or recolouring it: its bricks do the same
		rec.conns[#rec.conns + 1] = part:GetPropertyChangedSignal("Transparency"):Connect(function()
			for _, b in ipairs(rec.bricks) do b.Transparency = part.Transparency end
		end)
		if not rec.ownColor then
			rec.conns[#rec.conns + 1] = part:GetPropertyChangedSignal("Color"):Connect(function()
				for _, b in ipairs(rec.bricks) do b.Color = part.Color end
			end)
		end
		-- resized: done again
		rec.conns[#rec.conns + 1] = part:GetPropertyChangedSignal("Size"):Connect(function()
			undo(part)
			enqueue(part)
		end)
	end
end

local function process(part)
	if records[part] or not alive or not part.Parent or made >= MAX_BRICKS then return end
	if part.Transparency >= 0.98 or leftAlone(part) then return end
	if solid(part) then
		local rec = newRecord(part)
		doSolid(rec, part)
		track(rec, part)
		counts.solids = counts.solids + 1
	elseif part:IsA("TrussPart") then
		local rec = newRecord(part)
		hide(rec, part)
		newBrick(rec, part, "Block", part.Size, part.CFrame, part.Color)
		track(rec, part)
		counts.trusses = counts.trusses + 1
	else
		local mesh = meshIn(part)
		if not mesh then return end
		local rec = newRecord(part)
		doMesh(rec, part, mesh)
		track(rec, part)
		counts.meshes = counts.meshes + 1
	end
end

for _, inst in ipairs(Workspace:GetDescendants()) do consider(inst) end
table.insert(conns, Workspace.DescendantAdded:Connect(function(inst)
	if alive then consider(inst) end
end))

local reported, errorShown = false, false
table.insert(conns, RunService.Heartbeat:Connect(function()
	if not alive then return end
	local partsLeft = PARTS_PER_FRAME
	testsLeft = TESTS_PER_FRAME
	while partsLeft > 0 and testsLeft > 0 and #queue > 0 do
		local part = table.remove(queue)
		queued[part] = nil
		local ok, err = pcall(process, part)
		if not ok and not errorShown then
			errorShown = true
			warn("[2006 Shapes] couldn't do " .. tostring(part and part:GetFullName()) .. ": " .. tostring(err))
		end
		partsLeft = partsLeft - 1
	end
	if not reported and #queue == 0 then
		reported = true
		local function n(count, one, many) return count .. " " .. (count == 1 and one or many) end
		print(("[2006 Shapes] on: %s, %s and %s shown as %s%s. New ones are done as they come in."):format(
			n(counts.solids, "mesh or union", "meshes and unions"), n(counts.meshes, "part with a mesh", "parts with meshes"),
			n(counts.trusses, "truss", "trusses"), n(made, "basic part", "basic parts"),
			made >= MAX_BRICKS and " (the most it makes)" or ""))
	end
end))

Env.__Shapes2006Cleanup = function()
	alive = false
	for _, c in ipairs(conns) do c:Disconnect() end
	local list = {}
	for part in pairs(records) do list[#list + 1] = part end
	for _, part in ipairs(list) do undo(part) end
	pcall(function() folder:Destroy() end)
	Env.__Shapes2006Cleanup = nil
	print("[2006 Shapes] off: the game's own shapes are back.")
end
