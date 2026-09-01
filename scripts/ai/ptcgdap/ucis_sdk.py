from __future__ import annotations

from dataclasses import dataclass
import hashlib
from pathlib import Path
from types import MappingProxyType
from typing import Any, Callable, Mapping, Sequence

from .source_lock import canonical_json_v1_bytes, load_json_bytes_strict
from .ucis import UcisRegistry


class UcisSdkError(ValueError):
    """Stable fail-closed developer SDK error."""


def _fail(code: str) -> None:
    raise UcisSdkError(code)


_SELECT_FIELDS = frozenset(
    {
        "type",
        "context",
        "minCount",
        "maxCount",
        "remainDamageCounter",
        "remainEnergyCost",
        "option",
        "deck",
        "contextCard",
        "effect",
    }
)


@dataclass(frozen=True, slots=True)
class UcisOptionView:
    index: int
    option_type_raw: int
    option_type_name: str
    fields: Mapping[str, int]
    semantic_fingerprint: str

    def field(self, name: str) -> int | None:
        return self.fields.get(name)


@dataclass(frozen=True, slots=True)
class UcisSelectionView:
    select_type_raw: int
    select_type_name: str
    context_raw: int
    context_name: str
    min_count: int
    max_count: int
    remain_damage_counter: int
    remain_energy_cost: int
    options: tuple[UcisOptionView, ...]
    public_facts: Mapping[str, int | bool | str]

    def indexes_where(self, predicate: Callable[[UcisOptionView], bool]) -> list[int]:
        if not callable(predicate):
            _fail("ucis_sdk_predicate_invalid")
        return [option.index for option in self.options if predicate(option)]

    def rebind_semantic_fingerprints(self, fingerprints: Sequence[str]) -> list[int]:
        if type(fingerprints) not in (list, tuple) or any(
            type(value) is not str or not value for value in fingerprints
        ):
            _fail("ucis_sdk_semantic_fingerprint_invalid")
        available: dict[str, list[int]] = {}
        for option in self.options:
            available.setdefault(option.semantic_fingerprint, []).append(option.index)
        indexes: list[int] = []
        for fingerprint in fingerprints:
            candidates = available.get(fingerprint, [])
            if not candidates:
                _fail("ucis_sdk_semantic_rebind_missing")
            indexes.append(candidates.pop(0))
        return indexes

    def validate_indexes(self, indexes: Sequence[int]) -> list[int]:
        if type(indexes) not in (list, tuple) or any(type(index) is not int for index in indexes):
            _fail("ucis_sdk_indexes_invalid")
        result = list(indexes)
        if (
            len(result) != len(set(result))
            or any(index < 0 or index >= len(self.options) for index in result)
            or not self.min_count <= len(result) <= self.max_count
        ):
            _fail("ucis_sdk_indexes_invalid")
        return result


