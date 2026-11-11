-- [[ 2015 EARLY HOOK (mobile and PC) ]]
-- Early 2015 is the 2014 GUI with Roblox's 2015 backpack and chat, before
-- the dark top bar came in late 2015. This loads the 2014 GUI (menu,
-- health) and runs Legacy's own 2015 backpack and chat in
-- place of the 2014 ones, set up the way they were without the top bar:
--    60px hotbar slots above the health bar (3 on phones, 10 on PC)
--    the arrow above the hotbar opens the inventory: "Search" on top, then
--    the tools that aren't on the hotbar; drag them onto the hotbar
--    (phones: swipe the list to scroll, double tap a tool to put it on
--    the hotbar)
--    the hotbar slots go solid while the inventory is open
--    chat lines with a colored dot before "[name]:", the gray Chat button,
--    and a darker box behind the chat while you type, lined up with the
--    menu button (phones have no "click here to chat" bar, only PC does)
--    early 2015 chat bubbles: see-through white, small round corners
--    an early 2015 leaderboard: your name in a dark header, the list slides
--    open under it from the ≡ tab (built on the 2016 leaderboard, shown on phones)
--    on phones it stays thin however many stats the game has (about as wide as
--    with two stats): big numbers are shortened (4.1M) and the columns narrow
--    a Volume slider in Settings > Game Settings, like the 2015 settings
-- Fixes kept from the "2014 gui fix":
--    the dark background behind the menus covers the whole screen (it left
--    strips at the sides on phones) and goes above the leaderboard, chat and
--    menu button, with the open menu on top
--    other backpacks / hotbars (from the game or other scripts) get hidden,
--    and this one stays on even if the game turns the backpack off
-- Pick it as "2015 early" in the GUI list (More gui fix), or run it on its own.

