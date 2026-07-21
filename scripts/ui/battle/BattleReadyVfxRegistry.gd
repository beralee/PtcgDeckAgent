class_name BattleReadyVfxRegistry
extends RefCounted


const BattleReadyVfxProfileScript := preload("res://scripts/ui/battle/BattleReadyVfxProfile.gd")

const RULE_BUDEW_OPENING_ITEM_LOCK := "budew_opening_item_lock_ready"
const RULE_DRAGAPULT_PHANTOM_DIVE := "dragapult_phantom_dive_ready"
const RULE_LUGIA_DOUBLE_ARCHEOPS := "lugia_double_archeops_ready"
const RULE_IRON_HANDS_AMP := "iron_hands_amp_ready"
const RULE_TERAPAGOS_CAVERN_BOARD := "terapagos_cavern_board_ready"
const RULE_PALKIA_VSTAR_ACCELERATION := "palkia_vstar_acceleration_ready"
const RULE_GHOLDENGO_BIG_SWING := "gholdengo_big_swing_ready"
const RULE_CHARIZARD_INFERNAL_REIGN := "charizard_infernal_reign_ready"
const RULE_MIRAIDON_GENERATOR_LINE := "miraidon_generator_line_ready"
const RULE_REGIGIGAS_ANCIENT_WISDOM := "regigigas_ancient_wisdom_ready"
const RULE_RADIANT_GRENINJA_CONCEALED_CARDS := "radiant_greninja_concealed_cards_ready"
const RULE_CERULEDGE_DISCARD_ENERGY := "ceruledge_discard_energy_ready"
const RULE_ROARING_MOON_FRENZIED := "roaring_moon_frenzied_ready"
const RULE_GARDEVOIR_PSYCHIC_EMBRACE := "gardevoir_psychic_embrace_ready"
const RULE_ARCHALUDON_METAL_BRIDGE := "archaludon_metal_bridge_ready"
const RULE_SQUAWKABILLY_FIRST_TURN_DRAW := "squawkabilly_first_turn_draw_ready"
const RULE_MARNIES_GRIMMSNARL_PUNK_UP := "marnies_grimmsnarl_punk_up_ready"
const RULE_NS_ZOROARK_NIGHT_JOKER := "ns_zoroark_night_joker_ready"
const RULE_RAGING_BOLT_BELLOWING_THUNDER_LETHAL := "raging_bolt_bellowing_thunder_lethal_ready"
const RULE_ETHANS_HO_OH_GOLDEN_FLAME := "ethans_ho_oh_golden_flame_ready"
const RULE_CYNTHIAS_GARCHOMP_SPIRAL_DRAW := "cynthias_garchomp_spiral_draw_ready"
const RULE_ETHANS_TYPHLOSION_PARTNER_BLAST_LETHAL := "ethans_typhlosion_partner_blast_lethal_ready"
const RULE_BLAZIKEN_BOILING_SPIRIT_ACCELERATION := "blaziken_boiling_spirit_acceleration_ready"
const RULE_PIDGEOT_QUICK_SEARCH_CONTROL := "pidgeot_quick_search_control_ready"
const RULE_FLAREON_BURNING_CHARGE_ENGINE := "flareon_burning_charge_engine_ready"
const RULE_HOPS_ZACIAN_BRAVE_BLADE_LETHAL := "hops_zacian_brave_blade_lethal_ready"
const RULE_YANMEGA_BUZZING_RUSH_ACCELERATION := "yanmega_buzzing_rush_acceleration_ready"
const RULE_MUNKIDORI_ADRENA_BRAIN_TRANSFER := "munkidori_adrena_brain_transfer_ready"
const RULE_TOEDSCRUEL_COLONY_RUSH_LETHAL := "toedscruel_colony_rush_lethal_ready"

const BUDEW_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_budew_item_lock/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const SQUAWKABILLY_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_squawkabilly_first_turn_draw/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const DRAGAPULT_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_dragapult_phantom_dive/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const LUGIA_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_lugia_double_archeops/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const IRON_HANDS_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_iron_hands_amp/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const TERAPAGOS_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_terapagos_cavern_board/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const PALKIA_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_palkia_vstar_acceleration/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const GHOLDENGO_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_gholdengo_big_swing/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const RADIANT_GRENINJA_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_radiant_greninja_concealed_cards/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const PSYCHIC_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/attribute_psychic/source/psychic_impact_bloom.png",
		"frames": 1,
		"rows": 1,
		"cols": 1,
	},
}

