local _, FLT = ...
local UI = FLT.UI
local makeTexture, makeButton = UI.makeTexture, UI.makeButton

-- "Noteworthy changes" popup. Shown once per account after logging in with a
-- new NEWS_ID (change it for the next release with news). /ofa news reopens it.
-- 5.6.3 (user 16.10.): only the Gear Planner. 5.7.0 (user 22.10.): Quality of Life, enchants, set buttons.
-- 6.0.2 (user 01.11.): World Map, dungeon quests, Gear Planner filters, talent import - not shown automatically.

local NEWS_AUTO = false -- set true (and a new NEWS_ID) for the next release with news
-- 6.0.2 (agreed with the user 01.11.): four entries, filled but NOT shown automatically (the welcome setup opens for
-- new players, both at once would be too much); /ofa news and Settings > Window show them
local NEWS_ID = "6.0.2"

-- images (optional): pictures in a row under the lines, each { tex, shown width, shown height, texcoord right,
-- texcoord bottom } (made by tools/art/proc_news.py from the user's screenshots in source_images/news)
local NEWS = {
  { icon = "Interface\\Icons\\INV_Misc_Map_01", title = "World Map", tab = "qol", button = "Open Quality of Life",
    lines = {
      "Quest icons: a yellow ! at quest givers with quests for your level, a ? where you turn in finished quests (hidden with Questie).",
      "The zone's level range, zone transitions and a OneForAll button with all map switches.",
    } },
  { icon = "Interface\\Icons\\INV_Misc_Note_02", title = "Dungeons - quests", tab = "dungeons", button = "Open Dungeons & Raids",
    lines = {
      "Share all Quests: one click shares every dungeon quest your group still needs.",
      "Quest marks on nameplates: a sword or bag with your progress on mobs you need (Quality of Life > Quests).",
    } },
  { icon = "Interface\\Icons\\INV_Chest_Chain_05", title = "Gear Planner", tab = "armory", button = "Open Armory",
    lines = {
      "Filter by source (dungeon, raid, quest, crafted ...), crafted items only from your professions, and a button to the recipe.",
    } },
  { icon = "Interface\\Icons\\Ability_Marksmanship", title = "Talent Trees - import", tab = "talents", button = "Open Talent Trees",
    lines = {
      "Buttons for talentsforever.com and wowforevertalents.com: copy the link, plan your build there and paste it back.",
    } },
}

local frame

local function addonVersion()
  local v
  if C_AddOns and C_AddOns.GetAddOnMetadata then v = C_AddOns.GetAddOnMetadata("OneForAll", "Version")
  elseif GetAddOnMetadata then v = GetAddOnMetadata("OneForAll", "Version") end
  return v or NEWS_ID
end

local function create()
  local f = CreateFrame("Frame", "OneForAllWhatsNew", UIParent)
  f:SetSize(560, 200); f:SetPoint("CENTER", 0, 60); f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if UISpecialFrames then table.insert(UISpecialFrames, "OneForAllWhatsNew") end -- Esc closes it

  UI.FramedPanel(f)
  for _, t in ipairs(UI.OrnateFrame(f, f, 18, 3, "OVERLAY", 4)) do t:SetVertexColor(FLT.SkinC(1, 1, 1, 1)) end
  local band = makeTexture(f, "BORDER", 0.075, 0.062, 0.040, 0.90); band:SetPoint("TOPLEFT", 3, -3); band:SetPoint("TOPRIGHT", -3, -3); band:SetHeight(50)
  local dv = f:CreateTexture(nil, "ARTWORK"); FLT.SetTex(dv, UI.ASSET_ROOT .. "divider_ornate"); dv:SetHeight(14); dv:SetPoint("TOPLEFT", 6, -46); dv:SetPoint("TOPRIGHT", -6, -46)

  local logo = f:CreateTexture(nil, "OVERLAY"); logo:SetSize(34, 34); logo:SetPoint("TOPLEFT", 12, -8)
  FLT.SetTex(logo, "Interface\\AddOns\\OneForAll\\Assets\\minimap_icon")
  local title = UI.SmallCaps(f, "OneForAll - Noteworthy changes", 19, 15, {1, 0.82, 0.20}, "GameFontNormalLarge"); title:SetPoint("TOPLEFT", 54, -9)
  local ver = FLT.NewFS(f, nil, "OVERLAY", "GameFontDisableSmall"); ver:SetPoint("TOPLEFT", 54, -30)
  ver:SetText("Version " .. addonVersion())

  local close = UI.CloseButton(f); close:SetPoint("TOPRIGHT", -12, -12)

  local class = UnitClass and select(2, UnitClass("player"))
  local y = -70
  for _, entry in ipairs(NEWS) do
    do
      local ic = f:CreateTexture(nil, "ARTWORK"); ic:SetSize(36, 36); ic:SetPoint("TOPLEFT", 16, y)
      FLT.SetTex(ic, entry.icon); ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      if ic.AddMaskTexture and f.CreateMaskTexture then
        local m = f:CreateMaskTexture(); FLT.SetTex(m, UI.ASSET_ROOT .. "talent_icon_mask2", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); m:SetAllPoints(ic); ic:AddMaskTexture(m)
      end
      local icf = f:CreateTexture(nil, "OVERLAY"); FLT.SetTex(icf, UI.ASSET_ROOT .. "talent_frame"); icf:SetPoint("TOPLEFT", ic, -3, 3); icf:SetPoint("BOTTOMRIGHT", ic, 3, -3); icf:SetVertexColor(FLT.SkinC(0.98, 0.76, 0.30, 1))
      local h = FLT.NewFS(f, nil, "OVERLAY", "GameFontNormal"); h:SetPoint("TOPLEFT", 62, y - 2)
      h:SetText(entry.title .. (entry.note and ("  |cff9d9d9d" .. entry.note .. "|r") or "")); h:SetTextColor(FLT.SkinC(1, 0.82, 0.20))
      -- the button only for characters that have that tab (Hunter Pets: hunters)
      if entry.tab and (not entry.buttonClass or entry.buttonClass == class) then
        local b = UI.GoldButton(f, entry.button, 150, 24, nil, 12); b:SetPoint("TOPRIGHT", -16, y)
        b:SetScript("OnClick", function() f:Hide(); if FLT.OpenPanel then FLT:OpenPanel(entry.tab) end end)
      end
      local ly = y - 24
      for _, line in ipairs(entry.lines) do
        local dot = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall"); dot:SetPoint("TOPLEFT", 64, ly); dot:SetText(FLT.SkinHex("d9a63a") .. "•|r")
        local t = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall"); t:SetPoint("TOPLEFT", 76, ly)
        -- the lines stay left of the buttons column (user 22.10.); full width only for entries without a button
        t:SetWidth(entry.tab and 308 or 460); t:SetJustifyH("LEFT"); t:SetText(line); t:SetTextColor(FLT.SkinC(0.90, 0.88, 0.82))
        ly = ly - math.max(16, (t:GetStringHeight() or 12) + 5)
      end
      if entry.images then
        local x, hmax = 76, 0
        for _, im in ipairs(entry.images) do
          local pic = f:CreateTexture(nil, "ARTWORK"); pic:SetSize(im[2], im[3]); pic:SetPoint("TOPLEFT", x, ly - 4)
          FLT.SetTex(pic, UI.ASSET_ROOT .. im[1]); pic:SetTexCoord(0, im[4], 0, im[5])
          local pf = CreateFrame("Frame", nil, f); pf:SetAllPoints(pic)
          UI.OrnateFrame(pf, pf, 10, 2, "OVERLAY", 1)
          x = x + im[2] + 10; hmax = math.max(hmax, im[3])
        end
        ly = ly - hmax - 12
      end
      y = ly - 14
    end
  end

  local foot = FLT.NewFS(f, nil, "OVERLAY", "GameFontDisableSmall"); foot:SetPoint("BOTTOMLEFT", 16, 16)
  foot:SetText("Type /ofa news to show this again.")
  local ok = UI.GoldButton(f, "Got it", 110, 26, nil, 13); ok:SetPoint("BOTTOMRIGHT", -16, 14)
  ok:SetScript("OnClick", function() f:Hide() end)

  f:SetHeight(-y + 40)
  f:Hide()
  return f
end

function FLT.ShowNews()
  if not frame then frame = create() end
  frame:Show()
  if type(OneForAllDB) == "table" then OneForAllDB.newsSeen = NEWS_ID end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  if not NEWS_AUTO then return end -- 6.0.0: no news popup, a clean start; only the welcome setup (user 27.10.)
  if type(OneForAllDB) ~= "table" then return end
  if FLT.WelcomeDue and FLT.WelcomeDue() then return end -- the welcome setup first; the news come with the next login
  local seen = OneForAllDB.newsSeen
  if type(seen) == "string" and (seen == NEWS_ID or seen:sub(1, #NEWS_ID + 1) == NEWS_ID .. ".") then return end
  if C_Timer and C_Timer.After then C_Timer.After(6, FLT.ShowNews) else FLT.ShowNews() end
end)
