## Defines a character skin resource for BattleZone Party.
## Holds visual customization data: colors, type, and metadata.
class_name CharacterSkin
extends Resource

## Unique identifier for this skin.
@export var skin_id: int = 0

## Display name shown in character select.
@export var skin_name: String = ""

## Primary body color applied to the main mesh material.
@export var mesh_color: Color = Color.WHITE

## Secondary/trim color used for accents and details.
@export var accent_color: Color = Color.GRAY

## Color applied to the eye region of the character.
@export var eye_color: Color = Color.WHITE

## Short description shown in the character select screen.
@export var description: String = ""

## The archetype/style of this character skin.
@export_enum("Robot", "Ninja", "Astronaut", "Pirate", "Knight", "Alien") var character_type: String = "Robot"
