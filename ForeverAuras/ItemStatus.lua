-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
local _, Private = ...

-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript = Private.TimedAPI("ItemStatus")
function Private.ExecEnv.GetEquipmentDurability(selectedSlot)
  local lowest, currentTotal, maximumTotal, broken, count = 100, 0, 0, 0, 0
  selectedSlot = tonumber(selectedSlot) or 0
  if selectedSlot < 0 or selectedSlot > 19 or selectedSlot ~= math.floor(selectedSlot) then return end
  local firstSlot, lastSlot = 1, 19
  if selectedSlot > 0 then firstSlot, lastSlot = selectedSlot, selectedSlot end
  for slot = firstSlot, lastSlot do
    local current, maximum = GetInventoryItemDurability(slot)
    if hasanysecretvalues(current, maximum) then return end
    if current and maximum and maximum > 0 then
      lowest = math.min(lowest, current / maximum * 100)
      currentTotal = currentTotal + current
      maximumTotal = maximumTotal + maximum
      count = count + 1
      if current == 0 then broken = broken + 1 end
    end
  end
  if count == 0 then return end
  return lowest, currentTotal / maximumTotal * 100, broken, count
end

function Private.ExecEnv.GetBagSpace(includeSpecialty)
  local free, total = 0, 0
  local lastBag = includeSpecialty and (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS) or NUM_BAG_SLOTS
  for bag = 0, lastBag do
    local slots = C_Container.GetContainerNumSlots(bag)
    local available, family = C_Container.GetContainerNumFreeSlots(bag)
    if hasanysecretvalues(slots, available, family) then return end
    if slots and slots > 0 and (includeSpecialty or family == 0) then
      if available == nil then return end
      total = total + slots
      free = free + available
    end
  end
  if total == 0 then return end
  return free, total, total-free, free / total * 100
end

-- Ignore permanent enchants. If both are supplied, prefer an imbue over an oil
-- for the legacy one-enchant-per-hand trigger. Secret fields remain unavailable.
local function ReadModernWeaponEnchant(slot)
  local list = C_Item.GetWeaponEnchantInfo(slot)
  if issecretvalue(list) then return nil, false end
  local chosen
  local types = Enum and Enum.ItemEnchantType
  if not types then return nil, false end
  for _, entry in ipairs(list or {}) do
    if issecretvalue(entry) or hasanysecretvalues(entry.hasEnchant, entry.enchantType, entry.timeLeft, entry.charges, entry.enchantID, entry.enchantIconID) then return nil, false end
    if entry.hasEnchant and (entry.enchantType == types.Temporary or entry.enchantType == types.Imbue) then
      if not chosen or entry.enchantType == types.Imbue then chosen = entry end
    end
  end
  return chosen, true
end

-- Both enchant kinds per hand, for games that let an imbue (Firestone, the
-- mage imbue scrolls) and a temporary enchant (oil, stone, poison) share one
-- weapon. {readable = bool, main = {imbue = entry, temporary = entry}, off = {...}};
-- entries are the API's own tables (timeLeft, charges, enchantID, enchantIconID).
-- Without the modern API only the legacy single enchant is known, under "temporary".
function Private.ExecEnv.GetWeaponEnchantEntries()
  local result = {readable = true, main = {}, off = {}}
  local types = Enum and Enum.ItemEnchantType
  if C_Item and C_Item.GetWeaponEnchantInfo and types and Enum.WeaponSlot then
    for hand, slot in pairs({main = Enum.WeaponSlot.MainHand, off = Enum.WeaponSlot.OffHand}) do
      local list = C_Item.GetWeaponEnchantInfo(slot)
      if issecretvalue(list) then result.readable = false return result end
      for _, entry in ipairs(list or {}) do
        if issecretvalue(entry) or hasanysecretvalues(entry.hasEnchant, entry.enchantType, entry.timeLeft, entry.charges, entry.enchantID, entry.enchantIconID) then
          result.readable = false
          return result
        end
        if entry.hasEnchant and entry.enchantType == types.Imbue then
          result[hand].imbue = result[hand].imbue or entry
        elseif entry.hasEnchant and entry.enchantType == types.Temporary then
          result[hand].temporary = result[hand].temporary or entry
        end
      end
    end
    return result
  end
  local hasMain, mainTime, mainCharges, mainID, hasOff, offTime, offCharges, offID = Private.ExecEnv.GetTemporaryWeaponEnchants()
  if hasanysecretvalues(hasMain, mainTime, mainCharges, mainID, hasOff, offTime, offCharges, offID) then result.readable = false return result end
  if hasMain then result.main.temporary = {timeLeft = mainTime, charges = mainCharges, enchantID = mainID} end
  if hasOff then result.off.temporary = {timeLeft = offTime, charges = offCharges, enchantID = offID} end
  return result
