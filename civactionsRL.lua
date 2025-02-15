-- civ6_agent_actions.lua
if not ContextPtr then
  ContextPtr = {};
end
-- Include necessary game files (assuming they are in the same directory or a known path)
include("Civ6Common"); -- Make sure this path matches your file structure.
include("InstanceManager");
include( "SupportFunctions" );
include( "UnitSupport" );
include( "Colors" );
include( "CombatInfo" );
include( "PopupDialog" );
include( "EspionageSupport" );
include("GameCapabilities");
--------------------------------------------------
-- ACTION FUNCTIONS
--------------------------------------------------


-- ===========================================================================
-- Action Execution
-- ===========================================================================
function RLv1.ExecuteAction(actionType, actionParams)
    print("\n=== EXECUTING ACTION ===");
    print("Action Type: " .. tostring(actionType));
    print("Parameters:" .. tostring(actionParams));
    

    if actionType == "EndTurn" then
        EndTurn();
    elseif actionType == "ChooseCivic" then
        ChooseCivic(actionParams);
    elseif actionType == "ChooseTech" then
        ChooseTech(actionParams);
    elseif actionType == "CityRangedAttack" then
        CityRangedAttack(actionParams[1]);
    elseif actionType == "EncampmentRangedAttack" then
        EncampmentRangedAttack(actionParams[1]);
    elseif actionType == "SendEnvoy" then
        SendEnvoy(actionParams);
    elseif actionType == "MakePeace" then
        MakePeaceWithCityState(actionParams[1]);
    elseif actionType == "LevyMilitary" then
        LevyMilitary(actionParams[1]);
    elseif actionType == "RecruitGreatPerson" then
        RecruitGreatPerson(actionParams[1]);
    elseif actionType == "RejectGreatPerson" then
        RejectGreatPerson(actionParams[1]);
    elseif actionType == "PatronizeGreatPersonGold" then
        PatronizeGreatPersonGold(actionParams[1]);
    elseif actionType == "PatronizeGreatPersonFaith" then
        PatronizeGreatPersonFaith(actionParams[1]);
    elseif actionType == "MoveUnit" then
        actionParams = {actionParams.UnitID, actionParams.X, actionParams.Y};
        MoveUnit(actionParams[1], actionParams[2], actionParams[3]);
    -- elseif actionType == "SelectUnit" then
    --     SelectUnit(actionParams[1])
    elseif actionType == "UnitRangedAttack" then
        UnitRangedAttack(actionParams[1], actionParams[2], actionParams[3]);
    elseif actionType == "UnitAirAttack" then
        UnitAirAttack(actionParams[1], actionParams[2]);
    -- elseif actionType == "FormUnit" then
    --     FormUnitFormation(actionParams[1], actionParams[2], actionParams[3]);
    -- elseif actionType == "RebaseUnit" then
    --     UnitRebase(actionParams[1], actionParams[2], actionParams[3]);
    elseif actionType == "FoundCity" then
        FoundCity(actionParams[1]);
    elseif actionType == "PromoteUnit" then
        actionParams = {actionParams.UnitID, actionParams.PromotionType};
        PromoteUnit(actionParams[1], actionParams[2]);
    elseif actionType == "DeleteUnit" then
        actionParams = {actionParams.UnitID};
        DeleteUnit(actionParams[1]);
    elseif actionType == "UpgradeUnit" then
        UpgradeUnit(actionParams[1]);
    elseif actionType == "ChangeGovernment" then
        ChangeGovernment(actionParams);
    elseif actionType == "ChangePolicies" then
        ChangePolicies(actionParams);
    elseif actionType == "FoundPantheon" then
      FoundPantheon(actionParams)
    elseif actionType == "SpreadReligion" then
      SpreadReligion(actionParams)
    elseif actionType == "EvangelizeBelief" then
      EvangelizeBelief(actionParams)
    elseif actionType == "FoundReligion" then
      FoundReligion(actionParams)
    elseif actionType == "EstablishTradeRoute" then
      return EstablishTradeRoute(actionParams);
    elseif actionType == "SendEnvoy" then
      return SendEnvoy(actionParams);
    elseif actionType == "HarvestResource" then
      HarvestResource(actionParams.UnitID)
    elseif actionType == "Fortify" then
      Fortify(actionParams.UnitID)
    elseif actionType == "BuildImprovement" then
        BuildImprovement(actionParams.UnitID, actionParams.ImprovementHash)
    elseif actionType == "AssignGovernorTitle" then
        if actionParams.IsInitialAppointment then
          AppointNewGovernor(actionParams)
        else
          AssignGovernorPromotion(actionParams)
        end
    elseif actionType == "AssignGovernorToCity" then
        AssignGovernorToCity(actionParams)
    elseif actionType == "AirAttack" then
        UnitAirAttack(actionParams.UnitID, actionParams.X, actionParams.Y)
    elseif actionType == "FormCorps" then
        FormCorps(actionParams.UnitID)
    elseif actionType == "RemoveFeature" then
        RemoveFeature(actionParams);
    elseif actionType == "FormArmy" then
        FormArmy(actionParams.UnitID)
    elseif actionType == "Wake" then
        WakeUnit(actionParams.UnitID)
    elseif actionType == "Repair" then
      RepairImprovement(actionParams.UnitID)
    elseif actionType == "EstablishTradeRoute" then
        EstablishTradeRoute(actionParams[1], actionParams[2]);
    elseif actionType == "PurchaseWithGold" then
        if actionParams.PurchaseType == "UNIT" then
            PurchaseUnit(actionParams.CityID, actionParams.TypeHash, "YIELD_GOLD")
        end
      elseif actionParams.PurchaseType == "BUILDING" then
            PurchaseBuilding(actionParams.CityID, actionParams.TypeHash, "YIELD_GOLD")
      elseif actionParams.PurchaseType == "DISTRICT" then
          PurchaseDistrict(actionParams.CityID, actionParams.TypeHash, "YIELD_GOLD", actionParams.PlotX, actionParams.PlotY)
      elseif actionType == "PurchaseWithFaith" then
        if actionParams.PurchaseType == "UNIT" then
            PurchaseUnit(actionParams.CityID, actionParams.TypeHash, "YIELD_FAITH")
        end
      elseif actionType == "ActivateGreatPerson" then
          ActivateGreatPerson(actionParams)
    elseif actionType == "CityProduction" then
        local cityID = actionParams.CityID
        local productionHash = actionParams.ProductionHash
        if actionParams.ProductionType == 'Districts' then
          local plotX = actionParams.PlotX
          local plotY = actionParams.PlotY
        PlaceDistrict(cityID, productionHash, plotX, plotY)
        else
        productionType = actionParams.ProductionType
        StartCityProduction(cityID, productionHash, productionType)
        end
    elseif actionType == "ChangePolicies" then
        for slot, policy in pairs(actionParams) do
            print(string.format("  Slot %s: %s", tostring(slot), tostring(policy)));
        end
    else
        print("RLv1: Unknown action type: " .. tostring(actionType));
        return false;
    end

    return true;
