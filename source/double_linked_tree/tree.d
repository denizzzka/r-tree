module double_tree.tree;

unittest
{
	import double_tree.ram_node;

    RAMNode!(ubyte) root;

    auto n = root.addNode;
    auto leaf = n.addPayloadNode(123);

    assert(leaf.payload == 123);
    assert(n == leaf.parent);
    assert(&root == n.parent);
}
