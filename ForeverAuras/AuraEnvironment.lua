-- Modified for ForeverAuras, 2026-09-30.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript, C_Timer = Private.TimedAPI("AuraEnvironment")
---@class WeakAuras
local WeakAuras = WeakAuras
local L = WeakAuras.L

-- The addon's own copy, whatever other addons registered (see Libs/LibSerialize).
local LibSerialize = ForeverAurasLibSerialize or LibStub("LibSerialize")
local LibDeflate = LibStub:GetLibrary("LibDeflate")

local UnitAura = UnitAura
if UnitAura == nil then
  --- Deprecated in 10.2.5
  UnitAura = function(unitToken, index, filter)
		local auraData = C_UnitAuras.GetAuraDataByIndex(unitToken, index, filter)
		if not auraData then
			return nil;
		end

		return AuraUtil.UnpackAuraData(auraData)
	end
end

-- Unit Aura functions that return info about the first Aura matching the spellName or spellID given on the unit.
local WA_GetUnitAura = function(unit, spell, filter)
  if filter and not filter:upper():find("FUL") then
      filter = filter.."|HELPFUL"
  end
  for i = 1, 255 do
    local name, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, i, filter)
    if not name then return end
    if spell == spellId or spell == name then
      return UnitAura(unit, i, filter)
    end
  end
end

local WA_GetUnitBuff = function(unit, spell, filter)
  filter = filter and filter.."|HELPFUL" or "HELPFUL"
  return WA_GetUnitAura(unit, spell, filter)
end

local WA_GetUnitDebuff = function(unit, spell, filter)
  filter = filter and filter.."|HARMFUL" or "HARMFUL"
  return WA_GetUnitAura(unit, spell, filter)
end

-- Function to assist iterating group members whether in a party or raid.
local WA_IterateGroupMembers = function(reversed, forceParty)
  local unit = (not forceParty and IsInRaid()) and 'raid' or 'party'
  local numGroupMembers = unit == 'party' and GetNumSubgroupMembers() or GetNumGroupMembers()
  local i = reversed and numGroupMembers or (unit == 'party' and 0 or 1)
  return function()
    local ret
    if i == 0 and unit == 'party' then
      ret = 'player'
    elseif i <= numGroupMembers and i > 0 then
      ret = unit .. i
    end
    i = i + (reversed and -1 or 1)
    return ret
  end
end

-- UTF-8 Sub is pretty commonly needed
local WA_Utf8Sub = function(input, size)
  local output = ""
  -- A secret text (a name from a restricted unit or spell) cannot be read or
  -- cut; it is shown whole instead of raising an error.
  if issecretvalue(input) then return input end
  input = tostring(input)
  if type(input) ~= "string" then
    return output
  end
  local i = 1
  while (size > 0) do
    local byte = input:byte(i)
    if not byte then
      return output
    end
    if byte < 128 then
      -- ASCII byte
      output = output .. input:sub(i, i)
      size = size - 1
    elseif byte < 192 then
      -- Continuation bytes
      output = output .. input:sub(i, i)
    elseif byte < 244 then
      -- Start bytes
      output = output .. input:sub(i, i)
      size = size - 1
    end
    i = i + 1
  end

  -- Add any bytes that are part of the sequence
  while (true) do
    local byte = input:byte(i)
    if byte and byte >= 128 and byte < 192 then
      output = output .. input:sub(i, i)
    else
      break
    end
    i = i + 1
  end

  return output
end

WeakAuras.WA_Utf8Sub = WA_Utf8Sub

-- Wrapping a unit's name in its class colour is very common in custom Auras
local WA_ClassColorName = function(unit, maxlen)
  if unit and UnitExists(unit) then
    local name = WeakAuras.UnitName(unit)
    if issecretvalue(name) then
      local _, class = UnitClass(unit)
      if not class then
        return name
      end

      local classColor = C_ClassColor.GetClassColor(class)
      return classColor:WrapTextInColorCode(name)
    end
    if maxlen and maxlen > 0 then
      name = WA_Utf8Sub(name, maxlen)
    end
    local _, class = UnitClass(unit)
    if not class then
      return name
    else
      local classData = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
      local coloredName = ("|c%s%s|r"):format(classData.colorStr, name)
      return coloredName
    end
  else
    return "" -- ¯\_(ツ)_/¯
  end
