from __future__ import annotations

from dataclasses import dataclass
import hashlib
from pathlib import Path
from types import MappingProxyType
from typing import Any, Mapping, Sequence

from .source_lock import canonical_json_v1_bytes, load_json_bytes_strict


class UcisError(ValueError):
    """Stable fail-closed UCIS contract error."""


def _fail(code: str) -> None:
    raise UcisError(code)


def _strict_keys(value: Mapping[str, Any], allowed: frozenset[str], code: str) -> None:
    if set(value) != set(allowed):
        _fail(code)


def _sha(value: Any) -> str:
    return hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()


def _sha_text(value: Any) -> str:
    if type(value) is not str or len(value) != 64 or value != value.upper():
        _fail("ucis_invalid_source_hash")
    if any(character not in "0123456789ABCDEF" for character in value):
        _fail("ucis_invalid_source_hash")
    return value


@dataclass(frozen=True)
class UcisContextRow:
    context_raw: int
    context_name: str
    select_type_raw: int
    select_type_name: str
    option_types: tuple[int, ...]
    option_type_names: tuple[str, ...]


@dataclass(frozen=True)
class UcisPrimitive:
    name: str
    contexts: tuple[int, ...]
    quantity_encodings: tuple[str, ...]
    composition_role: str


class UcisRegistry:
    def __init__(self, document: Mapping[str, Any]) -> None:
        if document.get("document_type") != "ptcgdap_ucis_registry_v1":
            _fail("ucis_registry_document_type_invalid")
        if document.get("schema_version") != 1:
            _fail("ucis_registry_schema_version_invalid")
        self.contract_generation = int(document.get("contract_generation", -1))
        self.ucis_generation = int(document.get("ucis_generation", -1))
        self.source_census_sha256 = _sha_text(document.get("source_census_sha256"))
        contexts: dict[int, UcisContextRow] = {}
        for raw_row in document.get("context_rows", []):
            if type(raw_row) is not dict:
                _fail("ucis_registry_context_row_invalid")
            raw = raw_row.get("context_raw")
            select_type = raw_row.get("select_type_raw")
            context_name = raw_row.get("context_name")
            select_type_name = raw_row.get("select_type_name")
            option_types = raw_row.get("option_type_raw")
            option_type_names = raw_row.get("option_type_names")
            if (
                type(raw) is not int
                or type(context_name) is not str
                or not context_name
                or type(select_type) is not int
                or type(select_type_name) is not str
                or not select_type_name
                or type(option_types) is not list
                or type(option_type_names) is not list
                or len(option_types) != len(option_type_names)
            ):
                _fail("ucis_registry_context_row_invalid")
            if any(type(value) is not int for value in option_types) or any(
                type(value) is not str or not value for value in option_type_names
            ):
                _fail("ucis_registry_context_row_invalid")
            if raw in contexts:
                _fail("ucis_registry_context_duplicate")
            contexts[raw] = UcisContextRow(
                raw,
                context_name,
                select_type,
                select_type_name,
                tuple(option_types),
                tuple(option_type_names),
            )
        option_shapes: dict[int, tuple[str, ...]] = {}
        for key, value in document.get("option_sparse_shapes", {}).items():
            if (
                type(key) is not str
                or not key.isdigit()
                or type(value) is not list
                or any(type(field) is not str or not field for field in value)
            ):
                _fail("ucis_registry_option_shape_invalid")
            option_shapes[int(key)] = tuple(value)
        primitives: dict[str, UcisPrimitive] = {}
        for raw in document.get("primitives", []):
            if type(raw) is not dict:
                _fail("ucis_registry_primitive_invalid")
            name = raw.get("primitive")
            context_values = raw.get("contexts")
            quantities = raw.get("quantity_encodings")
            role = raw.get("composition_role")
            if (
                type(name) is not str
                or type(context_values) is not list
                or any(type(value) is not int for value in context_values)
                or type(quantities) is not list
                or not quantities
                or any(type(value) is not str for value in quantities)
                or type(role) is not str
            ):
                _fail("ucis_registry_primitive_invalid")
            if name in primitives or name == "CustomInteraction":
                _fail("ucis_registry_primitive_invalid")
            primitives[name] = UcisPrimitive(name, tuple(context_values), tuple(quantities), role)
        if set(contexts) != set(range(49)) or set(option_shapes) != set(range(17)):
            _fail("ucis_registry_wire_census_incomplete")
        if len(primitives) != 16:
            _fail("ucis_registry_primitive_census_incomplete")
        self.context_rows = MappingProxyType(contexts)
        self.context_names = MappingProxyType({row.context_name: row for row in contexts.values()})
        self.option_shapes = MappingProxyType(option_shapes)
        self.primitives = MappingProxyType(primitives)
        self.document_hash = _sha(document)

    @classmethod
    def load(cls, repository_root: str | Path) -> "UcisRegistry":
        root = Path(repository_root).resolve()
        registry_path = root / "contracts/ptcgdap/ucis_registry_v1.json"
        bundle_path = root / "contracts/ptcgdap/ucis_bundle_v1.json"
        registry = load_json_bytes_strict(registry_path.read_bytes())
        bundle = load_json_bytes_strict(bundle_path.read_bytes())
        if bundle.get("document_type") != "ptcgdap_ucis_bundle_v1":
            _fail("ucis_bundle_document_type_invalid")
        files = bundle.get("files")
        if type(files) is not list:
            _fail("ucis_bundle_files_invalid")
        registry_entry = next(
            (entry for entry in files if entry.get("path") == "contracts/ptcgdap/ucis_registry_v1.json"),
            None,
        )
        if type(registry_entry) is not dict or registry_entry.get("canonical_sha256") != _sha(registry):
            _fail("ucis_bundle_registry_hash_invalid")
        return cls(registry)


