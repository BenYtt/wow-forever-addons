-- Modified for ForeverAuras, 2026-10-23.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

---@class WeakAuras
WeakAuras = {}
ForeverAuras = WeakAuras
---@type table<string, string>
WeakAuras.L = {}
Private.frames = {}
Private.loadProfile = {filesStart = debugprofilestop(), prepare = {}, add = {}, modern = {}}

--- @alias uid string
--- @alias auraId string

--- @class state
--- @field id auraId
--- @field cloneId string?
--- @field show boolean?
--- @field changed boolean?
--- @field paused boolean?
--- @field remaining number?
--- @field autoHide boolean|string|nil
--- @field progressType "timed"|"static"|nil
--- @field expirationTime number?
--- @field duration number?
--- @field name any?
--- @field icon any?
--- @field value number?
--- @field total number?
--- @field inverse boolean?

--- @alias non_transmissable_field table<string, non_transmissable_field|boolean>

--- @class multiUnitUnits
--- @field nameplate table<string, boolean>
--- @field boss table<string, boolean>
--- @field arena table<string, boolean>
--- @field group table<string, boolean>
--- @field party table<string, boolean>
--- @field raid table<string, boolean>

--- @alias traverseFunction fun(): auraData

---@class WARegion : Frame
---@field state state
---@field states state[]
---@field regionType string
---@field FrameTick fun(self: WARegion)?
---@field UpdateValue fun(self: WARegion)?
---@field UpdateTime fun(self: WARegion)?
---@field Update fun(self: WARegion)?

--- @class Private
--- @field ActivateAuraEnvironment fun(id: auraId?, cloneId: string?, state: state?, states: state[]?, config: boolean?)
--- @field ActivateAuraEnvironmentForRegion fun(region: table, onlyConfig: boolean?)
--- @field ActivateAuraEnvironmentLifecycle fun(id: auraId)
--- @field DeactivateAuraEnvironmentLifecycle fun(id: auraId)
--- @field AddToWatchedTriggerDelay fun(id: auraId, triggerNum: number)
--- @field anchor_frame_types table<anchorFrameTypes, string>
--- @field anchor_frame_types_group table<anchorFrameTypes, string>
--- @field anim_function_strings table<string, string>
--- @field anim_presets table<string, table>
--- @field AuraWarnings AuraWarnings
--- @field AuraEnvironmentWrappedSystem AuraEnvironmentWrappedSystem
--- @field callbacks callbacks
--- @field category_event_prototype table<string, table<string, string>>
--- @field CanHaveTooltip fun(data: auraData): boolean
--- @field CheckTalentsForLoad fun(event: string)
--- @field ContainsCustomPlaceHolder fun(input: string): boolean
--- @field ContainsAnyPlaceHolders fun(input: string): boolean
--- @field ContainsPlaceHolders fun(input: string, placeholders: string, checkDoublePercent?: boolean): boolean
--- @field CreateSubscribableObject fun(): SubscribableObject
--- @field clones table<auraId, table<string, table>>
--- @field customActionsFunctions table<auraId, table<string, function?>>
--- @field DebugLog debugLog
--- @field dynamic_texts table<string, table>
--- @field EndEvent fun(state: state): boolean?
--- @field EnsureRegion fun(id: auraId, cloneId: string?): WARegion
--- @field ExecEnv table
--- @field event_prototypes table<string, prototypeData>
--- @field event_categories table<string, {name: string, default: string }>
--- @field Features Features
--- @field FindUnusedId fun(prefix: string?): string
--- @field FixGroupChildrenOrderForGroup fun(data: auraData)
--- @field frames table<string, table>
--- @field function_strings table<string, string>
--- @field GetDataByUID fun(uid: uid): auraData
--- @field GetErrorHandlerId fun(id: auraId, context: string): function
--- @field GetErrorHandlerUid fun(uid: uid, context: string): function
--- @field GetRegionByUID fun(uid: uid, cloneId: string): Region
--- @field glow_types table<string, string>
--- @field inverse_point_types table<string, string>
--- @field IsCLEUSubevent fun(subevent: string): boolean
--- @field IsDragonriding fun(): boolean
--- @field IsGroupType fun(data: auraData): boolean
--- @field item_slot_types string[]
--- @field LibSpecWrapper LibSpecWrapper
--- @field linked table<auraId, number>
--- @field loaded table<auraId, boolean>
--- @field LoadFunction fun(input: string): function
--- @field LoadOptions fun(msg: string?): boolean
--- @field maxTimerDuration number
--- @field multiUnitUnits multiUnitUnits
--- @field non_transmissable_fields table<string, non_transmissable_field>
--- @field non_transmissable_fields_v2000 table<string, non_transmissable_field>
--- @field orientation_types table<string, string>
--- @field orientation_with_circle_types table<string, string>
--- @field ParseNumber fun (numString: string|number): number?, string?
--- @field PreShowModels fun()
--- @field PrintHelp fun()
--- @field QuotedString fun(input: string): string
--- @field regionOptions table<string, table>
--- @field regions table<auraId, table>
--- @field regionTypes table<string, table>
--- @field reset_ranged_swing_spells table<number, boolean>
--- @field reset_swing_spells table<number, boolean>
--- @field noreset_swing_spells table<number, boolean>
--- @field RunCustomTextFunc fun(region: table, f: function): string?
--- @field spark_rotation_types table<string, string>
--- @field spec_types string[]
--- @field spec_types_3 string[]
--- @field spec_types_2 string[]
--- @field StartProfileAura fun(id: auraId)
--- @field StartProfileSystem fun(system: string)
--- @field StopProfileAura fun(id: auraId)
--- @field StopProfileSystem fun(system: string)
--- @field subRegionOptions table<string, table>
--- @field subRegionTypes table<string, table>
--- @field tick_placement_modes table<string, string>
--- @field tinySecondFormat fun(value: string|number): string?
--- @field TraverseAll fun(data: auraData): traverseFunction, auraData
--- @field TraverseAllChildren fun(data: auraData): traverseFunction, auraData
--- @field TraverseGroups fun(data: auraData): traverseFunction, auraData
--- @field TraverseLeafs fun(data: auraData): traverseFunction, auraData
--- @field TraverseLeafsOrAura fun(data: auraData): traverseFunction, auraData
--- @field TraverseParents fun(data: auraData): traverseFunction, auraData
--- @field TraverseSubGroups fun(data: auraData): traverseFunction, auraData
--- @field triggerTypes table<string, table>
--- @field triggerTypesOptions table<string, any>
--- @field UIDtoID fun(uid: uid): auraId
--- @field UnitEventList table<string, boolean>
--- @field UnitPlayerControlledFixed fun(unit: string): boolean
--- @field UpdatedTriggerState fun(id: auraId)
--- @field validate fun(input: table, default:table)
--- @field watched_trigger_events table<auraId, table<integer, table<integer, boolean>>>
--- @field RegisterRegionType fun(regionType: string, createFunction: function, modifyFunction: function, defaults: table, properties: table|function|nil, validate: function?))

