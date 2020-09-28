function PMDressUpLink(link)
	return link and (PMDressUpItemLink(link) or PMDressUpBattlePetLink(link) or PMDressUpMountLink(link));
end

function PMDressUpItemLink(link)
	if( link ) then 
		if ( IsDressableItem(link) ) then
			return PMDressUpVisual(link);
		end
	end
	return false;
end

function PMDressUpTransmogLink(link)
	if ( not link or not (strsub(link, 1, 16) == "transmogillusion" or strsub(link, 1, 18) == "transmogappearance") ) then
		return false;
	end
	return PMDressUpVisual(link);
end

SOURCES = {}
function GetSlotSource(index)
  local pa = PMDressUpFrame.ModelScene:GetPlayerActor()
  for j = 0, 23 do
    local source = pa:GetSlotTransmogSources(j)
    if source ~= 0 then
      table.insert(SOURCES, {s = source, index = index})
      return
    end
  end
  return
end

function ClearScene(frame)
  frame.ModelScene:ClearScene();
  frame.ModelScene:SetViewInsets(0, 0, 0, 0);
  frame.ModelScene:TransitionToModelSceneID(290, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true);
  SetupPlayerForModelScene(frame.ModelScene, nil, false, false);
end

SOURCES = {}
function PMSetup(raceFilename, classFilename)
  if not raceFilename then
    raceFilename = select(2, UnitRace("player"));
  end
  if not classFilename then
    classFilename = select(2, UnitClass("player"));
  end

	local frame = PMDressUpFrame;

	--SetPMDressUpBackground(frame, raceFilename, classFilename);


  local failCount = 0
  local tmogIndex = 0
  for i=6000,8000 do
    ClearScene(frame)
    local pa = frame.ModelScene:GetPlayerActor()
    local link = AUCTIONATOR_RAW_FULL_SCAN[i].itemLink
    local classID = select(6, GetItemInfoInstant(link))
    if classID == LE_ITEM_CLASS_WEAPON or classID == LE_ITEM_CLASS_ARMOR then
      SetupPlayerForModelScene(frame.ModelScene, nil, false, false);
      local result = pa:TryOn(link)
      if ( result ~= Enum.ItemTryOnReason.Success ) then
        local item = Item:CreateFromItemID(AUCTIONATOR_RAW_FULL_SCAN[i].auctionInfo[17])
        item:ContinueOnItemLoad((function(index)
         return function()
          ClearScene(frame)
          local pa = frame.ModelScene:GetPlayerActor()
          GetSlotSource(index)
          local result = pa:TryOn(link)
          if ( result ~= Enum.ItemTryOnReason.Success ) then
            failCount = failCount + 1
            print("fail", index, link)
          end
          print("fc", failCount)
         end
       end)(i))
      else
        GetSlotSource(i)
        tmogIndex = tmogIndex + 1
      end
      SetupPlayerForModelScene(frame.ModelScene, nil, false, false);
    end
  end
  print("fc tots", failCount)
  print("ti tots", tmogIndex)

	return frame;
end

function MergeSourceIDs()
  local result = {}
  for index, details in ipairs(SOURCES) do
    if details.s == 66976 then
      print(AUCTIONATOR_RAW_FULL_SCAN[details.index].itemLink)
    end
  end
end

function PMOnShow()
  PMSetup()
end

function PMDressUpVisual(...)
	local frame = PMSetup();
	PMDressUpFrame_Show(frame);

	local playerActor = frame.ModelScene:GetPlayerActor();
	if (not playerActor) then
		return false;
	end

	local result = playerActor:TryOn(...);
	if ( result ~= Enum.ItemTryOnReason.Success ) then
		UIErrorsFrame:AddExternalErrorMessage(ERR_NOT_EQUIPPABLE);
	end
	PMDressUpFrame_OnDressModel(frame);
	return true;
end

function PMDressUpTransmogSet(itemModifiedAppearanceIDs)
	local frame = PMSetup();
	PMDressUpFrame_Show(frame);
	PMDressUpFrame_ApplyAppearances(frame, itemModifiedAppearanceIDs);
end

