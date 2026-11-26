--[[
	Interactive Physics (Knowledge Revolution) — Faithful Classic Windows Recreation
	Standalone Client-Side Executor Script (Luau) — Full-Screen Mobile & Desktop

	Updates:
	- Open infinite space by default (no invisible floor/walls; objects fall straight down under gravity)
	- Expanded Help window explaining all tools below Join/Split (Points, Slots, Joints, Springs, Dampers, Forces, etc.)
	- Responsive edge-to-edge UIScale (1/scale) so all menus & toolbar buttons fit cleanly on any mobile screen
	- High-accuracy 16x16 Interactive Physics logo matching the uploaded purple sphere + teal grid + red/yellow arrows
	- Real Cut/Copy/Paste clipboard, tactile push-buttons, draggable scrollbars, hold-to-marquee multi-select
]]

--[[
	(Addtion-Scripts) "1989": this is the Interactive Physics script as an option in the GUI list (unlocked by an Easter egg).
	Changes from the original: it opens in the Windows XP theme, drawn (frames, gradients and pixel art, nothing cut from a
	picture, so it stays sharp): XP window frames and title bars, drawn red / blue window buttons, XP push buttons that glow
	orange under the finger, flat toolbar and palette buttons with no outline until touched, and the colour icons of
	Interactive Physics redrawn as clean pixel art. X closes this window and gives the game its GUI and sounds back, instead
	of shutting Roblox down.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

pcall(function() CoreGui.TopBarApp.TopBarApp.Enabled = false end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)

-- Mute background game sounds & ambient noise
local XPK = {} -- (Addtion-Scripts) everything the XP theme adds lives in this one table: the script is at Luau's 200-locals limit
XPK.vols = setmetatable({}, { __mode = "k" })
XPK.muteConn = nil
local function muteObj(obj)
	if obj:IsA("Sound") or obj:IsA("SoundGroup") then
		pcall(function()
			if XPK.vols[obj] == nil then XPK.vols[obj] = obj.Volume end
			obj.Volume = 0
		end)
	end
end
pcall(function()
	for _, obj in ipairs(game:GetDescendants()) do muteObj(obj) end
	XPK.muteConn = game.DescendantAdded:Connect(muteObj)
end)

local function getSafeGuiParent()
	local ok, hui = pcall(function()
		if type(gethui) == "function" then return gethui() end
		return nil
	end)
	if ok and hui then return hui end
	local okCore = pcall(function() return CoreGui.Name end)
	if okCore then return CoreGui end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local PARENT_GUI = getSafeGuiParent()
local EXISTING = PARENT_GUI:FindFirstChild("InteractivePhysicsGui")
if EXISTING then EXISTING:Destroy() end

local C = {
	WinBg = Color3.fromRGB(192, 192, 192),
	WinLight = Color3.fromRGB(255, 255, 255),
	WinDark = Color3.fromRGB(128, 128, 128),
	WinShadow = Color3.fromRGB(64, 64, 64),
	TrackBg = Color3.fromRGB(224, 224, 224),
	TitleActive = Color3.fromRGB(0, 0, 128),
	TitleGrad = Color3.fromRGB(16, 132, 208),
	TitleText = Color3.fromRGB(255, 255, 255),
	CanvasBg = Color3.fromRGB(255, 255, 255),
	GridDot = Color3.fromRGB(195, 200, 210),
	Text = Color3.fromRGB(0, 0, 0),
	DisabledText = Color3.fromRGB(115, 115, 115),
	VectorVel = Color3.fromRGB(0, 155, 45),
	VectorForce = Color3.fromRGB(205, 35, 35),
	RunGreen = Color3.fromRGB(0, 145, 0),
	StopRed = Color3.fromRGB(185, 0, 0),
	Marquee = Color3.fromRGB(0, 120, 215),
}

local SHAPE_COLORS = {
	Color3.fromRGB(150, 200, 245),
	Color3.fromRGB(245, 240, 150),
	Color3.fromRGB(160, 230, 230),
	Color3.fromRGB(235, 175, 170),
	Color3.fromRGB(180, 230, 175),
}

local UI_FONT = Enum.Font.Arial

local function isPointerBegin(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end
local function isPointerMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end
local function isPointerEnd(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- (Addtion-Scripts) THE WINDOWS XP THEME IS DRAWN (frames, gradients, pixel art), not a picture cut from a screenshot: a
-- scaled picture came out soft, drawn pieces stay sharp at any size. (XPK.sheet stays nil; the code that could show a
-- picture sheet is not used.)
XPK.sheet = nil
XPK.refresh = nil
XPK.flat = {}
local beveledFrames = {}
XPK.buttons = {}
XPK.winKinds = {}
XPK.scrollSet = {}
XPK.titles = {}
local currentThemeMode = "Win95"

-- (Addtion-Scripts) the colour icons of Interactive Physics itself, for the XP theme: each toolbar / palette picture
-- has its colour twin (built when the XP theme is first chosen, so nothing extra is drawn until then)
XPK.icons = {
	Circle = {
		rows = {
		"......aaaa......",
		"....aabaaaaa....",
		"...aaabeeaaaa...",
		"..abbeeedeebba..",
		".abbeeddddeebba.",
		".abbeddddddebba.",
		"cbbbdddddddebbba",
		"cabbdddddddddbaa",
		"cbbbdddddddddbba",
		".abbdddddddebbba",
		".abbbdddddeebba.",
		"..abbbdeedabba..",
		"...ababeeaaaa...",
		"....aabaaaaa....",
		"......aaaa......",
		},
		pal = { a = Color3.fromRGB(84, 82, 44), b = Color3.fromRGB(153, 151, 114), c = Color3.fromRGB(222, 220, 179), d = Color3.fromRGB(244, 242, 167), e = Color3.fromRGB(251, 249, 186) },
	},
	Square = {
		rows = {
		"accccccccccdd.",
		"aaaaaaaaaaaabe",
		"abeddddddacbbe",
		"abedddddddcbbe",
		"abddddddddcbbe",
		"abddddddddcbbe",
		"abddddddddcbbe",
		"abddddddddcbbe",
		"abddddddddcbbe",
		"abddddddddcbbe",
		"abddddddddcbbe",
		"aabbbbbbbbaabe",
		"aaaaaaaaaaaaa.",
		},
		pal = { a = Color3.fromRGB(22, 53, 49), b = Color3.fromRGB(96, 124, 119), c = Color3.fromRGB(143, 167, 161), d = Color3.fromRGB(162, 230, 236), e = Color3.fromRGB(202, 243, 241) },
	},
	Polygon = {
		rows = {
		".................",
		".....aaaaaaaaaaa.",
		"....aadddddddbba.",
		"...aaeeeeeedccb..",
		"..aaeeeeeedccc...",
		".acceeeeeedcc....",
		".aceeeeeeedccc...",
		".aceeeeeeeedca...",
		".aaddddddddddaa..",
		".aaabbbbbbaaaaaa.",
		".aaaaaaaaaaaaaaa.",
		".................",
		},
		pal = { a = Color3.fromRGB(45, 62, 55), b = Color3.fromRGB(84, 106, 101), c = Color3.fromRGB(102, 126, 122), d = Color3.fromRGB(152, 191, 191), e = Color3.fromRGB(160, 223, 229) },
	},
	CurvedPoly = {
		rows = {
		"....ccccc........",
		"...aaaaaaaa......",
		".aaaaadddaaa.....",
		".aaccdddddbba....",
		"abaddddddddbba...",
		"abddddddddddbbaa.",
		"aaddddddddddbba..",
		"abdddddddddddbba.",
		"abbddcccdddddcabe",
		"bbbccbbbbddddcbbe",
		".bbbbbbbbbdddcbbe",
		"..bbbeeebbcdbbbb.",
		"...ee..ecaccbbbb.",
		"........cbbabbb..",
		".........baaa....",
		},
		pal = { a = Color3.fromRGB(90, 70, 37), b = Color3.fromRGB(140, 121, 85), c = Color3.fromRGB(208, 184, 141), d = Color3.fromRGB(243, 202, 134), e = Color3.fromRGB(243, 223, 185) },
	},
	Rect = {
		rows = {
		".................",
		".aaaaaaaaaaaaaaaa",
		".aacccccccccccbba",
		".acdddddddddddcba",
		".acedddddddddecba",
		".acedddddddddecba",
		".acedddddddddecba",
		".aceedddddddeecba",
		".acdddddddddddcba",
		".aacccccccccccbba",
		".aaaaaaaaaaaaaaaa",
		".................",
		},
		pal = { a = Color3.fromRGB(34, 48, 56), b = Color3.fromRGB(69, 84, 92), c = Color3.fromRGB(119, 138, 154), d = Color3.fromRGB(155, 193, 233), e = Color3.fromRGB(163, 200, 236) },
	},
	Anchor = {
		rows = {
		"......ccc.......",
		".....aaacb......",
		"....aaa.abc.....",
		"....aad.cbc.....",
		"....caddcbc.....",
		"....ccbbba......",
		".....bbaa.......",
		"......cac.......",
		"......cac.......",
		"aaaa..cac.caaaa.",
		"aaaa..cac.caaaa.",
		"aaaa..cac..aaaa.",
		"aaaaaaaaaaaaaaa.",
		"...aaaaaaaaa....",
		".....aaaaa......",
		},
		pal = { a = Color3.fromRGB(35, 35, 25), b = Color3.fromRGB(90, 89, 78), c = Color3.fromRGB(192, 191, 179), d = Color3.fromRGB(233, 232, 220) },
	},
	Point = {
		rows = {
		"....cc....",
		"...aaaa...",
		".aaa..aaa.",
		"caa.cc.abc",
		"caa.cc.abc",
		".aa.cc.abc",
		".aaaccaab.",
		"..abbbbb..",
		"...baab...",
		"..........",
		},
		pal = { a = Color3.fromRGB(62, 60, 49), b = Color3.fromRGB(117, 116, 102), c = Color3.fromRGB(194, 192, 179) },
	},
	SqPoint = {
		rows = {
		"adddddddddd",
		".aaaaaaabd.",
		".aaa.eebbd.",
		".aa....dbd.",
		".aa....dbd.",
		".aa....dbd.",
		".aaddddbbd.",
		".aaccccbbd.",
		"eaaaaaaaaa.",
		"ee.........",
		},
		pal = { a = Color3.fromRGB(23, 21, 10), b = Color3.fromRGB(73, 73, 60), c = Color3.fromRGB(140, 138, 124), d = Color3.fromRGB(181, 180, 167), e = Color3.fromRGB(205, 204, 191) },
	},
	HSlot = {
		rows = {
		".aaaaaaaaaaaaaaaaa",
		".ccccccccccccccccc",
		"..ddddddddddddddd.",
		".accdddddddccdccd.",
		".abbbbbbbbbbbbbbba",
		".aaaaaaaaaaaaaaaaa",
		},
		pal = { a = Color3.fromRGB(35, 33, 21), b = Color3.fromRGB(99, 99, 85), c = Color3.fromRGB(171, 170, 157), d = Color3.fromRGB(199, 199, 185) },
	},
	VSlot = {
		rows = {
		"cc..ccc.",
		"cacccbb.",
		"bacccab.",
		"baccaab.",
		"bac.aab.",
		"baccaab.",
		"bac.aab.",
		"baccaab.",
		"baccaab.",
		"baccbab.",
		"baccbab.",
		"baccbab.",
		"baccbab.",
		"baccaab.",
		"baccaab.",
		"baccaab.",
		"aa.ccaa.",
		},
		pal = { a = Color3.fromRGB(42, 40, 28), b = Color3.fromRGB(172, 170, 156), c = Color3.fromRGB(200, 199, 186) },
	},
	CSlot = {
		rows = {
		"adddb............",
		"abbbba...........",
		"aaccbbaa.........",
		"..eeddaaa........",
		"...edddba........",
		"aaabdeebaa.......",
		"ddabbeedaaa......",
		"...bbbeddaa......",
		"....abedeca......",
		"....aaaeecbb.....",
		"....aaaeeebbaaaa.",
		".....abbeedbbbbaa",
		"......abddddeee..",
		"......aaddddeee..",
		".......aaadddddd.",
		".........aaaaaaaa",
		},
		pal = { a = Color3.fromRGB(34, 40, 21), b = Color3.fromRGB(83, 91, 71), c = Color3.fromRGB(135, 142, 122), d = Color3.fromRGB(166, 173, 153), e = Color3.fromRGB(198, 204, 184) },
	},
	Pin = {
		rows = {
		"......dddddd......",
		"....aabbbbbbdd....",
		"...aaaabaaccbbb...",
		"..aaaa.a..cddbbb..",
		".aad.addaaadddbbb.",
		".aad..daaaaddddba.",
		"abddddadddaaddddba",
		"abdddda....abcedba",
		"abddda.....bbcedba",
		"abdddaa....abbedba",
		"abbdddaaaaaaa.dbba",
		".abddddbbbbd..dba.",
		".bbddddddddddbbbb.",
		"..bddddddddddbbb..",
		"...aaddcccddaab...",
		".....aaaaaaaa.....",
		},
		pal = { a = Color3.fromRGB(64, 63, 49), b = Color3.fromRGB(107, 105, 92), c = Color3.fromRGB(147, 145, 132), d = Color3.fromRGB(183, 181, 168), e = Color3.fromRGB(215, 214, 200) },
	},
	RigidJoint = {
		rows = {
		".....dd.....",
		"...aaaaaa...",
		"..aaaaeaaa..",
		"..aacaeebbb.",
		".abccaaeebbd",
		".abecaaaebbd",
		".abeeaacebbd",
		".abbacccbbb.",
		"..aabeecaa..",
		"..aabbbbaa..",
		"....aaaa....",
		},
		pal = { a = Color3.fromRGB(7, 57, 5), b = Color3.fromRGB(62, 108, 56), c = Color3.fromRGB(104, 146, 98), d = Color3.fromRGB(155, 184, 146), e = Color3.fromRGB(153, 203, 148) },
	},
	KeySlot = {
		rows = {
		"eeeeeeeeeee.",
		"daaaaaaaaad.",
		"daaddddaaade",
		"daaaddcbbcde",
		"dadcabccccd.",
		"dadcbbbcccd.",
		"dadcabbcccd.",
		"daaacdbbbcd.",
		"daaccdcbaade",
		"daacbbcbaade",
		"aaaaaaaaaad.",
		},
		pal = { a = Color3.fromRGB(15, 50, 10), b = Color3.fromRGB(31, 104, 30), c = Color3.fromRGB(86, 137, 81), d = Color3.fromRGB(142, 169, 134), e = Color3.fromRGB(178, 211, 170) },
	},
	PinSlot = {
		rows = {
		"..................",
		"........aaaaa.....",
		"......aadddaaa....",
		".aaaaaaaddddaaaaaa",
		".adddcaddccddbbadd",
		".ddddccddaacdcbddd",
		".ddddccddaacdccdd.",
		".accdaaddddddbadda",
		".ddddaaacdddbbaddd",
		"......aaccccaa....",
		"........aaaa......",
		},
		pal = { a = Color3.fromRGB(9, 48, 4), b = Color3.fromRGB(23, 70, 18), c = Color3.fromRGB(68, 114, 62), d = Color3.fromRGB(131, 178, 125) },
	},
	Motor = {
		rows = {
		"............",
		"...aa.daa...",
		"...aaddccd..",
		"...aaddccd..",
		"...aaccacd..",
		"..aaaccaaa..",
		"..aaaddaaaa.",
		".acccccccca.",
		".abdcaacdccd",
		".abdcaacdccd",
		".acccdcccca.",
		"..aaaddccca.",
		"..aaaccaaa..",
		"...aabbaaa..",
		"...aaddca...",
		"...aaddca...",
		"...aa.aaa...",
		},
		pal = { a = Color3.fromRGB(12, 53, 7), b = Color3.fromRGB(40, 87, 34), c = Color3.fromRGB(90, 132, 83), d = Color3.fromRGB(162, 201, 155) },
	},
	Gear = {
		rows = {
		".......aaa.......",
		".......aaa.......",
		"...aaddaaadddd...",
		"...aaabaaabbaaa..",
		"...aaabdddaaaa...",
		"...bbbdddddaba...",
		"..abbddaabddbba..",
		".aaabdbabbadbaaad",
		".aaabdbbbbbdbaaad",
		"..abbddbabbdbba..",
		"...abbddcddaaaa..",
		"...aaaccccbaaa...",
		"...aaaaaaabbaaa..",
		"...ddd.aaadddd...",
		".......aaa.......",
		"........aa.......",
		".................",
		},
		pal = { a = Color3.fromRGB(24, 47, 19), b = Color3.fromRGB(82, 112, 78), c = Color3.fromRGB(120, 160, 116), d = Color3.fromRGB(169, 187, 161) },
	},
	GearPair = {
		rows = {
		"...ba....aaa......",
		"..bbba..ddcdd.....",
		"..abda..dbcbd..ddd",
		"ddcbda..dbcbd..aaa",
		"aacadda.aabccddbaa",
		"aaa..dada..dbbcbba",
		"aa...dadaaddbbcbba",
		"aa...dbaa..dbbccba",
		"aa...dbaadd.baddba",
		"aa...daabbbd...dba",
		"aa...daddbd..d.dba",
		"aadddaaedddddddbba",
		"aabbbbaedabbbbbbaa",
		"aaaaabaeddccaaaaaa",
		"dd...daedbcc....dd",
		".....dabbbdd......",
		".....daaaaad......",
		},
		pal = { a = Color3.fromRGB(50, 50, 38), b = Color3.fromRGB(101, 100, 88), c = Color3.fromRGB(138, 137, 125), d = Color3.fromRGB(185, 184, 173), e = Color3.fromRGB(235, 234, 223) },
	},
	TorSpring = {
		rows = {
		"..........ddda...",
		"..........aaaaa..",
		"..........aaaa...",
		"...........aaa...",
		"....ee.....abbaa.",
		"..aaaba.....bbbee",
		"..aabbba....abbae",
		".aaaccbaa.aaaaa..",
		"eabccccaaabaa....",
		"eabccccbaabaa....",
		".abbcccba.aaaaaa.",
		".aaaaaaa....abbce",
		"..aabba.....bbbce",
		"....ee.....abbaa.",
		"...........aaa...",
		"...........aaa...",
		"..........aaaaa..",
		},
		pal = { a = Color3.fromRGB(69, 79, 58), b = Color3.fromRGB(103, 115, 92), c = Color3.fromRGB(141, 154, 129), d = Color3.fromRGB(177, 188, 166), e = Color3.fromRGB(201, 209, 189) },
	},
	Spring = {
		rows = {
		"..................",
		"...aa....aaa......",
		"..bbaa..ddcdd.....",
		"..abda..dacbd...dd",
		"ddcadaa.dacbd..aaa",
		"aacddccadddccddaaa",
		"aaa..dadad.dccccdd",
		"dd...dada..dccca..",
		".....ddaa..ddccc..",
		"......aa....ddd...",
		"..................",
		},
		pal = { a = Color3.fromRGB(52, 51, 38), b = Color3.fromRGB(97, 95, 83), c = Color3.fromRGB(126, 126, 112), d = Color3.fromRGB(179, 177, 165) },
	},
	TorDamper = {
		rows = {
		".................",
		"............aad..",
		"............abd..",
		"............abd..",
		"............abd..",
		".........dd.abddd",
		".........abbaacca",
		"...aaaa.ebbbaaaca",
		"..baaaccebba...aa",
		".bbcccccbbabaaaba",
		"dbbdcccbbabbaabba",
		"dabdcccba.ddaabdd",
		"dbbccccba...abd..",
		".bbbbbbbb...abd..",
		"..bbaabb....add..",
		"...dddd.....dd...",
		},
		pal = { a = Color3.fromRGB(70, 77, 59), b = Color3.fromRGB(102, 113, 92), c = Color3.fromRGB(133, 152, 124), d = Color3.fromRGB(185, 194, 173), e = Color3.fromRGB(237, 240, 225) },
	},
	Damper = {
		rows = {
		".................",
		".....aaaaa.......",
		"....daaaaa.......",
		"....da..a........",
		"dd..daeda.....dd.",
		"aaaabaedaaaaaaaa.",
		"aaaabaedaaaaaaaa.",
		"aa..daedaaa..aaa.",
		"....daeea........",
		"....daccca.......",
		"....ddccca.......",
		".....ddddd.......",
		},
		pal = { a = Color3.fromRGB(41, 40, 28), b = Color3.fromRGB(84, 82, 69), c = Color3.fromRGB(124, 122, 109), d = Color3.fromRGB(182, 180, 168), e = Color3.fromRGB(236, 235, 222) },
	},
	RotForce = {
		rows = {
		".......ddddda..",
		".....aabbbbace.",
		"....aaabbbbace.",
		"...aaabbaaaaae.",
		"...aabaa.......",
		"..aaaba........",
		"..aaba...baaaa.",
		"..aaba..dbbbbce",
		"..aabba.dabbbce",
		".aaaba..dbbbbce",
		"dbbbbbaedbbbbc.",
		"ddabbaae.bbaa..",
		".dbbbba........",
		"..cccc.........",
		"...ee..........",
		},
		pal = { a = Color3.fromRGB(9, 28, 4), b = Color3.fromRGB(30, 52, 24), c = Color3.fromRGB(79, 97, 71), d = Color3.fromRGB(147, 161, 137), e = Color3.fromRGB(187, 199, 177) },
	},
	Force = {
		rows = {
		".................",
		"......da.........",
		"......daa........",
		"......aabaa......",
		"aaaaaaaabaaa.aaa.",
		"aabbbbbbcbbaaaaaa",
		"abbbbbbacbba.aaa.",
		"aaaaaaaaaaa...a..",
		"......daaa.......",
		"......daa........",
		".......a.........",
		".................",
		},
		pal = { a = Color3.fromRGB(11, 26, 6), b = Color3.fromRGB(30, 51, 24), c = Color3.fromRGB(52, 75, 47), d = Color3.fromRGB(181, 189, 170) },
	},
	Pulley = {
		rows = {
		"........aa.......",
		"......aaaaa......",
		".....aacccaaa....",
		"....abcceebbbb...",
		"....abccceebbc...",
		"...aaeccaadeccc..",
		"...abeecaadeccc..",
		"...bbbeccceccc...",
		"...aaaeeececce...",
		"....aaaeeccace...",
		"...aaccacccccc...",
		"..accccaacccccc..",
		".aacccccccccccca.",
		".aaccccccccccccaa",
		".aaaaaaaaaaaaaaa.",
		".................",
		},
		pal = { a = Color3.fromRGB(38, 70, 30), b = Color3.fromRGB(53, 101, 47), c = Color3.fromRGB(98, 146, 91), d = Color3.fromRGB(154, 184, 145), e = Color3.fromRGB(159, 214, 152) },
	},
	Actuator = {
		rows = {
		"aa.............eaa",
		"aaaaaaaaaaee..eeaa",
		"aaccdddaaaaaaaaaaa",
		"acdddddecaadddddaa",
		"acdddddecaaaaaaaaa",
		"aabbbbbbaaaaaaaaaa",
		"aaaaaaaaaaa....eaa",
		"aa.............eaa",
		},
		pal = { a = Color3.fromRGB(20, 43, 14), b = Color3.fromRGB(57, 85, 50), c = Color3.fromRGB(102, 127, 94), d = Color3.fromRGB(137, 156, 128), e = Color3.fromRGB(187, 215, 180) },
	},
	Rope = {
		rows = {
		".....aaaaa........",
		"....aaaaaaa.......",
		".aaaaa...aaa....aa",
		".aaaa.....aaa.caaa",
		".aaa.......abbccaa",
		".aa........abbbcaa",
		"...........bbbbb..",
		"............baa...",
		},
		pal = { a = Color3.fromRGB(58, 57, 44), b = Color3.fromRGB(109, 107, 94), c = Color3.fromRGB(143, 141, 128) },
	},
	Sep = {
		rows = {
		"....aa.....aad....",
		"....da.....dbd....",
		"aa..da.....dbd..dd",
		"aaaaaa.....dbaaaaa",
		"aaccaa.....dbbaaaa",
		"ddeeda.....dba.aaa",
		"....da.....dbb....",
		"....aa.....ddd....",
		},
		pal = { a = Color3.fromRGB(50, 51, 37), b = Color3.fromRGB(87, 86, 74), c = Color3.fromRGB(139, 138, 124), d = Color3.fromRGB(166, 166, 152), e = Color3.fromRGB(193, 191, 178) },
	},
	Rod = {
		rows = {
		"aa..............aa",
		"aaaaaaaaaaaaaaaaaa",
		"aabbbbbbbbbbbbbaaa",
		"aacccccccccccccaaa",
		"..................",
		},
		pal = { a = Color3.fromRGB(82, 82, 68), b = Color3.fromRGB(114, 113, 99), c = Color3.fromRGB(196, 194, 179) },
	},
	New = {
		rows = {
		"..cccccccc....",
		".aaaaaaaaaa...",
		".abd.....aaa..",
		".abde....aaaa.",
		".abdeee..aaaac",
		".abdeeee....ac",
		".abdeeeee...ac",
		".abdeeeeeeeeac",
		".abdeeeeeeeeac",
		".abdeeeeeeeeac",
		".aa.eeeeeeeeac",
		".aa........eac",
		".aa.........ac",
		".aaaaaaaaaaaac",
		".aaaaaaaaaaaac",
		"..............",
		},
		pal = { a = Color3.fromRGB(43, 43, 38), b = Color3.fromRGB(113, 112, 105), c = Color3.fromRGB(171, 172, 163), d = Color3.fromRGB(223, 223, 217), e = Color3.fromRGB(250, 251, 246) },
	},
	Open = {
		rows = {
		"...........dd....",
		"..........aaaa...",
		".........aa..aaaa",
		"....a.........aaa",
		".daaaa.....eeaaaa",
		"dddeeeaaaaaaa....",
		"dbdeeedddeeba....",
		"dbdeeeeeeeeba....",
		"dbdeeebbbbbaaaaaa",
		"dbdeccbbbbbbbbbaa",
		"dbddcccccccccccca",
		"dbcccccccccccccc.",
		"daacccccccccccc..",
		"daabbbbbbbbccc...",
		".accccccccccc....",
		".eeeeeeeeeee.....",
		},
		pal = { a = Color3.fromRGB(39, 37, 10), b = Color3.fromRGB(75, 73, 18), c = Color3.fromRGB(113, 110, 58), d = Color3.fromRGB(187, 184, 142), e = Color3.fromRGB(231, 229, 191) },
	},
	Save = {
		rows = {
		".eeeeeeeeeeeeeee.",
		".aaaaaaaaaaabbaee",
		".abba.......aaace",
		".abba.......aaace",
		".abba.......acbce",
		".abba.......acbce",
		".abba.......acbce",
		".abbca.....accbce",
		".accccaaaaacccbce",
		".acdcbbbbbbbcbbce",
		".acdcbbbbbbbcbbce",
		".accbaaaaabacbbce",
		".accbaaaaaa.ccbce",
		".accbaaaaaa.acbce",
		".acaaaaaaaaaaaace",
		"..aaaaaaaaaaaaaa.",
		},
		pal = { a = Color3.fromRGB(9, 8, 2), b = Color3.fromRGB(59, 56, 28), c = Color3.fromRGB(82, 79, 48), d = Color3.fromRGB(119, 116, 89), e = Color3.fromRGB(176, 174, 158) },
	},
	Cut = {
		rows = {
		"....d...a...",
		"...dbd.dba..",
		"...dbdedba..",
		"...dbdedba..",
		"...daabbaa..",
		"....dbbba...",
		"....daaaa...",
		".....aaa....",
		".....aaba...",
		"....bbbbaac.",
		"..aabbccccca",
		"..abbbccdeba",
		".dbeecccdebd",
		".dbecccccccd",
		"..accac.aac.",
		"...aa.......",
		},
		pal = { a = Color3.fromRGB(61, 60, 74), b = Color3.fromRGB(93, 93, 101), c = Color3.fromRGB(125, 124, 143), d = Color3.fromRGB(171, 171, 174), e = Color3.fromRGB(224, 222, 226) },
	},
	Copy = {
		rows = {
		".dddddd..........",
		".aaaaaaa.........",
		".a...aaaa........",
		".a....aaaa.......",
		".a.aaaaaaaaaaa...",
		".a..eeebceeecaa..",
		".a.abbbbceeecbaa.",
		".aedddbbcceddbbaa",
		".aecbbbbceddccbaa",
		".aacccbbcebccccca",
		".aaccccbcebbbbcca",
		".aaaaabbcecccccca",
		"......abbdbbbbdca",
		".......abddddddaa",
		".......aaaaaaaaaa",
		".................",
		},
		pal = { a = Color3.fromRGB(29, 29, 33), b = Color3.fromRGB(92, 93, 111), c = Color3.fromRGB(126, 127, 142), d = Color3.fromRGB(173, 173, 187), e = Color3.fromRGB(218, 219, 222) },
	},
	Paste = {
		rows = {
		".....ddddd.......",
		".ddddaadaadddd...",
		"adaaaaaaaaaaadb..",
		"accaaccaaaaaccbd.",
		"accbbeee..aaccbd.",
		"accbaaaaaaaaccbd.",
		"accccccccccccccd.",
		"accccccbbbbbbabd.",
		"accccccbdddddabd.",
		"accccccceeeedccdd",
		"accccccceddddcccd",
		"accccccceccddcccd",
		"acccccccedddddddd",
		"acbbbbbceccccddcd",
		".aaaaabbddddddccd",
		"......aaaaaaaaadd",
		".................",
		},
		pal = { a = Color3.fromRGB(37, 35, 15), b = Color3.fromRGB(69, 68, 65), c = Color3.fromRGB(111, 110, 102), d = Color3.fromRGB(171, 171, 172), e = Color3.fromRGB(224, 223, 224) },
	},
	Print = {
		rows = {
		"......aaaaaaaaaa..",
		".....abbbbbbaaaa..",
		"....eaeeeeee.aca..",
		"....eaeaaaaaaaca..",
		"...ea........aa...",
		"...ea.aaaaaaaaaaa.",
		"..aaa.eeeeeacccaaa",
		".aaaaabbbbbbccccaa",
		"aadddddddddcccccaa",
		"aacccccccccccaccca",
		"aaaaaacccccccbbcca",
		"aa....eeeddeebaaa.",
		"aaaaaacccccccaaaa.",
		"aaabbbbbbbbbaaaaa.",
		".aaddddddddabbaaa.",
		"...aaaaaaaaaaaaa..",
		},
		pal = { a = Color3.fromRGB(32, 31, 23), b = Color3.fromRGB(78, 77, 65), c = Color3.fromRGB(114, 114, 100), d = Color3.fromRGB(151, 150, 137), e = Color3.fromRGB(206, 205, 192) },
	},
	Help = {
		rows = {
		"..dddddd...",
		".ddbbbbba..",
		".adddddaaa.",
		"adddacccdaa",
		"adbaccccdaa",
		"adbaccccaaa",
		".aacccccaa.",
		".ddccddaa..",
		"...acdaa...",
		"...accaa...",
		"...accaa...",
		"...dcbba...",
		"...dcccca..",
		"...acccaa..",
		"...cccbba..",
		"....caab...",
		},
		pal = { a = Color3.fromRGB(26, 24, 1), b = Color3.fromRGB(69, 67, 28), c = Color3.fromRGB(118, 117, 68), d = Color3.fromRGB(171, 169, 125) },
	},
	Select = {
		rows = {
		"............",
		".aa.........",
		".aaa........",
		".aaaa.......",
		".aaaaa......",
		".aaaaaa.....",
		".aaaaaaa....",
		".aaaaaaaa...",
		".aaaaaaaba..",
		".aaaaabbbaa.",
		".aaaaacddaa.",
		".aaccacee...",
		".aaeebba....",
		".aa.ebba....",
		".....abba...",
		"......aba...",
		"......aaa...",
		},
		pal = { a = Color3.fromRGB(1, 0, 0), b = Color3.fromRGB(16, 16, 12), c = Color3.fromRGB(81, 80, 76), d = Color3.fromRGB(126, 125, 121), e = Color3.fromRGB(221, 220, 214) },
	},
	Rotate = {
		rows = {
		"......dddd.......",
		"....aaaaada......",
		"...aaa...aaaa....",
		"...aa......abb...",
		".eaa.......bba...",
		".ee.........ccd..",
		".ad.......ddccd..",
		".dd.......dbbcd..",
		"..e.......daacdda",
		"..e.......daaaaa.",
		"...e......daaaa..",
		"...e......daaa...",
		"..........daa....",
		"......e...da.....",
		".................",
		},
		pal = { a = Color3.fromRGB(31, 30, 19), b = Color3.fromRGB(86, 85, 73), c = Color3.fromRGB(126, 124, 112), d = Color3.fromRGB(166, 164, 152), e = Color3.fromRGB(197, 196, 182) },
	},
	Text = {
		rows = {
		"........bb.......",
		".......bbb.......",
		".......bbbb......",
		"......aaaba......",
		"......aaaaba.....",
		".....aaaabba.....",
		".....aaabbaba....",
		"....abbb.bbba....",
		"....aab..dbaaa...",
		"...abba..dcbaa...",
		"...aabaaaccbaaa..",
		"..aaaaaaaaaaaaa..",
		"..aaa......aaaaa.",
		".aaa........abaa.",
		"aaaaa.......abaaa",
		"aaaaa.......aaaaa",
		},
		pal = { a = Color3.fromRGB(7, 7, 1), b = Color3.fromRGB(36, 35, 26), c = Color3.fromRGB(112, 111, 101), d = Color3.fromRGB(189, 187, 177) },
	},
	ZoomIn = {
		rows = {
		"........bccccc....",
		".......bbbaacbaa..",
		"......bbba..dbabb.",
		"......abb..dddbba.",
		".....aab..aaa.dbba",
		".....ada.aaaa.ddba",
		".....ad.aaaaaaadba",
		".....ad.aaaaaaa.aa",
		".....aacaaaaaaa.aa",
		".....aac..aaa..aaa",
		".....aabbbaaa.bba.",
		".....aabbbb.abbba.",
		"....aaaabbbabbaa..",
		"...aaaa.aaaaaa....",
		"..aaaa............",
		".aaaa.............",
		".aaa..............",
		},
		pal = { a = Color3.fromRGB(10, 14, 25), b = Color3.fromRGB(106, 113, 112), c = Color3.fromRGB(168, 175, 168), d = Color3.fromRGB(199, 207, 206) },
	},
	ZoomOut = {
		rows = {
		"........ddddd.....",
		"......ddaaaaaaa...",
		"......aaa...daa...",
		".....aaa....ddaa..",
		".....aa.......aaa.",
		"....aa.......a.da.",
		"....ad.aaaaaaa.da.",
		"....ad.aaaaaaa.da.",
		"....aa.ddddddd.da.",
		"....abaeee....daa.",
		"....bbbbe....dda..",
		"...aabbbbddddbba..",
		"...aaabaacccaaa...",
		"..aaaaa.aaaaa.....",
		".aaaaa............",
		"aaaaa.............",
		".aa...............",
		"..................",
		},
		pal = { a = Color3.fromRGB(20, 26, 35), b = Color3.fromRGB(70, 79, 80), c = Color3.fromRGB(132, 141, 142), d = Color3.fromRGB(169, 179, 173), e = Color3.fromRGB(219, 227, 226) },
	},
}

XPK.iconByRows = {}
XPK.colour = {}

-- XP toolbar buttons (the toolbar's and the tool palette's) are flat: no outline at all until the finger / mouse is over one
-- (a pale orange fill with an orange edge) or it is the tool in use (the same, a little deeper)
function XPK.flatLook(frame)
	local down, hot = frame:GetAttribute("_XPPressed"), frame:GetAttribute("_XPHot")
	local st = frame:FindFirstChild("_ThemeStroke")
	local uc = frame:FindFirstChild("_ThemeCorner")
	if uc then uc:Destroy() end
	if down or hot then
		frame.BackgroundTransparency = 0
		frame.BackgroundColor3 = down and Color3.fromRGB(254, 222, 160) or Color3.fromRGB(255, 244, 206)
		if not st then st = Instance.new("UIStroke"); st.Name = "_ThemeStroke"; st.Parent = frame end
		st.Thickness = 1; st.Color = Color3.fromRGB(230, 153, 40); st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	else
		frame.BackgroundTransparency = 1
		if st then st:Destroy() end
	end
end
-- the drawn XP push button's edge: navy, orange under the finger / mouse or pressed
function XPK.pushEdge(frame)
	local st = frame:FindFirstChild("_ThemeStroke")
	if st then
		local lit = frame:GetAttribute("_XPPressed") or frame:GetAttribute("_XPHot")
		st.Color = lit and Color3.fromRGB(230, 153, 40) or Color3.fromRGB(0, 60, 116)
		st.Thickness = lit and 2 or 1
	end
end
function XPK.watchHover(frame, update)
	if frame:GetAttribute("_XPWired") then return end
	frame:SetAttribute("_XPWired", true)
	frame.MouseEnter:Connect(function() frame:SetAttribute("_XPHot", true); update(frame) end)
	frame.MouseLeave:Connect(function() frame:SetAttribute("_XPHot", false); update(frame) end)
end

-- a button's words in a label over its picture (a child always draws over its parent's own text)
function XPK.wordsOn(btn, on)
	local ov = btn:FindFirstChild("_XPText")
	if on and btn:IsA("TextButton") then
		if not ov then
			ov = Instance.new("TextLabel")
			ov.Name = "_XPText"; ov.BackgroundTransparency = 1; ov.Size = UDim2.fromScale(1, 1)
			ov.ZIndex = btn.ZIndex + 1; ov.Parent = btn
			local function sync()
				ov.Text = btn.Text; ov.TextColor3 = btn.TextColor3; ov.TextSize = btn.TextSize
				ov.Font = btn.Font; ov.TextXAlignment = btn.TextXAlignment; ov.TextWrapped = btn.TextWrapped
			end
			local conns = {}
			for _, p in ipairs({ "Text", "TextColor3", "TextSize", "Font", "TextXAlignment" }) do
				table.insert(conns, btn:GetPropertyChangedSignal(p):Connect(sync))
			end
			ov.Destroying:Connect(function() for _, c in ipairs(conns) do c:Disconnect() end end)
			sync()
		end
		btn.TextTransparency = 1
	elseif ov then
		ov:Destroy()
		btn.TextTransparency = 0
	end
end

function XPK.faceUpdate(frame)
	local face = frame:FindFirstChild("_XPBtnTex")
	if face then
		face.ImageRectOffset = Vector2.new(frame:GetAttribute("_XPPressed") and 42 or (frame:GetAttribute("_XPHot") and 21 or 0), 52)
	end
end

function XPK.clearButton(frame)
	for _, n in ipairs({ "_XPBtnTex", "_XPBtnGrad" }) do
		local o = frame:FindFirstChild(n); if o then o:Destroy() end
	end
	XPK.wordsOn(frame, false)
	if XPK.buttons[frame] then frame.BackgroundTransparency = 0 end
end

local function styleBevelForTheme(frame, pressed)
	local theme = currentThemeMode
	local edgeNames = { "_BTop", "_BLeft", "_BBot", "_BRight" }
	if theme == "Mac80s" then
		for _, en in ipairs(edgeNames) do
			local ef = frame:FindFirstChild(en); if ef then ef.Visible = false end
		end
		local uc = frame:FindFirstChild("_ThemeCorner"); if uc then uc:Destroy() end
		XPK.clearButton(frame)
		local st = frame:FindFirstChild("_ThemeStroke") or Instance.new("UIStroke")
		st.Name = "_ThemeStroke"; st.Thickness = 1; st.Color = Color3.fromRGB(0, 0, 0); st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = frame
	elseif theme == "WinXP" then
		for _, en in ipairs(edgeNames) do
			local ef = frame:FindFirstChild(en); if ef then ef.Visible = false end
		end
		-- (the window buttons are drawn in applyTheme)
		if XPK.winKinds[frame] then return end
		if XPK.flat[frame] then
			frame:SetAttribute("_XPPressed", pressed and true or false)
			XPK.watchHover(frame, XPK.flatLook)
			XPK.flatLook(frame)
			return
		end
		local isButton = XPK.buttons[frame] == true and frame:IsA("TextButton") and not XPK.scrollSet[frame]
		local uc = frame:FindFirstChild("_ThemeCorner")
		local st = frame:FindFirstChild("_ThemeStroke")
		local xg = frame:FindFirstChild("_XPBtnGrad")
		if isButton and XPK.sheet then
			-- the sheet's push button: normal, under the finger / mouse (orange edge), pressed
			if uc then uc:Destroy() end
			if st then st:Destroy() end
			if xg then xg:Destroy() end
			frame.BackgroundTransparency = 1
			frame:SetAttribute("_XPPressed", pressed and true or false)
			local face = frame:FindFirstChild("_XPBtnTex")
			if not face then
				face = Instance.new("ImageLabel")
				face.Name = "_XPBtnTex"; face.BackgroundTransparency = 1; face.Size = UDim2.fromScale(1, 1)
				face.Image = XPK.sheet; face.ImageRectSize = Vector2.new(20, 23)
				face.ScaleType = Enum.ScaleType.Slice; face.SliceCenter = Rect.new(4, 4, 16, 19)
				face.ZIndex = frame.ZIndex; face.Parent = frame
				if not frame:GetAttribute("_XPWired") then
					frame:SetAttribute("_XPWired", true)
					frame.MouseEnter:Connect(function() frame:SetAttribute("_XPHot", true); XPK.faceUpdate(frame) end)
					frame.MouseLeave:Connect(function() frame:SetAttribute("_XPHot", false); XPK.faceUpdate(frame) end)
				end
			end
			XPK.faceUpdate(frame)
			XPK.wordsOn(frame, true)
		elseif isButton then
			-- (the drawn XP button: white to beige, a navy edge, orange under the finger / mouse)
			uc = uc or Instance.new("UICorner")
			uc.Name = "_ThemeCorner"; uc.CornerRadius = UDim.new(0, 3); uc.Parent = frame
			st = st or Instance.new("UIStroke")
			st.Name = "_ThemeStroke"; st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = frame
			frame.BackgroundTransparency = 0
			frame.BackgroundColor3 = Color3.new(1, 1, 1)
			xg = xg or Instance.new("UIGradient")
			xg.Name = "_XPBtnGrad"; xg.Rotation = 90
			xg.Color = pressed and ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(205, 202, 190)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(236, 235, 229)),
			}) or ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.65, Color3.fromRGB(244, 243, 238)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(214, 208, 197)),
			})
			xg.Parent = frame
			frame:SetAttribute("_XPPressed", pressed and true or false)
			XPK.watchHover(frame, XPK.pushEdge)
			XPK.pushEdge(frame)
		elseif XPK.scrollSet[frame] then
			-- scroll bar thumbs and arrows: periwinkle (the gradient is set in applyTheme)
			uc = uc or Instance.new("UICorner")
			uc.Name = "_ThemeCorner"; uc.CornerRadius = UDim.new(0, 2); uc.Parent = frame
			st = st or Instance.new("UIStroke")
			st.Name = "_ThemeStroke"; st.Thickness = 1
			st.Color = pressed and Color3.fromRGB(70, 100, 190) or Color3.fromRGB(126, 156, 222)
			st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = frame
		else
			-- panels, boxes, swatches: no edge on a raised panel (a toolbar, a bar: Windows 95 drew one), XP's thin edge on a
			-- sunken box or a menu, square corners
			if uc then uc:Destroy() end
			if xg then xg:Destroy() end
			if pressed or string.sub(frame.Name, 1, 5) == "Drop_" then
				st = st or Instance.new("UIStroke")
				st.Name = "_ThemeStroke"; st.Thickness = 1
				st.Color = pressed and Color3.fromRGB(127, 157, 185) or Color3.fromRGB(151, 151, 151)
				st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = frame
			elseif st then
				st:Destroy()
			end
		end
	else
		local uc = frame:FindFirstChild("_ThemeCorner"); if uc then uc:Destroy() end
		local st = frame:FindFirstChild("_ThemeStroke"); if st then st:Destroy() end
		XPK.clearButton(frame)
		local function edge(name, size, pos, col)
			local f = frame:FindFirstChild(name) or Instance.new("Frame")
			f.Name = name; f.BorderSizePixel = 0; f.Size = size; f.Position = pos
			f.BackgroundColor3 = col; f.Visible = true; f.ZIndex = frame.ZIndex + 1; f.Parent = frame
		end
		edge("_BTop", UDim2.new(1, 0, 0, 1), UDim2.new(0, 0, 0, 0), pressed and C.WinShadow or C.WinLight)
		edge("_BLeft", UDim2.new(0, 1, 1, 0), UDim2.new(0, 0, 0, 0), pressed and C.WinShadow or C.WinLight)
		edge("_BBot", UDim2.new(1, 0, 0, 1), UDim2.new(0, 0, 1, -1), pressed and C.WinLight or C.WinShadow)
		edge("_BRight", UDim2.new(0, 1, 1, 0), UDim2.new(1, -1, 0, 0), pressed and C.WinLight or C.WinShadow)
	end
