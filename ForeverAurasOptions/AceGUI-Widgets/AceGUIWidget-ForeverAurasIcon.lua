-- Modified for ForeverAuras, 2026-09-18.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
--[[-----------------------------------------------------------------------------
Icon Widget that allows for a tooltip, by preventing SetLabel from actually
setting a label
Graphical Button.
-------------------------------------------------------------------------------]]
if not WeakAuras.IsLibsOK() then return end

local Type, Version = "WeakAurasIcon", 2
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local function Constructor()
	local button = AceGUI:Create("Icon")
	button.type = Type
	button.SetLabel = function() end
	return button
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
