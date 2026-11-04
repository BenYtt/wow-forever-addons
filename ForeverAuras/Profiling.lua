-- Modified for ForeverAuras, 2026-09-18.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then
  return
end
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

---@class WeakAuras
local WeakAuras = WeakAuras
local L = WeakAuras.L
local prettyPrint = WeakAuras.prettyPrint
local LGF = LibStub("LibGetFrame-1.0")
-- LibCustomGlow's per-frame glow handlers are timed under "glow ..." while
-- profiling runs (see Timed in the library).
local LCG = LibStub("LibCustomGlow-1.0-foreverauras", true)
if LCG then
  LCG.StartProfiling = function(name) Private.StartProfileSystem(name) end
  LCG.StopProfiling = function(name) Private.StopProfileSystem(name) end
end

local profileData = {}
profileData.systems = {}
profileData.auras = {}

local currentProfileState, ProfilingTimer

local table_to_string
table_to_string = function(tbl, depth)
  if depth and depth >= 3 then
    return "{ ... }"
  end
  local str
  for k, v in pairs(tbl) do
    if type(v) ~= "userdata" then
      if type(v) == "table" then
        v = table_to_string(v, (depth and depth + 1 or 1))
      elseif type(v) == "function" then
        v = "function"
      elseif type(v) == "string" then
        v = '"' .. v .. '"'
      end

      if type(k) == "string" then
        k = '"' .. k .. '"'
      end

      str = (str and str .. "|cff999999,|r " or "|cff999999{|r ") .. "|cffffff99[" .. tostring(k) .. "]|r |cff999999=|r |cffffffff" .. tostring(v) .. "|r"
    end
  end
  return (str or "{ ") .. " }"
end

WeakAurasProfilingReportMixin = {}
function WeakAurasProfilingReportMixin:OnShow()
  if self.initialised then
    return
  end
  self.initialised = true

  ButtonFrameTemplate_HidePortrait(self)
  self:SetTitle(L["ForeverAuras Profiling Report"])
  self:SetSize(500, 300)
end

function WeakAurasProfilingReportMixin:ClearText()
  self.ScrollBox.messageFrame:SetText("")
end

function WeakAurasProfilingReportMixin:AddText(v)
  if not v then
    return
  end
  --- @type string?
  local m = self.ScrollBox.messageFrame:GetText()
  if m ~= "" then
    m = m .. "|n"
  end
  if type(v) == "table" then
    v = table_to_string(v)
  end
  self.ScrollBox.messageFrame.originalText = m .. v
  self.ScrollBox.messageFrame:SetText(self.ScrollBox.messageFrame.originalText)
end

local hitchActive = false
local function StartProfiling(map, id)
  if not map[id] then
    map[id] = {}
    map[id].count = 1
    map[id].start = debugprofilestop()
    map[id].elapsed = 0
    map[id].spike = 0
    -- Hitch capture also attributes Lua allocation (see HitchAccumulate).
    if hitchActive then map[id].memStart = collectgarbage("count") end
    return
  end

  if map[id].count == 0 then
    map[id].count = 1
    map[id].start = debugprofilestop()
    if hitchActive then map[id].memStart = collectgarbage("count") end
  else
    map[id].count = map[id].count + 1
  end
end

local function StopProfiling(map, id)
  -- A handler that began before profiling (re)started has no entry to stop.
  if not map[id] then return end
  map[id].count = map[id].count - 1
  if map[id].count == 0 then
    local elapsed = debugprofilestop() - map[id].start
    map[id].elapsed = map[id].elapsed + elapsed
    if elapsed > map[id].spike then
      map[id].spike = elapsed
    end
  end
end

-- Hitch capture (/fa phitch): while active, every finished measurement is also
-- added to a per-frame bucket so a slow frame can be broken down afterwards.
-- The buckets live beside the normal totals and are only touched in this mode.
local hitch = {active = false, threshold = 30, touched = {}, events = {}, counts = {}}

-- Counts a widget call of note (container refreshes, reparenting, texture and
-- font changes) in the current frame's bucket. These calls cost the client
-- layout or loading time that no Lua profiler sees, so the counts are printed
-- with a slow frame to show what ForeverAuras asked of the client in it.
function Private.HitchCount(name, n)
  if hitch.active then hitch.counts[name] = (hitch.counts[name] or 0) + (n or 1) end
end

