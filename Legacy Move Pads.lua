--========================================================
-- LEGACY MOVE PADS (Addtion-Scripts)
-- Roblox's DPad and Thumbpad touch controls (their ControlScript's DPad.lua and Thumbpad.lua) and tap to move, for the
-- 2015 - 2019 GUIs, whose Settings menu has a "Movement Mode" dropdown that did nothing. What the dropdown shows picks:
--   * DPad: Roblox's own DPad (its pictures, size and place): eight directions, the middle is the jump button.
--   * Thumbpad: Roblox's own Thumbpad (the thumbstick's ring with four arrows; the arrow you push towards grows), fixed
--     where the thumbstick is: put your thumb on it and push the way you want to go (the pad itself stays put).
--   * Click to Move / Tap to Move: nothing on screen but the jump button; tap the ground and Roblox's own tap to move
--     walks you there. Its location icon and path dots are hidden; a smooth plastic sphere sits exactly where the
--     location icon would be (red and flickering when there is no way there).
--   (If the client no longer has Roblox's DPad pictures, the arrows are drawn as text.)
--   * anything else (Default, Thumbstick, Dynamic Thumbstick): Roblox's own thumbstick, back as it was.
-- By hand: getgenv().BPMovePads.Set("DPad" / "Thumbpad" / "ClickToMove" / nil), .Mode()
--========================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local PathfindingService = game:GetService("PathfindingService")
local ContentProvider = game:GetService("ContentProvider")

local Env = (getgenv and getgenv()) or _G
if type(Env.BPMovePadsCleanup) == "function" then pcall(Env.BPMovePadsCleanup) end

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do task.wait() LocalPlayer = Players.LocalPlayer end

local TOUCH_SHEET = "rbxasset://textures/ui/TouchControlsSheet.png"

local conns = {}
local function track(c) table.insert(conns, c) return c end
local alive = true
local mode = nil
local moveVector = Vector3.new(0, 0, 0)
local jumpRequested = false
local gui, dpad, thumbpad = nil, nil, nil
local hidden = {} -- Roblox's own thumbstick frames hidden while something of ours is on: [frame] = was visible
local lastStickCenter = nil -- where Roblox's thumbstick is on the screen (kept for the Thumbpad and the DPad)

----------------------------------------------------------------------------------------------------
-- Roblox's own thumbstick: out of the way while a pad or tap to move is on, back as it was after
----------------------------------------------------------------------------------------------------
local function touchFrames()
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local touchGui = pg and pg:FindFirstChild("TouchGui")
	return touchGui and touchGui:FindFirstChild("TouchControlFrame")
end
local STICK_NAMES = { "ThumbstickFrame", "DynamicThumbstickFrame" }
local wantedStick -- (below)
local PAD_NAMES = { "ThumbpadFrame", "DPadFrame" }
local function noteStickCenter()
	-- (Addtion-Scripts) the old thumbstick (Mobile Controls.lua) takes the thumbstick's place when it is on: its place
	pcall(function()
		local mc = Env.BPMobileControls
		if type(mc) == "table" and type(mc.StickCenter) == "function" then
			local c = mc.StickCenter()
			if typeof(c) == "Vector2" then lastStickCenter = c end
		end
	end)
	local controls = touchFrames()
	if not controls then return end
	for _, name in ipairs(STICK_NAMES) do
		local f = controls:FindFirstChild(name)
		if f and f:IsA("GuiObject") and f.AbsoluteSize.X > 20 and f.AbsoluteSize.Y > 20 then
			lastStickCenter = f.AbsolutePosition + f.AbsoluteSize / 2
			return
		end
	end
end
-- Every jump button that isn't the DPad's own (Roblox's, Bloxy's old mobile one, Mobile Controls'): hidden while the DPad
-- is on, since the DPad's middle is the jump button (as in Roblox's own DPad). Found by name as they come in.
local jumpButtons = setmetatable({}, { __mode = "k" })
local function noteJump(d)
	if d.Name == "JumpButton" and d:IsA("GuiObject") and not (gui and d:IsDescendantOf(gui)) then
		jumpButtons[d] = true
	end
end
local function hideJumps()
	for b in pairs(jumpButtons) do
		if b.Parent and b.Visible and not (gui and b:IsDescendantOf(gui)) then
			if hidden[b] == nil then hidden[b] = true end
			b.Visible = false
		end
	end
end

-- (Addtion-Scripts) which of Roblox's two sticks is meant to be on: the game's own choice if it makes one, else the
-- player's setting. "Default" on a touch screen is the dynamic thumbstick (it used to be taken for the plain one here,
-- and both showed at once, the user found).
function wantedStick()
	local mode = nil
	pcall(function()
		local dev = LocalPlayer.DevTouchMovementMode.Name
		if dev ~= "UserChoice" then mode = dev end
	end)
	if not mode then
		pcall(function() mode = UserSettings():GetService("UserGameSettings").TouchMovementMode.Name end)
	end
	if mode == "Thumbstick" then return "ThumbstickFrame" end
	if mode == "DynamicThumbstick" or mode == "Default" then return "DynamicThumbstickFrame" end
	return nil
