# TinyScape — Quest Registry & Derived Objectives
class_name QuestData
extends RefCounted

const QUESTS: Dictionary = {
	"thursdays_float": {
		"id": "thursdays_float",
		"display_name": "Thursday's Float",
		"description": "Mabb is one raft short for Thursday and needs 20 willow logs.",
		"journal": {
			"offered": "Mabb Truet needs willow logs for Thursday's float. She has not had an answer yet.",
			"active": "Cut 20 willow logs and bring them to Mabb Truet at the lumber clearing.",
			"complete": "Mabb's raft went down the Sallow on Thursday. She said to come back when your arms are better."
		}
	}
}

static func get_quest_info(quest_id: String) -> Dictionary:
	return QUESTS.get(quest_id, {})

static func get_journal_line(quest_id: String, state: String) -> String:
	var info = get_quest_info(quest_id)
	var journal_map = info.get("journal", {})
	return journal_map.get(state, "")

static func count_inventory_items(player: Node3D, item_name: String) -> int:
	if not ("inventory" in player):
		return 0
	var count: int = 0
	for item in player.inventory:
		if item.get("name", "") == item_name:
			count += 1
	return count
