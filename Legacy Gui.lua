--[[
 ___       _______   ________  ________  ________      ___    ___ 
|\  \     |\  ___ \ |\   ____\|\   __  \|\   ____\    |\  \  /  /|
\ \  \    \ \   __/|\ \  \___|\ \  \|\  \ \  \___|    \ \  \/  / /
 \ \  \    \ \  \_|/_\ \  \  __\ \   __  \ \  \        \ \    / / 
  \ \  \____\ \  \_|\ \ \  \|\  \ \  \ \  \ \  \____    \/   / /  
   \ \_______\ \_______\ \_______\ \__\ \__\ \_______\__/   / /   
    \|_______|\|_______|\|_______|\|__|\|__|\|_______|\____/ /    
                                                     \|____|/     
                                                                  
> github.com/yeku/legacy
>> a ROBLOX coregui changer that lets you use older designs
[!] only supports 2012, 2013, 2014, 2015, 2016
]]

-- (Addtion-Scripts copy of github.com/yeku/legacy's Source.luau, the original code. Bloxy's 2013 / 2015 / 2016 GUIs
--  load yeku's file; More guis.lua points them here instead, so they still work if that file changes or goes away.
--  Changed only where it could stop the GUI from loading:
--   * RBXM Suite and the Legacy model come through the loader's getgenv().BP_Legacy (another copy of the library,
--     the model straight from the release or from an earlier download when the usual download fails)
--   * the modern chat's bubbleChat is waited for 10 s, not forever (without it: no old bubble look, the rest loads)
--   * RobloxGui.NotificationFrame and the other parts it looks for may be missing (on phones they can be): skipped
--   * QueryDescendants, if this client doesn't have it, falls back to looking through the children
--  Run alone like the original: set getgenv().LegacySettings first.)
local ADDTION_LEGACY = true

if (not game:IsLoaded()) then
	game.Loaded:Wait()
end

-- Settings
local Developer = (isfile and (isfile("yeku.txt") and isfile("Legacy.rbxm")))
local Environment = (getgenv or function() return _G end)
local Settings = Environment().LegacySettings or ({
	Year = 2012,
	OldGraphics = true,
	HideDisplayName = true,
	SafeChat = true,
	OldConsole = true,
	OldBubbleChat = true,
})

-- Services
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local TextChatService = game:GetService("TextChatService")

