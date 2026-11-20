--========================================================
-- OLD LOADING SCREENS (Addtion-Scripts)
-- Each GUI's loading screen, drawn above everything (the GUI's top bar, menus and buttons are under it, as they were),
-- then taken away the way each one went. The loader picks one for the GUI:
--   * "2014" (the 2014 GUI and the early 2015 GUI): Roblox's own 2014 LoadingScript (by ArceusInator & Ben Tkacheff,
--     the one the user gave): black, the ROBLOX logo in the bottom right with its glow fading in and out, the place,
--     "By <creator>" and the Instances / Bricks / Connectors / Voxels counts in the bottom left, and a red circle with
--     an X in the top right (where its CloseButton was: tapping it takes the screen away). The black goes first, then
--     the logo and the text fade.
--   * "2015": the same screen on the light triangle texture (loadingTexture.png) with the dark vignette over it
--     (loadingvignette.png), as the 2015 client had it.
--   * "2016": the dark one of Roblox's 2016 LoadingScript: the dark triangle texture, the turning loading circle with
--     "Loading...", the place and "By <creator>" in the bottom left.
--   * "2013" (the 2013 GUIs with the old health bar off): the "Powered By ROBLOX" screen from the user's recording: the
--     light texture with the vignette, a dark slanted band in the top left with "Powered By" and the ROBLOX logo, the
--     place's picture in the middle in a dark frame, a dark band along the bottom with "You're on your way to", the place
--     and "By <creator>" on its right, and a grey circle with an X in the top right.
--   * "2008" (the 2006 GUI, in place of its own "Loading Character..."): the 2008 GUI's one (2008 Gui.lua): the world
--     hidden and the camera looking at it from afar, a see-through grey box in the middle with "Connecting to Server",
--     then "Bricks: N   Connectors: N" counting up while the world comes back.
--   * "2011" (the 2011 and 2012 GUIs, and the 2013 GUIs with the old health bar on): the same as 2008 in a black box
--     with white Arial letters and no edge, as the 2011 client had it (the user's video: youtu.be/7oRq9hvQQF0).
-- The pictures Roblox no longer ships (the 2014 logo and glow, the 2015 texture and vignette, the ROBLOX logo) come
-- from this repo's assets folder (saved with writefile and shown with getcustomasset); without those, the client's own
-- are tried.
-- The loading screen the GUI brings itself (the 2014 GUI's dark one) is taken away while this one shows (only its
-- ErrorFrame stays, for a disconnect message, and goes on top too); the loader also keeps it from ever showing.
-- The executor runs after the game has loaded, so each one shows for a few seconds and then goes.
-- Run: getgenv().OldLoadingScreen.Show("2008" / "2011" / "2013" / "2014" / "2015" / "2016"), or set
-- getgenv().BPLoadingScreenYear and run this file. Stop(): taken away at once. Style(): the one showing (or nil).
--========================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")

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
	-- the 2013 screen (measured on the user's recording)
	BAND = Color3.fromRGB(60, 60, 66),
	BAND_EDGE = Color3.fromRGB(118, 117, 129),
	PICTURE_EDGE = Color3.fromRGB(77, 77, 85),
	ON_YOUR_WAY = Color3.fromRGB(188, 187, 201),
	PLACE = Color3.fromRGB(222, 221, 230),
	CLOSE_GREY = Color3.fromRGB(138, 138, 138),
	-- the 2014 screen's close button
	CLOSE_RED = Color3.fromRGB(226, 35, 35),
	-- the 2008 box
	BOX_2008 = Color3.fromRGB(220, 220, 220),
}

local STYLES = { ["2008"] = "2008", ["2006"] = "2008", ["2011"] = "2011", ["2012"] = "2011", ["2013"] = "2013",
	["2014"] = "2014", ["2015"] = "2015", ["2016"] = "2016" }

-- the pictures, and what is tried when this repo's copy can't be had
local PICTURES = {
	logo = { file = "Roblox-loading2x.png", fallback = "rbxasset://textures/Roblox-loading.png" },
	glow = { file = "Roblox-loading-glow.png", fallback = "rbxasset://textures/Roblox-loading-glow.png" },
	texture = { file = "loadingTexture.png", fallback = "rbxasset://textures/loading/loadingTexture.png" },
	vignette = { file = "loadingvignette.png", fallback = "rbxasset://textures/loading/loadingvignette.png" },
	robloxLogo = { file = "roblox-logo.png", fallback = "rbxasset://textures/loading/robloxTilt.png" },
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

-- a circle with an X inside (both with rounded ends), as a button: { Position, Size (square, in pixels), Color,
-- Thickness (the circle's line), Bar (the X's lines), ZIndex, Parent, OnPress }
local function closeIcon(props)
	local size, line, bar = props.Size, props.Thickness, props.Bar
	local button = create "TextButton" {
		Name = "CloseButton",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.Position,
		Size = UDim2.new(0, size, 0, size),
		ZIndex = props.ZIndex,
		Parent = props.Parent,
	}
	-- the circle: a line round the inside of the button (a UIStroke is drawn outside its frame)
	local ring = create "Frame" {
		Name = "Circle",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(1, -line * 2, 1, -line * 2),
		ZIndex = props.ZIndex,
		Parent = button,
	}
	create "UICorner" { CornerRadius = UDim.new(0.5, 0), Parent = ring }
	create "UIStroke" { Color = props.Color, Thickness = line, Transparency = 0, Parent = ring }
	for i, angle in ipairs({ 45, -45 }) do
		local stroke = create "Frame" {
			Name = "X" .. i,
			BackgroundColor3 = props.Color,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0.5, 0, 0, bar),
			Rotation = angle,
			ZIndex = props.ZIndex,
			Parent = button,
		}
		create "UICorner" { CornerRadius = UDim.new(0.5, 0), Parent = stroke }
	end
	if props.OnPress then
		button.Activated:Connect(props.OnPress)
	end
	return button
end

-- everything under root fades out together (rate: how much a second)
local FADE_PROPS = {
	{ "GuiObject", "BackgroundTransparency" },
	{ "ImageLabel", "ImageTransparency" },
	{ "ImageButton", "ImageTransparency" },
	{ "TextLabel", "TextTransparency" },
	{ "TextLabel", "TextStrokeTransparency" },
	{ "UIStroke", "Transparency" },
}
local function fadeAll(root, rate)
	local items = {}
	local all = root:GetDescendants()
	table.insert(all, root)
	for _, d in ipairs(all) do
		for _, entry in ipairs(FADE_PROPS) do
			if d:IsA(entry[1]) then
				local ok, value = pcall(function() return d[entry[2]] end)
				if ok and type(value) == "number" and value < 1 then
					table.insert(items, { d, entry[2], value })
				end
			end
		end
	end
	local t = 0
	while t < 1 do
		t = math.min(1, t + rate * task.wait())
		for _, item in ipairs(items) do
			local base = item[3]
			pcall(function() item[1][item[2]] = base + (1 - base) * t end)
		end
	end
end

-- the place's picture (16:9): Roblox's 420 x 420 one at once, then its 768 x 432 one when that can be had (from Roblox's
-- thumbnail service, saved with writefile and shown with getcustomasset)
local function placePicture(onReady)
	onReady("rbxthumb://type=Asset&id=" .. tostring(game.PlaceId) .. "&w=420&h=420")
	local getAsset = customAsset()
	if not (getAsset and type(writefile) == "function") or game.PlaceId == 0 then return end
	task.spawn(function()
		pcall(function()
			local json = game:HttpGet("https://thumbnails.roblox.com/v1/assets?assetIds=" .. tostring(game.PlaceId)
				.. "&returnPolicy=PlaceHolder&size=768x432&format=Png&isCircular=false")
			local info = HttpService:JSONDecode(json)
			local url = info and info.data and info.data[1] and info.data[1].imageUrl
			if type(url) ~= "string" or url == "" then return end
			local data = game:HttpGet(url)
			if type(data) == "string" and #data > 64 and string.sub(data, 2, 4) == "PNG" then
				pcall(function()
					if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(ASSET_FOLDER) then
						makefolder(ASSET_FOLDER)
					end
				end)
				local path = ASSET_FOLDER .. "/placePicture" .. tostring(game.PlaceId) .. ".png"
				writefile(path, data)
				local id = getAsset(path)
				if type(id) == "string" and id ~= "" then onReady(id) end
			end
		end)
	end)
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
	local view = {}
	local closeButton = nil
	if style == "2014" then
		-- the 2014 LoadingScript's CloseButton (22 x 22, 5 from the top right): a red circle with an X in it, both with
		-- rounded ends. Tapping it takes the screen away.
		closeButton = closeIcon {
			Position = UDim2.new(1, -16, 0, 16), Size = 22, Color = COLORS.CLOSE_RED, Thickness = 2, Bar = 3, ZIndex = 10,
			Parent = blackFrame,
			OnPress = function()
				if view.onClose then view.onClose() end
			end,
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
			if closeButton then
				for _, d in ipairs(closeButton:GetDescendants()) do
					if d:IsA("UIStroke") then d.Transparency = t
					elseif d:IsA("Frame") and d.Name ~= "Circle" then d.BackgroundTransparency = t end
				end
			end
		end
		if closeButton then closeButton:Destroy() closeButton = nil end
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
-- 2013 (the 2013 GUIs with the old health bar off): the "Powered By ROBLOX" screen of the user's recording
-- Everything is placed as measured on that recording (a 646 pixel tall screen), scaled to this screen's height, inside
-- the phone's safe area as it was there; its background covers the whole screen.
----------------------------------------------------------------------------------------------------
local REF_HEIGHT = 646
local BAND_ANGLE = math.atan(-123 / 688) -- the top band's lower edge: from (0, 123) to (688, 0)

local function escapeRich(text)
	return (string.gsub(text, "[&<>\"']", {
		["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ["\""] = "&quot;", ["'"] = "&apos;",
	}))
end

local function build2013(screenGui)
	pcall(function() screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets end)
	local root = create "Frame" {
		Name = "BlackFrame",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Active = true,
		Parent = screenGui,
	}
	local background = create "Frame" {
		Name = "Background",
		BackgroundColor3 = COLORS.LIGHT,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 1,
		Parent = root,
	}
	local textureFrame = create "Frame" {
		Name = "BackgroundTextureFrame",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 1,
		Parent = background,
	}
	local vignette = create "ImageLabel" {
		Name = "Vignette",
		BackgroundTransparency = 1,
		ImageTransparency = 0,
		Image = picture("vignette"),
		ScaleType = Enum.ScaleType.Stretch,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 1,
		Parent = background,
	}

	-- the dark slanted band in the top left, with its lighter edge (two turned frames, cut off at the safe area)
	local topClip = create "Frame" {
		Name = "TopBand",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0, 140),
		ZIndex = 2,
		Parent = root,
	}
	local bandEdge = create "Frame" {
		Name = "Edge", BackgroundColor3 = COLORS.BAND_EDGE, BackgroundTransparency = 0, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), Rotation = math.deg(BAND_ANGLE), ZIndex = 2, Parent = topClip,
	}
	local band = create "Frame" {
		Name = "Band", BackgroundColor3 = COLORS.BAND, BackgroundTransparency = 0, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), Rotation = math.deg(BAND_ANGLE), ZIndex = 3, Parent = topClip,
	}
	local poweredBy = create "TextLabel" {
		Name = "PoweredBy", BackgroundTransparency = 1, Text = "Powered By", Font = Enum.Font.SourceSans,
		TextColor3 = COLORS.WHITE, TextTransparency = 0, TextXAlignment = Enum.TextXAlignment.Left,
		AnchorPoint = Vector2.new(0.5, 0.5), Rotation = -5, ZIndex = 4, Parent = root,
	}
	local logo = create "ImageLabel" {
		Name = "Logo", BackgroundTransparency = 1, ImageTransparency = 0, Image = picture("robloxLogo"),
		ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = -5, ZIndex = 4, Parent = root,
	}

	-- the place's picture in the middle, in a dark frame
	local pictureFrame = create "Frame" {
		Name = "PlacePictureFrame", BackgroundColor3 = COLORS.PICTURE_EDGE, BackgroundTransparency = 0,
		BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2, Parent = root,
	}
	local placeImage = create "ImageLabel" {
		Name = "PlacePicture", BackgroundColor3 = COLORS.BLACK, BackgroundTransparency = 0, BorderSizePixel = 0,
		ImageTransparency = 0, ScaleType = Enum.ScaleType.Crop, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0), ZIndex = 3, Parent = pictureFrame,
	}

	-- the dark band along the bottom, with its lighter edge on top and on the right
	local bottomEdge = create "Frame" {
		Name = "BottomBandEdge", BackgroundColor3 = COLORS.BAND_EDGE, BackgroundTransparency = 0, BorderSizePixel = 0,
		ZIndex = 2, Parent = root,
	}
	local bottomBand = create "Frame" {
		Name = "BottomBand", BackgroundColor3 = COLORS.BAND, BackgroundTransparency = 0, BorderSizePixel = 0,
		ZIndex = 3, Parent = root,
	}
	local function infoLine(name, font, color)
		return create "TextLabel" {
			Name = name, BackgroundTransparency = 1, Text = "", Font = font, TextColor3 = color, TextTransparency = 0,
			TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), RichText = true,
			ZIndex = 4, Parent = root,
		}
	end
	local onYourWay = infoLine("OnYourWayLabel", Enum.Font.SourceSans, COLORS.ON_YOUR_WAY)
	onYourWay.Text = "You're on your way to"
	local placeLabel = infoLine("PlaceLabel", Enum.Font.SourceSansBold, COLORS.PLACE)
	local creatorLabel = infoLine("CreatorLabel", Enum.Font.SourceSans, COLORS.PLACE)

	local view = {}
	-- the grey circle with an X in the top right
	local closeButton = nil

	local laidOut = nil
	local function layout()
		local size = root.AbsoluteSize
		local W, H = size.X, size.Y
		if W < 1 or H < 1 then return end
		laidOut = size
		local k = H / REF_HEIGHT
		-- the background over the whole screen (the root is inside the safe area)
		local viewport = size
		pcall(function() viewport = workspace.CurrentCamera.ViewportSize end)
		local pos = root.AbsolutePosition
		background.Position = UDim2.new(0, -pos.X, 0, -pos.Y)
		background.Size = UDim2.new(0, math.max(viewport.X, W + pos.X), 0, math.max(viewport.Y, H + pos.Y))

		-- the top band: two big turned frames whose lower edges lie on the slanted line (and 5 under it)
		topClip.Size = UDim2.new(1, 0, 0, math.ceil(140 * k))
		local cosA, sinA = math.cos(BAND_ANGLE), math.sin(BAND_ANGLE)
		local bw, bh = (W + H) * 2, H
		local function place(frame, drop)
			-- the middle of its lower edge, then its centre half its height "up" (turned)
			local mx, my = 344 * k - drop * sinA, 61.5 * k + drop * cosA
			frame.Size = UDim2.new(0, bw, 0, bh)
			frame.Position = UDim2.new(0, mx + bh / 2 * sinA, 0, my - bh / 2 * cosA)
		end
		place(band, 0)
		place(bandEdge, 5 * k)
		poweredBy.Position = UDim2.new(0, 100 * k, 0, 29 * k)
		poweredBy.Size = UDim2.new(0, 140 * k, 0, 28 * k)
		poweredBy.TextSize = math.max(8, math.floor(24 * k + 0.5))
		logo.Position = UDim2.new(0, 140 * k, 0, 67 * k)
		logo.Size = UDim2.new(0, 226 * k, 0, 58 * k)

		pictureFrame.Position = UDim2.new(0.5, 0, 0, 287.5 * k)
		pictureFrame.Size = UDim2.new(0, 444 * k, 0, 249 * k)
		placeImage.Size = UDim2.new(1, -14 * k, 1, -14 * k)

		bottomEdge.Position = UDim2.new(0, 0, 1, -83 * k)
		bottomEdge.Size = UDim2.new(1, -63 * k, 0, 83 * k)
		bottomBand.Position = UDim2.new(0, 0, 1, -78 * k)
		bottomBand.Size = UDim2.new(1, -68 * k, 0, 78 * k)
		local right = W - 78 * k
		for i, row in ipairs({ { onYourWay, 17 }, { placeLabel, 19 }, { creatorLabel, 19 } }) do
			row[1].Position = UDim2.new(0, right, 0, (560 + 20 * i) * k)
			row[1].Size = UDim2.new(0, W * 0.6, 0, 20 * k)
			row[1].TextSize = math.max(8, math.floor(row[2] * k + 0.5))
		end

		if closeButton then closeButton:Destroy() end
		closeButton = closeIcon {
			Position = UDim2.new(1, -31 * k, 0, 29 * k), Size = math.floor(37 * k + 0.5), Color = COLORS.CLOSE_GREY,
			Thickness = math.max(1, math.floor(3 * k + 0.5)), Bar = math.max(2, math.floor(4 * k + 0.5)), ZIndex = 5,
			Parent = root,
			OnPress = function()
				if view.onClose then view.onClose() end
			end,
		}
	end

	local lastTexture = nil
	local fading = false
	function view.step()
		if root.AbsoluteSize ~= laidOut then layout() end
		if placeLabel.Text == "" and placeName ~= "" then placeLabel.Text = escapeRich(placeName) end
		if creatorLabel.Text == "" and creatorName ~= "" then
			creatorLabel.Text = '<font color="rgb(174,173,185)">By</font>  <b>' .. escapeRich(creatorName) .. "</b>"
		end
		if not fading and textureFrame.AbsoluteSize ~= lastTexture then
			lastTexture = textureFrame.AbsoluteSize
			tileTexture(textureFrame, picture("texture"), 0)
		end
	end
	function view.picture(key, id)
		if key == "vignette" then vignette.Image = id
		elseif key == "robloxLogo" then logo.Image = id
		elseif key == "texture" then lastTexture = nil
		end
	end
	view.pictures = { "texture", "vignette", "robloxLogo" }
	placePicture(function(id)
		pcall(function() placeImage.Image = id end)
	end)
	-- everything fades together, as the 2015-2016 screens went (1.8 a second)
	function view.fadeOut()
		fading = true
		root.Active = false
		fadeAll(root, 1.8)
	end
	layout()
	return view
