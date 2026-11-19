-- (Addtion-Scripts) An unchanged copy of Bloxy's 2014 GUI (pastebin.com/raw/h5AEhK7N), kept for when pastebin doesn't
-- answer (it often blocks executors). The loader (getgenv().BP_Legacy.Get2014) asks pastebin first and uses this copy
-- only when that fails; the fixes for its built-in Legacy are put in as it loads (More guis.lua), so the GUI is the same.
--[[

    CONTEXT: This script was taken from 2016 corescripts off of ROBLOX's github

]]

spawn(function()
	local LoadingGui = game:WaitForChild("CoreGui"):WaitForChild("RobloxLoadingGui")
	LoadingGui.Enabled = false
	LoadingGui:Destroy()
end)

-- Creates the generic "ROBLOX" loading screen on startup
-- Written by ArceusInator & Ben Tkacheff, 2014

-- Constants
local PLACEID = game.PlaceId

local MPS = game:GetService('MarketplaceService')
local UIS = game:GetService('UserInputService')
local guiService = game:GetService("GuiService")
local ContextActionService = game:GetService('ContextActionService')
local RobloxGui = game:GetService("CoreGui"):WaitForChild("RobloxGui")

local startTime = tick()

local COLORS = {
	BLACK = Color3.new(0, 0, 0),
	BACKGROUND_COLOR = Color3.new(45/255, 45/255, 45/255),
	WHITE = Color3.new(1, 1, 1),
	ERROR = Color3.new(253/255,68/255,72/255)
}

local function getViewportSize()
	while not game.Workspace.CurrentCamera do
		game.Workspace.Changed:wait()
	end

	while game.Workspace.CurrentCamera.ViewportSize == Vector2.new(0,0) do
		game.Workspace.CurrentCamera.Changed:wait()
	end

	return game.Workspace.CurrentCamera.ViewportSize
end

--
-- Variables
local GameAssetInfo -- loaded by InfoProvider:LoadAssets()
local currScreenGui, renderSteppedConnection = nil, nil
local destroyingBackground, destroyedLoadingGui, hasReplicatedFirstElements = false, false, false
local backgroundImageTransparency = 0
local isMobile = (UIS.TouchEnabled == true and UIS.MouseEnabled == false and getViewportSize().Y <= 500)
local isTenFootInterface = guiService:IsTenFootInterface()
local platform = UIS:GetPlatform()

local function IsConvertMyPlaceNameInXboxAppEnabled()
	if UIS:GetPlatform() == Enum.Platform.XBoxOne then
		local success, flagValue = pcall(function() return settings():GetFFlag("ConvertMyPlaceNameInXboxApp") end)
		return (success and flagValue == true)
	end
	return false
end

--
-- Utility functions
local create = function(className, defaultParent)
	return function(propertyList)
		local object = Instance.new(className)
		local parent = nil

		for index, value in next, propertyList do
			if type(index) == 'string' then
				if index == 'Parent' then
					parent = value
				else
					object[index] = value
				end
			else
				if type(value) == 'function' then
					value(object)
				elseif type(value) == 'userdata' then
					value.Parent = object
				end
			end
		end
		
		if parent then
			object.Parent = parent
		end

		if object.Parent == nil then
			object.Parent = defaultParent
		end

		return object
	end
end

--
-- Create objects

local MainGui = {}
local InfoProvider = {}


function ExtractGeneratedUsername(gameName)
	local tempUsername = string.match(gameName, "^([0-9a-fA-F]+)'s Place$")
	if tempUsername and #tempUsername == 32 then
		return tempUsername
	end
end

-- Fix places that have been made with incorrect temporary usernames
function GetFilteredGameName(gameName, creatorName)
	if gameName and type(gameName) == 'string' then
		local tempUsername = ExtractGeneratedUsername(gameName)
		if tempUsername then
			local newGameName = string.gsub(gameName, tempUsername, creatorName, 1)
			if newGameName then
				return newGameName
			end
		end
	end
	return gameName
end


function InfoProvider:GetGameName()
	if GameAssetInfo ~= nil then
		if IsConvertMyPlaceNameInXboxAppEnabled() then
			return GetFilteredGameName(GameAssetInfo.Name, self:GetCreatorName())
		else
			return GameAssetInfo.Name
		end
	else
		return ''
	end
end

function InfoProvider:GetCreatorName()
	if GameAssetInfo ~= nil then
		return GameAssetInfo.Creator.Name
	else
		return ''
	end
end

function InfoProvider:LoadAssets()
	spawn(function()
		if PLACEID <= 0 then
			while game.PlaceId <= 0 do
				wait()
			end
			PLACEID = game.PlaceId
		end

		-- load game asset info
		coroutine.resume(coroutine.create(function()
			local success, result = pcall(function()
				GameAssetInfo = MPS:GetProductInfo(PLACEID)
			end)
			if not success then
				print("LoadingScript->InfoProvider:LoadAssets:", result)
			end
		end))
	end)
end

