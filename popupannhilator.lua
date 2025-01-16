-- ===========================================================================
-- Popup Suppressor
-- ===========================================================================

include("InstanceManager");
include("SupportFunctions");
include("PopupManager");
print("PopupSuppressor: Initializing Popup Suppressor");

local m_isAgentEnabled = false;  -- Global flag to enable/disable popup suppression
local m_NaturalDisasterPopupControl = nil; -- Cache for the Natural Disaster Popup control
local g_closePopups = false;

-- ===========================================================================
-- WE ALSO OVERWRITE THE CIV6 UI POPUPMANAGER, BC GOTTA STOP LOCKS FROM OCCURING
-- ===========================================================================

-- ===========================================================================
-- Function to close the Natural Disaster Popup directly
-- ===========================================================================
function CloseNaturalDisasterPopup()
    print("CloseNaturalDisasterPopup: Attempting to close NaturalDisasterPopup");
    if m_NaturalDisasterPopupControl then
        if not m_NaturalDisasterPopupControl:IsHidden() then
            print("CloseNaturalDisasterPopup: NaturalDisasterPopup found and visible. Hiding it.");
            m_NaturalDisasterPopupControl:SetHide(true);
        else
            print("CloseNaturalDisasterPopup: NaturalDisasterPopup found but already hidden.");
        end
    end
end

function CloseDiplomacyPopups()
    local localPlayerID = Game.GetLocalPlayer();
    -- Loop through all players
    for playerID = 0, GameDefines.MAX_PLAYERS-1 do
        local sessionID = DiplomacyManager.FindOpenSessionID(localPlayerID, playerID);
        if sessionID then
            DiplomacyManager.CloseSession(sessionID);
            break; -- Found and closed the session
        end
    end
    local pContext = ContextPtr:LookUpControl("/InGame/DiplomacyActionView");
    if pContext then
        -- Try using ESC handler first
        if pContext.HandleESC then
            pContext.HandleESC();
            return;
        end
    end
end

-- ===========================================================================
-- Function to close all popups (using events as before)
-- ===========================================================================
function CloseAllPopups()
    print("CloseAllPopups: Attempting to close all popups");
    
    -- Close standard popups
    LuaEvents.LaunchBar_CloseGreatPeoplePopup();
    LuaEvents.LaunchBar_CloseGreatWorksOverview();
    LuaEvents.LaunchBar_CloseReligionPanel();
    
    if g_isGovernmentOpen then 
        LuaEvents.LaunchBar_CloseGovernmentPanel();
    end

    LuaEvents.LaunchBar_CloseTechTree();
    LuaEvents.LaunchBar_CloseCivicsTree();
    
    -- Close diplomacy popups first since they may have engine locks
    CloseDiplomacyPopups();
    
    -- Then close other popups
    CloseNaturalDisasterPopup();    
    BulkHide(false, "CloseAllPopups_Restore");
end

-- Make sure we're subscribed to the turn cycling event
function Initialize()
    print("PopupSuppressor: Initialize called");

    Events.GameCoreEventPlaybackComplete.Add(OnGameCoreEventPlaybackComplete);
    Events.LocalPlayerTurnEnd.Add(CloseAllPopups); -- Add this line
    LuaEvents.RLAgentToggled.Add(OnRLAgentToggled);

    print("PopupSuppressor: Initialization complete");
end

-- ===========================================================================
-- Modified BulkHide function to include NaturalDisasterPopup handling
-- ===========================================================================
local m_bulkHideTracker:number = 0;
local m_lastBulkHider:string = "Not Yet Called";

function BulkHide(isHide: boolean, debugWho: string)
    -- Tracking for debugging:
    m_bulkHideTracker = m_bulkHideTracker + (isHide and 1 or -1);
    print("Request to BulkHide( "..tostring(isHide)..", "..debugWho.." ), Show on 0 = "..tostring(m_bulkHideTracker));

    if m_bulkHideTracker < 0 then
        UI.DataError("Request to bulk show past limit by "..debugWho..". Last bulk shown by "..m_lastBulkHider);
        m_bulkHideTracker = 0;
    end
    m_lastBulkHider = debugWho;

    -- Do the bulk hiding/showing
    local kGroups: table = {"WorldViewControls", "HUD", "PartialScreens", "Screens", "TopLevelHUD"};
    for i, group in ipairs(kGroups) do
        local pContext: table = ContextPtr:LookUpControl("/InGame/"..group);
        if pContext == nil then
            UI.DataError("InGame is unable to BulkHide("..tostring(isHide)..") '/InGame/"..group.."' because the Context doesn't exist.");
        else
            if m_bulkHideTracker == 1 and isHide then
                pContext:SetHide(true);
            elseif m_bulkHideTracker == 0 and isHide == false then
                pContext:SetHide(false);
                -- Don't call RestartRefreshRequest here, handle popup closing separately
            else
                -- Do nothing
            end
        end
    end

    -- Handle NaturalDisasterPopup specifically
    if isHide and m_bulkHideTracker == 1 then
        CloseNaturalDisasterPopup();
    end
end





-- ===========================================================================
-- Game Event: Playback Complete
-- ===========================================================================
function OnGameCoreEventPlaybackComplete()
    print("OnGameCoreEventPlaybackComplete: m_isAgentEnabled:", m_isAgentEnabled);
    if m_isAgentEnabled then
        print("OnGameCoreEventPlaybackComplete: Agent is enabled. Closing popups.");
        g_closePopups = true;
        
        -- Close all popups including diplomacy
        CloseAllPopups();
    end
end

-- ===========================================================================
-- Initialization
-- ===========================================================================
function OnRLAgentToggled(isEnabled)
    print("PopupSuppressor: Agent toggle state changed to: " .. tostring(isEnabled));
    m_isAgentEnabled = isEnabled;
end

function Initialize()
    print("PopupSuppressor: Initialize called");

    -- Subscribe to events
    Events.GameCoreEventPlaybackComplete.Add(OnGameCoreEventPlaybackComplete);
    LuaEvents.RLAgentToggled.Add(OnRLAgentToggled);

    print("PopupSuppressor: Initialization complete");
end

Initialize();
