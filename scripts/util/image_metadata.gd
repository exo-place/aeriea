## ImageMetadata — format-aware "embed a keyword/text payload into image bytes" so the
## character creator's IMAGE+HISTORY export round-trips for every image format we ship,
## not just PNG. The creator embeds the edit-history JSON so a saved picture re-imports
## back into an editable HistoryTree (DESIGN.md "lived history" / data-over-code at the
## seam — the artifact carries its own provenance).
##
## Three carriers, one interface (embed/extract over PackedByteArray, pure + deterministic):
##   - PNG  — an ancillary `tEXt` chunk (delegates to PngTextChunk; viewers ignore it).
##   - JPEG — a COM (comment, 0xFFFE) marker segment carrying `keyword\0text`, spliced
##            right after the SOI marker. JPEG comment segments are arbitrary and ignored
##            by decoders, so the image stays valid.
##   - WEBP — a custom RIFF chunk (fourcc "aeRH") appended before the RIFF stream end,
##            with the container's RIFF size field fixed up. Unknown chunks are skipped by
##            WebP decoders per the RIFF/WebP spec, so the image stays valid.
##
## supports_metadata(format) reports HONESTLY whether a format can carry the payload, so
## the UI can disable IMAGE+HISTORY for any format it can't embed rather than silently drop
## the history. (All three listed formats CAN — this is the seam if a new one can't.)
class_name ImageMetadata
extends RefCounted

const PngTextChunkScript := preload("res://scripts/util/png_text_chunk.gd")

## Canonical format keys (lowercase extensionless).
const FORMAT_PNG := "png"
const FORMAT_JPG := "jpg"
const FORMAT_WEBP := "webp"

## The WebP custom-chunk FourCC our payload rides under. Lowercase first letter marks it
## as an ancillary/optional chunk; FourCCs are 4 ASCII bytes.
const WEBP_FOURCC := "aeRH"


## True iff `format` (one of the FORMAT_* keys) can carry embedded metadata via this module.
## Drives the UI's honest enable/disable of IMAGE+HISTORY per format.
static func supports_metadata(format: String) -> bool:
	return format == FORMAT_PNG or format == FORMAT_JPG or format == FORMAT_WEBP


## Encode `img` to `format`'s byte stream (no metadata). Returns empty on an unknown format
## or an encode failure.
static func encode(img: Image, format: String) -> PackedByteArray:
	match format:
		FORMAT_PNG:
			return img.save_png_to_buffer()
		FORMAT_JPG:
			return img.save_jpg_to_buffer()
		FORMAT_WEBP:
			# Lossless WebP so the round-tripped image is exact (and metadata-only edits
			# don't compound lossy artifacts on re-export).
			return img.save_webp_to_buffer(false)
		_:
			return PackedByteArray()


## Embed `text` under `keyword` into `bytes` for the given `format`. Returns the input
## unchanged if the format can't carry metadata or the bytes aren't a recognizable file.
static func embed(bytes: PackedByteArray, format: String, keyword: String, text: String) -> PackedByteArray:
	match format:
		FORMAT_PNG:
			return PngTextChunkScript.embed(bytes, keyword, text)
		FORMAT_JPG:
			return _jpg_embed(bytes, keyword, text)
		FORMAT_WEBP:
			return _webp_embed(bytes, keyword, text)
		_:
			return bytes


## Extract the payload stored under `keyword` for `format`. Returns "" if absent.
static func extract(bytes: PackedByteArray, format: String, keyword: String) -> String:
	match format:
		FORMAT_PNG:
			return PngTextChunkScript.extract(bytes, keyword)
		FORMAT_JPG:
			return _jpg_extract(bytes, keyword)
		FORMAT_WEBP:
			return _webp_extract(bytes, keyword)
		_:
			return ""


# ---------------------------------------------------------------------------
# JPEG — COM (0xFFFE) marker segment carrying `keyword\0text`.
# A JPEG stream is SOI (FF D8) then a sequence of marker segments. A COM segment is
# FF FE <length:u16 BE, INCLUDING the 2 length bytes> <payload>. We splice ours right
# after SOI so it's the first segment, then the original rest follows.
# ---------------------------------------------------------------------------

static func _jpg_embed(jpg: PackedByteArray, keyword: String, text: String) -> PackedByteArray:
	# Validate SOI.
	if jpg.size() < 2 or jpg[0] != 0xFF or jpg[1] != 0xD8:
		return jpg
	var payload := PackedByteArray()
	payload.append_array(keyword.to_ascii_buffer())
	payload.append(0)
	payload.append_array(text.to_utf8_buffer())
	# Segment length field counts itself (2) + payload, and must fit in a u16.
	var seg_len := payload.size() + 2
	if seg_len > 0xFFFF:
		return jpg  # too large for one COM segment; caller should disable image+history
	var out := PackedByteArray()
	out.append(0xFF); out.append(0xD8)          # SOI
	out.append(0xFF); out.append(0xFE)          # COM marker
	out.append((seg_len >> 8) & 0xFF)
	out.append(seg_len & 0xFF)
	out.append_array(payload)
	out.append_array(jpg.slice(2))              # the rest of the original stream
	return out


