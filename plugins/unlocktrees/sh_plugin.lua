local PLUGIN = PLUGIN

PLUGIN.name = "Unlock Trees"
PLUGIN.author = "Copilot"
PLUGIN.description = "A generic unlock tree framework for progressive character advancement."

-- Include shared files first (order matters: API, then tree, then node)
ix.util.Include("sh_api.lua")
ix.util.Include("sh_tree.lua")
ix.util.Include("sh_node.lua")

-- Server files
ix.util.Include("sv_storage.lua")
ix.util.Include("sv_progression.lua")
ix.util.Include("sv_editor_drafts.lua")
ix.util.Include("sv_networking.lua")

-- Client files
ix.util.Include("cl_nodepanel.lua")
ix.util.Include("cl_treepanel.lua")
ix.util.Include("cl_editor.lua")
ix.util.Include("cl_tabmenu.lua")

-- Example tree (remove this line to disable the sample)
ix.util.Include("sh_example_tree.lua")

-- Configuration
ix.config.Add("unlockTreeRespecCost", 0, "The cost in currency to respec an unlock tree. Set to 0 for free.", nil, {
	data = {min = 0, max = 100000},
	category = "Unlock Trees"
})

-- Hook: sync tree state when a character loads
function PLUGIN:PlayerLoadedCharacter(client, character)
	if (SERVER) then
		timer.Simple(1, function()
			if (!IsValid(client)) then return end

			ix.unlocks.SyncAllToClient(client)
		end)
	end
end

