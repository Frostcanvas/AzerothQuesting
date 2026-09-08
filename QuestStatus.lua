local ADDON_NAME, ZQG = ...

local function IsQuestComplete(questID)
    if not questID then
        return false
    end

    if C_QuestLog and C_QuestLog.IsComplete then
        local ok, complete = pcall(C_QuestLog.IsComplete, questID)
        if ok and complete ~= nil then
            return complete == true or complete == 1
        end
    end

    -- Fallback for clients/builds where the direct completion helper is not
    -- available or does not return a value for this quest yet.
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetInfo then
        local indexOK, logIndex = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
        if indexOK and logIndex and logIndex > 0 then
            local infoOK, info = pcall(C_QuestLog.GetInfo, logIndex)
            if infoOK and info and info.isComplete ~= nil then
                return info.isComplete == true or info.isComplete == 1
            end
        end
    end

    return false
end

function ZQG.IsQuestReadyToTurnIn(quest)
    return quest and quest.accepted and IsQuestComplete(quest.id) or false
end

function ZQG.GetQuestStatusKey(quest)
    if not quest then
        return "unknown"
    end

    if not quest.accepted then
        return "available"
    end

    if ZQG.IsQuestReadyToTurnIn(quest) then
        return "turnin"
    end

    return "progress"
end

function ZQG.GetQuestStatusText(quest)
    local status = ZQG.GetQuestStatusKey(quest)

    if status == "available" then
        return "|cffffff66AVAILABLE|r"
    elseif status == "turnin" then
        return "|cffffa500TURN IN|r"
    elseif status == "progress" then
        return "|cff66ff66IN PROGRESS|r"
    end

    return "|cffaaaaaaUNKNOWN|r"
end

function ZQG.GetQuestStatusPriority(quest)
    local status = ZQG.GetQuestStatusKey(quest)

    -- Keep the behavior requested in v0.1.4: quests that can still be picked
    -- up remain first. Completed accepted quests come next, followed by quests
    -- that still have objectives in progress.
    if status == "available" then
        return 1
    elseif status == "turnin" then
        return 2
    elseif status == "progress" then
        return 3
    end

    return 4
end
