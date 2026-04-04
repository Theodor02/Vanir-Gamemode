
local PLUGIN = PLUGIN

PLUGIN.name = "Ambient Music"
PLUGIN.description = "Adds a system to play and configure ambient music on the client side."
PLUGIN.author = "bruck"
PLUGIN.license = [[
Copyright 2025 bruck
This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
]]

ix.util.IncludeDir(PLUGIN.folder .. "/hooks", true)
ix.util.IncludeDir(PLUGIN.folder .. "/meta", true)
ix.util.Include("sh_config.lua")

if SERVER then
    ix.util.Include(PLUGIN.folder .. "/libs/sv_music.lua")
end

if CLIENT then
    ix.util.Include(PLUGIN.folder .. "/libs/cl_music.lua")
    ix.util.IncludeDir(PLUGIN.folder .. "/derma", false)
end

ix.util.IncludeDir(PLUGIN.folder .. "/commands", true)

-- do NOT include the 'sound/' prefix in your file names for the track list
-- Individual tracks outside any playlist go here; they play in the "ambient" circumstance.
PLUGIN.ambientTracks = {
    { path = "swtor-class_low_ambient_republic/class_justice_the_jedi_knight_jedi_order_[class_low_ambient_republic].mp3", theme = "ambient", title = "Justice The Jedi Knight Jedi Order" },
    { path = "swtor-planet_low_ambient_republic/planet_tython_default_x11_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Tython Default (X11)" },
    { path = "swtor-planet_low_ambient_republic/planet_belsavis_the_scar_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Belsavis The Scar" },
    { path = "swtor-planet_low_ambient_republic/planet_corellia_government_district_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Corellia Government District" },
    { path = "swtor-planet_low_ambient_republic/planet_belsavis_the_tomb_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Belsavis The Tomb" },
    { path = "swtor-planet_low_ambient_republic/planet_corellia_blastfield_shipyards_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Corellia Blastfield Shipyards" },
    { path = "swtor-planet_low_ambient_republic/planet_hoth_default_x3_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Hoth Default (X3)" },
    { path = "swtor-planet_low_ambient_republic/planet_belsavis_rakatan_prison_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Belsavis Rakatan Prison" },
    { path = "swtor-planet_low_ambient_republic/planet_belsavis_esh_kha_escape_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Belsavis Esh Kha Escape" },
    { path = "swtor-planet_low_ambient_republic/planet_corellia_axial_park_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Corellia Axial Park" },
    { path = "swtor-planet_low_ambient_republic/planet_tython_default_x5_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Tython Default (X5)" },
    { path = "swtor-planet_low_ambient_republic/staunch_collection_unreleased_belsavis_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Staunch Collection Unreleased Belsavis" },
    { path = "swtor-planet_low_ambient_republic/planet_taris_default_x5_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Taris Default (X5)" },
    { path = "swtor-planet_low_ambient_republic/planet_tython_default_x3_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Tython Default (X3)" },
    { path = "swtor-planet_low_ambient_republic/planet_taris_aftermath_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Taris Aftermath" },
    { path = "swtor-planet_low_ambient_republic/planet_tython_default_x4_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Tython Default (X4)" },
    { path = "swtor-planet_low_ambient_republic/planet_taris_default_x4_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Taris Default (X4)" },
    { path = "swtor-planet_low_ambient_republic/planet_taris_default_x2_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Taris Default (X2)" },
    { path = "swtor-planet_low_ambient_republic/planet_corellia_labor_valley_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Corellia Labor Valley" },
    { path = "swtor-planet_low_ambient_republic/planet_taris_default_x3_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Taris Default (X3)" },
    { path = "swtor-planet_low_ambient_republic/planet_hoth_default_x2_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Hoth Default (X2)" },
    { path = "swtor-planet_low_ambient_republic/planet_hoth_default_x1_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Hoth Default (X1)" },
    { path = "swtor-planet_low_ambient_republic/planet_taris_default_x1_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Taris Default (X1)" },
    { path = "swtor-planet_low_ambient_republic/planet_corellia_coronet_city_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Corellia Coronet City" },
    { path = "swtor-planet_low_ambient_republic/planet_corellia_incorporation_islands_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Corellia Incorporation Islands" },
    { path = "swtor-planet_low_ambient_republic/planet_tython_default_x2_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Tython Default (X2)" },
    { path = "swtor-planet_low_ambient_republic_2/planet_alderaan_organa_castle_[planet_low_ambient_republic_2].mp3", theme = "ambient", title = "Alderaan Organa Castle" },
    { path = "swtor-planet_low_ambient_republic_2/planet_alderaan_sunny_vale_[planet_low_ambient_republic_2].mp3", theme = "ambient", title = "Alderaan Sunny Vale" },
    { path = "swtor-planet_low_ambient_republic_2/planet_alderaan_royal_family_[planet_low_ambient_republic_2].mp3", theme = "ambient", title = "Alderaan Royal Family" },
    { path = "swtor-planet_low_ambient_republic_2/planet_balmorra_distant_horizon_[planet_low_ambient_republic_2].mp3", theme = "ambient", title = "Balmorra Distant Horizon" },
    { path = "swtor-planet_low_ambient_republic_2/planet_balmorra_default_[planet_low_ambient_republic_2].mp3", theme = "ambient", title = "Balmorra Default" },
    { path = "swtor-planet_low_ambient_republic_2/planet_alderaan_peaceful_valley_[planet_low_ambient_republic_2].mp3", theme = "ambient", title = "Alderaan Peaceful Valley" },
    { path = "swtor-planet_low_ambient_republic_2/planet_balmorra_lost_[planet_low_ambient_republic_2].mp3", theme = "ambient", title = "Balmorra Lost" },
    { path = "swtor-planet_low_ambient_republic_2/planet_balmorra_markaran_plains_[planet_low_ambient_republic_2].mp3", theme = "ambient", title = "Balmorra Markaran Plains" },
    { path = "swtor-planet_low_ambient_republic_2/planet_balmorra_bugtown_[planet_low_ambient_republic_2].mp3", theme = "ambient", title = "Balmorra Bugtown" },
    { path = "swtor-planet_low_ambient_republic_2/planet_alderaan_grasslands_[planet_low_ambient_republic_2].mp3", theme = "ambient", title = "Alderaan Grasslands" },
    { path = "swtor-planet_low_ambient_republic_2/staunch_collection_unreleased_balmorra_[planet_low_ambient_republic_2].mp3", theme = "ambient", title = "Staunch Collection Unreleased Balmorra" },
    { path = "swtor-planet_low_ambient_republic_2/staunch_collection_unreleased_alderaan_[planet_low_ambient_republic_2].mp3", theme = "ambient", title = "Staunch Collection Unreleased Alderaan" },
    { path = "swtor-planet_low_ambient_republic_3/planet_voss_default_x2_[planet_low_ambient_republic_3].mp3", theme = "ambient", title = "Voss Default (X2)" },
    { path = "swtor-planet_low_ambient_republic_3/planet_voss_calm_x2_[planet_low_ambient_republic_3].mp3", theme = "ambient", title = "Voss Calm (X2)" },
    { path = "swtor-planet_low_ambient_republic_3/planet_voss_default_x1_[planet_low_ambient_republic_3].mp3", theme = "ambient", title = "Voss Default (X1)" },
    { path = "swtor-planet_low_ambient_republic_3/staunch_collection_unreleased_voss_[planet_low_ambient_republic_3].mp3", theme = "ambient", title = "Staunch Collection Unreleased Voss" },
    { path = "swtor-planet_low_ambient_republic_4/planet_nal_hutta_default_x2_[planet_low_ambient_republic_4].mp3", theme = "ambient", title = "Nal Hutta Default (X2)" },
    { path = "swtor-planet_low_ambient_republic_4/planet_nal_hutta_default_x1_[planet_low_ambient_republic_4].mp3", theme = "ambient", title = "Nal Hutta Default (X1)" },
    { path = "swtor-planet_low_ambient_republic_4/planet_nal_hutta_main_[planet_low_ambient_republic_4].mp3", theme = "ambient", title = "Nal Hutta Main" },
    { path = "swtor-planet_low_ambient_republic_4/planet_nal_hutta_main_no_chorus_[planet_low_ambient_republic_4].mp3", theme = "ambient", title = "Nal Hutta Main No Chorus" },
    { path = "swtor-planet_low_ambient_republic_4/staunch_collection_unreleased_nal_hutta_[planet_low_ambient_republic_4].mp3", theme = "ambient", title = "Staunch Collection Unreleased Nal Hutta" },
    { path = "swtor-planet_low_ambient_republic_4/planet_tython_default_x1_[planet_low_ambient_republic_4].mp3", theme = "ambient", title = "Tython Default (X1)" },
    { path = "swtor-planet_low_ambient_republic_4/staunch_collection_unreleased_makeb_[planet_low_ambient_republic_4].mp3", theme = "ambient", title = "Staunch Collection Unreleased Makeb" },
    { path = "swtor-planet_low_ambient_republic_4/staunch_collection_unreleased_ord_mantell_[planet_low_ambient_republic_4].mp3", theme = "ambient", title = "Staunch Collection Unreleased Ord Mantell" },
    { path = "swtor-planet_low_ambient_republic_4/staunch_collection_unreleased_makeb_the_impending_calamity_[planet_low_ambient_republic_4].mp3", theme = "ambient", title = "Staunch Collection Unreleased Makeb The Impending Calamity" },
    { path = "swtor-planet_low_ambient_republic_5/planet_nar_shaddaa_default_x3_[planet_low_ambient_republic_5].mp3", theme = "ambient", title = "Nar Shaddaa Default (X3)" },
    { path = "swtor-planet_low_ambient_republic_5/planet_nar_shaddaa_default_x2_[planet_low_ambient_republic_5].mp3", theme = "ambient", title = "Nar Shaddaa Default (X2)" },
    { path = "swtor-planet_low_ambient_republic_5/planet_tatooine_default_x2_[planet_low_ambient_republic_5].mp3", theme = "ambient", title = "Tatooine Default (X2)" },
    { path = "swtor-planet_low_ambient_republic_5/planet_nar_shaddaa_default_x1_[planet_low_ambient_republic_5].mp3", theme = "ambient", title = "Nar Shaddaa Default (X1)" },
    { path = "swtor-planet_low_ambient_republic_5/planet_tatooine_default_x1_[planet_low_ambient_republic_5].mp3", theme = "ambient", title = "Tatooine Default (X1)" },
    { path = "swtor-planet_low_ambient_republic_5/staunch_collection_unreleased_nar_shaddaa_[planet_low_ambient_republic_5].mp3", theme = "ambient", title = "Staunch Collection Unreleased Nar Shaddaa" },
    { path = "swtor-expansion_low_ambient_republic/expansion_5_kotfe_vaylin_the_right_hand_x2_[expansion_low_ambient_republic].mp3", theme = "ambient", title = "KotFE Vaylin The Right Hand (X2)" },
    { path = "swtor-expansion_low_ambient_republic/expansion_7_8_onslaught_lots_track_x41_[expansion_low_ambient_republic].mp3", theme = "ambient", title = "8 Onslaught Lots Track (X41)" },
    { path = "swtor-expansion_low_ambient_republic/expansion_7_8_onslaught_lots_track_x9_[expansion_low_ambient_republic].mp3", theme = "ambient", title = "8 Onslaught Lots Track (X9)" },
    { path = "swtor-expansion_low_ambient_republic_3/expansion_6_kotet_echoes_background_x14_[expansion_low_ambient_republic_3].mp3", theme = "ambient", title = "KotET Echoes Background (X14)" },
    { path = "swtor-expansion_low_ambient_republic_3/expansion_6_kotet_echoes_background_x6_[expansion_low_ambient_republic_3].mp3", theme = "ambient", title = "KotET Echoes Background (X6)" },
    { path = "swtor-expansion_low_ambient_republic_3/expansion_6_kotet_echoes_background_x5_[expansion_low_ambient_republic_3].mp3", theme = "ambient", title = "KotET Echoes Background (X5)" },
    { path = "swtor-expansion_low_ambient_republic_3/expansion_6_kotet_echoes_background_x15_[expansion_low_ambient_republic_3].mp3", theme = "ambient", title = "KotET Echoes Background (X15)" },
    { path = "swtor-expansion_low_ambient_republic_3/expansion_6_kotet_echoes_background_x4_[expansion_low_ambient_republic_3].mp3", theme = "ambient", title = "KotET Echoes Background (X4)" },
    { path = "swtor-expansion_low_ambient_republic_3/expansion_6_kotet_echoes_background_x17_[expansion_low_ambient_republic_3].mp3", theme = "ambient", title = "KotET Echoes Background (X17)" },
    { path = "swtor-expansion_low_ambient_republic_3/expansion_6_kotet_echoes_background_x16_[expansion_low_ambient_republic_3].mp3", theme = "ambient", title = "KotET Echoes Background (X16)" },
    { path = "swtor-expansion_low_ambient_republic_3/expansion_6_kotet_echoes_background_x3_[expansion_low_ambient_republic_3].mp3", theme = "ambient", title = "KotET Echoes Background (X3)" },
    { path = "swtor-expansion_low_ambient_republic_3/expansion_6_kotet_echoes_background_x13_[expansion_low_ambient_republic_3].mp3", theme = "ambient", title = "KotET Echoes Background (X13)" },
    { path = "swtor-expansion_low_ambient_republic_3/expansion_6_kotet_echoes_background_x9_[expansion_low_ambient_republic_3].mp3", theme = "ambient", title = "KotET Echoes Background (X9)" },
    { path = "swtor-expansion_low_ambient_republic_3/expansion_6_kotet_echoes_background_x18_[expansion_low_ambient_republic_3].mp3", theme = "ambient", title = "KotET Echoes Background (X18)" },
    { path = "swtor-expansion_low_ambient_republic_3/expansion_6_kotet_echoes_background_x1_[expansion_low_ambient_republic_3].mp3", theme = "ambient", title = "KotET Echoes Background (X1)" },
    { path = "swtor-official_low_ambient_republic/official_57_the_end_in_the_stars_[official_low_ambient_republic].mp3", theme = "ambient", title = "The End In The Stars" },
    { path = "swtor-official_low_ambient_republic/official_64_my_jeeska_choy_myo_naga_[official_low_ambient_republic].mp3", theme = "ambient", title = "My Jeeska Choy Myo Naga" },
    { path = "swtor-official_low_ambient_republic/official_65_potaggas_pagonas_um_potas_[official_low_ambient_republic].mp3", theme = "ambient", title = "Potaggas Pagonas Um Potas" },
    { path = "swtor-official_low_ambient_republic/official_90_ruhnuk_[official_low_ambient_republic].mp3", theme = "ambient", title = "Ruhnuk" },
    { path = "swtor-official_low_ambient_republic/official_93_siblings_[official_low_ambient_republic].mp3", theme = "ambient", title = "Siblings" },
    { path = "swtor-official_low_ambient_republic/official_87_the_padawan_[official_low_ambient_republic].mp3", theme = "ambient", title = "The Padawan" },
    { path = "swtor-official_low_ambient_republic/official_84_this_is_only_the_beginning_[official_low_ambient_republic].mp3", theme = "ambient", title = "This Is Only The Beginning" },
    { path = "swtor-official_low_ambient_republic/official_83_temple_ruins_[official_low_ambient_republic].mp3", theme = "ambient", title = "Temple Ruins" },
    { path = "swtor-official_low_ambient_republic/official_60_mek_sha_the_waypoint_[official_low_ambient_republic].mp3", theme = "ambient", title = "Mek Sha The Waypoint" },
    { path = "swtor-official_low_ambient_republic/official_66_splinter_of_the_minds_eye_[official_low_ambient_republic].mp3", theme = "ambient", title = "Splinter Of The Minds Eye" },
    { path = "swtor-official_low_ambient_republic/official_59_onderon_the_lush_overgrowth_[official_low_ambient_republic].mp3", theme = "ambient", title = "Onderon The Lush Overgrowth" },
    { path = "swtor-official_low_ambient_republic/official_62_unyielding_grudges_[official_low_ambient_republic].mp3", theme = "ambient", title = "Unyielding Grudges" },
    { path = "swtor-official_low_ambient_republic/official_12_the_mandalorian_blockade_[official_low_ambient_republic].mp3", theme = "ambient", title = "The Mandalorian Blockade" },
    { path = "swtor-official_low_ambient_republic/official_63_the_lost_library_[official_low_ambient_republic].mp3", theme = "ambient", title = "The Lost Library" },
    { path = "swtor-official_low_ambient_republic/official_28_voss_the_mystic_garden_[official_low_ambient_republic].mp3", theme = "ambient", title = "Voss The Mystic Garden" },
    { path = "swtor-official_low_ambient_republic/official_21_tatooine_the_desert_sands_[official_low_ambient_republic].mp3", theme = "ambient", title = "Tatooine The Desert Sands" },
    { path = "swtor-official_low_ambient_republic/official_47_the_blood_of_kings_[official_low_ambient_republic].mp3", theme = "ambient", title = "The Blood Of Kings" },
    { path = "swtor-official_low_ambient_republic/official_55_the_twisted_empress_[official_low_ambient_republic].mp3", theme = "ambient", title = "The Twisted Empress" },
    { path = "swtor-official_low_ambient_republic/official_36_the_shadow_of_revan_[official_low_ambient_republic].mp3", theme = "ambient", title = "The Shadow Of Revan" },
    { path = "swtor-official_low_ambient_republic/official_15_nal_hutta_the_glorious_jewel_[official_low_ambient_republic].mp3", theme = "ambient", title = "Nal Hutta The Glorious Jewel" },
    { path = "swtor-official_low_ambient_republic/official_20_nar_shaddaa_the_playground_[official_low_ambient_republic].mp3", theme = "ambient", title = "Nar Shaddaa The Playground" },
    { path = "swtor-official_low_ambient_republic/official_51_the_burning_star_[official_low_ambient_republic].mp3", theme = "ambient", title = "The Burning Star" },
    { path = "swtor-official_low_ambient_republic/official_50_an_empress_in_the_jungle_[official_low_ambient_republic].mp3", theme = "ambient", title = "An Empress In The Jungle" },
    { path = "swtor-official_low_ambient_republic/official_19_balmorra_the_forge_[official_low_ambient_republic].mp3", theme = "ambient", title = "Balmorra The Forge" },
    { path = "swtor-official_low_ambient_republic/official_27_belsavis_the_ancient_prison_[official_low_ambient_republic].mp3", theme = "ambient", title = "Belsavis The Ancient Prison" },
    { path = "swtor-official_low_ambient_republic/official_45_odessen_the_distantwood_[official_low_ambient_republic].mp3", theme = "ambient", title = "Odessen The Distantwood" },
    { path = "swtor-official_low_ambient_republic/official_40_arcann_the_inner_flame_[official_low_ambient_republic].mp3", theme = "ambient", title = "Arcann The Inner Flame" },
    { path = "swtor-official_low_ambient_republic/official_42_vaylin_the_right_hand_[official_low_ambient_republic].mp3", theme = "ambient", title = "Vaylin The Right Hand" },
    { path = "swtor-cantina_playful_social_republic/cantina_in_the_escape_pod_[cantina_playful_social_republic].mp3", theme = "ambient", title = "In The Escape Pod" },
}

