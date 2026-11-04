--[[
  Forever Threat 1.24

  One window of bars, one bar per group member, sorted by threat on the mob you
  are targeting. The window is laid out from Blizzard_DamageMeter's own XML and
  Lua (retail 12.1 UI source): the same atlases, fonts, sizes and anchors for
  the header, background, rows, settings gear, minimize button and resize
  handle, with a fallback texture wherever this client lacks an atlas. Your own
  row is pinned to the top or bottom edge when it scrolls out of view, the way
  the damage meter pins the local player.

  Everything here is read-only. It asks the game for UnitDetailedThreatSituation
  and draws the answer. It sends nothing, clicks nothing, and makes no decision
  for the player, which is the line the Midnight addon rules draw.

  This client can hand addons "secret" numbers in combat: values you may
  display but not compare or do arithmetic on. When threat comes back that way
  the bars still fill and the percentages still print, but the rows stay in
  roster order because sorting would need a comparison.
]]

local ADDON, ns = ...
local PREFIX = '|cff33ff99Forever Threat:|r '

local DEFAULTS = {
  shown = true,
  locked = false,
  scale = 1,
  minimized = false,
  width = 300,
  height = 200,
  alpha = 0.5,              -- matches the damage meter's background (CurseForge comment)
  barHeight = 20,
  textScale = 1,
  display = 1,              -- 1 threat and %, 2 percent, 3 threat
  classColors = false,      -- class colour on bars that are not aggro or next
  highlightMe = false,      -- your own bar in a colour of its own
  hints = true,             -- the grey help text when the list is empty
  icons = true,
  pets = true,
  strangers = true,         -- read nameplates for people outside the group
  combatOnly = false,
  groupOnly = false,
  instanceOnly = false,     -- with groupOnly: show when either holds
  warn = true,
  warnAt = 90,
  sound = false,
  minimap = true,
  minimapAngle = 195,
}

local DISPLAYS = { 'Threat and percent', 'Percent only', 'Threat only' }
local HEADER_H = 32
local ROW_GAP = 2           -- sized to match how the damage meter is set up on this client
local TICK = 0.05           -- 20 reads a second; the game itself only moves threat about once a second

local FILL = 'Interface\\RaidFrame\\Raid-Bar-Hp-Fill'

-- Use Blizzard's atlas when this client has it, otherwise a stock texture.
local function hasAtlas(name)
  return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

local function setAtlas(tex, name, fallback, useSize)
  if hasAtlas(name) then
    tex:SetAtlas(name, useSize or false)
    return true
  end
  if fallback then tex:SetTexture(fallback) end
  return false
end
local FLAT = 'Interface\\Buttons\\WHITE8X8'
local CLASS_ICONS = 'Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes'
local PET_ICON = 'Interface\\Icons\\Ability_Hunter_BeastCall'
local ADDON_ICON = 'Interface\\Icons\\Ability_Warrior_Sunder'

local function IsSecret(v)
  return issecretvalue ~= nil and issecretvalue(v) or false
end

local db
local frame, header, titleButton, titleText, targetText, gear, grip, mm
local rows = {}
local entries, pool = {}, {}
local testMode = false
local warned = false
local scroll = 0
local placePending = false
local trace = {}
local topValue = 0          -- highest readable threat this refresh; bars are drawn against it
local refresh

local function getCVar(name)
  local ok, v = pcall(function()
    if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
    return GetCVar(name)
  end)
  return ok and v or nil
end

local function friendlyPlatesOn()
  return getCVar('nameplateShowFriends') == '1'
end

local function say(message)
  DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message)
end

-- Data ------------------------------------------------------------------------

-- The mob whose threat table we read. A healer has the tank targeted, so fall
-- through to the target's target before giving up.
local function hostile(unit)
  local ok, yes = pcall(function()
    return UnitExists(unit) and UnitCanAttack('player', unit) and not UnitIsDead(unit)
  end)
  return ok and yes
end

local function mobUnit()
  if hostile('target') then return 'target' end
  if hostile('targettarget') then
    -- Chained names like "targettarget" are where this client starts hiding
    -- things. If the same mob has a nameplate, ask through that instead.
    for i = 1, 40 do
      local plate = 'nameplate' .. i
      local ok, same = pcall(UnitIsUnit, plate, 'targettarget')
      if ok and not IsSecret(same) and same then return plate end
    end
    return 'targettarget'
  end
end