end

local function createBevel(frame, pressed)
	frame.BorderSizePixel = 0
	beveledFrames[frame] = pressed and true or false
	styleBevelForTheme(frame, pressed)
end

local skipThemeBevel = {}
local function bindPushAnimation(btn)
	local isDown = false
	btn.InputBegan:Connect(function(input)
		if isPointerBegin(input) and not isDown then
			isDown = true
			if not skipThemeBevel[btn] then createBevel(btn, true) end
			for _, ch in ipairs(btn:GetChildren()) do
				if ch.Name == "_Sprite" then ch.Position = ch.Position + UDim2.fromOffset(1, 1) end
			end
		end
	end)
	local function release()
		if isDown then
			isDown = false
			if not skipThemeBevel[btn] then createBevel(btn, false) end
			for _, ch in ipairs(btn:GetChildren()) do
				if ch.Name == "_Sprite" then ch.Position = ch.Position - UDim2.fromOffset(1, 1) end
			end
		end
	end
	btn.InputEnded:Connect(function(input) if isPointerEnd(input) then release() end end)
	btn.MouseLeave:Connect(release)
end

local themedChromeFrames = {}
local themedButtons = {}
local function trackChrome(f)
	table.insert(themedChromeFrames, f)
	return f
end

local function makeButton(parent, text, pos, size, zindex, textColor, isBold)
	local btn = Instance.new("TextButton")
	btn.BackgroundColor3 = C.WinBg; btn.BorderSizePixel = 0; btn.Position = pos; btn.Size = size
	table.insert(themedButtons, btn)
	XPK.buttons[btn] = true
	btn.Font = isBold and Enum.Font.ArialBold or UI_FONT
	btn.Text = text; btn.TextColor3 = textColor or C.Text
	btn.TextSize = 12; btn.AutoButtonColor = false; btn.ZIndex = zindex or 5; btn.Parent = parent
	createBevel(btn, false)
	bindPushAnimation(btn)
	return btn
end

local function drawPixelArt(parent, rows, palette, pxSize, offsetX, offsetY, zindex, name)
	local container = Instance.new("Frame")
	container.Name = name or "_Sprite"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromOffset(#rows[1] * pxSize, #rows * pxSize)
	container.Position = UDim2.fromOffset(offsetX or 0, offsetY or 0)
	container.ZIndex = zindex or (parent.ZIndex + 2)
	container.Parent = parent

	for r = 1, #rows do
		local line = rows[r]
		local c = 1
		while c <= #line do
			local ch = line:sub(c, c)
			local col = palette[ch]
			if col then
				local run = 1
				while c + run <= #line and line:sub(c + run, c + run) == ch do run += 1 end
				local px = Instance.new("Frame")
				px.BorderSizePixel = 0; px.BackgroundColor3 = col
				px.Position = UDim2.fromOffset((c - 1) * pxSize, (r - 1) * pxSize)
				px.Size = UDim2.fromOffset(run * pxSize, pxSize)
				px.ZIndex = container.ZIndex; px.Parent = container
				c += run
			else
				c += 1
			end
		end
	end
	local iconId = XPK.iconByRows[rows]
	if iconId and XPK.icons[iconId] and not name then
		-- (Addtion-Scripts) this picture has a colour twin for the XP theme
		local e = { mono = container, id = iconId, parent = parent, ox = offsetX or 0, oy = offsetY or 0, z = container.ZIndex, w = #rows[1], h = #rows }
		table.insert(XPK.colour, e)
	end
	return container
end

function XPK.setIconTheme(e, xp)
	if not e.mono.Parent then return end
	if xp and not e.colour then
		local ic = XPK.icons[e.id]
		local w, h = #ic.rows[1], #ic.rows
		local ox = e.ox + math.floor((e.w - w) / 2)
		local oy = e.oy + math.floor((e.h - h) / 2)
		e.colour = drawPixelArt(e.parent, ic.rows, ic.pal, 1, ox, oy, e.z, "_Sprite")
	end
	if e.colour then e.colour.Visible = xp end
	e.mono.Visible = not xp
end

local function drawLineFrame(parent, name, color, zindex)
	local f = Instance.new("Frame")
	f.Name = name or "Line"; f.BackgroundColor3 = color; f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5); f.ZIndex = zindex or 7; f.Parent = parent
	return f
end

local function updateLine(frame, x1, y1, x2, y2, thickness)
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	frame.Position = UDim2.fromOffset((x1 + x2) * 0.5, (y1 + y2) * 0.5)
	frame.Size = UDim2.fromOffset(math.max(1, len), thickness or 1)
	frame.Rotation = math.deg(math.atan2(dy, dx))
end

--// Main Full-Screen Gui with Edge-to-Edge Responsive UIScale
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "InteractivePhysicsGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end end)
ScreenGui.Parent = PARENT_GUI

local MainWindow = Instance.new("Frame")
MainWindow.Name = "MainWindow"
MainWindow.Size = UDim2.fromScale(1, 1); MainWindow.Position = UDim2.fromScale(0, 0)
trackChrome(MainWindow); MainWindow.BackgroundColor3 = C.WinBg; MainWindow.BorderSizePixel = 0; MainWindow.ZIndex = 1; MainWindow.Parent = ScreenGui

local WindowScale = Instance.new("UIScale")
WindowScale.Scale = 1
WindowScale.Parent = MainWindow

local function updateResponsiveScale()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local s = 1
	if vp.X < 520 then
		s = math.clamp(vp.X / 520, 0.62, 1)
	elseif vp.Y < 340 then
		s = math.clamp(vp.Y / 340, 0.72, 1)
	end
	WindowScale.Scale = s
	MainWindow.Size = UDim2.fromScale(1 / s, 1 / s)
end
updateResponsiveScale()

--// Title Bar with High-Accuracy 16x16 Interactive Physics Logo
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 22); TitleBar.Position = UDim2.fromOffset(0, 0)
TitleBar.BackgroundColor3 = C.TitleActive; TitleBar.BorderSizePixel = 0; TitleBar.ZIndex = 2; TitleBar.Parent = MainWindow


drawPixelArt(TitleBar, {
	".........RRRR...",
	"..KKKKK...RRR...",
	".KWWLLPK.RRRR...",
	"KWWWLLPPKRRR....",
	"KWWLLPRRKRKKKKKK",
	"KWLPPYRRKGGTGTTG",
	"KLPPYPPBKGGGGGGG",
	"KPPPYPBBKGGTGTTG",
	".KPPYBBKGGGGGGGG",
	"..KKYKKGGGGTGTTG",
	"..KGYGGGGGGGGGGG",
	"..KGYGGGGGGTGTTG",
	".KYYYGGGGGGGGGGG",
	"..KKYKKKKKKKKKKK",
	"...KY...........",
	"................",
}, {
	K = Color3.fromRGB(0, 0, 0),
	W = Color3.fromRGB(255, 255, 255),
	L = Color3.fromRGB(195, 160, 230),
	P = Color3.fromRGB(115, 45, 165),
	B = Color3.fromRGB(35, 35, 130),
	R = Color3.fromRGB(240, 15, 15),
	Y = Color3.fromRGB(255, 240, 20),
	G = Color3.fromRGB(195, 195, 195),
	T = Color3.fromRGB(0, 135, 135),
}, 1, 4, 3, 4, "Logo")

local MacPinstripes = Instance.new("Frame")
MacPinstripes.Name = "MacPinstripes"; MacPinstripes.Size = UDim2.fromScale(1, 1)
MacPinstripes.BackgroundColor3 = Color3.fromRGB(255, 255, 255); MacPinstripes.BorderSizePixel = 0
MacPinstripes.Visible = false; MacPinstripes.ZIndex = 2; MacPinstripes.Parent = TitleBar
do
	for py = 3, 18, 2 do
		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.new(1, -8, 0, 1); stripe.Position = UDim2.fromOffset(4, py)
		stripe.BackgroundColor3 = Color3.fromRGB(0, 0, 0); stripe.BorderSizePixel = 0; stripe.ZIndex = 2; stripe.Parent = MacPinstripes
	end
	local MacBottomLine = Instance.new("Frame")
	MacBottomLine.Size = UDim2.new(1, 0, 0, 1); MacBottomLine.Position = UDim2.new(0, 0, 1, -1)
	MacBottomLine.BackgroundColor3 = Color3.fromRGB(0, 0, 0); MacBottomLine.BorderSizePixel = 0; MacBottomLine.ZIndex = 3; MacBottomLine.Parent = MacPinstripes
end

local MacCloseBtn = Instance.new("TextButton")
MacCloseBtn.Name = "MacCloseBtn"; MacCloseBtn.Size = UDim2.fromOffset(11, 11); MacCloseBtn.Position = UDim2.fromOffset(8, 5)
MacCloseBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255); MacCloseBtn.BorderSizePixel = 1; MacCloseBtn.BorderColor3 = Color3.fromRGB(0, 0, 0)
MacCloseBtn.Text = ""; MacCloseBtn.Visible = false; MacCloseBtn.ZIndex = 5; MacCloseBtn.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -90, 1, 0); TitleLabel.Position = UDim2.fromOffset(24, 0)
TitleLabel.BackgroundTransparency = 1; TitleLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.BorderSizePixel = 0; TitleLabel.Font = Enum.Font.ArialBold
TitleLabel.Text = "Interactive Physics - [Untitled1]"
TitleLabel.TextColor3 = C.TitleText; TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left; TitleLabel.ZIndex = 4; TitleLabel.Parent = TitleBar

local WIN_SPRITES = {
	Min = {
		"........", "........", "........", "........",
		"........", "........", ".KKKKKK.", ".KKKKKK.",
	},
	Max = {
		"KKKKKKKK", "KKKKKKKK", "K......K", "K......K",
		"K......K", "K......K", "K......K", "KKKKKKKK",
	},
	Close = {
		"KK....KK", ".KK..KK.", "..KKKK..", "...KK...",
		"...KK...", "..KKKK..", ".KK..KK.", "KK....KK",
	},
}
local winPal = { K = C.Text }

