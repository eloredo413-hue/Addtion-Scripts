--========================================================
-- HIDE GAME GUI
--========================================================
-- Hides the game's own on-screen GUI: TopbarPlus buttons
-- (TopbarStandard / TopbarCentered), shop buttons, menus, HUDs,
-- coin counters, every ScreenGui the game puts in PlayerGui.
--
-- It never hides anything made by our scripts (Bloxy Paradox and its
-- top bar / menu, the 2005, 2010, 2013, 2015, 2017, 2019, 2023 and
-- 2024 GUIs, Old Chrome 2024, 2017 chat, Voxel terrain, ForceField
-- 2014, the dialog scripts, ...):
--
--   * Nothing in CoreGui or gethui() is ever touched. A game cannot
--     put GUI there, and that is where most of our scripts draw.
--   * A GUI made by ANY executor script after this one has started
--     is remembered (Instance.new / :Clone() are watched) and left
--     alone. That covers scripts those scripts download too.
--   * GUIs our scripts put in PlayerGui are also known by name (see
--     KEEP_NAMES / KEEP_PATTERNS), for when this runs after them.
--   * Roblox's own controls in PlayerGui (TouchGui, Chat, BubbleChat,
--     Freecam, ProximityPrompts) stay, so moving and chat still work.
--
-- Best: run this FIRST (auto-execute), then the other scripts. Run
-- after them it still works, using the name list.
--
-- Toggle with Right Ctrl, or from another script:
--   getgenv().GameGuiHider.Toggle() / .Show() / .Hide() / .IsHidden()
--   getgenv().GameGuiHider.Keep(guiOrName)   -- never hide this one
--   getgenv().GameGuiHiderCleanup()          -- stop, show everything
--========================================================

------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------
local TOGGLE_KEY = Enum.KeyCode.RightControl -- nil = no key
local START_HIDDEN = true

-- Exact ScreenGui names that are ours (never hidden).
local KEEP_NAMES = {
	-- Bloxy Paradox (menu / retro top bar, its loaders and hooks)
	"BloxyParadoxProject",
	"ClassicDialogExecutorGui",
	"ClassicDialogNoticeGui",
	"ClassicDialogBillboardHost",
	"OldRobloxGui",
	"OldLoadingScreen",
	"PlayerList",
	"CustomHealthGui",
	"CustomCursorSystem",
	"LoadingGui",
	-- 2005 / 2010 GUI
	"Classic2010Gui",
	-- 2013 GUI
	"LegacyMobileUI_FunctionalReplacement",
	"LegacyMobileUI_Dialog",
	"LegacyTouchControls",
	-- Legacy / 2017 / 2019 core gui
	"NewRobloxGui",
	"NewRobloxGuiOld",
	"RobloxGui",
	"TopBarApp",
	"TopBar",
	"LoadingScreen",
	-- 2017 chat, 2023 GUI
	"Chat2017Gui",
	"Settings2016AlreadyGui",
	-- Voxel terrain, ForceField 2014
	"Voxel2013StatusGui",
	"ForceField2014Tint",
	-- Roblox's own controls / chat (not the game's GUI)
	"TouchGui",
	"Chat",
	"BubbleChat",
	"Freecam",
	"ProximityPrompts",
}

-- Name patterns (Lua patterns) that are ours.
local KEEP_PATTERNS = {
	"Bloxy",
	"Paradox",
	"^Settings2016",
	"^Classic",
	"^Legacy",
	"^Old",
	"^__OldChrome",
	"Chat2017",
	"20[012]%d",   -- era-named GUIs: 2005Gui, Topbar2017, ...
	"^GameGuiHider",
}

------------------------------------------------------------
-- SERVICES
------------------------------------------------------------
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
	task.wait()
	LocalPlayer = Players.LocalPlayer
end
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Env = (getgenv and getgenv()) or _G

-- Running it again replaces the old copy.
if Env.GameGuiHiderCleanup then
	pcall(Env.GameGuiHiderCleanup)
	Env.GameGuiHiderCleanup = nil
end

------------------------------------------------------------
-- REMEMBER GUIs MADE BY EXECUTOR SCRIPTS
------------------------------------------------------------
-- Kept on getgenv() so a second run keeps what the first one saw.
-- The hooks are installed only once per game session.
Env.GameGuiHiderMarks = Env.GameGuiHiderMarks or setmetatable({}, { __mode = "k" })
local Marks = Env.GameGuiHiderMarks

if not Env.GameGuiHiderHooked
	and type(checkcaller) == "function"
	and type(newcclosure) == "function" then

	local function mark(inst)
		if typeof(inst) == "Instance" and inst:IsA("LayerCollector") then
			Env.GameGuiHiderMarks[inst] = true
		end
	end

	if type(hookfunction) == "function" then
		pcall(function()
			local oldNew
			oldNew = hookfunction(Instance.new, newcclosure(function(...)
				local inst = oldNew(...)
				if checkcaller() then
					pcall(mark, inst)
				end
				return inst
			end))
		end)
	end

	-- (Addtion-Scripts) No __namecall hook here any more (it marked GUIs our scripts Clone): every method call
	-- of every script in the game went through it, which got in the way of a lot of games. Cloned GUIs of
	-- ours are kept by their names (KEEP_NAMES / KEEP_PATTERNS) instead.

	Env.GameGuiHiderHooked = true
