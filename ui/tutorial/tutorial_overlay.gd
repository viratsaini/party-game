## TutorialOverlay — Visual overlay showing tutorial steps
extends CanvasLayer

@onready var step_indicator: Label = %StepIndicator
@onready var title_label: Label = %Title
@onready var description_label: Label = %Description
@onready var skip_button: Button = %SkipButton
@onready var next_button: Button = %NextButton
@onready var highlight_rect: ReferenceRect = %HighlightRect
@onready var arrow: Polygon2D = %Arrow
@onready var dim_overlay: ColorRect = $DimOverlay

func _ready() -> void:
	visible = false
	skip_button.pressed.connect(_on_skip_pressed)
	next_button.pressed.connect(_on_next_pressed)

func show_tutorial() -> void:
	visible = true

func hide_tutorial() -> void:
	visible = false

func update_step(step_data: Dictionary, step_index: int, total_steps: int) -> void:
	step_indicator.text = "Step %d of %d" % [step_index + 1, total_steps]
	title_label.text = step_data.get("title", "")
	description_label.text = step_data.get("description", "")

	if step_index >= total_steps - 1:
		next_button.text = "FINISH"
	else:
		next_button.text = "NEXT"

	# Handle highlighting
	var highlight_target: String = step_data.get("highlight", "")
	if highlight_target.is_empty():
		highlight_rect.visible = false
		arrow.visible = false
		dim_overlay.visible = true
	else:
		_highlight_element(highlight_target)

func _highlight_element(element_name: String) -> void:
	# This would be expanded to actually find and highlight UI elements
	highlight_rect.visible = false
	arrow.visible = false
	dim_overlay.visible = true

func _on_skip_pressed() -> void:
	if is_instance_valid(TutorialManager):
		TutorialManager.skip_tutorial()
	hide_tutorial()

func _on_next_pressed() -> void:
	if is_instance_valid(TutorialManager):
		TutorialManager.next_step()
