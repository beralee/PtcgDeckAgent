extends RefCounted
const AttackAccessScript = preload("res://scripts/ai/ptcgdap/public/PublicAttackAccess.gd")
# Schema/fact constants mechanically copied from public_decision_facts.py.
const SCHEMA = {
  "type": "object",
  "additionalProperties": false,
  "required": [
    "version",
    "current_player_index",
    "first_player_index",
    "stadium",
    "turn",
    "selection",
    "self",
    "opponent",
    "entities"
  ],
  "properties": {
    "version": {
      "type": "integer",
      "const": 1
    },
    "current_player_index": {
      "type": "integer",
      "minimum": 0,
      "maximum": 1
    },
    "first_player_index": {
      "type": "integer",
      "minimum": 0,
      "maximum": 1
    },
    "stadium": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "card_uid",
        "owner_index"
      ],
      "properties": {
        "card_uid": {
          "anyOf": [
            {
              "type": "string",
              "pattern": "^[A-Za-z0-9.]+_[A-Za-z0-9._]+$",
              "minLength": 3,
              "maxLength": 64
            },
            {
              "type": "null"
            }
          ]
        },
        "owner_index": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "turn": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "stadium_play_available",
        "stadium_effect_used"
      ],
      "properties": {
        "stadium_play_available": {
          "type": "boolean"
        },
        "stadium_effect_used": {
          "type": "boolean"
        }
      }
    },
    "selection": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "remaining_energy_cost",
        "remaining_damage_counters",
        "max_assignments",
        "max_assignments_per_target",
        "allow_partial"
      ],
      "properties": {
        "remaining_energy_cost": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0,
              "maximum": 100
            },
            {
              "type": "null"
            }
          ]
        },
        "remaining_damage_counters": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0,
              "maximum": 100
            },
            {
              "type": "null"
            }
          ]
        },
        "max_assignments": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0,
              "maximum": 100
            },
            {
              "type": "null"
            }
          ]
        },
        "max_assignments_per_target": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0,
              "maximum": 100
            },
            {
              "type": "null"
            }
          ]
        },
        "allow_partial": {
          "anyOf": [
            {
              "type": "boolean"
            },
            {
              "type": "null"
            }
          ]
        }
      }
    },
    "self": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "is_first_turn",
        "vstar_used",
        "knocked_out_previous_opponent_turn",
        "bench_capacity",
        "lost_zone"
      ],
      "properties": {
        "is_first_turn": {
          "type": "boolean"
        },
        "vstar_used": {
          "type": "boolean"
        },
        "knocked_out_previous_opponent_turn": {
          "type": "boolean"
        },
        "bench_capacity": {
          "type": "integer",
          "minimum": 0,
          "maximum": 8
        },
        "lost_zone": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "serial",
              "local_card_uid"
            ],
            "properties": {
              "serial": {
                "type": "integer",
                "minimum": 0,
                "maximum": 9007199254740991
              },
              "local_card_uid": {
                "type": "string",
                "pattern": "^[A-Za-z0-9.]+_[A-Za-z0-9._]+$",
                "minLength": 3,
                "maxLength": 64
              }
            }
          },
          "maxItems": 60
        }
      }
    },
    "opponent": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "is_first_turn",
        "vstar_used",
        "knocked_out_previous_opponent_turn",
        "bench_capacity",
        "lost_zone"
      ],
      "properties": {
        "is_first_turn": {
          "type": "boolean"
        },
        "vstar_used": {
          "type": "boolean"
        },
        "knocked_out_previous_opponent_turn": {
          "type": "boolean"
        },
        "bench_capacity": {
          "type": "integer",
          "minimum": 0,
          "maximum": 8
        },
        "lost_zone": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "serial",
              "local_card_uid"
            ],
            "properties": {
              "serial": {
                "type": "integer",
                "minimum": 0,
                "maximum": 9007199254740991
              },
              "local_card_uid": {
                "type": "string",
                "pattern": "^[A-Za-z0-9.]+_[A-Za-z0-9._]+$",
                "minLength": 3,
                "maxLength": 64
              }
            }
          },
          "maxItems": 60
        }
      }
    },
    "entities": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "entity_serial",
          "played_this_turn",
          "evolved_this_turn",
          "conditions",
          "effective_retreat_cost",
          "retreat_energy_units",
          "retreat_energy_ready",
          "tool_effect_suppressed",
          "ability_disabled",
          "early_evolution_allowed",
          "ability_use_recorded_this_turn",
          "energies",
          "attacks"
        ],
        "properties": {
          "entity_serial": {
            "type": "integer",
            "minimum": 1,
            "maximum": 9007199254740991
          },
          "played_this_turn": {
            "type": "boolean"
          },
          "evolved_this_turn": {
            "type": "boolean"
          },
          "conditions": {
            "type": "array",
            "items": {
              "type": "string",
              "enum": [
                "poisoned",
                "burned",
                "asleep",
                "paralyzed",
                "confused"
              ]
            },
            "maxItems": 5
          },
          "effective_retreat_cost": {
            "type": "integer",
            "minimum": 0,
            "maximum": 60
          },
          "retreat_energy_units": {
            "type": "integer",
            "minimum": 0,
            "maximum": 3600
          },
          "retreat_energy_ready": {
            "type": "boolean"
          },
          "tool_effect_suppressed": {
            "type": "boolean"
          },
          "ability_disabled": {
            "type": "boolean"
          },
          "early_evolution_allowed": {
            "type": "boolean"
          },
          "ability_use_recorded_this_turn": {
            "type": "boolean"
          },
          "energies": {
            "type": "array",
            "items": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "serial",
                "local_card_uid",
                "units",
                "types"
              ],
              "properties": {
                "serial": {
                  "type": "integer",
                  "minimum": 0,
                  "maximum": 9007199254740991
                },
                "local_card_uid": {
                  "type": "string",
                  "pattern": "^[A-Za-z0-9.]+_[A-Za-z0-9._]+$",
                  "minLength": 3,
                  "maxLength": 64
                },
                "units": {
                  "type": "integer",
                  "minimum": 0,
                  "maximum": 60
                },
                "types": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "enum": [
                      "G",
                      "W",
                      "F",
                      "R",
                      "L",
                      "P",
                      "M",
                      "D",
                      "N",
                      "Y",
                      "C",
                      "ANY"
                    ]
                  },
                  "maxItems": 12
                }
              }
            },
            "maxItems": 60
          },
          "attacks": {
            "type": "array",
            "items": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "attack_index",
                "source_uid",
                "cost_candidates",
                "energy_debt",
                "energy_ready"
              ],
              "properties": {
                "attack_index": {
                  "type": "integer",
                  "minimum": 0,
                  "maximum": 31
                },
                "source_uid": {
                  "type": "string",
                  "pattern": "^[A-Za-z0-9.]+_[A-Za-z0-9._]+$",
                  "minLength": 3,
                  "maxLength": 64
                },
                "cost_candidates": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "pattern": "^[GWFRLPMDNYC]*$",
                    "maxLength": 32
                  },
                  "maxItems": 256
                },
                "energy_debt": {
                  "type": "integer",
                  "minimum": 0,
                  "maximum": 32
                },
                "energy_ready": {
                  "type": "boolean"
                }
              }
            },
            "maxItems": 32
          }
        }
      },
      "maxItems": 18
    }
  }
}
const FACT_TYPES = {
  "decision.option.access_best": "boolean",
  "decision.option.access_gain": "integer",
  "decision.option.access_pressure": "integer",
  "decision.option.access_resource_cost": "integer",
  "decision.option.counter_prize_plan": "integer",
  "decision.version": "integer",
  "decision.current_player_index": "integer",
  "decision.first_player_index": "integer",
  "decision.stadium.card_uid": "string",
  "decision.stadium.owner_index": "integer",
  "decision.turn.stadium_play_available": "boolean",
  "decision.turn.stadium_effect_used": "boolean",
  "decision.selection.remaining_energy_cost": "integer",
  "decision.selection.remaining_damage_counters": "integer",
  "decision.selection.max_assignments": "integer",
  "decision.selection.max_assignments_per_target": "integer",
  "decision.selection.allow_partial": "boolean",
  "decision.self.is_first_turn": "boolean",
  "decision.self.vstar_used": "boolean",
  "decision.self.knocked_out_previous_opponent_turn": "boolean",
  "decision.self.bench_capacity": "integer",
  "decision.self.lost_zone_count": "integer",
  "decision.self.lost_zone_uids": "array",
  "decision.opponent.is_first_turn": "boolean",
  "decision.opponent.vstar_used": "boolean",
  "decision.opponent.knocked_out_previous_opponent_turn": "boolean",
  "decision.opponent.bench_capacity": "integer",
  "decision.opponent.lost_zone_count": "integer",
  "decision.opponent.lost_zone_uids": "array",
  "decision.self.active.played_this_turn": "boolean",
  "decision.self.active.evolved_this_turn": "boolean",
  "decision.self.active.conditions": "array",
  "decision.self.active.effective_retreat_cost": "integer",
  "decision.self.active.retreat_energy_units": "integer",
  "decision.self.active.retreat_energy_ready": "boolean",
  "decision.self.active.tool_effect_suppressed": "boolean",
  "decision.self.active.ability_disabled": "boolean",
  "decision.self.active.early_evolution_allowed": "boolean",
  "decision.self.active.ability_use_recorded_this_turn": "boolean",
  "decision.self.active.attack.0.energy_debt": "integer",
  "decision.self.active.attack.0.energy_ready": "boolean",
  "decision.self.active.attack.0.cost_candidates": "array",
  "decision.self.active.attack.1.energy_debt": "integer",
  "decision.self.active.attack.1.energy_ready": "boolean",
  "decision.self.active.attack.1.cost_candidates": "array",
  "decision.self.active.attack.2.energy_debt": "integer",
  "decision.self.active.attack.2.energy_ready": "boolean",
  "decision.self.active.attack.2.cost_candidates": "array",
  "decision.self.active.attack.3.energy_debt": "integer",
  "decision.self.active.attack.3.energy_ready": "boolean",
  "decision.self.active.attack.3.cost_candidates": "array",
  "decision.self.active.attack.4.energy_debt": "integer",
  "decision.self.active.attack.4.energy_ready": "boolean",
  "decision.self.active.attack.4.cost_candidates": "array",
  "decision.self.active.attack.5.energy_debt": "integer",
  "decision.self.active.attack.5.energy_ready": "boolean",
  "decision.self.active.attack.5.cost_candidates": "array",
  "decision.self.active.attack.6.energy_debt": "integer",
  "decision.self.active.attack.6.energy_ready": "boolean",
  "decision.self.active.attack.6.cost_candidates": "array",
  "decision.self.active.attack.7.energy_debt": "integer",
  "decision.self.active.attack.7.energy_ready": "boolean",
  "decision.self.active.attack.7.cost_candidates": "array",
  "decision.opponent.active.played_this_turn": "boolean",
  "decision.opponent.active.evolved_this_turn": "boolean",
  "decision.opponent.active.conditions": "array",
  "decision.opponent.active.effective_retreat_cost": "integer",
  "decision.opponent.active.retreat_energy_units": "integer",
  "decision.opponent.active.retreat_energy_ready": "boolean",
  "decision.opponent.active.tool_effect_suppressed": "boolean",
  "decision.opponent.active.ability_disabled": "boolean",
  "decision.opponent.active.early_evolution_allowed": "boolean",
  "decision.opponent.active.ability_use_recorded_this_turn": "boolean",
  "decision.opponent.active.attack.0.energy_debt": "integer",
  "decision.opponent.active.attack.0.energy_ready": "boolean",
  "decision.opponent.active.attack.0.cost_candidates": "array",
  "decision.opponent.active.attack.1.energy_debt": "integer",
  "decision.opponent.active.attack.1.energy_ready": "boolean",
  "decision.opponent.active.attack.1.cost_candidates": "array",
  "decision.opponent.active.attack.2.energy_debt": "integer",
  "decision.opponent.active.attack.2.energy_ready": "boolean",
  "decision.opponent.active.attack.2.cost_candidates": "array",
  "decision.opponent.active.attack.3.energy_debt": "integer",
  "decision.opponent.active.attack.3.energy_ready": "boolean",
  "decision.opponent.active.attack.3.cost_candidates": "array",
  "decision.opponent.active.attack.4.energy_debt": "integer",
  "decision.opponent.active.attack.4.energy_ready": "boolean",
  "decision.opponent.active.attack.4.cost_candidates": "array",
  "decision.opponent.active.attack.5.energy_debt": "integer",
  "decision.opponent.active.attack.5.energy_ready": "boolean",
  "decision.opponent.active.attack.5.cost_candidates": "array",
  "decision.opponent.active.attack.6.energy_debt": "integer",
  "decision.opponent.active.attack.6.energy_ready": "boolean",
  "decision.opponent.active.attack.6.cost_candidates": "array",
  "decision.opponent.active.attack.7.energy_debt": "integer",
  "decision.opponent.active.attack.7.energy_ready": "boolean",
  "decision.opponent.active.attack.7.cost_candidates": "array",
  "decision.option.target.played_this_turn": "boolean",
  "decision.option.target.evolved_this_turn": "boolean",
  "decision.option.target.conditions": "array",
  "decision.option.target.effective_retreat_cost": "integer",
  "decision.option.target.retreat_energy_units": "integer",
  "decision.option.target.retreat_energy_ready": "boolean",
  "decision.option.target.tool_effect_suppressed": "boolean",
  "decision.option.target.ability_disabled": "boolean",
  "decision.option.target.early_evolution_allowed": "boolean",
  "decision.option.target.ability_use_recorded_this_turn": "boolean",
  "decision.option.target.attack.0.energy_debt": "integer",
  "decision.option.target.attack.0.energy_ready": "boolean",
  "decision.option.target.attack.0.cost_candidates": "array",
  "decision.option.target.attack.1.energy_debt": "integer",
  "decision.option.target.attack.1.energy_ready": "boolean",
  "decision.option.target.attack.1.cost_candidates": "array",
  "decision.option.target.attack.2.energy_debt": "integer",
  "decision.option.target.attack.2.energy_ready": "boolean",
  "decision.option.target.attack.2.cost_candidates": "array",
  "decision.option.target.attack.3.energy_debt": "integer",
  "decision.option.target.attack.3.energy_ready": "boolean",
  "decision.option.target.attack.3.cost_candidates": "array",
  "decision.option.target.attack.4.energy_debt": "integer",
  "decision.option.target.attack.4.energy_ready": "boolean",
  "decision.option.target.attack.4.cost_candidates": "array",
  "decision.option.target.attack.5.energy_debt": "integer",
  "decision.option.target.attack.5.energy_ready": "boolean",
  "decision.option.target.attack.5.cost_candidates": "array",
  "decision.option.target.attack.6.energy_debt": "integer",
  "decision.option.target.attack.6.energy_ready": "boolean",
  "decision.option.target.attack.6.cost_candidates": "array",
  "decision.option.target.attack.7.energy_debt": "integer",
  "decision.option.target.attack.7.energy_ready": "boolean",
  "decision.option.target.attack.7.cost_candidates": "array",
  "decision.option.source.played_this_turn": "boolean",
  "decision.option.source.evolved_this_turn": "boolean",
  "decision.option.source.conditions": "array",
  "decision.option.source.effective_retreat_cost": "integer",
  "decision.option.source.retreat_energy_units": "integer",
  "decision.option.source.retreat_energy_ready": "boolean",
  "decision.option.source.tool_effect_suppressed": "boolean",
  "decision.option.source.ability_disabled": "boolean",
  "decision.option.source.early_evolution_allowed": "boolean",
  "decision.option.source.ability_use_recorded_this_turn": "boolean",
  "decision.option.source.attack.0.energy_debt": "integer",
  "decision.option.source.attack.0.energy_ready": "boolean",
  "decision.option.source.attack.0.cost_candidates": "array",
  "decision.option.source.attack.1.energy_debt": "integer",
  "decision.option.source.attack.1.energy_ready": "boolean",
  "decision.option.source.attack.1.cost_candidates": "array",
  "decision.option.source.attack.2.energy_debt": "integer",
  "decision.option.source.attack.2.energy_ready": "boolean",
  "decision.option.source.attack.2.cost_candidates": "array",
  "decision.option.source.attack.3.energy_debt": "integer",
  "decision.option.source.attack.3.energy_ready": "boolean",
  "decision.option.source.attack.3.cost_candidates": "array",
  "decision.option.source.attack.4.energy_debt": "integer",
  "decision.option.source.attack.4.energy_ready": "boolean",
  "decision.option.source.attack.4.cost_candidates": "array",
  "decision.option.source.attack.5.energy_debt": "integer",
  "decision.option.source.attack.5.energy_ready": "boolean",
  "decision.option.source.attack.5.cost_candidates": "array",
  "decision.option.source.attack.6.energy_debt": "integer",
  "decision.option.source.attack.6.energy_ready": "boolean",
  "decision.option.source.attack.6.cost_candidates": "array",
  "decision.option.source.attack.7.energy_debt": "integer",
  "decision.option.source.attack.7.energy_ready": "boolean",
  "decision.option.source.attack.7.cost_candidates": "array"
}

