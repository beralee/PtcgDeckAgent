#!/usr/bin/env python3
"""Static compiler for PTCG turn-construction puzzle design graphs."""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict, deque
from dataclasses import dataclass
from pathlib import Path
from typing import Any


CONTROL_KINDS = {
    "state",
    "player_decision",
    "action",
    "opponent_decision",
    "information",
    "terminal",
}
DOMAIN_KINDS = {"resource", "threat", "invariant"}
NODE_KINDS = CONTROL_KINDS | DOMAIN_KINDS
CONTROL_EDGES = {"opens", "option", "reply", "outcome", "resolves", "reaches"}
SEMANTIC_EDGES = {
    "consumes",
    "reserves",
    "enables",
    "counters",
    "exposes",
    "constrains",
    "satisfies",
    "violates",
    "requires",
}
EDGE_TYPES = CONTROL_EDGES | SEMANTIC_EDGES
INVARIANT_CATEGORIES = {
    "progress",
    "disruption",
    "survival",
    "deny_opponent_win",
    "handoff",
}
PROFILE_REQUIREMENTS = {
    "precision": {
        "initial_options": 2,
        "scarce_resources": 2,
        "invariants": {"progress"},
        "bench_required": False,
        "and_reply_required": False,
        "delayed_failure_required": False,
    },
    "deployment": {
        "initial_options": 3,
        "scarce_resources": 3,
        "invariants": {"progress", "survival", "handoff"},
        "bench_required": True,
        "and_reply_required": True,
        "delayed_failure_required": True,
    },
    "composite": {
        "initial_options": 3,
        "scarce_resources": 3,
        "invariants": INVARIANT_CATEGORIES,
        "bench_required": True,
        "and_reply_required": True,
        "delayed_failure_required": True,
    },
}


@dataclass
class Issue:
    severity: str
    code: str
    message: str


