-- Hammer stuff 1 (Addtion-Scripts copy of the gist): adds a "sky & world" category title above its options.
-- [[ BLOXY PARADOX
-- SKYBOX + LIGHTING + PLASTIC + 2009 MATERIALS
-- + LEGACY MATERIALS + SHADOWS + DESTROY GUI ADDON
-- Materials dropdown: smooth plastic / plastic / 2009 / legacy
-- Full executor-compatible replacement
-- ]]

task.spawn(function()

	------------------------------------------------------------
	-- SERVICES
	------------------------------------------------------------
	local HttpService = game:GetService("HttpService")
	local Lighting = game:GetService("Lighting")
	local Workspace = game:GetService("Workspace")
	local Players = game:GetService("Players")
	local SoundService = game:GetService("SoundService")
	local MaterialService = game:GetService("MaterialService")

	local LocalPlayer = Players.LocalPlayer

	if not LocalPlayer then
		warn("[Bloxy Paradox] LocalPlayer not available.")
		return
	end

	------------------------------------------------------------
	-- CONFIG
	------------------------------------------------------------
	local CONFIG_FILE = "BloxyParadoxConfig.json"

	local SKYBOX_2008_ID = 8199641442
	local SUN_ID = 79910545334172
	local MOON_ID = 5189246322
	local SKYBOX_2013_ID = 13530763931

	-- Original pack supplied in your script.
	local PACK_ID = "rbxassetid://14719371673"

	local SKYBOX_2008_DESC =
		"The Classic 2008 Skybox A Skybox Used from 2006 to 2011"

	------------------------------------------------------------
	-- LOAD CONFIG
	------------------------------------------------------------
	local config = {}

	if readfile and isfile and isfile(CONFIG_FILE) then
		pcall(function()
			local decoded = HttpService:JSONDecode(readfile(CONFIG_FILE))
			if type(decoded) == "table" then
				config = decoded
			end
		end)
	end

	if type(config) ~= "table" then
		config = {}
	end

	config.Choices = config.Choices or {}

	-- Hammer stuff 2 (and the base GUI) save to the same file, so
	-- re-read it before writing and only put in the keys this
	-- script changed. Otherwise each script would write back its
	-- old copy of the other's settings.
	local savedSnapshot = {}
	for key, value in pairs(config) do
		savedSnapshot[key] = value
	end

	local function readSavedConfig()
		if not (readfile and isfile) then
			return nil
		end
		local ok, decoded = pcall(function()
			if isfile(CONFIG_FILE) then
				return HttpService:JSONDecode(readfile(CONFIG_FILE))
			end
		end)
		return (ok and type(decoded) == "table") and decoded or nil
	end

	local function saveConfig()
		if not writefile then
			return
		end

		local latest = readSavedConfig() or {}
		for key, value in pairs(config) do
			if savedSnapshot[key] ~= value then
				latest[key] = value
			end
		end
		latest.Choices = latest.Choices or config.Choices or {}

		config = latest
		table.clear(savedSnapshot)
		for key, value in pairs(config) do
			savedSnapshot[key] = value
		end

		pcall(function()
			writefile(
				CONFIG_FILE,
				HttpService:JSONEncode(config)
			)
		end)
	end

	------------------------------------------------------------
	-- SAVED STATES
	------------------------------------------------------------
	local isSkybox2013Enabled =
		config.isSkybox2013Enabled == true

	local isRemoveLightingEnabled =
		config.isRemoveLightingEnabled == true

	local isSmoothPlasticEnabled =
		config.isSmoothPlasticEnabled == true

	local isPlasticEnabled =
		config.isPlasticEnabled == true

	local is2009MaterialsEnabled =
		config.is2009MaterialsEnabled == true

	local isLegacyMaterialsEnabled =
		config.isLegacyMaterialsEnabled == true

	local isNoShadowsEnabled =
		config.isNoShadowsEnabled == true

	------------------------------------------------------------
	-- FIND GUI SAFELY
	------------------------------------------------------------
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")

	if not pg then
		pg = LocalPlayer:WaitForChild("PlayerGui", 15)
	end

	if not pg then
		warn("[Bloxy Paradox] PlayerGui was not found.")
		return
	end

	local sg = pg:FindFirstChild("BloxyParadoxProject", true)

	if not sg then
		sg = pg:WaitForChild("BloxyParadoxProject", 15)
	end

	if not sg then
		warn("[Bloxy Paradox] BloxyParadoxProject was not found.")
		return
	end

	local hammerPanel =
		sg:FindFirstChild("HammerBigPanel", true)

	if not hammerPanel then
		warn("[Bloxy Paradox] HammerBigPanel was not found.")
		return
	end

	local skyboxContainer2008 =
		hammerPanel:FindFirstChild("SkyboxContainer", true)

	local skyboxCheckbox2008

	if skyboxContainer2008 then
		skyboxCheckbox2008 =
			skyboxContainer2008:FindFirstChild(
				"SkyboxCheckbox",
				true
			)
	end

	if not skyboxCheckbox2008 then
		warn("[Bloxy Paradox] 2008 Skybox checkbox was not found.")
	end

	------------------------------------------------------------
	-- CLICK SOUND
	------------------------------------------------------------
	local clickSfx = Instance.new("Sound")
	clickSfx.Name = "BPAddonClickSound"
	clickSfx.SoundId = "rbxassetid://12221967"
	clickSfx.Volume = 0.6
	clickSfx.Parent = SoundService

	local function playClick()
		pcall(function()
			clickSfx:Stop()
			clickSfx:Play()
		end)
	end

	------------------------------------------------------------
	-- FONT
	------------------------------------------------------------
	local fontBold

	pcall(function()
		fontBold = Font.new(
			"rbxasset://fonts/families/Arial.json",
			Enum.FontWeight.Bold,
			Enum.FontStyle.Normal
		)
	end)

	------------------------------------------------------------
	-- CACHE ORIGINAL SKY
	------------------------------------------------------------
	local originalSky = nil

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") then
			originalSky = child:Clone()
			break
		end
	end

	print(
		"[Bloxy Paradox] Original sky cached:",
		originalSky ~= nil
	)

	------------------------------------------------------------
	-- INFO PANEL
	------------------------------------------------------------
	local infoPanel =
		sg:FindFirstChild("SkipInfoPanel", true)

	if infoPanel then
		pcall(function()
			infoPanel.Parent = sg
			infoPanel.ZIndex = 500
			infoPanel.Visible = false
			infoPanel.AnchorPoint = Vector2.new(0, 0.5)
			infoPanel.Position = UDim2.new(0, 20, 0.5, 0)
			infoPanel.Size = UDim2.new(0, 360, 0, 200)
		end)
	end

	------------------------------------------------------------
	-- INFO TEXT
	------------------------------------------------------------
	local infoText

	if infoPanel then
		infoText =
			infoPanel:FindFirstChild("InfoText", true)
	end

	------------------------------------------------------------
	-- OVERRIDE 2008 DESCRIPTION
	------------------------------------------------------------
	if infoText then

		task.spawn(function()

			local oldText = infoText.Text

			while infoPanel
				and infoPanel.Parent
				and sg
				and sg.Parent do

				task.wait(0.05)

				local current = infoText.Text or ""

				if current ~= oldText then

					oldText = current

					local lower =
						string.lower(current)

					if lower:find(
						"2008 skybox",
						1,
						true
					)
					or lower:find(
						"to rejoin",
						1,
						true
					)
					then

						infoText.Text =
							SKYBOX_2008_DESC

						local len =
							#SKYBOX_2008_DESC

						if len <= 50 then
							infoText.TextSize = 18
						elseif len >= 250 then
							infoText.TextSize = 12
						else
							infoText.TextSize =
								math.floor(
									18 -
									((len - 50) / 200) * 6
								)
						end

						oldText =
							SKYBOX_2008_DESC
					end
				end
			end
		end)
	end

	------------------------------------------------------------
	-- MAKE HAMMER PANEL SCROLLABLE
	------------------------------------------------------------
	local originalHammerPanel = hammerPanel

	local isFrame =
		hammerPanel:IsA("Frame")
		or hammerPanel:IsA("ScrollingFrame")

	if isFrame then

		pcall(function()
			hammerPanel.ClipsDescendants = true
		end)

		local oldScroller =
			hammerPanel:FindFirstChild(
				"BPAddonScroller"
			)

		if oldScroller then
			-- Running this again: put the panel's own rows back
			-- first, or they would be destroyed with the old
			-- scroller. Our rows (and the other addon's) are
			-- rebuilt, so those go with it.
			for _, child in ipairs(oldScroller:GetChildren()) do
				if child:GetAttribute("BPBaseChild") then
					local baseY = child:GetAttribute("BPBaseY")
					if baseY then
						local p = child.Position
						child.Position = UDim2.new(p.X.Scale, p.X.Offset, p.Y.Scale, baseY)
					end
					child.Parent = hammerPanel
				end
			end
			oldScroller:Destroy()
		end

		local scroller =
			Instance.new("ScrollingFrame")

		scroller.Name = "BPAddonScroller"
		scroller.Size = UDim2.new(1, 0, 1, 0)
		scroller.Position = UDim2.new(0, 0, 0, 0)
		scroller.BackgroundTransparency = 1
		scroller.BorderSizePixel = 0
		scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroller.AutomaticCanvasSize =
			Enum.AutomaticSize.Y
		scroller.ScrollBarThickness = 4
		scroller.ScrollBarImageColor3 =
			Color3.fromRGB(150, 150, 150)
		scroller.ZIndex = 90
		scroller.Parent = hammerPanel

		for _, child in ipairs(hammerPanel:GetChildren()) do

			if child ~= scroller
				and child.Name ~= "SkipInfoPanel"
				and (
					child:IsA("Frame")
					or child:IsA("TextLabel")
					or child:IsA("TextButton")
				)
			then
				-- Remember it's the panel's own row (and where it
				-- was) so a second run can hand it back.
				child:SetAttribute("BPBaseChild", true)
				child:SetAttribute("BPBaseY", child.Position.Y.Offset)
				child.Parent = scroller
			end
		end

		hammerPanel = scroller
	end

	------------------------------------------------------------
	-- SKYBOX HELPERS
	------------------------------------------------------------
	local function clearSkies()

		for _, child in ipairs(
			Lighting:GetChildren()
		) do

			if child:IsA("Sky") then
				pcall(function()
					child:Destroy()
				end)
			end
		end
	end

	local function restoreOriginalSky()

		clearSkies()

		if originalSky then

			pcall(function()
				originalSky:Clone().Parent =
					Lighting
			end)

			print(
				"[Bloxy Paradox] Original sky restored."
			)

		else

			print(
				"[Bloxy Paradox] No original sky cached."
			)
		end
	end

	local function resolveTex(id)

		local result = nil

		pcall(function()

			local objects =
				game:GetObjects(
					"rbxassetid://" .. tostring(id)
				)

			for _, object in ipairs(objects) do

				if object:IsA("Decal")
					or object:IsA("Texture")
				then
					result = object.Texture
					return
				end

				for _, descendant in ipairs(
					object:GetDescendants()
				) do

					if descendant:IsA("Decal")
						or descendant:IsA("Texture")
					then
						result =
							descendant.Texture
						return
					end
				end
			end
		end)

		return result
			or ("rbxassetid://" .. tostring(id))
	end

	------------------------------------------------------------
	-- 2008 SKYBOX
	------------------------------------------------------------
	local function apply2008()

		clearSkies()

		local success =
			pcall(function()

				local sky = nil

				local objects =
					game:GetObjects(
						"rbxassetid://" ..
						tostring(SKYBOX_2008_ID)
					)

				for _, object in ipairs(objects) do

					if object:IsA("Sky") then
						sky = object
						break
					end

					local found =
						object:FindFirstChildWhichIsA(
							"Sky",
							true
						)

					if found then
						sky = found
						break
					end
				end

				if sky then

					sky.Parent = Lighting

					pcall(function()
						sky.SunTextureId =
							resolveTex(SUN_ID)

						sky.MoonTextureId =
							resolveTex(MOON_ID)

						sky.SunAngularSize = 21
						sky.MoonAngularSize = 11
					end)

				else
					warn(
						"[Bloxy Paradox] 2008 sky asset did not contain a Sky."
					)
				end
			end)

		if success then
			print("[Bloxy Paradox] 2008 Skybox applied.")
		end
	end

	------------------------------------------------------------
	-- 2013 SKYBOX
	------------------------------------------------------------
	local function apply2013()

		clearSkies()

		local success =
			pcall(function()

				local objects =
					game:GetObjects(
						"rbxassetid://" ..
						tostring(SKYBOX_2013_ID)
					)

				for _, object in ipairs(objects) do

					if object:IsA("Sky") then
						object.Parent = Lighting
						return
					end

					local found =
						object:FindFirstChildWhichIsA(
							"Sky",
							true
						)

					if found then
						found.Parent = Lighting
						return
					end
				end
			end)

		if success then
			print("[Bloxy Paradox] 2013 Skybox applied.")
		else
			warn("[Bloxy Paradox] 2013 Skybox failed.")
		end
	end

	------------------------------------------------------------
	-- REMOVE LIGHTING
	------------------------------------------------------------
	local rlState = {
		active = false,
		lights = {},
		bright = nil,
		exp = nil,
		fx = {},
		conns = {}
	}

	local function hideLight(light)

		if not light:IsA("Light") then
			return
		end

		if not rlState.active then
			return
		end

		rlState.lights[light] = true

		pcall(function()
			light.Enabled = false
		end)
	end

	local function trackFx(effect)

		if not (
			effect:IsA("BloomEffect")
			or effect:IsA("ColorCorrectionEffect")
			or effect:IsA("SunRaysEffect")
		) then
			return
		end

		if rlState.fx[effect] == nil then
			rlState.fx[effect] =
				effect.Enabled
		end

		pcall(function()
			effect.Enabled = false
		end)
	end

	local function applyRemoveLighting()

		if rlState.active then
			return
		end

		rlState.active = true

		rlState.bright =
			Lighting.Brightness

		rlState.exp =
			Lighting.ExposureCompensation

		for _, object in ipairs(
			Workspace:GetDescendants()
		) do

			if object:IsA("Light") then
				hideLight(object)
			end
		end

		table.insert(
			rlState.conns,
			Workspace.DescendantAdded:Connect(
				function(object)

					if rlState.active
						and object:IsA("Light")
					then
						task.defer(function()
							hideLight(object)
						end)
					end
				end
			)
		)

		local function enforce()

			if not rlState.active then
				return
			end

			if Lighting.Brightness >
				rlState.bright
			then
				pcall(function()
					Lighting.Brightness =
						rlState.bright
				end)
			end

			if Lighting.ExposureCompensation >
				rlState.exp
			then
				pcall(function()
					Lighting.ExposureCompensation =
						rlState.exp
				end)
			end
		end

		table.insert(
			rlState.conns,
			Lighting:GetPropertyChangedSignal(
				"Brightness"
			):Connect(enforce)
		)

		table.insert(
			rlState.conns,
			Lighting:GetPropertyChangedSignal(
				"ExposureCompensation"
			):Connect(enforce)
		)

		for _, object in ipairs(
			Lighting:GetChildren()
		) do
			trackFx(object)
		end

		table.insert(
			rlState.conns,
			Lighting.ChildAdded:Connect(
				function(object)

					if rlState.active then
						task.defer(function()
							trackFx(object)
						end)
					end
				end
			)
		)

		print(
			"[Bloxy Paradox] Remove lighting ON."
		)
	end

	local function restoreLighting()

		if not rlState.active then
			return
		end

		rlState.active = false

		for _, connection in ipairs(
			rlState.conns
		) do
			pcall(function()
				connection:Disconnect()
			end)
		end

		rlState.conns = {}

		if rlState.bright ~= nil then
			pcall(function()
				Lighting.Brightness =
					rlState.bright
			end)
		end

		if rlState.exp ~= nil then
			pcall(function()
				Lighting.ExposureCompensation =
					rlState.exp
			end)
		end

		for light in pairs(
			rlState.lights
		) do

			if light
				and light.Parent
			then
				pcall(function()
					light.Enabled = true
				end)
			end
		end

		rlState.lights = {}

		for effect, state in pairs(
			rlState.fx
		) do

			if effect
				and effect.Parent
			then
				pcall(function()
					effect.Enabled = state
				end)
			end
		end

		rlState.fx = {}

		print(
			"[Bloxy Paradox] Lighting restored."
		)
	end

	------------------------------------------------------------
	-- SMOOTH PLASTIC
	------------------------------------------------------------
	local spState = {
		active = false,
		orig = {},
		conn = nil,
		known = setmetatable({}, {
			__mode = "k"
		})
	}

	for _, object in ipairs(
		Workspace:GetDescendants()
	) do

		if object:IsA("BasePart")
			and object.Material ==
				Enum.Material.Plastic
		then
			spState.known[object] = true
		end
	end

	local function toSmooth(part)

		-- Deferred calls can land after a restore; skip them.
		if not spState.active
			or not part:IsA("BasePart")
		then
			return
		end

		if part.Material ~=
			Enum.Material.Plastic
		then
			return
		end

		if spState.orig[part] == nil then
			spState.orig[part] =
				part.Material
		end

		pcall(function()
			part.Material =
				Enum.Material.SmoothPlastic
		end)
	end

	local function applySmooth()

		if spState.active then
			return
		end

		spState.active = true

		for _, object in ipairs(
			Workspace:GetDescendants()
		) do
			toSmooth(object)
		end

		spState.conn =
			Workspace.DescendantAdded:Connect(
				function(object)

					if spState.active then
						task.defer(function()
							toSmooth(object)
						end)
					end
				end
			)

		print(
			"[Bloxy Paradox] Smooth Plastic ON."
		)
	end

	local function restoreSmooth()

		if not spState.active then
			return
		end

		spState.active = false

		if spState.conn then
			pcall(function()
				spState.conn:Disconnect()
			end)
			spState.conn = nil
		end

		for part, material in pairs(
			spState.orig
		) do

			if part
				and part.Parent
			then
				pcall(function()
					part.Material = material
				end)
			end
		end

		spState.orig = {}

		print(
			"[Bloxy Paradox] Plastic restored."
		)
	end

	------------------------------------------------------------
	-- PLASTIC (EVERY MATERIAL -> SMOOTH PLASTIC)
	-- Smooth plastic only converts Plastic parts; this one
	-- converts everything. The two are mutually exclusive in
	-- the materials dropdown so their restores never collide.
	------------------------------------------------------------
	local plState = {
		active = false,
		orig = {},
		conn = nil
	}

	local function toPlastic(part)

		if not plState.active
			or not part:IsA("BasePart")
			or part:IsA("Terrain")
		then
			return
		end

		if part.Material ==
			Enum.Material.SmoothPlastic
		then
			return
		end

		if plState.orig[part] == nil then
			plState.orig[part] =
				part.Material
		end

		pcall(function()
			part.Material =
				Enum.Material.SmoothPlastic
		end)
	end

	local function applyPlastic()

		if plState.active then
			return
		end

		plState.active = true

		for _, object in ipairs(
			Workspace:GetDescendants()
		) do
			toPlastic(object)
		end

		plState.conn =
			Workspace.DescendantAdded:Connect(
				function(object)

					if plState.active then
						task.defer(function()
							toPlastic(object)
						end)
					end
				end
			)

		print(
			"[Bloxy Paradox] Plastic ON."
		)
	end

	local function restorePlastic()

		if not plState.active then
			return
		end

		plState.active = false

		if plState.conn then
			pcall(function()
				plState.conn:Disconnect()
			end)
			plState.conn = nil
		end

		for part, material in pairs(
			plState.orig
		) do

			if part
				and part.Parent
			then
				pcall(function()
					part.Material = material
				end)
			end
		end

		plState.orig = {}

		print(
			"[Bloxy Paradox] Original materials restored."
		)
	end

	------------------------------------------------------------
	-- 2009 MATERIALS
	------------------------------------------------------------
	local m09 = {
		active = false,
		variants = {},
		overrides = {},
		holder = nil,
		neonConn = nil
	}

	local function apply2009()

		if m09.active then
			return
		end

		m09.active = true

		--------------------------------------------------------
		-- Turn off newer materials where supported.
		--------------------------------------------------------
		pcall(function()
			MaterialService.Use2022Materials =
				false
		end)

		local textures = {}

		--------------------------------------------------------
		-- Load material pack.
		--------------------------------------------------------
		local ok, objects =
			pcall(function()
				return game:GetObjects(
					PACK_ID
				)
			end)

		if ok and objects then

			local holder =
				Instance.new("Folder")

			holder.Name =
				"BP2009PackHolder"

			holder.Parent =
				MaterialService

			m09.holder = holder

			local function scan(object)

				if object:IsA("MaterialVariant")
					and object.ColorMap ~= ""
				then

					local name =
						object.Name:lower()

					if name:find("wood")
						and not name:find("plank")
					then
						textures.Wood =
							object.ColorMap
					end

					if name:find("slate") then
						textures.Slate =
							object.ColorMap
					end

					if name:find("concrete") then
						textures.Concrete =
							object.ColorMap
					end

					if name:find("foil") then
						textures.Foil =
							object.ColorMap
					end

					if name:find("corroded")
						or name:find("rust")
					then
						textures.CorrodedMetal =
							object.ColorMap
					end

					if name:find("diamond") then
						textures.DiamondPlate =
							object.ColorMap
					end

					if name:find("grass") then
						textures.Grass =
							object.ColorMap
					end

					if name:find("ice") then
						textures.Ice =
							object.ColorMap
					end

					if name:find("marble") then
						textures.Marble =
							object.ColorMap
					end
				end
			end

			for _, object in ipairs(objects) do

				pcall(function()
					object.Parent = holder
				end)

				scan(object)

				for _, descendant in ipairs(
					object:GetDescendants()
				) do
					scan(descendant)
				end
			end
		end

		--------------------------------------------------------
		-- Texture table
		--------------------------------------------------------
		local T = {

			Plastic = "",

			Wood =
				textures.Wood
				or "rbxassetid://12811801",

			Slate =
				textures.Slate
				or "rbxassetid://63727552",

			Concrete =
				textures.Concrete
				or "rbxassetid://63727330",

			Foil =
				textures.Foil
				or "rbxassetid://63727402",

			CorrodedMetal =
				textures.CorrodedMetal
				or "rbxassetid://63727348",

			DiamondPlate =
				textures.DiamondPlate
				or "rbxassetid://63727376",

			Grass =
				textures.Grass
				or "rbxassetid://63727421",

			Ice =
				textures.Ice
				or "",

			Marble =
				textures.Marble
				or ""
		}

		--------------------------------------------------------
		-- Modern -> old material groups
		--------------------------------------------------------
		local MAP = {

			[T.Plastic] = {
				Enum.Material.Plastic,
				Enum.Material.SmoothPlastic,
				Enum.Material.Metal,
				Enum.Material.RoofShingles,
				Enum.Material.Neon,
				Enum.Material.Glass,
				Enum.Material.ForceField
			},

			[T.Wood] = {
				Enum.Material.Wood,
				Enum.Material.WoodPlanks
			},

			[T.Slate] = {
				Enum.Material.Slate,
				Enum.Material.Cobblestone,
				Enum.Material.Pebble,
				Enum.Material.Rock,
				Enum.Material.Basalt,
				Enum.Material.Brick
			},

			[T.Concrete] = {
				Enum.Material.Concrete,
				Enum.Material.Sand,
				Enum.Material.Plaster,
				Enum.Material.Pavement,
				Enum.Material.Sandstone,
				Enum.Material.Granite,
				Enum.Material.Limestone
			},

			[T.Foil] = {
				Enum.Material.Foil,
				Enum.Material.CrackedLava
			},

			[T.CorrodedMetal] = {
				Enum.Material.CorrodedMetal
			},

			[T.DiamondPlate] = {
				Enum.Material.DiamondPlate
			},

			[T.Grass] = {
				Enum.Material.Grass,
				Enum.Material.Ground,
				Enum.Material.Mud,
				Enum.Material.LeafyGrass
			},

			[T.Ice] = {
				Enum.Material.Ice,
				Enum.Material.Glacier,
				Enum.Material.Salt
			},

			[T.Marble] = {
				Enum.Material.Marble,
				Enum.Material.CeramicTiles,
				Enum.Material.ClayRoofTiles,
				Enum.Material.Asphalt,
				Enum.Material.Rubber,
				Enum.Material.Cardboard,
				Enum.Material.Carpet,
				Enum.Material.Fabric,
				Enum.Material.Leather
			}
		}

		--------------------------------------------------------
		-- Apply variants
		--------------------------------------------------------
		for texture, materials in pairs(MAP) do

			for _, material in ipairs(materials) do

				local variantName =
					"BP2009_" ..
					material.Name

				local variant =
					MaterialService:FindFirstChild(
						variantName
					)

				if not variant then

					variant =
						Instance.new(
							"MaterialVariant"
						)

					variant.Name =
						variantName

					variant.Parent =
						MaterialService
				end

				pcall(function()
					variant.BaseMaterial =
						material

					variant.ColorMap =
						texture

					variant.StudsPerTile = 4

					variant.NormalMap = ""
					variant.RoughnessMap = ""
					variant.MetalnessMap = ""
				end)

				local previous = nil

				pcall(function()
					previous =
						MaterialService:
						GetBaseMaterialOverride(
							material
						)
				end)

				m09.overrides[
					material.Name
				] = previous or false

				local success =
					pcall(function()

						MaterialService:
							SetBaseMaterialOverride(
								material,
								variant.Name
							)
					end)

				if success then
					table.insert(
						m09.variants,
						variant
					)
				end
			end
		end

		--------------------------------------------------------
		-- Keep Neon from producing modern neon appearance.
		--------------------------------------------------------
		local function checkNeon(object)

			if object:IsA("BasePart")
				and object.Material ==
					Enum.Material.Neon
			then
				pcall(function()
					object.Material =
						Enum.Material.SmoothPlastic
				end)
			end
		end

		for _, object in ipairs(
			Workspace:GetDescendants()
		) do
			checkNeon(object)
		end

		m09.neonConn =
			Workspace.DescendantAdded:Connect(
				checkNeon
			)

		print(
			"[Bloxy Paradox] 2009 Materials ON."
		)
	end

	local function restore2009()

		if not m09.active then
			return
		end

		m09.active = false

		--------------------------------------------------------
		-- Restore material overrides
		--------------------------------------------------------
		for name, previous in pairs(
			m09.overrides
		) do

			local material

			pcall(function()
				material =
					Enum.Material[name]
			end)

			if material then

				if previous
					and previous ~= ""
				then

					pcall(function()
						MaterialService:
							SetBaseMaterialOverride(
								material,
								previous
							)
					end)

				else

					pcall(function()
						MaterialService:
							SetBaseMaterialOverride(
								material,
								""
							)
					end)
				end
			end
		end

		m09.overrides = {}

		--------------------------------------------------------
		-- Remove generated variants
		--------------------------------------------------------
		for _, variant in ipairs(
			m09.variants
		) do

			if variant
				and variant.Parent
			then
				pcall(function()
					variant:Destroy()
				end)
			end
		end

		m09.variants = {}

		if m09.holder
			and m09.holder.Parent
		then
			pcall(function()
				m09.holder:Destroy()
			end)
		end

		m09.holder = nil

		if m09.neonConn then
			pcall(function()
				m09.neonConn:Disconnect()
			end)

			m09.neonConn = nil
		end

		pcall(function()
			MaterialService.Use2022Materials =
				true
		end)

		print(
			"[Bloxy Paradox] 2009 Materials restored."
		)
	end

	------------------------------------------------------------
	-- LEGACY MATERIALS
	------------------------------------------------------------
	local lmState = {
		active = false,
		original = nil
	}

	local function applyLegacy()

		if lmState.active then
			return
		end

		lmState.active = true

		pcall(function()
			lmState.original =
				MaterialService.Use2022Materials
		end)

		local success =
			pcall(function()
				MaterialService.Use2022Materials =
					false
			end)

		if not success
			and sethiddenproperty
		then

			pcall(function()
				sethiddenproperty(
					MaterialService,
					"Use2022Materials",
					false
				)
			end)
		end

		print(
			"[Bloxy Paradox] Legacy materials ON."
		)
	end

	local function restoreLegacy()

		if not lmState.active then
			return
		end

		lmState.active = false

		local target =
			lmState.original

		if target == nil then
			target = true
		end

		local success =
			pcall(function()
				MaterialService.Use2022Materials =
					target
			end)

		if not success
			and sethiddenproperty
		then

			pcall(function()
				sethiddenproperty(
					MaterialService,
					"Use2022Materials",
					target
				)
			end)
		end

		print(
			"[Bloxy Paradox] Legacy materials restored."
		)
	end

	------------------------------------------------------------
	-- NO SHADOWS
	------------------------------------------------------------
	local shState = {
		active = false,
		originalGlobal = nil,
		partOriginal = {},
		conn = nil
	}

	local function trackPartShadow(part)

		if not part:IsA("BasePart") then
			return
		end

		if shState.partOriginal[part] == nil then
			shState.partOriginal[part] =
				part.CastShadow
		end
	end

	local function applyNoShadows()

		if shState.active then
			return
		end

		shState.active = true

		shState.originalGlobal =
			Lighting.GlobalShadows

		pcall(function()
			Lighting.GlobalShadows = false
		end)

		for _, part in ipairs(
			Workspace:GetDescendants()
		) do

			if part:IsA("BasePart") then

				trackPartShadow(part)

				pcall(function()
					part.CastShadow = false
				end)
			end
		end

		shState.conn =
			Workspace.DescendantAdded:Connect(
				function(object)

					if not shState.active then
						return
					end

					if object:IsA("BasePart") then

						task.defer(function()

							if object
								and object.Parent
							then

								trackPartShadow(object)

								pcall(function()
									object.CastShadow =
										false
								end)
							end
						end)
					end
				end
			)

		print(
			"[Bloxy Paradox] Shadows disabled."
		)
	end

	local function restoreShadows()

		if not shState.active then
			return
		end

		shState.active = false

		if shState.conn then

			pcall(function()
				shState.conn:Disconnect()
			end)

			shState.conn = nil
		end

		if shState.originalGlobal ~= nil then

			pcall(function()
				Lighting.GlobalShadows =
					shState.originalGlobal
			end)

		else

			pcall(function()
				Lighting.GlobalShadows = true
			end)
		end

		for part, original in pairs(
			shState.partOriginal
		) do

			if part
				and part.Parent
			then

				pcall(function()
					part.CastShadow = original
				end)
			end
		end

		shState.partOriginal = {}

		print(
			"[Bloxy Paradox] Shadows restored."
		)
	end

	------------------------------------------------------------
	-- UI HELPERS
	------------------------------------------------------------
	-- Rows given a parent are dropdown options: they sit inside
	-- the dropdown with a small indent and slightly smaller text.
	local function makeToggle(
		name,
		labelText,
		yPos,
		checked,
		parent
	)

		local isOption = parent ~= nil

		local container =
			Instance.new("Frame")

		container.Name =
			name .. "Container"

		container.Size =
			isOption
			and UDim2.new(1, 0, 0, 30)
			or UDim2.new(1, -30, 0, 30)

		container.Position =
			isOption
			and UDim2.new(0, 0, 0, yPos)
			or UDim2.new(0, 15, 0, yPos)

		container.BackgroundTransparency = 1
		container.ZIndex = 96
		container.Parent = parent or hammerPanel

		local label =
			Instance.new("TextLabel")

		label.Name =
			name .. "Label"

		label.Size =
			isOption
			and UDim2.new(0, 112, 0, 30)
			or UDim2.new(0, 115, 0, 30)

		label.Position =
			isOption
			and UDim2.new(0, 6, 0, 0)
			or UDim2.new(0, 0, 0, 0)

		label.BackgroundTransparency = 1

		if fontBold then
			label.FontFace = fontBold
		else
			label.Font =
				Enum.Font.SourceSansBold
		end

		label.TextSize =
			isOption and 14 or 16

		label.TextColor3 =
			Color3.fromRGB(
				255,
				255,
				255
			)

		label.TextXAlignment =
			Enum.TextXAlignment.Left

		label.Text =
			labelText

		label.ZIndex = 97
		label.Parent = container

		local checkbox =
			Instance.new("TextButton")

		checkbox.Name =
			name .. "Checkbox"

		checkbox.Size =
			UDim2.new(0, 16, 0, 16)

		checkbox.Position =
			UDim2.new(0, 118, 0, 7)

		checkbox.BackgroundColor3 =
			Color3.fromRGB(
				220,
				220,
				220
			)

		checkbox.BackgroundTransparency = 0.5
		checkbox.BorderSizePixel = 0

		checkbox.Text =
			checked and "✓" or ""

		checkbox.Font =
			Enum.Font.SourceSansBold

		checkbox.TextSize = 18

		checkbox.TextColor3 =
			Color3.fromRGB(
				0,
				220,
				0
			)

		checkbox.ZIndex = 97
		checkbox.Parent = container

		local stroke =
			Instance.new("UIStroke")

		stroke.Color =
			Color3.fromRGB(
				255,
				255,
				255
			)

		stroke.Thickness = 1.2
		stroke.ApplyStrokeMode =
			Enum.ApplyStrokeMode.Border

		stroke.Parent = checkbox

		local help =
			Instance.new("TextButton")

		help.Name =
			name .. "HelpButton"

		help.Size =
			UDim2.new(0, 16, 0, 16)

		help.Position =
			UDim2.new(0, 140, 0, 7)

		help.BackgroundColor3 =
			Color3.fromRGB(
				220,
				220,
				220
			)

		help.BackgroundTransparency = 0.5
		help.BorderSizePixel = 0

		help.Text = "?"

		help.Font =
			Enum.Font.SourceSansBold

		help.TextSize = 14

		help.TextColor3 =
			Color3.fromRGB(
				255,
				255,
				255
			)

		help.ZIndex = 97
		help.Parent = container

		local helpStroke =
			Instance.new("UIStroke")

		helpStroke.Color =
			Color3.fromRGB(
				255,
				255,
				255
			)

		helpStroke.Thickness = 1.2

		helpStroke.ApplyStrokeMode =
			Enum.ApplyStrokeMode.Border

		helpStroke.Parent = help

		return checkbox, help
	end

	------------------------------------------------------------
	-- DROPDOWN HELPERS
	------------------------------------------------------------
	-- Moves every panel row below yPos. Works on rows added by
	-- other addon scripts too, since it only looks at positions.
	local function shiftBelow(yPos, amount)

		for _, child in ipairs(
			hammerPanel:GetChildren()
		) do

			if child:IsA("GuiObject")
				and child.Position.Y.Scale == 0
				and child.Position.Y.Offset > yPos
			then
				local p = child.Position

				child.Position =
					UDim2.new(
						p.X.Scale,
						p.X.Offset,
						0,
						p.Y.Offset + amount
					)
			end
		end
	end

	-- Header row in the same style as a toggle, but its box is
	-- an arrow that opens the option rows underneath it.
	-- Returns the frame the option rows go into and the "?".
	local function makeDropdown(
		name,
		labelText,
		yPos,
		optionCount
	)

		local arrow, help =
			makeToggle(
				name,
				labelText,
				yPos,
				false
			)

		local container = arrow.Parent

		arrow.Name =
			name .. "Arrow"

		arrow.Text = "▼"
		arrow.TextSize = 12

		arrow.TextColor3 =
			Color3.fromRGB(
				255,
				255,
				255
			)

		local height =
			optionCount * 30

		local options =
			Instance.new("Frame")

		options.Name =
			name .. "Options"

		options.Size =
			UDim2.new(1, 0, 0, height)

		options.Position =
			UDim2.new(0, 0, 0, 30)

		options.BackgroundTransparency = 1
		options.Visible = false
		options.ZIndex = 96
		options.Parent = container

		local guide =
			Instance.new("Frame")

		guide.Name = "Guide"

		guide.Size =
			UDim2.new(0, 2, 1, -6)

		guide.Position =
			UDim2.new(0, 0, 0, 3)

		guide.BackgroundColor3 =
			Color3.fromRGB(
				255,
				255,
				255
			)

		guide.BackgroundTransparency = 0.5
		guide.BorderSizePixel = 0
		guide.ZIndex = 97
		guide.Parent = options

		local expanded = false

		arrow.MouseButton1Click:Connect(
			function()

				playClick()

				expanded = not expanded

				options.Visible = expanded
				arrow.Text =
					expanded and "▲" or "▼"

				container.Size =
					UDim2.new(
						1,
						-30,
						0,
						expanded
							and 30 + height
							or 30
					)

				shiftBelow(
					container.Position.Y.Offset,
					expanded and height or -height
				)
			end
		)

		return options, help
	end

	------------------------------------------------------------
	-- CREATE ADDON BUTTONS
	------------------------------------------------------------
	local sky2013CB, sky2013Help =
		makeToggle(
			"Skybox2013",
			"2013 skybox",
			120,
			isSkybox2013Enabled
		)

	local rlCB, rlHelp =
		makeToggle(
			"RemoveLighting",
			"remove lighting",
			160,
			isRemoveLightingEnabled
		)

	local materialsOptions, materialsHelp =
		makeDropdown(
			"MaterialsDropdown",
			"materials",
			200,
			4
		)

	local spCB, spHelp =
		makeToggle(
			"SmoothPlastic",
			"smooth plastic",
			0,
			isSmoothPlasticEnabled,
			materialsOptions
		)

	local plCB, plHelp =
		makeToggle(
			"Plastic",
			"plastic",
			30,
			isPlasticEnabled,
			materialsOptions
		)

	local m09CB, m09Help =
		makeToggle(
			"Materials2009",
			"2009 materials",
			60,
			is2009MaterialsEnabled,
			materialsOptions
		)

	local lmCB, lmHelp =
		makeToggle(
			"LegacyMaterials",
			"legacy materials",
			90,
			isLegacyMaterialsEnabled,
			materialsOptions
		)

	local shCB, shHelp =
		makeToggle(
			"NoShadows",
			"no shadows",
			240,
			isNoShadowsEnabled
		)

	------------------------------------------------------------
	-- DESTROY GUI BUTTON
	------------------------------------------------------------
	local destroyBtn =
		Instance.new("TextButton")

	destroyBtn.Name =
		"BPDestroyGuiButton"

	destroyBtn.Size =
		UDim2.new(1, -30, 0, 36)

	destroyBtn.Position =
		UDim2.new(0, 15, 0, 280)

	destroyBtn.BackgroundColor3 =
		Color3.fromRGB(
			180,
			30,
			30
		)

	destroyBtn.BorderSizePixel = 0

	destroyBtn.Text =
		"destroy GUI"

	if fontBold then
		destroyBtn.FontFace = fontBold
	else
		destroyBtn.Font =
			Enum.Font.SourceSansBold
	end

	destroyBtn.TextSize = 16

	destroyBtn.TextColor3 =
		Color3.fromRGB(
			255,
			255,
			255
		)

	destroyBtn.ZIndex = 97
	destroyBtn.AutoButtonColor = true
	destroyBtn.Parent = hammerPanel

	local destroyCorner =
		Instance.new("UICorner")

	destroyCorner.CornerRadius =
		UDim.new(0, 6)

	destroyCorner.Parent =
		destroyBtn

	local destroyStroke =
		Instance.new("UIStroke")

	destroyStroke.Color =
		Color3.fromRGB(
			255,
			80,
			80
		)

	destroyStroke.Thickness = 1.5

	destroyStroke.ApplyStrokeMode =
		Enum.ApplyStrokeMode.Border

	destroyStroke.Parent =
		destroyBtn

	------------------------------------------------------------
	-- BOTTOM SPACER
	------------------------------------------------------------
	local bottomSpacer =
		Instance.new("Frame")

	bottomSpacer.Name =
		"BPBottomSpacer"

	bottomSpacer.Size =
		UDim2.new(0, 1, 0, 30)

	bottomSpacer.Position =
		UDim2.new(0, 0, 0, 320)

	bottomSpacer.BackgroundTransparency = 1
	bottomSpacer.BorderSizePixel = 0
	bottomSpacer.ZIndex = 1
	bottomSpacer.Parent = hammerPanel

	------------------------------------------------------------
	-- CATEGORY TITLE (Addtion-Scripts copy)
	-- Every option in this part of the panel is about the sky and the world (skyboxes, lighting,
	-- materials, shadows), so they get one title above them, like the categories in Hammer stuff 2.
	------------------------------------------------------------
	pcall(function()
		local old = hammerPanel:FindFirstChild("BPCategoryWorld")
		if old then old:Destroy() end

		local firstY = nil
		for _, child in ipairs(hammerPanel:GetChildren()) do
			if child:IsA("GuiObject") and child.Position.Y.Scale == 0
				and string.sub(child.Name, -9) == "Container" then
				local y = child.Position.Y.Offset
				if not firstY or y < firstY then firstY = y end
			end
		end
		if not firstY then return end

		local TITLE_HEIGHT = 30
		for _, child in ipairs(hammerPanel:GetChildren()) do
			if child:IsA("GuiObject") and child.Position.Y.Scale == 0
				and child.Position.Y.Offset >= firstY then
				local p = child.Position
				child.Position = UDim2.new(p.X.Scale, p.X.Offset, 0, p.Y.Offset + TITLE_HEIGHT)
			end
		end

		local title = Instance.new("Frame")
		title.Name = "BPCategoryWorld"
		title.Size = UDim2.new(1, -30, 0, TITLE_HEIGHT)
		title.Position = UDim2.new(0, 15, 0, firstY)
		title.BackgroundTransparency = 1
		title.ZIndex = 96
		title.Parent = hammerPanel

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 0, 22)
		lbl.Position = UDim2.new(0, 0, 0, 6)
		lbl.BackgroundTransparency = 1
		if fontBold then lbl.FontFace = fontBold else lbl.Font = Enum.Font.SourceSansBold end
		lbl.TextSize = 13
		lbl.TextColor3 = Color3.fromRGB(255, 220, 120)
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = "SKY & WORLD"
		lbl.ZIndex = 97
		lbl.Parent = title

		local line = Instance.new("Frame")
		line.Size = UDim2.new(1, 0, 0, 1)
		line.Position = UDim2.new(0, 0, 1, -2)
		line.BackgroundColor3 = Color3.fromRGB(255, 220, 120)
		line.BackgroundTransparency = 0.5
		line.BorderSizePixel = 0
		line.ZIndex = 97
		line.Parent = title

		-- The panel opens scrolled down to the title, so the title and the first options are at the
		-- top. (The rows are not moved up: Bloxy places some of its own rows by their position, and
		-- moving them made rows land on top of each other.)
		local TOP_MARGIN = 6
		if hammerPanel:IsA("ScrollingFrame") then
			local scroller = hammerPanel
			local function toTitle()
				local t = scroller:FindFirstChild("BPCategoryWorld")
				if not t then return end
				local y = math.max(0, t.Position.Y.Offset - TOP_MARGIN)
				scroller.CanvasPosition = Vector2.new(0, y)
			end
			task.defer(toTitle)
			task.delay(0.5, toTitle)
			-- and again every time the hammer panel is opened
			if originalHammerPanel and originalHammerPanel:IsA("GuiObject") then
				originalHammerPanel:GetPropertyChangedSignal("Visible"):Connect(function()
					if originalHammerPanel.Visible then task.defer(toTitle) end
				end)
			end
		end
	end)

	------------------------------------------------------------
	-- DESTROY GUI
	------------------------------------------------------------
	destroyBtn.MouseButton1Click:Connect(
		function()

			playClick()

			local objects = {
				"New2010Container",
				"Skybox2013Container",
				"RemoveLightingContainer",
				"MaterialsDropdownContainer",
				"SmoothPlasticContainer",
				"PlasticContainer",
				"Materials2009Container",
				"LegacyMaterialsContainer",
				"NoShadowsContainer",
				"SkipInfoPanel",
				"BPDestroyGuiButton",
				"BPAddonScroller",
				"BPBottomSpacer"
			}

			for _, name in ipairs(objects) do

				local object =
					sg:FindFirstChild(
						name,
						true
					)

				if object then

					pcall(function()
						object:Destroy()
					end)
				end
			end

			task.wait(0.15)

			if sg
				and sg.Parent
			then

				pcall(function()
					sg:Destroy()
				end)
			end

			print(
				"[Bloxy Paradox] GUI destroyed."
			)
		end
	)

	------------------------------------------------------------
	-- 2013 SKYBOX BUTTON
	------------------------------------------------------------
	sky2013CB.MouseButton1Click:Connect(
		function()

			playClick()

			if not isSkybox2013Enabled then

				isSkybox2013Enabled = true
				sky2013CB.Text = "✓"

				if skyboxCheckbox2008 then
					skyboxCheckbox2008.Text = ""
				end

				config.isSkyboxEnabled = false

				task.spawn(function()
					pcall(apply2013)
				end)

			else

				isSkybox2013Enabled = false
				sky2013CB.Text = ""

				task.spawn(function()
					pcall(
						restoreOriginalSky
					)
				end)
			end

			config.isSkybox2013Enabled =
				isSkybox2013Enabled

			saveConfig()
		end
	)

	------------------------------------------------------------
	-- REMOVE LIGHTING BUTTON
	------------------------------------------------------------
	rlCB.MouseButton1Click:Connect(
		function()

			playClick()

			if not isRemoveLightingEnabled then

				isRemoveLightingEnabled = true
				rlCB.Text = "✓"

				task.spawn(function()
					pcall(
						applyRemoveLighting
					)
				end)

			else

				isRemoveLightingEnabled = false
				rlCB.Text = ""

				task.spawn(function()
					pcall(
						restoreLighting
					)
				end)
			end

			config.isRemoveLightingEnabled =
				isRemoveLightingEnabled

			saveConfig()
		end
	)

	------------------------------------------------------------
	-- SMOOTH PLASTIC BUTTON
	------------------------------------------------------------
	spCB.MouseButton1Click:Connect(
		function()

			playClick()

			if not isSmoothPlasticEnabled then

				isSmoothPlasticEnabled = true
				spCB.Text = "✓"

				-- Plastic and smooth plastic can't both be on.
				local wasPlastic = isPlasticEnabled

				if wasPlastic then
					isPlasticEnabled = false
					plCB.Text = ""
					config.isPlasticEnabled = false
				end

				task.spawn(function()
					if wasPlastic then
						pcall(restorePlastic)
					end
					pcall(applySmooth)
				end)

			else

				isSmoothPlasticEnabled = false
				spCB.Text = ""

				task.spawn(function()
					pcall(restoreSmooth)
				end)
			end

			config.isSmoothPlasticEnabled =
				isSmoothPlasticEnabled

			saveConfig()
		end
	)

	------------------------------------------------------------
	-- PLASTIC BUTTON
	------------------------------------------------------------
	plCB.MouseButton1Click:Connect(
		function()

			playClick()

			if not isPlasticEnabled then

				isPlasticEnabled = true
				plCB.Text = "✓"

				local wasSmooth = isSmoothPlasticEnabled

				if wasSmooth then
					isSmoothPlasticEnabled = false
					spCB.Text = ""
					config.isSmoothPlasticEnabled = false
				end

				task.spawn(function()
					if wasSmooth then
						pcall(restoreSmooth)
					end
					pcall(applyPlastic)
				end)

			else

				isPlasticEnabled = false
				plCB.Text = ""

				task.spawn(function()
					pcall(restorePlastic)
				end)
			end

			config.isPlasticEnabled =
				isPlasticEnabled

			saveConfig()
		end
	)

	------------------------------------------------------------
	-- 2009 MATERIAL BUTTON
	------------------------------------------------------------
	m09CB.MouseButton1Click:Connect(
		function()

			playClick()

			if not is2009MaterialsEnabled then

				is2009MaterialsEnabled = true
				m09CB.Text = "✓"

				task.spawn(function()
					pcall(apply2009)
				end)

			else

				is2009MaterialsEnabled = false
				m09CB.Text = ""

				task.spawn(function()
					pcall(restore2009)
				end)
			end

			config.is2009MaterialsEnabled =
				is2009MaterialsEnabled

			saveConfig()
		end
	)

	------------------------------------------------------------
	-- LEGACY MATERIAL BUTTON
	------------------------------------------------------------
	lmCB.MouseButton1Click:Connect(
		function()

			playClick()

			if not isLegacyMaterialsEnabled then

				isLegacyMaterialsEnabled = true
				lmCB.Text = "✓"

				task.spawn(function()
					pcall(applyLegacy)
				end)

			else

				isLegacyMaterialsEnabled = false
				lmCB.Text = ""

				task.spawn(function()
					pcall(restoreLegacy)
				end)
			end

			config.isLegacyMaterialsEnabled =
				isLegacyMaterialsEnabled

			saveConfig()
		end
	)

	------------------------------------------------------------
	-- NO SHADOWS BUTTON
	------------------------------------------------------------
	shCB.MouseButton1Click:Connect(
		function()

			playClick()

			if not isNoShadowsEnabled then

				isNoShadowsEnabled = true
				shCB.Text = "✓"

				task.spawn(function()
					pcall(applyNoShadows)
				end)

			else

				isNoShadowsEnabled = false
				shCB.Text = ""

				task.spawn(function()
					pcall(restoreShadows)
				end)
			end

			config.isNoShadowsEnabled =
				isNoShadowsEnabled

			saveConfig()
		end
	)

	------------------------------------------------------------
	-- 2008 SKYBOX BUTTON
	------------------------------------------------------------
	if skyboxCheckbox2008 then

		skyboxCheckbox2008.MouseButton1Click:Connect(
			function()

				playClick()

				task.defer(function()

					if skyboxCheckbox2008.Text == "✓" then

						if isSkybox2013Enabled then

							isSkybox2013Enabled = false
							sky2013CB.Text = ""

							config.isSkybox2013Enabled =
								false

							saveConfig()
						end

						task.spawn(function()
							pcall(apply2008)
						end)

					else

						task.spawn(function()
							pcall(
								restoreOriginalSky
							)
						end)
					end
				end)
			end
		)
	end

	------------------------------------------------------------
	-- UNSELECT ALL (called by Hammer stuff 2's "unselect all"
	-- button through getgenv().BPHammer1UnselectAll)
	-- Turns off every option of this script the same way
	-- unticking it would. Dropdowns stay open or closed as they
	-- are; only the boxes change.
	------------------------------------------------------------
	local unselecting = false

	local function unselectAll()
		if unselecting then
			return
		end
		unselecting = true

		local restores = {}

		if isSkybox2013Enabled then
			isSkybox2013Enabled = false
			sky2013CB.Text = ""
			config.isSkybox2013Enabled = false
			table.insert(restores, restoreOriginalSky)
		end

		if isRemoveLightingEnabled then
			isRemoveLightingEnabled = false
			rlCB.Text = ""
			config.isRemoveLightingEnabled = false
			table.insert(restores, restoreLighting)
		end

		if isSmoothPlasticEnabled then
			isSmoothPlasticEnabled = false
			spCB.Text = ""
			config.isSmoothPlasticEnabled = false
			table.insert(restores, restoreSmooth)
		end

		if isPlasticEnabled then
			isPlasticEnabled = false
			plCB.Text = ""
			config.isPlasticEnabled = false
			table.insert(restores, restorePlastic)
		end

		if is2009MaterialsEnabled then
			is2009MaterialsEnabled = false
			m09CB.Text = ""
			config.is2009MaterialsEnabled = false
			table.insert(restores, restore2009)
		end

		if isLegacyMaterialsEnabled then
			isLegacyMaterialsEnabled = false
			lmCB.Text = ""
			config.isLegacyMaterialsEnabled = false
			table.insert(restores, restoreLegacy)
		end

		if isNoShadowsEnabled then
			isNoShadowsEnabled = false
			shCB.Text = ""
			config.isNoShadowsEnabled = false
			table.insert(restores, restoreShadows)
		end

		saveConfig()

		-- One after another, so restores that touch the same
		-- parts (the material options) don't run over each other.
		task.spawn(function()
			for _, restore in ipairs(restores) do
				pcall(restore)
			end
			unselecting = false
		end)

		return #restores
	end

	do
		local genv = (getgenv and getgenv()) or _G
		genv.BPHammer1UnselectAll = unselectAll
	end

	------------------------------------------------------------
	-- HELP SYSTEM
	------------------------------------------------------------
	local function showHelp(text)

		if not infoPanel
			or not infoPanel.Parent
		then
			return
		end

		local textObject =
			infoPanel:FindFirstChild(
				"InfoText",
				true
			)

		if not textObject then
			return
		end

		pcall(function()

			textObject.Text =
				tostring(text)

			local length =
				#tostring(text)

			if length <= 50 then
				textObject.TextSize = 18

			elseif length >= 250 then
				textObject.TextSize = 12

			else
				textObject.TextSize =
					math.floor(
						18 -
						((length - 50) / 200) * 6
					)
			end

			infoPanel.Visible = true
		end)
	end

	local function hideHelp()

		if infoPanel
			and infoPanel.Parent
		then

			pcall(function()
				infoPanel.Visible = false
			end)
		end
	end

	------------------------------------------------------------
	-- HELP BUTTONS
	------------------------------------------------------------
	sky2013Help.MouseButton1Click:Connect(
		function()
			playClick()
			showHelp(
				"Applies the 2013 Roblox skybox."
			)
		end
	)

	rlHelp.MouseButton1Click:Connect(
		function()
			playClick()
			showHelp(
				"Disables local light sources and selected modern lighting effects."
			)
		end
	)

	materialsHelp.MouseButton1Click:Connect(
		function()
			playClick()
			showHelp(
				"Press the arrow to open the material options: smooth plastic, plastic, 2009 materials and legacy materials."
			)
		end
	)

	spHelp.MouseButton1Click:Connect(
		function()
			playClick()
			showHelp(
				"Changes normal Plastic parts to SmoothPlastic. Turns off plastic."
			)
		end
	)

	plHelp.MouseButton1Click:Connect(
		function()
			playClick()
			showHelp(
				"Sets every part's material to SmoothPlastic, including new parts. Disabling restores the original materials. Turns off smooth plastic."
			)
		end
	)

	m09Help.MouseButton1Click:Connect(
		function()
			playClick()
			showHelp(
				"Applies the available 2009-style material textures through MaterialService."
			)
		end
	)

	lmHelp.MouseButton1Click:Connect(
		function()
			playClick()
			showHelp(
				"Turns off Roblox's newer 2022 material system when the client permits it."
			)
		end
	)

	shHelp.MouseButton1Click:Connect(
		function()
			playClick()
			showHelp(
				"Disables GlobalShadows and CastShadow on workspace parts."
			)
		end
	)

	------------------------------------------------------------
	-- APPLY SAVED SETTINGS
	------------------------------------------------------------
	task.spawn(function()

		task.wait(0.25)

		if isSkybox2013Enabled then
			pcall(apply2013)
		end

		if isRemoveLightingEnabled then
			pcall(applyRemoveLighting)
		end

		if isSmoothPlasticEnabled then
			pcall(applySmooth)
		elseif isPlasticEnabled then
			pcall(applyPlastic)
		end

		if is2009MaterialsEnabled then
			pcall(apply2009)
		end

		if isLegacyMaterialsEnabled then
			pcall(applyLegacy)
		end

		if isNoShadowsEnabled then
			pcall(applyNoShadows)
		end
	end)

	------------------------------------------------------------
	-- FINAL STATUS
	------------------------------------------------------------
	print("==================================================")
	print("[Bloxy Paradox] Addon loaded successfully.")
	print("[Bloxy Paradox] 2013 Skybox:", isSkybox2013Enabled)
	print("[Bloxy Paradox] Remove Lighting:", isRemoveLightingEnabled)
	print("[Bloxy Paradox] Smooth Plastic:", isSmoothPlasticEnabled)
	print("[Bloxy Paradox] Plastic:", isPlasticEnabled)
	print("[Bloxy Paradox] 2009 Materials:", is2009MaterialsEnabled)
	print("[Bloxy Paradox] Legacy Materials:", isLegacyMaterialsEnabled)
	print("[Bloxy Paradox] No Shadows:", isNoShadowsEnabled)
	print("==================================================")

end)