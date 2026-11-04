-- Books on map (Forever): group mode (party/raid members with the addon share their progress)
local ADDON, ns = ...
local L = ns.L
local BOOKS = ns.BOOKS

local PREFIX = "BooksOnMapFE"
local SEND_DELAY = 1 -- seconds: several changes in a row make one message

local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local VERSION = getMeta(ADDON, "Version") or "?"

-- message: "S<book count>:<one 0/1 per book, in data order>:<addon version>" (state) or "R" (state request)
local members = {} -- short name -> bits string
local others = {}  -- short name -> addon version, for players whose addon has another book list
local versions = {} -- short name -> addon version, for the members who share their books
local index = {}   -- book -> position in BOOKS
for i, b in ipairs(BOOKS) do index[b] = i end

-- full character name without the realm: on WoW Forever names are compound ("Daeler Backbï"),
-- so only a "-Realm" suffix is dropped (several alts share the same first name)
local function shortName(name)
  return (name:gsub("%-[^%-]*$", ""))
end

-- full name of a unit: on WoW Forever UnitName returns the surname as the realm ("Daeler", "Backbï")
local function unitFullName(unit)
  local name, surname = UnitName(unit)
  if name and surname and surname ~= "" then return name .. " " .. surname end
  return name
end
ns.PlayerFullName = function() return unitFullName("player") end

local function channel()
  if IsInRaid() then return "RAID" elseif IsInGroup() then return "PARTY" end
end

local function send(msg)
  local ch = channel()
  if ch and C_ChatInfo and C_ChatInfo.SendAddonMessage then C_ChatInfo.SendAddonMessage(PREFIX, msg, ch) end
end

local function encode()
  local bits = {}
  for i, b in ipairs(BOOKS) do bits[i] = ns.IsDone(b) and "1" or "0" end
  return ("S%d:%s:%s"):format(#BOOKS, table.concat(bits), VERSION)
end

-- sends our progress (and optionally asks for theirs) once, after SEND_DELAY
local pending, pendingRequest
function ns.SendGroupState(request)
  if not channel() then return end
  pendingRequest = pendingRequest or request
  if pending then return end
  pending = true
  C_Timer.After(SEND_DELAY, function()
    pending = false
    send(encode())
    if pendingRequest then send("R") end
    pendingRequest = nil
  end)
end

-- forgets the players who left the group
local function prune()
  local inGroup, changed = {}, false
  for _, name in ipairs(ns.GroupRoster()) do inGroup[name] = true end
  for _, list in ipairs({ members, others, versions }) do
    for name in pairs(list) do
      if not inGroup[name] then list[name] = nil; changed = true end
    end
  end
  if changed then ns.Refresh() end
end

-- Queries ----------------------------------------------------------------
local function sortedNames()
  local names = {}
  for name in pairs(members) do names[#names + 1] = name end
  table.sort(names)
  return names
end

local function has(name, b)
  return members[name]:sub(index[b], index[b]) == "1"
end

-- for the group panel
ns.GroupNames, ns.GroupHas = sortedNames, has
ns.ADDON_VERSION = VERSION

-- addon version of a group member whose addon has another book list, or nil
function ns.GroupOtherVersion(name) return others[name] end

-- addon version of a member who shares their books, or nil
function ns.GroupVersion(name) return versions[name] end

-- full names of the other group members, sorted
function ns.GroupRoster()
  local list, me = {}, unitFullName("player")
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local name = unitFullName("raid" .. i)
      if name and name ~= me then list[#list + 1] = name end
    end
  else
    for i = 1, GetNumSubgroupMembers() do
      local name = unitFullName("party" .. i)
      if name then list[#list + 1] = name end
    end
  end
  table.sort(list)
  return list
end

-- true when a group member still needs this book (and the option is on)
function ns.GroupNeeds(b)
  if ns.db.hideGroupBooks then return end
  for name in pairs(members) do
    if not has(name, b) then return true end
  end
end

-- "Group:" lines in the tooltip: who has the book, who is missing it
function ns.AddGroupTooltip(b)
  local names = sortedNames()
  if #names == 0 then return end
  GameTooltip:AddLine(L["Group:"], 0.4, 0.8, 1)
  for _, name in ipairs(names) do
    if has(name, b) then
      GameTooltip:AddDoubleLine("  " .. name, L["collected"], 1, 1, 1, 0.1, 1, 0.1)
    else
      GameTooltip:AddDoubleLine("  " .. name, L["missing"], 1, 1, 1, 1, 0.3, 0.3)
    end
  end
end

-- "Name: 12/39" lines for each member
function ns.AddGroupProgressTooltip(tt)
  tt = tt or GameTooltip
  local names = sortedNames()
  if #names == 0 then return end
  tt:AddLine(L["Group:"], 0.4, 0.8, 1)
  for _, name in ipairs(names) do
    local _, n = members[name]:gsub("1", "")
    tt:AddDoubleLine("  " .. name, ("%d/%d"):format(n, #BOOKS), 1, 1, 1, 1, 1, 1)
  end
end

-- Events -----------------------------------------------------------------
function ns.InitGroup()
  if not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) then return end
  C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
  local f = CreateFrame("Frame")
  f:RegisterEvent("CHAT_MSG_ADDON")
  f:RegisterEvent("GROUP_ROSTER_UPDATE")
  f:SetScript("OnEvent", function(_, event, prefix, msg, _, sender)
    if event == "GROUP_ROSTER_UPDATE" then
      prune()
      ns.RefreshGroupPanel() -- "not in a group" message
      ns.SendGroupState(true)
      return
    end
    if prefix ~= PREFIX then return end
    local name = shortName(sender)
    if name == unitFullName("player") then return end
    if msg == "R" then
      ns.SendGroupState()
    else
      local n, bits, version = msg:match("^S(%d+):([01]+):?(.*)$")
      if n and tonumber(n) == #BOOKS and #bits == #BOOKS then
        version = version ~= "" and version or nil
        if members[name] ~= bits or others[name] or versions[name] ~= version then
          members[name], others[name], versions[name] = bits, nil, version
          ns.Refresh()
        end
      else
        -- the addon with another book list (older or newer): listed, books not shared
        version = version and version ~= "" and version or "?"
        if others[name] ~= version or members[name] then
          members[name], others[name], versions[name] = nil, version, nil
          ns.Refresh()
        end
      end
    end
  end)
  ns.SendGroupState(true)
end
