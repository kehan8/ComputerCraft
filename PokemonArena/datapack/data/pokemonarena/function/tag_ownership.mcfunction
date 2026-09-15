# Tags every not-yet-checked Cobblemon Pokemon as pa_owned (has a trainer)
# or pa_wild (wild-spawned), based on Pokemon.PokemonOriginalTrainerType.
# PokemonArena's startup.lua filters scanEntities() results on these tags -
# see ../../../../NOTES.txt for why this datapack exists at all.

execute as @e[type=cobblemon:pokemon,tag=!pa_checked] if data entity @s Pokemon{PokemonOriginalTrainerType:"NONE"} run tag @s add pa_wild
execute as @e[type=cobblemon:pokemon,tag=!pa_checked] unless data entity @s Pokemon{PokemonOriginalTrainerType:"NONE"} run tag @s add pa_owned
tag @e[type=cobblemon:pokemon,tag=!pa_checked] add pa_checked

schedule function pokemonarena:tag_ownership 20t
