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
local m_isAgentEnabled = false; -- Default to disabled
local m_isInitialized = false;
local m_localPlayerID = -1;

local m_gameHistory = {
    transitions = {}, -- Will store {state, action, next_state} tuples
    episode_number = 0,
    victory_type = nil,
    total_turns = 0
}


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


--     m_currentGameTurn = Game.GetCurrentGameTurn();
--     print("RLv1.OnTurnBegin: Turn " .. m_currentGameTurn .. " started");
--     --if we have hit turn limit, restart game
--     if m_currentGameTurn >= TURN_LIMIT then
--         print("Turn limit reached at turn " .. m_currentGameTurn .. ". Initiating restart...");
--         AutoRestartGame();
--         return;
--     end

--     while true do
--         local possibleActions = GetPossibleActions()
--         local currentState = GetPlayerData(Game.GetLocalPlayer())
--         local actionType, actionParams = SelectPrioritizedAction(possibleActions)
--     if actionType == "ENDTURN" then
--         EndTurn(true)
--         break
--     elseif actionType then
--         -- Execute action
--         RLv1.ExecuteAction(actionType, actionParams)
        
--         -- Get state after action
--         local nextState = GetPlayerData(Game.GetLocalPlayer())
        
--         -- Record state-action-nextstate transition
--         index = index + 1
--         table.insert(m_gameHistory.transitions, {
--             turn = m_currentGameTurn,
--             index = index,
--             action = {
--                 type = actionType,
--                 params = actionParams
--             },
--             state = currentState,
--             next_state = nextState
--         })
        
--         -- Update possible actions
--         possibleActions = GetPossibleActions()
--         if not possibleActions then return end
--     else
--         print("NO ACTION SELECTED, NOT EVEN ENDTURN, SOMETHING WENT WRONG. Force ending turn")
--         EndTurn(true) --we have no actions left, force end turn, but something must've gone wrong
--         break
--     end
-- end -- end of while loop
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