class UcisDeveloperSdk:
    """Read-only author view over the current official-shaped selection window."""

    def __init__(
        self,
        root: Path,
        registry: UcisRegistry,
        catalog: Mapping[str, Any],
        coverage_ledger: Mapping[str, Any],
        legacy_inventory: Mapping[str, Any],
    ) -> None:
        self.root = root
        self.registry = registry
        self.catalog = MappingProxyType(dict(catalog))
        self.coverage_ledger = MappingProxyType(dict(coverage_ledger))
        self.legacy_inventory = MappingProxyType(dict(legacy_inventory))
        self.catalog_hash = hashlib.sha256(
            canonical_json_v1_bytes(catalog)
        ).hexdigest().upper()
        self.coverage_ledger_hash = hashlib.sha256(
            canonical_json_v1_bytes(coverage_ledger)
        ).hexdigest().upper()
        self.select_types = MappingProxyType(
            {row.select_type_name: row.select_type_raw for row in registry.context_rows.values()}
        )
        self.contexts = MappingProxyType(
            {row.context_name: row.context_raw for row in registry.context_rows.values()}
        )
        option_types: dict[str, int] = {}
        for row in registry.context_rows.values():
            option_types.update(zip(row.option_type_names, row.option_types, strict=True))
        self.option_types = MappingProxyType(option_types)

    @classmethod
    def load(cls, repository_root: str | Path) -> "UcisDeveloperSdk":
        root = Path(repository_root).resolve()
        registry = UcisRegistry.load(root)
        catalog_path = root / "contracts/ptcgdap/ucis_card_catalog_v1.json"
        coverage_path = root / "contracts/ptcgdap/ucis_coverage_ledger_v1.json"
        legacy_path = root / "contracts/ptcgdap/ucis_legacy_inventory_v1.json"
        bundle_path = root / "contracts/ptcgdap/ucis_bundle_v1.json"
        catalog = load_json_bytes_strict(catalog_path.read_bytes())
        coverage = load_json_bytes_strict(coverage_path.read_bytes())
        legacy = load_json_bytes_strict(legacy_path.read_bytes())
        bundle = load_json_bytes_strict(bundle_path.read_bytes())
        bundle_hashes = {
            entry.get("path"): entry.get("canonical_sha256")
            for entry in bundle.get("files", [])
            if type(entry) is dict
        }
        for path, document, code in (
            (catalog_path, catalog, "ucis_sdk_catalog_hash_invalid"),
            (coverage_path, coverage, "ucis_sdk_coverage_hash_invalid"),
            (legacy_path, legacy, "ucis_sdk_legacy_hash_invalid"),
        ):
            expected = bundle_hashes.get(path.relative_to(root).as_posix())
            actual = hashlib.sha256(
                canonical_json_v1_bytes(document)
            ).hexdigest().upper()
            if expected != actual:
                _fail(code)
        if catalog.get("ucis_generation") != registry.ucis_generation:
            _fail("ucis_sdk_generation_drift")
        if (
            coverage.get("ucis_generation") != registry.ucis_generation
            or legacy.get("ucis_generation") != registry.ucis_generation
        ):
            _fail("ucis_sdk_generation_drift")
        return cls(root, registry, catalog, coverage, legacy)

    def parse_selection(self, raw_observation: Mapping[str, Any]) -> UcisSelectionView:
        if type(raw_observation) is not dict or type(raw_observation.get("select")) is not dict:
            _fail("ucis_sdk_observation_invalid")
        select = raw_observation["select"]
        if set(select) != _SELECT_FIELDS:
            _fail("ucis_sdk_select_fields_invalid")
        select_type = select.get("type")
        context = select.get("context")
        minimum = select.get("minCount")
        maximum = select.get("maxCount")
        remain_damage = select.get("remainDamageCounter")
        remain_energy = select.get("remainEnergyCost")
        options = select.get("option")
        if any(
            type(value) is not int
            for value in (select_type, context, minimum, maximum, remain_damage, remain_energy)
        ) or type(options) is not list:
            _fail("ucis_sdk_select_value_invalid")
        row = self.registry.context_rows.get(context)
        if row is None or select_type != row.select_type_raw:
            _fail("ucis_sdk_context_type_mismatch")
        if (
            minimum < 0
            or maximum < minimum
            or maximum > len(options)
            or remain_damage < 0
            or remain_energy < 0
        ):
            _fail("ucis_sdk_cardinality_invalid")
        parsed_options = tuple(self._parse_option(index, option, row) for index, option in enumerate(options))
        facts: dict[str, int | bool | str] = {
            "select_type_raw": select_type,
            "select_type_name": row.select_type_name,
            "context_raw": context,
            "context_name": row.context_name,
            "min_count": minimum,
            "max_count": maximum,
            "option_count": len(options),
            "remain_damage_counter": remain_damage,
            "remain_energy_cost": remain_energy,
            "optional_zero": minimum == 0,
            "exact_count_required": minimum == maximum,
        }
        return UcisSelectionView(
            select_type_raw=select_type,
            select_type_name=row.select_type_name,
            context_raw=context,
            context_name=row.context_name,
            min_count=minimum,
            max_count=maximum,
            remain_damage_counter=remain_damage,
            remain_energy_cost=remain_energy,
            options=parsed_options,
            public_facts=MappingProxyType(facts),
        )

    def build_scenario_window(
        self,
        *,
        context_name: str,
        options: Sequence[Mapping[str, Any]],
        min_count: int,
        max_count: int,
        remain_damage_counter: int = 0,
        remain_energy_cost: int = 0,
    ) -> dict[str, Any]:
        row = self.registry.context_names.get(context_name)
        if row is None or type(options) not in (list, tuple):
            _fail("ucis_sdk_scenario_invalid")
        observation = {
            "select": {
                "type": row.select_type_raw,
                "context": row.context_raw,
                "minCount": min_count,
                "maxCount": max_count,
                "remainDamageCounter": remain_damage_counter,
                "remainEnergyCost": remain_energy_cost,
                "option": [dict(option) for option in options],
                "deck": None,
                "contextCard": None,
                "effect": None,
            }
        }
        self.parse_selection(observation)
        return observation

    def capability_catalog(self) -> Mapping[str, Any]:
        unsupported = tuple(
            {
                "effect_id": str(effect.get("effect_id", "")),
                "capability_ids": tuple(effect.get("capability_ids", [])),
                "reasons": tuple(effect.get("unsupported_reasons", [])),
            }
            for effect in self.catalog.get("effects", [])
            if type(effect) is dict and effect.get("status") == "unsupported"
        )
        return MappingProxyType(
            {
                "ucis_generation": self.registry.ucis_generation,
                "contract_generation": self.registry.contract_generation,
                "registry_sha256": self.registry.document_hash,
                "catalog_scope_sha256": self.catalog_hash,
                "coverage_ledger_sha256": self.coverage_ledger_hash,
                "primitives": tuple(self.registry.primitives),
                "primitive_coverage": MappingProxyType(
                    dict(self.catalog.get("primitive_coverage", {}))
                ),
                "unsupported_capabilities": unsupported,
                "closure": MappingProxyType(dict(self.catalog.get("closure", {}))),
                "coverage_metrics": MappingProxyType(
                    dict(self.coverage_ledger.get("metrics", {}))
                ),
                "legacy_closure": MappingProxyType(
                    dict(self.legacy_inventory.get("closure", {}))
                ),
            }
        )

    def _parse_option(self, index: int, raw: Any, row: Any) -> UcisOptionView:
        if type(raw) is not dict or type(raw.get("type")) is not int:
            _fail("ucis_sdk_option_invalid")
        option_type = raw["type"]
        if option_type not in row.option_types:
            _fail("ucis_sdk_context_option_mismatch")
        expected_shape = self.registry.option_shapes.get(option_type)
        if expected_shape is None or set(raw) != set(expected_shape):
            _fail("ucis_sdk_sparse_option_invalid")
        if any(type(raw[field]) is not int for field in expected_shape):
            _fail("ucis_sdk_option_value_invalid")
        option_index = row.option_types.index(option_type)
        fields = MappingProxyType({field: raw[field] for field in expected_shape if field != "type"})
        fingerprint = hashlib.sha256(canonical_json_v1_bytes(raw)).hexdigest().upper()
        return UcisOptionView(
            index=index,
            option_type_raw=option_type,
            option_type_name=row.option_type_names[option_index],
            fields=fields,
            semantic_fingerprint=fingerprint,
        )


__all__ = [
    "UcisDeveloperSdk",
    "UcisOptionView",
    "UcisSdkError",
    "UcisSelectionView",
]
