--[=[
	2008 Roblox Night Sky Effect (Night-Only Pitch-Black Sky + Classic Square Stars)
	- Permanently locks StarCount = 0 on all Sky instances so default Roblox stars never appear.
	- Daytime (06:00 - 18:00): Leaves the daytime sky untouched and hides the 2008 stars.
	- Nighttime (18:00 - 06:00): Swaps in the pitch-black 2008 night sky (StarCount = 0,
	  CelestialBodiesShown = false) and enables the classic 2008 square pixel stars.

	(Addtion-Scripts: Hammer stuff 2's "2008 night sky" loads this file and calls Cleanup2008NightSky to turn
	it off. Each sky's own star count is remembered and put back by the cleanup. The night sky is plain
	black: the picture it used before had mountains in it.
	It fades in at sunset (17:30 - 18:15) and out at sunrise (05:45 - 06:30) instead of switching all at
	once: a layer just behind the stars (a box of panels around the camera, further out than the stars)
	darkens the game's own sky, deep twilight blue first, then black, and the 2008 stars come out one by one,
	the brightest first. Once it is fully dark the black sky takes over and the panels are put away; at
	sunrise it runs the other way.
	The change takes at least a few seconds (TransitionTime): when a game jumps its clock straight from day to
	night, or this is turned on at night, the whole transition plays instead of a snap.)
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

	-- (Addtion-Scripts) sunset and sunrise fades (24-hour ClockTime): fully night from DuskEnd to DawnStart
	DuskStart = 17.5,   -- 17:30 the stars and the black start fading in
	DuskEnd = 18.25,    -- 18:15 fully night
	DawnStart = 5.75,   -- 05:45 the night starts fading out
	DawnEnd = 6.5,      -- 06:30 fully day
	FadeDistance = 1900, -- the black panels: just further out than the stars (SphereRadius)
	TransitionTime = 6,  -- (seconds) the quickest the whole change to night (or back) is shown
	StarWindow = 0.2,    -- each star fades in over this part of the transition (at its own moment)
	Twilight = Color3.fromRGB(24, 32, 78), -- the sky's colour on its way to black

	-- Pitch-black skybox asset used only while Night is active
	-- (Addtion-Scripts) 264909758 was a purple night picture with mountains, so a mountain sky showed every
	-- night; 163866766 is a plain black image ("Black Solid Color 500x500")
	BlackSkyboxAsset = "rbxassetid://163866766",
}

local RENDER_STEP_NAME = "Roblox2008NightSkyLock"
local NIGHT_SKY_NAME = "Classic2008NightSky"

local createdInstances = {}
local connections = {}
local watchedSkies = {}
local stashedDaySkies = {}
local starBillboards = {}
local starPixels = {}  -- (Addtion-Scripts) each star's square, faded in and out
local fadePanels = {}  -- (Addtion-Scripts) the black panels' SurfaceGuis
local fadeFrames = {}  -- their black fill, faded in and out
local fadeOffsets = {} -- each panel's place around the camera
local originalStarCounts = {} -- (Addtion-Scripts) each sky's own star count, put back by the cleanup
local starMoment = {}  -- (Addtion-Scripts) when each star comes out (0 - 1 of the transition)
local starLevel = {}   -- how far each star is faded in now (0 - STAR_STEPS)
local STAR_STEPS = 6

-- // Helper: how far into the night the clock is: 0 = day, 1 = night, in between while it fades //
local function nightAmount(clockTime)
	local duskStart, duskEnd = CONFIG.DuskStart, CONFIG.DuskEnd
	local dawnStart, dawnEnd = CONFIG.DawnStart, CONFIG.DawnEnd
	if clockTime >= duskEnd or clockTime < dawnStart then
		return 1
	elseif clockTime >= duskStart then
		return (clockTime - duskStart) / (duskEnd - duskStart)
	elseif clockTime < dawnEnd then
		return 1 - (clockTime - dawnStart) / (dawnEnd - dawnStart)
	end
	return 0
end

-- // Helper: Check if current ClockTime is fully Night //
local function isNightTime(clockTime)
	return nightAmount(clockTime) >= 1
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
	table.clear(starPixels)
	table.clear(starMoment)
	table.clear(starLevel)
	table.clear(fadePanels)
	table.clear(fadeFrames)
	table.clear(fadeOffsets)

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
		table.insert(starPixels, pixel)
		-- (Addtion-Scripts) the brightest come out first, as at dusk, with a little randomness
		local brightness = (gray - CONFIG.MinBrightness) / math.max(1, CONFIG.MaxBrightness - CONFIG.MinBrightness)
		local moment = (1 - brightness) * 0.6 + rng:NextNumber() * 0.4
		table.insert(starMoment, moment * (1 - CONFIG.StarWindow))
		table.insert(starLevel, 0)
	end

	-- (Addtion-Scripts) the fade: a box of black panels around the camera, further out than the stars, so
	-- the stars show in front of it and it covers the game's sky behind them. SurfaceGuis are used (on
	-- see-through parts) because fog doesn't cover them; each side is 2 x 2 panels (a part can't be
	-- bigger than 2048). They are only on while it fades.
	local R = CONFIG.FadeDistance
	local tile = R + 10 -- a little overlap, so no seams
	for _, normal in ipairs({
		Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 1, 0),
		Vector3.new(0, -1, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
	}) do
		local u = (normal.X ~= 0) and Vector3.new(0, 1, 0) or Vector3.new(1, 0, 0)
		local v = normal:Cross(u) -- u x v = normal, so the panel's Front side faces the camera
		for _, a in ipairs({ -1, 1 }) do
			for _, b in ipairs({ -1, 1 }) do
				local centre = normal * R + u * (a * R / 2) + v * (b * R / 2)
				local panel = Instance.new("Part")
				panel.Name = "NightFadePanel"
				panel.Anchored = true
				panel.CanCollide = false
				panel.CanTouch = false
				panel.CanQuery = false
				panel.CastShadow = false
				panel.Locked = true
				panel.Transparency = 1
				panel.Size = Vector3.new(tile, tile, 1)
				local offset = CFrame.fromMatrix(centre, u, v)
				panel.CFrame = CFrame.new(camera.CFrame.Position) * offset
				panel.Parent = carrier

				local surface = Instance.new("SurfaceGui")
				surface.Name = "NightFade"
				surface.Face = Enum.NormalId.Front
				surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				surface.PixelsPerStud = 0.05
				surface.LightInfluence = 0
				surface.AlwaysOnTop = false
				surface.Enabled = false
				surface.Adornee = panel
				surface.Parent = panel

				local fill = Instance.new("Frame")
				fill.Name = "Black"
				fill.Size = UDim2.fromScale(1, 1)
				fill.BorderSizePixel = 0
				fill.BackgroundColor3 = Color3.new(0, 0, 0)
				fill.BackgroundTransparency = 1
				fill.Parent = surface

				table.insert(fadePanels, surface)
				table.insert(fadeFrames, fill)
				table.insert(fadeOffsets, { panel = panel, offset = offset })
			end
		end
	end

	return carrier
