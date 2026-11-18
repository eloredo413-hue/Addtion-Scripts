-- [[ EARLY 2011 ROBLOX CLIENT GUI - COMPLETE UNIFIED SCRIPT ]]
-- Uses the authentic October 25, 2011 (0.47.0.380) Roblonium archive textures:
--   https://archive.roblonium.com/Client/Windows/RobloxApp/2011/10.2011/October%2025%20%280.47.0.380%29/version-87de5333d4254860/content/textures/
--   https://archive.roblonium.com/Client/Windows/RobloxApp/2011/10.2011/October%2025%20%280.47.0.380%29/version-87de5333d4254860/content/textures/ui/
-- Automatically downloads and caches the real 2011 PNGs via game:HttpGet + writefile + getcustomasset
-- (with rbxasset://textures/ and rbxassetid:// fallbacks) including normal, hover (_ovr), and pressed (_dn) button states.
--
-- (Addtion-Scripts copy of the 2011gui gist, loaded by More guis through the loader:)
--   * the chat log (top left) gets every message by itself. It was filled only by the chat bubbles'
--     part, which the loader's own 2011-style bubbles switch off (both use ClassicBubbleCleanup), so
--     with them on the log stayed empty
--   * the buttons as in the 2011 client: Leave, the menu (list), mouse lock (on a phone: shift lock,
--     the character turns with the camera), settings; on the right "Record" with its words, the
--     screenshot, the camera buttons, "REPORT" with its words, full screen

--========================================================
-- CLEANUP PREVIOUS CONNECTIONS & GUIS
--========================================================
if _G.CustomEarly2011Gui_Connections then
	for _, conn in pairs(_G.CustomEarly2011Gui_Connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
end
_G.CustomEarly2011Gui_Connections = {}

local function storeConnection(conn)
	if conn then
		table.insert(_G.CustomEarly2011Gui_Connections, conn)
	end
	return conn
end

local env = (type(getgenv) == "function" and getgenv()) or _G
if env.ClassicBubbleCleanup then
	pcall(env.ClassicBubbleCleanup)
	env.ClassicBubbleCleanup = nil
end
if env.OldHealthBar and type(env.OldHealthBar.Stop) == "function" then
	pcall(env.OldHealthBar.Stop)
end
for _, key in ipairs({ "_Roblox2014HealthCleanup", "_Roblox2012HealthCleanup", "_Roblox2013HealthCleanup" }) do
	if env[key] then
		pcall(env[key])
		env[key] = nil
	end
end

--========================================================
-- SERVICES
--========================================================
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local Chat = game:GetService("Chat")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
	task.wait()
	LocalPlayer = Players.LocalPlayer
end
local Camera = Workspace.CurrentCamera

--========================================================
-- 2011 ROBLONIUM ARCHIVE TEXTURE LOADER
--========================================================
local ARCHIVE_BASE = "https://archive.roblonium.com/Client/Windows/RobloxApp/2011/10.2011/October%2025%20%280.47.0.380%29/version-87de5333d4254860/content/textures/"
-- (Addtion-Scripts) the December 2, 2010 client (the first with this look) first; what it doesn't have, from
-- May 2011, February 2011, then October 2011 (the same pictures)
local ARCHIVE_BASES = {
	"https://archive.roblonium.com/Client/Windows/RobloxApp/2010/12.2010/December%202%20%280.29.0.1%29%20-%20First%20client%20with%20new%20UI/version-ddd9de6fd55e4df2/content/textures/",
	"https://archive.roblonium.com/Client/Windows/RobloxApp/2011/5.2011/May%2020%20%280.40.0.202%29/version-5fb0645efa584e24/content/textures/",
	"https://archive.roblonium.com/Client/Windows/RobloxApp/2011/2.2011/February%20%280.34.0.22%29/version-2de7d827839d40a3/content/textures/",
	ARCHIVE_BASE,
}
local ARCHIVE_TAGS = { dec = 1, may = 2, feb = 3, oct = 4 }
local customAssetFunc = (type(getcustomasset) == "function" and getcustomasset)
	or (type(getsynasset) == "function" and getsynasset)
local canWriteFiles = (type(writefile) == "function") and (type(isfile) == "function") and (customAssetFunc ~= nil)

if canWriteFiles and type( makefolder ) == "function" and type( isfolder ) == "function" then
	pcall(function()
		if not isfolder("Early2011Textures") then
			makefolder("Early2011Textures")
		end
	end)
end

local resolvedTextureCache = {}

-- Resolves a texture from the October 25, 2011 Roblonium archive (e.g. "RecordToggle.png" or "ui/BottomRightControl.png")
local function get2011Texture(relPath, fallbackAsset)
	if resolvedTextureCache[relPath] then
		return resolvedTextureCache[relPath]
	end

	if canWriteFiles then
		local safeName = "Early2011v2_" .. relPath:gsub("[^%w%.]", "_")
		local filePath = (type(isfolder) == "function" and isfolder("Early2011Textures"))
			and ("Early2011Textures/" .. safeName)
			or safeName

		local okReady = false
		pcall(function()
			if isfile(filePath) then
				okReady = true
			else
				-- ("dec:", "may:", "feb:" or "oct:" in front: only that client's picture, never another's)
				local bases, path = ARCHIVE_BASES, relPath
				local tag, rest = relPath:match("^(%a%a%a):(.+)$")
				if tag and ARCHIVE_TAGS[tag] then
					bases, path = { ARCHIVE_BASES[ARCHIVE_TAGS[tag]] }, rest
				end
				for _, base in ipairs(bases) do
					local okHttp, bytes = pcall(game.HttpGet, game, base .. path)
					-- (a PNG: the archive's "not found" page is HTML)
					if okHttp and type(bytes) == "string" and #bytes > 64 and bytes:sub(2, 4) == "PNG" then
						writefile(filePath, bytes)
						okReady = true
						break
					end
				end
			end
		end)

		if okReady then
			local okAsset, customId = pcall(customAssetFunc, filePath)
			if okAsset and type(customId) == "string" and customId ~= "" then
				resolvedTextureCache[relPath] = customId
				return customId
			end
		end
	end

	local finalFallback = fallbackAsset or ("rbxasset://textures/" .. (relPath:gsub("^%a%a%a:", "")))
	resolvedTextureCache[relPath] = finalFallback
	return finalFallback
end

-- Asynchronously binds normal, hover (_ovr), and pressed (_dn) textures from the 2011 archive to an ImageButton/ImageLabel
local function bind2011ButtonStates(btn, iconTarget, normalRel, ovrRel, dnRel, fallbackId, fallbackRotation)
	iconTarget = iconTarget or btn
	iconTarget.Image = fallbackId or ("rbxasset://textures/" .. (normalRel:gsub("^%a%a%a:", "")))
	if fallbackRotation then
		iconTarget.Rotation = fallbackRotation
	end

	task.spawn(function()
		local normalTex = get2011Texture(normalRel, fallbackId)
		local ovrTex = ovrRel and get2011Texture(ovrRel, normalTex) or normalTex
		local dnTex = dnRel and get2011Texture(dnRel, ovrTex) or ovrTex

		iconTarget.Image = normalTex
		if normalTex ~= fallbackId then
			iconTarget.Rotation = 0
		end

		if btn:IsA("GuiButton") then
			local isHovering = false
			storeConnection(btn.MouseEnter:Connect(function()
				isHovering = true
				iconTarget.Image = ovrTex
			end))
			storeConnection(btn.MouseLeave:Connect(function()
				isHovering = false
				iconTarget.Image = normalTex
			end))
			storeConnection(btn.MouseButton1Down:Connect(function()
				iconTarget.Image = dnTex
			end))
			storeConnection(btn.MouseButton1Up:Connect(function()
				iconTarget.Image = isHovering and ovrTex or normalTex
			end))
		end
	end)
end

--========================================================
-- DISABLE DEFAULT ROBLOX UI
--========================================================
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

pcall(function()
	CoreGui.TopBarApp.TopBarApp.Enabled = false
end)

--========================================================
-- TEXT CHAT CONFIGURATION & NATIVE BUBBLE DISABLER
--========================================================
local function findGeneralChannel()
	local channels = TextChatService:FindFirstChild("TextChannels")
	if not channels then
		channels = TextChatService:WaitForChild("TextChannels", 5)
	end
	if not channels then
		warn("[Early 2011 GUI] TextChatService.TextChannels was not found.")
		return nil
	end
	local channel = channels:FindFirstChild("RBXGeneral")
	if channel and channel:IsA("TextChannel") then
		return channel
	end
	channel = channels:WaitForChild("RBXGeneral", 5)
	if channel and channel:IsA("TextChannel") then
		return channel
	end
	warn("[Early 2011 GUI] RBXGeneral was not found.")
	return nil
end

local GeneralChannel = findGeneralChannel()

pcall(function()
	TextChatService.ChatWindowConfiguration.Enabled = false
	TextChatService.ChatInputBarConfiguration.Enabled = false
end)

local function disableDefaultBubbles()
	pcall(function()
		local bubbleConfig = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
			or TextChatService:FindFirstChild("BubbleChatConfiguration")
		if bubbleConfig then
			bubbleConfig.Enabled = false
		end
	end)
end

disableDefaultBubbles()

--========================================================
-- UI PARENT TARGET & CLEANUP
--========================================================
local parentTarget = CoreGui
pcall(function()
	if type(gethui) == "function" then
		parentTarget = gethui()
	end
end)

for _, oldName in ipairs({"BottomBarApp", "Classic2010Gui", "Early2011Gui", "CustomHealthGui", "BPOldHealthBar"}) do
	local old = parentTarget:FindFirstChild(oldName)
	if old then
		pcall(function()
			old:Destroy()
		end)
	end
	local oldCore = CoreGui:FindFirstChild(oldName)
	if oldCore then
		pcall(function()
			oldCore:Destroy()
		end)
	end
end

--========================================================
-- MAIN SCREENGUI & AUTOMATIC SCREEN SCALING
--========================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Early2011Gui"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local parentOk = pcall(function()
	ScreenGui.Parent = parentTarget
end)
if not parentOk or not ScreenGui.Parent then
	ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local trackedScales = {}
local function computeUIScale()
	Camera = Workspace.CurrentCamera
	if not Camera then
		return 1
	end
	local viewport = Camera.ViewportSize
	if viewport.X <= 0 or viewport.Y <= 0 then
		return 1
	end
	local scaleX = viewport.X / 1200
	local scaleY = viewport.Y / 720
	return math.clamp(math.min(scaleX, scaleY), 0.5, 1.25)
end

local function applyAutoScale(targetGui)
	local scaleObj = targetGui:FindFirstChild("AutoUIScale") or Instance.new("UIScale")
	scaleObj.Name = "AutoUIScale"
	scaleObj.Scale = computeUIScale()
	scaleObj.Parent = targetGui
	table.insert(trackedScales, scaleObj)
	return scaleObj
end

local function updateAllUIScales()
	local newScale = computeUIScale()
	for i = #trackedScales, 1, -1 do
		local s = trackedScales[i]
		if s and s.Parent then
			s.Scale = newScale
		else
			table.remove(trackedScales, i)
		end
	end
end

applyAutoScale(ScreenGui)
if Camera then
	storeConnection(Camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateAllUIScales))
end
storeConnection(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if Workspace.CurrentCamera then
		storeConnection(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateAllUIScales))
		updateAllUIScales()
	end
end))
updateAllUIScales()

--========================================================
-- 1. HELP DIALOG WINDOW
--========================================================
local HelpDialog = Instance.new("Frame")
HelpDialog.Name = "HelpDialog"
HelpDialog.Size = UDim2.new(0, 520, 0, 310)
HelpDialog.Position = UDim2.new(0.5, -260, 0.5, -155)
HelpDialog.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
HelpDialog.BackgroundTransparency = 0.08
HelpDialog.BorderSizePixel = 0
HelpDialog.Visible = false
HelpDialog.Active = true
HelpDialog.ZIndex = 20
HelpDialog.Parent = ScreenGui

local HelpCorner = Instance.new("UICorner")
HelpCorner.CornerRadius = UDim.new(0, 8)
HelpCorner.Parent = HelpDialog

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 45)
Title.Position = UDim2.new(0, 0, 0, 10)
Title.BackgroundTransparency = 1
Title.Text = "Keyboard & Mouse Controls"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 22
Title.Font = Enum.Font.SourceSansBold
Title.ZIndex = 21
Title.Parent = HelpDialog

