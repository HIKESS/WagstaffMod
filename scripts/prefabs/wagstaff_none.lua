local assets =
{
	Asset( "ANIM", "anim/wagstaff.zip" ),
	Asset( "ANIM", "anim/ghost_wagstaff_build.zip" ),
}

local skins =
{
	normal_skin = "wagstaff",
	ghost_skin = "ghost_wagstaff_build",
}

return CreatePrefabSkin("wagstaff_none",
{
	base_prefab = "wagstaff",
	type = "base",
	assets = assets,
	skins = skins, 
	skin_tags = {"WAGSTAFF", "CHARACTER", "BASE"},
	build_name = "wagstaff",
	rarity = "Common",
})