const COLORLESS_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/attribute_colorless/source/impact_bloom.png",
		"frames": 1,
		"rows": 1,
		"cols": 1,
	},
}

const LIGHTNING_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/attribute_lightning/impact/impact_bloom.png",
		"frames": 1,
		"rows": 1,
		"cols": 1,
	},
}

const WATER_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/attribute_water/impact_only/water_impact_flipbook.png",
		"frames": 4,
		"rows": 1,
		"cols": 4,
	},
}

const METAL_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/attribute_metal/impact_only/impact_bloom_flipbook.png",
		"frames": 4,
		"rows": 1,
		"cols": 4,
	},
}

const FIRE_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/charizard_ex/mid_stream/impact_bloom_flipbook.png",
		"frames": 4,
		"rows": 1,
		"cols": 4,
	},
}

const CHARIZARD_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_charizard_infernal_reign/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const MIRAIDON_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_miraidon_generator_line/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const REGIGIGAS_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_regigigas_ancient_wisdom/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const CERULEDGE_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_ceruledge_discard_energy/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const ROARING_MOON_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_roaring_moon_frenzied/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const GARDEVOIR_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_gardevoir_psychic_embrace/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const ARCHALUDON_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_archaludon_metal_bridge/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const MARNIES_GRIMMSNARL_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_marnies_grimmsnarl_punk_up/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const NS_ZOROARK_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_ns_zoroark_night_joker/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const RAGING_BOLT_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_raging_bolt_bellowing_thunder_lethal/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const ETHANS_HO_OH_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_ethans_ho_oh_golden_flame/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const CYNTHIAS_GARCHOMP_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_cynthias_garchomp_spiral_draw/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const ETHANS_TYPHLOSION_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_ethans_typhlosion_partner_blast_lethal/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const BLAZIKEN_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_blaziken_boiling_spirit_acceleration/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const PIDGEOT_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_pidgeot_quick_search_control/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const FLAREON_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_flareon_burning_charge_engine/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const HOPS_ZACIAN_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_hops_zacian_brave_blade_lethal/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const YANMEGA_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_yanmega_buzzing_rush_acceleration/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const MUNKIDORI_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_munkidori_adrena_brain_transfer/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const TOEDSCRUEL_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/ready_toedscruel_colony_rush_lethal/sheet-transparent.png",
		"frames": 6,
		"rows": 2,
		"cols": 3,
	},
}

const DARKNESS_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/attribute_darkness/source/impact_bloom.png",
		"frames": 1,
		"rows": 1,
		"cols": 1,
	},
}

const DRAGON_READY_ASSET_SPECS := {
	"burst": {
		"path": "res://assets/textures/vfx/attribute_dragon/source/impact_bloom.png",
		"frames": 1,
		"rows": 1,
		"cols": 1,
	},
}

