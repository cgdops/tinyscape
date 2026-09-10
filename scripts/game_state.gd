# TinyScape — Central Game State Store (Flags & Quests)
class_name GameState
extends RefCounted

signal flag_changed(flag_name: String, value: bool)
signal quest_state_changed(quest_id: String, state: String, old_state: String)

const VALID_QUEST_STATES: Array[String] = [
	"unstarted",
	"offered",
	"active",
	"complete"
]

var flags: Dictionary = {}
var quests: Dictionary = {}

func get_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)

func set_flag(flag_name: String, value: bool) -> void:
	var old_val: bool = get_flag(flag_name)
	flags[flag_name] = value
	if old_val != value:
		flag_changed.emit(flag_name, value)

func get_quest_state(quest_id: String) -> String:
	return quests.get(quest_id, "unstarted")

func set_quest_state(quest_id: String, new_state: String) -> bool:
	var current_state: String = get_quest_state(quest_id)
	if current_state == new_state:
		return true

	var current_idx: int = VALID_QUEST_STATES.find(current_state)
	var new_idx: int = VALID_QUEST_STATES.find(new_state)

	if new_idx == -1:
		push_warning("Invalid quest state: '%s'" % new_state)
		return false

	if new_idx < current_idx:
		push_warning("Cannot regress quest '%s' from state '%s' backward to '%s'." % [quest_id, current_state, new_state])
		return false

	quests[quest_id] = new_state
	quest_state_changed.emit(quest_id, new_state, current_state)
	return true