end

local function hideRoblox(hide)
	if not hide then
		for f, was in pairs(hidden) do
			if f.Parent then pcall(function() f.Visible = was end) end
			hidden[f] = nil
		end
	elseif mode == "DPad" then
		hideJumps()
	end
	local controls = touchFrames()
	if not controls then return end
	if hide then
		noteStickCenter()
		for _, name in ipairs(STICK_NAMES) do
			local f = controls:FindFirstChild(name)
			if f and f:IsA("GuiObject") then
				if hidden[f] == nil then hidden[f] = f.Visible end
				f.Visible = false
			end
		end
		for _, name in ipairs(PAD_NAMES) do
			local f = controls:FindFirstChild(name)
			if f and f:IsA("GuiObject") then
				if hidden[f] == nil then hidden[f] = f.Visible end
				f.Visible = false
			end
		end
	else
		-- (and only the stick that is meant to be on shows: the other one is hidden, so the two never show together)
		pcall(function()
			local wanted = wantedStick()
			if not wanted then return end
			for _, name in ipairs(STICK_NAMES) do
				local f = controls:FindFirstChild(name)
				if f and f:IsA("GuiObject") then f.Visible = (name == wanted) end
			end
		end)
	end
end

----------------------------------------------------------------------------------------------------
-- the pads: Roblox's own (their DPad.lua and Thumbpad.lua: the same pictures, sizes and arrows)
----------------------------------------------------------------------------------------------------
local DPAD_SHEET = "rbxasset://textures/ui/DPadSheet.png"
-- (if the client no longer has DPadSheet.png, its arrows are drawn as text instead, so the pads never go blank)
local dpadSheetMissing = false
local sheetUsers = {} -- [ImageLabel] = { glyph, round }
local function textArrow(image, glyph, round)
	if image:FindFirstChild("BPArrowText") then return end
	image.Image = ""
	if round then
		image.BackgroundColor3 = Color3.fromRGB(190, 190, 190)
		image.BackgroundTransparency = 0.45
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = image
		return
	end
	local l = Instance.new("TextLabel")
	l.Name = "BPArrowText"
	l.BackgroundTransparency = 1
	l.Text = glyph
	l.TextColor3 = image.ImageColor3
	l.TextTransparency = 0.1
	l.Font = Enum.Font.SourceSansBold
	l.TextScaled = true
	l.Size = UDim2.new(1, 0, 1, 0)
	l.Parent = image
end
local function sheetImage(image, glyph, round)
	sheetUsers[image] = { glyph, round }
	if dpadSheetMissing then textArrow(image, glyph, round) end
end
task.spawn(function()
	local ok = pcall(function()
		ContentProvider:PreloadAsync({ DPAD_SHEET }, function(_, status)
			if status ~= Enum.AssetFetchStatus.Success then dpadSheetMissing = true end
		end)
	end)
	if not ok then return end
	if dpadSheetMissing then
		warn("[Legacy Move Pads] this client has no DPadSheet.png: the arrows are drawn as text")
		for image, how in pairs(sheetUsers) do pcall(textArrow, image, how[1], how[2]) end
	end
end)

