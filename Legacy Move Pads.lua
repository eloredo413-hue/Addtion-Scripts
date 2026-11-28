--========================================================
-- LEGACY MOVE PADS (Addtion-Scripts)
-- Roblox's DPad and Thumbpad touch controls (their ControlScript's DPad.lua and Thumbpad.lua) and tap to move, for the
-- 2015 - 2019 GUIs, whose Settings menu has a "Movement Mode" dropdown that did nothing. What the dropdown shows picks:
--   * DPad: eight directions on a round pad, the middle is the jump button. Drawn here (its own arrows), at the thumbstick's place.
--   * Thumbpad: the same ring as the thumbstick's, fixed where the thumbstick is: put your thumb on it and push the way you
--     want to go (the pad itself stays put); the arrow that way lights up.
--   * Click to Move / Tap to Move: nothing on screen but the jump button; tap the ground to walk there (a sphere shows where;
--     it goes red and flickers when there is no way there).
--   * anything else (Default, Thumbstick, Dynamic Thumbstick): Roblox's own thumbstick, back as it was.
-- By hand: getgenv().BPMovePads.Set("DPad" / "Thumbpad" / "ClickToMove" / nil), .Mode()
--========================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local PathfindingService = game:GetService("PathfindingService")

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
local PAD_NAMES = { "ThumbpadFrame", "DPadFrame" }
local function noteStickCenter()
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
local function hideRoblox(hide)
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
		for f, was in pairs(hidden) do
			if f.Parent then pcall(function() f.Visible = was end) end
			hidden[f] = nil
		end
		-- (and the one the player's own setting shows is shown, whatever it was found as)
		pcall(function()
			local settings = UserSettings():GetService("UserGameSettings")
			local name = settings.TouchMovementMode.Name
			local wanted = (name == "DynamicThumbstick") and "DynamicThumbstickFrame"
				or ((name == "Default" or name == "Thumbstick") and "ThumbstickFrame" or nil)
			local f = wanted and controls:FindFirstChild(wanted)
			if f and f:IsA("GuiObject") and not f.Visible then f.Visible = true end
		end)
	end
end

----------------------------------------------------------------------------------------------------
-- the pads, drawn here
----------------------------------------------------------------------------------------------------
local ARROW_LIT = Color3.fromRGB(255, 255, 255)
local ARROW_DIM = Color3.fromRGB(190, 190, 190)

local function ring(parent, size)
	local outer = Instance.new("ImageLabel")
	outer.Name = "OuterImage"
	outer.Image = TOUCH_SHEET
	outer.ImageRectOffset = Vector2.new(0, 0)
	outer.ImageRectSize = Vector2.new(220, 220)
	outer.BackgroundTransparency = 1
	outer.Size = UDim2.new(0, size, 0, size)
	outer.Parent = parent
	return outer
end
local function arrowLabel(parent, glyph, position, size)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = glyph
	l.TextColor3 = ARROW_DIM
	l.TextTransparency = 0.15
	l.Font = Enum.Font.SourceSansBold
	l.TextScaled = true
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = position
	l.Size = size
	l.Active = false
	l.Parent = parent
	return l
end

-- DPad: eight directions; the middle jumps
local COMPASS_DIR = {
	Vector3.new(1, 0, 0), Vector3.new(1, 0, 1).Unit, Vector3.new(0, 0, 1), Vector3.new(-1, 0, 1).Unit,
	Vector3.new(-1, 0, 0), Vector3.new(-1, 0, -1).Unit, Vector3.new(0, 0, -1), Vector3.new(1, 0, -1).Unit,
}
local function buildDPad(parent)
	local SIZE = 192
	local frame = Instance.new("Frame")
	frame.Name = "DPadFrame"
	frame.Active = true
	frame.Visible = false
	frame.Size = UDim2.new(0, SIZE, 0, SIZE)
	frame.Position = UDim2.new(0, 10, 1, -SIZE - 20)
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	ring(frame, SIZE)
	local fwd = arrowLabel(frame, "▲", UDim2.new(0.5, 0, 0.14, 0), UDim2.new(0, 44, 0, 44))
	local back = arrowLabel(frame, "▼", UDim2.new(0.5, 0, 0.86, 0), UDim2.new(0, 44, 0, 44))
	local left = arrowLabel(frame, "◀", UDim2.new(0.14, 0, 0.5, 0), UDim2.new(0, 44, 0, 44))
	local right = arrowLabel(frame, "▶", UDim2.new(0.86, 0, 0.5, 0), UDim2.new(0, 44, 0, 44))
	local jumpBtn = Instance.new("TextButton")
	jumpBtn.Name = "JumpButton"
	jumpBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	jumpBtn.Position = UDim2.new(0.5, 0, 0.5, 0)
	jumpBtn.Size = UDim2.new(0, 56, 0, 56)
	jumpBtn.BackgroundColor3 = Color3.fromRGB(170, 170, 170)
	jumpBtn.BackgroundTransparency = 0.5
	jumpBtn.Text = ""
	jumpBtn.AutoButtonColor = false
	jumpBtn.Parent = frame
	local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(1, 0) corner.Parent = jumpBtn
	local lights = { [1] = right, [3] = back, [5] = left, [7] = fwd }
	local function light(octant)
		for _, l in ipairs({ fwd, back, left, right }) do l.TextColor3 = ARROW_DIM end
		if not octant then return end
		-- (the diagonals light the two arrows beside them)
		if lights[octant] then lights[octant].TextColor3 = ARROW_LIT
		elseif octant == 2 then right.TextColor3 = ARROW_LIT back.TextColor3 = ARROW_LIT
		elseif octant == 4 then left.TextColor3 = ARROW_LIT back.TextColor3 = ARROW_LIT
		elseif octant == 6 then left.TextColor3 = ARROW_LIT fwd.TextColor3 = ARROW_LIT
		elseif octant == 8 then right.TextColor3 = ARROW_LIT fwd.TextColor3 = ARROW_LIT end
	end
	local touch = nil
	local function center()
		return Vector2.new(frame.AbsolutePosition.X + frame.AbsoluteSize.X / 2, frame.AbsolutePosition.Y + frame.AbsoluteSize.Y / 2)
	end
	local function normalize(pos)
		local c = center()
		local d = Vector2.new(pos.X - c.X, pos.Y - c.Y)
		if d.Magnitude > jumpBtn.AbsoluteSize.X / 2 then
			local angle = math.atan2(d.Y, d.X)
			local octant = (math.floor(8 * angle / (2 * math.pi) + 8.5) % 8) + 1
			moveVector = COMPASS_DIR[octant]
			light(octant)
		end
	end
	local function ended()
		touch = nil
		moveVector = Vector3.new(0, 0, 0)
		light(nil)
	end
	track(jumpBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			jumpRequested = true
		end
	end))
	track(frame.InputBegan:Connect(function(input)
		if touch or (input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1) then return end
		touch = input
		normalize(input.Position)
	end))
	track(frame.InputChanged:Connect(function(input)
		if input == touch then normalize(input.Position) end
	end))
	track(frame.InputEnded:Connect(function(input)
		if input == touch then ended() end
	end))
	track(GuiService.MenuOpened:Connect(function() if touch then ended() end end))
	return {
		frame = frame, stop = ended, size = SIZE,
		setCenter = function(c)
			if not gui then return end
			frame.Position = UDim2.new(0, c.X - gui.AbsolutePosition.X - SIZE / 2, 0, c.Y - gui.AbsolutePosition.Y - SIZE / 2)
		end,
	}
