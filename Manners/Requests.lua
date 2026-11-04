-- Manners -- people who ask for a buff in chat, and the chat events that
-- bring the asking in.

local ns = select(2, ...)
local L = ns.L
local addon = ns.addon

local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime

-- Core.lua's and Queue.lua's, which load first. The player's class is read
-- through ns.PlayerClass() when it is needed: the probe sets it again.
local plain, ShortName, FirstName, SameName = ns.plain, ns.ShortName, ns.FirstName, ns.SameName

---------------------------------------------------------------------------
-- people who ask for a buff
--
-- "int pls", "fort?", "can I get motw", "buffs please" -- said in /say, /yell,
-- your group's chat or a whisper -- put whoever said it on the prompt, reading
-- "asked for it", for a minute. Nothing is ever said back. The rules are kept
-- simple enough to say on the options page, and err towards silence:
--
--   * eight words at most; anything longer is a conversation.
--   * it names the buff in whole words, by a name players use (ASK_NAMES) or
--     the spell's own name on this client, which covers other languages.
--     "buff" or "buffs" names every buff you have.
--   * nothing in it says no.
--   * it reads as a request: a please or "need" anywhere, an opener (can, any,
--     anyone...), or nothing but the name and filler ("int me"). A buff's name
--     (not a looser word, not "buff") is also asked for by a closing question
--     mark, unless the message opens as a question about it ("who has int?").
--
-- A one-word nickname and "buff" are everyday words too ("int" is an
-- interrupt), so beside one every other word must be a small one. The looser
-- words (might, mark, shout...) need a please or to stand alone, and never
-- count in group chat, where "mark pls" is about raid markers.
--
-- Chat text and senders can be secret values (Forever, retail); a secret is
-- never compared, matched or kept, so an unreadable message is no request.
--
-- A request names a person, not a unit: the queue matches it against every
-- unit it walks, and there is no tokenless fallback (a whisper, unlike a
-- favour, is no evidence of range). It is offered only while they lack it.
--
-- The section sits in one do-block, hanging its entry points off ns, because
-- the main chunk is close to the 200 locals Lua 5.1 allows a function.
---------------------------------------------------------------------------

