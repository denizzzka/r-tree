module double_tree.tree;

unittest
{
	import double_tree.ram_node;

    {
		// simple test
		RAMNode!ubyte root;

		auto n = root.addNode;
		auto leaf = n.addPayloadNode(123);

		assert(leaf.payload == 123);
		assert(n == leaf.parent);
		assert(&root == n.parent);
	}

	{
		// complex test
		alias TestType = float;

		alias Node = RAMNode!TestType;
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
					node.addPayloadNode(counter + currDepth/10);
					counter++;
				}
			}
		}

		recursive(&writable);

		debug(double_tree) writable.showBranch(&writable);

		size_t nodes, leafs, leafBlocksNum;
		//~ writable.statistic(nodes, leafs, leafBlocksNum);

		//~ assert(leafs == 9);
		//~ // assert(nodes == 13);
		//~ assert(leafBlocksNum == 6);

		//~ assert(writable.root.boundary == BBox(1, 1, 4, 4));

		//~ auto search1 = BBox(2, 2, 3, 3);
		//~ auto search2 = BBox(2.1, 2.1, 2.9, 2.9);

		//~ assert(writable.search( search1 ).length == 9);
		//~ assert(writable.search( search2 ).length == 1);
	}
}
