include("InstanceManager");
include( "SupportFunctions" );
include( "Civ6Common" ); -- IsTutorialRunning()
include( "PopupDialog" );
include( "GameCapabilities" );


print("LOADED POPUPANNHILARO")
-- ===========================================================================
--	GLOBALS (accessible in scripts that include this file)
-- ===========================================================================
ms_IntelPanel = nil;
ms_LocalPlayer = nil;
ms_LocalPlayerID = -1;
-- The selected player. This can be any player, including the local player
ms_SelectedPlayerID = -1;
ms_SelectedPlayer = nil;
ms_ActiveSessionID = nil;
m_bottomPanelHeight = 0;

m_PopupDialog = PopupDialog:new("DiplomacyActionViewPopup");

-- Add a global variable to track if popups should be closed.
local g_closePopups = false;
local m_isAgentEnabled = false; -- You'll need to set this value based on your game logic

-- ===========================================================================
-- Make sure the active session is still there.
-- ===========================================================================
function ValidateActiveSession()

	if (ms_ActiveSessionID ~= nil) then
		if (not DiplomacyManager.IsSessionIDOpen(ms_ActiveSessionID)) then
			ms_ActiveSessionID = nil;
			return false;
		end
	end

	return true;
end

-- ===========================================================================
-- Exit the conversation mode.
-- ===========================================================================
function ExitConversationMode(bForced : boolean)

	if (ms_currentViewMode == CONVERSATION_MODE) then
		ValidateActiveSession();
		if (ms_ActiveSessionID ~= nil) then
			-- Close the session, this will handle exiting back to OVERVIEW_MODE or exiting, if the other leader contacted us.
			if (HasNextQueuedSession(ms_ActiveSessionID)) then
				-- There is another session right after this one, so we want to delay sending the CloseSession until the screen goes to black.
				m_bCloseSessionOnFadeComplete = true;
				StartFadeOut();
			else
				-- Close the session now.
				DiplomacyManager.CloseSession( ms_ActiveSessionID );
			end
		else
			-- No session for some reason, just go directly back.
			if (bForced) then
				Close();
			else
				SelectPlayer(ms_OtherPlayerID, OVERVIEW_MODE);
			end
		end		
		ResetPlayerPanel();
	end
end

-- ===========================================================================
function StartFadeOut()
	Controls.BlackFade:SetHide(false);
	Controls.BlackFadeAnim:SetToBeginning();
	Controls.BlackFadeAnim:Play();
	Controls.FadeTimerAnim:SetToBeginning();
	Controls.FadeTimerAnim:Play();
end

-- ===========================================================================
function StartFadeIn()
	Controls.BlackFade:SetHide(false);

	-- Only do the BlackFadeAnim
	Controls.BlackFadeAnim:SetToBeginning();	-- This forces a clear of the reverse flag.
	Controls.BlackFadeAnim:SetToEnd();
	Controls.BlackFadeAnim:Reverse();
end

-- ===========================================================================
--	Will close whatever has focus; if this is a conversation or dialog they
--	will receive the close action otherwise the screen itself closes.
-- ===========================================================================
function CloseFocusedState(bForced : boolean)
	if m_PopupDialog:IsOpen() then
		m_PopupDialog:Close();
		return;
	end
	if (ms_currentViewMode == CONVERSATION_MODE) then
		if (ms_ActiveSessionID ~= nil) then
			if (Controls.BlackFadeAnim:IsStopped()) then
				ExitConversationMode(bForced);
			end
		else
			Close();
		end
	elseif (ms_currentViewMode == CINEMA_MODE) then
		UI.PlaySound("Stop_Leader_Speech");
		if (Controls.BlackFadeAnim:IsStopped()) then
			StartFadeOut();
		end
	elseif (ms_currentViewMode == DEAL_MODE) then
			-- No handling ESC while transitioning to/from deal mode. The deal screen will handle it if it is up.
	else
		Close();
	end
end

-- ===========================================================================
--	INPUT Handling
--	If this context is visible, it will get a crack at the input.
-- ===========================================================================
function KeyHandler( key:number )
	if (key == Keys.VK_ESCAPE) then 
		CloseFocusedState(false);
	end	
end

-- ===========================================================================
--	UI Callback
--	Consume all key input so it doens't fall through to world
-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then 
		KeyHandler( pInputStruct:GetKey() ); 
		return true;
	elseif uiMsg == KeyEvents.KeyDown then
		return true;
	end

	return false;
end