local winWhitePal = { K = Color3.fromRGB(255, 255, 255) }
local MinBtn = makeButton(TitleBar, "", UDim2.new(1, -58, 0, 2), UDim2.fromOffset(18, 18), 4)
drawPixelArt(MinBtn, WIN_SPRITES.Min, winPal, 1, 5, 5, 6, "Glyph95")
drawPixelArt(MinBtn, WIN_SPRITES.Min, winWhitePal, 1, 5, 5, 6, "GlyphXP")
local MaxBtn = makeButton(TitleBar, "", UDim2.new(1, -39, 0, 2), UDim2.fromOffset(18, 18), 4)
drawPixelArt(MaxBtn, WIN_SPRITES.Max, winPal, 1, 5, 5, 6, "Glyph95")
drawPixelArt(MaxBtn, WIN_SPRITES.Max, winWhitePal, 1, 5, 5, 6, "GlyphXP")
local CloseBtn = makeButton(TitleBar, "", UDim2.new(1, -20, 0, 2), UDim2.fromOffset(18, 18), 4)
drawPixelArt(CloseBtn, WIN_SPRITES.Close, winPal, 1, 5, 5, 6, "Glyph95")
drawPixelArt(CloseBtn, WIN_SPRITES.Close, winWhitePal, 1, 5, 5, 6, "GlyphXP")
XPK.winKinds[MinBtn] = "min"; XPK.winKinds[MaxBtn] = "max"; XPK.winKinds[CloseBtn] = "close"
for _, wb in ipairs({ MinBtn, MaxBtn, CloseBtn }) do
	skipThemeBevel[wb] = true
	local g = wb:FindFirstChild("GlyphXP"); if g then g.Visible = false end
end

MinBtn.MouseButton1Click:Connect(function() end)
MaxBtn.MouseButton1Click:Connect(function() end)
local function exitInteractivePhysics()
	-- (Addtion-Scripts) closes this window and gives the game its GUI and sounds back (the original shut Roblox down)
	if XPK.muteConn then pcall(function() XPK.muteConn:Disconnect() end) end
	for obj, vol in pairs(XPK.vols) do pcall(function() obj.Volume = vol end) end
	pcall(function() CoreGui.TopBarApp.TopBarApp.Enabled = true end)
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
	pcall(function() ScreenGui:Destroy() end)
end

CloseBtn.MouseButton1Click:Connect(exitInteractivePhysics)
MacCloseBtn.MouseButton1Click:Connect(exitInteractivePhysics)

--// Classic Menu Bar + Pixel-Art MDI Window Controls
local MenuBar = Instance.new("Frame")
MenuBar.Size = UDim2.new(1, 0, 0, 20); MenuBar.Position = UDim2.fromOffset(0, 22)
trackChrome(MenuBar); MenuBar.BackgroundColor3 = C.WinBg; MenuBar.BorderSizePixel = 0; MenuBar.ZIndex = 20; MenuBar.Parent = MainWindow

local MenuSep = Instance.new("Frame")
MenuSep.Size = UDim2.new(1, 0, 0, 1); MenuSep.Position = UDim2.new(0, 0, 1, -1)
MenuSep.BackgroundColor3 = C.WinDark; MenuSep.BorderSizePixel = 0; MenuSep.ZIndex = 21; MenuSep.Parent = MenuBar

local MacAppleIcon = Instance.new("Frame")
MacAppleIcon.Name = "MacAppleIcon"; MacAppleIcon.Size = UDim2.fromOffset(12, 14); MacAppleIcon.Position = UDim2.fromOffset(4, 3)
MacAppleIcon.BackgroundTransparency = 1; MacAppleIcon.Visible = false; MacAppleIcon.ZIndex = 23; MacAppleIcon.Parent = MenuBar
drawPixelArt(MacAppleIcon, {
	"......KK...", ".....KK....", "..KKKKKKKK.", ".KKKKKKKKKK",
	"KKKKKKKKKK.", "KKKKKKKKK..", "KKKKKKKKK..", "KKKKKKKKKK.",
	"KKKKKKKKKKK", "KKKKKKKKKKK", ".KKKKKKKKK.", "..KKK..KKK.",
}, {
	K = Color3.fromRGB(0, 0, 0),
}, 1, 0, 1, 24, "AppleLogo")

local MacClockLbl = Instance.new("TextLabel")
MacClockLbl.Name = "MacClock"; MacClockLbl.Size = UDim2.fromOffset(58, 18); MacClockLbl.Position = UDim2.new(1, -64, 0, 1)
MacClockLbl.BackgroundTransparency = 1; MacClockLbl.Font = Enum.Font.ArialBold
MacClockLbl.Text = "9:30 AM"; MacClockLbl.TextColor3 = C.Text; MacClockLbl.TextSize = 11
MacClockLbl.Visible = false; MacClockLbl.ZIndex = 23; MacClockLbl.Parent = MenuBar

local mdiMin = makeButton(MenuBar, "", UDim2.new(1, -50, 0, 2), UDim2.fromOffset(15, 16), 22)
drawPixelArt(mdiMin, WIN_SPRITES.Min, winPal, 1, 3, 4, 24)
local mdiMax = makeButton(MenuBar, "", UDim2.new(1, -34, 0, 2), UDim2.fromOffset(15, 16), 22)
drawPixelArt(mdiMax, WIN_SPRITES.Max, winPal, 1, 3, 4, 24)
local mdiCls = makeButton(MenuBar, "", UDim2.new(1, -18, 0, 2), UDim2.fromOffset(15, 16), 22)
drawPixelArt(mdiCls, WIN_SPRITES.Close, winPal, 1, 3, 4, 24)
mdiMin.MouseButton1Click:Connect(function() end)
mdiMax.MouseButton1Click:Connect(function() end)
mdiCls.MouseButton1Click:Connect(exitInteractivePhysics)

--// Top Toolbar
local TopToolbar = Instance.new("Frame")
TopToolbar.Size = UDim2.new(1, 0, 0, 26); TopToolbar.Position = UDim2.fromOffset(0, 42)
trackChrome(TopToolbar); TopToolbar.BackgroundColor3 = C.WinBg; TopToolbar.BorderSizePixel = 0; TopToolbar.ZIndex = 3; TopToolbar.Parent = MainWindow
createBevel(TopToolbar, false)

local tbPal = {
	K = Color3.fromRGB(0, 0, 0),
	W = Color3.fromRGB(255, 255, 255),
	Y = Color3.fromRGB(245, 210, 45),
	T = Color3.fromRGB(185, 135, 55),
	B = Color3.fromRGB(0, 50, 185),
	R = Color3.fromRGB(215, 25, 25),
	G = Color3.fromRGB(0, 165, 0),
	M = Color3.fromRGB(255, 255, 165),
	O = Color3.fromRGB(145, 140, 45),
	U = Color3.fromRGB(105, 100, 30),
	D = Color3.fromRGB(128, 128, 128),
	L = Color3.fromRGB(205, 205, 205),
	C = Color3.fromRGB(190, 228, 248),
}

local tbGroup1 = {
	{ id = "New", rows = {
		"..KKKKKKKKK....", "..KWWWWWWWKK...", "..KWWWWWWWKWK..", "..KWWWWWWWKKKK.",
		"..KWWWWWWWWWWK.", "..KWWWWWWWWWWK.", "..KWWWWWWWWWWK.", "..KWWWWWWWWWWK.",
		"..KWWWWWWWWWWK.", "..KWWWWWWWWWWK.", "..KWWWWWWWWWWK.", "..KWWWWWWWWWWK.",
		"..KKKKKKKKKKKK.", "...............",
	}},
	{ id = "Open", rows = {
		".........KKK..K", "........K...KKK", ".KKK........KKK", "KYMYKKKKKKKKKKK",
		"KMYMYMYMYMYK...", "KYMYMYMYMYMK...", "KMYMYMYMYMYK...", "KYMYKKKKKKKKKKK",
		"KMYKOUOUOUOUOK.", "KYKOUOUOUOUOK..", "KKOUOUOUOUOK...", "KOUOUOUOUOK....",
		"KKKKKKKKKK.....", "...............",
	}},
	{ id = "Save", rows = {
		"KKKKKKKKKKKKKKK", "KOOKLLLLLLLLKOK", "KOOKLLLLLLLLKKK", "KOOKLLLLLLLLKOK",
		"KOOKLLLLLLLLKOK", "KOOKKKKKKKKKKOK", "KOOOOOOOOOOOOOK", "KOOOOOOOOOOOOOK",
		"KOOKKKKKKKKKKOK", "KOOKKKKKKKLLKOK", "KOOKKKKKKKLLKOK", "KOOKKKKKKKLLKOK",
		"KOOKKKKKKKLLKOK", ".KKKKKKKKKKKKKK",
	}},
	{ id = "Cut", rows = {
		"....K.....K....", "....KK...KK....", ".....KK.KK.....", "......KKK......",
		"......KKK......", ".....KK.KK.....", "....K.....K....", "..BBK.....KBB..",
		".B..B.....B..B.", ".B..B.....B..B.", "..BB.......BB..", "...............",
		"...............", "...............",
	}},
	{ id = "Copy", rows = {
		".KKKKKK........", ".KWWWWKK.......", ".KWBBBWKKKKKK..", ".KWWWWKWWWWKK..",
		".KWBBBKWBBBKWK.", ".KWWWWKWWWWWWK.", ".KKKKKKWBBBWK..", "......KWWWWWWK.",
		"......KWBBBWK..", "......KWWWWWWK.", "......KKKKKKKK.", "...............",
		"...............", "...............",
	}},
	{ id = "Paste", rows = {
		"....KKKKK......", "..KKDDDDDKK....", ".KOOKKKKOOOK...", ".KOOKOOOKOK....",
		".KOOKKKKKKKKKK.", ".KOOOKWWWWWWKK.", ".KOOOKWBBBBKWK.", ".KOOOKWWWWWWWK.",
		".KOOOKWBBBBWWK.", ".KKKKKWBBBBWWK.", ".....KWWWWWWWK.", ".....KKKKKKKKK.",
		"...............", "...............",
	}},
	{ id = "Print", rows = {
		"....KKKKKKK....", "....KWWWWWK....", "....KWDDDWK....", "..KKKKKKKKKKK..",
		".KLLCLCLCLCLCK.", ".KLLLLLLLLLGKK.", ".KKKKKKKKKKKKK.", "..KDDDDDDDDDK..",
		"...KKKKKKKKK...", "...............", "...............", "...............",
		"...............", "...............",
	}},
	{ id = "Help", rows = {
		"....KKKKKK.....", "...KKYOYOYKK...", "...KYK..YOYK...", "...KK....YOK...",
		"........YOYK...", ".......YOYK....", "......YOYK.....", "......YOK......",
		"...............", "......YOK......", "......YOK......", "...............",
		"...............", "...............",
	}},
}

for _, it in ipairs(tbGroup1) do XPK.iconByRows[it.rows] = it.id end
local tbBtns = {}
local curTbX = 4
for i, item in ipairs(tbGroup1) do
	if i == 4 or i == 7 then curTbX += 5 end
	local b = makeButton(TopToolbar, "", UDim2.fromOffset(curTbX, 3), UDim2.fromOffset(22, 20), 4)
	drawPixelArt(b, item.rows, tbPal, 1, 3, 3, 6)
	tbBtns[item.id] = b
	curTbX += 22
end

curTbX += 8
local tbGroup2 = {
	{ id = "Select", rows = {
		"....K..........", "....KK.........", "....KKK........", "....KKKK.......",
		"....KKKKK......", "....KKKKKK.....", "....KKKKKKK....", "....KKKKKKKK...",
		"....KKKKK......", "....KK.KK......", "....K...KK.....", "........KK.....",
		".........KK....", "...............",
	}},
	{ id = "Rotate", rows = {
		"...............", "....KKKKK......", "..KK.....KK....", ".K.........K...",
		".K.........K...", ".K........KKK..", ".K.........K...", "..K............",
		"...KK......K...", ".....KKKKK.....", "...............", "...............",
		"...............", "...............",
	}},
	{ id = "Text", rows = {
		"...............", "......KK.......", ".....KKKK......", "....KK..KK.....",
		"....K....K.....", "...KK....KK....", "...KKKKKKKK....", "..KK......KK...",
		"..K........K...", ".KKK......KKK..", "...............", "...............",
		"...............", "...............",
	}},
	{ id = "ZoomIn", rows = {
		".....KKKKKK....", "....KCCCCCCK...", "...KCCCKCCCCK..", "...KCCCKCCCCK..",
		"...KCKKKKKCCK..", "...KCCCKCCCCK..", "...KCCCKCCCCK..", "....KCCCCCCK...",
		"....KKKKKKK....", "...BBB.........", "..BBB..........", ".BBB...........",
		".BB............", "...............",
	}},
	{ id = "ZoomOut", rows = {
		".....KKKKKK....", "....KCCCCCCK...", "...KCCCCCCCCK..", "...KCCCCCCCCK..",
		"...KCKKKKKCCK..", "...KCCCCCCCCK..", "...KCCCCCCCCK..", "....KCCCCCCK...",
		"....KKKKKKK....", "...BBB.........", "..BBB..........", ".BBB...........",
		".BB............", "...............",
	}},
}
for _, it in ipairs(tbGroup2) do XPK.iconByRows[it.rows] = it.id end
for _, item in ipairs(tbGroup2) do
	local b = makeButton(TopToolbar, "", UDim2.fromOffset(curTbX, 3), UDim2.fromOffset(22, 20), 4)
	drawPixelArt(b, item.rows, tbPal, 1, 3, 3, 6)
	tbBtns[item.id] = b
	curTbX += 22
end

curTbX += 8
local RunBtn = makeButton(TopToolbar, "", UDim2.fromOffset(curTbX, 3), UDim2.fromOffset(48, 20), 4)
local runLbl = Instance.new("TextLabel")
runLbl.Name = "_Sprite"; runLbl.Size = UDim2.fromOffset(28, 18); runLbl.Position = UDim2.fromOffset(4, 1)
runLbl.BackgroundTransparency = 1; runLbl.Font = Enum.Font.ArialBold; runLbl.Text = "Run"
runLbl.TextColor3 = C.Text; runLbl.TextSize = 12; runLbl.TextXAlignment = Enum.TextXAlignment.Left; runLbl.ZIndex = 6; runLbl.Parent = RunBtn
drawPixelArt(RunBtn, {
	"G....", "GG...", "GGG..", "GGGG.", "GGGGG", "GGGG.", "GGG..", "GG...", "G....",
}, { G = C.RunGreen }, 1, 34, 5, 6)

local StopBtn = makeButton(TopToolbar, "", UDim2.fromOffset(curTbX + 48, 3), UDim2.fromOffset(50, 20), 4)
local stopLbl = Instance.new("TextLabel")
stopLbl.Name = "_Sprite"; stopLbl.Size = UDim2.fromOffset(30, 18); stopLbl.Position = UDim2.fromOffset(4, 1)
stopLbl.BackgroundTransparency = 1; stopLbl.Font = UI_FONT; stopLbl.Text = "Stop"
stopLbl.TextColor3 = C.Text; stopLbl.TextSize = 12; stopLbl.TextXAlignment = Enum.TextXAlignment.Left; stopLbl.ZIndex = 6; stopLbl.Parent = StopBtn
drawPixelArt(StopBtn, {
	"RR.RR", "RR.RR", "RR.RR", "RR.RR", "RR.RR", "RR.RR", "RR.RR",
}, { R = C.StopRed }, 1, 37, 6, 6)

local ResetBtn = makeButton(TopToolbar, "", UDim2.fromOffset(curTbX + 98, 3), UDim2.fromOffset(44, 20), 4)
local resetLbl = Instance.new("TextLabel")
resetLbl.Name = "_Sprite"; resetLbl.Size = UDim2.fromScale(1, 1); resetLbl.Position = UDim2.fromOffset(0, 0)
resetLbl.BackgroundTransparency = 1; resetLbl.Font = UI_FONT; resetLbl.Text = "Reset"
resetLbl.TextColor3 = C.Text; resetLbl.TextSize = 12; resetLbl.ZIndex = 6; resetLbl.Parent = ResetBtn

--// Left 5-Section Tool Palette
local ToolPalette = Instance.new("ScrollingFrame")
ToolPalette.Size = UDim2.new(0, 56, 1, -72); ToolPalette.Position = UDim2.fromOffset(2, 70)
trackChrome(ToolPalette); ToolPalette.BackgroundColor3 = C.WinBg; ToolPalette.BorderSizePixel = 0
ToolPalette.ScrollBarThickness = 2; ToolPalette.CanvasSize = UDim2.fromOffset(0, 440)
ToolPalette.ZIndex = 3; ToolPalette.Parent = MainWindow
createBevel(ToolPalette, false)

--// Dedicated Late '80s Macintosh Single-Column Tool Strip (matches _resize.jpeg)
local MacToolStrip = Instance.new("Frame")
MacToolStrip.Name = "MacToolStrip"
MacToolStrip.Size = UDim2.new(0, 36, 1, -44); MacToolStrip.Position = UDim2.fromOffset(0, 42)
MacToolStrip.BackgroundColor3 = Color3.fromRGB(255, 255, 255); MacToolStrip.BorderSizePixel = 1
MacToolStrip.BorderColor3 = Color3.fromRGB(0, 0, 0); MacToolStrip.Visible = false; MacToolStrip.ZIndex = 4; MacToolStrip.Parent = MainWindow

local macStripBtns = {}
do
local macY = 2
local function addMacBtn(id, labelText, spriteRows, h)
	local bh = h or 20
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -4, 0, bh); b.Position = UDim2.fromOffset(2, macY)
	b.BackgroundColor3 = Color3.fromRGB(255, 255, 255); b.BorderSizePixel = 1; b.BorderColor3 = Color3.fromRGB(0, 0, 0)
	b.Font = Enum.Font.Arial; b.Text = labelText or ""; b.TextColor3 = Color3.fromRGB(0, 0, 0); b.TextSize = 10
	b.AutoButtonColor = false; b.ZIndex = 5; b.Parent = MacToolStrip
	if spriteRows then
		drawPixelArt(b, spriteRows, { K = Color3.fromRGB(0, 0, 0), W = Color3.fromRGB(255, 255, 255) }, 1, 9, 3, 6, "MacIcon")
	end
	macStripBtns[id] = b
	macY += bh + 2
	return b
end

local macPtrBtn = addMacBtn("Select", nil, {
	".K.........", ".KK........", ".KKK.......", ".KKKK......",
	".KKKKK.....", ".KKKKKK....", ".KKKKKKK...", ".KKKK......",
	".KK.KK.....", ".....KK....",
}, 20)
local macZoomBtn = addMacBtn("ZoomIn", nil, {
	"..KKKK.....", ".K....K....", "K......K...", "K......K...",
	".K....K....", "..KKKKKK...", "......KKK..", ".......KKK.",
}, 18)
local macRunBtn = addMacBtn("MacRun", "Run", nil, 18)
local macResetBtn = addMacBtn("MacReset", "Reset", nil, 18)
macY += 3
addMacBtn("Rect", nil, { "...........", "K.K.K.K.K.K", ".K.......K.", "K.........K", "K.K.K.K.K.K" }, 16)
addMacBtn("Square", nil, { "...........", "..K.K.K.K..", "..K.....K..", "..K.....K..", "..K.....K..", "..K.K.K.K.." }, 16)
addMacBtn("Circle", nil, { "...........", "...K.K.K...", ".K.......K.", "K.........K", ".K.......K.", "...K.K.K..." }, 16)
addMacBtn("CurvedPoly", nil, { "...........", "..K.K.K....", ".K.....K...", "..K...K....", "...K.K....." }, 16)
addMacBtn("Pin", nil, { "...........", "....KKK....", "...K.K.K...", "....KKK...." }, 16)
addMacBtn("Spring", nil, { "...........", ".K..K..K...", "K.KK.KK.K..", "..K..K..K.." }, 16)
addMacBtn("Force", nil, { "....K......", "KKKKKK.KKK.", "....K..K...", ".......KK.." }, 16)
addMacBtn("Anchor", nil, { "....KKK....", ".....K.....", ".K...K...K.", "..KKKKKKK.." }, 16)
addMacBtn("Rotate", nil, { "...K.KK....", "..K....K...", "..K...KKK..", "...KK......" }, 16)

-- MacToolStrip click handlers wired after simulation functions are defined
end

--// Workspace Area
local WorkspaceContainer = Instance.new("Frame")
WorkspaceContainer.Size = UDim2.new(1, -62, 1, -72); WorkspaceContainer.Position = UDim2.fromOffset(60, 70)
trackChrome(WorkspaceContainer); WorkspaceContainer.BackgroundColor3 = C.WinBg; WorkspaceContainer.BorderSizePixel = 0; WorkspaceContainer.ZIndex = 2; WorkspaceContainer.Parent = MainWindow

local Canvas = Instance.new("Frame")
Canvas.Name = "PhysicsCanvas"; Canvas.Size = UDim2.new(1, -16, 1, -36); Canvas.Position = UDim2.fromOffset(0, 0)
Canvas.BackgroundColor3 = C.CanvasBg; Canvas.BorderSizePixel = 0; Canvas.ClipsDescendants = true; Canvas.ZIndex = 3; Canvas.Parent = WorkspaceContainer
createBevel(Canvas, true)

local WorldContainer = Instance.new("Frame")
WorldContainer.Size = UDim2.fromScale(1, 1); WorldContainer.BackgroundTransparency = 1; WorldContainer.ZIndex = 4; WorldContainer.Parent = Canvas
local WorldScale = Instance.new("UIScale"); WorldScale.Scale = 1; WorldScale.Parent = WorldContainer

local GridLayer = Instance.new("Frame"); GridLayer.Size = UDim2.fromScale(1, 1); GridLayer.BackgroundTransparency = 1; GridLayer.Visible = false; GridLayer.ZIndex = 4; GridLayer.Parent = WorldContainer
local TrackLayer = Instance.new("Frame"); TrackLayer.Size = UDim2.fromScale(1, 1); TrackLayer.BackgroundTransparency = 1; TrackLayer.ZIndex = 5; TrackLayer.Parent = WorldContainer
local BodyLayer = Instance.new("Frame"); BodyLayer.Size = UDim2.fromScale(1, 1); BodyLayer.BackgroundTransparency = 1; BodyLayer.ZIndex = 6; BodyLayer.Parent = WorldContainer
local ConstraintLayer = Instance.new("Frame"); ConstraintLayer.Size = UDim2.fromScale(1, 1); ConstraintLayer.BackgroundTransparency = 1; ConstraintLayer.ZIndex = 7; ConstraintLayer.Parent = WorldContainer
local VectorLayer = Instance.new("Frame"); VectorLayer.Size = UDim2.fromScale(1, 1); VectorLayer.BackgroundTransparency = 1; VectorLayer.ZIndex = 8; VectorLayer.Parent = WorldContainer
local PreviewLayer = Instance.new("Frame"); PreviewLayer.Size = UDim2.fromScale(1, 1); PreviewLayer.BackgroundTransparency = 1; PreviewLayer.ZIndex = 9; PreviewLayer.Parent = WorldContainer

local function applyDitherTrack(trackFrame, isVertical)
	trackFrame.BackgroundColor3 = C.WinLight
	local rows = {}
	if isVertical then
		for y = 1, 200 do table.insert(rows, (y % 2 == 1) and "DWDWDWDWDWDWDWDW" or "WDWDWDWDWDWDWDWD") end
	else
		local s1, s2 = string.rep("DW", 150), string.rep("WD", 150)
		for y = 1, 16 do table.insert(rows, (y % 2 == 1) and s1 or s2) end
	end
	drawPixelArt(trackFrame, rows, { D = C.WinBg, W = C.WinLight }, 1, 0, 0, trackFrame.ZIndex, "Dither")
end

local ARROW_SPRITES = {
	Up = { "...K...", "..KKK..", ".KKKKK.", "KKKKKKK" },
	Down = { "KKKKKKK", ".KKKKK.", "..KKK..", "...K..." },
	Left = { "...K", "..KK", ".KKK", "KKKK", ".KKK", "..KK", "...K" },
	Right = { "K...", "KK..", "KKK.", "KKKK", "KKK.", "KK..", "K..." },
	Rew = { "K...K", "K..KK", "K.KKK", "KKKKK", "K.KKK", "K..KK", "K...K" },
}

local VScrollBar = Instance.new("Frame")
VScrollBar.Size = UDim2.new(0, 16, 1, -36); VScrollBar.Position = UDim2.new(1, -16, 0, 0)
VScrollBar.BackgroundColor3 = C.TrackBg; VScrollBar.BorderSizePixel = 0; VScrollBar.ClipsDescendants = true; VScrollBar.ZIndex = 4; VScrollBar.Parent = WorkspaceContainer
applyDitherTrack(VScrollBar, true)
local vUp = makeButton(VScrollBar, "", UDim2.fromOffset(0, 0), UDim2.fromOffset(16, 16), 6)
drawPixelArt(vUp, ARROW_SPRITES.Up, winPal, 1, 4, 6, 8)
local vThumb = makeButton(VScrollBar, "", UDim2.new(0, 0, 0.35, 0), UDim2.fromOffset(16, 32), 6)
local vDn = makeButton(VScrollBar, "", UDim2.new(0, 0, 1, -16), UDim2.fromOffset(16, 16), 6)
drawPixelArt(vDn, ARROW_SPRITES.Down, winPal, 1, 4, 6, 8)

local CoordBar = Instance.new("Frame")
CoordBar.Size = UDim2.new(1, -16, 0, 18); CoordBar.Position = UDim2.new(0, 0, 1, -36)
trackChrome(CoordBar); CoordBar.BackgroundColor3 = C.WinBg; CoordBar.BorderSizePixel = 0; CoordBar.ZIndex = 4; CoordBar.Parent = WorkspaceContainer

local CoordLabels = {}
local function makeCoordField(label, xPos)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromOffset(14, 16); lbl.Position = UDim2.fromOffset(xPos, 1)
	lbl.BackgroundTransparency = 1; lbl.Font = UI_FONT; lbl.Text = label
	lbl.TextColor3 = C.Text; lbl.TextSize = 11; lbl.ZIndex = 5; lbl.Parent = CoordBar

	local box = Instance.new("TextBox")
	box.Size = UDim2.fromOffset(44, 16); box.Position = UDim2.fromOffset(xPos + 15, 1)
	box.BackgroundColor3 = C.WinBg; box.BorderSizePixel = 0; box.Font = UI_FONT
	box.Text = "0.00"; box.TextColor3 = C.Text; box.TextSize = 11; box.ClearTextOnFocus = false
	box.ZIndex = 5; box.Parent = CoordBar
	createBevel(box, true)

	local unit = Instance.new("TextLabel")
	unit.Size = UDim2.fromOffset(14, 16); unit.Position = UDim2.fromOffset(xPos + 61, 1)
	unit.BackgroundTransparency = 1; unit.Font = UI_FONT; unit.Text = "m"
	unit.TextColor3 = C.Text; unit.TextSize = 11; unit.ZIndex = 5; unit.Parent = CoordBar
	return box
end
CoordLabels.x = makeCoordField("x", 4)
CoordLabels.y = makeCoordField("y", 84)

local BottomBar = Instance.new("Frame")
BottomBar.Size = UDim2.new(1, 0, 0, 18); BottomBar.Position = UDim2.new(0, 0, 1, -18)
trackChrome(BottomBar); BottomBar.BackgroundColor3 = C.WinBg; BottomBar.BorderSizePixel = 0; BottomBar.ZIndex = 4; BottomBar.Parent = WorkspaceContainer

local TapeRewindBtn = makeButton(BottomBar, "", UDim2.fromOffset(0, 1), UDim2.fromOffset(18, 16), 5)
drawPixelArt(TapeRewindBtn, ARROW_SPRITES.Rew, winPal, 1, 6, 4, 7)
local TapePlayBtn = makeButton(BottomBar, "", UDim2.fromOffset(19, 1), UDim2.fromOffset(18, 16), 5)
drawPixelArt(TapePlayBtn, ARROW_SPRITES.Right, winPal, 1, 7, 4, 7)

local TapeFrameBox = Instance.new("TextLabel")
TapeFrameBox.Size = UDim2.fromOffset(34, 16); TapeFrameBox.Position = UDim2.fromOffset(38, 1)
TapeFrameBox.BackgroundColor3 = C.CanvasBg; TapeFrameBox.BorderSizePixel = 0; TapeFrameBox.Font = UI_FONT
TapeFrameBox.Text = "0"; TapeFrameBox.TextColor3 = C.Text; TapeFrameBox.TextSize = 11; TapeFrameBox.ZIndex = 5; TapeFrameBox.Parent = BottomBar
createBevel(TapeFrameBox, true)

