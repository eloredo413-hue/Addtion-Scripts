--[[ CHAT BAR (Addtion-Scripts) ]]
-- Hammer stuff 2's "chatbar": the normal 2013 GUI shows a "Chat" button on a touch screen (its chat script makes
-- "ChatTouchFrame" there instead of its bar). This hides that button and puts back the bar the GUI has on a PC: a
-- black strip along the bottom of the screen, "To chat click here or press "/" key". Tapping it (or "/") lets
-- you type; sending puts the message in the chat, the same way its own bar does.
-- Only the normal 2013 GUI: nothing is done for the 2013 mobile GUI or any other, nor where the GUI already
-- shows its bar.
-- getgenv().BPChatBar = { Enable, Disable, IsOn }

local Env = (getgenv and getgenv()) or _G
if Env.BPChatBar and type(Env.BPChatBar.Disable) == "function" then
	pcall(Env.BPChatBar.Disable)
end

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")

local GUI_NAME = "ParadoxChatBar" -- ("Paradox" in the name: the game GUI hider leaves it alone)
local BAR_HEIGHT = 22
local HINT = "To chat click here or press \"/\" key"

local on = false
local connections = {}
local gui, hint, box = nil, nil, nil
local hiddenButtons = setmetatable({}, { __mode = "k" }) -- the GUI's chat button -> its watcher

local function connect(signal, fn)
	local ok, c = pcall(function() return signal:Connect(fn) end)
	if ok and c then table.insert(connections, c) end
	return c
end

local function topbarPick()
	for _, value in ipairs({ Env.BloxyTopbarPick, Env.BP_PendingTopbar, Env.BloxyTopbarRaw }) do
		if value ~= nil and tostring(value) ~= "" and tostring(value) ~= "nil" then
			return string.lower(tostring(value))
		end
	end
	return nil
end

local function holders()
	local list = { CoreGui }
	pcall(function()
		local hui = gethui and gethui()
		if hui and hui ~= CoreGui then table.insert(list, hui) end
	end)
	pcall(function()
		local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if playerGui then table.insert(list, playerGui) end
	end)
	return list
end

-- the 2013 mobile GUI: left alone
local function mobile2013()
	local pick = topbarPick()
	if pick and string.find(pick, "mobile", 1, true) then return true end
	for _, holder in ipairs(holders()) do
		if holder:FindFirstChild("LegacyTouchControls") or holder:FindFirstChild("LegacyMobileUI_FunctionalReplacement") then
			return true
		end
	end
	return false
end

-- the normal 2013 GUI: the topbar picked, else its make-up (the 2012 one has a Resizer and a ToolTip, the 2014
-- one a HealthScript and a ToolTip; the 2013 one none of them)
local function is2013(legacy)
	local pick = topbarPick()
	local year = pick and tonumber(string.match(pick, "(20%d%d)"))
	if year then return year == 2013 and not string.find(pick, "mobile", 1, true) end
	return legacy:FindFirstChild("ControlFrame") ~= nil and legacy:FindFirstChild("Resizer") == nil
		and legacy:FindFirstChild("ToolTip") == nil and legacy:FindFirstChild("HealthScript") == nil
		and legacy:FindFirstChild("Topbar") == nil
end

-- the normal 2013 GUI, when it shows its chat button and not its bar
local function legacyWithButton()
	for _, holder in ipairs(holders()) do
		local legacy = holder:FindFirstChild("NewRobloxGui")
		if legacy and is2013(legacy) then
			local button = legacy:FindFirstChild("ChatTouchFrame", true)
			local ownBar = legacy:FindFirstChild("ClickToChat", true)
			if button and not ownBar then return legacy, button end
		end
	end
	return nil
end

local function hideButton(button)
	if hiddenButtons[button] then return end
	button.Visible = false
	hiddenButtons[button] = button:GetPropertyChangedSignal("Visible"):Connect(function()
		if on and button.Visible then button.Visible = false end
	end)
