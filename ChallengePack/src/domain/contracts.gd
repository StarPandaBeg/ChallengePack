extends RefCounted

enum Contract { NONE, NO_HEALING, NO_SELF_SHOTS, NO_CUFFS, NO_HINTS, UNTOUCHABLE_CHARGE, FAIR_CALIBER, NO_STEALING, DRY_LAW, NO_INVERSION, NO_INSURANCE, TWO_FOR_ONE, LEAKY_GUN }
# IDs and setting values are append-only: old saved choices keep their meaning.
const LEGACY_SETTING_COUNT = Contract.LEAKY_GUN + 2
const ALL_IDS = [Contract.NO_HEALING, Contract.NO_SELF_SHOTS, Contract.NO_CUFFS, Contract.NO_HINTS, Contract.UNTOUCHABLE_CHARGE, Contract.FAIR_CALIBER, Contract.NO_STEALING, Contract.DRY_LAW, Contract.NO_INVERSION, Contract.NO_INSURANCE, Contract.TWO_FOR_ONE, Contract.LEAKY_GUN]
const CATALOG = {
	Contract.NONE: {"key": "CP_OFF", "hud": "CP_OFF", "detail": "CP_TIP_CONTRACT", "items": [], "requires_items": false},
	Contract.NO_HEALING: {"key": "CP_NO_HEALING", "hud": "CP_HUD_NO_HEALING", "detail": "CP_HUD_HEALING_DETAIL", "items": ["cigarettes", "expired medicine"], "requires_items": true},
	Contract.NO_SELF_SHOTS: {"key": "CP_NO_SELF_SHOTS", "hud": "CP_HUD_NO_SELF_SHOTS", "detail": "CP_HUD_SELF_DETAIL", "items": [], "requires_items": false},
	Contract.NO_CUFFS: {"key": "CP_NO_CUFFS", "hud": "CP_HUD_NO_CUFFS", "detail": "CP_HUD_CUFFS_DETAIL", "items": ["handcuffs"], "requires_items": true},
	Contract.NO_HINTS: {"key": "CP_NO_HINTS", "hud": "CP_HUD_NO_HINTS", "detail": "CP_DETAIL_NO_HINTS", "items": ["magnifying glass", "burner phone"], "requires_items": true},
	Contract.UNTOUCHABLE_CHARGE: {"key": "CP_UNTOUCHABLE_CHARGE", "hud": "CP_HUD_UNTOUCHABLE_CHARGE", "detail": "CP_DETAIL_UNTOUCHABLE_CHARGE", "items": ["beer", "inverter"], "requires_items": true},
	Contract.FAIR_CALIBER: {"key": "CP_FAIR_CALIBER", "hud": "CP_HUD_FAIR_CALIBER", "detail": "CP_DETAIL_FAIR_CALIBER", "items": ["handsaw"], "requires_items": true},
	Contract.NO_STEALING: {"key": "CP_NO_STEALING", "hud": "CP_HUD_NO_STEALING", "detail": "CP_DETAIL_NO_STEALING", "items": ["adrenaline"], "requires_items": true},
	Contract.DRY_LAW: {"key": "CP_DRY_LAW", "hud": "CP_HUD_DRY_LAW", "detail": "CP_DETAIL_DRY_LAW", "items": ["beer"], "requires_items": true},
	Contract.NO_INVERSION: {"key": "CP_NO_INVERSION", "hud": "CP_HUD_NO_INVERSION", "detail": "CP_DETAIL_NO_INVERSION", "items": ["inverter"], "requires_items": true},
	Contract.NO_INSURANCE: {"key": "CP_NO_INSURANCE", "hud": "CP_HUD_NO_INSURANCE", "detail": "CP_DETAIL_NO_INSURANCE", "items": [], "requires_items": true},
	Contract.TWO_FOR_ONE: {"key": "CP_TWO_FOR_ONE", "hud": "CP_HUD_TWO_FOR_ONE", "detail": "CP_DETAIL_TWO_FOR_ONE", "items": [], "requires_items": false},
	Contract.LEAKY_GUN: {"key": "CP_LEAKY_GUN", "hud": "CP_HUD_LEAKY_GUN", "detail": "CP_DETAIL_LEAKY_GUN", "items": [], "requires_items": false}
}
static func contract_key(id: int) -> String:
	return CATALOG[id].key

static func hud_key(id: int, used_items: Array = []) -> String:
	if id == Contract.NO_INSURANCE:
		if "magnifying glass" in used_items:
			return "CP_HUD_INSURANCE_NO_CUFFS"
		if "handcuffs" in used_items:
			return "CP_HUD_INSURANCE_NO_GLASS"
	return CATALOG[id].hud

