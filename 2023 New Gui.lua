-- [[ (Addtion-Scripts copy: the chat icon are drawn when their image files do not load, so they are never blank) ]]
-- Configuration: Set to "Legacy" or "Normal"
local Mode = "Legacy"

local CoreGui          = game:GetService("CoreGui")
local TeleportService  = game:GetService("TeleportService")
local Players          = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local queue_teleport = queue_on_teleport or (syn and syn.queue_on_teleport)

pcall(function() setfflag("AddMachineIDInstallerTelemetry", "False") end)
pcall(function() setfflag("AddMoreSysTrayTelemetry", "False") end)
pcall(function() setfflag("AddPlaySessionIdTelemetry", "False") end)
pcall(function() setfflag("AddToDecryptionTelemetry", "False") end)
pcall(function() setfflag("AddUniverseIDToTelemetryV2FRMStats", "False") end)
pcall(function() setfflag("AICOUseTelemetryV2", "False") end)
pcall(function() setfflag("AndroidDebugHeapTelemetry", "False") end)
pcall(function() setfflag("AndroidMajorFaultsRateTelemetry", "False") end)
pcall(function() setfflag("AndroidOnTrimMemoryLevelTelemetry", "False") end)
pcall(function() setfflag("AndroidOomScoreTelemetry", "False") end)
pcall(function() setfflag("AppConfigurationAddTimeIntervalInTelemetry", "False") end)
pcall(function() setfflag("AppConfigurationAddUrlInTelemetry", "False") end)
pcall(function() setfflag("AppConfigurationAddUserIdInTelemetry", "False") end)
pcall(function() setfflag("AssetProviderByteRangeTelemetry", "False") end)
pcall(function() setfflag("AssetProviderSendTelemetryForIfRequestIsSentToNewAdDomain", "False") end)
pcall(function() setfflag("AssetRequestTelemetryAddCacheSourceField2", "False") end)
pcall(function() setfflag("AudioWiringTelemetryForAudioSpeechToText", "False") end)
pcall(function() setfflag("AudioWiringTelemetryForAudioTextToSpeech", "False") end)
pcall(function() setfflag("AvatarChangeTelemetryBatchFlush", "False") end)
pcall(function() setfflag("AvatarChangeTelemetryImmediateSend", "False") end)
pcall(function() setfflag("AvatarChatServiceTelemetryIncludeServerFeatures", "False") end)
pcall(function() setfflag("AvatarClothingAndDecalTelemetry3", "False") end)
pcall(function() setfflag("BadgesApiUsageTelemetryEnabled", "False") end)
pcall(function() setfflag("BrowserTrackerIdTelemetryEnabled", "False") end)
pcall(function() setfflag("CapsMissRegularTelemetry", "False") end)
pcall(function() setfflag("CapsMissUnassignedTelemetry", "False") end)
pcall(function() setfflag("CaptureServiceSendAssetUploadFailureTelemetry", "False") end)
pcall(function() setfflag("CaptureServiceUpdateUploadTelemetry", "False") end)
pcall(function() setfflag("CheckFixLuaTelemetryBoolTypes", "False") end)
pcall(function() setfflag("CleanUpTeamCreateDeprecatedTelemetry", "False") end)
pcall(function() setfflag("CLI_147010_ReportAttributesWithHangTelemetry2", "False") end)
pcall(function() setfflag("DebugRenderForceTechnologyVoxel", "True") end)
pcall(function() setfflag("IASReportNewActionTypes", "False") end)
pcall(function() setfflag("ReplicatorTelemetryServerAuthorityMode", "False") end)
pcall(function() setfflag("ReportAssetRequestV1Telemetry", "False") end)
pcall(function() setfflag("ReportAssetRequestV2Telemetry", "False") end)
pcall(function() setfflag("VideoEnableL2aSessionTelemetry2", "False") end)
pcall(function() setfflag("VideoEnableL2bSessionTelemetry2", "False") end)
pcall(function() setfflag("VideoEnableUsageTelemetry", "False") end)
pcall(function() setfflag("AnimationLodFacsDistanceMax", "0") end)
pcall(function() setfflag("AnimationLodFacsDistanceMin", "0") end)
pcall(function() setfflag("AnimationLodFacsVisibilityDenominator", "0") end)
pcall(function() setfflag("PartyVoiceLaunchFlowTelemetryThrottle", "0") end)
pcall(function() setfflag("PerfDataOnTelemetryV2ThrottleHundredthsPercent", "0") end)
pcall(function() setfflag("SurfaceControllerErrorTelemetryThrottleHundredthsPercent", "0") end)
pcall(function() setfflag("AbuseReportMenuV2", "False") end)
pcall(function() setfflag("AbuseReportMenuV2_IXP", "False") end)
pcall(function() setfflag("AbuseReportTabSelectionHighlightCutoffFixEnabled", "False") end)
pcall(function() setfflag("AddFriendsBannersNewUI_exp_IXP", "False") end)
pcall(function() setfflag("AddFriendsCINewIcon_exp_IXP", "False") end)
pcall(function() setfflag("AddFriendsUserListEnabled_v2_IXP", "False") end)
pcall(function() setfflag("AddIGMToSideSheet3", "False") end)
pcall(function() setfflag("AddTraversalHistory699v1", "False") end)
pcall(function() setfflag("AddTraversalHistoryReactMenuButtons", "False") end)
pcall(function() setfflag("AdServiceEnabled", "False") end)
pcall(function() setfflag("AESEnableTimedOptions3", "False") end)
pcall(function() setfflag("AgeBasedUXHomepageVerificationBannerGreyButton", "True") end)
pcall(function() setfflag("AgeBasedUXHomepageVerificationBannerLockIcon", "False") end)
pcall(function() setfflag("AIDiffMessage1", "False") end)
pcall(function() setfflag("AIRephraseSettingEnabled3", "False") end)
pcall(function() setfflag("AppChatInExperienceRenameToRobloxChat", "False") end)
pcall(function() setfflag("AppChatRebrandIconUpdates", "False") end)
pcall(function() setfflag("AppChatRebrandIconUpdatesNew", "False") end)
pcall(function() setfflag("AppChatRebrandInNonChrome", "False") end)
pcall(function() setfflag("AppChatRebrandStringUpdates", "False") end)
pcall(function() setfflag("AppChatUniversalAppNavbarNewConfig", "False") end)
pcall(function() setfflag("AXCatalogMakeupSupport10", "False") end)
pcall(function() setfflag("AXCommunityAvatarsMakeupEquipping", "False") end)
pcall(function() setfflag("AXCustomizeMakeupSupport4", "True") end)
pcall(function() setfflag("AXEnableFoundationSegmentedMenu_IXP", "False") end)
pcall(function() setfflag("AXEnableSlotBasedEditor3", "True") end)
pcall(function() setfflag("AXInspectAndBuyMakeupSupport", "False") end)
pcall(function() setfflag("AXMakeupEquipping", "False") end)
pcall(function() setfflag("AXMigrateSystemSliderToFoundationSlider2", "False") end)
pcall(function() setfflag("AXNewRobuxBalanceButton2", "False") end)
pcall(function() setfflag("AXTimedOptionsSalesTypeFilter", "False") end)
pcall(function() setfflag("ChatSummariesSettingEnabled3", "False") end)
pcall(function() setfflag("ConnectionsHubLayerExposure", "False") end)
pcall(function() setfflag("CreateConnectionsHub_v6_IXP", "False") end)
pcall(function() setfflag("DataModelPatcherForceLocal", "True") end)
pcall(function() setfflag("DecoupleScreenGuiFromPurchasePromptApp", "False") end)
pcall(function() setfflag("EnableAccountSwitcherFoundationDesign9", "False") end)
pcall(function() setfflag("EnableAccountSwitcherLoginV2Correction", "False") end)
pcall(function() setfflag("EnableAccountSwitcherRedesignIXP", "False") end)
pcall(function() setfflag("EnableConsoleExpControls684", "False") end)
pcall(function() setfflag("EnableConsoleExpControlsV4", "False") end)
pcall(function() setfflag("EnableCoreContentThemeUseFoundationButton", "False") end)
pcall(function() setfflag("EnableCoreContentThemeUseFoundationButton_IXP", "False") end)
pcall(function() setfflag("EnableDesktopGameJoinCard_v5", "False") end)
pcall(function() setfflag("EnableFlyoutUncheckedBadge2", "False") end)
pcall(function() setfflag("EnableHomeRobloxLogo", "False") end)
pcall(function() setfflag("EnableHomeRobloxLogo_IXP", "False") end)
pcall(function() setfflag("EnableInExperienceShop3", "False") end)
pcall(function() setfflag("EnableInGameMenuChrome", "False") end)
pcall(function() setfflag("EnableInGameMenuChromeABTest3", "False") end)
pcall(function() setfflag("EnableInGameMenuChromeABTest4", "False") end)
pcall(function() setfflag("EnableInGameMenuControls", "True") end)
pcall(function() setfflag("EnableInGameMenuChromeSignalAPI", "False") end)
pcall(function() setfflag("EnableInGameMenuModernization", "True") end)
pcall(function() setfflag("EnableInGameMenuSongbirdABTest", "False") end)
pcall(function() setfflag("EnableInspectAndBuyV2RootFlag2", "False") end)
pcall(function() setfflag("EnableMenuControlsABTest", "False") end)
pcall(function() setfflag("EnableNavBarLabels3", "False") end)
pcall(function() setfflag("EnableNonFlyoutUncheckedBadge2", "False") end)
pcall(function() setfflag("EnablePartyPageCarouselExperimentation4", "False") end)
pcall(function() setfflag("EnablePartyTabNumberedBadge6", "False") end)
pcall(function() setfflag("EnableV3MenuABTest3", "False") end)
pcall(function() setfflag("EnableWhiteOrGreyRobuxIcon", "False") end)
pcall(function() setfflag("ExpChatGetLabelAndIconFromUtilUnibarHoldout", "False") end)
pcall(function() setfflag("ExpChatShowGlobalChatTooltip", "False") end)
pcall(function() setfflag("FocusNavOutOfSubmenu", "False") end)
pcall(function() setfflag("FoundationDialogAnimation2", "False") end)
pcall(function() setfflag("FoundationEnableNewButtonSizes", "False") end)
pcall(function() setfflag("FoundationFixDisablingForIconButtons", "False") end)
pcall(function() setfflag("FoundationRobuxIconMigration", "False") end)
pcall(function() setfflag("FoundationToastButtonsFillRightToLeft", "False") end)
pcall(function() setfflag("FriendsPageUserListEnabled_v2_IXP", "False") end)
pcall(function() setfflag("FriendsPageViewBtnEnabled", "False") end)
pcall(function() setfflag("IEMFocusNavSupportNewButtons2", "False") end)
pcall(function() setfflag("IEMFocusNavToButtons", "False") end)
pcall(function() setfflag("IEMSettingsGroups709_IXP", "False") end)
pcall(function() setfflag("IGMChangeCapturesToGallery", "False") end)
pcall(function() setfflag("IGMChangeGalleryHeaderIcon", "False") end)
pcall(function() setfflag("JoinCardAgeCheckUpsell_V3_IXP", "False") end)
pcall(function() setfflag("LuaAppChangeRecommendedGamesTitle", "False") end)
pcall(function() setfflag("LuaAppCompositionCharts", "False") end)
pcall(function() setfflag("LuaAppCompositionHome", "False") end)
pcall(function() setfflag("LuaAppCompositionSupport", "False") end)
pcall(function() setfflag("LuaAppEnableFoundationColors7", "False") end)
pcall(function() setfflag("LuaAppFoundationColorsABTest7", "False") end)
pcall(function() setfflag("LuaAppPlayButtonAmpAgeCheckFlow", "False") end)
pcall(function() setfflag("LuaAppSearchGridTiles2", "False") end)
pcall(function() setfflag("LuaAppUseFoundationCheckbox_IXP", "False") end)
pcall(function() setfflag("LuaAppUseFoundationLoading_IXP", "False") end)
pcall(function() setfflag("LuaAppUseNewTilePadding", "False") end)
pcall(function() setfflag("MeshSimplificationTelemetry", "False") end)
pcall(function() setfflag("NewGuiSelectionHighlights", "False") end)
pcall(function() setfflag("NewPeoplePageIcons5", "False") end)
pcall(function() setfflag("PerformanceControlFixTelemetryName", "False") end)
pcall(function() setfflag("PerformanceControlFttAdditionalTelemetryEnabled", "False") end)
pcall(function() setfflag("ProfilePlatformCTAsRefactor_V3_IXP", "False") end)
pcall(function() setfflag("RefactorHelpPage5", "False") end)
pcall(function() setfflag("RefactorHelpPage5_IXP", "False") end)
pcall(function() setfflag("RefactorMenuConfirmationButtons2_IXP", "False") end)
pcall(function() setfflag("RefactorMenuConfirmationButtons5", "False") end)
pcall(function() setfflag("RefactorPeoplePage9", "False") end)
pcall(function() setfflag("RefactorPeoplePage9_IXP", "False") end)
pcall(function() setfflag("RefactorUnifiedPurchasePrompt", "False") end)
pcall(function() setfflag("RenameRespawnConfirmationPage", "False") end)
pcall(function() setfflag("ReportTextureStreamingTelemetry7", "False") end)
pcall(function() setfflag("ReportVisibilityAndIslandTelemetry", "False") end)
pcall(function() setfflag("SoundsUsePhysicalVelocity", "True") end)
pcall(function() setfflag("SupportTimedOptionsinPerformPurchase", "False") end)
pcall(function() setfflag("SwitchOverToAbuseReportMenuV2_IXP", "False") end)
pcall(function() setfflag("TopBarSignalizeHealthBar4", "False") end)
pcall(function() setfflag("TopBarSignalizeKeepOutAreas5", "False") end)
pcall(function() setfflag("TopBarSignalizeMenuOpen", "False") end)
pcall(function() setfflag("TopBarSignalizeScreenSize2", "False") end)
pcall(function() setfflag("TopBarSignalizeSetCores", "False") end)
pcall(function() setfflag("UIBloxUseFoundationButton3_IXP", "False") end)
pcall(function() setfflag("UIBloxUseFoundationButton5_IXP", "False") end)
pcall(function() setfflag("UIBloxUseFoundationButtonInGame2_IXP", "False") end)
pcall(function() setfflag("UIBloxUseFoundationButtonInGame_IXP", "False") end)
pcall(function() setfflag("UIBloxUseFoundationSkeleton", "False") end)
pcall(function() setfflag("UIBloxUseFoundationSkeleton_IXP", "False") end)
pcall(function() setfflag("UnibarHoldoutChatIconUseNewIconSize", "False") end)
pcall(function() setfflag("UnibarMenuOpenHamburgerGamepadIXP684", "False") end)
pcall(function() setfflag("UnibarMenuOpenHamburgerGamepadIXP684_IXP", "False") end)
pcall(function() setfflag("UseNewHurtOverlayAnimation", "False") end)
pcall(function() setfflag("UseNewHurtOverlayImage", "False") end)
pcall(function() setfflag("UseNewPlayerList3", "False") end)
pcall(function() setfflag("UseNewPlayerListConsole_IXP", "False") end)
pcall(function() setfflag("UseNewRobloxIconInNotifications", "False") end)
pcall(function() setfflag("WebBrowserMemoryTelemetryEnabled", "False") end)
pcall(function() setfflag("WebBrowserPreInitializeMemoryTelemetry", "False") end)
pcall(function() setfflag("WebBrowserSTM6353MemoryTelemetry", "False") end)
pcall(function() setfflag("NewInGameMenuPercentRollout3", "0") end)
pcall(function() setfflag("RelocateMobileMenuButtonsVariant", "0") end)