function MainGui:tileBackgroundTexture(frameToFill)
	if not frameToFill then return end
	frameToFill:ClearAllChildren()
	if backgroundImageTransparency < 1 then
		local backgroundTextureSize = Vector2.new(512, 512)
		for i = 0, math.ceil(frameToFill.AbsoluteSize.X/backgroundTextureSize.X) do
			for j = 0, math.ceil(frameToFill.AbsoluteSize.Y/backgroundTextureSize.Y) do
				create 'ImageLabel' {
					Name = 'BackgroundTextureImage',
					BackgroundTransparency = 1,
					ImageTransparency = backgroundImageTransparency,
					Image = 'rbxasset://textures/loading/darkLoadingTexture.png',
					Position = UDim2.new(0, i*backgroundTextureSize.X, 0, j*backgroundTextureSize.Y),
					Size = UDim2.new(0, backgroundTextureSize.X, 0, backgroundTextureSize.Y),
					ZIndex = 1,
					Parent = frameToFill
				}
			end
		end
	end
end

-- create a cancel binding for console to be able to cancel anytime while loading
local function createTenfootCancelGui()
	local cancelLabel = create'ImageLabel'
	{
		Name = "CancelLabel";
		Size = UDim2.new(0, 83, 0, 83);
		Position = UDim2.new(1, -32 - 83, 0, 32);
		BackgroundTransparency = 1;
		Image = 'rbxasset://textures/ui/Shell/ButtonIcons/BButton.png';
	}
	local cancelText = create'TextLabel'
	{
		Name = "CancelText";
		Size = UDim2.new(0, 0, 0, 0);
		Position = UDim2.new(1, -131, 0, 64);
		BackgroundTransparency = 1;
		FontSize = Enum.FontSize.Size36;
		TextXAlignment = Enum.TextXAlignment.Right;
		TextColor3 = COLORS.WHITE;
		Text = "Cancel";
	}

	-- bind cancel action
	local platformService = nil
	pcall(function()
		platformService = game:GetService('PlatformService')
	end)

	if platformService then
		if not game:GetService("ReplicatedFirst"):IsFinishedReplicating() then
			local seenBButtonBegin = false
			ContextActionService:BindCoreAction("CancelGameLoad",
				function(actionName, inputState, inputObject)
					if inputState == Enum.UserInputState.Begin then
						seenBButtonBegin = true
					elseif inputState == Enum.UserInputState.End and seenBButtonBegin then
						cancelLabel:Destroy()
						cancelText.Text = "Canceling..."
						cancelText.Position = UDim2.new(1, -32, 0, 64)
						ContextActionService:UnbindCoreAction('CancelGameLoad')
						platformService:RequestGameShutdown()
					end
				end,
				false,
				Enum.KeyCode.ButtonB)
		end
	end

	while cancelLabel.Parent == nil do
		if currScreenGui then
			local blackFrame = currScreenGui:FindFirstChild('BlackFrame')
			if blackFrame then
				cancelLabel.Parent = blackFrame
				cancelText.Parent = blackFrame
				break
			end
		end
		wait()
	end
end