local ButtonsContainer = Instance.new("Frame")
ButtonsContainer.Name = "ButtonsContainer"
ButtonsContainer.Size = UDim2.new(0.9, 0, 0, 32)
ButtonsContainer.Position = UDim2.new(0.05, 0, 0, 60)
ButtonsContainer.BackgroundTransparency = 1
ButtonsContainer.ZIndex = 21
ButtonsContainer.Parent = HelpDialog

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.FillDirection = Enum.FillDirection.Horizontal
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.Parent = ButtonsContainer

local ImageDisplay = Instance.new("ImageLabel")
ImageDisplay.Name = "ControlImage"
ImageDisplay.Size = UDim2.new(0, 380, 0, 160)
ImageDisplay.Position = UDim2.new(0.35, -130, 0, 105)
ImageDisplay.BackgroundTransparency = 1
ImageDisplay.Image = "rbxassetid://45915825"
ImageDisplay.ScaleType = Enum.ScaleType.Fit
ImageDisplay.ZIndex = 22
ImageDisplay.Parent = HelpDialog

local OkBtn = Instance.new("TextButton")
OkBtn.Name = "OkBtn"
OkBtn.Size = UDim2.new(0, 150, 0, 32)
OkBtn.Position = UDim2.new(0.5, -75, 1, -45)
OkBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
OkBtn.BackgroundTransparency = 0.2
OkBtn.BorderSizePixel = 1
OkBtn.BorderColor3 = Color3.fromRGB(220, 0, 0)
OkBtn.Text = "OK"
OkBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
OkBtn.TextSize = 16
OkBtn.Font = Enum.Font.SourceSansBold
OkBtn.ZIndex = 22
OkBtn.Parent = HelpDialog

storeConnection(OkBtn.MouseButton1Click:Connect(function()
	HelpDialog.Visible = false
end))

local categoryTabs = {
	{Order = 1, Name = "LookBtn", Text = "Look", ImageId = "http://www.roblox.com/Asset?id=45915798"},
	{Order = 2, Name = "MoveBtn", Text = "Move", ImageId = "http://www.roblox.com/Asset?id=45915811"},
	{Order = 3, Name = "GearBtn", Text = "Gear", ImageId = "http://www.roblox.com/Asset?id=45917596"},
	{Order = 4, Name = "ZoomBtn", Text = "Zoom", ImageId = "http://www.roblox.com/Asset?id=45915825"}
}

local createdButtons = {}

local function selectTab(selectedBtn, imageId)
	ImageDisplay.Image = imageId
	for _, btn in ipairs(createdButtons) do
		if btn == selectedBtn then
			btn.BorderColor3 = Color3.fromRGB(220, 0, 0)
			btn.BorderSizePixel = 1
		else
			btn.BorderColor3 = Color3.fromRGB(60, 60, 60)
			btn.BorderSizePixel = 1
		end
	end
end

for _, tab in ipairs(categoryTabs) do
	local btn = Instance.new("TextButton")
	btn.Name = tab.Name
	btn.LayoutOrder = tab.Order
	btn.Size = UDim2.new(0.23, 0, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	btn.BackgroundTransparency = 0.3
	btn.BorderSizePixel = 1
	btn.BorderColor3 = Color3.fromRGB(60, 60, 60)
	btn.Text = tab.Text
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 15
	btn.Font = Enum.Font.SourceSans
	btn.ZIndex = 22
	btn.Parent = ButtonsContainer

	table.insert(createdButtons, btn)

	storeConnection(btn.MouseButton1Click:Connect(function()
		selectTab(btn, tab.ImageId)
	end))
end

selectTab(createdButtons[1], categoryTabs[1].ImageId)

--========================================================
-- 2. SETTINGS DIALOG WINDOW
--========================================================
local SettingsDialog = Instance.new("Frame")
SettingsDialog.Name = "SettingsDialog"
SettingsDialog.Size = UDim2.new(0, 520, 0, 270)
SettingsDialog.Position = UDim2.new(0.5, -260, 0.5, -135)
SettingsDialog.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
SettingsDialog.BackgroundTransparency = 0.08
SettingsDialog.BorderSizePixel = 0
SettingsDialog.Visible = false
SettingsDialog.Active = true
SettingsDialog.ZIndex = 30
SettingsDialog.Parent = ScreenGui

local SettingsCorner = Instance.new("UICorner")
SettingsCorner.CornerRadius = UDim.new(0, 8)
SettingsCorner.Parent = SettingsDialog

local SettingsTitle = Instance.new("TextLabel")
SettingsTitle.Size = UDim2.new(1, 0, 0, 45)
SettingsTitle.Position = UDim2.new(0, 0, 0, 10)
SettingsTitle.BackgroundTransparency = 1
SettingsTitle.Text = "Settings"
SettingsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
SettingsTitle.TextSize = 28
SettingsTitle.Font = Enum.Font.SourceSansBold
SettingsTitle.ZIndex = 31
SettingsTitle.Parent = SettingsDialog

local LabelControl = Instance.new("TextLabel")
LabelControl.Size = UDim2.new(0, 260, 0, 30)
LabelControl.Position = UDim2.new(0, 20, 0, 80)
LabelControl.BackgroundTransparency = 1
LabelControl.Text = "Character & Camera Controls (Test):"
LabelControl.TextColor3 = Color3.fromRGB(230, 230, 230)
LabelControl.TextSize = 15
LabelControl.Font = Enum.Font.SourceSans
LabelControl.TextXAlignment = Enum.TextXAlignment.Left
LabelControl.ZIndex = 31
LabelControl.Parent = SettingsDialog

local DropdownButton = Instance.new("TextButton")
DropdownButton.Name = "DropdownButton"
DropdownButton.Size = UDim2.new(0, 180, 0, 30)
DropdownButton.Position = UDim2.new(0, 300, 0, 80)
DropdownButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
DropdownButton.BackgroundTransparency = 0.1
DropdownButton.BorderSizePixel = 1
DropdownButton.BorderColor3 = Color3.fromRGB(80, 80, 80)
DropdownButton.Text = "  Classic"
DropdownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
DropdownButton.TextSize = 15
DropdownButton.Font = Enum.Font.SourceSansBold
DropdownButton.TextXAlignment = Enum.TextXAlignment.Left
DropdownButton.ZIndex = 31
DropdownButton.Parent = SettingsDialog

local DropdownMenu = Instance.new("Frame")
DropdownMenu.Name = "DropdownMenu"
DropdownMenu.Size = UDim2.new(0, 180, 0, 150)
DropdownMenu.Position = UDim2.new(0, 300, 0, 80)
DropdownMenu.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
DropdownMenu.BackgroundTransparency = 0.05
DropdownMenu.BorderSizePixel = 1
DropdownMenu.BorderColor3 = Color3.fromRGB(100, 100, 100)
DropdownMenu.Visible = false
DropdownMenu.ZIndex = 40
DropdownMenu.Parent = SettingsDialog

local DropdownLayout = Instance.new("UIListLayout")
DropdownLayout.SortOrder = Enum.SortOrder.LayoutOrder
DropdownLayout.Parent = DropdownMenu

local ShiftLockNotification = Instance.new("Frame")
ShiftLockNotification.Name = "ShiftLockNotification"
ShiftLockNotification.Size = UDim2.new(0, 180, 0, 28)
ShiftLockNotification.Position = UDim2.new(0, 5, 1, -92)
ShiftLockNotification.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
ShiftLockNotification.BackgroundTransparency = 0.2
ShiftLockNotification.BorderSizePixel = 1
ShiftLockNotification.BorderColor3 = Color3.fromRGB(180, 0, 0)
ShiftLockNotification.Visible = false
ShiftLockNotification.Parent = ScreenGui

local ShiftLockLabel = Instance.new("TextLabel")
ShiftLockLabel.Size = UDim2.new(1, 0, 1, 0)
ShiftLockLabel.BackgroundTransparency = 1
ShiftLockLabel.Font = Enum.Font.SourceSansBold
ShiftLockLabel.Text = "Press Shift to lock mouse"
ShiftLockLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
ShiftLockLabel.TextSize = 13
ShiftLockLabel.Parent = ShiftLockNotification

local options = {"Character Lock", "Drag to Look", "Click to Look", "Mouse Lock Switch", "Classic"}

for i, optionText in ipairs(options) do
	local OptionBtn = Instance.new("TextButton")
	OptionBtn.Name = optionText
	OptionBtn.LayoutOrder = i
	OptionBtn.Size = UDim2.new(1, 0, 0, 30)
	OptionBtn.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
	OptionBtn.BackgroundTransparency = 1
	OptionBtn.BorderSizePixel = 0
	OptionBtn.Text = "  " .. optionText
	OptionBtn.TextColor3 = Color3.fromRGB(230, 230, 230)
	OptionBtn.TextSize = 14
	OptionBtn.Font = (optionText == "Classic") and Enum.Font.SourceSansBold or Enum.Font.SourceSans
	OptionBtn.TextXAlignment = Enum.TextXAlignment.Left
	OptionBtn.ZIndex = 41
	OptionBtn.Parent = DropdownMenu

	storeConnection(OptionBtn.MouseEnter:Connect(function()
		OptionBtn.BackgroundTransparency = 0.2
		OptionBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	end))

	storeConnection(OptionBtn.MouseLeave:Connect(function()
		OptionBtn.BackgroundTransparency = 1
	end))

	storeConnection(OptionBtn.MouseButton1Click:Connect(function()
		DropdownButton.Text = "  " .. optionText
		DropdownMenu.Visible = false
		ShiftLockNotification.Visible = (optionText == "Mouse Lock Switch")
	end))
end

storeConnection(DropdownButton.MouseButton1Click:Connect(function()
	DropdownMenu.Visible = not DropdownMenu.Visible
end))

local SettingsOkBtn = Instance.new("TextButton")
SettingsOkBtn.Name = "SettingsOkBtn"
SettingsOkBtn.Size = UDim2.new(0, 180, 0, 32)
SettingsOkBtn.Position = UDim2.new(0.5, -90, 1, -45)
SettingsOkBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
SettingsOkBtn.BackgroundTransparency = 0.2
SettingsOkBtn.BorderSizePixel = 1
SettingsOkBtn.BorderColor3 = Color3.fromRGB(220, 0, 0)
SettingsOkBtn.Text = "OK"
SettingsOkBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SettingsOkBtn.TextSize = 16
SettingsOkBtn.Font = Enum.Font.SourceSansBold
SettingsOkBtn.ZIndex = 31
SettingsOkBtn.Parent = SettingsDialog

storeConnection(SettingsOkBtn.MouseButton1Click:Connect(function()
	DropdownMenu.Visible = false
	SettingsDialog.Visible = false
end))

--========================================================
-- 3. TOP-RIGHT PLAYER LIST (2010 / EARLY 2011 STYLE)
--========================================================
local PlayerList = Instance.new("Frame")
PlayerList.Name = "ClassicPlayerList"
PlayerList.AnchorPoint = Vector2.new(1, 0)
PlayerList.Size = UDim2.new(0, 200, 0, 140)
PlayerList.Position = UDim2.new(1, -6, 0, 6)
PlayerList.BackgroundColor3 = Color3.fromRGB(160, 160, 160)
PlayerList.BackgroundTransparency = 0.55
PlayerList.BorderSizePixel = 0
PlayerList.Parent = ScreenGui

local ListPadding = Instance.new("UIPadding")
ListPadding.PaddingTop = UDim.new(0, 4)
ListPadding.PaddingLeft = UDim.new(0, 8)
ListPadding.PaddingRight = UDim.new(0, 8)
ListPadding.Parent = PlayerList

local HeaderFrame = Instance.new("Frame")
HeaderFrame.Size = UDim2.new(1, 0, 0, 22)
HeaderFrame.BackgroundTransparency = 1
HeaderFrame.Parent = PlayerList

local ListTitle = Instance.new("TextLabel")
ListTitle.Name = "ListTitle"
ListTitle.BackgroundTransparency = 1
ListTitle.Text = "Player List"
ListTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
ListTitle.TextXAlignment = Enum.TextXAlignment.Left
ListTitle.Font = Enum.Font.ArialBold
ListTitle.TextSize = 16
ListTitle.Parent = HeaderFrame

local StatHeaderContainer = Instance.new("Frame")
StatHeaderContainer.Name = "StatHeaderContainer"
StatHeaderContainer.BackgroundTransparency = 1
StatHeaderContainer.Parent = HeaderFrame

local ListScroll = Instance.new("ScrollingFrame")
ListScroll.Name = "ListScroll"
ListScroll.Size = UDim2.new(1, 0, 1, -26)
ListScroll.Position = UDim2.new(0, 0, 0, 24)
ListScroll.BackgroundTransparency = 1
ListScroll.BorderSizePixel = 0
ListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ListScroll.ScrollBarThickness = 4
ListScroll.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 120)
ListScroll.Parent = PlayerList

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 3)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = ListScroll

