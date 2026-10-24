-- [[ 2015 / 2016 → AUTO-RUN BUBBLE CHAT ON CLICK ]]
-- Run AFTER the main Bloxy Paradox script.

------------------------------------------------------------
-- EMBEDDED BUBBLE CHAT PAYLOAD
------------------------------------------------------------
local EMBEDDED = [==[
-- Old chat bubbles — standalone
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players           = game:GetService("Players")
local TextChatService   = game:GetService("TextChatService")
local TextService       = game:GetService("TextService")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")

pcall(function()
    TextChatService.BubbleChatConfiguration.Enabled = false
end)

pcall(function()
    local CoreGui = game:GetService("CoreGui")
    local ExperienceChat = CoreGui:FindFirstChild("ExperienceChat")
    if ExperienceChat then
        ExperienceChat.Enabled = false
    end
end)

local MAX_BUBBLE_WIDTH            = 400
local MAX_TOTAL_BUBBLE_HEIGHT     = 150
local NEAR_BUBBLE_DISTANCE        = 45
local MAX_BUBBLE_DISTANCE         = 80
local MIN_BUBBLE_LIFETIME         = 12
local MAX_BUBBLE_LIFETIME         = 20
local MIN_BUBBLE_LIFETIME_SELF    = 8
local MAX_BUBBLE_LIFETIME_SELF    = 15
local BUBBLE_FADE_TIME            = 1.5
local MAX_CHAT_MESSAGE_LENGTH     = 128
local ELLIPSES                    = "..."

local MAX_CHAT_MESSAGE_LENGTH_EXCLUSIVE =
    MAX_CHAT_MESSAGE_LENGTH - #ELLIPSES - 1

local BubbleFont         = Font.fromEnum(Enum.Font.SourceSans)
local BubbleBackground   = Color3.fromRGB(255, 255, 255)
local BubbleTextColor    = Color3.fromRGB(60, 68, 75)
local BubbleTextSize     = 22

local ResizeBubbleTweenInfo =
    TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local ShiftBubblesUpTweenInfo =
    TweenInfo.new(0.07, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local ChatBubbleQueues = {}

local function getMessageLength(Message)
    local Success, Length = pcall(function()
        return utf8.len(utf8.nfcnormalize(Message))
    end)
    if Success and Length then return Length end
    return #Message
end

local function sanitizeChatLine(Message)
    local Length = getMessageLength(Message)
    if Length <= MAX_CHAT_MESSAGE_LENGTH_EXCLUSIVE then
        return Message
    end
    local ByteOffset
    pcall(function()
        ByteOffset = utf8.offset(
            Message,
            MAX_CHAT_MESSAGE_LENGTH_EXCLUSIVE + getMessageLength(ELLIPSES) + 1
        )
    end)
    if not ByteOffset then
        return string.sub(Message, 1, MAX_CHAT_MESSAGE_LENGTH_EXCLUSIVE)
    end
    return string.sub(Message, 1, ByteOffset - 1)
end

local function lerpLength(Message, Minimum, Maximum)
    local Alpha = math.min(getMessageLength(Message) / 75, 1)
    return Minimum + (Maximum - Minimum) * Alpha
end

local function removeBubbleFromQueue(Adornee, Bubble)
    local Queue = ChatBubbleQueues[Adornee]
    if not Queue then return end
    for Index, Value in ipairs(Queue) do
        if Value == Bubble then
            table.remove(Queue, Index)
            break
        end
    end
    if #Queue == 0 then
        ChatBubbleQueues[Adornee] = nil
    end
end

local function removeOldestFromQueue(Adornee)
    local Queue = ChatBubbleQueues[Adornee]
    if not Queue then return end
    local OldestBubble = Queue[#Queue]
    if not OldestBubble then return end
    table.remove(Queue, #Queue)
    if OldestBubble.Parent then
        OldestBubble:Destroy()
    end
end

local function addBubbleToQueue(Adornee, ChatBubbleGui, Lifetime)
    local Queue = ChatBubbleQueues[Adornee]
    if not Queue then
        Queue = {}
        ChatBubbleQueues[Adornee] = Queue
        Adornee.Destroying:Connect(function()
            ChatBubbleQueues[Adornee] = nil
        end)
    end

    local Gap = 4
    local ChatBubble = ChatBubbleGui:FindFirstChild("BillboardFrame")
        and ChatBubbleGui.BillboardFrame:FindFirstChild("ChatBubble")

    local NewBubbleHeight = 0
    if ChatBubble then
        NewBubbleHeight = ChatBubble.AbsoluteSize.Y
        if NewBubbleHeight <= 0 then
            NewBubbleHeight = ChatBubble.Size.Y.Offset
        end
    end

    local TotalYSpaceUsed = NewBubbleHeight

    for _, Bubble in ipairs(Queue) do
        if not Bubble.Parent then continue end
        local BillboardFrame = Bubble:FindFirstChild("BillboardFrame")
        if not BillboardFrame then continue end
        local ExistingBubble = BillboardFrame:FindFirstChild("ChatBubble")
        if not ExistingBubble then continue end

        local ShiftUp = NewBubbleHeight + Gap
        local NewPosition = BillboardFrame.Position - UDim2.fromOffset(0, ShiftUp)

        TweenService:Create(BillboardFrame, ShiftBubblesUpTweenInfo, {
            Position = NewPosition,
        }):Play()

        TotalYSpaceUsed += ExistingBubble.AbsoluteSize.Y

        local ExistingText = ExistingBubble:FindFirstChild("BubbleText")
        if ExistingText then
            ExistingText.TextTransparency = 0.5
        end
    end

    if TotalYSpaceUsed > MAX_TOTAL_BUBBLE_HEIGHT then
        removeOldestFromQueue(Adornee)
    end

    table.insert(Queue, 1, ChatBubbleGui)

    task.delay(Lifetime + BUBBLE_FADE_TIME, function()
        if ChatBubbleGui.Parent then
            removeBubbleFromQueue(Adornee, ChatBubbleGui)
        end
    end)
end

local function createBubble(Adornee, Message, SentBySelf)
    if not Adornee or not Adornee.Parent then return end
    Message = sanitizeChatLine(Message)

    local ChatBubbleGui = Instance.new("BillboardGui")
    ChatBubbleGui.Name = "ChatBubbleGui"
    ChatBubbleGui.Size = UDim2.fromOffset(400, 250)
    ChatBubbleGui.Adornee = Adornee
    pcall(function()
        ChatBubbleGui.MaxDistance = MAX_BUBBLE_DISTANCE
    end)

    local BillboardFrame = Instance.new("Frame")
    BillboardFrame.Name = "BillboardFrame"
    BillboardFrame.AnchorPoint = Vector2.new(0.5, 0)
    BillboardFrame.BackgroundTransparency = 1
    BillboardFrame.Position = UDim2.fromScale(0.5, -0.5)
    BillboardFrame.Size = UDim2.fromScale(1, 1)
    BillboardFrame.Parent = ChatBubbleGui

    local SmallTalkBubble = Instance.new("ImageLabel")
    SmallTalkBubble.Name = "SmallTalkBubble"
    SmallTalkBubble.AnchorPoint = Vector2.new(0.5, 1)
    SmallTalkBubble.BackgroundTransparency = 1
    SmallTalkBubble.BorderSizePixel = 0
    SmallTalkBubble.Image = "rbxasset://textures/ui/dialog_white.png"
    SmallTalkBubble.ImageColor3 = BubbleBackground
    SmallTalkBubble.Position = UDim2.fromScale(0.5, 1)
    SmallTalkBubble.ScaleType = Enum.ScaleType.Slice
    SmallTalkBubble.Size = UDim2.fromOffset(40, 30)
    SmallTalkBubble.SliceCenter = Rect.new(5, 5, 15, 15)
    SmallTalkBubble.Visible = false
    SmallTalkBubble.Parent = BillboardFrame

    local SmallTalkBubbleText = Instance.new("TextLabel")
    SmallTalkBubbleText.Name = "BubbleText"
    SmallTalkBubbleText.BackgroundTransparency = 1
    SmallTalkBubbleText.ClipsDescendants = true
    SmallTalkBubbleText.FontFace = BubbleFont
    SmallTalkBubbleText.Size = UDim2.fromScale(1, 1)
    SmallTalkBubbleText.Text = "..."
    SmallTalkBubbleText.TextColor3 = BubbleTextColor
    SmallTalkBubbleText.TextSize = BubbleTextSize
    SmallTalkBubbleText.Parent = SmallTalkBubble

    local SmallTalkPadding = Instance.new("UIPadding")
    SmallTalkPadding.PaddingBottom = UDim.new(0, 12)
    SmallTalkPadding.PaddingLeft   = UDim.new(0, 12)
    SmallTalkPadding.PaddingRight  = UDim.new(0, 12)
    SmallTalkPadding.PaddingTop    = UDim.new(0, 12)
    SmallTalkPadding.Parent = SmallTalkBubbleText

    local SmallTailFrame = Instance.new("Frame")
    SmallTailFrame.Name = "ChatBubbleTailFrame"
    SmallTailFrame.BackgroundTransparency = 1
    SmallTailFrame.Position = UDim2.fromScale(0.5, 1)
    SmallTailFrame.Size = UDim2.fromScale(0.5, 0.5)
    SmallTailFrame.SizeConstraint = Enum.SizeConstraint.RelativeXX
    SmallTailFrame.Parent = SmallTalkBubble

    local SmallTail = Instance.new("ImageLabel")
    SmallTail.Name = "ChatBubbleTail"
    SmallTail.BackgroundTransparency = 1
    SmallTail.BorderSizePixel = 0
    SmallTail.Image = "rbxasset://textures/ui/dialog_tail.png"
    SmallTail.ImageColor3 = BubbleBackground
    SmallTail.Position = UDim2.fromScale(-0.5, 0)
    SmallTail.Size = UDim2.fromScale(1, 0.5)
    SmallTail.Parent = SmallTailFrame

    local ChatBubble = Instance.new("ImageLabel")
    ChatBubble.Name = "ChatBubble"
    ChatBubble.AnchorPoint = Vector2.new(0.5, 1)
    ChatBubble.BackgroundTransparency = 1
    ChatBubble.BorderSizePixel = 0
    ChatBubble.Image = "rbxasset://textures/ui/dialog_white.png"
    ChatBubble.ImageColor3 = BubbleBackground
    ChatBubble.Position = UDim2.fromScale(0.5, 1)
    ChatBubble.ScaleType = Enum.ScaleType.Slice
    ChatBubble.SliceCenter = Rect.new(5, 5, 15, 15)
    ChatBubble.Visible = false
    ChatBubble.Parent = BillboardFrame

    local BubbleText = Instance.new("TextLabel")
    BubbleText.Name = "BubbleText"
    BubbleText.BackgroundTransparency = 1
    BubbleText.ClipsDescendants = true
    BubbleText.FontFace = BubbleFont
    BubbleText.Size = UDim2.fromScale(1, 1)
    BubbleText.Text = ""
    BubbleText.TextColor3 = BubbleTextColor
    BubbleText.TextSize = BubbleTextSize
    BubbleText.TextWrapped = true
    BubbleText.Parent = ChatBubble

    local UIPadding = Instance.new("UIPadding")
    UIPadding.PaddingBottom = UDim.new(0, 12)
    UIPadding.PaddingLeft   = UDim.new(0, 12)
    UIPadding.PaddingRight  = UDim.new(0, 12)
    UIPadding.PaddingTop    = UDim.new(0, 12)
    UIPadding.Parent = BubbleText

    local ChatBubbleTail = Instance.new("ImageLabel")
    ChatBubbleTail.Name = "ChatBubbleTail"
    ChatBubbleTail.BackgroundTransparency = 1
    ChatBubbleTail.BorderSizePixel = 0
    ChatBubbleTail.Image = "rbxasset://textures/ui/dialog_tail.png"
    ChatBubbleTail.ImageColor3 = BubbleBackground
    ChatBubbleTail.Position = UDim2.new(0.5, -14, 1, 0)
    ChatBubbleTail.Size = UDim2.fromOffset(30, 14)
    ChatBubbleTail.Visible = false
    ChatBubbleTail.Parent = BillboardFrame

    local TextSizeBounds = TextService:GetTextSize(
        Message,
        BubbleText.TextSize,
        BubbleText.Font,
        Vector2.new(MAX_BUBBLE_WIDTH, math.huge)
    )

    local Multiline = TextSizeBounds.Y > BubbleText.TextSize
    if not Multiline then
        UIPadding.PaddingTop    = UDim.new(0, UIPadding.PaddingTop.Offset / 2)
        UIPadding.PaddingBottom = UDim.new(0, UIPadding.PaddingBottom.Offset / 2)
    end

    local ChatBubbleSize = UDim2.fromOffset(
        TextSizeBounds.X + UIPadding.PaddingLeft.Offset
            + UIPadding.PaddingRight.Offset + 1,
        TextSizeBounds.Y + UIPadding.PaddingTop.Offset
            + UIPadding.PaddingBottom.Offset
    )

    ChatBubble.Size = UDim2.fromOffset(
        ChatBubbleSize.X.Offset + 10,
        ChatBubbleSize.Y.Offset + 10
    )

    TweenService:Create(ChatBubble, ResizeBubbleTweenInfo, {
        Size = ChatBubbleSize,
    }):Play()

    task.delay(ResizeBubbleTweenInfo.Time, function()
        if BubbleText.Parent then
            BubbleText.Text = Message
        end
    end)

    local Lifetime
    if SentBySelf then
        ChatBubbleGui.StudsOffset = Vector3.new(0, 1.8, 0)
        Lifetime = lerpLength(Message, MIN_BUBBLE_LIFETIME_SELF, MAX_BUBBLE_LIFETIME_SELF)
    else
        ChatBubbleGui.StudsOffset = Vector3.new(0, 2.4, 0)
        Lifetime = lerpLength(Message, MIN_BUBBLE_LIFETIME, MAX_BUBBLE_LIFETIME)
    end

    ChatBubbleGui.Parent = Adornee

    task.delay(Lifetime, function()
        if not ChatBubbleGui.Parent then return end
        local FadeInfo = TweenInfo.new(BUBBLE_FADE_TIME, Enum.EasingStyle.Linear)
        for _, Object in ipairs(ChatBubbleGui:GetDescendants()) do
            if Object:IsA("ImageLabel") then
                TweenService:Create(Object, FadeInfo, { ImageTransparency = 1 }):Play()
            elseif Object:IsA("TextLabel") then
                TweenService:Create(Object, FadeInfo, { TextTransparency = 1 }):Play()
            end
        end
    end)

    Debris:AddItem(ChatBubbleGui, Lifetime + BUBBLE_FADE_TIME + 0.1)
    addBubbleToQueue(Adornee, ChatBubbleGui, Lifetime)
end

local LocalPlayer = Players.LocalPlayer

TextChatService.MessageReceived:Connect(function(TextChatMessage)
    local TextSource = TextChatMessage.TextSource
    if not TextSource then return end

    local Player = Players:GetPlayerByUserId(TextSource.UserId)
    if not Player then return end

    local Character = Player.Character
    if not Character then return end

    local Adornee = Character:FindFirstChild("Head")
        or Character:FindFirstChild("HumanoidRootPart")
        or Character
    if not Adornee then return end

    local Message = TextChatMessage.Text
    if not Message or Message == "" then return end

    createBubble(Adornee, Message, Player == LocalPlayer)
end)

task.spawn(function()
    local Camera = workspace.CurrentCamera
    while true do
        task.wait()
        Camera = workspace.CurrentCamera
        if not Camera then continue end

        for Adornee, Queue in pairs(ChatBubbleQueues) do
            if not Adornee or not Adornee.Parent then
                ChatBubbleQueues[Adornee] = nil
                continue
            end
            if #Queue == 0 then continue end

            local MostRecent = Queue[1]
            if not MostRecent or not MostRecent.Parent then continue end

            local Distance
            pcall(function()
                Distance = (Camera.CFrame.Position - Adornee:GetPivot().Position).Magnitude
            end)
            if not Distance then continue end

            for Index, BubbleGui in ipairs(Queue) do
                if not BubbleGui.Parent then continue end

                local BillboardFrame = BubbleGui:FindFirstChild("BillboardFrame")
                if not BillboardFrame then continue end

                local MainBubble  = BillboardFrame:FindFirstChild("ChatBubble")
                local SmallBubble = BillboardFrame:FindFirstChild("SmallTalkBubble")
                local MainTail    = BillboardFrame:FindFirstChild("ChatBubbleTail")

                if Distance < NEAR_BUBBLE_DISTANCE then
                    if Index == 1 then
                        if MainBubble then MainBubble.Visible = true end
                        if MainTail   then MainTail.Visible = true end
                    else
                        if MainBubble then MainBubble.Visible = true end
                        if MainTail   then MainTail.Visible = false end
                    end
                    if SmallBubble then SmallBubble.Visible = false end
                    BubbleGui.Enabled = true
                elseif Distance < MAX_BUBBLE_DISTANCE and Index == 1 then
                    if MainBubble  then MainBubble.Visible = false end
                    if MainTail    then MainTail.Visible = false end
                    if SmallBubble then SmallBubble.Visible = true end
                    BubbleGui.Enabled = true
                else
                    BubbleGui.Enabled = false
                end
            end
        end
    end
end)

print("[OldBubbles] Legacy bubble chat loaded.")
]==]

------------------------------------------------------------
-- HOOK THE 2015 / 2016 BUTTONS → RUN BUBBLE CHAT ON CLICK
------------------------------------------------------------
task.spawn(function()
	local Players    = game:GetService("Players")
	local RunService = game:GetService("RunService")

	local player = Players.LocalPlayer
	local pg     = player:WaitForChild("PlayerGui")
	local sg     = pg:WaitForChild("BloxyParadoxProject", 30)
	if not sg then
		warn("[BubbleHook] GUI never appeared.")
		return
	end

	local TARGETS = { "2015", "2016" }
	local TARGET_SET = {}
	for _, t in ipairs(TARGETS) do TARGET_SET[t] = true end

	local function runBubbleChat(label)
		print("[" .. label .. "] Running bubble chat script...")
		task.spawn(function()
			local fn, err = loadstring(EMBEDDED)
			if not fn then
				warn("[BubbleHook] Compile error: " .. tostring(err))
				return
			end
			local ok, runtimeErr = pcall(fn)
			if not ok then
				warn("[BubbleHook] Runtime error: " .. tostring(runtimeErr))
			end
		end)
	end

	local function hookButton(btn, label)
		if btn:GetAttribute("BpBubbleHooked") then return end
		btn:SetAttribute("BpBubbleHooked", true)

		btn.MouseButton1Click:Connect(function()
			runBubbleChat(label)
		end)

		print("[BubbleHook] Hooked '" .. label .. "' button.")
	end

	RunService.RenderStepped:Connect(function()
		if not sg or not sg.Parent then return end

		for _, frame in ipairs(sg:GetChildren()) do
			if frame:IsA("Frame") then
				for _, d in ipairs(frame:GetDescendants()) do
					if d:IsA("ScrollingFrame") then
						for _, opt in ipairs(d:GetChildren()) do
							if opt:IsA("TextButton") and TARGET_SET[opt.Text] then
								hookButton(opt, opt.Text)
							end
						end
					end
				end
			end
		end
	end)

	print("[BubbleHook] Watching for 2015 / 2016 buttons.")
end)