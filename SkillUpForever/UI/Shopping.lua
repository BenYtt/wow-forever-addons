---@type string, SkillUpNamespace
local _, ns = ...
local L = ns.L

local CALLER = "SkillUp Forever"
-- Missing reagents shown per profession before "...".
local MAX_OBJECTIVES = 6

---@type SkillUpTrackerModule?
local module
---@type Button?
local buyButton
-- Set when the anchor cannot be read: the section then stays out of the tracker instead of raising.
local detached = false

---@return boolean
function ns.HasAuctionator()
	local api = Auctionator and Auctionator.API and Auctionator.API.v1
	return api and api.CreateShoppingList and api.ConvertToSearchString and true or false
end

-- The last count the client let us read per item, for when it hands over a secret one.
local lastCounts = {}

-- Bags and bank: the client knows bank counts once the bank has been opened. A secret count would turn every
-- sum, comparison and cache it reaches secret until a reload, so it reads as the last count seen instead.
---@param itemID integer
---@return number
function ns.Have(itemID)
	local count = ns.Readable(C_Item.GetItemCount(itemID, true))
	if count then
		lastCounts[itemID] = count
		return count
	end
	return lastCounts[itemID] or 0
end

-- What your other characters on this realm and faction hold (bags, bank, mail),
-- most first, when Syndicator is installed: they can mail it over.
---@param itemID integer
---@return {name: string, count: number}[]
function ns.AltCounts(itemID)
	local api = Syndicator and Syndicator.API
	if not (api and api.GetInventoryInfoByItemID and api.IsReady and api.IsReady()) then
		return {}
	end
	local info = api.GetInventoryInfoByItemID(itemID, true, true)
	local me, realm = UnitName("player"), ns.NormalizedRealm()
	local alts = {}
	for _, character in ipairs(info and info.characters or {}) do
		local count = character.bags + character.bank + character.mail
		if count > 0 and not (character.character == me and character.realmNormalized == realm) then
			alts[#alts + 1] = { name = character.character, count = count }
		end
	end
	table.sort(alts, function(a, b)
		return a.count > b.count
	end)
	return alts
end

-- Auctionator searches by name, and names of unseen items arrive asynchronously.
---@param items SkillUpShoppingItem[]
---@param callback fun()
local function WithNames(items, callback)
	local container = ContinuableContainer:Create()
	for _, item in ipairs(items) do
		container:AddContinuable(Item:CreateFromItemID(item.itemID))
	end
	container:ContinueOnLoad(callback)
end
ns.WithItemNames = WithNames

-- Auctionator replaces same-named lists account-wide, so each character owns its own namespace.
---@param profession string
---@return string?
function ns.AuctionListName(profession)
	local character = ns.CharacterKey()
	return character and ("SkillUp: " .. character .. ": " .. profession) or nil
end

-- Auctionator's own "scan when the auction house opens" option, read through its config table. nil
-- when it cannot be read: it is not part of Auctionator's public API.
---@return boolean?
function ns.AuctionatorAutoscan()
	local ok, value = pcall(function()
		local config = Auctionator and Auctionator.Config
		if not (config and config.Options) then
			return nil
		end
		return config.Get(config.Options.AUTO_LIST_SEARCH)
	end)
	if ok and type(value) == "boolean" then
		return value
	end
	return nil
end

-- The auction house reagents a route still needs: what no vendor sells and this character buys. Written only
-- with Buy reagents on, where a material you gather shows as gathered only while nothing prices it.
---@param items SkillUpNeededItem[]
---@return SkillUpShoppingItem[]
local function MissingFromAuction(items)
	local missing = {}
	for _, item in ipairs(items) do
		local count = item.need - ns.Have(item.itemID)
		if (item.source == "auction" or item.source == "unknown" or item.source == "gather") and count > 0 then
			missing[#missing + 1] = { itemID = item.itemID, count = count }
		end
	end
	return missing
end

---@param name string
---@param missing SkillUpShoppingItem[]
local function WriteAuctionList(name, missing)
	local api = Auctionator.API.v1
	if #missing == 0 then
		api.CreateShoppingList(CALLER, name, {})
		return
	end
	WithNames(missing, function()
		local searches = {}
		for _, item in ipairs(missing) do
			searches[#searches + 1] = api.ConvertToSearchString(CALLER, {
				-- WithNames fires only after every item record is cached.
				searchString = assert(C_Item.GetItemNameByID(item.itemID)),
				isExact = true,
				quantity = item.count,
			})
		end
		api.CreateShoppingList(CALLER, name, searches)
	end)
end

-- The list last written for each profession, so an unchanged need leaves Auctionator alone.
local auctionLists = {}

---@param missing SkillUpShoppingItem[]
---@return string
local function AuctionSignature(missing)
	local parts = {}
	for index, item in ipairs(missing) do
		parts[index] = item.itemID .. "x" .. item.count
	end
	return table.concat(parts, ",")
end

-- Keep every tracked route's Auctionator list up to date with what it still buys, empties one it no
-- longer needs, and leaves an unchanged list alone. Gather mode buys nothing, so it is left as it is.
local function SyncAuctionator()
	if not ns.HasAuctionator() or ns.CollectMode() ~= "auction" then
		return
	end
	for _, entry in ipairs(ns.TrackedNeeds()) do
		local name = ns.AuctionListName(entry.plan.profession.name)
		local missing = MissingFromAuction(entry.items)
		local signature = AuctionSignature(missing)
		if name and auctionLists[name] ~= signature then
			auctionLists[name] = signature
			WriteAuctionList(name, missing)
		end
	end
end

---@param skillLine integer?
---@return boolean
function ns.IsTracked(skillLine)
	return ns.db.trackedProfessions[skillLine] == true
end

-- Starts tracking the profession the player just opened, its own window or a trainer that teaches it,
-- when its route still has steps, so the tracker and the where-to-train hints arrive without a hunt.
-- A saved true (tracked) or false (stopped by hand) is a decision already made and is left alone.
---@param skillLine integer?
---@return boolean started
function ns.AutoTrack(skillLine)
	if not skillLine or ns.db.trackedProfessions[skillLine] ~= nil then
		return false
	end
	local profession = ns.RouteProfessions()[skillLine]
	if not profession or #ns.PlanRoute(profession).steps == 0 then
		return false
	end
	ns.db.trackedProfessions[skillLine] = true
	ns.Changed("tracking")
	return true
end

-- The plan of every tracked profession of this character with the reagents it
-- still needs, so it follows skill, target and prices.
---@return SkillUpTracked[]
function ns.TrackedNeeds()
	local tracked = {}
	for skillLine, profession in pairs(ns.RouteProfessions()) do
		if ns.IsTracked(skillLine) then
			local plan = ns.PlanRoute(profession)
			tracked[#tracked + 1] = { plan = plan, items = ns.RouteReagents(plan) }
		end
	end
	table.sort(tracked, function(a, b)
		return a.plan.profession.name < b.plan.profession.name
	end)
	return tracked
end

-- What the open merchant sells for gold of the tracked reagents still missing,
-- and its cost. Two professions sharing a reagent need both amounts.
local function MerchantPurchases()
	local missing = {}
	for _, entry in ipairs(ns.TrackedNeeds()) do
		for _, item in ipairs(entry.items) do
			missing[item.itemID] = (missing[item.itemID] or -ns.Have(item.itemID)) + item.need
		end
	end
	local purchases, cost = {}, 0
	for index = 1, GetMerchantNumItems() do
		local itemID = GetMerchantItemID(index)
		local info = C_MerchantFrame.GetItemInfo(index)
		local count = itemID and missing[itemID]
		if
			count
			and count > 0
			and info
			and info.price
			and info.price > 0
			and info.stackCount
			and info.stackCount > 0
			and not info.hasExtendedCost
		then
			local stack = info.stackCount
			count = math.ceil(count / stack) * stack
			if info.numAvailable and info.numAvailable >= 0 then
				count = math.min(count, info.numAvailable * stack)
			end
			if count > 0 then
				purchases[#purchases + 1] = { index = index, count = count, stack = stack }
				cost = cost + info.price * count / stack
			end
		end
	end
	return purchases, cost
end

-- Set by a click until the bags show what it bought: the missing counts only drop then, so a second
-- click before that would place the same order again.
---@type table?
local ordered
-- A purchase the server refuses (full bags) changes no bag and closes no merchant, so nothing else
-- would bring the button back. Long enough for a slow bag update, short enough to try again.
local ORDER_TIMEOUT = 3

-- BuyMerchantItem counts units, priced per merchant stack, and takes at most
-- GetMerchantItemMaxStack units a call (Blizzard's MerchantFrame does the same).
---@param expected number? the cost the player agreed to; anything else is not bought
local function BuyMissing(expected)
	if ordered then
		return
	end
	local purchases, cost = MerchantPurchases()
	if expected and cost ~= expected then
		return
	end
	if cost > GetMoney() then
		ns.Print(L["not enough money for every missing reagent here."])
		return
	end
	for _, purchase in ipairs(purchases) do
		local perCall = math.max(math.floor(GetMerchantItemMaxStack(purchase.index) / purchase.stack), 1)
			* purchase.stack
		local remaining = purchase.count
		while remaining > 0 do
			local count = math.min(remaining, perCall)
			BuyMerchantItem(purchase.index, count)
			remaining = remaining - count
		end
	end
	if #purchases == 0 then
		return
	end
	local order = {}
	ordered = order
	if buyButton then
		buyButton:SetEnabled(false)
	end
	C_Timer.After(ORDER_TIMEOUT, function()
		if ordered == order then
			ordered = nil
			ns.Changed("merchant")
		end
	end)
end

-- What a purchase buys, for the confirmation: the first few items by name and how many more.
local LISTED_PURCHASES = 4

---@param purchases {index: integer, count: integer}[]
---@return string
local function PurchaseList(purchases)
	local parts = {}
	for index, purchase in ipairs(purchases) do
		if index > LISTED_PURCHASES then
			parts[#parts + 1] = string.format(L["%d more"], #purchases - LISTED_PURCHASES)
			break
		end
		local info = C_MerchantFrame.GetItemInfo(purchase.index)
		local name = info and info.name or C_Item.GetItemNameByID(GetMerchantItemID(purchase.index)) or UNKNOWN
		parts[#parts + 1] = string.format(L["%d %s"], purchase.count, name)
	end
	return table.concat(parts, ", ")
end

-- The addon's own confirmation, on the merchant's window so it goes when the merchant does. One click
-- spends gold on every missing reagent, so the player sees what and how much before anything is bought.
---@class SkillUpBuyConfirm : Frame
---@field Text FontString
---@field Accept Button
---@field Cancel Button
---@field cost number?
---@type SkillUpBuyConfirm?
local confirm

local function HideConfirm()
	if confirm then
		confirm.cost = nil
		confirm:Hide()
	end
end

---@return SkillUpBuyConfirm
local function Confirm()
	if confirm then
		return confirm
	end
	local frame = CreateFrame("Frame", nil, MerchantFrame) --[[@as SkillUpBuyConfirm]]
	frame:SetSize(320, 112)
	frame:SetPoint("TOP", MerchantFrame, "TOP", 0, -72)
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	CreateFrame("Frame", nil, frame, "DialogBorderOpaqueTemplate"):SetAllPoints()
	frame.Text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	frame.Text:SetPoint("TOPLEFT", 20, -18)
	frame.Text:SetPoint("TOPRIGHT", -20, -18)
	frame.Text:SetJustifyH("CENTER")
	frame.Accept = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate") --[[@as Button]]
	frame.Accept:SetSize(110, 22)
	frame.Accept:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -4, 16)
	frame.Accept:SetText(L["Buy"])
	frame.Accept:SetScript("OnClick", function()
		local cost = frame.cost
		HideConfirm()
		if cost then
			BuyMissing(cost)
		end
	end)
	frame.Cancel = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate") --[[@as Button]]
	frame.Cancel:SetSize(110, 22)
	frame.Cancel:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 4, 16)
	frame.Cancel:SetText(L["Cancel"])
	frame.Cancel:SetScript("OnClick", HideConfirm)
	frame:Hide()
	confirm = frame
	return frame
end

-- The button asks first: what it would buy here and what that costs.
local function AskToBuy()
	if ordered then
		return
	end
	local purchases, cost = MerchantPurchases()
	if #purchases == 0 then
		return
	end
	local frame = Confirm()
	frame.cost = cost
	frame.Text:SetText(
		string.format(L["Buy %s for %s?"], PurchaseList(purchases), C_CurrencyInfo.GetCoinTextureString(cost))
	)
	frame:Show()
end

local function RefreshBuyButton()
	local purchases, cost = {}, 0
	if ns.db.merchantButton and MerchantFrame and MerchantFrame:IsShown() then
		purchases, cost = MerchantPurchases()
	end
	-- Whatever the player agreed to is out of date once the merchant, the bags or the route change.
	if confirm and confirm.cost ~= cost then
		HideConfirm()
	end
	if #purchases == 0 then
		if buyButton then
			buyButton:Hide()
		end
		return
	end
	if not buyButton then
		buyButton = CreateFrame("Button", nil, MerchantFrame, "SharedButtonSmallTemplate") --[[@as Button]]
		buyButton:SetPoint("BOTTOMRIGHT", MerchantFrame, "TOPRIGHT", 0, 2)
		buyButton:SetScript("OnClick", AskToBuy)
	end
	buyButton:SetText(string.format(L["Buy tracked reagents  %s"], C_CurrencyInfo.GetCoinTextureString(cost)))
	buyButton:SetSize(buyButton:GetTextWidth() + 32, 22)
	buyButton:SetEnabled(not ordered)
	buyButton:Show()
end

---@return boolean
function ns.TrackerAttached()
	return module ~= nil and not detached and ForeverTrackerHost ~= nil and ForeverTrackerHost.IsAttached(module)
end

local function RefreshTracker()
	SyncAuctionator()
	if module then
		module:MarkDirty()
	end
	RefreshBuyButton()
end

---@param skillLine integer
---@param tracked boolean
function ns.SetTracked(skillLine, tracked)
	-- false is kept, not dropped: it is the player saying stop, which AutoTrack honours.
	ns.db.trackedProfessions[skillLine] = tracked
	PlaySound(tracked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
	ns.Changed("tracking")
end

---@type fun()
local Attach

---@param target SkillUpTrackerModule
---@param container Frame
local function SetContainer(target, container)
	---@diagnostic disable-next-line: undefined-field
	target:SetContainer(container)
end

-- Where the section hangs right now. The shared host and Blizzard's tracker
-- both replace frames during a layout, so this is read on every use, never cached.
---@return Frame?
local function Anchor()
	if not module then
		return nil
	end
	local parent = module:GetParent()
	local host = ForeverTrackerHost
	if host and host.Attach then
		if not parent or (host.IsAttached and not host.IsAttached(module)) then
			host.Attach(module)
			parent = module:GetParent()
		end
	elseif not parent then
		Attach()
		parent = module and module:GetParent()
	end
	local native = ObjectiveTrackerFrame
	if native and parent == native.Header then
		-- Blizzard recreates the heading frame as it lays out All Objectives, so a
		-- point on that copy is a dead point. Fall back to the host or the tracker.
		if host and host.Attach then
			host.Attach(module)
		elseif module then
			SetContainer(module, native)
		end
		parent = module and module:GetParent()
	end
	return parent
end

---@return boolean
local function AnchorAvailable()
	local parent = Anchor()
	return parent ~= nil and not (parent.GetPoint and not parent:GetPoint())
end

local function Detach()
	detached = true
	if module then
		module:Hide()
	end
end

Attach = function()
	if not module or detached then
		return
	end
	local host = ForeverTrackerHost
	if host and host.Attach then
		host.Attach(module)
		return
	end
	-- No shared host yet: the template's own container layout places the section,
	-- rather than reserving a uiOrder above Blizzard's sections.
	if ObjectiveTrackerFrame then
		SetContainer(module, ObjectiveTrackerFrame)
	end
end

---@class SkillUpModuleMixin : SkillUpTrackerModule
local ModuleMixin = { headerText = L["Profession reagents"] }

---@param block SkillUpTrackerBlock
function ModuleMixin:OnBlockHeaderClick(block)
	MenuUtil.CreateContextMenu(self:GetContextMenuParent(), function(_, root)
		root:CreateTitle(block.profession)
		-- Only while this profession is open: the client crafts from the open one.
		local craft = ns.NextCraft(block.plan)
		if craft.recipeID then
			root:CreateButton(craft.text, function()
				C_TradeSkillUI.CraftRecipe(craft.recipeID, craft.count)
			end)
		end
		-- The layout picked by straight line; a click ranks by travel time.
		local first = block.steps[1]
		local npc = first and first.nearest()
		if npc then
			local label = first.book and string.format(L["Waypoint to a vendor: %s"], first.book)
				or first.quest and string.format(L["Waypoint to the quest giver: %s"], first.quest)
				or L["Waypoint to a trainer"]
			root:CreateButton(label, function()
				ns.SetWaypoint((first.nearest(true)) or npc)
			end)
		end
		for _, item in ipairs(block.vendorMissing) do
			root:CreateButton(string.format(L["Waypoint to a vendor: %s"], item.name), function()
				ns.SetWaypoint(ns.NearestVendor(item.itemID, true) or item.vendor)
			end)
		end
		-- Recipes left out with Not this recipe on the route page, each with Show again.
		local pinned = #ns.PinnedRecipes(block.id)
		if pinned > 0 then
			ns.AddPinnedMenu(root:CreateButton(string.format(L["Pinned (%d)"], pinned)), block.id)
		end
		local skipped = #ns.SkippedRecipes(block.id)
		if skipped > 0 then
			ns.AddSkippedMenu(root:CreateButton(string.format(L["Skipped (%d)"], skipped)), block.id)
		end
		root:CreateButton(L["Stop tracking"], function()
			ns.SetTracked(block.id, false)
		end)
	end)
end

-- The template from Shopping.xml: a line that takes the mouse.
local LINE_TEMPLATE = "SkillUpForeverTrackerLineTemplate"

-- A left click on the line sets a waypoint to the NPC `nearest` picks, by travel
-- time, and hovering names it. Picked when used, never while the tracker redraws.
---@param line Frame
---@param title string
---@param label string
---@param nearest fun(): integer?
---@param quest? boolean an Artisan quest step
local function Waypointed(line, title, label, nearest, quest)
	line:SetScript("OnMouseUp", function(_, button)
		local npcID = button == "LeftButton" and nearest()
		if npcID then
			ns.SetWaypoint(npcID)
		end
	end)
	line:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip_SetTitle(GameTooltip, title)
		ns.AddNearest(GameTooltip, label, nearest())
		if quest then
			ns.AddQuestChainHint(GameTooltip)
		end
		GameTooltip:Show()
	end)
	line:SetScript("OnLeave", GameTooltip_Hide)
end

-- The ranks and recipes to train, in the order the route page lists them, each with where to go for it:
-- a trainer, or the vendor of a rank's book.
---@param plan SkillUpPlan
---@return SkillUpTrackerStep[]
local function TrainingSteps(plan)
	local steps = {}
	local profession = plan.profession
	for _, step in ipairs(plan.steps) do
		local rank, training = step.rank, step.training
		if rank then
			steps[#steps + 1] = {
				text = ns.RankText(rank),
				book = rank.book and ns.RankBookName(rank),
				quest = rank.quest and ns.RankQuestName(rank),
				nearest = function(byTravel)
					return ns.NearestForRank(profession, rank, byTravel)
				end,
			}
		elseif training then
			local name = C_Spell.GetSpellName(training.recipeID) or string.format(L["recipe %d"], training.recipeID)
			steps[#steps + 1] = {
				text = string.format(L["Train %s at %d"], name, training.usedAt),
				nearest = function(byTravel)
					return ns.NearestTrainer(profession, training.cap, byTravel), L["Nearest trainer"]
				end,
			}
		end
	end
	return steps
end

-- Compact, quest style, under "Tailoring to 125": the next thing to train, then
-- only the reagents still missing, as "12/20 Linen Cloth". The page has the rest.
---@param self SkillUpTrackerModule
---@param entry SkillUpTracked
---@return boolean
local function LayoutEntry(self, entry)
	local plan = entry.plan
	local info = plan.profession
	local block = self:GetBlock(info.skillLine)
	block.profession, block.items = info.name, entry.items
	block.vendorMissing, block.plan = {}, plan
	block:SetHeader(string.format(L["%s to %d"], info.name, plan.target))
	local steps = TrainingSteps(plan)
	block.steps = steps
	if #steps > 0 then
		local more = #steps > 1 and string.format(" |cff808080(%s)|r", string.format(L["+%d more"], #steps - 1)) or ""
		local first = steps[1]
		local npc, label = first.nearest()
		local line = block:AddObjective("Train", first.text .. more, npc and LINE_TEMPLATE or nil)
		if npc then
			Waypointed(line, first.text, label, function()
				return (first.nearest(true))
			end, first.quest and true)
		end
	end
	local shown = 0
	for _, item in ipairs(entry.items) do
		local have = ns.Have(item.itemID)
		if have < item.need then
			if shown == MAX_OBJECTIVES then
				block:AddObjective("Extra", "...", nil, nil, OBJECTIVE_DASH_STYLE_HIDE)
				break
			end
			shown = shown + 1
			local name = C_Item.GetItemNameByID(item.itemID)
			if not name then
				C_Item.RequestLoadItemDataByID(item.itemID)
				name = string.format(L["item %d"], item.itemID)
			end
			local gather = item.source == "gather" and string.format(" |cff808080(%s)|r", L["gather"]) or ""
			local vendor = item.source == "vendor" and ns.NearestVendor(item.itemID)
			local text = string.format("%d/%d %s%s", have, item.need, name, gather)
			local line = block:AddObjective(item.itemID, text, vendor and LINE_TEMPLATE or nil)
			if vendor then
				local itemID = item.itemID
				Waypointed(line, name, L["Nearest vendor"], function()
					return ns.NearestVendor(itemID, true)
				end)
				block.vendorMissing[#block.vendorMissing + 1] = { name = name, itemID = item.itemID, vendor = vendor }
			end
		end
	end
	local blocked = ns.RouteBlocked(plan)
	if blocked then
		block:AddObjective("Blocked", blocked)
	elseif shown == 0 then
		block:AddObjective("Ready", L["Reagents in hand"], nil, nil, nil, OBJECTIVE_TRACKER_COLOR.Complete)
	end
	return self:LayoutBlock(block)
end

function ModuleMixin:LayoutContents()
	if not ns.db.showTracker or detached then
		return
	end
	for _, entry in ipairs(ns.TrackedNeeds()) do
		if not AnchorAvailable() then
			ns.Print(L["couldn't add tracked reagents to the objective tracker; please report it."])
			Detach()
			return
		end
		local ok, keep = pcall(LayoutEntry, self, entry)
		if not ok then
			ns.Print(L["couldn't add tracked reagents to the objective tracker; please report it."])
			Detach()
			return
		end
		if not keep then
			return
		end
	end
end

local function CreateModule()
	if not ObjectiveTrackerFrame then
		ns.Print(L["the objective tracker isn't available, so tracked reagents can't be shown."])
		return
	end
	local hostFrame = ForeverTrackerHost --[[@as Frame?]]
	local parent = hostFrame and type(hostFrame.GetParent) == "function" and hostFrame or UIParent
	local created = CreateFrame("Frame", "SkillUpForeverObjectiveTracker", parent, "ObjectiveTrackerModuleTemplate")
	---@cast created SkillUpTrackerModule
	module = created
	Mixin(module, ModuleMixin)
	module:SetHeader(ModuleMixin.headerText)
	-- No uiOrder: the shared host owns the section's place and the template lays
	-- it out when the host is missing.
	EventUtil.ContinueAfterAllEvents(function()
		C_Timer.After(0, function()
			Attach()
			-- A fresh session writes each tracked route's Auctionator list once.
			SyncAuctionator()
		end)
	end, "PLAYER_ENTERING_WORLD", "VARIABLES_LOADED")
	Attach()
	C_Timer.After(5, function()
		if not ns.TrackerAttached() then
			ns.Print(L["couldn't add tracked reagents to the objective tracker; please report it."])
		end
	end)
end

function ns.InitShopping()
	CreateModule()
	ns.WhenStale("tracker", RefreshTracker)
	-- The order arrived, or its merchant is gone: the refresh these events bring offers the button again.
	local function OrderSettled()
		ordered = nil
	end
	ns.WhenEvent("BAG_UPDATE_DELAYED", OrderSettled)
	ns.WhenEvent("MERCHANT_CLOSED", OrderSettled)
end