-- ===========================================================================
--	Guarantee close!
-- ===========================================================================
function Close()

	print("Closing Diplomacy Action View. m_eventID: "..tostring(m_eventID));

	-- If a popup is showing, close it.
	if m_PopupDialog:IsOpen() then
		UI.DataError("Closing DiplomacyActionView but it's popup dialog was open.");
		m_PopupDialog:Close();
	end

	local isCleanExit:boolean = UninitializeView();
	LuaEvents.DiploScene_SceneClosed();
	
	ResetPlayerPanel();

	local localPlayer = Game.GetLocalPlayer();
	if ms_LocalPlayer then
		UI.SetSoundSwitchValue("Game_Location", UI.GetNormalEraSoundSwitchValue(ms_LocalPlayer:GetID()));
	end

    -- always Stop_Leader_Music to resume the game music properly...
    UI.PlaySound("Stop_Leader_Music");

    -- check if we need to also stop modder civ music
    if m_bCurrentMusicIsModder then
		UI.StopModCivLeaderMusic(m_curModderMusic);
    end

    if (m_bIsModPaused) then
		-- resume modder music if it's what was playing (the C++ will make that determination for us)
		UI.ResumeModCivMusic();
		m_bIsModPaused = false;
	end

    UI.PlaySound("Exit_Leader_Screen");
    UI.SetSoundStateValue("Game_Views", "Normal_View");

	-- Don't attempt to change bulk hide state if exit wasn't clean; the
	-- game may just be exiting and this screen was never raised.
	if isCleanExit then
		LuaEvents.DiplomacyActionView_ShowIngameUI();
	end
end


function CloseAllPopups()
	LuaEvents.LaunchBar_CloseGreatPeoplePopup();
	LuaEvents.LaunchBar_CloseGreatWorksOverview();
	LuaEvents.LaunchBar_CloseReligionPanel();
	if isGovernmentOpen then
		LuaEvents.LaunchBar_CloseGovernmentPanel();
	end
	LuaEvents.LaunchBar_CloseTechTree();
	LuaEvents.LaunchBar_CloseCivicsTree();
end

-- ===========================================================================
function OnGameCoreEventPlaybackComplete()
    if m_isAgentEnabled == true then
        print("attempting to close popups");
		CloseAllPopups()
		-- Use a local variable to signal that popups should be closed.
		g_closePopups = true;
    end
end

-- ===========================================================================
-- UI Event Handler: Called when the game core has finished an event batch.
-- ===========================================================================


-- ===========================================================================
-- Timer to close popups after a delay
-- ===========================================================================
function ClosePopupsWithDelay()
    if g_closePopups then
        print("Closing popups after delay");
        CloseAllPopups();
        g_closePopups = false; -- Reset the flag
    end
end

-- Assuming you have access to UI.StartTimer
UI.StartTimer(ClosePopupsWithDelay, 0.1); -- Timer for 100ms

-- ===========================================================================
-- Update: Listen for a UI event that signifies the end of popup creation.
-- This is a placeholder; you'll need to find an appropriate event.
-- ===========================================================================
-- ===========================================================================
-- Update: Listen for a UI event that signifies the end of popup creation.
-- This is a placeholder; you'll need to find an appropriate event.
-- ===========================================================================
function OnInterfaceUpdateComplete()
    if g_closePopups then
        print("Closing popups after UI update");
        CloseAllPopups();
        g_closePopups = false; -- Reset the flag
    end
end
Events.InterfaceUpdateComplete.Add(OnInterfaceUpdateComplete); -- Replace 'InterfaceUpdateComplete' with an actual event if available

-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnShow()
	-- NOTE: We can get here after the OnDiplomacyStatement handler has done some setup, so don't reset too much, assume that OnHide has closed things down properly.	

	Controls.AlphaIn:SetToBeginning();
	Controls.SlideIn:SetToBeginning();
	Controls.AlphaIn:Play();
	Controls.SlideIn:Play();

	m_bCloseSessionOnFadeComplete = false;

	ms_IconAndTextIM:ResetInstances();

	SetupPlayers();
	UpdateSelectedPlayer(true);

	LuaEvents.DiploBasePopup_HideUI(true);
	LuaEvents.DiploScene_SceneOpened(ms_SelectedPlayerID, m_LiteMode);
	UI.DeselectAllCities(); --We can get some bad UI if City statuses change because of diplomacy, so just deselect them when we open

	TTManager:ClearCurrent();	-- Clear any tool tips raised;

	if (m_cinemaMode) then
		ShowCinemaMode();
		StartFadeIn();
	end

end

----------------------------------------------------------------    
function OnHide()

	LuaEvents.DiploBasePopup_HideUI(false);
	Controls.BlackFade:SetHide(true);
	Controls.BlackFadeAnim:SetToBeginning();
	-- Game Core Events	
	Events.LeaderAnimationComplete.Remove( OnLeaderAnimationComplete );
	Events.LeaderScreenFinishedLoading.Remove( OnLeaderLoaded );

	ms_showingLeaderName = "";

end

