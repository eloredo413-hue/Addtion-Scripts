-- [[ 2013 MOBILE GUI (Addtion-Scripts copy) - fix: the 2013 joystick now drives vehicles (fed into Roblox's control module); no stuck jump ]]
--[[
    =========================================================
    PART 1: SERVICES, SETTINGS & PRELOADING
    =========================================================
]]

getgenv().LegacySettings = {
    Year = 2013,
    OldGraphics = true,
    HideDisplayName = true,
    SafeChat = true,
    OldConsole = false,
    OldBubbleChat = true
}

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local TextChatService = game:GetService("TextChatService")
local ChatService = game:GetService("Chat")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local TOUCH_SHEET = "rbxasset://textures/ui/TouchControlsSheet.png"

-- Disable native Roblox bubble chat safely on both chat engines
pcall(function()
    TextChatService.BubbleChatConfiguration.Enabled = false
end)
pcall(function()
    ChatService.BubbleChatEnabled = false
end)

-- Preload health, chat bubble, and mobile UI assets
task.spawn(function()
    ContentProvider:PreloadAsync({
        "rbxassetid://35238053",
        "rbxassetid://35238036",
        "rbxassetid://154646431",
        "rbxassetid://34854607",
        "rbxassetid://2582470061",
        "rbxassetid://2582470060",
        TOUCH_SHEET
    })
end)

pcall(function()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

GuiService.MenuOpened:Connect(function()
    if GuiService.IsMenuOpened then pcall(function() GuiService:SetMenuOpened(false) end) end
end)

local function eliminateNativeMenuCompletely()
    pcall(function()
        if CoreGui:FindFirstChild("TopBarApp") then CoreGui.TopBarApp:Destroy() end
        local robloxGui = CoreGui:FindFirstChild("RobloxGui")
        if robloxGui then
            for _, child in ipairs(robloxGui:GetChildren()) do
                local name = string.lower(child.Name)
                if name == "topbar" or name == "chrome" or name == "unibarleft" or name == "menubutton" then
                    child.Visible = false
                end
            end
        end
        local expChat = CoreGui:FindFirstChild("ExperienceChat")
        if expChat and expChat:FindFirstChild("appLayout") and expChat.appLayout:FindFirstChild("topBar") then
            expChat.appLayout.topBar.Visible = false
        end
    end)
end
eliminateNativeMenuCompletely()

-- Persistent Modern Touch UI Hider (Preserves Backpack/Inventory)
task.spawn(function()
    while true do
        local modernTouch = PlayerGui:FindFirstChild("TouchGui")
        if modernTouch and modernTouch.Enabled then 
            modernTouch.Enabled = false 
        end
        task.wait(0.5)
    end
end)

--[[
    =========================================================
    PART 2: UNIFIED MAIN GUI CONTAINERS (SAFE PARENTING)
    =========================================================
]]

local targetParent = CoreGui
pcall(function() if gethui then targetParent = gethui() end end)

local guiName = "LegacyMobileUI_FunctionalReplacement"
if targetParent:FindFirstChild(guiName) then targetParent[guiName]:Destroy() end
local dialogGuiName = "LegacyMobileUI_Dialog"
if targetParent:FindFirstChild(dialogGuiName) then targetParent[dialogGuiName]:Destroy() end
local touchGuiName = "LegacyTouchControls"
if targetParent:FindFirstChild(touchGuiName) then targetParent[touchGuiName]:Destroy() end
if PlayerGui:FindFirstChild(touchGuiName) then PlayerGui[touchGuiName]:Destroy() end

-- Main UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = guiName
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999999999 
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
screenGui.Parent = targetParent

-- Dialog UI
local dialogGui = Instance.new("ScreenGui")
dialogGui.Name = dialogGuiName
dialogGui.IgnoreGuiInset = false 
dialogGui.ResetOnSpawn = false
dialogGui.DisplayOrder = 999999999 
dialogGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
dialogGui.Parent = targetParent

-- Touch Controls UI (Parented to targetParent to survive resets)
local touchScreenGui = Instance.new("ScreenGui")
touchScreenGui.Name = touchGuiName
touchScreenGui.ResetOnSpawn = false
touchScreenGui.DisplayOrder = 999
touchScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
touchScreenGui.Parent = targetParent

--[[
    =========================================================
    PART 3: 2018 LEGACY MOBILE TOUCH CONTROLS
    =========================================================
]]

local JoystickFrame = Instance.new("Frame", touchScreenGui)
JoystickFrame.Name = "JoystickFrame"
JoystickFrame.Size = UDim2.new(0, 90, 0, 90)
JoystickFrame.Position = UDim2.new(0, 30, 1, -120)
JoystickFrame.BackgroundTransparency = 1
JoystickFrame.Active = true

local JoystickBase = Instance.new("ImageLabel", JoystickFrame)
JoystickBase.Name = "Base"
JoystickBase.Size = UDim2.new(1, 0, 1, 0)
JoystickBase.Image = TOUCH_SHEET
JoystickBase.ImageRectOffset = Vector2.new(0, 0)
JoystickBase.ImageRectSize = Vector2.new(220, 220)
JoystickBase.BackgroundTransparency = 1

local JoystickStick = Instance.new("ImageLabel", JoystickFrame)
JoystickStick.Name = "Stick"
JoystickStick.Size = UDim2.new(0, 42, 0, 42) 
JoystickStick.Position = UDim2.new(0.5, 0, 0.5, 0)
JoystickStick.AnchorPoint = Vector2.new(0.5, 0.5)
JoystickStick.Image = TOUCH_SHEET
JoystickStick.ImageRectOffset = Vector2.new(220, 0)
JoystickStick.ImageRectSize = Vector2.new(111, 111)
JoystickStick.BackgroundTransparency = 1
JoystickStick.ZIndex = 2

local JumpButton = Instance.new("ImageButton", touchScreenGui)
JumpButton.Name = "JumpButton"
JumpButton.Size = UDim2.new(0, 90, 0, 90)
JumpButton.Position = UDim2.new(1, -120, 1, -120)
JumpButton.BackgroundTransparency = 1
JumpButton.Image = TOUCH_SHEET
JumpButton.ImageRectOffset = Vector2.new(176, 222)
JumpButton.ImageRectSize = Vector2.new(174, 174)
JumpButton.Active = true

local moveVector = Vector3.new(0,0,0)
local walkSpeedFactor = 0
local isJumpButtonDown = false
local moveTouchObject = nil
local jumpTouchObject = nil 
local maxRadius = 45 

JoystickFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch and not moveTouchObject then
        moveTouchObject = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == moveTouchObject then
        local center = JoystickFrame.AbsolutePosition + (JoystickFrame.AbsoluteSize / 2)
        local diff = Vector2.new(input.Position.X, input.Position.Y) - center
        local dist = math.min(diff.Magnitude, maxRadius)
        walkSpeedFactor = dist / maxRadius
        local dir = diff.Magnitude > 0 and diff.Unit or Vector2.new(0,0)
        JoystickStick.Position = UDim2.new(0.5, dir.X * dist, 0.5, dir.Y * dist)
        moveVector = Vector3.new(dir.X, 0, dir.Y)
        
    elseif input == jumpTouchObject then
        local pos = input.Position
        local absPos = JumpButton.AbsolutePosition
        local absSize = JumpButton.AbsoluteSize
        
        local isInside = (pos.X >= absPos.X and pos.X <= absPos.X + absSize.X and 
                          pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y)
                          
        if not isInside then
            jumpTouchObject = nil
            isJumpButtonDown = false
            JumpButton.ImageRectOffset = Vector2.new(176, 222)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input == moveTouchObject then
        moveTouchObject = nil; moveVector = Vector3.new(0,0,0); walkSpeedFactor = 0
        JoystickStick.Position = UDim2.new(0.5, 0, 0.5, 0)
    end
end)

JumpButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch and not jumpTouchObject then
        jumpTouchObject = input
        isJumpButtonDown = true
        JumpButton.ImageRectOffset = Vector2.new(0, 222)
    end
end)

JumpButton.InputEnded:Connect(function(input)
    if input == jumpTouchObject then
        jumpTouchObject = nil
        isJumpButtonDown = false
        JumpButton.ImageRectOffset = Vector2.new(176, 222)
    end
end)

-- VEHICLES (fix, part 1): this joystick replaces Roblox's touch controls, and it only called
-- LocalPlayer:Move(), which walks a character. A car is driven by the game's vehicle code, which reads
-- Roblox's real controls (the control module), so with only this joystick nothing happened. The joystick
-- is now fed into the control module itself: when it asks the active controller for the move vector it
-- gets this stick's. Cars (VehicleSeat or the game's own) then react exactly as to Roblox's own controls,
-- while the 2013 controls stay the ones on screen. The control module also does the walking then.
-- Nothing is swapped or hidden, so no button can be left held down by it.
local lastConsulted = -1
local function controlsAreFed()
    return os.clock() - lastConsulted < 0.25
end

do
    local controls = nil
    local fedController = nil
    local nextLook = 0

    local function findControls()
        if controls then return controls end
        local ok, found = pcall(function()
            local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
            local module = scripts and scripts:FindFirstChild("PlayerModule")
            if not module then return nil end
            return require(module):GetControls()
        end)
        if ok and type(found) == "table" then controls = found end
        return controls
    end

    RunService.RenderStepped:Connect(function()
        if not controls then
            -- Roblox's controls may not exist yet: look again every two seconds
            local now = os.clock()
            if now < nextLook then return end
            nextLook = now + 2
            if not findControls() then return end
        end
        local controller = controls.activeController
        if controller and controller ~= fedController then
            -- a new active controller (touch, keyboard, ...): the stick is fed into that one too
            pcall(function()
                local original = controller.GetMoveVector
                if type(original) ~= "function" then return end
                controller.GetMoveVector = function(self, ...)
                    if walkSpeedFactor > 0 and moveVector.Magnitude > 0 then
                        lastConsulted = os.clock()
                        return moveVector * walkSpeedFactor
                    end
                    return original(self, ...)
                end
                fedController = controller
            end)
        end
    end)
end

-- Nothing may stay held that is not: a touch that ended without this GUI hearing about it (a finger that
-- slid off, a GUI that was hidden for a moment) used to leave the jump button pressed down.
local function releaseJump()
    jumpTouchObject = nil
    isJumpButtonDown = false
    JumpButton.ImageRectOffset = Vector2.new(176, 222)
end
local function releaseStick()
    moveTouchObject = nil
    moveVector = Vector3.new(0,0,0)
    walkSpeedFactor = 0
    JoystickStick.Position = UDim2.new(0.5, 0, 0.5, 0)
end
local function touchIsOver(touch)
    return touch.UserInputState == Enum.UserInputState.End or touch.UserInputState == Enum.UserInputState.Cancel
end
UserInputService.InputEnded:Connect(function(input)
    if input == jumpTouchObject then releaseJump() end
end)

RunService.RenderStepped:Connect(function()
    if jumpTouchObject and touchIsOver(jumpTouchObject) then releaseJump() end
    if moveTouchObject and touchIsOver(moveTouchObject) then releaseStick() end

    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    -- (when the control module is being fed the stick, it does the moving itself)
    if moveVector.Magnitude > 0 and not controlsAreFed() then
        LocalPlayer:Move(moveVector * walkSpeedFactor, true)
    end
    
    if isJumpButtonDown then
        local state = hum:GetState()
        local canJump = (hum.FloorMaterial ~= Enum.Material.Air or hum.Sit or state == Enum.HumanoidStateType.Climbing or state == Enum.HumanoidStateType.Swimming)
        
        if canJump then
            hum.Jump = true
            if state == Enum.HumanoidStateType.Climbing then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
end)

-- VEHICLES (fix, part 2, only if part 1 cannot work): when the control module is not asking for this
-- stick (a game without Roblox's control module), a VehicleSeat is driven directly: stick up = forward,
-- down = brake / reverse, left / right = steer. It runs just after Roblox's control step and only while
-- the stick is held. Letting go, or getting out, puts the throttle and steering back to 0.
do
    local STEP_NAME = "Legacy2013VehicleDrive"
    local drivenSeat = nil

    local function releaseSeat(seat)
        if seat and seat.Parent then
            pcall(function()
                seat.ThrottleFloat = 0
                seat.SteerFloat = 0
            end)
        end
    end

    pcall(function() RunService:UnbindFromRenderStep(STEP_NAME) end)
    RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Input.Value + 1, function()
        local character = LocalPlayer.Character
        local hum = character and character:FindFirstChildOfClass("Humanoid")
        local seat = hum and hum.SeatPart
        if seat and not seat:IsA("VehicleSeat") then seat = nil end

        if drivenSeat and drivenSeat ~= seat then
            releaseSeat(drivenSeat)
            drivenSeat = nil
        end

        if seat and walkSpeedFactor > 0 and not controlsAreFed() then
            local stick = moveVector * walkSpeedFactor
            pcall(function()
                seat.ThrottleFloat = -stick.Z
                seat.SteerFloat = stick.X
            end)
            drivenSeat = seat
        elseif drivenSeat then
            releaseSeat(drivenSeat)
            drivenSeat = nil
        end
    end)
end

--[[
    =========================================================
    PART 4: CLASSIC HEALTH SYSTEM
    =========================================================
]]

local HurtOverlay = Instance.new("ImageLabel")
HurtOverlay.Name = "HurtOverlay"
HurtOverlay.BackgroundTransparency = 1
HurtOverlay.Image = "rbxassetid://34854607"
HurtOverlay.Size = UDim2.new(1, 0, 1, 0)
HurtOverlay.Position = UDim2.new(0, 0, 0, 0)
HurtOverlay.Visible = false
HurtOverlay.ZIndex = 1
HurtOverlay.Parent = screenGui

local HealthFrame = Instance.new("Frame")
HealthFrame.Name = "HealthFrame"
HealthFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
HealthFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
HealthFrame.Position = UDim2.new(0.5, -85, 1, -22)
HealthFrame.Size = UDim2.new(0, 170, 0, 18)
HealthFrame.ZIndex = 99999
HealthFrame.Parent = screenGui

local HealthBar = Instance.new("ImageLabel")
HealthBar.Name = "HealthBar"
HealthBar.BackgroundTransparency = 1
HealthBar.Image = "rbxassetid://35238053"
HealthBar.Size = UDim2.new(1, 0, 1, 0)
HealthBar.ZIndex = 99999
HealthBar.Parent = HealthFrame

local HealthLabel = Instance.new("TextLabel")
HealthLabel.Name = "HealthLabel"
HealthLabel.Text = "Health  "
HealthLabel.Font = Enum.Font.SourceSansBold
HealthLabel.TextSize = 14
HealthLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
HealthLabel.TextStrokeTransparency = 0
HealthLabel.TextXAlignment = Enum.TextXAlignment.Right
HealthLabel.BackgroundTransparency = 1
HealthLabel.Size = UDim2.new(1, 0, 1, 0)
HealthLabel.ZIndex = 99999
HealthLabel.Parent = HealthFrame

local lastHealth = 100
local healthConn, diedConn, charConn

local function AnimateHurtOverlay()
    HurtOverlay.Size = UDim2.new(1, 0, 1, 0)
    HurtOverlay.Position = UDim2.new(0, 0, 0, 0)
    HurtOverlay.Visible = true

    local tweenInfo = TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(HurtOverlay, tweenInfo, {
        Size = UDim2.new(20, 0, 20, 0),
        Position = UDim2.new(-10, 0, -10, 0)
    })
    
    tween:Play()
    task.delay(10, function() HurtOverlay.Visible = false end)
end

local function UpdateGui(currentHealth, humanoid)
    if not humanoid then return end
    
    local healthPercent = currentHealth / humanoid.MaxHealth
    
    if healthPercent == healthPercent then
        if healthPercent > 0.25 then
            HealthBar.Image = "rbxassetid://35238053"
        else
            HealthBar.Image = "rbxassetid://35238036"
        end
    else
        HealthBar.Image = "rbxassetid://154646431"
    end

    local clampedPercent = math.max(math.min(healthPercent, 1), 0)
    local damageTaken = lastHealth - currentHealth
    lastHealth = currentHealth

    local sizeTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
    local sizeTween = TweenService:Create(HealthBar, sizeTweenInfo, {
        Size = UDim2.new(clampedPercent, 0, 1, 0)
    })
    sizeTween:Play()

    if damageTaken > 0 and (humanoid.MaxHealth * 0.05 <= damageTaken) then
        AnimateHurtOverlay()
    end
end

local function setupCharacter(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then return end

    lastHealth = humanoid.Health
    UpdateGui(humanoid.Health, humanoid)

    if healthConn then healthConn:Disconnect() end
    if diedConn then diedConn:Disconnect() end

    healthConn = humanoid.HealthChanged:Connect(function(health) UpdateGui(health, humanoid) end)
    diedConn = humanoid.Died:Connect(function() UpdateGui(0, humanoid) end)
end

if LocalPlayer.Character then task.spawn(function() setupCharacter(LocalPlayer.Character) end) end
charConn = LocalPlayer.CharacterAdded:Connect(setupCharacter)

--[[
    =========================================================
    PART 5: TOP LEFT UI CONTAINER & LEAVE MENU
    =========================================================
]]

local container = Instance.new("Frame")
container.Name = "ButtonContainer"
container.Size = UDim2.new(0, 250, 0, 28.999) 
container.Position = UDim2.new(0, 10, 0, 2)
container.BackgroundTransparency = 1
container.ZIndex = 99999
container.Parent = screenGui

local listLayout = Instance.new("UIListLayout", container)
listLayout.FillDirection = Enum.FillDirection.Horizontal
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 0)

local leaveButtonToggleState = false
local updateLeaveButtonVisuals = nil

local leaveDialog = Instance.new("Frame")
leaveDialog.Name = "LeaveDialog"
leaveDialog.Size = UDim2.new(0, 355, 0, 220)
leaveDialog.AnchorPoint = Vector2.new(0.5, 0.5)
leaveDialog.Position = UDim2.new(0.5, 0, 1.5, 0)
leaveDialog.BackgroundColor3 = Color3.fromRGB(115, 115, 115)
leaveDialog.BorderSizePixel = 0
leaveDialog.Visible = false
leaveDialog.ZIndex = 99999
leaveDialog.Parent = dialogGui

Instance.new("UICorner", leaveDialog).CornerRadius = UDim.new(0, 2)
local dialogStroke = Instance.new("UIStroke", leaveDialog)
dialogStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
dialogStroke.Color = Color3.fromRGB(255, 255, 255)
dialogStroke.Thickness = 1

local dialogMessage = Instance.new("TextLabel")
dialogMessage.Size = UDim2.new(1, -30, 0, 110)
dialogMessage.Position = UDim2.new(0, 15, 0, 15)
dialogMessage.BackgroundTransparency = 1
dialogMessage.Font = Enum.Font.SourceSansBold
dialogMessage.Text = "Are you sure you want to leave this game?"
dialogMessage.TextColor3 = Color3.fromRGB(255, 255, 255)
dialogMessage.TextSize = 34
dialogMessage.TextWrapped = true
dialogMessage.TextXAlignment = Enum.TextXAlignment.Center
dialogMessage.ZIndex = 999999
dialogMessage.Parent = leaveDialog

local function showLeaveDialog()
    leaveDialog.Position = UDim2.new(0.5, 0, 1.5, 0)
    leaveDialog.Visible = true
    TweenService:Create(leaveDialog, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0.5, -18)}):Play()
