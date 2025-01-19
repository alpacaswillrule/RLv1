-- Base game includes first
include("InstanceManager");
include("SupportFunctions"); 
include("Civ6Common");
include("PopupDialog");
RLv1 = {};
-- Then our mod files
include("civobvRL");
include("civactionsRL");
include("RL_Policy")
include("rewardFunction")
local m_isAgentEnabled = true; -- Default to disabled

local m_todayGameCount = 0  -- Track number of games saved today

-- Helper function to get today's date as number
function GetTodayHour()
    -- Get current real-world date
    local date = os.date("*t")
    return date.hour
end

-- Function to generate save game name
function GenerateGameSaveName()
    local hour = GetTodayHour()
    m_todayGameCount = m_todayGameCount + 1
    return string.format("rl_game_%d_%d", hour, m_todayGameCount)
end

local m_gameHistory = {
    transitions = {}, -- Will store {state, action, next_state} tuples
    episode_number = 0,
    victory_type = nil,
    total_turns = 0
}

function SaveGameWithHistory()
    local gameFile = {};
    gameFile.Name = GenerateGameSaveName();
    gameFile.Location = SaveLocations.LOCAL_STORAGE;
    gameFile.Type = Network.GetGameConfigurationSaveType();
    gameFile.IsAutosave = false;
    gameFile.IsQuicksave = false;
    
    -- Attach our history to the game configuration
    GameConfiguration.SetValue("RL_HISTORY", m_gameHistory);
    
    Network.SaveGame(gameFile);
end

-- Load history from a saved game
function LoadGameWithHistory(saveName)
    local loadParams = {
        Name = saveName,
        Location = SaveLocations.LOCAL_STORAGE,
        Type = SaveTypes.SINGLE_PLAYER,
        IsAutosave = false,
        IsQuicksave = false
    };
    
    -- Load the game
    if Network.LoadGame(loadParams, ServerType.SERVER_TYPE_NONE) then
        -- Retrieve our history from the game configuration
        local history = GameConfiguration.GetValue("RL_HISTORY");
        if history then
            m_gameHistory = history;
            return true;
        end
    end
    return false;
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

-- Initialize state
local m_isInitialized = false;
local m_currentGameTurn = 0;
local m_localPlayerID = -1;
local m_currentState = nil;
local m_lastReward = 0;

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
local TURN_LIMIT = 100;
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

    -- Load the XML context first
    print("RL: Loading XML context...");
    local success = pcall(function()
        ContextPtr:LoadNewContext("Rl_enviroment_scripts");
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
    Events.TeamVictory.Add(OnTeamVictory);
    Events.PlayerDefeat.Add(OnPlayerDefeat);

    m_isInitialized = true;
    SendRLNotification("Agent initialized successfully!");
    print("RLv1: Agent initialized successfully!");
end


function RLv1.OnTurnBegin()
    
    local possibleActions = GetPossibleActions()
    if not possibleActions then return end
    
    local numActionsToTake = 4
    
    for i = 1, numActionsToTake do
        -- Get state before action
        local currentState = GetPlayerData(Game.GetLocalPlayer())
        print(CalculateReward(currentState))
        local actionType, actionParams = SelectPrioritizedAction(possibleActions)
        if actionType then
            -- Execute action
            RLv1.ExecuteAction(actionType, actionParams)
            
            -- Get state after action
            local nextState = GetPlayerData(Game.GetLocalPlayer())
            
            -- Record state-action-nextstate transition
            table.insert(m_gameHistory.transitions, {
                turn = m_currentGameTurn,
                action = {
                    type = actionType,
                    params = actionParams
                },
                state = currentState,
                next_state = nextState
            })
            
            -- Update possible actions
            possibleActions = GetPossibleActions()
            if not possibleActions then break end
        else
            break
        end
    end

    EndTurn()
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
    SaveGameWithHistory()
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

-- Example analysis function
function AnalyzeGameHistory(saveName)
    if LoadGameWithHistory(saveName) then
        print("Loaded game history:")
        print("Episodes:", m_gameHistory.episode_number)
        print("Total turns:", m_gameHistory.total_turns)
        print("Victory type:", m_gameHistory.victory_type)
        print("Total transitions:", #m_gameHistory.transitions)
        
        -- Analyze actions taken
        local actionCounts = {}
        for _, transition in ipairs(m_gameHistory.transitions) do
            actionCounts[transition.action.type] = (actionCounts[transition.action.type] or 0) + 1
        end
        
        print("\nAction distribution:")
        for actionType, count in pairs(actionCounts) do
            print(actionType .. ":", count)
        end
    end
end

-- Load all games from a specific day
function LoadAllGamesFromDay(day)
    local histories = {}
    local index = 1
    
    -- Try loading games until we fail to find one
    while true do
        local saveName = string.format("rl_game_%d_%d", day, index)
        local loadParams = {
            Name = saveName,
            Location = SaveLocations.LOCAL_STORAGE,
            Type = SaveTypes.SINGLE_PLAYER,
            IsAutosave = false,
            IsQuicksave = false
        };
        
        if Network.LoadGame(loadParams, ServerType.SERVER_TYPE_NONE) then
            local history = GameConfiguration.GetValue("RL_HISTORY")
            if history then
                table.insert(histories, history)
                print("Loaded game: " .. saveName)
            end
            index = index + 1
        else
            break  -- No more games found for this day
        end
    end
    
    print(string.format("Loaded %d games from day %d", #histories, day))
    return histories
end

-- Reset game counter at start of new day
function CheckAndResetDayCounter()
    -- Store last checked date in game configuration to persist between sessions
    local lastCheckedDay = GameConfiguration.GetValue("LAST_CHECKED_DAY")
    local today = GetTodayDate()
    
    if lastCheckedDay ~= today then
        m_todayGameCount = 0
        GameConfiguration.SetValue("LAST_CHECKED_DAY", today)
    end
end

function AnalyzeGamesFromDay(day)
    local histories = LoadAllGamesFromDay(day)
    
    print("\n=== Analysis of Games from Day " .. day .. " ===")
    print("Total games:", #histories)
    
    -- Aggregate statistics across all games
    local totalTurns = 0
    local victories = {}
    local actionCounts = {}
    
    for _, history in ipairs(histories) do
        totalTurns = totalTurns + history.total_turns
        victories[history.victory_type] = (victories[history.victory_type] or 0) + 1
        
        -- Count actions
        for _, transition in ipairs(history.transitions) do
            actionCounts[transition.action.type] = (actionCounts[transition.action.type] or 0) + 1
        end
    end
    
    -- Print statistics
    print("\nAverage turns per game:", totalTurns / #histories)
    print("\nVictory types:")
    for type, count in pairs(victories) do
        print(type .. ":", count)
    end
    
    print("\nMost common actions:")
    for actionType, count in pairs(actionCounts) do
        print(actionType .. ":", count)
    end
end