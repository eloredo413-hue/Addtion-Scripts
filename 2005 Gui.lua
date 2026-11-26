-- [[ ULTIMATE 2005 ROBLOX STUDIO & DYNABLOCKS OVERHAUL (EXECUTOR READY) ]]
-- (Addtion-Scripts copy of the 2005 gui gist, loaded by More guis through the loader: the Properties window and the
-- "2005 GUI SETTINGS" menu are drawn as Windows XP windows - the blue Luna title bar with rounded top corners, the
-- red close button with its white X, the blue window frame and XP buttons - see XP WINDOWS in part 11)
-- [[ ALL 86 AUTHENTIC 2005 STUDIO DECAL ASSETS CROPPED & CLEANED (NO 3-DOT BUBBLES) ]]
-- [[ TRUE 2005 STUDIO FREECAM + EDIT/RUN SIMULATION MODE + CAMERA MENU ]]
-- [[ ALL PLAYERS USE DYNABLOX-MAN (rbxassetid://14098578999) & WORK LIKE STUDIO MODELS ]]
-- [[ 2006 BITMAP FONT FOR UI & WORLD + TOP-RIGHT 2005 CONDENSED TIMER & SCORE ]]
-- [[ 2005 STUDS (3D BUMPS + 2005 STUD TEXTURES) ON WORLD BRICKS ]]
-- [[ CREATE-MODE LAYOUT MATCHES THE OCTOBER 2005 CLIENT - SEE SOURCES.md FOR EVERY REFERENCE ]]
--   * Menus File / Edit / View / Insert / Format ("Run" menu was removed in the Oct 2005 builds)
--   * Left panel: GO, Drag, Resize + Axis Drag, Rotate + Tilt, Group, UnGroup, Duplicate, Delete, MENU
--   * Bottom-left tabs Model / Surface / Color / Controller / Hopper over a 60px toolbox strip
--   * Bottom-right CameraMenu: big arrows zoom, small circle arrows tilt, side arrows pan, centre focuses
--   * Toolbox data, controllers, surfaces & colours follow the original 2005 .rbxm files (IDs 770-864)

--========================================================
-- SETTINGS
--========================================================
local Config = {
	SHOW_CHAT_BUBBLES = false,
	SHOW_DIALOG_BUBBLES = false,
	REMOVE_ALL_3DOT_BUBBLES = true,
	USE_2006_NAME_TAGS = false,
	APPLY_2006_FONT_TO_GAME_GUIS = true,
	APPLY_2006_FONT_TO_OTHER_SCRIPTS = true,
	APPLY_2006_FONT_TO_WORLD_TEXT = false,
	APPLY_2006_FONT_TO_ROBLOX_MENUS = false,
	SHOW_LOADING_SCREEN = false,
	TOPBAR_STYLE = "2005_STUDIO", -- "2005_STUDIO" (Oct 2005: "File Edit View Insert Format") or "CLASSIC_5" (2006-07 in-game bar: "Tools Insert Fullscreen Help... Exit")
	SHOW_2005_FPS = true,
	HIDE_OBSTRUCTIVE_LEFT_GAME_GUIS = true,
	DEFAULT_TIMER_SECONDS = 60.0, -- Level.InitialTimerValue (2005 default 60.0); edit it in Properties with nothing selected (0 = no time limit)
	APPLY_2005_STUDS_TO_ALL_PARTS = true,
	STUD_MODE = "2D", -- "2D" (faux-3D low-graphics style texture, zero lag) or "3D" (real 3D block bumps within STUD_3D_RANGE)
	STUD_3D_RANGE = 35, -- Safe 3D stud radius around camera when STUD_MODE == "3D"
	STUD_3D_RANGE_PRESETS = { 10, 15, 25, 35, 50, 75, 100, 150, 200, 300, 500, 1000 }, -- 12 range options (10 to 1000 studs)
	ADD_3D_2005_BUMPS_TO_BRICKS = true,
	MAX_3D_BUMPS_PER_PART = 256,
	CONVERT_ALL_PLAYERS_TO_DYNABLOX_MAN = true,
	HIDE_FORCEFIELDS_AND_PARTICLES = true, -- 2005 had no spawn ForceField bubble and no particle effects; explosions become a red sphere
	MUTE_AVATAR_SOUNDS = true, -- silence the footstep / jump / land sounds Roblox plays from every (hidden) avatar
	DYNABLOX_MAN_ASSET_ID = "rbxassetid://14098578999",
	STUDIO_FREECAM_ENABLED = true, -- True 2005 Studio FreeCam (never locked to a player!)
	FOLLOW_PLAYER_WHEN_RUNNING = false, -- Smoothly track Dynablox-man in Run (GO) mode while still allowing CameraMenu/Right-Click orbit
	FREECAM_SPEED = 38,
	ASSET_FOLDER_NAME = "2005Gui",
	SET_LIGHTING = true,
	LIGHTING_AMBIENT = Color3.fromRGB(175, 175, 175),
	LIGHTING_COLOR_SHIFT_BOTTOM = Color3.fromRGB(122, 155, 128),
	LIGHTING_BRIGHTNESS = 1.5,
}

--========================================================
-- CLEANUP PREVIOUS RUN (GETGENV + _G EXECUTOR SAFE)
--========================================================
local GENV = (type(getgenv) == "function" and getgenv()) or _G
if GENV.CustomHealthESP_Connections then
	for _, conn in pairs(GENV.CustomHealthESP_Connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
end
GENV.CustomHealthESP_Connections = {}
_G.CustomHealthESP_Connections = GENV.CustomHealthESP_Connections
local function storeConnection(conn)
	if conn then
		table.insert(GENV.CustomHealthESP_Connections, conn)
	end
	return conn
end

--========================================================
-- SERVICES & EXECUTOR SAFE REFERENCES (CLONEREF SUPPORT)
--========================================================
local function safeGetService(serviceName)
	local ok, svc = pcall(game.GetService, game, serviceName)
	if ok and svc then
		if type(cloneref) == "function" then
			local okClone, cloned = pcall(cloneref, svc)
			if okClone and cloned then
				return cloned
			end
		end
		return svc
	end
	return nil
end

local Players = safeGetService("Players")
local RunService = safeGetService("RunService")
local StarterGui = safeGetService("StarterGui")
local TextChatService = safeGetService("TextChatService")
local UserInputService = safeGetService("UserInputService")
local Workspace = safeGetService("Workspace") or workspace
local CoreGui = safeGetService("CoreGui")
local ContentProvider = safeGetService("ContentProvider")
local SoundService = safeGetService("SoundService")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
	task.wait()
	LocalPlayer = Players.LocalPlayer
end
local Camera = Workspace.CurrentCamera

-- Shared state table to keep top-level local variable count low for all executors
local S = {
	isSimulationRunning = false,
	currentStudioTool = "Select", -- "Select" (Drag), "Resize", "Move" (Axis Drag) or "Surface" (a Surface toolbox tool)
	activeTab = "Model",
	selectedObject = nil,
	isDraggingObject = false,
	savedTransforms = {},
	-- 2005 "Level" properties (shown in Properties when nothing is selected)
	level = {
		WinMessage = "You Won!",
		LoseMessage = "You Lost. Try Again",
		InitialTimerValue = Config.DEFAULT_TIMER_SECONDS,
		InitialScoreValue = 0,
		TimerUpAction = "Lose", -- "Nothing", "Pause", "Lose", "Draw", "Win"
		TimerAffectsScore = "NoChange", -- "NoChange", "Increase", "Decrease"
		HighScoreIsGood = true,
	},
	currentTimerValue = Config.DEFAULT_TIMER_SECONDS,
	bonusScore = 0,
	leaderstatsScore = 0,
	bottomScrollIndex = 1,
	showAllModelsMode = false,
	currentSurfaceTool = nil, -- record from the Surface toolbox page; applied to the clicked face
	studMode = Config.STUD_MODE or "2D",
	stud3DRange = Config.STUD_3D_RANGE or 25,
	stud3DRangeIdx = 2,
	currentBrickColorToApply = Color3.fromRGB(255, 255, 255),
	currentControllerToApply = "KeyboardRight",
	levelHopperBins = {}, -- HopperBin.BinType -> true when the level grants it
	activeHopperBin = nil,
	bumpLocalCF = {},
	-- 2005 Studio FreeCam state
	freeCamEnabled = Config.STUDIO_FREECAM_ENABLED,
	followInRun = Config.FOLLOW_PLAYER_WHEN_RUNNING,
	camPos = Vector3.new(0, 28, 42),
	camYaw = 0,
	camPitch = math.rad(-25),
	camDistance = 28,
	isRightMouseDown = false,
	lastMousePos = Vector2.zero,
	keysDown = {},
	camHoldDir = { Up = false, Down = false, Left = false, Right = false, ZoomIn = false, ZoomOut = false },
	rigRegistry = {},
}

--========================================================
-- DISABLE DEFAULT ROBLOX UI & THREE-DOT BUBBLES
--========================================================
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
end)
if TextChatService then
	pcall(function()
		TextChatService.ChatWindowConfiguration.Enabled = false
		TextChatService.ChatInputBarConfiguration.Enabled = false
	end)
end

local function disableDefaultBubblesAnd3Dots()
	if TextChatService then
		pcall(function()
			local bubbleConfig = TextChatService:FindFirstChild("BubbleChatConfiguration")
			if bubbleConfig then
				bubbleConfig.Enabled = false
			end
		end)
	end
	if not Config.SHOW_CHAT_BUBBLES or Config.REMOVE_ALL_3DOT_BUBBLES then
		pcall(function()
			local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
			local legacyBubbles = pg and pg:FindFirstChild("BubbleChat")
			if legacyBubbles and legacyBubbles:IsA("ScreenGui") then
				legacyBubbles.Enabled = false
			end
		end)
		pcall(function()
			local expChat = CoreGui:FindFirstChild("ExperienceChat")
			if expChat then
				local bChat = expChat:FindFirstChild("bubbleChat", true) or expChat:FindFirstChild("BubbleChat", true)
				if bChat and bChat:IsA("GuiObject") then
					bChat.Visible = false
				elseif bChat and bChat:IsA("ScreenGui") then
					bChat.Enabled = false
				end
				for _, desc in ipairs(expChat:GetDescendants()) do
					if desc:IsA("BillboardGui") then
						desc.Enabled = false
					end
				end
			end
		end)
		pcall(function()
			local rbxGui = CoreGui:FindFirstChild("RobloxGui")
			if rbxGui then
				for _, childName in ipairs({ "VoiceChatPromptGui", "BubbleChat", "PlayerList", "TopBarApp" }) do
					local c = rbxGui:FindFirstChild(childName, true)
					if c then
						if c:IsA("ScreenGui") or c:IsA("BillboardGui") then c.Enabled = false
						elseif c:IsA("GuiObject") then c.Visible = false end
					end
				end
			end
		end)
	end
end
disableDefaultBubblesAnd3Dots()
pcall(function()
	if CoreGui:FindFirstChild("TopBarApp") and CoreGui.TopBarApp:FindFirstChild("TopBarApp") then
		CoreGui.TopBarApp.TopBarApp.Enabled = false
	end
end)

--========================================================
-- LIGHTING & 2005 SHADOWS
--========================================================
if Config.SET_LIGHTING then
	pcall(function()
		local Lighting = game:GetService("Lighting")
		local function lockLighting(property, value)
			Lighting[property] = value
			storeConnection(Lighting:GetPropertyChangedSignal(property):Connect(function()
				if Lighting[property] ~= value then
					Lighting[property] = value
				end
			end))
		end
		lockLighting("Ambient", Config.LIGHTING_AMBIENT)
		lockLighting("ColorShift_Bottom", Config.LIGHTING_COLOR_SHIFT_BOTTOM)
		lockLighting("GlobalShadows", false)
		Lighting.Brightness = Config.LIGHTING_BRIGHTNESS
	end)
end

--========================================================
-- UI PARENT & CLEANUP
--========================================================
local parentTarget = CoreGui
pcall(function()
	if type(gethui) == "function" then
		local hui = gethui()
		if hui then parentTarget = hui end
	end
end)
local function parentGui(gui)
	pcall(function()
		if type(gethui) ~= "function" then
			if type(protectgui) == "function" then
				protectgui(gui)
			elseif type(syn) == "table" and type(syn.protect_gui) == "function" then
				syn.protect_gui(gui)
			end
		end
	end)
	local success = pcall(function()
		gui.Parent = parentTarget
	end)
	if not success or not gui.Parent then
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
end
for _, container in ipairs({ parentTarget, CoreGui, LocalPlayer:FindFirstChildOfClass("PlayerGui") }) do
	pcall(function()
		if not container then return end
		for _, child in ipairs(container:GetChildren()) do
			if child.Name == "Classic2010Gui" or child.Name == "Classic2005StudioGui" or child.Name == "LoadingGui" then
				child:Destroy()
			end
		end
	end)
end

--========================================================
-- CUSTOM ASSET LOADER (ALL 86 DIRECT PNGS + SPRITESHEET + FOLDER OVERRIDES)
--========================================================
S._run = (function()
	local B64_2005_SHEET = "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"
	local B64_2005_STUD = "iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAMAAAD04JH5AAAA/1BMVEWAgID///8AAAAAAAD///////8AAAD///////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADwP+mqAAAAQHRSTlMAJFkgaYJzFUEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAj35g5wAAAMVJREFUeNrt20EOAjAMA8FSguH/L+bAGaEYi1Ri9wOee9N1HW4dALgPdgpgjQUAAAAAAAAAAADgZEDdYpmAmGC7gJBg+4DK7H8BqMj+Kw9QsX0XUKn9N4bPgMrtm4CH384ALm4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAkAJMv5zKLwKQcgIHIAUFBkBKCvoAKSpoA6SsoAuQwoImQEoL+rdkOxsAAM5BI4BxAFe1AAAAAAAAAAAAPwH8+e/7J9GiWgYVs/juAAAAAElFTkSuQmCC"
	-- Second sheet: 2005 Surface toolbox tools, CameraMenu hover/press states, Resize (ScaleTool) states and HopperBin icons
	local B64_2005_SHEET2 = "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"
	local B64_DIRECT_FILES = {
		["ArrowLeft.png"] = "iVBORw0KGgoAAAANSUhEUgAAACMAAAAjCAMAAAApB0NrAAAA/1BMVEX9/f3o6OiTSwHY2NjIyMi4uLj8xjlGSk9pRyToiADylgj3tizTeACYmZlORDanp6eqWwD2pRi4ZQE5OjxSVVlmaGqHiIqdUQA5PEJ1d3nDbAB1SBuHaTPFmjc/QkZcXmFhVjx6fICfoKGjhTzfgABDPTVfVTxfYWabfDicnqCqfi6/wMDfrzn3riEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADuiVo6AAAAQHRSTlP/////////////////////////////////////////////////////////////AAAAAAAAAAAAAAAAAAAAAAAAtbczaQAAATRJREFUeNrd0+lygjAUhmGysWUDwiZq1dbu7f3fXk8SmBFJvICevz7zvTpgkvyXY72kjwV9N0qN/QOBduP5WJcHo6PkOVMvnNelyNtYpjMHnqa8FFWeoWgmTa2ZhjwjsYwjdVFhMAgFMj+pJ5ACQ+9RP74dvQBSNBgMI2RlLuaDzwKI8IauzLf54tz+IBAlmMoavY71qqzrXy/KYjFsZS55Aec+t+eNXMc+Xxu4SYirJdegQa3CcEPVCAEzQZPQk8m9gjExBU2CZKb2VlUQBRIyCaLdkwviYcBhgxChss1cEOPYDiFU7+ZgzMAQZfI0B4NmRrr3wb3q9NZYRChjNgjXSn3/4D1yU6zv2raTWtPtW7ZM2S0QLhV+p32Qacbo9uvcBGHLXmRmmXIXJ37L3eP//K34AycdFFkJOG3eAAAAAElFTkSuQmCC",
		["ArrowRight.png"] = "iVBORw0KGgoAAAANSUhEUgAAACMAAAAjCAMAAAApB0NrAAAA/1BMVEX9/f3zmAqTSwHo6OiXmJnX19fHx8foiQJNQjSnp6i3t7fReAJERkmHh4f5uCz2pBenWgFRVFh2d3i1ZgT7xDg9PDtGPjRnaGp5SRZnRiXsqSY9QkidUwE5PUNcXmJsUzDEbgDXhw9eUzx+f4CCWyaMYiaWczKcnaCvchrMnTXWqDn+sh8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAZe4rVAAAAQHRSTlP//////////////////////////////////////////////////////////wAAAAAAAAAAAAAAAAAAAAAAAAAAzFu39AAAASlJREFUeNrV1Md6hCAABGCRXkTFtrrJZje9vP/7BbBlFbxnrv7fDAcwSf51IM8+8DEhZcuYQvCopXz+1sN7U4q44c1XXeuf29OjITGD2KAtysEnO8cGJzMAQN9ig4gBrWttiwCQkUFrcm2JM4BWwUHEaJ6PwiH52pQkYMBCrJEFUyRkwGqqIm27gBk/A0qpLNI0PW2LZkOd8MQaETE36XZcekUgDBi6iLRvXjC+Q6Oh8lo8eHFiquNka6Q7yVzCVGk4Fxb9Na2U12VGqS5DaG+qacXNlCbLPNmYSbiZLsvmGnh3x9YZ4wjf1SRQsXHmYqaSHbFF57YfD+KELdkM+Qhz6Qxy4VNJ4MpCQgTnqwgRiIkQXkRKHMKY+ESFLxoDYfy1wjnH/4UQ+AX4+BM1wNYp3QAAAABJRU5ErkJggg==",
		["ArrowTool.png"] = "iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAMAAAAp4XiDAAAA/1BMVEWRkZEAAADl5eWXl5fY2Ni2trampqYAAP/GxsaIiIhYWFhmZmZ3d3cBAQEBAQEtLS0ICAgSEhJJSUkpKSnLy8sqKio1NTW2trbFxcUKCgoNDQ0ZGRk2Nja5ubm2trbKysrR0dFKSkobGxsbGxsmJiYhISEnJyc5OTk5OTlZWVlwcHCNjY2KioqdnZ2VlZWtra2pqammpqanp6eysrK0tLSwsLDBwcHJycnQ0NDQ0NDS0tLQ0NAxMTFAQEBSUlKPj48AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABNybJCAAAAQHRSTlNvAP7+/vz9//z4+v38K1RDb7b6yabz+ScYkKPMN5iqV5AQL3A8YaOStMDfBjGs1QU2itETbs2J2RI0aaFBLARsowHLXQAAAjdJREFUeNrV1tli2yAQBVDXwyBAoNgkkrfYcfZ935O2+f+/6siVBUioad+a+2bQscU2uPftn9P7OuTl9W25fN+ivC+Xb68vn5LxztazQA6rcBTPWzvjPxICAkGndTSgaKKAjJ8QpVISWX8V9vsTPo27yGiOkCpePV8prlLA+ShORgv6Uin6jQhqxMUoRkYLLhXvR8KV5J6pyf0cZYr9aDCVOL9vkusHGkeHKA3gw3WD3Dxyzfudoc7Hm5Cc33IpWTdhUvLb84Bc3HHt5ipiheZ3Fz7Z/aAt4vqTyKBA8t5Pn1yCvyBJxAgNl7se+XEF/kiSiGESrrY9sk2jC0nLMJCyRVySlWFBBE3pd49sEBENkmD9uyuCUm6EBLmok1RGVI8zasMYwToVSeqXRRS8RQDBZU0SEPR01YPwKcmLwqbSNf4FKVKtPdEiukFyMikEoTLik4MzQO6S5DZNEjqLfhDODjyyd0rr4nqt1eXLaV/QUp7u+Zv/WINwk6ypEJFR4JpQgD4OzsthWbzqpcRqPaVb3bKkHQbEnKQgwk1FC6rZevmZgPTEhGd/3+rGPmRcy3rHMNR2v1EuzFG76gnh178j06xj2aYC0VUtBKjNrFX6zKDblGJg2gW2NDJq6K084ZdxMlbzVkGiabC+CC4LMxjm7nJxV0w+9EV4JZlsMitos+D6MNJWtMVskpnui89kg+ksL6xS5a2nlC3y2XQQitb1SmgyHdaZTpogdokbk3kx5iv/IflPyC+/eC/AW3p+QwAAAABJRU5ErkJggg==",
		["ArrowTool_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAMAAAAp4XiDAAAA/1BMVEUMWFhkZGRY29up1taN0NAEISEcYWEEsbELmpon7e2No6MAaWkA19d74+M4PT0A29sAAADl5eUA/v6Xl5fY2Ni1trampqYAAP/Hx8eIiIgB+/sA/v5YWFhmZmZ3d3cA//8A//8A//8A//8SEhJJSUkAAQEB6OgGBwcA//8pKSkqKio1NTWuxsYKCgoNDQ0ZGRkddHQy7Owx8/MKGBgOnZ0NpKQPvLwG09MtLS1L5uZvxMQAXFwAysoA19cnJyc5OTkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACKR7pgAAAAQHRSTlNfz8ut4l6QVpHa1ylrvZOiAP79/v79/f/9+NG0+v38DJE1T7b6WbBvacnz+fGQo8xb2NttbnOEmkTR0mGJa6O0005csgAAAtdJREFUeNqdlnl7ojAQxrFra8/d1TAhQQhqKVTw6N3t/f2/VScJhHDVZ33/M+Fn5spMnL//Lae9FC1mU9+fTHx/OptHu5FoMZ3UNFvsQBb+pCV//gMyL4C7g4tfqIuXO/17Ou9DZvr74QooUaKwGmrquhOJlBO3KyAiNBIEVifKpaiNRMqoFfAg4OCOlVz9a6iMi5qIOuMWSBjQ4vuCokFIQB40ayLSjwP8U87GDTFchBfLnwJZSILygI47RANOJTO3kbmyiocw7hSEHKQ/kYWgIz760UNIhoBxxynNGlJBx73CzdfSNIVgfG8p524/4nJOZaRLRHpySkUVqw6W6WOiAsEAn2CJVPteh1OEU18H2tF2vRI7IV4HwwQ50JY5hV3E9sTrYFxOTrVliFxPJgl6V0dajEs4R3MWCsGkPEmkkqcYtyaGIX1WqdHIAyKsgXhgzlUIcP5UInjcDedAmZFXMKz43MU1QORR+Y8IOvVPImBUIJ4xFoBRRG6wriqEAKlUIh5h+HWxA4Q7O5Asz+OQV4uImFOUL20kD4WwCIkYX2TERAPJkAlJTdhGnqwgjwYEaCUvi0PPw7toC8jA5EVmf4B5qXbjWEjjhE1gKgcm+7LGfgvCqiALjmHCY0i1BIyII1Nj0v9j2bxMKqHIJ6+yK1vasalkeV+Sr5CwelFhQoVbpt9lJPyy7ou07CgWjTp0qeCmYlwQ8ZF1K6VlyWe76zFm979P37r7qsM4y4Cwvm7BSLA8rnUY1cfu+xlJHNb7mPImSZcdHbmwannvN7qlMu09XcaCthoShiFepn+aPVl3/vf0MquGSzVissv0ud359XxJrtbbHIsFysuIpRjn2/V90jVf9BTz39LNNsvjIJBTLwjiPNtuUsfvnGLlrEycdL25NNqs07ekb1aaiZw8HF4ZHT4mP0xka+5PP85HZ2ejj/Pprrm/z+tirzfMPi+l/d5ju/QNVLnHYzsnyYgAAAAASUVORK5CYII=",
		["ArrowTool_ds.png"] = "iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAMAAAAp4XiDAAAA/1BMVEUAAADl5eWXl5fY2Ni2trZLS0umpqbGxsaIiIhYWFhmZmZ3d3cBAQEBAQEtLS0ICAgSEhIpKSnLy8sqKio1NTW2trbFxcUKCgoNDQ0ZGRk2Nja5ubm2trbKysrR0dFKSkobGxsbGxsmJiYhISEnJyc5OTk5OTlZWVlwcHCNjY2KioqdnZ2VlZWtra2pqammpqanp6eysrK0tLSwsLDBwcHJycnQ0NDQ0NDS0tLQ0NAxMTFAQEBSUlKPj4+RkZEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA7/tlqAAAAQHRSTlMA/v7+/P79/Pj6/fwrVENvtsmm8/knGJCjzDeYqleQEC9wPGGjkrTA3wYxrNUFNorRE27NidkSNGmhQSwEbG8A5uj/mQAAAiFJREFUeNrt1dl24jAMBmAiy7ZsJ4WSUKC0dN/3vZ3t/R9rlDTEzlbmnLmbM/8djj8wkS0PBv9yXt/el8uPMedjuXx/e10LtnbHLxoVFFGoX8a7W+uARnC2igPUX6KtZ0QyhlBERcTnJ3zuNZMFgjWqnF8qZSzgYtIjdvhLSUeNaB7EnUm3UGRU1BFlSHWZhwWSxagzaAkXD01x88j/o0fkBvDxpkFun5RTke5D/PDpti4u7hSRiLTuIYJI3V3UyOW9cn66aBvt1P1lKPZ+8hbxz2XH+oDUrx8huYKwILLDaAdXewH5fg0kQtI2guB6OyDb/O/qpGUEELWIjyyMqEXzK/0WkA0mukEkVr9bECTaqBNUuoosjS6nCx7DLoJVSiKrxSJq1SKA4LMiEjTPLp8grCVplklLfvAPSGadC0SLuAZJ2ViohdtISA7PAZUPCysln8UwCOeHAdk/47oERLp8cS4UXMqz/XArnzjQ/iU7bkRsDPgh1OBOauflKG9eVSmxrCf56uYt7ahG4lMLur6puKBOrMovNNjTuH6SD6Rr7EOhHFU7RqCTB412ER+3u17QCbj/HcfNrpRsGuhrFpEGs5m0Wl887De5GMaDTkOdhlfVKQrD1Ws1JH4NskfkZpT6y8VfMemoT7BJpvOMNwuuDiNvRZnNp0ncf43FyXA2TzNpTH7rGSOzdD4bfiU+0XQ2qjKbrgMFipMgcTz4n7/Nb5yFJT9Bd9ZXAAAAAElFTkSuQmCC",
		["ArrowTool_ovr.png"] = "iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAMAAAAp4XiDAAAA/1BMVEWRkZEAAADl5eWXl5fY2Ni2trampqYA///GxsaIiIhYWFhmZmZ3d3cBAQEBAQEtLS0ICAgSEhJJSUkpKSnLy8sqKio1NTW2trbFxcUKCgoNDQ0ZGRk2Nja5ubm2trbKysrR0dFKSkobGxsbGxsmJiYhISEnJyc5OTk5OTlZWVlwcHCNjY2KioqdnZ2VlZWtra2pqammpqanp6eysrK0tLSwsLDBwcHJycnQ0NDQ0NDS0tLQ0NAxMTFAQEBSUlKPj48AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACmNjX1AAAAQHRSTlNvAP7+/vz9//z4+v38K1RDb7b6yabz+ScYkKPMN5iqV5AQL3A8YaOStMDfBjGs1QU2itETbs2J2RI0aaFBLARsowHLXQAAAjdJREFUeNrV1tli2yAQBVDXwyBAoNgkkrfYcfZ935O2+f+/6siVBUioad+a+2bQscU2uPftn9P7OuTl9W25fN+ivC+Xb68vn5LxztazQA6rcBTPWzvjPxICAkGndTSgaKKAjJ8QpVISWX8V9vsTPo27yGiOkCpePV8prlLA+ShORgv6Uin6jQhqxMUoRkYLLhXvR8KV5J6pyf0cZYr9aDCVOL9vkusHGkeHKA3gw3WD3Dxyzfudoc7Hm5Cc33IpWTdhUvLb84Bc3HHt5ipiheZ3Fz7Z/aAt4vqTyKBA8t5Pn1yCvyBJxAgNl7se+XEF/kiSiGESrrY9sk2jC0nLMJCyRVySlWFBBE3pd49sEBENkmD9uyuCUm6EBLmok1RGVI8zasMYwToVSeqXRRS8RQDBZU0SEPR01YPwKcmLwqbSNf4FKVKtPdEiukFyMikEoTLik4MzQO6S5DZNEjqLfhDODjyyd0rr4nqt1eXLaV/QUp7u+Zv/WINwk6ypEJFR4JpQgD4OzsthWbzqpcRqPaVb3bKkHQbEnKQgwk1FC6rZevmZgPTEhGd/3+rGPmRcy3rHMNR2v1EuzFG76gnh178j06xj2aYC0VUtBKjNrFX6zKDblGJg2gW2NDJq6K084ZdxMlbzVkGiabC+CC4LMxjm7nJxV0w+9EV4JZlsMitos+D6MNJWtMVskpnui89kg+ksL6xS5a2nlC3y2XQQitb1SmgyHdaZTpogdokbk3kx5iv/IflPyC+/eC/AW3p+QwAAAABJRU5ErkJggg==",
		["CamDown.png"] = "iVBORw0KGgoAAAANSUhEUgAAACYAAAAcCAMAAAA6Aj1XAAAA/1BMVEUAAAD7+/unpqYWFRZmZ2fT1dXn6eq2t7dIR0eZmZoqKio6Ojpyc3SRlJQlJSVLTExZWlplZmd0dniFiYpVVVVXV1ducXKlqqw1NTVFRUV9gYJ+gYGGiYmMlZajp6jFysve4+VsbXBydXifoJ+ZoaOeoaTEy84gHx8/Pz9APz9OUFBcXFxdX2BfYGJia2tmZmhqcnN/g4SEiYqEiImmnp6hn6SloZ+utLqytLm9xci3w8IAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAa8VX+AAAAQHRSTlMA/v0L8/z8/XHyL1Dt2hiPzdLN0I+umtE4WNjw9JC0+fOlr/G88dUcYVhL5uj/QoVPqHi8//v/ucPV5AAAAAAAFLWVSQAAASdJREFUeNqd1NeWgyAUBdBQRBCsWGNNnd77/P+HjZhMokbNWjnP23NFwNnssiBk8Ng4g3ggRJoJ10eTVammEUKq7ZJOsaQEu/y41kSZBP+RE3X098C2eHQZKATHZPaY4kWLfdsji7WeSIuRRTJSFoF2IjpYhxLSYZUfD9a9gm6im6E6q+oxctsZZjQPoRz0U6AWMB5e8ufH/AucpizW0Tp0sfqESDBdA2MpN2zpccUwYwxqZAhp+gc0F/fNcAdLCN/1U6jpEDIpgqvmFWOKhQkh7EGFNm+eww9rpRh75qoDFYKm53S2wvIVPDY2iM1du384FZR7uEfYNwa2oR7thpLV4rMeNxcOHzlJiDpBqNzKw5hO3K0auhlL8d01OnObDTuwObrwX/AHm7MQ+XZFoEAAAAAASUVORK5CYII=",
		["CamUp.png"] = "iVBORw0KGgoAAAANSUhEUgAAACYAAAAcCAMAAAA6Aj1XAAAA/1BMVEXg4d8AAAD5+vqYmpoXFxeop6jk5uRnaWvS2NhISEg3NjYpKCgjIyOQl5jJy8tUVVVZWlphY2NnaGg8PDxzdXXe4eExMjFxc3SIi42cnqGstLTCyslHR0ZOUFBXWFh1e3uIjI2doaGhnZ2gnqEvLy5APz9CRERHSEhWWFljZWa+w8Te4N8fHx88PDw+QEBaX2BdX2BeYGJeYWJqbGx5fH1xdXZ4foB9f4F+gICDhomQlZexu8DCvLrKxb/a3+Dg3uAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADNMWHgAAAAQHRSTlP/AP70DP798fVuTTEXzu+QsbHRaPb+M9bp8urbjnXPi7H7/flFYk609pPV/iOATs/oq9xhe6jR+9zaqOv///n/i6agOgAAAVhJREFUeNqNlIdugzAQhik+jM+YPQJkkN2k6d677/9WdSCD2eYTltDpk8/cb6GcnYTSLEEk/teAO8EdF39rgB6xmDXGmljRYOGSvrrlIrNRtGuw8MxCysWxi0aLxmU7tUzf7CFUNeCuyahahVoHUSmkXsLUFigzXb7TDN+JPxhjlNIN3e9IC0KWvp7DVoPR6uY5JoRMZ9pMm37l1ifJmcoV30tP7uY7T28x0SSJrBafYcm3iXwmRCPrq7zpwLHxGhGHiM7tS9GVBnoQuI5tD23b9nMN4DAU4aW7s5m4FPs61MOC9fdOY0vRnWn0fpjFI3RnOjxOj0WdGh+XRvvQpYFbDrUfdWg+qaSaifaL5FVztRDaNCRhNXcTWzTQU5n+D2ObkLKQKTRMA6PtWppajWDQ1AZuRkokM5L0Rk1N90Z6DWcFzabc9/mcc8OYy2VcGgDHS6Gc9nP4BeBgGD32yh56AAAAAElFTkSuQmCC",
		["CamZoomIn.png"] = "iVBORw0KGgoAAAANSUhEUgAAABYAAAAWCAMAAADzapwJAAAA/1BMVEUAAAD1+PhFRkY3ODjl6utSVVQWFhYqKiqnqqyzuLfFyczO1dXc5OZkaGqdpaajqaoZGRkSFxk2NjYyMTI+QkNIR0dyeHiXnJu1vMEqKio4Nzc2NjZFRUWCh4cbGxssLCwuLS04ODheZWZ5e3h+hIiepaS1w8bU3eEmJiYvLi45OTk7PkA9QT9APz9AQD9PTU16gXyXlZGapaels7O8wL7Ezc7f8PAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABlOm9PAAAAQHRSTlMA/vn6/fQL8u/39/b79e/QLP0yS/yq1+7ySJWq2vBEJ6p08fj0tO79GHTH//+M5Jv31drT/dX/AAAAAAAAAAAAD5LALAAAAPxJREFUeNqFkcl2wjAMRSPJip3ETkhCBoYABQqd5/b/P60emsJpF7yNda6lZ0uKoguarFaTf2wjyUpuzm/iBd2bvO/VjnFxokTbgwZxFDod8Cn+wUvaC4DUcC+EyHEZ6BW1jk7LkhIQ0OGtt0D2FLmUjgtDzqYmBZAhvedly5ZDTjPnwRmA4revXHYKO1fofjNnDWBroZCvwoWfeGfxI9psp2up/Jnh3OIZJiMOQUIOr3EIuKCQ/eKfjBDTc/yB6PusH4wOuHDOW6zH5nfCtpdyb6nBZhwVEyca9OGYdTxt4t8RNki8H1rb5egQVDXo9XzzZz/xuqqq+MJivwEFGQ3Sqq+NawAAAABJRU5ErkJggg==",
		["CamZoomOut.png"] = "iVBORw0KGgoAAAANSUhEUgAAABYAAAAWCAMAAADzapwJAAAA/1BMVEUAAAD2+PhFSUpSVlbc5efk6eo5OzzS1teaoqMlJSUkJSUqKipvdHaFioqvt7k9QUOUmZmlq65WVlYYGBgYGBi6wsTCys3W3uEtLi01NjaNk5MQEBA2NzZFRUVbZF1eZmlobW6PlpqPkpWXnaKhqa0wMDA2NTU3PkJAPz9BQUB8foB+goKEj5OVnqCdo6WpsLKyuboAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACrJbqAAAAAQHRSTlMA/vr2+fr4+PA6jm369/L7zvPOIEzz8Puwk/cUx5r+/eWbuLPSea//nXzT/9Xpt7neAAAAAAAAAAAAAAAAAAAAAnp8bQAAAOBJREFUeNqdkdlygzAMRdFmm+IFQ4CENE2678v/f10NbofwGr3IOnPnjqxbFJfUfnOVarNfwXaL1hgTHT21C62U7Vi470Q7rBb6JiDgmxEA4j8v1UnSDF9NPTWD5YwV6mmE24zFqiwe4Rwnm0m+wz7je7qbu6Zdwi80rPFwc53wgbI1PFA24Rm/ok/P7z5hA9wNfyYlOoCfQ2Mi1oMlDzHMGyJpEUNo8XREw/qo8nfQauEPfFYKa2aXxUXxiC7pP4MKhnkMy1HCu9bijefequr8sOSi77zDbbvOIcdwUYTFL9VLDEwzsn9pAAAAAElFTkSuQmCC",
		["CameraCenter.png"] = "iVBORw0KGgoAAAANSUhEUgAAACAAAAASCAMAAAANFixgAAAA/1BMVEUAAAD7+/pHSEgyNDVRUlTm5eTZ19ZFRUUXFxcjIyOGh4YnJyaVlpWrqai1s7MpLS4+QEBoaWvKx8UxMjJ6eXkqKioyMjI4ODni3dvi4d4qKissLi45OTk1NTZNTU0gIB8tLzE+PEI9QT5AQz9CQkJfXWNhXWJ4doCCgH+foKSgn5/Cu7bDwb7d3eAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABm7M7+AAAAQHRSTlMA/vv9/f79Twka+yf9/v3+//79sv5FT8j6/Y6nMpRkGMr7/fma///v//3/9///AAAAAAAAAAAAAAAAAAAAAAAAZY7s5wAAAOlJREFUeNqNkumWwiAMhTUpCDFQi2jbcZnF2Zf3f73B0GI9Mz/8zuEQyAXChdnsFkzC2mXCpk7avbXGjPnDA/5Lu95I/q4GqKZAbgCIsskOv3RGjfRKxlQvZQfoXBNj/J5f4CYRHMoZu6ojIOYwEXjm+OhdvT1fYV2pDyopVYI37wfBq1I/47R2Raq1xyx4UbqsC/5KsMlH9EzzP+gm1TAIOk5F0rRIR9zAILBtpV0kuhJ8Rnqn4MQH00I4u9KrKWIUZ6MO+ATC6LTYnDghisA8yzC9zip1q0xesh1e2+4XhePxEu/NDX/lF6RxDoZYPovNAAAAAElFTkSuQmCC",
		["CameraCenter_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAACAAAAASCAMAAAANFixgAAAA/1BMVEX66yMAAABHSEgyNDVRUlRFRUUXFxcjIyOGh4YnJyYpLS4+QEBoaWsxMjJ6eXkqKioyMjI4ODkqKissLi45OTk1NTZNTU0gIB8tLzE+PEI9QT5AQz9CQkJfXWNhXWJ4doCCgH8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC91EWZAAAAQHRSTlP+APv9/U8JGvsn/v/+sv5FT8iOpzKUZBjK+/35mv//7/8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQLDspwAAALhJREFUeNqFkgkSgjAMAGOCaShQQAHv4/+vNKSAMoLuTO9tm0kLmz9AX7HiXKo4bawcnGMehfZIi9RFacLOIyafYCyIRNwLe4IVxKd2AgLkIYTZWq4AUGknJCAoX9vDCcBXKnCRLF/wmIT7WgxAUbitC+V4hSysapB+EjTIuSOQ4yC4WoUgMheCPHXC8sA1rsYQE9XSGY0x05Zm5UJkAl9tqK+TaZNF4pYqvia7ZjvRde9+w8N/+MULzusHtp9MXtwAAAAASUVORK5CYII=",
		["CameraCenter_ds.png"] = "iVBORw0KGgoAAAANSUhEUgAAACAAAAASCAMAAAANFixgAAAA/1BMVEUBAQG7u7s4ODinp6cmJiYXFxczMzNmZmaYmJh3d3eGhoZISEgcHBxZWVkkJCQkJCQoKCgdHR0lJSUrKys5OTkeHh4hISExMTEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/YwoHAAAAQHRSTlMA/vz+/RRP/P39/f4n/K9LyUWOMmSaG5oAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA3ilviwAAAKtJREFUeNqNkgsOgyAMQJW2KwWr+Nl2/5sOgaFzmvgSfu0LkELT3ISIusg6lEZUk1PAU0I/5jyaCxDTLj06sNbCgRhi7FbhaUC8qtp2g733agWHtIMHNiyyF5yIonNVEG7/AC0CRQHgG7ayGXAquFPh8oixCPGSzPtLCrM3TrIQPDg9CikgqQ4UzE+R1sMLpVAT4mWpk0DvssI8pD4bQ3nO1/yoLMs2n+98lA8ZrQi1XRdYvgAAAABJRU5ErkJggg==",
		["CameraCenter_ovr.png"] = "iVBORw0KGgoAAAANSUhEUgAAACAAAAASCAMAAAANFixgAAAA/1BMVEUj9f8AAABHSEgyNDVRUlRFRUUXFxcjIyOGh4YnJyYpLS4+QEBoaWsxMjJ6eXkqKioyMjI4ODkqKissLi45OTk1NTZNTU0gIB8tLzE+PEI9QT5AQz9CQkJfXWNhXWJ4doCCgH8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACVl7pnAAAAQHRSTlP+APv9/U8JGvsn/v/+sv5FT8iOpzKUZBjK+/35mv//7/8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQLDspwAAALhJREFUeNqFkgkSgjAMAGOCaShQQAHv4/+vNKSAMoLuTO9tm0kLmz9AX7HiXKo4bawcnGMehfZIi9RFacLOIyafYCyIRNwLe4IVxKd2AgLkIYTZWq4AUGknJCAoX9vDCcBXKnCRLF/wmIT7WgxAUbitC+V4hSysapB+EjTIuSOQ4yC4WoUgMheCPHXC8sA1rsYQE9XSGY0x05Zm5UJkAl9tqK+TaZNF4pYqvia7ZjvRde9+w8N/+MULzusHtp9MXtwAAAAASUVORK5CYII=",
		["CameraPanLeft.png"] = "iVBORw0KGgoAAAANSUhEUgAAAB4AAAAkCAMAAACpD3pbAAAA/1BMVEWfp66go6e+x9Xe3+cAAAD6+vokJCXX2+bq6u+pqa0WFhZpamorKipjZWnJyNHV19o0NDRaWlk5OTlCQkNWV1iFiI5JSUpRU1VkZGSys7VQU1ZaWlrh3d1fYGJzdHd5fIJ9gYWSlJvDvsA2NzlMTExeYGNydXlzdnx5fYGTmKCZnaKcoKigo6a7uMLCzNIgHx8+QUVGSUxQTk5bXGBaXGFfX2BZYGdbYGZhZ2tobntwc3t+f4Z7hoqGjpSKj5SKjpQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADb9AKyAAAAQHRSTlOq6e31AP4X+f74CvYrrPb3N69MVJG3bWvU+kvH/aj5Yq/V/hmqlY+3r8716s7y2B8nPZQyXbk/WFeGWcprdZXeZ6f2cQAAAUhJREFUeNp909d2gzAMBmAyLBsLDGaF0YSMNrNJ917v/1a1Q2hDTvB/BXxHB1kIq2+M9XfFwcgQmhgmVybOu66JLTo08IxSU3VJaNTOXBCanNoAan4nhJ4cDL4nh2oOnuLBMfLnLrk+MJSkWQ2vFmE1c+hprocK+eeOKCV2xc6XUsJuOYfZQ2ntGKmSVZxX94zSGqrYXLNjkfOxHcXc9Vo40+yP2ti+URxgx1QN+FN31OiMeetAt1aMxP65N50K70LF88Q0y+z18F5zgivNbPLRsf+zWb0kkWZAV5ezHO4e5+M4jsfL+Xi5cKM02Y9FpjFVQ3VllERSusMnTBFTGfLDUNHdMsWO4wdhEPi+43N+tA4pxpTR1k11RtGWNb93Y5kKjHsGVm8Xop37EjfCsMiAC7sw7LnEt4K3M6B/aeB+aGYOgfH3P5tf5gAiDlnTdRMAAAAASUVORK5CYII=",
		["CameraPanLeft_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAAB4AAAAkCAMAAACpD3pbAAAA/1BMVEUAAAAZVfUkJCUWFhZpamoZVfUrKipjZWk0NDRaWlk5OTlCQkNWV1hJSUpRU1VkZGSEhowZVfVQU1ZaWlpfYGJzdHd5fIJ9gYUZVfU2NzlMTExeYGNydXlzdnx5fYEZVfUgHx8+QUVGSUxQTk5bXGBaXGFfX2BZYGdbYGZhZ2tobntwc3t+f4Z7hooAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADalsRFAAAAQHRSTlMA/BcK9tUrrDevTFSRbWvUtbRLx6j5Yq+WGaqVj7evdR8nPZQyXbk/WFeGWcprAAAAAAAAAAAAAAAAAAAAAAAAHHzzqwAAAQBJREFUeNqVktlygzAMAC35NibmCiRtkh5J7/b/f69gCBOYsabVm7WzlmSZsT8GRxJjRlJ5T+EKNIV30BB0D6TdAnhiKgDI18nNPOpXj1eD4U7OL9JT2Cyue5NwxdjC0saPsk/IWxmulbD6kTEB41k9xMMT57i/tOXEZlxBIniUyxRWQ2UNFDbbJH7ssROSsjGN3dBanbq9OQ84n3T5vYDyPY87RDH2XuHzy6EriqI7HbrTUfsw7tCGOLm2PvfW6uZVBCGCzfj0qKOulTIuc84YZTi/2V4QRY+TP1Vt/Xrfi6gHPY1j9TRmVpAfGcURakbpnzWndHNHYJbRmKNj/45fr9oKT4EI8lYAAAAASUVORK5CYII=",
		["CameraPanLeft_ovr.png"] = "iVBORw0KGgoAAAANSUhEUgAAAB4AAAAkCAMAAACpD3pbAAAA/1BMVEUAAAAj9f8kJCUWFhZpamoj9f8rKipjZWk0NDRaWlk5OTlCQkNWV1hJSUpRU1VkZGSEhowj9f9QU1ZaWlpfYGJzdHd5fIJ9gYU2Nzkj9f9MTExeYGNydXlzdnx5fYEgHx8+QUUj9f9GSUxQTk5bXGBaXGFfX2BZYGdbYGZhZ2tobntwc3t+f4Z7hooAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD2/v5eAAAAQHRSTlMA/BcK9tUrrDevTFSRbWvUtbRLx6j5Yq8ZlqqVj7evHyd1PZQyXbk/WFeGWcprAAAAAAAAAAAAAAAAAAAAAAAAu2Da3AAAAQBJREFUeNqVktlygzAMAC35NibmCiRtkh5J7/b/f69gCBOYsabVm7WzlmSZsT8GRxJjRlJ5T+EKNIX30BB0B6TdAnhiKgDI18nNPOpXj1eD4V7OL9JT2Cyue5NwxdjC0saPsk/IWxmulbD6kTEB41k9xcMj57i7tOXEZlxBIniUyxRWQ2UNFDbbJH7osROSsjGN3dBanbq9OQ84n3T5vYDyPY87RDH2XuHzy6EriqI7HbrTUfsw7tCGOLm2PvfW6uZVBCGCzfj0qKOulTIuc84YZTi/2V4QRY+TP1Vt/Xrfi6gHPY1j9TRmVpAfGcURakbpnzWndHNHYJbRmKNj/45fsQIKT3vehR8AAAAASUVORK5CYII=",
		["CameraPanRight.png"] = "iVBORw0KGgoAAAANSUhEUgAAAB4AAAAkCAMAAACpD3pbAAAA/1BMVEUAAAD5+vkYGBjo6emytbaqqqk2NjaUlpRlZmZ0dnMrKyvV1tZGRkYyMjJERESJi4sjIyNVVlbJyMmUlJRZWVlWWFiDhoaDhodTU1NjZWZwdHN8gH0vLzA9PT1APkBaXF5fYGF+f4CdoJqhnZu+wsTBvrrBwb1ISktLS0xOT1BPUVFqaF51dnZ+gICOkZGco6C8vsC5u8DV3+Dd4d/h4N0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABhF123AAAAQHRSTlMA/g78+PxR8/b4MPmQNm/3Gqr+1MjsucuU0a70Q2t1b/v99//1/fxWtNFK/9fgqv/I/+3z/QAAAAAAAAAAAAAAwRnJfgAAAThJREFUeNqVlNlywyAMRQMSu/FW29maPU33vf//bQWSeuqmMO19YAYOV8ICeTT6t0qaxNk0yfPHPIWXzyJl5wyrJH5TCfslI6zPbidnGInZlF+h1B0dhuJIoLfrwjxN8nKIyfvDaUWPAYxQWTnABKtjSN0RIGDYZqLDAqWLV4ehyE9uEgQ1jle2pNryvZ+jpMfcpJdL84KIECYF/4kH2ldJDIX2ZRERTMLhdAyDyry7gN/x1X0WiioYHmpjPsDL1HUd9oOQ/uhWzoTYsl67nTDBrNb+w7m8Xs3GXdddeAkhinntqKvzMhTR8qxpqkY6Tf0gW1dzQCW/3SOlmjvlllLbYDBnsYfs7hvnksZxwuywM69pHDvzIt5E7KBk/CXfiK1KtNGtmrWJNmirSieaqJ0mO5Tbv/4oPgHbWRBaw7msNAAAAABJRU5ErkJggg==",
		["CameraPanRight_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAAB4AAAAkCAMAAACpD3pbAAAA/1BMVEUAAAAZVfUYGBg2NjZlZmZ0dnMrKytGRkYyMjJEREQZVfUjIyNVVlZZWVlWWFiDhoaDhoeEh4dTU1NjZWZwdHN8gH0vLzA9PT1APkBaXF5fYGF+f4AZVfVISktLS0xOT1BPUVFqaF51dnZ+gIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACS9apkAAAAQHRSTlMA/A5R9vgwkDZv0hqqyOy5y/OU0a70Q2t1b/v9qla00Ur/1+AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAXhGewwAAAPNJREFUeNqVlOl2hCAMhU2AAAPu2tk6W/v+71iJtto5Q057f3gMnzeGSCyKfyugiG0vcv/pJXwAkOwKIMrYCPY3APh5u+te4XP4TmXuiM/JVzsBvHc+POOPZYWaFBkbfmOIc0qqOYJzR7yAuOe49Rs3qzm6gORmN2h+mlrYarfeqqW0jKKMW0ptyWLee95trOh+WG5qDutUutNDJvcpbVzpy3Fo6rreJaWCxwUfuIlO2bKMpZ7Up4uuZqo33xGR1CTvEF251v3yICc6apRw1sx4PKGEzb4QsNH5k3ydsDBGNzNUwhhUMZIwRFUvTqhyf/1RfAG9aAhTk9k8rgAAAABJRU5ErkJggg==",
		["CameraPanRight_ovr.png"] = "iVBORw0KGgoAAAANSUhEUgAAAB4AAAAkCAMAAACpD3pbAAAA/1BMVEUAAAAj9f8YGBg2NjZlZmZ0dnMrKytGRkYyMjJEREQjIyMj9f9VVlZZWVlWWFiDhoaDhoeEh4dTU1NjZWZwdHN8gH0vLzA9PT1APkBaXF5fYGF+f4Aj9f9ISktLS0xOT1BPUVFqaF51dnZ+gIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA2zvbFAAAAQHRSTlMA/A5R9vgwkDZvGtKqyOy5y/OU0a70Q2t1b/v9qla00Ur/1+AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHVRozAAAAPNJREFUeNqVlNlygzAMRZFsy0vMDlmbpMv//2OxoIVmYk16HxjkwxWysCiKfyugiG0vcv/lJXwEkOwKIMrYCPY9APy+3XXP8CX8pDLviI/JVzsBvHU+POLPZYWaFBkb/mKIc0qqOYJLR7yAeOC49Rs3qzm5gORmN2h+mlrYarfeqqW0jKKMW0ptyWLee95trOj+sNzUHNapdKeHTO5z2rjS19PQ1HW9S0oFjws+chOdsmUZSz2pTxddzVRvviMiqUneIbpyrfvpQU501CjhrJnxeEYJm0MhYKPzJ/k2YWGM7maohDGoYiRhiKpenFDlXv1RfAO05ghTXZ0C3AAAAABJRU5ErkJggg==",
		["Card.png"] = "iVBORw0KGgoAAAANSUhEUgAAADwAAAA8CAMAAAANIilAAAAA/1BMVEWcqVqxsbGmoZ+ioqLMzMwdHRcqKirJycnPz89fYV/CwsIeHh50dCRISEiqxCjU2lLMyo11llg0NDTT1DSCfoCLqCSioqKCfX8AAADr60/o6DHx8Ynu7mibmxHw8HinpxKOiYzLzBfk5BkBAQCZlZe4uhVWWFd3dnYBAQEAAAASEhIsLCzU1oZlaGepqKi1tbXo6YY4OBHZ2RkICAgnJye3torMzMxcaWLS2W1JSUm1tbW4ykoLCwsNDQ0yMjJWVgoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADdedNpAAAAQHRSTlP6neUiXek2HJTl72f/Ff35+fen/v/+bf8B/v7+/v/+/vr+/v/+/vf9Uiu2Q/r9/ff9//5uxfyl/vz2JfmSpPP/UHs24QAAA0hJREFUeNq1l4tyojAUQANKrdWK7xWNC7iBmIpBeXTx/f9/tTeAFYR2nSk94yiT5JDciLlXNPkGqKSt0ajXn4H3GHFVrzcaPy6D+P7y8uJyTlI4d6HhHW7wtZyYLqF0vV7/TYFLSolb4lcmNxrPrusaRrPZ6yHH2Ww2sxm8OQ7q9ZpNw4DO51zsGXkvSS4ha9tG0axAhGx7TYgrSfvK5b0ES7btXlSixnrUs21Yesa+yvu9xA3DRmgz+5QNQrZhcGm/r1CuQbywyweMfwNlpmjH+AC7DnHXMnKtNnZdskbod0q5K0BoTVx3XKtlZJlzinBMiZ82Jf2Ici5XJEPAsFlIxbhUz6kYq0hsWhx2LMsyp/SANe1Oz3DtgTEHSrksVyC/vo45NxDSBBjf/AjFZEzhAggZnI9fE1kiZHg4aCnpMIT+JGyjKGsCh8MvQqQqZJkQNJ1qN8RIRQGxvRVv7awJDAY9QuQnIT89GfA95WQRl5hzi5OPfJfmeT1QKpJHi8V0mr0B2m637bZWkMUozxuB0hLyaiVk05ym5CZpxzFnRIFpdkBZfciWrk/zJFsjdm0wuOuyLKs6uTOfm4tpAbHqy32jp+v5ZZvz+VzXdcs0vcUV2BjxkNwaPNOESXUdJqpKJgSWXeRygUVfyno6hHzIsvyZrMxL6chyJTKFZUPAcxHNXC+R9ZwJQ2HZdJU8nk34VYmNuKfdvrT1EiwLEdJMn23InrJp6g9jmjLk4e/Lk0kfEr+qWgW2cBSMRsV2VYXSoZ+eni1InWG4MD/wkg8hwwNxzyIMIRW3qpBZvw9JP7o9hylC1vX7Vi+C8qHfZ9dc1WrtKA3V6UOoIaW7VmtSicxYH8LuwkETnzVamaNdz4guBNxnLFMZLIPAJt2u9l8ch9hBsMyVFd+Sme+DTRzIDPhToMsh4Po+y1dDjIENcXfLMyxkSnh1RbyBz1ihiAM7EJvuOMWSRrQ4jtjmILhOW50s4n5TFHs4DKHgzdckUPqGw6GtKG9+xs2VzIwtj0flfN5RKAjikhnjpGRGiO7OZ+V4XDI2+QEZ9OXSP50UcQMbSuQYuBCicjr5yyX7+g+K8I+n01uO0+lYMCuXk9gLMPbgn7KH+QeMcZXWzOVWywAAAABJRU5ErkJggg==",
		["Card_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAADwAAAA8CAMAAAANIilAAAAA/1BMVEWfpZ2xsSRdYFnl5ZdjYzixsVvZ2SrNzc2pqakRERHp6NWxsbEaGhrFxE7MzMwqKiqywrrJycl7johISEgxMTF0hmtMTEyioqLAv1bCu8G/wcEAAADp6OmamhLp6U3m5jLr626mphTX11EoKCfMzBjj4xpXV1V5eU3+/vymplOyua/Nyss4ODHX13DV1dKHh1CWlS0BAQGYmGYAAABWVjrGxmi2tm2VlFDIxzPo6IKVl5Tw8HqJiSssLCxnZziKimkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACPxCGrAAAAQHRSTlP3//P+/v//nSRr/J2b/102/hz9FcL+v23///8B/v////////7///X+///8+f7//f3/Uv4r/////v///P//Q//8YEL1WgAAA9dJREFUeNq1l3F3mjwUxkMgvoJQK7XtNlmrtiMDFbSgWEbl+3+r97kBLei2s7Oy5w8PhPxy75OQcGWTD4j9pG00urr6r6Wrq9Hon8MEWlHktRRFFg3we5jIxcLzFotrKFSiq6rtgu8MHo0U6bGQsZxzf7l8eloufc5zhiZP8S3vDbg/GAD9zBjjhDW1XHI0fwY+GPQ7h/sDzDGRvO5v1KpH4sRj3hv0Ee73B+TWdQldpimXMn5RiqXkaUoDcNcl54N+v0MYfilnV+XryywTu912tdL11Wq724ksk2run1zK/OSbVWHvsUah65JTKbPdFuDqtRYut9tdJiW5d90QK3ZfBa9hpGPlKl8ZBEROXxuaEh8EUmWfW7DXEQzDNFlY3TSOA6Q8VXrVlV6rO6QexHFKK06TpmwrWK0fR9hYha16T3/Uqm9V8BjBuXofOoBvbu4pabZMpQwc5xxt4o4TSJkuGSV+f1PB5Jhz44DVnc/n06N0C9L1H6cGPMSKHwzOyXUXcOh514ZBhp35/AGq0v5eqyKpfT53yLZhXHteOCR4OMSBxQwEFhT4oZaug6t/jm0UWiC04eJY6wKGg1t6tRznhBIMxw9tGDhNeJreAjEJfnuj+UrTItjve4+Pjw9NEXy6wcPefh8UhwPN2Ns7fDistQquVfWnwIqqBVhbdwr7h0PRhpVU1s2GGvbPIxtrTZtpWu/bUehLs/V4aug9P2uatjZ+kvbfwxJHbKFpX1sKgu/W1zNpWoGusgXfElwU7Y5CXMLohK633cFMyqJYr89TFEJdzFpwISU7wsMhdlWIg7WCZ+8SQtdnTeHxel3gcA7fdxXGiSp43epL22LW1rqCaSt9HJ5MbHWiScBaSwRrZwIs1Xlp16enmeeerstYwfvnX2qv4FjqupfnZhdwcnf3BSbiLCO4B+FV/NYWtRKcZTGm6MvdXXL8Vpkms6yoxLcG8F7h7d2lUGwoDV+cMrIsZpqTTuAksWE7jOMsCISDo6xxENYHHw4vRwRBFschDNtJ0qgMNihXvDCE7UCIT4puy/kkRADDYYjPKd+0yooPwYlp+pjFsCyROcoR0qqWutlRzmWJl5r5ppm0q6EkMTn5Dl/i+AXVzK4egTiSoPaQ/HIzSS6KONCcLxYLxkoUUEJUIxAnBBpKxvAQXY5hu4PJ99j3c8/TWVmWqoBTGMCyZLrn5b4/Nhtsq2ROko1t+77PFlFEVXOpRPVyFC0YHtj2Jkkm/wAGvtmYts1Rn7McEAsxBl2hcue2bW42ye//oCh+POZ+Q3w8viQ7hyvvF0qSP/xT9sf6H2a/pMayILO9AAAAAElFTkSuQmCC",
		["Card_ovr.png"] = "iVBORw0KGgoAAAANSUhEUgAAADwAAAA8CAMAAAANIilAAAAA/1BMVEUaGhqioqLT3WMqKiphYWGqqqqRmpXd29weHh7J0o1ISEi2zCqt4la04J3H1CPQ0NDS0tLLy8tMTEyioqLCu8G7u1G/wcEAAADr61Dx8Yro6DHp6Ont7mibmxHw8HinpxLMzBfj4xn+/vq5uRRWVlbMyssBAQEAAADy86ksLCyruLDW1tbN6Y/t7bLr6seYmJgICAiop6jMzMz29s5HR0ezwbrt7ZW1tbW6urq1tbXJycnR0dHY2BcxMTGLi4vExMQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADDdG1OAAAAQHRSTlObIv029KHw+Wf+Ff/+/f0jaZm/bf///wH+/v7+/v/+/v/+//7z+VIr/UP7+/z9//tu/qX/2P7+JZnVVZL+wv0Wg71ZggAAAy9JREFUeNq1l4lyqjAUQBFxa91tX4GgYFmSYmSpPlDr8v9/9W4CVBDa50zpmVGYJAdyE5NchZcfIFSUjUbj8cfHx+SdM4Hb8Xg0+nX5cji8d1YrVGC16rwfDpfvZWbaNkK2/RdwOewuKSv5tcmXy4S1QqE7GESKQhQOXKLBwA0R8yeXS7Uc73agPrXbVKmAtttPoO92ce1y3IIxDsOB8iWDMIRxb8UlOY5bEFSbUuUbKGWRt+K4Rrmx262Q69IFp0pMaqjrotVu18jJjcYM5silqVtlZzWUujBjs0YjJ+8R6lCNU+GnRUk97SC0r0lutNhg9bSMG72gAj02aK1GJu/3MH+aJss3eo6shrWB38N+X4P88DCDflAqM7Rc3xUC8F5fS3kjSkGYPSQyi1gU5ZS0GSGvKZ9y1kIUWdR1yC4MtarKV1hL7vEHEJI3AVWFAXebTG42YcMaFGRA4bLGLptNsUpeLvuwrdUhQwT95VJV8w9YbDYbQuSSzFodjyCjLpPf3uDu0TDUlMJLCI85JzIM4xGUt6us62qRpD3r+9VKMc0aZWM+N5ZqCRYyuS086npJnuu6bhrGcZkB7diL1c+Co2GYpqnr8KL65Md5Bb3e66soVtUUu93/Qt7MK+nXJ4sQ8JxFM9cLssdv9IIJTcVMbjZhVa3ZQNzy/NwT9QpMc31dVW2EvOFQv5vh0IPD5ecyfGBH0zSzhOexqSqXaxrsl0K6e3Z9H63XS+OTY3LZbJhs3LJcr5Hvd+uQ8XT6B6Ho+sNMYTLbN4ocI4T+TKc4O6u63XOn48nqXchep3Pudl9qkTEWWNiw6vnCr3yKnO0RLGAB41xm4Gy3IQya/F8IQeF26xTSih/JOAgsSFbgbMiddbdAFYH80AoCXMyGMA4kPt2LyhOWn1cLPsFSgHEpicPBdivZtkdIOaVhJYR4ti1tt9lr65NZ3CfL8mFxJ0d6zoTcF5awb1mnIOcWUmaMHUGwLOtse946iiLmQb4cRWvPs89QIQgOxi+/IIPuOIEgSJYknX0/DEPXhS/fP0tQJAiB4+Dv/6Bw/3SSrBzS6VQ2a5eT2EtgfOefsrv5B1Ykj+sIdj+/AAAAAElFTkSuQmCC",
		["Controller1.png"] = "iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAMAAADW3miqAAAA/1BMVEUAAAAPI+sAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB7kQElAAAAQHRSTlMA/wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAft0+HgAAAEJJREFUeNpjYBjagBEIiFJEUB0jHBClCI86RjRAlCKs6hixAqIUoakj2yTCbiLsOyLCiXCIUyWCqZeeRhUNOkX0AgArRQEOeya6HQAAAABJRU5ErkJggg==",
		["Controller1Tool.png"] = "iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAMAAAApWqozAAAA/1BMVEUAAAA3NzoUFBaCgocULeuVlZplZWmnp6tEREienqJTU1a0tLnKys93d3t9fYC8vMHV1drs7PEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADm00FIAAAAQHRSTlMA//////////////////////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAj0PqgAAAALtJREFUeNrl09sKwyAMBmA1NfG00/u/7LpJNStq08FAWK4a8tFGy6/UPLUs9dnwauOqDdhSPVy8AV1qgDMX45f/xZvlO7PbWBWGEVafmLwcI3gnxuQQpNiR1lG+8/g2psC8zmF9Bh8kxciqkaR+0zhTv/kvjNs8rTG5F4wNHMhucwsaqWBLYY99Tt17Hm6asK7hcnwZjsDWTC7xnSHu18B4rV+2vuJLxMYBoczDAyuGOX8KT1K/+SIpE9QTgagIlC6aAZgAAAAASUVORK5CYII=",
		["Controller1Tool_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAMAAAApWqozAAAA/1BMVEUA//83NzoUFBaCgocULeuVlZplZWmnp6tEREienqJTU1a0tLnKys93d3t9fYC8vMHV1drs7PEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACzFin4AAAAQHRSTlP///////////////////////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAcxEqeAAAALtJREFUeNrl09sKwyAMBmA1NfG00/u/7LpJNStq08FAWK4a8tFGy6/UPLUs9dnwauOqDdhSPVy8AV1qgDMX45f/xZvlO7PbWBWGEVafmLwcI3gnxuQQpNiR1lG+8/g2psC8zmF9Bh8kxciqkaR+0zhTv/kvjNs8rTG5F4wNHMhucwsaqWBLYY99Tt17Hm6asK7hcnwZjsDWTC7xnSHu18B4rV+2vuJLxMYBoczDAyuGOX8KT1K/+SIpE9QTgagIlC6aAZgAAAAASUVORK5CYII=",
		["Controller1_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAMAAADW3miqAAAA/1BMVEUA//8obv9evP8A//8A//8A//8A//8A//8A//8A//8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAnPo2JAAAAQHRSTlMD//8vSvCJb67QAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABNXpkgAAAK9JREFUeNrV1EESwyAIBdCkIML9L1xFjXESvptuyjZvGCHAcfw4yGNDOJdgRo6yqJmqAEcsZ42ULHaUtZoPdJTNUYnYkaSBYscLWhzFqDvTm3pDzWneIXdXqgjtM9VH4Te18mB1swFRn1rtz5ZPdL4mWdDtfzynoKNCwER1lLzkaDYHKq2Lx3cgYTDiEx3/hUh8W0zQnveVsoyRL6di1NYc9tJVCd6eHsZ35zpi8dcv7HgHo/6vLPUAAAAASUVORK5CYII=",
		["Controller1_ds.png"] = "iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAMAAADW3miqAAAA/1BMVEUAAACMjJEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACJx1sYAAAAQHRSTlMA/wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAft0+HgAAAEJJREFUeNpjYBjagBEIiFJEUB0jHBClCI86RjRAlCKs6hixAqIUoakj2yTCbiLsOyLCiXCIUyWCqZeeRhUNOkX0AgArRQEOeya6HQAAAABJRU5ErkJggg==",
		["Controller1_ovr.png"] = "iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAMAAADW3miqAAAA/1BMVEUA//8PI+sA//8A//8A//8A//8A//8A//8A//8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA1sIIhAAAAQHRSTlMD/y5KifBur9IAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAr0nUZgAAAKVJREFUeNrV1MsSwyAIBVDlpf//xUGtqU0Qssimd5szTHCAlF4OtEQERQTRdYBUNOQ5NVnDXB0HUvKI40BqPrNzQJzXmA4v6OsWZqDmlC3KRpqitUKkeaUSh/+k7QXd3R/ghuwnX5FV5IJmEWMKPoiZ7SI/qPezG8yJijjjOxHhI5T+CwH1bankLvBYqSo+KmMOg1PQkPuWXWl8004PBodnHrH91wObMQXZkPUwuwAAAABJRU5ErkJggg==",
		["Controller2.png"] = "iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAMAAADW3miqAAAA/1BMVEUAAADhGRQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABgXtQiAAAAQHRSTlMA/wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAft0+HgAAAEJJREFUeNpjYBjagBEIiFJEUB0jHBClCI86RjRAlCKs6hixAqIUoakj2yTCbiLsOyLCiXCIUyWCqZeeRhUNOkX0AgArRQEOeya6HQAAAABJRU5ErkJggg==",
		["Controller2Tool.png"] = "iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAMAAAApWqozAAAA/1BMVEUAAAA3NzoUFBaCgofrHhSVlZrHx8tGRklmZmpWVlmoqKzn5+x1dXi2trre3uK+vsN9fYE+PkGdnaLW1tsoKCpdXWEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD2/Zt3AAAAQHRSTlMA////////////////////////////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAc8MdlAAAAQJJREFUeNrN0+1uwyAMBdDeUGwgfCRp9/6vOrK1rlMlC5lUKf6FxQGBwZfLeeJ6fY07Hev4pTtjJbaw+M5A4g/8y5vx7D+xs5w5RIAmYPL71YCxYKK64L5bZwNPcHbGXQPGDdYF9xWacPGJB2NiE7aR4FPgJuxKqCcmNGHua/FSaMM7j3IA6ziGcQTvdErXFiudtJ2s3Gk7OR82Pcu8L1T4mfRENLzhNA2CiRGTYGCkuMBj/fCCs6/fVOG50TSOBiR4yMFBY+QFDkRZNgMPZDUel7hu68Jjnusqzhq7pPEMx9sTZ/45pWAmp/FUrwvyj3lHVLwuXTzfc+tO2k7+0SkniG8MfgvaoXA4DQAAAABJRU5ErkJggg==",
		["Controller2Tool_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAMAAAApWqozAAAA/1BMVEUA//83NzoUFBaCgofrHhSVlZrHx8tGRklmZmpWVlmoqKzn5+x1dXi2trre3uK+vsN9fYE+PkGdnaLW1tsoKCpdXWEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACjOPPHAAAAQHRSTlP/////////////////////////////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAj5HdbAAAAQJJREFUeNrN0+1uwyAMBdDeUGwgfCRp9/6vOrK1rlMlC5lUKf6FxQGBwZfLeeJ6fY07Hev4pTtjJbaw+M5A4g/8y5vx7D+xs5w5RIAmYPL71YCxYKK64L5bZwNPcHbGXQPGDdYF9xWacPGJB2NiE7aR4FPgJuxKqCcmNGHua/FSaMM7j3IA6ziGcQTvdErXFiudtJ2s3Gk7OR82Pcu8L1T4mfRENLzhNA2CiRGTYGCkuMBj/fCCs6/fVOG50TSOBiR4yMFBY+QFDkRZNgMPZDUel7hu68Jjnusqzhq7pPEMx9sTZ/45pWAmp/FUrwvyj3lHVLwuXTzfc+tO2k7+0SkniG8MfgvaoXA4DQAAAABJRU5ErkJggg==",
		["Controller2_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAMAAADW3miqAAAA/1BMVEUA////WlX/oZoA//8A//8A//8A//8A//8A//8A//8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAzSpaVAAAAQHRSTlMD//8vSvCJb67QAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABNXpkgAAAK9JREFUeNrV1EESwyAIBdCkIML9L1xFjXESvptuyjZvGCHAcfw4yGNDOJdgRo6yqJmqAEcsZ42ULHaUtZoPdJTNUYnYkaSBYscLWhzFqDvTm3pDzWneIXdXqgjtM9VH4Te18mB1swFRn1rtz5ZPdL4mWdDtfzynoKNCwER1lLzkaDYHKq2Lx3cgYTDiEx3/hUh8W0zQnveVsoyRL6di1NYc9tJVCd6eHsZ35zpi8dcv7HgHo/6vLPUAAAAASUVORK5CYII=",
		["Controller2_ovr.png"] = "iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAMAAADW3miqAAAA/1BMVEUA///hGRQA//8A//8A//8A//8A//8A//8A//8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuf1cmAAAAQHRSTlMD/y5KifBur9IAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAr0nUZgAAAKVJREFUeNrV1MsSwyAIBVDlpf//xUGtqU0Qssimd5szTHCAlF4OtEQERQTRdYBUNOQ5NVnDXB0HUvKI40BqPrNzQJzXmA4v6OsWZqDmlC3KRpqitUKkeaUSh/+k7QXd3R/ghuwnX5FV5IJmEWMKPoiZ7SI/qPezG8yJijjjOxHhI5T+CwH1bankLvBYqSo+KmMOg1PQkPuWXWl8004PBodnHrH91wObMQXZkPUwuwAAAABJRU5ErkJggg==",
		["ControllerAI1Tool.png"] = "iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAMAAAApWqozAAAA/1BMVEUAAACgoKULCwsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAnkOIUAAAAQHRSTlMA//8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAOG9a2wAAAKxJREFUeNrd1UkOgCAMBVD89z+0QVE6fuzGGFkYkScpU2ntOwUoYZSw4YD/pptg6yE3bf1l6yXUUF1ddHDas6AnJzEb67UYCgKMbJ4BF4bD8+1oltQGorHQGPUQXwr6J6Ud3iCeHNswYnxbsdxOfwQ3PRlugAz78hec6SwnyD2PZ/g+wAybbUfWT5yUGS3D0RDzrFnC6yTD9CJ1LxJjkPrylEtS8OOLo3QvvVh2/5EEtkFu3QoAAAAASUVORK5CYII=",
		["ControllerAI1Tool_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAMAAAApWqozAAAA/1BMVEUA//+goKULCwsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAByVYqkAAAAQHRSTlP///8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAxD2aIwAAAKxJREFUeNrd1UkOgCAMBVD89z+0QVE6fuzGGFkYkScpU2ntOwUoYZSw4YD/pptg6yE3bf1l6yXUUF1ddHDas6AnJzEb67UYCgKMbJ4BF4bD8+1oltQGorHQGPUQXwr6J6Ud3iCeHNswYnxbsdxOfwQ3PRlugAz78hec6SwnyD2PZ/g+wAybbUfWT5yUGS3D0RDzrFnC6yTD9CJ1LxJjkPrylEtS8OOLo3QvvVh2/5EEtkFu3QoAAAAASUVORK5CYII=",
		["ControllerAI2Tool.png"] = "iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAMAAAApWqozAAAA/1BMVEUAAAD15QAKCgoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABrbjxRAAAAQHRSTlMA//8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAOG9a2wAAAK1JREFUeNrV1NEOgCAIBVDg/z+6rNQrwnW+GQ9ttVODm0PknFLdwrqFHbe3UgzeeuX44wU9d6FWRV7px+mXgb6c9OzsrGG62i1eLcv5wTBghNG6Ab12CbuWLcE39POVzgeNOCqGeydWHwS4Wfjdkz4EyxjGNCDDi+x+jEEPxy/eCZiZYYIMt3gZbv9Q8aXE7uFRL6zgESIHI9Aru15fXtPFOGuyciNNdn/C5ci6ABV3BG9TKK9/AAAAAElFTkSuQmCC",
		["ControllerAI2Tool_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAMAAAApWqozAAAA/1BMVEUA///15QAKCgoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA+q1ThAAAAQHRSTlP///8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAxD2aIwAAAK1JREFUeNrV1NEOgCAIBVDg/z+6rNQrwnW+GQ9ttVODm0PknFLdwrqFHbe3UgzeeuX44wU9d6FWRV7px+mXgb6c9OzsrGG62i1eLcv5wTBghNG6Ab12CbuWLcE39POVzgeNOCqGeydWHwS4Wfjdkz4EyxjGNCDDi+x+jEEPxy/eCZiZYYIMt3gZbv9Q8aXE7uFRL6zgESIHI9Aru15fXtPFOGuyciNNdn/C5ci6ABV3BG9TKK9/AAAAAElFTkSuQmCC",
		["ControllerNoneTool.png"] = "iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAMAAAApWqozAAAA/1BMVEUAAADrFBTr6/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAm8gtPAAAAQHRSTlMA//8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAOG9a2wAAALNJREFUeNrd1UsOxCAIAFDh/odurGLlD7vJuIQXpUboGP+xYK0GrfDLpJznYy2zkdY5X68MovhYD48X4x1x8A7ju76jbM3w5KsEE1OQMFK5ljbwqqaCYeJVjX/HzDp3fSJfESrl4Xu7DLOjY6weX4BlOsbQwPpV+1jdq4Xh4LwBKFTY+MSs1gowFvDYT11iv1OAHnGGdy8L7Hf3zHCcDA6GOyOpM+wKY7Q8cnvDvPmb+P31AG84AcreFAHGAAAAAElFTkSuQmCC",
		["ControllerNoneTool_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAMAAAApWqozAAAA/1BMVEUA///rFBTr6/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABzN2P/AAAAQHRSTlP///8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAxD2aIwAAALNJREFUeNrd1UsOxCAIAFDh/odurGLlD7vJuIQXpUboGP+xYK0GrfDLpJznYy2zkdY5X68MovhYD48X4x1x8A7ju76jbM3w5KsEE1OQMFK5ljbwqqaCYeJVjX/HzDp3fSJfESrl4Xu7DLOjY6weX4BlOsbQwPpV+1jdq4Xh4LwBKFTY+MSs1gowFvDYT11iv1OAHnGGdy8L7Hf3zHCcDA6GOyOpM+wKY7Q8cnvDvPmb+P31AG84AcreFAHGAAAAAElFTkSuQmCC",
		["ControllerPanel.png"] = "iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAMAAAApWqozAAAA/1BMVEUAAADl5eWXl5empqbX19fFxcUPh9cZpfAPeMO1tbXX4eZnZ2eJiYn///8CAgJaWlp6enoKCgoAAAB9fX2srKzw8PADAwNGRkZ2dna/v7/Hx8cICAgZGRkkJCQ2Nja2tra7u7vKysrY2Njg4OAXFxcVFRUYGBgjIyMnJycqKio7Ozs3NzdbW1tubm6MjIyKioqYmJipqampqamysrK0tLS0tLTExMTKysrd3d3S0tLR0dGCgoIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAdn6l2AAAAQHRSTlMB/v79/f3////4//39AUv4xKk0BQr/ZfP8BMyP0sT1V9kkM0NMYLSZueuAq63BSLGIX7M5Y6pGeURsqMAAAAAA0juIzgAAAfRJREFUeNrl1Nl2ozAMBmCQbBrXAjdAE5q1Sfd9X+f932sUQ4kxkF7M5fwnN4Hv+AjZVhD8S7I8PrKJ8+wXGsf9/zpovl6ffJ7wb73Od/EsiFdf3xOpFKJScvL9tYqD3lpWHxMFVGibgkBNPlZ99p2p1qSk4EhFWjN/7y5ieYzaoAjDQ5swFGg0Hi87CslfFRgSbLY5FGRAveZ+H4Ill4BhK8ilLAOvJy9cg+KX0WDQ1IoreWmum7+pwq4bDfY8joV6y5214+AJCcIK7zF3PRA+bTF3/hlJ1ni/6SXhc1brLLhHqD7OYo71P4UQ3tc7GQePUC1c431neUnw6BT9ACB8vF1eADw47fhDPy12cF2JQDpw8AEpUabGllYPFTQwoBJykwpbKsvwmfKwQrnF9tNkHdXCgDbVpqAbaOMydrvBSz9uUR/fbXEUdeE7B9/S5pLamqMI/ShFt86huy5Q9mOJxbWz3aeGuEO2dVEkm+HHZE7d43+jsdrBKBJ+UN80btXZmGQfljQ+a+D0wpTnjrF3ZQWYi7R5YZPLUrcw28vEnxvJ3Gofs50n7SkzmnPdPuZ656Ou+ZWcLzQ0sAC9OE+6B2MynS3sXLRwMxkXs2nSN0bT0XB2NTZmM3GNGV/NhqN0x+xPR9NhnelOanmaVEnT4H/LX14GJZCoerETAAAAAElFTkSuQmCC",
		["HingeTool.png"] = "iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAMAAAApWqozAAAA/1BMVEUAAACMjIyvr69zc3NTU1P15gBGRkaglgD/9SgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADpqmTFAAAAQHRSTlMA//////////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAu/oNAQAAAK5JREFUeNrt1EsOBCEIBFA/NPT9Tzw6aCsRlElm2bV+qcQghPBmHwDw05SSj39p8nB4KHNwlM7eTS1u0BrEBUeDI2YFR40XmnVcOQhZqYnn+ia3uPFB97jwmZ5wFPb/mOgXfDXuwHSVUPVezP6Iu22evJjuEtpgUXzEJK3QygPJxrBOkNivWPJn3NVreObjK2MoXrF8NyaMbVUN3OuRS3tImeLgmNf9N0+Tn75x5gMJXwnVxf23fQAAAABJRU5ErkJggg==",
		["HingeTool_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAMAAAApWqozAAAA/1BMVEUA//+MjIyvr69zc3MA//9TU1P15gBGRkaglgD/9SgA//8A//8A//8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA6yMRNAAAAQHRSTlP/////A///////zn6uAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALo0IAAAAAOBJREFUeNqt1csOxCAIBVBqx8LU/v/3js+qERSTuYuuTogVFfjEOJjGJQXx+8AiT8U3LHMXrLBJg9JGDev11nUDsw/WWn5POGqMEThHjYbblyZuFUVbr6YSF2gI4oAPgSOeDD447unJ48BtJwMVcVs+yynOvNI59rylK3x09v+YaAdfmSswXT4UvBYnv8TFZk9aTF8fmuCu8BJTbzvN/CDJ2I4dpORH3PO33cFzuOX1KCN4z9j0bjQY81UVcCmPqWgJMV2sHM/x/otPk0gdqOP2HvO9MbE3gPZG297Q1I7jH2MTDW5FvuxiAAAAAElFTkSuQmCC",
		["HopperPanel.png"] = "iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAMAAAApWqozAAAA/1BMVEUAAADk5OUdHR3GxsakpKQjrzeXl5fW1ta0tLRnZ2f///8jQeGJiYnXLS3XLbnr1yMCAgJaWloKCgoAAAB9fX16enqsrKzw8PADAwO/v7/Hx8dFRUV3d3cICAgkJCQ2Nja2tra7u7vKysrY2Njg4OAYGBgjIyMnJycqKiqMjIyKioqYmJipqampqamysrK0tLS0tLTExMTKysrd3d3S0tLR0dEXFxcVFRU7Ozs3NzdbW1tubm6CgoIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACGGgZyAAAAQHRSTlMB/tv9+//9/fb9Af/8////S/mpNAXECv9lBMz2/I/E9VfZJDNDtJm560ixiF+zOWOqRnlEbKhMYICrrcHAAAAAdWi0SQAAAeFJREFUeNrllMly2zAQRAFiMlgC24BI04xILZa873bs7P//XQEgcyfkQ47p0qFVejXVagBDyL8oy9WXIJVnH6BKxb9NoPl2e/b1zH2223wfnhG1eX2bMyEAhGDzt9eNItEsm5e5QF3JoEqjmL9sYuyzQ6XUgnEnJrSUDn+eDrE+BWmBU3oSRCkHK+F0PREkfxRoNXdMqxOuLYrHfNgDWbsIQEcCF2VNBp08uAzJuyhtHRUuyUN/bv4kKkgOgzz8OSgJsyvxlHdmK3IHGmly6H/cwd7tYIoa7lrYNX8PmsVgpuE+a+iMXAO6PxeBKWi4bk5SkVt0g6Mw03jbCX2DyOMwR7zp1PFH+4qn2/AnqY878LEW7jrU7XZdkMAejCA4i8jdqQEsgEUlRjBCTLtEPbiOiSOTHDkN4E9BjmnMQZCDKe3Cvz3sWwpwbQ68GcO/dANDayZhRX5U8BHcHvc3q2uGtSYSg/yUNcNb08D9Nsj3si6Bt6ZuY9AzSS+aZzcyaC/S/oM1l9bf0rE42ksz3BtmOUk7dmnGW6ZYlv659MV0uSym9pc5X8n+cI5ydW6mF6NZJKuwFwPoN+MqWZjYGk2LWXJVWus3rrXlVTIr0j27Py0Ws0aLvWjAU/OuNCX/m/4CLAckBq9zrUwAAAAASUVORK5CYII=",
		["Key_A.png"] = "iVBORw0KGgoAAAANSUhEUgAAACIAAAAeCAMAAAB+ITwmAAAA/1BMVEXu3s/g4N1ISEk3NzZXV1dnZ2cpKSl2dnYXFhYJCgmHhoZSUlqUk5EWFhgoJin49/VLSlIAAAANDBDEw8JeXWBnZGrr6+lDQT3R0tJUVWCuq6m3t7YcHCEhIRw1NTmAgH4MCw4RFhYgHx0gHiI7Oz0+PkM+PkBAP0FHR0diXl1/f3/JwrwMDAgfHiEfICFCOzlRRTldWV1VVVtcXGhfYF9/AABhWl9kXGN9fIR/f4CAf4KlnZCjmpqgoJ+sp6zc0NAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHnu44AAAAQHRSTlMp//7+/v7+//79/5b/lpb/lQCW//6W//L/l/f/lf+V/3AW/ZZylf39F/8C8zz//28WPG8W/wKVlZb//zxy/28WCCMMRAAAAYJJREFUeNqF0+lygjAUBeA0N7kkGIsRRNRau6hd7L7vff+36g0BJGWmPX8yDN+ckJuBndvvr5fRaDTpTSa9MtVCGQzu7u05s2waS3nGWxFlskxm9HBrGdsYKbnSWil1hAgUrzJJ4TA+ZR8kxJXWpQHAhjgRSYAlG8ks45XgqcRaOBIRwX0iQlQEZsm0XRJRagKeREmSdskue24IpHlecPBneqjImMjTmSeuxMx2RFgScSI9URFME2lyGZJFi7iS3KTJIiQxv3SEc/AlLga2Q6GSmKuGaJmkxsySTwhKSjLwBNOCI/J81t4njuOxOvZEaZkbd0FF0SF7bMAdUdMNlSBMC7H9lFcisCV0gY5wEZbU5ISIUoj4a/qe9ImcAHZJFJB1SIIS4wn8SfRvUu4jG2ICghUJSwwSWf1HhmwFDeke2cSO7IOfWmcqb45ITWRZE1rXJcmaa44l/V8H7FRUJU3VNkhCHzL7Pi7fzefzI1VFt3Jh2aO9ud6tc9xvMixzcGjtD/oKJGXK6IGQAAAAAElFTkSuQmCC",
		["Key_A_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAACIAAAAeCAMAAAB+ITwmAAAA/1BMVEX/WVz/UlL9MzPqIB/7QD//YmPkgX/oop/7Jif+NTXPGBiOCQm0ExNzBATnHR0JEhMVERDEKC/5JSarDAy0EhPwHiDr+feMCQvQNDYCAADRGRp6AQHSCwvqHSHoeXjnlpbq6Of5R0fIQkrltrXk09AABAIWExIuFxdzAwOkDxHkHR3yVVL/WGPrh4fpp6fqwb/kyssHDg5qBAR8Bga5Fwu+FBS+NTXDFRXUGh3dIRbdIB/HO0Lej5Df2Nbc4N7jDw8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACkfLwiAAAAQHRSTlNylZb///////7+/f7+/f79lvyW/pb//5X+AJYI/5X////+8v//PG8WcJWX/hf/////4DyWFm//PHIX////////PR+cyQAAAU1JREFUeNql08d2wjAQBVCRqmYlYOxI2HGjhNDTe/L/f5UZhMHCJpu8lRb3PI2kIxKZm9HlwYxuTETM8O7irwwNmRVFoXX7UD6KGSGnOaOQQAWb0F0CRXNCWlMUUmAkhEPUcWlgfURaOQoPAsb310bteiTvkQ4uPEtkol3CKJeWcCv8eZjEjmCMy26V6Cxc8AphNeKnYbhU+8SvEp3N+wM8wyGCJSz5Zu4oLtFZlqfhtEZutwQngSTxe3UfxsWWQMkgPV+GyQ+lLrlCopB8Dlgc0yxVTUQpuP/nr7MYbnbVdyax5BpKpCeSvob3iRerRsKR6LaPz8zyBtJBIhpe2RKJLWpDhHQI+xehe8Srkb2SNemVxG/axxLukMAhJ0AeyGtJnGnLEia8MXkDIWv7lIYKDz7sC5rND1JB7UD3hkTm8alr04NMJp1KuuPIRL/l4zfK2GggawAAAABJRU5ErkJggg==",
		["Key_D.png"] = "iVBORw0KGgoAAAANSUhEUgAAACIAAAAeCAMAAAB+ITwmAAAA/1BMVEVXV1dISEkpKSk2NTZnZ2d3dnaGhoYWFhYKCQknJypQU1vn5uQUFBZHR03KysgAAABVV2Srq6k1NDo+PkGUlJJdXWFlZWvU1NPh4d719PMZHCMgHhwhIR47PEO2tbV7e3sPDhAUFBcbHSA+QEJAPj5gYF6hoZ/5+f8VEREWISEdICkeISQiFxcgHiAhIR45Mi08PkdFRUxcUVFVUFBYWGNbXmdYY2N/AABmYWZ3cHelnqWhoaXAwL/Y2NgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAcTI7xAAAAQHRSTlP+/v79/v///v2Wlv+Wlf8AlvqV+v//lv///5X9/ZX5CJZw//3//f8WPBeV/xaXl29ychY8F28XAjyWb3L/PAAAdPx5AgAAAX1JREFUeNp909l6gjAQBeCZrGCUSBGQutet+74v7/9aTQhIUNtzwdX/nRkCgZnefn5kWdav0vHS67zM9Az0TywYA2wCLmlqHgjvGrZTwdYobcaEUJuKMZMl4it82Q4ZBIEVpamarOBAkgfIjKBGBKt4Gm8E1CWl4IzSiSHgCFdqqFS0bggvyQn0KyJjNWA8VjEekE7qCImGSAjmOdTLcp8QQ1BF1Cw7VcwrEY6AI6zY2Nf5NgQawimxBEsiCm4IRkM4RtAQOVVgTgVUBI0whJCwJiTKzSpEFAIPSM8Ruy1Fbkr8bSuCJWGFivK8GHLvaIVPZCCUOdwoZtgq8Vtk+fGQrv4g1BAp688MbXJlSULJTlCvpCTjs4Y4szdH8FFJaIu05gz4SF4eI82cAZfyFHpLWu9CDuY4Mkmot+5xQv8jrCHu50/2BwkMZBfuLWldj7RZ196eBTwntanhLoTY+3UB+qkC49FIVgm8nGt40493YZXbMLzpepnPF9da/wLSQRypCsJ5KQAAAABJRU5ErkJggg==",
		["Key_D_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAACIAAAAeCAMAAAB+ITwmAAAA/1BMVEWpEhKiDxD/Wl7Ya2vdnZ0HDg53BARwAgKrDxGbEA/SFiHJGBrsIB//P0H/X2DowL7czcr7Jyf9NDSyEhPPGBiPCQlyBAPnHBwJEhIVERDEKTCqCwv5JSazEhTQGRrvHiACAADKCQnNRUjwVVTk09KUDA/jqKfm5eTo9fN8AADpHiC4JSfc5+XmurjTNTbtSkzni4rhxsUABAQWExIuFxfGPEPfW1raZmXa2dbiHR3/Rkj/WGPzZWbsdHPol5Xj4N0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACR62gaAAAAQHRSTlMjcHL//+A8b5b/F3L//5b///7+/v3+/f79lvz+lpWV/gD/+f7/lf///waV/v///v///zxvFv3///+WlRf/////7o4fPgAAAW9JREFUeNp909dywjAQBVBR0qsaShBFlh0Xeu+B//+rrNxtTO6TmTlzd2ULFKjV8vtmlisVILW4+/ovC4WOWq8n7eoM2+21PqL6ySYY0k+Ci5nW0XsoKOf8iUIYRIgUMIYP6PAGT7wF4RJCQ/KaGsoGqGOsEXSzte1JsYUA6aWEa2e0233OoDsTBH5FhBrSGJ3tkzv6FTeJdC/YsvB8jtM5pESGzgej1HI9kisBQjOi/bMFZy4TSrsJ4Q1/I4GMHXyTNL0JvBTsjPOCkIj0DZHNeRtWmcKJqoigZlvXggPl5pAcEYZoz5nN3ItvF0tCMsCC0Rbfer7ve+NMJEQC6TNDhlpPCRSKUovMSPiZw29YEETyLtoLxiQQHt8WXCY/qJcQGZLSHMJjYl5dWJO1kDxh0S4xEdWEmptrBuUuXCWpXCUkLyDo1baJwJzX0HPcEi17TVoIKQRGJv+g0hwQ9woFCtW6UXqQ/aCTy+NDoII/7AZamqU60BUAAAAASUVORK5CYII=",
		["Key_S.png"] = "iVBORw0KGgoAAAANSUhEUgAAACIAAAAeCAMAAAB+ITwmAAAA/1BMVEVhYWXm5u1ZWmFgX1+foahxcXdzc4tzd4F/f4CBf3yAf4GBgH6goJy/vsHh4N1ISElXV1cpKChnZ2c3NjZ3d3cWFhaGhoYJCQoVFhgoJyliZ3QAAAA2NTpIR0308/BRU1uTk5LY2NVXWmSpqafo6eULDQ49PEE9PUBZYXDIx8QeHiAiIB5CQT5dXmAWFhYcHSAhHx0/QEBAPkJ/f3+4uLkMDBELDQsRERYeICMhHiI7OTA3OkVAPz5BP0ZNQk1cXFEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAhgSmAAAAQHRSTlMvI3D/cJYWlv//////6P/+/v7+/v/+//2WlpYAlZX/lv//lv//lpX/l//+/vT+Fpb///MC7zxvcpX/b3L8lRcWDrO16gAAAYBJREFUeNpt09l64yAMBlDSdvZFCCFoSkuh9iSTTNJ99qXv/1YDxk5M6v+Ki/NJwhbiwc1OXp3t8jnlKueyy9FL9yDc7NEoJaGK7JNOwonZB6O2wNYy8xdEJKJCVA4QCHGSaySRyW0vMjnOQktcHokXSVAnyDRB7UgGWiukC3GmZEcsrHzr23APNcEdYW68USa2x1UVTbgQV1spMRXBGAlJt2ozFoXIQnjlDdGdlvCMXBbCLGP7qKGe1mjE84FYRnjf+gaWUwQSYavfIKmYmo37FHKRmmO+0Cp9W+0DHJB1IlBI8IGgaXXVxxjkPZEffYx+JQcxQVA2MTbyoEhFGBFg9Jd3ZJ7JpifVIlTkDyHXZC96QiNyN0X+VgSeETsXiwNSXTmYtf0hFstCur09LBIM2xtxToVMThvesT0dyHpylKD35GcnyiJsC3mdDdhEfudZcGgzqvK2CPtd/LsvAgc3Sl41e53e46Y3tzzEjvLVCeeefs373Jzu86nLt2vn/gOFclQ+PXC5fQAAAABJRU5ErkJggg==",
		["Key_S_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAACIAAAAeCAMAAAB+ITwmAAAA/1BMVEX7Jif+NTXRGBiwEhKQCQlzBATlHBwJERHHJSoVEhL5JieqCwvQGBq1ExTm6ecCAADtHiB4AAHQCQnNODrQRUfvSEnsZ2f0V1ji8u+TCwzoHSHoyMXiHR3mmJbnuLYABAQGDg4WEhMuFxdzAwWjDhC0Fhbd6+joIB//RUf/WFjndHPoiYnoo6Hk08/k4t1qBAS/FRW6FBTEFhjXQD/XVlbZe3jciYbf8ev/WVv/W2D/X2LkYV/twb0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAcdlYOAAAAQHRSTlP+/v3+/v3+//uWlv6Vlv8A/gj//vf///7/lZX/lv//POBvFnCVFv//lRf//////zw8b3L//////3Jylv//AAAA4z37BwAAAU5JREFUeNp909d6wjAMBlB5xLQYnD0gbMoe3bvv/1yVkxDiQPivfHE+SU4scO3Z9L4x05ntgj2etG5kMrZhEwT+XXP8YAPfUUygMQ6EX/CTCcZ1mA7FlASPa1iHeOKWDpcyF+IkCDDahra2OfDfApoJg/QzwjRhO5WoUWgUQcI6JeFRMox2yxTOhNRJmnqeFykiRIUQg/wp4lERQbVPjQTqsAUhjD5IZIVIsv88xDcI918l/T0modmnIE5GPoaSeXGyLUVBeEYEszh/PwbSi5bxBelCH0fUxFdqP0xSMPvkxNEEpw1HCj+uWK2uEEp1FS6pT+r3yclAFIQxWf3LBeFIOidSewgNRBvHEEgeMiIrBGrEQkINIi5I70zyIo2E3yQvOC0rSV0gmcOiIPJqEbAsXNgnbYr9EY5JcHsebXDtxXM3TwczGLQr6c1d2/0HaZwaDUOWD0gAAAAASUVORK5CYII=",
		["Key_W.png"] = "iVBORw0KGgoAAAANSUhEUgAAACIAAAAeCAMAAAB+ITwmAAAA/1BMVEXg392uqqqgn6Do3dJnZ2cnJydXV1h2dnY3NzdHR0cXFxeHh4cLCgpJSk729vRRU1cmKCw2NjqUlZTr6urIyMYgHh4AAAC4uLbZ2dcgIB4bGyM7OkGrqaldXmAZGxdlZWo/PkIWFhofIBtOVFpUVFReYGJgX19/f39+foAAAH8ZGRUXFyIfHyAeIB0hISE/QD5BPT1BPz9APkBCQT5QTEhCQkddXVlaX2FjY1hoaHNxcHeAfoWAgH+Li4uKhoienaAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA2Ls5vAAAAQHRSTlP/PP8X/v7+//7+/v79lv+WlZb9///+AP///paW//+Vlv5w/BZw//8C/wI8Fv+VF/+V/3L/PG88lRcWlm//FnL/s3xXrwAAAbNJREFUeNqF0teSnDAQBVDZllrdQiN2ENHL7Gxe55zj//+VuxFiQtnr+0AVcOpKglZ37c/v37bbsixXKWWO3Fx/be9U+6CwGggl5+c0BSSbzQaA4FOrHlUsjPPeOWeMEZiQlhDSF/WLBXrvjRGCgAL42SQsGLpWWw1gvG/GSkqKGlg8rK0Qa5ngKhNTdyyoj5rI9l3qsHZj8FR9vgEYmHQ1vjC/QyiIxljATG4MrlXJ22bixp4c9CFUb7Wqc0mhM5HzVHHjxtDHkcZQwO0xaSaiIfZF7HSsNcBCTG5xvghVFwodar5msRDiFudt7EONEGPYlRwRHUOwBvjKJfNWfgg5USv+mrIQv+zQkMol01YW8p6JoxABkXopyZtl0iSC/Acd1lb+YdfBAXF7xKAInObgL6RJg8BmmQObySAE/0FYVNo1/ycukcHlkVvm7YC8TsQcELsjL9WKj2F2JQfrMPHuTL25h1SJrBNJw78nnkwtMBMe/uU8tE8qy1N9pt5JS+qYST6RtZqFv1BXNInjDMPlJc8rj+Mr1X7A2cgHnOL386xVT9urj6eSdcrJnMdTLp637R9H2Cz+A9/9HAAAAABJRU5ErkJggg==",
		["Key_W_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAACIAAAAeCAMAAAB+ITwmAAAA/1BMVEXkHyDyFBT/XWP/Xl7bP0H/XVjnYV/sgH/ctrfe2dr7Jyj9NTWRCQnPGBizEhLpHBx1BAUJEhIUEhKnDAzHJCjyIiPQGRnt+PeyExPuaGe+Iibr6OfourgCAAD4Rkbr1tXiHR3wW1rrysh9AALFMzbmhIOVDAukDw/JREjuHiDmqKfkmpkABAIWEhIuFxfHBwjZVlXc6ej/REPidHMHDw9cAABuBAB3BAJ6BQOKCAitFxe6EhTSFhbDFRXSGBjSIB8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADgKXKAAAAQHRSTlOW/xdy/5b//////v7+/f7+/f2W/vyVlf+V//z//wD+/5X//wb+/5WV8////zxvFv///5X/4BY8b5ZyFm8XPHL/lVYh3QAAAYRJREFUeNqN0+lSgzAUBeDU3SQ3Fw1timEpFLS7+769/1t5CVLoYNXzh8zwzSFzE9g4Wi1Pt2a5isYsWtyd/JZFxHYmk9xf56xKvfb9fLLDdtNYcM4REdBlOuVNkMe7bD+mFUgXrRSUaQitb9gNdYDnec5Uol2jsM/65ZNEGpPQ4hABMC6Eey8EVzByRHuenheaSmZWIPKjGW/IwBFZkpmSOrU2Rgyu0x9JEfoSQmMC5GFYCyLKkR4ReZvlOjCJKXqBCTqkbJHB8R4kSWrmmDQla4IlubpOCxMIMwvKb7XIsCE2tBkIm9iMt1q0I+jIxBpzcOknpi7pktyaEBSRdsmagKTx58YKrSDbKBFcEmHTiqjs9pJOMQzbgogeshEdSkn0J5TnLMQW8n0TiCDyTSIvGqIqwrtk0GqBhog2gT/I+T+JqvfS2W28JrohmyUV+aBx6G3fEb4nn9kbtah6Kh1CF59+2HdQqppJZyuC5v4QsXH08jp0GVQZjfpV2ODi6fE+Gn8BBz9Bvkb/PVkAAAAASUVORK5CYII=",
		["MoveTool.png"] = "iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAMAAAApWqozAAAA/1BMVEUAAADl5eX1rxkZLdLX19eoqKjGxsaXl5e1tbUAAACJiYn///9nZ2daWlp6enoKCgoAAAB9fX2srKzw8PADAwNGRkZ2dna/v7/Hx8cICAgZGRkkJCQ2Nja2tra7u7vKysrY2Njg4OAXFxcVFRUYGBgjIyMnJycqKio7Ozs3NzdbW1tubm6MjIyKioqYmJipqampqamysrK0tLS0tLTExMTKysrd3d3S0tLR0dGCgoIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB4FS9nAAAAQHRSTlMB/v///fv8/fdT/QH9+MSpNAUK/2Xz/ATMj9LE9VfZJDNDTGC0mbnrgKutwUixiF+zOWOqRnlEbKjAAAAAAAAAApQFWQAAAf1JREFUeNrllNly2zAMRSWGIEGIjLVZ9Ro7+74nTfr/P1aSkrVZcmfax97xSCJ4BnMNggiCf1GSRj+8ojT5AxpF46sBNN1uT3+e2t92mx7CkyDafH3PBCIAoph9f22iYNTL5nOGkgrtVZDE2edmjP2wqNaEglsJJK0t/jFsYn0C2gAPwyzLWJaFIQej4WQ9YCR9Q2mIW8aKMeZeGScj8S3t1yFYWwsQVqpgK7BW1kGvJq/WA7bYmkbr5LWbN33HAjpsk7vA97SVOwqegWSPrWlJ8NzAtvIvQGIMFgQvSU0nwQNI2GMbIwQP9UlGwZNsElsdOal6KUg+tUw/SsnHYS7lY6scv6hywXqwX3Og4xZ8TOj6gTPmXyXcBFB2YAnIhftPwqmE3ZcL2Z7qwQh+gx115WO4B1fVGoIZ68HsIMz+OvO9RClHYbt534LvyF1St6Gcymo4uZC9vHTXarqbAgSAw90TSrgOCChuWsd9ZkgIdHXt19mHyZy12/9WA2/UnKAX6NvOrTqfkhiDBU3PO3B8aXZ91+9nLs1l3L2w6mqf3rFXqj831HJHd2DLLtX+lMmX0+q6tFjrd5kPzS91sdJl8h3LpV5dqOHBqOaLlZ+LYdnFpFeLuRobo3E+WVxPjdEWNmZ6vZjk8YHZH+fziRNzj/lB1OOxqhTHwf+m39AFIRkBth1GAAAAAElFTkSuQmCC",
		["MoveTool_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAMAAAApWqozAAAA/1BMVEUCWFgKoKBT3t5PTExyl5cAmJgkYGAA19cZJSUqJiZccnKcrq4/QkKKeHilwcEAHR062toAAAAB/v7l5eX1rxkA//8ZLdLX19fGx8epqKgA/PwA//+YmJiLiYmxtbUA+/tqaWkA/f0AAAAA//9dYGAOCAgA//+VxsYJAACkmprw8PBVV1cmGBgaFxcAxMQA1dU1Nzct+fl6d3d319eJa2uBdHSzqqoDBgYDKSkA4+MA6upU6Oh0fHyC29sAAAAAEhIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACBDlwVAAAAQHRSTlNrm9fnz3Kle6Pcu+v+/vNo1wD5/v8F//39/c8u/P35rvyOV077q2zlkv7//bfQjI/41f3ssLjYcmmdqOnC8zVKosSPfgAAAtBJREFUeNqFlWlD4jAQhkMFb90FWtukuQoFyimgrrpe//9f7cwkPUBY3w9Ap4+vk0kyw7oNRRF9lCojldguG6XDTIgeSJgsxUB0EMZwmhFYSmQpxA/AwKaZQzabINhsHA94bV7C8A/H9PbtY3L1B6QnH2/0p+OaZhVr8NXHrbzZWtL2Rt4+kHlUplI5Y7IPWlmrdBKDEvc7gLDZd0bfCbc5j/v92WwWzmb9fsxzy9E8a8BQUlzaROYqBgYUhiF+zWKVTyfwauwSIbiLa5tMLe97eRjEHT0kmiGbOlY32IrWdgqZCNpQhklAwgHf8h229t7yN0zbwd0hGGsl99iKlkoDAJvTZW51wVQlx+BETQOyjhhkLHriSvFvbJ2IuqJiIwxZBLI2Bt2hBtVjouRvyoNRFm0l4+NwLFWbas1w80y7zCLcg+k55qotMA+GKb+2lcbzEIchfTm4DmjV/gulRrjXu3+SXMcJrilBORh/YQjOlHwHOHXw2aPUnF6Ed7uimNby6R5XSHAHYF+tQ3AYysdVBYNz+F84bDhDzj84v7/6nKEal1JLeRSWboFYDbhQ5lJpzTm+GKBcNVAY4lqrS1dn2sFTyxPOEcdP7uAqkHDbcjtIZ6N1opJEY13360xhddKiy+JOnQHruFa9gyRuTwWmjDBeFLQ+BjtjOs/upojzeXnu9s9zLOfn5U3xd7C1yL/Rns0Xq+oO+tvNLkrvHRh8F6do7G637xviZXHir0uDhXwXTDT6hu9I5mW0ts68ZGNp1yNkM9dJme+hEBGsWK6pL/bdKVZ2vSyQNW5m+MZIxYaj+lwsL67nuQU4n19fLIvnFrbow/1ZdH49F6PR6DyEj6J46QjXcaNvnZ+GhFkx9jX4/Bx8sc5K7PbyxkzpdofU/HvGZGdnmXGjyByaKW6webySGR6eVuUcHHtLmGvD9OgcrCdsSvphwrr9OfKA+gdAs6eKzJs0sQAAAABJRU5ErkJggg==",
		["MoveTool_ds.png"] = "iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAMAAAApWqozAAAA/1BMVEUAAADl5eVzc3NeXl7X19eoqKjGxsaXl5e1tbUAAACJiYn///9nZ2d6enoKCgoAAAB9fX2srKzw8PADAwNGRka/v7/Hx8cICAgZGRkkJCQ2Nja2tra7u7vKysrY2Njg4OAXFxcVFRUYGBgjIyMnJycqKio7Ozs3NzdbW1tubm6MjIyKioqYmJipqampqamysrK0tLS0tLTExMTKysrd3d3S0tLR0dGCgoIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADclTTyAAAAQHRSTlMB/v7+/fv8/fdT/QH9xKk0BQr+ZfMEzI/SxPVX2SQzQ0xgtJm564CrrcFIsYhfszljqkZ5RGyowAAAAAAAAAAAb5iy9gAAAgJJREFUeNrllGlzozAMhsG2LFm4JZBszia977vddv//P1vbIWAIZGd2P+47DGD5GY0sS0qSf9GoyH4EZcXoD2iWDa960GKzOf156p7NpjiEj5Js/fU91UQARHr6/bXOksFY1p9TQhY2SDDS9HM9xH441FomrZw0sbUO/+gPYnUCVoJK07IsRVmmqQJp4WTVE0jxRihZOcZJCOE/pWKJ9FZ085CsXAiQVqpgJ3ChrJJOTl5dDFQ2bE2Ti+S17bd4JwGpVg3b+Bb0XkS+s+QZGFNFKmJrGhmeG9hl/gVYu+OnfbBmeBnV9Ch5AIwP16GB4aG+ySx5Qu+4lvQy9VIzPkVBPyKqYVghPkbp+MVVFKIDh7UCPorgIyZfD0qI8NnCjYGwBSOQ0v5M2msL+z9vcjXVgQnChpBtBRvtwVW2+mAhOrA4CIu/9nyPhDgIu837CL5j36R+w3hts+HlTa55+S4quhsBGsDj/g1buDZoEDfRdZ9J1pp8Xrt5DmaWZ3H531pQjZobDAJ72+qq8wnrIVjz5LwF55dyV3fdelYoL/N2w5qrfXrHXpnu3DCLHd2CHbsw+1NmvJhU7RKxLt7FuG9+mYulRRXPDYV2eWH6B6OZzZdhLqbbKma7nM/M0BjNx8fz64mUNhTJ5Hp+PM4PzP58PDv2Ev41O4gGPDeV8jz53/QbyFofJb4fCgEAAAAASUVORK5CYII=",
		["MoveTool_ovr.png"] = "iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAMAAAApWqozAAAA/1BMVEUAAADl5eVQ+v8A6//X19eoqKjGxsaXl5e1tbUAAACJiYn///9nZ2daWlp6enoKCgoAAAB9fX2srKzw8PADAwNGRkZ2dna/v7/Hx8cICAgZGRkkJCQ2Nja2tra7u7vKysrY2Njg4OAXFxcVFRUYGBgjIyMnJycqKio7Ozs3NzdbW1tubm6MjIyKioqYmJipqampqamysrK0tLS0tLTExMTKysrd3d3S0tLR0dGCgoIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABu36FjAAAAQHRSTlMB/v///fv8/fdT/QH9+MSpNAUK/2Xz/ATMj9LE9VfZJDNDTGC0mbnrgKutwUixiF+zOWOqRnlEbKjAAAAAAAAAApQFWQAAAf1JREFUeNrllNly2zAMRSWGIEGIjLVZ9Ro7+74nTfr/P1aSkrVZcmfax97xSCJ4BnMNggiCf1GSRj+8ojT5AxpF46sBNN1uT3+e2t92mx7CkyDafH3PBCIAoph9f22iYNTL5nOGkgrtVZDE2edmjP2wqNaEglsJJK0t/jFsYn0C2gAPwyzLWJaFIQej4WQ9YCR9Q2mIW8aKMeZeGScj8S3t1yFYWwsQVqpgK7BW1kGvJq/WA7bYmkbr5LWbN33HAjpsk7vA97SVOwqegWSPrWlJ8NzAtvIvQGIMFgQvSU0nwQNI2GMbIwQP9UlGwZNsElsdOal6KUg+tUw/SsnHYS7lY6scv6hywXqwX3Og4xZ8TOj6gTPmXyXcBFB2YAnIhftPwqmE3ZcL2Z7qwQh+gx115WO4B1fVGoIZ68HsIMz+OvO9RClHYbt534LvyF1St6Gcymo4uZC9vHTXarqbAgSAw90TSrgOCChuWsd9ZkgIdHXt19mHyZy12/9WA2/UnKAX6NvOrTqfkhiDBU3PO3B8aXZ91+9nLs1l3L2w6mqf3rFXqj831HJHd2DLLtX+lMmX0+q6tFjrd5kPzS91sdJl8h3LpV5dqOHBqOaLlZ+LYdnFpFeLuRobo3E+WVxPjdEWNmZ6vZjk8YHZH+fziRNzj/lB1OOxqhTHwf+m39AFIRkBth1GAAAAAElFTkSuQmCC",
		["PlayDelete.png"] = "iVBORw0KGgoAAAANSUhEUgAAACoAAAAsCAMAAAAkRNp0AAAA/1BMVEWIeXGlpaWZmJjl5eW3t7fX19fGxsaPi4iLgHmNhH6Kf3iMgXugnp6goJ+LgnyNhH4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADOEWlYAAAAQHRSTlMA/////////lTFLm3//4C0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAYzu44gAAAXlJREFUeNrV1dmWwyAIANBIEZJu8/9/O2ymLrSd1/Gh7cm5RUQ02/ZPx8E2bt8lQ7EB/HP95HaGe2njDu+DOwQJixj8AcArvLapRVKlTh8zBUckCOulKg4+B2aPJoj002wJPdpdghpRdLEvtD+vVoKikxhVqKywxb0OlEZJIoPKj72jD5l/oTKVrWukYwI1KtAkDLlCH1YpRZqyCwvFnlqBIyRPFQAtaxJVKrVEBZwzcLzSMdkzsFIoPb2B1obqSjXZwtuUAbS9bSszqR33HOjD/4/aLTZien0IY7uCP9UeQYwVaVReqGcAigpAa3FCo5xS21Gq3q5EhVNajF6kntraZHkoLWU6jE9LtpwUXxTWw2XlshPTKGarOiubUH5D65+o2owuF8EOJapVT+q9sm/puiaaFqAl2yUgu6CU31HqqbXFkdyE0bO1o5xTT3am2aqcdlHJEshS9WQLBpVWsAvmfqTX9quzu6OdX/Hdzd1eCPzpxdGP5bXxC59JDzFeZUB8AAAAAElFTkSuQmCC",
		["PlayDelete_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAACoAAAAsCAMAAAAkRNp0AAAA/1BMVEUA//+lpaWZmJjl5eW3t7fX19fGxsaPi4gA//8A/v4A//8A//8A//8A//8A//8t1dKgnp4X6OegoJ85y8lwnplqop9GwL1BxcIh4eBkqKQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD8c6hZAAAAQHRSTlMF/////////yz5T3Kt0JH////////////z/wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA4cVdcAAAAf5JREFUeNqN1dl24jAMAFAsvGASJ8CULv//o9XqyAnTVg8th3NRJFlJTqchLhinP8TlcuX4laObFo5p+lETnFurGK3NpP/DBdZn4fiHfEZO+lgjwVogcED5ulN20iNGuLS6FrgFixtIcsaDnBUCpo1R+QMAMLOzJO92aZQ5Zaef1VnKCYIyopjOibByKM5OSy2SDVGmv2yDarJGl7ZiUiaEzvwv8o/VtukqdKakUYhGQoodWt7PRdM2onmUGaVS/LDOG33g9Q8UL8V9jXQsIOkETEL1FHxaolnLBCgHGj3lAWvK4qaldEvrsuKkDlkh7isQLNSGxXOF/QyS1IDXD0TttD6AZpPTkVKxoXQ6zVwB2NlaZyxp497b5NblIb+PtC0cenn6EnfW6HVpd5BvaUdi1I4oa2HaN+tiFQChAGArniPT0geAd0GnfKI5ybrmHEoZukLKu830jPOk1c5cB9EQPnqpVEF752JDp3GjriumVWjmO8ZotK4cvfbJvqDu1rJi9RBe0N4VT1b7ekXfmqdY7ApBp5U6lV1ZXVdyCK+oDGAeaO/LFYCnQHToyoqVvhzltXjbjnUolkewUelqGh+wVuyeYlfzjmIFu6yZC/Br1R+crfBTSimuAj9gbs/+aHMVrNtmu1t7179U0NyT214IpR6SSmP0PvDBrw3f1DdSDh7cu5etNwAAAABJRU5ErkJggg==",
		["PlayDelete_ds.png"] = "iVBORw0KGgoAAAANSUhEUgAAACoAAAAsCAMAAAAkRNp0AAAA/1BMVEWBgYGnp6eXl5e3t7fHx8fo6Ojx8fHY2NiOjo6IiIiLi4uHh4eJiYkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACcW5egAAAAQHRSTlMAv7+/v7+/v7xHkS9gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA5amT2AAAAXNJREFUeNrVldu2gyAMRJsABrT//72H3BQhtn09vPSy9hqTyRBfr396duRT23eygh3cj09cq8hUSkY/ijc0wZRyOsVrQJogn0yU5YtWEpAOZSqlf+ZsldSV7FxhiMq2FdE1GkfyELIww4c/uN7E0hNb+79M+OniuTsAjh7j8zs6koVSnwR4c+1W6oK6IYAzmqiM5GjXrVY2NU+om4UresmKY0z+grpq+oYqayXgiuJiF4VoA5UtETpNln+jzFbmevolovBe0s/TySShGR7f0Xu0FPXAavsuimuyezyI44HqEmcQ6yPKkZJoS1w1M3O2q9bqaLFkCzpdxrfMpftFfBk2QyHoyq/hiGZBl1INBbLL9QPKffHQDI268r4uVLwVdFkExyPaovWibt3QoNTBgguFsFSbV4DuwSaUYknNoo+oFpsHVLs6QhS11hOFuCvri6MtcdE8xs/XtS0psTUA8CDap4C+4dP5Pnh+caC/EHSvzIP6A2tIDx5sv7b3AAAAAElFTkSuQmCC",
		["PlayDelete_ovr.png"] = "iVBORw0KGgoAAAANSUhEUgAAACoAAAAsCAMAAAAkRNp0AAAA/1BMVEUA//+lpaWZmJjl5eW3t7fX19cA/v7GxsYA//+PjIoA/v4A/v4A/v4A/v4A//8s1dN2mZWinpwW6ulJwL2loZ9Vt7RCxcI2zMltpqQx1NIl3dwl4uFqop9ksK4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACqw1IaAAAAQHRSTlMF///////6/y3/TnCRrM38/v/8//////f/rNL///8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAZRvw8wAAAjNJREFUeNptldnCqyAMhCWFAKKoXf+zvf9rniyIoM1FL+zXcSYJdBiGIaQ5Iy6f12N9RzDP9XFHnNMYhnOFccr4AAvW7AXrkqcULiyJ3p9bpeRz+4fEnnVJ9MPfW6kqvC7iIZzQlb7y3nF5S7/xrP7z5yIcxl/0du9uUo6UnRPx5/o6hQtjmo0p5I2V6dMLvL0vLHUAb205p7bhdZ/bRgTW7WFBRfiF1LShYyeGKy0GlP3JrQVCx1RgVL/WACgLy1RRBolMU2ERqWVEEirh1nl3EEahqHIuKKJVVGTt7zQqSjYr8b3y7mCa47MOoMTn95OcrAQcZucc6alrScq/94pIwB3NGGmbGllGfZkAQLygtkU9o0UyQsS5Rw/ZRtVAZNUOBXt2oLCiNRahvdkqzCgYRrWvU34D98a7K8pmTaxomsUBs65NJiSJmkfeB5smpBmAzlwPTX09PwSsKO31HfSpnsWSiFWjoHsD+GirA2DI6C8Mv8EKGmsDaLMqKhP15dh6b2LsUvHJknYxeqN+6iG0BTXmnY8DE1J+iFlTUXugTSpBUVFPegdq91QNOtbOfkGPZalmyxC+oDWVdLbk+oauuUXJ7AKmdMtVVHdlyd2NQUP4hmoD5g6tuRoDNAVGu1S7Wc3VoLIW6zHWzqy04EA1VQqnPwM1e0Yp1ZzOVzyeVL0YaNdqN5tylKuvoLQKcsFsf3MaL39Hy7HZzdE+5S9X/D2C6WuLeBHVYLhEaCt+sO//f75MIYMmU0nwAAAAAElFTkSuQmCC",
		["Reset.png"] = "iVBORw0KGgoAAAANSUhEUgAAAEgAAAAYCAMAAABuvUuCAAAA/1BMVEXCrotkVUH15s1zVTKDZ0QAAACul3S7poOSeVZ9YT6chGGji2i2oX6bgl8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACoOA8IAAAAQHRSTlP//////wD//////////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAje9QRwAAAJ9JREFUeNrtlcEOAyEIREdF0N3t//9ux2p76aW70KSHTiLOhRdEg6i1JrcIATnITiENUKJxKudUwXrgFmtCCuCQ9E1QEek6omxQRpuelrueAQHaR6S6QdvyeO2fg7hmUjlIdYBUVtJemuIyiM2YfSHD9t6e/kJF220m2UCVgKMZSzvE2Wwepz2uX5c/Dfq9l/0HvYOiBlvYqI0b/kHf0R2kewS5cCZ3VAAAAABJRU5ErkJggg==",
		["ResetOrg.png"] = "iVBORw0KGgoAAAANSUhEUgAAAGAAAAAcCAMAAACppkqwAAAA/1BMVEXXuY6lh2JLS1C5ub6hgl7LrYPfwZWMXzLEpn20l3GOYjb+/v338/AAAACVbEKcdU2hfVTr5Nzk2s3VxbTNu6Tl29GqiWi8pIrw6+Te0cS0l3m7o4XJs5m3n4K8oX7Dq5TBqZHayrTPvKnf0sXp4NUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC8iGANAAAAQHRSTlP//v///f7////8/XmCAPv2+pWlrsmY3NSNpdHj1eTyvsLCsZ6gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA7nNrswAAAapJREFUeNrdlutuwyAMheuUzbVNIQlJmnbdutv7P+MMhHRbpf1j0nakYrkc+4NApGz2+31TTdp8o+231aQIBewqSgHN9q6ito0CNhX1TwD3FfU7gL9/BtXfg+WlY0RmSBGx3e3IMbMpeRoRTfaaOKeeHSH6VMtlLOVZCUBZjLZjPscoIj2x6+fw/FJyeUOj8SVaPba9PU49UauL6mMtBjK6QruWZ30D6G9MUQXo56enIZRc682cnYAs73d0jp35gK8xtGZgvwDoqhuAk4e8x5iz85BWl3IFdNnZ4rQ0MTh1aAYFBDxhyIBs/wSArDjDY9njAHDy+oAJSh4B2em1LcQDAYehd3gEZnHoRQGrPesrwAb0DzFS+oOOR8ZuzdsVYNCNABOOebd40R2Ix9AtAIJV3wB6es+0OIwzYNgL3QJ0C6foHwEvulr2QQEwyPlnAOqMQR7SohyA06voRgsl91cAHFq9ptPscAwQn5OeemrBV/stAEQIHsVqjPcMaLRiu0coORxkBcAwi9ieOjlooqNIbmGv9ltADf0TgKkoBeybmoDmNz68Kn86fgCSODFbfix2YwAAAABJRU5ErkJggg==",
		["ResetOrg_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAAGAAAAAcCAMAAACppkqwAAAA/1BMVEU0dcR4ufBLS1C5ub7u+P6BwvZpquVXmNlhod5Ghs4KKFAAHkYQNmYAAADX5/M1c7y5yda51e8xa7Dh7PQnWZSJtePG2esvSm4zUnhQaYZnnNZ6kaqryugYNVkZQ3YhTYGlt8gcSoQtYJlDXHpac5CRpbsJLVweUI0nQWQnXqEoX6MyZ6NFd61Cf8NjepSLnrGGsN6luMvBz9vH1N/f8PsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAdMrzkAAAAQHRSTlP+/////v///v7+k4yoAPr05v7p+M//96Wutf/M+pi0ut7Dz6281qDMnt/g2dvzvc/+4ejr/wAAAAAAAAAAAAAAwrH8LQAAAbhJREFUeNrtltmO2zAMRVmHGUWUIjuOtzjLZPbu+/9/W68kx046D+2LAhToBQKa4iWPbCuAablcZsmE4YTxs2QCAgCVUABks0VCzTIAbhIqAN4k1HUA84S6DuDffwfJj+nwp2PI1THySqnaMf/cnXKOmkfvHDUHj7oJVnicUgvUp/aoS4C8Zf7oozHmVrFr94/b6pTLAxeI99664l0nD8eDUjtM68LUR1Uzr2VsPwPoKFS04zZEqOfGftL31SnXCy5sdPYYZHNdHjQavvBn3/u9+OAarI/2qN8A2LXk4R5r38tNHdZjPgFqLoQG6LHlwm9iw0/4BUC0nwEoKlQ6oXiPFeknj6Ax94DorP0VzD3teGMdd97juBEARnvUJWC/YVd6Rx4WykPHbMd8Aihe46rgtoxvfosoX8EaADmNugRIXvA2Hxx61Ws8MnPKqR8B2PhRU8PtgrfGCLs7eKgy1Z8B2FsVzxkAeEKrVmjIzwG0/YGD+W3fcHdHIG08wI9YT/bXADImp9JIbrwslVZEbOnXQ07vzAigl+dQtAZ1sua9kThCJvtrQAr9B/wNYJmlBGTX+PBK/On4C/kyMTu2O6nDAAAAAElFTkSuQmCC",
		["ResetOrg_ds.png"] = "iVBORw0KGgoAAAANSUhEUgAAAGAAAAAcCAMAAACppkqwAAAA/1BMVEW5ubqFhYWqqqpKS1DBwcFcXV6Xl5djY2MHI0kAHkYlOVR4eXsAAAAcNFNYZHQVLEx3e4E3RFVIVml+gYReYGMtQl03SmNETVlAUmpbXWBGUFxjbHhocX0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADBEUtgAAAAQHRSTlP//v/+//z+/ZSMsPoApdGl7szI9vawt9u699rc2wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA3ddQsgAAAZBJREFUeNrtlltvgzAMhTHs4FygXArt2u7//87ZDlDW7mEvqbRpRwLH5MRfYlqJommaKpukeCHli2wShADKjBJAVeQESPmMDbIm/QnAW0a9BvD730H2/8EyZoCZLAKxLGvmXW53gJKXdE48ZW1W8fB6X5fvAHUSwzngQ6P3/l3qBxeGw5q7FpB4UGvEFFx7PekIOOlahJpk7LblSQ8AYnSkUVKxt0SHsV5yfRCSU0ZuprqfddGAQArAjacFQPWmZ4Dr0xltVxzJouVKTM6IailCOHeAnjLgLJcBkn0HoCSd4c4g2gqiQR5c6J7bkVQCCNoPnQuzXOqZcJEO75abvgKcbCFai0z9KWjNNY8bQJtFVKFbXv0gp3YRoV0AdNcD4DhhsGi5XBP8lu8AjLPeOnkD3su+R606+sMCOH4PgM6I2TbFWuDC2rI13wHoqj9pOGGM1iekbWtY7c8A8r6n6N3RqwL1wTkXoj63nG5+A9DYyuTct15LBc8+9UXDan8G5NA/4CeApsoJqF7x4ZX50/ETUDkeOLUjDbsAAAAASUVORK5CYII=",
		["ResetOrg_ovr.png"] = "iVBORw0KGgoAAAANSUhEUgAAAGAAAAAcCAMAAACppkqwAAAA/1BMVEVboeGw6PtLS1CIxfC5ub7u+P6k3feX0/RlqOV3t+oKKFAAHkbR5vUAAABYmdYWPGi6ydVop9wqS3FCdqnh7PPH3e8cRHIxWoWGvOs3VXc0ZZdRaYZ9lKsWNFlQi8RadJFKhbumuMlDXHuTqL3d8PwnQWQ4bKJOg7RfkLtkepRin9KLnrGNtdqou82izfHBz9vH1N8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAov5/JAAAAQHRSTlP+///+//7+//7+koz7APSl5fao0/f4rLf/rMa0zJjnvODerdb/ns/Z273uz/Dh/+jrAAAAAAAAAAAAAAAAAAAAJjIigQAAAcJJREFUeNrtltlynDAQRRWYK0stjdgMDMzmsZ3Y2fP/X5duBNiJnSq/KE++D7S6daWjBapQ2+02SyaeXPH0m2RiBAPyhGJAtkkJ2GQMuEqoCaATagJ8SKh3wNsAyS85+Ws6fxNg3esY4fNce45rjigdvfo+evKrGDhbnsvwZx+ajQLoI/Ao0TnX7+CH4/nQLDndouTYiNVDD8fbS2+t5tl6GYuztK9psc+T/gWoPOpKIqc52qKqmtHOORfKIjp5lVR/MTe1DPqKzxWHn+WDb2dAZVdNABPFPRaewrTH3MiqvLZSn3IjgOj8gZKqqZXjUqNs2LPHHc4MWO1RfwJYgzhkj42xd3zwvlrzJwC3OrHvTIt97dGLx6OlCIj21wDHPfxJHGEqhH4AujXfrQCL69qYEvUp3vyBd0059sUMCMa8vgMKOprFYdsdz+RdeAkwGhdj+L6+4eAcwY/sMZ9c8w+AipIeXtsY3zNlWj6htiY150oAs9UcfnHp+7HFMCrl+QJAUmbAao96DlDkgjo5CnKGrlOhI6LiJPUpV41bAEqNBXd2oXA3nPCTBKCCoyf7S0AKvQPeAthmKQHZ//jxSvzr+BuwdjKQK7xbZwAAAABJRU5ErkJggg==",
		["Reset_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAAEgAAAAYCAMAAABuvUuCAAAA/1BMVEU1dsR2t+9LS1Bmp+O5ub6Awfbu+P5VlthFhc0AHkYOK1IAAAAPNGQzcrzX5vG6ytgwa7K40+4nWJJom9UuS29ypNrJ2+oXNFkiToE3U3UtYJpAfsV7kamDr9+Ouuehye4WQnknQWQmXaBEXHpUa4dedZBGd66Up7zh7PMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAXlhlUAAAAQHRSTlP+///////+//6MlACm9vjn7P3N/6f/9Zi6q8/5y////7me36y0u9vW+AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAW/c5awAAAQJJREFUeNqtletqwzAMRjUnVWzFdpzL2vWydvft/Z9wst0UEloIrc4f8Ql0QMgkUNe1ehiWAGvKh2EViyoBWKTKQoBSSYqeBEiilQCyIrHVxESzAyDjV7liWxRHz/U0Zsycrl1t9rYQ6R3xJ1ZjzEuFfth8H7ox0yc2XHfToSTSU3hAexxSZXpc273edWPWz9hYPeeWCD2FtMKrZimuj6mf820RTEkDW4K8Sgf6N6rcJUcRzLku2nyhD3HQpUZ42yLaS+6Xi8g1eHDnQd32e17VuLtEFf51+dws4s3ageCcl4vAmADBkDMRC8ESkQ2xnzJ8mIWie5AU1UpCpCQ//kK/o39z7hwGO4QWFAAAAABJRU5ErkJggg==",
		["Reset_ds.png"] = "iVBORw0KGgoAAAANSUhEUgAAAEgAAAAYCAMAAABuvUuCAAAA/1BMVEW4uLqFhYVLS1CpqanBwcGXl5dcXV5iYmMAHkYIJEgAAAB4enscNFMkOVV6fYFZZXR+gYQWLUw6RldAUmpJV2tdXmBeYGI2SGFocX4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA55BsrAAAAQHRSTlP//v/////8/oyVAPmlrvPS9qbPusf5+LnbAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAdacdPgAAAPRJREFUeNrNlVFvgzAMhDEs55g0oWVtt///S2d7QxWISqj1w+4B6yz8kcMSdOM49m9LIZ1iurelKAUNAVJQ30WAFBMQzMNFgj4CFAv6f+9os0kGmJNXoAxDYhUt3q8A7a0/rcUQAb6t5pw/lVOlztPi5QRondZDT0DEuJBVtQSciKZr+vPWqGmr5yBpv1ESWdRC1nfv5H0QrWUDfHGYRSCatXGjh/cjbrQPkqqPtnr2RvuqNrv4chQEjXXHbNUHNRfdkc94BaQ3X33NbCe8sUVd/GEQ5dyoZGnZVKlVEanF+u5pygdBrygSNPYRoD7y4x/0O/oBFvgS4YznQqMAAAAASUVORK5CYII=",
		["Reset_ovr.png"] = "iVBORw0KGgoAAAANSUhEUgAAAEgAAAAYCAMAAABuvUuCAAAA/1BMVEVcoeGu5/pLS1CJxvG5ub6d2PZlqOXu+f53uOoAHkYNKlIAAABXmdXR5PIWPGi8y9dop9uHvOsbQ3BFeamu1vDG3O82VHcuW4dNisNzk7AXNFkxTG46apk/dKnd8fwnQWREXHpUa4dfdpCWqb3h7PMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD6+kAlAAAAQHRSTlP////////+/v6MkwD1+aXm9f+r0vz4rLnn0Jilx9T/nqy0u9b4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAjp/FjwAAAQhJREFUeNrdldmOgzAMRQ1h4sQklL3QdtrZ/v8bxw6lEqhIaJqnOS9XN5KP5EQCyPM8fRmWAGuyl2EVi1QEWJRmMURZyqK3CARREoH/Lop22auXRObaToleqfbKmcwdJ5Jnz2+WININcZS01h4V+v70NTZzpw88cDbLoQ1R6fFcSnKtsCvKsrmYezcKD4VZE0R6CQ8Y9OTCCko6+taEDF1Ees1zEdOTnlZ51/qbL8a7R6/2i06f6AcZdOHAHXvE+tG3RbBEBlocnSRX3VWaV7VzBxHBmi2RwZ/L9Nws4s26M8G97xcBWQeDJSdXYmtwNREVg5yHDo3dKfoLMUV5GkOUxvz4R/od/QKefBv1fGs8SwAAAABJRU5ErkJggg==",
		["Resize.png"] = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAMAAABEpIrGAAAA/1BMVEXm5udwamelpaaZmZnZ2dqHhobIyMu3t7gCAv0lJfba2uV6eHdFRfe6uujHx+hYWO6Kiq6ZmexLSklPTk1XV1ZqZWJnZ2d4eO6YmKgZGfo3NjVUU1NcXMhpacaLi++2ttEzM/eWlsgsLCs9PT1MS0pjXltoY2F2cnF4dHOpqeslJCQwMDA+PttKSEZNSklkXlxnYl9mYV9lYF5pY2Bra/NfXFpgXVwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACcN6rAAAAAQHRSTlP/AP////7///////r///////+X9PAw/f///zHL////////LJPL9JOTy/8NW/8NW8ssW5tb/5ubAAAAAAAAAAAA9XjnFAAAAeFJREFUeNplk+mioyAMhTFAGFTUWtc6VrtMl7vv7/9oE6i22nt+BfJJiDkw76bPj9d/pNePz8kmG4P8EEx0yO+BQwAKgDsBhcFhBuQnSkppc5aiCOCU34A8AJASFAonVHYFQT4CbwF9zpVgVwlFGxC8DcCJ8jBJOwSIOF2AI4dfeUcAP1ogpwCE7/vTNC0FbcucgCPdHcswXE+BdRiWSP0cCaBa6Me1ngO6jn2khj32zm2Br1CH5lbA0PLLFuHv7IdTg/7ZlHUYjUAU1qU5+9Qs/2aN5GgvFZX99QjTlxFdWiCXDcskoO3Rj0x0XjidI+N6EggyY0v6xUIMJ2unsZYFlg4YZmD0HydNtcaZOIDGq5DUjUBHSVQ0fgvs5WiDKqkHYAOXPQL2LL0CPBlPSCoYnCNT9hIMQJUk7V+nNkmq6gIEL+y5cDaCqn1KYFDy1FYu4MUz86iGUhW0mkordzPYaN3ChmKZ0rBWBSDGse43eNWi13GMCMXKGiaVCu00xVW+v+7rGBUd4CzX8K4M48V03Is4LDveDJ5cZbwzJpo5KjIdz1aj7YnAe9PiJT88nG0j1YwQSjbb2dPbFZOHQU4pdvePd5sW5E5l/wSXRbr99bo97+Fxt19m2XK/e3y47f4HnYkgfIdVFSIAAAAASUVORK5CYII=",
		["Run.png"] = "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",
		["Run_dn.png"] = "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",
		["Run_ds.png"] = "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAMAAACdt4HsAAAA/1BMVEVlZWWHh4eXl5d3d3enp6dWVlZISEhnZ2ezs7M3NzcpKSkcHBxmZmZmZmZkZGRkZGRmZmampqapqamoqKhWVlZZWVlUVFRlZWWXl5dXV1d8fHyDg4Orq6uoqKi0tLRJSUlBQUFVVVVbW1uDg4OGhoaBgYGampqVlZWlpaW0tLS1tbWzs7NLS0tLS0t2dnZ8fHxwcHB/f39/f39wcHCOjo6AgICampqfn5+vr6+1tbW1tbUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC8n0GpAAAAQHRSTlMA/v7+/v7+/v/+//+I0a5vOa+Ja2mLrVWtMxjPDs8YidUO1W2JrWmJLj6J1XW9LlVthb3VDlUu1VVVdQAAAAAA8lsctgAABAxJREFUeNq1l2lD5CAMhgsUsONcjreu7qXufd/7/3/YJnkDhWmr44fNl6EheQgBAtM0E3L9e3Nw1YpcHbz9c908St5srqy1RoWabfvu7Ztdva8PfxlHErPwl7Htu79PdnB/srHkzj4mixMFIdrNg4hDcucx2XpPpW0L5eG97q/P2FIMszsQYHDPwc+HhmervYH0hPZuyn9jxWTEWxmCIMKrcf8Dq/2TgDZZnE36D2Y/yMQkgf2RvQkEejgTowRZ/eQ/Rkg9ye5mK/9t5T8k9D1CoJ+X1fpTepwr/LcJZY+amo9VArYCqBG1Xm3t197/zlrWKcCK9IgtJTWJwIf1c/L/ziqjBtLttuKR80SnyypKzI1LgFcICiLHxqejA3c+2l51asQtN4f/hS0ADpbiYJJ/r3IVIALwkkpPRosVlwBuWCRdVdJXhmDiSgCXZQDee0mxuPEkhIluhiIEzgkTF+y/NvjMAZgcixMAMXsVehMgrglw7IzLAB90NB1YZ6AqR91GZ0AuzkdO4wsFcPktANZhXmYAQJWMAvhGAPKQkiniQ+gXVAcrAIEAKLMRANoKpwJAmnmIkBJtrR2kJXCAFeC0mQMAAgC4SyoAAs8AlwHzZikAXwCKC0F2i++HzYCYAMtmAYCPyCsATi+kyqtvOozIgEUTFSCEGLogv14ErBKAbgwogJgAge2j77qOtRQIC0O5LXBuSjcfijAEsL0P3axjFH2SLTXJOPAvN/pusAuASUOG2YxMIJ02u0o1Cyk4838A3eMBi8CpxrySNZLAzVLle5YcetrZvIxL3npp3dSrbI6o0grHwBtpjp0zDcgrUwGwQyKd59OAj0zI1p1OpiumUAZA2zbG06ZJmze7dZINAYgOqpC2RrlFI5fVZ51HeZLCG5J52kgxglVqYpSDR/uai+LTDiE4Ld0hWYdkLftSI8qnDAeDS9o572+85fA49En0hdirVIGC6tmPiyrNQQqhEtIT09VSaVA5yE3KevOeYuOixdeLyaGUZSXp0OQyQ3uAZ4SL5TmtjgdhN5E6J056uT7lD2ftbghcYLIl9HJtntMhVMJuwv6zkANomiP5drv7y4iaAZEPSpDnQzsp0qn+wS+LN9K5nBM/eCaNMIzEz1tyXT7TjkCIxtoH/GPyX9UPxWNUM07E2DsxTcF5lCXcy5WcSE8nr5jxZ57cUh3GqRJQEPaBMHUU+ZHM7vtT/kpghJzOYjnwJIkc4r74x+X4H4ZjNZnh3JYnCfVM+4bzz2uhZvs80VTLpTjMVC3o1fSfpvOToIgR0fK+XN/7v+3I9wNWzjPU2PuGT5lIV2stUpinZ1/J6gVu4EKkoC1WO//5Xs8XcUsW8/Xj/sBf/Li5vUQJubz98uliyu4fjGJJCQoYpmMAAAAASUVORK5CYII=",
		["Run_ovr.png"] = "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",
		["SelectionDown.png"] = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAMAAADXqc3KAAAA/1BMVEX08/Tr7e/q6ekAAADGxsa4uLgAAADU1dX6+vrm5+ZJSUmfn5////8AAACmpqZNTU1/f3+gn5+pqanHxMfFxcXW1tf39/ZWVlafoJ+srKmysrKxsrG3t7eztLO/wL/MzNDIyMja2trb2dvo5+j6+vf39/YqKipQUFBVVVVSUlJVZlViYmKCiIKYmJidnZ2joKCqqqqioqKkpKS/v7+qsaq8vsG+wL6/wsDMmczHv8/AvsDNzc3IxsbX19fV1dXg3uAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACyZNnLAAAAQHRSTlOeQ8oA/vxS/fz7oegILO2TC+gPL7CKd1PoMEpxq9n/GVMw2Hcv0wYTIXIPDSlrklyXvN8EJP92/gUg34vPDVDPsgBpRQAAAOhJREFUeNp1zYlygyAQgGHSxcoWRI1H7vtqk7ZJ77t5/7cqCA5q0n9GZthPgAAEl82CAID8D9edMLyqFd50Ngpu7x+l5DyOY867Xc65lA93kYLtwbNJu4xH+7V+Y0DHJb0UKx31isd7Q496lag3aBcA/U//jbr84S4y0E5prVc1M9D/Rvc/TZ9LAPhCX41MdAoOpr4rTSoQZYhmzObJewVgNi8EkWVmUMIkQ4a6428d4ONCA2Pl3oIAWDAVYgsaJyAhWhaTE4BczVczOIXlirH8Sd/aAGgx8iPOnABBcrepAizFWRD2s/0BY3cTrERSIB8AAAAASUVORK5CYII=",
		["SelectionDown_ds.png"] = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAMAAADXqc3KAAAA/1BMVEUAAAB5eXmGhoYAAACXl5dnZ2ekpKQwMDClpaUAAACGhoZ5eXmJiYmZmZkvLy85OTkyMjJSUlJ3d3d3d3d1dXV3d3eHh4eJiYmXl5c3Nzdra2tvb29qamp3d3eHh4eZmZkbGxs3Nzc1NTVVVVVoaGhiYmJpaWlqamqGhoaenp6VlZWampqlpaWlpaWlpaWkpKShoaEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAqIW8RAAAAQHRSTlMA/f1S++f8oQgsKqyKeqIPkwsMSXPbFdXSUwgwlDBXQwYhcilca7zftDOJpyxuna7HAAAAAAAAAAAAAAAAAAAAfqo7OAAAALxJREFUeNp1jtcWgjAQBS8xrhJ6x4q9t///OglyJIk4jzObzQKwBya2Dcm/sJ6Eoe+POvxwMwnqsJ0fhwaHfVSHYG6ZZLuV3JUyw7Ns1nw+cywtMSudNgFJpgcniD4hdhhT5lmKlmlScNbhLPDFVUPSeSwVfxJKiFzevqFiESsBouAtLjRyt/XlUg8QJUlPF12PAU9qziuYiCsRcS//CfDqUIpfj/OLyIvlVpOKnnmPri943NHPrXe+Wa6UN62DCj93yobgAAAAAElFTkSuQmCC",
		["SelectionDown_ovr.png"] = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAMAAADXqc3KAAAA/1BMVEXO2tzd7u7O6emy6+u13dyq19fn8fG/09D/qqoAAACv/v7M/v2N/v7x/v5J8vIAAAAYtLT7/f3N5OQAAADL6Ojx+vouvLyuxMa62Niy1NS46OjD19nw+vry+vns9/c0rKw7trYlurpVVVVbwMBV1NRa3NxX5uZqFSp4PDxwUVF/f39ypaV2r69gycl919d+6OiNjaqfn5+Ux8eZ3Nyf6eme7+6knp6qqqqtqKisvb2zuLipsbGqt7eux82uyMizzc0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA88/W/AAAAQHRSTlMxW9MOq9WFaQMA/v7++/tLqQeRLO2uc0wqzdpSMnjPIjiNAzUGrM4MERkSKEdanMkJCGmjGOgtDDUfL1Z8KXWAMsE9hgAAANFJREFUeNptztd2wjAQBFBjg2EsBLiBKaYmJKRDEnr5/7/KIsVIlpknae5ZrSwgbJoJQ8DCuN0yM2mPCN7njUIeZwRvn/VCPl4JFt+eUXu/qycCnD0z3f11ObYVo68cNwLQ6TG9Z+XnqYRdNw8X6gQsD9oIY+V1BkDA/kMQ9aGgGrFbbEuDl4BxWXO786UBrCiDAPA1SOQI57bccAOchlwkQA5o2JVQgjGBJBa9UwCkV1BXdRrQFrcmv5SDhxKPf5w7E/DjVF0U0BMD/x6IxzX5Awh1HWff2gpRAAAAAElFTkSuQmCC",
		["SelectionRotate.png"] = "iVBORw0KGgoAAAANSUhEUgAAAB4AAAAgCAMAAAAynjhNAAAA/1BMVEVwamfKyMhHRkXX1dVZVVS6t7ZqZWI5NzZhXVqrqKaZlpSMiIZpZGF9eXeCfnzAvr4tKypmYV5kYF1oY2F3c3FAPTyEgH1nYmB0cG55dnQiIB9nYl9hYF9zcXB2dHSgnJukoZ8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAymUU9AAAAQHRSTlMA//////8o//3///9M+v///6nZaG7//4YOuf+V9CiO//8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAmlAaiQAAAPNJREFUeNq90dmCgyAMBdCgQUgQ6952ts7/f+UEq1VR5rH30ZNgCABLCkTbFBI4DWYZJuipGZb/qXgLZVpDAdqySOpUUfTREdk+CNDsu40ZBmPM4h1ct27Fzcrhil3kdV3ja4ivaLouMx81NjhXyO+j+XAwVso+bSiAH2ijA1o7b9+irTzY5IahJfedZk+K+xT3jtSF/TlXjrUSvp+wd0z6opTSfFv3NjoJM5H05SpEu00TaUloyiVPrjaPoqdPEy58X7U4Mt2OrF5MFaQ4V3qncbfm/W1nnnvJ9dE2lm6ZmPi4rLBFrYmYx7M9P37ZjR7enD/71QlJausUSQAAAABJRU5ErkJggg==",
		["SelectionRotate_ds.png"] = "iVBORw0KGgoAAAANSUhEUgAAAB4AAAAgCAMAAAAynjhNAAAA/1BMVEVFRUWFhYUqKio3Nzd4eHhXV1dnZ2dCQkJGRkYaGhpBQUE/Pz8+Pj5CQkJOTk5MTEwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABMSbbRAAAAQHRSTlMA///+////KGv/TKnZi/m5AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAjY66OAAAAMFJREFUeNq90csWgyAMBNBAHqBS/P+/bQBbhBKXnXPccCPgCPBJQMQjaGAZVTSoqve4P6lHTLCcKOjrAOIeLG0TIe42lwGAw2YdiPB69ABx8m3bEL93nG4XUR0PvCaUf++ni/FVC9Kz07RBwt4+M6DZMCThYHMWkmhxZCGSvGZWdI7kXHAuL6o64ltvXCMXucY9Zb1T49tPuYNSec6uYeSiBA9Mw9Ezk9x1ZpLxa0cWjlMbZO17cYsI86pnKZDhz3kDZfUFVfdFXiAAAAAASUVORK5CYII=",
		["SelectionRotate_ovr.png"] = "iVBORw0KGgoAAAANSUhEUgAAAB4AAAAgCAMAAAAynjhNAAAA/1BMVEUA//+U//8A//81g5gA//8A/v4A/v6i//9Dma4A/v4veo5Iordy6P5o1/AlaXwD+/xiy+R79/87jaER7PEF+vs+kqcp2eRbxdwU6e8zxNFBscMbWWoZ5OsW5+0t1+Qo4OtD0OI6vs86vs06vMw0yNYuz9suzdo0xNMp0t0h3OVAtMZdyOIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABHQc9nAAAAQHRSTlMF/y7/TY9t//+w//3////P////sfL/1P/M9fn/m/fm9fqQq+EyS4HPo2fJ/wAAAAAAAAAAAAAAAAAAAAAAAAAAidGi7wAAAU1JREFUeNp9k9mCgyAMRTUSJIIC1qXtdJt9+///G0CtWDu9DzxwQnJJIEkGMTwKIXeH7/e3ZC3gJOpMNMjgX5qJIyFbBwAjkTnVYq83yG8DGAYaAoTcHhjAInU70sIvQndfcQLgdeFBEVYfQPgDERYeFVectSd8gUXtonKacNZu+TPMzlFmVfVUtZPFTMYdcLyrHRY7IQabkvhHzF1jikJq6nbSVaqbE8mlfdxL5JwjbaWQ5lcvsEvgBODyoG72adlIvuweBLkyTW9Tdb7FyXCWzmWapqqfsd/38pVNqVKPL1fsbAWR7gfmcfM5WgNuSielrN/PB1zq62G06aQ8H7F5ne7FMKYjvuBkjG3uYGKPsJkvHeGxtjXRwFanlY7HOeMAbdktHmvk3PeDbv4CTNgqZWj1zoFbq0rTE6Fn618Ses55mPe9P+Ymdp881h+k3REn4kQCowAAAABJRU5ErkJggg==",
		["SelectionTilt.png"] = "iVBORw0KGgoAAAANSUhEUgAAAB4AAAAgCAMAAAAynjhNAAAA/1BMVEVwamdEQ0LY1tbLychYVFNqZWJBQD+6t7dAPj6MiYeZlZOrp6ZhXVpnYV49OzpoY2CgnZtnYV9kYF15dXN9eXaBfXtoZGJnYmB2cW91cnB5dHHg394xLy94dHGCgH/Bvr4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABR5/knAAAAQHRSTlMA/////yn////////8qf9s/5vYqvv/TYsxSI///3b//wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAeTVbngAAAOpJREFUeNrVktmuwiAQQAeGQoHaRVu3u/j/f+kAA1SrryaepA/NYVYAWNEw8FmsdQF7eCXn0SBhRneB46YzGyWaRQTUkz0kK21PtFp0D/bsMOn/3xCshZrW2qGMoO1FQg3VXn2yP34QmW7dF2sHSmzDx5Ib9lT4OZyDpVmgUULTAfpUHn7J2kPVrTjl0jU3lOJtyZ5L+yv9dKx1WR2PhR6o3L6MljUHS0Q/w1Q19yaRV2pmgEGV7Mekb6xNaI205t52eePJxnfQbFv3UTt4o8/Be8i6jfT1UVxMtjSZ2l7a31jvb5h2kRN8OXch3gklx1pFdQAAAABJRU5ErkJggg==",
		["SelectionTilt_ds.png"] = "iVBORw0KGgoAAAANSUhEUgAAAB4AAAAgCAMAAAAynjhNAAAA/1BMVEVFRUUqKiqHh4c1NTV6enpYWFhoaGhCQkI/Pz9CQkJERERFRUU+Pj5MTEw/Pz9OTk6QkJAeHh4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB2cl5tAAAAQHRSTlMA///+////KqltjkrYqp/5//8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAh65dFgAAALlJREFUeNrVku0OgyAMRUtLi4BO9/4vu8r4UMC/S3YSE8nx0qsCcMFl4LcwC5/XNpO7WAWtSIQ4NGNVimVDxhB1dksSkU2i804w63f24b413tLqfbMhhw/xZMbtS/gQoEm8TEaGdRIvky2Da3HXFxO46jD01kXVhrrRcj5P1Ou2t45bB40V2eE1dKtWm4NvOg7vddNLrvb1Np0D91A9ZafayXlM4ElDtCjlfqVK/epe2v/zryUR4M/5AGIJBV/nrI1ZAAAAAElFTkSuQmCC",
		["SelectionTilt_ovr.png"] = "iVBORw0KGgoAAAANSUhEUgAAAB4AAAAgCAMAAAAynjhNAAAA/1BMVEUA//8wfZGV//8A//+j//8A//82hJkA//8A//8A/v5DmK07jKE0w9Fp2fJy5v569P9Io7cC/P0zydYG+fsr1+IV6e8/kqZizOYT6u8p2ONdxdw5u8s2xtUp0dxB0eIc4ekY7PMkZ3syxtQh5e5CsMJC0OJgyN8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQeM9mAAAAQHRSTlME//8t/0z/b5Ct///w/////fdD1PDL//+xyv71MdP0mfv/18r+3f8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgXbrbAAAARtJREFUeNrF09l2hCAMBmAFWYIiUrfRWbr3/R+xCIGhh5nr/pd+JORorKoslxefS/UklNJnz9mRh+5MSB/BSncIWvdH9HdxgDK5G+Jj+rdxe2X0r64BycpbzrmSuVN5Q9W1Dx8yp2LGzs36Hlh1kkUWsieNT6x2volYLifUhkxtfW+PDDpybxWP5ddYbk3qbc+8KLep989ol3T7CYdfI5sRRpXKO+yuU2+QoLLugfFqQibHQ2KFl+MrIcbOAF93hpx9duja6EvBu4RpidzOYbakWgo5FaP3qDcQTMzF6DZ8rx7clrCTykb3LEe/JnD0yrhGZuLTsVf37YelxQzhbreHm4nrwcS18zl/CJaWjaXlcYdD2OMfgsZU/55f98cPnhbYob4AAAAASUVORK5CYII=",
		["SelectionUp.png"] = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAMAAADXqc3KAAAA/1BMVEX08/Tr7e/q6ekAAADGxsa4uLgAAADU1dX6+vrm5+ZJSUmfn5////8AAACmpqZNTU1/f3+gn5+pqanHxMfFxcXW1tf39/ZWVlafoJ+srKmysrKxsrG3t7eztLO/wL/MzNDIyMja2trb2dvo5+j6+vf39/YqKipQUFBVVVVSUlJVZlViYmKCiIKYmJidnZ2joKCqqqqioqKkpKS/v7+qsaq8vsG+wL6/wsDMmczHv8/AvsDNzc3IxsbX19fV1dXg3uAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACyZNnLAAAAQHRSTlOeQ8oA/vxS/fz7oegILO2TC+gPL7CKd1PoMEpxq9n/GVMw2Hcv0wYTIXIPDSlrklyXvN8EJP92/gUg34vPDVDPsgBpRQAAAN9JREFUeNp1zYduhDAQBFBfWOLdGAwc5XpvyZX03u7//yqGYLDJZSRb1jyNzBwdrzxlWP10lkZvgsey09BC9uWdgOUKMXuovqkhQ8TV7O8iZgpwMbFB7Rd5T9RqLt7OVEuIrAGTlHIgOn7bMJsTcc7VJrUgTIteBefxqwFTXieJDfggDlACTCto9z8JdDgkjxUkYOVZQ/+dvxg9H+7CAnpDF1wj4A7aBQxgrLunXxn1ctje6lqW13h0s1awv76XUogoioTodoUQUt4dQgWXnSC4sBJcdTb5H/55M77v/A8/u3ETrFj6onUAAAAASUVORK5CYII=",
		["SelectionUp_ds.png"] = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAMAAADXqc3KAAAA/1BMVEUAAAB5eXmGhoYAAACXl5dnZ2ekpKQwMDClpaUAAACGhoZ5eXmJiYmZmZkvLy85OTkyMjJSUlJ3d3d3d3d1dXV3d3eHh4eJiYmXl5c3Nzdra2tvb29qamp3d3eHh4eZmZkbGxs3Nzc1NTVVVVVoaGhiYmJpaWlqamqGhoaenp6VlZWampqlpaWlpaWlpaWkpKShoaEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAqIW8RAAAAQHRSTlMA/f1S++f8oQgsKqyKeqIPkwsMSXPbFdXSUwgwlDBXQwYhcilca7zftDOJpyxuna7HAAAAAAAAAAAAAAAAAAAAfqo7OAAAALlJREFUeNp1jtcSgyAUBYXcEHvvJab39v9fFzASEXFnfNmd40XTOHr/KXjMeP31VIeWvFPV5vohxAkVZxxCSG5OB+adBnBS6S4dAAABaCeDnFqabpJPbfiRr6VB1gewRz6gA9xBsiYUwhoPXMQn2yCU6K/LKBOD1fAQWhgjDkY45iFKBs+S5QWdryw0DiguuxCPNCtJxbxXI5nksKFhX5+XEqcjO7ItfN91VwOuvys89i9jIWMY2nz4AlWsCj/v/Vq7AAAAAElFTkSuQmCC",
		["SelectionUp_ovr.png"] = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAMAAADXqc3KAAAA/1BMVEXO2tzd7u7O6emy6+u13dyq19fn8fG/09D/qqoAAACv/v7M/v2N/v7x/v5J8vIAAAAYtLT7/f3N5OQAAADL6Ojx+vouvLyuxMa62Niy1NS46OjD19nw+vry+vns9/c0rKw7trYlurpVVVVbwMBV1NRa3NxX5uZqFSp4PDxwUVF/f39ypaV2r69gycl919d+6OiNjaqfn5+Ux8eZ3Nyf6eme7+6knp6qqqqtqKisvb2zuLipsbGqt7eux82uyMizzc0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA88/W/AAAAQHRSTlMxW9MOq9WFaQMA/v7++/tLqQeRLO2uc0wqzdpSMnjPIjiNAzUGrM4MERkSKEdanMkJCGmjGOgtDDUfL1Z8KXWAMsE9hgAAAMdJREFUeNptz+cOgyAYhWEcHYJ0OOro3nvvff93VVBRwL6Jf86TL0RgsOrJlwS4vcXtGRBy239hpGD3pP2BVgfjYjl9JoM2JoH8he9SUDQRyH0RRynyxbsTgyWBbyGMEMJYbYoAHLpTspL/j2ERH1BQvR13UXJQmgo4sNgKIXKaKeyfIVmSENIvDO5BtlP6MvBCEfTZIIJbAYoVXtcIPlAueFCYH6EpBs+HKYHV1sy1WRJYTyq5xkMCvUZNrt/o0sftqpxtG8YP6L8dZwrJedkAAAAASUVORK5CYII=",
		["Stop.png"] = "iVBORw0KGgoAAAANSUhEUgAAACoAAAAqCAMAAADyHTlpAAAA/1BMVEWooJwxMTFjYF+fPkOvNDmNjY3Mpp4jIyNvb2/gZ1v///+4KDCHh4cAAAD0Z271dny3t7f6yMpOTk7OLTb1hovySlL709X0WmJMEBTyOUP4p6rdMDroMzz5trkAAAD3lJhiJypkNDaXIiloFxsAAADyU1uFHSOHRUiLNTpqHSH0fIGYmJjOZWr6vsDMRk2xSE2zZWj4naFWVlZ3d3exVVnNVFnRcnadV1qoqKiyXWHOXmMAAAAAAADPPUTFxcUVFRUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD2e8WZAAAAQHRSTlPN/vn//zjrpTD3AP//Lv7+///+//////////7///6O//////8L/////////v////////7///////7//054//+vYHlWPAAAAh9JREFUeNqt1Q1vojAYwHHU3e4FpCL0QDdGeYeCqOCYOnXf/1vd04IWLw53yf0Tm7T9IUqMlX59OQlegXSa9HQ6fQtaGkhbZViW09uVZZVNuJVAZtWjpmm/bwc7Q2X7I+A0Ux7thXYbs+WFPcwyTsdKNZ/btnZOmCbbns8rZdxQxWF2od3KZtIR1HDWDPMWbe0U4NoxFEENjnmCNAE0rilg1np9IWu+wKBBBaXUaHM6ndcoRYIitHHduDbqFa92jDfXfQNV73abHKEuZdKNjZ3LW4GMY2b5QtylapIgFLsU5Xkc1zU14DLgBt24eZ6QXO1QslTRhiBEaRyz+7orSnM3Z2sq27ym6hIovDfcDjGFcrIHqv5FTZKobaMR0D0odU9e4XJOTUHDBKamyWjCLnoFxYclMc2QjEJBMSYkCcMQ+JmaZkGKcESKwksxFnSGjyRNMOAwScJGhWx4SCF5NhNU15+fUl/GkOdhHBZpgfExPeIHX5ZlXdcFlVmWxUafbXqW1wwRX5PlDo1gK2L796kVtfv/lwJIxWeVrbSZ36C+FUWWL+h5DlS/pjp8fdiBp6L7PhvZHJQeWTqv+1x1/vg6Xc8FfbqXoM/36vwG7nWhGb5XdqGq2d/PrGroUJGQ2ttWKRv6vcwk1NdEmR44Dd4/SmX7+f/7NqumL+PmrxjsYDD9vMGAS34WBO+Hl74O4+BywgTj/oLLYfQP59YX+wNDSJP6I21xFAAAAABJRU5ErkJggg==",
		["Stop_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAACoAAAAqCAMAAADyHTlpAAAA/1BMVEW4IyWooJy6WV2zf4GNjY3WXGDOfoAjIyNvb2/BQDz///+Hh4cAAADIFhzlHCL2yMq0FRrtMzjplprTNjq3t7dOTk7tKS/wRUy1hIbzZmv2pqjQPkLOREnxhosAAADPJivRGyH1dXr1XGP2VFsAAADOi43TZmr1trj80dOyd3nzPUH0foOYmJjLkZPTV1tWVlZ3d3edFRmyaGrUdnmoqKi7REj5naEAAAAAAADFxcUVFRUqKio3NzdiW1plZWWSW1UAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB9s7fNAAAAQHRSTlP+zf//OP//pTD7AP8u/////////v/+//////////+O//////8L//////////7///7//////v//Tnj/r/3/8//13usFiwAAAk1JREFUeNqV1WlXozAUgGGqo7PQzGWxxASQBij7QG1r1XH7///Km4BAHazOew45EJ6kPXwA7deX0/CIZ/cXR7q//xZ3NJ7t9OemWUzXNOvqQlkNZbV+yfP89HIqvJE/6bsfsaKV/rLBiUl5eZrnm81TVSk619cnm3y7avvT102cI92s9XlL9TpJkFpTrVbbJDkZqFcnwvf9Cen7pUhqTx+oVzMmytJ/V1mWgrHaO6AeDUOmEl2sK6LeIaVYFIXh2wLG5HkURfKG5w7UdSllDG2rZaWIOkipO6K2G0KWpZTxVCYiIS8RcowVrj2idgo+z0qWqUTEM2ufWZRmgDF7TD0QBQWfyn3kT0omz8AvGPgH9AyYaeJ80VIGglIfigJK0+T8gNaSlngUnBcF7sSKogRcLRQNBhrYYJltnOPA5ErRUofzYEwDH3zTcd5oCKGiDgjHhPKQmhw4Wgf3wAURRI4jwHEg3adAx9Qwlk5n93scBgqQhsQwBnptYOeQ4GhZOHjgGUYChqGmDON6RLUbzQjSFSHEsnBASkgChEzQG7mNUp9RQ1IyScm/tMY/sH2jBPCU854a4yeQpoklt+ooT7f4pBUl7+kZPhaf9LROAXiAlBFlx5QEnk1GBdQbLg7oUvZ7KnVnRLWPYIe1gS4/ocueVoHMmU7dq3pqq8ypcD6wtWrd0md9Zh9vpzct/d5UM8/t896f/LzQF3eKxrd/G3338ft9V60XV/P2VYz24XHxcY8PSqpvQXx7d3Wsu3ncf2Hi+fHi/mP0H9+tL/YKU/mR39HIBlAAAAAASUVORK5CYII=",
		["Stop_ds.png"] = "iVBORw0KGgoAAAANSUhEUgAAACoAAAAqCAMAAADyHTlpAAAA/1BMVEUAAACHh4e3t7epqal3d3dJSUmYmJhra2sAAADk5OTX19fGxsZZWVksLCwAAAA6OjoAAAAAAAAUFBSYmJghISFvb2+Dg4ONjY2UlJSpqam+vr4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAdUM90AAAAQHRSTlMA//7+//7+/y7//v7+/o7/Tnivz6UwOtc3ysUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHAqlSgAAAZJJREFUeNq11Wt3mzAMBuDIujEs1027td3+/w+dZAjgFEjXc/Z+UGLr4eJDcC6Xf8ufnE6S88cifyOo8UHMSNLbLF9F0/jjOKMB/pqoQBrHY+s9E2lyAMrjoY3OmAmGiUJuduwPWKbGvKG+yBXfx3sJVhp2h+exTaeO3vBOotnTPb48hS0lY8WE0II5ETM5ER9JT8EfCqt/tEAmVg3bJrSjZikpJxRRFcFkGhcKKmIsuFKczhB3pY4Sst+TsLQ5b/YUkVYaqhVixHtqOKWnuEM1Ttui6iUUAkOj0lERX+dELc4faqYAVkW2FLiq7NDq0S0lgmY95r9NhBpHe9GqShTtG9VILa16U63YVLjNqW4oz60v0HJA7ROlYkQWxddB89coVojuaGUiv1hQjmWUeRy0X5ZPM5eGuNUa40p71Jdfqq70Nrb6icYdUZd+vNIv5BtUHmWh8jgzJcEHEaGJKrynBxZsoj9NXs92bfS38dro5fnF99oTKcRPw7xtP7+UysepZZFur09nuQ6bv5jhPJf/mL9FXCKl4V474QAAAABJRU5ErkJggg==",
		["Stop_ovr.png"] = "iVBORw0KGgoAAAANSUhEUgAAACoAAAAqCAMAAADyHTlpAAAA/1BMVEXd0NDGurr////0JCn1R0yhlpYPCAj6NTr8pan9Z27UyMhkWlrVHiP919n8h4zSk5T8PEH4l5r6dHn/tbgPCAj6Uln/4uPSIiYPCAjgHiTQiIr/xsm5HiL+WmL9fIKyp6f6nqKTiYnOd3lyZmWckZHYZ2raTlDGurr/3uAPCAgPCAj/v8IvJyc8NDRSSUlaUVF8cnLaUlYhGRlIPz+GfHyHfX2ek5OuZF2qamW4mI6vpKS0qKi9srLbQTvbfoHHpp0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAqrqHDAAAAQHRSTlPiygD//v8u//////7//////////47///8L/////////v////r///7+/054/6r9//7//6//MP869PbXN8r/+//UvkeUygAAAj5JREFUeNqd1Yl2oyAUBuDMgAFSL4NQXGrdsrfpOvs+7/9Wc8GcqG1jM/PniHL9ROLxyOTtyZnglk5gMjsegO/pnqZvNsHD4uxYFk01+5x6mv6oPn29wLx7Ia5+sQg2H1NPq+WX+XyEzueLqvJ0GjSr+e8LGbnU/JDaFyKJdNUEU0+XzUqUsq96QatXq2bZ0iCwQku0z3Bd15EshXhcHihFW0rZzqEXLDlpaRB01BZCaEzprvApS9cXQhSW9ilah5+nwBN0SKnVouhjd2OseDikAuI4t3qXu5SidF0c0mD0E5pDZGKpYx9Z7GLO49pS3xUDamOJW4TXG4Ozs44ZQymWBZZVR5XYCl+nHlAdl5RGcVvaGdWjTIBWVIqO4gQl0q1UyhjGepQCVz4t9TeRW6VAKvaEsggiyhhzY+AFAoRSEhgDiaNIRjpKiDJgFFo/Bs5HMOZpznMoSI8mCWHOEsY47yghAJALkiQdvQwxEjS2nGNDgYahhjD0pTC87NFknYRJHp1C1+4c51mW+QZplmnIshep7SgZpY8gEpJLQgjn2BDAQ2Nwr/E/JQMa5rnmYA/U5DJyHCkZ0iQR+FjcoHta5ACGtNSNO3iuxDLSj7Xd8YCS8fwfJa/lQCv2Wqo9bar2/cM3S7mfa1zXvWn+mP2qmpY+BN/oeDbLRUtvFtWfMbieBWfXnqZXN2fNz+Pf903V3J9P209xevX+9u7+6Af+7sOtl34tSK+uz8dyPU0PK0w6HU96WIz+Yd06MX8Bjy1ONrk6uXUAAAAASUVORK5CYII=",
		["SurfacePanel.png"] = "iVBORw0KGgoAAAANSUhEUgAAACoAAAAqCAMAAADyHTlpAAAA/1BMVEXk0JaknqDo01ampNhYWVvepVZjYJTU1CWcrGDR0eMoJSScWSqoqKjMzMwcHBybbl2wsLDdoDcuLGLesYtZLx2ksyzJycmrxCgrKyuEeZV2llm2yE3MzMwhISFJSUlzTzKioqLFfk/QdhXCveUAAADp6lDx8Yzn5zLs7GmNiIvw8HaamhKZlZbIyRro6fymphPo6IgBAQFXWFjZ2foBAQG3uBa1tLTj4xlmZ2h3dnirqKn09f4tLS3U2G8ICAgSEhIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAE9zu0AAAAQHRSTlP99/7/9f///vj53v8fnJ3/n////v/+HP02//f4XWAT/23///8B/v7+/vj+//7+//7+K/r/VP75/v37/f9D/G+2IW0piQAAA1VJREFUeNqN1e2WojgQBuAEEiDQLa2gtjpO9+w2DdEQBBRBB/v+72oqAfyY3Z2z7w89ls8pC5ACffzvoIdPs9m352u+zWb/ScExVp2EzqliDPS/UgUr0dQ10anrRlQP+Epnz1XFCVk6aLf7/NztkLMkhFfV8+x3+vRSibpw2s+7tE5Ri+rl6ZGC5MVSQdXzhpcFPw0W9fLEC0ejge4g8OLcLBp6klWy2Ww6hhArS2xCIUlWMHBnFX16hzmdjY6SFiuZZL5HkyRpEwfmfX8aKD41DpQTjREqJWOWTykKqBclidOccE/VoI6R9BZFpZQS+wj5TrSjQA2nGxd1TVdJlHRpFSU+Q6czM2sUwBerri36+P4OTSNIR6NIns+q6dnCpkQ+FCJo+/5d0RexWEV92p5iA2HTNGUQqurKFy+aYuHEAzUiTXkVoMiMmBuEBCr2UuBXoK+cD1TBiSnl2TqFlIbhmx/qor3kvKfTYxwrbUDZmpRAq9Cj9Af1FlCMY3vK+RroT6BprAPV2AJ7NjGLcOi6C1lG2IjTOec/O3rIOmrbQA1t/y5Lw7CkLA1sx4fDlc636THuk2XYXMizqcKkNEkW29mta7rdZtkhtSEHfp5Y1gKOTVlZWuKQZdt0oGK+vSb0zWZilRZjmpqWUNW56Cm+0uAHCnxroqwp4RqopprijjZiDr+RwRBbDwUBBYsnJilLaGtVBzXcXDSKvhLhqHm2KYErjyj1PHyWklksNS2cphkchiOIvgSE4zSbTrMUetIxpX+BrS04v2lqKZhlKeaafowaYRwgHrQcjw3D8EJxUmdjOp3a6ouDIZqR/r+uC46PdupoSQ1j7AFJIfoFcsS8WGuaj2rR2vYRaQjSt4/3sVtRj/Lu3lqTBi50rOY0DDp+E3Z8HwM3ZN3fhvmo4EFkUzUn9UBGPdLvEeKFatrtgb1bcHWalCQivv7RdZAo3P11ZeQXtxBI9Xxr4c6/S5Qoeclvi0hZjlXazV2STQK/3sthvYElJWOsbG/bTS0FOKJBXpdmfvlyiwVGu2FvbTY7hBeF+zXI2yrO9yPXJY2jVnGSqFXsQEd3tM//ueDz/QWwS4qihhQFOHd0ucmHx4bCo69rRg/w94dRnu/vkud/eG79Mb8A0ezeEp5c69gAAAAASUVORK5CYII=",
		["VelocityTool.png"] = "iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAMAAAAp4XiDAAAA/1BMVEWgoKAzMzOkpKRkZGSioqKioqLQ0NDIyMi0Z2fskJBJSUnS0tLJyckxMTEAAADn5+eXl5fa2toAAP+1tbWJiYmnp6fHx8dYWFhmZmZ3d3cBAQEBAQH+BQUtLS0ICAgSEhJJSUkpKSnLy8sqKio1NTW2trbFxcXl1dXruLgKCgoNDQ0ZGRk2Nja5ubm2trbKysrR0dH8Fxf6Kir4OTnyaWnxe3voxsZKSkr1SUn0XFzsl5fsp6cbGxsbGxsmJiYhISEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACeQdAmAAAAQHRSTlMao9HPbZsjlf//GGnZQQD+/v7//Pj9+/r9/CtU/0NvtvrJpvP5Jxj//5CjzDeYqleQ////////EP////8vcDxhVpSqGAAAAo5JREFUeNrV1ntzojAQAHB893XHhk0CwVRpQa1aW9ta+26//7fqRnyEAHdz/113xnFM8iOQkF293/8c3s8h3e7pctm7pOgtl6fd7l/J+PbyTKKATQiUZ5e34z8SAhJBRftQgNJFBTLuIfIw5Mj8TbD8F/bGdWS0QIhCsR2/VSKMABejajK6oYty6TshqRFvRlVkdCN4KPyKECEXltkTb4E8Qr8yMOK48Fzitek5aoQxgG3PJU2hhF8b1Nl0iNcRnLPXl7XpP365cgnjXHS8IqFJpP+qH6l7cn+3Dhhz1u0wTf711KZXxPfXdw8T33/Tz34QoGOAi/aJTTqw2ZBnTbe00sdEXCMVdJ4sctIEbkY80p3RfV0Z4hjGoXltkWt6OjPgSt9P3vSDvyFFw4DzKjK5128rswZByUha0l8WOSciTf9KvzyY5wlcwyRyfl4kKBjFq9barFpgG9PBsIIAUsf6TusV7cmOBJsLmYASAaRzKwQ+a31MA4KDkTSBOdkIFcTE0dERp698eJplScTzjnqyjZxkkVK8jqgySekTWU2URmzy2YJdItqRNImCIOT7FoHQ+rTIe4v2RVgRJIkyUynYtdBWtt7tl7+hQKIVoDhdlqaBXYsE1Sicly+TvOQhzBiJNA3HvMGktK8CiRsRSOYGGSXz7ZcQNeLi2f9IFJYIE4pvCarkw0kXcaMi69HLKPf5bzfJIY/1L0KQdQlGQnjRL6W+eFBvjBjE5QRrDJfMr7g7bgs7jZNJlCgZWoPEFoViEQ+G6aG4HEpMOrRFsSTF/ek8S0zlYtvDCyrJ5tN+XF/44v5gNk+zJAxN1QvDJEvns0FRlMoroelsuI/Z1AVVRTyO+1bE8U/+Q/KfkG/koqtfRPQd0wAAAABJRU5ErkJggg==",
		["VelocityTool_dn.png"] = "iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAMAAAAp4XiDAAAA/1BMVEVb19cKpqbsmpoYJycIWVkNq6sD0dH0UlIxMjIA19dkZGSp1taN0NAcYWEn7u60Z2eNo6MAaWl74+MAAADn5+cA/v6Xl5fa2toAAP+1tbWJiYmnp6fHx8cB+/sA/v5YWFhmZmZ3d3cA//8A//8A///+BQUA//8SEhJJSUkAAQEB6OgGBwcA//8pKSkqKio1NTXl1dWuxsbruLgKCgoNDQ0ZGRkddHQy7Owx8/P8Fxf6Kir4OTnyaWnxe3voxsYKGBgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACvvg5OAAAAQHRSTlPPaP9RYIqW/6Zrz63ikNr/1ym9AP79/v7//fj9/NG0+v38DJE1/0+2+lmwb2nJ8/n/8f+Qo8xb2Nv///////9tOpXTogAAAyhJREFUeNqdlglzqjAQxxG1Hs+eDwM5EIJiKdSrak9rv/+3ersJIALWef5nHIckP/ZIsovx979lVIeC6XjkusOh647Gk+A8EkxHwyONp2eQqTusyJ38gkxS4N14+AN6MN7182hyChnr9YMV5USJ09VAU8+1SKCCeFtRIv1cktDVjQopqCKBcmpFmecxaltKtn4aKOeCMqJsvFHiezxdn1Lc8wlFQ+MygnEY8FImrJIEDFKjEE+KTJHgzONWjbjHODKTIjJRXjGfWrWiPqMYT1BAIBAX4jhBIENoHo6RuTXgklsnBZO5awqB/L5xxmyzs8d5s/NSRmzGOGY6QzCSOy6FZYbfML38/Ng7tl3KmzYTpAgk+AaOiGXtP76WYCTsWI5DSwxh3NWJNrRfBlEb0gnBpV1oAlJmhCSG9sxI/SIMV3yDZ+DXCyIlxmbkTnsGyPNwGEN0uOAl/Fya4ZelkGPGJoyBO1OFwKa0U2T5GZo7zIFTYQSk9EptjUYagAic34WdL4zHKTO2oIy1MwTMvTJGuQ0ywzDErDlFBidsCkhDxQ8IBNUEhFCY2H+E4Q72JEMc9SIUAeQVztUBIRTuLee0E4YmLHAOjAADeLMpYa0Kgrq9vWXwp5fPF4vIZ3oCkdyKiiVDUmlk4UvJCkgeC2ZMVpE5/PzCEJSRdjHJfZIVogyZR77jeCwf4ZT0833B3e/DvvCCnCiSaEqSbAS2sp/vPp6xriSCFkQkg9eCGZKNCCKv8zOG8bexeImDcI2gYIZRPYAlrZ2fZLwvcdcnwi4LGCn09gvidwv3BT27jiStIDaXLEWojK4LtxI9i7s1VQ8Oo8jrHxoZHVWY1swj4lSBEcSbtY8qjKpjP6cZJJrHdUxFEycz8M22arxj3uzHLVVL5dpVMoskrzCQg2iWXJVrsq78V8nj/NBcDi1m/qiI57r+Ej+ttws4KVT7B5eXyGixXf/Edf1FdzG3lWy280Xkedj1PC9azLebpOXWdrGsV8atZL15zLVZJ634VK/MO3LcaD7lajbiXzpyoe+Per3G/X2j1xud6/uXfF1c9A1zyZfSZd9j5/QPx2Ti1Qa9F4AAAAAASUVORK5CYII=",
		["VelocityTool_ds.png"] = "iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAMAAAAp4XiDAAAA/1BMVEUAAADm5uaXl5fa2tpLS0u2traHh4enp6fHx8dYWFhmZmZ3d3cBAQEBAQEtLS0ICAgSEhIpKSnLy8sqKio1NTW2trbFxcUKCgoNDQ0ZGRk2Nja5ubm2trbKysrR0dFKSkobGxsbGxsmJiYhISEnJyc5OTk5OTlZWVlwcHCNjY2KioqdnZ2VlZWtra2pqammpqanp6eysrK0tLSwsLDBwcHJycnQ0NDQ0NDS0tLQ0NAxMTFAQEBSUlKPj4+RkZEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACzPU3XAAAAQHRSTlMA/v7+/vz6/fz6/fwrVENvtsmm8/knGJCjzDeYqleQEC9wPGGjkrTA3wYxrNUFNorRE27NidkSNGmhQSwEbG8AO3xapAAAAlZJREFUeNrt1WdzozAQBmCz0u5KCGLH4BYnTu+9J9f+/8+6FWCbGt/Mfbu5dyaZRPAgIaFVr/cv5+39Y7H4HEo+F4uP97eNYLw3fDXIkIXRvA73xpuAQXDhKg7QfInGL4hkLaEKsqj8P3zpNKM5Qmi5uL9QbEPA+ahD7MpDyQS1GGnE3VG7YLIctIQtcZt5nCOFGLQGQ8L5Y13cPsl7dAhvAJ9ua+TumR0HJn93rE6BH5vj57uquLxnIiWvmnXk/6xGEfH9ZYVcPbAz/gpkc8Ra1ZBx/HBVFvs/5RPxV8A/Hwm1xpoB4l8/yuQa8gVBPzJxumGMg+v9Evl+A/nwDYHyo9MNI603OyWyI2+X3aCkN9+Tbhi5Qq0kYGLfoW4YI1P6rUS2hJhiZORnTdeNks5pq0pk+bII4RXJTdaOLQQwuyT9G7UiuniQUtAggLJvmVEG4KleGyMd+J2N0EJKyW9P0lSHVDT9GUlD56iLuCZJ5CcsNUkZKZOjC1gWoiVJdKi1pVULI1wclcjBuawLlyI9OMh+LVtkKc8Pyp/yqQOZqnXAkTxWuoFliwF3Wtkvx754mXX8PUa2gCbMG3xJO66Q6CwEo+oR4zeeX34D4VlU3cmH2mGDKHZUEHT6sFYuopOWqicfo1nVv5OoXpXibQumqygZsNtxo/RF/W7jRT/qtRoyKmgZHbWLzGjXKHpS+53uEN4MkvXhsj5ikkGXEBNPZqn2J5cqNi84nc4mcdR9jEVxfzpLUm2tP/Ws1Wkym/a/EjmaTAerTCebQIaiuJQo6v3P3+Y3mA4lcNVHHRQAAAAASUVORK5CYII=",
		["VelocityTool_ovr.png"] = "iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAMAAAAp4XiDAAAA/1BMVEWgoKAzMzOkpKRkZGSioqKioqLQ0NDIyMhJSUn4SEjS0tLJyckxMTHaqqoAAADm5uaXl5fa2toA/v61tbWJiYmnp6fHx8dYWFhmZmZ3d3cBAQEBAQH+BAQtLS0ICAgSEhJJSUkpKSnLy8sqKio1NTW2trbFxcXtuLj6KCjo19cKCgoNDQ0ZGRk2Nja5ubm2trbKysrR0dH9ExP5Ojr0WVnza2vyfHzriIjpx8dKSkrtmJjrp6cbGxsbGxsmJiYhISEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADqx59LAAAAQHRSTlMao9HPbZsjlRj/adlB/wD+/v7//Pj9+/r9/CtU/0NvtvrJpvP5Jxj///+Qo8w3mKpXkP////////8Q//8vcDxhPodzCQAAAopJREFUeNrV1nl3ojAQAHC8e+wuEyYHQWppwdva2tpq7+//rToBxXC4x3/bec/nM8mPhEBmdH79czjfh3S7Z6tV75qit1qddbt/JKO763OJAtIQKM+v70a/JQQkgvbz0ICyjApk1EPkSnFkbhos+4W90TEyXCL4SuzG75RQPuByWE+Gt3RRLt1SSGrE22EdGd4KroRbE0JxYZmcOEvkPrq1gT7HpVMmTpvu44gwBrDtlElTaOG+rLdmxGY9Lq9Ni2aJOB3BOXNfwifqn07utyXCOBcdp0hoEtqr7f3D1HVfw1OPsdK+HabJvp7b9IqYntOQlvQYbjwPSwa4aJ/YpAPZA3mildG6xl7FSA2dZ4ucNIGnI8bhZDoOH1yvYhiH5o1Fbuju0gHTSfj6SDN5FcOA81pC97F+uB9npGAkbekPi1wQkWn/SxjSunbEMkwi5xdFgoKZ2E7C8DEnmUk7sIYApl3rMHxlOfGyC1FAhQDSuRUC2c/NRjLmHYykCczJRqghVmTD4ySJfL5r+juS+FrzY0RXSUwf32qiNGKTjxbsE9GexJHveYrnLQKh9WGRtxY9F2GFF0XaTKVh30KPsvVmv/wNDRKtAM3psjQN7Fsk6EbhvHya5CUPYcZIpGk4Zg0mpX0WSNDwQbJykDEHzzx+CX4jKJ7990hjhTCh+Y6gjt5L6SJo1GQ9ehllnv/2kxzyWP9KgTyWlCSoq34l9QWD48aIQVBNsMZwydya1XFb2GmcTKRFxdAeRLYoFItgcBkfisuhxMSXtiiWpKA/WySRqVxsd3hBR8li1g+OF76gP5gv4iRSylQ9paIkXswHRVEpr4Rm88s85rMyqCviQdC3Igi+8x+S/4R8AYf/q9f74ISrAAAAAElFTkSuQmCC",
	}

	local b64lut = {}
	local b64alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, 64 do
		b64lut[string.byte(b64alphabet, i)] = i - 1
	end

	local nativeB64Decode = nil
	pcall(function()
		if type(crypt) == "table" then
			if type(crypt.base64decode) == "function" then
				nativeB64Decode = crypt.base64decode
			elseif type(crypt.base64_decode) == "function" then
				nativeB64Decode = crypt.base64_decode
			elseif type(crypt.base64) == "table" and type(crypt.base64.decode) == "function" then
				nativeB64Decode = crypt.base64.decode
			end
		end
		if not nativeB64Decode then
			if type(base64_decode) == "function" then
				nativeB64Decode = base64_decode
			elseif type(base64decode) == "function" then
				nativeB64Decode = base64decode
			elseif type(base64) == "table" and type(base64.decode) == "function" then
				nativeB64Decode = base64.decode
			elseif type(syn) == "table" and type(syn.crypt) == "table" and type(syn.crypt.base64) == "table" and type(syn.crypt.base64.decode) == "function" then
				nativeB64Decode = syn.crypt.base64.decode
			end
		end
	end)

	local function decodeBase64(data)
		local clean = string.gsub(data, "%s+", "")
		if nativeB64Decode then
			local ok, res = pcall(nativeB64Decode, clean)
			if ok and type(res) == "string" and #res > 8 and string.sub(res, 2, 4) == "PNG" then
				return res
			end
		end
		local out = {}
		local outIdx = 0
		local len = #clean
		local v1, v2, v3, v4 = 0, 0, 0, 0
		local count = 0
		for i = 1, len do
			local b = string.byte(clean, i)
			local val = b64lut[b]
			if val ~= nil then
				count = count + 1
				if count == 1 then
					v1 = val
				elseif count == 2 then
					v2 = val
				elseif count == 3 then
					v3 = val
				elseif count == 4 then
					v4 = val
					local n = v1 * 262144 + v2 * 4096 + v3 * 64 + v4
					local c1 = math.floor(n / 65536) % 256
					local c2 = math.floor(n / 256) % 256
					local c3 = n % 256
					outIdx = outIdx + 1
					out[outIdx] = string.char(c1, c2, c3)
					count = 0
				end
			elseif b == 61 then -- '=' padding
				if count == 2 then
					local n = v1 * 262144 + v2 * 4096
					local c1 = math.floor(n / 65536) % 256
					outIdx = outIdx + 1
					out[outIdx] = string.char(c1)
				elseif count == 3 then
					local n = v1 * 262144 + v2 * 4096 + v3 * 64
					local c1 = math.floor(n / 65536) % 256
					local c2 = math.floor(n / 256) % 256
					outIdx = outIdx + 1
					out[outIdx] = string.char(c1, c2)
				end
				break
			end
		end
		return table.concat(out)
	end

	local getCustomAssetFunc = (type(getcustomasset) == "function" and getcustomasset)
		or (type(getsynasset) == "function" and getsynasset)
		or nil

	local function findLocalFileAsset(filenames)
		if not getCustomAssetFunc or type(isfile) ~= "function" then
			return nil
		end
		local prefixes = { "", Config.ASSET_FOLDER_NAME .. "/", "2005/", "images/", "assets/", "icons/" }
		for _, prefix in ipairs(prefixes) do
			for _, name in ipairs(filenames) do
				local path = prefix .. name
				local ok, exists = pcall(isfile, path)
				if ok and exists then
					local okAsset, assetUrl = pcall(getCustomAssetFunc, path)
					if okAsset and type(assetUrl) == "string" and assetUrl ~= "" then
						return assetUrl
					end
				end
			end
		end
		return nil
	end

	S.DirectFileUrls = {}
	pcall(function()
		if getCustomAssetFunc and type(writefile) == "function" then
			if type(isfolder) == "function" and type(makefolder) == "function" then
				pcall(function()
					if not isfolder(Config.ASSET_FOLDER_NAME) then
						makefolder(Config.ASSET_FOLDER_NAME)
					end
				end)
			end
			local sheetPath = Config.ASSET_FOLDER_NAME .. "/2005_gui_sheet.png"
			pcall(writefile, sheetPath, decodeBase64(B64_2005_SHEET))
			local okSheet, sheetUrl = pcall(getCustomAssetFunc, sheetPath)
			if okSheet and type(sheetUrl) == "string" and sheetUrl ~= "" then
				S.CustomSheetUrl = sheetUrl
			end

			local sheet2Path = Config.ASSET_FOLDER_NAME .. "/2005_gui_sheet2.png"
			pcall(writefile, sheet2Path, decodeBase64(B64_2005_SHEET2))
			local okSheet2, sheet2Url = pcall(getCustomAssetFunc, sheet2Path)
			if okSheet2 and type(sheet2Url) == "string" and sheet2Url ~= "" then
				S.CustomSheet2Url = sheet2Url
			end

			local studPath = Config.ASSET_FOLDER_NAME .. "/2005_stud.png"
			pcall(writefile, studPath, decodeBase64(B64_2005_STUD))
			local okStud, studUrl = pcall(getCustomAssetFunc, studPath)
			if okStud and type(studUrl) == "string" and studUrl ~= "" then
				S.CustomStudUrl = studUrl
			end

			-- Extract all 86 standalone PNGs asynchronously in batches so startup is instant & never hits script timeout!
			task.spawn(function()
				local writtenCount = 0
				for fname, b64 in pairs(B64_DIRECT_FILES) do
					local fpath = Config.ASSET_FOLDER_NAME .. "/" .. fname
					local exists = false
					if type(isfile) == "function" and fname ~= "SurfacePanel.png" then
						local okEx, exVal = pcall(isfile, fpath)
						exists = (okEx and exVal == true)
					end
					if not exists then
						pcall(writefile, fpath, decodeBase64(b64))
						writtenCount = writtenCount + 1
						if writtenCount % 6 == 0 then
							task.wait()
						end
					end
					local okF, fUrl = pcall(getCustomAssetFunc, fpath)
					if okF and type(fUrl) == "string" and fUrl ~= "" then
						S.DirectFileUrls[fname] = fUrl
					end
				end
				if S.refreshAllToolbarSprites then pcall(S.refreshAllToolbarSprites) end
				if S.rebuildBottomBarContent then pcall(S.rebuildBottomBarContent) end
			end)
		end
	end)

	S.Raw4tdUrl = findLocalFileAsset({ "4tdATt.png" })
	S.RawPuzzleUrl = findLocalFileAsset({ "puzzle.jpg" })
	S.RawGalleryArrowUrl = findLocalFileAsset({ "Screenshot_20261019_172613_Gallery.jpg", "arrow_left.png", "arrow.jpg" })

	S.SPRITE_MAP = {
		ArrowLeft              = { Offset = Vector2.new(2, 212), Size = Vector2.new(35, 35), File = "ArrowLeft.png" },
		ArrowRight             = { Offset = Vector2.new(39, 212), Size = Vector2.new(35, 35), File = "ArrowRight.png" },
		ArrowTool              = { Offset = Vector2.new(442, 2), Size = Vector2.new(50, 50), File = "ArrowTool.png" },
		ArrowTool_dn           = { Offset = Vector2.new(2, 68), Size = Vector2.new(50, 50), File = "ArrowTool_dn.png" },
		ArrowTool_ds           = { Offset = Vector2.new(106, 68), Size = Vector2.new(50, 50), File = "ArrowTool_ds.png" },
		ArrowTool_ovr          = { Offset = Vector2.new(54, 68), Size = Vector2.new(50, 50), File = "ArrowTool_ovr.png" },
		CamCenter              = { Offset = Vector2.new(386, 212), Size = Vector2.new(32, 18), File = "CameraCenter.png" },
		CamDown                = { Offset = Vector2.new(115, 212), Size = Vector2.new(38, 28), File = "CamDown.png" },
		CamLeft                = { Offset = Vector2.new(200, 212), Size = Vector2.new(30, 36), File = "CameraPanLeft.png" },
		CamRight               = { Offset = Vector2.new(293, 212), Size = Vector2.new(30, 36), File = "CameraPanRight.png" },
		CamUp                  = { Offset = Vector2.new(76,  212), Size = Vector2.new(38, 28), File = "CamUp.png" },
		CamZoomIn              = { Offset = Vector2.new(154, 212), Size = Vector2.new(22, 22), File = "CamZoomIn.png" },
		CamZoomOut             = { Offset = Vector2.new(177, 212), Size = Vector2.new(22, 22), File = "CamZoomOut.png" },
		CameraCenter           = { Offset = Vector2.new(386, 212), Size = Vector2.new(32, 18), File = "CameraCenter.png" },
		CameraCenter_dn        = { Offset = Vector2.new(452, 212), Size = Vector2.new(32, 18), File = "CameraCenter_dn.png" },
		CameraCenter_ds        = { Offset = Vector2.new(386, 231), Size = Vector2.new(32, 18), File = "CameraCenter_ds.png" },
		CameraCenter_ovr       = { Offset = Vector2.new(419, 212), Size = Vector2.new(32, 18), File = "CameraCenter_ovr.png" },
		CameraPanLeft          = { Offset = Vector2.new(200, 212), Size = Vector2.new(30, 36), File = "CameraPanLeft.png" },
		CameraPanLeft_dn       = { Offset = Vector2.new(262, 212), Size = Vector2.new(30, 36), File = "CameraPanLeft_dn.png" },
		CameraPanLeft_ovr      = { Offset = Vector2.new(231, 212), Size = Vector2.new(30, 36), File = "CameraPanLeft_ovr.png" },
		CameraPanRight         = { Offset = Vector2.new(293, 212), Size = Vector2.new(30, 36), File = "CameraPanRight.png" },
		CameraPanRight_dn      = { Offset = Vector2.new(355, 212), Size = Vector2.new(30, 36), File = "CameraPanRight_dn.png" },
		CameraPanRight_ovr     = { Offset = Vector2.new(324, 212), Size = Vector2.new(30, 36), File = "CameraPanRight_ovr.png" },
		Card                   = { Offset = Vector2.new(164, 166), Size = Vector2.new(44, 44), File = "Card.png" },
		Card_dn                = { Offset = Vector2.new(256, 166), Size = Vector2.new(44, 44), File = "Card_dn.png" },
		Card_ovr               = { Offset = Vector2.new(210, 166), Size = Vector2.new(44, 44), File = "Card_ovr.png" },
		ColorPalette           = { Offset = Vector2.new(72, 166), Size = Vector2.new(44, 44), File = "HopperPanel.png" },
		Controller1            = { Offset = Vector2.new(2, 251), Size = Vector2.new(36, 36), File = "Controller1.png" },
		Controller1Tool        = { Offset = Vector2.new(268, 251), Size = Vector2.new(44, 44), File = "Controller1Tool.png" },
		Controller1Tool_dn     = { Offset = Vector2.new(314, 251), Size = Vector2.new(44, 44), File = "Controller1Tool_dn.png" },
		Controller1_dn         = { Offset = Vector2.new(78, 251), Size = Vector2.new(36, 36), File = "Controller1_dn.png" },
		Controller1_ds         = { Offset = Vector2.new(116, 251), Size = Vector2.new(36, 36), File = "Controller1_ds.png" },
		Controller1_ovr        = { Offset = Vector2.new(40, 251), Size = Vector2.new(36, 36), File = "Controller1_ovr.png" },
		Controller2            = { Offset = Vector2.new(154, 251), Size = Vector2.new(36, 36), File = "Controller2.png" },
		Controller2Tool        = { Offset = Vector2.new(360, 251), Size = Vector2.new(44, 44), File = "Controller2Tool.png" },
		Controller2Tool_dn     = { Offset = Vector2.new(406, 251), Size = Vector2.new(44, 44), File = "Controller2Tool_dn.png" },
		Controller2_dn         = { Offset = Vector2.new(230, 251), Size = Vector2.new(36, 36), File = "Controller2_dn.png" },
		Controller2_ds         = { Offset = Vector2.new(116, 251), Size = Vector2.new(36, 36), File = "Controller1_ds.png" },
		Controller2_ovr        = { Offset = Vector2.new(192, 251), Size = Vector2.new(36, 36), File = "Controller2_ovr.png" },
		ControllerAI1Tool      = { Offset = Vector2.new(452, 251), Size = Vector2.new(44, 44), File = "ControllerAI1Tool.png" },
		ControllerAI1Tool_dn   = { Offset = Vector2.new(2, 297), Size = Vector2.new(44, 44), File = "ControllerAI1Tool_dn.png" },
		ControllerAI2Tool      = { Offset = Vector2.new(48, 297), Size = Vector2.new(44, 44), File = "ControllerAI2Tool.png" },
		ControllerAI2Tool_dn   = { Offset = Vector2.new(94, 297), Size = Vector2.new(44, 44), File = "ControllerAI2Tool_dn.png" },
		ControllerNoneTool     = { Offset = Vector2.new(140, 297), Size = Vector2.new(44, 44), File = "ControllerNoneTool.png" },
		ControllerNoneTool_dn  = { Offset = Vector2.new(186, 297), Size = Vector2.new(44, 44), File = "ControllerNoneTool_dn.png" },
		ControllerPanel        = { Offset = Vector2.new(118, 166), Size = Vector2.new(44, 44), File = "ControllerPanel.png" },
		Controller_Chase       = { Offset = Vector2.new(452, 251), Size = Vector2.new(44, 44), File = "ControllerAI1Tool.png" },
		Controller_Flee        = { Offset = Vector2.new(48, 297), Size = Vector2.new(44, 44), File = "ControllerAI2Tool.png" },
		Cursor                 = { Offset = Vector2.new(442, 2), Size = Vector2.new(50, 50), File = "ArrowTool.png" },
		Cursor_dn              = { Offset = Vector2.new(2, 68), Size = Vector2.new(50, 50), File = "ArrowTool_dn.png" },
		Cursor_ds              = { Offset = Vector2.new(106, 68), Size = Vector2.new(50, 50), File = "ArrowTool_ds.png" },
		Cursor_ovr             = { Offset = Vector2.new(54, 68), Size = Vector2.new(50, 50), File = "ArrowTool_ovr.png" },
		Flag_Blue              = { Offset = Vector2.new(2, 251), Size = Vector2.new(36, 36), File = "Controller1.png" },
		Flag_Red               = { Offset = Vector2.new(154, 251), Size = Vector2.new(36, 36), File = "Controller2.png" },
		GO                     = { Offset = Vector2.new(2, 2), Size = Vector2.new(64, 64), File = "Run.png" },
		HingeTool              = { Offset = Vector2.new(82, 120), Size = Vector2.new(44, 44), File = "HingeTool.png" },
		HingeTool_dn           = { Offset = Vector2.new(128, 120), Size = Vector2.new(44, 44), File = "HingeTool_dn.png" },
		HopperPanel            = { Offset = Vector2.new(72, 166), Size = Vector2.new(44, 44), File = "HopperPanel.png" },
		Move                   = { Offset = Vector2.new(366, 68), Size = Vector2.new(44, 44), File = "MoveTool.png" },
		MoveTool               = { Offset = Vector2.new(366, 68), Size = Vector2.new(44, 44), File = "MoveTool.png" },
		MoveTool_dn            = { Offset = Vector2.new(458, 68), Size = Vector2.new(44, 44), File = "MoveTool_dn.png" },
		MoveTool_ds            = { Offset = Vector2.new(2, 120), Size = Vector2.new(44, 44), File = "MoveTool_ds.png" },
		MoveTool_ovr           = { Offset = Vector2.new(412, 68), Size = Vector2.new(44, 44), File = "MoveTool_ovr.png" },
		PlayDelete             = { Offset = Vector2.new(302, 166), Size = Vector2.new(42, 44), File = "PlayDelete.png" },
		PlayDelete_dn          = { Offset = Vector2.new(346, 166), Size = Vector2.new(42, 44), File = "PlayDelete_dn.png" },
		PlayDelete_ds          = { Offset = Vector2.new(390, 166), Size = Vector2.new(42, 44), File = "PlayDelete_ds.png" },
		PlayDelete_ovr         = { Offset = Vector2.new(434, 166), Size = Vector2.new(42, 44), File = "PlayDelete_ovr.png" },
		Reset                  = { Offset = Vector2.new(232, 297), Size = Vector2.new(72, 24), File = "Reset.png" },
		ResetGame              = { Offset = Vector2.new(76, 343), Size = Vector2.new(96, 28), File = "ResetOrg.png" },
		ResetOrg               = { Offset = Vector2.new(76, 343), Size = Vector2.new(96, 28), File = "ResetOrg.png" },
		ResetOrg_dn            = { Offset = Vector2.new(272, 343), Size = Vector2.new(96, 28), File = "ResetOrg_dn.png" },
		ResetOrg_ds            = { Offset = Vector2.new(370, 343), Size = Vector2.new(96, 28), File = "ResetOrg_ds.png" },
		ResetOrg_ovr           = { Offset = Vector2.new(174, 343), Size = Vector2.new(96, 28), File = "ResetOrg_ovr.png" },
		Reset_dn               = { Offset = Vector2.new(380, 297), Size = Vector2.new(72, 24), File = "Reset_dn.png" },
		Reset_ds               = { Offset = Vector2.new(2, 343), Size = Vector2.new(72, 24), File = "Reset_ds.png" },
		Reset_ovr              = { Offset = Vector2.new(306, 297), Size = Vector2.new(72, 24), File = "Reset_ovr.png" },
		Resize                 = { Offset = Vector2.new(48, 120), Size = Vector2.new(32, 32), File = "Resize.png" },
		RotateLeft             = { Offset = Vector2.new(174, 120), Size = Vector2.new(30, 32), File = "SelectionRotate.png" },
		RotateRight            = { Offset = Vector2.new(270, 120), Size = Vector2.new(30, 32), File = "SelectionTilt.png" },
		Run                    = { Offset = Vector2.new(2, 2), Size = Vector2.new(64, 64), File = "Run.png" },
		Run_dn                 = { Offset = Vector2.new(134, 2), Size = Vector2.new(64, 64), File = "Run_dn.png" },
		Run_ds                 = { Offset = Vector2.new(200, 2), Size = Vector2.new(64, 64), File = "Run_ds.png" },
		Run_ovr                = { Offset = Vector2.new(68, 2), Size = Vector2.new(64, 64), File = "Run_ovr.png" },
		STOP                   = { Offset = Vector2.new(266, 2), Size = Vector2.new(42, 42), File = "Stop.png" },
		STOP_dn                = { Offset = Vector2.new(310, 2), Size = Vector2.new(42, 42), File = "Stop_dn.png" },
		STOP_ds                = { Offset = Vector2.new(354, 2), Size = Vector2.new(42, 42), File = "Stop_ds.png" },
		STOP_ovr               = { Offset = Vector2.new(398, 2), Size = Vector2.new(42, 42), File = "Stop_ovr.png" },
		SelectionDown          = { Offset = Vector2.new(444, 120), Size = Vector2.new(24, 24), File = "SelectionDown.png" },
		SelectionDown_ds       = { Offset = Vector2.new(2, 166), Size = Vector2.new(24, 24), File = "SelectionDown_ds.png" },
		SelectionDown_ovr      = { Offset = Vector2.new(470, 120), Size = Vector2.new(24, 24), File = "SelectionDown_ovr.png" },
		SelectionRotate        = { Offset = Vector2.new(174, 120), Size = Vector2.new(30, 32), File = "SelectionRotate.png" },
		SelectionRotate_ds     = { Offset = Vector2.new(238, 120), Size = Vector2.new(30, 32), File = "SelectionRotate_ds.png" },
		SelectionRotate_ovr    = { Offset = Vector2.new(206, 120), Size = Vector2.new(30, 32), File = "SelectionRotate_ovr.png" },
		SelectionTilt          = { Offset = Vector2.new(270, 120), Size = Vector2.new(30, 32), File = "SelectionTilt.png" },
		SelectionTilt_ds       = { Offset = Vector2.new(334, 120), Size = Vector2.new(30, 32), File = "SelectionTilt_ds.png" },
		SelectionTilt_ovr      = { Offset = Vector2.new(302, 120), Size = Vector2.new(30, 32), File = "SelectionTilt_ovr.png" },
		SelectionUp            = { Offset = Vector2.new(366, 120), Size = Vector2.new(24, 24), File = "SelectionUp.png" },
		SelectionUp_ds         = { Offset = Vector2.new(418, 120), Size = Vector2.new(24, 24), File = "SelectionUp_ds.png" },
		SelectionUp_ovr        = { Offset = Vector2.new(392, 120), Size = Vector2.new(24, 24), File = "SelectionUp_ovr.png" },
		Stop                   = { Offset = Vector2.new(266, 2), Size = Vector2.new(42, 42), File = "Stop.png" },
		Stop_dn                = { Offset = Vector2.new(310, 2), Size = Vector2.new(42, 42), File = "Stop_dn.png" },
		Stop_ds                = { Offset = Vector2.new(354, 2), Size = Vector2.new(42, 42), File = "Stop_ds.png" },
		Stop_ovr               = { Offset = Vector2.new(398, 2), Size = Vector2.new(42, 42), File = "Stop_ovr.png" },
		SurfacePanel           = { Offset = Vector2.new(28, 166), Size = Vector2.new(42, 42), File = "SurfacePanel.png" },
		Trash                  = { Offset = Vector2.new(302, 166), Size = Vector2.new(42, 44), File = "PlayDelete.png" },
		Trash_dn               = { Offset = Vector2.new(346, 166), Size = Vector2.new(42, 44), File = "PlayDelete_dn.png" },
		Trash_open             = { Offset = Vector2.new(434, 166), Size = Vector2.new(42, 44), File = "PlayDelete_ovr.png" },
		Trash_ovr              = { Offset = Vector2.new(434, 166), Size = Vector2.new(42, 44), File = "PlayDelete_ovr.png" },
		VelocityTool           = { Offset = Vector2.new(158, 68), Size = Vector2.new(50, 50), File = "VelocityTool.png" },
		VelocityTool_dn        = { Offset = Vector2.new(210, 68), Size = Vector2.new(50, 50), File = "VelocityTool_dn.png" },
		VelocityTool_ds        = { Offset = Vector2.new(262, 68), Size = Vector2.new(50, 50), File = "VelocityTool_ds.png" },
		VelocityTool_ovr       = { Offset = Vector2.new(314, 68), Size = Vector2.new(50, 50), File = "VelocityTool_ovr.png" },

		-- 2005 Model Thumbnails (Cropped from 2005 Studio & Rendered)
		ModelRedBall           = { Offset = Vector2.new(2,   378), Size = Vector2.new(48, 42) },
		ModelCyanBall          = { Offset = Vector2.new(50,  378), Size = Vector2.new(48, 42) },
		ModelTallBlock         = { Offset = Vector2.new(98,  378), Size = Vector2.new(48, 42) },
		ModelBrick2x4          = { Offset = Vector2.new(146, 378), Size = Vector2.new(48, 42) },
		ModelHingedBlock       = { Offset = Vector2.new(194, 378), Size = Vector2.new(48, 42) },
		ModelWhiteBlock        = { Offset = Vector2.new(242, 378), Size = Vector2.new(48, 42) },
		ModelPinPlate          = { Offset = Vector2.new(290, 378), Size = Vector2.new(48, 42) },
		ModelPlate4x4          = { Offset = Vector2.new(338, 378), Size = Vector2.new(48, 42) },
		ModelDynabloxMan       = { Offset = Vector2.new(386, 378), Size = Vector2.new(48, 42) },
		ModelChassis           = { Offset = Vector2.new(434, 378), Size = Vector2.new(48, 42) },
		ModelFlag              = { Offset = Vector2.new(2,   422), Size = Vector2.new(48, 42) },
		ModelJewel             = { Offset = Vector2.new(50,  422), Size = Vector2.new(48, 42) },

		-- 2005 Impact Timer & Score Bitmap Tokens
		ScoreTok_Timer         = { Offset = Vector2.new(100, 424), Size = Vector2.new(80, 42) },
		ScoreTok_Score         = { Offset = Vector2.new(182, 424), Size = Vector2.new(81, 42) },
		ScoreTok_0             = { Offset = Vector2.new(265, 424), Size = Vector2.new(25, 42) },
		ScoreTok_1             = { Offset = Vector2.new(292, 424), Size = Vector2.new(25, 42) },
		ScoreTok_2             = { Offset = Vector2.new(319, 424), Size = Vector2.new(25, 42) },
		ScoreTok_3             = { Offset = Vector2.new(346, 424), Size = Vector2.new(25, 42) },
		ScoreTok_4             = { Offset = Vector2.new(373, 424), Size = Vector2.new(26, 42) },
		ScoreTok_5             = { Offset = Vector2.new(401, 424), Size = Vector2.new(25, 42) },
		ScoreTok_6             = { Offset = Vector2.new(428, 424), Size = Vector2.new(25, 42) },
		ScoreTok_7             = { Offset = Vector2.new(455, 424), Size = Vector2.new(25, 42) },
		ScoreTok_8             = { Offset = Vector2.new(482, 424), Size = Vector2.new(25, 42) },
		ScoreTok_9             = { Offset = Vector2.new(2,   468), Size = Vector2.new(25, 42) },
		ScoreTok_Dot           = { Offset = Vector2.new(29,  468), Size = Vector2.new(17, 42) },
		-- Cropped RBLX04 / 2004 Keyboard Controller Sprites (Unpushed & Pushed)
		Key_W                  = { Offset = Vector2.new(50,  468), Size = Vector2.new(34, 30), File = "Key_W.png" },
		Key_A                  = { Offset = Vector2.new(86,  468), Size = Vector2.new(34, 30), File = "Key_A.png" },
		Key_S                  = { Offset = Vector2.new(122, 468), Size = Vector2.new(34, 30), File = "Key_S.png" },
		Key_D                  = { Offset = Vector2.new(158, 468), Size = Vector2.new(34, 30), File = "Key_D.png" },
		Key_W_dn               = { Offset = Vector2.new(194, 468), Size = Vector2.new(34, 30), File = "Key_W_dn.png" },
		Key_A_dn               = { Offset = Vector2.new(230, 468), Size = Vector2.new(34, 30), File = "Key_A_dn.png" },
		Key_S_dn               = { Offset = Vector2.new(266, 468), Size = Vector2.new(34, 30), File = "Key_S_dn.png" },
		Key_D_dn               = { Offset = Vector2.new(302, 468), Size = Vector2.new(34, 30), File = "Key_D_dn.png" },
		-- Second sheet (Sheet = 2): 2005 Surface / Hopper toolbox art, CameraMenu states and Resize states
		FlatTool               = { Sheet = 2, Offset = Vector2.new(194, 54), Size = Vector2.new(60, 40) },
		FlatTool_dn            = { Sheet = 2, Offset = Vector2.new(2, 104), Size = Vector2.new(60, 40) },
		BumpTool               = { Sheet = 2, Offset = Vector2.new(64, 104), Size = Vector2.new(60, 40) },
		BumpTool_dn            = { Sheet = 2, Offset = Vector2.new(126, 104), Size = Vector2.new(60, 40) },
		HingeSurfaceTool       = { Sheet = 2, Offset = Vector2.new(188, 188), Size = Vector2.new(51, 40) },
		HingeSurfaceTool_dn    = { Sheet = 2, Offset = Vector2.new(2, 230), Size = Vector2.new(51, 40) },
		LeftMotorTool          = { Sheet = 2, Offset = Vector2.new(188, 104), Size = Vector2.new(60, 40) },
		LeftMotorTool_dn       = { Sheet = 2, Offset = Vector2.new(2, 146), Size = Vector2.new(60, 40) },
		LeftMotorFastTool      = { Sheet = 2, Offset = Vector2.new(64, 146), Size = Vector2.new(60, 40) },
		LeftMotorFastTool_dn   = { Sheet = 2, Offset = Vector2.new(126, 146), Size = Vector2.new(60, 40) },
		RightMotorTool         = { Sheet = 2, Offset = Vector2.new(188, 146), Size = Vector2.new(60, 40) },
		RightMotorTool_dn      = { Sheet = 2, Offset = Vector2.new(2, 188), Size = Vector2.new(60, 40) },
		RightMotorFastTool     = { Sheet = 2, Offset = Vector2.new(64, 188), Size = Vector2.new(60, 40) },
		RightMotorFastTool_dn  = { Sheet = 2, Offset = Vector2.new(126, 188), Size = Vector2.new(60, 40) },
		CameraZoomIn           = { Sheet = 2, Offset = Vector2.new(163, 230), Size = Vector2.new(34, 25) },
		CameraZoomIn_ovr       = { Sheet = 2, Offset = Vector2.new(199, 230), Size = Vector2.new(34, 25) },
		CameraZoomIn_dn        = { Sheet = 2, Offset = Vector2.new(2, 272), Size = Vector2.new(34, 25) },
		CameraZoomOut          = { Sheet = 2, Offset = Vector2.new(55, 230), Size = Vector2.new(34, 26) },
		CameraZoomOut_ovr      = { Sheet = 2, Offset = Vector2.new(91, 230), Size = Vector2.new(34, 26) },
		CameraZoomOut_dn       = { Sheet = 2, Offset = Vector2.new(127, 230), Size = Vector2.new(34, 26) },
		CameraTiltUp           = { Sheet = 2, Offset = Vector2.new(38, 272), Size = Vector2.new(24, 24) },
		CameraTiltUp_ovr       = { Sheet = 2, Offset = Vector2.new(64, 272), Size = Vector2.new(24, 24) },
		CameraTiltUp_dn        = { Sheet = 2, Offset = Vector2.new(90, 272), Size = Vector2.new(24, 24) },
		CameraTiltDown         = { Sheet = 2, Offset = Vector2.new(116, 272), Size = Vector2.new(24, 24) },
		CameraTiltDown_ovr     = { Sheet = 2, Offset = Vector2.new(142, 272), Size = Vector2.new(24, 24) },
		CameraTiltDown_dn      = { Sheet = 2, Offset = Vector2.new(168, 272), Size = Vector2.new(24, 24) },
		ScaleTool              = { Sheet = 2, Offset = Vector2.new(2, 2), Size = Vector2.new(50, 50) },
		ScaleTool_ovr          = { Sheet = 2, Offset = Vector2.new(54, 2), Size = Vector2.new(50, 50) },
		ScaleTool_dn           = { Sheet = 2, Offset = Vector2.new(106, 2), Size = Vector2.new(50, 50) },
		ScaleTool_ds           = { Sheet = 2, Offset = Vector2.new(158, 2), Size = Vector2.new(50, 50) },
		HopperGameTool         = { Sheet = 2, Offset = Vector2.new(2, 54), Size = Vector2.new(48, 48) },
		HopperGrab             = { Sheet = 2, Offset = Vector2.new(52, 54), Size = Vector2.new(48, 48) },
		HopperClone            = { Sheet = 2, Offset = Vector2.new(152, 54), Size = Vector2.new(40, 48) },
		HopperHammer           = { Sheet = 2, Offset = Vector2.new(102, 54), Size = Vector2.new(48, 48) },
		HopperSlingshot         = { Sheet = 2, Offset = Vector2.new(2, 301), Size = Vector2.new(48, 48) },
		HopperRocket            = { Sheet = 2, Offset = Vector2.new(52, 301), Size = Vector2.new(48, 48) },
		HopperLaser             = { Sheet = 2, Offset = Vector2.new(102, 301), Size = Vector2.new(48, 40) },
	}
end)()

-- Official cloud-hosted RBLX04 asset IDs from decompiled clp script
local RBLX04_CLOUD_MAP = {
	ArrowTool           = "rbxassetid://1134933286",
	ArrowTool_ovr       = "rbxassetid://1134933285",
	ArrowTool_dn        = "rbxassetid://1134933289",
	ArrowTool_ds        = "rbxassetid://1134933287",
	Cursor              = "rbxassetid://1134933286",
	Cursor_ovr          = "rbxassetid://1134933285",
	Cursor_dn           = "rbxassetid://1134933289",
	Cursor_ds           = "rbxassetid://1134933287",
	Resize              = "rbxassetid://2523068788",
	Resize_ovr          = "rbxassetid://2523068789",
	Resize_dn           = "rbxassetid://2523069439",
	Resize_ds           = "rbxassetid://2523068790",
	ScaleTool           = "rbxassetid://2523068788",
	ScaleTool_ovr       = "rbxassetid://2523068789",
	ScaleTool_dn        = "rbxassetid://2523069439",
	ScaleTool_ds        = "rbxassetid://2523068790",
	Move                = "rbxassetid://1134934804",
	MoveTool            = "rbxassetid://1134934804",
	MoveTool_ovr        = "rbxassetid://1134934805",
	MoveTool_dn         = "rbxassetid://1135042988",
	MoveTool_ds         = "rbxassetid://1134934803",
	AnchorTool          = "rbxassetid://1206277782",
	AnchorTool_ovr      = "rbxassetid://1206283205",
	AnchorTool_dn       = "rbxassetid://1206278229",
	AnchorTool_ds       = "rbxassetid://1206277782",
	LockTool            = "rbxassetid://1206223581",
	LockTool_ovr        = "rbxassetid://1206224222",
	LockTool_dn         = "rbxassetid://1206224222",
	LockTool_ds         = "rbxassetid://1206223581",
	SelectionRotate     = "rbxassetid://1087732278",
	SelectionRotate_ovr = "rbxassetid://1087732276",
	SelectionRotate_ds  = "rbxassetid://1087732273",
	RotateLeft          = "rbxassetid://1087732278",
	SelectionTilt       = "rbxassetid://1087733948",
	SelectionTilt_ovr   = "rbxassetid://1087733945",
	SelectionTilt_ds    = "rbxassetid://1087733920",
	RotateRight         = "rbxassetid://1087733948",
	SelectionUp         = "rbxassetid://1103065194",
	SelectionUp_ovr     = "rbxassetid://1103065195",
	SelectionUp_dn      = "rbxassetid://1103065192",
	SelectionUp_ds      = "rbxassetid://1103065193",
	SelectionDown       = "rbxassetid://1103063039",
	SelectionDown_ovr   = "rbxassetid://1103063043",
	SelectionDown_dn    = "rbxassetid://1103064334",
	SelectionDown_ds    = "rbxassetid://1103064332",
	PlayDelete          = "rbxassetid://1087743993",
	PlayDelete_ovr      = "rbxassetid://1087743995",
	PlayDelete_dn       = "rbxassetid://1087743994",
	PlayDelete_ds       = "rbxassetid://1087744001",
	Trash               = "rbxassetid://1087743993",
	Trash_ovr           = "rbxassetid://1087743995",
	Trash_open          = "rbxassetid://1087743995",
	Trash_dn            = "rbxassetid://1087743994",
	Run                 = "rbxassetid://1087629821",
	Run_ovr             = "rbxassetid://1087629820",
	Run_dn              = "rbxassetid://1087629815",
	Run_ds              = "rbxassetid://1087629819",
	GO                  = "rbxassetid://1087629821",
	Stop                = "rbxassetid://1087743485",
	Stop_ovr            = "rbxassetid://1087743489",
	Stop_dn             = "rbxassetid://1087743488",
	Stop_ds             = "rbxassetid://1087743487",
	STOP                = "rbxassetid://1087743485",
	STOP_ovr            = "rbxassetid://1087743489",
	STOP_dn             = "rbxassetid://1087743488",
	STOP_ds             = "rbxassetid://1087743487",
	Reset               = "rbxassetid://1087735480",
	Reset_ovr           = "rbxassetid://1087735482",
	Reset_dn            = "rbxassetid://1087735485",
	Reset_ds            = "rbxassetid://1087735483",
	ResetOrg            = "rbxassetid://1087735480",
	ResetOrg_ovr        = "rbxassetid://1087735482",
	ResetOrg_dn         = "rbxassetid://1087735485",
	ResetOrg_ds         = "rbxassetid://1087735483",
	CameraZoomIn        = "rbxassetid://5973867006",
	CameraZoomIn_ovr    = "rbxassetid://5973867429",
	CameraZoomIn_dn     = "rbxassetid://5973867164",
	CameraZoomOut       = "rbxassetid://5973867659",
	CameraZoomOut_ovr   = "rbxassetid://5973868056",
	CameraZoomOut_dn    = "rbxassetid://5973867866",
	CameraPanLeft       = "rbxassetid://5973870788",
	CameraPanLeft_ovr   = "rbxassetid://5973871105",
	CameraPanRight      = "rbxassetid://5973870113",
	CameraPanRight_ovr  = "rbxassetid://5973870521",
	CameraTiltUp        = "rbxassetid://5973871431",
	CameraTiltUp_ovr    = "rbxassetid://5973871605",
	CameraTiltDown      = "rbxassetid://5973869636",
	CameraTiltDown_ovr  = "rbxassetid://5973869877",
	ArrowLeft           = "rbxassetid://138679913085732",
	ArrowLeft_ovr       = "rbxassetid://71109184122080",
}
S.RBLX04_CLOUD_MAP = RBLX04_CLOUD_MAP

if ContentProvider then
	task.spawn(function()
		local list = {}
		for _, url in pairs(RBLX04_CLOUD_MAP) do
			table.insert(list, url)
		end
		pcall(function() ContentProvider:PreloadAsync(list) end)
	end)
end

local function applySpriteToImage(imgObj, spriteName, fallbackGui)
	local info = S.SPRITE_MAP[spriteName]
	local cloudUrl = RBLX04_CLOUD_MAP[spriteName]
	if not info and not cloudUrl then return false end
	local assigned = false
	local sheetUrl = nil
	if info then
		sheetUrl = (info.Sheet == 2) and S.CustomSheet2Url or (info.Sheet ~= 2 and S.CustomSheetUrl) or nil
	end
	if sheetUrl then
		imgObj.Image = sheetUrl
		imgObj.ImageRectOffset = info.Offset
		imgObj.ImageRectSize = info.Size
		assigned = true
	elseif info and info.File and info.File ~= "" and S.DirectFileUrls[info.File] then
		imgObj.Image = S.DirectFileUrls[info.File]
		imgObj.ImageRectOffset = Vector2.zero
		imgObj.ImageRectSize = Vector2.zero
		assigned = true
	elseif spriteName == "ArrowLeft" and S.RawGalleryArrowUrl then
		imgObj.Image = S.RawGalleryArrowUrl
		imgObj.ImageRectOffset = Vector2.zero
		imgObj.ImageRectSize = Vector2.zero
		assigned = true
	elseif spriteName == "ArrowRight" and S.RawGalleryArrowUrl then
		imgObj.Image = S.RawGalleryArrowUrl
		imgObj.ImageRectOffset = Vector2.zero
		imgObj.ImageRectSize = Vector2.zero
		imgObj.Rotation = 180
		assigned = true
	elseif cloudUrl then
		imgObj.Image = cloudUrl
		imgObj.ImageRectOffset = Vector2.zero
		imgObj.ImageRectSize = Vector2.zero
		assigned = true
	end

	if fallbackGui then
		fallbackGui.Visible = not assigned
	end
	if not info then
		return assigned
	end
	return assigned, info.Size.X, info.Size.Y
end

local function bindButtonSprites(btn, fallbackGui, normalSprite, ovrSprite, dnSprite, dsSprite, isDisabledFn, isActiveFn)
	local isHovered = false
	local isPressed = false
	local function refresh()
		if isDisabledFn and isDisabledFn() and dsSprite then
			applySpriteToImage(btn, dsSprite, fallbackGui)
		elseif (isPressed or (isActiveFn and isActiveFn())) and dnSprite then
			applySpriteToImage(btn, dnSprite, fallbackGui)
		elseif isHovered and ovrSprite then
			applySpriteToImage(btn, ovrSprite, fallbackGui)
		else
			applySpriteToImage(btn, normalSprite, fallbackGui)
		end
	end
	storeConnection(btn.MouseEnter:Connect(function()
		isHovered = true
		refresh()
	end))
	storeConnection(btn.MouseLeave:Connect(function()
		isHovered = false
		isPressed = false
		refresh()
	end))
	storeConnection(btn.MouseButton1Down:Connect(function()
		isPressed = true
		refresh()
	end))
	storeConnection(btn.MouseButton1Up:Connect(function()
		isPressed = false
		refresh()
	end))
	refresh()
	return refresh
end

--========================================================
-- NO DIALOG BUBBLES & NO 3-DOT OVERHEAD INDICATORS
--========================================================
do
	local DIALOG_BUBBLE_MARKER = "Classic2006HiddenBubble"
	local hiddenDialogBubbles = setmetatable({}, { __mode = "k" })

	local function isCharacterAttachedBillboard(gui)
		local adornee = gui.Adornee
		if adornee and adornee:IsDescendantOf(Workspace) then
			local m = adornee:FindFirstAncestorOfClass("Model")
			if m and (m:FindFirstChildOfClass("Humanoid") or Players:GetPlayerFromCharacter(m)) then
				return true
			end
		end
		local pModel = gui:FindFirstAncestorOfClass("Model")
		if pModel and (pModel:FindFirstChildOfClass("Humanoid") or Players:GetPlayerFromCharacter(pModel)) then
			return true
		end
		return false
	end

	local function isDialogOr3DotBubble(gui)
		if gui:GetAttribute("ClassicOwned") then
			return false
		end
		if isCharacterAttachedBillboard(gui) then
			return true
		end
		local name = string.lower(gui.Name)
		if name == "chatnotificationgui"
			or name == "playerdialogbubble"
			or name == "bubblechat"
			or name == "voicebubble"
			or string.find(name, "bubble", 1, true)
			or string.find(name, "voice", 1, true)
			or string.find(gui.Name, "^ClassicExecutorDialogGui_") then
			return true
		end
		for _, child in ipairs(gui:GetDescendants()) do
			if child:IsA("ImageLabel") or child:IsA("ImageButton") then
				local image = string.lower(child.Image)
				local cname = string.lower(child.Name)
				if string.find(image, "dialog_purpose", 1, true)
					or string.find(image, "notify_bkg", 1, true)
					or string.find(image, "chatbubble", 1, true)
					or string.find(image, "voice", 1, true)
					or string.find(cname, "ellipsis", 1, true)
					or string.find(cname, "three", 1, true)
					or string.find(cname, "caret", 1, true) then
					return true
				end
			elseif (child:IsA("TextLabel") or child:IsA("TextButton")) and child.Text == "..." then
				return true
			end
		end
		return false
	end

	local function hideDialogBubble(gui)
		if hiddenDialogBubbles[gui] or not isDialogOr3DotBubble(gui) then
			return
		end
		hiddenDialogBubbles[gui] = true
		pcall(gui.SetAttribute, gui, DIALOG_BUBBLE_MARKER, true)
		gui.Enabled = false
		storeConnection(gui:GetPropertyChangedSignal("Enabled"):Connect(function()
			if gui.Enabled then
				gui.Enabled = false
			end
		end))
	end

	local function watchDialogBubbles(root)
		if not Config.SHOW_DIALOG_BUBBLES or Config.REMOVE_ALL_3DOT_BUBBLES then
			storeConnection(root.DescendantAdded:Connect(function(obj)
				if obj:IsA("BillboardGui") then
					task.defer(pcall, hideDialogBubble, obj)
				end
			end))
		end
		for _, obj in ipairs(root:GetDescendants()) do
			if obj:IsA("BillboardGui") then
				pcall(hideDialogBubble, obj)
			end
		end
	end

	local dialogBubbleRoots = { CoreGui, Workspace, LocalPlayer:WaitForChild("PlayerGui") }
	if parentTarget ~= CoreGui and not parentTarget:IsDescendantOf(CoreGui) then
		table.insert(dialogBubbleRoots, parentTarget)
	end
	for _, root in ipairs(dialogBubbleRoots) do
		task.spawn(pcall, watchDialogBubbles, root)
	end
end

--========================================================
-- 2006 BITMAP FONT RENDERER
--========================================================
local get2006TextWidth, apply2006Font
S._run = (function()
local FONT_SHEET = "rbxassetid://11363842965"
local GLYPH_WIDTHS = {}
for code, hex in ipairs({
	"1A", "1A", "1A", "1A", "1A", "1A", "1A", "1A", "1A", "60", "1A", "1A", "00", "1A", "1A", "1A",
	"1A", "1A", "1A", "1A", "1A", "1A", "1A", "1A", "1A", "1A", "1A", "1A", "1A", "1A", "1A", "07",
	"08", "09", "10", "10", "16", "13", "05", "09", "09", "0D", "10", "07", "07", "07", "0B", "10",
	"10", "10", "10", "10", "10", "10", "10", "10", "10", "07", "07", "0D", "10", "0D", "0D", "16",
	"14", "11", "11", "14", "10", "0F", "14", "14", "08", "0C", "11", "0E", "17", "14", "16", "0F",
	"16", "10", "0D", "0F", "14", "12", "1B", "11", "0F", "10", "09", "0B", "09", "0D", "0D", "0D",
	"0F", "10", "0D", "10", "0F", "09", "10", "11", "07", "07", "0E", "07", "17", "11", "10", "10",
	"10", "0A", "0B", "0A", "10", "0E", "17", "0E", "0E", "0D", "0B", "0D", "0B", "11", "1A"
}) do
	GLYPH_WIDTHS[code] = tonumber(hex, 16)
end
local OUTLINE_OFFSETS = {
	Vector2.new(-1, -1),
	Vector2.new(1, 1),
	Vector2.new(1, -1),
	Vector2.new(-1, 1)
}
local FALLBACK_FONT = nil
pcall(function()
	FALLBACK_FONT = Font.new(
		"rbxasset://fonts/families/Nunito.json",
		Enum.FontWeight.ExtraBold,
		Enum.FontStyle.Italic
	)
end)
local HIDDEN = 0.9990234375
local MAX_BITMAP_CHARACTERS = 300
local fontSheetFailed = false
local fontStates = setmetatable({}, { __mode = "k" })

local function glyphCode(byte)
	if GLYPH_WIDTHS[byte] then
		return byte
	end
	return 1
end

local function measure2006Line(line, size)
	local width = 0
	for i = 1, #line do
		width = width + GLYPH_WIDTHS[glyphCode(string.byte(line, i))]
	end
	return width / 32 * size
end

local function layout2006Lines(text, size, maxWidth)
	local lines = {}
	for _, paragraph in ipairs(string.split(text, "\n")) do
		local current = nil
		for _, word in ipairs(string.split(paragraph, " ")) do
			if current == nil then
				current = word
			elseif maxWidth and measure2006Line(current .. " " .. word, size) > maxWidth then
				table.insert(lines, current)
				current = word
			else
				current = current .. " " .. word
			end
		end
		table.insert(lines, current or "")
	end
	return lines
end

function get2006TextWidth(text, textSize)
	return measure2006Line(text, textSize + 4)
end

local function getCumulativeScale(object)
	local scale = 1
	while object do
		local uiScale = object:FindFirstChildOfClass("UIScale")
		if uiScale then
			scale = scale * uiScale.Scale
		end
		object = object.Parent
	end
	return math.max(scale, 0.001)
end

local function getScaledSize(text, label, maxWidth, maxHeight)
	local lineHeight = label.LineHeight
	if label.TextWrapped then
		local low, high = 1, math.max(1, math.min(maxHeight, 104))
		for _ = 1, 12 do
			local size = (low + high) / 2
			local lines = layout2006Lines(text, size, maxWidth)
			local fits = (#lines - 1) * size * lineHeight + size <= maxHeight
			for _, line in ipairs(lines) do
				if fits and measure2006Line(line, size) > maxWidth then
					fits = false
				end
			end
			if fits then
				low = size
			else
				high = size
			end
		end
		return low
	end
	local lines = string.split(text, "\n")
	local widest = 0
	for _, line in ipairs(lines) do
		widest = math.max(widest, measure2006Line(line, 1))
	end
	local size = maxHeight / ((#lines - 1) * lineHeight + 1)
	if widest > 0 then
		size = math.min(size, maxWidth / widest)
	end
	return math.clamp(size, 1, 104)
end

local function getPooledImage(pool, index, parent, name)
	local image = pool[index]
	if not image then
		image = Instance.new("ImageLabel")
		image.Name = name
		image.BackgroundTransparency = 1
		image.Image = FONT_SHEET
		image.Parent = parent
		pool[index] = image
	end
	image.Visible = true
	return image
end

local function show2006Fallback(state)
	local label = state.label
	if state.content then
		state.content.Visible = false
	end
	if state.uiStroke then
		state.uiStroke.Enabled = true
	end
	pcall(function() label.FontFace = FALLBACK_FONT end)
	label.TextTransparency = state.textTransparency
	label.TextStrokeTransparency = state.strokeTransparency
end

local function hasNonAsciiByte(s)
	for i = 1, #s do
		if string.byte(s, i) >= 128 then
			return true
		end
	end
	return false
end

local function render2006(state)
	local label = state.label
	if label:GetAttribute("No2006Font") then
		return
	end
	local text = string.gsub(label.Text, "\r", "")
	text = string.gsub(text, "\t", "    ")
	if fontSheetFailed
		or label.RichText
		or #text > MAX_BITMAP_CHARACTERS
		or hasNonAsciiByte(text) then
		state.layoutKey = nil
		state.scaledAspect = nil
		show2006Fallback(state)
		return
	end
	local wrapWidth = state.wrapWidth
	local size = label.TextSize + 4
	local available = nil
	if label.TextScaled or (label.TextWrapped and not wrapWidth) then
		available = label.AbsoluteSize / getCumulativeScale(label)
		if label.TextWrapped then
			wrapWidth = wrapWidth or available.X
		end
		if label.TextScaled then
			size = getScaledSize(text, label, wrapWidth or available.X, available.Y)
		end
	end
	local lines = layout2006Lines(text, size, wrapWidth)
	local layoutKey = tostring(size) .. "\n" .. table.concat(lines, "\n")
	if layoutKey == state.layoutKey and state.content and state.content.Parent == label then
		return
	end
	label.TextTransparency = HIDDEN
	label.TextStrokeTransparency = HIDDEN
	if state.uiStroke then
		state.uiStroke.Enabled = false
	end
	local content = state.content
	if not content or content.Parent ~= label then
		content = Instance.new("Frame")
		content.Name = "TextContent"
		content.BackgroundTransparency = 1
		content:SetAttribute("CustomFont", true)
		content.Parent = label
		state.content = content
		state.glyphs = {}
		state.outlines = {}
	end
	content.Visible = true

	local lineAdvance = size * label.LineHeight
	local lineWidths = {}
	local blockWidth = 0
	for i, line in ipairs(lines) do
		lineWidths[i] = measure2006Line(line, size)
		blockWidth = math.max(blockWidth, lineWidths[i])
	end
	local alignX = 0
	if label.TextXAlignment == Enum.TextXAlignment.Center then
		alignX = 0.5
	elseif label.TextXAlignment == Enum.TextXAlignment.Right then
		alignX = 1
	end
	local alignY = 0
	if label.TextYAlignment == Enum.TextYAlignment.Center then
		alignY = 0.5
	elseif label.TextYAlignment == Enum.TextYAlignment.Bottom then
		alignY = 1
	end
	local blockHeight = (#lines - 1) * lineAdvance + size
	local relative = label.TextScaled and available ~= nil and available.X > 0 and available.Y > 0 and blockWidth > 0
	local function place(x, y, offsetX, offsetY)
		if relative then
			return UDim2.new(x / blockWidth, offsetX, y / blockHeight, offsetY)
		end
		return UDim2.fromOffset(x + offsetX, y + offsetY)
	end
	content.AnchorPoint = Vector2.new(alignX, alignY)
	content.Position = UDim2.new(alignX, 0, alignY, 0)
	if relative then
		content.Size = UDim2.fromScale(blockWidth / available.X, blockHeight / available.Y)
	else
		content.Size = UDim2.fromOffset(blockWidth, blockHeight)
	end

	local textColor = label.TextColor3
	local strokeColor = label.TextStrokeColor3
	local strokeTransparency = state.strokeTransparency
	if state.uiStroke then
		strokeColor = state.uiStroke.Color
		strokeTransparency = state.uiStroke.Transparency
	end
	local glyphTransparency = state.textTransparency
	local outlineTransparency = 1 - (1 - strokeTransparency) * (1 - glyphTransparency)
	local visibleCount = label.MaxVisibleGraphemes
	local glyphCount = 0
	local outlineCount = 0
	local characterCount = 0
	for lineIndex, line in ipairs(lines) do
		local x = (blockWidth - lineWidths[lineIndex]) * alignX
		local y = (lineIndex - 1) * lineAdvance
		for i = 1, #line do
			characterCount = characterCount + 1
			if visibleCount >= 0 and characterCount > visibleCount then
				break
			end
			local code = glyphCode(string.byte(line, i))
			local width = GLYPH_WIDTHS[code]
			local pixelWidth = width / 32 * size
			if code ~= 32 then
				local rectOffset = Vector2.new((code * 32) % 512 + (32 - width) / 2, math.floor(code / 16) * 32)
				local rectSize = Vector2.new(width, 32)
				glyphCount = glyphCount + 1
				local glyph = getPooledImage(state.glyphs, glyphCount, content, "Glyph")
				glyph.ImageRectOffset = rectOffset
				glyph.ImageRectSize = rectSize
				glyph.Size = place(pixelWidth, size, 0, 0)
				glyph.Position = place(x, y, 0, 0)
				if state.prefixLength and characterCount <= state.prefixLength then
					glyph.ImageColor3 = state.prefixColor
				else
					glyph.ImageColor3 = textColor
				end
				glyph.ImageTransparency = glyphTransparency
				glyph.ZIndex = label.ZIndex + 2
				if outlineTransparency < 1 then
					for _, shift in ipairs(OUTLINE_OFFSETS) do
						outlineCount = outlineCount + 1
						local outline = getPooledImage(state.outlines, outlineCount, content, "Outline")
						outline.ImageRectOffset = rectOffset
						outline.ImageRectSize = rectSize
						outline.Size = glyph.Size
						outline.Position = place(x, y, shift.X, shift.Y)
						outline.ImageColor3 = strokeColor
						outline.ImageTransparency = outlineTransparency
						outline.ZIndex = label.ZIndex + 1
					end
				end
			end
			x = x + pixelWidth
		end
		characterCount = characterCount + 1
	end
	for i = glyphCount + 1, #state.glyphs do
		state.glyphs[i].Visible = false
	end
	for i = outlineCount + 1, #state.outlines do
		state.outlines[i].Visible = false
	end
	state.scaledAspect = relative and available.X / available.Y or nil
	state.layoutKey = not relative and layoutKey or nil
end

local function safeRender2006(state)
	if not pcall(render2006, state) then
		state.layoutKey = nil
		state.scaledAspect = nil
		pcall(show2006Fallback, state)
	end
end

local function queue2006Render(state, sizeOnly)
	if not sizeOnly then
		state.layoutKey = nil
	end
	if state.queued then
		return
	end
	state.queued = true
	task.defer(function()
		state.queued = false
		safeRender2006(state)
	end)
end

function apply2006Font(label, opts)
	if fontStates[label] or label:GetAttribute("No2006Font") then
		return
	end
	opts = opts or {}
	local state = {
		label = label,
		wrapWidth = opts.wrapWidth,
		prefixLength = opts.prefixLength,
		prefixColor = opts.prefixColor,
		textTransparency = label.TextTransparency,
		strokeTransparency = label.TextStrokeTransparency,
		glyphs = {},
		outlines = {}
	}
	fontStates[label] = state
	label.Destroying:Connect(function()
		fontStates[label] = nil
	end)
	label:SetAttribute("Classic2006Font", true)
	for _, child in ipairs(label:GetChildren()) do
		if child:IsA("UIStroke")
			and child.Enabled
			and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
			state.uiStroke = child
			child:GetPropertyChangedSignal("Color"):Connect(function()
				queue2006Render(state)
			end)
			child:GetPropertyChangedSignal("Transparency"):Connect(function()
				queue2006Render(state)
			end)
			break
		end
	end
	for _, property in ipairs({
		"Text", "TextSize", "TextColor3", "TextStrokeColor3", "TextXAlignment", "TextYAlignment",
		"TextScaled", "TextWrapped", "RichText", "LineHeight", "MaxVisibleGraphemes", "ZIndex"
	}) do
		label:GetPropertyChangedSignal(property):Connect(function()
			queue2006Render(state)
		end)
	end
	label:GetPropertyChangedSignal("TextTransparency"):Connect(function()
		if math.abs(label.TextTransparency - HIDDEN) > 0.0001 then
			state.textTransparency = label.TextTransparency
			queue2006Render(state)
		end
	end)
	label:GetPropertyChangedSignal("TextStrokeTransparency"):Connect(function()
		if math.abs(label.TextStrokeTransparency - HIDDEN) > 0.0001 then
			state.strokeTransparency = label.TextStrokeTransparency
			queue2006Render(state)
		end
	end)
	label:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if not (label.TextScaled or (label.TextWrapped and not state.wrapWidth)) then
			return
		end
		local aspect = state.scaledAspect
		local absoluteSize = label.AbsoluteSize
		if aspect and label.TextScaled and absoluteSize.Y > 0
			and math.abs(absoluteSize.X / absoluteSize.Y / aspect - 1) < 0.005 then
			return
		end
		queue2006Render(state, true)
	end)
	safeRender2006(state)
end

task.spawn(function()
	local probe = Instance.new("ImageLabel")
	probe.Image = FONT_SHEET
	pcall(function()
		ContentProvider:PreloadAsync({ probe }, function(_, status)
			if status.Name == "Failure" or status.Name == "TimedOut" then
				fontSheetFailed = true
			end
		end)
	end)
	probe:Destroy()
	if fontSheetFailed then
		for _, state in pairs(fontStates) do
			queue2006Render(state)
		end
	end
end)
end)()

--========================================================
-- UI SCALE & CLASSIC SOUNDS
--========================================================
local function getClassicUIScale()
	Camera = Workspace.CurrentCamera
	if not Camera then return 1 end
	local viewport = Camera.ViewportSize
	if viewport.Y > 0 and (viewport.Y < 800 or viewport.X < 1200) then
		return math.clamp(viewport.Y / 610, 0.50, 1)
	end
	return 1
end
local function scaleTextSize(textSize, scale)
	return (textSize + 4) * scale - 4
end

local SOUND_CLICK = "rbxasset://sounds/switch.wav"
local SOUND_BOOP  = "rbxasset://sounds/electronicpingshort.wav"
local SOUND_TICK  = "rbxasset://sounds/clickfast.wav"
local SOUND_SNAP  = "rbxasset://sounds/snap.mp3"
local SOUND_WIN   = "rbxasset://sounds/victory.wav"
local SOUND_PAGE  = "rbxasset://sounds/pageturn.wav"

local function playClassicSound(soundId, volume, pitch)
	pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = soundId
		s.Volume = volume or 0.5
		s.PlaybackSpeed = pitch or 1
		s.Parent = SoundService
		s:Play()
		task.delay(2.5, function()
			if s then s:Destroy() end
		end)
	end)
end

--========================================================
-- MAIN SCREEN GUI
--========================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Classic2010Gui"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 5
parentGui(ScreenGui)

local uiScale = Instance.new("UIScale")
uiScale.Parent = ScreenGui
local function updateUIScale()
	uiScale.Scale = getClassicUIScale()
end
if Camera then
	storeConnection(Camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateUIScale))
end
updateUIScale()

-- Hide obstructive left-side game buttons
if Config.HIDE_OBSTRUCTIVE_LEFT_GAME_GUIS then
	task.spawn(function()
		local pg = LocalPlayer:WaitForChild("PlayerGui", 5)
		if not pg then return end
		local function checkLeftGui(obj)
			if obj:IsA("GuiObject") and not obj:IsDescendantOf(ScreenGui) then
				local txt = (obj:IsA("TextLabel") or obj:IsA("TextButton")) and string.lower(obj.Text) or ""
				if txt == "shop" or txt == "balloons" or txt == "mute music" then
					local frame = obj:IsA("TextButton") and obj or obj.Parent
					if frame and frame:IsA("GuiObject") then
						frame.Visible = false
					end
				end
			end
		end
		for _, d in ipairs(pg:GetDescendants()) do
			pcall(checkLeftGui, d)
		end
		storeConnection(pg.DescendantAdded:Connect(function(d)
			task.defer(pcall, checkLeftGui, d)
		end))
	end)
end

--========================================================
-- PROCEDURAL 2005 3D GLOSSY ICON BUILDERS (FALLBACK WHEN NO CUSTOM ASSET)
--========================================================
local function addCircleCorner(parent, radiusScale)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(radiusScale or 1, 0)
	c.Parent = parent
	return c
end

local function createMetallicOrbFallback(parent, innerText, textColor, isGreenGo, isRedStop, isYellowSurface)
	local orb = Instance.new("Frame")
	orb.Name = "FallbackOrb"
	orb.AnchorPoint = Vector2.new(0.5, 0.5)
	orb.Position = UDim2.new(0.5, 0, 0.5, 0)
	orb.Size = UDim2.new(1, -2, 1, -2)
	orb.BorderSizePixel = 0
	orb.Parent = parent

	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	if isGreenGo then
		orb.BackgroundColor3 = Color3.fromRGB(60, 215, 100)
		addCircleCorner(orb, 1)
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(175, 255, 195)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 185, 65)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 235, 130))
		})
	elseif isRedStop then
		orb.BackgroundColor3 = Color3.fromRGB(230, 50, 50)
		addCircleCorner(orb, 0.22)
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 185, 185)),
			ColorSequenceKeypoint.new(0.48, Color3.fromRGB(235, 50, 50)),
			ColorSequenceKeypoint.new(0.52, Color3.fromRGB(180, 20, 20)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 45, 45))
		})
	elseif isYellowSurface then
		orb.BackgroundColor3 = Color3.fromRGB(235, 235, 80)
		addCircleCorner(orb, 1)
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 175)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(190, 190, 25)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 240, 70))
		})
	else
		orb.BackgroundColor3 = Color3.fromRGB(225, 225, 230)
		addCircleCorner(orb, 1)
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(175, 175, 180)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 235, 240))
		})
	end
	grad.Parent = orb

	local rim = Instance.new("UIStroke")
	rim.Thickness = isGreenGo and 3 or 2
	rim.Color = Color3.fromRGB(95, 95, 100)
	rim.Parent = orb

	local lbl = Instance.new("TextLabel")
	lbl:SetAttribute("No2006Font", true)
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.Oswald
	lbl.Text = innerText or ""
	lbl.TextColor3 = textColor or Color3.fromRGB(20, 50, 210)
	lbl.TextScaled = true
	lbl.Parent = orb
	return orb, lbl, grad
end

--========================================================

-- 1. TOP MENU BAR, FPS COUNTER & MODE INDICATOR
local TopBar, FPSLabel, ScoreTimerFrame, TopResetBtn, CenterBanner, CenterBannerText
local showCenterBanner, getTotalScore, updateScoreTimerUI
local GoStopBtn, updateGoStopVisual, RotateLeftBtn, RotateRightBtn
local TrashBtn, MenuBtn, refreshAllToolbarSprites, setStudioTool
local BottomLeftArrow, CategoryBox, CategoryText, AllModelsLink, BottomRightArrow, BottomItemsContainer
local rebuildBottomBarContent
S._run = (function()

--========================================================
TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 26)
TopBar.Position = UDim2.new(0, 0, 0, 0)
TopBar.BackgroundTransparency = 1
TopBar.Parent = ScreenGui
S.TopBar = TopBar

FPSLabel = Instance.new("TextLabel")
FPSLabel.Name = "FPSLabel"
FPSLabel:SetAttribute("No2006Font", true)
-- 2005 client draws "FPS: 30.000" small and yellow just under the Edit menu (x = 120, y = 25)
FPSLabel.Position = UDim2.new(0, 120, 0, 26)
FPSLabel.Size = UDim2.new(0, 200, 0, 14)
FPSLabel.BackgroundTransparency = 1
FPSLabel.Font = Enum.Font.Oswald
FPSLabel.TextSize = 12
FPSLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
FPSLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
FPSLabel.TextStrokeTransparency = 0
FPSLabel.TextXAlignment = Enum.TextXAlignment.Left
FPSLabel.Text = "FPS: 30.000"
FPSLabel.Visible = Config.SHOW_2005_FPS
FPSLabel.Parent = ScreenGui
S.FPSLabel = FPSLabel

--========================================================
-- 2. TOP-RIGHT 2005 TIMER & SCORE (TRUE 2005 IMPACT FONT + PERSISTENT POOLED SLOTS THAT NEVER DISAPPEAR ON GO!)
--========================================================
ScoreTimerFrame = Instance.new("Frame")
ScoreTimerFrame.Name = "ScoreTimerFrame"
-- 2005 client: "Timer:" at (screen width - 120, 25) and "Score:" at (screen width - 120, 50), 20px, 0x81C518 with black outline
ScoreTimerFrame.AnchorPoint = Vector2.new(1, 0)
ScoreTimerFrame.Position = UDim2.new(1, 0, 0, 25)
ScoreTimerFrame.Size = UDim2.new(0, 120, 0, 50)
ScoreTimerFrame.BackgroundTransparency = 1
ScoreTimerFrame.Parent = ScreenGui
S.ScoreTimerFrame = ScoreTimerFrame

local SCORE_TOKEN_SPRITES = {
	["Timer:"] = "ScoreTok_Timer",
	["Score:"] = "ScoreTok_Score",
	["0"]      = "ScoreTok_0",
	["1"]      = "ScoreTok_1",
	["2"]      = "ScoreTok_2",
	["3"]      = "ScoreTok_3",
	["4"]      = "ScoreTok_4",
	["5"]      = "ScoreTok_5",
	["6"]      = "ScoreTok_6",
	["7"]      = "ScoreTok_7",
	["8"]      = "ScoreTok_8",
	["9"]      = "ScoreTok_9",
	["."]      = "ScoreTok_Dot",
}

local MAX_DIGIT_SLOTS = 12

local function create2005ScoreLine(name, defaultText, posY)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn:SetAttribute("No2006Font", true)
	btn.Position = UDim2.new(0, 0, 0, posY)
	btn.Size = UDim2.new(1, 0, 0, 24)
	btn.BackgroundTransparency = 1
	btn.AutoButtonColor = false
	btn.Font = Enum.Font.Oswald
	pcall(function()
		btn.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	end)
	btn.Text = defaultText
	btn.TextSize = 20
	btn.TextColor3 = Color3.fromRGB(129, 197, 24) -- 0x81C518
	btn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	btn.TextStrokeTransparency = 0
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.Parent = ScoreTimerFrame

	local stroke = Instance.new("UIStroke")
	stroke.Name = "ThickBlackStroke"
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 1.6
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = btn

	local glyphRow = Instance.new("Frame")
	glyphRow.Name = "BitmapGlyphRow"
	glyphRow.AnchorPoint = Vector2.new(0, 0.5)
	glyphRow.Position = UDim2.new(0, 0, 0.5, 0)
	glyphRow.Size = UDim2.new(1, 0, 0, 24)
	glyphRow.BackgroundTransparency = 1
	glyphRow.Parent = btn

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, -1)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = glyphRow

	-- Pre-allocate persistent pooled ImageLabels ONCE so we NEVER destroy/recreate ImageLabels during RenderStepped!
	local wordSlot = Instance.new("ImageLabel")
	wordSlot.Name = "WordSlot"
	wordSlot.LayoutOrder = 1
	wordSlot.BackgroundTransparency = 1
	wordSlot.Visible = false
	wordSlot.Parent = glyphRow

	local gapSpacer = Instance.new("Frame")
	gapSpacer.Name = "GapSpacer"
	gapSpacer.LayoutOrder = 2
	gapSpacer.Size = UDim2.new(0, 4, 0, 1)
	gapSpacer.BackgroundTransparency = 1
	gapSpacer.Visible = false
	gapSpacer.Parent = glyphRow

	for i = 1, MAX_DIGIT_SLOTS do
		local dSlot = Instance.new("ImageLabel")
		dSlot.Name = "DigitSlot_" .. i
		dSlot.LayoutOrder = 2 + i
		dSlot.BackgroundTransparency = 1
		dSlot.Visible = false
		dSlot.Parent = glyphRow
	end

	return btn
end

local function render2005ScoreBitmapLine(btn, prefixWord, valStr)
	if not btn then return end
	local fullText = prefixWord .. " " .. valStr
	if btn:GetAttribute("LastRenderedScoreText") == fullText then
		return
	end
	btn:SetAttribute("LastRenderedScoreText", fullText)
	btn.Text = fullText

	local glyphRow = btn:FindFirstChild("BitmapGlyphRow")
	local wordSlot = glyphRow and glyphRow:FindFirstChild("WordSlot")
	local gapSpacer = glyphRow and glyphRow:FindFirstChild("GapSpacer")
	if not S.CustomSheetUrl or not glyphRow or not wordSlot then
		btn.TextTransparency = 0
		local st = btn:FindFirstChild("ThickBlackStroke")
		if st then st.Enabled = true end
		return
	end

	local scale = 0.5 -- 42px tokens -> the 2005 client's 20px Timer/Score text
	local wSprite = SCORE_TOKEN_SPRITES[prefixWord]
	local okWord, ww, wh = applySpriteToImage(wordSlot, wSprite)
	if not okWord or not ww or not wh then
		wordSlot.Visible = false
		if gapSpacer then gapSpacer.Visible = false end
		btn.TextTransparency = 0
		local st = btn:FindFirstChild("ThickBlackStroke")
		if st then st.Enabled = true end
		return
	end

	wordSlot.Size = UDim2.new(0, math.floor(ww * scale + 0.5), 0, math.floor(wh * scale + 0.5))
	wordSlot.Visible = true
	if gapSpacer then gapSpacer.Visible = true end

	local nChars = math.min(#valStr, MAX_DIGIT_SLOTS)
	for i = 1, MAX_DIGIT_SLOTS do
		local dSlot = glyphRow:FindFirstChild("DigitSlot_" .. i)
		if dSlot then
			if i <= nChars then
				local ch = string.sub(valStr, i, i)
				local dSprite = SCORE_TOKEN_SPRITES[ch]
				local okD, dw, dh = applySpriteToImage(dSlot, dSprite)
				if okD and dw and dh then
					dSlot.Size = UDim2.new(0, math.floor(dw * scale + 0.5), 0, math.floor(dh * scale + 0.5))
					dSlot.Visible = true
				else
					dSlot.Visible = false
				end
			else
				dSlot.Visible = false
			end
		end
	end

	btn.TextTransparency = 1
	local st = btn:FindFirstChild("ThickBlackStroke")
	if st then st.Enabled = false end
end

S.TimerLabel = create2005ScoreLine("TimerLabel", string.format("Timer: %.1f", S.currentTimerValue), 0)
S.ScoreLabel = create2005ScoreLine("ScoreLabel", "Score: 0", 25)

-- RBLX04 on-screen W/A/S/D keypad (+ reset flag). The 2005 client had no such HUD (it was keyboard-only),
-- so it is only shown on touch-only devices where it is the only way to drive a controlled model.
S.hudKeysDown = { W = false, A = false, S = false, D = false }
S.WASDControllerFrame = Instance.new("Frame")
S.WASDControllerFrame.Name = "WASDControllerWidget"
S.WASDControllerFrame.AnchorPoint = Vector2.new(1, 0)
S.WASDControllerFrame.Position = UDim2.new(1, -2, 0, 56)
S.WASDControllerFrame.Size = UDim2.new(0, 110, 0, 64)
S.WASDControllerFrame.BackgroundTransparency = 1
S.WASDControllerFrame.Visible = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
S.WASDControllerFrame.Parent = ScoreTimerFrame

TopResetBtn = Instance.new("ImageButton")
TopResetBtn.Name = "ControllerFlagBtn"
TopResetBtn.Position = UDim2.new(0, 4, 0, 2)
TopResetBtn.Size = UDim2.new(0, 28, 0, 28)
TopResetBtn.BackgroundTransparency = 1
TopResetBtn.ScaleType = Enum.ScaleType.Fit
TopResetBtn.Parent = S.WASDControllerFrame
applySpriteToImage(TopResetBtn, "Flag_Red")
S.ControllerFlagBtn = TopResetBtn

local function createCroppedKeyBtn(keyChar, posX, posY)
	local kBtn = Instance.new("ImageButton")
	kBtn.Name = "KeyBtn_" .. keyChar
	kBtn.Position = UDim2.new(0, posX, 0, posY)
	kBtn.Size = UDim2.new(0, 34, 0, 30)
	kBtn.BackgroundTransparency = 1
	kBtn.AutoButtonColor = false
	kBtn.ScaleType = Enum.ScaleType.Fit
	kBtn.Parent = S.WASDControllerFrame

	local fb = Instance.new("TextLabel")
	fb:SetAttribute("No2006Font", true)
	fb.Size = UDim2.new(1, 0, 1, 0)
	fb.BackgroundColor3 = Color3.fromRGB(45, 45, 48)
	fb.BorderSizePixel = 1
	fb.BorderColor3 = Color3.fromRGB(20, 20, 22)
	fb.Font = Enum.Font.ArialBold
	fb.Text = keyChar
	fb.TextSize = 14
	fb.TextColor3 = Color3.fromRGB(255, 255, 255)
	fb.Parent = kBtn

	applySpriteToImage(kBtn, "Key_" .. keyChar, fb)

	local function setTouchKey(down)
		S.hudKeysDown[keyChar] = down
		if S.refreshWASDKeySprites then S.refreshWASDKeySprites() end
	end
	storeConnection(kBtn.MouseButton1Down:Connect(function() setTouchKey(true) end))
	storeConnection(kBtn.MouseButton1Up:Connect(function() setTouchKey(false) end))
	storeConnection(kBtn.MouseLeave:Connect(function() setTouchKey(false) end))
	return kBtn, fb
end

S.KeyBtn_W, S.KeyFb_W = createCroppedKeyBtn("W", 38, 0)
S.KeyBtn_A, S.KeyFb_A = createCroppedKeyBtn("A", 2,  32)
S.KeyBtn_S, S.KeyFb_S = createCroppedKeyBtn("S", 38, 32)
S.KeyBtn_D, S.KeyFb_D = createCroppedKeyBtn("D", 74, 32)

S.lastKeyVisState = { W = nil, A = nil, S = nil, D = nil }
S.refreshWASDKeySprites = function(wActive, aActive, sActive, dActive)
	local wDn = (wActive ~= nil and wActive) or S.hudKeysDown.W or S.keysDown[Enum.KeyCode.W] or S.keysDown[Enum.KeyCode.Up] or false
	local aDn = (aActive ~= nil and aActive) or S.hudKeysDown.A or S.keysDown[Enum.KeyCode.A] or S.keysDown[Enum.KeyCode.Left] or false
	local sDn = (sActive ~= nil and sActive) or S.hudKeysDown.S or S.keysDown[Enum.KeyCode.S] or S.keysDown[Enum.KeyCode.Down] or false
	local dDn = (dActive ~= nil and dActive) or S.hudKeysDown.D or S.keysDown[Enum.KeyCode.D] or S.keysDown[Enum.KeyCode.Right] or false

	if S.lastKeyVisState.W ~= wDn then
		S.lastKeyVisState.W = wDn
		applySpriteToImage(S.KeyBtn_W, wDn and "Key_W_dn" or "Key_W", S.KeyFb_W)
	end
	if S.lastKeyVisState.A ~= aDn then
		S.lastKeyVisState.A = aDn
		applySpriteToImage(S.KeyBtn_A, aDn and "Key_A_dn" or "Key_A", S.KeyFb_A)
	end
	if S.lastKeyVisState.S ~= sDn then
		S.lastKeyVisState.S = sDn
		applySpriteToImage(S.KeyBtn_S, sDn and "Key_S_dn" or "Key_S", S.KeyFb_S)
	end
	if S.lastKeyVisState.D ~= dDn then
		S.lastKeyVisState.D = dDn
		applySpriteToImage(S.KeyBtn_D, dDn and "Key_D_dn" or "Key_D", S.KeyFb_D)
	end
end

-- 2005 Level message box ("You Won!" / "You Lost. Try Again"): a translucent 0xB2B2B2 box in the middle of
-- the 3D view, (screen width / 2 + 100) wide, a third as tall, with plain white text 1/8 of its height.
CenterBanner = Instance.new("Frame")
CenterBanner.Name = "CenterBanner"
CenterBanner.AnchorPoint = Vector2.new(0.5, 0.5)
CenterBanner.Position = UDim2.new(0.5, 0, 0.5, -30)
CenterBanner.Size = UDim2.new(0, 612, 0, 204)
CenterBanner.BackgroundColor3 = Color3.fromRGB(178, 178, 178)
CenterBanner.BackgroundTransparency = 0.667
CenterBanner.BorderSizePixel = 1
CenterBanner.BorderColor3 = Color3.fromRGB(178, 178, 178)
CenterBanner.Visible = false
CenterBanner.ZIndex = 20
CenterBanner.Parent = ScreenGui
S.CenterBanner = CenterBanner

CenterBannerText = Instance.new("TextLabel")
CenterBannerText.Name = "BannerText"
CenterBannerText.Size = UDim2.new(1, 0, 1, 0)
CenterBannerText.BackgroundTransparency = 1
CenterBannerText.Text = S.level.LoseMessage
CenterBannerText.TextColor3 = Color3.fromRGB(255, 255, 255)
CenterBannerText.TextStrokeTransparency = 1
CenterBannerText.TextSize = 21
CenterBannerText.ZIndex = 21
CenterBannerText.Parent = CenterBanner
apply2006Font(CenterBannerText)

function showCenterBanner(msg, duration)
	Camera = Workspace.CurrentCamera
	local viewport = (Camera and Camera.ViewportSize or Vector2.new(1024, 768)) / math.max(uiScale.Scale, 0.01)
	local boxW = math.floor(viewport.X * 0.5 + 100)
	local boxH = math.floor(boxW / 3)
	CenterBannerText.Text = msg
	CenterBannerText.TextSize = math.max(8, math.floor(boxH / 8) - 4)
	CenterBanner.Size = UDim2.new(0, boxW, 0, boxH)
	CenterBanner.Visible = true
	if duration then
		task.delay(duration, function()
			if CenterBanner and CenterBannerText.Text == msg then
				CenterBanner.Visible = false
			end
		end)
	end
end

function getTotalScore()
	return S.leaderstatsScore + S.bonusScore
end

function updateScoreTimerUI()
	local tStr = string.format("%.1f", math.max(0, S.currentTimerValue))
	local sStr = string.format("%d", getTotalScore())
	render2005ScoreBitmapLine(S.TimerLabel, "Timer:", tStr)
	render2005ScoreBitmapLine(S.ScoreLabel, "Score:", sStr)
end
updateScoreTimerUI()

do
	local function recalculateLeaderstatsScore()
		local total = 0
		local ls = LocalPlayer:FindFirstChild("leaderstats")
		if ls then
			for _, stat in ipairs(ls:GetChildren()) do
				if stat:IsA("IntValue") or stat:IsA("NumberValue") then
					total = total + stat.Value
				elseif stat:IsA("StringValue") and tonumber(stat.Value) then
					total = total + tonumber(stat.Value)
				end
			end
		end
		S.leaderstatsScore = total
		updateScoreTimerUI()
	end

	local function watchFolder(folder)
		if folder.Name ~= "leaderstats" then return end
		recalculateLeaderstatsScore()
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("ValueBase") then
				storeConnection(child.Changed:Connect(recalculateLeaderstatsScore))
			end
		end
		storeConnection(folder.ChildAdded:Connect(function(child)
			if child:IsA("ValueBase") then
				storeConnection(child.Changed:Connect(recalculateLeaderstatsScore))
			end
			recalculateLeaderstatsScore()
		end))
	end
	local existing = LocalPlayer:FindFirstChild("leaderstats")
	if existing then watchFolder(existing) end
	storeConnection(LocalPlayer.ChildAdded:Connect(watchFolder))
end

--========================================================
-- 3. LEFT 2005 STUDIO TOOLBAR (OCTOBER 2005 LAYOUT, MEASURED FROM THE 2005 SCREENSHOTS)
--========================================================
-- An 80px translucent panel from y = 25 to y = 355 holding, top to bottom: GO, Drag (arrow),
-- Resize + Axis Drag, Rotate + Tilt, a divider, Group / UnGroup / Duplicate, Delete and MENU.
local PANEL_GREY = Color3.fromRGB(153, 153, 153)
local PANEL_TRANSPARENCY = 0.6

local LeftToolbar = Instance.new("Frame")
LeftToolbar.Name = "LeftToolbar"
LeftToolbar.Position = UDim2.new(0, 0, 0, 25)
LeftToolbar.Size = UDim2.new(0, 80, 0, 330)
LeftToolbar.BackgroundColor3 = PANEL_GREY
LeftToolbar.BackgroundTransparency = PANEL_TRANSPARENCY
LeftToolbar.BorderSizePixel = 0
LeftToolbar.Active = true
LeftToolbar.Parent = ScreenGui
S.LeftToolbar = LeftToolbar

-- 3A. GO / STOP toggle (65x65)
GoStopBtn = Instance.new("ImageButton")
GoStopBtn.Name = "GoStopBtn"
GoStopBtn.Position = UDim2.new(0, 7, 0, 0)
GoStopBtn.Size = UDim2.new(0, 65, 0, 65)
GoStopBtn.BackgroundTransparency = 1
GoStopBtn.Parent = LeftToolbar
local GoFallbackOrb = createMetallicOrbFallback(GoStopBtn, "GO", Color3.fromRGB(10, 85, 25), true, false, false)

local goHovered = false
local goPressed = false
function updateGoStopVisual()
	local fbLbl = GoFallbackOrb and GoFallbackOrb:FindFirstChildOfClass("TextLabel")
	if S.isSimulationRunning then
		if fbLbl then
			fbLbl.Text = "STOP"
			fbLbl.TextColor3 = Color3.fromRGB(255, 235, 235)
		end
		local key = goPressed and "Stop_dn" or (goHovered and "Stop_ovr" or "Stop")
		applySpriteToImage(GoStopBtn, key, GoFallbackOrb)
	else
		if fbLbl then
			fbLbl.Text = "GO"
			fbLbl.TextColor3 = Color3.fromRGB(10, 85, 25)
		end
		local key = goPressed and "Run_dn" or (goHovered and "Run_ovr" or "Run")
		applySpriteToImage(GoStopBtn, key, GoFallbackOrb)
	end
end
updateGoStopVisual()

storeConnection(GoStopBtn.MouseEnter:Connect(function() goHovered = true updateGoStopVisual() end))
storeConnection(GoStopBtn.MouseLeave:Connect(function() goHovered = false goPressed = false updateGoStopVisual() end))
storeConnection(GoStopBtn.MouseButton1Down:Connect(function() goPressed = true updateGoStopVisual() end))
storeConnection(GoStopBtn.MouseButton1Up:Connect(function() goPressed = false updateGoStopVisual() end))

-- 3B. Drag tool (ArrowTool, 50x50)
local CursorBtn = Instance.new("ImageButton")
CursorBtn.Name = "CursorBtn"
CursorBtn.Position = UDim2.new(0, 15, 0, 65)
CursorBtn.Size = UDim2.new(0, 50, 0, 50)
CursorBtn.BackgroundTransparency = 1
CursorBtn.Parent = LeftToolbar
local CursorFallback = createMetallicOrbFallback(CursorBtn, "^", Color3.fromRGB(15, 55, 220), false, false, false)

-- 3C. Resize (ScaleTool) & Axis Drag (MoveTool), 40x40 side by side
local ResizeBtn = Instance.new("ImageButton")
ResizeBtn.Name = "ResizeBtn"
ResizeBtn.Position = UDim2.new(0, 0, 0, 115)
ResizeBtn.Size = UDim2.new(0, 40, 0, 40)
ResizeBtn.BackgroundTransparency = 1
ResizeBtn.Parent = LeftToolbar
local ResizeFallback = createMetallicOrbFallback(ResizeBtn, "<>", Color3.fromRGB(20, 60, 220), false, false, false)

local MoveBtn = Instance.new("ImageButton")
MoveBtn.Name = "MoveBtn"
MoveBtn.Position = UDim2.new(0, 40, 0, 115)
MoveBtn.Size = UDim2.new(0, 40, 0, 40)
MoveBtn.BackgroundTransparency = 1
MoveBtn.Parent = LeftToolbar
local MoveFallback = createMetallicOrbFallback(MoveBtn, "+", Color3.fromRGB(215, 140, 20), false, false, false)

-- 3D. Rotate & Tilt (30x32, the size of their art), starting just below Resize / Axis Drag so nothing overlaps
RotateLeftBtn = Instance.new("ImageButton")
RotateLeftBtn.Name = "SelectionRotateBtn"
RotateLeftBtn.Position = UDim2.new(0, 10, 0, 157)
RotateLeftBtn.Size = UDim2.new(0, 30, 0, 32)
RotateLeftBtn.BackgroundTransparency = 1
RotateLeftBtn.Parent = LeftToolbar
local RotLFallback = createMetallicOrbFallback(RotateLeftBtn, "<-", Color3.fromRGB(40, 40, 40), false, false, false)

RotateRightBtn = Instance.new("ImageButton")
RotateRightBtn.Name = "SelectionTiltBtn"
RotateRightBtn.Position = UDim2.new(0, 40, 0, 157)
RotateRightBtn.Size = UDim2.new(0, 30, 0, 32)
RotateRightBtn.BackgroundTransparency = 1
RotateRightBtn.Parent = LeftToolbar
local RotRFallback = createMetallicOrbFallback(RotateRightBtn, "->", Color3.fromRGB(40, 40, 40), false, false, false)

-- Divider
local Div1 = Instance.new("Frame")
Div1.Position = UDim2.new(0, 5, 0, 192)
Div1.Size = UDim2.new(0, 70, 0, 1)
Div1.BackgroundColor3 = Color3.fromRGB(205, 205, 205)
Div1.BorderSizePixel = 0
Div1.Parent = LeftToolbar

-- 3E. Group / UnGroup / Duplicate: cyan 12px text, greyed out while they cannot apply
local ACTION_TEXT_ON = Color3.fromRGB(0, 255, 255)
local ACTION_TEXT_OFF = Color3.fromRGB(204, 204, 204)
local function createLeftActionTextBtn(name, text, posY)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Position = UDim2.new(0, 0, 0, posY)
	btn.Size = UDim2.new(0, 80, 0, 20)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Parent = LeftToolbar

	local lbl = Instance.new("TextLabel")
	lbl.Name = "Caption"
	lbl.Position = UDim2.new(0, 10, 0, 0)
	lbl.Size = UDim2.new(1, -10, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = ACTION_TEXT_OFF
	lbl.TextStrokeColor3 = Color3.fromRGB(128, 128, 128)
	lbl.TextStrokeTransparency = 0.5
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = btn
	apply2006Font(lbl)
	return btn, lbl
end

S.GroupBtn, S.GroupLbl = createLeftActionTextBtn("GroupBtn", "Group", 195)
S.UnGroupBtn, S.UnGroupLbl = createLeftActionTextBtn("UnGroupBtn", "UnGroup", 216)
S.DuplicateBtn, S.DuplicateLbl = createLeftActionTextBtn("DuplicateBtn", "Duplicate", 237)

-- 3F. Delete (trash can, 40x46) & MENU
TrashBtn = Instance.new("ImageButton")
TrashBtn.Name = "TrashBtn"
TrashBtn.Position = UDim2.new(0, 20, 0, 259)
TrashBtn.Size = UDim2.new(0, 40, 0, 46)
TrashBtn.BackgroundTransparency = 1
TrashBtn.Parent = LeftToolbar
local TrashFallback = createMetallicOrbFallback(TrashBtn, "DEL", Color3.fromRGB(60, 60, 60), false, false, false)
S.TrashBtn = TrashBtn

MenuBtn = Instance.new("TextButton")
MenuBtn.Name = "MenuBtn"
MenuBtn.Position = UDim2.new(0, 0, 0, 305)
MenuBtn.Size = UDim2.new(1, 0, 0, 22)
MenuBtn.BackgroundTransparency = 1
MenuBtn.Text = ""
MenuBtn.Parent = LeftToolbar
S.MenuBtn = MenuBtn

local MenuLabel = Instance.new("TextLabel")
MenuLabel.Position = UDim2.new(0, 0, 0, 0)
MenuLabel.Size = UDim2.new(1, 0, 1, 0)
MenuLabel.BackgroundTransparency = 1
MenuLabel.Text = "MENU"
MenuLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
MenuLabel.TextStrokeColor3 = Color3.fromRGB(128, 128, 128)
MenuLabel.TextStrokeTransparency = 0.5
MenuLabel.TextSize = 14
MenuLabel.TextXAlignment = Enum.TextXAlignment.Center
MenuLabel.Parent = MenuBtn
apply2006Font(MenuLabel)

-- Bind all LeftToolbar interactive decal states
local noSelectionFn = function() return S.selectedObject == nil end
S.refreshCursorBtn   = bindButtonSprites(CursorBtn, CursorFallback, "ArrowTool", "ArrowTool_ovr", "ArrowTool_dn", "ArrowTool_ds", nil, function() return S.currentStudioTool == "Select" end)
S.refreshResizeBtn   = bindButtonSprites(ResizeBtn, ResizeFallback, "ScaleTool", "ScaleTool_ovr", "ScaleTool_dn", "ScaleTool_ds", nil, function() return S.currentStudioTool == "Resize" end)
S.refreshMoveBtn     = bindButtonSprites(MoveBtn, MoveFallback, "MoveTool", "MoveTool_ovr", "MoveTool_dn", "MoveTool_ds", nil, function() return S.currentStudioTool == "Move" end)
S.refreshRotLBtn     = bindButtonSprites(RotateLeftBtn, RotLFallback, "SelectionRotate", "SelectionRotate_ovr", "SelectionRotate_ovr", "SelectionRotate_ds", noSelectionFn)
S.refreshRotRBtn     = bindButtonSprites(RotateRightBtn, RotRFallback, "SelectionTilt", "SelectionTilt_ovr", "SelectionTilt_ovr", "SelectionTilt_ds", noSelectionFn)
S.refreshTrashBtn    = bindButtonSprites(TrashBtn, TrashFallback, "PlayDelete", "PlayDelete_ovr", "PlayDelete_dn", "PlayDelete_ds", noSelectionFn)

local function refreshLeftActionText()
	local sel = S.selectedObject
	local canUnGroup = sel ~= nil and sel:IsA("Model") and not Players:GetPlayerFromCharacter(sel)
	S.GroupLbl.TextColor3 = (sel ~= nil and sel:IsA("BasePart")) and ACTION_TEXT_ON or ACTION_TEXT_OFF
	S.UnGroupLbl.TextColor3 = canUnGroup and ACTION_TEXT_ON or ACTION_TEXT_OFF
	S.DuplicateLbl.TextColor3 = (sel ~= nil) and ACTION_TEXT_ON or ACTION_TEXT_OFF
end

function refreshAllToolbarSprites()
	S.refreshCursorBtn()
	S.refreshResizeBtn()
	S.refreshMoveBtn()
	S.refreshRotLBtn()
	S.refreshRotRBtn()
	S.refreshTrashBtn()
	refreshLeftActionText()
	if S.updateHandlesAdornee then
		S.updateHandlesAdornee()
	end
end

function setStudioTool(toolName)
	S.currentStudioTool = toolName
	if toolName ~= "Surface" and S.currentSurfaceTool then
		S.currentSurfaceTool = nil
		if S.activeTab == "Surface" and S.rebuildBottomBarContent then
			S.rebuildBottomBarContent()
		end
	end
	refreshAllToolbarSprites()
	playClassicSound(SOUND_CLICK, 0.35, 1)
end

S.refreshAllToolbarSprites = refreshAllToolbarSprites
S.setStudioTool = setStudioTool
storeConnection(CursorBtn.MouseButton1Click:Connect(function() setStudioTool("Select") end))
storeConnection(ResizeBtn.MouseButton1Click:Connect(function() setStudioTool("Resize") end))
storeConnection(MoveBtn.MouseButton1Click:Connect(function() setStudioTool("Move") end))

--========================================================
-- 4. BOTTOM-LEFT TOOLBOX TABS (Model, Surface, Color, Controller, Hopper - 80x24 each, cyan text)
--========================================================
local TOOLBOX_STRIP_HEIGHT = 60 -- the 2005 toolbox was a 60px web page docked under the 3D view
S.TOOLBOX_STRIP_HEIGHT = TOOLBOX_STRIP_HEIGHT

local BottomLeftTabs = Instance.new("Frame")
BottomLeftTabs.Name = "BottomLeftTabs"
BottomLeftTabs.AnchorPoint = Vector2.new(0, 1)
BottomLeftTabs.Position = UDim2.new(0, 0, 1, -TOOLBOX_STRIP_HEIGHT)
BottomLeftTabs.Size = UDim2.new(0, 80, 0, 120)
BottomLeftTabs.BackgroundTransparency = 1
BottomLeftTabs.Active = true
BottomLeftTabs.Parent = ScreenGui
S.BottomLeftTabs = BottomLeftTabs

local TAB_NAMES = { "Model", "Surface", "Color", "Controller", "Hopper" }
S.tabButtons = {}

-- Selected or hovered tabs get a cyan outline; a pressed tab dims its box like the 2005 buttons
local function refreshTabLook(tabName)
	local d = S.tabButtons[tabName]
	if not d then return end
	d.Stroke.Enabled = (tabName == S.activeTab) or d.Hovered
	d.Button.BackgroundTransparency = d.Pressed and 0.8 or PANEL_TRANSPARENCY
end
S.refreshTabLook = refreshTabLook

for idx, tabName in ipairs(TAB_NAMES) do
	local btn = Instance.new("TextButton")
	btn.Name = tabName .. "Tab"
	btn.Position = UDim2.new(0, 0, 0, (idx - 1) * 24)
	btn.Size = UDim2.new(1, 0, 0, 24)
	btn.BackgroundColor3 = PANEL_GREY
	btn.BackgroundTransparency = PANEL_TRANSPARENCY
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Text = ""
	btn.Parent = BottomLeftTabs

	local stroke = Instance.new("UIStroke")
	stroke.Name = "TabBorder"
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(0, 255, 255)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Enabled = (tabName == S.activeTab)
	stroke.Parent = btn

	local lbl = Instance.new("TextLabel")
	lbl.Position = UDim2.new(0, 10, 0, 3)
	lbl.Size = UDim2.new(1, -10, 1, -3)
	lbl.BackgroundTransparency = 1
	lbl.Text = tabName
	lbl.TextColor3 = Color3.fromRGB(0, 255, 255)
	lbl.TextStrokeTransparency = 1
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextYAlignment = Enum.TextYAlignment.Top
	lbl.Parent = btn
	apply2006Font(lbl)

	local data = { Button = btn, Stroke = stroke, Hovered = false, Pressed = false }
	S.tabButtons[tabName] = data
	storeConnection(btn.MouseEnter:Connect(function() data.Hovered = true refreshTabLook(tabName) end))
	storeConnection(btn.MouseLeave:Connect(function() data.Hovered = false data.Pressed = false refreshTabLook(tabName) end))
	storeConnection(btn.MouseButton1Down:Connect(function() data.Pressed = true refreshTabLook(tabName) end))
	storeConnection(btn.MouseButton1Up:Connect(function() data.Pressed = false refreshTabLook(tabName) end))
end

--========================================================
-- 5. BOTTOM-RIGHT 2005 CAMERAMENU (120x117: ZOOM ARROWS, TILT CIRCLES, PAN ARROWS, CENTER)
--========================================================
local CameraMenuFrame = Instance.new("Frame")
CameraMenuFrame.Name = "CameraMenuFrame"
CameraMenuFrame.AnchorPoint = Vector2.new(1, 1)
CameraMenuFrame.Position = UDim2.new(1, 0, 1, -TOOLBOX_STRIP_HEIGHT)
CameraMenuFrame.Size = UDim2.new(0, 120, 0, 117)
CameraMenuFrame.BackgroundColor3 = PANEL_GREY
CameraMenuFrame.BackgroundTransparency = PANEL_TRANSPARENCY
CameraMenuFrame.BorderSizePixel = 0
CameraMenuFrame.ClipsDescendants = false
CameraMenuFrame.Active = true
CameraMenuFrame.Parent = ScreenGui
S.CameraMenuFrame = CameraMenuFrame

local CamTitle = Instance.new("TextLabel")
CamTitle.Name = "CamTitle"
CamTitle.Position = UDim2.new(0, 0, 0, -3)
CamTitle.Size = UDim2.new(1, -1, 0, 18)
CamTitle.BackgroundTransparency = 1
CamTitle.Text = "CameraMenu"
CamTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
CamTitle.TextStrokeColor3 = Color3.fromRGB(128, 128, 128)
CamTitle.TextStrokeTransparency = 0.5
CamTitle.TextSize = 14
CamTitle.TextXAlignment = Enum.TextXAlignment.Right
CamTitle.TextYAlignment = Enum.TextYAlignment.Top
CamTitle.Parent = CameraMenuFrame
apply2006Font(CamTitle)

local function createCamBtn(name, spriteName, fallbackText, posX, posY, w, h)
	local btn = Instance.new("ImageButton")
	btn.Name = name
	btn.Position = UDim2.new(0, posX, 0, posY)
	btn.Size = UDim2.new(0, w, 0, h)
	btn.BackgroundTransparency = 1
	btn.ScaleType = Enum.ScaleType.Fit
	btn.Parent = CameraMenuFrame
	local fb = createMetallicOrbFallback(btn, fallbackText, Color3.fromRGB(30, 30, 30), false, false, false)
	bindButtonSprites(btn, fb, spriteName, spriteName .. "_ovr", spriteName .. "_dn", spriteName)
	return btn
end

-- Big white arrows zoom, small circled arrows tilt (original CameraZoomIn/CameraTiltUp textures)
S.CamZoomInBtn   = createCamBtn("CamZoomIn",   "CameraZoomIn",   "+",   43, 27, 34, 25)
S.CamZoomOutBtn  = createCamBtn("CamZoomOut",  "CameraZoomOut",  "-",   43, 86, 34, 26)
S.CamLeftBtn     = createCamBtn("CamPanLeft",  "CameraPanLeft",  "<",   10, 67, 34, 34)
S.CamRightBtn    = createCamBtn("CamPanRight", "CameraPanRight", ">",   75, 67, 34, 34)
S.CamCenterBtn   = createCamBtn("CamCenter",   "CameraCenter",   "[ ]", 43, 57, 34, 20)
S.CamTiltUpBtn   = createCamBtn("CamTiltUp",   "CameraTiltUp",   "^",   15, 42, 24, 24)
S.CamTiltDownBtn = createCamBtn("CamTiltDown", "CameraTiltDown", "v",   80, 42, 24, 24)

--========================================================
-- 6. BOTTOM 2005 TOOLBOX STRIP (60px, Windows XP ButtonFace with a 2px outset border)
--========================================================
local BottomBar = Instance.new("Frame")
BottomBar.Name = "Classic2005BottomBar"
BottomBar.AnchorPoint = Vector2.new(0, 1)
BottomBar.Position = UDim2.new(0, 0, 1, 0)
BottomBar.Size = UDim2.new(1, 0, 0, TOOLBOX_STRIP_HEIGHT)
BottomBar.BackgroundColor3 = Color3.fromRGB(236, 233, 216)
BottomBar.BorderSizePixel = 0
BottomBar.Active = true
BottomBar.Parent = ScreenGui
S.BottomBar = BottomBar

local function addOutsetEdge(name, pos, size, color)
	local edge = Instance.new("Frame")
	edge.Name = name
	edge.Position = pos
	edge.Size = size
	edge.BackgroundColor3 = color
	edge.BorderSizePixel = 0
	edge.Parent = BottomBar
end
addOutsetEdge("EdgeTop", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 2), Color3.fromRGB(255, 255, 255))
addOutsetEdge("EdgeLeft", UDim2.new(0, 0, 0, 0), UDim2.new(0, 2, 1, 0), Color3.fromRGB(255, 255, 255))
addOutsetEdge("EdgeBottom", UDim2.new(0, 0, 1, -2), UDim2.new(1, 0, 0, 2), Color3.fromRGB(172, 168, 153))
addOutsetEdge("EdgeRight", UDim2.new(1, -2, 0, 0), UDim2.new(0, 2, 1, 0), Color3.fromRGB(172, 168, 153))

BottomLeftArrow = Instance.new("ImageButton")
BottomLeftArrow.Name = "LeftArrow"
BottomLeftArrow.Position = UDim2.new(0, 12, 0.5, -16)
BottomLeftArrow.Size = UDim2.new(0, 32, 0, 32)
BottomLeftArrow.BackgroundTransparency = 1
BottomLeftArrow.Parent = BottomBar
local LeftArrFb = createMetallicOrbFallback(BottomLeftArrow, "<", Color3.fromRGB(20, 20, 20), false, false, true)
applySpriteToImage(BottomLeftArrow, "ArrowLeft", LeftArrFb)

CategoryBox = Instance.new("TextButton")
CategoryBox.Name = "CategoryBox"
CategoryBox.Position = UDim2.new(0, 52, 0, 8)
CategoryBox.Size = UDim2.new(0, 86, 0, 20)
CategoryBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CategoryBox.BorderSizePixel = 1
CategoryBox.BorderColor3 = Color3.fromRGB(90, 90, 90)
CategoryBox.Text = ""
CategoryBox.Parent = BottomBar

CategoryText = Instance.new("TextLabel")
CategoryText.Name = "CategoryText"
CategoryText:SetAttribute("No2006Font", true)
CategoryText.Position = UDim2.new(0, 5, 0, 0)
CategoryText.Size = UDim2.new(1, -22, 1, 0)
CategoryText.BackgroundTransparency = 1
CategoryText.Font = Enum.Font.Arial
CategoryText.Text = "Blocks"
CategoryText.TextSize = 12
CategoryText.TextColor3 = Color3.fromRGB(0, 0, 0)
CategoryText.TextXAlignment = Enum.TextXAlignment.Left
CategoryText.Parent = CategoryBox

local DropArrowBox = Instance.new("Frame")
DropArrowBox.AnchorPoint = Vector2.new(1, 0)
DropArrowBox.Position = UDim2.new(1, -1, 0, 1)
DropArrowBox.Size = UDim2.new(0, 16, 1, -2)
DropArrowBox.BackgroundColor3 = Color3.fromRGB(225, 225, 225)
DropArrowBox.BorderSizePixel = 1
DropArrowBox.BorderColor3 = Color3.fromRGB(130, 130, 130)
DropArrowBox.Parent = CategoryBox

local DropArrowLabel = Instance.new("TextLabel")
DropArrowLabel:SetAttribute("No2006Font", true)
DropArrowLabel.Size = UDim2.new(1, 0, 1, 0)
DropArrowLabel.BackgroundTransparency = 1
DropArrowLabel.Font = Enum.Font.ArialBold
DropArrowLabel.Text = "v"
DropArrowLabel.TextSize = 10
DropArrowLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
DropArrowLabel.Parent = DropArrowBox

AllModelsLink = Instance.new("TextButton")
AllModelsLink.Name = "AllModelsLink"
AllModelsLink:SetAttribute("No2006Font", true)
AllModelsLink.Position = UDim2.new(0, 52, 0, 32)
AllModelsLink.Size = UDim2.new(0, 86, 0, 18)
AllModelsLink.BackgroundTransparency = 1
AllModelsLink.Font = Enum.Font.Arial
AllModelsLink.Text = "All Models..."
AllModelsLink.TextSize = 11
AllModelsLink.TextColor3 = Color3.fromRGB(0, 0, 238)
AllModelsLink.Parent = BottomBar

local LinkUnderline = Instance.new("Frame")
LinkUnderline.Position = UDim2.new(0, 6, 1, -2)
LinkUnderline.Size = UDim2.new(1, -12, 0, 1)
LinkUnderline.BackgroundColor3 = Color3.fromRGB(0, 0, 238)
LinkUnderline.BorderSizePixel = 0
LinkUnderline.Parent = AllModelsLink

BottomRightArrow = Instance.new("ImageButton")
BottomRightArrow.Name = "RightArrow"
BottomRightArrow.Position = UDim2.new(0, 146, 0.5, -16)
BottomRightArrow.Size = UDim2.new(0, 32, 0, 32)
BottomRightArrow.BackgroundTransparency = 1
BottomRightArrow.Parent = BottomBar
local RightArrFb = createMetallicOrbFallback(BottomRightArrow, ">", Color3.fromRGB(20, 20, 20), false, false, true)
applySpriteToImage(BottomRightArrow, "ArrowRight", RightArrFb)

BottomItemsContainer = Instance.new("Frame")
BottomItemsContainer.Name = "ItemsContainer"
BottomItemsContainer.Position = UDim2.new(0, 188, 0, 5)
BottomItemsContainer.Size = UDim2.new(1, -198, 1, -10)
BottomItemsContainer.BackgroundTransparency = 1
BottomItemsContainer.ClipsDescendants = true
BottomItemsContainer.Parent = BottomBar

local BottomItemsLayout = Instance.new("UIListLayout")
BottomItemsLayout.FillDirection = Enum.FillDirection.Horizontal
BottomItemsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
BottomItemsLayout.Padding = UDim.new(0, 10)
BottomItemsLayout.SortOrder = Enum.SortOrder.LayoutOrder
BottomItemsLayout.Parent = BottomItemsContainer

-- Only the Model page had the category box, "All Models..." link and scroll arrows; the Surface, Color,
-- Controller and Hopper pages were a plain row of tools starting 5px in from the edge.
S.setModelToolboxChrome = function(isModelPage)
	BottomLeftArrow.Visible = isModelPage
	BottomRightArrow.Visible = isModelPage
	CategoryBox.Visible = isModelPage
	AllModelsLink.Visible = isModelPage
	BottomItemsLayout.Padding = UDim.new(0, isModelPage and 10 or 4)
	if isModelPage then
		BottomItemsContainer.Position = UDim2.new(0, 188, 0, 5)
		BottomItemsContainer.Size = UDim2.new(1, -198, 1, -10)
	else
		BottomItemsContainer.Position = UDim2.new(0, 7, 0, 5)
		BottomItemsContainer.Size = UDim2.new(1, -14, 1, -10)
	end
end
end)()

S._run = (function()
--========================================================
-- 7. 2005 STUDS ENGINE (2D FAUX-3D LOW-GRAPHICS TEXTURE MODE + SAFE RANGE-LIMITED 3D MODE)
--========================================================
local styledParts = {}
local allStuddedParts = {}
local trackedBaseplates = {}
local largePartGridCenter = {}

local SpawnedModelsFolder = Workspace:FindFirstChild("Studio2005SpawnedModels")
if not SpawnedModelsFolder then
	SpawnedModelsFolder = Instance.new("Folder")
	SpawnedModelsFolder.Name = "Studio2005SpawnedModels"
	SpawnedModelsFolder.Parent = Workspace
end

local baseStudFolder = Workspace:FindFirstChild("Baseplate3DStuds2005")
if baseStudFolder then
	baseStudFolder:Destroy()
end
baseStudFolder = Instance.new("Folder")
baseStudFolder.Name = "Baseplate3DStuds2005"
baseStudFolder.Parent = Workspace
storeConnection({ Disconnect = function() if baseStudFolder then baseStudFolder:Destroy() end end })

local function isPartInCharacterOrFigure(part)
	local m = part:FindFirstAncestorOfClass("Model")
	while m do
		if m:FindFirstChildOfClass("Humanoid")
			or m.Name == "Dynablox2005Rig"
			or m.Name == "DynabloxMan"
			or m:GetAttribute("IsDynabloxFigure")
			or m:GetAttribute("Is2005PlayerModel") then
			return true
		end
		m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model") or nil
	end
	return false
end

local function smoothPartSurfacesFor2005(part)
	if not part or not part:IsA("BasePart") then return end
	pcall(function()
		part.Material = Enum.Material.SmoothPlastic
		for _, prop in ipairs({ "TopSurface", "BottomSurface", "LeftSurface", "RightSurface", "FrontSurface", "BackSurface" }) do
			local cur = part[prop]
			if cur == Enum.SurfaceType.Studs or cur == Enum.SurfaceType.Inlet or cur == Enum.SurfaceType.Universal then
				part[prop] = Enum.SurfaceType.Smooth
			end
		end
	end)
end

local function hide2DStudTexturesOnPart(part)
	if not part or not part.Parent then return end
	smoothPartSurfacesFor2005(part)
	local tex = part:FindFirstChild("Classic2005StudTexture")
	if tex and tex:IsA("Texture") then
		tex.Transparency = 1
	end
	for _, ch in ipairs(part:GetChildren()) do
		if (ch:IsA("Texture") or ch:IsA("Decal")) and ch.Name ~= "Classic2005StudTexture" then
			local nm = string.lower(ch.Name)
			local tx = string.lower(tostring(ch.Texture))
			if string.find(nm, "stud", 1, true) or string.find(tx, "stud", 1, true) or trackedBaseplates[part] then
				if ch:GetAttribute("Orig2DStudTrans") == nil then
					ch:SetAttribute("Orig2DStudTrans", ch.Transparency)
				end
				ch.Transparency = 1
			end
		end
	end
end

local function applyFaux3D2DStudTexture(part)
	if not part or not part.Parent then return end
	if S.studMode == "3D" then
		hide2DStudTexturesOnPart(part)
		return
	end
	for _, ch in ipairs(part:GetChildren()) do
		if (ch:IsA("Texture") or ch:IsA("Decal")) and ch:GetAttribute("Orig2DStudTrans") ~= nil then
			ch.Transparency = ch:GetAttribute("Orig2DStudTrans")
		end
	end
	if part:GetAttribute("No2005Bumps") then
		local flatTex = part:FindFirstChild("Classic2005StudTexture")
		if flatTex then flatTex.Transparency = 1 end
		return
	end
	if part.Transparency >= 0.95 then return end
	smoothPartSurfacesFor2005(part)
	if not S.CustomStudUrl then
		pcall(function()
			part.Material = Enum.Material.Plastic
			part.TopSurface = Enum.SurfaceType.Studs
		end)
		return
	end
	local tex = part:FindFirstChild("Classic2005StudTexture")
	if not tex then
		tex = Instance.new("Texture")
		tex.Name = "Classic2005StudTexture"
		tex.Face = Enum.NormalId.Top
		tex.StudsPerTileU = 1
		tex.StudsPerTileV = 1
		tex.Parent = part
	end
	tex.Texture = S.CustomStudUrl
	tex.Transparency = part.Transparency
end

S.activeBumpParts = S.activeBumpParts or {}
S.lastBumpPartCF = S.lastBumpPartCF or {}
S.bumpLocalCF = S.bumpLocalCF or {}

-- Check if a 3D stud box at studCF on `ownerPart` would poke into/through another visible part
local function isStudBlockedByOtherPart(ownerPart, studCF)
	local ok, parts = pcall(function()
		return Workspace:GetPartBoundsInBox(studCF, Vector3.new(0.46, 0.16, 0.46))
	end)
	if ok and parts then
		for i = 1, #parts do
			local hitP = parts[i]
			if hitP ~= ownerPart
				and not hitP:GetAttribute("Is2005Bump")
				and not hitP:GetAttribute("Is2005HandleArrow")
				and hitP.Transparency < 0.92
				and (not LocalPlayer.Character or not hitP:IsDescendantOf(LocalPlayer.Character)) then
				return true, hitP
			end
		end
	end
	return false, nil
end

local function getBumpLocalCFrame(b)
	local lcf = S.bumpLocalCF and S.bumpLocalCF[b]
	if not lcf then
		local lv = b:GetAttribute("LocalOffset")
		if typeof(lv) == "Vector3" then
			lcf = CFrame.new(lv)
			if S.bumpLocalCF then
				S.bumpLocalCF[b] = lcf
			end
		end
	end
	return lcf
end

local function syncPart3DBumpsCFrame(part, checkOverlap)
	if not part or not part.Parent then return end
	local bf = part:FindFirstChild("Bumps2005")
	if not bf then return end
	local pCF = part.CFrame
	local pAnch = part.Anchored
	local pCol = part.Color
	local pTrans = part.Transparency
	S.lastBumpPartCF[part] = pCF
	S.activeBumpParts[part] = true
	for _, b in ipairs(bf:GetChildren()) do
		if b:IsA("BasePart") then
			local lcf = getBumpLocalCFrame(b)
			if lcf then
				local wcf = pCF * lcf
				local weld = b:FindFirstChild("BumpWeld")
				if pAnch then
					if weld and weld.Enabled then
						weld.Enabled = false
					end
					if not b.Anchored then
						b.Anchored = true
					end
					b.CFrame = wcf
				elseif weld and weld.Enabled and not b.Anchored then
					-- Already welded, so physics carries it. Setting its CFrame here would teleport the
					-- whole assembly once per bump, every frame, which froze GO mode in 3D stud mode.
					if weld.C0 ~= lcf then
						weld.C0 = lcf
					end
				else
					b.CFrame = wcf
					if b.Anchored then
						b.Anchored = false
					end
					if not weld then
						weld = Instance.new("Weld")
						weld.Name = "BumpWeld"
						weld.Part0 = part
						weld.Part1 = b
						weld.C0 = lcf
						weld.Parent = b
					else
						weld.C0 = lcf
						weld.Enabled = true
					end
				end
				if checkOverlap then
					local blocked = isStudBlockedByOtherPart(part, wcf)
					b:SetAttribute("BlockedByPart", blocked and true or false)
					b.Transparency = blocked and 1 or pTrans
				else
					local wasBlocked = b:GetAttribute("BlockedByPart") == true
					b.Transparency = wasBlocked and 1 or pTrans
				end
			end
			b.Color = pCol
		end
	end
end
S.syncPart3DBumpsCFrame = syncPart3DBumpsCFrame

local function syncObject3DBumps(obj)
	if not obj then return end
	S.forceBaseplatePoolRefresh = true
	if obj:IsA("BasePart") then
		syncPart3DBumpsCFrame(obj, true)
	elseif obj:IsA("Model") then
		for _, d in ipairs(obj:GetDescendants()) do
			if d:IsA("BasePart") and not d:GetAttribute("Is2005Bump") then
				syncPart3DBumpsCFrame(d, true)
			end
		end
	end
end
S.syncObject3DBumps = syncObject3DBumps

local function createSingle3DBump(part, bumpFolder, ox, topY, oz)
	local localVec = Vector3.new(ox, topY, oz)
	local lcf = CFrame.new(ox, topY, oz)
	local wcf = part.CFrame * lcf
	local blocked = isStudBlockedByOtherPart(part, wcf)

	local bump = Instance.new("Part")
	bump.Name = "Bump2005"
	bump:SetAttribute("Is2005Bump", true)
	bump:SetAttribute("LocalOffset", localVec)
	bump:SetAttribute("BlockedByPart", blocked and true or false)
	bump.Shape = Enum.PartType.Block
	bump.Material = Enum.Material.SmoothPlastic
	bump.TopSurface = Enum.SurfaceType.Smooth
	bump.BottomSurface = Enum.SurfaceType.Smooth
	bump.LeftSurface = Enum.SurfaceType.Smooth
	bump.RightSurface = Enum.SurfaceType.Smooth
	bump.FrontSurface = Enum.SurfaceType.Smooth
	bump.BackSurface = Enum.SurfaceType.Smooth
	bump.Color = part.Color
	bump.Transparency = blocked and 1 or part.Transparency
	bump.Size = Vector3.new(0.56, 0.14, 0.56)
	bump.CastShadow = false
	bump.CanCollide = false
	bump.CanTouch = false
	bump.CanQuery = false
	bump.Massless = true
	if S.bumpLocalCF then
		S.bumpLocalCF[bump] = lcf
	end
	bump.CFrame = wcf
	if part.Anchored then
		bump.Anchored = true
	else
		bump.Anchored = false
		local weld = Instance.new("Weld")
		weld.Name = "BumpWeld"
		weld.Part0 = part
		weld.Part1 = bump
		weld.C0 = lcf
		weld.Parent = bump
	end
	bump.Parent = bumpFolder
end

local function destroyPartBumps(part)
	if not part then return end
	local oldFolder = part:FindFirstChild("Bumps2005")
	if oldFolder then
		if S.bumpLocalCF then
			for _, ch in ipairs(oldFolder:GetChildren()) do
				S.bumpLocalCF[ch] = nil
			end
		end
		oldFolder:Destroy()
	end
	S.activeBumpParts[part] = nil
	S.lastBumpPartCF[part] = nil
	largePartGridCenter[part] = nil
end

local function rebuild3DBumpsForPart(part)
	if not part or not part.Parent or not part:IsA("Part") or part.Shape ~= Enum.PartType.Block then
		return
	end
	destroyPartBumps(part)
	if part.Transparency >= 0.95 or part:FindFirstAncestorOfClass("Tool") then
		return
	end
	-- Top face switched to Flat with the Surface toolbox
	if part:GetAttribute("No2005Bumps") then
		pcall(applyFaux3D2DStudTexture, part)
		return
	end

	-- In 3D mode, strictly hide all 2D stud textures; in 2D mode, show the 2D stud texture!
	if S.studMode == "3D" then
		pcall(hide2DStudTexturesOnPart, part)
	else
		pcall(applyFaux3D2DStudTexture, part)
	end

	local sx = math.floor(part.Size.X + 0.1)
	local sz = math.floor(part.Size.Z + 0.1)
	local count = sx * sz
	-- Allow thin floor pads (part.Size.Y >= 0.04) to get their own colored 3D studs on top!
	if sx < 1 or sz < 1 or part.Size.Y < 0.04 then
		return
	end
	-- Skip vertical walls whose local +Y isn't pointing mostly upward
	if part.CFrame.UpVector.Y < 0.65 and not part:IsDescendantOf(SpawnedModelsFolder) then
		return
	end

	-- Only truly massive map baseplates (>= 128x128) use the baseplate pool; all sidewalks, roads, plates, and bricks get their own attached Bumps2005!
	if part.Size.X >= 128 and part.Size.Z >= 128 then
		trackedBaseplates[part] = true
		return
	end

	-- Only build 3D Part bumps when STUD_MODE == "3D" and the part is within STUD_3D_RANGE!
	if S.studMode ~= "3D" then
		return
	end

	local refPos = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.Position
		or (LocalPlayer.Character and LocalPlayer.Character:GetPivot().Position)
		or Vector3.zero
	local rLimit = math.clamp(math.floor(S.stud3DRange or 35), 8, 1000)
	local relCam = part.CFrame:PointToObjectSpace(refPos)
	local halfX, halfZ = part.Size.X * 0.5, part.Size.Z * 0.5
	local dxOut = math.max(0, math.abs(relCam.X) - halfX)
	local dzOut = math.max(0, math.abs(relCam.Z) - halfZ)
	local dyOut = math.abs(relCam.Y)
	if math.sqrt(dxOut * dxOut + dzOut * dzOut + dyOut * dyOut) > rLimit + 4 then
		return
	end

	local bumpFolder = Instance.new("Folder")
	bumpFolder.Name = "Bumps2005"
	bumpFolder.Parent = part
	S.activeBumpParts[part] = true
	S.lastBumpPartCF[part] = part.CFrame
	local topY = part.Size.Y / 2 + 0.07

	local ixMin, ixMax = 1, sx
	local izMin, izMax = 1, sz
	if count > 400 then
		local windowR = math.min(rLimit, 36)
		local midX = (sx + 1) * 0.5
		local midZ = (sz + 1) * 0.5
		ixMin = math.max(1, math.floor(relCam.X - windowR + midX))
		ixMax = math.min(sx, math.ceil(relCam.X + windowR + midX))
		izMin = math.max(1, math.floor(relCam.Z - windowR + midZ))
		izMax = math.min(sz, math.ceil(relCam.Z + windowR + midZ))
		largePartGridCenter[part] = Vector2.new(math.floor(relCam.X * 0.25 + 0.5), math.floor(relCam.Z * 0.25 + 0.5))
	end

	for ix = ixMin, ixMax do
		local ox = (ix - (sx + 1) / 2)
		for iz = izMin, izMax do
			local oz = (iz - (sz + 1) / 2)
			createSingle3DBump(part, bumpFolder, ox, topY, oz)
		end
	end
end

local function apply2005StudsToPart(part)
	if not part or not part:IsA("BasePart") or styledParts[part] then
		return
	end
	if part.Name == "Bump2005" or part:GetAttribute("Is2005Bump") or part:GetAttribute("Is2005HandleArrow") then
		return
	end
	-- Explosions, rockets, balls and laser beams keep their own look (restyling them made the neon flicker)
	if part:GetAttribute("Is2005Effect") then
		return
	end
	if part.Parent and part.Parent.Name == "Bumps2005" then
		return
	end
	-- Skip invisible R6/R15 character limbs, but allow visible 2005 figure parts that explicitly requested studs
	if isPartInCharacterOrFigure(part) and part.Transparency >= 0.95 then
		return
	end
	styledParts[part] = true

	smoothPartSurfacesFor2005(part)

	if part:IsA("Part") and part.Shape == Enum.PartType.Block then
		allStuddedParts[part] = true
		rebuild3DBumpsForPart(part)
		storeConnection(part:GetPropertyChangedSignal("Color"):Connect(function()
			local bf = part:FindFirstChild("Bumps2005")
			if bf then
				for _, b in ipairs(bf:GetChildren()) do
					if b:IsA("BasePart") then b.Color = part.Color end
				end
			end
		end))
		storeConnection(part:GetPropertyChangedSignal("Size"):Connect(function()
			if S.studMode == "3D" then
				pcall(rebuild3DBumpsForPart, part)
			end
		end))
		storeConnection(part:GetPropertyChangedSignal("CFrame"):Connect(function()
			if S.studMode == "3D" then
				syncPart3DBumpsCFrame(part, false)
			end
		end))
		storeConnection(part:GetPropertyChangedSignal("Position"):Connect(function()
			if S.studMode == "3D" then
				syncPart3DBumpsCFrame(part, false)
			end
		end))
		storeConnection(part:GetPropertyChangedSignal("Anchored"):Connect(function()
			if S.studMode == "3D" then
				syncPart3DBumpsCFrame(part, false)
			end
		end))
		storeConnection(part:GetPropertyChangedSignal("Transparency"):Connect(function()
			local tex = part:FindFirstChild("Classic2005StudTexture")
			if tex then
				tex.Transparency = (S.studMode == "3D" or part.Transparency >= 0.95 or part:GetAttribute("No2005Bumps")) and 1 or part.Transparency
			end
			local bf = part:FindFirstChild("Bumps2005")
			if bf then
				for _, b in ipairs(bf:GetChildren()) do
					if b:IsA("BasePart") then
						local wasBlocked = b:GetAttribute("BlockedByPart") == true
						b.Transparency = wasBlocked and 1 or part.Transparency
					end
				end
			end
		end))
	end
end
S.rebuild3DBumpsForPart = rebuild3DBumpsForPart

-- Range-Limited 3D Stud Pool for Massive Baseplates (>= 128x128) & Nearby Bricks
do
	local pool = {}
	local poolLocalCF = {}
	local activeCount = 0
	local lastCellX, lastCellZ, lastBaseplate, lastBaseColor, lastRange, lastMode = nil, nil, nil, nil, nil, nil

	local function getBaseplateUnder(pos)
		local bestPart = nil
		local bestY = -math.huge
		for bp in pairs(trackedBaseplates) do
			if bp and bp.Parent and bp.Transparency < 0.95 and not bp:GetAttribute("No2005Bumps") then
				local halfX, halfZ = bp.Size.X * 0.5, bp.Size.Z * 0.5
				local rel = bp.CFrame:PointToObjectSpace(pos)
				if math.abs(rel.X) <= halfX + 40 and math.abs(rel.Z) <= halfZ + 40 then
					local topY = bp.Position.Y + bp.Size.Y * 0.5
					if topY > bestY and topY <= pos.Y + 45 then
						bestY = topY
						bestPart = bp
					end
				end
			else
				trackedBaseplates[bp] = nil
			end
		end
		return bestPart
	end

	local function hideBaseplatePool()
		activeCount = 0
		for i = 1, #pool do
			if pool[i] then
				pool[i].Transparency = 1
			end
		end
	end
	S.hideBaseplatePool = hideBaseplatePool

	S.syncBaseplatePoolWithMovedBaseplate = function()
		if S.studMode ~= "3D" or not lastBaseplate or not lastBaseplate.Parent or activeCount == 0 then
			return
		end
		local bpCF = lastBaseplate.CFrame
		if bpCF ~= S.lastBaseplateCF then
			S.lastBaseplateCF = bpCF
			local col = lastBaseplate.Color
			local trans = lastBaseplate.Transparency
			for i = 1, activeCount do
				local b = pool[i]
				local lcf = poolLocalCF[i]
				if b and lcf then
					b.CFrame = bpCF * lcf
					b.Color = col
					b.Transparency = trans
				end
			end
		end
	end

	task.spawn(function()
		while baseStudFolder and baseStudFolder.Parent do
			if S.studMode ~= "3D" then
				if lastMode == "3D" then
					hideBaseplatePool()
					lastMode = S.studMode
				end
				task.wait(0.25)
			else
				lastMode = "3D"
				local refPos = nil
				if Workspace.CurrentCamera then
					refPos = Workspace.CurrentCamera.CFrame.Position
				elseif LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
					refPos = LocalPlayer.Character.HumanoidRootPart.Position
				end

				local rLimit = math.clamp(math.floor(S.stud3DRange or 35), 8, 1000)
				if refPos then
					-- Update nearby bricks & plates within rLimit
					for p in pairs(allStuddedParts) do
						if p and p.Parent then
							if not trackedBaseplates[p] then
								local rel = p.CFrame:PointToObjectSpace(refPos)
								local hx, hz = p.Size.X * 0.5, p.Size.Z * 0.5
								local dx = math.max(0, math.abs(rel.X) - hx)
								local dz = math.max(0, math.abs(rel.Z) - hz)
								local dy = math.abs(rel.Y)
								local surfDist = math.sqrt(dx * dx + dz * dz + dy * dy)
								local hasBumps = p:FindFirstChild("Bumps2005") ~= nil
								if surfDist <= rLimit + 3 then
									if not hasBumps then
										pcall(rebuild3DBumpsForPart, p)
									elseif (math.floor(p.Size.X + 0.1) * math.floor(p.Size.Z + 0.1)) > 400 then
										local curCell = Vector2.new(math.floor(rel.X * 0.25 + 0.5), math.floor(rel.Z * 0.25 + 0.5))
										if largePartGridCenter[p] ~= curCell then
											pcall(rebuild3DBumpsForPart, p)
										end
									end
								elseif surfDist > rLimit + 8 and hasBumps then
									destroyPartBumps(p)
								end
							end
						else
							allStuddedParts[p] = nil
							styledParts[p] = nil
							destroyPartBumps(p)
						end
					end

					-- Update range-limited 3D baseplate studs locked to bp's OWN local stud coordinates!
					local bp = getBaseplateUnder(refPos)
					if bp then
						hide2DStudTexturesOnPart(bp)
						local bpCF = bp.CFrame
						local relCam = bpCF:PointToObjectSpace(refPos)
						local cellX = math.floor(relCam.X * 0.5 + 0.5) * 2
						local cellZ = math.floor(relCam.Z * 0.5 + 0.5) * 2
						if S.forceBaseplatePoolRefresh or cellX ~= lastCellX or cellZ ~= lastCellZ or bp ~= lastBaseplate or bpCF ~= S.lastBaseplateCF or bp.Color ~= lastBaseColor or rLimit ~= lastRange then
							S.forceBaseplatePoolRefresh = false
							S.lastBaseplateCF = bpCF
							lastCellX, lastCellZ, lastBaseplate, lastBaseColor, lastRange = cellX, cellZ, bp, bp.Color, rLimit
							local sx = math.floor(bp.Size.X + 0.1)
							local sz = math.floor(bp.Size.Z + 0.1)
							local midX = (sx + 1) * 0.5
							local midZ = (sz + 1) * 0.5
							local topY = bp.Size.Y * 0.5 + 0.07
							local idx = 0
							local col = bp.Color
							local trans = bp.Transparency
							local bpLimit = math.min(rLimit, 75)
							local r2Max = bpLimit * bpLimit
							local ixMin = math.max(1, math.floor(relCam.X - bpLimit + midX))
							local ixMax = math.min(sx, math.ceil(relCam.X + bpLimit + midX))
							local izMin = math.max(1, math.floor(relCam.Z - bpLimit + midZ))
							local izMax = math.min(sz, math.ceil(relCam.Z + bpLimit + midZ))

							for ix = ixMin, ixMax do
								local lx = ix - midX
								local dx = lx - relCam.X
								local dx2 = dx * dx
								for iz = izMin, izMax do
									local lz = iz - midZ
									local dz = lz - relCam.Z
									if dx2 + dz * dz <= r2Max then
										local lcf = CFrame.new(lx, topY, lz)
										local wcf = bpCF * lcf
										local blocked = isStudBlockedByOtherPart(bp, wcf)
										if not blocked then
											idx = idx + 1
											poolLocalCF[idx] = lcf
											local b = pool[idx]
											if not b then
												b = Instance.new("Part")
												b.Name = "Bump2005"
												b:SetAttribute("Is2005Bump", true)
												b.Shape = Enum.PartType.Block
												b.Material = Enum.Material.SmoothPlastic
												b.TopSurface = Enum.SurfaceType.Smooth
												b.BottomSurface = Enum.SurfaceType.Smooth
												b.LeftSurface = Enum.SurfaceType.Smooth
												b.RightSurface = Enum.SurfaceType.Smooth
												b.FrontSurface = Enum.SurfaceType.Smooth
												b.BackSurface = Enum.SurfaceType.Smooth
												b.Size = Vector3.new(0.56, 0.14, 0.56)
												b.CastShadow = false
												b.Anchored = true
												b.CanCollide = false
												b.CanTouch = false
												b.CanQuery = false
												b.Massless = true
												b.Parent = baseStudFolder
												pool[idx] = b
											end
											b.Color = col
											b.Transparency = trans
											b.CFrame = wcf
										end
									end
								end
							end
							activeCount = idx
							for i = idx + 1, #pool do
								pool[i].Transparency = 1
							end
						end
					else
						hideBaseplatePool()
					end
				end
				task.wait(0.18)
			end
		end
	end)
end

local function refreshAllStudsForMode()
	if S.studMode == "2D" then
		if S.hideBaseplatePool then S.hideBaseplatePool() end
		for p in pairs(allStuddedParts) do
			if p and p.Parent then
				destroyPartBumps(p)
				pcall(applyFaux3D2DStudTexture, p)
			end
		end
		for bp in pairs(trackedBaseplates) do
			if bp and bp.Parent then
				pcall(applyFaux3D2DStudTexture, bp)
			end
		end
	else
		for p in pairs(allStuddedParts) do
			if p and p.Parent then
				pcall(hide2DStudTexturesOnPart, p)
				pcall(rebuild3DBumpsForPart, p)
			end
		end
		for bp in pairs(trackedBaseplates) do
			if bp and bp.Parent then
				pcall(hide2DStudTexturesOnPart, bp)
			end
		end
		S.forceBaseplatePoolRefresh = true
	end
	if S.rebuildBottomBarContent then
		pcall(S.rebuildBottomBarContent)
	end
end

S.setStudMode = function(newMode)
	S.studMode = (newMode == "3D") and "3D" or "2D"
	refreshAllStudsForMode()
end

S.toggleStudMode = function()
	S.setStudMode(S.studMode == "3D" and "2D" or "3D")
end

S.cycleStud3DRange = function(stepDir)
	local presets = Config.STUD_3D_RANGE_PRESETS or { 10, 15, 25, 35, 50, 75, 100, 150, 200, 300, 500, 1000 }
	local dir = stepDir or 1
	S.stud3DRangeIdx = ((S.stud3DRangeIdx or 4) - 1 + dir) % #presets + 1
	S.stud3DRange = presets[S.stud3DRangeIdx]
	if S.studMode ~= "3D" then
		S.studMode = "3D"
	end
	refreshAllStudsForMode()
end

if Config.APPLY_2005_STUDS_TO_ALL_PARTS then
	-- Clean up any leftover Bumps2005 folders from an earlier script execution before scanning Workspace
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Folder") and obj.Name == "Bumps2005" then
			pcall(function() obj:Destroy() end)
		end
	end
	task.spawn(function()
		for idx, obj in ipairs(Workspace:GetDescendants()) do
			if obj:IsA("BasePart") then
				pcall(apply2005StudsToPart, obj)
			end
			if idx % 200 == 0 then
				task.wait()
			end
		end
	end)
	storeConnection(Workspace.DescendantAdded:Connect(function(obj)
		if obj:IsA("BasePart") then
			task.defer(pcall, apply2005StudsToPart, obj)
		end
	end))
end

--========================================================
-- 8. ALL PLAYERS (LOCALPLAYER + EVERY OTHER PLAYER + NPCS) AS 2005 PHYSICS MODELS
--========================================================
-- 2005 colours were plain RGB: 864 Red Figure is (255, 0, 0) and 863 Blue figure is (0, 0, 255)
local DYNABLOX_MAIN_COLORS = {
	Color3.fromRGB(255, 0, 0),
	Color3.fromRGB(0, 0, 255),
}
local DYNABLOX_YELLOW = Color3.fromRGB(238, 222, 28)
local DYNABLOX_BELT_GRAY = Color3.fromRGB(163, 165, 168)

local function makeSmooth2005Part(name, size, color, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.LeftSurface = Enum.SurfaceType.Smooth
	p.RightSurface = Enum.SurfaceType.Smooth
	p.FrontSurface = Enum.SurfaceType.Smooth
	p.BackSurface = Enum.SurfaceType.Smooth
	p.CanCollide = true
	p.CanTouch = true
	p.CanQuery = true
	p.Massless = false
	p.Anchored = false
	p.Parent = parent
	return p
end

S.playerModelStyle = S.playerModelStyle or "Figure863_864" -- "Figure863_864" (863 Blue / 864 Red Figure) or "Man862" (862 Man figure)

local function ensureUprightGyro(rootPart, yawRad)
	if not rootPart or not rootPart:IsA("BasePart") then return nil end
	local gyro = rootPart:FindFirstChild("RBLX04ControllerGyro")
	if not gyro then
		gyro = Instance.new("BodyGyro")
		gyro.Name = "RBLX04ControllerGyro"
		gyro.MaxTorque = Vector3.new(400000, 400000, 400000)
		gyro.P = 18000
		gyro.D = 600
		local _, ry, _ = rootPart.CFrame:ToEulerAnglesYXZ()
		local initYaw = yawRad or ry or 0
		rootPart:SetAttribute("RBLX04Yaw", initYaw)
		gyro.CFrame = CFrame.Angles(0, initYaw, 0)
		gyro.Parent = rootPart
	elseif yawRad then
		rootPart:SetAttribute("RBLX04Yaw", yawRad)
		gyro.CFrame = CFrame.Angles(0, yawRad, 0)
	end
	return gyro
end

-- Helper: Rigidly connect Left Arm and Right Arm to the support torso with a WeldConstraint (zero arm swinging!)
local S_baseShoulderC0 = {}

local function attachSwingingArmHinge(supportTorso, armPart, torsoLocalPos, armLocalPos, allBodyParts)
	for _, ch in ipairs(armPart:GetChildren()) do
		if ch:IsA("WeldConstraint") or ch:IsA("Weld") or ch:IsA("Motor6D") or ch:IsA("HingeConstraint") then
			if ch.Name ~= "BumpWeld" then
				ch:Destroy()
			end
		end
	end

	local w = Instance.new("WeldConstraint")
	w.Name = "RigWeld_" .. armPart.Name
	w.Part0 = supportTorso
	w.Part1 = armPart
	w.Parent = armPart

	armPart:SetAttribute("IsSwingingArm2004", nil)
	armPart.Massless = false
	return w
end

-- Exact 7-part 863 Blue figure.rbxm & 864 Red Figure.rbxm + 10-part 862 Man figure.rbxm builder
-- Torso, Head, LowerBody, and Legs are rigidly welded; Left Arm & Right Arm are connected by free HingeConstraints!
local function buildProceduralDynabloxMan(forcedColor, forcedStyle)
	local style = forcedStyle or S.playerModelStyle or "Figure863_864"
	local mainColor = forcedColor or DYNABLOX_MAIN_COLORS[math.random(1, #DYNABLOX_MAIN_COLORS)]

	local model = Instance.new("Model")
	model:SetAttribute("IsDynabloxFigure", true)
	model:SetAttribute("Is2005Model", true)
	model:SetAttribute("FigureStyle2004", style)
	model:SetAttribute("PostureXML", "Stand")

	if style == "Man862" then
		model.Name = "862 Man figure"
		local colGrey = Color3.fromRGB(204, 204, 204)
		local colPants = forcedColor or Color3.fromRGB(102, 204, 230)
		local colShoe = Color3.fromRGB(76, 76, 76)
		local colHead = Color3.fromRGB(204, 204, 76)

		local upperTorso = makeSmooth2005Part("Torso", Vector3.new(3, 3, 2), colGrey, model)
		upperTorso.CFrame = CFrame.new(0, 0, 0)
		upperTorso.TopSurface = Enum.SurfaceType.Studs
		upperTorso.BottomSurface = Enum.SurfaceType.Studs
		apply2005StudsToPart(upperTorso)

		local topShoulders = makeSmooth2005Part("UpperBody", Vector3.new(3, 1, 2), colGrey, model)
		topShoulders.CFrame = CFrame.new(0, 2.0, 0)
		topShoulders.TopSurface = Enum.SurfaceType.Studs
		topShoulders.BottomSurface = Enum.SurfaceType.Studs
		topShoulders.LeftSurface = Enum.SurfaceType.Hinge
		topShoulders.RightSurface = Enum.SurfaceType.Hinge
		apply2005StudsToPart(topShoulders)

		local midTorso = makeSmooth2005Part("LowerBody", Vector3.new(3, 2, 2), colPants, model)
		midTorso.CFrame = CFrame.new(0, -2.5, 0)
		midTorso.TopSurface = Enum.SurfaceType.Studs
		midTorso.BottomSurface = Enum.SurfaceType.Studs
		apply2005StudsToPart(midTorso)

		local head = makeSmooth2005Part("Head", Vector3.new(2, 2, 2), colHead, model)
		head.Shape = Enum.PartType.Cylinder
		head.CFrame = CFrame.new(-0.5, 3.5, 0) * CFrame.Angles(0, 0, math.rad(90))

		local leftArm = makeSmooth2005Part("Left Arm", Vector3.new(1, 4, 1), colGrey, model)
		leftArm.CFrame = CFrame.new(-2.0, 0.5, 0.5)
		leftArm.TopSurface = Enum.SurfaceType.Studs
		leftArm.BottomSurface = Enum.SurfaceType.Studs
		apply2005StudsToPart(leftArm)

		local rightArm = makeSmooth2005Part("Right Arm", Vector3.new(1, 4, 1), colGrey, model)
		rightArm.CFrame = CFrame.new(2.0, 0.5, 0.5)
		rightArm.TopSurface = Enum.SurfaceType.Studs
		rightArm.BottomSurface = Enum.SurfaceType.Studs
		apply2005StudsToPart(rightArm)

		local leftLeg = makeSmooth2005Part("Left Leg", Vector3.new(1, 4, 1), colPants, model)
		leftLeg.CFrame = CFrame.new(-1.0, -5.5, 0.5)
		leftLeg.TopSurface = Enum.SurfaceType.Studs
		leftLeg.BottomSurface = Enum.SurfaceType.Studs
		apply2005StudsToPart(leftLeg)

		local rightLeg = makeSmooth2005Part("Right Leg", Vector3.new(1, 4, 1), colPants, model)
		rightLeg.CFrame = CFrame.new(1.0, -5.5, 0.5)
		rightLeg.TopSurface = Enum.SurfaceType.Studs
		rightLeg.BottomSurface = Enum.SurfaceType.Studs
		apply2005StudsToPart(rightLeg)

		local leftShoe = makeSmooth2005Part("LeftShoe", Vector3.new(1, 1, 2), colShoe, model)
		leftShoe.CFrame = CFrame.new(-1.0, -8.0, 0)
		leftShoe.TopSurface = Enum.SurfaceType.Studs
		leftShoe.BottomSurface = Enum.SurfaceType.Studs
		apply2005StudsToPart(leftShoe)

		local rightShoe = makeSmooth2005Part("RightShoe", Vector3.new(1, 1, 2), colShoe, model)
		rightShoe.CFrame = CFrame.new(1.0, -8.0, 0)
		rightShoe.TopSurface = Enum.SurfaceType.Studs
		rightShoe.BottomSurface = Enum.SurfaceType.Studs
		apply2005StudsToPart(rightShoe)

		local bodyParts = { upperTorso, topShoulders, midTorso, head, leftLeg, rightLeg, leftShoe, rightShoe, leftArm, rightArm }
		for _, part in ipairs(bodyParts) do
			if part ~= upperTorso and part ~= leftArm and part ~= rightArm then
				local w = Instance.new("WeldConstraint")
				w.Name = "RigWeld_" .. part.Name
				w.Part0 = upperTorso
				w.Part1 = part
				w.Parent = part
			end
		end
		attachSwingingArmHinge(topShoulders, leftArm, Vector3.new(-1.5, 0, 0.5), Vector3.new(0.5, 1.5, 0), bodyParts)
		attachSwingingArmHinge(topShoulders, rightArm, Vector3.new(1.5, 0, 0.5), Vector3.new(-0.5, 1.5, 0), bodyParts)

		model.PrimaryPart = upperTorso
		return model
	end

	-- Default: Exact 7-part 863 Blue figure.rbxm / 864 Red Figure.rbxm PhysicalCharacter!
	local isRed = (mainColor.R > mainColor.B)
	model.Name = isRed and "864 Red Figure" or "863 Blue figure"

	local upperTorso = makeSmooth2005Part("Torso", Vector3.new(2, 1, 1), mainColor, model)
	upperTorso.CFrame = CFrame.new(0, 0.5, 0)
	upperTorso.TopSurface = Enum.SurfaceType.Studs
	upperTorso.BottomSurface = Enum.SurfaceType.Studs
	upperTorso.LeftSurface = Enum.SurfaceType.Hinge
	upperTorso.RightSurface = Enum.SurfaceType.Hinge
	apply2005StudsToPart(upperTorso)

	local midTorso = makeSmooth2005Part("MidTorso", Vector3.new(2, 1, 1), Color3.fromRGB(178, 178, 178), model)
	midTorso.CFrame = CFrame.new(0, -0.5, 0)
	midTorso.TopSurface = Enum.SurfaceType.Studs
	midTorso.BottomSurface = Enum.SurfaceType.Studs
	apply2005StudsToPart(midTorso)

	local head = makeSmooth2005Part("Head", Vector3.new(2, 2, 2), Color3.fromRGB(255, 255, 0), model)
	head.Shape = Enum.PartType.Ball
	head.CFrame = CFrame.new(0, 2.0, -0.5)

	local leftArm = makeSmooth2005Part("Left Arm", Vector3.new(1, 2, 1), Color3.fromRGB(255, 255, 0), model)
	leftArm.CFrame = CFrame.new(-1.5, 0, 0)

	local rightArm = makeSmooth2005Part("Right Arm", Vector3.new(1, 2, 1), Color3.fromRGB(255, 255, 0), model)
	rightArm.CFrame = CFrame.new(1.5, 0, 0)

	local leftLeg = makeSmooth2005Part("Left Leg", Vector3.new(1, 2, 1), mainColor, model)
	leftLeg.CFrame = CFrame.new(-0.5, -2.0, 0)
	leftLeg.BottomSurface = Enum.SurfaceType.Studs
	apply2005StudsToPart(leftLeg)

	local rightLeg = makeSmooth2005Part("Right Leg", Vector3.new(1, 2, 1), mainColor, model)
	rightLeg.CFrame = CFrame.new(0.5, -2.0, 0)
	rightLeg.BottomSurface = Enum.SurfaceType.Studs
	apply2005StudsToPart(rightLeg)

	local bodyParts = { upperTorso, midTorso, head, leftLeg, rightLeg, leftArm, rightArm }
	for _, part in ipairs(bodyParts) do
		if part ~= upperTorso and part ~= leftArm and part ~= rightArm then
			local w = Instance.new("WeldConstraint")
			w.Name = "RigWeld_" .. part.Name
			w.Part0 = upperTorso
			w.Part1 = part
			w.Parent = part
		end
	end

	-- Connect Left Arm & Right Arm with real HingeConstraints (ActuatorType = None) at the exact shoulder joints!
	attachSwingingArmHinge(upperTorso, leftArm, Vector3.new(-1.0, 0, 0), Vector3.new(0.5, 0.5, 0), bodyParts)
	attachSwingingArmHinge(upperTorso, rightArm, Vector3.new(1.0, 0, 0), Vector3.new(-0.5, 0.5, 0), bodyParts)

	model.PrimaryPart = upperTorso
	return model
end

-- RBLX04 Format Menu Pose Setter: "Stand", "Sit", "Climb"
local function setFigurePose2004(targetObj, poseName)
	if not targetObj then return end
	local fig = (S.rigRegistry and S.rigRegistry[targetObj])
		or (targetObj:IsA("Model") and (targetObj:FindFirstChild("Dynablox2005Rig") or targetObj))
		or nil
	if not fig or not fig:IsA("Model") then return end
	local primary = fig:FindFirstChild("Torso") or fig.PrimaryPart
	local leftLeg = fig:FindFirstChild("Left Leg")
	local rightLeg = fig:FindFirstChild("Right Leg")
	local leftArm = fig:FindFirstChild("Left Arm")
	local rightArm = fig:FindFirstChild("Right Arm")
	if not primary then return end
	fig:SetAttribute("PostureXML", poseName)

	if leftLeg and rightLeg then
		local lw = leftLeg:FindFirstChild("RigWeld_Left Leg") or leftLeg:FindFirstChildOfClass("WeldConstraint")
		local rw = rightLeg:FindFirstChild("RigWeld_Right Leg") or rightLeg:FindFirstChildOfClass("WeldConstraint")
		if lw then lw.Enabled = false end
		if rw then rw.Enabled = false end
		if poseName == "Sit" then
			leftLeg.CFrame = primary.CFrame * CFrame.new(-0.5, -1.0, -0.5) * CFrame.Angles(math.rad(90), 0, 0)
			rightLeg.CFrame = primary.CFrame * CFrame.new(0.5, -1.0, -0.5) * CFrame.Angles(math.rad(90), 0, 0)
		else
			leftLeg.CFrame = primary.CFrame * CFrame.new(-0.5, -2.5, 0)
			rightLeg.CFrame = primary.CFrame * CFrame.new(0.5, -2.5, 0)
		end
		if lw then lw.Enabled = true end
		if rw then rw.Enabled = true end
	end

	if leftArm and rightArm then
		local lw = leftArm:FindFirstChild("RigWeld_Left Arm") or leftArm:FindFirstChildOfClass("WeldConstraint")
		local rw = rightArm:FindFirstChild("RigWeld_Right Arm") or rightArm:FindFirstChildOfClass("WeldConstraint")
		if lw then lw.Enabled = false end
		if rw then rw.Enabled = false end
		if poseName == "Climb" then
			leftArm.CFrame = primary.CFrame * CFrame.new(-1.5, 0.5, 0) * CFrame.Angles(math.rad(180), 0, 0)
			rightArm.CFrame = primary.CFrame * CFrame.new(1.5, 0.5, 0) * CFrame.Angles(math.rad(180), 0, 0)
		else
			leftArm.CFrame = primary.CFrame * CFrame.new(-1.5, -0.5, 0)
			rightArm.CFrame = primary.CFrame * CFrame.new(1.5, -0.5, 0)
		end
		if lw then lw.Enabled = true end
		if rw then rw.Enabled = true end
	end
end
S.setFigurePose2004 = setFigurePose2004

local function getDynabloxManTemplate()
	return buildProceduralDynabloxMan()
end

local convertedCharacters = {}
S.convertedCharacters = convertedCharacters

-- A raycast that only stops on solid parts. Studs, arrow handles, invisible triggers and the hidden avatars are
-- passed through, so nothing gets stood on (or dragged onto) something you can't see or bump into.
S.raycastSolid = function(origin, direction, ignoreList)
	local ignore = S.getHiddenCharacters and S.getHiddenCharacters() or {}
	for _, inst in ipairs(ignoreList or {}) do
		table.insert(ignore, inst)
	end
	table.insert(ignore, baseStudFolder)
	if S.ArrowRigFolder then
		table.insert(ignore, S.ArrowRigFolder)
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	for _ = 1, 12 do
		rp.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(origin, direction, rp)
		if not hit or hit.Instance.CanCollide then
			return hit
		end
		table.insert(ignore, hit.Instance)
	end
	return nil
end

-- World-space height of the lowest point of a part or model. 3D studs are left out: they only sit on top
-- faces, and right after a move they can lag a frame behind their part.
S.getWorldBottomY = function(obj)
	local function partBottom(p)
		local cf, size = p.CFrame, p.Size
		return cf.Position.Y - (math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z) * 0.5
	end
	if obj:IsA("BasePart") then
		return partBottom(obj)
	end
	local lowest = nil
	for _, d in ipairs(obj:GetDescendants()) do
		if d:IsA("BasePart") and not d:GetAttribute("Is2005Bump") then
			local y = partBottom(d)
			if not lowest or y < lowest then lowest = y end
		end
	end
	return lowest or obj:GetPivot().Position.Y
end

-- Move `obj` straight up or down so its lowest point rests on the first solid surface below `fromPos`
-- (or at `fallbackY` when there is nothing below). Edit mode keeps things anchored, so this is what stops floating.
S.standOnGround = function(obj, fromPos, fallbackY, ignoreList)
	if not obj then return end
	local ignore = { obj }
	for _, inst in ipairs(ignoreList or {}) do
		table.insert(ignore, inst)
	end
	local hit = S.raycastSolid(fromPos, Vector3.new(0, -300, 0), ignore)
	local groundY = hit and hit.Position.Y or fallbackY
	if not groundY then return end
	local ok, bottomY = pcall(S.getWorldBottomY, obj)
	if not ok then return end
	local lift = Vector3.new(0, groundY - bottomY, 0)
	if obj:IsA("Model") then
		obj:PivotTo(obj:GetPivot() + lift)
	else
		obj.CFrame = obj.CFrame + lift
	end
end
local playerColors = {}

local function lockHumanoidAsPhysicsModel(hum)
	if not hum or not hum.Parent then return end
	pcall(function()
		hum.NameDisplayDistance = 0
		hum.HealthDisplayDistance = 0
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.JumpHeight = 0
		hum.AutoRotate = false
		hum.PlatformStand = true
		hum:ChangeState(Enum.HumanoidStateType.Physics)
	end)
end

local function hideMobileMovementGui()
	pcall(function()
		local guiService = game:GetService("GuiService")
		guiService.TouchControlsEnabled = false
	end)
	pcall(function()
		LocalPlayer.DevTouchMovementMode = Enum.DevTouchMovementMode.Scriptable
	end)
	pcall(function()
		local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if pg then
			local touchGui = pg:FindFirstChild("TouchGui")
			if touchGui then
				touchGui.Enabled = false
				for _, desc in ipairs(touchGui:GetDescendants()) do
					if desc:IsA("GuiObject") then
						desc.Visible = false
					end
				end
			end
		end
	end)
end

local function findCharacterRootPart(character)
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
		or character:FindFirstChild("Torso")
		or character:FindFirstChild("UpperTorso")
		or character.PrimaryPart
		or character:FindFirstChildWhichIsA("BasePart")
end

local function convertCharacterTo2005Model(character, forceRebuild)
	if not character then return end
	if not forceRebuild and (convertedCharacters[character] or character:GetAttribute("IsDynabloxFigure")) then
		return
	end
	if SpawnedModelsFolder and character:IsDescendantOf(SpawnedModelsFolder) then
		return
	end

	local hrp = findCharacterRootPart(character)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hrp then
		hrp = character:WaitForChild("HumanoidRootPart", 5) or findCharacterRootPart(character)
	end
	if not hum then
		hum = character:WaitForChild("Humanoid", 5)
	end
	if not hrp then
		return
	end
	convertedCharacters[character] = true
	character:SetAttribute("Is2005PlayerModel", true)
	character:SetAttribute("Is2005Model", true)
	character:SetAttribute("IsDynabloxFigure", true)

	if hum then
		lockHumanoidAsPhysicsModel(hum)
		for _, prop in ipairs({ "WalkSpeed", "JumpPower", "JumpHeight", "PlatformStand" }) do
			storeConnection(hum:GetPropertyChangedSignal(prop):Connect(function()
				lockHumanoidAsPhysicsModel(hum)
			end))
		end
	end

	local isLocal = (character == LocalPlayer.Character)
	if isLocal then
		hideMobileMovementGui()
		pcall(function()
			local animateScript = character:FindFirstChild("Animate")
			if animateScript then animateScript.Disabled = true end
			local animator = hum and hum:FindFirstChildOfClass("Animator")
			if animator then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					track:Stop(0)
				end
				storeConnection(animator.AnimationPlayed:Connect(function(track)
					track:Stop(0)
				end))
			end
		end)
	end

	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.LocalTransparencyModifier = 1
			desc.Transparency = 1
			desc.CanCollide = false
			-- The hidden avatar must never take clicks or touches; otherwise the Drag tool grabs it
			desc.CanQuery = false
			desc.CanTouch = false
			if isLocal and desc ~= hrp then
				desc.Massless = true
			end
		elseif desc:IsA("Decal") or desc:IsA("Texture") then
			desc.Transparency = 1
		elseif desc:IsA("BillboardGui") and not desc:GetAttribute("ClassicOwned") then
			desc.Enabled = false
		end
	end

	-- Parts, hair and accessories that load after this point are hidden too
	storeConnection(character.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") then
			desc.Transparency = 1
			desc.LocalTransparencyModifier = 1
			desc.CanCollide = false
			desc.CanQuery = false
			desc.CanTouch = false
		elseif desc:IsA("Decal") or desc:IsA("Texture") then
			desc.Transparency = 1
		elseif desc:IsA("BillboardGui") and not desc:GetAttribute("ClassicOwned") then
			desc.Enabled = false
		end
	end))

	-- Park and anchor the invisible modern Roblox character so it never falls, collides, or respawns a rig!
	pcall(function()
		hrp.Anchored = true
		hrp.CanCollide = false
		hrp.CanQuery = false
		hrp.CanTouch = false
	end)

	S.deletedPlayerRigs = S.deletedPlayerRigs or {}
	S.spawnedInitialPlayerRig = S.spawnedInitialPlayerRig or {}

	-- If this player's 2005 figure was already deleted (or already spawned once and not forced), NEVER respawn it!
	if not forceRebuild and (S.deletedPlayerRigs[character.Name] or S.spawnedInitialPlayerRig[character.Name]) then
		return
	end
	S.spawnedInitialPlayerRig[character.Name] = true

	if not playerColors[character.Name] then
		if isLocal then
			playerColors[character.Name] = Color3.fromRGB(0, 0, 255) -- 863 Blue figure
		else
			playerColors[character.Name] = DYNABLOX_MAIN_COLORS[math.random(1, #DYNABLOX_MAIN_COLORS)]
		end
	end
	local chosenColor = playerColors[character.Name]

	local oldRig = S.rigRegistry[character]
	if oldRig and oldRig.Parent then oldRig:Destroy() end
	local oldChildRig = character:FindFirstChild("Dynablox2005Rig")
	if oldChildRig then oldChildRig:Destroy() end
	local oldSpawnedRig = SpawnedModelsFolder:FindFirstChild("Player2005Model_" .. character.Name)
	if oldSpawnedRig then oldSpawnedRig:Destroy() end

	-- Spawn the 2005 figure as a standalone selectable Model in SpawnedModelsFolder (NOT welded inside LocalPlayer.Character!)
	-- so it can be freely deleted without ever respawning, and the user sets their own player via Controller!
	local rig = buildProceduralDynabloxMan(chosenColor, S.playerModelStyle)
	local primary = rig.PrimaryPart

	rig.Name = isLocal and "863 Blue figure" or ("Player2005Model_" .. character.Name)
	rig:SetAttribute("OwnerCharacterName", character.Name)
	rig:SetAttribute("Is2005PlayerModel", true)
	local _, curYaw, _ = hrp.CFrame:ToEulerAnglesYXZ()
	rig:PivotTo(CFrame.new(hrp.Position) * CFrame.Angles(0, curYaw, 0))
	-- Stand the figure's feet on whatever is under the avatar, so it doesn't hover in edit mode
	S.standOnGround(rig, hrp.Position + Vector3.new(0, 2, 0), hrp.Position.Y - 3, { character })
	for _, part in ipairs(rig:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = not part:GetAttribute("Is2005Bump")
			part.CanQuery = true
			part.Massless = false
			part.Anchored = not S.isSimulationRunning
		end
	end
	if primary then
		ensureUprightGyro(primary, curYaw)
	end
	rig.Parent = SpawnedModelsFolder

	if isLocal then
		S.localPlayerRig = rig
	end
	S.rigRegistry[character] = rig
	-- NOTE: Do NOT force any character/model to have a Controller unless the user explicitly assigns one!
end
S.convertCharacterTo2005Model = convertCharacterTo2005Model

-- Classic explosions were a glowing red sphere that flashed up for a moment: show one of `radius` at `pos`
S.showRedExplosionSphere = function(pos, radius)
	local ball = Instance.new("Part")
	ball.Name = "Explosion2005"
	ball:SetAttribute("Is2005Effect", true)
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(1, 1, 1) * math.clamp(radius * 2, 2, 60)
	ball.Color = Color3.fromRGB(255, 0, 0)
	ball.Material = Enum.Material.Neon
	ball.Transparency = 0.2
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.CFrame = CFrame.new(pos)
	ball.Parent = Workspace
	task.delay(1, function()
		ball:Destroy()
	end)
end

-- Is `obj` inside an avatar or NPC (a model with a Humanoid), as opposed to a 2005 model you built?
local function isInsideAvatar(obj)
	local model = obj:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return not model:IsDescendantOf(SpawnedModelsFolder)
		end
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model") or nil
	end
	return false
end

-- Keep a property at a value even if a game script sets it back
local function pin(obj, prop, value)
	obj[prop] = value
	obj:GetPropertyChangedSignal(prop):Connect(function()
		if obj[prop] ~= value then obj[prop] = value end
	end)
end

-- Hide the game's modern effects on this client and mute the avatars' walking sounds
if Config.HIDE_FORCEFIELDS_AND_PARTICLES or Config.MUTE_AVATAR_SOUNDS then
	local hideFx = Config.HIDE_FORCEFIELDS_AND_PARTICLES
	local function hideEffect(obj)
		if obj:IsA("Sound") then
			if Config.MUTE_AVATAR_SOUNDS and isInsideAvatar(obj) then
				obj:Stop()
				pin(obj, "Volume", 0)
			end
		elseif not hideFx then
			return
		elseif obj:IsA("ForceField") then
			pin(obj, "Visible", false)
		elseif obj:IsA("ParticleEmitter") then
			-- Invisible as well as off, so a script's :Emit() burst shows nothing either
			pin(obj, "Enabled", false)
			obj:Clear()
			pcall(function() obj.Transparency = NumberSequence.new(1) end)
		elseif obj:IsA("Sparkles") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Trail") or obj:IsA("Beam") then
			pin(obj, "Enabled", false)
		elseif obj:IsA("Explosion") then
			obj.Visible = false
			S.showRedExplosionSphere(obj.Position, obj.BlastRadius)
		end
	end
	task.spawn(function()
		for idx, obj in ipairs(Workspace:GetDescendants()) do
			pcall(hideEffect, obj)
			if idx % 500 == 0 then
				task.wait()
			end
		end
	end)
	storeConnection(Workspace.DescendantAdded:Connect(function(obj)
		pcall(hideEffect, obj)
	end))
end

-- Every real avatar, hidden or not yet hidden, for raycasts that must pass straight through them
S.getHiddenCharacters = function()
	local list = {}
	for char in pairs(convertedCharacters) do
		if char.Parent then table.insert(list, char) end
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character and not convertedCharacters[plr.Character] then
			table.insert(list, plr.Character)
		end
	end
	return list
end

if Config.CONVERT_ALL_PLAYERS_TO_DYNABLOX_MAN then
	local function setupPlayerModel(player)
		if player.Character then
			task.spawn(pcall, convertCharacterTo2005Model, player.Character)
		end
		storeConnection(player.CharacterAdded:Connect(function(char)
			task.defer(pcall, convertCharacterTo2005Model, char)
		end))
	end
	for _, p in ipairs(Players:GetPlayers()) do
		setupPlayerModel(p)
	end
	storeConnection(Players.PlayerAdded:Connect(setupPlayerModel))

	-- Humanoids switch Torso/Head collision back on before every physics step, so the hidden avatars
	-- have to be made non-solid on Stepped too. Without this your own avatar is an invisible wall.
	-- (each avatar's parts are listed once, and again only when parts come or go, not every step)
	local partLists = setmetatable({}, { __mode = "k" })
	local function partsOf(char)
		local entry = partLists[char]
		if entry and not entry.dirty then return entry.list end
		if not entry then
			entry = { list = {}, dirty = true }
			partLists[char] = entry
			storeConnection(char.DescendantAdded:Connect(function() entry.dirty = true end))
			storeConnection(char.DescendantRemoving:Connect(function() entry.dirty = true end))
		end
		local list = {}
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then list[#list + 1] = part end
		end
		entry.list, entry.dirty = list, false
		return list
	end
	storeConnection(RunService.Stepped:Connect(function()
		for char in pairs(convertedCharacters) do
			if char.Parent then
				for _, part in ipairs(partsOf(char)) do
					if part.CanCollide then
						part.CanCollide = false
					end
				end
			else
				convertedCharacters[char] = nil
			end
		end
	end))

	task.spawn(function()
		while Workspace and Workspace.Parent do
			for _, p in ipairs(Players:GetPlayers()) do
				if p.Character and not convertedCharacters[p.Character] then
					pcall(convertCharacterTo2005Model, p.Character)
				end
			end
			for _, child in ipairs(Workspace:GetChildren()) do
				if child:IsA("Model") and not convertedCharacters[child] and not child:GetAttribute("IsDynabloxFigure") and child:FindFirstChildOfClass("Humanoid") then
					pcall(convertCharacterTo2005Model, child)
				end
			end
			task.wait(0.5)
		end
	end)

	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if pg then
		hideMobileMovementGui()
		storeConnection(pg.ChildAdded:Connect(function(ch)
			if ch.Name == "TouchGui" then
				task.defer(hideMobileMovementGui)
			end
		end))
	end
end

--========================================================
-- 9. 2005 3D ARROW HANDLES (NO SPHERES!) + MOBILE & PC BTOOLS SCALING / MOVING ENGINE
--========================================================
local SelectionBox2005 = Instance.new("SelectionBox")
SelectionBox2005.Name = "SelectionBox2005"
SelectionBox2005.Color3 = Color3.fromRGB(0, 255, 255)
SelectionBox2005.LineThickness = 0.06
SelectionBox2005.Parent = ScreenGui

-- Build ONE unified set of 6 physical/visual 2005 3D Arrow Handles in Workspace
-- (Removed the duplicate Roblox Instance.new("Handles") so there is ONLY ONE set of arrows and zero handle conflicts!)
local ArrowRigFolder = Workspace:FindFirstChild("Studio2005ArrowRig")
if ArrowRigFolder then ArrowRigFolder:Destroy() end
ArrowRigFolder = Instance.new("Folder")
ArrowRigFolder.Name = "Studio2005ArrowRig"
ArrowRigFolder.Parent = Workspace
S.ArrowRigFolder = ArrowRigFolder
storeConnection({ Disconnect = function() if ArrowRigFolder then ArrowRigFolder:Destroy() end end })

local FACE_NORMALS = {
	{ Id = Enum.NormalId.Right,  Vec = Vector3.new(1, 0, 0) },
	{ Id = Enum.NormalId.Left,   Vec = Vector3.new(-1, 0, 0) },
	{ Id = Enum.NormalId.Top,    Vec = Vector3.new(0, 1, 0) },
	{ Id = Enum.NormalId.Bottom, Vec = Vector3.new(0, -1, 0) },
	{ Id = Enum.NormalId.Back,   Vec = Vector3.new(0, 0, 1) },
	{ Id = Enum.NormalId.Front,  Vec = Vector3.new(0, 0, -1) },
}

local arrowHitParts = {}
for _, info in ipairs(FACE_NORMALS) do
	-- Invisible generous touch/click hitbox around each 3D arrow so mobile fingers & PC mouse grab arrows effortlessly
	local hitPart = Instance.new("Part")
	hitPart.Name = "ArrowHit_" .. info.Id.Name
	hitPart:SetAttribute("Is2005HandleArrow", true)
	hitPart:SetAttribute("ArrowNormalId", info.Id.Name)
	hitPart.Size = Vector3.new(2.2, 2.2, 3.0)
	hitPart.Transparency = 1
	hitPart.Anchored = true
	hitPart.CanCollide = false
	hitPart.CanTouch = false
	hitPart.CanQuery = true
	hitPart.Parent = ArrowRigFolder

	-- Always-on-top 3D ConeHandleAdornment + LineHandleAdornment parented to ScreenGui with Adornee = hitPart!
	local shaft = Instance.new("LineHandleAdornment")
	shaft.Name = "Shaft_" .. info.Id.Name
	shaft.Adornee = hitPart
	shaft.Thickness = 5
	shaft.Length = 1.6
	shaft.CFrame = CFrame.new(0, 0, 1.35)
	shaft.AlwaysOnTop = true
	shaft.ZIndex = 5
	shaft.Visible = false
	shaft.Parent = ScreenGui

	local cone = Instance.new("ConeHandleAdornment")
	cone.Name = "Tip_" .. info.Id.Name
	cone.Adornee = hitPart
	cone.Radius = 0.45
	cone.Height = 1.1
	cone.CFrame = CFrame.new(0, 0, -0.25)
	cone.AlwaysOnTop = true
	cone.ZIndex = 6
	cone.Visible = false
	cone.Parent = ScreenGui

	arrowHitParts[info.Id] = {
		Normal = info.Vec,
		HitPart = hitPart,
		Shaft = shaft,
		Cone = cone,
		WorldTip = Vector3.zero,
		WorldBase = Vector3.zero,
		WorldDir = info.Vec,
	}
end

local function getHandleTargetPart(obj)
	if not obj then return nil end
	if obj:IsA("BasePart") then return obj end
	if obj:IsA("Model") then
		local rig = obj:FindFirstChild("Dynablox2005Rig")
		if rig and rig.PrimaryPart then return rig.PrimaryPart end
		return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function getObjectBoundingBox(obj)
	if not obj then return nil, nil end
	if obj:IsA("BasePart") then
		return obj.CFrame, obj.Size
	elseif obj:IsA("Model") then
		local ok, cf, sz = pcall(function() return obj:GetBoundingBox() end)
		if ok and cf and sz then return cf, sz end
		local tp = getHandleTargetPart(obj)
		if tp then return tp.CFrame, tp.Size end
	end
	return nil, nil
end

local function updateHandlesAdornee()
	local targetPart = getHandleTargetPart(S.selectedObject)
	local showArrows = S.selectedObject ~= nil and targetPart ~= nil and (S.currentStudioTool == "Resize" or S.currentStudioTool == "Move")
	-- Axis Drag arrows are G3D orange; Resize handles use the cyan of the selection box
	local arrowColor = (S.currentStudioTool == "Resize") and Color3.fromRGB(0, 255, 255) or Color3.fromRGB(255, 128, 0)

	local boxCF, boxSize = getObjectBoundingBox(S.selectedObject)
	for normalId, data in pairs(arrowHitParts) do
		if showArrows and boxCF and boxSize then
			local n = data.Normal
			local faceDist = math.abs(n.X) * (boxSize.X * 0.5) + math.abs(n.Y) * (boxSize.Y * 0.5) + math.abs(n.Z) * (boxSize.Z * 0.5)
			local worldCenter = boxCF.Position
			local worldDir = boxCF:VectorToWorldSpace(n).Unit
			local basePos = worldCenter + worldDir * (faceDist + 0.35)
			local tipPos = basePos + worldDir * 2.7

			data.WorldBase = basePos
			data.WorldTip = tipPos
			data.WorldDir = worldDir
			data.HitPart.CFrame = CFrame.lookAt(basePos + worldDir * 1.35, tipPos + worldDir)
			data.Shaft.Adornee = data.HitPart
			data.Shaft.Color3 = arrowColor
			data.Shaft.Visible = true
			data.Cone.Adornee = data.HitPart
			data.Cone.Color3 = arrowColor
			data.Cone.Visible = true
		else
			data.Shaft.Visible = false
			data.Cone.Visible = false
			data.HitPart.CFrame = CFrame.new(0, -500, 0)
		end
	end
end
S.updateHandlesAdornee = updateHandlesAdornee

-- Exact 3D Ray-to-Axis Closest Point helper for 1:1 3D arrow dragging at any distance/angle
local function projectScreenPosOntoAxis(originPos, worldDir, screenPos, startScreenPos)
	local cam = Workspace.CurrentCamera
	if not cam then return 0 end

	local ray = cam:ScreenPointToRay(screenPos.X, screenPos.Y)
	local r0 = ray.Origin
	local rd = ray.Direction.Unit
	local w0 = originPos - r0
	local b = worldDir:Dot(rd)
	local denom = 1 - b * b

	-- When not looking nearly parallel to the arrow axis, use exact 3D ray-to-line closest point!
	if denom > 0.08 then
		local d = worldDir:Dot(w0)
		local e = rd:Dot(w0)
		return (b * e - d) / denom
	end

	-- Fallback when looking straight down the arrow axis
	local p0, _ = cam:WorldToViewportPoint(originPos)
	local p1, _ = cam:WorldToViewportPoint(originPos + worldDir)
	local screenAxis = Vector2.new(p1.X - p0.X, p1.Y - p0.Y)
	local screenLen = screenAxis.Magnitude
	if screenLen < 6 then
		local dy = ((startScreenPos and startScreenPos.Y or screenPos.Y) - screenPos.Y)
		return dy / 18
	end
	local sRef = startScreenPos or screenPos
	local screenDelta = Vector2.new(screenPos.X - sRef.X, screenPos.Y - sRef.Y)
	return screenDelta:Dot(screenAxis.Unit) / math.clamp(screenLen, 10, 120)
end

local activeDragState = nil

local function beginArrowHandleDrag(normalId, startScreenPos, inputObj)
	local obj = S.selectedObject
	local part = getHandleTargetPart(obj)
	if not obj or not part then return false end
	updateHandlesAdornee()
	local arrowData = arrowHitParts[normalId]
	if not arrowData then return false end

	local startScale = nil
	local startPartTransforms = nil
	local startPivot = obj:IsA("Model") and obj:GetPivot() or part.CFrame
	if obj:IsA("Model") then
		pcall(function() startScale = obj:GetScale() end)
		startPartTransforms = {}
		for _, p in ipairs(obj:GetDescendants()) do
			if p:IsA("BasePart") and not p:GetAttribute("Is2005Bump") then
				startPartTransforms[p] = {
					Size = p.Size,
					RelCF = startPivot:ToObjectSpace(p.CFrame),
				}
			end
		end
	end

	local sPos2D = Vector2.new(startScreenPos.X, startScreenPos.Y)
	local startAxisT = projectScreenPosOntoAxis(arrowData.WorldBase, arrowData.WorldDir, sPos2D, sPos2D)

	activeDragState = {
		Mode = S.currentStudioTool, -- "Resize" or "Move"
		NormalId = normalId,
		LocalNormal = arrowData.Normal,
		WorldDir = arrowData.WorldDir,
		OriginPos = arrowData.WorldBase,
		StartScreenPos = sPos2D,
		StartAxisT = startAxisT,
		InputObject = inputObj,
		Object = obj,
		Part = part,
		StartSize = part.Size,
		StartCF = part.CFrame,
		StartPivot = startPivot,
		StartScale = startScale,
		StartPartTransforms = startPartTransforms,
		LastStep = 0,
	}
	S.isDraggingObject = false
	return true
end
S.beginArrowHandleDrag = beginArrowHandleDrag

local function applyArrowHandleStep(rawStep)
	if not activeDragState then return end
	local step = math.clamp(rawStep, activeDragState.LastStep - 8, activeDragState.LastStep + 8)
	step = math.clamp(step, -120, 120)
	if step == activeDragState.LastStep then return end
	activeDragState.LastStep = step

	local obj = activeDragState.Object
	local part = activeDragState.Part
	local normal = activeDragState.LocalNormal
	if not obj or not obj.Parent or not part or not part.Parent then return end

	if activeDragState.Mode == "Resize" then
		if obj:IsA("Model") then
			local baseScale = activeDragState.StartScale or 1
			local newScale = math.clamp(baseScale + step * 0.15, 0.25, 12)
			local scaledOk = pcall(function() obj:ScaleTo(newScale) end)
			if not scaledOk and activeDragState.StartPartTransforms then
				local ratio = newScale / baseScale
				local piv = activeDragState.StartPivot
				for p, data in pairs(activeDragState.StartPartTransforms) do
					if p and p.Parent then
						p.Size = data.Size * ratio
						local relRot = data.RelCF - data.RelCF.Position
						p.CFrame = piv * CFrame.new(data.RelCF.Position * ratio) * relRot
					end
				end
			end
			syncObject3DBumps(obj)
			updateHandlesAdornee()
			return
		end

		local ax, ay, az = math.abs(normal.X), math.abs(normal.Y), math.abs(normal.Z)
		local sSize = activeDragState.StartSize
		local newX = (ax > 0.5) and math.max(1, sSize.X + step) or sSize.X
		local newY = (ay > 0.5) and math.max(1, sSize.Y + step) or sSize.Y
		local newZ = (az > 0.5) and math.max(1, sSize.Z + step) or sSize.Z

		local dX = newX - sSize.X
		local dY = newY - sSize.Y
		local dZ = newZ - sSize.Z
		local localOffset = Vector3.new(normal.X * dX * 0.5, normal.Y * dY * 0.5, normal.Z * dZ * 0.5)

		part.Size = Vector3.new(newX, newY, newZ)
		part.CFrame = activeDragState.StartCF * CFrame.new(localOffset)
		rebuild3DBumpsForPart(part)
		updateHandlesAdornee()
	elseif activeDragState.Mode == "Move" then
		local worldOffset = activeDragState.WorldDir * step
		local newCF = activeDragState.StartPivot + worldOffset
		if obj:IsA("Model") then
			obj:PivotTo(newCF)
			syncObject3DBumps(obj)
		elseif obj:IsA("BasePart") then
			obj.CFrame = newCF
			syncPart3DBumpsCFrame(obj)
		end
		updateHandlesAdornee()
	end
end
S.applyArrowHandleStep = applyArrowHandleStep

local function computeAxisStepFromScreenPos(screenPos)
	if not activeDragState then return 0 end
	local curT = projectScreenPosOntoAxis(
		activeDragState.OriginPos,
		activeDragState.WorldDir,
		screenPos,
		activeDragState.StartScreenPos
	)
	local deltaStuds = curT - (activeDragState.StartAxisT or 0)
	return math.floor(deltaStuds + 0.5)
end
S.computeAxisStepFromScreenPos = computeAxisStepFromScreenPos

local function endArrowHandleDrag()
	activeDragState = nil
end
S.endArrowHandleDrag = endArrowHandleDrag
S.isArrowDragging = function() return activeDragState ~= nil end
S.getArrowDragInput = function() return activeDragState and activeDragState.InputObject or nil end

local function findHitArrowNormalId(screenPos)
	if not S.selectedObject or (S.currentStudioTool ~= "Resize" and S.currentStudioTool ~= "Move") then
		return nil
	end
	local cam = Workspace.CurrentCamera
	if not cam then return nil end

	-- 1. Raycast directly against the 6 generous invisible ArrowHit parts in ArrowRigFolder
	local ray = cam:ScreenPointToRay(screenPos.X, screenPos.Y)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { ArrowRigFolder }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 500, rp)
	if hit and hit.Instance then
		local nidName = hit.Instance:GetAttribute("ArrowNormalId")
		if nidName and Enum.NormalId[nidName] then
			return Enum.NormalId[nidName]
		end
	end

	-- 2. Check 2D screen distance along each of the 6 arrow shafts/tips (generous 56px radius for mobile fingers!)
	local bestNormalId = nil
	local bestDist = 56
	for normalId, data in pairs(arrowHitParts) do
		if data.Cone.Visible then
			for _, wpt in ipairs({ data.WorldTip, (data.WorldBase + data.WorldTip) * 0.5, data.WorldBase }) do
				local vp, onScreen = cam:WorldToViewportPoint(wpt)
				if onScreen and vp.Z > 0 then
					local d = (Vector2.new(vp.X, vp.Y) - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
					if d < bestDist then
						bestDist = d
						bestNormalId = normalId
					end
				end
			end
		end
	end
	return bestNormalId
end
S.findHitArrowNormalId = findHitArrowNormalId

local function selectStudioObject(obj)
	if obj and obj:IsA("BasePart") then
		if obj:GetAttribute("Is2005HandleArrow") then
			return
		end
		if (obj.Name == "Bump2005" or obj:GetAttribute("Is2005Bump")) and obj.Parent and obj.Parent.Name == "Bumps2005" and obj.Parent.Parent and obj.Parent.Parent:IsA("BasePart") then
			obj = obj.Parent.Parent
		end
		local charModel = obj:FindFirstAncestorOfClass("Model")
		while charModel and charModel.Name == "Dynablox2005Rig" do
			charModel = charModel.Parent and charModel.Parent:FindFirstAncestorOfClass("Model") or charModel.Parent
		end
		if charModel and charModel:IsA("Model") and (
			Players:GetPlayerFromCharacter(charModel)
			or charModel:GetAttribute("Is2005Model")
			or charModel:GetAttribute("IsDynabloxFigure")
			or charModel.Parent == SpawnedModelsFolder
		) then
			obj = charModel
		end
	end
	if obj and obj:IsA("BasePart") and ((obj.Size.X >= 256 and obj.Size.Z >= 256) or obj:GetAttribute("Is2005Bump")) then
		obj = nil
	end
	local changed = (S.selectedObject ~= obj)
	S.selectedObject = obj
	SelectionBox2005.Adornee = obj
	refreshAllToolbarSprites()
	if S.refreshPropertyGrid then S.refreshPropertyGrid() end
	-- the Controller page highlights the selection's own controller
	if changed and S.activeTab == "Controller" and rebuildBottomBarContent then
		rebuildBottomBarContent()
	end
	if obj then
		playClassicSound(SOUND_CLICK, 0.35, 1.15)
	end
end

local function moveStudioObject(obj, targetPos)
	if not obj then return end
	local snapped = Vector3.new(
		math.floor(targetPos.X + 0.5),
		targetPos.Y,
		math.floor(targetPos.Z + 0.5)
	)
	if obj:IsA("Model") then
		local piv = obj:GetPivot()
		obj:PivotTo(CFrame.new(snapped) * (piv - piv.Position))
	elseif obj:IsA("BasePart") then
		local rot = obj.CFrame - obj.CFrame.Position
		obj.CFrame = CFrame.new(snapped) * rot
	end
	syncObject3DBumps(obj)
	updateHandlesAdornee()
end

-- 2005 Rotate turns the selection 90 degrees about its up axis; Tilt turns it 90 degrees about its Z axis
local function rotateSelectedObject(yawDeg, tiltDeg)
	if not S.selectedObject then return end
	local turn = CFrame.Angles(0, math.rad(yawDeg), math.rad(tiltDeg))
	if S.selectedObject:IsA("Model") then
		S.selectedObject:PivotTo(S.selectedObject:GetPivot() * turn)
	elseif S.selectedObject:IsA("BasePart") then
		S.selectedObject.CFrame = S.selectedObject.CFrame * turn
	end
	syncObject3DBumps(S.selectedObject)
	updateHandlesAdornee()
	playClassicSound(SOUND_CLICK, 0.45, 1)
end
S.rotateSelectedObject = rotateSelectedObject

storeConnection(RotateLeftBtn.MouseButton1Click:Connect(function() rotateSelectedObject(90, 0) end))
storeConnection(RotateRightBtn.MouseButton1Click:Connect(function() rotateSelectedObject(0, 90) end))

local function getObjectHeight(obj)
	if obj:IsA("BasePart") then
		return obj.Size.Y
	end
	local ok, _, size = pcall(function() return obj:GetBoundingBox() end)
	return (ok and size) and size.Y or 4
end

-- 2005 Duplicate drops the copy straight on top of the original
local function duplicateSelectedObject()
	if not S.selectedObject then return end
	pcall(function()
		if Players:GetPlayerFromCharacter(S.selectedObject) then
			local fig = getDynabloxManTemplate():Clone()
			fig.Name = "Dynablox-man Clone"
			fig:SetAttribute("Is2005Model", true)
			fig:SetAttribute("IsDynabloxFigure", true)
			fig:PivotTo(S.selectedObject:GetPivot() * CFrame.new(3, 2, 0))
			for _, p in ipairs(fig:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CanCollide = not p:GetAttribute("Is2005Bump")
					p.Anchored = not S.isSimulationRunning
				end
			end
			fig.Parent = SpawnedModelsFolder
			selectStudioObject(fig)
		else
			S.selectedObject.Archivable = true
			local clone = S.selectedObject:Clone()
			local lift = Vector3.new(0, getObjectHeight(S.selectedObject), 0)
			clone.Parent = SpawnedModelsFolder
			if clone:IsA("Model") then
				clone:PivotTo(S.selectedObject:GetPivot() + lift)
			elseif clone:IsA("BasePart") then
				clone.CFrame = S.selectedObject.CFrame + lift
			end
			selectStudioObject(clone)
		end
		playClassicSound(SOUND_BOOP, 0.5, 1)
	end)
end
S.duplicateSelectedObject = duplicateSelectedObject
storeConnection(S.DuplicateBtn.MouseButton1Click:Connect(duplicateSelectedObject))

local function groupSelectedObject()
	if S.selectedObject and S.selectedObject:IsA("BasePart") then
		local m = Instance.new("Model")
		m.Name = "Model"
		m:SetAttribute("Is2005Model", true)
		m.Parent = S.selectedObject.Parent
		S.selectedObject.Parent = m
		m.PrimaryPart = S.selectedObject
		selectStudioObject(m)
		playClassicSound(SOUND_BOOP, 0.5, 1)
	end
end
S.groupSelectedObject = groupSelectedObject

local function ungroupSelectedObject()
	if S.selectedObject and S.selectedObject:IsA("Model") and not Players:GetPlayerFromCharacter(S.selectedObject) then
		local parent = S.selectedObject.Parent or Workspace
		local firstPart = nil
		for _, child in ipairs(S.selectedObject:GetChildren()) do
			child.Parent = parent
			if not firstPart and child:IsA("BasePart") then
				firstPart = child
			end
		end
		S.selectedObject:Destroy()
		selectStudioObject(firstPart)
		playClassicSound(SOUND_BOOP, 0.5, 1)
	end
end
S.ungroupSelectedObject = ungroupSelectedObject

storeConnection(S.GroupBtn.MouseButton1Click:Connect(groupSelectedObject))
storeConnection(S.UnGroupBtn.MouseButton1Click:Connect(ungroupSelectedObject))

local function deleteSelectedStudioObject()
	local target = S.selectedObject
	if not target then return end
	S.deletedPlayerRigs = S.deletedPlayerRigs or {}

	local ownerName = target:GetAttribute("OwnerCharacterName")
	if ownerName then
		S.deletedPlayerRigs[ownerName] = true
	end
	local plr = Players:GetPlayerFromCharacter(target)
	if plr then
		S.deletedPlayerRigs[plr.Name] = true
		local rig = S.rigRegistry and S.rigRegistry[target]
		if rig and rig.Parent then
			rig:Destroy()
		end
		S.rigRegistry[target] = nil
		if S.localPlayerRig == rig then
			S.localPlayerRig = nil
		end
	else
		if S.localPlayerRig == target then
			S.deletedPlayerRigs[LocalPlayer.Name] = true
			S.localPlayerRig = nil
		end
		for char, rig in pairs(S.rigRegistry or {}) do
			if rig == target then
				if char and char.Name then
					S.deletedPlayerRigs[char.Name] = true
				end
				S.rigRegistry[char] = nil
			end
		end
		if S.controlledObjects then
			S.controlledObjects[target] = nil
		end
		if S.activeControlledModel == target then
			S.activeControlledModel = nil
		end
		pcall(function()
			target:Destroy()
		end)
	end
	selectStudioObject(nil)
	if S.refreshPropertyGrid then pcall(S.refreshPropertyGrid) end
	playClassicSound(SOUND_PAGE, 0.5, 1)
end
S.deleteSelectedStudioObject = deleteSelectedStudioObject

storeConnection(TrashBtn.MouseButton1Click:Connect(deleteSelectedStudioObject))

local function saveStudioState()
	S.savedTransforms = {}
	if LocalPlayer.Character then
		local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character:FindFirstChild("Torso")
		if hrp then
			S.savedTransforms[hrp] = { CFrame = hrp.CFrame, IsCharacterRoot = true }
		end
	end
	for _, obj in ipairs(SpawnedModelsFolder:GetDescendants()) do
		if obj:IsA("BasePart") and not obj:GetAttribute("Is2005Bump") then
			local parentModel = obj:FindFirstAncestorOfClass("Model")
			local isPlayerModel = parentModel and parentModel:GetAttribute("Is2005PlayerModel")
			S.savedTransforms[obj] = {
				CFrame = obj.CFrame,
				Anchored = obj:GetAttribute("AnchoredInGame") or false,
				IsPlayerModel = isPlayerModel,
			}
		end
	end
end

local function start2005Simulation()
	S.isSimulationRunning = true
	CenterBanner.Visible = false
	S.currentTimerValue = S.level.InitialTimerValue
	S.bonusScore = S.level.InitialScoreValue
	S.scoreStepAccum = 0
	saveStudioState()
	updateScoreTimerUI()
	updateGoStopVisual()
	playClassicSound(SOUND_CLICK, 0.5, 1.2)

	-- The Hopper tools start un-held; whatever they make or remove this run is undone by STOP
	S.runSpawned = {}
	S.runRemoved = {}
	S.activeHopperBin = nil
	if S.refreshHopperBar then S.refreshHopperBar() end

	if LocalPlayer.Character then
		local rig = S.rigRegistry and S.rigRegistry[LocalPlayer.Character]
		if rig then
			for _, desc in ipairs(rig:GetDescendants()) do
				if desc:IsA("WeldConstraint") or desc:IsA("Motor6D") then
					desc.Enabled = true
				elseif desc:IsA("BasePart") and not desc:GetAttribute("Is2005Bump") then
					desc.Anchored = false
				end
			end
		end
	end
	for _, obj in ipairs(SpawnedModelsFolder:GetDescendants()) do
		if obj:IsA("WeldConstraint") or obj:IsA("Motor6D") or obj:IsA("HingeConstraint") then
			obj.Enabled = true
		elseif obj:IsA("BasePart") and not obj:GetAttribute("Is2005Bump") then
			obj:SetAttribute("TriggeredInRun", nil) -- SingleShot OnTouch fires once per run
			obj.CanCollide = not obj:GetAttribute("IsSwingingArm2004")
			obj.Anchored = (obj:GetAttribute("AnchoredInGame") == true)
			local initVel = obj:GetAttribute("InitialVelocity2004")
			obj.AssemblyLinearVelocity = (typeof(initVel) == "Vector3") and initVel or Vector3.zero
			obj.AssemblyAngularVelocity = Vector3.zero
		end
	end

	-- Fragment Bomb (853): detonate after 2.5 seconds of spinning in GO mode!
	for _, model in ipairs(SpawnedModelsFolder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("OriginalRBXMId") == 853 then
			task.delay(2.5, function()
				if not S.isSimulationRunning or not model or not model.Parent then return end
				playClassicSound(SOUND_BOOP, 0.85, 0.55)
				local centerPos = model:GetPivot().Position
				for _, desc in ipairs(model:GetDescendants()) do
					if desc:IsA("WeldConstraint") or desc:IsA("HingeConstraint") then
						desc.Enabled = false
					end
				end
				for _, part in ipairs(model:GetDescendants()) do
					if part:IsA("BasePart") and not part:GetAttribute("Is2005Bump") and not part:GetAttribute("AnchoredInGame") then
						local dir = (part.Position - centerPos)
						if dir.Magnitude < 0.1 then dir = Vector3.new(math.random() - 0.5, 0.6, math.random() - 0.5) end
						part.AssemblyLinearVelocity = dir.Unit * 55 + Vector3.new(0, 28, 0)
					end
				end
			end)
		end
	end
end

local function stop2005Simulation()
	S.isSimulationRunning = false
	CenterBanner.Visible = false

	-- STOP puts back everything the Hopper tools changed: copies, balls and rockets go away, hammered things return
	if S.endHopperGrab then S.endHopperGrab() end
	for _, inst in ipairs(S.runSpawned or {}) do
		pcall(function() inst:Destroy() end)
	end
	S.runSpawned = {}
	local removed = S.runRemoved or {}
	for i = #removed, 1, -1 do
		pcall(function() removed[i].Obj.Parent = removed[i].Parent end)
	end
	S.runRemoved = {}
	S.activeHopperBin = nil
	if S.refreshHopperBar then S.refreshHopperBar() end
	if S.selectedObject and not S.selectedObject.Parent then
		selectStudioObject(nil)
	end
	S.currentTimerValue = S.level.InitialTimerValue
	S.bonusScore = S.level.InitialScoreValue
	updateScoreTimerUI()
	updateGoStopVisual()
	playClassicSound(SOUND_CLICK, 0.5, 0.85)

	-- Re-enable any joints disabled during Run mode (e.g., the Fragment Bomb explosion)
	if LocalPlayer.Character then
		local rig = S.rigRegistry and S.rigRegistry[LocalPlayer.Character]
		if rig then
			for _, desc in ipairs(rig:GetDescendants()) do
				if desc:IsA("WeldConstraint") or desc:IsA("Motor6D") then
					desc.Enabled = true
					if desc:IsA("Motor6D") and S_baseShoulderC0[desc] then desc.C0 = S_baseShoulderC0[desc] end
				end
			end
		end
	end
	for _, desc in ipairs(SpawnedModelsFolder:GetDescendants()) do
		if desc:IsA("WeldConstraint") or desc:IsA("Motor6D") or desc:IsA("HingeConstraint") then
			desc.Enabled = true
			if desc:IsA("Motor6D") and S_baseShoulderC0[desc] then desc.C0 = S_baseShoulderC0[desc] end
		end
	end

	for part, data in pairs(S.savedTransforms) do
		if part and part.Parent then
			pcall(function()
				part.AssemblyLinearVelocity = Vector3.zero
				part.AssemblyAngularVelocity = Vector3.zero
				part.CFrame = data.CFrame
				if part:GetAttribute("IsSwingingArm2004") then
					part.Anchored = false
				else
					part.Anchored = true
				end
			end)
		end
	end
end

-- 2005 Level end (Win / Lose / Draw / Pause): stop the run like pressing STOP and show the Level message
local function endLevel2005(action)
	if not S.isSimulationRunning then return end
	stop2005Simulation()
	if action == "Win" then
		playClassicSound(SOUND_WIN, 0.7, 1)
		showCenterBanner(S.level.WinMessage)
	elseif action == "Lose" then
		playClassicSound(SOUND_BOOP, 0.7, 0.6)
		showCenterBanner(S.level.LoseMessage)
	end
end
S.endLevel2005 = endLevel2005

local function reset2005Game()
	if S.isSimulationRunning then
		stop2005Simulation()
		start2005Simulation()
	else
		stop2005Simulation()
		if S.localPlayerRig and S.localPlayerRig.Parent then
			S.localPlayerRig:PivotTo(CFrame.new(0, 12, 0))
			S.standOnGround(S.localPlayerRig, Vector3.new(0, 12, 0), 0)
		elseif LocalPlayer.Character then
			LocalPlayer.Character:PivotTo(CFrame.new(0, 12, 0))
		end
	end
	playClassicSound(SOUND_BOOP, 0.55, 1.0)
end

storeConnection(GoStopBtn.MouseButton1Click:Connect(function()
	if S.isSimulationRunning then
		stop2005Simulation()
	else
		start2005Simulation()
	end
end))

storeConnection(TopResetBtn.MouseButton1Click:Connect(reset2005Game))

--========================================================
-- 10. 2005 TOOLBOX MODELS, CONTROLLERS & BRICKS CATALOG
--========================================================
-- 2005 ControllerSchemes and the colour of their flag / motor ring: KeyboardRight = blue (arrow keys),
-- KeyboardLeft = red (W/A/S/D), Chase = black, Flee = yellow, Player = purple (added with Humanoids in
-- fall 2005) and Joypad1 / Joypad2 = grey (listed in the menus but never worked)
local CONTROLLER_ORDER_2005 = { "None", "KeyboardRight", "KeyboardLeft", "Joypad1", "Joypad2", "Chase", "Flee", "Player" }
local CONTROLLER_FLAG_COLORS = {
	Player        = Color3.fromRGB(128, 0, 128),
	KeyboardRight = Color3.fromRGB(0, 0, 255),
	KeyboardLeft  = Color3.fromRGB(255, 0, 0),
	Joypad1       = Color3.fromRGB(128, 128, 128),
	Joypad2       = Color3.fromRGB(128, 128, 128),
	Chase         = Color3.fromRGB(0, 0, 0),
	Flee          = Color3.fromRGB(255, 255, 0),
}
S.CONTROLLER_ORDER_2005 = CONTROLLER_ORDER_2005

S.controlledObjects = S.controlledObjects or {}

local function isKeyboardController(ctrlType)
	return ctrlType == "KeyboardRight" or ctrlType == "KeyboardLeft" or ctrlType == "Player"
end
S.isKeyboardController = isKeyboardController

-- flagShown mirrors the 2005 ControllerFlagShown property (false on the 863/864 figures)
local function attachControllerBadge(targetObj, ctrlType, flagShown)
	if not targetObj then return end
	local old = targetObj:FindFirstChild("ControllerFlag2005", true)
	if old then old:Destroy() end
	targetObj:SetAttribute("ControllerType2005", ctrlType)
	if flagShown ~= nil then
		targetObj:SetAttribute("ControllerFlagShown2005", flagShown)
	end
	if ctrlType == "None" then
		S.controlledObjects[targetObj] = nil
		if S.activeControlledModel == targetObj then
			S.activeControlledModel = nil
		end
		return
	end
	S.controlledObjects[targetObj] = ctrlType
	if isKeyboardController(ctrlType) then
		S.activeControlledModel = targetObj
		if S.ControllerFlagBtn then
			applySpriteToImage(S.ControllerFlagBtn, (ctrlType == "KeyboardLeft") and "Flag_Red" or "Flag_Blue")
		end
	end
	if S.isSimulationRunning then
		for _, p in ipairs(targetObj:IsA("Model") and targetObj:GetDescendants() or { targetObj }) do
			if p:IsA("BasePart") and not p:GetAttribute("Is2005Bump") and not p:GetAttribute("AnchoredInGame") then
				p.Anchored = false
			end
		end
	end

	if targetObj:GetAttribute("ControllerFlagShown2005") == false then return end
	local adornee = targetObj:IsA("Model") and (targetObj.PrimaryPart or targetObj:FindFirstChildWhichIsA("BasePart", true)) or targetObj
	if not adornee or not adornee:IsA("BasePart") then return end

	local bGui = Instance.new("BillboardGui")
	bGui.Name = "ControllerFlag2005"
	bGui:SetAttribute("ClassicOwned", true)
	bGui.Adornee = adornee
	bGui.Size = UDim2.fromOffset(26, 26)
	bGui.StudsOffset = Vector3.new(0, 3.2, 0)
	bGui.AlwaysOnTop = true
	bGui.Parent = targetObj

	-- A plain flag in the scheme's colour (blue / red flag art, the grey flag tinted for the others)
	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.Parent = bGui
	if ctrlType == "KeyboardRight" then
		applySpriteToImage(icon, "Flag_Blue")
	elseif ctrlType == "KeyboardLeft" then
		applySpriteToImage(icon, "Flag_Red")
	else
		applySpriteToImage(icon, "Controller1_ds")
		icon.ImageColor3 = CONTROLLER_FLAG_COLORS[ctrlType] or CONTROLLER_FLAG_COLORS.Joypad1
	end
end
S.attachControllerBadge = attachControllerBadge

-- 2005 NameShown: the model's name floats above it (e.g. "5 sec", "100 Points")
local function setNameShown2005(targetObj, labelText)
	if not targetObj then return end
	local old = targetObj:FindFirstChild("NameShown2005")
	if old then old:Destroy() end
	targetObj:SetAttribute("NameShown2005", labelText ~= nil)
	if not labelText then return end
	local adornee = targetObj:IsA("Model") and (targetObj.PrimaryPart or targetObj:FindFirstChildWhichIsA("BasePart", true)) or targetObj
	if not adornee or not adornee:IsA("BasePart") then return end
	local ok, _, size = pcall(function() return targetObj:GetBoundingBox() end)
	local height = (targetObj:IsA("BasePart") and targetObj.Size.Y) or ((ok and size) and size.Y) or 4

	local bGui = Instance.new("BillboardGui")
	bGui.Name = "NameShown2005"
	bGui:SetAttribute("ClassicOwned", true)
	bGui.Adornee = adornee
	bGui.Size = UDim2.fromOffset(160, 24)
	bGui.StudsOffsetWorldSpace = Vector3.new(0, height * 0.5 + 1.5, 0)
	bGui.AlwaysOnTop = true
	bGui.Parent = targetObj

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = labelText
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	lbl.TextStrokeTransparency = 0
	lbl.TextSize = 16
	lbl.Parent = bGui
	apply2006Font(lbl)
end
S.setNameShown2005 = setNameShown2005

local ON_TOUCH_SOUNDS = {
	Ping    = { SOUND_BOOP, 1 },
	Clock   = { SOUND_TICK, 1 },
	Victory = { SOUND_WIN, 1 },
	Boing   = { SOUND_BOOP, 0.6 },
}

-- 2005 OnTouch: ChangeScore / ChangeTimer, then the Win / Lose Action. SingleShot fires once per run.
local function hookInteractive2005Model(part, onTouch)
	storeConnection(part.Touched:Connect(function(hit)
		if not S.isSimulationRunning then return end
		if not hit or not hit.Parent or hit == part or hit:IsDescendantOf(part) then return end
		if hit:GetAttribute("Is2005Bump") then return end
		local hitModel = hit:FindFirstAncestorOfClass("Model")
		if hitModel == LocalPlayer.Character or hit:IsDescendantOf(SpawnedModelsFolder) then
			if part:GetAttribute("TriggeredInRun") then return end
			part:SetAttribute("TriggeredInRun", true)
			local snd = ON_TOUCH_SOUNDS[onTouch.Sound or "Ping"]
			if snd and onTouch.Action ~= "Win" and onTouch.Action ~= "Lose" then
				playClassicSound(snd[1], 0.6, snd[2])
			end
			if onTouch.Score and onTouch.Score ~= 0 then
				S.bonusScore = S.bonusScore + onTouch.Score
			end
			if onTouch.Timer and onTouch.Timer ~= 0 then
				S.currentTimerValue = S.currentTimerValue + onTouch.Timer
			end
			updateScoreTimerUI()
			if onTouch.Action == "Win" or onTouch.Action == "Lose" then
				endLevel2005(onTouch.Action)
			end
		end
	end))
end

local ORIGINAL_2004_TOOLBOX_MODELS = {
	{Id="RBXM_770",Num=770,Name="Ball 4x4x4",Category="Blocks",Class="TrussPart",Ctrl="None",BBox={4,4,4},OnTouch=nil,Parts={{1,{4,4,4},{0,2,0},nil,{221,45,45},false,"",nil,nil}},Joints={}},
	{Id="RBXM_771",Num=771,Name="Block 2x4x1",Category="Blocks",Class="Part",Ctrl="None",BBox={4,1,2},OnTouch=nil,Parts={{2,{2,1,4},{0,0.5,0},{0,0,1,0,1,0,-1,0,0},{128,128,128},false,"TB",nil,nil}},Joints={}},
	{Id="RBXM_772",Num=772,Name="Block 2x4x1 no join",Category="Blocks",Class="Part",Ctrl="None",BBox={4,1,2},OnTouch=nil,Parts={{2,{2,1,4},{0,0.5,0},{0,0,1,0,-1,0,1,0,0},{221,221,221},false,"",nil,nil}},Joints={}},
	{Id="RBXM_773",Num=773,Name="Block 2x4x1 hinged",Category="Blocks",Class="Part",Ctrl="None",BBox={4,1,2},OnTouch=nil,Parts={{2,{2,1,4},{0,0.5,0},{0,0,1,0,1,0,-1,0,0},{128,128,128},false,"TB",nil,nil}},Joints={}},
	{Id="RBXM_774",Num=774,Name="Block 2x2x6",Category="Blocks",Class="Part",Ctrl="None",BBox={2,6,2},OnTouch=nil,Parts={{2,{2,6,2},{0,3,0},nil,{128,128,128},false,"TB",nil,nil}},Joints={}},
	{Id="RBXM_775",Num=775,Name="Block 4x8x1",Category="Blocks",Class="Part",Ctrl="None",BBox={8,1,4},OnTouch=nil,Parts={{2,{8,1,4},{0,0.5,0},nil,{128,128,128},false,"TB",nil,nil}},Joints={}},
	{Id="RBXM_776",Num=776,Name="Block 4x4x1 turntable",Category="Blocks",Class="Part",Ctrl="None",BBox={4,1,4},OnTouch=nil,Parts={{2,{4,1,4},{0,0.5,0},{0,0,1,0,1,0,-1,0,0},{128,128,128},false,"B",nil,nil}},Joints={}},
	{Id="RBXM_777",Num=777,Name="Ball 2x2x2",Category="Blocks",Class="Part",Ctrl="None",BBox={2,2,2},OnTouch=nil,Parts={{1,{2,2,2},{0,1,0},nil,{221,45,45},false,"",nil,nil}},Joints={}},
	{Id="RBXM_780",Num=780,Name="Vertical Motor - Controllable",Category="Construction",Class="Part",Ctrl="KeyboardRight",BBox={4,1,4},OnTouch=nil,Parts={{2,{4,1,4},{0,0.5,0},{0,0,1,0,1,0,-1,0,0},{180,168,36},false,"B",nil,nil}},Joints={}},
	{Id="RBXM_781",Num=781,Name="Motorized Block Pair - Controllable",Category="Construction",Class="Model",Ctrl="KeyboardRight",BBox={4,2,4},OnTouch=nil,Parts={{2,{4,1,4},{0,1.5,0},{0,0,1,0,-1,0,1,0,0},{180,168,36},false,"B",nil,nil},{2,{4,1,4},{0,0.5,0},{0,0,1,0,1,0,-1,0,0},{180,168,36},false,"B",nil,nil}},Joints={{2,1,2,"RightTread",{0,1,0},{0,1,0}}}},
	{Id="RBXM_782",Num=782,Name="Motorized Block Pair - Controllable",Category="Construction",Class="Model",Ctrl="KeyboardRight",BBox={4,2,2},OnTouch=nil,Parts={{2,{2,2,2},{1,1,0},nil,{180,168,36},false,"TBF",nil,nil},{2,{2,2,2},{-1,1,0},nil,{180,168,36},false,"TBK",nil,nil}},Joints={{2,1,2,"RightTread",{1,0,0},{0,1,0}}}},
	{Id="RBXM_783",Num=783,Name="Constant Velocity Motor Pair",Category="Construction",Class="Model",Ctrl="None",BBox={4,2,4},OnTouch=nil,Parts={{2,{4,1,4},{0,1.5,0},{0,0,1,0,-1,0,1,0,0},{255,146,51},false,"B",nil,nil},{2,{4,1,4},{0,0.5,0},{0,0,1,0,1,0,-1,0,0},{255,146,51},false,"B",nil,nil}},Joints={{2,1,2,"Constant",{0,1,0},{0,1,0}}}},
	{Id="RBXM_784",Num=784,Name="Motorized Block - Controllable",Category="Construction",Class="Part",Ctrl="KeyboardRight",BBox={4,2,2},OnTouch=nil,Parts={{2,{2,2,4},{0,1,0},{0,0,1,0,1,0,-1,0,0},{180,168,36},false,"TB",nil,nil}},Joints={}},
	{Id="RBXM_788",Num=788,Name="Tree",Category="Buildings",Class="Model",Ctrl="None",BBox={10,18,10},OnTouch=nil,Parts={{2,{2,8,2},{0,4,0},{0,0,1,0,1,0,-1,0,0},{128,119,26},true,"TB",nil,nil},{1,{10,10,10},{0,13,0},nil,{50,180,34},false,"",nil,nil}},Joints={{0,1,2}}},
	{Id="RBXM_789",Num=789,Name="Chassis",Category="Vehicles",Class="Model",Ctrl="KeyboardRight",BBox={12,4,12},OnTouch=nil,Parts={{2,{4,1,12},{0,1.5,0},nil,{128,128,128},false,"T",nil,nil},{3,{4,4,4},{4,2,-4},nil,{76,76,76},false,"",nil,nil},{3,{4,4,4},{-4,2,-4},nil,{76,76,76},false,"",nil,nil},{3,{4,4,4},{4,2,4},nil,{76,76,76},false,"",nil,nil},{3,{4,4,4},{-4,2,4},nil,{76,76,76},false,"",nil,nil}},Joints={{2,1,2,"RightTread",{-1,0,0},{2,2,-4}},{2,1,3,"LeftTread",{1,0,0},{-2,2,-4}},{2,1,4,"RightTread",{-1,0,0},{2,2,4}},{2,1,5,"LeftTread",{1,0,0},{-2,2,4}}}},
	{Id="RBXM_794",Num=794,Name="Dog",Category="Robots",Class="Model",Ctrl="KeyboardRight",BBox={3,6,5},OnTouch=nil,Parts={{2,{4,2,1},{0,3,0.5},{0,0,-1,0,1,0,1,0,0},{178,102,76},false,"TB",nil,nil},{2,{1,2,1},{1,0.5,-1.5},{-1,0,0,0,0,-1,0,-1,0},{178,128,76},false,"TB",nil,nil},{2,{2,1,1},{0,4.5,-1.5},{0,0,-1,0,1,0,1,0,0},{178,102,76},false,"TB",nil,nil},{2,{1,2,1},{-1,0.5,-1.5},{-1,0,0,0,0,-1,0,-1,0},{178,128,76},false,"TB",nil,nil},{2,{1,1,1},{0,5.5,-1},{-1,0,0,0,1,0,0,0,-1},{178,102,76},false,"TB",nil,nil},{2,{1,2,1},{1,0.5,1.5},{-1,0,0,0,0,-1,0,-1,0},{178,128,76},false,"TB",nil,nil},{2,{1,3,1},{1,2.5,2},{-1,0,0,0,1,0,0,0,-1},{178,102,76},false,"TB",nil,nil},{2,{1,3,1},{-1,2.5,-1},nil,{178,102,76},false,"TB",nil,nil},{2,{1,2,1},{-1,0.5,1.5},{-1,0,0,0,0,-1,0,-1,0},{178,128,76},false,"TB",nil,nil},{2,{1,3,1},{-1,2.5,2},nil,{178,102,76},false,"TB",nil,nil},{2,{1,3,1},{1,2.5,-1},{-1,0,0,0,1,0,0,0,-1},{178,102,76},false,"TB",nil,nil}},Joints={{1,1,7,"NoInput",{-1,0,0},{0.5,2.5,2}},{1,1,8,"NoInput",{1,0,0},{-0.5,2.5,-1}},{1,1,10,"NoInput",{1,0,0},{-0.5,2.5,2}},{1,1,11,"NoInput",{-1,0,0},{0.5,2.5,-1}},{0,1,3},{0,2,11},{0,3,5},{0,4,8},{0,6,7},{0,9,10}}},
	{Id="RBXM_796",Num=796,Name="Skateboard",Category="Vehicles",Class="Model",Ctrl="KeyboardRight",BBox={6,2,7},OnTouch=nil,Parts={{3,{2,2,2},{2,1,2.5},nil,{178,178,178},false,"",nil,nil},{3,{2,2,2},{-2,1,-2.5},nil,{178,178,178},false,"",nil,nil},{3,{2,2,2},{2,1,-2.5},nil,{178,178,178},false,"",nil,nil},{3,{2,2,2},{-2,1,2.5},nil,{178,178,178},false,"",nil,nil},{2,{2,1,7},{0,1.5,0},nil,{178,128,76},false,"T",nil,nil}},Joints={{2,5,1,"RightTread",{-1,0,0},{1,1,2.5}},{2,5,2,"LeftTread",{1,0,0},{-1,1,-2.5}},{2,5,3,"RightTread",{-1,0,0},{1,1,-2.5}},{2,5,4,"LeftTread",{1,0,0},{-1,1,2.5}}}},
	{Id="RBXM_797",Num=797,Name="Skooter",Category="Vehicles",Class="Model",Ctrl="KeyboardRight",BBox={7,9,8},OnTouch=nil,Parts={{2,{3,1,8},{0,1.5,0},nil,{173,194,222},false,"T",nil,nil},{3,{2,2,2},{2.5,1,-3},nil,{178,178,178},false,"",nil,nil},{3,{2,2,2},{2.5,1,3},nil,{178,178,178},false,"",nil,nil},{3,{2,2,2},{-2.5,1,3},nil,{178,178,178},false,"",nil,nil},{3,{2,2,2},{-2.5,1,-3},nil,{178,178,178},false,"",nil,nil},{2,{1,1,6},{0,5,-3.5},{-1,0,0,0,0,-1,0,-1,0},{173,194,222},false,"LR",nil,nil},{2,{1,1,3},{0,8.5,-3.5},{0,0,-1,1,0,0,0,-1,0},{173,194,222},false,"LR",nil,nil}},Joints={{2,1,2,"RightTread",{-1,0,0},{1.5,1,-3}},{2,1,3,"RightTread",{-1,0,0},{1.5,1,3}},{2,1,4,"LeftTread",{1,0,0},{-1.5,1,3}},{2,1,5,"LeftTread",{1,0,0},{-1.5,1,-3}},{0,1,6},{0,6,7}}},
	{Id="RBXM_801",Num=801,Name="Bouncy Chassis",Category="Vehicles",Class="Model",Ctrl="KeyboardRight",BBox={10,4,17},OnTouch=nil,Parts={{2,{4,2,4},{-4,2,-4.5},{0,1,0,0,0,-1,-1,0,0},{76,76,76},false,"",nil,nil},{2,{4,2,4},{4,2,5.5},{0,1,0,0,0,-1,-1,0,0},{76,76,76},false,"",nil,nil},{2,{4,2,4},{4,2,-4.5},{0,1,0,0,0,-1,-1,0,0},{76,76,76},false,"",nil,nil},{3,{1,1,1},{1.5,1.5,-8},{0,0,1,0,1,0,-1,0,0},{204,204,204},false,"FK",nil,nil},{2,{6,1,16},{0,1.5,0.5},nil,{111,124,180},false,"T",nil,nil},{3,{1,1,1},{-1.5,1.5,-8},{0,0,1,0,1,0,-1,0,0},{204,204,204},false,"FK",nil,nil},{2,{4,2,4},{-4,2,5.5},{0,1,0,0,0,-1,-1,0,0},{76,76,76},false,"",nil,nil}},Joints={{2,5,1,"LeftTread",{1,0,0},{-3,2,-4.5}},{2,5,2,"RightTread",{-1,0,0},{3,2,5.5}},{2,5,3,"RightTread",{-1,0,0},{3,2,-4.5}},{2,5,7,"LeftTread",{1,0,0},{-3,2,5.5}},{0,4,5},{0,5,6}}},
	{Id="RBXM_802",Num=802,Name="Micro Chassis",Category="Vehicles",Class="Model",Ctrl="KeyboardRight",BBox={6,2,6},OnTouch=nil,Parts={{3,{2,2,2},{2,1,2},nil,{76,76,76},false,"",nil,nil},{3,{1,1,1},{0.5,1.5,-2.5},{0,0,1,0,1,0,-1,0,0},{204,204,204},false,"FK",nil,nil},{3,{2,2,2},{-2,1,-1},nil,{76,76,76},false,"",nil,nil},{3,{2,2,2},{2,1,-1},nil,{76,76,76},false,"",nil,nil},{3,{2,2,2},{-2,1,2},nil,{76,76,76},false,"",nil,nil},{2,{2,1,5},{0,1.5,0.5},nil,{121,36,180},false,"T",nil,nil},{3,{1,1,1},{-0.5,1.5,-2.5},{0,0,1,0,1,0,-1,0,0},{204,204,204},false,"FK",nil,nil}},Joints={{2,6,1,"RightTread",{-1,0,0},{1,1,2}},{2,6,3,"LeftTread",{1,0,0},{-1,1,-1}},{2,6,4,"RightTread",{-1,0,0},{1,1,-1}},{2,6,5,"LeftTread",{1,0,0},{-1,1,2}},{0,2,6},{0,6,7}}},
	{Id="RBXM_805",Num=805,Name="Truck Chassis",Category="Vehicles",Class="Model",Ctrl="KeyboardRight",BBox={10,5,21},OnTouch=nil,Parts={{3,{3,3,3},{3.5,1.5,9},nil,{76,76,76},false,"",nil,nil},{3,{3,3,3},{-3.5,1.5,9},nil,{76,76,76},false,"",nil,nil},{2,{2,3,4},{0,2.5,8.5},{0,0,1,0,1,0,-1,0,0},{128,128,128},false,"TB",nil,nil},{3,{3,3,3},{3.5,1.5,-2},nil,{76,76,76},false,"",nil,nil},{3,{1,1,1},{1.5,1.5,-10},{0,0,1,0,1,0,-1,0,0},{204,204,204},false,"FK",nil,nil},{3,{3,3,3},{-3.5,1.5,-8},nil,{76,76,76},false,"",nil,nil},{3,{3,3,3},{3.5,1.5,-8},nil,{76,76,76},false,"",nil,nil},{3,{3,3,3},{-3.5,1.5,-2},nil,{76,76,76},false,"",nil,nil},{2,{4,1,9},{0,1.5,-5},nil,{128,128,128},false,"T",nil,nil},{3,{1,1,1},{-1.5,1.5,-10},{0,0,1,0,1,0,-1,0,0},{204,204,204},false,"FK",nil,nil},{2,{4,2,3},{0,3,-2},nil,{178,76,178},false,"B",nil,nil},{2,{6,1,14},{0,4.5,3.5},nil,{128,128,128},false,"T",nil,nil}},Joints={{1,12,11,"NoInput",{0,1,0},{0,4,-2}},{1,3,1,"RightTread",{-1,0,0},{2,1.5,9}},{1,3,2,"LeftTread",{1,0,0},{-2,1.5,9}},{2,9,4,"RightTread",{-1,0,0},{2,1.5,-2}},{2,9,6,"LeftTread",{1,0,0},{-2,1.5,-8}},{2,9,7,"RightTread",{-1,0,0},{2,1.5,-8}},{2,9,8,"LeftTread",{1,0,0},{-2,1.5,-2}},{0,3,12},{0,5,9},{0,9,10},{0,9,11}}},
	{Id="RBXM_807",Num=807,Name="Tank Chassis",Category="Vehicles",Class="Model",Ctrl="KeyboardRight",BBox={8,4,13},OnTouch=nil,Parts={{2,{2,2,11},{0,2,0},nil,{128,128,128},false,"T",nil,nil},{3,{3,3,3},{-2.5,1.5,-2},nil,{29,105,20},false,"",nil,nil},{3,{3,3,3},{-2.5,2.5,5},nil,{29,105,20},false,"",nil,nil},{3,{3,3,3},{-2.5,2.5,-5},nil,{29,105,20},false,"",nil,nil},{3,{3,3,3},{2.5,1.5,2},nil,{29,105,20},false,"",nil,nil},{3,{3,3,3},{-2.5,1.5,2},nil,{29,105,20},false,"",nil,nil},{3,{3,3,3},{2.5,2.5,5},nil,{29,105,20},false,"",nil,nil},{3,{3,3,3},{2.5,1.5,-2},nil,{29,105,20},false,"",nil,nil},{3,{3,3,3},{2.5,2.5,-5},nil,{29,105,20},false,"",nil,nil}},Joints={{2,1,2,"LeftTread",{1,0,0},{-1,1.5,-2}},{2,1,5,"RightTread",{-1,0,0},{1,1.5,2}},{2,1,6,"LeftTread",{1,0,0},{-1,1.5,2}},{2,1,8,"RightTread",{-1,0,0},{1,1.5,-2}},{2,1,3,"LeftTread",{1,0,0},{-1,2.5,5}},{2,1,4,"LeftTread",{1,0,0},{-1,2.5,-5}},{2,1,7,"RightTread",{-1,0,0},{1,2.5,5}},{2,1,9,"RightTread",{-1,0,0},{1,2.5,-5}}}},
	{Id="RBXM_808",Num=808,Name="The Hammer",Category="Vehicles",Class="Model",Ctrl="KeyboardRight",BBox={18,23,17},OnTouch=nil,Parts={{2,{4,13,5},{0,10.5,0},nil,{255,238,51},false,"T",nil,nil},{1,{6,6,6},{0,20,0.5},nil,{178,26,26},false,"",nil,nil},{2,{2,2,7},{4,15,-3},nil,{0,0,0},false,"LR",nil,nil},{2,{2,4,2},{4,15,-7.5},nil,{42,75,215},false,"",nil,nil},{2,{4,4,1},{2.5,15,-0.5},{0,0,1,1,0,0,0,1,0},{76,76,76},false,"L",nil,nil},{2,{2,2,4},{-4,8,-0.5},nil,{42,75,215},false,"",nil,nil},{2,{4,4,1},{-2.5,15,-0.5},{0,0,-1,0,1,0,1,0,0},{76,76,76},false,"L",nil,nil},{2,{2,7,2},{-4,12.5,-0.5},nil,{0,0,0},false,"TB",nil,nil},{2,{6,1,6},{0,3.5,0.5},{0,0,-1,0,1,0,1,0,0},{128,128,128},false,"B",nil,nil},{3,{1,1,1},{1.5,2.5,-8},{0,0,1,0,1,0,-1,0,0},{204,204,204},false,"FK",nil,nil},{2,{6,1,16},{0,2.5,0.5},nil,{128,128,128},false,"T",nil,nil},{3,{1,1,1},{-1.5,2.5,-8},{0,0,1,0,1,0,-1,0,0},{204,204,204},false,"FK",nil,nil},{3,{6,6,6},{-6,3,5.5},nil,{76,76,76},false,"",nil,nil},{3,{6,6,6},{6,3,-4.5},nil,{76,76,76},false,"",nil,nil},{3,{6,6,6},{6,3,5.5},nil,{76,76,76},false,"",nil,nil},{3,{6,6,6},{-6,3,-4.5},nil,{76,76,76},false,"",nil,nil}},Joints={{2,1,9,"Throtle",{0,1,0},{0,4,0.5}},{2,1,5,"Steer",{-1,0,0},{2,15,-0.5}},{2,1,7,"Steer",{1,0,0},{-2,15,-0.5}},{2,11,13,"LeftTread",{1,0,0},{-3,3,5.5}},{2,11,14,"RightTread",{-1,0,0},{3,3,-4.5}},{2,11,15,"RightTread",{-1,0,0},{3,3,5.5}},{2,11,16,"LeftTread",{1,0,0},{-3,3,-4.5}},{0,1,2},{0,3,4},{0,3,5},{0,6,8},{0,7,8},{0,9,11},{0,10,11},{0,11,12}}},
	{Id="RBXM_809",Num=809,Name="Man on Scooter",Category="Vehicles",Class="Model",Ctrl="KeyboardRight",BBox={6,15,7},OnTouch=nil,Parts={{2,{2,3,3},{0,10.5,0},{-1,0,0,0,1,0,0,0,-1},{204,204,204},false,"TB",nil,nil},{2,{2,2,3},{0,8,0},{-1,0,0,0,1,0,0,0,-1},{102,204,230},false,"TB",nil,nil},{2,{1,2,1},{0,2.5,1},{0,1,0,0,0,-1,-1,0,0},{76,76,76},false,"TB",nil,nil},{2,{1,4,1},{-0.5,11,-2},{0,0,1,0,1,0,-1,0,0},{204,204,204},false,"TB",nil,nil},{2,{1,4,1},{-0.5,5,-1},{0,0,1,0,1,0,-1,0,0},{102,204,230},false,"TB",nil,nil},{2,{1,2,1},{0,2.5,-1},{0,1,0,0,0,-1,-1,0,0},{76,76,76},false,"TB",nil,nil},{2,{1,4,1},{-0.5,5,1},{0,0,1,0,1,0,-1,0,0},{102,204,230},false,"TB",nil,nil},{2,{1,4,1},{-0.5,11,2},{0,0,1,0,1,0,-1,0,0},{204,204,204},false,"TB",nil,nil},{3,{2,2,2},{0,14,-0.5},{0,1,0,-1,0,0,0,0,1},{204,204,76},false,"",nil,nil},{2,{2,1,3},{0,12.5,0},{-1,0,0,0,1,0,0,0,-1},{204,204,204},false,"TB",nil,nil},{3,{2,2,2},{2,1,2.5},nil,{178,178,178},false,"",nil,nil},{3,{2,2,2},{-2,1,-2.5},nil,{178,178,178},false,"",nil,nil},{3,{2,2,2},{2,1,-2.5},nil,{178,178,178},false,"",nil,nil},{3,{2,2,2},{-2,1,2.5},nil,{178,178,178},false,"",nil,nil},{2,{2,1,7},{0,1.5,0},nil,{178,128,76},false,"T",nil,nil}},Joints={{2,15,11,"RightTread",{-1,0,0},{1,1,2.5}},{2,15,12,"LeftTread",{1,0,0},{-1,1,-2.5}},{2,15,13,"RightTread",{-1,0,0},{1,1,-2.5}},{2,15,14,"LeftTread",{1,0,0},{-1,1,2.5}},{1,4,10,"NoInput",{0,0,-1},{0,12.5,-1.5}},{1,8,10,"NoInput",{0,0,1},{0,12.5,1.5}},{0,1,2},{0,1,10},{0,2,5},{0,2,7},{0,3,7},{0,3,15},{0,5,6},{0,6,15},{0,9,10}}},
	{Id="RBXM_810",Num=810,Name="Blue Figure on Scooter",Category="Vehicles",Class="Model",Ctrl="KeyboardRight",BBox={6,8,7},OnTouch=nil,Parts={{1,{2,2,2},{0,7,0.5},{0,0,-1,0,1,0,1,0,0},{255,255,0},false,"",nil,"Head"},{2,{2,1,1},{-0.5,5.5,0.5},{0,0,-1,0,1,0,1,0,0},{0,0,255},false,"TB",nil,"UpperBody"},{2,{2,1,1},{-0.5,4.5,0.5},{0,0,-1,0,1,0,1,0,0},{178,178,178},false,"TB",nil,"LowerBody"},{2,{1,2,1},{-0.5,5,2},{0,0,-1,0,1,0,1,0,0},{255,255,0},false,"",nil,"RightArm"},{2,{1,2,1},{-0.5,5,-1},{0,0,-1,0,1,0,1,0,0},{255,255,0},false,"",nil,"LeftArm"},{2,{1,2,1},{-0.5,3,1},{0,0,-1,0,1,0,1,0,0},{0,0,255},false,"B",nil,"RightLeg"},{2,{1,2,1},{-0.5,3,0},{0,0,-1,0,1,0,1,0,0},{0,0,255},false,"B",nil,"LeftLeg"},{3,{2,2,2},{2,1,2.5},nil,{178,178,178},false,"",nil,nil},{3,{2,2,2},{-2,1,-2.5},nil,{178,178,178},false,"",nil,nil},{3,{2,2,2},{2,1,-2.5},nil,{178,178,178},false,"",nil,nil},{3,{2,2,2},{-2,1,2.5},nil,{178,178,178},false,"",nil,nil},{2,{2,1,7},{0,1.5,0},nil,{178,128,76},false,"T",nil,nil}},Joints={{2,12,8,"RightTread",{-1,0,0},{1,1,2.5}},{2,12,9,"LeftTread",{1,0,0},{-1,1,-2.5}},{2,12,10,"RightTread",{-1,0,0},{1,1,-2.5}},{2,12,11,"LeftTread",{1,0,0},{-1,1,2.5}},{1,4,2,"NoInput",{0,0,1},{-0.5,5.5,1.5}},{1,5,2,"NoInput",{0,0,-1},{-0.5,5.5,-0.5}},{0,1,2},{0,2,3},{0,3,6},{0,3,7},{0,6,12},{0,7,12}}},
	{Id="RBXM_813",Num=813,Name="Elevated Ramp",Category="Construction",Class="Model",Ctrl="None",BBox={16,6,22},OnTouch=nil,Parts={{2,{2,6,2},{7,3,-10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil},{2,{1,22,12},{0,4.5,0},{0,0,1,1,0,0,0,1,0},{128,128,128},true,"",nil,nil},{2,{2,6,2},{-7,3,10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil},{2,{2,6,2},{7,3,10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil},{2,{2,6,2},{-7,3,-10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil}},Joints={{0,1,2},{0,2,3},{0,2,4},{0,2,5}}},
	{Id="RBXM_814",Num=814,Name="Tilted Ramp",Category="Construction",Class="Model",Ctrl="None",BBox={16,6,22},OnTouch=nil,Parts={{2,{2,4,1},{7.5,2,-10},{0,0,-1,0,-1,0,-1,0,0},{204,204,204},true,"",nil,nil},{2,{1,22,12},{0,4.5,0},{0,0,1,1,0,0,0,1,0},{128,128,128},false,"",nil,nil},{2,{2,2,2},{7,5,-10},{0,0,-1,0,-1,0,-1,0,0},{204,204,204},true,"",nil,nil},{2,{2,4,1},{-7.5,2,-10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil},{2,{2,2,2},{-7,5,-10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil}},Joints={{1,2,3,"NoInput",{-1,0,0},{6,5,-10}},{1,2,5,"NoInput",{1,0,0},{-6,5,-10}},{0,1,3},{0,4,5}}},
	{Id="RBXM_818",Num=818,Name="Rotating Barrier",Category="Construction",Class="Model",Ctrl="None",BBox={2,13,16},OnTouch=nil,Parts={{2,{12,1,12},{-0.5,7,0},{0,1,0,1,0,0,0,0,-1},{128,128,128},false,"",nil,nil},{2,{2,6,1},{0,3,-7.5},{-1,0,0,0,-1,0,0,0,1},{204,204,204},true,"",nil,nil},{2,{2,2,2},{0,7,-7},{-1,0,0,0,-1,0,0,0,1},{204,204,204},true,"",nil,nil},{2,{2,6,1},{0,3,7.5},{1,0,0,0,-1,0,0,0,-1},{204,204,204},true,"",nil,nil},{2,{2,2,2},{0,7,7},{1,0,0,0,-1,0,0,0,-1},{204,204,204},true,"",nil,nil}},Joints={{1,1,3,"NoInput",{0,0,1},{0,7,-6}},{2,1,5,"Sin",{0,0,-1},{0,7,6}},{0,2,3},{0,4,5}}},
	{Id="RBXM_819",Num=819,Name="Push Through Barrier",Category="Construction",Class="Model",Ctrl="None",BBox={2,8,16},OnTouch=nil,Parts={{2,{7,1,12},{-0.5,4.5,0},{0,1,0,1,0,0,0,0,-1},{128,128,128},false,"",nil,nil},{2,{2,6,1},{0,3,-7.5},{-1,0,0,0,-1,0,0,0,1},{204,204,204},true,"",nil,nil},{2,{2,2,2},{0,7,-7},{-1,0,0,0,-1,0,0,0,1},{204,204,204},true,"",nil,nil},{2,{2,6,1},{0,3,7.5},{1,0,0,0,-1,0,0,0,-1},{204,204,204},true,"",nil,nil},{2,{2,2,2},{0,7,7},{1,0,0,0,-1,0,0,0,-1},{204,204,204},true,"",nil,nil}},Joints={{1,1,3,"NoInput",{0,0,1},{0,7,-6}},{1,1,5,"NoInput",{0,0,-1},{0,7,6}},{0,2,3},{0,4,5}}},
	{Id="RBXM_820",Num=820,Name="100 Point Arch",Category="Buildings",Class="Model",Ctrl="None",Label="100 Points",BBox={2,10,20},OnTouch={Action="Nothing",Score=100,Timer=0,Sound="Ping"},Parts={{2,{2,9,2},{0,4.5,-9},{0,0,1,0,-1,0,1,0,0},{221,221,221},true,"",nil,nil},{2,{16,9,2},{0,4.5,0},{0,0,1,0,-1,0,1,0,0},{128,128,128},true,"",nil,nil},{2,{2,9,2},{0,4.5,9},{0,0,1,0,-1,0,1,0,0},{221,221,221},true,"",nil,nil},{2,{2,1,20},{0,9.5,0},{-1,0,0,0,1,0,0,0,-1},{221,221,221},true,"",nil,nil}},Joints={{0,1,2},{0,1,4},{0,2,3},{0,2,4},{0,3,4}}},
	{Id="RBXM_825",Num=825,Name="House",Category="Buildings",Class="Model",Ctrl="None",BBox={17,14,21},OnTouch=nil,Parts={{2,{17,1,21},{0,10.5,0},{-1,0,0,0,1,0,0,0,-1},{76,76,76},true,"",nil,nil},{2,{17,1,9},{0,12.5,0},{-1,0,0,0,1,0,0,0,-1},{76,76,76},true,"",nil,nil},{2,{17,1,3},{0,13.5,0},{-1,0,0,0,1,0,0,0,-1},{76,76,76},true,"",nil,nil},{2,{15,10,1},{-8,5,0},{0,0,-1,0,1,0,1,0,0},{204,204,204},true,"",nil,nil},{2,{15,3,1},{8,8.5,0},{0,0,-1,0,1,0,1,0,0},{204,204,204},true,"",nil,nil},{2,{15,10,1},{0,5,-7},{-1,0,0,0,1,0,0,0,-1},{204,204,204},true,"",nil,nil},{2,{1,7,5},{8,3.5,5},{-1,0,0,0,1,0,0,0,-1},{41,208,208},true,"",nil,nil},{2,{15,10,1},{0,5,7},{-1,0,0,0,1,0,0,0,-1},{204,204,204},true,"",nil,nil},{2,{1,7,5},{8,3.5,-5},{-1,0,0,0,1,0,0,0,-1},{41,208,208},true,"",nil,nil},{2,{17,1,15},{0,11.5,0},{-1,0,0,0,1,0,0,0,-1},{76,76,76},true,"",nil,nil}},Joints={{0,1,4},{0,1,5},{0,1,6},{0,1,8},{0,1,10},{0,2,3},{0,2,10},{0,4,6},{0,4,8},{0,5,6},{0,5,7},{0,5,8},{0,5,9},{0,6,9},{0,7,8}}},
	{Id="RBXM_826",Num=826,Name="Building",Category="Buildings",Class="Model",Ctrl="None",BBox={23,24,22},OnTouch=nil,Parts={{2,{2,6,2},{10.5,3,10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil},{2,{2,6,2},{10.5,3,-10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil},{2,{1,22,19},{0,5.5,0},{0,0,1,1,0,0,0,1,0},{128,128,128},true,"",nil,nil},{2,{2,6,2},{-10.5,3,-10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil},{2,{2,6,2},{-10.5,3,10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil},{2,{2,6,2},{10.5,9,10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil},{2,{2,6,2},{10.5,9,-10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil},{2,{1,22,19},{0,11.5,0},{0,0,1,1,0,0,0,1,0},{128,128,128},true,"",nil,nil},{2,{2,6,2},{-10.5,9,-10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil},{2,{2,6,2},{-10.5,9,10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil},{2,{2,6,2},{10.5,15,10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil},{2,{2,6,2},{10.5,15,-10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil},{2,{1,22,19},{0,17.5,0},{0,0,1,1,0,0,0,1,0},{128,128,128},true,"",nil,nil},{2,{2,6,2},{-10.5,15,-10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil},{2,{2,6,2},{-10.5,15,10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil},{2,{2,6,2},{10.5,21,10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil},{2,{2,6,2},{10.5,21,-10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil},{2,{1,22,19},{0,23.5,0},{0,0,1,1,0,0,0,1,0},{128,128,128},true,"",nil,nil},{2,{2,6,2},{-10.5,21,-10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil},{2,{2,6,2},{-10.5,21,10},{0,0,1,0,-1,0,1,0,0},{204,204,204},true,"",nil,nil}},Joints={{0,1,3},{0,1,6},{0,2,3},{0,2,7},{0,3,4},{0,3,5},{0,4,9},{0,5,10},{0,6,8},{0,6,11},{0,7,8},{0,7,12},{0,8,9},{0,8,10},{0,9,14},{0,10,15},{0,11,13},{0,11,16},{0,12,13},{0,12,17},{0,13,14},{0,13,15},{0,14,19},{0,15,20},{0,16,18},{0,17,18},{0,18,19},{0,18,20}}},
	{Id="RBXM_827",Num=827,Name="Chassis with Figure",Category="Vehicles",Class="Model",Ctrl="KeyboardRight",BBox={12,7,12},OnTouch=nil,Parts={{1,{2,2,2},{0,6,1},nil,{255,255,0},false,"",nil,"Head"},{2,{2,1,1},{0,4.5,1.5},nil,{0,0,255},false,"TB",nil,"UpperBody"},{2,{2,1,1},{0,3.5,1.5},nil,{178,178,178},false,"TB",nil,"LowerBody"},{2,{1,2,1},{1.5,4,1.5},nil,{255,255,0},false,"",nil,"RightArm"},{2,{1,2,1},{-1.5,4,1.5},nil,{255,255,0},false,"",nil,"LeftArm"},{2,{1,2,1},{0.5,2.5,1},{1,0,0,0,0,-1,0,1,0},{0,0,255},false,"B",nil,"RightLeg"},{2,{1,2,1},{-0.5,2.5,1},{1,0,0,0,0,-1,0,1,0},{0,0,255},false,"B",nil,"LeftLeg"},{2,{4,1,12},{0,1.5,0},nil,{128,128,128},false,"T",nil,nil},{3,{4,4,4},{4,2,-4},nil,{76,76,76},false,"",nil,nil},{3,{4,4,4},{-4,2,-4},nil,{76,76,76},false,"",nil,nil},{3,{4,4,4},{4,2,4},nil,{76,76,76},false,"",nil,nil},{3,{4,4,4},{-4,2,4},nil,{76,76,76},false,"",nil,nil}},Joints={{2,8,9,"RightTread",{-1,0,0},{2,2,-4}},{2,8,10,"LeftTread",{1,0,0},{-2,2,-4}},{2,8,11,"RightTread",{-1,0,0},{2,2,4}},{2,8,12,"LeftTread",{1,0,0},{-2,2,4}},{1,4,2,"NoInput",{1,0,0},{1,4.5,1.5}},{1,5,2,"NoInput",{-1,0,0},{-1,4.5,1.5}},{0,1,2},{0,2,3},{0,3,6},{0,3,7},{0,6,8},{0,7,8}}},
	{Id="RBXM_828",Num=828,Name="Spasmotron",Category="Robots",Class="Model",Ctrl="KeyboardRight",BBox={12,9,19},OnTouch=nil,Parts={{2,{4,1,12},{0,1.5,-3.5},nil,{128,128,128},false,"T",nil,nil},{3,{4,4,4},{4,2,-7.5},nil,{76,76,76},false,"",nil,nil},{3,{4,4,4},{-4,2,-7.5},nil,{76,76,76},false,"",nil,nil},{3,{4,4,4},{4,2,0.5},nil,{76,76,76},false,"",nil,nil},{3,{4,4,4},{-4,2,0.5},nil,{76,76,76},false,"",nil,nil},{2,{4,1,4},{0,3.5,-3.5},nil,{128,128,230},false,"TB",nil,nil},{2,{4,1,4},{0,4.5,-3.5},nil,{128,128,230},false,"TB",nil,nil},{2,{4,1,4},{0,2.5,-3.5},nil,{128,128,230},false,"TB",nil,nil},{2,{4,1,4},{0,7.5,-3.5},nil,{128,128,128},false,"B",nil,nil},{2,{2,1,15},{0,8.5,2},nil,{153,51,26},false,"",nil,nil},{2,{4,1,4},{0,5.5,-3.5},nil,{128,128,128},false,"B",nil,nil},{2,{2,1,15},{0,6.5,2},nil,{153,51,26},false,"",nil,nil}},Joints={{2,10,9,"Constant",{0,1,0},{0,8,-3.5}},{2,12,11,"Constant",{0,1,0},{0,6,-3.5}},{2,1,2,"RightTread",{-1,0,0},{2,2,-7.5}},{2,1,3,"LeftTread",{1,0,0},{-2,2,-7.5}},{2,1,4,"RightTread",{-1,0,0},{2,2,0.5}},{2,1,5,"LeftTread",{1,0,0},{-2,2,0.5}},{0,7,9},{0,1,8},{0,6,7},{0,6,8},{0,7,11}}},
	{Id="RBXM_829",Num=829,Name="Wimpotron",Category="Robots",Class="Model",Ctrl="KeyboardRight",BBox={12,16,28},OnTouch=nil,Parts={{2,{4,1,12},{0,1.5,0},nil,{128,128,128},false,"T",nil,nil},{3,{4,4,4},{4,2,-4},nil,{76,76,76},false,"",nil,nil},{3,{4,4,4},{-4,2,-4},nil,{76,76,76},false,"",nil,nil},{3,{4,4,4},{4,2,4},nil,{76,76,76},false,"",nil,nil},{3,{4,4,4},{-4,2,4},nil,{76,76,76},false,"",nil,nil},{2,{2,1,20},{0,12.5,0},nil,{128,128,128},false,"TB",nil,nil},{2,{2,10,2},{0,7,4},{-1,0,0,0,1,0,0,0,-1},{178,178,178},false,"TB",nil,nil},{2,{2,1,4},{0,13.5,0},{-1,0,0,0,1,0,0,0,-1},{128,128,128},false,"TB",nil,nil},{2,{2,1,4},{0,14.5,0},{-1,0,0,0,1,0,0,0,-1},{128,128,128},false,"TB",nil,nil},{2,{2,1,20},{0,15.5,0},nil,{128,128,128},false,"TB",nil,nil},{2,{2,10,2},{0,7,-5},{-1,0,0,0,1,0,0,0,-1},{178,178,178},false,"TB",nil,nil},{2,{2,2,2},{-1,14,5},{-1,0,0,0,1,0,0,0,-1},{128,128,128},false,"TB",nil,nil},{2,{2,18,2},{-3,14,5},{0,0,-1,-1,0,0,0,1,0},{255,179,128},false,"TB",nil,nil},{2,{2,2,2},{1,14,-5},nil,{128,128,128},false,"TB",nil,nil},{2,{2,18,2},{3,14,-5},{0,0,1,-1,0,0,0,-1,0},{255,179,128},false,"TB",nil,nil}},Joints={{2,13,12,"Constant",{-1,0,0},{-2,14,5}},{2,15,14,"Constant",{1,0,0},{2,14,-5}},{2,1,2,"RightTread",{-1,0,0},{2,2,-4}},{2,1,3,"LeftTread",{1,0,0},{-2,2,-4}},{2,1,4,"RightTread",{-1,0,0},{2,2,4}},{2,1,5,"LeftTread",{1,0,0},{-2,2,4}},{0,1,7},{0,1,11},{0,6,7},{0,6,8},{0,6,11},{0,6,12},{0,6,14},{0,8,9},{0,9,10},{0,10,12},{0,10,14}}},
	{Id="RBXM_830",Num=830,Name="Micro-troublemaker",Category="Robots",Class="Model",Ctrl="KeyboardRight",BBox={2,1,8},OnTouch=nil,Parts={{2,{1,6,1},{-0.5,0.5,-1},{0,0,1,-1,0,0,0,-1,0},{51,51,51},false,"TB",nil,nil},{2,{1,6,1},{0.5,0.5,1},{-1,0,0,0,0,-1,0,-1,0},{204,204,0},false,"TB",nil,nil}},Joints={{2,1,2,"Constant",{-1,0,0},{0,0.5,1}}}},
	{Id="RBXM_832",Num=832,Name="Attacking Bug",Category="Robots",Class="Model",Ctrl="Chase",BBox={6,2,6},OnTouch=nil,Parts={{3,{1,1,1},{0.5,1.5,-2.5},{0,0,1,0,1,0,-1,0,0},{204,204,204},false,"FK",nil,nil},{3,{2,2,2},{-2,1,2},nil,{76,76,76},false,"",nil,nil},{3,{2,2,2},{-2,1,-1},nil,{76,76,76},false,"",nil,nil},{2,{2,1,5},{0,1.5,0.5},nil,{87,87,87},false,"T",nil,nil},{3,{1,1,1},{-0.5,1.5,-2.5},{0,0,1,0,1,0,-1,0,0},{204,204,204},false,"FK",nil,nil},{3,{2,2,2},{2,1,2},nil,{76,76,76},false,"",nil,nil},{3,{2,2,2},{2,1,-1},nil,{76,76,76},false,"",nil,nil}},Joints={{2,4,2,"LeftTread",{1,0,0},{-1,1,2}},{2,4,3,"LeftTread",{1,0,0},{-1,1,-1}},{2,4,6,"RightTread",{-1,0,0},{1,1,2}},{2,4,7,"RightTread",{-1,0,0},{1,1,-1}},{0,1,4},{0,4,5}}},
	{Id="RBXM_833",Num=833,Name="Fleeing Bug",Category="Robots",Class="Model",Ctrl="Flee",BBox={6,2,6},OnTouch=nil,Parts={{3,{1,1,1},{0.5,1.5,-2.5},{0,0,1,0,1,0,-1,0,0},{204,204,204},false,"FK",nil,nil},{3,{2,2,2},{-2,1,2},nil,{76,76,76},false,"",nil,nil},{3,{2,2,2},{-2,1,-1},nil,{76,76,76},false,"",nil,nil},{2,{2,1,5},{0,1.5,0.5},nil,{221,206,44},false,"T",nil,nil},{3,{1,1,1},{-0.5,1.5,-2.5},{0,0,1,0,1,0,-1,0,0},{204,204,204},false,"FK",nil,nil},{3,{2,2,2},{2,1,2},nil,{76,76,76},false,"",nil,nil},{3,{2,2,2},{2,1,-1},nil,{76,76,76},false,"",nil,nil}},Joints={{2,4,2,"LeftTread",{1,0,0},{-1,1,2}},{2,4,3,"LeftTread",{1,0,0},{-1,1,-1}},{2,4,6,"RightTread",{-1,0,0},{1,1,2}},{2,4,7,"RightTread",{-1,0,0},{1,1,-1}},{0,1,4},{0,4,5}}},
	{Id="RBXM_843",Num=843,Name="25 Point flag",Category="Buildings",Class="Model",Ctrl="None",BBox={1,4,3},OnTouch={Action="Nothing",Score=25,Timer=0,Sound="Ping"},Parts={{2,{1,4,1},{0,2,1},nil,{0,0,255},true,"TB",nil,nil},{2,{1,2,2},{0,3,-0.5},nil,{255,0,0},true,"L",nil,nil}},Joints={{0,1,2}}},
	{Id="RBXM_851",Num=851,Name="Electron Canon - Mounted",Category="Weapons",Class="Model",Ctrl="None",BBox={2,10,6},OnTouch=nil,Parts={{3,{2,2,2},{0,9,-2},{0,0,-1,0,1,0,1,0,0},{204,204,204},false,"TBFKLR",nil,nil},{1,{2,2,2},{0,9,2},{0,0,1,0,1,0,-1,0,0},{178,153,76},false,"",{-200,0,0},nil},{2,{2,8,2},{0,4,-2},{-1,0,0,0,1,0,0,0,-1},{204,204,204},false,"TB",nil,nil},{3,{2,2,2},{0,9,0},{0,0,-1,0,1,0,1,0,0},{204,204,204},false,"TBKLR",nil,nil}},Joints={{0,1,3},{0,1,4}}},
	{Id="RBXM_852",Num=852,Name="Electron Cannon",Category="Weapons",Class="Model",Ctrl="None",BBox={2,2,6},OnTouch=nil,Parts={{3,{2,2,2},{0,1,-2},{0,0,-1,0,1,0,1,0,0},{204,204,204},false,"TBFKLR",nil,nil},{1,{2,2,2},{0,1,2},{0,0,1,0,1,0,-1,0,0},{178,153,76},false,"",{-200,0,0},nil},{3,{2,2,2},{0,1,0},{0,0,-1,0,1,0,1,0,0},{204,204,204},false,"TBKLR",nil,nil}},Joints={{0,1,3}}},
	{Id="RBXM_853",Num=853,Name="Fragment Bomb",Category="Weapons",Class="Model",Ctrl="KeyboardRight",BBox={6,6,6},OnTouch=nil,Parts={{2,{6,1,6},{0,5.5,0},{0,0,-1,0,-1,0,-1,0,0},{128,128,128},false,"TBFKLR",nil,nil},{2,{4,1,4},{0,1.5,0},{0,0,1,0,1,0,-1,0,0},{230,230,230},false,"",nil,nil},{2,{6,1,6},{0,0.5,0},{0,0,1,0,1,0,-1,0,0},{128,128,128},false,"B",nil,nil},{2,{2,1,2},{2.5,2,-1},{0,1,0,0,0,-1,-1,0,0},{128,128,128},false,"TBFKLR",nil,nil},{2,{2,1,2},{2.5,4,-1},{0,1,0,0,0,-1,-1,0,0},{128,128,128},false,"TBFKLR",nil,nil},{2,{2,1,2},{-2.5,2,-1},{0,1,0,0,0,-1,-1,0,0},{128,128,128},false,"TBFKLR",nil,nil},{2,{2,1,2},{-2.5,4,-1},{0,1,0,0,0,-1,-1,0,0},{128,128,128},false,"TBFKLR",nil,nil},{2,{2,1,2},{-2.5,2,1},{0,1,0,0,0,-1,-1,0,0},{128,128,128},false,"TBFKLR",nil,nil},{2,{2,1,2},{-2.5,4,1},{0,1,0,0,0,-1,-1,0,0},{128,128,128},false,"TBFKLR",nil,nil},{2,{2,1,2},{0,2,-2.5},{-1,0,0,0,0,-1,0,-1,0},{128,128,128},false,"TBFKLR",nil,nil},{2,{2,1,2},{0,4,-2.5},{-1,0,0,0,0,-1,0,-1,0},{128,128,128},false,"TBFKLR",nil,nil},{2,{2,1,2},{2,2,-2.5},{-1,0,0,0,0,-1,0,-1,0},{128,128,128},false,"TBFKLR",nil,nil},{2,{2,1,2},{2,4,-2.5},{-1,0,0,0,0,-1,0,-1,0},{128,128,128},false,"TBFKLR",nil,nil},{2,{2,1,2},{2.5,2,1},{0,1,0,0,0,-1,-1,0,0},{128,128,128},false,"TBFKLR",nil,nil},{2,{2,1,2},{2.5,4,1},{0,1,0,0,0,-1,-1,0,0},{128,128,128},false,"TBFKLR",nil,nil},{2,{2,1,2},{2,2,2.5},{-1,0,0,0,0,-1,0,-1,0},{128,128,128},false,"TBFKLR",nil,nil},{2,{2,1,2},{2,4,2.5},{-1,0,0,0,0,-1,0,-1,0},{128,128,128},false,"TBFKLR",nil,nil},{2,{2,1,2},{-2,2,-2.5},{-1,0,0,0,0,-1,0,-1,0},{128,128,128},false,"TBFKLR",nil,nil},{2,{2,1,2},{-2,4,-2.5},{-1,0,0,0,0,-1,0,-1,0},{128,128,128},false,"TBFKLR",nil,nil},{2,{2,1,2},{-2,2,2.5},{-1,0,0,0,0,-1,0,-1,0},{128,128,128},false,"TBFKLR",nil,nil},{2,{2,1,2},{-2,4,2.5},{-1,0,0,0,0,-1,0,-1,0},{128,128,128},false,"TBFKLR",nil,nil},{2,{2,1,2},{0,2,2.5},{-1,0,0,0,0,-1,0,-1,0},{128,128,128},false,"TBFKLR",nil,nil},{2,{2,1,2},{0,4,2.5},{-1,0,0,0,0,-1,0,-1,0},{128,128,128},false,"TBFKLR",nil,nil}},Joints={{2,2,3,"Constant",{0,1,0},{0,1,0}},{2,5,1,"Constant",{0,-1,0},{0,5,0}},{2,7,1,"Constant",{0,-1,0},{0,5,0}},{2,9,1,"Constant",{0,-1,0},{0,5,0}},{2,11,1,"Constant",{0,-1,0},{0,5,0}},{2,13,1,"Constant",{0,-1,0},{0,5,0}},{2,15,1,"Constant",{0,-1,0},{0,5,0}},{2,17,1,"Constant",{0,-1,0},{0,5,0}},{2,19,1,"Constant",{0,-1,0},{0,5,0}},{2,21,1,"Constant",{0,-1,0},{0,5,0}},{2,23,1,"Constant",{0,-1,0},{0,5,0}},{2,4,3,"Constant",{0,1,0},{0,1,0}},{2,6,3,"Constant",{0,1,0},{0,1,0}},{2,8,3,"Constant",{0,1,0},{0,1,0}},{2,10,3,"Constant",{0,1,0},{0,1,0}},{2,12,3,"Constant",{0,1,0},{0,1,0}},{2,14,3,"Constant",{0,1,0},{0,1,0}},{2,16,3,"Constant",{0,1,0},{0,1,0}},{2,18,3,"Constant",{0,1,0},{0,1,0}},{2,20,3,"Constant",{0,1,0},{0,1,0}},{2,22,3,"Constant",{0,1,0},{0,1,0}},{0,4,5},{0,6,7},{0,8,9},{0,10,11},{0,12,13},{0,14,15},{0,16,17},{0,18,19},{0,20,21},{0,22,23},{0,1,2},{0,2,3}}},
	{Id="RBXM_854",Num=854,Name="Crazy Railroad Gate",Category="Construction",Class="Model",Ctrl="KeyboardRight",BBox={8,12,32},OnTouch=nil,Parts={{2,{4,4,4},{0,10,0},nil,{128,128,128},false,"TB",nil,nil},{2,{2,18,2},{-3,11,7},{0,0,1,-1,0,0,0,-1,0},{204,204,0},false,"TB",nil,nil},{2,{4,8,4},{0,4,0},nil,{128,128,128},false,"TB",nil,nil},{2,{2,18,2},{3,11,-7},{0,0,1,-1,0,0,0,-1,0},{204,204,0},false,"TB",nil,nil}},Joints={{3,2,1,"Sin",{-1,0,0},{-2,10,0}},{3,4,1,"Sin",{1,0,0},{2,10,0}},{0,1,3}}},
	{Id="RBXM_855",Num=855,Name="Spinner",Category="Construction",Class="Model",Ctrl="KeyboardRight",BBox={16,5,16},OnTouch=nil,Parts={{3,{1,1,1},{2.5,3.5,2.5},{0,0,1,-1,0,0,0,-1,0},{178,0,178},false,"",nil,nil},{2,{1,1,6},{5,4.5,2.5},{0,0,1,0,1,0,-1,0,0},{204,0,0},false,"",nil,nil},{2,{6,1,6},{0,2.5,0},{0,0,1,0,1,0,-1,0,0},{128,128,128},false,"TB",nil,nil},{3,{2,2,2},{0,1,0},{0,1,0,-1,0,0,0,0,1},{76,76,76},false,"",nil,nil},{3,{1,1,1},{-2.5,3.5,2.5},{0,1,0,-1,0,0,0,0,1},{178,0,178},false,"",nil,nil},{2,{1,1,6},{-2.5,4.5,5},nil,{204,0,0},false,"",nil,nil},{3,{1,1,1},{-2.5,3.5,-2.5},{0,0,-1,-1,0,0,0,1,0},{178,0,178},false,"",nil,nil},{2,{1,1,6},{-5,4.5,-2.5},{0,0,-1,0,1,0,1,0,0},{204,0,0},false,"",nil,nil},{3,{1,1,1},{2.5,3.5,-2.5},{0,-1,0,-1,0,0,0,0,-1},{178,0,178},false,"",nil,nil},{2,{1,1,6},{2.5,4.5,-5},{-1,0,0,0,1,0,0,0,-1},{204,0,0},false,"",nil,nil}},Joints={{2,3,4,"Constant",{0,1,0},{0,2,0}},{1,3,1,"NoInput",{0,-1,0},{2.5,3,2.5}},{1,3,5,"NoInput",{0,-1,0},{-2.5,3,2.5}},{1,3,7,"NoInput",{0,-1,0},{-2.5,3,-2.5}},{1,3,9,"NoInput",{0,-1,0},{2.5,3,-2.5}},{1,2,1,"NoInput",{0,1,0},{2.5,4,2.5}},{1,6,5,"NoInput",{0,1,0},{-2.5,4,2.5}},{1,8,7,"NoInput",{0,1,0},{-2.5,4,-2.5}},{1,10,9,"NoInput",{0,1,0},{2.5,4,-2.5}}}},
	{Id="RBXM_856",Num=856,Name="Rotating Obstacle",Category="Construction",Class="Model",Ctrl="KeyboardRight",BBox={6,3,20},OnTouch=nil,Parts={{2,{2,1,4},{0,2.5,-9},{0,0,1,0,1,0,-1,0,0},{128,128,128},false,"TB",nil,nil},{2,{2,1,20},{0,1.5,0},nil,{153,51,26},false,"",nil,nil},{2,{6,1,6},{0,0.5,0},nil,{128,128,128},false,"B",nil,nil},{2,{2,1,4},{0,2.5,9},{0,0,1,0,1,0,-1,0,0},{128,128,128},false,"TB",nil,nil}},Joints={{3,2,3,"Sin",{0,1,0},{0,1,0}},{0,1,2},{0,2,4}}},
	{Id="RBXM_857",Num=857,Name="Windmill Obstacle - Anchored",Category="Construction",Class="Model",Ctrl="None",BBox={2,12,20},OnTouch=nil,Parts={{2,{2,9,2},{0,4.5,9},nil,{128,128,128},true,"TB",nil,nil},{2,{2,1,20},{0,9.5,0},nil,{128,128,128},true,"TB",nil,nil},{2,{2,2,2},{0,11,0},nil,{128,128,128},true,"TB",nil,nil},{2,{2,9,2},{0,4.5,-9},nil,{128,128,128},true,"TB",nil,nil}},Joints={{0,1,2},{0,2,3},{0,2,4}}},
	{Id="RBXM_858",Num=858,Name="5 Second Jewel",Category="Buildings",Class="Part",Ctrl="None",Label="5 sec",BBox={2,2,2},OnTouch={Action="Nothing",Score=0,Timer=5,Sound="Clock"},Parts={{1,{2,2,2},{0,1,0},nil,{0,255,255},true,"",nil,nil}},Joints={}},
	{Id="RBXM_859",Num=859,Name="Lose Game Beacon",Category="Buildings",Class="Part",Ctrl="None",BBox={6,6,6},OnTouch={Action="Lose",Score=0,Timer=0,Sound="Boing"},Parts={{2,{6,6,6},{0,3,0},nil,{230,0,0},true,"TB",nil,nil}},Joints={}},
	{Id="RBXM_860",Num=860,Name="Win Game Beacon",Category="Buildings",Class="Part",Ctrl="None",BBox={6,6,6},OnTouch={Action="Win",Score=0,Timer=0,Sound="Victory"},Parts={{2,{6,6,6},{0,3,0},nil,{204,204,76},true,"TB",nil,nil}},Joints={}},
	{Id="RBXM_862",Num=862,Name="Man figure",Category="Robots",Class="Model",Ctrl="KeyboardRight",BBox={2,13,5},OnTouch=nil,Parts={{2,{2,3,3},{0,8.5,0},{-1,0,0,0,1,0,0,0,-1},{204,204,204},false,"TB",nil,nil},{2,{2,2,3},{0,6,0},{-1,0,0,0,1,0,0,0,-1},{102,204,230},false,"TB",nil,nil},{2,{1,2,1},{0,0.5,1},{0,1,0,0,0,-1,-1,0,0},{76,76,76},false,"TB",nil,nil},{2,{1,4,1},{-0.5,9,-2},{0,0,1,0,1,0,-1,0,0},{204,204,204},false,"TB",nil,nil},{2,{1,4,1},{-0.5,3,-1},{0,0,1,0,1,0,-1,0,0},{102,204,230},false,"TB",nil,nil},{2,{1,2,1},{0,0.5,-1},{0,1,0,0,0,-1,-1,0,0},{76,76,76},false,"TB",nil,nil},{2,{1,4,1},{-0.5,3,1},{0,0,1,0,1,0,-1,0,0},{102,204,230},false,"TB",nil,nil},{2,{1,4,1},{-0.5,9,2},{0,0,1,0,1,0,-1,0,0},{204,204,204},false,"TB",nil,nil},{3,{2,2,2},{0,12,-0.5},{0,1,0,-1,0,0,0,0,1},{204,204,76},false,"",nil,nil},{2,{2,1,3},{0,10.5,0},{-1,0,0,0,1,0,0,0,-1},{204,204,204},false,"TB",nil,nil}},Joints={{1,4,10,"NoInput",{0,0,-1},{0,10.5,-1.5}},{1,8,10,"NoInput",{0,0,1},{0,10.5,1.5}},{0,1,2},{0,1,10},{0,2,5},{0,2,7},{0,3,7},{0,5,6},{0,9,10}}},
	{Id="RBXM_863",Num=863,Name="Blue figure",Category="Robots",Class="PhysicalCharacter",Ctrl="KeyboardRight",FlagShown=false,BBox={2,6,4},OnTouch=nil,Parts={{1,{2,2,2},{0,5,0},{0,0,-1,0,1,0,1,0,0},{255,255,0},false,"",nil,"Head"},{2,{2,1,1},{-0.5,3.5,0},{0,0,-1,0,1,0,1,0,0},{0,0,255},false,"TB",nil,"UpperBody"},{2,{2,1,1},{-0.5,2.5,0},{0,0,-1,0,1,0,1,0,0},{178,178,178},false,"TB",nil,"LowerBody"},{2,{1,2,1},{-0.5,3,1.5},{0,0,-1,0,1,0,1,0,0},{255,255,0},false,"",nil,"RightArm"},{2,{1,2,1},{-0.5,3,-1.5},{0,0,-1,0,1,0,1,0,0},{255,255,0},false,"",nil,"LeftArm"},{2,{1,2,1},{-0.5,1,0.5},{0,0,-1,0,1,0,1,0,0},{0,0,255},false,"B",nil,"RightLeg"},{2,{1,2,1},{-0.5,1,-0.5},{0,0,-1,0,1,0,1,0,0},{0,0,255},false,"B",nil,"LeftLeg"}},Joints={{1,4,2,"NoInput",{0,0,1},{-0.5,3.5,1}},{1,5,2,"NoInput",{0,0,-1},{-0.5,3.5,-1}},{0,1,2},{0,2,3},{0,3,6},{0,3,7}}},
	{Id="RBXM_864",Num=864,Name="Red Figure",Category="Robots",Class="PhysicalCharacter",Ctrl="KeyboardLeft",FlagShown=false,BBox={2,6,4},OnTouch=nil,Parts={{1,{2,2,2},{0,5,0},{0,0,-1,0,1,0,1,0,0},{255,255,0},false,"",nil,"Head"},{2,{2,1,1},{-0.5,3.5,0},{0,0,-1,0,1,0,1,0,0},{255,0,0},false,"TB",nil,"UpperBody"},{2,{2,1,1},{-0.5,2.5,0},{0,0,-1,0,1,0,1,0,0},{178,178,178},false,"TB",nil,"LowerBody"},{2,{1,2,1},{-0.5,3,1.5},{0,0,-1,0,1,0,1,0,0},{255,255,0},false,"",nil,"RightArm"},{2,{1,2,1},{-0.5,3,-1.5},{0,0,-1,0,1,0,1,0,0},{255,255,0},false,"",nil,"LeftArm"},{2,{1,2,1},{-0.5,1,0.5},{0,0,-1,0,1,0,1,0,0},{255,0,0},false,"B",nil,"RightLeg"},{2,{1,2,1},{-0.5,1,-0.5},{0,0,-1,0,1,0,1,0,0},{255,0,0},false,"B",nil,"LeftLeg"}},Joints={{1,4,2,"NoInput",{0,0,1},{-0.5,3.5,1}},{1,5,2,"NoInput",{0,0,-1},{-0.5,3.5,-1}},{0,1,2},{0,2,3},{0,3,6},{0,3,7}}},
}

local TOOLBOX_CATEGORIES ={ "All", "Blocks", "Vehicles", "Construction", "Buildings", "Robots", "Weapons" }
S.currentCategoryIndex = S.currentCategoryIndex or 1
S.activeMotors = S.activeMotors or {}

local function getFilteredToolboxModels()
	local cat = TOOLBOX_CATEGORIES[S.currentCategoryIndex] or "All"
	if cat == "All" then
		return ORIGINAL_2004_TOOLBOX_MODELS
	end
	local list = {}
	for _, m in ipairs(ORIGINAL_2004_TOOLBOX_MODELS) do
		if m.Category == cat then
			table.insert(list, m)
		end
	end
	return list
end

local function getSpawnCFrame(yOffset)
	Camera = Workspace.CurrentCamera
	local camCF = Camera and Camera.CFrame or CFrame.new(0, 10, 0)
	local lookPos = camCF.Position + camCF.LookVector * 18
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { LocalPlayer.Character, ArrowRigFolder }
	local hit = Workspace:Raycast(lookPos + Vector3.new(0, 24, 0), Vector3.new(0, -65, 0), rayParams)
	local basePos = hit and hit.Position or Vector3.new(lookPos.X, math.max(1, lookPos.Y - 4), lookPos.Z)
	return CFrame.new(
		math.floor(basePos.X + 0.5),
		math.floor(basePos.Y + (yOffset or 0) + 0.5),
		math.floor(basePos.Z + 0.5)
	)
end

local function spawnOriginal2004Model(modelDef)
	if not modelDef then return nil end
	playClassicSound(SOUND_SNAP, 0.55, 1.05)

	local baseCF = getSpawnCFrame(0.2)
	local isSinglePart = (#modelDef.Parts == 1 and modelDef.Class ~= "Model" and modelDef.Class ~= "PhysicalCharacter")
	local createdParts = {}
	local container = nil

	if not isSinglePart then
		container = Instance.new("Model")
		container.Name = string.format("%d %s", modelDef.Num, modelDef.Name)
		container:SetAttribute("Is2005Model", true)
		container:SetAttribute("OriginalRBXMId", modelDef.Num)
		if modelDef.Class == "PhysicalCharacter" or modelDef.Num == 862 or modelDef.Num == 863 or modelDef.Num == 864 then
			container:SetAttribute("IsDynabloxFigure", true)
		end
	end

	for idx, pdef in ipairs(modelDef.Parts) do
		local shapeCode, sz, pos, rot, rgb, anch, bCode, vel, role = pdef[1], pdef[2], pdef[3], pdef[4], pdef[5], pdef[6], pdef[7], pdef[8], pdef[9]
		local p = Instance.new("Part")
		local roleMapName = {
			UpperBody = "Torso",
			LowerBody = "MidTorso",
			LeftArm   = "Left Arm",
			RightArm  = "Right Arm",
			LeftLeg   = "Left Leg",
			RightLeg  = "Right Leg",
			Head      = "Head",
		}
		p.Name = (role and roleMapName[role]) or role or (isSinglePart and string.format("%d %s", modelDef.Num, modelDef.Name) or ("Part" .. idx))
		if shapeCode == 1 then
			p.Shape = Enum.PartType.Ball
		elseif shapeCode == 3 then
			p.Shape = Enum.PartType.Cylinder
		else
			p.Shape = Enum.PartType.Block
		end
		p.Size = Vector3.new(sz[1], sz[2], sz[3])
		p.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = string.find(bCode, "T", 1, true) and Enum.SurfaceType.Studs or Enum.SurfaceType.Smooth
		p.BottomSurface = string.find(bCode, "B", 1, true) and Enum.SurfaceType.Studs or Enum.SurfaceType.Smooth
		p.RightSurface = string.find(bCode, "F", 1, true) and Enum.SurfaceType.Studs or Enum.SurfaceType.Smooth
		p.LeftSurface = string.find(bCode, "K", 1, true) and Enum.SurfaceType.Studs or Enum.SurfaceType.Smooth
		p.FrontSurface = string.find(bCode, "L", 1, true) and Enum.SurfaceType.Studs or Enum.SurfaceType.Smooth
		p.BackSurface = string.find(bCode, "R", 1, true) and Enum.SurfaceType.Studs or Enum.SurfaceType.Smooth

		local localCF
		if rot then
			localCF = CFrame.new(pos[1], pos[2], pos[3], rot[1], rot[2], rot[3], rot[4], rot[5], rot[6], rot[7], rot[8], rot[9])
		else
			localCF = CFrame.new(pos[1], pos[2], pos[3])
		end
		p.CFrame = baseCF * localCF
		p.CanCollide = true
		p.CanTouch = true
		p.CanQuery = true
		p.Massless = false

		if anch then
			p:SetAttribute("AnchoredInGame", true)
		end
		p.Anchored = anch or (not S.isSimulationRunning)

		if vel then
			local worldVel = baseCF:VectorToWorldSpace(Vector3.new(vel[1], vel[2], vel[3]))
			p:SetAttribute("InitialVelocity2004", worldVel)
			if S.isSimulationRunning and not anch then
				p.AssemblyLinearVelocity = worldVel
			end
		end

		p.Parent = container or SpawnedModelsFolder
		if bCode ~= "" and p.Shape == Enum.PartType.Block then
			apply2005StudsToPart(p)
		end

		if modelDef.OnTouch then
			hookInteractive2005Model(p, modelDef.OnTouch)
		end

		createdParts[idx] = p
	end

	-- Choose best PrimaryPart (UpperBody/Torso or largest/heaviest chassis block)
	if container then
		local bestPrimary = createdParts[1]
		local bestVol = 0
		for _, p in ipairs(createdParts) do
			if p.Name == "Torso" or p.Name == "UpperBody" then
				bestPrimary = p
				break
			end
			local v = p.Size.X * p.Size.Y * p.Size.Z
			if p.Shape == Enum.PartType.Block and v > bestVol then
				bestVol = v
				bestPrimary = p
			end
		end
		container.PrimaryPart = bestPrimary
	end

	-- Anchor the ground base part of stationary motorized obstacles (781, 782, 783, 854, 855, 856) so their rotors spin on a stable base!
	local stationaryBasePartIdx = ({
		[781] = 1, [782] = 1, [783] = 1,
		[854] = 3, [855] = 4, [856] = 3,
	})[modelDef.Num]
	if stationaryBasePartIdx and createdParts[stationaryBasePartIdx] then
		createdParts[stationaryBasePartIdx]:SetAttribute("AnchoredInGame", true)
		createdParts[stationaryBasePartIdx].Anchored = true
	end

	-- Build all 2004 Welds, Connected Shoulder Hinges (Motor6D), and Wheel/Obstacle HingeConstraints!
	for _, jdef in ipairs(modelDef.Joints) do
		local jtype, idx0, idx1 = jdef[1], jdef[2], jdef[3]
		local p0, p1 = createdParts[idx0], createdParts[idx1]
		if p0 and p1 then
			if jtype == 0 then
				local wc = Instance.new("WeldConstraint")
				wc.Name = (p1.Name == "Left Arm" or p1.Name == "Right Arm" or p1.Name == "Left Leg" or p1.Name == "Right Leg") and ("RigWeld_" .. p1.Name) or "Weld2004"
				wc.Part0 = p0
				wc.Part1 = p1
				wc.Parent = p1
			else
				local inputType, axis, jpos = jdef[4], jdef[5], jdef[6]
				local worldPivot = baseCF:PointToWorldSpace(Vector3.new(jpos[1], jpos[2], jpos[3]))
				local worldAxis = baseCF:VectorToWorldSpace(Vector3.new(axis[1], axis[2], axis[3])).Unit

				-- Check if this is a figure's shoulder hinge (Left Arm / Right Arm):
				-- Use a connected shoulder Motor6D so the arm stays 100% attached and swings cleanly around the shoulder pin!
				local isArm0 = (p0.Name == "Left Arm" or p0.Name == "Right Arm" or p0.Name == "Part4" or p0.Name == "Part8")
					and (modelDef.Class == "PhysicalCharacter" or modelDef.Num == 809 or modelDef.Num == 810 or modelDef.Num == 827 or modelDef.Num == 862 or modelDef.Num == 863 or modelDef.Num == 864)
				local isArm1 = (p1.Name == "Left Arm" or p1.Name == "Right Arm")
				if jtype == 1 and (inputType == "NoInput" or not inputType) and (isArm0 or isArm1) then
					local armPart = isArm0 and p0 or p1
					local torsoPart = isArm0 and p1 or p0
					if armPart.Name == "Part4" then armPart.Name = "Right Arm" end
					if armPart.Name == "Part8" then armPart.Name = "Left Arm" end
					attachSwingingArmHinge(torsoPart, armPart, Vector3.zero, Vector3.zero, createdParts)
				else
					local att0 = Instance.new("Attachment")
					att0.Name = "JAtt0"
					att0.Position = p0.CFrame:PointToObjectSpace(worldPivot)
					att0.Axis = p0.CFrame:VectorToObjectSpace(worldAxis).Unit
					att0.Parent = p0

					local att1 = Instance.new("Attachment")
					att1.Name = "JAtt1"
					att1.Position = p1.CFrame:PointToObjectSpace(worldPivot)
					att1.Axis = p1.CFrame:VectorToObjectSpace(worldAxis).Unit
					att1.Parent = p1

					-- Prevent hinged/motorized parts (e.g. wheels and chassis) from binding against each other
					local ncc = Instance.new("NoCollisionConstraint")
					ncc.Name = "HingeNoCollide2004"
					ncc.Part0 = p0
					ncc.Part1 = p1
					ncc.Parent = p0

					local hc = Instance.new("HingeConstraint")
					hc.Name = "Motor2004_" .. tostring(inputType)
					hc.Attachment0 = att0
					hc.Attachment1 = att1
					if jtype >= 2 or (inputType and inputType ~= "NoInput") then
						hc.ActuatorType = Enum.ActuatorType.Motor
						hc.MotorMaxTorque = 250000
						hc.MotorMaxAcceleration = 120
						hc.AngularVelocity = (inputType == "Constant") and 6.5 or 0
						table.insert(S.activeMotors, {
							Constraint = hc,
							Model = container or p0,
							Input = inputType or "Constant",
						})
					else
						hc.ActuatorType = Enum.ActuatorType.None
					end
					hc.Parent = p0
				end
			end
		end
	end

	local spawnedObj = container or createdParts[1]
	if container then
		container.Parent = SpawnedModelsFolder
	end

	if spawnedObj then
		local okTop, topCF, topSize = pcall(function()
			if spawnedObj:IsA("Model") then return spawnedObj:GetBoundingBox() end
			return spawnedObj.CFrame, spawnedObj.Size
		end)
		if okTop then
			S.standOnGround(spawnedObj, topCF.Position + Vector3.new(0, topSize.Magnitude * 0.5 + 1, 0), nil)
		end
		if container and container:GetAttribute("IsDynabloxFigure") and container.PrimaryPart then
			ensureUprightGyro(container.PrimaryPart, 0)
		end
		-- Every 2005 toolbox model arrived with its own Controller (vehicles & robots: KeyboardRight)
		if modelDef.Ctrl and modelDef.Ctrl ~= "None" then
			attachControllerBadge(spawnedObj, modelDef.Ctrl, modelDef.FlagShown ~= false)
		end
		if modelDef.Label then
			setNameShown2005(spawnedObj, modelDef.Label)
		end
		selectStudioObject(spawnedObj)
	end
	return spawnedObj
end

local function buildViewportModelThumb(parent, modelDef)
	local vf = Instance.new("ViewportFrame")
	vf.Size = UDim2.new(1, 0, 1, -12)
	vf.Position = UDim2.new(0, 0, 0, 0)
	vf.BackgroundTransparency = 1
	vf.Ambient = Color3.fromRGB(195, 195, 195)
	vf.LightColor = Color3.fromRGB(255, 255, 255)
	vf.LightDirection = Vector3.new(-1, -1.4, -1)
	vf.Parent = parent

	local cam = Instance.new("Camera")
	cam.FieldOfView = 32
	cam.Parent = vf
	vf.CurrentCamera = cam

	local bx, by, bz = modelDef.BBox[1], modelDef.BBox[2], modelDef.BBox[3]
	local centerY = by * 0.5
	for _, pdef in ipairs(modelDef.Parts) do
		local shapeCode, sz, pos, rot, rgb = pdef[1], pdef[2], pdef[3], pdef[4], pdef[5]
		local p = Instance.new("Part")
		p.Anchored = true
		if shapeCode == 1 then
			p.Shape = Enum.PartType.Ball
		elseif shapeCode == 3 then
			p.Shape = Enum.PartType.Cylinder
		else
			p.Shape = Enum.PartType.Block
		end
		p.Size = Vector3.new(sz[1], sz[2], sz[3])
		p.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		p.Material = Enum.Material.SmoothPlastic
		if rot then
			p.CFrame = CFrame.new(pos[1], pos[2] - centerY, pos[3], rot[1], rot[2], rot[3], rot[4], rot[5], rot[6], rot[7], rot[8], rot[9])
		else
			p.CFrame = CFrame.new(pos[1], pos[2] - centerY, pos[3])
		end
		p.Parent = vf
	end

	local maxDim = math.max(bx, by, bz, 2.5)
	local dist = maxDim * 1.45
	cam.CFrame = CFrame.lookAt(Vector3.new(dist * 0.78, dist * 0.58, dist * 0.82), Vector3.new(0, 0, 0))
	return vf
end

-- 2005 toolbox pages (Surface / Color / Controller / Hopper), as served to the client's toolbox strip
local SURFACE_TOOLS_2005 = {
	{ Name = "Flat",              Sprite = "FlatTool",           W = 60, Surface = "Smooth" },
	{ Name = "Bump",              Sprite = "BumpTool",           W = 60, Surface = "Bumps" },
	{ Name = "Hinge",             Sprite = "HingeSurfaceTool",   W = 51, Surface = "Hinge" },
	{ Name = "Motor Left",        Sprite = "LeftMotorTool",      W = 60, Surface = "Motor", Speed = 1 },
	{ Name = "Motor Left Fast",   Sprite = "LeftMotorFastTool",  W = 60, Surface = "Motor", Speed = 3 },
	{ Name = "Motor Right",       Sprite = "RightMotorTool",     W = 60, Surface = "Motor", Speed = -1 },
	{ Name = "Motor Right Fast",  Sprite = "RightMotorFastTool", W = 60, Surface = "Motor", Speed = -3 },
}

-- Colours were plain RGB in 2005 (BrickColor came later): the 20-colour 2005 palette, two rows of 10.
-- Values measured from a screenshot of the 2005 Color page.
local COLOR_PALETTE_2005 = {
	{ 255, 255, 0 }, { 0, 0, 255 }, { 235, 232, 215 }, { 126, 119, 49 }, { 48, 178, 34 },
	{ 203, 204, 77 }, { 105, 231, 204 }, { 112, 124, 180 }, { 118, 35, 180 }, { 203, 77, 76 },
	{ 255, 0, 0 }, { 180, 180, 180 }, { 127, 127, 127 }, { 254, 145, 51 }, { 174, 194, 221 },
	{ 76, 76, 76 }, { 204, 204, 204 }, { 101, 204, 229 }, { 129, 254, 35 }, { 33, 76, 202 },
}

local CONTROLLER_TOOLS_2005 = {
	{ Id = "KeyboardRight", Sprite = "Controller1Tool",    Label = "Arrows" },
	{ Id = "KeyboardLeft",  Sprite = "Controller2Tool",    Label = "WASD" },
	{ Id = "Chase",         Sprite = "ControllerAI1Tool",  Label = "Chase" },
	{ Id = "Flee",          Sprite = "ControllerAI2Tool",  Label = "Flee" },
	{ Id = "None",          Sprite = "ControllerNoneTool", Label = "None" },
}

-- The 2005 Hopper page: the HopperBins a level could hand to the player (in this order on the page)
local HOPPER_BINS_2005 = {
	{ Id = "GameTool",  Sprite = "HopperGameTool" },  -- hand marked "Grab": drag things around
	{ Id = "Grab",      Sprite = "HopperGrab" },      -- hand and binoculars: pick things up and throw them
	{ Id = "Clone",     Sprite = "HopperClone" },     -- wand marked "Copy": copy what you tap
	{ Id = "Hammer",    Sprite = "HopperHammer" },    -- hammer marked "Delete": delete what you tap
	{ Id = "Slingshot", Sprite = "HopperSlingshot" }, -- fire a ball
	{ Id = "Rocket",    Sprite = "HopperRocket" },    -- fire a rocket that blasts bricks apart
	{ Id = "Laser",     Sprite = "HopperLaser" },     -- zap a brick loose
}
S.HOPPER_BINS_2005 = HOPPER_BINS_2005

local FACE_NAMES = {
	[Enum.NormalId.Top] = "Top",
	[Enum.NormalId.Bottom] = "Bottom",
	[Enum.NormalId.Left] = "Left",
	[Enum.NormalId.Right] = "Right",
	[Enum.NormalId.Front] = "Front",
	[Enum.NormalId.Back] = "Back",
}

-- The 2005 surface tools changed only the face you clicked
local function applySurfaceToolToFace(part, normalId, tool)
	local face = FACE_NAMES[normalId]
	if not part or not part:IsA("BasePart") or not face or not tool then return end
	local bumpTexName = "Classic2005Bumps" .. face
	local oldBumpTex = part:FindFirstChild(bumpTexName)
	if oldBumpTex then oldBumpTex:Destroy() end

	if tool.Surface == "Bumps" then
		if face == "Top" then
			part:SetAttribute("No2005Bumps", nil)
			part.TopSurface = Enum.SurfaceType.Studs
			if styledParts[part] and allStuddedParts[part] then
				pcall(rebuild3DBumpsForPart, part)
			else
				styledParts[part] = nil
				apply2005StudsToPart(part)
			end
		elseif S.CustomStudUrl then
			part[face .. "Surface"] = Enum.SurfaceType.Smooth
			local tex = Instance.new("Texture")
			tex.Name = bumpTexName
			tex.Face = normalId
			tex.StudsPerTileU = 1
			tex.StudsPerTileV = 1
			tex.Texture = S.CustomStudUrl
			tex.Transparency = part.Transparency
			tex.Parent = part
		else
			part[face .. "Surface"] = Enum.SurfaceType.Studs
		end
		return
	end

	if face == "Top" then
		part:SetAttribute("No2005Bumps", true)
		pcall(rebuild3DBumpsForPart, part)
	end
	if tool.Surface == "Hinge" then
		part[face .. "Surface"] = Enum.SurfaceType.Hinge
	elseif tool.Surface == "Motor" then
		part[face .. "Surface"] = Enum.SurfaceType.Motor
		pcall(function()
			part[face .. "SurfaceInput"] = Enum.InputType.Constant
			part[face .. "ParamB"] = tool.Speed
		end)
	else
		part[face .. "Surface"] = Enum.SurfaceType.Smooth
	end
end
S.applySurfaceToolToFace = applySurfaceToolToFace

local function createToolboxFallbackText(parent, text)
	local fb = Instance.new("TextLabel")
	fb:SetAttribute("No2006Font", true)
	fb.Size = UDim2.new(1, 0, 1, 0)
	fb.BackgroundColor3 = Color3.fromRGB(236, 233, 216)
	fb.BorderSizePixel = 1
	fb.BorderColor3 = Color3.fromRGB(172, 168, 153)
	fb.Font = Enum.Font.Arial
	fb.Text = text
	fb.TextSize = 11
	fb.TextWrapped = true
	fb.TextColor3 = Color3.fromRGB(0, 0, 0)
	fb.Parent = parent
	return fb
end

function rebuildBottomBarContent()
	for _, child in ipairs(BottomItemsContainer:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	for name in pairs(S.tabButtons) do
		S.refreshTabLook(name)
	end
	S.setModelToolboxChrome(S.activeTab == "Model")

	if S.activeTab == "Model" then
		local catName = TOOLBOX_CATEGORIES[S.currentCategoryIndex] or "All"
		local filtered = getFilteredToolboxModels()
		CategoryText.Text = string.format("%s (%d)", catName, #filtered)
		AllModelsLink.Text = "Next Cat..."

		S.bottomScrollIndex = math.clamp(S.bottomScrollIndex, 1, math.max(1, #filtered))
		for idx = S.bottomScrollIndex, #filtered do
			local modelDef = filtered[idx]
			local btn = Instance.new("TextButton")
			btn:SetAttribute("No2006Font", true)
			btn.Name = modelDef.Id
			btn.LayoutOrder = idx
			btn.Size = UDim2.new(0, 58, 0, 48)
			btn.BackgroundTransparency = 1
			btn.AutoButtonColor = false
			btn.Text = ""
			btn.Parent = BottomItemsContainer

			buildViewportModelThumb(btn, modelDef)

			local cap = Instance.new("TextLabel")
			cap:SetAttribute("No2006Font", true)
			cap.Position = UDim2.new(0, 1, 1, -12)
			cap.Size = UDim2.new(1, -2, 0, 12)
			cap.BackgroundTransparency = 1
			cap.Font = Enum.Font.Arial
			cap.Text = modelDef.Name
			cap.TextSize = 9
			cap.TextTruncate = Enum.TextTruncate.AtEnd
			cap.TextColor3 = Color3.fromRGB(25, 25, 25)
			cap.Parent = btn

			storeConnection(btn.MouseEnter:Connect(function()
				btn.BackgroundTransparency = 0.55
				btn.BackgroundColor3 = Color3.fromRGB(180, 245, 245)
			end))
			storeConnection(btn.MouseLeave:Connect(function()
				btn.BackgroundTransparency = 1
			end))
			storeConnection(btn.MouseButton1Click:Connect(function()
				spawnOriginal2004Model(modelDef)
			end))
		end
	elseif S.activeTab == "Surface" then
		-- Pick a tool, then click a face of a part to change that face
		for idx, tool in ipairs(SURFACE_TOOLS_2005) do
			local btn = Instance.new("ImageButton")
			btn.Name = tool.Name
			btn.LayoutOrder = idx
			btn.Size = UDim2.new(0, tool.W, 0, 40)
			btn.BackgroundTransparency = 1
			btn.AutoButtonColor = false
			btn.Parent = BottomItemsContainer
			local fb = createToolboxFallbackText(btn, tool.Name)
			bindButtonSprites(btn, fb, tool.Sprite, tool.Sprite, tool.Sprite .. "_dn", tool.Sprite, nil, function()
				return S.currentSurfaceTool == tool
			end)
			storeConnection(btn.MouseButton1Click:Connect(function()
				S.currentSurfaceTool = tool
				S.currentStudioTool = "Surface"
				refreshAllToolbarSprites()
				playClassicSound(SOUND_BOOP, 0.45, 1)
				rebuildBottomBarContent()
			end))
		end
	elseif S.activeTab == "Color" then
		-- Matches the 2005 Color page: two rows of ten 20x20 sunken swatches, 4px apart, and nothing else
		local palette = Instance.new("Frame")
		palette.Name = "Palette"
		palette.LayoutOrder = 1
		palette.Size = UDim2.new(0, 10 * 24 - 4, 0, 2 * 24 - 4)
		palette.BackgroundTransparency = 1
		palette.Parent = BottomItemsContainer

		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(0, 20, 0, 20)
		grid.CellPadding = UDim2.new(0, 4, 0, 4)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = palette

		local function shade(c, k)
			return Color3.new(c.R * k, c.G * k, c.B * k)
		end

		for idx, rgb in ipairs(COLOR_PALETTE_2005) do
			local col = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
			-- Dark outer edge, a mid-tone top/left inner edge, then the colour itself
			local swatch = Instance.new("TextButton")
			swatch.LayoutOrder = idx
			swatch.BackgroundColor3 = shade(col, 0.55)
			swatch.BorderSizePixel = 0
			swatch.AutoButtonColor = false
			swatch.Text = ""
			swatch.Parent = palette

			local inner = Instance.new("Frame")
			inner.Position = UDim2.new(0, 1, 0, 1)
			inner.Size = UDim2.new(1, -2, 1, -2)
			inner.BackgroundColor3 = shade(col, 0.8)
			inner.BorderSizePixel = 0
			inner.Parent = swatch

			local fill = Instance.new("Frame")
			fill.Position = UDim2.new(0, 2, 0, 2)
			fill.Size = UDim2.new(1, -3, 1, -3)
			fill.BackgroundColor3 = col
			fill.BorderSizePixel = 0
			fill.Parent = swatch

			storeConnection(swatch.MouseButton1Click:Connect(function()
				S.currentBrickColorToApply = col
				if S.selectedObject then
					for _, p in ipairs(S.selectedObject:IsA("Model") and S.selectedObject:GetDescendants() or { S.selectedObject }) do
						if p:IsA("BasePart") and not p:GetAttribute("Is2005Bump") then
							p.Color = col
						end
					end
				end
				playClassicSound(SOUND_CLICK, 0.4, 1.1)
				if S.refreshPropertyGrid then S.refreshPropertyGrid() end
			end))
		end
	elseif S.activeTab == "Controller" then
		-- Applies to the selection (or your own figure when nothing is selected)
		local sel = S.selectedObject
		local current = sel and (sel:GetAttribute("ControllerType2005") or "None") or S.currentControllerToApply
		for idx, ctrl in ipairs(CONTROLLER_TOOLS_2005) do
			local btn = Instance.new("ImageButton")
			btn.Name = ctrl.Id .. "Tool"
			btn.LayoutOrder = idx
			btn.Size = UDim2.new(0, 44, 0, 44)
			btn.BackgroundTransparency = 1
			btn.AutoButtonColor = false
			btn.Parent = BottomItemsContainer
			local fb = createToolboxFallbackText(btn, ctrl.Label)
			bindButtonSprites(btn, fb, ctrl.Sprite, ctrl.Sprite, ctrl.Sprite .. "_dn", ctrl.Sprite, nil, function()
				return current == ctrl.Id
			end)
			storeConnection(btn.MouseButton1Click:Connect(function()
				S.currentControllerToApply = ctrl.Id
				local target = S.selectedObject or S.localPlayerRig
				if target and target.Parent then
					attachControllerBadge(target, ctrl.Id)
					playClassicSound(SOUND_BOOP, 0.45, 1)
				else
					playClassicSound(SOUND_CLICK, 0.4, 1)
				end
				if S.refreshPropertyGrid then S.refreshPropertyGrid() end
				rebuildBottomBarContent()
			end))
		end
	elseif S.activeTab == "Hopper" then
		-- Tap a tool to put it in (or take it out of) the level's Hopper. In GO mode the tools you put in show up
		-- in a bar at the bottom of the screen: tap one to hold it, then tap the world to use it.
		for idx, bin in ipairs(HOPPER_BINS_2005) do
			local btn = Instance.new("ImageButton")
			btn.Name = bin.Id
			btn.LayoutOrder = idx
			btn.Size = UDim2.new(0, 50, 0, 47)
			btn.BackgroundColor3 = Color3.fromRGB(204, 204, 204)
			btn.BackgroundTransparency = S.levelHopperBins[bin.Id] and 0 or 1
			btn.BorderSizePixel = 0
			btn.AutoButtonColor = false
			btn.ScaleType = Enum.ScaleType.Fit
			btn.Parent = BottomItemsContainer
			local fb = createToolboxFallbackText(btn, bin.Id)
			applySpriteToImage(btn, bin.Sprite, fb)
			storeConnection(btn.MouseButton1Click:Connect(function()
				local on = not S.levelHopperBins[bin.Id]
				S.levelHopperBins[bin.Id] = on or nil
				if not on and S.activeHopperBin == bin.Id then
					S.activeHopperBin = nil
				end
				playClassicSound(SOUND_CLICK, 0.4, 1)
				rebuildBottomBarContent()
				if S.refreshHopperBar then S.refreshHopperBar() end
			end))
		end

		local hint = Instance.new("TextLabel")
		hint:SetAttribute("No2006Font", true)
		hint.LayoutOrder = #HOPPER_BINS_2005 + 1
		hint.Size = UDim2.new(0, 190, 0, 44)
		hint.BackgroundTransparency = 1
		hint.Font = Enum.Font.Arial
		hint.TextSize = 11
		hint.TextWrapped = true
		hint.TextXAlignment = Enum.TextXAlignment.Left
		hint.TextColor3 = Color3.fromRGB(60, 60, 60)
		hint.Text = next(S.levelHopperBins)
			and "Press GO, tap a tool in the bar at the bottom, then tap the world to use it."
			or "Tap tools to give them to the player. They work in GO mode."
		hint.Parent = BottomItemsContainer
	end
end
S.rebuildBottomBarContent = rebuildBottomBarContent

for tabName, data in pairs(S.tabButtons) do
	storeConnection(data.Button.MouseButton1Click:Connect(function()
		S.activeTab = tabName
		playClassicSound(SOUND_CLICK, 0.35, 1)
		rebuildBottomBarContent()
	end))
end

local function cycleToolboxCategory()
	S.activeTab = "Model"
	S.currentCategoryIndex = (S.currentCategoryIndex % #TOOLBOX_CATEGORIES) + 1
	S.bottomScrollIndex = 1
	playClassicSound(SOUND_PAGE, 0.45, 1)
	rebuildBottomBarContent()
end

storeConnection(AllModelsLink.MouseButton1Click:Connect(cycleToolboxCategory))
storeConnection(CategoryBox.MouseButton1Click:Connect(cycleToolboxCategory))

storeConnection(BottomLeftArrow.MouseButton1Click:Connect(function()
	S.bottomScrollIndex = math.max(1, S.bottomScrollIndex - 3)
	playClassicSound(SOUND_PAGE, 0.4, 1.05)
	rebuildBottomBarContent()
end))

storeConnection(BottomRightArrow.MouseButton1Click:Connect(function()
	local filtered = getFilteredToolboxModels()
	S.bottomScrollIndex = math.min(math.max(1, #filtered), S.bottomScrollIndex + 3)
	playClassicSound(SOUND_PAGE, 0.4, 0.95)
	rebuildBottomBarContent()
end))

rebuildBottomBarContent()

--========================================================
-- 11. TOP BAR MENUS (FILE, EDIT, VIEW, INSERT, FORMAT), PROPERTIES WINDOW & MENU POPUP
--========================================================
do
	-- (Addtion-Scripts) XP WINDOWS: the look of Windows XP's own windows (the "Luna" blue theme the 2005 client ran
	-- under): a blue title bar lit at the top and darker at the bottom, rounded top corners, white bold title, the
	-- red close button (rounded, white edge, white X), a blue frame round the window, and grey-beige XP buttons with a
	-- thin dark-blue edge that glow orange under the finger.
	local XP_FACE = Color3.fromRGB(236, 233, 216)
	local XP_FRAME = Color3.fromRGB(0, 84, 227)
	local XP_TITLE = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(9, 151, 255)),
		ColorSequenceKeypoint.new(0.08, Color3.fromRGB(0, 113, 255)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(0, 84, 227)),
		ColorSequenceKeypoint.new(0.88, Color3.fromRGB(0, 76, 218)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 61, 190)),
	})
	local XP_CLOSE = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 132, 104)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(226, 88, 56)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(196, 49, 25)),
	})
	local XP_BUTTON = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.85, Color3.fromRGB(236, 235, 230)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(214, 208, 197)),
	})
	local function xpCorner(obj, r)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, r)
		c.Parent = obj
		return c
	end
	local function xpGradient(obj, seq)
		local g = Instance.new("UIGradient")
		g.Color = seq
		g.Rotation = 90
		g.Parent = obj
		return g
	end
	local function xpStroke(obj, color, thick)
		local st = Instance.new("UIStroke")
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Color = color
		st.Thickness = thick
		st.Parent = obj
		return st
	end
	-- a window frame, its title bar, title and close button drawn as XP's
	-- (Addtion-Scripts) THE REAL XP PICTURES: from the Luna theme sheet the user gave, cut into one small picture
	-- (assets/xp_parts.png: Roblox shrinks a picture over 1024 tall, so the whole sheet came out wrong) - window title
	-- bars, buttons, the window's close button, with their hovered and pressed looks), downloaded once into the
	-- executor's folder and shown with getcustomasset. The drawn look below stays if it can't be loaded.
	local XP_SHEET_URL = "https://raw.githubusercontent.com/eloredo413-hue/Addtion-Scripts/main/assets/xp_parts.png"
	local XP_SHEET_FILE = "AddtionAssets/xp_parts_v1.png"
	local xpSheetId, xpSheetTried, xpSheetWaiting = nil, false, {}
	local function withXpSheet(fn)
		if xpSheetId then task.spawn(fn, xpSheetId) return end
		table.insert(xpSheetWaiting, fn)
		if xpSheetTried then return end
		xpSheetTried = true
		task.spawn(function()
			pcall(function()
				if not (getcustomasset and writefile and isfile) then return end
				if not isfile(XP_SHEET_FILE) then
					pcall(function() if makefolder and not (isfolder and isfolder("AddtionAssets")) then makefolder("AddtionAssets") end end)
					local data = game:HttpGet(XP_SHEET_URL)
					if type(data) ~= "string" or #data < 1000 or data:sub(2, 4) ~= "PNG" then return end
					writefile(XP_SHEET_FILE, data)
				end
				xpSheetId = getcustomasset(XP_SHEET_FILE)
			end)
			if xpSheetId then
				for _, f in ipairs(xpSheetWaiting) do task.spawn(f, xpSheetId) end
			end
			xpSheetWaiting = {}
		end)
	end
	-- a piece of the sheet over a frame: ScaleType Slice with the given middle (the edges keep their size)
	local function xpPiece(parent, id, x, y, w, h, slice, z)
		local img = Instance.new("ImageLabel")
		img.Name = "XPPiece"
		img.BackgroundTransparency = 1
		img.Image = id
		img.ImageRectOffset = Vector2.new(x, y)
		img.ImageRectSize = Vector2.new(w, h)
		img.ScaleType = Enum.ScaleType.Slice
		img.SliceCenter = slice
		img.Size = UDim2.new(1, 0, 1, 0)
		img.ZIndex = z
		img.Parent = parent
		return img
	end
	S.withXpSheet, S.xpPiece = withXpSheet, xpPiece

	function S.xpWindow(win, bar, title, close)
		win.BackgroundColor3 = XP_FACE
		win.BackgroundTransparency = 0
		win.BorderSizePixel = 0
		xpCorner(win, 7)
		xpStroke(win, XP_FRAME, 3)
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		bar.BackgroundTransparency = 0
		bar.Size = UDim2.new(1, 0, 0, 26)
		xpGradient(bar, XP_TITLE)
		xpCorner(bar, 7)
		-- (the title bar's lower corners square again: only its top is rounded)
		local square = Instance.new("Frame")
		square.Name = "XPSquareBottom"
		square.BorderSizePixel = 0
		square.BackgroundColor3 = Color3.fromRGB(0, 70, 208)
		square.Position = UDim2.new(0, 0, 1, -8)
		square.Size = UDim2.new(1, 0, 0, 8)
		square.ZIndex = bar.ZIndex
		square.Parent = bar
		if title then
			title:SetAttribute("No2006Font", true)
			title.Font = Enum.Font.ArialBold
			title.TextSize = 13
			title.TextColor3 = Color3.new(1, 1, 1)
			title.TextStrokeTransparency = 0.75
			title.TextStrokeColor3 = Color3.fromRGB(0, 30, 110)
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.Position = UDim2.new(0, 8, 0, 0)
			title.Size = UDim2.new(1, -36, 1, 0)
			title.ZIndex = bar.ZIndex + 2
		end
		if close then
			close:SetAttribute("No2006Font", true)
			close.AutoButtonColor = false
			close.BackgroundColor3 = Color3.new(1, 1, 1)
			close.BorderSizePixel = 0
			close.Size = UDim2.new(0, 21, 0, 21)
			close.Position = UDim2.new(1, -25, 0, 3)
			close.Font = Enum.Font.ArialBold
			close.Text = "X"
			close.TextSize = 13
			close.TextColor3 = Color3.new(1, 1, 1)
			close.ZIndex = bar.ZIndex + 2
			xpGradient(close, XP_CLOSE)
			xpCorner(close, 3)
			xpStroke(close, Color3.new(1, 1, 1), 1)
		end
		withXpSheet(function(id)
			if not bar.Parent then return end
			-- the title bar (the sheet's active one, rounded at the top)
			bar.BackgroundTransparency = 1
			for _, c in ipairs(bar:GetChildren()) do
				if c:IsA("UIGradient") or c.Name == "XPSquareBottom" then c:Destroy() end
			end
			xpPiece(bar, id, 0, 0, 66, 29, Rect.new(8, 6, 58, 24), bar.ZIndex)
			if close then
				-- the red X: normal, under the finger / mouse, pressed
				close.BackgroundTransparency = 1
				close.Text = ""
				for _, c in ipairs(close:GetChildren()) do
					if c:IsA("UIGradient") or c:IsA("UIStroke") or c:IsA("UICorner") then c:Destroy() end
				end
				local x = xpPiece(close, id, 0, 30, 21, 21, Rect.new(0, 0, 0, 0), close.ZIndex)
				x.ScaleType = Enum.ScaleType.Stretch
				close.MouseEnter:Connect(function() x.ImageRectOffset = Vector2.new(22, 30) end)
				close.MouseLeave:Connect(function() x.ImageRectOffset = Vector2.new(0, 30) end)
				close.MouseButton1Down:Connect(function() x.ImageRectOffset = Vector2.new(44, 30) end)
				close.MouseButton1Up:Connect(function() x.ImageRectOffset = Vector2.new(0, 30) end)
			end
		end)
	end
	-- a button drawn as XP's (its text label inside, if it has one)
	function S.xpButton(btn, label)
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = Color3.new(1, 1, 1)
		btn.BackgroundTransparency = 0
		btn.BorderSizePixel = 0
		xpGradient(btn, XP_BUTTON)
		xpCorner(btn, 3)
		local edge = xpStroke(btn, Color3.fromRGB(0, 60, 116), 1)
		local target = label or btn
		target:SetAttribute("No2006Font", true)
		target.Font = Enum.Font.Arial
		target.TextSize = 13
		target.TextColor3 = Color3.new(0, 0, 0)
		target.TextStrokeTransparency = 1
		local function lit(on)
			edge.Color = on and Color3.fromRGB(248, 179, 48) or Color3.fromRGB(0, 60, 116)
			edge.Thickness = on and 2 or 1
		end
		btn.MouseEnter:Connect(function() lit(true) end)
		btn.MouseLeave:Connect(function() lit(false) end)
		btn.MouseButton1Down:Connect(function() lit(true) end)
		btn.MouseButton1Up:Connect(function() lit(false) end)
		withXpSheet(function(id)
			if not btn.Parent then return end
			-- the sheet's push button: normal, under the finger / mouse (orange edge), pressed
			btn.BackgroundTransparency = 1
			for _, c in ipairs(btn:GetChildren()) do
				if c:IsA("UIGradient") or c:IsA("UIStroke") or c:IsA("UICorner") then c:Destroy() end
			end
			local face = xpPiece(btn, id, 0, 52, 20, 23, Rect.new(4, 4, 16, 19), btn.ZIndex)
			if label then
				label.ZIndex = math.max(label.ZIndex, btn.ZIndex + 1)
			elseif btn:IsA("TextButton") and btn.Text ~= "" then
				-- (the button's own words would be under the picture: they go into a label on top of it)
				local words = Instance.new("TextLabel")
				words.Name = "XPWords"
				words:SetAttribute("No2006Font", true)
				words.BackgroundTransparency = 1
				words.Size = UDim2.new(1, 0, 1, 0)
				words.Font = btn.Font
				words.TextSize = btn.TextSize
				words.TextColor3 = btn.TextColor3
				words.Text = btn.Text
				words.ZIndex = btn.ZIndex + 1
				words.Parent = btn
				btn:GetPropertyChangedSignal("Text"):Connect(function()
					if btn.Text ~= "" then words.Text = btn.Text btn.Text = "" end
				end)
				btn.Text = ""
			end
			local function at(x) face.ImageRectOffset = Vector2.new(x, 52) end
			btn.MouseEnter:Connect(function() at(21) end)
			btn.MouseLeave:Connect(function() at(0) end)
			btn.MouseButton1Down:Connect(function() at(42) end)
			btn.MouseButton1Up:Connect(function() at(0) end)
		end)
	end

	-- 11A. Properties window (the 2005 client kept its property grid in a separate Windows tool window)
	local PropertyGridFrame = Instance.new("Frame")
	S.PropertyGridFrame = PropertyGridFrame
	PropertyGridFrame.Name = "PropertyGrid2004"
	PropertyGridFrame.Position = UDim2.new(0, 82, 0, 64)
	PropertyGridFrame.Size = UDim2.new(0, 235, 0, 270)
	PropertyGridFrame.BackgroundColor3 = Color3.fromRGB(236, 233, 216)
	PropertyGridFrame.BorderSizePixel = 2
	PropertyGridFrame.BorderColor3 = Color3.fromRGB(95, 95, 95)
	PropertyGridFrame.Visible = false
	PropertyGridFrame.Active = true
	PropertyGridFrame.ZIndex = 28
	PropertyGridFrame.Parent = ScreenGui

	local pgTitleBar = Instance.new("Frame")
	pgTitleBar.Size = UDim2.new(1, 0, 0, 22)
	pgTitleBar.BackgroundColor3 = Color3.fromRGB(25, 105, 195)
	pgTitleBar.BorderSizePixel = 0
	pgTitleBar.ZIndex = 29
	pgTitleBar.Parent = PropertyGridFrame

	local pgTitleLbl = Instance.new("TextLabel")
	pgTitleLbl:SetAttribute("No2006Font", true)
	pgTitleLbl.Position = UDim2.new(0, 6, 0, 0)
	pgTitleLbl.Size = UDim2.new(1, -28, 1, 0)
	pgTitleLbl.BackgroundTransparency = 1
	pgTitleLbl.Font = Enum.Font.ArialBold
	pgTitleLbl.Text = "Properties"
	pgTitleLbl.TextSize = 12
	pgTitleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	pgTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
	pgTitleLbl.ZIndex = 30
	pgTitleLbl.Parent = pgTitleBar

	local pgCloseBtn = Instance.new("TextButton")
	pgCloseBtn:SetAttribute("No2006Font", true)
	pgCloseBtn.Position = UDim2.new(1, -20, 0, 2)
	pgCloseBtn.Size = UDim2.new(0, 18, 0, 18)
	pgCloseBtn.BackgroundColor3 = Color3.fromRGB(215, 65, 55)
	pgCloseBtn.BorderSizePixel = 1
	pgCloseBtn.BorderColor3 = Color3.fromRGB(255, 255, 255)
	pgCloseBtn.Font = Enum.Font.ArialBold
	pgCloseBtn.Text = "X"
	pgCloseBtn.TextSize = 11
	pgCloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	pgCloseBtn.ZIndex = 30
	pgCloseBtn.Parent = pgTitleBar
	storeConnection(pgCloseBtn.MouseButton1Click:Connect(function()
		PropertyGridFrame.Visible = false
	end))
	S.xpWindow(PropertyGridFrame, pgTitleBar, pgTitleLbl, pgCloseBtn)

	local pgHeader = Instance.new("Frame")
	pgHeader.Position = UDim2.new(0, 4, 0, 26)
	pgHeader.Size = UDim2.new(1, -8, 0, 22)
	pgHeader.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	pgHeader.BorderSizePixel = 1
	pgHeader.BorderColor3 = Color3.fromRGB(160, 160, 160)
	pgHeader.ZIndex = 29
	pgHeader.Parent = PropertyGridFrame

	local pgClassIcon = Instance.new("ImageLabel")
	pgClassIcon.Position = UDim2.new(0, 3, 0, 3)
	pgClassIcon.Size = UDim2.new(0, 16, 0, 16)
	pgClassIcon.BackgroundTransparency = 1
	pgClassIcon.ZIndex = 30
	pgClassIcon.Parent = pgHeader

	local pgObjName = Instance.new("TextLabel")
	pgObjName:SetAttribute("No2006Font", true)
	pgObjName.Position = UDim2.new(0, 24, 0, 0)
	pgObjName.Size = UDim2.new(1, -28, 1, 0)
	pgObjName.BackgroundTransparency = 1
	pgObjName.Font = Enum.Font.ArialBold
	pgObjName.Text = "Level"
	pgObjName.TextSize = 11
	pgObjName.TextColor3 = Color3.fromRGB(0, 0, 0)
	pgObjName.TextXAlignment = Enum.TextXAlignment.Left
	pgObjName.ZIndex = 30
	pgObjName.Parent = pgHeader

	local pgList = Instance.new("ScrollingFrame")
	pgList.Position = UDim2.new(0, 4, 0, 52)
	pgList.Size = UDim2.new(1, -8, 1, -56)
	pgList.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	pgList.BorderSizePixel = 1
	pgList.BorderColor3 = Color3.fromRGB(160, 160, 160)
	pgList.ScrollBarThickness = 6
	pgList.CanvasSize = UDim2.new(0, 0, 0, 0)
	pgList.ZIndex = 29
	pgList.Parent = PropertyGridFrame

	local pgLayout = Instance.new("UIListLayout")
	pgLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pgLayout.Padding = UDim.new(0, 1)
	pgLayout.Parent = pgList

	local TIMER_UP_ACTIONS = { "Nothing", "Pause", "Lose", "Draw", "Win" }
	local TIMER_AFFECTS_SCORE = { "NoChange", "Increase", "Decrease" }
	local POSTURES = { "Stand", "Sit", "Climb" }

	local function cycleValue(list, cur)
		for i, v in ipairs(list) do
			if v == cur then
				return list[(i % #list) + 1]
			end
		end
		return list[1]
	end

	-- Rows: { Name, Value } read-only, + OnClick to cycle / toggle, or + Edit(text) for typed values
	local function refreshPropertyGrid()
		if not PropertyGridFrame.Visible then return end
		for _, ch in ipairs(pgList:GetChildren()) do
			if not ch:IsA("UIListLayout") then ch:Destroy() end
		end
		local rows = {}
		local obj = S.selectedObject
		if not obj or not obj.Parent then
			-- Nothing selected: the 2005 client showed the Level's game settings
			local lv = S.level
			pgObjName.Text = "Level"
			pgClassIcon.Image = ""
			table.insert(rows, { Name = "WinMessage", Value = lv.WinMessage, Edit = function(t) lv.WinMessage = t end })
			table.insert(rows, { Name = "LoseMessage", Value = lv.LoseMessage, Edit = function(t) lv.LoseMessage = t end })
			table.insert(rows, {
				Name = "HighScoreIsGood",
				Value = tostring(lv.HighScoreIsGood),
				OnClick = function()
					lv.HighScoreIsGood = not lv.HighScoreIsGood
					refreshPropertyGrid()
				end
			})
			table.insert(rows, {
				Name = "InitialTimerValue",
				Value = string.format("%g", lv.InitialTimerValue),
				Edit = function(t)
					local n = tonumber(t)
					if n and n >= 0 then
						lv.InitialTimerValue = n
						if not S.isSimulationRunning then
							S.currentTimerValue = n
							updateScoreTimerUI()
						end
					end
				end
			})
			table.insert(rows, {
				Name = "InitialScoreValue",
				Value = tostring(lv.InitialScoreValue),
				Edit = function(t)
					local n = tonumber(t)
					if n then
						lv.InitialScoreValue = math.floor(n)
						if not S.isSimulationRunning then
							S.bonusScore = lv.InitialScoreValue
							updateScoreTimerUI()
						end
					end
				end
			})
			table.insert(rows, {
				Name = "TimerUpAction",
				Value = lv.TimerUpAction,
				OnClick = function()
					lv.TimerUpAction = cycleValue(TIMER_UP_ACTIONS, lv.TimerUpAction)
					refreshPropertyGrid()
				end
			})
			table.insert(rows, {
				Name = "TimerAffectsScore",
				Value = lv.TimerAffectsScore,
				OnClick = function()
					lv.TimerAffectsScore = cycleValue(TIMER_AFFECTS_SCORE, lv.TimerAffectsScore)
					refreshPropertyGrid()
				end
			})
		else
			local isModel = obj:IsA("Model")
			pgObjName.Text = obj.Name
			pgClassIcon.Image = isModel and "rbxassetid://6436158391" or "rbxassetid://6436157520"
			local targetPart = getHandleTargetPart(obj)
			table.insert(rows, {
				Name = "Name",
				Value = obj.Name,
				Edit = function(t)
					if t ~= "" then obj.Name = t end
				end
			})
			table.insert(rows, {
				Name = "Controller",
				Value = tostring(obj:GetAttribute("ControllerType2005") or "None"),
				OnClick = function()
					attachControllerBadge(obj, cycleValue(S.CONTROLLER_ORDER_2005, obj:GetAttribute("ControllerType2005") or "None"))
					refreshPropertyGrid()
				end
			})
			table.insert(rows, {
				Name = "ControllerFlagShown",
				Value = tostring(obj:GetAttribute("ControllerFlagShown2005") ~= false),
				OnClick = function()
					attachControllerBadge(obj, obj:GetAttribute("ControllerType2005") or "None", obj:GetAttribute("ControllerFlagShown2005") == false)
					refreshPropertyGrid()
				end
			})
			table.insert(rows, {
				Name = "NameShown",
				Value = tostring(obj:GetAttribute("NameShown2005") == true),
				OnClick = function()
					setNameShown2005(obj, (obj:GetAttribute("NameShown2005") ~= true) and obj.Name or nil)
					refreshPropertyGrid()
				end
			})
			if targetPart then
				local isAnch = (targetPart:GetAttribute("AnchoredInGame") == true) or (S.isSimulationRunning and targetPart.Anchored)
				table.insert(rows, {
					Name = "Anchored",
					Value = tostring(isAnch),
					OnClick = function()
						local newAnch = not isAnch
						for _, p in ipairs(isModel and obj:GetDescendants() or { obj }) do
							if p:IsA("BasePart") and not p:GetAttribute("Is2005Bump") and not p:GetAttribute("IsSwingingArm2004") then
								p:SetAttribute("AnchoredInGame", newAnch)
								if S.isSimulationRunning then p.Anchored = newAnch end
							end
						end
						refreshPropertyGrid()
					end
				})
				table.insert(rows, {
					Name = "size",
					Value = string.format("%d, %d, %d", math.floor(targetPart.Size.X+0.5), math.floor(targetPart.Size.Y+0.5), math.floor(targetPart.Size.Z+0.5)),
				})
				table.insert(rows, {
					Name = "CoordinateFrame",
					Value = string.format("%d, %d, %d", math.floor(targetPart.Position.X+0.5), math.floor(targetPart.Position.Y+0.5), math.floor(targetPart.Position.Z+0.5)),
				})
				local c = targetPart.Color
				table.insert(rows, {
					Name = "Color",
					Value = string.format("%d, %d, %d", math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5)),
				})
			end
			if isModel and obj:GetAttribute("IsDynabloxFigure") then
				table.insert(rows, {
					Name = "PostureXML",
					Value = tostring(obj:GetAttribute("PostureXML") or "Stand"),
					OnClick = function()
						setFigurePose2004(obj, cycleValue(POSTURES, obj:GetAttribute("PostureXML") or "Stand"))
						refreshPropertyGrid()
					end
				})
			end
		end

		for i, r in ipairs(rows) do
			local rowFrame = Instance.new("Frame")
			rowFrame.LayoutOrder = i
			rowFrame.Size = UDim2.new(1, 0, 0, 20)
			rowFrame.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(246, 245, 240) or Color3.fromRGB(255, 255, 255)
			rowFrame.BorderSizePixel = 0
			rowFrame.ZIndex = 30
			rowFrame.Parent = pgList

			local kLbl = Instance.new("TextLabel")
			kLbl:SetAttribute("No2006Font", true)
			kLbl.Position = UDim2.new(0, 6, 0, 0)
			kLbl.Size = UDim2.new(0.5, -6, 1, 0)
			kLbl.BackgroundTransparency = 1
			kLbl.Font = Enum.Font.Arial
			kLbl.Text = r.Name
			kLbl.TextSize = 11
			kLbl.TextColor3 = Color3.fromRGB(30, 30, 30)
			kLbl.TextXAlignment = Enum.TextXAlignment.Left
			kLbl.TextTruncate = Enum.TextTruncate.AtEnd
			kLbl.ZIndex = 31
			kLbl.Parent = rowFrame

			if r.Edit then
				local box = Instance.new("TextBox")
				box:SetAttribute("No2006Font", true)
				box.Position = UDim2.new(0.5, 0, 0, 0)
				box.Size = UDim2.new(0.5, -4, 1, 0)
				box.BackgroundTransparency = 1
				box.ClearTextOnFocus = false
				box.Font = Enum.Font.Arial
				box.Text = r.Value
				box.TextSize = 11
				box.TextColor3 = Color3.fromRGB(15, 75, 185)
				box.TextXAlignment = Enum.TextXAlignment.Left
				box.TextTruncate = Enum.TextTruncate.AtEnd
				box.ZIndex = 31
				box.Parent = rowFrame
				storeConnection(box.FocusLost:Connect(function()
					r.Edit(box.Text)
					refreshPropertyGrid()
				end))
			else
				local vBtn = Instance.new("TextButton")
				vBtn:SetAttribute("No2006Font", true)
				vBtn.Position = UDim2.new(0.5, 0, 0, 0)
				vBtn.Size = UDim2.new(0.5, -4, 1, 0)
				vBtn.BackgroundTransparency = 1
				vBtn.Font = Enum.Font.ArialBold
				vBtn.Text = r.Value
				vBtn.TextSize = 11
				vBtn.TextColor3 = r.OnClick and Color3.fromRGB(15, 75, 185) or Color3.fromRGB(50, 50, 50)
				vBtn.TextXAlignment = Enum.TextXAlignment.Left
				vBtn.TextTruncate = Enum.TextTruncate.AtEnd
				vBtn.ZIndex = 31
				vBtn.Parent = rowFrame
				if r.OnClick then
					storeConnection(vBtn.MouseButton1Click:Connect(r.OnClick))
				end
			end
		end
		pgList.CanvasSize = UDim2.new(0, 0, 0, #rows * 21)
	end
	S.refreshPropertyGrid = refreshPropertyGrid

	local function togglePropertyGrid()
		PropertyGridFrame.Visible = not PropertyGridFrame.Visible
		refreshPropertyGrid()
	end

	-- Format > Set Model Front: the side of the model facing away from the camera becomes its front.
	-- Driving and Chase / Flee steer by that front, and the controller flag sits on the opposite side.
	local function setModelFront(obj)
		local root = getHandleTargetPart(obj)
		Camera = Workspace.CurrentCamera
		if not root or not Camera then return end
		local look = Camera.CFrame.LookVector
		local desiredYaw = math.atan2(-look.X, -look.Z)
		local _, curYaw, _ = root.CFrame:ToEulerAnglesYXZ()
		local quarter = math.pi / 2
		local offset = math.floor((desiredYaw - curYaw) / quarter + 0.5) * quarter
		root:SetAttribute("ModelFrontYaw2005", offset)
		playClassicSound(SOUND_BOOP, 0.45, 1)
	end
	S.setModelFront = setModelFront

	-- 11B. MENU popup (opened from the MENU label at the bottom of the left panel)
	local PopupMenuFrame = Instance.new("Frame")
	S.PopupMenuFrame = PopupMenuFrame
	PopupMenuFrame.Name = "PopupMenu2005"
	PopupMenuFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	PopupMenuFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	PopupMenuFrame.Size = UDim2.new(0, 270, 0, 290)
	PopupMenuFrame.BackgroundColor3 = Color3.fromRGB(155, 155, 155)
	PopupMenuFrame.BackgroundTransparency = 0.15
	PopupMenuFrame.BorderSizePixel = 2
	PopupMenuFrame.BorderColor3 = Color3.fromRGB(220, 220, 220)
	PopupMenuFrame.Visible = false
	PopupMenuFrame.Active = true
	PopupMenuFrame.ZIndex = 30
	PopupMenuFrame.Parent = ScreenGui

	-- (Addtion-Scripts) drawn as a Windows XP window: title bar with the title and a close button
	PopupMenuFrame.Size = UDim2.new(0, 270, 0, 300)
	local PopupBar = Instance.new("Frame")
	PopupBar.Name = "XPTitleBar"
	PopupBar.BorderSizePixel = 0
	PopupBar.ZIndex = 31
	PopupBar.Parent = PopupMenuFrame
	local PopupTitle = Instance.new("TextLabel")
	PopupTitle.BackgroundTransparency = 1
	PopupTitle.Text = "2005 GUI Settings"
	PopupTitle.Parent = PopupBar
	local PopupClose = Instance.new("TextButton")
	PopupClose.Name = "XPClose"
	PopupClose.Parent = PopupBar
	S.xpWindow(PopupMenuFrame, PopupBar, PopupTitle, PopupClose)
	storeConnection(PopupClose.MouseButton1Click:Connect(function()
		playClassicSound(SOUND_CLICK, 0.45, 1)
		PopupMenuFrame.Visible = false
	end))

	local ResetOrgBtn = Instance.new("ImageButton")
	ResetOrgBtn.AnchorPoint = Vector2.new(0.5, 0)
	ResetOrgBtn.Position = UDim2.new(0.5, 0, 0, 36)
	ResetOrgBtn.Size = UDim2.new(0, 130, 0, 32)
	ResetOrgBtn.BackgroundTransparency = 1
	ResetOrgBtn.ZIndex = 32
	ResetOrgBtn.Parent = PopupMenuFrame
	local ResetOrgFb = createMetallicOrbFallback(ResetOrgBtn, "RESET GAME", Color3.fromRGB(90, 60, 20), false, false, false)
	bindButtonSprites(ResetOrgBtn, ResetOrgFb, "ResetOrg", "ResetOrg_ovr", "ResetOrg_dn", "ResetOrg_ds")
	storeConnection(ResetOrgBtn.MouseButton1Click:Connect(function()
		reset2005Game()
		PopupMenuFrame.Visible = false
	end))

	local popupRows = 0
	local function createPopupBtn(text, callback)
		local posY = 76 + popupRows * 31
		popupRows = popupRows + 1
		local btn = Instance.new("TextButton")
		btn.AnchorPoint = Vector2.new(0.5, 0)
		btn.Position = UDim2.new(0.5, 0, 0, posY)
		btn.Size = UDim2.new(0, 230, 0, 25)
		btn.Text = ""
		btn.ZIndex = 31
		btn.Parent = PopupMenuFrame

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = text
		lbl.ZIndex = 32
		lbl.Parent = btn
		-- (Addtion-Scripts) an XP button
		S.xpButton(btn, lbl)

		storeConnection(btn.MouseButton1Click:Connect(function()
			playClassicSound(SOUND_CLICK, 0.45, 1)
			callback(lbl)
		end))
		return btn, lbl
	end

	createPopupBtn("Properties...", function()
		togglePropertyGrid()
		PopupMenuFrame.Visible = false
	end)

	-- Stud rendering settings (not part of the 2005 UI, so they live here instead of the Surface page)
	local function studModeText()
		return (S.studMode == "3D") and "Bumps: 3D (Click for 2D)" or "Bumps: 2D (Click for 3D)"
	end
	local function studRangeText()
		return string.format("3D Bump Range: %d studs", S.stud3DRange or 25)
	end
	local studModeLbl, studRangeLbl
	local function refreshStudLabels()
		studModeLbl.Text = studModeText()
		studRangeLbl.Text = studRangeText()
	end
	studModeLbl = select(2, createPopupBtn(studModeText(), function()
		if S.toggleStudMode then S.toggleStudMode() end
		refreshStudLabels()
	end))
	studRangeLbl = select(2, createPopupBtn(studRangeText(), function()
		if S.cycleStud3DRange then S.cycleStud3DRange() end
		refreshStudLabels()
	end))

	createPopupBtn("Players: 863/864 Figure (Click: 862)", function(lbl)
		S.playerModelStyle = (S.playerModelStyle == "Figure863_864") and "Man862" or "Figure863_864"
		lbl.Text = (S.playerModelStyle == "Figure863_864") and "Players: 863/864 Figure (Click: 862)" or "Players: 862 Man Figure (Click: 863)"
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character then
				pcall(convertCharacterTo2005Model, p.Character, true)
			end
		end
	end)

	createPopupBtn("Clear Spawned 2005 Models", function()
		SpawnedModelsFolder:ClearAllChildren()
		selectStudioObject(nil)
		PopupMenuFrame.Visible = false
	end)

	createPopupBtn("Close Menu", function()
		PopupMenuFrame.Visible = false
	end)

	createPopupBtn("Exit Game", function()
		pcall(function() game:Shutdown() end)
	end)

	storeConnection(MenuBtn.MouseButton1Click:Connect(function()
		playClassicSound(SOUND_CLICK, 0.45, 1)
		PopupMenuFrame.Visible = not PopupMenuFrame.Visible
	end))

	-- 11C. Top bar drop-down menus (Windows-style list under the clicked menu title)
	local DropdownFrame = Instance.new("Frame")
	S.TopbarDropdownFrame = DropdownFrame
	DropdownFrame.Name = "TopbarDropdown2004"
	DropdownFrame.Position = UDim2.new(0, 0, 0, 25)
	DropdownFrame.Size = UDim2.new(0, 180, 0, 100)
	DropdownFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	DropdownFrame.BorderSizePixel = 1
	DropdownFrame.BorderColor3 = Color3.fromRGB(172, 168, 153)
	DropdownFrame.Visible = false
	DropdownFrame.Active = true
	DropdownFrame.ZIndex = 35
	DropdownFrame.Parent = ScreenGui

	local activeDropdownMenuName = nil
	local function closeTopbarDropdown()
		DropdownFrame.Visible = false
		activeDropdownMenuName = nil
	end
	S.closeTopbarDropdown = closeTopbarDropdown

	local function setToolboxVisible(visible)
		S.BottomBar.Visible = visible
		S.BottomLeftTabs.Visible = visible
	end

	local function selectedFigure()
		local obj = S.selectedObject
		return (obj and obj:IsA("Model") and obj:GetAttribute("IsDynabloxFigure")) and obj or S.localPlayerRig
	end

	-- October 2005 menus. File / Insert follow the recreated client; the rest only use 2005 commands.
	local menus2005 = {
		File = {
			{ Text = "New", Action = function()
				if S.isSimulationRunning then stop2005Simulation() end
				SpawnedModelsFolder:ClearAllChildren()
				selectStudioObject(nil)
			end },
			{ Text = "Open...", Disabled = true },
			{ Text = "Close", Action = function() pcall(function() game:Shutdown() end) end },
		},
		Edit = {
			{ Text = "Duplicate", Action = function() duplicateSelectedObject() end },
			{ Text = "Group", Action = function() S.groupSelectedObject() end },
			{ Text = "UnGroup", Action = function() S.ungroupSelectedObject() end },
			{ Text = "Delete", Shortcut = "Del", Action = function() S.deleteSelectedStudioObject() end },
			{ Text = "Rotate", Shortcut = "R", Action = function() rotateSelectedObject(90, 0) end },
			{ Text = "Tilt", Shortcut = "T", Action = function() rotateSelectedObject(0, 90) end },
		},
		View = {
			{ Text = "Toolbox", Action = function() setToolboxVisible(not S.BottomBar.Visible) end },
			{ Text = "CameraMenu", Action = function() S.CameraMenuFrame.Visible = not S.CameraMenuFrame.Visible end },
			{ Text = "Properties", Action = togglePropertyGrid },
			{ Text = "FPS", Action = function() FPSLabel.Visible = not FPSLabel.Visible end },
		},
		Insert = {
			{ Text = "Model...", Action = function()
				setToolboxVisible(true)
				S.activeTab = "Model"
				rebuildBottomBarContent()
			end },
		},
		Format = {
			{ Text = "Set Model Front", Action = function() setModelFront(S.selectedObject) end },
			{ Text = "Posture: Stand", Action = function() setFigurePose2004(selectedFigure(), "Stand") end },
			{ Text = "Posture: Sit", Action = function() setFigurePose2004(selectedFigure(), "Sit") end },
			{ Text = "Posture: Climb", Action = function() setFigurePose2004(selectedFigure(), "Climb") end },
		},
	}

	local function openTopbarDropdown(menuKey, posX)
		if activeDropdownMenuName == menuKey and DropdownFrame.Visible then
			closeTopbarDropdown()
			return
		end
		local items = menus2005[menuKey]
		if not items then return end
		activeDropdownMenuName = menuKey
		for _, ch in ipairs(DropdownFrame:GetChildren()) do ch:Destroy() end
		local rowH = 22
		DropdownFrame.Position = UDim2.new(0, posX, 0, 25)
		DropdownFrame.Size = UDim2.new(0, 180, 0, #items * rowH + 4)
		DropdownFrame.Visible = true

		for idx, item in ipairs(items) do
			local rowBtn = Instance.new("TextButton")
			rowBtn:SetAttribute("No2006Font", true)
			rowBtn.Position = UDim2.new(0, 2, 0, (idx - 1) * rowH + 2)
			rowBtn.Size = UDim2.new(1, -4, 0, rowH)
			rowBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			rowBtn.BackgroundTransparency = 0
			rowBtn.BorderSizePixel = 0
			rowBtn.AutoButtonColor = false
			rowBtn.Text = ""
			rowBtn.ZIndex = 36
			rowBtn.Parent = DropdownFrame

			local tLbl = Instance.new("TextLabel")
			tLbl:SetAttribute("No2006Font", true)
			tLbl.Position = UDim2.new(0, 20, 0, 0)
			tLbl.Size = UDim2.new(1, -70, 1, 0)
			tLbl.BackgroundTransparency = 1
			tLbl.Font = Enum.Font.Arial
			tLbl.Text = item.Text
			tLbl.TextSize = 12
			tLbl.TextColor3 = item.Disabled and Color3.fromRGB(172, 168, 153) or Color3.fromRGB(0, 0, 0)
			tLbl.TextXAlignment = Enum.TextXAlignment.Left
			tLbl.ZIndex = 37
			tLbl.Parent = rowBtn

			local sLbl = nil
			if item.Shortcut then
				sLbl = Instance.new("TextLabel")
				sLbl:SetAttribute("No2006Font", true)
				sLbl.Position = UDim2.new(1, -46, 0, 0)
				sLbl.Size = UDim2.new(0, 40, 1, 0)
				sLbl.BackgroundTransparency = 1
				sLbl.Font = Enum.Font.Arial
				sLbl.Text = item.Shortcut
				sLbl.TextSize = 11
				sLbl.TextColor3 = Color3.fromRGB(0, 0, 0)
				sLbl.TextXAlignment = Enum.TextXAlignment.Right
				sLbl.ZIndex = 37
				sLbl.Parent = rowBtn
			end

			if not item.Disabled then
				-- Windows XP menu highlight: white text on the system Highlight blue
				storeConnection(rowBtn.MouseEnter:Connect(function()
					rowBtn.BackgroundColor3 = Color3.fromRGB(49, 106, 197)
					tLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
					if sLbl then sLbl.TextColor3 = Color3.fromRGB(255, 255, 255) end
				end))
				storeConnection(rowBtn.MouseLeave:Connect(function()
					rowBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					tLbl.TextColor3 = Color3.fromRGB(0, 0, 0)
					if sLbl then sLbl.TextColor3 = Color3.fromRGB(0, 0, 0) end
				end))
			end
			storeConnection(rowBtn.MouseButton1Click:Connect(function()
				if item.Disabled then return end
				closeTopbarDropdown()
				playClassicSound(SOUND_CLICK, 0.4, 1)
				if item.Action then item.Action() end
			end))
		end
	end

	-- 2005: five 125px-wide menu titles from the left edge, white 16px text with a grey outline
	local menuLayouts = {
		["2005_STUDIO"] = {
			{ Name = "FileBtn",   MenuKey = "File",   Text = "File",   X = 0,   W = 125 },
			{ Name = "EditBtn",   MenuKey = "Edit",   Text = "Edit",   X = 125, W = 125 },
			{ Name = "ViewBtn",   MenuKey = "View",   Text = "View",   X = 250, W = 125 },
			{ Name = "InsertBtn", MenuKey = "Insert", Text = "Insert", X = 375, W = 125 },
			{ Name = "FormatBtn", MenuKey = "Format", Text = "Format", X = 500, W = 125 },
		},
		["CLASSIC_5"] = {
			{ Name = "ToolsBtn",      MenuKey = "Edit",   Text = "Tools",      X = 10,  W = 85 },
			{ Name = "InsertBtn",     MenuKey = "Insert", Text = "Insert",     X = 110, W = 85 },
			{ Name = "FullscreenBtn", MenuKey = "View",   Text = "Fullscreen", X = 210, W = 110 },
			{ Name = "HelpBtn",       MenuKey = "Format", Text = "Help...",    X = 335, W = 85 },
			{ Name = "ExitBtn",       MenuKey = nil,      Text = "Exit",       X = 435, W = 75 },
		}
	}

	local function createTopMenuButton(name, text, posX, width)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(0, width or 90, 0, 25)
		btn.Position = UDim2.new(0, posX, 0, 0)
		btn.BackgroundColor3 = Color3.fromRGB(153, 153, 153)
		btn.BackgroundTransparency = 1
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		btn.Text = ""
		btn.Parent = TopBar

		local caption = Instance.new("TextLabel")
		caption.Name = "ButtonText"
		caption.Position = UDim2.new(0, 10, 0, 0)
		caption.Size = UDim2.new(1, -10, 1, 0)
		caption.BackgroundTransparency = 1
		caption.Text = text
		caption.TextColor3 = Color3.fromRGB(255, 255, 255)
		caption.TextStrokeColor3 = Color3.fromRGB(128, 128, 128)
		caption.TextStrokeTransparency = 0.5
		caption.TextSize = 16
		caption.TextXAlignment = Enum.TextXAlignment.Left
		caption.Parent = btn
		apply2006Font(caption)

		-- hover box: the same translucent grey as the panels
		storeConnection(btn.MouseEnter:Connect(function() btn.BackgroundTransparency = 0.6 end))
		storeConnection(btn.MouseLeave:Connect(function() btn.BackgroundTransparency = 1 end))
		return btn
	end

	local function rebuildTopBarButtons()
		for _, child in ipairs(TopBar:GetChildren()) do
			child:Destroy()
		end
		local items = menuLayouts[Config.TOPBAR_STYLE] or menuLayouts["2005_STUDIO"]
		for _, info in ipairs(items) do
			local btn = createTopMenuButton(info.Name, info.Text, info.X, info.W)
			storeConnection(btn.MouseButton1Click:Connect(function()
				playClassicSound(SOUND_CLICK, 0.4, 1)
				if info.Name == "ExitBtn" then
					pcall(function() game:Shutdown() end)
				elseif info.MenuKey then
					openTopbarDropdown(info.MenuKey, info.X)
				else
					PopupMenuFrame.Visible = not PopupMenuFrame.Visible
				end
			end))
		end
	end
	rebuildTopBarButtons()

	S.freeCamEnabled = true
end

--========================================================
-- 12. RETRO CAMERA (MAIN + OPACITY + POPPERCAM) & CAMERAMENU
--========================================================
local ContextActionService = safeGetService("ContextActionService")

if _G.RetroCameraHooks then
	pcall(function() RunService:UnbindFromRenderStep("RetroCamera") end)
	if _G.RetroCamMain then pcall(function() _G.RetroCamMain:DisconnectInputEvents() end) end
	if _G.RetroCamOpacityConn then pcall(function() _G.RetroCamOpacityConn:Disconnect() end) end
end
_G.RetroCameraHooks = true

storeConnection({
	Disconnect = function()
		pcall(function() RunService:UnbindFromRenderStep("RetroCamera") end)
		if _G.RetroCamMain then pcall(function() _G.RetroCamMain:DisconnectInputEvents() end) end
		if _G.RetroCamOpacityConn then pcall(function() _G.RetroCamOpacityConn:Disconnect() end) end
	end
})

-- [[ MODULE: MAIN CAMERA ]]
local Main = {}
S._run = (function()
	local GuiService = safeGetService("GuiService")
	local TeleportService = safeGetService("TeleportService")
	local Debris = safeGetService("Debris")
	local GameSettings = nil
	pcall(function()
		GameSettings = UserSettings():GetService("UserGameSettings")
	end)

	local function getCameraYInvert()
		local val = 1
		if GameSettings then
			pcall(function() val = GameSettings:GetCameraYInvertValue() end)
		end
		return val or 1
	end

	local function getGamepadSensitivity()
		local val = 1
		if GameSettings then
			pcall(function() val = GameSettings.GamepadCameraSensitivity end)
		end
		return val or 1
	end

	local function isDynamicThumbstickMode()
		local isDyn = false
		if GameSettings then
			pcall(function() isDyn = (GameSettings.TouchMovementMode == Enum.TouchMovementMode.DynamicThumbstick) end)
		end
		return isDyn
	end

	local math_abs = math.abs
	local math_asin = math.asin
	local math_atan2 = math.atan2
	local math_floor = math.floor
	local math_min = math.min
	local math_max = math.max
	local math_pi = math.pi
	local math_rad = math.rad
	local Vector2_new = Vector2.new
	local Vector3_new = Vector3.new
	local CFrame_Angles = CFrame.Angles
	local CFrame_new = CFrame.new

	local MIN_Y = math_rad(-80)
	local MAX_Y = math_rad(80)

	local ZERO_VECTOR2 = Vector2_new()
	local ZERO_VECTOR3 = Vector3_new()
	local UP_VECTOR = Vector3_new(0, 1, 0)
	local XZ_VECTOR = Vector3_new(1, 0, 1)

	local TOUCH_SENSITIVTY = Vector2_new(math_pi*2.25, math_pi*2)
	local MOUSE_SENSITIVITY = Vector2_new(math_pi*4, math_pi*1.9)

	local THUMBSTICK_DEADZONE = 0.2
	local DEADZONE = 0.1
	local ZOOM_FACTOR = 0.25

	local humanoid

	local function findPlayerHumanoid(player)
		local character = player and player.Character
		if character then
			if not (humanoid and humanoid.Parent == character) then
				humanoid = character:FindFirstChildOfClass("Humanoid")
			end
		end
		return humanoid
	end

	local function clamp(low, high, num)
		return (num > high and high or num < low and low or num)
	end

	local function findAngleBetweenXZVectors(vec2, vec1)
		return math_atan2(vec1.X*vec2.Z-vec1.Z*vec2.X, vec1.X*vec2.X + vec1.Z*vec2.Z)
	end

	local function IsFinite(num)
		return num == num and num ~= 1/0 and num ~= -1/0
	end

	local function SCurveTranform(t)
		t = clamp(-1,1,t)
		if t >= 0 then
			return (.35*t) / (.35 - t + 1)
		end
		return -((.8*-t) / (.8 + t + 1))
	end

	local function toSCurveSpace(t)
		return (1 + DEADZONE) * (2*math.abs(t) - 1) - DEADZONE
	end

	local function fromSCurveSpace(t)
		return t/2 + 0.5
	end

	local function gamepadLinearToCurve(thumbstickPosition)
		local function onAxis(axisValue)
			local sign = 1
			if axisValue < 0 then
				sign = -1
			end
			local point = fromSCurveSpace(SCurveTranform(toSCurveSpace(math_abs(axisValue))))
			point = point * sign
			return clamp(-1, 1, point)
		end
		return Vector2_new(onAxis(thumbstickPosition.x), onAxis(thumbstickPosition.y))
	end

	local SetCameraOnSpawn = true
	local this = Main

	local isFirstPerson = false
	local isRightMouseDown = false
	local isMiddleMouseDown = false

	this.Enabled = false
	this.RotateInput = ZERO_VECTOR2
	this.DefaultZoom = 12.5
	this.activeGamepad = nil
	this.PartSubjectHack = nil

	function this:GetHumanoid()
		local player = Players.LocalPlayer
		return findPlayerHumanoid(player)
	end

	function this:GetHumanoidRootPart()
		local hum = this:GetHumanoid()
		return hum and (hum.Torso or (hum.Parent and hum.Parent:FindFirstChild("HumanoidRootPart")))
	end

	function this:GetObjectFocusPosition(obj)
		if not obj then return nil end
		if obj:IsA("BasePart") and obj.Parent then
			return obj.Position
		elseif obj:IsA("Model") and obj.Parent then
			local rig = (S.rigRegistry and S.rigRegistry[obj]) or obj:FindFirstChild("Dynablox2005Rig")
			local rigHead = rig and rig:FindFirstChild("Head", true)
			if rigHead and rigHead:IsA("BasePart") then
				return rigHead.Position
			end
			local pp = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso") or obj:FindFirstChildWhichIsA("BasePart", true)
			if pp and pp:IsA("BasePart") then
				return pp.Position + Vector3_new(0, 1.2, 0)
			end
		end
		return nil
	end

	function this:GetPlayerModelPosition()
		local char = Players.LocalPlayer and Players.LocalPlayer.Character
		local pos = this:GetObjectFocusPosition(char)
		return pos or Vector3_new(0, 10, 0)
	end

	function this:GetControlledModelPosition()
		local m = S.activeControlledModel
		if m and m.Parent and (S.isSimulationRunning or m == LocalPlayer.Character) then
			if S.isKeyboardController(m:GetAttribute("ControllerType2005")) then
				local p = this:GetObjectFocusPosition(m)
				if p then return p end
			end
		end
		if LocalPlayer.Character then
			return this:GetObjectFocusPosition(LocalPlayer.Character)
		end
		if S.controlledObjects then
			for obj, ctrl in pairs(S.controlledObjects) do
				if obj and obj.Parent and S.isKeyboardController(ctrl) then
					local p = this:GetObjectFocusPosition(obj)
					if p then return p end
				end
			end
		end
		return nil
	end

	function this:GetSubjectPosition()
		if not this.FreeCamFocus then
			this.FreeCamFocus = this:GetPlayerModelPosition()
		end
		-- Always stay in 100% FreeCam (never lock onto a player)!
		return this.FreeCamFocus
	end

	function this:GetCameraLook()
		return workspace.CurrentCamera and workspace.CurrentCamera.CFrame.lookVector or Vector3_new(0,0,1)
	end

	function this:GetCameraZoom()
		if this.currentZoom == nil then
			local player = Players.LocalPlayer
			this.currentZoom = player and clamp(player.CameraMinZoomDistance, player.CameraMaxZoomDistance, this.DefaultZoom) or this.DefaultZoom
		end
		return this.currentZoom
	end

	function this:GetCameraActualZoom()
		local camera = workspace.CurrentCamera
		if camera then
			return (camera.CFrame.p - camera.Focus.p).Magnitude
		end
	end

	function this:ViewSizeX()
		local result = 1024
		local camera = workspace.CurrentCamera
		if camera then
			result = camera.ViewportSize.X
		end
		return result
	end

	function this:ViewSizeY()
		local result = 768
		local camera = workspace.CurrentCamera
		if camera then
			result = camera.ViewportSize.Y
		end
		return result
	end

	function this:ScreenTranslationToAngle(translationVector)
		local screenX = this:ViewSizeX()
		local screenY = this:ViewSizeY()
		local xTheta = (translationVector.x / screenX)
		local yTheta = (translationVector.y / screenY)
		return Vector2_new(xTheta, yTheta)
	end

	function this:MouseTranslationToAngle(translationVector)
		local xTheta = (translationVector.x / 1920)
		local yTheta = (translationVector.y / 1200)
		return Vector2_new(xTheta, yTheta)
	end

	function this:RotateVector(startVector, xyRotateVector)
		local startCFrame = CFrame_new(ZERO_VECTOR3, startVector)
		local resultLookVector = (CFrame_Angles(0, -xyRotateVector.x, 0) * startCFrame * CFrame_Angles(-xyRotateVector.y,0,0)).lookVector
		return resultLookVector, Vector2_new(xyRotateVector.x, xyRotateVector.y)
	end

	function this:RotateCamera(startLook, xyRotateVector)
		local startVertical = math_asin(clamp(-1, 1, startLook.y))
		local yTheta = clamp(-MAX_Y + startVertical, -MIN_Y + startVertical, xyRotateVector.y)
		return self:RotateVector(startLook, Vector2_new(xyRotateVector.x, yTheta))
	end

	function this:IsInFirstPerson()
		return isFirstPerson
	end

	function this:UpdateMouseBehavior()
		pcall(function()
			if isFirstPerson or this.PartSubjectHack then
				GameSettings.RotationType = Enum.RotationType.CameraRelative
				UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			else
				GameSettings.RotationType = Enum.RotationType.MovementRelative
				if isRightMouseDown or isMiddleMouseDown then
					UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
				else
					UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				end
			end
		end)
	end

	function this:PlayTick()
		local now = tick()
		local lastTickSound = this.LastTickSound or 0
		if (now - lastTickSound) > .03 then
			pcall(function()
				local s = Instance.new("Sound")
				s.SoundId = "rbxasset://sounds/switch3.wav"
				s.Parent = SoundService
				s:Play()
				Debris:AddItem(s, 1)
			end)
			this.LastTickSound = now
		end
	end

	function this:ZoomCamera(desiredZoom)
		this.currentZoom = clamp(0.25, 400, desiredZoom)
		isFirstPerson = self:GetCameraZoom() < 1.5
		self:UpdateMouseBehavior()
		return self:GetCameraZoom()
	end

	function this:ZoomCameraBy(input)
		local zoom = this:GetCameraActualZoom() or this:GetCameraZoom()
		if zoom then
			if input > 0 then
				zoom = math_max(1, zoom / (1 + ZOOM_FACTOR*input))
			elseif input < 0 then
				zoom = math_min(5000, zoom * (1 - ZOOM_FACTOR*input))
			end
			self:ZoomCamera(zoom)
		end
		self:PlayTick()
		return self:GetCameraZoom()
	end

	function this:ZoomCameraFixedBy(zoomIncrement)
		return self:ZoomCamera(self:GetCameraZoom() + zoomIncrement)
	end

	local startPos = nil
	local lastPos = nil
	local panBeginLook = nil
	local fingerTouches = {}
	local NumUnsunkTouches = 0
	local inputStartPositions = {}
	local inputStartTimes = {}
	local StartingDiff = nil
	local pinchBeginZoom = nil
	local flaggedDynamic = {}
	local thumbstickTouch = nil
	local thumbstickStartPos = nil
	local thumbstickCurPos = nil

	this.ZoomEnabled = true
	this.PanEnabled = true
	this.KeyPanEnabled = true

	local function inputIsDynamic(input)
		if flaggedDynamic[input] ~= nil then
			return flaggedDynamic[input]
		end
		if not isDynamicThumbstickMode() then
			return false
		end
		flaggedDynamic[input] = false
		return false
	end

	local function OnTouchBegan(input, processed)
		if processed and not thumbstickTouch and input.Position.X < this:ViewSizeX() * 0.48 and input.Position.Y > this:ViewSizeY() * 0.42 then
			thumbstickTouch = input
			thumbstickStartPos = input.Position
			thumbstickCurPos = input.Position
		end
		if not inputIsDynamic(input) then
			fingerTouches[input] = processed
			if not processed then
				inputStartPositions[input] = input.Position
				inputStartTimes[input] = tick()
				NumUnsunkTouches = NumUnsunkTouches + 1
			end
		end
	end

	local function OnTouchChanged(input, processed)
		if S.isDraggingObject or (S.isArrowDragging and S.isArrowDragging()) then
			panBeginLook = nil
			startPos = nil
			lastPos = nil
			StartingDiff = nil
			pinchBeginZoom = nil
			this.UserPanningTheCamera = false
			return
		end
		if input == thumbstickTouch then
			thumbstickCurPos = input.Position
		end
		if inputIsDynamic(input) then return end
		if fingerTouches[input] == nil then
			fingerTouches[input] = processed
			if not processed then
				NumUnsunkTouches = NumUnsunkTouches + 1
			end
		end
		if NumUnsunkTouches == 1 then
			if fingerTouches[input] == false and not S.isDraggingObject and not (S.isArrowDragging and S.isArrowDragging()) then
				panBeginLook = panBeginLook or this:GetCameraLook()
				startPos = startPos or input.Position
				lastPos = lastPos or startPos
				this.UserPanningTheCamera = true
				local delta = input.Position - lastPos
				delta = Vector2_new(delta.X, delta.Y * getCameraYInvert())
				if this.PanEnabled then
					local desiredXYVector = this:ScreenTranslationToAngle(delta) * TOUCH_SENSITIVTY
					this.RotateInput = this.RotateInput + desiredXYVector
				end
				lastPos = input.Position
			end
		else
			panBeginLook = nil
			startPos = nil
			lastPos = nil
			this.UserPanningTheCamera = false
		end

		if NumUnsunkTouches == 2 then
			local unsunkTouches = {}
			for touch, wasSunk in pairs(fingerTouches) do
				if not wasSunk then
					table.insert(unsunkTouches, touch)
				end
			end
			if #unsunkTouches == 2 then
				local difference = (unsunkTouches[1].Position - unsunkTouches[2].Position).magnitude
				if StartingDiff and pinchBeginZoom then
					local scale = difference / math_max(0.01, StartingDiff)
					local clampedScale = clamp(0.1, 10, scale)
					if this.ZoomEnabled then
						this:ZoomCamera(pinchBeginZoom / clampedScale)
						this:PlayTick()
					end
				else
					StartingDiff = difference
					pinchBeginZoom = this:GetCameraActualZoom()
				end
			end
		else
			StartingDiff = nil
			pinchBeginZoom = nil
		end
	end

	local function OnTouchEnded(input, processed)
		if input == thumbstickTouch then
			thumbstickTouch = nil
			thumbstickStartPos = nil
			thumbstickCurPos = nil
		end
		if fingerTouches[input] == false then
			if NumUnsunkTouches == 1 then
				panBeginLook = nil
				startPos = nil
				lastPos = nil
			elseif NumUnsunkTouches == 2 then
				StartingDiff = nil
				pinchBeginZoom = nil
			end
		end
		if fingerTouches[input] ~= nil and fingerTouches[input] == false then
			NumUnsunkTouches = NumUnsunkTouches - 1
		end
		fingerTouches[input] = nil
		inputStartPositions[input] = nil
		inputStartTimes[input] = nil
		flaggedDynamic[input] = nil
	end

	local function OnMousePanButtonPressed(input, processed)
		if processed then return end
		this:UpdateMouseBehavior()
		panBeginLook = panBeginLook or this:GetCameraLook()
		startPos = startPos or input.Position
		lastPos = lastPos or startPos
		this.UserPanningTheCamera = true
	end

	local function OnMousePanButtonReleased(input, processed)
		this:UpdateMouseBehavior()
		if not (isRightMouseDown or isMiddleMouseDown) then
			panBeginLook = nil
			startPos = nil
			lastPos = nil
			this.UserPanningTheCamera = false
		end
	end

	local function OnMouse2Down(input, processed)
		if processed then return end
		isRightMouseDown = true
		OnMousePanButtonPressed(input, processed)
	end

	local function OnMouse2Up(input, processed)
		isRightMouseDown = false
		OnMousePanButtonReleased(input, processed)
	end

	local function OnMouse3Down(input, processed)
		if processed then return end
		isMiddleMouseDown = true
		OnMousePanButtonPressed(input, processed)
	end

	local function OnMouse3Up(input, processed)
		isMiddleMouseDown = false
		OnMousePanButtonReleased(input, processed)
	end

	local function OnMouseMoved(input, processed)
		if S.isDraggingObject or (S.isArrowDragging and S.isArrowDragging()) then
			return
		end
		local inputDelta = input.Delta
		inputDelta = Vector2_new(inputDelta.X, inputDelta.Y * getCameraYInvert())
		if startPos and lastPos and panBeginLook then
			local currPos = lastPos + input.Delta
			if this.PanEnabled then
				local desiredXYVector = this:MouseTranslationToAngle(inputDelta) * MOUSE_SENSITIVITY
				this.RotateInput = this.RotateInput + desiredXYVector
			end
			lastPos = currPos
		elseif (this:IsInFirstPerson() or this.PartSubjectHack) and this.PanEnabled then
			local desiredXYVector = this:MouseTranslationToAngle(inputDelta) * MOUSE_SENSITIVITY
			this.RotateInput = this.RotateInput + desiredXYVector
		end
	end

	local function OnMouseWheel(input, processed)
		if not processed and this.ZoomEnabled then
			this:ZoomCameraBy(clamp(-1, 1, input.Position.Z))
		end
	end

	local function round(num)
		return math_floor(num + 0.5)
	end
	local eight2Pi = math_pi / 4

	local function rotateVectorByAngleAndRound(camLook, rotateAngle, roundAmount)
		if camLook ~= ZERO_VECTOR3 then
			camLook = camLook.unit
			local currAngle = math_atan2(camLook.z, camLook.x)
			local newAngle = round((math_atan2(camLook.z, camLook.x) + rotateAngle) / roundAmount) * roundAmount
			return newAngle - currAngle
		end
		return 0
	end
	this.RotateVectorByAngleAndRound = rotateVectorByAngleAndRound

	local function OnKeyDown(input, processed)
		if processed then return end
		if this.ZoomEnabled then
			if input.KeyCode == Enum.KeyCode.I then
				this:ZoomCameraBy(1)
			elseif input.KeyCode == Enum.KeyCode.O then
				this:ZoomCameraBy(-1)
			end
		end
		if panBeginLook == nil and this.KeyPanEnabled then
			if input.KeyCode == Enum.KeyCode.Left then
				this.TurningLeft = true
			elseif input.KeyCode == Enum.KeyCode.Right then
				this.TurningRight = true
			elseif input.KeyCode == Enum.KeyCode.Comma then
				local angle = rotateVectorByAngleAndRound(this:GetCameraLook() * Vector3_new(1,0,1), -eight2Pi * (3/4), eight2Pi)
				if angle ~= 0 then
					this.RotateInput = this.RotateInput + Vector2_new(angle, 0)
					this.LastUserPanCamera = tick()
					this.LastCameraTransform = nil
				end
				this:PlayTick()
			elseif input.KeyCode == Enum.KeyCode.Period then
				local angle = rotateVectorByAngleAndRound(this:GetCameraLook() * Vector3_new(1,0,1), eight2Pi * (3/4), eight2Pi)
				if angle ~= 0 then
					this.RotateInput = this.RotateInput + Vector2_new(angle, 0)
					this.LastUserPanCamera = tick()
					this.LastCameraTransform = nil
				end
				this:PlayTick()
			elseif input.KeyCode == Enum.KeyCode.PageUp then
				this.RotateInput = this.RotateInput + Vector2_new(0, math_pi/12)
				this.LastCameraTransform = nil
				this:PlayTick()
			elseif input.KeyCode == Enum.KeyCode.PageDown then
				this.RotateInput = this.RotateInput + Vector2_new(0, -math_pi/12)
				this.LastCameraTransform = nil
				this:PlayTick()
			end
		end
	end

	local function OnKeyUp(input, processed)
		if input.KeyCode == Enum.KeyCode.Left then
			this.TurningLeft = false
		elseif input.KeyCode == Enum.KeyCode.Right then
			this.TurningRight = false
		end
	end

	local lastThumbstickRotate = nil
	local numOfSeconds = 0.7
	local currentSpeed = 0
	local maxSpeed = 6
	local lastThumbstickPos = Vector2_new(0,0)
	local ySensitivity = 0.65
	local lastVelocity = nil

	function this:UpdateGamepad()
		local gamepadPan = this.GamepadPanningCamera
		if gamepadPan then
			gamepadPan = gamepadLinearToCurve(gamepadPan)
			local currentTime = tick()
			if gamepadPan.X ~= 0 or gamepadPan.Y ~= 0 then
				this.userPanningTheCamera = true
			elseif gamepadPan == ZERO_VECTOR2 then
				lastThumbstickRotate = nil
				if lastThumbstickPos == ZERO_VECTOR2 then
					currentSpeed = 0
				end
			end
			local finalConstant = 0
			if lastThumbstickRotate then
				local elapsed = (currentTime - lastThumbstickRotate) * 10
				currentSpeed = currentSpeed + (maxSpeed * ((elapsed*elapsed)/numOfSeconds))
				if currentSpeed > maxSpeed then currentSpeed = maxSpeed end
				if lastVelocity then
					local velocity = (gamepadPan - lastThumbstickPos)/(currentTime - lastThumbstickRotate)
					local velocityDeltaMag = (velocity - lastVelocity).magnitude
					if velocityDeltaMag > 12 then
						currentSpeed = currentSpeed * (20/velocityDeltaMag)
						if currentSpeed > maxSpeed then currentSpeed = maxSpeed end
					end
				end
				local gamepadCameraSensitivity = getGamepadSensitivity()
				finalConstant = (gamepadCameraSensitivity * currentSpeed)
				lastVelocity = (gamepadPan - lastThumbstickPos)/(currentTime - lastThumbstickRotate)
			end
			lastThumbstickPos = gamepadPan
			lastThumbstickRotate = currentTime
			return Vector2_new(gamepadPan.X * finalConstant, gamepadPan.Y * finalConstant * ySensitivity * getCameraYInvert())
		end
		return ZERO_VECTOR2
	end

	local InputEvents = {}

	function this:DisconnectInputEvents()
		while true do
			local signalName = next(InputEvents)
			if signalName then
				InputEvents[signalName]:Disconnect()
				InputEvents[signalName] = nil
			else
				break
			end
		end
		this.TurningLeft = false
		this.TurningRight = false
		this.LastCameraTransform = nil
		this.UserPanningTheCamera = false
		this.RotateInput = ZERO_VECTOR2
		this.GamepadPanningCamera = ZERO_VECTOR2
		startPos = nil
		lastPos = nil
		panBeginLook = nil
		isRightMouseDown = false
		isMiddleMouseDown = false
		fingerTouches = {}
		NumUnsunkTouches = 0
		StartingDiff = nil
		pinchBeginZoom = nil
		pcall(function()
			if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
		end)
	end

	local function resetInputStates()
		isRightMouseDown = false
		isMiddleMouseDown = false
		OnMousePanButtonReleased()
		if UserInputService.TouchEnabled then
			for inputObject, _ in pairs(fingerTouches) do
				fingerTouches[inputObject] = nil
			end
			panBeginLook = nil
			startPos = nil
			lastPos = nil
			this.UserPanningTheCamera = false
			StartingDiff = nil
			pinchBeginZoom = nil
			NumUnsunkTouches = 0
		end
	end

	local function getGamepadPan(name, state, input)
		if input.UserInputType == this.activeGamepad and input.KeyCode == Enum.KeyCode.Thumbstick2 then
			if state == Enum.UserInputState.Cancel then
				this.GamepadPanningCamera = ZERO_VECTOR2
				return
			end
			local inputVector = Vector2_new(input.Position.X, -input.Position.Y)
			if inputVector.magnitude > THUMBSTICK_DEADZONE then
				this.GamepadPanningCamera = Vector2_new(input.Position.X, -input.Position.Y)
			else
				this.GamepadPanningCamera = ZERO_VECTOR2
			end
		end
	end

	local function doGamepadZoom(name, state, input)
		if input.UserInputType == this.activeGamepad and input.KeyCode == Enum.KeyCode.ButtonR3 and state == Enum.UserInputState.Begin then
			if this.ZoomEnabled then
				if this:GetCameraZoom() > 0.5 then
					this:ZoomCamera(0)
				else
					this:ZoomCamera(10)
				end
			end
		end
	end

	local function assignActivateGamepad()
		local connectedGamepads = UserInputService:GetConnectedGamepads()
		if #connectedGamepads > 0 then
			for i = 1, #connectedGamepads do
				if this.activeGamepad == nil then
					this.activeGamepad = connectedGamepads[i]
				elseif connectedGamepads[i].Value < this.activeGamepad.Value then
					this.activeGamepad = connectedGamepads[i]
				end
			end
		end
		if this.activeGamepad == nil then
			this.activeGamepad = Enum.UserInputType.Gamepad1
		end
	end

	local function onInputBegan(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch then
			OnTouchBegan(input, processed)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			OnMouse2Down(input, processed)
		elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
			OnMouse3Down(input, processed)
		end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			OnKeyDown(input, processed)
		end
	end

	local function onInputChanged(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch then
			OnTouchChanged(input, processed)
		elseif input.UserInputType == Enum.UserInputType.MouseMovement then
			OnMouseMoved(input, processed)
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			OnMouseWheel(input, processed)
		end
	end

	local function onInputEnded(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch then
			OnTouchEnded(input, processed)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			OnMouse2Up(input, processed)
		elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
			OnMouse3Up(input, processed)
		end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			OnKeyUp(input, processed)
		end
	end

	local function onGamepadConnected(gamepadEnum)
		if this.activeGamepad == nil then assignActivateGamepad() end
	end
	local function onGamepadDisconnected(gamepadEnum)
		if this.activeGamepad ~= gamepadEnum then return end
		this.activeGamepad = nil
		assignActivateGamepad()
	end

	function this:ConnectInputEvents()
		this.RotateInput = ZERO_VECTOR2
		this.activeGamepad = nil

		InputEvents = {
			InputBegan = UserInputService.InputBegan:Connect(onInputBegan),
			InputChanged = UserInputService.InputChanged:Connect(onInputChanged),
			InputEnded = UserInputService.InputEnded:Connect(onInputEnded),
			MenuOpened = GuiService.MenuOpened:Connect(resetInputStates),
			GamepadConnected = UserInputService.GamepadConnected:Connect(onGamepadConnected),
			GamepadDisconnected = UserInputService.GamepadDisconnected:Connect(onGamepadDisconnected),
		}

		pcall(function()
			ContextActionService:BindAction("RootCamGamepadPan", getGamepadPan, false, Enum.KeyCode.Thumbstick2)
			ContextActionService:BindAction("RootCamGamepadZoom", doGamepadZoom, false, Enum.KeyCode.ButtonR3)
		end)
		assignActivateGamepad()
		self:UpdateMouseBehavior()
	end

	function this:SetEnabled(newState)
		if newState ~= self.Enabled then
			self.Enabled = newState
			if self.Enabled then
				self:ConnectInputEvents()
			else
				self:DisconnectInputEvents()
			end
		end
	end

	local function OnPlayerAdded(player)
		storeConnection(player.Changed:Connect(function(prop)
			if this.Enabled then
				if prop == "CameraMode" or prop == "CameraMaxZoomDistance" or prop == "CameraMinZoomDistance" then
					this:ZoomCameraFixedBy(0)
				end
			end
		end))

		local function OnCharacterAdded(newCharacter)
			local hum = findPlayerHumanoid(player)
			local start = tick()
			while tick() - start < 0.3 and (hum == nil or (hum.Torso == nil and newCharacter:FindFirstChild("HumanoidRootPart") == nil)) do
				task.wait()
				hum = findPlayerHumanoid(player)
			end
			local root = hum and (hum.Torso or newCharacter:FindFirstChild("HumanoidRootPart"))
			if hum and root and player.Character == newCharacter then
				local newDesiredLook = (root.CFrame.lookVector - Vector3_new(0,0.23,0)).unit
				local horizontalShift = findAngleBetweenXZVectors(newDesiredLook, this:GetCameraLook())
				local vertShift = math_asin(clamp(-1, 1, this:GetCameraLook().y)) - math_asin(clamp(-1, 1, newDesiredLook.y))
				if not IsFinite(horizontalShift) then horizontalShift = 0 end
				if not IsFinite(vertShift) then vertShift = 0 end
				this.RotateInput = Vector2_new(horizontalShift, vertShift)
				this.LastCameraTransform = nil
			end
			task.wait()
			this:ZoomCamera(this.DefaultZoom)
		end

		storeConnection(player.CharacterAdded:Connect(function(character)
			if this.Enabled or SetCameraOnSpawn then
				OnCharacterAdded(character)
				SetCameraOnSpawn = false
			end
		end))

		if player.Character then
			task.spawn(function() OnCharacterAdded(player.Character) end)
		end
	end

	if Players.LocalPlayer then OnPlayerAdded(Players.LocalPlayer) end
	storeConnection(Players.ChildAdded:Connect(function(child)
		if child and Players.LocalPlayer == child then OnPlayerAdded(Players.LocalPlayer) end
	end))

	local tweenSpeed = math_rad(0)
	local lastUpdate = tick()
	this.LastUserPanCamera = lastUpdate

	function this:Update()
		local now = tick()
		local userPanningTheCamera = (self.UserPanningTheCamera == true)
		local camera = workspace.CurrentCamera
		local hum = self:GetHumanoid()
		local cameraSubject = camera and camera.CameraSubject
		local isInVehicle = cameraSubject and cameraSubject:IsA("VehicleSeat")
		local isOnASkateboard = cameraSubject and cameraSubject:IsA("SkateboardPlatform")

		if isInVehicle and cameraSubject.Occupant == hum then
			cameraSubject = hum
			camera.CameraSubject = hum
			isInVehicle = false
		end

		if lastUpdate == nil or (now - lastUpdate) > 1 then
			self.LastCameraTransform = nil
		end

		if lastUpdate then
			local gamepadRotation = self:UpdateGamepad()
			local delta = math_min(0.1, now - lastUpdate)

			if gamepadRotation ~= ZERO_VECTOR2 then
				userPanningTheCamera = true
				self.RotateInput = self.RotateInput + (gamepadRotation * delta)
			end
			local angleX = (self.TurningLeft and -120 or 0) + (self.TurningRight and 120 or 0)
			if S.arrowKeysDriveModels then
				-- In GO mode the arrow keys belong to KeyboardRight models, not the camera
				angleX = 0
			end
			local angleY = (self.TiltingUp and 85 or 0) + (self.TiltingDown and -85 or 0)
			if angleX ~= 0 or angleY ~= 0 then
				self.RotateInput = self.RotateInput + Vector2_new(math_rad(angleX * delta), math_rad(angleY * delta))
				userPanningTheCamera = true
			end

			-- Compute Mobile Thumbstick 2D input vector (-1..1 X, -1..1 Y) for both FreeCam & RBLX04 Model Controller
			local stickX, stickY = 0, 0
			if thumbstickTouch and thumbstickStartPos and thumbstickCurPos then
				local stickDelta = thumbstickCurPos - thumbstickStartPos
				stickX = clamp(-1, 1, stickDelta.X / 42)
				stickY = clamp(-1, 1, -stickDelta.Y / 42)
				if math_abs(stickX) < 0.12 then stickX = 0 end
				if math_abs(stickY) < 0.12 then stickY = 0 end
			elseif hum and hum.MoveDirection.Magnitude > 0.05 and camera then
				local md = hum.MoveDirection
				local camCF = camera.CFrame
				local flatLook = Vector3_new(camCF.LookVector.X, 0, camCF.LookVector.Z)
				local flatRight = Vector3_new(camCF.RightVector.X, 0, camCF.RightVector.Z)
				if flatLook.Magnitude > 0.01 and flatRight.Magnitude > 0.01 then
					stickY = clamp(-1, 1, md:Dot(flatLook.Unit))
					stickX = clamp(-1, 1, md:Dot(flatRight.Unit))
				end
			end
			S.thumbstickX = stickX
			S.thumbstickY = stickY

			-- RBLX04 Studio Free Camera Flight (Active in Edit mode or when no model is being controlled in GO mode)
			if not self.FreeCamFocus then
				self.FreeCamFocus = self:GetPlayerModelPosition()
			end
			local hasActiveControlledInRun = S.isSimulationRunning and (S.activeControlledModel ~= nil and S.activeControlledModel.Parent ~= nil and S.activeControlledModel:GetAttribute("ControllerType2005") ~= nil and S.activeControlledModel:GetAttribute("ControllerType2005") ~= "None")
			if camera and not UserInputService:GetFocusedTextBox() and not hasActiveControlledInRun then
				local camCF = camera.CFrame
				local lookVec = camCF.LookVector
				local rightVec = camCF.RightVector
				local moveVec = ZERO_VECTOR3

				if S.keysDown[Enum.KeyCode.W] or S.keysDown[Enum.KeyCode.Up] or (S.hudKeysDown and S.hudKeysDown.W) then
					moveVec = moveVec + lookVec
				end
				if S.keysDown[Enum.KeyCode.S] or S.keysDown[Enum.KeyCode.Down] or (S.hudKeysDown and S.hudKeysDown.S) then
					moveVec = moveVec - lookVec
				end
				if S.keysDown[Enum.KeyCode.D] or S.keysDown[Enum.KeyCode.Right] or (S.hudKeysDown and S.hudKeysDown.D) then
					moveVec = moveVec + rightVec
				end
				if S.keysDown[Enum.KeyCode.A] or S.keysDown[Enum.KeyCode.Left] or (S.hudKeysDown and S.hudKeysDown.A) then
					moveVec = moveVec - rightVec
				end
				if S.keysDown[Enum.KeyCode.E] or S.keysDown[Enum.KeyCode.Space] then
					moveVec = moveVec + UP_VECTOR
				end
				if S.keysDown[Enum.KeyCode.Q] then
					moveVec = moveVec - UP_VECTOR
				end
				if math_abs(stickX) > 0.05 or math_abs(stickY) > 0.05 then
					moveVec = moveVec + (lookVec * stickY) + (rightVec * stickX)
				end

				if moveVec.Magnitude > 0.01 then
					local flySpeed = (S.keysDown[Enum.KeyCode.LeftShift] or S.keysDown[Enum.KeyCode.RightShift]) and 85 or 42
					self.FreeCamFocus = self.FreeCamFocus + (moveVec.Unit * flySpeed * delta)
				end
			end
		end

		if userPanningTheCamera then
			tweenSpeed = 0
			self.LastUserPanCamera = now
		end

		local subjectPosition = self:GetSubjectPosition()
		if subjectPosition and camera then
			local zoom = self:GetCameraZoom()
			if zoom < 0.25 then zoom = 0.25 end

			local followSetting = false
			pcall(function() followSetting = TeleportService:GetTeleportSetting("FollowCamera") end)
			if followSetting then
				if self.LastCameraTransform and not self:IsInFirstPerson() then
					local lastVec = -(self.LastCameraTransform.p - subjectPosition)
					local y = findAngleBetweenXZVectors(lastVec, self:GetCameraLook())
					if IsFinite(y) and math_abs(y) > 0.0001 then
						self.RotateInput = self.RotateInput + Vector2_new(y, 0)
					end
				end
			end

			camera.Focus = CFrame_new(subjectPosition)
			local newLookVector = self:RotateCamera(self:GetCameraLook(), self.RotateInput)
			self.RotateInput = ZERO_VECTOR2
			self.LastZoom = zoom

			local newCF = CFrame_new(subjectPosition - (zoom * newLookVector), subjectPosition)
			camera.CFrame = newCF
			self.LastCameraTransform = camera.CFrame
		end
		lastUpdate = now
	end

	pcall(function()
		GameSettings:SetCameraYInvertVisible()
		GameSettings:SetGamepadCameraSensitivityVisible()
	end)

	_G.RetroCamMain = this
end)()

-- [[ MODULE: OPACITY (APPLIES TO DYNABLOX-MAN RIG PARTS WHEN ZOOMED IN) ]]
local Opacity = {}
S._run = (function()
	local TransparencyDirty = false
	local Enabled = false
	local LastTransparency = nil
	local DescendantAddedConn, DescendantRemovingConn = nil, nil
	local ToolDescendantAddedConns = {}
	local ToolDescendantRemovingConns = {}
	local CachedParts = {}

	local function HasToolAncestor(object)
		return (object:FindFirstAncestorWhichIsA("Tool")) ~= nil
	end

	local function IsValidPartToModify(part)
		if part:IsA("BasePart") or part:IsA("Decal") then
			if HasToolAncestor(part) then return false end
			local char = part:FindFirstAncestorOfClass("Model")
			while char and char.Name == "Dynablox2005Rig" do
				char = char.Parent
			end
			-- If character has Dynablox2005Rig, only fade the visible Dynablox2005Rig parts; keep R6/R15 limbs hidden!
			if char and char:FindFirstChild("Dynablox2005Rig") then
				local rig = char:FindFirstChild("Dynablox2005Rig")
				if not part:IsDescendantOf(rig) then
					return false
				end
				if part:GetAttribute("KeepInvisible2005") or part.Name == "HumanoidRootPart" or part.Name == "RootPart" then
					return false
				end
			end
			return true
		end
		return false
	end

	local function TeardownTransparency()
		for child, _ in pairs(CachedParts) do
			if child:IsA("BasePart") or child:IsA("Decal") then
				child.LocalTransparencyModifier = 0
			end
		end
		CachedParts = {}
		TransparencyDirty = true
		LastTransparency = nil

		if DescendantAddedConn then DescendantAddedConn:Disconnect(); DescendantAddedConn = nil end
		if DescendantRemovingConn then DescendantRemovingConn:Disconnect(); DescendantRemovingConn = nil end

		for object, conn in pairs(ToolDescendantAddedConns) do conn:Disconnect(); ToolDescendantAddedConns[object] = nil end
		for object, conn in pairs(ToolDescendantRemovingConns) do conn:Disconnect(); ToolDescendantRemovingConns[object] = nil end
	end

	local function SetupTransparency(character)
		TeardownTransparency()
		if DescendantAddedConn then DescendantAddedConn:Disconnect() end

		DescendantAddedConn = character.DescendantAdded:Connect(function(object)
			if IsValidPartToModify(object) then
				CachedParts[object] = true
				TransparencyDirty = true
			elseif object:IsA("Tool") then
				if ToolDescendantAddedConns[object] then ToolDescendantAddedConns[object]:Disconnect() end
				ToolDescendantAddedConns[object] = object.DescendantAdded:Connect(function(toolChild)
					CachedParts[toolChild] = nil
					if toolChild:IsA("BasePart") or toolChild:IsA("Decal") then
						toolChild.LocalTransparencyModifier = 0
					end
				end)

				if ToolDescendantRemovingConns[object] then ToolDescendantRemovingConns[object]:Disconnect() end
				ToolDescendantRemovingConns[object] = object.DescendantRemoving:Connect(function(formerToolChild)
					task.wait()
					if character and formerToolChild and formerToolChild:IsDescendantOf(character) then
						if IsValidPartToModify(formerToolChild) then
							CachedParts[formerToolChild] = true
							TransparencyDirty = true
						end
					end
				end)
			end
		end)

		if DescendantRemovingConn then DescendantRemovingConn:Disconnect() end
		DescendantRemovingConn = character.DescendantRemoving:Connect(function(object)
			if CachedParts[object] then
				CachedParts[object] = nil
				object.LocalTransparencyModifier = 0
			end
		end)

		for _, desc in pairs(character:GetDescendants()) do
			if IsValidPartToModify(desc) then
				CachedParts[desc] = true
				TransparencyDirty = true
			end
		end
	end

	function Opacity:SetEnabled(newState)
		if Enabled ~= newState then
			Enabled = newState
			self:Update()
		end
	end

	function Opacity:SetSubject(subject)
		local character = nil
		if subject and subject:IsA("Humanoid") then character = subject.Parent end
		if subject and subject:IsA("VehicleSeat") and subject.Occupant then character = subject.Occupant.Parent end
		if character then
			SetupTransparency(character)
		else
			TeardownTransparency()
		end
	end

	function Opacity:Update()
		local currentCamera = workspace.CurrentCamera
		if currentCamera then
			local transparency = 0
			if Enabled then
				local distance = (Main:GetPlayerModelPosition() - currentCamera.CFrame.p).magnitude
				if distance < 2 then transparency = 1
				elseif distance < 6 then transparency = 0.5
				else transparency = 0 end
			end

			if TransparencyDirty or LastTransparency ~= transparency then
				for child in pairs(CachedParts) do
					if child:IsA("BasePart") or child:IsA("Decal") then
						if child.ClassName == "Decal" then
							child.LocalTransparencyModifier = math.floor(transparency)
						else
							child.LocalTransparencyModifier = transparency
						end
					end
				end
				TransparencyDirty = false
				LastTransparency = transparency
			end
		end
	end
end)()

-- [[ MODULE: POPPER CAM ]]
local PopperCam = {}
S._run = (function()
	local POP_RESTORE_RATE = 0.3
	local SubjectPart = nil
	local PlayerCharacters = {}
	local VehicleParts = {}

	local LastPopAmount = 0
	local LastZoomLevel = 0
	local PopperEnabled = false
	local math_abs = math.abs

	local function OnCharacterAdded(player, character)
		PlayerCharacters[player] = character
	end

	local function OnPlayersChildAdded(child)
		if child:IsA("Player") then
			storeConnection(child.CharacterAdded:Connect(function(character)
				OnCharacterAdded(child, character)
			end))
			if child.Character then
				OnCharacterAdded(child, child.Character)
			end
		end
	end

	local function OnPlayersChildRemoved(child)
		if child:IsA("Player") then
			PlayerCharacters[child] = nil
		end
	end

	function PopperCam:Update()
		if PopperEnabled then
			local cam = workspace.CurrentCamera
			if not cam or cam.CameraType.Name == "Fixed" then return end

			local cameraCFrame = cam.CFrame
			local focusPoint = cam.Focus.p
			if SubjectPart then focusPoint = SubjectPart.CFrame.p end

			local ignoreList = {}
			for _, character in pairs(PlayerCharacters) do
				ignoreList[#ignoreList + 1] = character
			end
			for i = 1, #VehicleParts do
				ignoreList[#ignoreList + 1] = VehicleParts[i]
			end

			local okCut, largest = pcall(cam.GetLargestCutoffDistance, cam, ignoreList)
			if not okCut or type(largest) ~= "number" then largest = 0 end
			local zoomLevel = (cameraCFrame.p - focusPoint).Magnitude
			if math_abs(zoomLevel - LastZoomLevel) > 0.001 then LastPopAmount = 0 end

			local popAmount = largest
			if LastPopAmount > popAmount then popAmount = LastPopAmount end

			if popAmount > 0 then
				cam.CFrame = cameraCFrame + (cameraCFrame.lookVector * popAmount)
				LastPopAmount = popAmount - POP_RESTORE_RATE
				if LastPopAmount < 0 then LastPopAmount = 0 end
			end
			LastZoomLevel = zoomLevel
		end
	end

	storeConnection(Players.ChildRemoved:Connect(OnPlayersChildRemoved))
	storeConnection(Players.ChildAdded:Connect(OnPlayersChildAdded))
	for _, player in pairs(Players:GetPlayers()) do
		OnPlayersChildAdded(player)
	end
end)()

-- [[ BOOTSTRAPPER & EVENT BINDING ]]
local function onCameraSubjectChanged()
	local currentCamera = workspace.CurrentCamera
	if currentCamera then
		local newSubject = currentCamera.CameraSubject
		Opacity:SetSubject(newSubject)
	end
end

local function onNewCamera()
	local currentCamera = workspace.CurrentCamera
	if currentCamera then
		if _G.RetroCamOpacityConn then _G.RetroCamOpacityConn:Disconnect() end
		local cameraSubjectChanged = currentCamera:GetPropertyChangedSignal("CameraSubject")
		_G.RetroCamOpacityConn = cameraSubjectChanged:Connect(onCameraSubjectChanged)
		onCameraSubjectChanged()
	end
end

storeConnection(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(onNewCamera))
onNewCamera()
Main:SetEnabled(true)
Opacity:SetEnabled(true)

local function updateRetroCamera()
	Main:Update()
	PopperCam:Update()
	Opacity:Update()
	pcall(function()
		RunService:UnbindFromRenderStep("cameraRenderUpdate")
	end)
end

RunService:BindToRenderStep("RetroCamera", 250, updateRetroCamera)

-- 2005 CameraMenu: zoom moves 1/5 of the distance, pan steps to the next 45 degree heading, tilt is 25 degrees
-- and Center focuses on the selection
do
	local PAN_STEP = math.pi / 4
	local TILT_STEP = math.rad(25)

	local function panCamera(dir)
		local flatLook = Main:GetCameraLook() * Vector3.new(1, 0, 1)
		local angle = Main.RotateVectorByAngleAndRound(flatLook, dir * PAN_STEP * 0.75, PAN_STEP)
		if angle == 0 then
			angle = dir * PAN_STEP
		end
		Main.RotateInput = Main.RotateInput + Vector2.new(angle, 0)
		Main:PlayTick()
		Main:Update()
	end

	local function tiltCamera(dir)
		Main.RotateInput = Main.RotateInput + Vector2.new(0, dir * TILT_STEP)
		Main:PlayTick()
		Main:Update()
	end

	storeConnection(S.CamZoomInBtn.MouseButton1Click:Connect(function()
		Main:ZoomCameraBy(1)
		Main:Update()
	end))

	storeConnection(S.CamZoomOutBtn.MouseButton1Click:Connect(function()
		Main:ZoomCameraBy(-1)
		Main:Update()
	end))

	storeConnection(S.CamTiltUpBtn.MouseButton1Click:Connect(function() tiltCamera(1) end))
	storeConnection(S.CamTiltDownBtn.MouseButton1Click:Connect(function() tiltCamera(-1) end))
	storeConnection(S.CamLeftBtn.MouseButton1Click:Connect(function() panCamera(-1) end))
	storeConnection(S.CamRightBtn.MouseButton1Click:Connect(function() panCamera(1) end))

	storeConnection(S.CamCenterBtn.MouseButton1Click:Connect(function()
		Main:PlayTick()
		if S.selectedObject then
			local targetPos = Main:GetObjectFocusPosition(S.selectedObject)
			if targetPos then
				Main.FreeCamFocus = targetPos
				Main:ZoomCamera(14)
			end
		else
			local ctrlPos = Main:GetControlledModelPosition() or Main:GetPlayerModelPosition()
			Main.FreeCamFocus = ctrlPos
			Main:ZoomCamera(Main.DefaultZoom)
		end
		Main:Update()
	end))
end

--========================================================
-- 13. MOBILE & PC 3D ARROW SCALING/MOVING + RAYCAST SELECTION & DRAGGING
--========================================================
-- True while the pointer is over a visible 2005 panel. GuiObject.AbsolutePosition and InputObject.Position
-- share the same screen space, so this follows the panels wherever they are and at any UIScale.
local function isPointerOver2005Gui(screenPos)
	local x, y = screenPos.X, screenPos.Y
	local function inside(frame)
		if not frame or not frame.Visible then return false end
		local p, s = frame.AbsolutePosition, frame.AbsoluteSize
		return x >= p.X and x <= p.X + s.X and y >= p.Y and y <= p.Y + s.Y
	end
	for _, btn in ipairs(TopBar:GetChildren()) do
		if btn:IsA("GuiButton") and inside(btn) then return true end
	end
	for _, frame in ipairs({
		S.LeftToolbar, S.BottomLeftTabs, S.CameraMenuFrame, S.BottomBar, S.WASDControllerFrame, S.HopperBar,
		S.PopupMenuFrame, S.TopbarDropdownFrame, S.PropertyGridFrame,
	}) do
		if inside(frame) then return true end
	end
	return false
end

local function raycast3DWorldAtScreenPos(screenPos)
	Camera = Workspace.CurrentCamera
	if not Camera then return nil, nil, nil end
	local unitRay = Camera:ScreenPointToRay(screenPos.X, screenPos.Y)
	local ignore = S.getHiddenCharacters and S.getHiddenCharacters() or {}
	table.insert(ignore, ArrowRigFolder)
	table.insert(ignore, baseStudFolder)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, rp)
	if hit and hit.Instance then
		return hit.Instance, hit.Position, hit.Normal
	end
	return nil, nil, nil
end

-- Which face of `part` a world-space hit normal belongs to
local function getNormalIdFromWorld(part, worldNormal)
	local n = part.CFrame:VectorToObjectSpace(worldNormal)
	local ax, ay, az = math.abs(n.X), math.abs(n.Y), math.abs(n.Z)
	if ay >= ax and ay >= az then
		return n.Y > 0 and Enum.NormalId.Top or Enum.NormalId.Bottom
	elseif ax >= az then
		return n.X > 0 and Enum.NormalId.Right or Enum.NormalId.Left
	end
	return n.Z > 0 and Enum.NormalId.Back or Enum.NormalId.Front
end

-- Drag tool (and the GameTool / Grab HopperBins): a 12px threshold and a capped ray so taps never fling parts away
local function beginSelectDrag(input, hitWorldPos)
	local obj = S.selectedObject
	local objPos = obj:IsA("Model") and obj:GetPivot().Position or obj.Position
	local camPos = Camera and Camera.CFrame.Position or objPos
	S.isDraggingObject = true
	S.dragActivated = false
	S.dragInputObject = input
	S.dragStartScreenPos = Vector2.new(input.Position.X, input.Position.Y)
	S.dragGrabOffset = hitWorldPos and (objPos - hitWorldPos) or Vector3.new(0, obj:IsA("Model") and 2.5 or (obj.Size.Y * 0.5), 0)
	-- How far the pivot sits above the object's lowest point, so a drag rests it on the surface instead of
	-- sinking it (grabbed high up) or floating it (grabbed low down)
	local okBottom, bottomY = pcall(S.getWorldBottomY, obj)
	S.dragPivotAboveBottom = okBottom and (objPos.Y - bottomY) or nil
	S.dragMaxRayDist = math.clamp((objPos - camPos).Magnitude * 1.8, 25, 110)
end

--========================================================
-- 13B. HOPPER TOOLS IN GO MODE: the bar of tools the level hands out, and what each one does
--========================================================
do
	local SLOT = 48
	local HopperBar = Instance.new("Frame")
	HopperBar.Name = "HopperBar2005"
	HopperBar.AnchorPoint = Vector2.new(0.5, 1)
	HopperBar.Position = UDim2.new(0.5, 0, 1, -(S.TOOLBOX_STRIP_HEIGHT + 8))
	HopperBar.Size = UDim2.new(0, 0, 0, SLOT + 6)
	HopperBar.BackgroundColor3 = Color3.fromRGB(236, 233, 216)
	HopperBar.BackgroundTransparency = 0.15
	HopperBar.BorderSizePixel = 1
	HopperBar.BorderColor3 = Color3.fromRGB(113, 111, 100)
	HopperBar.Visible = false
	HopperBar.Parent = ScreenGui
	S.HopperBar = HopperBar

	local barLayout = Instance.new("UIListLayout")
	barLayout.FillDirection = Enum.FillDirection.Horizontal
	barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	barLayout.Padding = UDim.new(0, 4)
	barLayout.SortOrder = Enum.SortOrder.LayoutOrder
	barLayout.Parent = HopperBar
	local barPad = Instance.new("UIPadding")
	barPad.PaddingLeft = UDim.new(0, 3)
	barPad.PaddingRight = UDim.new(0, 3)
	barPad.Parent = HopperBar

	local function grantedBins()
		local list = {}
		for _, bin in ipairs(S.HOPPER_BINS_2005) do
			if S.levelHopperBins[bin.Id] then
				table.insert(list, bin)
			end
		end
		return list
	end
	S.grantedHopperBins = grantedBins

	-- The bar shows the tools the level gave the player; the one being held is highlighted cyan
	S.refreshHopperBar = function()
		for _, ch in ipairs(HopperBar:GetChildren()) do
			if ch:IsA("GuiButton") then ch:Destroy() end
		end
		local granted = grantedBins()
		HopperBar.Visible = S.isSimulationRunning and #granted > 0
		HopperBar.Size = UDim2.new(0, #granted * (SLOT + 4) + 2, 0, SLOT + 6)
		for idx, bin in ipairs(granted) do
			local held = (S.activeHopperBin == bin.Id)
			local btn = Instance.new("ImageButton")
			btn.Name = bin.Id
			btn.LayoutOrder = idx
			btn.Size = UDim2.new(0, SLOT, 0, SLOT)
			btn.BackgroundColor3 = held and Color3.fromRGB(180, 245, 245) or Color3.fromRGB(204, 204, 204)
			btn.BackgroundTransparency = held and 0 or 0.5
			btn.BorderSizePixel = held and 2 or 0
			btn.BorderColor3 = Color3.fromRGB(0, 190, 190)
			btn.AutoButtonColor = false
			btn.ScaleType = Enum.ScaleType.Fit
			btn.Parent = HopperBar
			local fb = Instance.new("TextLabel")
			fb:SetAttribute("No2006Font", true)
			fb.Size = UDim2.new(1, 0, 1, 0)
			fb.BackgroundTransparency = 1
			fb.Font = Enum.Font.Arial
			fb.TextSize = 10
			fb.TextWrapped = true
			fb.TextColor3 = Color3.fromRGB(0, 0, 0)
			fb.Text = bin.Id
			fb.Parent = btn
			applySpriteToImage(btn, bin.Sprite, fb)
			local num = Instance.new("TextLabel")
			num:SetAttribute("No2006Font", true)
			num.Position = UDim2.new(0, 2, 0, 1)
			num.Size = UDim2.new(0, 10, 0, 12)
			num.BackgroundTransparency = 1
			num.Font = Enum.Font.ArialBold
			num.TextSize = 11
			num.TextColor3 = Color3.fromRGB(0, 0, 0)
			num.TextXAlignment = Enum.TextXAlignment.Left
			num.Text = tostring(idx)
			num.Parent = btn
			storeConnection(btn.MouseButton1Click:Connect(function()
				S.selectHopperBin(bin.Id)
			end))
		end
	end

	-- Tap a tool to hold it; tap it again to put it away
	S.selectHopperBin = function(id)
		if S.activeHopperBin == id then
			S.activeHopperBin = nil
		else
			S.activeHopperBin = id
		end
		S.endHopperGrab()
		playClassicSound(SOUND_CLICK, 0.4, 1)
		S.refreshHopperBar()
	end

	local effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "Studio2005RunEffects"
	effectsFolder.Parent = Workspace
	storeConnection({ Disconnect = function() effectsFolder:Destroy() end })

	local function trackForRun(inst)
		S.runSpawned = S.runSpawned or {}
		table.insert(S.runSpawned, inst)
	end

	-- Only bricks you built can be blasted, zapped or grabbed; studs count as their brick
	local function buildPart(part)
		if not part then return nil end
		if part:GetAttribute("Is2005Bump") and part.Parent and part.Parent.Parent and part.Parent.Parent:IsA("BasePart") then
			part = part.Parent.Parent
		end
		if part:IsA("BasePart") and part:IsDescendantOf(SpawnedModelsFolder) then
			return part
		end
		return nil
	end

	-- Switch off the joints holding `part` to the rest of its model (STOP switches them back on)
	local function breakJointsOf(part)
		local root = part:FindFirstAncestorOfClass("Model") or part
		for _, j in ipairs(root:GetDescendants()) do
			if j:IsA("WeldConstraint") or j:IsA("Motor6D") then
				if j.Part0 == part or j.Part1 == part then j.Enabled = false end
			elseif j:IsA("HingeConstraint") then
				local a0, a1 = j.Attachment0, j.Attachment1
				if (a0 and a0.Parent == part) or (a1 and a1.Parent == part) then j.Enabled = false end
			end
		end
	end

	local function knockLoose(part, velocity)
		if part:GetAttribute("AnchoredInGame") then return end
		breakJointsOf(part)
		part.Anchored = false
		part.AssemblyLinearVelocity = velocity
	end

	local function shortLivedPart(name, size, color, cf, life)
		local p = Instance.new("Part")
		p.Name = name
		p:SetAttribute("Is2005Effect", true)
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.CFrame = cf
		p.Parent = effectsFolder
		task.delay(life, function() p:Destroy() end)
		return p
	end

	-- Where shots come from: your 2005 figure's head when it is on screen nearby, otherwise the camera
	local function muzzle(aimPoint)
		local cam = Workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position or Vector3.new(0, 10, 0)
		local from = camPos
		local rig = S.localPlayerRig
		local head = rig and rig.Parent and (rig:FindFirstChild("Head") or rig.PrimaryPart)
		if head and (head.Position - camPos).Magnitude < 150 then
			from = head.Position + Vector3.new(0, 1, 0)
		end
		local dir = aimPoint - from
		if dir.Magnitude < 0.1 then
			dir = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
		end
		return from, dir.Unit
	end

	-- Rocket blast: a red sphere, and bricks within 8 studs break loose and fly outward
	local function blast(pos)
		playClassicSound(SOUND_BOOP, 0.8, 0.5)
		S.showRedExplosionSphere(pos, 8)
		local ok, parts = pcall(function() return Workspace:GetPartBoundsInRadius(pos, 8) end)
		for _, hit in ipairs(ok and parts or {}) do
			local part = buildPart(hit)
			if part and part == hit then
				local away = part.Position - pos
				local dir = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 1, 0)
				knockLoose(part, dir * 50 + Vector3.new(0, 25, 0))
			end
		end
	end
	S.hopperBlast = blast

	local function fireSlingshot(aimPoint)
		local from, dir = muzzle(aimPoint)
		local ball = Instance.new("Part")
		ball.Name = "SlingshotBall2005"
		ball:SetAttribute("Is2005Effect", true)
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(1, 1, 1)
		ball.Color = Color3.fromRGB(255, 0, 0)
		ball.Material = Enum.Material.SmoothPlastic
		ball.CanQuery = false
		pcall(function() ball.CustomPhysicalProperties = PhysicalProperties.new(4, 0.3, 0.5) end)
		ball.CFrame = CFrame.new(from + dir * 2.5)
		ball.Parent = effectsFolder
		ball.AssemblyLinearVelocity = dir * 120 + Vector3.new(0, 6, 0)
		trackForRun(ball)
		task.delay(6, function() ball:Destroy() end)
		playClassicSound(SOUND_CLICK, 0.5, 0.7)
	end

	local function fireRocket(aimPoint)
		local from, dir = muzzle(aimPoint)
		local rocket = Instance.new("Part")
		rocket.Name = "Rocket2005"
		rocket:SetAttribute("Is2005Effect", true)
		rocket.Size = Vector3.new(1, 1, 4)
		rocket.Color = Color3.fromRGB(0, 0, 255)
		rocket.Material = Enum.Material.SmoothPlastic
		rocket.CanCollide = false
		rocket.CanQuery = false
		rocket.CFrame = CFrame.lookAt(from + dir * 3, from + dir * 4)
		local push = Instance.new("BodyVelocity")
		push.MaxForce = Vector3.new(1e6, 1e6, 1e6)
		push.Velocity = dir * 70
		push.Parent = rocket
		rocket.Parent = effectsFolder
		trackForRun(rocket)
		local exploded = false
		local function explode()
			if exploded or not rocket.Parent then return end
			exploded = true
			local pos = rocket.Position
			rocket:Destroy()
			blast(pos)
		end
		rocket.Touched:Connect(function(hit)
			if hit.CanCollide and not hit:IsDescendantOf(effectsFolder)
				and not (S.localPlayerRig and hit:IsDescendantOf(S.localPlayerRig)) then
				explode()
			end
		end)
		task.delay(5, explode)
		playClassicSound(SOUND_BOOP, 0.6, 1.4)
	end

	local function fireLaser(aimPoint, hitPart)
		local from, dir = muzzle(aimPoint)
		local len = (aimPoint - from).Magnitude
		shortLivedPart("LaserBeam2005", Vector3.new(0.2, 0.2, len), Color3.fromRGB(255, 0, 0),
			CFrame.lookAt(from + dir * (len * 0.5), aimPoint), 0.15).Material = Enum.Material.Neon
		local part = buildPart(hitPart)
		if part then
			knockLoose(part, dir * 40 + Vector3.new(0, 10, 0))
		end
		playClassicSound(SOUND_CLICK, 0.6, 1.8)
	end

	-- Grab: pick a loose brick up; it follows your finger or mouse and keeps its speed when you let go
	S.endHopperGrab = function()
		local g = S.hopperGrab
		S.hopperGrab = nil
		if g and g.Mover then
			pcall(function() g.Mover:Destroy() end)
		end
	end
	local function beginGrab(part, hitPos, input)
		S.endHopperGrab()
		if not part or part.Anchored then
			playClassicSound(SOUND_CLICK, 0.4, 0.6)
			return
		end
		local cam = Workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position or hitPos
		local mover = Instance.new("BodyPosition")
		mover.Name = "HopperGrab2005"
		mover.MaxForce = Vector3.new(1e6, 1e6, 1e6)
		mover.P = 20000
		mover.D = 800
		mover.Position = part.Position
		mover.Parent = part
		S.hopperGrab = {
			Part = part,
			Mover = mover,
			Input = input,
			Dist = (hitPos - camPos).Magnitude,
			Offset = part.Position - hitPos,
		}
		playClassicSound(SOUND_CLICK, 0.45, 1.2)
	end
	S.updateHopperGrab = function(input)
		local g = S.hopperGrab
		if not g then return false end
		if input.UserInputType == Enum.UserInputType.Touch and g.Input and input ~= g.Input then
			return true
		end
		local cam = Workspace.CurrentCamera
		if not cam or not g.Part.Parent then
			S.endHopperGrab()
			return true
		end
		local ray = cam:ScreenPointToRay(input.Position.X, input.Position.Y)
		g.Mover.Position = ray.Origin + ray.Direction * g.Dist + g.Offset
		return true
	end

	-- What a tap in the world does while a Hopper tool is held
	S.useHopperBin = function(bin, input, target, hitWorldPos)
		local cam = Workspace.CurrentCamera
		local ray = cam and cam:ScreenPointToRay(input.Position.X, input.Position.Y)
		local aimPoint = hitWorldPos or (ray and (ray.Origin + ray.Direction * 200)) or Vector3.zero
		if bin == "Slingshot" then
			fireSlingshot(aimPoint)
		elseif bin == "Rocket" then
			fireRocket(aimPoint)
		elseif bin == "Laser" then
			fireLaser(aimPoint, target)
		elseif not target then
			return
		elseif bin == "Grab" then
			beginGrab(buildPart(target) or (target:IsA("BasePart") and target or nil), hitWorldPos or target.Position, input)
		elseif bin == "GameTool" then
			selectStudioObject(target)
			if S.selectedObject then
				beginSelectDrag(input, hitWorldPos)
			end
		elseif bin == "Clone" then
			selectStudioObject(target)
			local original = S.selectedObject
			if original then
				duplicateSelectedObject()
				if S.selectedObject and S.selectedObject ~= original then
					trackForRun(S.selectedObject)
				end
			end
		elseif bin == "Hammer" then
			selectStudioObject(target)
			local obj = S.selectedObject
			if obj then
				S.runRemoved = S.runRemoved or {}
				table.insert(S.runRemoved, { Obj = obj, Parent = obj.Parent })
				selectStudioObject(nil)
				obj.Parent = nil
				playClassicSound(SOUND_PAGE, 0.5, 1)
			end
		end
	end
end

storeConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		S.keysDown[input.KeyCode] = true
		if not gameProcessed then
			if input.KeyCode == Enum.KeyCode.Delete or input.KeyCode == Enum.KeyCode.Backspace then
				if S.deleteSelectedStudioObject then
					S.deleteSelectedStudioObject()
				end
			elseif input.KeyCode == Enum.KeyCode.R and S.selectedObject then
				rotateSelectedObject(90, 0)
			elseif input.KeyCode == Enum.KeyCode.T and S.selectedObject then
				rotateSelectedObject(0, 90)
			elseif S.isSimulationRunning and S.grantedHopperBins then
				local slot = ({ One = 1, Two = 2, Three = 3, Four = 4, Five = 5, Six = 6, Seven = 7 })[input.KeyCode.Name]
				local bin = slot and S.grantedHopperBins()[slot]
				if bin then
					S.selectHopperBin(bin.Id)
				end
			end
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if isPointerOver2005Gui(input.Position) then return end

		-- STEP 1: Check if the touch/click hit one of the 6 2005 3D Arrows on the currently selected object!
		local hitArrowNormalId = S.findHitArrowNormalId(input.Position)
		if hitArrowNormalId then
			S.beginArrowHandleDrag(hitArrowNormalId, input.Position, input)
			return
		end

		if gameProcessed then return end

		if S.closeTopbarDropdown then S.closeTopbarDropdown() end

		-- STEP 2: Raycast into the 3D world at input.Position (works immediately on both Mobile Touch & PC Mouse!)
		local target, hitWorldPos, hitNormal = raycast3DWorldAtScreenPos(input.Position)

		-- Surface toolbox tool: only the clicked face changes, the selection stays as it is
		if target and S.currentStudioTool == "Surface" and S.currentSurfaceTool then
			local part = target
			if part:GetAttribute("Is2005Bump") and part.Parent and part.Parent.Parent and part.Parent.Parent:IsA("BasePart") then
				part = part.Parent.Parent
			end
			if part:IsA("BasePart") and not part:GetAttribute("Is2005HandleArrow") and hitNormal then
				S.applySurfaceToolToFace(part, getNormalIdFromWorld(part, hitNormal), S.currentSurfaceTool)
				playClassicSound(SOUND_BOOP, 0.45, 1)
			end
			return
		end

		-- While GO runs, a Hopper tool held from the bar acts on every tap in the world
		local bin = S.isSimulationRunning and S.activeHopperBin
		if bin and S.levelHopperBins[bin] then
			S.useHopperBin(bin, input, target, hitWorldPos)
			return
		end

		if target then
			local prevSel = S.selectedObject
			local nowClick = tick()
			selectStudioObject(target)
			if S.selectedObject and S.selectedObject == prevSel and S.lastSelectClickTime and (nowClick - S.lastSelectClickTime) <= 0.28 then
				if S.PropertyGridFrame then
					S.PropertyGridFrame.Visible = true
					if S.refreshPropertyGrid then S.refreshPropertyGrid() end
				end
			end
			S.lastSelectClickTime = nowClick

			if S.selectedObject then
				if S.currentStudioTool == "Resize" or S.currentStudioTool == "Move" then
					-- In Resize and Move tools, ONLY move/scale via the 6 3D Arrow Handles (NEVER free-drag across the map!)
					S.isDraggingObject = false
					updateHandlesAdornee()
				elseif S.currentStudioTool == "Select" then
					beginSelectDrag(input, hitWorldPos)
				end
			end
		else
			selectStudioObject(nil)
		end
	end
end))

storeConnection(UserInputService.InputChanged:Connect(function(input)
	if not (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		return
	end

	-- 0. Carrying something with the Grab tool
	if S.updateHopperGrab(input) then
		return
	end

	-- 1. If dragging one of the 6 2005 3D Arrows (Resize or Move along axis):
	if S.isArrowDragging() then
		local arrowInput = S.getArrowDragInput and S.getArrowDragInput() or nil
		if input.UserInputType == Enum.UserInputType.Touch and arrowInput and input ~= arrowInput then
			return
		end
		local step = S.computeAxisStepFromScreenPos(input.Position)
		S.applyArrowHandleStep(step)
		return
	end

	-- 2. Otherwise, if free-dragging a selected Studio part or 2005 model (Drag tool or GameTool / Grab bins):
	if S.isDraggingObject and S.selectedObject then
		if input.UserInputType == Enum.UserInputType.Touch and S.dragInputObject and input ~= S.dragInputObject then
			return
		end
		local curScreenPos = Vector2.new(input.Position.X, input.Position.Y)
		if not S.dragActivated then
			if not S.dragStartScreenPos or (curScreenPos - S.dragStartScreenPos).Magnitude < 12 then
				return
			end
			S.dragActivated = true
		end
		Camera = Workspace.CurrentCamera
		if not Camera then return end
		local unitRay = Camera:ScreenPointToRay(input.Position.X, input.Position.Y)
		local maxDist = S.dragMaxRayDist or 85
		local result = S.raycastSolid(unitRay.Origin, unitRay.Direction * maxDist, { S.selectedObject })
		if result then
			local offset = S.dragGrabOffset or Vector3.new(0, S.selectedObject:IsA("Model") and 2.5 or (S.selectedObject.Size.Y * 0.5), 0)
			local target = result.Position + offset
			if S.dragPivotAboveBottom and result.Normal.Y > 0.3 then
				target = Vector3.new(target.X, result.Position.Y + S.dragPivotAboveBottom, target.Z)
			elseif S.dragPivotAboveBottom then
				-- Over the side of something: slide sideways without changing height
				local piv = S.selectedObject:IsA("Model") and S.selectedObject:GetPivot().Position or S.selectedObject.Position
				target = Vector3.new(target.X, piv.Y, target.Z)
			end
			moveStudioObject(S.selectedObject, target)
		end
	end
end))

storeConnection(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		S.keysDown[input.KeyCode] = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local arrowInput = S.getArrowDragInput and S.getArrowDragInput() or nil
		if not arrowInput or input == arrowInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
			S.endArrowHandleDrag()
		end
		local grab = S.hopperGrab
		if grab and (input == grab.Input or input.UserInputType == Enum.UserInputType.MouseButton1) then
			S.endHopperGrab()
		end
		if not S.dragInputObject or input == S.dragInputObject or input.UserInputType == Enum.UserInputType.MouseButton1 then
			S.isDraggingObject = false
			S.dragActivated = false
			S.dragInputObject = nil
		end
	end
end))

--========================================================
-- 14. RENDERSTEPPED LOOP (PHYSICS-ONLY PLAYER MODELS, 3D ARROW SYNC, CONTROLLERS, TIMER & FPS)
--========================================================
do
	local fpsAccum = 0
	local fpsFrames = 0

	storeConnection(RunService.RenderStepped:Connect(function(dt)
		-- 14A. FPS Display
		fpsAccum = fpsAccum + dt
		fpsFrames = fpsFrames + 1
		if fpsAccum >= 0.25 then
			local fps = fpsFrames / fpsAccum
			FPSLabel.Text = string.format("FPS: %.3f", fps)
			fpsAccum = 0
			fpsFrames = 0
		end

		-- 14B. Keep All Players as Pure 2005 Physics Models (Hide all original avatars & enforce 3D collision on 2005 rigs)
		if Config.CONVERT_ALL_PLAYERS_TO_DYNABLOX_MAN then
			for char in pairs(S.convertedCharacters) do
				if char.Parent then
					local hum = char:FindFirstChildOfClass("Humanoid")
					if hum then
						if hum.WalkSpeed ~= 0 then hum.WalkSpeed = 0 end
						if hum.JumpPower ~= 0 then hum.JumpPower = 0 end
						if not hum.PlatformStand then hum.PlatformStand = true end
					end
					-- (set only when not already so: setting them every frame for every player cost)
					local function hidePart(part)
						if part.LocalTransparencyModifier ~= 1 then part.LocalTransparencyModifier = 1 end
						if part.Transparency ~= 1 then part.Transparency = 1 end
						if part.CanCollide then part.CanCollide = false end
						if part.CanQuery then part.CanQuery = false end
					end
					for _, ch in ipairs(char:GetChildren()) do
						if ch:IsA("BasePart") then
							hidePart(ch)
						elseif ch:IsA("Accessory") then
							local handle = ch:FindFirstChild("Handle")
							if handle and handle:IsA("BasePart") then hidePart(handle) end
						end
					end
				end
			end
			for _, rig in pairs(S.rigRegistry) do
				if rig and rig.Parent and rig.PrimaryPart then
					for _, rp in ipairs(rig:GetChildren()) do
						if rp:IsA("BasePart") then
							if rp:GetAttribute("IsSwingingArm2004") then
								rp.CanCollide = false
								rp.Anchored = false
							else
								rp.CanCollide = true
							end
						end
					end
					if rig.PrimaryPart.Position.Y < -35 then
						rig.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
						rig:PivotTo(CFrame.new(0, 12, 0))
					end
				end
			end
		end

		-- Keep 3D Arrow Handles locked onto moving physics objects
		if S.selectedObject and (S.currentStudioTool == "Resize" or S.currentStudioTool == "Move") and not S.isArrowDragging() then
			updateHandlesAdornee()
		end

		-- Keep all 3D Studs (Bumps2005) 100% locked onto their parent part whenever any part moves or rotates!
		if S.studMode == "3D" then
			if S.activeBumpParts then
				for p in pairs(S.activeBumpParts) do
					if p and p.Parent and p:FindFirstChild("Bumps2005") then
						if p.Anchored and S.lastBumpPartCF[p] ~= p.CFrame then
							syncPart3DBumpsCFrame(p, false)
						end
					else
						S.activeBumpParts[p] = nil
						S.lastBumpPartCF[p] = nil
					end
				end
			end
			if S.syncBaseplatePoolWithMovedBaseplate then
				S.syncBaseplatePoolWithMovedBaseplate()
			end
		end

		-- Keep mobile joystick (TouchGui) completely hidden
		hideMobileMovementGui()

		-- 14C. 2005 controllers: KeyboardLeft = W/A/S/D, KeyboardRight = arrow keys, Player = either.
		-- The touch keypad counts for both because it is the only keyboard a phone has.
		local hud = S.hudKeysDown or {}
		local wasdFwd = ((S.keysDown[Enum.KeyCode.W] or hud.W) and 1 or 0) - ((S.keysDown[Enum.KeyCode.S] or hud.S) and 1 or 0)
		local wasdTurn = ((S.keysDown[Enum.KeyCode.A] or hud.A) and 1 or 0) - ((S.keysDown[Enum.KeyCode.D] or hud.D) and 1 or 0)
		local arrowFwd = ((S.keysDown[Enum.KeyCode.Up] or hud.W) and 1 or 0) - ((S.keysDown[Enum.KeyCode.Down] or hud.S) and 1 or 0)
		local arrowTurn = ((S.keysDown[Enum.KeyCode.Left] or hud.A) and 1 or 0) - ((S.keysDown[Enum.KeyCode.Right] or hud.D) and 1 or 0)
		local function getControllerInput(ctrl)
			if ctrl == "KeyboardLeft" then
				return wasdFwd, wasdTurn
			elseif ctrl == "KeyboardRight" then
				return arrowFwd, arrowTurn
			elseif ctrl == "Player" then
				return math.clamp(wasdFwd + arrowFwd, -1, 1), math.clamp(wasdTurn + arrowTurn, -1, 1)
			end
			return 0, 0
		end

		if S.refreshWASDKeySprites then
			S.refreshWASDKeySprites()
		end

		S.arrowKeysDriveModels = false
		if S.isSimulationRunning then
			local lv = S.level
			-- Level timer: counts down from InitialTimerValue (0 = no limit) and fires TimerUpAction at zero
			if lv.InitialTimerValue > 0 and S.currentTimerValue > 0 then
				S.currentTimerValue = math.max(0, S.currentTimerValue - dt)
				if S.currentTimerValue <= 0 and lv.TimerUpAction ~= "Nothing" then
					endLevel2005(lv.TimerUpAction)
					return
				end
			end
			-- TimerAffectsScore: the score climbs or drains while the clock runs
			if lv.TimerAffectsScore ~= "NoChange" then
				S.scoreStepAccum = (S.scoreStepAccum or 0) + dt * 30
				local steps = math.floor(S.scoreStepAccum)
				if steps > 0 then
					S.scoreStepAccum = S.scoreStepAccum - steps
					if lv.TimerAffectsScore == "Increase" then
						S.bonusScore = S.bonusScore + steps
					else
						S.bonusScore = math.max(0, S.bonusScore - steps)
					end
				end
			end
			updateScoreTimerUI()

			-- Gather ONLY models that explicitly have a Controller assigned (never force any model to be the player!)
			local activeList = {}
			local seenObj = {}
			if S.controlledObjects then
				for obj, ctrl in pairs(S.controlledObjects) do
					if obj and obj.Parent and ctrl and ctrl ~= "None" and not seenObj[obj] then
						seenObj[obj] = true
						table.insert(activeList, obj)
					end
				end
			end
			for _, obj in ipairs(SpawnedModelsFolder:GetChildren()) do
				local ctrl = obj:GetAttribute("ControllerType2005")
				if not seenObj[obj] and ctrl and ctrl ~= "None" then
					seenObj[obj] = true
					table.insert(activeList, obj)
				end
			end

			local controlled = {}
			for _, obj in ipairs(activeList) do
				local ctrl = obj:GetAttribute("ControllerType2005")
				if ctrl == "KeyboardRight" or ctrl == "Player" then
					S.arrowKeysDriveModels = true
				end
				local ok, pivot = pcall(obj.GetPivot, obj)
				if ok and pivot then
					table.insert(controlled, { Obj = obj, Ctrl = ctrl, Pos = pivot.Position })
				end
			end

			local refTargetPos = (S.activeControlledModel and S.activeControlledModel.Parent and S.activeControlledModel:GetPivot().Position)
				or (Camera and Camera.CFrame.Position)
				or Vector3.zero

			-- Chase / Flee aim at the nearest model whose controller differs from their own
			local function findChaseTarget(selfObj, selfCtrl, selfPos)
				local best, bestDist = nil, math.huge
				for _, info in ipairs(controlled) do
					if info.Obj ~= selfObj and info.Ctrl ~= selfCtrl then
						local d = (info.Pos - selfPos).Magnitude
						if d < bestDist then
							best, bestDist = info.Pos, d
						end
					end
				end
				return best or refTargetPos
			end

			S.motorClock = (S.motorClock or 0) + dt * 4.5

			-- Track which models have active wheel motors so we don't lock wheeled vehicles with a figure BodyGyro
			local wheeledModels = {}
			if S.activeMotors then
				for _, mdata in ipairs(S.activeMotors) do
					if mdata.Model and (mdata.Input == "LeftTread" or mdata.Input == "RightTread") then
						wheeledModels[mdata.Model] = true
					end
				end
			end

			-- 2005 controllers worked through motors; only the PhysicalCharacter figures walked by themselves
			for _, obj in ipairs(activeList) do
				local ctrl = obj:GetAttribute("ControllerType2005")
				if ctrl and ctrl ~= "None" and not wheeledModels[obj] and obj:GetAttribute("IsDynabloxFigure") then
					local rootPart = nil
					if obj:IsA("Model") then
						rootPart = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChild("Torso") or obj:FindFirstChildWhichIsA("BasePart", true)
					elseif obj:IsA("BasePart") then
						rootPart = obj
					end

					if rootPart and not rootPart.Anchored then
						-- Command-Moving Part Physics: rigid upright BodyGyro + direct linear velocity along facing direction!
						local gyro = ensureUprightGyro(rootPart, nil)
						local frontOffset = rootPart:GetAttribute("ModelFrontYaw2005") or 0
						local curYaw = rootPart:GetAttribute("RBLX04Yaw")
						if type(curYaw) ~= "number" then
							local _, ry, _ = rootPart.CFrame:ToEulerAnglesYXZ()
							curYaw = ry
						end

						local speed = 0
						if isKeyboardController(ctrl) then
							local fwd, turn = getControllerInput(ctrl)
							if math.abs(turn) > 0.01 then
								curYaw = curYaw + turn * 3.0 * dt
								rootPart:SetAttribute("RBLX04Yaw", curYaw)
								rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, curYaw, 0)
							end
							if gyro then gyro.CFrame = CFrame.Angles(0, curYaw, 0) end
							speed = fwd * 16
						elseif ctrl == "Chase" then
							local diff = (findChaseTarget(obj, ctrl, rootPart.Position) - rootPart.Position) * Vector3.new(1, 0, 1)
							if diff.Magnitude > 2.2 then
								curYaw = math.atan2(-diff.X, -diff.Z) - frontOffset
								rootPart:SetAttribute("RBLX04Yaw", curYaw)
								if gyro then gyro.CFrame = CFrame.Angles(0, curYaw, 0) end
								speed = 14
							end
						elseif ctrl == "Flee" then
							local diff = (rootPart.Position - findChaseTarget(obj, ctrl, rootPart.Position)) * Vector3.new(1, 0, 1)
							if diff.Magnitude < 65 and diff.Magnitude > 0.1 then
								curYaw = math.atan2(-diff.X, -diff.Z) - frontOffset
								rootPart:SetAttribute("RBLX04Yaw", curYaw)
								if gyro then gyro.CFrame = CFrame.Angles(0, curYaw, 0) end
								speed = 14
							end
						end

						local facingDir = CFrame.Angles(0, curYaw + frontOffset, 0).LookVector
						if math.abs(speed) > 0.1 then
							rootPart.AssemblyLinearVelocity = Vector3.new(facingDir.X * speed, rootPart.AssemblyLinearVelocity.Y, facingDir.Z * speed)
						elseif isKeyboardController(ctrl) then
							rootPart.AssemblyLinearVelocity = Vector3.new(0, rootPart.AssemblyLinearVelocity.Y, 0)
						end
					end
				end
			end

			-- Drive all 2004 HingeConstraint Motors (LeftTread, RightTread, Steer, Throtle, Constant, Sin)
			if S.activeMotors then
				for i = #S.activeMotors, 1, -1 do
					local mdata = S.activeMotors[i]
					local hc = mdata and mdata.Constraint
					if not hc or not hc.Parent then
						table.remove(S.activeMotors, i)
					else
						local inp = mdata.Input
						local mdl = mdata.Model
						local mCtrl = mdl and mdl:GetAttribute("ControllerType2005") or "None"
						local mFwd, mTurn = getControllerInput(mCtrl)
						local root = mdl and mdl:IsA("Model") and mdl.PrimaryPart
						if (mCtrl == "Chase" or mCtrl == "Flee") and root then
							local frontCF = root.CFrame * CFrame.Angles(0, root:GetAttribute("ModelFrontYaw2005") or 0, 0)
							local look = frontCF.LookVector * Vector3.new(1, 0, 1)
							local right = frontCF.RightVector * Vector3.new(1, 0, 1)
							local targetPos = findChaseTarget(mdl, mCtrl, root.Position)
							local diff = ((mCtrl == "Chase") and (targetPos - root.Position) or (root.Position - targetPos)) * Vector3.new(1, 0, 1)
							if (mCtrl == "Chase" and diff.Magnitude > 2.0) or (mCtrl == "Flee" and diff.Magnitude < 65 and diff.Magnitude > 0.1) then
								mFwd = (diff.Unit:Dot(look) >= -0.2) and 1 or -1
								mTurn = -math.clamp(diff.Unit:Dot(right) * 2.0, -1, 1)
							else
								mFwd, mTurn = 0, 0
							end
						end

						if inp == "Constant" then
							hc.AngularVelocity = S.isSimulationRunning and 6.5 or 0
						elseif inp == "Sin" then
							hc.AngularVelocity = S.isSimulationRunning and (math.sin((S.motorClock or 0)) * 6.0) or 0
						elseif inp == "LeftTread" then
							hc.AngularVelocity = (mFwd * 16) - (mTurn * 12)
						elseif inp == "RightTread" then
							hc.AngularVelocity = -(mFwd * 16) - (mTurn * 12)
						elseif inp == "Throtle" then
							hc.AngularVelocity = mFwd * 14
						elseif inp == "Steer" then
							hc.AngularVelocity = mTurn * 8
						end
					end
				end
			end

		end
	end))
end

end)()

--========================================================


-- 15. 2006 NAMES AND HEALTH BARS OVER HEADS
--========================================================
S._run = (function()
	local HEALTH_GREEN = Color3.new(0.5058824, 0.7725491, 0.08627451)
	local NAME_TAG_TEXT_SIZE = 16
	local NAME_TAG_BAR_WIDTH = 60
	local NAME_TAG_BAR_HEIGHT = 7
	local MAX_NAME_TAGS = 40
	local DISPLAY_DISTANCES = { "NameDisplayDistance", "HealthDisplayDistance" }

	local function disconnectAll(connections)
		for _, conn in ipairs(connections) do
			conn:Disconnect()
		end
	end

	local function getGameDistance(humanoid, property)
		local saved = humanoid:GetAttribute("Classic2006" .. property)
		if type(saved) == "number" then
			return saved
		end
		return humanoid[property]
	end

	local function holdDisplayDistances(humanoid)
		local connections = {}
		for _, property in ipairs(DISPLAY_DISTANCES) do
			local attribute = "Classic2006" .. property
			local function hold()
				local value = humanoid[property]
				if value ~= 0 or humanoid:GetAttribute(attribute) == nil then
					humanoid:SetAttribute(attribute, value)
				end
				if value ~= 0 then
					humanoid[property] = 0
				end
			end
			hold()
			table.insert(connections, humanoid:GetPropertyChangedSignal(property):Connect(hold))
		end
		return connections
	end

	local function releaseDisplayDistances(humanoid)
		for _, property in ipairs(DISPLAY_DISTANCES) do
			local attribute = "Classic2006" .. property
			local saved = humanoid:GetAttribute(attribute)
			if type(saved) == "number" then
				humanoid:SetAttribute(attribute, nil)
				humanoid[property] = saved
			end
		end
	end

	if Config.USE_2006_NAME_TAGS then
		for _, container in ipairs({ CoreGui, LocalPlayer:FindFirstChildOfClass("PlayerGui") }) do
			pcall(function()
				local old = container and container:FindFirstChild("Classic2006NameTags")
				if old then
					old:Destroy()
				end
			end)
		end
		local NameTagFolder = Instance.new("Folder")
		NameTagFolder.Name = "Classic2006NameTags"
		if not pcall(function()
			NameTagFolder.Parent = CoreGui
		end) then
			NameTagFolder.Parent = LocalPlayer:WaitForChild("PlayerGui")
		end
		local nameTags = {}
		local nameTagsRunning = true
		local viewerHumanoid = nil
		local viewerHold = {}

		local function getTagName(tag)
			local displayName = tag.humanoid.DisplayName
			if displayName ~= "" then
				return displayName
			end
			return tag.model.Name
		end

		local function layoutNameTag(tag)
			local scale = getClassicUIScale()
			local textSize = scaleTextSize(NAME_TAG_TEXT_SIZE, scale)
			local nameHeight = textSize + 4
			local barWidth = NAME_TAG_BAR_WIDTH * scale
			local barHeight = NAME_TAG_BAR_HEIGHT * scale
			local height = nameHeight + scale + barHeight
			local width = math.max(get2006TextWidth(tag.name, textSize), barWidth) + 8 * scale
			tag.scale = scale
			tag.gui.Size = UDim2.fromOffset(width, height * 2)
			tag.nameLabel.Size = UDim2.new(1, 0, 0, nameHeight)
			tag.nameLabel.TextSize = textSize
			tag.barBack.Position = UDim2.new(0.5, 0, 0, height - barHeight)
			tag.barBack.Size = UDim2.fromOffset(barWidth, barHeight)
		end

		local function buildNameTag(tag)
			local gui = Instance.new("BillboardGui")
			gui.Name = "NameTag"
			gui.AlwaysOnTop = true
			gui.LightInfluence = 0
			gui.ResetOnSpawn = false
			gui.ExtentsOffsetWorldSpace = Vector3.new(0, 1, 0)
			gui.StudsOffsetWorldSpace = Vector3.new(0, 0.5, 0)
			gui:SetAttribute("ClassicOwned", true)
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Name = "NameLabel"
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = tag.name
			nameLabel.TextColor3 = Color3.new(1, 1, 1)
			nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			nameLabel.TextStrokeTransparency = 0
			nameLabel.Parent = gui
			local barBack = Instance.new("Frame")
			barBack.Name = "HealthBar"
			barBack.AnchorPoint = Vector2.new(0.5, 0)
			barBack.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
			barBack.BorderSizePixel = 0
			barBack.Parent = gui
			local barFill = Instance.new("Frame")
			barFill.Name = "Fill"
			barFill.BackgroundColor3 = HEALTH_GREEN
			barFill.BorderSizePixel = 0
			barFill.Parent = barBack
			tag.gui = gui
			tag.nameLabel = nameLabel
			tag.barBack = barBack
			tag.barFill = barFill
			layoutNameTag(tag)
			apply2006Font(nameLabel)
			gui.Parent = NameTagFolder
		end

		local function hideNameTag(tag, keep)
			if tag.gui then
				if keep then
					tag.gui.Enabled = false
				else
					tag.gui:Destroy()
					tag.gui = nil
				end
			end
		end

		local function hasOtherNameTag(tag)
			local now = os.clock()
			if tag.otherNameCheckedAt and now - tag.otherNameCheckedAt < 2 then
				return tag.otherName
			end
			tag.otherNameCheckedAt = now
			tag.otherName = false
			if tag.name == "" then
				return false
			end
			for _, obj in ipairs(tag.model:GetDescendants()) do
				if (obj:IsA("TextLabel") or obj:IsA("TextButton"))
					and string.find(obj.Text, tag.name, 1, true)
					and obj:FindFirstAncestorWhichIsA("BillboardGui") then
					tag.otherName = true
					break
				end
			end
			return tag.otherName
		end

		local function getNameTagView(tag)
			local humanoid = tag.humanoid
			local head = tag.model:FindFirstChild("Head")
			local camera = Workspace.CurrentCamera
			local displayType = humanoid.DisplayDistanceType
			if not (head and head:IsA("BasePart") and camera)
				or displayType == Enum.HumanoidDisplayDistanceType.None
				or tag.model == LocalPlayer.Character
				or hasOtherNameTag(tag) then
				return nil
			end
			local source = humanoid
			if displayType == Enum.HumanoidDisplayDistanceType.Viewer then
				source = viewerHumanoid
			end
			local nameDistance, healthDistance = 100, 100
			if source then
				nameDistance = getGameDistance(source, "NameDisplayDistance")
				healthDistance = getGameDistance(source, "HealthDisplayDistance")
			end
			local distance = (camera.CFrame.Position - head.Position).Magnitude
			local healthType = humanoid.HealthDisplayType
			return {
				head = head,
				distance = distance,
				range = math.max(nameDistance, healthDistance),
				showName = distance <= nameDistance,
				showHealth = distance <= healthDistance
					and (healthType == Enum.HumanoidHealthDisplayType.AlwaysOn
						or (healthType == Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
							and humanoid.Health < humanoid.MaxHealth))
			}
		end

		local function showNameTag(tag, view)
			if not tag.gui then
				buildNameTag(tag)
			elseif tag.scale ~= getClassicUIScale() then
				layoutNameTag(tag)
			end
			local humanoid = tag.humanoid
			local fraction = 1
			if humanoid.MaxHealth > 0 then
				fraction = humanoid.Health / humanoid.MaxHealth
			end
			if fraction ~= fraction then
				fraction = 1
			end
			tag.gui.Adornee = view.head
			tag.nameLabel.Visible = view.showName
			tag.barBack.Visible = view.showHealth
			tag.barFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
			tag.gui.Enabled = true
		end

		local function updateNameTag(tag)
			if not (tag.gui and tag.gui.Enabled) then
				return
			end
			local view = getNameTagView(tag)
			if view and (view.showName or view.showHealth) then
				showNameTag(tag, view)
			else
				hideNameTag(tag, view ~= nil)
			end
		end

		local function renameNameTag(tag)
			local name = getTagName(tag)
			if name ~= tag.name then
				tag.name = name
				if tag.gui then
					tag.nameLabel.Text = name
					layoutNameTag(tag)
				end
			end
		end

		local function updateSubjectHold(tag)
			local isSubject = tag.humanoid.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.Subject
			if isSubject and not tag.hold then
				tag.hold = holdDisplayDistances(tag.humanoid)
			elseif not isSubject then
				if tag.hold then
					disconnectAll(tag.hold)
					tag.hold = nil
				end
				releaseDisplayDistances(tag.humanoid)
			end
		end

		local function untrackHumanoid(humanoid, giveBack)
			local tag = nameTags[humanoid]
			if not tag then
				return
			end
			nameTags[humanoid] = nil
			disconnectAll(tag.connections)
			if tag.hold then
				disconnectAll(tag.hold)
				tag.hold = nil
				if giveBack then
					pcall(releaseDisplayDistances, humanoid)
				end
			end
			hideNameTag(tag, false)
		end

		local function trackHumanoid(humanoid)
			if nameTags[humanoid] or not nameTagsRunning or not humanoid:IsDescendantOf(Workspace) then
				return
			end
			local model = humanoid.Parent
			if not (model and model:IsA("Model")) or model == LocalPlayer.Character then
				return
			end
			local tag = { humanoid = humanoid, model = model, connections = {} }
			tag.name = getTagName(tag)
			nameTags[humanoid] = tag
			local function update()
				pcall(updateNameTag, tag)
			end
			local function rename()
				pcall(renameNameTag, tag)
			end
			tag.connections = {
				humanoid.HealthChanged:Connect(update),
				humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update),
				humanoid:GetPropertyChangedSignal("HealthDisplayType"):Connect(update),
				humanoid:GetPropertyChangedSignal("DisplayDistanceType"):Connect(function()
					pcall(updateSubjectHold, tag)
					update()
				end),
				humanoid:GetPropertyChangedSignal("DisplayName"):Connect(rename),
				model:GetPropertyChangedSignal("Name"):Connect(rename),
				humanoid.AncestryChanged:Connect(function()
					if humanoid.Parent ~= model or not humanoid:IsDescendantOf(Workspace) then
						untrackHumanoid(humanoid, true)
						task.defer(pcall, trackHumanoid, humanoid)
					end
				end)
			}
			updateSubjectHold(tag)
		end

		local function holdViewer(character)
			local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
			if not humanoid or not nameTagsRunning or LocalPlayer.Character ~= character then
				return
			end
			untrackHumanoid(humanoid, false)
			disconnectAll(viewerHold)
			viewerHumanoid = humanoid
			viewerHold = holdDisplayDistances(humanoid)
		end

		storeConnection({
			Disconnect = function()
				nameTagsRunning = false
				for humanoid in pairs(nameTags) do
					untrackHumanoid(humanoid, false)
				end
				disconnectAll(viewerHold)
				NameTagFolder:Destroy()
			end
		})
		if LocalPlayer.Character then
			task.spawn(pcall, holdViewer, LocalPlayer.Character)
		end
		storeConnection(LocalPlayer.CharacterAdded:Connect(function(character)
			pcall(holdViewer, character)
		end))
		storeConnection(Workspace.DescendantAdded:Connect(function(obj)
			if obj:IsA("Humanoid") then
				task.defer(pcall, trackHumanoid, obj)
			end
		end))
		task.spawn(function()
			for index, obj in ipairs(Workspace:GetDescendants()) do
				if obj:IsA("Humanoid") then
					pcall(trackHumanoid, obj)
				end
				if index % 500 == 0 then
					task.wait()
				end
			end
		end)
		task.spawn(function()
			while nameTagsRunning do
				local views = {}
				for _, tag in pairs(nameTags) do
					local ok, view = pcall(getNameTagView, tag)
					if ok and view and (view.showName or view.showHealth) then
						view.tag = tag
						table.insert(views, view)
					else
						pcall(hideNameTag, tag, ok and view ~= nil and view.distance <= view.range + 25)
					end
				end
				table.sort(views, function(a, b)
					return a.distance < b.distance
				end)
				for index, view in ipairs(views) do
					if index <= MAX_NAME_TAGS then
						pcall(showNameTag, view.tag, view)
					else
						pcall(hideNameTag, view.tag, index <= MAX_NAME_TAGS + 10)
					end
				end
				task.wait(0.2)
			end
		end)
	else
		-- Completely hide all overhead names and health bars on all Humanoids
		for _, container in ipairs({ CoreGui, LocalPlayer:FindFirstChildOfClass("PlayerGui") }) do
			pcall(function()
				local old = container and container:FindFirstChild("Classic2006NameTags")
				if old then old:Destroy() end
			end)
		end
		local function hideHumanoidTag(hum)
			if hum and hum:IsA("Humanoid") then
				pcall(function()
					hum.NameDisplayDistance = 0
					hum.HealthDisplayDistance = 0
					hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				end)
			end
		end
		task.spawn(function()
			for idx, obj in ipairs(Workspace:GetDescendants()) do
				if obj:IsA("Humanoid") then
					hideHumanoidTag(obj)
				end
				if idx % 300 == 0 then task.wait() end
			end
		end)
		storeConnection(Workspace.DescendantAdded:Connect(function(obj)
			if obj:IsA("Humanoid") then
				task.defer(hideHumanoidTag, obj)
			end
		end))
	end
end)()

--========================================================
-- 16. 2006 FONT FOR THE GAME'S TEXT AND OTHER SCRIPTS' TEXT
--========================================================
S._run = (function()
	local GAME_FONT_MARKER = "rbxasset://fonts/families/GothamSSm.json"
	local IS_RETROSTUDIO = false
	pcall(function()
		local replicatedStorage = game:GetService("ReplicatedStorage")
		local modules = replicatedStorage:FindFirstChild("Modules")
		IS_RETROSTUDIO = modules ~= nil
			and modules:FindFirstChild("CustomFont") ~= nil
			and replicatedStorage:FindFirstChild("TimePeriod") ~= nil
			and replicatedStorage:FindFirstChild("Protocols") ~= nil
	end)

	local OTHER_SCRIPT_GUIS = {
		ClassicDialogExecutorGui = true,
		ClassicDialogNoticeGui = true,
		ClassicDialogBillboardHost = true
	}

	local function isOtherScriptText(obj)
		if obj:FindFirstAncestorWhichIsA("BillboardGui") then
			return true
		end
		local node = obj.Parent
		while node do
			if OTHER_SCRIPT_GUIS[node.Name] then
				return true
			end
			node = node.Parent
		end
		return false
	end

	local function isOverCharacter(billboard)
		for _, start in ipairs({ billboard, billboard.Adornee }) do
			if start then
				local model = start.ClassName == "Model" and start or start:FindFirstAncestorOfClass("Model")
				while model do
					if model:FindFirstChildOfClass("Humanoid") then
						return true
					end
					model = model:FindFirstAncestorOfClass("Model")
				end
			end
		end
		return false
	end

	local function isOverheadText(obj)
		local billboard = obj:FindFirstAncestorWhichIsA("BillboardGui")
		return billboard ~= nil and isOverCharacter(billboard)
	end

	local function convertGameText(obj, filter)
		-- apply2006Font tags every label it converts with the Classic2006Font attribute
		if obj:GetAttribute("Classic2006Font")
			or obj:GetAttribute("No2006Font")
			or obj:IsDescendantOf(ScoreTimerFrame)
			or obj:IsDescendantOf(ScreenGui) then
			return
		end
		if filter and not filter(obj) then
			return
		end
		if parentTarget ~= CoreGui and obj:IsDescendantOf(parentTarget) and not isOtherScriptText(obj) then
			return
		end
		if obj:FindFirstAncestor("Chat")
			or obj:FindFirstChild("TextContent")
			or obj:FindFirstAncestor("TextContent") then
			return
		end
		local parent = obj.Parent
		if parent and parent:FindFirstChildWhichIsA("TextBox") then
			return
		end
		local family = string.lower(obj.FontFace.Family)
		if string.find(family, "mono", 1, true) or string.find(family, "inconsolata", 1, true) then
			return
		end
		if IS_RETROSTUDIO and obj.FontFace.Family == GAME_FONT_MARKER then
			return
		end
		apply2006Font(obj)
	end

	local function isGameText(obj)
		return obj:IsA("TextLabel") or obj:IsA("TextButton")
	end

	local function watchGameText(root, filter)
		storeConnection(
			root.DescendantAdded:Connect(function(obj)
				if isGameText(obj) then
					task.defer(pcall, convertGameText, obj, filter)
				end
			end)
		)
		for index, obj in ipairs(root:GetDescendants()) do
			if isGameText(obj) then
				pcall(convertGameText, obj, filter)
			end
			if index % 200 == 0 then
				task.wait()
			end
		end
	end

	if Config.APPLY_2006_FONT_TO_GAME_GUIS then
		task.spawn(watchGameText, LocalPlayer:WaitForChild("PlayerGui"))
	end
	if Config.APPLY_2006_FONT_TO_WORLD_TEXT then
		task.spawn(watchGameText, Workspace)
	end
	if Config.APPLY_2006_FONT_TO_ROBLOX_MENUS then
		task.spawn(watchGameText, CoreGui)
	end
	if Config.APPLY_2006_FONT_TO_OTHER_SCRIPTS then
		if not Config.APPLY_2006_FONT_TO_ROBLOX_MENUS then
			task.spawn(watchGameText, CoreGui, isOtherScriptText)
		end
		if parentTarget ~= CoreGui and not parentTarget:IsDescendantOf(CoreGui) then
			task.spawn(watchGameText, parentTarget, isOtherScriptText)
		end
		if not Config.APPLY_2006_FONT_TO_GAME_GUIS then
			task.spawn(watchGameText, LocalPlayer:WaitForChild("PlayerGui"), isOtherScriptText)
		end
		if not Config.APPLY_2006_FONT_TO_WORLD_TEXT then
			task.spawn(watchGameText, Workspace, isOverheadText)
		end
	end
end)()

--========================================================
-- FINAL TEXT CHAT & 3-DOT BUBBLE SAFETY
--========================================================
task.spawn(function()
	while ScreenGui and ScreenGui.Parent do
		disableDefaultBubblesAnd3Dots()
		task.wait(0.25)
	end
end)