_STEP_FIELDS = frozenset(
    {
        "step_id",
        "primitive",
        "context_name",
        "option_type_name",
        "source_zone_query",
        "candidate_predicate",
        "target_predicate",
        "quantity_encoding",
        "min_rule",
        "max_rule",
        "remaining_debt_rule",
        "public_context_projection",
        "private_binding_recipe",
        "commit_command_kind",
        "next_checkpoint_rule",
        "unsupported_if",
        "capability_ids",
    }
)


@dataclass(frozen=True)
class CardEffectStepSpec:
    step_id: str
    primitive: str
    context_name: str
    option_type_name: str
    source_zone_query: str
    candidate_predicate: str
    target_predicate: str
    quantity_encoding: str
    min_rule: str
    max_rule: str
    remaining_debt_rule: str
    public_context_projection: str
    private_binding_recipe: str
    commit_command_kind: str
    next_checkpoint_rule: str
    unsupported_if: tuple[str, ...]
    capability_ids: tuple[str, ...]

    @classmethod
    def from_mapping(cls, raw: Mapping[str, Any]) -> "CardEffectStepSpec":
        if type(raw) is not dict:
            _fail("ucis_step_spec_invalid")
        _strict_keys(raw, _STEP_FIELDS, "ucis_step_spec_fields_invalid")
        string_fields = (
            "step_id",
            "primitive",
            "context_name",
            "option_type_name",
            "source_zone_query",
            "candidate_predicate",
            "target_predicate",
            "quantity_encoding",
            "min_rule",
            "max_rule",
            "remaining_debt_rule",
            "public_context_projection",
            "private_binding_recipe",
            "commit_command_kind",
            "next_checkpoint_rule",
        )
        if any(type(raw.get(key)) is not str or not raw[key] for key in string_fields):
            _fail("ucis_step_spec_string_invalid")
        unsupported = raw.get("unsupported_if")
        capabilities = raw.get("capability_ids")
        if (
            type(unsupported) is not list
            or any(type(value) is not str or not value for value in unsupported)
            or type(capabilities) is not list
            or not capabilities
            or any(type(value) is not str or not value for value in capabilities)
        ):
            _fail("ucis_step_spec_capability_invalid")
        return cls(
            step_id=raw["step_id"],
            primitive=raw["primitive"],
            context_name=raw["context_name"],
            option_type_name=raw["option_type_name"],
            source_zone_query=raw["source_zone_query"],
            candidate_predicate=raw["candidate_predicate"],
            target_predicate=raw["target_predicate"],
            quantity_encoding=raw["quantity_encoding"],
            min_rule=raw["min_rule"],
            max_rule=raw["max_rule"],
            remaining_debt_rule=raw["remaining_debt_rule"],
            public_context_projection=raw["public_context_projection"],
            private_binding_recipe=raw["private_binding_recipe"],
            commit_command_kind=raw["commit_command_kind"],
            next_checkpoint_rule=raw["next_checkpoint_rule"],
            unsupported_if=tuple(unsupported),
            capability_ids=tuple(capabilities),
        )


