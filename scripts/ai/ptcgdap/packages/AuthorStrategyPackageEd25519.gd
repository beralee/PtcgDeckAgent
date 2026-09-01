extends RefCounted

## Bounded, verification-only Ed25519 used by the .ptcgai metadata loader.
## Godot 4.6.1's CryptoKey cannot load Ed25519 SPKI keys, so this owner keeps
## the AS-WP1 signature contract without introducing a native/runtime plugin.

const LIMB_BITS := 15
const LIMB_BASE := 1 << LIMB_BITS
const LIMB_MASK := LIMB_BASE - 1
const MASK32 := 0xFFFFFFFF
const TWO32 := 4294967296

const SHA512_INITIAL := [
	"6A09E667F3BCC908", "BB67AE8584CAA73B", "3C6EF372FE94F82B", "A54FF53A5F1D36F1",
	"510E527FADE682D1", "9B05688C2B3E6C1F", "1F83D9ABFB41BD6B", "5BE0CD19137E2179",
]

const SHA512_ROUND := [
	"428A2F98D728AE22", "7137449123EF65CD", "B5C0FBCFEC4D3B2F", "E9B5DBA58189DBBC",
	"3956C25BF348B538", "59F111F1B605D019", "923F82A4AF194F9B", "AB1C5ED5DA6D8118",
	"D807AA98A3030242", "12835B0145706FBE", "243185BE4EE4B28C", "550C7DC3D5FFB4E2",
	"72BE5D74F27B896F", "80DEB1FE3B1696B1", "9BDC06A725C71235", "C19BF174CF692694",
	"E49B69C19EF14AD2", "EFBE4786384F25E3", "0FC19DC68B8CD5B5", "240CA1CC77AC9C65",
	"2DE92C6F592B0275", "4A7484AA6EA6E483", "5CB0A9DCBD41FBD4", "76F988DA831153B5",
	"983E5152EE66DFAB", "A831C66D2DB43210", "B00327C898FB213F", "BF597FC7BEEF0EE4",
	"C6E00BF33DA88FC2", "D5A79147930AA725", "06CA6351E003826F", "142929670A0E6E70",
	"27B70A8546D22FFC", "2E1B21385C26C926", "4D2C6DFC5AC42AED", "53380D139D95B3DF",
	"650A73548BAF63DE", "766A0ABB3C77B2A8", "81C2C92E47EDAEE6", "92722C851482353B",
	"A2BFE8A14CF10364", "A81A664BBC423001", "C24B8B70D0F89791", "C76C51A30654BE30",
	"D192E819D6EF5218", "D69906245565A910", "F40E35855771202A", "106AA07032BBD1B8",
	"19A4C116B8D2D0C8", "1E376C085141AB53", "2748774CDF8EEB99", "34B0BCB5E19B48A8",
	"391C0CB3C5C95A63", "4ED8AA4AE3418ACB", "5B9CCA4F7763E373", "682E6FF3D6B2B8A3",
	"748F82EE5DEFB2FC", "78A5636F43172F60", "84C87814A1F0AB72", "8CC702081A6439EC",
	"90BEFFFA23631E28", "A4506CEBDE82BDE9", "BEF9A3F7B2C67915", "C67178F2E372532B",
	"CA273ECEEA26619C", "D186B8C721C0C207", "EADA7DD6CDE0EB1E", "F57D4F7FEE6ED178",
	"06F067AA72176FBA", "0A637DC5A2C898A6", "113F9804BEF90DAE", "1B710B35131C471B",
	"28DB77F523047D84", "32CAAB7B40C72493", "3C9EBE0A15C9BEBC", "431D67C49C100D4C",
	"4CC5D4BECB3E42B6", "597F299CFC657E2A", "5FCB6FAB3AD6FAEC", "6C44198C4A475817",
]

