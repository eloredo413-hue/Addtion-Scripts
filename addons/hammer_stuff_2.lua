-- [[ HEALTH ESP + REMOVE PRO + CLASSIC OUTLINE + LENS FLARE + AVATAR DROPDOWN (OLD / 2006)
--    + CLASSIC FACE + COLOR LIMITER DROPDOWN (2012 / 2006 / 2005) + OLD DECAL RENDERING BUTTON ]]

task.spawn(function()
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local Teams = game:GetService("Teams")
	local SoundService = game:GetService("SoundService")
	local Lighting = game:GetService("Lighting")

	local CONFIG_FILE = "BloxyParadoxConfig.json"

	local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
	local pg = player:WaitForChild("PlayerGui", 15)
	if not pg then
		warn("[Addon] PlayerGui never appeared.")
		return
	end

	local sg = pg:WaitForChild("BloxyParadoxProject", 15)
	if not sg then
		pcall(function()
			sg = game:GetService("CoreGui"):FindFirstChild("BloxyParadoxProject")
		end)
	end
	if not sg then
		warn("[Addon] BloxyParadoxProject never appeared.")
		return
	end

	local hammerPanel = sg:WaitForChild("HammerBigPanel", 15)
	if not hammerPanel then
		warn("[Addon] HammerBigPanel never appeared.")
		return
	end

	local scroll = hammerPanel:FindFirstChild("BPAddonScroller") or hammerPanel

	local config = {}
	if readfile and isfile and isfile(CONFIG_FILE) then
		pcall(function() config = HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
	end
	if type(config) ~= "table" then config = {} end
	config.Choices = config.Choices or {}

	local state = {
		isHealthESPEnabled   = config.isHealthESPEnabled or false,
		isRemoveProEnabled   = config.isRemoveProEnabled or false,
		isOutlineEnabled     = config.isOutlineEnabled or false,
		isLensFlareEnabled   = config.isLensFlareEnabled or false,
		isOldAvatarEnabled   = config.isOldAvatarEnabled or false,
		isClassicFaceEnabled = config.isClassicFaceEnabled or false,
		is2006AvatarEnabled  = config.is2006AvatarEnabled or false,
		is2012ColorsEnabled  = config.is2012ColorsEnabled or false,
		is2006ColorsEnabled  = config.is2006ColorsEnabled or false,
		is2005ColorsEnabled  = config.is2005ColorsEnabled or false,
		isOldDecalEnabled    = config.isOldDecalEnabled or false,
	}

	local function saveConfig()
		for key, value in pairs(state) do
			config[key] = value
		end
		if writefile then
			pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(config)) end)
		end
	end

	local clickSfx = Instance.new("Sound")
	clickSfx.SoundId = "rbxassetid://12221967"
	clickSfx.Volume = 0.6
	clickSfx.Parent = SoundService
	local function playClick()
		clickSfx:Stop()
		clickSfx:Play()
	end

	local fontBold = Font.new("rbxasset://fonts/families/Arial.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	local actions = {}

	------------------------------------------------------------
	-- 1. HEALTH ESP LOGIC
	------------------------------------------------------------
	do
		local MAX_DISTANCE = 100
		local HEIGHT_OFFSET = 2.8

		local hpState = {
			active = false,
			connections = {},
			humanoids = {},
			baseGui = nil
		}

		local function isFinite(num)
			return num == num and num ~= -1/0 and num ~= 1/0
		end

		local function buildHealthBase()
			local healthBase = Instance.new("BillboardGui")
			healthBase.Name = "CustomExecutorHealth"
			healthBase.AlwaysOnTop = false
			healthBase.MaxDistance = math.huge
			healthBase.Size = UDim2.new(0, 200, 0, 60)
			healthBase.StudsOffsetWorldSpace = Vector3.new(0, HEIGHT_OFFSET, 0)
			healthBase.ResetOnSpawn = true

			local playerName = Instance.new("TextLabel")
			playerName.Name = "PlayerName"
			playerName.AnchorPoint = Vector2.new(0.5, 0)
			playerName.BackgroundTransparency = 1
			playerName.Font = Enum.Font.SourceSans
			playerName.Position = UDim2.new(0.5, 0, 0, 0)
			playerName.Size = UDim2.new(1, 0, 0, 20)
			playerName.TextScaled = false
			playerName.TextSize = 24
			playerName.TextStrokeTransparency = 0
			playerName.TextColor3 = Color3.new(1, 1, 1)
			playerName.TextStrokeColor3 = Color3.new(0, 0, 0)
			playerName.TextXAlignment = Enum.TextXAlignment.Center
			playerName.TextYAlignment = Enum.TextYAlignment.Top
			playerName.Parent = healthBase

			local redBar = Instance.new("Frame")
			redBar.Name = "RedBar"
			redBar.AnchorPoint = Vector2.new(0.5, 0)
			redBar.BackgroundColor3 = Color3.new(1, 0, 0)
			redBar.BorderSizePixel = 0
			redBar.Position = UDim2.new(0.5, 0, 0, 24)
			redBar.Size = UDim2.new(0, 60, 0, 8)
			redBar.Parent = healthBase

			local greenBar = Instance.new("Frame")
			greenBar.Name = "GreenBar"
			greenBar.BackgroundColor3 = Color3.new(0.5058824, 0.7725491, 0.08627451)
			greenBar.BorderSizePixel = 0
			greenBar.Size = UDim2.new(1, 0, 1, 0)
			greenBar.Parent = redBar

			return healthBase
		end

		local function setupHumanoidESP(h)
			local updateCon = nil
			local currentHealth = nil

			local function onAncestryChanged()
				if updateCon then updateCon:Disconnect() updateCon = nil end
				if currentHealth then currentHealth:Destroy() currentHealth = nil end

				local char = h.Parent
				if char then
					task.spawn(function()
						while not char:FindFirstChild("Head") do
							if h.Parent ~= char then break end
							char.ChildAdded:Wait()
						end

						local head = char:FindFirstChild("Head")
						if head and hpState.active and hpState.baseGui then
							local health = hpState.baseGui:Clone()
							local pName = health:WaitForChild("PlayerName")
							local rBar = health:WaitForChild("RedBar")
							local gBar = rBar:WaitForChild("GreenBar")

							local hPlayer = Players:GetPlayerFromCharacter(char)
							pName.Text = char.Name
							health.Adornee = head
							if hPlayer then health.PlayerToHideFrom = hPlayer end
							health.Parent = head

							local function update()
								if not head or not head.Parent then return end
								local camera = workspace.CurrentCamera
								if not camera then return end

								local dist = (camera.CFrame.Position - head.Position).Magnitude
								local fontSize = 12
								local barWidth = 40
								local barHeight = 6

								if dist < 25 then
									fontSize = 20
									barWidth = 60
									barHeight = 8
								elseif dist < 50 then
									fontSize = 15
									barWidth = 50
									barHeight = 7
								end

								local gap = 2

								pName.TextSize = fontSize
								pName.Size = UDim2.new(1, 0, 0, fontSize)
								pName.Position = UDim2.new(0.5, 0, 0, 0)
								pName.AnchorPoint = Vector2.new(0.5, 0)
								pName.TextXAlignment = Enum.TextXAlignment.Center

								rBar.AnchorPoint = Vector2.new(0.5, 0)
								rBar.Position = UDim2.new(0.5, 0, 0, fontSize + gap)
								rBar.Size = UDim2.new(0, barWidth, 0, barHeight)

								health.Size = UDim2.new(0, 200, 0, fontSize + gap + barHeight + 10)
								health.Enabled = (dist <= MAX_DISTANCE and head.Transparency < 1)
								health.StudsOffsetWorldSpace = Vector3.new(0, HEIGHT_OFFSET, 0)

								local ratio = (h.MaxHealth > 0) and (h.Health / h.MaxHealth) or 0
								if isFinite(ratio) then
									rBar.Visible = true
									rBar.BackgroundTransparency = (ratio >= 1) and 1 or 0
									gBar.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)
								else
									rBar.Visible = false
								end

								if hPlayer and Teams:FindFirstChildOfClass("Team") then
									pName.TextColor3 = hPlayer.TeamColor.Color
								else
									pName.TextColor3 = Color3.new(1, 1, 1)
								end

								local overWriter = char:FindFirstChild("NameOverwrite")
								if overWriter and overWriter:IsA("StringValue") then
									pName.Text = overWriter.Value
								else
									pName.Text = char.Name
								end
							end

							updateCon = RunService.RenderStepped:Connect(update)
							table.insert(hpState.connections, updateCon)
							currentHealth = health
							h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
						end
					end)
				end
			end

			onAncestryChanged()
			local ancConn = h.AncestryChanged:Connect(onAncestryChanged)
			table.insert(hpState.connections, ancConn)
		end

		function actions.applyHealthESP()
			if hpState.active then return end
			hpState.active = true
			hpState.baseGui = buildHealthBase()

			for _, desc in pairs(workspace:GetDescendants()) do
				if desc:IsA("Humanoid") then hpState.humanoids[desc] = true end
			end

			for h in pairs(hpState.humanoids) do
				task.spawn(function() setupHumanoidESP(h) end)
			end

			local descConn = workspace.DescendantAdded:Connect(function(child)
				if not hpState.active then return end
				if child:IsA("Humanoid") then
					hpState.humanoids[child] = true
					setupHumanoidESP(child)
				end
			end)
			table.insert(hpState.connections, descConn)
			print("[Health ESP] Enabled.")
		end

		function actions.restoreHealthESP()
			if not hpState.active then return end
			hpState.active = false

			for _, conn in ipairs(hpState.connections) do
				pcall(function() conn:Disconnect() end)
			end
			hpState.connections = {}

			for _, desc in pairs(workspace:GetDescendants()) do
				if desc:IsA("BillboardGui") and desc.Name == "CustomExecutorHealth" then
					pcall(function() desc:Destroy() end)
				end
			end

			if hpState.baseGui then
				pcall(function() hpState.baseGui:Destroy() end)
				hpState.baseGui = nil
			end
			hpState.humanoids = {}
			print("[Health ESP] Disabled.")
		end
	end

	------------------------------------------------------------
	-- 2. REMOVE PRO LOGIC
	------------------------------------------------------------
	do
		local rpState = {
			active = false,
			connections = {},
			colorCorrection = nil,
			savedLighting = nil,
		}

		local function captureLighting()
			return {
				Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
				Brightness = Lighting.Brightness,
				ColorShift_Bottom = Lighting.ColorShift_Bottom, ColorShift_Top = Lighting.ColorShift_Top,
				EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
				EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
				GlobalShadows = Lighting.GlobalShadows,
				ExposureCompensation = Lighting.ExposureCompensation,
				FogColor = Lighting.FogColor, FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
				ShadowColor = Lighting.ShadowColor, ShadowSoftness = Lighting.ShadowSoftness,
			}
		end

		local function restoreLighting(saved)
			if not saved then return end
			for k, v in pairs(saved) do
				pcall(function() Lighting[k] = v end)
			end
		end

		function actions.applyRemovePro()
			if rpState.active then return end
			rpState.active = true

			local Workspace = game:GetService("Workspace")
			rpState.savedLighting = captureLighting()

			for _, child in ipairs(Lighting:GetChildren()) do
				if child:IsA("PostEffect") or child:IsA("Atmosphere") then
					pcall(function() child:Destroy() end)
				end
			end

			pcall(function() sethiddenproperty(Lighting, "Technology", Enum.Technology.Compatibility) end)
			pcall(function() Lighting.Technology = Enum.Technology.Compatibility end)
			pcall(function() Lighting.ToneMapper = Enum.ToneMapper.Retro end)

			Lighting.Ambient = Color3.fromRGB(150, 150, 150)
			Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)
			Lighting.Brightness = 1.5
			Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
			Lighting.ColorShift_Top = Color3.fromRGB(0, 0, 0)
			Lighting.EnvironmentDiffuseScale = 0
			Lighting.EnvironmentSpecularScale = 0
			Lighting.GlobalShadows = false
			Lighting.ExposureCompensation = 0
			Lighting.FogColor = Color3.fromRGB(191, 191, 191)
			Lighting.FogEnd = 100000
			Lighting.FogStart = 0
			Lighting.ShadowColor = Color3.fromRGB(178, 178, 184)
			Lighting.ShadowSoftness = 0.1

			local cc = Instance.new("ColorCorrectionEffect")
			cc.Name = "CustomColorCorrection"
			cc.Brightness = 0
			cc.Contrast = 0
			cc.Saturation = 0
			cc.TintColor = Color3.fromRGB(255, 255, 255)
			cc.Enabled = true
			cc.Parent = Lighting
			rpState.colorCorrection = cc

			local S, I, U = Enum.SurfaceType.Studs, Enum.SurfaceType.Inlet, Enum.SurfaceType.Universal
			local P_PLASTIC, P_SMOOTH = Enum.Material.Plastic, Enum.Material.SmoothPlastic

			local function isCharacter(instance)
				local parent = instance.Parent
				if parent and parent.ClassName == "Model" and parent:FindFirstChildOfClass("Humanoid") then
					return true
				end
				local model = instance:FindFirstAncestorOfClass("Model")
				if model and model:FindFirstChildOfClass("Humanoid") then
					return true
				end
				return false
			end

			local function hasStuds(part)
				if part.ClassName == "Terrain" then return false end
				local ts, bs  = part.TopSurface, part.BottomSurface
				local fs, bks = part.FrontSurface, part.BackSurface
				local ls, rs  = part.LeftSurface, part.RightSurface
				return ts == S or ts == I or ts == U
					or bs == S or bs == I or bs == U
					or fs == S or fs == I or fs == U
					or bks == S or bks == I or bks == U
					or ls == S or ls == I or ls == U
					or rs == S or rs == I or rs == U
			end

			local function convertToClassicPart(part)
				part.CastShadow = false
				part.Reflectance = 0
				local appearance = part:FindFirstChildWhichIsA("SurfaceAppearance")
				if appearance then appearance:Destroy() end
				if part.Material == P_PLASTIC and not hasStuds(part) then
					part.Material = P_SMOOTH
				end
			end

			local function convertToGlossyCharacterPart(part)
				part.CastShadow = false
				for _, child in ipairs(part:GetChildren()) do
					if child:IsA("SurfaceAppearance") then child:Destroy() end
				end
				part.Material = P_SMOOTH
				part.Reflectance = 0
			end

			task.spawn(function()
				local count = 0
				for _, descendant in ipairs(Workspace:GetDescendants()) do
					if not rpState.active then break end
					if descendant:IsA("BasePart") then
						if not isCharacter(descendant) then
							pcall(convertToClassicPart, descendant)
						end
						count += 1
						if count % 50 == 0 then task.wait() end
					end
				end
			end)

			table.insert(rpState.connections, Workspace.DescendantAdded:Connect(function(descendant)
				if not rpState.active then return end
				if descendant:IsA("BasePart") and not isCharacter(descendant) then
					pcall(convertToClassicPart, descendant)
				end
			end))

			local function setupCharacter(char)
				for _, descendant in ipairs(char:GetDescendants()) do
					if descendant:IsA("BasePart") then
						pcall(convertToGlossyCharacterPart, descendant)
					end
				end
				table.insert(rpState.connections, char.DescendantAdded:Connect(function(descendant)
					if not rpState.active then return end
					if descendant:IsA("BasePart") then
						pcall(convertToGlossyCharacterPart, descendant)
					end
				end))
			end

			local function setupPlayer(plr)
				if plr.Character then setupCharacter(plr.Character) end
				table.insert(rpState.connections, plr.CharacterAdded:Connect(setupCharacter))
			end

			for _, plr in ipairs(Players:GetPlayers()) do setupPlayer(plr) end
			table.insert(rpState.connections, Players.PlayerAdded:Connect(setupPlayer))
			print("[Remove Pro] Classic lighting + parts applied.")
		end

		function actions.restoreRemovePro()
			if not rpState.active then return end
			rpState.active = false

			for _, conn in ipairs(rpState.connections) do
				pcall(function() conn:Disconnect() end)
			end
			rpState.connections = {}

			if rpState.colorCorrection then
				pcall(function() rpState.colorCorrection:Destroy() end)
				rpState.colorCorrection = nil
			end

			restoreLighting(rpState.savedLighting)
			rpState.savedLighting = nil
			print("[Remove Pro] Lighting restored.")
		end
	end

	------------------------------------------------------------
	-- 3. CLASSIC OUTLINE LOGIC
	------------------------------------------------------------
	do
		local OUTLINE_COLOR       = Color3.fromRGB(50, 50, 50)
		local LINE_THICKNESS      = 0.001
		local TRANSPARENCY        = 0.95
		local JITTER_AMPLITUDE    = 100
		local TRANSPARENCY_CUTOFF = 0
		local ALLOWED_CLASS       = "Part"

		local DISQUALIFYING_CHILDREN = {
			"SpecialMesh", "BlockMesh", "CylinderMesh", "SphereMesh",
			"BevelMesh", "FileMesh", "MeshPart", "Decal", "Texture", "SurfaceAppearance"
		}

		local olState = {
			active = false,
			tracked = {},
			boxes = {},
			connections = {},
			partConnections = {}
		}

		local function isInLocalCharacter(p)
			local char = player and player.Character
			return char and p:IsDescendantOf(char) or false
		end

		local function hasDisqualifyingChild(p)
			for _, className in ipairs(DISQUALIFYING_CHILDREN) do
				if p:FindFirstChildOfClass(className) then return true end
			end
			return false
		end

		local function removePartOutline(p)
			if olState.boxes[p] then
				olState.boxes[p]:Destroy()
				olState.boxes[p] = nil
			end
			olState.tracked[p] = nil
		end

		local function applyPartOutline(p)
			if not olState.active then return end
			if p.ClassName ~= ALLOWED_CLASS then return end
			if p.Shape ~= Enum.PartType.Block then return end
			if hasDisqualifyingChild(p) then return end
			if isInLocalCharacter(p) then return end

			if p.Transparency > TRANSPARENCY_CUTOFF then
				removePartOutline(p)
				return
			end

			if olState.tracked[p] then return end
			olState.tracked[p] = true

			local h, s, v = p.Color:ToHSV()
			local roll = math.random(-JITTER_AMPLITUDE, JITTER_AMPLITUDE) * 0.0002
			p.Color = Color3.fromHSV(h, s, math.clamp(v + roll, 0, 1))

			if p:FindFirstChild("outline") then return end

			local box = Instance.new("SelectionBox")
			box.Name          = "outline"
			box.Adornee       = p
			box.Color3        = OUTLINE_COLOR
			box.LineThickness = LINE_THICKNESS
			box.Transparency  = TRANSPARENCY
			box.Parent        = p

			olState.boxes[p] = box
		end

		local function setupOutlinePart(p)
			if not olState.active then return end
			if p:IsA("BasePart") then
				applyPartOutline(p)
				if not olState.partConnections[p] then
					olState.partConnections[p] = p:GetPropertyChangedSignal("Transparency"):Connect(function()
						applyPartOutline(p)
					end)
				end
			end
		end

		local function cleanupOutlinePart(p)
			removePartOutline(p)
			if olState.partConnections[p] then
				olState.partConnections[p]:Disconnect()
				olState.partConnections[p] = nil
			end
		end

		function actions.applyOutline()
			if olState.active then return end
			olState.active = true

			local Workspace = game:GetService("Workspace")
			for _, v in ipairs(Workspace:GetDescendants()) do
				setupOutlinePart(v)
			end

			table.insert(olState.connections, Workspace.DescendantAdded:Connect(setupOutlinePart))
			table.insert(olState.connections, Workspace.DescendantRemoving:Connect(cleanupOutlinePart))

			local function onCharacter(char)
				task.wait()
				for _, v in ipairs(char:GetDescendants()) do
					cleanupOutlinePart(v)
				end
			end

			if player then
				table.insert(olState.connections, player.CharacterAdded:Connect(onCharacter))
				if player.Character then onCharacter(player.Character) end
			end
			print("[Classic Outline] Applied.")
		end

		function actions.restoreOutline()
			if not olState.active then return end
			olState.active = false

			for _, conn in ipairs(olState.connections) do
				if conn then conn:Disconnect() end
			end
			for _, conn in pairs(olState.partConnections) do
				if conn then conn:Disconnect() end
			end
			for _, box in pairs(olState.boxes) do
				if box and box.Parent then box:Destroy() end
			end

			olState.boxes = {}
			olState.tracked = {}
			olState.connections = {}
			olState.partConnections = {}
			print("[Classic Outline] Cleaned up.")
		end
	end

	------------------------------------------------------------
	-- 4. LENS FLARE LOGIC
	------------------------------------------------------------
	do
		local lfState = {
			active = false,
			node = nil,
			lenses = nil
		}

		local function getLensesDefinition()
			return {
				{ Color = Color3.fromRGB(200, 255, 200), Radius = 1.20, Distance = 0.100 },
				{ Color = Color3.fromRGB(  0, 255,   0), Radius = 0.50, Distance = 0.200 },
				{ Color = Color3.fromRGB(255,   0,   0), Radius = 0.30, Distance = 0.225 },
				{ Color = Color3.fromRGB(255, 170,   0), Radius = 1.50, Distance = 0.250 },
				{ Color = Color3.fromRGB(255, 170,   0), Radius = 3.00, Distance = 0.250 },
				{ Color = Color3.fromRGB(  0, 255,   0), Radius = 0.50, Distance = 0.300 },
				{ Color = Color3.fromRGB(  0, 255,   0), Radius = 0.20, Distance = 0.600 },
				{ Color = Color3.fromRGB(  0, 255,   0), Radius = 0.40, Distance = 0.650 },
				{ Color = Color3.fromRGB(255,   0,   0), Radius = 0.20, Distance = 0.780 },
				{ Color = Color3.fromRGB(  0, 255,   0), Radius = 0.25, Distance = 0.900 },
				{ Color = Color3.fromRGB( 23,  17,   0), Radius = 0.15, Distance = 1.200 },
				{ Color = Color3.fromRGB( 23,  17,   0), Radius = 0.15, Distance = 1.500 },
			}
		end

		local function projectRay(ray, length)
			return Ray.new(ray.Origin, ray.Direction.Unit * length)
		end

		local function asVector2(v3, ...)
			return Vector2.new(v3.X, v3.Y), ...
		end

		function actions.applyLensFlare()
			if lfState.active then return end
			lfState.active = true

			local camera = workspace.CurrentCamera
			if not camera then return end

			pcall(function() RunService:UnbindFromRenderStep("LensFlareUpdate") end)

			local existingNode = camera:FindFirstChild("LensFlareNode")
			if existingNode then existingNode:Destroy() end

			local lensFlareNode = Instance.new("Part")
			lensFlareNode.Name = "LensFlareNode"
			lensFlareNode.Transparency = 1
			lensFlareNode.Anchored = true
			lensFlareNode.CanCollide = false
			lensFlareNode.Locked = true
			lensFlareNode.Parent = camera
			lfState.node = lensFlareNode

			local lenses = getLensesDefinition()
			lfState.lenses = lenses

			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude
			raycastParams.IgnoreWater = true

			local function computeSunOcclusion(sunPos)
				local curCam = workspace.CurrentCamera
				if not curCam then return 0 end
				local cf = curCam.CFrame

				if sunPos:Dot(cf.LookVector) > 0 then
					local sunView = curCam:WorldToViewportPoint(cf.Position + sunPos)
					local visibility = 0
					local total = 0

					local filterList = {curCam}
					if player and player.Character then
						table.insert(filterList, player.Character)
					end
					raycastParams.FilterDescendantsInstances = filterList

					for dx = -1, 1 do
						for dy = -1, 1 do
							local posX = math.floor(sunView.X + dx * 15)
							local posY = math.floor(sunView.Y + dy * 15)

							local sunRay = curCam:ViewportPointToRay(posX, posY)
							local ray = projectRay(sunRay, 5000)

							local result = workspace:Raycast(ray.Origin, ray.Direction, raycastParams)
							if not result then
								visibility = visibility + 1
							end
							total = total + 1
						end
					end

					visibility = visibility / total
					return (1 - visibility), sunView
				end

				return 0
			end

			local function update()
				if not lfState.active then return end
				local curCam = workspace.CurrentCamera
				if not curCam then return end

				local vpSize = curCam.ViewportSize
				local sunDir = Lighting:GetSunDirection()

				local sunWP = sunDir * 10e6
				local sunSP, inView = asVector2(curCam:WorldToViewportPoint(sunWP))
				local occlusion = inView and computeSunOcclusion(sunDir) or 1

				if occlusion < 1 and sunDir.Y > -0.1 then
					local invSunSP = vpSize - sunSP

					for i, lense in ipairs(lenses) do
						local radius = lense.Radius / 12

						if not lense.Beam or not lense.Beam.Parent then
							local a0 = Instance.new("Attachment")
							lense.A0 = a0
							a0.Name = i .. "_A0"
							a0.Parent = lensFlareNode

							local a1 = Instance.new("Attachment")
							lense.A1 = a1
							a1.Name = i .. "_A1"
							a1.Parent = lensFlareNode

							local beam = Instance.new("Beam")
							lense.Beam = beam
							beam.Name = tostring(i)
							beam.Color = ColorSequence.new(lense.Color)
							beam.Width0 = radius
							beam.Width1 = radius
							beam.TextureSpeed = 0
							beam.Transparency = NumberSequence.new(0.9)
							beam.LightEmission = 1
							beam.Texture = "rbxasset://sky/lensflare.jpg"
							beam.Attachment0 = a0
							beam.Attachment1 = a1
							beam.Parent = lensFlareNode
						end

						local lenseSP = invSunSP:Lerp(sunSP, lense.Distance)
						local lenseWP = curCam:ViewportPointToRay(lenseSP.X, lenseSP.Y, 1).Origin
						local lenseCF = CFrame.new(lenseWP, lenseWP - sunDir)

						if lense.A0 and lense.A1 then
							lense.A0.CFrame = lenseCF * CFrame.new(-radius / 2, 0, 0)
							lense.A1.CFrame = lenseCF * CFrame.new( radius / 2, 0, 0)
						end
					end

					lensFlareNode.Parent = curCam
					return
				end

				lensFlareNode.Parent = nil
			end

			RunService:BindToRenderStep("LensFlareUpdate", 1000, update)
			print("[Lens Flare] Enabled.")
		end

		function actions.restoreLensFlare()
			if not lfState.active then return end
			lfState.active = false

			pcall(function() RunService:UnbindFromRenderStep("LensFlareUpdate") end)

			if lfState.node and lfState.node.Parent then
				pcall(function() lfState.node:Destroy() end)
			end
			lfState.node = nil
			lfState.lenses = nil

			local cam = workspace.CurrentCamera
			if cam then
				local leftover = cam:FindFirstChild("LensFlareNode")
				if leftover then pcall(function() leftover:Destroy() end) end
			end
			print("[Lens Flare] Disabled.")
		end
	end

	------------------------------------------------------------
	-- 5. OLD AVATAR (RETRO SUITE 2006) LOGIC
	------------------------------------------------------------
	do
		local retroState = {
			active = false,
			cleanup = {},
			otherTracked = {},
			headModel = nil,
			bodyModel = nil,
			isSnappingColor = {}
		}

		local BODY_ASSET_ID   = "rbxassetid://1112295249"
		local HEAD_ASSET_ID   = "rbxassetid://12723461139"
		local CLASSIC_FACE_ID_2006 = "rbxasset://textures/face.png"

		local PALETTE_2006_IDS = {
			1, 2, 3, 5, 6, 9, 11, 12, 18, 21, 22, 23, 24, 25, 26, 27, 28, 29, 
			36, 37, 38, 45, 47, 104, 106, 107, 119, 125, 194, 199, 200
		}

		local colorCache = {}
		local validBrickColorSet = {}

		for _, id in ipairs(PALETTE_2006_IDS) do
			local bc = BrickColor.new(id)
			validBrickColorSet[bc.Number] = true
			table.insert(colorCache, { BrickColor = bc, R = bc.Color.R, G = bc.Color.G, B = bc.Color.B })
		end

		local function safeGetObjects(id)
			if type(game.GetObjects) ~= "function" then return nil end
			local ok, result = pcall(function() return game:GetObjects(id) end)
			if ok and type(result) == "table" and #result > 0 then return result end
			return nil
		end

		local function getClosest2006Color(c)
			local closest = colorCache[1].BrickColor
			local minDistSq = math.huge
			local tr, tg, tb = c.R, c.G, c.B
			for i = 1, #colorCache do
				local entry = colorCache[i]
				local dr, dg, db = tr - entry.R, tg - entry.G, tb - entry.B
				local distSq = dr * dr + dg * dg + db * db
				if distSq < minDistSq then minDistSq = distSq; closest = entry.BrickColor end
			end
			return closest
		end

		local function setupCustomAudio(character)
			local humanoid = character:WaitForChild("Humanoid", 5)
			local rPart    = character:WaitForChild("HumanoidRootPart", 5)
			if not (humanoid and rPart) then return end

			local defaultSounds = character:FindFirstChild("RbxCharacterSounds")
			if defaultSounds then pcall(function() defaultSounds:Destroy() end) end

			for _, child in ipairs(rPart:GetChildren()) do
				if child:IsA("Sound") then pcall(function() child:Stop() child:Destroy() end) end
			end

			local sounds = {
				FallingDown = Instance.new("Sound"), FreeFall = Instance.new("Sound"),
				GettingUp   = Instance.new("Sound"), Running  = Instance.new("Sound"),
				Jumping     = Instance.new("Sound"),
			}

			sounds.FallingDown.SoundId = "rbxasset://sounds/splat.wav"
			sounds.FreeFall.SoundId    = "rbxassetid://12222200"
			sounds.GettingUp.SoundId   = "rbxasset://sounds/hit.wav"
			sounds.Running.SoundId     = "rbxasset://sounds/bfsl-minifigfoots1.mp3"
			sounds.Running.Looped      = true
			sounds.Jumping.SoundId     = "rbxasset://sounds/button.wav"

			for name, s in pairs(sounds) do
				s.Name = "Custom_" .. name; s.Volume = 1; s.RollOffMaxDistance = 100; s.RollOffMinDistance = 10; s.Parent = rPart
			end

			table.insert(retroState.cleanup, humanoid.FallingDown:Connect(function(a) if a then sounds.FallingDown.TimePosition = 0; sounds.FallingDown:Play() else sounds.FallingDown:Stop() end end))
			table.insert(retroState.cleanup, humanoid.FreeFalling:Connect(function(a) if a then sounds.FreeFall.TimePosition = 0; sounds.FreeFall:Play() else sounds.FreeFall:Stop() end end))
			table.insert(retroState.cleanup, humanoid.Jumping:Connect(function() sounds.Jumping.TimePosition = 0; sounds.Jumping:Play(); task.delay(0.15, function() if sounds.Jumping.IsPlaying then sounds.Jumping:Stop() end end) end))
			table.insert(retroState.cleanup, humanoid.GettingUp:Connect(function() sounds.GettingUp.TimePosition = 0; sounds.GettingUp:Play() end))

			table.insert(retroState.cleanup, RunService.Heartbeat:Connect(function()
				if not character.Parent or humanoid.Health <= 0 then return end
				local vel = (rPart.Velocity * Vector3.new(1,0,1)).Magnitude
				if humanoid:GetState() == Enum.HumanoidStateType.Running and vel > 0.5 then
					if not sounds.Running.IsPlaying then sounds.Running:Play() end
				else
					if sounds.Running.IsPlaying then sounds.Running:Stop() end
				end
			end))
		end

		local function classifyAccessory(item)
			if not (item:IsA("Accessory") or item:IsA("Accoutrement")) then return nil end
			local handle = item:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				if handle:FindFirstChild("HairAttachment") then return "Hair" end
				if handle:FindFirstChild("HatAttachment") then return "Hat" end
			end
			if item.ClassName == "Hat" or item:IsA("Hat") then return "Hat" end
			if string.find(string.lower(item.Name), "hair") then return "Hair" end
			return "Other"
		end

		local function enforceRetroAccessories(character)
			local keptHat, keptHair = false, false
			for _, child in ipairs(character:GetChildren()) do
				if child:IsA("Accessory") or child:IsA("Accoutrement") then
					local kind = classifyAccessory(child)
					if kind == "Hair" and not keptHair then
						keptHair = true
						local h = child:FindFirstChild("Handle")
						if h then for _, hc in ipairs(h:GetChildren()) do if hc:IsA("WrapLayer") then hc:Destroy() end end end
					elseif kind == "Hat" and not keptHat then
						keptHat = true
						local h = child:FindFirstChild("Handle")
						if h then for _, hc in ipairs(h:GetChildren()) do if hc:IsA("WrapLayer") then hc:Destroy() end end end
					else
						pcall(function() child:Destroy() end)
					end
				end
			end
		end

		local function isForbiddenItem(item)
			if not item or not item.Parent then return false end
			if item:IsA("WrapTarget") or item:IsA("WrapLayer") or item:IsA("SurfaceAppearance") or item:IsA("ForceField") then return true end
			if item:IsA("CharacterMesh") and item.Name ~= "RetroSharpMesh" then return true end
			return false
		end

		local function enforceClassicFaceAndHead(character)
			if state.isClassicFaceEnabled then return end
			local head = character:FindFirstChild("Head")
			if not head then return end

			for _, child in ipairs(head:GetChildren()) do
				if child:IsA("FaceControls") or child:IsA("SurfaceAppearance") or child:IsA("WrapTarget") then
					pcall(function() child:Destroy() end)
				end
			end

			for _, item in ipairs(head:GetChildren()) do
				if item:IsA("SpecialMesh") then
					pcall(function() item:Destroy() end)
				end
			end

			local newMesh = Instance.new("SpecialMesh")
			if retroState.headModel then
				local foundMesh = retroState.headModel:FindFirstChildWhichIsA("SpecialMesh", true)
								  or retroState.headModel:FindFirstChildWhichIsA("MeshPart", true)
				if foundMesh and foundMesh:IsA("MeshPart") then
					newMesh.MeshType  = Enum.MeshType.FileMesh
					newMesh.MeshId    = foundMesh.MeshId
					newMesh.TextureId = foundMesh.TextureID
				elseif foundMesh then
					newMesh = foundMesh:Clone()
				end
			else
				newMesh.MeshType = Enum.MeshType.Head
			end
			newMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
			newMesh.Parent = head

			local face = head:FindFirstChild("face")
			if not face then
				face = Instance.new("Decal")
				face.Name = "face"
				face.Face = Enum.NormalId.Front
				face.Parent = head
			end
			if face.Texture ~= CLASSIC_FACE_ID_2006 then
				face.Texture = CLASSIC_FACE_ID_2006
			end

			for _, child in ipairs(head:GetChildren()) do
				if child:IsA("Decal") and child ~= face then
					pcall(function() child:Destroy() end)
				end
			end
		end

		local function snapColorsNow(character)
			if retroState.isSnappingColor[character] then return end
			retroState.isSnappingColor[character] = true

			local bc = character:FindFirstChildOfClass("BodyColors")
			if not bc then bc = Instance.new("BodyColors"); bc.Parent = character end

			local hBc  = getClosest2006Color(bc.HeadColor3)
			local tBc  = getClosest2006Color(bc.TorsoColor3)
			local laBc = getClosest2006Color(bc.LeftArmColor3)
			local raBc = getClosest2006Color(bc.RightArmColor3)
			local llBc = getClosest2006Color(bc.LeftLegColor3)
			local rlBc = getClosest2006Color(bc.RightLegColor3)

			if bc.HeadColor ~= hBc then bc.HeadColor = hBc end
			if bc.TorsoColor ~= tBc then bc.TorsoColor = tBc end
			if bc.LeftArmColor ~= laBc then bc.LeftArmColor = laBc end
			if bc.RightArmColor ~= raBc then bc.RightArmColor = raBc end
			if bc.LeftLegColor ~= llBc then bc.LeftLegColor = llBc end
			if bc.RightLegColor ~= rlBc then bc.RightLegColor = rlBc end

			local limbColorMap = {
				["Head"] = hBc, ["ClassicHead"] = hBc, ["Torso"] = tBc, ["UpperTorso"] = tBc, ["LowerTorso"] = tBc,
				["Left Arm"] = laBc, ["LeftUpperArm"] = laBc, ["LeftLowerArm"] = laBc, ["LeftHand"] = laBc,
				["Right Arm"] = raBc, ["RightUpperArm"] = raBc, ["RightLowerArm"] = raBc, ["RightHand"] = raBc,
				["Left Leg"] = llBc, ["LeftUpperLeg"] = llBc, ["LeftLowerLeg"] = llBc, ["LeftFoot"] = llBc,
				["Right Leg"] = rlBc, ["RightUpperLeg"] = rlBc, ["RightLowerLeg"] = rlBc, ["RightFoot"] = rlBc,
			}

			for _, part in ipairs(character:GetChildren()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.Material = Enum.Material.SmoothPlastic
					local assigned = limbColorMap[part.Name]
					if assigned then
						if part.BrickColor ~= assigned then part.BrickColor = assigned end
					else
						if not validBrickColorSet[part.BrickColor.Number] then part.BrickColor = getClosest2006Color(part.Color) end
					end
				end
			end
			retroState.isSnappingColor[character] = nil
		end

		local function applyFullRetroAvatar(character)
			if not character or not character.Parent then return end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid then return end

			for _, child in ipairs(character:GetChildren()) do
				if isForbiddenItem(child) then pcall(function() child:Destroy() end) end
			end
			for _, part in ipairs(character:GetChildren()) do
				if part:IsA("BasePart") then
					for _, child in ipairs(part:GetChildren()) do
						if isForbiddenItem(child) then pcall(function() child:Destroy() end) end
					end
				end
			end

			enforceRetroAccessories(character)

			if humanoid.RigType == Enum.HumanoidRigType.R6 and retroState.bodyModel then
				for _, desc in ipairs(retroState.bodyModel:GetDescendants()) do
					if desc:IsA("CharacterMesh") then
						local exists = false
						for _, existing in ipairs(character:GetChildren()) do
							if existing:IsA("CharacterMesh") and existing.MeshId == desc.MeshId then exists = true; break end
						end
						if not exists then
							local clone = desc:Clone(); clone.Name = "RetroSharpMesh"; clone.Parent = character
						end
					end
				end
			end

			enforceClassicFaceAndHead(character)
			snapColorsNow(character)
		end

		local function runLocalCharacter(char)
			local humanoid = char:WaitForChild("Humanoid", 10)
			local torso = char:WaitForChild("Torso", 10)
			if not humanoid or not torso then return end

			local defaultAnimate = char:FindFirstChild("Animate")
			if defaultAnimate then defaultAnimate.Disabled = true end

			for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
				track:Stop()
			end

			local RightShoulder = torso:WaitForChild("Right Shoulder", 10)
			local LeftShoulder = torso:WaitForChild("Left Shoulder", 10)
			local RightHip = torso:WaitForChild("Right Hip", 10)
			local LeftHip = torso:WaitForChild("Left Hip", 10)
			if not (RightShoulder and LeftShoulder and RightHip and LeftHip) then return end

			local pose = "Standing"
			local toolAnim = "None"
			local toolAnimTime = 0
			local jumpMaxLimbVelocity = 0.75

			local function moveJump()
				RightShoulder.MaxVelocity = jumpMaxLimbVelocity
				LeftShoulder.MaxVelocity = jumpMaxLimbVelocity
				RightShoulder:SetDesiredAngle(3.14)
				LeftShoulder:SetDesiredAngle(-3.14)
				RightHip:SetDesiredAngle(0)
				LeftHip:SetDesiredAngle(0)
			end

			local function moveFreeFall()
				RightShoulder.MaxVelocity = jumpMaxLimbVelocity
				LeftShoulder.MaxVelocity = jumpMaxLimbVelocity
				RightShoulder:SetDesiredAngle(3.14)
				LeftShoulder:SetDesiredAngle(-3.14)
				RightHip:SetDesiredAngle(0)
				LeftHip:SetDesiredAngle(0)
			end

			local function moveSit()
				RightShoulder.MaxVelocity = 0.15
				LeftShoulder.MaxVelocity = 0.15
				RightShoulder:SetDesiredAngle(1.57)
				LeftShoulder:SetDesiredAngle(-1.57)
				RightHip:SetDesiredAngle(1.57)
				LeftHip:SetDesiredAngle(-1.57)
			end

			local function getTool()
				for _, kid in ipairs(char:GetChildren()) do
					if kid:IsA("Tool") then return kid end
				end
				return nil
			end

			local function getToolAnim(tool)
				for _, c in ipairs(tool:GetChildren()) do
					if c.Name == "toolanim" and c:IsA("StringValue") then return c end
				end
				return nil
			end

			local function animateTool()
				if (toolAnim == "None") then RightShoulder:SetDesiredAngle(1.57) return end
				if (toolAnim == "Slash") then RightShoulder.MaxVelocity = 0.5; RightShoulder:SetDesiredAngle(0) return end
				if (toolAnim == "Lunge") then
					RightShoulder.MaxVelocity = 0.5; LeftShoulder.MaxVelocity = 0.5; RightHip.MaxVelocity = 0.5; LeftHip.MaxVelocity = 0.5
					RightShoulder:SetDesiredAngle(1.57); LeftShoulder:SetDesiredAngle(1.0); RightHip:SetDesiredAngle(1.57); LeftHip:SetDesiredAngle(1.0)
					return
				end
			end

			local function move(time)
				if (pose == "Jumping") then moveJump() return end
				if (pose == "FreeFall") then moveFreeFall() return end
				if (pose == "Seated") then moveSit() return end

				local amplitude = 0.1
				local frequency = 1
				local climbFudge = 0

				if (pose == "Running") then
					if (RightShoulder.CurrentAngle > 1.5 or RightShoulder.CurrentAngle < -1.5) then
						RightShoulder.MaxVelocity = jumpMaxLimbVelocity
					else  
						RightShoulder.MaxVelocity = 0.15
					end
					if (LeftShoulder.CurrentAngle > 1.5 or LeftShoulder.CurrentAngle < -1.5) then
						LeftShoulder.MaxVelocity = jumpMaxLimbVelocity
					else  
						LeftShoulder.MaxVelocity = 0.15
					end
					amplitude = 1
					frequency = 9
				elseif (pose == "Climbing") then
					RightShoulder.MaxVelocity = 0.5; LeftShoulder.MaxVelocity = 0.5
					amplitude = 1; frequency = 9; climbFudge = 3.14
				end

				local desiredAngle = amplitude * math.sin(time * frequency)
				RightShoulder:SetDesiredAngle(desiredAngle + climbFudge)
				LeftShoulder:SetDesiredAngle(desiredAngle - climbFudge)
				RightHip:SetDesiredAngle(-desiredAngle)
				LeftHip:SetDesiredAngle(-desiredAngle)

				local tool = getTool()
				if tool then
					local animObj = getToolAnim(tool)
					if animObj then
						toolAnim = animObj.Value
						animObj:Destroy()
						toolAnimTime = time + .3
					end
					if time > toolAnimTime then toolAnimTime = 0; toolAnim = "None" end
					animateTool()
				else
					toolAnim = "None"
					toolAnimTime = 0
				end
			end

			local conns = {}
			table.insert(conns, humanoid.Running:Connect(function(speed) pose = (speed > 0) and "Running" or "Standing" end))
			table.insert(conns, humanoid.Died:Connect(function() pose = "Dead" end))
			table.insert(conns, humanoid.Jumping:Connect(function() pose = "Jumping" end))
			table.insert(conns, humanoid.Climbing:Connect(function() pose = "Climbing" end))
			table.insert(conns, humanoid.GettingUp:Connect(function() pose = "GettingUp" end))
			table.insert(conns, humanoid.FreeFalling:Connect(function() pose = "FreeFall" end))
			table.insert(conns, humanoid.FallingDown:Connect(function() pose = "FallingDown" end))
			table.insert(conns, humanoid.Seated:Connect(function() pose = "Seated" end))
			table.insert(conns, humanoid.PlatformStanding:Connect(function() pose = "PlatformStanding" end))
			table.insert(conns, humanoid.Swimming:Connect(function(speed) pose = (speed > 0) and "Running" or "Standing" end))

			table.insert(conns, RunService.RenderStepped:Connect(function()
				if char and char.Parent and humanoid.Health > 0 then
					move(os.clock())
				end
			end))

			table.insert(conns, char.AncestryChanged:Connect(function(_, p)
				if not p then
					for _, c in ipairs(conns) do c:Disconnect() end
				end
			end))

			for _, c in ipairs(conns) do table.insert(retroState.cleanup, c) end
		end

		local function setupOther(char)
			if not char then return end
			local hum = char:WaitForChild("Humanoid", 10)
			local torso = char:WaitForChild("Torso", 10)
			if not hum or not torso then return end

			local anim = char:FindFirstChild("Animate")
			if anim then anim.Disabled = true end

			for _, t in ipairs(hum:GetPlayingAnimationTracks()) do t:Stop(0) end

			local rS = torso:WaitForChild("Right Shoulder", 10)
			local lS = torso:WaitForChild("Left Shoulder", 10)
			local rH = torso:WaitForChild("Right Hip", 10)
			local lH = torso:WaitForChild("Left Hip", 10)
			if not (rS and lS and rH and lH) then return end

			local entry = {
				char = char, hum = hum,
				rS = rS, lS = lS, rH = rH, lH = lH,
				pose = "Standing", conns = {}
			}

			table.insert(entry.conns, hum.AnimationPlayed:Connect(function(t) t:Stop(0) end))
			table.insert(entry.conns, hum.Running:Connect(function(s) entry.pose = (s > 0) and "Running" or "Standing" end))
			table.insert(entry.conns, hum.Jumping:Connect(function() entry.pose = "Jumping" end))
			table.insert(entry.conns, hum.FreeFalling:Connect(function() entry.pose = "FreeFall" end))
			table.insert(entry.conns, hum.Seated:Connect(function() entry.pose = "Seated" end))
			table.insert(entry.conns, hum.Climbing:Connect(function() entry.pose = "Climbing" end))

			table.insert(entry.conns, char.AncestryChanged:Connect(function(_, p)
				if not p then
					for _, c in ipairs(entry.conns) do c:Disconnect() end
					retroState.otherTracked[char] = nil
				end
			end))

			retroState.otherTracked[char] = entry
		end

		local function handlePlayer(targetPlayer)
			if not targetPlayer then return end

			local function onCharacter(character)
				task.spawn(function()
					applyFullRetroAvatar(character)
					if targetPlayer == player then
						runLocalCharacter(character)
					else
						setupOther(character)
					end
					setupCustomAudio(character)
				end)

				local bc = character:WaitForChild("BodyColors", 3)
				if bc then table.insert(retroState.cleanup, bc.Changed:Connect(function() snapColorsNow(character) end)) end

				for _, part in ipairs(character:GetChildren()) do
					if part:IsA("BasePart") then
						table.insert(retroState.cleanup, part:GetPropertyChangedSignal("Color"):Connect(function() snapColorsNow(character) end))
					end
				end

				table.insert(retroState.cleanup, character.ChildAdded:Connect(function(child)
					if isForbiddenItem(child) or child:IsA("Accessory") or child:IsA("Accoutrement") then
						task.defer(function() if character.Parent then pcall(applyFullRetroAvatar, character) end end)
					end
				end))

				table.insert(retroState.cleanup, character.DescendantAdded:Connect(function(desc)
					if desc:IsA("FaceControls") or desc:IsA("WrapTarget") then
						task.defer(function() if character.Parent then pcall(applyFullRetroAvatar, character) end end)
					end
				end))

				local lastEnforce = 0
				local steppedConn
				steppedConn = RunService.Heartbeat:Connect(function()
					if not character or not character.Parent then steppedConn:Disconnect(); return end
					local t = os.clock()
					if t - lastEnforce < 1.0 then return end
					lastEnforce = t
					pcall(applyFullRetroAvatar, character)
				end)
				table.insert(retroState.cleanup, steppedConn)
			end

			if targetPlayer.Character then task.spawn(onCharacter, targetPlayer.Character) end
			table.insert(retroState.cleanup, targetPlayer.CharacterAdded:Connect(onCharacter))
		end

		function actions.applyOldAvatar()
			if retroState.active then return end
			retroState.active = true

			task.spawn(function()
				local hObjs = safeGetObjects(HEAD_ASSET_ID)
				if hObjs then retroState.headModel = hObjs[1] end

				local bObjs = safeGetObjects(BODY_ASSET_ID)
				if bObjs then retroState.bodyModel = bObjs[1] end
			end)

			local othersRender = RunService.RenderStepped:Connect(function()
				local t = os.clock()
				for char, data in pairs(retroState.otherTracked) do
					if char.Parent and data.hum and data.hum.Health > 0 then
						local pose = data.pose
						local rS, lS, rH, lH = data.rS, data.lS, data.rH, data.lH

						if pose == "Jumping" or pose == "FreeFall" then
							rS.MaxVelocity = 0.75; lS.MaxVelocity = 0.75
							rS:SetDesiredAngle(3.14); lS:SetDesiredAngle(-3.14); rH:SetDesiredAngle(0); lH:SetDesiredAngle(0)
						elseif pose == "Seated" then
							rS.MaxVelocity = 0.15; lS.MaxVelocity = 0.15
							rS:SetDesiredAngle(1.57); lS:SetDesiredAngle(-1.57); rH:SetDesiredAngle(1.57); lH:SetDesiredAngle(-1.57)
						else
							local amp, freq, climb = 0.1, 1, 0
							if pose == "Running" then
								rS.MaxVelocity = 0.15; lS.MaxVelocity = 0.15; amp = 1; freq = 9
							elseif pose == "Climbing" then
								rS.MaxVelocity = 0.5; lS.MaxVelocity = 0.5; amp = 1; freq = 9; climb = 3.14
							end
							local ang = amp * math.sin(t * freq)
							rS:SetDesiredAngle(ang + climb)
							lS:SetDesiredAngle(ang - climb)
							rH:SetDesiredAngle(-ang)
							lH:SetDesiredAngle(-ang)
						end
					else
						for _, c in ipairs(data.conns) do c:Disconnect() end
						retroState.otherTracked[char] = nil
					end
				end
			end)
			table.insert(retroState.cleanup, othersRender)

			for _, plr in ipairs(Players:GetPlayers()) do
				pcall(handlePlayer, plr)
			end
			table.insert(retroState.cleanup, Players.PlayerAdded:Connect(handlePlayer))
			print("[Old Avatar] Retro Suite 2006 applied.")
		end

		function actions.restoreOldAvatar()
			if not retroState.active then return end
			retroState.active = false

			for _, c in ipairs(retroState.cleanup) do
				if typeof(c) == "RBXScriptConnection" then
					pcall(function() c:Disconnect() end)
				elseif type(c) == "function" then
					pcall(c)
				end
			end
			table.clear(retroState.cleanup)

			for _, data in pairs(retroState.otherTracked) do
				for _, c in ipairs(data.conns) do c:Disconnect() end
			end
			table.clear(retroState.otherTracked)
			table.clear(retroState.isSnappingColor)

			for _, plr in ipairs(Players:GetPlayers()) do
				local char = plr.Character
				if char then
					local animate = char:FindFirstChild("Animate")
					if animate then animate.Disabled = false end
				end
			end
			print("[Old Avatar] Disabled.")
		end
	end

	------------------------------------------------------------
	-- 6. CLASSIC FACE LOGIC (LOADSTRING)
	------------------------------------------------------------
	do
		local CLASSIC_FACES_URL = "https://gist.githubusercontent.com/eloredo413-hue/7c035b526111523ac45eab852fc756e7/raw/2d31d61b91835bd59b90b44c24c772571bd6b63e/Classic%2520faces"
		local cfActive = false

		function actions.applyClassicFace()
			if cfActive then return end
			cfActive = true

			local ok, err = pcall(function()
				loadstring(game:HttpGet(CLASSIC_FACES_URL))()
			end)
			if ok then
				print("[Classic Face] Loaded via loadstring.")
			else
				warn("[Classic Face] Loadstring failed: " .. tostring(err))
			end
		end

		function actions.restoreClassicFace()
			if not cfActive then return end
			cfActive = false

			for _, plr in ipairs(Players:GetPlayers()) do
				local char = plr.Character
				if char then
					local fakeHead = char:FindFirstChild("ClassicHead")
					if fakeHead then
						pcall(function() fakeHead:Destroy() end)
					end
					local head = char:FindFirstChild("Head")
					if head and head:IsA("BasePart") then
						head.Transparency = 0
					end
				end
			end
			print("[Classic Face] Disabled.")
		end
	end

	------------------------------------------------------------
	-- 7. COLOR LIMITER LOGIC (2012 / 2006 / 2005 COLORS)
	------------------------------------------------------------
	do
		-- 64 solid colors, row by row from the 2012 8x8 palette grid
		local PALETTE_2012_IDS = {
			119, 24, 106, 21, 104, 23, 107, 37,
			1, 208, 2, 194, 199, 26, 141, 1003,
			1022, 133, 125, 153, 148, 135, 102, 151,
			5, 226, 12, 101, 9, 11, 1018, 29,
			1030, 1009, 1016, 1019, 1015, 1024, 1027, 1028,
			1021, 1004, 1005, 1020, 1032, 1010, 1013, 1006,
			217, 18, 38, 1007, 1026, 45, 1025, 1023,
			192, 1014, 1008, 1031, 1012, 1011, 28, 1029
		}

		-- 31 core 2006 BrickColors
		local PALETTE_2006_IDS = {
			1, 2, 3, 5, 6, 9, 11, 12, 18, 21, 22, 23, 24, 25, 26, 27, 28, 29,
			36, 37, 38, 45, 47, 104, 106, 107, 119, 125, 194, 199, 200
		}

		-- 20 colors from the 2005 Studio toolbar. true = exact 2005 RGB colors,
		-- false = snap to the closest BrickColor equivalents instead.
		local USE_EXACT_2005_RGB = true

		local PALETTE_2005_RGB = {
			Color3.fromRGB(255, 255, 0),   Color3.fromRGB(0, 0, 255),     Color3.fromRGB(238, 236, 218),
			Color3.fromRGB(118, 113, 36),  Color3.fromRGB(0, 168, 0),     Color3.fromRGB(205, 208, 48),
			Color3.fromRGB(0, 240, 202),   Color3.fromRGB(108, 123, 182), Color3.fromRGB(128, 18, 179),
			Color3.fromRGB(220, 68, 68),   Color3.fromRGB(245, 0, 0),     Color3.fromRGB(178, 178, 178),
			Color3.fromRGB(125, 125, 125), Color3.fromRGB(255, 134, 0),   Color3.fromRGB(172, 198, 226),
			Color3.fromRGB(70, 70, 70),    Color3.fromRGB(204, 204, 204), Color3.fromRGB(62, 206, 238),
			Color3.fromRGB(106, 230, 0),   Color3.fromRGB(0, 88, 224),
		}

		local PALETTE_2005_BRICKCOLOR_IDS = {
			24, 23, 1, 108, 28, 119, 107, 102, 104, 101,
			21, 2, 27, 106, 45, 199, 194, 11, 37, 195
		}

		local function colorKey(c)
			return string.format("%d,%d,%d", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
		end

		local function isCharacterPart(part)
			local current = part.Parent
			while current and current ~= workspace do
				if current:IsA("Model") and Players:GetPlayerFromCharacter(current) then
					return true
				end
				current = current.Parent
			end
			return false
		end

		-- Builds an apply/restore pair that keeps every non-character part on the
		-- nearest palette color. It re-checks every frame so BTool/executor color
		-- changes get forced back, and restore puts the original colors back.
		local function makeColorLimiter(tag, palette, useExactRGB)
			local colorCache = {}
			local validSet = {}

			for _, entry in ipairs(palette) do
				if useExactRGB then
					validSet[colorKey(entry)] = true
					table.insert(colorCache, { Color = entry, R = entry.R, G = entry.G, B = entry.B })
				else
					local bc = BrickColor.new(entry)
					validSet[bc.Number] = true
					table.insert(colorCache, { BrickColor = bc, R = bc.Color.R, G = bc.Color.G, B = bc.Color.B })
				end
			end

			local lim = {
				active = false,
				isUpdating = false,
				connections = {},
				original = setmetatable({}, { __mode = "k" }),
			}

			local function isValidColor(part)
				if useExactRGB then
					return validSet[colorKey(part.Color)] == true
				end
				return validSet[part.BrickColor.Number] == true
			end

			local function getClosest(c)
				local closest = colorCache[1]
				local minDistSq = math.huge
				local tr, tg, tb = c.R, c.G, c.B
				for i = 1, #colorCache do
					local entry = colorCache[i]
					local dr, dg, db = tr - entry.R, tg - entry.G, tb - entry.B
					local distSq = dr * dr + dg * dg + db * db
					if distSq < minDistSq then minDistSq = distSq; closest = entry end
				end
				return closest
			end

			local function snapPart(part)
				if lim.isUpdating or not lim.active then return end
				if not part:IsA("BasePart") or isCharacterPart(part) then return end
				if isValidColor(part) then return end

				lim.isUpdating = true
				if lim.original[part] == nil then lim.original[part] = part.Color end
				local match = getClosest(part.Color)
				pcall(function()
					if useExactRGB then
						part.Color = match.Color
					else
						part.BrickColor = match.BrickColor
					end
				end)
				lim.isUpdating = false
			end

			local function apply()
				if lim.active then return end
				lim.active = true

				table.insert(lim.connections, RunService.Stepped:Connect(function()
					if lim.isUpdating then return end
					for _, desc in ipairs(workspace:GetDescendants()) do
						if desc:IsA("BasePart") and not isValidColor(desc) then
							snapPart(desc)
						end
					end
				end))

				table.insert(lim.connections, workspace.DescendantAdded:Connect(function(desc)
					if desc:IsA("BasePart") then snapPart(desc) end
				end))
				print("[" .. tag .. "] Enabled.")
			end

			local function restore()
				if not lim.active then return end
				lim.active = false

				for _, conn in ipairs(lim.connections) do
					pcall(function() conn:Disconnect() end)
				end
				lim.connections = {}

				for part, color in pairs(lim.original) do
					if part.Parent then
						pcall(function() part.Color = color end)
					end
				end
				lim.original = setmetatable({}, { __mode = "k" })
				print("[" .. tag .. "] Disabled, original colors restored.")
			end

			return apply, restore
		end

		actions.apply2012Colors, actions.restore2012Colors =
			makeColorLimiter("2012 Colors", PALETTE_2012_IDS, false)
		actions.apply2006Colors, actions.restore2006Colors =
			makeColorLimiter("2006 Colors", PALETTE_2006_IDS, false)
		actions.apply2005Colors, actions.restore2005Colors =
			makeColorLimiter("2005 Colors", USE_EXACT_2005_RGB and PALETTE_2005_RGB or PALETTE_2005_BRICKCOLOR_IDS, USE_EXACT_2005_RGB)
	end

	------------------------------------------------------------
	-- 8. 2006 AVATAR (RETRO SUITE 2006 EXECUTOR EDITION) LOGIC
	------------------------------------------------------------
	do
		local BODY_ASSET_ID    = "rbxassetid://1112295249"
		local HEAD_ASSET_ID    = "rbxassetid://12723461139"
		local TSHIRT_ASSET_ID  = "rbxassetid://6526314520"
		local RAW_TSHIRT_IMAGE = "rbxassetid://6526314494"
		local CLASSIC_FACE_ID  = "rbxasset://textures/face.png"
		local ENFORCE_INTERVAL = 0.75

		local MOVEMENT_CATALOG_IDS = {
			Idle  = "rbxassetid://107407916979702",
			Walk  = "rbxassetid://103979922296239",
			Run   = "rbxassetid://103979922296239",
			Jump  = "rbxassetid://119095524735341",
			Fall  = "rbxassetid://119095524735341",
			Climb = "rbxassetid://132639392250396",
		}

		local AVATAR_PALETTES = {
			{ Head = Color3.fromRGB(245,205,48),  Torso = Color3.fromRGB(163,162,165), LeftArm = Color3.fromRGB(245,205,48),  RightArm = Color3.fromRGB(245,205,48),  LeftLeg = Color3.fromRGB(164,189,71), RightLeg = Color3.fromRGB(164,189,71) },
			{ Head = Color3.fromRGB(245,205,48),  Torso = Color3.fromRGB(224,152,147), LeftArm = Color3.fromRGB(245,205,48),  RightArm = Color3.fromRGB(245,205,48),  LeftLeg = Color3.fromRGB(224,152,147), RightLeg = Color3.fromRGB(224,152,147) },
			{ Head = Color3.fromRGB(245,205,48),  Torso = Color3.fromRGB(13,105,172),  LeftArm = Color3.fromRGB(245,205,48),  RightArm = Color3.fromRGB(245,205,48),  LeftLeg = Color3.fromRGB(164,189,71), RightLeg = Color3.fromRGB(164,189,71) },
			{ Head = Color3.fromRGB(245,205,48),  Torso = Color3.fromRGB(217,122,114), LeftArm = Color3.fromRGB(245,205,48),  RightArm = Color3.fromRGB(245,205,48),  LeftLeg = Color3.fromRGB(164,189,71), RightLeg = Color3.fromRGB(164,189,71) },
			{ Head = Color3.fromRGB(245,205,48),  Torso = Color3.fromRGB(116,180,222), LeftArm = Color3.fromRGB(245,205,48),  RightArm = Color3.fromRGB(245,205,48),  LeftLeg = Color3.fromRGB(164,189,71), RightLeg = Color3.fromRGB(164,189,71) },
			{ Head = Color3.fromRGB(218,133,65),  Torso = Color3.fromRGB(163,162,165), LeftArm = Color3.fromRGB(218,133,65),  RightArm = Color3.fromRGB(218,133,65),  LeftLeg = Color3.fromRGB(164,189,71), RightLeg = Color3.fromRGB(164,189,71) },
			{ Head = Color3.fromRGB(204,142,105), Torso = Color3.fromRGB(164,189,71),  LeftArm = Color3.fromRGB(204,142,105), RightArm = Color3.fromRGB(204,142,105), LeftLeg = Color3.fromRGB(164,189,71), RightLeg = Color3.fromRGB(164,189,71) },
		}

		local rng = Random.new()

		local avState = {
			active = false,
			cleanup = {},
			players = {},
			palettes = {},
			assetsLoaded = false,
			assetsLoading = false,
			headModel = nil,
			bodyModel = nil,
			tshirtGraphic = RAW_TSHIRT_IMAGE,
			movementIds = {},
		}

		local function now()
			return (tick and tick()) or os.clock()
		end

		local function safeGetObjects(id)
			local ok, result = pcall(function() return game:GetObjects(id) end)
			if ok and type(result) == "table" and #result > 0 then return result end
			return nil
		end

		local function getPaletteForPlayer(plr)
			if not avState.palettes[plr] then
				avState.palettes[plr] = AVATAR_PALETTES[rng:NextInteger(1, #AVATAR_PALETTES)]
			end
			return avState.palettes[plr]
		end

		-- Assets only need loading once; later toggles reuse them.
		local function loadAssets()
			if avState.assetsLoaded or avState.assetsLoading then return end
			avState.assetsLoading = true

			local hObjs = safeGetObjects(HEAD_ASSET_ID)
			if hObjs then avState.headModel = hObjs[1] end

			local bObjs = safeGetObjects(BODY_ASSET_ID)
			if bObjs then avState.bodyModel = bObjs[1] end

			local tObjs = safeGetObjects(TSHIRT_ASSET_ID)
			local template = tObjs and tObjs[1]
			if template then
				if template:IsA("ShirtGraphic") and template.Graphic ~= "" then
					avState.tshirtGraphic = template.Graphic
				else
					local g = template:FindFirstChildWhichIsA("ShirtGraphic", true)
					if g and g.Graphic ~= "" then avState.tshirtGraphic = g.Graphic end
				end
			end

			for name, catalogId in pairs(MOVEMENT_CATALOG_IDS) do
				avState.movementIds[name] = catalogId
				local objs = safeGetObjects(catalogId)
				if objs then
					for _, obj in ipairs(objs) do
						if obj:IsA("Animation") then
							avState.movementIds[name] = obj.AnimationId
						else
							local anim = obj:FindFirstChildWhichIsA("Animation", true)
							if anim then avState.movementIds[name] = anim.AnimationId end
						end
					end
				end
			end

			avState.assetsLoaded = true
			avState.assetsLoading = false
			print("[2006 Avatar] Assets loaded.")
		end

		local function setupCustomAudio(character, isCurrent)
			local humanoid = character:WaitForChild("Humanoid", 8)
			local rPart    = character:WaitForChild("HumanoidRootPart", 8)
			if not (humanoid and rPart) or not isCurrent() then return end

			local defaultSounds = character:FindFirstChild("RbxCharacterSounds")
			if defaultSounds then pcall(function() defaultSounds:Destroy() end) end

			for _, child in ipairs(rPart:GetChildren()) do
				if child:IsA("Sound") then pcall(function() child:Stop() child:Destroy() end) end
			end

			local sounds = {
				FallingDown = Instance.new("Sound"), FreeFall = Instance.new("Sound"),
				GettingUp   = Instance.new("Sound"), Running  = Instance.new("Sound"),
				Jumping     = Instance.new("Sound"),
			}

			sounds.FallingDown.SoundId = "rbxasset://sounds/splat.wav"
			sounds.FreeFall.SoundId    = "rbxassetid://12222200"
			sounds.GettingUp.SoundId   = "rbxasset://sounds/hit.wav"
			sounds.Running.SoundId     = "rbxasset://sounds/bfsl-minifigfoots1.mp3"
			sounds.Running.Looped      = true
			sounds.Jumping.SoundId     = "rbxasset://sounds/button.wav"

			for name, s in pairs(sounds) do
				s.Name = "Custom_" .. name; s.Volume = 1; s.RollOffMaxDistance = 100; s.RollOffMinDistance = 10; s.Parent = rPart
			end

			local conns = {}
			table.insert(conns, humanoid.FallingDown:Connect(function(a)
				if not sounds.FallingDown.Parent then return end
				if a then sounds.FallingDown.TimePosition = 0; sounds.FallingDown:Play() else sounds.FallingDown:Stop() end
			end))
			table.insert(conns, humanoid.FreeFalling:Connect(function(a)
				if not sounds.FreeFall.Parent then return end
				if a then sounds.FreeFall.TimePosition = 0; sounds.FreeFall:Play() else sounds.FreeFall:Stop() end
			end))
			table.insert(conns, humanoid.Jumping:Connect(function()
				if not sounds.Jumping.Parent then return end
				sounds.Jumping.TimePosition = 0
				sounds.Jumping:Play()
				task.delay(0.1 + rng:NextNumber() / 10, function()
					if sounds.Jumping.Parent and sounds.Jumping.IsPlaying then sounds.Jumping:Stop() end
				end)
			end))
			table.insert(conns, humanoid.GettingUp:Connect(function()
				if not sounds.GettingUp.Parent then return end
				sounds.GettingUp.TimePosition = 0
				sounds.GettingUp:Play()
			end))

			local hb
			hb = RunService.Heartbeat:Connect(function()
				if not character.Parent or not humanoid.Parent or humanoid.Health <= 0 or not rPart.Parent then
					hb:Disconnect(); return
				end
				local vel = (rPart.Velocity * Vector3.new(1,0,1)).Magnitude
				if humanoid:GetState() == Enum.HumanoidStateType.Running and vel > 0.5 then
					if not sounds.Running.IsPlaying then sounds.Running:Play() end
				else
					if sounds.Running.IsPlaying then sounds.Running:Stop() end
				end
			end)
			table.insert(conns, hb)

			return conns
		end

		local function isForbiddenItem(item)
			if not item or not item.Parent then return false end
			if item:IsA("Accessory") or item:IsA("Accoutrement")
				or item:IsA("Shirt") or item:IsA("Pants")
				or item:IsA("ForceField") or item:IsA("WrapTarget")
				or item:IsA("WrapLayer") or item:IsA("Clothing")
				or item:IsA("SurfaceAppearance") or item:IsA("ShirtGraphic") then
				return true
			end
			if item:IsA("CharacterMesh") and item.Name ~= "RetroSharpMesh" then return true end
			if item:IsA("BlockMesh") then return true end
			return false
		end

		local function enforceClassicFace(character)
			local head = character:FindFirstChild("Head")
			if not head then return end

			for _, child in ipairs(head:GetChildren()) do
				if child:IsA("FaceControls") or child:IsA("SurfaceAppearance") or child:IsA("WrapTarget") then
					pcall(function() child:Destroy() end)
				end
			end

			local face = head:FindFirstChild("face")
			if not face then
				face = Instance.new("Decal")
				face.Name = "face"
				face.Face = Enum.NormalId.Front
				face.Parent = head
			end
			if face.Texture ~= CLASSIC_FACE_ID then face.Texture = CLASSIC_FACE_ID end
			face.Transparency = 0

			for _, child in ipairs(head:GetChildren()) do
				if child:IsA("Decal") and child ~= face then
					pcall(function() child:Destroy() end)
				end
			end
		end

		local function purgeUnwantedItems(character)
			if not character or not character.Parent then return end

			for _, child in ipairs(character:GetChildren()) do
				if isForbiddenItem(child) then pcall(function() child:Destroy() end) end
			end
			for _, part in ipairs(character:GetChildren()) do
				if part:IsA("BasePart") then
					for _, child in ipairs(part:GetChildren()) do
						if isForbiddenItem(child) then pcall(function() child:Destroy() end) end
					end
				end
			end

			enforceClassicFace(character)
		end

		local function applyFullRetroAvatar(character, palette)
			if not character or not character.Parent or not palette then return end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid then return end

			purgeUnwantedItems(character)

			if humanoid.RigType == Enum.HumanoidRigType.R6 and avState.bodyModel then
				for _, desc in ipairs(avState.bodyModel:GetDescendants()) do
					if desc:IsA("CharacterMesh") then
						local exists = false
						for _, existing in ipairs(character:GetChildren()) do
							if existing:IsA("CharacterMesh") and existing.MeshId == desc.MeshId then exists = true; break end
						end
						if not exists then
							local clone = desc:Clone(); clone.Name = "RetroSharpMesh"; clone.Parent = character
						end
					end
				end
			end

			local head = character:FindFirstChild("Head")
			if head then
				for _, item in ipairs(head:GetChildren()) do
					if item:IsA("SpecialMesh") or item:IsA("FaceControls")
						or item:IsA("WrapTarget") or item:IsA("SurfaceAppearance") then
						pcall(function() item:Destroy() end)
					end
				end

				local newMesh = Instance.new("SpecialMesh")
				if avState.headModel then
					local foundMesh = avState.headModel:FindFirstChildWhichIsA("SpecialMesh", true)
									  or avState.headModel:FindFirstChildWhichIsA("MeshPart", true)
					if foundMesh and foundMesh:IsA("MeshPart") then
						newMesh.MeshType  = Enum.MeshType.FileMesh
						newMesh.MeshId    = foundMesh.MeshId
						newMesh.TextureId = foundMesh.TextureID
					elseif foundMesh then
						newMesh = foundMesh:Clone()
					end
				else
					newMesh.MeshType = Enum.MeshType.Head
				end
				newMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
				newMesh.Parent = head
			end

			enforceClassicFace(character)

			local bc = character:FindFirstChildOfClass("BodyColors")
			if not bc then bc = Instance.new("BodyColors"); bc.Parent = character end
			bc.HeadColor3     = palette.Head
			bc.TorsoColor3    = palette.Torso
			bc.LeftArmColor3  = palette.LeftArm
			bc.RightArmColor3 = palette.RightArm
			bc.LeftLegColor3  = palette.LeftLeg
			bc.RightLegColor3 = palette.RightLeg

			local limbColors = {
				["Head"] = palette.Head, ["Torso"] = palette.Torso,
				["Left Arm"] = palette.LeftArm, ["Right Arm"] = palette.RightArm,
				["Left Leg"] = palette.LeftLeg, ["Right Leg"] = palette.RightLeg,
			}

			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Material = Enum.Material.SmoothPlastic
					if limbColors[part.Name] then part.Color = limbColors[part.Name] end
				end
			end

			-- Classic 2006 T-shirt badge: an upright SurfaceGui flush to the left chest,
			-- since Decals get rotated 90 degrees by the RetroSharpMesh UVs.
			local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
			if torso then
				for _, child in ipairs(torso:GetChildren()) do
					if child:IsA("Decal") or (child:IsA("SurfaceGui") and child.Name ~= "Retro2006LogoGui") then
						pcall(function() child:Destroy() end)
					end
				end

				local logoGui = torso:FindFirstChild("Retro2006LogoGui")
				if not logoGui then
					logoGui = Instance.new("SurfaceGui")
					logoGui.Name = "Retro2006LogoGui"
					logoGui.Face = Enum.NormalId.Front
					logoGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
					logoGui.PixelsPerStud = 100
					logoGui.LightInfluence = 1
					logoGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

					local img = Instance.new("ImageLabel")
					img.Name = "Badge"
					img.BackgroundTransparency = 1
					img.Size = UDim2.new(1, 0, 1, 0)
					img.Position = UDim2.new(-0.015, 0, 0.045, 0)
					img.ScaleType = Enum.ScaleType.Stretch
					img.Image = avState.tshirtGraphic
					img.Parent = logoGui

					logoGui.Parent = torso
				else
					logoGui.MaxDistance = 0
					local img = logoGui:FindFirstChild("Badge")
					if img then
						img.Size = UDim2.new(1, 0, 1, 0)
						img.Position = UDim2.new(-0.015, 0, 0.045, 0)
						if img.Image ~= avState.tshirtGraphic then img.Image = avState.tshirtGraphic end
					end
				end
			end
		end

		local function injectClassicAnimations(character, charConns, isCurrent)
			local humanoid = character:WaitForChild("Humanoid", 8)
			if not humanoid then return end

			local animator = humanoid:WaitForChild("Animator", 5)
			if not isCurrent() then return end
			if not animator then
				animator = Instance.new("Animator")
				animator.Parent = humanoid
			end

			local animateScript = character:FindFirstChild("Animate")
			if animateScript and animateScript:IsA("LocalScript") then animateScript.Disabled = true end

			table.insert(charConns, character.ChildAdded:Connect(function(child)
				if child.Name == "Animate" and child:IsA("LocalScript") then
					task.defer(function() child.Disabled = true end)
				end
			end))

			local currentTrack, currentAnimId

			local function playRetroAnim(animId, priority)
				if not animId or not character.Parent or humanoid.Health <= 0 then return end
				if currentAnimId == animId and currentTrack and currentTrack.IsPlaying then return end

				if currentTrack then
					pcall(function() currentTrack:Stop(0); currentTrack:Destroy() end)
					currentTrack = nil
				end

				currentAnimId = animId
				local animObj = Instance.new("Animation")
				animObj.AnimationId = animId
				local ok, track = pcall(function() return animator:LoadAnimation(animObj) end)
				if ok and track then
					currentTrack = track
					currentTrack.Priority = priority or Enum.AnimationPriority.Action
					pcall(function() currentTrack:Play(0) end)
				end
			end

			local function stopDefaultTracks()
				pcall(function()
					for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
						if t ~= currentTrack then t:Stop(0) end
					end
				end)
			end

			stopDefaultTracks()

			local ids = avState.movementIds
			table.insert(charConns, animator.AnimationPlayed:Connect(function(track)
				if track ~= currentTrack then pcall(function() track:Stop(0) end) end
			end))
			table.insert(charConns, humanoid.Running:Connect(function(speed)
				stopDefaultTracks()
				playRetroAnim(speed > 0.5 and ids.Walk or ids.Idle)
			end))
			table.insert(charConns, humanoid.Jumping:Connect(function()
				stopDefaultTracks()
				playRetroAnim(ids.Jump)
			end))
			table.insert(charConns, humanoid.FreeFalling:Connect(function()
				stopDefaultTracks()
				playRetroAnim(ids.Fall)
			end))
			table.insert(charConns, humanoid.Climbing:Connect(function(speed)
				stopDefaultTracks()
				playRetroAnim(ids.Climb)
				if currentTrack then pcall(function() currentTrack:AdjustSpeed(speed / 10) end) end
			end))

			playRetroAnim(ids.Idle)
		end

		local function setupPlayer(targetPlayer)
			if not avState.active or not targetPlayer or not targetPlayer.Parent then return end
			if avState.players[targetPlayer] then return end

			local entry = { charConns = {} }
			function entry.cleanup()
				for _, c in ipairs(entry.charConns) do
					pcall(function() c:Disconnect() end)
				end
				entry.charConns = {}
			end
			avState.players[targetPlayer] = entry

			local function onCharacter(character)
				if not character or not avState.active then return end
				entry.cleanup()

				local charConns = entry.charConns
				local palette = getPaletteForPlayer(targetPlayer)

				-- Work that waits must not hook a character after a disable or respawn.
				local function isCurrent()
					return avState.active and avState.players[targetPlayer] == entry and entry.charConns == charConns
				end

				task.spawn(function()
					local timeout = now() + 5
					while not avState.assetsLoaded and now() < timeout do
						task.wait(0.05)
					end
					character:WaitForChild("Head", 5)
					character:WaitForChild("Humanoid", 5)
					if not isCurrent() then return end

					pcall(applyFullRetroAvatar, character, palette)
					pcall(injectClassicAnimations, character, charConns, isCurrent)
				end)

				task.spawn(function()
					local ok, conns = pcall(setupCustomAudio, character, isCurrent)
					if ok and conns then
						for _, c in ipairs(conns) do table.insert(charConns, c) end
					end
				end)

				table.insert(charConns, character.ChildAdded:Connect(function(child)
					if isForbiddenItem(child) or child:IsA("Decal") then
						task.defer(function()
							if character.Parent and isCurrent() then pcall(purgeUnwantedItems, character) end
						end)
					end
				end))

				table.insert(charConns, character.DescendantAdded:Connect(function(desc)
					if isForbiddenItem(desc)
						or (desc:IsA("Decal") and desc.Parent and desc.Parent.Name == "Head" and desc.Texture ~= CLASSIC_FACE_ID) then
						task.defer(function()
							if character.Parent and isCurrent() then pcall(purgeUnwantedItems, character) end
						end)
					end
				end))

				local lastEnforce = 0
				table.insert(charConns, RunService.Heartbeat:Connect(function()
					if not character.Parent then return end
					local t = now()
					if t - lastEnforce < ENFORCE_INTERVAL then return end
					lastEnforce = t
					pcall(applyFullRetroAvatar, character, palette)
				end))
			end

			if targetPlayer.Character then onCharacter(targetPlayer.Character) end
			table.insert(avState.cleanup, targetPlayer.CharacterAdded:Connect(onCharacter))
			table.insert(avState.cleanup, targetPlayer.CharacterRemoving:Connect(entry.cleanup))
		end

		function actions.apply2006Avatar()
			if avState.active then return end
			avState.active = true

			task.spawn(loadAssets)

			for _, plr in ipairs(Players:GetPlayers()) do
				pcall(setupPlayer, plr)
			end
			table.insert(avState.cleanup, Players.PlayerAdded:Connect(function(plr) pcall(setupPlayer, plr) end))
			table.insert(avState.cleanup, Players.PlayerRemoving:Connect(function(plr)
				avState.palettes[plr] = nil
				local entry = avState.players[plr]
				if entry then entry.cleanup(); avState.players[plr] = nil end
			end))
			print("[2006 Avatar] Retro Suite 2006 applied.")
		end

		function actions.restore2006Avatar()
			if not avState.active then return end
			avState.active = false

			for _, c in ipairs(avState.cleanup) do
				pcall(function() c:Disconnect() end)
			end
			table.clear(avState.cleanup)

			for _, entry in pairs(avState.players) do entry.cleanup() end
			table.clear(avState.players)
			table.clear(avState.palettes)

			for _, plr in ipairs(Players:GetPlayers()) do
				local char = plr.Character
				if char then
					local humanoid = char:FindFirstChildOfClass("Humanoid")
					local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
					if animator then
						pcall(function()
							for _, t in ipairs(animator:GetPlayingAnimationTracks()) do t:Stop(0) end
						end)
					end

					local animate = char:FindFirstChild("Animate")
					if animate then animate.Disabled = false end

					local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
					local logo = torso and torso:FindFirstChild("Retro2006LogoGui")
					if logo then pcall(function() logo:Destroy() end) end

					local rPart = char:FindFirstChild("HumanoidRootPart")
					if rPart then
						for _, s in ipairs(rPart:GetChildren()) do
							if s:IsA("Sound") and string.sub(s.Name, 1, 7) == "Custom_" then
								pcall(function() s:Stop(); s:Destroy() end)
							end
						end
					end
				end
			end
			print("[2006 Avatar] Disabled. Respawn to get removed accessories and clothing back.")
		end
	end

	------------------------------------------------------------
	-- 9. OLD DECAL RENDERING LOGIC (v8)
	-- Classic 2006-2011 decal, face and T-shirt rendering:
	-- black 4-way outlines, pixelated filtering and flat PBR maps.
	------------------------------------------------------------
	do
		local genv = (getgenv and getgenv()) or _G

		local Config = {
			-- "All": head decals, 2006 T-shirt GUIs and non-stud workspace decals
			-- "CharactersOnly": only character head decals and torso T-shirts
			TargetScope = "All",
			-- Never touch studs, inlets, welds or tiling surface textures
			IgnoreStudsAndSurfaceTextures = true,
			-- Classic head & 3D decal outlines
			EnableThickOutlines = true,
			OutlineUVThickness = 0.0018,
			AlphaCrushLayers = 2,
			MainDecalTint = Color3.fromRGB(255, 255, 255),
			-- 2006 T-shirt (Retro2006LogoGui -> Badge); LightInfluence 1 so it never glows
			TShirtLightInfluence = 1,
			TShirtOutlinePixelThickness = 1,
			TShirtColorTint = Color3.fromRGB(255, 255, 255),
			TShirtPixelatedFiltering = true,
			-- Nearest-neighbor filtering and runtime PBR maps on 3D decals
			PixelatedFiltering = true,
			AttemptRuntimePBR = true,
			FallbackWhiteAssetId = "rbxassetid://10800735854",
			FallbackNormalAssetId = "rbxassetid://10800735854",
		}

		local ProcessedTag = "__OldRobloxDecalProcessed_v8"
		local GeneratedTag = "__OldRobloxGenerated_v8"

		local STUD_KEYWORDS = {
			"stud", "inlet", "weld", "glue", "universal",
			"surface", "tile", "grid", "plate", "baseplate",
			"ground", "floor", "road", "grass", "sand", "brick", "concrete"
		}

		-- 1x1 PNGs for the PBR roughness (#FFFFFF) and normal (#7F7FFF) maps
		local WHITE_PNG_BYTES =
			"\137\80\78\71\13\10\26\10\0\0\0\13\73\72\68\82\0\0\0\1\0\0\0\1\8\6\0\0\0\31\21\196\137"
			.. "\0\0\0\13\73\68\65\84\120\218\99\248\255\255\255\127\0\9\251\3\253\245\216\241\154"
			.. "\0\0\0\0\73\69\78\68\174\66\96\130"

		local NORMAL_PNG_BYTES =
			"\137\80\78\71\13\10\26\10\0\0\0\13\73\72\68\82\0\0\0\1\0\0\0\1\8\6\0\0\0\31\21\196\137"
			.. "\0\0\0\13\73\68\65\84\120\218\99\168\175\255\255\31\0\6\123\2\253\150\39\3\105"
			.. "\0\0\0\0\73\69\78\68\174\66\96\130"

		local odState = {
			active = false,
			overlay = nil,
			pbrMaps = nil,
		}

		local TrackedDecals = {}
		local TrackedSurfaceGuis = {}
		local TrackedImageLabels = {}
		local CreatedInstances = {}
		local Connections = {}
		local HeadShells = {}
		local TShirtGuiStacks = {}

		-- Executor thread identity is raised for restricted property access
		local function elevateIdentity()
			local setId = setthreadidentity or setidentity or (syn and syn.set_thread_identity)
			if type(setId) == "function" then pcall(setId, 8) end
		end

		local function setRestrictedProperty(instance, prop, value)
			elevateIdentity()
			if type(setscriptable) == "function" then pcall(setscriptable, instance, prop, true) end
			local ok = pcall(function() instance[prop] = value end)
			if ok then return true end
			if type(sethiddenproperty) == "function" then
				local hiddenOk = pcall(sethiddenproperty, instance, prop, value)
				if hiddenOk then return true end
			end
			return false
		end

		local function getRestrictedProperty(instance, prop)
			elevateIdentity()
			if type(setscriptable) == "function" then pcall(setscriptable, instance, prop, true) end
			local ok, val = pcall(function() return instance[prop] end)
			if ok and val ~= nil then return val end
			if type(gethiddenproperty) == "function" then
				local hiddenOk, hiddenVal = pcall(gethiddenproperty, instance, prop)
				if hiddenOk then return hiddenVal end
			end
			return nil
		end

		local function buildPBRMaps()
			local maps = {
				WhiteUri = Config.FallbackWhiteAssetId,
				NormalUri = Config.FallbackNormalAssetId,
				WhiteContent = nil,
				NormalContent = nil,
			}

			local customAssetFunc = getcustomasset or getsynasset
			if type(writefile) == "function" and type(customAssetFunc) == "function" then
				pcall(function()
					local whiteFile = "old_roblox_decal_white_1x1.png"
					local normalFile = "old_roblox_decal_normal_1x1.png"
					writefile(whiteFile, WHITE_PNG_BYTES)
					writefile(normalFile, NORMAL_PNG_BYTES)
					maps.WhiteUri = customAssetFunc(whiteFile)
					maps.NormalUri = customAssetFunc(normalFile)
				end)
			end

			if type(Content) == "table" and type(Content.fromUri) == "function" then
				pcall(function()
					maps.WhiteContent = Content.fromUri(maps.WhiteUri)
					maps.NormalContent = Content.fromUri(maps.NormalUri)
				end)
			end

			return maps
		end

		local function markGenerated(inst)
			pcall(function() inst:SetAttribute(GeneratedTag, true) end)
			table.insert(CreatedInstances, inst)
		end

		local function isGenerated(inst)
			local ok, val = pcall(function() return inst:GetAttribute(GeneratedTag) == true end)
			return ok and val
		end

		local function getDecalTextureUri(decal)
			local tex = decal.Texture
			if type(tex) == "string" and tex ~= "" then return tex end
			local colorMap = getRestrictedProperty(decal, "ColorMap")
			if type(colorMap) == "string" and colorMap ~= "" then return colorMap end
			local texContent = getRestrictedProperty(decal, "TextureContent")
			if texContent and typeof(texContent) == "Content" and texContent.Uri and texContent.Uri ~= "" then
				return texContent.Uri
			end
			local colorMapContent = getRestrictedProperty(decal, "ColorMapContent")
			if colorMapContent and typeof(colorMapContent) == "Content" and colorMapContent.Uri and colorMapContent.Uri ~= "" then
				return colorMapContent.Uri
			end
			return ""
		end

		-- Detects studs, inlets, welds and tiling surface textures so floors and
		-- building bricks are never outlined with black borders.
		local function isStudOrSurfaceDecal(decal)
			if not Config.IgnoreStudsAndSurfaceTextures then return false end

			-- Every Texture tiles across a surface, so it's never a single decal
			if decal:IsA("Texture") then return true end
			if not decal:IsA("Decal") then return false end

			-- Never ignore character head decals
			local parentPart = decal.Parent
			if parentPart and parentPart:IsA("BasePart") and parentPart.Name == "Head" then return false end

			local name = string.lower(decal.Name)
			for _, kw in ipairs(STUD_KEYWORDS) do
				if string.find(name, kw, 1, true) then return true end
			end

			local texUri = string.lower(getDecalTextureUri(decal))
			if string.find(texUri, "textures/", 1, true) and not string.find(texUri, "face", 1, true) then return true end
			for _, kw in ipairs(STUD_KEYWORDS) do
				if string.find(texUri, kw, 1, true) then return true end
			end

			if parentPart and parentPart:IsA("BasePart") then
				local pName = string.lower(parentPart.Name)
				for _, kw in ipairs(STUD_KEYWORDS) do
					if string.find(pName, kw, 1, true) then return true end
				end

				local model = parentPart.Parent
				if model and model:IsA("Model") then
					local mName = string.lower(model.Name)
					if string.find(mName, "stud", 1, true)
						or string.find(mName, "floor", 1, true)
						or string.find(mName, "baseplate", 1, true) then
						return true
					end
				end

				-- The same texture on 2+ faces of one part means it's a surface texture
				local targetUri = getDecalTextureUri(decal)
				if targetUri ~= "" then
					local sameTexCount = 0
					for _, sibling in ipairs(parentPart:GetChildren()) do
						if sibling:IsA("Decal") and not isGenerated(sibling) and getDecalTextureUri(sibling) == targetUri then
							sameTexCount += 1
						end
					end
					if sameTexCount >= 2 then return true end
				end
			end

			return false
		end

		local function applyPBRPropertiesToDecal(decal, texUri)
			if not Config.AttemptRuntimePBR or texUri == "" then return end
			local maps = odState.pbrMaps
			setRestrictedProperty(decal, "ColorMap", texUri)
			if type(Content) == "table" and type(Content.fromUri) == "function" then
				pcall(function()
					local c = Content.fromUri(texUri)
					setRestrictedProperty(decal, "ColorMapContent", c)
					setRestrictedProperty(decal, "TextureContent", c)
				end)
			end
			setRestrictedProperty(decal, "NormalMap", maps.NormalUri)
			if maps.NormalContent then setRestrictedProperty(decal, "NormalMapContent", maps.NormalContent) end
			setRestrictedProperty(decal, "RoughnessMap", maps.WhiteUri)
			if maps.WhiteContent then setRestrictedProperty(decal, "RoughnessMapContent", maps.WhiteContent) end
		end

		-- Builds the classic layer stack (4 black outlines, alpha crush, main) on a part
		local function createDecalStackOnPart(sourceDecal, targetParent)
			local stack = {}
			local texUri = getDecalTextureUri(sourceDecal)

			local function makeLayer(suffix, uvOffset, zIndex, color, trans)
				local d = Instance.new("Decal")
				markGenerated(d)
				d.Name = sourceDecal.Name .. suffix
				d.Face = sourceDecal.Face
				d.Texture = texUri
				d.Color3 = color
				d.Transparency = trans
				d.ZIndex = zIndex
				pcall(function()
					d.UVOffset = uvOffset
					d.UVScale = sourceDecal.UVScale
					d.Rotation = sourceDecal.Rotation
				end)
				if Config.PixelatedFiltering then
					setRestrictedProperty(d, "ResampleMode", Enum.ResamplerMode.Pixelated)
				end
				applyPBRPropertiesToDecal(d, texUri)
				d.Parent = targetParent
				table.insert(stack, d)
				return d
			end

			local baseZ = math.max(sourceDecal.ZIndex, 2)
			local baseOffset = Vector2.zero
			pcall(function() baseOffset = sourceDecal.UVOffset end)

			if Config.EnableThickOutlines then
				local off = Config.OutlineUVThickness or 0.0018
				local cardinalOffsets = {
					baseOffset + Vector2.new(off, 0),
					baseOffset + Vector2.new(-off, 0),
					baseOffset + Vector2.new(0, off),
					baseOffset + Vector2.new(0, -off),
				}
				for i, uvOff in ipairs(cardinalOffsets) do
					makeLayer("_Outline_" .. i, uvOff, baseZ, Color3.new(0, 0, 0), sourceDecal.Transparency)
				end
				for i = 1, (Config.AlphaCrushLayers or 2) do
					makeLayer("_AlphaCrush_" .. i, baseOffset, baseZ + 1, Color3.new(0, 0, 0), sourceDecal.Transparency)
				end
			end

			local topColor = sourceDecal.Color3
			if Config.MainDecalTint and topColor == Color3.new(1, 1, 1) then topColor = Config.MainDecalTint end
			makeLayer("_ClassicMain", baseOffset, baseZ + 2, topColor, sourceDecal.Transparency)

			return stack
		end

		-- Dynamic faces (FaceControls) and decal-less heads are left untouched
		local function isDynamicOrDecallessHead(head)
			if head:FindFirstChildOfClass("FaceControls") ~= nil then return true, {} end

			local decals = {}
			for _, child in ipairs(head:GetChildren()) do
				if child:IsA("Decal") and not isGenerated(child) and getDecalTextureUri(child) ~= "" then
					table.insert(decals, child)
				end
			end
			if #decals == 0 then return true, {} end
			return false, decals
		end

		-- 2006 T-shirt SurfaceGui (Retro2006LogoGui -> Badge): shaded, pixelated, outlined
		local function setupTorsoTShirtGui(sgui)
			if not odState.active or isGenerated(sgui) then return end
			local parentPart = sgui.Parent
			if not parentPart or not parentPart:IsA("BasePart") then return end

			if not TrackedSurfaceGuis[sgui] then
				TrackedSurfaceGuis[sgui] = {
					LightInfluence = sgui.LightInfluence,
					Brightness = sgui.Brightness,
					ZIndexBehavior = sgui.ZIndexBehavior,
				}
			end

			pcall(function()
				sgui.LightInfluence = Config.TShirtLightInfluence or 1
				sgui.Brightness = 1.0
				sgui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			end)

			for _, child in ipairs(sgui:GetChildren()) do
				if child:IsA("ImageLabel") and not isGenerated(child) then
					if not TrackedImageLabels[child] then
						TrackedImageLabels[child] = {
							ImageColor3 = child.ImageColor3,
							ZIndex = child.ZIndex,
							ResampleMode = getRestrictedProperty(child, "ResampleMode"),
						}
					end

					child.ZIndex = math.max(child.ZIndex, 5)
					child.ImageColor3 = Config.TShirtColorTint or Color3.fromRGB(255, 255, 255)
					if Config.TShirtPixelatedFiltering then
						pcall(function() child.ResampleMode = Enum.ResamplerMode.Pixelated end)
					end

					if not TShirtGuiStacks[child] then
						local outlineEntries = {}
						if Config.EnableThickOutlines then
							local px = Config.TShirtOutlinePixelThickness or 1
							local pixelOffsets = {
								UDim2.fromOffset(px, 0), UDim2.fromOffset(-px, 0),
								UDim2.fromOffset(0, px), UDim2.fromOffset(0, -px),
							}
							for i, off in ipairs(pixelOffsets) do
								local outImg = Instance.new("ImageLabel")
								markGenerated(outImg)
								outImg.Name = child.Name .. "_ClassicBorder_" .. i
								outImg.BackgroundTransparency = 1
								outImg.Size = child.Size
								outImg.Position = child.Position + off
								outImg.ScaleType = child.ScaleType
								outImg.Image = child.Image
								outImg.ImageColor3 = Color3.new(0, 0, 0)
								outImg.ImageTransparency = child.ImageTransparency
								outImg.Rotation = child.Rotation
								outImg.ZIndex = child.ZIndex - 1
								if Config.TShirtPixelatedFiltering then
									pcall(function() outImg.ResampleMode = Enum.ResamplerMode.Pixelated end)
								end
								outImg.Parent = sgui
								table.insert(outlineEntries, { Label = outImg, Offset = off })
							end
						end
						TShirtGuiStacks[child] = { Gui = sgui, OutlineLabels = outlineEntries }
					end
				end
			end
		end

		-- Head decal layers go on a transparent shell part kept in the camera, so
		-- character scripts (like 2006 avatar) never find and purge them.
		local function setupCharacterHead(character, head)
			if not odState.active then return end
			local skipHead, headDecals = isDynamicOrDecallessHead(head)

			local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
			if torso then
				for _, child in ipairs(torso:GetChildren()) do
					if child:IsA("SurfaceGui") then setupTorsoTShirtGui(child) end
				end
			end

			if skipHead then
				if HeadShells[head] then
					if HeadShells[head].ShellPart then
						pcall(function() HeadShells[head].ShellPart:Destroy() end)
					end
					HeadShells[head] = nil
				end
				return
			end

			local shellData = HeadShells[head]
			if not shellData or not shellData.ShellPart or not shellData.ShellPart.Parent then
				local shellPart = Instance.new("Part")
				markGenerated(shellPart)
				shellPart.Name = "ClassicHeadShell_" .. character.Name
				shellPart.Size = head.Size
				shellPart.CFrame = head.CFrame
				shellPart.Transparency = 1
				shellPart.CanCollide = false
				shellPart.CanQuery = false
				shellPart.CanTouch = false
				shellPart.Massless = true
				shellPart.CastShadow = false
				shellPart.Anchored = false

				local shellMesh = Instance.new("SpecialMesh")
				markGenerated(shellMesh)
				shellMesh.Name = "Mesh"
				shellMesh.MeshType = Enum.MeshType.Head
				shellMesh.Scale = Vector3.new(1.251, 1.251, 1.251)
				shellMesh.Parent = shellPart

				local weld = Instance.new("WeldConstraint")
				markGenerated(weld)
				weld.Part0 = head
				weld.Part1 = shellPart
				weld.Parent = shellPart

				shellPart.Parent = odState.overlay

				shellData = { ShellPart = shellPart, ShellMesh = shellMesh, Weld = weld, DecalStacks = {} }
				HeadShells[head] = shellData
			end

			for _, decal in ipairs(headDecals) do
				local texUri = getDecalTextureUri(decal)
				if not TrackedDecals[decal] then
					TrackedDecals[decal] = {
						Color3 = decal.Color3,
						Transparency = decal.Transparency,
						ZIndex = decal.ZIndex,
						LocalTransparencyModifier = getRestrictedProperty(decal, "LocalTransparencyModifier") or 0,
						ResampleMode = getRestrictedProperty(decal, "ResampleMode"),
					}
				end
				if Config.PixelatedFiltering then
					setRestrictedProperty(decal, "ResampleMode", Enum.ResamplerMode.Pixelated)
				end
				applyPBRPropertiesToDecal(decal, texUri)
				if not shellData.DecalStacks[decal] then
					shellData.DecalStacks[decal] = createDecalStackOnPart(decal, shellData.ShellPart)
				end
			end
		end

		-- Every frame: keep head shells matched to their heads and T-shirt outlines matched to their badges
		local function syncOverlays()
			if not odState.active then return end
			local overlay = odState.overlay
			if overlay.Parent ~= (workspace.CurrentCamera or workspace) then
				overlay.Parent = workspace.CurrentCamera or workspace
			end

			for head, shellData in pairs(HeadShells) do
				if not head or not head.Parent or not shellData.ShellPart or not shellData.ShellPart.Parent then
					if shellData.ShellPart then pcall(function() shellData.ShellPart:Destroy() end) end
					HeadShells[head] = nil
					continue
				end

				if head:FindFirstChildOfClass("FaceControls") ~= nil then
					pcall(function() shellData.ShellPart:Destroy() end)
					HeadShells[head] = nil
					continue
				end

				local shellPart = shellData.ShellPart
				local shellMesh = shellData.ShellMesh

				if shellPart.Size ~= head.Size then shellPart.Size = head.Size end
				if not shellData.Weld or not shellData.Weld.Parent or shellData.Weld.Part0 ~= head then
					shellPart.CFrame = head.CFrame
				end

				local srcMesh = head:FindFirstChildOfClass("SpecialMesh")
				if srcMesh then
					if shellMesh.MeshType ~= srcMesh.MeshType then shellMesh.MeshType = srcMesh.MeshType end
					if shellMesh.MeshId ~= srcMesh.MeshId then shellMesh.MeshId = srcMesh.MeshId end
					local targetScale = srcMesh.Scale * 1.001
					if shellMesh.Scale ~= targetScale then shellMesh.Scale = targetScale end
					if shellMesh.Offset ~= srcMesh.Offset then shellMesh.Offset = srcMesh.Offset end
				elseif head:IsA("MeshPart") then
					if shellMesh.MeshType ~= Enum.MeshType.FileMesh then shellMesh.MeshType = Enum.MeshType.FileMesh end
					if shellMesh.MeshId ~= head.MeshId then shellMesh.MeshId = head.MeshId end
					shellMesh.Scale = Vector3.new(1.001, 1.001, 1.001)
				end

				for _, child in ipairs(head:GetChildren()) do
					if child:IsA("Decal") and not isGenerated(child) and not shellData.DecalStacks[child]
						and getDecalTextureUri(child) ~= "" then
						shellData.DecalStacks[child] = createDecalStackOnPart(child, shellPart)
					end
				end

				for srcDecal, stack in pairs(shellData.DecalStacks) do
					if not srcDecal or srcDecal.Parent ~= head then
						for _, layer in ipairs(stack) do
							if layer and layer.Parent then layer:Destroy() end
						end
						shellData.DecalStacks[srcDecal] = nil
					else
						local texUri = getDecalTextureUri(srcDecal)
						local visTrans = 1
						if head.LocalTransparencyModifier <= 0.9 then
							visTrans = math.max(srcDecal.Transparency, head.Transparency)
						end
						for _, layer in ipairs(stack) do
							if layer and layer.Parent then
								if layer.Texture ~= texUri then layer.Texture = texUri end
								if layer.Face ~= srcDecal.Face then layer.Face = srcDecal.Face end
								if layer.Transparency ~= visTrans then layer.Transparency = visTrans end
							end
						end
					end
				end
			end

			for badgeLabel, stackInfo in pairs(TShirtGuiStacks) do
				local sgui = stackInfo.Gui
				if not badgeLabel or not badgeLabel.Parent or not sgui or not sgui.Parent then
					TShirtGuiStacks[badgeLabel] = nil
					continue
				end

				if sgui.LightInfluence ~= 1 then sgui.LightInfluence = 1 end
				if sgui.Brightness ~= 1.0 then sgui.Brightness = 1.0 end

				local targetTint = Config.TShirtColorTint or Color3.fromRGB(255, 255, 255)
				if badgeLabel.ImageColor3 ~= targetTint then badgeLabel.ImageColor3 = targetTint end
				if Config.TShirtPixelatedFiltering and badgeLabel.ResampleMode ~= Enum.ResamplerMode.Pixelated then
					pcall(function() badgeLabel.ResampleMode = Enum.ResamplerMode.Pixelated end)
				end

				for _, entry in ipairs(stackInfo.OutlineLabels) do
					local lbl = entry.Label
					if lbl and lbl.Parent then
						local targetPos = badgeLabel.Position + entry.Offset
						if lbl.Position ~= targetPos then lbl.Position = targetPos end
						if lbl.Size ~= badgeLabel.Size then lbl.Size = badgeLabel.Size end
						if lbl.Image ~= badgeLabel.Image then lbl.Image = badgeLabel.Image end
						if lbl.ImageTransparency ~= badgeLabel.ImageTransparency then lbl.ImageTransparency = badgeLabel.ImageTransparency end
						if lbl.ScaleType ~= badgeLabel.ScaleType then lbl.ScaleType = badgeLabel.ScaleType end
					end
				end
			end
		end

		local function isInsideCharacter(instance)
			local current = instance.Parent
			while current and current ~= workspace do
				if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then return true end
				current = current.Parent
			end
			return false
		end

		-- Non-head workspace decals (studs and surface textures are always skipped)
		local function processGeneralDecal(inst)
			if not odState.active then return false end
			if not inst:IsA("Decal") or isGenerated(inst) or TrackedDecals[inst] then return false end
			if isStudOrSurfaceDecal(inst) then return false end

			local okAttr, alreadyDone = pcall(function() return inst:GetAttribute(ProcessedTag) == true end)
			if okAttr and alreadyDone then return false end

			local parentPart = inst.Parent
			if not parentPart or not parentPart:IsA("BasePart") or isGenerated(parentPart) then return false end

			if parentPart.Name == "Head" and parentPart.Parent and parentPart.Parent:FindFirstChildOfClass("Humanoid") then
				setupCharacterHead(parentPart.Parent, parentPart)
				return true
			end

			if Config.TargetScope == "CharactersOnly" and not isInsideCharacter(inst) then return false end

			local texUri = getDecalTextureUri(inst)
			if texUri == "" or inst.Transparency >= 0.99 then return false end

			pcall(function() inst:SetAttribute(ProcessedTag, true) end)

			TrackedDecals[inst] = {
				Color3 = inst.Color3,
				Transparency = inst.Transparency,
				ZIndex = inst.ZIndex,
				LocalTransparencyModifier = getRestrictedProperty(inst, "LocalTransparencyModifier") or 0,
				ResampleMode = getRestrictedProperty(inst, "ResampleMode"),
			}

			if Config.PixelatedFiltering then
				setRestrictedProperty(inst, "ResampleMode", Enum.ResamplerMode.Pixelated)
			end
			applyPBRPropertiesToDecal(inst, texUri)
			createDecalStackOnPart(inst, parentPart)
			return true
		end

		local function onCharacterAdded(character)
			task.spawn(function()
				local head = character:WaitForChild("Head", 5)
				if head and head:IsA("BasePart") then setupCharacterHead(character, head) end
				local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
				if torso then
					for _, child in ipairs(torso:GetChildren()) do
						if child:IsA("SurfaceGui") then setupTorsoTShirtGui(child) end
					end
				end
			end)
		end

		local function isTShirtGui(sgui)
			local part = sgui.Parent
			return sgui.Name == "Retro2006LogoGui" or sgui.Name == "ClassicTShirtGui"
				or (part ~= nil and (part.Name == "Torso" or part.Name == "UpperTorso"))
		end

		local function onDescendantAdded(desc)
			if desc:IsA("Decal") then
				if not isStudOrSurfaceDecal(desc) then
					task.defer(function() pcall(processGeneralDecal, desc) end)
				end
			elseif desc:IsA("BasePart") and desc.Name == "Head" then
				task.defer(function()
					local model = desc.Parent
					if model and model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
						pcall(setupCharacterHead, model, desc)
					end
				end)
			elseif desc:IsA("SurfaceGui") then
				task.defer(function()
					if isTShirtGui(desc) then pcall(setupTorsoTShirtGui, desc) end
				end)
			elseif desc:IsA("ImageLabel") then
				task.defer(function()
					local sgui = desc.Parent
					if sgui and sgui:IsA("SurfaceGui") and not isGenerated(desc) and isTShirtGui(sgui) then
						pcall(setupTorsoTShirtGui, sgui)
					end
				end)
			end
		end

		function actions.applyOldDecal()
			if odState.active then return end
			odState.active = true

			-- The standalone gist exposes this; clear it so the layers don't stack twice
			if type(genv.DisableOldDecalRenderer) == "function" then
				pcall(genv.DisableOldDecalRenderer)
			end

			elevateIdentity()
			if not odState.pbrMaps then odState.pbrMaps = buildPBRMaps() end

			local overlay = Instance.new("Folder")
			overlay.Name = "__OldRobloxDecalOverlays"
			overlay.Parent = workspace.CurrentCamera or workspace
			odState.overlay = overlay

			table.insert(Connections, RunService.RenderStepped:Connect(syncOverlays))

			for _, plr in ipairs(Players:GetPlayers()) do
				if plr.Character then onCharacterAdded(plr.Character) end
				table.insert(Connections, plr.CharacterAdded:Connect(onCharacterAdded))
			end
			table.insert(Connections, Players.PlayerAdded:Connect(function(plr)
				table.insert(Connections, plr.CharacterAdded:Connect(onCharacterAdded))
			end))

			local convertedCount = 0
			for _, desc in ipairs(workspace:GetDescendants()) do
				if desc:IsA("Model") and desc:FindFirstChildOfClass("Humanoid") then
					local head = desc:FindFirstChild("Head")
					if head and head:IsA("BasePart") then pcall(setupCharacterHead, desc, head) end
				elseif desc:IsA("SurfaceGui") and (desc.Name == "Retro2006LogoGui" or desc.Name == "ClassicTShirtGui") then
					pcall(setupTorsoTShirtGui, desc)
				elseif desc:IsA("Decal") and not isStudOrSurfaceDecal(desc) then
					local ok, applied = pcall(processGeneralDecal, desc)
					if ok and applied then convertedCount += 1 end
				end
			end

			table.insert(Connections, workspace.DescendantAdded:Connect(onDescendantAdded))
			print(string.format("[Old Decal] Enabled. Processed %d decals, head faces & 2006 T-shirts (studs & surface textures protected).", convertedCount))
		end

		function actions.restoreOldDecal()
			if not odState.active then return end
			odState.active = false

			for _, conn in ipairs(Connections) do
				if conn.Connected then conn:Disconnect() end
			end
			table.clear(Connections)

			for _, shellData in pairs(HeadShells) do
				if shellData.ShellPart then pcall(function() shellData.ShellPart:Destroy() end) end
			end
			table.clear(HeadShells)
			table.clear(TShirtGuiStacks)

			if odState.overlay then
				pcall(function() odState.overlay:Destroy() end)
				odState.overlay = nil
			end

			for _, inst in ipairs(CreatedInstances) do
				if inst and inst.Parent then pcall(function() inst:Destroy() end) end
			end
			table.clear(CreatedInstances)

			for sgui, orig in pairs(TrackedSurfaceGuis) do
				if sgui and sgui.Parent then
					pcall(function()
						sgui.LightInfluence = orig.LightInfluence
						sgui.Brightness = orig.Brightness
						sgui.ZIndexBehavior = orig.ZIndexBehavior
					end)
				end
			end
			table.clear(TrackedSurfaceGuis)

			for lbl, orig in pairs(TrackedImageLabels) do
				if lbl and lbl.Parent then
					pcall(function()
						lbl.ImageColor3 = orig.ImageColor3
						lbl.ZIndex = orig.ZIndex
						if orig.ResampleMode ~= nil then lbl.ResampleMode = orig.ResampleMode end
					end)
				end
			end
			table.clear(TrackedImageLabels)

			for decal, orig in pairs(TrackedDecals) do
				if decal and decal.Parent then
					pcall(function()
						decal:SetAttribute(ProcessedTag, nil)
						decal.Color3 = orig.Color3
						decal.Transparency = orig.Transparency
						decal.ZIndex = orig.ZIndex
						setRestrictedProperty(decal, "LocalTransparencyModifier", orig.LocalTransparencyModifier or 0)
						if orig.ResampleMode ~= nil then
							setRestrictedProperty(decal, "ResampleMode", orig.ResampleMode)
						end
					end)
				end
			end
			table.clear(TrackedDecals)
			print("[Old Decal] Disabled, original decals and GUIs restored.")
		end
	end

	------------------------------------------------------------
	-- UI CONSTRUCTION
	------------------------------------------------------------
	local infoPanel = sg:FindFirstChild("SkipInfoPanel", true)

	local function showInfo(txt)
		if not infoPanel then return end
		local infoText = infoPanel:FindFirstChild("InfoText")
		if infoText then
			infoText.Text = txt
			local len = #txt
			if len <= 50 then infoText.TextSize = 18
			elseif len >= 250 then infoText.TextSize = 12
			else infoText.TextSize = math.floor(18 - ((len - 50) / 200) * 6) end
		end
		infoPanel.Visible = true
	end

	local destroyBtn = scroll:FindFirstChild("BPDestroyGuiButton", true)
	if not destroyBtn then
		warn("[Addon] Could not find destroy button.")
		return
	end

	local function pushDown(obj, amount)
		if not obj then return end
		local p = obj.Position
		obj.Position = UDim2.new(p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset + amount)
	end

	-- This addon's rows start where the base GUI's destroy button sits, then the destroy
	-- button and bottom spacer get pushed below everything added here.
	local ROW_HEIGHT   = 30
	local startY       = destroyBtn.Position.Y.Offset
	local decalBtnY    = startY + 7 * ROW_HEIGHT + 10
	local ADDON_HEIGHT = 7 * ROW_HEIGHT + 10 + 36 + 10

	pushDown(destroyBtn, ADDON_HEIGHT)
	local spacer = scroll:FindFirstChild("BPBottomSpacer")
	if spacer then pushDown(spacer, ADDON_HEIGHT) end

	if scroll:IsA("ScrollingFrame") then
		scroll.CanvasSize = UDim2.new(
			scroll.CanvasSize.X.Scale,
			scroll.CanvasSize.X.Offset,
			scroll.CanvasSize.Y.Scale,
			scroll.CanvasSize.Y.Offset + ADDON_HEIGHT
		)
	end

	-- Moves every panel row below yPos when a dropdown opens or closes. It only looks at
	-- positions, so rows from the base script move too.
	local function shiftBelow(yPos, amount)
		for _, child in ipairs(scroll:GetChildren()) do
			if child:IsA("GuiObject") and child.Position.Y.Scale == 0 and child.Position.Y.Offset > yPos then
				pushDown(child, amount)
			end
		end
	end

	-- Label + box + "?" row. Rows inside a dropdown get a small indent and smaller text.
	local function buildRow(parent, containerName, labelText, yPos, boxName, helpName)
		local isOption = parent ~= scroll
		local existing = parent:FindFirstChild(containerName)
		if existing then existing:Destroy() end

		local cont = Instance.new("Frame")
		cont.Name = containerName
		cont.Size = isOption and UDim2.new(1, 0, 0, 30) or UDim2.new(1, -30, 0, 30)
		cont.Position = isOption and UDim2.new(0, 0, 0, yPos) or UDim2.new(0, 15, 0, yPos)
		cont.BackgroundTransparency = 1
		cont.ZIndex = 96
		cont.Parent = parent

		local lbl = Instance.new("TextLabel")
		lbl.Size = isOption and UDim2.new(0, 112, 1, 0) or UDim2.new(0, 130, 1, 0)
		lbl.Position = isOption and UDim2.new(0, 6, 0, 0) or UDim2.new(0, 0, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.FontFace = fontBold
		lbl.TextSize = isOption and 14 or 16
		lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = labelText
		lbl.ZIndex = 97
		lbl.Parent = cont

		local cb = Instance.new("TextButton")
		cb.Name = boxName
		cb.Size = UDim2.new(0, 16, 0, 16)
		cb.Position = UDim2.new(0, 118, 0.5, -8)
		cb.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
		cb.BackgroundTransparency = 0.5
		cb.BorderSizePixel = 0
		cb.Text = ""
		cb.Font = Enum.Font.SourceSansBold
		cb.TextSize = 18
		cb.TextColor3 = Color3.fromRGB(0, 220, 0)
		cb.ZIndex = 97
		cb.Parent = cont

		local st = Instance.new("UIStroke")
		st.Color = Color3.fromRGB(255, 255, 255)
		st.Thickness = 1.2
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = cb

		local help = Instance.new("TextButton")
		help.Name = helpName
		help.Size = UDim2.new(0, 16, 0, 16)
		help.Position = UDim2.new(0, 140, 0.5, -8)
		help.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
		help.BackgroundTransparency = 0.5
		help.BorderSizePixel = 0
		help.Text = "?"
		help.Font = Enum.Font.SourceSansBold
		help.TextSize = 14
		help.TextColor3 = Color3.fromRGB(255, 255, 255)
		help.ZIndex = 97
		help.Parent = cont

		local hst = Instance.new("UIStroke")
		hst.Color = Color3.fromRGB(255, 255, 255)
		hst.Thickness = 1.2
		hst.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		hst.Parent = help

		return cont, cb, help
	end

	local rows = {}

	local function createAddonRow(rowSpec, parent)
		local _, cb, help = buildRow(parent or scroll, rowSpec.containerName, rowSpec.label, rowSpec.yPos, rowSpec.checkboxName, rowSpec.helpName)
		cb.Text = state[rowSpec.stateKey] and "✓" or ""
		rows[rowSpec.stateKey] = { spec = rowSpec, checkbox = cb }

		cb.MouseButton1Click:Connect(function()
			playClick()
			local newState = not state[rowSpec.stateKey]
			state[rowSpec.stateKey] = newState
			cb.Text = newState and "✓" or ""
			if newState then
				-- Options that fight over the same thing switch each other off first.
				local toRestore = {}
				for _, otherKey in ipairs(rowSpec.exclusiveWith or {}) do
					local other = rows[otherKey]
					if state[otherKey] and other then
						state[otherKey] = false
						other.checkbox.Text = ""
						table.insert(toRestore, other.spec.onDisable)
					end
				end
				task.spawn(function()
					for _, onDisable in ipairs(toRestore) do pcall(onDisable) end
					rowSpec.onEnable()
				end)
			else
				task.spawn(rowSpec.onDisable)
			end
			saveConfig()
		end)

		help.MouseButton1Click:Connect(function()
			playClick()
			showInfo(rowSpec.helpText)
		end)
	end

	-- Header row in the same style whose box is an arrow that opens the option rows under it.
	local function createDropdown(dropSpec)
		local cont, arrow, help = buildRow(scroll, dropSpec.containerName, dropSpec.label, dropSpec.yPos, dropSpec.arrowName, dropSpec.helpName)
		arrow.Text = "▼"
		arrow.TextSize = 12
		arrow.TextColor3 = Color3.fromRGB(255, 255, 255)

		local height = #dropSpec.options * ROW_HEIGHT
		local options = Instance.new("Frame")
		options.Name = dropSpec.containerName .. "Options"
		options.Size = UDim2.new(1, 0, 0, height)
		options.Position = UDim2.new(0, 0, 0, 30)
		options.BackgroundTransparency = 1
		options.Visible = false
		options.ZIndex = 96
		options.Parent = cont

		local guide = Instance.new("Frame")
		guide.Name = "Guide"
		guide.Size = UDim2.new(0, 2, 1, -6)
		guide.Position = UDim2.new(0, 0, 0, 3)
		guide.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		guide.BackgroundTransparency = 0.5
		guide.BorderSizePixel = 0
		guide.ZIndex = 97
		guide.Parent = options

		for i, rowSpec in ipairs(dropSpec.options) do
			rowSpec.yPos = (i - 1) * ROW_HEIGHT
			createAddonRow(rowSpec, options)
		end

		local expanded = false
		arrow.MouseButton1Click:Connect(function()
			playClick()
			expanded = not expanded
			-- The header stays 30 tall: its label and boxes are centered in it, so growing
			-- it drags them over the options. The options hang below it instead.
			options.Visible = expanded
			arrow.Text = expanded and "▲" or "▼"
			shiftBelow(cont.Position.Y.Offset, expanded and height or -height)
		end)

		help.MouseButton1Click:Connect(function()
			playClick()
			showInfo(dropSpec.helpText)
		end)
	end

	createAddonRow({
		containerName = "HealthESPContainer",
		checkboxName  = "HealthESPCheckbox",
		helpName      = "HealthESPHelpButton",
		label         = "health ESP",
		yPos          = startY,
		stateKey      = "isHealthESPEnabled",
		onEnable      = actions.applyHealthESP,
		onDisable     = actions.restoreHealthESP,
		helpText      = "Old Roblox Health ESP For Players Used to See Health Range"
	})

	createAddonRow({
		containerName = "RemoveProContainer",
		checkboxName  = "RemoveProCheckbox",
		helpName      = "RemoveProHelpButton",
		label         = "remove pro",
		yPos          = startY + ROW_HEIGHT,
		stateKey      = "isRemoveProEnabled",
		onEnable      = actions.applyRemovePro,
		onDisable     = actions.restoreRemovePro,
		helpText      = "Removes modern post-processing (Atmosphere, Bloom, DepthOfField, etc.) and applies classic 2016-era flat lighting with Retro tonemapper. Parts are converted to SmoothPlastic. Disabling restores lighting; material changes persist."
	})

	createAddonRow({
		containerName = "OutlineContainer",
		checkboxName  = "OutlineCheckbox",
		helpName      = "OutlineHelpButton",
		label         = "outline",
		yPos          = startY + 2 * ROW_HEIGHT,
		stateKey      = "isOutlineEnabled",
		onEnable      = actions.applyOutline,
		onDisable     = actions.restoreOutline,
		helpText      = "Classic 2013-era SelectionBox outlines for plain block Parts with subtle brightness jitter. Automatically adapts to dynamic transparency changes."
	})

	createAddonRow({
		containerName = "LensFlareContainer",
		checkboxName  = "LensFlareCheckbox",
		helpName      = "LensFlareHelpButton",
		label         = "lens flare",
		yPos          = startY + 3 * ROW_HEIGHT,
		stateKey      = "isLensFlareEnabled",
		onEnable      = actions.applyLensFlare,
		onDisable     = actions.restoreLensFlare,
		helpText      = "Renders multi-beam classic sun lens flares aligned dynamically with the sun's trajectory, featuring Raycast-based obstacle occlusion checking."
	})

	createDropdown({
		containerName = "AvatarDropdownContainer",
		arrowName     = "AvatarDropdownArrow",
		helpName      = "AvatarDropdownHelpButton",
		label         = "avatar",
		yPos          = startY + 4 * ROW_HEIGHT,
		helpText      = "Press the arrow to pick an avatar era: old avatar or 2006 avatar. Only one can be on at a time.",
		options = {
			{
				containerName = "OldAvatarContainer",
				checkboxName  = "OldAvatarCheckbox",
				helpName      = "OldAvatarHelpButton",
				label         = "old avatar",
				stateKey      = "isOldAvatarEnabled",
				exclusiveWith = { "is2006AvatarEnabled" },
				onEnable      = actions.applyOldAvatar,
				onDisable     = actions.restoreOldAvatar,
				helpText      = "Retro Suite 2006: 2010 Motor6D procedural animations for all players, 31-color palette quantization, 1-hat/1-hair enforcement, legacy audio, and original mesh/face textures."
			},
			{
				containerName = "Avatar2006Container",
				checkboxName  = "Avatar2006Checkbox",
				helpName      = "Avatar2006HelpButton",
				label         = "2006 avatar",
				stateKey      = "is2006AvatarEnabled",
				exclusiveWith = { "isOldAvatarEnabled" },
				onEnable      = actions.apply2006Avatar,
				onDisable     = actions.restore2006Avatar,
				helpText      = "Retro Suite 2006 Executor Edition: random 2006 body colors, classic head and face, sharp R6 meshes, the 2006 T-shirt badge, retro animations and sounds for all players. Removes accessories and clothing; respawn to get them back after disabling."
			},
		}
	})

	createAddonRow({
		containerName = "ClassicFaceContainer",
		checkboxName  = "ClassicFaceCheckbox",
		helpName      = "ClassicFaceHelpButton",
		label         = "classic face",
		yPos          = startY + 5 * ROW_HEIGHT,
		stateKey      = "isClassicFaceEnabled",
		onEnable      = actions.applyClassicFace,
		onDisable     = actions.restoreClassicFace,
		helpText      = "Loads the external Classic Faces script via loadstring to convert modern R15 dynamic heads into classic R6 block heads with 2D face decals."
	})

	createDropdown({
		containerName = "ColorLimiterDropdownContainer",
		arrowName     = "ColorLimiterDropdownArrow",
		helpName      = "ColorLimiterDropdownHelpButton",
		label         = "color limiter",
		yPos          = startY + 6 * ROW_HEIGHT,
		helpText      = "Press the arrow to pick a color era. Every non-character part gets snapped to that era's palette. Only one can be on at a time.",
		options = {
			{
				containerName = "Colors2012Container",
				checkboxName  = "Colors2012Checkbox",
				helpName      = "Colors2012HelpButton",
				label         = "2012 colors",
				stateKey      = "is2012ColorsEnabled",
				exclusiveWith = { "is2006ColorsEnabled", "is2005ColorsEnabled" },
				onEnable      = actions.apply2012Colors,
				onDisable     = actions.restore2012Colors,
				helpText      = "Snaps every non-character part to the 64-color 2012 BrickColor palette, re-checked every frame. Disabling restores the original colors."
			},
			{
				containerName = "Colors2006Container",
				checkboxName  = "Colors2006Checkbox",
				helpName      = "Colors2006HelpButton",
				label         = "2006 colors",
				stateKey      = "is2006ColorsEnabled",
				exclusiveWith = { "is2012ColorsEnabled", "is2005ColorsEnabled" },
				onEnable      = actions.apply2006Colors,
				onDisable     = actions.restore2006Colors,
				helpText      = "Limits every non-character part to the 31 core 2006 BrickColors, re-checked every frame. Disabling restores the original colors."
			},
			{
				containerName = "Colors2005Container",
				checkboxName  = "Colors2005Checkbox",
				helpName      = "Colors2005HelpButton",
				label         = "2005 colors",
				stateKey      = "is2005ColorsEnabled",
				exclusiveWith = { "is2012ColorsEnabled", "is2006ColorsEnabled" },
				onEnable      = actions.apply2005Colors,
				onDisable     = actions.restore2005Colors,
				helpText      = "Snaps every non-character part to the 20 colors of the 2005 Studio toolbar, re-checked every frame. Disabling restores the original colors."
			},
		}
	})

	------------------------------------------------------------
	-- OLD DECAL RENDERING BUTTON
	------------------------------------------------------------
	local oldDecalBtn = scroll:FindFirstChild("BPOldDecalButton")
	if oldDecalBtn then oldDecalBtn:Destroy() end

	oldDecalBtn = Instance.new("TextButton")
	oldDecalBtn.Name = "BPOldDecalButton"
	oldDecalBtn.Size = UDim2.new(1, -30, 0, 36)
	oldDecalBtn.Position = UDim2.new(0, 15, 0, decalBtnY)
	oldDecalBtn.BorderSizePixel = 0
	oldDecalBtn.FontFace = fontBold
	oldDecalBtn.TextSize = 16
	oldDecalBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	oldDecalBtn.ZIndex = 97
	oldDecalBtn.AutoButtonColor = true
	oldDecalBtn.Parent = scroll

	local oldDecalCorner = Instance.new("UICorner")
	oldDecalCorner.CornerRadius = UDim.new(0, 6)
	oldDecalCorner.Parent = oldDecalBtn

	local oldDecalStroke = Instance.new("UIStroke")
	oldDecalStroke.Thickness = 1.5
	oldDecalStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	oldDecalStroke.Parent = oldDecalBtn

	local function refreshOldDecalBtn()
		local on = state.isOldDecalEnabled
		oldDecalBtn.Text = on and "old decal rendering: ON" or "old decal rendering: OFF"
		oldDecalBtn.BackgroundColor3 = on and Color3.fromRGB(30, 140, 30) or Color3.fromRGB(70, 70, 70)
		oldDecalStroke.Color = on and Color3.fromRGB(80, 220, 80) or Color3.fromRGB(160, 160, 160)
	end
	refreshOldDecalBtn()

	oldDecalBtn.MouseButton1Click:Connect(function()
		playClick()
		state.isOldDecalEnabled = not state.isOldDecalEnabled
		refreshOldDecalBtn()
		task.spawn(state.isOldDecalEnabled and actions.applyOldDecal or actions.restoreOldDecal)
		saveConfig()
	end)

	------------------------------------------------------------
	-- APPLY SAVED STATE ON LOAD
	------------------------------------------------------------
	if state.isHealthESPEnabled then task.spawn(actions.applyHealthESP) end
	if state.isRemoveProEnabled then task.spawn(actions.applyRemovePro) end
	if state.isOutlineEnabled then task.spawn(actions.applyOutline) end
	if state.isLensFlareEnabled then task.spawn(actions.applyLensFlare) end
	if state.isOldAvatarEnabled then task.spawn(actions.applyOldAvatar)
	elseif state.is2006AvatarEnabled then task.spawn(actions.apply2006Avatar) end
	if state.isClassicFaceEnabled then task.spawn(actions.applyClassicFace) end
	if state.is2012ColorsEnabled then task.spawn(actions.apply2012Colors)
	elseif state.is2006ColorsEnabled then task.spawn(actions.apply2006Colors)
	elseif state.is2005ColorsEnabled then task.spawn(actions.apply2005Colors) end
	if state.isOldDecalEnabled then task.spawn(actions.applyOldDecal) end

	print("[Addon] All options loaded into GUI.")
end)