end


function RemoveFeature(params)
  -- Validate parameters
  if not params.UnitID then
      print("ERROR: Missing required UnitID parameter for RemoveFeature");
      return false;
  end

  local player = Players[Game.GetLocalPlayer()];
  if not player then return false; end

  local unit = player:GetUnits():FindID(params.UnitID);
  if not unit then
      print("ERROR: Could not find unit with ID " .. tostring(params.UnitID));
      return false;
  end

  -- Set up parameters for removing feature
  local tParameters = {};
  tParameters[UnitOperationTypes.PARAM_X] = unit:GetX();
  tParameters[UnitOperationTypes.PARAM_Y] = unit:GetY();

  -- Request the operation
  if UnitManager.CanStartOperation(unit, UnitOperationTypes.REMOVE_FEATURE, nil, tParameters) then
      UnitManager.RequestOperation(unit, UnitOperationTypes.REMOVE_FEATURE, tParameters);
      return true;
  end

  print("ERROR: Cannot remove feature at current location");
  return false;
end

function AppointNewGovernor(params)
  local tParameters = {}
  tParameters[PlayerOperations.PARAM_GOVERNOR_TYPE] = params.GovernorType
  return UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.APPOINT_GOVERNOR, tParameters)
end

function AssignGovernorPromotion(params)
  local tParameters = {}
  tParameters[PlayerOperations.PARAM_GOVERNOR_TYPE] = params.GovernorType
  tParameters[PlayerOperations.PARAM_GOVERNANCE_TYPE] = params.PromotionHash
  return UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.ASSIGN_GOVERNOR_PROMOTION, tParameters)
end

function AssignGovernorToCity(params)
  local tParameters = {}
  tParameters[PlayerOperations.PARAM_GOVERNOR_TYPE] = params.GovernorType
  tParameters[PlayerOperations.PARAM_PLAYER_ONE] = params.CityOwner
  tParameters[PlayerOperations.PARAM_CITY_DEST] = params.CityID
  return UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.ASSIGN_GOVERNOR, tParameters)
end


-- In civactionsRL.lua, update the EstablishTradeRoute function:

function EstablishTradeRoute(actionParams)
  print("Establishing trade route with parameters:")
  print("- Trader Unit ID: " .. tostring(actionParams.TraderUnitID))
  print("- Destination City: " .. tostring(actionParams.DestinationCityName))
  
  -- Get the trader unit
  local playerID = Game.GetLocalPlayer()
  local player = Players[playerID]
  local unit = player:GetUnits():FindID(actionParams.TraderUnitID)
  
  if not unit then
      print("ERROR: Could not find trader unit")
      return false
  end
  
  -- Get destination city 
  local destCity = Cities.GetCity(actionParams.DestinationPlayerID, actionParams.DestinationCityID)
  if not destCity then
      print("ERROR: Could not find destination city")
      return false
  end

  -- Set up parameters for the trade route
  local tParameters = {}
  tParameters[UnitOperationTypes.PARAM_X0] = destCity:GetX()
  tParameters[UnitOperationTypes.PARAM_Y0] = destCity:GetY()
  tParameters[UnitOperationTypes.PARAM_X1] = unit:GetX()
  tParameters[UnitOperationTypes.PARAM_Y1] = unit:GetY()

  -- Request the trade route operation
  if UnitManager.CanStartOperation(unit, UnitOperationTypes.MAKE_TRADE_ROUTE, nil, tParameters) then
      UnitManager.RequestOperation(unit, UnitOperationTypes.MAKE_TRADE_ROUTE, tParameters)
      print("Trade route establishment requested successfully")
      return true
  end

  print("ERROR: Cannot establish trade route")
  return false
end


function ActivateGreatPerson(actionParams)
  local unit = Players[Game.GetLocalPlayer()]:GetUnits():FindID(actionParams.UnitID)
  if unit then
      local tParameters = {}
      -- If a plot was specified, add plot parameters
      if actionParams.PlotIndex then
          local plot = Map.GetPlotByIndex(actionParams.PlotIndex)
          if plot then
              tParameters[UnitOperationTypes.PARAM_X] = plot:GetX()
              tParameters[UnitOperationTypes.PARAM_Y] = plot:GetY()
          end
      end

      -- Looking at the UnitCommands table data, we can see the Hash is 374670040
      -- for UNITCOMMAND_ACTIVATE_GREAT_PERSON
      local activateGPHash = 374670040

      if UnitManager.CanStartCommand(unit, activateGPHash, tParameters) then
          UnitManager.RequestCommand(unit, activateGPHash, tParameters)
          return true
      else
          print("Cannot activate great person at current location")
          return false
      end
  end
  return false