-- Adds one finished measurement to the current frame's bucket for map[id]:
-- its time, and the Lua memory it allocated (garbage drives the collector's
-- steps, which the time of no handler shows).
local function HitchAccumulate(map, id, elapsed)
  local entry = map[id]
  if not entry.frame or entry.frame == 0 then
    entry.frame = 0
    entry.frameMem = 0
    hitch.touched[#hitch.touched + 1] = {entry = entry, name = id, aura = map == profileData.auras}
  end
  entry.frame = entry.frame + elapsed
  if entry.memStart then
    local delta = collectgarbage("count") - entry.memStart
    if delta > 0 then entry.frameMem = (entry.frameMem or 0) + delta end
  end
end

-- Same as StopProfiling, plus the per-frame bucket used by hitch capture.
local function StopProfilingHitch(map, id)
  -- A handler that began before profiling (re)started has no entry to stop.
  if not map[id] then return end
  map[id].count = map[id].count - 1
  if map[id].count == 0 then
    local elapsed = debugprofilestop() - map[id].start
    map[id].elapsed = map[id].elapsed + elapsed
    if elapsed > map[id].spike then
      map[id].spike = elapsed
    end
    HitchAccumulate(map, id, elapsed)
  end
end

-- Helper functions used by the built-in cooldown triggers, timed one by one
-- while profiling runs ("api ..." systems) to see which part of a trigger is
-- expensive. The original functions are put back when profiling stops.
local apiWrapped = {}
local function ApiTargets()
  return {
    {WeakAuras, "WeakAuras", {"GetSpellCooldown", "GetSpellCharges", "IsSpellKnownIncludingPet",
      "GetSpellCooldownDurationNoGCD", "GetSpellCooldownDuration", "GetSpellLossOfControlCooldown"}},
    {Private.ExecEnv, "ExecEnv", {"GetEffectiveSpellId", "GetSpellCooldownData", "GetSpellInfo", "GetSpellName"}},
    {Private, "Private", {"GetWandCooldownDuration", "GetSpellCooldownData", "GCDTextAlpha"}},
  }
end
local function StopApi(name, ...)
  Private.StopProfileSystem(name)
  return ...
end
local function WrapApis()
  for _, target in ipairs(ApiTargets()) do
    local tbl, prefix, keys = target[1], target[2], target[3]
    for _, key in ipairs(keys) do
      local fn = tbl and rawget(tbl, key)
      if type(fn) == "function" then
        local name = "api " .. prefix .. "." .. key
        apiWrapped[#apiWrapped + 1] = {tbl, key, fn}
        rawset(tbl, key, function(...)
          Private.StartProfileSystem(name)
          return StopApi(name, fn(...))
        end)
      end
    end
  end
end
local function UnwrapApis()
  for i = #apiWrapped, 1, -1 do
    local entry = apiWrapped[i]
    rawset(entry[1], entry[2], entry[3])
    apiWrapped[i] = nil
  end
end

local function StartProfileSystem(system)
  StartProfiling(profileData.systems, "wa")
  StartProfiling(profileData.systems, system)
end

local function StartProfileAura(id)
  StartProfiling(profileData.auras, id)
end

local function StopProfileSystem(system)
  StopProfiling(profileData.systems, "wa")
  StopProfiling(profileData.systems, system)
end

local function StopProfileAura(id)
  StopProfiling(profileData.auras, id)
end

local function StartProfileUID(uid)
  StartProfiling(profileData.auras, Private.UIDtoID(uid))
end

local function StopProfileUID(uid)
  StopProfiling(profileData.auras, Private.UIDtoID(uid))
end

function Private.ProfileRenameAura(oldid, id)
  profileData.auras[id] = profileData.auras[id]
  profileData.auras[oldid] = nil
end

local RegisterProfile = function(startType)
  if startType == "boss" then
    startType = "encounter"
  end
  local delayedStart
  if startType == "encounter" then
    WeakAurasProfilingFrame:UnregisterAllEvents()
    prettyPrint(L["Your next encounter will automatically be profiled."])
    WeakAurasProfilingFrame:RegisterEvent("ENCOUNTER_START")
    WeakAurasProfilingFrame:RegisterEvent("ENCOUNTER_END")
    currentProfileState = startType
    delayedStart = true
  elseif startType == "combat" then
    WeakAurasProfilingFrame:UnregisterAllEvents()
    prettyPrint(L["Your next instance of combat will automatically be profiled."])
    WeakAurasProfilingFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    WeakAurasProfilingFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    currentProfileState = startType
    delayedStart = true
  elseif startType == "autostart" then
    prettyPrint(L["Profiling automatically started."])
    currentProfileState = "profiling"
  elseif startType and startType:match("%d") then
    WeakAurasProfilingFrame:UnregisterAllEvents()
    local time = startType + 0
    prettyPrint(L["Profiling started. It will end automatically in %d seconds"]:format(time))
    ProfilingTimer = WeakAuras.timer:ScheduleTimer(WeakAuras.StopProfile, time)
    currentProfileState = "profiling"
  else
    WeakAurasProfilingFrame:UnregisterAllEvents()
    prettyPrint(L["Profiling started."])
    currentProfileState = "profiling"
  end
  WeakAurasProfilingFrame:UpdateButtons()
  return delayedStart
end

---@diagnostic disable-next-line: duplicate-set-field
function WeakAuras.StartProfile(startType)
  if currentProfileState == "profiling" then
    prettyPrint(L["Profiling already started."])
    return
  end

  if RegisterProfile(startType) then
    -- Scheduled for later
    return
  end

  profileData.systems = {}
  profileData.auras = {}
  profileData.systems.time = {}
  profileData.systems.time.start = debugprofilestop()
  profileData.systems.time.elapsed = nil
  profileData.systems.time.count = 1

  Private.StartProfileSystem = StartProfileSystem
  -- Times handlers set through Private.TimedAPI while profiling runs.
  Private.handlerTiming = true
  if #apiWrapped == 0 then WrapApis() end
  Private.StartProfileAura = StartProfileAura
  Private.StartProfileUID = StartProfileUID
  Private.StopProfileSystem = StopProfileSystem
  Private.StopProfileAura = StopProfileAura
  Private.StopProfileUID = StopProfileUID
  LGF.StartProfile()
end

local function doNothing() end

-- Hitch-capture variants of the stop functions; installed instead of the
-- normal ones by WeakAuras.StartHitchCapture.
local function StopProfileSystemHitch(system)
  StopProfilingHitch(profileData.systems, "wa")
  StopProfilingHitch(profileData.systems, system)
end

local function StopProfileAuraHitch(id)
  StopProfilingHitch(profileData.auras, id)
end

local function StopProfileUIDHitch(uid)
  StopProfilingHitch(profileData.auras, Private.UIDtoID(uid))
end

-- Summarises one frame interval (from one hitchFrame OnUpdate to the next):
-- its length, ForeverAuras time from the client's addon profiler (covers all
-- of the addon's code), the part covered by the ForeverAuras profiler, Lua
-- memory change, events of note and the most expensive systems and auras.
-- Returns the two report lines.
local function SummariseInterval(frameMs, memDelta)
  local addonMs
  if C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric and Enum.AddOnProfilerMetric then
    addonMs = C_AddOnProfiler.GetAddOnMetric(AddonName, Enum.AddOnProfilerMetric.LastTime)
  end
  local waEntry = profileData.systems.wa
  local tracked = waEntry and waEntry.frame or 0
  local systems, auras = {}, {}
  for _, t in ipairs(hitch.touched) do
    if t.name ~= "wa" and t.entry.frame >= 0.2 then
      tinsert(t.aura and auras or systems, t)
    end
  end
  local byTime = function(a, b) return a.entry.frame > b.entry.frame end
  sort(systems, byTime)
  sort(auras, byTime)
  local parts = {}
  for i = 1, math.min(14, #systems) do
    parts[#parts + 1] = ("%s %.1f"):format(systems[i].name, systems[i].entry.frame)
  end
  for i = 1, math.min(3, #auras) do
    parts[#parts + 1] = ("|cffffff99%s|r %.1f"):format(auras[i].name, auras[i].entry.frame)
  end
  -- The systems that allocated the most Lua memory in the interval.
  local allocators = {}
  for _, t in ipairs(hitch.touched) do
    if t.name ~= "wa" and not t.aura and (t.entry.frameMem or 0) >= 16 then allocators[#allocators + 1] = t end
  end
  sort(allocators, function(a, b) return a.entry.frameMem > b.entry.frameMem end)
  for i = 1, math.min(4, #allocators) do
    parts[#parts + 1] = ("|cffcc99ff%s|r +%.0fKB"):format(allocators[i].name, allocators[i].entry.frameMem)
  end
  local events = {}
  for event, count in pairs(hitch.events) do
    events[#events + 1] = count > 1 and (event .. "x" .. count) or event
  end
  -- Lua time of all addons together and of Blizzard's aura container code
  -- (which runs the native aura buttons of Modern displays), when the client
  -- reports them.
  local others = ""
  if C_AddOnProfiler and C_AddOnProfiler.GetOverallMetric and Enum.AddOnProfilerMetric then
    local metric = Enum.AddOnProfilerMetric.LastTime
    local all = C_AddOnProfiler.GetOverallMetric(metric)
    local ok, container = pcall(C_AddOnProfiler.GetAddOnMetric, "Blizzard_AuraContainer", metric)
    others = (" | all addons %s | AuraContainer %s"):format(all and ("%.1fms"):format(all) or "?",
      ok and type(container) == "number" and ("%.1fms"):format(container) or "?")
  end
  local header = ("%.0fms | FA %s | tracked %.1fms | mem %+.0fKB%s%s"):format(frameMs,
    addonMs and ("%.1fms"):format(addonMs) or "?", tracked, memDelta, others,
    #events > 0 and (" | " .. table.concat(events, " ")) or "")
  -- Widget calls of the interval (Private.HitchCount), most frequent first.
  local counts = {}
  for name, count in pairs(hitch.counts) do counts[#counts + 1] = {name = name, count = count} end
  sort(counts, function(a, b) return a.count > b.count end)
  for i = 1, math.min(8, #counts) do
    parts[#parts + 1] = ("|cff99ccff%s|r x%d"):format(counts[i].name, counts[i].count)
  end
  -- The other addons that took the most of the interval, so a slow frame
  -- that is not ForeverAuras' can be told apart (the client's own profiler).
  if frameMs >= hitch.threshold and C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric and Enum.AddOnProfilerMetric and C_AddOns and C_AddOns.GetNumAddOns then
    local metric = Enum.AddOnProfilerMetric.LastTime
    local addons = {}
    for i = 1, C_AddOns.GetNumAddOns() do
      local name = C_AddOns.GetAddOnInfo(i)
      if name and name ~= AddonName and C_AddOns.IsAddOnLoaded(i) then
        local ok, ms = pcall(C_AddOnProfiler.GetAddOnMetric, name, metric)
        if ok and type(ms) == "number" and ms >= 1 then addons[#addons + 1] = {name = name, ms = ms} end
      end
    end
    sort(addons, function(a, b) return a.ms > b.ms end)
    for i = 1, math.min(5, #addons) do
      parts[#parts + 1] = ("|cffff9966%s|r %.1fms"):format(addons[i].name, addons[i].ms)
    end
  end
  return header, #parts > 0 and ("   " .. table.concat(parts, ", ")) or nil
end

-- Runs at the start of every frame while hitch capture is active. Events are
-- dispatched before OnUpdate, so the frame in which combat starts or ends is
-- summarised one interval before the slow drawing it causes shows up. Each
-- interval's summary is therefore kept, and a slow interval is reported
-- together with the one before it.
local hitchFrame = CreateFrame("Frame")
hitchFrame:Hide()
hitchFrame:SetScript("OnUpdate", function(_, elapsed)
  local mem = collectgarbage("count")
  local frameMs = elapsed * 1000
  if hitch.lastMem then
    local header, details = SummariseInterval(frameMs, mem - hitch.lastMem)
    if frameMs >= hitch.threshold then
      if hitch.previous then
        prettyPrint("Before hitch: " .. hitch.previous[1])
        if hitch.previous[2] then print(hitch.previous[2]) end
      end
      prettyPrint("Hitch " .. header)
      if details then print(details) end
    end
    hitch.previous = {header, details}
  end
  hitch.lastMem = mem
  for i, t in ipairs(hitch.touched) do
    t.entry.frame = 0
    t.entry.frameMem = 0
    hitch.touched[i] = nil
  end
  wipe(hitch.events)
  wipe(hitch.counts)
end)
-- Combat and restriction changes are labelled in the report so transitions
-- can be told apart from other slow frames; the other labels mark the common
-- causes of display work outside combat changes (target, auras, cooldowns,
-- nameplates, roster), so a slow frame can be matched to what happened in it.
local hitchEvents = {PLAYER_REGEN_DISABLED = "+combat", PLAYER_REGEN_ENABLED = "-combat",
  ADDON_RESTRICTION_STATE_CHANGED = "restriction", PLAYER_ENTERING_WORLD = "loading",
  PLAYER_TARGET_CHANGED = "target", PLAYER_FOCUS_CHANGED = "focus", UPDATE_MOUSEOVER_UNIT = "mouseover",
  UNIT_AURA = "aura", SPELL_UPDATE_COOLDOWN = "cooldown", SPELL_UPDATE_USABLE = "usable",
  NAME_PLATE_UNIT_ADDED = "+plate", NAME_PLATE_UNIT_REMOVED = "-plate", GROUP_ROSTER_UPDATE = "roster",
  UNIT_PET = "pet", PLAYER_EQUIPMENT_CHANGED = "equip", UNIT_SPELLCAST_SUCCEEDED = "cast",
  ZONE_CHANGED_NEW_AREA = "zone", UI_SCALE_CHANGED = "scale", COOLDOWN_VIEWER_DATA_LOADED = "cdm"}
-- Unit events are only labelled for the player and its target.
local hitchUnitEvents = {UNIT_AURA = true, UNIT_SPELLCAST_SUCCEEDED = true}
hitchFrame:SetScript("OnEvent", function(_, event, unit)
  local label = hitchEvents[event]
  if hitchUnitEvents[event] then
    if unit ~= "player" and unit ~= "target" then return end
    label = label .. ":" .. unit
  end
  hitch.events[label] = (hitch.events[label] or 0) + 1
end)

-- /fa phitch [ms]: starts profiling and reports every frame slower than ms
-- (default 30) until /fa phitch is used again. The normal profiling report
-- stays available afterwards through /fa pprint.
function WeakAuras.ToggleHitchCapture(threshold)
  if hitch.active then
    hitch.active = false; hitchActive = false
    hitchFrame:Hide()
    hitchFrame:UnregisterAllEvents()
    WeakAuras.StopProfile()
    return
  end
  if currentProfileState == "profiling" then
    WeakAuras.StopProfile()
  end
  hitch.threshold = tonumber(threshold) or 30
  WeakAuras.StartProfile()
  if currentProfileState ~= "profiling" then return end
  hitch.active = true; hitchActive = true
  hitch.lastMem = nil
  hitch.previous = nil
  wipe(hitch.touched)
  wipe(hitch.events)
  wipe(hitch.counts)
  Private.StopProfileSystem = StopProfileSystemHitch
  Private.StopProfileAura = StopProfileAuraHitch
  Private.StopProfileUID = StopProfileUIDHitch
  for event in pairs(hitchEvents) do
    if hitchUnitEvents[event] then
      hitchFrame:RegisterUnitEvent(event, "player", "target")
    else
      hitchFrame:RegisterEvent(event)
    end
  end
  hitchFrame:Show()
  prettyPrint(("Hitch capture started: frames slower than %dms are reported. Type /fa phitch again to stop."):format(hitch.threshold))
  -- How much native aura content the Modern displays currently hold.
  if Private.BlizzardAuraDisplay and Private.BlizzardAuraDisplay.CountContainers then
    local displays, containers, shown = Private.BlizzardAuraDisplay.CountContainers()
    prettyPrint(("Modern displays active: %d, native containers: %d (%d shown)"):format(displays, containers, shown))
  end
end

-- /fa phitch login [ms] [seconds]: the next reload runs the hitch capture
-- from the moment the addon's saved variables are read, through login and
-- for `seconds` (default 20) after entering the world, then prints the slow
-- frames seen, the load time breakdown and the profile. One reload only.
local LOGIN_HITCH_SECONDS = 20
function WeakAuras.ArmLoginHitchCapture(threshold, seconds)
  if not Private.db then return end
  Private.db.hitchOnLogin = {threshold = tonumber(threshold) or 30, seconds = tonumber(seconds) or LOGIN_HITCH_SECONDS}
  prettyPrint(L["Hitch capture armed for the next reload: frames slower than %dms are reported from addon load until %d s after entering the world."]:format(
    Private.db.hitchOnLogin.threshold, Private.db.hitchOnLogin.seconds))
end

-- Called once the saved variables are read (ADDON_LOADED in ForeverAuras.lua).
function Private.StartLoginHitchCapture()
  local arm = Private.db and Private.db.hitchOnLogin
  if not arm then return end
  Private.db.hitchOnLogin = nil
  WeakAuras.ToggleHitchCapture(arm.threshold)
  if not hitch.active then return end
  local watcher = CreateFrame("Frame")
  watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
  watcher:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    prettyPrint(L["Entered the world; hitch capture continues for %d s."]:format(arm.seconds))
    C_Timer.After(arm.seconds, function()
      if hitch.active then WeakAuras.ToggleHitchCapture() end
      if Private.PrintLoadProfile then Private.PrintLoadProfile() end
      WeakAuras.PrintProfile()
    end)
  end)
end

---@diagnostic disable-next-line: duplicate-set-field
function WeakAuras.StopProfile()
  if currentProfileState ~= "profiling" then
    prettyPrint(L["Profiling not running."])
    return
  end

  prettyPrint(L["Profiling stopped."])

  -- Stopping profiling by any route also ends hitch capture.
  if hitch.active then
    hitch.active = false; hitchActive = false
    hitchFrame:Hide()
    hitchFrame:UnregisterAllEvents()
  end

  profileData.systems.time.elapsed = debugprofilestop() - profileData.systems.time.start
  profileData.systems.time.count = 0

  Private.StartProfileSystem = doNothing
  Private.handlerTiming = false
  UnwrapApis()
  Private.StartProfileAura = doNothing
  Private.StartProfileUID = doNothing
  Private.StopProfileSystem = doNothing
  Private.StopProfileAura = doNothing
  Private.StopProfileUID = doNothing
  LGF.StopProfile()

  currentProfileState = nil
  if WeakAurasProfilingFrame then
    WeakAurasProfilingFrame:UnregisterAllEvents()
    WeakAurasProfilingFrame:UpdateButtons()
  end

  if ProfilingTimer then
    WeakAuras.timer:CancelTimer(ProfilingTimer)
    ProfilingTimer = nil
  end
end

function WeakAuras.ToggleProfile()
  if not profileData.systems.time or profileData.systems.time.count ~= 1 then
    WeakAuras.StartProfile()
  else
    WeakAuras.StopProfile()
  end
end

local function CancelScheduledProfile()
  prettyPrint(L["Your scheduled automatic profile has been cancelled."])
  currentProfileState = nil
  WeakAurasProfilingFrame:UnregisterAllEvents()
  WeakAurasProfilingFrame:UpdateButtons()
end

WeakAuras.CancelScheduledProfile = CancelScheduledProfile

local function AutoStartStopProfiling(frame, event)
  if event == "ENCOUNTER_START" or event == "PLAYER_REGEN_DISABLED" then
    WeakAuras.StartProfile("autostart")
  elseif event == "ENCOUNTER_END" or event == "PLAYER_REGEN_ENABLED" then
    WeakAuras.StopProfile()
  end
end

local function ColoredSpike(spike)
  local r, g, b
  if spike < 2 then
    r, g, b = WeakAuras.GetHSVTransition(spike / 2, 0, 1, 0, 1, 1, 1, 0, 1)
  elseif spike < 2.5 then
    r, g, b = WeakAuras.GetHSVTransition((spike - 2) * 2, 1, 1, 0, 1, 1, 0.65, 0, 1)
  elseif spike < 3 then
    r, g, b = WeakAuras.GetHSVTransition((spike - 2.5) * 2, 1, 0.65, 0, 1, 1, 0, 0, 1)
  else
    r, g, b = 1, 0, 0
  end
  return ("|cff%02x%02x%02x%.2fms|r"):format(r * 255, g * 255, b * 255, spike)
end

local function PrintOneProfile(popup, name, map, total)
  if map.count ~= 0 then
    popup:AddText(name .. "  ERROR: count is not zero:" .. " " .. map.count)
  end

  local percent = ""
  if total then
    percent = (", %.2f%%"):format(100 * map.elapsed / total)
  end

  local spikeInfo = ""
  if map.spike then
    spikeInfo = ColoredSpike(map.spike)
  end

  popup:AddText(("%s |cff999999%.2fms%s (%s)|r"):format(name, map.elapsed, percent, spikeInfo))
end

local function SortProfileMap(map, sortField)
  local result = {}
  for k in pairs(map) do
    tinsert(result, k)
  end

  sort(result, function(a, b)
    if sortField then
      local x, y = map[a][sortField], map[b][sortField]
      if x and y then
        return x > y
      end
    end

    return map[a].elapsed > map[b].elapsed
  end)

  return result
end

local function TotalProfileTime(map)
  local total = 0
  for k, v in pairs(map) do
    if k ~= "time" and k ~= "wa" then
      total = total + v.elapsed
    end
  end
  return total
end

local function unitEventToMultiUnit(event)
  local count
  event, count = event:gsub("nameplate%d+$", "nameplate")
  if count == 1 then
    return event
  end
  event, count = event:gsub("boss%d$", "boss")
  if count == 1 then
    return event
  end
  event, count = event:gsub("arena%d$", "arena")
  if count == 1 then
    return event
  end
  event, count = event:gsub("raid%d+$", "group")
  if count == 1 then
    return event
  end
  event, count = event:gsub("raidpet%d+$", "group")
  if count == 1 then
    return event
  end
  event, count = event:gsub("party%d$", "party")
  if count == 1 then
    return event
  end
  event, count = event:gsub("partypet%d$", "party")
  return event
end

---@diagnostic disable-next-line: duplicate-set-field
function WeakAuras.PrintProfile()
  local popup = WeakAurasProfilingReport
  if not profileData.systems.time then
    prettyPrint(L["No Profiling information saved."])
    return
  end

  if profileData.systems.time.count == 1 then
    prettyPrint(L["Profiling still running, stop before trying to print."])
    return
  end

  popup:ClearAllPoints()
  if WeakAurasProfilingFrame and WeakAurasProfilingFrame:IsShown() then
    popup:SetParent(WeakAurasProfilingFrame)
    popup:SetPoint("TOPLEFT", WeakAurasProfilingFrame, "TOPRIGHT", 5, 0)
  else
    popup:SetParent(UIParent)
    if ForeverAurasSaved.ProfilingWindow then
      popup:SetPoint("TOPLEFT", UIParent, "TOPLEFT", ForeverAurasSaved.ProfilingWindow.xOffset or 0, ForeverAurasSaved.ProfilingWindow.yOffset or 0)
    else
      popup:SetPoint("CENTER")
    end
  end

  popup:ClearText()

  PrintOneProfile(popup, "|cff9900ffTotal time:|r", profileData.systems.time)
  PrintOneProfile(popup, "|cff9900ffTime inside WA:|r", profileData.systems.wa)
  popup:AddText(string.format("|cff9900ffTime spent inside WA:|r %.2f%%", 100 * profileData.systems.wa.elapsed / profileData.systems.time.elapsed))

  popup:AddText("")
  popup:AddText("Note: Not every aspect of each aura can be tracked.")

  popup:AddText("")
  popup:AddText("|cff9900ffAuras:|r")
  local total = TotalProfileTime(profileData.auras)
  popup:AddText("Total time attributed to auras: ", floor(total) .. "ms")
  for _, k in ipairs(SortProfileMap(profileData.auras), "spike") do
    PrintOneProfile(popup, k, profileData.auras[k], total)
  end

  popup:AddText("")
  popup:AddText("|cff9900ffSystems:|r")

  -- make a new table for system data with multiUnits grouped
  local systemRegrouped = {}
  for k, v in pairs(profileData.systems) do
    local event = unitEventToMultiUnit(k)
    if systemRegrouped[event] == nil then
      systemRegrouped[event] = CopyTable(v)
    else
      if v.elapsed then
        systemRegrouped[event].elapsed = (systemRegrouped[event].elapsed or 0) + v.elapsed
      end
      if v.spike then
        systemRegrouped[event].spike = (systemRegrouped[event].spike or 0) + v.spike
      end
    end
  end

  for i, k in ipairs(SortProfileMap(systemRegrouped)) do
    if k ~= "time" and k ~= "wa" then
      PrintOneProfile(popup, k, systemRegrouped[k], profileData.systems.wa.elapsed)
    end
  end

  popup:AddText("")
  popup:AddText("|cff9900ffLibGetFrame:|r")
  for id, map in pairs(LGF.GetProfileData()) do
    PrintOneProfile(popup, id, map)
  end

  popup:Show()
end

WeakAurasProfilingLineMixin = {
  spikeTooltip = L["Maximum time used on a single frame"],
  timeTooltip = L["Cumulated time used during profiling"],
}

function WeakAurasProfilingLineMixin:Init(e)
  -- button.pct:SetText(pct)
  self.progressBar.name:SetText(e.name)
  self.time:SetText(("%.2fms"):format(e.time))
  self.spike:SetText(ColoredSpike(e.spike))
  self.progressBar:SetValue(e.pct)
end

local COLUMN_INFO = {
  {
    title = L["Name"],
    width = 1,
    attribute = "name",
  },
  {
    title = L["Time"],
    width = 100,
    attribute = "time",
  },
  {
    title = L["Spike"],
    width = 100,
    attribute = "spike",
  },
}

local function ApplyAlternateState(frame, alternate)
  if alternate then
    frame.progressBar:SetStatusBarColor(0.7, 0.7, 0.7, 0.7)
  else
    frame.progressBar:SetStatusBarColor(0.5, 0.5, 0.5, 0.7)
  end
end

local modes = {
  L["Auras"],
  L["Systems"],
}
WeakAurasProfilingMixin = {}

local MinPanelWidth, MinPanelHeight = 500, 300
local MinPanelMinimizedWidth, MinPanelMinimizedHeight = 250, 80
function WeakAurasProfilingMixin:OnShow()
  if self.initialised then
    return
  end
  self.initialised = true

  ButtonFrameTemplate_HidePortrait(self)
  self:SetTitle(L["ForeverAuras Profiling"])
  self:SetSize(MinPanelWidth, MinPanelHeight)
  self.ResizeButton:Init(self, MinPanelMinimizedWidth, MinPanelMinimizedHeight)
  self:SetResizeBounds(MinPanelWidth, MinPanelHeight)
  self.mode = 1
  UIDropDownMenu_SetText(self.buttons.modeDropDown, modes[1])

  self.buttons.report:SetText(L["Report Summary"])
  self.buttons.report.tooltip = L["A detailed overview of your auras and ForeverAuras systems\nCopy the whole text to Weakaura's Discord if you need assistance."]

  local minimizeButton = CreateFrame("Button", nil, self, "MaximizeMinimizeButtonFrameTemplate")
  minimizeButton:SetPoint("RIGHT", self.CloseButton, "LEFT")
  minimizeButton:SetOnMaximizedCallback(function()
    self.minimized = false
    self.buttons:Show()
    self.ResizeButton:Show()
    self.ColumnDisplay:Show()
    self.ScrollBox:Show()
    self.ScrollBar:Show()
    self.stats:Show()
    self:ClearAllPoints()
    self:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", self.right, self.top)
    self:SetHeight(self.prevHeight > MinPanelHeight and self.prevHeight or MinPanelHeight)
    self:SetWidth(self.prevWidth > MinPanelWidth and self.prevWidth or MinPanelWidth)
  end)
  minimizeButton:SetOnMinimizedCallback(function()
    self.minimized = true
    self.buttons:Hide()
    self.ResizeButton:Hide()
    self.ColumnDisplay:Hide()
    self.ScrollBox:Hide()
    self.ScrollBar:Hide()
    self.stats:Hide()
    self.right, self.top = self:GetRight(), self:GetTop()
    self:ClearAllPoints()
    self:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", self.right, self.top)
    self.prevHeight = self:GetHeight()
    self.prevWidth = self:GetWidth()
    self:SetHeight(MinPanelMinimizedHeight)
    self:SetWidth(MinPanelMinimizedWidth)
  end)

  self.ColumnDisplay:LayoutColumns(COLUMN_INFO)

  -- LayoutColumns doesn't handle resizable columns, fix it
  local headers = {}
  for header in self.ColumnDisplay.columnHeaders:EnumerateActive() do
    headers[header:GetID()] = header
  end
  local prevHeader
  for i, header in ipairs_reverse(headers) do
    header:ClearAllPoints()
    local info = COLUMN_INFO[i]
    if info.width ~= 1 then
      header:SetWidth(info.width)
    end
    if prevHeader == nil then
      header:SetPoint("BOTTOMRIGHT", -25, 1)
    else
      header:SetPoint("BOTTOMRIGHT", prevHeader, "BOTTOMLEFT", 2, 0)
    end
    if i == 1 then
      header:SetPoint("BOTTOMLEFT", 3, 0)
    end
    prevHeader = header
  end

  local view = CreateScrollBoxListLinearView()
  view:SetElementInitializer("WeakAurasProfilingLineTemplate", function(frame, elementData)
    frame:Init(elementData)
  end)
  ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view)
  ScrollUtil.RegisterAlternateRowBehavior(self.ScrollBox, ApplyAlternateState)

  self.sortField = "time"
  self.bars = CreateDataProvider()
  self:SortByColumnIndex(2)
  self.ScrollBox:SetDataProvider(self.bars)

  self:InitDropDown()
  self:InitModeDropDown()
  self:SetScript("OnEvent", AutoStartStopProfiling)

  self:SetScript("OnUpdate", function()
    if profileData.systems.time and profileData.systems.time.count > 0 then
      self:RefreshBars()
    end
  end)
  self:UpdateButtons()
end

function WeakAurasProfilingResultButton_OnClick(self)
  WeakAuras.PrintProfile()
end

local function nextEncounterButton_OnClick(self)
  if currentProfileState ~= "encounter" then
    WeakAuras.StartProfile("encounter")
  end
  local parent = self:GetParent()
  local profilingFrame = parent.dropdown.Button:GetParent():GetParent():GetParent()
  profilingFrame:ResetBars()
  profilingFrame:UpdateButtons()
end

local function nextCombatButton_OnClick(self)
  if currentProfileState ~= "combat" then
    WeakAuras.StartProfile("combat")
  end
  local parent = self:GetParent()
  local profilingFrame = parent.dropdown.Button:GetParent():GetParent():GetParent()
  profilingFrame:ResetBars()
  profilingFrame:UpdateButtons()
end

local function startNowButton_OnClick(self)
  WeakAuras.StartProfile()
  local parent = self:GetParent()
  local profilingFrame = parent.dropdown.Button:GetParent():GetParent():GetParent()
  profilingFrame:ResetBars()
  profilingFrame:UpdateButtons()
end

function WeakAurasProfilingStopButton_OnClick(self)
  if currentProfileState == "profiling" then
    WeakAuras.StopProfile()
  else
    CancelScheduledProfile()
  end
  self:GetParent():GetParent():UpdateButtons()
end

function WeakAurasProfilingMixin:InitDropDown()
  local function Initializer(dropDown, level)
    local entries = {
      {
        text = L["Start Now"],
        func = startNowButton_OnClick,
      },
      {
        text = L["Next Encounter"],
        func = nextEncounterButton_OnClick,
      },
      {
        text = L["Next Combat"],
        func = nextCombatButton_OnClick,
      },
    }
    for _, entry in ipairs(entries) do
      local info = UIDropDownMenu_CreateInfo()
      info.notCheckable = true
      info.text = entry.text
      info.func = entry.func
      UIDropDownMenu_AddButton(info)
    end
  end

  local dropDown = self.buttons.startDropDown
  local dropDownButton = self.buttons.start
  UIDropDownMenu_SetInitializeFunction(dropDown, Initializer)
  UIDropDownMenu_SetDisplayMode(dropDown, "MENU")

  dropDownButton.Text:SetText(L["Start Profiling"])
  dropDownButton:SetScript("OnMouseDown", function(o, button)
    UIMenuButtonStretchMixin.OnMouseDown(dropDownButton, button)
    ToggleDropDownMenu(1, nil, dropDown, dropDownButton, 130, 20)
  end)
end

local function selectMode(self, mode)
  local parent = self:GetParent()
  local profilingFrame = parent.dropdown.Button:GetParent():GetParent():GetParent()
  profilingFrame.mode = mode
  UIDropDownMenu_SetText(profilingFrame.buttons.modeDropDown, modes[mode])
  profilingFrame:ResetBars()
  profilingFrame:RefreshBars(nil, true)
end

function WeakAurasProfilingMixin:InitModeDropDown()
  local function Initializer(dropDown, level)
    for i = 1, 2 do
      local info = UIDropDownMenu_CreateInfo()
      info.text = modes[i]
      info.func = selectMode
      info.checked = i == self.mode
      info.arg1 = i
      UIDropDownMenu_AddButton(info)
    end
  end

  local dropDown = self.buttons.modeDropDown
  UIDropDownMenu_SetWidth(dropDown, 120)
  UIDropDownMenu_JustifyText(dropDown, "LEFT")
  UIDropDownMenu_Initialize(dropDown, Initializer)
end


local lastRefresh
function WeakAurasProfilingMixin:RefreshBars(_, force)
  if force or (not lastRefresh or lastRefresh < GetTime() - 1) then
    lastRefresh = GetTime()
  else
    return
  end

  if not profileData.systems.time then
    return
  end

  local data
  if self.mode == 1 then -- auras
    data = profileData.auras
  elseif self.mode == 2 then -- systems
    data = {}
    for k, v in pairs(profileData.systems) do
      if k ~= "time" and k ~= "wa" then
        local event = unitEventToMultiUnit(k)
        if data[event] == nil then
          data[event] = CopyTable(v)
        else
          if v.elapsed then
            data[event].elapsed = (data[event].elapsed or 0) + v.elapsed
          end
          if v.spike then
            data[event].spike = (data[event].spike or 0) + v.spike
          end
        end
      end
    end
  end

  local total = TotalProfileTime(data)
  for _, name in ipairs(SortProfileMap(data)) do
    if name ~= "time" and name ~= "wa" then
      local elapsed = data[name].elapsed
      local pct = 100 * elapsed / total
      local spike = data[name].spike
      self:UpdateBar(name, elapsed, pct, spike)
    end
  end

  self.bars:Sort()
  if profileData.systems.wa then
    local timespent = profileData.systems.time.elapsed or (debugprofilestop() - profileData.systems.time.start)
    self.stats:SetText(
      ("|cFFFFFFFFTime in WA: %.2fs / %ds (%.1f%%)"):format(profileData.systems.wa.elapsed / 1000, timespent / 1000, 100 * profileData.systems.wa.elapsed / timespent)
    )
  end
end

function WeakAurasProfilingMixin:ResetBars()
  self.bars:Flush()
end

function WeakAurasProfilingMixin:UpdateBar(name, time, pct, spike)
  local elementData = self.bars:FindElementDataByPredicate(function(elementData)
    return elementData.name == name
  end)
  if elementData then
    elementData.time = time
    elementData.pct = pct
    elementData.spike = spike
    local button = WeakAurasProfilingFrame.ScrollBox:FindFrame(elementData)
    if button then
      button.time:SetText(("%.2fms"):format(time))
      button.spike:SetText(ColoredSpike(spike))
      button.progressBar:SetValue(pct)
    end
  else
    self.bars:Insert({ name = name, time = time, pct = pct, spike = spike })
  end
end

function WeakAurasProfilingMixin:SortByColumnIndex(index)
  local previousField = self.sortField
  self.sortField = COLUMN_INFO[index].attribute
  if previousField == self.sortField then
    self.sortDirection = not self.sortDirection
  else
    self.sortDirection = true
  end
  self.bars:SetSortComparator(function(lhs, rhs)
    local field = self.sortField
    local lhsF, rhsF = lhs[field] or 0, rhs[field] or 0
    if type(lhsF) == "string" then
      lhsF = lhsF:lower()
    end
    if type(rhsF) == "string" then
      rhsF = rhsF:lower()
    end
    if lhsF == rhsF then
      return lhs.name < rhs.name
    end
    if self.sortDirection then
      return lhsF > rhsF
    else
      return lhsF < rhsF
    end
  end)
end

function WeakAurasProfilingMixin:UpdateButtons()
  local b = self.buttons
  if currentProfileState == "combat" or currentProfileState == "encounter" then
    b.stop:SetText(L["Cancel"])
    b.stop:Show()
    b.start:Hide()
  elseif currentProfileState == "profiling" then
    b.stop:SetText(L["Stop"])
    b.stop:Show()
    b.start:Hide()
  else
    b.start:Show()
    b.stop:Hide()
    if profileData.systems.time then
      b.report:Show()
    end
  end
end

function WeakAurasProfilingMixin:Start()
  self:Show()
end

function WeakAurasProfilingMixin:Stop()
  WeakAuras.StopProfile()
  self:UpdateButtons()
  self:ResetBars()
end

function WeakAurasProfilingMixin:Toggle()
  if self:IsShown() then
    if currentProfileState == "profiling" then
      self:Stop()
    end
    self:Hide()
  else
    self:Start()
  end
end

local function StopSystem(name, ...)
  Private.StopProfileSystem(name)
  return ...
end

function Private.Profiled(name, func)
  return function(...)
    Private.StartProfileSystem(name)
    return StopSystem(name, func(...))
  end
end

function WeakAurasProfilingColumnDisplay_OnClick(self, columnIndex)
  self:GetParent():SortByColumnIndex(columnIndex)
end
