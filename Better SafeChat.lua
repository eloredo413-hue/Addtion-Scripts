--[[
    =========================================================
    SAFE CHAT (2013-style) — CASCADING FLYOUT MENU
    • Mobile-only
    • Tap a category → submenu pops out to the right
    • Tap the SAME category again → sends its own label as chat
    • Tap a leaf → sends chat and closes
    • Columns shift left on mobile, each scrolls if too tall
    • Top layer above everything, position/parent locked
    • BULLETPROOF bubble-chat detection: backs off completely
      whenever the Bloxy Paradox system (hooks, wizard,
      config, 2013mobile selection, 2011 bubble hook, etc.)
      is present, so nothing conflicts with custom bubbles.
]]

-- (Addtion-Scripts copy of the Better SafeChat gist, loaded by the Safe chat Hook through the loader: it can
-- be shown smaller, getgenv().BPSafeChatScale (Old Gui Fix.lua sets it on a phone for the GUIs before 2014 and
-- 2013 mobile, so the safe chat is the same size as those GUIs). The whole menu is drawn on a canvas that
-- much bigger and zoomed down, so it all keeps its place on the screen; followed if it changes.)
local function uiScale()
    local env = (getgenv and getgenv()) or _G
    local s = tonumber(env.BPSafeChatScale)
    if not s or s <= 0 then return 1 end
    return s
end

local MOBILE_ONLY = true
_G.safeChatVersion = _G.safeChatVersion or "v1"
_G.keyToDestroy   = _G.keyToDestroy   or Enum.KeyCode.RightShift

local TextChatService  = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local ChatService      = game:GetService("Chat")
local HttpService      = game:GetService("HttpService")

if MOBILE_ONLY and not UserInputService.TouchEnabled then
    warn("[SafeChat] Mobile-only script — aborting.")
    return
end