end

------------------------------------------------------------
-- OURS OR THE GAME'S?
------------------------------------------------------------
local keepNameSet = {}
for _, name in ipairs(KEEP_NAMES) do
	keepNameSet[name] = true
end
local keepInstances = setmetatable({}, { __mode = "k" })

local function isOurs(gui)
	if Marks[gui] or keepInstances[gui] then
		return true
	end
	local name = gui.Name
	if keepNameSet[name] then
		return true
	end
	for _, pattern in ipairs(KEEP_PATTERNS) do
		if string.find(name, pattern) then
			return true
		end
	end
	return false
end

-- Only top-level ScreenGuis (a ScreenGui inside another one is
-- drawn as part of its parent, so the parent decides).
local function isTopScreenGui(inst)
	if not inst:IsA("ScreenGui") or not inst:IsDescendantOf(PlayerGui) then
		return false
	end
	local parent = inst.Parent
	while parent and parent ~= PlayerGui do
		if parent:IsA("LayerCollector") then
			return false
		end
		parent = parent.Parent
	end
	return true
end

------------------------------------------------------------
-- HIDING
------------------------------------------------------------
local hidden = false
local tracked = {} -- [gui] = { wasEnabled = bool, conns = {...} }
local connections = {}

local function untrack(gui, restore)
	local info = tracked[gui]
	if not info then return end
	tracked[gui] = nil
	for _, c in ipairs(info.conns) do
		c:Disconnect()
	end
	if restore and gui.Parent then
		pcall(function() gui.Enabled = info.wasEnabled end)
	end
end

local function hideGui(gui)
	if tracked[gui] or isOurs(gui) then return end
	local info = { wasEnabled = gui.Enabled, conns = {} }
	tracked[gui] = info

	-- The game turning it back on while hidden: keep it off, but
	-- remember that the game wants it on for when we show again.
	table.insert(info.conns, gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if hidden and gui.Enabled then
			if isOurs(gui) then
				untrack(gui, false)
				return
			end
			info.wasEnabled = true
			gui.Enabled = false
		end
	end))

	-- Renamed to one of ours (a script that parents first, names later).
	table.insert(info.conns, gui:GetPropertyChangedSignal("Name"):Connect(function()
		if isOurs(gui) then
			untrack(gui, true)
		end
	end))

	table.insert(info.conns, gui.AncestryChanged:Connect(function()
		if not gui:IsDescendantOf(PlayerGui) then
			untrack(gui, false)
		end
	end))

	pcall(function() gui.Enabled = false end)
end

local function consider(inst)
	if hidden and isTopScreenGui(inst) then
		hideGui(inst)
	end
end

local function hideAll()
	hidden = true
	for _, inst in ipairs(PlayerGui:GetDescendants()) do
		consider(inst)
	end
end

local function showAll()
	hidden = false
	for gui in pairs(tracked) do
		untrack(gui, true)
	end
end

-- New GUIs (respawn copies from StarterGui, GUIs made by game
-- scripts). Wait a frame so a script that names its GUI right after
-- parenting it is seen with its real name.
table.insert(connections, PlayerGui.DescendantAdded:Connect(function(inst)
	if not inst:IsA("ScreenGui") then return end
	task.defer(function()
		if inst.Parent then
			consider(inst)
		end
	end)
end))

------------------------------------------------------------
-- TOGGLE KEY
------------------------------------------------------------
if TOGGLE_KEY then
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == TOGGLE_KEY then
			if hidden then showAll() else hideAll() end
		end
	end))
end

------------------------------------------------------------
-- API
------------------------------------------------------------
local function cleanup()
	for _, c in ipairs(connections) do
		c:Disconnect()
	end
	table.clear(connections)
	showAll()
	if Env.GameGuiHider and Env.GameGuiHider._cleanup == cleanup then
		Env.GameGuiHider = nil
	end
end

Env.GameGuiHider = {
	Hide = hideAll,
	Show = showAll,
	Toggle = function()
		if hidden then showAll() else hideAll() end
		return hidden
	end,
	IsHidden = function()
		return hidden
	end,
	-- Never hide this GUI (an Instance) or GUIs with this name (a string).
	Keep = function(target)
		if typeof(target) == "Instance" then
			keepInstances[target] = true
			untrack(target, true)
		elseif type(target) == "string" then
			keepNameSet[target] = true
			for gui in pairs(tracked) do
				if gui.Name == target then
					untrack(gui, true)
				end
			end
		end
	end,
	_cleanup = cleanup,
}
Env.GameGuiHiderCleanup = cleanup

if START_HIDDEN then
	hideAll()
end