--- @alias triggerTypes
--- | "aura"
--- | "aura2"
--- | "custom"

--- @alias anchorFrameTypes
--- | "SCREEN"
--- | "PRD"
--- | "MOUSE"
--- | "SELECTFRAME"
--- | "NAMEPLATE"
--- | "UNITFRAME"
--- | "CUSTOM"

--- @class triggerData
--- @field buffShowOn string
--- @field debuffType string
--- @field essence number?
--- @field event string|nil
--- @field instance_size table|nil
--- @field itemName string?
--- @field itemSetName string?
--- @field itemTypeName table|nil
--- @field range number?l
--- @field realSpellName string?
--- @field rune number?
--- @field spellName string?
--- @field subeventPrefix string?
--- @field subeventSuffix string?
--- @field type triggerTypes
--- @field unit string?
--- @field use_alwaystrue boolean|nil
--- @field use_ignoreoverride boolean|nil
--- @field use_showOn boolean|nil

---@class prototypeDataArgs
---@field name string
---@field required boolean?
---@field display string
---@field type "unit"|nil
---@field init "string"|nil
---@field values any
---@field desc string?
---@field store boolean?
---@field test string?

---@class prototypeData
---@field durationFunc (fun(trigger: triggerData): number, number, boolean?)|nil
---@field init (fun(trigger: triggerData):string?)|nil
---@field useModRate boolean?
---@field timedrequired boolean?
---@field GetNameAndIcon (fun(trigger: triggerData): string?, string?)|nil
---@field iconFunc (fun(trigger: triggerData): string?)|nil
---@field loadFunc (fun(trigger: triggerData): nil)|nil
---@field nameFunc (fun(trigger: triggerData): string?)|nil
---@field events (fun(trigger: triggerData): table)|nil
---@field internal_events (fun(trigger: triggerData): table)|nil
---@field name string
---@field statesParameter "unit"|"one"|"all"|nil
---@field progressType "timed"|"static"|"none"

