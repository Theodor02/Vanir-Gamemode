-- cl_tabmenu.lua
-- Integrates unlock trees into the Helix tab menu as sub-tabs under the "You" tab.
-- Trees with showInTabMenu = true appear as section buttons (like "plugins" under "config").
-- If the player has no accessible trees, no extra buttons appear.

hook.Add("CreateMenuButtons", "ixUnlockTreesTabMenu", function(tabs)
	-- Wait for the "you" tab to be registered by the framework
	if (!tabs["you"]) then return end

	local client = LocalPlayer()
	local tabTrees = ix.unlocks.GetTabMenuTrees(client)

	-- Nothing to show — leave the "you" tab unmodified
	if (#tabTrees == 0) then return end

	-- impmainmenu registers tabs["you"] as a plain function, but Sections
	-- only work on table entries. Convert to a table if needed.
	-- Note: table Create is called as info:Create(subpanel) (colon syntax),
	-- so we wrap the original function to forward the correct argument.
	if (isfunction(tabs["you"])) then
		local originalCreate = tabs["you"]

		tabs["you"] = {
			Create = function(info, container)
				originalCreate(container)
			end,
			Sections = {}
		}
	elseif (!tabs["you"].Sections) then
		tabs["you"].Sections = {}
	end

	-- Add a section for each visible tree
	for _, treeID in ipairs(tabTrees) do
		local tree = ix.unlocks.GetTree(treeID)

		if (tree) then
			tabs["you"].Sections[tree.name] = {
				Create = function(info, container)
					-- Embed the full tree panel (toolbar, canvas, footer) without tree switching
					container.treeEmbed = container:Add("ixUnlockTreeTabEmbed")
					container.treeEmbed:Dock(FILL)
					container.treeEmbed:SetTreeID(treeID)

					timer.Simple(0, function()
						if (IsValid(container.treeEmbed)) then
							container.treeEmbed:CenterOnTree()
						end
					end)
				end,

				OnSelected = function(info, container)
					if (IsValid(container.treeEmbed)) then
						container.treeEmbed:CenterOnTree()
					end
				end
			}
		end
	end
end)
