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
include("rewardFunction")
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
    Events.TeamVictory.Add(OnTeamVictory);
    Events.PlayerDefeat.Add(OnPlayerDefeat);

    m_isInitialized = true;
    SendRLNotification("Agent initialized successfully!");
    print("RLv1: Agent initialized successfully!");
end
function RLv1.OnTurnBegin()
    print("=== TURN BEGIN FUNCTION START ===")

    local playerState = GetPlayerData(Game.GetLocalPlayer())
    --PrintPlayerSummary(playerState)
    PrintPlayerUnitsAndCities(playerState)
    --PrintTileDataSummary(playerState.VisibleTiles,playerState.revealedTiles)
    
    if not m_isInitialized then 
        print("Not initialized, returning")
        return
    end
    if not m_isAgentEnabled then
        print("Agent not enabled, returning")
        return
    end
    
    m_currentGameTurn = Game.GetCurrentGameTurn();

    SendRLNotification("Turn " .. tostring(m_currentGameTurn) .. " beginning");
    print("RL Turn " .. tostring(m_currentGameTurn) .. " Begin");

    local possibleActions = GetPossibleActions()
    
    if not possibleActions then
        print("No possible actions available")
        return
    end
    
    -- Use the prioritized action selector
    local numActionsToTake = 4 --math.random(4, 9)
    print("Planning to take " .. numActionsToTake .. " actions")
    
    for i = 1, numActionsToTake do
        print("Starting action iteration " .. i)
        
        local actionType, actionParams = SelectPrioritizedAction(possibleActions)
        
        if actionType then
            print("Selected action:", actionType)
            --print("Action params:", actionParams and table.concat(actionParams, ", ") or "nil")
            
            RLv1.ExecuteAction(actionType, actionParams)
            print("Action execution completed")
            
            -- Update possible actions after each execution to maintain accuracy
            possibleActions = {} --RESET POSSIBLE ACTIONS
            ContextPtr:RequestRefresh()
            possibleActions = GetPossibleActions()
            
            if not possibleActions then 
                print("No more possible actions after update")
                break 
            end
        else
            print("No action selected, breaking loop")
            break
        end
        
        print("Completed action iteration " .. i)
    end

    print("Action loop complete, ending turn")
    -- Always end turn after taking actions
    EndTurn();
    print("=== TURN BEGIN FUNCTION END ===")
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

-- Enhanced auto restart with confirmation
function AutoRestartGame()
    if not AUTO_RESTART_ENABLED then return end;
    
    print("Initiating game restart...");
    Network.RestartGame();
    Automation.SetAutoStartEnabled(true);
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
