-- Base game includes first
include("InstanceManager");
include("SupportFunctions"); 
include("Civ6Common");

RLv1 = {};
-- Then our mod files
include("civobvRL");
include("civactionsRL");

print("RL Environment Script Loading JOHAN MAKER 2...");

local m_isAgentEnabled = false; -- Default to disabled

function RLv1.EnableAgent()
    m_isAgentEnabled = true;
    SendRLNotification("RL Agent enabled");
end

function RLv1.DisableAgent()
    m_isAgentEnabled = false; 
    SendRLNotification("RL Agent disabled");
end

function RLv1.ToggleAgent()
    m_isAgentEnabled = not m_isAgentEnabled;
    if m_isAgentEnabled then
        SendRLNotification("RL Agent enabled");
    else
        SendRLNotification("RL Agent disabled");
    end
end

-- Add at the top with other state variables
-- Initialize state
local m_isInitialized = false;
local m_currentGameTurn = 0;
local m_localPlayerID = -1;
local m_currentState = nil;
local m_lastAction = nil;
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
    print("RL OnGameCoreEventPlaybackComplete fired");
    -- Check if UI needs to be reinitialized
    if not Controls.RLButtonContainer then
        print("RL: Button container not found, attempting to reinitialize...");
        InitializeRL();
    else
        print("RL: Button container found, ensuring visibility");
        Controls.RLButtonContainer:SetHide(false);
        -- Force UI update
        Controls.RLContainer:ChangeParent(ContextPtr);
    end
end

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
        print("WARNING: ToggleRLButton control not found! Available controls:");
        for k,v in pairs(Controls) do
            print("  - " .. tostring(k));
        end
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
    
    -- Print detailed action information
    print("\n=== AVAILABLE ACTIONS FOR TURN " .. tostring(m_currentGameTurn) .. " ===");
    
    for actionType, actions in pairs(possibleActions) do
        if type(actions) == "table" and #actions > 0 then
            print("\nAction Type: " .. actionType);
            print("Number of possible actions: " .. #actions);
            print("Available Parameters:");
            
            -- Print specific details based on action type
            for i, action in ipairs(actions) do
                if actionType == "MoveUnit" then
                    print(string.format("  %d. Unit ID: %s, Target Position: X=%s, Y=%s", 
                        i, tostring(action.UnitID), tostring(action.X), tostring(action.Y)));
                elseif actionType == "UnitRangedAttack" then
                    print(string.format("  %d. Unit ID: %s, Target Position: X=%s, Y=%s", 
                        i, tostring(action.UnitID), tostring(action.X), tostring(action.Y)));
                elseif actionType == "PromoteUnit" then
                    print(string.format("  %d. Unit ID: %s, Promotion: %s", 
                        i, tostring(action.UnitID), tostring(action.PromotionType)));
                elseif actionType == "ChooseCivic" or actionType == "ChooseTech" then
                    print(string.format("  %d. %s", i, tostring(action)));
                elseif actionType == "ChangePolicies" then
                    print(string.format("  %d. Slot: %s, Policy: %s", 
                        i, tostring(action.SlotIndex), tostring(action.PolicyType)));
                else
                    if type(action) == "table" then
                        print(string.format("  %d. Parameters: %s", 
                            i, table.concat(action, ", ")));
                    else
                        print(string.format("  %d. Parameter: %s", i, tostring(action)));
                    end
                end
            end
        elseif actions == true then
            print("\nAction Type: " .. actionType);
            print("Available (no parameters required)");
        end
    end
    print("\n=== END OF AVAILABLE ACTIONS ===\n");
    
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
        -- Only add action types that have valid parameters
        if type(possibleActions[actionType]) == "table" then
            if #possibleActions[actionType] > 0 then
                -- For actions that require parameters, verify they have them
                local hasValidParams = false;
                if actionType == "MoveUnit" then
                    hasValidParams = possibleActions[actionType][1].UnitID and 
                                   possibleActions[actionType][1].X and 
                                   possibleActions[actionType][1].Y;
                elseif actionType == "SelectUnit" or actionType == "DeleteUnit" then
                    hasValidParams = type(possibleActions[actionType][1].UnitID) == "number";
                elseif actionType == "PromoteUnit" then
                    hasValidParams = possibleActions[actionType][1].UnitID and 
                                   possibleActions[actionType][1].PromotionType;
                elseif actionType == "ChangePolicies" then
                    -- Check for the new structure
                    hasValidParams = possibleActions[actionType][1].SlotIndex and
                                     possibleActions[actionType][1].PolicyType and
                                     possibleActions[actionType][1].PolicyHash
                else
                    hasValidParams = true; -- Other actions are assumed valid if they exist
                end
                
                if hasValidParams then
                    table.insert(validActionTypes, actionType);
                end
            end
        elseif possibleActions[actionType] == true then
            -- For boolean actions like EndTurn
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
                        -- Get a random policy change option
                        local randomPolicyChange = actionsOfType[math.random(#actionsOfType)]
                        
                        -- Pass the full policy change data structure
                        actionParams = {
                            SlotIndex = randomPolicyChange.SlotIndex,
                            PolicyType = randomPolicyChange.PolicyType,
                            PolicyHash = randomPolicyChange.PolicyHash
                        }
                else
                    if type(randomAction) == "table" then
                        for k, v in pairs(randomAction) do
                            table.insert(actionParams, v);
                        end
                    else
                        actionParams = {randomAction};
                    end
                end
                
                print("Executing random action: " .. randomActionType);
                print("With parameters:", table.concat(actionParams, ", "));
                
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