local function getUIParent()
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- [FULL CLASSIC SAFECHAT TREE]
local safeChatData = {
    Branches = {
        { Label = "Use the Chat menu to talk to me.", Branches = {} },
        { Label = "Hello", Branches = {
            { Label = "Hi", Branches = {} },
            { Label = "Hi there!", Branches = {} },
            { Label = "Hi everyone", Branches = {} },
            { Label = "Howdy", Branches = {} },
            { Label = "Howdy partner!", Branches = {} },
        }},
        { Label = "Greetings", Branches = {
            { Label = "Greetings everyone", Branches = {} },
            { Label = "Greetings Robloxians!", Branches = {} },
            { Label = "Seasons greetings!", Branches = {} },
        }},
        { Label = "Welcome", Branches = {
            { Label = "Welcome to my place", Branches = {} },
            { Label = "Welcome to our base", Branches = {} },
            { Label = "Welcome to my barbeque", Branches = {} },
        }},
        { Label = "Hey there!", Branches = {
            { Label = "What's up?", Branches = {} },
            { Label = "How are you doing?", Branches = {} },
            { Label = "How's it going?", Branches = {} },
            { Label = "What's new?", Branches = {} },
        }},
        { Label = "Good day", Branches = {
            { Label = "Good morning", Branches = {} },
            { Label = "Good afternoon", Branches = {} },
            { Label = "Good evening", Branches = {} },
            { Label = "Good night", Branches = {} },
            { Label = "Waaaaaaaz up?!", Branches = {} },
            { Label = "Hullo!", Branches = {} },
            { Label = "Behold greatness, mortals!", Branches = {} },
            { Label = "Pardon me, is this Sparta?", Branches = {} },
            { Label = "THIS IS SPARTAAAA!", Branches = {} },
        }},
        { Label = "Happy Holidays!", Branches = {
            { Label = "Happy New Year!", Branches = {} },
            { Label = "Happy Valentine's Day!", Branches = {} },
            { Label = "Beware the Ides of March!", Branches = {} },
            { Label = "Happy St. Patrick's Day!", Branches = {} },
            { Label = "Happy Easter!", Branches = {} },
            { Label = "Happy Earth Day!", Branches = {} },
            { Label = "Happy 4th of July!", Branches = {} },
            { Label = "Happy Thanksgiving!", Branches = {} },
            { Label = "Happy Halloween!", Branches = {} },
            { Label = "Happy Hanukkah!", Branches = {} },
            { Label = "Merry Christmas!", Branches = {} },
            { Label = "Happy May Day!", Branches = {} },
            { Label = "Happy Towel Day!", Branches = {} },
            { Label = "Happy ROBLOX Day!", Branches = {} },
            { Label = "Happy LOL Day!", Branches = {} },
        }},
        { Label = "Goodbye", Branches = {
            { Label = "Good Night", Branches = {} },
            { Label = "Sweet dreams", Branches = {} },
            { Label = "Go to sleep!", Branches = {} },
            { Label = "Lights out!", Branches = {} },
            { Label = "Bedtime", Branches = {} },
            { Label = "Going to bed now", Branches = {} },
            { Label = "Later", Branches = {} },
            { Label = "See ya later", Branches = {} },
            { Label = "Later gator!", Branches = {} },
            { Label = "See you tomorrow", Branches = {} },
            { Label = "Bye", Branches = {} },
            { Label = "Hasta la bye bye!", Branches = {} },
            { Label = "I'll be right back", Branches = {} },
            { Label = "I have to go", Branches = {} },
            { Label = "Farewell", Branches = {} },
            { Label = "Take care", Branches = {} },
            { Label = "Have a nice day", Branches = {} },
            { Label = "Goodluck!", Branches = {} },
            { Label = "Ta-ta for now!", Branches = {} },
            { Label = "Peace", Branches = {} },
            { Label = "Peace out!", Branches = {} },
            { Label = "Peace dudes!", Branches = {} },
            { Label = "Rest in pieces!", Branches = {} },
            { Label = "To the batcave!", Branches = {} },
            { Label = "Over and out!", Branches = {} },
            { Label = "Happy trails!", Branches = {} },
            { Label = "I've got to book it!", Branches = {} },
            { Label = "Tootles!", Branches = {} },
            { Label = "Smell you later!", Branches = {} },
            { Label = "GG!", Branches = {} },
            { Label = "My house is on fire!", Branches = {} },
            { Label = "gtg.", Branches = {} },
        }},
        { Label = "Friend", Branches = {
            { Label = "Wanna be friends?", Branches = {} },
            { Label = "Follow me", Branches = {} },
            { Label = "Come to my place!", Branches = {} },
            { Label = "Come to my base!", Branches = {} },
            { Label = "Follow me, team!", Branches = {} },
        }},
        { Label = "Your place is cool", Branches = {
            { Label = "Your place is fun", Branches = {} },
            { Label = "Your place is awesome", Branches = {} },
            { Label = "Your place looks good", Branches = {} },
            { Label = "This place is awesome!", Branches = {} },
        }},
        { Label = "Thank you", Branches = {
            { Label = "Thanks for playing", Branches = {} },
            { Label = "Thanks for visiting", Branches = {} },
            { Label = "Thanks for everything", Branches = {} },
            { Label = "No, thank you", Branches = {} },
            { Label = "Thanx", Branches = {} },
        }},
        { Label = "No problem", Branches = {
            { Label = "Don't worry", Branches = {} },
            { Label = "That's ok", Branches = {} },
            { Label = "np", Branches = {} },
        }},
        { Label = "You are ...", Branches = {
            { Label = "You are great!", Branches = {} },
            { Label = "You are good!", Branches = {} },
            { Label = "You are cool!", Branches = {} },
            { Label = "You are funny!", Branches = {} },
            { Label = "You are silly!", Branches = {} },
            { Label = "You are awesome!", Branches = {} },
            { Label = "You are doing something I don't like, please stop", Branches = {} },
        }},
        { Label = "I like ...", Branches = {
            { Label = "I like your name", Branches = {} },
            { Label = "I like your shirt", Branches = {} },
            { Label = "I like your place", Branches = {} },
            { Label = "I like your style", Branches = {} },
            { Label = "I like you", Branches = {} },
            { Label = "I like items", Branches = {} },
            { Label = "I like money", Branches = {} },
        }},
        { Label = "Sorry", Branches = {
            { Label = "My bad!", Branches = {} },
            { Label = "I'm sorry", Branches = {} },
            { Label = "Whoops!", Branches = {} },
            { Label = "Please forgive me.", Branches = {} },
            { Label = "I forgive you.", Branches = {} },
            { Label = "I didn't mean to do that.", Branches = {} },
            { Label = "Sorry, I'll stop now.", Branches = {} },
        }},
        { Label = "Questions", Branches = {
            { Label = "Who?", Branches = {
                { Label = "Who wants to be my friend?", Branches = {} },
                { Label = "Who wants to be on my team?", Branches = {} },
                { Label = "Who made this brilliant game?", Branches = {} },
                { Label = "LOLWHO?", Branches = {} },
            }},
            { Label = "What?", Branches = {
                { Label = "What is your favorite animal?", Branches = {} },
                { Label = "What is your favorite game?", Branches = {} },
                { Label = "What is your favorite movie?", Branches = {} },
                { Label = "What is your favorite TV show?", Branches = {} },
                { Label = "What is your favorite music?", Branches = {} },
                { Label = "What are your hobbies?", Branches = {} },
                { Label = "LOLWUT?", Branches = {} },
            }},
            { Label = "When?", Branches = {
                { Label = "When are you online?", Branches = {} },
                { Label = "When is the new version coming out?", Branches = {} },
                { Label = "When can we play again?", Branches = {} },
                { Label = "When will your place be done?", Branches = {} },
            }},
            { Label = "Where?", Branches = {
                { Label = "Where do you want to go?", Branches = {} },
                { Label = "Where are you going?", Branches = {} },
                { Label = "Where am I?!", Branches = {} },
                { Label = "Where did you go?", Branches = {} },
            }},
            { Label = "How?", Branches = {
                { Label = "How are you today?", Branches = {} },
                { Label = "How did you make this cool place?", Branches = {} },
                { Label = "LOLHOW?", Branches = {} },
            }},
        }},
        { Label = "Can I...", Branches = {
            { Label = "Can I have a tour?", Branches = {} },
            { Label = "Can I be on your team?", Branches = {} },
            { Label = "Can I be your friend?", Branches = {} },
            { Label = "Can I try something?", Branches = {} },
            { Label = "Can I have that please?", Branches = {} },
            { Label = "Can I have that back please?", Branches = {} },
            { Label = "Can I have borrow your hat?", Branches = {} },
            { Label = "Can I have borrow your gear?", Branches = {} },
        }},
        { Label = "Answers", Branches = {
            { Label = "You need help?", Branches = {} },
            { Label = "Check out the news section", Branches = {} },
            { Label = "Check out the help section", Branches = {} },
            { Label = "Read the wiki!", Branches = {} },
            { Label = "All the answers are in the wiki!", Branches = {} },
            { Label = "I will help you with this.", Branches = {} },
        }},
        { Label = "Some people ...", Branches = {
            { Label = "Me", Branches = {} },
            { Label = "Not me", Branches = {} },
            { Label = "You", Branches = {} },
            { Label = "All of us", Branches = {} },
            { Label = "Everyone but you", Branches = {} },
            { Label = "Builderman!", Branches = {} },
            { Label = "Telamon!", Branches = {} },
            { Label = "My team", Branches = {} },
            { Label = "My group", Branches = {} },
            { Label = "Mom", Branches = {} },
            { Label = "Dad", Branches = {} },
            { Label = "Sister", Branches = {} },
            { Label = "Brother", Branches = {} },
            { Label = "Cousin", Branches = {} },
            { Label = "Grandparent", Branches = {} },
            { Label = "Friend", Branches = {} },
        }},
        { Label = "Time ...", Branches = {
            { Label = "In the morning", Branches = {} },
            { Label = "In the afternoon", Branches = {} },
            { Label = "At night", Branches = {} },
            { Label = "Tomorrow", Branches = {} },
            { Label = "This week", Branches = {} },
            { Label = "This month", Branches = {} },
            { Label = "Sometime", Branches = {} },
            { Label = "Sometimes", Branches = {} },
            { Label = "Whenever you want", Branches = {} },
            { Label = "Never", Branches = {} },
            { Label = "After this", Branches = {} },
            { Label = "In 10 minutes", Branches = {} },
            { Label = "In a couple hours", Branches = {} },
            { Label = "In a couple days", Branches = {} },
        }},
        { Label = "Animals", Branches = {
            { Label = "Cats", Branches = {} },
            { Label = "Lion", Branches = {} },
            { Label = "Tiger", Branches = {} },
            { Label = "Leopard", Branches = {} },
            { Label = "Cheetah", Branches = {} },
            { Label = "Dogs", Branches = {} },
            { Label = "Wolves", Branches = {} },
            { Label = "Beagle", Branches = {} },
            { Label = "Collie", Branches = {} },
            { Label = "Dalmatian", Branches = {} },
            { Label = "Poodle", Branches = {} },
            { Label = "Spaniel", Branches = {} },
            { Label = "Shepherd", Branches = {} },
            { Label = "Terrier", Branches = {} },
            { Label = "Retriever", Branches = {} },
            { Label = "Horses", Branches = {} },
            { Label = "Ponies", Branches = {} },
            { Label = "Stallions", Branches = {} },
            { Label = "Pwnyz", Branches = {} },
            { Label = "Reptiles", Branches = {} },
            { Label = "Dinosaurs", Branches = {} },
            { Label = "Lizards", Branches = {} },
            { Label = "Snakes", Branches = {} },
            { Label = "Turtles!", Branches = {} },
            { Label = "Hamster", Branches = {} },
            { Label = "Monkey", Branches = {} },
            { Label = "Bears", Branches = {} },
            { Label = "Fish", Branches = {} },
            { Label = "Goldfish", Branches = {} },
            { Label = "Sharks", Branches = {} },
            { Label = "Sea Bass", Branches = {} },
            { Label = "Halibut", Branches = {} },
            { Label = "Tropical Fish", Branches = {} },
            { Label = "Birds", Branches = {} },
            { Label = "Eagles", Branches = {} },
            { Label = "Penguins", Branches = {} },
            { Label = "Parakeets", Branches = {} },
            { Label = "Owls", Branches = {} },
            { Label = "Hawks", Branches = {} },
            { Label = "Pidgeons", Branches = {} },
            { Label = "Elephants", Branches = {} },
            { Label = "Mythical Beasts", Branches = {} },
            { Label = "Dragons", Branches = {} },
            { Label = "Unicorns", Branches = {} },
            { Label = "Sea Serpents", Branches = {} },
            { Label = "Sphinx", Branches = {} },
            { Label = "Cyclops", Branches = {} },
            { Label = "Minotaurs", Branches = {} },
            { Label = "Goblins", Branches = {} },
            { Label = "Honest Politicians", Branches = {} },
            { Label = "Ghosts", Branches = {} },
            { Label = "Scylla and Charybdis", Branches = {} },
        }},
        { Label = "Games", Branches = {
            { Label = "Roblox", Branches = {} },
            { Label = "BrickBattle", Branches = {} },
            { Label = "Community Building", Branches = {} },
            { Label = "Roblox Minigames Contest", Branches = {} },
            { Label = "Place", Branches = {} },
            { Label = "Action", Branches = {} },
            { Label = "Puzzle", Branches = {} },
            { Label = "Strategy", Branches = {} },
            { Label = "Racing", Branches = {} },
            { Label = "RPG", Branches = {} },
            { Label = "Obstacle Course", Branches = {} },
            { Label = "Tycoon", Branches = {} },
            { Label = "Board games", Branches = {} },
            { Label = "Chess", Branches = {} },
            { Label = "Checkers", Branches = {} },
            { Label = "Settlers of Catan", Branches = {} },
            { Label = "Tigris and Euphrates", Branches = {} },
            { Label = "El Grande", Branches = {} },
            { Label = "Stratego", Branches = {} },
            { Label = "Carcassonne", Branches = {} },
            { Label = "Sports", Branches = {} },
            { Label = "Hockey", Branches = {} },
            { Label = "Soccer", Branches = {} },
            { Label = "Football", Branches = {} },
            { Label = "Baseball", Branches = {} },
            { Label = "Basketball", Branches = {} },
            { Label = "Volleyball", Branches = {} },
            { Label = "Tennis", Branches = {} },
            { Label = "Sports team practice", Branches = {} },
            { Label = "Watersports", Branches = {} },
            { Label = "Surfing", Branches = {} },
            { Label = "Swimming", Branches = {} },
            { Label = "Water Polo", Branches = {} },
            { Label = "Winter sports", Branches = {} },
            { Label = "Skiing", Branches = {} },
            { Label = "Snowboarding", Branches = {} },
            { Label = "Sledding", Branches = {} },
            { Label = "Skating", Branches = {} },
            { Label = "Adventure", Branches = {} },
            { Label = "Rock climbing", Branches = {} },
            { Label = "Hiking", Branches = {} },
            { Label = "Fishing", Branches = {} },
            { Label = "Horseback riding", Branches = {} },
            { Label = "Wacky", Branches = {} },
            { Label = "Foosball", Branches = {} },
            { Label = "Calvinball", Branches = {} },
            { Label = "Croquet", Branches = {} },
            { Label = "Cricket", Branches = {} },
            { Label = "Dodgeball", Branches = {} },
            { Label = "Squash", Branches = {} },
            { Label = "Trampoline", Branches = {} },
        }},
        { Label = "Movies/TV", Branches = {
            { Label = "Science Fiction", Branches = {} },
            { Label = "Animated", Branches = {} },
            { Label = "Anime", Branches = {} },
            { Label = "Comedy", Branches = {} },
            { Label = "Romantic", Branches = {} },
            { Label = "Action", Branches = {} },
            { Label = "Fantasy", Branches = {} },
        }},
        { Label = "Music", Branches = {
            { Label = "Country", Branches = {} },
            { Label = "Jazz", Branches = {} },
            { Label = "Rap", Branches = {} },
            { Label = "Hip-hop", Branches = {} },
            { Label = "Techno", Branches = {} },
            { Label = "Classical", Branches = {} },
            { Label = "Pop", Branches = {} },
            { Label = "Rock", Branches = {} },
        }},
        { Label = "Hobbies", Branches = {
            { Label = "Computers", Branches = {} },
            { Label = "Building computers", Branches = {} },
            { Label = "Videogames", Branches = {} },
            { Label = "Coding", Branches = {} },
            { Label = "Hacking", Branches = {} },
            { Label = "The Internet", Branches = {} },
            { Label = "lol. teh internets!", Branches = {} },
            { Label = "Watching vids", Branches = {} },
            { Label = "Dance", Branches = {} },
            { Label = "Gymnastics", Branches = {} },
            { Label = "Martial Arts", Branches = {} },
            { Label = "Karate", Branches = {} },
            { Label = "Judo", Branches = {} },
            { Label = "Taikwon Do", Branches = {} },
            { Label = "Wushu", Branches = {} },
            { Label = "Street fighting", Branches = {} },
            { Label = "Listening to music", Branches = {} },
            { Label = "Music lessons", Branches = {} },
            { Label = "Playing in my band", Branches = {} },
            { Label = "Playing piano", Branches = {} },
            { Label = "Playing guitar", Branches = {} },
            { Label = "Playing violin", Branches = {} },
            { Label = "Playing drums", Branches = {} },
            { Label = "Playing a weird instrument", Branches = {} },
            { Label = "Arts and crafts", Branches = {} },
        }},
        { Label = "Location", Branches = {
            { Label = "USA", Branches = {
                { Label = "West", Branches = {
                    { Label = "Alaska", Branches = {} },
                    { Label = "Arizona", Branches = {} },
                    { Label = "California", Branches = {} },
                    { Label = "Colorado", Branches = {} },
                    { Label = "Hawaii", Branches = {} },
                    { Label = "Idaho", Branches = {} },
                    { Label = "Montana", Branches = {} },
                    { Label = "Nevada", Branches = {} },
                    { Label = "New Mexico", Branches = {} },
                    { Label = "Oregon", Branches = {} },
                    { Label = "Utah", Branches = {} },
                    { Label = "Washington", Branches = {} },
                    { Label = "Wyoming", Branches = {} },
                }},
                { Label = "Midwest", Branches = {
                    { Label = "Illinois", Branches = {} },
                    { Label = "Indiana", Branches = {} },
                    { Label = "Iowa", Branches = {} },
                    { Label = "Kansas", Branches = {} },
                    { Label = "Michigan", Branches = {} },
                    { Label = "Minnesota", Branches = {} },
                    { Label = "Missouri", Branches = {} },
                    { Label = "Nebraska", Branches = {} },
                    { Label = "North Dakota", Branches = {} },
                    { Label = "Ohio", Branches = {} },
                    { Label = "South Dakota", Branches = {} },
                    { Label = "Wisconsin", Branches = {} },
                }},
                { Label = "Northeast", Branches = {
                    { Label = "Connecticut", Branches = {} },
                    { Label = "Delaware", Branches = {} },
                    { Label = "Maine", Branches = {} },
                    { Label = "Maryland", Branches = {} },
                    { Label = "Massachusetts", Branches = {} },
                    { Label = "New Hampshire", Branches = {} },
                    { Label = "New Jersey", Branches = {} },
                    { Label = "New York", Branches = {} },
                    { Label = "Pennsylvania", Branches = {} },
                    { Label = "Rhode Island", Branches = {} },
                    { Label = "Vermont", Branches = {} },
                }},
                { Label = "South", Branches = {
                    { Label = "Alabama", Branches = {} },
                    { Label = "Arkansas", Branches = {} },
                    { Label = "Florida", Branches = {} },
                    { Label = "Georgia", Branches = {} },
                    { Label = "Kentucky", Branches = {} },
                    { Label = "Louisiana", Branches = {} },
                    { Label = "Mississippi", Branches = {} },
                    { Label = "North Carolina", Branches = {} },
                    { Label = "Oklahoma", Branches = {} },
                    { Label = "South Carolina", Branches = {} },
                    { Label = "Tennessee", Branches = {} },
                    { Label = "Texas", Branches = {} },
                    { Label = "Virginia", Branches = {} },
                    { Label = "West Virginia", Branches = {} },
                }},
            }},
            { Label = "Canada", Branches = {
                { Label = "Alberta", Branches = {} },
                { Label = "British Columbia", Branches = {} },
                { Label = "Manitoba", Branches = {} },
                { Label = "New Brunswick", Branches = {} },
                { Label = "Newfoundland", Branches = {} },
                { Label = "Northwest Territories", Branches = {} },
                { Label = "Nova Scotia", Branches = {} },
                { Label = "Nunavut", Branches = {} },
                { Label = "Ontario", Branches = {} },
                { Label = "Prince Edward Island", Branches = {} },
                { Label = "Quebec", Branches = {} },
                { Label = "Saskatchewan", Branches = {} },
                { Label = "Yukon", Branches = {} },
            }},
            { Label = "Mexico", Branches = {} },
            { Label = "Central America", Branches = {} },
            { Label = "Europe", Branches = {
                { Label = "Great Britain", Branches = {} },
                { Label = "England", Branches = {} },
                { Label = "Scotland", Branches = {} },
                { Label = "Wales", Branches = {} },
                { Label = "Northern Ireland", Branches = {} },
                { Label = "France", Branches = {} },
                { Label = "Germany", Branches = {} },
                { Label = "Spain", Branches = {} },
                { Label = "Italy", Branches = {} },
                { Label = "Poland", Branches = {} },
                { Label = "Switzerland", Branches = {} },
                { Label = "Greece", Branches = {} },
                { Label = "Romania", Branches = {} },
                { Label = "Netherlands", Branches = {} },
            }},
            { Label = "Asia", Branches = {
                { Label = "China", Branches = {} },
                { Label = "India", Branches = {} },
                { Label = "Japan", Branches = {} },
                { Label = "Korea", Branches = {} },
                { Label = "Russia", Branches = {} },
                { Label = "Vietnam", Branches = {} },
            }},
            { Label = "South America", Branches = {
                { Label = "Argentina", Branches = {} },
                { Label = "Brazil", Branches = {} },
            }},
            { Label = "Africa", Branches = {
                { Label = "Eygpt", Branches = {} },
                { Label = "Swaziland", Branches = {} },
            }},
            { Label = "Australia", Branches = {} },
            { Label = "Middle East", Branches = {} },
            { Label = "Antarctica", Branches = {} },
            { Label = "New Zealand", Branches = {} },
        }},
        { Label = "Age", Branches = {
            { Label = "Rugrat", Branches = {} },
            { Label = "Kid", Branches = {} },
            { Label = "Tween", Branches = {} },
            { Label = "Teen", Branches = {} },
            { Label = "Twenties", Branches = {} },
            { Label = "Old", Branches = {} },
            { Label = "Ancient", Branches = {} },
            { Label = "Mesozoic", Branches = {} },
            { Label = "I don't want to say my age. Don't ask.", Branches = {} },
        }},
        { Label = "Mood", Branches = {
            { Label = "Good", Branches = {} },
            { Label = "Great!", Branches = {} },
            { Label = "Not bad", Branches = {} },
            { Label = "Sad", Branches = {} },
            { Label = "Hyper", Branches = {} },
            { Label = "Chill", Branches = {} },
            { Label = "Happy", Branches = {} },
            { Label = "Kind of mad", Branches = {} },
        }},
        { Label = "Boy", Branches = {
            { Label = "Girl", Branches = {} },
            { Label = "I don't want to say boy or girl. Don't ask.", Branches = {} },
        }},
        { Label = "Game", Branches = {
            { Label = "Let's build", Branches = {} },
            { Label = "Let's battle", Branches = {} },
            { Label = "Nice one!", Branches = {} },
            { Label = "So far so good!", Branches = {} },
            { Label = "Lucky shot!", Branches = {} },
            { Label = "Oh man!", Branches = {} },
            { Label = "I challenge you to a fight!", Branches = {} },
            { Label = "Help me with this", Branches = {} },
            { Label = "Let's go to your game", Branches = {} },
            { Label = "Can you show me how do to that?", Branches = {} },
            { Label = "Backflip!", Branches = {} },
            { Label = "Frontflip!", Branches = {} },
            { Label = "Dance!", Branches = {} },
            { Label = "I'm on your side!", Branches = {} },
        }},
        { Label = "Game Commands", Branches = {
            { Label = "regen", Branches = {} },
            { Label = "reset", Branches = {} },
            { Label = "go", Branches = {} },
            { Label = "fix", Branches = {} },
            { Label = "respawn", Branches = {} },
        }},
        { Label = "Silly", Branches = {
            { Label = "Muahahahaha!", Branches = {} },
            { Label = "all your base are belong to me!", Branches = {} },
            { Label = "GET OFF MAH LAWN", Branches = {} },
            { Label = "TEH EPIK DUCK IS COMING!!!", Branches = {} },
            { Label = "ROFL", Branches = {} },
            { Label = "1337", Branches = {} },
            { Label = "i r teh pwnz0r!", Branches = {} },
            { Label = "w00t!", Branches = {} },
            { Label = "z0mg h4x!", Branches = {} },
            { Label = "ub3rR0xXorzage!", Branches = {} },
        }},
        { Label = "Yes", Branches = {
            { Label = "Absolutely!", Branches = {} },
            { Label = "Rock on!", Branches = {} },
            { Label = "Totally!", Branches = {} },
            { Label = "Juice!", Branches = {} },
            { Label = "Yay!", Branches = {} },
            { Label = "Yesh", Branches = {} },
        }},
        { Label = "No", Branches = {
            { Label = "Ummm.", Branches = {} },
            { Label = "No.", Branches = {} },
            { Label = "Stop!", Branches = {} },
            { Label = "Go away!", Branches = {} },
            { Label = "Don't do that", Branches = {} },
            { Label = "Stop breaking the rules", Branches = {} },
            { Label = "I don't want to", Branches = {} },
        }},
        { Label = "Ok", Branches = {
            { Label = "Well... ok", Branches = {} },
            { Label = "Sure", Branches = {} },
        }},
        { Label = "Uncertain", Branches = {
            { Label = "Maybe", Branches = {} },
            { Label = "I don't know", Branches = {} },
            { Label = "idk", Branches = {} },
            { Label = "I can't decide", Branches = {} },
            { Label = "Hmm...", Branches = {} },
        }},
        { Label = "Emoticons", Branches = {
            { Label = ":-)", Branches = {} },
            { Label = ":-( ", Branches = {} },
            { Label = ":D", Branches = {} },
            { Label = ":-O", Branches = {} },
            { Label = "lol", Branches = {} },
            { Label = "=D", Branches = {} },
            { Label = "D=", Branches = {} },
            { Label = "XD", Branches = {} },
            { Label = ";D", Branches = {} },
            { Label = ";)", Branches = {} },
            { Label = "O_O", Branches = {} },
            { Label = "=)", Branches = {} },
            { Label = "@_@", Branches = {} },
            { Label = ">_<", Branches = {} },
            { Label = "T_T", Branches = {} },
            { Label = "^_^", Branches = {} },
            { Label = "<(0_0<)", Branches = {} },
            { Label = "<(0_0)>", Branches = {} },
            { Label = "(>0_0)>", Branches = {} },
            { Label = "KIRBY DANCE", Branches = {} },
            { Label = ")", Branches = {} },
            { Label = "';", Branches = {} },
            { Label = ":3", Branches = {} },
        }},
        { Label = "Ratings", Branches = {
            { Label = "Rate it!", Branches = {} },
            { Label = "I give it a 1 out of 10", Branches = {} },
            { Label = "I give it a 2 out of 10", Branches = {} },
            { Label = "I give it a 3 out of 10", Branches = {} },
            { Label = "I give it a 4 out of 10", Branches = {} },
            { Label = "I give it a 5 out of 10", Branches = {} },
            { Label = "I give it a 6 out of 10", Branches = {} },
            { Label = "I give it a 7 out of 10", Branches = {} },
            { Label = "I give it a 8 out of 10", Branches = {} },
            { Label = "I give it a 9 out of 10", Branches = {} },
            { Label = "I give it a 10 out of 10!", Branches = {} },
        }},
    }
}

