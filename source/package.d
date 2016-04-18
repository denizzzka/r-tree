module rtree;

import rtree.box_extensions;
import std.traits;
debug import std.stdio;

class RTree(Node, bool isWritable)
{
    private Node root;
    private ubyte depth = 0;

    static if(isWritable)
    {
        immutable size_t maxChildren;
        immutable size_t maxLeafChildren;

        this(size_t maxChildren, size_t maxLeafChildren)
        {
            assert( maxChildren >= 2 );
            assert( maxLeafChildren >= 1 );

            this.maxChildren = maxChildren;
            this.maxLeafChildren = maxLeafChildren;
        }
    }

    alias Box = ReturnType!(Node.boundary);
    alias Payload = PointerTarget!(ReturnType!(Node.getPayload));

    static if(isWritable)
    auto addObject(in Box boundary, Payload payload) @system
    {
        auto payloadId = Node.savePayload(payload);
        Node* leaf = new Node(boundary, payloadId);

        addLeafNode(leaf);

        return payloadId;
    }

    /// Useful for external payload storage
    static if(isWritable)
    PayloadPtr* addObject(PayloadPtr)(in Box boundary, PayloadPtr* payloadPtr) @system
    {
        Node* leaf = new Node(boundary, payloadPtr);

        addLeafNode(leaf);

        return payload;
    }

    private auto addLeafNode(Node* leaf) @system
    {
        debug assert(leaf.isLeafNode);

        auto place = selectLeafPlace(leaf.boundary);

        debug(rtptrs) writeln("Add leaf ", leaf, " to node ", place);

        place.assignChild(leaf); // unconditional add a leaf
        correct(place); // correction of the tree
    }

    private Node* selectLeafPlace(in Box newItemBoundary) @system
    {
        Node* curr = &root;

        for(auto currDepth = 0; currDepth < depth; currDepth++)
        {
            debug assert( !curr.isLeafNode );

            // search for min area of child nodes
            float minArea = float.infinity;
            size_t minKey;
            foreach(i, c; curr._children)
            {
                auto area = c.boundary.expand(newItemBoundary).volume();

                if( area < minArea )
                {
                    minArea = area;
                    minKey = i;
                }
            }

            curr = curr._children[minKey];
        }

        return curr;
    }

    private void correct(Node* fromDeepestNode) @system
    {
        auto node = fromDeepestNode;
        bool leafs_level = true;

        debug(rtptrs) writeln("Correcting from node ", fromDeepestNode);

        while(node)
        {
            debug(rtptrs) writeln("Correcting node ", node);

            debug assert(node.children.front.isLeafNode == leafs_level);

            if( (leafs_level && node._children.length > maxLeafChildren) // need split on leafs level?
                || (!leafs_level && node._children.length > maxChildren) ) // need split of node?
            {
                if(node.parent is null) // for root split it is need a new root node
                {
                    node = new Node;
                    *node = root;
                    root = Node.init;
                    root.assignChild(node);
                    depth++;

                    debug(rtptrs) writeln("Added new root ", root, ", depth (without leafs) now is: ", depth);
                }

                Node* n = splitNode(node);
                node.parent.assignChild(n);
            }
            else // just recalculate boundary
            {
                Box boundary = node._children[0].boundary;

                foreach( c; node._children[1..$] )
                    boundary = boundary.expand(c.boundary);

                node.boundary = boundary;
            }

            node = node.parent;
            leafs_level = false;
        }

        debug(rtptrs) writeln( "End of correction" );
    }

