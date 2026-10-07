class_name QrCode
extends RefCounted
## Generador de códigos QR (modo byte, versiones 1 a 40). Sin dependencias.
## Algoritmo estándar: codificación, Reed-Solomon, entrelazado, patrones de función,
## colocación en zigzag y elección de la máscara con menor penalización.

enum Ecc { LOW, MEDIUM, QUARTILE, HIGH }

const FORMAT_BITS := [1, 0, 3, 2]
const ECC_PER_BLOCK := [
	[-1, 7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28, 28, 28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
	[-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28],
	[-1, 13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26, 30, 28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
	[-1, 17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28, 26, 28, 30, 24, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
]
const NUM_BLOCKS := [
	[-1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8, 8, 9, 9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25],
	[-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49],
	[-1, 1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21, 20, 23, 23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, 62, 65, 68],
	[-1, 1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25, 25, 34, 30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, 74, 77, 81],
]

var version: int
var size: int
var ecc: int
var mask: int = -1
var _modules: PackedByteArray
var _is_function: PackedByteArray


## Codifica el texto en el QR más pequeño que lo contenga con ese nivel de corrección.
## Devuelve null si no cabe (más de ~2900 bytes).
static func encode_text(text: String, level: int = Ecc.MEDIUM) -> QrCode:
	var data := text.to_utf8_buffer()
	var ver := 1
	while ver <= 40:
		var capacity := _num_data_codewords(ver, level) * 8
		var count_bits := 8 if ver <= 9 else 16
		if 4 + count_bits + data.size() * 8 <= capacity:
			break
		ver += 1
	if ver > 40:
		return null

	var bits := PackedByteArray()
	_append_bits(bits, 0x4, 4)
	_append_bits(bits, data.size(), 8 if ver <= 9 else 16)
	for b in data:
		_append_bits(bits, b, 8)
	var capacity_bits := _num_data_codewords(ver, level) * 8
	_append_bits(bits, 0, mini(4, capacity_bits - bits.size()))
	_append_bits(bits, 0, (8 - bits.size() % 8) % 8)
	var pad := 0xEC
	while bits.size() < capacity_bits:
		_append_bits(bits, pad, 8)
		pad ^= 0xEC ^ 0x11

	var codewords := PackedByteArray()
	codewords.resize(bits.size() / 8)
	for i in bits.size():
		codewords[i >> 3] |= bits[i] << (7 - (i & 7))
	return QrCode.new(ver, level, codewords)


func _init(ver: int, level: int, data_codewords: PackedByteArray) -> void:
	version = ver
	ecc = level
	size = ver * 4 + 17
	_modules = PackedByteArray()
	_modules.resize(size * size)
	_is_function = PackedByteArray()
	_is_function.resize(size * size)
	_draw_function_patterns()
	_draw_codewords(_add_ecc_and_interleave(data_codewords))

	var best_mask := 0
	var best_penalty := 1 << 30
	for m in 8:
		_apply_mask(m)
		_draw_format_bits(m)
		var penalty := _penalty_score()
		if penalty < best_penalty:
			best_penalty = penalty
			best_mask = m
		_apply_mask(m)
	mask = best_mask
	_apply_mask(best_mask)
	_draw_format_bits(best_mask)


func get_module(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size and y < size and _modules[y * size + x] == 1


## Imagen en blanco y negro con zona silenciosa de `border` módulos y `scale` píxeles por módulo.
func to_image(scale: int, border: int = 4) -> Image:
	var px := (size + border * 2) * scale
	var image := Image.create(px, px, false, Image.FORMAT_L8)
	image.fill(Color.WHITE)
	for y in size:
		for x in size:
			if _modules[y * size + x] == 1:
				image.fill_rect(Rect2i((x + border) * scale, (y + border) * scale, scale, scale), Color.BLACK)
	return image


# --- Codificación -----------------------------------------------------------

static func _append_bits(bits: PackedByteArray, value: int, count: int) -> void:
	for i in range(count - 1, -1, -1):
		bits.append((value >> i) & 1)


static func _num_raw_data_modules(ver: int) -> int:
	var result := (16 * ver + 128) * ver + 64
	if ver >= 2:
		var num_align := ver / 7 + 2
		result -= (25 * num_align - 10) * num_align - 55
		if ver >= 7:
			result -= 36
	return result


static func _num_data_codewords(ver: int, level: int) -> int:
	return _num_raw_data_modules(ver) / 8 - ECC_PER_BLOCK[level][ver] * NUM_BLOCKS[level][ver]


static func _gf_mul(x: int, y: int) -> int:
	var z := 0
	for i in range(7, -1, -1):
		z = (z << 1) ^ ((z >> 7) * 0x11D)
		z ^= ((y >> i) & 1) * x
	return z


static func _rs_divisor(degree: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(degree)
	result[degree - 1] = 1
	var root := 1
	for i in degree:
		for j in degree:
			result[j] = _gf_mul(result[j], root)
			if j + 1 < degree:
				result[j] ^= result[j + 1]
		root = _gf_mul(root, 0x02)
	return result


static func _rs_remainder(data: PackedByteArray, divisor: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(divisor.size())
	for b in data:
		var factor := b ^ result[0]
		result.remove_at(0)
		result.append(0)
		for i in divisor.size():
			result[i] ^= _gf_mul(divisor[i], factor)
	return result


func _add_ecc_and_interleave(data: PackedByteArray) -> PackedByteArray:
	var num_blocks: int = NUM_BLOCKS[ecc][version]
	var block_ecc_len: int = ECC_PER_BLOCK[ecc][version]
	var raw_codewords := _num_raw_data_modules(version) / 8
	var num_short := num_blocks - raw_codewords % num_blocks
	var short_len := raw_codewords / num_blocks
	var divisor := _rs_divisor(block_ecc_len)
	var blocks: Array[PackedByteArray] = []
	var k := 0
	for i in num_blocks:
		var dat_len := short_len - block_ecc_len + (0 if i < num_short else 1)
		var dat := data.slice(k, k + dat_len)
		k += dat_len
		var ecc_bytes := _rs_remainder(dat, divisor)
		if i < num_short:
			dat.append(0)
		blocks.append(dat + ecc_bytes)
	var result := PackedByteArray()
	for i in blocks[0].size():
		for j in num_blocks:
			if i != short_len - block_ecc_len or j >= num_short:
				result.append(blocks[j][i])
	return result


# --- Patrones de función ----------------------------------------------------

func _set_function(x: int, y: int, dark: bool) -> void:
	_modules[y * size + x] = 1 if dark else 0
	_is_function[y * size + x] = 1


func _alignment_positions() -> PackedInt32Array:
	var result := PackedInt32Array()
	if version == 1:
		return result
	var num_align := version / 7 + 2
	var step := 26 if version == 32 else (version * 8 + num_align * 3 + 5) / (num_align * 4 - 4) * 2
	var positions: Array[int] = [6]
	var pos := size - 7
	var tail: Array[int] = []
	while tail.size() < num_align - 1:
		tail.push_front(pos)
		pos -= step
	positions.append_array(tail)
	result.append_array(PackedInt32Array(positions))
	return result


func _draw_function_patterns() -> void:
	for i in size:
		_set_function(6, i, i % 2 == 0)
		_set_function(i, 6, i % 2 == 0)
	_draw_finder(3, 3)
	_draw_finder(size - 4, 3)
	_draw_finder(3, size - 4)
	var pos := _alignment_positions()
	var n := pos.size()
	for i in n:
		for j in n:
			if not ((i == 0 and j == 0) or (i == 0 and j == n - 1) or (i == n - 1 and j == 0)):
				_draw_alignment(pos[i], pos[j])
	_draw_format_bits(0)
	_draw_version()


func _draw_finder(cx: int, cy: int) -> void:
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var dist := maxi(absi(dx), absi(dy))
			var x := cx + dx
			var y := cy + dy
			if x >= 0 and x < size and y >= 0 and y < size:
				_set_function(x, y, dist != 2 and dist != 4)


func _draw_alignment(cx: int, cy: int) -> void:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			_set_function(cx + dx, cy + dy, maxi(absi(dx), absi(dy)) != 1)


func _draw_format_bits(m: int) -> void:
	var data: int = (FORMAT_BITS[ecc] << 3) | m
	var rem := data
	for i in 10:
		rem = (rem << 1) ^ ((rem >> 9) * 0x537)
	var bits := ((data << 10) | rem) ^ 0x5412
	for i in range(0, 6):
		_set_function(8, i, ((bits >> i) & 1) == 1)
	_set_function(8, 7, ((bits >> 6) & 1) == 1)
	_set_function(8, 8, ((bits >> 7) & 1) == 1)
	_set_function(7, 8, ((bits >> 8) & 1) == 1)
	for i in range(9, 15):
		_set_function(14 - i, 8, ((bits >> i) & 1) == 1)
	for i in range(0, 8):
		_set_function(size - 1 - i, 8, ((bits >> i) & 1) == 1)
	for i in range(8, 15):
		_set_function(8, size - 15 + i, ((bits >> i) & 1) == 1)
	_set_function(8, size - 8, true)


func _draw_version() -> void:
	if version < 7:
		return
	var rem := version
	for i in 12:
		rem = (rem << 1) ^ ((rem >> 11) * 0x1F25)
	var bits := (version << 12) | rem
	for i in 18:
		var dark := ((bits >> i) & 1) == 1
		var a := size - 11 + i % 3
		var b := i / 3
		_set_function(a, b, dark)
		_set_function(b, a, dark)


func _draw_codewords(data: PackedByteArray) -> void:
	var i := 0
	var right := size - 1
	while right >= 1:
		if right == 6:
			right = 5
		for vert in size:
			for j in 2:
				var x := right - j
				var upward := ((right + 1) & 2) == 0
				var y := size - 1 - vert if upward else vert
				if _is_function[y * size + x] == 0 and i < data.size() * 8:
					_modules[y * size + x] = (data[i >> 3] >> (7 - (i & 7))) & 1
					i += 1
		right -= 2


func _apply_mask(m: int) -> void:
	for y in size:
		for x in size:
			var invert := false
			match m:
				0: invert = (x + y) % 2 == 0
				1: invert = y % 2 == 0
				2: invert = x % 3 == 0
				3: invert = (x + y) % 3 == 0
				4: invert = (x / 3 + y / 2) % 2 == 0
				5: invert = x * y % 2 + x * y % 3 == 0
				6: invert = (x * y % 2 + x * y % 3) % 2 == 0
				7: invert = ((x + y) % 2 + x * y % 3) % 2 == 0
			if invert and _is_function[y * size + x] == 0:
				_modules[y * size + x] ^= 1


# --- Penalización de máscaras -----------------------------------------------

func _penalty_score() -> int:
	var result := 0
	for y in size:
		var run_color := 0
		var run_len := 0
		var history := [0, 0, 0, 0, 0, 0, 0]
		for x in size:
			var c := _modules[y * size + x]
			if c == run_color:
				run_len += 1
				if run_len == 5:
					result += 3
				elif run_len > 5:
					result += 1
			else:
				_history_add(run_len, history)
				if run_color == 0:
					result += _count_patterns(history) * 40
				run_color = c
				run_len = 1
		result += _terminate_and_count(run_color, run_len, history) * 40
	for x in size:
		var run_color := 0
		var run_len := 0
		var history := [0, 0, 0, 0, 0, 0, 0]
		for y in size:
			var c := _modules[y * size + x]
			if c == run_color:
				run_len += 1
				if run_len == 5:
					result += 3
				elif run_len > 5:
					result += 1
			else:
				_history_add(run_len, history)
				if run_color == 0:
					result += _count_patterns(history) * 40
				run_color = c
				run_len = 1
		result += _terminate_and_count(run_color, run_len, history) * 40
	for y in size - 1:
		for x in size - 1:
			var c := _modules[y * size + x]
			if c == _modules[y * size + x + 1] and c == _modules[(y + 1) * size + x] and c == _modules[(y + 1) * size + x + 1]:
				result += 3
	var dark := 0
	for v in _modules:
		dark += v
	var total := size * size
	var k := (absi(dark * 20 - total * 10) + total - 1) / total - 1
	result += k * 10
	return result


func _count_patterns(history: Array) -> int:
	var n: int = history[1]
	var core: bool = n > 0 and history[2] == n and history[3] == n * 3 and history[4] == n and history[5] == n
	var count := 0
	if core and history[0] >= n * 4 and history[6] >= n:
		count += 1
	if core and history[6] >= n * 4 and history[0] >= n:
		count += 1
	return count


func _terminate_and_count(run_color: int, run_len: int, history: Array) -> int:
	if run_color == 1:
		_history_add(run_len, history)
		run_len = 0
	run_len += size
	_history_add(run_len, history)
	return _count_patterns(history)


func _history_add(run_len: int, history: Array) -> void:
	if history[0] == 0:
		run_len += size
	history.pop_back()
	history.push_front(run_len)
