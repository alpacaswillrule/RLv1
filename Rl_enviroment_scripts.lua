-- Base game includes first
include("InstanceManager");
include("SupportFunctions"); 
include("Civ6Common");
include("PopupDialog");
RLv1 = {};
-- Then our mod files
include("civobvRL");
include("civactionsRL");

local m_pendingPopupDismissals = {}
local m_isAgentEnabled = false; -- Default to disabled


function RLv1.ToggleAgent()
    m_isAgentEnabled = not m_isAgentEnabled;
    if Controls.ToggleRLText then
        if m_isAgentEnabled then
            Controls.ToggleRLText:SetText(Locale.ToUpper("RL Agent: ON"));
            Controls.ToggleRLText:SetColor(UI.GetColorValue("COLOR_GREEN"));
        else
            Controls.ToggleRLText:SetText(Locale.ToUpper("RL Agent: OFF")); 
            Controls.ToggleRLText:SetColor(UI.GetColorValue("COLOR_LIGHT_GRAY"));
        end
    end
    
    -- Send notification regardless of UI state
    if m_isAgentEnabled then
        SendRLNotification("RL Agent enabled");
    else
        SendRLNotification("RL Agent disabled");
    end
end

-- Initialize state
local m_isInitialized = false;
local m_currentGameTurn = 0;
local m_localPlayerID = -1;
local m_currentState = nil;
local m_lastReward = 0;

-- Helper function to send notifications
function SendRLNotification(message)
    if m_localPlayerID ~= -1 then
        NotificationManager.SendNotification(
            m_localPlayerID,
            NotificationTypes.USER_DEFINED_1,
            "RL Agent: " .. message
        );
        print("RL Notification: " .. message);
    end
end

-- Game initialization
function OnLoadGameViewStateDone()
    print("RL OnLoadGameViewStateDone fired");
    InitializeRL();  -- Initialize immediately when view is loaded
    Events.GameCoreEventPlaybackComplete.Add(OnGameCoreEventPlaybackComplete);
end

function OnGameCoreEventPlaybackComplete()
    -- Add natural wonder popup handler
    Events.NaturalWonderRevealed.Add(function(plotX, plotY, eFeature, isFirstToFind)
        local wonderPopupContext = ContextPtr:LookUpControl("/InGame/NaturalWonderPopup")
        if wonderPopupContext and wonderPopupContext.Close then
            wonderPopupContext.Close()
        end
    end)

    -- Handle diplomacy using DiplomacyStatement instead
    Events.DiplomacyStatement.Add(function(fromPlayer, toPlayer, kVariants)
        local diplo = ContextPtr:LookUpControl("/InGame/DiplomacyActionView")
        if diplo and diplo.CloseDiplomacyActionView then
            diplo.CloseDiplomacyActionView()
        end
    end)

    Events.GameCoreEventPublishComplete.Add(function()
        for popupType, _ in pairs(m_pendingPopupDismissals) do
            m_PopupManager:ClosePopup(popupType)
            m_pendingPopupDismissals[popupType] = nil
        end
    end)
end

function OnInputHandler(pInputStruct)
    local uiMsg = pInputStruct:GetMessageType();
    if uiMsg == KeyEvents.KeyUp then
        -- Toggle agent with Ctrl+Shift+A
        if pInputStruct:IsShiftDown() and pInputStruct:IsControlDown() 
        and pInputStruct:GetKey() == Keys.A then
            RLv1.ToggleAgent();
            return true;
        end
    end
    return false;
end