var _profiles: Dictionary = {
	RULE_BUDEW_OPENING_ITEM_LOCK: _make_profile(
		"ready_budew_item_lock",
		RULE_BUDEW_OPENING_ITEM_LOCK,
		BUDEW_READY_ASSET_SPECS,
		{
			"duration": 1.014,
			"effect_size": Vector2(440.0, 440.0),
			"anchor_offset": Vector2(0.0, -16.0),
			"start_scale": 0.58,
			"peak_scale": 1.18,
			"end_scale": 1.04,
			"flash_color": Color(1.0, 0.45, 0.82, 0.24),
		}
	),
	RULE_SQUAWKABILLY_FIRST_TURN_DRAW: _make_profile(
		"ready_squawkabilly_first_turn_draw",
		RULE_SQUAWKABILLY_FIRST_TURN_DRAW,
		SQUAWKABILLY_READY_ASSET_SPECS,
		{
			"duration": 1.5,
			"effect_size": Vector2(500.0, 500.0),
			"anchor_offset": Vector2(0.0, -34.0),
			"start_scale": 0.7,
			"peak_scale": 1.18,
			"hold_scale": 1.08,
			"end_scale": 1.0,
			"hold_ratio": 0.2,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.62,
			"portrait_effect_width_ratio": 0.88,
			"portrait_effect_min_size": 580.0,
			"portrait_effect_max_size": 800.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(0.58, 1.0, 0.22, 0.3),
		}
	),
	RULE_DRAGAPULT_PHANTOM_DIVE: _make_profile(
		"ready_dragapult_phantom_dive",
		RULE_DRAGAPULT_PHANTOM_DIVE,
		DRAGAPULT_READY_ASSET_SPECS,
		{
			"duration": 1.6,
			"effect_size": Vector2(500.0, 500.0),
			"anchor_offset": Vector2(0.0, -40.0),
			"start_scale": 0.72,
			"peak_scale": 1.2,
			"hold_scale": 1.12,
			"end_scale": 1.04,
			"hold_ratio": 0.22,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.7,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(0.46, 0.25, 1.0, 0.32),
		}
	),
	RULE_LUGIA_DOUBLE_ARCHEOPS: _make_profile(
		"ready_lugia_double_archeops",
		RULE_LUGIA_DOUBLE_ARCHEOPS,
		LUGIA_READY_ASSET_SPECS,
		{
			"duration": 1.62,
			"effect_size": Vector2(520.0, 520.0),
			"anchor_offset": Vector2(0.0, -44.0),
			"start_scale": 0.7,
			"peak_scale": 1.18,
			"hold_scale": 1.1,
			"end_scale": 1.03,
			"hold_ratio": 0.24,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.72,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(0.82, 0.92, 1.0, 0.32),
		}
	),
	RULE_IRON_HANDS_AMP: _make_profile(
		"ready_iron_hands_amp",
		RULE_IRON_HANDS_AMP,
		IRON_HANDS_READY_ASSET_SPECS,
		{
			"duration": 1.6,
			"effect_size": Vector2(500.0, 500.0),
			"anchor_offset": Vector2(0.0, -40.0),
			"start_scale": 0.72,
			"peak_scale": 1.22,
			"hold_scale": 1.14,
			"end_scale": 1.04,
			"hold_ratio": 0.22,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.7,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(1.0, 0.9, 0.16, 0.34),
		}
	),
	RULE_TERAPAGOS_CAVERN_BOARD: _make_profile(
		"ready_terapagos_cavern_board",
		RULE_TERAPAGOS_CAVERN_BOARD,
		TERAPAGOS_READY_ASSET_SPECS,
		{
			"duration": 1.62,
			"effect_size": Vector2(520.0, 520.0),
			"anchor_offset": Vector2(0.0, -42.0),
			"start_scale": 0.72,
			"peak_scale": 1.2,
			"hold_scale": 1.12,
			"end_scale": 1.04,
			"hold_ratio": 0.24,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.72,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(0.92, 0.7, 1.0, 0.34),
		}
	),
	RULE_PALKIA_VSTAR_ACCELERATION: _make_profile(
		"ready_palkia_vstar_acceleration",
		RULE_PALKIA_VSTAR_ACCELERATION,
		PALKIA_READY_ASSET_SPECS,
		{
			"duration": 1.62,
			"effect_size": Vector2(520.0, 520.0),
			"anchor_offset": Vector2(0.0, -44.0),
			"start_scale": 0.7,
			"peak_scale": 1.18,
			"hold_scale": 1.1,
			"end_scale": 1.03,
			"hold_ratio": 0.24,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.72,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(0.24, 0.68, 1.0, 0.34),
		}
	),
	RULE_GHOLDENGO_BIG_SWING: _make_profile(
		"ready_gholdengo_big_swing",
		RULE_GHOLDENGO_BIG_SWING,
		GHOLDENGO_READY_ASSET_SPECS,
		{
			"duration": 1.6,
			"effect_size": Vector2(500.0, 500.0),
			"anchor_offset": Vector2(0.0, -40.0),
			"start_scale": 0.72,
			"peak_scale": 1.2,
			"hold_scale": 1.12,
			"end_scale": 1.04,
			"hold_ratio": 0.22,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.7,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(1.0, 0.78, 0.12, 0.34),
		}
	),
	RULE_CHARIZARD_INFERNAL_REIGN: _make_profile(
		"ready_charizard_infernal_reign",
		RULE_CHARIZARD_INFERNAL_REIGN,
		CHARIZARD_READY_ASSET_SPECS,
		{
			"duration": 1.62,
			"effect_size": Vector2(520.0, 520.0),
			"anchor_offset": Vector2(0.0, -44.0),
			"start_scale": 0.72,
			"peak_scale": 1.22,
			"hold_scale": 1.14,
			"end_scale": 1.04,
			"hold_ratio": 0.24,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.72,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(1.0, 0.34, 0.05, 0.34),
		}
	),
	RULE_MIRAIDON_GENERATOR_LINE: _make_profile(
		"ready_miraidon_generator_line",
		RULE_MIRAIDON_GENERATOR_LINE,
		MIRAIDON_READY_ASSET_SPECS,
		{
			"duration": 1.6,
			"effect_size": Vector2(500.0, 500.0),
			"anchor_offset": Vector2(0.0, -40.0),
			"start_scale": 0.72,
			"peak_scale": 1.2,
			"hold_scale": 1.12,
			"end_scale": 1.04,
			"hold_ratio": 0.22,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.7,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(0.7, 0.42, 1.0, 0.34),
		}
	),
	RULE_REGIGIGAS_ANCIENT_WISDOM: _make_profile(
		"ready_regigigas_ancient_wisdom",
		RULE_REGIGIGAS_ANCIENT_WISDOM,
		REGIGIGAS_READY_ASSET_SPECS,
		{
			"duration": 1.62,
			"effect_size": Vector2(520.0, 520.0),
			"anchor_offset": Vector2(0.0, -44.0),
			"start_scale": 0.7,
			"peak_scale": 1.18,
			"hold_scale": 1.1,
			"end_scale": 1.03,
			"hold_ratio": 0.24,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.72,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(0.95, 0.82, 0.44, 0.34),
		}
	),
	RULE_RADIANT_GRENINJA_CONCEALED_CARDS: _make_profile(
		"ready_radiant_greninja_concealed_cards",
		RULE_RADIANT_GRENINJA_CONCEALED_CARDS,
		RADIANT_GRENINJA_READY_ASSET_SPECS,
		{
			"duration": 1.5,
			"effect_size": Vector2(470.0, 470.0),
			"anchor_offset": Vector2(0.0, -36.0),
			"start_scale": 0.72,
			"peak_scale": 1.18,
			"hold_scale": 1.1,
			"end_scale": 1.03,
			"hold_ratio": 0.2,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.62,
			"portrait_effect_width_ratio": 0.86,
			"portrait_effect_min_size": 560.0,
			"portrait_effect_max_size": 760.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.1),
			"flash_color": Color(0.2, 0.62, 1.0, 0.3),
		}
	),
	RULE_CERULEDGE_DISCARD_ENERGY: _make_profile(
		"ready_ceruledge_discard_energy",
		RULE_CERULEDGE_DISCARD_ENERGY,
		CERULEDGE_READY_ASSET_SPECS,
		{
			"duration": 1.6,
			"effect_size": Vector2(500.0, 500.0),
			"anchor_offset": Vector2(0.0, -40.0),
			"start_scale": 0.72,
			"peak_scale": 1.2,
			"hold_scale": 1.12,
			"end_scale": 1.04,
			"hold_ratio": 0.22,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.7,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(0.74, 0.18, 1.0, 0.32),
		}
	),
	RULE_ROARING_MOON_FRENZIED: _make_profile(
		"ready_roaring_moon_frenzied",
		RULE_ROARING_MOON_FRENZIED,
		ROARING_MOON_READY_ASSET_SPECS,
		{
			"duration": 1.62,
			"effect_size": Vector2(520.0, 520.0),
			"anchor_offset": Vector2(0.0, -44.0),
			"start_scale": 0.7,
			"peak_scale": 1.18,
			"hold_scale": 1.1,
			"end_scale": 1.03,
			"hold_ratio": 0.24,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.72,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(0.5, 0.12, 0.68, 0.34),
		}
	),
	RULE_GARDEVOIR_PSYCHIC_EMBRACE: _make_profile(
		"ready_gardevoir_psychic_embrace",
		RULE_GARDEVOIR_PSYCHIC_EMBRACE,
		GARDEVOIR_READY_ASSET_SPECS,
		{
			"duration": 1.62,
			"effect_size": Vector2(520.0, 520.0),
			"anchor_offset": Vector2(0.0, -44.0),
			"start_scale": 0.7,
			"peak_scale": 1.18,
			"hold_scale": 1.1,
			"end_scale": 1.03,
			"hold_ratio": 0.24,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.72,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(0.95, 0.36, 1.0, 0.34),
		}
	),
	RULE_ARCHALUDON_METAL_BRIDGE: _make_profile(
		"ready_archaludon_metal_bridge",
		RULE_ARCHALUDON_METAL_BRIDGE,
		ARCHALUDON_READY_ASSET_SPECS,
		{
			"duration": 1.62,
			"effect_size": Vector2(520.0, 520.0),
			"anchor_offset": Vector2(0.0, -44.0),
			"start_scale": 0.7,
			"peak_scale": 1.18,
			"hold_scale": 1.1,
			"end_scale": 1.03,
			"hold_ratio": 0.24,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.72,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(0.68, 0.84, 1.0, 0.34),
		}
	),
	RULE_MARNIES_GRIMMSNARL_PUNK_UP: _make_profile(
		"ready_marnies_grimmsnarl_punk_up",
		RULE_MARNIES_GRIMMSNARL_PUNK_UP,
		MARNIES_GRIMMSNARL_READY_ASSET_SPECS,
		{
			"duration": 1.64,
			"effect_size": Vector2(520.0, 520.0),
			"anchor_offset": Vector2(0.0, -40.0),
			"start_scale": 0.7,
			"peak_scale": 1.2,
			"hold_scale": 1.12,
			"end_scale": 1.03,
			"hold_ratio": 0.24,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.74,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(0.96, 0.12, 0.78, 0.34),
		}
	),
	RULE_NS_ZOROARK_NIGHT_JOKER: _make_profile(
		"ready_ns_zoroark_night_joker",
		RULE_NS_ZOROARK_NIGHT_JOKER,
		NS_ZOROARK_READY_ASSET_SPECS,
		{
			"duration": 1.62,
			"effect_size": Vector2(520.0, 520.0),
			"anchor_offset": Vector2(0.0, -42.0),
			"start_scale": 0.7,
			"peak_scale": 1.19,
			"hold_scale": 1.11,
			"end_scale": 1.03,
			"hold_ratio": 0.23,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.72,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(0.14, 0.78, 1.0, 0.32),
		}
	),
	RULE_RAGING_BOLT_BELLOWING_THUNDER_LETHAL: _make_profile(
		"ready_raging_bolt_bellowing_thunder_lethal",
		RULE_RAGING_BOLT_BELLOWING_THUNDER_LETHAL,
		RAGING_BOLT_READY_ASSET_SPECS,
		{
			"duration": 1.66,
			"effect_size": Vector2(520.0, 520.0),
			"anchor_offset": Vector2(0.0, -42.0),
			"start_scale": 0.68,
			"peak_scale": 1.18,
			"hold_scale": 1.1,
			"end_scale": 1.02,
			"hold_ratio": 0.24,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.76,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(1.0, 0.84, 0.12, 0.34),
		}
	),
	RULE_ETHANS_HO_OH_GOLDEN_FLAME: _make_profile(
		"ready_ethans_ho_oh_golden_flame",
		RULE_ETHANS_HO_OH_GOLDEN_FLAME,
		ETHANS_HO_OH_READY_ASSET_SPECS,
		{
			"duration": 1.66,
			"effect_size": Vector2(520.0, 520.0),
			"anchor_offset": Vector2(0.0, -42.0),
			"start_scale": 0.7,
			"peak_scale": 1.2,
			"hold_scale": 1.12,
			"end_scale": 1.03,
			"hold_ratio": 0.24,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.76,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(1.0, 0.68, 0.08, 0.34),
		}
	),
	RULE_CYNTHIAS_GARCHOMP_SPIRAL_DRAW: _make_profile(
		"ready_cynthias_garchomp_spiral_draw",
		RULE_CYNTHIAS_GARCHOMP_SPIRAL_DRAW,
		CYNTHIAS_GARCHOMP_READY_ASSET_SPECS,
		{
			"duration": 1.64,
			"effect_size": Vector2(520.0, 520.0),
			"anchor_offset": Vector2(0.0, -40.0),
			"start_scale": 0.7,
			"peak_scale": 1.2,
			"hold_scale": 1.11,
			"end_scale": 1.03,
			"hold_ratio": 0.23,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.74,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(1.0, 0.78, 0.2, 0.32),
		}
	),
	RULE_ETHANS_TYPHLOSION_PARTNER_BLAST_LETHAL: _make_profile(
		"ready_ethans_typhlosion_partner_blast_lethal",
		RULE_ETHANS_TYPHLOSION_PARTNER_BLAST_LETHAL,
		ETHANS_TYPHLOSION_READY_ASSET_SPECS,
		{
			"duration": 1.64,
			"effect_size": Vector2(520.0, 520.0),
			"anchor_offset": Vector2(0.0, -40.0),
			"start_scale": 0.7,
			"peak_scale": 1.2,
			"hold_scale": 1.12,
			"end_scale": 1.03,
			"hold_ratio": 0.23,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.74,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(1.0, 0.36, 0.04, 0.34),
		}
	),
	RULE_BLAZIKEN_BOILING_SPIRIT_ACCELERATION: _make_profile(
		"ready_blaziken_boiling_spirit_acceleration",
		RULE_BLAZIKEN_BOILING_SPIRIT_ACCELERATION,
		BLAZIKEN_READY_ASSET_SPECS,
		{
			"duration": 1.64,
			"effect_size": Vector2(520.0, 520.0),
			"anchor_offset": Vector2(0.0, -40.0),
			"start_scale": 0.7,
			"peak_scale": 1.2,
			"hold_scale": 1.12,
			"end_scale": 1.03,
			"hold_ratio": 0.24,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.74,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(1.0, 0.42, 0.08, 0.34),
		}
	),
	RULE_PIDGEOT_QUICK_SEARCH_CONTROL: _make_profile(
		"ready_pidgeot_quick_search_control",
		RULE_PIDGEOT_QUICK_SEARCH_CONTROL,
		PIDGEOT_READY_ASSET_SPECS,
		{
			"duration": 1.64,
			"effect_size": Vector2(520.0, 520.0),
			"anchor_offset": Vector2(0.0, -42.0),
			"start_scale": 0.7,
			"peak_scale": 1.18,
			"hold_scale": 1.1,
			"end_scale": 1.03,
			"hold_ratio": 0.24,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.74,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(1.0, 0.82, 0.36, 0.32),
		}
	),
	RULE_FLAREON_BURNING_CHARGE_ENGINE: _make_profile(
		"ready_flareon_burning_charge_engine",
		RULE_FLAREON_BURNING_CHARGE_ENGINE,
		FLAREON_READY_ASSET_SPECS,
		{
			"duration": 1.64,
			"effect_size": Vector2(520.0, 520.0),
			"anchor_offset": Vector2(0.0, -38.0),
			"start_scale": 0.7,
			"peak_scale": 1.2,
			"hold_scale": 1.12,
			"end_scale": 1.03,
			"hold_ratio": 0.24,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.74,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(1.0, 0.5, 0.12, 0.34),
		}
	),
	RULE_HOPS_ZACIAN_BRAVE_BLADE_LETHAL: _make_profile(
		"ready_hops_zacian_brave_blade_lethal",
		RULE_HOPS_ZACIAN_BRAVE_BLADE_LETHAL,
		HOPS_ZACIAN_READY_ASSET_SPECS,
		{
			"duration": 1.66,
			"effect_size": Vector2(520.0, 520.0),
			"anchor_offset": Vector2(0.0, -40.0),
			"start_scale": 0.68,
			"peak_scale": 1.2,
			"hold_scale": 1.12,
			"end_scale": 1.03,
			"hold_ratio": 0.24,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.76,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(0.72, 0.88, 1.0, 0.34),
		}
	),
	RULE_YANMEGA_BUZZING_RUSH_ACCELERATION: _make_profile(
		"ready_yanmega_buzzing_rush_acceleration",
		RULE_YANMEGA_BUZZING_RUSH_ACCELERATION,
		YANMEGA_READY_ASSET_SPECS,
		{
			"duration": 1.64,
			"effect_size": Vector2(520.0, 520.0),
			"anchor_offset": Vector2(0.0, -44.0),
			"start_scale": 0.7,
			"peak_scale": 1.2,
			"hold_scale": 1.12,
			"end_scale": 1.03,
			"hold_ratio": 0.24,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.74,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.13),
			"flash_color": Color(0.42, 1.0, 0.16, 0.34),
		}
	),
	RULE_MUNKIDORI_ADRENA_BRAIN_TRANSFER: _make_profile(
		"ready_munkidori_adrena_brain_transfer",
		RULE_MUNKIDORI_ADRENA_BRAIN_TRANSFER,
		MUNKIDORI_READY_ASSET_SPECS,
		{
			"duration": 1.64,
			"effect_size": Vector2(520.0, 520.0),
			"anchor_offset": Vector2(0.0, -40.0),
			"start_scale": 0.7,
			"peak_scale": 1.2,
			"hold_scale": 1.12,
			"end_scale": 1.03,
			"hold_ratio": 0.24,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.74,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(0.82, 0.18, 1.0, 0.34),
		}
	),
	RULE_TOEDSCRUEL_COLONY_RUSH_LETHAL: _make_profile(
		"ready_toedscruel_colony_rush_lethal",
		RULE_TOEDSCRUEL_COLONY_RUSH_LETHAL,
		TOEDSCRUEL_READY_ASSET_SPECS,
		{
			"duration": 1.66,
			"effect_size": Vector2(520.0, 520.0),
			"anchor_offset": Vector2(0.0, -38.0),
			"start_scale": 0.68,
			"peak_scale": 1.2,
			"hold_scale": 1.12,
			"end_scale": 1.03,
			"hold_ratio": 0.24,
			"flipbook_ratio": 0.96,
			"portrait_duration": 1.76,
			"portrait_effect_width_ratio": 0.9,
			"portrait_effect_min_size": 600.0,
			"portrait_effect_max_size": 820.0,
			"portrait_anchor_offset_ratio": Vector2(0.0, -0.12),
			"flash_color": Color(0.5, 1.0, 0.18, 0.34),
		}
	),
}


