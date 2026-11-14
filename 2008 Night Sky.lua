--[=[
	2008 Roblox Night Sky Effect (Night-Only Pitch-Black Sky + Classic Square Stars)
	- Permanently locks StarCount = 0 on all Sky instances so default Roblox stars never appear.
	- Daytime (06:00 - 18:00): Leaves the daytime sky untouched and hides the 2008 stars.
	- Nighttime (18:00 - 06:00): Swaps in the pitch-black 2008 night sky (StarCount = 0,
	  CelestialBodiesShown = false) and enables the classic 2008 square pixel stars.

	(Addtion-Scripts: Hammer stuff 2's "2008 night sky" loads this file and calls Cleanup2008NightSky to turn
	it off. Each sky's own star count is remembered and put back by the cleanup.)
]=]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Clean up any previously running instance of this script
if _G.Cleanup2008NightSky then
	pcall(_G.Cleanup2008NightSky)
end

-- // Configuration //
local CONFIG = {
	StarCount = 650,                         -- Number of classic 2008 square pixel stars
	SphereRadius = 1800,                     -- Distance of stars from camera (depth-tested against 3D map)
	MinPixelSize = 2,                        -- Minimum star square size in screen pixels
	MaxPixelSize = 4,                        -- Maximum star square size in screen pixels
	MinBrightness = 115,                     -- Dimmer gray stars (0-255)
	MaxBrightness = 255,                     -- Bright white stars (0-255)
	FullSphere = true,                       -- True = stars also appear below the horizon void (like 2008)

	-- Nighttime window (24-hour ClockTime: active from 17:45 to 06:15 to cover dusk/dawn star fade)
	NightStartClock = 17.75,
	NightEndClock = 6.25,

	-- Pitch-black skybox asset used only while Night is active
	BlackSkyboxAsset = "rbxassetid://264909758",
}

local RENDER_STEP_NAME = "Roblox2008NightSkyLock"
local NIGHT_SKY_NAME = "Classic2008NightSky"

local createdInstances = {}
local connections = {}
local watchedSkies = {}
local stashedDaySkies = {}
local starBillboards = {}
local originalStarCounts = {} -- (Addtion-Scripts) each sky's own star count, put back by the cleanup

-- // Helper: Check if current ClockTime is Night //
local function isNightTime(clockTime)
	return (clockTime >= CONFIG.NightStartClock) or (clockTime < CONFIG.NightEndClock)
end

-- // 1. Create the Dedicated Night-Only Pitch-Black Sky (Properties Set Before Parenting) //
local nightSky = Instance.new("Sky")
nightSky.Name = NIGHT_SKY_NAME
nightSky.CelestialBodiesShown = false
nightSky.StarCount = 0
nightSky.SkyboxBk = CONFIG.BlackSkyboxAsset
nightSky.SkyboxDn = CONFIG.BlackSkyboxAsset
nightSky.SkyboxFt = CONFIG.BlackSkyboxAsset
nightSky.SkyboxLf = CONFIG.BlackSkyboxAsset
nightSky.SkyboxRt = CONFIG.BlackSkyboxAsset
nightSky.SkyboxUp = CONFIG.BlackSkyboxAsset
table.insert(createdInstances, nightSky)

-- Force StarCount = 0 on any Sky instance so default Roblox stars can never render
local function lockZeroDefaultStars(sky)
	if not sky:IsA("Sky") then
		return
	end
	if originalStarCounts[sky] == nil and sky ~= nightSky then
		originalStarCounts[sky] = sky.StarCount
	end
	if sky.StarCount ~= 0 then
		sky.StarCount = 0
	end
	if not watchedSkies[sky] then
		watchedSkies[sky] = true
		table.insert(connections, sky:GetPropertyChangedSignal("StarCount"):Connect(function()
			if sky.StarCount ~= 0 then
				sky.StarCount = 0
			end
		end))
	end
end

for _, child in ipairs(Lighting:GetChildren()) do
	if child:IsA("Sky") then
		lockZeroDefaultStars(child)
	end
end

-- // 2. Generate 2008 Screen-Aligned Square Pixel Stars //
local function createStarfieldCarrier()
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	table.clear(starBillboards)

	local carrier = Instance.new("Part")
	carrier.Name = "Retro2008Starfield"
	carrier.Anchored = true
	carrier.CanCollide = false
	carrier.CanTouch = false
	carrier.CanQuery = false
	carrier.CastShadow = false
	carrier.Locked = true
	carrier.Transparency = 1
	carrier.Size = Vector3.new(1, 1, 1)
	carrier.CFrame = CFrame.new(camera.CFrame.Position)
	carrier.Parent = camera
	table.insert(createdInstances, carrier)

	local rng = Random.new(2008)

	for i = 1, CONFIG.StarCount do
		local u = rng:NextNumber()
		local v = rng:NextNumber()
		local theta = 2 * math.pi * u
		local zMin = CONFIG.FullSphere and -1 or -0.15
		local z = zMin + (1 - zMin) * v
		local r = math.sqrt(math.max(0, 1 - z * z))

		local dir = Vector3.new(r * math.cos(theta), z, r * math.sin(theta))

		local attachment = Instance.new("Attachment")
		attachment.Name = "Star_" .. i
		attachment.Position = dir * CONFIG.SphereRadius
		attachment.Parent = carrier

		local sizeRoll = rng:NextNumber()
		local pxSize = CONFIG.MinPixelSize
		if sizeRoll > 0.88 then
			pxSize = CONFIG.MaxPixelSize
		elseif sizeRoll > 0.45 then
			pxSize = math.min(CONFIG.MaxPixelSize, CONFIG.MinPixelSize + 1)
		end

		local gray = rng:NextInteger(CONFIG.MinBrightness, CONFIG.MaxBrightness)
		local starColor = Color3.fromRGB(gray, gray, gray)

		local billboard = Instance.new("BillboardGui")
		billboard.Name = "StarPoint"
		billboard.Adornee = attachment
		billboard.Size = UDim2.fromOffset(pxSize, pxSize)
		billboard.AlwaysOnTop = false
		billboard.LightInfluence = 0
		billboard.MaxDistance = math.huge
		billboard.ResetOnSpawn = false
		billboard.Enabled = false
		billboard.Parent = attachment

		local pixel = Instance.new("Frame")
		pixel.Name = "Pixel"
		pixel.Size = UDim2.fromScale(1, 1)
		pixel.BorderSizePixel = 0
		pixel.BackgroundColor3 = starColor
		pixel.BackgroundTransparency = 0
		pixel.Parent = billboard

		table.insert(starBillboards, billboard)
	end

	return carrier
end

local starCarrier = createStarfieldCarrier()
local currentNightState = nil

-- // 3. Toggle Night Sky & Classic Stars Strictly Based on Lighting.ClockTime //
local function updateTimeState()
	local nightActive = isNightTime(Lighting.ClockTime)

	-- Always keep default Roblox stars disabled on every Sky in Lighting
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") then
			lockZeroDefaultStars(child)
		end
	end

	if nightActive then
		-- Stash any regular daytime Sky instances out of Lighting so only the pitch-black sky renders at night
		for _, child in ipairs(Lighting:GetChildren()) do
			if child:IsA("Sky") and child ~= nightSky then
				lockZeroDefaultStars(child)
				table.insert(stashedDaySkies, child)
				child.Parent = nil
			end
		end
		if nightSky.Parent ~= Lighting then
			nightSky.Parent = Lighting
		end
	else
		-- Daytime: remove the pitch-black night sky and restore any original daytime Sky
		if nightSky.Parent ~= nil then
			nightSky.Parent = nil
		end
		for _, daySky in ipairs(stashedDaySkies) do
			if daySky then
				lockZeroDefaultStars(daySky)
				daySky.Parent = Lighting
			end
		end
		table.clear(stashedDaySkies)
	end

	if nightActive ~= currentNightState then
		currentNightState = nightActive
		for _, billboard in ipairs(starBillboards) do
			billboard.Enabled = nightActive
		end
	end
end

updateTimeState()

table.insert(connections, Lighting:GetPropertyChangedSignal("ClockTime"):Connect(updateTimeState))
table.insert(connections, Lighting.ChildAdded:Connect(function(child)
	if child:IsA("Sky") then
		lockZeroDefaultStars(child)
		if child ~= nightSky and isNightTime(Lighting.ClockTime) then
			task.defer(updateTimeState)
		end
	end
end))

-- // 4. Lock Star Sphere Position to Camera //
RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, function()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if not starCarrier or starCarrier.Parent ~= camera then
		if starCarrier then
			starCarrier:Destroy()
		end
		starCarrier = createStarfieldCarrier()
		currentNightState = nil
		updateTimeState()
	end
	if starCarrier then
		starCarrier.CFrame = CFrame.new(camera.CFrame.Position)
	end
end)

-- // Cleanup Hook for Re-Execution //
_G.Cleanup2008NightSky = function()
	pcall(function()
		RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
	end)
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	table.clear(connections)
	if nightSky and nightSky.Parent ~= nil then
		nightSky.Parent = nil
	end
	for _, daySky in ipairs(stashedDaySkies) do
		if daySky then
			daySky.Parent = Lighting
		end
	end
	table.clear(stashedDaySkies)
	for _, inst in ipairs(createdInstances) do
		if inst and inst.Parent then
			inst:Destroy()
		end
	end
	table.clear(createdInstances)
	table.clear(starBillboards)
	table.clear(watchedSkies)
	-- (Addtion-Scripts) each sky's own stars back
	for sky, count in pairs(originalStarCounts) do
		pcall(function() sky.StarCount = count end)
	end
	table.clear(originalStarCounts)
	print("[2008 Night Sky] Off: the game's sky and stars are back.")
end

-- (Addtion-Scripts) the same off switch through getgenv(), for the executors where _G isn't shared
do
	local genv = (getgenv and getgenv()) or _G
	genv.Cleanup2008NightSky = _G.Cleanup2008NightSky
end
print("[2008 Night Sky] On: a pitch-black sky and square stars at night (18:00 - 06:00).")
