--========================================================
-- 2014 BUBBLE DUMP
-- Run this once in the "going to 2014" game. It finds that game's BubbleChat script
-- (PlayerScripts.BubbleChat) and writes down its chat bubble templates (ChatBubble and
-- Folder.ChatBubble: the bubble and tail pictures, the font, every size and position), so the
-- loader's 2011-2014 chat bubbles can be built the same way in every game.
-- The result is copied to your clipboard (paste it in the chat), saved as BubbleChat2014Dump.lua
-- in your executor's workspace folder, and printed in the console.
-- It only reads: nothing in the game is changed.
--========================================================

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer

local function notify(text)
    print("[2014 Bubble Dump] " .. text)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = "2014 Bubble Dump", Text = text, Duration = 8 })
    end)
end

-- the BubbleChat script: PlayerScripts first, then StarterPlayerScripts, then anything holding
-- a ChatBubble billboard with a "Tier" value (the template the script clones)
local function findBubbleScript()
    local playerScripts = player:FindFirstChild("PlayerScripts") or player:WaitForChild("PlayerScripts", 10)
    if playerScripts then
        local found = playerScripts:FindFirstChild("BubbleChat") or playerScripts:WaitForChild("BubbleChat", 10)
        if found then return found end
    end
    local ok, sps = pcall(function() return game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts") end)
    if ok and sps and sps:FindFirstChild("BubbleChat") then return sps.BubbleChat end
    for _, root in ipairs({ playerScripts, game:GetService("ReplicatedStorage"), game:GetService("StarterPlayer") }) do
        if root then
            for _, object in ipairs(root:GetDescendants()) do
                if object.Name == "ChatBubble" and object:IsA("BillboardGui") and object:FindFirstChild("Tier") then
                    local holder = object.Parent
                    if holder and holder.Name == "Folder" and holder.Parent then holder = holder.Parent end
                    return holder
                end
            end
        end
    end
    return nil
end

-- the properties worth keeping, by kind of object (missing ones are skipped)
local PROPS = {
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

local bubbleScript = findBubbleScript()
if not bubbleScript then
    notify("Could not find the BubbleChat script here. Run this in the 2014 game, after chatting once.")
    return
end

local lines = {
    "-- 2014 Bubble Dump of " .. bubbleScript:GetFullName() .. " (place " .. tostring(game.PlaceId) .. ")",
    "return {",
}
local count = 0
local descendants = bubbleScript:GetDescendants()
for _, object in ipairs(descendants) do
    if not object:IsA("LuaSourceContainer") then
        count = count + 1
        table.insert(lines, ("  { path = %q, class = %q, props = {"):format(relPath(object, bubbleScript), object.ClassName))
        for _, pair in ipairs(propsFor(object)) do
            table.insert(lines, ("    %s = %s,"):format(pair[1], ser(pair[2])))
        end
        table.insert(lines, "  } },")
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
    if writefile then writefile("BubbleChat2014Dump.lua", out); saved = true end
end)

-- the console cuts very long lines, so it is printed a few lines at a time
local chunk = {}
for i, line in ipairs(lines) do
    table.insert(chunk, line)
    if #chunk >= 25 or i == #lines then
        print(table.concat(chunk, "\n"))
        chunk = {}
    end
end

notify(("Found %d parts. %s%s"):format(count,
    copied and "Copied to your clipboard: paste it in the chat. " or "Copy it from the console (F9). ",
    saved and "Also saved as BubbleChat2014Dump.lua." or ""))
