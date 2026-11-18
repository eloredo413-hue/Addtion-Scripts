--========================================================
-- CLASSIC NOTIFICATIONS (Addtion-Scripts)
-- The 2013-2014 Roblox notifications, drawn on your screen:
--   * Badge Awarded: when you win a badge in the game, a box slides in from the right with the badge's picture and
--     the game's message (BadgeService.BadgeAwarded).
--   * Friend requests: "<name> sent you a friend request" with Accept and Decline (Player.FriendStatusChanged).
--     Accept and Decline answer the request. When you become friends: "You are now friends with <name>".
-- They stack at the right edge above the jump button (newest at the bottom), up to four at once, and slide out
-- after a few seconds (a friend request stays longer). Nothing is changed in the game.
--
-- The loader starts it with the 2014 GUI, and with the 2013 and 2013 mobile GUIs when the old health bar is off.
-- Run alone: this file starts it. Switch off: getgenv().ClassicNotificationsStop()
-- getgenv().ClassicNotifications: Start(), Stop(), Running(), Notify(title, text, image), Test()
--========================================================

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local CoreGui = game:GetService("CoreGui")

local genv = (getgenv and getgenv()) or _G

-- an earlier run (this file run again) is stopped first: one set of notifications at a time
if type(genv.ClassicNotifications) == "table" and type(genv.ClassicNotifications.Stop) == "function" then
	pcall(genv.ClassicNotifications.Stop)
end

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
	task.wait()
	LocalPlayer = Players.LocalPlayer
end

local Settings = {
	Lifetime       = 5,    -- seconds a badge / info notification stays
	FriendLifetime = 14,   -- seconds a friend request stays (until you answer it)
	MaxShown       = 4,    -- most at once: the oldest slides out first
	Width          = 264,  -- notification width in pixels
	BottomOffset   = 130,  -- pixels from the bottom edge: clear of the jump button and backpack
	SideOffset     = 8,    -- pixels from the right edge
	Gap            = 6,    -- pixels between notifications
	SlideTime      = 0.3,
}

local GUI_NAME = "ClassicNotifications"
local running = false
local gui, holder = nil, nil
local conns = {}
local active = {}          -- notifications on screen, oldest first
local friendNotes = {}     -- userId -> its friend request notification
local lastStatus = {}      -- userId -> the last friend status seen
local nextOrder = 0

