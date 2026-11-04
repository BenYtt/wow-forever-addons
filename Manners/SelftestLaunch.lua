-- Manners -- /manners selftest launch: the parts of Manners that have never run
-- in a real client, asked of the one it is running in.
--
-- Several features were written against Blizzard's documentation and the mock
-- in tests/ and have not seen a game: the looks Ribbon, Letter and Leather
-- (Morpheus, masks, the unroll's clipping, tiled strips, animations), the
-- look picker's live card icons and text, the action bar slot of the macro
-- (SetMacroSpell, SetMacroItem, clearing with "", PickupMacro), the key
-- glyphs on the chip for a controller, the tooltip's settings (anchors,
-- Shift), the hand-back with nothing targeted, and the prompt laying itself
-- out again when the display changes. One command asks the client about each
-- and says what it answered, so that a report can be read for what the game
-- did, not for what Manners hoped.
--
--   PASS   the client answered as Manners expects
--   CHECK  it answered something else, Manners falls back, or only eyes can
--          tell (the line says which)
--   FAIL   an error, or a refusal Manners has no way round
--
-- WHAT IT TOUCHES, AND HOW IT PUTS IT BACK. Out of combat only (the command
-- refuses in a fight, and nothing here is asked in one). It casts nothing,
-- says nothing and presses nothing. The prompt's style is switched through
-- every look in one go, inside one call, so no frame is drawn between them,
-- and put back before the call ends; the profile is never written to
-- otherwise. The macro's slot is set, read back and cleared on the player's
-- own Manners macro, and put back to what it showed (what it held is read
-- first); a player with no such macro gets a temporary one named
-- MannersSelfTest, made for this and deleted at the end, and the report says
-- so. The cursor is checked to be empty before the macro is picked up and
-- emptied after. The tooltip is a scratch one of its own: the game's is never
-- touched. Everything else is drawn on a hidden scratch frame made once.
--
-- It is quick: one pass in a single frame (a few milliseconds a look, the
-- first time a look is shown, which builds it) and half a second of listening
-- afterwards for UPDATE_MACROS, which tells a macro call that the client
-- answers once from one it answers forever.

local _, ns = ...
local L = ns.L
local addon = ns.addon
local Selftest = ns.Selftest
if not Selftest or not Selftest.tools then return end

local T = Selftest.tools
local Show, Plain, Ask, MISSING, Field, SomeSpell = T.Show, T.Plain, T.Ask, T.MISSING, T.Field, T.SomeSpell
local InCombatLockdown = _G.InCombatLockdown
local unpack = _G.unpack or table.unpack

local PASS, CHECK, FAIL = "PASS", "CHECK", "FAIL"
local RANK = { [PASS] = 1, [CHECK] = 2, [FAIL] = 3 }
-- Bindings.xml's command.
local COMMAND = "CLICK MannersPrompt:LeftButton"
local MORPHEUS = "Fonts\\MORPHEUS.TTF"
local ART = "Interface\\AddOns\\Manners\\Textures\\"
-- The client languages whose alphabet Morpheus draws (Ribbon, Letter, Leather).
local ROMAN = { enUS = true, enGB = true, deDE = true, esES = true, esMX = true, frFR = true, itIT = true, ptBR = true }
-- The macro made for the test when the player has none of their own.
local TEMP_MACRO = "MannersSelfTest"
-- How long the listener for UPDATE_MACROS stays up after the calls, and from
-- when in it an event counts as the client still answering.
local LISTEN, QUIET_AFTER = 0.5, 0.25
local QUESTION_MARK = 134400

local LAUNCH = {}
Selftest.LAUNCH = LAUNCH