end

local starCarrier = createStarfieldCarrier()
local currentNightState = nil
local currentStarAmount = nil -- (Addtion-Scripts) the amount the stars were last set for
local currentFadeStep = nil  -- the panels' fade, in 60 steps (0 = put away)
local shownAmount = 0        -- how far into the night it is shown (moves towards targetAmount)
local targetAmount = 0       -- how far into the night the clock is

-- (Addtion-Scripts) the stars for an amount from 0 (none) to 1 (all of them): each one fades in over its own
-- part of the transition, so they come out one by one. Only the stars whose step changes are touched.
local function setStars(amount)
	if amount == currentStarAmount then return end
	currentStarAmount = amount
	local window = CONFIG.StarWindow
	for i, billboard in ipairs(starBillboards) do
		local level = math.floor((amount - (starMoment[i] or 0)) / window * STAR_STEPS + 0.5)
		level = math.clamp(level, 0, STAR_STEPS)
		if amount >= 1 then level = STAR_STEPS elseif amount <= 0 then level = 0 end
		if level ~= starLevel[i] then
			starLevel[i] = level
			billboard.Enabled = level > 0
			local pixel = starPixels[i]
			if pixel then pixel.BackgroundTransparency = 1 - level / STAR_STEPS end
		end
	end
end

-- the panels: amount from 0 to 1 while it changes (deep blue to black, see-through to solid); anything else
-- puts them away
local BLACK = Color3.new(0, 0, 0)
local function setFade(amount)
	local step = (amount > 0 and amount < 1) and math.max(1, math.floor(amount * 60 + 0.5)) or 0
	if step == currentFadeStep then return end
	local wasOn = currentFadeStep ~= nil and currentFadeStep > 0
	currentFadeStep = step
	local on = step > 0
	local a = step / 60
	local transparency = 1 - math.min(1, a * 1.1)
	local color = CONFIG.Twilight:Lerp(BLACK, math.clamp((a - 0.25) / 0.65, 0, 1))
	for i, surface in ipairs(fadePanels) do
		if surface.Enabled ~= on then surface.Enabled = on end
		local fill = fadeFrames[i]
		if fill then
			fill.BackgroundTransparency = transparency
			fill.BackgroundColor3 = color
		end
	end
	-- (they follow the camera only while on: put around it now, before they show)
	if on and not wasOn then
		local camera = Workspace.CurrentCamera
		if camera then
			local around = CFrame.new(camera.CFrame.Position)
			for _, entry in ipairs(fadeOffsets) do entry.panel.CFrame = around * entry.offset end
		end
	end
