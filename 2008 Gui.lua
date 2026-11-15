-- [[ 2008 ROBLOX LOOK - built on the 2010 GUI ]]
-- (Addtion-Scripts: the repo copy of the 2008 GUI gist, loaded in its place by the loader. The health bar is
-- the 2008 client's: a short bar on the right just under the player list, "Health" under it.)
-- [[ TEXTCHATSERVICE CHAT ]]
-- [[ 2008 CARTOON FONT EVERYWHERE (like the 2006 GUI does with its font) ]]
-- [[ NO CHAT BUBBLES, NO SCREENSHOT BUTTON ]]
-- [[ CAMERA BUTTONS DOWN IN THE BOTTOM-RIGHT CORNER, REPORT ABUSE RIGHT ABOVE THEM ]]
-- [[ NO LEGACY CHAT FALLBACK ]]
--========================================================
-- SETTINGS
--========================================================
-- The font 2008 Roblox used: Roblox's Cartoon font
local CARTOON_FONT = Enum.Font.Cartoon
-- Names and health bars over characters and NPCs in the cartoon font. Roblox's own can't change
-- font, so they're hidden and drawn again by this script.
local USE_CARTOON_NAME_TAGS = true
-- Also switch the game's own on-screen text (PlayerGui) to the cartoon font. Text boxes are never touched.
local APPLY_CARTOON_FONT_TO_GAME_GUIS = true
-- Also switch other executor scripts' text to the cartoon font: the Bloxy Paradox loader's NPC
-- dialog box, notices and dialog bubbles, and anything drawn over characters and NPCs (health
-- bar ESPs, name tags). Executor menus are left alone, so their code editors keep their own fonts.
local APPLY_CARTOON_FONT_TO_OTHER_SCRIPTS = true
-- Also switch every other sign and label in the world (BillboardGui / SurfaceGui) to the cartoon font.
local APPLY_CARTOON_FONT_TO_WORLD_TEXT = false
-- Also switch Roblox's own menus and pop-ups (CoreGui) to the cartoon font.
local APPLY_CARTOON_FONT_TO_ROBLOX_MENUS = false
--========================================================
-- CLEANUP
--========================================================
if _G.CustomHealthESP_Connections then
	for _, conn in pairs(_G.CustomHealthESP_Connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
end
_G.CustomHealthESP_Connections = {}
local function storeConnection(conn)
	if conn then
		table.insert(_G.CustomHealthESP_Connections, conn)
	end
	return conn
end
--========================================================
-- SERVICES
--========================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
--========================================================
-- DISABLE DEFAULT ROBLOX UI
--========================================================
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)
--========================================================
-- TEXT CHAT
--========================================================
local GeneralChannel = nil
local function findGeneralChannel()
	local channels =
		TextChatService:FindFirstChild("TextChannels")
	if not channels then
		channels =
			TextChatService:WaitForChild(
				"TextChannels",
				5
			)
	end
	if not channels then
		warn(
			"[2010 Chat] TextChatService.TextChannels was not found."
		)
		return nil
	end
	local channel =
		channels:FindFirstChild("RBXGeneral")
	if channel and channel:IsA("TextChannel") then
		return channel
	end
	channel =
		channels:WaitForChild(
			"RBXGeneral",
			5
		)
	if channel and channel:IsA("TextChannel") then
		return channel
	end
	warn(
		"[2010 Chat] RBXGeneral was not found."
	)
	return nil
end
GeneralChannel = findGeneralChannel()
--========================================================
-- TEXT CHAT CONFIGURATION
--========================================================
pcall(function()
	TextChatService.ChatWindowConfiguration.Enabled = false
	TextChatService.ChatInputBarConfiguration.Enabled = false
end)
--========================================================
-- DISABLE NATIVE BUBBLE CHAT LOCALLY
--========================================================
local function disableDefaultBubbles()
	pcall(function()
		local bubbleConfig = TextChatService:FindFirstChild("BubbleChatConfiguration")
		if bubbleConfig then
			bubbleConfig.Enabled = false
		end
	end)
end

disableDefaultBubbles()
--========================================================
-- TOPBAR APP
--========================================================
pcall(function()
	CoreGui.TopBarApp.TopBarApp.Enabled = false
end)
--========================================================
-- UI PARENT
--========================================================
local parentTarget = CoreGui
pcall(function()
	if type(gethui) == "function" then
		parentTarget = gethui()
	end
end)
-- Remove the GUI left behind by an earlier run of this script (or the 2006 / 2010 GUI)
for _, container in ipairs({ parentTarget, LocalPlayer:FindFirstChildOfClass("PlayerGui") }) do
	pcall(function()
		for _, child in ipairs(container:GetChildren()) do
			if child.Name == "Classic2010Gui" then
				child:Destroy()
			end
		end
	end)
end
--========================================================
-- LOADING SCREEN
--========================================================
local LoadingGui = Instance.new("ScreenGui")
LoadingGui.Name = "LoadingGui"
LoadingGui.ResetOnSpawn = false
LoadingGui.IgnoreGuiInset = true
local success =
	pcall(function()
		LoadingGui.Parent = parentTarget
	end)
if not success or not LoadingGui.Parent then
	LoadingGui.Parent =
		LocalPlayer:WaitForChild("PlayerGui")
end
Camera.CameraType = Enum.CameraType.Scriptable
Camera.CFrame =
	CFrame.new(
		Vector3.new(0, 30, 80),
		Vector3.new(0, 10, 0)
	)
local touchGui =
	LocalPlayer:WaitForChild("PlayerGui"):
	FindFirstChild("TouchGui")
if touchGui then
	touchGui.Enabled = false
end
local mapParts = {}
for _, obj in ipairs(Workspace:GetDescendants()) do
	if obj:IsA("BasePart")
		and obj.Parent ~= LocalPlayer.Character
		and not obj:IsDescendantOf(LocalPlayer.Character) then
		table.insert(
			mapParts,
			{
				Part = obj,
				OriginalTransparency = obj.Transparency
			}
		)
		obj.Transparency = 1
	end
end
local font = Font.fromEnum(CARTOON_FONT)
local ConnectingFrame = Instance.new("Frame")
ConnectingFrame.Name = "ConnectingFrame"
ConnectingFrame.AnchorPoint =
	Vector2.new(0.5, 0.5)
ConnectingFrame.Position =
	UDim2.new(0.5, 0, 0.5, 0)
ConnectingFrame.Size =
	UDim2.new(0, 500, 0, 160)
ConnectingFrame.BackgroundColor3 =
	Color3.fromRGB(220, 220, 220)
ConnectingFrame.BackgroundTransparency = 0.5
ConnectingFrame.BorderColor3 =
	Color3.fromRGB(255, 255, 255)
ConnectingFrame.BorderSizePixel = 1
ConnectingFrame.Parent = LoadingGui
local ConnectingText = Instance.new("TextLabel")
ConnectingText.Name = "ConnectingText"
ConnectingText.Size =
	UDim2.new(1, 0, 1, 0)
ConnectingText.BackgroundTransparency = 1
ConnectingText.FontFace = font
ConnectingText.TextSize = 22
ConnectingText.TextColor3 =
	Color3.fromRGB(255, 255, 255)
ConnectingText.Text =
	"Connecting to Server"
ConnectingText.Parent =
	ConnectingFrame
task.wait(2)
ConnectingFrame:Destroy()
local StatsFrame = Instance.new("Frame")
StatsFrame.Name = "StatsFrame"
StatsFrame.AnchorPoint =
	Vector2.new(0.5, 0.5)
StatsFrame.Position =
	UDim2.new(0.5, 0, 0.5, 0)
StatsFrame.Size =
	UDim2.new(0, 500, 0, 160)
StatsFrame.BackgroundColor3 =
	Color3.fromRGB(220, 220, 220)
StatsFrame.BackgroundTransparency = 0.5
StatsFrame.BorderColor3 =
	Color3.fromRGB(255, 255, 255)
StatsFrame.BorderSizePixel = 3
StatsFrame.Parent = LoadingGui
local StatsText = Instance.new("TextLabel")
StatsText.Name = "StatsText"
StatsText.Size =
	UDim2.new(1, 0, 1, 0)
StatsText.BackgroundTransparency = 1
StatsText.FontFace = font
StatsText.TextSize = 20
StatsText.TextColor3 =
	Color3.fromRGB(255, 255, 255)
StatsText.Text =
	"Bricks: 0   Connectors: 0"
StatsText.Parent = StatsFrame
local totalBricks = #mapParts
local targetConnectors = #Players:GetPlayers()
local steps = 30
local partsPerStep =
	math.ceil(totalBricks / steps)
local currentIndex = 1
for i = 1, steps do
	local currentBricks =
		math.floor(
			(totalBricks / steps) * i
		)
	local currentConnectors =
		math.floor(
			(targetConnectors / steps) * i
		)
	for j = 1, partsPerStep do
		if mapParts[currentIndex] then
			local data =
				mapParts[currentIndex]
			data.Part.Transparency =
				data.OriginalTransparency
			currentIndex =
				currentIndex + 1
		end
	end
	StatsText.Text =
		"Bricks: "
		.. tostring(currentBricks)
		.. "   Connectors: "
		.. tostring(currentConnectors)
	task.wait(0.05)
end
for _, data in ipairs(mapParts) do
	data.Part.Transparency =
		data.OriginalTransparency
end
StatsText.Text =
	"Bricks: "
	.. tostring(totalBricks)
	.. "   Connectors: "
	.. tostring(targetConnectors)
task.wait(1.5)
Camera.CameraType =
	Enum.CameraType.Custom
if LocalPlayer.Character
	and LocalPlayer.Character:FindFirstChild("Humanoid") then
	Camera.CameraSubject =
		LocalPlayer.Character.Humanoid
end
if touchGui then
	touchGui.Enabled = true
end
LoadingGui:Destroy()
--========================================================
-- MAIN SCREEN GUI
--========================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Classic2010Gui"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = parentTarget
local uiScale = Instance.new("UIScale")
uiScale.Parent = ScreenGui
local function updateUIScale()
	local viewport = Camera.ViewportSize
	if viewport.Y < 800
		or viewport.X < 1200 then
		uiScale.Scale =
			math.clamp(
				viewport.Y / 900,
				0.55,
				1
			)
	else
		uiScale.Scale = 1
	end
end
storeConnection(
	Camera:GetPropertyChangedSignal(
		"ViewportSize"
	):Connect(updateUIScale)
)
updateUIScale()
--========================================================
-- TOP BAR
--========================================================
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size =
	UDim2.new(1, 0, 0, 23)
TopBar.Position =
	UDim2.new(0, 0, 0, 0)
TopBar.BackgroundColor3 =
	Color3.fromRGB(144, 144, 144)
TopBar.BackgroundTransparency = 1
TopBar.Parent = ScreenGui
local function createTopButton(
	name,
	text,
	positionX,
	isWhiteText
)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size =
		UDim2.new(0, 100, 0, 20)
	btn.Position =
		UDim2.new(0, positionX, 0, 1)
	btn.BackgroundColor3 =
		Color3.fromRGB(100, 100, 100)
	btn.BackgroundTransparency = 0.4
	btn.BorderSizePixel = 0
	btn.BorderColor3 =
		Color3.fromRGB(100, 100, 100)
	btn.Text = text
	if isWhiteText then
		btn.TextColor3 =
			Color3.fromRGB(255, 255, 255)
		btn.TextTransparency = 0.75
	else
		btn.TextColor3 =
			Color3.fromRGB(0, 0, 0)
		btn.TextTransparency = 0.65
	end
	btn.Font = CARTOON_FONT
	btn.TextSize = 14
	btn.Parent = TopBar
	return btn
end
createTopButton(
	"ToolsBtn",
	"Tools",
	0,
	true
)
createTopButton(
	"InsertBtn",
	"Insert",
	100,
	true
)
createTopButton(
	"FullscreenBtn",
	"Fullscreen",
	200,
	false
)
createTopButton(
	"HelpBtn",
	"Help...",
	300,
	false
)
createTopButton(
	"ExitBtn",
	"Exit",
	400,
	false
)
--========================================================
-- PLAYER LIST
--========================================================
local PlayerList = Instance.new("Frame")
PlayerList.Name = "ClassicPlayerList"
PlayerList.AnchorPoint =
	Vector2.new(1, 0)
PlayerList.Size =
	UDim2.new(0, 265, 0, 180)
PlayerList.Position =
	UDim2.new(1, -15, 0, 32)
PlayerList.BackgroundColor3 =
	Color3.fromRGB(190, 190, 190)
PlayerList.BackgroundTransparency = 0.6
PlayerList.BorderSizePixel = 0
local ListPadding =
	Instance.new("UIPadding")
ListPadding.PaddingTop =
	UDim.new(0, 4)
ListPadding.PaddingLeft =
	UDim.new(0, 8)
ListPadding.PaddingRight =
	UDim.new(0, 8)
ListPadding.Parent =
	PlayerList
PlayerList.Parent =
	ScreenGui
local HeaderFrame =
	Instance.new("Frame")
HeaderFrame.Size =
	UDim2.new(1, 0, 0, 22)
HeaderFrame.BackgroundTransparency = 1
HeaderFrame.Parent =
	PlayerList
local ListTitle =
	Instance.new("TextLabel")
ListTitle.Name = "ListTitle"
ListTitle.BackgroundTransparency = 1
ListTitle.Text = "Player List"
ListTitle.TextColor3 =
	Color3.fromRGB(255, 255, 255)
ListTitle.TextXAlignment =
	Enum.TextXAlignment.Left
ListTitle.Font =
	CARTOON_FONT
ListTitle.TextSize = 14
ListTitle.Parent =
	HeaderFrame
local StatHeaderContainer =
	Instance.new("Frame")
StatHeaderContainer.Name =
	"StatHeaderContainer"
StatHeaderContainer.BackgroundTransparency = 1
StatHeaderContainer.Parent =
	HeaderFrame
local ListScroll =
	Instance.new("ScrollingFrame")
ListScroll.Name =
	"ListScroll"
ListScroll.Size =
	UDim2.new(1, 0, 1, -30)
ListScroll.Position =
	UDim2.new(0, 0, 0, 24)
ListScroll.BackgroundTransparency = 1
ListScroll.BorderSizePixel = 0
ListScroll.CanvasSize =
	UDim2.new(0, 0, 0, 0)
ListScroll.ScrollBarThickness = 4
ListScroll.ScrollBarImageColor3 =
	Color3.fromRGB(120, 120, 120)
ListScroll.Parent =
	PlayerList
local ListLayout =
	Instance.new("UIListLayout")
ListLayout.Padding =
	UDim.new(0, 4)
ListLayout.SortOrder =
	Enum.SortOrder.LayoutOrder
ListLayout.Parent =
	ListScroll
storeConnection(
	ListLayout:GetPropertyChangedSignal(
		"AbsoluteContentSize"
	):Connect(function()
		ListScroll.CanvasSize =
			UDim2.new(
				0,
				0,
				0,
				ListLayout.AbsoluteContentSize.Y
			)
	end)
)
--========================================================
-- PLAYER LIST COLORS
--========================================================
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
		count =
			count + string.byte(name, i)
	end
	return CLASSIC_CHAT_COLORS[
		(count % #CLASSIC_CHAT_COLORS) + 1
	]
end
--========================================================
-- PLAYER LIST HELPERS
--========================================================
local function getPlayerStatObjects(player)
	local stats = {}
	local statsFolder =
		player:FindFirstChild("leaderstats")
	if statsFolder then
		for _, stat in ipairs(
			statsFolder:GetChildren()
		) do
			if stat:IsA("ValueBase") then
				table.insert(stats, stat)
			end
		end
	end
	return stats
end
local function getActiveStatNames()
	local names = {}
	for _, p in ipairs(
		Players:GetPlayers()
	) do
		local statsFolder =
			p:FindFirstChild("leaderstats")
		if statsFolder then
			for _, stat in ipairs(
				statsFolder:GetChildren()
			) do
				if stat:IsA("ValueBase")
					and not table.find(
						names,
						stat.Name
					) then
					table.insert(
						names,
						stat.Name
					)
				end
			end
		end
	end
	return names
end
local function resizeLeaderboardLayout(
	statCount
)
	local baseWidth = 180
	local statColumnWidth = 75
	local calculatedTotalWidth =
		baseWidth
		+ statCount * statColumnWidth
	PlayerList.Size =
		UDim2.new(
			0,
			calculatedTotalWidth,
			0,
			180
		)
	local nameRatio =
		baseWidth / calculatedTotalWidth
	local statsRatio =
		1 - nameRatio
	ListTitle.Size =
		UDim2.new(
			nameRatio,
			0,
			1,
			0
		)
	StatHeaderContainer.Size =
		UDim2.new(
			statsRatio,
			0,
			1,
			0
		)
	StatHeaderContainer.Position =
		UDim2.new(
			nameRatio,
			0,
			0,
			0
		)
	return nameRatio, statsRatio
end
local function updateHeaderTitles()
	local activeStats =
		getActiveStatNames()
	local statCount =
		#activeStats
	local nameRatio, statsRatio =
		resizeLeaderboardLayout(
			statCount
		)
	local existingHeaders =
		StatHeaderContainer:GetChildren()
	if #existingHeaders ~= statCount then
		for _, child in ipairs(
			existingHeaders
		) do
			child:Destroy()
		end
		if statCount == 0 then
			return
		end
		local columnWidth =
			1 / statCount
		for i, statName in ipairs(
			activeStats
		) do
			local label =
				Instance.new("TextLabel")
			label.Name =
				statName
			label.Size =
				UDim2.new(
					columnWidth,
					0,
					1,
					0
				)
			label.Position =
				UDim2.new(
					(i - 1) * columnWidth,
					0,
					0,
					0
				)
			label.BackgroundTransparency = 1
			label.Text =
				statName
			label.TextColor3 =
				Color3.fromRGB(
					255,
					255,
					255
				)
			label.TextXAlignment =
				Enum.TextXAlignment.Center
			label.Font =
				CARTOON_FONT
			label.TextSize = 14
			label.Parent =
				StatHeaderContainer
		end
	end
end
local function createOrUpdateRow(
	rowKey,
	labelText,
	statValuesList,
	textColor,
	isHeader,
	paddingSpaces,
	layoutOrder
)
	local rowFrame =
		ListScroll:FindFirstChild(
			rowKey
		)
	local activeStats =
		getActiveStatNames()
	local statCount =
		#activeStats
	local baseWidth = 180
	local statColumnWidth = 75
	local totalWidth =
		baseWidth
		+ statCount * statColumnWidth
	local nameRatio =
		baseWidth / totalWidth
	local statsRatio =
		1 - nameRatio
	local columnWidth =
		statCount > 0
		and (1 / statCount)
		or 1
	if not rowFrame then
		rowFrame =
			Instance.new("Frame")
		rowFrame.Name =
			rowKey
		rowFrame.Size =
			UDim2.new(
				1,
				-5,
				0,
				18
			)
		rowFrame.BackgroundTransparency = 1
		local leftLabel =
			Instance.new("TextLabel")
		leftLabel.Name =
			"LeftLabel"
		leftLabel.BackgroundTransparency = 1
		leftLabel.Font =
			CARTOON_FONT
		leftLabel.TextXAlignment =
			Enum.TextXAlignment.Left
		leftLabel.Parent =
			rowFrame
		local statContainer =
			Instance.new("Frame")
		statContainer.Name =
			"StatContainer"
		statContainer.BackgroundTransparency = 1
		statContainer.Parent =
			rowFrame
		local underline =
			Instance.new("Frame")
		underline.Name =
			"Underline"
		underline.Size =
			UDim2.new(
				1,
				0,
				0,
				1
			)
		underline.Position =
			UDim2.new(
				0,
				0,
				1,
				-1
			)
		underline.BorderSizePixel = 0
		underline.Parent =
			rowFrame
		rowFrame.Parent =
			ListScroll
	end
	rowFrame.LayoutOrder =
		layoutOrder
	local leftLabel =
		rowFrame.LeftLabel
	leftLabel.Size =
		UDim2.new(
			nameRatio,
			0,
			1,
			0
		)
	leftLabel.Text =
		(paddingSpaces or "")
		.. labelText
	leftLabel.TextSize =
		isHeader and 12 or 14
	leftLabel.TextColor3 =
		textColor
	local statContainer =
		rowFrame.StatContainer
	statContainer.Size =
		UDim2.new(
			statsRatio,
			0,
			1,
			0
		)
	statContainer.Position =
		UDim2.new(
			nameRatio,
			0,
			0,
			0
		)
	local underline =
		rowFrame.Underline
	underline.Visible =
		isHeader
	if isHeader then
		underline.BackgroundColor3 =
			textColor
	end
	for i, statName in ipairs(
		activeStats
	) do
		local statLabel =
			statContainer:FindFirstChild(
				statName
			)
		if not statLabel then
			statLabel =
				Instance.new("TextLabel")
			statLabel.Name =
				statName
			statLabel.BackgroundTransparency = 1
			statLabel.Font =
				CARTOON_FONT
			statLabel.TextXAlignment =
				Enum.TextXAlignment.Center
			statLabel.Parent =
				statContainer
		end
		statLabel.Size =
			UDim2.new(
				columnWidth,
				0,
				1,
				0
			)
		statLabel.Position =
			UDim2.new(
				(i - 1) * columnWidth,
				0,
				0,
				0
			)
		statLabel.TextSize =
			isHeader and 16 or 18
		statLabel.TextColor3 =
			textColor
		local valueText = ""
		if statValuesList
			and statValuesList[statName] then
			valueText =
				tostring(
					statValuesList[statName]
				)
		end
		statLabel.Text =
			valueText
	end
	for _, child in ipairs(
		statContainer:GetChildren()
	) do
		if not table.find(
			activeStats,
			child.Name
		) then
			child:Destroy()
		end
	end
end
local function updatePlayerList()
	updateHeaderTitles()
	local currentTeams =
		Teams:GetTeams()
	local playersMapped = {}
	local activeStats =
		getActiveStatNames()
	local orderIndex = 1
	local activeKeys = {}
	if #currentTeams > 0 then
		for _, team in ipairs(
			currentTeams
		) do
			local teamPlayers =
				team:GetPlayers()
			if #teamPlayers > 0 then
				local teamScores = {}
				for _, statName in ipairs(
					activeStats
				) do
					teamScores[statName] = 0
				end
				for _, p in ipairs(
					teamPlayers
				) do
					local pStats =
						getPlayerStatObjects(p)
					for _, stat in ipairs(
						pStats
					) do
						if (
							stat:IsA("IntValue")
							or stat:IsA("NumberValue")
						)
							and teamScores[stat.Name] then
							teamScores[stat.Name] =
								teamScores[stat.Name]
								+ stat.Value
						end
					end
				end
				local teamKey =
					"Team_" .. team.Name
				table.insert(
					activeKeys,
					teamKey
				)
				createOrUpdateRow(
					teamKey,
					team.Name,
					teamScores,
					team.TeamColor.Color,
					true,
					"",
					orderIndex
				)
				orderIndex =
					orderIndex + 1
				for _, p in ipairs(
					teamPlayers
				) do
					playersMapped[p] = true
					local pStats =
						getPlayerStatObjects(p)
					local playerStatMap = {}
					for _, stat in ipairs(
						pStats
					) do
						playerStatMap[
							stat.Name
						] = stat.Value
					end
					local playerKey =
						"Player_" .. p.Name
					table.insert(
						activeKeys,
						playerKey
					)
					createOrUpdateRow(
						playerKey,
						p.Name,
						playerStatMap,
						team.TeamColor.Color,
						false,
						"   ",
						orderIndex
					)
					orderIndex =
						orderIndex + 1
				end
			end
		end
	end
	local neutralHeaderCreated = false
	for _, p in ipairs(
		Players:GetPlayers()
	) do
		if not playersMapped[p] then
			if #currentTeams > 0
				and not neutralHeaderCreated then
				neutralHeaderCreated = true
				local neutralKey =
					"Team_Neutral"
				table.insert(
					activeKeys,
					neutralKey
				)
				createOrUpdateRow(
					neutralKey,
					"Neutral",
					{},
					Color3.fromRGB(
						230,
						230,
						230
					),
					true,
					"",
					orderIndex
				)
				orderIndex =
					orderIndex + 1
			end
			local rowColor =
				getClassicNameColor(
					p.Name
				)
			local padding =
				neutralHeaderCreated
				and "   "
				or ""
			local pStats =
				getPlayerStatObjects(p)
			local playerStatMap = {}
			for _, stat in ipairs(
				pStats
			) do
				playerStatMap[
					stat.Name
				] = stat.Value
			end
			local playerKey =
				"Player_" .. p.Name
			table.insert(
				activeKeys,
				playerKey
			)
			createOrUpdateRow(
				playerKey,
				p.Name,
				playerStatMap,
				rowColor,
				false,
				padding,
				orderIndex
			)
			orderIndex =
				orderIndex + 1
		end
	end
	for _, child in ipairs(
		ListScroll:GetChildren()
	) do
		if (
			child:IsA("Frame")
			or child:IsA("TextLabel")
		)
			and not table.find(
				activeKeys,
				child.Name
			) then
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
	if now - lastUpdate >= 1.5 then
		lastUpdate = now
		updatePlayerList()
	else
		updatePending = true
		task.delay(
			1.5 - (now - lastUpdate),
			function()
				updatePending = false
				lastUpdate =
					os.clock()
				updatePlayerList()
			end
		)
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
			storeConnection(
				val.Changed:Connect(
					function(newValue)
						local playerKey =
							"Player_" .. p.Name
						local rowFrame =
							ListScroll:
							FindFirstChild(
								playerKey
							)
						if rowFrame then
							local statContainer =
								rowFrame:
								FindFirstChild(
									"StatContainer"
								)
							local statLabel =
								statContainer
								and statContainer:
								FindFirstChild(
									val.Name
								)
							if statLabel then
								statLabel.Text =
									tostring(
										newValue
									)
							end
						end
					end
				)
			)
		end
		storeConnection(
			folder.ChildAdded:Connect(
				function(val)
					listenToStat(val)
					requestListUpdate()
				end
			)
		)
		for _, val in ipairs(
			folder:GetChildren()
		) do
			listenToStat(val)
		end
	end
	storeConnection(
		p.ChildAdded:Connect(
			hookLeaderstats
		)
	)
	local existingStats =
		p:FindFirstChild("leaderstats")
	if existingStats then
		hookLeaderstats(existingStats)
	end
	storeConnection(
		p:GetPropertyChangedSignal(
			"Team"
		):Connect(requestListUpdate)
	)
end
storeConnection(
	Players.PlayerAdded:Connect(
		function(p)
			connectPlayerStats(p)
			requestListUpdate()
		end
	)
)
storeConnection(
	Players.PlayerRemoving:Connect(
		requestListUpdate
	)
)
storeConnection(
	Teams.ChildAdded:Connect(
		requestListUpdate
	)
)
storeConnection(
	Teams.ChildRemoved:Connect(
		requestListUpdate
	)
)
for _, p in ipairs(
	Players:GetPlayers()
) do
	connectPlayerStats(p)
end
updatePlayerList()
--========================================================
-- HEALTH BAR
--========================================================
local HealthFrame =
	Instance.new("Frame")
HealthFrame.Name =
	"ClassicHealthFrame"
-- (Addtion-Scripts) The 2008 client's size (measured on a 2008 screenshot, as parts of the screen's height:
-- 1.25% wide and 12.5% tall, "Health" right under it), floating on the right, lined up with the camera buttons
-- and Report (over their middle), its top 52% down the screen (below the player list, above Report). Placed
-- below, once the label is made, and again when the screen, the GUI's scale or the player list changes.
HealthFrame.AnchorPoint =
	Vector2.new(0.5, 0)
HealthFrame.BackgroundColor3 =
	Color3.fromRGB(255, 0, 0)
HealthFrame.BorderSizePixel = 0
HealthFrame.Parent =
	ScreenGui
local HealthBar =
	Instance.new("Frame")
HealthBar.Name = "Bar"
HealthBar.Size =
	UDim2.new(1, 0, 1, 0)
HealthBar.Position =
	UDim2.new(0, 0, 0, 0)
HealthBar.BackgroundColor3 =
	Color3.new(
		0.5058824,
		0.7725491,
		0.08627451
	)
HealthBar.BorderSizePixel = 0
HealthBar.Parent =
	HealthFrame
-- "Health" centred under the bar, in the 2006 GUI's blue
local HealthLabel =
	Instance.new("TextLabel")
HealthLabel.AnchorPoint =
	Vector2.new(0.5, 0)
HealthLabel.Size =
	UDim2.new(0, 60, 0, 18)
HealthLabel.Position =
	UDim2.new(0.5, 0, 1, 3)
HealthLabel.BackgroundTransparency = 1
HealthLabel.Text = "Health"
HealthLabel.TextColor3 =
	Color3.fromRGB(0, 0, 255)
HealthLabel.Font =
	CARTOON_FONT
HealthLabel.TextSize = 16
HealthLabel.Parent =
	HealthFrame
-- (Addtion-Scripts) the 2008 client's size and place, worked out from the screen's height in the GUI's own
-- units (its scale makes them the right size on the screen)
-- (the camera buttons and Report are made further down: placed again once they are there)
local function placeHealthBar()
	local scale = (uiScale and uiScale.Scale > 0) and uiScale.Scale or 1
	local h = math.max(1, ScreenGui.AbsoluteSize.Y / scale)
	local width = math.max(3, math.floor(h * 0.0125 + 0.5))
	local height = math.max(30, math.floor(h * 0.125 + 0.5))
	-- across: over the middle of the camera buttons and Report (the right-hand column)
	local middleX = -36
	local palette = ScreenGui:FindFirstChild("RightPalette")
	if palette then
		local p, sz = palette.Position, palette.Size
		middleX = p.X.Offset - sz.X.Offset * palette.AnchorPoint.X + sz.X.Offset / 2
	end
	-- down: a little below the middle of the screen's height (its top 52% down: under the player list, above
	-- the camera buttons and Report), and never up into the player list
	local labelHeight = math.floor(h * 0.035 + 0.5)
	local labelGap = math.floor(h * 0.01 + 0.5)
	local listPos, listSize = PlayerList.Position, PlayerList.Size
	local top = math.max(listPos.Y.Offset + listSize.Y.Offset + h * 0.012, h * 0.52)
	-- (a very long player list on a short screen: "Health" still ends above Report's word)
	if palette then
		local p, sz = palette.Position, palette.Size
		local reportTop = h + p.Y.Offset - sz.Y.Offset * palette.AnchorPoint.Y - 22
		top = math.min(top, reportTop - 6 - labelHeight - labelGap - height)
	end
	HealthFrame.Size = UDim2.new(0, width, 0, height)
	HealthFrame.Position = UDim2.new(1, math.floor(middleX + 0.5), 0, math.floor(top + 0.5))
	HealthLabel.TextSize = math.max(10, math.floor(h * 0.03 + 0.5))
	HealthLabel.Size = UDim2.new(0, math.floor(h * 0.14 + 0.5), 0, labelHeight)
	HealthLabel.Position = UDim2.new(0.5, 0, 1, labelGap)
end
placeHealthBar()
storeConnection(PlayerList:GetPropertyChangedSignal("Size"):Connect(placeHealthBar))
storeConnection(PlayerList:GetPropertyChangedSignal("Position"):Connect(placeHealthBar))
storeConnection(ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeHealthBar))
if uiScale then storeConnection(uiScale:GetPropertyChangedSignal("Scale"):Connect(placeHealthBar)) end
local function setupHealthTracking(character)
	local humanoid =
		character:WaitForChild(
			"Humanoid",
			5
		)
	if humanoid then
		local function updateHealth()
			local healthPercent =
				math.clamp(
					humanoid.Health
					/ humanoid.MaxHealth,
					0,
					1
				)
			HealthBar.Size =
				UDim2.new(
					1,
					0,
					healthPercent,
					0
				)
			HealthBar.Position =
				UDim2.new(
					0,
					0,
					1 - healthPercent,
					0
				)
			if healthPercent < 0.25 then
				HealthBar.BackgroundColor3 =
					Color3.fromRGB(
						255,
						0,
						0
					)
			else
				HealthBar.BackgroundColor3 =
					Color3.new(
						0.5058824,
						0.7725491,
						0.08627451
					)
			end
		end
		storeConnection(
			humanoid.HealthChanged:Connect(
				updateHealth
			)
		)
		updateHealth()
	end
