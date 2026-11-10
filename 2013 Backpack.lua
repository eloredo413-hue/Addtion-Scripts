-- [[ 2013 BACKPACK (touch and mouse; 3 slots on phones, 10 on tablets and PC) for the regular 2013 GUI ]]
-- The 2013 GUI (Legacy's payload) keeps its own tablet backpack on PC and tablets. It drags tools with Roblox's old
-- Draggable property, which only switches on while the mouse is over a tool: touch does nothing, and a tool dropped
-- outside a slot is taken off the hotbar and never seen again. This replaces it with the backpack of the 2013 mobile
-- GUI (touch and mouse drag; nothing is lost when a drop misses; keys 1-0 equip). Loaded by the addition script
-- when 2013 is the topbar; the 2013 mobile GUI has it built in. It starts once per server.

do
    local Players = game:GetService("Players")
    local CoreGui = game:GetService("CoreGui")
    local StarterGui = game:GetService("StarterGui")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local ContentProvider = game:GetService("ContentProvider")
    local Env = (getgenv and getgenv()) or _G

    local LocalPlayer = Players.LocalPlayer
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

    local targetParent = CoreGui
    pcall(function() if gethui then targetParent = gethui() end end)

    local guiName = "Backpack2013Gui"
    if targetParent:FindFirstChild(guiName) then targetParent[guiName]:Destroy() end
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = guiName
    screenGui.IgnoreGuiInset = true
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 999999
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    screenGui.Parent = targetParent

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


    local function isPhoneScreen()
        local viewport = workspace.CurrentCamera.ViewportSize
        return math.min(viewport.X, viewport.Y) <= 500
    end

    task.spawn(function()
        local legacyGui = CoreGui:WaitForChild("NewRobloxGui", 60)
        if not legacyGui then
            warn("[2013 backpack] the 2013 GUI (NewRobloxGui) did not appear")
            return
        end
        -- once per server (the GUI is made again in every server; the 2013 mobile GUI sets the same mark)
        if legacyGui:GetAttribute("Backpack2013Started") then
            screenGui:Destroy()
            return
        end
        legacyGui:SetAttribute("Backpack2013Started", true)
        local ok, err = pcall(startPhoneBackpack, legacyGui, not isPhoneScreen())
        if not ok then
            legacyGui:SetAttribute("Backpack2013Started", nil)
            warn("[2013 backpack] did not start: " .. tostring(err))
        else
            print("[2013 backpack] started (" .. (isPhoneScreen() and "phone" or "tablet / PC") .. ")")
        end
    end)
end