function InitializeRL()
    print("RL InitializeRL called");
    if m_isInitialized then 
        print("RLv1.InitializeRL: Already initialized.");
        return; 
    end

    -- Load the XML context first
    print("RL: Loading XML context...");
    local success = pcall(function()
        ContextPtr:LoadNewContext("RLEnvironment");
    end)
    
    if not success then
        print("ERROR: Failed to load RLEnvironment context!");
        return;
    end
    print("RL: XML context loaded successfully");
    
    -- Force immediate UI update and ensure context is active
    ContextPtr:RequestRefresh();
    ContextPtr:SetHide(false);
    
    -- Initialize UI elements after context is loaded
    print("RL: Initializing UI elements...");
    if Controls.ToggleRLButton then
        Controls.ToggleRLText:SetText(Locale.ToUpper("RL Agent: OFF"));
        Controls.ToggleRLButton:RegisterCallback(Mouse.eLClick, function()
            RLv1.ToggleAgent();
            UI.PlaySound("Play_UI_Click");
        end);
        Controls.ToggleRLButton:RegisterCallback(Mouse.eMouseEnter, function()
            UI.PlaySound("Main_Menu_Mouse_Over");
        end);

        -- Show the button container
        Controls.RLButtonContainer:SetHide(false);
    else
        print("WARNING: ToggleRLButton control not found!");
    end

    -- Set up input handler
    ContextPtr:SetInputHandler(OnInputHandler, true);

    m_localPlayerID = Game.GetLocalPlayer();
    if (m_localPlayerID == -1) then
        print("RLv1: Warning - Local player not yet available");
        return;
    end

    print("RLv1: Initializing agent for player: " .. tostring(m_localPlayerID));
    SendRLNotification("Initializing RL agent for player " .. tostring(m_localPlayerID));

    -- Register turn events
    Events.LocalPlayerTurnBegin.Add(RLv1.OnTurnBegin);
    Events.LocalPlayerTurnEnd.Add(RLv1.OnTurnEnd);

    m_isInitialized = true;
    SendRLNotification("Agent initialized successfully!");
    print("RLv1: Agent initialized successfully!");
end