_EFFECT_FIELDS = frozenset(
    {
        "schema_version",
        "effect_ref",
        "resolution_kind",
        "program_kind",
        "capability_ids",
        "steps",
        "chooser_rule",
        "visibility_rule",
        "lifecycle_anchor",
        "continuation_rule",
        "stop_rule",
        "information_checkpoints",
        "source_hash",
        "unsupported_reason",
    }
)


@dataclass(frozen=True)
class CardEffectSpec:
    schema_version: int
    effect_ref: str
    resolution_kind: str
    program_kind: str
    capability_ids: tuple[str, ...]
    steps: tuple[CardEffectStepSpec, ...]
    chooser_rule: str
    visibility_rule: str
    lifecycle_anchor: str
    continuation_rule: str
    stop_rule: str
    information_checkpoints: tuple[str, ...]
    source_hash: str
    unsupported_reason: str

    @classmethod
    def from_mapping(cls, raw: Mapping[str, Any]) -> "CardEffectSpec":
        if type(raw) is not dict:
            _fail("ucis_effect_spec_invalid")
        allowed = _EFFECT_FIELDS if "unsupported_reason" in raw else _EFFECT_FIELDS - {"unsupported_reason"}
        _strict_keys(raw, frozenset(allowed), "ucis_effect_spec_fields_invalid")
        if raw.get("schema_version") != 1:
            _fail("ucis_effect_spec_version_invalid")
        resolution = raw.get("resolution_kind")
        if resolution not in {"interactive", "automatic_resolution", "unsupported_interaction_shape"}:
            _fail("ucis_effect_spec_resolution_invalid")
        required_strings = (
            "effect_ref",
            "program_kind",
            "chooser_rule",
            "visibility_rule",
            "lifecycle_anchor",
            "continuation_rule",
            "stop_rule",
        )
        if any(type(raw.get(key)) is not str or not raw[key] for key in required_strings):
            _fail("ucis_effect_spec_string_invalid")
        capabilities = raw.get("capability_ids")
        steps = raw.get("steps")
        checkpoints = raw.get("information_checkpoints")
        if (
            type(capabilities) is not list
            or any(type(value) is not str or not value for value in capabilities)
            or type(steps) is not list
            or type(checkpoints) is not list
            or any(type(value) is not str or not value for value in checkpoints)
        ):
            _fail("ucis_effect_spec_collection_invalid")
        parsed_steps = tuple(CardEffectStepSpec.from_mapping(value) for value in steps)
        if resolution == "interactive" and (not parsed_steps or not capabilities):
            _fail("ucis_interactive_effect_empty")
        if resolution != "interactive" and parsed_steps:
            _fail("ucis_noninteractive_effect_has_steps")
        reason = raw.get("unsupported_reason", "")
        if type(reason) is not str:
            _fail("ucis_unsupported_reason_invalid")
        if resolution == "unsupported_interaction_shape" and not reason:
            _fail("ucis_unsupported_reason_required")
        return cls(
            schema_version=1,
            effect_ref=raw["effect_ref"],
            resolution_kind=resolution,
            program_kind=raw["program_kind"],
            capability_ids=tuple(capabilities),
            steps=parsed_steps,
            chooser_rule=raw["chooser_rule"],
            visibility_rule=raw["visibility_rule"],
            lifecycle_anchor=raw["lifecycle_anchor"],
            continuation_rule=raw["continuation_rule"],
            stop_rule=raw["stop_rule"],
            information_checkpoints=tuple(checkpoints),
            source_hash=_sha_text(raw.get("source_hash")),
            unsupported_reason=reason,
        )


@dataclass(frozen=True)
class CompiledInteractionStep:
    step_id: str
    primitive: str
    select_type_raw: int
    context_raw: int
    option_type_raw: int
    source_zone_query: str
    candidate_predicate: str
    target_predicate: str
    quantity_encoding: str
    min_rule: str
    max_rule: str
    remaining_debt_rule: str
    public_context_projection: str
    private_binding_recipe: str
    commit_command_kind: str
    next_checkpoint_rule: str
    unsupported_if: tuple[str, ...]
    capability_ids: tuple[str, ...]