end

----------------------------------------------------------------------------------------------------
-- 2008 (the 2006 GUI) and 2011 (2011 - 2013 with the old health bar): the 2008 GUI's loading (2008 Gui.lua), the world
-- hidden and the camera looking at it from afar; the box says "Connecting to Server" for 2 s, then counts the bricks up
-- while the world comes back (30 steps, 0.05 s each), holds 1.5 s and goes. 2011: a black box, white Arial, no edge.
----------------------------------------------------------------------------------------------------
local function build2008(screenGui, style)
	local black = style == "2011"
	local font = black and Enum.Font.ArialBold or Enum.Font.Cartoon
	local function box(name, border)
		return create "Frame" {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, 500, 0, 160),
			BackgroundColor3 = black and COLORS.BLACK or COLORS.BOX_2008,
			-- (the 2011 one, measured on the user's video: black, about 0.3 see-through)
			BackgroundTransparency = black and 0.3 or 0.5,
			BorderColor3 = COLORS.WHITE,
			BorderSizePixel = black and 0 or border,
			Parent = screenGui,
		}
	end
	local function boxText(parent, name, size, text)
		return create "TextLabel" {
			Name = name,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Font = font,
			TextSize = size,
			TextColor3 = COLORS.WHITE,
			Text = text,
			Parent = parent,
		}
	end
	local function statsText(bricks, connectors)
		if black then
			return "Bricks:  " .. tostring(bricks) .. "    Connectors:  " .. tostring(connectors)
		end
		return "Bricks: " .. tostring(bricks) .. "   Connectors: " .. tostring(connectors)
	end

	local camera = workspace.CurrentCamera
	local player = Players.LocalPlayer
	local saved = nil -- what was changed (put back by view.cleanup)

	-- the world hidden (all but your own character) and the camera looking at it from afar, as the 2008 GUI did
	local function hideWorld()
		saved = { parts = {}, touch = nil }
		pcall(function()
			saved.cameraType = camera.CameraType
			saved.cameraSubject = camera.CameraSubject
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.new(Vector3.new(0, 30, 80), Vector3.new(0, 10, 0))
		end)
		pcall(function()
			local pg = player and player:FindFirstChildOfClass("PlayerGui")
			local touchGui = pg and pg:FindFirstChild("TouchGui")
			if touchGui and touchGui.Enabled then
				touchGui.Enabled = false
				saved.touch = touchGui
			end
		end)
		local character = player and player.Character
		pcall(function()
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("BasePart") and not (character and obj:IsDescendantOf(character)) then
					table.insert(saved.parts, { obj, obj.Transparency })
					obj.Transparency = 1
				end
			end
		end)
	end

	-- one part back (only if nothing else changed it meanwhile)
	local function showPart(entry)
		pcall(function()
			if entry[1].Transparency == 1 then entry[1].Transparency = entry[2] end
		end)
	end

	local view = { pictures = {} }
	function view.step() end
	function view.picture() end
	function view.cleanup()
		local s = saved
		saved = nil
		if not s then return end
		for _, entry in ipairs(s.parts) do showPart(entry) end
		pcall(function()
			if camera.CameraType == Enum.CameraType.Scriptable then
				local back = s.cameraType
				if back == nil or back == Enum.CameraType.Scriptable then back = Enum.CameraType.Custom end
				camera.CameraType = back
			end
			local character = player and player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			camera.CameraSubject = humanoid or s.cameraSubject
		end)
		if s.touch then pcall(function() s.touch.Enabled = true end) end
	end
	-- the whole of it (yields); isStopped() says when it was taken away
	function view.run(isStopped)
		hideWorld()
		local connecting = box("ConnectingFrame", 1)
		boxText(connecting, "ConnectingText", 22, "Connecting to Server")
		task.wait(2)
		if isStopped() then return end
		connecting:Destroy()
		local stats = box("StatsFrame", 3)
		local statsLabel = boxText(stats, "StatsText", 20, statsText(0, 0))
		local parts = saved and saved.parts or {}
		local totalBricks = #parts
		local targetConnectors = #Players:GetPlayers()
		local steps = 30
		local perStep = math.ceil(totalBricks / steps)
		local index = 1
		for i = 1, steps do
			if isStopped() then return end
			for _ = 1, perStep do
				if parts[index] then
					showPart(parts[index])
					index = index + 1
				end
			end
			statsLabel.Text = statsText(math.floor(totalBricks / steps * i), math.floor(targetConnectors / steps * i))
			task.wait(0.05)
		end
		for _, entry in ipairs(parts) do showPart(entry) end
		statsLabel.Text = statsText(totalBricks, targetConnectors)
		task.wait(1.5)
		-- (then the camera comes back to you: view.cleanup, as the screen goes)
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
	local style = STYLES[year] or "2014"
	api.Stop()

	local conns = {}
	local screenGui = create "ScreenGui" {
		Name = GUI_NAME,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 2147483647, -- above the GUI and everything else
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}
	local view
	if style == "2016" then
		view = build2016(screenGui)
	elseif style == "2013" then
		view = build2013(screenGui)
	elseif style == "2008" or style == "2011" then
		view = build2008(screenGui, style)
	else
		view = build2014(screenGui, style)
	end
	screenGui.Parent = guiHolder()

	local entry = { style = style }
	local stopped = false
	function entry.stop()
		if stopped then return end
		stopped = true
		for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		table.clear(conns)
		if view.cleanup then pcall(view.cleanup) end
		pcall(function() screenGui:Destroy() end)
		if running == entry then running = nil end
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

	if view.run then
		-- (2008 / 2011: its own steps, then it goes)
		task.spawn(function()
			pcall(view.run, function() return stopped end)
			entry.stop()
		end)
	else
		-- the others show for HOLD seconds (or until their close button is tapped), then fade
		local finishing = false
		local function finish()
			if stopped or finishing then return end
			finishing = true
			pcall(view.fadeOut)
			entry.stop()
		end
		view.onClose = function() task.spawn(finish) end
		task.delay(HOLD, finish)
	end
	print("[Old Loading Screen] the " .. style .. " loading screen")
	return true
end

-- the style showing now (nil when none is)
function api.Style()
	return running and running.style or nil
end

function api.Running()
	return running ~= nil
end

genv.OldLoadingScreen = api

if genv.BPLoadingScreenYear then
	api.Show(genv.BPLoadingScreenYear)
end
