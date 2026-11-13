--[[ OLD HEALTH BAR (Addtion-Scripts) ]]
-- The 2011-2013 Roblox health bar: the dark tray (35238000), the green bar inside it with a dark edge above
-- and below (35238053; red, 35238036, at a quarter or less), "HEALTH" on the right (34816363), the lost
-- part flashing white and the red hurt overlay (34854607) on a big hit.
--
-- It takes the place of the GUI's own health bar: that one (Roblox's old HealthGUI "tray", the 2013 mobile
-- GUI's HealthFrame, or any bar made of the same pictures) is hidden, and this one goes exactly where it
-- was, at its size. With none to be found it goes at the bottom middle, 170 x 18 (the size the GUIs use).
--
-- getgenv().OldHealthBar = { Start, Stop, IsRunning }: the loader starts it for the GUIs before 2014 (the
-- 2013 mobile GUI only with Hammer stuff 2's "old healthbar" ticked) and stops it for the others.

local Env = (getgenv and getgenv()) or _G
if Env.OldHealthBar and type(Env.OldHealthBar.Stop) == "function" then
	pcall(Env.OldHealthBar.Stop)
end
-- the older versions of this bar
for _, key in ipairs({ "_Roblox2014HealthCleanup", "_Roblox2012HealthCleanup", "_Roblox2013HealthCleanup" }) do
	if Env[key] then
		pcall(Env[key])
		Env[key] = nil
	end
end

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ContentProvider = game:GetService("ContentProvider")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
	task.wait()
	LocalPlayer = Players.LocalPlayer
end

local ASSET_BKG = "rbxassetid://35238000"
local ASSET_BAR_GREEN = "rbxassetid://35238053"
local ASSET_BAR_RED = "rbxassetid://35238036"
local ASSET_LABEL = "rbxassetid://34816363"
local ASSET_HURT_OVERLAY = "rbxassetid://34854607"
local HEALTH_IDS = { "35238000", "35238053", "35238036", "34816363" }

local OUR_GUI = "BPOldHealthBar"

-- where it goes when the GUI has no health bar of its own (the 2013 mobile GUI's size and place)
local DEFAULT_SIZE = UDim2.new(0, 170, 0, 18)
local DEFAULT_POSITION = UDim2.new(0.5, -85, 1, -22)

-- Measured from the reference picture of the bar (a 501 x 58 tray):
-- the green bar fills most of the tray, with a thin dark edge round it
local BAR_LEFT = 0.02
local BAR_WIDTH = 0.96
local BAR_TOP = 0.17
local BAR_HEIGHT = 0.73

-- the bar's shading, top to bottom: a light shine, the green, darker towards the bottom, a little lighter
-- at the very bottom (as in the reference); red the same way at a quarter health or less
local GREEN = ColorSequence.new({
	ColorSequenceKeypoint.new(0.00, Color3.fromRGB(116, 178, 96)),
	ColorSequenceKeypoint.new(0.12, Color3.fromRGB(66, 149, 41)),
	ColorSequenceKeypoint.new(0.45, Color3.fromRGB(52, 121, 31)),
	ColorSequenceKeypoint.new(0.85, Color3.fromRGB(29, 78, 16)),
	ColorSequenceKeypoint.new(1.00, Color3.fromRGB(55, 104, 38)),
})
local RED = ColorSequence.new({
	ColorSequenceKeypoint.new(0.00, Color3.fromRGB(214, 110, 96)),
	ColorSequenceKeypoint.new(0.12, Color3.fromRGB(178, 46, 34)),
	ColorSequenceKeypoint.new(0.45, Color3.fromRGB(146, 32, 22)),
	ColorSequenceKeypoint.new(0.85, Color3.fromRGB(92, 16, 10)),
	ColorSequenceKeypoint.new(1.00, Color3.fromRGB(120, 40, 32)),
})

-- "HEALTH", white pixel letters on the right of the bar, about a third of the tray tall
local LABEL_POSITION = UDim2.new(0.68, 0, 0.33, 0)
local LABEL_SIZE = UDim2.new(0.255, 0, 0.32, 0)

local FLASH_DURATION = 0.18
local OVERLAY_PERCENT = 5 -- a hit of this much of the health or more shows the red hurt overlay

local running = false
local gui, tray, bar, whiteFlash, hurtOverlay = nil, nil, nil, nil, nil
local barGradient = nil
local conns = {}
local charConns = {}
local hidden = {}         -- the GUI's own health bars: object -> { prop, was, conn }
local coreHealthWas = nil
local currentHumanoid = nil
local lastRatio = 1
local flashToken = 0
local source = nil        -- the GUI's own tray this one sits on top of

local function disconnectAll(list)
	for _, c in ipairs(list) do pcall(function() c:Disconnect() end) end
	table.clear(list)
end

------------------------------------------------------------------------------------------------------
-- THE GUI'S OWN HEALTH BAR: found, hidden, and its place taken
------------------------------------------------------------------------------------------------------
local function isOurs(obj)
	return gui ~= nil and (obj == gui or obj:IsDescendantOf(gui))
end

local function usesHealthPicture(obj)
	if not (obj:IsA("ImageLabel") or obj:IsA("ImageButton")) then return false end
	local image = tostring(obj.Image)
	for _, id in ipairs(HEALTH_IDS) do
		if string.find(image, id, 1, true) then return true end
	end
	return false
end

-- The frame that is the bar (its tray), for something that belongs to a health bar
local function trayOf(obj)
	if isOurs(obj) then return nil end
	local name = string.lower(obj.Name)
	-- Roblox's old HealthGUI: HealthGUI > tray
	if name == "tray" and obj.Parent and string.find(string.lower(obj.Parent.Name), "health", 1, true) then
		return obj
	end
	-- the 2013 mobile GUI's own one
	if obj.Name == "HealthFrame" and obj:IsA("GuiObject") then return obj end
	-- any bar made of the old health pictures: the frame around the picture
	if usesHealthPicture(obj) then
		local parent = obj.Parent
		if parent and parent:IsA("GuiObject") then return parent end
	end
	-- an era GUI's bar drawn without them: a small frame with "Health" written on it (only in the GUIs
	-- Roblox and the era GUIs use, not in the game's own GUI, whose health display is left alone)
	if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and not obj:IsDescendantOf(LocalPlayer:FindFirstChildOfClass("PlayerGui") or game) then
		local text = string.lower((string.gsub(obj.Text or "", "%s", "")))
		local parent = obj.Parent
		if text == "health" and parent and parent:IsA("GuiObject") and parent.AbsoluteSize.X <= 400 then
			return parent
		end
	end
	return nil
end

local function hide(obj)
	if hidden[obj] then return end
	local prop = obj:IsA("LayerCollector") and "Enabled" or (obj:IsA("GuiObject") and "Visible") or nil
	if not prop then return end
	local entry = { prop = prop, was = obj[prop] }
	hidden[obj] = entry
	pcall(function() obj[prop] = false end)
	entry.conn = obj:GetPropertyChangedSignal(prop):Connect(function()
		if running and obj[prop] == true then
			entry.was = true
			pcall(function() obj[prop] = false end)
		end
	end)
end

local placedPos, placedSize = nil, nil
local function placeOnTop(foundTray)
	if not tray then return end
	source = foundTray
	local pos, size = foundTray.AbsolutePosition, foundTray.AbsoluteSize
	if size.X < 20 or size.Y < 4 then return end
	if pos == placedPos and size == placedSize then return end
	placedPos, placedSize = pos, size
	-- the GUI's own bar is measured on screen; ours is placed on screen too (IgnoreGuiInset on our gui),
	-- plus the top bar's inset when the GUI's bar is below it
	local inset = Vector2.new(0, 0)
	pcall(function()
		local holder = foundTray:FindFirstAncestorWhichIsA("ScreenGui")
		if holder and not holder.IgnoreGuiInset then
			inset = game:GetService("GuiService"):GetGuiInset()
		end
	end)
	tray.Position = UDim2.new(0, pos.X + inset.X, 0, pos.Y + inset.Y)
	tray.Size = UDim2.new(0, size.X, 0, size.Y)
end

local function consider(obj)
	if not running or not obj.Parent then return end
	local found = trayOf(obj)
	if not found or isOurs(found) then return end
	-- measured before it is hidden (hidden things keep their place and size)
	placeOnTop(found)
	-- the whole health bar goes: the tray, and Roblox's HealthGUI around it
	hide(found)
	local parent = found.Parent
	if parent and string.find(string.lower(parent.Name), "health", 1, true) and not isOurs(parent) then
		hide(parent)
	end
end

local function restoreHidden()
	for obj, entry in pairs(hidden) do
		pcall(function() entry.conn:Disconnect() end)
		pcall(function() if obj.Parent then obj[entry.prop] = entry.was end end)
	end
	hidden = {}
end

------------------------------------------------------------------------------------------------------
-- OUR BAR
------------------------------------------------------------------------------------------------------
local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = OUR_GUI
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	pcall(function() gui.ScreenInsets = Enum.ScreenInsets.None end)
	if type(syn) == "table" and type(syn.protect_gui) == "function" then pcall(syn.protect_gui, gui) end
	if not pcall(function() gui.Parent = CoreGui end) then
		local ok, hui = pcall(function() return gethui and gethui() end)
		gui.Parent = (ok and hui) or LocalPlayer:WaitForChild("PlayerGui")
	end

	hurtOverlay = Instance.new("ImageLabel")
	hurtOverlay.Name = "HurtOverlay"
	hurtOverlay.BackgroundTransparency = 1
	hurtOverlay.Image = ASSET_HURT_OVERLAY
	hurtOverlay.Position = UDim2.new(-10, 0, -10, 0)
	hurtOverlay.Size = UDim2.new(20, 0, 20, 0)
	hurtOverlay.Visible = false
	hurtOverlay.ZIndex = 1
	hurtOverlay.Parent = gui

	tray = Instance.new("Frame")
	tray.Name = "tray"
	tray.BackgroundTransparency = 1
	tray.BorderSizePixel = 0
	-- (without a GUI bar to sit on: the bottom middle, below the top bar's inset like the GUIs' own)
	tray.Position = DEFAULT_POSITION
	tray.Size = DEFAULT_SIZE
	tray.ZIndex = 2
	tray.Parent = gui

	-- the tray: dark grey, rounded ends, a thin light line along its top edge
	local bkg = Instance.new("Frame")
	bkg.Name = "bkg"
	bkg.BackgroundColor3 = Color3.fromRGB(42, 44, 42)
	bkg.BorderSizePixel = 0
	bkg.Size = UDim2.new(1, 0, 1, 0)
	bkg.ZIndex = 2
	bkg.Parent = tray
	local bkgCorner = Instance.new("UICorner")
	bkgCorner.CornerRadius = UDim.new(0.18, 0)
	bkgCorner.Parent = bkg
	local bkgStroke = Instance.new("UIStroke")
	bkgStroke.Color = Color3.fromRGB(28, 30, 28)
	bkgStroke.Thickness = 1
	bkgStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bkgStroke.Parent = bkg
	local shine = Instance.new("Frame")
	shine.Name = "shine"
	shine.BackgroundColor3 = Color3.fromRGB(186, 185, 188)
	shine.BackgroundTransparency = 0.15
	shine.BorderSizePixel = 0
	shine.Position = UDim2.new(0.03, 0, 0, 0)
	shine.Size = UDim2.new(0.94, 0, 0, 1)
	shine.ZIndex = 2
	shine.Parent = bkg

	-- the bar: drawn with the reference's shading (the old bar picture stretched into hard bands)
	bar = Instance.new("Frame")
	bar.Name = "bar"
	bar.BackgroundColor3 = Color3.new(1, 1, 1)
	bar.BorderSizePixel = 0
	bar.Position = UDim2.new(BAR_LEFT, 0, BAR_TOP, 0)
	bar.Size = UDim2.new(BAR_WIDTH, 0, BAR_HEIGHT, 0)
	bar.ZIndex = 3
	bar.Parent = tray
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0.12, 0)
	barCorner.Parent = bar
	barGradient = Instance.new("UIGradient")
	barGradient.Rotation = 90
	barGradient.Color = GREEN
	barGradient.Parent = bar

	whiteFlash = Instance.new("Frame")
	whiteFlash.Name = "WhiteFlash"
	whiteFlash.BackgroundColor3 = Color3.new(1, 1, 1)
	whiteFlash.BorderSizePixel = 0
	whiteFlash.Position = UDim2.new(BAR_LEFT, 0, BAR_TOP, 0)
	whiteFlash.Size = UDim2.new(0, 0, BAR_HEIGHT, 0)
	whiteFlash.Visible = false
	whiteFlash.ZIndex = 4
	whiteFlash.Parent = tray

	local label = Instance.new("ImageLabel")
	label.Name = "label"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Image = ASSET_LABEL
	label.ScaleType = Enum.ScaleType.Fit
	label.Position = LABEL_POSITION
	label.Size = LABEL_SIZE
	label.ZIndex = 5
	label.Parent = tray

	task.spawn(function()
		pcall(function() ContentProvider:PreloadAsync({ hurtOverlay, label }) end)
	end)
end

local function flashLost(oldRatio, newRatio)
	local lost = math.clamp(oldRatio - newRatio, 0, 1)
	if lost <= 0.005 then return end
	flashToken = flashToken + 1
	local token = flashToken
	-- the bar empties from the left, towards "HEALTH": the lost part is just left of what is left
	whiteFlash.Position = UDim2.new(BAR_LEFT + BAR_WIDTH * (1 - oldRatio), 0, BAR_TOP, 0)
	whiteFlash.Size = UDim2.new(BAR_WIDTH * lost, 0, BAR_HEIGHT, 0)
	whiteFlash.Visible = true
	task.delay(FLASH_DURATION, function()
		if flashToken == token and whiteFlash then whiteFlash.Visible = false end
	end)
end

local function hurtFlash()
	if not hurtOverlay or not hurtOverlay.Parent then return end
	hurtOverlay.Size = UDim2.new(1, 0, 1, 0)
	hurtOverlay.Position = UDim2.new(0, 0, 0, 0)
	hurtOverlay.Visible = true
	hurtOverlay:TweenSizeAndPosition(
		UDim2.new(20, 0, 20, 0), UDim2.new(-10, 0, -10, 0),
		Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 10, true,
		function() hurtOverlay.Visible = false end
	)
end

local function update(health)
	if not currentHumanoid or not bar then return end
	local maxHealth = math.max(currentHumanoid.MaxHealth, 1)
	local ratio = math.clamp(health / maxHealth, 0, 1)
	local old = lastRatio
	lastRatio = ratio
	if ratio <= 0 then
		bar.Visible = false
	else
		bar.Visible = true
		local colors = (ratio > 0.25) and GREEN or RED
		if barGradient and barGradient.Color ~= colors then barGradient.Color = colors end
		bar.Position = UDim2.new(BAR_LEFT + BAR_WIDTH * (1 - ratio), 0, BAR_TOP, 0)
		bar.Size = UDim2.new(BAR_WIDTH * ratio, 0, BAR_HEIGHT, 0)
	end
	if ratio < old then
		flashLost(old, ratio)
		if old - ratio >= OVERLAY_PERCENT / 100 then hurtFlash() end
	end
end

local function bindCharacter(character)
	disconnectAll(charConns)
	if not character then return end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not running then return end
	currentHumanoid = humanoid
	lastRatio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
	if whiteFlash then whiteFlash.Visible = false end
	update(humanoid.Health)
	table.insert(charConns, humanoid.HealthChanged:Connect(update))
	table.insert(charConns, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		update(humanoid.Health)
	end))
	table.insert(charConns, humanoid.Died:Connect(function() update(0) end))
