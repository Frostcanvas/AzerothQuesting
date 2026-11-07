local ADDON_NAME, ZQG = ...

-- Classic collection entry point. The Classic manifests load the shared
-- research and character handoff modules without Retail guide dependencies.
ZoneQuestGuideDB = ZoneQuestGuideDB or {}
SLASH_ZONEQUESTGUIDE1 = "/aq"
SLASH_ZONEQUESTGUIDE2 = "/zqg"

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffAzeroth Questing:|r " .. message)
end

local function CurrentMap()
    return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
end

local function Queue(questID, evidence, title, completed)
    local mapID = CurrentMap()
    if questID and mapID and ZQG.QueueCompanionQuestObservation then
        ZQG.QueueCompanionQuestObservation(questID, evidence, mapID, {
            questName = title,
            completed = completed,
        })
    end
end

local function ScanQuestLog()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        for index = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(index)
            if info and not info.isHeader then
                Queue(info.questID, "active", info.title)
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        for index = 1, GetNumQuestLogEntries() do
            local title, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(index)
            if not isHeader then
                Queue(questID, "active", title)
            end
        end
    end
end

local pendingScan = false
local function ScheduleScan()
    if pendingScan then
        return
    end
    pendingScan = true
    C_Timer.After(0.5, function()
        pendingScan = false
        ScanQuestLog()
        if ZQG.TagQueuedResearchByProduct then
            ZQG.TagQueuedResearchByProduct()
        end
    end)
end

SlashCmdList.ZONEQUESTGUIDE = function()
    Print("Classic quest collection is active. Use /aq client, /aq sync, /aq map, or /aq completed client. Use /reload to save for the Companion.")
end

local events = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE",
    "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_DETAIL", "GOSSIP_SHOW",
    "ZONE_CHANGED_NEW_AREA", "QUEST_QUERY_COMPLETE", "PLAYER_LOGOUT",
}) do
    pcall(events.RegisterEvent, events, event)
end

events:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "PLAYER_LOGIN" and QueryQuestsCompleted then
        pcall(QueryQuestsCompleted)
    elseif event == "QUEST_ACCEPTED" then
        Queue(arg2 or arg1, "accepted")
    elseif event == "QUEST_TURNED_IN" then
        Queue(arg1, "turnedIn", nil, true)
    elseif event == "QUEST_DETAIL" and GetQuestID then
        Queue(GetQuestID(), "offered", GetTitleText and GetTitleText())
    elseif event == "GOSSIP_SHOW" and C_GossipInfo and C_GossipInfo.GetAvailableQuests then
        for _, quest in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
            Queue(quest.questID, "available", quest.title)
        end
    elseif event == "QUEST_QUERY_COMPLETE" and ZQG.CaptureCompletedQuestSnapshot then
        ZQG.CaptureCompletedQuestSnapshot()
    elseif event == "PLAYER_LOGOUT" then
        ScanQuestLog()
        return
    end
    ScheduleScan()
end)