func get_profile(rule_id: String) -> RefCounted:
	return _profiles.get(rule_id, null) as RefCounted


func resolve_profile_for_trigger(trigger: Dictionary) -> RefCounted:
	return get_profile(str(trigger.get("rule_id", "")))


func list_rule_ids() -> Array[String]:
	var ids: Array[String] = []
	for key_variant: Variant in _profiles.keys():
		ids.append(str(key_variant))
	return ids


static func _make_profile(profile_id: String, rule_id: String, asset_specs: Dictionary, options: Dictionary = {}) -> RefCounted:
	var profile: RefCounted = BattleReadyVfxProfileScript.new()
	profile.set("profile_id", profile_id)
	profile.set("rule_id", rule_id)
	profile.set("asset_specs", asset_specs.duplicate(true))
	if options.has("duration"):
		profile.set("duration", float(options.get("duration")))
	if options.has("effect_size"):
		profile.set("effect_size", options.get("effect_size"))
	if options.has("anchor_offset"):
		profile.set("anchor_offset", options.get("anchor_offset"))
	if options.has("start_scale"):
		profile.set("start_scale", float(options.get("start_scale")))
	if options.has("peak_scale"):
		profile.set("peak_scale", float(options.get("peak_scale")))
	if options.has("hold_scale"):
		profile.set("hold_scale", float(options.get("hold_scale")))
	if options.has("end_scale"):
		profile.set("end_scale", float(options.get("end_scale")))
	if options.has("hold_ratio"):
		profile.set("hold_ratio", float(options.get("hold_ratio")))
	if options.has("flipbook_ratio"):
		profile.set("flipbook_ratio", float(options.get("flipbook_ratio")))
	if options.has("portrait_duration"):
		profile.set("portrait_duration", float(options.get("portrait_duration")))
	if options.has("portrait_effect_width_ratio"):
		profile.set("portrait_effect_width_ratio", float(options.get("portrait_effect_width_ratio")))
	if options.has("portrait_effect_min_size"):
		profile.set("portrait_effect_min_size", float(options.get("portrait_effect_min_size")))
	if options.has("portrait_effect_max_size"):
		profile.set("portrait_effect_max_size", float(options.get("portrait_effect_max_size")))
	if options.has("portrait_anchor_offset_ratio"):
		profile.set("portrait_anchor_offset_ratio", options.get("portrait_anchor_offset_ratio"))
	if options.has("flash_color"):
		profile.set("flash_color", options.get("flash_color"))
	if options.has("flash_enabled"):
		profile.set("flash_enabled", bool(options.get("flash_enabled")))
	return profile
