--========================================================
-- OLD LOADING SCREENS (Addtion-Scripts)
-- The "ROBLOX" loading screen of the 2014, 2015 and 2016 GUIs, drawn above everything (the GUI's top bar, menus and
-- buttons are under it, as they were), then faded away the way each one went:
--   * 2014: Roblox's own 2014 LoadingScript (by ArceusInator & Ben Tkacheff, the one the user gave): black, the
--     ROBLOX logo in the bottom right with its glow fading in and out, the place, "By <creator>" and the Instances /
--     Bricks / Connectors / Voxels counts in the bottom left. The black goes first, then the logo and the text fade.
--   * 2015: the same screen on the light triangle texture (loadingTexture.png) with the dark vignette over it
--     (loadingvignette.png), as the 2015 client had it. (No 2015 script was given: it is put together from those two
--     pictures and the 2014 and 2016 scripts.)
--   * 2016: the dark one that the 2014 GUI used to start with (Roblox's 2016 LoadingScript): the dark triangle
--     texture, the turning loading circle with "Loading...", the place and "By <creator>" in the bottom left.
-- The pictures Roblox no longer ships (the 2014 logo and glow, the 2015 texture and vignette) come from this repo's
-- assets folder (saved with writefile and shown with getcustomasset); without those, the client's own are tried.
-- The loading screen the GUI brings itself (the 2014 GUI's dark one) is taken away while this one shows (only its
-- ErrorFrame stays, for a disconnect message, and goes on top too).
-- The executor runs after the game has loaded, so each one shows for a few seconds (HOLD) and then fades.
-- Run: getgenv().OldLoadingScreen.Show("2014" / "2015" / "2016"), or set getgenv().BPLoadingScreenYear and run this
-- file. Stop(): taken away at once.
--========================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local MarketplaceService = game:GetService("MarketplaceService")

local genv = (getgenv and getgenv()) or _G

if type(genv.OldLoadingScreen) == "table" and type(genv.OldLoadingScreen.Stop) == "function" then
	pcall(genv.OldLoadingScreen.Stop)
end

local GUI_NAME = "OldLoadingScreen"
local HOLD = 3 -- seconds it shows before fading (the 2014 GUI held its own for 3)
local OTHER_LOADING_GUIS = { Custom2016LoadingGui = true } -- (the 2014 GUI's own, Roblox's 2016 one renamed)
local ASSET_BASE = "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/assets/"
local ASSET_FOLDER = "AddtionAssets"

local COLORS = {
	BLACK = Color3.new(0, 0, 0),
	WHITE = Color3.new(1, 1, 1),
	DARK = Color3.new(45 / 255, 45 / 255, 45 / 255),
	LIGHT = Color3.new(225 / 255, 225 / 255, 225 / 255),
}

-- the pictures, and what is tried when this repo's copy can't be had
local PICTURES = {
	logo = { file = "Roblox-loading2x.png", fallback = "rbxasset://textures/Roblox-loading.png" },
	glow = { file = "Roblox-loading-glow.png", fallback = "rbxasset://textures/Roblox-loading-glow.png" },
	texture = { file = "loadingTexture.png", fallback = "rbxasset://textures/loading/loadingTexture.png" },
	vignette = { file = "loadingvignette.png", fallback = "rbxasset://textures/loading/loadingvignette.png" },
	darkTexture = { fallback = "rbxasset://textures/loading/darkLoadingTexture.png" },
	circle = { fallback = "rbxasset://textures/loading/loadingCircle.png" },
}

local running = nil -- the screen showing now: { gui, conns, stop }

----------------------------------------------------------------------------------------------------
-- pictures from this repo (cached on the executor's disk)
----------------------------------------------------------------------------------------------------
local resolved = {}
local function customAsset()
	if type(getcustomasset) == "function" then return getcustomasset end
	if type(getsynasset) == "function" then return getsynasset end
	return nil
end

-- the picture to use now (the fallback until this repo's copy is ready)
local function picture(key)
	if resolved[key] then return resolved[key] end
	return PICTURES[key].fallback
end

-- gets this repo's copies ready (yields): calls onReady(key, id) for each one found
local function fetchPictures(keys, onReady)
	local getAsset = customAsset()
	if not (getAsset and type(writefile) == "function" and type(isfile) == "function") then return end
	pcall(function()
		if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(ASSET_FOLDER) then
			makefolder(ASSET_FOLDER)
		end
	end)
	for _, key in ipairs(keys) do
		local info = PICTURES[key]
		if info.file and not resolved[key] then
			local path = ASSET_FOLDER .. "/" .. info.file
			pcall(function()
				if not isfile(path) then
					local data = game:HttpGet(ASSET_BASE .. info.file)
					-- (a PNG: a failed download is a web page)
					if type(data) == "string" and #data > 64 and string.sub(data, 2, 4) == "PNG" then
						writefile(path, data)
					end
				end
				if isfile(path) then
					local id = getAsset(path)
					if type(id) == "string" and id ~= "" then
						resolved[key] = id
						onReady(key, id)
					end
				end
			end)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------
local function create(className)
	return function(props)
		local obj = Instance.new(className)
		local parent = props.Parent
		props.Parent = nil
		for k, v in pairs(props) do
			if type(k) == "string" then
				pcall(function() obj[k] = v end)
			end
		end
		for _, child in ipairs(props) do
			child.Parent = obj
		end
		if parent then obj.Parent = parent end
		return obj
	end
end

local function guiHolder()
	local holder = CoreGui
	pcall(function()
		if gethui then holder = gethui() end
	end)
	return holder
end

local function round(num, idp)
	local mult = 10 ^ (idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

-- the place's name and creator (asked once)
local placeName, creatorName = "", ""
local function askPlaceInfo()
	task.spawn(function()
		local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
		if ok and type(info) == "table" then
			placeName = tostring(info.Name or "")
			local creator = info.Creator
			creatorName = type(creator) == "table" and tostring(creator.Name or "") or ""
		end
	end)
end

-- what the 2014 screen counts: the client counted while loading, so here the counts go up from 0 to the game's
-- while it shows
local function countWorld()
	local instances, bricks, connectors = 0, 0, 0
	pcall(function()
		local all = workspace:GetDescendants()
		instances = #all
		for _, d in ipairs(all) do
			if d:IsA("BasePart") then
				bricks = bricks + 1
			elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") then
				connectors = connectors + 1
			end
		end
	end)
	return instances, bricks, connectors
end

-- the other loading screen (the 2014 GUI's own) goes while this one shows: all of it but its ErrorFrame, which it keeps
-- for a disconnect message (that is put on top too, so it isn't under the GUI either)
local function removeOthers(conns)
	local function clear(gui)
		for _, part in ipairs(gui:GetChildren()) do
			if part.Name ~= "ErrorFrame" then pcall(function() part:Destroy() end) end
		end
	end
	local function check(child)
		if OTHER_LOADING_GUIS[child.Name] and child:IsA("ScreenGui") then
			pcall(function() child.DisplayOrder = 2147483647 end)
			clear(child)
			-- (its pieces are put in a moment after the ScreenGui itself)
			table.insert(conns, child.ChildAdded:Connect(function(part)
				if part.Name ~= "ErrorFrame" then task.defer(function() pcall(function() part:Destroy() end) end) end
			end))
		end
	end
	local holders = { CoreGui }
	pcall(function()
		local h = gethui and gethui()
		if h and h ~= CoreGui then table.insert(holders, h) end
	end)
	pcall(function()
		local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if pg then table.insert(holders, pg) end
	end)
	for _, holder in ipairs(holders) do
		pcall(function()
			for _, child in ipairs(holder:GetChildren()) do check(child) end
			table.insert(conns, holder.ChildAdded:Connect(check))
		end)
	end
end

-- a texture tiled over a frame (512 x 512 tiles, as the scripts did); tiled again when the frame's size changes
local function tileTexture(frame, image, transparency)
	frame:ClearAllChildren()
	local size = Vector2.new(512, 512)
	for i = 0, math.ceil(frame.AbsoluteSize.X / size.X) do
		for j = 0, math.ceil(frame.AbsoluteSize.Y / size.Y) do
			create "ImageLabel" {
				Name = "BackgroundTextureImage",
				BackgroundTransparency = 1,
				ImageTransparency = transparency,
				Image = image,
				Position = UDim2.new(0, i * size.X, 0, j * size.Y),
				Size = UDim2.new(0, size.X, 0, size.Y),
				ZIndex = 1,
				Parent = frame,
			}
		end
	end
end

local function textLabel(props)
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or COLORS.WHITE
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0
	props.TextScaled = true
	props.ZIndex = props.ZIndex or 2
	return create "TextLabel" (props)
end

----------------------------------------------------------------------------------------------------
-- 2014 (and 2015, on its texture): the 2014 LoadingScript's screen
----------------------------------------------------------------------------------------------------
local function build2014(screenGui, style)
	local blackFrame = create "Frame" {
		Name = "BlackFrame",
		BackgroundColor3 = style == "2015" and COLORS.LIGHT or COLORS.BLACK,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 0,
		Active = true,
		Parent = screenGui,
	}
	local textureFrame, vignette = nil, nil
	if style == "2015" then
		textureFrame = create "Frame" {
			Name = "BackgroundTextureFrame",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 1,
			Parent = blackFrame,
		}
		vignette = create "ImageLabel" {
			Name = "Vignette",
			BackgroundTransparency = 1,
			ImageTransparency = 0,
			Image = picture("vignette"),
			ScaleType = Enum.ScaleType.Stretch,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 1,
			Parent = blackFrame,
		}
	end
	local graphicsFrame = create "Frame" {
		Name = "GraphicsFrame",
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -125, 1, -125),
		Size = UDim2.new(0, 120, 0, 120),
		ZIndex = 2,
		Parent = blackFrame,
	}
	local loadingImage = create "ImageLabel" {
		Name = "LoadingImage",
		BackgroundTransparency = 1,
		ImageTransparency = 0,
		Image = picture("glow"),
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 2,
		Parent = graphicsFrame,
	}
	local logoImage = create "ImageLabel" {
		Name = "LogoImage",
		BackgroundTransparency = 1,
		ImageTransparency = 0,
		Image = picture("logo"),
		Position = UDim2.new(0.125, 0, 0.125, 0),
		Size = UDim2.new(0.75, 0, 0.75, 0),
		ZIndex = 2,
		Parent = graphicsFrame,
	}
	local countFrame = create "Frame" {
		Name = "CountFrame",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 1, -120),
		Size = UDim2.new(0.3, 0, 0, 120),
		ZIndex = 2,
		Parent = blackFrame,
	}
	local placeLabel = textLabel {
		Name = "PlaceLabel", Size = UDim2.new(1, -5, 0, 18), Position = UDim2.new(0, 5, 0, 0),
		Font = Enum.Font.SourceSansBold, TextWrapped = true, Text = "", TextXAlignment = Enum.TextXAlignment.Left,
		Parent = countFrame,
	}
	local creatorLabel = textLabel {
		Name = "CreatorLabel", Size = UDim2.new(1, -5, 0, 18), Position = UDim2.new(0, 5, 0, 18),
		Font = Enum.Font.SourceSans, TextWrapped = true, Text = "", TextXAlignment = Enum.TextXAlignment.Left,
		Parent = countFrame,
	}
	local counts = {}
	for _, row in ipairs({ { "Instance", "Instances:", 45 }, { "Brick", "Bricks:", 63 }, { "Connector", "Connectors:", 81 }, { "Voxel", "Voxels:", 99 } }) do
		textLabel {
			Name = row[1] .. "Label", Position = UDim2.new(0, 5, 0, row[3]), Size = UDim2.new(0, 85, 0, 18),
			Font = Enum.Font.SourceSansBold, Text = row[2], TextXAlignment = Enum.TextXAlignment.Right, Parent = countFrame,
		}
		counts[row[1]] = textLabel {
			Name = row[1] .. "Count", Position = UDim2.new(0, 95, 0, row[3]), Size = UDim2.new(0.5, -5, 0, 18),
			Font = Enum.Font.SourceSans, Text = "", TextXAlignment = Enum.TextXAlignment.Left, Parent = countFrame,
		}
	end

	local totalInstances, totalBricks, totalConnectors = 0, 0, 0
	task.spawn(function() totalInstances, totalBricks, totalConnectors = countWorld() end)
	local shownAt = os.clock()
	local fadeDown, lastSize = true, nil

	local view = {}
	-- every frame, as the script's RenderStepped: the place and creator, the counts, the glow fading in and out
	function view.step(dt)
		if placeLabel.Text == "" then placeLabel.Text = placeName end
		if creatorLabel.Text == "" and creatorName ~= "" then creatorLabel.Text = "By " .. creatorName end
		local share = math.clamp((os.clock() - shownAt) / (HOLD * 0.8), 0, 1)
		counts.Instance.Text = tostring(math.floor(totalInstances * share))
		counts.Brick.Text = tostring(math.floor(totalBricks * share))
		counts.Connector.Text = tostring(math.floor(totalConnectors * share))
		counts.Voxel.Text = "0"
		local fadeAmount = dt * 1.7
		if fadeDown then
			loadingImage.ImageTransparency = loadingImage.ImageTransparency - fadeAmount
			if loadingImage.ImageTransparency <= 0 then fadeDown = false end
		else
			loadingImage.ImageTransparency = loadingImage.ImageTransparency + fadeAmount
			if loadingImage.ImageTransparency >= 1 then fadeDown = true end
		end
		if textureFrame and textureFrame.AbsoluteSize ~= lastSize then
			lastSize = textureFrame.AbsoluteSize
			tileTexture(textureFrame, picture("texture"), 0)
		end
	end
	function view.picture(key, id)
		if key == "logo" then logoImage.Image = id
		elseif key == "glow" then loadingImage.Image = id
		elseif key == "vignette" and vignette then vignette.Image = id
		elseif key == "texture" and textureFrame then lastSize = nil
		end
	end
	view.pictures = style == "2015" and { "logo", "glow", "texture", "vignette" } or { "logo", "glow" }
	-- the script's fadeBackground (the black, 3.2 a second), then its fadeAndDestroyBlackFrame (the rest, 1.8 a second)
	function view.fadeOut()
		blackFrame.Active = false
		local t = 0
		while blackFrame.BackgroundTransparency < 1 do
			local dt = task.wait()
			t = math.min(1, blackFrame.BackgroundTransparency + dt * 3.2)
			blackFrame.BackgroundTransparency = t
			if textureFrame then
				for _, img in ipairs(textureFrame:GetChildren()) do img.ImageTransparency = t end
			end
			if vignette then vignette.ImageTransparency = t end
		end
		if textureFrame then textureFrame:Destroy() textureFrame = nil end
		local transparency = 0
		while transparency < 1 do
			transparency = math.min(1, transparency + 1.8 * task.wait())
			for _, child in ipairs(countFrame:GetChildren()) do
				child.TextTransparency = transparency
				child.TextStrokeTransparency = transparency
			end
			loadingImage.ImageTransparency = math.max(loadingImage.ImageTransparency, transparency)
			logoImage.ImageTransparency = transparency
		end
	end
	return view
end

----------------------------------------------------------------------------------------------------
-- 2016: the 2016 LoadingScript's dark screen (the one the 2014 GUI started with)
----------------------------------------------------------------------------------------------------
local function build2016(screenGui)
	local blackFrame = create "Frame" {
		Name = "BlackFrame",
		BackgroundColor3 = COLORS.DARK,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 0,
		Active = true,
		Parent = screenGui,
	}
	local textureFrame = create "Frame" {
		Name = "BackgroundTextureFrame",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 1,
		Parent = blackFrame,
	}
	local graphicsFrame = create "Frame" {
		Name = "GraphicsFrame",
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -225, 1, -165),
		Size = UDim2.new(0, 120, 0, 120),
		ZIndex = 2,
		Parent = blackFrame,
	}
	local loadingImage = create "ImageLabel" {
		Name = "LoadingImage",
		BackgroundTransparency = 1,
		ImageTransparency = 0,
		Rotation = 0,
		Image = picture("circle"),
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 2,
		Parent = graphicsFrame,
	}
	local loadingText = create "TextLabel" {
		Name = "LoadingText",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -56, 1, 0),
		Position = UDim2.new(0, 28, 0, 0),
		Font = Enum.Font.SourceSans,
		TextSize = 18,
		TextWrapped = true,
		TextColor3 = COLORS.WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Loading...",
		ZIndex = 2,
		Parent = graphicsFrame,
	}
	local infoFrame = create "Frame" {
		Name = "InfoFrame",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 100, 1, -150),
		Size = UDim2.new(0.4, 0, 0, 110),
		ZIndex = 2,
		Parent = blackFrame,
	}
	local placeLabel = textLabel {
		Name = "PlaceLabel", Size = UDim2.new(1, 0, 0, 80), Font = Enum.Font.SourceSans, TextWrapped = true,
		Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Bottom,
		Parent = infoFrame,
	}
	local creatorLabel = textLabel {
		Name = "CreatorLabel", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 80),
		Font = Enum.Font.SourceSans, TextWrapped = true, Text = "", TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, Parent = infoFrame,
	}

	local lastSize, dots, lastDot = nil, "...", os.clock()
	local textureTransparency = 0
	local view = { pictures = {} }
	function view.step(dt)
		if placeLabel.Text == "" then placeLabel.Text = placeName end
		if creatorLabel.Text == "" and creatorName ~= "" then creatorLabel.Text = "By " .. creatorName end
		if textureFrame.Parent and textureFrame.AbsoluteSize ~= lastSize then
			lastSize = textureFrame.AbsoluteSize
			tileTexture(textureFrame, picture("darkTexture"), textureTransparency)
		end
		-- the circle turns once in 2 s; the dots step every 0.2 s
		loadingImage.Rotation = loadingImage.Rotation + dt * 180
		if os.clock() - lastDot >= 0.2 then
			lastDot = os.clock()
			dots = dots .. "."
			if dots == "...." then dots = "" end
			loadingText.Text = "Loading" .. dots
		end
	end
	function view.picture() end
	-- the script's fadeAndDestroyBlackFrame: everything together, 1.8 a second
	function view.fadeOut()
		blackFrame.Active = false
		local transparency = 0
		while transparency < 1 do
			transparency = math.min(1, transparency + 1.8 * task.wait())
			textureTransparency = transparency
			for _, child in ipairs(infoFrame:GetChildren()) do
				child.TextTransparency = transparency
				child.TextStrokeTransparency = transparency
			end
			loadingImage.ImageTransparency = transparency
			loadingText.TextTransparency = transparency
			blackFrame.BackgroundTransparency = transparency
			for _, img in ipairs(textureFrame:GetChildren()) do img.ImageTransparency = transparency end
		end
	end
	return view