-- DPad (DPad.lua): eight directions, the middle jumps; where Roblox put it
local COMPASS_DIR = {
	Vector3.new(1, 0, 0),			-- E
	Vector3.new(1, 0, 1).Unit,		-- SE
	Vector3.new(0, 0, 1),			-- S
	Vector3.new(-1, 0, 1).Unit,		-- SW
	Vector3.new(-1, 0, 0),			-- W
	Vector3.new(-1, 0, -1).Unit,	-- NW
	Vector3.new(0, 0, -1),			-- N
	Vector3.new(1, 0, -1).Unit,		-- NE
}
local function buildDPad(parent)
	local frame = Instance.new("Frame")
	frame.Name = "DPadFrame"
	frame.Active = true
	frame.Visible = false
	frame.Size = UDim2.new(0, 192, 0, 192)
	frame.Position = UDim2.new(0, 10, 1, -230)
	frame.BackgroundTransparency = 1
	frame.Parent = parent

	local function createArrowLabel(name, position, size, rectOffset, rectSize, glyph, round)
		local image = Instance.new("ImageLabel")
		image.Name = name
		image.Image = DPAD_SHEET
		image.ImageRectOffset = rectOffset
		image.ImageRectSize = rectSize
		image.BackgroundTransparency = 1
		image.Size = size
		image.Position = position
		image.Parent = frame
		sheetImage(image, glyph, round)
		return image
	end
	local smArrowSize = UDim2.new(0, 23, 0, 23)
	local lgArrowSize = UDim2.new(0, 64, 0, 64)
	local smImgOffset = Vector2.new(46, 46)
	local lgImgOffset = Vector2.new(128, 128)
	createArrowLabel("BackButton", UDim2.new(0.5, -32, 1, -64), lgArrowSize, Vector2.new(0, 0), lgImgOffset, "▼")
	createArrowLabel("ForwardButton", UDim2.new(0.5, -32, 0, 0), lgArrowSize, Vector2.new(0, 258), lgImgOffset, "▲")
	createArrowLabel("LeftButton", UDim2.new(0, 0, 0.5, -32), lgArrowSize, Vector2.new(129, 129), lgImgOffset, "◀")
	createArrowLabel("RightButton", UDim2.new(1, -64, 0.5, -32), lgArrowSize, Vector2.new(0, 129), lgImgOffset, "▶")
	local jumpBtn = createArrowLabel("JumpButton", UDim2.new(0.5, -32, 0.5, -32), lgArrowSize, Vector2.new(129, 0), lgImgOffset, "", true)
	local flBtn = createArrowLabel("ForwardLeftButton", UDim2.new(0, 35, 0, 35), smArrowSize, Vector2.new(129, 258), smImgOffset, "◤")
	local frBtn = createArrowLabel("ForwardRightButton", UDim2.new(1, -55, 0, 35), smArrowSize, Vector2.new(176, 258), smImgOffset, "◥")
	flBtn.Visible = false
	frBtn.Visible = false

	track(jumpBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			jumpRequested = true
		end
	end))

	local touch = nil
	local function center()
		return Vector2.new(frame.AbsolutePosition.X + frame.AbsoluteSize.X / 2, frame.AbsolutePosition.Y + frame.AbsoluteSize.Y / 2)
	end
	local function normalizeDirection(pos)
		local jumpRadius = jumpBtn.AbsoluteSize.X / 2
		local c = center()
		local d = Vector2.new(pos.X - c.X, pos.Y - c.Y)
		if d.Magnitude > jumpRadius then
			local angle = math.atan2(d.Y, d.X)
			local octant = (math.floor(8 * angle / (2 * math.pi) + 8.5) % 8) + 1
			moveVector = COMPASS_DIR[octant]
		end
		if not flBtn.Visible and moveVector == COMPASS_DIR[7] then
			flBtn.Visible = true
			frBtn.Visible = true
		end
	end
	local function ended()
		touch = nil
		flBtn.Visible = false
		frBtn.Visible = false
		moveVector = Vector3.new(0, 0, 0)
	end
	track(frame.InputBegan:Connect(function(input)
		if touch or (input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1) then return end
		touch = input
		normalizeDirection(input.Position)
	end))
	track(frame.InputChanged:Connect(function(input)
		if input == touch then normalizeDirection(input.Position) end
	end))
	track(frame.InputEnded:Connect(function(input)
		if input == touch then ended() end
	end))
	track(GuiService.MenuOpened:Connect(function() if touch then ended() end end))
	return { frame = frame, stop = ended }
end