local ScrubberTrack = Instance.new("Frame")
ScrubberTrack.Size = UDim2.fromOffset(74, 14); ScrubberTrack.Position = UDim2.fromOffset(74, 2)
ScrubberTrack.BackgroundColor3 = C.TrackBg; ScrubberTrack.BorderSizePixel = 0; ScrubberTrack.ZIndex = 5; ScrubberTrack.Parent = BottomBar
createBevel(ScrubberTrack, true)

local ScrubberFill = Instance.new("Frame")
ScrubberFill.Size = UDim2.fromScale(0, 1); ScrubberFill.BackgroundColor3 = C.TitleActive
ScrubberFill.BorderSizePixel = 0; ScrubberFill.ZIndex = 6; ScrubberFill.Parent = ScrubberTrack

local TapeBackBtn = makeButton(BottomBar, "", UDim2.fromOffset(150, 1), UDim2.fromOffset(18, 16), 5)
drawPixelArt(TapeBackBtn, ARROW_SPRITES.Left, winPal, 1, 7, 4, 7)
local TapeStepBtn = makeButton(BottomBar, "", UDim2.fromOffset(169, 1), UDim2.fromOffset(18, 16), 5)
drawPixelArt(TapeStepBtn, ARROW_SPRITES.Right, winPal, 1, 7, 4, 7)

local HScrollBar = Instance.new("Frame")
HScrollBar.Size = UDim2.new(1, -206, 0, 16); HScrollBar.Position = UDim2.fromOffset(190, 1)
HScrollBar.BackgroundColor3 = C.TrackBg; HScrollBar.BorderSizePixel = 0; HScrollBar.ClipsDescendants = true; HScrollBar.ZIndex = 4; HScrollBar.Parent = BottomBar
applyDitherTrack(HScrollBar, false)
local hLeft = makeButton(HScrollBar, "", UDim2.fromOffset(0, 0), UDim2.fromOffset(16, 16), 6)
drawPixelArt(hLeft, ARROW_SPRITES.Left, winPal, 1, 6, 4, 8)
local hThumb = makeButton(HScrollBar, "", UDim2.new(0.45, 0, 0, 0), UDim2.fromOffset(32, 16), 6)
local hRight = makeButton(HScrollBar, "", UDim2.new(1, -16, 0, 0), UDim2.fromOffset(16, 16), 6)
drawPixelArt(hRight, ARROW_SPRITES.Right, winPal, 1, 6, 4, 8)
local CornerGrip = makeButton(BottomBar, "", UDim2.new(1, -16, 0, 1), UDim2.fromOffset(16, 16), 5)

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateResponsiveScale)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
end

--// Working Zoom, Draggable Scrollbar Thumbs & MouseWheel Pan
local panX, panY = 0, 0
local PAN_RANGE = 300
local function applyViewTransform()
	panX = math.clamp(panX, -PAN_RANGE, PAN_RANGE)
	panY = math.clamp(panY, -PAN_RANGE, PAN_RANGE)
	WorldContainer.Position = UDim2.fromOffset(panX, panY)

	local vTrackH = math.max(1, VScrollBar.AbsoluteSize.Y - 64)
	local vFrac = 0.5 - (panY / (PAN_RANGE * 2))
	vThumb.Position = UDim2.fromOffset(0, 16 + math.clamp(vFrac, 0, 1) * vTrackH)

	local hTrackW = math.max(1, HScrollBar.AbsoluteSize.X - 64)
	local hFrac = 0.5 - (panX / (PAN_RANGE * 2))
	hThumb.Position = UDim2.fromOffset(16 + math.clamp(hFrac, 0, 1) * hTrackW, 0)
end

tbBtns.ZoomIn.MouseButton1Click:Connect(function() WorldScale.Scale = math.clamp(WorldScale.Scale + 0.15, 0.5, 2.5) end)
tbBtns.ZoomOut.MouseButton1Click:Connect(function() WorldScale.Scale = math.clamp(WorldScale.Scale - 0.15, 0.5, 2.5) end)
vUp.MouseButton1Click:Connect(function() panY += 35; applyViewTransform() end)
vDn.MouseButton1Click:Connect(function() panY -= 35; applyViewTransform() end)
hLeft.MouseButton1Click:Connect(function() panX += 35; applyViewTransform() end)
hRight.MouseButton1Click:Connect(function() panX -= 35; applyViewTransform() end)

local thumbDrag = { which = nil, startPos = 0, startPan = 0 }
vThumb.InputBegan:Connect(function(input)
	if isPointerBegin(input) then thumbDrag.which = "V"; thumbDrag.startPos = input.Position.Y; thumbDrag.startPan = panY end
end)
hThumb.InputBegan:Connect(function(input)
	if isPointerBegin(input) then thumbDrag.which = "H"; thumbDrag.startPos = input.Position.X; thumbDrag.startPan = panX end
end)
UserInputService.InputChanged:Connect(function(input)
	if thumbDrag.which == "V" and isPointerMove(input) then
		local dy = input.Position.Y - thumbDrag.startPos
		local vTrackH = math.max(1, VScrollBar.AbsoluteSize.Y - 64)
		panY = thumbDrag.startPan - (dy / vTrackH) * (PAN_RANGE * 2)
		applyViewTransform()
	elseif thumbDrag.which == "H" and isPointerMove(input) then
		local dx = input.Position.X - thumbDrag.startPos
		local hTrackW = math.max(1, HScrollBar.AbsoluteSize.X - 64)
		panX = thumbDrag.startPan - (dx / hTrackW) * (PAN_RANGE * 2)
		applyViewTransform()
	elseif input.UserInputType == Enum.UserInputType.MouseWheel then
		panY += input.Position.Z * 30; applyViewTransform()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if isPointerEnd(input) then thumbDrag.which = nil end
end)

--// Expanded Classic Help Window (Explains ALL tools including everything below Join/Split)
local HelpPanel = Instance.new("Frame")
HelpPanel.Size = UDim2.fromOffset(330, 270); HelpPanel.Position = UDim2.new(0.5, -165, 0.5, -135)
trackChrome(HelpPanel); HelpPanel.BackgroundColor3 = C.WinBg; HelpPanel.BorderSizePixel = 0; HelpPanel.Visible = false; HelpPanel.ZIndex = 30; HelpPanel.Parent = MainWindow
createBevel(HelpPanel, false)

