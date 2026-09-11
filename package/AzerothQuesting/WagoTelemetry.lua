local ADDON_NAME, ZQG = ...

local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local projectID = GetAddOnMetadata and GetAddOnMetadata(ADDON_NAME, "X-Wago-ID") or nil
local analytics
local analyticsRegistered = false
local sentThisSession = {}
local stateSentThisSession = {}
local discoverySwitchesThisSession = {}
local phaseSentCount = 0
local mapQuestSentCount = 0
local mapVisitSentCount = 0
local phaseVisitSentCount = 0
local instanceVisitSentCount = 0
local discoverySwitchSentCount = 0
local questDiscoverySwitchSentCount = 0
local MAX_DISCOVERY_SWITCHES_PER_SESSION = 200
local MAX_QUEST_DISCOVERY_SWITCHES_PER_SESSION = 150

-- These are the same evidence classes represented by the local learning export.
-- They intentionally remain distinct because they have different confidence:
-- available is a map/API hint, offered/active/turnedIn are much stronger proof,
-- and accepted can be carried across maps or timelines.
local REPORTABLE_EVIDENCE = {
    seen = true,
    available = true,
    offered = true,
    accepted = true,
    active = true,
    turnedIn = true,
}

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffAzeroth Questing:|r " .. tostring(msg))
end

local function CurrentMapID()
    if C_Map and C_Map.GetBestMapForUnit then
        return C_Map.GetBestMapForUnit("player")
    end
    return nil
end

local function PlayerFaction()
    if UnitFactionGroup then
        return (UnitFactionGroup("player") or "Neutral"):lower()
    end
    return "neutral"
end

local function IsOnTaxi()
    return UnitOnTaxi and UnitOnTaxi("player") and true or false
end

local function IsCompleted(questID)
    if not questID or not C_QuestLog or not C_QuestLog.IsQuestFlaggedCompleted then
        return false
    end

    local ok, completed = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
    return ok and completed and true or false
end

local function IsWagoAnalyticsLoaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded("WagoAnalytics") and true or false
    end

    if IsAddOnLoaded then
        return IsAddOnLoaded("WagoAnalytics") and true or false
    end

    return false
end

local function GetReportablePhase(mapID)
    if not mapID or not ZQG.GetTimePhaseKey then
        return nil, nil
    end

    local phase, source = ZQG.GetTimePhaseKey(mapID)
    if not phase then
        return nil, source
    end

    -- Manual overrides remain useful locally, but are not promoted into crowd
    -- telemetry because an accidental override should not become phase evidence.
    if source ~= "zidormi" and source ~= "detected" then
        return nil, source
    end

    return tostring(phase):lower(), source
end

local function RegisterAnalytics()
    if analyticsRegistered then
        return analytics
    end
    analyticsRegistered = true

    if not projectID or projectID == "" or not LibStub then
        return nil
    end

    local shim = LibStub("WagoAnalytics", true)
    if not shim or type(shim.Register) ~= "function" then
        return nil
    end

    local ok, registered = pcall(shim.Register, shim, projectID)
    if not ok or not registered then
        return nil
    end

    analytics = registered

    if IsWagoAnalyticsLoaded() and type(analytics.Switch) == "function" then
        pcall(analytics.Switch, analytics, "phase_learning_enabled", true)
        pcall(analytics.Switch, analytics, "map_quest_learning_enabled", true)
        pcall(analytics.Switch, analytics, "map_visit_learning_enabled", true)
        pcall(analytics.Switch, analytics, "phase_visit_learning_enabled", true)
        pcall(analytics.Switch, analytics, "instance_visit_learning_enabled", true)
        pcall(analytics.Switch, analytics, "discovery_switch_mirroring_enabled", true)
        pcall(analytics.Switch, analytics, "full_research_telemetry_enabled", true)
    end

    return analytics
end

-- Wago recommends registering when the addon loads. OptionalDependencies makes
-- the real WagoAnalytics addon available first when it is installed.
RegisterAnalytics()

local function SafeToken(value)
    value = tostring(value or "unknown"):lower()
    value = value:gsub("[^%w]+", "_")
    value = value:gsub("^_+", "")
    value = value:gsub("_+$", "")
    if value == "" then
        return "unknown"
    end
    return value
end

local function NumericToken(value)
    local number = tonumber(value)
    if not number then
        return "0"
    end
    return tostring(math.floor(number))