-- [HELPERS]
local TOP_ORDER = 2147483647
local TOP_Z     = 2000000000

local function instanceNewData(datatype, properties)
    local Item = Instance.new(datatype)
    if Item then
        for property, value in pairs(properties) do
            Item[property] = value
        end
    end
    return Item
end

local function getViewport()
    -- (in the menu's own units: the screen divided by how far it is zoomed down)
    local s = uiScale()
    local cam = workspace.CurrentCamera
    if cam then return cam.ViewportSize.X / s, cam.ViewportSize.Y / s end
    return 800 / s, 600 / s
end

-- =========================================================
-- [BLOXY PARADOX DETECTION]
-- SafeChat refuses to touch bubble-chat settings if ANY trace
-- of the Bloxy Paradox system is present. This list is
-- deliberately broad so we never fight the wizard, the 2011
-- bubble hook, the 2015/2016 bubble hook, or any variant.
-- =========================================================
local function bloxyParadoxPresent()
    -- 1. getgenv flags set by Bloxy scripts
    if getgenv then
        local flags = {
            "BP_TrueLS",             -- hooks installed
            "BP_PendingTopbar",      -- user selected a variant, awaiting confirm
            "BP_2023Variant",        -- 2023 new/old chosen
            "Force2008BubbleChat",   -- 2013 mobile bubble flag
            "BP_2013Active",         -- custom flag some forks set
            "BP_Bubble2011Loaded",   -- 2011 bubble hook finished
            "BP_Bubble2015Loaded",   -- 2015/2016 bubble hook finished
        }
        for _, key in ipairs(flags) do
            local ok, val = pcall(function() return getgenv()[key] end)
            if ok and val ~= nil and val ~= false then
                return true
            end
        end
    end

    -- 2. Config file on disk
    if isfile and readfile then
        local ok, exists = pcall(isfile, "BloxyParadoxConfig.json")
        if ok and exists then
            return true
        end
    end

    -- 3. Any Bloxy/Legacy/Classic/Bubble/Mobile ScreenGui in the wild
    local lp = Players.LocalPlayer
    if lp then
        local function scan(container)
            if not container then return false end
            for _, c in ipairs(container:GetChildren()) do
                if c:IsA("ScreenGui") then
                    local n = c.Name or ""
                    if n:find("Bloxy", 1, true)
                    or n:find("Legacy", 1, true)
                    or n:find("Classic", 1, true)
                    or n:find("Bubble", 1, true)
                    or n:find("Mobile", 1, true) then
                        return true
                    end
                end
            end
            return false
        end

        local pg = lp:FindFirstChild("PlayerGui")
        if scan(pg) then return true end

        if gethui then
            local ok, hui = pcall(gethui)
            if ok and hui and scan(hui) then return true end
        end

        local ok, cg = pcall(function() return game:GetService("CoreGui") end)
        if ok and cg and scan(cg) then return true end
    end

    -- 4. BloxyParadoxProject ScreenGui (the wizard itself)
    local lp2 = Players.LocalPlayer
    if lp2 then
        local pg = lp2:FindFirstChild("PlayerGui")
        if pg and pg:FindFirstChild("BloxyParadoxProject") then
            return true
        end
    end

    return false
end

-- =========================================================
-- [BUBBLE CHAT SUPPRESSION — DETECTION-AWARE]
-- =========================================================
local suppressBubbles = true

local function suppressNativeBubbles()
    if not suppressBubbles then return end
    -- If Bloxy Paradox (any part of it) is running, do nothing.
    if bloxyParadoxPresent() then return end
    pcall(function() TextChatService.BubbleChatConfiguration.Enabled = false end)
    pcall(function() ChatService.BubbleChatEnabled = false end)
end

-- Initial sweep — only fires if Bloxy isn't running.
suppressNativeBubbles()

-- Slow periodic sweep (cheap, catches respawn re-enables).
task.spawn(function()
    while true do
        task.wait(2)
        suppressNativeBubbles()
    end
end)

-- Property hooks that only revert when Bloxy isn't around.
pcall(function()
    local cfg = TextChatService.BubbleChatConfiguration
    cfg:GetPropertyChangedSignal("Enabled"):Connect(function()
        if suppressBubbles and cfg.Enabled and not bloxyParadoxPresent() then
            cfg.Enabled = false
        end
    end)
end)

pcall(function()
    ChatService:GetPropertyChangedSignal("BubbleChatEnabled"):Connect(function()
        if suppressBubbles and ChatService.BubbleChatEnabled and not bloxyParadoxPresent() then
            ChatService.BubbleChatEnabled = false
        end
    end)
end)

-- [CLEANUP OLD]
local uiParent = getUIParent()
for _, name in ipairs({"SafeChatGUI", "SC_Gui"}) do
    local old = uiParent:FindFirstChild(name)
    if old then old:Destroy() end
end

-- [GUI — forced to topmost layer]
local SC_Gui = instanceNewData("ScreenGui", {
    Name = "SC_Gui",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
    DisplayOrder = TOP_ORDER,
    Enabled = true,
    Parent = uiParent
})

local SC_Root = instanceNewData("Frame", {
    Name = "SC_Root",
    BackgroundTransparency = 1,
    Position = UDim2.fromScale(0, 0),
    Size = UDim2.fromScale(1, 1),
    ZIndex = TOP_Z,
    Parent = SC_Gui
})

local SC_Btn = instanceNewData("ImageButton", {
    Name = "SC_Btn",
    BackgroundTransparency = 1,
    Position = UDim2.fromScale(0.02, 0.535),
    Size = UDim2.fromOffset(32, 32),
    Image = "rbxassetid://991182833",
    ZIndex = TOP_Z,
    Parent = SC_Root
})

local SC_Click = instanceNewData("Sound", {
    Name = "SC_Click",
    SoundId = "rbxasset://sounds/switch.mp3",
    Volume = 0.5,
    Parent = SC_Btn
})

local SC_Template = instanceNewData("TextButton", {
    Name = "SC_Template",
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BorderColor3     = Color3.fromRGB(62, 62, 62),
    BorderSizePixel  = 1,
    Size             = UDim2.fromOffset(140, 24),
    Font             = Enum.Font.SourceSansBold,
    TextSize         = 12,
    TextScaled       = true,
    TextWrapped      = false,
    TextStrokeTransparency = 0.95,
    TextTransparency = 0.25,
    TextColor3       = Color3.fromRGB(27, 42, 53),
    TextXAlignment   = Enum.TextXAlignment.Center,
    AutoButtonColor  = true,
    ZIndex           = TOP_Z,
    Parent = SC_Root,
    Visible = false
})
instanceNewData("UITextSizeConstraint", {
    MaxTextSize = 12,
    MinTextSize = 7,
    Parent = SC_Template
})
instanceNewData("UIPadding", {
    PaddingLeft  = UDim.new(0, 4),
    PaddingRight = UDim.new(0, 4),
    Parent = SC_Template
})

-- [CHAT SEND]
local function sendChatMessage(text)
    local sent = false
    pcall(function()
        local channel = TextChatService:FindFirstChild("RBXGeneral", true)
        if channel and channel:IsA("TextChannel") then
            channel:SendAsync(text)
            sent = true
        end
    end)
    if not sent then
        pcall(function()
            local legacy = game:GetService("Chat")
            local head = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("Head")
            legacy:Chat(head, text, Enum.ChatColor.White)
        end)
    end
    return sent
end

-- [CASCADING FLYOUT SYSTEM]
local COL_W = 150
local COL_GAP = 6
local COL_START_X = 60
local COL_TOP_MARGIN = 10
local COL_BOTTOM_MARGIN = 60
local MAX_COL_HEIGHT_RATIO = 0.75

local PAD_TOP    = 4
local PAD_BOTTOM = 12
local PAD_LEFT   = 4
local PAD_RIGHT  = 8

local openColumns = {}
local interactionLocked = false
local isMenuOpen = false

local function relayoutColumns()
    local screenW = getViewport()
    local count = #openColumns
    if count == 0 then return end

    local totalW = count * COL_W + (count - 1) * COL_GAP
    local rightEdge = COL_START_X + totalW
    local shift = math.max(0, rightEdge + 10 - screenW)

    for i, col in ipairs(openColumns) do
        local x = COL_START_X + (i - 1) * (COL_W + COL_GAP) - shift
        local y = col.frame.Position.Y.Offset
        col.frame.Position = UDim2.fromOffset(x, y)
    end
end

local function closeColumnsFrom(startIdx)
    for i = #openColumns, startIdx, -1 do
        openColumns[i].frame:Destroy()
        table.remove(openColumns, i)
    end
    relayoutColumns()
end

local function closeAllColumns()
    closeColumnsFrom(1)
end

local openColumn -- forward declaration

local function commitMessage(label)
    sendChatMessage(label)
    SC_Click:Play()
    closeAllColumns()
    isMenuOpen = false
    SC_Btn.Image = "rbxassetid://991182833"
end

openColumn = function(node, desiredY, parentButton)
    local screenW, screenH = getViewport()
    local colIdx = #openColumns + 1

    local frame = instanceNewData("ScrollingFrame", {
        Name = "SC_Col" .. colIdx,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(COL_START_X, desiredY or (screenH * 0.3)),
        Size = UDim2.fromOffset(COL_W, 40),
        AnchorPoint = Vector2.new(0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150),
        ScrollBarImageTransparency = 0.3,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        ClipsDescendants = true,
        ZIndex = TOP_Z,
        Visible = false,
        Parent = SC_Root
    })

    local content = instanceNewData("Frame", {
        Name = "SC_Content",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = TOP_Z,
        Parent = frame
    })

    instanceNewData("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = content
    })

    instanceNewData("UIPadding", {
        PaddingTop    = UDim.new(0, PAD_TOP),
        PaddingBottom = UDim.new(0, PAD_BOTTOM),
        PaddingLeft   = UDim.new(0, PAD_LEFT),
        PaddingRight  = UDim.new(0, PAD_RIGHT),
        Parent = content
    })

    local order = 0

    if colIdx > 1 then
        order = order + 1
        local back = SC_Template:Clone()
        back.Name = "SC_Item"
        back.Text = "Back"
        back.LayoutOrder = order
        back.ZIndex = TOP_Z
        back.Visible = true
        back.Parent = content
        back.Activated:Connect(function()
            if not back.Parent then return end
            closeColumnsFrom(colIdx)
        end)
    end

    for _, branch in ipairs(node.Branches or {}) do
        order = order + 1
        local label = branch.Label or "…"
        local hasChildren = branch.Branches and #branch.Branches > 0

        local btn = SC_Template:Clone()
        btn.Name = "SC_Item"
        btn.Text = label
        btn.LayoutOrder = order
        btn.ZIndex = TOP_Z
        btn.Visible = true
        btn.Parent = content

        btn.Activated:Connect(function()
            if not btn.Parent then return end
            if interactionLocked then return end
            interactionLocked = true
            task.delay(0.18, function() interactionLocked = false end)

            local subCol = openColumns[colIdx + 1]
            local submenuAlreadyOpen = subCol and subCol.parentButton == btn

            if hasChildren and not submenuAlreadyOpen then
                local relY = (btn.AbsolutePosition.Y - SC_Root.AbsolutePosition.Y) / uiScale()
                closeColumnsFrom(colIdx + 1)
                openColumn(branch, relY, btn)
            else
                commitMessage(label)
            end
        end)
    end

    table.insert(openColumns, {
        frame = frame,
        node = node,
        parentButton = parentButton,
    })

    task.defer(function()
        task.wait()
        if not frame.Parent then return end

        local contentH = content.AbsoluteSize.Y / uiScale()
        local maxH = screenH * MAX_COL_HEIGHT_RATIO
        local colH = math.max(40, math.min(contentH, maxH))
        frame.Size = UDim2.fromOffset(COL_W, colH)

        local y = frame.Position.Y.Offset
        y = math.max(COL_TOP_MARGIN, math.min(y, screenH - colH - COL_BOTTOM_MARGIN))
        frame.Position = UDim2.fromOffset(frame.Position.X.Offset, y)
        frame.CanvasPosition = Vector2.new(0, 0)

        frame.Visible = true
        relayoutColumns()
    end)