local HelpTitle = Instance.new("TextLabel")
HelpTitle.Size = UDim2.new(1, -24, 0, 18); HelpTitle.Position = UDim2.fromOffset(2, 2)
HelpTitle.BackgroundColor3 = C.TitleActive; HelpTitle.BorderSizePixel = 0; HelpTitle.Font = Enum.Font.ArialBold
HelpTitle.Text = " Interactive Physics Help"; HelpTitle.TextColor3 = C.TitleText; HelpTitle.TextSize = 11
HelpTitle.TextXAlignment = Enum.TextXAlignment.Left; HelpTitle.ZIndex = 31; HelpTitle.Parent = HelpPanel; XPK.titles[#XPK.titles + 1] = HelpTitle
do
local HelpCloseBtn = makeButton(HelpPanel, "", UDim2.new(1, -20, 0, 2), UDim2.fromOffset(18, 18), 32)
drawPixelArt(HelpCloseBtn, WIN_SPRITES.Close, winPal, 1, 5, 5, 34); XPK.winKinds[HelpCloseBtn] = "close"
HelpCloseBtn.MouseButton1Click:Connect(function() HelpPanel.Visible = false end)
end

local HelpScroll = Instance.new("ScrollingFrame")
HelpScroll.Size = UDim2.new(1, -12, 1, -28); HelpScroll.Position = UDim2.fromOffset(6, 23)
HelpScroll.BackgroundColor3 = C.CanvasBg; HelpScroll.BorderSizePixel = 0; HelpScroll.ScrollBarThickness = 6
HelpScroll.CanvasSize = UDim2.fromOffset(0, 470); HelpScroll.ZIndex = 31; HelpScroll.Parent = HelpPanel
createBevel(HelpScroll, true)

-- Help entries are populated with actual pixel-art sprites after sprite tables are defined

--// Collapsible Properties Window
local PropsPanel = Instance.new("Frame")
PropsPanel.Size = UDim2.fromOffset(176, 260); PropsPanel.Position = UDim2.new(1, -184, 0, 74)
trackChrome(PropsPanel); PropsPanel.BackgroundColor3 = C.WinBg; PropsPanel.BorderSizePixel = 0; PropsPanel.Visible = false; PropsPanel.ZIndex = 25; PropsPanel.Parent = MainWindow
createBevel(PropsPanel, false)

local PropsTitle = Instance.new("TextLabel")
PropsTitle.Size = UDim2.new(1, -24, 0, 18); PropsTitle.Position = UDim2.fromOffset(2, 2)
PropsTitle.BackgroundColor3 = C.TitleActive; PropsTitle.BorderSizePixel = 0; PropsTitle.Font = Enum.Font.ArialBold
PropsTitle.Text = " Properties"; PropsTitle.TextColor3 = C.TitleText; PropsTitle.TextSize = 11
PropsTitle.TextXAlignment = Enum.TextXAlignment.Left; PropsTitle.ZIndex = 26; PropsTitle.Parent = PropsPanel; XPK.titles[#XPK.titles + 1] = PropsTitle
do
local PropsCloseBtn = makeButton(PropsPanel, "", UDim2.new(1, -20, 0, 2), UDim2.fromOffset(18, 18), 27)
drawPixelArt(PropsCloseBtn, WIN_SPRITES.Close, winPal, 1, 5, 5, 29); XPK.winKinds[PropsCloseBtn] = "close"
PropsCloseBtn.MouseButton1Click:Connect(function() PropsPanel.Visible = false end)
end

--// Grid Dots
local PIXELS_PER_METER = 50
for x = PIXELS_PER_METER, 1400, PIXELS_PER_METER do
	for y = PIXELS_PER_METER, 900, PIXELS_PER_METER do
		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromOffset(2, 2); dot.Position = UDim2.fromOffset(x - 1, y - 1)
		dot.BackgroundColor3 = C.GridDot; dot.BorderSizePixel = 0; dot.ZIndex = 4; dot.Parent = GridLayer
	end
end

--// Simulation State (Open space by default — objects fall straight down unless you build a floor!)
local MAX_TAPE_FRAMES = 600
local sim = {
	running = false, time = 0, frame = 0, maxFrame = 0, gravity = 9.81, airDrag = 0.0,
	targetFps = 60, fpsAccum = 0, theme = "Win95",
	useBounds = false, -- FALSE by default so objects fall straight down when there's nothing below!
	showGrid = false, showVelocityVectors = true, showForceVectors = false, showTracks = false,
	showVelMeter = false, showEnergyMeter = false, activeTool = "Select",
	bodies = {}, constraints = {}, labels = {}, tape = {},
	clipboard = {}, pasteCount = 0,
	selectedBody = nil, selectedBodies = {}, nextId = 1, trackCounter = 0,
}

local updatePropsUI, updateMetersUI, updateCoordBar, updateAppearanceUI

--// Floating Meters
local VelMeter = Instance.new("Frame")
VelMeter.Size = UDim2.fromOffset(146, 68); VelMeter.Position = UDim2.fromOffset(8, 8)
VelMeter.BackgroundColor3 = C.WinBg; VelMeter.BorderSizePixel = 0; VelMeter.Visible = false; VelMeter.ZIndex = 12; VelMeter.Parent = Canvas
createBevel(VelMeter, false)
do
local VelMeterTitle = Instance.new("TextLabel")
VelMeterTitle.Size = UDim2.new(1, -4, 0, 16); VelMeterTitle.Position = UDim2.fromOffset(2, 2)
VelMeterTitle.BackgroundColor3 = C.TitleActive; VelMeterTitle.Font = Enum.Font.ArialBold; VelMeterTitle.Text = " Velocity (m/s)"
VelMeterTitle.TextColor3 = C.TitleText; VelMeterTitle.TextSize = 11; VelMeterTitle.TextXAlignment = Enum.TextXAlignment.Left; VelMeterTitle.ZIndex = 13; VelMeterTitle.Parent = VelMeter
end
local VelMeterText = Instance.new("TextLabel")
VelMeterText.Size = UDim2.new(1, -8, 1, -22); VelMeterText.Position = UDim2.fromOffset(4, 20)
VelMeterText.BackgroundColor3 = C.CanvasBg; VelMeterText.Font = UI_FONT; VelMeterText.Text = " (no selection)"
VelMeterText.TextColor3 = C.Text; VelMeterText.TextSize = 11; VelMeterText.TextXAlignment = Enum.TextXAlignment.Left; VelMeterText.TextYAlignment = Enum.TextYAlignment.Top
VelMeterText.ZIndex = 13; VelMeterText.Parent = VelMeter
createBevel(VelMeterText, true)

local EnergyMeter = Instance.new("Frame")
EnergyMeter.Size = UDim2.fromOffset(146, 68); EnergyMeter.Position = UDim2.fromOffset(162, 8)
EnergyMeter.BackgroundColor3 = C.WinBg; EnergyMeter.BorderSizePixel = 0; EnergyMeter.Visible = false; EnergyMeter.ZIndex = 12; EnergyMeter.Parent = Canvas
createBevel(EnergyMeter, false)
do
local EnergyMeterTitle = Instance.new("TextLabel")
EnergyMeterTitle.Size = UDim2.new(1, -4, 0, 16); EnergyMeterTitle.Position = UDim2.fromOffset(2, 2)
EnergyMeterTitle.BackgroundColor3 = C.TitleActive; EnergyMeterTitle.Font = Enum.Font.ArialBold; EnergyMeterTitle.Text = " Energy (J)"
EnergyMeterTitle.TextColor3 = C.TitleText; EnergyMeterTitle.TextSize = 11; EnergyMeterTitle.TextXAlignment = Enum.TextXAlignment.Left; EnergyMeterTitle.ZIndex = 13; EnergyMeterTitle.Parent = EnergyMeter
end
local EnergyMeterText = Instance.new("TextLabel")
EnergyMeterText.Size = UDim2.new(1, -8, 1, -22); EnergyMeterText.Position = UDim2.fromOffset(4, 20)
EnergyMeterText.BackgroundColor3 = C.CanvasBg; EnergyMeterText.Font = UI_FONT; EnergyMeterText.Text = " (no selection)"
EnergyMeterText.TextColor3 = C.Text; EnergyMeterText.TextSize = 11; EnergyMeterText.TextXAlignment = Enum.TextXAlignment.Left; EnergyMeterText.TextYAlignment = Enum.TextYAlignment.Top
EnergyMeterText.ZIndex = 13; EnergyMeterText.Parent = EnergyMeter
createBevel(EnergyMeterText, true)

updateMetersUI = function()
	VelMeter.Visible = sim.showVelMeter; EnergyMeter.Visible = sim.showEnergyMeter
	local b = sim.selectedBody
	if not b then VelMeterText.Text = " (no selection)"; EnergyMeterText.Text = " (no selection)"; return end
	local vx, vy = b.vx / PIXELS_PER_METER, -b.vy / PIXELS_PER_METER
	local spd = math.sqrt(vx * vx + vy * vy)
	VelMeterText.Text = string.format(" Vx: %+.2f\n Vy: %+.2f\n |V|: %.2f", vx, vy, spd)
	local ke = 0.5 * b.mass * spd * spd
	local pe = b.mass * sim.gravity * math.max(0, (Canvas.AbsoluteSize.Y - b.y) / PIXELS_PER_METER)
	EnergyMeterText.Text = string.format(" KE: %.2f J\n PE: %.2f J\n Tot: %.2f J", ke, pe, ke + pe)
end

updateCoordBar = function()
	local b = sim.selectedBody
	if not b then CoordLabels.x.Text = "0.00"; CoordLabels.y.Text = "0.00"; return end
	CoordLabels.x.Text = string.format("%.2f", b.x / PIXELS_PER_METER)
	CoordLabels.y.Text = string.format("%.2f", (Canvas.AbsoluteSize.Y - b.y) / PIXELS_PER_METER)
end

local function isBodySelected(body)
	for _, b in ipairs(sim.selectedBodies) do if b == body then return true end end
	return false
end

local function clearSelection()
	for _, b in ipairs(sim.selectedBodies) do if b.handles then b.handles.Visible = false end end
	sim.selectedBodies = {}; sim.selectedBody = nil
	updatePropsUI(); updateCoordBar(); updateMetersUI()
end

local function setSelection(list)
	for _, b in ipairs(sim.selectedBodies) do if b.handles then b.handles.Visible = false end end
	sim.selectedBodies = {}
	for _, b in ipairs(list) do
		table.insert(sim.selectedBodies, b)
		if b.handles then b.handles.Visible = true end
	end
	sim.selectedBody = sim.selectedBodies[1]
	updatePropsUI(); updateCoordBar(); updateMetersUI()
end

local function selectBody(body)
	if body then setSelection({ body }) else clearSelection() end
end

local function smoothPolygonPoints(pts, passes)
	local current = pts
	for _ = 1, (passes or 2) do
		if #current < 3 then break end
		local nextPts = {}
		local n = #current
		for i = 1, n do
			local p0 = current[i]; local p1 = current[(i % n) + 1]
			table.insert(nextPts, p0:Lerp(p1, 0.25))
			table.insert(nextPts, p0:Lerp(p1, 0.75))
		end
		current = nextPts
	end
	return current
end

local function renderCustomPolygon(ui, localPts, w, h, baseColor)
	ui.BackgroundTransparency = 1
	local stepY = 2
	for sy = 0, h - 1, stepY do
		local intersections = {}
		local n = #localPts
		for i = 1, n do
			local p1, p2 = localPts[i], localPts[(i % n) + 1]
			if (p1.Y <= sy and p2.Y > sy) or (p2.Y <= sy and p1.Y > sy) then
				table.insert(intersections, p1.X + (sy - p1.Y) * (p2.X - p1.X) / (p2.Y - p1.Y))
			end
		end
		table.sort(intersections)
		for k = 1, #intersections - 1, 2 do
			local xStart, xEnd = math.floor(intersections[k]), math.ceil(intersections[k + 1])
			if xEnd > xStart then
				local span = Instance.new("Frame")
				span.BorderSizePixel = 0; span.Position = UDim2.fromOffset(xStart, sy); span.Size = UDim2.fromOffset(xEnd - xStart, stepY)
				span.BackgroundColor3 = (math.floor(sy / stepY) % 3 == 0) and baseColor:Lerp(C.Text, 0.06) or baseColor
				span.ZIndex = ui.ZIndex; span.Parent = ui
			end
		end
	end
	local n = #localPts
	for i = 1, n do
		local p1, p2 = localPts[i], localPts[(i % n) + 1]
		local edge = drawLineFrame(ui, "PolyEdge", C.Text, ui.ZIndex + 1)
		updateLine(edge, p1.X, p1.Y, p2.X, p2.Y, 1.5)
	end
end

local function applyBodyTexture(ui, kind, w, h)
	if kind == "Circle" then
		local hi = Instance.new("Frame")
		hi.BorderSizePixel = 0
		hi.Size = UDim2.fromOffset(math.max(4, math.floor(w * 0.22)), math.max(4, math.floor(h * 0.22)))
		hi.Position = UDim2.fromOffset(math.floor(w * 0.2), math.floor(h * 0.18))
		hi.BackgroundColor3 = Color3.fromRGB(255, 255, 255); hi.BackgroundTransparency = 0.45
		hi.ZIndex = ui.ZIndex + 1; hi.Parent = ui
		local hc = Instance.new("UICorner"); hc.CornerRadius = UDim.new(1, 0); hc.Parent = hi
	elseif kind == "Rect" then
		local stripe = Instance.new("Frame")
		stripe.BorderSizePixel = 0; stripe.Size = UDim2.new(1, -4, 0, 2); stripe.Position = UDim2.fromOffset(2, 2)
		stripe.BackgroundColor3 = Color3.fromRGB(255, 255, 255); stripe.BackgroundTransparency = 0.55
		stripe.ZIndex = ui.ZIndex + 1; stripe.Parent = ui
	end
end

local function createSelectionHandles(ui)
	local handles = Instance.new("Frame")
	handles.Name = "SelHandles"; handles.Size = UDim2.fromScale(1, 1); handles.BackgroundTransparency = 1
	handles.Visible = false; handles.ZIndex = ui.ZIndex + 4; handles.Parent = ui
	for _, pos in ipairs({
		UDim2.new(0, -3, 0, -3), UDim2.new(1, -2, 0, -3),
		UDim2.new(0, -3, 1, -2), UDim2.new(1, -2, 1, -2),
	}) do
		local sq = Instance.new("Frame")
		sq.Size = UDim2.fromOffset(5, 5); sq.Position = pos; sq.BackgroundColor3 = C.Text
		sq.BorderSizePixel = 0; sq.ZIndex = handles.ZIndex; sq.Parent = handles
	end
	return handles
end

local function createBody(kind, x, y, w, h, color, customPts)
	local id = sim.nextId; sim.nextId += 1
	local col = color or (currentThemeMode == "Mac80s" and Color3.fromRGB(255, 255, 255) or SHAPE_COLORS[((id - 1) % #SHAPE_COLORS) + 1])
	local area = (w / PIXELS_PER_METER) * (h / PIXELS_PER_METER)
	local mass = math.max(0.2, math.floor(area * 100) / 100)

	local body = {
		id = id, name = kind .. "_" .. id, kind = kind,
		x = x, y = y, w = w, h = h, vx = 0, vy = 0, angle = 0, omega = 0, motorSpeed = 0,
		torSpringK = 0, torDamperC = 0, mass = mass, restitution = 0.75, friction = 0.2,
		anchored = false, trackBody = false, slotMode = nil, color = col, pattern = "Solid",
		showName = false, showCom = true, forceX = 0, forceY = 0,
		customPts = customPts,
		initX = x, initY = y, initVx = 0, initVy = 0, initAngle = 0,
	}

	local ui = Instance.new("Frame")
	ui.Name = body.name; ui.AnchorPoint = Vector2.new(0.5, 0.5); ui.Position = UDim2.fromOffset(x, y)
	ui.Size = UDim2.fromOffset(w, h); ui.BackgroundColor3 = col; ui.BorderSizePixel = 0; ui.ZIndex = 6; ui.Parent = BodyLayer

	if kind == "Polygon" and customPts and #customPts >= 3 then
		renderCustomPolygon(ui, customPts, w, h, col)
	else
		local stroke = Instance.new("UIStroke"); stroke.Thickness = 1; stroke.Color = C.Text; stroke.Parent = ui
		if kind == "Circle" then
			local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1, 0); corner.Parent = ui
		end
		applyBodyTexture(ui, kind, w, h)
	end

	local com = Instance.new("Frame")
	com.Name = "COMDot"; com.Size = UDim2.fromOffset(3, 3); com.Position = UDim2.new(0.5, -1, 0.5, -1)
	com.BackgroundColor3 = C.Text; com.BorderSizePixel = 0; com.ZIndex = 8; com.Parent = ui

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "NameTag"; nameLbl.Size = UDim2.fromOffset(90, 14); nameLbl.Position = UDim2.new(0.5, -45, 0, -16)
	nameLbl.BackgroundTransparency = 1; nameLbl.Font = UI_FONT; nameLbl.Text = body.name
	nameLbl.TextColor3 = C.Text; nameLbl.TextSize = 10; nameLbl.Visible = false; nameLbl.ZIndex = 9; nameLbl.Parent = ui

	local anchorTag = Instance.new("TextLabel")
	anchorTag.Size = UDim2.fromOffset(10, 10); anchorTag.Position = UDim2.new(0.5, -5, 0.5, -5)
	anchorTag.BackgroundColor3 = C.WinBg; anchorTag.BorderSizePixel = 1; anchorTag.Font = UI_FONT
	anchorTag.Text = "X"; anchorTag.TextColor3 = C.Text; anchorTag.TextSize = 9
	anchorTag.Visible = body.anchored; anchorTag.ZIndex = 9; anchorTag.Parent = ui

	body.ui = ui; body.handles = createSelectionHandles(ui); body.anchorTag = anchorTag
	body.comDot = com; body.nameLabel = nameLbl
	body.velLine = drawLineFrame(VectorLayer, "Vel_" .. id, currentThemeMode == "Mac80s" and Color3.fromRGB(0, 0, 0) or C.VectorVel, 8); body.velLine.Visible = false
	body.forceLine = drawLineFrame(VectorLayer, "Force_" .. id, currentThemeMode == "Mac80s" and Color3.fromRGB(0, 0, 0) or C.VectorForce, 8); body.forceLine.Visible = false

	table.insert(sim.bodies, body)
	return body
end

local function applyBodyAppearance(body)
	if not body or not body.ui then return end
	if body.kind == "Polygon" and body.customPts and #body.customPts >= 3 then
		for _, ch in ipairs(body.ui:GetChildren()) do
			if ch:IsA("Frame") and ch.Name ~= "SelHandles" and ch.Name ~= "COMDot" and ch.Name ~= "PatternOverlay" then
				ch:Destroy()
			end
		end
		renderCustomPolygon(body.ui, body.customPts, body.w, body.h, body.color)
	else
		body.ui.BackgroundColor3 = body.color
	end
	local oldPat = body.ui:FindFirstChild("PatternOverlay")
	if oldPat then oldPat:Destroy() end
	if body.pattern and body.pattern ~= "Solid" then
		local pat = Instance.new("Frame")
		pat.Name = "PatternOverlay"; pat.Size = UDim2.fromScale(1, 1)
		pat.BackgroundTransparency = 1; pat.ClipsDescendants = true; pat.ZIndex = body.ui.ZIndex + 2; pat.Parent = body.ui
		local isCircle = (body.kind == "Circle")
		local cx, cy = body.w * 0.5, body.h * 0.5
		local r = math.max(1, math.min(cx, cy) - 1.5)
		local step = (body.pattern == "Grid") and 8 or (body.pattern == "Dither" and 4 or 6)
		if body.pattern == "Grid" then
			for gx = step, body.w - 1, step do
				local y0, hSpan = 0, body.h
				if isCircle then
					local dx = gx - cx
					if math.abs(dx) >= r then hSpan = 0 else
						local half = math.sqrt(r * r - dx * dx)
						y0 = math.floor(cy - half); hSpan = math.max(0, math.floor(half * 2))
					end
				end
				if hSpan > 1 then
					local l = Instance.new("Frame"); l.BorderSizePixel = 0; l.Size = UDim2.fromOffset(1, hSpan)
					l.Position = UDim2.fromOffset(gx, y0); l.BackgroundColor3 = C.Text; l.BackgroundTransparency = 0.65; l.ZIndex = pat.ZIndex; l.Parent = pat
				end
			end
			for gy = step, body.h - 1, step do
				local x0, wSpan = 0, body.w
				if isCircle then
					local dy = gy - cy
					if math.abs(dy) >= r then wSpan = 0 else
						local half = math.sqrt(r * r - dy * dy)
						x0 = math.floor(cx - half); wSpan = math.max(0, math.floor(half * 2))
					end
				end
				if wSpan > 1 then
					local l = Instance.new("Frame"); l.BorderSizePixel = 0; l.Size = UDim2.fromOffset(wSpan, 1)
					l.Position = UDim2.fromOffset(x0, gy); l.BackgroundColor3 = C.Text; l.BackgroundTransparency = 0.65; l.ZIndex = pat.ZIndex; l.Parent = pat
				end
			end
		elseif body.pattern == "Diagonal" then
			for gy = step, body.h - 1, step do
				local x0, wSpan = 0, body.w
				if isCircle then
					local dy = gy - cy
					if math.abs(dy) >= r then wSpan = 0 else
						local half = math.sqrt(r * r - dy * dy)
						x0 = math.floor(cx - half); wSpan = math.max(0, math.floor(half * 2))
					end
				end
				if wSpan > 1 then
					local l = Instance.new("Frame"); l.BorderSizePixel = 0; l.Size = UDim2.fromOffset(wSpan, 1)
					l.Position = UDim2.fromOffset(x0, gy); l.BackgroundColor3 = C.Text; l.BackgroundTransparency = 0.7; l.ZIndex = pat.ZIndex; l.Parent = pat
				end
			end
		elseif body.pattern == "Dither" then
			for gx = 2, body.w - 2, step do
				for gy = 2, body.h - 2, step do
					if ((gx + gy) / step) % 2 == 0 and (not isCircle or ((gx - cx)^2 + (gy - cy)^2 <= r * r)) then
						local d = Instance.new("Frame"); d.BorderSizePixel = 0; d.Size = UDim2.fromOffset(1, 1)
						d.Position = UDim2.fromOffset(gx, gy); d.BackgroundColor3 = C.Text; d.BackgroundTransparency = 0.55; d.ZIndex = pat.ZIndex; d.Parent = pat
					end
				end
			end
		end
	end
	if body.comDot then body.comDot.Visible = body.showCom ~= false end
	if body.nameLabel then
		body.nameLabel.Text = body.name
		body.nameLabel.Visible = body.showName == true
	end
end

local function createConstraint(kind, bodyA, bodyB, worldX, worldY, k)
	local c = {
		kind = kind, bodyA = bodyA, bodyB = bodyB, worldX = worldX, worldY = worldY,
		k = k or 40, damping = (kind == "Damper" or kind == "TorDamper") and 6.0 or 0.8,
		restLength = 100, baseRest = 100, phase = 0, segs = {},
		offsetX = bodyB and (bodyB.x - bodyA.x) or 0,
		offsetY = bodyB and (bodyB.y - bodyA.y) or 0,
	}
	if bodyA and bodyB then
		c.restLength = math.max(20, math.sqrt((bodyB.x - bodyA.x)^2 + (bodyB.y - bodyA.y)^2))
	elseif bodyA and worldX and worldY then
		c.restLength = math.max(20, math.sqrt((worldX - bodyA.x)^2 + (worldY - bodyA.y)^2))
	end
	c.baseRest = c.restLength

	if kind == "Pin" or kind == "Pulley" then
		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromOffset(kind == "Pulley" and 14 or 8, kind == "Pulley" and 14 or 8)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BackgroundColor3 = (currentThemeMode == "Mac80s") and Color3.fromRGB(255, 255, 255) or ((kind == "Pulley") and C.WinBg or Color3.fromRGB(245, 205, 45))
		dot.BorderSizePixel = 1; dot.ZIndex = 9; dot.Parent = ConstraintLayer
		local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1, 0); corner.Parent = dot
		c.pinDot = dot
		if bodyA and not bodyB then c.worldX = worldX or bodyA.x; c.worldY = worldY or bodyA.y end
		if kind == "Pulley" then c.ropeLine = drawLineFrame(ConstraintLayer, "PulleyRope", C.Text, 7) end
	elseif kind == "Spring" then
		for i = 1, 8 do table.insert(c.segs, drawLineFrame(ConstraintLayer, "SpringSeg", Color3.fromRGB(40, 40, 40), 7)) end
	elseif kind == "Rope" then
		c.ropeLine = drawLineFrame(ConstraintLayer, "RopeLine", currentThemeMode == "Mac80s" and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(115, 75, 35), 7)
	elseif kind == "Rod" or kind == "Actuator" or kind == "Separator" or kind == "RigidJoint" then
		c.rodLine = drawLineFrame(ConstraintLayer, "RodLine", currentThemeMode == "Mac80s" and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(70, 90, 120), 7)
	elseif kind == "Damper" then
		c.damperLine = drawLineFrame(ConstraintLayer, "DamperLine", Color3.fromRGB(60, 60, 60), 7)
	end

	table.insert(sim.constraints, c)
	return c
end

local function updateConstraintVisuals()
	for _, c in ipairs(sim.constraints) do
		local x1, y1 = c.bodyA.x, c.bodyA.y
		local x2 = c.bodyB and c.bodyB.x or c.worldX
		local y2 = c.bodyB and c.bodyB.y or c.worldY
		if (c.kind == "Pin" or c.kind == "Pulley") and c.pinDot then c.pinDot.Position = UDim2.fromOffset(x2, y2) end
		if (c.kind == "Rope" or c.kind == "Pulley") and c.ropeLine then
			updateLine(c.ropeLine, x1, y1, x2, y2, 1.5)
		elseif (c.kind == "Rod" or c.kind == "Actuator" or c.kind == "Separator" or c.kind == "RigidJoint") and c.rodLine then
			updateLine(c.rodLine, x1, y1, x2, y2, 3)
		elseif c.kind == "Damper" and c.damperLine then
			updateLine(c.damperLine, x1, y1, x2, y2, 4)
		elseif c.kind == "Spring" then
			local dx, dy = x2 - x1, y2 - y1
			local len = math.max(1, math.sqrt(dx * dx + dy * dy))
			local nx, ny = -dy / len, dx / len
			local n = #c.segs
			local px, py = x1, y1
			for i = 1, n do
				local t = i / n
				local offset = (i < n) and ((i % 2 == 1) and 6 or -6) or 0
				local qx = x1 + dx * t + nx * offset
				local qy = y1 + dy * t + ny * offset
				updateLine(c.segs[i], px, py, qx, qy, 2)
				px, py = qx, qy
			end
		end
	end
end

local function updateTapeUI()
	local ratio = (sim.maxFrame > 0) and (sim.frame / sim.maxFrame) or 0
	ScrubberFill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
	TapeFrameBox.Text = tostring(sim.frame)
end

local function recordTapeFrame()
	if sim.frame > MAX_TAPE_FRAMES then return end
	local snap = { time = sim.time, states = {} }
	for _, b in ipairs(sim.bodies) do
		snap.states[b.id] = { x = b.x, y = b.y, vx = b.vx, vy = b.vy, angle = b.angle }
	end
	sim.tape[sim.frame] = snap
	sim.maxFrame = math.max(sim.maxFrame, sim.frame)
end

local function applyTapeFrame(frameIdx)
	local snap = sim.tape[frameIdx]
	if not snap then return end
	sim.frame = frameIdx; sim.time = snap.time
	for _, b in ipairs(sim.bodies) do
		local st = snap.states[b.id]
		if st then
			b.x, b.y, b.vx, b.vy, b.angle = st.x, st.y, st.vx, st.vy, st.angle
			b.ui.Position = UDim2.fromOffset(b.x, b.y); b.ui.Rotation = math.deg(b.angle)
		end
	end
	updateConstraintVisuals(); updateCoordBar(); updateMetersUI(); updateTapeUI()
end

local function deleteBody(b)
	if not b then return end
	for i = #sim.constraints, 1, -1 do
		local c = sim.constraints[i]
		if c.bodyA == b or c.bodyB == b then
			if c.pinDot then c.pinDot:Destroy() end
			if c.ropeLine then c.ropeLine:Destroy() end
			if c.rodLine then c.rodLine:Destroy() end
			if c.damperLine then c.damperLine:Destroy() end
			for _, s in ipairs(c.segs) do s:Destroy() end
			table.remove(sim.constraints, i)
		end
	end
	for i, item in ipairs(sim.bodies) do
		if item == b then table.remove(sim.bodies, i); break end
	end
	b.ui:Destroy(); b.velLine:Destroy(); b.forceLine:Destroy()
end

local function deleteSelected()
	local toDelete = {}
	for _, b in ipairs(sim.selectedBodies) do table.insert(toDelete, b) end
	clearSelection()
	for _, b in ipairs(toDelete) do deleteBody(b) end
end

local function copySelected()
	if #sim.selectedBodies == 0 then return end
	sim.clipboard = {}; sim.pasteCount = 0
	for _, s in ipairs(sim.selectedBodies) do
		table.insert(sim.clipboard, {
			kind = s.kind, x = s.x, y = s.y, w = s.w, h = s.h, color = s.color,
			mass = s.mass, restitution = s.restitution, friction = s.friction,
			anchored = s.anchored, customPts = s.customPts,
		})
	end
end

local function cutSelected()
	if #sim.selectedBodies == 0 then return end
	copySelected(); deleteSelected()
end

local function pasteClipboard()
	if #sim.clipboard == 0 then return end
	sim.pasteCount += 1
	local offset = sim.pasteCount * 20
	local newList = {}
	for _, item in ipairs(sim.clipboard) do
		local nb = createBody(item.kind, item.x + offset, item.y + offset, item.w, item.h, item.color, item.customPts)
		nb.mass = item.mass; nb.restitution = item.restitution; nb.friction = item.friction
		nb.anchored = item.anchored; nb.anchorTag.Visible = item.anchored
		table.insert(newList, nb)
	end
	if #newList > 0 then setSelection(newList) end
end

local function eraseTracks()
	for _, ch in ipairs(TrackLayer:GetChildren()) do ch:Destroy() end
end

local function clearAll()
	sim.running = false; sim.time = 0; sim.frame = 0; sim.maxFrame = 0; sim.tape = {}
	clearSelection()
	for _, b in ipairs(sim.bodies) do
		if b.ui then b.ui:Destroy() end
		if b.velLine then b.velLine:Destroy() end
		if b.forceLine then b.forceLine:Destroy() end
	end
	for _, c in ipairs(sim.constraints) do
		if c.pinDot then c.pinDot:Destroy() end
		if c.ropeLine then c.ropeLine:Destroy() end
		if c.rodLine then c.rodLine:Destroy() end
		if c.damperLine then c.damperLine:Destroy() end
		for _, s in ipairs(c.segs) do s:Destroy() end
	end
	for _, lbl in ipairs(sim.labels) do lbl:Destroy() end
	sim.bodies = {}; sim.constraints = {}; sim.labels = {}
	eraseTracks(); updateTapeUI()
end

local function snapshotInitialStates()
	sim.tape = {}; sim.frame = 0; sim.maxFrame = 0
	for _, b in ipairs(sim.bodies) do
		b.initX, b.initY = b.x, b.y; b.initVx, b.initVy = b.vx, b.vy; b.initAngle = b.angle
	end
	recordTapeFrame()
end

local function resetSimulation()
	sim.running = false; sim.time = 0; sim.frame = 0
	for _, b in ipairs(sim.bodies) do
		b.x, b.y = b.initX, b.initY; b.vx, b.vy = b.initVx, b.initVy; b.angle, b.omega = b.initAngle, b.motorSpeed
		b.ui.Position = UDim2.fromOffset(b.x, b.y); b.ui.Rotation = math.deg(b.angle)
		b.velLine.Visible = false; b.forceLine.Visible = false
	end
	eraseTracks(); updateConstraintVisuals(); updatePropsUI(); updateCoordBar(); updateMetersUI(); updateTapeUI()
end

--// 2D Geometry & Rigid-Body Collision Helpers (Supports Custom Drawn & Concave Polygons)
local function getBodyWorldPoly(b)
	local cosA, sinA = math.cos(b.angle), math.sin(b.angle)
	local hw, hh = b.w * 0.5, b.h * 0.5
	local verts = {}
	local minX, maxX = math.huge, -math.huge
	local minY, maxY = math.huge, -math.huge

	if b.kind == "Polygon" and b.customPts and #b.customPts >= 3 then
		for i, p in ipairs(b.customPts) do
			local lx, ly = p.X - hw, p.Y - hh
			local wx = b.x + lx * cosA - ly * sinA
			local wy = b.y + lx * sinA + ly * cosA
			verts[i] = Vector2.new(wx, wy)
			if wx < minX then minX = wx end; if wx > maxX then maxX = wx end
			if wy < minY then minY = wy end; if wy > maxY then maxY = wy end
		end
	else
		local corners = {
			Vector2.new(-hw, -hh), Vector2.new(hw, -hh),
			Vector2.new(hw, hh), Vector2.new(-hw, hh),
		}
		for i, c in ipairs(corners) do
			local wx = b.x + c.X * cosA - c.Y * sinA
			local wy = b.y + c.X * sinA + c.Y * cosA
			verts[i] = Vector2.new(wx, wy)
			if wx < minX then minX = wx end; if wx > maxX then maxX = wx end
			if wy < minY then minY = wy end; if wy > maxY then maxY = wy end
		end
	end
	return { verts = verts, minX = minX, maxX = maxX, minY = minY, maxY = maxY }
end

local function pointInPoly(px, py, verts)
	local inside = false
	local n = #verts
	local j = n
	for i = 1, n do
		local vi, vj = verts[i], verts[j]
		if ((vi.Y > py) ~= (vj.Y > py)) and (px < (vj.X - vi.X) * (py - vi.Y) / ((vj.Y - vi.Y) + 1e-9) + vi.X) then
			inside = not inside
		end
		j = i
	end
	return inside
end

local function closestPointOnPolyEdges(px, py, verts)
	local n = #verts
	local bestD2 = math.huge
	local bestCx, bestCy = px, py
	local bestNx, bestNy = 0, -1
	for i = 1, n do
		local p1 = verts[i]
		local p2 = verts[(i % n) + 1]
		local ex, ey = p2.X - p1.X, p2.Y - p1.Y
		local len2 = ex * ex + ey * ey
		if len2 > 1e-6 then
			local t = math.clamp(((px - p1.X) * ex + (py - p1.Y) * ey) / len2, 0, 1)
			local cx = p1.X + ex * t
			local cy = p1.Y + ey * t
			local dx, dy = px - cx, py - cy
			local d2 = dx * dx + dy * dy
			if d2 < bestD2 then
				bestD2 = d2
				bestCx, bestCy = cx, cy
				local len = math.sqrt(len2)
				bestNx, bestNy = ey / len, -ex / len
			end
		end
	end
	return bestCx, bestCy, bestNx, bestNy, bestD2
end

local function getBodyInvInertia(b)
	if b.anchored then return 0 end
	if b.kind == "Circle" then
		local r = b.w * 0.5
		return 1 / math.max(50, 0.5 * b.mass * r * r)
	else
		return 1 / math.max(80, (b.mass * (b.w * b.w + b.h * b.h)) / 12)
	end
end

local function resolveContact(a, b, nx, ny, pen, cpX, cpY)
	local invA = a.anchored and 0 or (1 / a.mass)
	local invB = b.anchored and 0 or (1 / b.mass)
	local invSum = invA + invB
	if invSum <= 0 or pen <= 0 then return end

	local slop = 0.05
	local corr = math.max(0, pen - slop) * 0.85
	a.x -= nx * corr * (invA / invSum); a.y -= ny * corr * (invA / invSum)
	b.x += nx * corr * (invB / invSum); b.y += ny * corr * (invB / invSum)

	local invIA = getBodyInvInertia(a)
	local invIB = getBodyInvInertia(b)
	local rAx, rAy = cpX - a.x, cpY - a.y
	local rBx, rBy = cpX - b.x, cpY - b.y

	local vAx = a.vx - a.omega * rAy
	local vAy = a.vy + a.omega * rAx
	local vBx = b.vx - b.omega * rBy
	local vBy = b.vy + b.omega * rBx
	local rvx, rvy = vBx - vAx, vBy - vAy
	local vn = rvx * nx + rvy * ny
	if vn > 0 then return end

	local e = math.min(a.restitution, b.restitution)
	local rAxN = rAx * ny - rAy * nx
	local rBxN = rBx * ny - rBy * nx
	local denom = invSum + rAxN * rAxN * invIA + rBxN * rBxN * invIB
	local j = -(1 + e) * vn / math.max(1e-6, denom)

	local impX, impY = j * nx, j * ny
	if not a.anchored then
		a.vx -= impX * invA; a.vy -= impY * invA
		a.omega -= (rAx * impY - rAy * impX) * invIA
	end
	if not b.anchored then
		b.vx += impX * invB; b.vy += impY * invB
		b.omega += (rBx * impY - rBy * impX) * invIB
	end

	-- Tangential friction
	local tx, ty = -ny, nx
	local vt = rvx * tx + rvy * ty
	local rAxT = rAx * ty - rAy * tx
	local rBxT = rBx * ty - rBy * tx
	local denomT = invSum + rAxT * rAxT * invIA + rBxT * rBxT * invIB
	local jt = -vt / math.max(1e-6, denomT)
	local mu = math.sqrt((a.friction or 0.2) * (b.friction or 0.2))
	jt = math.clamp(jt, -math.abs(j) * mu, math.abs(j) * mu)

	local fImpX, fImpY = jt * tx, jt * ty
	if not a.anchored then
		a.vx -= fImpX * invA; a.vy -= fImpY * invA
		a.omega -= (rAx * fImpY - rAy * fImpX) * invIA
	end
	if not b.anchored then
		b.vx += fImpX * invB; b.vy += fImpY * invB
		b.omega += (rBx * fImpY - rBy * fImpX) * invIB
	end
end

--// Physics Step
local function stepPhysics(dt)
	local subSteps = 5
	local subDt = dt / subSteps
	local cw = Canvas.AbsoluteSize.X; if cw <= 0 then cw = 600 end
	local ch = Canvas.AbsoluteSize.Y; if ch <= 0 then ch = 300 end

	for _ = 1, subSteps do
		for _, b in ipairs(sim.bodies) do
			if not b.anchored then
				local fx = b.forceX - sim.airDrag * b.vx * b.mass
				local fy = b.forceY + (sim.gravity * PIXELS_PER_METER * b.mass) - sim.airDrag * b.vy * b.mass
				b.vx += (fx / b.mass) * subDt; b.vy += (fy / b.mass) * subDt
				if b.slotMode == "H" then b.vy = 0 elseif b.slotMode == "V" then b.vx = 0 end
				b.x += b.vx * subDt; b.y += b.vy * subDt
				if b.torSpringK > 0 then b.omega += (-b.torSpringK * b.angle / b.mass) * subDt end
				if b.torDamperC > 0 then b.omega *= math.max(0, 1 - b.torDamperC * subDt) end
				b.angle += (b.omega + b.motorSpeed) * subDt
			else
				b.vx, b.vy = 0, 0
				if b.motorSpeed ~= 0 then b.angle += b.motorSpeed * subDt end
			end
		end

		for _, c in ipairs(sim.constraints) do
			local a, b = c.bodyA, c.bodyB
			if c.kind == "Actuator" then
				c.phase += subDt * 3; c.restLength = c.baseRest + math.sin(c.phase) * 35
			elseif c.kind == "GearPair" and b then
				b.omega = -a.omega - a.motorSpeed; b.angle = -a.angle
			elseif c.kind == "RigidJoint" and b then
				local avgVx, avgVy = (a.vx + b.vx) * 0.5, (a.vy + b.vy) * 0.5
				if not a.anchored then a.vx, a.vy = avgVx, avgVy end
				if not b.anchored then b.vx, b.vy = avgVx, avgVy; b.x = a.x + c.offsetX; b.y = a.y + c.offsetY end
			end

			local x1, y1 = a.x, a.y
			local x2 = b and b.x or c.worldX
			local y2 = b and b.y or c.worldY
			local dx, dy = x2 - x1, y2 - y1
			local dist = math.max(0.001, math.sqrt(dx * dx + dy * dy))
			local nx, ny = dx / dist, dy / dist

			if c.kind == "Spring" then
				local stretch = dist - c.restLength
				local rvx, rvy = (b and b.vx or 0) - a.vx, (b and b.vy or 0) - a.vy
				local fMag = c.k * stretch + c.damping * (rvx * nx + rvy * ny)
				if not a.anchored then a.vx += (fMag * nx / a.mass) * subDt; a.vy += (fMag * ny / a.mass) * subDt end
				if b and not b.anchored then b.vx -= (fMag * nx / b.mass) * subDt; b.vy -= (fMag * ny / b.mass) * subDt end
			elseif c.kind == "Damper" then
				local rvx, rvy = (b and b.vx or 0) - a.vx, (b and b.vy or 0) - a.vy
				local fMag = c.damping * (rvx * nx + rvy * ny)
				if not a.anchored then a.vx += (fMag * nx / a.mass) * subDt; a.vy += (fMag * ny / a.mass) * subDt end
				if b and not b.anchored then b.vx -= (fMag * nx / b.mass) * subDt; b.vy -= (fMag * ny / b.mass) * subDt end
			elseif ((c.kind == "Rope" or c.kind == "Pulley") and dist > c.restLength)
				or (c.kind == "Separator" and dist < c.restLength)
				or c.kind == "Rod" or c.kind == "Actuator" then
				local corr = dist - c.restLength
				local invA = a.anchored and 0 or (1 / a.mass)
				local invB = (not b or b.anchored) and 0 or (1 / b.mass)
				local invSum = invA + invB
				if invSum > 0 then
					a.x += nx * corr * (invA / invSum); a.y += ny * corr * (invA / invSum)
					if b then b.x -= nx * corr * (invB / invSum); b.y -= ny * corr * (invB / invSum) end
					local vn = ((b and b.vx or 0) - a.vx) * nx + ((b and b.vy or 0) - a.vy) * ny
					local j = vn / invSum
					a.vx += j * nx * invA; a.vy += j * ny * invA
					if b then b.vx -= j * nx * invB; b.vy -= j * ny * invB end
				end
			elseif c.kind == "Pin" then
				if not b then
					local corr = dist - c.restLength
					if not a.anchored and dist > 0.001 then
						a.x += nx * corr; a.y += ny * corr
						local vn = a.vx * nx + a.vy * ny
						a.vx -= vn * nx; a.vy -= vn * ny
					end
				else
					local invA = a.anchored and 0 or (1 / a.mass)
					local invB = b.anchored and 0 or (1 / b.mass)
					local invSum = invA + invB
					if invSum > 0 then
						local corr = dist - c.restLength
						a.x += nx * corr * (invA / invSum); a.y += ny * corr * (invA / invSum)
						b.x -= nx * corr * (invB / invSum); b.y -= ny * corr * (invB / invSum)
						local vn = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny
						local j = vn / invSum
						a.vx += j * nx * invA; a.vy += j * ny * invA
						b.vx -= j * nx * invB; b.vy -= j * ny * invB
					end
				end
			end
		end

		-- Optional canvas floor/walls (OFF by default so objects fall straight down in open space!)
		if sim.useBounds then
			for _, b in ipairs(sim.bodies) do
				if not b.anchored then
					local hw, hh = b.w * 0.5, b.h * 0.5
					if b.y + hh > ch then
						b.y = ch - hh; if b.vy > 0 then b.vy = -b.vy * b.restitution; b.vx *= (1 - b.friction * 0.1) end
					elseif b.y - hh < 0 then
						b.y = hh; if b.vy < 0 then b.vy = -b.vy * b.restitution end
					end
					if b.x + hw > cw then
						b.x = cw - hw; if b.vx > 0 then b.vx = -b.vx * b.restitution end
					elseif b.x - hw < 0 then
						b.x = hw; if b.vx < 0 then b.vx = -b.vx * b.restitution end
					end
				end
			end
		end

		local n = #sim.bodies
		local polys = {}
		for i = 1, n do
			local b = sim.bodies[i]
			if b.kind == "Circle" then
				local r = b.w * 0.5
				polys[i] = { isCircle = true, r = r, minX = b.x - r, maxX = b.x + r, minY = b.y - r, maxY = b.y + r }
			else
				polys[i] = getBodyWorldPoly(b)
			end
		end

		for i = 1, n do
			for j = i + 1, n do
				local a, b = sim.bodies[i], sim.bodies[j]
				if not (a.anchored and b.anchored) then
					local pa, pb = polys[i], polys[j]
					if pa.maxX >= pb.minX and pb.maxX >= pa.minX and pa.maxY >= pb.minY and pb.maxY >= pa.minY then
						if pa.isCircle and pb.isCircle then
							local dx, dy = b.x - a.x, b.y - a.y
							local d2 = dx * dx + dy * dy
							local minD = pa.r + pb.r
							if d2 < minD * minD and d2 > 0.0001 then
								local d = math.sqrt(d2)
								local nx, ny = dx / d, dy / d
								resolveContact(a, b, nx, ny, minD - d, a.x + nx * pa.r, a.y + ny * pa.r)
							end
						elseif pa.isCircle or pb.isCircle then
							local cBody = pa.isCircle and a or b
							local pBody = pa.isCircle and b or a
							local r = (pa.isCircle and pa.r or pb.r)
							local verts = (pa.isCircle and pb.verts or pa.verts)
							local cx, cy, _, _, d2 = closestPointOnPolyEdges(cBody.x, cBody.y, verts)
							local inside = pointInPoly(cBody.x, cBody.y, verts)
							if inside or d2 < r * r then
								local d = math.sqrt(math.max(1e-6, d2))
								local nx, ny = (cBody.x - cx) / d, (cBody.y - cy) / d
								if inside then nx, ny = -nx, -ny end
								local pen = inside and (r + d) or (r - d)
								if pa.isCircle then
									resolveContact(a, b, -nx, -ny, pen, cx, cy)
								else
									resolveContact(a, b, nx, ny, pen, cx, cy)
								end
							end
						else
							-- Polygon/Rect vs Polygon/Rect (supports concave custom drawn shapes!)
							local bestPen = -1
							local bestNx, bestNy, bestCx, bestCy = 0, -1, (a.x + b.x) * 0.5, (a.y + b.y) * 0.5
							for _, v in ipairs(pa.verts) do
								if pointInPoly(v.X, v.Y, pb.verts) then
									local cx, cy, _, _, d2 = closestPointOnPolyEdges(v.X, v.Y, pb.verts)
									local d = math.sqrt(math.max(1e-6, d2))
									if d > bestPen then
										bestPen = d
										bestNx, bestNy = (cx - v.X) / d, (cy - v.Y) / d
										bestCx, bestCy = v.X, v.Y
									end
								end
							end
							for _, v in ipairs(pb.verts) do
								if pointInPoly(v.X, v.Y, pa.verts) then
									local cx, cy, _, _, d2 = closestPointOnPolyEdges(v.X, v.Y, pa.verts)
									local d = math.sqrt(math.max(1e-6, d2))
									if d > bestPen then
										bestPen = d
										bestNx, bestNy = (v.X - cx) / d, (v.Y - cy) / d
										bestCx, bestCy = v.X, v.Y
									end
								end
							end
							if bestPen > 0 then
								resolveContact(a, b, bestNx, bestNy, bestPen, bestCx, bestCy)
							end
						end
					end
				end
			end
		end
	end

	sim.time += dt; sim.frame += 1; sim.trackCounter += 1
	recordTapeFrame()

	for _, b in ipairs(sim.bodies) do
		b.ui.Position = UDim2.fromOffset(b.x, b.y); b.ui.Rotation = math.deg(b.angle)
		if sim.showVelocityVectors and not b.anchored and (math.abs(b.vx) > 2 or math.abs(b.vy) > 2) then
			b.velLine.Visible = true; updateLine(b.velLine, b.x, b.y, b.x + b.vx * 0.25, b.y + b.vy * 0.25, 2)
		else
			b.velLine.Visible = false
		end
		if sim.showForceVectors and not b.anchored then
			b.forceLine.Visible = true; updateLine(b.forceLine, b.x, b.y, b.x + b.forceX * 0.2, b.y + sim.gravity * 3, 2)
		else
			b.forceLine.Visible = false
		end
		if (sim.showTracks or b.trackBody) and not b.anchored and sim.trackCounter % 4 == 0 and #TrackLayer:GetChildren() < 350 then
			local dot = Instance.new("Frame")
			dot.Size = UDim2.fromOffset(3, 3); dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Position = UDim2.fromOffset(b.x, b.y); dot.BackgroundColor3 = (currentThemeMode == "Mac80s") and Color3.fromRGB(0, 0, 0) or b.color; dot.BorderSizePixel = 0
			dot.ZIndex = 5; dot.Parent = TrackLayer
		end
	end

	updateConstraintVisuals(); updateCoordBar(); updateMetersUI(); updateTapeUI()
end

--// Properties Panel Controls
local propFields = {}
local function addPropRow(labelText, yPos, onCommit)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromOffset(72, 18); lbl.Position = UDim2.fromOffset(6, yPos)
	lbl.BackgroundTransparency = 1; lbl.Font = UI_FONT; lbl.Text = labelText
	lbl.TextColor3 = C.Text; lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 26; lbl.Parent = PropsPanel

	local box = Instance.new("TextBox")
	box.Size = UDim2.fromOffset(88, 18); box.Position = UDim2.fromOffset(80, yPos)
	box.BackgroundColor3 = C.CanvasBg; box.BorderSizePixel = 0; box.Font = UI_FONT
	box.Text = "-"; box.TextColor3 = C.Text; box.TextSize = 11; box.ClearTextOnFocus = false
	box.ZIndex = 26; box.Parent = PropsPanel
	createBevel(box, true)

	box.FocusLost:Connect(function()
		for _, sel in ipairs(sim.selectedBodies) do onCommit(sel, box.Text) end
		updatePropsUI()
	end)
	return box
end

local PropNameLbl = Instance.new("TextLabel")
PropNameLbl.Size = UDim2.new(1, -12, 0, 18); PropNameLbl.Position = UDim2.fromOffset(6, 24)
PropNameLbl.BackgroundTransparency = 1; PropNameLbl.Font = UI_FONT; PropNameLbl.Text = "Body: None"
PropNameLbl.TextColor3 = C.Text; PropNameLbl.TextSize = 11; PropNameLbl.TextXAlignment = Enum.TextXAlignment.Left; PropNameLbl.ZIndex = 26; PropNameLbl.Parent = PropsPanel

propFields.mass = addPropRow("Mass (kg):", 46, function(b, txt) local v = tonumber(txt); if v then b.mass = math.clamp(v, 0.1, 100) end end)
propFields.rest = addPropRow("Elasticity:", 70, function(b, txt) local v = tonumber(txt); if v then b.restitution = math.clamp(v, 0, 1.2) end end)
propFields.fric = addPropRow("Friction:", 94, function(b, txt) local v = tonumber(txt); if v then b.friction = math.clamp(v, 0, 1) end end)
propFields.vx = addPropRow("Vx (m/s):", 118, function(b, txt) local v = tonumber(txt); if v then b.vx = v * PIXELS_PER_METER; b.initVx = b.vx end end)
propFields.vy = addPropRow("Vy (m/s):", 142, function(b, txt) local v = tonumber(txt); if v then b.vy = -v * PIXELS_PER_METER; b.initVy = b.vy end end)
propFields.motor = addPropRow("Motor rad:", 166, function(b, txt) local v = tonumber(txt); if v then b.motorSpeed = math.clamp(v, -20, 20) end end)

local AnchorToggleBtn = makeButton(PropsPanel, "Anchor: OFF", UDim2.fromOffset(6, 196), UDim2.fromOffset(164, 22), 26)
AnchorToggleBtn.MouseButton1Click:Connect(function()
	for _, b in ipairs(sim.selectedBodies) do b.anchored = not b.anchored; b.anchorTag.Visible = b.anchored end
	updatePropsUI()
end)

local DeleteBodyBtn = makeButton(PropsPanel, "Delete Selected", UDim2.fromOffset(6, 224), UDim2.fromOffset(164, 22), 26, C.StopRed)
DeleteBodyBtn.MouseButton1Click:Connect(deleteSelected)

updatePropsUI = function()
	local count = #sim.selectedBodies
	local b = sim.selectedBody
	if count == 0 or not b then
		PropNameLbl.Text = "Body: None"
		for _, f in pairs(propFields) do f.Text = "-" end
		AnchorToggleBtn.Text = "Anchor: -"
		return
	end
	PropNameLbl.Text = (count > 1) and ("Selected: " .. count .. " bodies") or ("Body: " .. b.name)
	propFields.mass.Text = string.format("%.2f", b.mass)
	propFields.rest.Text = string.format("%.2f", b.restitution)
	propFields.fric.Text = string.format("%.2f", b.friction)
	propFields.vx.Text = string.format("%.2f", b.vx / PIXELS_PER_METER)
	propFields.vy.Text = string.format("%.2f", -b.vy / PIXELS_PER_METER)
	propFields.motor.Text = string.format("%.2f", b.motorSpeed)
	AnchorToggleBtn.Text = b.anchored and "Anchor: ON" or "Anchor: OFF"
	if updateAppearanceUI then updateAppearanceUI() end
end

--// Theme Selector (Windows 95, Windows XP Luna, Late '80s Macintosh)
local ThemePanel = Instance.new("Frame")
ThemePanel.Name = "ThemePanel"
ThemePanel.Size = UDim2.fromOffset(228, 146); ThemePanel.Position = UDim2.new(0.5, -114, 0.5, -73)
ThemePanel.BackgroundColor3 = C.WinBg; ThemePanel.BorderSizePixel = 0; ThemePanel.Visible = false; ThemePanel.ZIndex = 28; ThemePanel.Parent = MainWindow
trackChrome(ThemePanel); createBevel(ThemePanel, false)

local ThemeTitle = Instance.new("TextLabel")
ThemeTitle.Size = UDim2.new(1, -24, 0, 18); ThemeTitle.Position = UDim2.fromOffset(2, 2)
ThemeTitle.BackgroundColor3 = C.TitleActive; ThemeTitle.BorderSizePixel = 0; ThemeTitle.Font = Enum.Font.ArialBold
ThemeTitle.Text = " Interface Theme"; ThemeTitle.TextColor3 = C.TitleText; ThemeTitle.TextSize = 11
ThemeTitle.TextXAlignment = Enum.TextXAlignment.Left; ThemeTitle.ZIndex = 29; ThemeTitle.Parent = ThemePanel; XPK.titles[#XPK.titles + 1] = ThemeTitle
do
local ThemeCloseBtn = makeButton(ThemePanel, "", UDim2.new(1, -20, 0, 2), UDim2.fromOffset(18, 18), 30)
drawPixelArt(ThemeCloseBtn, WIN_SPRITES.Close, winPal, 1, 5, 5, 32); XPK.winKinds[ThemeCloseBtn] = "close"
ThemeCloseBtn.MouseButton1Click:Connect(function() ThemePanel.Visible = false end)

local THEMES = {
	Win95 = {
		chrome = Color3.fromRGB(192, 192, 192),
		titleBg = Color3.fromRGB(0, 0, 128),
		titleText = Color3.fromRGB(255, 255, 255),
		gridDot = Color3.fromRGB(195, 200, 210),
		macMode = false, xpMode = false,
	},
	WinXP = {
		chrome = Color3.fromRGB(236, 233, 216),
		titleBg = Color3.fromRGB(0, 84, 227),
		titleText = Color3.fromRGB(255, 255, 255),
		gridDot = Color3.fromRGB(205, 210, 220),
		macMode = false, xpMode = true,
	},
	Mac80s = {
		chrome = Color3.fromRGB(255, 255, 255),
		titleBg = Color3.fromRGB(255, 255, 255),
		titleText = Color3.fromRGB(0, 0, 0),
		gridDot = Color3.fromRGB(120, 120, 120),
		macMode = true, xpMode = false,
	},
}

local function applyTheme(themeId)
	local t = THEMES[themeId] or THEMES.Win95
	sim.theme = themeId
	currentThemeMode = themeId
	C.WinBg = t.chrome
	C.TitleActive = t.titleBg
	C.TitleText = t.titleText

	for _, f in ipairs(themedChromeFrames) do
		if f and f.Parent then f.BackgroundColor3 = t.chrome end
	end
	for _, b in ipairs(themedButtons) do
		if b and b.Parent and b ~= MinBtn and b ~= MaxBtn and b ~= CloseBtn then
			b.BackgroundColor3 = t.chrome
		end
	end

	TitleBar.BackgroundColor3 = t.titleBg
	MenuSep.Visible = not t.xpMode -- (Windows 95's grey line under the menu bar: XP has none)
	MacPinstripes.Visible = t.macMode
	MacCloseBtn.Visible = t.macMode
	local logo = TitleBar:FindFirstChild("Logo")
	if logo then logo.Visible = not t.macMode end
	local mdiDoc = MenuBar:FindFirstChild("MDIDocIcon")
	if mdiDoc then mdiDoc.Visible = not t.macMode end
	MacAppleIcon.Visible = t.macMode
	MacClockLbl.Visible = t.macMode

	if t.macMode then
		TitleLabel.TextXAlignment = Enum.TextXAlignment.Center
		TitleLabel.BackgroundTransparency = 0
		TitleLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		TitleLabel.Size = UDim2.fromOffset(220, 16)
		TitleLabel.Position = UDim2.new(0.5, -110, 0, 3)
		TitleLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
		MinBtn.Visible = false; MaxBtn.Visible = false; CloseBtn.Visible = false
		mdiMin.Visible = false; mdiMax.Visible = false; mdiCls.Visible = false
	else
		TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
		TitleLabel.BackgroundTransparency = 1
		TitleLabel.Size = UDim2.new(1, -90, 1, 0)
		TitleLabel.Position = UDim2.fromOffset(24, 0)
		TitleLabel.TextColor3 = t.titleText
		MinBtn.Visible = true; MaxBtn.Visible = true; CloseBtn.Visible = true
		mdiMin.Visible = true; mdiMax.Visible = true; mdiCls.Visible = true
		if t.xpMode then
			MinBtn.BackgroundColor3 = Color3.fromRGB(21, 108, 232)
			MaxBtn.BackgroundColor3 = Color3.fromRGB(21, 108, 232)
			CloseBtn.BackgroundColor3 = Color3.fromRGB(220, 56, 32)
		else
			MinBtn.BackgroundColor3 = t.chrome
			MaxBtn.BackgroundColor3 = t.chrome
			CloseBtn.BackgroundColor3 = t.chrome
		end
	end

	-- (Addtion-Scripts) the title bar: the sheet's real XP title bar when it's there, else the drawn gradient
	TitleLabel.TextStrokeTransparency = t.xpMode and 0.7 or 1
	TitleLabel.TextStrokeColor3 = Color3.fromRGB(0, 30, 110)
	local xpTitleTex = TitleBar:FindFirstChild("_XPTitleTex")
	if t.xpMode and XPK.sheet then
		if not xpTitleTex then
			xpTitleTex = Instance.new("ImageLabel")
			xpTitleTex.Name = "_XPTitleTex"; xpTitleTex.Size = UDim2.fromScale(1, 1); xpTitleTex.BackgroundTransparency = 1
			xpTitleTex.Image = XPK.sheet; xpTitleTex.ImageRectOffset = Vector2.new(0, 0); xpTitleTex.ImageRectSize = Vector2.new(66, 29)
			xpTitleTex.ScaleType = Enum.ScaleType.Slice; xpTitleTex.SliceCenter = Rect.new(8, 6, 58, 24)
			xpTitleTex.ZIndex = 3; xpTitleTex.Parent = TitleBar
		end
	elseif xpTitleTex then
		xpTitleTex:Destroy()
	end
	local xpGrad = TitleBar:FindFirstChild("_XPTitleGrad")
	if t.xpMode and not XPK.sheet then
		if not xpGrad then
			xpGrad = Instance.new("UIGradient")
			xpGrad.Name = "_XPTitleGrad"; xpGrad.Rotation = 90
			xpGrad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(61, 149, 255)),
				ColorSequenceKeypoint.new(0.22, Color3.fromRGB(0, 84, 227)),
				ColorSequenceKeypoint.new(0.85, Color3.fromRGB(0, 70, 210)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 50, 165)),
			})
			xpGrad.Parent = TitleBar
		end
	elseif xpGrad then
		xpGrad:Destroy()
	end

	-- the window buttons (the title bar's three and every dialog's close button): the sheet's red / blue pieces with their
	-- hovered and pressed looks; without the sheet the drawn XP buttons
	local WIN_SHEET_Y = { close = 30, min = 76, max = 98 }
	for wb, kind in pairs(XPK.winKinds) do
		if wb.Parent then
			local sheet = t.xpMode and XPK.sheet ~= nil
			local wtex = wb:FindFirstChild("_XPWinTex")
			if sheet then
				if not wtex then
					wtex = Instance.new("ImageLabel")
					wtex.Name = "_XPWinTex"; wtex.Size = UDim2.fromScale(1, 1); wtex.BackgroundTransparency = 1
					wtex.Image = XPK.sheet; wtex.ImageRectSize = Vector2.new(21, 21)
					wtex.ImageRectOffset = Vector2.new(0, WIN_SHEET_Y[kind]); wtex.ZIndex = wb.ZIndex + 1; wtex.Parent = wb
					local function lookAt(x) wtex.ImageRectOffset = Vector2.new(x, WIN_SHEET_Y[kind]) end
					wb.MouseEnter:Connect(function() lookAt(22) end)
					wb.MouseLeave:Connect(function() lookAt(0) end)
					wb.MouseButton1Down:Connect(function() lookAt(44) end)
					wb.MouseButton1Up:Connect(function() lookAt(0) end)
				end
			elseif wtex then
				wtex:Destroy()
			end
			for _, ch in ipairs(wb:GetChildren()) do
				if ch.Name == "_Sprite" then ch.Visible = not sheet end
			end
			if not wb:FindFirstChild("GlyphXP") then
				-- (a dialog's close button has one picture: white on the red XP button, black on the others)
				for _, ch in ipairs(wb:GetChildren()) do
					if ch.Name == "_Sprite" then
						for _, px in ipairs(ch:GetChildren()) do
							if px:IsA("Frame") then px.BackgroundColor3 = (t.xpMode and not sheet) and Color3.new(1, 1, 1) or C.Text end
						end
					end
				end
			end
			local g95 = wb:FindFirstChild("Glyph95")
			local gxp = wb:FindFirstChild("GlyphXP")
			if g95 then g95.Visible = not t.xpMode end
			if gxp then gxp.Visible = t.xpMode and not sheet end
			wb.BackgroundTransparency = sheet and 1 or 0
			local uc = wb:FindFirstChild("_XPCorner")
			local st = wb:FindFirstChild("_XPStroke")
			local wg = wb:FindFirstChild("_XPWinBtnGrad")
			if t.xpMode and not sheet then
				wb.BackgroundColor3 = Color3.new(1, 1, 1)
				if not uc then uc = Instance.new("UICorner"); uc.Name = "_XPCorner"; uc.CornerRadius = UDim.new(0, 3); uc.Parent = wb end
				if not st then st = Instance.new("UIStroke"); st.Name = "_XPStroke"; st.Thickness = 1; st.Color = Color3.fromRGB(255, 255, 255); st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = wb end
				if not wg then wg = Instance.new("UIGradient"); wg.Name = "_XPWinBtnGrad"; wg.Rotation = 90; wg.Parent = wb end
				if kind == "close" then
					wg.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 122, 89)),
						ColorSequenceKeypoint.new(0.45, Color3.fromRGB(230, 72, 39)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(185, 36, 12)),
					})
				else
					wg.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(102, 165, 255)),
						ColorSequenceKeypoint.new(0.45, Color3.fromRGB(40, 106, 227)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(21, 81, 196)),
					})
				end
			else
				if uc then uc:Destroy() end
				if st then st:Destroy() end
				if wg then wg:Destroy() end
			end
		end
	end

	-- Pure 1-bit monochrome vectors/constraints/tracks in Mac80s mode
	for _, td in ipairs(TrackLayer:GetChildren()) do
		if td:IsA("Frame") and t.macMode then td.BackgroundColor3 = Color3.fromRGB(0, 0, 0) end
	end
	local mono = Color3.fromRGB(0, 0, 0)
	for _, body in ipairs(sim.bodies) do
		if body.velLine then body.velLine.BackgroundColor3 = t.macMode and mono or C.VectorVel end
		if body.forceLine then body.forceLine.BackgroundColor3 = t.macMode and mono or C.VectorForce end
	end
	for _, c in ipairs(sim.constraints) do
		if c.pinDot then c.pinDot.BackgroundColor3 = t.macMode and Color3.fromRGB(255, 255, 255) or ((c.kind == "Pulley") and C.WinBg or Color3.fromRGB(245, 205, 45)) end
		if c.ropeLine then c.ropeLine.BackgroundColor3 = t.macMode and mono or Color3.fromRGB(115, 75, 35) end
		if c.rodLine then c.rodLine.BackgroundColor3 = t.macMode and mono or Color3.fromRGB(70, 90, 120) end
	end

	TopToolbar.Visible = not t.macMode
	ToolPalette.Visible = not t.macMode
	MacToolStrip.Visible = t.macMode

	-- Scrollbar styling per theme (219948.png XP periwinkle scrollbars vs Mac 1-bit B&W vs Win95 dither)
	for _, trk in ipairs({ VScrollBar, HScrollBar }) do
		local dith = trk:FindFirstChild("Dither")
		if dith then dith.Visible = not t.xpMode end
		trk.BackgroundColor3 = t.xpMode and Color3.fromRGB(243, 242, 235) or (t.macMode and Color3.fromRGB(255, 255, 255) or C.TrackBg)
	end
	for _, sb in ipairs({ vThumb, hThumb, vUp, vDn, hLeft, hRight }) do
		XPK.scrollSet[sb] = true
		local sg = sb:FindFirstChild("_XPScrollGrad")
		if t.xpMode then
			sb.BackgroundTransparency = 0
			sb.BackgroundColor3 = Color3.fromRGB(205, 223, 252)
			if not sg then sg = Instance.new("UIGradient"); sg.Name = "_XPScrollGrad"; sg.Rotation = 90; sg.Parent = sb end
			sg.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(225, 236, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(165, 196, 246)),
			})
		else
			if sg then sg:Destroy() end
			sb.BackgroundColor3 = t.macMode and Color3.fromRGB(255, 255, 255) or C.WinBg
		end
	end

	-- (Addtion-Scripts) the colour icons in the XP theme, the black-and-white ones in the others (built a few per frame)
	task.spawn(function()
		for i, e in ipairs(XPK.colour) do
			if currentThemeMode ~= themeId then return end
			XPK.setIconTheme(e, t.xpMode)
			if t.xpMode and i % 5 == 0 then task.wait() end
		end
	end)

	-- Fix ScrubberFill, CoordBar, & Crisp Pixelated Mac Font
	ScrubberFill.BackgroundColor3 = t.macMode and Color3.fromRGB(0, 0, 0) or t.titleBg
	ScrubberTrack.BackgroundColor3 = t.macMode and Color3.fromRGB(255, 255, 255) or C.TrackBg
	if CoordLabels.x then CoordLabels.x.BackgroundColor3 = t.chrome end
	if CoordLabels.y then CoordLabels.y.BackgroundColor3 = t.chrome end
	TitleLabel.Font = t.macMode and Enum.Font.Code or Enum.Font.ArialBold
	MacClockLbl.Font = t.macMode and Enum.Font.Code or Enum.Font.ArialBold
	for _, mb in pairs(macStripBtns) do
		mb.Font = t.macMode and Enum.Font.Code or Enum.Font.Arial
	end
	if t.macMode then
		WorkspaceContainer.Position = UDim2.fromOffset(36, 42)
		WorkspaceContainer.Size = UDim2.new(1, -36, 1, -66)
		GridLayer.Visible = true
		sim.showGrid = true
	else
		WorkspaceContainer.Position = UDim2.fromOffset(56, 68)
		WorkspaceContainer.Size = UDim2.new(1, -56, 1, -92)
	end

	for fr, pressed in pairs(beveledFrames) do
		if fr and fr.Parent and fr ~= MinBtn and fr ~= MaxBtn and fr ~= CloseBtn then
			styleBevelForTheme(fr, pressed)
		end
	end
	if t.xpMode then
		for _, wb in ipairs({ MinBtn, MaxBtn, CloseBtn }) do
			for _, en in ipairs({ "_BTop", "_BLeft", "_BBot", "_BRight" }) do
				local ef = wb:FindFirstChild(en); if ef then ef.Visible = false end
			end
		end
	end

	for _, ttl in ipairs(XPK.titles) do
		ttl.BackgroundColor3 = t.macMode and Color3.fromRGB(0, 0, 0) or t.titleBg
		ttl.TextColor3 = Color3.fromRGB(255, 255, 255)
		ttl.TextSize = t.xpMode and 12 or 11
		-- (Addtion-Scripts) an XP dialog is a window: the blue frame, the title bar across its top, the beige page inside
		local panel = ttl.Parent
		local page = panel:FindFirstChild("_XPPage")
		local bar = panel:FindFirstChild("_XPDlgBar")
		if t.xpMode then
			panel.BackgroundColor3 = Color3.fromRGB(0, 66, 214)
			if not page then
				page = Instance.new("Frame")
				page.Name = "_XPPage"; page.BorderSizePixel = 0
				page.Position = UDim2.new(0, 3, 0, 22); page.Size = UDim2.new(1, -6, 1, -25)
				page.ZIndex = panel.ZIndex; page.Parent = panel
			end
			page.BackgroundColor3 = t.chrome
			if XPK.sheet then
				ttl.BackgroundTransparency = 1
				if not bar then
					bar = Instance.new("ImageLabel")
					bar.Name = "_XPDlgBar"; bar.BackgroundTransparency = 1
					bar.Position = UDim2.fromOffset(0, 0); bar.Size = UDim2.new(1, 0, 0, 22)
					bar.Image = XPK.sheet; bar.ImageRectOffset = Vector2.new(0, 0); bar.ImageRectSize = Vector2.new(66, 29)
					bar.ScaleType = Enum.ScaleType.Slice; bar.SliceCenter = Rect.new(8, 6, 58, 24)
					bar.ZIndex = panel.ZIndex; bar.Parent = panel
				end
			else
				ttl.BackgroundTransparency = 0
				if bar then bar:Destroy() end
			end
			local pst = panel:FindFirstChild("_ThemeStroke")
			if not pst then pst = Instance.new("UIStroke"); pst.Name = "_ThemeStroke"; pst.Thickness = 1; pst.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; pst.Parent = panel end
			pst.Color = Color3.fromRGB(0, 0, 128)
		else
			ttl.BackgroundTransparency = 0
			if page then page:Destroy() end
			if bar then bar:Destroy() end
		end
	end

	for _, dot in ipairs(GridLayer:GetChildren()) do
		if dot:IsA("Frame") then dot.BackgroundColor3 = t.gridDot end
	end

	for _, body in ipairs(sim.bodies) do
		if t.macMode then
			if body.kind == "Polygon" and body.customPts and #body.customPts >= 3 then
				for _, ch in ipairs(body.ui:GetChildren()) do
					if ch:IsA("Frame") and ch.Name ~= "SelHandles" and ch.Name ~= "COMDot" and ch.Name ~= "PatternOverlay" then ch:Destroy() end
				end
				renderCustomPolygon(body.ui, body.customPts, body.w, body.h, Color3.fromRGB(255, 255, 255))
			else
				body.ui.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			end
		else
			applyBodyAppearance(body)
		end
	end
