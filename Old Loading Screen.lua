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
--   * "2013" (the 2013 GUIs with the old health bar off): the "Powered By ROBLOX" screen from the user's recording, over
--     the whole screen: the light texture with the vignette, a dark slanted band in the top left with "Powered By" and
--     the ROBLOX logo, the place's picture in the middle in a dark frame, the square loading thing under it (little
--     squares flying into a square that grows, then out of it as it shrinks), a dark band along the bottom with
--     "You're on your way to", the place and "By <creator>" on its right, and a grey circle with an X in the top right.
--     It shows for about 7 seconds, as on the recording.
--   * "2008": the 2008 GUI's one (2008 Gui.lua): the world hidden and the camera looking at it from afar, a see-through
--     grey box in the middle with "Connecting to Server", then "Bricks: N   Connectors: N" counting up while the world
--     comes back.
--   * "2006": the same in the 2006 GUI's font. (The loader doesn't use it: the 2006 GUI shows its own loading screen.)
--   * "2011" (the 2011 and 2012 GUIs, and the 2013 GUIs with the old health bar on): the same as 2008 in a black box
--     with white Arial letters and no edge, as the 2011 client had it (the user's video: youtu.be/7oRq9hvQQF0).
-- The GUI under it (the one picked, its health bar, backpack...) is hidden while it shows and comes back as it goes, as
-- the old GUIs only showed once the game had loaded (and none of it is drawn over the loading screen).
-- The pictures Roblox no longer ships (the 2014 logo and glow, the 2015 texture and vignette, the ROBLOX logo) come
-- from this repo's assets folder (saved with writefile and shown with getcustomasset); without those, the client's own
-- are tried.
-- The loading screen the GUI brings itself (the 2014 GUI's dark one) is taken away while this one shows (only its
-- ErrorFrame stays, for a disconnect message, and goes on top too); the loader also keeps it from ever showing.
-- The executor runs after the game has loaded, so each one shows for a few seconds and then goes.
-- Run: getgenv().OldLoadingScreen.Show("2006" / "2008" / "2011" / "2013" / "2014" / "2015" / "2016"), or set
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

local STYLES = { ["2008"] = "2008", ["2006"] = "2006", ["2011"] = "2011", ["2012"] = "2011", ["2013"] = "2013",
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

-- THE GUI UNDER IT: hidden while the loading screen shows and back when it goes (the old GUIs only showed once the game
-- had loaded, and some draw at the very top). That is the GUIs made since the loader started (it notes them in
-- getgenv().BPNewGuis: the GUI you picked, its health bar, backpack, the setup...) and any made while this shows.
-- Roblox's own and the executor's are left alone. A GUI that turns itself on meanwhile is kept off, and comes on after.
local KEEP_GUIS = {
	[GUI_NAME] = true, Custom2016LoadingGui = true,
	TopBarApp = true, RobloxGui = true, ExperienceChat = true, DevConsoleMaster = true, RobloxPromptGui = true,
	PurchasePromptApp = true, RobloxNetworkPauseNotification = true, RobloxLoadingGUI = true, RobloxLoadingGui = true,
	TeleportGui = true,
}
local function guiHolders()
	local holders = { CoreGui }
	pcall(function()
		local h = gethui and gethui()
		if h and h ~= CoreGui then table.insert(holders, h) end
	end)
	pcall(function()
		local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if pg then table.insert(holders, pg) end
	end)
	return holders
end
local function hideGuis(conns, hidden)
	local function hide(gui)
		if hidden[gui] ~= nil or not gui:IsA("ScreenGui") or KEEP_GUIS[gui.Name] then return end
		hidden[gui] = gui.Enabled == true
		pcall(function() gui.Enabled = false end)
		table.insert(conns, gui:GetPropertyChangedSignal("Enabled"):Connect(function()
			if hidden[gui] ~= nil and gui.Enabled then
				hidden[gui] = true
				pcall(function() gui.Enabled = false end)
			end
		end))
	end
	local made = genv.BPNewGuis
	if type(made) == "table" then
		for gui in pairs(made) do
			pcall(function()
				if gui.Parent then hide(gui) end
			end)
		end
	end
	for _, holder in ipairs(guiHolders()) do
		pcall(function()
			table.insert(conns, holder.ChildAdded:Connect(function(child)
				-- (looked at a moment later: the script making it may still be setting it up)
				task.defer(function()
					if child.Parent == holder then pcall(hide, child) end
				end)
			end))
		end)
	end
end
local function showGuis(hidden)
	for gui, wasOn in pairs(hidden) do
		if wasOn then
			pcall(function()
				if gui.Parent then gui.Enabled = true end
			end)
		end
	end
	table.clear(hidden)
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
	-- (sizes as measured on the user's screenshot of it on a phone: the circle 64 across, 5 from the right and 6 from
	-- the bottom, the name in 32 and the creator in 24, no outline on the words, all of it near the corners)
	local graphicsFrame = create "Frame" {
		Name = "GraphicsFrame",
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -69, 1, -70),
		Size = UDim2.new(0, 64, 0, 64),
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
		-- (in the middle of the circle, a little bigger, as in the user's screenshot; the dots grow to the right of
		-- "Loading" without moving it: the label is as wide as "Loading..." and starts where that one is centred)
		Size = UDim2.new(0, 52, 1, 0),
		Position = UDim2.new(0.5, -26, 0, 0),
		Font = Enum.Font.SourceSans,
		TextSize = 14,
		TextWrapped = false,
		TextColor3 = COLORS.WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Loading...",
		ZIndex = 2,
		Parent = graphicsFrame,
	}
	local infoFrame = create "Frame" {
		Name = "InfoFrame",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 23, 1, -156),
		Size = UDim2.new(0.4, 0, 0, 150),
		ZIndex = 2,
		Parent = blackFrame,
	}
	local placeLabel = textLabel {
		Name = "PlaceLabel", Size = UDim2.new(1, 0, 0, 120), Font = Enum.Font.SourceSans, TextWrapped = true,
		Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Bottom,
		TextStrokeTransparency = 1, Parent = infoFrame,
	}
	placeLabel.TextScaled = false
	placeLabel.TextSize = 32
	local creatorLabel = textLabel {
		Name = "CreatorLabel", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 120),
		Font = Enum.Font.SourceSans, TextWrapped = true, Text = "", TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, TextStrokeTransparency = 1, Parent = infoFrame,
	}
	creatorLabel.TextScaled = false
	creatorLabel.TextSize = 24

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
-- 2013 (the 2013 GUIs with the old health bar off): the "Powered By ROBLOX" screen of the user's recording, over the
-- whole screen (as the 2014 one). Everything is placed as measured on that recording (a 1400 x 646 screen), scaled to
-- this screen's height; what was on the right is kept as far from the right edge. It shows for about 7 seconds, as on
-- the recording, with its square loading thing going round meanwhile.
----------------------------------------------------------------------------------------------------
local REF_HEIGHT = 646
local BAND_ANGLE = math.atan(-123 / 688) -- the top band's lower edge: through (60, 123) and (748, 0)
local HOLD_2013 = 6.5
local TEXT_SCALE = 1.42 -- (Roblox draws a TextSize this much smaller than the recording's letters measured)

-- the square loading thing (measured on the recording, frame by frame): little squares fly in from the left and slow
-- down into a square in the middle, which grows as they come; it holds a moment, then little squares fly out of it to
-- the right while it shrinks, and last it goes after them. Then again (every 2.25 s).
local SQUARES = {
	period = 2.25,
	inTimes = { 0, 0.13, 0.26, 0.39, 0.52, 0.65, 0.78 }, -- (when each one sets off from the left)
	travelIn = 0.25,
	grownAt = 1.05,
	releaseAt = 1.4,
	outTimes = { 1.4, 1.52, 1.64, 1.76, 1.88 },
	travelOut = 0.2,
	shrunkAt = 1.95,
	leave = 0.17,
	small = 18, big = 72, last = 30, -- (sizes on the 646 tall recording)
	y = 514,
	color = Color3.fromRGB(33, 33, 36),
}

-- where the squares are t seconds into the loop: { x (0 - 1 across the screen), size (recording pixels) }, ...
local function squaresAt(t)
	local q = SQUARES
	t = t % q.period
	local left, middle, right = 0.045, 0.5, 0.89
	local list = {}
	for _, start in ipairs(q.inTimes) do
		if t >= start and t < start + q.travelIn then
			local p = (t - start) / q.travelIn
			local e = 1 - (1 - p) * (1 - p)
			table.insert(list, { left + (middle - left) * e, q.small })
		end
	end
	if t >= q.travelIn and t < q.grownAt then
		table.insert(list, { middle, q.small + (q.big - q.small) * (t - q.travelIn) / (q.grownAt - q.travelIn) })
	elseif t >= q.grownAt and t < q.releaseAt then
		table.insert(list, { middle, q.big })
	elseif t >= q.releaseAt and t < q.shrunkAt then
		table.insert(list, { middle, q.big + (q.last - q.big) * (t - q.releaseAt) / (q.shrunkAt - q.releaseAt) })
	elseif t >= q.shrunkAt and t < q.shrunkAt + q.leave then
		local p = (t - q.shrunkAt) / q.leave
		table.insert(list, { middle + (right - middle) * p * p, q.last - 7 * p })
	end
	for _, start in ipairs(q.outTimes) do
		if t >= start and t < start + q.travelOut then
			local p = (t - start) / q.travelOut
			local e = 1 - (1 - p) * (1 - p)
			table.insert(list, { middle + (right - middle) * e, q.small })
		end
	end
	return list
end

local function escapeRich(text)
	return (string.gsub(text, "[&<>\"']", {
		["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ["\""] = "&quot;", ["'"] = "&apos;",
	}))
end

local function build2013(screenGui)
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

	-- the dark slanted band in the top left, with its lighter edge (two turned frames)
	local topClip = create "Frame" {
		Name = "TopBand",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0, 145),
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
		AnchorPoint = Vector2.new(0.5, 0.5), Rotation = -6, ZIndex = 4, Parent = root,
	}
	local logo = create "ImageLabel" {
		Name = "Logo", BackgroundTransparency = 1, ImageTransparency = 0, Image = picture("robloxLogo"),
		ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = -7, ZIndex = 4, Parent = root,
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

	-- the square loading thing
	local squareFrames = {}
	local function squareFrame(i)
		local f = squareFrames[i]
		if not f then
			f = create "Frame" {
				Name = "LoadingSquare", BackgroundColor3 = SQUARES.color, BackgroundTransparency = 0, BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4, Parent = root,
			}
			squareFrames[i] = f
		end
		return f
	end

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
			TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0.5), RichText = true,
			ZIndex = 4, Parent = root,
		}
	end
	local onYourWay = infoLine("OnYourWayLabel", Enum.Font.SourceSans, COLORS.ON_YOUR_WAY)
	onYourWay.Text = "You're on your way to"
	local placeLabel = infoLine("PlaceLabel", Enum.Font.SourceSansBold, COLORS.PLACE)
	local creatorLabel = infoLine("CreatorLabel", Enum.Font.SourceSans, COLORS.PLACE)

	local view = { hold = HOLD_2013 }
	-- the grey circle with an X in the top right
	local closeButton = nil

	local laidOut, W, k = nil, 0, 1
	local function textSize(size)
		return math.max(8, math.floor(size * TEXT_SCALE * k + 0.5))
	end
	local function layout()
		local size = root.AbsoluteSize
		local H = size.Y
		W = size.X
		if W < 1 or H < 1 then return end
		laidOut = size
		k = H / REF_HEIGHT

		-- the top band: two big turned frames whose lower edges lie on the slanted line (and 5 under it), from the
		-- left edge of the screen
		topClip.Size = UDim2.new(1, 0, 0, math.ceil(145 * k))
		local cosA, sinA = math.cos(BAND_ANGLE), math.sin(BAND_ANGLE)
		local bw, bh = (W + H) * 2, H
		local midX = 374
		local midY = 123 + (midX - 60) * math.tan(BAND_ANGLE) -- (on the line through (60, 123))
		local function place(frame, drop)
			-- the middle of its lower edge, then its centre half its height "up" (turned)
			local mx, my = midX * k - drop * sinA, midY * k + drop * cosA
			frame.Size = UDim2.new(0, bw, 0, bh)
			frame.Position = UDim2.new(0, mx + bh / 2 * sinA, 0, my - bh / 2 * cosA)
		end
		place(band, 0)
		place(bandEdge, 5 * k)
		poweredBy.Position = UDim2.new(0, 160 * k, 0, 29 * k)
		poweredBy.Size = UDim2.new(0, 150 * k, 0, 34 * k)
		poweredBy.TextSize = textSize(24)
		logo.Position = UDim2.new(0, 199 * k, 0, 67 * k)
		logo.Size = UDim2.new(0, 226 * k, 0, 58 * k)

		pictureFrame.Position = UDim2.new(0.5, 0, 0, 287.5 * k)
		pictureFrame.Size = UDim2.new(0, 444 * k, 0, 249 * k)
		placeImage.Size = UDim2.new(1, -14 * k, 1, -14 * k)

		bottomEdge.Position = UDim2.new(0, 0, 1, -83 * k)
		bottomEdge.Size = UDim2.new(1, -123 * k, 0, 83 * k)
		bottomBand.Position = UDim2.new(0, 0, 1, -78 * k)
		bottomBand.Size = UDim2.new(1, -128 * k, 0, 78 * k)
		for _, row in ipairs({ { onYourWay, 17, 590.5 }, { placeLabel, 19, 610.5 }, { creatorLabel, 19, 630 } }) do
			row[1].Position = UDim2.new(1, -137 * k, 0, row[3] * k)
			row[1].Size = UDim2.new(0, W * 0.6, 0, 22 * k)
			row[1].TextSize = textSize(row[2])
		end

		if closeButton then closeButton:Destroy() end
		closeButton = closeIcon {
			Position = UDim2.new(1, -91 * k, 0, 29 * k), Size = math.floor(37 * k + 0.5), Color = COLORS.CLOSE_GREY,
			Thickness = math.max(1, math.floor(3 * k + 0.5)), Bar = math.max(2, math.floor(4 * k + 0.5)), ZIndex = 5,
			Parent = root,
			OnPress = function()
				if view.onClose then view.onClose() end
			end,
		}
	end

	local lastTexture = nil
	local fading = false
	local shownAt = os.clock()
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
		-- the squares
		local list = squaresAt(os.clock() - shownAt)
		for i, sq in ipairs(list) do
			local f = squareFrame(i)
			local side = sq[2] * k
			f.Position = UDim2.new(sq[1], 0, 0, SQUARES.y * k)
			f.Size = UDim2.new(0, side, 0, side)
			f.Visible = true
		end
		for i = #list + 1, #squareFrames do
			squareFrames[i].Visible = false
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
-- the 2006 GUI's font: RetroStudio's 2006 bitmap font (the same sheet and letter widths as the 2006 GUI): each letter
-- cut out of one picture (ASCII codes in a 16-wide grid of 32 x 32 cells), TextSize + 4 tall. If the picture can't be
-- loaded, the 2006 GUI's own stand-in font (Nunito ExtraBold Italic).
----------------------------------------------------------------------------------------------------
local FONT_2006_SHEET = "rbxassetid://11363842965"
local GLYPH_2006 = {}
for code, hex in ipairs({
	"1A", "1A", "1A", "1A", "1A", "1A", "1A", "1A", "1A", "60", "1A", "1A", "00", "1A", "1A", "1A", -- 1-16
	"1A", "1A", "1A", "1A", "1A", "1A", "1A", "1A", "1A", "1A", "1A", "1A", "1A", "1A", "1A", "07", -- 17-32
	"08", "09", "10", "10", "16", "13", "05", "09", "09", "0D", "10", "07", "07", "07", "0B", "10", -- 33-48
	"10", "10", "10", "10", "10", "10", "10", "10", "10", "07", "07", "0D", "10", "0D", "0D", "16", -- 49-64
	"14", "11", "11", "14", "10", "0F", "14", "14", "08", "0C", "11", "0E", "17", "14", "16", "0F", -- 65-80
	"16", "10", "0D", "0F", "14", "12", "1B", "11", "0F", "10", "09", "0B", "09", "0D", "0D", "0D", -- 81-96
	"0F", "10", "0D", "10", "0F", "09", "10", "11", "07", "07", "0E", "07", "17", "11", "10", "10", -- 97-112
	"10", "0A", "0B", "0A", "10", "0E", "17", "0E", "0E", "0D", "0B", "0D", "0B", "11", "1A", -- 113-127
}) do
	GLYPH_2006[code] = tonumber(hex, 16)
