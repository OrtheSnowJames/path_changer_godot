extends RefCounted

## takes in prompt options and returns yes or no as a bool
func prompt(title: String, description: String, yes_text: String, no_text: String) -> bool:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = description
	dialog.ok_button_text = yes_text
	dialog.cancel_button_text = no_text

	# add to the editor base control since this helper isnt in the tree itself
	EditorInterface.get_base_control().add_child(dialog)

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
