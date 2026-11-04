-- Item API: newer clients only have these under C_Item.
local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)
local ADDON, FLT = ...

local function msg(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff" .. tostring(FLT.DISPLAY_NAME or "OneForAll") .. ":|r " .. tostring(text))
end
FLT.Msg = msg

-- Safe calls for event handlers: an error is caught instead of popping up again and
-- again (e.g. in combat, when the Forever client hands out "secret" values). The
-- last errors are kept in OneForAllDB.errors; /ofa errors prints them so
-- players can copy them into a bug report.
local errorSaid = false
local function logError(tag, err)
  local db = type(OneForAllDB) == "table" and OneForAllDB
  if db then
    db.errors = db.errors or {}
    local ver = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")) or "?"
    local line = string.format("%s | %s | %s | %s | %s", date and date("%Y-%m-%d %H:%M") or "", tostring(ver), GetLocale and GetLocale() or "?", tostring(tag), tostring(err))
    if db.errors[1] ~= line then table.insert(db.errors, 1, line) end
    while #db.errors > 20 do table.remove(db.errors) end
  end
  if not errorSaid then
    errorSaid = true
    msg("An error was caught and the feature skipped. Type /ofa errors to see it (for a bug report).")
  end
end
function FLT.SafeCall(tag, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then logError(tag, err) end
  return ok
end
-- true when any of the values is a "secret" (newer clients hide some values in combat)
function FLT.IsSecret(...)
  if not issecretvalue then return false end
  for i = 1, select("#", ...) do if issecretvalue((select(i, ...))) then return true end end
  return false
end

local function numSlots(bag)
  if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) or 0 end
  if GetContainerNumSlots then return GetContainerNumSlots(bag) or 0 end
  return 0
end

local function itemID(bag, slot)
  if C_Container and C_Container.GetContainerItemID then return C_Container.GetContainerItemID(bag, slot) end
  if GetContainerItemID then return GetContainerItemID(bag, slot) end
  local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
  if link then return tonumber(link:match("item:(%d+)")) end
end

function FLT:IsQuestDone(qid)
  if not qid then return false end
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then return C_QuestLog.IsQuestFlaggedCompleted(qid) and true or false end
  if IsQuestFlaggedCompleted then return IsQuestFlaggedCompleted(qid) and true or false end
  return false
end

function FLT:FindBookByQuestID(qid)
  qid = tonumber(qid)
  if not qid then return nil end
  for _, book in ipairs(self.BOOKS) do
    if book.questId == qid then return book end
  end
end

function FLT:RecordObservedTurnIn(qid)
  local book = self:FindBookByQuestID(qid)
  if not book then return end
  OneForAllCharDB.confirmedDone[book.itemId] = true
  msg(string.format("Confirmed turn-in: %s (quest %d).", book.name, book.questId))
end

function FLT:ScanBags()
  -- reuse the table: bag updates come often
  self.bagItems = self.bagItems or {}
  for k in pairs(self.bagItems) do self.bagItems[k] = nil end
  for bag = 0, 4 do
    for slot = 1, numSlots(bag) do
      local id = itemID(bag, slot)
      if id then self.bagItems[id] = true end
    end
  end
end

function FLT:ScanBank()
  self.bankItems = self.bankItems or {}
  wipe(self.bankItems)
  local bags = {-1, 5, 6, 7, 8, 9, 10, 11}
  for _, bag in ipairs(bags) do
    for slot = 1, numSlots(bag) do
      local id = itemID(bag, slot)
      if id then self.bankItems[id] = true end
    end
  end
  OneForAllCharDB.bankItems = self.bankItems
  OneForAllCharDB.bankScanned = time()
end

-- Deliberately conservative completion logic:
-- "done" is only used after this addon actually observed QUEST_TURNED_IN.
-- The server quest-completion flag is still shown, but as "questflag" because
-- some Forever beta characters appear to report unexpected completion flags.
function FLT:GetBookState(book)
  if OneForAllCharDB.confirmedDone[book.itemId] then return "done" end
  if OneForAllCharDB.manualDone[book.itemId] then return "manual" end
  if self.bagItems and self.bagItems[book.itemId] then return "bag" end
  if self.bankItems and self.bankItems[book.itemId] then return "bank" end
  if self:IsQuestDone(book.questId) then return "questflag" end
  return "missing"
end

function FLT:GetCounts()
  local done, owned = 0, 0
  for _, b in ipairs(self.BOOKS) do
    local s = self:GetBookState(b)
    if s == "done" then
      done = done + 1
      owned = owned + 1
    elseif s == "manual" or s == "bag" or s == "bank" then
      owned = owned + 1
    end
  end
  return done, owned
end

function FLT:GetItemStorageState(id)
  if not id then return "unknown" end
  if self.bagItems and self.bagItems[id] then return "bag" end
  if self.bankItems and self.bankItems[id] then return "bank" end
  return "missing"
end


function FLT:GetRecipeFullName(recipe)
  if not recipe then return nil end
  return ((self.RECIPE_PREFIX or {})[recipe.profession] or "") .. (recipe.name or "")
end

function FLT:RequestRecipeItemData(id)
  id = tonumber(id)
  if not id then return end
  if C_Item and C_Item.RequestLoadItemDataByID then
    pcall(C_Item.RequestLoadItemDataByID, id)
  elseif GetItemInfo then
    -- On older clients, querying by ID itself starts the server cache request.
    pcall(GetItemInfo, id)
  end
end

function FLT:GetRecipeItemLink(recipe)
  local id = self:GetRecipeItemID(recipe)
  if not id then return nil end
  self:RequestRecipeItemData(id)
  local _, link = GetItemInfo(id)
  return link or ("item:" .. tostring(id))
end

function FLT:Refresh()
  self:ScanBags()
  if self.UIRefresh then self:UIRefresh() end
  if self.MapLandmarks and self.MapLandmarks.BooksChanged then self.MapLandmarks.BooksChanged() end
end

function FLT:PrintDebug()
  msg("Debug: books where the server says the quest is completed but this addon did not observe the turn-in:")
  local n = 0
  for _, book in ipairs(self.BOOKS) do
    if self:IsQuestDone(book.questId) and not OneForAllCharDB.confirmedDone[book.itemId] then
      n = n + 1
      msg(string.format("%s | quest=%d | item=%d | state=%s", book.name, book.questId, book.itemId, self:GetBookState(book)))
    end
  end
  if n == 0 then msg("No unverified quest-completion flags found.") end
end

-- 5.6.2: own SavedVariables names. Up to 5.6.1 they were ForeverCompanionDB / ForeverCompanionCharDB
-- (from the old addon name), the same names as the addon "Forever Companion: Discovery Journal": both
-- addons then shared one table and our data replaced the journal's at every login or /reload.
-- This chunk runs before our SavedVariables are loaded, so whatever is in the old globals now belongs
-- to another addon. At ADDON_LOADED we take our old data over once and hand those globals back.
-- (The old names stay in the .toc for the 5.6 versions so old data can be moved; remove them in 5.7.)
local OLD_DB, OLD_CHAR = "ForeverCompanionDB", "ForeverCompanionCharDB"
local foreignDB, foreignChar = _G[OLD_DB], _G[OLD_CHAR]
local function moveOldSavedVariables()
  local old, oldChar = _G[OLD_DB], _G[OLD_CHAR]
  if OneForAllDB == nil and type(old) == "table" and old ~= foreignDB then OneForAllDB = old end
  if OneForAllCharDB == nil and type(oldChar) == "table" and oldChar ~= foreignChar then OneForAllCharDB = oldChar end
  _G[OLD_DB], _G[OLD_CHAR] = foreignDB, foreignChar
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("BANKFRAME_OPENED")
f:RegisterEvent("BANKFRAME_CLOSED")
f:RegisterEvent("QUEST_TURNED_IN")
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    moveOldSavedVariables()
    -- Migrate settings/progress from the old Forever Library Tracker name.
    if not OneForAllDB and ForeverLibraryTrackerDB then OneForAllDB = ForeverLibraryTrackerDB end
    OneForAllDB = OneForAllDB or {}

    -- Book progress and bank contents are per character (SavedVariablesPerCharacter).
    -- Before 4.3 they were stored account-wide: the first character that logs
    -- in with 4.3 takes over the old turn-ins/manual marks. The old bank scan is
    -- dropped because it may belong to another character; it is rebuilt on the
    -- next bank visit.
    OneForAllCharDB = OneForAllCharDB or {}
    local char = OneForAllCharDB
    if not char.initialized then
      if OneForAllDB.confirmedDone or OneForAllDB.manualDone then
        char.confirmedDone = OneForAllDB.confirmedDone
        char.manualDone = OneForAllDB.manualDone
      end
      char.initialized = true
    end
    OneForAllDB.confirmedDone = nil
    OneForAllDB.manualDone = nil
    OneForAllDB.bankItems = nil
    OneForAllDB.bankScanned = nil
    char.manualDone = char.manualDone or {}
    char.confirmedDone = char.confirmedDone or {}
    char.bankItems = char.bankItems or {}
    OneForAllDB.recipeItemIDs = nil -- obsolete merchant cache (pre-4.1.2)
    OneForAllDB.talentPlans = OneForAllDB.talentPlans or {}
    FLT.bankItems = char.bankItems
    -- 6.0.1: the character's profile (UI/Profiles.lua) into the live settings, before the first-start defaults
    if FLT.Profiles then FLT.Profiles.Load() end
    -- 5.6.2: first start (no Quality of Life settings yet): these options start switched on
    -- (chosen by the user 16.10.); existing installs keep what they have
    if OneForAllDB.qol == nil then
      OneForAllDB.qol = {
        quickLoot = true, bagsFull = true,
        lootFeed = true, lootFeedMoney = true, lootFeedQuality = 0,
        questSparkles = true,
        bossDrops = true, recipeTip = true, unitTarget = true,
        classColors = true, thanksBuff = true,
        bagSlots = true, questXP = true, durability = true, copyChat = true, mmCollect = true,
        cameraZoom = true, moveWindows = true, -- 5.7.0 (user 22.10.)
      }
    end
    if OneForAllDB.nearbyAlertsEnabled == nil then OneForAllDB.nearbyAlertsEnabled = true end
    -- 5.7.3: one skin only (Gold Modern, user 27.10.); old skin choices are not read any more - clear them
    OneForAllDB.skin, OneForAllDB.frameStyle, OneForAllDB.skinDefault561 = nil, nil, nil
  elseif event == "PLAYER_LOGIN" then
    FLT:Refresh()
    if FLT.CreateMinimapButton then FLT:CreateMinimapButton() end
    if FLT.StartNearbyMonitor then FLT:StartNearbyMonitor() end
  elseif event == "BAG_UPDATE_DELAYED" then
    FLT:Refresh()
  elseif event == "QUEST_TURNED_IN" then
    FLT:RecordObservedTurnIn(arg1)
    FLT:Refresh()
  elseif event == "BANKFRAME_OPENED" then
    FLT:ScanBank(); FLT:Refresh()
  elseif event == "BANKFRAME_CLOSED" then
    FLT:Refresh()
  end
end)