@dataclass(frozen=True)
class CompiledInteractionProgram:
    source_effect_ref: str
    program_kind: str
    capability_ids: tuple[str, ...]
    ordered_steps: tuple[CompiledInteractionStep, ...]
    chooser_rule: str
    visibility_rule: str
    lifecycle_anchor: str
    continuation_rule: str
    stop_rule: str
    information_checkpoints: tuple[str, ...]
    contract_generation: int
    compiler_generation: int
    source_hash: str
    status: str
    unsupported_reason: str
    program_hash: str

    @property
    def effect_ref(self) -> str:
        """Compatibility alias; canonical language-neutral field is source_effect_ref."""
        return self.source_effect_ref

    @property
    def steps(self) -> tuple[CompiledInteractionStep, ...]:
        """Compatibility alias; canonical language-neutral field is ordered_steps."""
        return self.ordered_steps

    def to_mapping(self) -> dict[str, Any]:
        return {
            "source_effect_ref": self.source_effect_ref,
            "program_kind": self.program_kind,
            "capability_ids": list(self.capability_ids),
            "ordered_steps": [
                step.__dict__
                | {
                    "unsupported_if": list(step.unsupported_if),
                    "capability_ids": list(step.capability_ids),
                }
                for step in self.ordered_steps
            ],
            "chooser_rule": self.chooser_rule,
            "visibility_rule": self.visibility_rule,
            "lifecycle_anchor": self.lifecycle_anchor,
            "continuation_rule": self.continuation_rule,
            "stop_rule": self.stop_rule,
            "information_checkpoints": list(self.information_checkpoints),
            "contract_generation": self.contract_generation,
            "compiler_generation": self.compiler_generation,
            "source_hash": self.source_hash,
            "status": self.status,
            "unsupported_reason": self.unsupported_reason,
            "program_hash": self.program_hash,
        }


