--========================================================
-- CLASSIC NOTIFICATIONS (Addtion-Scripts)
-- The 2013-2014 Roblox notifications, as in the 2014 gameplay video:
--   * A small dark box slides in at the bottom right edge: the picture on the left, a bold title and a line under it
--     ("Friend Request" / "From <name>"), and a small circled x to close it. It slides out after a few seconds.
--   * Friend requests: tap the box and a dark box opens in the middle of the screen, "Accept Friend Request from
--     <name>?", with Accept and Decline (Player.FriendStatusChanged; they answer the request). When you become
--     friends: "You are now friends with <name>".
--   * Badge Awarded: the same small box with the badge's picture and the game's message
--     (BadgeService.BadgeAwarded).
-- Nothing is changed in the game.
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
	Width          = 200,  -- small box width in pixels
	BottomOffset   = 130,  -- pixels from the bottom edge: clear of the jump button and backpack
	SideOffset     = 4,    -- pixels from the right edge
	Gap            = 6,    -- pixels between notifications
	AskWidth       = 270,  -- the middle box: width in pixels
	AskHeight      = 290,  -- ...and height
	StartupNotice  = true, -- a short box when it starts, saying which events it could connect to (set
	                       -- getgenv().ClassicNotificationsQuiet = true before running to leave it out)
	SlideTime      = 0.3,
}

local GUI_NAME = "ClassicNotifications"
local running = false
local gui, holder = nil, nil
local ask = nil            -- the Accept / Decline box in the middle: { frame, userId }
local sources = {}         -- which events could be connected: badges, requests, friended
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
local TITLE_FONT = Enum.Font.ArialBold
local BODY_FONT = Enum.Font.Arial

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

-- opts: userId (friend request), lifetime, onClick (a tap on the box; the box goes after it)
local function notify(title, text, image, opts)
	if not running or not holder then return nil end
	opts = opts or {}
	local width = Settings.Width
	local textX = image and 52 or 12
	local bodyWidth = width - textX - 22
	local bodySize = TextService:GetTextSize(tostring(text or ""), 12, BODY_FONT, Vector2.new(bodyWidth, 1000))
	local height = math.max(64, 34 + bodySize.Y + 12)

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
	inner.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
	inner.BackgroundTransparency = 0.2
	inner.BorderSizePixel = 0
	inner.Parent = slot
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = inner

	if image then
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.new(0, 36, 0, 36)
		icon.Position = UDim2.new(0, 8, 0.5, -18)
		icon.Image = image
		icon.Parent = inner
	end

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.new(0, textX, 0, 10)
	titleLabel.Size = UDim2.new(0, bodyWidth, 0, 18)
	titleLabel.Font = TITLE_FONT
	titleLabel.TextSize = 14
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.Text = tostring(title or "")
	titleLabel.Parent = inner

	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.Name = "Text"
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.Position = UDim2.new(0, textX, 0, 30)
	bodyLabel.Size = UDim2.new(0, bodyWidth, 0, bodySize.Y)
	bodyLabel.Font = BODY_FONT
	bodyLabel.TextSize = 12
	bodyLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.TextWrapped = true
	bodyLabel.Text = tostring(text or "")
	bodyLabel.Parent = inner

	local note = { slot = slot, inner = inner, userId = opts.userId, gone = false, title = title, text = text }

	-- a tap anywhere on the box
	local tap = Instance.new("TextButton")
	tap.Name = "Tap"
	tap.BackgroundTransparency = 1
	tap.Size = UDim2.new(1, 0, 1, 0)
	tap.Text = ""
	tap.AutoButtonColor = false
	tap.Parent = inner
	tap.MouseButton1Click:Connect(function()
		if note.gone then return end
		if opts.onClick then
			local ok, err = pcall(opts.onClick, note)
			if not ok then warn("[Classic Notifications] " .. tostring(err)) end
		end
		dismiss(note)
	end)

	-- the small circled x in the corner
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.BackgroundTransparency = 1
	close.Size = UDim2.new(0, 16, 0, 16)
	close.Position = UDim2.new(1, -22, 0, 5)
	close.Font = BODY_FONT
	close.TextSize = 13
	close.TextColor3 = Color3.fromRGB(170, 170, 170)
	close.Text = "x"
	close.ZIndex = 2
	close.Parent = inner
	local ring = Instance.new("UICorner")
	ring.CornerRadius = UDim.new(0.5, 0)
	ring.Parent = close
	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = Color3.fromRGB(150, 150, 150)
	ringStroke.Thickness = 1
	ringStroke.Parent = close
	close.MouseButton1Click:Connect(function() dismiss(note) end)

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
-- the Accept / Decline box in the middle of the screen
----------------------------------------------------------------------------------------------------
local function closeAsk()
	if ask then
		pcall(function() ask.frame:Destroy() end)
		ask = nil
	end
end