--- @class triggerUntriggerData
--- @field trigger triggerData
--- @field untrigger triggerData

--- @class conditionCheck
--- @field variable string
--- @field trigger number
--- @field checks conditionCheck[]|nil

--- @class conditionChanges
--- @field property string

--- @class conditionData
--- @field check conditionCheck
--- @field changes conditionChanges

--- @class subRegionData

--- @class actionData
--- @field do_glow boolean
--- @field do_message boolean
--- @field do_sound boolean
--- @field message string
--- @field message_type string


--- @class actions
--- @field start actionData
--- @field finish actionData

--- @class load
--- @field use_realm boolean
--- @field itemtypeequipped table
--- @field size table

--- @alias regionTypes
--- | "aurabar"
--- | "dynamicgroup"
--- | "fallback"
--- | "group"
--- | "icon"
--- | "model"
--- | "progresstexture"
--- | "stopmotion"
--- | "text"
--- | "texture"

--- @class information
--- @field forceEvents boolean|nil
--- @field ignoreOptionsEventErrors boolean|nil
--- @field groupOffset boolean|nil

--- @alias dynamicGroupCenterType
--- | "LR"
--- | "RL"
--- | "CLR"
--- | "CRL"

--- @alias dynamicGroupGridType
--- | "RU"
--- | "UR"
--- | "LU"
--- | "UL"
--- | "RD"
--- | "DR"
--- | "LD"
--- | "DL"
--- | "HD"
--- | "HU"
--- | "VR"
--- | "VL"
--- | "DH"
--- | "UH"
--- | "LV"
--- | "RV"
--- | "HV"
--- | "VH"

--- @alias dynamicGroupCircularTypes
--- | "RADIUS"
--- | "SPACING"

--- @alias ColorArray {[1]: number, [2]: number, [3]: number, [4]: number }

--- @class auraData
--- @field anchorFrameType anchorFrameTypes?
--- @field animate boolean?
--- @field arcLength number?
--- @field actions actions?
--- @field border boolean?
--- @field borderBackdrop string?
--- @field borderColor ColorArray?
--- @field borderEdge string?
--- @field borderOffset number?
--- @field borderInset number?
--- @field borderSize number?
--- @field centerType dynamicGroupCenterType?
--- @field conditions conditionData[]?
--- @field constantFactor dynamicGroupCircularTypes
--- @field controlledChildren auraId[]?
--- @field displayText string?
--- @field frameStrata number?
--- @field fullCircle boolean?
--- @field gridType dynamicGroupGridType?
--- @field gridWidth number?
--- @field rowSpace number?
--- @field columnSpace number?
--- @field grow string?
--- @field id auraId
--- @field internalVersion number
--- @field information information
--- @field load load
--- @field limit number?
--- @field orientation string?
--- @field parent auraId?
--- @field radius number?
--- @field rotation number?
--- @field regionType regionTypes
--- @field scale number?
--- @field selfPoint AnchorPoint
--- @field subRegions subRegionData?
--- @field triggers triggerUntriggerData[]
--- @field url string?
--- @field useLimit boolean?
--- @field xOffset number?
--- @field yOffset number?

--- @class LibCustomGlow-1.0
--- @field ButtonGlow_Start fun(frame: Frame)
--- @field ButtonGlow_Stop fun(frame: Frame)
--- @field AutoCastGlow_Start fun(frame: Frame)
--- @field AutoCastGlow_Stop fun(frame: Frame)
--- @field PixelGlow_Start fun(frame: Frame)
--- @field PixelGlow_Stop fun(frame: Frame)

--- @class LibGetFrame-1.0
--- @field GetUnitFrame fun(unit: string)
--- @field GetUnitNameplate fun(unit: string)
--- @field StartProfile fun()
--- @field StopProfile fun()
--- @field GetProfileData fun(): table

--- @class LibSerialize
--- @field SerializeEx fun(self: LibSerialize,options: table, input: any)
--- @field Deserialize fun(self: LibSerialize, input: string): table