end
if LocalPlayer.Character then
	setupHealthTracking(
		LocalPlayer.Character
	)
end
storeConnection(
	LocalPlayer.CharacterAdded:Connect(
		setupHealthTracking
	)
)
--========================================================
-- CARTOON NAMES AND HEALTH BARS OVER HEADS
--========================================================
-- Roblox draws the names and health bars over characters and NPCs itself, in a font that
-- can't be changed. So Roblox's are hidden and drawn again here (same as the 2006 GUI does):
-- the name in white in the cartoon font with a black outline and the health bar (green over
-- red) under it, the same size at any distance.
-- They follow Roblox's rules: DisplayDistanceType, HealthDisplayType (by default the bar only
-- shows once hurt) and the name and health display distances.
-- Roblox's are hidden by holding the display distances that decide them at 0: this player's
-- character's (they decide what this player sees) and those of humanoids set to "Subject"
-- (those decide for themselves). The game's values are saved in attributes, so they still
-- count, even after running this script again. The attributes are the 2006 GUI's, so going
-- from one of these GUIs to the other keeps the game's values.
local NAME_TAG_TEXT_SIZE = 18
local NAME_TAG_BAR_WIDTH = 60
local NAME_TAG_BAR_HEIGHT = 7
local MAX_NAME_TAGS = 40
local DISPLAY_DISTANCES = { "NameDisplayDistance", "HealthDisplayDistance" }
local NAME_TAG_GREEN = Color3.new(0.5058824, 0.7725491, 0.08627451)

