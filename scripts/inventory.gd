extends RefCounted
## Helpers for slot arrays. A container is an Array where each slot is either
## null (empty) or {"id": String, "count": int}. Used for player inventories,
## furnaces, loot bags and corpses alike.
##
## Player inventory layout: slots 0-8 = hotbar, 9-35 = backpack,
## 36-39 = armor (head, chest, legs, feet), 40 = cape, 41 = ring, 42 = amulet.

const Items = preload("res://scripts/items.gd")

const HOTBAR_SIZE := 9
const PLAYER_SLOTS := 36
const ARMOR_START := 36
const PLAYER_SIZE := 43
const ARMOR_SLOTS := {36: "head", 37: "chest", 38: "legs", 39: "feet", 40: "back", 41: "ring", 42: "amulet"}
const CAPE_SLOT := 40
const RING_SLOT := 41
const AMULET_SLOT := 42


## The armor slot an item goes in, or -1.
static func armor_slot_for(id: String) -> int:
	var slot: String = Items.get_def(id).get("slot", "")
	for i in ARMOR_SLOTS:
		if ARMOR_SLOTS[i] == slot:
			return i
	return -1


## Can this item sit in this slot of a player inventory?
static func player_slot_accepts(index: int, id: String) -> bool:
	if index < ARMOR_START:
		return true
	return Items.get_def(id).get("slot", "") == ARMOR_SLOTS.get(index, "?")


## A slot's own data besides id and count (like which map it is and who made
## it). Items with data never stack, and the data goes wherever the item goes.
static func extra(s) -> Dictionary:
	var out := {}
	if s == null:
		return out
	for k in s:
		if k != "id" and k != "count":
			out[k] = s[k]
	return out


static func _new_slot(id: String, n: int, data: Dictionary) -> Dictionary:
	var s := {"id": id, "count": n}
	for k in data:
		s[k] = data[k]
	return s


## Can this item join an existing stack in slot s?
static func _joins(s, id: String, data: Dictionary, max_stack: int) -> bool:
	return s != null and s["id"] == id and s["count"] < max_stack and data.is_empty() and s.size() == 2


## Adds items into slots [from, to) only. Returns how many didn't fit.
static func add_range(inv: Array, id: String, count: int, from: int, to: int, data := {}) -> int:
	var max_stack := Items.max_stack(id)
	for pass_i in 2:
		for i in range(from, mini(to, inv.size())):
			if count <= 0:
				return 0
			var s = inv[i]
			if pass_i == 0 and _joins(s, id, data, max_stack):
				var n := mini(max_stack - s["count"], count)
				s["count"] += n
				count -= n
			elif pass_i == 1 and s == null:
				var n := mini(max_stack, count)
				inv[i] = _new_slot(id, n, data)
				count -= n
	return count


static func make(size: int) -> Array:
	var a := []
	a.resize(size)
	return a


## Adds items, filling existing stacks first. Returns how many did NOT fit.
## `limit` stops before that slot (so items never land in the armor slot).
## `data`: the slot's own data (see extra()), copied onto the new slot.
static func add(inv: Array, id: String, count: int, limit := -1, data := {}) -> int:
	var end := inv.size() if limit < 0 else mini(limit, inv.size())
	var max_stack := Items.max_stack(id)
	for i in end:
		if count <= 0:
			break
		var s = inv[i]
		if _joins(s, id, data, max_stack):
			var room: int = max_stack - s["count"]
			var n := mini(room, count)
			s["count"] += n
			count -= n
	for i in end:
		if count <= 0:
			break
		if inv[i] == null:
			var n := mini(max_stack, count)
			inv[i] = _new_slot(id, n, data)
			count -= n
	return count


## Adds a whole slot (keeping its data). Returns how many didn't fit.
static func add_slot(inv: Array, s: Dictionary, limit := -1) -> int:
	return add(inv, s["id"], s["count"], limit, extra(s))


static func can_fit(inv: Array, id: String, count: int, limit := -1) -> bool:
	return add(inv.duplicate(true), id, count, limit) == 0


static func count_of(inv: Array, id: String) -> int:
	var n := 0
	for s in inv:
		if s != null and s["id"] == id:
			n += s["count"]
	return n


## Removes up to `count` items (only from slots before `limit`, if given).
## Returns how many were removed.
static func remove(inv: Array, id: String, count: int, limit := -1) -> int:
	var removed := 0
	for i in (inv.size() if limit < 0 else mini(limit, inv.size())):
		if removed >= count:
			break
		var s = inv[i]
		if s != null and s["id"] == id:
			var n := mini(s["count"], count - removed)
			s["count"] -= n
			removed += n
			if s["count"] <= 0:
				inv[i] = null
	return removed


static func remove_from_slot(inv: Array, slot: int, count: int) -> void:
	var s = inv[slot]
	if s == null:
		return
	s["count"] -= count
	if s["count"] <= 0:
		inv[slot] = null


static func is_empty(inv: Array) -> bool:
	for s in inv:
		if s != null:
			return false
	return true


## Moves everything from `src` into `dst`. Returns true if `src` is now empty.
static func move_all(src: Array, dst: Array, dst_limit := -1) -> bool:
	for i in src.size():
		var s = src[i]
		if s == null:
			continue
		var left := add_slot(dst, s, dst_limit)
		if left == 0:
			src[i] = null
		else:
			s["count"] = left
	return is_empty(src)


## Stacks of the same item merge, otherwise the two slots swap.
static func swap_or_merge(a: Array, ia: int, b: Array, ib: int) -> void:
	var sa = a[ia]
	var sb = b[ib]
	if sa != null and sb != null and sa["id"] == sb["id"] and sa.size() == 2 and sb.size() == 2:
		var max_stack := Items.max_stack(sa["id"])
		var n := mini(max_stack - sb["count"], sa["count"])
		sb["count"] += n
		sa["count"] -= n
		if sa["count"] <= 0:
			a[ia] = null
		return
	a[ia] = sb
	b[ib] = sa