-- Thumbpad (Thumbpad.lua): the thumbstick's ring with four arrows; the arrow you push towards grows.
-- It stays where the thumbstick is (Roblox's own jumped to your thumb; this one's base never moves).
local function buildThumbpad(parent)
	local minAxis = math.min(parent.AbsoluteSize.X, parent.AbsoluteSize.Y)
	local isSmallScreen = minAxis <= 500
	local thumbpadSize = isSmallScreen and 70 or 120
	local position = isSmallScreen and UDim2.new(0, thumbpadSize * 1.25, 1, -thumbpadSize - 20)
		or UDim2.new(0, thumbpadSize / 2 - 10, 1, -thumbpadSize * 1.75 - 10)

	local frame = Instance.new("Frame")
	frame.Name = "ThumbpadFrame"
	frame.Visible = false
	frame.Active = true
	frame.Size = UDim2.new(0, thumbpadSize + 20, 0, thumbpadSize + 20)
	frame.Position = position
	frame.BackgroundTransparency = 1
	frame.Parent = parent

	local outerImage = Instance.new("ImageLabel")
	outerImage.Name = "OuterImage"
	outerImage.Image = TOUCH_SHEET
	outerImage.ImageRectOffset = Vector2.new(0, 0)
	outerImage.ImageRectSize = Vector2.new(220, 220)
	outerImage.BackgroundTransparency = 1
	outerImage.Size = UDim2.new(0, thumbpadSize, 0, thumbpadSize)
	outerImage.Position = UDim2.new(0, 10, 0, 10)
	outerImage.Parent = frame

	local function createArrowLabel(name, pos, size, rectOffset, rectSize, glyph)
		local image = Instance.new("ImageLabel")
		image.Name = name
		image.Image = DPAD_SHEET
		image.ImageRectOffset = rectOffset
		image.ImageRectSize = rectSize
		image.BackgroundTransparency = 1
		image.ImageColor3 = Color3.new(190 / 255, 190 / 255, 190 / 255)
		image.Size = size
		image.Position = pos
		image.Parent = outerImage
		sheetImage(image, glyph)
		return image
	end
	local smArrowSize = isSmallScreen and UDim2.new(0, 32, 0, 32) or UDim2.new(0, 64, 0, 64)
	local lgArrowSize = UDim2.new(0, smArrowSize.X.Offset * 2, 0, smArrowSize.Y.Offset * 2)
	local imgRectSize = Vector2.new(110, 110)
	local smImgOffset = isSmallScreen and -4 or -9
	local lgImgOffset = isSmallScreen and -28 or -55
	local dArrow = createArrowLabel("DownArrow", UDim2.new(0.5, -smArrowSize.X.Offset / 2, 1, lgImgOffset), smArrowSize, Vector2.new(8, 8), imgRectSize, "▼")
	local uArrow = createArrowLabel("UpArrow", UDim2.new(0.5, -smArrowSize.X.Offset / 2, 0, smImgOffset), smArrowSize, Vector2.new(8, 266), imgRectSize, "▲")
	local lArrow = createArrowLabel("LeftArrow", UDim2.new(0, smImgOffset, 0.5, -smArrowSize.Y.Offset / 2), smArrowSize, Vector2.new(137, 137), imgRectSize, "◀")
	local rArrow = createArrowLabel("RightArrow", UDim2.new(1, lgImgOffset, 0.5, -smArrowSize.Y.Offset / 2), smArrowSize, Vector2.new(8, 137), imgRectSize, "▶")

	local function doTween(guiObject, endSize, endPosition)
		pcall(function()
			guiObject:TweenSizeAndPosition(endSize, endPosition, Enum.EasingDirection.InOut, Enum.EasingStyle.Linear, 0.15, true)
		end)
	end
	local function restArrows()
		doTween(dArrow, smArrowSize, UDim2.new(0.5, -smArrowSize.X.Offset / 2, 1, lgImgOffset))
		doTween(uArrow, smArrowSize, UDim2.new(0.5, -smArrowSize.X.Offset / 2, 0, smImgOffset))
		doTween(lArrow, smArrowSize, UDim2.new(0, smImgOffset, 0.5, -smArrowSize.Y.Offset / 2))
		doTween(rArrow, smArrowSize, UDim2.new(1, lgImgOffset, 0.5, -smArrowSize.Y.Offset / 2))
	end

	local touch = nil
	local deadZone = 0.1
	local isRight, isLeft, isUp, isDown = false, false, false, false
	local vForward = Vector3.new(0, 0, -1)
	local vRight = Vector3.new(1, 0, 0)
	local function padOrigin()
		return Vector2.new(frame.AbsolutePosition.X + frame.AbsoluteSize.X / 2, frame.AbsolutePosition.Y + frame.AbsoluteSize.Y / 2)
	end
	local function doMove(pos)
		local delta = Vector2.new(pos.X, pos.Y) - padOrigin()
		local v = delta / (thumbpadSize / 2)
		local magnitude = v.Magnitude
		if magnitude < deadZone or magnitude == 0 then
			moveVector = Vector3.new(0, 0, 0)
		else
			local u = v.Unit
			moveVector = Vector3.new(u.X, 0, u.Y).Unit
		end
		local forwardDot = moveVector:Dot(vForward)
		local rightDot = moveVector:Dot(vRight)
		if forwardDot > 0.5 then
			if not isUp then
				isUp, isDown = true, false
				doTween(uArrow, lgArrowSize, UDim2.new(0.5, -smArrowSize.X.Offset, 0, smImgOffset - smArrowSize.Y.Offset * 1.5))
				doTween(dArrow, smArrowSize, UDim2.new(0.5, -smArrowSize.X.Offset / 2, 1, lgImgOffset))
			end
		elseif forwardDot < -0.5 then
			if not isDown then
				isDown, isUp = true, false
				doTween(dArrow, lgArrowSize, UDim2.new(0.5, -smArrowSize.X.Offset, 1, lgImgOffset + smArrowSize.Y.Offset / 2))
				doTween(uArrow, smArrowSize, UDim2.new(0.5, -smArrowSize.X.Offset / 2, 0, smImgOffset))
			end
		elseif isUp or isDown then
			isUp, isDown = false, false
			doTween(dArrow, smArrowSize, UDim2.new(0.5, -smArrowSize.X.Offset / 2, 1, lgImgOffset))
			doTween(uArrow, smArrowSize, UDim2.new(0.5, -smArrowSize.X.Offset / 2, 0, smImgOffset))
		end
		if rightDot > 0.5 then
			if not isRight then
				isRight, isLeft = true, false
				doTween(rArrow, lgArrowSize, UDim2.new(1, lgImgOffset + smArrowSize.X.Offset / 2, 0.5, -smArrowSize.Y.Offset))
				doTween(lArrow, smArrowSize, UDim2.new(0, smImgOffset, 0.5, -smArrowSize.Y.Offset / 2))
			end
		elseif rightDot < -0.5 then
			if not isLeft then
				isLeft, isRight = true, false
				doTween(lArrow, lgArrowSize, UDim2.new(0, smImgOffset - smArrowSize.X.Offset * 1.5, 0.5, -smArrowSize.Y.Offset))
				doTween(rArrow, smArrowSize, UDim2.new(1, lgImgOffset, 0.5, -smArrowSize.Y.Offset / 2))
			end
		elseif isLeft or isRight then
			isRight, isLeft = false, false
			doTween(lArrow, smArrowSize, UDim2.new(0, smImgOffset, 0.5, -smArrowSize.Y.Offset / 2))
			doTween(rArrow, smArrowSize, UDim2.new(1, lgImgOffset, 0.5, -smArrowSize.Y.Offset / 2))
		end
	end
	local function ended()
		moveVector = Vector3.new(0, 0, 0)
		touch = nil
		isUp, isDown, isLeft, isRight = false, false, false, false
		restArrows()
	end
	track(frame.InputBegan:Connect(function(input)
		-- (a touch that started elsewhere and slid onto the pad is not a new touch)
		if touch or (input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1)
			or input.UserInputState ~= Enum.UserInputState.Begin then
			return
		end
		touch = input
		doMove(input.Position)
	end))
	track(UserInputService.InputChanged:Connect(function(input)
		if input == touch then doMove(input.Position) end
	end))
	track(UserInputService.InputEnded:Connect(function(input)
		if input == touch then ended() end
	end))
	track(GuiService.MenuOpened:Connect(function() if touch then ended() end end))
	local size = thumbpadSize + 20
	return {
		frame = frame, stop = ended,
		setCenter = function(c)
			if not gui then return end
			-- (never out of the screen: the pad stays whole on it)
			local area = gui.AbsoluteSize
			local x = c.X - gui.AbsolutePosition.X - size / 2
			local y = c.Y - gui.AbsolutePosition.Y - size / 2
			if area.X > size and area.Y > size then
				x = math.clamp(x, 0, area.X - size)
				y = math.clamp(y, 0, area.Y - size)
			end
			frame.Position = UDim2.new(0, x, 0, y)
		end,
	}