local function wipeEntries()
  for i = #entries, 1, -1 do
    pool[#pool + 1] = entries[i]
    entries[i] = nil
  end
end

local function already(unit)
  for _, e in ipairs(entries) do
    local ok, same = pcall(UnitIsUnit, e.unit, unit)
    if ok and not IsSecret(same) and same then return true end
  end
  return false
end

-- The second check for a stranger's row. When the game will not say whether two
-- unit names are the same creature, fall back to the GUID, then to the name, so
-- a party member's pet that the mob is chewing on is not listed twice.
local function findTwin(unit)
  local okG, guid = pcall(UnitGUID, unit)
  guid = okG and not IsSecret(guid) and guid or nil
  local name = UnitName(unit)
  if IsSecret(name) then name = nil end
  for _, e in ipairs(entries) do
    local okE, eguid = pcall(UnitGUID, e.unit)
    eguid = okE and not IsSecret(eguid) and eguid or nil
    if guid and eguid then
      if guid == eguid then return e end
    elseif name and not IsSecret(e.name) and e.name == name then
      return e
    end
  end
end

-- holdsAggro marks the unit the mob is attacking. It gets a row even when the
-- game will not give numbers for it, which is the usual case for a stranger.
local function plain(v)
  if IsSecret(v) then return nil end
  return v
end

local function addUnit(unit, mob, isPet)
  if not UnitExists(unit) or already(unit) then return false end
  local ok, tanking, status, scaled, raw, value = pcall(UnitDetailedThreatSituation, unit, mob)
  if not ok then tanking, status, scaled, raw, value = nil, nil, nil, nil, nil end

  -- Whoever the mob is attacking has aggro, and that comparison stays readable
  -- even when the threat numbers do not.
  local okT, isTarget = pcall(UnitIsUnit, unit, mob .. 'target')
  local holdsAggro = okT and plain(isTarget) == true

  local secret = IsSecret(scaled) or IsSecret(value)
  local aggroOnly = false
  if not secret then
    -- On the mob's threat table at all? A fresh hit can read as 0 threat with
    -- a status, so the number alone is not the test.
    local onTable = plain(status) ~= nil or (value or 0) > 0 or (scaled or 0) > 0
    if not onTable then
      if not holdsAggro then return false end
      aggroOnly, scaled, raw, value = true, 100, 100, nil
    end
  end

  local e = table.remove(pool) or {}
  e.unit = unit
  e.name = UnitName(unit)
  e.isPet = isPet
  e.isPlayer = plain(UnitIsUnit(unit, 'player')) == true
  e.class = nil
  if not isPet then
    local _, class = UnitClass(unit)
    e.class = plain(class)
  end
  e.secret = secret
  e.aggroOnly = aggroOnly
  e.scaled, e.raw, e.value = scaled, raw, value
  e.tanking = holdsAggro or plain(tanking) == true
  e.status = status
  entries[#entries + 1] = e
  return secret
end

-- Aggro first, then real numbers high to low, then rows whose numbers the game
-- is hiding. Hidden numbers are never compared.
local function byThreat(a, b)
  if a.tanking ~= b.tanking then return a.tanking end
  if a.secret ~= b.secret then return b.secret end
  if a.secret then return tostring(a.unit) < tostring(b.unit) end
  if a.aggroOnly ~= b.aggroOnly then return a.aggroOnly end
  if a.value ~= b.value then return (a.value or 0) > (b.value or 0) end
  return tostring(a.unit) < tostring(b.unit)
end

-- Returns the mob unit, and whether any number came back secret.
local function collect()
  wipeEntries()
  local mob = mobUnit()
  if not mob then return nil, false end

  local anySecret = false
  local function add(unit, petUnit)
    if addUnit(unit, mob, false) then anySecret = true end
    if db.pets and addUnit(petUnit, mob, true) then anySecret = true end
    -- (pets here are known pets; strangers are sorted out below)
  end

  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do add('raid' .. i, 'raidpet' .. i) end
  else
    add('player', 'pet')
    if IsInGroup() then
      for i = 1, GetNumGroupMembers() - 1 do add('party' .. i, 'partypet' .. i) end
    end
  end

  -- People outside the group have no unit of their own. The ones the game does
  -- give a handle to: whoever the mob is attacking, whoever is under the
  -- cursor, and anyone with a nameplate up.
  local function friendly(unit)
    local ok, yes = pcall(function()
      return UnitExists(unit) and UnitPlayerControlled(unit) and not UnitCanAttack('player', unit)
    end)
    return ok and not IsSecret(yes) and yes
  end
  local function addOther(unit, holdsAggro)
    if not friendly(unit) then return end
    -- Only call it a pet when the game plainly says it is not a player.
    local okP, isPlayer = pcall(UnitIsPlayer, unit)
    local isPet = okP and plain(isPlayer) == false
    if isPet and not db.pets and not holdsAggro then return end

    -- Group members and their pets were already read by their own unit names.
    -- Anything here that the game says is in the group is a second handle on
    -- someone already listed.
    local function yes(fn, ...)
      if not fn then return false end
      local ok, v = pcall(fn, ...)
      return ok and not IsSecret(v) and v and true or false
    end
    if yes(UnitInParty, unit) or yes(UnitInRaid, unit) or yes(UnitIsUnit, unit, 'player')
      or yes(UnitIsUnit, unit, 'pet') then
      local twin = findTwin(unit)
      if twin and holdsAggro then twin.tanking = true end
      return
    end
    -- In a dungeon the game hides this unit's name, and then there is no way to
    -- tell it apart from a row already on the list. A row that cannot be told
    -- apart is left out: better one missing stranger than the same person twice.
    local okN, name = pcall(UnitName, unit)
    if not okN or IsSecret(name) or name == nil then return end

    if not already(unit) then
      local twin = findTwin(unit)
      if twin then
        if holdsAggro then twin.tanking = true end
        return
      end
    end
    if addUnit(unit, mob, isPet) then anySecret = true end
  end

  addOther(mob .. 'target', true)
  addOther('mouseover')
  addOther('focus')
  addOther('softfriend')
  if db.strangers then
    for i = 1, 40 do addOther('nameplate' .. i) end
  end

  table.sort(entries, byThreat)
  return mob, anySecret
end

local TEST = {
  { 'Tankadin', 'PALADIN', 100, 48200, true },
  { 'Stabsworth', 'ROGUE', 93, 44800 },
  { 'Frostbolt', 'MAGE', 81, 39100 },
  { 'Dotty', 'WARLOCK', 74, 35700 },
  { 'Pewpew', 'HUNTER', 66, 31800 },
  { 'Healbot', 'PRIEST', 41, 19700 },
  { 'Treehugger', 'DRUID', 35, 16900 },
  { 'Zappy', 'SHAMAN', 22, 10600 },
  { 'Ragebar', 'WARRIOR', 12, 5800 },
}

local function collectTest()
  wipeEntries()
  for i, t in ipairs(TEST) do
    local e = table.remove(pool) or {}
    e.unit, e.name, e.class, e.scaled, e.raw, e.value = nil, t[1], t[2], t[3], t[3], t[4] * 100
    e.tanking, e.status, e.isPet, e.secret, e.isPlayer = t[5] or false, t[5] and 3 or 0, false, false, i == 2
    e.aggroOnly = false
    entries[i] = e
  end
end

-- A small menu of our own --------------------------------------------------------
-- The dropdown API differs between clients, so this draws its own: a list of
-- lines, some with a check, that closes when you click anywhere else.

local menu, catcher
local menuLines = {}

local function backdrop(f, alpha)
  if not f.SetBackdrop then return end
  f:SetBackdrop({
    bgFile = FLAT, edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
    edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  f:SetBackdropColor(0, 0, 0, alpha)
  f:SetBackdropBorderColor(0.45, 0.45, 0.5, 1)
end

local function buildMenu()
  catcher = CreateFrame('Button', nil, UIParent)
  catcher:SetAllPoints(UIParent)
  catcher:SetFrameStrata('FULLSCREEN')
  catcher:RegisterForClicks('AnyUp')
  catcher:SetScript('OnClick', function() menu:Hide() end)
  catcher:Hide()

  menu = CreateFrame('Frame', 'ForeverThreatMenu', UIParent, BackdropTemplateMixin and 'BackdropTemplate' or nil)
  menu:SetFrameStrata('FULLSCREEN_DIALOG')
  menu:SetClampedToScreen(true)
  backdrop(menu, 0.92)
  menu:SetScript('OnHide', function() catcher:Hide() end)
  menu:Hide()
  if UISpecialFrames then table.insert(UISpecialFrames, 'ForeverThreatMenu') end
end

local function menuLine(i)
  local line = menuLines[i]
  if line then return line end
  line = CreateFrame('Button', nil, menu)
  line:SetHeight(18)
  line:SetPoint('TOPLEFT', 8, -8 - (i - 1) * 18)
  line:SetPoint('RIGHT', -8, 0)
  line.check = line:CreateTexture(nil, 'ARTWORK')
  line.check:SetTexture('Interface\\Buttons\\UI-CheckBox-Check')
  line.check:SetSize(16, 16)
  line.check:SetPoint('LEFT')
  line.text = line:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  line.text:SetPoint('LEFT', 20, 0)
  local hl = line:CreateTexture(nil, 'HIGHLIGHT')
  hl:SetAllPoints()
  hl:SetTexture(FLAT)
  hl:SetVertexColor(1, 1, 1, 0.12)
  menuLines[i] = line
  return line
end

local function showMenu(anchor, items)
  if not menu then buildMenu() end
  if menu:IsShown() and menu.anchor == anchor then menu:Hide() return end
  menu.anchor = anchor

  local function fill()
    local width = 120
    for i, item in ipairs(items) do
      local line = menuLine(i)
      local text = type(item.text) == 'function' and item.text() or item.text
      line.text:SetText(text)
      if item.title then
        line.text:SetTextColor(1, 0.82, 0)
        line:Disable()
      else
        line.text:SetTextColor(1, 1, 1)
        line:Enable()
      end
      if item.checked and item.checked() then line.check:Show() else line.check:Hide() end
      line:SetScript('OnClick', function()
        item.click()
        if item.close then menu:Hide() else fill() end
      end)
      line:Show()
      local w = line.text:GetStringWidth() + 44
      if w > width then width = w end
    end
    for i = #items + 1, #menuLines do menuLines[i]:Hide() end
    menu:SetSize(width, #items * 18 + 16)
  end

  fill()
  menu:ClearAllPoints()
  menu:SetPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, -2)
  catcher:Show()
  menu:Show()
end

-- Drawing ---------------------------------------------------------------------

local function short(n)
  if n >= 1e6 then return string.format('%.2fm', n / 1e6) end
  if n >= 1e4 then return string.format('%.1fk', n / 1e3) end
  return string.format('%d', n)
end

-- Red for aggro and orange for next always win, since they are the warning.
-- Below that, two options from a CurseForge request: your own bar in blue so
-- it stands out, and class colours for everyone else.
local function rowColor(e, isNext)
  if e.tanking then return 0.78, 0.1, 0.1 end
  if isNext then return 0.9, 0.5, 0.08 end
  if db.highlightMe and e.isPlayer then return 0.2, 0.55, 1.0 end
  if db.classColors and e.class then
    local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[e.class]
    if c then return c.r, c.g, c.b end
  end
  -- Black, lifted just enough that the length of the bar still reads against
  -- the dark row behind it.
  return 0.16, 0.16, 0.16
end

local function rowTooltip(row)
  local e = row.entry
  if not e then return end
  GameTooltip:SetOwner(row, 'ANCHOR_RIGHT')
  pcall(GameTooltip.AddLine, GameTooltip, e.name)
  if e.secret then
    GameTooltip:AddLine('The game is hiding exact threat from addons right now,', 1, 1, 1)
    GameTooltip:AddLine('so rows are not sorted. The bar and percent are still live.', 1, 1, 1)
  elseif e.aggroOnly then
    GameTooltip:AddLine('The mob is attacking this one.', 1, 1, 1)
    GameTooltip:AddLine('The game gives no threat numbers for them.', 1, 1, 1)
  else
    GameTooltip:AddDoubleLine('Threat', short(e.value), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine('Toward pulling aggro', string.format('%d%%', e.scaled or 0), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine('Of the aggro holder\'s threat', string.format('%d%%', plain(e.raw) or (topValue > 0 and e.value / topValue * 100) or 0), 1, 1, 1, 1, 1, 1)
    local top = entries[1]
    if top and top ~= e and not top.secret and top.value then
      GameTooltip:AddDoubleLine('Behind ' .. top.name, short(top.value - e.value), 1, 1, 1, 1, 1, 1)
    end
    if e.tanking then GameTooltip:AddLine('Has aggro', 1, 0.25, 0.25) end
    if not e.tanking and e.scaled then
      GameTooltip:AddLine(string.format('Pulls aggro at 100%%. %d%% to go.', math.max(0, 100 - e.scaled)), 1, 0.6, 0.1)
    end
  end
  GameTooltip:Show()
end

local lockHintAt = 0

local function startMove(_, button)
  if button and button ~= 'LeftButton' then return end
  if db.locked then
    if GetTime() - lockHintAt > 10 then
      lockHintAt = GetTime()
      say('the window is locked. Gear, then Lock window, or /threat lock.')
    end
    return
  end
  frame.moving = true
  frame:StartMoving()
end

local function stopMove()
  if not frame.moving then return end
  frame:StopMovingOrSizing()
  if frame.SetUserPlaced then pcall(frame.SetUserPlaced, frame, true) end
  frame.moving = false
  frame.savePlace()
  refresh()
end

local function buildRow(i)
  -- DamageMeterEntryTemplate: 24px square icon, status bar, shadow background
  -- and edge, NumberFontNormal for both strings.
  local row = CreateFrame('Frame', nil, frame.body)
  row:EnableMouse(true)
  row:SetScript('OnEnter', function(self) frame.hover() rowTooltip(self) end)
  row:SetScript('OnLeave', function() GameTooltip:Hide() end)
  -- Rows do not drag the window. A row can vanish under the cursor when its
  -- mob dies, and a hidden row never hears the mouse button come up, which
  -- left the window glued to the cursor. Drag by the header or the background.

  -- DamageMeterEntryTemplate: the icon is a fixed 24x24 and the row clips it, so
  -- a short row shows a wide, cropped icon exactly as the damage meter does.
  if row.SetClipsChildren then row:SetClipsChildren(true) end
  row.icon = row:CreateTexture(nil, 'ARTWORK')
  row.icon:SetSize(24, 24)
  row.icon:SetPoint('LEFT')

  row.bar = CreateFrame('StatusBar', nil, row)
  if hasAtlas('UI-HUD-CoolDownManager-Bar') then
    row.bar:SetStatusBarTexture('UI-HUD-CoolDownManager-Bar')
  else
    row.bar:SetStatusBarTexture(FILL)
  end
  row.bar:SetMinMaxValues(0, 100)

  row.bg = row.bar:CreateTexture(nil, 'BACKGROUND')
  row.bg:SetPoint('TOPLEFT', -2, 2)
  row.bg:SetPoint('BOTTOMRIGHT', 2, -2)
  if not setAtlas(row.bg, 'ui-damagemeters-bar-shadowbg', FLAT) then
    row.bg:SetVertexColor(0, 0, 0, 0.45)
  end

  row.edge = row.bar:CreateTexture(nil, 'OVERLAY')
  row.edge:SetPoint('TOPLEFT', -2, 2)
  row.edge:SetPoint('BOTTOMRIGHT', 2, -2)
  if not setAtlas(row.edge, 'ui-damagemeters-bar-shadowedge') then row.edge:Hide() end

  local fontObject = NumberFontNormal and 'NumberFontNormal' or 'GameFontHighlightSmall'
  row.value = row.bar:CreateFontString(nil, 'OVERLAY', fontObject)
  row.value:SetPoint('RIGHT', -3, 0)
  row.value:SetJustifyH('RIGHT')

  row.name = row.bar:CreateFontString(nil, 'OVERLAY', fontObject)
  row.name:SetPoint('LEFT', 2, 0)
  row.name:SetPoint('RIGHT', row.value, 'LEFT', -25, 0)
  row.name:SetJustifyH('LEFT')
  row.name:SetWordWrap(false)
  row.fontFile, row.fontSize, row.fontFlags = row.name:GetFont()

  rows[i] = row
  return row
end

local function layoutRow(row, i)
  local h = db.barHeight
  row:ClearAllPoints()
  row:SetHeight(h)
  -- Scroll box anchors: header bottom-left +5,-2 to bottom-right -1,+6.
  row:SetPoint('TOPLEFT', frame, 'TOPLEFT', 5, -(HEADER_H + 2 + (i - 1) * (h + ROW_GAP)))
  row:SetPoint('RIGHT', frame, 'RIGHT', -1, 0)
  row.bar:ClearAllPoints()
  if db.icons then
    row.icon:Show()
    row.bar:SetPoint('LEFT', row.icon, 'RIGHT', 0, 0)
  else
    row.icon:Hide()
    row.bar:SetPoint('LEFT', row, 'LEFT', 0, 0)
  end
  row.bar:SetPoint('TOP', 0, -1)
  row.bar:SetPoint('BOTTOMRIGHT', -4, 1)
  -- The damage meter scales its two strings with SetTextScale and leaves the
  -- font object alone, so at 100% the text is NumberFontNormal untouched.
  if row.name.SetTextScale then
    row.name:SetTextScale(db.textScale)
    row.value:SetTextScale(db.textScale)
  elseif row.fontFile and row.fontSize then
    local size = row.fontSize * db.textScale
    row.name:SetFont(row.fontFile, size, row.fontFlags)
    row.value:SetFont(row.fontFile, size, row.fontFlags)
  end
end

local function classAtlas(class)
  if GetClassAtlas then
    local ok, name = pcall(GetClassAtlas, class)
    if ok and name and hasAtlas(name) then return name end
  end
end

local function drawRow(row, e, rank, isNext)
  row.entry = e
  local r, g, b = rowColor(e, isNext)
  row.bar:GetStatusBarTexture():SetVertexColor(r, g, b)

  local atlas = not e.isPet and e.class and classAtlas(e.class)
  if atlas then
    row.icon:SetAtlas(atlas)
    row.icon:SetTexCoord(0, 1, 0, 1)
  elseif e.isPet then
    row.icon:SetTexture(PET_ICON)
    row.icon:SetTexCoord(0.0625, 0.9, 0.0626, 0.9)
  else
    local tc = e.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[e.class]
    if tc then
      row.icon:SetTexture(CLASS_ICONS)
      row.icon:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
    else
      row.icon:SetTexture('Interface\\Icons\\INV_Misc_Head_Human_01')
      row.icon:SetTexCoord(0.0625, 0.9, 0.0626, 0.9)
    end
  end

  -- A name can be secret inside an instance; SetText takes it, joining may not.
  if e.name == nil then
    row.name:SetText(rank .. '. ?')
  elseif IsSecret(e.name) then
    pcall(row.name.SetText, row.name, e.name)
  else
    row.name:SetText(rank .. '. ' .. e.name .. '')
  end

  if e.secret then
    -- Display only. No comparisons, no arithmetic.
    row.bar:SetMinMaxValues(0, 100)
    pcall(row.bar.SetValue, row.bar, e.scaled)
    if not pcall(row.value.SetFormattedText, row.value, '%d%%', e.scaled) then
      row.value:SetText('')
    end
    row.value:SetTextColor(1, 1, 1)
  elseif e.aggroOnly then
    row.bar:SetMinMaxValues(0, 100)
    row.bar:SetValue(100)
    row.value:SetText('')
  else
    -- Like the damage meter: the top row fills the bar and everyone else is
    -- drawn as their share of it.
    -- The bar is this player's threat as a percent of whoever has aggro: 300
    -- against 400 fills 75%. The game hands that percent over directly, and it
    -- stays readable even when the aggro holder's own number is hidden.
    local value = e.value or 0
    local pct = plain(e.raw)
    if e.tanking then
      pct = 100
    elseif pct == nil then
      pct = topValue > 0 and value / topValue * 100 or 0
    end
    pct = math.floor(pct + 0.5)
    row.bar:SetMinMaxValues(0, 100)
    row.bar:SetValue(pct > 100 and 100 or pct)
    -- Shown exactly as the game reports it. An earlier version divided by 100,
    -- which turned a few dozen threat into "0" on this client.
    if db.display == 2 then
      row.value:SetFormattedText('%d%%', pct)
    elseif db.display == 3 then
      row.value:SetText(short(e.value))
    else
      row.value:SetFormattedText('%s (%d%%)', short(e.value), pct)
    end
    row.value:SetTextColor(1, 1, 1)
  end
  row:Show()
end

local function visibleRows()
  local space = frame:GetHeight() - HEADER_H - 2 - 6 + ROW_GAP
  local n = math.floor(space / (db.barHeight + ROW_GAP))
  return n < 1 and 1 or n
end

local function setWarning(on)
  if on then
    header.bg:SetVertexColor(1, 0.15, 0.15, 1)
    if not warned and db.sound then pcall(PlaySound, 8959, 'Master') end
  else
    header.bg:SetVertexColor(1, 1, 1, 1)
  end
  warned = on
end

-- When the numbers are secret the percent cannot be compared, but the game
-- still says outright when you are above the tank and not yet tanking.
local function aboveTank(mob)
  local ok, status = pcall(UnitThreatSituation, 'player', mob)
  return ok and status and not IsSecret(status) and status == 1
end

refresh = function()
  if not frame then return end
  if placePending and not frame.moving and frame.savePlace then frame.savePlace() end
  -- Whatever else moves the window (the game's own layout restore did, after
  -- login), put it back on the saved spot.
  if not frame.moving and not placePending and frame.holdPlace then frame.holdPlace() end

  local mob, anySecret
  if testMode then
    collectTest()
  else
    mob, anySecret = collect()
  end

  local hide = not db.shown
  if not testMode and not frame.moving then
    if db.combatOnly and not UnitAffectingCombat('player') then hide = true end
    -- "Only in a group" and "Only in an instance" together mean: show when
    -- either is true, hide when neither is. A CurseForge request.
    if db.groupOnly or db.instanceOnly then
      local ok, inInstance = pcall(IsInInstance)
      inInstance = ok and inInstance == true
      local inGroup = IsInGroup() == true
      local wanted = (db.groupOnly and inGroup) or (db.instanceOnly and inInstance)
      if not wanted then hide = true end
    end
  end
  if ns.dockActive and ns.dockActive() then hide = true end
  if hide then frame:Hide() return end
  frame:Show()

  if testMode then
    targetText:SetText('Test bars')
  elseif mob then
    pcall(targetText.SetText, targetText, UnitName(mob))
  else
    targetText:SetText('')
  end

  local strangerOnly = #entries == 1 and entries[1].aggroOnly
  if not db.hints then
    frame.empty:SetText('')
  elseif #entries > 1 or (#entries == 1 and not strangerOnly) then
    frame.empty:SetText('')
  elseif strangerOnly then
    -- One row, and it is somebody outside the group: say how to get more.
    if db.strangers and not friendlyPlatesOn() then
      frame.empty:SetText('\n\nFriendly nameplates are off. Turn them on in\nthe gear menu to list the others fighting it.')
    else
      frame.empty:SetText('')
    end
  elseif mob then
    frame.empty:SetText('Nothing has threat on it yet.')
  else
    frame.empty:SetText('Target a mob to see who has threat on it.')
  end

  local max = visibleRows()
  if scroll > #entries - max then scroll = #entries - max end
  if scroll < 0 then scroll = 0 end
  local shown = #entries - scroll
  if shown > max then shown = max end

  if db.minimized then shown = 0 end

  -- Off the top or bottom of the window, your row is pinned to that edge, the
  -- way the damage meter pins the local player.
  local mine
  for i, e in ipairs(entries) do
    if e.isPlayer then mine = i break end
  end

  -- Who pulls next: the highest threat that is not already being attacked.
  -- The list is sorted, so it is the first such row. Needs real numbers.
  local nextUp
  do
    local someoneTanking = false
    for _, e in ipairs(entries) do
      if e.tanking then someoneTanking = true break end
    end
    if someoneTanking then
      for i, e in ipairs(entries) do
        if not e.tanking and not e.aggroOnly and not e.secret then nextUp = i break end
      end
    end
  end

  topValue = 0
  for _, e in ipairs(entries) do
    if not e.secret and e.value and e.value > topValue then topValue = e.value end
  end

  local danger = false
  for i = 1, shown do
    local index = i + scroll
    if mine and i == shown and mine > index then index = mine end
    if mine and i == 1 and shown > 1 and mine < index then index = mine end
    local e = entries[index]
    local row = rows[i]
    if not row then
      row = buildRow(i)
      layoutRow(row, i)
    end
    drawRow(row, e, index, index == nextUp)
    if GameTooltip:IsOwned(row) then rowTooltip(row) end
  end
  for i = shown + 1, #rows do
    rows[i].entry = nil
    rows[i]:Hide()
  end

  if db.warn and mine then
    local e = entries[mine]
    if e.secret then
      danger = mob and aboveTank(mob) or false
    else
      danger = not e.tanking and (e.scaled or 0) >= db.warnAt
    end
  end
  setWarning(danger)
end

-- Window ----------------------------------------------------------------------

-- The window's place is kept as where its top-left corner sits on the screen,
-- in screen units, so it comes back to the same spot whatever the scale, and
-- minimising or resizing never shifts that corner.
local function num(v)
  return type(v) == 'number' and not IsSecret(v)
end

local function placeFrame()
  if not (num(db.left) and num(db.top)) then return false end
  local scale = db.scale or 1
  frame:ClearAllPoints()
  frame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', db.left / scale, db.top / scale)
  return true
end

local function savePlace()
  local left, top, w, h = frame:GetLeft(), frame:GetTop(), frame:GetWidth(), frame:GetHeight()
  -- In combat this client can hand back hidden numbers for a window that is
  -- showing hidden values. Those cannot be stored, so try again after the fight
  -- rather than saving nothing and losing the spot.
  if not (num(left) and num(top)) then
    placePending = true
    return
  end
  placePending = false
  local scale = frame:GetScale()
  if not num(scale) then scale = db.scale or 1 end
  db.left, db.top = left * scale, top * scale
  if num(w) and num(h) then db.width, db.height = w, h end
  db.point, db.relPoint, db.x, db.y = nil, nil, nil, nil
  placeFrame()
end

local function applyLook()
  frame:SetScale(db.scale)
  placeFrame()
  frame.bg:SetAlpha(db.alpha)
  titleText:SetText(db.display == 2 and 'Threat %' or 'Threat')
  titleButton:SetWidth(titleText:GetStringWidth() + 20)
  frame.body:SetShown(not db.minimized)
  frame.setMinimizeArt()
  if db.locked or db.minimized then grip:Hide() else grip:Show() end
  for i, row in ipairs(rows) do layoutRow(row, i) end
end

local function updateMinimap()
  if not mm then return end
  if db.minimap then
    local a = math.rad(db.minimapAngle)
    local r = Minimap:GetWidth() / 2 + 8
    mm:ClearAllPoints()
    mm:SetPoint('CENTER', Minimap, 'CENTER', math.cos(a) * r, math.sin(a) * r)
    mm:Show()
  else
    mm:Hide()
  end
end

local function cycle(key, values)
  local at = 1
  for i, v in ipairs(values) do
    if db[key] == v then at = i break end
  end
  db[key] = values[at % #values + 1]
end

local function toggle(key)
  return function() db[key] = not db[key] applyLook() updateMinimap() refresh() end
end

local function checked(key)
  return function() return db[key] end
end

local function resetPlace()
  frame:ClearAllPoints()
  frame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
  frame:SetSize(DEFAULTS.width, DEFAULTS.height)
  db.shown = true
  savePlace()
  refresh()
end

local function cycler(label, key, values, suffix, mult)
  return {
    text = function() return label .. ': ' .. math.floor(db[key] * (mult or 1) + 0.5) .. (suffix or '') end,
    click = function() cycle(key, values) applyLook() refresh() end,
  }
end

local SETTINGS = {
  { text = 'Forever Threat', title = true, click = function() end },
  { text = 'Lock window', checked = checked('locked'), click = toggle('locked') },
  { text = 'Only show in combat', checked = checked('combatOnly'), click = toggle('combatOnly') },
  { text = 'Only show in a group', checked = checked('groupOnly'), click = toggle('groupOnly') },
  { text = 'Only show in an instance', checked = checked('instanceOnly'), click = toggle('instanceOnly') },
  { text = 'Count pets', checked = checked('pets'), click = toggle('pets') },
  { text = 'Class colours', checked = checked('classColors'), click = toggle('classColors') },
  { text = 'Highlight my bar', checked = checked('highlightMe'), click = toggle('highlightMe') },
  { text = 'Show hint text', checked = checked('hints'), click = toggle('hints') },
  { text = 'Include people outside my group', checked = checked('strangers'), click = toggle('strangers') },
  { text = 'Friendly nameplates (finds those people)', checked = function() return friendlyPlatesOn() end,
    click = function()
      if InCombatLockdown and InCombatLockdown() then
        say('the game only lets nameplates be switched out of combat.')
        return
      end
      local on = friendlyPlatesOn() and '0' or '1'
      local set = (C_CVar and C_CVar.SetCVar) or SetCVar
      pcall(set, 'nameplateShowFriends', on)
      pcall(set, 'nameplateShowFriendlyPets', on)
      refresh()
    end },
  { text = 'Class icons', checked = checked('icons'), click = toggle('icons') },
  { text = 'Warn me near aggro', checked = checked('warn'), click = toggle('warn') },
  cycler('Warn at', 'warnAt', { 70, 80, 90, 100 }, '%'),
  { text = 'Warning sound', checked = checked('sound'), click = toggle('sound') },
  cycler('Bar height', 'barHeight', { 12, 14, 16, 18, 20, 22, 25, 28 }),
  cycler('Text size', 'textScale', { 0.8, 0.9, 1, 1.1, 1.25, 1.5 }, '%', 100),
  cycler('Background', 'alpha', { 0, 0.25, 0.5, 0.75, 1 }, '%', 100),
  cycler('Scale', 'scale', { 0.8, 0.9, 1, 1.1, 1.25, 1.5 }, '%', 100),
  { text = 'Minimap button', checked = checked('minimap'), click = toggle('minimap') },
  { text = 'Test bars', checked = function() return testMode end,
    click = function() testMode = not testMode refresh() end },
  { text = 'Reset position', click = resetPlace, close = true },
}

local DISPLAY_MENU = {}
for i, label in ipairs(DISPLAYS) do
  DISPLAY_MENU[i] = {
    text = label, close = true,
    checked = function() return db.display == i end,
    click = function() db.display = i applyLook() refresh() end,
  }
end

local function buildFrame()
  -- DamageMeterSessionWindowTemplate: 32px header atlas across the top, the
  -- background atlas behind everything, resize bounds 200x120 to 600x400.
  -- The bare window already exists (made at file load, see the bottom of this
  -- file) so the game could put it back where it was.
  frame = frame or CreateFrame('Frame', 'ForeverThreatFrame', UIParent)
  local restored = frame:GetNumPoints() > 0
  trace.restored = tostring(restored)
  if placeFrame() then
    frame:SetSize(db.width, db.height)
  elseif restored then
    -- No saved settings reached the addon, but the game restored the window
    -- itself. Keep that, and adopt it as the saved spot.
    placePending = true
  else
    frame:SetSize(db.width, db.height)
    frame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
    placePending = true
  end
  frame:SetFrameStrata('MEDIUM')
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  if frame.SetUserPlaced then pcall(frame.SetUserPlaced, frame, true) end
  frame:SetResizable(true)
  frame:EnableMouse(true)
  frame:EnableMouseWheel(true)
  if frame.SetResizeBounds then
    frame:SetResizeBounds(200, 120, 600, 400)
  elseif frame.SetMinResize then
    frame:SetMinResize(200, 120)
    frame:SetMaxResize(600, 400)
  end

  -- Moved on mouse down rather than on drag: a drag needs the cursor to travel
  -- a few pixels before it starts, and child frames can swallow it.
  frame.savePlace = savePlace
  frame.holdPlace = function()
    if not (num(db.left) and num(db.top)) then return end
    local left, top, scale = frame:GetLeft(), frame:GetTop(), frame:GetScale()
    if not (num(left) and num(top) and num(scale)) then return end
    if math.abs(left * scale - db.left) > 1 or math.abs(top * scale - db.top) > 1 then
      placeFrame()
    end
  end
  frame:SetScript('OnMouseDown', startMove)
  frame:SetScript('OnMouseUp', stopMove)
  frame:SetScript('OnHide', stopMove)
  frame:SetScript('OnMouseWheel', function(_, delta)
    scroll = scroll - delta
    refresh()
  end)

  -- Everything the minimize button hides.
  frame.body = CreateFrame('Frame', nil, frame)
  frame.body:SetAllPoints()

  frame.bg = frame.body:CreateTexture(nil, 'BACKGROUND')
  frame.bg:SetAllPoints()
  if not setAtlas(frame.bg, 'damagemeters-background') then
    frame.bg:SetColorTexture(0, 0, 0, 1)
  end

  -- The damage meter's "not active" line, centred under the header.
  frame.empty = frame.body:CreateFontString(nil, 'OVERLAY', GameFontNormalMed1 and 'GameFontNormalMed1' or 'GameFontNormal')
  frame.empty:SetPoint('TOPLEFT', 20, -HEADER_H)
  frame.empty:SetPoint('BOTTOMRIGHT', -20, 0)
  frame.empty:SetJustifyH('CENTER')
  frame.empty:SetTextColor(0.6, 0.6, 0.6)

  header = CreateFrame('Frame', nil, frame)
  header:SetPoint('TOPLEFT')
  header:SetPoint('TOPRIGHT')
  header:SetHeight(HEADER_H)
  header:EnableMouse(true)
  header:SetScript('OnMouseDown', startMove)
  header:SetScript('OnMouseUp', stopMove)
  header.bg = header:CreateTexture(nil, 'BACKGROUND', nil, 1)
  header.bg:SetAllPoints()
  if not setAtlas(header.bg, 'ui-damagemeters-header-bar', FLAT) then
    header.bg:SetColorTexture(0.12, 0.12, 0.14, 0.95)
  end

  -- Minimize button, top right: -3,-5, quest tracker collapse art.
  local minimize = CreateFrame('Button', nil, header)
  minimize:SetSize(18, 19)
  minimize:SetPoint('TOPRIGHT', -3, -5)
  frame.setMinimizeArt = function()
    local kind = db.minimized and 'expand' or 'collapse'
    if hasAtlas('ui-questtrackerbutton-' .. kind .. '-all') then
      minimize:SetNormalAtlas('ui-questtrackerbutton-' .. kind .. '-all')
      minimize:SetPushedAtlas('ui-questtrackerbutton-' .. kind .. '-all-pressed')
      minimize:SetHighlightAtlas('ui-questtrackerbutton-red-highlight', 'ADD')
    else
      local art = db.minimized and 'Interface\\Buttons\\UI-PlusButton' or 'Interface\\Buttons\\UI-MinusButton'
      minimize:SetNormalTexture(art .. '-Up')
      minimize:SetPushedTexture(art .. '-Down')
      minimize:SetHighlightTexture('Interface\\Buttons\\UI-PlusButton-Hilight', 'ADD')
    end
  end
  minimize:SetScript('OnClick', function()
    db.minimized = not db.minimized
    applyLook()
    refresh()
  end)

  -- Settings gear, 27x27, left of the minimize button at -2,-2.
  gear = CreateFrame('Button', nil, header)
  gear:SetSize(27, 27)
  gear:SetPoint('RIGHT', minimize, 'LEFT', -2, -2)
  if hasAtlas('common-dropdown-a-button-settings-shadowless') then
    gear:SetNormalAtlas('common-dropdown-a-button-settings-shadowless')
    gear:SetPushedAtlas('common-dropdown-a-button-settings-pressed-shadowless')
    gear:SetHighlightAtlas('common-dropdown-a-button-settings-hover-shadowless')
  else
    gear:SetSize(18, 18)
    gear:SetNormalTexture('Interface\\Buttons\\UI-OptionsButton')
    gear:SetHighlightTexture('Interface\\Buttons\\UI-OptionsButton', 'ADD')
  end
  gear:SetScript('OnClick', function(self) showMenu(self, SETTINGS) end)

  -- Type dropdown: arrow first, then the name, GameFontNormalMed1.
  titleButton = CreateFrame('Button', nil, header)
  titleButton:SetPoint('TOPLEFT', 4, -5)
  titleButton:SetHeight(22)
  local arrow = titleButton:CreateTexture(nil, 'OVERLAY')
  arrow:SetPoint('LEFT', 0, -1)
  if setAtlas(arrow, 'common-dropdown-a-button-arrow-shadowless', nil, true)
    or setAtlas(arrow, 'friendslist-categorybutton-arrow-down', nil, true) then
    -- sized by the atlas
  else
    arrow:SetTexture('Interface\\Buttons\\Arrow-Down-Up')
    arrow:SetSize(14, 14)
    arrow:SetPoint('LEFT', 0, -4)
  end
  titleText = titleButton:CreateFontString(nil, 'OVERLAY', GameFontNormalMed1 and 'GameFontNormalMed1' or 'GameFontNormal')
  titleText:SetPoint('LEFT', arrow, 'RIGHT', 2, 1)
  titleButton:SetScript('OnClick', function(self) showMenu(self, DISPLAY_MENU) end)
  titleButton:SetScript('OnEnter', function() titleText:SetTextColor(1, 1, 1) end)
  titleButton:SetScript('OnLeave', function() titleText:SetTextColor(1, 0.82, 0) end)

  -- Where the damage meter has its session box, this has the mob's name.
  targetText = header:CreateFontString(nil, 'OVERLAY', GameFontNormalMed1 and 'GameFontNormalMed1' or 'GameFontNormal')
  targetText:SetTextColor(1, 1, 1)
  targetText:SetPoint('RIGHT', gear, 'LEFT', -2, 3)
  targetText:SetPoint('LEFT', titleButton, 'RIGHT', 8, 0)
  targetText:SetJustifyH('RIGHT')
  targetText:SetWordWrap(false)

  -- Resize handle: 60x60 at +9,-8, invisible until the mouse is over the window.
  grip = CreateFrame('Button', nil, frame.body)
  grip:SetFrameLevel(frame:GetFrameLevel() + 10)
  if hasAtlas('damagemeters-scalehandle') then
    grip:SetSize(60, 60)
    grip:SetPoint('BOTTOMRIGHT', 9, -8)
    grip:SetNormalAtlas('damagemeters-scalehandle')
    grip:SetHighlightAtlas('damagemeters-scalehandle-hover')
    grip:SetPushedAtlas('damagemeters-scalehandle-pressed')
    grip:SetHitRectInsets(30, 9, 30, 8)
  else
    grip:SetSize(16, 16)
    grip:SetPoint('BOTTOMRIGHT', -1, 1)
    grip:SetNormalTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up')
    grip:SetHighlightTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight')
    grip:SetPushedTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down')
  end
  grip:SetAlpha(0)
  grip:SetScript('OnMouseDown', function()
    frame.moving = true
    frame:StartSizing('BOTTOMRIGHT')
  end)
  grip:SetScript('OnMouseUp', stopMove)
  frame:SetScript('OnSizeChanged', function() if frame.moving then refresh() end end)

  -- Fade the handle in on mouse-over and out again, as the damage meter does.
  local watcher = CreateFrame('Frame', nil, frame)
  watcher:Hide()
  watcher:SetScript('OnUpdate', function(self, elapsed)
    local over = frame:IsMouseOver() or grip:IsMouseOver() or frame.moving
    local alpha = grip:GetAlpha() + (over and elapsed or -elapsed) * 4
    if alpha >= 1 then alpha = 1 elseif alpha <= 0 then alpha = 0 end
    grip:SetAlpha(alpha)
    if not over and alpha == 0 then self:Hide() end
  end)
  frame.hover = function() watcher:Show() end
  frame:SetScript('OnEnter', frame.hover)
  grip:SetScript('OnEnter', frame.hover)
  header:SetScript('OnEnter', frame.hover)

  applyLook()
end

local function toggleWindow()
  db.shown = not db.shown
  if db.shown and db.combatOnly and not UnitAffectingCombat('player') then
    say('on, and set to appear only in combat.')
  end
  refresh()
end

local function buildMinimapButton()
  mm = CreateFrame('Button', 'ForeverThreatMinimapButton', Minimap)
  mm:SetSize(31, 31)
  mm:SetFrameStrata('MEDIUM')
  mm:SetFrameLevel(8)
  mm:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
  mm:RegisterForDrag('LeftButton')
  mm:SetHighlightTexture('Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight')

  -- The ring's hole is not centred on the button, so the icon is placed by the
  -- ring's own offsets and cut to a circle to keep its corners inside.
  local back = mm:CreateTexture(nil, 'BACKGROUND')
  back:SetTexture('Interface\\Minimap\\UI-Minimap-Background')
  back:SetSize(20, 20)
  back:SetPoint('TOPLEFT', 7, -5)

  local icon = mm:CreateTexture(nil, 'ARTWORK')
  icon:SetTexture(ADDON_ICON)
  icon:SetSize(18, 18)
  icon:SetPoint('TOPLEFT', 7, -6)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  if mm.CreateMaskTexture then
    local mask = mm:CreateMaskTexture()
    mask:SetTexture('Interface\\CharacterFrame\\TempPortraitAlphaMask', 'CLAMPTOBLACKADDITIVE', 'CLAMPTOBLACKADDITIVE')
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)
  end

  local ring = mm:CreateTexture(nil, 'OVERLAY')
  ring:SetTexture('Interface\\Minimap\\MiniMap-TrackingBorder')
  ring:SetSize(53, 53)
  ring:SetPoint('TOPLEFT')

  mm:SetScript('OnDragStart', function(self)
    self:SetScript('OnUpdate', function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      db.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
      updateMinimap()
    end)
  end)
  mm:SetScript('OnDragStop', function(self) self:SetScript('OnUpdate', nil) end)
  mm:SetScript('OnClick', function(self, button)
    if button == 'RightButton' then showMenu(self, SETTINGS) else toggleWindow() end
  end)
  mm:SetScript('OnEnter', function(self)
    GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
    GameTooltip:AddLine('Forever Threat')
    GameTooltip:AddLine('Left-click: show or hide the meter', 1, 1, 1)
    GameTooltip:AddLine('Right-click: settings', 1, 1, 1)
    GameTooltip:AddLine('Drag: move this button', 1, 1, 1)
    GameTooltip:Show()
  end)
  mm:SetScript('OnLeave', function() GameTooltip:Hide() end)
  updateMinimap()
end

-- Slash -----------------------------------------------------------------------

local function slash(msg)
  local cmd = (msg or ''):lower():match('^%s*(%S*)')
  if cmd == 'test' then
    testMode = not testMode
    db.shown = true
  elseif cmd == 'lock' then
    db.locked = not db.locked
    say(db.locked and 'locked.' or 'unlocked.')
  elseif cmd == 'debug' then
    local mob = mobUnit()
    say('mob: ' .. tostring(mob) .. '  friendly nameplates: ' .. tostring(friendlyPlatesOn()))
    if mob then
      local units = { 'player', 'pet', 'party1', 'party2', 'party3', 'party4', mob .. 'target', 'mouseover' }
      for i = 1, 40 do units[#units + 1] = 'nameplate' .. i end
      for _, u in ipairs(units) do
        if UnitExists(u) then
          local ok, t, st, sc, raw, val = pcall(UnitDetailedThreatSituation, u, mob)
          local function show(v) return IsSecret(v) and 'SECRET' or tostring(v) end
          local name = UnitName(u)
          say(u .. ' name=' .. show(name) .. ' ok=' .. tostring(ok) .. ' tank=' .. show(t) .. ' status=' .. show(st)
            .. ' scaled=' .. show(sc) .. ' raw=' .. show(raw) .. ' value=' .. show(val))
        end
      end
    end
  elseif cmd == 'where' then
    local function show(v) return IsSecret(v) and 'SECRET' or tostring(v) end
    say('v1.24 saved left=' .. show(db.left) .. ' top=' .. show(db.top) .. ' scale=' .. show(db.scale))
    say('now left=' .. show(frame:GetLeft()) .. ' top=' .. show(frame:GetTop()) .. ' frameScale=' .. show(frame:GetScale())
      .. ' effScale=' .. show(frame:GetEffectiveScale()))
    say('screen ' .. show(UIParent:GetWidth()) .. ' x ' .. show(UIParent:GetHeight()) .. ' uiScale=' .. show(UIParent:GetEffectiveScale())
      .. ' points=' .. show(frame:GetNumPoints()) .. ' userPlaced=' .. show(frame:IsUserPlaced()))
    say('game restored window: ' .. tostring(trace.restored))
    say('at ADDON_LOADED: ' .. tostring(trace.addonLoaded))
    say('per-character copy at login: ' .. tostring(trace.char))
    say('adopted later: ' .. tostring(trace.adopted))
    say('at PLAYER_LOGIN: ' .. tostring(trace.login) .. '  loads now=' .. tostring(db.loads)
      .. '  same table=' .. tostring(db == ForeverThreatDB))
    for i = 1, frame:GetNumPoints() do
      local p, rel, rp, x, y = frame:GetPoint(i)
      say('point ' .. i .. ': ' .. show(p) .. ' -> ' .. show(rel and rel.GetName and rel:GetName() or rel) .. ' ' .. show(rp) .. ' ' .. show(x) .. ', ' .. show(y))
    end
    return
  elseif cmd == 'instance' then
    db.instanceOnly = not db.instanceOnly
    say('only in an instance ' .. (db.instanceOnly and 'on' or 'off'))
  elseif cmd == 'group' then
    db.groupOnly = not db.groupOnly
    say('only in a group ' .. (db.groupOnly and 'on' or 'off'))
  elseif cmd == 'hints' then
    db.hints = not db.hints
    say('hint text ' .. (db.hints and 'on' or 'off'))
  elseif cmd == 'class' then
    db.classColors = not db.classColors
    say('class colours ' .. (db.classColors and 'on' or 'off'))
  elseif cmd == 'me' then
    db.highlightMe = not db.highlightMe
    say('your bar ' .. (db.highlightMe and 'highlighted' or 'plain'))
  elseif cmd == 'dock' then
    if ns.toggleDock then ns.toggleDock() else say('the damage meter is not loaded, so there is nothing to dock to.') end
  elseif cmd == 'reset' then
    resetPlace()
  elseif cmd == 'minimap' then
    db.minimap = not db.minimap
  elseif cmd == 'options' or cmd == 'config' then
    showMenu(frame:IsShown() and gear or mm, SETTINGS)
  elseif cmd == '' then
    toggleWindow()
  else
    say('/threat (show or hide) | test | lock | reset | minimap | options | group | instance | class | me | hints | dock')
  end
  applyLook()
  updateMinimap()
  refresh()
end

-- Boot ------------------------------------------------------------------------

-- Made now, not at login: the game only puts a moved window back where it was
-- if the window exists by the time it reads its own layout file. This is the
-- second memory for the position, for clients where saved settings do not
-- come back to the addon.
frame = CreateFrame('Frame', 'ForeverThreatFrame', UIParent)
frame:SetSize(DEFAULTS.width, DEFAULTS.height)
frame:SetMovable(true)
frame:SetResizable(true)
if frame.SetUserPlaced then pcall(frame.SetUserPlaced, frame, true) end
frame:Hide()

local driver = CreateFrame('Frame')
driver:RegisterEvent('ADDON_LOADED')
driver:RegisterEvent('PLAYER_LOGIN')
driver:RegisterEvent('PLAYER_LOGOUT')
driver:SetScript('OnEvent', function(self, event, arg1)
  if event == 'ADDON_LOADED' then
    if arg1 == ADDON then
      local t = ForeverThreatDB
      trace.addonLoaded = 'type=' .. type(t) .. ' left=' .. tostring(type(t) == 'table' and t.left or nil)
        .. ' loads=' .. tostring(type(t) == 'table' and t.loads or nil)
    end
    return
  end
  if event == 'PLAYER_LOGOUT' then
    if frame and frame.savePlace then frame.savePlace() end
    return
  end
  if event ~= 'PLAYER_LOGIN' then
    -- If the game hands over the saved settings after login on this client,
    -- switch to them the moment they appear.
    if db and type(ForeverThreatDB) == 'table' and ForeverThreatDB ~= db then
      trace.adopted = event
      db = ForeverThreatDB
      ns.db = db
      for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
      end
      if frame then
        placePending = not placeFrame()
        applyLook()
        updateMinimap()
      end
    end
    refresh()
    return
  end

  trace.login = 'type=' .. type(ForeverThreatDB) .. ' left=' .. tostring(type(ForeverThreatDB) == 'table' and ForeverThreatDB.left or nil)
  trace.char = 'type=' .. type(ForeverThreatCharDB)
  -- This client does not hand the account-wide settings back. Try the
  -- per-character copy as a second route, and keep both written.
  if type(ForeverThreatDB) ~= 'table' then
    ForeverThreatDB = type(ForeverThreatCharDB) == 'table' and ForeverThreatCharDB or {}
  end
  db = ForeverThreatDB
  ForeverThreatCharDB = db
  ns.db = db
  db.loads = (db.loads or 0) + 1
  if (db.v or 1) < 6 and db.alpha == 0.4 then
    -- 1.24: old default 0.4 is off the new 0/25/50/75/100 steps.
    db.alpha = nil
  end
  if (db.v or 1) < 5 then
    -- 1.19: row height and text size re-measured against the damage meter.
    db.barHeight, db.textScale = nil, nil
  end
  if (db.v or 1) < 4 then
    -- 1.10: rows were much taller than the damage meter's; take the new sizes.
    db.barHeight, db.textScale = nil, nil
  end
  if (db.v or 1) < 3 then
    -- 1.3: start unlocked and see-through, whatever an earlier version saved.
    db.locked, db.alpha = false, nil
  end
  if (db.v or 1) < 2 then
    -- 1.2 took its sizes from the damage meter; drop the older look.
    db.width, db.height, db.barHeight, db.alpha, db.fontSize = nil, nil, nil, nil, nil
  end
  db.v = 6
  for k, v in pairs(DEFAULTS) do
    if db[k] == nil then db[k] = v end
  end

  SLASH_FOREVERTHREAT1 = '/threat'
  SLASH_FOREVERTHREAT2 = '/fthreat'

  if type(UnitDetailedThreatSituation) ~= 'function' then
    SlashCmdList.FOREVERTHREAT = function() say('this client has no threat API, so there is nothing to show.') end
    say('this client has no threat API, so there is nothing to show.')
    return
  end

  buildFrame()
  buildMinimapButton()
  SlashCmdList.FOREVERTHREAT = slash

  for _, e in ipairs({
    'PLAYER_ENTERING_WORLD', 'PLAYER_TARGET_CHANGED', 'GROUP_ROSTER_UPDATE',
    'PLAYER_REGEN_DISABLED', 'PLAYER_REGEN_ENABLED',
    'UNIT_THREAT_LIST_UPDATE', 'UNIT_THREAT_SITUATION_UPDATE',
  }) do
    pcall(self.RegisterEvent, self, e)
  end

  -- Events cover most changes; the tick catches targettarget swaps and threat
  -- that moves without an event.
  local since = 0
  self:SetScript('OnUpdate', function(_, elapsed)
    since = since + elapsed
    if since >= TICK then
      since = 0
      -- If the button is up, the move is over, whatever did or did not report it.
      if frame and frame.moving and IsMouseButtonDown and not IsMouseButtonDown('LeftButton') then
        stopMove()
      end
      refresh()
    end
  end)

  refresh()
  say('1.24 loaded. Minimap button or /threat. /threat test shows sample bars.')
end)

-- Shared with ForeverThreatDock.lua, which draws the same list inside the
-- built-in damage meter's window.
ns.entries = entries
ns.collect = collect
ns.collectTest = collectTest
ns.isTest = function() return testMode end
ns.rowColor = rowColor
ns.rowTooltip = rowTooltip
ns.short = short
ns.plain = plain
ns.IsSecret = IsSecret
ns.mobUnit = mobUnit
ns.say = say
ns.getFrame = function() return frame end
ns.refresh = function() if refresh then refresh() end end