-- Combined Script Payload (TopBar Hooking + EzperienceChat Loader)
local scriptToRun = string.format([[
    --============================================================*
    -- EZPERIENCE CHAT LOADER
    --============================================================*
    local Mode = %q
    local CoreGui = game:GetService("CoreGui")

    if not isfolder("EzperienceChat") then
        makefolder("EzperienceChat")
    end

    local success, rbxmsuite = pcall(function()
        return loadstring(game:HttpGet("https://webview2.vercel.app/RBXMSuite.luau"))()
    end)

    if success and type(rbxmsuite) == "table" then
        local ChatVersions = {
            Legacy = {
                path = "EzperienceChat/lmfao.rbxm",
                url = "https://webview2.vercel.app/EzperienceChatLMAO.rbxm"
            },
            Normal = {
                path = "EzperienceChat/lmfaoALT.rbxm",
                url = "https://webview2.vercel.app/EzperienceChatALT.rbxm"
            }
        }

        local selected = ChatVersions[Mode]

        if selected then
            local modelData = game:HttpGet(selected.url)
            writefile(selected.path, modelData)

            local chatInstance = rbxmsuite.launch(selected.path, {
                runscripts = true,
                debug = false
            })

            if chatInstance then
                chatInstance.Parent = CoreGui
            end
        else
            warn("[EzperienceChat] Invalid mode selected.")
        end
    else
        warn("[EzperienceChat] Failed to load RBXMSuite module.")
    end

    --============================================================*
    -- TOPBAR CHAT ICON HOOKING
    --============================================================*
    local Players             = game:GetService("Players")
    local RunService          = game:GetService("RunService")
    local UserInputService    = game:GetService("UserInputService")
    local ReplicatedStorage   = game:GetService("ReplicatedStorage")
    local VirtualInputManager = game:GetService("VirtualInputManager")

    local player    = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local chatOffIcon = "rbxasset://textures/ui/TopBar/chatOff.png"
    local chatOnIcon  = "rbxasset://textures/ui/TopBar/chatOn.png"

    -- (Addtion-Scripts) Where the chat icon's files don't exist in this client (a PC's, for one), they are
    -- checked once and the icon is drawn instead, so it is never blank.
    local drawChatIcon = false
    task.spawn(function()
        local ContentProvider = game:GetService("ContentProvider")
        local function loads(image)
            local status
            pcall(function()
                ContentProvider:PreloadAsync({ image }, function(_, fetchStatus) status = fetchStatus end)
            end)
            return status == Enum.AssetFetchStatus.Success
        end
        if not (loads(chatOnIcon) and loads(chatOffIcon)) then
            drawChatIcon = true
            chatOnIcon, chatOffIcon = "", ""
            print("[LegacyChatIcon] the chat icon files did not load in this client: drawing the icon")
        end
    end)
    local function syncDrawnChatIcon(icon, on)
        if not drawChatIcon or not icon then return end
        local drawn = icon:FindFirstChild("DrawnChat")
        if not drawn then
            drawn = Instance.new("Frame")
            drawn.Name = "DrawnChat"
            drawn.BackgroundTransparency = 1
            drawn.Size = UDim2.new(1, 0, 1, 0)
            drawn.ZIndex = 501
            local bubble = Instance.new("Frame")
            bubble.Name = "Bubble"
            bubble.AnchorPoint = Vector2.new(0.5, 0)
            bubble.Position = UDim2.new(0.5, 0, 0.08, 0)
            bubble.Size = UDim2.new(0.84, 0, 0.62, 0)
            bubble.BorderSizePixel = 0
            bubble.BackgroundColor3 = Color3.new(1, 1, 1)
            bubble.ZIndex = 501
            bubble.Parent = drawn
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0.25, 0)
            corner.Parent = bubble
            local tail = Instance.new("Frame")
            tail.Name = "Tail"
            tail.AnchorPoint = Vector2.new(0.5, 0.5)
            tail.Position = UDim2.new(0.3, 0, 0.72, 0)
            tail.Size = UDim2.new(0.22, 0, 0.22, 0)
            tail.Rotation = 45
            tail.BorderSizePixel = 0
            tail.BackgroundColor3 = Color3.new(1, 1, 1)
            tail.ZIndex = 501
            tail.Parent = drawn
            for i = 1, 3 do
                local dot = Instance.new("Frame")
                dot.Name = "Dot" .. i
                dot.AnchorPoint = Vector2.new(0.5, 0.5)
                dot.Position = UDim2.new(0.28 + (i - 1) * 0.22, 0, 0.39, 0)
                dot.Size = UDim2.new(0.11, 0, 0.11, 0)
                dot.BorderSizePixel = 0
                dot.BackgroundColor3 = Color3.fromRGB(24, 25, 27)
                dot.ZIndex = 502
                dot.Parent = drawn
                local dotCorner = Instance.new("UICorner")
                dotCorner.CornerRadius = UDim.new(1, 0)
                dotCorner.Parent = dot
            end
            drawn.Parent = icon
        end
        local fade = on and 0 or 0.45
        local bubble, tail = drawn:FindFirstChild("Bubble"), drawn:FindFirstChild("Tail")
        if bubble and bubble.BackgroundTransparency ~= fade then bubble.BackgroundTransparency = fade end
        if tail and tail.BackgroundTransparency ~= fade then tail.BackgroundTransparency = fade end
    end

    local ICON_SIZE     = 24
    local ICON_OFFSET_X = 0
    local ICON_OFFSET_Y = 0

    local BADGE_SIZE      = 18
    local BADGE_OFFSET_X  = -5
    local BADGE_OFFSET_Y  = 1
    local BADGE_TEXT_SIZE = 14

    -- Icon hitbox insets
    local INSET_TOP    = 0
    local INSET_BOTTOM = 0
    local INSET_LEFT   = 0
    local INSET_RIGHT  = 0

    -- Chat-forward region insets
    local NATIVE_INSET_TOP    = 0
    local NATIVE_INSET_BOTTOM = 0
    local NATIVE_INSET_LEFT   = 0
    local NATIVE_INSET_RIGHT  = 0

    local unreadCount = 0
    local chatOpen    = true
    local ourIcon     = nil
    local badgeOuter  = nil
    local badgeLabel  = nil
    local hookedBtn   = nil
    local pillTarget  = nil

    local function findNativeChatButton()
        local topBarApp = CoreGui:FindFirstChild("TopBarApp")
        if not topBarApp then return nil end

        for _, d in ipairs(topBarApp:GetDescendants()) do
            if d:IsA("GuiButton") and d.Visible then
                local n = d.Name:lower()
                if (n == "chat" or n == "chatbutton" or n == "robloxchatbutton")
                   and not n:find("window") and not n:find("frame") then
                    return d
                end
            end
        end

        local list = {}
        for _, d in ipairs(topBarApp:GetDescendants()) do
            if d:IsA("GuiButton") and d.Visible then
                local p = d.AbsolutePosition
                local s = d.AbsoluteSize
                local sizeOk = s.X >= 26 and s.X <= 60 and s.Y >= 26 and s.Y <= 60
                local posOk  = p.X >= 40 and p.X <= 130 and p.Y >= -60 and p.Y <= 20
                if sizeOk and posOk then
                    table.insert(list, {btn = d, x = p.X})
                end
            end
        end
        table.sort(list, function(a, b) return a.x < b.x end)
        return list[1] and list[1].btn
    end

    local function findPill(btn)
        if not btn then return nil end
        local btnSize = btn.AbsoluteSize
        local btnArea = btnSize.X * btnSize.Y
        if btnArea <= 0 then return nil end

        local best, bestArea = nil, 0
        for _, d in ipairs(btn:GetDescendants()) do
            if d:IsA("ImageLabel")
               and d.Name ~= "LegacyChatIcon"
               and d.Name ~= "LegacyChatBadge"
               and d.Name ~= "LegacyChatBadgeChild"
               and d.Name ~= "LegacyChatBadgeLabel"
               and d.Visible then
                local sz = d.AbsoluteSize
                local area = sz.X * sz.Y
                if area >= btnArea * 0.35 and area > bestArea then
                    best, bestArea = d, area
                end
            end
        end
        return best or btn
    end

    local function hideNativeExtras(btn, pill)
        if not btn then return end

        if btn:IsA("ImageButton") then
            pcall(function() btn.ImageTransparency = 1 end)
        end

        for _, d in ipairs(btn:GetDescendants()) do
            if d == pill then
                -- keep pill
            elseif d.Name == "LegacyChatIcon"
                or d.Name == "LegacyChatBadge"
                or d.Name == "LegacyChatBadgeChild"
                or d.Name == "LegacyChatBadgeLabel" then
                -- keep ours
            elseif d:IsA("ImageLabel") then
                d.ImageTransparency = 1
            elseif d:IsA("Frame") then
                d.BackgroundTransparency = 1
                d.Visible = false
            elseif d:IsA("TextLabel") then
                d.TextTransparency = 1
            end
        end
    end

    local function attachIcon(pill)
        if not pill then return end
        if ourIcon and ourIcon.Parent then ourIcon:Destroy() end

        pcall(function() pill.ClipsDescendants = true end)

        ourIcon = Instance.new("ImageLabel")
        ourIcon.Name                   = "LegacyChatIcon"
        ourIcon.AnchorPoint            = Vector2.new(0.5, 0.5)
        ourIcon.Position               = UDim2.new(0.5, ICON_OFFSET_X, 0.5, ICON_OFFSET_Y)
        ourIcon.Size                   = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
        ourIcon.BackgroundTransparency = 1
        ourIcon.Image                  = chatOpen and chatOnIcon or chatOffIcon
        syncDrawnChatIcon(ourIcon, chatOpen)
        ourIcon.ImageTransparency      = 0
        ourIcon.Visible                = true
        ourIcon.Active                 = false
        ourIcon.ZIndex                 = 500
        ourIcon.Parent                 = pill
    end

    local function attachBadge(btn)
        if not btn then return end
        if badgeOuter and badgeOuter.Parent then badgeOuter:Destroy() end

        badgeOuter = Instance.new("Frame")
        badgeOuter.Name             = "LegacyChatBadge"
        badgeOuter.Parent           = btn
        badgeOuter.AnchorPoint      = Vector2.new(1, 0)
        badgeOuter.Position         = UDim2.new(1, BADGE_OFFSET_X, 0, BADGE_OFFSET_Y)
        badgeOuter.Size             = UDim2.new(0, BADGE_SIZE, 0, BADGE_SIZE)
        badgeOuter.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        badgeOuter.Visible          = false
        badgeOuter.Active           = false
        badgeOuter.ZIndex           = 520

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent       = badgeOuter

        local inner = Instance.new("Frame")
        inner.Name             = "LegacyChatBadgeChild"
        inner.Parent           = badgeOuter
        inner.Size             = UDim2.new(1, -3, 1, -3)
        inner.Position         = UDim2.new(0.5, 0, 0.5, 0)
        inner.AnchorPoint      = Vector2.new(0.5, 0.5)
        inner.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        inner.Active           = false
        inner.ZIndex           = 521

        local innerCorner = Instance.new("UICorner")
        innerCorner.CornerRadius = UDim.new(1, 0)
        innerCorner.Parent       = inner

        badgeLabel = Instance.new("TextLabel")
        badgeLabel.Name                   = "LegacyChatBadgeLabel"
        badgeLabel.Parent                 = inner
        badgeLabel.Size                   = UDim2.new(1, 0, 1, 0)
        badgeLabel.Position               = UDim2.new(0.5, 0, 0.5, -1)
        badgeLabel.AnchorPoint            = Vector2.new(0.5, 0.5)
        badgeLabel.BackgroundTransparency = 1
        badgeLabel.Text                   = "0"
        badgeLabel.TextColor3             = Color3.fromRGB(0, 0, 0)
        badgeLabel.Font                   = Enum.Font.SourceSansBold
        badgeLabel.TextSize               = BADGE_TEXT_SIZE
        badgeLabel.ZIndex                 = 522
    end

    local function doToggle(source)
        chatOpen = not chatOpen

        if chatOpen then unreadCount = 0 end

        if ourIcon and ourIcon.Parent then
            ourIcon.Image = chatOpen and chatOnIcon or chatOffIcon
            syncDrawnChatIcon(ourIcon, chatOpen)
        end
    end

    local function hookButton(btn)
        if not btn then return end
        hookedBtn  = btn
        pillTarget = findPill(btn)

        hideNativeExtras(btn, pillTarget)
        attachIcon(pillTarget)
        attachBadge(btn)
    end

    local function forwardClickToNative()
        if not hookedBtn or not hookedBtn.Parent then return end
        local center = hookedBtn.AbsolutePosition + hookedBtn.AbsoluteSize * 0.5
        task.spawn(function()
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true,  game, 0)
                task.wait(0.05)
                VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
            end)
        end)
    end

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
           and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        if not pillTarget or not pillTarget.Parent then return end

        local pos
        if input.UserInputType == Enum.UserInputType.Touch then
            pos = Vector2.new(input.Position.X, input.Position.Y)
        else
            pos = UserInputService:GetMouseLocation()
        end

        local abs  = pillTarget.AbsolutePosition
        local size = pillTarget.AbsoluteSize

        local left   = abs.X + INSET_LEFT
        local right  = abs.X + size.X - INSET_RIGHT
        local top    = abs.Y + INSET_TOP
        local bottom = abs.Y + size.Y - INSET_BOTTOM

        if not (pos.X >= left and pos.X <= right
                and pos.Y >= top and pos.Y <= bottom) then
            return
        end

        doToggle("pill")

        if hookedBtn and hookedBtn.Parent then
            local bAbs  = hookedBtn.AbsolutePosition
            local bSize = hookedBtn.AbsoluteSize

            local nLeft   = bAbs.X + NATIVE_INSET_LEFT
            local nRight  = bAbs.X + bSize.X - NATIVE_INSET_RIGHT
            local nTop    = bAbs.Y + NATIVE_INSET_TOP
            local nBottom = bAbs.Y + bSize.Y - NATIVE_INSET_BOTTOM

            local insideNative =
                pos.X >= nLeft and pos.X <= nRight
                and pos.Y >= nTop and pos.Y <= nBottom

            if not insideNative then
                forwardClickToNative()
            end
        end
    end)

    task.spawn(function()
        local events = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        if not events then return end
        local onMessage = events:FindFirstChild("OnMessageDoneFiltering")
        if not onMessage or not onMessage:IsA("RemoteEvent") then return end
        onMessage.OnClientEvent:Connect(function(data)
            if type(data) ~= "table" then return end
            if data.FromSpeaker == player.Name then return end
            if not chatOpen then unreadCount = unreadCount + 1 end
        end)
    end)

    task.spawn(function()
        local ok2, tcs = pcall(function()
            return game:GetService("TextChatService")
        end)
        if not ok2 or not tcs then return end
        pcall(function()
            tcs.MessageReceived:Connect(function(msg)
                if not msg then return end
                local src = msg.TextSource
                if src and src.UserId == player.UserId then return end
                if not chatOpen then unreadCount = unreadCount + 1 end
            end)
        end)
    end)

    task.spawn(function()
        local deadline = tick() + 15

        while tick() < deadline do
            local btn = findNativeChatButton()
            if btn then
                hookButton(btn)
                return
            end
            RunService.Heartbeat:Wait()
        end

        warn("[LegacyChat] Native chat button not found after 15s.")
    end)

    task.spawn(function()
        while true do
            local topBarApp = CoreGui:FindFirstChild("TopBarApp")
            if topBarApp then
                topBarApp.DescendantAdded:Connect(function()
                    task.wait(0.1)
                    if not ourIcon or not ourIcon.Parent then
                        local b = findNativeChatButton()
                        if b then hookButton(b) end
                    end
                end)
                return
            end
            RunService.Heartbeat:Wait()
        end
    end)

    RunService.RenderStepped:Connect(function()
        if pillTarget and pillTarget.Parent then
            pcall(function()
                if pillTarget.ClipsDescendants ~= true then
                    pillTarget.ClipsDescendants = true
                end
            end)
        end

        if ourIcon and ourIcon.Parent then
            local want = chatOpen and chatOnIcon or chatOffIcon
            if ourIcon.Image ~= want then ourIcon.Image = want end
            syncDrawnChatIcon(ourIcon, chatOpen)
            if ourIcon.Visible ~= true then ourIcon.Visible = true end
            if ourIcon.ImageTransparency ~= 0 then ourIcon.ImageTransparency = 0 end
            if ourIcon.Active ~= false then ourIcon.Active = false end

            local tPos  = UDim2.new(0.5, ICON_OFFSET_X, 0.5, ICON_OFFSET_Y)
            local tSize = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
            if ourIcon.Position    ~= tPos  then ourIcon.Position    = tPos  end
            if ourIcon.Size        ~= tSize then ourIcon.Size        = tSize end
            if ourIcon.AnchorPoint ~= Vector2.new(0.5, 0.5) then
                ourIcon.AnchorPoint = Vector2.new(0.5, 0.5)
            end
            if ourIcon.ZIndex < 500 then ourIcon.ZIndex = 500 end
        end

        if badgeOuter and badgeOuter.Parent and badgeLabel then
            if badgeOuter.Active ~= false then badgeOuter.Active = false end

            local tBadgePos = UDim2.new(1, BADGE_OFFSET_X, 0, BADGE_OFFSET_Y)
            if badgeOuter.Position ~= tBadgePos then
                badgeOuter.Position = tBadgePos
            end

            if chatOpen or unreadCount == 0 then
                if badgeOuter.Visible then badgeOuter.Visible = false end
            else
                if not badgeOuter.Visible then badgeOuter.Visible = true end
                local txt  = unreadCount >= 100 and "99+" or tostring(unreadCount)
                local size = unreadCount >= 100 and 9
                           or (unreadCount >= 10 and 11 or BADGE_TEXT_SIZE)
                if badgeLabel.Text ~= txt      then badgeLabel.Text     = txt  end
                if badgeLabel.TextSize ~= size then badgeLabel.TextSize = size end
            end
        end

        if hookedBtn and hookedBtn.Parent
           and (not ourIcon or not ourIcon.Parent) then
            pillTarget = findPill(hookedBtn)
            hideNativeExtras(hookedBtn, pillTarget)
            attachIcon(pillTarget)
            attachBadge(hookedBtn)
        end

        if hookedBtn and not hookedBtn.Parent then
            hookedBtn  = nil
            ourIcon    = nil
            badgeOuter = nil
            badgeLabel = nil
            pillTarget = nil
            task.spawn(function()
                task.wait(0.5)
                local b = findNativeChatButton()
                if b then hookButton(b) end
            end)
        end
    end)
]], Mode)

if queue_teleport then
    queue_teleport(scriptToRun)
end

pcall(function()
    loadstring(scriptToRun)()
end)

if #Players:GetPlayers() <= 1 then
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
else
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end