end
-- Purchase unit (standard formation)
function PurchaseUnit(cityID, unitHash, yieldType)
  local city = CityManager.GetCity(Game.GetLocalPlayer(), cityID)
  if not city then return end
  
  local tParameters = {}
  tParameters[CityCommandTypes.PARAM_UNIT_TYPE] = unitHash
  tParameters[CityCommandTypes.PARAM_MILITARY_FORMATION_TYPE] = MilitaryFormationTypes.STANDARD_MILITARY_FORMATION
  
  -- Set yield type based on parameter
  if yieldType == "YIELD_GOLD" then
      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index
  else
      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index
  end
  
  CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters)
end

-- Purchase building
function PurchaseBuilding(cityID, buildingHash, yieldType)
  local city = CityManager.GetCity(Game.GetLocalPlayer(), cityID)
  if not city then return end
  
  local tParameters = {}
  tParameters[CityCommandTypes.PARAM_BUILDING_TYPE] = buildingHash
  
  if yieldType == "YIELD_GOLD" then
      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index
  else
      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index
  end
  
  CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters)
end

-- Purchase district
function PurchaseDistrict(cityID, districtHash, yieldType, plotX, plotY)
  local city = CityManager.GetCity(Game.GetLocalPlayer(), cityID)
  if not city then return end
  
  local district = GameInfo.Districts[GameInfo.Hash2Type(districtHash)]
  if not district then return end
  
  local tParameters = {}
  tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtHash
  
  if yieldType == "YIELD_GOLD" then
      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index
  else
      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index
  end
  
  -- Add plot coordinates for placement
  if plotX and plotY then
      tParameters[CityOperationTypes.PARAM_X] = plotX
      tParameters[CityOperationTypes.PARAM_Y] = plotY
  end
  
  -- Check if district needs placement
  local bNeedsPlacement = district.RequiresPlacement
  local pBuildQueue = city:GetBuildQueue()
  
  if pBuildQueue:HasBeenPlaced(districtHash) then
      bNeedsPlacement = false
  end
  
  if bNeedsPlacement and not (plotX and plotY) then
      -- If needs placement but no coordinates provided, set interface mode
      UI.SetInterfaceMode(InterfaceModeTypes.DISTRICT_PLACEMENT, tParameters)
  else
      -- Direct purchase
      CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters)
  end
end

-- Corps/Army unit purchase functions for completeness
function PurchaseUnitCorps(cityID, unitHash, yieldType)
  local city = CityManager.GetCity(Game.GetLocalPlayer(), cityID)
  if not city then return end
  
  local tParameters = {}
  tParameters[CityCommandTypes.PARAM_UNIT_TYPE] = unitHash
  tParameters[CityCommandTypes.PARAM_MILITARY_FORMATION_TYPE] = MilitaryFormationTypes.CORPS_MILITARY_FORMATION
  
  if yieldType == "YIELD_GOLD" then
      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index
  else
      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index
  end
  
  CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters)
end

function PurchaseUnitArmy(cityID, unitHash, yieldType)
  local city = CityManager.GetCity(Game.GetLocalPlayer(), cityID)
  if not city then return end
  
  local tParameters = {}
  tParameters[CityCommandTypes.PARAM_UNIT_TYPE] = unitHash
  tParameters[CityCommandTypes.PARAM_MILITARY_FORMATION_TYPE] = MilitaryFormationTypes.ARMY_MILITARY_FORMATION
  
  if yieldType == "YIELD_GOLD" then
      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index
  else
      tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index
  end
  
  CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters)
end


function SpreadReligion(params)
  -- Validate parameters
  if not params.UnitID or not params.X or not params.Y then
      print("ERROR: Missing required parameters for SpreadReligion")  
      return false
  end

  local player = Players[Game.GetLocalPlayer()]
  if not player then return false end

  local unit = player:GetUnits():FindID(params.UnitID)
  if not unit then 
      print("ERROR: Could not find unit with ID " .. tostring(params.UnitID))
      return false 
  end

  -- Set up parameters for spreading religion
  local tParameters = {}
  tParameters[UnitOperationTypes.PARAM_X] = params.X
  tParameters[UnitOperationTypes.PARAM_Y] = params.Y

  -- Request the operation
  if UnitManager.CanStartOperation(unit, UnitOperationTypes.SPREAD_RELIGION, nil, tParameters) then
      UnitManager.RequestOperation(unit, UnitOperationTypes.SPREAD_RELIGION, tParameters)
      return true
  end

  return false
end

function EvangelizeBelief(params)
  -- Validate parameters
  if not params.UnitID or not params.BeliefHash then
      print("ERROR: Missing required parameters for EvangelizeBelief")
      return false
  end

  local player = Players[Game.GetLocalPlayer()]
  if not player then return false end

  local unit = player:GetUnits():FindID(params.UnitID)
  if not unit then 
      print("ERROR: Could not find unit with ID " .. tostring(params.UnitID))
      return false 
  end

  -- Set up parameters for evangelizing belief
  local tParameters = {}
  tParameters[UnitOperationTypes.PARAM_BELIEF_TYPE] = params.BeliefHash

  -- Request the operation
  if UnitManager.CanStartOperation(unit, UnitOperationTypes.EVANGELIZE_BELIEF, nil, tParameters) then
      UnitManager.RequestOperation(unit, UnitOperationTypes.EVANGELIZE_BELIEF, tParameters)
      return true
  end

  return false
end


function FoundPantheon(actionParams)
  local tParameters = {};
  tParameters[PlayerOperations.PARAM_BELIEF_TYPE] = actionParams;
  tParameters[PlayerOperations.PARAM_INSERT_MODE] = PlayerOperations.VALUE_EXCLUSIVE;
  UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.FOUND_PANTHEON, tParameters);

end