--
-- Declare member functions
function MainGui:GenerateMain()
	local screenGui = create 'ScreenGui' {
		Name = 'Custom2016LoadingGui' -- Renamed to prevent automatic self-deletion loop
	}

	--
	-- create descendant frames
	local mainBackgroundContainer = create 'Frame' {
		Name = 'BlackFrame',
		BackgroundColor3 = COLORS.BACKGROUND_COLOR,
		BackgroundTransparency = 0,
		Size = UDim2.new(1, 0, 1, 36),
		Position = UDim2.new(0, 0, 0, -36),
		Active = true,
		Parent = screenGui,
	}

		local closeButton =	create 'ImageButton' {
			Name = 'CloseButton',
			Image = 'rbxasset://textures/loading/cancelButton.png',
			ImageTransparency = 1,
			BackgroundTransparency = 1,
			Position = UDim2.new(1, -37, 0, 5),
			Size = UDim2.new(0, 32, 0, 32),
			Active = false,
			ZIndex = 10,
			Parent = mainBackgroundContainer,
		}

		local graphicsFrame = create 'Frame' {
			Name = 'GraphicsFrame',
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			Position = UDim2.new(1, (isMobile == true and -75 or (isTenFootInterface and -245 or -225)), 1, (isMobile == true and -75 or (isTenFootInterface and -185 or -165))),
			Size = UDim2.new(0, (isMobile == true and 70 or (isTenFootInterface and 140 or 120)), 0, (isMobile == true and 70 or (isTenFootInterface and 140 or 120))),
			ZIndex = 2,
			Parent = mainBackgroundContainer,
		}

			local loadingImage = create 'ImageLabel' {
				Name = 'LoadingImage',
				BackgroundTransparency = 1,
				Image = 'rbxasset://textures/loading/loadingCircle.png',
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(1, 0, 1, 0),
				ZIndex = 2,
				Parent = graphicsFrame,
			}

			local loadingText = create 'TextLabel' {
				Name = 'LoadingText',
				BackgroundTransparency = 1,
				Size = UDim2.new(1, (isMobile == true and -14 or -56), 1, 0),
				Position = UDim2.new(0, (isMobile == true and 12 or 28), 0, 0),
				Font = Enum.Font.SourceSans,
				FontSize = (isMobile == true and Enum.FontSize.Size12 or Enum.FontSize.Size18),
				TextWrapped = true,
				TextColor3 = COLORS.WHITE,
				TextXAlignment = Enum.TextXAlignment.Left,
				Visible = not isTenFootInterface,
				Text = "Loading...",
				ZIndex = 2,
				Parent = graphicsFrame,
			}

		local uiMessageFrame = create 'Frame' {
			Name = 'UiMessageFrame',
			BackgroundTransparency = 1,
			Position = UDim2.new(0.25, 0, 1, -120),
			Size = UDim2.new(0.5, 0, 0, 80),
			ZIndex = 2,
			Parent = mainBackgroundContainer,
		}

			local uiMessage = create 'TextLabel' {
				Name = 'UiMessage',
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				Font = Enum.Font.SourceSansBold,
				FontSize = Enum.FontSize.Size18,
				TextWrapped = true,
				TextColor3 = COLORS.WHITE,
				Text = "",
				ZIndex = 2,
				Parent = uiMessageFrame,
			}

		local infoFrame = create 'Frame' {
			Name = 'InfoFrame',
			BackgroundTransparency = 1,
			Position = UDim2.new(0, (isMobile == true and 20 or 100), 1, (isMobile == true and -120 or -150)),
			Size = UDim2.new(0.4, 0, 0, 110),
			ZIndex = 2,
			Parent = mainBackgroundContainer,
		}

			local placeLabel = create 'TextLabel' {
				Name = 'PlaceLabel',
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 80),
				Position = UDim2.new(0, 0, 0, 0),
				Font = Enum.Font.SourceSans,
				FontSize = (isTenFootInterface and Enum.FontSize.Size48 or Enum.FontSize.Size24),
				TextWrapped = true,
				TextScaled = true,
				TextColor3 = COLORS.WHITE,
				TextStrokeTransparency = 0,
				Text = "",
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Bottom,
				ZIndex = 2,
				Parent = infoFrame,
			}

			if isTenFootInterface then
				local byLabel = create'TextLabel' {
					Name = "ByLabel",
					BackgroundTransparency = 1,
					Size = UDim2.new(0, 36, 0, 30),
					Position = UDim2.new(0, 0, 0, 80),
					Font = Enum.Font.SourceSans,
					FontSize = Enum.FontSize.Size36,
					TextScaled = true,
					TextColor3 = COLORS.WHITE,
					TextStrokeTransparency = 0,
					Text = "By",
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					ZIndex = 2,
					Visible = false,
					Parent = infoFrame,
				}
				local creatorIcon = create'ImageLabel' {
					Name = "CreatorIcon",
					BackgroundTransparency = 1,
					Size = UDim2.new(0, 30, 0, 30),
					Position = UDim2.new(0, 38, 0, 80),
					ImageTransparency = 0,
					Image = 'rbxasset://textures/ui/Shell/Icons/RobloxIcon32.png',
					ZIndex = 2,
					Visible = false,
					Parent = infoFrame,
				}
			end

			local creatorLabel = create 'TextLabel' {
				Name = 'CreatorLabel',
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 30),
				Position = UDim2.new(0, isTenFootInterface and 72 or 0, 0, 80),
				Font = Enum.Font.SourceSans,
				FontSize = (isTenFootInterface and Enum.FontSize.Size36 or Enum.FontSize.Size18),
				TextWrapped = true,
				TextScaled = true,
				TextColor3 = COLORS.WHITE,
				TextStrokeTransparency = 0,
				Text = "",
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				ZIndex = 2,
				Parent = infoFrame,
			}

		local backgroundTextureFrame = create 'Frame' {
			Name = 'BackgroundTextureFrame',
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),
			ClipsDescendants = true,
			ZIndex = 1,
			BackgroundTransparency = 1,
			Parent = mainBackgroundContainer,
		}

	local errorFrame = create 'Frame' {
		Name = 'ErrorFrame',
		BackgroundColor3 = COLORS.ERROR,
		BorderSizePixel = 0,
		Position = UDim2.new(0.25,0,0,0),
		Size = UDim2.new(0.5, 0, 0, 80),
		ZIndex = 8,
		Visible = false,
		Parent = screenGui,
	}

		local errorText = create 'TextLabel' {
			Name = "ErrorText",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			Font = Enum.Font.SourceSansBold,
			FontSize = Enum.FontSize.Size14,
			TextWrapped = true,
			TextColor3 = COLORS.WHITE,
			Text = "",
			ZIndex = 8,
			Parent = errorFrame,
		}

	while not game:GetService("CoreGui") do
		wait()
	end
	screenGui.Parent = game:GetService("CoreGui")
	currScreenGui = screenGui
end

function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

---------------------------------------------------------
-- Main Script (show something now + setup connections)

-- start loading assets asap
InfoProvider:LoadAssets()
MainGui:GenerateMain()
if isTenFootInterface then
	createTenfootCancelGui()
end

