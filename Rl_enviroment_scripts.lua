-- Base game includes first
include("InstanceManager");
include("SupportFunctions"); 
include("Civ6Common");

RLv1 = {};
-- Then our mod files
include("civobvRL");
include("civactionsRL");

print("RL Environment Script Loading JOHAN MAKER 2...");

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
    Events.GameCoreEventPlaybackComplete.Add(OnGameCoreEventPlaybackComplete);
end

function OnGameCoreEventPlaybackComplete()
    print("RL OnGameCoreEventPlaybackComplete fired");
    InitializeRL();
end

function InitializeRL()
    print("RL InitializeRL called");
    if m_isInitialized then 
        print("RLv1.InitializeRL: Already initialized.");
        return; 
    end

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
    if not m_isInitialized then return; end
    
    m_currentGameTurn = Game.GetCurrentGameTurn();
    SendRLNotification("Turn " .. tostring(m_currentGameTurn) .. " beginning");
    print("RL Turn " .. tostring(m_currentGameTurn) .. " Begin");

    -- Get all possible actions
    print("Getting possible actions for turn " .. tostring(m_currentGameTurn));
    local possibleActions = GetPossibleActions();
    
    -- Count total number of possible actions
    local totalActions = 0;
    local actionTypes = {};
    for actionType, actions in pairs(possibleActions) do
        if type(actions) == "table" and #actions > 0 then
            totalActions = totalActions + #actions;
            table.insert(actionTypes, actionType);
        end
    end
    
    print("Total possible actions: " .. tostring(totalActions));
    
    -- Randomly decide how many actions to take (between 1 and 3)
    local numActionsToTake = math.random(1, math.min(3, totalActions));
    print("Will take " .. tostring(numActionsToTake) .. " actions this turn");
    
    -- Take random actions
    for i = 1, numActionsToTake do
        -- Select random action type that has available actions
        local validActionTypes = {};
        for _, actionType in ipairs(actionTypes) do
            if type(possibleActions[actionType]) == "table" and #possibleActions[actionType] > 0 then
                table.insert(validActionTypes, actionType);
            end
        end
        
        if #validActionTypes > 0 then
            local randomActionType = validActionTypes[math.random(#validActionTypes)];
            local actionsOfType = possibleActions[randomActionType];
            
            -- Select random action of this type
            if #actionsOfType > 0 then
                local randomActionParams = actionsOfType[math.random(#actionsOfType)];
                print("Executing random action: " .. randomActionType);
                
                -- Ensure params is a table
                if type(randomActionParams) ~= "table" then
                    randomActionParams = {randomActionParams};
                end
                
                -- Execute the action
                RLv1.ExecuteAction(randomActionType, randomActionParams);
                
                -- Remove the used action from possible actions to avoid repeating
                for j = #actionsOfType, 1, -1 do
                    if actionsOfType[j] == randomActionParams then
                        table.remove(actionsOfType, j);
                        break;
                    end
                end
            end
        end
    end
    
    -- Always end turn after taking actions
    print("Ending turn " .. tostring(m_currentGameTurn));
    EndTurn();
end

function RLv1.OnTurnEnd()
    if not m_isInitialized then return; end
    
    SendRLNotification("Turn " .. tostring(m_currentGameTurn) .. " completed");
    print("RL Turn " .. tostring(m_currentGameTurn) .. " End");
end

-- Register our load handler
Events.LoadGameViewStateDone.Add(OnLoadGameViewStateDone);

print("RL Environment Script Registration Complete!");

