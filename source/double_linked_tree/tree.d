module double_tree.tree;

unittest
{
	import double_tree.ram_node;

    {
		// simple test
		RAMTreeNode!(float, ubyte) root;

		auto n = root.addNode;
		auto leaf = n.addLeafNode(123);

		assert(leaf.leafPayload == 123);
		assert(n == leaf.parent);
		assert(&root == n.parent);
	}

	{
		// complex test
		alias TestType = float;

		alias Node = RAMTreeNode!(short, TestType);
		Node writable;

		size_t counter;
		Node curr;

		void recursive(Node* node, size_t currDepth = 0)
		{
			foreach(i; 0 .. 3)
			{
				if(currDepth < 2)
				{
					auto newNode = node.addNode;
					recursive(newNode, currDepth + 1);
				}
				else
				{
					node.addLeafNode(counter + currDepth/10);
					counter++;
				}
			}
		}

		recursive(&writable);

		debug(double_tree)
		{
			writable.showBranch(&writable);

			size_t nodes, deadEnds;
			writable.statistic(nodes, deadEnds);

			assert(nodes == 40);
			assert(deadEnds == 27);
		}
	}
}
