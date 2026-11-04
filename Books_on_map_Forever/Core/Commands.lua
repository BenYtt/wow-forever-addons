-- Books on map (Forever): slash commands (/bom or /books)
local _, ns = ...
local L = ns.L
local BOOKS = ns.BOOKS

local SHARE_CHANNELS = { group = true, party = "PARTY", raid = "RAID", guild = "GUILD", say = "SAY" }
local NEXT_REWARD = { [10] = "necklace", [20] = "ring", [25] = "bow, crest or light" }

-- /bom share [group|guild|say] [missing]: progress (and the missing books) in chat, plain text
local function share(rest)
  local where, missing = rest:match("^(%S*)%s*(%S*)$")
  if where == "missing" then where, missing = "", "missing" end
  local channel = SHARE_CHANNELS[where]
  if channel == true or not channel then
    channel = IsInRaid() and "RAID" or IsInGroup() and "PARTY" or (where == "" and IsInGuild() and "GUILD")
  end
  if channel == "GUILD" and not IsInGuild() then channel = nil end
  if not channel then print(ns.PREFIX .. L["not in a group or a guild: /bom share say"]) return end

  local done = ns.CountDone()
  local msg = L["Books on map: %d/%d library books"]:format(done, #BOOKS)
  for _, goal in ipairs(ns.GOALS) do
    if done < goal then
      msg = msg .. " - " .. L["next reward: %s (%d)"]:format(L[NEXT_REWARD[goal]], goal)
      break
    end
  end
  SendChatMessage(msg, channel)

  if missing == "missing" and done < #BOOKS then
    local line = L["Missing:"]
    for _, b in ipairs(BOOKS) do
      if not ns.IsDone(b) then
        if #line + #b.name + 2 > 250 then SendChatMessage((line:gsub(",$", "")), channel); line = "" end
        line = line .. (line == "" and "" or " ") .. b.name .. ","
      end
    end
    SendChatMessage((line:gsub(",$", "")), channel)
  end
end

SLASH_BOOKSONMAP1, SLASH_BOOKSONMAP2 = "/bom", "/books"
SlashCmdList.BOOKSONMAP = function(msg)
  local db = ns.db
  local cmd, rest = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
  if cmd == "reset" then
    ns.SetAll(false); print(ns.PREFIX .. L["list reset."])
  elseif cmd == "toggle" then
    db.hidden = not db.hidden; ns.Refresh()
    print(ns.PREFIX .. (db.hidden and L["map icons hidden."] or L["map icons shown."]))
  elseif cmd == "minimap" then
    db.hideMinimap = not db.hideMinimap
    ns.UpdateMinimapButton()
    ns.RefreshOptions()
  elseif (cmd == "undo" or cmd == "done") and BOOKS[tonumber(rest) or 0] then
    ns.SetDone(BOOKS[tonumber(rest)], cmd == "done")
  elseif cmd == "route" then
    if rest == "list" then ns.PrintRoute()
    elseif rest == "guide" then ns.GuideRoute()
    elseif rest == "tomtom" then ns.GuideRoute(true)
    else ns.ToggleRoute() end
  elseif cmd == "welcome" or cmd == "bvn" then
    ns.ShowWelcome()
  elseif cmd == "bug" then
    ns.ReportBug()
  elseif cmd == "next" then
    ns.GoToNearest()
  elseif cmd == "share" then
    share(rest)
  elseif cmd == "list" then
    print(ns.PREFIX .. L["%d/%d books collected"]:format(ns.CountDone(), #BOOKS))
    for i, b in ipairs(BOOKS) do
      local l = b.locs[1] or { 0, 0, 0, L["location unknown"] }
      print(("%s%2d. %s|r - %s (%.1f, %.1f)"):format(ns.IsDone(b) and "|cff00ff00" or "|cffff8080", i, b.name, l[4], l[2], l[3]))
    end
  elseif cmd == "ids" then
    -- helper to fill Data.lua: prints the itemID of every item in the bags
    ns.ForEachBagItem(function(link) print(link:match("item:(%d+)"), link) end)
  elseif cmd == "" then
    ns.ToggleOptions()
  else
    print(ns.PREFIX .. L["/bom (options) | list | next | share [group|guild|say] [missing] | done N | undo N | route [list|guide|tomtom] | toggle | minimap | welcome | bug | reset | ids"])
  end
end