class GraphAuditor:
    def __init__(self, graph: dict[str, Any]) -> None:
        self.graph = graph
        self.issues: list[Issue] = []
        self.nodes: dict[str, dict[str, Any]] = {}
        self.edges: list[dict[str, Any]] = []
        self.outgoing: dict[str, list[dict[str, Any]]] = defaultdict(list)
        self.incoming: dict[str, list[dict[str, Any]]] = defaultdict(list)
        self.profile = str(graph.get("profile", ""))
        self.requirements = PROFILE_REQUIREMENTS.get(self.profile)

    def error(self, code: str, message: str) -> None:
        self.issues.append(Issue("ERROR", code, message))

    def warn(self, code: str, message: str) -> None:
        self.issues.append(Issue("WARN", code, message))

    def audit(self) -> list[Issue]:
        self._load_structure()
        if not self.nodes:
            return self.issues
        self._check_header()
        self._check_nodes()
        self._check_edges()
        self._check_routing()
        self._check_reachability()
        self._check_domain_contract()
        self._check_profile_gates()
        self._check_proof_contract()
        self._evaluate_root()
        return self.issues

    def _load_structure(self) -> None:
        raw_nodes = self.graph.get("nodes")
        raw_edges = self.graph.get("edges")
        if not isinstance(raw_nodes, list):
            self.error("schema.nodes", "`nodes` must be an array.")
            return
        if not isinstance(raw_edges, list):
            self.error("schema.edges", "`edges` must be an array.")
            return

        for index, node in enumerate(raw_nodes):
            if not isinstance(node, dict):
                self.error("schema.node", f"nodes[{index}] must be an object.")
                continue
            node_id = str(node.get("id", "")).strip()
            if not node_id:
                self.error("node.id", f"nodes[{index}] has no id.")
                continue
            if node_id in self.nodes:
                self.error("node.duplicate", f"Duplicate node id: {node_id}")
                continue
            self.nodes[node_id] = node

        for index, edge in enumerate(raw_edges):
            if not isinstance(edge, dict):
                self.error("schema.edge", f"edges[{index}] must be an object.")
                continue
            self.edges.append(edge)
            source = str(edge.get("from", "")).strip()
            target = str(edge.get("to", "")).strip()
            if source:
                self.outgoing[source].append(edge)
            if target:
                self.incoming[target].append(edge)

    def _check_header(self) -> None:
        required = ("format_version", "puzzle_id", "deck_id", "revision", "profile", "start", "proof")
        for key in required:
            if key not in self.graph:
                self.error("header.missing", f"Missing top-level field: {key}")
        if self.graph.get("format_version") != 1:
            self.error("header.version", "`format_version` must be 1.")
        if self.requirements is None:
            self.error(
                "header.profile",
                "`profile` must be precision, deployment, or composite.",
            )
        start = str(self.graph.get("start", ""))
        if start not in self.nodes:
            self.error("header.start", f"Start node does not exist: {start}")
        elif self.nodes[start].get("kind") != "state":
            self.error("header.start_kind", "Start node must have kind `state`.")

    def _require_fields(self, node: dict[str, Any], fields: tuple[str, ...]) -> None:
        node_id = str(node.get("id", "<unknown>"))
        for field in fields:
            value = node.get(field)
            if value is None or value == "":
                self.error("node.field", f"{node_id} is missing `{field}`.")

    def _check_nodes(self) -> None:
        for node_id, node in self.nodes.items():
            kind = node.get("kind")
            if kind not in NODE_KINDS:
                self.error("node.kind", f"{node_id} has unknown kind: {kind}")
                continue
            self._require_fields(node, ("label",))
            if kind == "state":
                self._require_fields(node, ("fingerprint", "checkpoint"))
            elif kind == "player_decision":
                self._require_fields(node, ("operator", "axis"))
                if node.get("operator") != "OR":
                    self.error("decision.player_operator", f"{node_id} must use OR.")
            elif kind == "opponent_decision":
                self._require_fields(node, ("operator", "coverage_basis"))
                if node.get("operator") not in {"AND", "FROZEN"}:
                    self.error(
                        "decision.opponent_operator",
                        f"{node_id} must use AND or FROZEN.",
                    )
                if node.get("operator") == "FROZEN":
                    self.warn(
                        "decision.frozen_policy",
                        f"{node_id} can prove only policy replay, not adversarial coverage.",
                    )
            elif kind == "action":
                self._require_fields(
                    node,
                    ("actor", "axis", "legal_guard", "effect_summary"),
                )
                if node.get("actor") not in {"player", "opponent", "system"}:
                    self.error("action.actor", f"{node_id} has invalid actor.")
            elif kind == "information":
                self._require_fields(node, ("operator", "epoch", "source"))
                if node.get("operator") not in {"DETERMINISTIC", "AND"}:
                    self.error("information.operator", f"{node_id} has invalid operator.")
            elif kind == "terminal":
                self._require_fields(node, ("outcome", "reason"))
                if node.get("outcome") not in {"success", "failure"}:
                    self.error("terminal.outcome", f"{node_id} has invalid outcome.")
                if node.get("outcome") == "failure":
                    self._require_fields(node, ("failure_axis", "consequence_depth"))
            elif kind == "resource":
                self._require_fields(
                    node,
                    (
                        "resource_type",
                        "available",
                        "minimum_required",
                        "slack",
                        "deadline",
                        "scarce",
                    ),
                )
            elif kind == "threat":
                self._require_fields(node, ("visibility", "evidence", "deadline", "impact"))
                if node.get("visibility") not in {"public", "history", "deduced"}:
                    self.error(
                        "threat.visibility",
                        f"{node_id} must be public, history, or deduced.",
                    )
            elif kind == "invariant":
                self._require_fields(node, ("category", "assertion"))
                if node.get("category") not in INVARIANT_CATEGORIES:
                    self.error(
                        "invariant.category",
                        f"{node_id} has unknown invariant category.",
                    )

    def _check_edges(self) -> None:
        for index, edge in enumerate(self.edges):
            source = str(edge.get("from", "")).strip()
            target = str(edge.get("to", "")).strip()
            edge_type = edge.get("type")
            if source not in self.nodes:
                self.error("edge.source", f"edges[{index}] has missing source: {source}")
            if target not in self.nodes:
                self.error("edge.target", f"edges[{index}] has missing target: {target}")
            if edge_type not in EDGE_TYPES:
                self.error("edge.type", f"edges[{index}] has unknown type: {edge_type}")

    def _control_out(self, node_id: str) -> list[dict[str, Any]]:
        return [edge for edge in self.outgoing[node_id] if edge.get("type") in CONTROL_EDGES]

    def _check_routing(self) -> None:
        for node_id, node in self.nodes.items():
            kind = node.get("kind")
            control = self._control_out(node_id)
            types = {edge.get("type") for edge in control}
            expected: set[str] = set()
            if kind == "state":
                expected = {"opens", "reaches"}
                if len(control) != 1:
                    self.error(
                        "routing.state",
                        f"{node_id} must have exactly one control edge.",
                    )
            elif kind == "player_decision":
                expected = {"option"}
                if len(control) < 2:
                    self.error(
                        "routing.player_options",
                        f"{node_id} needs at least two options.",
                    )
            elif kind == "opponent_decision":
                expected = {"reply"}
                if not control:
                    self.error("routing.opponent_replies", f"{node_id} has no replies.")
            elif kind == "information":
                expected = {"outcome"}
                minimum = 1 if node.get("operator") == "DETERMINISTIC" else 2
                if len(control) < minimum:
                    self.error(
                        "routing.information_outcomes",
                        f"{node_id} needs at least {minimum} outcome(s).",
                    )
                if node.get("operator") == "DETERMINISTIC" and len(control) != 1:
                    self.error(
                        "routing.deterministic",
                        f"{node_id} must have exactly one deterministic outcome.",
                    )
            elif kind == "action":
                expected = {"resolves"}
                if len(control) != 1:
                    self.error(
                        "routing.action",
                        f"{node_id} must resolve to exactly one node.",
                    )
            elif kind in {"terminal", "resource", "threat", "invariant"}:
                if control:
                    self.error(
                        "routing.leaf",
                        f"{node_id} may not have outgoing control edges.",
                    )
            if types and not types.issubset(expected):
                self.error(
                    "routing.edge_kind",
                    f"{node_id} has invalid control routing types: {sorted(types)}",
                )

    def _check_reachability(self) -> None:
        start = str(self.graph.get("start", ""))
        if start not in self.nodes:
            return
        reached: set[str] = set()
        queue: deque[str] = deque([start])
        while queue:
            node_id = queue.popleft()
            if node_id in reached:
                continue
            reached.add(node_id)
            for edge in self._control_out(node_id):
                target = str(edge.get("to", ""))
                if target in self.nodes:
                    queue.append(target)
        for node_id, node in self.nodes.items():
            if node.get("kind") in CONTROL_KINDS and node_id not in reached:
                self.error("graph.orphan", f"Unreachable control node: {node_id}")

    def _check_domain_contract(self) -> None:
        for node_id, node in self.nodes.items():
            if node.get("kind") in DOMAIN_KINDS:
                semantic_incident = any(
                    edge.get("type") in SEMANTIC_EDGES
                    for edge in self.incoming[node_id] + self.outgoing[node_id]
                )
                if not semantic_incident:
                    self.error("domain.orphan", f"Unlinked domain node: {node_id}")

        resources = [node for node in self.nodes.values() if node.get("kind") == "resource"]
        for node in resources:
            try:
                expected = float(node["available"]) - float(node["minimum_required"])
                actual = float(node["slack"])
            except (KeyError, TypeError, ValueError):
                continue
            if abs(expected - actual) > 1e-9:
                self.error(
                    "resource.slack",
                    f"{node['id']} slack must equal available - minimum_required.",
                )
            if bool(node.get("scarce")) != (actual <= 1):
                self.error(
                    "resource.scarcity",
                    f"{node['id']} scarce must match slack <= 1.",
                )

        success_nodes = [
            node for node in self.nodes.values()
            if node.get("kind") == "terminal" and node.get("outcome") == "success"
        ]
        if not success_nodes:
            self.error("terminal.success_missing", "Graph has no success terminal.")
        if not any(
            node.get("kind") == "terminal" and node.get("outcome") == "failure"
            for node in self.nodes.values()
        ):
            self.error("terminal.failure_missing", "Graph has no failure terminal.")

        required_categories = set()
        for success in success_nodes:
            categories = {
                self.nodes[str(edge.get("to"))].get("category")
                for edge in self.outgoing[success["id"]]
                if edge.get("type") == "requires"
                and str(edge.get("to")) in self.nodes
                and self.nodes[str(edge.get("to"))].get("kind") == "invariant"
            }
            required_categories |= categories
        if self.requirements is not None:
            missing = self.requirements["invariants"] - required_categories
            if missing:
                self.error(
                    "terminal.invariants",
                    f"Success terminal is missing required invariants: {sorted(missing)}",
                )

    def _first_player_decision(self) -> dict[str, Any] | None:
        start = str(self.graph.get("start", ""))
        if start not in self.nodes:
            return None
        queue: deque[tuple[str, int]] = deque([(start, 0)])
        seen: set[str] = set()
        found: list[tuple[int, dict[str, Any]]] = []
        while queue:
            node_id, depth = queue.popleft()
            if node_id in seen:
                continue
            seen.add(node_id)
            node = self.nodes[node_id]
            if node.get("kind") == "player_decision":
                found.append((depth, node))
                continue
            for edge in self._control_out(node_id):
                target = str(edge.get("to", ""))
                if target in self.nodes:
                    queue.append((target, depth + 1))
        return min(found, key=lambda item: item[0])[1] if found else None

    def _check_profile_gates(self) -> None:
        if self.requirements is None:
            return
        first = self._first_player_decision()
        if first is None:
            self.error("profile.player_decision", "No player decision is reachable.")
        else:
            option_count = sum(
                edge.get("type") == "option" for edge in self.outgoing[first["id"]]
            )
            required_options = max(
                int(self.requirements["initial_options"]),
                int(self.graph.get("proof", {}).get("required_initial_options", 0)),
            )
            if option_count < required_options:
                self.error(
                    "profile.initial_options",
                    f"First player decision has {option_count} options; "
                    f"{required_options} required.",
                )

        scarce = [
            node for node in self.nodes.values()
            if node.get("kind") == "resource" and node.get("scarce") is True
        ]
        if len(scarce) < int(self.requirements["scarce_resources"]):
            self.error(
                "profile.scarce_resources",
                f"Found {len(scarce)} scarce resources; "
                f"{self.requirements['scarce_resources']} required.",
            )

        if self.requirements["bench_required"]:
            bench_ids = {
                node_id for node_id, node in self.nodes.items()
                if node.get("kind") == "resource"
                and node.get("resource_type") == "bench_slot"
            }
            coupled = any(
                edge.get("type") in {"consumes", "reserves"}
                and str(edge.get("to")) in bench_ids
                and self.nodes.get(str(edge.get("from")), {}).get("kind") == "action"
                for edge in self.edges
            )
            if not bench_ids or not coupled:
                self.error(
                    "profile.bench_coupling",
                    "A consequential Bench-slot resource is required.",
                )

        if self.requirements["and_reply_required"]:
            covered = any(
                node.get("kind") == "opponent_decision"
                and node.get("operator") == "AND"
                and len(self._control_out(node_id)) >= 2
                for node_id, node in self.nodes.items()
            )
            if not covered:
                self.error(
                    "profile.opponent_and",
                    "At least one AND opponent decision with two replies is required.",
                )

        if self.requirements["delayed_failure_required"]:
            delayed = any(
                node.get("kind") == "terminal"
                and node.get("outcome") == "failure"
                and isinstance(node.get("consequence_depth"), int)
                and node["consequence_depth"] >= 2
                for node in self.nodes.values()
            )
            if not delayed:
                self.error(
                    "profile.delayed_failure",
                    "At least one consequence-depth >= 2 failure is required.",
                )

        dual_purpose = False
        for node_id, node in self.nodes.items():
            if node.get("kind") != "action":
                continue
            semantic = [
                edge for edge in self.outgoing[node_id]
                if edge.get("type") in SEMANTIC_EDGES
            ]
            counters_threat = any(
                edge.get("type") == "counters"
                and self.nodes.get(str(edge.get("to")), {}).get("kind") == "threat"
                for edge in semantic
            )
            develops = any(
                edge.get("type") in {"enables", "satisfies", "reserves"}
                and (
                    self.nodes.get(str(edge.get("to")), {}).get("kind") == "resource"
                    or self.nodes.get(str(edge.get("to")), {}).get("category")
                    in {"progress", "handoff"}
                )
                for edge in semantic
            )
            if counters_threat and develops:
                dual_purpose = True
                break
        if self.profile in {"deployment", "composite"} and not dual_purpose:
            self.error(
                "profile.dual_purpose",
                "Need one action that both develops/reserves and counters a threat.",
            )

    def _check_proof_contract(self) -> None:
        proof = self.graph.get("proof")
        if not isinstance(proof, dict):
            self.error("proof.schema", "`proof` must be an object.")
            return
        for key in ("max_depth", "max_player_turns", "opponent_reply_coverage", "negative_probe_axes"):
            if key not in proof:
                self.error("proof.missing", f"Proof contract is missing `{key}`.")
        if self.profile == "composite" and proof.get("opponent_reply_coverage") != "all":
            self.error(
                "proof.reply_coverage",
                "Composite profile requires opponent_reply_coverage = all.",
            )
        axes = proof.get("negative_probe_axes", [])
        if not isinstance(axes, list):
            self.error("proof.axes", "`negative_probe_axes` must be an array.")
            return
        if self.profile == "composite" and len(set(axes)) < 3:
            self.error("proof.axes_count", "Composite profile needs three negative axes.")
        failure_axes = {
            node.get("failure_axis")
            for node in self.nodes.values()
            if node.get("kind") == "terminal" and node.get("outcome") == "failure"
        }
        for axis in axes:
            if axis not in failure_axes:
                self.error(
                    "proof.axis_uncovered",
                    f"Negative probe axis has no failure terminal: {axis}",
                )

    def _evaluate_root(self) -> None:
        start = str(self.graph.get("start", ""))
        if start not in self.nodes:
            return

        max_depth = int(self.graph.get("proof", {}).get("max_depth", 64))

        def evaluate(node_id: str, path: tuple[str, ...]) -> bool:
            if len(path) > max_depth:
                return False
            if node_id in path:
                node = self.nodes[node_id]
                budget = node.get("loop_budget")
                if not isinstance(budget, int) or budget <= 0:
                    return False
                if path.count(node_id) >= budget:
                    return False
            node = self.nodes[node_id]
            kind = node.get("kind")
            if kind == "terminal":
                return node.get("outcome") == "success"
            children = [
                str(edge.get("to"))
                for edge in self._control_out(node_id)
                if str(edge.get("to")) in self.nodes
            ]
            if not children:
                return False
            next_path = path + (node_id,)
            values = [evaluate(child, next_path) for child in children]
            if kind == "player_decision":
                return any(values)
            if kind == "opponent_decision":
                return all(values)
            if kind == "information" and node.get("operator") == "AND":
                return all(values)
            return values[0] if len(values) == 1 else False

        if not evaluate(start, ()):
            self.error(
                "proof.root_false",
                "AND-OR evaluation cannot find a route satisfying every required reply.",
            )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compile and audit a PTCG turn-construction graph JSON file."
    )
    parser.add_argument("graph_file", type=Path)
    parser.add_argument(
        "--json",
        action="store_true",
        dest="json_output",
        help="Emit machine-readable issue output.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        graph = json.loads(args.graph_file.read_text(encoding="utf-8"))
    except FileNotFoundError:
        print(f"ERROR file.not_found: {args.graph_file}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as exc:
        print(f"ERROR json.invalid: {exc}", file=sys.stderr)
        return 2

    if not isinstance(graph, dict):
        print("ERROR schema.root: graph JSON root must be an object.", file=sys.stderr)
        return 2

    issues = GraphAuditor(graph).audit()
    errors = [issue for issue in issues if issue.severity == "ERROR"]
    warnings = [issue for issue in issues if issue.severity == "WARN"]

    if args.json_output:
        print(
            json.dumps(
                {
                    "ok": not errors,
                    "errors": [issue.__dict__ for issue in errors],
                    "warnings": [issue.__dict__ for issue in warnings],
                },
                ensure_ascii=False,
                indent=2,
            )
        )
    else:
        for issue in issues:
            print(f"{issue.severity} {issue.code}: {issue.message}")
        print(
            f"Graph audit {'PASSED' if not errors else 'FAILED'}: "
            f"{len(errors)} error(s), {len(warnings)} warning(s)."
        )
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
