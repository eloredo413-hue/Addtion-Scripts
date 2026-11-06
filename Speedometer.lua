--========================================================
-- OLD-STYLE SPEEDOMETER (standalone)
-- The blue-bar speedometer of the old car HUD, taken out of the Addtion-Scripts loader as it is,
-- with the few lines it needs to run on its own. Run it once; it keeps working while you play.
--
--   * A solid blue bar and "Speed: 46" under it, always at the same place on the screen (a screen GUI),
--     while you sit in a car. The bar grows with the speed, easing smoothly, and stops at 300 pixels
--     so it fits a phone screen.
--   * It switches off the modern speedometer: Roblox's own vehicle display (the "Speed 0" with the
--     segmented bar at the bottom of the screen, CoreGui.RobloxGui.VehicleHudFrame) and the game's
--     own, so only the old one shows. Whatever it switches off is switched on again when it stops.
--   * Console messages say what it found.
--
-- Use:
--   getgenv().Speedometer.Stop()            -- turns it off, the modern speedometer comes back
--   getgenv().Speedometer.Start("show")     -- the old speedometer, the modern one hidden (what runs now)
--   getgenv().Speedometer.Start("hideOnly") -- no speedometer at all (modern one hidden, none shown)
--   getgenv().SpeedometerOnlyWithGameReadout = true   -- show it only when the game has a readout of its own
--
-- (The loader runs it only for the 2010-2014 topbars: "show" for 2010-2014, "hideOnly" for 2005 and
-- 2006, and nothing for 2015 and later, so the modern speedometer is left alone there.)
--========================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local pg = Players.LocalPlayer:WaitForChild("PlayerGui")