local function track(c) conns[#conns + 1] = c return c end

local function guiHolder()
	local h = CoreGui
	pcall(function()
		if gethui then h = gethui() end
	end)
	return h
end

----------------------------------------------------------------------------------------------------
-- one notification
----------------------------------------------------------------------------------------------------
local TITLE_FONT = Enum.Font.SourceSansBold
local BODY_FONT = Enum.Font.SourceSans

local function dismiss(note)
	if note.gone then return end
	note.gone = true
	local index = table.find(active, note)
	if index then table.remove(active, index) end
	if note.userId and friendNotes[note.userId] == note then friendNotes[note.userId] = nil end
	local slot, inner = note.slot, note.inner
	local function remove()
		pcall(function() slot:Destroy() end)
	end
	if inner and inner.Parent then
		local ok = pcall(function()
			inner:TweenPosition(UDim2.new(0, Settings.Width + Settings.SideOffset + 20, 0, 0),
				Enum.EasingDirection.In, Enum.EasingStyle.Quad, Settings.SlideTime, true, remove)
		end)
		if not ok then remove() end
	else
		remove()
	end
end

-- opts: userId (friend request / friends), buttons = { {text, color, onClick}, ... }, lifetime
local function notify(title, text, image, opts)
	if not running or not holder then return nil end
	opts = opts or {}
	local width = Settings.Width
	local textX = image and 68 or 12
	local bodyWidth = width - textX - 10
	local bodySize = TextService:GetTextSize(tostring(text or ""), 16, BODY_FONT, Vector2.new(bodyWidth, 1000))
	local buttons = opts.buttons
	local height = math.max(image and 68 or 0, 34 + bodySize.Y + 10 + (buttons and 34 or 0))

	nextOrder = nextOrder + 1
	local slot = Instance.new("Frame")
	slot.Name = "Slot"
	slot.BackgroundTransparency = 1
	slot.Size = UDim2.new(0, width, 0, height)
	slot.LayoutOrder = nextOrder

	local inner = Instance.new("Frame")
	inner.Name = "Notification"
	inner.Size = UDim2.new(1, 0, 1, 0)
	inner.Position = UDim2.new(0, width + Settings.SideOffset + 20, 0, 0)
	inner.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
	inner.BackgroundTransparency = 0.2
	inner.BorderSizePixel = 0
	inner.Parent = slot
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = inner
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 120, 120)
	stroke.Transparency = 0.35
	stroke.Thickness = 1
	stroke.Parent = inner

	if image then
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.new(0, 48, 0, 48)
		icon.Position = UDim2.new(0, 10, 0, 10)
		icon.Image = image
		icon.Parent = inner
	end

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.new(0, textX, 0, 8)
	titleLabel.Size = UDim2.new(0, bodyWidth, 0, 22)
	titleLabel.Font = TITLE_FONT
	titleLabel.TextSize = 19
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = tostring(title or "")
	titleLabel.Parent = inner

	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.Name = "Text"
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.Position = UDim2.new(0, textX, 0, 31)
	bodyLabel.Size = UDim2.new(0, bodyWidth, 0, bodySize.Y)
	bodyLabel.Font = BODY_FONT
	bodyLabel.TextSize = 16
	bodyLabel.TextColor3 = Color3.fromRGB(205, 205, 205)
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.TextWrapped = true
	bodyLabel.Text = tostring(text or "")
	bodyLabel.Parent = inner

	local note = { slot = slot, inner = inner, userId = opts.userId, gone = false, title = title, text = text }

	if buttons then
		local count = #buttons
		local gap = 6
		local buttonWidth = (width - 20 - gap * (count - 1)) / count
		for i, spec in ipairs(buttons) do
			local b = Instance.new("TextButton")
			b.Name = spec.name or ("Button" .. i)
			b.Position = UDim2.new(0, 10 + (i - 1) * (buttonWidth + gap), 1, -34)
			b.Size = UDim2.new(0, buttonWidth, 0, 26)
			b.BackgroundColor3 = spec.color or Color3.fromRGB(70, 70, 70)
			b.BorderSizePixel = 0
			b.AutoButtonColor = true
			b.Font = TITLE_FONT
			b.TextSize = 16
			b.TextColor3 = Color3.fromRGB(255, 255, 255)
			b.Text = spec.text
			b.Parent = inner
			b.MouseButton1Click:Connect(function()
				if note.gone then return end
				local ok, err = pcall(spec.onClick, note)
				if not ok then warn("[Classic Notifications] " .. tostring(spec.text) .. " failed: " .. tostring(err)) end
				dismiss(note)
			end)
		end
	end

	-- too many: the oldest slides out first
	while #active >= Settings.MaxShown do dismiss(active[1]) end
	table.insert(active, note)
	slot.Parent = holder
	pcall(function()
		inner:TweenPosition(UDim2.new(0, 0, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, Settings.SlideTime, true)
	end)
	task.delay(opts.lifetime or Settings.Lifetime, function() dismiss(note) end)
	return note
end

----------------------------------------------------------------------------------------------------
-- badges and friends
----------------------------------------------------------------------------------------------------
local function headshot(userId)
	return "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=100&h=100"
end

local function friendRequest(player)
	if friendNotes[player.UserId] then return end
	friendNotes[player.UserId] = true -- (set again to the notification below)
	local note = notify("Friend Request", player.Name .. " sent you a friend request.", headshot(player.UserId), {
		userId = player.UserId,
		lifetime = Settings.FriendLifetime,
		buttons = {
			{ name = "Accept", text = "Accept", color = Color3.fromRGB(0, 140, 40), onClick = function()
				LocalPlayer:RequestFriendship(player) -- (answering an incoming request accepts it)
			end },
			{ name = "Decline", text = "Decline", color = Color3.fromRGB(95, 95, 95), onClick = function()
				LocalPlayer:RevokeFriendship(player)
			end },
		},
	})
	friendNotes[player.UserId] = note
end

local function onFriendStatus(player, status)
	if not running or not player then return end
	local before = lastStatus[player.UserId]
	lastStatus[player.UserId] = status
	if status == Enum.FriendStatus.FriendRequestReceived then
		friendRequest(player)
	else
		-- the request was answered (here or on the website): its notification goes
		local pending = friendNotes[player.UserId]
		if type(pending) == "table" then dismiss(pending) end
		if status == Enum.FriendStatus.Friend and before ~= Enum.FriendStatus.Friend then
			notify("Friends", "You are now friends with " .. player.Name .. ".", headshot(player.UserId))
		end
	end
end

local function onBadge(message, userId, badgeId)
	if not running or userId ~= LocalPlayer.UserId then return end
	notify("Badge Awarded", tostring(message or "You earned a badge!"),
		badgeId and ("rbxthumb://type=BadgeIcon&id=" .. tostring(badgeId) .. "&w=150&h=150") or nil)
end

----------------------------------------------------------------------------------------------------
-- on and off
----------------------------------------------------------------------------------------------------
local api = {}

function api.Stop()
	if not running then return end
	running = false
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	conns = {}
	pcall(function() gui:Destroy() end)
	gui, holder = nil, nil
	active, friendNotes, lastStatus = {}, {}, {}
	if genv.ClassicNotificationsStop == api.Stop then genv.ClassicNotificationsStop = nil end
	print("[Classic Notifications] off.")
end

function api.Start()
	if running then return end
	running = true
	gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 900
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global

	holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(1, 1)
	holder.Position = UDim2.new(1, -Settings.SideOffset, 1, -Settings.BottomOffset)
	holder.Size = UDim2.new(0, Settings.Width, 0, 600)
	holder.Parent = gui
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.Padding = UDim.new(0, Settings.Gap)
	list.Parent = holder
	gui.Parent = guiHolder()

	local okBadge, badgeErr = pcall(function()
		local BadgeService = game:GetService("BadgeService")
		track(BadgeService.BadgeAwarded:Connect(onBadge))
	end)
	if not okBadge then warn("[Classic Notifications] badge notifications unavailable here: " .. tostring(badgeErr)) end
	local okFriend, friendErr = pcall(function()
		track(LocalPlayer.FriendStatusChanged:Connect(onFriendStatus))
	end)
	if not okFriend then warn("[Classic Notifications] friend notifications unavailable here: " .. tostring(friendErr)) end

	genv.ClassicNotificationsStop = api.Stop
	print("[Classic Notifications] on.")
end

function api.Running()
	return running
end

function api.Notify(title, text, image)
	return notify(title, text, image)
end

-- shows one of each, to see how they look
function api.Test()
	if not running then return end
	notify("Badge Awarded", "Welcome to the game! You earned the Welcome badge.", nil)
	notify("Friend Request", "Builderman sent you a friend request.", "rbxthumb://type=AvatarHeadShot&id=156&w=100&h=100", {
		lifetime = Settings.FriendLifetime,
		buttons = {
			{ name = "Accept", text = "Accept", color = Color3.fromRGB(0, 140, 40), onClick = function() end },
			{ name = "Decline", text = "Decline", color = Color3.fromRGB(95, 95, 95), onClick = function() end },
		},
	})
end

genv.ClassicNotifications = api
api.Start()
