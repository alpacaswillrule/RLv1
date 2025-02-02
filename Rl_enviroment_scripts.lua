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
include("storage");
include("matrix");
include("ValueNetwork");
include("RL_Update");
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

local num_games_run = 0 --ONCE THIS NUMBER HITS threshold_games_run, WE RETRAIN
local threshold_games_run = 1

function retrain(m_gameHistory)
    -- Attempt training with error handling
    local success, error_message = pcall(function()
        PPOTraining:Update(m_gameHistory)
    end)
    
    if success then
        -- Only save networks if update was successful
        SaveNetworks("johanweights")
        print("Successfully completed training and saved weights")
    else
        -- If training failed, disable the agent and log the error
        m_isAgentEnabled = false
        print("Training failed, disabling agent. Error:", error_message)
        -- Notify user that agent has been disabled
        SendRLNotification("Training failed - agent disabled")
    end
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
local TURN_LIMIT = 5;
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
    SendRLNotification("RL Agent loaded successfully!");
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


local load_weights_from_past_session = false
function InitializeRL()
    print("RL InitializeRL called");
    if m_isInitialized then 
        print("RLv1.InitializeRL: Already initialized.");
        return; 
    end
    if load_weights_from_past_session then
        InitializeNetworks("johanweights")
    else
        InitializeNetworks()
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

function InitializeNetworks(identifier)
    -- Try to load existing weights first
    local policy_loaded = false
    local value_loaded = false
    
    if identifier then
        print("Attempting to load saved weights with identifier: " .. identifier)
        policy_loaded = CivTransformerPolicy:LoadWeights(identifier)
        value_loaded = ValueNetwork:LoadWeights(identifier)
    end
    
    -- Initialize networks that couldn't be loaded
    if not policy_loaded then
        print("Initializing new policy network")
        CivTransformerPolicy:Init()
    else
        print("Successfully loaded policy network weights")
        CivTransformerPolicy.initialized = true
    end
    
    if not value_loaded then
        print("Initializing new value network")
        ValueNetwork:Init()
    else
        print("Successfully loaded value network weights")
        ValueNetwork.initialized = true
    end
    
    return policy_loaded, value_loaded
end




-- Save current weights
function SaveNetworks(identifier)
    CivTransformerPolicy:SaveWeights(identifier)
    ValueNetwork:SaveWeights(identifier)
    print("Saved network weights with identifier: " .. identifier)
end

function RLv1.OnTurnBegin()
    if not m_isAgentEnabled then return end
    
    -- Initialize both networks if needed
    if not CivTransformerPolicy.initialized and not ValueNetwork.initialized then
        InitializeNetworks()
        print("Initialized networks on turn start WARNING")
    end

    state = GetPlayerData(Game.GetLocalPlayer())
    reward = CalculateReward(state)

    m_currentGameTurn = Game.GetCurrentGameTurn();
    print("RLv1.OnTurnBegin: Turn " .. m_currentGameTurn .. " started");
    index = 0
    while true do
        index = index + 1
        -- Perform inference
        state = GetPlayerData(Game.GetLocalPlayer())
        local action = CivTransformerPolicy:Forward(
            CivTransformerPolicy:ProcessGameState(state),
            GetPossibleActions()
        )
        
        -- Get value estimate separately
        local value_estimate = ValueNetwork:GetValue(state)
        
        if action and action.ActionType then
            if action.ActionType == "EndTurn" then
                RLv1.ExecuteAction(action.ActionType, action.Parameters or {})
                --with .05 probability, we will select random action so it's not all end turns local max
                if math.random() < 0.05 then
                    local possibleactions = GetPossibleActions();
                    local act, param = SelectRandomAction(possibleactions)
                    RLv1.ExecuteAction(act, param)
                end
                break
            else
                RLv1.ExecuteAction(action.ActionType, action.Parameters or {})
            end
        end
        
        -- Get state after action
        
        local nextState = GetPlayerData(Game.GetLocalPlayer())
        local reward = CalculateReward(nextState)
        if reward == nil then
            print("Reward is nil ERROR")
            return
        end
        local value = ValueNetwork:GetValue(nextState)
        if value == nil then
            print("Value is nil ERROR")
            return
        end
        print("action.action_probs type:", type(action.action_probs))
        if type(action.action_probs) == "table" then
            for i,v in ipairs(action.action_probs) do
                print(string.format("Index %d: %s (%s)", i, tostring(v), type(v)))
            end
        end
        -- Record transition with value estimate and new probability information
        table.insert(m_gameHistory.transitions, {
            turn = m_currentGameTurn,
            action = {
                type = action.ActionType,
                params = action.Parameters or {}
            },
            reward = reward,
            state = state,
            next_state = nextState,
            value_estimate = value_estimate,
            action_encoding = action.action_encoding,
            -- Make sure these are actual numeric probabilities
            action_probs = type(action.action_probs) == "table" and action.action_probs or {action.action_probs},
            option_probs = type(action.option_probs) == "table" and action.option_probs or {action.option_probs},
            next_value_estimate = value
        })

        if index >= 175 then -- Prevent infinite loops
            RLv1.ExecuteAction("EndTurn", {})
            break
        end

    end
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
    num_games_run = num_games_run + 1
    if num_games_run >= threshold_games_run then
        retrain(m_gameHistory)
        --num_games_run = 0
    --     m_gameHistory = { --RESETING THE GAME HISTORY
    --         transitions = {},
    --         episode_number = 0,
    --         victory_type = nil,
    --         total_turns = 0,
    --         game_id = gameId  -- Store the ID with the history
    --     }
     end
    -- Events.GameCoreEventPublishComplete.Add(CheckRestartTimer)
    -- coroutine.resume(RestartOperation)
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
