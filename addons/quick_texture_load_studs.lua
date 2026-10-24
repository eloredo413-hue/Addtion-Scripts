-- [[ FAST TEXTURES WIZARD ADDON — run AFTER the main Bloxy Paradox script ]]
-- FIXED: flexible button detection, works without 2016, manual fallback.

task.spawn(function()
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui", 30)

	local sg
	local elapsed = 0
	while elapsed < 60 do
		sg = pg:FindFirstChild("BloxyParadoxProject")
		if sg then break end
		task.wait(0.2)
		elapsed = elapsed + 0.2
	end
	if not sg then
		warn("[Fast Textures] GUI never appeared.")
		return
	end

	-- ============================================================
	-- STUD TEXTURE SOURCES (unchanged from original)
	-- ============================================================
	local STUD_2008 = [==[
		local STUDS_PER_TILE_U = 2
		local STUDS_PER_TILE_V = 4
		local DECAL_IDS = {
			STUDS = "112377592408206",
			INLETS = "130449770819407",
			UNIVERSAL = "14909139961",
			WELD = "139411804389109",
			GLUE = "82609935349620",
		}
		local FACE_TO_SURFACE_PROP = {
			[Enum.NormalId.Top]="TopSurface",
			[Enum.NormalId.Bottom]="BottomSurface",
			[Enum.NormalId.Front]="FrontSurface",
			[Enum.NormalId.Back]="BackSurface",
			[Enum.NormalId.Left]="LeftSurface",
			[Enum.NormalId.Right]="RightSurface",
		}
		local Players = game:GetService("Players")
		local RESOLVED = {}
		-- Textures made while their image id is still being looked up. They all
		-- get the real image as soon as the lookup finishes; each texture used to
		-- poll for it on a thread of its own for 4 seconds, which on a big map
		-- meant thousands of threads waking up ten times a second.
		local PENDING = {}
		_G.RetroTrackedParts = setmetatable({}, {__mode="k"})

		local function isPlayerPart(part)
			local a = part.Parent
			local d = 0
			while a and a ~= workspace and d < 32 do
				if a:IsA("Model") and Players:GetPlayerFromCharacter(a) then
					return true
				end
				a = a.Parent
				d = d + 1
			end
			return false
		end

		local function resolveId(id)
			if RESOLVED[id] then return RESOLVED[id] end
			RESOLVED[id] = "rbxthumb://type=Asset&id="..id.."&w=420&h=420"
			PENDING[id] = {}
			task.spawn(function()
				local ok, xml = pcall(function()
					return game:HttpGet("https://assetdelivery.roblox.com/v1/asset?id="..id)
				end)
				if ok and xml then
					local img = string.match(xml, "id=(%d+)")
					if img and img ~= id then
						RESOLVED[id] = "rbxassetid://"..img
					end
				end
				local waiting = PENDING[id]
				PENDING[id] = nil
				local cur = RESOLVED[id]
				for tex in pairs(waiting) do
					if tex.Parent and tex.Texture ~= cur then tex.Texture = cur end
				end
			end)
			return RESOLVED[id]
		end
		task.spawn(function()
			for _, id in pairs(DECAL_IDS) do
				resolveId(id)
			end
		end)

		local function applyTex(part, face, surface)
			local decal
			if surface==Enum.SurfaceType.Weld then decal=DECAL_IDS.WELD
			elseif surface==Enum.SurfaceType.Glue then decal=DECAL_IDS.GLUE
			elseif surface==Enum.SurfaceType.Universal then decal=DECAL_IDS.UNIVERSAL
			elseif surface==Enum.SurfaceType.Studs then decal=DECAL_IDS.STUDS
			elseif surface==Enum.SurfaceType.Inlet then decal=DECAL_IDS.INLETS end

			local name = "RetroTexture_"..face.Name
			local existing = part:FindFirstChild(name)

			if decal then
				local id = resolveId(decal)
				if not existing then
					existing = Instance.new("Texture")
					existing.Name = name
					existing.Face = face
					existing.Parent = part
				end
				existing.Texture = id
				existing.StudsPerTileU = STUDS_PER_TILE_U
				existing.StudsPerTileV = STUDS_PER_TILE_V
				existing.Transparency = part.Transparency

				local waiting = PENDING[decal]
				if waiting then waiting[existing] = true end
			elseif existing then
				existing:Destroy()
			end
		end

		local function removeTex(part, face)
			local t = part:FindFirstChild("RetroTexture_"..face.Name)
			if t then t:Destroy() end
		end

		local function setup(part)
			if not part:IsA("BasePart") or part:IsA("Terrain") then return end
			if isPlayerPart(part) then return end
			if _G.RetroTrackedParts[part] then return end
			_G.RetroTrackedParts[part] = true

			for face, prop in pairs(FACE_TO_SURFACE_PROP) do
				local init = part[prop]
				if init ~= Enum.SurfaceType.Smooth then
					applyTex(part, face, init)
					part:SetAttribute("RetroUpdating_"..prop, true)
					part[prop] = Enum.SurfaceType.Smooth
					part:SetAttribute("RetroUpdating_"..prop, false)
				end
				part:GetPropertyChangedSignal(prop):Connect(function()
					if part:GetAttribute("RetroUpdating_"..prop) then return end
					local cur = part[prop]
					if cur ~= Enum.SurfaceType.Smooth then
						applyTex(part, face, cur)
						part:SetAttribute("RetroUpdating_"..prop, true)
						part[prop] = Enum.SurfaceType.Smooth
						part:SetAttribute("RetroUpdating_"..prop, false)
					else
						removeTex(part, face)
					end
				end)
			end

			part:GetPropertyChangedSignal("Transparency"):Connect(function()
				for _, c in ipairs(part:GetChildren()) do
					if c:IsA("Texture") and string.find(c.Name, "RetroTexture_") then
						c.Transparency = part.Transparency
					end
				end
			end)
		end

		local n = 0
		for _, d in pairs(workspace:GetDescendants()) do
			if d:IsA("BasePart") then
				setup(d)
				n = n + 1
				if n % 500 == 0 then task.wait() end
			end
		end

		if _G.RetroTextureConnection then
			_G.RetroTextureConnection:Disconnect()
		end
		_G.RetroTextureConnection = workspace.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") then setup(d) end
		end)
	]==]

	local STUD_2012 = [==[
		local RunService = game:GetService("RunService")
		if RunService:IsClient() and not game:IsLoaded() then
			game.Loaded:Wait()
		end

		local TEXTURE_CONFIG = {
			INLETS={Id="75701694924031",TileSize=1},
			STUDS={Id="16120867196",TileSize=1},
			UNIVERSAL={Id="18690677546",TileSize=2},
			WELD={Id="18690671328",TileSize=2},
			GLUE={Id="18690673586",TileSize=2},
		}
		local FACE_TO_SURFACE_PROP = {
			[Enum.NormalId.Top]="TopSurface",
			[Enum.NormalId.Bottom]="BottomSurface",
			[Enum.NormalId.Front]="FrontSurface",
			[Enum.NormalId.Back]="BackSurface",
			[Enum.NormalId.Left]="LeftSurface",
			[Enum.NormalId.Right]="RightSurface",
		}
		local IGNORED = {
			["Head"]=true,["Torso"]=true,["Left Arm"]=true,["Right Arm"]=true,
			["Left Leg"]=true,["Right Leg"]=true,["HumanoidRootPart"]=true,
			["LeftHand"]=true,["LeftLowerArm"]=true,["LeftUpperArm"]=true,
			["RightHand"]=true,["RightLowerArm"]=true,["RightUpperArm"]=true,
			["LeftFoot"]=true,["LeftLowerLeg"]=true,["LeftUpperLeg"]=true,
			["RightFoot"]=true,["RightLowerLeg"]=true,["RightUpperLeg"]=true,
			["UpperTorso"]=true,["LowerTorso"]=true,["Handle"]=true,
		}
		_G.RetroTrackedParts = setmetatable({}, {__mode="k"})

		local function uri(id)
			return "rbxthumb://type=Asset&id="..id.."&w=420&h=420"
		end

		local function applyTex(part, face, id, tile)
			local n = "RetroTexture_"..face.Name
			local e = part:FindFirstChild(n)
			if e then e:Destroy() end
			local t = Instance.new("Texture")
			t.Name = n
			t.Texture = uri(id)
			t.Face = face
			t.StudsPerTileU = tile
			t.StudsPerTileV = tile
			t.Parent = part
		end

		local function removeTex(part, face)
			local t = part:FindFirstChild("RetroTexture_"..face.Name)
			if t then t:Destroy() end
		end

		local function updateFace(part, face, surface)
			local cfg
			if surface==Enum.SurfaceType.Weld then cfg=TEXTURE_CONFIG.WELD
			elseif surface==Enum.SurfaceType.Glue then cfg=TEXTURE_CONFIG.GLUE
			elseif surface==Enum.SurfaceType.Universal then cfg=TEXTURE_CONFIG.UNIVERSAL
			elseif surface==Enum.SurfaceType.Studs then cfg=TEXTURE_CONFIG.STUDS
			elseif surface==Enum.SurfaceType.Inlet then cfg=TEXTURE_CONFIG.INLETS end

			if cfg then
				applyTex(part, face, cfg.Id, cfg.TileSize)
			else
				removeTex(part, face)
			end

			if surface ~= Enum.SurfaceType.Smooth and surface ~= Enum.SurfaceType.SmoothNoOutlines then
				local p = FACE_TO_SURFACE_PROP[face]
				part:SetAttribute("RetroUpdating_"..p, true)
				pcall(function() part[p] = Enum.SurfaceType.Smooth end)
				part:SetAttribute("RetroUpdating_"..p, false)
			end
		end

		local function isChar(part)
			if IGNORED[part.Name] then return true end
			local c = part.Parent
			local d = 0
			while c and c ~= game and d < 32 do
				if c:IsA("Model") and c:FindFirstChildOfClass("Humanoid") then return true end
				if c:IsA("Accessory") or c:IsA("Tool") or c:IsA("Hat") then return true end
				c = c.Parent
				d = d + 1
			end
			return false
		end

		local function setup(part)
			if not part:IsA("BasePart") or part:IsA("Terrain") then return end
			if part.Transparency >= 1 then return end
			if isChar(part) then return end
			if _G.RetroTrackedParts[part] then return end
			_G.RetroTrackedParts[part] = true

			for face, prop in pairs(FACE_TO_SURFACE_PROP) do
				local ok, s = pcall(function() return part[prop] end)
				if ok then updateFace(part, face, s) end
			end
			part:SetAttribute("RetroTexturesListened", true)

			for face, prop in pairs(FACE_TO_SURFACE_PROP) do
				part:GetPropertyChangedSignal(prop):Connect(function()
					if part:GetAttribute("RetroUpdating_"..prop) then return end
					local ok, s = pcall(function() return part[prop] end)
					if ok then updateFace(part, face, s) end
				end)
			end
		end

		local n = 0
		for _, d in pairs(workspace:GetDescendants()) do
			if d:IsA("BasePart") then
				setup(d)
				n = n + 1
				if n % 500 == 0 then task.wait() end
			end
		end

		if _G.RetroTextureConnection then
			_G.RetroTextureConnection:Disconnect()
		end
		_G.RetroTextureConnection = workspace.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") then setup(d) end
		end)
	]==]

	local function runStud(src)
		local fn, err = loadstring(src)
		if not fn then
			warn("[Fast Textures] loadstring failed: " .. tostring(err))
			return
		end
		local ok, runErr = pcall(fn)
		if not ok then
			warn("[Fast Textures] Runtime error: " .. tostring(runErr))
		end
	end

	local function fireBtn(btn)
		if not btn or not btn.Parent then return end
		if firesignal then
			if pcall(firesignal, btn.MouseButton1Click) then return end
		end
		pcall(function() btn.MouseButton1Click:Fire() end)
	end

	local function killHandlers(btn)
		if not btn or not getconnections then return end
		local ok, conns = pcall(getconnections, btn.MouseButton1Click)
		if not ok or type(conns) ~= "table" then return end
		for _, c in ipairs(conns) do
			pcall(function() c:Disconnect() end)
		end
	end

	local function matches(text, needle)
		if not text then return false end
		return string.find(string.lower(text), needle, 1, true) ~= nil
	end

	local handled = setmetatable({}, {__mode="k"})

	RunService.RenderStepped:Connect(function()
		if not sg or not sg.Parent then return end

		for _, frame in ipairs(sg:GetChildren()) do
			if frame:IsA("Frame") and not handled[frame] then
				local btn2008, btn2012, btn2016, btnNormal
				-- The prompt's buttons sit right inside it. Reading every
				-- descendant walked the whole hammer panel every frame.
				for _, d in ipairs(frame:GetChildren()) do
					if d:IsA("TextButton") then
						local t = d.Text or ""
						if matches(t, "2008") and matches(t, "texture") then btn2008 = d end
						if matches(t, "2012") and matches(t, "texture") then btn2012 = d end
						if matches(t, "2016") and matches(t, "texture") then btn2016 = d end
						if t == "Normal" or matches(t, "normal") then btnNormal = d end
					end
				end

				-- Only require 2008 + 2012; Normal is optional
				if btn2008 and btn2012 then
					handled[frame] = true
					print("[Fast Textures] Textures step detected.")

					killHandlers(btn2008)
					killHandlers(btn2012)

					btn2008.MouseButton1Click:Connect(function()
						print("[Fast Textures] 2008 clicked — advancing.")
						if btnNormal then fireBtn(btnNormal) end
						task.spawn(function()
							local ok, err = pcall(function() runStud(STUD_2008) end)
							if not ok then warn("[Fast Textures] 2008 error: " .. tostring(err)) end
						end)
					end)

					btn2012.MouseButton1Click:Connect(function()
						print("[Fast Textures] 2012 clicked — advancing.")
						if btnNormal then fireBtn(btnNormal) end
						task.spawn(function()
							local ok, err = pcall(function() runStud(STUD_2012) end)
							if not ok then warn("[Fast Textures] 2012 error: " .. tostring(err)) end
						end)
					end)

					print("[Fast Textures] 2008/2012 handlers replaced.")
					return
				end
			end
		end
	end)

	-- Manual fallback if auto-detection fails
	_G.ApplyStuds = function(year)
		if year == "2008" then
			runStud(STUD_2008)
			print("[Fast Textures] Manual 2008 applied.")
		elseif year == "2012" then
			runStud(STUD_2012)
			print("[Fast Textures] Manual 2012 applied.")
		else
			warn("[Fast Textures] Usage: _G.ApplyStuds('2008') or _G.ApplyStuds('2012')")
		end
	end

	print("[Fast Textures] Watching for textures step.")
	print("[Fast Textures] Manual fallback: _G.ApplyStuds('2008') / _G.ApplyStuds('2012')")
end)