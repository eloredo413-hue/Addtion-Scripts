-- [[ (Addtion-Scripts copy: Remove Pro keeps shadows) HEALTH ESP + REMOVE PRO + CLASSIC OUTLINE + LENS FLARE + AVATAR DROPDOWN (OLD / 2006)
--    + CLASSIC FACE + COLOR LIMITER DROPDOWN (2012 / 2006 / 2005) + HIDE GAME GUI + LEGACY LIGHTING
--    + OLD DECAL RENDERING BUTTON + 2008 NIGHT SKY ]]
-- Execute Hammer stuff 1 first, then this.

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

	-- Hammer stuff 1 builds the scroller and the destroy button; give it a moment
	-- if this was executed right after it.
	local scroll = hammerPanel:FindFirstChild("BPAddonScroller") or hammerPanel:WaitForChild("BPAddonScroller", 10) or hammerPanel

	local config = {}
	if readfile and isfile and isfile(CONFIG_FILE) then
		pcall(function() config = HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
	end
	if type(config) ~= "table" then config = {} end
	config.Choices = config.Choices or {}

	local state = {
		isHealthESPEnabled   = config.isHealthESPEnabled or false,
		isRemoveProEnabled   = config.isRemoveProEnabled or false,
		isRemoveEffectsEnabled = config.isRemoveEffectsEnabled or false,
		is2006LightingEnabled = config.is2006LightingEnabled or false,
		isOutlineEnabled     = config.isOutlineEnabled or false,
		isLensFlareEnabled   = config.isLensFlareEnabled or false,
		isOldAvatarEnabled   = config.isOldAvatarEnabled or false,
		isClassicFaceEnabled = config.isClassicFaceEnabled or false,
		is2006AvatarEnabled  = config.is2006AvatarEnabled or false,
		is2008PlayersEnabled = config.is2008PlayersEnabled or false,
		is2012ColorsEnabled  = config.is2012ColorsEnabled or false,
		is2006ColorsEnabled  = config.is2006ColorsEnabled or false,
		is2005ColorsEnabled  = config.is2005ColorsEnabled or false,
		isOldDecalEnabled    = config.isOldDecalEnabled or false,
		isHideGameGuiEnabled    = config.isHideGameGuiEnabled or false,
		isLegacyLightingEnabled = config.isLegacyLightingEnabled or false,
		isOldCameraSoundEnabled = config.isOldCameraSoundEnabled or false,
		isOldPartSoundsEnabled  = config.isOldPartSoundsEnabled or false,
		isRemoveLeaderboardEnabled = config.isRemoveLeaderboardEnabled or false,
		is2013DynamicEnabled    = config.is2013DynamicEnabled or false,
		is2015AudioEnabled      = config.is2015AudioEnabled or false,
		is2016AudioEnabled      = config.is2016AudioEnabled or false,
		isOldHealthBarEnabled   = config.isOldHealthBarEnabled or false,
		is2008NightSkyEnabled   = config.is2008NightSkyEnabled or false,
		isAllPlayersEnabled     = config.isAllPlayersEnabled or false,
		isFpsCapEnabled         = config.isFpsCapEnabled or false,
		isHideMobileControlsEnabled = config.isHideMobileControlsEnabled or false,
		isMobileControlsEnabled = config.isMobileControlsEnabled or false,
		isOldThumbstickEnabled  = config.isOldThumbstickEnabled or false,
		isIWLegacyLightingEnabled = config.isIWLegacyLightingEnabled or false, -- (the dropdown's "normal")
		isIWLighting2014Enabled = config.isIWLighting2014Enabled or false,
		isIWLighting2015Enabled = config.isIWLighting2015Enabled or false,
		isIWLighting2016Enabled = config.isIWLighting2016Enabled or false,
		isIWLighting2017Enabled = config.isIWLighting2017Enabled or false,
		isIWLighting2019Enabled = config.isIWLighting2019Enabled or false,
		isIWLighting2020Enabled = config.isIWLighting2020Enabled or false,
		isOldMoonEnabled        = config.isOldMoonEnabled or false,
		is2014ShadowsEnabled    = config.is2014ShadowsEnabled or false,
		isSlipperyWalkEnabled   = config.isSlipperyWalkEnabled or false,
		isChatBarEnabled        = config.isChatBarEnabled or false,
		fpsCap                  = math.max(0, math.floor(tonumber(config.fpsCap) or 0)),
	}

	-- Hammer stuff 1 (and the base GUI) save to the same file, so re-read it first and
	-- only write this script's own keys on top. Otherwise each script would write back
	-- its old copy of the other's settings.
	local function saveConfig()
		if readfile and isfile then
			pcall(function()
				if isfile(CONFIG_FILE) then
					local latest = HttpService:JSONDecode(readfile(CONFIG_FILE))
					if type(latest) == "table" then config = latest end
				end
			end)
		end
		config.Choices = config.Choices or {}
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
			updates = {},  -- label -> its update function
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
			local updateCon = nil -- (the entry in hpState.updates for this humanoid's label)
			local currentHealth = nil

			local function onAncestryChanged()
				if updateCon then hpState.updates[updateCon] = nil updateCon = nil end
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

							-- Text only (no bar) when the humanoid only shows a name: MaxHealth 0, health display
							-- switched off, or a model with no body (games use a Head + Humanoid as a label, like
							-- the city names on a map).
							local function barWanted()
								if h.MaxHealth <= 0 then return false end
								local okType, displayType = pcall(function() return h.HealthDisplayType end)
								if okType and displayType == Enum.HumanoidHealthDisplayType.AlwaysOff then return false end
								return char:FindFirstChild("Torso") ~= nil or char:FindFirstChild("UpperTorso") ~= nil
									or char:FindFirstChild("HumanoidRootPart") ~= nil
							end

							-- Three sizes by distance. A size is only changed after the camera has moved a few
							-- studs past where it changes (so it doesn't flip back and forth, and the label doesn't
							-- jump), and nothing is written when nothing changed.
							local SIZES = {
								{ font = 20, width = 60, height = 8 }, -- nearer than 25
								{ font = 15, width = 50, height = 7 }, -- nearer than 50
								{ font = 12, width = 40, height = 6 }, -- farther
							}
							local tier = nil
							local lastRatio, lastBar, lastText, lastColor, lastEnabled = nil, nil, nil, nil, nil
							local gap = 2

							local function tierFor(dist)
								local margin = 3
								if tier == 1 then
									if dist < 25 + margin then return 1 end
								elseif tier == 2 then
									if dist >= 25 - margin and dist < 50 + margin then return 2 end
								elseif tier == 3 then
									if dist >= 50 - margin then return 3 end
								end
								if dist < 25 then return 1 elseif dist < 50 then return 2 end
								return 3
							end

							local function update()
								if not head or not head.Parent then return end
								local camera = workspace.CurrentCamera
								if not camera then return end

								local dist = (camera.CFrame.Position - head.Position).Magnitude
								local newTier = tierFor(dist)
								if newTier ~= tier then
									tier = newTier
									local sz = SIZES[tier]
									pName.TextSize = sz.font
									pName.Size = UDim2.new(1, 0, 0, sz.font)
									pName.Position = UDim2.new(0.5, 0, 0, 0)
									pName.AnchorPoint = Vector2.new(0.5, 0)
									pName.TextXAlignment = Enum.TextXAlignment.Center
									rBar.AnchorPoint = Vector2.new(0.5, 0)
									rBar.Position = UDim2.new(0.5, 0, 0, sz.font + gap)
									rBar.Size = UDim2.new(0, sz.width, 0, sz.height)
									health.Size = UDim2.new(0, 200, 0, sz.font + gap + sz.height + 10)
								end

								local enabled = (dist <= MAX_DISTANCE and head.Transparency < 1)
								if enabled ~= lastEnabled then
									lastEnabled = enabled
									health.Enabled = enabled
								end

								local showBar = barWanted()
								local ratio = (h.MaxHealth > 0) and (h.Health / h.MaxHealth) or 0
								if not isFinite(ratio) then showBar = false end
								if showBar ~= lastBar then
									lastBar = showBar
									rBar.Visible = showBar
								end
								if showBar and ratio ~= lastRatio then
									lastRatio = ratio
									rBar.BackgroundTransparency = (ratio >= 1) and 1 or 0
									gBar.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)
								end

								local color = Color3.new(1, 1, 1)
								if hPlayer and Teams:FindFirstChildOfClass("Team") then
									color = hPlayer.TeamColor.Color
								end
								if color ~= lastColor then
									lastColor = color
									pName.TextColor3 = color
								end

								local text = char.Name
								local overWriter = char:FindFirstChild("NameOverwrite")
								if overWriter and overWriter:IsA("StringValue") then
									text = overWriter.Value
								end
								if text ~= lastText then
									lastText = text
									pName.Text = text
								end
							end

							-- sized and filled in before it is shown, so it never appears at the wrong size first
							update()
							health.Parent = head

							-- one shared loop updates every label (below), not a loop per humanoid: maps can have
							-- hundreds of humanoids (city names, NPCs)
							updateCon = health
							hpState.updates[health] = update
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

			-- All the labels are updated about 12 times a second in one loop (health, size by distance,
			-- name). Labels farther away than they can be seen are only looked at every half second.
			local acc, farAcc = 0, 0
			table.insert(hpState.connections, RunService.Heartbeat:Connect(function(dt)
				acc = acc + dt
				farAcc = farAcc + dt
				if acc < 0.08 then return end
				acc = 0
				local doFar = farAcc >= 0.5
				if doFar then farAcc = 0 end
				for label, update in pairs(hpState.updates) do
					if not label.Parent then
						hpState.updates[label] = nil
					elseif doFar or label.Enabled then
						local ok = pcall(update)
						if not ok then hpState.updates[label] = nil end
					end
				end
			end))

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
			hpState.updates = {}

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
	-- 2A. REMOVE EFFECTS (Addtion-Scripts; it used to be part of Remove Pro)
	-- The game's Atmosphere and its other effects (bloom, blur, colour correction, depth of field, sun rays...) taken
	-- away, in Lighting and on the camera, also ones the game adds later. The effects this repo's own options make
	-- (Remove Pro's colour correction, iw legacy lighting's) are left. Unticking puts the game's back.
	------------------------------------------------------------
	do
		local OUR_EFFECTS = {
			CustomColorCorrection = true, LegacyCorrection = true, LegacyGrading = true, LegacyBloom = true,
		}
		local reState = { active = false, removed = {}, conns = {} }

		local function take(child)
			if not reState.active or reState.removed[child] or OUR_EFFECTS[child.Name] then return end
			if not (child:IsA("PostEffect") or child:IsA("Atmosphere")) then return end
			local parent = child.Parent
			if pcall(function() child.Parent = nil end) then
				reState.removed[child] = parent
			end
		end

		function actions.applyRemoveEffects()
			if reState.active then return end
			reState.active = true
			local holders = { Lighting }
			local camera = workspace.CurrentCamera
			if camera then table.insert(holders, camera) end
			for _, holder in ipairs(holders) do
				for _, child in ipairs(holder:GetChildren()) do pcall(take, child) end
				table.insert(reState.conns, holder.ChildAdded:Connect(function(child)
					-- (a moment later: the game may still be naming it)
					task.defer(function()
						if child.Parent == holder then pcall(take, child) end
					end)
				end))
			end
			print("[Remove Effects] The game's Atmosphere and effects taken away.")
		end

		function actions.restoreRemoveEffects()
			if not reState.active then return end
			reState.active = false
			for _, c in ipairs(reState.conns) do pcall(function() c:Disconnect() end) end
			reState.conns = {}
			for child, parent in pairs(reState.removed) do
				pcall(function()
					if parent then child.Parent = parent end -- (a parent that is gone: left out)
				end)
			end
			reState.removed = {}
			print("[Remove Effects] The game's Atmosphere and effects put back.")
		end
	end

	------------------------------------------------------------
	-- 2B. 2006-07 LIGHTING (Addtion-Scripts)
	-- The game's Atmosphere colour turned all the way up (white: the brightest of its colours), as the 2006-07 sky
	-- looked. A game without an Atmosphere gets none (nothing is added); one the game adds later is turned up too,
	-- and kept so if the game changes it.
	-- With the old Compatibility lighting (Remove Pro, legacy lighting...) Roblox doesn't draw an Atmosphere at all,
	-- so then its white haze is drawn the classic way instead: the fog, white, as far out as the Atmosphere's
	-- density puts it (the Atmosphere is set aside meanwhile, as it would keep the fog from showing). Looked at twice
	-- a second, so it follows Remove Pro being ticked or unticked. Unticking puts everything back.
	------------------------------------------------------------
	do
		local MAX_COLOR = Color3.fromRGB(255, 255, 255)
		local lState = {
			active = false, saved = {}, conns = {},
			fogMode = false, stashed = {}, underFog = nil, ourFog = nil,
		}

		local function brighten(atmosphere)
			if not lState.active or not atmosphere:IsA("Atmosphere") then return end
			if lState.saved[atmosphere] == nil then
				lState.saved[atmosphere] = atmosphere.Color
				table.insert(lState.conns, atmosphere:GetPropertyChangedSignal("Color"):Connect(function()
					if lState.active and atmosphere.Color ~= MAX_COLOR then
						pcall(function() atmosphere.Color = MAX_COLOR end)
					end
				end))
			end
			pcall(function() atmosphere.Color = MAX_COLOR end)
		end

		-- the old Compatibility (or Legacy) lighting: no Atmosphere drawn
		local function oldLighting()
			local tech = nil
			pcall(function() tech = Lighting.Technology end)
			if tech == nil and gethiddenproperty then
				pcall(function() tech = gethiddenproperty(Lighting, "Technology") end)
			end
			return tech == Enum.Technology.Compatibility or tech == Enum.Technology.Legacy
		end

		-- how far out the white fog goes for an Atmosphere (thicker / hazier: nearer)
		local function fogFor(atmosphere)
			local density, haze = 0.395, 0
			pcall(function() density = atmosphere.Density haze = atmosphere.Haze end)
			local fogEnd = math.clamp(500 / math.max(density, 0.05), 250, 10000) / (1 + haze / 2)
			return { start = fogEnd * 0.15, finish = fogEnd }
		end

		local function readFog()
			return { color = Lighting.FogColor, start = Lighting.FogStart, finish = Lighting.FogEnd }
		end
		local function writeFog(fog, color)
			pcall(function()
				Lighting.FogColor = color or fog.color
				Lighting.FogStart = fog.start
				Lighting.FogEnd = fog.finish
			end)
		end

		local function leaveFogMode()
			if not lState.fogMode then return end
			lState.fogMode = false
			if lState.underFog then writeFog(lState.underFog) end
			lState.underFog, lState.ourFog = nil, nil
			for _, atmosphere in ipairs(lState.stashed) do
				pcall(function() atmosphere.Parent = Lighting end)
			end
			lState.stashed = {}
		end

		-- the white Atmosphere the classic way (fog) while the old lighting is on, the real one otherwise
		local function refresh()
			if not lState.active then return end
			if oldLighting() then
				-- the game's Atmospheres (now, and new ones) set aside: the first one tells how far the fog goes
				for _, child in ipairs(Lighting:GetChildren()) do
					if child:IsA("Atmosphere") then
						pcall(brighten, child)
						if not lState.ourFog then lState.ourFog = fogFor(child) end
						table.insert(lState.stashed, child)
						pcall(function() child.Parent = nil end)
					end
				end
				if not lState.ourFog then return end -- (no Atmosphere in this game: nothing to draw)
				if not lState.fogMode then
					lState.fogMode = true
					lState.underFog = readFog()
				end
				local now = readFog()
				local ours = lState.ourFog
				if now.color ~= MAX_COLOR or now.start ~= ours.start or now.finish ~= ours.finish then
					-- (something else set the fog meanwhile, Remove Pro's own for one: that is what comes back after)
					if not (now.color == MAX_COLOR and math.abs(now.finish - ours.finish) < 0.01) then
						lState.underFog = now
					end
					writeFog(ours, MAX_COLOR)
				end
			else
				leaveFogMode()
			end
		end
		-- (Remove Pro asks for this as soon as it is ticked or unticked)
		actions.refresh2006Lighting = function() pcall(refresh) end

		function actions.apply2006Lighting()
			if lState.active then return end
			lState.active = true
			local found = 0
			for _, child in ipairs(Lighting:GetChildren()) do
				if child:IsA("Atmosphere") then
					found = found + 1
					pcall(brighten, child)
				end
			end
			table.insert(lState.conns, Lighting.ChildAdded:Connect(function(child)
				task.defer(function()
					if child.Parent == Lighting then
						pcall(brighten, child)
						pcall(refresh)
					end
				end)
			end))
			pcall(refresh)
			task.spawn(function()
				while lState.active do
					task.wait(0.5)
					pcall(refresh)
				end
			end)
			print("[2006-07 Lighting] " .. (found > 0 and ("The Atmosphere's colour turned all the way up"
				.. (lState.fogMode and " (drawn as white fog: the old lighting doesn't draw Atmospheres)." or "."))
				or "This game has no Atmosphere: nothing to change."))
		end

		function actions.restore2006Lighting()
			if not lState.active then return end
			lState.active = false
			for _, c in ipairs(lState.conns) do pcall(function() c:Disconnect() end) end
			lState.conns = {}
			leaveFogMode()
			for atmosphere, color in pairs(lState.saved) do
				pcall(function() atmosphere.Color = color end)
			end
			lState.saved = {}
			print("[2006-07 Lighting] The Atmosphere's own colour put back.")
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
			-- (the Atmosphere and the other effects are their own option now: "remove effects", below)

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
			-- (Remove Pro no longer switches shadows off: GlobalShadows is left as the game has it)
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
				part.Reflectance = 0
				local appearance = part:FindFirstChildWhichIsA("SurfaceAppearance")
				if appearance then appearance:Destroy() end
				if part.Material == P_PLASTIC and not hasStuds(part) then
					part.Material = P_SMOOTH
				end
			end

			local function convertToGlossyCharacterPart(part)
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
			-- (2006-07 lighting: its white Atmosphere drawn as fog now, the old lighting doesn't draw Atmospheres)
			if actions.refresh2006Lighting then actions.refresh2006Lighting() end
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
			if actions.refresh2006Lighting then actions.refresh2006Lighting() end
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
	-- CLASSIC LIMBS (Addtion-Scripts): the old procedural arm / leg swing on both kinds of body, for the old
	-- avatar and the 2006 avatar.
	--   * R6: the Torso's four joints turned with SetDesiredAngle, as the old Animate script did.
	--   * R15 (no Torso: the old avatar did nothing there): the same four joints (RightShoulder, LeftShoulder,
	--     RightHip, LeftHip) given the same angles through their Transform, set each frame after the
	--     animations (Stepped) and moved no faster than the old motors (MaxVelocity a 60th of a second). The
	--     rest of the body is held straight. Works on other players' characters too (on your screen).
	-- ClassicLimbs.joints(char) -> rS, lS, rH, lH, humanoid, handle (the joints answer SetDesiredAngle,
	-- MaxVelocity and CurrentAngle on both bodies); ClassicLimbs.release(handle) lets them go;
	-- ClassicLimbs.drive(char, conns) animates the character by itself (its pose followed).
	------------------------------------------------------------
	local ClassicLimbs = {}
	do
		local moving = {} -- R15 joints being moved -> true
		local stepConn = nil
		local function step(_, dt)
			dt = math.min(dt or 1 / 60, 0.1)
			for j in pairs(moving) do
				if not j.motor.Parent then
					moving[j] = nil
				else
					local maxStep = j.MaxVelocity * dt * 60
					local diff = j.desired - j.CurrentAngle
					if math.abs(diff) <= maxStep then
						j.CurrentAngle = j.desired
					else
						j.CurrentAngle = j.CurrentAngle + (diff > 0 and maxStep or -maxStep)
					end
					-- (a turn about the joint's X axis: forward for a positive angle, the left side mirrored as on R6)
					pcall(function() j.motor.Transform = CFrame.Angles(j.sign * j.CurrentAngle, 0, 0) end)
				end
			end
			if next(moving) == nil and stepConn then
				stepConn:Disconnect()
				stepConn = nil
			end
		end
		local function virtualJoint(motor, sign)
			local j = { motor = motor, sign = sign, MaxVelocity = 0.1, CurrentAngle = 0, desired = 0 }
			function j:SetDesiredAngle(angle) self.desired = angle end
			moving[j] = true
			if not stepConn then stepConn = RunService.Stepped:Connect(step) end
			return j
		end

		function ClassicLimbs.joints(char, timeout)
			timeout = timeout or 10
			local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", timeout)
			if not hum then return nil end
			if hum.RigType == Enum.HumanoidRigType.R15 then
				local function motor(partName, jointName)
					local part = char:WaitForChild(partName, timeout)
					local m = part and part:WaitForChild(jointName, timeout)
					return (m and m:IsA("Motor6D")) and m or nil
				end
				local rS, lS = motor("RightUpperArm", "RightShoulder"), motor("LeftUpperArm", "LeftShoulder")
				local rH, lH = motor("RightUpperLeg", "RightHip"), motor("LeftUpperLeg", "LeftHip")
				if not (rS and lS and rH and lH) then return nil end
				-- the rest of the body straight (it keeps the last pose of its own animations otherwise)
				for _, m in ipairs(char:GetDescendants()) do
					if m:IsA("Motor6D") and m ~= rS and m ~= lS and m ~= rH and m ~= lH then
						pcall(function() m.Transform = CFrame.new() end)
					end
				end
				local set = { virtualJoint(rS, 1), virtualJoint(lS, -1), virtualJoint(rH, 1), virtualJoint(lH, -1) }
				return set[1], set[2], set[3], set[4], hum, { r15 = set }
			end
			local torso = char:WaitForChild("Torso", timeout)
			if not torso then return nil end
			local rS = torso:WaitForChild("Right Shoulder", timeout)
			local lS = torso:WaitForChild("Left Shoulder", timeout)
			local rH = torso:WaitForChild("Right Hip", timeout)
			local lH = torso:WaitForChild("Left Hip", timeout)
			if not (rS and lS and rH and lH) then return nil end
			return rS, lS, rH, lH, hum, { r6 = { rS, lS, rH, lH } }
		end

		function ClassicLimbs.release(handle)
			if type(handle) ~= "table" then return end
			for _, j in ipairs(handle.r15 or {}) do
				moving[j] = nil
				pcall(function() j.motor.Transform = CFrame.new() end)
			end
			for _, joint in ipairs(handle.r6 or {}) do
				pcall(function() joint.MaxVelocity = 0.5 joint:SetDesiredAngle(0) end)
			end
		end

		-- the classic motion by itself (standing sway, running swing, arms up when jumping / falling, sitting,
		-- climbing); its connections go in conns, a release with them. False when the body has no such joints.
		function ClassicLimbs.drive(char, conns)
			local rS, lS, rH, lH, hum, handle = ClassicLimbs.joints(char)
			if not rS then return false end
			local pose = "Standing"
			table.insert(conns, hum.Running:Connect(function(speed) pose = (speed > 0.1) and "Running" or "Standing" end))
			table.insert(conns, hum.Jumping:Connect(function() pose = "Jumping" end))
			table.insert(conns, hum.FreeFalling:Connect(function()
				-- (Addtion-Scripts) the 2006 physics' landing bounce is not a fall
				local env = (getgenv and getgenv()) or _G
				local bounce = env.BPLandingBounce
				if type(bounce) == "number" and os.clock() - bounce < 0.35 and pose ~= "Jumping" then return end
				pose = "FreeFall"
			end))
			table.insert(conns, hum.Seated:Connect(function() pose = "Seated" end))
			table.insert(conns, hum.Climbing:Connect(function() pose = "Climbing" end))
			table.insert(conns, hum.Swimming:Connect(function(speed) pose = (speed > 0.1) and "Running" or "Standing" end))
			table.insert(conns, hum.Died:Connect(function() pose = "Dead" end))
			table.insert(conns, RunService.Stepped:Connect(function()
				if not char.Parent or hum.Health <= 0 or pose == "Dead" then return end
				-- (Addtion-Scripts) climbing with the 2006 physics: the jump pose, as climbing looked in 2007
				local env2006 = (getgenv and getgenv()) or _G
				local climbJump = pose == "Climbing" and type(env2006.__Physics2006Cleanup) == "function"
				if pose == "Jumping" or pose == "FreeFall" or climbJump then
					rS.MaxVelocity = 0.75; lS.MaxVelocity = 0.75
					rS:SetDesiredAngle(3.14); lS:SetDesiredAngle(-3.14); rH:SetDesiredAngle(0); lH:SetDesiredAngle(0)
				elseif pose == "Seated" then
					rS.MaxVelocity = 0.15; lS.MaxVelocity = 0.15
					rS:SetDesiredAngle(1.57); lS:SetDesiredAngle(-1.57); rH:SetDesiredAngle(1.57); lH:SetDesiredAngle(-1.57)
				else
					local amp, freq, climb = 0.1, 1, 0
					-- (Addtion-Scripts) with the 2006 physics the arms come down slowly from a jump (as the 2007 Animation)
					local env = (getgenv and getgenv()) or _G
					local slow = type(env.__Physics2006Cleanup) == "function"
					if pose == "Running" then
						rS.MaxVelocity = 0.15; lS.MaxVelocity = 0.15; amp = 1; freq = 9
					elseif pose == "Climbing" then
						rS.MaxVelocity = 0.5; lS.MaxVelocity = 0.5; amp = 1; freq = 9; climb = 3.14
					end
					if slow and pose ~= "Climbing" then
						if math.abs(rS.CurrentAngle) > 1.05 then rS.MaxVelocity = 0.09 end
						if math.abs(lS.CurrentAngle) > 1.05 then lS.MaxVelocity = 0.09 end
					end
					local ang = amp * math.sin(os.clock() * freq)
					rS:SetDesiredAngle(ang + climb)
					lS:SetDesiredAngle(ang - climb)
					rH:SetDesiredAngle(-ang)
					lH:SetDesiredAngle(-ang)
				end
			end))
			table.insert(conns, { Disconnect = function() ClassicLimbs.release(handle) end })
			return true
		end
	end

	------------------------------------------------------------
	-- 5. OLD AVATAR (RETRO SUITE 2006) LOGIC
	------------------------------------------------------------
	do
		local retroState = {
			active = false,
			cleanup = {},
			limbs = {},  -- (Addtion-Scripts) ClassicLimbs handles, let go when turned off
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
			-- (Addtion-Scripts) R6 or R15: the four joints from ClassicLimbs (R15 ones answer the same way)
			local RightShoulder, LeftShoulder, RightHip, LeftHip, humanoid, limbs = ClassicLimbs.joints(char)
			if not RightShoulder then return end
			if not retroState.active then ClassicLimbs.release(limbs) return end
			table.insert(retroState.limbs, limbs)

			local defaultAnimate = char:FindFirstChild("Animate")
			if defaultAnimate then defaultAnimate.Disabled = true end

			for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
				track:Stop()
			end

			local pose = "Standing"
			local toolAnim = "None"
			local toolAnimTime = 0
			local jumpMaxLimbVelocity = 0.75
			local HammerEnv = (getgenv and getgenv()) or _G
			local ARMS_SWING_TOP = 1.05 -- (Addtion-Scripts) above the walking swing: the arms are still coming down
			local ARMS_DOWN_2006 = 0.09 -- (Addtion-Scripts) how fast they come down with the 2006 physics
			local BOUNCE_WINDOW = 0.35  -- (Addtion-Scripts) seconds after the 2006 landing bounce in which a fall is the bounce

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
				-- (Addtion-Scripts) with the 2006 physics the arms come down slowly after a jump or a fall (about 0.4 s,
				-- the time of its landing bounce), as the 2007 Animation does: on every character, also after a reset
				local slow2006 = type(HammerEnv.__Physics2006Cleanup) == "function"
				if (pose == "Jumping") then moveJump() return end
				if (pose == "FreeFall") then moveFreeFall() return end
				if (pose == "Seated") then moveSit() return end
				-- (Addtion-Scripts) climbing with the 2006 physics: the jump pose, as climbing looked in 2007
				if (pose == "Climbing" and slow2006) then moveJump() return end

				local amplitude = 0.1
				local frequency = 1
				local climbFudge = 0

				local downSpeed = slow2006 and ARMS_DOWN_2006 or jumpMaxLimbVelocity
				local top = slow2006 and ARMS_SWING_TOP or 1.5
				if (pose == "Running") then
					if (RightShoulder.CurrentAngle > top or RightShoulder.CurrentAngle < -top) then
						RightShoulder.MaxVelocity = downSpeed
					else  
						RightShoulder.MaxVelocity = 0.15
					end
					if (LeftShoulder.CurrentAngle > top or LeftShoulder.CurrentAngle < -top) then
						LeftShoulder.MaxVelocity = downSpeed
					else  
						LeftShoulder.MaxVelocity = 0.15
					end
					amplitude = 1
					frequency = 9
				elseif (pose == "Climbing") then
					RightShoulder.MaxVelocity = 0.5; LeftShoulder.MaxVelocity = 0.5
					amplitude = 1; frequency = 9; climbFudge = 3.14
				elseif slow2006 then
					if math.abs(RightShoulder.CurrentAngle) > ARMS_SWING_TOP then RightShoulder.MaxVelocity = downSpeed end
					if math.abs(LeftShoulder.CurrentAngle) > ARMS_SWING_TOP then LeftShoulder.MaxVelocity = downSpeed end
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
			table.insert(conns, humanoid.FreeFalling:Connect(function()
				-- (Addtion-Scripts) the 2006 physics' landing bounce is not a fall: the arms go on coming down
				local bounce = HammerEnv.BPLandingBounce
				if type(bounce) == "number" and os.clock() - bounce < BOUNCE_WINDOW and pose ~= "Jumping" then return end
				pose = "FreeFall"
			end))
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
					ClassicLimbs.release(limbs)
				end
			end))

			for _, c in ipairs(conns) do table.insert(retroState.cleanup, c) end
		end

		local function setupOther(char)
			if not char then return end
			-- (Addtion-Scripts) R6 or R15: the four joints from ClassicLimbs (R15 ones answer the same way)
			local rS, lS, rH, lH, hum, limbs = ClassicLimbs.joints(char)
			if not rS then return end
			if not retroState.active then ClassicLimbs.release(limbs) return end
			table.insert(retroState.limbs, limbs)

			local anim = char:FindFirstChild("Animate")
			if anim then anim.Disabled = true end

			for _, t in ipairs(hum:GetPlayingAnimationTracks()) do t:Stop(0) end

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
					ClassicLimbs.release(limbs)
				end
			end))

			retroState.otherTracked[char] = entry
		end

		local function handlePlayer(targetPlayer)
			if not targetPlayer then return end

			local function onCharacter(character)
				task.spawn(function()
					-- (Addtion-Scripts) the look in a pcall: an error there no longer leaves the character unanimated
					pcall(applyFullRetroAvatar, character)
					if targetPlayer == player then
						runLocalCharacter(character)
					else
						setupOther(character)
					end
					pcall(setupCustomAudio, character)
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
						-- (climbing with the 2006 physics: the jump pose, as yours)
						local climbJump = pose == "Climbing"
							and type(((getgenv and getgenv()) or _G).__Physics2006Cleanup) == "function"

						if pose == "Jumping" or pose == "FreeFall" or climbJump then
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
			-- the joints let go (R15 ones straight again, R6 ones back to 0) before the game's Animate is back
			for _, limbs in ipairs(retroState.limbs) do ClassicLimbs.release(limbs) end
			table.clear(retroState.limbs)

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
		-- Classic Face.lua in this repo: the face the player really wears, classic heads kept, and it can be
		-- switched off (getgenv().ClassicFace.Stop puts every head back). The gist is the fallback.
		local CLASSIC_FACE_URL = "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/Classic%20Face.lua"
		local CLASSIC_FACES_URL = "https://gist.githubusercontent.com/eloredo413-hue/7c035b526111523ac45eab852fc756e7/raw/2d31d61b91835bd59b90b44c24c772571bd6b63e/Classic%2520faces"
		local genv = (getgenv and getgenv()) or _G
		local cfActive = false
		local loading = false

		function actions.applyClassicFace()
			if cfActive then return end
			cfActive = true
			local api = genv.ClassicFace
			if type(api) == "table" and type(api.Start) == "function" then
				pcall(api.Start)
				return
			end
			if loading then return end
			loading = true
			local ok, err = pcall(function()
				loadstring(game:HttpGet(CLASSIC_FACE_URL))()
			end)
			if not ok then
				warn("[Classic Face] repo copy failed (" .. tostring(err) .. "), using the gist")
				ok, err = pcall(function()
					loadstring(game:HttpGet(CLASSIC_FACES_URL))()
				end)
			end
			loading = false
			if ok then
				print("[Classic Face] Loaded via loadstring.")
				-- unticked while it was downloading
				if not state.isClassicFaceEnabled then
					cfActive = true
					actions.restoreClassicFace()
				end
			else
				warn("[Classic Face] Loadstring failed: " .. tostring(err))
			end
		end

		-- (Addtion-Scripts) the repo copy loaded (it starts itself) without ticking "classic face", for "2008 players",
		-- which puts its 2006 head on everyone through it. Returns its api, or nil.
		function actions.loadClassicFace()
			local api = genv.ClassicFace
			if type(api) == "table" and type(api.Start) == "function" then return api end
			local t0 = os.clock()
			while loading and os.clock() - t0 < 20 do task.wait(0.1) end
			api = genv.ClassicFace
			if type(api) == "table" and type(api.Start) == "function" then return api end
			loading = true
			local ok, err = pcall(function()
				loadstring(game:HttpGet(CLASSIC_FACE_URL))()
			end)
			loading = false
			if not ok then warn("[Classic Face] couldn't be loaded for 2008 players: " .. tostring(err)) end
			api = genv.ClassicFace
			return (type(api) == "table" and type(api.Start) == "function") and api or nil
		end

		function actions.restoreClassicFace()
			if not cfActive then return end
			cfActive = false
			-- (Addtion-Scripts) "2008 players" puts its heads on through it: it stays on, and goes with 2008 players
			if state.is2008PlayersEnabled then
				print("[Classic Face] Kept on: 2008 players uses it.")
				return
			end

			local api = genv.ClassicFace
			if type(api) == "table" and type(api.Stop) == "function" then
				pcall(api.Stop)
				return
			end
			-- the gist copy (no off switch): take its classic heads off
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
	-- 6b. 2008 PLAYERS (Addtion-Scripts)
	-- Every player as a 2008 player, on your screen only:
	--   * no packages: the blocky body. R6 packages are CharacterMeshes on the character; each is taken off
	--     (kept, and put back when this is turned off), also when one comes in later. R15 limbs are MeshParts
	--     whose mesh a script can't change while the game runs, so R15 bodies keep their shape
	--   * the 2006 head (the 2006 avatar's head mesh) on everyone, with the face each player really wears as a
	--     classic face: done by Classic Face (Classic Face.lua), started for it with ClassicFace.SetHead. Headless
	--     heads are left as they are
	-- Their clothes, hats, body colours and animations are left alone. Not together with the old avatar or the
	-- 2006 avatar (they change the same things).
	------------------------------------------------------------
	do
		local genv = (getgenv and getgenv()) or _G
		local HEAD_2006_ASSET = "rbxassetid://12723461139"
		local HEAD_SCALE_2006 = Vector3.new(1.25, 1.25, 1.25)
		-- (removed: each package taken off -> its character. A plain table: the packages are out of the game, so
		-- nothing else holds on to them until they are put back)
		local p8 = { active = false, conns = {}, removed = {} }
		local headSpec = nil

		-- the 2006 head: the mesh in the 2006 avatar's head asset (the plain classic head if it can't be read)
		local function loadHead()
			if headSpec then return headSpec end
			local spec = { name = "the 2006 head", scale = HEAD_SCALE_2006 }
			local ok, objs = pcall(function() return game:GetObjects(HEAD_2006_ASSET) end)
			if ok and type(objs) == "table" and objs[1] then
				local root = objs[1]
				local found = nil
				if root:IsA("SpecialMesh") or root:IsA("MeshPart") then
					found = root
				else
					found = root:FindFirstChildWhichIsA("SpecialMesh", true) or root:FindFirstChildWhichIsA("MeshPart", true)
				end
				if found and found:IsA("SpecialMesh") and found.MeshId ~= "" then
					spec.meshId, spec.textureId = found.MeshId, found.TextureId
				elseif found and found:IsA("MeshPart") and found.MeshId ~= "" then
					spec.meshId, spec.textureId = found.MeshId, found.TextureID
				end
			end
			if not spec.meshId then
				warn("[2008 Players] the 2006 head couldn't be read: the plain classic head is used")
				spec.name = "the plain classic head"
			end
			headSpec = spec
			return spec
		end

		-- R6 packages off: each CharacterMesh kept aside (put back when turned off), also one put back by the game
		local function stripPackages(character)
			for _, child in ipairs(character:GetChildren()) do
				if child:IsA("CharacterMesh") then
					if p8.removed[child] == nil then p8.removed[child] = character end
					pcall(function() child.Parent = nil end)
				end
			end
		end

		local function hookCharacter(character)
			if not p8.active or not character then return end
			stripPackages(character)
			table.insert(p8.conns, character.ChildAdded:Connect(function(child)
				if p8.active and child:IsA("CharacterMesh") then
					-- (once it has been put in place)
					task.defer(function()
						if p8.active and child.Parent == character then stripPackages(character) end
					end)
				end
			end))
		end

		local function hookPlayer(plr)
			if plr.Character then hookCharacter(plr.Character) end
			table.insert(p8.conns, plr.CharacterAdded:Connect(hookCharacter))
		end

		function actions.apply2008Players()
			if p8.active then return end
			p8.active = true
			for _, plr in ipairs(Players:GetPlayers()) do pcall(hookPlayer, plr) end
			table.insert(p8.conns, Players.PlayerAdded:Connect(function(plr) pcall(hookPlayer, plr) end))
			task.spawn(function()
				local spec = loadHead()
				-- the head is set before Classic Face starts, so it does each head once
				if p8.active then genv.BPClassicFaceHead = spec end
				local api = actions.loadClassicFace and actions.loadClassicFace() or nil
				if not p8.active then return end
				if not api then
					warn("[2008 Players] Classic Face couldn't be started: the heads stay as they are")
					return
				end
				pcall(api.Start)
				if type(api.SetHead) == "function" then pcall(api.SetHead, spec) end
				print("[2008 Players] On: blocky bodies (R6 packages off), " .. tostring(spec.name) .. " with classic faces on everyone.")
			end)
		end

		function actions.restore2008Players()
			if not p8.active then return end
			p8.active = false
			for _, c in ipairs(p8.conns) do pcall(function() c:Disconnect() end) end
			table.clear(p8.conns)
			-- the packages back on their characters (not on one that is gone)
			for mesh, character in pairs(p8.removed) do
				if character.Parent then pcall(function() mesh.Parent = character end) end
			end
			table.clear(p8.removed)
			genv.BPClassicFaceHead = nil
			local api = genv.ClassicFace
			if type(api) == "table" then
				if type(api.SetHead) == "function" then pcall(api.SetHead, nil) end
				-- started for this only: off again ("classic face" ticked: it stays, with each head's own rules)
				if not state.isClassicFaceEnabled and type(api.Stop) == "function" then pcall(api.Stop) end
			end
			print("[2008 Players] Off: packages and heads back.")
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

		-- (Addtion-Scripts) NO ANIMATIONS, as on a 2006 character: the arms and legs held straight and still, whatever
		-- else would move them. Every frame, right before the physics step (Stepped, after the animations): each joint's
		-- animation offset cleared, its angle and target angle put to 0, and its turning speed to 0, so a script that
		-- turns the joints by angle (the old Animate scripts, the 2007 animation, Bloxy's) can't move it either. Every
		-- animation that starts is stopped, and the character's Animate script switched off. The turning speeds are
		-- given back when the 2006 avatar is turned off (or the character goes).
		local STRAIGHT_JOINTS = {
			["Right Shoulder"] = true, ["Left Shoulder"] = true, ["Right Hip"] = true, ["Left Hip"] = true, Neck = true,
			RightShoulder = true, LeftShoulder = true, RightElbow = true, LeftElbow = true, RightWrist = true, LeftWrist = true,
			RightHip = true, LeftHip = true, RightKnee = true, LeftKnee = true, RightAnkle = true, LeftAnkle = true,
			Waist = true,
		}
		local function holdLimbsStill(character, charConns, humanoid)
			local joints = {} -- joint -> its own turning speed (MaxVelocity), given back afterwards
			local function consider(m)
				if m:IsA("Motor6D") and STRAIGHT_JOINTS[m.Name] and joints[m] == nil then
					local ok, speed = pcall(function() return m.MaxVelocity end)
					joints[m] = ok and speed or false
				end
			end
			for _, d in ipairs(character:GetDescendants()) do consider(d) end
			table.insert(charConns, character.DescendantAdded:Connect(consider))
			local identity = CFrame.new()
			table.insert(charConns, RunService.Stepped:Connect(function()
				if not character.Parent then return end
				for m in pairs(joints) do
					if not m.Parent then
						joints[m] = nil
					else
						if m.Transform ~= identity then m.Transform = identity end
						pcall(function()
							if m.MaxVelocity ~= 0 then m.MaxVelocity = 0 end
							if m.CurrentAngle ~= 0 or m.DesiredAngle ~= 0 then
								m.DesiredAngle = 0
								m.CurrentAngle = 0
							end
						end)
					end
				end
			end))
			table.insert(charConns, {
				Disconnect = function()
					for m, speed in pairs(joints) do
						if speed and m.Parent then pcall(function() m.MaxVelocity = speed end) end
					end
					table.clear(joints)
				end,
			})
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

			-- nothing plays, whatever animations were picked in Bloxy's step (R6 and R15 alike)
			pcall(function()
				for _, t in ipairs(animator:GetPlayingAnimationTracks()) do t:Stop(0) end
			end)
			table.insert(charConns, animator.AnimationPlayed:Connect(function(track)
				pcall(function() track:Stop(0) end)
			end))
			holdLimbsStill(character, charConns, humanoid)
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

			-- Every frame only the shells whose weld is gone follow their head; the rest (sizes, meshes, the
			-- copied faces, the T-shirt guis) is looked at 10 times a second. It went through every head's
			-- children and decals on every frame.
			local syncAcc = 0
			table.insert(Connections, RunService.RenderStepped:Connect(function(dt)
				for head, shellData in pairs(HeadShells) do
					local shellPart = shellData.ShellPart
					if head and head.Parent and shellPart and shellPart.Parent
						and (not shellData.Weld or not shellData.Weld.Parent or shellData.Weld.Part0 ~= head) then
						shellPart.CFrame = head.CFrame
					end
				end
				syncAcc = syncAcc + (dt or 0)
				if syncAcc < 0.1 then return end
				syncAcc = 0
				syncOverlays()
			end))

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
	-- 12. OLD CAMERA SOUND + OLD PARTS CLATTERING SOUNDS (LOADSTRING)
	-- Each gist is downloaded once and run once. They have no off switch of their own,
	-- so a one-line check is added to each: unticking mutes it (and ticking again unmutes).
	------------------------------------------------------------
	do
		local genv = (getgenv and getgenv()) or _G

		local function makeSoundOption(tag, url, flag, patchFn)
			local loaded, loading = false, false
			local function enable()
				genv[flag] = nil
				if loaded or loading then
					print("[" .. tag .. "] Enabled.")
					return
				end
				loading = true
				local ok, err = pcall(function()
					local src = game:HttpGet(url)
					src = patchFn(src)
					loadstring(src)()
				end)
				loading = false
				if ok then
					loaded = true
					print("[" .. tag .. "] Loaded via loadstring.")
				else
					warn("[" .. tag .. "] Loadstring failed: " .. tostring(err))
				end
			end
			local function disable()
				genv[flag] = true
				print("[" .. tag .. "] Disabled" .. (loaded and " (muted)." or "."))
			end
			return enable, disable
		end

		local function replaceOnce(src, old, new)
			local a, b = string.find(src, old, 1, true)
			if not a then return src end
			return string.sub(src, 1, a - 1) .. new .. string.sub(src, b + 1)
		end

		actions.applyOldCameraSound, actions.restoreOldCameraSound = makeSoundOption(
			"Old Camera Sound",
			"https://gist.githubusercontent.com/eloredo413-hue/c05d381096487925901673670bced908/raw/8eb68872b09204cc7190fcf79bab167bbb31cd56/Old%2520camera%2520sound",
			"BPOldCameraSoundOff",
			function(src)
				return replaceOnce(src, "RunService.Heartbeat:Connect(function()",
					"RunService.Heartbeat:Connect(function()\n    if getgenv().BPOldCameraSoundOff then lastDistance = nil return end")
			end)

		actions.applyOldPartSounds, actions.restoreOldPartSounds = makeSoundOption(
			"Old Part Sounds",
			"https://gist.githubusercontent.com/eloredo413-hue/63a6cd9da469ff1659287fda43c8649a/raw/4e90245c65c9f3cf8b4cfb924f517a5012cd317c/Old%2520parts%2520clattering%2520sounds",
			"BPOldPartSoundsOff",
			function(src)
				return replaceOnce(src, "local function playSound(fileName, volume, parent)",
					"local function playSound(fileName, volume, parent)\n    if getgenv().BPOldPartSoundsOff then return end")
			end)
	end

	------------------------------------------------------------
	-- 13. REMOVE LEADERBOARD
	-- Takes the leaderboard off the screen: Roblox's own (CoreGui) and the era GUIs' (anything in CoreGui named like
	-- a player list or a leaderboard, and such a screen GUI of the game's). Phones had none for a long time.
	-- Event-driven: what is there is looked at once, what appears later as it is added. Unticking puts it all back.
	------------------------------------------------------------
	do
		local CoreGuiService = game:GetService("CoreGui")
		local StarterGui = game:GetService("StarterGui")
		local held = {}        -- gui -> { prop, was, conn }
		local conns = {}
		local active = false
		local coreWas = nil    -- whether Roblox's PlayerList was on before

		local function isLeaderboardName(name)
			name = string.lower(name)
			return string.find(name, "playerlist", 1, true) ~= nil or string.find(name, "leaderboard", 1, true) ~= nil
		end

		local function hold(gui)
			if held[gui] or not active then return end
			local prop = gui:IsA("LayerCollector") and "Enabled" or (gui:IsA("GuiObject") and "Visible") or nil
			if not prop then return end
			local entry = { prop = prop, was = gui[prop] }
			held[gui] = entry
			pcall(function() gui[prop] = false end)
			entry.conn = gui:GetPropertyChangedSignal(prop):Connect(function()
				if active and gui[prop] == true then
					entry.was = true
					pcall(function() gui[prop] = false end)
				end
			end)
		end

		local function consider(obj)
			if not (obj:IsA("GuiObject") or obj:IsA("LayerCollector")) then return end
			if not isLeaderboardName(obj.Name) then return end
			-- not something already inside one that is held
			local up = obj.Parent
			while up and up ~= game do
				if held[up] then return end
				up = up.Parent
			end
			task.defer(hold, obj)
		end

		function actions.applyRemoveLeaderboard()
			if active then return end
			active = true
			pcall(function()
				coreWas = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList)
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			end)
			table.insert(conns, StarterGui.CoreGuiChangedSignal:Connect(function(coreType, enabled)
				if active and enabled and (coreType == Enum.CoreGuiType.PlayerList or coreType == Enum.CoreGuiType.All) then
					pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
				end
			end))
			pcall(function()
				for _, obj in ipairs(CoreGuiService:GetDescendants()) do consider(obj) end
				table.insert(conns, CoreGuiService.DescendantAdded:Connect(consider))
			end)
			-- the game's own screen GUIs: only the top level, and only by name
			table.insert(conns, pg.ChildAdded:Connect(consider))
			for _, child in ipairs(pg:GetChildren()) do consider(child) end
			print("[Remove Leaderboard] On.")
		end

		function actions.restoreRemoveLeaderboard()
			if not active then return end
			active = false
			for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
			table.clear(conns)
			for gui, entry in pairs(held) do
				pcall(function() entry.conn:Disconnect() end)
				pcall(function() if gui.Parent then gui[entry.prop] = entry.was end end)
			end
			held = {}
			pcall(function()
				if coreWas ~= false then StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true) end
			end)
			print("[Remove Leaderboard] Off.")
		end
	end

	------------------------------------------------------------
	-- 14. 2013 DYNAMIC LIGHTS ("2013 dyn")
	-- Runs the 2013 Dynamic Lights script (SurfaceLights -> 2013-style SpotLights / PointLights, key 8 switches
	-- between the two). The script is downloaded once and kept; unticking calls its Destroy, which gives every
	-- SurfaceLight back and removes the key listener, and ticking again just runs the kept copy.
	------------------------------------------------------------
	do
		local LIGHTS_URL = "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/2013%20Dynamic%20Lights.lua"
		local genv = (getgenv and getgenv()) or _G
		local source = nil
		local loading = false

		local function runningApi()
			local api = genv.SurfaceLightConverter or _G.SurfaceLightConverter
			if type(api) == "table" and type(api.Destroy) == "function" then return api end
			return nil
		end

		function actions.apply2013Dynamic()
			if loading then return end
			local api = runningApi()
			if api then
				pcall(api.SetEnabled, true)
				print("[2013 Dynamic] On.")
				return
			end
			loading = true
			local ok, err = pcall(function()
				source = source or game:HttpGet(LIGHTS_URL)
				local fn, compileErr = loadstring(source)
				if not fn then error(compileErr, 0) end
				fn()
			end)
			loading = false
			if ok then
				print("[2013 Dynamic] Loaded via loadstring. Press 8 to switch between the 2013 lights and SurfaceLights.")
				-- Unticked while it was downloading
				if not state.is2013DynamicEnabled then actions.restore2013Dynamic() end
			else
				warn("[2013 Dynamic] Loadstring failed: " .. tostring(err))
			end
		end

		function actions.restore2013Dynamic()
			local api = runningApi()
			if not api then return end
			pcall(api.Destroy)
			genv.SurfaceLightConverter = nil
			genv.__SurfaceLightConverterCleanup = nil
			if _G.SurfaceLightConverter == api then _G.SurfaceLightConverter = nil end
			_G.__SurfaceLightConverterCleanup = nil
			print("[2013 Dynamic] Off, SurfaceLights back.")
		end
	end

	------------------------------------------------------------
	-- 15. WALK SOUNDS: 2015 AUDIO / 2016 AUDIO
	-- Your walking sound, played by a sound of its own whose pitch follows how fast you move (Roblox's own
	-- "Running" sound is muted while it is on and gets its volume back when it is off).
	--   2015 audio: pitch = speed / 16 (1.0 at normal speed: the lower 2015 pitch)
	--   2016 audio: pitch = speed / 16 x Roblox's own pitch for the floor (usually 1.85)
	-- It plays only while you walk yourself: you press to move (MoveDirection, as Roblox's own sound checks), you
	-- are running on the ground (not sitting, climbing or swimming), and you move against the floor. A conveyor
	-- carrying you (its belt moves, you don't) is silent, and walking on one sounds like normal walking.
	-- Only one at a time; it comes back after a respawn.
	------------------------------------------------------------
	do
		local SOUND_NAME = "BPClassicWalkSound"
		local mode = nil       -- "2015", "2016" or nil
		local charConn = nil
		local current = {}     -- { token, conn, sound, defaultRunning, wasVolume }

		local function cleanupChar()
			if current.conn then pcall(function() current.conn:Disconnect() end) end
			if current.sound then pcall(function() current.sound:Destroy() end) end
			if current.defaultRunning and current.wasVolume then
				pcall(function() current.defaultRunning.Volume = current.wasVolume end)
			end
			current = {}
		end

		local function applyTo(character)
			cleanupChar()
			local token = {}
			current.token = token
			local rootPart = character:WaitForChild("HumanoidRootPart", 5)
			local humanoid = character:WaitForChild("Humanoid", 5)
			if not rootPart or not humanoid or current.token ~= token or not mode then return end
			local existing = rootPart:FindFirstChild(SOUND_NAME)
			if existing then existing:Destroy() end
			-- wait for Roblox's own scripts to add the normal "Running" sound
			task.wait(0.5)
			if current.token ~= token or not mode then return end
			local defaultRunning = rootPart:FindFirstChild("Running")

			-- the part under you, to take away its own movement (a conveyor's belt, a moving platform)
			local floorRay = RaycastParams.new()
			floorRay.FilterType = Enum.RaycastFilterType.Exclude
			floorRay.FilterDescendantsInstances = { character }
			local function floorVelocity()
				local legs = humanoid.RigType == Enum.HumanoidRigType.R6 and 2 or humanoid.HipHeight
				local reach = legs + rootPart.Size.Y / 2 + 2
				local hit = workspace:Raycast(rootPart.Position, Vector3.new(0, -reach, 0), floorRay)
				if hit and hit.Instance then
					local ok, v = pcall(function() return hit.Instance:GetVelocityAtPosition(hit.Position) end)
					if ok and v then return v end
				end
				return Vector3.new(0, 0, 0)
			end

			local walkSound = Instance.new("Sound")
			walkSound.Name = SOUND_NAME
			walkSound.Looped = true
			walkSound.Volume = 0
			walkSound.Parent = rootPart
			walkSound:Play()
			current.sound = walkSound
			current.defaultRunning = defaultRunning
			current.wasVolume = defaultRunning and defaultRunning.Volume or nil

			local conn
			conn = RunService.Heartbeat:Connect(function()
				if not character.Parent or humanoid.Health <= 0 or not mode then
					conn:Disconnect()
					return
				end
				local basePitch = 1.85
				if defaultRunning then
					-- the same sound as Roblox's (keeps the grass / wood / metal sounds)
					if walkSound.SoundId ~= defaultRunning.SoundId then
						walkSound.SoundId = defaultRunning.SoundId
					end
					if defaultRunning.PlaybackSpeed > 0 then basePitch = defaultRunning.PlaybackSpeed end
					defaultRunning.Volume = 0
				end
				local walking = false
				local currentSpeed = 0
				local state = humanoid:GetState()
				if humanoid.MoveDirection.Magnitude > 0.1 and humanoid.FloorMaterial ~= Enum.Material.Air
					and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics) then
					-- how fast you move against the floor
					local velocity = rootPart.AssemblyLinearVelocity - floorVelocity()
					currentSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
					walking = currentSpeed > 0.5
				end
				if walking then
					walkSound.Volume = 0.65
					if mode == "2015" then
						walkSound.PlaybackSpeed = math.clamp(currentSpeed / 16, 0.2, 3)
					else
						walkSound.PlaybackSpeed = math.clamp((currentSpeed / 16) * basePitch, 0.3, 5)
					end
				else
					walkSound.Volume = 0
				end
			end)
			current.conn = conn
		end

		local function enable(which)
			mode = which
			if not charConn then
				charConn = player.CharacterAdded:Connect(function(character)
					if mode then task.spawn(applyTo, character) end
				end)
			end
			if player.Character then task.spawn(applyTo, player.Character) end
			print("[" .. which .. " Audio] On.")
		end

		local function disable(which)
			if mode ~= which then return end
			mode = nil
			if charConn then charConn:Disconnect() charConn = nil end
			cleanupChar()
			print("[" .. which .. " Audio] Off, Roblox's walking sound is back.")
		end

		function actions.apply2015Audio() enable("2015") end
		function actions.restore2015Audio() disable("2015") end
		function actions.apply2016Audio() enable("2016") end
		function actions.restore2016Audio() disable("2016") end
	end

	------------------------------------------------------------
	-- 16. OLD HEALTHBAR (2013 AND 2013 MOBILE)
	-- The 2011 and 2012 GUIs always get the 2011-2013 health bar (the loader puts it on; never before 2011). The 2013 GUI and
	-- the 2013 mobile GUI keep their own unless this is ticked; it does nothing for the other GUIs.
	------------------------------------------------------------
	do
		local genv = (getgenv and getgenv()) or _G
		local function refresh()
			if type(genv.BPRefreshHealthBar) == "function" then pcall(genv.BPRefreshHealthBar) end
		end
		function actions.applyOldHealthBar()
			genv.BPOldHealthBar2013 = true
			genv.BPOldHealthBar2013Mobile = true
			refresh()
			print("[Old Healthbar] On for the 2013 and 2013 mobile GUIs.")
		end
		function actions.restoreOldHealthBar()
			genv.BPOldHealthBar2013 = false
			genv.BPOldHealthBar2013Mobile = false
			refresh()
			print("[Old Healthbar] Off: the 2013 and 2013 mobile GUIs keep their own health bar.")
		end
	end

	------------------------------------------------------------
	-- 17. 2008 NIGHT SKY (2008 Night Sky.lua in this repo)
	-- At night (18:00 - 06:00 by the game's clock) a pitch-black sky with the classic 2008 square stars; the
	-- day sky as it is. Roblox's own stars off. Unticking puts the game's sky and stars back.
	------------------------------------------------------------
	do
		local NIGHT_SKY_URL = "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/2008%20Night%20Sky.lua"
		local genv = (getgenv and getgenv()) or _G
		local loading = false
		local function cleanup()
			local fn = _G.Cleanup2008NightSky or genv.Cleanup2008NightSky
			if type(fn) == "function" then pcall(fn) end
			_G.Cleanup2008NightSky = nil
			genv.Cleanup2008NightSky = nil
		end
		function actions.apply2008NightSky()
			if loading then return end
			loading = true
			task.spawn(function()
				local ok, err = pcall(function()
					loadstring(game:HttpGet(NIGHT_SKY_URL))()
				end)
				loading = false
				if not ok then
					warn("[2008 Night Sky] couldn't load: " .. tostring(err))
					return
				end
				-- unticked while it was downloading
				if not state.is2008NightSkyEnabled then cleanup() end
			end)
		end
		function actions.restore2008NightSky()
			cleanup()
		end
	end

	------------------------------------------------------------
	-- 18. ALL PLAYERS (All Players.lua in this repo)
	-- Your setup choices for how a character looks (Bloxy's forcefield, animations and 2006 body) on
	-- everyone else too, on your screen only. Not the physics, camera or GUIs. Unticking puts them back.
	------------------------------------------------------------
	do
		local ALL_PLAYERS_URL = "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/All%20Players.lua"
		local genv = (getgenv and getgenv()) or _G
		local loading = false
		local function cleanup()
			local fn = genv.BPAllPlayersCleanup
			if type(fn) == "function" then pcall(fn) end
			genv.BPAllPlayersCleanup = nil
		end
		function actions.applyAllPlayers()
			if loading then return end
			loading = true
			task.spawn(function()
				local ok, err = pcall(function()
					loadstring(game:HttpGet(ALL_PLAYERS_URL))()
				end)
				loading = false
				if not ok then
					warn("[All Players] couldn't load: " .. tostring(err))
					return
				end
				-- unticked while it was downloading
				if not state.isAllPlayersEnabled then cleanup() end
			end)
		end
		function actions.restoreAllPlayers()
			cleanup()
		end
	end

	------------------------------------------------------------
	-- (the 4:3 screen option was taken out: it is turned off if an earlier copy left it on)
	------------------------------------------------------------
	do
		local genv = (getgenv and getgenv()) or _G
		local api = genv.BPScreen43
		if api and type(api.Disable) == "function" then pcall(api.Disable) end
		genv.BPScreen43 = nil
	end

	------------------------------------------------------------
	-- 22. IW LEGACY LIGHTING and the LIGHTING ERA dropdown. "iw legacy lighting" (its own row; "normal" below) is
	-- IW Legacy Lighting.lua, the overhaul; the lighting eras (2014, 2015, 2016, 2017, 2019, 2020) are
	-- IW Legacy Lighting Years.lua, told the year in getgenv().BPIWLightingYear. Both can be ticked: then the era's
	-- file runs with iw's overhaul (getgenv().BPIWLightingOverhaul: the colours darkened and the light boosted to match,
	-- instead of lighting only). Underneath they are the same lighting script, so two copies never run side by side
	-- (they would fight over the light, each boosting the other's boost): there is always one, worked out from the
	-- ticks. Each keeps its own off switch, getgenv().LegacyLightingStop, which puts the game back (lighting, effects,
	-- colours, terrain). One loader makes every switch in order: the one running is stopped fully before the next
	-- starts, and a change made while a file is still downloading is followed once it is done, so the last one wins.
	-- Each file is downloaded once and kept.
	------------------------------------------------------------
	do
		local URLS = {
			normal = "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/IW%20Legacy%20Lighting.lua",
			years  = "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/IW%20Legacy%20Lighting%20Years.lua",
		}
		local IW_YEARS = { "2014", "2015", "2016", "2017", "2019", "2020" }
		local genv = (getgenv and getgenv()) or _G
		local sources = {}
		local wanted, running = nil, nil -- "normal", a year, "iw+" and a year (both ticked), or nil
		local busy = false
		local function stopIt()
			local stop = genv.LegacyLightingStop
			if type(stop) == "function" then pcall(stop) end
			running = nil
		end
		-- "ran", "skipped" (something else was picked while it downloaded: not started), or false (failed)
		local function startIt(choice)
			local url = (choice == "normal") and URLS.normal or URLS.years
			local year = (choice ~= "normal") and (string.match(choice, "^iw%+(%d+)$") or choice) or nil
			local overhaul = string.sub(choice, 1, 3) == "iw+"
			local result = "ran"
			local ok, err = pcall(function()
				local src = sources[url] or game:HttpGet(url)
				local fn, compileErr = loadstring(src)
				if not fn then error(compileErr, 0) end
				sources[url] = src
				if wanted ~= choice then
					result = "skipped"
					return
				end
				genv.BPIWLightingYear = year
				genv.BPIWLightingOverhaul = overhaul or nil
				fn()
			end)
			genv.BPIWLightingYear = nil
			genv.BPIWLightingOverhaul = nil
			if not ok then
				warn("[iw Legacy Lighting] " .. choice .. " couldn't load: " .. tostring(err))
				return false
			end
			return result
		end
		local function follow()
			if busy then return end
			busy = true
			task.spawn(function()
				local failed = {}
				while wanted ~= running and not (wanted ~= nil and failed[wanted]) do
					if running then stopIt() end
					local target = wanted
					if target then
						local result = startIt(target)
						if result == "ran" then
							running = target
						elseif result == false then
							failed[target] = true
						end
					end
				end
				busy = false
			end)
		end
		-- what should run, from the ticks (each tick or untick has already set its state when this runs)
		local function desired()
			local era = nil
			for _, year in ipairs(IW_YEARS) do
				if state["isIWLighting" .. year .. "Enabled"] then
					era = year
					break
				end
			end
			local iw = state.isIWLegacyLightingEnabled == true
			if iw and era then return "iw+" .. era end
			if iw then return "normal" end
			return era
		end
		local function sync()
			wanted = desired()
			follow()
		end
		actions.IWLightingYears = IW_YEARS
		actions.syncIWLighting = sync
		actions.applyIWLegacyLighting = sync
		actions.restoreIWLegacyLighting = sync
		for _, year in ipairs(IW_YEARS) do
			actions["applyIWLighting" .. year] = sync
			actions["restoreIWLighting" .. year] = sync
		end
	end

	------------------------------------------------------------
	-- 22c. FROM ROWIND: OLD MOON, 2014 SHADOWS, SLIPPERY WALK
	-- Rowind's own client scripts (its OldMoon, 2014CharacterShadowsTEST and SlipperyHumanoid), made to run from an
	-- executor in any game, and on R15 too. Each one is undone by unticking.
	------------------------------------------------------------
	do
		local Workspace = game:GetService("Workspace")

		-- OLD MOON (Rowind's OldMoon, its pre-2014 look): Roblox's own moon is hidden (MoonAngularSize 0) and a big
		-- faint moon picture is drawn far away opposite the sun instead, fading in at dusk (brightest 18:00 - 23:00),
		-- out at dawn, and a faint ghost of it by day. Not shown if the game's sky hides the sun and moon.
		local MOON_IMAGE = "rbxassetid://121399502791092"
		local moonState = { active = false }
		local MOON_AXIS = Vector3.new(-0.35, 0, 1).Unit

		local function moonLook(t)
			-- (Rowind's table for the clients up to 2013: how see-through the picture is, and how bright)
			local clear, bright = 0.95, 12
			if t >= 15 and t < 17.5 then
				if t < 17 then clear = 0.95 + (t - 15) / 2 * 0.1 else clear = 1 end
				bright = 12
			elseif t >= 17.5 and t < 18 then
				local a = (t - 17.5) / 0.5
				clear, bright = 1 - a * 0.8, 12 - a * 10
			elseif t >= 18 and t < 23 then
				clear, bright = 0.25, 2
			elseif t >= 23 then
				clear, bright = 0.25 + (t - 23) * 0.8, 2
			elseif t <= 5.83 then
				clear, bright = 1, 2
			elseif t < 6.16 then
				local a = (t - 5.83) / 0.33
				clear, bright = 1 - a * 0.1, 2 + a * 29
			elseif t >= 12 and t < 14 then
				clear, bright = 0.95, 30 - (t - 12) / 2 * 18
			elseif t >= 6.16 and t < 12 then
				clear, bright = 0.95, 30
			end
			return math.min(clear, 1), bright
		end

		function actions.applyOldMoon()
			if moonState.active then return end
			moonState.active = true
			local conns, skies = {}, {}
			moonState.conns, moonState.skies = conns, skies
			local function hideMoon(sky)
				if skies[sky] ~= nil then return end
				local ok, size = pcall(function() return sky.MoonAngularSize end)
				if ok then
					skies[sky] = size
					pcall(function() sky.MoonAngularSize = 0 end)
				end
			end
			for _, c in ipairs(Lighting:GetChildren()) do
				if c:IsA("Sky") then hideMoon(c) end
			end
			table.insert(conns, Lighting.ChildAdded:Connect(function(c)
				if moonState.active and c:IsA("Sky") then hideMoon(c) end
			end))

			local part = Instance.new("Part")
			part.Name = "BPOldMoon"
			part.Transparency = 1
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Size = Vector3.new(1, 1, 1)
			local gui = Instance.new("BillboardGui")
			gui.Name = "Interface"
			gui.Size = UDim2.new(1900, 0, 1900, 0)
			gui.LightInfluence = 0
			gui.Brightness = 12
			gui.Enabled = false
			gui.Parent = part
			local img = Instance.new("ImageLabel")
			img.Name = "Texture"
			img.BackgroundTransparency = 1
			img.Size = UDim2.new(1, 0, 1, 0)
			img.Image = MOON_IMAGE
			img.ImageTransparency = 0.95
			img.Parent = gui
			part:SetAttribute("BPOldMoon", true)
			moonState.part = part

			table.insert(conns, RunService.Heartbeat:Connect(function()
				local cam = Workspace.CurrentCamera
				if not (moonState.active and cam) then return end
				if part.Parent ~= cam then part.Parent = cam end
				local sky = Lighting:FindFirstChildOfClass("Sky")
				local shown = not sky or sky.CelestialBodiesShown
				gui.Enabled = shown
				if not shown then return end
				local dir = CFrame.fromAxisAngle(MOON_AXIS, -math.pi / 2) * Lighting:GetSunDirection()
				part.CFrame = CFrame.new(cam.CFrame.Position + dir * 10000)
				local clear, bright = moonLook(Lighting.ClockTime)
				gui.Brightness = bright
				img.ImageTransparency = clear
			end))
			print("[Old Moon] On.")
			if not state.isOldMoonEnabled then actions.restoreOldMoon() end
		end

		function actions.restoreOldMoon()
			if not moonState.active then return end
			moonState.active = false
			for _, c in ipairs(moonState.conns or {}) do pcall(function() c:Disconnect() end) end
			if moonState.part then pcall(function() moonState.part:Destroy() end) end
			for sky, size in pairs(moonState.skies or {}) do
				pcall(function()
					if sky.MoonAngularSize == 0 then sky.MoonAngularSize = size end
				end)
			end
			moonState.conns, moonState.skies, moonState.part = nil, nil, nil
			print("[Old Moon] Off, the game's moon back.")
		end

		-- 2014 SHADOWS (from Rowind's 2014 character shadow test, without its Studio-only parts), drawn as the old
		-- blob shadow (like the one under the characters in the 2013 Roblox app): each character casts a soft round
		-- blob instead of its own shadow, right under its feet on whatever is below (up to 27 studs down), almost half
		-- darker than the ground in the middle and fading smoothly out to nothing (a soft bell, no rings), smaller and
		-- fainter the higher the character is above it (a jump), none at night. It no longer stretches away from the sun
		-- or fades on surfaces turned from it: the blob is the same at any time of day.
		-- Drawn as 30 see-through discs on top of each other on a SurfaceGui (the more of them overlap, the darker; with
		-- 30 each step is under 2 % darker, too small to see), on an invisible part, so nothing that changes materials or surfaces
		-- (Hammer stuff's materials, 2009 / legacy materials, Bloxy's textures, studs) can change how it looks; anything
		-- put on the part is taken off again. No picture has to load (a frame's own gradients only run in a straight
		-- line, so the discs make the round one). Characters within 150 studs, the nearest 16.
		local SHADOW_REACH = 27
		local SHADOW_RANGE = 150
		local MAX_SHADOWS = 16
		local BLOB_SIZE = 3.8      -- studs across, standing on the ground (the faint edge included)
		local BLOB_CLEAR = 0.55    -- how much of the ground shows through in the middle (45 % darker; it was 0.65, a third)
		-- the discs' sizes (fractions of the blob's width): disc i covers where the bell (1 - r^2)^2 is at least
		-- (i - 0.5) / 30, so the darkness falls off as a smooth bell from the middle to the edge
		local LAYERS = {}
		for i = 1, 30 do LAYERS[i] = math.sqrt(1 - math.sqrt((i - 0.5) / 30)) end
		local shState = { active = false }

		-- one shadow: an invisible flat part whose top face carries the picture
		local function newShadow()
			local p = Instance.new("Part")
			p.Name = "BP2014Shadow"
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Transparency = 1
			p.Size = Vector3.new(4, 0.05, 4)
			p:SetAttribute("BPKeepMaterial", true)
			local gui = Instance.new("SurfaceGui")
			gui.Name = "Shadow"
			gui.Face = Enum.NormalId.Top
			gui.LightInfluence = 0
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 25
			gui.ClipsDescendants = true
			gui.Parent = p
			local frames = {}
			for i, scale in ipairs(LAYERS) do
				local f = Instance.new("Frame")
				f.Name = "Layer" .. i
				f.AnchorPoint = Vector2.new(0.5, 0.5)
				f.Position = UDim2.new(0.5, 0, 0.5, 0)
				f.Size = UDim2.new(scale, 0, scale, 0)
				f.BackgroundColor3 = Color3.new(0, 0, 0)
				f.BackgroundTransparency = 1
				f.BorderSizePixel = 0
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0.5, 0)
				corner.Parent = f
				f.Parent = gui
				frames[i] = f
			end
			-- anything another script puts on it (a stud texture, a decal) is taken off again
			p.ChildAdded:Connect(function(c)
				if c ~= gui then task.defer(function() pcall(function() c:Destroy() end) end) end
			end)
			return { part = p, gui = gui, frames = frames, size = nil, each = nil }
		end

		function actions.apply2014Shadows()
			if shState.active then return end
			shState.active = true
			local conns = {}
			local casters = {}  -- character -> { discs = {...}, castShadow = { part -> before } }
			shState.conns, shState.casters = conns, casters
			local folder = Instance.new("Folder")
			folder.Name = "BP2014Shadows"
			shState.folder = folder
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.IgnoreWater = false

			local function noOwnShadow(rec, part)
				if part:IsA("BasePart") and rec.castShadow[part] == nil then
					rec.castShadow[part] = part.CastShadow
					pcall(function() part.CastShadow = false end)
				end
			end
			local function giveBack(rec)
				pcall(function() rec.shadow.part:Destroy() end)
				for part, before in pairs(rec.castShadow) do
					pcall(function() if part.Parent then part.CastShadow = before end end)
				end
				for _, c in ipairs(rec.conns) do pcall(function() c:Disconnect() end) end
			end
			local function caster(char)
				local rec = casters[char]
				if rec then return rec end
				rec = { shadow = newShadow(), castShadow = {}, conns = {} }
				rec.shadow.part.Parent = folder
				for _, d in ipairs(char:GetDescendants()) do noOwnShadow(rec, d) end
				table.insert(rec.conns, char.DescendantAdded:Connect(function(d) noOwnShadow(rec, d) end))
				casters[char] = rec
				return rec
			end
			local function hide(rec)
				rec.shadow.gui.Enabled = false
			end

			table.insert(conns, RunService.RenderStepped:Connect(function()
				if not shState.active then return end
				local cam = Workspace.CurrentCamera
				if not cam then return end
				if folder.Parent ~= cam then folder.Parent = cam end
				local camPos = cam.CFrame.Position
				-- the characters near enough, nearest first
				local list, exclude = {}, { folder }
				for _, plr in ipairs(Players:GetPlayers()) do
					local char = plr.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if root and hum and hum.Health > 0 then
						table.insert(exclude, char)
						local dist = (root.Position - camPos).Magnitude
						if dist <= SHADOW_RANGE then table.insert(list, { char = char, root = root, dist = dist }) end
					end
				end
				table.sort(list, function(a, b) return a.dist < b.dist end)
				params.FilterDescendantsInstances = exclude
				local seen = {}
				local sun = Lighting:GetSunDirection()
				for i = 1, math.min(#list, MAX_SHADOWS) do
					local e = list[i]
					local rec = caster(e.char)
					seen[e.char] = true
					local body = e.char:FindFirstChild("Torso") or e.char:FindFirstChild("UpperTorso") or e.root
					-- the ground under the feet (straight down from the body)
					local hit = sun.Y > 0.02 and Workspace:Raycast(e.root.Position, Vector3.new(0, -SHADOW_REACH, 0), params) or nil
					if not hit then
						hide(rec)
					else
						local up = hit.Normal
						-- (any direction along the ground: the blob is round)
						local along = up:Cross(Vector3.new(1, 0, 0))
						if along.Magnitude < 0.01 then along = up:Cross(Vector3.new(0, 0, 1)) end
						along = along.Unit
						local right = along:Cross(up)
						local dist = (hit.Position - e.root.Position).Magnitude -- (how high above it: about 3 standing)
						local near = dist < 2.5 and dist / 2.5 or 1 - (dist - 2.5) / (SHADOW_REACH - 2.5)
						near = math.clamp(near, 0.05, 1)
						-- how see-through: fainter the higher above the ground, and when the character is see-through
						-- (first person included)
						local clear = BLOB_CLEAR + (1 - near) / 2
						local ok, bodyClear = pcall(function()
							return 1 - (1 - body.Transparency) * (1 - body.LocalTransparencyModifier)
						end)
						if ok then clear = clear + bodyClear end
						clear = math.clamp(clear, 0, 1)
						-- the discs on top of each other: each lets `each` of the light through, so the middle, where all of
						-- them are, lets `clear` through (each ^ count = clear), and towards the edge it gets lighter
						local each = clear ^ (1 / #LAYERS)
						local width = BLOB_SIZE * near
						local length = width
						-- round, right under the feet
						local center = hit.Position + up * 0.03
						local sh = rec.shadow
						-- (resized only when it really changes: a new size redraws the picture)
						local size = sh.size
						if not size or math.abs(size.X - width) > 0.05 or math.abs(size.Z - length) > 0.05 then
							sh.size = Vector3.new(width, 0.05, length)
							sh.part.Size = sh.size
						end
						sh.part.CFrame = CFrame.fromMatrix(center, right, up)
						-- (only when it changes: 30 discs on up to sixteen shadows, every frame)
						if not sh.each or math.abs(sh.each - each) > 0.002 then
							sh.each = each
							for _, f in ipairs(sh.frames) do f.BackgroundTransparency = each end
						end
						sh.gui.Enabled = true
					end
				end
				for char, rec in pairs(casters) do
					if not seen[char] then
						if char.Parent then
							hide(rec)
						else
							giveBack(rec)
							casters[char] = nil
						end
					end
				end
			end))
			print("[2014 Shadows] On.")
			if not state.is2014ShadowsEnabled then actions.restore2014Shadows() end
		end

		function actions.restore2014Shadows()
			if not shState.active then return end
			shState.active = false
			for _, c in ipairs(shState.conns or {}) do pcall(function() c:Disconnect() end) end
			for char, rec in pairs(shState.casters or {}) do
				pcall(function() rec.shadow.part:Destroy() end)
				for part, before in pairs(rec.castShadow) do
					pcall(function() if part.Parent then part.CastShadow = before end end)
				end
				for _, c in ipairs(rec.conns) do pcall(function() c:Disconnect() end) end
			end
			if shState.folder then pcall(function() shState.folder:Destroy() end) end
			shState.conns, shState.casters, shState.folder = nil, nil, nil
			print("[2014 Shadows] Off, characters cast their own shadows again.")
		end

		-- SLIPPERY WALK (Rowind's SlipperyHumanoid, its late 2015 - 2016 clients): let go of the stick and you slide
		-- to a stop instead of stopping dead: each frame (1/60 s) a quarter of the sideways speed is taken off, as
		-- Rowind's has it. Rowind did it with a LinearVelocity, which Roblox's own humanoid (stopping you at once)
		-- could overpower; here the slide is carried on after each physics step instead, so it shows the same with
		-- any of the physics (Old, 2007, 2006 or none), R6 and R15. Works with the physics: not while climbing (any
		-- of the physics' climbing too), sitting, swimming, tripped or flung, and not for a moment after a landing
		-- (the 2006 physics' landing stop and the Old physics' spring are theirs).
		local slState = { active = false }
		local SLIDE_KEEP = 0.75 -- share of the sideways speed kept each 1/60 s
		local NO_SLIDE = {
			[Enum.HumanoidStateType.Climbing] = true,
			[Enum.HumanoidStateType.Seated] = true,
			[Enum.HumanoidStateType.Swimming] = true,
			[Enum.HumanoidStateType.Ragdoll] = true,
			[Enum.HumanoidStateType.FallingDown] = true,
			[Enum.HumanoidStateType.PlatformStanding] = true,
			[Enum.HumanoidStateType.Dead] = true,
			[Enum.HumanoidStateType.Landed] = true,
		}
		local slGenv = (getgenv and getgenv()) or _G

		local function slipperyCharacter(char)
			if not slState.active or not char then return end
			local root = char:WaitForChild("HumanoidRootPart", 10)
			local hum = char:WaitForChild("Humanoid", 10)
			if not (slState.active and root and hum) then return end
			local last = Vector3.zero   -- the sideways speed after the last frame
			local landedAt = -1
			table.insert(slState.conns, hum.StateChanged:Connect(function(_, new)
				if new == Enum.HumanoidStateType.Landed then landedAt = os.clock() end
			end))
			table.insert(slState.conns, RunService.Heartbeat:Connect(function(dt)
				if not slState.active or not root.Parent then return end
				local v = root.AssemblyLinearVelocity
				local flat = Vector3.new(v.X, 0, v.Z)
				if hum.MoveDirection.Magnitude > 0 or hum.SeatPart or hum.PlatformStand or hum.Health <= 0
					or NO_SLIDE[hum:GetState()] or slGenv.BPClimbing or os.clock() - landedAt < 0.1 then
					last = flat
					return
				end
				local want = last * (SLIDE_KEEP ^ (math.min(dt or 1 / 60, 0.1) * 60))
				if want.Magnitude > 0.2 and want.Magnitude > flat.Magnitude + 0.05 and want:Dot(flat) >= 0 then
					-- stopped harder than that (Roblox's own stop): the slide goes on
					root.AssemblyLinearVelocity = Vector3.new(want.X, v.Y, want.Z)
					last = want
				else
					last = flat
				end
			end))
		end

		function actions.applySlipperyWalk()
			if slState.active then return end
			slState.active = true
			slState.conns, slState.made = {}, {}
			table.insert(slState.conns, player.CharacterAdded:Connect(function(char)
				task.spawn(slipperyCharacter, char)
			end))
			if player.Character then task.spawn(slipperyCharacter, player.Character) end
			print("[Slippery Walk] On.")
			if not state.isSlipperyWalkEnabled then actions.restoreSlipperyWalk() end
		end

		function actions.restoreSlipperyWalk()
			if not slState.active then return end
			slState.active = false
			for _, c in ipairs(slState.conns or {}) do pcall(function() c:Disconnect() end) end
			slState.conns, slState.made = nil, nil
			print("[Slippery Walk] Off.")
		end
	end

	------------------------------------------------------------
	-- 23. CHAT BAR (Chat Bar.lua in this repo)
	-- On a touch screen, the 2012 / 2013 GUIs' Chat button becomes the chat bar along the bottom they have
	-- on a PC; 2015 early shows its own bar (hidden on phones while this is off) and hides its Chat button.
	-- Unticking gives the button back. Not the 2013 mobile GUI.
	------------------------------------------------------------
	do
		local CHAT_BAR_URL = "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/Chat%20Bar.lua"
		local genv = (getgenv and getgenv()) or _G
		local loading = false
		local function turnOff()
			local api = genv.BPChatBar
			if api and type(api.Disable) == "function" then pcall(api.Disable) end
		end
		function actions.applyChatBar()
			local api = genv.BPChatBar
			if api and type(api.Enable) == "function" then pcall(api.Enable) return end
			if loading then return end
			loading = true
			task.spawn(function()
				local ok, err = pcall(function()
					loadstring(game:HttpGet(CHAT_BAR_URL))()
				end)
				loading = false
				if not ok then
					warn("[Chat Bar] couldn't load: " .. tostring(err))
					return
				end
				-- unticked while it was downloading
				if not state.isChatBarEnabled then turnOff() end
			end)
		end
		function actions.restoreChatBar()
			turnOff()
		end
	end

	------------------------------------------------------------
	-- 21. HIDE MOBILE CONTROLS
	-- The joystick and the jump button can't be seen but still work: each part of them gets a see-through
	-- UIGradient (it hides what is drawn, and doesn't fight the controls' own fading in and out), and they
	-- stay shown and active, so taps still reach them. Roblox's touch controls (TouchGui, also Bloxy's old
	-- jump button on it) and Mobile Controls.lua's (LegacyTouchControls: "mobile controls" and "old thumbstick").
	------------------------------------------------------------
	do
		local TOUCH_GUIS = { TouchGui = true, LegacyTouchControls = true }
		local MARK = "BPHiddenTouch"
		local CoreGuiService = game:GetService("CoreGui")
		local hideConns = {}
		local hidden = false

		local function hideObject(obj)
			if not obj:IsA("GuiObject") or obj:FindFirstChild(MARK) then return end
			local gradient = Instance.new("UIGradient")
			gradient.Name = MARK
			gradient.Transparency = NumberSequence.new(1)
			gradient.Parent = obj
		end
		local function hideGui(gui)
			if not (gui:IsA("ScreenGui") and TOUCH_GUIS[gui.Name]) then return end
			for _, d in ipairs(gui:GetDescendants()) do pcall(hideObject, d) end
			table.insert(hideConns, gui.DescendantAdded:Connect(function(d)
				task.defer(function() if hidden then pcall(hideObject, d) end end)
			end))
		end
		local function touchHolders()
			local list = {}
			local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
			if playerGui then table.insert(list, playerGui) end
			table.insert(list, CoreGuiService)
			pcall(function()
				local hui = gethui and gethui()
				if hui and hui ~= CoreGuiService then table.insert(list, hui) end
			end)
			return list
		end

		function actions.applyHideMobileControls()
			if hidden then return end
			hidden = true
			for _, holder in ipairs(touchHolders()) do
				for _, gui in ipairs(holder:GetChildren()) do pcall(hideGui, gui) end
				table.insert(hideConns, holder.ChildAdded:Connect(function(child)
					task.delay(0.2, function() if hidden then pcall(hideGui, child) end end)
				end))
			end
			print("[Addon] Mobile controls hidden (they still work).")
		end
		function actions.restoreHideMobileControls()
			hidden = false
			for _, c in ipairs(hideConns) do pcall(function() c:Disconnect() end) end
			table.clear(hideConns)
			for _, holder in ipairs(touchHolders()) do
				for _, gui in ipairs(holder:GetChildren()) do
					if gui:IsA("ScreenGui") and TOUCH_GUIS[gui.Name] then
						for _, d in ipairs(gui:GetDescendants()) do
							if d.Name == MARK and d:IsA("UIGradient") then d:Destroy() end
						end
					end
				end
			end
			print("[Addon] Mobile controls shown again.")
		end
	end

	------------------------------------------------------------
	-- 21b. MOBILE CONTROLS and OLD THUMBSTICK (Mobile Controls.lua, downloaded once and kept)
	-- "mobile controls": the 2013 mobile GUI's joystick and jump button, now for any GUI (Roblox's own touch
	-- controls hidden while on). "old thumbstick": Roblox's classic thumbstick (its own pictures and the way its
	-- script worked: past its edge the whole stick follows your thumb, anywhere; let go and it goes back to its
	-- corner). It replaces only the stick: the
	-- 2013 joystick with mobile controls, Roblox's own thumbstick without (Roblox's or Bloxy's jump button stays).
	-- "hide controls" hides these too (they still work). One copy runs: the first tick downloads and starts it,
	-- later ticks only change what it shows.
	------------------------------------------------------------
	do
		local URL = "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/Mobile%20Controls.lua"
		local genv = (getgenv and getgenv()) or _G
		local source = nil
		local busy = false
		local function wanted()
			return state.isMobileControlsEnabled == true, state.isOldThumbstickEnabled == true
		end
		local function running()
			local api = genv.BPMobileControls
			if type(api) == "table" and type(api.Set) == "function" then return api end
			return nil
		end
		function actions.syncMobileControls()
			if busy then return end -- the download in progress follows the latest ticks when it is done
			local api = running()
			if api then
				pcall(api.Set, wanted())
				return
			end
			local controls, oldStick = wanted()
			if not (controls or oldStick) then return end
			busy = true
			local ok, err = pcall(function()
				local src = source or game:HttpGet(URL)
				local fn, compileErr = loadstring(src)
				if not fn then error(compileErr, 0) end
				source = src
				local c, o = wanted() -- (the ticks may have changed while it downloaded)
				if not (c or o) then return end
				genv.BPMobileControlsWant = { controls = c, oldThumbstick = o }
				fn()
			end)
			genv.BPMobileControlsWant = nil
			busy = false
			if not ok then
				warn("[Addon] Mobile controls couldn't load: " .. tostring(err))
				return
			end
			local api2 = running()
			if api2 then pcall(api2.Set, wanted()) end
		end
	end

	------------------------------------------------------------
	-- 20. FPS CAP
	-- The frame rate capped at the number typed in. The executor's setfpscap does it; when there is none, or
	-- the frame rate stays above the cap anyway (some executors have one that does nothing), a frame limiter
	-- here does it (each frame waits until its time is up). The frame rate now is counted, for the row's label.
	------------------------------------------------------------
	do
		local genv = (getgenv and getgenv()) or _G
		local RunService = game:GetService("RunService")
		local DEFAULT_CAP = 60
		local limiterConn = nil
		local applyToken = 0
		local frames, fpsNow = 0, 0

		-- the frame rate now (frames counted each half second)
		RunService.RenderStepped:Connect(function() frames = frames + 1 end)
		task.spawn(function()
			local last = os.clock()
			while true do
				task.wait(0.5)
				local now = os.clock()
				fpsNow = frames / math.max(now - last, 1e-3)
				frames, last = 0, now
				if type(actions.onFpsMeasured) == "function" then pcall(actions.onFpsMeasured, fpsNow) end
			end
		end)
		function actions.currentFps() return fpsNow end

		local function executorCap()
			local fn = setfpscap or set_fps_cap or genv.setfpscap or genv.set_fps_cap
			if type(fn) == "function" then return fn end
			return nil
		end

		local function stopLimiter()
			if limiterConn then limiterConn:Disconnect() limiterConn = nil end
		end
		local function startLimiter(cap)
			stopLimiter()
			local frameTime = 1 / cap
			local nextFrame = os.clock() + frameTime
			limiterConn = RunService.RenderStepped:Connect(function()
				local now = os.clock()
				-- (a busy wait: the frame doesn't end before its time)
				while now < nextFrame do now = os.clock() end
				nextFrame = math.max(nextFrame + frameTime, now)
			end)
		end

		local function clampCap(value)
			local cap = math.floor(tonumber(value) or 0)
			if cap < 0 then cap = 0 end
			if cap > 0 and cap < 5 then cap = 5 end   -- (lower than that the game can hardly be played)
			if cap > 1000 then cap = 1000 end
			return cap
		end
		actions.clampFpsCap = clampCap

		-- cap 0: no cap
		function actions.setFpsCap(value)
			local cap = clampCap(value)
			applyToken = applyToken + 1
			local token = applyToken
			stopLimiter()
			local setCap = executorCap()
			if cap == 0 then
				if setCap then
					if not pcall(setCap, 0) then pcall(setCap, 1000) end
				end
				print("[FPS cap] no cap")
				return cap
			end
			if setCap and pcall(setCap, cap) then
				print("[FPS cap] capped at " .. cap .. " FPS (the executor's setfpscap)")
				-- does it hold? if the frame rate stays above the cap, the limiter takes over
				task.delay(2.5, function()
					if token ~= applyToken then return end
					if fpsNow > cap + 4 then
						startLimiter(cap)
						print("[FPS cap] the frame rate stayed at " .. math.floor(fpsNow) .. ": capped at " .. cap
							.. " by a frame limiter instead")
					end
				end)
			else
				startLimiter(cap)
				print("[FPS cap] capped at " .. cap .. " FPS (a frame limiter: this executor has no setfpscap)")
			end
			return cap
		end

		function actions.applyFpsCap()
			if state.fpsCap <= 0 then state.fpsCap = DEFAULT_CAP end
			state.fpsCap = actions.setFpsCap(state.fpsCap)
			if type(actions.onFpsCapChanged) == "function" then pcall(actions.onFpsCapChanged) end
		end
		function actions.restoreFpsCap()
			actions.setFpsCap(0)
		end
	end

	------------------------------------------------------------
	-- 10. HIDE GAME GUI (LOADSTRING HOOK)
	-- The GUI Hider (Hide game GUI.lua in this repo: the gist without its __namecall hook) hides the game's
	-- own ScreenGuis (TopbarPlus, HUDs, shop buttons) and leaves Bloxy Paradox and the era GUIs alone.
	-- It puts getgenv().GameGuiHider (Show / Hide) in place, so after the
	-- first load the box only calls those.
	------------------------------------------------------------
	do
		local GUI_HIDER_URL = "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/Hide%20game%20GUI.lua"
		local genv = (getgenv and getgenv()) or _G
		local loading = false

		function actions.applyHideGameGui()
			local hider = genv.GameGuiHider
			if hider and type(hider.Hide) == "function" then
				pcall(hider.Hide)
				print("[Hide Game GUI] Enabled.")
				return
			end
			if loading then return end
			loading = true
			-- The gist hides the game GUI as soon as it runs.
			local ok, err = pcall(function()
				loadstring(game:HttpGet(GUI_HIDER_URL))()
			end)
			loading = false
			if ok then
				print("[Hide Game GUI] Loaded via loadstring.")
				-- Unticked while it was downloading
				if not state.isHideGameGuiEnabled then actions.restoreHideGameGui() end
			else
				warn("[Hide Game GUI] Loadstring failed: " .. tostring(err))
			end
		end

		function actions.restoreHideGameGui()
			local hider = genv.GameGuiHider
			if hider and type(hider.Show) == "function" then
				pcall(hider.Show)
				print("[Hide Game GUI] Disabled, game GUI shown again.")
			end
		end
	end

	------------------------------------------------------------
	-- 11. LEGACY LIGHTING (LOADSTRING HOOK)
	-- The Legacy Lighting gist (2017 OldGraphics lighting) has no off
	-- switch: it sets Technology to Compatibility, turns Lighting's
	-- effects off and keeps them off, removes the Atmosphere and adds a
	-- grey ColorCorrectionEffect. Before running it, the lighting is
	-- remembered here; unticking puts all of that back.
	------------------------------------------------------------
	do
		local LEGACY_LIGHTING_URL = "https://gist.githubusercontent.com/eloredo413-hue/09783d75811e0cac34d222908cb25670/raw/94382a78fc770c1fc4a4860cbe095b4c72b1bb6b/Legacy%2520Lighting%2520Option"
		local EFFECT_CLASSES = { "DepthOfFieldEffect", "SunRaysEffect", "BloomEffect", "BlurEffect", "ColorCorrectionEffect" }

		local llState = { active = false, busy = false }

		local function isEffect(inst)
			for _, className in ipairs(EFFECT_CLASSES) do
				if inst.ClassName == className then return true end
			end
			return false
		end

		local function connectionList(signal)
			if type(getconnections) ~= "function" then return {} end
			local ok, list = pcall(getconnections, signal)
			return (ok and type(list) == "table") and list or {}
		end

		-- (Addtion-Scripts) It can be on together with "iw legacy lighting": that one's own effects (marked
		-- BPIWLegacyLighting) are taken out of Lighting while the gist runs, so it doesn't switch them off for
		-- good, and the gist's grey colour correction is marked BPLegacyLighting, which iw legacy lighting
		-- leaves on. The game's own Technology is kept in getgenv().BPGameTechnology by whichever of the two
		-- changed it first, and given back by the last one to stop.
		local genv = (getgenv and getgenv()) or _G

		local function isModernTechnology(value)
			for _, name in ipairs({ "Future", "ShadowMap" }) do
				local ok, item = pcall(function() return Enum.Technology[name] end)
				if ok and value == item then return true end
			end
			return false
		end

		function actions.applyLegacyLighting()
			if llState.active or llState.busy then return end
			llState.busy = true

			-- iw legacy lighting's own effects: out of the gist's way while it runs
			local iwEffects = {}
			for _, child in ipairs(Lighting:GetChildren()) do
				if child:GetAttribute("BPIWLegacyLighting") then
					table.insert(iwEffects, child)
					pcall(function() child.Parent = nil end)
				end
			end

			-- Remember everything the gist changes
			local saved = { effects = {}, atmospheres = {}, children = {} }
			if type(gethiddenproperty) == "function" then
				pcall(function() saved.technology = gethiddenproperty(Lighting, "Technology") end)
			end
			if genv.BPGameTechnology == nil and saved.technology ~= nil then
				genv.BPGameTechnology = saved.technology
			end
			for _, child in ipairs(Lighting:GetChildren()) do
				saved.children[child] = true
				if isEffect(child) then
					local signal = child:GetPropertyChangedSignal("Enabled")
					local before = {}
					for _, c in ipairs(connectionList(signal)) do
						if c.Function then before[c.Function] = true end
					end
					saved.effects[child] = { enabled = child.Enabled, signal = signal, before = before }
				elseif child:IsA("Atmosphere") then
					local ok, copy = pcall(function() return child:Clone() end)
					if ok and copy then table.insert(saved.atmospheres, copy) end
				end
			end

			local ok, err = pcall(function()
				loadstring(game:HttpGet(LEGACY_LIGHTING_URL))()
			end)
			llState.busy = false
			for _, child in ipairs(iwEffects) do
				pcall(function() child.Parent = Lighting end)
			end
			if not ok then
				warn("[Legacy Lighting] Loadstring failed: " .. tostring(err))
				return
			end

			-- The gist's "keep it off" connections and the effect it added
			for effect, info in pairs(saved.effects) do
				info.added = {}
				for _, c in ipairs(connectionList(info.signal)) do
					-- Only connections whose function is known and new: never the game's own
					if c.Function and not info.before[c.Function] then table.insert(info.added, c) end
				end
			end
			saved.newChildren = {}
			for _, child in ipairs(Lighting:GetChildren()) do
				if not saved.children[child] and child:IsA("ColorCorrectionEffect")
				   and not child:GetAttribute("BPIWLegacyLighting") then
					table.insert(saved.newChildren, child)
					-- (iw legacy lighting leaves it on)
					pcall(function()
						child:SetAttribute("BPLegacyLighting", true)
						child.Enabled = true
					end)
				end
			end

			llState.saved = saved
			llState.active = true
			genv.BPLegacyLightingOn = true
			print("[Legacy Lighting] Loaded via loadstring.")

			-- Unticked while it was downloading
			if not state.isLegacyLightingEnabled then actions.restoreLegacyLighting() end
		end

		function actions.restoreLegacyLighting()
			if not llState.active then return end
			llState.active = false
			genv.BPLegacyLightingOn = nil
			local saved = llState.saved
			llState.saved = nil
			if not saved then return end

			for _, child in ipairs(saved.newChildren) do
				pcall(function() child:Destroy() end)
			end

			for effect, info in pairs(saved.effects) do
				if effect.Parent then
					local freed = #info.added > 0
					for _, c in ipairs(info.added) do
						local stopped = pcall(function() c:Disconnect() end)
						if not stopped then stopped = pcall(function() c:Disable() end) end
						freed = freed and stopped
					end
					if freed then
						pcall(function() effect.Enabled = info.enabled end)
					elseif info.enabled then
						-- No getconnections: the gist would switch the effect straight
						-- back off, so swap in a copy that has no connection on it.
						pcall(function()
							local copy = effect:Clone()
							copy.Enabled = true
							copy.Parent = effect.Parent
							effect:Destroy()
						end)
					end
				end
			end

			for _, atmosphere in ipairs(saved.atmospheres) do
				if not Lighting:FindFirstChildOfClass("Atmosphere") then
					pcall(function() atmosphere.Parent = Lighting end)
				end
			end

			if type(sethiddenproperty) == "function" then
				if type(genv.LegacyLightingStop) == "function" then
					-- iw legacy lighting is still on: what was there before the gist, but never Future /
					-- ShadowMap under it (Voxel then); it gives the game's own back when it stops
					local back = saved.technology
					if back == nil or isModernTechnology(back) then
						local ok, voxel = pcall(function() return Enum.Technology.Voxel end)
						back = ok and voxel or nil
					end
					if back ~= nil then pcall(sethiddenproperty, Lighting, "Technology", back) end
				else
					local original = genv.BPGameTechnology
					if original == nil then original = saved.technology end
					genv.BPGameTechnology = nil
					if original ~= nil then pcall(sethiddenproperty, Lighting, "Technology", original) end
				end
			end
			print("[Legacy Lighting] Disabled, original lighting restored.")
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
	local waitUntil = os.clock() + 10
	while not destroyBtn and os.clock() < waitUntil do
		task.wait(0.1)
		destroyBtn = scroll:FindFirstChild("BPDestroyGuiButton", true)
	end
	if not destroyBtn then
		warn("[Addon] Could not find destroy button.")
		return
	end

	-- This addon's rows start where the base GUI's destroy button sits; the old decal
	-- button, destroy button and bottom spacer go below them. Everything is placed by
	-- relayout() from absolute positions, so running this script again (or opening and
	-- closing dropdowns) never pushes things further down than they belong.
	local ROW_HEIGHT = 30
	local startY     = destroyBtn.Position.Y.Offset
	local decalBtnY  = startY + 19 * ROW_HEIGHT + 10

	-- Ran before: start where our first row already is, not at the (already moved)
	-- destroy button.
	local previousFirstRow = scroll:FindFirstChild("BPCategoryGraphics") or scroll:FindFirstChild("HealthESPContainer")
	if previousFirstRow then
		startY = previousFirstRow.Position.Y.Offset
		decalBtnY = startY + 19 * ROW_HEIGHT + 10
	end

	local spacer = scroll:FindFirstChild("BPBottomSpacer")
	local layoutEntries = {} -- top-level rows in order: { frame = Frame, extra = function() -> number }
	local oldDecalBtn
	local unselectBtn

	local function setY(obj, y)
		if not obj then return end
		local p = obj.Position
		obj.Position = UDim2.new(p.X.Scale, p.X.Offset, 0, y)
	end

	local layingOut = false
	local function relayout()
		layingOut = true
		-- The base script's dropdown moves our rows by position, so read where the
		-- first one is now instead of trusting startY.
		local first = layoutEntries[1]
		if first and first.frame.Parent then
			startY = first.frame.Position.Y.Offset
		end

		local y = startY
		for _, entry in ipairs(layoutEntries) do
			setY(entry.frame, y)
			y = y + ROW_HEIGHT + entry.extra()
		end

		y = y + 10
		if oldDecalBtn then setY(oldDecalBtn, y) end
		y = y + 36 + 10
		if unselectBtn then setY(unselectBtn, y) end
		y = y + 36 + 10
		setY(destroyBtn, y)
		if spacer then setY(spacer, y + 40) end

		if scroll:IsA("ScrollingFrame") and scroll.AutomaticCanvasSize == Enum.AutomaticSize.None then
			scroll.CanvasSize = UDim2.new(scroll.CanvasSize.X.Scale, scroll.CanvasSize.X.Offset, 0, y + 40 + 30)
		end
		layingOut = false
	end

	-- (Addtion-Scripts) Other scripts move rows by their position (Hammer stuff 1's and Bloxy's dropdowns move
	-- everything below them), and a row moved without the rest ended up on top of another one. When any of our rows
	-- is moved from outside, they are all laid out again right after, one under the other from the first.
	local relayoutQueued = false
	local function queueRelayout()
		if layingOut or relayoutQueued then return end
		relayoutQueued = true
		task.defer(function()
			relayoutQueued = false
			pcall(relayout)
		end)
	end
	local function watchEntry(frame)
		frame:GetPropertyChangedSignal("Position"):Connect(queueRelayout)
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
		lbl.Size = isOption and UDim2.new(0, 112, 0, 30) or UDim2.new(0, 130, 0, 30)
		lbl.Position = isOption and UDim2.new(0, 6, 0, 0) or UDim2.new(0, 0, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.FontFace = fontBold
		lbl.TextSize = isOption and 14 or 16
		lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = labelText
		-- (a long label, like "iw legacy lighting", a little smaller so it stays clear of its box)
		if #labelText > 15 then lbl.TextSize = isOption and 12 or 13 end
		lbl.ZIndex = 97
		lbl.Parent = cont

		local cb = Instance.new("TextButton")
		cb.Name = boxName
		cb.Size = UDim2.new(0, 16, 0, 16)
		cb.Position = UDim2.new(0, 118, 0, 7)
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
		help.Position = UDim2.new(0, 140, 0, 7)
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
		local cont, cb, help = buildRow(parent or scroll, rowSpec.containerName, rowSpec.label, rowSpec.yPos, rowSpec.checkboxName, rowSpec.helpName)
		if not parent then
			table.insert(layoutEntries, { frame = cont, extra = function() return 0 end })
			watchEntry(cont)
		end
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
		table.insert(layoutEntries, {
			frame = cont,
			extra = function() return expanded and height or 0 end,
		})
		watchEntry(cont)

		arrow.MouseButton1Click:Connect(function()
			playClick()
			expanded = not expanded
			options.Visible = expanded
			arrow.Text = expanded and "▲" or "▼"
			cont.Size = UDim2.new(1, -30, 0, expanded and 30 + height or 30)
			relayout()
		end)

		help.MouseButton1Click:Connect(function()
			playClick()
			showInfo(dropSpec.helpText)
		end)
	end

	-- Category title (e.g. "graphics & lighting") above a group of options: a plain label in the
	-- same list, placed by relayout() like the rows.
	local function createCategory(name, title)
		local existing = scroll:FindFirstChild(name)
		if existing then existing:Destroy() end
		local cont = Instance.new("Frame")
		cont.Name = name
		cont.Size = UDim2.new(1, -30, 0, 30)
		cont.Position = UDim2.new(0, 15, 0, startY)
		cont.BackgroundTransparency = 1
		cont.ZIndex = 96
		cont.Parent = scroll

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 0, 22)
		lbl.Position = UDim2.new(0, 0, 0, 6)
		lbl.BackgroundTransparency = 1
		lbl.FontFace = fontBold
		lbl.TextSize = 13
		lbl.TextColor3 = Color3.fromRGB(255, 220, 120)
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = string.upper(title)
		lbl.ZIndex = 97
		lbl.Parent = cont

		local line = Instance.new("Frame")
		line.Size = UDim2.new(1, 0, 0, 1)
		line.Position = UDim2.new(0, 0, 1, -2)
		line.BackgroundColor3 = Color3.fromRGB(255, 220, 120)
		line.BackgroundTransparency = 0.5
		line.BorderSizePixel = 0
		line.ZIndex = 97
		line.Parent = cont

		table.insert(layoutEntries, { frame = cont, extra = function() return 0 end })
		watchEntry(cont)
	end

	createCategory("BPCategoryGraphics", "graphics & lighting")

	createAddonRow({
		containerName = "NightSky2008Container",
		checkboxName  = "NightSky2008Checkbox",
		helpName      = "NightSky2008HelpButton",
		label         = "2008 night sky",
		yPos          = startY + 13 * ROW_HEIGHT,
		stateKey      = "is2008NightSkyEnabled",
		onEnable      = actions.apply2008NightSky,
		onDisable     = actions.restore2008NightSky,
		helpText      = "The 2008 night: at sunset (17:30 - 18:15, the game's clock) the sky fades to pitch black and the classic 2008 square stars fade in; at sunrise (05:45 - 06:30) it fades back. Roblox's own stars are off. The day sky stays as it is. Untick to put the game's sky and stars back."
	})

	createAddonRow({
		containerName = "OldMoonContainer",
		checkboxName  = "OldMoonCheckbox",
		helpName      = "OldMoonHelpButton",
		label         = "old moon",
		yPos          = startY,
		stateKey      = "isOldMoonEnabled",
		onEnable      = actions.applyOldMoon,
		onDisable     = actions.restoreOldMoon,
		helpText      = "From Rowind: the old moon. Roblox's own moon is hidden and a big faint moon is drawn far away instead, fading in at dusk (clearest 18:00 - 23:00), out at dawn, with a faint ghost of it by day. Follows the game's clock. Not shown if the game's sky hides the sun and moon. The moon picture is Rowind's: if it doesn't load in a game, nothing shows. Untick to put the game's moon back."
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
		helpText      = "Applies classic 2016-era flat lighting with the Retro tonemapper. Parts are converted to SmoothPlastic. Shadows are kept. The game's Atmosphere and effects are their own option now: remove effects. Disabling restores lighting; material changes persist."
	})

	createAddonRow({
		containerName = "RemoveEffectsContainer",
		checkboxName  = "RemoveEffectsCheckbox",
		helpName      = "RemoveEffectsHelpButton",
		label         = "remove effects",
		yPos          = startY + ROW_HEIGHT,
		stateKey      = "isRemoveEffectsEnabled",
		onEnable      = actions.applyRemoveEffects,
		onDisable     = actions.restoreRemoveEffects,
		helpText      = "Takes away the game's Atmosphere and its other effects (bloom, blur, colour correction, depth of field, sun rays...), also ones it adds later. Untick to put them back."
	})

	createAddonRow({
		containerName = "Lighting2006Container",
		checkboxName  = "Lighting2006Checkbox",
		helpName      = "Lighting2006HelpButton",
		label         = "2006-07 lighting",
		yPos          = startY + ROW_HEIGHT,
		stateKey      = "is2006LightingEnabled",
		onEnable      = actions.apply2006Lighting,
		onDisable     = actions.restore2006Lighting,
		helpText      = "The 2006-07 look of the sky: the game's Atmosphere colour turned all the way up (white). Works with remove pro too: its old lighting doesn't draw Atmospheres, so then the white haze is drawn as white fog. A game with no Atmosphere gets none. Untick to put everything back."
	})

	createAddonRow({
		containerName = "LegacyLightingContainer",
		checkboxName  = "LegacyLightingCheckbox",
		helpName      = "LegacyLightingHelpButton",
		label         = "legacy lighting",
		yPos          = startY + 8 * ROW_HEIGHT,
		stateKey      = "isLegacyLightingEnabled",
		onEnable      = actions.applyLegacyLighting,
		onDisable     = actions.restoreLegacyLighting,
		helpText      = "2017 OldGraphics lighting: Compatibility technology, no bloom, blur, sun rays, depth of field or atmosphere, and flat grey colors. Can be on together with iw legacy lighting. Untick to put the original lighting back."
	})

	createAddonRow({
		containerName = "IWLegacyLightingContainer",
		checkboxName  = "IWLegacyLightingCheckbox",
		helpName      = "IWLegacyLightingHelpButton",
		label         = "iw legacy lighting",
		yPos          = startY,
		stateKey      = "isIWLegacyLightingEnabled",
		onEnable      = actions.applyIWLegacyLighting,
		onDisable     = actions.restoreIWLegacyLighting,
		helpText      = "The iw legacy lighting, only on your screen: an overhaul of the game's look, brighter light with darker colors like the old Voxel look, the game's bloom / atmosphere / sun rays off, terrain darkened, no 3D clouds or grass blades. The game's time of day keeps going. Works with classic faces, and can be on together with legacy lighting. Can be on together with a lighting era: then the era's look is used with this overhaul (colors darkened, light boosted). Untick to put the game back as it was (lighting, effects, colors, terrain)."
	})

	createDropdown({
		containerName = "LightingEraDropdownContainer",
		arrowName     = "LightingEraDropdownArrow",
		helpName      = "LightingEraDropdownHelpButton",
		label         = "lighting era",
		yPos          = startY,
		helpText      = "Press the arrow to pick a lighting era: 2014, 2015, 2016, 2017, 2019 or 2020 (lighting only, as in your era scripts: the map's colors aren't changed, and soft voxel shadows are on). Only one era can be on at a time (picking one stops the one that is on first). An era can be on together with iw legacy lighting (the era's look with iw's overhaul: colors darkened, light boosted) and with legacy lighting.",
		options = {
			{
				containerName = "IWLighting2014Container",
				checkboxName  = "IWLighting2014Checkbox",
				helpName      = "IWLighting2014HelpButton",
				label         = "2014 lighting",
				stateKey      = "isIWLighting2014Enabled",
				exclusiveWith = { "isIWLighting2015Enabled", "isIWLighting2016Enabled", "isIWLighting2017Enabled", "isIWLighting2019Enabled", "isIWLighting2020Enabled" },
				onEnable      = actions.applyIWLighting2014,
				onDisable     = actions.restoreIWLighting2014,
				helpText      = "The 2014 lighting, only on your screen: lighting only (the map's colors aren't changed), soft voxel shadows, and none of what came in 2017 or later: glass shows as plain see-through plastic, no trails, beams, lit particles or lit 3D GUIs. The game's bloom / atmosphere / sun rays off, no 3D clouds or grass blades. (2014, 2015 and 2016 are the same: their scripts have the same settings.) The game's time of day keeps going. Works with classic faces, and can be on together with legacy lighting. With iw legacy lighting ticked too, this era's look is used with iw's overhaul (colors darkened, light boosted). Untick to put the game back as it was (lighting, effects, glass, trails)."
			},
			{
				containerName = "IWLighting2015Container",
				checkboxName  = "IWLighting2015Checkbox",
				helpName      = "IWLighting2015HelpButton",
				label         = "2015 lighting",
				stateKey      = "isIWLighting2015Enabled",
				exclusiveWith = { "isIWLighting2014Enabled", "isIWLighting2016Enabled", "isIWLighting2017Enabled", "isIWLighting2019Enabled", "isIWLighting2020Enabled" },
				onEnable      = actions.applyIWLighting2015,
				onDisable     = actions.restoreIWLighting2015,
				helpText      = "The 2015 lighting, only on your screen: lighting only (the map's colors aren't changed), soft voxel shadows, and none of what came in 2017 or later: glass shows as plain see-through plastic, no trails, beams, lit particles or lit 3D GUIs. The game's bloom / atmosphere / sun rays off, no 3D clouds or grass blades. (2014, 2015 and 2016 are the same: their scripts have the same settings.) The game's time of day keeps going. Works with classic faces, and can be on together with legacy lighting. With iw legacy lighting ticked too, this era's look is used with iw's overhaul (colors darkened, light boosted). Untick to put the game back as it was (lighting, effects, glass, trails)."
			},
			{
				containerName = "IWLighting2016Container",
				checkboxName  = "IWLighting2016Checkbox",
				helpName      = "IWLighting2016HelpButton",
				label         = "2016 lighting",
				stateKey      = "isIWLighting2016Enabled",
				exclusiveWith = { "isIWLighting2014Enabled", "isIWLighting2015Enabled", "isIWLighting2017Enabled", "isIWLighting2019Enabled", "isIWLighting2020Enabled" },
				onEnable      = actions.applyIWLighting2016,
				onDisable     = actions.restoreIWLighting2016,
				helpText      = "The 2016 lighting, only on your screen: lighting only (the map's colors aren't changed), soft voxel shadows, and none of what came in 2017 or later: glass shows as plain see-through plastic, no trails, beams, lit particles or lit 3D GUIs. The game's bloom / atmosphere / sun rays off, no 3D clouds or grass blades. (2014, 2015 and 2016 are the same: their scripts have the same settings.) The game's time of day keeps going. Works with classic faces, and can be on together with legacy lighting. With iw legacy lighting ticked too, this era's look is used with iw's overhaul (colors darkened, light boosted). Untick to put the game back as it was (lighting, effects, glass, trails)."
			},
			{
				containerName = "IWLighting2017Container",
				checkboxName  = "IWLighting2017Checkbox",
				helpName      = "IWLighting2017HelpButton",
				label         = "2017 lighting",
				stateKey      = "isIWLighting2017Enabled",
				exclusiveWith = { "isIWLighting2014Enabled", "isIWLighting2015Enabled", "isIWLighting2016Enabled", "isIWLighting2019Enabled", "isIWLighting2020Enabled" },
				onEnable      = actions.applyIWLighting2017,
				onDisable     = actions.restoreIWLighting2017,
				helpText      = "The 2017 lighting, only on your screen: lighting only (the map's colors aren't changed), soft voxel shadows, glass, trails, beams, lit particles and lit 3D GUIs as the game has them. The game's bloom / atmosphere / sun rays off, no 3D clouds or grass blades. The game's time of day keeps going. Works with classic faces, and can be on together with legacy lighting. With iw legacy lighting ticked too, this era's look is used with iw's overhaul (colors darkened, light boosted). Untick to put the game back as it was (lighting, effects, glass, trails)."
			},
			{
				containerName = "IWLighting2019Container",
				checkboxName  = "IWLighting2019Checkbox",
				helpName      = "IWLighting2019HelpButton",
				label         = "2019 lighting",
				stateKey      = "isIWLighting2019Enabled",
				exclusiveWith = { "isIWLighting2014Enabled", "isIWLighting2015Enabled", "isIWLighting2016Enabled", "isIWLighting2017Enabled", "isIWLighting2020Enabled" },
				onEnable      = actions.applyIWLighting2019,
				onDisable     = actions.restoreIWLighting2019,
				helpText      = "The 2019 lighting, only on your screen: the 2017 one with the newer tonemapper of the 2018-2019 lighting update (brighter, softer highlights instead of the hard retro clipping). The game's time of day keeps going. Works with classic faces, and can be on together with legacy lighting. With iw legacy lighting ticked too, this era's look is used with iw's overhaul (colors darkened, light boosted). Untick to put the game back as it was (lighting, effects, glass, trails)."
			},
			{
				containerName = "IWLighting2020Container",
				checkboxName  = "IWLighting2020Checkbox",
				helpName      = "IWLighting2020HelpButton",
				label         = "2020 lighting",
				stateKey      = "isIWLighting2020Enabled",
				exclusiveWith = { "isIWLighting2014Enabled", "isIWLighting2015Enabled", "isIWLighting2016Enabled", "isIWLighting2017Enabled", "isIWLighting2019Enabled" },
				onEnable      = actions.applyIWLighting2020,
				onDisable     = actions.restoreIWLighting2020,
				helpText      = "The 2020 lighting, only on your screen: the 2019 one, and what Roblox had by 2020 stays: 3D clouds, grass blades and the game's own atmosphere, bloom and sun rays. The game's time of day keeps going. Works with classic faces, and can be on together with legacy lighting. With iw legacy lighting ticked too, this era's look is used with iw's overhaul (colors darkened, light boosted). Untick to put the game back as it was (lighting, effects, glass, trails)."
			},
		}
	})

	createAddonRow({
		containerName = "Shadows2014Container",
		checkboxName  = "Shadows2014Checkbox",
		helpName      = "Shadows2014HelpButton",
		label         = "2014 shadows",
		yPos          = startY,
		stateKey      = "is2014ShadowsEnabled",
		onEnable      = actions.apply2014Shadows,
		onDisable     = actions.restore2014Shadows,
		helpText      = "The old blob shadow (as under the characters in the 2013 Roblox app), from Rowind's 2014 character shadow test: each character casts a soft round blob instead of its own shadow, right under its feet on the ground or whatever is below, almost half darker in the middle and fading smoothly out to nothing, the same at any time of day, fainter and smaller the higher it is above the ground, none at night. Materials and textures don't change it. Characters within 150 studs (the nearest 16). Untick to give characters their own shadows back."
	})

	createAddonRow({
		containerName = "Dynamic2013Container",
		checkboxName  = "Dynamic2013Checkbox",
		helpName      = "Dynamic2013HelpButton",
		label         = "2013 dyn",
		yPos          = startY + 12 * ROW_HEIGHT,
		stateKey      = "is2013DynamicEnabled",
		onEnable      = actions.apply2013Dynamic,
		onDisable     = actions.restore2013Dynamic,
		helpText      = "2013 dynamic lights: turns the game's SurfaceLights into 2013-style SpotLights and PointLights. Press 8 to switch between the 2013 lights and the SurfaceLights. Untick to put every SurfaceLight back."
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

	createCategory("BPCategoryAvatar", "avatar")

	createDropdown({
		containerName = "AvatarDropdownContainer",
		arrowName     = "AvatarDropdownArrow",
		helpName      = "AvatarDropdownHelpButton",
		label         = "avatar",
		yPos          = startY + 4 * ROW_HEIGHT,
		helpText      = "Press the arrow to pick an avatar era: old avatar, 2006 avatar or 2008 players. Only one can be on at a time.",
		options = {
			{
				containerName = "OldAvatarContainer",
				checkboxName  = "OldAvatarCheckbox",
				helpName      = "OldAvatarHelpButton",
				label         = "old avatar",
				stateKey      = "isOldAvatarEnabled",
				exclusiveWith = { "is2006AvatarEnabled", "is2008PlayersEnabled" },
				onEnable      = actions.applyOldAvatar,
				onDisable     = actions.restoreOldAvatar,
				helpText      = "Retro Suite 2006: 2010 Motor6D procedural animations for all players (R6 and R15 bodies), 31-color palette quantization, 1-hat/1-hair enforcement, legacy audio, and original mesh/face textures."
			},
			{
				containerName = "Avatar2006Container",
				checkboxName  = "Avatar2006Checkbox",
				helpName      = "Avatar2006HelpButton",
				label         = "2006 avatar",
				stateKey      = "is2006AvatarEnabled",
				exclusiveWith = { "isOldAvatarEnabled", "is2008PlayersEnabled" },
				onEnable      = actions.apply2006Avatar,
				onDisable     = actions.restore2006Avatar,
				helpText      = "Retro Suite 2006 Executor Edition: random 2006 body colors, classic head and face, sharp R6 meshes, the 2006 T-shirt badge, no animations (arms and legs stay still, as in 2006) and sounds for all players. Removes accessories and clothing; respawn to get them back after disabling."
			},
			{
				containerName = "Players2008Container",
				checkboxName  = "Players2008Checkbox",
				helpName      = "Players2008HelpButton",
				label         = "2008 players",
				stateKey      = "is2008PlayersEnabled",
				exclusiveWith = { "isOldAvatarEnabled", "is2006AvatarEnabled" },
				onEnable      = actions.apply2008Players,
				onDisable     = actions.restore2008Players,
				helpText      = "Every player as a 2008 player: the blocky body (R6 packages taken off; R15 bodies keep their shape, a script can't change those) and the 2006 head with the face each player wears as a classic face (through classic face, started for it). Clothes, hats and colors stay. Untick to put packages and heads back."
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
		helpText      = "Classic heads with 2D faces. Each player gets the face they really wear (their 2D face, their face item, or the classic face named like their dynamic head). Classic heads (Roundy, Blockhead...) keep their shape; only dynamic heads get a classic head on top, in the head's skin color (it follows paint / skin tone changes). Untick to put every head back."
	})

	createAddonRow({
		containerName = "AllPlayersContainer",
		checkboxName  = "AllPlayersCheckbox",
		helpName      = "AllPlayersHelpButton",
		label         = "all players",
		yPos          = startY + 5 * ROW_HEIGHT,
		stateKey      = "isAllPlayersEnabled",
		onEnable      = actions.applyAllPlayers,
		onDisable     = actions.restoreAllPlayers,
		helpText      = "Your setup choices for how a character looks go on everyone else too, on your screen only: the forcefield (2008 / 2012), the animations (each set on bodies of its own kind, R6 or R15) and the 2006 body. Not the physics, the camera or any GUI. (Classic face, the avatars and the 2007 animation already go on everyone.) Untick to put everyone back."
	})

	createCategory("BPCategorySounds", "sounds")

	createAddonRow({
		containerName = "OldCameraSoundContainer",
		checkboxName  = "OldCameraSoundCheckbox",
		helpName      = "OldCameraSoundHelpButton",
		label         = "camera sound",
		yPos          = startY + 9 * ROW_HEIGHT,
		stateKey      = "isOldCameraSoundEnabled",
		onEnable      = actions.applyOldCameraSound,
		onDisable     = actions.restoreOldCameraSound,
		helpText      = "The old camera zoom tick: a click sound for every 1.5 studs the camera zooms in or out. Untick to mute it."
	})

	createAddonRow({
		containerName = "OldPartSoundsContainer",
		checkboxName  = "OldPartSoundsCheckbox",
		helpName      = "OldPartSoundsHelpButton",
		label         = "part sounds",
		yPos          = startY + 10 * ROW_HEIGHT,
		stateKey      = "isOldPartSoundsEnabled",
		onEnable      = actions.applyOldPartSounds,
		onDisable     = actions.restoreOldPartSounds,
		helpText      = "The old clattering sounds when parts hit each other (a classic sound pack, saved in your executor's ClassicSounds folder the first time). Loose parts and dead characters only. Untick to mute it."
	})

	createAddonRow({
		containerName = "Audio2015Container",
		checkboxName  = "Audio2015Checkbox",
		helpName      = "Audio2015HelpButton",
		label         = "2015 audio",
		yPos          = startY,
		stateKey      = "is2015AudioEnabled",
		exclusiveWith = { "is2016AudioEnabled" },
		onEnable      = actions.apply2015Audio,
		onDisable     = actions.restore2015Audio,
		helpText      = "2015 walking sound: its pitch follows your speed (speed / 16), so normal walking sounds lower, like 2015. Only when you walk yourself: standing on a moving conveyor is silent. Only one of 2015 / 2016 audio at a time. Untick for Roblox's own walking sound."
	})

	createAddonRow({
		containerName = "Audio2016Container",
		checkboxName  = "Audio2016Checkbox",
		helpName      = "Audio2016HelpButton",
		label         = "2016 audio",
		yPos          = startY,
		stateKey      = "is2016AudioEnabled",
		exclusiveWith = { "is2015AudioEnabled" },
		onEnable      = actions.apply2016Audio,
		onDisable     = actions.restore2016Audio,
		helpText      = "2016 walking sound: its pitch follows your speed (speed / 16 x Roblox's pitch), so normal walking sounds like 2016. Only when you walk yourself: standing on a moving conveyor is silent. Only one of 2015 / 2016 audio at a time. Untick for Roblox's own walking sound."
	})

	createCategory("BPCategoryInterface", "interface")

	createAddonRow({
		containerName = "OldHealthBarContainer",
		checkboxName  = "OldHealthBarCheckbox",
		helpName      = "OldHealthBarHelpButton",
		label         = "old healthbar",
		yPos          = startY,
		stateKey      = "isOldHealthBarEnabled",
		onEnable      = actions.applyOldHealthBar,
		onDisable     = actions.restoreOldHealthBar,
		helpText      = "For the 2013 and 2013 mobile GUIs only: their health bar becomes the 2011-2013 one (dark tray, green bar, HEALTH). The 2011 and 2012 GUIs always have that one (nothing before 2011 does). Untick for the 2013 GUIs' own bar."
	})

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
		containerName = "RemoveLeaderboardContainer",
		checkboxName  = "RemoveLeaderboardCheckbox",
		helpName      = "RemoveLeaderboardHelpButton",
		label         = "no leaderboard",
		yPos          = startY + 11 * ROW_HEIGHT,
		stateKey      = "isRemoveLeaderboardEnabled",
		onEnable      = actions.applyRemoveLeaderboard,
		onDisable     = actions.restoreRemoveLeaderboard,
		helpText      = "Removes the leaderboard (the player list): Roblox's own and the era GUIs'. Phone GUIs had none for a long time. Untick to bring it back."
	})

	createAddonRow({
		containerName = "HideGameGuiContainer",
		checkboxName  = "HideGameGuiCheckbox",
		helpName      = "HideGameGuiHelpButton",
		label         = "hide game GUI",
		yPos          = startY + 7 * ROW_HEIGHT,
		stateKey      = "isHideGameGuiEnabled",
		onEnable      = actions.applyHideGameGui,
		onDisable     = actions.restoreHideGameGui,
		helpText      = "Hides the game's own GUI (TopbarPlus buttons, HUDs, shop buttons, menus). Bloxy Paradox, the retro top bar and every era GUI stay. Untick to show the game GUI again. Right Ctrl also switches it."
	})

	createAddonRow({
		containerName = "ChatBarContainer",
		checkboxName  = "ChatBarCheckbox",
		helpName      = "ChatBarHelpButton",
		label         = "chatbar",
		yPos          = startY,
		stateKey      = "isChatBarEnabled",
		onEnable      = actions.applyChatBar,
		onDisable     = actions.restoreChatBar,
		helpText      = "For the 2012, 2013 and 2015 early GUIs on a phone or tablet: the Chat button goes and the chat bar along the bottom is shown (\"To chat click here or press \"/\" key\"), like on a PC. Tap it to type. Not the 2013 mobile GUI. Untick for the Chat button again (2015 early's bar is then hidden)."
	})

	createCategory("BPCategoryControls", "controls & performance")

	createAddonRow({
		containerName = "HideMobileControlsContainer",
		checkboxName  = "HideMobileControlsCheckbox",
		helpName      = "HideMobileControlsHelpButton",
		label         = "hide controls",
		yPos          = startY,
		stateKey      = "isHideMobileControlsEnabled",
		onEnable      = actions.applyHideMobileControls,
		onDisable     = actions.restoreHideMobileControls,
		helpText      = "Hides the mobile joystick and jump button, but they still work: move and jump with your thumbs where they would be. Also hides mobile controls and old thumbstick. Untick to see them again."
	})

	createAddonRow({
		containerName = "MobileControlsContainer",
		checkboxName  = "MobileControlsCheckbox",
		helpName      = "MobileControlsHelpButton",
		label         = "mobile controls",
		yPos          = startY,
		stateKey      = "isMobileControlsEnabled",
		onEnable      = actions.syncMobileControls,
		onDisable     = actions.syncMobileControls,
		helpText      = "The 2013 mobile GUI's joystick and jump button, with any GUI (or none). Roblox's own touch controls are hidden while it is on. The joystick drives cars too, and holding jump keeps jumping. With old thumbstick ticked too, the old thumbstick takes the joystick's place. Untick for Roblox's own controls again."
	})

	createAddonRow({
		containerName = "OldThumbstickContainer",
		checkboxName  = "OldThumbstickCheckbox",
		helpName      = "OldThumbstickHelpButton",
		label         = "old thumbstick",
		yPos          = startY,
		stateKey      = "isOldThumbstickEnabled",
		onEnable      = actions.syncMobileControls,
		onDisable     = actions.syncMobileControls,
		helpText      = "Roblox's classic thumbstick from the old control script (2014-2016), with its own pictures and the way it worked: in the bottom-left corner, 70 across on a phone. Put your thumb on it and it centres under your thumb; drag, and once your thumb goes past its edge the whole stick comes along with it, anywhere on the screen. Let go and it goes back to its corner. It only replaces the thumbstick: with Roblox's regular controls their jump button (and Bloxy's old jump button) stays; with mobile controls it takes the 2013 joystick's place, as big as their jump button. It drives cars too, and works with hide controls. Untick for the thumbstick you had before."
	})

	createAddonRow({
		containerName = "SlipperyWalkContainer",
		checkboxName  = "SlipperyWalkCheckbox",
		helpName      = "SlipperyWalkHelpButton",
		label         = "slippery walk",
		yPos          = startY,
		stateKey      = "isSlipperyWalkEnabled",
		onEnable      = actions.applySlipperyWalk,
		onDisable     = actions.restoreSlipperyWalk,
		helpText      = "From Rowind (its late 2015 - 2016 physics): let go of the stick and you slide to a stop instead of stopping dead. Works together with any of the physics (Old, 2007, 2006) or none, on R6 and R15; not while climbing, sitting or swimming, or just after a landing. Untick to stop dead again."
	})

	-- the FPS cap: its tick box, then a number box (the "?" after it); the label shows the frame rate now
	createAddonRow({
		containerName = "FpsCapContainer",
		checkboxName  = "FpsCapCheckbox",
		helpName      = "FpsCapHelpButton",
		label         = "fps cap",
		yPos          = startY,
		stateKey      = "isFpsCapEnabled",
		onEnable      = actions.applyFpsCap,
		onDisable     = actions.restoreFpsCap,
		helpText      = "Caps the frame rate. Tick it, then type the number (like 30) in the box: it is used straight away. The number after \"fps cap\" is your frame rate now. Untick for no cap. (Roblox itself stops at 60 unless its own setting is higher.)"
	})
	local fpsBox
	do
		local row = rows.isFpsCapEnabled
		local cont = row and row.checkbox.Parent
		if cont then
			local help = cont:FindFirstChild("FpsCapHelpButton")
			if help then help.Position = UDim2.new(0, 184, 0, 7) end
			local label = cont:FindFirstChildOfClass("TextLabel")
			fpsBox = Instance.new("TextBox")
			fpsBox.Name = "FpsCapBox"
			fpsBox.Size = UDim2.new(0, 36, 0, 18)
			fpsBox.Position = UDim2.new(0, 142, 0, 6)
			fpsBox.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
			fpsBox.BackgroundTransparency = 0.5
			fpsBox.BorderSizePixel = 0
			fpsBox.ClearTextOnFocus = false
			fpsBox.Font = Enum.Font.SourceSansBold
			fpsBox.TextSize = 14
			fpsBox.TextColor3 = Color3.fromRGB(255, 255, 255)
			fpsBox.PlaceholderText = "60"
			fpsBox.PlaceholderColor3 = Color3.fromRGB(200, 200, 200)
			fpsBox.Text = state.fpsCap > 0 and tostring(state.fpsCap) or ""
			fpsBox.ZIndex = 97
			fpsBox.Parent = cont
			local st = Instance.new("UIStroke")
			st.Color = Color3.fromRGB(255, 255, 255)
			st.Thickness = 1.2
			st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			st.Parent = fpsBox

			local function showBox()
				if not fpsBox:IsFocused() then
					fpsBox.Text = state.fpsCap > 0 and tostring(state.fpsCap) or ""
				end
			end
			actions.onFpsCapChanged = showBox
			-- the number typed: used straight away (a moment after the last key, and when the box is left);
			-- typing one turns the cap on
			local typedToken = 0
			local function useTyped()
				local digits = string.match(fpsBox.Text or "", "%d+")
				if not digits then return end
				local cap = actions.clampFpsCap(digits)
				if cap <= 0 then
					if state.isFpsCapEnabled then
						state.isFpsCapEnabled = false
						row.checkbox.Text = ""
						actions.restoreFpsCap()
					end
					state.fpsCap = 0
				else
					state.fpsCap = cap
					if not state.isFpsCapEnabled then
						state.isFpsCapEnabled = true
						row.checkbox.Text = "✓"
					end
					actions.applyFpsCap()
				end
				saveConfig()
			end
			fpsBox:GetPropertyChangedSignal("Text"):Connect(function()
				if not fpsBox:IsFocused() then return end
				typedToken = typedToken + 1
				local token = typedToken
				task.delay(1, function()
					if token == typedToken then useTyped() end
				end)
			end)
			fpsBox.FocusLost:Connect(function()
				typedToken = typedToken + 1
				useTyped()
				showBox()
			end)

			-- the frame rate now, after "fps cap"
			actions.onFpsMeasured = function(fps)
				if label and label.Parent then
					label.Text = string.format("fps cap (%d)", math.floor(fps + 0.5))
				end
			end
		end
		-- (Saved Settings sets the number after loading a file; its tick box is pressed like the others)
		local genv = (getgenv and getgenv()) or _G
		genv.BPHammer2SetFpsCap = function(value)
			local cap = actions.clampFpsCap(value)
			state.fpsCap = cap
			if state.isFpsCapEnabled and cap > 0 then actions.applyFpsCap() end
			if fpsBox and fpsBox.Parent then fpsBox.Text = cap > 0 and tostring(cap) or "" end
			saveConfig()
		end
	end

	------------------------------------------------------------
	-- OLD DECAL RENDERING BUTTON
	------------------------------------------------------------
	oldDecalBtn = scroll:FindFirstChild("BPOldDecalButton")
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
	-- UNSELECT ALL BUTTON
	-- Turns off every option in this script and in Hammer stuff 1, the same way unticking
	-- each one would (so each option puts back what it changed). Dropdowns stay open or
	-- closed as they are; only the boxes change, so the layout doesn't move.
	------------------------------------------------------------
	unselectBtn = scroll:FindFirstChild("BPUnselectAllButton")
	if unselectBtn then unselectBtn:Destroy() end

	unselectBtn = Instance.new("TextButton")
	unselectBtn.Name = "BPUnselectAllButton"
	unselectBtn.Size = UDim2.new(1, -30, 0, 36)
	unselectBtn.Position = UDim2.new(0, 15, 0, decalBtnY + 46)
	unselectBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	unselectBtn.BorderSizePixel = 0
	unselectBtn.FontFace = fontBold
	unselectBtn.TextSize = 16
	unselectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	unselectBtn.Text = "unselect all"
	unselectBtn.ZIndex = 97
	unselectBtn.AutoButtonColor = true
	unselectBtn.Parent = scroll

	local unselectCorner = Instance.new("UICorner")
	unselectCorner.CornerRadius = UDim.new(0, 6)
	unselectCorner.Parent = unselectBtn

	local unselectStroke = Instance.new("UIStroke")
	unselectStroke.Color = Color3.fromRGB(160, 160, 160)
	unselectStroke.Thickness = 1.5
	unselectStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	unselectStroke.Parent = unselectBtn

	local unselecting = false

	local function unselectAll()
		if unselecting then return end
		unselecting = true

		-- Untick everything first so the boxes update at once, then restore in order.
		local restores = {}
		for stateKey, row in pairs(rows) do
			if state[stateKey] then
				state[stateKey] = false
				row.checkbox.Text = ""
				table.insert(restores, row.spec.onDisable)
			end
		end
		if state.isOldDecalEnabled then
			state.isOldDecalEnabled = false
			refreshOldDecalBtn()
			table.insert(restores, actions.restoreOldDecal)
		end
		saveConfig()

		-- Hammer stuff 1's options (2013 skybox, remove lighting, materials, no shadows)
		local genv = (getgenv and getgenv()) or _G
		if type(genv.BPHammer1UnselectAll) == "function" then
			pcall(genv.BPHammer1UnselectAll)
		end

		task.spawn(function()
			for _, restore in ipairs(restores) do
				pcall(restore)
			end
			unselecting = false
			print("[Addon] Unselected everything.")
		end)
	end

	unselectBtn.MouseButton1Click:Connect(function()
		playClick()
		unselectAll()
	end)

	-- Put every row, the buttons, destroy button and spacer where they belong.
	relayout()

	------------------------------------------------------------
	-- APPLY SAVED STATE ON LOAD
	------------------------------------------------------------
	if state.isHealthESPEnabled then task.spawn(actions.applyHealthESP) end
	if state.isRemoveProEnabled then task.spawn(actions.applyRemovePro) end
	if state.isRemoveEffectsEnabled then task.spawn(actions.applyRemoveEffects) end
	if state.is2006LightingEnabled then task.spawn(actions.apply2006Lighting) end
	if state.isOutlineEnabled then task.spawn(actions.applyOutline) end
	if state.isLensFlareEnabled then task.spawn(actions.applyLensFlare) end
	if state.isOldAvatarEnabled then task.spawn(actions.applyOldAvatar)
	elseif state.is2006AvatarEnabled then task.spawn(actions.apply2006Avatar)
	elseif state.is2008PlayersEnabled then task.spawn(actions.apply2008Players) end
	if state.isClassicFaceEnabled then task.spawn(actions.applyClassicFace) end
	if state.is2012ColorsEnabled then task.spawn(actions.apply2012Colors)
	elseif state.is2006ColorsEnabled then task.spawn(actions.apply2006Colors)
	elseif state.is2005ColorsEnabled then task.spawn(actions.apply2005Colors) end
	if state.isOldDecalEnabled then task.spawn(actions.applyOldDecal) end
	if state.isHideGameGuiEnabled then task.spawn(actions.applyHideGameGui) end
	if state.isLegacyLightingEnabled then task.spawn(actions.applyLegacyLighting) end
	if state.isOldCameraSoundEnabled then task.spawn(actions.applyOldCameraSound) end
	if state.isOldPartSoundsEnabled then task.spawn(actions.applyOldPartSounds) end
	if state.isRemoveLeaderboardEnabled then task.spawn(actions.applyRemoveLeaderboard) end
	if state.isOldHealthBarEnabled then task.spawn(actions.applyOldHealthBar) end
	if state.is2008NightSkyEnabled then task.spawn(actions.apply2008NightSky) end
	if state.isAllPlayersEnabled then task.spawn(actions.applyAllPlayers) end
	if state.isFpsCapEnabled then task.spawn(actions.applyFpsCap) end
	if state.isHideMobileControlsEnabled then task.spawn(actions.applyHideMobileControls) end
	if state.isMobileControlsEnabled or state.isOldThumbstickEnabled then task.spawn(actions.syncMobileControls) end
	if state.isChatBarEnabled then task.spawn(actions.applyChatBar) end
	-- iw legacy lighting and / or a lighting era (one script, worked out from the saved ticks)
	task.spawn(actions.syncIWLighting)
	if state.is2013DynamicEnabled then task.spawn(actions.apply2013Dynamic) end
	if state.isOldMoonEnabled then task.spawn(actions.applyOldMoon) end
	if state.is2014ShadowsEnabled then task.spawn(actions.apply2014Shadows) end
	if state.isSlipperyWalkEnabled then task.spawn(actions.applySlipperyWalk) end
	if state.is2015AudioEnabled then task.spawn(actions.apply2015Audio)
	elseif state.is2016AudioEnabled then task.spawn(actions.apply2016Audio) end

	print("[Addon] All options loaded into GUI.")
end)