storeConnection(ListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	ListScroll.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y)
	local targetHeight = math.clamp(ListLayout.AbsoluteContentSize.Y + 34, 65, 260)
	PlayerList.Size = UDim2.new(0, PlayerList.Size.X.Offset, 0, targetHeight)
end))

local CLASSIC_CHAT_COLORS = {
	Color3.fromRGB(227, 42, 53),
	Color3.fromRGB(33, 147, 226),
	Color3.fromRGB(24, 171, 71),
	Color3.fromRGB(147, 95, 207),
	Color3.fromRGB(216, 121, 46),
	Color3.fromRGB(247, 203, 34),
	Color3.fromRGB(235, 172, 193),
	Color3.fromRGB(199, 178, 142)
}

local function getClassicNameColor(name)
	name = tostring(name or "")
	local count = 0
	for i = 1, #name do
		count = count + string.byte(name, i)
	end
	return CLASSIC_CHAT_COLORS[(count % #CLASSIC_CHAT_COLORS) + 1]
end

local function getPlayerStatObjects(player)
	local stats = {}
	local statsFolder = player:FindFirstChild("leaderstats")
	if statsFolder then
		for _, stat in ipairs(statsFolder:GetChildren()) do
			if stat:IsA("ValueBase") then
				table.insert(stats, stat)
			end
		end
	end
	return stats
end

local function getActiveStatNames()
	local names = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local statsFolder = p:FindFirstChild("leaderstats")
		if statsFolder then
			for _, stat in ipairs(statsFolder:GetChildren()) do
				if stat:IsA("ValueBase") and not table.find(names, stat.Name) then
					table.insert(names, stat.Name)
				end
			end
		end
	end
	return names
end

local function resizeLeaderboardLayout(statCount)
	local baseWidth = 185
	local statColumnWidth = 75
	local calculatedTotalWidth = baseWidth + statCount * statColumnWidth
	PlayerList.Size = UDim2.new(0, calculatedTotalWidth, 0, PlayerList.Size.Y.Offset)
	local nameRatio = baseWidth / calculatedTotalWidth
	local statsRatio = 1 - nameRatio
	ListTitle.Size = UDim2.new(nameRatio, 0, 1, 0)
	StatHeaderContainer.Size = UDim2.new(statsRatio, 0, 1, 0)
	StatHeaderContainer.Position = UDim2.new(nameRatio, 0, 0, 0)
	return nameRatio, statsRatio
end

local function updateHeaderTitles()
	local activeStats = getActiveStatNames()
	local statCount = #activeStats
	resizeLeaderboardLayout(statCount)
	local existingHeaders = StatHeaderContainer:GetChildren()
	if #existingHeaders ~= statCount then
		for _, child in ipairs(existingHeaders) do
			child:Destroy()
		end
		if statCount == 0 then
			return
		end
		local columnWidth = 1 / statCount
		for i, statName in ipairs(activeStats) do
			local label = Instance.new("TextLabel")
			label.Name = statName
			label.Size = UDim2.new(columnWidth, 0, 1, 0)
			label.Position = UDim2.new((i - 1) * columnWidth, 0, 0, 0)
			label.BackgroundTransparency = 1
			label.Text = statName
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.Font = Enum.Font.ArialBold
			label.TextSize = 14
			label.Parent = StatHeaderContainer
		end
	end
end

local function createOrUpdateRow(rowKey, labelText, statValuesList, textColor, isHeader, paddingSpaces, layoutOrder)
	local rowFrame = ListScroll:FindFirstChild(rowKey)
	local activeStats = getActiveStatNames()
	local statCount = #activeStats
	local baseWidth = 185
	local statColumnWidth = 75
	local totalWidth = baseWidth + statCount * statColumnWidth
	local nameRatio = baseWidth / totalWidth
	local statsRatio = 1 - nameRatio
	local columnWidth = statCount > 0 and (1 / statCount) or 1

	if not rowFrame then
		rowFrame = Instance.new("Frame")
		rowFrame.Name = rowKey
		rowFrame.Size = UDim2.new(1, -5, 0, 18)
		rowFrame.BackgroundTransparency = 1

		local leftLabel = Instance.new("TextLabel")
		leftLabel.Name = "LeftLabel"
		leftLabel.BackgroundTransparency = 1
		leftLabel.Font = Enum.Font.ArialBold
		leftLabel.TextXAlignment = Enum.TextXAlignment.Left
		leftLabel.Parent = rowFrame

		local statContainer = Instance.new("Frame")
		statContainer.Name = "StatContainer"
		statContainer.BackgroundTransparency = 1
		statContainer.Parent = rowFrame

		local underline = Instance.new("Frame")
		underline.Name = "Underline"
		underline.Size = UDim2.new(1, 0, 0, 1)
		underline.Position = UDim2.new(0, 0, 1, -1)
		underline.BorderSizePixel = 0
		underline.Parent = rowFrame

		rowFrame.Parent = ListScroll
	end

	rowFrame.LayoutOrder = layoutOrder
	local leftLabel = rowFrame.LeftLabel
	leftLabel.Size = UDim2.new(nameRatio, 0, 1, 0)
	leftLabel.Text = (paddingSpaces or "") .. labelText
	leftLabel.TextSize = isHeader and 12 or 14
	leftLabel.TextColor3 = textColor

	local statContainer = rowFrame.StatContainer
	statContainer.Size = UDim2.new(statsRatio, 0, 1, 0)
	statContainer.Position = UDim2.new(nameRatio, 0, 0, 0)

	local underline = rowFrame.Underline
	underline.Visible = isHeader
	if isHeader then
		underline.BackgroundColor3 = textColor
	end

	for i, statName in ipairs(activeStats) do
		local statLabel = statContainer:FindFirstChild(statName)
		if not statLabel then
			statLabel = Instance.new("TextLabel")
			statLabel.Name = statName
			statLabel.BackgroundTransparency = 1
			statLabel.Font = Enum.Font.ArialBold
			statLabel.TextXAlignment = Enum.TextXAlignment.Center
			statLabel.Parent = statContainer
		end
		statLabel.Size = UDim2.new(columnWidth, 0, 1, 0)
		statLabel.Position = UDim2.new((i - 1) * columnWidth, 0, 0, 0)
		statLabel.TextSize = isHeader and 14 or 15
		statLabel.TextColor3 = textColor
		local valueText = ""
		if statValuesList and statValuesList[statName] then
			valueText = tostring(statValuesList[statName])
		end
		statLabel.Text = valueText
	end

	for _, child in ipairs(statContainer:GetChildren()) do
		if not table.find(activeStats, child.Name) then
			child:Destroy()
		end
	end
end

local function updatePlayerList()
	updateHeaderTitles()
	local currentTeams = Teams:GetTeams()
	local playersMapped = {}
	local activeStats = getActiveStatNames()
	local orderIndex = 1
	local activeKeys = {}

	if #currentTeams > 0 then
		for _, team in ipairs(currentTeams) do
			local teamPlayers = team:GetPlayers()
			if #teamPlayers > 0 then
				local teamScores = {}
				for _, statName in ipairs(activeStats) do
					teamScores[statName] = 0
				end
				for _, p in ipairs(teamPlayers) do
					local pStats = getPlayerStatObjects(p)
					for _, stat in ipairs(pStats) do
						if (stat:IsA("IntValue") or stat:IsA("NumberValue")) and teamScores[stat.Name] then
							teamScores[stat.Name] = teamScores[stat.Name] + stat.Value
						end
					end
				end
				local teamKey = "Team_" .. team.Name
				table.insert(activeKeys, teamKey)
				createOrUpdateRow(teamKey, team.Name, teamScores, team.TeamColor.Color, true, "", orderIndex)
				orderIndex = orderIndex + 1

				for _, p in ipairs(teamPlayers) do
					playersMapped[p] = true
					local pStats = getPlayerStatObjects(p)
					local playerStatMap = {}
					for _, stat in ipairs(pStats) do
						playerStatMap[stat.Name] = stat.Value
					end
					local playerKey = "Player_" .. p.Name
					table.insert(activeKeys, playerKey)
					createOrUpdateRow(playerKey, p.Name, playerStatMap, team.TeamColor.Color, false, "   ", orderIndex)
					orderIndex = orderIndex + 1
				end
			end
		end
	end

	local neutralHeaderCreated = false
	for _, p in ipairs(Players:GetPlayers()) do
		if not playersMapped[p] then
			if #currentTeams > 0 and not neutralHeaderCreated then
				neutralHeaderCreated = true
				local neutralKey = "Team_Neutral"
				table.insert(activeKeys, neutralKey)
				createOrUpdateRow(neutralKey, "Neutral", {}, Color3.fromRGB(230, 230, 230), true, "", orderIndex)
				orderIndex = orderIndex + 1
			end
			local rowColor = getClassicNameColor(p.Name)
			local padding = neutralHeaderCreated and "   " or ""
			local pStats = getPlayerStatObjects(p)
			local playerStatMap = {}
			for _, stat in ipairs(pStats) do
				playerStatMap[stat.Name] = stat.Value
			end
			local playerKey = "Player_" .. p.Name
			table.insert(activeKeys, playerKey)
			createOrUpdateRow(playerKey, p.Name, playerStatMap, rowColor, false, padding, orderIndex)
			orderIndex = orderIndex + 1
		end
	end

	for _, child in ipairs(ListScroll:GetChildren()) do
		if (child:IsA("Frame") or child:IsA("TextLabel")) and not table.find(activeKeys, child.Name) then
			child:Destroy()
		end
	end
end

local lastUpdate = 0
local updatePending = false
local function requestListUpdate()
	if updatePending then
		return
	end
	local now = os.clock()
	if now - lastUpdate >= 1.0 then
		lastUpdate = now
		updatePlayerList()
	else
		updatePending = true
		task.delay(1.0 - (now - lastUpdate), function()
			updatePending = false
			lastUpdate = os.clock()
			updatePlayerList()
		end)
	end
end

local function connectPlayerStats(p)
	local function hookLeaderstats(folder)
		if folder.Name ~= "leaderstats" then
			return
		end
		requestListUpdate()
		local function listenToStat(val)
			if not val:IsA("ValueBase") then
				return
			end
			storeConnection(val.Changed:Connect(function(newValue)
				local playerKey = "Player_" .. p.Name
				local rowFrame = ListScroll:FindFirstChild(playerKey)
				if rowFrame then
					local statContainer = rowFrame:FindFirstChild("StatContainer")
					local statLabel = statContainer and statContainer:FindFirstChild(val.Name)
					if statLabel then
						statLabel.Text = tostring(newValue)
					end
				end
			end))
		end
		storeConnection(folder.ChildAdded:Connect(function(val)
			listenToStat(val)
			requestListUpdate()
		end))
		for _, val in ipairs(folder:GetChildren()) do
			listenToStat(val)
		end
	end
	storeConnection(p.ChildAdded:Connect(hookLeaderstats))
	local existingStats = p:FindFirstChild("leaderstats")
	if existingStats then
		hookLeaderstats(existingStats)
	end
	storeConnection(p:GetPropertyChangedSignal("Team"):Connect(requestListUpdate))
end

storeConnection(Players.PlayerAdded:Connect(function(p)
	connectPlayerStats(p)
	requestListUpdate()
end))
storeConnection(Players.PlayerRemoving:Connect(requestListUpdate))
storeConnection(Teams.ChildAdded:Connect(requestListUpdate))
storeConnection(Teams.ChildRemoved:Connect(requestListUpdate))

for _, p in ipairs(Players:GetPlayers()) do
	connectPlayerStats(p)
end
updatePlayerList()

--========================================================
-- 4. TOP-LEFT CHAT LOG (NO EXTRA SPACE, TIGHT AUTO-WIDTH)
--========================================================
local ChatContainer = Instance.new("Frame")
ChatContainer.Name = "ClassicChatLog"
ChatContainer.Size = UDim2.new(0.4, 0, 0.25, 0)
ChatContainer.Position = UDim2.new(0, 5, 0, 8)
ChatContainer.BackgroundTransparency = 1
ChatContainer.Parent = ScreenGui

local ChatLayout = Instance.new("UIListLayout")
ChatLayout.SortOrder = Enum.SortOrder.LayoutOrder
ChatLayout.Padding = UDim.new(0, -2)
ChatLayout.Parent = ChatContainer



--========================================================
-- 5. BOTTOM CHAT INPUT BAR (BLACK BACKGROUND & WHITE TEXT)
--========================================================
local BottomChatBar = Instance.new("Frame")
BottomChatBar.Name = "ClassicBottomChatBar"
BottomChatBar.AnchorPoint = Vector2.new(0, 1)
BottomChatBar.Size = UDim2.new(1, 0, 0, 20)
BottomChatBar.Position = UDim2.new(0, 0, 1, 0)
BottomChatBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
BottomChatBar.BackgroundTransparency = 0.25
BottomChatBar.BorderColor3 = Color3.fromRGB(0, 0, 0)
BottomChatBar.BorderSizePixel = 0
BottomChatBar.Active = true
BottomChatBar.ZIndex = 12
BottomChatBar.Parent = ScreenGui

local ChatPromptLabel = Instance.new("TextLabel")
ChatPromptLabel.Name = "ChatPromptLabel"
ChatPromptLabel.Size = UDim2.new(1, -10, 1, 0)
ChatPromptLabel.Position = UDim2.new(0, 5, 0, 0)
ChatPromptLabel.BackgroundTransparency = 1
ChatPromptLabel.Font = Enum.Font.Arial
ChatPromptLabel.TextSize = 13
ChatPromptLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
ChatPromptLabel.TextXAlignment = Enum.TextXAlignment.Left
ChatPromptLabel.TextYAlignment = Enum.TextYAlignment.Center
ChatPromptLabel.Text = 'To chat click here or press the "/" key'
ChatPromptLabel.ZIndex = 13
ChatPromptLabel.Parent = BottomChatBar

local HiddenTextBox = Instance.new("TextBox")
HiddenTextBox.Name = "HiddenTextBox"
HiddenTextBox.Size = UDim2.new(1, -10, 1, 0)
HiddenTextBox.Position = UDim2.new(0, 5, 0, 0)
HiddenTextBox.BackgroundTransparency = 1
HiddenTextBox.Text = ""
HiddenTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
HiddenTextBox.TextTransparency = 0
HiddenTextBox.Font = Enum.Font.Arial
HiddenTextBox.TextSize = 13
HiddenTextBox.TextXAlignment = Enum.TextXAlignment.Left
HiddenTextBox.TextYAlignment = Enum.TextYAlignment.Center
HiddenTextBox.ClearTextOnFocus = false
HiddenTextBox.MultiLine = false
HiddenTextBox.Active = true
HiddenTextBox.Selectable = true
HiddenTextBox.ZIndex = 14
HiddenTextBox.Parent = BottomChatBar

local msgLayoutOrder = 0

local function addClassicMessage(senderName, messageText)
	senderName = tostring(senderName or "")
	messageText = tostring(messageText or "")
	if senderName == "" or messageText == "" then
		return
	end

	local messageFrames = {}
	for _, child in ipairs(ChatContainer:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(messageFrames, child)
		end
	end
	if #messageFrames >= 10 then
		messageFrames[1]:Destroy()
	end

	msgLayoutOrder += 1
	local nameColor = getClassicNameColor(senderName)
	local colorHex = string.format(
		"#%02X%02X%02X",
		math.floor(nameColor.R * 255),
		math.floor(nameColor.G * 255),
		math.floor(nameColor.B * 255)
	)

	local MsgFrame = Instance.new("Frame")
	MsgFrame.Name = "ChatMessage"
	MsgFrame.LayoutOrder = msgLayoutOrder
	MsgFrame.BackgroundColor3 = Color3.fromRGB(154, 154, 154)
	MsgFrame.BackgroundTransparency = 0.45
	MsgFrame.BorderSizePixel = 0
	MsgFrame.AutomaticSize = Enum.AutomaticSize.X
	MsgFrame.Size = UDim2.new(0, 0, 0, 21)
	MsgFrame.Parent = ChatContainer

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 5)
	padding.PaddingRight = UDim.new(0, 5)
	padding.Parent = MsgFrame

	local TextLabel = Instance.new("TextLabel")
	TextLabel.Name = "MessageText"
	TextLabel.BackgroundTransparency = 1
	TextLabel.Font = Enum.Font.Arial
	TextLabel.TextSize = 14
	TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	TextLabel.TextXAlignment = Enum.TextXAlignment.Left
	TextLabel.TextYAlignment = Enum.TextYAlignment.Center
	TextLabel.RichText = true
	TextLabel.AutomaticSize = Enum.AutomaticSize.X
	TextLabel.Size = UDim2.new(0, 0, 1, 0)

	local safeName = senderName:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	local safeMessage = messageText:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")

	TextLabel.Text = string.format(
		'<font color="%s">%s</font>: %s',
		colorHex,
		safeName,
		safeMessage
	)
	TextLabel.Parent = MsgFrame

end

-- (Addtion-Scripts) The chat log gets every message by itself (the same message from both chat events
-- shown once). It was only filled by the chat bubbles' part, which the loader's 2011-style bubbles
-- switch off when they start.
do
	local recent = {}
	local function logMessage(player, text)
		if not player or typeof(text) ~= "string" then return end
		text = text:gsub("^%s+", ""):gsub("%s+$", "")
		if text == "" then return end
		local key = tostring(player.UserId) .. ":" .. text
		if recent[key] then return end
		recent[key] = true
		task.delay(0.5, function() recent[key] = nil end)
		addClassicMessage(player.Name, text)
	end
	local function hookChatted(player)
		storeConnection(player.Chatted:Connect(function(text) logMessage(player, text) end))
	end
	for _, player in ipairs(Players:GetPlayers()) do hookChatted(player) end
	storeConnection(Players.PlayerAdded:Connect(hookChatted))
	pcall(function()
		storeConnection(TextChatService.MessageReceived:Connect(function(message)
			if not message or not message.TextSource then return end
			logMessage(Players:GetPlayerByUserId(message.TextSource.UserId), message.Text)
		end))
	end)
end

--========================================================
-- 6. EARLY 2011 BOTTOM CONTROL BAR (LEFT & RIGHT TRAYS)
--========================================================
local function apply2011TextureLeft(imageLabel)
	imageLabel.Image = "rbxassetid://132161153221969"
	imageLabel.ImageColor3 = Color3.fromRGB(255, 255, 255)
	imageLabel.ImageRectOffset = Vector2.new(0, 340)
	imageLabel.ImageRectSize = Vector2.new(768, 360)
	imageLabel.ImageTransparency = 0.22
	imageLabel.ScaleType = Enum.ScaleType.Stretch
	imageLabel.BackgroundTransparency = 1
end

local function apply2011TextureRight(imageLabel)
	imageLabel.Image = "rbxassetid://132161153221969"
	imageLabel.ImageColor3 = Color3.fromRGB(255, 255, 255)
	imageLabel.ImageRectOffset = Vector2.new(768, 340)
	imageLabel.ImageRectSize = Vector2.new(-768, 360)
	imageLabel.ImageTransparency = 0.22
	imageLabel.ScaleType = Enum.ScaleType.Stretch
	imageLabel.BackgroundTransparency = 1
	task.spawn(function()
		local rightTex = get2011Texture("ui/BottomRightControl.png", nil)
		if rightTex and not rightTex:find("rbxasset://textures/", 1, true) then
			imageLabel.ImageRectOffset = Vector2.new(0, 0)
			imageLabel.ImageRectSize = Vector2.new(0, 0)
			imageLabel.Image = rightTex
			imageLabel.ImageTransparency = 0
		end
	end)
end

local BottomControlFrame = Instance.new("Frame")
BottomControlFrame.Name = "BottomControlFrame"
BottomControlFrame.AnchorPoint = Vector2.new(0, 1)
BottomControlFrame.Size = UDim2.new(1, 0, 0, 42)
BottomControlFrame.Position = UDim2.new(0, 0, 1, -20)
BottomControlFrame.BackgroundTransparency = 1
BottomControlFrame.Visible = true
BottomControlFrame.Active = false
BottomControlFrame.ZIndex = 5
BottomControlFrame.Parent = ScreenGui

-- Left Control Tray (Original from first script)
local ControlBG = Instance.new("ImageLabel")
ControlBG.Name = "ImageLabel"
ControlBG.Size = UDim2.new(0, 260, 1, 0)
ControlBG.Position = UDim2.new(0, 0, 0, 0)
ControlBG.BackgroundColor3 = Color3.fromRGB(163, 162, 165)
ControlBG.Visible = true
ControlBG.Active = true
ControlBG.ZIndex = 5
apply2011TextureLeft(ControlBG)
ControlBG.Parent = BottomControlFrame

local ButtonContainer = Instance.new("Frame")
ButtonContainer.Name = "ButtonContainer"
ButtonContainer.Size = UDim2.new(1, 0, 1, 0)
ButtonContainer.BackgroundTransparency = 1
ButtonContainer.ZIndex = 6
ButtonContainer.Parent = ControlBG

local UIListLayoutBar = Instance.new("UIListLayout")
UIListLayoutBar.FillDirection = Enum.FillDirection.Horizontal
UIListLayoutBar.HorizontalAlignment = Enum.HorizontalAlignment.Left
UIListLayoutBar.VerticalAlignment = Enum.VerticalAlignment.Center
UIListLayoutBar.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayoutBar.Padding = UDim.new(0, 6)
UIListLayoutBar.Parent = ButtonContainer

local UIPaddingBar = Instance.new("UIPadding")
UIPaddingBar.PaddingLeft = UDim.new(0, 8)
UIPaddingBar.Parent = ButtonContainer

-- (Addtion-Scripts) The buttons as in the 2011 client: its own pictures (normal / under the mouse / pressed) at
-- their own sizes (80% of them, to fit the bar): Leave, the list (the menu), the tool cursor (mouse lock; on
-- a phone shift lock), the gear (settings).
local BAR_SCALE = 0.8
local function nativeSize(w, h)
	return UDim2.new(0, math.floor(w * BAR_SCALE + 0.5), 0, math.floor(h * BAR_SCALE + 0.5))
end
local function make2011Button(name, order, size, parent, normal, ovr, dn, fallback)
	local btn = Instance.new("ImageButton")
	btn.Name = name
	btn.LayoutOrder = order
	btn.Size = size
	btn.BackgroundTransparency = 1
	btn.BorderSizePixel = 0
	btn.ScaleType = Enum.ScaleType.Fit -- (the picture keeps its shape: never stretched)
	btn.ZIndex = 7
	btn.Parent = parent
	bind2011ButtonStates(btn, btn, normal, ovr, dn, fallback)
	return btn
end

local LeaveBtn = make2011Button("LeaveBtn", 1, nativeSize(75, 39), ButtonContainer,
	"Exit.png", "Exit_ovr.png", "Exit_dn.png", "rbxassetid://90232828981032")
local ListBtn = make2011Button("ExpandBtn", 2, nativeSize(39, 39), ButtonContainer,
	"TogglePlayMode.png", "TogglePlayMode_ovr.png", "TogglePlayMode_dn.png", "rbxassetid://106850260964317")
local MouseLockBtn = make2011Button("MouseLockBtn", 3, nativeSize(39, 39), ButtonContainer,
	"ui/ToolButton.png", "ui/ToolButton_dn.png", "ui/ToolButton_dn.png", "rbxasset://textures/ArrowCursor.png")
local SettingsBtn = make2011Button("SettingsBtn", 4, nativeSize(39, 39), ButtonContainer,
	"ui/SettingsButton.png", "ui/SettingsButton_ovr.png", "ui/SettingsButton_dn.png", "rbxassetid://14306059173")

storeConnection(LeaveBtn.MouseButton1Click:Connect(function()
	pcall(function()
		game:Shutdown()
	end)
end))
storeConnection(SettingsBtn.MouseButton1Click:Connect(function()
	SettingsDialog.Visible = not SettingsDialog.Visible
end))
storeConnection(ListBtn.MouseButton1Click:Connect(function()
	HelpDialog.Visible = not HelpDialog.Visible
end))

-- mouse lock: the character turns with the camera and the camera sits over the right shoulder (on a phone,
-- shift lock); on a PC the mouse is held in the middle too. While it's on, the button keeps a red edge (as
-- the 2011 buttons have under the mouse).
do
	local locked = false
	local BIND = "Early2011MouseLock"
	local onEdge = Instance.new("UIStroke")
	onEdge.Color = Color3.fromRGB(220, 0, 0)
	onEdge.Thickness = 2
	onEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	onEdge.Enabled = false
	onEdge.Parent = MouseLockBtn
	local function setLocked(on)
		locked = on
		onEdge.Enabled = on
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		pcall(function() RunService:UnbindFromRenderStep(BIND) end)
		if on then
			RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function()
				local char = LocalPlayer.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local cam = Workspace.CurrentCamera
				if not (hum and root and cam) or hum.Health <= 0 or hum.Sit then return end
				hum.AutoRotate = false
				hum.CameraOffset = Vector3.new(1.75, 0, 0)
				local look = cam.CFrame.LookVector
				local flat = Vector3.new(look.X, 0, look.Z)
				if flat.Magnitude > 0.01 then
					root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
				end
				if UserInputService.MouseEnabled then
					UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
				end
			end)
		else
			if humanoid then
				humanoid.AutoRotate = true
				humanoid.CameraOffset = Vector3.new(0, 0, 0)
			end
			if UserInputService.MouseEnabled then
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
		end
	end
	storeConnection(MouseLockBtn.MouseButton1Click:Connect(function() setLocked(not locked) end))
	storeConnection(LocalPlayer.CharacterAdded:Connect(function()
		if locked then setLocked(false) end
	end))