function FoundReligion(params)
  -- Validate required parameters
  if not params.UnitID or not params.ReligionHash or not params.BeliefHashes then
      print("ERROR: Missing required parameters for FoundReligion")
      return false
  end

  local player = Players[Game.GetLocalPlayer()]
  if not player then return false end

  local unit = player:GetUnits():FindID(params.UnitID)
  if not unit then 
      print("ERROR: Could not find unit with ID " .. tostring(params.UnitID))
      return false
  end

  -- Set up the parameters for founding religion
  local tParameters = {}
  tParameters[PlayerOperations.PARAM_RELIGION_TYPE] = params.ReligionHash
  tParameters[PlayerOperations.PARAM_INSERT_MODE] = PlayerOperations.VALUE_EXCLUSIVE
  local foundreligionhash = -953161477
  UnitManager.RequestOperation(unit, foundreligionhash , tParameters);
  -- Request the operation to found the religion
  UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.FOUND_RELIGION, tParameters)

  -- Add each belief
  for _, beliefHash in ipairs(params.BeliefHashes) do
      if beliefHash then -- Skip nil beliefs
          local beliefParameters = {}
          beliefParameters[PlayerOperations.PARAM_BELIEF_TYPE] = beliefHash
          beliefParameters[PlayerOperations.PARAM_INSERT_MODE] = PlayerOperations.VALUE_EXCLUSIVE
          UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.ADD_BELIEF, beliefParameters)
      end
  end

  return true
end
-- Ends the current turn.
-- @param force (optional) If true, forces end turn (Shift+Enter equivalent).
function EndTurn(force)
  if force then
    UI.RequestAction(ActionTypes.ACTION_ENDTURN, true);
  else
    UI.RequestAction(ActionTypes.ACTION_ENDTURN);
  end
end

function StartCityProduction(cityID, productionHash, productionType)
  local pCity = CityManager.GetCity(Game.GetLocalPlayer(), cityID)
  if not pCity then 
      print("City not found")
      return false 
  end
  print(string.format("Starting production in city %s: Type=%s, Hash=%s", 
    tostring(cityID),
    tostring(productionType),
    tostring(productionHash)))
  
  local tParameters = {}
  tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE
  
  -- Set the correct parameter type based on what we're producing
  if productionType == "Units" then
      tParameters[CityOperationTypes.PARAM_UNIT_TYPE] = productionHash
  elseif productionType == "Buildings" then
      tParameters[CityOperationTypes.PARAM_BUILDING_TYPE] = productionHash
  elseif productionType == "Districts" then
      print("ERROR, TYPE SHOULD NOT BE DISTRICTS FOR START CITY PRODUCTION FUNCTION. check execute actions")
      return true
  elseif productionType == "Projects" then
      tParameters[CityOperationTypes.PARAM_PROJECT_TYPE] = productionHash
  end
  
  -- All production types use the BUILD operation
  CityManager.RequestOperation(pCity, CityOperationTypes.BUILD, tParameters)
  return true
end
-- Chooses a civic to research.
-- @param civicName The name of the civic to research (e.g., "CIVIC_FOREIGN_TRADE").

function ChooseCivic(civicData)
  print("ChooseCivic: Attempting to research civic")
  if civicData == nil then
      print("ERROR: civicData is nil!")
      return false
  end
  
  print("CivicType: " .. tostring(civicData.CivicType))
  print("Hash: " .. tostring(civicData.Hash))
  
  local playerID = Game.GetLocalPlayer()
  local player = Players[playerID]
  local playerCulture = player:GetCulture()
  
  -- Parameters should use the civic hash
  local params = {}
  params[PlayerOperations.PARAM_CIVIC_TYPE] = civicData.Hash
  params[PlayerOperations.PARAM_INSERT_MODE] = PlayerOperations.VALUE_EXCLUSIVE
  
  -- Request the research
  print("Requesting civic research operation...")
  UI.RequestPlayerOperation(playerID, PlayerOperations.PROGRESS_CIVIC, params)
  
  -- Play civic selection sound
  UI.PlaySound("Confirm_Civic")
  return true
end

-- Chooses a technology to research.
-- @param techName The name of the technology to research (e.g., "TECH_POTTERY").
function ChooseTech(techData)
  print("ChooseTech: Attempting to research " .. techData.TechType)
  local playerID = Game.GetLocalPlayer()
  local player = Players[playerID]
  local playerTechs = player:GetTechs()

  -- Parameters should use the tech hash
  local params = {}
  params[PlayerOperations.PARAM_TECH_TYPE] = techData.Hash
  params[PlayerOperations.PARAM_INSERT_MODE] = PlayerOperations.VALUE_EXCLUSIVE
  
  -- Request the research
  UI.RequestPlayerOperation(playerID, PlayerOperations.RESEARCH, params)
  
  -- Play research selection sound
  UI.PlaySound("Confirm_Tech")
  return true
end


-- Performs a city ranged attack.
-- @param cityID The ID of the city performing the attack.
function CityRangedAttack(cityID)
  local playerID = Game.GetLocalPlayer();
  local player = Players[playerID];
  local attackCity = player:GetCities():FindID(cityID);

  if attackCity and CityManager.CanStartCommand(attackCity, CityCommandTypes.RANGE_ATTACK) then
    UI.LookAtPlot(attackCity:GetX(), attackCity:GetY());
    LuaEvents.CQUI_CityRangeStrike(playerID, attackCity:GetID()); -- Assuming you are using CQUI
    return true
  else
      print("City with ID " .. cityID .. " cannot perform ranged attack or does not exist.");
      return false;
  end
end

-- Performs an encampment ranged attack.
-- @param encampmentID The ID of the encampment district performing the attack.
function EncampmentRangedAttack(encampmentID)
  local playerID = Game.GetLocalPlayer();
  local player = Players[playerID];
  local attackEncampment = player:GetDistricts():FindID(encampmentID);

  if attackEncampment and CityManager.CanStartCommand(attackEncampment, CityCommandTypes.RANGE_ATTACK) then
    UI.LookAtPlot(attackEncampment:GetX(), attackEncampment:GetY());
    LuaEvents.CQUI_DistrictRangeStrike(playerID, attackEncampment:GetID()); -- Assuming you are using CQUI
    return true
  else
      print("Encampment with ID " .. encampmentID .. " cannot perform ranged attack or does not exist.");
      return false;
  end
end

