local _, FLT = ...
-- Item API: newer clients only have these under C_Item.
local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)
local GetItemCount = GetItemCount or (C_Item and C_Item.GetItemCount)
local GetItemIcon = GetItemIcon or (C_Item and C_Item.GetItemIconByID)
local UI = FLT.UI
local unpack = unpack or table.unpack
local makeTexture, makeButton = UI.makeTexture, UI.makeButton

-- "All recipes" browser for the Professions tab (beta). Data: Data/Professions/*.lua
-- (extracted from the Forever client database). Known recipes and the current
-- skill are read from the profession window and stored per character in
-- OneForAllCharDB.professions[profession] = { skill, maxSkill, known = {spellID=true} }.

local GOLD = {1, 0.82, 0.20}
local DIFF = {
  orange = {1.00, 0.50, 0.25}, yellow = {1.00, 1.00, 0.00},
  green  = {0.25, 0.75, 0.25}, gray   = {0.55, 0.55, 0.55},
  red    = {0.90, 0.25, 0.25},
}
local QCOL = { [0]={0.62,0.62,0.62}, [1]={1,1,1}, [2]={0.12,1,0}, [3]={0,0.44,0.87}, [4]={0.64,0.21,0.93}, [5]={1,0.5,0} }

-- ---------------------------------------------------------------------------
-- Character data (skill + known recipes)
-- ---------------------------------------------------------------------------
local function profDB(prof)
  if type(OneForAllCharDB) ~= "table" then return {known = {}} end
  OneForAllCharDB.professions = OneForAllCharDB.professions or {}
  local p = OneForAllCharDB.professions[prof]
  if not p then p = {known = {}}; OneForAllCharDB.professions[prof] = p end
  p.known = p.known or {}
  return p
end
FLT.GetProfessionState = profDB

-- Favourite recipes (account wide): OneForAllDB.recipeFavorites[prof][spell]
local function favDB(prof, create)
  if type(OneForAllDB) ~= "table" then return nil end
  OneForAllDB.recipeFavorites = OneForAllDB.recipeFavorites or {}
  local t = OneForAllDB.recipeFavorites[prof]
  if not t and create then t = {}; OneForAllDB.recipeFavorites[prof] = t end
  return t
end
local function isFavorite(prof, spell) local t = favDB(prof); return t and t[spell] and true or false end
local function setFavorite(prof, spell, on) local t = favDB(prof, true); if t then t[spell] = on and true or nil end end
FLT.IsRecipeFavorite = isFavorite

local SKILL_LINE_PROF = {
  [171] = "Alchemy", [197] = "Tailoring", [164] = "Blacksmithing", [165] = "Leatherworking",
  [202] = "Engineering", [333] = "Enchanting", [185] = "Cooking", [129] = "First Aid",
}
local function profFromName(name, skillLine)
  local recipes = FLT.PROFESSION_RECIPES or {}
  if skillLine and SKILL_LINE_PROF[skillLine] and recipes[SKILL_LINE_PROF[skillLine]] then return SKILL_LINE_PROF[skillLine] end
  if name and recipes[name] then return name end
  return nil
end

-- calls fn(prof, rank, maxRank) for every profession the character has; returns true if a list was readable
local function eachOwnProfession(fn)
  local any = false
  -- Old skill list API
  if GetNumSkillLines and GetSkillLineInfo then
    any = true
    for i = 1, GetNumSkillLines() or 0 do
      local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
      local prof = not isHeader and profFromName(name)
      if prof and rank then fn(prof, rank, maxRank) end
    end
  end
  -- Modern profession API (profession book)
  if GetProfessions and GetProfessionInfo then
    any = true
    local list = {GetProfessions()}
    for k = 1, 6 do
      local idx = list[k]
      if idx then
        local ok, name, _, rank, maxRank, _, _, skillLine = pcall(GetProfessionInfo, idx)
        local prof = ok and profFromName(name, skillLine)
        if prof and rank then fn(prof, rank, maxRank) end
      end
    end
  end
  return any
end
local function readSkillLines()
  eachOwnProfession(function(prof, rank, maxRank) local p = profDB(prof); p.skill = rank; p.maxSkill = maxRank end)
end

local browser -- set when created; refreshed after scans
-- the browser holds the secure craft buttons (RecipeBar): resizing it in combat is blocked (ADDON_ACTION_BLOCKED
-- SetHeight, user 27.10.: SKILL_LINES_CHANGED from a weapon skill-up in combat) -> wait for the end of combat
local refreshAfterCombat
local function refreshBrowser(onlyShown)
  if not (browser and browser.Refresh) or (onlyShown and not browser:IsShown()) then return end
  if InCombatLockdown and InCombatLockdown() then
    if not refreshAfterCombat then
      refreshAfterCombat = CreateFrame("Frame")
      refreshAfterCombat:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); refreshBrowser(true) end)
    end
    refreshAfterCombat:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  browser:Refresh(true)
end
local lastScan = {}

-- Which of our professions does a set of recipe spell IDs belong to?
local function profFromSpells(spells)
  local spellProf = FLT._spellProf
  if not spellProf then
    spellProf = {}
    for prof, list in pairs(FLT.PROFESSION_RECIPES or {}) do
      for _, r in ipairs(list) do spellProf[r.s] = prof end
    end
    FLT._spellProf = spellProf
  end
  local count, best, bestN = {}, nil, 0
  for _, s in ipairs(spells) do
    local pr = spellProf[s]
    if pr then count[pr] = (count[pr] or 0) + 1; if count[pr] > bestN then best, bestN = pr, count[pr] end end
  end
  return best
end

-- Removes stored "known" recipes that need far more skill than the character
-- has (wrong entries written by 4.18.0). Learn level, or yellow - 50.
local function cleanImplausible(prof)
  local list = FLT.PROFESSION_RECIPES and FLT.PROFESSION_RECIPES[prof]
  if not list or type(OneForAllCharDB) ~= "table" or type(OneForAllCharDB.professions) ~= "table" then return end
  local p = OneForAllCharDB.professions[prof]
  if not (p and p.known and p.skill) then return end
  for _, r in ipairs(list) do
    if p.known[r.s] then
      local need = r.req or ((r.y and r.y > 0) and (r.y - 50)) or 0
      if need > p.skill then p.known[r.s] = nil end
    end
  end
end
local function cleanAllProfessions()
  for prof in pairs(FLT.PROFESSION_RECIPES or {}) do cleanImplausible(prof) end
end

-- The trade skill window can also show someone else's recipes: a profession link from chat, a guild
-- member's profession or an NPC crafter. Those must not be stored as our own (bug report 16.10.:
-- a linked Enchanting 225 showed up as known until the own window was opened again).
local function call(fn) if type(fn) ~= "function" then return nil end local ok, v = pcall(fn); return ok and v end
local function foreignTradeSkill()
  local T = C_TradeSkillUI
  if T and (call(T.IsTradeSkillLinked) or call(T.IsTradeSkillGuild) or call(T.IsTradeSkillGuildMember) or call(T.IsNPCCrafting)) then
    return true
  end
  return call(IsTradeSkillLinked) or call(IsTradeSkillGuild) or false
end

local function scanTradeSkill()
  if foreignTradeSkill() then lastScan = {foreign = true}; return end
  local prof, rank, maxRank, hint
  local known = {}
  local fullList = false -- the new API lists every recipe, independent of the window's filters
  local stats = {ids = 0, yes = 0, no = 0, noField = 0, noInfo = 0}

  -- New profession window (C_TradeSkillUI)
  local T = C_TradeSkillUI
  if T and T.GetAllRecipeIDs then
    local ok, ids = pcall(T.GetAllRecipeIDs)
    if ok and type(ids) == "table" and #ids > 0 then
      -- GetAllRecipeIDs also returns recipes the character has NOT learned yet;
      -- only recipes whose info says learned = true count as known.
      local infos, anyField = {}, false
      for _, id in ipairs(ids) do
        stats.ids = stats.ids + 1
        local info
        if T.GetRecipeInfo then
          local ok2, i2 = pcall(T.GetRecipeInfo, id)
          if ok2 and type(i2) == "table" then info = i2 end
        end
        infos[id] = info or false
        if info and info.learned ~= nil then anyField = true end
      end
      for _, id in ipairs(ids) do
        local info = infos[id]
        if not info then stats.noInfo = stats.noInfo + 1
        elseif info.learned == true then stats.yes = stats.yes + 1; known[#known + 1] = id
        elseif info.learned == false then stats.no = stats.no + 1
        else
          stats.noField = stats.noField + 1
          -- no learned flag yet: the recipe data is still loading - don't guess
          -- (an early scan like this caused the wrong checks in 4.18.0)
        end
      end
      fullList = anyField
    end
    if T.GetBaseProfessionInfo then
      local ok3, info = pcall(T.GetBaseProfessionInfo)
      if ok3 and type(info) == "table" then
        hint = profFromName(info.professionName, info.professionID)
        rank, maxRank = info.skillLevel, info.maxSkillLevel
        if (not rank or rank == 0) and T.GetProfessionInfoBySkillLineID and info.professionID then
          local ok4, i2 = pcall(T.GetProfessionInfoBySkillLineID, info.professionID)
          if ok4 and type(i2) == "table" then rank, maxRank = i2.skillLevel, i2.maxSkillLevel end
        end
      end
    end
    if not hint and T.GetTradeSkillLine then
      local ok5, a, b, c, d = pcall(T.GetTradeSkillLine)
      if ok5 then
        if type(a) == "number" then hint = profFromName(b, a); rank, maxRank = rank or c, maxRank or d
        else hint = profFromName(a); rank, maxRank = rank or b, maxRank or c end
      end
    end
  end

  -- Old trade skill window
  if GetTradeSkillLine then
    local n, r, m = GetTradeSkillLine()
    if n and n ~= "UNKNOWN" then hint = hint or profFromName(n); rank, maxRank = rank or r, maxRank or m end
  end
  local itemLinks = {}
  if GetNumTradeSkills and GetTradeSkillInfo then
    for i = 1, GetNumTradeSkills() or 0 do
      local _, kind = GetTradeSkillInfo(i)
      if kind and kind ~= "header" and kind ~= "subheader" then
        local spell
        if GetTradeSkillRecipeLink then
          local link = GetTradeSkillRecipeLink(i)
          spell = link and tonumber(link:match("enchant:(%d+)") or link:match("spell:(%d+)"))
        end
        if spell then known[#known + 1] = spell
        elseif GetTradeSkillItemLink then
          local link = GetTradeSkillItemLink(i)
          local item = link and tonumber(link:match("item:(%d+)"))
          if item then itemLinks[#itemLinks + 1] = item end
        end
      end
    end
  end

  prof = hint or profFromSpells(known)
  if not prof then
    -- maybe only item links: match by crafted item
    for p, list in pairs(FLT.PROFESSION_RECIPES or {}) do
      local byItem = {}
      for _, r in ipairs(list) do if r.i then byItem[r.i] = r.s end end
      for _, it in ipairs(itemLinks) do if byItem[it] then prof = p; break end end
      if prof then break end
    end
  end
  if not prof then lastScan = {count = #known, items = #itemLinks}; return end
  -- second guard: the window shows a profession we don't have, or a different skill than ours
  do
    local own
    local readable = eachOwnProfession(function(p2, r2) if p2 == prof then own = r2 end end)
    if readable and (own == nil or (rank and rank > 0 and own ~= rank)) then lastScan = {foreign = true, prof = prof}; return end
  end

  local p = profDB(prof)
  if rank and rank > 0 then p.skill, p.maxSkill = rank, maxRank end
  local skillNow = (rank and rank > 0) and rank or p.skill
  -- Plausibility: a recipe can't be known when it needs far more skill than
  -- the character has (learn level, or yellow - 50 when the learn level is unknown).
  local recipeBySpell, byItem = {}, {}
  for _, r in ipairs(FLT.PROFESSION_RECIPES[prof]) do recipeBySpell[r.s] = r; if r.i then byItem[r.i] = r.s end end
  local function plausible(r)
    if not skillNow then return true end
    if r.req then return r.req <= skillNow end
    if r.y and r.y > 0 then return r.y - 50 <= skillNow end
    return true
  end
  -- a complete list from the new API replaces what was stored (removes wrong entries)
  if fullList then wipe(p.known) end
  local n = 0
  for _, s in ipairs(known) do local r = recipeBySpell[s]; if r and plausible(r) then p.known[s] = true; n = n + 1 end end
  for _, it in ipairs(itemLinks) do local r = recipeBySpell[byItem[it]]; if r and plausible(r) then p.known[r.s] = true; n = n + 1 end end
  -- also drop implausible entries stored by older versions
  for s in pairs(p.known) do local r = recipeBySpell[s]; if r and not plausible(r) then p.known[s] = nil end end
  p.scanned = true
  lastScan = {prof = prof, count = #known, matched = n, skill = rank, stats = stats}
  readSkillLines()
  if FLT.OnProfessionScan then FLT.OnProfessionScan() end
  refreshBrowser()
end

FLT.RefreshRecipeBrowser = function()
  refreshBrowser(true)
end

local scanPending = false
local function scanSoon()
  if scanPending then return end
  if C_Timer and C_Timer.After then
    scanPending = true
    C_Timer.After(0.5, function() scanPending = false; scanTradeSkill() end)
  else
    scanTradeSkill()
  end
end

FLT.ScanProfessions = function()
  readSkillLines(); scanTradeSkill()
  local T = C_TradeSkillUI
  return {
    newAPI = (T and T.GetAllRecipeIDs) and true or false,
    oldAPI = (GetNumTradeSkills and GetTradeSkillInfo) and true or false,
    profAPI = (GetProfessions and GetProfessionInfo) and true or false,
    last = lastScan,
  }
end

do
  local ev = CreateFrame("Frame")
  for _, e in ipairs({"TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED",
                      "NEW_RECIPE_LEARNED", "SKILL_LINES_CHANGED", "PLAYER_LOGIN"}) do pcall(ev.RegisterEvent, ev, e) end
  ev:SetScript("OnEvent", function(_, event)
    if event == "SKILL_LINES_CHANGED" or event == "PLAYER_LOGIN" then
      readSkillLines(); cleanAllProfessions(); refreshBrowser(true)
    else
      scanSoon()
    end
  end)
end

-- Recipes of a profession for the player's faction (side="A"/"H" = one faction only).
local factionLists = {}
-- Sorted by the level shown in the list (learn level, or the yellow skill
-- when the learn level is unknown), then by name.
local function sortLevel(r) return r.req or r.y or 0 end
local function recipesFor(prof)
  local all = FLT.PROFESSION_RECIPES and FLT.PROFESSION_RECIPES[prof] or {}
  local fac = UnitFactionGroup and UnitFactionGroup("player")
  local side = fac == "Alliance" and "A" or fac == "Horde" and "H" or nil
  local key = prof .. (side or "-")
  if not factionLists[key] then
    local t = {}
    for _, r in ipairs(all) do if not side or not r.side or r.side == side then t[#t + 1] = r end end
    table.sort(t, function(a, b)
      local la, lb = sortLevel(a), sortLevel(b)
      if la ~= lb then return la < lb end
      if a.n ~= b.n then return a.n < b.n end
      return a.s < b.s
    end)
    factionLists[key] = t
  end
  return factionLists[key]
end

-- Difficulty of a recipe for the current skill (like the profession window).
-- Other OneForAll users who know a recipe and are online right now.
local function onlineOthers(prof, spell)
  local list = FLT.GetOtherRecipeKnowers and FLT.GetOtherRecipeKnowers(prof, spell)
  if not list then return nil end
  for _, g in ipairs(list) do if g[2] then return list end end
  return nil
end

-- Recipes a dungeon boss drops: Data\Professions\BossDrops.lua (Wowhead
-- Forever drop data) plus the drop sources stored with the recipes.
local bossIndex
local function buildBossIndex()
  bossIndex = {}
  local byItem = {}
  for prof, list in pairs(FLT.PROFESSION_RECIPES or {}) do
    for _, r in ipairs(list) do
      if r.ri and not byItem[r.ri] then byItem[r.ri] = {prof = prof, r = r} end
    end
  end
  local function add(npc, e)
    local t = bossIndex[npc]
    if not t then t = {}; bossIndex[npc] = t end
    for _, x in ipairs(t) do if x == e then return end end
    t[#t + 1] = e
  end
  for npc, items in pairs(FLT.RECIPE_BOSS_DROPS or {}) do
    for _, ri in ipairs(items) do if byItem[ri] then add(npc, byItem[ri]) end end
  end
  for _, e in pairs(byItem) do
    for _, n in ipairs((e.r.src and e.r.src.d) or {}) do if n[1] then add(n[1], e) end end
  end
  for _, t in pairs(bossIndex) do
    table.sort(t, function(a, b) if a.prof ~= b.prof then return a.prof < b.prof end return (a.r.rn or a.r.n) < (b.r.rn or b.r.n) end)
  end
end
function FLT.GetBossRecipes(npcID)
  if not npcID then return nil end
  if not bossIndex then buildBossIndex() end
  return bossIndex[npcID]
end
-- yellow / green / blue state of a recipe for other modules
function FLT.RecipeKnowState(prof, r)
  local p = profDB(prof)
  local guild = FLT.GetGuildRecipeKnowers and FLT.GetGuildRecipeKnowers(prof, r.s)
  local list = FLT.GetOtherRecipeKnowers and FLT.GetOtherRecipeKnowers(prof, r.s)
  local other = false
  for _, g in ipairs(list or {}) do if g[2] then other = true; break end end
  return p.known[r.s] and true or false, guild and true or false, other
end

local function difficulty(r, skill)
  if not skill then return nil end
  if r.req and skill < r.req then return "red" end
  if r.gr and r.gr > 0 and skill >= r.gr then return "gray" end
  if r.g and r.g > 0 and skill >= r.g then return "green" end
  if r.y and r.y > 0 and skill >= r.y then return "yellow" end
  return "orange"
end

-- chance of a skill-up for yellow and green recipes (Classic: (grey - skill) / (grey - yellow)); nil for orange,
-- grey, red or without data (6.0.1, Discord noel.puldon: the colour stays, the number is added)
local function skillUpChance(r, d, skill)
  if (d ~= "yellow" and d ~= "green") or not skill or not r.y or not r.gr or r.gr <= r.y then return nil end
  local p = math.floor((r.gr - skill) / (r.gr - r.y) * 100 + 0.5)
  return math.max(1, math.min(100, p))
end

-- how many you can make with the reagents in your bags (6.0.1-beta2, user 30.10.: "(2)" like the game's window)
local function canMake(r)
  if not r.r or #r.r == 0 or not GetItemCount then return 0 end
  local n
  for _, rg in ipairs(r.r) do
    local k = math.floor((GetItemCount(rg[1]) or 0) / math.max(1, rg[2] or 1))
    if not n or k < n then n = k end
  end
  return n or 0
end

local function itemIcon(id)
  local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or (GetItemIcon and GetItemIcon(id))
  return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end
-- Icon of a recipe: crafted item, or the spell icon for enchants.
local function recipeIcon(r)
  if r.i then return itemIcon(r.i) end
  if r.ic then return r.ic end
  local t = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(r.s)) or (GetSpellTexture and GetSpellTexture(r.s))
  return t or "Interface\\Icons\\Spell_Holy_GreaterHeal"
end
-- Shift-click: crafted item link, or the spell link for enchants.
local function linkRecipe(r, button, H)
  if r.i then
    if H and H.handleDungeonItemClick then H.handleDungeonItemClick({id = r.i, name = r.n, quality = r.q}, button or "LeftButton") end
    return
  end
  local link = (C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(r.s)) or (GetSpellLink and GetSpellLink(r.s))
  if link then
    if ChatEdit_InsertLink and ChatEdit_InsertLink(link) then return end
    if ChatFrame_OpenChat then ChatFrame_OpenChat(link) end
  end
end
FLT.RecipeIcon = recipeIcon

local function itemName(id)
  local n = GetItemInfo and GetItemInfo(id)
  if not n and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  return n
end

-- ---------------------------------------------------------------------------
-- Browser
-- ---------------------------------------------------------------------------
function UI.CreateRecipeBrowser(parent)
  local H = UI.DungeonHelpers
  local f = CreateFrame("Frame", nil, parent); f:SetAllPoints(); f:Hide()
  browser = f
  local prof, filter, search = nil, "all", ""

  local title = FLT.NewFS(f, nil, "OVERLAY", "GameFontNormalLarge")
  local profIcon = f:CreateTexture(nil, "ARTWORK"); profIcon:SetSize(40, 40); profIcon:SetPoint("TOPLEFT", 12, -6)
  title:SetPoint("TOPLEFT", 60, -8); title:SetTextColor(FLT.SkinC(unpack(GOLD)))
  local meta = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall")
  meta:SetPoint("TOPLEFT", 60, -32); meta:SetTextColor(FLT.SkinC(0.82, 0.80, 0.72))

  -- the search line of the open recipe (6.1.0): its text and "Search again" change without rebuilding the details
  local searchUI = {}
  local function updateSearchUI()
    local ui = searchUI
    if not (ui.fs and ui.r and FLT.RecipeSearchState) then return end
    local state, ago, canAgain = FLT.RecipeSearchState(prof, ui.r.s)
    local msg = ""
    if not state then msg = (ui.n or 0) > 0 and "" or "|cff9d9d9dClick Search to find players who know this recipe.|r"
    elseif state == "connecting" then msg = "|cffd0c8b0Connecting to the other OneForAll users ...|r"
    elseif state == "searching" then msg = "|cffd0c8b0Searching ...|r"
    elseif state == "limited" then msg = "|cffff9933Many searches right now - try again in 30 s.|r"
    elseif state == "done" and (ui.n or 0) == 0 then msg = "|cff9d9d9dNo current results received.|r"
    elseif state == "done" and ago then msg = string.format("|cff9d9d9dSearched %s.|r", ago < 60 and "just now" or (math.floor(ago / 60) .. " min ago"))
    end
    local wait = (state ~= "searching" and not canAgain and ago) and math.max(1, 30 - math.floor(ago)) or nil
    if wait then msg = msg .. string.format("  |cff9d9d9d(search again in %d s)|r", wait) end
    ui.fs:SetText(msg)
    -- grey while it can't be used (plain Disable() keeps the gold look of our buttons)
    local can = (state == nil) or (state ~= "searching" and state ~= "connecting" and canAgain) or false
    if ui.btn.SetLabel then ui.btn:SetLabel(state and state ~= "connecting" and "Search again" or "Search") end
    if can then ui.btn:Enable() else ui.btn:Disable() end
    if ui.btn.SetLook then ui.btn:SetLook(can) end
  end

  -- Re-check who is online once a minute while the browser is open; the search line every second.
  local tick, stick = 0, 0
  f:SetScript("OnUpdate", function(_, elapsed)
    tick = tick + (elapsed or 0)
    stick = stick + (elapsed or 0)
    if stick >= 1 then stick = 0; updateSearchUI() end -- a few SetText calls, only while a recipe is open
    if tick >= 60 and not (InCombatLockdown and InCombatLockdown()) then tick = 0; f:Refresh(true) end -- not in combat (secure craft buttons)
  end)

  -- Legend for the check columns (top right)
  local legendFirst
  do
    local lx = -14
    local K = UI.KNOW_COLORS
    local specs = {{"Other users |cff9d9d9d(only visible when online)|r", K.other}, {"Guild member", K.guild}, {"I know it", K.me}}
    for i, spec in ipairs(specs) do
      local t = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall"); t:SetPoint("TOPRIGHT", lx, -14); t:SetText(spec[1]); t:SetTextColor(FLT.SkinC(0.85, 0.82, 0.75))
      if i == 1 then
        -- keeps its width when the text changes (see f:Refresh), so the other entries stay put
        t:SetWidth(t:GetStringWidth() or 200); t:SetJustifyH("RIGHT"); f.otherLegend = t
      end
      local ic = UI.Gem(f, 13, unpack(spec[2])); ic:SetPoint("RIGHT", t, "LEFT", -4, 0)
      legendFirst = ic -- the last one created is the left-most ("I know it")
      lx = lx - (t:GetStringWidth() or 60) - 34
    end
  end
  -- hint in the second line, left-aligned with the "I know it" check
  local scanHint = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall"); scanHint:SetTextColor(FLT.SkinC(1, 0.82, 0))
  if legendFirst then scanHint:SetPoint("TOPLEFT", legendFirst, "BOTTOMLEFT", 0, -5) else scanHint:SetPoint("TOPRIGHT", -14, -32) end

  -- filters + search
  local filters = {}
  local box = FLT.SkinBlizz(CreateFrame("EditBox", nil, f, "InputBoxTemplate"))
  box:SetSize(220, 20); box:SetPoint("TOPLEFT", 18, -53); box:SetAutoFocus(false)
  local hint = FLT.NewFS(box, nil, "OVERLAY", "GameFontDisableSmall"); hint:SetPoint("LEFT", 4, 0); hint:SetText("Search...")
  -- clear button next to the search field (only while there is text)
  local clear = UI.GoldButton(f, "X", 22, 20, nil, 11); clear:SetPoint("LEFT", box, "RIGHT", 6, 0); clear:Hide()
  clear:SetScript("OnClick", function() box:SetText(""); box:ClearFocus() end)
  clear:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("Clear search"); GameTooltip:Show() end)
  clear:SetScript("OnLeave", function() GameTooltip:Hide() end)
  box:SetScript("OnTextChanged", function(self) search = (self:GetText() or ""):lower(); hint:SetShown(search == ""); clear:SetShown(search ~= ""); f:Refresh() end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

  -- "Show offline": also list guild members / players who are offline (off by default).
  local function showOffline() return type(OneForAllDB) == "table" and OneForAllDB.recipeShowOffline == true end

  -- list (left) and detail (right)
  local left = CreateFrame("Frame", nil, f); left:SetPoint("TOPLEFT", 0, -82); left:SetPoint("BOTTOMLEFT", 0, 0); left:SetWidth(336)
  UI.Column(left, 4) -- ht3: no frame, a line to the right
  local lsf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, left, "UIPanelScrollFrameTemplate")); lsf:SetPoint("TOPLEFT", 8, -8); lsf:SetPoint("BOTTOMRIGHT", -26, 8)
  local lchild = CreateFrame("Frame", nil, lsf); lchild:SetSize(296, 1); lsf:SetScrollChild(lchild)
  UI.AutoHideScrollBar(lsf)

  local right = CreateFrame("Frame", nil, f); right:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0); right:SetPoint("BOTTOMRIGHT", 0, 0)
  local rsf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, right, "UIPanelScrollFrameTemplate")); rsf:SetPoint("TOPLEFT", 14, -12); rsf:SetPoint("BOTTOMRIGHT", -28, 10)
  local rchild = CreateFrame("Frame", nil, rsf); rchild:SetSize(420, 1); rsf:SetScrollChild(rchild)
  -- Crafting List / Craft buttons stacked right of Skill / Use / Learned from (5.7.3, user 24.10.; UI/CraftList.lua).
  -- Anchored once, it scrolls with the detail.
  local recipeBar = FLT.CraftList and FLT.CraftList.RecipeBar(rchild)
  if recipeBar then recipeBar:SetPoint("TOPRIGHT", rchild, "TOPRIGHT", -32, -100); recipeBar:Hide() end
  UI.AutoHideScrollBar(rsf)

  -- favourite star (top right of the detail panel)
  local star = CreateFrame("Button", nil, right); star:SetSize(26, 26); star:SetPoint("TOPRIGHT", -36, -16)
  star:SetFrameLevel(rsf:GetFrameLevel() + 5)
  star.tex = star:CreateTexture(nil, "ARTWORK"); star.tex:SetAllPoints(); FLT.SetTex(star.tex, UI.ASSET_ROOT .. "icon_star")
  local starHi = star:CreateTexture(nil, "HIGHLIGHT"); starHi:SetAllPoints(); FLT.SetTex(starHi, UI.ASSET_ROOT .. "icon_star"); starHi:SetBlendMode("ADD"); starHi:SetAlpha(0.35)
  local selectedRecipe -- forward: set below
  local function paintStar()
    local r = selectedRecipe and selectedRecipe()
    star:SetShown(r ~= nil and prof ~= nil)
    if not r then return end
    if isFavorite(prof, r.s) then star.tex:SetVertexColor(FLT.SkinC(1, 0.82, 0.25)); star.tex:SetAlpha(1)
    else star.tex:SetVertexColor(0.6, 0.6, 0.6); star.tex:SetAlpha(0.55) end
  end
  star:SetScript("OnEnter", function(self)
    local r = selectedRecipe and selectedRecipe()
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText((r and isFavorite(prof, r.s)) and "Remove from favorites" or "Add to favorites")
    GameTooltip:Show()
  end)
  star:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local rows, selected = {}, nil
  selectedRecipe = function() return selected end
  star:SetScript("OnClick", function()
    if not (prof and selected) then return end
    setFavorite(prof, selected.s, not isFavorite(prof, selected.s))
    paintStar()
    if filter == "fav" then f:Refresh(true) end
  end)
  -- hint when the favourites list is empty
  local favEmpty = FLT.NewFS(left, nil, "OVERLAY", "GameFontDisableSmall")
  favEmpty:SetPoint("TOPLEFT", 16, -16); favEmpty:SetWidth(296); favEmpty:SetJustifyH("LEFT")
  favEmpty:SetText("No favorites yet. Open a recipe in All recipes and click the star at the top right to add it here.")
  favEmpty:Hide()
  local detailWidgets = {}

  local function clearDetail()
    for _, w in ipairs(detailWidgets) do w:Hide() end
    wipe(detailWidgets)
    searchUI.fs, searchUI.btn, searchUI.r = nil, nil, nil
  end
  local function dtext(template, w, parent)
    local t = FLT.NewFS(parent or rchild, nil, "OVERLAY", template or "GameFontHighlightSmall")
    if w then t:SetWidth(w); t:SetJustifyH("LEFT") end
    detailWidgets[#detailWidgets + 1] = t
    return t
  end
  local function dframe(kind, template, parent)
    local fr = CreateFrame(kind or "Frame", nil, parent or rchild, template)
    detailWidgets[#detailWidgets + 1] = fr
    return fr
  end
  local function itemRow(id, y, label, sub, count, parent)
    local b = dframe("Button", nil, parent); b:SetSize(parent and 384 or 400, 30); b:SetPoint("TOPLEFT", parent and 8 or 0, y)
    UI.CardRow(b)
    local ic = b:CreateTexture(nil, "ARTWORK"); ic:SetSize(24, 24); ic:SetPoint("LEFT", 4, 0); FLT.SetTex(ic, itemIcon(id))
    local t = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlight"); t:SetPoint("LEFT", 36, sub and 6 or 0); t:SetWidth(300); t:SetJustifyH("LEFT"); t:SetText(label or itemName(id) or ("Item " .. id))
    if sub then local s = FLT.NewFS(b, nil, "OVERLAY", "GameFontDisableSmall"); s:SetPoint("LEFT", 34, -8); s:SetText(sub) end
    if count then local c = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlight"); c:SetPoint("RIGHT", -6, 0); c:SetText(count) end
    b:SetScript("OnEnter", function(self) if H and H.tryShowItemTooltip then H.tryShowItemTooltip(self, {id, label or ""}) end end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function(_, button) if H and H.handleDungeonItemClick and H.normalizeDungeonItem then H.handleDungeonItemClick(H.normalizeDungeonItem({id, label or ""}), button) end end)
    return b
  end
  local function npcRow(n, y, parent)
    local row = dframe("Frame", nil, parent); row:SetSize(parent and 376 or 400, 22); row:SetPoint("TOPLEFT", parent and 14 or 8, y)
    -- thin line under each row (like the family abilities of Hunter Pets)
    local sep = UI.makeTexture(row, "BORDER", 0.72, 0.50, 0.12, 0.18); sep:SetPoint("BOTTOMLEFT", 0, -1); sep:SetPoint("BOTTOMRIGHT", 0, -1); sep:SetHeight(1)
    local t = FLT.NewFS(row, nil, "OVERLAY", "GameFontHighlightSmall"); t:SetPoint("LEFT", 0, 0); t:SetWidth(300); t:SetJustifyH("LEFT")
    local fac = n.fac == "A" and " |cff4f9fff(Alliance)|r" or (n.fac == "H" and " |cffff5040(Horde)|r" or "")
    t:SetText((n[2] or "?") .. "  |cff9d9d9d- " .. (n[3] or "?") .. "|r" .. fac)
    if n[4] and n[5] then
      local mb = UI.GoldButton(row, "Map", 62, 20, UI.ASSET_ROOT .. "icon_map", 11); mb:SetPoint("RIGHT", 0, 0)
      mb:SetScript("OnClick", function() FLT:ShowOnMap({mapID = n[4], x = n[5], y = n[6], zone = n[3], name = n[2]}) end)
    end
  end

  -- framed box with a small-caps title, like Hunter Pets (5.7.3, user 24.10.); build(box, y) fills it from y down and
  -- returns where it ended; returns the y below the box
  local function section(title, y0, build)
    local b = dframe("Frame"); b:SetPoint("TOPLEFT", 0, y0); b:SetWidth(400)
    UI.FramedPanel(b)
    local t = UI.SmallCaps(b, title, 15, 11, GOLD); t:SetPoint("TOPLEFT", 12, -9)
    local h = -build(b, -32) + 8
    b:SetHeight(h)
    return y0 - h - 10
  end

  local function showDetail(r, keepScroll)
    clearDetail()
    if recipeBar then recipeBar:SetRecipe(prof, r) end
    if not r then return end
    local p = profDB(prof)
    local y = 0
    local big = dframe("Frame"); big:SetSize(46, 46); big:SetPoint("TOPLEFT", 0, y)
    local bic = big:CreateTexture(nil, "ARTWORK"); bic:SetAllPoints(); FLT.SetTex(bic, recipeIcon(r))
    local name = dtext("GameFontNormalLarge", 350); name:SetPoint("TOPLEFT", 56, y - 2)
    name:SetText(r.n .. ((r.c and r.c > 1) and (" x" .. r.c) or "")); local qc = QCOL[r.q or 1] or QCOL[1]; name:SetTextColor(FLT.SkinC(qc[1], qc[2], qc[3]))
    local sub = dtext("GameFontDisableSmall", 350); sub:SetPoint("TOPLEFT", 56, y - 26)
    -- 6.1.0 (user 03.11.): no automatic search when a recipe is opened - only the "Search" button asks the channel
    local guild = FLT.GetGuildRecipeKnowers and FLT.GetGuildRecipeKnowers(prof, r.s)
    local others = onlineOthers(prof, r.s)
    sub:SetText((r.cat or "") .. (p.known[r.s] and "   " .. FLT.SkinHex("ffd926") .. "Known|r" or (guild and "   |cff59ff73Known in your guild|r" or (others and "   |cff5ab3ffKnown by other players|r" or ""))))
    big:EnableMouse(true)
    big:SetScript("OnMouseUp", function(_, button)
      if button == "LeftButton" and IsShiftKeyDown and IsShiftKeyDown() then linkRecipe(r, button, H) end
    end)
    big:SetScript("OnEnter", function(self)
      if r.i then
        if H and H.tryShowItemTooltip then H.tryShowItemTooltip(self, {r.i, r.n}) end
      else
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(r.s) else GameTooltip:AddLine(r.n) end
        GameTooltip:Show()
      end
    end)
    big:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local dv = rchild:CreateTexture(nil, "ARTWORK"); FLT.SetTex(dv, UI.ASSET_ROOT .. "divider_ornate"); dv:SetSize(400, 16); dv:SetPoint("TOPLEFT", 0, y - 48)
    detailWidgets[#detailWidgets + 1] = dv
    y = y - 70
    local textW = (recipeBar and recipeBar:IsShown()) and 176 or 290 -- the Crafting List / Craft stack sits on the right
    local box, by -- the Details box and the y inside it

    local function line(label, text)
      local h = dtext("GameFontNormalSmall", nil, box); h:SetPoint("TOPLEFT", 12, by); h:SetText(label); h:SetTextColor(FLT.SkinC(unpack(GOLD)))
      local b = dtext("GameFontHighlightSmall", textW, box); b:SetPoint("TOPLEFT", 104, by); b:SetText(text)
      by = by - math.max(18, (b:GetStringHeight() or 14) + 6)
    end
    local function c(col, v) local k = DIFF[col]; return string.format("|cff%02x%02x%02x%s|r", math.floor(k[1] * 255), math.floor(k[2] * 255), math.floor(k[3] * 255), tostring(v)) end
    y = section("Details", y, function(b, y1) box, by = b, y1
    line("Skill", (r.req and ("learn at " .. r.req .. "   ") or "") .. c("yellow", r.y) .. "  " .. c("green", r.g) .. "  " .. c("gray", r.gr))
    do -- chance of a skill-up at your skill (yellow / green only)
      local d = difficulty(r, p.skill)
      local pct = skillUpChance(r, d, p.skill)
      if pct then line("Skill-up", c(d, pct .. "% chance") .. "  |cff9d9d9d(at skill " .. p.skill .. ")|r") end
    end
    if r.lv then
      local pl = UnitLevel and UnitLevel("player") or 0
      line("Use", (pl < r.lv and "|cffff6060" or "") .. "Requires level " .. r.lv .. (pl < r.lv and "|r" or ""))
    end
    local learn
    if r.start then learn = "Known when you learn " .. prof
    elseif r.ri then
      -- How to get the recipe item: vendor, world drop, specific mobs, quest, Favor.
      local src, how = r.src or {}, {}
      if r.fav then how[#how + 1] = FLT.SkinHex("ffd200") .. "Merchant's Favor|r" end
      if src.v then
        local fa, fh = false, false
        for _, n in ipairs(src.v) do if n.fac == "A" then fa = true elseif n.fac == "H" then fh = true else fa, fh = true, true end end
        how[#how + 1] = "|cff59ff73Vendor|r" .. ((fa and not fh) and " (Alliance)" or ((fh and not fa) and " (Horde)" or ""))
      end
      if src.d then
        local n = src.dn or #src.d
        how[#how + 1] = (n >= 10) and "|cffff9933World drop|r" or string.format("|cffff9933Drop|r (%d %s)", n, n == 1 and "mob" or "mobs")
      end
      if src.qs then how[#how + 1] = "|cff7fbfffQuest reward|r" end
      learn = (r.rn or "Recipe item") .. "\n" .. (#how > 0 and table.concat(how, "  +  ") or "|cff9d9d9dSource not known yet|r")
    else learn = "Profession trainer" end
    line("Learned from", learn)
    -- the Crafting List / Craft stack (anchored in rchild at y -100) must fit into the box
    if recipeBar and recipeBar:IsShown() then by = math.min(by, -30 - recipeBar:UsedHeight()) end
    return by + 4 end)

    y = section("Reagents", y, function(b, ry)
      for _, rg in ipairs(r.r or {}) do
        local have = GetItemCount and GetItemCount(rg[1], true) or 0
        local col = have >= rg[2] and "|cff59ff73" or "|cffff6060"
        itemRow(rg[1], ry, itemName(rg[1]) or (rg[3] ~= "" and rg[3]) or nil, nil, col .. have .. "|r / " .. rg[2], b); ry = ry - 32
      end
      return ry + 2
    end) + 10

    -- Who else can craft it: online first, with zone and a whisper button.
    local INST = { raid = "in a raid", party = "in a dungeon", pvp = "in a battleground", arena = "in an arena", scenario = "in a scenario" }
    -- Guild: online members, offline ones with "Show offline".
    -- Other players: only those online right now.
    local function knowers(label, list, col, isGuild)
      if not list then return end
      local hidden = 0
      if not (isGuild and showOffline()) then
        local on = {}
        for _, g in ipairs(list) do if g[2] then on[#on + 1] = g else hidden = hidden + 1 end end
        list = on
      end
      -- other players: search state line (6.1.0), shown also without results
      local state
      if not isGuild then
        hidden = 0
        if FLT.RecipeSearchState then state = FLT.RecipeSearchState(prof, r.s) end -- (not "a and f()": keeps one value)
        if state == "off" then return end -- shown also before any search, with the "Search" button
      end
      y = y - 12
      y = y - 6
      -- tinted box behind the section (size set below)
      local top = y + 6
      -- rounded box: the textures belong to rchild (behind the text), the
      -- empty frame only gives them their position and size
      local box = dframe("Frame")
      local card
      if col == "|cff59ff73" then card = UI.Card(rchild, box, 5, {0.30, 0.55, 0.30, 0.85}, {0.06, 0.13, 0.07, 0.80}, "BACKGROUND", 0)
      else card = UI.Card(rchild, box, 5, {0.30, 0.45, 0.68, 0.85}, {0.05, 0.09, 0.16, 0.80}, "BACKGROUND", 0) end
      for _, t in ipairs(card.border.pieces) do detailWidgets[#detailWidgets + 1] = t end
      for _, t in ipairs(card.fill.pieces) do detailWidgets[#detailWidgets + 1] = t end
      y = y - 6
      local hk = dtext("GameFontNormal"); hk:SetPoint("TOPLEFT", 10, y); hk:SetText(label); hk:SetTextColor(FLT.SkinC(unpack(GOLD)))
      if not isGuild then
        -- "Search again" (at most every 30 s) and the state of the search
        local nm = UI.NewMark(rchild, "Now you need to click \"Search\" to see who knows this recipe. Had to make it this way to get no lags and stay fast. Players near you are preferred to show up.")
        nm:SetPoint("LEFT", hk, "RIGHT", 4, 0)
        detailWidgets[#detailWidgets + 1] = nm
        local holder = dframe("Frame"); holder:SetSize(104, 22); holder:SetPoint("TOPLEFT", 286, y + 2)
        local sb = UI.GoldButton(holder, state and "Search again" or "Search", 100, 20, nil, 11); sb:SetPoint("RIGHT", 0, 0)
        sb:SetScript("OnClick", function()
          if FLT.SearchRecipe then FLT.SearchRecipe(prof, r.s, true); f:Refresh(true) end
        end)
        -- explain the wait (the button is grey for 30 s after a search; the tooltip shows while grey too)
        if sb.SetMotionScriptsWhileDisabled then sb:SetMotionScriptsWhileDisabled(true) end
        sb:SetScript("OnEnter", function(self)
          GameTooltip:SetOwner(self, "ANCHOR_TOP")
          GameTooltip:AddLine("Search", 1, 0.82, 0)
          GameTooltip:AddLine("Asks the other OneForAll users who know this recipe. Only a few of them answer, and you can search again 30 seconds after the last search - so the channel stays quiet and fast with many players.", 1, 1, 1, true)
          GameTooltip:Show()
        end)
        sb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- text and button state are kept up to date by updateSearchUI (no rebuild for "2 min ago")
        y = y - 20
        local st = dtext("GameFontHighlightSmall", 380); st:SetPoint("TOPLEFT", 12, y)
        searchUI.fs, searchUI.btn, searchUI.r, searchUI.n = st, sb, r, #list
        updateSearchUI()
      end
      if isGuild then
        -- "Show offline" next to the guild heading (off by default)
        local cb = dframe("CheckButton", "UICheckButtonTemplate"); cb:SetSize(22, 22)
        cb:SetPoint("LEFT", hk, "RIGHT", 14, 0); cb:SetChecked(showOffline())
        local cl = dtext("GameFontHighlightSmall"); cl:SetPoint("LEFT", cb, "RIGHT", 2, 0); cl:SetText("Show offline")
        cb:SetScript("OnClick", function(self)
          if type(OneForAllDB) == "table" then OneForAllDB.recipeShowOffline = self:GetChecked() and true or false end
          f:Refresh(true)
        end)
      end
      y = y - 22
      for k, g in ipairs(list) do
        if k > 8 then
          local more = dtext("GameFontDisableSmall"); more:SetPoint("TOPLEFT", 12, y)
          more:SetText(string.format("+%d more", #list - 8)); y = y - 18; break
        end
        local row = dframe("Frame"); row:SetSize(396, 22); row:SetPoint("TOPLEFT", 12, y)
        local t = FLT.NewFS(row, nil, "OVERLAY", "GameFontHighlightSmall"); t:SetPoint("LEFT", 0, 0); t:SetWidth(300); t:SetJustifyH("LEFT"); t:SetWordWrap(false)
        local where
        if g[2] then
          where = g[3] and ("|cffd0c8b0" .. g[3] .. "|r") or "|cffd0c8b0online|r"
          if g[4] and INST[g[4]] then where = where .. "  |cffff9933(" .. INST[g[4]] .. ")|r" end
        else
          where = "|cff7f7f7foffline|r"
        end
        -- "Name, lvl 23 Priest - Zone" (level and class in grey)
        local who = ""
        if g.level or g.class then
          local cls = g.class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[g.class]) or (g.class:sub(1, 1) .. g.class:sub(2):lower())) or nil
          local parts = {}
          if g.level and g.level > 0 then parts[#parts + 1] = "lvl " .. g.level end
          if cls then parts[#parts + 1] = cls end
          if #parts > 0 then who = "|cff9d9d9d, " .. table.concat(parts, " ") .. "|r" end
        end
        t:SetText((g[2] and col or "|cff9d9d9d") .. g[1] .. "|r" .. who .. "|cff9d9d9d - |r" .. where)
        if g.seen then
          row:EnableMouse(true)
          local seen = g.seen
          row:SetScript("OnEnter", function(self)
            local m = math.max(0, math.floor(((time and time() or 0) - seen) / 60))
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(m < 1 and "Last heard just now" or ("Last heard " .. m .. " min ago"), 1, 1, 1)
            GameTooltip:Show()
          end)
          row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        if g[2] then
          local wb = UI.GoldButton(row, "Whisper", 70, 20, nil, 11); wb:SetPoint("RIGHT", -10, 0)
          local who = g[1]
          wb:SetScript("OnClick", function()
            if ChatFrame_SendTell then ChatFrame_SendTell(who)
            elseif ChatFrame_OpenChat then ChatFrame_OpenChat("/w " .. who .. " ") end
          end)
        end
        y = y - 22
      end
      if hidden > 0 then
        local hn = dtext("GameFontDisableSmall", 390); hn:SetPoint("TOPLEFT", 12, y)
        hn:SetText(string.format("%s%d offline", #list > 0 and "+ " or "", hidden)); y = y - 18
      end
      y = y - 6
      box:SetPoint("TOPLEFT", 0, top); box:SetSize(400, top - y)
    end
    knowers("Guild members who know it", guild, "|cff59ff73", true)
    knowers("Other OneForAll users online who know it", others or {}, "|cff5ab3ff", false)

    if r.ri then
      y = section("Recipe", y - 10, function(b, ry)
        itemRow(r.ri, ry, r.rn, nil, nil, b); ry = ry - 38
        local src = r.src or {}
        local function sub(text)
          local t = dtext("GameFontNormalSmall", nil, b); t:SetPoint("TOPLEFT", 12, ry); t:SetText(text); t:SetTextColor(FLT.SkinC(unpack(GOLD))); ry = ry - 20
        end
        if src.v then
          sub("Sold by")
          for _, n in ipairs(src.v) do npcRow(n, ry, b); ry = ry - 24 end
          ry = ry - 6
        end
        if src.d then
          sub("Drops from" .. ((src.dn and src.dn > #src.d) and string.format("  |cff9d9d9d(%d of %d shown)|r", #src.d, src.dn) or ""))
          for _, n in ipairs(src.d) do npcRow(n, ry, b); ry = ry - 24 end
          ry = ry - 6
        end
        if src.qs then
          sub("Quest reward")
          for _, q in ipairs(src.qs) do local qt = dtext("GameFontHighlightSmall", 370, b); qt:SetPoint("TOPLEFT", 14, ry); qt:SetText(q[2]); ry = ry - 18 end
        end
        if not (src.v or src.d or src.qs) then
          local t = dtext("GameFontDisableSmall", 370, b); t:SetPoint("TOPLEFT", 12, ry)
          t:SetText(r.fav and "Bought with Merchant's Favor - see the Favor pages." or "Where this recipe comes from is not known yet."); ry = ry - 18
        end
        return ry
      end)
    end
    rchild:SetHeight(math.max(1, -y + 10))
    if not keepScroll then rsf:SetVerticalScroll(0) end
  end

  if recipeBar then recipeBar.onChange = function() if selected then showDetail(selected, true) end end end

  local function rowFor(i)
    if rows[i] then return rows[i] end
    local b = CreateFrame("Button", nil, lchild); b:SetSize(298, 26)
    b.card = UI.CardRow(b)
    -- quality bar on the left edge (colour of the crafted item's rarity)
    b.qbar = b:CreateTexture(nil, "BORDER"); b.qbar:SetPoint("TOPLEFT", 2, -3); b.qbar:SetPoint("BOTTOMLEFT", 2, 3); b.qbar:SetWidth(2)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(20, 20); b.icon:SetPoint("LEFT", 7, 0)
    b.name = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlightSmall"); b.name:SetPoint("LEFT", 32, 0); b.name:SetWidth(150); b.name:SetJustifyH("LEFT"); b.name:SetWordWrap(false)
    b.lvl = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlightSmall"); b.lvl:SetPoint("RIGHT", -6, 0); b.lvl:SetJustifyH("RIGHT")
    -- character level needed to use the crafted item ("L51"), left of the checks
    b.req = FLT.NewFS(b, nil, "OVERLAY", "GameFontDisableSmall"); b.req:SetPoint("RIGHT", -84, 0); b.req:SetJustifyH("RIGHT")
    -- three check columns side by side: yellow = you, green = guild, blue = other players
    b.checks = {}
    local K = UI.KNOW_COLORS
    for k, spec in ipairs({{-66, K.me}, {-50, K.guild}, {-34, K.other}}) do
      local c = UI.Gem(b, 12, unpack(spec[2])); c:SetPoint("RIGHT", spec[1] - 1, 0); c:Hide()
      b.checks[k] = c
    end
    b:SetScript("OnClick", function(self, button)
      -- Shift-click links the crafted item in the chat; a normal click selects.
      local r = self.recipe
      if r and IsShiftKeyDown and IsShiftKeyDown() and H and H.handleDungeonItemClick then
        linkRecipe(r, button, H); return
      end
      selected = r; f:Refresh(true); rsf:SetVerticalScroll(0)
    end)
    rows[i] = b
    return b
  end

  local ROW_STEP = 29
  -- Draws the rows that are visible at the current scroll position.
  function f:DrawRows()
    local vis = f.visible
    if not vis then return end
    local skill, knownT = f.visSkill, f.visKnown or {}
    local off = lsf:GetVerticalScroll() or 0
    local viewH = lsf:GetHeight() or 0
    if viewH < 50 then viewH = 900 end -- not laid out yet: draw enough rows
    local first = math.max(1, math.floor(off / ROW_STEP) + 1)
    local last = math.min(#vis, math.ceil((off + viewH) / ROW_STEP) + 1)
    local pl = UnitLevel and UnitLevel("player") or 0
    local used = 0
    for idx = first, last do
      local r = vis[idx]
      used = used + 1
      local b = rowFor(used); b.recipe = r
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", 0, -2 - (idx - 1) * ROW_STEP)
      FLT.SetTex(b.icon, recipeIcon(r))
      local qc = r.i and QCOL[r.q or 1]
      if qc then b.qbar:SetColorTexture(FLT.SkinC(qc[1], qc[2], qc[3], (r.q or 1) <= 1 and 0.45 or 0.95)); b.qbar:Show() else b.qbar:Hide() end
      local d = difficulty(r, skill)
      local pct = skillUpChance(r, d, skill)
      local n = knownT[r.s] and canMake(r) or 0
      b.name:SetText(r.n .. (n > 0 and (" (" .. n .. ")") or "") .. (pct and ("  " .. pct .. "%") or ""))
      local col = d and DIFF[d] or {0.92, 0.90, 0.84}
      b.name:SetTextColor(FLT.SkinC(col[1], col[2], col[3]))
      b.lvl:SetText(r.req and tostring(r.req) or ("|cff9d9d9d" .. (r.y or "?") .. "|r"))
      if r.lv then
        b.req:SetText((pl < r.lv and "|cffcc5555" or "|cff8f8f8f") .. "L" .. r.lv .. "|r")
      else
        b.req:SetText("")
      end
      -- yellow = you, green = guild member, blue = other OneForAll user
      b.checks[1]:SetShown(knownT[r.s] and true or false)
      b.checks[2]:SetShown((FLT.GetGuildRecipeKnowers and FLT.GetGuildRecipeKnowers(prof, r.s)) and true or false)
      b.checks[3]:SetShown(onlineOthers(prof, r.s) and true or false)
      b.card:SetSelected(selected == r)
      b:Show()
    end
    for i = used + 1, #rows do rows[i]:Hide() end
  end
  lsf:HookScript("OnVerticalScroll", function() f:DrawRows() end)
  -- the "(n)" you can make follows your bags, but only while the list is open (6.0.1-beta2)
  f:SetScript("OnShow", function(self) self:RegisterEvent("BAG_UPDATE_DELAYED") end)
  f:SetScript("OnHide", function(self) self:UnregisterEvent("BAG_UPDATE_DELAYED") end)
  f:SetScript("OnEvent", function(self) if self:IsVisible() then self:DrawRows() end end)
  lsf:HookScript("OnSizeChanged", function() f:DrawRows() end)

  -- what the detail view of a recipe shows, as a string (see f:Refresh)
  local lastSig
  local sigParts = {}
  local function addKnowers(list)
    for _, g in ipairs(list or {}) do
      sigParts[#sigParts + 1] = tostring(g[1]) .. (g[2] and "+" or "-") .. tostring(g[3]) .. tostring(g[4]) .. tostring(g.level)
    end
  end
  local function detailSig(r)
    wipe(sigParts)
    local p = profDB(prof)
    sigParts[1] = prof .. ":" .. r.s .. (p.known[r.s] and "k" or "") .. (showOffline() and "o" or "") .. tostring(p.skill)
    sigParts[2] = (recipeBar and recipeBar:IsShown()) and "b" or ""
    if FLT.RecipeSearchState then sigParts[3] = tostring((FLT.RecipeSearchState(prof, r.s))) end -- time and button: updateSearchUI
    for _, rg in ipairs(r.r or {}) do sigParts[#sigParts + 1] = GetItemCount and GetItemCount(rg[1], true) or 0 end
    addKnowers(FLT.GetGuildRecipeKnowers and FLT.GetGuildRecipeKnowers(prof, r.s))
    addKnowers(FLT.GetOtherRecipeKnowers and FLT.GetOtherRecipeKnowers(prof, r.s))
    return table.concat(sigParts, "|")
  end

  function f:Refresh(keepScroll)
    if self.otherLegend then
      local on = not FLT.IsRecipeShareEnabled or FLT.IsRecipeShareEnabled()
      self.otherLegend:SetText("Other users |cff9d9d9d(" .. (on and "only visible when online" or "sharing is off") .. ")|r")
    end
    if not prof then return end
    local list = recipesFor(prof)
    local p = profDB(prof)
    local skill = p.skill
    local knownCount = 0
    for _, r in ipairs(list) do if p.known[r.s] then knownCount = knownCount + 1 end end
    title:SetText(prof .. (filter == "fav" and " - Favorites" or " - All recipes") .. "  |cff9d9d9d(beta)|r")
    FLT.SetTex(profIcon, (FLT.PROFESSION_ICONS and FLT.PROFESSION_ICONS[prof]) or "Interface\\Icons\\INV_Misc_QuestionMark")
    -- The skill comes from the profession book; no skill = not learned on this character.
    meta:SetText((skill and ("Your skill: " .. skill .. (p.maxSkill and ("/" .. p.maxSkill) or "")) or "|cff9d9d9dNot learned on this character|r") ..
      string.format("   |   %d recipes, %d known", #list, knownCount))
    scanHint:SetText((skill and not p.scanned) and ("Open your " .. prof .. " window once to mark known recipes") or "")

    -- Filtered list first (cheap); rows are only drawn for the visible part
    -- (virtual list), so a profession with 500 recipes builds ~20 rows.
    local vis = {}
    for _, r in ipairs(list) do
      local ok = true
      if filter == "missing" and p.known[r.s] then ok = false end
      if filter == "fav" and not isFavorite(prof, r.s) then ok = false end
      if ok and search ~= "" then
        local hay = (r.n .. " " .. (r.cat or "") .. " " .. (r.rn or "")):lower()
        if not hay:find(search, 1, true) then ok = false end
      end
      if ok then vis[#vis + 1] = r end
    end
    if filter == "fav" then
      local still = false
      for _, r in ipairs(vis) do if r == selected then still = true end end
      if not still then selected = vis[1] end
    end
    favEmpty:SetShown(filter == "fav" and #vis == 0)
    f.visible, f.visSkill, f.visKnown = vis, skill, p.known
    lchild:SetHeight(math.max(1, #vis * ROW_STEP + 4))
    if not keepScroll then lsf:SetVerticalScroll(0) end
    f:DrawRows()
    if selected then
      -- rebuild the details only when something in them changed (the frames of a detail view can't be freed; the
      -- browser refreshes once a minute and after search answers)
      local sig = detailSig(selected)
      if sig ~= lastSig or not keepScroll then lastSig = sig; showDetail(selected, keepScroll) else updateSearchUI() end
    else
      lastSig = nil; clearDetail(); if recipeBar then recipeBar:SetRecipe(nil) end
    end
    paintStar()
  end

  function f:ShowProfession(name, mode)
    if FLT.RequestGuildRoster then FLT.RequestGuildRoster() end
    if prof ~= name then selected = nil end
    filter = (mode == "fav") and "fav" or "all"
    prof = name
    readSkillLines()
    local list = recipesFor(prof)
    selected = selected or list[1]
    f:Show(); f:Refresh()
  end

  -- Opens the browser on one recipe (used by the dungeon loot list).
  function f:SelectRecipe(name, spell)
    f:ShowProfession(name, "all")
    search = ""
    box:SetText(""); box:ClearFocus()
    local list = recipesFor(prof)
    for idx, r in ipairs(list) do
      if r.s == spell then
        selected = r
        f:Refresh()
        local function scrollTo()
          local range = lsf:GetVerticalScrollRange() or 0
          lsf:SetVerticalScroll(math.max(0, math.min(range, (idx - 1) * 29 - 120)))
        end
        scrollTo()
        -- the first time the tab opens the list has no scroll range yet: once more on the next frame (user 22.10.)
        if C_Timer and C_Timer.After then C_Timer.After(0, function() if selected == r then scrollTo() end end) end
        return true
      end
    end
    f:Refresh()
    return false
  end

  return f
end