local lastRenderTime, lastDotUpdateTime, brickCountChange = nil, nil, nil
local fadeCycleTime = 1.7
local turnCycleTime = 2
local lastAbsoluteSize = Vector2.new(0, 0)
local loadingDots = "..."
local dotChangeTime = .2
local lastBrickCount = 0

renderSteppedConnection = game:GetService("RunService").RenderStepped:connect(function()
	if not currScreenGui then return end
	if not currScreenGui:FindFirstChild("BlackFrame") then return end

	if setVerb then
		currScreenGui.BlackFrame.CloseButton:SetVerb("Exit")
		setVerb = false
	end

	if currScreenGui.BlackFrame:FindFirstChild("BackgroundTextureFrame") and currScreenGui.BlackFrame.BackgroundTextureFrame.AbsoluteSize ~= lastAbsoluteSize then
		lastAbsoluteSize = currScreenGui.BlackFrame.BackgroundTextureFrame.AbsoluteSize
		MainGui:tileBackgroundTexture(currScreenGui.BlackFrame.BackgroundTextureFrame)
	end

	local infoFrame = currScreenGui.BlackFrame:FindFirstChild('InfoFrame')
	if infoFrame then
		-- set place name
		local placeLabel = infoFrame:FindFirstChild('PlaceLabel')
		if placeLabel and placeLabel.Text == "" then
			placeLabel.Text = InfoProvider:GetGameName()
		end

		-- set creator name
		local creatorLabel = infoFrame:FindFirstChild('CreatorLabel')
		if creatorLabel and creatorLabel.Text == "" then
			local creatorName = InfoProvider:GetCreatorName()
			if creatorName ~= "" then
				if isTenFootInterface then
					local showDevName = true
					if platform == Enum.Platform.XBoxOne then
						local success, result = pcall(function()
							return settings():GetFFlag("ShowDevNameInXboxApp")
						end)
						if success then
							showDevName = result
						end
					end
					creatorLabel.Text = showDevName and creatorName or ""
					local creatorIcon = infoFrame:FindFirstChild('CreatorIcon')
					local byLabel = infoFrame:FindFirstChild('ByLabel')
					if creatorIcon then creatorIcon.Visible = showDevName end
					if byLabel then byLabel.Visible = showDevName end
				else
					creatorLabel.Text = "By "..creatorName
				end
			end
		end
	end

	if not lastRenderTime then
		lastRenderTime = tick()
		lastDotUpdateTime = lastRenderTime
		return
	end

	local currentTime = tick()
	local fadeAmount = (currentTime - lastRenderTime) * fadeCycleTime
	local turnAmount = (currentTime - lastRenderTime) * (360/turnCycleTime)
	lastRenderTime = currentTime

	currScreenGui.BlackFrame.GraphicsFrame.LoadingImage.Rotation = currScreenGui.BlackFrame.GraphicsFrame.LoadingImage.Rotation + turnAmount

	local updateLoadingDots =  function()
		loadingDots = loadingDots.. "."
		if loadingDots == "...." then
			loadingDots = ""
		end
		currScreenGui.BlackFrame.GraphicsFrame.LoadingText.Text = "Loading" ..loadingDots
	end

	if currentTime - lastDotUpdateTime >= dotChangeTime and InfoProvider:GetCreatorName() == "" then
		lastDotUpdateTime = currentTime
		updateLoadingDots()
	else
		if guiService:GetBrickCount() > 0 then
			if brickCountChange == nil then
				brickCountChange = guiService:GetBrickCount()
			end
			if guiService:GetBrickCount() - lastBrickCount >= brickCountChange then
				lastBrickCount = guiService:GetBrickCount()
				updateLoadingDots()
			end
		end
	end

	if not isTenFootInterface then
		if currentTime - startTime > 5 and currScreenGui.BlackFrame.CloseButton.ImageTransparency > 0 then
			currScreenGui.BlackFrame.CloseButton.ImageTransparency = currScreenGui.BlackFrame.CloseButton.ImageTransparency - fadeAmount

			if currScreenGui.BlackFrame.CloseButton.ImageTransparency <= 0 then
				currScreenGui.BlackFrame.CloseButton.Active = true
			end
		end
	end
end)

spawn(function()
	local RobloxGui = game:GetService("CoreGui"):WaitForChild("RobloxGui")
	local guiInsetChangedEvent = Instance.new("BindableEvent")
	guiInsetChangedEvent.Name = "GuiInsetChanged"
	guiInsetChangedEvent.Parent = RobloxGui
	guiInsetChangedEvent.Event:connect(function(x1, y1, x2, y2)
		if currScreenGui and currScreenGui:FindFirstChild("BlackFrame") then
			currScreenGui.BlackFrame.Position = UDim2.new(0, -x1, 0, -y1)
			currScreenGui.BlackFrame.Size = UDim2.new(1, x1 + x2, 1, y1 + y2)
		end
	end)
end)

local leaveGameButton, leaveGameTextLabel, errorImage = nil