end

--========================================================
-- 7. BOTTOM-RIGHT CONTROL TRAY (AUTHENTIC OCT 25, 2011 ARCHIVE TEXTURES)
-- Uses exact files from /content/textures/ and /content/textures/ui/:
--   * RecordToggle.png / RecordToggle_ovr.png / RecordToggle_sel.png
--   * Screenshot.png / Screenshot_ovr.png / Screenshot_dn.png
--   * CameraTiltUp_ds.png / CameraTiltUp_ovr.png / CameraTiltUp_dn.png
--   * CameraTiltDown_ds.png / CameraTiltDown_ovr.png / CameraTiltDown_dn.png
--   * CameraZoomIn.png / CameraZoomIn_ovr.png / CameraZoomIn_dn.png
--   * CameraZoomOut_ds.png / CameraZoomOut_ovr.png / CameraZoomOut_dn.png
--   * ReportAbuse_ds.PNG / ReportAbuse_ovr.PNG / ReportAbuse_dn.PNG
--   * ToggleFullScreen.png / ToggleFullScreen_ovr.png / ToggleFullScreen_dn.png
--========================================================
local RightControlBG = Instance.new("ImageLabel")
RightControlBG.Name = "RightControlBG"
RightControlBG.AnchorPoint = Vector2.new(1, 0)
-- (Addtion-Scripts) as narrow as the 2011 tray (only REPORT and full screen are on it), with a little room
-- after the full screen button
RightControlBG.Size = UDim2.new(0, 112, 1, 0)
RightControlBG.Position = UDim2.new(1, 0, 0, 0)
RightControlBG.Visible = true
RightControlBG.Active = true
RightControlBG.ZIndex = 5
apply2011TextureRight(RightControlBG)
RightControlBG.Parent = BottomControlFrame