class UcisCompiler:
    def __init__(self, registry: UcisRegistry) -> None:
        if type(registry) is not UcisRegistry:
            _fail("ucis_registry_owner_required")
        self._registry = registry

    def compile_effect(self, spec: CardEffectSpec) -> CompiledInteractionProgram:
        if type(spec) is not CardEffectSpec:
            _fail("ucis_effect_spec_owner_required")
        if spec.resolution_kind == "interactive":
            compiled_steps = self._compile_interactive_steps(spec)
            status = "compiled"
        elif spec.resolution_kind == "automatic_resolution":
            compiled_steps = ()
            status = "automatic"
        else:
            compiled_steps = ()
            status = "unsupported"
        payload = {
            "source_effect_ref": spec.effect_ref,
            "program_kind": spec.program_kind,
            "capability_ids": list(spec.capability_ids),
            "ordered_steps": [
                step.__dict__
                | {
                    "unsupported_if": list(step.unsupported_if),
                    "capability_ids": list(step.capability_ids),
                }
                for step in compiled_steps
            ],
            "chooser_rule": spec.chooser_rule,
            "visibility_rule": spec.visibility_rule,
            "lifecycle_anchor": spec.lifecycle_anchor,
            "continuation_rule": spec.continuation_rule,
            "stop_rule": spec.stop_rule,
            "information_checkpoints": list(spec.information_checkpoints),
            "contract_generation": self._registry.contract_generation,
            "compiler_generation": self._registry.ucis_generation,
            "source_hash": spec.source_hash,
            "status": status,
            "unsupported_reason": spec.unsupported_reason,
        }
        return CompiledInteractionProgram(
            source_effect_ref=spec.effect_ref,
            program_kind=spec.program_kind,
            capability_ids=spec.capability_ids,
            ordered_steps=compiled_steps,
            chooser_rule=spec.chooser_rule,
            visibility_rule=spec.visibility_rule,
            lifecycle_anchor=spec.lifecycle_anchor,
            continuation_rule=spec.continuation_rule,
            stop_rule=spec.stop_rule,
            information_checkpoints=spec.information_checkpoints,
            contract_generation=self._registry.contract_generation,
            compiler_generation=self._registry.ucis_generation,
            source_hash=spec.source_hash,
            status=status,
            unsupported_reason=spec.unsupported_reason,
            program_hash=_sha(payload),
        )

    def validate_program(self, raw: Mapping[str, Any]) -> CompiledInteractionProgram:
        """Parse the exact language-neutral program document and verify its hash."""
        if type(raw) is not dict:
            _fail("ucis_program_document_invalid")
        fields = frozenset(
            {
                "program_kind",
                "capability_ids",
                "source_effect_ref",
                "chooser_rule",
                "visibility_rule",
                "lifecycle_anchor",
                "ordered_steps",
                "continuation_rule",
                "stop_rule",
                "information_checkpoints",
                "contract_generation",
                "compiler_generation",
                "source_hash",
                "status",
                "unsupported_reason",
                "program_hash",
            }
        )
        _strict_keys(raw, fields, "ucis_program_fields_invalid")
        status = raw.get("status")
        if status not in {"compiled", "automatic", "unsupported"}:
            _fail("ucis_program_status_invalid")
        strings = (
            "program_kind",
            "source_effect_ref",
            "chooser_rule",
            "visibility_rule",
            "lifecycle_anchor",
            "continuation_rule",
            "stop_rule",
        )
        if any(type(raw.get(field)) is not str or not raw[field] for field in strings):
            _fail("ucis_program_string_invalid")
        capabilities = raw.get("capability_ids")
        checkpoints = raw.get("information_checkpoints")
        ordered_steps = raw.get("ordered_steps")
        if (
            type(capabilities) is not list
            or any(type(value) is not str or not value for value in capabilities)
            or len(capabilities) != len(set(capabilities))
            or any(value not in self._registry.primitives for value in capabilities)
            or type(checkpoints) is not list
            or any(type(value) is not str or not value for value in checkpoints)
            or type(ordered_steps) is not list
        ):
            _fail("ucis_program_collection_invalid")
        if (
            type(raw.get("contract_generation")) is not int
            or raw.get("contract_generation") != self._registry.contract_generation
            or type(raw.get("compiler_generation")) is not int
            or raw.get("compiler_generation") != self._registry.ucis_generation
        ):
            _fail("ucis_contract_generation_drift")
        source_hash = _sha_text(raw.get("source_hash"))
        unsupported_reason = raw.get("unsupported_reason")
        if type(unsupported_reason) is not str:
            _fail("ucis_unsupported_reason_invalid")
        parsed_steps = tuple(self._parse_compiled_step(value) for value in ordered_steps)
        if status == "compiled":
            if not parsed_steps or raw["program_kind"] not in self._registry.primitives:
                _fail("ucis_compiled_program_empty")
            if not set(step.primitive for step in parsed_steps).issubset(set(capabilities)):
                _fail("ucis_program_capability_closure_invalid")
        elif parsed_steps:
            _fail("ucis_noncompiled_program_has_steps")
        if status == "unsupported" and not unsupported_reason:
            _fail("ucis_unsupported_reason_required")
        program_hash = _sha_text(raw.get("program_hash"))
        payload = dict(raw)
        payload.pop("program_hash")
        if _sha(payload) != program_hash:
            _fail("ucis_program_hash_invalid")
        return CompiledInteractionProgram(
            source_effect_ref=raw["source_effect_ref"],
            program_kind=raw["program_kind"],
            capability_ids=tuple(capabilities),
            ordered_steps=parsed_steps,
            chooser_rule=raw["chooser_rule"],
            visibility_rule=raw["visibility_rule"],
            lifecycle_anchor=raw["lifecycle_anchor"],
            continuation_rule=raw["continuation_rule"],
            stop_rule=raw["stop_rule"],
            information_checkpoints=tuple(checkpoints),
            contract_generation=raw["contract_generation"],
            compiler_generation=raw["compiler_generation"],
            source_hash=source_hash,
            status=status,
            unsupported_reason=unsupported_reason,
            program_hash=program_hash,
        )

    def _parse_compiled_step(self, raw: Any) -> CompiledInteractionStep:
        if type(raw) is not dict:
            _fail("ucis_compiled_step_invalid")
        fields = frozenset(CompiledInteractionStep.__dataclass_fields__)
        _strict_keys(raw, fields, "ucis_compiled_step_fields_invalid")
        string_fields = fields - {"select_type_raw", "context_raw", "option_type_raw", "unsupported_if", "capability_ids"}
        if any(type(raw.get(field)) is not str or not raw[field] for field in string_fields):
            _fail("ucis_compiled_step_string_invalid")
        if any(type(raw.get(field)) is not int for field in ("select_type_raw", "context_raw", "option_type_raw")):
            _fail("ucis_compiled_step_registry_invalid")
        row = self._registry.context_rows.get(raw.get("context_raw"))
        primitive = self._registry.primitives.get(raw.get("primitive"))
        if row is None or primitive is None:
            _fail("ucis_compiled_step_registry_invalid")
        if (
            raw.get("select_type_raw") != row.select_type_raw
            or raw.get("option_type_raw") not in row.option_types
            or row.context_raw not in primitive.contexts
            or raw.get("quantity_encoding") not in primitive.quantity_encodings
            or raw.get("next_checkpoint_rule") != "fresh_reobserve"
        ):
            _fail("ucis_compiled_step_registry_invalid")
        unsupported = raw.get("unsupported_if")
        capabilities = raw.get("capability_ids")
        if (
            type(unsupported) is not list
            or any(type(value) is not str or not value for value in unsupported)
            or type(capabilities) is not list
            or not capabilities
            or any(type(value) is not str or not value for value in capabilities)
            or len(capabilities) != len(set(capabilities))
            or any(value not in self._registry.primitives for value in capabilities)
        ):
            _fail("ucis_compiled_step_capability_invalid")
        return CompiledInteractionStep(
            **{
                **{field: raw[field] for field in string_fields},
                "select_type_raw": raw["select_type_raw"],
                "context_raw": raw["context_raw"],
                "option_type_raw": raw["option_type_raw"],
                "unsupported_if": tuple(unsupported),
                "capability_ids": tuple(capabilities),
            }
        )

    def _compile_interactive_steps(
        self, spec: CardEffectSpec
    ) -> tuple[CompiledInteractionStep, ...]:
        if spec.program_kind not in self._registry.primitives:
            _fail("ucis_unknown_primitive")
        seen: set[str] = set()
        compiled: list[CompiledInteractionStep] = []
        for step in spec.steps:
            if step.step_id in seen:
                _fail("ucis_duplicate_step_id")
            seen.add(step.step_id)
            primitive = self._registry.primitives.get(step.primitive)
            if primitive is None or step.primitive == "CustomInteraction":
                _fail("ucis_unknown_primitive")
            row = self._registry.context_names.get(step.context_name)
            if row is None:
                _fail("ucis_unknown_context")
            if row.context_raw not in primitive.contexts:
                _fail("ucis_primitive_context_mismatch")
            if step.option_type_name not in row.option_type_names:
                _fail("ucis_context_option_mismatch")
            if step.quantity_encoding not in primitive.quantity_encodings:
                _fail("ucis_quantity_encoding_mismatch")
            if not set(step.capability_ids).issubset(set(spec.capability_ids)):
                _fail("ucis_step_capability_not_declared")
            if step.next_checkpoint_rule != "fresh_reobserve":
                _fail("ucis_stale_continuation_forbidden")
            option_index = row.option_type_names.index(step.option_type_name)
            compiled.append(
                CompiledInteractionStep(
                    step_id=step.step_id,
                    primitive=step.primitive,
                    select_type_raw=row.select_type_raw,
                    context_raw=row.context_raw,
                    option_type_raw=row.option_types[option_index],
                    source_zone_query=step.source_zone_query,
                    candidate_predicate=step.candidate_predicate,
                    target_predicate=step.target_predicate,
                    quantity_encoding=step.quantity_encoding,
                    min_rule=step.min_rule,
                    max_rule=step.max_rule,
                    remaining_debt_rule=step.remaining_debt_rule,
                    public_context_projection=step.public_context_projection,
                    private_binding_recipe=step.private_binding_recipe,
                    commit_command_kind=step.commit_command_kind,
                    next_checkpoint_rule=step.next_checkpoint_rule,
                    unsupported_if=step.unsupported_if,
                    capability_ids=step.capability_ids,
                )
            )
        return tuple(compiled)