end

local function ensureGui()
	if gui and gui.Parent then return end
	local pg = LocalPlayer:WaitForChild("PlayerGui")
	gui = Instance.new("ScreenGui")
	gui.Name = "BPLegacyMovePads"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = pg
	dpad = buildDPad(gui)
	thumbpad = buildThumbpad(gui)
end

----------------------------------------------------------------------------------------------------
-- TAP TO MOVE: Roblox's own tap to move walks you there; what it draws (its location icon, the dots of the path,
-- the failure icon) is hidden, and a smooth plastic sphere sits exactly where its location icon would be. If no path
-- can be made the sphere goes red and flickers. (If Roblox draws nothing, the tap's own spot is used.)
----------------------------------------------------------------------------------------------------
local marker = nil
local markerFor = nil   -- the waypoint of Roblox's the sphere sits on (it goes when that goes)
local markerToken = 0
local lastShownAt = -1
local function clearMarker()
	markerToken = markerToken + 1
	markerFor = nil
	if marker then pcall(function() marker:Destroy() end) marker = nil end
end
local function myHumanoid()
	local char = LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end
-- No way there: Roblox's 2015 tap to move (its ControlScript's ClickToMove, FlashRed) switched the sphere's colour every
-- 0.13 s and took it away after a second; here it switches between red and 2006's black (BrickColor "Black", the dark
-- blue-grey 2006 black, not pure black), as the user asked.
local FLASH_RED = Color3.fromRGB(255, 0, 0)      -- BrickColor "Really red"
local FLASH_BLACK = Color3.fromRGB(27, 42, 53)   -- BrickColor "Black" (2006)
local FLASH_STEP = 0.13
local FLASH_FOR = 1
local function flickerRed(sphere, token)
	local start = os.clock()
	local red = true
	while os.clock() - start < FLASH_FOR do
		sphere.Color = red and FLASH_RED or FLASH_BLACK
		red = not red
		task.wait(FLASH_STEP)
		if token ~= markerToken then return end
	end
	if token == markerToken then clearMarker() end