static func schema_error(value: Variant, schema: Dictionary) -> bool:
	if schema.has("anyOf"):
		for choice: Dictionary in schema.anyOf:
			if not schema_error(value, choice): return false
		return true
	var expected: int = {"object": TYPE_DICTIONARY, "array": TYPE_ARRAY, "integer": TYPE_INT, "boolean": TYPE_BOOL, "string": TYPE_STRING, "null": TYPE_NIL}[schema.type]
	# JSON parsing represents integers as floats in Godot, as in the core validator.
	if expected == TYPE_INT:
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or float(value) != floor(float(value)): return true
	elif typeof(value) != expected: return true
	if schema.has("const") and value != schema["const"]: return true
	if schema.has("enum") and value not in schema["enum"]: return true
	match str(schema.type):
		"object":
			if value.size() != schema.properties.size(): return true
			for key: String in schema.properties:
				if not value.has(key) or schema_error(value[key], schema.properties[key]): return true
		"array":
			if value.size() > schema.maxItems: return true
			for child: Variant in value:
				if schema_error(child, schema.items): return true
		"integer":
			return value < schema.get("minimum", 0) or value > schema.get("maximum", 9007199254740991)
		"string":
			if value.length() < schema.get("minLength", 0) or value.length() > schema.get("maxLength", 64): return true
			if schema.has("pattern"):
				var regex := RegEx.new()
				regex.compile(schema.pattern)
				var matched := regex.search(value)
				if matched == null or matched.get_string() != value: return true
	return false

