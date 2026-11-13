class_name DrawOrder
extends RefCounted
## Test helper (art-pass "Draw order by foot position"): which of two canvas items Godot 4 draws
## later, that is on top. A headless run renders nothing to read back, so the order is read from
## the tree by the 2D renderer's rules (RendererCanvasCull::_cull_canvas_item and
## _collect_ysort_children; design.md K23):
## - the absolute z index decides first (z_index added up the ancestors while z_as_relative);
## - under a y-sorted node, its children, and the children of every y-sorted child below them, are
##   one list sorted by y in that node's space, ties in tree order; a node in that list that is not
##   y-sorted draws its whole subtree at its own place in it;
## - a y-sorted node's own drawing is in that list too, at its own origin and first among equal y,
##   so a child above that origin is drawn before its y-sorted parent (design.md K30);
## - elsewhere a node draws before its children, and children in tree order.
## Only CanvasItems of one canvas are compared: no CanvasLayer, top_level or show_behind_parent.

const Z_MIN: int = RenderingServer.CANVAS_ITEM_Z_MIN
const Z_MAX: int = RenderingServer.CANVAS_ITEM_Z_MAX


## The z index `item` draws at: its own, plus its parent's while it is relative.
static func absolute_z(item: CanvasItem) -> int:
	var z: int = 0
	var node: Node = item
	while node is CanvasItem:
		var canvas_item := node as CanvasItem
		z += canvas_item.z_index
		if not canvas_item.z_as_relative:
			break
		node = node.get_parent()
	return clampi(z, Z_MIN, Z_MAX)


## True when `a` is drawn after `b`, so over it where they overlap.
static func drawn_after(a: CanvasItem, b: CanvasItem) -> bool:
	var z_a: int = absolute_z(a)
	var z_b: int = absolute_z(b)
	if z_a != z_b:
		return z_a > z_b
	if a == b:
		return false
	if a.is_ancestor_of(b):
		return not drawn_after(b, a)
	if b.is_ancestor_of(a):
		return _drawn_after_ancestor(a, b)
	var common: Node = common_ancestor(a, b)
	var sorter := common as CanvasItem
	if sorter == null or not sorter.y_sort_enabled:
		return _later_in_tree(common, a, b)
	var entry_a: Node = sort_entry(sorter, a)
	var entry_b: Node = sort_entry(sorter, b)
	var y_a: float = y_in(sorter, entry_a)
	var y_b: float = y_in(sorter, entry_b)
	if not is_equal_approx(y_a, y_b):
		return y_a > y_b
	return _later_in_tree(common, entry_a, entry_b)


## `a` against its ancestor `b` at the same z. A plain `b` draws before its whole subtree. A
## y-sorted `b` draws itself inside the outermost y-sorted list that holds it, at its own origin and
## first among equal y (it is collected before its children), so a descendant whose entry in that
## list lies above `b`'s origin is drawn before it.
static func _drawn_after_ancestor(a: CanvasItem, b: CanvasItem) -> bool:
	if not b.y_sort_enabled:
		return true
	var sorter: CanvasItem = top_sorter(b)
	var y_a: float = y_in(sorter, sort_entry(sorter, a))
	var y_b: float = y_in(sorter, b)
	if is_equal_approx(y_a, y_b):
		return true
	return y_a > y_b


## The outermost y-sorted node whose list holds `item`'s own drawing: `item` itself, or the highest
## of its ancestors reached through y-sorted parents only.
static func top_sorter(item: CanvasItem) -> CanvasItem:
	var sorter: CanvasItem = item
	var parent := sorter.get_parent() as CanvasItem
	while parent != null and parent.y_sort_enabled:
		sorter = parent
		parent = sorter.get_parent() as CanvasItem
	return sorter


## The node that stands for `item` in `sorter`'s y-sorted list: the first node below `sorter` on the
## way down to `item` that is not y-sorted (it draws its subtree with it), else `item` itself.
static func sort_entry(sorter: CanvasItem, item: Node) -> Node:
	for node: Node in path_below(sorter, item):
		var canvas_item := node as CanvasItem
		if canvas_item == null or not canvas_item.y_sort_enabled:
			return node
	return item


## `node`'s y in `sorter`'s space, as the y-sorted list compares it.
static func y_in(sorter: CanvasItem, node: Node) -> float:
	var canvas_item := node as CanvasItem
	if canvas_item == null:
		return 0.0
	return (sorter.get_global_transform().affine_inverse() * canvas_item.get_global_transform()).origin.y


## The nodes from just below `ancestor` down to `node`, `node` last.
static func path_below(ancestor: Node, node: Node) -> Array[Node]:
	var path: Array[Node] = []
	var current: Node = node
	while current != null and current != ancestor:
		path.push_front(current)
		current = current.get_parent()
	return path


static func common_ancestor(a: Node, b: Node) -> Node:
	var current: Node = a
	while current != null:
		if current == b or current.is_ancestor_of(b):
			return current
		current = current.get_parent()
	return null


# Tree (preorder) order under `common`, for two nodes neither of which holds the other.
static func _later_in_tree(common: Node, a: Node, b: Node) -> bool:
	var path_a: Array[Node] = path_below(common, a)
	var path_b: Array[Node] = path_below(common, b)
	for i: int in mini(path_a.size(), path_b.size()):
		if path_a[i] != path_b[i]:
			return path_a[i].get_index() > path_b[i].get_index()
	return path_a.size() > path_b.size()
