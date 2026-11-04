---@type string, SkillUpNamespace
local _, ns = ...
local L = ns.L

---@type SkillUpRecipeList
local recipeList

-- The row's own Init sized the label for Blizzard's right-hand widgets only;
-- shrink it again so a long recipe name truncates instead of running under our text.
---@param row SkillUpRecipeRow
---@param text FontString
local function FitLabel(row, text)
	local count = row.Count:IsShown() and row.Count:GetStringWidth() or 0
	local locked = row.LockedIcon:IsShown() and row.LockedIcon:GetWidth() + 2 or 0
	local available = row:GetWidth() - row.SkillUps:GetWidth() - count - locked - text:GetStringWidth() - 14
	if row.Label:GetWidth() > available then
		row.Label:SetWidth(math.max(available, 40))
	end
end

---@param _ SkillUpNamespace
---@param row SkillUpRecipeRow
---@param node SkillUpTreeNode
local function DecorateRow(_, row, node)
	local data = node and node:GetData()
	if not data then
		return
	end
	local info = data.recipeInfo
	if not info then
		return
	end

	local text = row.SkillUpText
	if not text then
		text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight_NoShadow")
		text:SetJustifyH("RIGHT")
		row.SkillUpText = text
	end
	if not ns.db.showRowText then
		text:Hide()
		return
	end

	local recipeInfo = Professions.GetHighestLearnedRecipe(info) or info
	local d = ns.Describe(recipeInfo, ns.SkillContext())
	text:ClearAllPoints()
	if row.LockedIcon:IsShown() then
		text:SetPoint("RIGHT", row.LockedIcon, "LEFT", -2, 0)
	else
		text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	end
	text:SetText(ns.FormatRow(d))
	text:SetTextColor(ns.RowColor(d):GetRGB())
	text:Show()
	FitLabel(row, text)
end

---@type table<string, SkillUpSortKey>
local SORT_KEYS = {
	skill = function(recipeInfo)
		local t = ns.Model.Get(recipeInfo.recipeID)
		return t and t[1] or math.huge
	end,
	chance = function(recipeInfo, ctx)
		local chance = ns.Describe(recipeInfo, ctx).chance
		return chance and -chance or math.huge
	end,
	cost = function(recipeInfo, ctx)
		return ns.Describe(recipeInfo, ctx).perSkillUp or math.huge
	end,
}

-- Forever's categories hold one or two recipes each, so sorting inside them changes
-- nothing. A sort instead flattens the list: learned recipes, then unlearned ones.
local replacing = false

---@param node SkillUpTreeNode
---@param learned TradeSkillRecipeInfo[]
---@param unlearned TradeSkillRecipeInfo[]
---@param seen table<integer, boolean>
local function CollectRecipes(node, learned, unlearned, seen)
	for _, child in ipairs(node:GetNodes()) do
		local info = child:GetData().recipeInfo
		if not info then
			CollectRecipes(child, learned, unlearned, seen)
		elseif not info.favoritesInstance and not seen[info.recipeID] then
			seen[info.recipeID] = true
			local list = info.learned and learned or unlearned
			list[#list + 1] = info
		end
	end
end

---@param list TradeSkillRecipeInfo[]
---@param key SkillUpSortKey
---@param ctx SkillUpContext?
local function SortRecipes(list, key, ctx)
	local keys = {}
	for _, info in ipairs(list) do
		keys[info] = key(info, ctx)
	end
	table.sort(list, function(a, b)
		if keys[a] ~= keys[b] then
			return keys[a] < keys[b]
		end
		return strcmputf8i(a.name, b.name) < 0
	end)
end

---@param source SkillUpTreeProvider
---@param key SkillUpSortKey
---@return SkillUpTreeProvider
local function BuildSorted(source, key)
	local ctx = ns.SkillContext()
	local learned, unlearned = {}, {}
	CollectRecipes(source:GetRootNode(), learned, unlearned, {})
	SortRecipes(learned, key, ctx)
	SortRecipes(unlearned, key, ctx)

	local sorted = CreateTreeDataProvider()
	for _, info in ipairs(learned) do
		sorted:Insert({ recipeInfo = info })
	end
	-- Blizzard's divider template draws the "Unlearned" label itself.
	if #unlearned > 0 then
		sorted:Insert({ isDivider = true, dividerHeight = #learned > 0 and 70 or 30 })
		for _, info in ipairs(unlearned) do
			sorted:Insert({ recipeInfo = info })
		end
	end
	return sorted
end

---@param scrollBox SkillUpRecipeScrollBox
local function ApplySort(scrollBox)
	local key = SORT_KEYS[ns.db.sortMode]
	local source = scrollBox:GetDataProvider()
	if replacing or not key or not source or not source.GetRootNode then
		return
	end
	local ok, sorted = pcall(BuildSorted, source, key)
	if not ok then
		ns.SetSortMode("blizzard")
		ns.Print(string.format(L["sorting failed and has been turned off: %s"], tostring(sorted)))
		return
	end
	replacing = true
	scrollBox:SetDataProvider(sorted, ScrollBoxConstants.RetainScrollPosition)
	replacing = false
end

-- A "Sort by" section at the bottom of Blizzard's own Filter menu. The same menu
-- serves other recipe lists, so only the crafting page's dropdown gets it.
---@param owner Region
---@param rootDescription RootMenuDescriptionProxy
local function AddFilterMenu(owner, rootDescription)
	if owner ~= recipeList.FilterDropdown then
		return
	end
	rootDescription:CreateDivider()
	rootDescription:CreateTitle(L["Sort by"])
	for _, option in ipairs(ns.SORT_OPTIONS) do
		rootDescription:CreateRadio(option[2], function(mode)
			return ns.db.sortMode == mode
		end, function(mode)
			ns.SetSortMode(mode)
			return MenuResponse.Refresh
		end, option[1])
	end
end

function ns.AttachRecipeList()
	recipeList = ProfessionsFrame.CraftingPage.RecipeList
	-- No iterateExisting: it calls back as (frame, data), not (owner, frame, data),
	-- and the list is still empty when Blizzard_Professions finishes loading.
	ScrollUtil.AddInitializedFrameCallback(recipeList.ScrollBox, DecorateRow, ns)
	recipeList.ScrollBox:RegisterCallback("OnDataProviderReassigned", ApplySort, recipeList.ScrollBox)
	EventRegistry:RegisterCallback("Professions.RecipeListOnEnter", ns.ShowRecipeTooltip, ns)
	Menu.ModifyMenu("MENU_PROFESSIONS_FILTER", AddFilterMenu)
	-- Rebuilding through the crafting page re-runs Blizzard's provider, which our
	-- data-provider callback then re-sorts.
	ns.WhenStale("recipeList", function()
		if recipeList:IsVisible() and ProfessionsFrame.professionInfo then
			ProfessionsFrame.CraftingPage:Init(ProfessionsFrame.professionInfo)
		end
	end)
	ns.AttachRoute()
	ns.AttachGear()
	ns.AttachAuctionSearch()
	ns.AttachDetailsBar()
end