--========================================================
-- OLD-STYLE SPEEDOMETER (2010-2014), AND NO MODERN ONE BEFORE 2015
-- A solid blue bar with "Speed: 46" under it, as in the old car HUD of https://youtu.be/HgcfN5V0I-4.
-- From frames of a screen recording of it: the bar is plain blue, no background, always at the same
-- place on the screen (centred, a little below the middle), and its width grows with the speed,
-- roughly 7 pixels for every point of speed on a 720p screen; the text is small, plain blue, no
-- outline, centred under it. It is a screen GUI, not attached to the player or the car.
--   * The modern speedometer only shows from 2015 on. In every era up to 2014 it is switched off
--     (and kept off if it is switched on again): Roblox's own vehicle speed display (the "Speed 0"
--     with a segmented bar at the bottom, CoreGui.RobloxGui.VehicleHudFrame), the game's own
--     readout and the GUI around it that is named like a speedometer, and any GUI named like one
--     (Speedometer, SpeedoFrame ...). A dashboard on the car is left alone. 2015 and later get
--     the modern one back untouched.
--   * 2010-2014 (2010, 2011-2014, mobile) get this old one in its place, while driving: whatever the
--     game has. If the game has a visible speed readout, its number is shown (so the units match),
--     else the car's own speed. 2005 and 2006 have no speedometer at all.
--   * Only while you are sitting in a VehicleSeat (another seat once it moves).
--   * "Hide game GUI" leaves it alone (it is in the hidden-UI container, and is told to keep it).
--   * What it found is printed to the console.
-- Redrawn every frame and the bar eases toward its width, so it moves smoothly. On purpose
-- different from the original: the bar stops growing at MAX_BAR pixels, so it fits a phone screen
-- (the original kept getting wider; about 5 pixels per point of speed instead of about 7).
--========================================================
-- mode: "show" = the old speedometer, and the game's own switched off; "hideOnly" = only the game's
-- own switched off (2005 / 2006: no speedometer at all)
local function startSpeedometer(mode)
    mode = mode or "show"
    if getgenv().SpeedometerCleanup then
        if getgenv().SpeedometerMode == mode then return end   -- already on, the same way
        pcall(getgenv().SpeedometerCleanup)
    end
    local showOurs = mode == "show"

    local LocalPlayer = Players.LocalPlayer
    local BLUE = Color3.fromRGB(0, 0, 255)
    local PIXELS_PER_SPEED = 5       -- the original: about 7 on a 720p screen
    local MAX_BAR = 300              -- fits a phone screen
    local MIN_BAR = 3                -- so it can be seen at a standstill
    local BAR_HEIGHT = 12
    local EASE = 14                  -- how fast the bar follows (per second)
    local running = true
    local connections = {}
    local display = nil      -- { gui, bar, label, seat, beat, clock, readout, nextCheck, width, shownNumber }

    -- is this label a speed readout, and is it on screen?
    local SPEED_WORDS = { "speed", "mph", "km/h", "kmh", "kph", "m/s", "studs/s", "velocity", "spd" }
    local function mentionsSpeed(text)
        text = string.lower(text or "")
        for _, word in ipairs(SPEED_WORDS) do
            if string.find(text, word, 1, true) then return true end
        end
        return false
    end

    -- a title label that only says what the number next to it is: "Speed", "MPH", "km/h" ...
    local TITLE_TEXTS = { speed = true, ["speed:"] = true, spd = true, mph = true, ["km/h"] = true,
                          kmh = true, kph = true, ["m/s"] = true }
    local function isTextLabel(obj)
        local class = obj.ClassName
        return class == "TextLabel" or class == "TextButton"
    end
    local function isTitleLabel(obj)
        if not isTextLabel(obj) then return false end
        local text = string.lower(obj.Text or "")
        text = string.gsub(string.gsub(text, "^%s+", ""), "%s+$", "")
        return TITLE_TEXTS[text] == true
    end
    -- a label that is a number, maybe with a unit after it ("46", "46.5", "46 mph")
    local function isNumberLabel(obj)
        if not isTextLabel(obj) then return false end
        local text = obj.Text or ""
        return #text <= 14 and string.find(text, "^%s*%-?%d") ~= nil
    end
    -- the title next to a number label: a sibling, or a sibling of its parent. Returns the title
    -- and the container that holds both.
    local function findTitleNear(label)
        local container = label.Parent
        for _ = 1, 2 do
            if not container or container:IsA("PlayerGui") then return nil end
            for _, sibling in ipairs(container:GetChildren()) do
                if sibling ~= label and isTitleLabel(sibling) then return sibling, container end
            end
            if container:IsA("LayerCollector") then return nil end
            container = container.Parent
        end
        return nil
    end

    -- a label with a number in it that says "speed" itself, or sits in something called Speed...
    -- (a GUI named SpeedBar / Speedometer, a Frame called MPH), up to three levels up; or a number
    -- with a "Speed" title next to it
    local function looksLikeSpeedReadout(obj)
        if not isTextLabel(obj) then return false end
        local text = obj.Text or ""
        if not string.find(text, "%d") then return false end
        if mentionsSpeed(text) or mentionsSpeed(obj.Name) then return true end
        local up = obj.Parent
        for _ = 1, 3 do
            if not up or up:IsA("PlayerGui") then break end
            if mentionsSpeed(up.Name) then return true end
            up = up.Parent
        end
        return isNumberLabel(obj) and findTitleNear(obj) ~= nil
    end

    -- the game's own speedometer GUIs that are switched off by this script: target -> { prop, gameWants, conn }
    local held = {}

    -- (a GUI this script switched off is still "on screen" as far as the game is concerned)
    local function isOnScreen(obj)
        local current = obj
        while current and current ~= game do
            if not held[current] then
                if current:IsA("GuiObject") then
                    if not current.Visible then return false end
                elseif current:IsA("LayerCollector") then
                    if not current.Enabled then return false end
                end
            end
            current = current.Parent
        end
        -- a GUI that was taken out of the game is not on screen either
        return current == game
    end

    -- the game's own speed readout: in the player's GUI, or on the car (a dashboard)
    local function findReadout(seat)
        local roots = { pg }
        local car = seat:FindFirstAncestorOfClass("Model")
        if car then table.insert(roots, car) end
        for _, root in ipairs(roots) do
            for _, obj in ipairs(root:GetDescendants()) do
                if looksLikeSpeedReadout(obj) and isOnScreen(obj)
                   and not (display and obj:IsDescendantOf(display.gui)) then
                    return obj
                end
            end
        end
        return nil
    end

    -- The game's own speedometer is switched off for as long as this runs (every era up to 2014), also
    -- when you are not in a car, and switched off again if the game switches it on. When this stops
    -- (a 2015 or later topbar) the game's own comes back: if you are in a car it is switched on.
    local function holdGame(target, prop)
        if held[target] then return false end
        local up = target.Parent
        while up and up ~= game do          -- something inside one already held is covered by it
            if held[up] then return false end
            up = up.Parent
        end
        local ok = pcall(function()
            local entry = { prop = prop, gameWants = target[prop] }
            entry.conn = target:GetPropertyChangedSignal(prop):Connect(function()
                if target[prop] == true then
                    entry.gameWants = true
                    target[prop] = false        -- the game switched it on again
                end
            end)
            held[target] = entry
            target[prop] = false
        end)
        if ok then
            print("[Speedometer] the game's own speedometer is switched off: " .. target:GetFullName())
        end
        return ok
    end

    local function releaseGame()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local seated = humanoid ~= nil and humanoid.SeatPart ~= nil
        for target, entry in pairs(held) do
            pcall(function() entry.conn:Disconnect() end)
            pcall(function() target[entry.prop] = entry.gameWants and seated end)
        end
        held = {}
    end

    local function propOf(gui) return gui:IsA("LayerCollector") and "Enabled" or "Visible" end

    -- is this GUI small enough to be one gauge, not the whole HUD?
    local function isSmallWidget(gui)
        if gui:IsA("LayerCollector") then return #gui:GetDescendants() <= 12 end
        local camera = workspace.CurrentCamera
        local view = camera and camera.ViewportSize
        if not view then return false end
        local size = gui.AbsoluteSize
        return size.X > 0 and size.X <= view.X * 0.6 and size.Y <= view.Y * 0.3
    end

    -- What to switch off for a readout: the highest thing named like a speedometer within three
    -- levels above it (the same levels the readout is recognised by); else the small container that
    -- holds it and its "Speed" title (the dial or bar in it goes too); else just the readout and
    -- its title. Returns a list of { gui, property }.
    local function speedometerTargets(readout)
        local top = nil
        local up = readout.Parent
        for _ = 1, 3 do
            if not up or up:IsA("PlayerGui") then break end
            if mentionsSpeed(up.Name) then top = up end
            up = up.Parent
        end
        if top then return { { top, propOf(top) } } end
        local title, container = findTitleNear(readout)
        if container and isSmallWidget(container) then return { { container, propOf(container) } } end
        if title then return { { readout, "Visible" }, { title, "Visible" } } end
        return { { readout, "Visible" } }
    end

    -- GUIs named like a speedometer, whether or not they hold a label this can read
    local METER_WORDS = { "speedo", "speedmeter", "speed meter", "speed_meter", "speedgauge", "speed gauge", "speed_gauge" }
    local METER_EXACT = { mph = true, kmh = true, kph = true }
    local function nameSaysMeter(name)
        name = string.lower(name)
        if METER_EXACT[name] then return true end
        for _, word in ipairs(METER_WORDS) do
            if string.find(name, word, 1, true) then return true end
        end
        return false
    end

    -- Roblox's own vehicle speed display (the "Speed 0" with a segmented bar at the bottom of the screen
    -- that shows whenever you sit in a VehicleSeat): its CoreScript VehicleHud makes
    -- CoreGui.RobloxGui.VehicleHudFrame and switches it on when you sit down and off when you leave.
    -- It is not the game's GUI, so nothing in PlayerGui reaches it. Switched off (and kept off) here.
    local vehicleHudHeld = false
    local function switchOffVehicleHud()
        local robloxGui = CoreGui:FindFirstChild("RobloxGui")
        if not robloxGui then return end
        local frame = robloxGui:FindFirstChild("VehicleHudFrame")
        if not frame then
            -- another name for it: a frame with the speed bar and the speed text in it
            for _, child in ipairs(robloxGui:GetChildren()) do
                if child:FindFirstChild("SpeedBarClippingFrame")
                   or (child:FindFirstChild("SpeedText") and child:FindFirstChild("SpeedLabel")) then
                    frame = child
                    break
                end
            end
        end
        if frame then
            if not held[frame] then holdGame(frame, "Visible") end
            vehicleHudHeld = held[frame] ~= nil
        end
    end

    -- titles = true (only while driving): also a "Speed" / "MPH" title label with a number label next to
    -- it, and the small container around them (so the bar or dial in it goes too)
    local function switchOffMeters(titles)
        for _, obj in ipairs(pg:GetDescendants()) do
            if not held[obj] and nameSaysMeter(obj.Name) and not obj:GetAttribute("ClassicOwned")
               and (obj:IsA("GuiObject") or obj:IsA("LayerCollector")) then
                holdGame(obj, propOf(obj))
            elseif titles and not held[obj] and isTitleLabel(obj) then
                local container = obj.Parent
                for _ = 1, 2 do
                    if not container or container:IsA("PlayerGui") or held[container] then break end
                    local hasNumber = false
                    for _, sibling in ipairs(container:GetChildren()) do
                        if sibling ~= obj and isNumberLabel(sibling) then hasNumber = true break end
                    end
                    if hasNumber then
                        if isSmallWidget(container) then holdGame(container, propOf(container)) end
                        break
                    end
                    if container:IsA("LayerCollector") then break end
                    container = container.Parent
                end
            end
        end
    end

    local function hide()
        if not display then return end
        local shown = display
        display = nil
        pcall(function() shown.beat:Disconnect() end)
        pcall(function() shown.gui:Destroy() end)
    end

    local function barWidthFor(speed)
        return math.clamp(speed * PIXELS_PER_SPEED, MIN_BAR, MAX_BAR)
    end

    local function frame(dt)
        local shown = display
        if not shown then return end
        local seat = shown.seat
        if not seat.Parent then hide() return end
        shown.clock = shown.clock + dt

        -- the game's readout: looked for every two seconds while there is none, and checked every
        -- half second while there is one (it can be switched off, or the game can remove it)
        if shown.clock >= shown.nextCheck then
            if shown.readout and not (shown.readout.Parent and isOnScreen(shown.readout)) then
                shown.readout = nil
            end
            if not shown.readout then
                shown.readout = findReadout(seat)
                if shown.readout then
                    print("[Speedometer] the game's speed readout: " .. shown.readout:GetFullName() .. " = \"" .. tostring(shown.readout.Text) .. "\"")
                    if shown.readout:IsDescendantOf(pg) then
                        for _, entry in ipairs(speedometerTargets(shown.readout)) do
                            holdGame(entry[1], entry[2])
                        end
                    end
                end
            end
            shown.nextCheck = shown.clock + (shown.readout and 0.5 or 2)
        end
        -- GUIs named like a speedometer: looked for every two seconds while driving
        if shown.clock >= shown.nextMeterScan then
            shown.nextMeterScan = shown.clock + 2
            pcall(switchOffMeters, true)
            pcall(switchOffVehicleHud)
        end

        local physical = seat.AssemblyLinearVelocity.Magnitude
        -- always, unless it was asked to follow the game's readout only
        local needsReadout = getgenv().SpeedometerOnlyWithGameReadout == true
        local on = showOurs and (shown.readout ~= nil or not needsReadout) and (seat:IsA("VehicleSeat") or physical > 3)
        if shown.gui.Enabled ~= on then
            shown.gui.Enabled = on
            shown.justShown = on
        end
        if not on then return end

        -- the game's number if it has one, else the car's speed
        local speed = physical
        local number = shown.readout and tonumber(string.match(shown.readout.Text or "", "%d+%.?%d*"))
        if number then speed = number end

        local target = barWidthFor(speed)
        if shown.justShown then
            shown.width = target          -- no growing from nothing when it appears
            shown.justShown = false
        else
            shown.width = shown.width + (target - shown.width) * (1 - math.exp(-EASE * dt))
        end
        shown.bar.Size = UDim2.new(0, shown.width, 0, BAR_HEIGHT)

        local rounded = math.floor(speed + 0.5)
        if rounded ~= shown.shownNumber then
            shown.shownNumber = rounded
            shown.label.Text = "Speed: " .. rounded
        end
    end

    local function show(seat)
        if display and display.seat == seat then return end
        hide()

        -- a screen GUI, always in the same place: not attached to the player or the car
        local gui = Instance.new("ScreenGui")
        gui.Name = "ClassicSpeedometer"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 5
        gui.Enabled = false
        gui:SetAttribute("ClassicOwned", true)

        local holder = Instance.new("Frame")
        holder.Name = "Holder"
        holder.AnchorPoint = Vector2.new(0.5, 0)
        holder.Position = UDim2.new(0.5, 0, 0.55, 0)
        holder.Size = UDim2.new(0, MAX_BAR + 20, 0, 32)
        holder.BackgroundTransparency = 1
        holder.BorderSizePixel = 0
        holder.Parent = gui

        local bar = Instance.new("Frame")
        bar.Name = "Bar"
        bar.AnchorPoint = Vector2.new(0.5, 0)
        bar.Position = UDim2.new(0.5, 0, 0, 0)
        bar.Size = UDim2.new(0, 0, 0, BAR_HEIGHT)
        bar.BackgroundColor3 = BLUE
        bar.BorderSizePixel = 0
        bar.Parent = holder

        local label = Instance.new("TextLabel")
        label.Name = "Speed"
        label.AnchorPoint = Vector2.new(0.5, 0)
        label.Position = UDim2.new(0.5, 0, 0, BAR_HEIGHT + 2)
        label.Size = UDim2.new(0, 160, 0, 14)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Legacy
        label.TextSize = 11
        label.TextColor3 = BLUE
        label.Text = "Speed: 0"
        label.Parent = holder

        local parentGui = (gethui and gethui()) or CoreGui
        if not pcall(function() gui.Parent = parentGui end) then gui.Parent = pg end
        -- "hide game GUI" must not take this one away
        pcall(function()
            local hider = getgenv().GameGuiHider
            if hider and hider.Keep then hider.Keep(gui) end
        end)

        local shown = { gui = gui, bar = bar, label = label, seat = seat, clock = 0, nextCheck = 0, nextMeterScan = 0,
                        readout = nil, width = 0, shownNumber = nil, justShown = false }
        shown.beat = RunService.RenderStepped:Connect(frame)
        display = shown
        print("[Speedometer] " .. (showOurs and "shown" or "(no speedometer in this era)") .. " for " .. seat:GetFullName() .. " (" .. seat.ClassName .. ")")
        frame(0)
    end

    local function onSeat(humanoid)
        local seat = humanoid.SeatPart
        if running and seat then show(seat) else hide() end
    end

    local function bindCharacter(character)
        task.spawn(function()
            local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
            if not running or not humanoid then return end
            table.insert(connections, humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
                onSeat(humanoid)
            end))
            onSeat(humanoid)
        end)
    end

    table.insert(connections, LocalPlayer.CharacterAdded:Connect(function(character)
        hide()
        bindCharacter(character)
    end))
    if LocalPlayer.Character then bindCharacter(LocalPlayer.Character) end

    -- every half second: is the player in a seat? (in case an event was missed, or the character
    -- was replaced); this is two property reads
    task.spawn(function()
        while running do
            task.wait(0.5)
            if not running then break end
            if not vehicleHudHeld then pcall(switchOffVehicleHud) end   -- until it has been found
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid then onSeat(humanoid) else hide() end
        end
    end)

    local function cleanup()
        running = false
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        connections = {}
        hide()
        releaseGame()
        if getgenv().SpeedometerCleanup == cleanup then
            getgenv().SpeedometerCleanup = nil
            getgenv().SpeedometerMode = nil
        end
    end
    getgenv().SpeedometerCleanup = cleanup
    getgenv().SpeedometerMode = mode
    -- the game's speedometer GUIs that are already there, and Roblox's own vehicle speed display
    pcall(switchOffMeters)
    pcall(switchOffVehicleHud)
    print("[Loader] " .. (showOurs and "old speedometer on (2010-2014)" or "no speedometer (2005 / 2006)") .. ": the game's own speedometer is switched off")
end

local function stopSpeedometer()
    if getgenv().SpeedometerCleanup then pcall(getgenv().SpeedometerCleanup) end
end

getgenv().Speedometer = { Start = startSpeedometer, Stop = stopSpeedometer }
-- (running it again replaces the old copy)
if getgenv().SpeedometerCleanup then pcall(getgenv().SpeedometerCleanup) end
startSpeedometer("show")
