PLUGIN.name        = "Imperial UI Framework"
PLUGIN.author      = "Skeleton"
PLUGIN.description = "Centralised theme, fonts, helper functions and vgui components shared across all skeleton plugins. Must load before any plugin that uses ix.ui.*"

-- The cl_ prefix means this file is only sent/executed on the client.
ix.util.Include("cl_framework.lua")
