extends Control
## Text Sandbox — scaffold and entrypoint for the FUTURE text/dialogue/NPC-mind subsystem.
##
## Right now this is deliberately minimal-but-real: a scrollable transcript plus a
## single-line input that submits on Enter and echoes the line back into the transcript.
## It is the seam the conversational/NPC-mind work will grow into — the input line will
## become the player utterance channel, and _append_line() the place where NPC turns,
## narration, and system messages land. Keep this a clean foundation: route everything
## through _submit() / _append_line() so the eventual dialogue driver only has to swap
## what produces the response, not the IO plumbing.
##
## Standalone-runnable (it is its own scene); also instanced as a mode inside
## scenes/launcher.tscn. No mouse-capture, no 3D — pure Control UI.

const PROMPT_PREFIX := "> "

var _transcript: RichTextLabel
var _scroll: ScrollContainer
var _input: LineEdit


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var header := Label.new()
	header.text = "Text Sandbox — placeholder transcript (future dialogue / NPC-mind entrypoint)"
	header.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	root.add_child(header)

	# Transcript: a RichTextLabel inside a ScrollContainer so long conversations scroll.
	_transcript = RichTextLabel.new()
	_transcript.bbcode_enabled = true
	_transcript.scroll_active = true
	_transcript.scroll_following = true
	_transcript.selection_enabled = true
	_transcript.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_transcript.add_theme_constant_override("margin_left", 6)
	root.add_child(_transcript)

	# Input row: a single-line field that submits on Enter.
	var input_row := HBoxContainer.new()
	input_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(input_row)

	var prompt := Label.new()
	prompt.text = PROMPT_PREFIX
	input_row.add_child(prompt)

	_input = LineEdit.new()
	_input.placeholder_text = "Type a line and press Enter…"
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.clear_button_enabled = true
	_input.text_submitted.connect(_on_text_submitted)
	input_row.add_child(_input)

	_append_line("[i]Text sandbox ready. This is a scaffold — your input is echoed for now.[/i]", Color(0.6, 0.65, 0.7))
	_input.grab_focus()


func _on_text_submitted(text: String) -> void:
	_submit(text)


## Submit a player line. For now this only echoes; this is the hook the dialogue/NPC
## driver will replace — keep producing transcript turns via _append_line().
func _submit(raw: String) -> void:
	var line := raw.strip_edges()
	_input.clear()
	_input.grab_focus()
	if line.is_empty():
		return
	_append_line("[b]you:[/b] " + line, Color(0.85, 0.9, 0.95))
	# Placeholder "response". The real subsystem plugs in here.
	_append_line("[color=#8899aa]…(echo) " + line + "[/color]")


## Append one turn to the transcript. Central IO sink for the future subsystem.
func _append_line(bbcode: String, color: Color = Color(1, 1, 1)) -> void:
	_transcript.push_color(color)
	_transcript.append_text(bbcode)
	_transcript.pop()
	_transcript.newline()
