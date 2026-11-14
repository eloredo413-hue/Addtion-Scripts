-- [[ ESCAPE MENU (Addtion-Scripts) ]]
-- The old escape menus (the 2016-2021 GUIs: SettingsHub, the menu with the Players / Settings / Report /
-- Help tab bar):
--   * a gap under the tab bar (18px for 2016 and older, 14px for 2017 and later); the page scrolls
--     that much further, so its last row (Graphics Quality) isn't cut off
--   * 2017 and later: Leave / Reset Character / Resume side by side across the page, like 2023 old
-- Loaded by the loader (Script) and by the 2021 GUI after its rejoin (the loader doesn't run in the
-- server the 2021 GUI rejoins). Only one copy runs at a time.

local Env = (getgenv and getgenv()) or _G
if Env.BPEscapeMenuLoaded then return end
Env.BPEscapeMenuLoaded = true

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local getgenv = getgenv or function() return Env end

--========================================================
-- ESCAPE MENU (the GUIs before 2023 old)
--   * 2016 and older: a gap under the tab bar (Players, Settings, Report, Help), so Reset Character /
--     Leave Game don't sit against it: padding at the top of the menu's page view (SettingsHub's
--     "PageView", inside "PageViewClipper").
--   * 2017 up to 2021: also the 2023 old buttons on the Players page: Leave Game, Reset Character and
--     Resume Game side by side across the whole page.
-- The topbar year is the pick at the topbar Confirm (getgenv().BloxyTopbarPick: More guis' 2017 / 2019 /
-- 2021 are saved in Bloxy's config as 2023, so the config alone can't tell), else the saved one.
-- The buttons are found by their text, whatever the menu calls them.
--========================================================
do
    local GAP = 18      -- 2016 and older
    local GAP_2017 = 14 -- 2017 up to 2021 (a little less: their buttons have room of their own)
    local function gapFor(year)
        -- 2016 and older: their gap; 2017 and later (or a year not known): a little less
        return (year ~= nil and year <= 2016) and GAP or GAP_2017
    end

    local function topbarYear()
        -- the pick at Confirm first (More guis' 2017 / 2019 / 2021 are saved as Bloxy's 2023)
        for _, value in ipairs({ getgenv().BloxyTopbarPick, getgenv().BP_PendingTopbar, getgenv().BloxyTopbarRaw }) do
            local year = value and tonumber(string.match(tostring(value), "(20%d%d)"))
            if year then return year end
        end
        return nil
    end

    -- Inside one of the old escape menus (SettingsHub, whose tab bar is called "HubBar"). The 2023 GUIs
    -- and Roblox's own menu have none, so what is done here never touches them.
    local function inOldMenu(obj)
        local cur = obj
        for _ = 1, 12 do
            if not cur then return false end
            if cur:FindFirstChild("HubBar") then return true end
            cur = cur.Parent
        end
        return false
    end
    -- 2016 and older keep their own two buttons (and their gap); the year can only be told when it is
    -- known, so an old menu whose year isn't known is treated as 2017 or later.
    local function upTo2016(year)
        return year ~= nil and year <= 2016
    end

    -- The gap pushes the page down, but the menu sets how far its page scrolls (CanvasSize) to the
    -- page's own height, so the last row (Graphics Quality on the Settings page) was cut off at the
    -- bottom, most of all on phones. The scroll area is made taller by the gap, each time the menu
    -- sets it (a menu that sizes it by itself, AutomaticCanvasSize, already counts the gap).
    local canvasFix = setmetatable({}, { __mode = "k" })
    local function fitCanvas(view, gap)
        local automatic = false
        pcall(function() automatic = view.AutomaticCanvasSize ~= Enum.AutomaticSize.None end)
        if automatic then return end
        local state = canvasFix[view]
        local function grow()
            local base = state.base
            local want = UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale, base.Y.Offset + state.gap)
            if view.CanvasSize ~= want then
                state.ours = want
                view.CanvasSize = want
            end
        end
        if not state then
            state = { base = view.CanvasSize, gap = gap }
            canvasFix[view] = state
            view:GetPropertyChangedSignal("CanvasSize"):Connect(function()
                if view.CanvasSize == state.ours then return end -- the size set here
                state.base = view.CanvasSize                     -- the menu set its own: the gap on top
                grow()
            end)
        end
        state.gap = gap
        grow()
    end

    local function padPageView(obj)
        if obj.Name ~= "PageView" or not obj:IsA("ScrollingFrame") then return end
        local clipper = obj.Parent
        if not clipper or clipper.Name ~= "PageViewClipper" then return end
        local year = topbarYear()
        -- the scroll bar (when the player list is long) no longer narrows the page on the right, which
        -- made the page look pushed to the left of the tab bar
        pcall(function() obj.VerticalScrollBarInset = Enum.ScrollBarInset.None end)
        local pad = obj:FindFirstChild("BPMenuGap")
        if not pad then
            pad = Instance.new("UIPadding")
            pad.Name = "BPMenuGap"
            pad.Parent = obj
        end
        pad.PaddingTop = UDim.new(0, gapFor(year))
        pcall(fitCanvas, obj, gapFor(year))
    end

    -- The same gap found from the buttons: the scrolling page view they are in (for menus whose page
    -- view isn't called "PageView").
    local function padAround(obj)
        local year = topbarYear()
        local view = obj:FindFirstAncestorWhichIsA("ScrollingFrame")
        if not view then return end
        local existing = view:FindFirstChild("BPMenuGap")
        if existing then
            existing.PaddingTop = UDim.new(0, gapFor(year))
            pcall(fitCanvas, view, gapFor(year))
            return
        end
        -- only the escape menu's (SettingsHub: its tab bar is called HubBar)
        local hub = view.Parent and view.Parent.Parent
        if not (hub and hub:FindFirstChild("HubBar", true)) then return end
        pcall(function() view.VerticalScrollBarInset = Enum.ScrollBarInset.None end)
        local pad = Instance.new("UIPadding")
        pad.Name = "BPMenuGap"
        pad.PaddingTop = UDim.new(0, gapFor(year))
        pad.Parent = view
        pcall(fitCanvas, view, gapFor(year))
    end

    -- Resume: the menu is closed by its own code (SettingsHub:SetVisibility(false), found among the
    -- legacy modules the GUI loaded). A pretend Escape key press made Roblox think a keyboard and
    -- mouse were in use, so a mouse pointer showed up on phones; it is only used on a PC now, and
    -- only when the menu's own code can't be found.
    local function closeMenu()
        local closed = false
        pcall(function()
            local records = getgenv().__rbxm_suite_modules
            if type(records) ~= "table" then return end
            for module, record in pairs(records) do
                if not closed and typeof(module) == "Instance" and module.Name == "SettingsHub"
                   and type(record) == "table" then
                    local hub = rawget(record, "data")
                    if type(hub) == "table" then
                        if type(hub.SetVisibility) == "function" then
                            closed = pcall(hub.SetVisibility, hub, false)
                        elseif type(hub.Instance) == "table" and type(hub.Instance.SetVisibility) == "function" then
                            closed = pcall(hub.Instance.SetVisibility, hub.Instance, false)
                        end
                    end
                end
            end
        end)
        if closed then return end
        local UIS = game:GetService("UserInputService")
        if UIS.TouchEnabled and not UIS.KeyboardEnabled then return end
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(true, Enum.KeyCode.Escape, false, game)
            task.wait()
            vim:SendKeyEvent(false, Enum.KeyCode.Escape, false, game)
        end)
    end

    local function labelOf(button)
        for _, d in ipairs(button:GetDescendants()) do
            if d:IsA("TextLabel") then return d end
        end
        return button:IsA("TextButton") and button or nil
    end

    -- The buttons by what they say (the menus name them differently): "Reset Character", "Leave Game",
    -- "Resume Game", among the children of one frame.
    local function buttonText(obj)
        if obj:IsA("TextButton") or obj:IsA("TextLabel") then return obj.Text end
        local lbl = labelOf(obj)
        return lbl and lbl.Text or ""
    end
    local function menuButtons(parent)
        local found = {}
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("GuiObject") then
                local t = string.lower(buttonText(child) or "")
                if t == "reset character" then found.reset = child
                elseif t == "leave game" or t == "leave" then found.leave = child
                elseif t == "resume game" or t == "resume" then found.resume = child end
            end
        end
        return found
    end
    -- the button a "Reset Character" / "Leave Game" text belongs to (the text itself, or the button around it)
    local function buttonOf(obj)
        local cur = obj
        for _ = 1, 3 do
            if not cur or not cur.Parent then return nil end
            if cur:IsA("GuiButton") then return cur end
            cur = cur.Parent
        end
        return nil
    end

    -- (newer menus, 2021 among them, say "Leave" / "Resume")
    local function isMenuWord(text)
        local t = string.lower(text or "")
        return t == "reset character" or t == "leave game" or t == "leave"
    end

    local styled = setmetatable({}, { __mode = "k" })
    local told = setmetatable({}, { __mode = "k" })
    local function threeButtons(parent)
        if styled[parent] then return end
        local year = topbarYear()
        if upTo2016(year) or not inOldMenu(parent) then return end
        local found = menuButtons(parent)
        local reset, leave = found.reset, found.leave
        if not (reset and leave) then
            if not told[parent] then
                told[parent] = true
                print("[Loader] escape menu: Reset / Leave not side by side in " .. parent:GetFullName()
                    .. " (reset " .. tostring(reset ~= nil) .. ", leave " .. tostring(leave ~= nil) .. ")")
            end
            return
        end
        styled[parent] = true

        local resume = found.resume
        if not resume then
            resume = leave:Clone()
            resume.Name = "ResumeButton"
            -- the same wording as the menu's Leave: "Leave Game" -> "Resume Game", "Leave" -> "Resume"
            local function resumeWords(obj)
                local t = string.lower(obj.Text or "")
                if t == "leave game" then obj.Text = "Resume Game"
                elseif t == "leave" then obj.Text = "Resume" end
            end
            if resume:IsA("TextButton") then resumeWords(resume) end
            for _, d in ipairs(resume:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then resumeWords(d) end
            end
            resume.Parent = parent
            if resume:IsA("GuiButton") then resume.Activated:Connect(closeMenu) end
            -- A copy keeps none of the menu's button scripts: turning blue while touched (or under the
            -- mouse) is put back the way the menu's own buttons do it.
            if resume:IsA("ImageButton") then
                local NORMAL = "rbxasset://textures/ui/Settings/MenuBarAssets/MenuButton.png"
                local SELECTED = "rbxasset://textures/ui/Settings/MenuBarAssets/MenuButtonSelected.png"
                local function pointer(input)
                    return input.UserInputType == Enum.UserInputType.MouseMovement
                        or input.UserInputType == Enum.UserInputType.Touch
                end
                resume.Image = NORMAL
                resume.InputBegan:Connect(function(input)
                    if pointer(input) then resume.Image = SELECTED end
                end)
                resume.InputEnded:Connect(function(input)
                    if pointer(input) then resume.Image = NORMAL end
                end)
            end
        end
        resume.Visible = true

        -- the words a little smaller than the menu's own (24), as on the three-button menu
        local TEXT_SIZE = 18
        for _, button in ipairs({ leave, reset, resume }) do
            if button:IsA("TextButton") then pcall(function() button.TextSize = TEXT_SIZE end) end
            for _, d in ipairs(button:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    pcall(function() d.TextSize = TEXT_SIZE end)
                end
            end
        end

        -- the three-button spacing: nearly the full width of the page (lined up with the tab bar),
        -- a clear gap between the buttons
        local EDGE, BETWEEN = 0, 8
        local widthCut = (2 * EDGE + 2 * BETWEEN) / 3
        local order = { leave, reset, resume }
        local grid = parent:FindFirstChildWhichIsA("UIGridLayout")
        local list = (not grid) and parent:FindFirstChildWhichIsA("UIListLayout") or nil
        local top = reset.Position.Y
        local heights = {}
        for i, button in ipairs(order) do heights[i] = button.Size.Y end

        -- The layout is put on, and put back if the menu's own code moves the buttons again later
        -- (the 2021 menu's script lays its page out again).
        local applying = false
        local function apply()
            if applying then return end
            applying = true
            pcall(function()
                if grid then
                    grid.CellSize = UDim2.new(1 / 3, -widthCut, 0, grid.CellSize.Y.Offset)
                    grid.CellPadding = UDim2.new(0, BETWEEN, 0, grid.CellPadding.Y.Offset)
                    grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
                    for i, button in ipairs(order) do button.LayoutOrder = i end
                elseif list then
                    list.Padding = UDim.new(0, BETWEEN)
                    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
                    for i, button in ipairs(order) do
                        button.LayoutOrder = i
                        button.Size = UDim2.new(1 / 3, -widthCut, heights[i].Scale, heights[i].Offset)
                    end
                else
                    -- placed by hand: three across, the same height and top as before
                    for i, button in ipairs(order) do
                        local n = i - 1
                        local size = UDim2.new(1 / 3, -widthCut, heights[i].Scale, heights[i].Offset)
                        local pos = UDim2.new(n / 3, EDGE + n * (BETWEEN - widthCut), top.Scale, top.Offset)
                        if button.AnchorPoint ~= Vector2.new(0, 0) then button.AnchorPoint = Vector2.new(0, 0) end
                        if button.Size ~= size then button.Size = size end
                        if button.Position ~= pos then button.Position = pos end
                    end
                end
            end)
            applying = false
        end
        apply()
        for _, button in ipairs(order) do
            button:GetPropertyChangedSignal("Position"):Connect(function() task.defer(apply) end)
            button:GetPropertyChangedSignal("Size"):Connect(function() task.defer(apply) end)
        end
        if grid then grid:GetPropertyChangedSignal("CellSize"):Connect(function() task.defer(apply) end) end
        print("[Loader] escape menu (" .. tostring(year) .. "): Leave / Reset / Resume in one row")
    end

    -- The menu can be built before the topbar is picked: what was seen is looked at again for a while.
    local seenViews, seenParents = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
    local seenHubs = setmetatable({}, { __mode = "k" }) -- the escape menus (what holds a HubBar)
    local function onAdded(obj)
        if obj.Name == "PageView" then
            seenViews[obj] = true
            padPageView(obj)
        end
        if obj.Name == "HubBar" and obj.Parent then
            if not seenHubs[obj.Parent] then
                print("[Loader] escape menu found in " .. obj.Parent:GetFullName() .. "; topbar year: "
                    .. tostring(topbarYear()) .. " (pick " .. tostring(getgenv().BloxyTopbarPick)
                    .. ", saved " .. tostring(getgenv().BloxyTopbarRaw) .. ")")
            end
            seenHubs[obj.Parent] = true
        end
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            task.defer(function()
                if not isMenuWord(obj.Text) then return end
                local button = buttonOf(obj)
                if button and button.Parent then
                    seenParents[button.Parent] = true
                    pcall(padAround, button.Parent)
                    pcall(threeButtons, button.Parent)
                end
            end)
        end
    end
    -- Bloxy builds its own GUIs' menu right at the topbar Confirm, before the loader has read the pick,
    -- so the menu parts seen are looked at again at Confirm and every few seconds after (only those).
    local function recheck()
        for view in pairs(seenViews) do pcall(padPageView, view) end
        -- the menus themselves are looked through too: some put the words on their buttons after the
        -- buttons are made, which the check when a text is added can miss
        for hub in pairs(seenHubs) do
            if hub.Parent then
                pcall(function()
                    for _, d in ipairs(hub:GetDescendants()) do
                        if (d:IsA("TextLabel") or d:IsA("TextButton")) and isMenuWord(d.Text) then
                            local button = buttonOf(d)
                            if button and button.Parent and not styled[button.Parent] then
                                seenParents[button.Parent] = true
                            end
                        end
                    end
                end)
            end
        end
        for parent in pairs(seenParents) do
            if parent.Parent then
                pcall(padAround, parent)
                pcall(threeButtons, parent)
            end
        end
    end
    getgenv().BPMenuRecheck = recheck
    task.spawn(function()
        while true do
            task.wait(2)
            recheck()
        end
    end)

    task.spawn(function()
        local roots = { CoreGui }
        pcall(function()
            local hui = gethui and gethui()
            if hui and hui ~= CoreGui then table.insert(roots, hui) end
        end)
        pcall(function()
            table.insert(roots, Players.LocalPlayer:WaitForChild("PlayerGui", 10))
        end)
        for _, root in ipairs(roots) do
            pcall(function()
                for _, obj in ipairs(root:GetDescendants()) do onAdded(obj) end
                root.DescendantAdded:Connect(onAdded)
            end)
        end
    end)
end