do
	-- How long a request stands, and how many are kept. The cap is for a city
	-- square full of people asking at once; the oldest goes first.
	local ASK_SECONDS = 60
	local ASK_KEEP = 30
	local ASK_MOST_WORDS = 8

	-- The names players type for each buff, lower case, by the buff's key in
	-- Buffs.lua; only the buffs this character knows are looked up. A leading ~
	-- marks a looser word; a one-word name is a nickname. "pw f" is how "pw:f"
	-- reads once punctuation is gone.
	local ASK_NAMES = {
		intellect = { "int", "intellect", "ai", "arcane intellect", "brilliance",
			"arcane brilliance" },
		fortitude = { "fort", "fortitude", "stam", "stamina", "pwf", "pw f",
			"power word fortitude", "prayer of fortitude" },
		spirit = { "divine spirit", "prayer of spirit", "~spirit" },
		shadow = { "shadow prot", "shadow protection", "sprot",
			"prayer of shadow protection", "~shadow" },
		motw = { "motw", "gotw", "mark of the wild", "gift of the wild", "~mark" },
		thorns = { "thorns" },
		wisdom = { "bow", "blessing of wisdom", "~wisdom" },
		might = { "bom", "blessing of might", "~might" },
		kings = { "kings", "bok", "blessing of kings" },
		salvation = { "salv", "salvation", "blessing of salvation" },
		light = { "bol", "blessing of light" },
		sanctuary = { "sanc", "sanctuary", "blessing of sanctuary" },
		breath = { "unending breath", "water breathing", "ub", "~breath" },
		battleshout = { "battle shout", "~shout" },
		emperor = { "legacy of the emperor", "~emperor" },
		whitetiger = { "legacy of the white tiger", "white tiger" },
		darkintent = { "dark intent" },
		hornofwinter = { "horn of winter", "~horn" },
		skyfury = { "skyfury" },
		bronze = { "blessing of the bronze", "bronze" },
		sourceofmagic = { "source of magic" },
	}

	local function Set(list)
		local out = {}
		for _, word in ipairs(list) do out[word] = true end
		return out
	end

	-- The small words the rules are made of, in one table to spend one local.
	-- Apostrophes are dropped before any lookup, so "don't" is "dont".
	local ASK = {
		-- Any of every buff you cast.
		generic = Set({ "buff", "buffs" }),
		please = Set({ "please", "pls", "plz", "plx", "plox", "pl0x", "plis", "pliz",
			"plez", "plse", "pleas", "plss", "plzz", "need", "gimme",
			"bitte", "svp", "stp", "porfa", "favor", "favore",
			"пожалуйста", "пж", "плз", "плиз", "пжлст" }),
		-- A please of more than one word, as one phrase: none of its words
		-- alone is a please ("ça me plaît"), and beside a nickname each one
		-- had to be a small word, which "por" and "per" are not.
		pleasePhrases = { { "por", "favor" }, { "per", "favore" }, { "sil", "vous", "plait" },
			{ "sil", "vous", "plaît" }, { "sil", "te", "plait" }, { "sil", "te", "plaît" } },
		opener = Set({ "can", "could", "may", "any", "anyone", "anybody", "someone",
			"somebody", "got", "mind" }),
		-- Opening a question about the buff rather than one asking for it. "who
		-- has int?" is looking for a mage; "who needs int?" and "needs int?" are
		-- a mage offering it. The same openers in the shipped languages follow.
		question = Set({ "is", "are", "does", "do", "did", "what", "whats", "why",
			"how", "which", "when", "where", "should", "would", "was", "were",
			"who", "whos", "wants", "needs",
			"ist", "sind", "hat", "wer", "was", "wie", "warum", "welche", "lohnt",
			"wo", "wann", "wieso", "wozu", "wofür", "weshalb",
			"est", "qui", "quoi", "pourquoi", "comment", "quel", "quelle", "où", "quand",
			"combien",
			-- Spanish and Italian write these with the accent when they ask, and
			-- Among does not fold accents, so each is listed both ways.
			"es", "quien", "quién", "quem", "que", "qué", "por", "como", "cómo",
			"cual", "cuál", "donde", "dónde", "cuando", "cuándo", "cuanto", "cuánto",
			"onde", "quando", "qual",
			"chi", "cosa", "perche", "perché", "dove", "quale",
			"кто", "что", "как", "зачем", "почему", "есть", "где", "когда", "сколько",
			"какой", "какая", "откуда", "куда" }),
		-- Chinese ends a question with a particle before the question mark:
		-- "is it any good?" rather than a bare name asked for.
		questionEnds = Set({ "吗", "嗎", "呢" }),
		never = Set({ "no", "not", "dont", "stop", "nvm", "never", "cant", "wont",
			"nicht", "kein", "keine", "keinen", "keiner", "nein", "pas", "non",
			"não", "nao", "нет", "не" }),
		-- Chinese and Korean write "don't" inside a word, so these are looked
		-- for anywhere. 别 only before the verbs a buff takes: alone it is also
		-- part of 特别 (especially), 别人 (others) and 区别.
		neverInside = { "不要", "不用", "不需要", "别给", "别加", "别上", "别刷", "别套", "别丢",
			"別給", "別加", "別上", "別刷", "別套", "別丟", "말아", "마세요", "필요없" },
		-- The cap on words, in characters, for Chinese: a sentence there has
		-- no spaces, so it is one long "word".
		mostChars = 12,
		-- What may stand beside a buff's name in a message that is nothing but
		-- the name: "int me", "mage int", "for the kings".
		filler = Set({ "me", "us", "i", "a", "an", "the", "some", "for", "to",
			"mage", "mages", "priest", "priests", "druid", "druids", "paladin",
			"paladins", "pala", "pally", "pallys", "warrior", "warlock", "lock" }),
		-- What else may stand beside a nickname or "buff": "can I get int",
		-- "int pls ty". Not filler, since "thanks for the int" asks for nothing.
		aside = Set({ "get", "have", "give", "can", "you", "u", "ty", "thx", "thanks",
			"again", "too", "also" }),
		-- Where the looser words are tactics, not buffs: raid markers, a shout
		-- to pull.
		group = Set({ "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "INSTANCE_CHAT",
			"INSTANCE_CHAT_LEADER" }),
		-- Chinese and Korean write "please" as part of a word, so these are
		-- looked for anywhere.
		pleaseInside = { "请", "請", "부탁", "주세요" },
		-- 求 is a please too ("法师求奥术智慧"), but also the end of 要求, 需求,
		-- 追求, 寻求 and 供求, so it counts unless one of these stands just
		-- before it.
		notBeforeQiu = { ["要"] = true, ["需"] = true, ["追"] = true, ["寻"] = true,
			["尋"] = true, ["供"] = true },
		-- A command rather than a word, so it reads the same in every language.
		slash = { SAY = "/say", YELL = "/yell", PARTY = "/party", PARTY_LEADER = "/party",
			RAID = "/raid", RAID_LEADER = "/raid", INSTANCE_CHAT = "/instance",
			INSTANCE_CHAT_LEADER = "/instance", WHISPER = "/whisper" },
		-- Every buff you have, as a request for "buff pls".
		ANY = {},
	}

	-- Standing requests, oldest first: { name, short, guid, keys, at, expires,
	-- channel, fight, held, full }. `fight` is held through the one going on;
	-- `held` has been, and will not be again.
	local requests = {}
	-- For /manners debug: how many messages were read, and why the ones that
	-- were not requests were set aside where that is worth knowing.
	ns.askScan = { heard = 0, unreadable = 0, own = 0, fight = 0, noted = 0 }

	-- A message as words, lower case, with the chat frame's escapes out of the
	-- way (a linked spell keeps its bracketed name). Letters, digits and every
	-- byte of a multibyte character make words; everything else separates them.
	--
	-- A to Z spelled out rather than %w and string.lower, which follow the C
	-- locale and can split a Cyrillic or Chinese character in two. Other
	-- scripts are compared by SameWord and looked up by Among.
	--
	-- The common punctuation outside ASCII separates words too: ¡ ¿ « », the
	-- dashes, curly quotes and the ellipsis, the full-width ！ ， ？ and 、 。,
	-- and a curly apostrophe is an apostrophe ("s’il"). Not the full-width
	-- colon, which stands inside a spell's name (真言术：韧). The text handed
	-- back is the message as typed, which the Chinese names and the trailing
	-- question mark are read from.
	--
	-- The apostrophe is dropped, so "s'il" is "sil" and "don't" is "dont". An
	-- article elided before a vowel ("l'intelligence", "qu'est") glues itself
	-- to the word that way, so the list also holds, as `bare` by position, the
	-- word without it, for the names and openers to be found by.
	local function Words(text)
		text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
			:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("[A-Z]", string.lower)
		local split = text:gsub("\194[\161\171\187\191]", " "):gsub("\226\128[\147\148\156\157\166]", " ")
			:gsub("\239\188[\129\140\159]", " "):gsub("\227\128[\129\130]", " ")
			:gsub("\226\128[\152\153]", "'")
		local words, bare = {}, {}
		words.bare = bare
		for found in split:gmatch("[A-Za-z0-9\128-\255']+") do
			local word = found:gsub("'", "")
			if word ~= "" then
				words[#words + 1] = word
				local rest = found:match("^[a-z][a-z]?'([aeiouh\128-\255].*)$")
				if rest then bare[#words] = rest:gsub("'", "") end
			end
		end
		return words, text
	end

	-- Two words the same, regardless of case. Words only folds A to Z, so a
	-- Russian or a Greek word typed in another case is folded by the client's
	-- own strcmputf8i where there is one, as SameName folds names. Only when
	-- both are in another script: an English word is already folded, so it
	-- matches by equality alone, and asking strcmputf8i of every English word
	-- on every list cost a Russian line seven hundred calls.
	local function SameWord(a, b)
		if a == b then return true end
		if not a:find("[\128-\255]") or not b:find("[\128-\255]") then return false end
		local caseless = _G.strcmputf8i
		if type(caseless) ~= "function" then return false end
		local ok, cmp = pcall(caseless, a, b)
		return ok and cmp == 0
	end

	-- Whether `word` is one of `set`: a plain lookup, except that a word in
	-- another script, left in its typed case, is compared caselessly ("Не" is
	-- "не"). Only chat events come here, so the walk costs nothing that matters.
	local function Among(set, word)
		if set[word] then return true end
		if not word:find("[\128-\255]") then return false end
		for entry in pairs(set) do
			if SameWord(word, entry) then return true end
		end
		return false
	end

	-- Marks every place `name` (already words) stands in `words`, in `covered`,
	-- and says whether it was found at all.
	local function Mark(words, name, covered)
		local found = false
		local n = #name
		if n == 0 then return false end
		for i = 1, #words - n + 1 do
			local all = true
			for j = 1, n do
				local at = i + j - 1
				if not (SameWord(words[at], name[j])
					or (words.bare[at] and SameWord(words.bare[at], name[j]))) then
					all = false
					break
				end
			end
			if all then
				found = true
				for j = 1, n do covered[i + j - 1] = true end
			end
		end
		return found
	end

	-- How strongly a message names this buff: "strict" for its own name or a
	-- plain name of more than one word, "short" for a one-word nickname, "loose"
	-- for one of the ~ words, nil for not at all. The strongest wins.
	local STRENGTH = { loose = 1, short = 2, strict = 3 }
	local function Names(words, lowered, buff, covered)
		local strength
		local own = ns.BuffInfo(buff)
		own = own and own.name
		if type(own) == "string" and own ~= "" then
			local ownWords = Words(own)
			if Mark(words, ownWords, covered) then
				strength = "strict"
			elseif #ownWords == 1 and not ownWords[1]:find("[A-Za-z0-9]")
				and ownWords[1]:find("[\228-\233]") and #ownWords[1] >= 6
				and lowered:find(ownWords[1], 1, true) then
				-- A Chinese name, holding ideographs (lead bytes 228-233) and
				-- perhaps full-width punctuation (真言术：韧): the message has no
				-- spaces either, so the name is found inside a longer "word". Two
				-- characters at least, so it is a name and not a syllable. Not a
				-- Korean or Russian name, which holds no ideograph: those
				-- languages put spaces between words and build other words from
				-- the same syllables.
				strength = "strict"
			end
		end
		for _, entry in ipairs(ASK_NAMES[buff.key] or {}) do
			local loose = entry:sub(1, 1) == "~"
			local name = Words(loose and entry:sub(2) or entry)
			if Mark(words, name, covered) then
				local this = loose and "loose" or (#name == 1 and "short" or "strict")
				if not strength or STRENGTH[this] > STRENGTH[strength] then strength = this end
			end
		end
		return strength
	end

	-- The buffs a message asks for, as a set of keys (ASK.ANY for "buff pls"),
	-- or nil: the rules at the top of this section, in order. `channel` decides
	-- whether the looser words count at all.
	local function Asks(text, channel)
		local words, lowered = Words(text)
		if #words == 0 or #words > ASK_MOST_WORDS then return nil end
		for _, word in ipairs(words) do
			if Among(ASK.never, word) then return nil end
		end
		-- A run holding Chinese ideographs (lead bytes 228-233) is capped by its
		-- characters, counted by their lead bytes. Read off the message as
		-- typed: a sentence is no shorter for the commas Words splits it at.
		for run in lowered:gmatch("[A-Za-z0-9\128-\255']+") do
			if run:find("[\228-\233]") and select(2, run:gsub("[\192-\255]", "")) > ASK.mostChars then
				return nil
			end
		end
		for _, inside in ipairs(ASK.neverInside) do
			if lowered:find(inside, 1, true) then return nil end
		end

		-- Each 求, with the three bytes before it: one Chinese character.
		local pleased, at = false, lowered:find("求", 1, true)
		while at do
			if not ASK.notBeforeQiu[lowered:sub(at - 3, at - 1)] then pleased = true break end
			at = lowered:find("求", at + 3, true)
		end
		for _, word in ipairs(words) do
			if Among(ASK.please, word) then pleased = true break end
		end
		if not pleased then
			for _, inside in ipairs(ASK.pleaseInside) do
				if lowered:find(inside, 1, true) then pleased = true break end
			end
		end
		local opens = Among(ASK.opener, words[1])
		-- A trailing question mark, and what stands before it. The full-width
		-- one is the one Chinese and Japanese type.
		local stem, marked = lowered:gsub("%s+$", ""), false
		if stem:sub(-1) == "?" then
			stem, marked = stem:sub(1, -2), true
		elseif stem:sub(-3) == "？" then
			stem, marked = stem:sub(1, -4), true
		end
		stem = stem:gsub("%s+$", "")
		-- Not a question about the buff: no opener that asks about it, no
		-- Chinese question particle, and no Hangul (lead bytes 234-237), since
		-- Korean asks about a thing and for it with the same question mark.
		local questioned = marked and not Among(ASK.question, words[1])
			and not (words.bare[1] and Among(ASK.question, words.bare[1]))
			and not ASK.questionEnds[stem:sub(-3)] and not lowered:find("[\234-\237]")

		local covered, found, generic = {}, {}, false
		-- A please of more than one word ("por favor", "s'il vous plaît"),
		-- covered as a whole so that none of its words stands alone.
		for _, phrase in ipairs(ASK.pleasePhrases) do
			if Mark(words, phrase, covered) then pleased = true end
		end
		for _, buff in ipairs(ns.GetClassBuffs(ns.PlayerClass()) or {}) do
			if ns.IsBuffKnown(buff) then
				found[buff.key] = Names(words, lowered, buff, covered)
			end
		end
		for i, word in ipairs(words) do
			if ASK.generic[word] then generic, covered[i] = true, true end
		end
		-- Nothing but names and filler; and nothing but names and small words,
		-- which is what a nickname, "buff" or a looser word may stand beside.
		local only, small = true, true
		for i, word in ipairs(words) do
			if not covered[i] and not Among(ASK.filler, word) then
				only = false
				if not (Among(ASK.please, word) or Among(ASK.opener, word)
					or Among(ASK.aside, word)) then
					small = false
				end
			end
		end
		local asking = pleased or opens or only

		local keys
		for key, strength in pairs(found) do
			local counts
			if strength == "strict" then
				counts = asking or questioned
			elseif strength == "short" then
				counts = small and (asking or questioned)
			else
				counts = small and (pleased or only) and not ASK.group[channel]
			end
			if counts then
				keys = keys or {}
				keys[key] = true
			end
		end
		if not keys and generic and small and asking then keys = ASK.ANY end
		return keys
	end

	-- Whether a message is your own: true, false, or nil for could not tell,
	-- which callers treat as yours. The GUID decides where both are readable;
	-- otherwise the whole name, so another Mort on a client with surnames is
	-- not taken for you.
	local function Mine(sender, guid)
		local me = plain(UnitGUID("player"))
		if guid and type(me) == "string" then return guid == me end
		local first = plain(UnitName("player"))
		if type(first) ~= "string" then return nil end
		local short = ShortName(sender)
		return short == first or short == ns.UnitFullName("player")
	end

	local function Live(request, now)
		return request.fight or request.expires > now
	end

	local function Sweep(now)
		for i = #requests, 1, -1 do
			if not Live(requests[i], now) then table.remove(requests, i) end
		end
	end

	-- Whether a request was made by the person behind this unit: the GUID
	-- where both sides have one, else the name or its first word, since a chat
	-- sender on the client with surnames may be either.
	local function Made(request, guid, short, first)
		if request.guid and guid then return request.guid == guid end
		if SameName(request.short, short) then return true end
		return first ~= nil and SameName(request.short, first)
	end

	-- A chat message from `channel` -- SAY, WHISPER and so on -- in the shape
	-- the client hands it over: the text, the sender, and the sender's GUID.
	function ns.NoteRequest(channel, text, sender, guid)
		local db = addon.db and addon.db.profile
		if not (db and db.enabled and db.sources.asked) then return end
		ns.askScan.heard = ns.askScan.heard + 1
		-- plain() before anything else touches them: a secret throws on the
		-- first comparison and must not even be kept.
		text, sender, guid = plain(text), plain(sender), plain(guid)
		if type(text) ~= "string" or type(sender) ~= "string" or sender == "" then
			ns.askScan.unreadable = ns.askScan.unreadable + 1
			return
		end
		if type(guid) ~= "string" or guid == "" then guid = nil end
		if Mine(sender, guid) ~= false then
			ns.askScan.own = ns.askScan.own + 1
			return
		end
		local keys = Asks(text, channel)
		if not keys then return end
		-- In a fight "int pls" is an interrupt, so only a whisper counts, and
		-- it is held until the fight is over.
		local fighting = InCombatLockdown() and true or nil
		if fighting and channel ~= "WHISPER" then
			ns.askScan.fight = ns.askScan.fight + 1
			return
		end

		local now = GetTime()
		Sweep(now)
		-- One standing request per person: asking again starts the minute again
		-- and asks for what the new message asks for.
		local short = ShortName(sender)
		for i = #requests, 1, -1 do
			if Made(requests[i], guid, short, nil) then table.remove(requests, i) end
		end
		requests[#requests + 1] = {
			name = sender, short = short, guid = guid, keys = keys, at = now,
			expires = now + ASK_SECONDS, channel = channel,
			fight = fighting,
		}
		while #requests > ASK_KEEP do table.remove(requests, 1) end
		ns.askScan.noted = ns.askScan.noted + 1
	end

	-- What the person behind `unit`, filed as `full`, asked for, as the part
	-- of `candidates` (the queue's castable list) that answers it, or nil. A
	-- pin still means only that one spell. Nobody of your own class has asked;
	-- a class that cannot be read is not taken for yours. `askOnly` is the
	-- scan's neverAuto spells (ns.AskOnlyBuffs), offered to whoever names one:
	-- "buff pls" names every buff you have, not one Automatic leaves alone.
	function ns.AskedFor(unit, full, now, candidates, askOnly)
		if #requests == 0 then return nil end
		local db = addon.db and addon.db.profile
		if not (db and db.sources.asked) then return nil end
		if plain(select(2, UnitClass(unit))) == ns.PlayerClass() then return nil end
		local guid = plain(UnitGUID(unit))
		if type(guid) ~= "string" then guid = nil end
		local short, first = ShortName(full), FirstName(full)
		for _, request in ipairs(requests) do
			if Live(request, now) and Made(request, guid, short, first) then
				local pinned = ns.PinnedBuff()
				local pool = {}
				for _, buff in ipairs(candidates) do
					if (request.keys == ASK.ANY or request.keys[buff.key])
						and (not pinned or pinned.key == buff.key) then
						pool[#pool + 1] = buff
					end
				end
				if askOnly and request.keys ~= ASK.ANY then
					for _, buff in ipairs(askOnly) do
						if request.keys[buff.key] then pool[#pool + 1] = buff end
					end
				end
				if #pool == 0 then return nil end
				request.full = full
				return pool
			end
		end
		return nil
	end

	-- Whether any request stands at all, for the queue to know that a walk
	-- could still serve somebody when it has nothing to offer unasked.
	function ns.RequestStanding(now)
		for _, request in ipairs(requests) do
			if Live(request, now) then return true end
		end
		return false
	end

	-- Whether somebody still has a request standing that asks for this buff,
	-- for an asker Queue.lua remembers after the cursor has left them, who has
	-- no unit to match: by the name AskedFor wrote on it when a token matched
	-- it, or by name as ServeRequest closes one (asking again replaces the
	-- request, and the new one has not been matched yet). The pin and the
	-- switches are the queue's to check, against its castable list.
	function ns.StillAsked(full, buffKey, now)
		local db = addon.db and addon.db.profile
		if not (db and db.sources.asked) or type(full) ~= "string" then return false end
		local short = ShortName(full)
		for _, request in ipairs(requests) do
			if Live(request, now) and (request.full == full or (request.full == nil and SameName(request.short, short)))
				and (request.keys == ASK.ANY or request.keys[buffKey]) then
				return true
			end
		end
		return false
	end

	-- A buff landed on them. Called from the settle, beside the favour being
	-- settled, with the buff's key. A request is answered buff by buff: the one
	-- that landed comes off it, and it closes once nothing it asked for is
	-- left, so a favour returned, or the first of two buffs, leaves the rest
	-- standing. No key closes it whole. A refusal that arrives after it does
	-- not put anything back -- they can ask again.
	function ns.ServeRequest(name, buffKey)
		if type(name) ~= "string" then return end
		local short = ShortName(name)
		for i = #requests, 1, -1 do
			local request = requests[i]
			-- A request a token has matched answers to the name it wrote on it,
			-- and only that: another realm's Anna is a person of her own.
			if request.full == name or (request.full == nil and SameName(request.short, short)) then
				-- "buff pls" becomes the rest of what you can cast, each to be
				-- given once: whether they carry a buff often cannot be read,
				-- and then only this list stops the same one being offered
				-- again. ASK.ANY itself is shared by every such request, so it
				-- is replaced, never written.
				if buffKey and request.keys == ASK.ANY then
					request.keys = {}
					for _, buff in ipairs(ns.CastableBuffs()) do request.keys[buff.key] = true end
				end
				if buffKey then request.keys[buffKey] = nil end
				if not buffKey or next(request.keys) == nil then table.remove(requests, i) end
			end
		end
	end

	-- The two ends of a fight: requests standing at the start are held through
	-- it and get their minute from its end -- once, or chained pulls would keep
	-- one "int pls" standing for the whole dungeon.
	function ns.HoldRequestsForFight()
		local now = GetTime()
		for _, request in ipairs(requests) do
			if Live(request, now) and not request.held then request.fight = true end
		end
	end

	function ns.RequestsAfterFight()
		local now = GetTime()
		for _, request in ipairs(requests) do
			if request.fight then
				request.fight = nil
				request.held = true
				request.expires = now + ASK_SECONDS
			end
		end
		Sweep(now)
	end

	-- For /manners debug: one line per standing request, or the reason there
	-- are none.
	function ns.RequestLines()
		local db = addon.db and addon.db.profile
		local lines = {}
		if not (db and db.sources.asked) then
			lines[1] = L["not listening for requests -- %s is switched off."]:format("|cffffd100" .. L["People who ask me in chat"] .. "|r")
			return lines
		end
		local now = GetTime()
		Sweep(now)
		local scan = ns.askScan
		lines[1] = L["requests: %d messages read, %d unreadable, %d yours, %d asked in a fight and let go, %d asked for a buff"]
			:format(scan.heard, scan.unreadable, scan.own, scan.fight, scan.noted)
		for _, request in ipairs(requests) do
			local what = {}
			if request.keys == ASK.ANY then
				what[1] = L["any buff"]
			else
				for _, buff in ipairs(ns.GetClassBuffs(ns.PlayerClass()) or {}) do
					if request.keys[buff.key] then what[#what + 1] = ns.BuffName(buff) end
				end
			end
			local where = ASK.slash[request.channel] or tostring(request.channel)
			if request.fight then
				lines[#lines + 1] = L["asked in %s: |cffffffff%s|r for %s (held until the fight ends)"]
					:format(where, request.name, table.concat(what, ", "))
			else
				lines[#lines + 1] = L["asked in %s: |cffffffff%s|r for %s (%ds left)"]
					:format(where, request.name, table.concat(what, ", "),
						math.floor(request.expires - now))
			end
		end
		if #requests == 0 then lines[#lines + 1] = L["nobody has asked you for a buff recently."] end
		return lines
	end
end

-- The channels a request can arrive in, each registered on this client by
-- addons known to work on it (EnhanceQoL). Each hands over the text, the
-- sender and, twelfth, the sender's GUID. Your own whispers arrive as
-- WHISPER_INFORM, which is not listened to.
function addon:CHAT_MSG_SAY(_, text, sender, ...)
	ns.Guard("request", ns.NoteRequest, "SAY", text, sender, (select(10, ...)))
end
function addon:CHAT_MSG_YELL(_, text, sender, ...)
	ns.Guard("request", ns.NoteRequest, "YELL", text, sender, (select(10, ...)))
end
function addon:CHAT_MSG_PARTY(_, text, sender, ...)
	ns.Guard("request", ns.NoteRequest, "PARTY", text, sender, (select(10, ...)))
end
function addon:CHAT_MSG_PARTY_LEADER(_, text, sender, ...)
	ns.Guard("request", ns.NoteRequest, "PARTY_LEADER", text, sender, (select(10, ...)))
end
function addon:CHAT_MSG_RAID(_, text, sender, ...)
	ns.Guard("request", ns.NoteRequest, "RAID", text, sender, (select(10, ...)))
end
function addon:CHAT_MSG_RAID_LEADER(_, text, sender, ...)
	ns.Guard("request", ns.NoteRequest, "RAID_LEADER", text, sender, (select(10, ...)))
end
-- A group the game's group finder made talks here rather than in /party or
-- /raid, whichever the player typed.
function addon:CHAT_MSG_INSTANCE_CHAT(_, text, sender, ...)
	ns.Guard("request", ns.NoteRequest, "INSTANCE_CHAT", text, sender, (select(10, ...)))
end
function addon:CHAT_MSG_INSTANCE_CHAT_LEADER(_, text, sender, ...)
	ns.Guard("request", ns.NoteRequest, "INSTANCE_CHAT_LEADER", text, sender, (select(10, ...)))
end
function addon:CHAT_MSG_WHISPER(_, text, sender, ...)
	ns.Guard("request", ns.NoteRequest, "WHISPER", text, sender, (select(10, ...)))
end