end

-- Extra return values are internal metadata; the first twelve retain the old API.
function Private.ExecEnv.GetTemporaryWeaponEnchants()
  if C_Item and C_Item.GetWeaponEnchantInfo and Enum and Enum.ItemEnchantType and Enum.WeaponSlot then
    local main, mainReadable = ReadModernWeaponEnchant(Enum.WeaponSlot.MainHand)
    local off, offReadable = ReadModernWeaponEnchant(Enum.WeaponSlot.OffHand)
    if not mainReadable or not offReadable then
      return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false
    end
    return main ~= nil, main and main.timeLeft, main and main.charges, main and main.enchantID,
      off ~= nil, off and off.timeLeft, off and off.charges, off and off.enchantID,
      nil, nil, nil, nil, true, main and main.enchantIconID, off and off.enchantIconID
  end
  if C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo then
    local main = C_PaperDollInfo.GetTemporaryEnchantmentInfo(INVSLOT_MAINHAND)
    local off = C_PaperDollInfo.GetTemporaryEnchantmentInfo(INVSLOT_OFFHAND)
    return main ~= nil, main and main.remainingTimeMs, main and main.chargesRemaining, main and main.enchantID,
      off ~= nil, off and off.remainingTimeMs, off and off.chargesRemaining, off and off.enchantID
  end
  return GetWeaponEnchantInfo()
end

local function TrackingInfo(index)
  if C_Minimap and C_Minimap.GetTrackingInfo then return C_Minimap.GetTrackingInfo(index) end
  local name, texture, active = GetTrackingInfo(index)
  if name then return {name = name, texture = texture, active = active == true or active == 1} end
end

local function TrackingCount()
  if C_Minimap and C_Minimap.GetNumTrackingTypes then return C_Minimap.GetNumTrackingTypes() end
  return GetNumTrackingTypes()
end

local function TrackingKey(info)
  return info.spellID and tostring(info.spellID) or info.name
end

function Private.ExecEnv.GetTrackingChoices(selected)
  local values = {}
  for index = 1, TrackingCount() do
    local info = TrackingInfo(index)
    if info then values[TrackingKey(info)] = info.name end
  end
  if selected and selected ~= "" and not values[selected] then values[selected] = selected .. " (unavailable)" end
  return values
end

function Private.ExecEnv.GetTrackingState(selected)
  for index = 1, TrackingCount() do
    local info = TrackingInfo(index)
    if info and TrackingKey(info) == selected then return info.active, info.name, info.texture end
  end
end

-- Share the ammo count across triggers; invalidate it before notifying listeners.
local ammoSnapshot, ammoFrame
local requestedAmmoInfo = {}

local function ParseAmmoItemIDs(input)
  if type(input) ~= "string" then return end
  local selected = {}
  if input:match("^%s*$") then return selected end
  for entry in (input .. ","):gmatch("(.-),") do
    local digits = entry:match("^%s*(%d+)%s*$")
    local id = digits and tonumber(digits)
    if not id or id <= 0 or id >= 2147483647 then return end
    selected[id] = true
  end
  return selected
end

function Private.ExecEnv.ValidateAmmoItemIDs(input)
  if not ParseAmmoItemIDs(input) then return "Enter positive item IDs separated by commas, or leave blank." end
  return true
end

function Private.ExecEnv.WatchAmmo()
  if ammoFrame then return end
  ammoFrame = CreateFrame("Frame")
  ammoFrame:RegisterEvent("BAG_UPDATE_DELAYED")
  ammoFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  ammoFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  -- The ammo slot (equipping other ammo, or the last stack running out).
  ammoFrame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
  ammoFrame:SetScript("OnEvent", function(_, event, itemID)
    if event == "GET_ITEM_INFO_RECEIVED" and not requestedAmmoInfo[itemID] then return end
    if event ~= "GET_ITEM_INFO_RECEIVED" then wipe(requestedAmmoInfo) end
    ammoSnapshot = nil
    Private.ScanEvents("FA_AMMO_UPDATE")
  end)