end

WeakAuras.WA_ClassColorName = WA_ClassColorName

WeakAuras.PadString = function(input, padMode, padLength)
  -- Secret text cannot be measured, so it is not padded.
  if issecretvalue(input) then return input end
  input = tostring(input)
  if type(input) ~= "string" then
    return input
  end

  local toAdd = padLength - #input
  if toAdd <= 0 then
    return input
  end

  if padMode == "left" then
    return string.rep(" ", toAdd) .. input
  elseif padMode == "right" then
    return input .. string.rep(" ", toAdd)
  end

  return input
end

local LCG = LibStub("LibCustomGlow-1.0-foreverauras")
WeakAuras.ShowOverlayGlow = LCG.ButtonGlow_Start
WeakAuras.HideOverlayGlow = LCG.ButtonGlow_Stop

local LGF = LibStub("LibGetFrame-1.0")
WeakAuras.GetUnitFrame = LGF.GetUnitFrame
-- Name-only player plates have no visible health bar. Keep one frame per
-- native name region so Set Parent to Anchor also works, without reading its
-- potentially secret bounds or changing Blizzard's nameplate layout.
local nameplateNameAnchors = {}
local function CanAccessNameplateRegion(region)
  if not region then return false end
  local forbidden = region:IsForbidden()
  if issecretvalue(forbidden) or forbidden then return false end
  if region.CanBeAccessedInContext then
    local accessible = region:CanBeAccessedInContext()
    if issecretvalue(accessible) or not accessible then return false end
  end
  return true
end

local function GetNameOnlyAnchor(nameplate)
  if not CanAccessNameplateRegion(nameplate) then return end
  local unitFrame = nameplate.UnitFrame
  if not CanAccessNameplateRegion(unitFrame) then return end
  local name = unitFrame.name
  if not CanAccessNameplateRegion(name) then return end
  local anchor = nameplateNameAnchors[name]
  if not anchor then
    anchor = CreateFrame("Frame", nil, nameplate)
    anchor:SetAllPoints(name)
    nameplateNameAnchors[name] = anchor
  end
  return anchor
end

WeakAuras.GetUnitNameplate = function(unit)
  if Private.multiUnitUnits.nameplate[unit] then
    -- Match Ellesmere's current plate before using a pooled health bar.
    local ns = EllesmereNameplates_NS
    local nameplate = ns and C_NamePlate.GetNamePlateForUnit(unit)
    local plate = ns and ((ns.plates and ns.plates[unit]) or (ns.friendlyPlates and ns.friendlyPlates[unit]))
    if plate and plate.health and plate.nameplate and plate.nameplate == nameplate then
      return plate.health
    end
    -- Ellesmere renders name-only players through the native name region;
    -- friendly NPCs use a separate overlay and retain their existing lookup.
    local profile = ns and ns.db and ns.db.profile
    if nameplate and profile and profile.friendlyNameOnly ~= false and ns.pendingUnits and ns.pendingUnits[unit] == nameplate then
      local player = UnitIsPlayer(unit)
      if not issecretvalue(player) and player then
        local anchor = GetNameOnlyAnchor(nameplate)
        if anchor then return anchor end
      end
    end
    return LGF.GetUnitNameplate(unit)
  end
end