-- Same scale as the rest of the GUI (its UIScale)
local function getClassicUIScale()
	local viewport = Camera.ViewportSize
	if viewport.Y < 800 or viewport.X < 1200 then
		return math.clamp(viewport.Y / 900, 0.55, 1)
	end
	return 1
end

local function getCartoonTextWidth(text, textSize)
	local ok, size = pcall(function()
		return TextService:GetTextSize(text, textSize, CARTOON_FONT, Vector2.new(10000, 10000))
	end)
	if ok then
		return size.X
	end
	return #text * textSize * 0.55
end

local function disconnectAll(connections)
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
end

-- The display distance the game wants (saved in an attribute while it's held at 0)
local function getGameDistance(humanoid, property)
	local saved = humanoid:GetAttribute("Classic2006" .. property)
	if type(saved) == "number" then
		return saved
	end
	return humanoid[property]
end

-- Holds a humanoid's name and health display distances at 0, saving the game's values (and
-- any it sets later). Returns the connections doing the holding.
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

-- Puts back the display distances holdDisplayDistances saved
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

if USE_CARTOON_NAME_TAGS then
	-- Name tags left behind by an earlier run of this script (or the 2006 GUI)
	for _, container in ipairs({ CoreGui, LocalPlayer:FindFirstChildOfClass("PlayerGui") }) do
		pcall(function()
			for _, name in ipairs({ "Classic2008NameTags", "Classic2006NameTags" }) do
				local old = container:FindFirstChild(name)
				if old then
					old:Destroy()
				end
			end
		end)
	end
	local NameTagFolder = Instance.new("Folder")
	NameTagFolder.Name = "Classic2008NameTags"
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

	-- The BillboardGui is centred on a spot just above the head and the tag fills its top
	-- half, so the tag stands on that spot. Sized with the same scale as the rest of the GUI.
	local function layoutNameTag(tag)
		local scale = getClassicUIScale()
		local textSize = math.max(8, math.floor(NAME_TAG_TEXT_SIZE * scale + 0.5))
		local nameHeight = textSize + 4
		local barWidth = NAME_TAG_BAR_WIDTH * scale
		local barHeight = NAME_TAG_BAR_HEIGHT * scale
		local height = nameHeight + scale + barHeight
		local width = math.max(getCartoonTextWidth(tag.name, textSize), barWidth) + 8 * scale
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
		-- half a stud over the top of the head
		gui.ExtentsOffsetWorldSpace = Vector3.new(0, 1, 0)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 0.5, 0)
		-- The Bloxy Paradox loader switches off billboards over the NPCs it gives dialogs, unless
		-- they carry its own mark
		gui:SetAttribute("ClassicOwned", true)
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = tag.name
		nameLabel.Font = CARTOON_FONT
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		nameLabel.TextStrokeTransparency = 0
		-- already in the cartoon font: the font switcher further down can leave it alone
		nameLabel:SetAttribute("Classic2008Font", true)
		nameLabel.Parent = gui
		local barBack = Instance.new("Frame")
		barBack.Name = "HealthBar"
		barBack.AnchorPoint = Vector2.new(0.5, 0)
		barBack.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
		barBack.BorderSizePixel = 0
		barBack.Parent = gui
		local barFill = Instance.new("Frame")
		barFill.Name = "Fill"
		barFill.BackgroundColor3 = NAME_TAG_GREEN
		barFill.BorderSizePixel = 0
		barFill.Parent = barBack
		tag.gui = gui
		tag.nameLabel = nameLabel
		tag.barBack = barBack
		tag.barFill = barFill
		layoutNameTag(tag)
		gui.Parent = NameTagFolder
	end

	-- keep: only switch it off, for when it's wanted again soon
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

	-- Something else already shows this name over the character (a health bar ESP, or the game's
	-- own name tag), so it isn't shown twice. Checked every 2 seconds.
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

	-- What a tag should show by Roblox's rules, or nil when it shows nothing at all
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
		-- "Viewer": as far as this player's character is set to see; "Subject": as far as the humanoid is set to show
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
			-- infinite health
			fraction = 1
		end
		tag.gui.Adornee = view.head
		tag.nameLabel.Visible = view.showName
		tag.barBack.Visible = view.showHealth
		tag.barFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		tag.gui.Enabled = true
	end

	-- Brings a tag that's showing up to date right away (its health or settings changed);
	-- the loop at the bottom takes care of the rest
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

	-- A humanoid set to "Subject" decides with its own display distances, so those are held at 0 too
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

	-- giveBack puts the humanoid's own display distances back (not done for the next run of this script)
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
					-- moved into another model: start again with that one
					task.defer(pcall, trackHumanoid, humanoid)
				end
			end)
		}
		updateSubjectHold(tag)
	end

	-- This player's own character gets no tag, and its display distances (which decide what this
	-- player sees of the other characters) are held at 0
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

	-- Running this script again stops this run; the held distances stay saved for the new one
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
	-- Distances change as everything moves, so the tags are sorted out a few times a second.
	-- Only the nearest MAX_NAME_TAGS show, so a crowd of NPCs can't flood the screen (or slow the game).
	task.spawn(function()
		while nameTagsRunning do
			local views = {}
			for _, tag in pairs(nameTags) do
				local ok, view = pcall(getNameTagView, tag)
				if ok and view and (view.showName or view.showHealth) then
					view.tag = tag
					table.insert(views, view)
				else
					-- out of range: kept for when it comes back, unless it's well out of range
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
	-- An earlier run of this script (or the 2006 GUI) may have hidden Roblox's own names: give them back
	task.spawn(function()
		for index, obj in ipairs(Workspace:GetDescendants()) do
			if obj:IsA("Humanoid") then
				pcall(releaseDisplayDistances, obj)
			end
			if index % 500 == 0 then
				task.wait()
			end
		end
	end)
end
--========================================================
-- CHAT SYSTEM
--========================================================
local ChatContainer =
	ScreenGui:FindFirstChild(
		"ClassicChatLog"
	)
if not ChatContainer then
	ChatContainer =
		Instance.new("Frame")
	ChatContainer.Name =
		"ClassicChatLog"
	ChatContainer.Size =
		UDim2.new(
			0.4,
			0,
			0.25,
			0
		)
	ChatContainer.Position =
		UDim2.new(
			0,
			5,
			0,
			25
		)
	ChatContainer.BackgroundTransparency = 1
	ChatContainer.Parent =
		ScreenGui
	local ChatLayout =
		Instance.new("UIListLayout")
	ChatLayout.SortOrder =
		Enum.SortOrder.LayoutOrder
	ChatLayout.Padding =
		UDim.new(0, -3)
	ChatLayout.Parent =
		ChatContainer
end
--========================================================
-- CHAT INPUT BAR
--========================================================
local BottomChatBar =
	Instance.new("Frame")
BottomChatBar.Name =
	"ClassicBottomChatBar"
BottomChatBar.AnchorPoint =
	Vector2.new(0, 1)
BottomChatBar.Size =
	UDim2.new(
		1,
		0,
		0,
		20
	)
BottomChatBar.Position =
	UDim2.new(
		0,
		0,
		1,
		0
	)
BottomChatBar.BackgroundColor3 =
	Color3.fromRGB(
		50,
		50,
		50
	)
BottomChatBar.BorderSizePixel = 0
BottomChatBar.Active = true
BottomChatBar.Parent =
	ScreenGui
local ChatPromptLabel =
	Instance.new("TextLabel")
ChatPromptLabel.Name =
	"ChatPromptLabel"
ChatPromptLabel.Size =
	UDim2.new(
		1,
		-10,
		1,
		0
	)
ChatPromptLabel.Position =
	UDim2.new(
		0,
		5,
		0,
		0
	)
ChatPromptLabel.BackgroundTransparency = 1
ChatPromptLabel.Font =
	Enum.Font.Arial -- the chat bar keeps its plain font, like 2008
ChatPromptLabel.TextSize = 13
ChatPromptLabel.TextColor3 =
	Color3.fromRGB(
		254,
		252,
		196
	)
ChatPromptLabel.TextXAlignment =
	Enum.TextXAlignment.Left
ChatPromptLabel.TextYAlignment =
	Enum.TextYAlignment.Center
ChatPromptLabel.Text =
	'To chat click here or press the "/" key'
ChatPromptLabel.ZIndex = 1
ChatPromptLabel.Parent =
	BottomChatBar
local HiddenTextBox =
	Instance.new("TextBox")
HiddenTextBox.Name =
	"HiddenTextBox"
HiddenTextBox.Size =
	UDim2.new(
		1,
		-10,
		1,
		0
	)
HiddenTextBox.Position =
	UDim2.new(
		0,
		5,
		0,
		0
	)
HiddenTextBox.BackgroundTransparency = 1
HiddenTextBox.Text = ""
HiddenTextBox.TextColor3 =
	Color3.fromRGB(
		254,
		252,
		196
	)
HiddenTextBox.TextTransparency = 0
HiddenTextBox.Font =
	Enum.Font.Arial
HiddenTextBox.TextSize = 13
HiddenTextBox.TextXAlignment =
	Enum.TextXAlignment.Left
HiddenTextBox.TextYAlignment =
	Enum.TextYAlignment.Center
HiddenTextBox.ClearTextOnFocus = false
HiddenTextBox.MultiLine = false
HiddenTextBox.Active = true
HiddenTextBox.Selectable = true
HiddenTextBox.ZIndex = 2
HiddenTextBox.Parent =
	BottomChatBar

--========================================================
-- CHAT COLORS
--========================================================
local CLASSIC_COLORS = {
	Color3.fromRGB(227, 42, 53),
	Color3.fromRGB(33, 147, 226),
	Color3.fromRGB(24, 171, 71),
	Color3.fromRGB(147, 95, 207),
	Color3.fromRGB(216, 121, 46),
	Color3.fromRGB(247, 203, 34),
	Color3.fromRGB(235, 172, 193),
	Color3.fromRGB(199, 178, 142)
}
local function getChatColor(name)
	name = tostring(name or "")
	local count = 0
	for i = 1, #name do
		count =
			count + string.byte(name, i)
	end
	return CLASSIC_COLORS[
		(count % #CLASSIC_COLORS) + 1
	]
end

--========================================================
-- ADD CHAT MESSAGE
--========================================================
local function addClassicMessage(senderName, messageText)
	senderName = tostring(senderName or "")
	messageText = tostring(messageText or "")
	if senderName == "" or messageText == "" then
		return
	end
	local currentMessages = ChatContainer:GetChildren()
	local messageFrames = {}
	for _, child in ipairs(currentMessages) do
		if child:IsA("Frame") then
			table.insert(messageFrames, child)
		end
	end
	if #messageFrames >= 10 then
		messageFrames[1]:Destroy()
	end
	local nameColor = getChatColor(senderName)
	local colorHex = string.format(
		"#%02X%02X%02X",
		math.floor(nameColor.R * 255),
		math.floor(nameColor.G * 255),
		math.floor(nameColor.B * 255)
	)
	local MsgFrame = Instance.new("Frame")
	MsgFrame.Name = "ChatMessage"
	MsgFrame.BackgroundColor3 = Color3.fromRGB(154, 154, 154)
	MsgFrame.BackgroundTransparency = 0.45
	MsgFrame.BorderSizePixel = 0
	MsgFrame.AutomaticSize = Enum.AutomaticSize.X
	MsgFrame.Size = UDim2.new(0, 0, 0, 22)
	MsgFrame.Parent = ChatContainer
	
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = MsgFrame
	
	local TextLabel = Instance.new("TextLabel")
	TextLabel.Name = "MessageText"
	TextLabel.BackgroundTransparency = 1
	TextLabel.Font = CARTOON_FONT
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

--========================================================
-- SEND CHAT MESSAGE
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
		warn("[2010 Chat] Cannot send message because RBXGeneral is unavailable.")
		return
	end
	local success, result = pcall(function()
		return GeneralChannel:SendAsync(text)
	end)
	if not success then
		warn("[2010 Chat] SendAsync failed:", result)
	end
end

--========================================================
-- CHAT INPUT & EVENTS
--========================================================
storeConnection(
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
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
	end)
)

storeConnection(
	BottomChatBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			task.defer(function()
				if HiddenTextBox and HiddenTextBox.Parent then
					HiddenTextBox:CaptureFocus()
				end
			end)
		end
	end)
)

