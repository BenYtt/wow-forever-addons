-- Books on map (Forever): side tabs on the right of the options window, one panel open at a time
local _, ns = ...
local S = ns.Skin

local TAB_SIZE = 40
local TAB_SPACING = 48 -- vertical distance between two tabs

local tabs = {} -- { id = ..., button = ..., panel = ... } in creation order
local window

-- rounded tab: icon, pulsing gold glow when selected, glow fade on hover
local function createButton(parent, icon)
  local t = CreateFrame("Button", nil, parent)
  t:SetSize(TAB_SIZE, TAB_SIZE)
  S.Shadow(t, 8, 0.6)
  S.Rounded(t, 8)

  t.glow = t:CreateTexture(nil, "BACKGROUND", nil, -6)
  t.glow:SetTexture(S.MEDIA .. "Glow")
  t.glow:SetBlendMode("ADD")
  t.glow:SetPoint("CENTER")
  t.glow:SetSize(TAB_SIZE * 1.9, TAB_SIZE * 1.9)
  t.glow:SetVertexColor(0.3, 0.72, 1, 0.6)
  t.glow:SetAlpha(0)

  t.icon = t:CreateTexture(nil, "ARTWORK")
  t.icon:SetPoint("TOPLEFT", 6, -6)
  t.icon:SetPoint("BOTTOMRIGHT", -6, 6)
  t.icon:SetTexture(icon)
  t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local gloss = t:CreateTexture(nil, "OVERLAY")
  gloss:SetAllPoints(t.icon)
  gloss:SetTexture(S.MEDIA .. "Gloss")

  -- selected: glow breathes
  local clock = 0
  t:SetScript("OnUpdate", function(self, elapsed)
    if not self.open then return end
    clock = clock + elapsed
    self.glow:SetAlpha(0.6 + 0.4 * math.sin(clock * 2.5))
  end)
  return t
end

-- shows the selected panel; the tabs sit on the right edge of the window, or of the open panel
local function layout()
  local anchor = window
  for _, tab in ipairs(tabs) do
    local open = ns.db.sideTab == tab.id
    local b = tab.button
    local p = tab.panel
    if open and (not p:IsShown() or p.closing) then
      if p.closing then
        p.closing = nil
        S.AnimateOpen(p, p.openDX, p.openDY) -- reopened while sliding away
      else
        p:Show()
      end
    elseif not open and p:IsShown() and not p.closing then
      p.closing = true
      S.AnimateClose(p, p.openDX, p.openDY)
    end
    if open then anchor = tab.panel end
    b.open = open
    b.icon:SetDesaturated(not open)
    b.icon:SetVertexColor(open and 1 or 0.75, open and 1 or 0.75, open and 1 or 0.75)
    b:SetBorderColor(S.Color(open and S.C.gold or S.C.trim))
    if not open then S.FadeTo(b.glow, 0, 0.2) end
  end
  for i, tab in ipairs(tabs) do
    tab.button:ClearAllPoints()
    tab.button:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 6, -50 - (i - 1) * TAB_SPACING)
  end
end

-- empty panel (window background + title row) to the right of the window, slides out of it
function ns.CreateSidePanel(f, title, width)
  local p = S.Window(nil, f, width, 100, title)
  p:SetPoint("TOPLEFT", f, "TOPRIGHT", 6, 0)
  p.openDX, p.openDY = -24, 0
  p.close:SetScript("OnClick", function() ns.db.sideTab = nil; layout() end)
  p:Hide()
  return p
end

function ns.AddSideTab(f, id, icon, tooltipTitle, tooltipText, panel)
  window = f
  -- before the group tab, the rewards panel was a simple on/off
  if ns.db.showRewards then ns.db.sideTab, ns.db.showRewards = "rewards", nil end

  local button = createButton(f, icon)
  button:SetScript("OnClick", function()
    ns.db.sideTab = ns.db.sideTab ~= id and id or nil
    layout()
  end)
  button:SetScript("OnEnter", function(self)
    self.icon:SetDesaturated(false)
    self.icon:SetVertexColor(1, 1, 1)
    if not self.open then S.FadeTo(self.glow, 0.6, 0.15) end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(tooltipTitle)
    GameTooltip:AddLine(tooltipText, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
    layout()
  end)

  tabs[#tabs + 1] = { id = id, button = button, panel = panel }
  layout()
end