const FIELD_D_DECIMAL := "37095705934669439343138083508754565189542113879843219016388785533085940283555"
const FIELD_SQRT_M1_DECIMAL := "19681161376707505956807079304988542015446066515923890162744021073123829784752"
const BASE_X_DECIMAL := "15112221349535400772501151409588531511454012693041857206046113283949847762202"
const BASE_Y_DECIMAL := "46316835694926478169428394003475163141307993866256225615783033603165251855960"
const SCALAR_L_DECIMAL := "7237005577332262213973186563042994240857116359379907606001950938285454250989"


static func verify(public_key: PackedByteArray, message: PackedByteArray, signature: PackedByteArray) -> bool:
	if public_key.size() != 32 or signature.size() != 64:
		return false
	var encoded_r := signature.slice(0, 32)
	var encoded_s := signature.slice(32, 64)
	var scalar_l := _from_decimal(SCALAR_L_DECIMAL)
	var scalar_s := _from_little_bytes(encoded_s)
	if _compare(scalar_s, scalar_l) >= 0:
		return false
	var point_a = _decode_point(public_key)
	var point_r = _decode_point(encoded_r)
	if point_a == null or point_r == null:
		return false
	var hash_input := PackedByteArray()
	hash_input.append_array(encoded_r)
	hash_input.append_array(public_key)
	hash_input.append_array(message)
	var h_scalar := _reduce_scalar(_sha512(hash_input), scalar_l)
	var base_point := _point_from_affine(_from_decimal(BASE_X_DECIMAL), _from_decimal(BASE_Y_DECIMAL))
	var left := _point_scalar_mul(base_point, scalar_s)
	var right := _point_add(point_r, _point_scalar_mul(point_a, h_scalar))
	return _point_equal(left, right)


static func sha512_for_test(value: PackedByteArray) -> PackedByteArray:
	return _sha512(value)


static func _p() -> Array:
	var result := []
	result.resize(17)
	result[0] = LIMB_BASE - 19
	for index in range(1, 17):
		result[index] = LIMB_MASK
	return result


static func _zero() -> Array:
	var result := []
	result.resize(17)
	result.fill(0)
	return result


static func _one() -> Array:
	var result := _zero()
	result[0] = 1
	return result


static func _copy_limbs(value: Array) -> Array:
	var result := []
	result.assign(value)
	return result


static func _trim(value: Array) -> Array:
	while value.size() > 1 and value[-1] == 0:
		value.pop_back()
	return value


static func _normalize(value: Array) -> Array:
	var index := 0
	while index < value.size():
		var carry: int = int(value[index]) >> LIMB_BITS
		value[index] = int(value[index]) & LIMB_MASK
		if carry > 0:
			if index + 1 == value.size():
				value.append(carry)
			else:
				value[index + 1] = int(value[index + 1]) + carry
		index += 1
	return _trim(value)


static func _compare(a: Array, b: Array) -> int:
	var aa := _trim(_copy_limbs(a))
	var bb := _trim(_copy_limbs(b))
	if aa.size() != bb.size():
		return -1 if aa.size() < bb.size() else 1
	for index in range(aa.size() - 1, -1, -1):
		if aa[index] != bb[index]:
			return -1 if aa[index] < bb[index] else 1
	return 0


static func _subtract_positive(a: Array, b: Array) -> Array:
	var result := _copy_limbs(a)
	var borrow := 0
	for index in range(result.size()):
		var subtrahend: int = (int(b[index]) if index < b.size() else 0) + borrow
		var current: int = int(result[index]) - subtrahend
		if current < 0:
			current += LIMB_BASE
			borrow = 1
		else:
			borrow = 0
		result[index] = current
	return _trim(result)


static func _field_reduce(value: Array) -> Array:
	var result := _normalize(_copy_limbs(value))
	while result.size() > 17:
		var folded := _zero()
		for index in range(min(17, result.size())):
			folded[index] = int(folded[index]) + int(result[index])
		for index in range(17, result.size()):
			var target := index - 17
			while target >= folded.size():
				folded.append(0)
			folded[target] = int(folded[target]) + int(result[index]) * 19
		result = _normalize(folded)
	while result.size() < 17:
		result.append(0)
	var prime := _p()
	while _compare(result, prime) >= 0:
		result = _subtract_positive(result, prime)
		while result.size() < 17:
			result.append(0)
	return result


