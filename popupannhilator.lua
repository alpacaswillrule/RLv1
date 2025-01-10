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
-- Function to unlock the PopupManager for the NaturalDisasterPopup
-- ===========================================================================
function UnlockNaturalDisasterPopup()
    print("UnlockNaturalDisasterPopup: Attempting to unlock NaturalDisasterPopup");
    local popupManager = UI.GetPopupManager();
    if popupManager then
        if popupManager:IsLocked(ContextPtr) then
            if m_NaturalDisasterPopupControl then
                popupManager:Unlock(m_NaturalDisasterPopupControl);
                print("UnlockNaturalDisasterPopup: PopupManager unlocked for NaturalDisasterPopup");
            else
                print("UnlockNaturalDisasterPopup: m_NaturalDisasterPopupControl is nil, cannot unlock.");
            end
        else
            print("UnlockNaturalDisasterPopup: PopupManager is not locked.");
        end
    else
        print("UnlockNaturalDisasterPopup: PopupManager not found.");
    end
end

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
    else
        print("CloseNaturalDisasterPopup: NaturalDisasterPopup control not found or not initialized.");
    end
end

-- ===========================================================================
-- Function to close all popups (using events as before)
-- ===========================================================================
function CloseAllPopups()
    print("CloseAllPopups: Attempting to close all popups.");
    LuaEvents.LaunchBar_CloseGreatPeoplePopup();
    LuaEvents.LaunchBar_CloseGreatWorksOverview();
    LuaEvents.LaunchBar_CloseReligionPanel();
    
    -- Check for government open state using a global or accessible variable (replace with your actual method)
    if g_isGovernmentOpen then 
        print("CloseAllPopups: Closing Government Panel.");
        LuaEvents.LaunchBar_CloseGovernmentPanel();
    end

    LuaEvents.LaunchBar_CloseTechTree();
    LuaEvents.LaunchBar_CloseCivicsTree();
    CloseNaturalDisasterPopup();
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
        print("BulkHide: Attempting to unlock and hide NaturalDisasterPopup as part of bulk hide.");
        UnlockNaturalDisasterPopup();
        CloseNaturalDisasterPopup();
    end
end

-- ===========================================================================
-- Timer to close popups after a delay
-- ===========================================================================
function ClosePopupsWithDelay()
    if g_closePopups then
        print("ClosePopupsWithDelay: Closing popups after delay");
        CloseAllPopups();
        g_closePopups = false; -- Reset the flag
    end
end

-- ===========================================================================
-- Game Event: Natural Disaster Occurs (or a similar event that triggers the popup)
-- ===========================================================================
function OnNaturalDisasterOccurred(params)
    print("OnNaturalDisasterOccurred: Natural disaster occurred!");
    m_isAgentEnabled = true; -- Assuming this is where your agent becomes active

    -- Get the NaturalDisasterPopup control
    m_NaturalDisasterPopupControl = ContextPtr:LookUpControl("/InGame/NaturalDisasterPopup");

    if m_NaturalDisasterPopupControl then
        print("OnNaturalDisasterOccurred: NaturalDisasterPopup control found.");
    else
        print("OnNaturalDisasterOccurred: NaturalDisasterPopup control NOT found.");
    end
    
    -- Other logic to handle the natural disaster event...
end

-- ===========================================================================
-- Game Event: Playback Complete
-- ===========================================================================
function OnGameCoreEventPlaybackComplete()
    print("OnGameCoreEventPlaybackComplete: m_isAgentEnabled:", m_isAgentEnabled);
    if m_isAgentEnabled then
        print("OnGameCoreEventPlaybackComplete: Agent is enabled. Setting g_closePopups to true.");
        g_closePopups = true;

        -- Start the timer to close popups after a delay
        UI.StartTimer(ClosePopupsWithDelay, 0.1); -- 100ms delay
    end
end

-- ===========================================================================
-- Initialization
-- ===========================================================================
function Initialize()
    print("PopupSuppressor: Initialize called");

    -- Subscribe to events
    Events.GameCoreEventPlaybackComplete.Add(OnGameCoreEventPlaybackComplete);

    print("PopupSuppressor: Initialization complete");
end

Initialize();