end

local function ReadCarriedAmmo()
  local snapshot = {counts = {}}
  for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS do
    local slots = C_Container.GetContainerNumSlots(bag)
    if issecretvalue(slots) or type(slots) ~= "number" then return end
    for slot = 1, slots do
      local itemID = C_Container.GetContainerItemID(bag, slot)
      if issecretvalue(itemID) then return end
      if itemID then
        local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
        if issecretvalue(classID) then return end
        -- Do not report a partial count while item metadata is unavailable.
        if classID == nil then
          if not requestedAmmoInfo[itemID] then
            requestedAmmoInfo[itemID] = true
            C_Item.RequestLoadItemDataByID(itemID)
          end
          return
        end
        if classID == Enum.ItemClass.Projectile then
          local info = C_Container.GetContainerItemInfo(bag, slot)
          if issecretvalue(info) or not info then return end
          if issecretvalue(info.stackCount) or type(info.stackCount) ~= "number" then return end
          snapshot.counts[itemID] = (snapshot.counts[itemID] or 0) + info.stackCount
        end
      end
    end
  end
  return snapshot
end

-- The equipped ammo (slot 0) and how many of it are loaded, nil without any.
local function EquippedAmmo()
  local slot = INVSLOT_AMMO or 0
  local itemID = GetInventoryItemID("player", slot)
  if not itemID or issecretvalue(itemID) then return end
  local loaded = GetInventoryItemCount("player", slot)
  if issecretvalue(loaded) or type(loaded) ~= "number" then loaded = 0 end
  return itemID, loaded
end

-- mode, with the Item IDs field blank: "equipped" counts the equipped ammo
-- and shows its icon; "all" counts every kind carried. Explicit IDs count
-- those items. The ammo slot never adds to the bag count.
function Private.ExecEnv.GetAmmoCount(input, mode)
  local selected = ParseAmmoItemIDs(input)
  if not selected then return end
  if not ammoSnapshot then ammoSnapshot = ReadCarriedAmmo() end
  if not ammoSnapshot then return end
  local all = next(selected) == nil
  local equippedID, loaded = EquippedAmmo()
  if all and mode ~= "all" and equippedID then
    -- On this client the ammo slot holds no stack of its own: slot 0's count
    -- is already the carried total of the equipped ammo, which the bag scan
    -- counts too. Take the larger of the two, never their sum.
    local count = math.max(ammoSnapshot.counts[equippedID] or 0, loaded)
    local name, icon = "Ammo", 132382
    local itemName, itemIcon = C_Item.GetItemNameByID(equippedID), C_Item.GetItemIconByID(equippedID)
    if not issecretvalue(itemName) and itemName then name = itemName end
    if not issecretvalue(itemIcon) and itemIcon then icon = itemIcon end
    return count, name, icon
  end
  local count, itemID, kinds = 0, nil, 0
  -- The equipped ammo is one of the bag stacks; its slot count only stands in
  -- when the bag scan did not see it.
  if equippedID and (all or selected[equippedID]) and not ammoSnapshot.counts[equippedID] then
    count = loaded
    itemID = equippedID
    kinds = kinds + 1
  end
  for id, quantity in pairs(ammoSnapshot.counts) do
    if all or selected[id] then
      count = count + quantity
      itemID = id
      kinds = kinds + 1
    end
  end
  -- A single explicit ID keeps its name/icon at zero; multiple types use Ammo.
  if not all then
    itemID = next(selected)
    if next(selected, itemID) then itemID = nil end
  elseif kinds ~= 1 then
    itemID = nil
  end
  local name, icon = "Ammo", 132382
  if itemID then
    local itemName = C_Item.GetItemNameByID(itemID)
    local itemIcon = C_Item.GetItemIconByID(itemID)
    if not issecretvalue(itemName) and itemName then name = itemName end
    if not issecretvalue(itemIcon) and itemIcon then icon = itemIcon end
  end
  return count, name, icon
end
