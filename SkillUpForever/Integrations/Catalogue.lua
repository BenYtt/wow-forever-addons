---@type string, SkillUpNamespace
local _, ns = ...
local L = ns.L

-- Where recipes, vendors and trainers are, from the QuestieDB and AtlasLoot the player has installed. A
-- profession's scrolls are worked out the first time it is asked for and kept for the session, never saved.
-- The one thing saved is what the player saw for themselves: which vendor sold what, and where it stood.
-- All reading goes through one queue that does a little each frame, and what was missing is read again
-- when a provider becomes ready.

local Q, A = ns.Questie, ns.AtlasLoot
-- Each frame the queue reads at most this many records, and stops early past this many milliseconds.
local RECORDS, SLICE_MS = 32, 1

---@class SkillUpCatalogue
local C = {}
ns.Catalogue = C

---@type (fun(): boolean?)[]
local queue = {}
local head, tail, running, dirty = 1, 0, false, false
---@type string?
local failure

local function Step()
	local started, done = debugprofilestop(), 0
	while head <= tail and done < RECORDS and debugprofilestop() - started < SLICE_MS do
		-- A job that returns true has more records to read and keeps its place.
		local ok, again = pcall(queue[head])
		if not ok then
			failure = tostring(again)
		end
		if not (ok and again) then
			queue[head] = nil
			head = head + 1
		end
		done = done + 1
	end
	if head <= tail then
		C_Timer.After(0, Step)
		return
	end
	queue, head, tail, running = {}, 1, 0, false
	if dirty then
		dirty = false
		ns.Changed("sources")
	end
end

---@param job fun(): boolean?
local function Enqueue(job)
	tail = tail + 1
	queue[tail] = job
	if not running then
		running = true
		C_Timer.After(0, Step)
	end
end

-- Session caches: a record, or false for one a provider does not have.
---@type table<integer, SkillUpItemSources|false>
local items = {}
---@type table<integer, SkillUpSourceNPC|false>
local npcs = {}
---@type table<integer, SkillUpSourceQuest|false>
local quests = {}
-- [skill line] = false while it is being read, then [recipeID] = where its scroll comes from.
---@type table<integer, table<integer, SkillUpScrollSource>|false>
local professions = {}
-- [itemID] = false while its vendors are being read, then true.
---@type table<integer, boolean>
local vendorsRead = {}
-- [recipeID] = every scroll QuestieDB says teaches it; nil until its items have been gone through.
---@type table<integer, integer[]>?
local taught
-- True while QuestieDB's items are being gone through, so two professions asked for together share one pass.
local scanning = false

-- Everything read so far is dropped and read again: a provider became ready, so a miss may now be a hit.
local function Reset()
	items, npcs, quests, professions, vendorsRead, taught, scanning = {}, {}, {}, {}, {}, nil, false
	queue, head, tail = {}, 1, 0
	if running then
		dirty = true
	else
		ns.Changed("sources")
	end
end

-- What is installed: Questie's state, whether AtlasLoot is readable, whether the queue is still reading,
-- and the last error a provider raised.
---@return {questie: SkillUpProviderState, atlasLoot: boolean, reading: boolean, failure: string?}
function C.Status()
	return { questie = Q.State(), atlasLoot = A.Ready(), reading = running, failure = failure }
end

-- One plain line naming what to install for where recipes, vendors and trainers are; nil with both. An
-- AtlasLoot that is installed but not running is told apart from a missing one. With `places`, only what
-- names a vendor or trainer matters, which is Questie.
---@param places boolean?
---@return string?
function C.Hint(places)
	local state, atlasLoot = Q.State(), A.Ready() or places
	if state == "unfit" then
		return L["Update Questie to see vendors, quests and trainers, with waypoints to them."]
	elseif state == "missing" and not atlasLoot then
		return L["Install Questie and AtlasLoot to see where recipes, vendors and trainers are."]
	elseif state == "missing" then
		return L["Install Questie to see vendors, quests and trainers, with waypoints to them."]
	elseif not atlasLoot and A.Idle() then
		return L["AtlasLoot is installed but not running: enable it in the AddOns list, or update it if out of date."]
	elseif not atlasLoot then
		return L["Install AtlasLoot to see the recipes vendors, quests and drops would add."]
	end
end

---@param cache table
---@param id integer
---@param read fun(id: integer): table?
---@return any
local function Cached(cache, id, read)
	local record = cache[id]
	if record == nil then
		record = read(id) or false
		cache[id] = record
	end
	return record or nil
end

-- Questie's record of an item, with every vendor the player has seen selling it among its vendors.
---@param itemID integer
---@return SkillUpItemSources?
local function ReadItem(itemID)
	local found = Q.Item(itemID)
	for npcID, seller in pairs(ns.db.sellers) do
		if seller.items[itemID] and ns.SellerFresh(seller) then
			found = found or { vendors = {}, quests = {}, drops = {} }
			local known = false
			for _, vendor in ipairs(found.vendors) do
				known = known or vendor == npcID
			end
			if not known then
				table.insert(found.vendors, npcID)
			end
		end
	end
	if found then
		table.sort(found.vendors)
	end
	return found
