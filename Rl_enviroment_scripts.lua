-- Base game includes first
include("InstanceManager");
include("SupportFunctions"); 
include("Civ6Common");
include("PopupDialog");
RLv1 = {};
-- Then our mod files
include("civobvRL");
include("civactionsRL");
include("RL_heur_methods")
local m_pendingPopupDismissals = {}
local m_isAgentEnabled = false; -- Default to disabled


function RLv1.ToggleAgent()
    m_isAgentEnabled = not m_isAgentEnabled;
    -- Fire event for popup annihilator
    LuaEvents.RLAgentToggled(m_isAgentEnabled);
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

                if randomActionType == "EndTurn" then
                    print("EndTurn selected - breaking action loop");
                    RLv1.ExecuteAction(randomActionType, {});
                    return; -- Exit the function entirely since we're ending the turn
                end
                
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
                        elseif randomActionType == "FoundCity" then
                            actionParams = randomAction;
                        elseif randomActionType == "FoundReligion" then
                            actionParams = randomAction[1]; --THE 1 HERE IS TO SELECT FIRST POSSIBLE BELIEF/RELIGION COMBO
                        else
                            actionParams = randomAction;
                        end
                        
                        -- Execute the action, if it isn't delete unit
                        if randomActionType ~= "DeleteUnit" then
                            RLv1.ExecuteAction(randomActionType, actionParams);
                        end
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

-- -- Register our load handler
Events.LoadGameViewStateDone.Add(OnLoadGameViewStateDone);
-- Events.GameCoreEventPlaybackComplete.Add(OnGameCoreEventPlaybackComplete);
-- print("RL Environment Script Registration Complete!");

-- print("POPUP MANAGER")

-- function CloseAllPopups()
-- 	LuaEvents.LaunchBar_CloseGreatPeoplePopup();
-- 	LuaEvents.LaunchBar_CloseGreatWorksOverview();
-- 	LuaEvents.LaunchBar_CloseReligionPanel();
-- 	if isGovernmentOpen then
-- 		LuaEvents.LaunchBar_CloseGovernmentPanel();
-- 	end
-- 	LuaEvents.LaunchBar_CloseTechTree();
-- 	LuaEvents.LaunchBar_CloseCivicsTree();
-- end

-- function OnGameCoreEventPlaybackComplete()
--     if m_isAgentEnabled == true then
--         print("attempting to close popups");
--     CloseAllPopups();
--     end
-- end