local RightButtonContainer = Instance.new("Frame")
RightButtonContainer.Name = "RightButtonContainer"
RightButtonContainer.Size = UDim2.new(1, 0, 1, 0)
RightButtonContainer.BackgroundTransparency = 1
RightButtonContainer.ZIndex = 6
RightButtonContainer.Parent = RightControlBG

local RightLayout = Instance.new("UIListLayout")
RightLayout.FillDirection = Enum.FillDirection.Horizontal
RightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
RightLayout.VerticalAlignment = Enum.VerticalAlignment.Center
RightLayout.SortOrder = Enum.SortOrder.LayoutOrder
RightLayout.Padding = UDim.new(0, 6)
RightLayout.Parent = RightButtonContainer

local RightPadding = Instance.new("UIPadding")
RightPadding.PaddingRight = UDim.new(0, 10)
RightPadding.Parent = RightButtonContainer

-- (Addtion-Scripts) On a phone the GUI stops at the screen's safe area (its camera hole): the tray runs on to the
-- screen's real edge, so the full screen button isn't at the very end of it.
do
	local trayEdge = Instance.new("Frame")
	trayEdge.Name = "RightControlEdge"
	trayEdge.BackgroundColor3 = Color3.new(0, 0, 0)
	trayEdge.BackgroundTransparency = 1 - 179 / 255 -- (the tray picture's own darkness)
	trayEdge.BorderSizePixel = 0
	trayEdge.Position = UDim2.new(1, 0, 0, 0)
	trayEdge.Size = UDim2.new(0, 0, 1, 0)
	trayEdge.Visible = false
	trayEdge.ZIndex = RightControlBG.ZIndex
	trayEdge.Parent = RightControlBG
	local function fitTrayEdge()
		local camera = Workspace.CurrentCamera
		if not camera then return end
		local right = ScreenGui.AbsolutePosition.X + ScreenGui.AbsoluteSize.X
		local inset = camera.ViewportSize.X - right
		if inset < 1 then trayEdge.Visible = false return end
		local scaler = ScreenGui:FindFirstChild("AutoUIScale")
		local scale = (scaler and scaler.Scale > 0) and scaler.Scale or 1
		pcall(function() ScreenGui.ClipToDeviceSafeArea = false end)
		trayEdge.Size = UDim2.new(0, math.ceil(inset / scale) + 1, 1, 0)
		trayEdge.Visible = true
	end
	task.defer(fitTrayEdge)
	storeConnection(ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitTrayEdge))
	storeConnection(ScreenGui:GetPropertyChangedSignal("AbsolutePosition"):Connect(fitTrayEdge))
end

-- 1) The "Record" bar, the screenshot circle and the camera buttons
-- (Addtion-Scripts) As in the 2011 client: they stand just left of the right tray, not on it; the tray has
-- "! REPORT" and full screen. "Record" is the May 2011 client's bar (a film camera and "Record", 65 x 30), and
-- while recording its red "Stop" bar (the same size: nothing is stretched); the screenshot button is the
-- camera in a circle.
local CameraControls = Instance.new("Frame")
CameraControls.Name = "CameraControls"
CameraControls.AnchorPoint = Vector2.new(1, 0)
CameraControls.Position = UDim2.new(1, -114, 0, 0) -- (just left of the 112 wide tray)
CameraControls.Size = UDim2.new(0, 150, 1, 0)
CameraControls.BackgroundTransparency = 1
CameraControls.ZIndex = 6
CameraControls.Parent = BottomControlFrame
do
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	-- (Addtion-Scripts) as in the 2011 client: close together, "Record" and the screenshot circle in the
	-- middle of the bar like REPORT, and the camera circles' bottom row beside them (their top row above the
	-- bar)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = CameraControls
	local padding = Instance.new("UIPadding")
	padding.PaddingBottom = UDim.new(0, 9) -- ((42 - 24) / 2: "Record" in the middle of the 42 high bar)
	padding.Parent = CameraControls
end

-- "Record": its own two pictures only ("Record", and "Stop" while recording), no others swapped in
local RecordBtn = Instance.new("ImageButton")
RecordBtn.Name = "RecordToggle"
RecordBtn.LayoutOrder = 1
RecordBtn.Size = nativeSize(65, 30)
RecordBtn.BackgroundTransparency = 1
RecordBtn.BorderSizePixel = 0
RecordBtn.ScaleType = Enum.ScaleType.Fit
RecordBtn.AutoButtonColor = false
RecordBtn.ZIndex = 7
RecordBtn.Image = "rbxassetid://23847250"
RecordBtn.Parent = CameraControls
do
	local recording = false
	local recordTex, stopTex = nil, nil
	local function show()
		local tex = (recording and stopTex) or recordTex
		if tex and RecordBtn.Image ~= tex then RecordBtn.Image = tex end
	end
	task.spawn(function()
		recordTex = get2011Texture("may:RecordToggle.png", "rbxassetid://23847250")
		stopTex = get2011Texture("may:RecordToggle_dn.png", recordTex)
		show()
	end)
	storeConnection(RecordBtn.MouseButton1Click:Connect(function()
		recording = not recording
		show()
	end))
end

-- the screenshot circle (pressed: the circle filled in)
local ScreenshotBtn = make2011Button("Screenshot", 2, nativeSize(31, 31), CameraControls,
	"may:Screenshot.png", "oct:Screenshot_ovr.png", "oct:Screenshot_dn.png", "rbxassetid://4456953824")
ScreenshotBtn.ScaleType = Enum.ScaleType.Fit

local CameraPanel = Instance.new("Frame")
CameraPanel.Name = "CameraPanel"
CameraPanel.LayoutOrder = 3
local CAMERA_BUTTON = 21
local CAMERA_GAP = 1 -- (the circles all but touch, as in the 2011 client)
CameraPanel.Size = UDim2.new(0, CAMERA_BUTTON * 2 + CAMERA_GAP, 0, CAMERA_BUTTON * 2 + CAMERA_GAP)
CameraPanel.BackgroundTransparency = 1
CameraPanel.ZIndex = 7
CameraPanel.Parent = CameraControls

local function cameraButton(name, x, y, normal, ovr, dn, fallback, rotation)
	local btn = Instance.new("ImageButton")
	btn.Name = name
	btn.Position = UDim2.new(0, x * (CAMERA_BUTTON + CAMERA_GAP), 0, y * (CAMERA_BUTTON + CAMERA_GAP))
	btn.Size = UDim2.new(0, CAMERA_BUTTON, 0, CAMERA_BUTTON)
	btn.BackgroundTransparency = 1
	btn.ScaleType = Enum.ScaleType.Fit
	btn.ZIndex = 8
	btn.Parent = CameraPanel
	bind2011ButtonStates(btn, btn, normal, ovr, dn, fallback, rotation)
	return btn
end
local TiltUp = cameraButton("CameraTiltUp", 0, 0, "CameraTiltUp.png", "CameraTiltUp_ovr.png", "CameraTiltUp_dn.png", "rbxassetid://598662248", 0)
local TiltDown = cameraButton("CameraTiltDown", 0, 1, "CameraTiltDown.png", "CameraTiltDown_ovr.png", "CameraTiltDown_dn.png", "rbxassetid://598662248", 180)
local ZoomIn = cameraButton("CameraZoomIn", 1, 0, "CameraZoomIn.png", "CameraZoomIn_ovr.png", "CameraZoomIn_dn.png", "rbxassetid://1074548141", 0)
local ZoomOut = cameraButton("CameraZoomOut", 1, 1, "CameraZoomOut.png", "CameraZoomOut_ovr.png", "CameraZoomOut_dn.png", "rbxassetid://598665130", 0)

-- on the tray: "! REPORT" and full screen
local ReportAbuseBtn = make2011Button("ReportAbuse", 4, nativeSize(39, 39), RightButtonContainer,
	"ReportAbuse.PNG", "ReportAbuse_ovr.PNG", "ReportAbuse_dn.PNG", "rbxassetid://4539289774")
ReportAbuseBtn.ScaleType = Enum.ScaleType.Fit
local FullscreenBtn = make2011Button("ToggleFullScreen", 5, nativeSize(39, 39), RightButtonContainer,
	"ToggleFullScreen.png", "ToggleFullScreen_ovr.png", "ToggleFullScreen_dn.png", "rbxassetid://106850260964317")
FullscreenBtn.ScaleType = Enum.ScaleType.Fit

-- Authentic 2011 Camera Zoom & Tilt Functions
local ZOOM_FACTOR = 0.75
local TILT_ANGLE = math.rad(5)

storeConnection(ZoomIn.MouseButton1Click:Connect(function()
	Camera = Workspace.CurrentCamera
	if LocalPlayer and Camera then
		local currentZoom = (Camera.CFrame.Position - Camera.Focus.Position).Magnitude
		local newDist = math.max(0.5, currentZoom * ZOOM_FACTOR)
		LocalPlayer.CameraMinZoomDistance = newDist
		LocalPlayer.CameraMaxZoomDistance = newDist
		task.wait()
		LocalPlayer.CameraMinZoomDistance = 0.5
		LocalPlayer.CameraMaxZoomDistance = 400
	end
end))

