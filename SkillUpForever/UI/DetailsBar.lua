---@type string, SkillUpNamespace
local _, ns = ...

-- The recipe tooltip's skill bar on the crafting page itself (#172): the selected recipe's orange, yellow, green
-- and grey thresholds with the pip at your skill, just under the recipe, instead of only on the hover. It draws
-- the tooltip's own bar (ns.CreateSkillBar and ns.LayoutSkillBar) from the same numbers.

-- The bar's TOPLEFT below the details pane's TOPLEFT: under the recipe's name and description, inset from the
-- card's art. The frame is the bar's own height, so its labels stay off the reagents beneath it.
local DETAILS_BAR_TOP = -76

---@class SkillUpDetailsBar : Frame
---@field bar SkillUpBar

---@type SkillUpDetailsBar?
local frame
---@type integer?
local recipeID

-- What the bar draws for a recipe at a skill: its four thresholds and where the player's skill sits on them.
-- Nothing without thresholds, a skill to place, or all four numbers.
---@param t number[]?
---@param skill number?
---@return number[]? thresholds
---@return number? skill
function ns.DetailsBar(t, skill)
	if not t or not skill or not t[1] or not t[2] or not t[3] or not t[4] then
		return nil
	end
	return t, skill
end

-- The recipe whose bar is drawn: the highest learned version of the selected one, as the recipe tooltip draws it.
---@param info TradeSkillRecipeInfo?
---@return integer?
function ns.DetailsBarRecipe(info)
	local recipeInfo = info and (Professions.GetHighestLearnedRecipe(info) or info)
	return recipeInfo and recipeInfo.recipeID or nil
end

local function Refresh()
	if not frame then
		return
	end
	local ctx = ns.SkillContext()
	local t, skill = ns.DetailsBar(recipeID and ns.Model.Get(recipeID), ctx and ctx.skill)
	if t and skill and ns.db.detailsBar then
		ns.LayoutSkillBar(frame.bar, t, skill)
	end
	frame:SetShown(t ~= nil and ns.db.detailsBar)
end

-- The window's selection is kept even while the bar is hidden, so turning the setting back on draws it again.
---@param _ Frame
---@param info TradeSkillRecipeInfo?
local function OnRecipeSelected(_, info)
	recipeID = ns.DetailsBarRecipe(info)
	Refresh()
end

-- The bar is our own frame, parented to the crafting page and anchored to the details pane: nothing of the
-- pane's own points, scripts or callbacks is touched, so it stays safe in combat and through Create All.
function ns.AttachDetailsBar()
	local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
	local form = page and page.SchematicForm
	if frame or not form then
		return
	end
	local details = CreateFrame("Frame", nil, page) --[[@as SkillUpDetailsBar]]
	details:SetSize(250, 60)
	details:SetPoint("TOPLEFT", form, "TOPLEFT", 28, DETAILS_BAR_TOP)
	details.bar = ns.LayoutSkillBar(ns.CreateSkillBar(), { 1, 26, 41, 56 }, 1)
	details.bar:SetParent(details)
	details.bar:ClearAllPoints()
	details.bar:SetPoint("TOPLEFT", details, "TOPLEFT")
	details:Hide()
	frame = details
	EventRegistry:RegisterCallback("ProfessionsRecipeListMixin.Event.OnRecipeSelected", OnRecipeSelected, details)
	local info = form.GetRecipeInfo and form:GetRecipeInfo()
	OnRecipeSelected(details, info)
	ns.WhenStale("detailsBar", Refresh)
	-- A reopened window draws the profession it opens with once Blizzard has chosen its recipe.
	ns.WhenEvent("TRADE_SKILL_SHOW", function()
		C_Timer.After(0, Refresh)
	end)
end
