-- Manners -- the words on the prompt: the name line and the reason line for
-- the person offered, and a click's outcome written over them.

local _, ns = ...
local L = ns.L
local Prompt = ns.Prompt
local S, R, lib = Prompt.state, Prompt.regions, Prompt.lib
local GetTime = _G.GetTime
local REASON_KEY, RemainingText, OUTCOME_SECONDS = lib.REASON_KEY, lib.RemainingText, lib.OUTCOME_SECONDS
local Gradient, SetLine, ShowChip, FullEffects = lib.Gradient, lib.SetLine, lib.ShowChip, lib.FullEffects

-- The softened class codes ClassColored has worked out, for the look's
-- classSoften in `by`.
local softened = {}

local function ClassColored(entry, text)
	if not ns.db.profile.prompt.classColor or not entry.class then return text end
	local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.class]
	if not c or not c.colorStr then return text end
	-- Taken towards white where the look asks, so a name never reads as a
	-- reason colour.
	local soften = S.activeLook and S.activeLook.classSoften
	-- A look on a light ground (the letter's parchment) takes the class colour
	-- darker, until it reads at this contrast on that ground, first taken a
	-- part of the way to the look's own ink (`classInk`: r, g, b and how far) so
	-- that a pale class is a coloured ink and not a grey. Worked out once per
	-- class: ApplyStyle empties ink.codes, where it is kept.
	local contrast = S.activeLook and S.activeLook.classContrast
	if contrast then
		local key = "class" .. c.colorStr
		local codes = lib.ink.codes
		local code = codes[key]
		if not code then
			local function at(i) return (tonumber(c.colorStr:sub(i, i + 1), 16) or 255) / 255 end
			local r, g, b = at(3), at(5), at(7)
			local own = S.activeLook.classInk
			if own then
				r, g, b = r + (own[1] - r) * own[4], g + (own[2] - g) * own[4], b + (own[3] - b) * own[4]
			end
			r, g, b = lib.Legible(r, g, b, contrast)
			code = ("|cff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
				math.floor(b * 255 + 0.5))
			codes[key] = code
		end
		return ("%s%s|r"):format(code, text)
	end
	if soften then
		-- Worked out once per class and look: this runs on every repaint.
		if softened.by ~= soften then wipe(softened) softened.by = soften end
		local code = softened[c.colorStr]
		if not code then
			-- From the code itself ("ffRRGGBB"), which every client fills in.
			local function up(at)
				local v = (tonumber(c.colorStr:sub(at, at + 1), 16) or 255) / 255
				return math.floor((v + (1 - v) * soften) * 255 + 0.5)
			end
			code = ("|cff%02x%02x%02x"):format(up(3), up(5), up(7))
			softened[c.colorStr] = code
		end
		return ("%s%s|r"):format(code, text)
	end
	return string.format("|c%s%s|r", c.colorStr, text)
end

-- Core's; its comment says why substitutions use a function replacement.
-- Local because this runs on every line of every repaint.
local Swap = ns.Swap

local function Substitute(template, entry, extra)
	local out = template or ""
	-- A group cast names the party it is for ("Gwen's party") in the name's
	-- place, and the group spell in the buff's.
	out = Swap(out, "{name}", entry.display or entry.short or entry.name or "?")
	out = Swap(out, "{count}", tostring(extra or 0))
	out = Swap(out, "{class}", ns.ClassName(entry.class))
	out = Swap(out, "{buff}", entry.buff and ns.EntrySpellName(entry) or "")
	-- Empty for everybody who is simply missing the buff: only a top-up has a
	-- timer to quote, and the queue sets `remaining` for nobody else.
	out = Swap(out, "{time}", RemainingText(entry.remaining))
	return out
end

-- The icon of the buff an entry offers: the group spell's for a group cast,
-- else the buff's own. The prompt's icon and the list's rows are both drawn
-- from it, and read nothing of the person (no aura is asked for).
local function EntryIcon(entry)
	local info = ns.BuffInfo(entry.buff)
	local groupIcon = entry.groupCast and entry.groupCast.icon
	return groupIcon or (info and info.icon) or 135932
end

function Prompt:ReasonText(entry)
	local p = ns.db.profile.prompt
	-- A group cast's second line is what it is and for how many, which no
	-- reason line the player wrote can say.
	local group = entry.groupCast
	if group then
		local missing, low = group.missing or 0, group.low or 0
		local spell = ns.EntrySpellName(entry)
		if low == 0 then return L["%s -- %d missing"]:format(spell, missing) end
		if missing == 0 then return L["%s -- %d running out"]:format(spell, low) end
		return L["%s -- %d need it"]:format(spell, missing + low)
	end
	local template = p[REASON_KEY[entry.reason] or "reasonNearby"] or ""
	-- The sub-line must be true without hovering: a top-up gets its own
	-- wording, and so does an unreadable aura except for owed or asked, whose
	-- reason is the line worth reading. Swapped in whole, since reason lines
	-- are free text. One chain on purpose, so both can never apply. A group
	-- member a ready check or a death put first says that instead: it is why
	-- they are at the front, and the queue only does it for a reading.
	if entry.sweep and entry.reason == "group" then
		template = entry.sweep == "readycheck" and L["ready check"] or L["just revived"]
	elseif entry.charges then
		-- A charge shield topped up for its charges, not its time.
		template = entry.charges == 1 and L["1 charge left"] or L["%d charges left"]:format(entry.charges)
	elseif RemainingText(entry.remaining) then
		template = p.reasonRefresh or template
	elseif entry.checked and entry.known == nil and entry.reason ~= "owed"
		and entry.reason ~= "asked" then
		template = p.reasonUnknown or template
	end
	return Substitute(template, entry, 0)
end

function Prompt:RenderPrimary(entry, extra)
	local p = ns.db.profile.prompt
	local template = p.format or "{name}"
	local out = Substitute(template, entry, extra)
	if template:find("{name}", 1, true) then
		-- The name is escaped into the pattern and the colour goes in through a
		-- function: gsub is being handed text, not a template.
		local plainName = entry.short or entry.name or "?"
		local coloured = ClassColored(entry, plainName)
		out = (out:gsub(plainName:gsub("(%W)", "%%%1"), function() return coloured end, 1))
	end
	-- A reason line is free text, and as a gsub replacement a % in it ("10%
	-- left") threw on every repaint; Swap takes it as text.
	return Swap(out, "{reason}", self:ReasonText(entry))
end

---------------------------------------------------------------------------
-- what the click turned into
--
-- Three states, because the settle path separates a confirmed cast from one
-- the client would not attribute.
---------------------------------------------------------------------------

-- Which outcome the expiry timer was set for, so a timer left from an earlier
-- outcome is ignored.
local outcomeGen = 0

-- The cross-fade the text takes when it is about to change: a new person on
-- the panel (Refresh) or an outcome over it (ShowOutcome). In the first beat
-- of the entrance, while the words are still arriving, the reveal is let go
-- and the words put at full, so the dip starts from full and never leaves
-- them half-lit, nor has two groups drive their alpha at once. On the three
-- looks drawn here only: under a look from Looks/ the words' alpha is the
-- look's own.
function Prompt:SwapText()
	if not S.activeLook and R.textLayer.reveal and R.textLayer.reveal:IsPlaying() then
		R.textLayer.reveal:Stop()
		R.textLayer:SetAlpha(1)
	end
	if R.textLayer.swap then
		R.textLayer.swap:Stop()
		R.textLayer.swap:Play()
	end
end

function Prompt:ShowOutcome(kind, name, detail)
	if not R.button then return end
	S.outcomeKind, S.outcomeAt, S.outcomeName, S.outcomeDetail = kind, GetTime(), name, detail
	-- A new outcome gets its own wash, even one in the same instant as the last.
	S.washStamp = nil
	self:SwapText()
	-- Taken off on time rather than at the next scan.
	self:PlayOutcomeFlourish(kind)
	outcomeGen = outcomeGen + 1
	local gen = outcomeGen
	if C_Timer and C_Timer.After then
		C_Timer.After(OUTCOME_SECONDS + 0.05, function()
			if gen ~= outcomeGen then return end
			ns.Guard("prompt outcome expiry", Prompt.Refresh, Prompt)
		end)
	end
	-- Painted now rather than waiting for the scan. At 0.4s between ticks, a
	-- confirmation that waits for one misses most of its own half-second.
	ns.Guard("prompt outcome paint", Prompt.Refresh, self)
end

function Prompt:OutcomeLive()
	if not S.outcomeKind then return false end
	if GetTime() - S.outcomeAt <= OUTCOME_SECONDS then return true end
	S.outcomeKind, S.outcomeAt, S.outcomeName, S.outcomeDetail = nil, nil, nil, nil
	if R.resultFill then R.resultFill:Hide() end
	self:UngreyIcon()
	if S.activeLook then S.activeLook:ClearOutcome() end
	return false
end

-- Who the panel names for a press: the outcome's person while its words are on
-- the name line, otherwise the entry last painted.
function Prompt:PanelName()
	if S.outcomePainted then return S.outcomePainted end
	return S.heldEntry and S.heldEntry.name
end

-- A press aimed at somebody the panel is not naming: nothing is cast. The
-- panel is brought up to date and disarmed, so the next press casts at who it
-- says.
function Prompt:MovedOn(top)
	S.outcomeKind, S.outcomeAt, S.outcomeName, S.outcomeDetail = nil, nil, nil, nil
	S.outcomePainted = nil
	if R.resultFill then R.resultFill:Hide() end
	self:UngreyIcon()
	if S.activeLook then S.activeLook:ClearOutcome() end
	ns.Guard("prompt moved on", Prompt.Refresh, self)
	self:ApplyTarget(nil)
	-- Your own buff by what it is: your name in the third person reads as
	-- somebody else who shares it.
	if top.reason == "self" then
		ns.addon:Print(L["the prompt has moved on to your own buff -- press again to buff yourself."])
		return
	end
	-- A group cast by whom it lands on and what it is: the entry is a copy of
	-- one member, and the next press casts the group spell on them all, with
	-- its reagent.
	if top.groupCast then
		ns.addon:Print(L["the prompt has moved on to |cffffffff%s|r -- press again to cast |cffffffff%s|r on them all."]
			:format(top.groupCast.label or "?", ns.EntrySpellName(top)))
		return
	end
	ns.addon:Print(L["the prompt has moved on to |cffffffff%s|r -- press again to buff them."]
		:format(tostring(top.short or top.name)))
end

-- Written over whatever Paint put on the panel: by the time the outcome lands
-- the queue has usually moved on.
function Prompt:PaintOutcome()
	-- No name is rare, and each headline has its own "them" sentence for it,
	-- for the same reason as in ClickSummary.
	local who = ns.ShortName and ns.ShortName(S.outcomeName) or S.outcomeName
	-- A press on yourself says so, rather than naming you like a stranger.
	local own = ns.IsPlayerName(S.outcomeName)

	local r, g, b = self:AccentColor(S.current and S.current.reason or "owed")
	local lead, sub

	if S.outcomeKind == "failed" then
		-- Red, with the game's own localised words underneath: often the only
		-- thing that says why (range, line of sight, mana).
		r, g, b = 0.90, 0.26, 0.22
		lead = own and L["|cffff8080could not buff|r |cffffffffyourself|r"]
			or who and L["|cffff8080could not buff|r |cffffffff%s|r"]:format(who)
			or L["|cffff8080could not buff|r |cffffffffthem|r"]
		sub = S.outcomeDetail
	elseif S.outcomeKind == "sent" then
		-- Deliberately not a tick: our spell went out, but tying it to this
		-- person is an inference, and the panel says it at the settle path's
		-- strength. The settle sends the clause for which inference; the
		-- fallback is the commoner.
		lead = who and L["|cffe8e0a0sent to|r |cffffffff%s|r"]:format(who)
			or L["|cffe8e0a0sent to|r |cffffffffthem|r"]
		sub = S.outcomeDetail or L["cast -- this client will not confirm who to"]
	elseif own then
		-- [@player] can land nowhere else, so our spell going out is the
		-- whole answer (Clicks.lua, SettleSelf).
		lead = L["|cff8ce88cbuffed|r |cffffffffyourself|r"]
		sub = L["cast on you"]
	else
		lead = who and L["|cff8ce88cbuffed|r |cffffffff%s|r"]:format(who)
			or L["|cff8ce88cbuffed|r |cffffffffthem|r"]
		sub = L["the game confirmed it"]
	end

	-- A look of its own writes the outcome its way; the count goes as here.
	if S.activeLook then
		S.activeLook:PaintOutcome(S.outcomeKind, lead, sub, own and L["You"] or who, S.outcomeAt)
		S.accentPainted = nil
		S.outcomePainted = S.outcomeName
		ShowChip(false)
		R.countText:SetText("")
		return
	end

	-- A low-alpha wash over the whole panel, read without being looked at.
	-- Lighter for a refusal, which the red words and ring already say, and
	-- lightest for an unconfirmed cast. On Full it rises and fades (PlayWash)
	-- once per outcome: a repaint of the same outcome touches neither its
	-- alpha nor its colour. On Calm it is set and left, a fade's worth lighter.
	if FullEffects() then
		if S.washStamp ~= S.outcomeAt or not R.resultFill:IsShown() then
			S.washStamp = S.outcomeAt
			R.resultFill:SetVertexColor(r, g, b, 1)
			R.resultFill:Show()
			self:PlayWash(S.outcomeKind)
		end
	else
		local wash = (S.outcomeKind == "failed" and 0.15) or (S.outcomeKind == "sent" and 0.14) or 0.20
		R.washFrame:SetAlpha(1)
		R.resultFill:SetVertexColor(r, g, b, wash)
		R.resultFill:Show()
	end
	-- The bezel says it too, where it carries a colour at all: its metal goes
	-- red. Put back by the next PaintAccent, which every repaint of a person
	-- runs.
	local mode = ns.db.profile.prompt.accentMode or "icon"
	if S.outcomeKind == "failed" and (mode == "icon" or mode == "both") then
		R.bezel:SetVertexColor(0.80, 0.26, 0.22, 1)
		S.accentPainted = nil
	end
	-- And the icon greys for the outcome: a state, not a motion, so Calm has it
	-- too. The flag is what UngreyIcon reads at every clear, so a scan with
	-- nothing to undo costs no client call.
	if S.outcomeKind == "failed" then
		R.icon:SetDesaturated(true)
		S.iconGreyed = true
	end
	SetLine(R.nameText, lead)
	S.outcomePainted = S.outcomeName
	if R.subText:IsShown() then SetLine(R.subText, sub or "") end
	ShowChip(false)
	R.countText:SetText("")
end

-- What a branch paints when the fight would not let the prompt go. The two
-- shapes -- inert, or still armed by the fight -- are read off the attribute
-- PostClick warns about, so the two agree. Callers pass whole sentences, not a
-- reason word: a translator needs the sentence the word agrees with.
function Prompt:PaintHeldInert(whyFrozen, whyInert)
	local frozen = R.button:GetAttribute("macrotext1")
	SetLine(R.nameText, frozen and "|cffff8080" .. L["still armed by the fight"] .. "|r"
		or "|cff909098" .. L["nothing to buff"] .. "|r")
	S.outcomePainted = nil
	if R.subText:IsShown() then
		SetLine(R.subText, ("|cffb0b0b0%s|r"):format(frozen and whyFrozen or whyInert))
	end
	-- Every other claim on the panel goes with the name: a count of a queue
	-- that is not being offered, and the wash of colour from a click that is
	-- over.
	ShowChip(false)
	R.countText:SetText("")
	R.resultFill:Hide()
	self:UngreyIcon()
	if S.activeLook then S.activeLook:ClearOutcome() end
	self:PaintAccent("nearby")
	-- The same statement the held panel makes, for the same reason: nothing
	-- here can be pointed at anybody until the fight ends.
	self:SetCombatHold(true)
end

function Prompt:Paint(entry, extra)
	local p = ns.db.profile.prompt

	SetLine(R.nameText, self:RenderPrimary(entry, extra))
	-- The name line is the entry's again, so a press follows the entry.
	S.outcomePainted = nil
	if R.subText:IsShown() then SetLine(R.subText, self:ReasonText(entry)) end

	local showCount = p.showCount and extra > 0
	R.countText:SetText(showCount and tostring(extra) or "")
	ShowChip(showCount)

	self:PaintAccent(entry.reason)
	-- On every paint of a person, the scan's own tick: a look's clock.
	if S.activeLook and S.activeLook.Painted then S.activeLook:Painted(entry) end

	if p.showIcon then R.icon:SetTexture(EntryIcon(entry)) end
	-- A person's icon is in colour: a refusal's grey is the outcome's, and
	-- PaintOutcome (which follows while one is live) greys it again.
	self:UngreyIcon()
end

lib.Substitute, lib.EntryIcon = Substitute, EntryIcon