end

XPK.refresh = applyTheme

local themeChoices = {
	{ id = "Win95", label = "Windows 95 / 98 (Classic)" },
	{ id = "WinXP", label = "Windows XP (Luna Blue)" },
	{ id = "Mac80s", label = "Late '80s Macintosh (System 6)" },
}
for i, tc in ipairs(themeChoices) do
	local tb = makeButton(ThemePanel, tc.label, UDim2.fromOffset(10, 28 + (i - 1) * 28), UDim2.fromOffset(208, 24), 29)
	tb.MouseButton1Click:Connect(function() applyTheme(tc.id) end)
end
local ThemeOkBtn = makeButton(ThemePanel, "OK", UDim2.fromOffset(74, 116), UDim2.fromOffset(80, 22), 29)
ThemeOkBtn.MouseButton1Click:Connect(function() ThemePanel.Visible = false end)
end

--// Simulation Frame Rate / Lag Dialog (World -> Frame Rate...)
local FpsPanel = Instance.new("Frame")
FpsPanel.Name = "FpsPanel"
FpsPanel.Size = UDim2.fromOffset(216, 134); FpsPanel.Position = UDim2.new(0.5, -108, 0.5, -67)
trackChrome(FpsPanel); FpsPanel.BackgroundColor3 = C.WinBg; FpsPanel.BorderSizePixel = 0; FpsPanel.Visible = false; FpsPanel.ZIndex = 28; FpsPanel.Parent = MainWindow
createBevel(FpsPanel, false)