    /// Brute force method
    private Node* splitNode(Node* n)
    in
    {
        debug assert(!n.isLeafNode);
        assert( n._children.length >= 2 );
    }
    body
    {
        debug(rtptrs)
        {
            writeln( "Begin splitting node ", n, " by brute force" );
            stdout.flush();
        }

        size_t _children_num = n._children.length;

        struct Metrics
        {
            auto overlapping_perimeter = real.max; // TODO: why real?
            auto boundary_perimeter = real.max;
        }

        import core.bitop: bt;
        alias BinKey = ulong;
        Metrics metrics;
        BinKey minMetricsKey;

        // loop through all combinations of nodes (combinatorial method)
        auto capacity = num2bits!BinKey(_children_num);
        for(BinKey i = 1; i < (capacity + 1) / 2; i++)
        {
            import std.typecons: Nullable;
            import rtree.box_extensions;

            Nullable!Box b1;
            Nullable!Box b2;

            static void circumscribe(ref Nullable!Box box, inout Box add) pure
            {
                if( box.isNull )
                    box = add;
                else
                    box = box.expand(add);
            }

            // division into two unique combinations of child nodes
            for(size_t bit_num = 0; bit_num < _children_num; bit_num++)
            {
                auto boundary = n._children[bit_num].boundary;

                if(bt(cast( size_t* ) &i, bit_num) == 0)
                    circumscribe(b1, boundary);
                else
                    circumscribe(b2, boundary);
            }

            // search for combination with minimum metrics
            Metrics m;

            if(b1.isOverlappedBy(b2))
                m.overlapping_perimeter = b1.intersection(b2).getPerimeter;
            else
                m.overlapping_perimeter = 0;

            if(metrics.overlapping_perimeter)
            {
                if(m.overlapping_perimeter < metrics.overlapping_perimeter)
                {
                    metrics = m;
                    minMetricsKey = i;
                }
            }
            else
            {
                m.boundary_perimeter = b1.getPerimeter + b2.getPerimeter;

                if( m.boundary_perimeter < metrics.boundary_perimeter )
                {
                    metrics = m;
                    minMetricsKey = i;
                }
            }
        }

        // split node by places specified by the bits of key
        auto oldChildren = n._children.dup;
        n.children.clear();

        Node* newNode = new Node;

        for(auto i = 0; i < _children_num; i++)
        {
            auto c = oldChildren[i];

            if(bt(cast(size_t*) &minMetricsKey, i) == 0)
                n.assignChild(c);
            else
                newNode.assignChild(c);
        }

        debug(rtptrs)
        {
            writeln("Split node ", n, " ", n._children, ", new ", newNode, " ", newNode._children);
            stdout.flush();
        }

        return newNode;
    }

    void statistic(
        ref size_t nodesNum,
        ref size_t leafsNum,
        ref size_t leafBlocksNum,
        Node* curr = null,
        size_t currDepth = 0
    ) pure
    {
        if(!curr)
        {
            curr = &root;
            nodesNum = 1;
        }

        if(currDepth == depth)
        {
            leafBlocksNum++;
            leafsNum += curr._children.length;
        }
        else
        {
            nodesNum += curr._children.length;

            foreach(c; curr._children)
                statistic( nodesNum, leafsNum, leafBlocksNum, c, currDepth+1 );
        }
    }

    debug void showBranch(Node* from, uint depth = 0)
    {
        writeln("Depth: ", depth);

        if(depth > this.depth)
        {
            writeln("Leaf: ", from, " parent: ", from.parent, " value: ", from.getPayload);
        }
        else
        {
            writeln("Node: ", from, " parent: ", from.parent, " _children: ", from._children);

            foreach(c; from._children)
            {
                showBranch(c, depth+1);
            }
        }
    }

    Box boundary()
    {
        assert(root._children.length);

        return root.boundary;
    }

    Payload*[] search(in Box boundary)
    {
        Node* r = &root;
        return search(boundary, r);
    }

    private Payload*[] search(in Box boundary, Node* curr, size_t currDepth = 0)
    {
        Payload*[] res;

        if( currDepth > depth )
        {
            debug assert(curr.isLeafNode);

            res ~= curr.getPayload;
        }
        else
        {
            debug assert(!curr.isLeafNode);

            foreach(i, c; curr._children)
                if(c.boundary.isOverlappedBy(boundary))
                    res ~= search(boundary, c, currDepth+1);
        }

        return res;
    }
}

/// converts number to number of bits
private T num2bits(T, N)(N n) pure @safe
{
    {
        auto max_n = n + 1;
        auto bytes_used = max_n / 8;

        if(max_n % 8 > 0)
            bytes_used++;

        import std.exception: enforce;

        enforce(bytes_used <= T.sizeof);
    }

    T res;

    for(N i = 0; i < n; i++)
        res = cast(T) (res << 1 | 1);

    return res;
}
unittest
{
    assert(num2bits!ubyte( 3 ) == 0b_0000_0111);
}

unittest
{
    import rtree.ram_node;
    import gfm.math.box;

    alias TestType = float;
    alias BBox = Box!(TestType, 2);

    alias Node = RAMNode!(BBox, TestType);

    auto writable = new RTree!(Node, true)(2, 2);

    for(TestType y = 1; y < 4; y++)
    {
        for(TestType x = 1; x < 4; x++)
        {
            auto boundary = BBox(x, y, x+1, y+1);
            writable.addObject(boundary, cast(ubyte) (10 * x + y) /*payload*/);
        }
    }

    debug(rtree) writable.showBranch(&writable.root);

    size_t nodes, leafs, leafBlocksNum;
    writable.statistic(nodes, leafs, leafBlocksNum);

    assert(leafs == 9);
    // assert(nodes == 13);
    assert(leafBlocksNum == 6);

    assert(writable.root.boundary == BBox(1, 1, 4, 4));

    auto search1 = BBox(2, 2, 3, 3);
    auto search2 = BBox(2.1, 2.1, 2.9, 2.9);

    assert(writable.search( search1 ).length == 9);
    assert(writable.search( search2 ).length == 1);
}
