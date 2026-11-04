local _, ns = ...

-- Every player-facing string goes through ns.L, keyed by its English text:
--
--   print(L["Nobody to buff right now."])
--   print(L["%s buffed you"]:format(name))
--
-- A string with no translation for the client's language comes back as its
-- own key, so English needs no file of its own and a string added after the
-- last translation pass reads in English rather than as a blank or an error.
--
-- The locale files after this one fill the table only in their own language,
-- and set values and nothing else. tests/validate.py checks that every
-- translation keeps its format specifiers, {tokens} and colour codes in the
-- English order, because a dropped %s throws in string.format when printed.
ns.LOCALE = type(GetLocale) == "function" and GetLocale() or "enUS"
ns.L = setmetatable({}, {
	__index = function(_, key) return key end,
})
