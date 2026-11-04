local _, FLT = ...
-- Item API: newer clients only have these under C_Item.
local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)
local GetItemIcon = GetItemIcon or (C_Item and C_Item.GetItemIconByID)
local UI = FLT.UI
local DISPLAY_NAME = UI.DISPLAY_NAME

-- Quest-status and item helpers used by the Dungeons tab.
local H = {}
UI.DungeonHelpers = H

-- Matches a log entry to a quest. The quest ID is authoritative: chain steps
-- often share one title (e.g. five "Hidden Enemies" steps), so the title is
-- only used when the log entry or the quest data has no ID at all.
local function logEntryMatches(wantedID, wantedTitle, entryID, entryTitle)
  if wantedID and entryID and entryID ~= 0 then return entryID == wantedID end
  return wantedTitle ~= nil and entryTitle == wantedTitle
end

local function getQuestLogInfo(q)
  if not q then return false, false end
  local wantedID = tonumber(q.id)
  local wantedTitle = q.name
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
    local n = C_QuestLog.GetNumQuestLogEntries() or 0
    for i=1,n do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader and logEntryMatches(wantedID, wantedTitle, info.questID, info.title) then
        return true, info.isComplete and true or false
      end
    end
  elseif GetNumQuestLogEntries and GetQuestLogTitle then
    local n = GetNumQuestLogEntries() or 0
    for i=1,n do
      local qtitle, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
      if not isHeader and logEntryMatches(wantedID, wantedTitle, questID, qtitle) then
        return true, (isComplete and isComplete > 0) and true or false
      end
    end
  end
  return false, false
end

local function dungeonQuestEligible(q)
  local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
  local classToken
  if UnitClass then local _, token = UnitClass("player"); classToken = token end
  local sideOK = (not q.side or q.side == "Both" or q.side == "Neutral" or not faction or q.side == faction)
  local classOK = (not q.class or not classToken or q.class == classToken)
  return sideOK and classOK
end

local QUEST_STATUS_LABELS = {
  completed = "Completed",
  inlog = "In log",
  available = "Available",
  unavailable = "Unavailable",
}