local FpsTitle = Instance.new("TextLabel")
FpsTitle.Size = UDim2.new(1, -24, 0, 18); FpsTitle.Position = UDim2.fromOffset(2, 2)
FpsTitle.BackgroundColor3 = C.TitleActive; FpsTitle.BorderSizePixel = 0; FpsTitle.Font = Enum.Font.ArialBold
FpsTitle.Text = " Simulation Frame Rate"; FpsTitle.TextColor3 = C.TitleText; FpsTitle.TextSize = 11
FpsTitle.TextXAlignment = Enum.TextXAlignment.Left; FpsTitle.ZIndex = 29; FpsTitle.Parent = FpsPanel; XPK.titles[#XPK.titles + 1] = FpsTitle
do
local FpsCloseBtn = makeButton(FpsPanel, "", UDim2.new(1, -20, 0, 2), UDim2.fromOffset(18, 18), 30)
drawPixelArt(FpsCloseBtn, WIN_SPRITES.Close, winPal, 1, 5, 5, 32); XPK.winKinds[FpsCloseBtn] = "close"
FpsCloseBtn.MouseButton1Click:Connect(function() FpsPanel.Visible = false end)

local FpsCurLbl = Instance.new("TextLabel")
FpsCurLbl.Size = UDim2.new(1, -12, 0, 16); FpsCurLbl.Position = UDim2.fromOffset(6, 24)
FpsCurLbl.BackgroundTransparency = 1; FpsCurLbl.Font = Enum.Font.ArialBold; FpsCurLbl.Text = "Current: 60 FPS"
FpsCurLbl.TextColor3 = C.Text; FpsCurLbl.TextSize = 11; FpsCurLbl.TextXAlignment = Enum.TextXAlignment.Left
FpsCurLbl.ZIndex = 29; FpsCurLbl.Parent = FpsPanel

local FpsInput = Instance.new("TextBox")
FpsInput.Size = UDim2.fromOffset(72, 22); FpsInput.Position = UDim2.fromOffset(8, 44)
FpsInput.BackgroundColor3 = C.CanvasBg; FpsInput.BorderSizePixel = 0; FpsInput.Font = UI_FONT
FpsInput.Text = "60"; FpsInput.TextColor3 = C.Text; FpsInput.TextSize = 11; FpsInput.ZIndex = 29; FpsInput.Parent = FpsPanel
createBevel(FpsInput, true)

local FpsApplyBtn = makeButton(FpsPanel, "Set FPS", UDim2.fromOffset(86, 44), UDim2.fromOffset(62, 22), 29)
local FpsOkBtn = makeButton(FpsPanel, "OK", UDim2.fromOffset(154, 44), UDim2.fromOffset(52, 22), 29)

local function setSimFps(fps)
	local clamped = math.clamp(math.floor(fps + 0.5), 1, 60)
	sim.targetFps = clamped
	sim.fpsAccum = 0
	FpsInput.Text = tostring(clamped)
	FpsCurLbl.Text = string.format("Current: %d FPS", clamped)
end

FpsApplyBtn.MouseButton1Click:Connect(function()
	local n = tonumber(FpsInput.Text)
	if n then setSimFps(n) else FpsInput.Text = tostring(sim.targetFps) end
end)
FpsInput.FocusLost:Connect(function()
	local n = tonumber(FpsInput.Text)
	if n then setSimFps(n) else FpsInput.Text = tostring(sim.targetFps) end
end)
FpsOkBtn.MouseButton1Click:Connect(function()
	local n = tonumber(FpsInput.Text)
	if n then setSimFps(n) end
	FpsPanel.Visible = false
end)

local FPS_PRESETS = { 5, 10, 15, 20, 30, 60 }
for i, pFps in ipairs(FPS_PRESETS) do
	local col = (i - 1) % 3
	local row = math.floor((i - 1) / 3)
	local pb = makeButton(FpsPanel, pFps .. " FPS", UDim2.fromOffset(8 + col * 68, 76 + row * 26), UDim2.fromOffset(64, 22), 29)
	pb.MouseButton1Click:Connect(function() setSimFps(pFps) end)
end
end

--// Classic Appearance Dialog (Window -> Appearance...)
local AppearancePanel = Instance.new("Frame")
AppearancePanel.Name = "AppearancePanel"
AppearancePanel.Size = UDim2.fromOffset(224, 224); AppearancePanel.Position = UDim2.new(0.5, -112, 0.5, -112)
trackChrome(AppearancePanel); AppearancePanel.BackgroundColor3 = C.WinBg; AppearancePanel.BorderSizePixel = 0; AppearancePanel.Visible = false; AppearancePanel.ZIndex = 28; AppearancePanel.Parent = MainWindow
createBevel(AppearancePanel, false)

local AppTitle = Instance.new("TextLabel")
AppTitle.Size = UDim2.new(1, -24, 0, 18); AppTitle.Position = UDim2.fromOffset(2, 2)
AppTitle.BackgroundColor3 = C.TitleActive; AppTitle.BorderSizePixel = 0; AppTitle.Font = Enum.Font.ArialBold
AppTitle.Text = " Appearance"; AppTitle.TextColor3 = C.TitleText; AppTitle.TextSize = 11
AppTitle.TextXAlignment = Enum.TextXAlignment.Left; AppTitle.ZIndex = 29; AppTitle.Parent = AppearancePanel; XPK.titles[#XPK.titles + 1] = AppTitle
do
local AppCloseBtn = makeButton(AppearancePanel, "", UDim2.new(1, -20, 0, 2), UDim2.fromOffset(18, 18), 30)
drawPixelArt(AppCloseBtn, WIN_SPRITES.Close, winPal, 1, 5, 5, 32); XPK.winKinds[AppCloseBtn] = "close"
AppCloseBtn.MouseButton1Click:Connect(function() AppearancePanel.Visible = false end)

local AppTargetLbl = Instance.new("TextLabel")
AppTargetLbl.Size = UDim2.new(1, -12, 0, 16); AppTargetLbl.Position = UDim2.fromOffset(6, 24)
AppTargetLbl.BackgroundTransparency = 1; AppTargetLbl.Font = UI_FONT; AppTargetLbl.Text = "Select an object to customize"
AppTargetLbl.TextColor3 = C.Text; AppTargetLbl.TextSize = 11; AppTargetLbl.TextXAlignment = Enum.TextXAlignment.Left
AppTargetLbl.ZIndex = 29; AppTargetLbl.Parent = AppearancePanel

local AppColorLbl = Instance.new("TextLabel")
AppColorLbl.Size = UDim2.new(1, -12, 0, 14); AppColorLbl.Position = UDim2.fromOffset(6, 42)
AppColorLbl.BackgroundTransparency = 1; AppColorLbl.Font = Enum.Font.ArialBold; AppColorLbl.Text = "Fill Color:"
AppColorLbl.TextColor3 = C.Text; AppColorLbl.TextSize = 11; AppColorLbl.TextXAlignment = Enum.TextXAlignment.Left
AppColorLbl.ZIndex = 29; AppColorLbl.Parent = AppearancePanel

local APPEARANCE_COLORS = {
	Color3.fromRGB(150, 200, 245), Color3.fromRGB(245, 240, 150), Color3.fromRGB(160, 230, 230), Color3.fromRGB(235, 175, 170),
	Color3.fromRGB(180, 230, 175), Color3.fromRGB(210, 180, 240), Color3.fromRGB(250, 195, 130), Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(0, 120, 215),   Color3.fromRGB(220, 50, 50),   Color3.fromRGB(0, 160, 80),    Color3.fromRGB(235, 140, 20),
	Color3.fromRGB(128, 0, 128),   Color3.fromRGB(0, 128, 128),   Color3.fromRGB(192, 192, 192), Color3.fromRGB(64, 64, 64),
}

for idx, col in ipairs(APPEARANCE_COLORS) do
	local row = math.floor((idx - 1) / 8)
	local cidx = (idx - 1) % 8
	local sw = Instance.new("TextButton")
	sw.Size = UDim2.fromOffset(22, 20)
	sw.Position = UDim2.fromOffset(8 + cidx * 26, 58 + row * 24)
	sw.BackgroundColor3 = col; sw.BorderSizePixel = 0; sw.Text = ""; sw.AutoButtonColor = false
	sw.ZIndex = 29; sw.Parent = AppearancePanel
	createBevel(sw, true)
	sw.MouseButton1Click:Connect(function()
		for _, b in ipairs(sim.selectedBodies) do
			b.color = col
			applyBodyAppearance(b)
		end
	end)
end

local AppPatLbl = Instance.new("TextLabel")
AppPatLbl.Size = UDim2.new(1, -12, 0, 14); AppPatLbl.Position = UDim2.fromOffset(6, 110)
AppPatLbl.BackgroundTransparency = 1; AppPatLbl.Font = Enum.Font.ArialBold; AppPatLbl.Text = "Pattern:"
AppPatLbl.TextColor3 = C.Text; AppPatLbl.TextSize = 11; AppPatLbl.TextXAlignment = Enum.TextXAlignment.Left
AppPatLbl.ZIndex = 29; AppPatLbl.Parent = AppearancePanel

for i, patName in ipairs({ "Solid", "Grid", "Diagonal", "Dither" }) do
	local pb = makeButton(AppearancePanel, patName == "Diagonal" and "Lines" or patName, UDim2.fromOffset(8 + (i - 1) * 52, 126), UDim2.fromOffset(48, 22), 29)
	pb.MouseButton1Click:Connect(function()
		for _, b in ipairs(sim.selectedBodies) do
			b.pattern = patName
			applyBodyAppearance(b)
		end
	end)
end

local AppNameBtn = makeButton(AppearancePanel, "Show Name: OFF", UDim2.fromOffset(8, 156), UDim2.fromOffset(100, 22), 29)
local AppComBtn = makeButton(AppearancePanel, "Show COM: ON", UDim2.fromOffset(114, 156), UDim2.fromOffset(100, 22), 29)
local AppTrackBtn = makeButton(AppearancePanel, "Track Path: OFF", UDim2.fromOffset(8, 184), UDim2.fromOffset(100, 22), 29)
local AppDoneBtn = makeButton(AppearancePanel, "OK", UDim2.fromOffset(114, 184), UDim2.fromOffset(100, 22), 29)

AppNameBtn.MouseButton1Click:Connect(function()
	for _, b in ipairs(sim.selectedBodies) do b.showName = not b.showName; applyBodyAppearance(b) end
	updateAppearanceUI()
end)
AppComBtn.MouseButton1Click:Connect(function()
	for _, b in ipairs(sim.selectedBodies) do b.showCom = not b.showCom; applyBodyAppearance(b) end
	updateAppearanceUI()
end)
AppTrackBtn.MouseButton1Click:Connect(function()
	for _, b in ipairs(sim.selectedBodies) do b.trackBody = not b.trackBody end
	updateAppearanceUI()
end)
AppDoneBtn.MouseButton1Click:Connect(function() AppearancePanel.Visible = false end)
end

updateAppearanceUI = function()
	local count = #sim.selectedBodies
	local b = sim.selectedBody
	if count == 0 or not b then
		AppTargetLbl.Text = "Select an object to customize"
		AppNameBtn.Text = "Show Name: -"
		AppComBtn.Text = "Show COM: -"
		AppTrackBtn.Text = "Track Path: -"
		return
	end
	AppTargetLbl.Text = (count > 1) and ("Selected: " .. count .. " objects") or ("Selected: " .. b.name)
	AppNameBtn.Text = b.showName and "Show Name: ON" or "Show Name: OFF"
	AppComBtn.Text = (b.showCom ~= false) and "Show COM: ON" or "Show COM: OFF"
	AppTrackBtn.Text = b.trackBody and "Track Path: ON" or "Track Path: OFF"
end

--// Exact Dithered 16x16 Left Tool Palette Icons
local PIXEL_ICONS = {
	Circle = {
		"....KKKKKK....", "..KKDWDWDWKK..", ".KDWDWDWDWDWK.", ".KWDWDWDWDWDK.",
		"KDWDWDWDWDWDWK", "KWDWDWDWDWDWDK", "KDWDWDWDWDWDWK", "KWDWDWDWDWDWDK",
		".KDWDWDWDWDWK.", ".KWDWDWDWDWDK.", "..KKDWDWDWKK..", "....KKKKKK....",
	},
	Square = {
		"..............", ".KKKKKKKKKKKK.", ".KDWDWDWDWDWK.", ".KWDWDWDWDWDK.",
		".KDWDWDWDWDWK.", ".KWDWDWDWDWDK.", ".KDWDWDWDWDWK.", ".KWDWDWDWDWDK.",
		".KDWDWDWDWDWK.", ".KWDWDWDWDWDK.", ".KKKKKKKKKKKK.", "..............",
	},
	Polygon = {
		"..............", "..KKKKKKKKKK..", ".KDWDWDWDWK...", "KDWDWDWDWK....",
		"KWDWDWDWK.....", "KDWDWDWDWKK...", "KWDWDWDWDWDKK.", "KKKKKKKKKKKKKK",
		"..............", "..............", "..............", "..............",
	},
	CurvedPoly = {
		"...KKKKKK.....", ".KKDWDWDWKK...", "KDWDWDWDWDWK..", "KWDWDWDWDWDK..",
		"KDWDWDWDWDK...", ".KWDWDWDWKK...", "..KDWDWDWDWKK.", "..KWDWDWDWDWDK",
		"...KDWDWDWDWK.", "....KKKKKKKK..", "..............", "..............",
	},
	Rect = {
		"..............", "..............", "KKKKKKKKKKKKKK", "KDWDWDWDWDWDWK",
		"KWDWDWDWDWDWDK", "KDWDWDWDWDWDWK", "KWDWDWDWDWDWDK", "KDWDWDWDWDWDWK",
		"KWDWDWDWDWDWDK", "KKKKKKKKKKKKKK", "..............", "..............",
	},
	Anchor = {
		".....KKKK.....", "....K....K....", ".....KKKK.....", "......KK......",
		"......KK......", ".K....KK....K.", "KK....KK....KK", ".KK...KK...KK.",
		"..KK..KK..KK..", "....KKKKKK....", "..............", "..............",
	},
	Point = {
		"..............", "..............", "..............", ".....KKKK.....",
		"....KWWWWK....", "....KWWWWK....", ".....KKKK.....", "..............",
		"..............", "..............", "..............", "..............",
	},
	SqPoint = {
		"..............", "..............", "..............", "....KKKKKK....",
		"....KWWWWK....", "....KWWWWK....", "....KKKKKK....", "..............",
		"..............", "..............", "..............", "..............",
	},
	HSlot = {
		"..............", "..............", "KKKKKKKKKKKKKK", "DWDWDWDWDWDWDW",
		"WDWDWDWDWDWDWD", "DWDWDWDWDWDWDW", "KKKKKKKKKKKKKK", "..............",
		"..............", "..............", "..............", "..............",
	},
	VSlot = {
		"....K....K....", "....KDWDWK....", "....KWDWDK....", "....KDWDWK....",
		"....KWDWDK....", "....KDWDWK....", "....KWDWDK....", "....KDWDWK....",
		"....K....K....", "..............", "..............", "..............",
	},
	CSlot = {
		".......KKKKK..", ".....KKDWDWD..", "....KDWDW.....", "...KWDW..KKK..",
		"..KDWD..KK....", "..KWD..K......", ".KDW..K.......", ".KWD..K.......",
		"..............", "..............", "..............", "..............",
	},
	Pin = {
		"....KKKKKK....", "..KKDDDDDDKK..", ".KDDKKKKKKDDK.", ".KDKWWWWWWKDK.",
		".KDKWWWWWWKDK.", ".KDKWWWWWWKDK.", ".KDDKKKKKKDDK.", "..KKDDDDDDKK..",
		"....KKKKKK....", "..............", "..............", "..............",
	},
	RigidJoint = {
		"...K......K...", "...KKKKKKKK...", "...KDWKKWDK...", "...KWDKKDWK...",
		"...KKKKKKKK...", "...K......K...", "..............", "..............",
		"..............", "..............", "..............", "..............",
	},
	KeySlot = {
		"....KKKKKK....", "...KDDDDDDK...", "..KDDKKKKDDK..", "..KDKWWWWKDK..",
		"...KDDDDDDK...", "....KKKKKK....", "..............", "..............",
		"..............", "..............", "..............", "..............",
	},
	PinSlot = {
		"..............", ".KKKKKKKKKKKK.", ".DWDWDKKDWDWD.", ".....KWWK.....",
		".WDWDWKKWDWDW.", ".KKKKKKKKKKKK.", "..............", "..............",
		"..............", "..............", "..............", "..............",
	},
	Motor = {
		"...KKKKKKKK...", "..KDDDDDDDDK..", ".KDDKKKKKKDDK.", ".KDKWWWWWWKDK.",
		".KDKWWKKWWKDK.", ".KDKWWWWWWKDK.", ".KDDKKKKKKDDK.", "..KDDDDDDDDK..",
		"...KKKKKKKK...", "..............", "..............", "..............",
	},
	Gear = {
		"....K.KK.K....", "..KKKKKKKKKK..", ".KDDDKKKKDDDK.", "KKDKWWWWWWKDKK",
		".KDKWWKKWWKDK.", "KKDKWWWWWWKDKK", ".KDDDKKKKDDDK.", "..KKKKKKKKKK..",
		"....K.KK.K....", "..............", "..............", "..............",
	},
	GearPair = {
		".KKKK.........", "KDDDDK..KKKK..", ".KKKK..KDDDDK.", "........KKKK..",
		"..............", "..............", "..............", "..............",
		"..............", "..............", "..............", "..............",
	},
	TorSpring = {
		"....KKKKKK....", "..KK......KK..", ".K...KKKK...K.", ".K..K....K..K.",
		"..KK.KKK......", "....K.........", "..............", "..............",
		"..............", "..............", "..............", "..............",
	},
	Spring = {
		"......KK......", "......KK......", "...KKKKKKKK...", "..KK..........",
		"...KKKKKKKK...", "..........KK..", "...KKKKKKKK...", "..KK..........",
		"......KK......", "......KK......", "..............", "..............",
	},
	TorDamper = {
		"...KKKKKK.....", "..K......K....", ".K...KK...K...", ".K...KK...K...",
		"..K......K....", "...KKKKKK.....", "..............", "..............",
		"..............", "..............", "..............", "..............",
	},
	Damper = {
		"......KK......", "...KKKKKKKK...", "...K......K...", "...K..KK..K...",
		"...K..KK..K...", "......KK......", "......KK......", "......KK......",
		"..............", "..............", "..............", "..............",
	},
	Pulley = {
		".K..........K.", ".KK........KK.", "..KK......KK..", "...KKKKKKKK...",
		"......KK......", "......KK......", "..............", "..............",
		"..............", "..............", "..............", "..............",
	},
	Rope = {
		"..........KKKK", ".........KK...", "........KK....", ".......KK.....",
		"......KK......", ".....KK.......", "....KK........", "...KK.........",
		"KKKK..........", "..............", "..............", "..............",
	},
	RotForce = {
		"...KKKKKK.....", "..K......K....", ".K.......KK...", ".K......KKKK..",
		".K............", "..K......K....", "...KKKKKK.....", "..............",
		"..............", "..............", "..............", "..............",
	},
	Force = {
		"........KK....", "........KDK...", "........KDDK..", ".KKKKKKKKDDDK.",
		".KDDDDDDDDDDDK", ".KKKKKKKKDDDK.", "........KDDK..", "........KDK...",
		"........KK....", "..............", "..............", "..............",
	},
	Sep = {
		"..............", "..KKKKKKKKKK..", "......KK......", "......KK......",
		"......KK......", "......KK......", "..KKKKKKKKKK..", "..............",
		"..............", "..............", "..............", "..............",
	},
	Rod = {
		".........KKKK.", "........K...K.", ".......K...K..", "......K...K...",
		".....K...K....", "....K...K.....", "...K...K......", ".KKKK.........",
		"..............", "..............", "..............", "..............",
	},
	Actuator = {
		"...K......K...", "...KKKKKKKK...", "...K......K...", "KKKKKKKK......",
		"...K......K...", "...KKKKKKKK...", "...K......K...", "..............",
		"..............", "..............", "..............", "..............",
	},
}

for id, rows in pairs(PIXEL_ICONS) do if XPK.icons[id] then XPK.iconByRows[rows] = id end end
local ICON_PALETTE = { K = C.Text, W = C.WinLight, D = C.WinDark }

do
	local topLookup = {}
	for _, it in ipairs(tbGroup1) do topLookup[it.id] = it.rows end
	for _, it in ipairs(tbGroup2) do topLookup[it.id] = it.rows end

	local helpY = 6
	local function addHelpHeader(title)
		local hdr = Instance.new("TextLabel")
		hdr.Size = UDim2.new(1, -12, 0, 18); hdr.Position = UDim2.fromOffset(6, helpY)
		hdr.BackgroundColor3 = Color3.fromRGB(220, 224, 232); hdr.BorderSizePixel = 0
		hdr.Font = Enum.Font.ArialBold; hdr.Text = " " .. title
		hdr.TextColor3 = C.TitleActive; hdr.TextSize = 11; hdr.TextXAlignment = Enum.TextXAlignment.Left
		hdr.ZIndex = 32; hdr.Parent = HelpScroll
		helpY += 22
	end

	local function addHelpRow(spriteRows, pal, offX, offY, badgeText, title, desc)
		local rowH = 28
		local iconBox = Instance.new("Frame")
		iconBox.Size = UDim2.fromOffset(24, 22); iconBox.Position = UDim2.fromOffset(6, helpY + 2)
		iconBox.BackgroundColor3 = C.WinBg; iconBox.BorderSizePixel = 0; iconBox.ZIndex = 32; iconBox.Parent = HelpScroll
		createBevel(iconBox, false)
		if spriteRows then
			drawPixelArt(iconBox, spriteRows, pal, 1, offX, offY, 34)
		elseif badgeText then
			local bl = Instance.new("TextLabel")
			bl.Size = UDim2.fromScale(1, 1); bl.BackgroundTransparency = 1
			bl.Font = Enum.Font.ArialBold; bl.Text = badgeText
			bl.TextColor3 = C.Text; bl.TextSize = 9; bl.ZIndex = 34; bl.Parent = iconBox
		end

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -40, 0, rowH); lbl.Position = UDim2.fromOffset(35, helpY)
		lbl.BackgroundTransparency = 1; lbl.Font = UI_FONT; lbl.TextWrapped = true; lbl.RichText = true
		lbl.Text = "<b>" .. title .. ":</b> " .. desc
		lbl.TextColor3 = C.Text; lbl.TextSize = 10
		lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextYAlignment = Enum.TextYAlignment.Center
		lbl.ZIndex = 32; lbl.Parent = HelpScroll
		helpY += rowH + 2
	end

	addHelpHeader("Top Toolbar")
	addHelpRow(topLookup.New, tbPal, 4, 4, nil, "New", "Clear the canvas and reset to a blank workspace.")
	addHelpRow(topLookup.Open, tbPal, 4, 4, nil, "Open", "Load a built-in physics demo (Pendulum or Pulley).")
	addHelpRow(topLookup.Save, tbPal, 4, 4, nil, "Save", "Save current object positions as the Reset state.")
	addHelpRow(topLookup.Cut, tbPal, 4, 4, nil, "Cut", "Remove selected objects and copy them to clipboard.")
	addHelpRow(topLookup.Copy, tbPal, 4, 4, nil, "Copy", "Copy selected objects without removing them.")
	addHelpRow(topLookup.Paste, tbPal, 4, 4, nil, "Paste", "Spawn copied objects onto the canvas.")
	addHelpRow(topLookup.Select, tbPal, 4, 4, nil, "Pointer", "Select/drag objects. Hold 0.35s for multi-select box.")
	addHelpRow(topLookup.Rotate, tbPal, 4, 4, nil, "Rotate", "Drag around a body to spin its starting angle.")
	addHelpRow(topLookup.Text, tbPal, 4, 4, nil, "Text", "Click the canvas to place an editable text label.")
	addHelpRow(topLookup.ZoomIn, tbPal, 4, 4, nil, "Zoom In / Out", "Zoom the camera view in or out.")

	addHelpHeader("Shapes, Anchor & Join/Split")
	addHelpRow(PIXEL_ICONS.Circle, ICON_PALETTE, 5, 5, nil, "Circle", "Drag to draw a round ball.")
	addHelpRow(PIXEL_ICONS.Square, ICON_PALETTE, 5, 5, nil, "Square", "Drag to draw a square block.")
	addHelpRow(PIXEL_ICONS.Polygon, ICON_PALETTE, 5, 5, nil, "Polygon", "Tap corners; tap the green start dot to close.")
	addHelpRow(PIXEL_ICONS.CurvedPoly, ICON_PALETTE, 5, 5, nil, "Freehand Draw", "Drag to draw a custom curved polygon shape.")
	addHelpRow(PIXEL_ICONS.Rect, ICON_PALETTE, 5, 5, nil, "Rectangle", "Drag to draw a block or platform.")
	addHelpRow(PIXEL_ICONS.Anchor, ICON_PALETTE, 5, 5, nil, "Anchor", "Tap a body to pin/unpin it in place.")
	addHelpRow(nil, nil, 0, 0, "Join", "Join / Split", "Weld selected bodies together or remove all joints.")

	addHelpHeader("Below Join/Split — Points & Slots")
	addHelpRow(PIXEL_ICONS.Point, ICON_PALETTE, 5, 5, nil, "Point / Sq. Point", "Toggle center-of-mass dot tracking on a body.")
	addHelpRow(PIXEL_ICONS.HSlot, ICON_PALETTE, 5, 5, nil, "Horiz. Slot", "Lock a body to slide horizontally along X.")
	addHelpRow(PIXEL_ICONS.VSlot, ICON_PALETTE, 5, 5, nil, "Vert. Slot", "Lock a body to slide vertically along Y.")
	addHelpRow(PIXEL_ICONS.CSlot, ICON_PALETTE, 5, 5, nil, "Curved Slot", "Pin a body along a curved arc pivot.")
	addHelpRow(PIXEL_ICONS.Pin, ICON_PALETTE, 5, 5, nil, "Pin Joint", "Tap a body to create a pendulum hinge pivot.")

	addHelpHeader("Joints, Motors & Gears")
	addHelpRow(PIXEL_ICONS.RigidJoint, ICON_PALETTE, 5, 5, nil, "Rigid Joint", "Drag between two bodies to weld them together.")
	addHelpRow(PIXEL_ICONS.KeySlot, ICON_PALETTE, 5, 5, nil, "Keyed / Pin Slot", "Pin a body into a constrained slot pivot.")
	addHelpRow(PIXEL_ICONS.Motor, ICON_PALETTE, 5, 5, nil, "Motor", "Tap a body to toggle continuous rotation.")
	addHelpRow(PIXEL_ICONS.Gear, ICON_PALETTE, 5, 5, nil, "Gear", "Tap a body to toggle gear drive spin.")
	addHelpRow(PIXEL_ICONS.GearPair, ICON_PALETTE, 5, 5, nil, "Gear Pair", "Drag between two bodies to spin in opposite directions.")

	addHelpHeader("Springs, Forces & Constraints")
	addHelpRow(PIXEL_ICONS.Spring, ICON_PALETTE, 5, 5, nil, "Spring", "Drag between bodies (or world) for an elastic spring.")
	addHelpRow(PIXEL_ICONS.TorSpring, ICON_PALETTE, 5, 5, nil, "Tor. Spring", "Tap a body to add rotational spring return torque.")
	addHelpRow(PIXEL_ICONS.Damper, ICON_PALETTE, 5, 5, nil, "Damper", "Drag between bodies to slow relative motion.")
	addHelpRow(PIXEL_ICONS.TorDamper, ICON_PALETTE, 5, 5, nil, "Tor. Damper", "Tap a body to damp its spin speed.")
	addHelpRow(PIXEL_ICONS.Pulley, ICON_PALETTE, 5, 5, nil, "Pulley", "Drag from a body to hang a pulley tether.")
	addHelpRow(PIXEL_ICONS.Rope, ICON_PALETTE, 5, 5, nil, "Rope", "Drag between bodies for a flexible tether.")
	addHelpRow(PIXEL_ICONS.Force, ICON_PALETTE, 5, 5, nil, "Force", "Drag from a body to set its launch velocity.")
	addHelpRow(PIXEL_ICONS.RotForce, ICON_PALETTE, 5, 5, nil, "Rot. Force", "Drag from a body to give it initial spin.")
	addHelpRow(PIXEL_ICONS.Sep, ICON_PALETTE, 5, 5, nil, "Separator", "Drag between bodies to push them apart if too close.")
	addHelpRow(PIXEL_ICONS.Rod, ICON_PALETTE, 5, 5, nil, "Rod", "Drag between bodies to lock a rigid distance.")
	addHelpRow(PIXEL_ICONS.Actuator, ICON_PALETTE, 5, 5, nil, "Actuator", "Drag between bodies for an oscillating piston.")

	HelpScroll.CanvasSize = UDim2.fromOffset(0, helpY + 8)
end

local toolButtons = {}
local function setActiveTool(id)
	sim.activeTool = id
	for mid, mb in pairs(macStripBtns) do
		if mid ~= "MacRun" and mid ~= "MacReset" then
			local on = (mid == id)
			mb.BackgroundColor3 = on and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
			mb.TextColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(0, 0, 0)
		end
	end
	for tid, btn in pairs(toolButtons) do
		local active = (tid == id)
		btn.BackgroundColor3 = active and Color3.fromRGB(235, 235, 235) or C.WinBg
		createBevel(btn, active)
	end
	for _, tid in ipairs({ "Select", "Rotate", "Text" }) do
		if tbBtns[tid] then
			local active = (tid == id)
			tbBtns[tid].BackgroundColor3 = active and Color3.fromRGB(235, 235, 235) or C.WinBg
			createBevel(tbBtns[tid], active)
		end
	end
end

local palY = 4
local function addPaletteGrid(items)
	for idx, id in ipairs(items) do
		local col = (idx - 1) % 2
		local row = math.floor((idx - 1) / 2)
		local btn = makeButton(ToolPalette, "", UDim2.fromOffset(3 + col * 25, palY + row * 23), UDim2.fromOffset(24, 22), 4)
		if PIXEL_ICONS[id] then
			drawPixelArt(btn, PIXEL_ICONS[id], ICON_PALETTE, 1, 5, 5, btn.ZIndex + 2)
		end
		btn.MouseButton1Click:Connect(function() setActiveTool(id) end)
		toolButtons[id] = btn
	end
	palY += math.ceil(#items / 2) * 23 + 5
end

addPaletteGrid({ "Circle", "Square", "Polygon", "CurvedPoly", "Rect", "Anchor" })

local JoinBtn = makeButton(ToolPalette, "Join (o)", UDim2.fromOffset(3, palY), UDim2.fromOffset(49, 18), 4, C.DisabledText)
local SplitBtn = makeButton(ToolPalette, "Split o-o", UDim2.fromOffset(3, palY + 19), UDim2.fromOffset(49, 18), 4, C.DisabledText)
JoinBtn.TextSize = 10; SplitBtn.TextSize = 10
palY += 41

JoinBtn.MouseButton1Click:Connect(function()
	if #sim.selectedBodies >= 2 then
		for i = 1, #sim.selectedBodies - 1 do createConstraint("RigidJoint", sim.selectedBodies[i], sim.selectedBodies[i + 1]) end
		updateConstraintVisuals()
	elseif #sim.selectedBodies == 1 then
		createConstraint("Pin", sim.selectedBodies[1], nil, sim.selectedBodies[1].x, sim.selectedBodies[1].y)
		updateConstraintVisuals()
	end
end)

SplitBtn.MouseButton1Click:Connect(function()
	for _, b in ipairs(sim.selectedBodies) do
		b.slotMode = nil
		for i = #sim.constraints, 1, -1 do
			local c = sim.constraints[i]
			if c.bodyA == b or c.bodyB == b then
				if c.pinDot then c.pinDot:Destroy() end
				if c.ropeLine then c.ropeLine:Destroy() end
				if c.rodLine then c.rodLine:Destroy() end
				if c.damperLine then c.damperLine:Destroy() end
				for _, s in ipairs(c.segs) do s:Destroy() end
				table.remove(sim.constraints, i)
			end
		end
	end
end)

addPaletteGrid({ "Point", "SqPoint", "HSlot", "VSlot", "CSlot", "Pin" })
addPaletteGrid({ "RigidJoint", "KeySlot", "PinSlot", "Motor", "Gear", "GearPair" })
addPaletteGrid({ "TorSpring", "Spring", "TorDamper", "Damper", "Pulley", "Rope", "RotForce", "Force", "Sep", "Rod", "Actuator" })

ToolPalette.CanvasSize = UDim2.fromOffset(0, palY + 6)
-- (Addtion-Scripts) the toolbar's and the tool palette's picture buttons are flat in the XP theme (no outline until touched)
for _, holder in ipairs({ TopToolbar, ToolPalette }) do
	for _, b in ipairs(holder:GetChildren()) do
		if b:IsA("TextButton") and b.Text == "" then XPK.flat[b] = true end
	end
end
setActiveTool("Select")

tbBtns.Select.MouseButton1Click:Connect(function() setActiveTool("Select") end)
tbBtns.Rotate.MouseButton1Click:Connect(function() setActiveTool("Rotate") end)
tbBtns.Text.MouseButton1Click:Connect(function() setActiveTool("Text") end)
tbBtns.New.MouseButton1Click:Connect(clearAll)
tbBtns.Cut.MouseButton1Click:Connect(cutSelected)
tbBtns.Copy.MouseButton1Click:Connect(copySelected)
tbBtns.Paste.MouseButton1Click:Connect(pasteClipboard)
tbBtns.Help.MouseButton1Click:Connect(function() HelpPanel.Visible = not HelpPanel.Visible end)
tbBtns.Save.MouseButton1Click:Connect(snapshotInitialStates)

local function loadPreset(name)
	clearAll()
	TitleLabel.Text = "Interactive Physics - [" .. name .. "]"
	if name == "Pendulum" then
		local bob = createBody("Circle", 300, 130, 38, 38)
		createConstraint("Pin", bob, nil, 200, 45)
		snapshotInitialStates(); selectBody(bob)
	elseif name == "SpringOscillator" then
		local top = createBody("Rect", 260, 40, 56, 20, Color3.fromRGB(150, 200, 245))
		top.anchored = true; top.anchorTag.Visible = true
		local mass = createBody("Rect", 260, 180, 48, 40)
		local sp = createConstraint("Spring", top, mass, nil, nil, 45)
		sp.restLength = 95; updateConstraintVisuals()
		snapshotInitialStates(); selectBody(mass)
	end
end
tbBtns.Open.MouseButton1Click:Connect(function() loadPreset("Pendulum") end)

--// Classic Menu Bar
local activeDropdown = nil
local function closeDropdown()
	if activeDropdown then activeDropdown:Destroy(); activeDropdown = nil end
end

local MENUS = {
	{ name = "File", items = {
		{ text = "New", fn = function() clearAll(); TitleLabel.Text = "Interactive Physics - [Untitled1]" end },
		{ text = "Demo: Pendulum", fn = function() loadPreset("Pendulum") end },
		{ text = "Demo: Spring Mass", fn = function() loadPreset("SpringOscillator") end },
		{ text = "Exit (Leave Game)", fn = exitInteractivePhysics },
	}},
	{ name = "Edit", items = {
		{ text = "Cut", fn = cutSelected },
		{ text = "Copy", fn = copySelected },
		{ text = "Paste", fn = pasteClipboard },
		{ text = "Select All", fn = function() setSelection(sim.bodies) end },
		{ text = "Delete Selected", fn = deleteSelected },
		{ text = "Clear All", fn = clearAll },
	}},
	{ name = "View", items = {
		{ text = "Theme (95 / XP / Mac)...", fn = function() ThemePanel.Visible = true end },
		{ text = "Toggle Grid", fn = function() sim.showGrid = not sim.showGrid; GridLayer.Visible = sim.showGrid end },
		{ text = "Reset Zoom/Pan", fn = function() WorldScale.Scale = 1; panX, panY = 0, 0; applyViewTransform() end },
	}},
	{ name = "World", items = {
		{ text = "Gravity: Earth (9.81)", fn = function() sim.gravity = 9.81 end },
		{ text = "Gravity: Moon (1.62)", fn = function() sim.gravity = 1.62 end },
		{ text = "Gravity: Zero-G (0)", fn = function() sim.gravity = 0 end },
		{ text = "Frame Rate (FPS)...", fn = function() FpsPanel.Visible = true end },
		{ text = "Toggle Floor/Walls", fn = function() sim.useBounds = not sim.useBounds end },
		{ text = "Air Drag: Off", fn = function() sim.airDrag = 0 end },
		{ text = "Air Drag: Low (0.3)", fn = function() sim.airDrag = 0.3 end },
		{ text = "Erase Tracks", fn = eraseTracks },
	}},
	{ name = "Object", items = {
		{ text = "Appearance...", fn = function() AppearancePanel.Visible = true; updateAppearanceUI() end },
		{ text = "Properties...", fn = function() PropsPanel.Visible = not PropsPanel.Visible end },
		{ text = "Anchor / Unanchor", fn = function()
			for _, b in ipairs(sim.selectedBodies) do b.anchored = not b.anchored; b.anchorTag.Visible = b.anchored end
			updatePropsUI()
		end },
	}},
	{ name = "Define", items = {
		{ text = "Velocity Vectors", fn = function() sim.showVelocityVectors = not sim.showVelocityVectors end },
		{ text = "Force Vectors", fn = function() sim.showForceVectors = not sim.showForceVectors end },
		{ text = "Track Center of Mass", fn = function() sim.showTracks = not sim.showTracks end },
	}},
	{ name = "Measure", items = {
		{ text = "Velocity Meter", fn = function() sim.showVelMeter = not sim.showVelMeter; updateMetersUI() end },
		{ text = "Energy Meter", fn = function() sim.showEnergyMeter = not sim.showEnergyMeter; updateMetersUI() end },
	}},
	{ name = "Script", items = {} },
	{ name = "Window", items = {
		{ text = "Theme...", fn = function() ThemePanel.Visible = not ThemePanel.Visible end },
		{ text = "Appearance...", fn = function() AppearancePanel.Visible = not AppearancePanel.Visible; updateAppearanceUI() end },
		{ text = "Properties", fn = function() PropsPanel.Visible = not PropsPanel.Visible end },
	}},
	{ name = "Help", items = {
		{ text = "Contents...", fn = function() HelpPanel.Visible = true end },
		{ text = "About Interactive Physics...", fn = function() HelpPanel.Visible = true end },
	}},
}

drawPixelArt(MenuBar, {
	".KKKKKKKK......", ".KWWWWWWKK.....", ".KWWWWWWRWK....", ".KWPPWWWRKKKK..",
	".KPPPKGGGGGGK..", ".KPPPKGGTGTTG..", ".KBBBKGGGGGGK..", ".KWWYKGGTGTTG..",
	".KGGYKGGGGGGK..", ".KGGYKGGTGTTG..", ".KGGYKGGGGGGK..", ".KKKKKKKKKKKK..",
}, {
	K = C.Text, W = C.WinLight, R = Color3.fromRGB(235, 25, 25),
	P = Color3.fromRGB(130, 60, 175), B = Color3.fromRGB(45, 45, 145),
	Y = Color3.fromRGB(245, 225, 30), G = Color3.fromRGB(195, 195, 195),
	T = Color3.fromRGB(0, 135, 135),
}, 1, 3, 4, 22, "MDIDocIcon")
do
local curMenuX = 20
for _, menu in ipairs(MENUS) do
	local mw = (#menu.name * 7) + 12
	local mBtn = Instance.new("TextButton")
	mBtn.Size = UDim2.fromOffset(mw, 19); mBtn.Position = UDim2.fromOffset(curMenuX, 0)
	trackChrome(mBtn); mBtn.BackgroundColor3 = C.WinBg; mBtn.BorderSizePixel = 0; mBtn.Font = UI_FONT
	mBtn.Text = menu.name; mBtn.TextColor3 = C.Text; mBtn.TextSize = 12; mBtn.ZIndex = 22; mBtn.Parent = MenuBar
	local dropX = curMenuX; curMenuX += mw

	mBtn.MouseButton1Click:Connect(function()
		if #menu.items == 0 then closeDropdown(); return end
		if activeDropdown and activeDropdown.Name == "Drop_" .. menu.name then closeDropdown(); return end
		closeDropdown()
		local drop = Instance.new("Frame")
		drop.Name = "Drop_" .. menu.name; drop.Size = UDim2.fromOffset(174, #menu.items * 20 + 4)
		drop.Position = UDim2.fromOffset(math.min(dropX, 300), 42); drop.BackgroundColor3 = C.WinBg
		drop.BorderSizePixel = 0; drop.ZIndex = 35; drop.Parent = MainWindow
		createBevel(drop, false); activeDropdown = drop

		for i, item in ipairs(menu.items) do
			local ib = Instance.new("TextButton")
			ib.Size = UDim2.new(1, -4, 0, 18); ib.Position = UDim2.fromOffset(2, 2 + (i - 1) * 20)
			ib.BackgroundColor3 = C.WinBg; ib.BorderSizePixel = 0; ib.Font = UI_FONT
			ib.Text = " " .. item.text; ib.TextColor3 = C.Text; ib.TextSize = 11
			ib.TextXAlignment = Enum.TextXAlignment.Left; ib.ZIndex = 36; ib.Parent = drop
			ib.MouseButton1Click:Connect(function() closeDropdown(); item.fn(); updateTapeUI() end)
		end
	end)
end
end

--// Canvas Pointer Interaction
local function getCanvasPos(input)
	local s = WorldScale.Scale * WindowScale.Scale
	local abs = WorldContainer.AbsolutePosition
	return (input.Position.X - abs.X) / s, (input.Position.Y - abs.Y) / s
end

local function findBodyAt(x, y)
	for i = #sim.bodies, 1, -1 do
		local b = sim.bodies[i]
		if b.kind == "Circle" then
			local r = b.w * 0.5 + 6
			if (x - b.x)^2 + (y - b.y)^2 <= r * r then return b end
		else
			local p = getBodyWorldPoly(b)
			if x >= p.minX - 6 and x <= p.maxX + 6 and y >= p.minY - 6 and y <= p.maxY + 6 then
				if pointInPoly(x, y, p.verts) then return b end
				local _, _, _, _, d2 = closestPointOnPolyEdges(x, y, p.verts)
				if d2 <= 36 then return b end
			end
		end
	end
	return nil
end

local dragState = {
	active = false, activeInput = nil, mode = nil, startX = 0, startY = 0, lastX = 0, lastY = 0,
	moved = false, holdToken = 0, targetBody = nil, preview = nil,
	freePoints = {}, polyPoints = {},
}

local function finishCustomPolygon(pts, doSmooth)
	if #pts < 3 then return end
	local finalPts = doSmooth and smoothPolygonPoints(pts, 2) or pts
	local minX, maxX = math.huge, -math.huge
	local minY, maxY = math.huge, -math.huge
	for _, p in ipairs(finalPts) do
		if p.X < minX then minX = p.X end; if p.X > maxX then maxX = p.X end
		if p.Y < minY then minY = p.Y end; if p.Y > maxY then maxY = p.Y end
	end
	local w = math.max(18, math.floor(maxX - minX))
	local h = math.max(18, math.floor(maxY - minY))
	local localPts = {}
	for _, p in ipairs(finalPts) do table.insert(localPts, Vector2.new(p.X - minX, p.Y - minY)) end
	local b = createBody("Polygon", (minX + maxX) * 0.5, (minY + maxY) * 0.5, w, h, nil, localPts)
	selectBody(b)
end

local function clearPolyPreview()
	for _, ch in ipairs(PreviewLayer:GetChildren()) do ch:Destroy() end
end

local function startMarqueeBox(x, y)
	dragState.mode = "Marquee"
	if dragState.preview then dragState.preview:Destroy() end
	local box = Instance.new("Frame")
	local mCol = (currentThemeMode == "Mac80s") and Color3.fromRGB(0, 0, 0) or C.Marquee
	box.BackgroundColor3 = mCol; box.BackgroundTransparency = (currentThemeMode == "Mac80s") and 0.9 or 0.82; box.BorderSizePixel = 0
	box.Position = UDim2.fromOffset(x, y); box.Size = UDim2.fromOffset(1, 1); box.ZIndex = 10; box.Parent = PreviewLayer
	local st = Instance.new("UIStroke"); st.Thickness = 1.5; st.Color = mCol; st.Parent = box
	dragState.preview = box
end

Canvas.InputBegan:Connect(function(input)
	if not isPointerBegin(input) then return end
	if dragState.active then return end
	closeDropdown()
	if dragState.preview then dragState.preview:Destroy(); dragState.preview = nil end
	local x, y = getCanvasPos(input)
	local hit = findBodyAt(x, y)

	if sim.activeTool == "Select" then
		dragState.active = true; dragState.activeInput = input; dragState.startX, dragState.startY = x, y
		dragState.lastX, dragState.lastY = x, y; dragState.moved = false
		dragState.holdToken += 1; local token = dragState.holdToken

		if hit then
			if not isBodySelected(hit) then selectBody(hit) end
			dragState.mode = "Move"; dragState.targetBody = hit
			task.delay(0.35, function()
				if dragState.active and dragState.holdToken == token and not dragState.moved then
					startMarqueeBox(dragState.startX, dragState.startY)
				end
			end)
		else
			clearSelection(); startMarqueeBox(x, y)
		end
	elseif sim.activeTool == "CurvedPoly" then
		dragState.active = true; dragState.activeInput = input; dragState.mode = "Freehand"
		dragState.freePoints = { Vector2.new(x, y) }
		dragState.lastX, dragState.lastY = x, y
		clearPolyPreview()
	elseif sim.activeTool == "Polygon" then
		local pts = dragState.polyPoints
		if #pts >= 3 and (Vector2.new(x, y) - pts[1]).Magnitude <= 14 then
			clearPolyPreview(); finishCustomPolygon(pts, false); dragState.polyPoints = {}
		else
			table.insert(pts, Vector2.new(x, y))
			local dot = Instance.new("Frame")
			dot.Size = UDim2.fromOffset(5, 5); dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Position = UDim2.fromOffset(x, y); dot.BackgroundColor3 = (#pts == 1) and C.RunGreen or C.Text
			dot.BorderSizePixel = 0; dot.ZIndex = 10; dot.Parent = PreviewLayer
			if #pts >= 2 then
				local seg = drawLineFrame(PreviewLayer, "PolyPrev", C.Text, 9)
				updateLine(seg, pts[#pts - 1].X, pts[#pts - 1].Y, x, y, 1.5)
			end
		end
	elseif sim.activeTool == "Rotate" then
		selectBody(hit)
		if hit then dragState.active = true; dragState.activeInput = input; dragState.mode = "Rotate"; dragState.targetBody = hit end
	elseif sim.activeTool == "Text" then
		local lbl = Instance.new("TextBox")
		lbl.Size = UDim2.fromOffset(120, 22); lbl.Position = UDim2.fromOffset(x, y)
		lbl.BackgroundTransparency = 1; lbl.Font = UI_FONT; lbl.Text = "Label"
		lbl.TextColor3 = C.Text; lbl.TextSize = 13; lbl.ZIndex = 8; lbl.Parent = BodyLayer
		table.insert(sim.labels, lbl); lbl:CaptureFocus()
	elseif sim.activeTool == "Anchor" and hit then
		hit.anchored = not hit.anchored; hit.anchorTag.Visible = hit.anchored; selectBody(hit)
	elseif (sim.activeTool == "Point" or sim.activeTool == "SqPoint") and hit then
		hit.trackBody = not hit.trackBody; selectBody(hit)
	elseif sim.activeTool == "HSlot" and hit then
		hit.slotMode = (hit.slotMode == "H") and nil or "H"; selectBody(hit)
	elseif sim.activeTool == "VSlot" and hit then
		hit.slotMode = (hit.slotMode == "V") and nil or "V"; selectBody(hit)
	elseif (sim.activeTool == "Motor" or sim.activeTool == "Gear") and hit then
		hit.motorSpeed = (hit.motorSpeed == 0) and 3.0 or 0; selectBody(hit)
	elseif sim.activeTool == "TorSpring" and hit then
		hit.torSpringK = (hit.torSpringK == 0) and 15.0 or 0; selectBody(hit)
	elseif sim.activeTool == "TorDamper" and hit then
		hit.torDamperC = (hit.torDamperC == 0) and 4.0 or 0; selectBody(hit)
	elseif sim.activeTool == "Circle" or sim.activeTool == "Square" or sim.activeTool == "Rect" then
		dragState.active = true; dragState.activeInput = input; dragState.mode = "Draw"; dragState.startX, dragState.startY = x, y
		local pv = Instance.new("Frame")
		pv.BackgroundColor3 = (currentThemeMode == "Mac80s") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 200, 240); pv.BackgroundTransparency = 0.65
		pv.BorderColor3 = Color3.fromRGB(0, 0, 0); pv.BorderSizePixel = 1; pv.ZIndex = 9; pv.Parent = PreviewLayer
		dragState.preview = pv
	elseif (sim.activeTool == "Pin" or sim.activeTool == "KeySlot" or sim.activeTool == "PinSlot" or sim.activeTool == "CSlot") and hit then
		createConstraint("Pin", hit, nil, x, y); updateConstraintVisuals()
	elseif hit then
		dragState.active = true; dragState.activeInput = input; dragState.mode = "Constraint"
		dragState.startX, dragState.startY = hit.x, hit.y; dragState.targetBody = hit
		dragState.preview = drawLineFrame(PreviewLayer, "DragLine", currentThemeMode == "Mac80s" and Color3.fromRGB(0, 0, 0) or C.VectorForce, 9)
	end
end)

local finishCanvasDrag

UserInputService.InputChanged:Connect(function(input)
	if not dragState.active then return end
	if dragState.activeInput and dragState.activeInput.UserInputType == Enum.UserInputType.Touch and input.UserInputType == Enum.UserInputType.Touch and input ~= dragState.activeInput then return end
	if input.UserInputState == Enum.UserInputState.End or input.UserInputState == Enum.UserInputState.Cancel then
		finishCanvasDrag(input)
		return
	end
	if not isPointerMove(input) then return end
	local x, y = getCanvasPos(input)
	if math.abs(x - dragState.startX) > 6 or math.abs(y - dragState.startY) > 6 then dragState.moved = true end

	if dragState.mode == "Freehand" then
		if (Vector2.new(x, y) - Vector2.new(dragState.lastX, dragState.lastY)).Magnitude >= 12 then
			table.insert(dragState.freePoints, Vector2.new(x, y))
			local seg = drawLineFrame(PreviewLayer, "FreeSeg", C.Text, 9)
			updateLine(seg, dragState.lastX, dragState.lastY, x, y, 1.5)
			dragState.lastX, dragState.lastY = x, y
		end
	elseif dragState.mode == "Marquee" and dragState.preview then
		local minX, maxX = math.min(dragState.startX, x), math.max(dragState.startX, x)
		local minY, maxY = math.min(dragState.startY, y), math.max(dragState.startY, y)
		dragState.preview.Position = UDim2.fromOffset(minX, minY)
		dragState.preview.Size = UDim2.fromOffset(math.max(2, maxX - minX), math.max(2, maxY - minY))
	elseif dragState.mode == "Move" and dragState.targetBody then
		local dx, dy = x - dragState.lastX, y - dragState.lastY
		dragState.lastX, dragState.lastY = x, y
		for _, b in ipairs(sim.selectedBodies) do
			b.x += dx; b.y += dy
			if not sim.running then b.initX, b.initY = b.x, b.y else b.vx = dx * 8; b.vy = dy * 8 end
			b.ui.Position = UDim2.fromOffset(b.x, b.y)
		end
		updateConstraintVisuals(); updateCoordBar(); updateMetersUI()
	elseif dragState.mode == "Rotate" and dragState.targetBody then
		local b = dragState.targetBody
		b.angle = math.atan2(y - b.y, x - b.x); b.initAngle = b.angle
		b.ui.Rotation = math.deg(b.angle)
	elseif dragState.mode == "Draw" and dragState.preview then
		local w = math.max(18, math.abs(x - dragState.startX))
		local h = math.max(18, math.abs(y - dragState.startY))
		if sim.activeTool == "Circle" or sim.activeTool == "Square" then local s = math.max(w, h); w, h = s, s end
		dragState.preview.AnchorPoint = Vector2.new(0.5, 0.5)
		dragState.preview.Position = UDim2.fromOffset((dragState.startX + x) * 0.5, (dragState.startY + y) * 0.5)
		dragState.preview.Size = UDim2.fromOffset(w, h)
	elseif dragState.mode == "Constraint" and dragState.preview then
		updateLine(dragState.preview, dragState.startX, dragState.startY, x, y, 2)
	end
end)

finishCanvasDrag = function(input)
	if not dragState.active or not isPointerEnd(input) then return end
	if dragState.activeInput and dragState.activeInput.UserInputType == Enum.UserInputType.Touch and input.UserInputType == Enum.UserInputType.Touch and input ~= dragState.activeInput then return end
	local mode = dragState.mode
	dragState.active = false; dragState.activeInput = nil; dragState.mode = nil
	local x, y = getCanvasPos(input)
	if dragState.preview then dragState.preview:Destroy(); dragState.preview = nil end
	clearPolyPreview()

	if mode == "Freehand" then
		clearPolyPreview()
		finishCustomPolygon(dragState.freePoints, true)
		dragState.freePoints = {}
	elseif mode == "Marquee" then
		local minX, maxX = math.min(dragState.startX, x), math.max(dragState.startX, x)
		local minY, maxY = math.min(dragState.startY, y), math.max(dragState.startY, y)
		local picked = {}
		for _, b in ipairs(sim.bodies) do
			if b.x + b.w * 0.5 >= minX and b.x - b.w * 0.5 <= maxX
				and b.y + b.h * 0.5 >= minY and b.y - b.h * 0.5 <= maxY then
				table.insert(picked, b)
			end
		end
		setSelection(picked)
	elseif mode == "Draw" then
		local w = math.max(24, math.abs(x - dragState.startX))
		local h = math.max(24, math.abs(y - dragState.startY))
		if sim.activeTool == "Circle" or sim.activeTool == "Square" then local s = math.max(w, h); w, h = s, s end
		local kind = (sim.activeTool == "Circle") and "Circle" or "Rect"
		local b = createBody(kind, (dragState.startX + x) * 0.5, (dragState.startY + y) * 0.5, w, h)
		selectBody(b)
	elseif mode == "Constraint" and dragState.targetBody then
		if sim.activeTool == "Force" then
			local b = dragState.targetBody
			b.vx = (x - b.x) * 3; b.vy = (y - b.y) * 3; b.initVx = b.vx; b.initVy = b.vy
			updatePropsUI(); updateMetersUI()
		elseif sim.activeTool == "RotForce" then
			local b = dragState.targetBody
			b.omega = (x - b.x) * 0.05
			updatePropsUI()
		else
			local cKind = "Spring"
			if sim.activeTool == "Damper" then cKind = "Damper"
			elseif sim.activeTool == "Rope" or sim.activeTool == "Pulley" then cKind = sim.activeTool
			elseif sim.activeTool == "Rod" or sim.activeTool == "Actuator" or sim.activeTool == "RigidJoint" then cKind = sim.activeTool
			elseif sim.activeTool == "Sep" then cKind = "Separator"
			elseif sim.activeTool == "GearPair" then cKind = "GearPair" end
			local hitEnd = findBodyAt(x, y)
			if hitEnd and hitEnd ~= dragState.targetBody then
				createConstraint(cKind, dragState.targetBody, hitEnd)
			else
				createConstraint(cKind, dragState.targetBody, nil, x, y)
			end
			updateConstraintVisuals()
		end
	end

	dragState.active = false; dragState.activeInput = nil; dragState.mode = nil; dragState.targetBody = nil; dragState.holdToken += 1
end

UserInputService.InputEnded:Connect(finishCanvasDrag)
Canvas.InputEnded:Connect(finishCanvasDrag)
UserInputService.TouchEnded:Connect(finishCanvasDrag)

--// Simulation & Tape Player Controls
RunBtn.MouseButton1Click:Connect(function()
	if not sim.running then
		if sim.frame == 0 then snapshotInitialStates() end
		sim.running = true
	end
end)
StopBtn.MouseButton1Click:Connect(function() sim.running = false; updateTapeUI() end)
ResetBtn.MouseButton1Click:Connect(resetSimulation)
if macStripBtns.MacRun then
	macStripBtns.MacRun.MouseButton1Click:Connect(function()
		if not sim.running then
			if sim.frame == 0 then snapshotInitialStates() end
			sim.running = true
		else
			sim.running = false
		end
		updateTapeUI()
	end)
end
if macStripBtns.MacReset then
	macStripBtns.MacReset.MouseButton1Click:Connect(resetSimulation)
end
for mid, mb in pairs(macStripBtns) do
	if mid ~= "MacRun" and mid ~= "MacReset" then
		mb.MouseButton1Click:Connect(function()
			if mid == "ZoomIn" then
				WorldScale.Scale = math.clamp(WorldScale.Scale + 0.15, 0.5, 2.2)
				applyViewTransform()
			else
				setActiveTool(mid)
			end
		end)
	end
end

TapeRewindBtn.MouseButton1Click:Connect(function()
	sim.running = false; if sim.tape[0] then applyTapeFrame(0) else resetSimulation() end
end)
TapePlayBtn.MouseButton1Click:Connect(function()
	if not sim.running then
		if sim.frame == 0 then snapshotInitialStates() end
		sim.running = true
	end
end)
TapeBackBtn.MouseButton1Click:Connect(function()
	sim.running = false; if sim.frame > 0 and sim.tape[sim.frame - 1] then applyTapeFrame(sim.frame - 1) end
end)
TapeStepBtn.MouseButton1Click:Connect(function()
	sim.running = false
	if sim.frame < sim.maxFrame and sim.tape[sim.frame + 1] then applyTapeFrame(sim.frame + 1) else
		if sim.frame == 0 then snapshotInitialStates() end
		stepPhysics(1 / 60)
	end
end)

-- (Addtion-Scripts) the window opens in the Windows XP theme (Window > Theme... has the others)
if XPK.refresh then pcall(XPK.refresh, "WinXP") end

local renderConn
renderConn = RunService.RenderStepped:Connect(function(dt)
	if not ScreenGui.Parent then renderConn:Disconnect(); return end
	if sim.running then
		local fps = math.clamp(sim.targetFps or 60, 1, 60)
		if fps >= 60 then
			stepPhysics(math.min(dt, 1 / 30))
		else
			local interval = 1 / fps
			sim.fpsAccum += dt
			if sim.fpsAccum >= interval then
				sim.fpsAccum -= interval
				if sim.fpsAccum > interval then sim.fpsAccum = 0 end
				stepPhysics(math.min(interval, 1 / 12))
			end
		end
	end
end)

updateCoordBar()
updateTapeUI()
applyViewTransform()