end

local function ValidMetricName(name)
    return type(name) == "string" and name ~= "" and #name <= 128
end

local function PhaseMetricName(mapID, faction, phase, questID, evidence, source)
    return table.concat({
        "phase",
        "m" .. SafeToken(mapID),
        SafeToken(faction),
        SafeToken(phase),
        "q" .. SafeToken(questID),
        SafeToken(evidence),
        "src",
        SafeToken(source),
    }, "_")
end

local function PhaseCompletionMetricName(mapID, faction, phase, questID, source)
    return table.concat({
        "phasecompleted",
        "m" .. SafeToken(mapID),
        SafeToken(faction),
        SafeToken(phase),
        "q" .. SafeToken(questID),
        "src",
        SafeToken(source),
    }, "_")
end

local function MapQuestMetricName(mapID, faction, questID, evidence)
    return table.concat({
        "mapquest",
        "m" .. SafeToken(mapID),
        SafeToken(faction),
        "q" .. SafeToken(questID),
        SafeToken(evidence),
    }, "_")
end

local function MapQuestCompletionMetricName(mapID, faction, questID)
    return table.concat({
        "mapquestcompleted",
        "m" .. SafeToken(mapID),
        SafeToken(faction),
        "q" .. SafeToken(questID),
    }, "_")
end

local function MapVisitMetricName(mapID, faction)
    return table.concat({
        "mapvisit",
        "m" .. SafeToken(mapID),
        SafeToken(faction),
    }, "_")
end

local function PhaseVisitMetricName(mapID, faction, phase, source)
    return table.concat({
        "phasevisit",
        "m" .. SafeToken(mapID),
        SafeToken(faction),
        SafeToken(phase),
        "src",
        SafeToken(source),
    }, "_")
end

-- This mirrors the non-name fields from ZQGINSTANCEDATA|1. Localized map,
-- instance, difficulty, and scenario names stay local; their stable IDs/context
-- are what the crowd dataset needs and avoid localization/cardinality noise.
local function InstanceVisitMetricName(info, faction)
    return table.concat({
        "instancevisit",
        "m" .. NumericToken(info.mapID),
        "p" .. NumericToken(info.parentMapID),
        "i" .. NumericToken(info.instanceID),
        "d" .. NumericToken(info.difficultyID),
        "lfg" .. NumericToken(info.lfgDungeonID),
        "max" .. NumericToken(info.maxPlayers),
        "grp" .. NumericToken(info.instanceGroupSize),
        "st" .. NumericToken(info.scenarioType),
        "sa" .. NumericToken(info.scenarioArea),
        "sk" .. NumericToken(info.scenarioTextureKit),
        SafeToken(info.instanceType or "unknown"),
        "ph" .. SafeToken(info.phase or "unknown"),
        "src" .. SafeToken(info.phaseSource or "unknown"),
        SafeToken(faction),
    }, "_")
end

local function MapDiscoverySwitchName(mapID, faction)
    return table.concat({
        "seen", "map", "m" .. SafeToken(mapID), SafeToken(faction),
    }, "_")
end

local function PhaseDiscoverySwitchName(mapID, faction, phase, source)
    return table.concat({
        "seen", "phase", "m" .. SafeToken(mapID), SafeToken(faction),
        SafeToken(phase), "src", SafeToken(source),
    }, "_")
end

local function PhaseQuestDiscoverySwitchName(mapID, faction, phase, questID, evidence, source)
    return table.concat({
        "seen", "quest", "m" .. SafeToken(mapID), SafeToken(faction),
        SafeToken(phase), "q" .. SafeToken(questID), SafeToken(evidence),
        "src", SafeToken(source),
    }, "_")
end

local function MapQuestDiscoverySwitchName(mapID, faction, questID, evidence)
    return table.concat({
        "seen", "mapquest", "m" .. SafeToken(mapID), SafeToken(faction),
        "q" .. SafeToken(questID), SafeToken(evidence),
    }, "_")
end