static func decision_error(state: Variant) -> bool:
	if not state is Dictionary or not state.has("decision"): return false
	var extension: Variant = state.decision
	if schema_error(extension, SCHEMA): return true
	var board := {}
	for side: String in ["self", "opponent"]:
		var public_side: Variant = state.get(side, {})
		if not public_side is Dictionary: return true
		for zone: String in ["active", "bench"]:
			if not public_side.get(zone) is Array: return true
			for slot: Variant in public_side[zone]:
				if not slot is Dictionary or not slot.has("entity_serial"): return true
				var identity: Variant = slot.entity_serial
				if schema_error(identity, {"type": "integer", "minimum": 1}) or board.has(identity): return true
				board[identity] = slot
	var seen := {}
	for entity: Dictionary in extension.entities:
		var identity: Variant = entity.entity_serial
		if seen.has(identity) or not board.has(identity): return true
		seen[identity] = true
		var slot: Dictionary = board[identity]
		if entity.energies.size() != slot.get("attached_energy_count"): return true
		var uids := []
		var energy_serials := {}
		var units := 0
		for energy: Dictionary in entity.energies:
			uids.append(energy.local_card_uid)
			if energy_serials.has(energy.serial): return true
			energy_serials[energy.serial] = true
			units += int(energy.units)
		if uids != slot.get("attached_energy_uids"): return true
		var conditions := {}
		for condition: String in entity.conditions:
			if conditions.has(condition): return true
			conditions[condition] = true
		if entity.retreat_energy_units != units: return true
		if entity.retreat_energy_ready != (units >= entity.effective_retreat_cost): return true
		for index: int in entity.attacks.size():
			var attack: Dictionary = entity.attacks[index]
			if attack.attack_index != index or attack.source_uid != slot.get("local_card_uid") or attack.cost_candidates.is_empty(): return true
			if attack.energy_ready != (attack.energy_debt == 0): return true
	return seen.size() != board.size()