-- Sends an envoy to a city-state.
-- @param cityStateName The name of the city-state (e.g., "CITY_STATE_ZANZIBAR").
function SendEnvoy(targetCityStateID)
  print("Sending envoy to city-state with ID: " .. targetCityStateID)
  local localPlayerID = Game.GetLocalPlayer()
  
  -- Set up parameters
  local parameters = {}
  parameters[PlayerOperations.PARAM_PLAYER_ONE] = targetCityStateID

  -- Request the operation
  UI.RequestPlayerOperation(localPlayerID, PlayerOperations.GIVE_INFLUENCE_TOKEN, parameters)
end

-- Makes peace with a city-state.
-- @param cityStateName The name of the city-state.
function MakePeaceWithCityState(cityStateName)
  local playerID = Game.GetLocalPlayer();
  local player = Players[playerID];
  local cityStateID = GameInfo.MinorCivs[cityStateName].Index;

  if not player:GetDiplomacy():CanMakePeaceWith(cityStateID) then
      print("Cannot make peace with " .. cityStateName);
      return false;
  end

  local parameters = {};
  parameters[PlayerOperations.PARAM_PLAYER_ONE] = playerID;
  parameters[PlayerOperations.PARAM_PLAYER_TWO] = cityStateID;
  UI.RequestPlayerOperation(playerID, PlayerOperations.DIPLOMACY_MAKE_PEACE, parameters);
  return true;
end

-- Levies the military of a city-state.
-- @param cityStateName The name of the city-state.
function LevyMilitary(cityStateName)
  local playerID = Game.GetLocalPlayer();
  local player = Players[playerID];
  local cityStateID = GameInfo.MinorCivs[cityStateName].Index;

  if not player:GetInfluence():CanLevyMilitary(cityStateID) then
      print("Cannot levy military of " .. cityStateName);
      return false;
  end

  local parameters = {};
  parameters[PlayerOperations.PARAM_PLAYER_ONE] = cityStateID;
  UI.RequestPlayerOperation(playerID, PlayerOperations.LEVY_MILITARY, parameters);
  return true;
end

-- Recruits a Great Person.
-- @param individualID The ID of the Great Person to recruit.
function RecruitGreatPerson(individualName)
  local playerID = Game.GetLocalPlayer();
  local individualID = GameInfo.GreatPersonIndividuals[individualName].Hash;

  if not Game.GetGreatPeople():CanRecruitPerson(playerID, individualID) then
      print("Cannot recruit Great Person " .. individualName);
      return false;
  end

  local parameters = {};
  parameters[PlayerOperations.PARAM_GREAT_PERSON_INDIVIDUAL_TYPE] = individualID;
  UI.RequestPlayerOperation(playerID, PlayerOperations.RECRUIT_GREAT_PERSON, parameters);
  return true
end

-- Rejects a Great Person.
-- @param individualID The ID of the Great Person to reject.
function RejectGreatPerson(individualName)
  local playerID = Game.GetLocalPlayer();
  local individualID = GameInfo.GreatPersonIndividuals[individualName].Hash;
  if not Game.GetGreatPeople():CanRejectPerson(playerID, individualID) then
      print("Cannot reject Great Person " .. individualName);
      return false;
  end

  local parameters = {};
  parameters[PlayerOperations.PARAM_GREAT_PERSON_INDIVIDUAL_TYPE] = individualID;
  UI.RequestPlayerOperation(playerID, PlayerOperations.REJECT_GREAT_PERSON, parameters);
  return true
end

-- Patronizes a Great Person with Gold.
-- @param individualID The ID of the Great Person to patronize.
function PatronizeGreatPersonGold(individualName)
  local playerID = Game.GetLocalPlayer();
  local individualID = GameInfo.GreatPersonIndividuals[individualName].Hash;

  if not Game.GetGreatPeople():CanPatronizePerson(playerID, individualID, YieldTypes.GOLD) then
      print("Cannot patronize Great Person " .. individualName .. " with Gold");
      return false;
  end

  local parameters = {};
  parameters[PlayerOperations.PARAM_GREAT_PERSON_INDIVIDUAL_TYPE] = individualID;
  parameters[PlayerOperations.PARAM_YIELD_TYPE] = YieldTypes.GOLD;
  UI.RequestPlayerOperation(playerID, PlayerOperations.PATRONIZE_GREAT_PERSON, parameters);
  return true
end

-- Patronizes a Great Person with Faith.
-- @param individualID The ID of the Great Person to patronize.
function PatronizeGreatPersonFaith(individualName)
  local playerID = Game.GetLocalPlayer();
  local individualID = GameInfo.GreatPersonIndividuals[individualName].Hash;
    if not Game.GetGreatPeople():CanPatronizePerson(playerID, individualID, YieldTypes.FAITH) then
      print("Cannot patronize Great Person " .. individualName .. " with Faith");
      return false;
  end
  local parameters = {};
  parameters[PlayerOperations.PARAM_GREAT_PERSON_INDIVIDUAL_TYPE] = individualID;
  parameters[PlayerOperations.PARAM_YIELD_TYPE] = YieldTypes.FAITH;
  UI.RequestPlayerOperation(playerID, PlayerOperations.PATRONIZE_GREAT_PERSON, parameters);
  return true
end

-- Moves a unit to a specific plot.
-- @param unitID The ID of the unit to move.
-- @param plotX The X coordinate of the target plot.
-- @param plotY The Y coordinate of the target plot.
function MoveUnit(unitID, plotX, plotY)
  local playerID = Game.GetLocalPlayer()
  local player = Players[playerID];
  local unit = player:GetUnits():FindID(unitID);
  
  if unit == nil then 
      print("Unit with ID " .. unitID .. " not found.");
      return false
  end

  local tParameters = {};
  tParameters[UnitOperationTypes.PARAM_X] = plotX;
  tParameters[UnitOperationTypes.PARAM_Y] = plotY;

  -- Check if unit can move to target plot
  if UnitManager.CanStartOperation(unit, UnitOperationTypes.MOVE_TO, nil, tParameters) then
      UnitManager.RequestOperation(unit, UnitOperationTypes.MOVE_TO, tParameters);
      return true;
  else
      print("Unit cannot move to specified plot X:" .. tostring(plotX) .. " Y:" .. tostring(plotY));
      return false;
  end
