## Provides the six default character skins for BattleZone Party.
class_name DefaultSkins
extends RefCounted


## Returns an Array of [CharacterSkin] resources for all built-in characters.
static func get_all() -> Array[CharacterSkin]:
	var skins: Array[CharacterSkin] = []

	# 0 — Robot (gray / blue)
	var robot := CharacterSkin.new()
	robot.skin_id = 0
	robot.skin_name = "Robot"
	robot.mesh_color = Color(0.55, 0.55, 0.6)
	robot.accent_color = Color(0.2, 0.5, 0.9)
	robot.eye_color = Color(0.3, 0.8, 1.0)
	robot.description = "A sturdy mechanical fighter built for the arena."
	robot.character_type = "Robot"
	skins.append(robot)

	# 1 — Ninja (black / red)
	var ninja := CharacterSkin.new()
	ninja.skin_id = 1
	ninja.skin_name = "Ninja"
	ninja.mesh_color = Color(0.1, 0.1, 0.1)
	ninja.accent_color = Color(0.85, 0.1, 0.1)
	ninja.eye_color = Color(1.0, 1.0, 1.0)
	ninja.description = "Silent and swift — strikes from the shadows."
	ninja.character_type = "Ninja"
	skins.append(ninja)

	# 2 — Astronaut (white / orange)
	var astronaut := CharacterSkin.new()
	astronaut.skin_id = 2
	astronaut.skin_name = "Astronaut"
	astronaut.mesh_color = Color(0.95, 0.95, 0.95)
	astronaut.accent_color = Color(1.0, 0.55, 0.1)
	astronaut.eye_color = Color(0.4, 0.7, 1.0)
	astronaut.description = "One small step for fun, one giant leap for party games."
	astronaut.character_type = "Astronaut"
	skins.append(astronaut)

	# 3 — Pirate (brown / gold)
	var pirate := CharacterSkin.new()
	pirate.skin_id = 3
	pirate.skin_name = "Pirate"
	pirate.mesh_color = Color(0.45, 0.25, 0.1)
	pirate.accent_color = Color(0.9, 0.75, 0.2)
	pirate.eye_color = Color(0.2, 0.2, 0.2)
	pirate.description = "Yo-ho-ho! Plundering victory on every map."
	pirate.character_type = "Pirate"
	skins.append(pirate)

	# 4 — Knight (silver / purple)
	var knight := CharacterSkin.new()
	knight.skin_id = 4
	knight.skin_name = "Knight"
	knight.mesh_color = Color(0.75, 0.75, 0.8)
	knight.accent_color = Color(0.5, 0.2, 0.7)
	knight.eye_color = Color(0.9, 0.85, 0.6)
	knight.description = "Clad in shining armor, ready for honorable combat."
	knight.character_type = "Knight"
	skins.append(knight)

	# 5 — Alien (green / cyan)
	var alien := CharacterSkin.new()
	alien.skin_id = 5
	alien.skin_name = "Alien"
	alien.mesh_color = Color(0.2, 0.75, 0.3)
	alien.accent_color = Color(0.0, 0.9, 0.85)
	alien.eye_color = Color(0.9, 0.1, 0.9)
	alien.description = "From a galaxy far away — here to party."
	alien.character_type = "Alien"
	skins.append(alien)

	return skins
