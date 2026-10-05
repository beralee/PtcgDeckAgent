extends RefCounted
## Display-only asynchronous agent. No GameState/scene/action authority enters here.
signal line_ready(text: String, source: String)
signal status_changed(text: String)
const Prompt := preload("res://scripts/commentary/CommentaryPrompt.gd")
const Knowledge := preload("res://scripts/commentary/CommentaryKnowledge.gd")
const MAX_CALLS := 24
const MAX_TOKENS := 120000
const MIN_INTERVAL := 9.0
var client: RefCounted
var owner: Node
var config: Dictionary = {}
var active := false
var in_flight := false
var generation := 0
var calls := 0
var charged_tokens := 0
var failures := 0
var next_request_at := 0.0
var pending: Dictionary = {}
var latest_id := 0
var plans: Array = []
var prepared_signature := ""
var last_text := ""
var history: Array[Dictionary] = []
var stable := false
var local_only := false

func start(parent: Node, api_config: Dictionary, transport: RefCounted = null) -> void:
	owner = parent
	config = api_config.duplicate(true)
	client = transport if transport != null else preload("res://scripts/commentary/CommentaryDeepSeekClient.gd").new()
	active = true
	local_only = str(config.get("api_key", "")).is_empty()
	if str(config.get("api_key", "")).is_empty():
		status_changed.emit("未配置 DeepSeek · 仅显示公开战况")
	else: status_changed.emit("知识档案已载入 · 等待公开开局")

func stop() -> void:
	active = false
	generation += 1
	in_flight = false
	pending.clear()
	config.clear()
	if client != null: client.cancel_pending_requests()
	client = null
	owner = null
	status_changed.emit("本局解说已关闭")

func offer(packet: Dictionary) -> void:
	if not active: return
	stable = true
	latest_id = int(packet.snapshot_id)
	# Latest-state queue with bounded causal history; never queue stale network jobs.
	if not pending.is_empty():
		var merged: Array = pending.events.duplicate(true)
		var ids := {}
		for e: Dictionary in merged: ids[e.id] = true
		for e: Dictionary in packet.events:
			if not ids.has(e.id): merged.append(e)
		packet = packet.duplicate(true)
		packet.events = merged.slice(-64)
		packet.before = pending.before.duplicate(true)
	pending = packet.duplicate(true)
	_local_line(packet.state)

func mark_unsettled() -> void:
	# Invalidate immediately, before a new action's choices/animation settle.
	# A result for the previous stable board must never become a live subtitle.
	stable = false
	latest_id = -1

func _local_line(state: Dictionary) -> void:
	var text := "第 %d 回合 · 玩家 %d 行动。双方剩余奖赏：%d / %d。" % [state.turn, int(state.current) + 1, state.players[0].prizes_remaining, state.players[1].prizes_remaining]
	if int(state.winner) in [0, 1]: text = "对局结束，玩家 %d 获胜。" % (int(state.winner) + 1)
	if last_text == text: return
	if history.is_empty() or int(state.winner) in [0, 1] or local_only: _publish(text, "公开战况")

func tick(now: float) -> void:
	if not active or not stable or in_flight or pending.is_empty() or now < next_request_at: return
	if str(config.get("api_key", "")).is_empty(): return
	if calls >= MAX_CALLS or charged_tokens >= MAX_TOKENS or failures >= 3:
		local_only = true
		_local_line(pending.state)
		status_changed.emit("本局额度已到" if failures < 3 else "服务暂不可用 · 仅显示公开战况")
		return
	var packet := pending.duplicate(true)
	var signature := Knowledge.signature(packet.knowledge)
	var mode := "commentary" if prepared_signature == signature and not plans.is_empty() else "prepare"
	var payload := Prompt.payload(packet, mode, plans, str(config.get("model", "deepseek-v4-flash")))
	# UTF-8 bytes upper-bound a token estimate. Reserve before dispatch; missing
	# provider usage (including timeout/cancel) never gets treated as free.
	var reserve := JSON.stringify(payload).to_utf8_buffer().size() + int(payload.max_tokens) + 256
	if reserve > 50000 or charged_tokens + reserve > MAX_TOKENS:
		local_only = true
		_local_line(pending.state)
		status_changed.emit("本局解说预算已到 · 仅显示公开战况")
		return
	in_flight = true
	calls += 1
	charged_tokens += reserve
	next_request_at = now + MIN_INTERVAL
	pending.clear()
	status_changed.emit("正在理解双方打法…" if mode == "prepare" else "正在解说 · %d/%d 次" % [calls, MAX_CALLS])
	var callback := _completed.bind(generation, packet, mode, signature, reserve)
	var error: int = client.request_json(owner, str(config.get("endpoint", "https://api.deepseek.com")), str(config.api_key), payload, callback)
	if error != OK: callback.call_deferred({"ok": false})

func _completed(response: Dictionary, request_generation: int, packet: Dictionary, mode: String, signature: String, reserve: int) -> void:
	if request_generation != generation or not active: return
	in_flight = false
	var usage := int(response.get("tokens", -1))
	if usage >= 0: charged_tokens = maxi(0, charged_tokens - reserve + usage)
	var content: Dictionary = response.get("content", {}) if response.get("content") is Dictionary else {}
	if not bool(response.get("ok", false)):
		failures += 1
		local_only = true
		if stable and latest_id == int(packet.snapshot_id) and pending.is_empty(): pending = packet
		status_changed.emit("服务暂不可用 · 继续对战")
		return
	if mode == "prepare":
		var current_signature := Knowledge.signature(pending.knowledge) if not pending.is_empty() else signature
		if current_signature != signature: return
		if not Prompt.valid_plans(content, int(packet.snapshot_id)):
			failures += 1
			status_changed.emit("打法分析未通过校验 · 稍后重试")
			return
		plans = content.plans.duplicate(true)
		prepared_signature = signature
		if stable and pending.is_empty() and latest_id == int(packet.snapshot_id): pending = packet
		status_changed.emit("双方打法已分析 · 关注关键行动")
		failures = 0
		local_only = false
		return
	# Live board moved: do not describe an old attack as current action.
	if not stable or latest_id != int(packet.snapshot_id):
		status_changed.emit("跟随最新战况")
		return
	if not Prompt.valid_comment(content, packet):
		failures += 1
		status_changed.emit("本条解说未通过校验")
		return
	failures = 0
	local_only = false
	_publish(str(content.text).strip_edges(), "AI 解说")
	status_changed.emit("AI 解说 · %d/%d 次 · %d tokens（含估算）" % [calls, MAX_CALLS, charged_tokens])

func _publish(value: String, source: String) -> void:
	if value == last_text: return
	last_text = value
	history.append({"text": value, "source": source})
	if history.size() > 40: history.pop_front()
	line_ready.emit(value, source)