end

-- Selects a unit
-- @param unitID The ID of the unit to select.
function SelectUnit(unitID)
    local playerID = Game.GetLocalPlayer()
    local player = Players[playerID];
    local unit = player:GetUnits():FindID(unitID);
    if unit then
        UI.SelectUnit(unit);
        return true
    else
        print("Unit with ID " .. unitID .. " not found.");
        return false
    end
end

-- Performs a unit ranged attack on a target plot.
-- @param unitID The ID of the unit performing the attack.
-- @param targetPlotX The X coordinate of the target plot.
-- @param targetPlotY The Y coordinate of the target plot.
function UnitRangeAttack(unit, targetPlotID) 
  local tParameters = {};
  tParameters[UnitOperationTypes.PARAM_X] = Map.GetPlotByIndex(targetPlotID):GetX();
  tParameters[UnitOperationTypes.PARAM_Y] = Map.GetPlotByIndex(targetPlotID):GetY();

  if UnitManager.CanStartOperation(unit, UnitOperationTypes.RANGE_ATTACK, nil, tParameters) then
      UnitManager.RequestOperation(unit, UnitOperationTypes.RANGE_ATTACK, tParameters);
      return true;
  end
  return false;
end

-- Performs a unit air attack on a target plot.
-- @param unitID The ID of the unit performing the attack.
-- @param targetPlotX The X coordinate of the target plot.
-- @param targetPlotY The Y coordinate of the target plot.
function UnitAirAttack(unit, targetPlotID)
  local tParameters = {};
  tParameters[UnitOperationTypes.PARAM_X] = Map.GetPlotByIndex(targetPlotID):GetX();
  tParameters[UnitOperationTypes.PARAM_Y] = Map.GetPlotByIndex(targetPlotID):GetY();

  if UnitManager.CanStartOperation(unit, UnitOperationTypes.AIR_ATTACK, nil, tParameters) then
      UnitManager.RequestOperation(unit, UnitOperationTypes.AIR_ATTACK, tParameters);
      return true;
  end
  return false;
end


function HarvestResource(unitID)
  local unit = GetUnit(Game.GetLocalPlayer(), unitID)
  if unit then
      return UnitManager.RequestOperation(unit, UnitOperationTypes.HARVEST_RESOURCE)
  end
  return false
end

function Fortify(unitID)
  local unit = GetUnit(Game.GetLocalPlayer(), unitID)
  if unit then
      return UnitManager.RequestOperation(unit, UnitOperationTypes.FORTIFY)
  end
  return false
end

function BuildImprovement(unitID, improvementHash)
  local unit = GetUnit(Game.GetLocalPlayer(), unitID)
  if unit then
      local tParameters = {}
      tParameters[UnitOperationTypes.PARAM_IMPROVEMENT_TYPE] = improvementHash
      return UnitManager.RequestOperation(unit, UnitOperationTypes.BUILD_IMPROVEMENT, tParameters)
  end
  return false
end

function FormCorps(unitID)
  local unit = GetUnit(Game.GetLocalPlayer(), unitID)
  if unit then
      return UnitManager.RequestCommand(unit, UnitCommandTypes.FORM_CORPS)
  end
  return false
end

function FormArmy(unitID)
  local unit = GetUnit(Game.GetLocalPlayer(), unitID)
  if unit then
      return UnitManager.RequestCommand(unit, UnitCommandTypes.FORM_ARMY)
  end
  return false
end

function WakeUnit(unitID)
  local unit = GetUnit(Game.GetLocalPlayer(), unitID)
  if unit then
      return UnitManager.RequestCommand(unit, UnitCommandTypes.WAKE)
  end
  return false
end

function RepairImprovement(unitID)
  local unit = GetUnit(Game.GetLocalPlayer(), unitID)
  if unit then
      return UnitManager.RequestOperation(unit, UnitOperationTypes.REPAIR)
  end
  return false
end


-- Requests a settler to found a city
-- @param unit The settler unit
function RequestFoundCity(unit)
  if unit:GetUnitType() ~= GameInfo.Units["UNIT_SETTLER"].Index then
      print("Unit must be a settler to found city");
      return false;
  end
  
  if UnitManager.CanStartOperation(unit, UnitOperationTypes.FOUND_CITY, nil) then
      UnitManager.RequestOperation(unit, UnitOperationTypes.FOUND_CITY);
      return true;
  end
  print("Cannot found city at current location");
  return false;
end

-- Founds a city with a unit.
-- @param unitID The ID of the unit (e.g., Settler).
function FoundCity(unitID)
  local playerID = Game.GetLocalPlayer();
  local player = Players[playerID];
  local unit = player:GetUnits():FindID(unitID);
    if unit == nil then
      print("Unit with ID " .. unitID .. " not found.");
      return false;
  end
  return RequestFoundCity(unit);
end

-- Promotes a unit.
-- @param unitID The ID of the unit to promote.
-- @param promotionName The name of the promotion (e.g., "PROMOTION_BATTLECRY").
function PromoteUnit(unitID, promotionName)
  local playerID = Game.GetLocalPlayer();
  local player = Players[playerID];
  local unit = player:GetUnits():FindID(unitID);
    if unit == nil then
      print("Unit with ID " .. unitID .. " not found.");
      return false;
  end
  local promotionHash = GameInfo.UnitPromotions[promotionName].Hash;
  return RequestPromoteUnit(unit, promotionHash);
end

-- Deletes a unit (with confirmation).
-- @param unitID The ID of the unit to delete.
-- Deletes a unit (without confirmation).
-- @param unitID The ID of the unit to delete.
function DeleteUnit(unitID)
  local playerID = Game.GetLocalPlayer();
  local player = Players[playerID];
  local unit = player:GetUnits():FindID(unitID);
  if unit == nil then
      print("Unit with ID " .. unitID .. " not found.");
      return false;
  end
  
  -- Directly request delete command instead of using prompt
  if UnitManager.CanStartCommand(unit, UnitCommandTypes.DELETE) then
      UnitManager.RequestCommand(unit, UnitCommandTypes.DELETE);
      return true;
  end
  return false;