function RLv1.OnTurnBegin()
    if not m_isInitialized or not m_isAgentEnabled then return; end
    
    m_currentGameTurn = Game.GetCurrentGameTurn();
    SendRLNotification("Turn " .. tostring(m_currentGameTurn) .. " beginning");
    print("RL Turn " .. tostring(m_currentGameTurn) .. " Begin");

    -- Get all possible actions
    print("Getting possible actions for turn " .. tostring(m_currentGameTurn));
    local possibleActions = GetPossibleActions();
    
    if not possibleActions then
        print("No possible actions available")
        return
    end
    
    -- Count total number of possible actions
    local totalActions = 0
    local actionTypes = {}
    for actionType, actions in pairs(possibleActions) do
        if type(actions) == "table" and #actions > 0 then
            totalActions = totalActions + #actions
            table.insert(actionTypes, actionType)
        elseif actions == true then
            -- Count boolean actions like EndTurn as 1 action
            totalActions = totalActions + 1
            table.insert(actionTypes, actionType)
        end
    end

    print("Total possible actions: " .. tostring(totalActions))

    -- Only proceed if we have actions available
    if totalActions > 0 then
        -- Randomly decide how many actions to take (between 1 and 3)
        local numActionsToTake = math.random(1, math.min(3, totalActions))
        print("Will take " .. tostring(numActionsToTake) .. " actions this turn")
        
        -- Take random actions
        for i = 1, numActionsToTake do
            -- Select random action type that has available actions
            local validActionTypes = {};
            for _, actionType in ipairs(actionTypes) do
                if type(possibleActions[actionType]) == "table" then
                    if #possibleActions[actionType] > 0 then
                        table.insert(validActionTypes, actionType);
                    end
                elseif possibleActions[actionType] == true then
                    table.insert(validActionTypes, actionType);
                end
            end
            
            if #validActionTypes > 0 then
                local randomActionType = validActionTypes[math.random(#validActionTypes)];
                print("Selected action type: " .. randomActionType);
                
                local actionParams = {};
                if type(possibleActions[randomActionType]) == "table" then
                    local actionsOfType = possibleActions[randomActionType];
                    if #actionsOfType > 0 then
                        local randomActionIndex = math.random(#actionsOfType);
                        local randomAction = actionsOfType[randomActionIndex];
                        
                        if randomActionType == "MoveUnit" then
                            actionParams = {randomAction.UnitID, randomAction.X, randomAction.Y};
                        elseif randomActionType == "SelectUnit" or randomActionType == "DeleteUnit" then
                            actionParams = {randomAction.UnitID};
                        elseif randomActionType == "PromoteUnit" then
                            actionParams = {randomAction.UnitID, randomAction.PromotionType};
                        elseif randomActionType == "ChooseCivic" or randomActionType == "ChooseTech" then
                            actionParams = {randomAction};
                        elseif randomActionType == "ChangePolicies" then
                            actionParams = randomAction;
                        elseif randomActionType == "CityProduction" then
                            actionParams = randomAction;
                        else
                            actionParams = {table.unpack(randomAction)};
                        end
                        
                        -- Execute the action
                        RLv1.ExecuteAction(randomActionType, actionParams);
                        
                        -- Remove used action
                        table.remove(actionsOfType, randomActionIndex);
                    end
                else
                    -- Handle boolean actions like EndTurn
                    RLv1.ExecuteAction(randomActionType, {});
                end
            end
        end
    end
    
    -- Always end turn after taking actions
    print("Ending turn " .. tostring(m_currentGameTurn));
    EndTurn();
end

function RLv1.OnTurnEnd()
    if not m_isInitialized or not m_isAgentEnabled then return; end
    
    SendRLNotification("Turn " .. tostring(m_currentGameTurn) .. " completed");
    print("RL Turn " .. tostring(m_currentGameTurn) .. " End");
end

-- Register our load handler
Events.LoadGameViewStateDone.Add(OnLoadGameViewStateDone);

print("RL Environment Script Registration Complete!");

-- Initialize popup manager
local m_PopupManager = {
    activePopups = {},
    popupQueue = {},
    isProcessing = false
}

-- Define popup types and their close functions
local POPUP_TYPES = {
    NATURAL_WONDER = {
        context = "/InGame/NaturalWonderPopup",
        closeFunction = "Close",
    },
    DIPLOMACY = {
        context = "/InGame/DiplomacyActionView", 
        closeFunction = "CloseDiplomacyActionView", 
    }
}

function m_PopupManager:ClosePopup(popupType)
    local success = false
    local popupInfo = POPUP_TYPES[popupType]
    
    if popupInfo then
        local success, error = pcall(function()
            local popupContext = ContextPtr:LookUpControl(popupInfo.context)
            if popupContext then
                if popupType == "DIPLOMACY" then
                    LuaEvents.DiplomacyActionView_ShowIngameUI();
                    UI.PlaySound("Exit_Leader_Screen");
                    UI.SetSoundStateValue("Game_Views", "Normal_View");
                else
                    local closeFunction = popupContext[popupInfo.closeFunction]
                    if closeFunction then
                        closeFunction()
                    end
                end
                print("Successfully closed popup: " .. popupType)
                success = true
            end
        end)
        
        if not success then
            print("Failed to close popup: " .. tostring(error))
        end
    end

    self.activePopups[popupType] = nil
    return success
end

function m_PopupManager:ProcessPopupQueue()
    if self.isProcessing then return end
    
    self.isProcessing = true
    for popupType in pairs(self.popupQueue) do
        print("Processing popup dismissal: " .. popupType)
        self:ClosePopup(popupType)
        self.popupQueue[popupType] = nil
    end    
    self.isProcessing = false
end

function AddPendingPopupDismissal(popupType)
    if not m_pendingPopupDismissals then
        m_pendingPopupDismissals = {}
    end
    m_pendingPopupDismissals[popupType] = true
end

function m_PopupManager:QueuePopupDismissal(popupType)
    if POPUP_TYPES[popupType] then
        AddPendingPopupDismissal(popupType)
        self.popupQueue[popupType] = true
        self.activePopups[popupType] = true
        print("Queued popup dismissal for: " .. popupType)
    end
end

function Initialize()
    Events.NaturalWonderRevealed.Add(function(plotX, plotY, eFeature, isFirstToFind)
        if m_PopupManager.activePopups["NATURAL_WONDER"] then
            m_PopupManager:ClosePopup("NATURAL_WONDER")
        end
    end)

    Events.DiplomacyStatement.Add(function(fromPlayer, toPlayer, kVariants)
        if m_PopupManager.activePopups["DIPLOMACY"] then
            m_PopupManager:ClosePopup("DIPLOMACY") 
        end
    end)

    Events.GameCoreEventPublishComplete.Add(function()
        m_PopupManager:ProcessPopupQueue()
    end)

    print("Popup Manager Initialized")
end

Initialize()
