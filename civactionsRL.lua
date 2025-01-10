-- civ6_agent_actions.lua
if not ContextPtr then
  ContextPtr = {};
end
-- Include necessary game files (assuming they are in the same directory or a known path)
include("Civ6Common"); -- Make sure this path matches your file structure.
include("InstanceManager");
include( "SupportFunctions" );
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
        ChooseCivic(actionParams[1]);
    elseif actionType == "ChooseTech" then
        ChooseTech(actionParams[1]);
    elseif actionType == "CityRangedAttack" then
        CityRangedAttack(actionParams[1]);
    elseif actionType == "EncampmentRangedAttack" then
        EncampmentRangedAttack(actionParams[1]);
    elseif actionType == "SendEnvoy" then
        SendEnvoy(actionParams[1]);
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
        MoveUnit(actionParams[1], actionParams[2], actionParams[3]);
    elseif actionType == "SelectUnit" then
        SelectUnit(actionParams[1])
    elseif actionType == "UnitRangedAttack" then
        UnitRangedAttack(actionParams[1], actionParams[2], actionParams[3]);
    elseif actionType == "UnitAirAttack" then
        UnitAirAttack(actionParams[1], actionParams[2], actionParams[3]);
    elseif actionType == "FormUnit" then
        FormUnitFormation(actionParams[1], actionParams[2], actionParams[3]);
    elseif actionType == "RebaseUnit" then
        UnitRebase(actionParams[1], actionParams[2], actionParams[3]);
    elseif actionType == "WMDStrike" then
        UnitWMDStrike(actionParams[1], actionParams[2], actionParams[3], actionParams[4]);
    elseif actionType == "QueueUnitPath" then
        QueueUnitPath(actionParams[1], actionParams[2], actionParams[3]);
    elseif actionType == "BuildImprovement" then
        BuildImprovement(actionParams[1], actionParams[2]);
    elseif actionType == "EnterFormation" then
        EnterFormation(actionParams[1], actionParams[2]);
    elseif actionType == "FoundCity" then
        FoundCity(actionParams[1]);
    elseif actionType == "PromoteUnit" then
        PromoteUnit(actionParams[1], actionParams[2]);
    elseif actionType == "DeleteUnit" then
        DeleteUnit(actionParams[1]);
    elseif actionType == "UpgradeUnit" then
        UpgradeUnit(actionParams[1]);
    elseif actionType == "ChangeGovernment" then
        ChangeGovernment(actionParams);
    elseif actionType == "ChangePolicies" then
        ChangePolicies(actionParams);
    elseif actionType == "EstablishTradeRoute" then
        EstablishTradeRoute(actionParams[1], actionParams[2]);
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
function SendEnvoy(cityStateName)
    local playerID = Game.GetLocalPlayer();
    local player = Players[playerID];
    local influence = player:GetInfluence();
    
    if not influence:CanGiveInfluence() then
        print("Player cannot give influence at this time.");
        return false;
    end

    local cityStateID = GameInfo.MinorCivs[cityStateName].Index;

    if not influence:CanGiveTokensToPlayer(cityStateID) then
        print("Cannot send envoy to " .. cityStateName);
        return false;
    end

    local parameters = {};
    parameters[PlayerOperations.PARAM_PLAYER_ONE] = cityStateID;
    UI.RequestPlayerOperation(playerID, PlayerOperations.GIVE_INFLUENCE_TOKEN, parameters);
    return true;
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

-- Forms a unit into a corps or army.
-- @param unitID The ID of the unit forming up.
-- @param targetUnitID The ID of the unit to join.
-- @param formationType "CORPS" or "ARMY".
-- Fix recursive call in FormUnitFormation
function FormUnitFormation(unit, targetUnit, formationType)
  local tParameters = {};
  tParameters[UnitCommandTypes.PARAM_UNIT_PLAYER] = targetUnit:GetOwner();
  tParameters[UnitCommandTypes.PARAM_UNIT_ID] = targetUnit:GetID();
  
  local operationType = (formationType == "CORPS") and 
      UnitCommandTypes.FORM_CORPS or UnitCommandTypes.FORM_ARMY;
  
  if UnitManager.CanStartCommand(unit, operationType, tParameters) then
      UnitManager.RequestCommand(unit, operationType, tParameters);
      return true;
  end
  return false;
end

