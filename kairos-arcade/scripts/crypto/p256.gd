class_name P256
extends RefCounted
## Curva NIST P-256: solo lo necesario para firmar (multiplicar el punto base por un escalar).
## Puntos en coordenadas Jacobianas, con los números en forma de Montgomery.

const P_HEX := "FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF"
const N_HEX := "FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551"
const GX_HEX := "6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296"
const GY_HEX := "4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5"

static var _fp: MontField
static var _fn: MontField
static var _gx: PackedInt64Array
static var _gy: PackedInt64Array


## Campo de las coordenadas (módulo p).
static func field_p() -> MontField:
	if _fp == null:
		_fp = MontField.new(P_HEX.hex_decode())
		_gx = _fp.to_mont(MontField.from_bytes(GX_HEX.hex_decode()))
		_gy = _fp.to_mont(MontField.from_bytes(GY_HEX.hex_decode()))
	return _fp


## Campo de los escalares (módulo n, el orden del grupo).
static func field_n() -> MontField:
	if _fn == null:
		_fn = MontField.new(N_HEX.hex_decode())
	return _fn


static func _double(f: MontField, p: Array) -> Array:
	var x: PackedInt64Array = p[0]
	var y: PackedInt64Array = p[1]
	var z: PackedInt64Array = p[2]
	var delta := f.sq(z)
	var gamma := f.sq(y)
	var beta := f.mul(x, gamma)
	var alpha := f.mul(f.sub(x, delta), f.add(x, delta))
	alpha = f.add(f.add(alpha, alpha), alpha)
	var beta2 := f.add(beta, beta)
	var beta4 := f.add(beta2, beta2)
	var beta8 := f.add(beta4, beta4)
	var x3 := f.sub(f.sq(alpha), beta8)
	var z3 := f.sub(f.sub(f.sq(f.add(y, z)), gamma), delta)
	var g2 := f.sq(gamma)
	var g4 := f.add(g2, g2)
	var g8 := f.add(f.add(g4, g4), f.add(g4, g4))
	var y3 := f.sub(f.mul(alpha, f.sub(beta4, x3)), g8)
	return [x3, y3, z3]


static func _add(f: MontField, p: Array, q: Array) -> Array:
	if MontField.is_zero(p[2]):
		return q
	if MontField.is_zero(q[2]):
		return p
	var z1z1 := f.sq(p[2])
	var z2z2 := f.sq(q[2])
	var u1 := f.mul(p[0], z2z2)
	var u2 := f.mul(q[0], z1z1)
	var s1 := f.mul(f.mul(p[1], q[2]), z2z2)
	var s2 := f.mul(f.mul(q[1], p[2]), z1z1)
	var h := f.sub(u2, u1)
	var r0 := f.sub(s2, s1)
	if MontField.is_zero(h):
		if MontField.is_zero(r0):
			return _double(f, p)
		return [f.one, f.one, PackedInt64Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])]
	var h2 := f.add(h, h)
	var i := f.sq(h2)
	var j := f.mul(h, i)
	var r := f.add(r0, r0)
	var v := f.mul(u1, i)
	var x3 := f.sub(f.sub(f.sq(r), j), f.add(v, v))
	var s1j := f.mul(s1, j)
	var y3 := f.sub(f.mul(r, f.sub(v, x3)), f.add(s1j, s1j))
	var zs := f.add(p[2], q[2])
	var z3 := f.mul(f.sub(f.sub(f.sq(zs), z1z1), z2z2), h)
	return [x3, y3, z3]


## k * G como [x, y], cada una de 32 bytes. k debe estar en 1..n-1.
static func base_mul(k: PackedByteArray) -> Array:
	var f := field_p()
	var g := [_gx, _gy, f.one]
	var acc := [f.one, f.one, PackedInt64Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])]
	for byte in k:
		for bit in range(7, -1, -1):
			acc = _double(f, acc)
			if (byte >> bit) & 1:
				acc = _add(f, acc, g)
	var zinv := f.inv(acc[2])
	var zinv2 := f.sq(zinv)
	var x := f.mul(acc[0], zinv2)
	var y := f.mul(acc[1], f.mul(zinv2, zinv))
	return [MontField.to_bytes(f.from_mont(x)), MontField.to_bytes(f.from_mont(y))]


## Coordenada x (como entero 32 bytes) de k * G.
static func base_mul_x(k: PackedByteArray) -> PackedByteArray:
	return base_mul(k)[0]