storeConnection(
	HiddenTextBox.Focused:Connect(function()
		ChatPromptLabel.Text = ""
	end)
)

storeConnection(
	HiddenTextBox.FocusLost:Connect(function(enterPressed)
		local text = HiddenTextBox.Text
		HiddenTextBox.Text = ""
		ChatPromptLabel.Text = 'To chat click here or press the "/" key'
		if not enterPressed then
			return
		end
		sendChatMessage(text)
	end)
)

--========================================================
-- TEXTCHAT SERVICE MESSAGE RECEIVER
--========================================================
local seenMessageIds = {}
storeConnection(
	TextChatService.MessageReceived:Connect(function(textChatMessage)
		if not textChatMessage then
			return
		end

		local textSource = textChatMessage.TextSource
		if not textSource then
			return
		end

		local messageText = tostring(textChatMessage.Text or "")
		messageText = messageText:gsub("^%s+", ""):gsub("%s+$", "")
		if messageText == "" then
			return
		end

		local messageId = tostring(textChatMessage.MessageId or "")
		if messageId ~= "" then
			if seenMessageIds[messageId] then
				return
			end
			seenMessageIds[messageId] = true
			task.delay(30, function()
				seenMessageIds[messageId] = nil
			end)
		end

		local senderPlayer = nil
		pcall(function()
			senderPlayer = Players:GetPlayerByUserId(textSource.UserId)
		end)
		if not senderPlayer then
			return
		end

		-- 2008: chat only shows in the corner, no bubbles over heads
		addClassicMessage(senderPlayer.Name, messageText)
	end)
)