function PMDressUpBattlePetLink(link)
	if( link ) then 
		local _, _, _, linkType, linkID, _, _, _, _, _, battlePetID, battlePetDisplayID = strsplit(":|H", link);
		if ( linkType == "item") then
			local _, _, _, creatureID, _, _, _, _, _, _, _, displayID, speciesID = C_PetJournal.GetPetInfoByItemID(tonumber(linkID));
			if (creatureID and displayID) then
				return PMDressUpBattlePet(creatureID, displayID, speciesID);
			end
		elseif ( linkType == "battlepet" ) then
			local speciesID, _, _, _, _, displayID, _, _, _, _, creatureID = C_PetJournal.GetPetInfoByPetID(battlePetID);
			if ( speciesID == tonumber(linkID)) then
				return PMDressUpBattlePet(creatureID, displayID, speciesID);
			else
				speciesID = tonumber(linkID);
				local _, _, _, creatureID, _, _, _, _, _, _, _, displayID = C_PetJournal.GetPetInfoBySpeciesID(speciesID);
				displayID = (battlePetDisplayID and battlePetDisplayID ~= "0") and battlePetDisplayID or displayID;
				return PMDressUpBattlePet(creatureID, displayID, speciesID);
			end
		end
	end
	return false
end

function PMDressUpBattlePet(creatureID, displayID, speciesID)
	if ( not displayID and not creatureID ) then
		return false;
	end
	
	local frame = PMSetup("Pet", "warrior");	--default to warrior BG when viewing full Pet/Mounts for now

	--Show the frame
	if ( not frame:IsShown() or frame.mode ~= "battlepet" ) then
		ShowUIPanel(frame);
	end
	frame.mode = "battlepet";

	local _, loadoutModelSceneID = C_PetJournal.GetPetModelSceneInfoBySpeciesID(speciesID);

	frame.ModelScene:ClearScene();
	frame.ModelScene:SetViewInsets(0, 0, 50, 0);
	frame.ModelScene:TransitionToModelSceneID(loadoutModelSceneID, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true);

	local battlePetActor = frame.ModelScene:GetActorByTag("pet");
	if ( battlePetActor ) then
		battlePetActor:SetModelByCreatureDisplayID(displayID);
		battlePetActor:SetAnimationBlendOperation(LE_MODEL_BLEND_OPERATION_NONE);
	end
	return true;
end

function PMDressUpMountLink(link)
	if( link ) then
		local mountID = 0;

		local _, _, _, linkType, linkID = strsplit(":|H", link);
		if linkType == "item" then
			mountID = C_MountJournal.GetMountFromItem(tonumber(linkID));
		elseif linkType == "spell" then
			mountID = C_MountJournal.GetMountFromSpell(tonumber(linkID));
		end

		if ( mountID ) then
			return PMDressUpMount(mountID);
		end
	end
	return false
end

function PMDressUpMount(mountID)
	if ( not mountID or mountID == 0 ) then
		return false;
	end

	local frame = PMSetup("Pet", "warrior");	--default to warrior BG when viewing full Pet/Mounts for now

	--Show the frame
	if ( not frame:IsShown() or frame.mode ~= "mount" ) then
		ShowUIPanel(frame);
	end
	frame.mode = "mount";

	local creatureDisplayID, _, _, isSelfMount, _, modelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(mountID);
	frame.ModelScene:ClearScene();
	frame.ModelScene:SetViewInsets(0, 0, 0, 0);
	local forceEvenIfSame = true;
	frame.ModelScene:TransitionToModelSceneID(modelSceneID, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_MAINTAIN, forceEvenIfSame);
	
	local mountActor = frame.ModelScene:GetActorByTag("unwrapped");
	if mountActor then
		mountActor:SetModelByCreatureDisplayID(creatureDisplayID);

		-- mount self idle animation
		if (isSelfMount) then
			mountActor:SetAnimationBlendOperation(LE_MODEL_BLEND_OPERATION_NONE);
			mountActor:SetAnimation(618); -- MountSelfIdle
		else
			mountActor:SetAnimationBlendOperation(LE_MODEL_BLEND_OPERATION_ANIM);
			mountActor:SetAnimation(0);
		end
		frame.ModelScene:AttachPlayerToMount(mountActor, animID, isSelfMount, disablePlayerMountPreview);
	end
	return true;
end

function PMDressUpTexturePath(raceFileName)
	-- HACK
	if ( not raceFileName ) then
		raceFileName = "Orc";
	end
	-- END HACK

	return "Interface\\PMDressUpFrame\\PMDressUpBackground-"..raceFileName;
end