end

-- [TOGGLE]
SC_Btn.Activated:Connect(function()
    if interactionLocked then return end
    interactionLocked = true
    task.delay(0.18, function() interactionLocked = false end)

    isMenuOpen = not isMenuOpen
    if isMenuOpen then
        closeAllColumns()
        local _, screenH = getViewport()
        openColumn(safeChatData, screenH * 0.3, nil)
        SC_Btn.Image = "rbxassetid://991182832"
    else
        closeAllColumns()
        SC_Btn.Image = "rbxassetid://991182833"
    end
end)

SC_Btn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch and not isMenuOpen then
        SC_Btn.Image = "rbxassetid://991182834"
    end
end)
SC_Btn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch and not isMenuOpen then
        SC_Btn.Image = "rbxassetid://991182833"
    end
end)

workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    if isMenuOpen then relayoutColumns() end
end)

-- =========================================================
-- [WATCHDOG] — position/parent/layer enforcement only.
-- Bubble suppression is handled separately above with its own
-- detection guard, so it never fights Bloxy Paradox.
-- =========================================================
local LOCKED_ROOT_POS  = UDim2.fromScale(0, 0)
local LOCKED_ROOT_SIZE = UDim2.fromScale(1, 1)
-- (Addtion-Scripts) the zoom: the root is made bigger by as much as it is zoomed down
local SC_Scale = Instance.new("UIScale")
SC_Scale.Name = "BPSafeChatScale"
SC_Scale.Parent = SC_Root
local LOCKED_BTN_POS   = UDim2.fromScale(0.02, 0.535)
local LOCKED_BTN_SIZE  = UDim2.fromOffset(32, 32)