-- Rebase a unit to a target plot.
-- @param unitID The ID of the unit to rebase.
-- @param targetPlotX The X coordinate of the target plot.
-- @param targetPlotY The Y coordinate of the target plot.
function UnitRebase(unitID, targetPlotX, targetPlotY)
  local playerID = Game.GetLocalPlayer();
  local player = Players[playerID];
  local unit = player:GetUnits():FindID(unitID);
    if unit == nil then
      print("Unit with ID " .. unitID .. " not found.");
      return false;
  end
  local targetPlot = Map.GetPlot(targetPlotX, targetPlotY);
    if not targetPlot then
      print("Invalid target plot coordinates.");
      return false;
  end
  return UnitRebase(unit, targetPlot:GetIndex());
end

-- Performs a nuclear strike on a target plot.
-- @param unitID The ID of the unit performing the strike.
-- @param targetPlotX The X coordinate of the target plot.
-- @param targetPlotY The Y coordinate of the target plot.
-- @param wmdType The type of WMD (e.g., "WMD_NUCLEAR").
function UnitWMDStrike(unitID, targetPlotX, targetPlotY, wmdType)
  local playerID = Game.GetLocalPlayer();
  local player = Players[playerID];
  local unit = player:GetUnits():FindID(unitID);
    if unit == nil then
      print("Unit with ID " .. unitID .. " not found.");
      return false;
  end
  local targetPlot = Map.GetPlot(targetPlotX, targetPlotY);
    if not targetPlot then
      print("Invalid target plot coordinates.");
      return false;
  end
  return UnitWMDStrike(unit, targetPlot:GetIndex(), GameInfo.UnitWmdTypes[wmdType].Hash);
end

-- Queues a unit path to a target plot.
-- @param unitID The ID of the unit.
-- @param targetPlotX The X coordinate of the target plot.
-- @param targetPlotY The Y coordinate of the target plot.
function QueueUnitPath(unitID, targetPlotX, targetPlotY)
  local playerID = Game.GetLocalPlayer();
  local player = Players[playerID];
  local unit = player:GetUnits():FindID(unitID);
    if unit == nil then
      print("Unit with ID " .. unitID .. " not found.");
      return false;
  end
  local targetPlot = Map.GetPlot(targetPlotX, targetPlotY);
    if not targetPlot then
      print("Invalid target plot coordinates.");
      return false;
  end
  return QueueUnitPath(unit, targetPlot:GetIndex());
end

-- Builds an improvement with a unit.
-- @param unitID The ID of the unit (e.g., Builder).
-- @param improvementName The name of the improvement (e.g., "IMPROVEMENT_FARM").
function BuildImprovement(unitID, improvementName)
  local playerID = Game.GetLocalPlayer();
  local player = Players[playerID];
  local unit = player:GetUnits():FindID(unitID);
    if unit == nil then
      print("Unit with ID " .. unitID .. " not found.");
      return false;
  end
  return RequestBuildImprovement(unit, GameInfo.Improvements[improvementName].Hash);
end

-- Enters a unit into a formation with another unit.
-- @param unitID The ID of the unit entering the formation.
-- @param targetUnitID The ID of the unit to form with.
function EnterFormation(unitID, targetUnitID)
  local playerID = Game.GetLocalPlayer();
  local player = Players[playerID];
  local unit = player:GetUnits():FindID(unitID);
  local targetUnit = player:GetUnits():FindID(targetUnitID);
    if unit == nil then
      print("Unit with ID " .. unitID .. " not found.");
      return false;
  end
    if targetUnit == nil then
      print("Unit with ID " .. targetUnitID .. " not found.");
      return false;
  end
  return RequestEnterFormation(unit, targetUnit);
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
  local pCity = CityManager.GetCity(Game.GetLocalPlayer(), cityID)
  if not pCity then return false end
  
  -- First check if we can actually produce this district
  local buildQueue = pCity:GetBuildQueue()
  if not buildQueue:CanProduce(districtHash, true) then
    return false
  end

  -- Set up parameters for district placement
  local tParameters = {}
  tParameters[CityOperationTypes.PARAM_X] = plotX
  tParameters[CityOperationTypes.PARAM_Y] = plotY
  tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtHash
  
  -- Request the build operation
  CityManager.RequestOperation(pCity, CityOperationTypes.BUILD, tParameters)
  return true
end