end
-- point: on the ground. Like Roblox's 2015 one (CreateDestinationIndicator: a 2 x 2 x 2 white ball made at the tapped
-- point itself), the sphere's middle is the spot, so it is half in the ground.
local function showMarker(point, _normal, failed, waypoint)
	clearMarker()
	lastShownAt = os.clock()
	local token = markerToken
	local sphere = Instance.new("Part")
	sphere.Name = "BPTapMarker"
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.new(2, 2, 2)
	sphere.Material = Enum.Material.SmoothPlastic
	sphere.Color = Color3.fromRGB(255, 255, 255)
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanQuery = false
	sphere.CanTouch = false
	sphere.CastShadow = false
	sphere.CFrame = CFrame.new(point)
	sphere.Parent = workspace
	marker = sphere
	markerFor = waypoint
	if failed then task.spawn(flickerRed, sphere, token) end
	return sphere, token
end

-- Roblox's display (Camera.ClickToMoveDisplay: TrailDot / EndWaypoint / FailureWaypoint parts, each drawn with an
-- ImageHandleAdornment, the two icons with a BillboardGui)
local function hideTheirs(d)
	if not alive or mode ~= "ClickToMove" or d.Name == "BPTapMarker" then return end
	pcall(function()
		if d:IsA("GuiBase3d") then d.Visible = false          -- the dots (ImageHandleAdornments) and any other adornment
		elseif d:IsA("LayerCollector") then d.Enabled = false -- the location icon / failure icon
		elseif d:IsA("BasePart") then d.LocalTransparencyModifier = 1
		elseif d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1
		elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then d.Enabled = false end
	end)
end
local function onTheirWaypoint(part)
	if mode ~= "ClickToMove" or not part:IsA("BasePart") then return end
	local failed = part.Name == "FailureWaypoint"
	if part.Name ~= "EndWaypoint" and not failed then return end
	-- (Roblox sets where it is just before it is put in; read it a moment later all the same)
	task.defer(function()
		if mode ~= "ClickToMove" or not part.Parent then return end
		local cf = part.CFrame
		showMarker(cf.Position, cf.LookVector, failed, (not failed) and part or nil)
	end)
end
local watchedDisplay = setmetatable({}, { __mode = "k" })
local function watchDisplay(model)
	if watchedDisplay[model] then return end
	watchedDisplay[model] = true
	for _, d in ipairs(model:GetDescendants()) do hideTheirs(d) end
	track(model.DescendantAdded:Connect(function(d)
		hideTheirs(d) -- at once, so they never show for a frame
		if d.Parent == model then onTheirWaypoint(d) end
	end))
	track(model.ChildRemoved:Connect(function(d)
		-- arrived (or a new tap): Roblox takes its location icon away, and the sphere goes with it
		if d == markerFor then clearMarker() end
	end))
end
local function watchCamera(cam)
	if not cam then return end
	local existing = cam:FindFirstChild("ClickToMoveDisplay")
	if existing then watchDisplay(existing) end
	track(cam.ChildAdded:Connect(function(c)
		if c.Name == "ClickToMoveDisplay" then watchDisplay(c) end
	end))
end
task.spawn(function()
	local cam = workspace.CurrentCamera
	while alive and not cam do task.wait() cam = workspace.CurrentCamera end
	watchCamera(cam)
	track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() watchCamera(workspace.CurrentCamera) end))
end)
-- (and anything Roblox changes back on its dots while they are up: a few parts, checked a few times a second)
local recheckAt = 0
track(RunService.Heartbeat:Connect(function()
	if mode ~= "ClickToMove" then return end
	local now = os.clock()
	if now < recheckAt then return end
	recheckAt = now + 0.2
	local cam = workspace.CurrentCamera
	local model = cam and cam:FindFirstChild("ClickToMoveDisplay")
	if model then
		watchDisplay(model)
		for _, d in ipairs(model:GetDescendants()) do
			if (d:IsA("GuiBase3d") and d.Visible) or (d:IsA("LayerCollector") and d.Enabled) then hideTheirs(d) end
		end
	end
end))

