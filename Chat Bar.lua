--[[ CHAT BAR (Addtion-Scripts) ]]
-- Hammer stuff 2's "chatbar", for the old GUIs on a phone or tablet:
--   * 2012 / 2013 (and 2014): their chat script shows a "Chat" button on a touch screen ("ChatTouchFrame") instead
--     of its bar. This hides that button and puts back the bar they have on a PC: a black strip along the bottom
--     of the screen, "To chat click here or press "/" key". Tapping it (or "/") lets you type; sending puts the
--     message in the chat, the same way their own bar does.
--   * 2015 early: its chat makes that bar itself ("ChatBarContainer"), and E2015 Gui.lua keeps it hidden on
--     phones unless BPChatBar is set on NewRobloxGui. This sets it, and hides the Chat button
--     ("TouchDeviceChatButton").
-- Nothing is done for the 2013 mobile GUI or the 2011 GUI (it has its own bar), nor on a PC.
-- While the bar shows, nothing of the GUI is left under it: on a phone the 2012 / 2013 GUIs put their Menu / Exit
-- buttons and zoom buttons right at the bottom, and Bloxy's 2013 health bar sits 4 pixels from the bottom, all in
-- the bar's strip. Each such thing is lifted just enough to clear the bar (and put back when the bar goes).
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
local BAR_HEIGHT = 20 -- (the strip the old GUIs keep along the bottom for it)
local HINT = "To chat click here or press \"/\" key"

local on = false
local connections = {}
local gui, hint, box = nil, nil, nil
local hiddenButtons = setmetatable({}, { __mode = "k" }) -- the GUI's chat button -> its watcher
local markedGui = nil -- the 2015 early NewRobloxGui given BPChatBar

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

-- the 2011 GUI: it has its own bar
local function gui2011()
	for _, holder in ipairs(holders()) do
		if holder:FindFirstChild("Early2011Gui") then return true end
	end
	return false
end

-- The old GUI on screen and what to do there:
--   "own"  (2015 early): its chat made its own bar; it gets BPChatBar, and its Chat button (if any) is hidden
--   "ours" (2012 / 2013 / 2014): only a Chat button; it is hidden and our bar shown
-- (on a PC this changes nothing: 2015 early's bar always shows there, and the others make their bar, not the button)
local function findLegacy()
	if mobile2013() or gui2011() then return nil end
	for _, holder in ipairs(holders()) do
		for _, legacy in ipairs(holder:GetChildren()) do
			if legacy.Name == "NewRobloxGui" then
				if legacy:FindFirstChild("ChatBarContainer") then
					return "own", legacy, legacy:FindFirstChild("TouchDeviceChatButton")
				end
				local button = legacy:FindFirstChild("ChatTouchFrame", true)
				if button and not legacy:FindFirstChild("ClickToChat", true) then
					return "ours", legacy, button
				end
			end
		end
	end
	return nil
end

local function mark(legacy)
	if markedGui == legacy then return end
	if markedGui then pcall(function() markedGui:SetAttribute("BPChatBar", nil) end) end
	markedGui = legacy
	if legacy then pcall(function() legacy:SetAttribute("BPChatBar", true) end) end
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

-- LIFTING what the bar would cover: the GUI's own things along the bottom (Menu / Exit, the zoom buttons, the
-- Backpack button) and Bloxy's health bar (Old Health Bar's follows it). Each is moved up by as much as it reaches
-- into the bar's strip, plus 2 pixels. When something else moves it (the GUI after a new screen size, Old Gui Fix
-- putting 2012's health bar next to its Backpack button) it is let go, and looked at again a second later: lifted
-- from its new place only if that is still under the bar (so two scripts never keep moving the same thing).
local lifted = setmetatable({}, { __mode = "k" }) -- thing -> { base = its own position, ours = where we put it, conn }
local LIFT_GAP = 2