-- If the quest has a known chain and one of its earlier steps is in the quest
-- log, returns that step's position and the chain length (steps + the quest).
local function getChainProgress(q)
  local chain = q and q.id and FLT.QUEST_PREREQ_CHAINS and FLT.QUEST_PREREQ_CHAINS[q.id]
  if not chain or #chain == 0 then return nil end
  local steps = {}
  for _, step in ipairs(chain) do if step.id ~= q.id then steps[#steps + 1] = step end end
  local total = #steps + 1
  for i = #steps, 1, -1 do
    local step = steps[i]
    if step.id and not (FLT.IsQuestDone and FLT:IsQuestDone(step.id)) and getQuestLogInfo({ id = step.id }) then
      return i, total
    end
  end
  return nil, total
end

local function getDungeonQuestStatus(d, q)
  if not q then return "unavailable" end

  -- Faction/class relevance is checked before completion flags. This prevents
  -- odd beta completion flags for opposite-faction quests from entering the
  -- player's dungeon denominator. Dungeons both factions actually run
  -- (openToBoth, e.g. Gnomeregan) skip the territory rule.
  if not dungeonQuestEligible(q) then return "unavailable" end
  local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
  if d and faction and not d.openToBoth and d.territory and (d.territory == "Alliance" or d.territory == "Horde") and d.territory ~= faction then
    return "unavailable"
  end

  if q.id and FLT.IsQuestDone and FLT:IsQuestDone(q.id) then return "completed" end

  local inLog = getQuestLogInfo(q)
  if inLog then return "inlog" end
  -- Working on an earlier step of this quest's chain counts as "in log" too.
  if getChainProgress(q) then return "inlog" end

  local playerLevel = UnitLevel and tonumber(UnitLevel("player")) or nil
  local required = tonumber(q.required or q.level)
  if playerLevel and required and playerLevel < required then return "unavailable" end

  -- If we have a verified prerequisite chain, keep the quest unavailable until
  -- the prior required steps are completed. Optional lead-ins never block.
  -- Unknown prerequisites are not guessed here.
  local chain = q.id and FLT.QUEST_PREREQ_CHAINS and FLT.QUEST_PREREQ_CHAINS[q.id]
  if chain then
    for _, step in ipairs(chain) do
      if step.id and step.id ~= q.id and not step.optional and FLT.IsQuestDone and not FLT:IsQuestDone(step.id) then
        return "unavailable"
      end
    end
  end

  return "available"
end

local function dungeonSideColor(side)
  if side == "Alliance" then return 0.30,0.62,1.00 end
  if side == "Horde" then return 1.00,0.28,0.23 end
  return 1.00,0.74,0.18
end

local function normalizeDungeonItem(item)
  if type(item) == "table" then
    if item.name or item.id then return item end -- {id = ...} alone too (Crafting List, user 26.10.)
    return {id=item[1],name=item[2],slot=item[3],quality=item[4]}
  end
  local rec = FLT.DUNGEON_ITEM_DB and FLT.DUNGEON_ITEM_DB[item]
  if rec then return {name=item, id=rec.id, slot=rec.slot, summary=rec.summary, quality=rec.quality} end
  return {name=tostring(item or "Unknown item")}
end


local function dungeonItemQuality(item)
  local rec=normalizeDungeonItem(item)

  -- Forever changes the quality of a number of Classic dungeon items. Always
  -- prefer the quality reported by the running client and only use our embedded
  -- value as a fallback while item data is not available yet.
  if rec.id and C_Item and C_Item.RequestLoadItemDataByID then
    pcall(C_Item.RequestLoadItemDataByID, rec.id)
  end
  if GetItemInfo then
    local _,_,quality = GetItemInfo(rec.id or rec.name)
    if quality ~= nil then return quality end
  end
  if rec.id and C_Item and C_Item.GetItemQualityByID then
    local ok,quality = pcall(C_Item.GetItemQualityByID, rec.id)
    if ok and quality ~= nil then return quality end
  end
  return rec.quality
end

local function colorDungeonItemText(fontString,item,dr,dg,db)
  local q=dungeonItemQuality(item)
  local c=q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c then fontString:SetTextColor(FLT.SkinC(c.r,c.g,c.b)) else fontString:SetTextColor(FLT.SkinC(dr or 0.92,dg or 0.90,db or 0.84)) end
end

-- Items the client has not cached yet show "Retrieving item information".
-- Remember the hovered item and redraw the tooltip once the server has sent
-- the data (GET_ITEM_INFO_RECEIVED), as long as the mouse is still on it.
local pendingTooltip
local tryShowItemTooltip
local itemInfoWatcher = CreateFrame("Frame")
itemInfoWatcher:RegisterEvent("GET_ITEM_INFO_RECEIVED")
itemInfoWatcher:SetScript("OnEvent", function(_, _, itemID)
  local p = pendingTooltip
  if not p or (itemID and p.id ~= itemID) then return end
  pendingTooltip = nil
  if GameTooltip:IsShown() and GameTooltip:GetOwner() == p.owner and (not p.owner.IsMouseOver or p.owner:IsMouseOver()) then
    tryShowItemTooltip(p.owner, p.item)
  end
end)

-- Item rows are very wide, so ANCHOR_RIGHT puts the tooltip far away from the
-- item. Show it next to the mouse instead, top-aligned with the row. The
-- client's comparison tooltips ("Equipped") are kept on the same side, so the
-- hovered loot row is never covered: everything right of the mouse if it fits,
-- otherwise everything left of it.
local tipAnchor = { owner = nil, xr = 0, xl = 0, top = 0 }

local function placeItemTooltips()
  local owner = tipAnchor.owner
  if not owner or GameTooltip:GetOwner() ~= owner or not GameTooltip:IsShown() then return end
  local ui = UIParent:GetEffectiveScale()
  local function w(f) return (f:GetWidth() or 0) * f:GetEffectiveScale() / ui end
  local s1, s2 = ShoppingTooltip1, ShoppingTooltip2
  local c1 = s1 and s1:IsShown()
  local c2 = c1 and s2 and s2:IsShown()
  local total = w(GameTooltip) + (c1 and w(s1) or 0) + (c2 and w(s2) or 0)
  local gs = GameTooltip:GetEffectiveScale() / ui
  local right = tipAnchor.xr + total <= UIParent:GetWidth()
  GameTooltip:ClearAllPoints()
  if right then
    GameTooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", tipAnchor.xr / gs, tipAnchor.top / gs)
  else
    GameTooltip:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", tipAnchor.xl / gs, tipAnchor.top / gs)
  end
  if c1 then
    s1:ClearAllPoints()
    if right then s1:SetPoint("TOPLEFT", GameTooltip, "TOPRIGHT", 0, 0) else s1:SetPoint("TOPRIGHT", GameTooltip, "TOPLEFT", 0, 0) end
  end
  if c2 then
    s2:ClearAllPoints()
    if right then s2:SetPoint("TOPLEFT", s1, "TOPRIGHT", 0, 0) else s2:SetPoint("TOPRIGHT", s1, "TOPLEFT", 0, 0) end
  end
end

-- Tooltips of items you wear (the Armory gear slots): no comparison with themselves (user 31.10.).
-- The owner sets GameTooltip.ofaNoCompare before showing; the comparison tooltips are hidden again right after
-- the client shows them. Cleared when the tooltip hides.
local function noCompare()
  if not GameTooltip.ofaNoCompare then return end
  if type(ShoppingTooltip1) == "table" then ShoppingTooltip1:Hide() end
  if type(ShoppingTooltip2) == "table" then ShoppingTooltip2:Hide() end
  return true
end

-- The client re-anchors the comparison tooltips itself (e.g. when Shift is
-- pressed); move them back right after it does.
if type(GameTooltip_ShowCompareItem) == "function" and hooksecurefunc then
  hooksecurefunc("GameTooltip_ShowCompareItem", function(tt) if (tt == nil or tt == GameTooltip) and not noCompare() then placeItemTooltips() end end)
end
if TooltipComparisonManager and TooltipComparisonManager.AnchorShoppingTooltips and hooksecurefunc then
  hooksecurefunc(TooltipComparisonManager, "AnchorShoppingTooltips", function() if not noCompare() then placeItemTooltips() end end)
end

GameTooltip:HookScript("OnHide", function() tipAnchor.owner = nil; GameTooltip.ofaNoCompare = nil end)

-- Position does not depend on where the mouse entered the row: right of the
-- item's text (name / slot line), or left of the whole row if there is no room.
local function anchorItemTooltip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_NONE")
  local ui = UIParent:GetEffectiveScale()
  local os = owner:GetEffectiveScale() / ui
  local left, top = owner:GetLeft(), owner:GetTop()
  if not (left and top) then
    local cx, cy = GetCursorPosition()
    left, top, os = cx / ui, cy / ui, 1
  end
  local textRight = left + 40
  for _, r in ipairs({ owner:GetRegions() }) do
    -- right-aligned extras (e.g. the drop chance "31 %") are not part of the item text
    if r.GetObjectType and r:GetObjectType() == "FontString" and r:IsShown() and r:GetLeft()
       and not r._ofaNoAnchor and not (r.GetJustifyH and r:GetJustifyH() == "RIGHT") then
      local w = math.min(r:GetStringWidth() or 0, r:GetWidth() or 0)
      textRight = math.max(textRight, r:GetLeft() + w)
    end
  end
  tipAnchor.owner = owner
  tipAnchor.xr = textRight * os + 16
  tipAnchor.xl = left * os - 8
  tipAnchor.top = top * os
  GameTooltip:ClearAllPoints()
  GameTooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", tipAnchor.xr, tipAnchor.top)
end

-- Call after GameTooltip:Show(): final placement once the size is known, and
-- again next frame in case the comparison tooltips appear a frame later.
local function finishItemTooltip()
  placeItemTooltips()
  if C_Timer and C_Timer.After then C_Timer.After(0, placeItemTooltips) end
end

tryShowItemTooltip = function(owner, item)
  local rec = normalizeDungeonItem(item)
  if not rec.name then return false end
  if rec.id then
    local cached = GetItemInfo and GetItemInfo(rec.id)
    if not cached then
      pendingTooltip = { owner=owner, item=item, id=rec.id }
      if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, rec.id) end
    else
      pendingTooltip = nil
    end
    anchorItemTooltip(owner)
    local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:"..tostring(rec.id))
    -- The beta server does not send data for every item (e.g. above the
    -- level cap). If nothing arrives within a second, show our own data
    -- instead of "Retrieving item information"; the real tooltip still
    -- replaces it as soon as GET_ITEM_INFO_RECEIVED fires.
    local p = pendingTooltip
    if p and C_Timer and C_Timer.After then
      C_Timer.After(1.0, function()
        if pendingTooltip ~= p then return end
        if not GameTooltip:IsShown() or GameTooltip:GetOwner() ~= owner then return end
        if GetItemInfo and GetItemInfo(rec.id) then return end
        anchorItemTooltip(owner)
        local q = rec.quality
        local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
        GameTooltip:AddLine(rec.name, c and c.r or 1, c and c.g or 1, c and c.b or 1)
        if rec.slot then GameTooltip:AddLine(rec.slot, 1, 1, 1) end
        if rec.summary then GameTooltip:AddLine(rec.summary, 0.85, 0.85, 0.85, true) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("The beta server does not send the details of this item yet.", 0.60, 0.60, 0.60, true)
        GameTooltip:Show(); finishItemTooltip()
      end)
    end
    if ok and (not GameTooltip.NumLines or GameTooltip:NumLines() > 0) then
      if rec.summary then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(DISPLAY_NAME, 1, 0.82, 0.20)
        GameTooltip:AddLine(rec.summary, 0.85, 0.85, 0.85, true)
      end
      GameTooltip:Show(); finishItemTooltip(); return true
    end
  end
  if GetItemInfo then
    local _, link = GetItemInfo(rec.name)
    if link then
      anchorItemTooltip(owner)
      GameTooltip:SetHyperlink(link)
      GameTooltip:Show(); finishItemTooltip()
      return true
    end
  end
  return false