end

-- A vendor the player has stood at is where the player stood, under the name it had there, whatever a
-- database says or lacks. It deals with the side that saw it, and with both when Questie says so.
---@param npcID integer
---@return SkillUpSourceNPC?
local function ReadNPC(npcID)
	local npc, seller = Q.NPC(npcID), ns.db.sellers[npcID]
	if not seller or not ns.SellerFresh(seller) then
		return npc
	end
	return {
		name = seller.name,
		side = npc and npc.side == "" and "" or seller.side,
		map = seller.map,
		x = seller.x,
		y = seller.y,
	}
end

-- Who sells an item, the quests that reward it and who drops it; nil for an item neither Questie nor a
-- merchant's window has shown.
---@param itemID integer
---@return SkillUpItemSources?
function C.ItemSources(itemID)
	return Cached(items, itemID, ReadItem)
end

---@param npcID integer
---@return SkillUpSourceNPC?
function C.NPC(npcID)
	return Cached(npcs, npcID, ReadNPC)
end

-- The vendor whose window is open sells these items. The ones the addon has a use for (a reagent of a
-- recipe it knows, or a scroll that teaches one) are kept with the vendor in the saved variables, so it is
-- named for them from then on. True when that told the catalogue something new.
---@param npcID integer
---@param seller SkillUpSeller The vendor's name, side and place; its `items` are filled in here.
---@param itemIDs integer[]
---@return boolean
function C.SawVendor(npcID, seller, itemIDs)
	local known = ns.db.sellers[npcID]
	-- A vendor last seen two builds ago was left out of the reads; seeing it now brings it back.
	local fresh = not known or ns.SellerFresh(known)
	local sells, new = known and known.items or {}, {}
	for _, itemID in ipairs(itemIDs) do
		local item = items[itemID]
		if
			not sells[itemID]
			and (#ns.UsedIn(itemID) > 0 or (select(2, A.Scroll(itemID))) ~= nil or (item and item.teaches ~= nil))
		then
			sells[itemID] = true
			new[#new + 1] = itemID
		end
	end
	-- A vendor nothing the addon uses sells is not worth keeping; one already kept is restamped.
	if not known and #new == 0 then
		return false
	end
	seller.build = ns.ClientBuild()
	seller.items = sells
	ns.db.sellers[npcID] = seller
	if #new == 0 and fresh then
		return false
	end
	local reread = {}
	if not fresh then
		for itemID in pairs(sells) do
			reread[itemID] = true
		end
	end
	for _, itemID in ipairs(new) do
		reread[itemID] = true
	end
	-- Read again here, at the window, so nothing is read while a step is drawn.
	npcs[npcID] = nil
	C.NPC(npcID)
	for itemID in pairs(reread) do
		items[itemID] = nil
		C.ItemSources(itemID)
	end
	-- A scroll already read for its profession holds the vendors it had then.
	for _, snapshot in pairs(professions) do
		for _, source in pairs(snapshot or {}) do
			local found = sells[source.item] and C.ItemSources(source.item)
			if found then
				source.vendors = found.vendors
			end
		end
	end
	return true
end

---@param questID integer
---@return SkillUpSourceQuest?
function C.Quest(questID)
	return Cached(quests, questID, Q.Quest)
end

-- Every scroll that teaches a recipe, lowest item first. QuestieDB's items name them all; AtlasLoot keeps
-- one a recipe, so it only answers when QuestieDB names none.
---@param spellID integer
---@return integer[]
function C.Scrolls(spellID)
	local found = taught and taught[spellID]
	if found then
		return found
	end
	local itemID = A.ScrollFor(spellID)
	return itemID and { itemID } or {}
end

-- Where a recipe's scroll comes from, once its profession has been read; nil before then, for a recipe
-- no scroll teaches, and for one neither provider knows.
---@param spellID integer
---@return SkillUpScrollSource?
function C.Recipe(spellID)
	local recipe = ns.RecipeData[spellID]
	local snapshot = recipe and professions[recipe.skillLine]
	return snapshot and snapshot[spellID] or nil
end

-- The trainers of a profession who teach up to `cap`. Which NPC trains what, and how far, is bundled; who
-- they are and where they stand comes from Questie.
---@param skillLine integer
---@param cap number
---@return integer[]
function C.Trainers(skillLine, cap)
	local trainers = {}
	for _, row in ipairs(ns.ProfessionTrainers[skillLine] or {}) do
		if row[2] >= cap then
			trainers[#trainers + 1] = row[1]
		end
	end
	return trainers
end

---@param npcIDs integer[]
local function ReadNPCs(npcIDs)
	for _, npcID in ipairs(npcIDs) do
		if npcs[npcID] == nil then
			Enqueue(function()
				C.NPC(npcID)
			end)
		end
	end
end

---@param spellID integer
---@return SkillUpScrollSource?
local function ReadRecipe(spellID)
	local best
	for _, itemID in ipairs(C.Scrolls(spellID)) do
		local found = C.ItemSources(itemID)
		local drops = {}
		for index, drop in ipairs(ns.ScrollDrops[itemID] or {}) do
			drops[index] = { drop[1], A.DropChance(drop[1], itemID) or drop[2] }
		end
		---@type SkillUpScrollSource
		local source = {
			item = itemID,
			skill = (A.Scroll(itemID)),
			vendors = found and found.vendors or {},
			quests = found and found.quests or {},
			drops = drops,
			world = ns.WorldDrops[itemID] or false,
		}
		-- Several scrolls can teach one recipe: the first a vendor sells, else the lowest item.
		if not best or (#source.vendors > 0 and #best.vendors == 0) then
			best = source
		end
	end
	return best
end

-- Goes through QuestieDB's items for the scrolls that teach a recipe, one record a turn.
local function ReadScrolls()
	local ids, index, found = Q.ItemIDs(), 0, {}
	Enqueue(function()
		index = index + 1
		local itemID = ids[index]
		if not itemID then
			taught = found
			return false
		end
		-- Read past the cache: nearly every item is no scroll, and none of those is asked for again.
		local item = Q.Item(itemID)
		local spellID = item and item.teaches
		if spellID and ns.RecipeData[spellID] then
			found[spellID] = found[spellID] or {}
			table.insert(found[spellID], itemID)
		end
		return true
	end)
end

-- Whether QuestieDB's items are worth going through for scrolls: always without AtlasLoot, and with it only
-- when QuestieDB names the recipe on a scroll AtlasLoot knows, since a database that leaves that out names
-- none.
---@param recipeIDs integer[]
---@return boolean
local function ScrollsNamed(recipeIDs)
	if not A.Ready() then
		return true
	end
	for _, spellID in ipairs(recipeIDs) do
		local itemID = A.ScrollFor(spellID)
		if itemID then
			local item = C.ItemSources(itemID)
			return item ~= nil and item.teaches ~= nil
		end
	end
	return false
end

-- True once a profession's scroll sources are read. The first call for one starts the reading, and what
-- depends on it is redrawn when the queue has finished.
---@param skillLine integer
---@return boolean
function C.EnsureProfession(skillLine)
	if professions[skillLine] ~= nil then
		return professions[skillLine] ~= false
	end
	-- With neither provider there is nothing to read: the profession has no scroll sources.
	if Q.State() ~= "ready" and not A.Ready() then
		professions[skillLine] = {}
		return true
	end
	professions[skillLine] = false
	local recipeIDs = {}
	for spellID, recipe in pairs(ns.RecipeData) do
		if recipe.skillLine == skillLine then
			recipeIDs[#recipeIDs + 1] = spellID
		end
	end
	table.sort(recipeIDs)
	local snapshot = {}
	Enqueue(function()
		if Q.State() == "ready" and not taught and not scanning then
			if ScrollsNamed(recipeIDs) then
				scanning = true
				ReadScrolls()
			else
				taught = {}
			end
		end
		for _, spellID in ipairs(recipeIDs) do
			Enqueue(function()
				local source = ReadRecipe(spellID)
				snapshot[spellID] = source
				if source then
					ReadNPCs(source.vendors)
					for _, drop in ipairs(source.drops) do
						ReadNPCs({ drop[1] })
					end
					for _, questID in ipairs(source.quests) do
						Enqueue(function()
							C.Quest(questID)
						end)
					end
				end
			end)
		end
		ReadNPCs(C.Trainers(skillLine, 0))
		-- The recipes queue their NPCs and quests behind this, so the snapshot is published behind those.
		Enqueue(function()
			Enqueue(function()
				professions[skillLine] = snapshot
				dirty = true
			end)
		end)
	end)
	return false
end

-- True once an item's vendors are read, so the nearest can be picked without a read on the way.
---@param itemID integer
---@return boolean
function C.EnsureVendors(itemID)
	-- Without Questie nobody is known to sell anything, and there is nothing to read.
	if Q.State() ~= "ready" then
		return true
	end
	if vendorsRead[itemID] ~= nil then
		return vendorsRead[itemID]
	end
	vendorsRead[itemID] = false
	Enqueue(function()
		local found = C.ItemSources(itemID)
		ReadNPCs(found and found.vendors or {})
		Enqueue(function()
			vendorsRead[itemID] = true
			dirty = true
		end)
	end)
	return false
end

-- Starts looking for the providers. An addon that loads later is picked up, and so is Questie finishing
-- its own start.
function ns.InitCatalogue()
	local atlasLoot, started = A.Ready(), false
	-- A database that is ready as this starts has had nothing read from it yet, so nothing is redrawn.
	Q.Start(function()
		if started then
			Reset()
		end
	end)
	started = true
	ns.WhenEvent("ADDON_LOADED", function()
		Q.Start(Reset)
		if A.Ready() ~= atlasLoot then
			atlasLoot = A.Ready()
			Reset()
		end
	end)
end