--========================================================
-- TEXT CHANNEL RECOVERY
--========================================================
storeConnection(
	TextChatService.ChildAdded:Connect(function(child)
		if child.Name ~= "TextChannels" then
			return
		end
		task.defer(function()
			GeneralChannel = findGeneralChannel()
		end)
	end)
)

task.spawn(function()
	while ScreenGui and ScreenGui.Parent do
		if not GeneralChannel or not GeneralChannel.Parent then
			pcall(function()
				GeneralChannel = findGeneralChannel()
			end)
		end
		task.wait(2)
	end
end)

--========================================================
-- TOPBAR EXIT
--========================================================
local TopBarRef = ScreenGui:WaitForChild("TopBar", 5)
if TopBarRef then
	local ExitBtn = TopBarRef:WaitForChild("ExitBtn", 5)
	if ExitBtn and ExitBtn:IsA("TextButton") then
		storeConnection(
			ExitBtn.MouseButton1Click:Connect(function()
				pcall(function()
					game:Shutdown()
				end)
			end)
		)
	end
end

--========================================================
-- RIGHT PALETTE CONTROLS
--========================================================
-- 2008 layout: the camera buttons down in the bottom-right corner, just above the chat bar
-- (20 tall), with Report Abuse right above them. No screenshot / video buttons.
local RightPalette = Instance.new("Frame")
RightPalette.Name = "RightPalette"
RightPalette.AnchorPoint = Vector2.new(1, 1)
RightPalette.Position = UDim2.new(1, -12, 1, -24)
RightPalette.Size = UDim2.new(0, 48, 0, 48)
RightPalette.BackgroundTransparency = 1
RightPalette.Parent = ScreenGui

