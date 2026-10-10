extends RefCounted
## Kleine hulpfuncties.


## De wereld (hoofdscene) vinden, vanuit elke node.
static func world(node: Node) -> Node:
	return node.get_tree().get_first_node_in_group("world")


static func player(node: Node) -> Node2D:
	return node.get_tree().get_first_node_in_group("player")