end

local function showButtons()
	for button, watcher in pairs(hiddenButtons) do
		pcall(function() watcher:Disconnect() end)
		pcall(function() button.Visible = true end)
	end
	table.clear(hiddenButtons)
end

local function send(text)
	text = string.gsub(text or "", "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	if text == "" then return end
	task.spawn(function()
		local sent = false
		pcall(function()
			if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
				local channels = TextChatService:FindFirstChild("TextChannels")
				local general = channels and channels:FindFirstChild("RBXGeneral")
				if general then
					general:SendAsync(text)
					sent = true
				end
			end
		end)
		if not sent then
			-- (the old chat)
			pcall(function()
				local events = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
				local request = events and events:FindFirstChild("SayMessageRequest")
				if request then request:FireServer(text, "All") end
			end)
		end
	end)
end

local function makeBar()
	gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 101 -- (just above the 2013 GUI, which is 100)
	gui.Enabled = false

	box = Instance.new("TextBox")
	box.Name = "ChatBar"
	box.AnchorPoint = Vector2.new(0, 1)
	box.Position = UDim2.new(0, 0, 1, 0)
	box.Size = UDim2.new(1, 0, 0, BAR_HEIGHT)
	box.BackgroundColor3 = Color3.new(0, 0, 0)
	box.BackgroundTransparency = 0.25
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Text = ""
	box.TextColor3 = Color3.new(1, 1, 1)
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Font = Enum.Font.Arial
	box.TextSize = 14
	box.ZIndex = 1
	box.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.Parent = box

	hint = Instance.new("TextButton")
	hint.Name = "ClickToChat"
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.new(0, 4, 1, 0)
	hint.Size = UDim2.new(1, -4, 0, BAR_HEIGHT)
	hint.BackgroundTransparency = 1
	hint.Text = HINT
	hint.TextColor3 = Color3.new(1, 1, 0.9)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Font = Enum.Font.Arial
	hint.TextSize = 14
	hint.ZIndex = 2
	hint.Parent = gui

	local function focus()
		if not (gui and gui.Enabled) then return end
		hint.Visible = false
		box:CaptureFocus()
	end
	connect(hint.MouseButton1Click, focus)
	connect(box.Focused, function() hint.Visible = false end)
	connect(box.FocusLost, function(enterPressed)
		if enterPressed then send(box.Text) end
		box.Text = ""
		hint.Visible = true
	end)
	connect(UserInputService.InputBegan, function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.Slash then return end
		task.wait(0.05)
		focus()
	end)

	local ok = pcall(function() gui.Parent = CoreGui end)
	if not ok or not gui.Parent then
		local hui = nil
		pcall(function() hui = gethui and gethui() end)
		gui.Parent = hui or (Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui"))
	end
end

local api = {}

function api.Enable()
	if on then return end
	on = true
	makeBar()
	local said = false
	task.spawn(function()
		while on do
			local wanted = false
			if not mobile2013() then
				local legacy, button = legacyWithButton()
				if legacy then
					wanted = true
					pcall(hideButton, button)
				end
			end
			if not wanted then showButtons() end
			if gui and gui.Enabled ~= wanted then
				gui.Enabled = wanted
				if not wanted and box and box:IsFocused() then pcall(function() box:ReleaseFocus() end) end
			end
			if wanted and not said then
				said = true
				print("[Chat Bar] the 2013 chat button is now a chat bar along the bottom")
			end
			task.wait(1)
		end
	end)
	print("[Chat Bar] On: in the normal 2013 GUI on a touch screen the chat button becomes a chat bar")
end

function api.Disable()
	on = false
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	table.clear(connections)
	showButtons()
	if gui then pcall(function() gui:Destroy() end) end
	gui, hint, box = nil, nil, nil
	print("[Chat Bar] Off: the GUI's own chat button is back")
end

function api.IsOn()
	return on
end

Env.BPChatBar = api
api.Enable()
