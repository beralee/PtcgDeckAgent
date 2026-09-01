from __future__ import annotations

import copy
import hashlib
import json
import math
from dataclasses import dataclass
from typing import Any

from .source_lock import DuplicateJsonKeyError, load_json_bytes_strict


PROFILE_ID = "cabt_tree_hash_v1"
SAFE_INTEGER_MIN = -(2**53) + 1
SAFE_INTEGER_MAX = 2**53 - 1

_HARD_MAX_INPUT_BYTES = 64 * 1024 * 1024
_HARD_MAX_DEPTH = 128
_HARD_MAX_NODES = 1_000_000
_HARD_MAX_OUTPUT_BYTES = 64 * 1024 * 1024
_CALLBACK_REQUIRED_FIELDS = {
    "select",
    "logs",
    "current",
    "search_begin_input",
}
_SEARCH_FIELD = "search_begin_input"
_SEARCH_PRESENCE_FIELD = "$ptcgdap_opaque_search_capability_present"
_DOMAINS = {
    "raw_private",
    "token_free_callback",
    "public_observation",
}
_PREFIX_STEM = b"PTCGDAP\x00CABT_TREE_HASH_V1\x00"


class CabtTreeHashError(ValueError):
    """A bounded, stable-code failure in JCS canonicalization or CABT hashing."""

    def __init__(self, code: str, detail: str) -> None:
        self.code = code
        self.detail = detail
        super().__init__(f"{code}: {detail}")


@dataclass(frozen=True)
class CabtTreeHashLimits:
    max_input_bytes: int = _HARD_MAX_INPUT_BYTES
    max_depth: int = _HARD_MAX_DEPTH
    max_nodes: int = _HARD_MAX_NODES
    max_output_bytes: int = _HARD_MAX_OUTPUT_BYTES

    def __post_init__(self) -> None:
        maxima = {
            "max_input_bytes": _HARD_MAX_INPUT_BYTES,
            "max_depth": _HARD_MAX_DEPTH,
            "max_nodes": _HARD_MAX_NODES,
            "max_output_bytes": _HARD_MAX_OUTPUT_BYTES,
        }
        for field_name, hard_maximum in maxima.items():
            value = getattr(self, field_name)
            minimum = 0 if field_name == "max_depth" else 1
            if type(value) is not int or value < minimum or value > hard_maximum:
                raise CabtTreeHashError(
                    "invalid_limits",
                    f"{field_name} must be an integer in [{minimum}, {hard_maximum}]",
                )


DEFAULT_LIMITS = CabtTreeHashLimits()


def _require_limits(limits: Any) -> CabtTreeHashLimits:
    if not isinstance(limits, CabtTreeHashLimits):
        raise CabtTreeHashError("invalid_limits", "limits must be CabtTreeHashLimits")
    return limits


class _BoundedSink:
    def __init__(self, maximum: int) -> None:
        self._maximum = maximum
        self._buffer = bytearray()

    def write(self, data: bytes) -> None:
        if len(self._buffer) + len(data) > self._maximum:
            raise CabtTreeHashError(
                "output_size_limit",
                "canonical JSON exceeds the configured output byte limit",
            )
        self._buffer.extend(data)

    def finish(self) -> bytes:
        return bytes(self._buffer)


def _canonical_string_byte_length(value: str) -> int:
    length = 2  # Surrounding quotes.
    for character in value:
        codepoint = ord(character)
        if 0xD800 <= codepoint <= 0xDFFF or _is_unicode_noncharacter(codepoint):
            raise CabtTreeHashError(
                "invalid_unicode",
                "I-JSON strings and object keys must not contain surrogates or noncharacters",
            )
        if character in {'"', "\\", "\b", "\t", "\n", "\f", "\r"}:
            length += 2
        elif codepoint <= 0x1F:
            length += 6
        elif codepoint <= 0x7F:
            length += 1
        elif codepoint <= 0x7FF:
            length += 2
        elif codepoint <= 0xFFFF:
            length += 3
        else:
            length += 4
    return length


def _is_unicode_noncharacter(codepoint: int) -> bool:
    return 0xFDD0 <= codepoint <= 0xFDEF or codepoint & 0xFFFF in {
        0xFFFE,
        0xFFFF,
    }