do
	local Players = game:GetService("Players")
	local CoreGui = game:GetService("CoreGui")
	local player = Players.LocalPlayer

	------------------------------------------------------------
	-- MENU BACKGROUND: the 2014 GUI only fills the phone's safe area, so the
	-- dark shield behind its menus (settings, report abuse, help...) left
	-- strips uncovered, and the leaderboard / chat / menu button showed on
	-- top of it. Draw it over the whole screen above those, menu on top.
	------------------------------------------------------------
	local MENU_BACKGROUND_Z = 9 -- above the leaderboard (8), chat and menu button
	local MENU_LIFT = 10 -- the open menu goes this much higher, above the background
	local lifted = setmetatable({}, { __mode = "k" })
	local shields = setmetatable({}, { __mode = "k" })

	-- keep a menu piece above the background, even if its script changes its ZIndex
	local function liftMenuPiece(obj)
		if not obj:IsA("GuiObject") or lifted[obj] then return end
		lifted[obj] = true
		local expected = obj.ZIndex + MENU_LIFT
		obj.ZIndex = expected
		obj:GetPropertyChangedSignal("ZIndex"):Connect(function()
			if obj.ZIndex ~= expected then
				expected = obj.ZIndex + MENU_LIFT
				obj.ZIndex = expected
			end
		end)
	end

	local function fixShield(shield, gui)
		if shields[shield] or lifted[shield] then return end
		shields[shield] = true

		-- way bigger than the screen so it covers past the safe area and padding
		local background = Instance.new("Frame")
		background.Name = shield.Name .. "Background"
		background.BorderSizePixel = 0
		background.Position = UDim2.new(0, -2000, 0, -2000)
		background.Size = UDim2.new(1, 4000, 1, 4000)
		background.BackgroundColor3 = shield.BackgroundColor3
		background.BackgroundTransparency = shield.BackgroundTransparency
		background.ZIndex = MENU_BACKGROUND_Z
		background.Visible = false
		background.Parent = gui

		-- the shield keeps blocking taps, it just doesn't draw anymore
		local function takeLook()
			if shield.BackgroundTransparency < 1 then
				background.BackgroundColor3 = shield.BackgroundColor3
				background.BackgroundTransparency = shield.BackgroundTransparency
				shield.BackgroundTransparency = 1
			end
		end
		takeLook()
		shield:GetPropertyChangedSignal("BackgroundTransparency"):Connect(takeLook)

		-- the menu itself goes above the background
		liftMenuPiece(shield)
		for _, d in ipairs(shield:GetDescendants()) do liftMenuPiece(d) end
		shield.DescendantAdded:Connect(liftMenuPiece)

		local function update()
			background.Visible = shield.Visible and shield:IsDescendantOf(gui)
		end
		shield:GetPropertyChangedSignal("Visible"):Connect(update)
		shield.AncestryChanged:Connect(function()
			if shield:IsDescendantOf(game) then
				update()
			else
				background:Destroy()
			end
		end)
		update()
	end

	local function fixMenus(gui)
		-- let the background draw outside the safe area
		pcall(function() gui.ClipToDeviceSafeArea = false end)
		-- every full-screen shield the 2014 menus use ends in "Shield"
		-- (UserSettingsShield, ReportAbuseShield, HelpDialogShield, ...)
		local function check(obj)
			if obj:IsA("GuiObject") and string.match(obj.Name, "Shield$") then
				fixShield(obj, gui)
			end
		end
		for _, d in ipairs(gui:GetDescendants()) do check(d) end
		gui.DescendantAdded:Connect(check)
	end

	------------------------------------------------------------
	-- ONLY THIS BACKPACK: hide custom backpacks / hotbars / inventories
	-- (ScreenGuis, or frames right inside one, with those words in the name)
	-- and keep this one on when the game switches the backpack off
	------------------------------------------------------------
	local CUSTOM_WORDS = { "backpack", "inventory", "hotbar", "toolbar", "loadout", "satchel" }
	local ROBLOX_GUIS = { NewRobloxGui = true, RobloxGui = true, TopBarApp = true }
	local hidden = setmetatable({}, { __mode = "k" })

	local function isCustomInventory(obj)
		local root = obj:IsA("ScreenGui") and obj or obj.Parent
		if not (root and root:IsA("ScreenGui")) or ROBLOX_GUIS[root.Name] then return false end
		local name = obj.Name:lower()
		for _, word in ipairs(CUSTOM_WORDS) do
			if string.find(name, word, 1, true) then return true end
		end
		return false
	end

	local function hideCustom(obj)
		if hidden[obj] then return end
		local ok, custom = pcall(isCustomInventory, obj)
		if not (ok and custom) then return end
		local prop = obj:IsA("ScreenGui") and "Enabled" or (obj:IsA("GuiObject") and "Visible")
		if not prop then return end
		hidden[obj] = true
		obj[prop] = false
		-- it stays hidden if the game tries to show it again
		obj:GetPropertyChangedSignal(prop):Connect(function()
			if obj[prop] then obj[prop] = false end
		end)
	end

	local hidingStarted = false
	local function hideCustomInventories()
		if hidingStarted then return end
		hidingStarted = true
		task.spawn(function()
			local playerGui = player:WaitForChild("PlayerGui", 30)
			for _, container in ipairs({ playerGui or false, CoreGui }) do
				if container then
					for _, d in ipairs(container:GetDescendants()) do hideCustom(d) end
					container.DescendantAdded:Connect(hideCustom)
				end
			end
		end)
	end

	local function keepBackpackOn(gui)
		-- Legacy turns the backpack off when the game disables Roblox's
		local function on()
			if gui:GetAttribute("BackpackEnabled") == false then
				gui:SetAttribute("BackpackEnabled", true)
			end
		end
		gui:GetAttributeChangedSignal("BackpackEnabled"):Connect(on)
		on()
	end

	------------------------------------------------------------
	-- 2015 BACKPACK AND CHAT: the 2014 base loads Legacy through RBXMSuite.
	-- Hand it a copy whose launch, before the GUI starts, runs Legacy's own
	-- 2015 backpack and chat in place of the 2014 ones, set up the way they
	-- were without the top bar, then fixes the GUI.
	------------------------------------------------------------
	local SUITE_URL = "https://raw.githubusercontent.com/yeku/forks/refs/heads/main/Scripts/RBXMSuite.luau"
	-- RBXMSuite's debug mode starts each script's Source with this, and loads
	-- the Source when the script is first required (so a swap before that counts)
	local HEADER = "^local script, require = unpack%b(); "

	-- each change: { text in Legacy's 2015 script, what it becomes }
	local BACKPACK_CHANGES = {
		-- arrow above the hotbar, hotbar moved up for the health bar
		{ "local TopBarEnabled = true", "local TopBarEnabled = false" },
		-- the top bar opened the inventory, now the arrow does, so it takes taps
		{ "\t\tarrowFrame.Parent = MainFrame", [[
		local arrowButton = NewGui('TextButton', 'Button')
		arrowButton.BorderSizePixel = 0
		arrowButton.Parent = arrowFrame
		arrowButton.MouseButton1Click:connect(openClose)
		arrowFrame.Parent = MainFrame]] },
		-- phones: an inventory tool doesn't grab your finger, so a swipe
		-- anywhere in the list scrolls it (double tap puts it on the hotbar)
		{ "local DOUBLE_CLICK_TIME = 0.5\n",
			"local DOUBLE_CLICK_TIME = 0.5\nlocal SWIPE_TO_SCROLL = game:GetService('UserInputService').TouchEnabled\n" },
		{ "\t\tif not hotbarSlot or inventoryOpen then\n\t\t\tSlotFrame.Draggable = true\n\t\tend",
			"\t\tif not hotbarSlot or inventoryOpen then\n\t\t\tSlotFrame.Draggable = not (SWIPE_TO_SCROLL and not hotbarSlot)\n\t\tend" },
		{ "\t\tSlotFrame.BackgroundTransparency = (SlotFrame.Draggable) and 0 or SLOT_FADE_LOCKED\n\t\tSlotFrame.BackgroundColor3 = (SlotFrame.Draggable) and SLOT_DRAGGABLE_COLOR or BACKGROUND_COLOR", [[
		local solid = SlotFrame.Draggable or (SWIPE_TO_SCROLL and slot.Tool and slot.Index > HOTBAR_SLOTS)
		SlotFrame.BackgroundTransparency = (solid) and 0 or SLOT_FADE_LOCKED
		SlotFrame.BackgroundColor3 = (solid) and SLOT_DRAGGABLE_COLOR or BACKGROUND_COLOR]] },
		{ "\tslot.Frame = SlotFrame\n", [[
	slot.Frame = SlotFrame
	if SWIPE_TO_SCROLL then
		local lastTap = 0
		SlotFrame.MouseButton1Click:connect(function()
			local now = tick()
			if slot.Tool and slot.Index > HOTBAR_SLOTS and now - lastTap < DOUBLE_CLICK_TIME and LowestEmptySlot then
				local myTool = slot.Tool
				slot:Clear()
				LowestEmptySlot:Fill(myTool)
				slot:Delete()
				now = 0
			end
			lastTap = now
		end)
	end
]] },
		-- phones: drag a tool onto the hotbar. If the list is long enough to
		-- scroll, an up/down swipe scrolls it and a sideways drag (or a short
		-- hold) picks the tool up; otherwise any drag picks it up. The drag runs
		-- the backpack's own drag start / drop code, so it lands the same way
		-- a PC drag does.
		{ "\t\tSlotFrame.DragBegin:connect(function(dragPoint)", "\t\tlocal function onDragBegin(dragPoint)" },
		{ "\t\t\tend\n\t\tend)\n\n\t\tSlotFrame.DragStopped:connect(function(x, y)",
			"\t\t\tend\n\t\tend\n\t\tSlotFrame.DragBegin:connect(onDragBegin)\n\n\t\tlocal function onDragStopped(x, y)" },
		{ "\t\t\tlastUpTime = now\n\t\tend)\n\tend\n", [[
			lastUpTime = now
		end
		SlotFrame.DragStopped:connect(onDragStopped)

		if SWIPE_TO_SCROLL then
			local HOLD_TIME, MOVE_DISTANCE = 0.3, 8
			SlotFrame.InputBegan:connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.Touch or SlotFrame.Draggable or not slot.Tool or next(Dragging) then return end
				local start = input.Position
				local scrolling, dragging, released, base = false, false, false, nil
				local moveConn, endConn

				local function pickUp(delta)
					if dragging or scrolling or released or not slot.Tool or next(Dragging) then return end
					dragging = true
					ScrollingFrame.ScrollingEnabled = false
					onDragBegin(SlotFrame.Position)
					base = SlotFrame.Position
					SlotFrame.Position = base + UDim2.new(0, delta.X, 0, delta.Y)
				end

				moveConn = UserInputService.InputChanged:connect(function(changed)
					if changed ~= input then return end
					local delta = changed.Position - start
					if dragging then
						SlotFrame.Position = base + UDim2.new(0, delta.X, 0, delta.Y)
					elseif not scrolling and delta.magnitude > MOVE_DISTANCE then
						local canScroll = ScrollingFrame.CanvasSize.Y.Offset > ScrollingFrame.AbsoluteWindowSize.Y
						if canScroll and math.abs(delta.Y) > math.abs(delta.X) then
							scrolling = true
						else
							pickUp(delta)
						end
					end
				end)
				endConn = UserInputService.InputEnded:connect(function(ended)
					if ended ~= input then return end
					released = true
					moveConn:disconnect()
					endConn:disconnect()
					if dragging then
						dragging = false
						ScrollingFrame.ScrollingEnabled = true
						local center = SlotFrame.AbsolutePosition + SlotFrame.AbsoluteSize / 2
						onDragStopped(center.X, center.Y)
					end
				end)
				delay(HOLD_TIME, function()
					pickUp(Vector3.new(0, 0, 0))
				end)
			end)
		end
	end
]] },
	}

	local CHAT_CHANGES = {
		-- A PC with a touch screen is a PC: the chat script treated any touch device as a phone, which turned
		-- off the "/" key, the "To chat click here" bar and the mode buttons. A phone has no mouse, so it stays a phone.
		{ "pcall(function() touchEnabled = InputService.TouchEnabled end)\n\t\treturn touchEnabled",
			"pcall(function() touchEnabled = InputService.TouchEnabled and not (InputService.KeyboardEnabled and InputService.MouseEnabled) end)\n\t\treturn touchEnabled" },
		-- no top bar: the dot before each name, the Chat button, the darker
		-- box while you type
		{ "\treturn true\nend\n\nlocal function GetChatMovedUpPlaceIdCutoffFlag",
			"\treturn false\nend\n\nlocal function GetChatMovedUpPlaceIdCutoffFlag" },
		-- the top bar used to show the chat window
		{ "\t\t--SetVisbility(true)", "\t\tSetVisbility(true)" },
		-- "/" still starts typing on PC
		{ "\t\t\tif GetTopBarFlag() then\n\t\t\t\tif true then", "\t\t\tif true then\n\t\t\t\tif true then" },
		-- chat box lined up with the menu button (2px from the left)
		{ "\t\t\tName = 'ChatWindowContainer';\n\t\t\tSize = UDim2.new(0.3, 0, 0.25, 0);\n\t\t\tPosition = UDim2.new(0, 8, 0, 37);",
			"\t\t\tName = 'ChatWindowContainer';\n\t\t\tSize = UDim2.new(0.3, 0, 0.25, 0);\n\t\t\tPosition = UDim2.new(0, 2, 0, 37);" },
		-- The "To chat click here or press / key" bar is the chat script's own: along the bottom of the screen on
		-- PC (the script reserves that strip), and none on phones. (It used to be moved under the chat box.)
		-- "/" also works when something else took the key but no text box has focus
		{ "if key.KeyCode == Enum.KeyCode.Slash and not proc then",
			"if key.KeyCode == Enum.KeyCode.Slash and (not proc or not game:GetService('UserInputService'):GetFocusedTextBox()) then" },
		{ "Please press the '...' icon to chat", "Please press the Chat button to chat" },
		-- phones: tapping the chat box darkens it and lets you scroll, no
		-- need to press the Chat button
		{ "\t\t\t\t\t\t\t\ttouchCount = touchCount + 1\n\t\t\t\t\t\t\t\tdontFadeOutOnMouseLeave = true",
			"\t\t\t\t\t\t\t\ttouchCount = touchCount + 1\n\t\t\t\t\t\t\t\tdontFadeOutOnMouseLeave = true\n\t\t\t\t\t\t\t\tif not this.BackgroundVisible then this:FadeIn(0.25) end" },
	}

	-- the 2016 leaderboard, made to look like early 2015's: your name in a
	-- dark header on top, the list slides open under it from the ≡ tab
	local LEADERBOARD_CHANGES = {
		-- 2016 hid it on phones; early 2015 showed it there
		{ "local IsSmallScreenDevice = UserInputService.TouchEnabled and GuiService:GetScreenResolution().Y <= 500",
			"local IsSmallScreenDevice = false" },
		-- early 2015's thinner, slightly narrower rows; narrower still on
		-- phones, so a couple of stats don't take half the screen
		{ "local MinContainerSize = UDim2.new(0, 165, 0.5, 0)\n", [=[local IsPhone = UserInputService.TouchEnabled and GuiService:GetScreenResolution().Y <= 500
-- phones: big numbers shortened (1.2K, 4.1M) so the stat columns can stay narrow
local function shortNumber(value)
	local suffixes = { "K", "M", "B", "T", "Qa", "Qi" }
	local size, i = math.abs(value), 0
	while size >= 1000 and i < #suffixes do
		size = size / 1000
		i = i + 1
	end
	local digits = size >= 100 and tostring(math.floor(size))
		or (string.gsub(string.format("%.1f", math.floor(size * 10) / 10), "%.0$", ""))
	return (value < 0 and "-" or "") .. digits .. suffixes[i]
end
local MinContainerSize = UDim2.new(0, IsPhone and 130 or 165, 0.5, 0)
]=] },
		{ "\tif numberValue then\n\t\ttext = formatNumber(numberValue)\n\tend\n",
			"\tif numberValue then\n\t\ttext = (IsPhone and math.abs(numberValue) >= 1000) and shortNumber(numberValue) or formatNumber(numberValue)\n\tend\n" },
		{ "local PlayerEntrySizeY = 24\n", "local PlayerEntrySizeY = 18\n" },
		{ "local NameEntrySizeX = 170\n", "local NameEntrySizeX = IsPhone and 120 or 160\n" },
		{ "local StatEntrySizeX = 75\n", "local StatEntrySizeX = IsPhone and 45 or 75\n" },
		-- the list starts under the 40px header
		{ "\tContainer.Position = UDim2.new(1, -167, 0, 2)", "\tContainer.Position = UDim2.new(1, -MinContainerSize.X.Offset - 2, 0, 44)" },
		{ "\t\t\t\tContainer.Position = UDim2.new(1, -offset, 0, 2)", "\t\t\t\tContainer.Position = UDim2.new(1, -offset, 0, 44)" },
		{ "\nreturn Playerlist", [=[

--[[ Early 2015: your name on top, the list slides open under it from the tab
     (tap or drag it), tap your name for the big view in the middle ]]--
do
	local HEADER_HEIGHT, SLIDE_TIME, WIDE_TIME, DRAG_DISTANCE = 40, 0.25, 0.3, 6
	local BASE_NAME_WIDTH = NameEntrySizeX
	local TweenService = game:GetService('TweenService')

	-- everything moves together inside this when the big view opens
	local holder = Instance.new('Frame')
	holder.Name = "PlayerListHolder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 1, 0)
	holder.Parent = NewRobloxGui
	Container.Parent = holder

	local header = Instance.new('TextButton')
	header.Name = "PlayerListHeader"
	header.AutoButtonColor = false
	header.Text = ""
	header.AnchorPoint = Vector2.new(1, 0)
	header.BackgroundColor3 = BG_COLOR
	header.BackgroundTransparency = BG_TRANSPARENCY
	header.BorderSizePixel = 0
	header.Parent = holder

	local headerName = Instance.new('TextLabel')
	headerName.Name = "PlayerName"
	headerName.BackgroundTransparency = 1
	headerName.Size = UDim2.new(1, -6, 1, 0)
	headerName.Font = Enum.Font.SourceSansBold
	headerName.FontSize = Enum.FontSize.Size18
	headerName.TextColor3 = TEXT_COLOR
	headerName.TextStrokeColor3 = TEXT_STROKE_COLOR
	headerName.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	headerName.TextXAlignment = Enum.TextXAlignment.Right
	headerName.Text = Player.Name
	headerName.Parent = header

	-- the list slides inside this, so it can hide above its top edge
	local slideClip = Instance.new('Frame')
	slideClip.Name = "SlideClip"
	slideClip.BackgroundTransparency = 1
	slideClip.Size = UDim2.new(1, 0, 1, 0)
	slideClip.ClipsDescendants = true
	slideClip.Parent = Container
	ScrollList.Parent = slideClip

	local tab = Instance.new('TextButton')
	tab.Name = "ExtendTab"
	tab.AutoButtonColor = false
	tab.BackgroundTransparency = 1
	tab.Text = ""
	tab.Size = UDim2.new(0, 44, 0, 20)
	tab.Parent = header
	for i = 0, 1 do
		local line = Instance.new('Frame')
		line.BackgroundColor3 = Color3.new(1, 1, 1)
		line.BorderSizePixel = 0
		line.Size = UDim2.new(0, 22, 0, 2)
		line.Position = UDim2.new(0.5, -11, 0, 5 + i * 4)
		line.Parent = tab
	end

	local slide = Instance.new('NumberValue') -- list: 0 closed, 1 open
	local wide = Instance.new('NumberValue') -- big view: 0 off, 1 on
	local bigView = false

	local function layout()
		local w = wide.Value
		local width = Container.Size.X.Offset
		-- big view: centered, a tenth of the way down
		holder.Size = UDim2.new(1 - 0.5 * w, w * width / 2, 1, 0)
		holder.Position = UDim2.new(0, 0, 0.1 * w, -2 * w)
		header.Size = UDim2.new(0, width, 0, HEADER_HEIGHT)
		header.Position = UDim2.new(1, Container.Position.X.Offset + width, 0, 2)
		header.Visible = Container.Visible
		local shown = slide.Value * ScrollList.Size.Y.Offset
		ScrollList.Position = UDim2.new(0, 0, 0, shown - ScrollList.Size.Y.Offset)
		tab.Position = UDim2.new(0.5, -22, 1, shown + 4)
	end

	-- the name column takes up whatever the stats leave; in the big view the
	-- rows fill half the screen like the header
	local function setNameWidth(width)
		width = math.floor(width)
		if width == NameEntrySizeX then return end
		local delta = width - NameEntrySizeX
		NameEntrySizeX = width
		local function widen(entry)
			local bg = entry and entry.Frame:FindFirstChild('BGFrame')
			if not bg then return end
			bg.Size = bg.Size + UDim2.new(0, delta, 0, 0)
			local name = bg:FindFirstChild('PlayerName') or bg:FindFirstChild('TeamName')
			if name then name.Size = name.Size + UDim2.new(0, delta, 0, 0) end
		end
		for _, entry in ipairs(PlayerEntries) do widen(entry) end
		for _, entry in ipairs(TeamEntries) do widen(entry) end
		widen(NeutralTeam)
		updateLeaderstatFrames()
	end

	local function fitNames()
		if bigView then
			local statsWidth = Container.Size.X.Offset - NameEntrySizeX
			setNameWidth(math.max(BASE_NAME_WIDTH, NewRobloxGui.AbsoluteSize.X / 2 - statsWidth))
		else
			setNameWidth(BASE_NAME_WIDTH)
		end
	end
	Playerlist.OnLeaderstatsChanged.Event:connect(fitNames)

	-- phones: keep the list about as thin as with two stats, however many the game has.
	-- With more stats the stat columns get narrower first (not under 32), then the
	-- name column (not under 96), so the numbers stay readable.
	local PHONE_MAX_WIDTH, PHONE_MIN_STAT, PHONE_MIN_NAME = 214, 32, 96
	local PHONE_STAT, PHONE_NAME = StatEntrySizeX, NameEntrySizeX
	local function fitStats()
		if not IsPhone then return end
		local count = #GameStats
		local stat, name = PHONE_STAT, PHONE_NAME
		if count > 0 then
			stat = math.floor((PHONE_MAX_WIDTH - PHONE_NAME) / count) - TILE_SPACING
			stat = math.max(PHONE_MIN_STAT, math.min(PHONE_STAT, stat))
			name = PHONE_MAX_WIDTH - count * (stat + TILE_SPACING)
			name = math.max(PHONE_MIN_NAME, math.min(PHONE_NAME, name))
		end
		local changed = false
		if stat ~= StatEntrySizeX then
			StatEntrySizeX = stat
			changed = true
			local function resize(entry)
				if not entry or not entry.Frame then return end
				for _, s in ipairs(GameStats) do
					local statFrame = entry.Frame:FindFirstChild(s.Name)
					if statFrame and statFrame:IsA('Frame') then
						statFrame.Size = UDim2.new(0, stat, statFrame.Size.Y.Scale, statFrame.Size.Y.Offset)
					end
				end
			end
			for _, entry in ipairs(PlayerEntries) do resize(entry) end
			for _, entry in ipairs(TeamEntries) do resize(entry) end
			resize(NeutralTeam)
		end
		if name ~= BASE_NAME_WIDTH then
			BASE_NAME_WIDTH = name
			changed = true
		end
		if changed then
			fitNames() -- the name column to its new width
			updateLeaderstatFrames() -- the stats moved along, and the list's width
		end
	end
	Playerlist.OnLeaderstatsChanged.Event:connect(fitStats)
	fitStats()

	local tweens = {}
	local function tweenTo(value, goal, time)
		if tweens[value] then tweens[value]:Cancel() end
		tweens[value] = TweenService:Create(value, TweenInfo.new(time, Enum.EasingStyle.Quad), { Value = goal })
		tweens[value]:Play()
	end

	-- the player menu (friend / block / report) belongs to a row: close it
	-- whenever the rows move or hide
	local function closeMenu()
		if LastSelectedFrame then
			playerDropDown:Hide()
			LastSelectedFrame = nil
			LastSelectedPlayer = nil
		end
	end

	header.MouseButton1Click:connect(function()
		closeMenu()
		bigView = not bigView
		fitNames()
		tweenTo(wide, bigView and 1 or 0, WIDE_TIME)
	end)

	-- the tab: drag it to pull the list open or shut, or tap it
	tab.InputBegan:connect(function(input)
		local isTouch = input.UserInputType == Enum.UserInputType.Touch
		if not isTouch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if tweens[slide] then tweens[slide]:Cancel() end
		closeMenu()
		local startY, startSlide, dragged = input.Position.Y, slide.Value, false
		local moveConn, endConn
		moveConn = UserInputService.InputChanged:connect(function(changed)
			if isTouch and changed ~= input then return end
			if not isTouch and changed.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			local dy = changed.Position.Y - startY
			if math.abs(dy) >= DRAG_DISTANCE then dragged = true end
			local height = ScrollList.Size.Y.Offset
			if dragged and height > 0 then
				slide.Value = math.max(0, math.min(1, startSlide + dy / height))
			end
		end)
		endConn = UserInputService.InputEnded:connect(function(ended)
			if isTouch and ended ~= input then return end
			if not isTouch and ended.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			moveConn:disconnect()
			endConn:disconnect()
			if dragged then
				tweenTo(slide, (slide.Value >= 0.5) and 1 or 0, SLIDE_TIME)
			else
				tweenTo(slide, (startSlide < 0.5) and 1 or 0, SLIDE_TIME)
			end
		end)
	end)

	slide.Changed:connect(layout)
	wide.Changed:connect(layout)
	Container.Changed:connect(function(property)
		if property == 'Visible' and not Container.Visible then closeMenu() end
		if property == 'Size' or property == 'Position' or property == 'Visible' then layout() end
	end)
	ScrollList.Changed:connect(function(property)
		if property == 'Size' then layout() end
	end)
	layout()
end

return Playerlist]=] },
	}

	-- changes to the 2014 settings script itself
	local SETTINGS_CHANGES = {
		-- Game Settings: the 2015 volume slider, above OK (on PC, where the
		-- graphics slider fills the page, OK moves down and the page grows)
		{ "\tlocal backButton\n\tif hasGraphicsSlider then\n\t\tbackButton = createTextButton(\"OK\",Enum.ButtonStyle.RobloxRoundDefaultButton,Enum.FontSize.Size24,UDim2.new(0,180,0,50),UDim2.new(0,170,0,315))", [[
	----------------------------------------------------------------------------------------------------
	-- V O L U M E    S L I D E R   (from the 2015 settings)
	----------------------------------------------------------------------------------------------------

	local volumeTop = hasGraphicsSlider and 315 or itemTop + 10
	local maxVolumeLevel = 256

	local volumeText = Instance.new("TextLabel")
	volumeText.Name = "VolumeText"
	volumeText.Text = "Volume"
	volumeText.Size = UDim2.new(0,224,0,18)
	volumeText.Position = UDim2.new(0,31,0,volumeTop + 6)
	volumeText.TextXAlignment = Enum.TextXAlignment.Left
	volumeText.Font = Enum.Font.SourceSansBold
	volumeText.FontSize = Enum.FontSize.Size18
	volumeText.TextColor3 = Color3.new(1,1,1)
	volumeText.ZIndex = baseZIndex + 4
	volumeText.BackgroundTransparency = 1
	volumeText.Parent = gameSettingsMenuFrame

	local volumeSlider, volumeLevel = RbxGui.CreateSliderNew(maxVolumeLevel, 200, UDim2.new(0, 270, 0, volumeTop + 10))
	for _, part in pairs(volumeSlider:GetDescendants()) do
		if part:IsA("GuiObject") then part.ZIndex = baseZIndex + 4 end
	end
	volumeSlider.Bar.Slider.ZIndex = baseZIndex + 5
	volumeSlider.Parent = gameSettingsMenuFrame

	local masterVolume = 1
	pcall(function() masterVolume = UserSettings().GameSettings.MasterVolume end)
	volumeLevel.Value = math.min(math.max(math.floor((masterVolume * (maxVolumeLevel - 1)) + 1.5), 1), maxVolumeLevel)
	volumeLevel.Changed:connect(function()
		pcall(function() UserSettings().GameSettings.MasterVolume = (volumeLevel.Value - 1) / (maxVolumeLevel - 1) end)
	end)

	local backButton
	if hasGraphicsSlider then
		backButton = createTextButton("OK",Enum.ButtonStyle.RobloxRoundDefaultButton,Enum.FontSize.Size24,UDim2.new(0,180,0,50),UDim2.new(0,170,0,365))]] },
		{ "goToMenu(settingsFrame,\"GameSettingsMenu\",\"left\",UDim2.new(0,525,0,350))",
			"goToMenu(settingsFrame,\"GameSettingsMenu\",\"left\",UDim2.new(0,525,0,hasGraphicsSlider and 400 or 350))" },
	}

	local function find(obj, ...)
		for _, name in ipairs({ ... }) do
			obj = obj and obj:FindFirstChild(name)
		end
		return obj
	end

	local function replaceOnce(text, old, new)
		local a, b = string.find(text, old, 1, true)
		if not a or string.find(text, old, b + 1, true) then return nil end
		return string.sub(text, 1, a - 1) .. new .. string.sub(text, b + 1)
	end

	-- run a 2015 script in place of a 2014 one (or the 2014 script itself),
	-- with the changes made; nothing happens if Legacy changed any of those lines
	local function swap(script2014, script2015, changes)
		local header = script2014 and string.match(script2014.Source, HEADER)
		local header2015 = script2015 and string.match(script2015.Source, HEADER)
		if not (header and header2015) then return false end
		local body = string.sub(script2015.Source, #header2015 + 1)
		for _, change in ipairs(changes) do
			body = replaceOnce(body, change[1], change[2])
			if not body then return false end
		end
		script2014.Source = header .. body
		return true
	end

	local function fixGui(gui)
		keepBackpackOn(gui)
		hideCustomInventories()
		fixMenus(gui)
	end

	local env = getgenv()
	local previous = env.Suite
	local suite = previous or loadstring(game:HttpGet(SUITE_URL))()
	env.Suite = setmetatable({
		launch = function(path, options)
			if type(path) ~= "string" or not string.find(path, "Legacy", 1, true) then
				return suite.launch(path, options)
			end
			env.Suite = previous -- only this launch gets the swap
			options = options or {}
			options.debug = true
			local legacy = suite.launch(path, options)
			local ok, err = pcall(function()
				local gui = find(legacy, "Core", "2014", "NewRobloxGui")
				local modules = find(legacy, "Core", "2015", "NewRobloxGui", "Modules")
				if not swap(find(gui, "BackpackLoader"), find(modules, "BackpackScript"), BACKPACK_CHANGES) then
					warn("[Early 2015] Couldn't swap in the 2015 backpack (Legacy changed), using the 2014 one.")
					return
				end
				if not swap(find(gui, "ChatScript"), find(modules, "Chat"), CHAT_CHANGES) then
					warn("[Early 2015] Couldn't swap in the 2015 chat (Legacy changed), using the 2014 one.")
				end
				local settingsScript = find(gui, "Settings")
				if not swap(settingsScript, settingsScript, SETTINGS_CHANGES) then
					warn("[Early 2015] Couldn't add the volume slider (Legacy changed).")
				end
				-- the 2016 leaderboard needs two 2016 modules, and PlayerDropDown
				-- looks up Modules.Settings.SettingsHub when it loads (the 2016
				-- settings menu itself isn't brought over)
				local modules2016 = find(legacy, "Core", "2016", "NewRobloxGui", "Modules")
				local tenFoot, dropDown = find(modules2016, "TenFootInterface"), find(modules2016, "PlayerDropDown")
				if tenFoot and dropDown and swap(find(gui, "PlayerListScript"), find(modules2016, "PlayerlistModule"), LEADERBOARD_CHANGES) then
					local folder = Instance.new("Folder")
					folder.Name = "Modules"
					folder.Parent = gui
					tenFoot.Parent = folder
					dropDown.Parent = folder
					local settingsFolder = Instance.new("Folder")
					settingsFolder.Name = "Settings"
					settingsFolder.Parent = folder
					local hub = Instance.new("ModuleScript")
					hub.Name = "SettingsHub"
					hub.Parent = settingsFolder
				else
					warn("[Early 2015] Couldn't swap in the leaderboard (Legacy changed), using the 2014 one.")
				end
				fixGui(gui)
				print("[Early 2015] 2015 backpack and chat, early 2015 leaderboard, volume added, menus fixed.")
			end)
			if not ok then warn("[Early 2015] " .. tostring(err)) end
			return legacy
		end,
	}, { __index = suite })
end

------------------------------------------------------------
-- LOAD THE 2014 BASE (loading screen, Leave Game button, Legacy)
------------------------------------------------------------
do
	-- a GUI picked earlier can leave its year here, and the base would
	-- load that year instead of its own (2014)
	local settings = getgenv().LegacySettings
	if settings and settings.Year ~= 2014 then
		getgenv().LegacySettings = nil
	end

	-- the base draws 2012 bubbles; draw early 2015's instead: see-through
	-- white, small round corners, dark gray SourceSans text, a small tail
	local BUBBLE_2015 = [[
local function createClassicBubble(head, messageText)
	if not head or not head:IsA("BasePart") then return end

	for _, child in ipairs(head:GetChildren()) do
		if child.Name == "ClassicBubbleGui" then
			child:Destroy()
		end
	end

	local FILL = 0.3 -- see-through
	local TAIL_W, TAIL_H = 25, 10
	local textSize = TextService:GetTextSize(messageText, 22, Enum.Font.SourceSans, Vector2.new(220, 1000))
	local width = math.max(textSize.X + 50, 70)
	local height = textSize.Y + 28
	local smallWidth, smallHeight = 46, 35

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ClassicBubbleGui"
	billboard.Adornee = head
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.SizeOffset = Vector2.new(0, 0.5)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = MAX_VISIBILITY_DISTANCE

	local body = Instance.new("Frame")
	body.Name = "BubbleBody"
	body.BackgroundColor3 = Color3.new(1, 1, 1)
	body.BackgroundTransparency = FILL
	body.BorderSizePixel = 0
	body.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = body

	local tail = Instance.new("ImageLabel")
	tail.Name = "BubbleTail"
	tail.BackgroundTransparency = 1
	tail.Image = "rbxassetid://89395716827984"
	tail.ImageTransparency = FILL
	tail.Size = UDim2.new(0, TAIL_W, 0, TAIL_H)
	tail.Parent = billboard

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.SourceSans
	label.TextSize = 22
	label.TextColor3 = Color3.fromRGB(60, 68, 75)
	label.TextWrapped = true
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Parent = body

	local function layout(w, h, text)
		billboard.Size = UDim2.new(0, w, 0, h + TAIL_H)
		body.Size = UDim2.new(1, 0, 0, h)
		tail.Position = UDim2.new(0.5, -TAIL_W / 2, 0, h)
		label.Text = text
	end
	layout(width, height, messageText)
	billboard.Parent = head

	-- far away it shrinks to "...", like the base's bubbles
	local far = false
	local renderConnection
	renderConnection = RunService.RenderStepped:Connect(function()
		if not billboard.Parent or not workspace.CurrentCamera then
			renderConnection:Disconnect()
			return
		end
		local nowFar = (workspace.CurrentCamera.CFrame.Position - head.Position).Magnitude > ZOOM_THRESHOLD
		if nowFar ~= far then
			far = nowFar
			if far then
				layout(smallWidth, smallHeight, "...")
			else
				layout(width, height, messageText)
			end
		end
	end)

	task.delay(BUBBLE_LIFETIME, function()
		renderConnection:Disconnect()
		if billboard.Parent then
			billboard:Destroy()
		end
	end)
end
]]

	local base = game:HttpGet("https://pastebin.com/raw/h5AEhK7N")
	local a = string.find(base, "local function createClassicBubble(head, messageText)", 1, true)
	local b = string.find(base, "\nlocal function handleBubbleSpawn(player, text)", 1, true)
	if a and b and a < b then
		base = string.sub(base, 1, a - 1) .. BUBBLE_2015 .. string.sub(base, b)
	else
		warn("[Early 2015] Couldn't swap in the 2015 chat bubbles, using the base's.")
	end
	loadstring(base)()
end