end

-- Upgrades a unit.
-- @param unitID The ID of the unit to upgrade.
function UpgradeUnit(unitID)
  local playerID = Game.GetLocalPlayer();
  local player = Players[playerID];
  local unit = player:GetUnits():FindID(unitID);
    if unit == nil then
      print("Unit with ID " .. unitID .. " not found.");
      return false;
  end
  return RequestUnitUpgrade(unit);
end

-- Changes the current government.
-- @param government Hash of the govt you want
function ChangeGovernment(governmentHash)
  local playerID = Game.GetLocalPlayer();
  local player = Players[playerID];
  local playerCulture = player:GetCulture();


  if not playerCulture:IsGovernmentUnlocked(governmentHash) then
      print("Government " .. governmentName .. " is not unlocked.");
      return false;
  end

  if not CanChangeGovernment() then
      print("Cannot change government at this time.");
      return false;
  end

  playerCulture:RequestChangeGovernment(governmentHash);
  return true
end

-- Changes policy cards.
-- @param policyChanges A table where keys are slot indices and values are policy names.
-- In ChangePolicies(), modify to handle indexed array parameters correctly:
-- In civactionsRL.lua, modify the ChangePolicies function:

function ChangePolicies(params)
  print("Attempting to change policies...");
  
  local playerID = Game.GetLocalPlayer();
  if playerID == -1 then return false end
  
  local slotIndex = params.SlotIndex;
  local policyHash = params.PolicyHash;
  
  print("Changing policy - Slot: " .. tostring(slotIndex) .. ", Policy: " .. params.PolicyType);

  -- Create lists for policy changes
  local clearList = {slotIndex};  -- List of slots to clear
  local addList = {};  -- New policies to add, keyed by slot index
  addList[slotIndex] = policyHash;

  -- Get player culture object
  local player = Players[playerID];
  local playerCulture = player:GetCulture();

  -- Request the policy changes
  playerCulture:RequestPolicyChanges(clearList, addList);
  
  UI.PlaySound("Play_UI_Click");
  return true;
end


function PlaceDistrict(cityID, districtHash, plotX, plotY)
  print("PlaceDistrict called with params - cityID: " .. tostring(cityID) .. 
        ", districtHash: " .. tostring(districtHash) .. 
        ", plotX: " .. tostring(plotX) .. 
        ", plotY: " .. tostring(plotY))

  local pCity = CityManager.GetCity(Game.GetLocalPlayer(), cityID)
  if not pCity then 
    print("ERROR: Could not get city object for cityID: " .. tostring(cityID))
    return false 
  end
  print("Successfully got city object: " .. pCity:GetName())

  -- First check if we can actually produce this district
  local buildQueue = pCity:GetBuildQueue()
  if not buildQueue then
    print("ERROR: Could not get build queue for city")
    return false
  end
  print("Successfully got build queue")

  -- Check if district can be produced
  local canProduce = buildQueue:CanProduce(districtHash, true)
  print("Can produce district check result: " .. tostring(canProduce))
  if not canProduce then
    print("ERROR: City cannot produce this district")
    return false
  end

  -- Set up parameters for district placement
  local tParameters = {}
  tParameters[CityOperationTypes.PARAM_X] = plotX
  tParameters[CityOperationTypes.PARAM_Y] = plotY
  tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtHash
  
  print("Attempting to place district with parameters:")
  print("- PARAM_X: " .. tostring(tParameters[CityOperationTypes.PARAM_X]))
  print("- PARAM_Y: " .. tostring(tParameters[CityOperationTypes.PARAM_Y]))
  print("- PARAM_DISTRICT_TYPE: " .. tostring(tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE]))

  -- Get plot to verify it exists and is valid
  local plot = Map.GetPlot(plotX, plotY)
  if not plot then
    print("ERROR: Invalid plot coordinates")
    return false
  end
  print("Plot exists at specified coordinates")

  -- Verify plot can have district
  -- Note: We need to use the district's Index, not Hash, for CanHaveDistrict
  local districtIndex = GameInfo.Districts[districtHash].Index
  if not plot:CanHaveDistrict(districtIndex, Game.GetLocalPlayer(), cityID) then
    print("ERROR: District cannot be placed on this plot")
    return false
  end
  print("Plot can have district")

  -- Request the build operation
  print("Requesting district build operation...")
  local success = CityManager.RequestOperation(pCity, CityOperationTypes.BUILD, tParameters)
  print("Build operation request result: " .. tostring(success))

  return success
end

-- Establishes a trade route between two cities.
-- @param originCityID The ID of the origin city.
-- @param destinationCityID The ID of the destination city.
function EstablishTradeRoute(actionParams)
  print("Establishing trade route with parameters:")
  print("- Trader Unit ID: " .. tostring(actionParams.TraderUnitID))
  print("- Destination City: " .. tostring(actionParams.DestinationCityName))
  
  -- Get the trader unit directly using the ID
  local player = Players[Game.GetLocalPlayer()]
  local unit = player:GetUnits():FindID(actionParams.TraderUnitID)
  
  if not unit then
      print("ERROR: Could not find trader unit")
      return false
  end
  
  -- Get destination city using the player's city list
  local destPlayer = Players[actionParams.DestinationPlayerID]
  local destCity = destPlayer:GetCities():FindID(actionParams.DestinationCityID)
  if not destCity then
      print("ERROR: Could not find destination city")
      return false
  end

  -- Set up parameters for the trade route
  local tParameters = {}
  tParameters[UnitOperationTypes.PARAM_X0] = destCity:GetX()
  tParameters[UnitOperationTypes.PARAM_Y0] = destCity:GetY()
  tParameters[UnitOperationTypes.PARAM_X1] = unit:GetX()
  tParameters[UnitOperationTypes.PARAM_Y1] = unit:GetY()

  -- Request the trade route operation
  if UnitManager.CanStartOperation(unit, UnitOperationTypes.MAKE_TRADE_ROUTE, nil, tParameters) then
      UnitManager.RequestOperation(unit, UnitOperationTypes.MAKE_TRADE_ROUTE, tParameters)
      print("Trade route establishment requested successfully")
      return true
  end

  print("ERROR: Cannot establish trade route")
  return false