end

local function applyButtonPressEffect(btn)
    local isPressed = false
    btn.InputBegan:Connect(function(input) 
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
            isPressed = true
            TweenService:Create(btn, TweenInfo.new(0.12), {ImageColor3 = Color3.fromRGB(150, 150, 150)}):Play()
        end 
    end)
    btn.InputEnded:Connect(function(input) 
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
            if isPressed then
                isPressed = false
                TweenService:Create(btn, TweenInfo.new(0.12), {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
            end
        end 
    end)
    btn.MouseLeave:Connect(function()
        if isPressed then
            isPressed = false
            TweenService:Create(btn, TweenInfo.new(0.12), {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
        end
    end)
end

local cancelBtn = Instance.new("ImageButton")
cancelBtn.Name = "CancelButton"
cancelBtn.Size = UDim2.new(0, 150, 0, 55)
cancelBtn.Position = UDim2.new(0, 20, 1, -75)
cancelBtn.BackgroundTransparency = 1
cancelBtn.Image = "rbxassetid://5698789475"
cancelBtn.ZIndex = 999999
cancelBtn.Parent = leaveDialog

applyButtonPressEffect(cancelBtn)

cancelBtn.Activated:Connect(function()
    leaveButtonToggleState = false
    if updateLeaveButtonVisuals then updateLeaveButtonVisuals(false) end
    local hideTween = TweenService:Create(leaveDialog, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.5, 0, 1.5, 0)})
    hideTween:Play()
    hideTween.Completed:Connect(function() if not leaveButtonToggleState then leaveDialog.Visible = false end end)
end)

local confirmLeaveBtn = Instance.new("ImageButton")
confirmLeaveBtn.Name = "ConfirmLeaveButton"
confirmLeaveBtn.Size = UDim2.new(0, 150, 0, 55) 
confirmLeaveBtn.Position = UDim2.new(0, 185, 1, -75)
confirmLeaveBtn.BackgroundTransparency = 1
confirmLeaveBtn.Image = "rbxassetid://5698790766"
confirmLeaveBtn.ZIndex = 999999
confirmLeaveBtn.Parent = leaveDialog

applyButtonPressEffect(confirmLeaveBtn)

confirmLeaveBtn.Activated:Connect(function()
    pcall(function() TeleportService:TeleportToPlaceInstance(0, "") end)
    task.wait(0.1)
    pcall(function() game:Shutdown() end)
end)

local function createExactVintageLeaveButton()
    local wrapper = Instance.new("Frame", container)
    wrapper.Name = "LeaveIconWrapper"
    wrapper.BackgroundTransparency = 1
    wrapper.Size = UDim2.new(0, 71, 0, 28.999) 
    wrapper.LayoutOrder = 1

    local btn = Instance.new("ImageButton", wrapper)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Image = "rbxassetid://107261331"
    btn.AutoButtonColor = false
    btn.ZIndex = 999999

    local isPressed, isToggledDark = false, false

    updateLeaveButtonVisuals = function(active)
        isToggledDark = active
        isPressed = false
        TweenService:Create(btn, TweenInfo.new(0.12), {
            ImageColor3 = active and Color3.fromRGB(150, 150, 150) or Color3.fromRGB(255, 255, 255)
        }):Play()
    end

    btn.InputBegan:Connect(function(input) 
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
            if not isToggledDark then
                isPressed = true
                TweenService:Create(btn, TweenInfo.new(0.12), {ImageColor3 = Color3.fromRGB(150, 150, 150)}):Play()
            end
        end 
    end)
    
    btn.InputEnded:Connect(function(input) 
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
            if isPressed and not isToggledDark then
                isPressed = false
                TweenService:Create(btn, TweenInfo.new(0.12), {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
            end
        end 
    end)
    
    btn.MouseLeave:Connect(function()
        if isPressed and not isToggledDark then
            isPressed = false
            TweenService:Create(btn, TweenInfo.new(0.12), {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
        end
    end)
    
    btn.Activated:Connect(function()
        leaveButtonToggleState = not leaveButtonToggleState
        if leaveButtonToggleState then
            showLeaveDialog()
        else
            local hideTween = TweenService:Create(leaveDialog, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.5, 0, 1.5, 0)})
            hideTween:Play()
            hideTween.Completed:Connect(function() if not leaveButtonToggleState then leaveDialog.Visible = false end end)
        end
        if updateLeaveButtonVisuals then updateLeaveButtonVisuals(leaveButtonToggleState) end
    end)
end
createExactVintageLeaveButton()

--[[
    =========================================================
    PART 6: UI HIJACKER (CHAT ENFORCER)
    =========================================================
]]

local capturedChatButton = nil
local capturedChatOriginal = nil
local capturedChatIsLegacy = false

-- Roblox's own UI. Its settings menu has option rows named like "Voice ChatFrame" and
-- "Voice Chat VolumeFrame", which must never be mistaken for the chat button.
local nativeUiRoots = { RobloxGui = true, ExperienceChat = true, TopBarApp = true }

local function hijackLegacyUI(uiElement)
    if not uiElement:IsA("GuiObject") then return end

    pcall(function()
        local insideMenu = false
        local current = uiElement
        while current and current ~= game do
            if current.Name == "LegacyMobileUI_FunctionalReplacement" or current.Name == "ClassicBubbleGui" or current.Name == "LegacyTouchControls" then return end
            if current ~= uiElement then
                local ancestorName = string.lower(current.Name)
                if nativeUiRoots[current.Name] or string.find(ancestorName, "menu") or string.find(ancestorName, "settings") then
                    insideMenu = true
                end
            end
            current = current.Parent
        end

        local name = string.lower(uiElement.Name or "")
        local text = ""
        if uiElement:IsA("TextLabel") or uiElement:IsA("TextButton") then
            text = string.lower(uiElement.Text or "")
        end
        
        if (text == "chat" or string.find(name, "chat") or string.find(name, "chaticon")) and uiElement:IsA("GuiButton") then
            -- Only one chat button goes in the top bar, and never a row pulled out of a menu.
            -- The 2013 payload's own chat button wins over anything found before it.
            if insideMenu then return end
            local isLegacy = uiElement:FindFirstAncestor("NewRobloxGui") ~= nil
            local previous, previousOriginal = capturedChatButton, capturedChatOriginal
            if previous and previous ~= uiElement and previous.Parent then
                if capturedChatIsLegacy or not isLegacy then return end
            end

            capturedChatButton = uiElement
            capturedChatOriginal = { Parent = uiElement.Parent, LayoutOrder = uiElement.LayoutOrder, Visible = uiElement.Visible, ZIndex = uiElement.ZIndex }
            capturedChatIsLegacy = isLegacy
            capturedChatButton.Parent = container 
            capturedChatButton.LayoutOrder = 2 
            capturedChatButton.Visible = true
            capturedChatButton.ZIndex = 999999

            -- Hand a replaced button back to the UI it came from
            if previous and previous ~= uiElement then
                pcall(function()
                    previous.LayoutOrder = previousOriginal.LayoutOrder
                    previous.Visible = previousOriginal.Visible
                    previous.ZIndex = previousOriginal.ZIndex
                    previous.Parent = previousOriginal.Parent
                end)
            end

        elseif text == "menu" or string.find(name, "menu") or string.find(name, "settings") then
            uiElement.Position = UDim2.new(9999, 0, 9999, 0)
            uiElement.Visible = false
        end
    end)
end

RunService.Heartbeat:Connect(function()
    if capturedChatButton then
        pcall(function()
            if capturedChatButton.Parent ~= container then capturedChatButton.Parent = container end
            if capturedChatButton.LayoutOrder ~= 2 then capturedChatButton.LayoutOrder = 2 end
        end)
    end
end)

local function setupHijacker(targetContainer)
    if not targetContainer then return end
    for _, element in ipairs(targetContainer:GetDescendants()) do hijackLegacyUI(element) end
    targetContainer.DescendantAdded:Connect(function(element)
        task.defer(function() hijackLegacyUI(element) end)
    end)
end

setupHijacker(CoreGui)
if gethui then setupHijacker(gethui()) end
if LocalPlayer then
    local pGui = LocalPlayer:WaitForChild("PlayerGui", 5)
    setupHijacker(pGui)
end

--[[
    =========================================================
    PART 7: LOAD THE 2013 PAYLOAD 
    =========================================================
]]

local success, errorMessage = pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/yeku/legacy/refs/heads/main/Source.luau"))()
end)

if not success then
    warn("Failed to load payload: " .. tostring(errorMessage))
end

--[[
    =========================================================
    PART 8: 2008 CLASSIC BUBBLE CHAT SYSTEM
    =========================================================
]]

local function createClassicBubble(head, messageText)
    if not head or not head:IsA("BasePart") then return end
    
    local oldBubble = head:FindFirstChild("ClassicBubbleGui")
    if oldBubble then oldBubble:Destroy() end
    
    local classicFont = Font.new(
        "rbxasset://fonts/families/Arial.json",
        Enum.FontWeight.Regular,
        Enum.FontStyle.Normal
    )
    local fontSize = 22
    local maxTextWidth = 220 
    
    local absoluteTextSize = TextService:GetTextSize(
        messageText, 
        fontSize, 
        Enum.Font.Arial, 
        Vector2.new(maxTextWidth, 1000)
    )
    
    local width = math.clamp(absoluteTextSize.X + 36, 75, maxTextWidth + 36)
    local height = absoluteTextSize.Y + 24 + 12 
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ClassicBubbleGui"
    billboard.Size = UDim2.new(0, width, 0, height)
    billboard.Adornee = head
    billboard.StudsOffset = Vector3.new(0, 3.2, 0)
    billboard.AlwaysOnTop = false
    billboard.MaxDistance = 40

    local bubbleBody = Instance.new("ImageLabel")
    bubbleBody.Name = "BubbleBody"
    bubbleBody.Image = "rbxassetid://2582470061"
    bubbleBody.BackgroundTransparency = 1
    bubbleBody.ScaleType = Enum.ScaleType.Slice
    bubbleBody.SliceCenter = Rect.new(29, 29, 67, 67)
    bubbleBody.SliceScale = 0.5
    bubbleBody.Size = UDim2.new(1, 0, 1, -2) 
    bubbleBody.Parent = billboard

    local bubbleTail = Instance.new("ImageLabel")
    bubbleTail.Name = "BubbleTail"
    bubbleTail.Size = UDim2.new(0, 16, 0, 12)
    bubbleTail.Position = UDim2.new(0.5, -8, 1, -9.5)
    bubbleTail.BackgroundTransparency = 1
    bubbleTail.Image = "rbxassetid://2582470060"
    bubbleTail.Parent = billboard

    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "BubbleText"
    textLabel.Size = UDim2.new(1, -24, 1, -20)
    textLabel.Position = UDim2.new(0, 12, 0, 10)
    textLabel.BackgroundTransparency = 1
    textLabel.FontFace = classicFont
    textLabel.TextSize = fontSize
    textLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.TextWrapped = true
    textLabel.Text = messageText
    textLabel.Parent = billboard
    
    billboard.Parent = head
    
    task.delay(10, function()
        if billboard and billboard.Parent then
            billboard:Destroy()
        end
    end)
end

local lastProcessedMessage = {}

local function processPlayerChat(player, message)
    if not player or typeof(message) ~= "string" or message == "" then return end
    
    local key = player.UserId
    local now = os.clock()
    if lastProcessedMessage[key] and lastProcessedMessage[key].text == message and (now - lastProcessedMessage[key].time) < 0.25 then
        return
    end
    lastProcessedMessage[key] = { text = message, time = now }

    local character = player.Character
    if character then
        local head = character:FindFirstChild("Head")
        if head then
            createClassicBubble(head, message)
        end
    end
end

local function trackPlayerBubbles(player)
    player.Chatted:Connect(function(message)
        processPlayerChat(player, message)
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    trackPlayerBubbles(p)
end
Players.PlayerAdded:Connect(trackPlayerBubbles)

pcall(function()
    TextChatService.MessageReceived:Connect(function(textChatMessage)
        if textChatMessage.TextSource then
            local senderPlayer = Players:GetPlayerByUserId(textChatMessage.TextSource.UserId)
            if senderPlayer then
                processPlayerChat(senderPlayer, textChatMessage.Text)
            end
        end
    end)
end)

--[[
    =========================================================
    PART 9: 2013 BACKPACK (TOUCH AND MOUSE; 3 SLOTS ON PHONES, 10 ON TABLETS AND PC)
    =========================================================
]]

-- The 2013 payload only builds its phone backpack when its screen is 320px tall or less, so
-- modern phones get the 600x400 tablet window that covers most of the screen. On phones its
-- hotbar, inventory window and tab are hidden and replaced by the phone layout below.

-- desktop = a big screen (tablet or PC): ten hotbar slots with 1-0 as keys and a bigger window. Phones keep the
-- three slots and the small window. Touch and mouse both work on both (the payload's own backpack only reacts
-- to a mouse hovering over a tool, so a drag did nothing with touch and dropped the tool into the void).
local function startPhoneBackpack(legacyGui, desktop)
    local SLOT_IMAGE = "rbxassetid://97613075"
    local LOADOUT_IMAGE = "rbxassetid://96536002"
    local LOADOUT_EDGE_IMAGE = "rbxassetid://97662207"
    local LOADOUT_OPEN_IMAGE = "rbxassetid://97623721"
    local TAB_UP_IMAGE = "rbxassetid://97617958"
    local TAB_DOWN_IMAGE = "rbxassetid://97644093"

    local SLOT_COUNT = desktop and 10 or 3
    local SLOT_SIZE = 54
    local SLOT_PITCH = 60
    local LOADOUT_WIDTH = SLOT_COUNT * SLOT_PITCH
    local LOADOUT_Y = -85
    local CELL_SIZE = 52
    local CELL_GAP = 2
    local GRID_COLUMNS = desktop and 7 or 3
    local GRID_ROWS = desktop and 4 or 2
    -- window: the grid (14 px in from the left, 32 down), then the scroll bar
    local PANEL_WIDTH = 14 + GRID_COLUMNS * (CELL_SIZE + CELL_GAP) - CELL_GAP + 12 + 19
    local PANEL_HEIGHT = 32 + GRID_ROWS * (CELL_SIZE + CELL_GAP)
    local PANEL_BOTTOM = -88
    local EQUIPPED_SCALE = 1.18
    local DRAG_THRESHOLD = 8
    local slideInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local hiddenGuis = setmetatable({}, { __mode = "k" })
    local function keepHidden(gui)
        if not gui or hiddenGuis[gui] then return end
        local property = gui:IsA("LayerCollector") and "Enabled" or "Visible"
        hiddenGuis[gui] = true
        gui[property] = false
        gui:GetPropertyChangedSignal(property):Connect(function()
            if gui[property] then gui[property] = false end
        end)
    end

    task.spawn(function()
        keepHidden(legacyGui:WaitForChild("CurrentLoadout", 30))
        keepHidden(legacyGui:WaitForChild("Backpack", 30))
        local controlFrame = legacyGui:WaitForChild("ControlFrame", 30)
        keepHidden(controlFrame and controlFrame:WaitForChild("BackpackButton", 30))
    end)

    -- Only the 2013 backpack is shown: keep Roblox's own backpack off even when the game turns it on
    local function disableRobloxBackpack()
        pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
    end
    disableRobloxBackpack()
    StarterGui.CoreGuiChangedSignal:Connect(function(coreGuiType, enabled)
        if enabled and (coreGuiType == Enum.CoreGuiType.Backpack or coreGuiType == Enum.CoreGuiType.All) then
            disableRobloxBackpack()
        end
    end)

    -- ...and hide the game's own inventories and hotbars
    local CUSTOM_INVENTORY_WORDS = { "backpack", "inventory", "hotbar", "toolbar" }
    local function hideIfCustomInventory(gui)
        if not (gui:IsA("GuiObject") or gui:IsA("LayerCollector")) then return end
        local name = string.lower(gui.Name)
        for _, word in ipairs(CUSTOM_INVENTORY_WORDS) do
            if string.find(name, word, 1, true) then
                keepHidden(gui)
                return
            end
        end
    end
    for _, gui in ipairs(PlayerGui:GetDescendants()) do hideIfCustomInventory(gui) end
    PlayerGui.DescendantAdded:Connect(function(gui)
        task.defer(hideIfCustomInventory, gui)
    end)

    task.spawn(function()
        ContentProvider:PreloadAsync({ SLOT_IMAGE, LOADOUT_IMAGE, LOADOUT_EDGE_IMAGE, LOADOUT_OPEN_IMAGE, TAB_UP_IMAGE, TAB_DOWN_IMAGE })
    end)

    -- Gear button shared by the hotbar slots, the backpack grid and the drag preview
    local function createGearButton(parent, zIndex)
        local button = Instance.new("ImageButton")
        button.Name = "Gear"
        button.BackgroundTransparency = 1
        button.AutoButtonColor = false
        button.Size = UDim2.new(1, 0, 1, 0)
        button.ZIndex = zIndex
        button.Parent = parent

        local background = Instance.new("ImageLabel")
        background.Name = "Background"
        background.BackgroundTransparency = 1
        background.Image = SLOT_IMAGE
        background.Size = UDim2.new(1, 0, 1, 0)
        background.ZIndex = zIndex
        background.Parent = button

        local gearImage = Instance.new("ImageLabel")
        gearImage.Name = "GearImage"
        gearImage.BackgroundTransparency = 1
        gearImage.Size = UDim2.new(1, 0, 1, 0)
        gearImage.ZIndex = zIndex + 1
        gearImage.Parent = button

        local gearText = Instance.new("TextLabel")
        gearText.Name = "GearText"
        gearText.BackgroundTransparency = 1
        gearText.Font = Enum.Font.Arial
        gearText.TextSize = 14
        gearText.TextColor3 = Color3.new(1, 1, 1)
        gearText.TextWrapped = true
        gearText.Text = ""
        gearText.Position = UDim2.new(0, -8, 0, -8)
        gearText.Size = UDim2.new(1, 16, 1, 16)
        gearText.ZIndex = zIndex + 2
        gearText.Parent = button

        return button
    end

    local function showTool(button, tool)
        local texture = tool and tool.TextureId or ""
        button.GearImage.Image = texture
        button.GearText.Text = (tool and texture == "") and tool.Name or ""
    end

    -- Hotbar
    local loadout = Instance.new("Frame")
    loadout.Name = "PhoneLoadout"
    loadout.BackgroundTransparency = 1
    loadout.Size = UDim2.new(0, LOADOUT_WIDTH, 0, SLOT_SIZE)
    loadout.Position = UDim2.new(0.5, -LOADOUT_WIDTH / 2, 1, LOADOUT_Y)
    loadout.Visible = false
    loadout.Parent = screenGui

    local loadoutBackground = Instance.new("ImageLabel")
    loadoutBackground.Name = "Background"
    loadoutBackground.BackgroundTransparency = 1
    loadoutBackground.ZIndex = 14
    loadoutBackground.Visible = false
    loadoutBackground.Parent = loadout

    local loadoutEdge = Instance.new("ImageLabel")
    loadoutEdge.Name = "TopEdge"
    loadoutEdge.BackgroundTransparency = 1
    loadoutEdge.Image = LOADOUT_EDGE_IMAGE
    loadoutEdge.Size = UDim2.new(1, 0, 0.025, 1)
    loadoutEdge.ZIndex = 14
    loadoutEdge.Parent = loadoutBackground

    local slotFrames, slotButtons = {}, {}
    for slot = 1, SLOT_COUNT do
        local slotFrame = Instance.new("Frame")
        slotFrame.Name = "Slot" .. slot
        slotFrame.BackgroundColor3 = Color3.new(0, 0, 0)
        slotFrame.BackgroundTransparency = 1
        slotFrame.BorderColor3 = Color3.new(1, 1, 1)
        slotFrame.Size = UDim2.new(0, SLOT_SIZE, 1, 0)
        slotFrame.Position = UDim2.new(0, (slot - 1) * SLOT_PITCH, 0, 0)
        slotFrame.ZIndex = 15
        slotFrame.Parent = loadout
        slotFrames[slot] = slotFrame
        slotButtons[slot] = createGearButton(slotFrame, 16)
    end

    -- Backpack window
    local panel = Instance.new("Frame")
    panel.Name = "PhoneBackpack"
    panel.Active = true
    panel.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    panel.BorderSizePixel = 0
    panel.ClipsDescendants = true
    panel.Size = UDim2.new(0, PANEL_WIDTH, 0, 0)
    panel.Position = UDim2.new(0.5, -PANEL_WIDTH / 2, 1, LOADOUT_Y)
    panel.Visible = false
    panel.ZIndex = 10
    panel.Parent = screenGui

    local gridClip = Instance.new("Frame")
    gridClip.Name = "GearGrid"
    gridClip.BackgroundTransparency = 1
    gridClip.ClipsDescendants = true
    gridClip.Position = UDim2.new(0, 14, 0, 32)
    gridClip.Size = UDim2.new(0, GRID_COLUMNS * (CELL_SIZE + CELL_GAP) - CELL_GAP, 0, GRID_ROWS * (CELL_SIZE + CELL_GAP))
    gridClip.ZIndex = 11
    gridClip.Parent = panel

    local gridContent = Instance.new("Frame")
    gridContent.Name = "Content"
    gridContent.BackgroundTransparency = 1
    gridContent.Size = UDim2.new(1, 0, 1, 0)
    gridContent.ZIndex = 11
    gridContent.Parent = gridClip

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, CELL_SIZE, 0, CELL_SIZE)
    gridLayout.CellPadding = UDim2.new(0, CELL_GAP, 0, CELL_GAP)
    gridLayout.FillDirectionMaxCells = GRID_COLUMNS
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = gridContent

    local scrollTrack = Instance.new("Frame")
    scrollTrack.Name = "ScrollTrack"
    scrollTrack.BackgroundColor3 = Color3.fromRGB(48, 48, 48)
    scrollTrack.BorderSizePixel = 0
    scrollTrack.Position = UDim2.new(1, -19, 0, 35)
    scrollTrack.Size = UDim2.new(0, 17, 0, PANEL_HEIGHT - 45)
    scrollTrack.ZIndex = 11
    scrollTrack.Parent = panel

    local function createScrollButton(name, arrow, position)
        local button = Instance.new("TextButton")
        button.Name = name
        button.BackgroundColor3 = Color3.new(1, 1, 1)
        button.BorderSizePixel = 0
        button.Position = position
        button.Size = UDim2.new(1, 0, 0, 17)
        button.Font = Enum.Font.SourceSansBold
        button.Text = arrow
        button.TextColor3 = Color3.new(0, 0, 0)
        button.TextSize = 11
        button.ZIndex = 12
        button.Parent = scrollTrack
        Instance.new("UICorner", button).CornerRadius = UDim.new(0, 3)
        return button
    end

    local scrollUpButton = createScrollButton("ScrollUp", "▲", UDim2.new(0, 0, 0, 0))
    local scrollDownButton = createScrollButton("ScrollDown", "▼", UDim2.new(0, 0, 1, -17))

    -- Tab above the hotbar that opens and closes the window
    local tab = Instance.new("ImageButton")
    tab.Name = "BackpackButton"
    tab.BackgroundTransparency = 1
    tab.Image = TAB_UP_IMAGE
    tab.Size = UDim2.new(0, 120, 0, 18)
    tab.Position = UDim2.new(0.5, -60, 1, -108)
    tab.Visible = false
    tab.ZIndex = 19
    tab.Parent = screenGui

    local tools = {} -- every tool the player has, in the order it was received
    local hotbar = {} -- hotbar[slot] = tool shown in that slot
    local toolConnections = {}
    local gridCells = {}
    local slotTargets = {}
    local slotEnlarged = {}
    local currentBackpack, currentCharacter = nil, nil
    local panelOpen, panelBusy, panelTween = false, false, nil
    local scrollRow = 0
    local press = nil -- finger held on a hotbar slot or backpack item
    local refreshQueued = false
    local queueRefresh = nil

    local function getHumanoid()
        return currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
    end

    local function isOwned(tool)
        local parent = tool.Parent
        return parent ~= nil and (parent == currentBackpack or parent == currentCharacter)
    end

    local function slotOf(tool)
        for slot = 1, SLOT_COUNT do
            if hotbar[slot] == tool then return slot end
        end
        return nil
    end

    local function isOver(guiObject, position)
        local topLeft, size = guiObject.AbsolutePosition, guiObject.AbsoluteSize
        return position.X >= topLeft.X and position.X <= topLeft.X + size.X
            and position.Y >= topLeft.Y and position.Y <= topLeft.Y + size.Y
    end

    local function syncTools()
        for index = #tools, 1, -1 do
            local tool = tools[index]
            if not isOwned(tool) then
                table.remove(tools, index)
                toolConnections[tool]:Disconnect()
                toolConnections[tool] = nil
                local slot = slotOf(tool)
                if slot then hotbar[slot] = nil end
            end
        end

        local holders = {}
        if currentBackpack then table.insert(holders, currentBackpack) end
        if currentCharacter then table.insert(holders, currentCharacter) end
        for _, holder in ipairs(holders) do
            for _, child in ipairs(holder:GetChildren()) do
                if child:IsA("Tool") and not table.find(tools, child) then
                    table.insert(tools, child)
                    toolConnections[child] = child.Changed:Connect(function(property)
                        if property == "TextureId" or property == "Name" then queueRefresh() end
                    end)
                    -- New gear takes the first empty hotbar slot, like the 2013 loadout
                    for slot = 1, SLOT_COUNT do
                        if not hotbar[slot] then
                            hotbar[slot] = child
                            break
                        end
                    end
                end
            end
        end
    end

    local function toggleEquip(tool)
        local humanoid = getHumanoid()
        if not tool or not humanoid or humanoid.Health <= 0 or not isOwned(tool) then return end
        if tool.Parent == currentCharacter then
            humanoid:UnequipTools()
        else
            humanoid:EquipTool(tool)
        end
    end

    -- The equipped slot grows a little, like 2013
    local function setEnlarged(slot, enlarged)
        if slotEnlarged[slot] == enlarged then return end
        slotEnlarged[slot] = enlarged
        local scale = enlarged and EQUIPPED_SCALE or 1
        TweenService:Create(slotButtons[slot], TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(scale, 0, scale, 0),
            Position = UDim2.new((1 - scale) / 2, 0, (1 - scale) / 2, 0)
        }):Play()
    end

    local function setPanelOpen(open, instant)
        if open == panelOpen then return end
        panelOpen = open
        if panelTween then panelTween:Cancel() end
        if not open and press and press.ghost then
            press.ghost:Destroy()
            press = nil
        end

        local size = UDim2.new(0, PANEL_WIDTH, 0, open and PANEL_HEIGHT or 0)
        local position = UDim2.new(0.5, -PANEL_WIDTH / 2, 1, open and PANEL_BOTTOM - PANEL_HEIGHT or LOADOUT_Y)
        if instant then
            panelTween = nil
            panelBusy = false
            panel.Size = size
            panel.Position = position
            panel.Visible = open
        else
            panelBusy = true
            panel.Visible = true
            panelTween = TweenService:Create(panel, slideInfo, { Size = size, Position = position })
            panelTween.Completed:Connect(function(playbackState)
                if playbackState ~= Enum.PlaybackState.Completed then return end
                panelBusy = false
                panel.Visible = panelOpen
                queueRefresh()
            end)
            panelTween:Play()
        end
        queueRefresh()
    end

    local function beginPress(input, tool, fromSlot, button)
        if not tool then return end
        if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if press then
            if press.input.UserInputState ~= Enum.UserInputState.End then return end
            if press.ghost then press.ghost:Destroy() end
        end
        press = { input = input, start = Vector2.new(input.Position.X, input.Position.Y), tool = tool, fromSlot = fromSlot, button = button }
    end

    local function createGridCell(index)
        local cell = createGearButton(gridContent, 11)
        cell.LayoutOrder = index
        cell.InputBegan:Connect(function(input)
            beginPress(input, tools[index], nil, cell)
        end)
        gridCells[index] = cell
        return cell
    end

    local function render()
        local humanoid = getHumanoid()
        local active = humanoid ~= nil and humanoid.Health > 0
        if panelOpen and (not active or #tools == 0) then
            setPanelOpen(false, not active)
        end

        local filledSlots = {}
        for slot = 1, SLOT_COUNT do
            if hotbar[slot] then table.insert(filledSlots, slot) end
        end

        loadout.Visible = active
        loadoutBackground.Visible = panelOpen or #filledSlots > 0
        loadoutEdge.Visible = not panelOpen
        if panelOpen then
            loadoutBackground.Image = LOADOUT_OPEN_IMAGE
            loadoutBackground.Position = UDim2.new(-0.03, 0, -0.17, 0)
            loadoutBackground.Size = UDim2.new(1.05, 0, 1.25, 0)
        else
            loadoutBackground.Image = LOADOUT_IMAGE
            loadoutBackground.Position = UDim2.new(-0.1, 0, -0.1, 0)
            loadoutBackground.Size = UDim2.new(1.2, 0, 1.2, 0)
        end

        -- While the window is open every slot sits in place so gear can be dropped into it,
        -- otherwise only the filled slots show, centred under the tab
        local pitchShare = SLOT_PITCH / LOADOUT_WIDTH -- (a third on the phone's three slots)
        local centerStart = 0.5 - #filledSlots * pitchShare / 2
        for slot = 1, SLOT_COUNT do
            local tool = hotbar[slot]
            local target = nil
            if panelOpen then
                target = UDim2.new(0, (slot - 1) * SLOT_PITCH, 0, 0)
            elseif tool then
                target = UDim2.new(centerStart + (table.find(filledSlots, slot) - 1) * pitchShare, 0, 0, 0)
            end
            if target and target ~= slotTargets[slot] then
                slotTargets[slot] = target
                TweenService:Create(slotFrames[slot], slideInfo, { Position = target }):Play()
            end
            slotFrames[slot].BackgroundTransparency = panelOpen and 0.5 or 1
            slotButtons[slot].Visible = tool ~= nil
            showTool(slotButtons[slot], tool)
            setEnlarged(slot, tool ~= nil and tool.Parent == currentCharacter)
        end

        tab.Visible = active and #tools > 0 and not (panelOpen and panelBusy)
        if panelOpen then
            tab.Image = TAB_DOWN_IMAGE
            tab.Position = UDim2.new(0.5, -60, 1, PANEL_BOTTOM - PANEL_HEIGHT - 15)
        else
            tab.Image = TAB_UP_IMAGE
            tab.Position = UDim2.new(0.5, -60, 1, #filledSlots > 0 and -108 or -44)
        end

        for index, tool in ipairs(tools) do
            local cell = gridCells[index] or createGridCell(index)
            cell.Visible = true
            showTool(cell, tool)
        end
        for index = #tools + 1, #gridCells do
            gridCells[index].Visible = false
        end

        local lastRow = math.max(0, math.ceil(#tools / GRID_COLUMNS) - GRID_ROWS)
        scrollRow = math.clamp(scrollRow, 0, lastRow)
        gridContent.Position = UDim2.new(0, 0, 0, -scrollRow * (CELL_SIZE + CELL_GAP))
        scrollUpButton.TextTransparency = scrollRow > 0 and 0 or 0.6
        scrollDownButton.TextTransparency = scrollRow < lastRow and 0 or 0.6
    end

    queueRefresh = function()
        if refreshQueued then return end
        refreshQueued = true
        task.defer(function()
            refreshQueued = false
            syncTools()
            render()
        end)
    end

    local function dropTool(tool, fromSlot, position)
        if not isOwned(tool) then return end
        for slot = 1, SLOT_COUNT do
            if isOver(slotFrames[slot], position) then
                local previousSlot = slotOf(tool)
                if previousSlot then hotbar[previousSlot] = hotbar[slot] end
                hotbar[slot] = tool
                queueRefresh()
                return
            end
        end
        -- Gear dragged off the hotbar stays in the backpack only, like 2013
        if fromSlot and hotbar[fromSlot] == tool and not isOver(loadout, position) then
            hotbar[fromSlot] = nil
            queueRefresh()
        end
    end

    local function followsPress(input, mouseType)
        return input == press.input
            or (press.input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == mouseType)
    end

    UserInputService.InputChanged:Connect(function(input)
        if not press or not followsPress(input, Enum.UserInputType.MouseMovement) then return end
        local position = Vector2.new(input.Position.X, input.Position.Y)
        if not press.ghost then
            -- Gear can only be dragged around while the window is open, like 2013
            if not panelOpen or (position - press.start).Magnitude < DRAG_THRESHOLD then return end
            press.ghost = createGearButton(screenGui, 30)
            press.ghost.AnchorPoint = Vector2.new(0.5, 0.5)
            press.ghost.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
            showTool(press.ghost, press.tool)
        end
        local origin = screenGui.AbsolutePosition
        press.ghost.Position = UDim2.new(0, position.X - origin.X, 0, position.Y - origin.Y)
    end)

    UserInputService.InputEnded:Connect(function(input)
        if not press or not followsPress(input, Enum.UserInputType.MouseButton1) then return end
        local released = press
        local position = Vector2.new(input.Position.X, input.Position.Y)
        press = nil
        if released.ghost then
            released.ghost:Destroy()
            dropTool(released.tool, released.fromSlot, position)
        elseif isOver(released.button, position) then
            toggleEquip(released.tool)
        end
    end)

    for slot = 1, SLOT_COUNT do
        local button = slotButtons[slot]
        button.InputBegan:Connect(function(input)
            beginPress(input, hotbar[slot], slot, button)
        end)
    end

    tab.Activated:Connect(function()
        if not panelBusy then setPanelOpen(not panelOpen, false) end
    end)

    -- keys 1 to 9 and 0 equip the hotbar slot, as in 2013 (when a keyboard is there)
    local SLOT_KEYS = {
        [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4,
        [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6, [Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8,
        [Enum.KeyCode.Nine] = 9, [Enum.KeyCode.Zero] = 10,
    }
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local slot = SLOT_KEYS[input.KeyCode]
        if slot and slot <= SLOT_COUNT and hotbar[slot] then toggleEquip(hotbar[slot]) end
    end)

    scrollUpButton.Activated:Connect(function()
        scrollRow = scrollRow - 1
        queueRefresh()
    end)

    scrollDownButton.Activated:Connect(function()
        scrollRow = scrollRow + 1
        queueRefresh()
    end)

    local backpackConnections, characterConnections = {}, {}

    local function disconnectAll(connections)
        for _, connection in ipairs(connections) do connection:Disconnect() end
        table.clear(connections)
    end

    local function bindBackpack(backpack)
        disconnectAll(backpackConnections)
        currentBackpack = backpack
        if backpack then
            table.insert(backpackConnections, backpack.ChildAdded:Connect(queueRefresh))
            table.insert(backpackConnections, backpack.ChildRemoved:Connect(queueRefresh))
        end
        queueRefresh()
    end

    local function bindCharacter(character)
        disconnectAll(characterConnections)
        currentCharacter = character
        setPanelOpen(false, true)
        -- Every life starts with a fresh hotbar, like the 2013 loadout
        for _, connection in pairs(toolConnections) do connection:Disconnect() end
        table.clear(toolConnections)
        table.clear(tools)
        table.clear(hotbar)
        scrollRow = 0
        if character then
            table.insert(characterConnections, character.ChildAdded:Connect(queueRefresh))
            table.insert(characterConnections, character.ChildRemoved:Connect(queueRefresh))
            task.spawn(function()
                local humanoid = character:WaitForChild("Humanoid", 10)
                if humanoid and currentCharacter == character then
                    table.insert(characterConnections, humanoid.Died:Connect(queueRefresh))
                end
            end)
        end
        queueRefresh()
    end

    LocalPlayer.ChildAdded:Connect(function(child)
        if child:IsA("Backpack") then bindBackpack(child) end
    end)
    LocalPlayer.CharacterAdded:Connect(bindCharacter)
    bindBackpack(LocalPlayer:FindFirstChildOfClass("Backpack"))
    bindCharacter(LocalPlayer.Character)
end

-- Every screen gets this backpack (touch and mouse both work in it); a big screen (tablet or PC) gets the
-- ten-slot version. Same small-screen rule Roblox's menus use.
local function isPhoneScreen()
    local viewport = workspace.CurrentCamera.ViewportSize
    return math.min(viewport.X, viewport.Y) <= 500
end

task.spawn(function()
    local legacyGui = CoreGui:WaitForChild("NewRobloxGui", 30)
    if not legacyGui then
        warn("[2013 backpack] the 2013 GUI (NewRobloxGui) did not appear")
        return
    end
    if legacyGui:GetAttribute("Backpack2013Started") then return end   -- (the addition script's copy already runs)
    legacyGui:SetAttribute("Backpack2013Started", true)
    local ok, err = pcall(startPhoneBackpack, legacyGui, not isPhoneScreen())
    if not ok then
        legacyGui:SetAttribute("Backpack2013Started", nil)
        warn("[2013 backpack] did not start: " .. tostring(err))
    else
        print("[2013 backpack] started (" .. (isPhoneScreen() and "phone" or "tablet / PC") .. ")")
    end
end)