@dataclass(frozen=True)
class WindowDraft:
    step: CompiledInteractionStep
    public_state_hash: str
    observation_generation: int
    ordered_option_fingerprints: tuple[str, ...]
    min_count: int
    max_count: int
    remain_damage_counter: int | None
    remain_energy_cost: int | None


@dataclass
class ProgramInstance:
    program: CompiledInteractionProgram
    effect_instance_ref: str
    cursor: int = 0
    remaining_debt: int = 0
    semantic_refs: tuple[str, ...] = ()
    observation_generation: int = -1

    def next_step(self, current_engine_state: Mapping[str, Any]) -> WindowDraft | str:
        if self.program.status == "automatic":
            return "AUTO"
        if self.program.status == "unsupported":
            return "UNSUPPORTED"
        if self.cursor >= len(self.program.steps):
            return "COMPLETE"
        if type(current_engine_state) is not dict:
            _fail("ucis_current_state_invalid")
        if set(current_engine_state) != {
            "observation_generation",
            "public_state_hash",
            "legality",
        }:
            _fail("ucis_public_projection_rejected")
        generation = current_engine_state.get("observation_generation")
        public_state_hash = current_engine_state.get("public_state_hash")
        legality = current_engine_state.get("legality")
        if (
            type(generation) is not int
            or generation < 0
            or generation < self.observation_generation
            or type(public_state_hash) is not str
            or type(legality) is not dict
        ):
            _fail("ucis_current_state_invalid")
        _sha_text(public_state_hash)
        allowed_legality = {
            "ordered_option_fingerprints",
            "min_count",
            "max_count",
            "remain_damage_counter",
            "remain_energy_cost",
        }
        if not set(legality).issubset(allowed_legality) or not {
            "ordered_option_fingerprints",
            "min_count",
            "max_count",
        }.issubset(legality):
            _fail("ucis_public_projection_rejected")
        fingerprints = legality.get("ordered_option_fingerprints")
        minimum = legality.get("min_count")
        maximum = legality.get("max_count")
        if (
            type(fingerprints) is not list
            or any(type(value) is not str or not value for value in fingerprints)
            or type(minimum) is not int
            or type(maximum) is not int
            or minimum < 0
            or maximum < minimum
            or maximum > len(fingerprints)
        ):
            _fail("ucis_current_legality_invalid")
        self.observation_generation = generation
        return WindowDraft(
            step=self.program.steps[self.cursor],
            public_state_hash=public_state_hash,
            observation_generation=generation,
            ordered_option_fingerprints=tuple(fingerprints),
            min_count=minimum,
            max_count=maximum,
            remain_damage_counter=_optional_nonnegative_int(
                legality.get("remain_damage_counter"), "ucis_current_legality_invalid"
            ),
            remain_energy_cost=_optional_nonnegative_int(
                legality.get("remain_energy_cost"), "ucis_current_legality_invalid"
            ),
        )

    def advance_after_reobserve(
        self,
        fresh_engine_state: Mapping[str, Any],
        *,
        paid: int = 0,
        semantic_refs: Sequence[str] = (),
    ) -> None:
        if type(paid) is not int or paid < 0:
            _fail("ucis_invalid_paid_debt")
        if any(type(value) is not str or not value for value in semantic_refs):
            _fail("ucis_invalid_semantic_ref")
        if type(fresh_engine_state) is not dict:
            _fail("ucis_fresh_reobserve_required")
        if set(fresh_engine_state) != {"observation_generation", "public_state_hash"}:
            _fail("ucis_public_projection_rejected")
        generation = fresh_engine_state.get("observation_generation")
        public_state_hash = fresh_engine_state.get("public_state_hash")
        if type(generation) is not int or generation <= self.observation_generation:
            _fail("ucis_fresh_reobserve_required")
        _sha_text(public_state_hash)
        self.remaining_debt = max(0, self.remaining_debt - paid)
        self.semantic_refs = tuple(semantic_refs)
        self.observation_generation = generation
        self.cursor += 1


def _optional_nonnegative_int(value: Any, code: str) -> int | None:
    if value is None:
        return None
    if type(value) is not int or value < 0:
        _fail(code)
    return value


def begin_program(
    program: CompiledInteractionProgram, effect_instance_ref: str
) -> ProgramInstance:
    if type(program) is not CompiledInteractionProgram:
        _fail("ucis_compiled_program_required")
    if type(effect_instance_ref) is not str or not effect_instance_ref:
        _fail("ucis_effect_instance_ref_required")
    return ProgramInstance(program=program, effect_instance_ref=effect_instance_ref)


__all__ = [
    "CardEffectSpec",
    "CardEffectStepSpec",
    "CompiledInteractionStep",
    "CompiledInteractionProgram",
    "ProgramInstance",
    "UcisCompiler",
    "UcisError",
    "UcisPrimitive",
    "UcisRegistry",
    "WindowDraft",
    "begin_program",
]
