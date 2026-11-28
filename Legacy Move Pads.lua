--========================================================
-- LEGACY MOVE PADS (Addtion-Scripts)
-- Roblox's own DPad and Thumbpad touch controls, from its ControlScript (MasterControl/DPad.lua and Thumbpad.lua), for the
-- 2015 - 2019 GUIs, whose Settings menu has a "Movement Mode" dropdown that did nothing: pick DPad or Thumbpad there and the
-- control comes up; pick anything else and it goes again (Roblox's own thumbstick is back).
--   * DPad: eight directions on a pad, the middle is the jump button (the diagonal arrows show once you go forward).
--   * Thumbpad: a pad that centres under your thumb where you touch it, with arrows that grow as you go that way.
-- How it works: the pad draws itself, hides Roblox's thumbstick while it is on, and hands your direction to the
-- humanoid after the controls have (camera-relative, as the controls do).
-- By hand: getgenv().BPMovePads.Set("DPad" / "Thumbpad" / nil), .Mode()
--========================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")

local Env = (getgenv and getgenv()) or _G
if type(Env.BPMovePadsCleanup) == "function" then pcall(Env.BPMovePadsCleanup) end

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do task.wait() LocalPlayer = Players.LocalPlayer end

local DPAD_SHEET = "rbxasset://textures/ui/DPadSheet.png"
local TOUCH_SHEET = "rbxasset://textures/ui/TouchControlsSheet.png"

local conns = {}
local function track(c) table.insert(conns, c) return c end
local alive = true
local mode = nil
local moveVector = Vector3.new(0, 0, 0)
local jumpRequested = false
local gui, dpad, thumbpad = nil, nil, nil
local savedTouchMode, settingFromUs, nativeShown = nil, false, false
local hidden = {} -- Roblox's own thumbstick frames hidden while a pad is on: [frame] = was visible

----------------------------------------------------------------------------------------------------
-- DPad (MasterControl/DPad.lua)
----------------------------------------------------------------------------------------------------
local COMPASS_DIR = {
	Vector3.new(1, 0, 0), Vector3.new(1, 0, 1).Unit, Vector3.new(0, 0, 1), Vector3.new(-1, 0, 1).Unit,
	Vector3.new(-1, 0, 0), Vector3.new(-1, 0, -1).Unit, Vector3.new(0, 0, -1), Vector3.new(1, 0, -1).Unit,
}

local function buildDPad(parent)
	local frame = Instance.new("Frame")
	frame.Name = "DPadFrame"
	frame.Active = true
	frame.Visible = false
	frame.Size = UDim2.new(0, 192, 0, 192)
	frame.Position = UDim2.new(0, 10, 1, -230)
	frame.BackgroundTransparency = 1
	local function arrow(name, position, size, rectOffset, rectSize)
		local image = Instance.new("ImageLabel")
		image.Name = name
		image.Image = DPAD_SHEET
		image.ImageRectOffset = rectOffset
		image.ImageRectSize = rectSize
		image.BackgroundTransparency = 1
		image.Size = size
		image.Position = position
		image.Parent = frame
		return image
	end
	local sm, lg = UDim2.new(0, 23, 0, 23), UDim2.new(0, 64, 0, 64)
	local smOff, lgOff = Vector2.new(46, 46), Vector2.new(128, 128)
	arrow("BackButton", UDim2.new(0.5, -32, 1, -64), lg, Vector2.new(0, 0), lgOff)
	arrow("ForwardButton", UDim2.new(0.5, -32, 0, 0), lg, Vector2.new(0, 258), lgOff)
	arrow("LeftButton", UDim2.new(0, 0, 0.5, -32), lg, Vector2.new(129, 129), lgOff)
	arrow("RightButton", UDim2.new(1, -64, 0.5, -32), lg, Vector2.new(0, 129), lgOff)
	local jumpBtn = arrow("JumpButton", UDim2.new(0.5, -32, 0.5, -32), lg, Vector2.new(129, 0), lgOff)
	local flBtn = arrow("ForwardLeftButton", UDim2.new(0, 35, 0, 35), sm, Vector2.new(129, 258), smOff)
	local frBtn = arrow("ForwardRightButton", UDim2.new(1, -55, 0, 35), sm, Vector2.new(176, 258), smOff)
	flBtn.Visible, frBtn.Visible = false, false

	local touch = nil
	local direction = Vector3.new(0, 0, 0)
	local function center()
		return Vector2.new(frame.AbsolutePosition.X + frame.AbsoluteSize.X / 2, frame.AbsolutePosition.Y + frame.AbsoluteSize.Y / 2)
	end
	local function normalize(pos)
		local c = center()
		local d = Vector2.new(pos.X - c.X, pos.Y - c.Y)
		if d.Magnitude > jumpBtn.AbsoluteSize.X / 2 then
			local angle = math.atan2(d.Y, d.X)
			local octant = (math.floor(8 * angle / (2 * math.pi) + 8.5) % 8) + 1
			direction = COMPASS_DIR[octant]
		end
		if not flBtn.Visible and direction == COMPASS_DIR[7] then
			flBtn.Visible, frBtn.Visible = true, true
		end
		moveVector = direction
	end
	local function ended()
		touch = nil
		flBtn.Visible, frBtn.Visible = false, false
		direction = Vector3.new(0, 0, 0)
		moveVector = direction
	end
	track(jumpBtn.InputBegan:Connect(function() jumpRequested = true end))
	track(frame.InputBegan:Connect(function(input)
		if touch or input.UserInputType ~= Enum.UserInputType.Touch then return end
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
	frame.Parent = parent
	return { frame = frame, stop = ended }
end

----------------------------------------------------------------------------------------------------
-- Thumbpad (MasterControl/Thumbpad.lua)
----------------------------------------------------------------------------------------------------
local function buildThumbpad(parent)
	local minAxis = math.min(parent.AbsoluteSize.X, parent.AbsoluteSize.Y)
	local small = minAxis <= 500
	local padSize = small and 70 or 120
	local home = small and UDim2.new(0, padSize * 1.25, 1, -padSize - 20) or UDim2.new(0, padSize / 2 - 10, 1, -padSize * 1.75 - 10)
	local frame = Instance.new("Frame")
	frame.Name = "ThumbpadFrame"
	frame.Visible = false
	frame.Active = true
	frame.Size = UDim2.new(0, padSize + 20, 0, padSize + 20)
	frame.Position = home
	frame.BackgroundTransparency = 1
	local outer = Instance.new("ImageLabel")
	outer.Name = "OuterImage"
	outer.Image = TOUCH_SHEET
	outer.ImageRectOffset = Vector2.new(0, 0)
	outer.ImageRectSize = Vector2.new(220, 220)
	outer.BackgroundTransparency = 1
	outer.Size = UDim2.new(0, padSize, 0, padSize)
	outer.Position = UDim2.new(0, 10, 0, 10)
	outer.Parent = frame
	local smSize = small and UDim2.new(0, 32, 0, 32) or UDim2.new(0, 64, 0, 64)
	local lgSize = UDim2.new(0, smSize.X.Offset * 2, 0, smSize.Y.Offset * 2)
	local rect = Vector2.new(110, 110)
	local smOff = small and -4 or -9
	local lgOff = small and -28 or -55
	local function arrow(name, position, rectOffset)
		local image = Instance.new("ImageLabel")
		image.Name = name
		image.Image = DPAD_SHEET
		image.ImageRectOffset = rectOffset
		image.ImageRectSize = rect
		image.BackgroundTransparency = 1
		image.ImageColor3 = Color3.new(190 / 255, 190 / 255, 190 / 255)
		image.Size = smSize
		image.Position = position
		image.Parent = outer
		return image
	end
	local dA = arrow("DownArrow", UDim2.new(0.5, -smSize.X.Offset / 2, 1, lgOff), Vector2.new(8, 8))
	local uA = arrow("UpArrow", UDim2.new(0.5, -smSize.X.Offset / 2, 0, smOff), Vector2.new(8, 266))
	local lA = arrow("LeftArrow", UDim2.new(0, smOff, 0.5, -smSize.Y.Offset / 2), Vector2.new(137, 137))
	local rA = arrow("RightArrow", UDim2.new(1, lgOff, 0.5, -smSize.Y.Offset / 2), Vector2.new(8, 137))
	local function tween(obj, size, pos)
		pcall(function() obj:TweenSizeAndPosition(size, pos, Enum.EasingDirection.InOut, Enum.EasingStyle.Linear, 0.15, true) end)
	end
	local function relax()
		tween(dA, smSize, UDim2.new(0.5, -smSize.X.Offset / 2, 1, lgOff))
		tween(uA, smSize, UDim2.new(0.5, -smSize.X.Offset / 2, 0, smOff))
		tween(lA, smSize, UDim2.new(0, smOff, 0.5, -smSize.Y.Offset / 2))
		tween(rA, smSize, UDim2.new(1, lgOff, 0.5, -smSize.Y.Offset / 2))
	end
	local touch, origin = nil, nil
	local deadZone = 0.1
	local isUp, isDown, isLeft, isRight = false, false, false, false
	local function doMove(pos)
		local delta = (Vector2.new(pos.X, pos.Y) - origin) / (padSize / 2)
		local v = Vector3.new(delta.X, delta.Y, 0)
		local magnitude = v.Magnitude
		if magnitude < deadZone then
			moveVector = Vector3.new(0, 0, 0)
		else
			local scaled = v.Unit * ((magnitude - deadZone) / (1 - deadZone))
			if scaled.Magnitude == 0 or scaled.Magnitude ~= scaled.Magnitude then
				moveVector = Vector3.new(0, 0, 0)
			else
				moveVector = Vector3.new(scaled.X, 0, scaled.Y).Unit
			end
		end
		local forwardDot = moveVector:Dot(Vector3.new(0, 0, -1))
		local rightDot = moveVector:Dot(Vector3.new(1, 0, 0))
		if forwardDot > 0.5 then
			if not isUp then
				isUp, isDown = true, false
				tween(uA, lgSize, UDim2.new(0.5, -smSize.X.Offset, 0, smOff - smSize.Y.Offset * 1.5))
				tween(dA, smSize, UDim2.new(0.5, -smSize.X.Offset / 2, 1, lgOff))
			end
		elseif forwardDot < -0.5 then
			if not isDown then
				isDown, isUp = true, false
				tween(dA, lgSize, UDim2.new(0.5, -smSize.X.Offset, 1, lgOff + smSize.Y.Offset / 2))
				tween(uA, smSize, UDim2.new(0.5, -smSize.X.Offset / 2, 0, smOff))
			end
		else
			isUp, isDown = false, false
			tween(dA, smSize, UDim2.new(0.5, -smSize.X.Offset / 2, 1, lgOff))
			tween(uA, smSize, UDim2.new(0.5, -smSize.X.Offset / 2, 0, smOff))
		end
		if rightDot > 0.5 then
			if not isRight then
				isRight, isLeft = true, false
				tween(rA, lgSize, UDim2.new(1, lgOff + smSize.X.Offset / 2, 0.5, -smSize.Y.Offset))
				tween(lA, smSize, UDim2.new(0, smOff, 0.5, -smSize.Y.Offset / 2))
			end
		elseif rightDot < -0.5 then
			if not isLeft then
				isLeft, isRight = true, false
				tween(lA, lgSize, UDim2.new(0, smOff - smSize.X.Offset * 1.5, 0.5, -smSize.Y.Offset))
				tween(rA, smSize, UDim2.new(1, lgOff, 0.5, -smSize.Y.Offset / 2))
			end
		else
			isRight, isLeft = false, false
			tween(lA, smSize, UDim2.new(0, smOff, 0.5, -smSize.Y.Offset / 2))
			tween(rA, smSize, UDim2.new(1, lgOff, 0.5, -smSize.Y.Offset / 2))
		end
	end
	local function ended()
		moveVector = Vector3.new(0, 0, 0)
		frame.Position = home
		touch = nil
		isUp, isDown, isLeft, isRight = false, false, false, false
		relax()
	end
	track(frame.InputBegan:Connect(function(input)
		if touch or input.UserInputType ~= Enum.UserInputType.Touch or input.UserInputState ~= Enum.UserInputState.Begin then return end
		frame.Position = UDim2.new(0, input.Position.X - frame.AbsoluteSize.X / 2, 0, input.Position.Y - frame.Size.Y.Offset / 2)
		origin = Vector2.new(frame.AbsolutePosition.X + frame.AbsoluteSize.X / 2, frame.AbsolutePosition.Y + frame.AbsoluteSize.Y / 2)
		doMove(input.Position)
		touch = input
	end))
	track(UserInputService.TouchMoved:Connect(function(input)
		if input == touch then doMove(input.Position) end
	end))
	track(UserInputService.TouchEnded:Connect(function(input)
		if input == touch then ended() end
	end))
	track(GuiService.MenuOpened:Connect(function() if touch then ended() end end))
	frame.Parent = parent
	return { frame = frame, stop = ended }
end

----------------------------------------------------------------------------------------------------
-- Roblox's own thumbstick: out of the way while a pad is on
----------------------------------------------------------------------------------------------------
local function setRobloxStick(hide)
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local touchGui = pg and pg:FindFirstChild("TouchGui")
	local controls = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	if not controls then return end
	for _, name in ipairs({ "ThumbstickFrame", "DynamicThumbstickFrame" }) do
		local f = controls:FindFirstChild(name)
		if f and f:IsA("GuiObject") then
			if hide then
				if hidden[f] == nil then hidden[f] = f.Visible end
				f.Visible = false
			elseif hidden[f] ~= nil then
				f.Visible = hidden[f]
				hidden[f] = nil
			end
		end
	end
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

local api = {}
function api.Set(newMode)
	if newMode ~= "DPad" and newMode ~= "Thumbpad" then newMode = nil end
	if newMode == mode then return end
	mode = newMode
	moveVector = Vector3.new(0, 0, 0)
	if mode then ensureGui() end
	if dpad then dpad.stop() dpad.frame.Visible = false end
	if thumbpad then thumbpad.stop() thumbpad.frame.Visible = false end
	-- (the setting is Roblox's own: its control comes up for it. Ours is drawn only if Roblox's does not appear within a moment.)
	pcall(function()
		local settings = UserSettings():GetService("UserGameSettings")
		if mode then
			if savedTouchMode == nil then savedTouchMode = settings.TouchMovementMode end
			settingFromUs = true
			settings.TouchMovementMode = Enum.TouchMovementMode[mode]
			settingFromUs = false
		elseif savedTouchMode ~= nil then
			settingFromUs = true
			settings.TouchMovementMode = savedTouchMode
			settingFromUs = false
			savedTouchMode = nil
		end
	end)
	local myMode = mode
	if mode then
		task.delay(0.8, function()
			if mode ~= myMode or not alive then return end
			local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
			local tc = pg and pg:FindFirstChild("TouchGui") and pg.TouchGui:FindFirstChild("TouchControlFrame")
			local native = tc and tc:FindFirstChild(myMode == "DPad" and "DPadFrame" or "ThumbpadFrame")
			if native and native:IsA("GuiObject") and native.Visible then
				nativeShown = true
				setRobloxStick(false) -- (Roblox's own is running: nothing of ours)
			else
				nativeShown = false
				if myMode == "DPad" and dpad then dpad.frame.Visible = true end
				if myMode == "Thumbpad" and thumbpad then thumbpad.frame.Visible = true end
				setRobloxStick(true)
			end
		end)
	else
		nativeShown = false
		setRobloxStick(false)
	end
	print("[Legacy Move Pads] " .. tostring(mode or "off: Roblox's own controls"))
end
function api.Mode() return mode end
Env.BPMovePads = api

-- the direction handed to the humanoid, after the controls' own (which are zero with the thumbstick hidden)
local stepName = "BPMovePads" .. tostring(math.random(1, 1e9))
RunService:BindToRenderStep(stepName, Enum.RenderPriority.Input.Value + 3, function()
	if not mode or nativeShown then return end
	local char = LocalPlayer.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if moveVector.Magnitude > 0 then humanoid:Move(moveVector, true) end
	if jumpRequested then
		jumpRequested = false
		humanoid.Jump = true
	end
	-- (Roblox's controls may have put its own thumbstick back after a respawn)
	if not nativeShown then setRobloxStick(true) end
end)

----------------------------------------------------------------------------------------------------
-- The Settings menu's "Movement Mode" dropdown: what it shows picks the pad
----------------------------------------------------------------------------------------------------
local MODE_TEXT = {
	["dpad"] = "DPad", ["thumbpad"] = "Thumbpad",
	["thumbstick"] = false, ["default (thumbstick)"] = false, ["dynamic thumbstick"] = false, ["click to move"] = false,
	["tap to move"] = false, ["default (dynamic thumbstick)"] = false, ["classic"] = false,
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
	if picked == nil then return end -- not one of the options
	api.Set(picked or nil)
end
local function look(obj)
	if hooked[obj] or not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then return end
	local t = MODE_TEXT[string.lower(obj.Text or "")]
	if t == nil then return end
	if not rowHasMovementMode(obj) then return end
	hooked[obj] = true
	track(obj:GetPropertyChangedSignal("Text"):Connect(function() applyText(obj.Text) end))
	-- (the label that shows the pick: its text now is the pick)
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
-- (and Roblox's own setting, when something sets it)
pcall(function()
	local settings = UserSettings():GetService("UserGameSettings")
	track(settings:GetPropertyChangedSignal("TouchMovementMode"):Connect(function()
		if settingFromUs then return end
		local name = settings.TouchMovementMode.Name
		if name == "DPad" or name == "Thumbpad" then api.Set(name) elseif mode then api.Set(nil) end
	end))
end)

----------------------------------------------------------------------------------------------------
-- TAP TO MOVE: a sphere where you tapped (white; red and flickering when there is nowhere to walk to), in place of
-- Roblox's teardrop marker
----------------------------------------------------------------------------------------------------
local PathfindingService = game:GetService("PathfindingService")
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
	sphere.Material = Enum.Material.Neon
	sphere.Color = Color3.fromRGB(255, 255, 255)
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanQuery = false
	sphere.CanTouch = false
	sphere.CastShadow = false
	sphere.Position = point + Vector3.new(0, 0.5, 0)
	sphere.Parent = workspace.CurrentCamera or workspace
	marker = sphere
	task.spawn(function()
		-- is there a way there?
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
			if token == markerToken then clearMarker() end
		end
	end)
end
local hookedHumanoid = nil
local function hookHumanoid(humanoid)
	if hookedHumanoid == humanoid then return end
	hookedHumanoid = humanoid
	track(humanoid:GetPropertyChangedSignal("WalkToPoint"):Connect(function()
		local point = humanoid.WalkToPoint
		if point and point.Magnitude > 0 and humanoid.MoveDirection.Magnitude >= 0 then showMarker(point, humanoid) end
	end))
	track(humanoid.MoveToFinished:Connect(function() clearMarker() end))
	track(humanoid.Died:Connect(clearMarker))
end
local function hookCharacter(char)
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
	if humanoid then hookHumanoid(humanoid) end
end
task.spawn(hookCharacter, LocalPlayer.Character)
track(LocalPlayer.CharacterAdded:Connect(function(char) task.spawn(hookCharacter, char) end))
-- Roblox's own marker (what it puts under the camera) is hidden
local function hideTheirMarker(d)
	if d.Name == "BPTapMarker" then return end
	local n = string.lower(d.Name)
	if string.find(n, "click", 1, true) or string.find(n, "marker", 1, true) or string.find(n, "waypoint", 1, true)
		or string.find(n, "destination", 1, true) or string.find(n, "teardrop", 1, true) or string.find(n, "movedisplay", 1, true) then
		pcall(function()
			if d:IsA("BasePart") then d.Transparency = 1 d.LocalTransparencyModifier = 1
			elseif d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Beam") then d.Enabled = false
			elseif d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
		end)
	end
end
task.spawn(function()
	local cam = workspace.CurrentCamera
	while alive and not cam do task.wait() cam = workspace.CurrentCamera end
	if not cam then return end
	track(cam.DescendantAdded:Connect(function(d) task.defer(function() if d.Parent then hideTheirMarker(d) end end) end))
end)

Env.BPMovePadsCleanup = function()
	alive = false
	pcall(function() RunService:UnbindFromRenderStep(stepName) end)
	api.Set(nil)
	clearMarker()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	table.clear(conns)
	if gui then pcall(function() gui:Destroy() end) gui = nil end
	Env.BPMovePads = nil
end
print("[Legacy Move Pads] ready: pick DPad or Thumbpad as the Movement Mode in Settings.")