guiService.ErrorMessageChanged:connect(function()
	if guiService:GetErrorMessage() ~= '' then
		if isTenFootInterface then
			currScreenGui.ErrorFrame.Size = UDim2.new(1, 0, 0, 144)
			currScreenGui.ErrorFrame.Position = UDim2.new(0, 0, 0, 0)
			currScreenGui.ErrorFrame.BackgroundColor3 = COLORS.BLACK
			currScreenGui.ErrorFrame.BackgroundTransparency = 0.5
			currScreenGui.ErrorFrame.ErrorText.FontSize = Enum.FontSize.Size36
			currScreenGui.ErrorFrame.ErrorText.Position = UDim2.new(.3, 0, 0, 0)
			currScreenGui.ErrorFrame.ErrorText.Size = UDim2.new(.4, 0, 0, 144)
			if errorImage == nil then
				errorImage = Instance.new("ImageLabel")
				errorImage.Image = "rbxasset://textures/ui/ErrorIconSmall.png"
				errorImage.Size = UDim2.new(0, 96, 0, 79)
				errorImage.Position = UDim2.new(0.228125, 0, 0, 32)
				errorImage.ZIndex = 9
				errorImage.BackgroundTransparency = 1
				errorImage.Parent = currScreenGui.ErrorFrame
			end
			-- we show a B button to kill game data model on console
			if not isTenFootInterface then
				if leaveGameButton == nil then
					local RobloxGui = game:GetService("CoreGui"):WaitForChild("RobloxGui")
					local utility = require(RobloxGui.Modules.Settings.Utility)
					local textLabel = nil
					leaveGameButton, leaveGameTextLabel = utility:MakeStyledButton("LeaveGame", "Leave", UDim2.new(0, 288, 0, 78))
					leaveGameButton:SetVerb("Exit")
					leaveGameButton.NextSelectionDown = leaveGameButton
					leaveGameButton.NextSelectionLeft = leaveGameButton
					leaveGameButton.NextSelectionRight = leaveGameButton
					leaveGameButton.NextSelectionUp = leaveGameButton
					leaveGameButton.ZIndex = 9
					leaveGameButton.Position = UDim2.new(0.771875, 0, 0, 37)
					leaveGameButton.Parent = currScreenGui.ErrorFrame
					leaveGameTextLabel.FontSize = Enum.FontSize.Size36
					leaveGameTextLabel.ZIndex = 10
					game:GetService("GuiService").SelectedCoreObject = leaveGameButton
				else
					game:GetService("GuiService").SelectedCoreObject = leaveGameButton
				end
			end
		end
		currScreenGui.ErrorFrame.ErrorText.Text = guiService:GetErrorMessage()
		currScreenGui.ErrorFrame.Visible = true
		local blackFrame = currScreenGui:FindFirstChild('BlackFrame')
		if blackFrame then
			blackFrame.CloseButton.ImageTransparency = 0
			blackFrame.CloseButton.Active = true
		end
	else
		currScreenGui.ErrorFrame.Visible = false
	end
end)

guiService.UiMessageChanged:connect(function(type, newMessage)
	if type == Enum.UiMessageType.UiMessageInfo then
		local blackFrame = currScreenGui and currScreenGui:FindFirstChild('BlackFrame')
		if blackFrame then
			blackFrame.UiMessageFrame.UiMessage.Text = newMessage
			if newMessage ~= '' then
				blackFrame.UiMessageFrame.Visible = true
			else
				blackFrame.UiMessageFrame.Visible = false
			end
		end
	end
end)

if guiService:GetErrorMessage() ~= '' then
	currScreenGui.ErrorFrame.ErrorText.Text = guiService:GetErrorMessage()
	currScreenGui.ErrorFrame.Visible = true
end


function stopListeningToRenderingStep()
	if renderSteppedConnection then
		renderSteppedConnection:disconnect()
		renderSteppedConnection = nil
	end
end

function fadeAndDestroyBlackFrame(blackFrame)
	if destroyingBackground then return end
	destroyingBackground = true
	spawn(function()
		local infoFrame = blackFrame:FindFirstChild("InfoFrame")
		local graphicsFrame = blackFrame:FindFirstChild("GraphicsFrame")
		
		if blackFrame:FindFirstChild("InfoFrame") then
				local infoFrameChildren = infoFrame:GetChildren()
				local transparency = 0
				local rateChange = 1.8
				local lastUpdateTime = nil

				while transparency < 1 do
					if not lastUpdateTime then
						lastUpdateTime = tick()
					else
						local newTime = tick()
						transparency = transparency + rateChange * (newTime - lastUpdateTime)
						for i = 1, #infoFrameChildren do
							local child = infoFrameChildren[i]
							if child:IsA('TextLabel') then
								child.TextTransparency = transparency
								child.TextStrokeTransparency = transparency
							elseif child:IsA('ImageLabel') then
								child.ImageTransparency = transparency
							end
						end
						graphicsFrame.LoadingImage.ImageTransparency = transparency
						blackFrame.BackgroundTransparency = transparency

						if backgroundImageTransparency < 1 then
							backgroundImageTransparency = transparency
							local backgroundImages = blackFrame.BackgroundTextureFrame:GetChildren()
							for i = 1, #backgroundImages do
								backgroundImages[i].ImageTransparency = backgroundImageTransparency
							end
						end

						lastUpdateTime = newTime
					end
					wait()
				end
				if blackFrame ~= nil then
					stopListeningToRenderingStep()
					blackFrame:Destroy()
				end
		end
	end)