function SetPMDressUpBackground(frame, raceFilename, classFilename)
	local texture = PMDressUpTexturePath(raceFilename);
	
	if ( frame.BGTopLeft ) then
		frame.BGTopLeft:SetTexture(texture..1);
	end
	if ( frame.BGTopRight ) then
		frame.BGTopRight:SetTexture(texture..2);
	end
	if ( frame.BGBottomLeft ) then
		frame.BGBottomLeft:SetTexture(texture..3);
	end
	if ( frame.BGBottomRight ) then
		frame.BGBottomRight:SetTexture(texture..4);
	end
	
	if ( frame.ModelBackground and classFilename ) then
		frame.ModelBackground:SetAtlas("dressingroom-background-"..classFilename);
	end
end

function PMDressUpFrame_OnDressModel(self)
end

function PMDressUpFrame_Show(frame)
	if ( not frame:IsShown() or frame.mode ~= "player") then
		frame.mode = "player";

		-- If there's not enough space as-is, try minimizing.
		if not CanShowRightUIPanel(frame) and not frame.MaximizeMinimizeFrame:IsMinimized() then
			local isAutomaticAction = true;
			frame.MaximizeMinimizeFrame:Minimize(isAutomaticAction);

			-- Restore the frame to its original state if we still can't fit.
			if not CanShowRightUIPanel(frame) then
				frame.MaximizeMinimizeFrame:Maximize(isAutomaticAction);
			end
		end

		ShowUIPanel(frame);

		frame.ModelScene:ClearScene();
		frame.ModelScene:SetViewInsets(0, 0, 0, 0);
		frame.ModelScene:TransitionToModelSceneID(290, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true);
		
		local sheatheWeapons = false;
		local autoDress = true;
		local itemModifiedAppearanceIDs = nil;
		SetupPlayerForModelScene(frame.ModelScene, itemModifiedAppearanceIDs, sheatheWeapons, autoDress);
	end
end

function PMDressUpFrame_ApplyAppearances(frame, itemModifiedAppearanceIDs)
	local sheatheWeapons = false;
	local autoDress = true;
	SetupPlayerForModelScene(frame.ModelScene, itemModifiedAppearanceIDs, sheatheWeapons, autoDress);
end

function PMDressUpSources(appearanceSources, mainHandEnchant, offHandEnchant)
	if ( not appearanceSources ) then
		return true;
	end

	local raceFilename = nil;
	local classFilename = select(2, UnitClass("player"));
	SetPMDressUpBackground(PMDressUpFrame, raceFilename, classFilename);
	PMDressUpFrame_Show(PMDressUpFrame);

	local playerActor = PMDressUpFrame.ModelScene:GetPlayerActor();
	if (not playerActor) then
		return true;
	end

	local mainHandSlotID = GetInventorySlotInfo("MAINHANDSLOT");
	local secondaryHandSlotID = GetInventorySlotInfo("SECONDARYHANDSLOT");
	for i = 1, #appearanceSources do
		if ( i ~= mainHandSlotID and i ~= secondaryHandSlotID ) then
			if ( appearanceSources[i] and appearanceSources[i] ~= NO_TRANSMOG_SOURCE_ID ) then
				playerActor:TryOn(appearanceSources[i]);
			end
		end
	end

	playerActor:TryOn(appearanceSources[mainHandSlotID], "MAINHANDSLOT", mainHandEnchant);
	playerActor:TryOn(appearanceSources[secondaryHandSlotID], "SECONDARYHANDSLOT", offHandEnchant);
end

PMDressUpOutfitMixin = { };

function PMDressUpOutfitMixin:GetSlotSourceID(slot, transmogType)
	local playerActor = PMDressUpFrame.ModelScene:GetPlayerActor();
	if (not playerActor) then
		return;
	end

	local slotID = GetInventorySlotInfo(slot);
	local appearanceSourceID, illusionSourceID = playerActor:GetSlotTransmogSources(slotID);
	if ( transmogType == LE_TRANSMOG_TYPE_APPEARANCE ) then
		return appearanceSourceID;
	elseif ( transmogType == LE_TRANSMOG_TYPE_ILLUSION ) then
		return illusionSourceID;
	end
end

function PMDressUpOutfitMixin:LoadOutfit(outfitID)
	if ( not outfitID ) then
		return;
	end
	PMDressUpSources(C_TransmogCollection.GetOutfitSources(outfitID))
end