static func counter_prize_plan(frame: Dictionary) -> Variant:
	var semantics: Dictionary = frame.get("select_semantics", {})
	var options: Array = frame.get("options", [])
	if semantics.get("select_type_raw") != 1 or semantics.get("select_context_raw") not in [13, 14] or options.is_empty() or options.size() > 9: return null
	var budget: Variant = options[0].get("remaining_damage_counters")
	if schema_error(budget, {"type":"integer", "minimum":1, "maximum":6}): return null
	var state: Dictionary = frame.get("public_state", {})
	if state.get("decision", {}).get("selection", {}).get("max_assignments_per_target") != null: return null
	var board := {}
	for zone: String in ["active", "bench"]:
		for slot: Dictionary in state.get("opponent", {}).get(zone, []): board[slot.get("entity_serial")] = slot
	var rows := []
	var seen := {}
	for o: Dictionary in options:
		var identity: Variant = o.get("target_entity_serial")
		var hp: Variant = o.get("target_remaining_hp")
		var prize: Variant = o.get("target_prize_value")
		var pending: Variant = o.get("target_pending_damage_counters")
		var slot: Dictionary = board.get(identity, {})
		if schema_error(identity, {"type":"integer", "minimum":1}) or seen.has(identity): return null
		if schema_error(hp, {"type":"integer", "minimum":1}) or schema_error(prize, {"type":"integer", "minimum":1, "maximum":3}) or schema_error(pending, {"type":"integer", "minimum":0, "maximum":6}): return null
		if o.get("remaining_damage_counters") != budget or slot.get("local_card_uid") != o.get("target_uid") or slot.get("remaining_hp") != hp or slot.get("prize_value") != prize: return null
		seen[identity] = true
		var residual: int = maxi(0, int(hp) - 10 * int(pending))
		rows.append([int(identity), residual, int(prize), int(ceil(float(residual) / 10.0))])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var best := [-1, -1, -100]
	var allocation := []
	allocation.resize(rows.size()); allocation.fill(0)
	for mask: int in range(1 << rows.size()):
		var cost := 0
		var prizes := 0
		var kos := 0
		for i: int in range(rows.size()):
			if mask & (1 << i):
				if rows[i][1] == 0:
					cost = int(budget) + 1
					break
				cost += rows[i][3]; prizes += rows[i][2]; kos += 1
		var better: bool = prizes > best[0] or (prizes == best[0] and (kos > best[1] or (kos == best[1] and -cost > best[2])))
		if cost <= budget and better:
			best = [prizes, kos, -cost]
			for i: int in range(rows.size()): allocation[i] = rows[i][3] if mask & (1 << i) else 0
	var left: int = int(budget)
	for amount: int in allocation: left -= amount
	var order := range(rows.size())
	order.sort_custom(func(a: int, b: int) -> bool: return rows[a][1] < rows[b][1] or (rows[a][1] == rows[b][1] and rows[a][0] < rows[b][0]))
	for i: int in order:
		var residual: int = rows[i][1] - 10 * allocation[i]
		if residual > 0:
			var spend: int = mini(left, int(ceil(float(residual) / 10.0)))
			allocation[i] += spend; left -= spend
	if left > 0: allocation[0] += left
	var result := {}
	for i: int in range(rows.size()): result[rows[i][0]] = allocation[i]
	return result

