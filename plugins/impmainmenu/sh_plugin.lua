PLUGIN.name = "Improved Main Menu"
PLUGIN.author = "Copilot"
PLUGIN.description = "Replaces the Skeleton main menu with a custom layout." 

ix.util.Include("cl_menu.lua")
ix.util.Include("cl_charcreate.lua")
ix.util.Include("cl_charload.lua")
ix.util.Include("derma/cl_menu.lua")
ix.util.Include("derma/cl_menubutton.lua")
ix.util.Include("derma/cl_inventory.lua")
ix.util.Include("derma/cl_information.lua")
ix.util.Include("derma/cl_business.lua")
ix.util.Include("derma/cl_classes.lua")
ix.util.Include("derma/cl_help.lua")
ix.util.Include("derma/cl_settings.lua")
ix.util.Include("derma/cl_scoreboard.lua")
ix.util.Include("cl_tooltip.lua")

-- Unified character + inventory panel
ix.util.Include("vgui/cl_dynamic_sections.lua")
ix.util.Include("vgui/cl_stats_panel.lua")
ix.util.Include("vgui/cl_attribute_renderer.lua")
ix.util.Include("vgui/cl_character_model.lua")
ix.util.Include("vgui/cl_inventory_grid.lua")
ix.util.Include("vgui/cl_unified_panel.lua")