-- run(add, ctx): add(status, value[, label[, id]]). A `late` check runs after
-- the half second of listening, with the rest of the report already made.
local function Launch(id, label, run, late)
	LAUNCH[#LAUNCH + 1] = { id = id, label = label, run = run, late = late }
end

local function Clock()
	local now = _G.debugprofilestop
	if type(now) == "function" then return now() end
	return nil
end

-- A method of a client object: MISSING when there is none, else pcall's answer.
local function Call(obj, method, ...)
	if type(obj) ~= "table" and type(obj) ~= "userdata" then return MISSING end
	local fn = obj[method]
	if type(fn) ~= "function" then return MISSING end
	return pcall(fn, obj, ...)
end

local function Lower(v) return type(v) == "string" and v:lower() or v end

---------------------------------------------------------------------------
-- the scratch objects, made once for the session and never shown
---------------------------------------------------------------------------

local function Scratch()
	local s = Selftest.scratch
	if s then return s end
	s = {}
	s.frame = CreateFrame("Frame", nil, UIParent)
	s.frame:Hide()
	s.tex = s.frame:CreateTexture(nil, "ARTWORK")
	s.fs = s.frame:CreateFontString(nil, "OVERLAY")
	s.clip = CreateFrame("Frame", nil, s.frame)
	-- The picker's card, in little: an icon, a mask and two lines of text.
	s.cardIcon = s.frame:CreateTexture(nil, "ARTWORK")
	s.cardLine = s.frame:CreateFontString(nil, "OVERLAY")
	-- Animations are tried on a frame that is up and draws nothing.
	s.animFrame = CreateFrame("Frame", nil, UIParent)
	s.animFrame:SetSize(1, 1)
	s.animFrame:SetAlpha(0)
	s.events = CreateFrame("Frame")
	s.log = {}
	s.events:SetScript("OnEvent", function(_, event)
		ns.Guard("selftest event", function()
			s.log[#s.log + 1] = { event = event, at = GetTime() }
		end)
	end)
	Selftest.scratch = s
	return s
end

-- For the scenarios, which swap what a scratch object answers.
Selftest.Scratch = Scratch

local function Registered(event)
	local get = _G.LibStub
	if type(get) ~= "table" and type(get) ~= "function" then return nil end
	local ok, lib = pcall(get, "AceEvent-3.0", true)
	local registry = ok and type(lib) == "table" and type(lib.events) == "table" and lib.events.events
	if type(registry) ~= "table" then return nil end
	local who = registry[event]
	return type(who) == "table" and who[addon] ~= nil
end

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------

-- The four events launch day cares about, each tried on a frame of our own:
-- a client that does not know one refuses the registration with an error.
-- `severity` is what a refusal costs: the three the addon registers through
-- a guard cost a feature, the one the tooltip registers on hovering costs an
-- error.
local EVENTS = {
	{ "UPDATE_MACROS", CHECK, "the action bar slot is not set again when the macro list changes" },
	{ "UI_SCALE_CHANGED", CHECK, "the prompt is not laid out again for a new UI scale" },
	{ "DISPLAY_SIZE_CHANGED", CHECK, "the prompt is not laid out again for a new resolution" },
	{ "MODIFIER_STATE_CHANGED", FAIL, "hovering the prompt with a tooltip setting that watches Shift would throw" },
}

Launch("launch.events", "events", function(add)
	local frame = Scratch().events
	Call(frame, "UnregisterEvent", "UPDATE_MACROS")
	local parts, status = {}, PASS
	for _, row in ipairs(EVENTS) do
		local event, cost, why = row[1], row[2], row[3]
		local ok, err = Call(frame, "RegisterEvent", event)
		if ok == true then
			local heard = Registered(event)
			parts[#parts + 1] = event .. " exists" .. (heard == nil and "" or heard and ", Manners listens"
				or ", Manners does NOT listen")
			if heard == false and RANK[CHECK] > RANK[status] then status = CHECK end
			-- UPDATE_MACROS stays up for the half second after the macro calls.
			if event ~= "UPDATE_MACROS" then Call(frame, "UnregisterEvent", event) end
		else
			parts[#parts + 1] = event .. " REFUSED (" .. (ok == MISSING and "no RegisterEvent" or tostring(err)) .. ") -- " .. why
			if RANK[cost] > RANK[status] then status = cost end
		end
	end
	add(status, table.concat(parts, "; "))
end)

---------------------------------------------------------------------------
-- the macro's slot on an action bar
---------------------------------------------------------------------------

local function SpellNameOf(spell)
	if type(spell) == "string" then return spell end
	if type(spell) ~= "number" then return nil end
	local fn = Field(_G.C_Spell, "GetSpellName")
	if type(fn) == "function" then
		local ok, name = pcall(fn, spell)
		if ok and type(Plain(name)) == "string" then return name end
	end
	if type(_G.GetSpellInfo) == "function" then
		local ok, name = pcall(_G.GetSpellInfo, spell)
		if ok and type(Plain(name)) == "string" then return name end
	end
	return nil
end

-- What the slot shows now: the spell (an id) and the item (name, link), as the
-- client reads them back.
local function ReadSlot(index)
	local slot = {}
	local ok, spell = Ask(_G.GetMacroSpell, index)
	slot.spellKnown = ok == true
	slot.spell = ok == true and Plain(spell) or nil
	local okI, name, link = Ask(_G.GetMacroItem, index)
	slot.itemKnown = okI == true
	slot.itemName = okI == true and Plain(name) or nil
	slot.itemLink = okI == true and Plain(link) or nil
	return slot
end

-- The slot as it was: cleared, then given back what it held. Answers whether
-- reading it now says what it said before.
local function RestoreSlot(index, before)
	local setSpell, setItem = _G.SetMacroSpell, _G.SetMacroItem
	if type(setSpell) == "function" then pcall(setSpell, index, "") end
	if type(setItem) == "function" then pcall(setItem, index, "") end
	if before.spell ~= nil and type(setSpell) == "function" then
		pcall(setSpell, index, SpellNameOf(before.spell) or before.spell)
	end
	if (before.itemLink or before.itemName) and type(setItem) == "function" then
		pcall(setItem, index, before.itemLink or before.itemName)
	end
	local now = ReadSlot(index)
	return now.spell == before.spell and now.itemName == before.itemName, now
end

local function DeleteTemporary(ctx)
	local macro = ctx.macro
	if not (macro and macro.temp) or macro.deleted then return end
	macro.deleted = true
	local okI, index = Ask(_G.GetMacroIndexByName, TEMP_MACRO)
	if okI == true and type(Plain(index)) == "number" and index > 0 then
		local okN, name = Ask(_G.GetMacroInfo, index)
		-- Only a macro that is still the one made here.
		if okN ~= true or name == TEMP_MACRO then pcall(_G.DeleteMacro, index) end
	end
	local okAfter, left = Ask(_G.GetMacroIndexByName, TEMP_MACRO)
	macro.left = okAfter == true and type(Plain(left)) == "number" and left > 0
end

-- The macro the checks work on: the player's own, else (when asked to) a
-- temporary one, else nothing and the reason. `ctx.macro` false: none.
local function MacroTarget(ctx)
	if ctx.macro ~= nil then return ctx.macro end
	local name = ns.CLICK_MACRO_NAME or "Manners"
	local ok, index = Ask(_G.GetMacroIndexByName, name)
	if ok == true and type(Plain(index)) == "number" and index > 0 then
		ctx.macro = { index = index, name = name }
		return ctx.macro
	end
	ctx.macro = false
	if ok == MISSING then
		ctx.macroWhy = "GetMacroIndexByName is missing, so the macro cannot be looked for"
		return false
	end
	if not ctx.opts.createMacro then
		ctx.macroWhy = "no macro named " .. name .. " (make it with /manners macro, or run /manners selftest launch, which tests on a temporary one)"
		return false
	end
	if type(_G.CreateMacro) ~= "function" or type(_G.DeleteMacro) ~= "function" then
		ctx.macroWhy = "no macro named " .. name .. " and CreateMacro or DeleteMacro is missing, so a temporary one cannot be made"
		return false
	end
	-- Account-wide first, as Clicks.lua makes the real one, then this character's.
	local made, made1 = pcall(_G.CreateMacro, TEMP_MACRO, "INV_MISC_NOTE_03", "#MannersSelfTest", false)
	if not made then made, made1 = pcall(_G.CreateMacro, TEMP_MACRO, "INV_MISC_NOTE_03", "#MannersSelfTest", true) end
	if not made or type(Plain(made1)) ~= "number" or made1 <= 0 then
		ctx.macroWhy = "no macro named " .. name .. " and a temporary one could not be made"
			.. (made and "" or (": " .. tostring(made1)))
		return false
	end
	ctx.macro = { index = made1, name = TEMP_MACRO, temp = true }
	ctx.cleanup[#ctx.cleanup + 1] = function() DeleteTemporary(ctx) end
	return ctx.macro
end

-- Which macro the line is about, said every time.
local function MacroWhere(macro)
	if macro.temp then
		return ("a temporary macro %s (slot %d), made for this test and deleted at its end"):format(TEMP_MACRO, macro.index)
	end
	return ("your %s macro (slot %d), put back as it was"):format(macro.name, macro.index)
end

local function SlotText(slot)
	return ("spell %s, item %s"):format(Show(slot.spell), Show(slot.itemName))
end

Launch("launch.macro.slot", "SetMacroSpell", function(add, ctx)
	local macro = MacroTarget(ctx)
	if not macro then
		add(CHECK, "skipped: " .. tostring(ctx.macroWhy))
		return
	end
	local setSpell = _G.SetMacroSpell
	if type(setSpell) ~= "function" then
		add(CHECK, "SetMacroSpell is missing -- the bar slot keeps the note icon instead of the spell")
		return
	end
	if InCombatLockdown() then
		add(CHECK, "in combat -- not tried")
		return
	end
	local id = SomeSpell()
	local name = SpellNameOf(id)
	if not name then
		add(CHECK, "no spell name to try with")
		return
	end
	local before = ReadSlot(macro.index)
	local okSet, errSet = pcall(setSpell, macro.index, name)
	local afterSet = ReadSlot(macro.index)
	local okClear, errClear = pcall(setSpell, macro.index, "")
	local afterClear = ReadSlot(macro.index)
	local restored, now = RestoreSlot(macro.index, before)
	local where = MacroWhere(macro)
	if not okSet or not okClear then
		add(FAIL, ("SetMacroSpell(%d, %s) threw: %s (%s)"):format(macro.index, Show(name),
			tostring(okSet and errClear or errSet), where))
		return
	end
	local status, notes = PASS, {}
	local function worse(s, note)
		if RANK[s] > RANK[status] then status = s end
		notes[#notes + 1] = note
	end
	local shown = afterSet.spell
	if not afterSet.spellKnown then
		worse(CHECK, "GetMacroSpell is missing, so what the slot holds cannot be read back")
	elseif shown == nil then
		worse(CHECK, "GetMacroSpell answered nothing after setting it")
	elseif shown ~= id and shown ~= name and SpellNameOf(shown) ~= name then
		worse(CHECK, "GetMacroSpell answered something other than the spell set")
	end
	if afterSet.spellKnown and afterClear.spell ~= nil then
		worse(CHECK, "an empty string leaves the spell on the slot (with nobody to buff it would keep showing the last one)")
	end
	if not restored then
		worse(CHECK, "it could not be put back exactly: it showed " .. SlotText(before) .. ", now " .. SlotText(now))
	end
	add(status, ("SetMacroSpell(%d, %s) then GetMacroSpell answered %s; SetMacroSpell(%d, \"\") leaves %s; on %s%s"):format(
		macro.index, Show(name), Show(shown), macro.index, Show(afterClear.spell), where,
		#notes > 0 and (" -- " .. table.concat(notes, "; ")) or ""))
end)

Launch("launch.macro.item", "SetMacroItem", function(add, ctx)
	local macro = MacroTarget(ctx)
	if not macro then
		add(CHECK, "skipped: " .. tostring(ctx.macroWhy))
		return
	end
	local setItem = _G.SetMacroItem
	if type(setItem) ~= "function" then
		add(CHECK, "SetMacroItem is missing -- the bar slot keeps the note icon instead of a scroll's or an oil's")
		return
	end
	if InCombatLockdown() then
		add(CHECK, "in combat -- not tried")
		return
	end
	local item = "item:" .. tostring(T.ANY_ITEM)
	local before = ReadSlot(macro.index)
	local okSet, errSet = pcall(setItem, macro.index, item)
	local afterSet = ReadSlot(macro.index)
	local okClear, errClear = pcall(setItem, macro.index, "")
	local afterClear = ReadSlot(macro.index)
	local restored, now = RestoreSlot(macro.index, before)
	if not okSet or not okClear then
		add(FAIL, ("SetMacroItem(%d, %s) threw: %s"):format(macro.index, Show(item), tostring(okSet and errClear or errSet)))
		return
	end
	local status, notes = PASS, {}
	local function worse(note)
		status = CHECK
		notes[#notes + 1] = note
	end
	if not afterSet.itemKnown then
		worse("GetMacroItem is missing, so what the slot holds cannot be read back")
	elseif afterSet.itemName == nil then
		worse("GetMacroItem answered nothing after setting it")
	end
	if afterSet.itemKnown and afterClear.itemName ~= nil then
		worse("an empty string leaves the item on the slot")
	end
	if not restored then
		worse("it could not be put back exactly: it showed " .. SlotText(before) .. ", now " .. SlotText(now))
	end
	add(status, ("SetMacroItem(%d, %s) then GetMacroItem answered %s, %s; SetMacroItem(%d, \"\") leaves %s%s"):format(
		macro.index, Show(item), Show(afterSet.itemName), Show(afterSet.itemLink), macro.index,
		Show(afterClear.itemName), #notes > 0 and (" -- " .. table.concat(notes, "; ")) or ""))
end)

Launch("launch.macro.pickup", "PickupMacro", function(add, ctx)
	local macro = MacroTarget(ctx)
	if not macro then
		add(CHECK, "skipped: " .. tostring(ctx.macroWhy))
		return
	end
	local pickup, info, clear = _G.PickupMacro, _G.GetCursorInfo, _G.ClearCursor
	if type(pickup) ~= "function" then
		add(CHECK, "PickupMacro is missing -- the options button can only say where the macro is")
		return
	end
	if type(info) ~= "function" or type(clear) ~= "function" then
		add(CHECK, "GetCursorInfo or ClearCursor is missing, so the cursor cannot be checked and emptied")
		return
	end
	if InCombatLockdown() then
		add(CHECK, "in combat -- not tried")
		return
	end
	-- Something already carried is the player's: it is not touched.
	local okHeld, heldKind = Ask(info)
	if okHeld == true and heldKind ~= nil then
		add(CHECK, "something is on the cursor (" .. Show(heldKind) .. ") -- put it down and run this again")
		return
	end
	local okPick, errPick = pcall(pickup, macro.index)
	local okInfo, kind, which = Ask(info)
	pcall(clear)
	local _, kindAfter = Ask(info)
	if not okPick then
		add(FAIL, ("PickupMacro(%d) threw: %s"):format(macro.index, tostring(errPick)))
	elseif kindAfter ~= nil then
		add(FAIL, ("the macro was picked up and the cursor still holds %s after ClearCursor"):format(Show(kindAfter)))
	elseif okInfo ~= true or kind ~= "macro" then
		add(CHECK, ("PickupMacro(%d) then GetCursorInfo answered %s, %s -- the macro would not be carried to a bar"):format(
			macro.index, Show(kind), Show(which)))
	else
		add(PASS, ("PickupMacro(%d) then GetCursorInfo answered %s, %s; ClearCursor emptied it"):format(
			macro.index, Show(kind), Show(which)))
	end
end)

-- The bar macro carries the cast under its first line (Clicks.lua, click
-- macro): a body of two lines written and read back, on the temporary macro
-- only. The player's own Manners macro is never rewritten here (Manners writes
-- it as the prompt changes): for it, its first line and whose Manners counts
-- it.
Launch("launch.macro.body", "EditMacro", function(add, ctx)
	local macro = MacroTarget(ctx)
	if not macro then
		add(CHECK, "skipped: " .. tostring(ctx.macroWhy))
		return
	end
	local readBody = _G.GetMacroBody
	if not macro.temp then
		local okB, text = Ask(readBody, macro.index)
		text = okB == true and Plain(text) or nil
		local first = type(text) == "string" and text:match("^%s*([^\n]*)") or nil
		local state = ns.BarMacroState and ns.BarMacroState() or "?"
		local line = ("your %s macro (slot %d) starts %s, and Manners counts it %s; not rewritten here"):format(
			macro.name, macro.index, Show(first), state)
		if first == ns.BAR_LINE and state ~= "foreign" then
			add(PASS, line)
		else
			add(CHECK, line .. " -- Put Manners on an action bar hands it back to Manners")
		end
		return
	end
	if type(_G.EditMacro) ~= "function" or type(readBody) ~= "function" then
		add(CHECK, "EditMacro or GetMacroBody is missing -- the bar macro cannot carry the cast")
		return
	end
	if InCombatLockdown() then
		add(CHECK, "in combat -- not tried")
		return
	end
	local want = tostring(ns.BAR_LINE) .. "\n/cleartarget"
	-- Called as Clicks.lua calls it, with the macro's own name: a client that
	-- refuses a nil name would otherwise read as a fault Manners never meets.
	local okE, errE = pcall(_G.EditMacro, macro.index, macro.name, nil, want)
	local okB, back = Ask(readBody, macro.index)
	back = okB == true and Plain(back) or nil
	local got = type(back) == "string" and back:match("^%s*(.-)%s*$") or nil
	local where = MacroWhere(macro)
	if not okE then
		add(FAIL, ("EditMacro(%d) threw: %s (%s)"):format(macro.index, tostring(errE), where))
	elseif got == want then
		add(PASS, ("EditMacro wrote two lines and GetMacroBody read them back the same, on %s"):format(where))
	else
		add(CHECK, ("EditMacro wrote %s and GetMacroBody answered %s, on %s -- the bar macro would not carry the cast as written"):format(
			Show(want), Show(back), where))
	end
end)

Launch("launch.macro.cleanup", "temporary macro", function(add, ctx)
	local macro = ctx.macro
	if not macro then
		add(PASS, "none made")
		return
	end
	if not macro.temp then
		add(PASS, "none made -- the test used your own " .. macro.name .. " macro and put it back")
		return
	end
	DeleteTemporary(ctx)
	if macro.left then
		add(FAIL, TEMP_MACRO .. " is still there -- delete it in the macro window (/macro)")
	else
		add(PASS, TEMP_MACRO .. " was made for the test and has been deleted")
	end
end)

-- After the half second: the client answers a macro call with UPDATE_MACROS,
-- and Manners answers that by setting the slot again only when the macro's
-- place changed. A client that went on sending it after our last call would
-- say the slot is being set in a loop.
Launch("launch.macro.events", "UPDATE_MACROS", function(add, ctx)
	local log = Scratch().log
	local total, late = 0, 0
	for _, e in ipairs(log) do
		if e.event == "UPDATE_MACROS" then
			total = total + 1
			if ctx.listenFrom and e.at and e.at - ctx.listenFrom > QUIET_AFTER then late = late + 1 end
		end
	end
	if not ctx.macro then
		add(CHECK, "no macro call was made, so there was nothing to listen for")
	elseif late > 0 then
		add(CHECK, ("%d UPDATE_MACROS in %.1f s after the macro calls, %d of them after the first %.2f s -- it may be answering in a loop"):format(
			total, LISTEN, late, QUIET_AFTER))
	else
		add(PASS, ("%d UPDATE_MACROS in %.1f s after the macro calls, none after the first %.2f s"):format(
			total, LISTEN, QUIET_AFTER))
	end
end, true)

---------------------------------------------------------------------------
-- fonts, masks, clipping, tiling, animations
---------------------------------------------------------------------------

local function FaceTry(fs, path)
	local ok, accepted = Call(fs, "SetFont", path, 14, "")
	if ok ~= true then return { threw = ok == false and tostring(accepted) or "SetFont is missing" } end
	local face = { accepted = accepted }
	local okG, got, size = Call(fs, "GetFont")
	face.got, face.size = okG == true and got or nil, okG == true and size or nil
	local okT, errT = Call(fs, "SetText", "Hello, Manners")
	if okT == true then
		local okW, width = Call(fs, "GetStringWidth")
		face.width = okW == true and Plain(width) or nil
	else
		face.textErr = okT == MISSING and "no SetText" or tostring(errT)
	end
	return face
end

local function FaceLine(path, face)
	if face.threw then return ("%s: %s"):format(path, face.threw) end
	return ("%s: SetFont answered %s, GetFont %s, text %s wide"):format(path, Show(face.accepted), Show(face.got),
		face.textErr and ("refused (" .. face.textErr .. ")") or Show(face.width))
end

Launch("launch.font", "Morpheus font", function(add)
	local fs = Scratch().fs
	local standard = _G.STANDARD_TEXT_FONT
	local face = FaceTry(fs, MORPHEUS)
	local control = standard and FaceTry(fs, standard)
	local locale = tostring(ns.LOCALE)
	local used = ROMAN[ns.LOCALE or "enUS"] and ("language " .. locale .. ": the looks write in it")
		or ("language " .. locale .. ": the looks keep the client's own face and never ask for it")
	local line = FaceLine("Morpheus", face) .. "; " .. (control and FaceLine("the game's own", control) or "no STANDARD_TEXT_FONT") .. "; " .. used
	if face.threw then
		add(FAIL, line)
	elseif control and (control.threw or control.accepted ~= true) then
		add(FAIL, line .. " -- SetFont refuses even the game's own face")
	elseif face.accepted ~= true or face.textErr or type(face.width) ~= "number" or face.width <= 0 then
		add(CHECK, line .. " -- the client refused the file: the looks fall back to the game's face")
	elseif face.got == nil or Lower(face.got) ~= Lower(MORPHEUS) then
		add(CHECK, line .. " -- the client took it but reads another face back")
	else
		add(PASS, line)
	end
end)

Launch("launch.mask", "icon masks", function(add)
	local s = Scratch()
	local mask, tex = nil, s.tex
	-- One mask for the session: a frame keeps every one it is ever given.
	local okC, made = true, s.mask
	if made == nil then okC, made = Call(s.frame, "CreateMaskTexture") end
	if okC == MISSING then
		add(FAIL, "CreateMaskTexture is missing -- Ribbon, Letter, Leather, Toast and the picker cannot cut an icon round")
		return
	elseif okC ~= true then
		add(FAIL, "CreateMaskTexture threw: " .. tostring(made))
		return
	elseif made == nil then
		add(FAIL, "CreateMaskTexture answered nothing -- no mask can be made")
		return
	end
	mask = made
	s.mask = made
	local file = ART .. "Ribbon\\Ribbon_Mask"
	local okS, errS = Call(mask, "SetTexture", file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	local okP = Call(mask, "SetAllPoints", tex)
	local okA, errA = Call(tex, "AddMaskTexture", mask)
	local okN, count = Call(tex, "GetNumMaskTextures")
	local okR, errR = Call(tex, "RemoveMaskTexture", mask)
	local okN2, count2 = Call(tex, "GetNumMaskTextures")
	local line = ("mask created (%s), SetTexture %s, AddMaskTexture %s, attached count %s, after RemoveMaskTexture %s"):format(
		Show(Call(mask, "GetObjectType") == true and select(2, Call(mask, "GetObjectType")) or "MaskTexture"),
		okS == true and "accepted" or okS == MISSING and "MISSING" or ("threw " .. tostring(errS)),
		okA == true and "accepted" or okA == MISSING and "MISSING" or ("threw " .. tostring(errA)),
		okN == true and Show(count) or "unreadable", okN2 == true and Show(count2) or "unreadable")
	if okA == MISSING or okS == MISSING then
		add(FAIL, line .. " -- the looks call it without asking")
	elseif okS ~= true or okA ~= true or okR == false then
		add(FAIL, line)
	elseif okN ~= true then
		add(CHECK, line .. " -- the client has no call to count masks, so only a look at the prompt's round icon shows it")
	elseif count ~= 1 or (okN2 == true and count2 ~= 0) then
		add(CHECK, line .. " -- not one mask on, then none")
	else
		add(PASS, line)
	end
	-- okP is only told for the line above being a complete use of the calls.
	local _ = okP
end)

Launch("launch.clip", "SetClipsChildren", function(add)
	local clip = Scratch().clip
	if type(clip.SetClipsChildren) ~= "function" then
		add(CHECK, "SetClipsChildren is missing -- the Letter's unroll and the seal's shadow are drawn without being cut to the paper")
		return
	end
	local okSet, errSet = Call(clip, "SetClipsChildren", true)
	local okDoes, does = Call(clip, "DoesClipChildren")
	local okOff = Call(clip, "SetClipsChildren", false)
	local okOff2, doesOff = Call(clip, "DoesClipChildren")
	local line = ("SetClipsChildren(true) %s, DoesClipChildren answered %s; after (false) %s"):format(
		okSet == true and "accepted" or ("threw " .. tostring(errSet)), okDoes == true and Show(does) or "unreadable",
		okOff2 == true and Show(doesOff) or "unreadable")
	if okSet ~= true then
		add(FAIL, line)
	elseif okDoes ~= true then
		add(CHECK, line .. " -- the client cannot say whether it clips, so only the Letter's unroll shows it")
	elseif does ~= true or (okOff2 == true and doesOff ~= false) then
		add(CHECK, line .. " -- it does not read back as set")
	else
		add(PASS, line)
	end
	local _ = okOff
end)

Launch("launch.tile", "REPEAT tiling", function(add)
	local tex = Scratch().tex
	local file = ART .. "Leather\\Leather_BodyM"
	local okT, errT = Call(tex, "SetTexture", file, "REPEAT", "REPEAT")
	local okC, errC = Call(tex, "SetTexCoord", 0, 6, 0, 1)
	local okG, ulx, uly, llx, lly, urx = Call(tex, "GetTexCoord")
	local okF, got = Call(tex, "GetTexture")
	local okH, horiz = Call(tex, "GetHorizTile")
	local okV, vert = Call(tex, "GetVertTile")
	-- Put back for the next test of the same texture.
	Call(tex, "SetTexture", nil)
	Call(tex, "SetTexCoord", 0, 1, 0, 1)
	local line = ("SetTexture(Leather_BodyM, \"REPEAT\", \"REPEAT\") %s, SetTexCoord(0, 6, 0, 1) %s, GetTexCoord reads %s, GetTexture %s, GetHorizTile %s, GetVertTile %s"):format(
		okT == true and "accepted" or ("threw " .. tostring(errT)),
		okC == true and "accepted" or ("threw " .. tostring(errC)),
		okG == true and ("%s..%s"):format(Show(ulx), Show(urx)) or "unreadable",
		okF == true and Show(got) or "unreadable",
		okH == true and Show(horiz) or "n/a", okV == true and Show(vert) or "n/a")
	if okT ~= true or okC ~= true then
		add(FAIL, line)
	elseif okG ~= true then
		add(CHECK, line .. " -- the client cannot read the span back; only a look at the Leather's strips shows the tiling")
	elseif type(Plain(urx)) ~= "number" or math.abs(urx - 6) > 0.01 then
		add(CHECK, line .. " -- the span past 1 was not kept, so the strips would not repeat")
	else
		add(PASS, line .. " (how the leather looks tiled is for eyes)")
	end
	local _ = { uly, llx, lly }
end)

-- The animation kinds and settings the looks use, tried on a group of our own.
Launch("launch.anim", "animations", function(add)
	local s = Scratch()
	local frame = s.animFrame
	-- One group, and one animation of each kind, for the session.
	local okG, group = true, s.animGroup
	if group == nil then okG, group = Call(frame, "CreateAnimationGroup") end
	s.anims = s.anims or {}
	if okG == MISSING then
		add(FAIL, "CreateAnimationGroup is missing -- no look can animate")
		return
	elseif okG ~= true or group == nil then
		add(FAIL, "CreateAnimationGroup " .. (okG == true and "answered nothing" or ("threw " .. tostring(group))))
		return
	end
	local made, missing, threw = {}, {}, {}
	local function try(obj, method, ...)
		local ok, err = Call(obj, method, ...)
		if ok == MISSING then missing[#missing + 1] = method
		elseif ok ~= true then threw[#threw + 1] = method .. ": " .. tostring(err) end
		return ok == true
	end
	-- `key` names the animation in the scratch's keep when one kind is tried
	-- twice (the second Scale below); it reads as the kind otherwise.
	local function make(kind, setup, key)
		key = key or kind
		local ok, anim = true, s.anims[key]
		if anim == nil then ok, anim = Call(group, "CreateAnimation", kind) end
		if ok == true and anim ~= nil then s.anims[key] = anim end
		if ok ~= true or anim == nil then
			threw[#threw + 1] = "CreateAnimation(" .. kind .. ") " .. (ok == true and "answered nothing" or tostring(anim))
			return
		end
		made[#made + 1] = key
		try(anim, "SetDuration", 0.1)
		try(anim, "SetOrder", 1)
		try(anim, "SetSmoothing", "OUT")
		setup(anim)
	end
	make("Alpha", function(a) try(a, "SetFromAlpha", 0) try(a, "SetToAlpha", 1) end)
	make("Scale", function(a) try(a, "SetScaleFrom", 1, 1) try(a, "SetScaleTo", 1.1, 1.1) try(a, "SetOrigin", "CENTER", 0, 0) end)
	-- The entrance's rules grow along one axis only, about their left end
	-- (Prompt/Effects.lua): the pair of unequal scales and the LEFT origin,
	-- which the mock accepts and launch day has to confirm.
	make("Scale", function(a) try(a, "SetScaleFrom", 0.04, 1) try(a, "SetScaleTo", 1, 1) try(a, "SetOrigin", "LEFT", 0, 0) end,
		"Scale(x, y) about LEFT")
	make("Translation", function(a) try(a, "SetOffset", 2, 0) end)
	make("Rotation", function(a) try(a, "SetDegrees", 5) end)
	try(group, "SetLooping", "BOUNCE")
	try(group, "SetLooping", "REPEAT")
	try(group, "SetLooping", "NONE")
	local okP = Call(group, "Play")
	local okI, playing = Call(group, "IsPlaying")
	Call(group, "Stop")
	local okI2, after = Call(group, "IsPlaying")
	local line = ("made %s; Play %s, IsPlaying %s, after Stop %s"):format(table.concat(made, ", "),
		okP == true and "accepted" or "refused", okI == true and Show(playing) or "unreadable",
		okI2 == true and Show(after) or "unreadable")
	if #threw > 0 then
		add(FAIL, line .. " -- " .. table.concat(threw, "; "))
	elseif #missing > 0 or #made < 5 then
		add(CHECK, line .. " -- missing: " .. table.concat(missing, ", "))
	elseif okI == true and playing ~= true then
		add(CHECK, line .. " -- the group did not report playing")
	else
		add(PASS, line)
	end
	-- One group on the scratch frame for ever, not one more each run.
	s.animGroup = group
end)

---------------------------------------------------------------------------
-- every look, on the real prompt
---------------------------------------------------------------------------

-- The prompt's tree as the client lists it: how many frames and regions are
-- built (every look that was ever shown keeps its own), and, of those, what is
-- switched on from the prompt down -- shown, and under frames that are shown,
-- the prompt's own state aside, which is hidden whenever nobody is on it. What
-- the looks lean on is counted among the live ones, so that a look's line
-- speaks of that look and not of the ones built before it.
local function Tree(root)
	local c = { frames = 0, textures = 0, strings = 0, masks = 0, live = 0, liveFrames = 0, clips = 0,
		tiled = 0, groups = 0 }
	local seen, nodes = {}, 0
	local function shown(obj)
		local ok, on = Call(obj, "IsShown")
		return ok ~= true or on == true
	end
	local function region(r, live)
		local okK, kind = Call(r, "GetObjectType")
		kind = okK == true and kind or "Texture"
		if kind == "FontString" then c.strings = c.strings + 1
		elseif kind == "MaskTexture" then c.masks = c.masks + 1
		else c.textures = c.textures + 1 end
		if not (live and shown(r)) then return end
		c.live = c.live + 1
		local okH, h = Call(r, "GetHorizTile")
		local okV, v = Call(r, "GetVertTile")
		if (okH == true and h == true) or (okV == true and v == true) then c.tiled = c.tiled + 1 end
	end
	local function walk(f, level, live)
		if seen[f] or level > 12 or nodes > 4000 then return end
		seen[f] = true
		nodes = nodes + 1
		c.frames = c.frames + 1
		if live then
			c.liveFrames = c.liveFrames + 1
			local okC, clips = Call(f, "DoesClipChildren")
			if okC == true and clips == true then c.clips = c.clips + 1 end
			local okA, groups = pcall(function() return select("#", f:GetAnimationGroups()) end)
			if okA then c.groups = c.groups + groups end
		end
		if type(f.GetRegions) == "function" then
			local ok, regions = pcall(function() return { f:GetRegions() } end)
			if ok then for _, r in ipairs(regions) do region(r, live) end end
		end
		if type(f.GetChildren) == "function" then
			local ok, children = pcall(function() return { f:GetChildren() } end)
			if ok then
				for _, child in ipairs(children) do walk(child, level + 1, live and shown(child)) end
			end
		end
	end
	c.listed = type(root.GetRegions) == "function" and type(root.GetChildren) == "function"
	walk(root, 0, true)
	c.regions = c.textures + c.strings + c.masks
	return c
end

-- What each look must show when the client does what the code relies on.
local EXPECT = {
	ribbon = { face = true, mask = true },
	letter = { face = true, mask = true, clip = true },
	leather = { face = true, mask = true },
}

local function WantsMorpheus(p)
	local d = ns.defaults and ns.defaults.profile.prompt.font
	if type(p.font) == "string" and p.font ~= d then return false end
	return ROMAN[ns.LOCALE or "enUS"] == true
end

local function Measure(Prompt, R, key, look)
	local row = { key = key }
	local S = Prompt.state
	row.active = S and S.activeLook
	row.matches = row.active == look
	row.tree = Tree(R.button)
	local okF, path, size = Call(R.nameText, "GetFont")
	row.font, row.size = okF == true and path or nil, okF == true and size or nil
	row.fontKnown = okF == true
	local okN, masks = Call(R.icon, "GetNumMaskTextures")
	row.masks = okN == true and masks or nil
	-- How many of them are switched on: a mask that is hidden is the look's way
	-- of taking its shape off the icon, and the game's word on that is the
	-- thing to read.
	if okN == true and type(masks) == "number" then
		row.masksShown = 0
		for i = 1, masks do
			local okM, mask = Call(R.icon, "GetMaskTexture", i)
			local okS, on = Call(okM == true and mask or nil, "IsShown")
			if okM ~= true or okS ~= true then
				row.masksShown = nil
				break
			end
			if on then row.masksShown = row.masksShown + 1 end
		end
	end
	local okS, shown = Call(R.icon, "IsShown")
	row.iconShown = okS == true and shown == true
	row.ownMask = look ~= nil and look.mask ~= nil
	return row
end

-- Every look put on the prompt in turn, in one call, and the style put back.
-- Run once, by the first check that wants it.
local function Sweep(ctx)
	if ctx.sweep then return ctx.sweep end
	local sweep = { per = {}, order = {} }
	ctx.sweep = sweep
	local Prompt = ns.Prompt
	local R = Prompt and Prompt.regions
	local p = ns.db and ns.db.profile and ns.db.profile.prompt
	if not (R and R.button and p and ns.Looks and type(Prompt.ApplyStyle) == "function") then
		sweep.why = "the prompt is not built"
		return sweep
	end
	if InCombatLockdown() then
		sweep.why = "in combat"
		return sweep
	end
	local _, keys = ns.Looks.Choices()
	local saved = rawget(p, "style")
	local t0 = Clock()
	local before = Tree(R.button)
	local seen = before.frames + before.regions
	sweep.before = before
	sweep.style = saved == nil and p.style or saved
	for _, key in ipairs(keys) do
		local row
		local started = Clock()
		p.style = key
		local ok, err = pcall(Prompt.ApplyStyle, Prompt)
		local ms = started and Clock() and (Clock() - started) or nil
		if not ok then
			row = { key = key, err = tostring(err) }
		else
			local okM, measured = pcall(Measure, Prompt, R, key, ns.Looks.Get(key))
			row = okM and measured or { key = key, err = "measuring it threw: " .. tostring(measured) }
			if row.tree then
				row.built = row.tree.frames + row.tree.regions - seen
				seen = row.tree.frames + row.tree.regions
			end
		end
		row.ms = ms
		sweep.per[key] = row
		sweep.order[#sweep.order + 1] = key
	end
	-- Put back, and the prompt laid out for it again.
	p.style = saved
	local okBack, errBack = pcall(Prompt.ApplyStyle, Prompt)
	sweep.restoreErr = not okBack and tostring(errBack) or nil
	sweep.after = Tree(R.button)
	sweep.ms = t0 and Clock() and (Clock() - t0) or nil
	sweep.wore = rawget(p, "style") == saved
	return sweep
end

Launch("launch.looks", "looks", function(add, ctx)
	local sweep = Sweep(ctx)
	if sweep.why then
		add(CHECK, "not tried: " .. sweep.why)
		return
	end
	local p = ns.db.profile.prompt
	local status, notes = PASS, {}
	local function worse(s, note)
		if RANK[s] > RANK[status] then status = s end
		notes[#notes + 1] = note
	end
	if sweep.restoreErr then worse(FAIL, "putting the style back threw: " .. sweep.restoreErr) end
	if not sweep.wore then worse(FAIL, "the style was not put back") end
	if not sweep.before.listed then
		worse(CHECK, "the client cannot list a frame's regions and children here, so region counts are not read")
	elseif sweep.after.live ~= sweep.before.live or sweep.after.liveFrames ~= sweep.before.liveFrames then
		worse(CHECK, ("the prompt has %d regions in %d frames switched on now, it had %d in %d before"):format(
			sweep.after.live, sweep.after.liveFrames, sweep.before.live, sweep.before.liveFrames))
	end
	add(status, ("switched through %d looks in one call%s and put the style back to %s: %d regions switched on, as before%s"):format(
		#sweep.order, sweep.ms and (" (" .. math.floor(sweep.ms + 0.5) .. " ms)") or "", Show(sweep.style),
		sweep.after.live, #notes > 0 and (" -- " .. table.concat(notes, "; ")) or ""))

	local face = WantsMorpheus(p)
	local clipApi = type(Scratch().clip.SetClipsChildren) == "function"
	for _, key in ipairs(sweep.order) do
		local row = sweep.per[key]
		local id, label = "launch.look." .. key, "look " .. key
		if row.err then
			add(FAIL, "applying it threw: " .. row.err, label, id)
		else
			local tree = row.tree
			local problems, st = {}, PASS
			local function bad(note)
				st = CHECK
				problems[#problems + 1] = note
			end
			if not row.matches then
				st = FAIL
				problems[#problems + 1] = "the prompt did not end up wearing it"
			end
			local expect = EXPECT[key] or {}
			if expect.face and face then
				if not row.fontKnown then bad("the name's font cannot be read back")
				elseif Lower(row.font) ~= Lower(MORPHEUS) then bad("the name is not in Morpheus (" .. Show(row.font) .. ")") end
			end
			if expect.mask and row.iconShown then
				if row.masks == nil then bad("the icon's masks cannot be counted")
				elseif row.masks < 1 or (row.masksShown or row.masks) < 1 then bad("the icon has no mask on it") end
			end
			if expect.clip and clipApi and tree.listed and tree.clips < 1 then bad("no frame clips its children") end
			add(st, ("%s%s, name font %s, icon masks %s, clipping frames %s, tiled textures %s, animation groups %s%s"):format(
				row.ms and (math.floor(row.ms + 0.5) .. " ms; ") or "",
				tree.listed and ("%d regions in %d frames switched on%s"):format(tree.live, tree.liveFrames,
					row.built and row.built > 0 and (" (" .. row.built .. " built now)") or "") or "regions not listable",
				row.fontKnown and (Show(row.font) .. " " .. Show(row.size)) or "n/a",
				row.masks == nil and "n/a" or (row.masksShown and row.masksShown ~= row.masks
					and ("%d (%d shown)"):format(row.masks, row.masksShown) or tostring(row.masks)),
				tree.listed and tostring(tree.clips) or "n/a",
				tree.listed and tostring(tree.tiled) or "n/a", tree.listed and tostring(tree.groups) or "n/a",
				#problems > 0 and (" -- " .. table.concat(problems, "; ")) or ""), label, id)
		end
	end
end)

---------------------------------------------------------------------------
-- the look picker's cards
---------------------------------------------------------------------------

local function BuffIcon()
	for _, buff in ipairs(ns.CastableBuffs and ns.CastableBuffs() or {}) do
		local info = ns.BuffInfo(buff)
		local icon = info and info.icon
		if type(icon) == "number" or type(icon) == "string" then return icon, true end
	end
	return QUESTION_MARK, false
end

Launch("launch.picker", "look picker cards", function(add, ctx)
	local s = Scratch()
	local icon, own = BuffIcon()
	-- A card in little: the spell icon on the picture, cut round by the look's
	-- mask, with the sample name in the look's face.
	local tex, line = s.cardIcon, s.cardLine
	local okT, errT = Call(tex, "SetTexture", icon)
	local okC, errC = Call(tex, "SetTexCoord", 0.08, 0.92, 0.08, 0.92)
	local okFile, file = Call(tex, "GetTexture")
	local okM, mask = true, s.cardMask
	if mask == nil then okM, mask = Call(s.frame, "CreateMaskTexture") end
	local masked = false
	if okM == true and mask ~= nil then
		s.cardMask = mask
		Call(mask, "SetTexture", ART .. "Letter\\Letter_Mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		Call(mask, "SetAllPoints", tex)
		masked = Call(tex, "AddMaskTexture", mask) == true
		local okN, n = Call(tex, "GetNumMaskTextures")
		masked = masked and (okN ~= true or n == 1)
		Call(tex, "RemoveMaskTexture", mask)
	end
	local face = FaceTry(line, MORPHEUS)
	Call(line, "SetShadowOffset", 1, -1)
	Call(line, "SetText", L["buffed you"])
	local okW, width = Call(line, "GetStringWidth")
	local text = ("icon %s (%s) set %s, crop %s, GetTexture %s, round mask %s; sample line in Morpheus: SetFont %s, %s wide"):format(
		Show(icon), own and "your own buff's" or "the question mark", okT == true and "ok" or ("threw " .. tostring(errT)),
		okC == true and "ok" or ("threw " .. tostring(errC)), okFile == true and Show(file) or "unreadable",
		masked and "attached" or "NOT attached", Show(face.accepted), okW == true and Show(Plain(width)) or "unreadable")

	-- The cards of the window as it stands, when the Look page has been drawn.
	local UI = ns.WindowUI
	local okRow, row = pcall(function() return UI and UI.RowFor and UI.RowFor("appearance.style") end)
	local cards, withIcon, round, withText = 0, 0, 0, 0
	local drift = {}
	if okRow and type(row) == "table" and type(row.cards) == "table" then
		for _, card in ipairs(row.cards) do
			if card.IsShown and card:IsShown() then
				cards = cards + 1
				if card.iconFile ~= nil then
					withIcon = withIcon + 1
					if card.icon and card.icon.IsShown and not card.icon:IsShown() then drift[#drift + 1] = tostring(card.key) .. " has its icon hidden" end
				end
				if card.masked then round = round + 1 end
				local name = card.lines and card.lines.name
				if name and card.lineFace and card.lineFace.name then
					withText = withText + 1
					local okF, path = Call(name, "GetFont")
					if okF ~= true or path == nil then drift[#drift + 1] = tostring(card.key) .. " has no font on its name" end
				end
			end
		end
		text = text .. ("; the window's own cards: %d shown, %d with the live icon, %d round, %d with text"):format(
			cards, withIcon, round, withText)
	else
		text = text .. "; the window's cards are not drawn yet (open /manners, Look, to build them)"
	end

	if okT ~= true or okC ~= true then
		add(FAIL, text)
	elseif okM ~= true or mask == nil then
		add(FAIL, text .. " -- no mask can be made, so a round card icon cannot be cut")
	elseif not masked or face.accepted ~= true or face.textErr or okW ~= true or type(Plain(width)) ~= "number" then
		add(CHECK, text .. " -- " .. (not masked and "the mask did not attach" or "the sample line could not be set in Morpheus"))
	elseif #drift > 0 then
		add(CHECK, text .. " -- " .. table.concat(drift, "; "))
	elseif not own then
		add(CHECK, text .. " -- no buff of yours to show, so the cards carry the question mark")
	else
		add(PASS, text)
	end
	local _ = ctx
end)

---------------------------------------------------------------------------
-- controller glyphs
---------------------------------------------------------------------------

Launch("launch.keys", "controller key glyphs", function(add)
	local gbt = _G.GetBindingText
	if type(gbt) ~= "function" then
		add(CHECK, "GetBindingText is missing -- the chip spells a key in Manners' own words, a controller button as its name")
		return
	end
	local status, notes, parts = PASS, {}, {}
	local function worse(note)
		if status ~= FAIL then status = CHECK end
		notes[#notes + 1] = note
	end
	local keys = { "PAD1", "SHIFT-PAD1" }
	for _, key in ipairs(keys) do
		local okL, long = pcall(gbt, key)
		local okS, short = pcall(gbt, key, true)
		parts[#parts + 1] = ("GetBindingText(%s) %s, short %s"):format(key, okL and Show(long) or "threw", okS and Show(short) or "threw")
		if not okL or not okS then
			status = FAIL
			notes[#notes + 1] = "GetBindingText(" .. key .. ") threw"
		elseif type(Plain(short)) ~= "string" or short == "" then
			worse("no short text for " .. key)
		end
	end
	local chip = {}
	for _, key in ipairs(keys) do
		local ok, text = pcall(ns.Looks.ShortKey, key)
		chip[#chip + 1] = key .. " -> " .. (ok and Show(text) or "threw")
		if not ok then status = FAIL notes[#notes + 1] = "the chip's reading of " .. key .. " threw"
		elseif text == nil then worse("the chip has nothing for " .. key) end
	end
	parts[#parts + 1] = "the chip shows " .. table.concat(chip, ", ")
	local get = _G.GetCVar or Field(_G.C_CVar, "GetCVar")
	local cvars = {}
	for _, name in ipairs({ "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt", "GamePadEnable" }) do
		local ok, value = Ask(get, name)
		cvars[#cvars + 1] = name .. "=" .. (ok == true and Show(value) or "unreadable")
		if name ~= "GamePadEnable" and (ok ~= true or Plain(value) == nil) then
			worse(name .. " cannot be read, so a held trigger is spelt as Shift")
		end
	end
	parts[#parts + 1] = table.concat(cvars, " ")
	local pad = _G.C_GamePad
	local okE, enabled = Ask(Field(pad, "IsEnabled"))
	local okD, devices = Ask(Field(pad, "GetAllDeviceIDs"))
	parts[#parts + 1] = ("C_GamePad enabled %s, %s device(s)"):format(okE == true and Show(enabled) or "n/a",
		okD == true and type(devices) == "table" and tostring(#devices) or "n/a")
	local okK, key = Ask(_G.GetBindingKey, COMMAND)
	parts[#parts + 1] = "your key for the prompt: " .. (okK == true and Show(key) or "none")
	if okK == true and type(Plain(key)) == "string" then
		local ok, text = pcall(ns.Looks.ShortKey, key)
		parts[#parts + 1] = "on the chip " .. (ok and Show(text) or "threw")
	end
	add(status, table.concat(parts, "; ") .. (#notes > 0 and (" -- " .. table.concat(notes, "; ")) or ""))
end)

---------------------------------------------------------------------------
-- the tooltip
---------------------------------------------------------------------------

local function Tip()
	local s = Scratch()
	if s.tip then return s.tip end
	local tip = CreateFrame("GameTooltip", "MannersSelftestTooltip", UIParent, "GameTooltipTemplate")
	s.tip = tip
	return tip
end

Launch("launch.tooltip", "prompt tooltip", function(add)
	local Prompt = ns.Prompt
	local R = Prompt and Prompt.regions
	local button = R and R.button
	if not button then
		add(CHECK, "the prompt is not built")
		return
	end
	local p = ns.db.profile.prompt
	local tip = Tip()
	local status, notes, parts = PASS, {}, {}
	local function worse(s, note)
		if RANK[s] > RANK[status] then status = s end
		notes[#notes + 1] = note
	end
	-- What the placement reads: where the button is, and the screen's size.
	local okT, top = Call(button, "GetTop")
	local okB, bottom = Call(button, "GetBottom")
	local okH, screen = Call(UIParent, "GetHeight")
	local okE, own = Call(button, "GetEffectiveScale")
	parts[#parts + 1] = ("button top %s bottom %s, screen %s high, scale %s"):format(okT == true and Show(top) or "n/a",
		okB == true and Show(bottom) or "n/a", okH == true and Show(screen) or "n/a", okE == true and Show(own) or "n/a")
	if type(Plain(top)) ~= "number" or type(Plain(bottom)) ~= "number" or type(Plain(screen)) ~= "number" then
		worse(CHECK, "the prompt cannot be measured, so the tooltip falls back to the game's own anchor above it")
	end
	-- Above and below the button, as the placement asks.
	for _, spot in ipairs({ { "above", "BOTTOM", "TOP", 6 }, { "below", "TOP", "BOTTOM", -6 } }) do
		local name, point, rel, y = spot[1], spot[2], spot[3], spot[4]
		local okO = Call(tip, "SetOwner", button, "ANCHOR_NONE")
		local okC = Call(tip, "ClearAllPoints")
		local okP, errP = Call(tip, "SetPoint", point, button, rel, 0, y)
		local okG, got, relTo, relPoint = Call(tip, "GetPoint", 1)
		parts[#parts + 1] = ("%s: SetPoint %s, reads back %s to %s"):format(name,
			okP == true and "accepted" or okP == MISSING and "MISSING" or ("threw " .. tostring(errP)),
			okG == true and (Show(got) .. "/" .. Show(relPoint)) or "unreadable",
			okG == true and (relTo == button and "the prompt" or Show(relTo)) or "?")
		if okO ~= true or okC ~= true or okP ~= true then
			worse(FAIL, ("the tooltip cannot be anchored %s the prompt"):format(name))
		elseif okG == true and (got ~= point or relTo ~= button or relPoint ~= rel) then
			worse(CHECK, ("anchored %s the prompt, the client reads another anchor back"):format(name))
		end
	end
	-- The game's own place.
	local default = _G.GameTooltip_SetDefaultAnchor
	if type(default) == "function" then
		local ok, err = pcall(default, tip, button)
		local okG, got = Call(tip, "GetPoint", 1)
		parts[#parts + 1] = "game's own place: " .. (ok and ("anchored " .. (okG == true and Show(got) or "(unreadable)")) or ("threw " .. tostring(err)))
		if not ok then worse(FAIL, "GameTooltip_SetDefaultAnchor threw") end
	else
		parts[#parts + 1] = "GameTooltip_SetDefaultAnchor missing"
		worse(CHECK, "no default anchor to ask, so 'where the game shows tooltips' falls back to above the prompt")
	end
	Call(tip, "Hide")
	Call(tip, "ClearLines")
	-- Shift.
	local okS, held = Ask(_G.IsShiftKeyDown)
	parts[#parts + 1] = "IsShiftKeyDown " .. (okS == true and Show(held) or okS == MISSING and "missing" or "threw")
	if okS ~= true or type(Plain(held)) ~= "boolean" then
		worse(CHECK, "Shift cannot be read, so 'Only while holding Shift' never opens the full tooltip but the short one's hint")
	end
	parts[#parts + 1] = ("set to %s at %s"):format(Show(p.tooltip), Show(p.tooltipPosition))
	add(status, table.concat(parts, "; ") .. (#notes > 0 and (" -- " .. table.concat(notes, "; ")) or ""))
end)

---------------------------------------------------------------------------
-- /cleartarget
---------------------------------------------------------------------------

-- The slash commands the macro uses, found the way the chat box finds them: as
-- SLASH_<NAME><n> globals.
local function SlashNamed(command)
	local found
	for k, v in pairs(_G) do
		if type(k) == "string" and k:sub(1, 6) == "SLASH_" and type(v) == "string" and v:lower() == command then
			found = k
			break
		end
	end
	return found
end

Launch("launch.handback", "/cleartarget hand-back", function(add)
	local status, notes, parts = PASS, {}, {}
	local function worse(note)
		if status ~= FAIL then status = CHECK end
		notes[#notes + 1] = note
	end
	for _, command in ipairs({ "/cleartarget", "/targetlasttarget" }) do
		local okS, name = pcall(SlashNamed, command)
		local known = okS and name
		local handler = known and type(_G.SlashCmdList) == "table"
			and _G.SlashCmdList[(name:gsub("^SLASH_", ""):gsub("%d+$", ""))]
		parts[#parts + 1] = command .. (known and (" is " .. name .. (type(handler) == "function" and "" or ", with no handler")) or " is not a registered slash command")
		if not known then worse(command .. " is not a slash command here, so the macro's line would do nothing")
		elseif type(handler) ~= "function" then worse(command .. " has no handler") end
	end
	local okX, exists = Ask(_G.UnitExists, "target")
	local okG, guid = Ask(_G.UnitGUID, "target")
	local secret = okG == true and Selftest.tools.Secret(guid)
	local shown = okG ~= true and "unreadable" or secret and "SECRET" or guid == nil and "nil" or "a string"
	parts[#parts + 1] = ("target: UnitExists %s, UnitGUID answers %s"):format(okX == true and Show(exists) or "n/a", shown)
	local nothing = okX == true and Plain(exists) == false
	if okG ~= true then
		worse("UnitGUID cannot be read, so Manners cannot tell nothing is targeted and always hands back")
	elseif okX == true and Plain(exists) == false and Plain(guid) ~= nil then
		worse("nothing is targeted and UnitGUID still answers something")
	elseif okX == true and Plain(exists) == true and Plain(guid) == nil and not secret then
		worse("something is targeted and UnitGUID answers nothing -- the prompt would think nothing is")
	end
	-- What the macro on the prompt ends with now, against what the target says.
	local last = type(ns.lastMacro) == "string" and ns.lastMacro:match("([^\r\n]+)%s*$") or nil
	local armedForFight = ns.Prompt and ns.Prompt.armedForFight == true
	parts[#parts + 1] = "the macro on the prompt ends " .. (last and Show(last) or "nowhere (nothing armed)")
	if last and nothing and not armedForFight and (last == "/targetlasttarget") then
		worse("nothing is targeted, yet the armed macro would bring an old target back")
	end
	parts[#parts + 1] = nothing and "nothing targeted: a press hands back with /cleartarget" or "something is targeted: a press hands it back with /targetlasttarget; clear your target and run this again to see the other"
	add(status, table.concat(parts, "; ") .. (#notes > 0 and (" -- " .. table.concat(notes, "; ")) or ""))
end)

---------------------------------------------------------------------------
-- the display changing
---------------------------------------------------------------------------

local function Place(button)
	local o = {}
	local okP, point, rel, relPoint, x, y = Call(button, "GetPoint")
	if okP == true then
		o.point, o.rel, o.relPoint = point, rel, relPoint
		o.x, o.y = type(x) == "number" and math.floor(x * 100 + 0.5) / 100 or x, type(y) == "number" and math.floor(y * 100 + 0.5) / 100 or y
	end
	local okS, w, h = Call(button, "GetSize")
	if okS == true then o.w, o.h = w, h end
	for _, name in ipairs({ "GetScale", "GetAlpha", "IsShown" }) do
		local ok, v = Call(button, name)
		o[name] = ok == true and v or nil
	end
	return o
end

local function Same(a, b)
	for k, v in pairs(a) do
		if b[k] ~= v then return false, k end
	end
	for k in pairs(b) do
		if a[k] == nil then return false, k end
	end
	return true
end

Launch("launch.display", "display change", function(add)
	local Prompt = ns.Prompt
	local R = Prompt and Prompt.regions
	local button = R and R.button
	local status, notes, parts = PASS, {}, {}
	local function worse(s, note)
		if RANK[s] > RANK[status] then status = s end
		notes[#notes + 1] = note
	end
	local okW, w = Call(UIParent, "GetWidth")
	local okH, h = Call(UIParent, "GetHeight")
	local okE, scale = Call(UIParent, "GetEffectiveScale")
	local okPh, pw, ph = Ask(_G.GetPhysicalScreenSize)
	parts[#parts + 1] = ("UIParent %s x %s at scale %s, physical %s"):format(okW == true and Show(w) or "n/a",
		okH == true and Show(h) or "n/a", okE == true and Show(scale) or "n/a",
		okPh == true and (Show(pw) .. " x " .. Show(ph)) or "n/a")
	for _, name in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
		local handler = addon[name]
		parts[#parts + 1] = name .. " handler " .. (type(handler) == "function" and "present" or "MISSING")
		if type(handler) ~= "function" then worse(CHECK, name .. " has no handler") end
	end
	if not button or type(addon.UI_SCALE_CHANGED) ~= "function" then
		add(status == PASS and CHECK or status, table.concat(parts, "; ") .. " -- the prompt's re-layout was not tried")
		return
	end
	if InCombatLockdown() then
		add(CHECK, table.concat(parts, "; ") .. " -- in combat, the re-layout was not tried")
		return
	end
	-- The handler's own work, as the client would run it for a new scale: the
	-- prompt laid out again, which must leave it where and as it was.
	local before = Place(button)
	local lookBefore = Prompt.state and Prompt.state.activeLook
	local errors = ns.errorCount or #(ns.errors or {})
	local ok, err = pcall(addon.UI_SCALE_CHANGED, addon)
	local after = Place(button)
	local same, differing = Same(before, after)
	parts[#parts + 1] = ("laying out again %s; the prompt %s"):format(ok and "ran" or ("threw " .. tostring(err)),
		same and "is where and as it was" or ("changed its " .. tostring(differing)))
	if not ok or (ns.errorCount or #(ns.errors or {})) ~= errors then
		worse(FAIL, "the restyle for the display raised an error (see Errors)")
	end
	if not same then worse(CHECK, "a new scale would move or resize the prompt: " .. tostring(differing)) end
	if (Prompt.state and Prompt.state.activeLook) ~= lookBefore then worse(FAIL, "the look changed") end
	add(status, table.concat(parts, "; ") .. (#notes > 0 and (" -- " .. table.concat(notes, "; ")) or ""))
end)

---------------------------------------------------------------------------
-- running them
---------------------------------------------------------------------------

-- Every launch check, each under its own pcall: a list of { id, group, status,
-- label, value } and a function that runs what waits for the listening and
-- returns the same list. A check that throws is a FAIL with the error, one
-- that says nothing a CHECK. `opts.createMacro` lets the macro checks make a
-- temporary macro when the player has none.
function Selftest.RunLaunch(opts)
	local results = {}
	if InCombatLockdown() then
		results[1] = { id = "launch.combat", group = "launch", status = FAIL, label = "combat",
			value = "in a fight -- no launch check runs; try again when it ends" }
		return results, function() return results end
	end
	local ctx = { opts = opts or {}, cleanup = {} }
	local current
	local function add(status, value, label, id)
		results[#results + 1] = { id = id or current.id, group = "launch", status = status,
			label = label or current.label, value = tostring(value) }
	end
	local function run(check)
		current = check
		local before = #results
		local ok, err = pcall(check.run, add, ctx)
		if not ok then
			add(FAIL, "threw: " .. tostring(err))
		elseif #results == before then
			add(CHECK, "said nothing")
		end
	end
	local started = Clock()
	-- Anything a past run left listening is let go; the log starts empty.
	local okS, s = pcall(Scratch)
	if okS then s.log = {} end
	local late = {}
	for _, check in ipairs(LAUNCH) do
		if check.late then late[#late + 1] = check else run(check) end
	end
	for _, fn in ipairs(ctx.cleanup) do pcall(fn) end
	ctx.listenFrom = GetTime()
	results.ms = started and Clock() and (Clock() - started) or nil
	local finished = false
	local function finish()
		if finished then return results end
		finished = true
		if okS then Call(s.events, "UnregisterEvent", "UPDATE_MACROS") end
		for _, check in ipairs(late) do run(check) end
		return results
	end
	return results, finish
end

-- The lines the report carries for a run: its summary first, then one line per
-- result, and the counts of checks (a check's status is its worst line's).
function Selftest.LaunchLines(results)
	local worst, order = {}, {}
	for _, r in ipairs(results) do
		if not worst[r.id] then order[#order + 1] = r.id end
		if not worst[r.id] or RANK[r.status] > RANK[worst[r.id]] then worst[r.id] = r.status end
	end
	local counts = { [PASS] = 0, [CHECK] = 0, [FAIL] = 0 }
	local labels = {}
	for _, id in ipairs(order) do
		counts[worst[id]] = counts[worst[id]] + 1
	end
	local seen = {}
	for _, r in ipairs(results) do
		if worst[r.id] ~= PASS and not seen[r.id] then
			seen[r.id] = true
			labels[#labels + 1] = r.label
		end
	end
	local summary = ("Launch checks: %d PASS, %d CHECK, %d FAIL%s"):format(counts[PASS], counts[CHECK], counts[FAIL],
		results.ms and (" in " .. math.floor(results.ms + 0.5) .. " ms") or "")
	if #labels > 0 then summary = summary .. " -- look at: " .. table.concat(labels, ", ") end
	local lines = { summary,
		"PASS = the client answered as Manners expects; CHECK = another answer, a fallback, or only eyes can tell; FAIL = an error or a refusal with no way round", "" }
	lines[#lines + 1] = "[" .. L["Launch checks"] .. "]"
	for _, r in ipairs(results) do
		lines[#lines + 1] = ("%s  %s: %s"):format(r.status, r.label, r.value)
	end
	lines[#lines + 1] = ""
	return lines, counts[PASS], counts[CHECK], counts[FAIL]
end

-- /manners selftest launch: the usual checks and the launch checks, the report
-- in its box once the half second of listening is over.
function Selftest.StartLaunch()
	if Selftest.launchPending then
		addon:Print(L["the launch checks are still running -- give them a moment."])
		return
	end
	local standard = Selftest.Run()
	local results, finish = Selftest.RunLaunch({ createMacro = true })
	local function deliver()
		Selftest.launchPending = nil
		finish()
		local _, pass, check, fail = Selftest.LaunchLines(results)
		local text, p, w, f = Selftest.Report(standard, results)
		Selftest.Deliver(text, p, w, f, { pass, check, fail })
	end
	if _G.C_Timer and _G.C_Timer.After then
		Selftest.launchPending = true
		_G.C_Timer.After(LISTEN, function()
			if not ns.Guard("selftest launch", deliver) then Selftest.launchPending = nil end
		end)
	else
		deliver()
	end
end