-- A tap Roblox drew nothing for: the sphere goes where the tap points (Roblox's own way of finding that spot), and if
-- the character isn't walking there, it is walked there.
local function tapPoint(pos)
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	local ray = camera:ScreenPointToRay(pos.X, pos.Y)
	local ignore = { camera, LocalPlayer.Character, marker }
	for _ = 1, 8 do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
		if not hit then return nil end
		-- (like Roblox's: see-through things you can walk through don't stop the tap)
		if hit.Instance.CanCollide then
			-- (a tap on another player is not a place to walk to)
			local model = hit.Instance:FindFirstAncestorOfClass("Model")
			if model and model:FindFirstChildOfClass("Humanoid") then return nil end
			return hit
		end
		table.insert(ignore, hit.Instance)
	end
	return nil
end
track(UserInputService.TouchTap:Connect(function(positions, processed)
	if mode ~= "ClickToMove" or processed then return end
	local pos = positions and positions[1]
	local humanoid = myHumanoid()
	if not (pos and humanoid) then return end
	local tappedAt = os.clock()
	task.delay(0.35, function()
		if mode ~= "ClickToMove" or lastShownAt >= tappedAt then return end
		local hit = tapPoint(pos)
		if not hit then return end
		local sphere, token = showMarker(hit.Position, hit.Normal, false, nil)
		local root = humanoid.RootPart
		local reachable = true
		if root then
			local ok, status = pcall(function()
				local path = PathfindingService:CreatePath()
				path:ComputeAsync(root.Position, hit.Position)
				return path.Status
			end)
			if ok and status ~= Enum.PathStatus.Success then reachable = false end
		end
		if token ~= markerToken or not alive then return end
		if not reachable then
			flickerRed(sphere, token)
			return
		end
		if humanoid.MoveDirection.Magnitude < 0.05 then
			pcall(function() humanoid:MoveTo(hit.Position) end)
			local done
			done = humanoid.MoveToFinished:Connect(function()
				done:Disconnect()
				if token == markerToken then clearMarker() end
			end)
		end
	end)
end))
local function hookHumanoid(humanoid)
	track(humanoid.Died:Connect(clearMarker))
end
task.spawn(function()
	local char = LocalPlayer.Character
	local h = char and (char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10))
	if h then hookHumanoid(h) end
end)
track(LocalPlayer.CharacterAdded:Connect(function(char)
	clearMarker()
	task.spawn(function()
		local h = char:WaitForChild("Humanoid", 10)
		if h then hookHumanoid(h) end
	end)
end))

----------------------------------------------------------------------------------------------------
-- the mode
----------------------------------------------------------------------------------------------------
local api = {}
function api.Set(newMode)
	if newMode ~= "DPad" and newMode ~= "Thumbpad" and newMode ~= "ClickToMove" then newMode = nil end
	if newMode == mode then return end
	mode = newMode
	moveVector = Vector3.new(0, 0, 0)
	clearMarker()
	if mode == "DPad" or mode == "Thumbpad" then ensureGui() end
	-- (Addtion-Scripts) the old thumbstick / 2013 joystick (Mobile Controls.lua) steps aside while a pad or tap to move is on
	pcall(function()
		local mc = Env.BPMobileControls
		if type(mc) == "table" and type(mc.Suspend) == "function" then mc.Suspend(mode ~= nil) end
	end)
	if mode ~= nil then noteStickCenter() end
	hideRoblox(false)
	if mode ~= nil then hideRoblox(true) end
	if dpad then dpad.stop() dpad.frame.Visible = (mode == "DPad") end
	if thumbpad then thumbpad.stop() thumbpad.frame.Visible = (mode == "Thumbpad") end
	if mode == "Thumbpad" and lastStickCenter then thumbpad.setCenter(lastStickCenter) end
	print("[Legacy Move Pads] " .. tostring(mode or "off: Roblox's own thumbstick"))
end
function api.Mode() return mode end
Env.BPMovePads = api

local stepName = "BPMovePads" .. tostring(math.random(1, 1e9))
-- (Addtion-Scripts) THE TWO STICKS NEVER TOGETHER: with the dynamic thumbstick on, the plain one sometimes showed beside
-- it (the user, in the 2017 GUI and older ones). A few times a second, if both are showing, the one not meant to be on is
-- hidden.
local nextStickCheck = 0
local function oneStickOnly()
	local now = os.clock()
	if now < nextStickCheck then return end
	nextStickCheck = now + 0.5
	local controls = touchFrames()
	if not controls then return end
	local plain, dynamic = controls:FindFirstChild("ThumbstickFrame"), controls:FindFirstChild("DynamicThumbstickFrame")
	if not (plain and dynamic and plain:IsA("GuiObject") and dynamic:IsA("GuiObject")) then return end
	if plain.Visible and dynamic.Visible then
		local wanted = wantedStick()
		if wanted == "DynamicThumbstickFrame" then plain.Visible = false
		elseif wanted == "ThumbstickFrame" then dynamic.Visible = false end
	end
end

RunService:BindToRenderStep(stepName, Enum.RenderPriority.Input.Value + 3, function()
	if mode == nil then oneStickOnly() return end
	if mode == "ClickToMove" then hideRoblox(true) return end
	local humanoid = myHumanoid()
	if not humanoid then return end
	if moveVector.Magnitude > 0 then humanoid:Move(moveVector, true) end
	if jumpRequested then
		jumpRequested = false
		humanoid.Jump = true
	end
	hideRoblox(true)
end)

