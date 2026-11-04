local _, ns = ...

-- Case- and accent-insensitive text matching for search boxes. Four addons each wrote their own copy -- Hoard's 45-line
-- table, Adventure Guide's three-line byte fold, Shortest Path's whitespace strip -- and they did not agree, so "dun
-- garok" found "Dûn Garok" in one addon and not in another. One fold and one ranking, here. Nothing else about a search
-- lives in this file: what a title is, which items are searched and in what order they are shown stay with the addon.

-- Latin-1's accented letters (UTF-8 \195\128-\195\191, U+00C0-U+00FF) folded to plain letters, upper and lower case
-- alike, so "dun garok" finds "Dûn Garok"; the ligatures spell out (ß ss, æ ae, þ th, and œ oe from Latin Extended-A).
-- The two signs (multiply, divide) stay. string.lower only handles ASCII, so the fold runs before it.
local FOLD = { ["\195\159"] = "ss", ["\197\146"] = "oe", ["\197\147"] = "oe" }
do
	local plain = "aaaaaaaceeeeiiiidnooooo\0ouuuuy\0\0aaaaaaaceeeeiiiidnooooo\0ouuuuy\0y"
	for code = 0xC0, 0xFF do
		local letter = plain:sub(code - 0xBF, code - 0xBF)
		if letter ~= "\0" then
			FOLD["\195" .. string.char(code - 0x40)] = letter
		end
	end
	FOLD["\195\134"], FOLD["\195\166"] = "ae", "ae" -- Æ æ
	FOLD["\195\158"], FOLD["\195\190"] = "th", "th" -- Þ þ
end

local Text = {}
ns.Text = Text

-- `text` lower-cased with Latin accents folded, for search matching only. Anything that is not a string is read as
-- nil, so a missing name never breaks a search: it folds to "" and matches nothing but an empty query.
---@param text? string
---@return string
function Text.Fold(text)
	return (tostring(text or ""):lower():gsub("[\195\197][\128-\191]", FOLD))
end

-- How well a folded title matches a folded query, lower is better:
--   0  the query is empty: everything matches equally, so nothing is filtered
--   1  the whole title, exactly
--   2  the title starts with the query
--   3  every query word starts a word of the title (words start after a space or punctuation)
--   4  every query word appears somewhere in the title
--   nil the title does not match: at least one query word appears nowhere in it
-- A query word without its neighbours is the common case ("garok" for "dûn garok"), and a query with several words must
-- match all of them ("garok dûn" is not a hit on "dûn morogh"). Both arguments are already folded: callers fold a name
-- once and reuse it across a list, and folding the query per item would defeat that.
---@param folded string
---@param query string
---@return integer?
function Text.Rank(folded, query)
	if query == "" then
		return 0
	end
	local words = {}
	for word in query:gmatch("%S+") do
		if not folded:find(word, 1, true) then
			return nil
		end
		words[#words + 1] = word
	end
	if folded == query then
		return 1
	end
	if folded:sub(1, #query) == query then
		return 2
	end
	-- Every word of the title starts after a space once punctuation is a space too, so "garok" starts the second word
	-- of "dûn garok's camp" and not the tail of "vargarok".
	local starts = " " .. folded:gsub("%p", " ")
	for _, word in ipairs(words) do
		if not starts:find(" " .. word, 1, true) then
			return 4
		end
	end
	return 3
end