end

local function tryDressUpDungeonItem(item)
  if not DressUpItemLink then return false end
  local rec=normalizeDungeonItem(item)
  if not rec or not rec.name then return false end

  local link=nil
  if GetItemInfo then
    local _,itemLink=GetItemInfo(rec.id or rec.name)
    link=itemLink
  end
  if not link and rec.id then link="item:"..tostring(rec.id) end
  if not link then return false end

  local ok=pcall(DressUpItemLink,link)
  return ok
end

-- Chat links: only real client links are used (the server drops messages with
-- self-built links). Items not cached yet are requested and inserted when ready.
-- the auction house search box when the auction house is open (new and old auction window), user 26.10.
local function auctionSearch(text)
  local name = type(text) == "string" and text:match("|h%[(.-)%]|h")
  if not name then return false end
  local ah = AuctionHouseFrame
  local bar = type(ah) == "table" and ah.IsShown and ah:IsShown() and ah.SearchBar
  if bar and bar.SearchBox then
    bar.SearchBox:SetText(name)
    if bar.StartSearch then pcall(bar.StartSearch, bar) end
    return true
  end
  local browse = BrowseName
  if type(browse) == "table" and browse.IsVisible and browse:IsVisible() then browse:SetText(name); return true end
  return false
end

local function insertChatText(text)
  if ChatEdit_InsertLink and ChatEdit_InsertLink(text) then return true end
  if auctionSearch(text) then return true end
  if ChatFrame_OpenChat then ChatFrame_OpenChat(text); return true end
  return false