local function InstanceDiscoverySwitchName(info, faction)
    return table.concat({
        "seen", "instance",
        "m" .. NumericToken(info.mapID),
        "p" .. NumericToken(info.parentMapID),
        "i" .. NumericToken(info.instanceID),
        "d" .. NumericToken(info.difficultyID),
        "lfg" .. NumericToken(info.lfgDungeonID),
        "max" .. NumericToken(info.maxPlayers),
        "grp" .. NumericToken(info.instanceGroupSize),
        "st" .. NumericToken(info.scenarioType),
        "sa" .. NumericToken(info.scenarioArea),
        "sk" .. NumericToken(info.scenarioTextureKit),
        SafeToken(info.instanceType or "unknown"),
        "ph" .. SafeToken(info.phase or "unknown"),
        "src" .. SafeToken(info.phaseSource or "unknown"),
        SafeToken(faction),
    }, "_")
end

local function ReportDiscoverySwitch(name, isQuestEvidence)
    if not ValidMetricName(name) then
        return false
    end

    if discoverySwitchesThisSession[name] then
        return true
    end

    if discoverySwitchSentCount >= MAX_DISCOVERY_SWITCHES_PER_SESSION then
        return false
    end

    -- Keep some switch headroom for map/phase/instance fingerprints even during
    -- long questing sessions. All quest evidence is still sent as counters.
    if isQuestEvidence and questDiscoverySwitchSentCount >= MAX_QUEST_DISCOVERY_SWITCHES_PER_SESSION then
        return false
    end

    if not IsWagoAnalyticsLoaded() then
        return false
    end

    local api = RegisterAnalytics()
    if not api or type(api.Switch) ~= "function" then
        return false
    end

    local ok = pcall(api.Switch, api, name, true)
    if not ok then
        return false
    end

    discoverySwitchesThisSession[name] = true
    discoverySwitchSentCount = discoverySwitchSentCount + 1
    if isQuestEvidence then
        questDiscoverySwitchSentCount = questDiscoverySwitchSentCount + 1
    end
    return true
end

local function SetCompletionCounter(metric, completed)
    if not ValidMetricName(metric) or not IsWagoAnalyticsLoaded() then
        return false
    end

    local value = completed and 1 or 0
    local key = "state:" .. metric
    if stateSentThisSession[key] == value then
        return true
    end

    local api = RegisterAnalytics()
    if not api or type(api.SetCounter) ~= "function" then
        return false
    end

    local ok = pcall(api.SetCounter, api, metric, value)
    if not ok then
        return false
    end

    stateSentThisSession[key] = value
    return true
end

local function ReportPhaseEvidenceSingle(questID, evidence, mapID)
    if type(questID) ~= "number" or questID <= 0 or not REPORTABLE_EVIDENCE[evidence] then
        return false
    end

    if IsOnTaxi() or not IsWagoAnalyticsLoaded() then
        return false
    end

    mapID = mapID or CurrentMapID()
    local phase, source = GetReportablePhase(mapID)
    if not mapID or not phase then
        return false
    end

    local faction = PlayerFaction()
    local key = table.concat({
        "phase", tostring(mapID), faction, phase, tostring(questID), evidence, tostring(source),
    }, ":")

    if sentThisSession[key] then
        SetCompletionCounter(
            PhaseCompletionMetricName(mapID, faction, phase, questID, source),
            IsCompleted(questID)
        )
        return true
    end

    local api = RegisterAnalytics()
    if not api or type(api.IncrementCounter) ~= "function" then
        return false
    end

    local metric = PhaseMetricName(mapID, faction, phase, questID, evidence, source)
    if not ValidMetricName(metric) then
        return false
    end

    local ok = pcall(api.IncrementCounter, api, metric, 1)
    if not ok then
        return false
    end

    sentThisSession[key] = true
    phaseSentCount = phaseSentCount + 1
    pcall(api.IncrementCounter, api, "phase_evidence_total", 1)
    SetCompletionCounter(
        PhaseCompletionMetricName(mapID, faction, phase, questID, source),
        IsCompleted(questID)
    )
    ReportDiscoverySwitch(
        PhaseQuestDiscoverySwitchName(mapID, faction, phase, questID, evidence, source),
        true
    )
    return true
end

local function ReportEvidence(questID, evidence, mapID)
    evidence = evidence or "seen"
    if not REPORTABLE_EVIDENCE[evidence] then
        return false
    end

    local seenOK = true
    if evidence ~= "seen" then
        seenOK = ReportPhaseEvidenceSingle(questID, "seen", mapID)
    end
    local evidenceOK = ReportPhaseEvidenceSingle(questID, evidence, mapID)
    return evidenceOK or seenOK
end

