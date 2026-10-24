--========================================================
-- 2008 BUBBLECHAT - UNIVERSAL CUSTOM BUBBLE REPLACER
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
-- CREATE 2008 BUBBLE
--========================================================
local function createBubble(player, text)
	if not player then return end
	if not text or text == "" then return end
	local character = player.Character
	if not character then return end
	local head = character:FindFirstChild("Head")
	if not head then return end
	removeCharacterBubbles(character)
	for _, object in ipairs(head:GetChildren()) do
		if object.Name == BUBBLE_NAME then
			object:Destroy()
		end
	end

	local fontSize = 20
	local maxWidth = 220
	local measured = TextService:GetTextSize(
		text, fontSize, Enum.Font.Arial, Vector2.new(maxWidth, 1000)
	)
	local bubbleWidth = math.clamp(measured.X + 24, 42, maxWidth + 24)
	local bubbleHeight = measured.Y + 24
	local tailWidth = 16
	local tailHeight = 19

	local gui = Instance.new("BillboardGui")
	gui.Name = BUBBLE_NAME
	gui.Adornee = head
	gui.Size = UDim2.new(0, bubbleWidth, 0, bubbleHeight + tailHeight)
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.SizeOffset = Vector2.new(0, 0.5)
	gui.MaxDistance = MAX_DISTANCE
	gui.AlwaysOnTop = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global

	local body = Instance.new("ImageLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Image = "rbxassetid://2582470061"
	body.ScaleType = Enum.ScaleType.Slice
	body.SliceCenter = Rect.new(29, 29, 67, 67)
	body.SliceScale = 0.4
	body.Size = UDim2.new(1, 0, 0, bubbleHeight)
	body.ZIndex = 2
	body.Parent = gui

	local tail = Instance.new("ImageLabel")
	tail.Name = "Tail"
	tail.BackgroundTransparency = 1
	tail.Image = "rbxassetid://2582470060"
	tail.Size = UDim2.new(0, tailWidth, 0, tailHeight)
	tail.Position = UDim2.new(0.5, -tailWidth / 2, 0, bubbleHeight - 6)
	tail.ZIndex = 4
	tail.Parent = gui

	local connector = Instance.new("Frame")
	connector.Name = "Connector"
	connector.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	connector.BorderSizePixel = 0
	connector.Size = UDim2.new(0, 10, 0, 6)
	connector.Position = UDim2.new(0.5, -5, 0, -4)
	connector.ZIndex = 3
	connector.Parent = tail

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.FontFace = Font.new(
		"rbxasset://fonts/families/Arial.json",
		Enum.FontWeight.Regular,
		Enum.FontStyle.Normal
	)
	label.TextSize = fontSize
	label.TextColor3 = Color3.fromRGB(0, 0, 0)
	label.TextWrapped = true
	label.Text = text
	label.Size = UDim2.new(1, -16, 0, measured.Y)
	label.Position = UDim2.new(0, 8, 0, 12)
	label.ZIndex = 10
	label.Parent = gui

	gui.Parent = head

	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not gui.Parent then
			if connection then connection:Disconnect() end
			return
		end
		removeCharacterBubbles(character)
		local camera = workspace.CurrentCamera
		if not camera then return end
		local distance = (camera.CFrame.Position - head.Position).Magnitude
		if distance > DOT_DISTANCE then
			label.Text = "..."
			label.Size = UDim2.new(1, -16, 0, 20)
			label.Position = UDim2.new(0, 8, 0, 9)
			gui.Size = UDim2.new(0, 52, 0, 38 + tailHeight)
			body.Size = UDim2.new(1, 0, 0, 38)
			tail.Position = UDim2.new(0.5, -tailWidth / 2, 0, 32)
		else
			label.Text = text
			label.Size = UDim2.new(1, -16, 0, measured.Y)
			label.Position = UDim2.new(0, 8, 0, 12)
			gui.Size = UDim2.new(0, bubbleWidth, 0, bubbleHeight + tailHeight)
			body.Size = UDim2.new(1, 0, 0, bubbleHeight)
			tail.Position = UDim2.new(0.5, -tailWidth / 2, 0, bubbleHeight - 6)
		end
	end)

	task.delay(LIFETIME, function()
		if connection then connection:Disconnect() end
		if gui and gui.Parent then gui:Destroy() end
	end)
end

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