end

----------------------------------------------------------------------------------------------------
-- showing one
----------------------------------------------------------------------------------------------------
local api = {}

function api.Stop()
	local current = running
	running = nil
	if current then current.stop() end
end

function api.Show(year)
	year = tostring(year or genv.BPLoadingScreenYear or "2014")
	local style = (year == "2015" or year == "2016") and year or "2014"
	api.Stop()

	local conns = {}
	local screenGui = create "ScreenGui" {
		Name = GUI_NAME,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 2147483647, -- above the GUI and everything else
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}
	local view = (style == "2016") and build2016(screenGui) or build2014(screenGui, style)
	screenGui.Parent = guiHolder()

	local entry = {}
	local stopped = false
	function entry.stop()
		if stopped then return end
		stopped = true
		for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		table.clear(conns)
		pcall(function() screenGui:Destroy() end)
	end
	running = entry

	removeOthers(conns)
	askPlaceInfo()
	table.insert(conns, RunService.RenderStepped:Connect(function(dt)
		if not stopped then pcall(view.step, math.min(dt, 0.1)) end
	end))
	task.spawn(fetchPictures, view.pictures, function(key, id)
		if not stopped then pcall(view.picture, key, id) end
	end)

	task.delay(HOLD, function()
		if stopped then return end
		pcall(view.fadeOut)
		entry.stop()
		if running == entry then running = nil end
	end)
	print("[Old Loading Screen] the " .. style .. " loading screen")
	return true
end

function api.Running()
	return running ~= nil
end

genv.OldLoadingScreen = api

if genv.BPLoadingScreenYear then
	api.Show(genv.BPLoadingScreenYear)
end