local function ReportMapQuestEvidenceSingle(questID, evidence, mapID)
    if type(questID) ~= "number" or questID <= 0 or not REPORTABLE_EVIDENCE[evidence] then
        return false
    end

    if IsOnTaxi() or not IsWagoAnalyticsLoaded() then
        return false
    end

    mapID = mapID or CurrentMapID()
    if type(mapID) ~= "number" or mapID <= 0 then
        return false
    end

    local faction = PlayerFaction()
    local key = table.concat({
        "mapquest", tostring(mapID), faction, tostring(questID), evidence,
    }, ":")

    if sentThisSession[key] then
        SetCompletionCounter(
            MapQuestCompletionMetricName(mapID, faction, questID),
            IsCompleted(questID)
        )
        return true
    end

    local api = RegisterAnalytics()
    if not api or type(api.IncrementCounter) ~= "function" then
        return false
    end

    local metric = MapQuestMetricName(mapID, faction, questID, evidence)
    if not ValidMetricName(metric) then
        return false
    end

    local ok = pcall(api.IncrementCounter, api, metric, 1)
    if not ok then
        return false
    end

    sentThisSession[key] = true
    mapQuestSentCount = mapQuestSentCount + 1
    pcall(api.IncrementCounter, api, "map_quest_evidence_total", 1)
    SetCompletionCounter(
        MapQuestCompletionMetricName(mapID, faction, questID),
        IsCompleted(questID)
    )
    ReportDiscoverySwitch(MapQuestDiscoverySwitchName(mapID, faction, questID, evidence), true)
    return true
end

local function ReportMapQuestEvidence(questID, evidence, mapID)
    evidence = evidence or "seen"
    if not REPORTABLE_EVIDENCE[evidence] then
        return false
    end

    local seenOK = true
    if evidence ~= "seen" then
        seenOK = ReportMapQuestEvidenceSingle(questID, "seen", mapID)
    end
    local evidenceOK = ReportMapQuestEvidenceSingle(questID, evidence, mapID)
    return evidenceOK or seenOK
end

local function ReportMapVisit(mapID)
    if IsOnTaxi() or not IsWagoAnalyticsLoaded() then
        return false
    end

    mapID = mapID or CurrentMapID()
    if type(mapID) ~= "number" or mapID <= 0 then
        return false
    end

    local faction = PlayerFaction()
    local key = table.concat({ "mapvisit", tostring(mapID), faction }, ":")
    if sentThisSession[key] then
        return true
    end

    local api = RegisterAnalytics()
    if not api or type(api.IncrementCounter) ~= "function" then
        return false
    end

    local metric = MapVisitMetricName(mapID, faction)
    local ok = ValidMetricName(metric) and pcall(api.IncrementCounter, api, metric, 1)
    if not ok then
        return false
    end

    sentThisSession[key] = true
    mapVisitSentCount = mapVisitSentCount + 1
    pcall(api.IncrementCounter, api, "map_visit_total", 1)
    ReportDiscoverySwitch(MapDiscoverySwitchName(mapID, faction), false)
    return true
end

local function ReportPhaseVisit(mapID)
    if IsOnTaxi() or not IsWagoAnalyticsLoaded() then
        return false
    end

    mapID = mapID or CurrentMapID()
    if type(mapID) ~= "number" or mapID <= 0 then
        return false
    end

    local phase, source = GetReportablePhase(mapID)
    if not phase then
        return false
    end

    local faction = PlayerFaction()
    local key = table.concat({ "phasevisit", tostring(mapID), faction, phase, tostring(source) }, ":")
    if sentThisSession[key] then
        return true
    end

    local api = RegisterAnalytics()
    if not api or type(api.IncrementCounter) ~= "function" then
        return false
    end

    local metric = PhaseVisitMetricName(mapID, faction, phase, source)
    local ok = ValidMetricName(metric) and pcall(api.IncrementCounter, api, metric, 1)
    if not ok then
        return false
    end

    sentThisSession[key] = true
    phaseVisitSentCount = phaseVisitSentCount + 1
    pcall(api.IncrementCounter, api, "phase_visit_total", 1)
    ReportDiscoverySwitch(PhaseDiscoverySwitchName(mapID, faction, phase, source), false)
    return true
end

