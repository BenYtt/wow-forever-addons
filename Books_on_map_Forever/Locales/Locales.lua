-- Books on map (Forever): localization (English / French, chosen in the options; "auto" = client language)
local _, ns = ...

-- set at ADDON_LOADED from the saved choice (ns.ApplyLanguage)
ns.IS_FRENCH = GetLocale() == "frFR"

-- English strings are the keys; a missing translation falls back to the key
local FR = {}
ns.L = setmetatable({}, { __index = function(_, k) return ns.IS_FRENCH and FR[k] or k end })
ns.FR = FR

function ns.ApplyLanguage(lang)
  if lang == "enUS" then ns.IS_FRENCH = false
  elseif lang == "frFR" then ns.IS_FRENCH = true
  else ns.IS_FRENCH = GetLocale() == "frFR" end
end
