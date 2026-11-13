-- [[ CLASSIC FACE (Addtion-Scripts copy of the "Classic faces" gist) ]]
-- Every player's head as a classic head with a 2D face.
--
-- What it shows:
--   * the face the player really wears: the 2D face already on their head, else the face item in the
--     avatar the game gave them (any classic face, not only the ones in the list below), else the
--     classic face named like their dynamic head, else (only when the game's avatar can't be read)
--     the same from their website avatar, else the classic smile
--   * heads without a face of their own stay as they are (Roundy, Blockhead, Peabrain, the plain classic
--     head...: R6 head meshes and R15 classic head MeshParts), with the face put on
--   * heads with the face part of the head (dynamic heads: a moving face, a 3D texture, or the face drawn
--     into the head's texture, as R6 avatars show them) are covered by a classic head: the classic model
--     of their shape when they have one (the 2026 classic-shape dynamic heads: Roundy, Blockhead, Trim,
--     Barrel, Hex, ...; read from Roblox's head shape, the head item's name or its mesh), else the plain one
--
-- Nothing of the player's own is deleted: their face decals and dynamic head are only hidden, so
-- getgenv().ClassicFace.Stop() puts every head back as it was. It waits for each avatar to load, and
-- follows changes (a new head, a new face) while it runs.
-- getgenv().ClassicFace = { Start, Stop, IsRunning, Refresh }

local Env = (getgenv and getgenv()) or _G
if Env.ClassicFace and type(Env.ClassicFace.Stop) == "function" then
	pcall(Env.ClassicFace.Stop)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local AvatarEditorService = game:GetService("AvatarEditorService")

local HEAD_SCALE = Vector3.new(1.25, 1.25, 1.25)
local DEFAULT_SMILE_TEXTURE = "rbxasset://textures/face.png"
local OUR_DECAL = "BPClassicFace"
local OUR_HEAD = "ClassicHead"
local OUR_MESH = "BPClassicHeadMesh"

-- Complete 2009-2018 + 102 Classic Face Asset Database
local ALLOWED_FACES = {
	-- === 2009 ===
	{ name = ";3", catalogId = 15366173 },
	{ name = ";D", catalogId = 14812979 },
	{ name = ";P", catalogId = 16179725 },
	{ name = "Adorable Puppy", catalogId = 13038247 },
	{ name = "Aghast", catalogId = 14860490 },
	{ name = "Alien Ambassador", catalogId = 16652266 },
	{ name = "Alright", catalogId = 13479825 },
	{ name = "And then we'll take over the world!", catalogId = 11389347 },
	{ name = "Anguished", catalogId = 8560975 },
	{ name = "Bad Dog", catalogId = 10860392 },
	{ name = "Bird of Prey", catalogId = 16132506 },
	{ name = "Blerg!", catalogId = 12777646, aliases = { "blerg" } },
	{ name = "Blinky", catalogId = 14030577 },
	{ name = "Bubble Trouble", catalogId = 19396123 },
	{ name = "Check It", catalogId = 7074786, texture = "rbxassetid://7074764", extraIds = { 7074780 } },
	{ name = "Chill", catalogId = 7074764, texture = "rbxassetid://7074749" },
	{ name = "Classic Vampire", catalogId = 7074836, texture = "rbxassetid://29532362", extraIds = { 29532363, 15498335489, 15498314260 }, aliases = { "vampire" } },
	{ name = "Commando", catalogId = 10907548 },
	{ name = "Concerned", catalogId = 9250654 },
	{ name = "Crazy Abstract Artist", catalogId = 16722443 },
	{ name = "Cute Kitty", catalogId = 13038305 },
	{ name = "Cutiemouse", catalogId = 14957653 },
	{ name = "D:", catalogId = 7075502 },
	{ name = "D=", catalogId = 17138027 },
	{ name = "Daring", catalogId = 8329690, texture = "rbxassetid://15177471" },
	{ name = "Demented Mouse", catalogId = 15053024 },
	{ name = "Distaught Alien Invader", catalogId = 15967686, aliases = { "distraught alien invader" } },
	{ name = "Dizzy Face", catalogId = 10907551, aliases = { "dizzy" } },
	{ name = "Dragonface", catalogId = 16206753 },
	{ name = "Drool", catalogId = 7074893, texture = "rbxassetid://7074882" },
	{ name = "Emotionally Distressed Zombie", catalogId = 16722553 },
	{ name = "Existential Angst", catalogId = 10860397 },
	{ name = "EXtreme", catalogId = 11913646 },
	{ name = "Eyes of Azurewrath", catalogId = 18151826 },
	{ name = "Fang", catalogId = 7074864 },
	{ name = "Fearless", catalogId = 7076076 },
	{ name = "Finn McCool", catalogId = 10907549 },
	{ name = "Freckles", catalogId = 12131998 },
	{ name = "Friendly Pirate", catalogId = 7074991 },
	{ name = "Frightful", catalogId = 9250642 },
	{ name = "Ghostface", catalogId = 12467159 },
	{ name = "Glee", catalogId = 7074729, texture = "rbxassetid://7074712" },
	{ name = "Good Intentioned", catalogId = 7317793, texture = "rbxassetid://7317606" },
	{ name = "Grr!", catalogId = 19398554, aliases = { "grr" } },
	{ name = "Gt lt", catalogId = 15392366, aliases = { "><", "> <" } },
	{ name = "Hmmm...", catalogId = 7075142, aliases = { "hmmm" } },
	{ name = "Hut Hut Hike!", catalogId = 15432070 },
	{ name = "Hypnoface", catalogId = 18590118 },
	{ name = "I Am Not Amused", catalogId = 15637848, texture = "rbxassetid://15637705", aliases = { "unamused" } },
	{ name = "I Hate Noobs", catalogId = 14817393 },
	{ name = "I Lack Personal Confidence", catalogId = 10907546 },
	{ name = "I wuv u", catalogId = 11913651 },
	{ name = "ILOVEFOOTBOLL!", catalogId = 15432088 },
	{ name = "It's Go Time!", catalogId = 15470565 },
	{ name = "Jack Frost Face", catalogId = 19264845 },
	{ name = "Jungle Commando", catalogId = 11956270 },
	{ name = "Lazy Eye", catalogId = 15858199, texture = "rbxassetid://15858100" },
	{ name = "Lion", catalogId = 14957678 },
	{ name = "Love", catalogId = 11981267 },
	{ name = "Meanie", catalogId = 8560978 },
	{ name = "Meow?", catalogId = 14721863 },
	{ name = "Mischievous", catalogId = 7131541 },
	{ name = "Mr. Chuckles", catalogId = 10907550 },
	{ name = "Mr. Oinkers", catalogId = 14957638 },
	{ name = "Muttdawg", catalogId = 11604259 },
	{ name = "Mysterious", catalogId = 7131584 },
	{ name = "NetHack Addict", catalogId = 14030594 },
	{ name = "Nibbles, Devourer of Worlds", catalogId = 16359822 },
	{ name = "Ninja", catalogId = 12195462 },
	{ name = "No Z", catalogId = 11913657 },
	{ name = "O.o", catalogId = 7317765 },
	{ name = "Ochre Ogre", catalogId = 16652287 },
	{ name = "Oh Deer", catalogId = 19090393 },
	{ name = "Oh Noes Another Dog", catalogId = 16722585 },
	{ name = "Old Man Jenkins", catalogId = 15053048 },
	{ name = "Owl", catalogId = 14721851 },
	{ name = "Pieface Jellyfreckles", catalogId = 17424072 },
	{ name = "Pony Face", catalogId = 15967725 },
	{ name = "Poor Man", catalogId = 7699183 },
	{ name = "Pumpkin Face", catalogId = 16997498, extraIds = { 313095003 } },
	{ name = "Quackface McGraw", catalogId = 16132528 },
	{ name = "Quijibo", catalogId = 16206785 },
	{ name = "RAWR", catalogId = 8329682 },
	{ name = "RAWR Bear", catalogId = 14721873 },
	{ name = "Red Fang", catalogId = 16722419 },
	{ name = "Red Tango", catalogId = 16652242 },
	{ name = "Redonkulous", catalogId = 15967707 },
	{ name = "Retro Smiley", catalogId = 10770432 },
	{ name = "Rudolph", catalogId = 19090373 },
	{ name = "Sad", catalogId = 7699177 },
	{ name = "Sad Zombie", catalogId = 11604268 },
	{ name = "Sapphire Drool", catalogId = 16652218 },
	{ name = "Scarecrow Face", catalogId = 26260937, texture = "rbxassetid://26260786", aliases = { "scarecrow" } },
	{ name = "Semi Colon Open Paren", catalogId = 15366153, aliases = { ";(" } },
	{ name = "Serious Cat", catalogId = 14957667 },
	{ name = "Serious Dog", catalogId = 14957688 },
	{ name = "Shhh...", catalogId = 11913641, aliases = { "shhh" } },
	{ name = "Shy Lady", catalogId = 14250215 },
	{ name = "Silence", catalogId = 15637759 },
	{ name = "Silly Fun", catalogId = 7699174, texture = "rbxassetid://10747371", extraIds = { 10747382 } },
	{ name = "Sinister", catalogId = 7132035 },
	{ name = "Sir Rich McMoneyston, III", catalogId = 14721899 },
	{ name = "Skeletar", catalogId = 16997523 },
	{ name = "Slick Fang", catalogId = 15053069 },
	{ name = "Slobbery Villain", catalogId = 10860384 },
	{ name = "Smile", catalogId = 144075659, texture = DEFAULT_SMILE_TEXTURE, extraIds = { 144080495 }, aliases = { "classic smile" } },
	{ name = "Classic Male - Face", catalogId = 4018617474, aliases = { "classic male", "classic male v2" } },
	{ name = "Classic Female - Face", catalogId = 4018627046, aliases = { "classic female", "classic female v2" } },
	{ name = "Friendly Smile", catalogId = 616381207 },
	{ name = "Cheerful Grin", catalogId = 33321848 },
	{ name = "Happy :D", catalogId = 406000730, aliases = { "happy" } },
	{ name = "Joyful Smile", catalogId = 209995366 },
	{ name = "Friendly Trusting Smile", catalogId = 402304145 },
	{ name = "Smiling Girl", catalogId = 209994875 },
	{ name = "Overjoyed Smile", catalogId = 1428416217 },
	{ name = "Tango", catalogId = 12239036 },
	{ name = "The Big Dog", catalogId = 12195443 },
	{ name = "Toothless", catalogId = 7131915 },
	{ name = "Toothy Drool", catalogId = 8560980 },
	{ name = "Toothy Grin", catalogId = 7075434 },
	{ name = "Two Guys on a Boat", catalogId = 14721912 },
	{ name = "Visual Studio Seized Up For 45 Seconds... Again", catalogId = 11389323 },
	{ name = "Walk the Plank You Scurvy Dogs!", catalogId = 11604248 },
	{ name = "WHAAAaaa!", catalogId = 10860405 },
	{ name = "Whatchoo Talkin Bout", catalogId = 15858163, aliases = { "whatchoo talkin' bout" } },
	{ name = "Winky", catalogId = 7075459, texture = "rbxassetid://7075459", aliases = { "wink" } },
	{ name = "X x", catalogId = 7131854, aliases = { "x_x" } },
	{ name = "XD", catalogId = 7317773 },
	{ name = "Yawn", catalogId = 7075189 },
	{ name = "Yuck!", catalogId = 9250647 },
	{ name = "ZOMG", catalogId = 8329686 },
	{ name = "ZOMG Hat Selling!", catalogId = 14030559 },

	-- === 2010 ===
	{ name = "Adoration", catalogId = 23932048 },
	{ name = "Alien", catalogId = 28999228 },
	{ name = "Awesome Face", catalogId = 30394850 },
	{ name = "Awkward", catalogId = 23645491 },
	{ name = "Bandage", catalogId = 20418616 },
	{ name = "Bling", catalogId = 23219022 },
	{ name = "Braces", catalogId = 21802396 },
	{ name = "Butterfly", catalogId = 26619070 },
	{ name = "Camoface", catalogId = 26424652 },
	{ name = "Clown Face", catalogId = 21635565 },
	{ name = "Clown School Dropout", catalogId = 36795292 },
	{ name = "Daydreaming", catalogId = 29296146 },
	{ name = "Disbelief", catalogId = 20337343, aliases = { "disbelief face" } },
	{ name = "Downcast", catalogId = 21352013 },
	{ name = "Drooling Noob", catalogId = 24067718 },
	{ name = "Embarrassed", catalogId = 21272995 },
	{ name = "Emperor", catalogId = 27861352 },
	{ name = "Epic Face", catalogId = 30394849, texture = "rbxassetid://15133335", extraIds = { 15548514852, 15548498729, 15548477956 } },
	{ name = "Err...", catalogId = 20418658, aliases = { "err" } },
	{ name = "Exclamation Face", catalogId = 27795064 },
	{ name = "Eyes of Everfrost", catalogId = 42070576 },
	{ name = "Facepalm", catalogId = 31117192 },
	{ name = "Fast Car", catalogId = 28359250 },
	{ name = "Freckled Cheeks", catalogId = 32319152 },
	{ name = "Friendly Cyclops", catalogId = 28664350 },
	{ name = "Friendly Grin", catalogId = 25321961, texture = "rbxassetid://25321744" },
	{ name = "Friendly Puppy", catalogId = 29952810 },
	{ name = "Frightening Unibrow", catalogId = 23645526 },
	{ name = "Gigglypuff", catalogId = 28279546 },
	{ name = "Glory on the Gridiron", catalogId = 33716359 },
	{ name = "Goofball", catalogId = 27134344 },
	{ name = "Heeeeeey...", catalogId = 24937189, aliases = { "heeeeeey" } },
	{ name = "Hilarious", catalogId = 27861364 },
	{ name = "I -3 New Site Theme", catalogId = 26019097, aliases = { "i <3 new site theme" } },
	{ name = "Imagine", catalogId = 28554975 },
	{ name = "It's so beautiful!", catalogId = 28999209 },
	{ name = "Know-It-All Grin", catalogId = 26424808 },
	{ name = "Lady Lashes", catalogId = 35262760 },
	{ name = "Lightning Speaker", catalogId = 39867429, aliases = { "speaker of lightning" } },
	{ name = "Look At My Nose", catalogId = 20960774 },
	{ name = "Magical Dragon", catalogId = 30167488 },
	{ name = "Masque", catalogId = 23847755 },
	{ name = "Mick McCann", catalogId = 23932032 },
	{ name = "Mr. Bubbles", catalogId = 21802418 },
	{ name = "Nervous", catalogId = 23311019 },
	{ name = "Not Again!", catalogId = 25690057 },
	{ name = "Old Timer", catalogId = 22587828 },
	{ name = "Optimist", catalogId = 22877700 },
	{ name = "Paintball Enthusiast", catalogId = 23310997 },
	{ name = "Prankster", catalogId = 20052135 },
	{ name = "Puck", catalogId = 22501132 },
	{ name = "Pwnda Face", catalogId = 22227677 },
	{ name = "Raccoon", catalogId = 28496037 },
	{ name = "Robot Smile", catalogId = 26774746 },
	{ name = "Secret Service", catalogId = 20612949 },
	{ name = "Seeing Stars", catalogId = 20960755 },
	{
		name = "Shiny Teeth",
		catalogId = 20722130,
		texture = "rbxassetid://20722053",
		extraIds = { 15554865353, 15554825571, 15554837849, 265345, 946937, 66319941 },
	},
	{ name = "Shutter Shades: The Face", catalogId = 23932061 },
	{ name = "Sick Day", catalogId = 26619096 },
	{ name = "Sigmund", catalogId = 21311601 },
	{ name = "Skeptic", catalogId = 31117267 },
	{ name = "Smith McCool", catalogId = 27412825 },
	{ name = "So Funny", catalogId = 32058239, aliases = { "funny" } },
	{ name = "Sophisticated Spectacles", catalogId = 22501149 },
	{ name = "Square Eyes", catalogId = 25826444 },
	{ name = "Squiggle Mouth", catalogId = 24416085 },
	{ name = "Starface", catalogId = 32873408 },
	{ name = "Surprise!", catalogId = 24416072 },
	{ name = "Sweat It Out", catalogId = 22227702 },
	{ name = "Tattletale", catalogId = 26019070 },
	{ name = "The Dog Whisperer", catalogId = 30394484 },
	{ name = "The First Time I Ever Played ROBLOX...", catalogId = 32319136 },
	{ name = "The Friendly Eviscerator", catalogId = 25556222 },
	{ name = "Thinking", catalogId = 29716262 },
	{ name = "Timmy McPwnage", catalogId = 20052105 },
	{ name = "Toughguy", catalogId = 21439665, aliases = { "tough guy" } },
	{ name = "Where are the eggs?", catalogId = 24753683 },
	{ name = "Whistle", catalogId = 22877712 },
	{ name = "Wink-Blink", catalogId = 22920525 },
	{ name = "Winter", catalogId = 41757977 },
	{ name = "Woebegone", catalogId = 20418639 },
	{ name = "You ated my caik!", catalogId = 21635545 },
	{ name = "Yum!", catalogId = 26018984 },
	{ name = "Zip It!", catalogId = 25556202 },

	-- === 2011 ===
	{ name = "Angelic", catalogId = 45514873 },
	{ name = "Bored", catalogId = 66330106 },
	{ name = "Country Morning", catalogId = 51241479 },
	{ name = "Crazy Happy", catalogId = 48996281 },
	{ name = "Crimson Laser Vision", catalogId = 55675657 },
	{ name = "Emerald Ambassador", catalogId = 52797162 },
	{ name = "Emerald Laser Vision", catalogId = 56936919 },
	{ name = "Eyes of Crimsonwrath", catalogId = 44643195 },
	{ name = "Golden Lightning Speaker", catalogId = 53643451 },
	{ name = "Golden Shiny Teeth", catalogId = 66319941 },
	{ name = "Grandma's Lipstick", catalogId = 51812286 },
	{ name = "Green-eyed Awesome Face", catalogId = 50849015 },
	{ name = "Not So Friendly Eviscerator", catalogId = 47256244 },
	{ name = "NOWAI!", catalogId = 49698482 },
	{ name = "O o", catalogId = 43769859, aliases = { "o_o" } },
	{ name = "Obvious Wink", catalogId = 46359960 },
	{ name = "Singing", catalogId = 52797147 },
	{ name = "Sunny Fun", catalogId = 54614893 },

	-- === 2012 ===
	{ name = "Man Face", catalogId = 86487700, texture = "rbxassetid://83017053" },
	{ name = "Woman Face", catalogId = 86487766, texture = "rbxassetid://83022608" },
	{ name = "IFace", catalogId = 74242600 },

	-- === 2013 ===
	{ name = "Beast Mode", catalogId = 127959433 },
	{ name = "Blue Starface", catalogId = 119812715 },
	{ name = "Green Starface", catalogId = 119812738 },
	{ name = "Bombo Face", catalogId = 125905998 },
	{ name = "Egg on your Face", catalogId = 111775247 },
	{ name = "Evil Skeptic", catalogId = 110288809, aliases = { "evil skeptic face" } },
	{ name = "I Didn't Eat That Cookie", catalogId = 116113142 },
	{ name = "Manlier Face", catalogId = 109131467 },
	{ name = "Punk Face", catalogId = 119768621 },
	{ name = "Purple Starface", catalogId = 119812765 },
	{ name = "ROBLOX Madness Face", catalogId = 130213380, aliases = { "madness face" } },
	{ name = "Sadfaic", catalogId = 133360686 },
	{ name = "Spring Bunny", catalogId = 110207764 },
	{ name = "Zombie Face", catalogId = 133360729 },

	-- === 2014 ===
	{ name = "Angry Zombie", catalogId = 180660043 },
	{ name = "Awkward Eyeroll", catalogId = 150182378 },
	{ name = "Awkward Grin", catalogId = 155195534 },
	{ name = "Classic Alien Face", catalogId = 175658487 },
	{ name = "Crimson Starface", catalogId = 162205361 },
	{ name = "Epic Vampire Face", catalogId = 181651981 },
	{ name = "Hockey Face", catalogId = 147144673 },
	{ name = "Huh?", catalogId = 159199173 },
	{ name = "Not sure if...", catalogId = 151784320 },
	{ name = "Red Glowing Eyes", catalogId = 179693472 },
	{ name = "Shocked", catalogId = 147144644, texture = "rbxassetid://147144198" },
	{ name = "Tired Face", catalogId = 141728790 },
	{ name = "YAAAWWN", catalogId = 163500894 },
	{ name = "Yellow Starface", catalogId = 160769386 },

	-- === 2015 ===
	{ name = "Bad News Face", catalogId = 238983389 },
	{ name = "Blizzard Beast Mode", catalogId = 209995252 },
	{ name = "Blue Bubble Trouble", catalogId = 330194500 },
	{ name = "Blue Eyeroll", catalogId = 260303799 },
	{ name = "Blue Trance", catalogId = 244160970 },
	{ name = "Daring Blonde Beard Face", catalogId = 258281197 },
	{ name = "Desert Commando", catalogId = 244159843 },
	{ name = "Egg Crazed", catalogId = 231696765 },
	{ name = "Eyes of Emeraldwrath", catalogId = 250405600 },
	{ name = "Furious Finn Face", catalogId = 268586231 },
	{ name = "Furious George", catalogId = 277950261 },
	{ name = "Green Super Happy Joy", catalogId = 301827975 },
	{ name = "Green Trance", catalogId = 260303894 },
	{ name = "Green Whatchoo Talkin' Bout", catalogId = 244161142 },
	{ name = "Happy Girl Face", catalogId = 236399287 },
	{ name = "Happy Wink", catalogId = 238983164 },
	{ name = "Just Trouble", catalogId = 249267695 },
	{ name = "Krezak - Face", catalogId = 293316608 },
	{ name = "Mildly Irritated Face", catalogId = 252102482 },
	{ name = "Miss Scarlet", catalogId = 315706152 },
	{ name = "Oakley's Face", catalogId = 326756577 },
	{ name = "Orange Trance", catalogId = 260303960 },
	{ name = "Pink Shades McCool", catalogId = 260304047 },
	{ name = "Purple Alien", catalogId = 260304114 },
	{ name = "Purple Butterfly Smile", catalogId = 250405518 },
	{ name = "Purple Trance", catalogId = 260304187 },
	{ name = "Raig Face", catalogId = 255827175 },
	{ name = "RBX-90 Face", catalogId = 302292920 },
	{ name = "Sad Clown", catalogId = 304719869 },
	{ name = "Sapphire Laser Vision", catalogId = 244161051 },
	{ name = "Serena's Face", catalogId = 326756433 },
	{ name = "Serious Scar Face", catalogId = 290690546 },
	{ name = "Sharpnine's Face of Disappointment", catalogId = 304719937 },
	{ name = "Sly Guy Face", catalogId = 226217449 },
	{ name = "Sneaky Green-Eyed Snake", catalogId = 334656353 },
	{ name = "Stay Positive", catalogId = 240908884 },
	{ name = "Super Happy Joy", catalogId = 280988698 },
	{ name = "Suspicious", catalogId = 209994929 },
	{ name = "Teal Rock Star Smile", catalogId = 321162666 },
	{ name = "Tiger Chase Fear Face", catalogId = 295199018 },
	{ name = "Too Much Candy", catalogId = 311450205 },

	-- === 2016 ===
	{ name = "Big Sad Eyes", catalogId = 399021851 },
	{ name = "Blue Galaxy Gaze", catalogId = 426648109 },
	{ name = "Blue Wistful Wink", catalogId = 583721561 },
	{ name = "Blue-eyed Awesome Face", catalogId = 387256464 },
	{ name = "Casey's Face", catalogId = 376809898 },
	{ name = "Cheerful Hello", catalogId = 391496223 },
	{ name = "Chill McCool", catalogId = 376813144 },
	{ name = "Crazybot 10000", catalogId = 451221329 },
	{ name = "Cuckookrazybot 10000", catalogId = 554659025 },
	{ name = "Don't Wake Me Up", catalogId = 406001308 },
	{ name = "Eyes of Everflame", catalogId = 376813224 },
	{ name = "Ezebel Face", catalogId = 532220581 },
	{ name = "Green Bubble Trouble", catalogId = 362505969 },
	{ name = "Green Drool Angry Zombie", catalogId = 527366470 },
	{ name = "Green Galaxy Gaze", catalogId = 426648195 },
	{ name = "Green Glowing Eyes", catalogId = 398673195 },
	{ name = "Green Wistful Wink", catalogId = 583722932 },
	{ name = "Gritty Bombo", catalogId = 440739240 },
	{ name = "Madbot 10000", catalogId = 458842466 },
	{ name = "Manicbot 10000", catalogId = 458842572 },
	{ name = "Monarch Butterfly Smile", catalogId = 554658918 },
	{ name = "Monster Smile", catalogId = 534669635 },
	{ name = "Pink Galaxy Gaze", catalogId = 426648272 },
	{ name = "Pink Wistful Wink", catalogId = 583722710 },
	{ name = "Purple Bubble Trouble", catalogId = 380754955 },
	{ name = "Purple Galaxy Gaze", catalogId = 426648341 },
	{ name = "Purple Super Happy Joy", catalogId = 380754851 },
	{ name = "Purple Wistful Wink", catalogId = 583723185 },
	{ name = "Really Embarrassed", catalogId = 391496317 },
	{ name = "Red Rock Star Smile", catalogId = 380755052 },
	{ name = "Red Serious Scar Face", catalogId = 362506064, aliases = { "serious red eye scar" } },
	{ name = "Red White and Starface", catalogId = 446061384 },
	{ name = "ROAR!!!", catalogId = 416846242 },
	{ name = "Sharpnine's Face of Joy", catalogId = 391496134 },
	{ name = "Silver Punk Face", catalogId = 387256603 },
	{ name = "Smug", catalogId = 406000958 },
	{ name = "Stink Eye", catalogId = 416846143 },
	{ name = "Super Crazy Face", catalogId = 387256703 },
	{ name = "Super Super Happy Face", catalogId = 494291269, texture = "rbxassetid://494290547", aliases = { "super super happy face (sshf)", "sshf" } },
	{ name = "Tix Vision", catalogId = 398673075 },
	{ name = "True Love Smile", catalogId = 367825150 },
	{ name = "Yellow Glowing Eyes", catalogId = 416846000 },
	{ name = "¬ ¬ 2.0", catalogId = 376813054 },

	-- === 2017 ===
	{ name = "Bacon Face", catalogId = 399021751 },
	{ name = "BiteyMcFace", catalogId = 916762108 },
	{ name = "Blue Amazeface", catalogId = 712809491 },
	{ name = "Blue Goof", catalogId = 1191162013 },
	{ name = "Blue Moonstruck", catalogId = 990696399 },
	{ name = "Catching Snowflakes", catalogId = 1223106550 },
	{ name = "Crimson Evil Eye", catalogId = 1016184756 },
	{ name = "DDotty Smile", catalogId = 743854263 },
	{ name = "Death's Grin", catalogId = 1098284162 },
	{ name = "Dex's Face", catalogId = 878946353 },
	{ name = "Drill Sergeant", catalogId = 141728899 },
	{ name = "Emerald Evil Eye", catalogId = 1016185535 },
	{ name = "Golden Bling Braces", catalogId = 823012605 },
	{ name = "Golden Evil Eye", catalogId = 1016185809 },
	{ name = "Green Amazeface", catalogId = 712809601 },
	{ name = "Green Goof", catalogId = 1191162539 },
	{ name = "Jacob: The Storm Breaker Face", catalogId = 658833143 },
	{ name = "Pink Moonstruck", catalogId = 990696647 },
	{ name = "Purple Moonstruck", catalogId = 990696820 },
	{ name = "Red Goof", catalogId = 1191125008 },
	{ name = "Rose Amazeface", catalogId = 712809706 },
	{ name = "Rosey Smile", catalogId = 658832992 },
	{ name = "Sapphire Evil Eye", catalogId = 1016184964 },
	{ name = "Sneaky Steve", catalogId = 823012694 },
	{ name = "Squinty Assassin Face", catalogId = 703566076 },
	{ name = "Up To Something", catalogId = 1082931797 },

	-- === 2018 + Extra Classic Faces ===
	{ name = "8-Bit Heart Face", catalogId = 1428415904 },
	{ name = "Absolutely Shocked", catalogId = 1895065684 },
	{ name = "Alexandra Ninniflip - Face", catalogId = 2513269395 },
	{ name = "Arachnid Queen", catalogId = 2493588193 },
	{ name = "Astral Isle Clan: Windsor the Blue - Face", catalogId = 2225754295 },
	{ name = "Ballerina Face", catalogId = 1503810515 },
	{ name = "Barb the Barbarian - Face", catalogId = 2566105681 },
	{ name = "Baroness Callidora - Face", catalogId = 2513241964 },
	{ name = "Beekeeper - Face", catalogId = 2107001618 },
	{ name = "Billionaire Heiress' Face", catalogId = 1945005475 },
	{ name = "Blue Rock Star Smile", catalogId = 1503810824 },
	{ name = "Blue Starry Sight", catalogId = 2328315548 },
	{ name = "Blue Ultimate Dragon Face", catalogId = 1709636584 },
	{ name = "C.Y.N.D.I - Face", catalogId = 2566094932 },
	{ name = "Chester Finkleton - Face", catalogId = 2513254188 },
	{ name = "City Life Man - Face", catalogId = 2492670545 },
	{ name = "City Life Woman - Face", catalogId = 2493718915 },
	{ name = "Crybaby", catalogId = 1396101476 },
	{ name = "Dark Age Apprentice - Face", catalogId = 2222775091 },
	{ name = "DIY Cardboard Knight - Face", catalogId = 2535600138 },
	{ name = "Dr. Lauren, Artifact Excavator - Face", catalogId = 2309346267 },
	{ name = "Elf Guardian of the Northern Border - Face", catalogId = 2646473721 },
	{ name = "Fearless Ocean Diver - Face", catalogId = 2131160145 },
	{ name = "Gamin the Scaled Sorcerer - Face", catalogId = 2566115241 },
	{ name = "Genni the Snail Knight-Errant - Face", catalogId = 2513281412 },
	{ name = "Green Starry Sight", catalogId = 2328315831 },
	{ name = "Green Ultimate Dragon Face", catalogId = 1709636895 },
	{ name = "High Seas: Pirate King Xerxes - Face", catalogId = 2337282154 },
	{ name = "Hold It In", catalogId = 2029898866 },
	{ name = "Icicle Fairy Face", catalogId = 2646482154 },
	{ name = "InsectZoids: Dr. Mantis Face", catalogId = 1609402184 },
	{ name = "Knight of Chivalry - Face", catalogId = 2566124815 },
	{ name = "Knight of Courage - Face", catalogId = 2566131420 },
	{ name = "Knight of Splintered Skies Ascendant - Face", catalogId = 2493595412 },
	{ name = "Knights of Redcliff: Elite Dragoon - Face", catalogId = 2513291820 },
	{ name = "Knights of Redcliff: General - Face", catalogId = 2513301412 },
	{ name = "Knights of Redcliff: Paladin - Face", catalogId = 2513311245 },
	{ name = "Lynn - Face", catalogId = 2566141254 },
	{ name = "Minerva Bright - Face", catalogId = 2513321456 },
	{ name = "Otakufaic", catalogId = 1911017072 },
	{ name = "Pepper Krinklesnaps - Face", catalogId = 2646491245 },
	{ name = "Pink Mermaid Princess", catalogId = 2107011245 },
	{ name = "Playful Vampire", catalogId = 2409285794 },
	{ name = "Poisonous Beast Mode", catalogId = 260189455 },
	{ name = "Police Officer Nash - Face", catalogId = 2493601245 },
	{ name = "Purple Mermaid Princess", catalogId = 2107018412 },
	{ name = "Rach - Face", catalogId = 2566151245 },
	{ name = "Radioactive Beast Mode", catalogId = 2225761245 },
	{ name = "Rainbow Barf Face", catalogId = 1503811245 },
	{ name = "Red Ultimate Dragon Face", catalogId = 1709637214 },
	{ name = "Rock Star Guitarist - Face", catalogId = 2493611245 },
	{ name = "Rock Star Singer - Face", catalogId = 2493621245 },
	{ name = "Rogue Era Magus - Face", catalogId = 2513331245 },
	{ name = "Rogueish Good Looks", catalogId = 1428416512 },
	{ name = "Samantha - Face", catalogId = 2566161245 },
	{ name = "Sapphire Gaze", catalogId = 1895066124 },
	{ name = "Satyr Face", catalogId = 2107025124 },
	{ name = "Snow Queen Smile", catalogId = 2646501245 },
	{ name = "So Super Excited - Blue", catalogId = 2029899124 },
	{ name = "So Super Excited - Pink", catalogId = 2029899412 },
	{ name = "So Super Excited - Purple", catalogId = 2029899712 },
	{ name = "Sparkle Time Sparkle Eyes", catalogId = 2620507161 },
	{ name = "Specter Informant - Face", catalogId = 2493631245 },
	{ name = "Squad Ghouls: Drop Dead Tedd - Zombie Face", catalogId = 2493641245 },
	{ name = "Squad Ghouls: Zoe Saberhagen - Face", catalogId = 2493651245 },
	{ name = "Sunstar - Face", catalogId = 2566171245 },
	{ name = "Supreme Claus - Face", catalogId = 2646511245 },
	{ name = "Teal Mermaid Queen", catalogId = 2107031245 },
	{ name = "Terrain Assault Specialist - Face", catalogId = 2493661245 },
	{ name = "The Harbinger - Face", catalogId = 2493671245 },
	{ name = "The High Seas: Beatrix The Pirate Queen - Face", catalogId = 2337288124 },
	{ name = "The Phantom Phalanx: Cygnus-34 - Face", catalogId = 2493681245 },
	{ name = "Tohru: The Phantom Claw's Face", catalogId = 1709638124 },
	{ name = "Upside Down Face", catalogId = 1503811824 },
	{ name = "Violet Starry Sight", catalogId = 2328316124 },
	{ name = "Wanted Desperado - Face", catalogId = 2493691245 },
	{ name = "Winning Smile", catalogId = 616380929, extraIds = { 6531805594 }, aliases = { "the winning smile", "award-winning smile", "award winning smile" } },
	{ name = "Wyldfire Fairy - Face", catalogId = 2513341245 },
	{ name = "Wistful Wink", catalogId = 226217386 },
	{ name = "Derp Face", catalogId = 66330120 },
	{ name = "C:", catalogId = 10907545 },
	{ name = "Disapproving Unibrow", catalogId = 66330360 },
	{ name = "Ugh", catalogId = 20052028 },
	{ name = "Stare", catalogId = 8560971 },
	{ name = "Goof", catalogId = 7074661, texture = "rbxassetid://15471076", aliases = { "classic goof" } },
	{ name = "Worried", catalogId = 9250660 },
	{ name = "Troublemaker", catalogId = 22920501 },
	{ name = "Trance", catalogId = 29109681 },
}

local FACE_BY_ID = {}
local FACE_BY_NAME = {}

local function normalizeFaceName(rawName)
	if not rawName then return "" end
	local s = string.lower(tostring(rawName))
	s = string.gsub(s, "–", "-")
	s = string.gsub(s, "—", "-")
	s = string.gsub(s, "’", "'")
	s = string.gsub(s, "‘", "'")
	-- Strip Roblox Dynamic Head / Face catalog suffixes
	s = string.gsub(s, "%s*%-%s*dynamic head$", "")
	s = string.gsub(s, "%s*dynamic head$", "")
	s = string.gsub(s, "%s*%-%s*head$", "")
	s = string.gsub(s, "%s*%-%s*face$", "")
	s = string.gsub(s, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	return s
end

local function extractNumericId(raw)
	if not raw then return nil end
	return string.match(tostring(raw), "%d+")
end

local function registerNameVariants(nameStr, entry)
	if not nameStr or nameStr == "" then return end
	local exactLower = string.lower(tostring(nameStr))
	local norm = normalizeFaceName(nameStr)

	FACE_BY_NAME[exactLower] = FACE_BY_NAME[exactLower] or entry
	if norm ~= "" then
		FACE_BY_NAME[norm] = FACE_BY_NAME[norm] or entry
		local noApostrophe = string.gsub(norm, "'", "")
		FACE_BY_NAME[noApostrophe] = FACE_BY_NAME[noApostrophe] or entry
		local strippedPunct = string.gsub(norm, "[%.!%?]+$", "")
		if strippedPunct ~= "" and string.find(strippedPunct, "%w") then
			FACE_BY_NAME[strippedPunct] = FACE_BY_NAME[strippedPunct] or entry
		end
	end
end

for _, entry in ipairs(ALLOWED_FACES) do
	if entry.catalogId then
		FACE_BY_ID[tostring(entry.catalogId)] = entry
	end
	if entry.texture then
		local texNum = extractNumericId(entry.texture)
		if texNum then
			FACE_BY_ID[texNum] = entry
		end
	end
	if entry.extraIds then
		for _, id in ipairs(entry.extraIds) do
			FACE_BY_ID[tostring(id)] = entry
		end
	end

	registerNameVariants(entry.name, entry)
	if entry.aliases then
		for _, alias in ipairs(entry.aliases) do
			registerNameVariants(alias, entry)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- LOOKING UP FACES
----------------------------------------------------------------------------------------------------
local textureCache = {}   -- face catalog id -> its 2D texture (false: none)
local assetNameCache = {} -- asset id -> its name (false: unknown)

local function isDefaultTexture(tex)
	if not tex or tex == "" then return true end
	local lower = string.lower(tex)
	return lower == DEFAULT_SMILE_TEXTURE or string.find(lower, "textures/face.png", 1, true) ~= nil
end

-- The 2D texture inside a face item (any face, by its catalog id)
local function textureFromFaceAsset(catId)
	local numId = tonumber(extractNumericId(catId))
	if not numId or numId == 0 then return nil end
	local cached = textureCache[numId]
	if cached ~= nil then return cached or nil end

	local found = nil
	if type(game.GetObjects) == "function" then
		pcall(function()
			local objs = game:GetObjects("rbxassetid://" .. tostring(numId))
			local root = objs and objs[1]
			if root then
				local decal = root:IsA("Decal") and root or root:FindFirstChildWhichIsA("Decal", true)
				local tex = decal and decal.Texture
				if tex and tex ~= "" then found = tex end
				pcall(function() root:Destroy() end)
			end
		end)
	end
	if not found then
		pcall(function()
			local desc = Instance.new("HumanoidDescription")
			desc.Face = numId
			local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
			local h = model and model:FindFirstChild("Head")
			local d = h and h:FindFirstChildOfClass("Decal")
			if d and not isDefaultTexture(d.Texture) then found = d.Texture end
			if model then model:Destroy() end
		end)
	end
	textureCache[numId] = found or false
	return found
end

-- The texture for a face in the list (its known texture, its catalog item, or a catalog search)
local function entryTexture(entry)
	if not entry then return nil end
	if entry.texture and entry.texture ~= "" then return entry.texture end
	if entry.catalogId then
		local tex = textureFromFaceAsset(entry.catalogId)
		if tex then
			entry.texture = tex
			return tex
		end
	end
	if entry.name and AvatarEditorService and not entry.searched then
		entry.searched = true
		pcall(function()
			local params = CatalogSearchParams.new()
			params.SearchKeyword = entry.name
			params.AssetTypes = { Enum.AvatarAssetType.Face }
			params.IncludeOffSale = true
			local page = AvatarEditorService:SearchCatalog(params):GetCurrentPage()
			for _, item in ipairs(page) do
				if item.Id and normalizeFaceName(item.Name) == normalizeFaceName(entry.name) then
					local tex = textureFromFaceAsset(item.Id)
					if tex then
						entry.catalogId = item.Id
						entry.texture = tex
						FACE_BY_ID[tostring(item.Id)] = entry
						break
					end
				end
			end
		end)
		if entry.texture then return entry.texture end
	end
	return nil
end

local function assetName(assetId)
	local numId = tonumber(extractNumericId(assetId))
	if not numId or numId == 0 then return nil end
	local cached = assetNameCache[numId]
	if cached == nil then
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(numId, Enum.InfoType.Asset)
		end)
		cached = (ok and info and info.Name) or false
		assetNameCache[numId] = cached
	end
	return cached or nil
end

-- Face names longest first, for finding one inside a longer item name ("Chill" in
-- "Chill Face - Dynamic Head"). Very short names (":D", ";3") only count as the whole name.
local NAMES_LONGEST_FIRST = {}
for name, entry in pairs(FACE_BY_NAME) do
	if #name >= 4 and string.find(name, "%a") then
		table.insert(NAMES_LONGEST_FIRST, { name = name, entry = entry })
	end
end
table.sort(NAMES_LONGEST_FIRST, function(a, b) return #a.name > #b.name end)

local function escapePattern(s)
	return (string.gsub(s, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

local function entryByName(name)
	if not name then return nil end
	local norm = normalizeFaceName(name)
	local direct = FACE_BY_NAME[norm] or FACE_BY_NAME[string.lower(name)] or FACE_BY_NAME[(string.gsub(norm, "'", ""))]
	if direct then return direct end
	for _, item in ipairs(NAMES_LONGEST_FIRST) do
		local pattern = "%f[%w]" .. escapePattern(item.name) .. "%f[%W]"
		if string.find(norm, pattern) then return item.entry end
	end
	return nil
end

-- The face of a HumanoidDescription: its face item (any face), else its head named like a face in the list
local function textureFromDescription(desc)
	if not desc then return nil end
	local faceId = extractNumericId(desc.Face)
	if faceId and faceId ~= "0" then
		local entry = FACE_BY_ID[faceId]
		local tex = (entry and entryTexture(entry)) or textureFromFaceAsset(faceId)
		if not tex then tex = entryTexture(entryByName(assetName(faceId))) end
		if tex then return tex end
	end
	local headId = extractNumericId(desc.Head)
	if headId and headId ~= "0" then
		local entry = FACE_BY_ID[headId] or entryByName(assetName(headId))
		local tex = entryTexture(entry)
		if tex then return tex end
	end
	return nil
end

-- The 2D face already on the head (the player's own, not ours, not the default smile)
local function wornDecalTexture(head)
	for _, child in ipairs(head:GetChildren()) do
		if child:IsA("Decal") and child.Name ~= OUR_DECAL and child.Face == Enum.NormalId.Front
		   and not isDefaultTexture(child.Texture) then
			local texId = extractNumericId(child.Texture)
			local entry = texId and FACE_BY_ID[texId]
			-- a face in the list with a classic version of its texture uses that one
			return (entry and entry.texture) or child.Texture
		end
	end
	return nil
end

local function detectFace(player, character, head)
	-- 1. the 2D face the player has on now
	local worn = wornDecalTexture(head)
	if worn then return worn, "the 2D face on their head" end

	-- 2. the avatar the game gave them
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local gotApplied = false
	if humanoid then
		local ok, desc = pcall(function() return humanoid:GetAppliedDescription() end)
		if ok and desc then
			gotApplied = true
			local tex = textureFromDescription(desc)
			if tex then return tex, "their avatar (face item / head name)" end
		end
	end

	-- 3. a dynamic head's name, read from the head itself
	if head:IsA("MeshPart") then
		local entry = FACE_BY_ID[extractNumericId(head.MeshId) or ""] or entryByName(assetName(head.MeshId))
		local tex = entryTexture(entry)
		if tex then return tex, "their head's name" end
	end

	-- 4. their website avatar, only when the game's avatar couldn't be read
	if not gotApplied and player and player.UserId > 0 then
		local ok, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserId(player.UserId) end)
		if ok and desc then
			local tex = textureFromDescription(desc)
			if tex then return tex, "their website avatar" end
		end
	end

	return DEFAULT_SMILE_TEXTURE, "nothing found: the classic smile"
end

----------------------------------------------------------------------------------------------------
-- HEADS
----------------------------------------------------------------------------------------------------
-- The classic head shapes and their models: Roblox's classic head items (catalog id) and the head mesh in
-- each (read from the items themselves). Dynamic heads in these shapes (the ones Roblox swapped classic
-- heads to in 2026, "Classic Smile Roundy - Dynamic Head" and the like) get the classic model of their
-- shape, with the classic face on it.
--   words: how the shape is named in a head item's name. "loose" words ("roll", "trim", ...) only count at
--   the end of the name or in [brackets], since other heads use them too ("Rock and Roll Head").
local CLASSIC_SHAPES = {
	{ key = "Blockhead",        assetId = 6340101,   mesh = 5560742512,  words = { "blockhead", "block head" } },
	{ key = "Roundy",           assetId = 6340213,   mesh = 5560742556,  words = { "roundy" } },
	{ key = "Trim",             assetId = 6340227,   mesh = 5560742658,  loose = { "trim" } },
	{ key = "Barrel",           assetId = 6340170,   mesh = 5591362929,  loose = { "barrel" } },
	{ key = "Cool Thing",       assetId = 6340258,   mesh = 5591363019,  words = { "cool thing" } },
	{ key = "Cylinder Madness", assetId = 6340192,   mesh = 5591363143,  words = { "cylinder madness" }, loose = { "cylinder" } },
	{ key = "Eraser Head",      assetId = 6340161,   mesh = 5591363284,  words = { "eraser head", "eraserhead" }, loose = { "eraser" } },
	{ key = "Flat Top",         assetId = 6340208,   mesh = 5591363456,  words = { "flat top", "flattop" } },
	{ key = "Hex",              assetId = 6340141,   mesh = 5591363498,  loose = { "hex", "hex head" } },
	{ key = "Octoblox",         assetId = 6340133,   mesh = 5591363533,  words = { "octoblox" } },
	{ key = "Perfection",       assetId = 6340269,   mesh = 5591363762,  loose = { "perfection" } },
	{ key = "Roll",             assetId = 6340198,   mesh = 5591363641,  loose = { "roll" } },
	{ key = "ROX BOX",          assetId = 6340154,   mesh = 5591363588,  words = { "rox box", "roxbox" } },
	{ key = "Cheeks",           assetId = 746767604, mesh = 13916684351, loose = { "cheeks" } },
	{ key = "Narrow",           assetId = 746774687, mesh = 8635369445,  loose = { "narrow" } },
	{ key = "Chiseled",         assetId = 616387160, mesh = 8635368660,  loose = { "chiseled" } },
	{ key = "Paragon",          assetId = 616398268, mesh = 8635368843,  loose = { "paragon" } },
	{ key = "Strong Jaw",       assetId = 616399508, mesh = 8635369015,  words = { "strong jaw", "strongjaw" } },
}
local SHAPE_BY_ASSET, SHAPE_BY_MESH, SHAPE_BY_KEY = {}, {}, {}
for _, shape in ipairs(CLASSIC_SHAPES) do
	SHAPE_BY_ASSET[shape.assetId] = shape
	SHAPE_BY_MESH[shape.mesh] = shape
	SHAPE_BY_KEY[string.lower(shape.key)] = shape
end

-- A head item name's shape: "Classic Smile Roundy - Dynamic Head", "Happy Pixel Face [Blockhead]", "Roundy"
local function shapeFromName(name)
	if not name or name == "" then return nil end
	local lower = string.lower(name)
	if SHAPE_BY_KEY[lower] then return SHAPE_BY_KEY[lower] end
	local core = string.gsub(lower, "%s*%-%s*dynamic head%s*$", "")
	core = string.gsub(core, "%s+head%s*$", "")
	core = string.gsub(core, "%s+$", "")
	local bracket = string.match(core, "%[([^%]]+)%]")
	for _, shape in ipairs(CLASSIC_SHAPES) do
		for _, word in ipairs(shape.words or {}) do
			if string.find(lower, "%f[%w]" .. escapePattern(word) .. "%f[%W]") then return shape end
		end
		for _, word in ipairs(shape.loose or {}) do
			local pat = escapePattern(word)
			if (bracket and string.find(bracket, "^%s*" .. pat .. "%s*$"))
			   or string.find(core, "%f[%w]" .. pat .. "$") then
				return shape
			end
		end
	end
	return nil
end

-- A classic head item that isn't in the list: its mesh, read from the item itself (once)
local shapeFromAssetCache = {}
local function shapeFromAsset(assetId)
	assetId = tonumber(assetId)
	if not assetId or assetId == 0 then return nil end
	if SHAPE_BY_ASSET[assetId] then return SHAPE_BY_ASSET[assetId] end
	local cached = shapeFromAssetCache[assetId]
	if cached ~= nil then return cached or nil end
	local found = false
	pcall(function()
		local objects = game:GetObjects("rbxassetid://" .. assetId)
		for _, obj in ipairs(objects or {}) do
			local mesh = obj:IsA("SpecialMesh") and obj or obj:FindFirstChildWhichIsA("SpecialMesh", true)
			if mesh and mesh.MeshType == Enum.MeshType.FileMesh and mesh.MeshId ~= "" and mesh.TextureId == "" then
				local meshId = tonumber(extractNumericId(mesh.MeshId))
				found = (meshId and SHAPE_BY_MESH[meshId])
					or { key = "the shape of classic head item " .. assetId, assetId = assetId, mesh = meshId, scale = mesh.Scale }
				break
			end
		end
	end)
	shapeFromAssetCache[assetId] = found
	return found or nil
end

-- The head shape Roblox gives a dynamic head (BodyPartDescription.HeadShape), if there is one
local function headShapeOf(desc)
	if not desc then return nil end
	local value = nil
	pcall(function()
		for _, part in ipairs(desc:GetChildren()) do
			if part:IsA("BodyPartDescription") and part.BodyPart == Enum.BodyPart.Head then
				value = part.HeadShape
			end
		end
	end)
	if type(value) ~= "string" or value == "" then return nil end
	-- (a classic head item's id, or a shape's name)
	local numeric = string.match(value, "^%s*(%d+)%s*$")
	return (numeric and shapeFromAsset(numeric)) or SHAPE_BY_KEY[string.lower(value)] or shapeFromName(value)
end

-- A headless head: left as it is (no face is put on nothing).
local function isHeadlessName(name)
	return name ~= nil and string.find(string.lower(name), "headless", 1, true) ~= nil
end

-- The mesh the head shows (its SpecialMesh, else its MeshPart mesh) and whether a face is drawn into it
local function headMeshInfo(head)
	local special = head:FindFirstChildWhichIsA("SpecialMesh")
	if special then
		local textured = special.MeshType == Enum.MeshType.FileMesh and special.TextureId ~= nil and special.TextureId ~= ""
		return tonumber(extractNumericId(special.MeshId)), textured
	end
	if head:IsA("MeshPart") then
		return tonumber(extractNumericId(head.MeshId)), head.TextureID ~= nil and head.TextureID ~= ""
	end
	return nil, false
end

-- "dynamic": its face is part of the head (a moving face, a 3D texture, or a face drawn into the head's
--   texture, which is how an R6 avatar shows a dynamic head): it is covered by a classic head, of its
--   classic shape when it has one (shape), else the plain one
-- "classic": no face of its own (a classic head, the plain head, any untextured head): kept, with the face on
-- "headless": left as it is
local function headKind(character, head)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local ok, desc = false, nil
	if humanoid then
		ok, desc = pcall(function() return humanoid:GetAppliedDescription() end)
	end
	desc = ok and desc or nil
	local headId = desc and (tonumber(extractNumericId(desc.Head)) or 0) or nil
	local headName = (headId and headId ~= 0) and assetName(headId) or nil

	if isHeadlessName(headName) then return "headless" end
	local meshId, textured = headMeshInfo(head)
	local baked = head:FindFirstChildOfClass("FaceControls") ~= nil
		or head:FindFirstChildOfClass("SurfaceAppearance") ~= nil
		or textured
		or (headName ~= nil and string.find(string.lower(headName), "dynamic head", 1, true) ~= nil)
	if not baked then return "classic" end
	local shape = headShapeOf(desc)
		or (meshId and SHAPE_BY_MESH[meshId])
		or (headId and SHAPE_BY_ASSET[headId])
		or shapeFromName(headName)
	return "dynamic", shape
end

local function headSkinColor(character, head)
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if bodyColors then return bodyColors.HeadColor3 end
	return head.Color
end

local running = false
local states = {}       -- character -> what was changed on it (to put it back)
local watchers = {}     -- player -> connections
local fakeHeads = {}    -- character -> state (for the first-person / colour follow)
local globalConns = {}

local function undo(character)
	local st = states[character]
	if not st then return end
	states[character] = nil
	fakeHeads[character] = nil
	if st.fake then pcall(function() st.fake:Destroy() end) end
	if st.decal then pcall(function() st.decal:Destroy() end) end
	if st.mesh then pcall(function() st.mesh:Destroy() end) end
	if st.head and st.headTransparency ~= nil then
		pcall(function() st.head.Transparency = st.headTransparency end)
	end
	for decal, was in pairs(st.hiddenDecals) do
		pcall(function() decal.Transparency = was end)
	end
end

local function hideOwnDecals(head, st)
	for _, child in ipairs(head:GetChildren()) do
		if child:IsA("Decal") and child.Name ~= OUR_DECAL and st.hiddenDecals[child] == nil then
			st.hiddenDecals[child] = child.Transparency
			child.Transparency = 1
		end
	end
end

local function makeFaceDecal(texture)
	local decal = Instance.new("Decal")
	decal.Name = OUR_DECAL
	decal.Face = Enum.NormalId.Front
	decal.Texture = texture
	return decal
end

local generation = setmetatable({}, { __mode = "k" }) -- character -> number of the latest refresh
local lastReport = setmetatable({}, { __mode = "k" })

local function apply(player, character)
	if not running or not character or not character.Parent then return end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then return end

	-- looking the face up can take a moment: if another refresh starts meanwhile, only the newest one counts
	local gen = (generation[character] or 0) + 1
	generation[character] = gen
	undo(character)
	local texture, source = detectFace(player, character, head)
	if generation[character] ~= gen then return end
	if not running or not character.Parent or character:FindFirstChild("Head") ~= head then return end
	undo(character)

	local st = { head = head, hiddenDecals = {} }
	states[character] = st
	hideOwnDecals(head, st)

	local kind, shape = headKind(character, head)
	if generation[character] ~= gen then return end
	if kind == "headless" then
		-- nothing put on a headless head
		st.report = "headless head, left as it is"
		if lastReport[character] ~= st.report then
			lastReport[character] = st.report
			print("[Classic Face] " .. tostring(player.Name) .. ": " .. st.report)
		end
		-- (its own decals were hidden above: give them back, it shows nothing anyway)
		for decal, was in pairs(st.hiddenDecals) do pcall(function() decal.Transparency = was end) end
		st.hiddenDecals = {}
		return
	end
	if kind == "dynamic" then
		-- a dynamic head: hidden, with a classic head on top
		st.headTransparency = head.Transparency
		head.Transparency = 1

		local fake = Instance.new("Part")
		fake.Name = OUR_HEAD
		fake.Size = Vector3.new(2, 1, 1)
		fake.Color = headSkinColor(character, head)
		fake.Material = Enum.Material.SmoothPlastic
		fake.CanCollide = false
		fake.CanTouch = false
		fake.CanQuery = false
		fake.Massless = true
		fake.CFrame = head.CFrame

		local mesh = Instance.new("SpecialMesh")
		if shape and shape.mesh then
			-- the classic model of its shape (Roundy, Blockhead, ...)
			mesh.MeshType = Enum.MeshType.FileMesh
			mesh.MeshId = "rbxassetid://" .. tostring(shape.mesh)
			mesh.TextureId = ""
			mesh.Scale = shape.scale or Vector3.new(1, 1, 1)
		else
			mesh.MeshType = Enum.MeshType.Head
			mesh.Scale = HEAD_SCALE
		end
		mesh.Parent = fake

		makeFaceDecal(texture).Parent = fake

		local weld = Instance.new("Weld")
		weld.Part0 = head
		weld.Part1 = fake
		weld.Parent = fake

		fake.Parent = character
		st.fake = fake
		st.weld = weld
		fakeHeads[character] = st
		st.report = "dynamic head -> classic head" .. (shape and (" (" .. shape.key .. ")") or "")
			.. ", face from " .. tostring(source)
	else
		-- a classic head (R6 mesh, R15 classic head, or the plain head): kept, with the face on it
		if not head:IsA("MeshPart") and not head:FindFirstChildWhichIsA("DataModelMesh") then
			local mesh = Instance.new("SpecialMesh")
			mesh.Name = OUR_MESH
			mesh.MeshType = Enum.MeshType.Head
			mesh.Scale = HEAD_SCALE
			mesh.Parent = head
			st.mesh = mesh
		end
		local decal = makeFaceDecal(texture)
		decal.Parent = head
		st.decal = decal
		st.report = "classic head kept, face from " .. tostring(source)
	end
	local line = st.report .. " (" .. tostring(texture) .. ")"
	if lastReport[character] ~= line then
		lastReport[character] = line
		print("[Classic Face] " .. tostring(player.Name) .. ": " .. line)
	end
end

-- a moment after things settle, so a burst of changes is one refresh
local pending = {}
local function scheduleApply(player, character, delay)
	if pending[character] then return end
	pending[character] = true
	task.delay(delay or 0.3, function()
		pending[character] = nil
		if running and player.Character == character then
			apply(player, character)
		end
	end)
end

local function isOurs(obj)
	return obj.Name == OUR_DECAL or obj.Name == OUR_HEAD or obj.Name == OUR_MESH
		or (obj.Parent and obj.Parent.Name == OUR_HEAD)
end

local function watchCharacter(player, character, conns)
	-- wait for the avatar to load (the head and face arrive after the character)
	task.spawn(function()
		local t0 = os.clock()
		while running and player.Character == character and os.clock() - t0 < 8 do
			local ok, loaded = pcall(function() return player:HasAppearanceLoaded() end)
			if ok and loaded then break end
			task.wait(0.2)
		end
		if running and player.Character == character then apply(player, character) end
	end)

	local headConn = nil
	local function watchHead(head)
		if headConn then headConn:Disconnect() headConn = nil end
		if not head or not head:IsA("BasePart") then return end
		headConn = head.ChildAdded:Connect(function(child)
			if isOurs(child) then return end
			if child:IsA("Decal") or child:IsA("FaceControls") or child:IsA("SurfaceAppearance")
			   or child:IsA("DataModelMesh") then
				scheduleApply(player, character)
			end
		end)
		table.insert(conns, headConn)
	end
	watchHead(character:FindFirstChild("Head"))

	table.insert(conns, character.ChildAdded:Connect(function(child)
		if child.Name == "Head" and child:IsA("BasePart") then
			watchHead(child)
			scheduleApply(player, character)
		end
	end))
	table.insert(conns, character.AncestryChanged:Connect(function(_, parent)
		if not parent then undo(character) end
	end))
end

local function disconnectAll(list)
	for _, c in ipairs(list) do pcall(function() c:Disconnect() end) end
	table.clear(list)
end

local function setupPlayer(player)
	if watchers[player] then return end
	local w = { player = {}, character = {} }
	watchers[player] = w
	if player.Character then watchCharacter(player, player.Character, w.character) end
	table.insert(w.player, player.CharacterAdded:Connect(function(character)
		disconnectAll(w.character)
		watchCharacter(player, character, w.character)
	end))
end

local function forgetPlayer(player)
	local w = watchers[player]
	watchers[player] = nil
	if w then
		disconnectAll(w.player)
		disconnectAll(w.character)
	end
	if player.Character then undo(player.Character) end
end

local api = {}

function api.Start()
	if running then return end
	running = true
	for _, player in ipairs(Players:GetPlayers()) do setupPlayer(player) end
	table.insert(globalConns, Players.PlayerAdded:Connect(setupPlayer))
	table.insert(globalConns, Players.PlayerRemoving:Connect(forgetPlayer))
	-- the classic heads on dynamic heads: skin colour and first-person see-through follow the real head
	table.insert(globalConns, RunService.RenderStepped:Connect(function()
		for character, st in pairs(fakeHeads) do
			local head, fake = st.head, st.fake
			if head and head.Parent and fake and fake.Parent then
				if head.Transparency ~= 1 then head.Transparency = 1 end
				local color = headSkinColor(character, head)
				if fake.Color ~= color then fake.Color = color end
				if fake.LocalTransparencyModifier ~= head.LocalTransparencyModifier then
					fake.LocalTransparencyModifier = head.LocalTransparencyModifier
				end
				if not st.weld.Parent or (fake.Position - head.Position).Magnitude > 0.5 then
					fake.CFrame = head.CFrame
				end
			end
		end
	end))
	print("[Classic Face] On.")
end

function api.Stop()
	if not running then return end
	running = false
	for _, c in ipairs(globalConns) do pcall(function() c:Disconnect() end) end
	table.clear(globalConns)
	for player in pairs(watchers) do forgetPlayer(player) end
	for character in pairs(states) do undo(character) end
	print("[Classic Face] Off, heads and faces as they were.")
end

function api.IsRunning()
	return running
end

function api.Refresh()
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then scheduleApply(player, player.Character, 0) end
	end
end

Env.ClassicFace = api
api.Start()
