extends SceneTree

const AppTheme := preload("res://presentation/panbeat_theme.gd")
const Tokens := preload("res://presentation/ui_tokens.gd")

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var args := OS.get_cmdline_user_args(); var output_index := args.find("--output"); var mode_index := args.find("--mode")
	if output_index < 0 or mode_index < 0: quit(64); return
	var after := args[mode_index + 1] == "after"
	root.size = Vector2i(1280, 720); RenderingServer.set_default_clear_color(Color("0b0e16") if after else Color("101620"))
	var page := MarginContainer.new(); page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for key: String in ["margin_left","margin_right","margin_top","margin_bottom"]: page.add_theme_constant_override(key, 40)
	if after: page.theme = AppTheme.shared()
	root.add_child(page)
	var layout := VBoxContainer.new(); layout.add_theme_constant_override("separation", 14); page.add_child(layout)
	var title := Label.new(); title.text = "P303 · COMPONENT GALLERY · %s" % ("QUIET FORGE THEME" if after else "PHASE 2 FALLBACK"); title.add_theme_font_size_override("font_size", 28); layout.add_child(title)
	var buttons := HBoxContainer.new(); buttons.add_theme_constant_override("separation", 10); layout.add_child(buttons)
	for entry: Dictionary in [{"text":"Normal","variation":""},{"text":"Hover","variation":"PreviewHoverButton"},{"text":"Pressed","variation":"PreviewPressedButton"},{"text":"Focus","variation":""},{"text":"Disabled","variation":"PreviewDisabledButton"}]:
		var button := Button.new(); button.text = entry["text"]; button.custom_minimum_size = Vector2(150, 48); button.theme_type_variation = entry["variation"] if after else ""; button.disabled = entry["text"] == "Disabled"; buttons.add_child(button)
		if entry["text"] == "Focus": button.grab_focus()
	var inputs := HBoxContainer.new(); inputs.add_theme_constant_override("separation", 12); layout.add_child(inputs)
	var edit := LineEdit.new(); edit.text = "Editable field"; edit.custom_minimum_size = Vector2(260, 46); inputs.add_child(edit)
	var readonly := LineEdit.new(); readonly.text = "Read-only field"; readonly.editable = false; readonly.custom_minimum_size = Vector2(260, 46); inputs.add_child(readonly)
	var options := OptionButton.new(); options.add_item("Selected option"); options.add_item("Alternative"); options.custom_minimum_size = Vector2(250, 46); inputs.add_child(options)
	var middle := HBoxContainer.new(); middle.add_theme_constant_override("separation", 16); middle.size_flags_vertical = Control.SIZE_EXPAND_FILL; layout.add_child(middle)
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(420, 230)
	for value: String in ["Orbit Practice","Evening Pulse","Broken Import — repair available"]:
		list.add_item(value)
	list.select(0)
	middle.add_child(list)
	var statuses := VBoxContainer.new(); statuses.add_theme_constant_override("separation", 10); statuses.size_flags_horizontal = Control.SIZE_EXPAND_FILL; middle.add_child(statuses)
	for entry: Dictionary in [{"kind":"success","text":"MIDI ready — MN-10"},{"kind":"warning","text":"Reopen required after hot-plug"},{"kind":"error","text":"Audio output unavailable — Retry"},{"kind":"info","text":"Loading song metadata…"}]:
		var panel := PanelContainer.new(); panel.theme_type_variation = "%sPanel" % entry["kind"].capitalize() if after else ""; var label := Label.new(); label.text = AppTheme.status_text(entry["kind"], entry["text"]) if after else entry["text"]; panel.add_child(label); statuses.add_child(panel)
	var progress := ProgressBar.new(); progress.value = 67; progress.show_percentage = true; progress.custom_minimum_size.y = 30; layout.add_child(progress)
	var note := Label.new(); note.text = "Fallback font: Godot/OS · no external assets · token %s" % Tokens.VERSION; layout.add_child(note)
	for _frame: int in 5: await process_frame
	var error := root.get_texture().get_image().save_png(args[output_index + 1]); quit(0 if error == OK else 1)