local CameraPanel = Instance.new("Frame")
CameraPanel.Name = "CameraPanel"
CameraPanel.Position = UDim2.new(0, 0, 0, 0)
CameraPanel.Size = UDim2.new(0, 48, 0, 48)
CameraPanel.BackgroundTransparency = 1
CameraPanel.Parent = RightPalette

local CameraLeft = Instance.new("Frame")
CameraLeft.Name = "CameraLeft"
CameraLeft.Size = UDim2.new(0, 24, 0, 48)
CameraLeft.BackgroundTransparency = 1
CameraLeft.Parent = CameraPanel

local TiltUp = Instance.new("ImageButton")
TiltUp.Name = "Tilt Up"
TiltUp.Size = UDim2.new(1, 0, 0.5, 0)
TiltUp.BackgroundTransparency = 1
TiltUp.Image = "rbxassetid://598662248"
TiltUp.Parent = CameraLeft

local TiltDown = Instance.new("ImageButton")
TiltDown.Name = "Tilt Down"
TiltDown.Position = UDim2.new(0, 0, 0.5, 0)
TiltDown.Size = UDim2.new(1, 0, 0.5, 0)
TiltDown.BackgroundTransparency = 1
TiltDown.Image = "rbxassetid://598662248"
TiltDown.Rotation = 180
TiltDown.Parent = CameraLeft

