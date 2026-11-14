-- [[ ESCAPE MENU (Addtion-Scripts) ]]
-- The old escape menus (the 2016-2021 GUIs: SettingsHub, the menu with the Players / Settings / Report /
-- Help tab bar):
--   * a gap under the tab bar (18px for 2016 and older, 14px for 2017 and later); the page scrolls
--     that much further, and on phones its page area ends above the bottom of the screen (it ran past
--     it); a page a little too tall for the room (Settings on a phone: Graphics Quality) is shrunk a
--     little so all of it shows, and on phones the page area's scroll bar strip is taken away (it cut off
--     Resume Game and the player rows on the right)
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

    -- Runs fn once whatever it watches has stopped changing for `quiet` seconds (one waiting thread at
    -- a time). The menu slides in from the top when it opens, and measuring it on every frame of that
    -- (and resizing the page each time) made opening the menu lag.
    local function whenStill(fn, quiet)
        local lastChange, waiting = 0, false
        local function check()
            local left = quiet - (os.clock() - lastChange)
            if left > 0 then
                task.delay(left, check)
                return
            end
            waiting = false
            pcall(fn)
        end
        return function()
            lastChange = os.clock()
            if not waiting then
                waiting = true
                task.delay(quiet, check)
            end
        end
    end

    -- On phones the menu's page area (PageViewClipper) runs past the bottom of the screen, so the last
    -- row of the Settings page (Graphics Quality) was cut off by the screen's edge and couldn't be scrolled
    -- to (the page thought it was all on show). The page area is made shorter so it ends just above the
    -- bottom of the screen, and the page scrolls instead. It is measured from where the menu puts it (not
    -- while it slides in from the top), and again whenever the menu moves or resizes it or the screen
    -- changes. Where it already fits (most PCs) nothing changes.
    local SCREEN_MARGIN = 6   -- pixels kept free above the bottom of the screen
    local MIN_HEIGHT = 100    -- never shorter than this
    local windowFix = setmetatable({}, { __mode = "k" })
    local function fitToScreen(window)
        local state = windowFix[window]
        if not state then
            state = { base = window.Size, cut = 0, said = false }
            windowFix[window] = state
            local later = whenStill(function() state.fit() end, 0.2)
            state.fit = function()
                local parent = window.Parent
                local layer = window:FindFirstAncestorWhichIsA("LayerCollector")
                if not (parent and layer and parent:IsA("GuiObject")) then return end
                -- the menu (SettingsShield) slides down from above the screen when it opens: measured
                -- from where it comes to rest (the top of what holds it)
                local slide = 0
                local shield = parent
                while shield and shield ~= layer and shield.Name ~= "SettingsShield" do shield = shield.Parent end
                if shield and shield ~= layer and shield:IsA("GuiObject") and shield.Position.Y.Scale < 0 then
                    local holder = shield.Parent
                    if holder and holder:IsA("GuiObject") then
                        slide = holder.AbsolutePosition.Y - shield.AbsolutePosition.Y
                    end
                end
                local parentHeight = parent.AbsoluteSize.Y
                local base = state.base
                local height = base.Y.Scale * parentHeight + base.Y.Offset
                local top = parent.AbsolutePosition.Y + slide
                    + window.Position.Y.Scale * parentHeight + window.Position.Y.Offset
                    - window.AnchorPoint.Y * height
                local bottom = layer.AbsolutePosition.Y + layer.AbsoluteSize.Y - SCREEN_MARGIN
                local cut = math.ceil(top + height - bottom)
                cut = math.max(0, math.min(cut, math.floor(height - MIN_HEIGHT)))
                if cut == state.cut then return end
                state.cut = cut
                state.ours = UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale, base.Y.Offset - cut)
                window.Size = state.ours
                if cut > 0 and not state.said then
                    state.said = true
                    print("[Loader] escape menu: its page area went " .. cut
                        .. "px past the bottom of the screen; it is shorter now and scrolls")
                end
            end
            window:GetPropertyChangedSignal("Size"):Connect(function()
                if window.Size == state.ours then return end -- the size set here
                state.base = window.Size                     -- the menu set its own
                state.cut = 0
                state.ours = nil
                later()
            end)
            window:GetPropertyChangedSignal("Position"):Connect(later)
            window:GetPropertyChangedSignal("AbsolutePosition"):Connect(later)
            pcall(function()
                window:FindFirstAncestorWhichIsA("LayerCollector"):GetPropertyChangedSignal("AbsoluteSize"):Connect(later)
            end)
        end
        state.fit()
    end

    -- PHONES: the page area keeps a strip on its right for its scroll bar (12 wide), and nothing is drawn
    -- under it, so whatever reached the right edge was cut off there (Resume Game, the player rows).
    -- Phones scroll by dragging, so the strip is taken away on a touch screen with no keyboard.
    -- THE SETTINGS PAGE on a phone is taller than the room under the tab bar, so Graphics Quality hung off
    -- the bottom of the screen. The page is found from its rows (a label "Graphics Quality", "Camera
    -- Mode", ...: the row is the label's frame, the page what holds the rows), whatever the menu calls its
    -- parts, and is shrunk (UIScale, its width kept) so its last row ends above whatever cuts it off: the
    -- page area's bottom, anything clipping it, or the bottom of the screen. It is measured with the menu
    -- at rest (not while it slides in from the top) and again every couple of seconds.
    local UserInputService = game:GetService("UserInputService")
    local function touchOnly()
        local ok, result = pcall(function()
            return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
        end)
        return ok and result == true
    end

    local stripped = setmetatable({}, { __mode = "k" })
    local function noStrip(view)
        if stripped[view] or not (view and view:IsA("ScrollingFrame")) or not touchOnly() then return end
        stripped[view] = true
        local function apply()
            if view.ScrollBarThickness ~= 0 then view.ScrollBarThickness = 0 end
        end
        apply()
        view:GetPropertyChangedSignal("ScrollBarThickness"):Connect(apply)
        print("[Loader] escape menu: no scroll bar strip on the page area (" .. view:GetFullName() .. ")")
    end

    local SETTINGS_ROWS = {
        ["graphics quality"] = true, ["graphics mode"] = true, ["camera mode"] = true,
        ["movement mode"] = true, ["volume"] = true, ["fullscreen"] = true,
    }
    local MIN_PAGE_SCALE = 0.6
    local SCREEN_GAP = 4
    local settingsPages = setmetatable({}, { __mode = "k" })

    local function fitSettingsPage(page)
        local state = settingsPages[page]
        if not state or not page.Parent then return end
        local layer = page:FindFirstAncestorWhichIsA("LayerCollector")
        if not layer then return end
        -- the page's own height: the bottom of its lowest row (rows are placed by offsets)
        local natural = 0
        for _, row in ipairs(page:GetChildren()) do
            if row:IsA("GuiObject") and row.Visible and row.Position.Y.Scale == 0 and row.Size.Y.Scale == 0 then
                natural = math.max(natural, row.Position.Y.Offset + row.Size.Y.Offset)
            end
        end
        if natural <= 0 then return end
        -- the menu slides down from above the screen when it opens: everything in it is measured from
        -- where it comes to rest
        local slide = 0
        local cur = page.Parent
        while cur and cur ~= layer do
            if cur.Name == "SettingsShield" and cur:IsA("GuiObject") and cur.Position.Y.Scale < 0 then
                local holder = cur.Parent
                if holder and holder:IsA("GuiObject") then
                    slide = holder.AbsolutePosition.Y - cur.AbsolutePosition.Y
                end
                break
            end
            cur = cur.Parent
        end
        -- the page's top when it isn't scrolled
        local view = page:FindFirstAncestorWhichIsA("ScrollingFrame")
        local scrolled = view and view.CanvasPosition.Y or 0
        local top = page.AbsolutePosition.Y + scrolled + slide
        -- the lowest point it can be seen down to
        local bottom = layer.AbsolutePosition.Y + layer.AbsoluteSize.Y - SCREEN_GAP
        cur = page.Parent
        while cur and cur ~= layer do
            if cur:IsA("GuiObject") and (cur.ClipsDescendants or cur:IsA("ScrollingFrame")) then
                bottom = math.min(bottom, cur.AbsolutePosition.Y + slide + cur.AbsoluteSize.Y)
            end
            cur = cur.Parent
        end
        local room = bottom - top - 2
        local scale = 1
        if room > 0 and room < natural then
            scale = math.max(MIN_PAGE_SCALE, room / natural)
        end
        local uiScale = page:FindFirstChild("BPFitScale")
        if scale == 1 and not uiScale then
            if not state.said then
                state.said = 100
                print("[Loader] escape menu Settings page: " .. natural .. " tall, " .. math.floor(room)
                    .. " of room: it fits as it is")
            end
            return
        end
        if not uiScale then
            uiScale = Instance.new("UIScale")
            uiScale.Name = "BPFitScale"
            uiScale.Parent = page
        end
        if math.abs(uiScale.Scale - scale) > 0.0005 then uiScale.Scale = scale end
        -- as wide as before: the page is made wider by as much as the scale makes it narrower
        local size = page.Size
        local want = UDim2.new(state.baseX / scale, size.X.Offset, size.Y.Scale, size.Y.Offset)
        if page.Size ~= want then
            state.ours = want
            page.Size = want
        end
        local percent = math.floor(scale * 100 + 0.5)
        if state.said ~= percent then
            state.said = percent
            print("[Loader] escape menu Settings page: " .. natural .. " tall, " .. math.floor(room)
                .. " of room down to the screen's bottom: shown at " .. percent .. "%"
                .. (scale <= MIN_PAGE_SCALE and " (the least it goes; the rest scrolls)" or " (all of it fits)"))
        end
    end

    -- a label that names one of the Settings page's rows: its page is looked after
    local function settingsRowLabel(label)
        if not (label:IsA("TextLabel") or label:IsA("TextButton")) then return end
        if not SETTINGS_ROWS[string.lower(label.Text or "")] then return end
        local row = label.Parent
        local page = row and row.Parent
        if not (page and page:IsA("GuiObject") and row:IsA("GuiObject")) or settingsPages[page] then return end
        if not inOldMenu(page) then return end
        local state = { baseX = page.Size.X.Scale }
        settingsPages[page] = state
        local later = whenStill(function() fitSettingsPage(page) end, 0.2)
        page:GetPropertyChangedSignal("Size"):Connect(function()
            if page.Size == state.ours then return end -- the size set here
            state.baseX = page.Size.X.Scale              -- the menu set its own
            state.ours = nil
            later()
        end)
        -- (when the menu has finished sliding in, not on every frame of it)
        page:GetPropertyChangedSignal("AbsolutePosition"):Connect(later)
        local view = page:FindFirstAncestorWhichIsA("ScrollingFrame")
        print("[Loader] escape menu Settings page found (" .. page:GetFullName() .. ")")
        pcall(noStrip, view)
        pcall(fitSettingsPage, page)
    end
    getgenv().BPFitMenuPages = function()
        for page in pairs(settingsPages) do pcall(fitSettingsPage, page) end
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
        pcall(fitToScreen, clipper)
    end

    -- The same gap found from the buttons: the scrolling page view they are in (for menus whose page
    -- view isn't called "PageView").
    local function padAround(obj)
        local year = topbarYear()
        local view = obj:FindFirstAncestorWhichIsA("ScrollingFrame")
        if not view then return end
        if inOldMenu(view) then pcall(noStrip, view) end
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
        -- (SettingsHub's own PageView is fitted through its PageViewClipper, above)
        if not (view.Name == "PageView" and view.Parent and view.Parent.Name == "PageViewClipper") then
            pcall(fitToScreen, view)
        end
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
        -- Put back at most once a frame, however many of the buttons' properties the menu changed. If the
        -- menu keeps moving them back (its own layout code running every frame), the two would fight on
        -- every frame while the menu is open, which lags: then the buttons are left to the menu.
        local queued, gaveUp = false, false
        local windowStart, count = os.clock(), 0
        local function queue()
            if queued or gaveUp then return end
            queued = true
            task.defer(function()
                queued = false
                local now = os.clock()
                if now - windowStart > 2 then windowStart, count = now, 0 end
                count = count + 1
                if count > 30 then
                    gaveUp = true
                    print("[Loader] escape menu: the menu keeps moving its buttons back, so they are left to it"
                        .. " (fighting it made the menu lag)")
                    return
                end
                apply()
            end)
        end
        for _, button in ipairs(order) do
            button:GetPropertyChangedSignal("Position"):Connect(queue)
            button:GetPropertyChangedSignal("Size"):Connect(queue)
        end
        if grid then grid:GetPropertyChangedSignal("CellSize"):Connect(queue) end
        print("[Loader] escape menu (" .. tostring(year) .. "): Leave / Reset / Resume in one row")
    end

    -- The menu can be built before the topbar is picked: what was seen is looked at again for a while.
    local seenViews, seenParents = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
    local seenHubs = setmetatable({}, { __mode = "k" }) -- the escape menus (what holds a HubBar)
    local hubLooked = setmetatable({}, { __mode = "k" }) -- when each menu was first and last looked through
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
        -- the menu names its parts after putting them in place (Create sets properties in any order), so
        -- they are looked at again once that is done
        if obj:IsA("ImageLabel") or obj:IsA("Frame") then
            task.defer(function()
                if obj.Name == "HubBar" and obj.Parent then seenHubs[obj.Parent] = true end
            end)
        end
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            task.defer(function()
                pcall(settingsRowLabel, obj)
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
        -- the Settings page, fitted again (and found from the menus if its rows were missed)
        for page in pairs(settingsPages) do pcall(fitSettingsPage, page) end
        -- the menus themselves are looked through too: some put the words on their buttons after the
        -- buttons are made, which the check when a text is added can miss
        local now = os.clock()
        for hub in pairs(seenHubs) do
            -- the whole menu is looked through every recheck for its first minute, then every 15 seconds
            -- (it has a lot in it: going through all of it every 2 seconds was more than needed)
            local seen = hubLooked[hub]
            if not seen then
                seen = { first = now, last = 0 }
                hubLooked[hub] = seen
            end
            local due = (now - seen.first < 60) or (now - seen.last >= 15)
            if due then seen.last = now end
            if hub.Parent and due then
                pcall(function()
                    for _, d in ipairs(hub:GetDescendants()) do
                        if d:IsA("TextLabel") or d:IsA("TextButton") then pcall(settingsRowLabel, d) end
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