end
local font2006Failed = false

local function glyph2006(byte)
	return GLYPH_2006[byte] and byte or 1 -- (a letter the font doesn't have: a box, as the 2006 GUI)
end

-- the label's text in the 2006 font, in the middle of the label (its own text hidden under it)
local function draw2006(label, text)
	label.Text = text
	local old = label:FindFirstChild("TextContent")
	if old then old:Destroy() end
	if font2006Failed then
		label.TextTransparency = 0
		return
	end
	label.TextTransparency = 1
	local size = label.TextSize + 4
	local width = 0
	for i = 1, #text do
		width = width + GLYPH_2006[glyph2006(string.byte(text, i))] / 32 * size
	end
	local content = create "Frame" {
		Name = "TextContent",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, width, 0, size),
		Parent = label,
	}
	local x = 0
	for i = 1, #text do
		local code = glyph2006(string.byte(text, i))
		local w = GLYPH_2006[code]
		local pixels = w / 32 * size
		if code ~= 32 then
			create "ImageLabel" {
				Name = "Glyph",
				BackgroundTransparency = 1,
				Image = FONT_2006_SHEET,
				ImageColor3 = label.TextColor3,
				ImageRectOffset = Vector2.new((code * 32) % 512 + (32 - w) / 2, math.floor(code / 16) * 32),
				ImageRectSize = Vector2.new(w, 32),
				Size = UDim2.new(0, pixels, 0, size),
				Position = UDim2.new(0, x, 0, 0),
				Parent = content,
			}
		end
		x = x + pixels
	end