RunService.RenderStepped:Connect(function()
    if SC_Gui.Parent ~= uiParent then
        pcall(function() SC_Gui.Parent = uiParent end)
    end
    if SC_Gui.Enabled ~= true then SC_Gui.Enabled = true end
    if SC_Gui.IgnoreGuiInset ~= true then SC_Gui.IgnoreGuiInset = true end
    if SC_Gui.DisplayOrder ~= TOP_ORDER then SC_Gui.DisplayOrder = TOP_ORDER end
    if SC_Gui.ZIndexBehavior ~= Enum.ZIndexBehavior.Global then
        SC_Gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    end

    if SC_Root.Parent ~= SC_Gui then
        pcall(function() SC_Root.Parent = SC_Gui end)
    end
    local zoom = uiScale()
    if SC_Scale.Parent ~= SC_Root then pcall(function() SC_Scale.Parent = SC_Root end) end
    if SC_Scale.Scale ~= zoom then SC_Scale.Scale = zoom end
    LOCKED_ROOT_SIZE = UDim2.fromScale(1 / zoom, 1 / zoom)
    if SC_Root.Position ~= LOCKED_ROOT_POS then SC_Root.Position = LOCKED_ROOT_POS end
    if SC_Root.Size ~= LOCKED_ROOT_SIZE then SC_Root.Size = LOCKED_ROOT_SIZE end
    if SC_Root.BackgroundTransparency ~= 1 then SC_Root.BackgroundTransparency = 1 end
    if SC_Root.ZIndex ~= TOP_Z then SC_Root.ZIndex = TOP_Z end

    if SC_Btn.Parent ~= SC_Root then
        pcall(function() SC_Btn.Parent = SC_Root end)
    end
    if SC_Btn.Position ~= LOCKED_BTN_POS then SC_Btn.Position = LOCKED_BTN_POS end
    if SC_Btn.Size ~= LOCKED_BTN_SIZE then SC_Btn.Size = LOCKED_BTN_SIZE end
    if SC_Btn.BackgroundTransparency ~= 1 then SC_Btn.BackgroundTransparency = 1 end
    if SC_Btn.ZIndex ~= TOP_Z then SC_Btn.ZIndex = TOP_Z end

    for _, col in ipairs(openColumns) do
        if col.frame and col.frame.Parent ~= SC_Root then
            pcall(function() col.frame.Parent = SC_Root end)
        end
        if col.frame and col.frame.ZIndex ~= TOP_Z then
            col.frame.ZIndex = TOP_Z
        end
    end
end)

-- [CLEANUP]
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == _G.keyToDestroy then
        SC_Gui:Destroy()
    end
end)