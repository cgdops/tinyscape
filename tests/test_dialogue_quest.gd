extends SceneTree

const World = preload("res://scripts/world.gd")
const Player = preload("res://scripts/player.gd")
const GameState = preload("res://scripts/game_state.gd")
const DialogueRunner = preload("res://scripts/dialogue_runner.gd")
const DialogueData = preload("res://scripts/dialogue_data.gd")
const QuestData = preload("res://scripts/quest_data.gd")
const NpcNode = preload("res://scripts/npc_node.gd")
const WoodcuttingData = preload("res://scripts/woodcutting_data.gd")

var _checks: int = 0
var _failures: int = 0

func _assert(cond: bool, msg: String) -> void:
	_checks += 1
	if cond:
		print("  [PASS] %s" % msg)
	else:
		_failures += 1
		printerr("  [FAIL] %s" % msg)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	print("--- Running Dialogue & Quest test suite ---")

	# 1. Verify GameState monotonicity and flag operations
	var gs = GameState.new()
	_assert(gs.get_quest_state("thursdays_float") == "unstarted", "Initial quest state is unstarted")
	
	var res = gs.set_quest_state("thursdays_float", "offered")
	_assert(res and gs.get_quest_state("thursdays_float") == "offered", "Transition to offered allowed")

	res = gs.set_quest_state("thursdays_float", "active")
	_assert(res and gs.get_quest_state("thursdays_float") == "active", "Transition to active allowed")

	# Invalid backward transition
	res = gs.set_quest_state("thursdays_float", "offered")
	_assert(not res and gs.get_quest_state("thursdays_float") == "active", "Backward transition active -> offered rejected")

	res = gs.set_quest_state("thursdays_float", "complete")
	_assert(res and gs.get_quest_state("thursdays_float") == "complete", "Transition to complete allowed")

	# Flags
	_assert(gs.get_flag("unknown_flag") == false, "Default flag is false")
	gs.set_flag("mabb_first_meeting", true)
	_assert(gs.get_flag("mabb_first_meeting") == true, "Flag set persists")

	# 2. Verify World NPC placement & 3D Assets
	var world = World.new()
	world.build()
	_assert(world.is_npc_at(Vector2i(21, 2)), "Mabb Truet present at (21, 2)")
	_assert(world.blocked.has(Vector2i(21, 2)), "Mabb Truet tile (21, 2) is blocked for movement")
	var npc = world.get_npc_at(Vector2i(21, 2))
	_assert(npc != null and npc.id == "mabb_truet", "NPC id matches mabb_truet")
	_assert(npc.facing == Vector2i(1, -1), "Mabb initial rest facing is (1, -1)")
	var anim_player = npc.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_assert(anim_player != null and anim_player.has_animation("Idle") and anim_player.has_animation("Talk"), "Mabb Truet GLB model loaded with Idle and Talk animations")
	var axe = world.find_child("MabbFellingAxe", true, false)
	_assert(axe != null, "MabbFellingAxe placed beside log pile in lumber clearing")

	# 3. Verify Player and DialogueRunner condition evaluation
	var player = Player.new()
	player.initialize(world, Vector2i(20, 2))
	var runner = DialogueRunner.new()
	runner.initialize(gs, player)

	# Skill level gate check
	var cond_skill = {"skill_at_least": ["woodcutting", 15]}
	_assert(not runner.evaluate_condition(cond_skill), "Level 1 player fails level 15 woodcutting check")
	player.woodcut_level = 15
	_assert(runner.evaluate_condition(cond_skill), "Level 15 player passes level 15 woodcutting check")

	# Item count condition
	var cond_items = {"has_items": ["Willow Log", 20]}
	_assert(not runner.evaluate_condition(cond_items), "Empty rucksack fails 20 willow logs condition")
	for i in range(20):
		player.add_item("willow", "Willow Log", 4)
	_assert(runner.evaluate_condition(cond_items), "Rucksack with 20 logs passes condition")

	# Not condition
	var cond_not = {"not": {"flag": ["test_flag", true]}}
	_assert(runner.evaluate_condition(cond_not), "Not condition passes when flag is unset")
	gs.set_flag("test_flag", true)
	_assert(not runner.evaluate_condition(cond_not), "Not condition fails when flag is set")

	# 4. Quest progression simulation via DialogueRunner
	var test_gs = GameState.new()
	var test_player = Player.new()
	test_player.initialize(world, Vector2i(20, 2))
	var test_runner = DialogueRunner.new()
	test_runner.initialize(test_gs, test_player)

	# Start dialogue with Mabb Truet
	var current_node = test_runner.start_dialogue("mabb_truet")
	_assert(current_node.get("node_id") == "start", "Starts at start node")
	_assert(test_gs.get_flag("met_mabb") == true, "Entering start node set met_mabb flag")

	# Advance past say node to menu
	current_node = test_runner.go_to_node(current_node.get("next"))
	_assert(current_node.get("type") == "choice", "Advances to menu choice node")

	# Select quest inquiry choice: "Anything you need doing?"
	var valid_choices = current_node.get("options", [])
	var quest_choice_next = ""
	for opt in valid_choices:
		if "Anything you need doing" in opt.text:
			quest_choice_next = opt.next
			break
	_assert(quest_choice_next != "", "Found quest offer choice option")
	current_node = test_runner.go_to_node(quest_choice_next)

	# Mabb offers Thursday's Float
	_assert(current_node.get("node_id") == "quest_offer", "Arrived at quest_offer node")

	# Advance to choice
	current_node = test_runner.go_to_node(current_node.get("next"))
	_assert(current_node.get("node_id") == "quest_offer_choice", "Arrived at quest_offer_choice node")

	# Choose accept: "Sure, I can do that."
	valid_choices = current_node.get("options", [])
	var accept_next = ""
	for opt in valid_choices:
		if "Sure, I can do that" in opt.text:
			accept_next = opt.next
			break
	_assert(accept_next != "", "Found accept choice option")
	current_node = test_runner.go_to_node(accept_next)
	_assert(test_gs.get_quest_state("thursdays_float") == "active", "Quest state is now active")

	# 5. Hand-in verification
	# Now start dialogue again with active quest
	current_node = test_runner.start_dialogue("mabb_truet")
	_assert(current_node.get("node_id") == "start_returning", "Returning player goes to start_returning")

	current_node = test_runner.go_to_node(current_node.get("next"))
	_assert(current_node.get("node_id") == "menu", "Arrived at menu")

	# Without logs, "I've got your twenty willow logs" should NOT be visible
	valid_choices = current_node.get("options", [])
	var handin_found = false
	for c in valid_choices:
		if "twenty willow logs" in c.text:
			handin_found = true
	_assert(not handin_found, "Hand-in option not visible without 20 logs")

	# Add 20 willow logs and check again
	for i in range(20):
		test_player.add_item("willow", "Willow Log", 4)

	# Refresh menu choices with logs in inventory
	current_node = test_runner.go_to_node("menu")
	valid_choices = current_node.get("options", [])
	var handin_next = ""
	for opt in valid_choices:
		if "twenty willow logs" in opt.text:
			handin_next = opt.next
			break
	_assert(handin_next != "", "Hand-in option is visible with 20 logs")

	# Select hand-in
	var initial_coins = test_player.coins
	var initial_xp = test_player.woodcut_xp
	current_node = test_runner.go_to_node(handin_next)

	# Advance to complete node
	_assert(current_node.get("node_id") == "quest_hand_in", "Arrived at quest_hand_in node")
	_assert(test_gs.get_quest_state("thursdays_float") == "complete", "Quest marked complete")
	_assert(test_player.inventory.size() == 0, "20 willow logs consumed from rucksack")
	_assert(test_player.coins == initial_coins + 150, "Awarded 150 coins")
	_assert(test_player.woodcut_xp == initial_xp + 2500, "Awarded 2500 Woodcutting XP")

	# Post-completion dialogue check
	current_node = test_runner.start_dialogue("mabb_truet")
	_assert(current_node.get("node_id") == "start_returning", "Post-completion start directs to start_returning")

	# 6. Text substitution test
	var substituted = runner.substitute_text("Hello {player_name}, you have {coins} coins and {logs} logs.")
	_assert("Wanderer" in substituted and "coins" in substituted, "Text substitution works correctly")

	# Clean up
	world.free()
	player.free()
	test_player.free()

	print("\nTEST SUMMARY: %d checks passed, %d failures" % [_checks, _failures])
	if _failures > 0:
		quit(1)
	else:
		quit(0)