storeConnection(ZoomOut.MouseButton1Click:Connect(function()
	Camera = Workspace.CurrentCamera
	if LocalPlayer and Camera then
		local currentZoom = (Camera.CFrame.Position - Camera.Focus.Position).Magnitude
		local newDist = math.min(400, math.max(2, currentZoom) / ZOOM_FACTOR)
		LocalPlayer.CameraMinZoomDistance = newDist
		LocalPlayer.CameraMaxZoomDistance = newDist
		task.wait()
		LocalPlayer.CameraMinZoomDistance = 0.5
		LocalPlayer.CameraMaxZoomDistance = 400
	end
end))

storeConnection(TiltUp.MouseButton1Click:Connect(function()
	Camera = Workspace.CurrentCamera
	if Camera then
		local focus = Camera.Focus
		local cframe = Camera.CFrame
		Camera.CFrame = CFrame.new(focus.Position) * CFrame.Angles(-TILT_ANGLE, 0, 0) * (CFrame.new(-focus.Position) * cframe)
	end
end))

storeConnection(TiltDown.MouseButton1Click:Connect(function()
	Camera = Workspace.CurrentCamera
	if Camera then
		local focus = Camera.Focus
		local cframe = Camera.CFrame
		Camera.CFrame = CFrame.new(focus.Position) * CFrame.Angles(TILT_ANGLE, 0, 0) * (CFrame.new(-focus.Position) * cframe)
	end
end))

storeConnection(ScreenshotBtn.MouseButton1Click:Connect(function()
	pcall(function()
		GuiService:TakeScreenshot()
	end)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "Classic Roblox",
			Text = "Screenshot saved!",
			Duration = 2
		})
	end)
end))

storeConnection(RecordBtn.MouseButton1Click:Connect(function()
	pcall(function()
		GuiService:ToggleRecording()
	end)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "Classic Roblox",
			Text = "Video recording toggled!",
			Duration = 2
		})
	end)
end))

storeConnection(ReportAbuseBtn.MouseButton1Click:Connect(function()
	pcall(function()
		GuiService:OpenBrowserWindow("https://www.roblox.com/report-abuse")
	end)
end))

storeConnection(FullscreenBtn.MouseButton1Click:Connect(function()
	pcall(function()
		GuiService:ToggleFullscreen()
	end)
end))

--========================================================
-- 8. OLD HEALTH BAR (2011-2013: BPOldHealthBar, RAISED ABOVE CHAT BAR)
--========================================================
do
	local ASSET_BKG = "rbxassetid://35238000"
	local ASSET_BAR_GREEN = "rbxassetid://35238053"
	local ASSET_BAR_RED = "rbxassetid://35238036"
	local ASSET_LABEL = "rbxassetid://34816363"
	local ASSET_HURT_OVERLAY = "rbxassetid://34854607"
	local HEALTH_IDS = { "35238000", "35238053", "35238036", "34816363" }

	local OUR_GUI = "BPOldHealthBar"
	local DEFAULT_SIZE = UDim2.new(0, 170, 0, 18)
	local DEFAULT_ANCHOR = Vector2.new(0.5, 1)
	local DEFAULT_POSITION = UDim2.new(0.5, 0, 1, -24)

	local BAR_LEFT = 0.02
	local BAR_WIDTH = 0.958
	local BAR_TOP = 0.076
	local BAR_HEIGHT = 0.848

	local LABEL_POSITION = UDim2.new(0.68, 0, 0.29, 0)
	local LABEL_SIZE = UDim2.new(0.25, 0, 0.36, 0)

	-- (measured on the user's recording of the 2011 - 2013 bar: on each hit the lost part shows solid white for
	-- about 0.7 seconds, over "HEALTH" too, then fades out in about 0.3)
	local FLASH_HOLD = 0.7
	local FLASH_FADE = 0.3
	local OVERLAY_PERCENT = 5

	local running = false
	local gui, tray, bar, whiteFlash, hurtOverlay = nil, nil, nil, nil, nil
	local conns = {}
	local charConns = {}
	local hidden = {}
	local coreHealthWas = nil
	local currentHumanoid = nil
	local lastRatio = 1
	local flashToken = 0
	local source = nil

	local function disconnectAll(list)
		for _, c in ipairs(list) do pcall(function() c:Disconnect() end) end
		table.clear(list)
	end

	local function isOurs(obj)
		return gui ~= nil and (obj == gui or obj:IsDescendantOf(gui))
	end

	local function usesHealthPicture(obj)
		if not (obj:IsA("ImageLabel") or obj:IsA("ImageButton")) then return false end
		local image = tostring(obj.Image)
		for _, id in ipairs(HEALTH_IDS) do
			if string.find(image, id, 1, true) then return true end
		end
		return false
	end

	local function trayOf(obj)
		if isOurs(obj) then return nil end
		local name = string.lower(obj.Name)
		if name == "tray" and obj.Parent and string.find(string.lower(obj.Parent.Name), "health", 1, true) then
			return obj
		end
		if obj.Name == "HealthFrame" and obj:IsA("GuiObject") then return obj end
		if usesHealthPicture(obj) then
			local parent = obj.Parent
			if parent and parent:IsA("GuiObject") then return parent end
		end
		if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and not obj:IsDescendantOf(LocalPlayer:FindFirstChildOfClass("PlayerGui") or game) then
			local text = string.lower((string.gsub(obj.Text or "", "%s", "")))
			local parent = obj.Parent
			if text == "health" and parent and parent:IsA("GuiObject") and parent.AbsoluteSize.X <= 400 then
				return parent
			end
		end
		return nil
	end

	local function hide(obj)
		if hidden[obj] then return end
		local prop = obj:IsA("LayerCollector") and "Enabled" or (obj:IsA("GuiObject") and "Visible") or nil
		if not prop then return end
		local entry = { prop = prop, was = obj[prop] }
		hidden[obj] = entry
		pcall(function() obj[prop] = false end)
		entry.conn = obj:GetPropertyChangedSignal(prop):Connect(function()
			if running and obj[prop] == true then
				entry.was = true
				pcall(function() obj[prop] = false end)
			end
		end)
	end

	local function setIfDifferent(obj, prop, value)
		if obj[prop] ~= value then obj[prop] = value end
	end

	local function placeOnTop(foundTray)
		if not tray or not gui then return end
		source = foundTray
		local holder = foundTray:FindFirstAncestorWhichIsA("LayerCollector")
		if holder then
			pcall(setIfDifferent, gui, "IgnoreGuiInset", holder.IgnoreGuiInset)
			pcall(setIfDifferent, gui, "ScreenInsets", holder.ScreenInsets)
			pcall(setIfDifferent, gui, "DisplayOrder", holder.DisplayOrder)
		end
		if foundTray.Parent == holder then
			setIfDifferent(tray, "AnchorPoint", foundTray.AnchorPoint)
			setIfDifferent(tray, "Position", foundTray.Position)
			setIfDifferent(tray, "Size", foundTray.Size)
			return
		end
		local pos, size = foundTray.AbsolutePosition, foundTray.AbsoluteSize
		if size.X < 20 or size.Y < 4 then return end
		local origin = Vector2.new(0, 0)
		pcall(function() origin = holder.AbsolutePosition end)
		setIfDifferent(tray, "AnchorPoint", Vector2.new(0, 0))
		setIfDifferent(tray, "Position", UDim2.new(0, pos.X - origin.X, 0, pos.Y - origin.Y))
		setIfDifferent(tray, "Size", UDim2.new(0, size.X, 0, size.Y))
	end

	local function consider(obj)
		if not running or not obj.Parent then return end
		local found = trayOf(obj)
		if not found or isOurs(found) then return end
		placeOnTop(found)
		hide(found)
		local parent = found.Parent
		if parent and string.find(string.lower(parent.Name), "health", 1, true) and not isOurs(parent) then
			hide(parent)
		end
	end

	local function restoreHidden()
		for obj, entry in pairs(hidden) do
			pcall(function() entry.conn:Disconnect() end)
			pcall(function() if obj.Parent then obj[entry.prop] = entry.was end end)
		end
		hidden = {}
	end

	local function build()
		gui = Instance.new("ScreenGui")
		gui.Name = OUR_GUI
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 15
		pcall(function() gui.ScreenInsets = Enum.ScreenInsets.None end)
		if type(syn) == "table" and type(syn.protect_gui) == "function" then pcall(syn.protect_gui, gui) end
		if not pcall(function() gui.Parent = CoreGui end) then
			local ok, hui = pcall(function() return gethui and gethui() end)
			gui.Parent = (ok and hui) or LocalPlayer:WaitForChild("PlayerGui")
		end
		applyAutoScale(gui)

		hurtOverlay = Instance.new("ImageLabel")
		hurtOverlay.Name = "HurtOverlay"
		hurtOverlay.BackgroundTransparency = 1
		hurtOverlay.Image = ASSET_HURT_OVERLAY
		hurtOverlay.Position = UDim2.new(-10, 0, -10, 0)
		hurtOverlay.Size = UDim2.new(20, 0, 20, 0)
		hurtOverlay.Visible = false
		hurtOverlay.ZIndex = 1
		hurtOverlay.Parent = gui

		tray = Instance.new("Frame")
		tray.Name = "tray"
		tray.BackgroundTransparency = 1
		tray.BorderSizePixel = 0
		tray.AnchorPoint = DEFAULT_ANCHOR
		tray.Position = DEFAULT_POSITION
		tray.Size = DEFAULT_SIZE
		tray.ZIndex = 2
		tray.Parent = gui

		local bkg = Instance.new("ImageLabel")
		bkg.Name = "bkg"
		bkg.BackgroundTransparency = 1
		bkg.BorderSizePixel = 0
		bkg.Image = ASSET_BKG
		bkg.Size = UDim2.new(1, 0, 1, 0)
		bkg.ZIndex = 2
		bkg.Parent = tray

		bar = Instance.new("ImageLabel")
		bar.Name = "bar"
		bar.BackgroundTransparency = 1
		bar.BorderSizePixel = 0
		bar.Image = ASSET_BAR_GREEN
		bar.ScaleType = Enum.ScaleType.Stretch
		bar.Position = UDim2.new(BAR_LEFT, 0, BAR_TOP, 0)
		bar.Size = UDim2.new(BAR_WIDTH, 0, BAR_HEIGHT, 0)
		bar.ZIndex = 3
		bar.Parent = tray

		whiteFlash = Instance.new("Frame")
		whiteFlash.Name = "WhiteFlash"
		whiteFlash.BackgroundColor3 = Color3.new(1, 1, 1)
		whiteFlash.BorderSizePixel = 0
		whiteFlash.Position = UDim2.new(BAR_LEFT, 0, BAR_TOP, 0)
		whiteFlash.Size = UDim2.new(0, 0, BAR_HEIGHT, 0)
		whiteFlash.Visible = false
		whiteFlash.ZIndex = 4
		whiteFlash.Parent = tray

		local label = Instance.new("ImageLabel")
		label.Name = "label"
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Image = ASSET_LABEL
		label.ScaleType = Enum.ScaleType.Fit
		label.Position = LABEL_POSITION
		label.Size = LABEL_SIZE
		label.ZIndex = 5
		label.Parent = tray

		task.spawn(function()
			pcall(function() ContentProvider:PreloadAsync({ hurtOverlay, bkg, bar, label }) end)
		end)
	end

	-- each hit its own white piece (two hits close together each show theirs), just left of what is left
	local function flashLost(oldRatio, newRatio)
		local lost = math.clamp(oldRatio - newRatio, 0, 1)
		if lost <= 0.005 or not tray or not tray.Parent then return end
		local piece = Instance.new("Frame")
		piece.Name = "WhiteFlashPiece"
		piece.BackgroundColor3 = Color3.new(1, 1, 1)
		piece.BorderSizePixel = 0
		-- the bar empties from the left, towards "HEALTH": the lost part is just left of what is left
		piece.Position = UDim2.new(BAR_LEFT + BAR_WIDTH * (1 - oldRatio), 0, BAR_TOP, 0)
		piece.Size = UDim2.new(BAR_WIDTH * lost, 0, BAR_HEIGHT, 0)
		piece.ZIndex = 6 -- (over "HEALTH", as in the recording)
		piece.Parent = tray
		task.delay(FLASH_HOLD, function()
			if not piece.Parent then return end
			local ok = pcall(function()
				local fade = TweenService:Create(piece, TweenInfo.new(FLASH_FADE, Enum.EasingStyle.Linear),
					{ BackgroundTransparency = 1 })
				fade.Completed:Connect(function() piece:Destroy() end)
				fade:Play()
			end)
			if not ok then piece:Destroy() end
		end)
	end

	local function clearFlashes()
		if not tray then return end
		for _, child in ipairs(tray:GetChildren()) do
			if child.Name == "WhiteFlashPiece" then child:Destroy() end
		end
	end

	local function hurtFlash()
		if not hurtOverlay or not hurtOverlay.Parent then return end
		hurtOverlay.Size = UDim2.new(1, 0, 1, 0)
		hurtOverlay.Position = UDim2.new(0, 0, 0, 0)
		hurtOverlay.Visible = true
		hurtOverlay:TweenSizeAndPosition(
			UDim2.new(20, 0, 20, 0), UDim2.new(-10, 0, -10, 0),
			Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 10, true,
			function() hurtOverlay.Visible = false end
		)
	end

	local function update(health)
		if not currentHumanoid or not bar then return end
		local maxHealth = math.max(currentHumanoid.MaxHealth, 1)
		local ratio = math.clamp(health / maxHealth, 0, 1)
		local old = lastRatio
		lastRatio = ratio
		if ratio <= 0 then
			bar.Visible = false
		else
			bar.Visible = true
			bar.Image = (ratio > 0.25) and ASSET_BAR_GREEN or ASSET_BAR_RED
			bar.Position = UDim2.new(BAR_LEFT + BAR_WIDTH * (1 - ratio), 0, BAR_TOP, 0)
			bar.Size = UDim2.new(BAR_WIDTH * ratio, 0, BAR_HEIGHT, 0)
		end
		if ratio < old then
			flashLost(old, ratio)
			if old - ratio >= OVERLAY_PERCENT / 100 then hurtFlash() end
		end
	end

	local function bindCharacter(character)
		disconnectAll(charConns)
		if not character then return end
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not running then return end
		currentHumanoid = humanoid
		lastRatio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		if whiteFlash then whiteFlash.Visible = false end
		clearFlashes()
		update(humanoid.Health)
		table.insert(charConns, humanoid.HealthChanged:Connect(update))
		table.insert(charConns, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
			update(humanoid.Health)
		end))
		table.insert(charConns, humanoid.Died:Connect(function() update(0) end))
	end

	local api = {}

	function api.Start()
		if running then return end
		running = true
		pcall(function()
			coreHealthWas = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Health)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		end)
		build()

		local roots = { CoreGui }
		pcall(function()
			local hui = gethui and gethui()
			if hui and hui ~= CoreGui then table.insert(roots, hui) end
		end)
		local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if pg then table.insert(roots, pg) end
		for _, root in ipairs(roots) do
			pcall(function()
				for _, d in ipairs(root:GetDescendants()) do consider(d) end
				table.insert(conns, root.DescendantAdded:Connect(function(d)
					task.defer(consider, d)
				end))
			end)
		end
		table.insert(conns, RunService.Heartbeat:Connect(function()
			if source and source.Parent then placeOnTop(source) end
		end))

		table.insert(conns, LocalPlayer.CharacterAdded:Connect(bindCharacter))
		if LocalPlayer.Character then task.spawn(bindCharacter, LocalPlayer.Character) end
	end

	function api.Stop()
		if not running then return end
		running = false
		disconnectAll(conns)
		disconnectAll(charConns)
		restoreHidden()
		if gui then pcall(function() gui:Destroy() end) end
		gui, tray, bar, whiteFlash, hurtOverlay, source, currentHumanoid = nil, nil, nil, nil, nil, nil, nil
		pcall(function()
			if coreHealthWas ~= nil then StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, coreHealthWas) end
		end)
	end

	function api.IsRunning()
		return running
	end

	env.OldHealthBar = api
	api.Start()