local SWTOR_CLASS_LOW = "swtor-class_low_ambient_republic/"
local SWTOR_PLANET_LOW = "swtor-planet_low_ambient_republic/"
local SWTOR_EXP_LOW = "swtor-expansion_low_ambient_republic/"
local SWTOR_EXP_LOW_2 = "swtor-expansion_low_ambient_republic_2/"
local SWTOR_EXP_LOW_3 = "swtor-expansion_low_ambient_republic_3/"
local SWTOR_EXP_LOW_4 = "swtor-expansion_low_ambient_republic_4/"
local SWTOR_OFFICIAL_LOW = "swtor-official_low_ambient_republic/"
local SWTOR_CANTINA = "swtor-cantina_playful_social_republic/"

local KOTOR_PLAYLISTS = {
    ["swtor_classes_ambient"] = {
        name = "SWTOR Classes - Ambient",
        mode = "ambient",
        tracks = {
            { path = SWTOR_CLASS_LOW .. "class_peace_the_jedi_consular_calm_[class_low_ambient_republic].mp3", theme = "ambient", title = "Peace, The Jedi Consular (Calm)" },
            { path = SWTOR_CLASS_LOW .. "class_peace_the_jedi_consular_jedi_order_x1_[class_low_ambient_republic].mp3", theme = "ambient", title = "Peace, The Jedi Consular (Jedi Order x1)" },
            { path = SWTOR_CLASS_LOW .. "class_peace_the_jedi_consular_jedi_order_x2_[class_low_ambient_republic].mp3", theme = "ambient", title = "Peace, The Jedi Consular (Jedi Order x2)" },
            { path = SWTOR_CLASS_LOW .. "class_justice_the_jedi_knight_main_[class_low_ambient_republic].mp3", theme = "ambient", title = "Justice, The Jedi Knight (Main)" },
            { path = SWTOR_CLASS_LOW .. "class_justice_the_jedi_knight_jedi_temple_[class_low_ambient_republic].mp3", theme = "ambient", title = "Justice, The Jedi Knight (Jedi Temple)" },
            { path = SWTOR_CLASS_LOW .. "class_hope_the_republic_trooper_calm_[class_low_ambient_republic].mp3", theme = "ambient", title = "Hope, The Republic Trooper (Calm)" },
            { path = SWTOR_CLASS_LOW .. "class_bravado_the_smuggler_calm_[class_low_ambient_republic].mp3", theme = "ambient", title = "Bravado, The Smuggler (Calm)" },
            { path = SWTOR_CLASS_LOW .. "class_scum_the_bounty_hunter_calm_[class_low_ambient_republic].mp3", theme = "ambient", title = "Scum, The Bounty Hunter (Calm)" },
        },
    },

    ["swtor_worlds_ambient"] = {
        name = "SWTOR Worlds - Ambient",
        mode = "ambient",
        tracks = {
            { path = SWTOR_PLANET_LOW .. "planet_tython_main_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Tython (Main)" },
            { path = SWTOR_PLANET_LOW .. "planet_tython_calm_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Tython (Calm)" },
            { path = SWTOR_PLANET_LOW .. "planet_taris_main_kotor_taris_sewers_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Taris: KOTOR Taris Sewers" },
            { path = SWTOR_PLANET_LOW .. "planet_taris_calm_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Taris (Calm)" },
            { path = SWTOR_PLANET_LOW .. "planet_hoth_main_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Hoth (Main)" },
            { path = SWTOR_PLANET_LOW .. "planet_hoth_calm_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Hoth (Calm)" },
            { path = SWTOR_PLANET_LOW .. "planet_corellia_calm_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Corellia (Calm)" },
            { path = SWTOR_PLANET_LOW .. "planet_corellia_coronet_city_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Corellia: Coronet City" },
            { path = SWTOR_PLANET_LOW .. "planet_corellia_government_district_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Corellia: Government District" },
            { path = SWTOR_PLANET_LOW .. "planet_belsavis_secret_vaults_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Belsavis: Secret Vaults" },
            { path = SWTOR_PLANET_LOW .. "planet_belsavis_mind_trap_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Belsavis: Mind Trap" },
            { path = SWTOR_PLANET_LOW .. "planet_belsavis_ancient_horrors_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Belsavis: Ancient Horrors" },
            { path = SWTOR_PLANET_LOW .. "planet_dromund_kaas_default_x1_[planet_low_ambient_republic].mp3", theme = "ambient", title = "Dromund Kaas (Default x1)" },
        },
    },

    ["swtor_official_ambient"] = {
        name = "SWTOR Official - Ambient",
        mode = "ambient",
        tracks = {
            { path = SWTOR_OFFICIAL_LOW .. "official_10_peace_the_jedi_consular_[official_low_ambient_republic].mp3", theme = "ambient", title = "Peace, The Jedi Consular" },
            { path = SWTOR_OFFICIAL_LOW .. "official_16_tython_the_wellspring_[official_low_ambient_republic].mp3", theme = "ambient", title = "Tython: The Wellspring" },
            { path = SWTOR_OFFICIAL_LOW .. "official_20_nar_shaddaa_the_playground_[official_low_ambient_republic].mp3", theme = "ambient", title = "Nar Shaddaa: The Playground" },
            { path = SWTOR_OFFICIAL_LOW .. "official_21_tatooine_the_desert_sands_[official_low_ambient_republic].mp3", theme = "ambient", title = "Tatooine: The Desert Sands" },
            { path = SWTOR_OFFICIAL_LOW .. "official_25_hoth_the_frozen_wastes_[official_low_ambient_republic].mp3", theme = "ambient", title = "Hoth: The Frozen Wastes" },
            { path = SWTOR_OFFICIAL_LOW .. "official_26_alderaan_the_throne_[official_low_ambient_republic].mp3", theme = "ambient", title = "Alderaan: The Throne" },
            { path = SWTOR_OFFICIAL_LOW .. "official_27_belsavis_the_ancient_prison_[official_low_ambient_republic].mp3", theme = "ambient", title = "Belsavis: The Ancient Prison" },
            { path = SWTOR_OFFICIAL_LOW .. "official_28_voss_the_mystic_garden_[official_low_ambient_republic].mp3", theme = "ambient", title = "Voss: The Mystic Garden" },
            { path = SWTOR_OFFICIAL_LOW .. "official_31_makeb_the_lodestone_[official_low_ambient_republic].mp3", theme = "ambient", title = "Makeb: The Lodestone" },
            { path = SWTOR_OFFICIAL_LOW .. "official_32_makeb_the_secluded_jewel_[official_low_ambient_republic].mp3", theme = "ambient", title = "Makeb: The Secluded Jewel" },
            { path = SWTOR_OFFICIAL_LOW .. "official_45_odessen_the_distantwood_[official_low_ambient_republic].mp3", theme = "ambient", title = "Odessen: The Distantwood" },
            { path = SWTOR_OFFICIAL_LOW .. "official_59_onderon_the_lush_overgrowth_[official_low_ambient_republic].mp3", theme = "ambient", title = "Onderon: The Lush Overgrowth" },
            { path = SWTOR_OFFICIAL_LOW .. "official_63_the_lost_library_[official_low_ambient_republic].mp3", theme = "ambient", title = "The Lost Library" },
        },
    },

    ["swtor_expansions_ambient"] = {
        name = "SWTOR Expansions - Ambient",
        mode = "ambient",
        tracks = {
            { path = SWTOR_EXP_LOW .. "expansion_8_lots_to_manaan_peaceful_[expansion_low_ambient_republic].mp3", theme = "ambient", title = "Manaan (Peaceful)" },
            { path = SWTOR_EXP_LOW_2 .. "expansion_4_sor_track_x1_[expansion_low_ambient_republic_2].mp3", theme = "ambient", title = "SoR Track x1" },
            { path = SWTOR_EXP_LOW_2 .. "expansion_4_sor_track_x2_[expansion_low_ambient_republic_2].mp3", theme = "ambient", title = "SoR Track x2" },
            { path = SWTOR_EXP_LOW_2 .. "expansion_4_sor_track_x3_[expansion_low_ambient_republic_2].mp3", theme = "ambient", title = "SoR Track x3" },
            { path = SWTOR_EXP_LOW_2 .. "expansion_4_sor_track_x4_[expansion_low_ambient_republic_2].mp3", theme = "ambient", title = "SoR Track x4" },
            { path = SWTOR_EXP_LOW_2 .. "expansion_4_sor_track_x5_[expansion_low_ambient_republic_2].mp3", theme = "ambient", title = "SoR Track x5" },
            { path = SWTOR_EXP_LOW_3 .. "expansion_6_kotet_background_calm_[expansion_low_ambient_republic_3].mp3", theme = "ambient", title = "KotET Background Calm" },
            { path = SWTOR_EXP_LOW_3 .. "expansion_6_kotet_echoes_background_x1_[expansion_low_ambient_republic_3].mp3", theme = "ambient", title = "KotET Echoes Background x1" },
            { path = SWTOR_EXP_LOW_3 .. "expansion_6_kotet_echoes_background_x2_[expansion_low_ambient_republic_3].mp3", theme = "ambient", title = "KotET Echoes Background x2" },
            { path = SWTOR_EXP_LOW_3 .. "expansion_6_kotet_echoes_background_x3_[expansion_low_ambient_republic_3].mp3", theme = "ambient", title = "KotET Echoes Background x3" },
            { path = SWTOR_EXP_LOW_4 .. "expansion_4_1_rise_of_the_emperor_track_x1_[expansion_low_ambient_republic_4].mp3", theme = "ambient", title = "Rise of the Emperor Track x1" },
            { path = SWTOR_EXP_LOW_4 .. "expansion_4_1_rise_of_the_emperor_track_x2_[expansion_low_ambient_republic_4].mp3", theme = "ambient", title = "Rise of the Emperor Track x2" },
            { path = SWTOR_EXP_LOW_4 .. "expansion_4_1_rise_of_the_emperor_track_x3_[expansion_low_ambient_republic_4].mp3", theme = "ambient", title = "Rise of the Emperor Track x3" },
        },
    },

    ["swtor_cantinas_ambient"] = {
        name = "SWTOR Cantinas - Ambient",
        mode = "ambient",
        tracks = {
            { path = SWTOR_CANTINA .. "cantina_kotet_cantina_music_x1_[cantina_playful_social_republic].mp3", theme = "ambient", title = "KotET Cantina Music" },
            { path = SWTOR_CANTINA .. "cantina_for_the_republic_kotor_the_old_republic_[cantina_playful_social_republic].mp3", theme = "ambient", title = "For the Republic" },
            { path = SWTOR_CANTINA .. "cantina_dune_sea_special_anh_cantina_band_2_[cantina_playful_social_republic].mp3", theme = "ambient", title = "Dune Sea Special" },
            { path = SWTOR_CANTINA .. "cantina_not_the_droids_[cantina_playful_social_republic].mp3", theme = "ambient", title = "Not the Droids" },
            { path = SWTOR_CANTINA .. "cantina_the_bothan_bounce_[cantina_playful_social_republic].mp3", theme = "ambient", title = "The Bothan Bounce" },
            { path = SWTOR_CANTINA .. "cantina_run_kessel_run_[cantina_playful_social_republic].mp3", theme = "ambient", title = "Run Kessel Run" },
            { path = SWTOR_CANTINA .. "cantina_shake_that_wampa_down_[cantina_playful_social_republic].mp3", theme = "ambient", title = "Shake That Wampa Down" },
            { path = SWTOR_CANTINA .. "cantina_twice_around_the_system_and_home_again_[cantina_playful_social_republic].mp3", theme = "ambient", title = "Twice Around the System and Home Again" },
        },
    },
}

-- Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ KOTOR Music Playlists Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
-- Tracks sourced from the kotormusic addon (addons/kotormusic/sound/...).
-- Paths are relative to the sound/ directory Ã¢â‚¬â€ no "sound/" prefix.
--
-- Circumstances:
--   ambient   Ã¢â€ â€™ peaceful exploration, city life, nature, character themes
--   combat    Ã¢â€ â€™ all battle / action tracks
--   tension   Ã¢â€ â€™ dark, ominous, villain themes, eerie / mystery
--
-- To activate a circumstance in-game: /MusicSetCircumstance <name>
-- To open the GM panel: /MusicPanel

local K1 = "star wars - kotor/"
local K2 = "star wars - kotor ii/"

PLUGIN.playlists = {

    -- Ã¢â€â‚¬Ã¢â€â‚¬ KOTOR I: Ambient Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
    -- Peaceful location themes, city ambience, and reflective pieces from the first game.
    ["kotor1_ambient"] = {
        name = "KOTOR I Ã¢â‚¬â€ Ambient",
        mode = "ambient",
        tracks = {
            { path = K1 .. "1_old_republic_theme.ogg",    theme = "ambient", title = "Old Republic Theme" },
            { path = K1 .. "3_taris_apartments.ogg",       theme = "ambient", title = "Taris: Apartments" },
            { path = K1 .. "4_taris_upper_city.ogg",       theme = "ambient", title = "Taris: Upper City" },
            { path = K1 .. "6_taris_lower_city.ogg",       theme = "ambient", title = "Taris: Lower City" },
            { path = K1 .. "9_pazaak.ogg",                 theme = "ambient", title = "Pazaak" },
            { path = K1 .. "15_dantooine.ogg",             theme = "ambient", title = "Dantooine" },
            { path = K1 .. "16_the_jedi_academy.ogg",      theme = "ambient", title = "The Jedi Academy" },
            { path = K1 .. "19_tatooine.ogg",              theme = "ambient", title = "Tatooine" },
            { path = K1 .. "21_tatooine_dune_sea.ogg",     theme = "ambient", title = "Tatooine: Dune Sea" },
            { path = K1 .. "24_manaan_ahto_city.ogg",      theme = "ambient", title = "Manaan: Ahto City" },
            { path = K1 .. "27_kashyyyk.ogg",              theme = "ambient", title = "Kashyyyk" },
            { path = K1 .. "34_the_unknown_world.ogg",     theme = "ambient", title = "The Unknown World" },
            { path = K1 .. "35_rakata_ancient_ruins.ogg",  theme = "ambient", title = "Rakata: Ancient Ruins" },
            { path = K1 .. "40_finale_and_end_credits.ogg",theme = "ambient", title = "Finale and End Credits" },
        },
    },

    -- Ã¢â€â‚¬Ã¢â€â‚¬ KOTOR II: Ambient Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
    -- Exploration, ship interiors, city life, and quieter character pieces from TSL.
    ["kotor2_ambient"] = {
        name = "KOTOR II Ã¢â‚¬â€ Ambient",
        mode = "ambient",
        tracks = {
            { path = K2 .. "1_the_sith_lords.ogg",             theme = "ambient", title = "The Sith Lords" },
            { path = K2 .. "2_ebon_hawk_adrift.ogg",           theme = "ambient", title = "Ebon Hawk Adrift" },
            { path = K2 .. "3_awaken.ogg",                     theme = "ambient", title = "Awaken" },
            { path = K2 .. "6_the_light_side.ogg",             theme = "ambient", title = "The Light Side" },
            { path = K2 .. "10_t3_m4.ogg",                     theme = "ambient", title = "T3-M4" },
            { path = K2 .. "11_attons_advice.ogg",             theme = "ambient", title = "Atton's Advice" },
            { path = K2 .. "14_the_ebon_hawk.ogg",             theme = "ambient", title = "The Ebon Hawk" },
            { path = K2 .. "16_citadel_station.ogg",           theme = "ambient", title = "Citadel Station" },
            { path = K2 .. "18_b4_d4.ogg",                     theme = "ambient", title = "B-4D4" },
            { path = K2 .. "19_eyesight_to_the_blind.ogg",     theme = "ambient", title = "Eyesight to the Blind" },
            { path = K2 .. "20_surface_of_telos.ogg",          theme = "ambient", title = "Surface of Telos" },
            { path = K2 .. "23_polar_plateau.ogg",             theme = "ambient", title = "Polar Plateau" },
            { path = K2 .. "25_the_jedi_academy.ogg",          theme = "ambient", title = "The Jedi Academy" },
            { path = K2 .. "28_the_smugglers_moon.ogg",        theme = "ambient", title = "The Smuggler's Moon" },
            { path = K2 .. "29_a_wretched_hive.ogg",           theme = "ambient", title = "A Wretched Hive" },
            { path = K2 .. "37_the_city_of_iziz.ogg",          theme = "ambient", title = "The City of Iziz" },
            { path = K2 .. "40_the_khoonda_plains.ogg",        theme = "ambient", title = "The Khoonda Plains" },
            { path = K2 .. "41_administrator_adare.ogg",       theme = "ambient", title = "Administrator Adare" },
            { path = K2 .. "46_the_royal_palace.ogg",          theme = "ambient", title = "The Royal Palace" },
            { path = K2 .. "47_back_together.ogg",             theme = "ambient", title = "Back Together" },
            { path = K2 .. "51_past_present_and_future.ogg",   theme = "ambient", title = "Past, Present and Future" },
            { path = K2 .. "65_kotor_march.ogg",               theme = "ambient", title = "KotOR March" },
        },
    },

    -- Ã¢â€â‚¬Ã¢â€â‚¬ Cantinas Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
    -- Social / downtime music. Both cantina tracks from K1 and K2.
    ["kotor_cantina"] = {
        name = "Cantinas",
        mode = "ambient",
        tracks = {
            { path = K1 .. "8_jayvars_cantina.ogg",  theme = "ambient", title = "Javyar's Cantina" },
            { path = K2 .. "64_iziz_cantina.ogg",    theme = "ambient", title = "Iziz Cantina" },
        },
    },

    -- Ã¢â€â‚¬Ã¢â€â‚¬ KOTOR I: Combat Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
    -- All battle and action tracks from the first game.
    ["kotor1_combat"] = {
        name = "KOTOR I Ã¢â‚¬â€ Combat",
        mode = "combat",
        tracks = {
            { path = K1 .. "5_sith_guard_encounter.ogg",       theme = "combat", title = "Sith Guard Encounter" },
            { path = K1 .. "7_the_black_vulkars.ogg",          theme = "combat", title = "The Black Vulkars" },
            { path = K1 .. "10_rakghoul_attack.ogg",           theme = "combat", title = "Rakghoul Attack" },
            { path = K1 .. "13_battle_at_daviks_estate.ogg",   theme = "combat", title = "Battle at Davik's Estate" },
            { path = K1 .. "17_dantooine_battle.ogg",          theme = "combat", title = "Dantooine Battle" },
            { path = K1 .. "18_guard_droid_battle.ogg",        theme = "combat", title = "Guard Droid Battle" },
            { path = K1 .. "20_anchorhead_street_fight.ogg",   theme = "combat", title = "Anchorhead Street Fight" },
            { path = K1 .. "23_tatooine_battle.ogg",           theme = "combat", title = "Tatooine Battle" },
            { path = K1 .. "25_ahto_sith_battle.ogg",          theme = "combat", title = "Ahto Sith Battle" },
            { path = K1 .. "26_insane_selkath_fight.ogg",      theme = "combat", title = "Insane Selkath Fight" },
            { path = K1 .. "29_confronting_darth_bandon.ogg",  theme = "combat", title = "Confronting Darth Bandon" },
            { path = K1 .. "36_rakata_ruins_battle.ogg",       theme = "combat", title = "Rakata Ruins Battle" },
            { path = K1 .. "38_star_forge_battle.ogg",         theme = "combat", title = "Star Forge Battle" },
            { path = K1 .. "39_darth_malak_battle.ogg",        theme = "combat", title = "Darth Malak Battle" },
        },
    },

    -- Ã¢â€â‚¬Ã¢â€â‚¬ KOTOR II: Combat Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
    -- All battle and action tracks from TSL.
    ["kotor2_combat"] = {
        name = "KOTOR II Ã¢â‚¬â€ Combat",
        mode = "combat",
        tracks = {
            { path = K2 .. "17_mercenary_troubles.ogg",              theme = "combat", title = "Mercenary Troubles" },
            { path = K2 .. "21_battle_in_the_restoration_zone.ogg",  theme = "combat", title = "Battle in the Restoration Zone" },
            { path = K2 .. "24_battle_in_the_polar_region.ogg",      theme = "combat", title = "Battle in the Polar Region" },
            { path = K2 .. "31_ubese_warriors.ogg",                  theme = "combat", title = "Ubese Warriors" },
            { path = K2 .. "35_battle_in_the_jungle.ogg",            theme = "combat", title = "Battle in the Jungle" },
            { path = K2 .. "38_riots_in_the_streets.ogg",            theme = "combat", title = "Riots in the Streets" },
            { path = K2 .. "39_civil_war.ogg",                       theme = "combat", title = "Civil War" },
            { path = K2 .. "42_kinrath_trouble.ogg",                 theme = "combat", title = "Kinrath Trouble" },
            { path = K2 .. "44_laigrek_infestation.ogg",             theme = "combat", title = "Laigrek Infestation" },
            { path = K2 .. "49_guardians_of_korriban.ogg",           theme = "combat", title = "Guardians of Korriban" },
            { path = K2 .. "60_battle_on_malachor_v.ogg",            theme = "combat", title = "Battle on Malachor V" },
            { path = K2 .. "63_the_final_battle.ogg",                theme = "combat", title = "The Final Battle" },
        },
    },

    -- Ã¢â€â‚¬Ã¢â€â‚¬ KOTOR I: Tension Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
    -- Ominous, dark, and villain themes from K1: Sith bases, the Leviathan, Korriban.
    ["kotor1_tension"] = {
        name = "KOTOR I Ã¢â‚¬â€ Tension",
        mode = "ambient",
        tracks = {
            { path = K1 .. "2_the_endar_spire.ogg",           theme = "tension", title = "The Endar Spire" },
            { path = K1 .. "11_bastila_shan.ogg",             theme = "tension", title = "Bastila Shan" },
            { path = K1 .. "12_inside_the_sith_base.ogg",     theme = "tension", title = "Inside the Sith Base" },
            { path = K1 .. "14_darth_malak.ogg",              theme = "tension", title = "Darth Malak" },
            { path = K1 .. "22_sand_people.ogg",              theme = "tension", title = "Sand People" },
            { path = K1 .. "28_kashyyyk_shadowlands.ogg",     theme = "tension", title = "Kashyyyk: Shadowlands" },
            { path = K1 .. "30_captured_by_the_leviathan.ogg",theme = "tension", title = "Captured by the Leviathan" },
            { path = K1 .. "31_the_leviathan.ogg",            theme = "tension", title = "The Leviathan" },
            { path = K1 .. "32_korriban_sith_academy.ogg",    theme = "tension", title = "Korriban: Sith Academy" },
            { path = K1 .. "33_uthar_wynns_trials.ogg",       theme = "tension", title = "Uthar Wynn's Trials" },
            { path = K1 .. "37_aboard_the_star_forge.ogg",    theme = "tension", title = "Aboard the Star Forge" },
        },
    },

    -- Ã¢â€â‚¬Ã¢â€â‚¬ KOTOR II: Tension Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
    -- The darkest and most ominous tracks from TSL: Peragus, the Sith Lords, Malachor.
    ["kotor2_tension"] = {
        name = "KOTOR II Ã¢â‚¬â€ Tension",
        mode = "ambient",
        tracks = {
            { path = K2 .. "4_stranded_on_peragus.ogg",           theme = "tension", title = "Stranded on Peragus" },
            { path = K2 .. "5_kreia.ogg",                         theme = "tension", title = "Kreia" },
            { path = K2 .. "7_the_dark_side.ogg",                 theme = "tension", title = "The Dark Side" },
            { path = K2 .. "8_mining_droids.ogg",                 theme = "tension", title = "Mining Droids" },
            { path = K2 .. "9_a_voice_from_beyond.ogg",           theme = "tension", title = "A Voice from Beyond" },
            { path = K2 .. "12_the_ghost_ship.ogg",               theme = "tension", title = "The Ghost Ship" },
            { path = K2 .. "13_darth_sion.ogg",                   theme = "tension", title = "Darth Sion" },
            { path = K2 .. "15_uninvited_guests.ogg",             theme = "tension", title = "Uninvited Guests" },
            { path = K2 .. "22_abandoned_military_base.ogg",      theme = "tension", title = "Abandoned Military Base" },
            { path = K2 .. "26_atris.ogg",                        theme = "tension", title = "Atris" },
            { path = K2 .. "27_kreias_fall.ogg",                  theme = "tension", title = "Kreia's Fall" },
            { path = K2 .. "30_the_perfect_trap.ogg",             theme = "tension", title = "The Perfect Trap" },
            { path = K2 .. "32_gotos_flagship.ogg",               theme = "tension", title = "GOTO's Flagship" },
            { path = K2 .. "33_binary_opposition.ogg",            theme = "tension", title = "Binary Opposition" },
            { path = K2 .. "34_old_wounds.ogg",                   theme = "tension", title = "Old Wounds" },
            { path = K2 .. "36_clan_ordo.ogg",                    theme = "tension", title = "Clan Ordo" },
            { path = K2 .. "43_the_enclave_sublevel.ogg",         theme = "tension", title = "The Enclave Sublevel" },
            { path = K2 .. "45_the_tomb_of_freedon_nadd.ogg",     theme = "tension", title = "The Tomb of Freedon Nadd" },
            { path = K2 .. "48_ancient_graves.ogg",               theme = "tension", title = "Ancient Graves" },
            { path = K2 .. "50_echoes_of_the_sith.ogg",           theme = "tension", title = "Echoes of the Sith" },
            { path = K2 .. "52_the_droid_planet.ogg",             theme = "tension", title = "The Droid Planet" },
            { path = K2 .. "53_irradiated_zone.ogg",              theme = "tension", title = "Irradiated Zone" },
            { path = K2 .. "54_industrial_control.ogg",           theme = "tension", title = "Industrial Control" },
            { path = K2 .. "55_the_core.ogg",                     theme = "tension", title = "The Core" },
            { path = K2 .. "56_ruins_of_the_jedi_enclave.ogg",    theme = "tension", title = "Ruins of the Jedi Enclave" },
            { path = K2 .. "57_the_ravager.ogg",                  theme = "tension", title = "The Ravager" },
            { path = K2 .. "58_darth_nihilus.ogg",                theme = "tension", title = "Darth Nihilus" },
            { path = K2 .. "59_graveyard_of_the_mandalorians.ogg",theme = "tension", title = "Graveyard of the Mandalorians" },
            { path = K2 .. "61_teachings_of_the_true_sith.ogg",   theme = "tension", title = "Teachings of the True Sith" },
            { path = K2 .. "62_darth_traya.ogg",                  theme = "tension", title = "Darth Traya" },
        },
    },

}

PLUGIN.playlists = {}
table.Merge(PLUGIN.playlists, KOTOR_PLAYLISTS)

-- Folders to scan for mp3 files at runtime (client-side only, at AmbientMusicStart).
-- Do NOT include the 'sound/' prefix.
PLUGIN.ambientFolders = {
    --"music/ambient/",
}

-- to force clients to download the workshop addon containing hte music 3699361408
if SERVER then
    resource.AddWorkshop("3699361408")
end