local function openAsk(question, userId, onAccept, onDecline)
	if not running or not gui then return end
	closeAsk()
	local frame = Instance.new("Frame")
	frame.Name = "AskBox"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.47, 0)
	frame.Size = UDim2.new(0, Settings.AskWidth, 0, Settings.AskHeight)
	frame.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.ZIndex = 5
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Question"
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 14, 0, 62)
	label.Size = UDim2.new(1, -28, 0, 110)
	label.Font = TITLE_FONT
	label.TextSize = 26
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextWrapped = true
	label.Text = question
	label.ZIndex = 6
	label.Parent = frame

	local function button(name, x, handler)
		local b = Instance.new("TextButton")
		b.Name = name
		b.AnchorPoint = Vector2.new(0, 1)
		b.Position = UDim2.new(x, x == 0 and 20 or -20, 1, -8)
		b.Size = UDim2.new(0, 92, 0, 34)
		if x ~= 0 then b.AnchorPoint = Vector2.new(1, 1) end
		b.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		b.BackgroundTransparency = 0.1
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.Font = TITLE_FONT
		b.TextSize = 17
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.Text = name
		b.ZIndex = 6
		b.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Thickness = 1
		stroke.Transparency = 1
		stroke.Parent = b
		b.MouseEnter:Connect(function() stroke.Transparency = 0 end)
		b.MouseLeave:Connect(function() stroke.Transparency = 1 end)
		b.MouseButton1Click:Connect(function()
			if ask and ask.frame == frame then
				local ok, err = pcall(handler)
				if not ok then warn("[Classic Notifications] " .. name .. " failed: " .. tostring(err)) end
				closeAsk()
			end
		end)
		return b
	end
	button("Accept", 0, onAccept)
	button("Decline", 1, onDecline)
	ask = { frame = frame, userId = userId }
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
	local note = notify("Friend Request", "From " .. player.Name, headshot(player.UserId), {
		userId = player.UserId,
		lifetime = Settings.FriendLifetime,
		onClick = function()
			openAsk("Accept Friend Request from " .. player.Name .. "?", player.UserId, function()
				LocalPlayer:RequestFriendship(player) -- (answering an incoming request accepts it)
			end, function()
				LocalPlayer:RevokeFriendship(player)
			end)
		end,
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
		if ask and ask.userId == player.UserId then closeAsk() end
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
	gui, holder, ask = nil, nil, nil
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

	-- the events these come from are Roblox's own (restricted): an executor may or may not be allowed to connect to
	-- them, so each one is tried on its own and the result is shown
	local okBadge, badgeErr = pcall(function()
		local BadgeService = game:GetService("BadgeService")
		track(BadgeService.BadgeAwarded:Connect(onBadge))
	end)
	if not okBadge then warn("[Classic Notifications] badge notifications unavailable here: " .. tostring(badgeErr)) end
	local okFriend, friendErr = pcall(function()
		track(LocalPlayer.FriendStatusChanged:Connect(onFriendStatus))
	end)
	if not okFriend then warn("[Classic Notifications] friend request notifications unavailable here: " .. tostring(friendErr)) end
	-- the "you are now friends" event of Roblox's core scripts: a second way to know a friend was added
	local okFriended = pcall(function()
		local StarterGui = game:GetService("StarterGui")
		local event = StarterGui:GetCore("PlayerFriendedEvent")
		track(event.Event:Connect(function(player)
			if not running or not player then return end
			if lastStatus[player.UserId] ~= Enum.FriendStatus.Friend then
				lastStatus[player.UserId] = Enum.FriendStatus.Friend
				notify("Friends", "You are now friends with " .. tostring(player.Name) .. ".", headshot(player.UserId))
			end
		end))
	end)
	sources = { badges = okBadge, requests = okFriend, friended = okFriended }

	genv.ClassicNotificationsStop = api.Stop
	local function word(ok) return ok and "yes" or "blocked" end
	local report = "Badges: " .. word(sources.badges) .. ". Friend requests: " .. word(sources.requests) .. "."
	print("[Classic Notifications] on. " .. report .. " (getgenv().ClassicNotifications.Test() shows a sample.)")
	if Settings.StartupNotice and genv.ClassicNotificationsQuiet ~= true then
		notify("Notifications on", report, nil, { lifetime = 6 })
	end
end

function api.Running()
	return running
end

-- which events were connected: { badges = bool, requests = bool, friended = bool }
function api.Sources()
	return sources
end

function api.Notify(title, text, image)
	return notify(title, text, image)
end

-- shows one of each, to see how they look
function api.Test()
	if not running then return end
	notify("Badge Awarded", "Welcome to the game! You earned the Welcome badge.", nil)
	notify("Friend Request", "From Builderman", "rbxthumb://type=AvatarHeadShot&id=156&w=100&h=100", {
		lifetime = Settings.FriendLifetime,
		onClick = function()
			openAsk("Accept Friend Request from Builderman?", nil, function() end, function() end)
		end,
	})
end

genv.ClassicNotifications = api
api.Start()