static func fact(frame: Dictionary, option: Variant, name: String) -> Variant:
	if not FACT_TYPES.has(name): return null
	if name.begins_with("decision.option.access_"): return AttackAccessScript.fact(frame, option, name)
	if name == "decision.option.counter_prize_plan":
		var plan: Variant = counter_prize_plan(frame)
		return plan.get(option.get("target_entity_serial")) if plan is Dictionary and option is Dictionary else null
	var state: Dictionary = frame.get("public_state", {})
	if not state.has("decision"): return null
	var extension: Dictionary = state.decision
	var path: PackedStringArray = name.split(".").slice(1)
	if path.size() >= 3 and path[0] + "." + path[1] in ["self.active", "opponent.active", "option.target", "option.source"]:
		var identity: Variant = null
		if path[0] == "option":
			if option is Dictionary: identity = option.get(path[1] + "_entity_serial")
		else:
			var slots: Array = state.get(path[0], {}).get("active", [])
			if not slots.is_empty(): identity = slots[0].get("entity_serial")
		for entity: Dictionary in extension.entities:
			if entity.entity_serial != identity: continue
			if path[2] == "attack":
				for attack: Dictionary in entity.attacks:
					if attack.attack_index == int(path[3]): return attack.get(path[4])
				return null
			return entity.get(path[2])
		return null
	if path.size() == 2 and path[1] in ["lost_zone_count", "lost_zone_uids"]:
		var cards: Array = extension[path[0]].lost_zone
		if path[1] == "lost_zone_count": return cards.size()
		var uids := []
		for card: Dictionary in cards: uids.append(card.local_card_uid)
		return uids
	var value: Variant = extension
	for key: String in path:
		value = value.get(key) if value is Dictionary else null
	return value
