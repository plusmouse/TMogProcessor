INVENTORY_TYPES_TO_SLOT = {
["INVTYPE_AMMO"] = {0},
["INVTYPE_HEAD"] = {1},
["INVTYPE_NECK"] = {2},
["INVTYPE_SHOULDER"] = {3},
["INVTYPE_BODY"] = {4},
["INVTYPE_CHEST"] = {5},
["INVTYPE_ROBE"] = {5},
["INVTYPE_WAIST"] = {6},
["INVTYPE_LEGS"] = {7},
["INVTYPE_FEET"] = {8},
["INVTYPE_WRIST"] = {9},
["INVTYPE_HAND"] = {10},
--["INVTYPE_FINGER"] = {11,12},
--["INVTYPE_TRINKET"] = {13,14},
["INVTYPE_CLOAK"] = {15},
["INVTYPE_WEAPON"] = {16,17},
["INVTYPE_SHIELD"] = {17},
["INVTYPE_2HWEAPON"] = {16},
["INVTYPE_WEAPONMAINHAND"] = {16},
["INVTYPE_WEAPONOFFHAND"] = {17},
["INVTYPE_HOLDABLE"] = {17},
["INVTYPE_RANGED"] = {18},
["INVTYPE_THROWN"] = {18},
["INVTYPE_RANGEDRIGHT"] = {18},
["INVTYPE_RELIC"] = {18},
["INVTYPE_TABARD"] = {19},
}

SOURCES = {}
function GetSlotSource(index, link)
  local pa = PMDressUpFrame.ModelScene:GetPlayerActor()
  local possibleSlots = INVENTORY_TYPES_TO_SLOT[select(9, GetItemInfo(link))]
  if possibleSlots == nil then
    print("nil slots")
    return
  end

  for _, slot in ipairs(possibleSlots) do
    local source = pa:GetSlotTransmogSources(slot)
    if source ~= 0 then
      table.insert(SOURCES, {s = source, index = index})
      return true
    end
  end
  return false
end

function GetSlotSourceHard(index, link)
  local pa = PMDressUpFrame.ModelScene:GetPlayerActor()
  local possibleSlots = INVENTORY_TYPES_TO_SLOT[select(9, GetItemInfo(link))]
  for j = 0, 23 do
    local source = pa:GetSlotTransmogSources(j)
    if source ~= 0 then
      table.insert(SOURCES, {s = source, index = index})
      --table.insert(possibleSlots, j)
      return true
    end
  end
  --print("drop rank 2", link, select(9, GetItemInfo(link)))
  return false
end

local function ResetPlayer()
  SetupPlayerForModelScene(PMDressUpFrame.ModelScene, nil, false, false);
  return PMDressUpFrame.ModelScene:GetPlayerActor()
end

local function ClearScene(frame)
  frame.ModelScene:ClearScene();
  frame.ModelScene:TransitionToModelSceneID(290, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true);
  return ResetPlayer()
end

SOURCES = {}
function PMSetup(raceFilename, classFilename)
  --PMDressUpFrame:Hide()
  ClearScene(PMDressUpFrame)
  C_Timer.After(3, function()
    BatchStep(ResetPlayer(), 1, 500)
  end)

  return PMDressUpFrame
end

function FindSourceID(id)
  local result = {}
  for index, details in ipairs(SOURCES) do
    if details.s == id then
      local entry = AUCTIONATOR_RAW_FULL_SCAN[details.index]
      print(entry.itemLink)
      print(
        Auctionator.Utilities.CreateMoneyString(entry.auctionInfo[10]),
        entry.auctionInfo[17]
      )
    end
  end
end

local missing = 0
function BatchStep(pa, start, limit, try)
  try = try or 1

  if start > #AUCTIONATOR_RAW_FULL_SCAN then
    print("ending", start, missing, #SOURCES)
    return
  end

  for i=start, math.min(limit, #AUCTIONATOR_RAW_FULL_SCAN) do
    local link = AUCTIONATOR_RAW_FULL_SCAN[i].itemLink

    local classID = select(6, GetItemInfoInstant(link))
    if (classID == LE_ITEM_CLASS_WEAPON or classID == LE_ITEM_CLASS_ARMOR) and
       IsDressableItem(link) then
      local pa = ClearScene(PMDressUpFrame)
      local result = pa:TryOn(link)
      if result == Enum.ItemTryOnReason.Success then
        if try >= 3 then
          pa:TryOn(link)
          if not GetSlotSourceHard(i, link) then
            if try < 5 then
              C_Timer.After(0.01, function()
                BatchStep(pa, i, limit-start + i, try + 1)
              end)
              return
            else
              print("dropped", link)
            end
          end
        elseif not GetSlotSource(i, link) then
          C_Timer.After(0.01, function()
            BatchStep(pa, i, limit-start + i, try + 1)
          end)
          return
        end
      else
        missing = missing + 1
      end
    end
  end

  C_Timer.After(0.01, function()
    BatchStep(pa, limit + 1, limit + 1 + (limit-start), 1)
  end)
end

function PMOnShow()
  PMSetup()
end