static func _field_add(a: Array, b: Array) -> Array:
	var result := _zero()
	for index in range(17):
		result[index] = int(a[index]) + int(b[index])
	return _field_reduce(result)


static func _field_sub(a: Array, b: Array) -> Array:
	var prime := _p()
	var result := _zero()
	for index in range(17):
		result[index] = int(a[index]) + int(prime[index]) * 2 - int(b[index])
	return _field_reduce(result)


static func _field_neg(a: Array) -> Array:
	return _field_sub(_zero(), a)


static func _field_mul(a: Array, b: Array) -> Array:
	var result := []
	result.resize(34)
	result.fill(0)
	for left in range(17):
		for right in range(17):
			result[left + right] = int(result[left + right]) + int(a[left]) * int(b[right])
	return _field_reduce(result)


static func _field_square(a: Array) -> Array:
	return _field_mul(a, a)


static func _field_equal(a: Array, b: Array) -> bool:
	return _compare(_field_reduce(a), _field_reduce(b)) == 0


static func _field_pow(value: Array, exponent: Array, bit_count: int) -> Array:
	var result := _one()
	var factor := _field_reduce(value)
	for bit in range(bit_count):
		var limb := bit / LIMB_BITS
		if limb < exponent.size() and ((int(exponent[limb]) >> (bit % LIMB_BITS)) & 1) != 0:
			result = _field_mul(result, factor)
		factor = _field_square(factor)
	return result


static func _sqrt_exponent() -> Array:
	# (p - 5) / 8 = 2^252 - 3.
	var result := []
	result.resize(17)
	result[0] = LIMB_BASE - 3
	for index in range(1, 16):
		result[index] = LIMB_MASK
	result[16] = (1 << 12) - 1
	return result


static func _from_decimal(value: String) -> Array:
	var result := [0]
	for character in value:
		var digit := character.unicode_at(0) - 48
		var carry := digit
		for index in range(result.size()):
			var current: int = int(result[index]) * 10 + carry
			result[index] = current & LIMB_MASK
			carry = current >> LIMB_BITS
		if carry > 0:
			result.append(carry)
	return _trim(result)


static func _from_little_bytes(value: PackedByteArray) -> Array:
	var result := [0]
	for byte_index in range(value.size() - 1, -1, -1):
		var carry: int = value[byte_index]
		for index in range(result.size()):
			var current: int = int(result[index]) * 256 + carry
			result[index] = current & LIMB_MASK
			carry = current >> LIMB_BITS
		if carry > 0:
			result.append(carry)
	return _trim(result)


static func _reduce_scalar(hash_bytes: PackedByteArray, scalar_l: Array) -> Array:
	var result := [0]
	for bit_index in range(hash_bytes.size() * 8 - 1, -1, -1):
		var carry: int = (hash_bytes[bit_index / 8] >> (bit_index % 8)) & 1
		for index in range(result.size()):
			var current: int = int(result[index]) * 2 + carry
			result[index] = current & LIMB_MASK
			carry = current >> LIMB_BITS
		if carry > 0:
			result.append(carry)
		if _compare(result, scalar_l) >= 0:
			result = _subtract_positive(result, scalar_l)
	return result


static func _decode_point(encoded: PackedByteArray):
	if encoded.size() != 32:
		return null
	var y_bytes := encoded.duplicate()
	var sign := (y_bytes[31] >> 7) & 1
	y_bytes[31] &= 0x7F
	var y := _from_little_bytes(y_bytes)
	if _compare(y, _p()) >= 0:
		return null
	while y.size() < 17:
		y.append(0)
	var y2 := _field_square(y)
	var u := _field_sub(y2, _one())
	var d := _field_reduce(_from_decimal(FIELD_D_DECIMAL))
	var v := _field_add(_field_mul(d, y2), _one())
	var v2 := _field_square(v)
	var v3 := _field_mul(v2, v)
	var v6 := _field_square(v3)
	var v7 := _field_mul(v6, v)
	var x := _field_pow(_field_mul(u, v7), _sqrt_exponent(), 252)
	x = _field_mul(_field_mul(x, v3), u)
	var check := _field_mul(v, _field_square(x))
	if not _field_equal(check, u):
		if not _field_equal(check, _field_neg(u)):
			return null
		x = _field_mul(x, _field_reduce(_from_decimal(FIELD_SQRT_M1_DECIMAL)))
	if _field_equal(x, _zero()) and sign == 1:
		return null
	if (int(x[0]) & 1) != sign:
		x = _field_neg(x)
	return _point_from_affine(x, y)


