local _, FLT = ...
local UI = FLT.UI

-- Profiles (6.0.1, user 31.10.2026): a profile holds the Settings options, the Quality of Life options and the
-- shown tabs + their order - not the window size / position and no collected data.
-- Saved account-wide in OneForAllDB.profiles[name]; each character picks one (OneForAllCharDB.profile, new
-- characters "Default"). The live tables stay where they are: at ADDON_LOADED the character's profile is copied
-- into them, at PLAYER_LOGOUT (also on /reload) they are copied back into that profile. Switching copies the new
-- profile in and reloads via the secure "/reload" button of UI.Confirm (ReloadUI is protected in Forever).
-- Sharing: a text string to copy / paste, or addon messages to one player in chunks (only if they switched
-- receiving on); the receiver must confirm, and a received profile is only saved, never switched to.

local P = {}
FLT.Profiles = P
local DEFAULT = "Default"
local SCALARS = { "versionNotice", "dungeonRecipes", "nearbyAlertsEnabled", "dungeonMapKey", "petTeachAlerts",
  "recipeShowOffline", "recipeShareChannel" }
local BROWSE = { "hiddenBrackets", "onlyFit", "highFirst" } -- the dungeon list options shown in Settings

local function copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = copy(x) end
  return t
end

local function store()
  OneForAllDB.profiles = OneForAllDB.profiles or {}
  return OneForAllDB.profiles
end

-- live settings -> profile table
local function snapshot()
  local d, c = OneForAllDB, OneForAllCharDB or {}
  local p = { qol = copy(d.qol), tabs = copy(c.tabs), tabOrder = copy(c.tabOrder),
    windowAlpha = type(d.window) == "table" and d.window.alpha or nil }
  for _, k in ipairs(SCALARS) do p[k] = d[k] end
  if type(d.dungeonBrowse) == "table" then
    p.browse = {}
    for _, k in ipairs(BROWSE) do p.browse[k] = copy(d.dungeonBrowse[k]) end
  end
  return p
end

-- profile table -> live settings (an empty profile = the defaults)
local function apply(p)
  local d, c = OneForAllDB, OneForAllCharDB
  d.qol = copy(p.qol)
  for _, k in ipairs(SCALARS) do d[k] = p[k] end
  d.dungeonBrowse = d.dungeonBrowse or {}
  for _, k in ipairs(BROWSE) do d.dungeonBrowse[k] = copy(p.browse and p.browse[k]) end
  if type(d.window) == "table" or p.windowAlpha then d.window = d.window or {}; d.window.alpha = p.windowAlpha end
  c.tabs, c.tabOrder = copy(p.tabs), copy(p.tabOrder)
end

-- renamed profiles: other characters still hold the old name (their CharDB cannot be reached from here)
local function resolve(name)
  local list, ren = store(), OneForAllDB.profileRenames
  for _ = 1, 8 do
    if list[name] or type(ren) ~= "table" or not ren[name] then break end
    name = ren[name]
  end
  return list[name] and name or DEFAULT
end

function P.Active()
  return type(OneForAllCharDB) == "table" and OneForAllCharDB.profile or DEFAULT
end

-- Core.lua, ADDON_LOADED (before the first-start defaults, so an empty profile gets them)
function P.Load()
  local list = store()
  if not list[DEFAULT] then list[DEFAULT] = snapshot() end -- first start with profiles: the current settings
  local name = resolve(OneForAllCharDB.profile or DEFAULT)
  OneForAllCharDB.profile = name
  apply(list[name])
end

function P.Save()
  if type(OneForAllDB) ~= "table" or type(OneForAllCharDB) ~= "table" then return end
  store()[P.Active()] = snapshot()
end

