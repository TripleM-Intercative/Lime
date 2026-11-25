class_name LootTable
extends Node

const CARD_RESOURCES_PATH: String = "res://resources/cards/"

const RARITY_CHANCES: Dictionary[Enums.Rarity, float] = {
	Enums.Rarity.Common: 0.5,
	Enums.Rarity.Rare: 0.3,
	Enums.Rarity.Epic: 0.15,
	Enums.Rarity.Legendary: 0.05,
}

var common_cards: Array[BaseCardRes]
var rare_cards: Array[BaseCardRes]
var epic_cards: Array[BaseCardRes]
var legendary_cards: Array[BaseCardRes]

func _init() -> void:
	set_up_loot_containers()

func set_up_loot_containers() -> void:
	for file in ResourceLoader.list_directory(CARD_RESOURCES_PATH):
		if file.ends_with(".tres"):
			var card_resource: Resource = load(CARD_RESOURCES_PATH.path_join(file))
			if card_resource is BaseCardRes:
				match card_resource.rarity:
					Enums.Rarity.Common:
						common_cards.append(card_resource)
					Enums.Rarity.Rare:
						rare_cards.append(card_resource)
					Enums.Rarity.Epic:
						epic_cards.append(card_resource)
					Enums.Rarity.Legendary:
						legendary_cards.append(card_resource)

func roll_base_rarity() -> Enums.Rarity:
	var pulled_rarity: Enums.Rarity = Enums.Rarity.Common
	var rarities: Array[int] = Enums.Rarity.values()
	var roll: float = randf()
	var cumulative_chance: float = 0.0
	for i in range(rarities.size() - 1, -1, -1):
		var rarity = rarities[i]
		cumulative_chance += RARITY_CHANCES.get(rarity, 0.0)
		if roll <= cumulative_chance:
			pulled_rarity = rarity as Enums.Rarity
			break
	return pulled_rarity

func pull_card() -> BaseCardRes:
	var rolled_card_pool: Array[BaseCardRes]
	
	match roll_base_rarity():
		Enums.Rarity.Common:
			rolled_card_pool = common_cards
		Enums.Rarity.Rare:
			rolled_card_pool = rare_cards
		Enums.Rarity.Epic:
			rolled_card_pool = epic_cards
		Enums.Rarity.Legendary:
			rolled_card_pool = legendary_cards
	
	if rolled_card_pool.is_empty():
		return null
	
	var card_index: int = randi_range(0, rolled_card_pool.size() -1)
	var rolled_card: BaseCardRes = rolled_card_pool[card_index].duplicate()
	rolled_card.rarity = roll_new_rarity(rolled_card.rarity)
	
	return rolled_card

func roll_new_rarity(base_rarity: Enums.Rarity) -> Enums.Rarity:
	var new_rarity_index: int = base_rarity as int
	var roll: float = randf()
	for i in range(new_rarity_index, Enums.Rarity.size() - 1):
		var next_rarity: Enums.Rarity = (i + 1) as Enums.Rarity
		if roll <= RARITY_CHANCES.get(next_rarity):
			new_rarity_index = i + 1
		else:
			break
	return new_rarity_index as Enums.Rarity
