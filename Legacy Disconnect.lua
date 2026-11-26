-- [[ LEGACY DISCONNECT MESSAGE (2015 - 2017) ]]
-- The old error / disconnect message, from the DISCONNECT SCREEN of the "legacy" CoreGui changer
-- (github.com/yeku/legacy, Roblox2016_Remaster's look): a red bar at the top centre of the screen, right under the
-- top bar, showing the engine's message ("You have lost connection...", kicks, teleport errors). That is how Roblox
-- showed it until late 2018: only the red bar, no blur, no box in the middle of the screen, no Leave / Reconnect
-- buttons; the way out is the menu and Leave Game, like back then. Half the screen wide, 80 high (40 on a small
-- touch screen). While it shows, Roblox's own error box is hidden, its screen blur is kept off, and you can still
-- move (the controls, the character and the camera are kept free), like back then.
-- The loader starts it with the 2015 early, 2015, 2016, 2017 and 2019 GUIs. It also works pasted on its own.
-- getgenv().LegacyDisconnectStop() takes it away again (and gives Roblox's own error box back).

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local genv = (getgenv and getgenv()) or _G
if type(genv.LegacyDisconnectStop) == "function" then pcall(genv.LegacyDisconnectStop) end

local TOP = 36 -- the old top bar's height: the bar hangs right under it

local conns = {}
local stopped = false
local hiddenPrompts = {} -- Roblox's own error box (RobloxPromptGui), hidden while the message shows

local parent = CoreGui
pcall(function()
	if gethui then parent = gethui() end
end)

local old = parent:FindFirstChild("LegacyDisconnectGui") or CoreGui:FindFirstChild("LegacyDisconnectGui")
if old then old:Destroy() end

local DisconnectGui = Instance.new("ScreenGui")
DisconnectGui.Name = "LegacyDisconnectGui"
DisconnectGui.DisplayOrder = 1000
DisconnectGui.IgnoreGuiInset = true
DisconnectGui.ResetOnSpawn = false

local ErrorFrame = Instance.new("Frame")
ErrorFrame.Name = "ErrorFrame"
ErrorFrame.BackgroundColor3 = Color3.fromRGB(253, 68, 72)
ErrorFrame.BorderSizePixel = 0
ErrorFrame.Position = UDim2.new(0.25, 0, 0, TOP)
ErrorFrame.Size = UDim2.new(0.5, 0, 0, 80)
ErrorFrame.ZIndex = 8
ErrorFrame.Visible = false
ErrorFrame.Parent = DisconnectGui

local ErrorText = Instance.new("TextLabel")
ErrorText.Name = "ErrorText"
ErrorText.BackgroundTransparency = 1
ErrorText.Size = UDim2.new(1, 0, 1, 0)
ErrorText.Font = Enum.Font.SourceSansBold
ErrorText.TextSize = 14
ErrorText.TextWrapped = true
ErrorText.TextColor3 = Color3.new(1, 1, 1)
ErrorText.Text = ""
ErrorText.ZIndex = 8
ErrorText.Parent = ErrorFrame

DisconnectGui.Parent = parent

local disconnected = false

local function showPrompts()
	for gui in pairs(hiddenPrompts) do
		pcall(function() gui.Enabled = true end)
	end
	hiddenPrompts = {}
end

local function hidePrompts()
	pcall(function()
		local prompt = CoreGui:FindFirstChild("RobloxPromptGui")
		if prompt and prompt:IsA("ScreenGui") and prompt.Enabled then
			prompt.Enabled = false
			hiddenPrompts[prompt] = true
		end
	end)
end

local function update()
	if stopped then return end
	local got, message = pcall(function() return GuiService:GetErrorMessage() end)
	if not got or type(message) ~= "string" then message = "" end
	disconnected = message ~= ""
	ErrorText.Text = message
	ErrorFrame.Visible = disconnected
	if disconnected then
		hidePrompts()
	else
		showPrompts()
	end
end

-- No blur: on a disconnect the screen blur comes from Roblox taking its own GUI to have the focus, so that is
-- switched off every frame while the message shows; any blur the error box added to the CoreGui is switched off too.
local lastScan = 0
table.insert(conns, RunService.RenderStepped:Connect(function()
	if stopped or not disconnected then return end
	pcall(function()
		local camera = workspace.CurrentCamera
		local small = UserInputService.TouchEnabled and camera ~= nil
			and (camera.ViewportSize.X <= 700 or camera.ViewportSize.Y <= 500)
		ErrorFrame.Size = UDim2.new(0.5, 0, 0, small and 40 or 80)
		ErrorFrame.Position = UDim2.new(0.25, 0, 0, TOP)
	end)
	pcall(function() RunService:SetRobloxGuiFocused(false) end)
	-- (the rest a few times a second, not every frame)
	if os.clock() - lastScan < 0.25 then return end
	lastScan = os.clock()
	hidePrompts()
	-- you can still move: the controls on, the character not frozen, anchored or stood still by the disconnect
	pcall(function()
		local player = Players.LocalPlayer
		local module = player and player:FindFirstChild("PlayerScripts")
			and player.PlayerScripts:FindFirstChild("PlayerModule")
		if module then require(module):GetControls():Enable() end
		local character = player and player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.PlatformStand = false end
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root.Anchored then root.Anchored = false end
	end)
	pcall(function()
		for _, object in ipairs(CoreGui:GetDescendants()) do
			if object:IsA("BlurEffect") and object.Enabled then object.Enabled = false end
		end
	end)
end))

pcall(function()
	table.insert(conns, GuiService.ErrorMessageChanged:Connect(update))
end)
update()

genv.LegacyDisconnectStop = function()
	if stopped then return end
	stopped = true
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	showPrompts()
	pcall(function() DisconnectGui:Destroy() end)
	if genv.LegacyDisconnectStop then genv.LegacyDisconnectStop = nil end
	print("[Legacy Disconnect] Off: Roblox's own error box is back.")
end

print("[Legacy Disconnect] On: a disconnect shows the old red bar under the top bar.")
