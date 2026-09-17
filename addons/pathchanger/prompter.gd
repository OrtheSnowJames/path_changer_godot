extends RefCounted

## builds an unpopped confirmation dialog added to the editor base control
func _new_dialog(title: String, description: String, yes_text: String, no_text: String) -> ConfirmationDialog:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = description
	dialog.ok_button_text = yes_text
	dialog.cancel_button_text = no_text

	# add to the editor base control since this helper isnt in the tree itself
	EditorInterface.get_base_control().add_child(dialog)
	return dialog

## takes in prompt options and returns yes or no as a bool
func prompt(title: String, description: String, yes_text: String, no_text: String) -> bool:
	var dialog := _new_dialog(title, description, yes_text, no_text)

	# held in a dict because lambdas capture locals by value not by reference
	var state := {"result": false, "finished": false}

	dialog.confirmed.connect(func():
		state.result = true
		state.finished = true
	)

	dialog.canceled.connect(func():
		state.finished = true
	)

	dialog.popup_centered()

	while not state.finished:
		await dialog.get_tree().process_frame

	dialog.queue_free()
	return state.result

## same as prompt but with a third button, returns "yes" "no" or "extra"
func prompt_with_extra(title: String, description: String, yes_text: String, no_text: String, extra_text: String) -> String:
	var dialog := _new_dialog(title, description, yes_text, no_text)
	dialog.add_button(extra_text, false, "extra")

	var state := {"result": "no", "finished": false}

	dialog.confirmed.connect(func():
		state.result = "yes"
		state.finished = true
	)

	dialog.canceled.connect(func():
		state.finished = true
	)

	# custom buttons dont auto close the dialog so hide it ourselves
	dialog.custom_action.connect(func(action):
		state.result = action
		state.finished = true
		dialog.hide()
	)

	dialog.popup_centered()

	while not state.finished:
		await dialog.get_tree().process_frame

	dialog.queue_free()
	return state.result
