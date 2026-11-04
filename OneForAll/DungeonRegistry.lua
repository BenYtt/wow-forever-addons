local _, FLT = ...

-- Dungeon registry. Every dungeon has its own file in Data\Dungeons\ and adds
-- itself here:
--   FLT.DUNGEON_REGISTRY["Name"] = { level=..., quests={...}, bosses={...} }
-- DungeonData.lua turns these tables into FLT.DUNGEONS once all dungeon files
-- are loaded (see the .toc order) and then frees them.
FLT.DUNGEON_REGISTRY = FLT.DUNGEON_REGISTRY or {}