static func _jpg_extract(jpg: PackedByteArray, keyword: String) -> String:
	var n := jpg.size()
	if n < 2 or jpg[0] != 0xFF or jpg[1] != 0xD8:
		return ""
	var pos := 2
	var kw_bytes := keyword.to_ascii_buffer()
	while pos + 4 <= n:
		if jpg[pos] != 0xFF:
			pos += 1
			continue
		var marker := jpg[pos + 1]
		# SOS (FF DA) begins entropy-coded scan data; stop scanning markers.
		if marker == 0xDA or marker == 0xD9:
			break
		# Standalone markers (RSTn, TEM) have no length; skip the marker only.
		if (marker >= 0xD0 and marker <= 0xD7) or marker == 0x01 or marker == 0xFF:
			pos += 2
			continue
		var seg_len := (jpg[pos + 2] << 8) | jpg[pos + 3]
		var data_start := pos + 4
		var data_end := pos + 2 + seg_len
		if marker == 0xFE:  # COM
			var data := jpg.slice(data_start, data_end)
			var sep := data.find(0)
			if sep == kw_bytes.size() and data.slice(0, sep) == kw_bytes:
				return data.slice(sep + 1, data.size()).get_string_from_utf8()
		pos = data_end
	return ""


# ---------------------------------------------------------------------------
# WEBP — a custom RIFF chunk. Container: "RIFF" <file_size:u32 LE> "WEBP" <chunks...>,
# where file_size counts everything AFTER the file_size field (i.e. from "WEBP" on). Each
# chunk is <fourcc:4> <size:u32 LE> <data> <pad-to-even>. We append our chunk after the
# last existing chunk and bump file_size. Unknown chunks are skipped by decoders.
# ---------------------------------------------------------------------------

static func _webp_embed(webp: PackedByteArray, keyword: String, text: String) -> PackedByteArray:
	if webp.size() < 12 or webp.slice(0, 4).get_string_from_ascii() != "RIFF" \
			or webp.slice(8, 12).get_string_from_ascii() != "WEBP":
		return webp
	var payload := PackedByteArray()
	payload.append_array(keyword.to_ascii_buffer())
	payload.append(0)
	payload.append_array(text.to_utf8_buffer())
	# Build the custom chunk: fourcc + size(LE) + data + even-pad byte.
	var chunk := PackedByteArray()
	chunk.append_array(WEBP_FOURCC.to_ascii_buffer())
	_append_u32_le(chunk, payload.size())
	chunk.append_array(payload)
	if payload.size() % 2 == 1:
		chunk.append(0)  # RIFF chunks pad to an even byte boundary
	# Append the chunk and fix the RIFF file-size field (bytes 4..8, LE).
	var out := webp.duplicate()
	out.append_array(chunk)
	var new_riff_size := out.size() - 8
	out[4] = new_riff_size & 0xFF
	out[5] = (new_riff_size >> 8) & 0xFF
	out[6] = (new_riff_size >> 16) & 0xFF
	out[7] = (new_riff_size >> 24) & 0xFF
	return out


static func _webp_extract(webp: PackedByteArray, keyword: String) -> String:
	var n := webp.size()
	if n < 12 or webp.slice(0, 4).get_string_from_ascii() != "RIFF" \
			or webp.slice(8, 12).get_string_from_ascii() != "WEBP":
		return ""
	var kw_bytes := keyword.to_ascii_buffer()
	var pos := 12
	while pos + 8 <= n:
		var fourcc := webp.slice(pos, pos + 4).get_string_from_ascii()
		var size := _read_u32_le(webp, pos + 4)
		var data_start := pos + 8
		if fourcc == WEBP_FOURCC:
			var data := webp.slice(data_start, data_start + size)
			var sep := data.find(0)
			if sep == kw_bytes.size() and data.slice(0, sep) == kw_bytes:
				return data.slice(sep + 1, data.size()).get_string_from_utf8()
		# Advance past data + even-pad.
		var advance := size + (size % 2)
		pos = data_start + advance
	return ""


static func _append_u32_le(b: PackedByteArray, v: int) -> void:
	b.append(v & 0xFF)
	b.append((v >> 8) & 0xFF)
	b.append((v >> 16) & 0xFF)
	b.append((v >> 24) & 0xFF)


static func _read_u32_le(b: PackedByteArray, at: int) -> int:
	return b[at] | (b[at + 1] << 8) | (b[at + 2] << 16) | (b[at + 3] << 24)
