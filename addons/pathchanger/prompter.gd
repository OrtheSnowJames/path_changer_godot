extends EditorPlugin

## Takes in prompt options and returns yes or no as a bool
func prompt(title: String, description: String, yes_text: String, no_text: String) -> bool:
	var dialog = ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = description
	dialog.ok_button_text = yes_text
	dialog.cancel_button_text = no_text

	add_child(dialog)

	var result := false
	var finished := false

	dialog.confirmed.connect(func():
		result = true
		finished = true
	)

	dialog.canceled.connect(func():
		result = false
		finished = true
	)

	dialog.popup_centered()

	while not finished:
		await get_tree().process_frame

	dialog.queue_free()
	return result
