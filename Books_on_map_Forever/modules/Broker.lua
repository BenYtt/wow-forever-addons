-- Books on map (Forever): DataBroker launcher (Titan Panel, ChocolateBar, ElvUI, Bazooka...)
local _, ns = ...
local L = ns.L

local obj

function ns.RefreshBroker()
  if obj then obj.text = ("%d/%d"):format(ns.CountDone(), #ns.BOOKS) end
end

function ns.InitBroker()
  local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
  if not ldb then return end
  obj = ldb:NewDataObject("Books on map (Forever)", {
    type = "data source",
    label = "Books",
    icon = ns.ADDON_ICON,
    OnClick = function(_, button)
      if button == "RightButton" then
        ns.db.hidden = not ns.db.hidden
        ns.Refresh()
      else
        ns.ToggleOptions()
      end
    end,
    OnTooltipShow = function(tt)
      tt:AddLine("Books on map (Forever)")
      tt:AddLine(L["Collected: %d/%d"]:format(ns.CountDone(), #ns.BOOKS), 1, 1, 1)
      local nearest = ns.NearestText()
      if nearest then tt:AddDoubleLine(L["Nearest:"], nearest, 0.36, 0.78, 1, 1, 1, 1) end
      ns.AddGroupProgressTooltip(tt)
      tt:AddLine(L["Left-click: open book list"], 0.5, 1, 0.5)
      tt:AddLine(L["Right-click: toggle map icons"], 0.5, 1, 0.5)
    end,
  })
  ns.brokerObject = obj -- (the minimap button, Minimap.lua)
  ns.RefreshBroker()
end
