local ADDON_NAME, ZQG = ...

-- Live Retail testing confirmed that Uldum uses separate best-map IDs for the
-- two Zidormi world states:
--   1527 / Uldum = PRESENT / N'Zoth assaults
--   249  / Uldum = PAST / Cataclysm Uldum
-- Keep the other registered Uldum-related maps unclassified until their live
-- role is observed. Map identity should beat stale session gossip for these two.

local function CurrentMapID()
    if C_Map and C_Map.GetBestMapForUnit then
        return C_Map.GetBestMapForUnit("player")
    end
    return nil
end

local originalGetTimePhaseKey = ZQG.GetTimePhaseKey
if originalGetTimePhaseKey then
    ZQG.GetTimePhaseKey = function(mapID)
        mapID = mapID or CurrentMapID()
        local phase, source = originalGetTimePhaseKey(mapID)

        -- Manual overrides remain the strongest local choice.
        if source == "manual" then
            return phase, source
        end

        if mapID == 1527 then
            return "present", "detected"
        elseif mapID == 249 then
            return "past", "detected"
        end

        return phase, source
    end
end

ZQG.GetUldumTimelinePhase = function(mapID)
    mapID = mapID or CurrentMapID()
    if mapID == 1527 then
        return "present", "detected"
    elseif mapID == 249 then
        return "past", "detected"
    end
    return nil, nil
end