--- @class LibDeflate
--- @field CompressDeflate fun(self: LibDeflate, input: string, options: table): string
--- @field EncodeForPrint fun(self: LibDeflate, input: string): string)
--- @field EncodeForWoWAddonChannel fun(self: LibDeflate, input: string): string
--- @field DecodeForPrint fun(self: LibDeflate, input: string): string
--- @field DecodeForWoWAddonChannel fun(self: LibDeflate, input: string): string
--- @field DecompressDeflate fun(self: LibDeflate, input: string): string

--- @class LibDBIcon-1.0
--- @field Hide fun(self: LibDBIcon-1.0, name: string)
--- @field Register fun(self: LibDBIcon-1.0, name: string, broker: table, options: table)
--- @field Show fun(self: LibDBIcon-1.0, name: string)

--- @class LibSharedMedia-3.0
--- @field Fetch fun(self: LibSharedMedia-3.0, mediaType: string, name: string)
--- @field HashTable fun(self: LibSharedMedia-3.0, mediaType: string): table<string, string>
--- @field Register fun(self: LibSharedMedia-3.0, mediaType: string, name: string, path: string|number, flags: number?)
--- @field RegisterCallback fun(self: LibSharedMedia-3.0, callbackType: string, callback: fun(_: any, mediaType: string, key: string))
--- @field LOCALE_BIT_western number
--- @field LOCALE_BIT_ruRU number

--- @class LibCompress
--- @field Decompress fun(self: LibCompress, input: string): string

--- @class AceTimer-3.0
--- @field Embed fun(self: AceTimer-3.0, t: table)

WeakAuras.normalWidth = 1.3
WeakAuras.halfWidth = WeakAuras.normalWidth / 2
WeakAuras.doubleWidth = WeakAuras.normalWidth * 2
local versionStringFromToc = C_AddOns.GetAddOnMetadata("ForeverAuras", "Version")
local versionString = "1.1.0"
local buildTime = "2026-10-23"

-- Prerelease labels are case-insensitive; packages use the requested BETA spelling.
if not versionString:lower():find("beta", 1, true) then
  WeakAuras.buildType = "release"
else
  WeakAuras.buildType = "beta"
end

WeakAuras.versionString = versionStringFromToc
WeakAuras.buildTime = buildTime
WeakAuras.newFeatureString = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0|t"
WeakAuras.BuildInfo = select(4, GetBuildInfo())

WeakAuras.displayName = "ForeverAuras"

WeakAuras.prettyPrint = function(...)
  print("|cff9900ffForeverAuras:|r ", ...)
end

-- Force enable ForeverAurasCompanion and Archive because some addon managers interfere with it
C_AddOns.EnableAddOn("ForeverAurasCompanion")
C_AddOns.EnableAddOn("ForeverAurasArchive")

local libsAreOk = true
function WeakAuras.IsLibsOK()
  return libsAreOk
end

local clientVersion = GetBuildInfo()
local isForeverClient = type(clientVersion) == "string" and clientVersion:match("^1%.60%.") ~= nil and WeakAuras.BuildInfo >= 16000 and WeakAuras.BuildInfo < 16100
-- Retail 12.x shares the Forever client's secret-value API, so it is allowed
-- for testing while Forever is down. Forever stays the only supported game.
local isRetailClient = type(WeakAuras.BuildInfo) == "number" and WeakAuras.BuildInfo >= 120000 and WeakAuras.BuildInfo < 130000
WeakAuras.IsRetailClient = function() return isRetailClient end

if not isForeverClient and not isRetailClient then
  libsAreOk = false
  StaticPopupDialogs["WeakAuras_UNSUPPORTED_CLIENT"] = {
    text = "ForeverAuras supports World of Warcraft: Forever only.",
    button1 = OKAY,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false,
    preferredIndex = 5,
  }
  StaticPopup_Show("WeakAuras_UNSUPPORTED_CLIENT")
  return
end

