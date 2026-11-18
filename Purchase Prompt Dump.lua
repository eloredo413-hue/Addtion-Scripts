--========================================================
-- PURCHASE PROMPT DUMP
-- Reads Roblox's own purchase prompt so the old looks (2015-2019, 2021-2023) can be matched to it. Run it, then
-- within 12 seconds open a purchase prompt in any game (tap a shop / buy button; you can press Cancel afterwards).
-- It then finds the prompt's GUI, writes down every part (names, sizes, positions, colours, fonts, texts, pictures),
-- and copies the result to your clipboard (paste it in the chat), saves it as PurchasePromptDump.lua in your
-- executor's workspace folder, and prints it in the console.
-- It only reads: nothing is changed, bought or clicked. Set getgenv().PPDumpDelay = 5 first to wait a different time.
--========================================================

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")

local function notify(text)
    print("[Purchase Prompt Dump] " .. text)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = "Purchase Prompt Dump", Text = text, Duration = 8 })
    end)
end

-- every GUI root a purchase prompt can be in, with the part that holds it
local function roots()
    local list = {}
    local function scan(container)
        if not container then return end
        for _, child in ipairs(container:GetChildren()) do
            if string.find(string.lower(child.Name), "purchase", 1, true) then table.insert(list, child) end
            if child.Name == "RobloxGui" then
                for _, d in ipairs(child:GetChildren()) do
                    if string.find(string.lower(d.Name), "purchase", 1, true) then table.insert(list, d) end
                end
            end
        end
    end
    pcall(function() scan(CoreGui) end)
    pcall(function() scan(gethui and gethui()) end)
    pcall(function() scan(Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")) end)
    return list
end

-- the properties worth keeping, by kind of object (missing ones are skipped)
local PROPS = {
    ScreenGui = { "Enabled", "DisplayOrder", "IgnoreGuiInset", "ZIndexBehavior", "ResetOnSpawn" },
    UIScale = { "Scale" },
    ScrollingFrame = { "CanvasSize", "ScrollBarThickness", "ScrollingDirection" },
    BillboardGui = { "Enabled", "Size", "SizeOffset", "StudsOffset", "StudsOffsetWorldSpace", "ExtentsOffset",
        "ExtentsOffsetWorldSpace", "MaxDistance", "AlwaysOnTop", "LightInfluence", "Brightness", "ClipsDescendants",
        "ZIndexBehavior", "ResetOnSpawn", "DistanceLowerLimit", "DistanceUpperLimit", "DistanceStep", "Active" },
    GuiObject = { "Visible", "Size", "Position", "AnchorPoint", "Rotation", "ZIndex", "LayoutOrder", "ClipsDescendants",
        "AutomaticSize", "SizeConstraint", "BackgroundColor3", "BackgroundTransparency", "BorderColor3",
        "BorderSizePixel" },
    ImageLabel = { "Image", "ImageColor3", "ImageTransparency", "ImageRectOffset", "ImageRectSize", "ScaleType",
        "SliceCenter", "SliceScale", "TileSize", "ResampleMode" },
    ImageButton = { "Image", "ImageColor3", "ImageTransparency", "ImageRectOffset", "ImageRectSize", "ScaleType",
        "SliceCenter", "SliceScale", "TileSize", "ResampleMode" },
    TextLabel = { "Text", "FontFace", "Font", "TextSize", "TextColor3", "TextTransparency", "TextStrokeColor3",
        "TextStrokeTransparency", "TextXAlignment", "TextYAlignment", "TextWrapped", "TextScaled", "TextTruncate",
        "RichText", "LineHeight" },
    TextButton = { "Text", "FontFace", "Font", "TextSize", "TextColor3", "TextTransparency", "TextXAlignment",
        "TextYAlignment", "TextWrapped", "TextScaled" },
    UICorner = { "CornerRadius" },
    UIStroke = { "Color", "Thickness", "Transparency", "ApplyStrokeMode", "LineJoinMode", "Enabled" },
    UIPadding = { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" },
    UISizeConstraint = { "MinSize", "MaxSize" },
    UITextSizeConstraint = { "MinTextSize", "MaxTextSize" },
    UIAspectRatioConstraint = { "AspectRatio", "AspectType", "DominantAxis" },
    UIGradient = { "Color", "Transparency", "Rotation", "Offset", "Enabled" },
    UIListLayout = { "FillDirection", "HorizontalAlignment", "VerticalAlignment", "SortOrder", "Padding" },
    ValueBase = { "Value" },
}

local function num(n)
    if n ~= n then return "0/0" end
    if n == math.huge then return "math.huge" end
    if n == -math.huge then return "-math.huge" end
    if n == math.floor(n) and math.abs(n) < 1e15 then return string.format("%d", n) end
    local s = string.format("%.6f", n):gsub("0+$", ""):gsub("%.$", "")
    return s
end

local function ser(v)
    local t = typeof(v)
    if t == "string" then return string.format("%q", v)
    elseif t == "number" then return num(v)
    elseif t == "boolean" then return tostring(v)
    elseif t == "UDim2" then return ("UDim2.new(%s, %s, %s, %s)"):format(num(v.X.Scale), num(v.X.Offset), num(v.Y.Scale), num(v.Y.Offset))
    elseif t == "UDim" then return ("UDim.new(%s, %s)"):format(num(v.Scale), num(v.Offset))
    elseif t == "Vector2" then return ("Vector2.new(%s, %s)"):format(num(v.X), num(v.Y))
    elseif t == "Vector3" then return ("Vector3.new(%s, %s, %s)"):format(num(v.X), num(v.Y), num(v.Z))
    elseif t == "Color3" then
        return ("Color3.fromRGB(%s, %s, %s)"):format(num(math.floor(v.R * 255 + 0.5)), num(math.floor(v.G * 255 + 0.5)), num(math.floor(v.B * 255 + 0.5)))
    elseif t == "Rect" then return ("Rect.new(%s, %s, %s, %s)"):format(num(v.Min.X), num(v.Min.Y), num(v.Max.X), num(v.Max.Y))
    elseif t == "EnumItem" then return tostring(v)
    elseif t == "Font" then
        return ("Font.new(%q, %s, %s)"):format(v.Family, tostring(v.Weight), tostring(v.Style))
    elseif t == "ColorSequence" then
        local parts = {}
        for _, k in ipairs(v.Keypoints) do table.insert(parts, ("ColorSequenceKeypoint.new(%s, %s)"):format(num(k.Time), ser(k.Value))) end
        return "ColorSequence.new({ " .. table.concat(parts, ", ") .. " })"
    elseif t == "NumberSequence" then
        local parts = {}
        for _, k in ipairs(v.Keypoints) do table.insert(parts, ("NumberSequenceKeypoint.new(%s, %s)"):format(num(k.Time), num(k.Value))) end
        return "NumberSequence.new({ " .. table.concat(parts, ", ") .. " })"
    elseif t == "Instance" then return string.format("%q", "<" .. v:GetFullName() .. ">")
    end
    return string.format("%q", "<" .. t .. " " .. tostring(v) .. ">")
end

local function propsFor(object)
    local seen, list = {}, {}
    for kind, names in pairs(PROPS) do
        if object:IsA(kind) then
            for _, name in ipairs(names) do
                if not seen[name] then
                    seen[name] = true
                    local ok, value = pcall(function() return object[name] end)
                    if ok and value ~= nil then table.insert(list, { name, value }) end
                end
            end
        end
    end
    table.sort(list, function(a, b) return a[1] < b[1] end)
    return list
end

local function relPath(object, root)
    local names = {}
    local current = object
    while current and current ~= root do
        table.insert(names, 1, current.Name)
        current = current.Parent
    end
    return table.concat(names, ".")
end


local delay = tonumber(getgenv and getgenv().PPDumpDelay) or 12
notify("Open a purchase prompt now: dumping in " .. delay .. " seconds.")
task.wait(delay)

local found = roots()
if #found == 0 then
    notify("No purchase prompt GUI found. Run it again and open a prompt (a Buy button in a game) before the time is up.")
    return
end

local lines = {
    "-- Purchase Prompt Dump (place " .. tostring(game.PlaceId) .. ")",
    "return {",
}
local count = 0
for _, root in ipairs(found) do
    local objects = { root }
    for _, d in ipairs(root:GetDescendants()) do table.insert(objects, d) end
    for _, object in ipairs(objects) do
        if not object:IsA("LuaSourceContainer") then
            count = count + 1
            table.insert(lines, ("  { path = %q, class = %q, props = {"):format(root.Name .. (object == root and "" or "." .. relPath(object, root)), object.ClassName))
            for _, pair in ipairs(propsFor(object)) do
                table.insert(lines, ("    %s = %s,"):format(pair[1], ser(pair[2])))
            end
            table.insert(lines, "  } },")
        end
    end
end
table.insert(lines, "}")
local out = table.concat(lines, "\n")

local copied, saved = false, false
pcall(function()
    local clip = setclipboard or toclipboard or (syn and syn.write_clipboard)
    if clip then clip(out); copied = true end
end)
pcall(function()
    if writefile then writefile("PurchasePromptDump.lua", out); saved = true end
end)

local chunk = {}
for i, line in ipairs(lines) do
    table.insert(chunk, line)
    if #chunk >= 25 or i == #lines then
        print(table.concat(chunk, "\n"))
        chunk = {}
    end
end

notify(("Found %d parts in %d GUI(s). %s%s"):format(count, #found,
    copied and "Copied to your clipboard: paste it in the chat. " or "Copy it from the console (F9). ",
    saved and "Also saved as PurchasePromptDump.lua." or ""))
