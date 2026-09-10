# TinyScape — Dialogue Runner & Condition Evaluator
class_name DialogueRunner
extends RefCounted

signal dialogue_message_emitted(msg: String)

var game_state: RefCounted # GameState
var player: Node3D
var current_dialogue: Dictionary = {}
var current_node_id: String = ""
var visited_effect_nodes: Dictionary = {} # Set of node_id to prevent double execution in loops

func initialize(p_game_state: RefCounted, p_player: Node3D) -> void:
	game_state = p_game_state
	player = p_player

func start_dialogue(dialogue_id: String) -> Dictionary:
	current_dialogue = DialogueData.get_dialogue(dialogue_id)
	visited_effect_nodes.clear()
	
	# Evaluate start node: if start has show_if and fails, check fallback
	var start_id = "start"
	if current_dialogue.has("start_returning") and current_dialogue["start_returning"].has("show_if"):
		if evaluate_condition(current_dialogue["start_returning"]["show_if"]):
			start_id = "start_returning"
	elif current_dialogue.has("start") and current_dialogue["start"].has("show_if"):
		if not evaluate_condition(current_dialogue["start"]["show_if"]):
			if current_dialogue.has("start_returning"):
				start_id = "start_returning"

	return go_to_node(start_id)

func go_to_node(node_id: String) -> Dictionary:
	current_node_id = node_id
	if not current_dialogue.has(node_id):
		return { "type": "end" }

	var raw_node = current_dialogue[node_id]
	var node_type = raw_node.get("type", "end")

	if node_type == "end":
		return { "type": "end" }

	# Run effects once per node
	if not visited_effect_nodes.has(node_id):
		visited_effect_nodes[node_id] = true
		if raw_node.has("effects"):
			for eff in raw_node["effects"]:
				apply_effect(eff)

	if node_type == "say":
		var text_lines: Array = raw_node.get("text", [])
		var processed_lines: Array[String] = []
		for line in text_lines:
			processed_lines.append(substitute_text(str(line)))
		return {
			"node_id": node_id,
			"type": "say",
			"speaker": raw_node.get("speaker", "npc"),
			"text": processed_lines,
			"next": raw_node.get("next", "end")
		}
	elif node_type == "choice":
		var raw_options: Array = raw_node.get("options", [])
		var valid_options: Array[Dictionary] = []
		for opt in raw_options:
			if opt.has("show_if"):
				if not evaluate_condition(opt["show_if"]):
					continue
			valid_options.append({
				"text": substitute_text(opt.get("text", "")),
				"next": opt.get("next", "end")
			})
		return {
			"node_id": node_id,
			"type": "choice",
			"prompt": substitute_text(raw_node.get("prompt", "")),
			"options": valid_options
		}

	return { "type": "end" }

func evaluate_condition(cond: Dictionary) -> bool:
	for key in cond:
		match key:
			"skill_at_least":
				var skill_req = cond[key]
				var _skill_name: String = str(skill_req[0])
				var req_level: int = int(skill_req[1])
				var player_lvl: int = player.get("woodcut_level") if ("woodcut_level" in player) else 1
				if player_lvl < req_level:
					return false
			"has_items":
				var item_req = cond[key]
				var item_name: String = str(item_req[0])
				var count_req: int = int(item_req[1])
				var count = QuestData.count_inventory_items(player, item_name)
				if count < count_req:
					return false
			"coins_at_least":
				var req_coins: int = int(cond[key])
				var player_coins: int = player.get("coins") if ("coins" in player) else 0
				if player_coins < req_coins:
					return false
			"quest_state":
				var q_req = cond[key]
				var q_id: String = str(q_req[0])
				var expected_state: String = str(q_req[1])
				if game_state.get_quest_state(q_id) != expected_state:
					return false
			"flag":
				var flag_req = cond[key]
				var flag_name: String = str(flag_req[0])
				var expected_val: bool = bool(flag_req[1])
				if game_state.get_flag(flag_name) != expected_val:
					return false
			"not":
				var nested = cond[key]
				if evaluate_condition(nested):
					return false
	return true

func apply_effect(eff: Dictionary) -> void:
	for key in eff:
		match key:
			"set_quest":
				var q_args = eff[key]
				game_state.set_quest_state(str(q_args[0]), str(q_args[1]))
			"set_flag":
				var f_args = eff[key]
				game_state.set_flag(str(f_args[0]), bool(f_args[1]))
			"take_items":
				var take_args = eff[key]
				var item_name: String = str(take_args[0])
				var count: int = int(take_args[1])
				var remaining_to_take = count
				var new_inv: Array[Dictionary] = []
				for item in player.inventory:
					if item.get("name", "") == item_name and remaining_to_take > 0:
						remaining_to_take -= 1
					else:
						new_inv.append(item)
				player.inventory = new_inv
			"give_coins":
				var amount: int = int(eff[key])
				player.coins += amount
			"give_xp":
				var xp_args = eff[key]
				var amount: int = int(xp_args[1])
				player.woodcut_xp += amount
				player.woodcut_level = WoodcuttingData.get_level_for_xp(player.woodcut_xp)
			"message":
				dialogue_message_emitted.emit(str(eff[key]))

func substitute_text(text: String) -> String:
	var res = text
	res = res.replace("{player_name}", "Wanderer")
	var wc_lvl = str(player.get("woodcut_level")) if ("woodcut_level" in player) else "1"
	res = res.replace("{skill_level:woodcutting}", wc_lvl)
	var coins_val = str(player.get("coins")) if ("coins" in player) else "0"
	res = res.replace("{coins}", coins_val)
	var logs_val = str(player.get("logs")) if ("logs" in player) else "0"
	res = res.replace("{logs}", logs_val)
	return res