local function ReportInstanceFingerprint(info)
    if type(info) ~= "table" or not info.inInstance or not IsWagoAnalyticsLoaded() then
        return false
    end

    if type(info.mapID) ~= "number" or info.mapID <= 0 then
        return false
    end

    local faction = tostring(info.faction or PlayerFaction()):lower()
    local metric = InstanceVisitMetricName(info, faction)
    if not ValidMetricName(metric) then
        return false
    end

    local key = "instance:" .. metric
    if sentThisSession[key] then
        return true
    end

    local api = RegisterAnalytics()
    if not api or type(api.IncrementCounter) ~= "function" then
        return false
    end

    local ok = pcall(api.IncrementCounter, api, metric, 1)
    if not ok then
        return false
    end

    sentThisSession[key] = true
    instanceVisitSentCount = instanceVisitSentCount + 1
    pcall(api.IncrementCounter, api, "instance_visit_total", 1)
    ReportDiscoverySwitch(InstanceDiscoverySwitchName(info, faction), false)
    return true
end

local function ScanVisitEvidence()
    local mapID = CurrentMapID()
    if not mapID or IsOnTaxi() then
        return
    end

    ReportMapVisit(mapID)
    ReportPhaseVisit(mapID)
end

local function ScanAcceptedQuestEvidence()
    local mapID = CurrentMapID()
    if IsOnTaxi() or not mapID or not C_QuestLog or not C_QuestLog.GetQuestsOnMap then
        return
    end

    local ok, quests = pcall(C_QuestLog.GetQuestsOnMap, mapID)
    if not ok or type(quests) ~= "table" then
        return
    end

    for _, info in ipairs(quests) do
        if info and info.questID then
            ReportMapQuestEvidence(info.questID, "accepted", mapID)
            ReportEvidence(info.questID, "accepted", mapID)
        end
    end
end

local function ScanAvailableQuestLines()
    local mapID = CurrentMapID()
    if IsOnTaxi() or not mapID or not C_QuestLine or not C_QuestLine.GetAvailableQuestLines then
        return
    end

    local ok, lines = pcall(C_QuestLine.GetAvailableQuestLines, mapID)
    if not ok or type(lines) ~= "table" then
        return
    end

    for _, info in ipairs(lines) do
        if info and info.questID then
            -- Keep this evidence because it is useful, but preserve the evidence
            -- label so downstream analysis can treat it as a map/API hint rather
            -- than proof that an NPC currently offers the quest in this phase.
            ReportMapQuestEvidence(info.questID, "available", mapID)
            ReportEvidence(info.questID, "available", mapID)
        end
    end
end

local function ScanGossipEvidence()
    local mapID = CurrentMapID()
    if not mapID or not C_GossipInfo then
        return
    end

    if C_GossipInfo.GetAvailableQuests then
        local ok, quests = pcall(C_GossipInfo.GetAvailableQuests)
        if ok and type(quests) == "table" then
            for _, info in ipairs(quests) do
                if info and info.questID then
                    ReportMapQuestEvidence(info.questID, "offered", mapID)
                    ReportEvidence(info.questID, "offered", mapID)
                end
            end
        end
    end

    if C_GossipInfo.GetActiveQuests then
        local ok, quests = pcall(C_GossipInfo.GetActiveQuests)
        if ok and type(quests) == "table" then
            for _, info in ipairs(quests) do
                if info and info.questID then
                    ReportMapQuestEvidence(info.questID, "active", mapID)
                    ReportEvidence(info.questID, "active", mapID)
                end
            end
        end
    end
end

local function CaptureQuestDetail()
    if not GetQuestID then
        return
    end

    local questID = GetQuestID()
    if questID and questID > 0 then
        ReportMapQuestEvidence(questID, "offered")
        ReportEvidence(questID, "offered")
    end
end

local scanScheduled = false
local function ScheduleQuestScan(delay)
    if scanScheduled then
        return
    end

    scanScheduled = true
    C_Timer.After(delay or 0.3, function()
        scanScheduled = false
        ScanAcceptedQuestEvidence()
        ScanAvailableQuestLines()
    end)
end