end

----------------------------------------------------------------------------------------------------
-- 2008 / 2006 (the 2006 GUI) and 2011 (2011 - 2013 with the old health bar): the 2008 GUI's loading (2008 Gui.lua), the
-- world hidden and the camera looking at it from afar; the box says "Connecting to Server" for 2 s, then counts the
-- bricks up while the world comes back (30 steps, 0.05 s each), holds 1.5 s and goes. 2006: the same in the 2006 GUI's
-- font. 2011: a black box, white Arial, no edge.
----------------------------------------------------------------------------------------------------
local function build2008(screenGui, style)
	local black = style == "2011"
	local bitmap = style == "2006"
	local font = black and Enum.Font.ArialBold or Enum.Font.Cartoon
	local labels = {}
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
		local label = create "TextLabel" {
			Name = name,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Font = font,
			TextSize = size,
			TextColor3 = COLORS.WHITE,
			Text = text,
			Parent = parent,
		}
		if bitmap then
			-- (the stand-in font, for when the 2006 letters can't be had)
			pcall(function()
				label.FontFace = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold,
					Enum.FontStyle.Italic)
			end)
			draw2006(label, text)
			table.insert(labels, label)
		end
		return label
	end
	local function setText(label, text)
		if bitmap then draw2006(label, text) else label.Text = text end
	end
	if bitmap and not font2006Failed then
		-- the 2006 letters' picture: if it can't be loaded, the stand-in font shows instead
		task.spawn(function()
			pcall(function()
				game:GetService("ContentProvider"):PreloadAsync({ FONT_2006_SHEET }, function(_, status)
					if status == Enum.AssetFetchStatus.Failure then
						font2006Failed = true
						for _, label in ipairs(labels) do
							pcall(draw2006, label, label.Text)
						end
					end
				end)
			end)
		end)
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
			setText(statsLabel, statsText(math.floor(totalBricks / steps * i), math.floor(targetConnectors / steps * i)))
			task.wait(0.05)
		end
		for _, entry in ipairs(parts) do showPart(entry) end
		setText(statsLabel, statsText(totalBricks, targetConnectors))
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
	-- (a year it has no screen for shows nothing: it used to fall back to the 2014 screen, which then came up over GUIs
	-- that were not 2014)
	local style = STYLES[year]
	if not style then
		print("[Old Loading Screen] no loading screen for \"" .. year .. "\"")
		return false
	end
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
	elseif style == "2008" or style == "2006" or style == "2011" then
		view = build2008(screenGui, style)
	else
		view = build2014(screenGui, style)
	end
	screenGui.Parent = guiHolder()

	local entry = { style = style }
	local stopped = false
	local hidden = {} -- the GUIs under it that were turned off (each: whether it was on)
	local hideConns = {}
	local function revealGuis()
		for _, c in ipairs(hideConns) do pcall(function() c:Disconnect() end) end
		table.clear(hideConns)
		showGuis(hidden)
	end
	function entry.stop()
		if stopped then return end
		stopped = true
		for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		table.clear(conns)
		if view.cleanup then pcall(view.cleanup) end
		pcall(function() screenGui:Destroy() end)
		revealGuis()
		if running == entry then running = nil end
	end
	running = entry

	removeOthers(conns)
	pcall(hideGuis, hideConns, hidden)
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
		-- the others show for HOLD seconds (2013: about 7, as on the recording; or until their close button is tapped),
		-- then fade, the GUI coming back under them as they go
		local finishing = false
		local function finish()
			if stopped or finishing then return end
			finishing = true
			revealGuis()
			pcall(view.fadeOut)
			entry.stop()
		end
		view.onClose = function() task.spawn(finish) end
		task.delay(view.hold or HOLD, finish)
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
