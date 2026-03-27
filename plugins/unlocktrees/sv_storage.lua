-- sv_storage.lua
-- Persistence is handled through Helix character data (character:GetData / character:SetData).
-- The "ixUnlockTrees" key stores all progression per character and is automatically saved to
-- the database when the character is saved.
--
-- This file exists for lifecycle hooks that manage data on character events.

local PLUGIN = PLUGIN

--- When a character is first created, initialise empty unlock data.
function PLUGIN:OnCharacterCreated(client, character)
	character:SetData("ixUnlockTrees", {})
	character:SetData("ixUnlockCooldowns", {})
	character:SetData("ixUnlockLog", {})
end