-- ===========================================================================
function OnForceClose()
	if (not ContextPtr:IsHidden()) then
		PopulatePlayerPanel(ms_PlayerPanel, ms_SelectedPlayer);
		-- If the local player's turn ends (turn timer usually), act like they hit esc.
		if (ms_currentViewMode == DEAL_MODE) then
			-- Unless we were in the deal mode, then just close, the deal view will close too.
			Close();
		else
			CloseFocusedState(true);
		end
	end
end

-- ===========================================================================
function OnLocalPlayerTurnEnd()
	g_bIsLocalPlayerTurn = false;
	OnForceClose();
end

-- ===========================================================================
function OnLocalPlayerTurnBegin()
	g_bIsLocalPlayerTurn = true;
	if(not ContextPtr:IsHidden()) then
		OnForceClose();
	end
end

-- ===========================================================================
--	HOTLOADING UI EVENTS
-- ===========================================================================
function OnInit(isHotload:boolean)
	LateInitialize();
	CreatePanels();
	if isHotload and not ContextPtr:IsHidden() then
		LuaEvents.GameDebug_GetValues( "DiplomacyActionView" );	
	end
end

--	Context DESTRUCTOR - Not called when screen is dismissed, only if the whole context is removed!
function OnShutdown()
	-- Cache values for hotloading...
	LuaEvents.GameDebug_AddValue("DiplomacyActionView", "isHidden", ContextPtr:IsHidden());
	LuaEvents.GameDebug_AddValue("DiplomacyActionView", "otherPlayerID", ms_OtherPlayerID);
	LuaEvents.GameDebug_AddValue("DiplomacyActionView", "liteMode", m_LiteMode);
end

-- LUA EVENT:  Set cached values back after a hotload.
function OnGameDebugReturn( context:string, contextTable:table )
	if context == "DiplomacyActionView" and contextTable["isHidden"] ~= nil and not contextTable["isHidden"] then
		m_LiteMode = contextTable["liteMode"];
		OnOpenDiplomacyActionView(contextTable["otherPlayerID"]);
	end
end

-- ===========================================================================
function OnGamePauseStateChanged(bNewState)
	if (not ContextPtr:IsHidden()) then
		ResetPlayerPanel();
		SelectPlayer(ms_SelectedPlayerID, OVERVIEW_MODE, true);
	end
end

-- ===========================================================================
function LateInitialize()
	-- Game Core Events	
	Events.DiplomacySessionClosed.Add( OnDiplomacySessionClosed );
	Events.DiplomacyStatement.Add( OnDiplomacyStatement );
	Events.DiplomacyMakePeace.Add( OnDiplomacyMakePeace );
	Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );
	Events.LocalPlayerTurnBegin.Add( OnLocalPlayerTurnBegin );
	Events.UserRequestClose.Add( OnUserRequestClose );
	Events.GamePauseStateChanged.Add(OnGamePauseStateChanged);
	Events.PlayerDefeat.Add( OnPlayerDefeat );
	Events.TeamVictory.Add( OnTeamVictory );
    Events.GameCoreEventPlaybackComplete.Add(OnGameCoreEventPlaybackComplete);

	-- LUA Events
	LuaEvents.CityBannerManager_TalkToLeader.Add(OnTalkToLeader);
	LuaEvents.DiploPopup_TalkToLeader.Add(OnTalkToLeader);
	LuaEvents.DiplomacyRibbon_OpenDiplomacyActionView.Add(OnOpenDiplomacyActionView);
	LuaEvents.TopPanel_OpenDiplomacyActionView.Add(OnOpenDiplomacyActionView);	
	LuaEvents.DiploScene_SetDealAnimation.Add(OnSetDealAnimation);
	LuaEvents.NaturalWonderPopup_Shown.Add(OnBlockingPopupShown);
	LuaEvents.WonderBuiltPopup_Shown.Add(OnBlockingPopupShown);
	LuaEvents.DiplomacyActionView_OpenLite.Add(OnOpenDiplomacyActionViewLite);

	Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnClose );
	Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	
	-- Size controls for screen:
	local screenX, screenY:number = UIManager:GetScreenSizeVal();
	local leaderResponseX = math.floor(screenX * CONVO_X_MULTIPLIER);
	Controls.LeaderResponseGrid:SetSizeX(leaderResponseX);
	Controls.LeaderResponseText:SetWrapWidth(leaderResponseX-40);
	Controls.LeaderReasonText:SetWrapWidth(leaderResponseX-40);

	Controls.ScreenClickRegion:RegisterCallback( Mouse.eRClick, HandleRMB )

	m_bIsModPaused = false;
end

-- ===========================================================================
function Initialize()
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetInputHandler( OnInputHandler, true );
	ContextPtr:SetShutdown( OnShutdown );
	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetHideHandler( OnHide );
	LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );	
end

if GameCapabilities.HasCapability("CAPABILITY_DIPLOMACY") then
	Initialize();
end

--https://forums.civfanatics.com/threads/help-closing-a-popup-window.440006/