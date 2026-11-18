--========================================================
-- CLASSIC OUTLINES (Addtion-Scripts)
-- The thin dark edges on bricks that Roblox drew in 2016-2017, taken from the lighting era script
-- (IW Legacy Lighting's Outlines) so they can be used on their own: "outline" in Hammer stuff 2.
-- Plain block Parts near the camera get a thin SelectionBox outline. Checked once a second, so the lines follow
-- you around a big map without outlining all of it. Parts of characters (limbs, tools, hats), see-through parts,
-- tiny parts and parts with a mesh are left alone (an outline box would be the wrong shape on them).
-- Only YOU see them: they live under your camera. Nothing in the map is changed.
--
-- Run it to switch the outlines on (running it again replaces the earlier run).
-- Switch them off: getgenv().ClassicOutlinesStop()
-- Hammer stuff uses getgenv().BPClassicOutlines: Start(), Stop(), Running().
--========================================================

local Settings = {
	OutlineThickness    = 0.01,  -- how thick the lines are, in studs. Measured on the 2017 Studio: about 1 pixel wide
	OutlineTransparency = 0.6,   -- 0 = solid, 1 = invisible. The 2017 lines were only about 10-17% darker than the brick next
	                             -- to them (not black); 0.6 with the dark grey below measured about 8-20% darker side by side
	OutlineColor        = Color3.new(0.1, 0.1, 0.1), -- a very dark grey: pure black came out far too dark
	OutlineDistance     = 120,   -- how far from the camera bricks get an outline (studs)
	MaxOutlines         = 1200,  -- most outlines at once
	RefreshSeconds      = 1,     -- how often the bricks near the camera are looked at again
}

local genv = (getgenv and getgenv()) or _G

-- an earlier run (this file run again) is stopped first: one set of outlines at a time
if type(genv.BPClassicOutlines) == "table" and type(genv.BPClassicOutlines.Stop) == "function" then
	pcall(genv.BPClassicOutlines.Stop)
end

local FOLDER_NAME = "ClassicOutlines"
local MESH_PROXY = "LegacyMeshProxy" -- the stand-in parts the lighting scripts draw textured meshes with

local running = false
local runToken = nil

local function startOutlines()
	local token = {}
	runToken = token
	running = true

	local radius = tonumber(Settings.OutlineDistance) or 120
	local maxBoxes = tonumber(Settings.MaxOutlines) or 1200
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = workspace.CurrentCamera or workspace -- things under the camera exist on your client only

	local params = OverlapParams.new()
	params.MaxParts = maxBoxes * 4
	local boxes = {}
	local count = 0

	-- Parts of a character (limbs, tools, accessories) get no outline: the box would not follow the outfit, and
	-- it floated around the arm, torso and legs. Looked up per model once per refresh (a big map model can hold
	-- thousands of parts).
	local charCache = {}
	local function onCharacter(part)
		local p = part.Parent
		for _ = 1, 3 do
			if not p or p == workspace then return false end
			if p:IsA("Model") then
				local c = charCache[p]
				if c == nil then
					c = p:FindFirstChildOfClass("Humanoid") ~= nil
					charCache[p] = c
				end
				if c then return true end
			end
			p = p.Parent
		end
		return false
	end

	local function wanted(part)
		if part.ClassName ~= "Part" or part.Name == MESH_PROXY then return false end
		if onCharacter(part) then return false end
		if part.Shape ~= Enum.PartType.Block or part.Transparency > 0.5 then return false end
		if part.Size.X < 0.4 and part.Size.Y < 0.4 and part.Size.Z < 0.4 then return false end
		if part:FindFirstChildWhichIsA("DataModelMesh") then return false end
		return true
	end

	local function refresh()
		local cam = workspace.CurrentCamera
		if not cam then return end
		-- a new camera (some games replace it): the outlines move with it
		if folder.Parent ~= cam then folder.Parent = cam end
		charCache = {}
		local near = {}
		for _, part in ipairs(workspace:GetPartBoundsInRadius(cam.CFrame.Position, radius, params)) do
			local ok, yes = pcall(wanted, part)
			if ok and yes then near[part] = true end
		end
		for part, box in pairs(boxes) do
			if not near[part] then
				box:Destroy()
				boxes[part] = nil
				count -= 1
			end
		end
		for part in pairs(near) do
			if count >= maxBoxes then break end
			if not boxes[part] then
				local box = Instance.new("SelectionBox")
				box.Name = "LegacyOutline"
				box.LineThickness = tonumber(Settings.OutlineThickness) or 0.01
				box.Color3 = typeof(Settings.OutlineColor) == "Color3" and Settings.OutlineColor or Color3.new(0, 0, 0)
				box.Transparency = tonumber(Settings.OutlineTransparency) or 0.85
				box.SurfaceTransparency = 1
				box.Adornee = part
				box.Parent = folder
				boxes[part] = box
				count += 1
			end
		end
	end

	task.spawn(function()
		while runToken == token do
			pcall(refresh)
			task.wait(tonumber(Settings.RefreshSeconds) or 1)
		end
		-- switched off (or replaced by a new run): every outline goes
		pcall(function() folder:Destroy() end)
		table.clear(boxes)
	end)
	print("[Classic Outlines] on (bricks within " .. radius .. " studs of the camera).")
end

local api = {}

function api.Start()
	if running then return end
	startOutlines()
end

function api.Stop()
	if not running then return end
	running = false
	runToken = nil
	-- the outlines go now, not at the next refresh
	for _, holder in ipairs({ workspace.CurrentCamera, workspace }) do
		if holder then
			for _, child in ipairs(holder:GetChildren()) do
				if child.Name == FOLDER_NAME and child:IsA("Folder") then pcall(function() child:Destroy() end) end
			end
		end
	end
	print("[Classic Outlines] off.")
end

function api.Running()
	return running
end

genv.BPClassicOutlines = api
genv.ClassicOutlinesStop = api.Stop
api.Start()
