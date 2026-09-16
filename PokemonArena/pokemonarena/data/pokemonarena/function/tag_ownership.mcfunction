# Tags every not-yet-checked Cobblemon Pokemon as pa_owned (has a trainer),
# based on Pokemon.PokemonOriginalTrainerType. Also tags every real player
# pa_player, so startup.lua's "Trainer:" guess only ever picks an actual
# player, never a wandering mob.
# PokemonArena's startup.lua filters scanEntities() results on these tags -
# see ../../../../NOTES.txt for why this datapack exists at all.

execute as @e[type=cobblemon:pokemon,tag=!pa_checked] unless data entity @s Pokemon{PokemonOriginalTrainerType:"NONE"} run tag @s add pa_owned
tag @e[type=cobblemon:pokemon,tag=!pa_checked] add pa_checked

# Players can't be "pre-checked" like Pokemon (no birth event to hook) - just
# re-tag everyone online every cycle. Re-adding an existing tag is a no-op,
# so this stays cheap even with several players online.
tag @a add pa_player

schedule function pokemonarena:tag_ownership 20t
