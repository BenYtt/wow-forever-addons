-- Modified for ForeverAuras, 2026-09-18.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
-- Narrow adapter for restriction-state access. Missing/erroring APIs remain restricted.
local _, Private = ...
Private.ClientAPI = {}
function Private.ClientAPI.RestrictionsActive()
  if not C_Secrets or type(C_Secrets.ShouldAurasBeSecret) ~= "function"
      or type(C_Secrets.ShouldCooldownsBeSecret) ~= "function" then
    return true
  end
  local okAura, aura = pcall(C_Secrets.ShouldAurasBeSecret)
  local okCD, cd = pcall(C_Secrets.ShouldCooldownsBeSecret)
  if not okAura or not okCD then return true end
  if type(issecretvalue) == "function" and (issecretvalue(aura) or issecretvalue(cd)) then return true end
  if type(aura) ~= "boolean" or type(cd) ~= "boolean" then return true end
  return aura or cd
end
