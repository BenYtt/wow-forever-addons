-- Books on map (Forever): automatic detection (bags and library turn-ins)
local _, ns = ...
local L = ns.L
local BOOKS = ns.BOOKS

local function norm(s)
  -- French client: curly apostrophe and (narrow) no-break spaces before : ? !
  return ((s or ""):gsub("’", "'"):gsub("\194\160", ""):gsub("\226\128\175", ""):lower():gsub("[%s%p]", ""))
end
-- English and French names, computed before the names are localized
for _, b in ipairs(BOOKS) do
  b.norms = { norm(b.name), b.frName and norm(b.frName) }
end

local numSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
local itemLink = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink

-- calls fn(link) for every item in the backpack and bags
function ns.ForEachBagItem(fn)
  for bag = 0, 4 do
    for slot = 1, (numSlots(bag) or 0) do
      local link = itemLink(bag, slot)
      if link then fn(link) end
    end
  end
end

-- itemID match first (any language), exact name match as fallback
local function checkItem(link)
  local id = tonumber(link:match("item:(%d+)"))
  local n = norm(link:match("%[(.-)%]"))
  for _, b in ipairs(BOOKS) do
    if not ns.IsDone(b) then
      local hit = id and b.item == id
      if not hit and n ~= "" then
        for _, bn in ipairs(b.norms) do
          if n == bn then hit = true break end
        end
      end
      if hit then ns.SetDone(b, true) end
    end
  end
end

local function scanBags()
  ns.ForEachBagItem(checkItem)
end

-- books already handed in to the library (needs b.quest)
local function scanQuests()
  local isDone = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted
  if not isDone then return end
  for _, b in ipairs(BOOKS) do
    if b.quest and not ns.IsDone(b) and isDone(b.quest) then ns.SetDone(b, true, true) end
  end
end

-- Item tooltips: "Library book - collected / missing (set)" -----------------
local bookByItem = {}

local function addBookLine(tt, link)
  local b = link and bookByItem[tonumber(link:match("item:(%d+)"))]
  if not b then return end
  local set = b.set == 1 and L["Starting set"] or L[("Level %d set"):format(b.set)]
  tt:AddLine(("|cff5cc8ff%s|r - %s |cff7f90ab(%s)|r"):format(L["Library book"],
    ns.IsDone(b) and L["|cff00ff00collected|r"] or ("|cffff5555" .. L["missing"] .. "|r"), set))
  tt:Show()
end

-- (at login: the other faction's books are already removed)
local function hookTooltips()
  for _, b in ipairs(BOOKS) do
    if b.item then bookByItem[b.item] = b end
  end
  if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt)
      if tt.GetItem then addBookLine(tt, select(2, tt:GetItem())) end
    end)
    return
  end
  for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
    tt:HookScript("OnTooltipSetItem", function(self) addBookLine(self, select(2, self:GetItem())) end)
  end
end

-- Events (registered at PLAYER_LOGIN, once the saved state is loaded) ---
function ns.InitDetection()
  -- itemIDs learned by the old proximity fallback (could be wrong, e.g. Stonewrought Design learned as Magma or Lava?)
  ns.db.itemIDs = nil
  local f = CreateFrame("Frame")
  f:RegisterEvent("BAG_UPDATE_DELAYED")
  f:RegisterEvent("QUEST_TURNED_IN")
  f:SetScript("OnEvent", function(_, event, questID)
    if event == "QUEST_TURNED_IN" then
      for _, b in ipairs(BOOKS) do
        if b.quest == questID then ns.SetDone(b, true) end
      end
    else
      scanBags()
    end
  end)
  scanQuests()
  scanBags()
  hookTooltips()
end
