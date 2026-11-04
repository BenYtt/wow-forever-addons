---@type string, SkillUpNamespace
local _, ns = ...

-- SkillUp's own lines in /su report (cjber/adventure-guide-forever#156): the settings that change a number, the
-- data providers, each profession with its route, then /su audit's lines and the trainer checks for this
-- character's professions, each list cut so the caught errors after it still fit in one message. Field labels and
-- reasons are English; profession and recipe names are the client's.

-- How many of a list's detail lines the report keeps; the rest are counted.
local DETAIL_SHOWN = 6

-- `lines` with at most DETAIL_SHOWN of `details` after them, indented, and how many more there were.
---@param lines string[]
---@param details string[]
---@param from integer the first detail in `details`
local function AddDetails(lines, details, from)
	local shown = 0
	for index = from, #details do
		if shown == DETAIL_SHOWN then
			lines[#lines + 1] = ("  and %d more"):format(#details - index + 1)
			return
		end
		shown = shown + 1
		lines[#lines + 1] = "  " .. details[index]
	end
end

---@param state string|boolean
---@return string
local function Provider(state)
	return state == true and "ready" or state == false and "missing" or tostring(state)
end

-- The report's SkillUp lines.
---@return string[]
function ns.ReportLines()
	local db = ns.db
	local lines = {
		("Settings: crafts count %s, gathered %s, reagent tooltips %s, sort %s"):format(
			db.craftValue,
			db.valueGathered and "valued" or "free",
			db.reagentTooltip,
			db.sortMode
		),
		("Providers: QuestieDB %s, AtlasLoot %s, Auctionator %s"):format(
			ns.Questie.State(),
			Provider(ns.AtlasLoot.Ready() or (ns.AtlasLoot.Idle() and "off") or false),
			Provider(ns.HasAuctionator())
		),
	}
	local professions = ns.PlayerProfessions()
	local routable = ns.RouteProfessions()
	local skillLines = {}
	for skillLine in pairs(professions) do
		skillLines[#skillLines + 1] = skillLine
	end
	table.sort(skillLines)
	for _, skillLine in ipairs(skillLines) do
		local p = professions[skillLine]
		local line = ("%s [%d]: %d+%d/%d"):format(p.name, skillLine, p.base, p.modifier, p.max)
		local profession = routable[skillLine]
		if profession then
			local plan = ns.PlanRoute(profession)
			line = line
				.. ("; route to %d reaches %d, %d steps, %s"):format(
					plan.target,
					plan.reached,
					#plan.steps,
					plan.stopReason or (#plan.crafts == 0 and "nothing to craft" or "ok")
				)
		end
		lines[#lines + 1] = line
	end
	local audit = ns.AuditLines()
	if audit then
		lines[#lines + 1] = "Audit: " .. audit[1]
		AddDetails(lines, audit, 2)
	else
		lines[#lines + 1] = "Audit: no profession open"
	end
	-- The bundled trainer requirements a trainer could prove wrong (/su trainers), for this character's
	-- professions: how many were moved from classic-db's, confirmed at a trainer, and each one shown differently.
	local counts, wrong = {}, {}
	for _, check in ipairs(ns.TrainerChecks()) do
		if professions[check.skillLine] then
			local count = counts[check.skillLine] or { moved = 0, confirmed = 0, wrong = 0 }
			counts[check.skillLine] = count
			if check.classic then
				count.moved = count.moved + 1
			end
			if check.shown and check.shown == check.bundled then
				count.confirmed = count.confirmed + 1
			elseif check.shown then
				count.wrong = count.wrong + 1
				local name = C_Spell.GetSpellName(check.recipeID) or "?"
				wrong[#wrong + 1] = ("%s (%d): bundled %s, trainer %d"):format(
					name,
					check.recipeID,
					tostring(check.bundled or "-"),
					check.shown
				)
			end
		end
	end
	local summaries = {}
	for _, skillLine in ipairs(skillLines) do
		local count = counts[skillLine]
		if count then
			summaries[#summaries + 1] = ("%s %d moved, %d confirmed, %d wrong"):format(
				professions[skillLine].name,
				count.moved,
				count.confirmed,
				count.wrong
			)
		end
	end
	lines[#lines + 1] = "Trainers: " .. (summaries[1] and table.concat(summaries, "; ") or "nothing to check")
	AddDetails(lines, wrong, 1)
	return lines
end
