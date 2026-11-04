-- Modified for ForeverAuras, 2026-09-18.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript, C_Timer = Private.TimedAPI("Dragonriding")
local LibAdvFlight = LibStub("LibAdvFlight-1.1")
local Events = LibAdvFlight.Events;

local function HandleEvent(self, event, arg1)
  Private.callbacks:Fire("WA_DRAGONRIDING_UPDATE")
  if event == "PLAYER_ENTERING_WORLD" and arg1 == true then
    C_Timer.After(2, HandleEvent)
  end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", HandleEvent)

LibAdvFlight.RegisterCallback(Events.ADV_FLYING_ENABLED, HandleEvent);
LibAdvFlight.RegisterCallback(Events.ADV_FLYING_DISABLED, HandleEvent);

Private.IsDragonriding = function ()
  return LibAdvFlight.IsAdvFlyEnabled()
end