end

-- Thumbpad: fixed where the thumbstick is; push the way you want to go from its middle (the pad itself never moves)
local function buildThumbpad(parent)
	local small = math.min(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) <= 500
	local SIZE = small and 90 or 120
	local frame = Instance.new("Frame")
	frame.Name = "ThumbpadFrame"
	frame.Visible = false
	frame.Active = true
	frame.Size = UDim2.new(0, SIZE, 0, SIZE)
	frame.Position = UDim2.new(0, 30, 1, -SIZE - 30)
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	ring(frame, SIZE)
	local fwd = arrowLabel(frame, "▲", UDim2.new(0.5, 0, 0.16, 0), UDim2.new(0, SIZE * 0.26, 0, SIZE * 0.26))
	local back = arrowLabel(frame, "▼", UDim2.new(0.5, 0, 0.84, 0), UDim2.new(0, SIZE * 0.26, 0, SIZE * 0.26))
	local left = arrowLabel(frame, "◀", UDim2.new(0.16, 0, 0.5, 0), UDim2.new(0, SIZE * 0.26, 0, SIZE * 0.26))
	local right = arrowLabel(frame, "▶", UDim2.new(0.84, 0, 0.5, 0), UDim2.new(0, SIZE * 0.26, 0, SIZE * 0.26))
	local touch = nil
	local deadZone = 0.1
	local function center()
		return Vector2.new(frame.AbsolutePosition.X + frame.AbsoluteSize.X / 2, frame.AbsolutePosition.Y + frame.AbsoluteSize.Y / 2)
	end
	local function doMove(pos)
		local delta = (Vector2.new(pos.X, pos.Y) - center()) / (SIZE / 2)
		local magnitude = delta.Magnitude
		if magnitude < deadZone then
			moveVector = Vector3.new(0, 0, 0)
		else
			local dir = delta.Unit
			moveVector = Vector3.new(dir.X, 0, dir.Y)
		end
		local f = moveVector:Dot(Vector3.new(0, 0, -1))
		local r = moveVector:Dot(Vector3.new(1, 0, 0))
		fwd.TextColor3 = f > 0.5 and ARROW_LIT or ARROW_DIM
		back.TextColor3 = f < -0.5 and ARROW_LIT or ARROW_DIM
		right.TextColor3 = r > 0.5 and ARROW_LIT or ARROW_DIM
		left.TextColor3 = r < -0.5 and ARROW_LIT or ARROW_DIM
	end
	local function ended()
		moveVector = Vector3.new(0, 0, 0)
		touch = nil
		for _, l in ipairs({ fwd, back, left, right }) do l.TextColor3 = ARROW_DIM end
	end
	track(frame.InputBegan:Connect(function(input)
		if touch or (input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1) then return end
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
	return {
		frame = frame, stop = ended, size = SIZE,
		setCenter = function(c)
			if not gui then return end
			frame.Position = UDim2.new(0, c.X - gui.AbsolutePosition.X - SIZE / 2, 0, c.Y - gui.AbsolutePosition.Y - SIZE / 2)
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
-- TAP TO MOVE (our own): a tap on the ground walks there; a sphere shows where
----------------------------------------------------------------------------------------------------
local marker = nil
local markerToken = 0
local function clearMarker()
	markerToken = markerToken + 1
	if marker then pcall(function() marker:Destroy() end) marker = nil end
end
local function showMarker(point, humanoid)
	clearMarker()
	local token = markerToken
	local sphere = Instance.new("Part")
	sphere.Name = "BPTapMarker"
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.new(1, 1, 1)
	sphere.Material = Enum.Material.SmoothPlastic
	sphere.Color = Color3.fromRGB(255, 255, 255)
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanQuery = false
	sphere.CanTouch = false
	sphere.CastShadow = false
	sphere.Position = point + Vector3.new(0, 0.6, 0)
	sphere.Parent = workspace
	marker = sphere
	task.spawn(function()
		local reachable = true
		local root = humanoid.RootPart
		if root then
			local ok, status = pcall(function()
				local path = PathfindingService:CreatePath()
				path:ComputeAsync(root.Position, point)
				return path.Status
			end)
			if ok and status ~= Enum.PathStatus.Success then reachable = false end
		end
		if token ~= markerToken or not alive then return end
		if not reachable then
			sphere.Color = Color3.fromRGB(255, 60, 40)
			for i = 1, 8 do
				sphere.Transparency = (i % 2 == 1) and 0.85 or 0
				task.wait(0.1)
				if token ~= markerToken then return end
			end
			sphere.Transparency = 0
			if token == markerToken then
				clearMarker()
				pcall(function() humanoid:Move(Vector3.new(0, 0, 0)) humanoid:MoveTo(root.Position) end)
			end
		end
	end)
end
local function myHumanoid()
	local char = LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end
local lastWalkAt = -1
track(UserInputService.TouchTap:Connect(function(positions, processed)
	if mode ~= "ClickToMove" or processed then return end
	local pos = positions and positions[1]
	local camera = workspace.CurrentCamera
	local humanoid = myHumanoid()
	if not (pos and camera and humanoid) then return end
	local tappedAt = os.clock()
	-- (Roblox's own tap to move walks there and sets the point: the sphere follows that. If it did nothing, we walk there.)
	task.delay(0.4, function()
		if mode ~= "ClickToMove" or lastWalkAt >= tappedAt then return end
		local ray = camera:ViewportPointToRay(pos.X, pos.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { LocalPlayer.Character, marker }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
		if hit then
			humanoid:MoveTo(hit.Position)
		end
	end)
end))
local hookedHumanoid = nil
local function hookHumanoid(humanoid)
	if hookedHumanoid == humanoid then return end
	hookedHumanoid = humanoid
	track(humanoid:GetPropertyChangedSignal("WalkToPoint"):Connect(function()
		if mode ~= "ClickToMove" then return end
		local point = humanoid.WalkToPoint
		if point and point.Magnitude > 0 then
			lastWalkAt = os.clock()
			showMarker(point, humanoid)
		end
	end))
	track(humanoid.MoveToFinished:Connect(function() if mode == "ClickToMove" then clearMarker() end end))
	track(humanoid.Died:Connect(clearMarker))
end
task.spawn(function()
	local char = LocalPlayer.Character
	local h = char and (char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10))
	if h then hookHumanoid(h) end
end)
track(LocalPlayer.CharacterAdded:Connect(function(char)
	task.spawn(function()
		local h = char:WaitForChild("Humanoid", 10)
		if h then hookHumanoid(h) end
	end)
end))

----------------------------------------------------------------------------------------------------
-- the mode
----------------------------------------------------------------------------------------------------
local api = {}
-- where Roblox's thumbstick is (it is hidden, but its frame stays where it is): the Thumbpad rests there
local function stickCenter()
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local touchGui = pg and pg:FindFirstChild("TouchGui")
	local controls = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	if not controls then return nil end
	for _, name in ipairs({ "ThumbstickFrame", "DynamicThumbstickFrame" }) do
		local f = controls:FindFirstChild(name)
		if f and f:IsA("GuiObject") and f.AbsoluteSize.X > 0 then
			return f.AbsolutePosition + f.AbsoluteSize / 2
		end
	end
	return nil
end
function api.Set(newMode)
	if newMode ~= "DPad" and newMode ~= "Thumbpad" and newMode ~= "ClickToMove" then newMode = nil end
	if newMode == mode then return end
	mode = newMode
	moveVector = Vector3.new(0, 0, 0)
	clearMarker()
	if mode == "DPad" or mode == "Thumbpad" then ensureGui() end
	hideRoblox(mode ~= nil)
	if dpad then dpad.stop() dpad.frame.Visible = (mode == "DPad") end
	if thumbpad then thumbpad.stop() thumbpad.frame.Visible = (mode == "Thumbpad") end
	if mode == "Thumbpad" and lastStickCenter then thumbpad.setCenter(lastStickCenter) end
	if mode == "DPad" and lastStickCenter then dpad.setCenter(lastStickCenter) end
	print("[Legacy Move Pads] " .. tostring(mode or "off: Roblox's own thumbstick"))
end
function api.Mode() return mode end
Env.BPMovePads = api

local stepName = "BPMovePads" .. tostring(math.random(1, 1e9))
RunService:BindToRenderStep(stepName, Enum.RenderPriority.Input.Value + 3, function()
	if mode == nil then return end
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
	["tap-to-move"] = "ClickToMove",
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
-- Roblox's own tap to move marker (its teardrop, rings, waypoints): hidden while tap to move is on
local function hideTheirs(d)
	if not alive or mode ~= "ClickToMove" then return end
	pcall(function()
		if d.Name == "BPTapMarker" then return end
		if d:IsA("BasePart") then d.Transparency = 1 d.LocalTransparencyModifier = 1
		elseif d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then d.Enabled = false
		elseif d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1
		elseif d:IsA("SelectionBox") or d:IsA("Highlight") then d.Visible = false end
	end)
end
task.spawn(function()
	local cam = workspace.CurrentCamera
	while alive and not cam do task.wait() cam = workspace.CurrentCamera end
	if not cam then return end
	track(cam.DescendantAdded:Connect(function(d) task.defer(function() if d.Parent then hideTheirs(d) end end) end))
	track(RunService.Heartbeat:Connect(function()
		if mode ~= "ClickToMove" then return end
		for _, d in ipairs(cam:GetDescendants()) do hideTheirs(d) end
	end))
end)
-- (the thumbstick's place is learned while it is still on screen)
task.spawn(function()
	for _ = 1, 20 do
		noteStickCenter()
		if lastStickCenter then break end
		task.wait(0.5)
	end
end)
print("[Legacy Move Pads] ready: pick DPad, Thumbpad or Click to Move as the Movement Mode in Settings.")
