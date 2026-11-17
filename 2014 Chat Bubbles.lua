--========================================================
-- 2014 CHAT BUBBLES (standalone)
-- The loader's 2011-2014 chat bubbles on their own: run this by itself in any game.
-- + The 2014 look: Arial 22 in a tight white bubble, rounder corners, a grey edge and a tail
-- + A new message goes at the bottom with the tail; up to 3 older ones stay above it in grey
-- + Farther than 52 studs: just "..."; no fading, like 2011-2014
-- + The game's own chat bubbles on players are removed while this runs (NPC dialogs are left alone)
-- + Run it again to restart it; ClassicBubbleCleanup() (in getgenv) stops it and brings Roblox's
--   bubbles back
-- It uses the same slot as the loader's bubbles, so it replaces them if they are running.
--========================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")
local genv = (getgenv and getgenv()) or _G
local pg = Players.LocalPlayer:WaitForChild("PlayerGui")

local function startClassicBubbles()
    if genv.ClassicBubbleCleanup then pcall(genv.ClassicBubbleCleanup) end

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
    -- Second pass (a phone screenshot next to the 2014 one at the same text size): the letters a little
    -- heavier (a faint text stroke), the grey edge thinner and the corners a little tighter, 1 to 2 px more
    -- white above and below the text and less at the sides, a tail a little wider at the top, and no
    -- bubble narrower than the tail's join (a one-letter message stays roughly square).
    local FONT_SIZE = 22
    local MAX_WIDTH = 240            -- where long messages wrap (as many letters per line as before)
    local PAD_X, PAD_Y = 20, 22      -- the bubble frame is the text's size plus these
    local TEXT_Y = 11                -- the text's top inside the bubble frame
    local BODY_SLICE_SCALE = 0.42    -- the bubble picture's corners and edge (0.5 made the edge too heavy)
    local MIN_WIDTH = 48             -- the narrowest bubble frame: its flat bottom always covers the tail's join
    local TEXT_STROKE = 0.8          -- a faint outline on the letters: as heavy as the 2014 text (1 = none)
    local TAIL_OVERLAP = 8           -- how far the tail's top goes up into the bubble frame
    local TAIL_WIDTH, TAIL_HEIGHT = 20, 22
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
            old.label.TextStrokeColor3 = OLD_TEXT_COLOR
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
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.TextStrokeTransparency = TEXT_STROKE
        label.TextWrapped = true
        label.Text = text
        label.ZIndex = 10
        label.Parent = frame

        local entry = {
            text = text,
            width = math.clamp(measured.X + PAD_X, MIN_WIDTH, MAX_WIDTH + PAD_X),
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
        if genv.ClassicBubbleCleanup == cleanup then genv.ClassicBubbleCleanup = nil end
    end
    genv.ClassicBubbleCleanup = cleanup
    return cleanup
end

startClassicBubbles()
