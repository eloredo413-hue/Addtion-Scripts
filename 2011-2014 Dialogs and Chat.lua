--========================================================
-- 2011-2014 DIALOGS AND CHAT (standalone)
-- The loader's 2011-2014 chat bubbles and classic NPC dialogs, on their own: paste this in
-- your executor and run it in any game. No Bloxy or topbar needed.
--
-- CHAT BUBBLES (the 2014 look)
-- + White bubbles over players' heads: Arial 22 in a tight bubble with a grey edge and a tail
-- + A new message goes at the bottom with the tail; up to 3 messages, older ones above in grey
-- + Farther than 52 studs: just "..."; no fading, like 2011-2014
-- + Roblox's own chat bubbles (both chat systems) and the game's own ones on players are hidden
--
-- NPC DIALOGS (classic)
-- + The old dialog icons over NPCs (neutral / friendly / enemy, and quest / help / shop)
-- + Tap or click one: the NPC's line in a classic bubble, your choices in the classic box at the
--   bottom left, your answer in a bubble over you, then the NPC's reply
-- + Walking away ends the chat ("Chat ended because you walked away")
-- + Roblox's own dialog icons on those NPCs are switched off while this runs
--
-- Run it again to restart it. To stop everything and get Roblox's own bubbles and dialogs back:
--   getgenv().ClassicDialogsAndChatStop()
-- It uses the same slots as the loader's own copies, so it replaces them if they are running.
--========================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local getgenv = getgenv or function() return _G end
local pg = Players.LocalPlayer:WaitForChild("PlayerGui")

-- an earlier run of this script is stopped first
if type(getgenv().ClassicDialogsAndChatStop) == "function" then
    pcall(getgenv().ClassicDialogsAndChatStop)
end

local dialogLoaded_Classic = false

--========================================================
-- ROBLOX'S OWN CHAT BUBBLES OFF (new chat's bubbles, and any in CoreGui)
--========================================================
local nativeBubblesHidden = false
local hiddenNativeBubbles = {}
local savedBubbleEnabled = nil

local function sweepNativeBubbles()
    pcall(function()
        for _, obj in ipairs(CoreGui:GetDescendants()) do
            if obj:IsA("BillboardGui") and obj.Enabled
               and not obj:GetAttribute("ClassicOwned")
               and string.find(string.lower(obj.Name), "bubble", 1, true) then
                obj.Enabled = false
                hiddenNativeBubbles[obj] = true
            end
        end
    end)
end

local function setNativeBubbles(hide)
    if hide then
        nativeBubblesHidden = true
        pcall(function()
            local cfg = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
            if cfg then
                if savedBubbleEnabled == nil then savedBubbleEnabled = cfg.Enabled end
                cfg.Enabled = false
            end
        end)
        sweepNativeBubbles()
    elseif nativeBubblesHidden then
        nativeBubblesHidden = false
        pcall(function()
            local cfg = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
            if cfg and savedBubbleEnabled ~= nil then cfg.Enabled = savedBubbleEnabled end
            savedBubbleEnabled = nil
        end)
        for obj in pairs(hiddenNativeBubbles) do
            pcall(function() obj.Enabled = true end)
        end
        hiddenNativeBubbles = {}
    end
end

--========================================================
-- KEPT DIALOG BOX
-- When the loader ran first, it moved Roblox's own dialog box into a GUI of its own
-- (DialogBoxHost); it is switched off here so it doesn't show next to the classic dialogs.
--========================================================
local function setDialogBoxShown(shown)
    local hui = nil
    pcall(function() hui = gethui and gethui() end)
    for _, container in ipairs({ CoreGui, hui }) do
        local kept = container and container:FindFirstChild("DialogBoxHost")
        if kept then pcall(function() kept.Enabled = shown end) end
    end
end

