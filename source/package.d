module rtree;

import rtree.box_extensions;
import std.range.primitives: isInputRange;
import std.traits: ReturnType;
debug import std.stdio;

class RTree(Node, bool isWritable)
{
    static assert(isInputRange!(typeof(Node.children)));

    package Node root;
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
    alias Payload = ReturnType!(Node.getPayload);

    static if(isWritable)
    void addObject(in Box boundary, Payload payload)
    {
        Node* leaf = new Node(boundary, payload);
        addLeafNode(leaf);
    }

    private auto addLeafNode(Node* leaf)
    {
        debug assert(leaf.isLeafNode);

        auto place = selectLeafPlace(leaf.boundary);

        debug(rtptrs) writeln("Add leaf ", leaf, " to node ", place);

        place.assignChild(leaf); // unconditional add a leaf
        correct(place); // correction of the tree
    }

    private Node* selectLeafPlace(in Box newItemBoundary)
    {
        Node* curr = &root;

        for(auto currDepth = 0; currDepth < depth; currDepth++)
        {
            debug assert( !curr.isLeafNode );

            // search for min area of child nodes
            float minArea = float.infinity; // FIXME: why float?
            Node* min;
            foreach(c; curr.children)
            {
                auto area = c.boundary.expand(newItemBoundary).volume();

                if( area < minArea )
                {
                    minArea = area;
                    min = c;
                }
            }

            curr = min;
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
            debug(rtptrs)
            {
                writeln("Correcting node ", node, " children.front.isLeafNode=", node.children.front.isLeafNode, " leafs_level=", leafs_level);
                stdout.flush();
            }

            debug assert(node.children.front.isLeafNode == leafs_level);

            if( (leafs_level && node.children.length > maxLeafChildren) // need split on leafs level?
                || (!leafs_level && node.children.length > maxChildren) ) // need split of node?
            {
                if(node.isRoot) // for root split it is need a new root node
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
                Box boundary = node.children.front.boundary;

                foreach(c; node.children) // FIXME: first iteration duplicates box initialization values
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
        assert( n.children.length >= 2 );
    }
    body
    {
        debug(rtptrs)
        {
            writeln( "Begin splitting node ", n, " by brute force" );
            stdout.flush();
        }

        size_t _children_num = n.children.length();

        struct Metrics
        {
            auto overlapping_perimeter = real.max; // TODO: why real?
            auto boundary_perimeter = real.max;
        }

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
            auto range = n.children.range();
            for(size_t bit_num = 0; bit_num < _children_num; bit_num++)
            {
                auto boundary = range.front.boundary;

                if(bitIsNull(i, bit_num))
                    circumscribe(b1, boundary);
                else
                    circumscribe(b2, boundary);

                range.popFront;
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

        Node* newNode = new Node;

        {
            // split node by places specified by the bits of key
            auto oldChildren = n.children;
            n.children.clear();

            auto range = oldChildren.range();

            for(auto i = 0; i < _children_num; i++)
            {
                auto c = range.front;

                if(bitIsNull(minMetricsKey, i))
                    n.assignChild(c);
                else
                    newNode.assignChild(c);

                range.popFront();
            }
        }

        debug(rtptrs)
        {
            writeln("Split node ", n, " isLeafNode=", n.isLeafNode," ", n.children, ", new ", newNode, " newNode.isLeafNode=", newNode.isLeafNode, " ", newNode.children);
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
            leafsNum += curr.children.length;
        }
        else
        {
            nodesNum += curr.children.length;

            foreach(c; curr.children)
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
            writeln("Node: ", from, " parent: ", from.parent, " children: ", from.children);

            foreach(c; from.children)
            {
                showBranch(c, depth+1);
            }
        }
    }

    Box boundary()
    {
        assert(root.children.length);

        return root.boundary;
    }

    Payload[] search(in Box boundary)
    {
        Node* r = &root;
        return search(boundary, r);
    }

    private Payload[] search(in Box boundary, Node* curr, size_t currDepth = 0)
    {
        Payload[] res;

        if( currDepth > depth )
        {
            debug assert(curr.isLeafNode);

            res ~= curr.getPayload;
        }
        else
        {
            debug assert(!curr.isLeafNode);

            foreach(c; curr.children)
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

private bool bitIsNull(T1, T2)(T1 number, T2 bitNumber) @trusted
{
    import core.bitop: bt;

    return bt(cast(size_t*) &number, bitNumber) == 0;
}