local function bottomGap(obj)
	local holder = obj:FindFirstAncestorWhichIsA("LayerCollector")
	if not (holder and holder:IsA("GuiBase2d")) then return nil end
	return (holder.AbsolutePosition.Y + holder.AbsoluteSize.Y) - (obj.AbsolutePosition.Y + obj.AbsoluteSize.Y), holder
end

local function liftOne(obj)
	if lifted[obj] or not obj:IsA("GuiObject") or not obj.Visible then return end
	local gap, holder = bottomGap(obj)
	if not gap then return end
	local need = BAR_HEIGHT + LIFT_GAP - gap
	if need <= 0 then return end -- (clear of the bar already)
	local size = obj.AbsoluteSize
	-- only small things along the bottom: not a whole-screen frame, window or shade
	if size.Y > holder.AbsoluteSize.Y * 0.4 or size.X > holder.AbsoluteSize.X * 0.7 or size.Y < 2 then return end
	local rec = { base = obj.Position, need = math.ceil(need) }
	local function ours()
		local b = rec.base
		return UDim2.new(b.X.Scale, b.X.Offset, b.Y.Scale, b.Y.Offset - rec.need)
	end
	rec.ours = ours()
	lifted[obj] = rec
	rec.conn = obj:GetPropertyChangedSignal("Position"):Connect(function()
		if obj.Position == rec.ours then return end -- (our own change)
		-- moved by something else: let go (the next look lifts it again only if it is still under the bar)
		pcall(function() rec.conn:Disconnect() end)
		if lifted[obj] == rec then lifted[obj] = nil end
	end)
	obj.Position = rec.ours
end

local function dropLifts()
	for obj, rec in pairs(lifted) do
		pcall(function() rec.conn:Disconnect() end)
		pcall(function()
			if obj.Position == rec.ours then obj.Position = rec.base end
		end)
	end
	table.clear(lifted)
end

local function liftAll(legacy)
	local controls = legacy:FindFirstChild("ControlFrame")
	for _, parent in ipairs({ legacy, controls }) do
		if parent then
			for _, child in ipairs(parent:GetChildren()) do
				if child:IsA("GuiObject") and child ~= controls then pcall(liftOne, child) end
			end
		end
	end
	for _, holder in ipairs(holders()) do
		local healthGui = holder:FindFirstChild("CustomHealthGui")
		local frame = healthGui and healthGui:FindFirstChild("HealthFrame")
		if frame then pcall(liftOne, frame) end
	end
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
	gui.DisplayOrder = 101 -- (just above the old GUIs, which are 100)
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
	local said = {}
	task.spawn(function()
		while on do
			local mode, legacy, button = findLegacy()
			mark(mode == "own" and legacy or nil)
			if button then
				pcall(hideButton, button)
			elseif not mode then
				showButtons()
			end
			local wanted = mode == "ours"
			if wanted then
				pcall(liftAll, legacy)
			else
				dropLifts()
			end
			if gui and gui.Enabled ~= wanted then
				gui.Enabled = wanted
				if not wanted and box and box:IsFocused() then pcall(function() box:ReleaseFocus() end) end
			end
			if mode and not said[mode] then
				said[mode] = true
				print(mode == "own" and "[Chat Bar] 2015 early: its chat bar along the bottom is shown, the Chat button hidden"
					or "[Chat Bar] the Chat button is now a chat bar along the bottom")
			end
			task.wait(1)
		end
	end)
	print("[Chat Bar] On: in the 2012 / 2013 / 2015 early GUIs on a touch screen the Chat button becomes a chat bar")
end

function api.Disable()
	on = false
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	table.clear(connections)
	mark(nil)
	showButtons()
	dropLifts()
	if gui then pcall(function() gui:Destroy() end) end
	gui, hint, box = nil, nil, nil
	print("[Chat Bar] Off: the GUI's own Chat button is back")
end

function api.IsOn()
	return on
end

Env.BPChatBar = api
api.Enable()