static func _point_from_affine(x: Array, y: Array) -> Array:
	return [_field_reduce(x), _field_reduce(y), _one(), _field_mul(x, y)]


static func _point_identity() -> Array:
	return [_zero(), _one(), _one(), _zero()]


static func _point_add(p: Array, q: Array) -> Array:
	var d2 := _field_add(_field_reduce(_from_decimal(FIELD_D_DECIMAL)), _field_reduce(_from_decimal(FIELD_D_DECIMAL)))
	var a := _field_mul(_field_sub(p[1], p[0]), _field_sub(q[1], q[0]))
	var b := _field_mul(_field_add(p[1], p[0]), _field_add(q[1], q[0]))
	var c := _field_mul(d2, _field_mul(p[3], q[3]))
	var d_value := _field_add(_field_mul(p[2], q[2]), _field_mul(p[2], q[2]))
	var e := _field_sub(b, a)
	var f := _field_sub(d_value, c)
	var g := _field_add(d_value, c)
	var h := _field_add(b, a)
	return [_field_mul(e, f), _field_mul(g, h), _field_mul(f, g), _field_mul(e, h)]


static func _point_double(p: Array) -> Array:
	var a := _field_square(p[0])
	var b := _field_square(p[1])
	var c := _field_add(_field_square(p[2]), _field_square(p[2]))
	var d_value := _field_neg(a)
	var e := _field_sub(_field_sub(_field_square(_field_add(p[0], p[1])), a), b)
	var g := _field_add(d_value, b)
	var f := _field_sub(g, c)
	var h := _field_sub(d_value, b)
	return [_field_mul(e, f), _field_mul(g, h), _field_mul(f, g), _field_mul(e, h)]


static func _point_scalar_mul(point: Array, scalar: Array) -> Array:
	var result := _point_identity()
	var addend := point
	for bit in range(256):
		var limb := bit / LIMB_BITS
		if limb < scalar.size() and ((int(scalar[limb]) >> (bit % LIMB_BITS)) & 1) != 0:
			result = _point_add(result, addend)
		addend = _point_double(addend)
	return result


static func _point_equal(a: Array, b: Array) -> bool:
	return _field_equal(_field_mul(a[0], b[2]), _field_mul(b[0], a[2])) and _field_equal(_field_mul(a[1], b[2]), _field_mul(b[1], a[2]))


static func _u64_from_hex(value: String) -> Array:
	return [value.substr(0, 8).hex_to_int() & MASK32, value.substr(8, 8).hex_to_int() & MASK32]


static func _xor64(a: Array, b: Array) -> Array:
	return [(int(a[0]) ^ int(b[0])) & MASK32, (int(a[1]) ^ int(b[1])) & MASK32]


static func _and64(a: Array, b: Array) -> Array:
	return [(int(a[0]) & int(b[0])) & MASK32, (int(a[1]) & int(b[1])) & MASK32]


static func _not64(a: Array) -> Array:
	return [(~int(a[0])) & MASK32, (~int(a[1])) & MASK32]


static func _add64(parts: Array) -> Array:
	var low_total := 0
	var high_total := 0
	for part in parts:
		low_total += int(part[1])
		high_total += int(part[0])
	high_total += low_total >> 32
	return [high_total & MASK32, low_total & MASK32]