----------------------------------------------------------------------------------------------------
-- The Settings menu's "Movement Mode" dropdown: what it shows picks the mode
----------------------------------------------------------------------------------------------------
local MODE_TEXT = {
	["dpad"] = "DPad", ["thumbpad"] = "Thumbpad",
	["click to move"] = "ClickToMove", ["tap to move"] = "ClickToMove", ["click-to-move"] = "ClickToMove",
	["tap-to-move"] = "ClickToMove", ["clicktomove"] = "ClickToMove",
	["thumbstick"] = false, ["default (thumbstick)"] = false, ["dynamic thumbstick"] = false, ["dynamicthumbstick"] = false,
	["default (dynamic thumbstick)"] = false, ["default (dynamicthumbstick)"] = false, ["default"] = false, ["classic"] = false,
}
local hooked = setmetatable({}, { __mode = "k" })
local function rowHasMovementMode(label)
	local p = label.Parent
	for _ = 1, 4 do
		if not p then return false end
		for _, d in ipairs(p:GetChildren()) do
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and string.find(string.lower(d.Text or ""), "movement mode", 1, true) then
				return true
			end
		end
		p = p.Parent
	end
	return false
end
local function applyText(text)
	local picked = MODE_TEXT[string.lower(text or "")]
	if picked == nil then return end
	api.Set(picked or nil)
end
local function look(obj)
	if hooked[obj] or not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then return end
	if MODE_TEXT[string.lower(obj.Text or "")] == nil then return end
	if not rowHasMovementMode(obj) then return end
	hooked[obj] = true
	track(obj:GetPropertyChangedSignal("Text"):Connect(function() applyText(obj.Text) end))
	if obj:IsA("TextLabel") then applyText(obj.Text) end
end
local function watchGui(g)
	if not g:IsA("ScreenGui") then return end
	track(g.DescendantAdded:Connect(function(d) task.defer(function() if d.Parent then look(d) end end) end))
	task.spawn(function()
		for i, d in ipairs(g:GetDescendants()) do
			pcall(look, d)
			if i % 300 == 0 then task.wait() end
		end
	end)
end
for _, holder in ipairs({ CoreGui, (gethui and gethui()) or nil }) do
	if holder then
		for _, g in ipairs(holder:GetChildren()) do
			if g.Name == "NewRobloxGui" or g.Name == "RobloxGui" then watchGui(g) end
		end
		track(holder.ChildAdded:Connect(function(g)
			task.defer(function() if g.Name == "NewRobloxGui" or g.Name == "RobloxGui" then watchGui(g) end end)
		end))
	end
end

-- (and Roblox's own setting, which its Settings menu sets: DPad, Thumbpad and ClickToMove pick ours; the rest, Roblox's thumbstick)
pcall(function()
	local settings = UserSettings():GetService("UserGameSettings")
	track(settings:GetPropertyChangedSignal("TouchMovementMode"):Connect(function()
		local name = settings.TouchMovementMode.Name
		if name == "DPad" or name == "Thumbpad" or name == "ClickToMove" then api.Set(name) else api.Set(nil) end
	end))
	local name = settings.TouchMovementMode.Name
	if name == "DPad" or name == "Thumbpad" or name == "ClickToMove" then task.defer(api.Set, name) end
end)

Env.BPMovePadsCleanup = function()
	alive = false
	pcall(function() RunService:UnbindFromRenderStep(stepName) end)
	api.Set(nil)
	hideRoblox(false)
	clearMarker()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	table.clear(conns)
	if gui then pcall(function() gui:Destroy() end) gui = nil end
	Env.BPMovePads = nil
end
-- (jump buttons, wherever they are made: noted by name as they come, and once at the start, a bit at a time)
local jumpHolders = {}
table.insert(jumpHolders, LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 10) or CoreGui)
table.insert(jumpHolders, CoreGui)
pcall(function() if gethui then local h = gethui() if h and h ~= CoreGui then table.insert(jumpHolders, h) end end end)
for _, holder in ipairs(jumpHolders) do
	if holder then
		track(holder.DescendantAdded:Connect(function(d)
			if d.Name == "JumpButton" then task.defer(function() if d.Parent then pcall(noteJump, d) end end) end
		end))
		task.spawn(function()
			local ok, all = pcall(function() return holder:GetDescendants() end)
			if not ok then return end
			for i, d in ipairs(all) do
				if d.Name == "JumpButton" then pcall(noteJump, d) end
				if i % 400 == 0 then task.wait() end
			end
		end)
	end
end
-- (the thumbstick's place is learned while it is still on screen)
task.spawn(function()
	for _ = 1, 20 do
		noteStickCenter()
		if lastStickCenter then break end
		task.wait(0.5)
	end
end)
print("[Legacy Move Pads] ready: pick DPad, Thumbpad or Click to Move as the Movement Mode in Settings.")
