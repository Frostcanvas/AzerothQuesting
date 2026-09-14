local ADDON_NAME, ZQG = ...

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffAzeroth Questing:|r " .. tostring(message))
end

local KNOWN_PRODUCTS = {
    { constant = "WOW_PROJECT_MAINLINE", label = "Retail" },
    { constant = "WOW_PROJECT_CLASSIC", label = "Classic Era" },
    { constant = "WOW_PROJECT_WOWLABS", label = "WoW Labs" },
    { constant = "WOW_PROJECT_BURNING_CRUSADE_CLASSIC", label = "Burning Crusade Classic" },
    { constant = "WOW_PROJECT_WRATH_CLASSIC", label = "Wrath Classic" },
    { constant = "WOW_PROJECT_CATACLYSM_CLASSIC", label = "Cataclysm Classic" },
    { constant = "WOW_PROJECT_MISTS_CLASSIC", label = "Mists of Pandaria Classic" },
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

local function GetProductContext()
    local projectID = SafeNumber(WOW_PROJECT_ID) or 0
    local label

    for _, product in ipairs(KNOWN_PRODUCTS) do
        local constantValue = SafeNumber(_G[product.constant])
        if constantValue and constantValue == projectID then
            label = product.label
            break
        end
    end

    if not label then
        if projectID > 0 then
            label = "Unknown Product " .. tostring(projectID)
        else
            label = "Unknown WoW Product"
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
        label = label,
        projectID = projectID,
        gameVersion = gameVersion,
        buildNumber = buildNumber,
        interfaceVersion = interfaceVersion or 0,
    }
end

local function ProductPrefix(context)
    return string.format("wp%d-", tonumber(context.projectID) or 0)
end

local function TaggedKey(key, context)
    key = tostring(key or "")

    -- Beta 29 used a readable gc-<name>-p<ID>- prefix. Preserve any queued or
    -- already-uploaded Beta 29 key exactly so it keeps its deduplication identity.
    if key:match("^gc%-[a-z0-9%-]+%-p%d+%-") then
        return key
    end

    -- Beta 30 and later use WOW_PROJECT_ID itself as the durable partition key.
    if key:match("^wp%d+%-") then
        return key
    end

    return ProductPrefix(context) .. key
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
    observation.wowProjectID = context.projectID
    observation.gameClient = context.label
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

    local context = GetProductContext()
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
        local context = GetProductContext()
        Print(string.format(
            "WoW product: %s | WOW_PROJECT_ID=%d | version=%s | build=%s | interface=%d",
            context.label,
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

ZQG.GetGameClientContext = GetProductContext
ZQG.GetWoWProductContext = GetProductContext
ZQG.TagQueuedResearchByGameClient = TagQueuedResearch
ZQG.TagQueuedResearchByProduct = TagQueuedResearch

TagQueuedResearch()
