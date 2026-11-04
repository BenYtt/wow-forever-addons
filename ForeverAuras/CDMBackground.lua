-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
-- Keep hiding limited to opacity. Calling Edit Mode setting updaters from addon
-- code taints Blizzard's aura refresh path; visibility/tooltips must be set in its UI.
if not WeakAuras.IsLibsOK() then return end
local _, Private = ...
-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript = Private.TimedAPI("CDMBackground")
local names = {"EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer"}
local viewers = setmetatable({}, {__mode = "k"})
local applying = false
local function Hidden() return Private.db and Private.db.cdmHideBlizzard == true end
local function Accessible(frame) return not frame.IsForbidden or not frame:IsForbidden() end
local function ApplyAlpha(frame, alpha)
  if applying or not Accessible(frame) then return end
  local record = viewers[frame]
  if not record then return end
  if alpha ~= nil and not (issecretvalue and issecretvalue(alpha)) then record.alpha = alpha end
  applying = true
  frame:SetAlpha(Hidden() and 0 or record.alpha)
  applying = false
end
function Private.ApplyCDMBackground()
  if InCombatLockdown() then return end
  if Hidden() and C_CVar and C_CVar.GetCVarBool and not C_CVar.GetCVarBool("cooldownViewerEnabled") then
    C_CVar.SetCVar("cooldownViewerEnabled", "1")
  end
  for _, name in ipairs(names) do
    local viewer = _G[name]
    if viewer and Accessible(viewer) and (Hidden() or viewers[viewer]) then
      if not viewers[viewer] then
        local alpha = viewer:GetAlpha()
        if issecretvalue and issecretvalue(alpha) then alpha = 1 end
        viewers[viewer] = {alpha = alpha}
        hooksecurefunc(viewer, "SetAlpha", ApplyAlpha)
      end
      ApplyAlpha(viewer)
    end
  end
  -- Queued with the viewer hooks' own refresh (CooldownViewerCatalog.lua), so
  -- the end of combat runs the CDM triggers once, not once here and once for
  -- Blizzard's viewer refresh in the next frame.
  if Private.QueueCDMRefresh then Private.QueueCDMRefresh()
  elseif Private.ScanEvents then Private.ScanEvents("FA_CDM_REFRESH") end
end
local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "COOLDOWN_VIEWER_DATA_LOADED", "CVAR_UPDATE"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, name)
  if event == "CVAR_UPDATE" and name ~= "cooldownViewerEnabled" then return end
  Private.ApplyCDMBackground()
end)
