--========================================================
-- 2008 BUBBLECHAT - UNIVERSAL CUSTOM BUBBLE REPLACER
-- Bubbles fade in, stack (older ones above, greyed), and fade out
--========================================================
-- FIXED: only runs for 2012/2013/2014 topbars (or manual override)
-- Now includes 2013 mobile

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local TextChatService = game:GetService("TextChatService")
local Chat = game:GetService("Chat")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local BUBBLE_NAME = "__2008_CLASSIC_BUBBLE"
local MAX_DISTANCE = 75
local DOT_DISTANCE = 52
local LIFETIME = 20

--========================================================
-- GUARD — ONLY RUN FOR 2012/2013/2014/2013 mobile
--========================================================
local function shouldRun()
	-- Manual override flag (check getgenv first — _G isn't always shared)
	local forced = getgenv().Force2008BubbleChat
	if forced == nil then
		forced = _G.Force2008BubbleChat
	end
	if forced ~= nil then
		print("[2008 BubbleChat] Manual override = " .. tostring(forced))
		return forced == true
	end

	-- Pending topbar flag — any non-2013mobile value blocks immediately
	local pending = getgenv().BP_PendingTopbar
	if pending ~= nil then
		if pending == "2013mobile" then
			print("[2008 BubbleChat] Pending 2013 mobile — ACTIVATING.")
			return true
		else
			print("[2008 BubbleChat] Pending '" .. tostring(pending) .. "' — SKIPPING.")
			return false
		end
	end

	local topbar = nil
	local cfg = nil

	if readfile and isfile and isfile("BloxyParadoxConfig.json") then
		local ok, result = pcall(function()
			return HttpService:JSONDecode(readfile("BloxyParadoxConfig.json"))
		end)
		if ok and type(result) == "table" then
			cfg = result
		else
			print("[2008 BubbleChat] Config file exists but could not be parsed.")
		end
	else
		print("[2008 BubbleChat] No config file found.")
	end

	if cfg then
		topbar = (cfg.Choices and cfg.Choices.Topbar)
			or cfg.Topbar
			or cfg.topbar
			or cfg.TopbarChoice
			or cfg.topbarChoice
	end

	print("[2008 BubbleChat] Detected topbar: " .. tostring(topbar))

	if topbar == "2012" or topbar == "2013" or topbar == "2014" then
		return true
	end

	if topbar == "2013 mobile" or topbar == "2013mobile" or topbar == "2013_mobile" then
		return true
	end

	if cfg then
		local alt = (cfg.Choices and cfg.Choices.TopbarID) or cfg.TopbarID
		if alt == "2013mobile" or alt == "2013 mobile" then
			return true
		end
	end

	return false
end

if not shouldRun() then
	print("[2008 BubbleChat] SKIPPED — topbar does not match.")
	return
end

print("[2008 BubbleChat] ACTIVATING — topbar matches.")

--========================================================
-- DISABLE ROBLOX BUBBLE CHAT
--========================================================
pcall(function()
	local config = TextChatService:FindFirstChild("BubbleChatConfiguration")
	if config then
		config.Enabled = false
	end
end)
pcall(function()
	Chat:SetBubbleChatEnabled(false)
end)

--========================================================
-- CHARACTER LOOKUP
--========================================================
local function findCharacter(object)
	if not object then return nil end
	local current = object
	while current and current ~= game do
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildOfClass("Humanoid")
			if humanoid then return current end
		end
		current = current.Parent
	end
	return nil
end

--========================================================
-- IS THIS GUI ATTACHED TO A PLAYER?
--========================================================
local function guiBelongsToCharacter(gui)
	if not gui then return false end
	if gui:IsA("BillboardGui") then
		if gui.Adornee then
			local character = findCharacter(gui.Adornee)
			if character then return true end
		end
	end
	if gui:IsA("SurfaceGui") then
		if gui.Adornee then
			local character = findCharacter(gui.Adornee)
			if character then return true end
		end
	end
	local character = findCharacter(gui)
	if character then return true end
	return false
end

--========================================================
-- REMOVE GUI
--========================================================
local function removeGUI(gui)
	if not gui then return end
	if gui.Name == BUBBLE_NAME then return end
	pcall(function()
		gui:Destroy()
	end)
end

--========================================================
-- FIND AND REMOVE EXISTING BUBBLES
--========================================================
local function removeCharacterBubbles(character)
	if not character then return end
	for _, object in ipairs(character:GetDescendants()) do
		if object.Name == BUBBLE_NAME then continue end
		if object:IsA("BillboardGui") or object:IsA("SurfaceGui") then
			removeGUI(object)
		end
	end
end

--========================================================
-- REMOVE BILLBOARD/SURFACE GUI ATTACHED TO CHARACTERS
--========================================================
local function scanWorkspace()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			removeCharacterBubbles(character)
		end
	end
end

--========================================================
-- REMOVE PLAYERGUI BUBBLES
--========================================================
local function scanPlayerGui()
	for _, player in ipairs(Players:GetPlayers()) do
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		if playerGui then
			for _, object in ipairs(playerGui:GetDescendants()) do
				if object.Name == BUBBLE_NAME then continue end
				if object:IsA("BillboardGui") or object:IsA("SurfaceGui") then
					if guiBelongsToCharacter(object) then
						removeGUI(object)
					end
				end
			end
		end
	end
end

--========================================================
-- CREATE 2008 BUBBLE (stacked, with fade in / fade out)
--========================================================
-- Like the classic bubble chat: a new message fades in under the
-- player's older messages, which stay above it with faded text and
-- no tail. Each message fades out when its lifetime ends.
local TweenService = game:GetService("TweenService")

local MAX_BUBBLES = 3              -- messages shown at once per player
local BUBBLE_GAP = 2               -- pixels between stacked bubbles
local FADE_IN_TIME = 0.2
local FADE_OUT_TIME = 0.3
local OLD_TEXT_TRANSPARENCY = 0.5  -- older messages: greyed-out text
local FONT_SIZE = 20
local MAX_WIDTH = 220
local TAIL_WIDTH = 16
local TAIL_HEIGHT = 19
local DOTS_WIDTH = 52
local DOTS_HEIGHT = 38

local stacks = {} -- [player] = { gui, head, tail, connector, entries, far, connection }

local function tween(object, duration, properties)
	local t = TweenService:Create(
		object,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		properties
	)
	t:Play()
	return t
end

local function setTailTransparency(stack, value, duration)
	if duration and duration > 0 then
		tween(stack.tail, duration, { ImageTransparency = value })
		tween(stack.connector, duration, { BackgroundTransparency = value })
	else
		stack.tail.ImageTransparency = value
		stack.connector.BackgroundTransparency = value
	end
end

-- Places the bubbles from the bottom up; the newest one sits on the tail.
local function layout(stack)
	local gui = stack.gui
	local entries = stack.entries
	local count = #entries
	if count == 0 then return end

	if stack.far then
		-- far away: only the newest bubble, shown as "..."
		for i, entry in ipairs(entries) do
			local newest = i == count
			entry.frame.Visible = newest
			if newest then
				entry.label.Text = "..."
				entry.label.Size = UDim2.new(1, -16, 0, 20)
				entry.label.Position = UDim2.new(0, 8, 0, 9)
				entry.frame.Size = UDim2.new(0, DOTS_WIDTH, 0, DOTS_HEIGHT)
				entry.frame.Position = UDim2.new(0.5, -DOTS_WIDTH / 2, 0, 0)
			end
		end
		gui.Size = UDim2.new(0, DOTS_WIDTH, 0, DOTS_HEIGHT + TAIL_HEIGHT)
		stack.tail.Position = UDim2.new(0.5, -TAIL_WIDTH / 2, 0, DOTS_HEIGHT - 6)
		return
	end

	local width, total = 0, 0
	for i, entry in ipairs(entries) do
		width = math.max(width, entry.width)
		total = total + entry.height
		if i > 1 then total = total + BUBBLE_GAP end
	end
	gui.Size = UDim2.new(0, width, 0, total + TAIL_HEIGHT)

	local y = total
	for i = count, 1, -1 do
		local entry = entries[i]
		y = y - entry.height
		entry.frame.Visible = true
		entry.frame.Size = UDim2.new(0, entry.width, 0, entry.height)
		entry.frame.Position = UDim2.new(0.5, -entry.width / 2, 0, y)
		entry.label.Text = entry.text
		entry.label.Size = UDim2.new(1, -16, 0, entry.textHeight)
		entry.label.Position = UDim2.new(0, 8, 0, 12)
		y = y - BUBBLE_GAP
	end
	stack.tail.Position = UDim2.new(0.5, -TAIL_WIDTH / 2, 0, total - 6)
end

local function destroyStack(player)
	local stack = stacks[player]
	if not stack then return end
	stacks[player] = nil
	if stack.connection then stack.connection:Disconnect() end
	if stack.gui then pcall(function() stack.gui:Destroy() end) end
end

local function removeEntry(stack, entry)
	if entry.removed then return end
	entry.removed = true
	local index = table.find(stack.entries, entry)
	if index then table.remove(stack.entries, index) end
	pcall(function() entry.frame:Destroy() end)
	if stacks[stack.player] ~= stack then return end
	if #stack.entries == 0 then
		destroyStack(stack.player)
	else
		layout(stack)
	end
end

local function getStack(player, character, head)
	local existing = stacks[player]
	if existing and existing.head == head and existing.gui.Parent then
		return existing
	end
	destroyStack(player)

	-- leftovers (e.g. from an earlier run of this script)
	for _, object in ipairs(head:GetChildren()) do
		if object.Name == BUBBLE_NAME then
			object:Destroy()
		end
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = BUBBLE_NAME
	gui.Adornee = head
	gui.Size = UDim2.new(0, DOTS_WIDTH, 0, DOTS_HEIGHT + TAIL_HEIGHT)
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.SizeOffset = Vector2.new(0, 0.5)
	gui.MaxDistance = MAX_DISTANCE
	gui.AlwaysOnTop = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global

	local tail = Instance.new("ImageLabel")
	tail.Name = "Tail"
	tail.BackgroundTransparency = 1
	tail.Image = "rbxassetid://2582470060"
	tail.ImageTransparency = 1
	tail.Size = UDim2.new(0, TAIL_WIDTH, 0, TAIL_HEIGHT)
	tail.ZIndex = 4
	tail.Parent = gui

	local connector = Instance.new("Frame")
	connector.Name = "Connector"
	connector.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	connector.BackgroundTransparency = 1
	connector.BorderSizePixel = 0
	connector.Size = UDim2.new(0, 10, 0, 6)
	connector.Position = UDim2.new(0.5, -5, 0, -4)
	connector.ZIndex = 3
	connector.Parent = tail

	local stack = {
		player = player,
		gui = gui,
		head = head,
		tail = tail,
		connector = connector,
		entries = {},
		far = false,
	}

	stack.connection = RunService.RenderStepped:Connect(function()
		if not gui.Parent then
			if stacks[player] == stack then
				destroyStack(player)
			elseif stack.connection then
				stack.connection:Disconnect()
			end
			return
		end
		removeCharacterBubbles(character)
		local camera = workspace.CurrentCamera
		if not camera then return end
		local far = (camera.CFrame.Position - head.Position).Magnitude > DOT_DISTANCE
		if far ~= stack.far then
			stack.far = far
			layout(stack)
		end
	end)

	stacks[player] = stack
	gui.Parent = head
	return stack
end

local function createBubble(player, text)
	if not player then return end
	if not text or text == "" then return end
	local character = player.Character
	if not character then return end
	local head = character:FindFirstChild("Head")
	if not head then return end
	removeCharacterBubbles(character)

	local stack = getStack(player, character, head)

	-- older messages: keep them above, grey out their text
	for _, old in ipairs(stack.entries) do
		if not old.fadingOut then
			tween(old.label, FADE_IN_TIME, { TextTransparency = OLD_TEXT_TRANSPARENCY })
		end
	end

	-- too many: the oldest goes right away
	while #stack.entries >= MAX_BUBBLES do
		removeEntry(stack, stack.entries[1])
	end
	if stacks[player] ~= stack then
		stack = getStack(player, character, head)
	end

	local measured = TextService:GetTextSize(
		text, FONT_SIZE, Enum.Font.Arial, Vector2.new(MAX_WIDTH, 1000)
	)

	local frame = Instance.new("Frame")
	frame.Name = "Bubble"
	frame.BackgroundTransparency = 1

	local body = Instance.new("ImageLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Image = "rbxassetid://2582470061"
	body.ImageTransparency = 1
	body.ScaleType = Enum.ScaleType.Slice
	body.SliceCenter = Rect.new(29, 29, 67, 67)
	body.SliceScale = 0.4
	body.Size = UDim2.new(1, 0, 1, 0)
	body.ZIndex = 2
	body.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.FontFace = Font.new(
		"rbxasset://fonts/families/Arial.json",
		Enum.FontWeight.Regular,
		Enum.FontStyle.Normal
	)
	label.TextSize = FONT_SIZE
	label.TextColor3 = Color3.fromRGB(0, 0, 0)
	label.TextTransparency = 1
	label.TextWrapped = true
	label.Text = text
	label.ZIndex = 10
	label.Parent = frame

	local entry = {
		text = text,
		width = math.clamp(measured.X + 24, 42, MAX_WIDTH + 24),
		height = measured.Y + 24,
		textHeight = measured.Y,
		frame = frame,
		body = body,
		label = label,
	}
	table.insert(stack.entries, entry)
	frame.Parent = stack.gui
	layout(stack)

	-- fade in
	tween(body, FADE_IN_TIME, { ImageTransparency = 0 })
	tween(label, FADE_IN_TIME, { TextTransparency = 0 })
	setTailTransparency(stack, 0, FADE_IN_TIME)

	-- fade out when the lifetime ends
	task.delay(LIFETIME, function()
		if entry.removed then return end
		entry.fadingOut = true
		tween(body, FADE_OUT_TIME, { ImageTransparency = 1 })
		tween(label, FADE_OUT_TIME, { TextTransparency = 1 })
		if #stack.entries == 1 and stack.entries[1] == entry then
			setTailTransparency(stack, 1, FADE_OUT_TIME)
		end
		task.wait(FADE_OUT_TIME)
		removeEntry(stack, entry)
	end)
end

Players.PlayerRemoving:Connect(destroyStack)

--========================================================
-- CHAT MESSAGE HANDLER
--========================================================
local lastMessages = {}
local function receiveMessage(player, text)
	if not player then return end
	if typeof(text) ~= "string" then return end
	if text == "" then return end
	local key = tostring(player.UserId) .. ":" .. text
	if lastMessages[key] then return end
	lastMessages[key] = true
	task.delay(0.25, function()
		lastMessages[key] = nil
	end)
	if player.Character then
		removeCharacterBubbles(player.Character)
	end
	createBubble(player, text)
end

--========================================================
-- PLAYER.CHATTED
--========================================================
local function hookPlayer(player)
	player.Chatted:Connect(function(text)
		receiveMessage(player, text)
	end)
	player.CharacterAdded:Connect(function(character)
		task.wait(0.2)
		removeCharacterBubbles(character)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	hookPlayer(player)
end
Players.PlayerAdded:Connect(hookPlayer)

--========================================================
-- TEXT CHAT
--========================================================
pcall(function()
	TextChatService.MessageReceived:Connect(function(message)
		if not message then return end
		if not message.TextSource then return end
		local player = Players:GetPlayerByUserId(message.TextSource.UserId)
		if player then
			receiveMessage(player, message.Text)
		end
	end)
end)

--========================================================
-- CONTINUOUS GUI INTERCEPTOR
--========================================================
local function watchContainer(container)
	container.DescendantAdded:Connect(function(object)
		if object.Name == BUBBLE_NAME then return end
		if object:IsA("BillboardGui") or object:IsA("SurfaceGui") then
			task.defer(function()
				if not object.Parent then return end
				if guiBelongsToCharacter(object) then
					removeGUI(object)
				end
			end)
		end
	end)
end

watchContainer(workspace)

for _, player in ipairs(Players:GetPlayers()) do
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if gui then
		watchContainer(gui)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.ChildAdded:Connect(function(child)
		if child:IsA("PlayerGui") then
			watchContainer(child)
		end
	end)
end)

--========================================================
-- BACKUP CLEANUP
--========================================================
task.spawn(function()
	while true do
		task.wait(0.15)
		scanWorkspace()
		scanPlayerGui()
	end
end)

--========================================================
-- INITIAL CLEANUP
--========================================================
scanWorkspace()
scanPlayerGui()

print("[2008 BubbleChat] Universal replacer loaded.")