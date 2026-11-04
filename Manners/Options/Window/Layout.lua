-- Manners -- options window: where every control sits.
--
-- The window reads its controls from ns.optionsTable (Options/<Tab>.lua, the
-- model) and places them from this table. A control is "tab.key": the tab is
-- where its definition lives, not the page it is drawn on, so a control moves
-- between pages here without its definition moving. Visibility, labels and
-- values stay the model's.
--
-- Read at load, before SetupOptions has built the model, so nothing here may
-- touch ns.optionsTable or ns.db; the icons that need the character are
-- functions the window calls when it draws the sidebar.
--
-- A section is { header = "tab.key" (the model header's name is its title) or
-- title = L[...], fold = true below the hairline, key = "<page>.<name>" (stable:
-- an open fold is remembered by it), items = { ... } }. An item is "tab.key"
-- or { "tab.key", indent, pair (may share a row with the item after it; pairs
-- that follow one another are one run, whose shown items go two to a row),
-- standIn (a note that keeps its section while the controls it stands in for
-- are hidden), lead, columns, widget, big (a button that leads its page: taller,
-- in the large font) }. tests/scenarios/layout.lua holds every control to being
-- placed exactly once.

local _, ns = ...
local L = ns.L

-- Only Interface\Icons: an atlas this client lacks draws as a green square.
local ICONS = {
	general = "Interface\\Icons\\INV_Misc_Map_01",
	who = "Interface\\Icons\\Spell_Holy_WordFortitude",
	skip = "Interface\\Icons\\Ability_Vanish",
	when = "Interface\\Icons\\INV_Misc_PocketWatch_01",
	click = "Interface\\Icons\\INV_Misc_Note_01",
	appearance = "Interface\\Icons\\Spell_Holy_MindVision",
	profiles = "Interface\\Icons\\INV_Misc_Head_Human_01",
	diagnostics = "Interface\\Icons\\INV_Misc_Spyglass_03",
}

-- The first spell in `spells` the client has a texture for. The probe asked
-- for each with C_Spell.GetSpellTexture, as the prompt's own icon is.
local function FirstIcon(spells)
	for _, spell in ipairs(spells or {}) do
		local info = ns.BuffInfo(spell)
		local icon = info and ns.plain(info.icon)
		if type(icon) == "number" or type(icon) == "string" then return icon end
	end
end

-- Who to buff shows the class's own first buff: Arcane Intellect for a mage,
-- Fortitude for a priest. A hunter has none for anybody else, so the first of
-- its own (an aspect); a class with neither, the fallback.
local function WhoIcon()
	local class = ns.caps and ns.caps.class
	local icon = FirstIcon(ns.GetClassBuffs(class))
	if not icon then
		local family = (ns.GetOwnFamilies(class) or {})[1]
		icon = family and FirstIcon(family.spells)
	end
	return icon or ICONS.who
end

-- The per-spell switches under Buff to offer (Who.lua's AddBuffToggles): one
-- per buff, only for a class with two or more, so a mage has none. Each class's
-- in its walk order, which is the order the buff set lists them; the model only
-- ever holds the player's own class's. On Forever that is the priest's three,
-- the paladin's six and the druid's two.
local function OfferItems()
	local items, seen, classes = {}, {}, {}
	for class, buffs in pairs(ns.BUFFS or {}) do
		if type(buffs) == "table" and #buffs > 1 then classes[#classes + 1] = class end
	end
	table.sort(classes)
	for _, class in ipairs(classes) do
		for _, buff in ipairs(ns.BUFFS[class]) do
			local path = "who.offer_" .. tostring(buff.key)
			if not seen[path] then
				seen[path] = true
				items[#items + 1] = { path, columns = 2 }
			end
		end
	end
	return items
end

-- What to cast: the buff dropdown, its switches, then the rest.
local function CastItems()
	local items = { "who.choice" }
	for _, item in ipairs(OfferItems()) do items[#items + 1] = item end
	-- A paladin's Blessing of Kings first, while the walk is Automatic.
	items[#items + 1] = "who.kingsFirst"
	items[#items + 1] = "who.relevantOnly"
	items[#items + 1] = { "who.autoNote", standIn = true }
	items[#items + 1] = "who.pinNote"
	return items
end

ns.WindowLayout = {
	-- The window frame: shown on every page, so no page shows them.
	header = {
		preview = "general.previewStart",
		-- Beside the preview: Move the prompt, which reads Lock it while the
		-- prompt is unlocked. The same control leads Look (appearance.move).
		move = "general.moveToggle",
		enabled = "general.enabled",
		snooze = { "general.snooze5", "general.snooze15", "general.snooze30", "general.snoozeStop" },
		snoozeTip = "general.snoozeNote",
	},
	strip = {
		lock = "general.lockNow",
		-- Line 2 in a fight: the open page's note.
		combat = { click = "click.combatNotice", appearance = "appearance.combatNotice", when = "advanced.advCombatNotice" },
	},
	foldCaption = "advanced.advIntro",
	footer = { reset = "advanced.resetAdvanced", build = "diagnostics.buildNote" },

	-- The sidebar, top to bottom; a hairline between groups. Page ids are the
	-- old tab keys (bug reports and ns.OptionsTab() name them), plus skip.
	groups = { { "general" }, { "who", "skip", "when", "click", "appearance" }, { "profiles", "diagnostics" } },

	pages = {
		general = {
			title = L["Start here"],
			icon = ICONS.general,
			sections = {
				-- A new profile's two questions (Start.lua, Quick.Asking); the
				-- section goes with them once answered or skipped.
				{ key = "general.firstRun", header = "general.firstHeader", items = {
					"general.firstWho",
					"general.firstVoice",
					{ "general.firstDone", pair = true },
					"general.firstSkip",
				} },
				{ key = "general.lead", items = {
					{ "general.noBuffs", standIn = true },
					{ "general.howItWorks", lead = true },
				} },
				{ key = "general.who", header = "general.whoHeader", items = {
					"general.quickWho",
					-- A hunter's step 1: the own-buff sentence, with no dropdown.
					{ "general.quickWhoSummary", standIn = true },
				} },
				{ key = "general.key", header = "general.keyHeader", items = {
					"general.bindKey",
					{ "general.makeMacro", pair = true },
					"general.openBindings",
					"general.bindStatus",
				} },
				{ key = "general.ledger", header = "general.ledgerHeader", items = {
					"general.ledgerSummary",
					"general.ledgerOpen",
				} },
				-- Unfolded, and on the one page that never hides: the chat lines
				-- are what people look for when they annoy them.
				{ key = "general.minimap", header = "general.minimapHeader", items = {
					"general.minimap",
					"general.verbose",
				} },
			},
		},

		who = {
			title = L["Who to buff"],
			icon = WhoIcon,
			sections = {
				{ key = "who.cast", header = "who.buffsHeader", items = CastItems() },
				-- The class's buffs as a list in the order they are tried, each with an
				-- arrow up and one down (the "order" composite, Widgets: five
				-- definitions drawn as one piece); for a class with two buffs or more
				-- and no spell pinned.
				{ key = "who.order", header = "who.orderHeader", items = {
					{ composite = "order", ids = {
						"who.orderNote", "who.orderPick", "who.orderUp", "who.orderDown", "who.orderReset",
					} },
				} },
				{ key = "who.sources", header = "who.sourcesHeader", items = {
					"who.emptyWarning",
					"who.owed",
					"who.group",
					"who.strangers",
					-- While passers-by are on and the game's nameplates are off.
					{ "who.strangersPlatesNote", indent = true },
					{ "who.strangersShowPlates", indent = true },
					{ "who.strangersNote", standIn = true },
					{ "who.proximity", indent = true },
					{ "who.restingOnly", indent = true },
					"who.asked",
				} },
				{ key = "who.myself", header = "who.myselfHeader", items = {
					"who.self",
					-- Only the families this character knows are shown (their own rule).
					{ "who.own_omen", indent = true },
					{ "who.own_aspect", indent = true },
					{ "who.own_trueshot", indent = true },
					{ "who.own_armor", indent = true },
					-- A mage's scrolls on Forever, while there is one in the bags.
					{ "who.own_familiar", indent = true },
					{ "who.own_imbue", indent = true },
					-- What goes on a weapon from the bags, per hand, while there is
					-- one in them; a rogue's poisons as spells on Mists and retail.
					{ "who.own_poisonmain", indent = true },
					{ "who.own_poisonoff", indent = true },
					{ "who.own_lethal", indent = true },
					{ "who.own_nonlethal", indent = true },
					{ "who.own_stonemain", indent = true },
					{ "who.own_stoneoff", indent = true },
					{ "who.own_oilmain", indent = true },
					{ "who.own_oiloff", indent = true },
					{ "who.own_lure", indent = true },
					{ "who.own_aura", indent = true },
					{ "who.own_righteousfury", indent = true },
					{ "who.own_innerfire", indent = true },
					{ "who.own_touchofweakness", indent = true },
					{ "who.own_shadowguard", indent = true },
					{ "who.own_shield", indent = true },
					{ "who.own_demonarmor", indent = true },
					{ "who.own_tracking", indent = true },
					{ "who.ownCities", indent = true },
					-- Why a buff of your own is not being offered, under the switches.
					"diagnostics.ownDiag",
				} },
				{ key = "who.group", header = "who.groupHeader", items = {
					"who.groupBuffsUse",
					{ "who.groupBuffsAtLeast", indent = true },
					"who.reagentNote",
					{ "who.skipRaidGroups", columns = 4 },
				} },
				{ key = "who.first", header = "who.firstHeader", fold = true, items = {
					"who.target",
					"who.friends",
					"who.readyCheck",
					"who.revived",
				} },
			},
		},

		-- Every "Skip ..." switch and the never-offer list, out of Who to buff.
		-- Its title is the old Who to skip header's string.
		skip = {
			title = L["Who to skip"],
			icon = ICONS.skip,
			sections = {
				{ key = "skip.lead", items = {
					"who.skipPvP",
					-- Who that switch holds back right now, under it.
					{ "diagnostics.pvpDiag", indent = true },
					"who.skipSameClass",
					"who.requireInRange",
					"who.minLevel",
				} },
				{ key = "skip.never", header = "who.neverHeader", items = {
					-- One list with a remove button per name, built from five
					-- model entries (Widgets.lua).
					{ composite = "never", ids = {
						"who.neverNote", "who.neverPick", "who.neverRemove", "who.neverAdd", "who.neverClear",
					} },
				} },
			},
		},

		when = {
			title = L["When to offer"],
			icon = ICONS.when,
			sections = {
				{ key = "when.buffed", header = "when.buffedHeader", items = {
					"when.whenBuffed",
					{ "when.refreshUnder", indent = true },
					{ "when.refreshRaid", indent = true },
					"when.selfTopUp",
					{ "when.selfLead", indent = true },
					"when.alwaysNote",
					"when.verifiedOnly",
				} },
				{ key = "when.holdBack", header = "when.wayHeader", items = {
					"when.hideMounted",
					"when.manaFloor",
					"when.manaNote",
				} },
				-- Where the old note pointing at Advanced was.
				{ key = "when.favours", header = "advanced.favoursHeader", items = {
					"advanced.reciprocateWindow",
					"advanced.owedClassBuffsOnly",
					"advanced.reachableOnly",
					{ "advanced.graceSeconds", indent = true },
					"advanced.keepDebts",
				} },
				{ key = "when.timing", header = "advanced.timingHeader", fold = true, items = {
					"advanced.retryCooldown",
					"advanced.scanInterval",
				} },
				{ key = "when.targeting", header = "advanced.targetingHeader", fold = true, items = {
					"advanced.restoreTarget",
					-- A warrior's: the switch is hidden, the note says why.
					{ "advanced.noTargetNote", standIn = true },
				} },
			},
		},

		click = {
			title = L["What I say"],
			icon = ICONS.click,
			sections = {
				-- The quick choice, directly above the switches it sets.
				{ key = "click.lead", items = {
					"general.quickVoice",
					"general.quickVoiceSummary",
				} },
				{ key = "click.speech", header = "click.speechHeader", items = {
					"click.thankEmote",
					"click.enabled",
					{ "click.channel", indent = true },
					{ "click.onlyWhenReturning", indent = true },
					-- While speaking with friendly nameplates off (Speech.lua).
					{ "click.platesNote", indent = true },
					{ "click.showPlates", indent = true },
					{ "click.linesOff", standIn = true },
				} },
				{ key = "click.lines", header = "click.phrasesHeader", items = {
					"click.preset",
					"click.phrasesHelp",
					"click.inCharacterNote",
					"click.phrases",
					{ "click.backToInCharacter", pair = true },
					"click.roll",
					"click.limits",
				} },
			},
		},

		-- Everything about the prompt itself; the wording and the exact
		-- position fold here rather than living on a page of their own.
		appearance = {
			title = L["Look"],
			icon = ICONS.appearance,
			sections = {
				-- The look to wear, as a gallery of cards (WidgetsTheme.lua) in
				-- place of the model's dropdown, which the fallback dialog keeps.
				{ key = "appearance.themes", title = L["Panel style"], items = {
					{ "appearance.style", widget = "themes" },
				} },
				-- No header of its own in the model: the control's label is the title.
				-- Moving the prompt leads the page: the button, big, with the
				-- ready-made places beside it. Lock position is not drawn (see
				-- unplaced): the button reads and sets the same lock.
				{ key = "appearance.where", title = L["Where it sits"], items = {
					{ "appearance.move", pair = true, big = true },
					"appearance.posPreset",
				} },
				{ key = "appearance.size", header = "appearance.posHeader", items = {
					{ "appearance.scale", pair = true },
					"appearance.alpha",
					{ "appearance.width", pair = true },
					"appearance.height",
				} },
				{ key = "appearance.style", header = "appearance.styleHeader", items = {
					{ "appearance.bgColor", pair = true },
					"appearance.accentByReason",
					-- With Colour marker, whatever else shows: Marker colour
					-- follows on a row of its own while Colour marker by
					-- reason is off.
					{ "appearance.reasonPalette", pair = true },
					"appearance.accentMode",
					"appearance.accentColor",
					"appearance.accentDead",
				} },
				{ key = "appearance.attention", header = "appearance.attentionHeader", items = {
					{ "appearance.flashStyle", pair = true },
					"appearance.effects",
					"appearance.hideInCombat",
					"appearance.dimInCombat",
					"appearance.soundEnabled",
					{ "appearance.soundFile", indent = true },
					{ "appearance.soundOwedOnly", indent = true },
					"appearance.noSound",
				} },
				{ key = "appearance.hover", header = "appearance.tooltipHeader", items = {
					"appearance.tooltip",
					"appearance.tooltipPosition",
				} },
				{ key = "appearance.exactPos", header = "advanced.exactPosHeader", fold = true, items = {
					{ "advanced.x", widget = "number", pair = true },
					{ "advanced.y", widget = "number" },
				} },
				{ key = "appearance.text", header = "appearance.textHeader", fold = true, items = {
					{ "appearance.font", pair = true },
					"appearance.fontSize",
					{ "appearance.fontColor", pair = true },
					"appearance.classColor",
					"appearance.showSub",
				} },
				-- The reason boxes two to a row, in queue order: one run of
				-- pairs, so a hunter's two still share a row.
				{ key = "appearance.wording", header = "advanced.wordingHeader", fold = true, items = {
					"advanced.formatHelp",
					"advanced.format",
					{ "advanced.reasonTarget", pair = true },
					"advanced.reasonOwed",
					{ "advanced.reasonAsked", pair = true },
					"advanced.reasonSelf",
					{ "advanced.reasonGroup", pair = true },
					"advanced.reasonNearby",
					{ "advanced.reasonRefresh", pair = true },
					"advanced.reasonUnknown",
				} },
				{ key = "appearance.icon", header = "appearance.iconHeader", fold = true, items = {
					"appearance.showIcon",
					{ "appearance.iconSize", indent = true },
					"appearance.iconSizeCapped",
					{ "appearance.roundIcon", indent = true },
					{ "appearance.showCooldown", indent = true },
					"appearance.showCount",
					"appearance.showQueue",
					{ "appearance.queueRows", indent = true },
					{ "appearance.clickRows", indent = true },
				} },
			},
		},

		profiles = {
			title = L["Profiles"],
			icon = ICONS.profiles,
			sections = {
				-- AceDBOptions' own entries (current to reset) with its grey
				-- descriptions beside the controls they explain.
				{ key = "profiles.lead", items = {
					"profiles.profilesIntro",
					"general.sharedNote",
					"general.ownProfile",
					"profiles.current",
					"profiles.choosedesc",
					{ "profiles.new", pair = true },
					"profiles.choose",
					"profiles.copydesc",
					"profiles.copyfrom",
					"profiles.deldesc",
					"profiles.delete",
					"profiles.descreset",
					"profiles.reset",
				} },
				{ key = "profiles.share", header = "profiles.shareHeader", items = {
					"profiles.shareNote",
					"profiles.shareCopy",
					"profiles.shareText",
					"profiles.sharePaste",
				} },
			},
		},

		diagnostics = {
			title = L["Diagnostics"],
			icon = ICONS.diagnostics,
			sections = {
				{ key = "diagnostics.see", header = "diagnostics.capsHeader", items = {
					"diagnostics.noDiag",
					"diagnostics.diag",
					"diagnostics.leadDiag",
					"diagnostics.proximityDiag",
				} },
				{ key = "diagnostics.errors", header = "diagnostics.errorsHeader", items = {
					"diagnostics.errorList",
					"diagnostics.noErrors",
				} },
				{ key = "diagnostics.report", header = "diagnostics.reportHeader", items = {
					"diagnostics.debugClicks",
					"diagnostics.copyReport",
					"diagnostics.report",
					"diagnostics.selftest",
				} },
			},
		},
	},

	-- How a note is drawn when not in the label colour: grey (a colour code
	-- in its text still wins), or grey in a block inset from the page. Kept
	-- apart from the items, which say where a row goes rather than how it
	-- looks.
	notes = {
		["who.autoNote"] = { hint = true },
		["diagnostics.ownDiag"] = { hint = true, block = true },
		["diagnostics.pvpDiag"] = { hint = true, block = true },
		["diagnostics.leadDiag"] = { hint = true, block = true },
		-- AceDBOptions' descriptions, beside the controls they explain.
		["profiles.choosedesc"] = { hint = true },
		["profiles.copydesc"] = { hint = true },
		["profiles.deldesc"] = { hint = true },
		["profiles.descreset"] = { hint = true },
	},

	-- In the model and drawn nowhere.
	unplaced = {
		-- AceDBOptions' opening paragraph, hidden today: profilesIntro says it.
		["profiles.desc"] = true,
		-- "3. See it": its preview is the header's button now.
		["general.tryHeader"] = true,
		-- "4. Say thanks (optional)": the voice choice leads What I say.
		["general.voiceHeader"] = true,
		-- Snooze is a menu button in the header.
		["general.snoozeHeader"] = true,
		-- "Lock position": Look's first control is the Move the prompt button,
		-- which reads Lock it while the prompt is unlocked and goes the same
		-- way as /manners unlock and lock; the saved setting is the same.
		["appearance.locked"] = true,
		-- Its string is the Who to skip page's title.
		["who.skipHeader"] = true,
		-- "Messages in chat": Log every click joined Reporting a bug.
		["diagnostics.chatHeader"] = true,
	},
}
