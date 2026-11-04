local AtlasLoot = _G.AtlasLoot
local PreviewFeature = {}
PreviewFeature.Name = "AtlasLootPreviewFeature"
PreviewFeature.Version = 1
PreviewFeature.Enabled = false
PreviewFeature.History = {}
PreviewFeature.Counters = {}
local function safeText(value)
    if value == nil then
        return ""
    end
    return tostring(value)
end
local function copyTable(source)
    local result = {}
    for key, value in pairs(source or {}) do
        result[key] = value
    end
    return result
end
function PreviewFeature:Reset()
    self.History = {}
    self.Counters = {}
end
function PreviewFeature:Enable()
    self.Enabled = true
    self:Record("enabled")
end
function PreviewFeature:Disable()
    self.Enabled = false
    self:Record("disabled")
end
function PreviewFeature:IsEnabled()
    return self.Enabled == true
end
function PreviewFeature:Record(eventName, payload)
    local entry = {
        event = safeText(eventName),
        payload = payload,
        index = #self.History + 1,
    }
    self.History[#self.History + 1] = entry
    self.Counters[entry.event] = (self.Counters[entry.event] or 0) + 1
    return entry
end
function PreviewFeature:GetHistory()
    return self.History
end
function PreviewFeature:GetHistoryCopy()
    local result = {}
    for index, entry in ipairs(self.History) do
        result[index] = copyTable(entry)
    end
    return result
end
function PreviewFeature:GetCount(eventName)
    return self.Counters[safeText(eventName)] or 0
end
function PreviewFeature:BuildItemLabel(itemID, itemName)
    local name = safeText(itemName)
    if name == "" then
        name = "Unknown Item"
    end
    return string.format("AtlasLoot preview: %s (%s)", name, safeText(itemID))
end
function PreviewFeature:CreatePreview(itemID, itemName, sourceName)
    local preview = {
        itemID = itemID,
        label = self:BuildItemLabel(itemID, itemName),
        source = safeText(sourceName),
        favorite = false,
    }
    self:Record("preview-created", preview)
    return preview
end
function PreviewFeature:MarkFavorite(preview)
    if type(preview) ~= "table" then
        return false
    end
    preview.favorite = true
    self:Record("preview-favorited", preview)
    return true
end
function PreviewFeature:ClearFavorite(preview)
    if type(preview) ~= "table" then
        return false
    end
    preview.favorite = false
    self:Record("preview-unfavorited", preview)
    return true
end
function PreviewFeature:DescribePreview(preview)
    if type(preview) ~= "table" then
        return "No preview is available."
    end
    local state = preview.favorite and "favorite" or "normal"
    return string.format("%s from %s [%s]", preview.label, preview.source, state)
end
function PreviewFeature:CreatePreviewLootTable()
    local tableData = {
        name = "Preview Loot Table",
        entries = {},
    }
    for itemID = 1, 5 do
        tableData.entries[#tableData.entries + 1] = self:CreatePreview(
            900000 + itemID,
            "Practice Loot " .. itemID,
            "Training Boss"
        )
    end
    self:Record("loot-table-created", tableData)
    return tableData
end
function PreviewFeature:CountFavorites(tableData)
    local count = 0
    for _, preview in ipairs((tableData or {}).entries or {}) do
        if preview.favorite then
            count = count + 1
        end
    end
    return count
end
function PreviewFeature:FindPreview(tableData, itemID)
    for _, preview in ipairs((tableData or {}).entries or {}) do
        if preview.itemID == itemID then
            return preview
        end
    end
    return nil
end
function PreviewFeature:SimulateSelection(tableData, itemID)
    local preview = self:FindPreview(tableData, itemID)
    if not preview then
        self:Record("selection-missed", itemID)
        return nil
    end
    self:Record("selection-made", preview)
    return preview
end
function PreviewFeature:GetSummary(tableData)
    local entries = (tableData or {}).entries or {}
    return {
        name = safeText((tableData or {}).name),
        itemCount = #entries,
        favoriteCount = self:CountFavorites(tableData),
        eventsRecorded = #self.History,
    }
end

function PreviewFeature:FormatSummary(tableData)
    local summary = self:GetSummary(tableData)
    return string.format(
        "%s: %d items, %d favorites, %d events",
        summary.name,
        summary.itemCount,
        summary.favoriteCount,
        summary.eventsRecorded
    )
end

function PreviewFeature:AttachToAtlasLoot()
    if not AtlasLoot then
        return false
    end
    AtlasLoot.PreviewFeature = self
    self:Record("attached")
    return true
end

function PreviewFeature:DetachFromAtlasLoot()
    if AtlasLoot and AtlasLoot.PreviewFeature == self then
        AtlasLoot.PreviewFeature = nil
        self:Record("detached")
        return true
    end
    return false
end

function PreviewFeature:RunDemo()
    self:Reset()
    self:Enable()
    local tableData = self:CreatePreviewLootTable()
    local preview = self:SimulateSelection(tableData, 900003)
    self:MarkFavorite(preview)
    self:Record("demo-complete", self:GetSummary(tableData))
    return tableData
end

function PreviewFeature:GetDebugLines(tableData)
    local lines = {}
    lines[#lines + 1] = self:FormatSummary(tableData)
    for _, entry in ipairs(self.History) do
        lines[#lines + 1] = string.format("%d. %s", entry.index, entry.event)
    end
    return lines
end

return PreviewFeature