end

function destroyLoadingElements(instant)
	if not currScreenGui then return end
	if destroyedLoadingGui then return end
	destroyedLoadingGui = true

	local guiChildren = currScreenGui:GetChildren()
	for i=1, #guiChildren do
		-- need to keep this around in case we get a connection error later
		if guiChildren[i].Name ~= "ErrorFrame" then
			if guiChildren[i].Name == "BlackFrame" and not instant then
				fadeAndDestroyBlackFrame(guiChildren[i])
			else
				guiChildren[i]:Destroy()
			end
		end
	end
end

-- ====================================================================
-- FORCED DELETION SEQUENCE: REMOVES GUI AFTER EXACTLY 3 SECONDS NO MATTER WHAT
-- ====================================================================
hasReplicatedFirstElements = false

spawn(function()
	wait(3) -- Display duration forced to exactly 3 seconds
	if currScreenGui and currScreenGui:FindFirstChild("BlackFrame") then
		if isTenFootInterface then
			ContextActionService:UnbindCoreAction('CancelGameLoad')
		end
		destroyLoadingElements(false)
	end
end)

local UserInputServiceChangedConn;
local function onUserInputServiceChanged(prop)
	if prop == 'VREnabled' then
		local UseVr = false
		pcall(function() UseVr = UIS.VREnabled end)

		if UseVr then
			if UserInputServiceChangedConn then
				UserInputServiceChangedConn:disconnect()
				UserInputServiceChangedConn = nil
			end
			if isTenFootInterface then
				ContextActionService:UnbindCoreAction('CancelGameLoad')
			end
			destroyLoadingElements(true)
			require(RobloxGui.Modules.LoadingScreen3D)
		end
	end
end

UserInputServiceChangedConn = UIS.Changed:connect(onUserInputServiceChanged)
onUserInputServiceChanged('VREnabled')

--2012 BUBBLECHAT
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")
local Chat = game:GetService("Chat")
local LocalPlayer = Players.LocalPlayer

-- Disable default Roblox chat stuff
pcall(function()
	TextChatService.BubbleChatConfiguration.Enabled = false
end)
pcall(function()
	Chat:SetBubbleChatEnabled(false)
end)

local ZOOM_THRESHOLD = 52 -- Distance in studs where stage 2 ("...") triggers
local MAX_VISIBILITY_DISTANCE = 75 -- Maximum distance before bubble disappears
local BUBBLE_LIFETIME = 20 -- Lifetime: 20 seconds

local lastProcessedMessages = {}

