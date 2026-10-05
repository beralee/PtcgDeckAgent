extends RefCounted
## Prepare reusable personality lines off the game clock. Replies only update a
## bank; live facts are bound synchronously when a confirmed cue is displayed.
signal line_ready(text: String, cue: Dictionary)
const Voice := preload("res://scripts/commentary/OpponentTalkVoice.gd")
const Mood := preload("res://scripts/commentary/OpponentMood.gd")
const Knowledge := preload("res://scripts/commentary/CommentaryKnowledge.gd")
const MAX_CALLS := 3
const MAX_TOKENS := 45000
var personality := "是一个大逗比，臭牌篓子"
var bank: Dictionary = {}
var history: Array[Dictionary] = []
var owner: Node
var client: RefCounted
var config: Dictionary = {}
var active := false
var in_flight := false
var generation := 0
var calls := 0
var charged_tokens := 0
var failures := 0
var signature := ""
var next_request_at := 0.0
var pending: Dictionary = {}
var last_spoken := -100.0
var last_turn := -1
var turn_lines := 0
var variants: Dictionary = {}
var terminal := false
var model_ready := false

func start(parent: Node, api_config: Dictionary, transport: RefCounted = null) -> void:
	owner = parent
	config = api_config.duplicate(true)
	personality = str(config.get("ai_personality", personality)).strip_edges().left(240)
	if personality.is_empty(): personality = "是一个大逗比，臭牌篓子"
	bank = Voice.local_bank(personality)
	client = transport if transport != null else preload("res://scripts/commentary/CommentaryDeepSeekClient.gd").new()
	active = true

func prepare(knowledge: Dictionary, now: float) -> void:
	if not active or terminal or in_flight or str(config.get("api_key", "")).is_empty(): return
	if calls >= MAX_CALLS or failures >= 2 or now < next_request_at: return
	var key := Knowledge.signature(knowledge)
	if key == signature: return
	var payload := Voice.payload(personality, knowledge, str(config.get("model", "deepseek-v4-flash")))
	var reserve := JSON.stringify(payload).to_utf8_buffer().size() + int(payload.max_tokens) + 256
	if charged_tokens + reserve > MAX_TOKENS: return
	calls += 1
	charged_tokens += reserve
	in_flight = true
	next_request_at = now + 30.0
	var callback := _completed.bind(generation, key, reserve)
	var error: int = client.request_json(owner, str(config.get("endpoint", "https://api.deepseek.com")), str(config.api_key), payload, callback)
	if error != OK: callback.call_deferred({"ok": false})

func _completed(response: Dictionary, request_generation: int, key: String, reserve: int) -> void:
	if not active or request_generation != generation: return
	in_flight = false
	var usage := int(response.get("tokens", -1))
	if usage >= 0: charged_tokens = maxi(0, charged_tokens - reserve + usage)
	if not bool(response.get("ok", false)) or not response.get("content") is Dictionary or not Voice.valid_bank(response.content):
		failures += 1
		return
	bank = response.content.lines.duplicate(true)
	signature = key
	model_ready = true

func offer(cue: Dictionary, now: float) -> void:
	if not active or terminal or cue.is_empty(): return
	cue = Mood.bind(cue)
	var priority := int(cue.get("priority", 0))
	if priority >= 100:
		pending.clear()
		_publish(cue, now)
		terminal = true
		generation += 1
		in_flight = false
		client.cancel_pending_requests()
		return
	if int(cue.turn) != last_turn:
		last_turn = int(cue.turn)
		turn_lines = 0
	if turn_lines >= 3: return
	var gap := 2.5 if priority >= 60 else 5.5
	if now - last_spoken >= gap:
		_publish(cue, now)
	elif priority >= 60:
		# Only a recent resolved result can wait. Never queue a shout to be
		# delivered after its move, or a turn-end quip over a later turn.
		pending = {"cue": cue.duplicate(true), "expires": now + 6.0}

func new_action() -> void:
	pending.clear()

func tick(now: float) -> void:
	if not active or pending.is_empty(): return
	if now > float(pending.expires):
		pending.clear()
	elif now - last_spoken >= 2.5:
		var cue: Dictionary = pending.cue
		pending.clear()
		_publish(cue, now)

func _publish(cue: Dictionary, now: float) -> void:
	var trigger := str(cue.trigger)
	var key := Mood.line_key(cue)
	var index := int(variants.get(key, 0))
	var text := Voice.render(bank, cue, index)
	if text.is_empty(): return
	variants[key] = index + 1
	last_spoken = now
	turn_lines += 1
	var record := cue.duplicate(true)
	record["text"] = text
	record["source"] = "model_bank" if model_ready else "local_bank"
	history.append(record)
	if history.size() > 60: history.pop_front()
	line_ready.emit(text, cue)

func stop() -> void:
	active = false
	generation += 1
	in_flight = false
	pending.clear()
	config.clear()
	if client != null: client.cancel_pending_requests()
	client = null
	owner = null