do
  local StandAloneLibs = {
    "LibStub"
  }
  local LibStubLibs = {
    "CallbackHandler-1.0",
    "AceTimer-3.0",
    "AceSerializer-3.0",
    "AceComm-3.0",
    "LibSharedMedia-3.0",
    "LibDataBroker-1.1",
    "LibCompress",
    "SpellRange-1.0",
    "LibCustomGlow-1.0-foreverauras",
    "LibDBIcon-1.0",
    "LibGetFrame-1.0",
    "LibSerialize",
  }
  do
    tinsert(LibStubLibs, "LibSpecialization-ForeverAuras")
    if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
    AddonCompartmentFrame:RegisterAddon({
      text = WeakAuras.displayName,
      icon = "Interface\\AddOns\\ForeverAuras\\Media\\Textures\\foreverauras_logo_64.tga",
      registerForAnyClick = true,
      notCheckable = true,
      func = function(button, menuInputData, menu)
        local mouseButton = menuInputData.buttonName
        if mouseButton == "LeftButton" then
          if IsShiftKeyDown() then
            if not (WeakAuras.IsOptionsOpen()) then
              WeakAuras.Toggle()
            end
          else
            WeakAuras.OpenOptions()
          end
        elseif mouseButton == "MiddleButton" then
          WeakAuras.ToggleMinimap()
        else
          WeakAurasProfilingFrame:Toggle()
        end
      end,
      funcOnEnter = function(button)
        MenuUtil.ShowTooltip(button, function(tooltip)
          WeakAuras.GenerateTooltip(true, tooltip)
        end)
      end,
      funcOnLeave = function(button)
        MenuUtil.HideTooltip(button)
      end,
    })
  end
  end -- optional addon compartment
  -- Archivist is embedded in the addon namespace, not installed globally.
  if not Private.Archivist then
    libsAreOk = false
    WeakAuras.prettyPrint("Missing library:", "Archivist")
  end
  for _, lib in ipairs(StandAloneLibs) do
    if not _G[lib] then
        libsAreOk = false
        WeakAuras.prettyPrint("Missing library:", lib)
    end
  end
  if LibStub then
    for _, lib in ipairs(LibStubLibs) do
        if not LibStub:GetLibrary(lib, true) then
          libsAreOk = false
          WeakAuras.prettyPrint("Missing library:", lib)
        end
    end
  else
    libsAreOk = false
  end
end

---@type ForeverAurasSaved
-- Saved settings are initialized at ADDON_LOADED, after the client restores them.
-- Independent settings: migration from other addons is intentionally not automatic.

if not libsAreOk then
  C_Timer.After(1, function()
    WeakAuras.prettyPrint("ForeverAuras is missing necessary libraries. Please reinstall a proper package.")
  end)
end

-- These function stubs are defined here to reduce the number of errors that occur if ForeverAuras.lua fails to compile
--- @type fun(regionType: string, createFunction: function, modifyFunction: function, defaults: table, properties: table|function|nil, validate: function?))
function Private.RegisterRegionType(_, _, _ ,_)
end

---@type fun(regionType: string, createOptions: function, icon: string|function, displayName: string, createThumbnail: function?, modifyThumbnail: function?, description: string?, templates: table?, getAnchors: function?)
---@diagnostic disable-next-line: duplicate-set-field
function Private.RegisterRegionOptions(_, _ , _ ,_ )
end

function Private.StartProfileSystem(_)
end

function Private.StartProfileAura(_)
end

function Private.StopProfileSystem(_)
end

function Private.StopProfileAura(_)
end

---@type fun()
function Private.StartProfileUID()
end

---@type fun()
function Private.StopProfileUID()
end

Private.ExecEnv = {}

-- If ForeverAuras shuts down due to being installed on the wrong target, keep the bindings from erroring
--- @type fun(type: string)
---@diagnostic disable-next-line: duplicate-set-field
function WeakAuras.StartProfile(_)
end

---@diagnostic disable-next-line: duplicate-set-field
function WeakAuras.StopProfile()
end

---@diagnostic disable-next-line: duplicate-set-field
function WeakAuras.PrintProfile()
end

function WeakAuras.CountWagoUpdates()
  -- The Companion may query this fork; it does not provide updates for it.
  return 0
end

function WeakAuras.PurgeSecrets(tbl)
  for k, v in pairs(tbl) do
    if issecretvalue(v) then
      tbl[k] = nil
    end
  end
end

function WeakAuras.IsDurationObject(duration)
  local t = type(duration)
  if t == "userdata" and duration.GetRemainingDuration then
    return true
  end
  return false
end

-- Handler timing for profiling. Each ForeverAuras file takes its CreateFrame
-- and hooksecurefunc through Private.TimedAPI(label); scripts and hooks set
-- through them are timed as profiling systems named "<label> <script>" while
-- profiling runs, so /fa pprint and /fa phitch cover event handlers, OnUpdate
-- scripts and Blizzard hooks that have no profiling of their own. When
-- profiling is off a wrapped handler costs one extra function call.
-- Secure and protected frames are never wrapped.
Private.handlerTiming = false

