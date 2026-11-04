-- Modified for ForeverAuras, 2026-09-18.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

--- @type table<auraId, auraId>
local attachedToTarget = {}
--- @type table<auraId, table<auraId, boolean>>
local targetToAttached = {}

-- Handles


--- @type fun(_: any, uid: uid, id: auraId)
local function OnDelete(_, uid, id)
  local target = attachedToTarget[id]
  if target then
    if targetToAttached[target] then
      targetToAttached[target][id] = nil
    end
    attachedToTarget[id] = nil
  end
end

--- @type fun(_: any, uid: uid, oldId: auraId, newId: auraId)
local function OnRename(_, uid, oldId, newId)

  local target = attachedToTarget[oldId]
  if target then
    -- renamed aura is an attached aura
    attachedToTarget[newId] = attachedToTarget[oldId]
    attachedToTarget[oldId] = nil

    targetToAttached[target][oldId] = nil
    targetToAttached[target][newId] = true
  end

  -- renamed aura is a targeted aura
  if targetToAttached[oldId] then
    for attached in pairs(targetToAttached[oldId]) do
      local data = WeakAuras.GetData(attached)
      if data then
        -- Keep the spelling the author used.
        local prefix = data.anchorFrameFrame:sub(1, 13) == "ForeverAuras:" and "ForeverAuras:" or "WeakAuras:"
        data.anchorFrameFrame = prefix .. newId
        WeakAuras.Add(data, true)
      end

      attachedToTarget[attached] = newId
    end
    targetToAttached[newId] = targetToAttached[oldId]
    targetToAttached[oldId] = nil
  end

end

--- @type fun(_: any, uid: uid, id: auraId, data: auraData, simpleChange: boolean)
local function OnAdd(_, uid, id, data, simpleChange)
  if simpleChange then
    return
  end
  OnDelete(nil, uid, id)
  local target = data.anchorFrameType == "SELECTFRAME" and Private.AuraFrameTarget(data.anchorFrameFrame)
  if target then
    attachedToTarget[data.id] = target
    targetToAttached[target] = targetToAttached[target] or {}
    targetToAttached[target][data.id] = true
  end
end

-- Re-anchors every aura anchored to the target aura, for when the frame that
-- stands for the target changes (SecretAuraStand.lua: a display drawn by a
-- stand-in inside a Modern Aura Group).
function Private.ReanchorAttachedTo(target)
  local attached = targetToAttached[target]
  if not attached then return end
  for id in pairs(attached) do
    local data = WeakAuras.GetData(id)
    local entry = Private.regions[id]
    if data and entry and entry.region then
      local parentEntry = data.parent and Private.regions[data.parent]
      Private.AnchorFrame(data, entry.region, parentEntry and parentEntry.region or nil)
    end
  end
end

Private.callbacks:RegisterCallback("Delete", OnDelete)
Private.callbacks:RegisterCallback("Rename", OnRename)
Private.callbacks:RegisterCallback("Add", OnAdd)