end

--========================================================
-- 9. CENTERED EARLY 2011 BACKPACK (RAISED ABOVE HEALTH BAR)
--========================================================
local BackpackGui = Instance.new("Frame")
BackpackGui.Name = "ClassicBackpack"
BackpackGui.AnchorPoint = Vector2.new(0.5, 1)
BackpackGui.Position = UDim2.new(0.5, 0, 1, -48)
BackpackGui.BackgroundTransparency = 1
BackpackGui.ZIndex = 8
BackpackGui.Parent = ScreenGui

local BackpackLayout = Instance.new("UIListLayout")
BackpackLayout.FillDirection = Enum.FillDirection.Horizontal
BackpackLayout.SortOrder = Enum.SortOrder.LayoutOrder
BackpackLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
BackpackLayout.VerticalAlignment = Enum.VerticalAlignment.Center
-- (Addtion-Scripts) the slots as close together as they go without touching: each one's edge is drawn 1
-- outside it (the red outline of the selected one is drawn inside), so 3 leaves 1 between neighbours' edges
local SLOT_GAP = 3
local SLOT_EDGE = Color3.fromRGB(105, 105, 105)
local SLOT_EDGE_SELECTED = Color3.fromRGB(225, 20, 20) -- (2 thick: still only meets the next slot's edge)
BackpackLayout.Padding = UDim.new(0, SLOT_GAP)
BackpackLayout.Parent = BackpackGui

local itemSlots = {}
local toolMappings = {}
local clickDebounce = false
local SLOT_SIZE = 54

local function toggleSlotTool(slotIndex)
	if clickDebounce then
		return
	end
	local tool = toolMappings[slotIndex]
	if not tool or not tool:IsDescendantOf(game) then
		return
	end
	clickDebounce = true
	local currentCharacter = LocalPlayer.Character
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid") and backpack then
		if tool.Parent == currentCharacter then
			tool.Parent = backpack
		else
			for _, otherTool in ipairs(currentCharacter:GetChildren()) do
				if otherTool:IsA("Tool") then
					otherTool.Parent = backpack
				end
			end
			tool.Parent = currentCharacter
		end
	end
	task.wait(0.08)
	clickDebounce = false
end

for i = 1, 10 do
	local slot = Instance.new("Frame")
	slot.Name = "Slot" .. i
	slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	-- (Addtion-Scripts) a see-through deep black inside, the same black as the GUI's trays (their picture is
	-- black at 179 / 255), with a slightly lighter edge
	slot.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	slot.BackgroundTransparency = 1 - 179 / 255
	slot.BorderColor3 = Color3.fromRGB(105, 105, 105)
	-- (Addtion-Scripts) each slot its own box with very slightly rounded corners: the border is a UIStroke (a
	-- frame's own border doesn't follow a UICorner)
	slot.BorderSizePixel = 0
	slot.LayoutOrder = i
	slot.ZIndex = 8
	slot.Visible = false
	local slotCorner = Instance.new("UICorner")
	slotCorner.CornerRadius = UDim.new(0, 2) -- (only just rounded)
	slotCorner.Parent = slot
	local slotBorder = Instance.new("UIStroke")
	slotBorder.Name = "SlotBorder"
	slotBorder.Color = Color3.fromRGB(105, 105, 105)
	slotBorder.Thickness = 1
	slotBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	slotBorder.Parent = slot

	local selectionFrame = Instance.new("Frame")
	selectionFrame.Name = "SelectionFrame"
	-- (Addtion-Scripts) a little smaller than the slot, so its red outline (drawn outside it) is inside the
	-- slot and never reaches the next one
	selectionFrame.Position = UDim2.new(0, 2.5, 0, 2.5)
	selectionFrame.Size = UDim2.new(1, -5, 1, -5)
	selectionFrame.BackgroundTransparency = 1
	selectionFrame.ZIndex = 12
	selectionFrame.Parent = slot
	local selectionCorner = Instance.new("UICorner")
	selectionCorner.CornerRadius = UDim.new(0, 2)
	selectionCorner.Parent = selectionFrame

	local stroke = Instance.new("UIStroke")
	stroke.Name = "SelectionStroke"
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(225, 20, 20)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Enabled = false
	stroke.Parent = selectionFrame

	local numberLabel = Instance.new("TextLabel")
	numberLabel.Size = UDim2.new(0, 16, 0, 16)
	numberLabel.Position = UDim2.new(0, 4, 0, 2)
	numberLabel.BackgroundTransparency = 1
	numberLabel.Text = tostring(i == 10 and 0 or i)
	numberLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	-- (Addtion-Scripts) as in the 2011 client: a bigger plain white number, only a faint outline
	numberLabel.TextStrokeTransparency = 0.7
	numberLabel.TextXAlignment = Enum.TextXAlignment.Left
	numberLabel.TextYAlignment = Enum.TextYAlignment.Top
	numberLabel.Font = Enum.Font.Arial
	numberLabel.BorderSizePixel = 0
	numberLabel.TextSize = 15
	numberLabel.ZIndex = 11
	numberLabel.Parent = slot

	local toolBtn = Instance.new("ImageButton")
	toolBtn.Name = "ToolButton"
	toolBtn.Size = UDim2.new(1, -4, 1, -4)
	toolBtn.Position = UDim2.new(0, 2, 0, 2)
	toolBtn.BackgroundTransparency = 1
	toolBtn.ZIndex = 9
	toolBtn.Parent = slot

	local textFallback = Instance.new("TextLabel")
	textFallback.Name = "TextFallback"
	textFallback.Size = UDim2.new(1, 0, 1, 0)
	textFallback.BackgroundTransparency = 1
	textFallback.TextColor3 = Color3.fromRGB(255, 255, 255)
	textFallback.Font = Enum.Font.ArialBold
	textFallback.TextSize = 10
	textFallback.TextWrapped = true
	textFallback.ZIndex = 10
	textFallback.Parent = toolBtn

	storeConnection(toolBtn.Activated:Connect(function()
		toggleSlotTool(i)
	end))

	slot.Parent = BackpackGui
	itemSlots[i] = slot
end

local KEYCODE_TO_SLOT = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 10
}

storeConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or UserInputService:GetFocusedTextBox() then
		return
	end
	local slotIdx = KEYCODE_TO_SLOT[input.KeyCode]
	if slotIdx then
		toggleSlotTool(slotIdx)
	end
end))

local function updateBackpack()
	local currentTools = {}
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				currentTools[tool] = true
			end
		end
	end
	local character = LocalPlayer.Character
	if character then
		for _, tool in ipairs(character:GetChildren()) do
			if tool:IsA("Tool") then
				currentTools[tool] = true
			end
		end
	end
	for slotIdx, registeredTool in pairs(toolMappings) do
		if not currentTools[registeredTool] then
			toolMappings[slotIdx] = nil
		end
	end
	for tool in pairs(currentTools) do
		local alreadySlotted = false
		for _, registeredTool in pairs(toolMappings) do
			if registeredTool == tool then
				alreadySlotted = true
				break
			end
		end
		if not alreadySlotted then
			for i = 1, 10 do
				if not toolMappings[i] then
					toolMappings[i] = tool
					break
				end
			end
		end
	end
	local totalVisibleSlots = 0
	for i = 1, 10 do
		if toolMappings[i] then
			totalVisibleSlots = totalVisibleSlots + 1
		end
	end
	-- (Addtion-Scripts) as wide as the slots shown with their gaps, so they sit together in the middle
	local shown = math.max(1, totalVisibleSlots)
	BackpackGui.Size = UDim2.new(
		0,
		shown * SLOT_SIZE + (shown - 1) * SLOT_GAP,
		0,
		SLOT_SIZE
	)
	local characterModel = LocalPlayer.Character
	for i = 1, 10 do
		local slot = itemSlots[i]
		local tool = toolMappings[i]
		if tool and tool:IsDescendantOf(game) then
			local toolBtn = slot.ToolButton
			local textFallback = toolBtn:FindFirstChild("TextFallback")
			local stroke = slot:FindFirstChild("SelectionStroke", true)
			toolBtn.Image = tool.TextureId
			if tool.TextureId == "" then
				if textFallback then
					textFallback.Text = tool.Name
				end
			else
				if textFallback then
					textFallback.Text = ""
				end
			end
			-- (Addtion-Scripts) the selected slot's own edge turns red (and a little thicker): one outline, not a
			-- red one inside the grey one
			local selected = characterModel ~= nil and tool.Parent == characterModel
			if stroke then
				stroke.Enabled = false
			end
			local edge = slot:FindFirstChild("SlotBorder")
			if edge then
				edge.Color = selected and SLOT_EDGE_SELECTED or SLOT_EDGE
				edge.Thickness = selected and 2 or 1
			end
			slot.Visible = true
		else
			slot.Visible = false
		end
	end
end

