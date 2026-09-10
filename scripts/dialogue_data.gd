# TinyScape — Dialogue Trees Registry
class_name DialogueData
extends RefCounted

const DIALOGUES: Dictionary = {
	"mabb_truet": {
		"start": {
			"type": "say",
			"speaker": "npc",
			"text": [
				"You're the one who came up the river road.",
				"Mabb Truet. I cut, I stack, I float it down to Harrowick. That's the whole of me."
			],
			"next": "menu",
			"show_if": { "flag": ["met_mabb", false] },
			"effects": [ { "set_flag": ["met_mabb", true] } ]
		},
		"start_returning": {
			"type": "say",
			"speaker": "npc",
			"text": ["Aye?"],
			"next": "menu",
			"show_if": { "flag": ["met_mabb", true] }
		},
		"menu": {
			"type": "choice",
			"options": [
				{
					"text": "How do I cut a tree?",
					"next": "teach_chop",
					"show_if": {
						"skill_at_least": ["woodcutting", 1],
						"flag": ["chopped_a_tree", false]
					}
				},
				{
					"text": "What do you do with the logs?",
					"next": "teach_pile"
				},
				{
					"text": "Anything worth cutting up here?",
					"next": "teach_tiers",
					"show_if": { "skill_at_least": ["woodcutting", 5] }
				},
				{
					"text": "What's that you left at the stump?",
					"next": "custom",
					"show_if": { "flag": ["saw_offering", true] }
				},
				# Thursday's Float Quest Options
				{
					"text": "Anything you need doing?",
					"next": "quest_offer",
					"show_if": { "quest_state": ["thursdays_float", "unstarted"] }
				},
				{
					"text": "About those logs.",
					"next": "quest_reoffer",
					"show_if": { "quest_state": ["thursdays_float", "offered"] }
				},
				{
					"text": "About the logs.",
					"next": "quest_in_progress",
					"show_if": {
						"quest_state": ["thursdays_float", "active"],
						"not": { "has_items": ["Willow Log", 20] }
					}
				},
				{
					"text": "I've got your twenty willow logs.",
					"next": "quest_hand_in",
					"show_if": {
						"quest_state": ["thursdays_float", "active"],
						"has_items": ["Willow Log", 20]
					}
				},
				{
					"text": "Never mind.",
					"next": "end"
				}
			]
		},
		"teach_chop": {
			"type": "say",
			"speaker": "player",
			"text": ["How do I cut a tree?"],
			"next": "teach_chop_mabb"
		},
		"teach_chop_mabb": {
			"type": "say",
			"speaker": "npc",
			"text": [
				"Right-click the tree. Pick 'Chop'. Your legs will do the walking.",
				"Then you keep swinging until it's down. Willows come apart in three. Oak takes four, and you'll feel it.",
				"Walk off mid-swing and you've done nothing but tire yourself. Stand still and finish."
			],
			"next": "menu"
		},
		"teach_pile": {
			"type": "say",
			"speaker": "player",
			"text": ["What do you do with the logs?"],
			"next": "teach_pile_mabb"
		},
		"teach_pile_mabb": {
			"type": "say",
			"speaker": "npc",
			"text": [
				"They go on the pile. Pile goes on the water. Water goes to Harrowick, and Harrowick pays me for the trouble.",
				"Right-click the pile and put yours on it. I'll pay you the same as I'd pay anyone — four a willow, six an oak.",
				"Bring pine and we'll talk properly."
			],
			"next": "menu"
		},
		"teach_tiers": {
			"type": "say",
			"speaker": "player",
			"text": ["Anything worth cutting up here?"],
			"next": "teach_tiers_mabb"
		},
		"teach_tiers_mabb": {
			"type": "say",
			"speaker": "npc",
			"text": [
				"Willow's what the village burns. Oak's what the village builds with.",
				"Pine's what the shipwrights want, and pine's up the Longwood side. Fourteen a log.",
				"Don't go at it yet. You'd blunt the axe and waste the tree, and I'd have to say something about it."
			],
			"next": "menu"
		},
		"custom": {
			"type": "say",
			"speaker": "player",
			"text": ["What's that you left at the stump?"],
			"next": "custom_mabb"
		},
		"custom_mabb": {
			"type": "say",
			"speaker": "npc",
			"text": [
				"Nothing that concerns the axe.",
				"You'll do it too, if you're still here in a year. Nobody'll tell you to."
			],
			"next": "menu"
		},
		# Thursday's Float Quest Dialogue
		"quest_offer": {
			"type": "say",
			"speaker": "npc",
			"text": [
				"There is, since you ask.",
				"I'm a raft short for Thursday. Willow, twenty logs. It's not skilled work and it's not quick, and I've a shoulder that says it isn't mine to do this week.",
				"Cut them, bring them to me here. I'll see you right."
			],
			"next": "quest_offer_choice"
		},
		"quest_offer_choice": {
			"type": "choice",
			"options": [
				{
					"text": "Sure, I can do that.",
					"next": "quest_accept"
				},
				{
					"text": "Not right now.",
					"next": "quest_decline"
				}
			]
		},
		"quest_reoffer": {
			"type": "say",
			"speaker": "npc",
			"text": ["Twenty willow. Still short."],
			"next": "quest_offer_choice"
		},
		"quest_accept": {
			"type": "say",
			"speaker": "npc",
			"text": [
				"Twenty. Willow, mind — the drooping ones. Oak's no use to me for this.",
				"Come back when your rucksack's heavy."
			],
			"next": "menu",
			"effects": [
				{ "set_quest": ["thursdays_float", "active"] },
				{ "message": "Quest started: Thursday's Float" }
			]
		},
		"quest_decline": {
			"type": "say",
			"speaker": "npc",
			"text": ["Suit yourself. The river's not in a hurry either."],
			"next": "menu",
			"effects": [
				{ "set_quest": ["thursdays_float", "offered"] }
			]
		},
		"quest_in_progress": {
			"type": "say",
			"speaker": "player",
			"text": ["I'm still cutting."],
			"next": "quest_in_progress_mabb"
		},
		"quest_in_progress_mabb": {
			"type": "say",
			"speaker": "npc",
			"text": [
				"You've {logs}. I need twenty willow. The pile isn't going to shrink on its own."
			],
			"next": "menu"
		},
		"quest_hand_in": {
			"type": "say",
			"speaker": "npc",
			"text": [
				"Twenty.",
				"Hundred and fifty. That's over the going rate and I'll thank you not to mention it in the village.",
				"You cut cleaner than you did on Monday. That's the whole trick — there isn't one."
			],
			"next": "quest_hand_in_part2",
			"effects": [
				{ "take_items": ["Willow Log", 20] },
				{ "give_coins": 150 },
				{ "give_xp": ["woodcutting", 2500] },
				{ "set_quest": ["thursdays_float", "complete"] },
				{ "set_flag": ["mabb_trusts_you", true] },
				{ "message": "Quest complete: Thursday's Float" }
			]
		},
		"quest_hand_in_part2": {
			"type": "say",
			"speaker": "npc",
			"text": [
				"When you've coin enough, there's a pedlar comes up from Harrowick with iron. Buy something with an edge before you go past the gate."
			],
			"next": "quest_hand_in_player"
		},
		"quest_hand_in_player": {
			"type": "say",
			"speaker": "player",
			"text": ["What's past the gate?"],
			"next": "quest_hand_in_gate_mabb"
		},
		"quest_hand_in_gate_mabb": {
			"type": "say",
			"speaker": "npc",
			"text": ["Things that don't stand still and let you hit them."],
			"next": "menu"
		},
		"end": {
			"type": "say",
			"speaker": "npc",
			"text": ["Mind the roots."],
			"next": "terminal"
		},
		"terminal": {
			"type": "end"
		}
	}
}

static func get_dialogue(dialogue_id: String) -> Dictionary:
	return DIALOGUES.get(dialogue_id, {})
