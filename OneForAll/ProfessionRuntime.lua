local _, FLT = ...

-- Standalone profession resolver backed by the embedded WoW Forever data in
-- ProfessionData.lua. No external addon is required at runtime.

local function getEmbedded(recipe)
  if not recipe or not recipe.profession or not recipe.name then return nil end
  local byProfession = FLT.PROFESSION_DATA and FLT.PROFESSION_DATA[recipe.profession]
  return byProfession and byProfession[recipe.name] or nil
end

function FLT:GetRecipeItemID(recipe)
  local data = getEmbedded(recipe)
  return data and data.recipeItemID or nil
end

local function copyTable(src)
  if type(src) ~= "table" then return nil end
  local out = {}
  for k,v in pairs(src) do out[k] = v end
  return out
end

function FLT:GetOfflineProfessionResult(recipe)
  local data = getEmbedded(recipe)
  if data then
    local out = copyTable(data)
    -- Keep curated descriptions where they are more detailed than the compact
    -- authoritative label from the profession data set.
    local curated = self.PROFESSION_RESULT_INFO and self.PROFESSION_RESULT_INFO[recipe.name]
    if curated and curated.effect and curated.effect ~= "" then
      out.effect = curated.effect
    end
    if out.craftedItemID and self.RequestRecipeItemData then
      self:RequestRecipeItemData(out.craftedItemID)
    end
    if out.recipeItemID and self.RequestRecipeItemData then
      self:RequestRecipeItemData(out.recipeItemID)
    end
    return out
  end
  return nil
end

function FLT:GetProfessionResolutionCount()
  local total, resolved = 0, 0
  for _,recipe in ipairs(self.MERCHANT_RECIPES or {}) do
    total = total + 1
    if getEmbedded(recipe) then resolved = resolved + 1 end
  end
  return resolved, total
end
