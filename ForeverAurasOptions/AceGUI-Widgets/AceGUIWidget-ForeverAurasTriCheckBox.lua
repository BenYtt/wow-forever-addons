-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
-- A three-state checkbox for multi selections: off (nil), on (true, the usual
-- check) and excluded (false, a red check). A click moves off -> on -> excluded
-- -> off. Used by load conditions that let an entry rule itself out, such as
-- "never load for this specialization".
if not WeakAuras.IsLibsOK() then return end
local AceGUI = LibStub("AceGUI-3.0")
local L = WeakAuras.L

local Type, Version = "ForeverAurasTriCheckBox", 1
local base = AceGUI.WidgetRegistry and AceGUI.WidgetRegistry["CheckBox"]
if not base then return end

local function Constructor()
  local widget = base()
  widget.type = Type
  -- Always three states: the dialog's own tristate flag may not reach here.
  local baseSetTriState = widget.SetTriState
  widget.SetTriState = function(self) baseSetTriState(self, true) end
  -- Like the tri-state conditions: an empty box when off, a check with a
  -- green label when on, a red check and a red "Not ..." label when excluded.
  local baseSetValue, baseSetLabel = widget.SetValue, widget.SetLabel
  local function Paint(self)
    local label = self.rawLabel or ""
    local value = self.checked
    if value == true then
      baseSetLabel(self, "|cFF00FF00" .. label .. "|r")
    elseif value == false then
      baseSetLabel(self, "|cFFFF0000" .. (L and L["Negator"] or "Not") .. " " .. label .. "|r")
    else
      baseSetLabel(self, label)
    end
  end
  widget.SetLabel = function(self, label)
    self.rawLabel = label
    Paint(self)
  end
  widget.SetValue = function(self, value)
    -- The base widget draws nil as a grey check; here nil is an empty box.
    local wasTristate = self.tristate
    self.tristate = nil
    baseSetValue(self, value == true)
    self.tristate = wasTristate
    self.checked = value
    local check = self.check
    if value == false then
      check:SetDesaturated(true)
      check:SetVertexColor(1, 0.15, 0.15, 1)
      check:Show()
    else
      check:SetDesaturated(false)
      check:SetVertexColor(1, 1, 1, 1)
    end
    Paint(self)
  end
  -- Off -> on -> excluded -> off (AceGUI's own order is on -> off -> excluded).
  widget.ToggleChecked = function(self)
    local value = self:GetValue()
    if value == nil then self:SetValue(true)
    elseif value == true then self:SetValue(false)
    else self:SetValue(nil) end
  end
  widget.SetTriState(widget)
  return widget
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
