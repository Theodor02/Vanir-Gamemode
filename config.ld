file = {
	"gamemode",
	"plugins",
	"schema"
}

module_file = {
	Character = "gamemode/core/meta/sh_character.lua",
	Entity = "gamemode/core/meta/sh_entity.lua",
	Inventory = "gamemode/core/meta/sh_inventory.lua",
	Item = "gamemode/core/meta/sh_item.lua",
	Player = "gamemode/core/meta/sh_player.lua",
	Plugin = "gamemode/core/meta/sh_plugin.lua"
}

dir = "docs/html"
project = "Skeleton"
title = "Skeleton Documentation"

no_space_before_args = true
style = "../../helix/docs/css"
template = "../../helix/docs/templates"
format = "markdown"
ignore = true
use_markdown_titles = true
kind_names = {module = "Libraries", topic = "Manual"}
merge = true
sort = true
sort_modules = true

simple_args_string = true
strip_metamethod_prefix = true
no_viewed_topic_at_top = true
use_new_templates = true
pretty_urls = true
pretty_topic_names = true

custom_tags = {
	{"realm", hidden = true},
	{"internal", hidden = true}
}

custom_display_name_handler = function(item, default_handler)
	if (item.type == "function" and item.module) then
		if (item.module.type == "classmod" or item.module.type == "panel") then
			return item.module.mod_name .. ":" .. default_handler(item)
		elseif (item.module.type == "hooks") then
			return item.module.mod_name:upper() .. ":" .. default_handler(item)
		end
	end
	return default_handler(item)
end