end

--------------------------------------------------
-- UTILITY FUNCTIONS (Place in Civ6Common.lua if you prefer)
--------------------------------------------------

function GetSelectedUnit()
  return UI.GetHeadSelectedUnit();
end

function GetFirstReadyUnit(playerID)
  local pPlayer = Players[playerID];
  if pPlayer then
    return pPlayer:GetUnits():GetFirstReadyUnit();
  end
  return nil;
end

function GetUnit(playerID, unitID)
  return Players[playerID]:GetUnits():FindID(unitID);
end

function GetUnitsInPlot(x, y)
  return Units.GetUnitsInPlotLayerID(x, y, MapLayers.ANY);
end

function GetCityInPlot(plotX, plotY)
  return Cities.GetCityInPlot(plotX, plotY);
end

function GetCity(playerID, cityID)
  local pPlayer = Players[playerID];
  if pPlayer then
    return pPlayer:GetCities():FindID(cityID);
  end
  return nil;
end

function GetDistrictFromCity(pCity)
  if pCity ~= nil then
    local cityOwner = pCity:GetOwner();
    local districtId = pCity:GetDistrictID();
    local pPlayer = Players[cityOwner];
    if pPlayer ~= nil then
      local pDistrict = pPlayer:GetDistricts():FindID(districtId);
      if pDistrict ~= nil then
        return pDistrict;
      end
    end
  end
  return nil;
end

function GetPlotByIndex(plotID)
  if Map.IsPlot(plotID) then
    return Map.GetPlotByIndex(plotID);
  end
  return nil;
end

function GetPlot(x, y)
  return Map.GetPlot(x, y);
end

function GetPlotOwner(plot)
  if plot:IsOwned() then
    return plot:GetOwner();
  end
  return -1;
end

function GetLocalPlayer()
  return Game.GetLocalPlayer();
end



function CanChangeGovernment()
    local playerID = Game.GetLocalPlayer()
    local player = Players[playerID]
    local playerCulture = player:GetCulture()
    
    if playerCulture:CanChangeGovernmentAtAll() and
       not playerCulture:GovernmentChangeMade() and
       Game.IsAllowStrategicCommands(playerID) then
        return true
    end
    return false
end

function CanChangePolicies()
    local playerID = Game.GetLocalPlayer()
    local player = Players[playerID]
    local playerCulture = player:GetCulture()
    
    if (playerCulture:CivicCompletedThisTurn() or 
        playerCulture:GetNumPolicySlotsOpen() > 0) and
        Game.IsAllowStrategicCommands(playerID) and 
        playerCulture:PolicyChangeMade() == false then
        return true
    end
    return false
end


-- Requests a unit promotion
-- @param unit The unit to promote
-- @param promotionHash The hash of the promotion type
function RequestPromoteUnit(unit, promotionHash)
  if not unit:GetExperience():CanPromote() then
      print("Unit cannot be promoted");
      return false;
  end
  
  local tParameters = {};
  tParameters[UnitCommandTypes.PARAM_PROMOTION_TYPE] = promotionHash;
  
  if UnitManager.CanStartCommand(unit, UnitCommandTypes.PROMOTE, nil, tParameters) then
      UnitManager.RequestCommand(unit, UnitCommandTypes.PROMOTE, tParameters);
      return true;
  end
  print("Cannot apply selected promotion to unit");
  return false;
end

-- Requests a unit upgrade
-- @param unit The unit to upgrade

function RequestUnitUpgrade(unit)
  -- Basic validation first
  if not UnitManager.CanStartCommand(unit, UnitCommandTypes.UPGRADE, true) then
      print("Unit cannot be upgraded");
      return false;
  end
  
  -- Get upgrade cost and check if player can afford it
  local playerID = unit:GetOwner();
  local player = Players[playerID];
  local upgradeCost = unit:GetUpgradeCost();
  
  if player:GetTreasury():GetGoldBalance() < upgradeCost then
      print("Cannot afford unit upgrade. Cost: " .. upgradeCost);
      return false;
  end  -- Changed from } to end
  
  -- Request the upgrade
  if UnitManager.CanStartCommand(unit, UnitCommandTypes.UPGRADE) then
      UnitManager.RequestCommand(unit, UnitCommandTypes.UPGRADE);
      return true;
  end
  print("Cannot upgrade unit");
  return false;
end

-- Add the functions from Civ6Common.lua here if you are not including the file directly.
-- ... (QueueUnitMovement, UnitRangeAttack, UnitAirAttack, etc.)

-- Example usage (you can test these in the console):
-- EndTurn();
-- ChooseCivic("CIVIC_GAMES_RECREATION");
-- ChooseTech("TECH_IRRIGATION");
-- MoveUnit(123, 10, 15); -- Replace with actual unit ID and plot coordinates
-- CityRangedAttack(45);
-- EncampmentRangedAttack(67);
-- SendEnvoy("CITY_STATE_HATTUSA");
-- MakePeaceWithCityState("CITY_STATE_KABUL");
-- LevyMilitary("CITY_STATE_NAN_MADOL");
-- RecruitGreatPerson("GREAT_PERSON_INDIVIDUAL_EUCLID");
-- RejectGreatPerson("GREAT_PERSON_INDIVIDUAL_HYPATIA");
-- PatronizeGreatPersonGold("GREAT_PERSON_INDIVIDUAL_IMHOTEP");
-- PatronizeGreatPersonFaith("GREAT_PERSON_INDIVIDUAL_ZHANG_HENG");
-- EstablishTradeRoute(1, 2)
-- PromoteUnit(1, "PROMOTION_ZEALOT")

--to indicate successful load
return True
