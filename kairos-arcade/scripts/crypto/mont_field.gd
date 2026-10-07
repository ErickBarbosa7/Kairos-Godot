class_name MontField
extends RefCounted
## Aritmética modular de 256 bits con multiplicación de Montgomery.
## Los números son PackedInt64Array de 11 limbs de 24 bits (el menos significativo primero).
## Solo necesita sumar, restar y multiplicar: no hace falta dividir.

const LIMBS := 11
const BITS := 24
const MASK := (1 << BITS) - 1

var m: PackedInt64Array
var one: PackedInt64Array  # 1 en forma de Montgomery (R mod m)
var _r2: PackedInt64Array
var _n0inv: int
var _exp_inv: PackedByteArray  # m - 2, para la inversa por Fermat


func _init(modulus: PackedByteArray) -> void:
	m = from_bytes(modulus)
	var inv := 1
	for i in 6:
		var t := (m[0] * inv) & MASK
		t = (2 - t) & MASK
		inv = (inv * t) & MASK
	_n0inv = (MASK + 1 - inv) & MASK
	var x := PackedInt64Array()
	x.resize(LIMBS)
	x[0] = 1
	for i in 2 * LIMBS * BITS:
		x = add(x, x)
		if i == LIMBS * BITS - 1:
			one = x.duplicate()
	_r2 = x
	_exp_inv = modulus.duplicate()
	_exp_inv[_exp_inv.size() - 1] -= 2


static func from_bytes(bytes: PackedByteArray) -> PackedInt64Array:
	var out := PackedInt64Array()
	out.resize(LIMBS)
	var acc := 0
	var bits := 0
	var idx := 0
	for i in range(bytes.size() - 1, -1, -1):
		acc |= bytes[i] << bits
		bits += 8
		while bits >= BITS:
			out[idx] = acc & MASK
			acc >>= BITS
			bits -= BITS
			idx += 1
	if bits > 0 and idx < LIMBS:
		out[idx] = acc
	return out


static func to_bytes(a: PackedInt64Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(32)
	var acc := 0
	var bits := 0
	var pos := 31
	for limb in a:
		acc |= limb << bits
		bits += BITS
		while bits >= 8 and pos >= 0:
			out[pos] = acc & 0xFF
			acc >>= 8
			bits -= 8
			pos -= 1
	return out


static func is_zero(a: PackedInt64Array) -> bool:
	for limb in a:
		if limb != 0:
			return false
	return true


static func ge(a: PackedInt64Array, b: PackedInt64Array) -> bool:
	for i in range(LIMBS - 1, -1, -1):
		if a[i] != b[i]:
			return a[i] > b[i]
	return true


static func _sub_in_place(a: PackedInt64Array, b: PackedInt64Array) -> void:
	var borrow := 0
	for i in LIMBS:
		var d := a[i] - b[i] - borrow
		if d < 0:
			d += MASK + 1
			borrow = 1
		else:
			borrow = 0
		a[i] = d


## Resta m si el valor es >= m. Para valores menores que 2m.
func reduce_once(a: PackedInt64Array) -> PackedInt64Array:
	var out := a.duplicate()
	if ge(out, m):
		_sub_in_place(out, m)
	return out


func add(a: PackedInt64Array, b: PackedInt64Array) -> PackedInt64Array:
	var out := PackedInt64Array()
	out.resize(LIMBS)
	var carry := 0
	for i in LIMBS:
		var s := a[i] + b[i] + carry
		out[i] = s & MASK
		carry = s >> BITS
	if ge(out, m):
		_sub_in_place(out, m)
	return out


func sub(a: PackedInt64Array, b: PackedInt64Array) -> PackedInt64Array:
	var out := PackedInt64Array()
	out.resize(LIMBS)
	var borrow := 0
	for i in LIMBS:
		var d := a[i] - b[i] - borrow
		if d < 0:
			d += MASK + 1
			borrow = 1
		else:
			borrow = 0
		out[i] = d
	if borrow:
		var carry := 0
		for i in LIMBS:
			var s := out[i] + m[i] + carry
			out[i] = s & MASK
			carry = s >> BITS
	return out


## Multiplicación de Montgomery (CIOS): a * b * R^-1 mod m.
func mul(a: PackedInt64Array, b: PackedInt64Array) -> PackedInt64Array:
	var t := PackedInt64Array()
	t.resize(LIMBS + 2)
	for i in LIMBS:
		var bi := b[i]
		var carry := 0
		for j in LIMBS:
			var s := t[j] + a[j] * bi + carry
			t[j] = s & MASK
			carry = s >> BITS
		var s2 := t[LIMBS] + carry
		t[LIMBS] = s2 & MASK
		t[LIMBS + 1] = s2 >> BITS
		var mi := (t[0] * _n0inv) & MASK
		carry = (t[0] + mi * m[0]) >> BITS
		for j in range(1, LIMBS):
			var s3 := t[j] + mi * m[j] + carry
			t[j - 1] = s3 & MASK
			carry = s3 >> BITS
		var s4 := t[LIMBS] + carry
		t[LIMBS - 1] = s4 & MASK
		t[LIMBS] = t[LIMBS + 1] + (s4 >> BITS)
	var out := PackedInt64Array()
	out.resize(LIMBS)
	for i in LIMBS:
		out[i] = t[i]
	if t[LIMBS] != 0 or ge(out, m):
		_sub_in_place(out, m)
	return out


func sq(a: PackedInt64Array) -> PackedInt64Array:
	return mul(a, a)


func to_mont(a: PackedInt64Array) -> PackedInt64Array:
	return mul(a, _r2)


func from_mont(a: PackedInt64Array) -> PackedInt64Array:
	var unit := PackedInt64Array()
	unit.resize(LIMBS)
	unit[0] = 1
	return mul(a, unit)


## Potencia con exponente en bytes (grande-endian). Base y resultado en forma de Montgomery.
func pow_mont(base: PackedInt64Array, exponent: PackedByteArray) -> PackedInt64Array:
	var result := one.duplicate()
	for byte in exponent:
		for bit in range(7, -1, -1):
			result = mul(result, result)
			if (byte >> bit) & 1:
				result = mul(result, base)
	return result


## Inversa multiplicativa (el módulo es primo). Entrada y salida en forma de Montgomery.
func inv(a: PackedInt64Array) -> PackedInt64Array:
	return pow_mont(a, _exp_inv)