-- Ends the system and passes the handler's return values through.
local function StopTimed(label, ...)
  Private.StopProfileSystem(label)
  return ...
end

-- Wraps fn so that it is timed under label while profiling runs. OnEvent
-- handlers are timed per event; the label is only built while profiling.
local function Timed(label, fn, perEvent)
  if type(fn) ~= "function" then return fn end
  return function(...)
    if not Private.handlerTiming then return fn(...) end
    local name = label
    if perEvent then
      local event = select(2, ...)
      if type(event) == "string" then name = label .. " " .. event end
    end
    Private.StartProfileSystem(name)
    return StopTimed(name, fn(...))
  end
end

-- Script handlers that are timed; other scripts are passed through untouched.
local timedScripts = {OnEvent = true, OnUpdate = true, OnShow = true, OnHide = true,
  OnSizeChanged = true, OnCooldownDone = true, OnFinished = true}

function Private.TimedAPI(label)
  local frameAPI = CreateFrame
  local hookAPI = hooksecurefunc
  -- CreateFrame replacement: the frame's own SetScript and HookScript wrap
  -- timed scripts. Only plain frames (no template, or BackdropTemplate) get the
  -- wrapped methods, so frames that Blizzard code also drives (secure buttons,
  -- tooltips, scroll and other templates) keep the client methods untouched.
  -- Templates that add no Blizzard-driven scripts; frames made from them are
  -- wrapped like plain frames.
  local plainTemplates = {BackdropTemplate = true, BackdropTemplateWeakAuras = true,
    DisableUntrustedLayoutScriptsTemplate = true, CooldownFrameTemplate = true}
  local function TimedCreateFrame(frameType, name, parent, template, ...)
    local frame = frameAPI(frameType, name, parent, template, ...)
    if template ~= nil and not plainTemplates[template] then return frame end
    if frame.IsProtected and frame:IsProtected() then return frame end
    local setScript, hookScript = frame.SetScript, frame.HookScript
    frame.SetScript = function(self, script, fn, ...)
      if timedScripts[script] then fn = Timed(label .. " " .. script, fn, script == "OnEvent") end
      return setScript(self, script, fn, ...)
    end
    frame.HookScript = function(self, script, fn, ...)
      if timedScripts[script] then fn = Timed(label .. " " .. script, fn, script == "OnEvent") end
      return hookScript(self, script, fn, ...)
    end
    return frame
  end
  -- hooksecurefunc replacement; the hook is named after the hooked method.
  local function TimedHook(target, method, fn)
    if type(target) == "string" then
      return hookAPI(target, Timed(label .. " hook " .. target, method))
    end
    return hookAPI(target, method, Timed(label .. " hook " .. tostring(method), fn))
  end
  -- HookScript on frames created elsewhere (Blizzard frames).
  local function TimedHookScript(frame, script, fn)
    return frame:HookScript(script, Timed(label .. " " .. script, fn, script == "OnEvent"))
  end
  -- C_Timer replacement: callbacks of After, NewTimer and NewTicker are timed
  -- as "<label> timer"; everything else is the client's C_Timer.
  local timerLabel = label .. " timer"
  local TimedTimer = setmetatable({
    After = function(delay, fn) return C_Timer.After(delay, Timed(timerLabel, fn)) end,
    NewTimer = function(delay, fn, ...) return C_Timer.NewTimer(delay, Timed(timerLabel, fn), ...) end,
    NewTicker = function(delay, fn, ...) return C_Timer.NewTicker(delay, Timed(timerLabel, fn), ...) end,
  }, {__index = C_Timer})
  return TimedCreateFrame, TimedHook, TimedHookScript, TimedTimer
end

-- Frames and hooks created by an aura's custom code, timed under the aura's
-- name ("aura <id> OnUpdate", ...). One set per aura, created on first use.
local auraAPIs = {}
function Private.AuraTimedAPI(id)
  local api = auraAPIs[id]
  if not api then
    local createFrame, hook = Private.TimedAPI("aura " .. tostring(id))
    api = {CreateFrame = createFrame, hooksecurefunc = hook}
    auraAPIs[id] = api
  end
  return api
end
