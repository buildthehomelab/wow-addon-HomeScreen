-- The home screen's window. When the server says this character is the account's viewer (it answers
-- ".home list" only then), the UI goes away, the camera turns slowly and the window lists the account's
-- characters. On every other character this does nothing but report how long Play took.
--
-- Commands go over AzerothCore's addon command channel, answers come as addon whispers with the prefix
-- HOMESCREEN. See mod-playerhousing's docs/HOME_SCREEN.md.

local ADDON_PREFIX = "HOMESCREEN"
local CHANNEL_PREFIX = "AzerothCore"
local ORBIT_SPEED = 0.01
local VIEW = 5              -- the saved camera slot "Save camera" uses
local ROWS = 12             -- characters on one page
local ROW_HEIGHT = 25
local RETRY_SECONDS = 5     -- asks once more if the first answer never came

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", nil, "DRUID" }

HomeScreenDB = HomeScreenDB or {}

local commandCount = 0
local function Command(text)
    commandCount = commandCount % 9999 + 1
    SendAddonMessage(CHANNEL_PREFIX, ("i%04dhome %s"):format(commandCount, text), "WHISPER", UnitName("player"))
end

local roster, incoming = {}, nil
local panel, rows, chosen, pageText
local selected, page, orbiting = nil, 1, false
local inHome, answered = false, false

local function Orbit(on)
    orbiting = on
    if on then
        MoveViewRightStart(ORBIT_SPEED)
    else
        MoveViewRightStop()
    end
end

local function Colored(character)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[CLASSES[character.class] or ""]
    local name = color and ("|cff%02x%02x%02x%s|r"):format(color.r * 255, color.g * 255, color.b * 255, character.name) or character.name
    return ("%s  %d"):format(name, character.level)
end

local function MakeButton(width, height, text, onClick)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetWidth(width)
    button:SetHeight(height)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function ShowRoster()
    local pages = math.max(1, math.ceil(#roster / ROWS))
    page = math.min(page, pages)
    for i, row in ipairs(rows) do
        local character = roster[(page - 1) * ROWS + i]
        row.character = character
        if character then
            row:SetText(Colored(character))
            if character.name == selected then
                row:LockHighlight()
            else
                row:UnlockHighlight()
            end
            row:Show()
        else
            row:Hide()
        end
    end
    pageText:SetText(pages > 1 and ("%d / %d"):format(page, pages) or "")
    chosen:SetText(selected or "")
end

-- The session handles the command and then the logout, in the order they're sent.
local function LeaveFor(command)
    Command(command)
    Orbit(false)
    Logout()
end

local function Play()
    if selected then
        HomeScreenDB.clicked = time()
        LeaveFor("play " .. selected)
    end
end

local function BuildPanel()
    panel = CreateFrame("Frame", "HomeScreenPanel", nil)
    panel:SetFrameStrata("DIALOG")
    panel:SetWidth(340)
    panel:SetHeight(44 + ROWS * ROW_HEIGHT + 140)
    panel:SetPoint("RIGHT", nil, "RIGHT", -24, 0)
    panel:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    panel:SetBackdropColor(0, 0, 0, 0.75)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", panel, "TOP", 0, -14)
    title:SetText("Your characters")

    rows = {}
    local at = -44
    for i = 1, ROWS do
        local row = MakeButton(300, 24, "", function(self)
            selected = self.character and self.character.name
            ShowRoster()
        end)
        row:SetPoint("TOP", panel, "TOP", 0, at)
        at = at - ROW_HEIGHT
        rows[i] = row
    end

    local previous = MakeButton(40, 22, "<", function()
        page = math.max(1, page - 1)
        ShowRoster()
    end)
    previous:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, at)
    local following = MakeButton(40, 22, ">", function()
        page = page + 1
        ShowRoster()
    end)
    following:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -20, at)
    pageText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pageText:SetPoint("TOP", panel, "TOP", 0, at - 5)
    at = at - 26

    chosen = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    chosen:SetPoint("TOP", panel, "TOP", 0, at)
    at = at - 18

    local play = MakeButton(300, 32, "Play", Play)
    play:SetPoint("TOP", panel, "TOP", 0, at)
    at = at - 36

    local camera = MakeButton(146, 24, "Camera: stop/turn", function()
        Orbit(not orbiting)
    end)
    camera:SetPoint("TOP", panel, "TOP", -77, at)
    local save = MakeButton(146, 24, "Save camera", function()
        SaveView(VIEW)
        HomeScreenDB.camera = true
    end)
    save:SetPoint("TOP", panel, "TOP", 77, at)
    at = at - 26

    local glue = MakeButton(146, 24, "Character select", function()
        LeaveFor("glue")
    end)
    glue:SetPoint("TOP", panel, "TOP", -77, at)
    local ui = MakeButton(146, 24, "Show UI", function()
        Orbit(false)
        panel:Hide()
        UIParent:Show()
    end)
    ui:SetPoint("TOP", panel, "TOP", 77, at)
end

local function EnterHome()
    inHome = true
    UIParent:Hide()
    if not panel then
        BuildPanel()
    end
    panel:Show()
    if HomeScreenDB.camera then
        SetView(VIEW)
    end
    Orbit(true)
end

local function OnAddonMessage(message)
    local kind, a, b, c, d, e = strsplit("\t", message)
    if kind == "begin" then
        answered = true
        incoming = {}
        if not inHome then
            EnterHome()
        end
    elseif kind == "row" and incoming then
        incoming[#incoming + 1] = { name = a, race = tonumber(b), class = tonumber(c), level = tonumber(d) or 0, zone = tonumber(e) }
    elseif kind == "end" and incoming then
        roster, incoming = incoming, nil
        selected = selected or (roster[1] and roster[1].name)
        ShowRoster()
    end
end

local frame = CreateFrame("Frame")
local arrived, retryIn = false, nil

local function Retry(self, elapsed)
    retryIn = retryIn - elapsed
    if retryIn > 0 then
        return
    end
    self:SetScript("OnUpdate", nil)
    if not answered then
        Command("list")
    end
end

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    if event == "CHAT_MSG_ADDON" then
        if prefix == ADDON_PREFIX and channel == "WHISPER" and sender == UnitName("player") then
            OnAddonMessage(message)
        end
    elseif not arrived then
        arrived = true
        if HomeScreenDB.clicked then
            DEFAULT_CHAT_FRAME:AddMessage(("|cffffd200Home screen:|r Play took %d s."):format(time() - HomeScreenDB.clicked))
            HomeScreenDB.clicked = nil
        end
        Command("list")
        retryIn = RETRY_SECONDS
        self:SetScript("OnUpdate", Retry)
    end
end)

SLASH_HOMESCREEN1 = "/homescreen"
-- On the viewer, between the window and the normal UI.
SlashCmdList["HOMESCREEN"] = function()
    if inHome and panel and not panel:IsShown() then
        EnterHome()
    elseif panel then
        Orbit(false)
        panel:Hide()
        UIParent:Show()
    end
end