local CameraRight = Instance.new("Frame")
CameraRight.Name = "CameraRight"
CameraRight.Position = UDim2.new(0, 24, 0, 0)
CameraRight.Size = UDim2.new(0, 24, 0, 48)
CameraRight.BackgroundTransparency = 1
CameraRight.Parent = CameraPanel

local ZoomIn = Instance.new("ImageButton")
ZoomIn.Name = "Zoom In"
ZoomIn.Size = UDim2.new(1, 0, 0.5, 0)
ZoomIn.BackgroundTransparency = 1
ZoomIn.Image = "rbxassetid://1074548141"
ZoomIn.Parent = CameraRight

local ZoomOut = Instance.new("ImageButton")
ZoomOut.Name = "Zoom Out"
ZoomOut.Position = UDim2.new(0, 0, 0.5, 0)
ZoomOut.Size = UDim2.new(1, 0, 0.5, 0)
ZoomOut.BackgroundTransparency = 1
ZoomOut.Image = "rbxassetid://598665130"
ZoomOut.Parent = CameraRight

local ReportAbuse = Instance.new("ImageButton")
ReportAbuse.Name = "ReportAbuse"
-- right above the camera buttons (it used to be over the screenshot button)
ReportAbuse.Position = UDim2.new(0, 0, 0, -48)
ReportAbuse.Size = UDim2.new(0, 48, 0, 48)
ReportAbuse.BackgroundTransparency = 1
ReportAbuse.Image = "rbxassetid://4539289774"
ReportAbuse.Parent = RightPalette
-- (Addtion-Scripts) the health bar floats just above these
pcall(placeHealthBar)

local STEP_ZOOM = 5
local STEP_TILT = math.rad(5)

storeConnection(
	ZoomIn.MouseButton1Click:Connect(function()
		if Camera and Camera.CameraMode ~= Enum.CameraMode.LockFirstPerson then
			local currentSubject = Camera.CameraSubject
			if currentSubject then
				LocalPlayer.CameraMinZoomDistance = math.max(0.5, LocalPlayer.CameraMinZoomDistance - STEP_ZOOM)
				LocalPlayer.CameraMaxZoomDistance = math.max(0.5, LocalPlayer.CameraMaxZoomDistance - STEP_ZOOM)
			end
		end
	end)
)

storeConnection(
	ZoomOut.MouseButton1Click:Connect(function()
		if Camera then
			LocalPlayer.CameraMaxZoomDistance = math.min(400, LocalPlayer.CameraMaxZoomDistance + STEP_ZOOM)
			LocalPlayer.CameraMinZoomDistance = math.min(400, LocalPlayer.CameraMinZoomDistance + STEP_ZOOM)
		end
	end)
)

storeConnection(
	TiltUp.MouseButton1Click:Connect(function()
		if Camera and Camera.CameraType == Enum.CameraType.Scriptable then
			Camera.CFrame = Camera.CFrame * CFrame.Angles(STEP_TILT, 0, 0)
		elseif Camera then
			Camera.CFrame = Camera.CFrame * CFrame.new(0, 2, 0)
		end
	end)
)

storeConnection(
	TiltDown.MouseButton1Click:Connect(function()
		if Camera and Camera.CameraType == Enum.CameraType.Scriptable then
			Camera.CFrame = Camera.CFrame * CFrame.Angles(-STEP_TILT, 0, 0)
		elseif Camera then
			Camera.CFrame = Camera.CFrame * CFrame.new(0, -2, 0)
		end
	end)
)

storeConnection(
	ReportAbuse.MouseButton1Click:Connect(function()
		local GuiService = game:GetService("GuiService")
		pcall(function()
			GuiService:OpenBrowserWindow("https://www.roblox.com/report-abuse")
		end)
	end)
)

--========================================================
-- BACKPACK
--========================================================
local BackpackGui = Instance.new("Frame")
BackpackGui.Name = "ClassicBackpack"
BackpackGui.AnchorPoint = Vector2.new(0, 1)
BackpackGui.Position = UDim2.new(0, 3, 1, -22)
BackpackGui.BackgroundTransparency = 1
BackpackGui.Parent = ScreenGui

local BackpackLayout = Instance.new("UIListLayout")
BackpackLayout.FillDirection = Enum.FillDirection.Horizontal
BackpackLayout.SortOrder = Enum.SortOrder.LayoutOrder
BackpackLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
BackpackLayout.VerticalAlignment = Enum.VerticalAlignment.Center
BackpackLayout.Padding = UDim.new(0, 0)
BackpackLayout.Parent = BackpackGui

local itemSlots = {}
local toolMappings = {}
local clickDebounce = false
local SLOT_SIZE = 64