local function createClassicBubble(head, messageText)
	if not head or not head:IsA("BasePart") then return end
	
	-- Purge any old custom bubble instances on this head
	for _, child in ipairs(head:GetChildren()) do
		if child.Name == "ClassicBubbleGui" then
			child:Destroy()
		end
	end
	
	local classicFont = Font.new(
		"rbxasset://fonts/families/Arial.json",
		Enum.FontWeight.Regular,
		Enum.FontStyle.Normal
	)
	local fontSize = 20
	local maxTextWidth = 220 
	
	-- Measure text bounds
	local absoluteTextSize = TextService:GetTextSize(
		messageText, 
		fontSize, 
		Enum.Font.Arial, 
		Vector2.new(maxTextWidth, 1000)
	)
	
	-- Dynamic bubble dimensions
	local normalWidth = math.clamp(absoluteTextSize.X + 24, 42, maxTextWidth + 24)
	local normalHeight = absoluteTextSize.Y + 24 
	local tailHeight = 19
	local tailWidth = 16

	-- Stage 2 ("...") dimensions
	local smallWidth = 52
	local smallHeight = 38

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ClassicBubbleGui"
	billboard.Size = UDim2.new(0, normalWidth, 0, normalHeight + tailHeight)
	billboard.Adornee = head
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.SizeOffset = Vector2.new(0, 0.5)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = MAX_VISIBILITY_DISTANCE
	billboard.ZIndexBehavior = Enum.ZIndexBehavior.Global

	-- Main Bubble Body
	local bubbleBody = Instance.new("ImageLabel")
	bubbleBody.Name = "BubbleBody"
	bubbleBody.Image = "rbxassetid://2582470061"
	bubbleBody.BackgroundTransparency = 1
	bubbleBody.ScaleType = Enum.ScaleType.Slice
	bubbleBody.SliceCenter = Rect.new(29, 29, 67, 67)
	bubbleBody.SliceScale = 0.4
	bubbleBody.Size = UDim2.new(1, 0, 0, normalHeight) 
	bubbleBody.ZIndex = 2
	bubbleBody.Parent = billboard

	-- Tail Image (Lowered by 1px to normalHeight - 6)
	local bubbleTail = Instance.new("ImageLabel")
	bubbleTail.Name = "BubbleTail"
	bubbleTail.Size = UDim2.new(0, tailWidth, 0, tailHeight)
	bubbleTail.Position = UDim2.new(0.5, -tailWidth / 2, 0, normalHeight - 6)
	bubbleTail.BackgroundTransparency = 1
	bubbleTail.Image = "rbxassetid://2582470060"
	bubbleTail.ZIndex = 4
	bubbleTail.Parent = billboard

	-- White Connector Box
	local connectorBox = Instance.new("Frame")
	connectorBox.Name = "ConnectorBox"
	connectorBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	connectorBox.BorderSizePixel = 0
	connectorBox.ZIndex = 3
	connectorBox.Size = UDim2.new(0, 10, 0, 6)
	connectorBox.Position = UDim2.new(0.5, -5, 0, -4)
	connectorBox.Parent = bubbleTail

	-- Chat Text Label
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -16, 0, absoluteTextSize.Y)
	textLabel.Position = UDim2.new(0, 8, 0, 12)
	textLabel.BackgroundTransparency = 1
	textLabel.FontFace = classicFont
	textLabel.TextSize = fontSize
	textLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
	textLabel.TextWrapped = true
	textLabel.Text = messageText
	textLabel.ZIndex = 10
	textLabel.Parent = billboard
	
	billboard.Parent = head

	local renderConnection
	renderConnection = RunService.RenderStepped:Connect(function()
		if not billboard or not billboard.Parent or not workspace.CurrentCamera then
			if renderConnection then renderConnection:Disconnect() end
			return
		end
		
		local camPos = workspace.CurrentCamera.CFrame.Position
		local distance = (camPos - head.Position).Magnitude
		
		if distance > ZOOM_THRESHOLD then
			textLabel.Text = "..."
			textLabel.Size = UDim2.new(1, -16, 0, 20)
			textLabel.Position = UDim2.new(0, 8, 0, 9)
			billboard.Size = UDim2.new(0, smallWidth, 0, smallHeight + tailHeight)
			bubbleBody.Size = UDim2.new(1, 0, 0, smallHeight)
			bubbleTail.Position = UDim2.new(0.5, -tailWidth / 2, 0, smallHeight - 6)
		else
			textLabel.Text = messageText
			textLabel.Size = UDim2.new(1, -16, 0, absoluteTextSize.Y)
			textLabel.Position = UDim2.new(0, 8, 0, 12)
			billboard.Size = UDim2.new(0, normalWidth, 0, normalHeight + tailHeight)
			bubbleBody.Size = UDim2.new(1, 0, 0, normalHeight)
			bubbleTail.Position = UDim2.new(0.5, -tailWidth / 2, 0, normalHeight - 6)
		end
	end)
	
	task.delay(BUBBLE_LIFETIME, function()
		if renderConnection then renderConnection:Disconnect() end
		if billboard and billboard.Parent then
			billboard:Destroy()
		end
	end)
end

local function handleBubbleSpawn(player, text)
	if not player or not text or text == "" then return end

	local msgKey = player.UserId .. ":" .. text
	if lastProcessedMessages[msgKey] then return end
	lastProcessedMessages[msgKey] = true
	task.delay(0.05, function() lastProcessedMessages[msgKey] = nil end)

	local character = player.Character
	if character then
		local head = character:FindFirstChild("Head")
		if head then
			createClassicBubble(head, text)
		end
	end
end

-- Instant event triggers
local function trackPlayer(player)
	player.Chatted:Connect(function(msg)
		handleBubbleSpawn(player, msg)
	end)
end

for _, p in ipairs(Players:GetPlayers()) do
	trackPlayer(p)
end
Players.PlayerAdded:Connect(trackPlayer)

TextChatService.MessageReceived:Connect(function(message)
	if message.TextSource then
		local player = Players:GetPlayerByUserId(message.TextSource.UserId)
		handleBubbleSpawn(player, message)
	end
end)

Chat.Chatted:Connect(function(part, message)
	if part and part:IsA("BasePart") then
		local player = Players:GetPlayerFromCharacter(part.Parent) or Players:GetPlayerFromCharacter(part)
		if player then
			handleBubbleSpawn(player, message)
		end
	end
end)

-- Background cleanup of default Roblox bubbles
if LocalPlayer then
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 2)
	if playerGui then
		playerGui.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BillboardGui") and descendant.Name ~= "ClassicBubbleGui" then
				descendant:Destroy()
			end
		end)
	end
end

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

if (not game:IsLoaded()) then
	game.Loaded:Wait()
end

-- Settings
local Developer = (isfile and (isfile("yeku.txt") and isfile("Legacy.rbxm")))
local Environment = (getgenv or function() return _G end)
local Settings = Environment().LegacySettings or ({
	Year = 2014,
	OldGraphics = false,
	HideDisplayName = true,
	SafeChat = false,
	OldConsole = true,
	OldBubbleChat = false,
})

-- Services
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

-- Variables
local RobloxGui = CoreGui:WaitForChild("RobloxGui")
local ChatBubbles = CoreGui:WaitForChild("ExperienceChat"):WaitForChild("bubbleChat")

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

