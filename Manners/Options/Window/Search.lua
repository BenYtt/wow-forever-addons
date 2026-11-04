-- Manners -- options window: what the search box finds, and in what order.
--
-- The window builds the entries when a query runs (every control shown right
-- now, with its name, tooltip and choices asked then) and draws the results;
-- this is only the matching, so it can be tested without a frame in sight.
--
--   entries = { { label = s, choices = { s, ... }, desc = s, section = s, page = s, ref = any }, ... }
--   Search.Find(query, entries, limit) -> the matching entries, best first

local _, ns = ...

local Search = {}
ns.WindowSearch = Search

local find, gsub, lower, char = string.find, string.gsub, string.lower, string.char

-- The UI's escapes, which are drawn, not read: colour (|cAARRGGBB, or a named
-- colour |cn...:), its end |r, textures |T...|t and atlases |A...|a. A link's
-- text stays; a line break is a space, so two lines never run into one word.
-- Byte ranges spelt out rather than %x or %s: those follow the C library's
-- locale, and under a Western one %s takes 0xA0, the second byte of "à".
local HEX = "[0-9A-Fa-f]"
local ESCAPES = {
	{ "|c" .. HEX:rep(8), "" },
	{ "|cn[^:|]*:", "" },
	{ "|r", "" },
	{ "|T.-|t", "" },
	{ "|A.-|a", "" },
	{ "|H.-|h(.-)|h", "%1" },
	{ "|n", " " },
	{ "[ \t\r\n]+", " " },
}

-- Case is folded by hand, for the same reason: string.lower under a Western
-- locale turns the first byte of "Ä" into another letter. So ASCII capitals
-- go through string.lower one run at a time, and then the two-byte capitals:
-- Latin-1's À to Þ (0xC3 0x80-0x9E, but not 0x97, the multiplication sign)
-- are their small letters plus 0x20, and Œ and Ÿ sit apart. That is every
-- capital German, French, Spanish, Italian and Portuguese write; Korean and
-- Chinese have no case. Russian is folded too, though Manners has no Russian
-- text: a ruRU client's spell names, which the choices and labels hold, are
-- Cyrillic and start with a capital. А to П (0xD0 0x90-0x9F) are their small
-- letters plus 0x20; Р to Я (0xD0 0xA0-0xAF) move on to 0xD1 0x80-0x8F; Ё
-- sits apart.
local function SmallLatin1(byte)
	return "\195" .. char(byte:byte() + 32)
end
local function SmallCyrillic(byte)
	byte = byte:byte()
	if byte == 129 then return "\209\145" end
	if byte < 160 then return "\208" .. char(byte + 32) end
	return "\209" .. char(byte - 32)
end
local TWO_BYTE = { ["\197\146"] = "\197\147", ["\197\184"] = "\195\191" }

local function Fold(text)
	text = gsub(text, "[A-Z]+", lower)
	text = gsub(text, "\195([\128-\150\152-\158])", SmallLatin1)
	text = gsub(text, "\208([\129\144-\175])", SmallCyrillic)
	return (gsub(text, "\197[\146\184]", TWO_BYTE))
end

-- The text as the box compares it: no escapes, one space between words, no
-- case. Anything that is not a plain string (a secret, a number) is "".
function Search.Normalise(text)
	text = ns.plain(text)
	if type(text) ~= "string" then return "" end
	for i = 1, #ESCAPES do
		text = gsub(text, ESCAPES[i][1], ESCAPES[i][2])
	end
	text = gsub(gsub(text, "^ ", ""), " $", "")
	return Fold(text)
end

local function Has(text, query)
	return find(Search.Normalise(text), query, 1, true) ~= nil
end

-- How well an entry matches, 0 best: its label, a choice's label, its
-- tooltip, then the section or page it is on. nil when nothing does.
local function Rank(entry, query)
	if type(entry) ~= "table" then return nil end
	if Has(entry.label, query) then return 0 end
	if type(entry.choices) == "table" then
		for _, choice in pairs(entry.choices) do
			if Has(choice, query) then return 1 end
		end
	end
	if Has(entry.desc, query) then return 2 end
	if Has(entry.section, query) or Has(entry.page, query) then return 3 end
	return nil
end

-- At most `limit` entries (8 when not given), best rank first and, within a
-- rank, in the order they were given: page order, so the list reads as the
-- window does. A plain substring match, so "whisp" finds Where to say it.
function Search.Find(query, entries, limit)
	local found = {}
	query = Search.Normalise(query)
	limit = tonumber(limit) or 8
	if query == "" or type(entries) ~= "table" or limit < 1 then return found end
	local ranks = { {}, {}, {}, {} }
	for _, entry in ipairs(entries) do
		local rank = Rank(entry, query)
		if rank then
			local list = ranks[rank + 1]
			list[#list + 1] = entry
		end
	end
	for _, list in ipairs(ranks) do
		for _, entry in ipairs(list) do
			if #found >= limit then return found end
			found[#found + 1] = entry
		end
	end
	return found
end