local function setupBackpackConnections(character)
	local backpack = LocalPlayer:WaitForChild("Backpack", 5)
	if backpack then
		storeConnection(backpack.ChildAdded:Connect(updateBackpack))
		storeConnection(backpack.ChildRemoved:Connect(updateBackpack))
	end
	if character then
		storeConnection(character.ChildAdded:Connect(updateBackpack))
		storeConnection(character.ChildRemoved:Connect(updateBackpack))
	end
	updateBackpack()
end

storeConnection(LocalPlayer.CharacterAdded:Connect(setupBackpackConnections))
if LocalPlayer.Character then
	task.spawn(function()
		setupBackpackConnections(LocalPlayer.Character)
	end)
end

--========================================================
-- 10. EXTRACTED 2011 CLASSIC CHAT BUBBLES (FROM BLOXY LOADER)
--========================================================
local pg = LocalPlayer:WaitForChild("PlayerGui")

local function startClassicBubbles()
	if env.ClassicBubbleCleanup then
		pcall(env.ClassicBubbleCleanup)
	end

	local BUBBLE_NAME = "__CLASSIC_2011_BUBBLE"
	local MAX_DISTANCE = 75
	local DOT_DISTANCE = 52

	local function bubbleLifetime(text, isSelf)
		local t = math.min(#text / 75, 1)
		if isSelf then
			return 8 + 7 * t
		end
		return 12 + 8 * t
	end

	local MAX_BUBBLES = 3
	local BUBBLE_GAP = 0             -- the bubble picture's own edge already leaves a gap between stacked bubbles
	-- The 2014 bubble (measured on a 2014 screenshot): Arial 22 in a tight bubble with a soft grey edge, and a
	-- tail whose edge runs straight on from the bubble's. These are the sizes of 2011-2014 Dialogs and Chat as first
	-- published (the bubbles in the 2014 screenshots): the bubble picture at slice 0.5, and the 18 x 21 tail with its
	-- top 8 px up into the frame, where the white ends, so the grey edge bends into the tail and no corner or white
	-- connector shows. (A thinner edge, or the tail lower, left a white notch with square corners where they meet,
	-- worst on small bubbles.) Small bubbles keep the narrow 42 frame, so the edge runs down into the tail like a
	-- funnel. A faint stroke makes the letters as heavy as 2014's.
	local FONT_SIZE = 22
	local MAX_WIDTH = 240            -- where long messages wrap
	local PAD_X, PAD_Y = 24, 22      -- the bubble frame is the text's size plus these
	local TEXT_Y = 11                -- the text's top inside the bubble frame
	local BODY_SLICE_SCALE = 0.5     -- the bubble picture's corners and edge (the tail's join is made for 0.5)
	local MIN_WIDTH = 42             -- the narrowest bubble frame
	local TEXT_STROKE = 0.8          -- a faint outline on the letters: as heavy as the 2014 text (1 = none)
	local TAIL_OVERLAP = 8           -- how far the tail's top goes up into the bubble frame
	local TAIL_WIDTH, TAIL_HEIGHT = 18, 21
	local DOTS_WIDTH, DOTS_HEIGHT = 52, FONT_SIZE + PAD_Y
	local TEXT_COLOR = Color3.fromRGB(0, 0, 0)
	local OLD_TEXT_COLOR = Color3.fromRGB(160, 160, 160)

	local running = true
	local connections = {}
	local stacks = {}
	local lastMessages = {}

	local savedLegacyBubbles = nil
	pcall(function()
		savedLegacyBubbles = Chat.BubbleChatEnabled
		Chat:SetBubbleChatEnabled(false)
	end)

	local function playerCharacterOf(object)
		local current = object
		while current and current ~= game do
			if current:IsA("Model") and Players:GetPlayerFromCharacter(current) then
				return current
			end
			current = current.Parent
		end
		return nil
	end

	local KEEP_NAMES = { CustomExecutorHealth = true }
	local function isForeignBubble(object)
		return object.ClassName == "BillboardGui"
			and object.Name ~= BUBBLE_NAME
			and not KEEP_NAMES[object.Name]
			and not object:GetAttribute("ClassicOwned")
	end

	local function belongsToPlayerCharacter(object)
		if object.Adornee and playerCharacterOf(object.Adornee) then
			return true
		end
		return playerCharacterOf(object) ~= nil
	end

	local function removeCharacterBubbles(character)
		if not character then
			return
		end
		for _, object in ipairs(character:GetDescendants()) do
			if isForeignBubble(object) then
				pcall(function()
					object:Destroy()
				end)
			end
		end
	end

	local function layout(stack)
		local entries = stack.entries
		local count = #entries
		if count == 0 then
			return
		end

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
			if i > 1 then
				total = total + BUBBLE_GAP
			end
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
			entry.label.Size = UDim2.new(0, entry.textWidth, 0, entry.textHeight)
			entry.label.Position = UDim2.new(0.5, -entry.textWidth / 2, 0, TEXT_Y)
			y = y - BUBBLE_GAP
		end
		stack.tail.Position = UDim2.new(0.5, -TAIL_WIDTH / 2, 0, total - TAIL_OVERLAP)
	end

	local function destroyStack(player)
		local stack = stacks[player]
		if not stack then
			return
		end
		stacks[player] = nil
		if stack.connection then
			stack.connection:Disconnect()
		end
		pcall(function()
			stack.gui:Destroy()
		end)
	end

	local function removeEntry(stack, entry)
		if entry.removed then
			return
		end
		entry.removed = true
		local index = table.find(stack.entries, entry)
		if index then
			table.remove(stack.entries, index)
		end
		pcall(function()
			entry.frame:Destroy()
		end)
		if stacks[stack.player] ~= stack then
			return
		end
		if #stack.entries == 0 then
			destroyStack(stack.player)
		else
			layout(stack)
		end
	end

	local function getStack(player, head)
		local existing = stacks[player]
		if existing and existing.head == head and existing.gui.Parent then
			return existing
		end
		destroyStack(player)

		for _, object in ipairs(head:GetChildren()) do
			if object.Name == BUBBLE_NAME then
				object:Destroy()
			end
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
				if stacks[player] == stack then
					destroyStack(player)
				else
					stack.connection:Disconnect()
				end
				return
			end
			local cam = Workspace.CurrentCamera
			if not cam then
				return
			end
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
		if not head then
			return
		end
		removeCharacterBubbles(character)

		local stack = getStack(player, head)

		for _, old in ipairs(stack.entries) do
			old.label.TextColor3 = OLD_TEXT_COLOR
			old.label.TextStrokeColor3 = OLD_TEXT_COLOR
		end
		while #stack.entries >= MAX_BUBBLES do
			removeEntry(stack, stack.entries[1])
		end

		local measured = TextService:GetTextSize(text, FONT_SIZE, Enum.Font.Arial, Vector2.new(MAX_WIDTH, 1000))
		-- The text is drawn exactly as wide as it was measured (a hair over, never past the wrap width), so it
		-- wraps the same way it was measured. It used to be drawn in the whole bubble less 16: 8 px wider than
		-- the measured wrap on long messages, so a word more fitted on a line and that line ran into the grey edge.
		-- (The bubble itself is as wide as before.)
		local textWidth = math.min(math.ceil(measured.X) + 2, MAX_WIDTH)

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
			textWidth = textWidth,
			height = measured.Y + PAD_Y,
			textHeight = measured.Y,
			frame = frame,
			label = label,
		}
		table.insert(stack.entries, entry)
		frame.Parent = stack.gui
		layout(stack)

		task.delay(bubbleLifetime(text, player == Players.LocalPlayer), function()
			removeEntry(stack, entry)
		end)
	end

	local function receiveMessage(player, text)
		if not running or not player then
			return
		end
		if typeof(text) ~= "string" then
			return
		end
		text = text:gsub("^%s+", ""):gsub("%s+$", "")
		if text == "" then
			return
		end
		local key = tostring(player.UserId) .. ":" .. text
		if lastMessages[key] then
			return
		end
		lastMessages[key] = true
		task.delay(0.25, function()
			lastMessages[key] = nil
		end)
		-- (the chat log gets the message by itself, above)
		createBubble(player, text)
	end

	local function hookPlayer(player)
		table.insert(connections, storeConnection(player.Chatted:Connect(function(text)
			receiveMessage(player, text)
		end)))
		table.insert(connections, storeConnection(player.CharacterAdded:Connect(function(character)
			task.wait(0.2)
			if running then
				removeCharacterBubbles(character)
			end
		end)))
	end

	for _, player in ipairs(Players:GetPlayers()) do
		hookPlayer(player)
	end
	table.insert(connections, storeConnection(Players.PlayerAdded:Connect(hookPlayer)))
	table.insert(connections, storeConnection(Players.PlayerRemoving:Connect(destroyStack)))

	pcall(function()
		table.insert(connections, storeConnection(TextChatService.MessageReceived:Connect(function(message)
			if not message or not message.TextSource then
				return
			end
			receiveMessage(Players:GetPlayerByUserId(message.TextSource.UserId), message.Text)
		end)))
	end)

	local function watchContainer(container)
		table.insert(connections, storeConnection(container.DescendantAdded:Connect(function(object)
			if not isForeignBubble(object) then
				return
			end
			task.defer(function()
				if running and object.Parent and belongsToPlayerCharacter(object) then
					pcall(function()
						object:Destroy()
					end)
				end
			end)
		end)))
	end
	watchContainer(Workspace)
	watchContainer(pg)

	task.spawn(function()
		pcall(function()
			for _, object in ipairs(pg:GetDescendants()) do
				if isForeignBubble(object) and belongsToPlayerCharacter(object) then
					object:Destroy()
				end
			end
		end)
		while running and ScreenGui.Parent do
			for _, player in ipairs(Players:GetPlayers()) do
				removeCharacterBubbles(player.Character)
			end
			task.wait(3)
		end
	end)

	local function cleanup()
		running = false
		for _, c in ipairs(connections) do
			pcall(function()
				c:Disconnect()
			end)
		end
		connections = {}
		for player in pairs(stacks) do
			destroyStack(player)
		end
		if savedLegacyBubbles ~= nil then
			pcall(function()
				Chat:SetBubbleChatEnabled(savedLegacyBubbles)
			end)
		end
		if env.ClassicBubbleCleanup == cleanup then
			env.ClassicBubbleCleanup = nil
		end
	end

	env.ClassicBubbleCleanup = cleanup
	return cleanup
end

startClassicBubbles()

--========================================================
-- 11. CHAT INPUT & TEXT CHANNEL EVENTS
--========================================================
local function sendChatMessage(text)
	text = tostring(text or "")
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then
		return
	end
	if not GeneralChannel or not GeneralChannel.Parent then
		GeneralChannel = findGeneralChannel()
	end
	if not GeneralChannel then
		warn("[Early 2011 GUI] Cannot send message because RBXGeneral is unavailable.")
		return
	end
	local success, result = pcall(function()
		return GeneralChannel:SendAsync(text)
	end)
	if not success then
		warn("[Early 2011 GUI] SendAsync failed:", result)
	end
end

storeConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Slash then
		task.defer(function()
			if HiddenTextBox and HiddenTextBox.Parent then
				HiddenTextBox:CaptureFocus()
			end
		end)
	end
end))

storeConnection(BottomChatBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		task.defer(function()
			if HiddenTextBox and HiddenTextBox.Parent then
				HiddenTextBox:CaptureFocus()
			end
		end)
	end
end))

storeConnection(HiddenTextBox.Focused:Connect(function()
	ChatPromptLabel.Text = ""
	BottomChatBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	BottomChatBar.BorderSizePixel = 0
	HiddenTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
end))

storeConnection(HiddenTextBox.FocusLost:Connect(function(enterPressed)
	local text = HiddenTextBox.Text
	HiddenTextBox.Text = ""
	BottomChatBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	BottomChatBar.BorderSizePixel = 0
	ChatPromptLabel.Text = 'To chat click here or press the "/" key'
	if not enterPressed then
		return
	end
	sendChatMessage(text)
end))

storeConnection(TextChatService.ChildAdded:Connect(function(child)
	if child.Name ~= "TextChannels" then
		return
	end
	task.defer(function()
		GeneralChannel = findGeneralChannel()
	end)
end))

task.spawn(function()
	while ScreenGui and ScreenGui.Parent do
		disableDefaultBubbles()
		if not GeneralChannel or not GeneralChannel.Parent then
			pcall(function()
				GeneralChannel = findGeneralChannel()
			end)
		end
		task.wait(1)
	end
end)

