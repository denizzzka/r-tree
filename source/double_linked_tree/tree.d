module double_tree.tree;

//~ class DoubleLinkedTree(Node)
//~ {
	//~ private Node root;
//~ }

unittest
{
	import double_tree.ram_node;

    RAMNode!(ubyte) root;

    auto n = root.addNode;
    n.addPayloadNode(123);
}