end

-- // 3. Toggle Night Sky & Classic Stars Strictly Based on Lighting.ClockTime //
-- (Addtion-Scripts) what is shown for the amount shown now: the black sky once it is fully night, the
-- stars and the panels while it changes
local function applyShown()
	local amount = shownAmount
	local nightActive = amount >= 1

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

	currentNightState = nightActive
	-- (Addtion-Scripts) the stars come out over sunset and go over sunrise; the panels cover the game's
	-- sky while it changes (once fully night the black sky itself is up, so they are put away)
	setStars(amount)
	setFade(nightActive and 0 or amount)
end

-- the clock: where the night is going to (the render step below moves what is shown there, no quicker than
-- TransitionTime for the whole change)
local function updateTimeState()
	targetAmount = nightAmount(Lighting.ClockTime)
end

updateTimeState()
applyShown()

table.insert(connections, Lighting:GetPropertyChangedSignal("ClockTime"):Connect(updateTimeState))
table.insert(connections, Lighting.ChildAdded:Connect(function(child)
	if child:IsA("Sky") then
		lockZeroDefaultStars(child)
		if child ~= nightSky and shownAmount >= 1 then
			task.defer(applyShown)
		end
	end
end))

-- // 4. Lock Star Sphere Position to Camera //
RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
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
		currentStarAmount = nil
		currentFadeStep = nil
		updateTimeState()
		applyShown()
	end
	-- (Addtion-Scripts) the transition: what is shown moves towards the clock's amount
	if shownAmount ~= targetAmount then
		local step = math.min(deltaTime or (1 / 60), 0.25) / CONFIG.TransitionTime
		if targetAmount > shownAmount then
			shownAmount = math.min(targetAmount, shownAmount + step)
		else
			shownAmount = math.max(targetAmount, shownAmount - step)
		end
		applyShown()
	end
	if starCarrier then
		local around = CFrame.new(camera.CFrame.Position)
		starCarrier.CFrame = around
		-- (Addtion-Scripts) the black panels follow the camera only while they are on
		if currentFadeStep and currentFadeStep > 0 then
			for _, entry in ipairs(fadeOffsets) do
				entry.panel.CFrame = around * entry.offset
			end
		end
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
	table.clear(starPixels)
	table.clear(starMoment)
	table.clear(starLevel)
	table.clear(fadePanels)
	table.clear(fadeFrames)
	table.clear(fadeOffsets)
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
print("[2008 Night Sky] On: a pitch-black sky and square stars at night. At sunset (17:30 - 18:15) the sky"
	.. " goes deep blue, then black, and the stars come out one by one (at least " .. CONFIG.TransitionTime
	.. " seconds, also when the clock jumps to night); at sunrise (05:45 - 06:30) the other way.")
