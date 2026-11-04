-- Books on map (Forever): minimap button (LibDBIcon, so minimap addons such as Leatrix Plus,
-- SexyMap or button bags see it like any other)
local _, ns = ...

local NAME = "Books on map (Forever)" -- (the DataBroker object, Broker.lua)
local icon

function ns.UpdateMinimapButton()
  if not icon or not ns.db.minimapIcon then return end
  ns.db.minimapIcon.hide = ns.db.hideMinimap and true or nil
  if ns.db.hideMinimap then icon:Hide(NAME) else icon:Show(NAME) end
end

function ns.InitMinimapButton()
  icon = LibStub and LibStub("LibDBIcon-1.0", true)
  if not icon or not ns.brokerObject then return end
  local db = ns.db
  if not db.minimapIcon then
    -- (the old button's place carries over: same angle convention)
    db.minimapIcon = { minimapPos = db.minimapAngle or 200 }
    db.minimapAngle = nil
  end
  db.minimapIcon.hide = db.hideMinimap and true or nil
  icon:Register(NAME, ns.brokerObject, db.minimapIcon)
end
