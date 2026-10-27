## 张三的交付与心情服务：一次落盘同时保存物品变更和剧情进度，失败时整体回滚。
class_name ZhangSanService
extends RefCounted

const MOOD_POOL: RelicPool = preload("res://resource/profile/zhang_san_mood_pool.tres")
const SUPPLIES: Dictionary = {"081": "冰箱", "002": "水桶", "106": "太阳能发电板"}


static func get_state() -> Dictionary:
	if ProfileManager.profile_data == null:
		return {}
	var raw: Variant = ProfileManager.profile_data.npc_service_state.get("zhang_san", {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


static func deliver_selected_supply() -> String:
	if not ProfileManager.has_completed_event(&"zhang_san_requested"):
		return "请先听完张三的设施请求。"
	var relic: Relic = ProfileManager.get_selected_warehouse_relic()
	var entry_id: String = ProfileManager.get_selected_warehouse_entry_id()
	if relic == null or not SUPPLIES.has(relic.id):
		return "请在大厅仓库中选定冰箱、水桶或太阳能发电板。"
	if ProfileManager.is_warehouse_entry_locked(entry_id):
		return "装备已锁定，请先由你手动解锁后再交付。"
	var state: Dictionary = get_state()
	var delivered: Array = state.get("delivered", [])
	if delivered.has(relic.id):
		return "这件设施已经交过了，不会重复消耗。"
	var snapshot: Dictionary = ProfileManager.profile_data.to_dictionary()
	if not _remove_selected_entry(entry_id):
		return "没有找到当前携带的仓库装备。"
	delivered.append(relic.id)
	state["delivered"] = delivered
	var event_id: StringName = &"zhang_san_facilities_ready" if delivered.size() == SUPPLIES.size() else &""
	if not _commit(snapshot, state, event_id):
		return "保存失败，交付已撤销，装备与进度均保留。"
	return "已交付%s（%d/3）。%s" % [relic.relic_name, delivered.size(), "设施齐备，收获心情已解锁！" if delivered.size() == 3 else "其余设施可分次交付。"]


static func _remove_selected_entry(entry_id: String) -> bool:
	var entries: Array[Dictionary] = ProfileManager.profile_data.relic_warehouse_entries
	for index in range(entries.size()):
		if str(entries[index].get("entry_id", "")) == entry_id:
			entries.remove_at(index)
			ProfileManager.profile_data.selected_warehouse_entry_id = ""
			return true
	return false


## 只由整局死亡/最终通关调用；中途返回大厅、续档与训练均不增加次数。
static func record_finished_adventure() -> void:
	if not ProfileManager.has_completed_event(&"zhang_san_facilities_ready"):
		return
	var snapshot: Dictionary = ProfileManager.profile_data.to_dictionary()
	var state: Dictionary = get_state()
	state["pending_harvests"] = int(state.get("pending_harvests", 0)) + 1
	_commit(snapshot, state)


static func harvest_mood() -> String:
	if not ProfileManager.has_completed_event(&"zhang_san_mood_introduction"):
		return "请先听张三介绍收获心情。"
	var state: Dictionary = get_state()
	var pending: int = int(state.get("pending_harvests", 0))
	if pending <= 0:
		return "还没有新的心情。完成一局冒险后再来，无论胜败都可以。"
	if not ProfileManager.is_relic_warehouse_unlocked():
		return "请先与迷途记录员解锁装备仓库；收获机会会保留。"
	if ProfileManager.get_relic_warehouse_free_slots() <= 0:
		return "仓库已满，请先整理；这次收获机会会保留。"
	if MOOD_POOL.relics.is_empty():
		return "心情奖励池尚未配置，不消耗机会。"
	var template: Relic = MOOD_POOL.relics.pick_random() as Relic
	if template == null:
		return "心情奖励配置为空，不消耗机会。"
	var serialized: Dictionary = SaveManager.serialize_relic_for_profile(template.duplicate(true) as Relic)
	if serialized.is_empty():
		return "奖励无法保存，不消耗机会。"
	var snapshot: Dictionary = ProfileManager.profile_data.to_dictionary()
	var profile: ProfileData = ProfileManager.profile_data
	profile.relic_warehouse_entries.append({"entry_id": "warehouse_%d" % profile.next_warehouse_entry_index,
		"relic": serialized, "recovered_at": int(Time.get_unix_time_from_system()), "locked": false})
	profile.next_warehouse_entry_index += 1
	state["pending_harvests"] = pending - 1
	if not _commit(snapshot, state):
		return "保存失败，奖励与次数变更已撤销。"
	return "收获了%s，已放入仓库。剩余次数：%d。" % [template.relic_name, pending - 1]


static func get_progress_text() -> String:
	var state: Dictionary = get_state()
	var delivered: Array = state.get("delivered", [])
	var missing := PackedStringArray()
	for id: String in SUPPLIES:
		if not delivered.has(id):
			missing.append(str(SUPPLIES[id]))
	if not missing.is_empty():
		return "还缺：%s。每次从仓库选定一件携带，再来交付。" % "、".join(missing)
	return "待收获心情：%d 次。" % int(state.get("pending_harvests", 0))


static func _commit(snapshot: Dictionary, state: Dictionary, event_id: StringName = &"") -> bool:
	ProfileManager.profile_data.npc_service_state["zhang_san"] = state
	if not event_id.is_empty():
		ProfileManager.profile_data.record_event_completion(event_id)
	if not ProfileManager.save_profile():
		ProfileManager.profile_data.load_from_dictionary(snapshot)
		ProfileManager.warehouse_relic_cache.clear()
		return false
	ProfileManager.warehouse_relic_cache.clear()
	ProfileManager.relic_warehouse_changed.emit()
	if not event_id.is_empty():
		ProfileManager.profile_event_completed.emit(event_id, ProfileManager.get_event_data(event_id))
	return true
