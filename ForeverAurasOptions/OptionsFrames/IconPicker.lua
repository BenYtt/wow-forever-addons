-- Modified for ForeverAuras, 2026-10-03.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class OptionsPrivate
local OptionsPrivate = select(2, ...)

-- Lua APIs
local pairs, ipairs, tinsert  = pairs, ipairs, tinsert

-- WoW APIs
local CreateFrame = CreateFrame

local AceGUI = LibStub("AceGUI-3.0")

---@class WeakAuras
local WeakAuras = WeakAuras
local L = WeakAuras.L

local iconPicker

-- The game icon list covers every client; names missing from this one would
-- draw as green squares, so each is checked against the client's file manifest
-- once and remembered.
local gameIconExists = {}
function OptionsPrivate.GameIconExists(name)
  local known = gameIconExists[name]
  if known ~= nil then return known end
  local exists = true
  if GetFileIDFromPath then
    exists = GetFileIDFromPath("Interface\\Icons\\" .. name) ~= nil
  end
  gameIconExists[name] = exists
  return exists
end

local spellCache = WeakAuras.spellCache

local function ConstructIconPicker(frame)
  local group = AceGUI:Create("InlineGroup");
  group.frame:SetParent(frame);
  group.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -17, 46);
  group.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 17, -50);
  group.frame:Hide();
  group:SetLayout("fill");

  local scroll = AceGUI:Create("ScrollFrame");
  scroll:SetLayout("flow");
  scroll.frame:SetClipsChildren(true);
  group:AddChild(scroll);

  -- Opens on All Icons: a search then covers spells, achievements, the
  -- game's icons and the icon library at once, rather than spells alone.
  local source = "all"
  local MAX_RESULTS = 500
  local MAX_FOLDER_RESULTS = 1000

  local function iconPickerFill(subname, doSort)
    scroll:ReleaseChildren();

    local usedIcons = {};
    local num = 0;
    local limit = MAX_RESULTS
    local AddButton = function(name, icon)
      if usedIcons[icon] or num >= limit then return end
      local button = AceGUI:Create("WeakAurasIconButton");
      button:SetName(name);
      button:SetTexture(icon);
      button:SetClick(function()
        group:Pick(icon);
      end);
      scroll:AddChild(button);

      usedIcons[icon] = true;
      num = num + 1
    end

    local library = OptionsPrivate.IconLibrary
    -- ForeverAuras: the library is a static list (addons cannot read folders),
    -- so a file deleted from its addon is still named here. Each file is
    -- probed once per session with a hidden texture: SetTexture reports
    -- whether the file exists, and missing ones are left out of the picker.
    local function FileExists(path)
      local known = OptionsPrivate.iconFilesSeen
      if not known then known = {}; OptionsPrivate.iconFilesSeen = known end
      local seen = known[path]
      if seen ~= nil then return seen end
      local probe = OptionsPrivate.iconFileProbe
      if not probe then probe = UIParent:CreateTexture(); probe:Hide(); OptionsPrivate.iconFileProbe = probe end
      local ok = probe:SetTexture(path) == true
      probe:SetTexture(nil)
      known[path] = ok
      return ok
    end
    local function AddLibrary(filter, onlyFolder)
      if not library then return end
      for index, folder in ipairs(library.folders) do
        -- Folders of another addon (FojjiCore) are offered only while it is loaded.
        if (not onlyFolder or onlyFolder == index) and OptionsPrivate.IconFolderAvailable(folder) then
          for _, file in ipairs(folder.files) do
            local name = file:gsub("%.%a+$", ""):gsub("^.*\\", "")
            if not filter or name:lower():find(filter, 1, true) or folder.name:lower():find(filter, 1, true) then
              local path = (folder.root or library.root) .. folder.path .. file
              if FileExists(path) then
                AddButton(name, path)
                if num >= limit then return end
              end
            end
          end
          if folder.game then
            for _, entry in ipairs(folder.game) do
              if not filter or entry[1]:lower():find(filter, 1, true) or folder.name:lower():find(filter, 1, true) then
                AddButton(entry[1], entry[2])
                if num >= limit then return end
              end
            end
          end
        end
      end
    end

    local function AddGameIcons(filter)
      local names = OptionsPrivate.GameIconNames
      if not names then return end
      local altFilter = filter and filter:gsub(" ", "_")
      for name, fileID in names:gmatch("([^\n]+)=(%d+)") do
        if (not filter or name:find(filter, 1, true) or name:find(altFilter, 1, true)) and OptionsPrivate.GameIconExists(name) then
          AddButton(name, tonumber(fileID))
          if num >= limit then return end
        end
      end
    end

    local function AddSpells(filter)
      for name, icons in pairs(spellCache.Get()) do
        if name:lower():find(filter, 1, true) then
          local list = icons.spells or icons.achievements
          if list then
            for _, icon in list:gmatch("(%d+)=(%d+)") do
              AddButton(name, tonumber(icon))
              if num >= limit then return end
            end
          end
        end
      end
    end

    if source == "all" or source == "spells" then
      -- Work around special numbers such as inf and nan
      if (tonumber(subname)) then
        local spellId = tonumber(subname);
        if (abs(spellId) < math.huge and tostring(spellId) ~= "nan") then
          local name, _, icon = OptionsPrivate.Private.ExecEnv.GetSpellInfo(spellId)
          if name and icon then
            AddButton(name, icon)
          end
          if spellId > 0 and spellId == math.floor(spellId) then
            AddButton(tostring(spellId), spellId)
          end
          return;
        end
      end

      if subname and subname ~= "" then
        local name, _, icon = OptionsPrivate.Private.ExecEnv.GetSpellInfo(subname)
        if name and icon then AddButton(name, icon) end
      end
    end

    local filter = subname and subname ~= "" and subname:lower() or nil

    if type(source) == "number" then
      limit = MAX_FOLDER_RESULTS
      AddLibrary(filter, source)
    elseif source == "game" then
      AddGameIcons(filter)
    elseif source == "spells" then
      if filter then AddSpells(filter) end
    else
      -- All Icons lists the game's own icons before the icon library, so a
      -- search (or an unfiltered browse) starts with spell-style icons rather
      -- than the library's emotes; the library folders stay reachable from the
      -- source dropdown and after the game icons.
      if filter then AddSpells(filter) end
      AddGameIcons(filter)
      AddLibrary(filter)
    end
  end

  local input = CreateFrame("EditBox", "WeakAurasFilterInput", group.frame, "SearchBoxTemplate")
  input:SetScript("OnTextChanged", function(self)
    SearchBoxTemplate_OnTextChanged(self)
    iconPickerFill(input:GetText(), false)
  end);
  input:SetScript("OnEnterPressed", function(...) iconPickerFill(input:GetText(), true); end);
  input:SetScript("OnEscapePressed", function(...) input:SetText(""); iconPickerFill(input:GetText(), true); end);
  input:SetWidth(200);
  input:SetHeight(15);
  input:SetFont(STANDARD_TEXT_FONT, 10, "")
  input:SetPoint("BOTTOMRIGHT", group.frame, "TOPRIGHT", -3, -10);

  function OptionsPrivate.RefreshIconPicker()
    if group.frame:IsShown() then iconPickerFill(input:GetText(), false) end
  end

  local sourceList = {
    spells = L["Spells & Achievements"],
    all = L["All Icons"],
    game = L["Game Icons"],
  }
  local sourceOrder = { "spells", "all", "game" }
  if OptionsPrivate.IconLibrary then
    for index, folder in ipairs(OptionsPrivate.IconLibrary.folders) do
      if OptionsPrivate.IconFolderAvailable(folder) then
        sourceList[index] = folder.name
        tinsert(sourceOrder, index)
      end
    end
  end
  local sourceDropdown = AceGUI:Create("Dropdown")
  sourceDropdown.frame:SetParent(group.frame)
  sourceDropdown:SetLabel(nil)
  sourceDropdown:SetWidth(200)
  sourceDropdown:SetList(sourceList, sourceOrder)
  sourceDropdown:SetValue(source)
  sourceDropdown:SetCallback("OnValueChanged", function(_, _, value)
    source = value
    iconPickerFill(input:GetText(), false)
  end)
  sourceDropdown.frame:SetPoint("RIGHT", input, "LEFT", -12, 0)
  sourceDropdown.frame:Show()

  local icon = AceGUI:Create("WeakAurasIconButton");
  icon.frame:Disable();
  icon.frame:SetParent(group.frame);
  icon.frame:SetPoint("BOTTOMLEFT", group.frame, "TOPLEFT", 44, -15);
  icon:SetHeight(36)
  icon:SetWidth(36)

  local iconLabel = input:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge");
  iconLabel:SetNonSpaceWrap("true");
  iconLabel:SetJustifyH("LEFT");
  iconLabel:SetPoint("LEFT", icon.frame, "RIGHT", 5, 0);
  iconLabel:SetPoint("RIGHT", sourceDropdown.frame, "LEFT", -10, 0);

  function group.Pick(self, texturePath)
    local valueToPath = OptionsPrivate.Private.ValueToPath
    if self.groupIcon then
      valueToPath(self.baseObject, self.paths[self.baseObject.id], texturePath)
      WeakAuras.Add(self.baseObject)
      WeakAuras.ClearAndUpdateOptions(self.baseObject.id)
      WeakAuras.UpdateThumbnail(self.baseObject)
    else
      for child in OptionsPrivate.Private.TraverseLeafsOrAura(self.baseObject) do
        valueToPath(child, self.paths[child.id], texturePath)
        WeakAuras.Add(child)
        WeakAuras.ClearAndUpdateOptions(child.id)
        WeakAuras.UpdateThumbnail(child);
      end
    end
    local success = icon:SetTexture(texturePath) and texturePath;
    if(success) then
      iconLabel:SetText(texturePath);
    else
      iconLabel:SetText();
    end
  end

  function group.Open(self, baseObject, paths, groupIcon)
    local valueFromPath = OptionsPrivate.Private.ValueFromPath
    self.baseObject = baseObject
    self.paths = paths
    self.groupIcon = groupIcon
    if groupIcon then
      local value = valueFromPath(self.baseObject, paths[self.baseObject.id])
      self.givenPath = value
    else
      self.givenPath = {};
      for child in OptionsPrivate.Private.TraverseLeafsOrAura(baseObject) do
        if child and paths[child.id] then
          local value = valueFromPath(child, paths[child.id])
          if value == nil then value = false end
          self.givenPath[child.id] = value;
        end
      end
    end
    -- group:Pick(self.givenPath);
    frame.window = "icon";
    frame:UpdateFrameVisible()
    input:SetText("");
  end

  function group.Close()
    frame.window = "default";
    frame:UpdateFrameVisible()
    WeakAuras.FillOptions()
  end

  function group.CancelClose()
    local valueToPath = OptionsPrivate.Private.ValueToPath
    if group.groupIcon then
      valueToPath(group.baseObject, group.paths[group.baseObject.id], group.givenPath)
      WeakAuras.Add(group.baseObject)
      WeakAuras.ClearAndUpdateOptions(group.baseObject.id)
      WeakAuras.UpdateThumbnail(group.baseObject)
    else
      for child in OptionsPrivate.Private.TraverseLeafsOrAura(group.baseObject) do
        if (group.givenPath[child.id] ~= nil) then
          valueToPath(child, group.paths[child.id], group.givenPath[child.id] or nil)
          WeakAuras.Add(child);
          WeakAuras.ClearAndUpdateOptions(child.id)
          WeakAuras.UpdateThumbnail(child);
        end
      end
    end

    group.Close();
  end

  local cancel = CreateFrame("Button", nil, group.frame, "UIPanelButtonTemplate");
  cancel:SetScript("OnClick", group.CancelClose);
  cancel:SetPoint("BOTTOMRIGHT", -20, -24)
  cancel:SetHeight(20);
  cancel:SetWidth(100);
  cancel:SetText(L["Cancel"]);

  local close = CreateFrame("Button", nil, group.frame, "UIPanelButtonTemplate");
  close:SetScript("OnClick", group.Close);
  close:SetPoint("RIGHT", cancel, "LEFT", -10, 0);
  close:SetHeight(20);
  close:SetWidth(100);
  close:SetText(L["Okay"]);

  return group
end

function OptionsPrivate.IconPicker(frame, noConstruct)
  iconPicker = iconPicker or (not noConstruct and ConstructIconPicker(frame))
  return iconPicker
end