class _JsonBoundsPreflight:
    """Count valid JSON values/depth before the strict loader allocates the tree."""

    _WHITESPACE = b" \t\r\n"
    _HEX_DIGITS = b"0123456789abcdefABCDEF"
    _SIMPLE_ESCAPES = b'"\\/bfnrt'

    def __init__(self, data: bytes, limits: CabtTreeHashLimits) -> None:
        self._data = data
        self._length = len(data)
        self._limits = limits
        self._nodes = 0

    def run(self) -> None:
        # The cross-runtime byte contract is strict UTF-8 JSON without a BOM.
        # U+FEFF may still occur inside a JSON string, but its UTF-8 signature
        # bytes are never skipped at the document boundary.
        index = self._skip_whitespace(0)
        index = self._parse_value(index, 0)
        if self._skip_whitespace(index) != self._length:
            self._invalid()

    def _invalid(self) -> None:
        raise CabtTreeHashError(
            "invalid_json",
            "input is not strict finite UTF-8 JSON",
        )

    def _skip_whitespace(self, index: int) -> int:
        while index < self._length and self._data[index] in self._WHITESPACE:
            index += 1
        return index

    def _count_node(self, depth: int) -> None:
        self._nodes += 1
        if self._nodes > self._limits.max_nodes:
            raise CabtTreeHashError(
                "node_limit",
                "JSON tree exceeds the configured node limit",
            )
        if depth > self._limits.max_depth:
            raise CabtTreeHashError(
                "depth_limit",
                "JSON tree exceeds the configured depth limit",
            )

    def _parse_value(self, index: int, depth: int) -> int:
        index = self._skip_whitespace(index)
        if index >= self._length:
            self._invalid()
        token = self._data[index]
        if token == 0x22:  # "
            end = self._scan_string(index)
            self._count_node(depth)
            return end
        if token == 0x7B:  # {
            self._count_node(depth)
            return self._parse_object(index, depth)
        if token == 0x5B:  # [
            self._count_node(depth)
            return self._parse_array(index, depth)
        if token == 0x74 and self._data[index : index + 4] == b"true":
            self._count_node(depth)
            return index + 4
        if token == 0x66 and self._data[index : index + 5] == b"false":
            self._count_node(depth)
            return index + 5
        if token == 0x6E and self._data[index : index + 4] == b"null":
            self._count_node(depth)
            return index + 4
        if token == 0x2D or 0x30 <= token <= 0x39:
            end = self._scan_number(index)
            self._count_node(depth)
            return end
        self._invalid()

    def _scan_string(self, index: int) -> int:
        index += 1
        while index < self._length:
            token = self._data[index]
            if token == 0x22:
                return index + 1
            if token < 0x20:
                self._invalid()
            if token != 0x5C:  # Backslash.
                index += 1
                continue
            index += 1
            if index >= self._length:
                self._invalid()
            escape = self._data[index]
            if escape in self._SIMPLE_ESCAPES:
                index += 1
                continue
            if escape != 0x75 or index + 4 >= self._length:  # uXXXX
                self._invalid()
            if any(
                digit not in self._HEX_DIGITS
                for digit in self._data[index + 1 : index + 5]
            ):
                self._invalid()
            index += 5
        self._invalid()

    def _scan_number(self, index: int) -> int:
        if self._data[index] == 0x2D:
            index += 1
            if index >= self._length:
                self._invalid()
        if self._data[index] == 0x30:
            index += 1
        elif 0x31 <= self._data[index] <= 0x39:
            index += 1
            while index < self._length and 0x30 <= self._data[index] <= 0x39:
                index += 1
        else:
            self._invalid()
        if index < self._length and self._data[index] == 0x2E:
            index += 1
            if index >= self._length or not 0x30 <= self._data[index] <= 0x39:
                self._invalid()
            while index < self._length and 0x30 <= self._data[index] <= 0x39:
                index += 1
        if index < self._length and self._data[index] in b"eE":
            index += 1
            if index < self._length and self._data[index] in b"+-":
                index += 1
            if index >= self._length or not 0x30 <= self._data[index] <= 0x39:
                self._invalid()
            while index < self._length and 0x30 <= self._data[index] <= 0x39:
                index += 1
        return index

    def _parse_array(self, index: int, depth: int) -> int:
        index = self._skip_whitespace(index + 1)
        if index < self._length and self._data[index] == 0x5D:
            return index + 1
        while True:
            index = self._parse_value(index, depth + 1)
            index = self._skip_whitespace(index)
            if index >= self._length:
                self._invalid()
            if self._data[index] == 0x5D:
                return index + 1
            if self._data[index] != 0x2C:
                self._invalid()
            index = self._skip_whitespace(index + 1)

    def _parse_object(self, index: int, depth: int) -> int:
        index = self._skip_whitespace(index + 1)
        if index < self._length and self._data[index] == 0x7D:
            return index + 1
        while True:
            if index >= self._length or self._data[index] != 0x22:
                self._invalid()
            index = self._skip_whitespace(self._scan_string(index))
            if index >= self._length or self._data[index] != 0x3A:
                self._invalid()
            index = self._parse_value(index + 1, depth + 1)
            index = self._skip_whitespace(index)
            if index >= self._length:
                self._invalid()
            if self._data[index] == 0x7D:
                return index + 1
            if self._data[index] != 0x2C:
                self._invalid()
            index = self._skip_whitespace(index + 1)


