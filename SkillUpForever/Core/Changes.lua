---@type string, SkillUpNamespace
local _, ns = ...

-- What goes stale when something changes. A writer says what changed with ns.Changed; the game's own
-- changes arrive as the events below. Only this file knows which caches that drops and which views it
-- redraws: each once per change, caches before views, in ORDER.

-- The route page only arms its redraw timer, so its place among the views is free. So is the hovered
-- tooltip's: it only marks the row for its next update, which the game asks for on its own.
---@type SkillUpStale[]
local ORDER = {
	"schematics",
	"prices",
	"plans",
	"api",
	"route",
	"recipeList",
	"tracker",
	"trainer",
	"routeTab",
	"gear",
	"tooltip",
	"auctionSearch",
	"detailsBar",
	"shoppingList",
}

---@type table<SkillUpChange, table<SkillUpStale, true>>
local STALE = {
	-- What a profession's recipes are or need: a recipe learned, or the open window's scan finding a learned
	-- flag, a live grey, skill points or a schematic the plans were built without. The plan is built from all
	-- of it.
	recipes = {
		schematics = true,
		plans = true,
		api = true,
		route = true,
		tracker = true,
		gear = true,
		auctionSearch = true,
		detailsBar = true,
		shoppingList = true,
	},
	-- The profession window opened, moved to another profession or redrew its list: what shows it follows,
	-- from plans kept as they are. What the window holds that the plans lack, its scan reports as recipes.
	window = {
		api = true,
		route = true,
		tracker = true,
		gear = true,
		auctionSearch = true,
		detailsBar = true,
		shoppingList = true,
	},
	-- A skill line moved: often a weapon or defense skill-up in combat, nothing a plan reads. A plan is keyed by
	-- its profession's skill, bonus and cap, so a profession's own skill-up rebuilds that one plan on its next ask.
	skill = { api = true, route = true, tracker = true, detailsBar = true, shoppingList = true },
	-- A profession learned or dropped changes what counts as gathered, so what things cost.
	professions = {
		prices = true,
		plans = true,
		api = true,
		route = true,
		recipeList = true,
		tracker = true,
		gear = true,
		shoppingList = true,
	},
	prices = {
		prices = true,
		plans = true,
		api = true,
		route = true,
		recipeList = true,
		tracker = true,
		shoppingList = true,
	},
	bags = { api = true, route = true, tracker = true, shoppingList = true },
	-- Item data arrived; `names` when the public list was waiting on it.
	items = { route = true, tracker = true, gear = true, shoppingList = true },
	names = { api = true },
	level = { api = true, route = true, tracker = true, gear = true, shoppingList = true },
	zone = { api = true },
	-- A merchant opened, restocked or closed: the tracker's buy button.
	merchant = { tracker = true, shoppingList = true },
	-- Fees and requirements recorded at a trainer.
	fees = { plans = true, api = true, route = true, tracker = true, shoppingList = true },
	-- Where scrolls, vendors and trainers are, read from Questie and AtlasLoot or seen at a merchant's window.
	sources = { api = true, route = true, tracker = true, tooltip = true, gear = true, shoppingList = true },
	target = { plans = true, api = true, route = true, tracker = true, shoppingList = true },
	tracking = { api = true, route = true, tracker = true, shoppingList = true },
	settings = {
		prices = true,
		plans = true,
		api = true,
		route = true,
		recipeList = true,
		tracker = true,
		trainer = true,
		routeTab = true,
		gear = true,
		auctionSearch = true,
		detailsBar = true,
		shoppingList = true,
	},
}

---@type table<string, SkillUpChange>
local EVENTS = {
	TRADE_SKILL_DATA_SOURCE_CHANGED = "window",
	NEW_RECIPE_LEARNED = "recipes",
	TRADE_SKILL_SHOW = "window",
	TRADE_SKILL_LIST_UPDATE = "window",
	SKILL_LINES_CHANGED = "skill",
	BAG_UPDATE_DELAYED = "bags",
	ITEM_DATA_LOAD_RESULT = "items",
	PLAYER_LEVEL_UP = "level",
	ZONE_CHANGED_NEW_AREA = "zone",
	MERCHANT_SHOW = "merchant",
	MERCHANT_UPDATE = "merchant",
	MERCHANT_CLOSED = "merchant",
}

-- A /reload after an update that added Core/SafeCall.lua runs without it (Core.lua says to restart the game):
-- the handlers are then called directly.
local SafeCall = ns.SafeCall
	or function(_, fn, ...)
		return true, fn(...) -- multi-value: fn's results, as SafeCall gives them
	end
-- The name each stale handler's failure is kept under for /su report, made once.
---@type table<SkillUpStale, string>
local LABELS = {}
for _, name in ipairs(ORDER) do
	LABELS[name] = "stale " .. name
end

---@type table<SkillUpStale, fun()>
local handlers = {}
---@type table<string, (fun(): SkillUpChange?)[]>
local watchers = {}

---@param kinds table<SkillUpChange, true>
local function Apply(kinds)
	local stale = {}
	for kind in pairs(kinds) do
		for name in pairs(STALE[kind]) do
			stale[name] = true
		end
	end
	for _, name in ipairs(ORDER) do
		local handler = stale[name] and handlers[name]
		if handler then
			-- One failing cache or view doesn't stop the rest; the error is kept for /su report.
			SafeCall(LABELS[name], handler)
		end
	end
end

-- Something changed that no event below reports: a setting, a target, a price.
---@param kind SkillUpChange
function ns.Changed(kind)
	assert(STALE[kind], kind)
	Apply({ [kind] = true })
end

-- How the owner of a cache drops it, or of a view redraws it. A view registers once its frames exist;
-- until then it has nothing to redraw.
---@param name SkillUpStale
---@param handler fun()
function ns.WhenStale(name, handler)
	handlers[name] = handler
end

local frame = CreateFrame("Frame")
for event in pairs(EVENTS) do
	frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event)
	local kinds = {}
	if EVENTS[event] then
		kinds[EVENTS[event]] = true
	end
	for _, watcher in ipairs(watchers[event] or {}) do
		local ok, kind = SafeCall(event, watcher)
		if ok and kind then
			kinds[kind] = true
		end
	end
	Apply(kinds)
end)

-- A file's own work on a game event, run before anything is dropped or redrawn for it. It returns
-- what else it found changed, which joins the event's own change in one pass.
---@param event WowEvent
---@param watcher fun(): SkillUpChange?
function ns.WhenEvent(event, watcher)
	watchers[event] = watchers[event] or {}
	table.insert(watchers[event], watcher)
	frame:RegisterEvent(event)
end
