-- Base game includes first
include("InstanceManager");
include("SupportFunctions"); 
include("Civ6Common");
include("PopupDialog");
RLv1 = {};
-- Then our mod files
include("civobvRL");
include("civactionsRL");
include("RL_Policy");
include("rewardFunction");
include("storage")
local m_isAgentEnabled = false; -- Default to disabled
local m_isInitialized = false;
local m_localPlayerID = -1;
local gameId = GenerateGameID()
m_gameHistory = {
    transitions = {},
    episode_number = 0,
    victory_type = nil,
    total_turns = 0,
    game_id = gameId  -- Store the ID with the history
}

local num_games_run = 0 --ONCE THIS NUMBER HITS 10, WE RETRAIN

function retrain()
end

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


-- Victory types as defined in the game
local VICTORY_TYPES = {
    "VICTORY_DEFAULT",
    "VICTORY_SCORE", 
    "VICTORY_TECHNOLOGY",
    "VICTORY_CULTURE",
    "VICTORY_CONQUEST",
    "VICTORY_RELIGIOUS"
};

-- Configuration variables
local TURN_LIMIT = 20;
local AUTO_RESTART_ENABLED = true;


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
    Events.TeamVictory.Add(OnTeamVictory);
    Events.PlayerDefeat.Add(OnPlayerDefeat);

    m_isInitialized = true;
    SendRLNotification("Agent initialized successfully!");
    print("RLv1: Agent initialized successfully!");
end


function RLv1.OnTurnBegin()
    if not m_isAgentEnabled then return end
    --get reward, and state
    state = GetPlayerData(Game.GetLocalPlayer())
    reward = CalculateReward(state)
    --print
    print("Reward: ", reward)

    m_currentGameTurn = Game.GetCurrentGameTurn();
    print("RLv1.OnTurnBegin: Turn " .. m_currentGameTurn .. " started");

    while true do
        local possibleActions = GetPossibleActions()
        local currentState = GetPlayerData(Game.GetLocalPlayer())
        
    if actionType == "ENDTURN" then
        EndTurn(true)
        break
    elseif actionType then
        -- Execute action
        RLv1.ExecuteAction(actionType, actionParams)
        
        -- Get state after action
        local nextState = GetPlayerData(Game.GetLocalPlayer())
        
        -- Record state-action-nextstate transition
        index = index + 1
        table.insert(m_gameHistory.transitions, {
            turn = m_currentGameTurn,
            index = index,
            action = {
                type = actionType,
                params = actionParams
            },
            state = currentState,
            next_state = nextState
        })
        
        -- Update possible actions
        possibleActions = GetPossibleActions()
        if not possibleActions then return end
    else
        print("NO ACTION SELECTED, NOT EVEN ENDTURN, SOMETHING WENT WRONG. Force ending turn")
        EndTurn(true) --we have no actions left, force end turn, but something must've gone wrong
        break
    end
end -- end of while loop
end


-- -- Register our load handler
Events.LoadGameViewStateDone.Add(OnLoadGameViewStateDone);

function RLv1.OnTurnEnd()
    local currentTurn = Game.GetCurrentGameTurn();
    if currentTurn >= TURN_LIMIT and AUTO_RESTART_ENABLED then
        print(string.format("Turn limit %d reached at turn %d. Initiating restart...", 
            TURN_LIMIT, currentTurn));
        AutoRestartGame();
    end
end

-- Get player's team ID
function GetPlayerTeamID(playerID)
    if playerID ~= nil and playerID >= 0 then
        local pPlayer = Players[playerID];
        if pPlayer ~= nil then
            return pPlayer:GetTeam();
        end
    end
    return -1;
end

local g_Timer = 0
local g_RestartDelay = 15  -- 15 second delay

local function StopRestartTimer()
    Events.GameCoreEventPublishComplete.Remove(CheckRestartTimer)
end

local RestartOperation = coroutine.create(function()
    if not AUTO_RESTART_ENABLED then return end
    
    print("Game will restart in " .. tostring(g_RestartDelay) .. " seconds...")
    g_Timer = Automation.GetTime()
    coroutine.yield()
    
    print("Initiating game restart...")
    Network.RestartGame()
    Automation.SetAutoStartEnabled(true)
    StopRestartTimer()
end)

function CheckRestartTimer()
    if Automation.GetTime() >= g_Timer + g_RestartDelay then
        coroutine.resume(RestartOperation)
    end
end

function AutoRestartGame()
    Events.GameCoreEventPublishComplete.Add(CheckRestartTimer)
    coroutine.resume(RestartOperation)
end
-- Handle team victory events
function OnTeamVictory(team, victory, eventID)
    local localPlayer = Game.GetLocalPlayer();
    if (localPlayer and localPlayer >= 0) then
        local localTeamID = GetPlayerTeamID(localPlayer);
        print(string.format("Team %d achieved victory type %s! Local team: %d", 
            team, victory, localTeamID));
        
        -- Restart regardless of which team won
        AutoRestartGame();
    end
end

-- Handle player defeat events
function OnPlayerDefeat(player, defeat, eventID)
    local localPlayer = Game.GetLocalPlayer();
    if (localPlayer and localPlayer >= 0) then
        -- Was it the local player that was defeated?
        if (localPlayer == player) then
            print(string.format("Local player (ID: %d) was defeated! Reason: %s", 
                player, defeat));
            AutoRestartGame();
        end
    end
