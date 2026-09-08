local ADDON_NAME, ZQG = ...

local mainFrame = _G.ZoneQuestGuideFrame
if not mainFrame then
    return
end

local function CurrentMapID()
    if C_Map and C_Map.GetBestMapForUnit then
        return C_Map.GetBestMapForUnit("player")
    end
    return nil
end

local function GetRequiredPhase(quest)
    if not quest then
        return nil
    end

    if quest.requiredPhase then
        return tostring(quest.requiredPhase):lower()
    end

    if quest.phase then
        return tostring(quest.phase):lower()
    end

    local phase = quest.id and ZQG.QuestPhaseRequirements
        and ZQG.QuestPhaseRequirements[quest.id] or nil
    return phase and tostring(phase):lower() or nil
end

local function GetPhaseSwitcher(mapID)
    if not mapID or not ZQG.PhaseSwitchers then
        return nil
    end

    return ZQG.PhaseSwitchers[mapID]
end

local function GetPhaseMismatch(quest, mapID)
    local requiredPhase = GetRequiredPhase(quest)
    if not requiredPhase or not ZQG.GetTimePhaseKey then
        return nil
    end

    local activePhase = ZQG.GetTimePhaseKey(mapID)
    if not activePhase or activePhase == requiredPhase then
        return nil
    end

    local switcher = GetPhaseSwitcher(mapID)
    if not switcher or not switcher.x or not switcher.y then
        return nil
    end

    return {
        activePhase = activePhase,
        requiredPhase = requiredPhase,
        switcher = switcher,
    }
end

local function BuildPhaseTarget(quest, mapID, mismatch)
    local required = mismatch.requiredPhase
    local switcher = mismatch.switcher
    local originalName = quest and quest.name or "selected quest"

    return {
        id = "phase:" .. tostring(quest and quest.id or originalName),
        name = string.format("%s - switch to %s", switcher.name or "Timeline switch", required:upper()),
        x = switcher.x,
        y = switcher.y,
        accepted = false,
        phaseGuidance = true,
        requiredPhase = required,
        originalQuestID = quest and quest.id or nil,
        originalQuestName = originalName,
        source = "phase-guidance",
        mapID = mapID,
    }
end

-- Give the synthetic navigation target a clear HUD status instead of showing it
-- as a normal AVAILABLE quest. This wrapper is intentionally narrow so real
-- quest rows continue using QuestStatus.lua unchanged.
local originalGetQuestStatusText = ZQG.GetQuestStatusText
ZQG.GetQuestStatusText = function(quest)
    if quest and quest.phaseGuidance then
        return "|cffffcc00SWITCH TIMELINE|r"
    end

    if originalGetQuestStatusText then
        return originalGetQuestStatusText(quest)
    end

    return quest and quest.accepted
        and "|cff66ff66IN PROGRESS|r"
        or "|cffffff66AVAILABLE|r"
end

-- NavigationHUD.lua is loaded before this file. Wrap its exported waypoint
-- function so a phase mismatch automatically reuses the same large rotating
-- arrow and waypoint machinery, but points at Zidormi instead of an objective
-- that is unavailable in the character's current historical version.
local originalSetWaypointForQuest = ZQG.SetWaypointForQuest
if originalSetWaypointForQuest then
    ZQG.SetWaypointForQuest = function(quest, ...)
        local mapID = CurrentMapID()
        local mismatch = GetPhaseMismatch(quest, mapID)

        if mismatch then
            return originalSetWaypointForQuest(
                BuildPhaseTarget(quest, mapID, mismatch),
                ...
            )
        end

        return originalSetWaypointForQuest(quest, ...)
    end
end

-- Core.lua's quest-row click handler uses a private waypoint function, so it can
-- briefly point at the quest before exported modules run. Re-apply the phase
-- guidance after the click when the selected quest is known to belong to the
-- opposite timeline.
local function HookQuestRows()
    for _, child in ipairs({ mainFrame:GetChildren() }) do
        if child.GetObjectType and child:GetObjectType() == "Button"
            and child.text and child.text.SetText
            and not child.ZQGPhaseGuidanceHooked then
            local width, height = child:GetSize()
            if math.abs((width or 0) - 330) < 1 and math.abs((height or 0) - 25) < 1 then
                child.ZQGPhaseGuidanceHooked = true
                child:HookScript("OnClick", function(self)
                    if not self.quest then
                        return
                    end

                    local mapID = CurrentMapID()
                    if not GetPhaseMismatch(self.quest, mapID) then
                        return
                    end

                    C_Timer.After(0, function()
                        if ZQG.SetWaypointForQuest then
                            ZQG.SetWaypointForQuest(self.quest)
                        end
                    end)
                end)
            end
        end
    end
end

HookQuestRows()
mainFrame:HookScript("OnShow", HookQuestRows)

-- Allow other modules and future zone-data packs to ask whether a quest needs a
-- timeline switch without duplicating the phase comparison logic.
function ZQG.GetPhaseGuidanceTarget(quest, mapID)
    mapID = mapID or CurrentMapID()
    local mismatch = GetPhaseMismatch(quest, mapID)
    return mismatch and BuildPhaseTarget(quest, mapID, mismatch) or nil
end