local blockedFunctions = {
  -- Lua functions that may allow breaking out of the environment
  getfenv = true,
  setfenv = true,
  loadstring = true,
  pcall = true,
  xpcall = true,
  -- blocked WoW API
  SendMail = true,
  SetTradeMoney = true,
  AddTradeMoney = true,
  PickupTradeMoney = true,
  PickupPlayerMoney = true,
  TradeFrame = true,
  MailFrame = true,
  EnumerateFrames = true,
  RunScript = true,
  AcceptTrade = true,
  SetSendMailMoney = true,
  EditMacro = true,
  DevTools_DumpCommand = true,
  hash_SlashCmdList = true,
  RegisterNewSlashCommand = true,
  CreateMacro = true,
  SetBindingMacro = true,
  GuildDisband = true,
  GuildUninvite = true,
  -- Custom code from a pasted string must not be able to log the player out,
  -- run console commands, manage their guild or move guild bank money.
  Quit = true,
  ForceQuit = true,
  Logout = true,
  ConsoleExec = true,
  GuildInvite = true,
  GuildPromote = true,
  GuildDemote = true,
  GuildSetLeader = true,
  GuildSetMOTD = true,
  GuildLeave = true,
  SetGuildInfoText = true,
  DepositGuildBankMoney = true,
  WithdrawGuildBankMoney = true,
  PickupGuildBankMoney = true,
  SetGuildBankWithdrawGoldLimit = true,
  securecall = true,
  DeleteCursorItem = true,
  ChatEdit_SendText = true,
  ChatEdit_ActivateChat = true,
  ChatEdit_ParseText = true,
  ChatEdit_OnEnterPressed = true,
  GetButtonMetatable = true,
  GetEditBoxMetatable = true,
  GetFontStringMetatable = true,
  GetFrameMetatable = true,
}

local blockedTables = {
  SlashCmdList = true,
  SendMailMailButton = true,
  SendMailMoneyGold = true,
  MailFrameTab2 = true,
  DEFAULT_CHAT_FRAME = true,
  ChatFrame1 = true,
  ForeverAurasSaved = true,
  ForeverAurasOptions = true,
  ForeverAurasOptionsSaved = true,
  -- Also under the compatibility names, and the debug library.
  WeakAurasSaved = true,
  WeakAurasOptions = true,
  WeakAurasOptionsSaved = true,
  debug = true,
  ItemRackUser = true,
  ItemRackEvents = true
}

local aura_environments = {}
-- nil == Not initiliazed
-- 1 == config initialized
-- 2 == fully initialized
local environment_initialized = {}
local getDataCallCounts = {}

-- Copies handed out by the aura environment's GetData, one per aura data table.
-- Copying a whole aura on every call was the cost behind the "GetData a lot"
-- warning: custom code that walks a group on each event copied every member's
-- triggers, conditions and code strings again (several ms and hundreds of KB
-- of garbage per event). A copy is kept until any aura changes
-- (Private.dataGeneration, ForeverAuras.lua) and is not used while the options
-- window is open, where auras are edited in place. Custom code that edits its
-- copy sees its own edits on later calls until then; the saved data itself
-- stays protected as before.
local dataCopies = setmetatable({}, {__mode = "k"})
local function GetDataCopy(id)
  local data = WeakAuras.GetData(id)
  if not data then return nil end
  if WeakAuras.IsOptionsOpen() then return CopyTable(data), true end
  local entry = dataCopies[data]
  if entry and entry.generation == Private.dataGeneration then return entry.copy, false end
  entry = {generation = Private.dataGeneration, copy = CopyTable(data)}
  dataCopies[data] = entry
  return entry.copy, true
end

function Private.IsEnvironmentInitialized(id)
  return environment_initialized[id] == 2
end

function Private.DeleteAuraEnvironment(id)
  aura_environments[id] = nil
  environment_initialized[id] = nil
  getDataCallCounts[id] = nil
  Private.InvalidateDataCopies()
end

function Private.RenameAuraEnvironment(oldid, newid)
  aura_environments[oldid], aura_environments[newid] = nil, aura_environments[oldid]
  environment_initialized[oldid], environment_initialized[newid] = nil, environment_initialized[oldid]
  getDataCallCounts[oldid], getDataCallCounts[newid] = nil, getDataCallCounts[oldid]
  Private.InvalidateDataCopies()
end