-- Module
local Suite = Environment().Suite or loadstring(game:HttpGet("https://raw.githubusercontent.com/yeku/forks/refs/heads/main/Scripts/RBXMSuite.luau"))()
local Legacy = (function()
	local Path do
		if (Developer) then
			StarterGui:SetCore("SendNotification", { Title = "Legacy", Text = "Running the developer build", Duration = 5 })
			Path = "Legacy.rbxm"
		else
			local RBXM = Suite.download("yeku/legacy@latest", "Legacy.rbxm")
			Path = RBXM
		end
	end

	return Suite.launch(Path, { runscripts = true, debug = true })
end)()

-- Setup
local LegacyGui = Suite.require(Legacy):Start(Settings.Year, Settings.SafeChat)

RobloxGui.Enabled = false
RobloxGui.NotificationFrame.Parent = LegacyGui

Run(Settings.OldConsole == true, function()
	loadstring(game:HttpGet("https://raw.githubusercontent.com/yeku/forks/refs/heads/main/Scripts/LegacyConsole.luau"))()
end)

Run(Settings.OldGraphics == true, function()
	if (sethiddenproperty) then
		task.spawn(sethiddenproperty, Lighting, "Technology", Enum.Technology.Compatibility)
	end

	for _, Hidden in next, Lighting:QueryDescendants("> DepthOfFieldEffect, > SunRaysEffect, > BloomEffect, > BlurEffect, > ColorCorrectionEffect, > Atmosphere") do
		if (Hidden:IsA("Atmosphere")) then
			Hidden:Destroy()
		else
			Force(Hidden, "Enabled", false)
		end
	end

	Create("ColorGradingEffect", { TonemapperPreset = Enum.TonemapperPreset.Retro })
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

	for _, Object in next, ChatBubbles:QueryDescendants(`#Caret, #DistantBubble`) do
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
	local TopBarApp = CoreGui:WaitForChild("TopBarApp", 10):WaitForChild("TopBarApp", 10)
	Force(TopBarApp, "Enabled", false)
end)

task.spawn(function()
	local SettingsShield = RobloxGui:WaitForChild("SettingsClippingShield"):WaitForChild("SettingsShield")
	local Modal = (SettingsShield and SettingsShield:WaitForChild("Modal"))

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

local gameMainMenu = CoreGui:WaitForChild("NewRobloxGui")
    :WaitForChild("ControlFrame")
    :WaitForChild("UserSettingsShield")
    :WaitForChild("Settings")
    :WaitForChild("SettingsStyle")
    :WaitForChild("GameMainMenu")

local leaveConfirmationMenu = CoreGui.NewRobloxGui.ControlFrame.UserSettingsShield.Settings.SettingsStyle.LeaveConfirmationMenu

local LeaveGameButton = Instance.new("TextButton")
LeaveGameButton.Name = "LeaveGameButton"
LeaveGameButton.Parent = gameMainMenu
LeaveGameButton.Position = UDim2.new(0.5, -170, 0, 258)
LeaveGameButton.Size = UDim2.new(0, 340, 0, 50)
LeaveGameButton.AnchorPoint = Vector2.new(0, 0)
LeaveGameButton.Rotation = 0
LeaveGameButton.BackgroundColor3 = Color3.fromRGB(163, 162, 165)
LeaveGameButton.BackgroundTransparency = 0
LeaveGameButton.BorderColor3 = Color3.fromRGB(27, 42, 53)
LeaveGameButton.BorderSizePixel = 1
LeaveGameButton.Visible = true
LeaveGameButton.Active = true
LeaveGameButton.Selectable = true
LeaveGameButton.Interactable = true
LeaveGameButton.AutoButtonColor = true
LeaveGameButton.ZIndex = 8
LeaveGameButton.ClipsDescendants = false
LeaveGameButton.Text = "Leave Game"
LeaveGameButton.TextColor3 = Color3.fromRGB(255, 255, 255)
LeaveGameButton.TextTransparency = 0
LeaveGameButton.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
LeaveGameButton.TextStrokeTransparency = 1
LeaveGameButton.TextSize = 24
LeaveGameButton.TextScaled = false
LeaveGameButton.TextWrapped = false
LeaveGameButton.RichText = false
LeaveGameButton.TextXAlignment = Enum.TextXAlignment.Center
LeaveGameButton.TextYAlignment = Enum.TextYAlignment.Center
LeaveGameButton.LineHeight = 1
LeaveGameButton.Font = Enum.Font.SourceSansBold
LeaveGameButton.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
LeaveGameButton.Style = Enum.ButtonStyle.RobloxRoundButton

leaveConfirmationMenu.Position = UDim2.new(0.5, -262, 1, 400)

LeaveGameButton.MouseButton1Click:Connect(function()
    leaveConfirmationMenu.Visible = true
    
    TweenService:Create(
        gameMainMenu,
        TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            Position = UDim2.new(0, 0, -1, -400)
        }
    ):Play()

    TweenService:Create(
        leaveConfirmationMenu,
        TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            Position = UDim2.new(0.5, -262, 0.5, -215)
        }
    ):Play()
end)