-- Establishes a trade route between two cities.
-- @param originCityID The ID of the origin city.
-- @param destinationCityID The ID of the destination city.
function EstablishTradeRoute(originCityID, destinationCityID)
  local playerID = Game.GetLocalPlayer();
  local player = Players[playerID];
    local originCity = player:GetCities():FindID(originCityID);
    local destinationCity = player:GetCities():FindID(destinationCityID);
    if not originCity then
        print("Origin city with ID " .. originCityID .. " not found.");
        return false;
    end
    if not destinationCity then
        print("Destination city with ID " .. destinationCityID .. " not found.");
        return false;
    end
    local traderUnit = GetTraderInCity(originCity)
    if not traderUnit then
        print("No available trader in the origin city.");
        return false
    end
    
    UI.SelectUnit(traderUnit)
    
    local params = {}
    params[UnitOperationTypes.PARAM_X0] = destinationCity:GetX()
    params[UnitOperationTypes.PARAM_Y0] = destinationCity:GetY()
    params[UnitOperationTypes.PARAM_X1] = traderUnit:GetX() 
    params[UnitOperationTypes.PARAM_Y1] = traderUnit:GetY()
    
    return UnitManager.RequestOperation(traderUnit, UnitOperationTypes.MAKE_TRADE_ROUTE, params)
end

-- Helper function to find trader in city
function GetTraderInCity(city)
    local units = city:GetUnits()
    for i, unit in units:Members() do
        if unit:GetUnitType() == GameInfo.Units["UNIT_TRADER"].Index then
            return unit
        end
    end
    return nil
end
-- Example usage for policy changes:
-- local policyChanges = {
--   [0] = "POLICY_AGOGE",        -- Military slot 0
--   [2] = "POLICY_CARAVANSARIES" -- Economic slot 2
-- }
-- ChangePolicies(policyChanges);

--[[ Add more action functions here, such as:
    - Constructing districts/buildings (more complex, requires production queue handling).
    - Researching along a specific path (requires more sophisticated logic).
    - Declaring war.
    - Making peace.
    - ...
--]]

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

function GetPlayerVisibility(playerID)
  return PlayersVisibility[playerID];
end

function GetPlayerColors(playerID)
  return UI.GetPlayerColors(playerID);
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


function QueueUnitPath(unit, targetPlotID)
  local plot = Map.GetPlotByIndex(targetPlotID);
  local tParameters = {};
  tParameters[UnitOperationTypes.PARAM_X] = plot:GetX();
  tParameters[UnitOperationTypes.PARAM_Y] = plot:GetY();
  
  if UnitManager.CanStartOperation(unit, UnitOperationTypes.MOVE_TO, nil, tParameters) then
      UnitManager.RequestOperation(unit, UnitOperationTypes.MOVE_TO, tParameters);
      return true;
  end
  return false;
end


-- Requests a unit to build an improvement
-- @param unit The unit object
-- @param improvementHash The hash of the improvement type
function RequestBuildImprovement(unit, improvementHash)
  local tParameters = {};
  tParameters[UnitOperationTypes.PARAM_IMPROVEMENT_TYPE] = improvementHash;
  tParameters[UnitOperationTypes.PARAM_X] = unit:GetX();
  tParameters[UnitOperationTypes.PARAM_Y] = unit:GetY();
  
  if UnitManager.CanStartOperation(unit, UnitOperationTypes.BUILD_IMPROVEMENT, nil, tParameters) then
      UnitManager.RequestOperation(unit, UnitOperationTypes.BUILD_IMPROVEMENT, tParameters);
      return true;
  end
  print("Cannot build improvement at current location");
  return false;
end

-- Requests a unit to enter formation with another unit
-- @param unit The unit entering formation
-- @param targetUnit The unit to form up with
function RequestEnterFormation(unit, targetUnit)
  local tParameters = {};
  tParameters[UnitCommandTypes.PARAM_UNIT_PLAYER] = targetUnit:GetOwner();
  tParameters[UnitCommandTypes.PARAM_UNIT_ID] = targetUnit:GetID();
  
  if UnitManager.CanStartCommand(unit, UnitCommandTypes.ENTER_FORMATION, nil, tParameters) then
      UnitManager.RequestCommand(unit, UnitCommandTypes.ENTER_FORMATION, tParameters);
      return true;
  end
  print("Cannot enter formation with target unit");
  return false;
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
