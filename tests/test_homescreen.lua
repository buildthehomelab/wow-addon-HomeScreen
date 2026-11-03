-- Mock tests of the addon's logic: lua tests/test_homescreen.lua, from the repo root. Whether the
-- client's own calls behave needs the game client.

local failures, checks = 0, 0
local function check(name, condition)
    checks = checks + 1
    if not condition then
        failures = failures + 1
        print("FAIL: " .. name)
    end
end

strsplit = function(sep, text)
    local out, at = {}, 1
    while true do
        local s = string.find(text, sep, at, true)
        if not s then
            out[#out + 1] = string.sub(text, at)
            break
        end
        out[#out + 1] = string.sub(text, at, s - 1)
        at = s + 1
    end
    return (unpack or table.unpack)(out)
end

local frames
local function NewFrame()
    local frame = { scripts = {}, shown = true, events = {} }
    function frame:SetScript(script, f) self.scripts[script] = f end
    function frame:HookScript(script, f) self.scripts[script] = f end
    function frame:SetAttribute(name, value) self.attributes = self.attributes or {}; self.attributes[name] = value end
    function frame:GetEffectiveScale() return 1 end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:SetText(text) self.text = text end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:CreateFontString() return NewFrame() end
    function frame:LockHighlight() self.locked = true end
    function frame:UnlockHighlight() self.locked = false end
    for _, method in ipairs({ "SetWidth", "SetHeight", "SetPoint", "ClearAllPoints", "SetFrameStrata", "SetBackdrop", "SetBackdropColor" }) do
        frame[method] = function() end
    end
    frames[#frames + 1] = frame
    return frame
end

local function Load(character)
    frames = {}
    local game = { commands = {}, logouts = 0, orbit = false, ui = true, messages = {}, units = {}, zoom = 10 }
    function CreateFrame() return NewFrame() end
    function UnitName() return character end
    function SendAddonMessage(prefix, text, channel, target)
        assert(prefix == "AzerothCore" and channel == "WHISPER" and target == character)
        game.commands[#game.commands + 1] = text
    end
    function Logout() game.logouts = game.logouts + 1 end
    function MoveViewRightStart() game.orbit = true end
    function MoveViewRightStop() game.orbit = false end
    function SetView(view) game.view = view end
    function SaveView(view) game.saved = view end
    function CameraZoomIn(yards) game.zoom = math.max(0, game.zoom - yards) end
    function CameraZoomOut(yards) game.zoom = game.zoom + yards end
    function UnitGUID(unit) return game.units[unit] end
    function GetCursorPosition() return 100, 100 end
    UIParent = NewFrame()
    function UIParent:Hide() game.ui = false end
    function UIParent:Show() game.ui = true end
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) game.messages[#game.messages + 1] = text end }
    SlashCmdList = {}
    assert(loadfile("HomeScreen/HomeScreen.lua"))()
    for _, frame in ipairs(frames) do
        if frame.events.PLAYER_ENTERING_WORLD then game.frame = frame end
    end
    function game.Enter() game.frame.scripts.OnEvent(game.frame, "PLAYER_ENTERING_WORLD") end
    function game.Fire(event) game.frame.scripts.OnEvent(game.frame, event) end
    function game.Hear(text, from)
        game.frame.scripts.OnEvent(game.frame, "CHAT_MSG_ADDON", "HOMESCREEN", text, "WHISPER", from or character)
    end
    function game.Button(text)
        for _, frame in ipairs(frames) do
            if frame.text == text and frame.scripts.OnClick then return frame end
        end
    end
    return game
end

local clock = 1000
function time() return clock end
HomeScreenDB = nil

-- A real character: asks, gets no answer, and nothing changes
local game = Load("Griffith")
game.Enter()
check("real: asked", game.commands[1] == "i0001home list")
check("real: UI stays", game.ui)
check("real: camera stays", not game.orbit)
game.frame.scripts.OnUpdate(game.frame, 6)
check("real: asks once more", game.commands[2] == "i0002home list")
game.frame.scripts.OnUpdate = nil
check("real: one retry only", #game.commands == 2)

-- The viewer: the UI goes, the camera holds still, the list shows
game = Load("Hvba")
game.Enter()
game.Hear("begin")
check("viewer: UI hidden", not game.ui)
check("viewer: camera holds still", not game.orbit)
game.Hear("row\tGriffith\t1\t1\t80\t12")
game.Hear("row\tPawster\t4\t11\t70\t1519")
game.Hear("end")
local function rows_seen()
    local seen = {}
    for _, frame in ipairs(frames) do
        if frame.character then seen[#seen + 1] = frame.character.name end
    end
    return seen
end
local griffith, pawster
for _, frame in ipairs(frames) do
    if frame.character and frame.character.name == "Griffith" then griffith = frame end
    if frame.character and frame.character.name == "Pawster" then pawster = frame end
end
check("viewer: rows", griffith and pawster)
check("viewer: first selected", griffith.locked)
game.frame.scripts.OnUpdate(game.frame, 6)
check("viewer: no retry once answered", #game.commands == 1)

-- Someone else's whisper does nothing
game.Hear("begin", "Mallory")
check("whisper from another: ignored", #rows_seen() == 2)

-- Play sends the target and logs out, in that order
pawster.scripts.OnClick(pawster)
check("play: selected", pawster.locked and not griffith.locked)
clock = 1100
game.Button("Play").scripts.OnClick()
check("play: command", game.commands[#game.commands] == "i0002home play Pawster")
check("play: logged out", game.logouts == 1)
check("play: camera stopped", not game.orbit)
check("play: clock started", HomeScreenDB.clicked == 1100)

-- The character it entered reports the time
clock = 1106
game = Load("Pawster")
game.Enter()
check("arrival: reported", game.messages[1] and string.find(game.messages[1], "6 s", 1, true) ~= nil)
check("arrival: clock cleared", HomeScreenDB.clicked == nil)

-- Character select needs no clock
game = Load("Hvba")
game.Enter()
game.Hear("begin")
game.Hear("row\tGriffith\t1\t1\t80\t12")
game.Hear("end")
game.Button("Character select").scripts.OnClick()
check("glue: command", game.commands[#game.commands] == "i0002home glue")
check("glue: logged out", game.logouts == 1 and HomeScreenDB.clicked == nil)

-- Save camera comes back next time
game.Button("Save camera").scripts.OnClick()
check("camera: saved", game.saved == 5 and HomeScreenDB.camera)
game = Load("Hvba")
game.Enter()
game.Hear("begin")
check("camera: restored", game.view == 5)

-- Show UI, and the slash command goes back and forth
game.Button("Show UI").scripts.OnClick()
check("show UI", game.ui and not game.orbit)
SlashCmdList["HOMESCREEN"]("")
check("slash: back to the window", not game.ui)
SlashCmdList["HOMESCREEN"]("")
check("slash: the UI again", game.ui and not game.orbit)

-- The camera only turns if it was asked to, and that's remembered
SlashCmdList["HOMESCREEN"]("")
game.Button("Camera: stop/turn").scripts.OnClick()
check("orbit: on when asked", game.orbit and HomeScreenDB.orbit == true)
game = Load("Hvba")
game.Enter()
game.Hear("begin")
check("orbit: remembered", game.orbit)
game.Button("Camera: stop/turn").scripts.OnClick()
check("orbit: off again", not game.orbit and HomeScreenDB.orbit == false)

-- A saved view isn't overridden by the starting distance
game.Hear("camera\t6")
check("camera: saved view wins", game.zoom == 10)
HomeScreenDB.camera = nil
game = Load("Hvba")
game.Enter()
game.Hear("begin")
game.Hear("camera\t6")
check("camera: starts at the distance", game.zoom == 6)
game.zoom = 20
game.Hear("camera\t6")
check("camera: only once", game.zoom == 20)

-- Clicking a figure selects its character, on whichever page they are
game = Load("Hvba")
game.Enter()
game.Hear("begin")
for i = 1, 30 do game.Hear(("row\tChar%02d\t1\t1\t10\t12"):format(i)) end
game.Hear("end")
game.Hear("figures")
game.Hear("figure\tF1300E0B4C000123\tChar20")
game.Hear("figure\tF1300E0B4C000124\tChar20")
game.Hear("figure\tF1300E0B4C000125\tChar02")
local function row_of(name)
    for _, frame in ipairs(frames) do
        if frame.character and frame.character.name == name and frame.shown then return frame end
    end
end
game.units.target = "0xF1300E0B4C000123"
game.Fire("PLAYER_TARGET_CHANGED")
check("figure: selected on its page", row_of("Char20") and row_of("Char20").locked)
game.units.target = "0xf1300e0b4c000125"
game.Fire("PLAYER_TARGET_CHANGED")
check("figure: any case of GUID", row_of("Char02") and row_of("Char02").locked)
game.units.target = "0xF1300E0B4C000124"
game.Fire("PLAYER_TARGET_CHANGED")
check("figure: a pet picks its owner", row_of("Char20") and row_of("Char20").locked)

-- Anything else targeted changes nothing, nor does losing the target
game.units.target = "0xF130000000000001"
game.Fire("PLAYER_TARGET_CHANGED")
check("figure: other unit ignored", row_of("Char20").locked)
game.units.target = nil
game.Fire("PLAYER_TARGET_CHANGED")
check("figure: no target ignored", row_of("Char20").locked)

-- A row clears the target, and everyone in the list can still be picked
local cleared = row_of("Char20")
check("row: clears the target", cleared.attributes.type == "macro" and cleared.attributes.macrotext == "/cleartarget")
game.Button("Play").scripts.OnClick()
check("figure: Play goes to them", game.commands[#game.commands]:find("home play Char20", 1, true) ~= nil)

-- A new set of figures replaces the old
game = Load("Hvba")
game.Enter()
game.Hear("begin")
game.Hear("row\tGriffith\t1\t1\t80\t12")
game.Hear("row\tPawster\t4\t11\t70\t1519")
game.Hear("end")
game.Hear("figure\tF1300E0B4C000123\tPawster")
game.Hear("figures")
game.units.target = "0xF1300E0B4C000123"
game.Fire("PLAYER_TARGET_CHANGED")
check("figures: forgotten", row_of("Griffith").locked)

-- Figures heard before the list still work
game = Load("Hvba")
game.Enter()
game.Hear("figure\tF1300E0B4C000123\tPawster")
game.Hear("begin")
game.Hear("row\tGriffith\t1\t1\t80\t12")
game.Hear("row\tPawster\t4\t11\t70\t1519")
game.Hear("end")
game.units.target = "0xF1300E0B4C000123"
game.Fire("PLAYER_TARGET_CHANGED")
check("figures: before the list", row_of("Pawster").locked)

-- Hovering names a figure, and the name goes when the cursor leaves
local before = #frames
game.units.mouseover = "0xF1300E0B4C000123"
game.Fire("UPDATE_MOUSEOVER_UNIT")
local hover = frames[before + 1]
check("hover: shown", hover and hover.shown and hover.text.text:find("Pawster", 1, true) ~= nil)
game.units.mouseover = nil
hover.scripts.OnUpdate(hover)
check("hover: gone", not hover.shown)
game.units.mouseover = "0xF130000000000001"
game.Fire("UPDATE_MOUSEOVER_UNIT")
check("hover: not for others", not hover.shown)

-- A panel that can't be built leaves the UI up
HomeScreenDB = {}
game = Load("Hvba")
game.Enter()
local realCreateFrame = CreateFrame
function CreateFrame() error("no such template") end
check("panel fails: error reaches the caller", not pcall(game.Hear, "begin"))
CreateFrame = realCreateFrame
check("panel fails: UI stays", game.ui)

-- On a real character the events do nothing
game = Load("Griffith")
game.Enter()
game.units.target = "0xF1300E0B4C000123"
game.Hear("figure\tF1300E0B4C000123\tPawster")
game.Fire("PLAYER_TARGET_CHANGED")
game.units.mouseover = "0xF1300E0B4C000123"
before = #frames
game.Fire("UPDATE_MOUSEOVER_UNIT")
check("real: no hover", #frames == before)

-- More characters than a page
game = Load("Hvba")
game.Enter()
game.Hear("begin")
for i = 1, 30 do game.Hear(("row\tChar%02d\t1\t1\t10\t12"):format(i)) end
game.Hear("end")
local shown = 0
for _, frame in ipairs(frames) do
    if frame.character then shown = shown + 1 end
end
check("pages: first page", shown == 12)
game.Button(">").scripts.OnClick()
local thirteenth = false
for _, frame in ipairs(frames) do
    if frame.character and frame.character.name == "Char13" then thirteenth = true end
end
check("pages: next page", thirteenth)

print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
