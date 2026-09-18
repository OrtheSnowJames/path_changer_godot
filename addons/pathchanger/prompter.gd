extends RefCounted

const _Config = preload("config.gd")

## builds an unpopped confirmation dialog with a remember checkbox, added to the editor base control
func _new_dialog(title: String, description: String, yes_text: String, no_text: String) -> Dictionary:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = description
	dialog.ok_button_text = yes_text
	dialog.cancel_button_text = no_text

	# the label doesnt wrap on its own so force it to a fixed width or itll stretch into one long line
	var label := dialog.get_label()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(400, 0)

	var checkbox := CheckBox.new()
	checkbox.text = "Don't show this again"
	checkbox.tooltip_text = "saved to " + ProjectSettings.globalize_path(_Config.CONFIG_PATH)
	dialog.add_child(checkbox)

	# add to the editor base control since this helper isnt in the tree itself
	EditorInterface.get_base_control().add_child(dialog)
	return {"dialog": dialog, "checkbox": checkbox}

## takes in prompt options, returns choice "yes"/"no" and whether to remember it
func prompt(title: String, description: String, yes_text: String, no_text: String) -> Dictionary:
	var built := _new_dialog(title, description, yes_text, no_text)
	var dialog: ConfirmationDialog = built.dialog
	var checkbox: CheckBox = built.checkbox

	# held in a dict because lambdas capture locals by value not by reference
	var state := {"choice": "no", "finished": false}

	dialog.confirmed.connect(func():
		state.choice = "yes"
		state.finished = true
	)

	dialog.canceled.connect(func():
		state.finished = true
	)

	dialog.popup_centered()

	while not state.finished:
		await dialog.get_tree().process_frame

	var remember := checkbox.button_pressed
	dialog.queue_free()
	return {"choice": state.choice, "remember": remember}

## same as prompt but with a third button, choice is "yes" "no" or "extra"
func prompt_with_extra(title: String, description: String, yes_text: String, no_text: String, extra_text: String) -> Dictionary:
	var built := _new_dialog(title, description, yes_text, no_text)
	var dialog: ConfirmationDialog = built.dialog
	var checkbox: CheckBox = built.checkbox
	dialog.add_button(extra_text, false, "extra")

	var state := {"choice": "no", "finished": false}

	dialog.confirmed.connect(func():
		state.choice = "yes"
		state.finished = true
	)

	dialog.canceled.connect(func():
		state.finished = true
	)

	# custom buttons dont auto close the dialog so hide it ourselves
	dialog.custom_action.connect(func(action):
		state.choice = action
		state.finished = true
		dialog.hide()
	)

	dialog.popup_centered()

	while not state.finished:
		await dialog.get_tree().process_frame

	var remember := checkbox.button_pressed
	dialog.queue_free()
	return {"choice": state.choice, "remember": remember}