end

------------------------------------------------------------------------------------------------------
local api = {}

function api.Start()
	if running then return end
	running = true
	pcall(function()
		coreHealthWas = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Health)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
	build()

	-- the GUI's own health bar, now and when it is (re)made
	local roots = { CoreGui }
	pcall(function()
		local hui = gethui and gethui()
		if hui and hui ~= CoreGui then table.insert(roots, hui) end
	end)
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if pg then table.insert(roots, pg) end
	for _, root in ipairs(roots) do
		pcall(function()
			for _, d in ipairs(root:GetDescendants()) do consider(d) end
			table.insert(conns, root.DescendantAdded:Connect(function(d)
				-- (pictures and names are set just after a thing is added)
				task.defer(consider, d)
			end))
		end)
	end
	-- follow the GUI's bar if it moves (a different screen size, the phone turned)
	table.insert(conns, RunService.Heartbeat:Connect(function()
		if source and source.Parent then placeOnTop(source) end
	end))

	table.insert(conns, LocalPlayer.CharacterAdded:Connect(bindCharacter))
	if LocalPlayer.Character then task.spawn(bindCharacter, LocalPlayer.Character) end
	print("[Old Health Bar] On.")
end

function api.Stop()
	if not running then return end
	running = false
	disconnectAll(conns)
	disconnectAll(charConns)
	restoreHidden()
	if gui then pcall(function() gui:Destroy() end) end
	gui, tray, bar, whiteFlash, hurtOverlay, source, currentHumanoid = nil, nil, nil, nil, nil, nil, nil
	pcall(function()
		if coreHealthWas ~= nil then StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, coreHealthWas) end
	end)
	print("[Old Health Bar] Off, the GUI's own health bar is back.")
end

function api.IsRunning()
	return running
end

Env.OldHealthBar = api