end

local function linkItemInChat(rec)
  if not rec or not rec.id then return false end
  if not GetItemInfo then return false end
  local _, link = GetItemInfo(rec.id)
  if link then return insertChatText(link) end
  if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, rec.id) end
  if not (C_Timer and C_Timer.After) then return false end
  local tries = 0
  local function retry()
    tries = tries + 1
    local _, l = GetItemInfo(rec.id)
    if l then insertChatText(l)
    elseif tries < 10 then C_Timer.After(0.2, retry)
    elseif rec.name and rec.name ~= "" then insertChatText("[" .. rec.name .. "]") end
  end
  C_Timer.After(0.2, retry)
  return true
end
FLT.LinkItemInChat = function(id, name) return linkItemInChat({id = id, name = name}) end

local function handleDungeonItemClick(item,button)
  if button~="LeftButton" then return false end
  -- Shift-click: link the item in the chat (like everywhere else in the game).
  local wantsLink = (IsModifiedClick and IsModifiedClick("CHATLINK")) or (IsShiftKeyDown and IsShiftKeyDown())
  if wantsLink then
    return linkItemInChat(normalizeDungeonItem(item))
  end
  if IsControlKeyDown and IsControlKeyDown() then
    return tryDressUpDungeonItem(item)
  end
  return false
end

local function dungeonItemIcon(item)
  local rec=normalizeDungeonItem(item)
  if rec.id then
    if GetItemIcon then local tex=GetItemIcon(rec.id); if tex then return tex end end
    if C_Item and C_Item.GetItemIconByID then local ok,tex=pcall(C_Item.GetItemIconByID,rec.id); if ok and tex then return tex end end
  end
  if GetItemInfo then local _,_,_,_,_,_,_,_,_,tex=GetItemInfo(rec.name); if tex then return tex end end
  return "Interface\\Icons\\INV_Misc_QuestionMark"
end


H.QUEST_STATUS_LABELS = QUEST_STATUS_LABELS
H.getDungeonQuestStatus = getDungeonQuestStatus
H.getQuestLogInfo = getQuestLogInfo
H.getChainProgress = getChainProgress
H.dungeonSideColor = dungeonSideColor
H.normalizeDungeonItem = normalizeDungeonItem
H.colorDungeonItemText = colorDungeonItemText
H.tryShowItemTooltip = tryShowItemTooltip
H.anchorItemTooltip = anchorItemTooltip
H.finishItemTooltip = finishItemTooltip
H.handleDungeonItemClick = handleDungeonItemClick
H.dungeonItemIcon = dungeonItemIcon
