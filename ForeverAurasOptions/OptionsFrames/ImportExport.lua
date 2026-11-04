-- Modified for ForeverAuras, 2026-09-18.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class OptionsPrivate
local OptionsPrivate = select(2, ...)

-- WoW APIs
local CreateFrame = CreateFrame

local AceGUI = LibStub("AceGUI-3.0")

---@class WeakAuras
local WeakAuras = WeakAuras
local L = WeakAuras.L

local importexport

local function ConstructImportExport(frame)
  local group = AceGUI:Create("WeakAurasInlineGroup");
  group.frame:SetParent(frame);
  group.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -63);
  group.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 46);
  group.frame:Hide();
  group:SetLayout("flow");

  local input = AceGUI:Create("MultiLineEditBox");
  input:DisableButton(true)
  input.frame:SetClipsChildren(true);
  input:SetFullWidth(true)
  input:SetFullHeight(true)
  group:AddChild(input);

  local close = CreateFrame("Button", nil, group.frame, "UIPanelButtonTemplate");
  close:SetScript("OnClick", function() group:Close() end);
  close:SetPoint("BOTTOMRIGHT", -20, -24);
  close:SetFrameLevel(close:GetFrameLevel() + 1)
  close:SetHeight(20);
  close:SetWidth(100);
  close:SetText(L["Close"])

  local function Import_OnUpdate(self, elapsed)
    self:SetScript("OnUpdate", nil);
    local pasted = table.concat(self.buffer):trim()
    self.buffer = {};
    self.bufferPos = 0;

    pasted = pasted:match("^%s*(.-)%s*$")
    self:SetMaxBytes(5000);
    if #pasted > 4000 then -- show truncated message to reduce lag
      self:SetText(pasted:sub(1, 4000).. "\n\n"..L["Input is too long to display. If you see this message, there is likely something wrong with your import string."]);
    else
      self:SetText(pasted);
    end
    if #pasted > 20 then
      WeakAuras.Import(pasted)
    end
  end

  function group.Open(self, mode, id)
    if(frame.window == "texture") then
      local texturepicker = OptionsPrivate.TexturePicker(frame, true)
      if texturepicker then
        texturepicker:CancelClose();
      end
    elseif(frame.window == "icon") then
      local iconpicker = OptionsPrivate.IconPicker(frame, true)
      if iconpicker then
        iconpicker:CancelClose();
      end
    elseif(frame.window == "model") then
      local modelpicker = OptionsPrivate.ModelPicker(frame, true)
      if modelpicker then
        modelpicker:CancelClose();
      end
    end
    frame.window = "importexport";
    frame:UpdateFrameVisible()
    if(mode == "export" or mode == "table") then
      OptionsPrivate.SetTitle(L["Exporting"])
      if(id) then
        local displayStr;
        if(mode == "export") then
          displayStr = OptionsPrivate.Private.DisplayToString(id, true);
        elseif(mode == "table") then
          displayStr = OptionsPrivate.Private.DataToString(id, true);
        end
        input.editBox:SetMaxBytes((2^32/2)-1);
        input.editBox:SetScript("OnChar", nil);
        input.editBox:SetScript("OnEscapePressed", function()
          group:Close();
        end);
        input.editBox:SetScript("OnTextChanged", function()
          input:SetText(displayStr); input.editBox:HighlightText();
        end);
        input.editBox:SetScript("OnMouseUp", function()
          input.editBox:HighlightText();
        end);
        input:SetLabel(id.." - "..#displayStr);
        input.button:Hide();
        input:SetText(displayStr);
        input.editBox:HighlightText();
        input:SetFocus();
      end
    elseif(mode == "import") then
      OptionsPrivate.SetTitle(L["Importing"])
      input.editBox:SetText("");
      input.editBox:SetMaxBytes(1);
      input.editBox.buffer = {};
      input.editBox.bufferPos = 0;
      input.editBox:SetScript("OnChar", function(self, char)
        self.bufferPos = self.bufferPos + 1;
        self.buffer[self.bufferPos] = char;

        self:SetScript("OnUpdate", Import_OnUpdate);
      end)
      input.editBox:SetScript("OnEscapePressed", function() group:Close(); end);
      input.editBox:SetScript("OnMouseUp", nil);
      input:SetLabel(L["Paste text below"]);
      input:SetFocus();
    end
    group:DoLayout()
  end

  function group.Close()
    input:ClearFocus();
    frame.window = "default";
    frame:UpdateFrameVisible()
  end

  return group
end

function OptionsPrivate.ImportExport(frame, noConstruct)
  importexport = importexport or (not noConstruct and ConstructImportExport(frame))
  return importexport
end
