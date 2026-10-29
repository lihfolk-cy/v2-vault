# World brief template

Fill this in before placing anything (5-15 lines is enough). Every later choice is checked against it.
A world with a filled brief and a blockout that passes the walk test scores far better than one dressed first.

```
WORLD BRIEF: <zone or map name, 6-16 chars; the art matches the name>

Fantasy      one sentence: who the player is here and what they feel ("a lantern-lit market at dusk after the harvest")
Play pattern what players do, in order: spawn -> <goal 1> -> <goal 2>; session length; solo or how many together
Target       mobile first | PC first; max players in this space; StreamingEnabled yes/no
Scale        R15 default (5 studs) | custom <n> studs; WalkSpeed <n>; jump mode
Style        one family: flat stylised | low-poly faceted | voxel/studs | hand-painted | PBR semi-real | neon sci-fi
Mood         one lighting preset (bright cartoon | toon arena | golden hour | readable night | fog horror | neon city) + time of day
Palette      3-5 base colours (RGB) with roles: ground, structure, foliage, sky/fog, trim
Accents      1-2 accent hues spent only on the hero, interactables and rewards (one game-wide pickup colour)
Hero         the landmark: what it is, where, height (>= 1.5x anything else), seen from where
Districts    nodes and areas with one purpose each (spawn, plaza, shop row, arena, exit)
Paths        main path width, side path width, what marks them (material, light, edges)
Not this     3-5 things this place must never look like ("no toolbox pine trees", "no grey concrete", "no neon in the forest")
Story        2-3 environmental hints ("a cart abandoned mid-unload", "lanterns lit only on the way to the shrine")
Budget       instance / light / shadowed-light caps for this folder (see budgets.md)
Assets       which LihFolk kits, materials and skies (lihfolk-assets), which buildings to model (roblox-blender-modeling)
```

## Example

```
WORLD BRIEF: Lanternfall Square

Fantasy      a village square at dusk, lanterns being lit for a harvest night; warm, safe, a little busy
Play pattern spawn -> quest board at the well -> market stalls -> north road to the fields; 3-8 players
Target       mobile first; 12 players; StreamingEnabled on
Scale        R15 default; WalkSpeed 16; JumpHeight 7.2
Style        flat stylised (Color-only props, a few MaterialVariants on ground and stone)
Mood         golden hour, ClockTime 17.6
Palette      cobble 178,164,140 | timber 120,84,60 | plaster 232,220,196 | grass 104,140,78 | dusk sky 255,200,160
Accents      lantern amber 255,176,64 (lights, quest board); pickups use teal 64,200,190 only
Hero         the stone well with a lantern arch, 22 studs, centre of the square, framed by the north road
Districts    spawn (south), square (centre), market corner (NE), road to fields (north), lane to the mill (east)
Paths        square radius 40; north road 20 wide, east lane 12 wide; paths lighter Ground, edges darker LeafyGrass
Not this     no evenly sprinkled props; no random-yaw crates; no bright lights in dead ends; no realistic PBR metal
Story        crates stacked by one stall half unpacked; a ladder against the lamp post nearest the well
Budget       <= 4k instances, <= 10 lights, 2 shadowed (well arch + market)
Assets       LihFolk village kit (houses via lihfolk_house.py), cobble MaterialVariant, dusk sky
```
