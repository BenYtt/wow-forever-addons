-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
-- Player swing timing supplied by Blizzard; no combat-log reconstruction.
if not WeakAuras.IsLibsOK() then return end
local Private = select(2, ...)
-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript, C_Timer = Private.TimedAPI("SwingTimer")
local swings, timers = {}, {}
local frame
local eventName = 'FA_SWING_TIMER_UPDATE'
local slots = {[0] = 16, [1] = 17, [2] = 18}
local names = {[0] = 'Main Hand', [1] = 'Off Hand', [2] = 'Ranged'}

function WeakAuras.GetSwingTimerInfo(swingType)
  local swing = swings[swingType]
  return swing and swing.duration or 0, swing and swing.expirationTime or 0,
    names[swingType], GetInventoryItemTexture('player', slots[swingType]) or 132324
end

function WeakAuras.IsTargetInSwingRange(swingType)
  if not (C_SwingTimer and C_SwingTimer.IsTargetWithinSwingRange) then return end
  local ok, inRange = pcall(C_SwingTimer.IsTargetWithinSwingRange, swingType)
  if ok and type(inRange) == 'boolean' and not issecretvalue(inRange) then return inRange end
end

function WeakAuras.WatchSwingTimer()
  if frame or not Enum.PlayerSwingType then return end
  frame = CreateFrame('Frame')
  frame:RegisterEvent('PLAYER_SWING')
  frame:RegisterEvent('PLAYER_ENTERING_WORLD')
  frame:RegisterEvent('WEAPON_SLOT_CHANGED')
  if C_SwingTimer and C_SwingTimer.EnableRangeCheck then
    for swingType in pairs(slots) do pcall(C_SwingTimer.EnableRangeCheck, swingType, true) end
    frame:RegisterEvent('PLAYER_SWING_RANGE_UPDATE')
    frame:RegisterEvent('PLAYER_TARGET_CHANGED')
  end
  frame:SetScript('OnEvent', function(_, event, duration, swingType)
    if event == 'PLAYER_SWING_RANGE_UPDATE' or event == 'PLAYER_TARGET_CHANGED' then
    elseif event == 'PLAYER_SWING' then
      if issecretvalue(duration) or issecretvalue(swingType) then return end
      if not slots[swingType] or type(duration) ~= 'number' or duration <= 0 or duration == math.huge or duration ~= duration then return end
      if timers[swingType] then timers[swingType]:Cancel() end
      swings[swingType] = {duration = duration, expirationTime = GetTime() + duration}
      timers[swingType] = C_Timer.NewTimer(duration, function()
        swings[swingType], timers[swingType] = nil, nil
        WeakAuras.ScanEvents(eventName)
      end)
    else
      for _, timer in pairs(timers) do timer:Cancel() end
      wipe(timers)
      wipe(swings)
    end
    WeakAuras.ScanEvents(eventName)
  end)
end