-- Variables
local RobloxGui = CoreGui:WaitForChild("RobloxGui")
local Helpers = Environment().BP_Legacy -- (the loader's; nil when this is run alone)
local ChatBubbles = (function()
	if (Helpers and Helpers.Bubbles) then
		return Helpers.Bubbles()
	end
	local ExperienceChat = CoreGui:FindFirstChild("ExperienceChat") or CoreGui:WaitForChild("ExperienceChat", 10)
	local Bubbles = (ExperienceChat and (ExperienceChat:FindFirstChild("bubbleChat") or ExperienceChat:WaitForChild("bubbleChat", 10)))
	if (not Bubbles) then
		warn("[Legacy] the modern chat's bubbleChat wasn't found, loading without the old bubble look")
	end
	return Bubbles or Instance.new("Folder")
end)()

-- Types
export type Properties = { [string]: any }

-- Functions
local Force = function(Object: Instance, Property: string, Value: any)
	if (Object[Property] ~= Value) then
		Object[Property] = Value
	end

	Object:GetPropertyChangedSignal(Property):Connect(function()
		if (Object[Property] ~= Value) then
			Object[Property] = Value
		end
	end)
end

local Set = function(Object: Instance, Properties: Properties, Forced: boolean)
	if (not Object) then
		return
	end

	for Property, Value in next, Properties do
		local Success, Result = pcall(function()
			Object[Property] = Value

			if (Forced) then
				Force(Object, Property, Value)
			end
		end)

		if (not Success) then
			warn(`{Result} | {debug.traceback()}`)
		end
	end
end

local Create = function(ClassName: string, Properties: Properties, Forced: boolean, Parent: Instance?)
	local Object = Instance.new(ClassName)

	if (Parent) then
		Object.Parent = Parent
	end

	Set(Object, Properties, Forced)

	return Object
end

local Run = function(Bool: boolean, Callback: () -> ())
	if (Bool) then
		task.spawn(Callback)
	end
end

-- (QueryDescendants with a fallback: "> A, > B" (children of these classes) and "#A, #B" (descendants with these names))
local Query = function(Object: Instance, Selector: string)
	local Success, Result = pcall(function()
		return Object:QueryDescendants(Selector)
	end)

	if (Success and type(Result) == "table") then
		return Result
	end

	local Found, Classes, Names = {}, {}, {}

	for Part in string.gmatch(Selector, "[^,]+") do
		local ClassName = string.match(Part, "^%s*>%s*([%w_]+)%s*$")
		local Name = string.match(Part, "^%s*#([%w_]+)%s*$")

		if (ClassName) then Classes[ClassName] = true end
		if (Name) then Names[Name] = true end
	end

	for _, Child in next, Object:GetChildren() do
		if (Classes[Child.ClassName]) then table.insert(Found, Child) end
	end

	if (next(Names)) then
		for _, Descendant in next, Object:GetDescendants() do
			if (Names[Descendant.Name]) then table.insert(Found, Descendant) end
		end
	end

	return Found
end

-- Module
local Suite = Environment().Suite
	or (Helpers and Helpers.LoadSuite and Helpers.LoadSuite())
	or loadstring(game:HttpGet("https://raw.githubusercontent.com/yeku/forks/refs/heads/main/Scripts/RBXMSuite.luau"))()
local Legacy = (function()
	local Path do
		if (Developer) then
			StarterGui:SetCore("SendNotification", { Title = "Legacy", Text = "Running the developer build", Duration = 5 })
			Path = "Legacy.rbxm"
		else
			local RBXM = (Helpers and Helpers.Model) and Helpers.Model(Suite) or Suite.download("yeku/legacy@latest", "Legacy.rbxm")
			Path = RBXM
		end
	end

	return Suite.launch(Path, { runscripts = true, debug = true })
end)()

-- Setup
local LegacyGui = Suite.require(Legacy):Start(Settings.Year, Settings.SafeChat)

RobloxGui.Enabled = false

-- (not every client has it: phones may not)
local NotificationFrame = RobloxGui:FindFirstChild("NotificationFrame")
if (NotificationFrame) then
	NotificationFrame.Parent = LegacyGui
end

Run(Settings.OldConsole == true, function()
	loadstring(game:HttpGet("https://raw.githubusercontent.com/yeku/forks/refs/heads/main/Scripts/LegacyConsole.luau"))()
end)

Run(Settings.OldGraphics == true, function()
	if (sethiddenproperty) then
		task.spawn(sethiddenproperty, Lighting, "Technology", Enum.Technology.Compatibility)
	end

	for _, Hidden in next, Query(Lighting, "> DepthOfFieldEffect, > SunRaysEffect, > BloomEffect, > BlurEffect, > ColorCorrectionEffect, > Atmosphere") do
		if (Hidden:IsA("Atmosphere")) then
			Hidden:Destroy()
		else
			Force(Hidden, "Enabled", false)
		end
	end

	pcall(Create, "ColorGradingEffect", { TonemapperPreset = Enum.TonemapperPreset.Retro })
	Create("ColorCorrectionEffect", {
		Saturation = 0,
		Contrast = -0.1,
		Parent = Lighting,
	})
end)

Run(Settings.OldBubbleChat == true, function()
	-- Variables
	local BubbleChatConfiguration = TextChatService:WaitForChild("BubbleChatConfiguration")
	local SourceSans = Font.fromEnum(Enum.Font.SourceSans)
	local Size = UDim2.fromOffset(46, 35)
	local PaddingData = ({ 
		PaddingBottom = UDim.new(0, 4),
		PaddingTop = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	})

	-- Functions
	local ConvertTail = function(Tail)
		if (Tail) then
			Set(Tail, {
				Size = UDim2.fromOffset(25, 10),
				ImageTransparency = 0,
				Image = "rbxassetid://89395716827984"
			})
		end
	end

	local ConvertDistantBubble = function(DistantBubble)
		local RoundedFrame = (DistantBubble and DistantBubble:FindFirstChild("RoundedFrame"))
		local Corner = (RoundedFrame and RoundedFrame:FindFirstChildOfClass("UICorner"))
		local Contents = (RoundedFrame and RoundedFrame:FindFirstChild("Contents"))
		local Padding = (Contents and Contents:FindFirstChildOfClass("UIPadding"))
		local Ellipsis = (Contents and Contents:FindFirstChildOfClass("TextLabel"))

		ConvertTail(DistantBubble:FindFirstChild("Carat"))
		Set(DistantBubble, { Size = Size }, true)
		Set(RoundedFrame, { Size = Size }, true)
		Set(Contents, { Size = Size }, true)
		Set(Corner, { CornerRadius = UDim.new(0, 5) })
		Set(Padding, PaddingData)
		Set(Ellipsis, {
			FontFace = SourceSans,
			TextSize = 22,
			TextColor3 = Color3.fromRGB(60, 68, 75),
			TextTransparency = 0,
		}, true)
	end

	local Convert = function(Object: Instance)
		if (Object.Name == "Caret") then
			ConvertTail(Object)
		elseif (Object.Name == "DistantBubble") then
			ConvertDistantBubble(Object)
		end
	end

	-- Setup
	Set(BubbleChatConfiguration, {
		FontFace = SourceSans,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(60, 68, 75),
		BackgroundTransparency = 0,
		LocalPlayerStudsOffset = Vector3.new(0, 0.4, 0),
	}, true)

	Create("UICorner", { Parent = BubbleChatConfiguration, CornerRadius = UDim.new(0, 5) })
	Create("UIPadding", PaddingData, false, BubbleChatConfiguration)

	for _, Object in next, Query(ChatBubbles, `#Caret, #DistantBubble`) do
		Convert(Object)
	end

	ChatBubbles.DescendantAdded:Connect(Convert)
end)

Run(Settings.HideDisplayName, function()
	-- Functions
	local Change = function(Player)
		local Character = (Player.Character or Player.CharacterAdded:Wait())
		local Humanoid = (Character and Character:FindFirstChildOfClass("Humanoid"))

		if (Humanoid and Humanoid.DisplayName == Player.DisplayName) then
			Humanoid.DisplayName = Player.Name
		else
			Character.ChildAdded:Connect(function(Humanoid)
				if (Humanoid:IsA("Humanoid") and Humanoid.DisplayName == Player.DisplayName) then
					Humanoid.DisplayName = Player.Name
				end
			end)
		end
	end

	local Joined = function(Player)
		Change(Player)
		Player.CharacterAdded:Connect(function()
			Change(Player)
		end)
	end

	-- Setup
	for _, Player in next, Players:GetPlayers() do
		task.spawn(Joined, Player)
	end

	Players.PlayerAdded:Connect(Joined)
end)

task.spawn(function()
	local TopBarHolder = CoreGui:WaitForChild("TopBarApp", 10)
	local TopBarApp = (TopBarHolder and TopBarHolder:WaitForChild("TopBarApp", 10))

	if (TopBarApp) then
		Force(TopBarApp, "Enabled", false)
	end
end)

task.spawn(function()
	local ClippingShield = RobloxGui:WaitForChild("SettingsClippingShield", 30)
	local SettingsShield = (ClippingShield and ClippingShield:WaitForChild("SettingsShield", 30))
	local Modal = (SettingsShield and SettingsShield:WaitForChild("Modal", 30))

	if (Modal) then
		Set(Modal, {
			Visible = false,
			Modal = false,
		}, true)
	end
end)

task.spawn(function()
	local ControlFrame = RobloxGui:WaitForChild("ControlFrame", 10)

	if (ControlFrame) then
		ControlFrame:Destroy()
	end
end)