local visitScanScheduled = false
local function ScheduleVisitScan(delay)
    if visitScanScheduled then
        return
    end

    visitScanScheduled = true
    C_Timer.After(delay or 0.3, function()
        visitScanScheduled = false
        ScanVisitEvidence()
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("ZONE_CHANGED")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUESTLINE_UPDATE")
events:RegisterEvent("QUEST_ACCEPTED")
events:RegisterEvent("QUEST_TURNED_IN")
events:RegisterEvent("QUEST_DETAIL")
events:RegisterEvent("GOSSIP_SHOW")
pcall(events.RegisterEvent, events, "UNIT_PHASE")

events:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "QUEST_ACCEPTED" then
        local questID = arg2
        if type(questID) ~= "number" or questID <= 0 then
            if type(arg1) == "number" and C_QuestLog and C_QuestLog.GetInfo then
                local info = C_QuestLog.GetInfo(arg1)
                questID = info and info.questID or nil
            end
        end
        if type(questID) == "number" and questID > 0 then
            ReportMapQuestEvidence(questID, "accepted")
            ReportEvidence(questID, "accepted")
        end
        ScheduleQuestScan(0.2)
        return
    end

    if event == "QUEST_TURNED_IN" then
        if type(arg1) == "number" and arg1 > 0 then
            ReportMapQuestEvidence(arg1, "turnedIn")
            ReportEvidence(arg1, "turnedIn")
        end
        ScheduleQuestScan(0.3)
        return
    end

    if event == "QUEST_DETAIL" then
        C_Timer.After(0.05, CaptureQuestDetail)
        return
    end

    if event == "GOSSIP_SHOW" then
        C_Timer.After(0.15, function()
            -- Timeline handlers load before this module. Give their Zidormi
            -- classification a moment to settle before capturing phase evidence.
            ScanVisitEvidence()
            ScanGossipEvidence()
            ScanAcceptedQuestEvidence()
            ScanAvailableQuestLines()
        end)
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.0, function()
            ScanVisitEvidence()
            ScanAcceptedQuestEvidence()
            ScanAvailableQuestLines()
        end)
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "UNIT_PHASE" then
        ScheduleVisitScan(0.6)
        ScheduleQuestScan(0.6)
    elseif event == "ZONE_CHANGED" then
        ScheduleVisitScan(0.3)
        ScheduleQuestScan(0.3)
    else
        ScheduleQuestScan(0.3)
    end
end)

local function WagoStatus()
    if not projectID or projectID == "" then
        Print("Wago telemetry is not configured: AzerothQuesting.toc has no X-Wago-ID.")
        return
    end

    if not analytics then
        Print("Wago telemetry could not register through the bundled WagoAnalytics shim.")
        return
    end

    if IsWagoAnalyticsLoaded() then
        Print(string.format(
            "Wago telemetry is registered for project %s. This session queued %d phase-quest, %d map/quest, %d map-visit, %d phase-visit, %d instance-visit observations, and %d dashboard discovery switches; upload still depends on the player's Wago App Analytics sharing setting.",
            tostring(projectID),
            phaseSentCount,
            mapQuestSentCount,
            mapVisitSentCount,
            phaseVisitSentCount,
            instanceVisitSentCount,
            discoverySwitchSentCount
        ))
    else
        Print("Wago project " .. tostring(projectID) .. " is configured and the shim is ready, but the WagoAnalytics addon is not loaded on this client.")
    end
end

local originalSlashHandler = SlashCmdList.ZONEQUESTGUIDE
SlashCmdList.ZONEQUESTGUIDE = function(msg)
    local command = (msg or ""):lower():match("^%s*(.-)%s*$")

    if command == "wago" or command == "telemetry" then
        WagoStatus()
        return
    end

    if originalSlashHandler then
        originalSlashHandler(msg)
    end
end

ZQG.ReportPhaseEvidenceToWago = ReportEvidence
ZQG.ReportMapQuestEvidenceToWago = ReportMapQuestEvidence
ZQG.ReportMapVisitToWago = ReportMapVisit
ZQG.ReportPhaseVisitToWago = ReportPhaseVisit
ZQG.ReportInstanceFingerprintToWago = ReportInstanceFingerprint
ZQG.GetWagoTelemetryStatus = function()
    return {
        projectID = projectID,
        registered = analytics ~= nil,
        providerLoaded = IsWagoAnalyticsLoaded(),
        phaseSent = phaseSentCount,
        mapQuestSent = mapQuestSentCount,
        mapVisitSent = mapVisitSentCount,
        phaseVisitSent = phaseVisitSentCount,
        instanceVisitSent = instanceVisitSentCount,
        discoverySwitchSent = discoverySwitchSentCount,
    }
end