--========================================================
-- CHAT BUBBLES
--========================================================
local function startClassicBubbles()
    if getgenv().ClassicBubbleCleanup then pcall(getgenv().ClassicBubbleCleanup) end

    local Chat = game:GetService("Chat")

    local BUBBLE_NAME = "__CLASSIC_2011_BUBBLE"
    local MAX_DISTANCE = 75
    local DOT_DISTANCE = 52          -- farther than this: the newest bubble shows "..."
    -- How long a message stays up is Roblox's own rule from its bubble chat script (BubbleChat.lua):
    -- your own messages 8 s (a short one) to 15 s (75 characters or more), other players' 12 to
    -- 20 s. It used to be 20 s for everything, the longest of those. No fade, like 2011.
    local function bubbleLifetime(text, isSelf)
        local t = math.min(#text / 75, 1)
        if isSelf then return 8 + 7 * t end
        return 12 + 8 * t
    end
    local MAX_BUBBLES = 3            -- messages shown at once per player
    local BUBBLE_GAP = 0             -- the bubble picture's own edge already leaves a gap between stacked bubbles
    -- Sizes from a real 2014 bubble (measured on a 2014 screenshot): Arial 22 in a tight bubble
    -- (about 9 px of white above the letters, 8 below and 5 to 6 at the sides), rounder corners and a
    -- slightly thicker grey edge, and a slightly longer tail. Before, the text was 20 with more white round it.
    local FONT_SIZE = 22
    local MAX_WIDTH = 240            -- where long messages wrap (as many letters per line as before)
    local PAD_X, PAD_Y = 24, 22      -- the bubble frame is the text's size plus these
    local TEXT_Y = 11                -- the text's top inside the bubble frame
    local BODY_SLICE_SCALE = 0.5     -- the bubble picture's corners and edge (0.4 before)
    local TAIL_OVERLAP = 8           -- how far the tail's top goes up into the bubble frame
    local TAIL_WIDTH, TAIL_HEIGHT = 18, 21
    local DOTS_WIDTH, DOTS_HEIGHT = 52, FONT_SIZE + PAD_Y
    local TEXT_COLOR = Color3.fromRGB(0, 0, 0)
    local OLD_TEXT_COLOR = Color3.fromRGB(160, 160, 160)

    local running = true
    local connections = {}
    local stacks = {}                -- player -> { gui, head, tail, entries, far, connection }
    local lastMessages = {}

    -- the old (legacy) bubble chat is switched off while these bubbles run
    local savedLegacyBubbles = nil
    pcall(function()
        savedLegacyBubbles = Chat.BubbleChatEnabled
        Chat:SetBubbleChatEnabled(false)
    end)

    -- a player's character (not an NPC, so NPC dialog icons are never touched)
    local function playerCharacterOf(object)
        local current = object
        while current and current ~= game do
            if current:IsA("Model") and Players:GetPlayerFromCharacter(current) then return current end
            current = current.Parent
        end
        return nil
    end

    -- Only BillboardGuis are chat bubbles. A SurfaceGui is never one, and was being deleted
    -- along with them (the 2006 avatar's T-shirt is a SurfaceGui on the torso, so it never
    -- stayed). Guis marked ClassicOwned, and the health bars from Hammer stuff 2, are left alone.
    local KEEP_NAMES = { CustomExecutorHealth = true }
    local function isForeignBubble(object)
        return object.ClassName == "BillboardGui"
            and object.Name ~= BUBBLE_NAME
            and not KEEP_NAMES[object.Name]
            and not object:GetAttribute("ClassicOwned")
    end

    local function belongsToPlayerCharacter(object)
        if object.Adornee and playerCharacterOf(object.Adornee) then return true end
        return playerCharacterOf(object) ~= nil
    end

    -- other bubble guis on a player's character (the game's own chat bubbles)
    local function removeCharacterBubbles(character)
        if not character then return end
        for _, object in ipairs(character:GetDescendants()) do
            if isForeignBubble(object) then pcall(function() object:Destroy() end) end
        end
    end

    -- places the bubbles from the bottom up; the newest one sits on the tail
    local function layout(stack)
        local entries = stack.entries
        local count = #entries
        if count == 0 then return end

        if stack.far then
            for i, entry in ipairs(entries) do
                local newest = i == count
                entry.frame.Visible = newest
                if newest then
                    entry.label.Text = "..."
                    entry.label.Size = UDim2.new(1, -16, 0, FONT_SIZE)
                    entry.label.Position = UDim2.new(0, 8, 0, TEXT_Y)
                    entry.frame.Size = UDim2.new(0, DOTS_WIDTH, 0, DOTS_HEIGHT)
                    entry.frame.Position = UDim2.new(0.5, -DOTS_WIDTH / 2, 0, 0)
                end
            end
            stack.gui.Size = UDim2.new(0, DOTS_WIDTH, 0, DOTS_HEIGHT + TAIL_HEIGHT)
            stack.tail.Position = UDim2.new(0.5, -TAIL_WIDTH / 2, 0, DOTS_HEIGHT - TAIL_OVERLAP)
            return
        end

        local width, total = 0, 0
        for i, entry in ipairs(entries) do
            width = math.max(width, entry.width)
            total = total + entry.height
            if i > 1 then total = total + BUBBLE_GAP end
        end
        stack.gui.Size = UDim2.new(0, width, 0, total + TAIL_HEIGHT)

        local y = total
        for i = count, 1, -1 do
            local entry = entries[i]
            y = y - entry.height
            entry.frame.Visible = true
            entry.frame.Size = UDim2.new(0, entry.width, 0, entry.height)
            entry.frame.Position = UDim2.new(0.5, -entry.width / 2, 0, y)
            entry.label.Text = entry.text
            entry.label.Size = UDim2.new(1, -16, 0, entry.textHeight)
            entry.label.Position = UDim2.new(0, 8, 0, TEXT_Y)
            y = y - BUBBLE_GAP
        end
        stack.tail.Position = UDim2.new(0.5, -TAIL_WIDTH / 2, 0, total - TAIL_OVERLAP)
    end

    local function destroyStack(player)
        local stack = stacks[player]
        if not stack then return end
        stacks[player] = nil
        if stack.connection then stack.connection:Disconnect() end
        pcall(function() stack.gui:Destroy() end)
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

    local function getStack(player, head)
        local existing = stacks[player]
        if existing and existing.head == head and existing.gui.Parent then return existing end
        destroyStack(player)

        for _, object in ipairs(head:GetChildren()) do
            if object.Name == BUBBLE_NAME then object:Destroy() end
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
        tail.Size = UDim2.new(0, TAIL_WIDTH, 0, TAIL_HEIGHT)
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

        local stack = { player = player, gui = gui, head = head, tail = tail, entries = {}, far = false }

        stack.connection = RunService.RenderStepped:Connect(function()
            if not gui.Parent then
                if stacks[player] == stack then destroyStack(player) else stack.connection:Disconnect() end
                return
            end
            local cam = Workspace.CurrentCamera
            if not cam then return end
            local far = (cam.CFrame.Position - head.Position).Magnitude > DOT_DISTANCE
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
        local character = player.Character
        local head = character and character:FindFirstChild("Head")
        if not head then return end
        removeCharacterBubbles(character)

        local stack = getStack(player, head)

        -- older messages stay above, with grey text
        for _, old in ipairs(stack.entries) do
            old.label.TextColor3 = OLD_TEXT_COLOR
        end
        -- too many: the oldest goes
        while #stack.entries >= MAX_BUBBLES do
            removeEntry(stack, stack.entries[1])
        end

        local measured = TextService:GetTextSize(text, FONT_SIZE, Enum.Font.Arial, Vector2.new(MAX_WIDTH, 1000))

        local frame = Instance.new("Frame")
        frame.Name = "Bubble"
        frame.BackgroundTransparency = 1

        local body = Instance.new("ImageLabel")
        body.Name = "Body"
        body.BackgroundTransparency = 1
        body.Image = "rbxassetid://2582470061"
        body.ScaleType = Enum.ScaleType.Slice
        body.SliceCenter = Rect.new(29, 29, 67, 67)
        body.SliceScale = BODY_SLICE_SCALE
        body.Size = UDim2.new(1, 0, 1, 0)
        body.ZIndex = 2
        body.Parent = frame

        local label = Instance.new("TextLabel")
        label.Name = "Text"
        label.BackgroundTransparency = 1
        label.FontFace = Font.new("rbxasset://fonts/families/Arial.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        label.TextSize = FONT_SIZE
        label.TextColor3 = TEXT_COLOR
        label.TextWrapped = true
        label.Text = text
        label.ZIndex = 10
        label.Parent = frame

        local entry = {
            text = text,
            width = math.clamp(measured.X + PAD_X, 42, MAX_WIDTH + PAD_X),
            height = measured.Y + PAD_Y,
            textHeight = measured.Y,
            frame = frame,
            label = label,
        }
        table.insert(stack.entries, entry)
        frame.Parent = stack.gui
        layout(stack)

        task.delay(bubbleLifetime(text, player == Players.LocalPlayer), function() removeEntry(stack, entry) end)
    end

    local function receiveMessage(player, text)
        if not running or not player then return end
        if typeof(text) ~= "string" or text == "" then return end
        -- the same message can arrive through both chat systems
        local key = tostring(player.UserId) .. ":" .. text
        if lastMessages[key] then return end
        lastMessages[key] = true
        task.delay(0.25, function() lastMessages[key] = nil end)
        createBubble(player, text)
    end

    local function hookPlayer(player)
        table.insert(connections, player.Chatted:Connect(function(text)
            receiveMessage(player, text)
        end))
        table.insert(connections, player.CharacterAdded:Connect(function(character)
            task.wait(0.2)
            if running then removeCharacterBubbles(character) end
        end))
    end
    for _, player in ipairs(Players:GetPlayers()) do hookPlayer(player) end
    table.insert(connections, Players.PlayerAdded:Connect(hookPlayer))
    table.insert(connections, Players.PlayerRemoving:Connect(destroyStack))

    pcall(function()
        table.insert(connections, TextChatService.MessageReceived:Connect(function(message)
            if not message or not message.TextSource then return end
            receiveMessage(Players:GetPlayerByUserId(message.TextSource.UserId), message.Text)
        end))
    end)

    -- the game's own bubbles on player characters are removed as soon as they appear
    local function watchContainer(container)
        table.insert(connections, container.DescendantAdded:Connect(function(object)
            if not isForeignBubble(object) then return end
            task.defer(function()
                if running and object.Parent and belongsToPlayerCharacter(object) then
                    pcall(function() object:Destroy() end)
                end
            end)
        end))
    end
    watchContainer(Workspace)
    watchContainer(pg)

    -- One sweep now (bubbles already on screen); after that new ones are caught the moment
    -- they appear (above), so only a slow safety sweep of the characters is left. This used to
    -- scan every player's character and the whole PlayerGui more than six times a second.
    task.spawn(function()
        pcall(function()
            for _, object in ipairs(pg:GetDescendants()) do
                if isForeignBubble(object) and belongsToPlayerCharacter(object) then object:Destroy() end
            end
        end)
        while running do
            for _, player in ipairs(Players:GetPlayers()) do
                removeCharacterBubbles(player.Character)
            end
            task.wait(3)
        end
    end)

    local function cleanup()
        running = false
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        connections = {}
        for player in pairs(stacks) do destroyStack(player) end
        if savedLegacyBubbles ~= nil then
            pcall(function() Chat:SetBubbleChatEnabled(savedLegacyBubbles) end)
        end
        if getgenv().ClassicBubbleCleanup == cleanup then getgenv().ClassicBubbleCleanup = nil end
    end
    getgenv().ClassicBubbleCleanup = cleanup
    return cleanup
end

--========================================================
-- NPC DIALOGS
--========================================================
local function injectClassicDialogs()
    if getgenv().ClassicDialogCleanup then pcall(getgenv().ClassicDialogCleanup) end

    local LocalPlayer = Players.LocalPlayer
    local connections = {}
    local SESSION_ID = tostring(os.clock())
    local parentGui = (gethui and gethui()) or CoreGui or pg

    local activeNPC, activeDialog = nil, nil
    local dialogGeneration = 0
    local hookedNPCs = {}
    local dialogCounter = 0
    local disabledNative = {}       -- native dialog icons switched off: icon -> { keepOff, restore }
    local alive = true
    local needNativeSweep = true    -- a new dialog was hooked: its native icon may already exist

    local OVERHEAD_ICONS = {
        Neutral  = "rbxassetid://44197302",
        Friendly = "rbxassetid://44197280",
        Enemy    = "rbxassetid://44197248",
    }
    local TONE_BACKGROUNDS = {
        Neutral  = "rbxassetid://112937316668112",
        Friendly = "rbxassetid://87266893464059",
        Enemy    = "rbxassetid://137202834516465",
    }
    local TONE_TAILS_BOTTOM = {
        Neutral  = "rbxassetid://123812487475700",
        Friendly = "rbxassetid://133902375146299",
        Enemy    = "rbxassetid://96906382970929",
    }
    local TONE_TAILS_RIGHT = {
        Neutral  = "rbxassetid://105269546831524",
        Friendly = "rbxassetid://90128448889142",
        Enemy    = "rbxassetid://115414034377238",
    }
    local PURPOSE_ICONS = {
        Quest = "rbxassetid://4542442173",
        Help  = "rbxassetid://4542442707",
        Shop  = "rbxassetid://4542442549",
    }
    local TONE_COLORS = {
        Neutral  = Color3.fromRGB(0, 0, 175),
        Friendly = Color3.fromRGB(0, 79, 0),  -- the inside of the green bubbles
        Enemy    = Color3.fromRGB(142, 0, 0),  -- the inside of the red bubbles
    }

    local function enumLeaf(val) return (tostring(val):match("[^.]+$")) or "" end
    local function getTone(dialog)
        if not dialog then return "Neutral" end
        local t = enumLeaf(dialog.Tone)
        return TONE_BACKGROUNDS[t] and t or "Neutral"
    end

    local function measureBubble(text)
        text = tostring(text or "")
        if text == "" then return 120, 44 end
        local measurement = TextService:GetTextSize(text, 16, Enum.Font.SourceSans, Vector2.new(280, 2000))
        return math.clamp(measurement.X + 32, 120, 320), math.clamp(measurement.Y + 28, 44, 400)
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "ClassicDialogExecutorGui"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 100
    gui.Parent = parentGui

    if getgenv().ClassicDialogDebug == nil then getgenv().ClassicDialogDebug = true end
    local function dbg(...)
        if getgenv().ClassicDialogDebug then warn("[ClassicDialog]", ...) end
    end

    local billboardHost
    local function ensureHost()
        if billboardHost and billboardHost.Parent then return billboardHost end
        dbg("creating billboard host folder")
        billboardHost = Instance.new("Folder")
        billboardHost.Name = "ClassicDialogBillboardHost"
        local success = pcall(function() billboardHost.Parent = CoreGui end)
        if not success then billboardHost.Parent = pg end
        return billboardHost
    end
    ensureHost()

    local noticeGui = Instance.new("ScreenGui")
    noticeGui.Name = "ClassicDialogNoticeGui"
    noticeGui.ResetOnSpawn = false
    noticeGui.DisplayOrder = 5000 -- above every GUI (the kept dialog box sits at 1000)
    noticeGui.Parent = parentGui

    local function showSystemNotice(text, duration)
        duration = duration or 2.5
        local existing = noticeGui:FindFirstChild("Notice")
        if existing then existing:Destroy() end

        local measured = TextService:GetTextSize(text, 20, Enum.Font.SourceSans, Vector2.new(2000, 2000))
        local boxWidth = math.max(measured.X + 32, 250)

        local frame = Instance.new("Frame")
        frame.Name = "Notice"
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.Size = UDim2.new(0, boxWidth, 0, 40)
        frame.Position = UDim2.new(0.5, 0, 0.5, 0)
        frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        frame.BackgroundTransparency = 0.4
        frame.BorderSizePixel = 0
        frame.ZIndex = 100
        frame.Parent = noticeGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = frame

        local label = Instance.new("TextLabel")
        label.Name = "Text"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.Position = UDim2.new(0, 0, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextSize = 20
        label.Font = Enum.Font.SourceSans
        label.ZIndex = 101
        label.Parent = frame

        task.delay(duration, function()
            if frame and frame.Parent then frame:Destroy() end
        end)
    end

    local dialogWrap = Instance.new("Frame")
    dialogWrap.Name = "DialogWrap"
    dialogWrap.Size = UDim2.new(0, 382, 0, 64)
    dialogWrap.Position = UDim2.new(0, 15, 1, -99)
    dialogWrap.BackgroundTransparency = 1
    dialogWrap.Visible = false
    dialogWrap.Parent = gui

    local boxBg = Instance.new("ImageLabel")
    boxBg.Size = UDim2.new(0, 330, 1, 0)
    boxBg.BackgroundTransparency = 1
    boxBg.Image = TONE_BACKGROUNDS.Neutral
    boxBg.ScaleType = Enum.ScaleType.Slice
    boxBg.SliceCenter = Rect.new(16, 16, 16, 16)
    boxBg.SliceScale = 0.55
    boxBg.Parent = dialogWrap

    local boxInterior = Instance.new("Frame")
    boxInterior.Size = UDim2.new(1, -20, 1, -20)
    boxInterior.Position = UDim2.new(0, 10, 0, 10)
    boxInterior.BackgroundColor3 = TONE_COLORS.Neutral
    boxInterior.BorderSizePixel = 0
    boxInterior.Parent = boxBg
    Instance.new("UICorner", boxInterior).CornerRadius = UDim.new(0, 12)

    local boxSideTail = Instance.new("ImageLabel")
    boxSideTail.AnchorPoint = Vector2.new(0, 0.5)
    boxSideTail.Size = UDim2.new(0, 52, 0, 36)
    boxSideTail.Position = UDim2.new(1, -12, 0.5, 0)
    boxSideTail.BackgroundTransparency = 1
    boxSideTail.Image = TONE_TAILS_RIGHT.Neutral
    boxSideTail.ScaleType = Enum.ScaleType.Fit
    boxSideTail.Parent = boxBg

    local choicesContainer = Instance.new("ScrollingFrame")
    choicesContainer.Size = UDim2.new(1, -20, 1, -16)
    choicesContainer.Position = UDim2.new(0, 10, 0, 8)
    choicesContainer.BackgroundTransparency = 1
    choicesContainer.BorderSizePixel = 0
    choicesContainer.ScrollingDirection = Enum.ScrollingDirection.Y
    choicesContainer.ScrollBarThickness = 4
    choicesContainer.Parent = boxBg

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 2)
    listLayout.Parent = choicesContainer

    local function updateBoxHeight(itemCount)
        local contentHeight = (itemCount * 28) + (math.max(0, itemCount - 1) * 2) + 16
        local finalHeight = math.clamp(contentHeight, 64, 520)
        dialogWrap.Size = UDim2.new(0, 382, 0, finalHeight)
        dialogWrap.Position = UDim2.new(0, 15, 1, -finalHeight - 35)
        choicesContainer.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
    end

    local function clearChoices()
        for _, child in ipairs(choicesContainer:GetChildren()) do
            if child:IsA("GuiObject") and child ~= listLayout then child:Destroy() end
        end
    end

    local function showPlayerBubble(text, duration, tone)
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
        if not head then return end

        local old = ensureHost():FindFirstChild("PlayerDialogBubble")
        if old then old:Destroy() end

        local bw, bh = measureBubble(text)
        tone = tone or "Neutral"

        local bg = {
            Neutral = "rbxassetid://112937316668112",
            Friendly = "rbxassetid://87266893464059",
            Enemy = "rbxassetid://137202834516465"
        }
        local tails = {
            Neutral = "rbxassetid://123812487475700",
            Friendly = "rbxassetid://133902375146299",
            Enemy = "rbxassetid://96906382970929"
        }

        local bb = Instance.new("BillboardGui")
        bb.Name = "PlayerDialogBubble"
        bb.Adornee = head
        bb.Size = UDim2.new(0, bw + 4, 0, bh + 22)
        bb.StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0)
        bb.AlwaysOnTop = false
        bb.MaxDistance = math.huge
        bb:SetAttribute("ClassicOwned", true)
        bb.Parent = ensureHost()

        local bubble = Instance.new("ImageLabel")
        bubble.Name = "Body"
        bubble.Size = UDim2.new(1, 0, 0, bh)
        bubble.Position = UDim2.new(0, 0, 0, 0)
        bubble.BackgroundTransparency = 1
        bubble.Image = bg[tone] or bg.Neutral
        bubble.ScaleType = Enum.ScaleType.Slice
        bubble.SliceCenter = Rect.new(16, 16, 16, 16)
        bubble.SliceScale = 0.55
        bubble.ZIndex = 1
        bubble.Parent = bb

        local tail = Instance.new("ImageLabel")
        tail.Name = "Tail"
        tail.AnchorPoint = Vector2.new(0.5, 0)
        tail.Size = UDim2.new(0, 22, 0, 22)
        tail.Position = UDim2.new(0.5, 0, 0, bh - 7)
        tail.BackgroundTransparency = 1
        tail.Image = tails[tone] or tails.Neutral
        tail.ScaleType = Enum.ScaleType.Fit
        tail.ZIndex = 3
        tail.Parent = bb

        local label = Instance.new("TextLabel")
        label.Name = "Text"
        label.Size = UDim2.new(1, -24, 1, -16)
        label.Position = UDim2.new(0, 12, 0, 8)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextSize = 16
        label.Font = Enum.Font.SourceSans
        label.TextWrapped = true
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.ZIndex = 4
        label.Parent = bubble

        task.delay(duration or 3, function() if bb and bb.Parent then bb:Destroy() end end)
    end

    local function setBubbleActive(bb, text, dialog)
        if not bb then return end
        local tone = getTone(dialog)
        local bw, bh = measureBubble(text)

        bb:SetAttribute("IsInDialog", true)
        bb.Size = UDim2.new(0, bw, 0, bh + 22)

        local iconBubble = bb:FindFirstChild("IconBubble")
        if iconBubble then iconBubble.Visible = false end

        local textFrame = bb:FindFirstChild("TextBubble")
        if textFrame then
            textFrame.Visible = true
            textFrame.Image = TONE_BACKGROUNDS[tone] or TONE_BACKGROUNDS.Neutral
            textFrame.Size = UDim2.new(1, 0, 0, bh)
            textFrame.Position = UDim2.new(0, 0, 0, 0)

            local bubbleText = textFrame:FindFirstChild("BubbleText")
            if bubbleText then
                bubbleText.Visible = true
                bubbleText.Text = tostring(text or "")
            end
        end

        local bubbleTail = bb:FindFirstChild("BubbleTail")
        if bubbleTail then
            bubbleTail.Image = TONE_TAILS_BOTTOM[tone] or TONE_TAILS_BOTTOM.Neutral
            bubbleTail.Position = UDim2.new(0.5, 0, 0, bh - 7)
            bubbleTail.Visible = true
        end
    end

    local function restoreBubbleIcon(bb, dialog)
        if not bb then return end
        bb:SetAttribute("IsInDialog", false)

        local textFrame = bb:FindFirstChild("TextBubble")
        if textFrame then textFrame.Visible = false end

        local bubbleTail = bb:FindFirstChild("BubbleTail")
        if bubbleTail then bubbleTail.Visible = false end

        local tone = getTone(dialog)
        local iconBubble = bb:FindFirstChild("IconBubble")
        if iconBubble then
            iconBubble.Image = OVERHEAD_ICONS[tone] or OVERHEAD_ICONS.Neutral
            iconBubble.Visible = true

            local purposeIcon = iconBubble:FindFirstChild("PurposeIcon")
            if purposeIcon then
                local pStr = dialog and enumLeaf(dialog.Purpose) or "Help"
                purposeIcon.Image = PURPOSE_ICONS[pStr] or PURPOSE_ICONS.Help
                purposeIcon.Visible = true
            end
        end

        local cam = Workspace.CurrentCamera
        if cam and bb.Adornee then
            local dist = (cam.CFrame.Position - bb.Adornee.Position).Magnitude
            local zoom = math.clamp(30 / math.max(dist, 3), 0.1, 2.5)
            bb:SetAttribute("CurrentZoom", zoom)
            bb.Size = UDim2.new(0, 46 * zoom, 0, 60 * zoom)
            if iconBubble then
                local pIcon = iconBubble:FindFirstChild("PurposeIcon")
                if pIcon then
                    pIcon.Size = UDim2.new(0, 28 * zoom, 0, 28 * zoom)
                    pIcon.Position = UDim2.new(0.5, -(28 * zoom / 2), 0, 4 * zoom)
                end
            end
        end
    end

    local function endDialog()
        dbg("dialog ended from:", debug.traceback("", 2))
        dialogGeneration = dialogGeneration + 1
        dialogWrap.Visible = false

        local oldNPC = activeNPC
        local oldDialog = activeDialog
        activeNPC, activeDialog = nil, nil
        clearChoices()

        if oldNPC and oldDialog then
            local data = hookedNPCs[oldDialog]
            if data and data.bb then
                pcall(function() restoreBubbleIcon(data.bb, oldDialog) end)
            end
        end
    end

    local function createChoiceButton(text, layoutOrder)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -4, 0, 28)
        btn.BackgroundTransparency = 1
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 15
        btn.Font = Enum.Font.SourceSans
        btn.Text = "  " .. tostring(text)
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.LayoutOrder = layoutOrder
        btn.Parent = choicesContainer
        btn.MouseEnter:Connect(function() btn.BackgroundTransparency = 0.88 end)
        btn.MouseLeave:Connect(function() btn.BackgroundTransparency = 1 end)
        return btn
    end

    local function getDialogChoices(node)
        local choices = {}
        pcall(function()
            for _, child in ipairs(node:GetChildren()) do
                if child:IsA("DialogChoice") then table.insert(choices, child) end
            end
        end)
        return choices
    end

    local function displayNode(node, promptText)
        if not node then return end
        local generation = dialogGeneration
        clearChoices()

        local text = promptText or (node:IsA("Dialog") and node.InitialPrompt) or (node:IsA("DialogChoice") and node.ResponseDialog) or ""
        if activeNPC and activeDialog then
            local data = hookedNPCs[activeDialog]
            if data and data.bb then setBubbleActive(data.bb, text, activeDialog) end
        end

        local choices = getDialogChoices(node)
        updateBoxHeight(#choices + 1)

        for index, choice in ipairs(choices) do
            local userText = (choice.UserDialog ~= "" and choice.UserDialog) or choice.Name
            local btn = createChoiceButton(index .. ") " .. userText, index)

            btn.Activated:Connect(function()
                if generation ~= dialogGeneration or not activeDialog then return end

                showPlayerBubble(userText, 2.5, getTone(activeDialog))

                local responseText = choice.ResponseDialog or ""
                local subChoices = getDialogChoices(choice)

                if #subChoices > 0 then
                    dialogGeneration = dialogGeneration + 1
                    local nextGen = dialogGeneration
                    task.delay(0.2, function()
                        if nextGen == dialogGeneration and activeNPC and activeDialog then
                            displayNode(choice, responseText)
                        end
                    end)
                else
                    dialogGeneration = dialogGeneration + 1
                    local endGen = dialogGeneration
                    if activeNPC then
                        local data = hookedNPCs[activeDialog]
                        if data and data.bb then setBubbleActive(data.bb, responseText, activeDialog) end
                    end
                    task.delay(1.5, function()
                        if endGen == dialogGeneration then endDialog() end
                    end)
                end
            end)
        end

        local goodbyeText = "Goodbye!"
        pcall(function()
            local g = node.GoodbyeDialog
            if type(g) == "string" and g ~= "" then goodbyeText = g end
        end)
        local goodbyeBtn = createChoiceButton((#choices + 1) .. ") " .. goodbyeText, #choices + 1)
        goodbyeBtn.Activated:Connect(function()
            if generation ~= dialogGeneration or not activeDialog then return end
            showPlayerBubble(goodbyeText, 2, getTone(activeDialog))
            endDialog()
        end)

        task.defer(function() choicesContainer.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y) end)
    end

    local function startDialog(dialog, head)
        if activeNPC == head and activeDialog == dialog then return end
        dialogGeneration = dialogGeneration + 1
        activeNPC = head
        activeDialog = dialog

        local tone = getTone(dialog)
        boxBg.Image = TONE_BACKGROUNDS[tone] or TONE_BACKGROUNDS.Neutral
        boxInterior.BackgroundColor3 = TONE_COLORS[tone] or TONE_COLORS.Neutral
        boxSideTail.Image = TONE_TAILS_RIGHT[tone] or TONE_TAILS_RIGHT.Neutral

        local prompt = dialog.InitialPrompt or ""
        local data = hookedNPCs[dialog]
        if data and data.bb then setBubbleActive(data.bb, prompt, dialog) end

        dialogWrap.Visible = true
        displayNode(dialog, prompt)
    end

    local function hookDialog(dialog)
        if not dialog or not dialog:IsA("Dialog") or dialog:GetAttribute("ClassicHooked") == SESSION_ID then return end

        local head = dialog:FindFirstAncestorWhichIsA("BasePart")
        if not head then
            -- a Dialog put straight into a Model: use that model's head / main part
            local model = dialog:FindFirstAncestorWhichIsA("Model")
            if model then
                local h = model:FindFirstChild("Head")
                head = (h and h:IsA("BasePart") and h) or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
            end
        end
        if not head then task.delay(1, function() hookDialog(dialog) end) return end

        dialog:SetAttribute("ClassicHooked", SESSION_ID)

        -- Where the icon sits. A Dialog inside an NPC shows over the NPC's head; anything
        -- else shows over the top of its part (not its centre: a big part's centre can be
        -- down in the floor, and the floor then hides the icon).
        local anchor = head
        local npc = head:FindFirstAncestorWhichIsA("Model")
        while npc do
            if npc:FindFirstChildOfClass("Humanoid") then
                local npcHead = npc:FindFirstChild("Head")
                if npcHead and npcHead:IsA("BasePart") then anchor = npcHead end
                break
            end
            npc = npc:FindFirstAncestorWhichIsA("Model")
        end

        local origDist = dialog:GetAttribute("OrigDist")
        if not origDist then
            origDist = dialog.ConversationDistance
            dialog:SetAttribute("OrigDist", origDist)
        end
        pcall(function() dialog.ConversationDistance = 0 end)

        dialogCounter = dialogCounter + 1
        local bbName = "ClassicExecutorDialogGui_" .. dialogCounter

        local tone = getTone(dialog)

        local bb = Instance.new("BillboardGui")
        bb.Name = bbName
        bb.Adornee = anchor
        bb.Size = UDim2.new(0, 46, 0, 60)
        -- the icon's bottom sits 1 stud above the top of the anchor part
        bb.ExtentsOffsetWorldSpace = Vector3.new(0, 1, 0)
        bb.StudsOffsetWorldSpace = Vector3.new(0, 1, 0)
        bb.SizeOffset = Vector2.new(0, 0.5)
        bb.AlwaysOnTop = false
        bb.Active = true
        bb.MaxDistance = math.huge
        bb:SetAttribute("ClassicOwned", true)
        bb.Parent = ensureHost()
        bb:SetAttribute("IsInDialog", false)

        local iconBubble = Instance.new("ImageLabel")
        iconBubble.Name = "IconBubble"
        iconBubble.Size = UDim2.new(1, 0, 1, 0)
        iconBubble.BackgroundTransparency = 1
        iconBubble.Image = OVERHEAD_ICONS[tone] or OVERHEAD_ICONS.Neutral
        iconBubble.ScaleType = Enum.ScaleType.Fit
        iconBubble.ZIndex = 1
        iconBubble.Visible = true
        iconBubble.Parent = bb

        local clickBtn = Instance.new("TextButton")
        clickBtn.Size = UDim2.new(1, 0, 1, 0)
        clickBtn.BackgroundTransparency = 1
        clickBtn.Text = ""
        clickBtn.ZIndex = 10
        clickBtn.Parent = iconBubble

        clickBtn.MouseButton1Click:Connect(function()
            local char = LocalPlayer.Character
            local myHead = char and char:FindFirstChild("Head")
            if not myHead then return end

            local dist = (myHead.Position - head.Position).Magnitude
            local maxDist = dialog:GetAttribute("OrigDist") or 25
            if dist <= maxDist then
                startDialog(dialog, head)
            end
        end)

        local pStr = dialog.Purpose and enumLeaf(dialog.Purpose) or "Help"
        local purposeIcon = Instance.new("ImageLabel")
        purposeIcon.Name = "PurposeIcon"
        purposeIcon.Size = UDim2.new(0, 28, 0, 28)
        purposeIcon.Position = UDim2.new(0.5, -14, 0, 4)
        purposeIcon.BackgroundTransparency = 1
        purposeIcon.Image = PURPOSE_ICONS[pStr] or PURPOSE_ICONS.Help
        purposeIcon.ScaleType = Enum.ScaleType.Fit
        purposeIcon.ZIndex = 3
        purposeIcon.Visible = true
        purposeIcon.Parent = iconBubble

        local textFrame = Instance.new("ImageLabel")
        textFrame.Name = "TextBubble"
        textFrame.Size = UDim2.new(1, 0, 1, 0)
        textFrame.BackgroundTransparency = 1
        textFrame.Image = TONE_BACKGROUNDS[tone] or TONE_BACKGROUNDS.Neutral
        textFrame.ScaleType = Enum.ScaleType.Slice
        textFrame.SliceCenter = Rect.new(16, 16, 16, 16)
        textFrame.SliceScale = 0.55
        textFrame.ZIndex = 2
        textFrame.Visible = false
        textFrame.Parent = bb

        local bubbleText = Instance.new("TextLabel")
        bubbleText.Name = "BubbleText"
        bubbleText.Size = UDim2.new(1, -24, 1, -16)
        bubbleText.Position = UDim2.new(0, 12, 0, 8)
        bubbleText.BackgroundTransparency = 1
        bubbleText.TextColor3 = Color3.fromRGB(255, 255, 255)
        bubbleText.TextSize = 16
        bubbleText.Font = Enum.Font.SourceSans
        bubbleText.TextWrapped = true
        bubbleText.ZIndex = 3
        bubbleText.Parent = textFrame

        local bubbleTail = Instance.new("ImageLabel")
        bubbleTail.Name = "BubbleTail"
        bubbleTail.BackgroundTransparency = 1
        bubbleTail.Image = TONE_TAILS_BOTTOM[tone] or TONE_TAILS_BOTTOM.Neutral
        bubbleTail.ScaleType = Enum.ScaleType.Fit
        bubbleTail.Size = UDim2.new(0, 22, 0, 22)
        bubbleTail.AnchorPoint = Vector2.new(0.5, 0)
        bubbleTail.Visible = false
        bubbleTail.ZIndex = 3
        bubbleTail.Parent = bb

        hookedNPCs[dialog] = { head = head, bb = bb }
        needNativeSweep = true

        local stepConn
        stepConn = RunService.RenderStepped:Connect(function()
            if not head.Parent or not dialog.Parent then
                if bb.Parent then bb:Destroy() end
                hookedNPCs[dialog] = nil
                stepConn:Disconnect()
                return
            end

            if not bb.Parent or not bb:IsDescendantOf(game) or not anchor.Parent then
                dbg("icon (or the NPC head it sits on) was removed, re-hooking")
                if bb.Parent then bb:Destroy() end
                stepConn:Disconnect()
                hookedNPCs[dialog] = nil
                dialog:SetAttribute("ClassicHooked", nil)
                task.defer(function() hookDialog(dialog) end)
                return
            end

            if bb:GetAttribute("IsInDialog") == true then return end

            local cam = Workspace.CurrentCamera
            if not cam then return end

            local dist = (cam.CFrame.Position - anchor.Position).Magnitude
            local zoom = math.clamp(30 / math.max(dist, 3), 0.1, 2.5)
            local storedZoom = bb:GetAttribute("CurrentZoom") or -1

            if math.abs(zoom - storedZoom) > 0.05 then
                bb:SetAttribute("CurrentZoom", zoom)
                bb.Size = UDim2.new(0, 46 * zoom, 0, 60 * zoom)
                purposeIcon.Size = UDim2.new(0, 28 * zoom, 0, 28 * zoom)
                purposeIcon.Position = UDim2.new(0.5, -(28 * zoom / 2), 0, 4 * zoom)
            end
        end)
        table.insert(connections, stepConn)
    end

    local function isHookedHead(part)
        if not part then return false end
        for _, data in pairs(hookedNPCs) do
            if data.head == part then return true end
        end
        return false
    end

    -- Roblox's / the game's own dialog icons over the NPCs hooked here are switched off the
    -- moment they show up, and again if the game switches them back on. This used to look
    -- through all of PlayerGui and CoreGui five times a second, which slowed the game down.
    local function suppressNative(obj)
        if obj.ClassName ~= "BillboardGui" or disabledNative[obj] or not obj.Parent then return end
        if obj:GetAttribute("ClassicOwned") then return end
        if billboardHost and obj:IsDescendantOf(billboardHost) then return end
        if not (isHookedHead(obj.Adornee) or isHookedHead(obj.Parent)) then return end
        local wasOn = obj.Enabled
        pcall(function() obj.Enabled = false end)
        local keepOff = obj:GetPropertyChangedSignal("Enabled"):Connect(function()
            if alive and obj.Enabled then pcall(function() obj.Enabled = false end) end
        end)
        disabledNative[obj] = { keepOff = keepOff, restore = wasOn }
    end

    -- the icons that already exist (and, once, every few seconds, in case one was missed)
    local function sweepNative()
        needNativeSweep = false
        for _, data in pairs(hookedNPCs) do
            if data.head then
                for _, obj in ipairs(data.head:GetChildren()) do suppressNative(obj) end
            end
        end
        for _, container in ipairs({ pg, CoreGui }) do
            pcall(function()
                for _, obj in ipairs(container:GetDescendants()) do suppressNative(obj) end
            end)
        end
    end

    -- icons that appear later are caught as they are added
    for _, container in ipairs({ pg, CoreGui }) do
        pcall(function()
            table.insert(connections, container.DescendantAdded:Connect(function(obj)
                if obj.ClassName ~= "BillboardGui" then return end
                -- its Adornee is often set a moment after it is parented
                task.defer(suppressNative, obj)
                task.delay(0.5, suppressNative, obj)
            end))
        end)
    end

    -- every second: the dialog GUIs are put back if they were removed, and the icons on the
    -- NPC heads are looked at (a few parts, not the whole GUI)
    task.spawn(function()
        local sinceFullSweep = 0
        while alive do
            pcall(ensureHost)
            for _, g in ipairs({ gui, noticeGui }) do
                if not g.Parent then pcall(function() g.Parent = parentGui end) end
            end
            sinceFullSweep = sinceFullSweep + 1
            if needNativeSweep or sinceFullSweep >= 10 then
                sinceFullSweep = 0
                pcall(sweepNative)
            else
                for _, data in pairs(hookedNPCs) do
                    if data.head then
                        for _, obj in ipairs(data.head:GetChildren()) do suppressNative(obj) end
                    end
                end
            end
            -- icons that no longer exist are forgotten
            for obj, state in pairs(disabledNative) do
                if not obj.Parent then
                    pcall(function() state.keepOff:Disconnect() end)
                    disabledNative[obj] = nil
                end
            end
            task.wait(1)
        end
    end)

    -- walking away from the NPC you are talking to ends the chat
    table.insert(connections, RunService.RenderStepped:Connect(function()
        if not activeNPC or not activeDialog then return end

        local char = LocalPlayer.Character
        local myHead = char and char:FindFirstChild("Head")

        local maxDist = 25
        pcall(function()
            local orig = activeDialog:GetAttribute("OrigDist")
            if type(orig) == "number" and orig > 0 then maxDist = orig end
        end)

        if not myHead or not activeNPC.Parent or (myHead.Position - activeNPC.Position).Magnitude > (maxDist + 5) then
            print("[ClassicDialog] chat ended: walked away")
            showSystemNotice("Chat ended because you walked away", 2.5)
            endDialog()
        end
    end))

    local function scanContainer(c)
        pcall(function()
            for _, d in ipairs(c:GetDescendants()) do
                if d:IsA("Dialog") then hookDialog(d) end
            end
        end)
    end

    scanContainer(Workspace)
    table.insert(connections, Workspace.DescendantAdded:Connect(function(d)
        local class = d.ClassName
        if class == "Dialog" then
            task.defer(function() hookDialog(d) end)
        elseif class == "BillboardGui" then
            -- an icon the game put on an NPC's head
            task.defer(suppressNative, d)
        end
    end))

    getgenv().ClassicDialogCleanup = function()
        alive = false
        dialogGeneration = dialogGeneration + 1
        activeNPC, activeDialog = nil, nil
        pcall(function() gui:Destroy() end)
        pcall(function() billboardHost:Destroy() end)
        pcall(function() noticeGui:Destroy() end)
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end

        for dialog, data in pairs(hookedNPCs) do
            pcall(function()
                dialog:SetAttribute("ClassicHooked", nil)
                local orig = dialog:GetAttribute("OrigDist")
                if orig then
                    dialog.ConversationDistance = orig
                    dialog:SetAttribute("OrigDist", nil)
                end
            end)
        end
        for obj, state in pairs(disabledNative) do
            pcall(function() state.keepOff:Disconnect() end)
            if state.restore then pcall(function() obj.Enabled = true end) end
        end
        disabledNative = {}
        hookedNPCs = {}
        dialogLoaded_Classic = false
    end

    dialogLoaded_Classic = true
end

--========================================================
-- START
--========================================================
setNativeBubbles(true)
setDialogBoxShown(false)
startClassicBubbles()
task.spawn(injectClassicDialogs)

local stop
stop = function()
    if getgenv().ClassicDialogsAndChatStop ~= stop then return end
    getgenv().ClassicDialogsAndChatStop = nil
    if getgenv().ClassicBubbleCleanup then pcall(getgenv().ClassicBubbleCleanup) end
    if getgenv().ClassicDialogCleanup then pcall(getgenv().ClassicDialogCleanup) end
    getgenv().ClassicBubbleCleanup, getgenv().ClassicDialogCleanup = nil, nil
    setNativeBubbles(false)
    setDialogBoxShown(true)
    print("[2011-2014 Dialogs and Chat] stopped: Roblox's own bubbles and dialogs are back")
end
getgenv().ClassicDialogsAndChatStop = stop
print("[2011-2014 Dialogs and Chat] running (getgenv().ClassicDialogsAndChatStop() stops it)")