static func _rotr64(value: Array, count: int) -> Array:
	var n := count % 64
	if n == 0:
		return [value[0], value[1]]
	if n == 32:
		return [value[1], value[0]]
	if n > 32:
		return _rotr64([value[1], value[0]], n - 32)
	var hi: int = value[0]
	var lo: int = value[1]
	return [((hi >> n) | ((lo << (32 - n)) & MASK32)) & MASK32, ((lo >> n) | ((hi << (32 - n)) & MASK32)) & MASK32]


static func _shr64(value: Array, count: int) -> Array:
	if count <= 0:
		return [value[0], value[1]]
	if count >= 64:
		return [0, 0]
	if count == 32:
		return [0, value[0]]
	if count > 32:
		return [0, int(value[0]) >> (count - 32)]
	var hi: int = value[0]
	var lo: int = value[1]
	return [(hi >> count) & MASK32, ((lo >> count) | ((hi << (32 - count)) & MASK32)) & MASK32]


static func _sha512(value: PackedByteArray) -> PackedByteArray:
	var data := value.duplicate()
	var bit_length: int = data.size() * 8
	data.append(0x80)
	while data.size() % 128 != 112:
		data.append(0)
	for _index in range(8):
		data.append(0)
	for shift in [56, 48, 40, 32, 24, 16, 8, 0]:
		data.append((bit_length >> shift) & 0xFF)
	var state := []
	for constant in SHA512_INITIAL:
		state.append(_u64_from_hex(constant))
	var round_constants := []
	for constant in SHA512_ROUND:
		round_constants.append(_u64_from_hex(constant))
	for block_offset in range(0, data.size(), 128):
		var words := []
		words.resize(80)
		for index in range(16):
			var offset := block_offset + index * 8
			var hi := (int(data[offset]) << 24) | (int(data[offset + 1]) << 16) | (int(data[offset + 2]) << 8) | int(data[offset + 3])
			var lo := (int(data[offset + 4]) << 24) | (int(data[offset + 5]) << 16) | (int(data[offset + 6]) << 8) | int(data[offset + 7])
			words[index] = [hi & MASK32, lo & MASK32]
		for index in range(16, 80):
			var s0 := _xor64(_xor64(_rotr64(words[index - 15], 1), _rotr64(words[index - 15], 8)), _shr64(words[index - 15], 7))
			var s1 := _xor64(_xor64(_rotr64(words[index - 2], 19), _rotr64(words[index - 2], 61)), _shr64(words[index - 2], 6))
			words[index] = _add64([words[index - 16], s0, words[index - 7], s1])
		var a = state[0]
		var b = state[1]
		var c = state[2]
		var d_value = state[3]
		var e = state[4]
		var f = state[5]
		var g = state[6]
		var h = state[7]
		for index in range(80):
			var big_s1 := _xor64(_xor64(_rotr64(e, 14), _rotr64(e, 18)), _rotr64(e, 41))
			var choose := _xor64(_and64(e, f), _and64(_not64(e), g))
			var temp1 := _add64([h, big_s1, choose, round_constants[index], words[index]])
			var big_s0 := _xor64(_xor64(_rotr64(a, 28), _rotr64(a, 34)), _rotr64(a, 39))
			var majority := _xor64(_xor64(_and64(a, b), _and64(a, c)), _and64(b, c))
			var temp2 := _add64([big_s0, majority])
			h = g
			g = f
			f = e
			e = _add64([d_value, temp1])
			d_value = c
			c = b
			b = a
			a = _add64([temp1, temp2])
		state[0] = _add64([state[0], a])
		state[1] = _add64([state[1], b])
		state[2] = _add64([state[2], c])
		state[3] = _add64([state[3], d_value])
		state[4] = _add64([state[4], e])
		state[5] = _add64([state[5], f])
		state[6] = _add64([state[6], g])
		state[7] = _add64([state[7], h])
	var digest := PackedByteArray()
	for word in state:
		for shift in [24, 16, 8, 0]:
			digest.append((int(word[0]) >> shift) & 0xFF)
		for shift in [24, 16, 8, 0]:
			digest.append((int(word[1]) >> shift) & 0xFF)
	return digest
