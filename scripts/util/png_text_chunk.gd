## PngTextChunk — minimal PNG tEXt-chunk encoder/decoder in pure GDScript.
##
## Godot's `Image.save_png()` produces a valid PNG byte stream but offers no way to
## attach metadata. The character-creator "PNG with history" export needs the body's
## edit-tree JSON to RIDE ALONG inside the image file so the PNG round-trips back into
## an editable history. The PNG spec lets ancillary `tEXt` chunks carry arbitrary
## keyword/text pairs; viewers ignore them, but we can read ours back.
##
## This post-processes the PackedByteArray Godot hands us:
##   embed(): splice a correctly-framed tEXt chunk in BEFORE the terminal IEND chunk.
##   extract(): scan the chunk list for our keyword and return its text payload.
##
## A PNG chunk is: [length:u32 BE][type:4 bytes][data:length bytes][crc32:u32 BE],
## where the CRC is computed over (type + data). A tEXt chunk's data is
## `keyword\0text` (Latin-1). We keep it pure/deterministic — no engine image deps.
class_name PngTextChunk
extends RefCounted

## The number of bytes in the PNG signature every valid PNG begins with
## (137 80 78 71 13 10 26 10). PackedByteArray can't be a GDScript `const`, so we
## hard-code the length and skip past it positionally.
const SIGNATURE_LEN := 8


## Embed `text` under `keyword` as a tEXt chunk, inserted just before IEND.
## Returns the new PNG bytes (the input is not mutated). Returns the input unchanged
## if it is not a recognizable PNG (no IEND found).
static func embed(png: PackedByteArray, keyword: String, text: String) -> PackedByteArray:
	var iend_pos := _find_chunk_start(png, "IEND")
	if iend_pos < 0:
		return png  # not a PNG we understand; leave it alone
	var chunk := _build_text_chunk(keyword, text)
	var out := PackedByteArray()
	out.append_array(png.slice(0, iend_pos))
	out.append_array(chunk)
	out.append_array(png.slice(iend_pos))
	return out


## Extract the text payload of the first tEXt chunk whose keyword matches.
## Returns "" if not present (caller treats empty as "no embedded history").
static func extract(png: PackedByteArray, keyword: String) -> String:
	var n := png.size()
	# Skip the 8-byte signature, then walk chunks.
	var pos := SIGNATURE_LEN
	while pos + 8 <= n:
		var length := _read_u32_be(png, pos)
		var ctype := _read_ascii(png, pos + 4, 4)
		var data_start := pos + 8
		if ctype == "tEXt":
			var data := png.slice(data_start, data_start + length)
			var sep := data.find(0)
			if sep >= 0:
				var kw := data.slice(0, sep).get_string_from_ascii()
				if kw == keyword:
					return data.slice(sep + 1, data.size()).get_string_from_utf8()
		# advance past data + 4-byte crc
		pos = data_start + length + 4
	return ""


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

static func _build_text_chunk(keyword: String, text: String) -> PackedByteArray:
	var data := PackedByteArray()
	data.append_array(keyword.to_ascii_buffer())
	data.append(0)  # null separator
	data.append_array(text.to_utf8_buffer())
	var type_bytes := "tEXt".to_ascii_buffer()
	var crc_input := PackedByteArray()
	crc_input.append_array(type_bytes)
	crc_input.append_array(data)
	var out := PackedByteArray()
	_append_u32_be(out, data.size())
	out.append_array(type_bytes)
	out.append_array(data)
	_append_u32_be(out, crc32(crc_input))
	return out


## Find the byte offset of the START (length field) of the first chunk of `ctype`.
static func _find_chunk_start(png: PackedByteArray, ctype: String) -> int:
	var n := png.size()
	var pos := SIGNATURE_LEN
	while pos + 8 <= n:
		var length := _read_u32_be(png, pos)
		var this_type := _read_ascii(png, pos + 4, 4)
		if this_type == ctype:
			return pos
		pos = pos + 8 + length + 4
	return -1


static func _read_u32_be(b: PackedByteArray, at: int) -> int:
	return (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3]


static func _append_u32_be(b: PackedByteArray, v: int) -> void:
	b.append((v >> 24) & 0xFF)
	b.append((v >> 16) & 0xFF)
	b.append((v >> 8) & 0xFF)
	b.append(v & 0xFF)


static func _read_ascii(b: PackedByteArray, at: int, length: int) -> String:
	return b.slice(at, at + length).get_string_from_ascii()


# ---------------------------------------------------------------------------
# CRC-32 (ISO 3309 / PNG) — the standard reflected CRC with polynomial 0xEDB88320.
# Computed fresh (no table cache needed for our small payloads, but we build a
# static table once for correctness + speed). Deterministic, pure.
# ---------------------------------------------------------------------------

static var _crc_table: PackedInt64Array = PackedInt64Array()


static func _crc_table_ref() -> PackedInt64Array:
	if _crc_table.is_empty():
		_crc_table = _build_crc_table()
	return _crc_table


static func _build_crc_table() -> PackedInt64Array:
	var table := PackedInt64Array()
	table.resize(256)
	for n in 256:
		var c := n
		for _k in 8:
			if c & 1:
				c = 0xEDB88320 ^ (c >> 1)
			else:
				c = c >> 1
		table[n] = c & 0xFFFFFFFF
	return table


static func crc32(bytes: PackedByteArray) -> int:
	var table := _crc_table_ref()
	var c := 0xFFFFFFFF
	for b in bytes:
		c = table[(c ^ b) & 0xFF] ^ (c >> 8)
		c = c & 0xFFFFFFFF
	return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF
