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
end

function RLv1.OnTurnEnd()
    if not m_isInitialized then return; end
    
    SendRLNotification("Turn " .. tostring(m_currentGameTurn) .. " completed");
    print("RL Turn " .. tostring(m_currentGameTurn) .. " End");
end

-- Register our load handler
Events.LoadGameViewStateDone.Add(OnLoadGameViewStateDone);

print("RL Environment Script Registration Complete!");

-- -- ===========================================================================
-- -- RLv1 Reinforcement Learning Agent
-- -- ===========================================================================
-- if not ContextPtr then
--     ContextPtr = {};
-- end
-- print("buildtest12");
-- RLv1 = {};
-- -- Add these at the start after the includes:
-- include("InstanceManager");
-- include("SupportFunctions");
-- include("Civ6Common");
-- include("civobvRL");
-- include("civactionsRL"); 
-- ContextPtr:SetInitHandler(Initialize);
-- -- Test includes worked
-- DoPrint()
-- if GetPlayerData == nil then
--     print("Error: Failed to load civ6obv. Check file path and make sure the file exists.");
-- end 

-- -- Agent state tracking
-- local m_isInitialized = false;
-- local m_currentGameTurn = 0;
-- local m_localPlayerID = -1;
-- local m_currentState = nil;
-- local m_lastAction = nil;
-- local m_lastReward = 0;

-- -- ===========================================================================
-- -- State Observation
-- -- ===========================================================================
-- function RLv1.GetState()
--     print("RLv1.GetState: Getting player data...")
--     local playerData = GetPlayerData(m_localPlayerID)
--     print("RLv1.GetState: Player data retrieved.")
--     return playerData;
-- end

-- -- ===========================================================================
-- -- Action Space
-- -- ===========================================================================
-- function RLv1.GetValidActions()
--     print("RLv1.GetValidActions: Getting possible actions...")
--     local possibleActions = GetPossibleActions()
--     print("RLv1.GetValidActions: Possible actions retrieved.")
--     return possibleActions;
-- end

-- -- ===========================================================================
-- -- Reward Calculation
-- -- ===========================================================================
-- function RLv1.CalculateReward()
--     -- TODO: Implement reward calculation
--     -- This should evaluate the current game state and return a reward value
--     -- Could be based on:
--     -- - Score
--     -- - Territory
--     -- - Science/Culture progress
--     -- - Military strength
--     -- etc.
--     print("RLv1.CalculateReward: Reward calculation not yet implemented. Returning 0.");
--     return 0;
-- end

-- -- ===========================================================================
-- -- Initialization
-- -- ===========================================================================
-- function Initialize()
--     if m_isInitialized then 
--         print("RLv1.Initialize: Already initialized.");
--         return; 
--     end

--     -- Get local player ID
--     m_localPlayerID = Game.GetLocalPlayer();
--     if (m_localPlayerID == -1) then
--         print("RLv1: Warning - Local player not yet available");
--         return;
--     end

--     print("RLv1: Initializing agent for player: " .. tostring(m_localPlayerID));

--     -- Register turn events
--     Events.LocalPlayerTurnBegin.Add(RLv1.OnTurnBegin);
--     Events.LocalPlayerTurnEnd.Add(RLv1.OnTurnEnd);

--     m_isInitialized = true;
--     print("RLv1: Agent initialized successfully!");
-- end

-- -- ===========================================================================
-- -- Event Handlers
-- -- ===========================================================================
-- function RLv1.OnTurnBegin()
--     print("turn begin function");
--     if not m_isInitialized then 
--         print("RLv1.OnTurnBegin: Not initialized. Returning.");
--         return; 
--     end

--     print("RLv1: Turn beginning");

--     -- Get current state
--     print("RLv1.OnTurnBegin: Getting current state...");
--     m_currentState = RLv1.GetState();
--     print("RLv1.OnTurnBegin: Current state retrieved.");

--     -- Get valid actions
--     print("RLv1.OnTurnBegin: Getting valid actions...");
--     local validActions = RLv1.GetValidActions();
--     print("RLv1.OnTurnBegin: Valid actions retrieved.");

--     -- Select and execute a random action (for demonstration)
--     -- Choose a random action type
--     local actionTypes = {}
--     for k, v in pairs(validActions) do
--         print("RLv1.OnTurnBegin: Checking action type: " .. tostring(k));
--         if #v > 0 then -- Only consider action types that have possible actions
--             table.insert(actionTypes, k)
--         end
--     end

--     if #actionTypes > 0 then
--         local randomActionType = actionTypes[math.random(#actionTypes)]
--         print("RLv1.OnTurnBegin: Selected random action type: " .. tostring(randomActionType));

--         -- Choose a random action of the selected type
--         local actionsOfSelectedType = validActions[randomActionType]
--         if actionsOfSelectedType and #actionsOfSelectedType > 0 then
--             local randomActionParams = actionsOfSelectedType[math.random(#actionsOfSelectedType)]
--             print("RLv1.OnTurnBegin: Selected random action with params: " .. table.concat(randomActionParams, ", "));

--             -- Ensure actionParams is a table:
--             if type(randomActionParams) ~= "table" then
--                 randomActionParams = { randomActionParams }  -- Wrap in a table if it's a single value
--                 print("RLv1.OnTurnBegin: Wrapped action params in a table.");
--             end
--             print("RLv1.OnTurnBegin: number of actionTypes: " .. #actionTypes);
--             print("RLv1.OnTurnBegin: Executing action: " .. tostring(randomActionType));
--             RLv1.ExecuteAction(randomActionType, randomActionParams)
--         else
--             print("RLv1.OnTurnBegin: No actions available for selected type: " .. randomActionType)
--         end
--     else
--         print("RLv1.OnTurnBegin: No valid actions found this turn.");
--     end

--     print("RLv1: State observation complete");
--     print("RLv1: Number of valid actions: " .. tostring(TableCount(validActions)));
--     m_currentGameTurn = Game.GetCurrentGameTurn();
--     print("RLv1: Turn " .. tostring(m_currentGameTurn) .. " ending");
--     EndTurn()
-- end

-- function TableCount(t)
--     local count = 0
--     for _, __ in pairs(t) do
--         count = count + 1
--     end
--     return count
-- end

-- function RLv1.OnTurnEnd()
--     if not m_isInitialized then return; end

--     -- Calculate reward
--     m_lastReward = RLv1.CalculateReward();

--     -- Debug output
--     print("RLv1: Turn " .. tostring(m_currentGameTurn) .. " completed");
--     print("RLv1: Last action: " .. tostring(m_lastAction));
--     print("RLv1: Reward: " .. tostring(m_lastReward));
-- end

-- -- Register for game load event to initialize
-- Events.LoadGameViewStateDone.Add(Initialize);

-- print("RLv1: Script loaded!");