end

function OnResearchChanged(playerID)
    -- Only process for local player
    if playerID ~= Game.GetLocalPlayer() then 
        return
    end

    print("=== OnResearchChanged: Research Change Detected ===")

    -- 1. Get and Encode Game State
    local currentState = GetPlayerData(playerID)
    local encodedState = EncodeGameState(currentState)
    print("Encoded State Size:", #encodedState)

    -- 2. Initialize Policy Network (if not already initialized)
    if not CivTransformerPolicy.isInitialized then
        CivTransformerPolicy:Init()
        CivTransformerPolicy.isInitialized = true
        print("CivTransformerPolicy initialized.")
    end

    -- 3. Perform Forward Pass
    local possibleActions = GetPossibleActions() -- You might want to modify this to return a simplified structure for testing
    local action_type_probs, action_params_probs, value = CivTransformerPolicy:Forward(encodedState, possibleActions)

    -- 4. Print Outputs for Debugging
    print("=== Forward Pass Outputs ===")
    --print("Action Type Probabilities:", action_type_probs) -- Might be large, depending on the number of action types
    --print("Action Parameter Probabilities:", action_params_probs) -- Might be large
    print("Value:", value)

    -- 5. Test Matrix Operations (Optional)
    print("=== Testing Matrix Operations ===")
    local testMatrix = matrix:new(3, 3, 2) -- Create a 3x3 matrix filled with 2s
    local testMatrix2 = matrix:new({{1, 2, 3}, {4, 5, 6}, {7, 8, 9}})
    print("Test Matrix 1:")
    testMatrix:print()
    print("Test Matrix 2:")
    testMatrix2:print()

    local sumMatrix = matrix.add(testMatrix, testMatrix2)
    print("Sum of Matrices:")
    sumMatrix:print()

    local mulMatrix = matrix.mulnum(testMatrix, 5)
    print("Matrix Multiplied by 5:")
    mulMatrix:print()

    local transposedMatrix = matrix.transpose(testMatrix2)
    print("Transposed Matrix:")
    transposedMatrix:print()

    -- 6. Test Attention Mechanism (Optional)
    print("=== Testing Attention Mechanism (Placeholder) ===")
    -- This is just a placeholder to remind you that you can add specific tests for the attention mechanism here
    -- You'd need to create dummy query, key, value matrices and potentially a mask
    -- Then, call the CivTransformerPolicy:Attention function and print the output
    -- Example (you'll need to adjust dimensions to match your model):
    local query = matrix:new(1, TRANSFORMER_DIM)
    local key = matrix:new(5, TRANSFORMER_DIM)  -- 5 is an example sequence length
    local value = matrix:new(5, TRANSFORMER_DIM)
    local mask = nil -- Or create a test mask

    -- Fill matrices with some dummy values
    for i = 1, query:rows() do
        for j = 1, query:columns() do
            query:setelement(i, j, math.random())
        end
    end

    for i = 1, key:rows() do
        for j = 1, key:columns() do
            key:setelement(i, j, math.random())
            value:setelement(i, j, math.random())
        end
    end
    
    local attention_output = CivTransformerPolicy:Attention(query, key, value, mask)
    print("Attention Output (Size): ", attention_output:size()[1], "x", attention_output:size()[2])
    --print("Attention Output:") -- This might print a large matrix
    --attention_output:print()
end

-- Register the event handler
Events.ResearchQueueChanged.Add(OnResearchChanged)



-- function OnResearchChanged(playerID)
--     -- Only process for local player
--     if playerID ~= Game.GetLocalPlayer() then 
--         return
--     end

--     local currentState = GetPlayerData(playerID) -- Get current game state
--     local cleanstate = CleanStateForSerialization(currentState)
    
--     -- Create a minimal game history with current state
--     local gameHistory = {
--         transitions = {
--             {
--                 turn = Game.GetCurrentGameTurn(),
--                 index = 1,
--                 state = cleanstate,
--                 -- Since this is just a snapshot, we'll leave these empty
--                 action = {},
--                 next_state = nil
--             }
--         },
--         episode_number = 1,
--         victory_type = nil,
--         total_turns = Game.GetCurrentGameTurn()
--     }

--     print("=== Saving Game State on Research Change ===")
--     --SaveGameHistory(gameHistory, "testjohan")

--     -- Load and print info
--     print("=== Loading Saved Game State ===")
--     local loadedHistory = LoadGameHistory("testjohan")
    
--     if loadedHistory then
--         print("Total Turns: " .. tostring(loadedHistory.total_turns))
--         print("Episode Number: " .. tostring(loadedHistory.episode_number))
        
--         -- Print some state info from the first transition
--         if #loadedHistory.transitions > 0 then
--             local state = loadedHistory.transitions[1].state
--             PrintPlayerSummary(state)
--             PrintPlayerUnitsAndCities(state)
--         end
--     else
--         print("Failed to load saved game state")
--     end
-- end

-- -- Register the event handler
-- Events.ResearchQueueChanged.Add(OnResearchChanged)