local current_uid = nil
local current_aura_env = nil
-- Stacks of aura environments/uids, allow use of recursive aura activations through calls to ForeverAuras.ScanEvents().
local aura_env_stack = {}
local aura_uid_stack = {}

local function PushAuraEnvironment()
  local index = #aura_env_stack + 1
  aura_env_stack[index] = current_aura_env
  aura_uid_stack[index] = current_uid
end

local function PopAuraEnvironment()
  local index = #aura_env_stack
  if index > 0 then
    aura_env_stack[index] = nil
    aura_uid_stack[index] = nil
  end
  current_aura_env = aura_env_stack[index - 1]
  current_uid = aura_uid_stack[index - 1]
end


local function UpdateSavedDataWarning(uid, size)
  local savedDataWarning = 16 * 1024 * 1024 -- 16 KB, but it's only a warning
  if size > savedDataWarning then
    Private.AuraWarnings.UpdateWarning(uid, "CustomSavedData", "warning",
                                       L["This aura is saving %s KB of data"]:format(ceil(size / 1024)))
  else
    Private.AuraWarnings.UpdateWarning(uid, "CustomSavedData")
  end
end

function Private.SaveAuraEnvironment(id)
  local data = WeakAuras.GetData(id)
  if not data then
    return
  end

  local input = aura_environments[id] and aura_environments[id].saved
  if input then
    local serialized = LibSerialize:SerializeEx({errorOnUnserializableType = false}, input)
    -- We use minimal compression, since that already achieves a reasonable compression ratio,
    -- but takes significant less time
    local compressed = LibDeflate:CompressDeflate(serialized, {level = 1})
    local encoded = LibDeflate:EncodeForPrint(compressed)
    UpdateSavedDataWarning(data.uid, #encoded)
    data.information.saved = encoded
  else
    data.information.saved = nil
  end
end

function Private.RestoreAuraEnvironment(id)
  local data = WeakAuras.GetData(id)
  if not data then
    return
  end

  local input = data.information.saved
  if input then
    local decoded = LibDeflate:DecodeForPrint(input)
    local decompressed = LibDeflate:DecompressDeflate(decoded)
    local success, deserialized = LibSerialize:Deserialize(decompressed)
    if success then
      aura_environments[id].saved = deserialized
    else
      aura_environments[id].saved = nil
    end
    UpdateSavedDataWarning(data.uid, #input)
  else
    aura_environments[id].saved = nil
  end
end

function Private.ClearAuraEnvironmentSavedData(id)
  if environment_initialized[id] == 2 then
    aura_environments[id].saved = nil
  end
end

function Private.ClearAuraEnvironment(id)
  if environment_initialized[id] == 2 then
    Private.DeactivateAuraEnvironmentLifecycle(id)
    Private.SaveAuraEnvironment(id)
    environment_initialized[id] = nil
    aura_environments[id] = nil
    getDataCallCounts[id] = nil
  end
end

function Private.ActivateAuraEnvironmentForRegion(region, onlyConfig)
  Private.ActivateAuraEnvironment(region.id, region.cloneId, region.state, region.states, onlyConfig)
end

function Private.ActivateAuraEnvironment(id, cloneId, state, states, onlyConfig)
  local data = id and WeakAuras.GetData(id)
  if not data then
    -- Pop the last aura_env from the stack, and update current_aura_env appropriately.
    PopAuraEnvironment()
  else
    -- Existing config is initialized to a high enough value
    if environment_initialized[id] == 2 or (onlyConfig and environment_initialized[id] == 1) then
      local region = WeakAuras.GetRegion(id, cloneId)
      -- Point the current environment to the correct table
      current_uid = data.uid
      current_aura_env = aura_environments[id]
      current_aura_env.id = id
      current_aura_env.cloneId = cloneId
      current_aura_env.state = state
      current_aura_env.states = states
      current_aura_env.region = region
      -- Push the new environment onto the stack
      PushAuraEnvironment()
    elseif onlyConfig then
      environment_initialized[id] = 1
      aura_environments[id] = {}
      getDataCallCounts[id] = 0
      current_uid = data.uid
      current_aura_env = aura_environments[id]
      current_aura_env.id = id
      current_aura_env.cloneId = cloneId
      current_aura_env.state = state
      current_aura_env.states = states
      PushAuraEnvironment()

      if not data.controlledChildren then
        current_aura_env.config = CopyTable(data.config)
      end
    else
      -- Either this aura environment has not yet been initialized, or it was reset via an edit in ForeverAurasOptions
      local region = id and Private.EnsureRegion(id, cloneId)
      environment_initialized[id] = 2
      aura_environments[id] = aura_environments[id] or {}
      getDataCallCounts[id] = getDataCallCounts[id] or 0
      current_uid = data.uid
      current_aura_env = aura_environments[id]
      current_aura_env.id = id
      current_aura_env.cloneId = cloneId
      current_aura_env.state = state
      current_aura_env.states = states
      current_aura_env.region = region
      Private.RestoreAuraEnvironment(id)
      -- push new environment onto the stack
      PushAuraEnvironment()

      if data.controlledChildren then
        current_aura_env.child_envs = {}
        for dataIndex, childID in ipairs(data.controlledChildren) do
          local childData = WeakAuras.GetData(childID)
          if childData then
            if not environment_initialized[childID] then
              Private.ActivateAuraEnvironment(childID, nil, nil, nil, true)
              Private.ActivateAuraEnvironment()
            end
            current_aura_env.child_envs[dataIndex] = aura_environments[childID]
          end
        end
      else
        if environment_initialized[id] == 1 then
          -- Already done
        else
          current_aura_env.config = CopyTable(data.config)
        end
      end
      -- Finally, run the init function if supplied
      local actions = data.actions.init
      if(actions and actions.do_custom and actions.custom) then
        local func = Private.customActionsFunctions[id]["init"]
        if func then
          xpcall(func, Private.GetErrorHandlerId(id, "init"))
        end
      end
      Private.ActivateAuraEnvironmentLifecycle(id)
    end
  end
end

EventRegistry:RegisterCallback("SetItemRef", function(_, link, text, button, chatFrame)
  local linkType, addonName, waID, uid = strsplit(":", link)
  if linkType == "addon" and addonName == "ForeverAuras" then
    waID = waID and C_EncodingUtil.DecodeBase64(waID)
    if button == "RightButton" then
      if (not Private.LoadOptions() or not WeakAuras.IsOptionsOpen()) then
        WeakAuras.ToggleOptions(nil, Private)
        C_Timer.After(1, function() WeakAuras.PickDisplay(waID) end)
      else
        WeakAuras.PickDisplay(waID)
      end
    else
      print("Print from WA:", [["]]..waID..[["]], "|n|cff999999(right click the link above to open in config, /wa trackprint to toggle the hyperlink display)|r")
    end
  end
end)

local function getHyperlinkForPrint()
  local id, uid = current_aura_env.id, current_uid
  if id then
    id = C_EncodingUtil.EncodeBase64(id)
    return string.format("|Haddon:ForeverAuras:%s:%s|h|cff666666[WA]|r|h", id, uid)
  else
    return "Unknown Aura"
  end
end

local function printID(...)
  print(getHyperlinkForPrint(), ...)
end

local function DebugPrint(...)
  Private.DebugLog.Print(current_uid, ...)
end

local function blocked(key)
  Private.AuraWarnings.UpdateWarning(current_uid, "SandboxForbidden", "error",
          string.format(L["Forbidden function or table: %s"], key))
end

local function MakeReadOnly(input, options)
  return setmetatable({},
  {
    __index = function(t, k)
       if options.blockedFunctions[k] then
         options.blocked(k)
         return function() end
       elseif options.blockedTables[k] then
         options.blocked(k)
         return {}
       elseif options.override[k] then
         return options.override[k]
       else
         return input[k]
       end
     end,
     __newindex = options.setBlocked,
     __metatable = false
  })
end

--- Wraps a table, so that accessing any key in it creates a deprecated warning
---@param input table
---@param name string
---@param warningMsg string
---@return table
local function MakeDeprecated(input, name, warningMsg)
  return setmetatable({},
  {
    __index = function(t, k)
      Private.AuraWarnings.UpdateWarning(current_uid, "Deprecated_" .. name, "warning", warningMsg)
      return input[k]
    end,
    __metatable = false
  })
end

local FakeWeakAurasMixin = {
  blockedFunctions = {
    -- Other addons might use these, so before moving them to the Private space, we need
    -- to discuss these. But Auras have no purpose for calling these
    Add = true,
    Delete = true,
    HideOptions = true,
    Rename = true,
    NewAura = true,
    Import = true,
    PreAdd = true,
    RegisterRegionOptions = true,
    RegisterSubRegionOptions = true,
    RegisterSubRegionType = true,
    RegisterRegionType = true,
    RegisterTriggerSystem = true,
    RegisterTriggerSystemOptions = true,
    ShowOptions = true,
    -- Internal editor APIs remain inaccessible to custom aura code.
    createSpinner = true,
    ClearAndUpdateOptions = true,
    CreateTemplateView = true,
    FillOptions = true,
    GetMoverSizerId = true,
    GetNameAndIcon = true,
    GetTriggerCategoryFor = true,
    NewDisplayButton = true,
    OpenOptions = true,
    PickDisplay = true,
    setTile = true,
    SetMoverSizer = true,
    SetModel = true,
    Toggle = true,
    ToggleOptions = true,
    UpdateGroupOrders = true,
    UpdateThumbnail = true,
  },
  blockedTables = {
    ModelPaths = true,
    RealTimeProfilingWindow = true,
    -- Internal editor APIs remain inaccessible to custom aura code.
    genericTriggerTypes = true,
    spellCache = true,
    StopMotion = true,
    -- We block the loaded table, even though it doesn't exist anymore,
    -- because some versions of ZT Tracker overwrote region:Collpase() and
    -- checked for ForeverAuras.loaded in there
    loaded = true
  },
  override = {
    me = GetUnitName("player", true),
    myGUID = UnitGUID("player"),
    GetData = function(id)
      -- Only calls that had to copy an aura count towards the warning; a copy
      -- served from the cache costs no more than a table lookup.
      local copy, copied = GetDataCopy(id)
      if copied then
        local currentId = Private.UIDtoID(current_uid)
        getDataCallCounts[currentId] = (getDataCallCounts[currentId] or 0) + 1
        if getDataCallCounts[currentId] > 99 then
          Private.AuraWarnings.UpdateWarning(current_uid, "FakeWeakAurasGetData", "warning",
                    L["This aura calls GetData a lot, which is a slow function."])
        end
      end
      return copy
    end,
    clones = MakeDeprecated(Private.clones, "clones",
                L["Using WeakAuras.clones is deprecated. Use WeakAuras.GetRegion(id, cloneId) instead."]),
    regions = MakeDeprecated(Private.regions, "regions",
                L["Using WeakAuras.regions is deprecated. Use WeakAuras.GetRegion(id) instead."]),
    GetAllDBMTimers = function() return Private.ExecEnv.BossMods.DBM:GetAllTimers() end,
    GetDBMTimerById = function(...) return Private.ExecEnv.BossMods.DBM:GetTimerById(...) end,
    GetDBMTimer = function(...) return Private.ExecEnv.BossMods.DBM:GetTimer(...) end,
    GetBigWigsTimerById = function(...) return Private.ExecEnv.BossMods.BigWigs:GetTimerById(...) end,
    GetAllBigWigsTimers = function() return Private.ExecEnv.BossMods.BigWigs:GetAllTimers() end,
    GetBigWigsStage = function(...) return Private.ExecEnv.BossMods.BigWigs:GetStage(...) end,
    RegisterBigWigsTimer = function() Private.ExecEnv.BossMods.BigWigs:RegisterTimer() end,
    RegisterDBMCallback = function() Private.ExecEnv.BossMods.DBM:RegisterTimer() end,
    GetBossStage = function() return Private.ExecEnv.BossMods.Generic:GetStage() end
  },
  blocked = blocked,
  setBlocked = function()
    Private.AuraWarnings.UpdateWarning(current_uid, "FakeWeakAurasSet", "error",
                  L["Writing to the ForeverAuras table is not allowed."], true)
  end
}

local FakeWeakAuras = MakeReadOnly(WeakAuras, FakeWeakAurasMixin)

local overridden = {
  WA_GetUnitAura = WA_GetUnitAura,
  WA_GetUnitBuff = WA_GetUnitBuff,
  WA_GetUnitDebuff = WA_GetUnitDebuff,
  WA_IterateGroupMembers = WA_IterateGroupMembers,
  WA_ClassColorName = WA_ClassColorName,
  WA_Utf8Sub = WA_Utf8Sub,
  ActionButton_ShowOverlayGlow = WeakAuras.ShowOverlayGlow,
  ActionButton_HideOverlayGlow = WeakAuras.HideOverlayGlow,
  WeakAuras = FakeWeakAuras,
  ForeverAuras = FakeWeakAuras,
}

-- WORKAROUND API which return Mixin'd values need those mixin "rawgettable" in caller's fenv #5071
local mixins = {
  ColorMixin = ColorMixin,
  Vector2DMixin = Vector2DMixin,
  Vector3DMixin = Vector3DMixin,
  ItemLocationMixin = ItemLocationMixin,
  ItemTransmogInfoMixin = ItemTransmogInfoMixin,
  TransmogPendingInfoMixin = TransmogPendingInfoMixin,
  TransmogLocationMixin = TransmogLocationMixin,
  PlayerLocationMixin = PlayerLocationMixin,
}

local env_getglobal_custom
local exec_env_custom = setmetatable(CopyTable(mixins),
{
  __index = function(t, k)
    if k == "_G" then
      return t
    elseif k == "getglobal" then
      return env_getglobal_custom
    elseif k == "aura_env" then
      return current_aura_env
    elseif k == "DebugPrint" then
      return DebugPrint
    elseif k == "C_Timer" then
      return current_aura_env and Private.AuraEnvironmentWrappedSystem.Get("C_Timer",
                                      current_aura_env.id, current_aura_env.cloneId)
                              or C_Timer
    elseif (k == "CreateFrame" or k == "hooksecurefunc") and current_aura_env then
      -- Frames and hooks made by custom code are timed under the aura's name
      -- while profiling runs (see Private.TimedAPI); otherwise unchanged.
      return Private.AuraTimedAPI(current_aura_env.id)[k]
    elseif k == "print" then
     return current_aura_env and not Private.db.disableTrackPrints and printID or print
    elseif blockedFunctions[k] then
      blocked(k)
      return function(_) end
    elseif blockedTables[k] then
      blocked(k)
      return {}
    elseif overridden[k] then
      return overridden[k]
    elseif _G[k] then
      return _G[k]
    elseif k:find(".", 1, true) then
      -- The frame chooser names a child frame without a name after its parent,
      -- e.g. "PlayerFrame.healthbar". Resolve the first segment through this
      -- sandbox, not through the real _G. Otherwise "_G.loadstring" or
      -- "ForeverAuras.Add" would return the real, blocked functions.
      local f
      for i, n in ipairs{strsplit(".", k)} do
        if i == 1 then
          f = t[n]
        elseif type(f) == "table" then
          f = f[n]
        else
          return
        end
      end
      return f
    end
  end,
  __newindex = function(table, key, value)
    if key == "aura_env" then
      -- Prevent custom code from replacing the managed aura environment.
      Private.AuraWarnings.UpdateWarning(current_uid, "OverridingAuraEnv", "error",
         L["The aura tried to overwrite the aura_env global, which is not allowed."], true)
      return
    elseif _G[key] then
      Private.AuraWarnings.UpdateWarning(current_uid, "OverridingGlobal", "warning",
         string.format(L["The aura has overwritten the global '%s', this might affect other auras."], key))
    end
    rawset(table, key, value)
  end,
  __metatable = false
})

function env_getglobal_custom(k)
  return exec_env_custom[k]
end

local PrivateForBuiltIn = {
  ExecEnv = Private.ExecEnv
}

local env_getglobal_builtin
local exec_env_builtin = setmetatable(CopyTable(mixins),
{
  __index = function(t, k)
    if k == "_G" then
      return t
    elseif k == "getglobal" then
      return env_getglobal_builtin
    elseif k == "aura_env" then
      return current_aura_env
    elseif k == "DebugPrint" then
      return DebugPrint
    elseif k == "Private" then
      -- Built in code has access to Private.ExecEnv
      -- Which contains a bunch of internal helpers
      return PrivateForBuiltIn
    elseif blockedFunctions[k] then
      blocked(k)
      return function(_) end
    elseif blockedTables[k] then
      blocked(k)
      return {}
    elseif overridden[k] then
      return overridden[k]
    else
      return _G[k]
    end
  end,
  __newindex = function(table, key, value)
    if _G[key] then
      Private.AuraWarnings.UpdateWarning(current_uid, "OverridingGlobal", "warning",
         string.format(L["The aura has overwritten the global '%s', this might affect other auras."], key))
    end
    rawset(table, key, value)
  end,
  __metatable = false
})

function env_getglobal_builtin(k)
  return exec_env_builtin[k]
end

local function firstLine(string)
  local lineBreak = string:find('\n', 1, true)
  if lineBreak then
    return string:sub(1, lineBreak - 1)
  end
  return string
end

local function CreateFunctionCache(exec_env)
  local cache = {
    funcs = setmetatable({}, {__mode = "v"})
  }
  cache.Load = function(self, string, id, silent)
    if self.funcs[string] then
      return self.funcs[string]
    else
      local loadedFunction, errorString = loadstring(string, firstLine(string))
      if errorString then
        if not silent then
          print(string.format(L["Error in Aura '%s'"], id), errorString)
        end
        return nil, errorString
      elseif loadedFunction then
        --- @cast loadedFunction -nil
        setfenv(loadedFunction, exec_env)
        local success, func = pcall(assert(loadedFunction))
        if success then
          self.funcs[string] = func
          return func
        end
      end
    end
  end
  return cache
end

local function_cache_custom = CreateFunctionCache(exec_env_custom)
local function_cache_builtin = CreateFunctionCache(exec_env_builtin)

function WeakAuras.LoadFunction(string, id)
  return function_cache_custom:Load(string, id)
end

function Private.LoadFunction(string, id, silent)
  return function_cache_builtin:Load(string, id, silent)
end

function Private.GetSanitizedGlobal(key)
  return exec_env_custom[key]
end


-- Resolve selected anchors through the existing sandbox. Missing targets can be
-- retried; blocked globals and unusable objects must not reach SetPoint/SetParent.
-- Position-only anchors can target textures/font strings; parents must be frames.
function Private.GetSanitizedFrame(key, requireFrame)
  if issecretvalue(key) or type(key) ~= "string" or key == "" then return end
  local root = key:match("^[^.]+")
  if root == "_G" or root == "getglobal" or blockedTables[root] or blockedFunctions[root] then
    return
  end

  local frame = Private.GetSanitizedGlobal(key)
  if issecretvalue(frame) then return end
  if frame == nil then return nil, true end
  if type(frame) ~= "table"
    or type(frame.IsForbidden) ~= "function"
    or type(frame.IsObjectType) ~= "function"
    or frame:IsForbidden() then
    return
  end
  if frame:IsObjectType("Frame") then return frame end
  if requireFrame == false and (frame:IsObjectType("Texture") or frame:IsObjectType("FontString")) then
    return frame
  end
end