function P.Names()
  local out = {}
  for name in pairs(store()) do out[#out + 1] = name end
  table.sort(out, function(a, b) if a == DEFAULT then return true elseif b == DEFAULT then return false end return a:lower() < b:lower() end)
  return out
end

local function clean(name)
  name = tostring(name or ""):gsub("|", ""):gsub("[%c]", ""):match("^%s*(.-)%s*$")
  return name:sub(1, 32)
end
local function freeName(name)
  local list, base, n = store(), name, 2
  while list[name] do name = base .. " " .. n; n = n + 1 end
  return name
end

-- switch this character to a profile; the interface reloads (secure "/reload" button)
function P.Switch(name)
  if InCombatLockdown and InCombatLockdown() then FLT.Msg("Profiles cannot be switched in combat."); return end
  if not store()[name] or name == P.Active() then return end
  UI.Confirm("Switch this character to the profile |cffffd100" .. name .. "|r?\nThe interface reloads.", function()
    P.Save()
    OneForAllCharDB.profile = name
    apply(store()[name])
  end, "Reload", "/reload")
end

-- after New / Copy / Import: offer to switch right away
local function offerSwitch(name, what)
  if InCombatLockdown and InCombatLockdown() then FLT.Msg(what .. " Switch to it in Settings > Profiles."); return end
  UI.Confirm(what .. "\nSwitch this character to it now? The interface reloads.", function()
    P.Save()
    OneForAllCharDB.profile = name
    apply(store()[name])
  end, "Switch", "/reload")
end

-- Text format ----------------------------------------------------------------
-- {..} table, n<number>; s<text>; (other characters as ~XX), t / f booleans. Only letters, digits and a few
-- signs, so it survives chat boxes and addon messages. Read back with our own parser (never run as code).
local function esc(s) return (s:gsub("[^%w_%.%-]", function(ch) return string.format("~%02X", ch:byte()) end)) end
local function ser(v, out)
  local t = type(v)
  if t == "table" then
    out[#out + 1] = "{"
    for k, x in pairs(v) do
      local tk, tx = type(k), type(x)
      if (tk == "string" or tk == "number") and (tx == "table" or tx == "string" or tx == "number" or tx == "boolean") then
        ser(k, out); ser(x, out)
      end
    end
    out[#out + 1] = "}"
  elseif t == "number" then out[#out + 1] = "n" .. tostring(v) .. ";"
  elseif t == "boolean" then out[#out + 1] = v and "t" or "f"
  else out[#out + 1] = "s" .. esc(tostring(v)) .. ";" end
end

local function parse(str)
  local pos, depth = 1, 0
  local function value()
    local ch = str:sub(pos, pos)
    if ch == "{" then
      depth = depth + 1
      if depth > 8 then error("deep") end
      pos = pos + 1
      local t = {}
      while str:sub(pos, pos) ~= "}" do
        if pos > #str then error("end") end
        local k = value()
        if type(k) == "table" or type(k) == "boolean" then error("key") end
        t[k] = value()
      end
      pos = pos + 1; depth = depth - 1
      return t
    elseif ch == "t" or ch == "f" then pos = pos + 1; return ch == "t"
    elseif ch == "n" or ch == "s" then
      local e = str:find(";", pos, true)
      if not e then error("end") end
      local raw = str:sub(pos + 1, e - 1); pos = e + 1
      if ch == "n" then return tonumber(raw) or error("num") end
      return (raw:gsub("~(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
    end
    error("char")
  end
  local ok, v = pcall(value)
  if ok and pos == #str + 1 then return v end
end

-- keep only what a profile may hold, with the right types
local function sanitize(p)
  if type(p) ~= "table" then return end
  local out = {}
  local defs = FLT.QoL and FLT.QoL.DEFAULTS or {}
  if type(p.qol) == "table" then
    out.qol = {}
    for k, v in pairs(p.qol) do
      if type(k) == "string" and (defs[k] == nil or type(defs[k]) == type(v)) then out.qol[k] = v end
    end
  end
  for _, k in ipairs(SCALARS) do if type(p[k]) == "boolean" then out[k] = p[k] end end
  if type(p.windowAlpha) == "number" then out.windowAlpha = math.max(0.7, math.min(1, p.windowAlpha)) end
  if type(p.tabs) == "table" then
    out.tabs = {}
    for k, v in pairs(p.tabs) do if type(k) == "string" and type(v) == "boolean" then out.tabs[k] = v end end
  end
  if type(p.tabOrder) == "table" then
    out.tabOrder = {}
    for _, v in ipairs(p.tabOrder) do if type(v) == "string" then out.tabOrder[#out.tabOrder + 1] = v end end
  end
  if type(p.browse) == "table" then
    out.browse = { onlyFit = p.browse.onlyFit == true or nil, highFirst = p.browse.highFirst == true or nil }
    if type(p.browse.hiddenBrackets) == "table" then
      out.browse.hiddenBrackets = {}
      for k, v in pairs(p.browse.hiddenBrackets) do if v == true then out.browse.hiddenBrackets[k] = true end end
    end
  end
  return out
end

local HEAD = "OFAP1:"
local function encode(name)
  local p = name == P.Active() and snapshot() or store()[name]
  local out = { HEAD }
  ser({ n = name, p = p }, out)
  return table.concat(out)
end
local function decode(str)
  str = tostring(str or ""):gsub("%s", "")
  if str:sub(1, #HEAD) ~= HEAD then return end
  local v = parse(str:sub(#HEAD + 1))
  local p = type(v) == "table" and sanitize(v.p)
  if p then return p, clean(v.n) end
end

local function addProfile(name, p)
  name = freeName(clean(name) ~= "" and clean(name) or "Imported")
  store()[name] = p
  return name
end

-- Sending (addon messages) -------------------------------------------------------
-- Only to single players (no guild, user 31.10.). The receiver must have "Receive shared profiles" on
-- (OneForAllDB.profileReceive, account-wide, default OFF - user 31.10.):
--   sender "Q:<id>"  ->  receiver "A:<id>" (allowed) or "N:<id>" (switched off)  ->  sender "<id>:<i>:<n>:<part>" ...
-- Parts are only taken from a sender the receiver said yes to; no answer within 5 s = offline / no OneForAll.
local PREFIX, CHUNK = "OFAProfile", 230
local sendSerial, incoming, outgoing, allowed = 0, {}, {}, {}
local function short(name) return (tostring(name or "?"):gsub("%-.*", "")) end
local function addonSend(msg, target)
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "WHISPER", target) end
end
function P.ReceiveEnabled() return type(OneForAllDB) == "table" and OneForAllDB.profileReceive == true end
function P.SetReceive(v) if type(OneForAllDB) == "table" then OneForAllDB.profileReceive = v and true or nil end end

function P.Send(name, target)
  if not store()[name] or not target or target == "" then return end
  sendSerial = (sendSerial % 99) + 1
  local id = sendSerial
  outgoing[id] = { data = encode(name), target = target, name = name }
  addonSend("Q:" .. id, target)
  C_Timer.After(5, function()
    if outgoing[id] then
      outgoing[id] = nil
      FLT.Msg(string.format("%s did not answer (offline, or no OneForAll 6.0.1 or newer).", target))
    end
  end)
end
local function sendParts(id)
  local o = outgoing[id]; outgoing[id] = nil
  if not o then return end
  local n = math.ceil(#o.data / CHUNK)
  for i = 1, n do
    local part = string.format("%d:%d:%d:%s", id, i, n, o.data:sub((i - 1) * CHUNK + 1, i * CHUNK))
    -- a short gap between the parts, so the server does not drop them
    C_Timer.After((i - 1) * 0.15, function() addonSend(part, o.target) end)
  end
  FLT.Msg(string.format("Profile \"%s\" sent to %s. They are asked whether to save it.", o.name, o.target))
end

local function received(sender, data)
  local p, name = decode(data)
  if not p then return end
  UI.Confirm(string.format("|cffffd100%s|r sends you the OneForAll profile |cffffd100%s|r.\nSave it as a new profile? (Nothing changes until you switch to it.)", short(sender), name),
    function()
      local saved = addProfile(name, p)
      FLT.Msg(string.format("Profile \"%s\" saved. Switch to it in Settings > Profiles.", saved))
      if P.onChange then P.onChange() end
    end, "Save")
end

local function onMessage(msg, sender)
  local kind, qid = msg:match("^([QAN]):(%d+)$")
  if kind == "Q" then
    -- one request at a time per sender; parts of an older one are dropped
    if P.ReceiveEnabled() then allowed[sender] = tonumber(qid); addonSend("A:" .. qid, sender)
    else addonSend("N:" .. qid, sender) end
    return
  elseif kind == "A" then
    local o = outgoing[tonumber(qid)]
    if o and short(o.target):lower() == short(sender):lower() then sendParts(tonumber(qid)) end
    return
  elseif kind == "N" then
    local o = outgoing[tonumber(qid)]
    if o and short(o.target):lower() == short(sender):lower() then
      outgoing[tonumber(qid)] = nil
      FLT.Msg(string.format("%s has turned off receiving shared profiles.", short(sender)))
    end
    return
  end
  local id, i, n, part = msg:match("^(%d+):(%d+):(%d+):(.*)$")
  id, i, n = tonumber(id), tonumber(i), tonumber(n)
  if not (id and i and n) or n > 60 or i < 1 or i > n then return end
  if not P.ReceiveEnabled() or allowed[sender] ~= id then return end
  local buf = incoming[sender]
  if not buf or buf.id ~= id or buf.n ~= n then buf = { id = id, n = n, got = 0 }; incoming[sender] = buf end
  if not buf[i] then buf[i] = part; buf.got = buf.got + 1 end
  if buf.got == n then incoming[sender], allowed[sender] = nil, nil; received(sender, table.concat(buf, "", 1, n)) end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_LOGOUT", "CHAT_MSG_ADDON" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, prefix, msg, dist, sender)
  if event == "PLAYER_LOGOUT" then P.Save()
  elseif event == "PLAYER_LOGIN" then
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
  elseif prefix == PREFIX and dist == "WHISPER" and type(msg) == "string" and type(sender) == "string" then
    onMessage(msg, sender)
  end
end)

-- Popup (name / text / player) -----------------------------------------------------
local pop
local function popup(title, info, opts)
  if not pop then
    local f = CreateFrame("Frame", "OneForAllProfilePopup", UIParent)
    f:SetSize(420, 200); f:SetPoint("CENTER", 0, 80); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:EnableMouse(true)
    f:SetMovable(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI.FramedPanel(f)
    for _, t in ipairs(UI.OrnateFrame(f, f, 16, 3, "OVERLAY", 4)) do t:SetVertexColor(1, 1, 1, 1) end
    local close = UI.CloseButton(f); close:SetPoint("TOPRIGHT", -12, -12)
    f.title = FLT.NewFS(f, nil, "OVERLAY", "GameFontNormalLarge"); f.title:SetPoint("TOP", 0, -20)
    f.title:SetTextColor(1, 0.82, 0.20)
    f.info = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall"); f.info:SetPoint("TOP", 0, -46); f.info:SetWidth(370)
    f.info:SetJustifyH("CENTER")
    f.input = FLT.SkinBlizz(CreateFrame("EditBox", nil, f, "InputBoxTemplate")); f.input:SetSize(240, 20)
    f.input:SetAutoFocus(false); f.input:SetMaxLetters(32)
    f.input:SetScript("OnEscapePressed", function() f:Hide() end)
    -- multi-line box for the profile string
    local sf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")); sf:SetSize(350, 96)
    local box = CreateFrame("EditBox", nil, sf); box:SetMultiLine(true); box:SetWidth(346); box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall"); sf:SetScrollChild(box)
    local bg = UI.makeTexture(sf, "BACKGROUND", 0.02, 0.02, 0.03, 0.85); bg:SetPoint("TOPLEFT", -4, 4); bg:SetPoint("BOTTOMRIGHT", 4, -4)
    box:SetScript("OnEscapePressed", function() f:Hide() end)
    box:SetScript("OnTextChanged", function(b, user) if user and b.readOnly then b:SetText(b.value or ""); b:HighlightText() end end)
    box:SetScript("OnEditFocusGained", function(b) if b.readOnly then b:HighlightText() end end)
    f.box, f.boxHolder = box, sf
    f.ok = UI.GoldButton(f, "OK", 130, 26, nil, 13)
    f.alt = UI.GoldButton(f, "", 130, 26, nil, 13)
    if UISpecialFrames then table.insert(UISpecialFrames, "OneForAllProfilePopup") end
    pop = f
  end
  local f = pop
  f.title:SetText(title); f.info:SetText(info or "")
  local y = -52 - (f.info:GetStringHeight() or 12)
  f.input:ClearAllPoints(); f.input:SetShown(opts.input ~= nil)
  if opts.input then f.input:SetPoint("TOP", 0, y - 4); f.input:SetText(opts.input); y = y - 34 end
  f.boxHolder:ClearAllPoints(); f.boxHolder:SetShown(opts.box ~= nil)
  if opts.box then
    f.boxHolder:SetPoint("TOP", -10, y - 8)
    f.box.readOnly, f.box.value = opts.readOnly, opts.box
    f.box:SetText(opts.box); f.box:SetCursorPosition(0)
    y = y - 112
  end
  f:SetHeight(-y + 60)
  f.ok:SetLabel(opts.okLabel or "OK"); f.ok:ClearAllPoints()
  f.ok:SetScript("OnClick", function()
    if not opts.onOK or opts.onOK(f.input:GetText(), f.box:GetText()) ~= false then f:Hide() end
  end)
  f.alt:SetShown(opts.altLabel ~= nil); f.alt:ClearAllPoints()
  if opts.altLabel then
    f.alt:SetLabel(opts.altLabel)
    f.alt:SetScript("OnClick", function() if opts.onAlt(f.input:GetText()) ~= false then f:Hide() end end)
    f.ok:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 18); f.alt:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 18)
  else
    f.ok:SetPoint("BOTTOM", 0, 18)
  end
  f.input:SetScript("OnEnterPressed", function() f.ok:Click() end)
  f:Show()
  if opts.input then f.input:SetFocus(); f.input:HighlightText()
  elseif opts.box then f.box:SetFocus(); if opts.readOnly then f.box:HighlightText() end end
end

local function changed() if P.onChange then P.onChange() end end
local function nameOK(name)
  name = clean(name)
  if name == "" then FLT.Msg("Please enter a name."); return end
  if store()[name] then FLT.Msg("A profile named \"" .. name .. "\" already exists."); return end
  return name
end

-- actions for the Settings section ----------------------------------------------------
function P.New()
  popup("New profile", "A new profile starts with the default options.", { input = "", okLabel = "Create", onOK = function(name)
    name = nameOK(name); if not name then return false end
    store()[name] = {}; changed()
    offerSwitch(name, "Profile \"" .. name .. "\" created.")
  end })
end
function P.Copy()
  local src = P.Active()
  popup("Copy profile", "Copies the profile \"" .. src .. "\" with all its options.", { input = freeName(src), okLabel = "Copy", onOK = function(name)
    name = nameOK(name); if not name then return false end
    store()[name] = snapshot(); changed()
    offerSwitch(name, "Profile \"" .. name .. "\" created.")
  end })
end
function P.Rename()
  local old = P.Active()
  if old == DEFAULT then FLT.Msg("The Default profile cannot be renamed."); return end
  popup("Rename profile", "New name for the profile \"" .. old .. "\".", { input = old, okLabel = "Rename", onOK = function(name)
    name = nameOK(name); if not name then return false end
    local list = store()
    list[name], list[old] = list[old], nil
    OneForAllDB.profileRenames = OneForAllDB.profileRenames or {}
    OneForAllDB.profileRenames[old] = name
    OneForAllCharDB.profile = name; changed()
  end })
end
function P.Delete()
  local name = P.Active()
  if name == DEFAULT then FLT.Msg("The Default profile cannot be deleted."); return end
  if InCombatLockdown and InCombatLockdown() then FLT.Msg("Profiles cannot be deleted in combat."); return end
  UI.Confirm("Delete the profile |cffffd100" .. name .. "|r?\nThis character and all others using it go back to Default. The interface reloads.", function()
    store()[name] = nil
    if OneForAllDB.profileRenames then
      for k, v in pairs(OneForAllDB.profileRenames) do if v == name then OneForAllDB.profileRenames[k] = nil end end
    end
    OneForAllCharDB.profile = DEFAULT
    apply(store()[DEFAULT])
  end, "Delete", "/reload")
end
function P.Export()
  popup("Export profile", "Copy this text (Ctrl+C) and give it to a friend or keep it. Import pastes it back.",
    { box = encode(P.Active()), readOnly = true, okLabel = "Close" })
end
function P.Import()
  popup("Import profile", "Paste a profile text (Ctrl+V). It is saved as a new profile.", { box = "", okLabel = "Import", onOK = function(_, text)
    local p, name = decode(text)
    if not p then FLT.Msg("That is not a OneForAll profile text."); return false end
    name = addProfile(name, p); changed()
    offerSwitch(name, "Profile \"" .. name .. "\" imported.")
  end })
end
function P.SendDialog()
  local name = P.Active()
  popup("Send profile", "Sends the profile \"" .. name .. "\" to a player who also uses OneForAll and has \"Receive shared profiles\" switched on. They are asked first and only get a copy.",
    { input = (UnitExists and UnitExists("target") and UnitIsPlayer("target") and UnitName("target")) or "", okLabel = "Send",
      onOK = function(target)
        target = clean(target)
        if target == "" then FLT.Msg("Please enter a player name."); return false end
        P.Send(name, target)
      end })
end

-- mock tests
P._ser, P._parse, P._sanitize, P._encode, P._decode, P._onMessage = ser, parse, sanitize, encode, decode, onMessage
