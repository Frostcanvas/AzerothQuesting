local ADDON_NAME, ZQG = ...

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffAzeroth Questing:|r " .. tostring(message))
end

local KNOWN_CLIENTS = {
    { constant = "WOW_PROJECT_MAINLINE", key = "retail", label = "Retail" },
    { constant = "WOW_PROJECT_CLASSIC", key = "classic-era", label = "Classic Era" },
    { constant = "WOW_PROJECT_BURNING_CRUSADE_CLASSIC", key = "burning-crusade-classic", label = "Burning Crusade Classic" },
    { constant = "WOW_PROJECT_WRATH_CLASSIC", key = "wrath-classic", label = "Wrath Classic" },
    { constant = "WOW_PROJECT_CATACLYSM_CLASSIC", key = "cataclysm-classic", label = "Cataclysm Classic" },
    { constant = "WOW_PROJECT_MISTS_CLASSIC", key = "mists-classic", label = "Mists Classic" },
}

local function SafeNumber(value)
    if canaccessvalue then
        local ok, allowed = pcall(canaccessvalue, value)
        if ok and not allowed then
            return nil
        end
    end
    return type(value) == "number" and value or nil
end

local function SafeString(value)
    if canaccessvalue then
        local ok, allowed = pcall(canaccessvalue, value)
        if ok and not allowed then
            return nil
        end
    end
    return type(value) == "string" and value or nil
end

local function GetClientContext()
    local projectID = SafeNumber(WOW_PROJECT_ID) or 0
    local key
    local label

    for _, client in ipairs(KNOWN_CLIENTS) do
        local constantValue = SafeNumber(_G[client.constant])
        if constantValue and constantValue == projectID then
            key = client.key
            label = client.label
            break
        end
    end

    if not key then
        if projectID > 0 then
            key = "project-" .. tostring(projectID)
            label = "Project " .. tostring(projectID)
        else
            key = "unknown"
            label = "Unknown WoW Client"
        end
    end

    local gameVersion
    local buildNumber
    local interfaceVersion
    if GetBuildInfo then
        local ok, version, build, _, toc = pcall(GetBuildInfo)
        if ok then
            gameVersion = SafeString(version)
            buildNumber = SafeString(build)
            interfaceVersion = SafeNumber(toc)
        end
    end

    return {
        key = key,
        label = label,
        projectID = projectID,
        gameVersion = gameVersion,
        buildNumber = buildNumber,
        interfaceVersion = interfaceVersion or 0,
    }
end

local function PrefixFor(context)
    return string.format("gc-%s-p%d-", tostring(context.key), tonumber(context.projectID) or 0)
end

local function TaggedKey(key, context)
    key = tostring(key or "")
    if key:match("^gc%-[a-z0-9%-]+%-p%d+%-") then
        return key
    end
    return PrefixFor(context) .. key
end

local function ReplaceWireKey(wire, key)
    if type(wire) ~= "string" or wire == "" then
        return wire
    end
    local recordType, _, remainder = wire:match("^([^|]+)|([^|]+)|(.*)$")
    if not recordType or not remainder then
        return wire
    end
    return recordType .. "|" .. key .. "|" .. remainder
end

local function TagObservation(observation, context)
    if type(observation) ~= "table" or not observation.key then
        return false
    end

    local newKey = TaggedKey(observation.key, context)
    observation.gameClient = context.key
    observation.wowProjectID = context.projectID
    observation.interfaceVersion = context.interfaceVersion
    observation.gameVersion = context.gameVersion
    observation.buildNumber = context.buildNumber

    if newKey == observation.key then
        return false
    end

    observation.key = newKey
    observation.wire = ReplaceWireKey(observation.wire, newKey)
    observation.wire2 = ReplaceWireKey(observation.wire2, newKey)
    observation.wire3 = ReplaceWireKey(observation.wire3, newKey)
    return true
end

local function TagQueuedResearch()
    if not ZoneQuestGuideDB or not ZoneQuestGuideDB.companionSync then
        return 0
    end

    local observations = ZoneQuestGuideDB.companionSync.observations
    if type(observations) ~= "table" then
        return 0
    end

    local context = GetClientContext()
    local changed = 0
    for _, observation in ipairs(observations) do
        if TagObservation(observation, context) then
            changed = changed + 1
        end
    end
    return changed
end

local pendingTag = false
local function ScheduleTag()
    if pendingTag then
        return
    end
    pendingTag = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            pendingTag = false
            TagQueuedResearch()
        end)
    else
        pendingTag = false
        TagQueuedResearch()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_ACCEPTED")
events:RegisterEvent("QUEST_TURNED_IN")
events:RegisterEvent("GOSSIP_SHOW")
events:RegisterEvent("ZONE_CHANGED")
events:RegisterEvent("ZONE_CHANGED_INDOORS")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGOUT" then
        TagQueuedResearch()
    else
        ScheduleTag()
    end
end)

if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(2, TagQueuedResearch)
end

local previousSlashHandler = SlashCmdList.ZONEQUESTGUIDE
SlashCmdList.ZONEQUESTGUIDE = function(msg)
    local command = (msg or ""):lower():match("^%s*(.-)%s*$")
    if command == "client" or command == "product" or command == "project" then
        local context = GetClientContext()
        Print(string.format(
            "WoW client: %s | key=%s | WOW_PROJECT_ID=%d | version=%s | build=%s | interface=%d",
            context.label,
            context.key,
            context.projectID,
            tostring(context.gameVersion or "unknown"),
            tostring(context.buildNumber or "unknown"),
            context.interfaceVersion or 0
        ))
        return
    end

    if previousSlashHandler then
        previousSlashHandler(msg)
    end
end

ZQG.GetGameClientContext = GetClientContext
ZQG.TagQueuedResearchByGameClient = TagQueuedResearch

TagQueuedResearch()