def _validate_tree(value: Any, limits: CabtTreeHashLimits) -> None:
    # Exit frames make ``active`` a path set rather than a global seen set, so
    # a shared but acyclic container serializes as the repeated JSON value.
    stack: list[tuple[bool, Any, int]] = [(False, value, 0)]
    active: set[int] = set()
    node_count = 0
    canonical_size = 0

    def add_canonical_size(byte_count: int) -> None:
        nonlocal canonical_size
        canonical_size += byte_count
        if canonical_size > limits.max_output_bytes:
            raise CabtTreeHashError(
                "output_size_limit",
                "canonical JSON exceeds the configured output byte limit",
            )

    while stack:
        exiting, current, depth = stack.pop()
        if exiting:
            active.remove(id(current))
            continue

        node_count += 1
        if node_count > limits.max_nodes:
            raise CabtTreeHashError(
                "node_limit",
                "JSON tree exceeds the configured node limit",
            )
        if depth > limits.max_depth:
            raise CabtTreeHashError(
                "depth_limit",
                "JSON tree exceeds the configured depth limit",
            )

        current_type = type(current)
        if current is None:
            add_canonical_size(4)
            continue
        if current_type is bool:
            add_canonical_size(4 if current else 5)
            continue
        if current_type is int:
            if current < SAFE_INTEGER_MIN or current > SAFE_INTEGER_MAX:
                raise CabtTreeHashError(
                    "unsafe_integer",
                    "Python integers must remain in the CABT profile's exact interoperable range",
                )
            add_canonical_size(len(str(current)))
            continue
        if current_type is float:
            if not math.isfinite(current):
                raise CabtTreeHashError(
                    "non_finite_number",
                    "NaN and Infinity are forbidden by RFC 8785",
                )
            add_canonical_size(len(_serialize_float(current)))
            continue
        if current_type is str:
            add_canonical_size(_canonical_string_byte_length(current))
            continue
        if current_type is list:
            identity = id(current)
            if identity in active:
                raise CabtTreeHashError(
                    "cycle_detected",
                    "JSON trees must be acyclic",
                )
            if len(current) > limits.max_nodes - node_count:
                raise CabtTreeHashError(
                    "node_limit",
                    "JSON tree exceeds the configured node limit",
                )
            add_canonical_size(2 + max(0, len(current) - 1))
            active.add(identity)
            stack.append((True, current, depth))
            for child in reversed(current):
                stack.append((False, child, depth + 1))
            continue
        if current_type is dict:
            identity = id(current)
            if identity in active:
                raise CabtTreeHashError(
                    "cycle_detected",
                    "JSON trees must be acyclic",
                )
            for key in current:
                if type(key) is not str:
                    raise CabtTreeHashError(
                        "non_string_key",
                        "JSON object keys must be strings",
                    )
                add_canonical_size(_canonical_string_byte_length(key) + 1)
            if len(current) > limits.max_nodes - node_count:
                raise CabtTreeHashError(
                    "node_limit",
                    "JSON tree exceeds the configured node limit",
                )
            add_canonical_size(2 + max(0, len(current) - 1))
            active.add(identity)
            stack.append((True, current, depth))
            for child in reversed(tuple(current.values())):
                stack.append((False, child, depth + 1))
            continue
        raise CabtTreeHashError(
            "unsupported_type",
            "canonicalization accepts only parsed JSON object/list/scalar types",
        )


def _serialize_string(value: str, sink: _BoundedSink) -> None:
    sink.write(b'"')
    start = 0
    for index, character in enumerate(value):
        codepoint = ord(character)
        replacement: bytes | None = None
        if character == '"':
            replacement = b'\\"'
        elif character == "\\":
            replacement = b"\\\\"
        elif character == "\b":
            replacement = b"\\b"
        elif character == "\t":
            replacement = b"\\t"
        elif character == "\n":
            replacement = b"\\n"
        elif character == "\f":
            replacement = b"\\f"
        elif character == "\r":
            replacement = b"\\r"
        elif codepoint <= 0x1F:
            replacement = f"\\u{codepoint:04x}".encode("ascii")

        if replacement is not None:
            if start < index:
                sink.write(value[start:index].encode("utf-8"))
            sink.write(replacement)
            start = index + 1

    if start < len(value):
        sink.write(value[start:].encode("utf-8"))
    sink.write(b'"')