SLASH_ONEFORALL1 = "/oneforall"
SLASH_ONEFORALL2 = "/ofa"
SLASH_ONEFORALL3 = "/forever"
SLASH_ONEFORALL4 = "/flt"
SLASH_ONEFORALL5 = "/librarybooks"
SlashCmdList.ONEFORALL = function(cmd)
  cmd = (cmd or ""):lower():match("^%s*(.-)%s*$")
  if cmd == "reset" then
    OneForAllCharDB.manualDone = {}
    msg("Manual marks reset. Observed turn-ins are kept.")
    FLT:Refresh()
  elseif cmd == "craft" then
    if FLT.CraftList then FLT.CraftList.Toggle() end
  elseif cmd == "where" then
    -- Prints the current map and coordinates, to correct map pins in the data.
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    local info = mapID and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    if pos then
      local x, y = pos:GetXY()
      msg(string.format("%s (mapID %d): %.1f, %.1f", info and info.name or "?", mapID, x * 100, y * 100))
    else
      msg("No map position available here (e.g. inside an instance).")
    end
  elseif cmd == "scale" or cmd:match("^scale%s") then
    local value = cmd:match("^scale%s+([%d%.]+)")
    if FLT.SetWindowScale then
      local applied = FLT:SetWindowScale(value)
      msg(string.format("Window size set to %d%%.%s", math.floor(applied * 100 + 0.5), value and "" or " Position reset to the screen center."))
    end
  elseif cmd == "tabs reset" then
    if FLT.UI and FLT.UI.ResetTabs then FLT.UI.ResetTabs() end
    msg("Tab selection reset to the defaults for this character.")
  elseif cmd == "share test" then
    if FLT.QuestShareTest then FLT:QuestShareTest() end
  elseif cmd == "questmarks test" then
    if FLT.QuestMarks then FLT.QuestMarks.Test() end
  elseif cmd == "chathistory" then
    if FLT.QoL and FLT.QoL.ChatHistoryInfo then FLT.QoL.ChatHistoryInfo() end
  elseif cmd == "share" then
    if FLT.OpenQuestShare then FLT:OpenQuestShare() end
  elseif cmd == "share on" or cmd == "share off" then
    if FLT.SetQuestShareOption then FLT:SetQuestShareOption("popup", cmd == "share on") end
    msg("Quest share popup " .. (cmd == "share on" and "enabled." or "disabled. /ofa share still opens it manually."))
  elseif cmd == "share emote on" or cmd == "share emote off" then
    if FLT.SetQuestShareOption then FLT:SetQuestShareOption("emote", cmd == "share emote on") end
    msg("Share emote " .. (cmd == "share emote on" and "enabled." or "disabled."))
  elseif cmd == "mem" then
    -- memory check: the number includes garbage that Lua has not freed yet
    local get = (C_AddOns and C_AddOns.GetAddOnMemoryUsage) or GetAddOnMemoryUsage
    if UpdateAddOnMemoryUsage then UpdateAddOnMemoryUsage() end
    local kb = get and get("OneForAll")
    if kb then msg(string.format("Memory: %.1f MB (includes garbage the game has not cleaned up yet).", kb / 1024)) end
  elseif cmd == "trainer" then
    if FLT.PrintTrainerDebug then FLT.PrintTrainerDebug() end
  elseif cmd == "buttons" then
    if FLT.PrintMinimapCollector then FLT.PrintMinimapCollector() end
  elseif cmd == "errors" then
    local list = type(OneForAllDB) == "table" and OneForAllDB.errors
    if not list or #list == 0 then msg("No errors caught.") else
      msg(#list .. " caught error(s), newest first (date | version | client language | where | error):")
      for i = 1, math.min(10, #list) do msg("  " .. list[i]) end
    end
  elseif cmd == "errors clear" then
    if type(OneForAllDB) == "table" then OneForAllDB.errors = nil end
    msg("Caught errors cleared.")
  elseif cmd == "bug" then
    if FLT.UI and FLT.UI.ShowBugReport then FLT.UI.ShowBugReport() end
  elseif cmd == "rolltest" then
    if FLT.GearMarks then FLT.GearMarks.RollTest() end
  elseif cmd == "questtest" then
    if FLT.GearMarks then FLT.GearMarks.QuestTest() end
  elseif cmd == "cheapest" then
    if FLT.QoL and FLT.QoL.PrintCheapest then FLT.QoL.PrintCheapest() end
  elseif cmd == "thanks" then
    if FLT.QoL and FLT.QoL.PrintThanksLog then FLT.QoL.PrintThanksLog() end
  elseif cmd == "petscan" then
    if FLT.ScanPetAbilities then FLT.ScanPetAbilities() end
    local t = type(OneForAllCharDB) == "table" and OneForAllCharDB.petAbilities or {}
    local parts = {}
    for name, rank in pairs(t) do parts[#parts + 1] = name .. " " .. rank end
    table.sort(parts)
    msg(#parts > 0 and ("Known pet abilities: " .. table.concat(parts, ", ")) or "No pet abilities found yet - summon your pet and try again.")
  elseif cmd == "news" then
    if FLT.ShowNews then FLT.ShowNews() end
  elseif cmd == "setup" then
    if FLT.ShowWelcome then FLT.ShowWelcome() end
  elseif cmd == "channel" then
    local st = FLT.RecipeShareStatus and FLT.RecipeShareStatus()
    if not st then return end
    if not st.enabled then msg("Recipe sharing with other OneForAll users is off (Settings).") return end
    msg(string.format("Recipe channel: %s. Other users online: %d, known recipe holders: %d. Own status sent: %s (every %d min).%s",
      st.channel and ("joined as channel " .. st.channel) or ("not joined (" .. st.tries .. " tries)"),
      st.online, st.known, st.lastStatus and (st.lastStatus .. " s ago") or "not yet", math.floor((st.every or 600) / 60),
      st.queued > 0 and (" Waiting to send: " .. st.queued .. ".") or ""))
    if st.recv then
      msg(string.format("Received: %d messages (this minute %d, peak %d per minute), dropped %d. Searches %d, players found %d, answers sent %d.",
        st.recv, st.recvMin, st.recvPeak, st.dropped, st.searches, st.hits, st.answers))
    end
  elseif cmd == "profscan" then
    if not FLT.ScanProfessions then return end
    local r = FLT.ScanProfessions()
    local l = r.last or {}
    msg(string.format("Profession scan: new API %s, old API %s, profession API %s. Last: %s, %d recipes read, %d matched, skill %s.",
      tostring(r.newAPI), tostring(r.oldAPI), tostring(r.profAPI), tostring(l.prof or "none"), l.count or 0, l.matched or 0, tostring(l.skill)))
    if l.foreign then msg("The last profession window showed another player's recipes (a link or guild member) - not stored.") end
    local st = l.stats
    if st then msg(string.format("Recipe list: %d ids, learned %d, not learned %d, no flag %d, no info %d.", st.ids, st.yes, st.no, st.noField, st.noInfo)) end
  elseif cmd == "talentdump" then
    if not FLT.DumpTalents then return end
    local classes, talents = FLT:DumpTalents()
    if not classes then
      msg("Talent dump failed: " .. tostring(talents))
    else
      msg(string.format("Talent dump saved: %d classes, %d talents. Type /reload (or log out), then send WTF\\Account\\<account>\\SavedVariables\\OneForAll.lua.", classes, talents))
    end
  elseif cmd == "debug" then
    FLT:PrintDebug()
  elseif cmd == "portraits" then
    if FLT.PrintPortraitDebug then FLT:PrintPortraitDebug() else msg("Portrait diagnostics are not available until the UI module has loaded.") end
  elseif cmd == "bank" then
    msg("Bank status is refreshed whenever you open your bank. The last successful scan is kept after closing it.")
  elseif cmd == "profdb" or cmd == "profdata" then
    local resolved, total = FLT:GetProfessionResolutionCount()
    msg(string.format("Profession data: standalone and embedded. %d/%d Merchant's Favor recipes have built-in result mappings.", resolved, total))
  else
    if FLT.ToggleUI then FLT:ToggleUI() end
  end
end
