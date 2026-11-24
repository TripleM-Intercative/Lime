class_name LootTable
extends Node

const RARITY_CHANCES: Dictionary[Enums.Rarity, float] = {
	Enums.Rarity.Common: 0.5,
	Enums.Rarity.Rare: 0.3,
	Enums.Rarity.Epic: 0.15,
	Enums.Rarity.Legendary: 0.05,
}