def _serialize_float(value: float) -> bytes:
    if not math.isfinite(value):
        raise CabtTreeHashError(
            "non_finite_number",
            "NaN and Infinity are forbidden by RFC 8785",
        )
    if value == 0:
        return b"0"
    if value < 0:
        return b"-" + _serialize_float(-value)

    # CPython emits the shortest round-tripping binary64 decimal.  JCS uses
    # the same shortest value but ECMAScript has different exponent/decimal
    # display thresholds, applied below (plain form for e-6 through e+20).
    shortest = repr(value)
    exponent_value = 0
    exponent_text = ""
    if "e" in shortest:
        mantissa, raw_exponent = shortest.split("e", 1)
        exponent_value = int(raw_exponent)
        sign = "+" if exponent_value >= 0 else "-"
        exponent_text = f"e{sign}{abs(exponent_value)}"
    else:
        mantissa = shortest

    if "." in mantissa:
        first, last = mantissa.split(".", 1)
        dot = "."
    else:
        first = mantissa
        last = ""
        dot = ""

    if last == "0":
        dot = ""
        last = ""

    if 0 < exponent_value < 21:
        first += last
        last = ""
        dot = ""
        exponent_text = ""
        zeros = exponent_value - len(first) + 1
        if zeros > 0:
            first += "0" * zeros
    elif -7 < exponent_value < 0:
        last = first + last
        first = "0"
        dot = "."
        exponent_text = ""
        zeros = -exponent_value - 1
        if zeros > 0:
            last = "0" * zeros + last

    return f"{first}{dot}{last}{exponent_text}".encode("ascii")


def _serialize_value(value: Any, sink: _BoundedSink) -> None:
    value_type = type(value)
    if value is None:
        sink.write(b"null")
    elif value_type is bool:
        sink.write(b"true" if value else b"false")
    elif value_type is int:
        sink.write(str(value).encode("ascii"))
    elif value_type is float:
        sink.write(_serialize_float(value))
    elif value_type is str:
        _serialize_string(value, sink)
    elif value_type is list:
        sink.write(b"[")
        for index, child in enumerate(value):
            if index:
                sink.write(b",")
            _serialize_value(child, sink)
        sink.write(b"]")
    elif value_type is dict:
        sink.write(b"{")
        # UTF-16 big-endian bytes preserve unsigned UTF-16 code-unit order.
        items = sorted(value.items(), key=lambda item: item[0].encode("utf-16be"))
        for index, (key, child) in enumerate(items):
            if index:
                sink.write(b",")
            _serialize_string(key, sink)
            sink.write(b":")
            _serialize_value(child, sink)
        sink.write(b"}")
    else:  # pragma: no cover - validation owns this invariant.
        raise CabtTreeHashError("unsupported_type", "unsupported JSON tree type")


def jcs_canonical_json_bytes(
    value: Any,
    *,
    limits: CabtTreeHashLimits = DEFAULT_LIMITS,
) -> bytes:
    """Serialize a CABT-safe parsed tree with RFC 8785 canonical byte rules.

    This profile intentionally rejects Python integer nodes outside the exact
    interoperable range instead of coercing them to binary64.  It is therefore
    an RFC 8785 output profile over a narrower CABT/I-JSON input subset, not a
    general-purpose arbitrary-Python-value JCS encoder.
    """

    limits = _require_limits(limits)
    _validate_tree(value, limits)
    sink = _BoundedSink(limits.max_output_bytes)
    try:
        _serialize_value(value, sink)
    except RecursionError as exc:  # Defensive guard if the hard limit changes.
        raise CabtTreeHashError(
            "depth_limit",
            "JSON tree exceeds the serializer recursion bound",
        ) from exc
    return sink.finish()