for i = 1, 10 do
	local slot = Instance.new("Frame")
	slot.Name = "Slot" .. i
	slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	slot.BackgroundColor3 = Color3.fromRGB(140, 140, 140)
	slot.BackgroundTransparency = 0.4
	slot.BorderSizePixel = 0
	slot.LayoutOrder = i
	slot.ZIndex = 1
	slot.Visible = false

	local selectionFrame = Instance.new("Frame")
	selectionFrame.Name = "SelectionFrame"
	selectionFrame.Size = UDim2.new(1, 0, 1, 0)
	selectionFrame.BackgroundTransparency = 1
	selectionFrame.ZIndex = 10
	selectionFrame.Parent = slot

	local stroke = Instance.new("UIStroke")
	stroke.Name = "SelectionStroke"
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(0, 255, 0)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Enabled = false
	stroke.Parent = selectionFrame

	local numberLabel = Instance.new("TextLabel")
	numberLabel.Size = UDim2.new(0, 15, 0, 15)
	numberLabel.Position = UDim2.new(0, 0, 1, -15)
	numberLabel.BackgroundTransparency = 0.25
	numberLabel.Text = tostring(i == 10 and 0 or i)
	numberLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	numberLabel.Font = CARTOON_FONT
	numberLabel.BorderSizePixel = 0
	numberLabel.TextSize = 12
	numberLabel.ZIndex = 3
	numberLabel.Parent = slot

	local toolBtn = Instance.new("ImageButton")
	toolBtn.Name = "ToolButton"
	toolBtn.Size = UDim2.new(1, -4, 1, -4)
	toolBtn.Position = UDim2.new(0, 2, 0, 2)
	toolBtn.BackgroundTransparency = 1
	toolBtn.ZIndex = 2
	toolBtn.Parent = slot

	local textFallback = Instance.new("TextLabel")
	textFallback.Name = "TextFallback"
	textFallback.Size = UDim2.new(1, 0, 1, 0)
	textFallback.BackgroundTransparency = 1
	textFallback.TextColor3 = Color3.fromRGB(255, 255, 255)
	textFallback.Font = CARTOON_FONT
	textFallback.TextSize = 10
	textFallback.TextWrapped = true
	textFallback.ZIndex = 2
	textFallback.Parent = toolBtn

	storeConnection(
		toolBtn.Activated:Connect(function()
			if clickDebounce then
				return
			end
			local tool = toolMappings[i]
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
			task.wait(0.1)
			clickDebounce = false
		end)
	)
	slot.Parent = BackpackGui
	itemSlots[i] = slot
end

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
		for slotIdx, registeredTool in pairs(toolMappings) do
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
	BackpackGui.Size = UDim2.new(
		0,
		math.max(1, totalVisibleSlots) * SLOT_SIZE,
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
			if characterModel and tool.Parent == characterModel then
				if stroke then
					stroke.Enabled = true
				end
			else
				if stroke then
					stroke.Enabled = false
				end
			end
			slot.Visible = true
		else
			slot.Visible = false
		end
	end
end

local function setupBackpackConnections(character)
	local backpack = LocalPlayer:WaitForChild("Backpack")
	storeConnection(backpack.ChildAdded:Connect(updateBackpack))
	storeConnection(backpack.ChildRemoved:Connect(updateBackpack))
	if character then
		storeConnection(character.ChildAdded:Connect(updateBackpack))
		storeConnection(character.ChildRemoved:Connect(updateBackpack))
	end
	updateBackpack()
end

storeConnection(LocalPlayer.CharacterAdded:Connect(setupBackpackConnections))
if LocalPlayer.Character then
	setupBackpackConnections(LocalPlayer.Character)
end

--========================================================
-- CARTOON FONT FOR THE GAME'S TEXT AND OTHER SCRIPTS' TEXT
--========================================================
-- Like the 2006 GUI does with its font: the game's own on-screen text, other scripts' text
-- (the Bloxy Paradox loader's dialogs and anything drawn over characters and NPCs) and,
-- if switched on above, the world's signs and Roblox's menus all get the cartoon font, and
-- keep it if the game sets another font later.
local cartoonRunning = true
local cartoonLabels = setmetatable({}, { __mode = "k" })
-- Running this script again stops this run from holding fonts
storeConnection({
	Disconnect = function()
		cartoonRunning = false
	end
})

local function applyCartoonFont(label)
	if cartoonLabels[label] then
		return
	end
	cartoonLabels[label] = true
	label:SetAttribute("Classic2008Font", true)
	local function hold()
		if cartoonRunning and label.Font ~= CARTOON_FONT then
			label.Font = CARTOON_FONT
		end
	end
	hold()
	-- the connection goes away with the label
	label:GetPropertyChangedSignal("FontFace"):Connect(hold)
end

-- GUIs made by the Bloxy Paradox loader: its NPC dialog box, notices and dialog bubbles.
-- Add a GUI's name here to give another script's GUI the cartoon font too.
local OTHER_SCRIPT_GUIS = {
	ClassicDialogExecutorGui = true,
	ClassicDialogNoticeGui = true,
	ClassicDialogBillboardHost = true
}

-- Other scripts' text that's safe to restyle: anything drawn over a head or part
-- (health bar ESPs, name tags, dialog bubbles) and the GUIs listed above
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

-- A BillboardGui over a character or NPC: inside its model, or shown on one of its parts
local function isOverCharacter(billboard)
	for _, start in ipairs({ billboard, billboard.Adornee }) do
		local model = start.ClassName == "Model" and start or start:FindFirstAncestorOfClass("Model")
		while model do
			if model:FindFirstChildOfClass("Humanoid") then
				return true
			end
			model = model:FindFirstAncestorOfClass("Model")
		end
	end
	return false
end

-- Text in the world that's drawn over a character or NPC (names and health bars over heads)
local function isOverheadText(obj)
	local billboard = obj:FindFirstAncestorWhichIsA("BillboardGui")
	return billboard ~= nil and isOverCharacter(billboard)
end

-- filter: when given, only text it says yes to is restyled
local function convertGameText(obj, filter)
	if cartoonLabels[obj] or obj:GetAttribute("Classic2008Font") or obj:IsDescendantOf(ScreenGui) then
		return
	end
	if filter and not filter(obj) then
		return
	end
	-- Leave other executor GUIs alone (they share the hidden gethui() folder with this one)
	if parentTarget ~= CoreGui and obj:IsDescendantOf(parentTarget) and not isOtherScriptText(obj) then
		return
	end
	-- Leave the game's chat alone
	if obj:FindFirstAncestor("Chat") then
		return
	end
	-- Leave typing boxes' hint text alone too (like a game's own "To chat click here..." bar)
	local parent = obj.Parent
	if parent and parent:FindFirstChildWhichIsA("TextBox") then
		return
	end
	-- Leave monospace text alone: code editors and consoles line up by character
	local family = string.lower(obj.FontFace.Family)
	if string.find(family, "mono", 1, true) or string.find(family, "inconsolata", 1, true) then
		return
	end
	applyCartoonFont(obj)
end

local function isGameText(obj)
	return obj:IsA("TextLabel") or obj:IsA("TextButton")
end

local function watchGameText(root, filter)
	storeConnection(
		root.DescendantAdded:Connect(function(obj)
			if isGameText(obj) then
				-- wait a moment so the game finishes setting the text up first
				task.defer(pcall, convertGameText, obj, filter)
			end
		end)
	)
	for index, obj in ipairs(root:GetDescendants()) do
		if isGameText(obj) then
			pcall(convertGameText, obj, filter)
		end
		-- a big GUI is taken over a bit at a time instead of freezing the game
		if index % 200 == 0 then
			task.wait()
		end
	end
end

if APPLY_CARTOON_FONT_TO_GAME_GUIS then
	task.spawn(watchGameText, LocalPlayer:WaitForChild("PlayerGui"))
end
if APPLY_CARTOON_FONT_TO_WORLD_TEXT then
	task.spawn(watchGameText, Workspace)
end
if APPLY_CARTOON_FONT_TO_ROBLOX_MENUS then
	task.spawn(watchGameText, CoreGui)
end
if APPLY_CARTOON_FONT_TO_OTHER_SCRIPTS then
	if not APPLY_CARTOON_FONT_TO_ROBLOX_MENUS then
		task.spawn(watchGameText, CoreGui, isOtherScriptText)
	end
	if parentTarget ~= CoreGui and not parentTarget:IsDescendantOf(CoreGui) then
		task.spawn(watchGameText, parentTarget, isOtherScriptText)
	end
	if not APPLY_CARTOON_FONT_TO_GAME_GUIS then
		task.spawn(watchGameText, LocalPlayer:WaitForChild("PlayerGui"), isOtherScriptText)
	end
	-- overhead GUIs put on the characters and NPCs themselves (like a health bar ESP)
	if not APPLY_CARTOON_FONT_TO_WORLD_TEXT then
		task.spawn(watchGameText, Workspace, isOverheadText)
	end
end

--========================================================
-- FINAL TEXT CHAT SAFETY
--========================================================
task.spawn(function()
	while ScreenGui and ScreenGui.Parent do
		disableDefaultBubbles()
		task.wait(0.25)
	end
end)