def jcs_canonicalize_json_bytes(
    data: bytes,
    *,
    limits: CabtTreeHashLimits = DEFAULT_LIMITS,
) -> bytes:
    """Strictly parse bounded UTF-8 JSON, then apply the CABT JCS profile."""

    limits = _require_limits(limits)
    if type(data) is not bytes:
        raise CabtTreeHashError("invalid_input_type", "JSON input must be bytes")
    if len(data) > limits.max_input_bytes:
        raise CabtTreeHashError(
            "input_size_limit",
            "JSON input exceeds the configured byte limit",
        )
    # Enforce the structural limits before ``json.loads`` materializes a
    # potentially adversarial tree.  The authoritative strict loader still
    # owns UTF-8 decoding, duplicate-key rejection, and parsed scalar values.
    _JsonBoundsPreflight(data, limits).run()
    try:
        value = load_json_bytes_strict(data)
    except DuplicateJsonKeyError as exc:
        raise CabtTreeHashError(
            "duplicate_key",
            "I-JSON objects must not contain duplicate keys",
        ) from exc
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError, RecursionError) as exc:
        raise CabtTreeHashError(
            "invalid_json",
            "input is not strict finite UTF-8 JSON",
        ) from exc
    return jcs_canonical_json_bytes(value, limits=limits)


def _validate_callback(raw_payload: Any, limits: CabtTreeHashLimits) -> dict[str, Any]:
    _validate_tree(raw_payload, limits)
    if type(raw_payload) is not dict:
        raise CabtTreeHashError(
            "invalid_callback",
            "CABT callback root must be an object",
        )
    if not _CALLBACK_REQUIRED_FIELDS.issubset(raw_payload):
        raise CabtTreeHashError(
            "invalid_callback",
            "CABT callback is missing a required root field",
        )
    search_value = raw_payload[_SEARCH_FIELD]
    if search_value is not None and type(search_value) is not str:
        raise CabtTreeHashError(
            "invalid_callback",
            "root search_begin_input must be a string or null",
        )
    return raw_payload


def normalize_search_capability(
    raw_payload: Any,
    *,
    limits: CabtTreeHashLimits = DEFAULT_LIMITS,
) -> dict[str, Any]:
    """Deep-copy a callback and replace only its root Search token with presence."""

    limits = _require_limits(limits)
    callback = _validate_callback(raw_payload, limits)
    try:
        normalized = copy.deepcopy(callback)
    except RecursionError as exc:  # The validated hard depth should prevent this.
        raise CabtTreeHashError("depth_limit", "callback cannot be copied safely") from exc
    normalized[_SEARCH_FIELD] = {
        _SEARCH_PRESENCE_FIELD: callback[_SEARCH_FIELD] is not None
    }
    return normalized


def _reject_public_search_fields(value: Any) -> None:
    stack = [value]
    while stack:
        current = stack.pop()
        if type(current) is dict:
            if _SEARCH_FIELD in current or _SEARCH_PRESENCE_FIELD in current:
                raise CabtTreeHashError(
                    "public_projection_forbidden_field",
                    "public projection must not contain Search token or presence fields",
                )
            stack.extend(current.values())
        elif type(current) is list:
            stack.extend(current)


def cabt_tree_hash(
    value: Any,
    domain: str,
    *,
    limits: CabtTreeHashLimits = DEFAULT_LIMITS,
) -> str:
    """Compute an uppercase SHA-256 for one cabt_tree_hash_v1 domain."""

    limits = _require_limits(limits)
    if type(domain) is not str or domain not in _DOMAINS:
        raise CabtTreeHashError(
            "unsupported_domain",
            "CABT tree hash domain is not part of cabt_tree_hash_v1",
        )

    if domain == "raw_private":
        _validate_callback(value, limits)
        canonical_input = value
    elif domain == "token_free_callback":
        canonical_input = normalize_search_capability(value, limits=limits)
    else:
        _validate_tree(value, limits)
        _reject_public_search_fields(value)
        canonical_input = value

    canonical = jcs_canonical_json_bytes(canonical_input, limits=limits)
    prefix = _PREFIX_STEM + domain.encode("ascii") + b"\x00"
    digest = hashlib.sha256()
    digest.update(prefix)
    digest.update(canonical)
    return digest.hexdigest().upper()


def raw_private_hash(
    raw_payload: Any,
    *,
    limits: CabtTreeHashLimits = DEFAULT_LIMITS,
) -> str:
    return cabt_tree_hash(raw_payload, "raw_private", limits=limits)


def token_free_callback_hash(
    raw_payload: Any,
    *,
    limits: CabtTreeHashLimits = DEFAULT_LIMITS,
) -> str:
    return cabt_tree_hash(raw_payload, "token_free_callback", limits=limits)


def public_observation_hash(
    public_projection: Any,
    *,
    limits: CabtTreeHashLimits = DEFAULT_LIMITS,
) -> str:
    return cabt_tree_hash(public_projection, "public_observation", limits=limits)
