module rtree;

import std.traits;
debug import std.stdio;

class RTree(Node, bool writable)
{
    private Node root;
    private ubyte depth = 0;

    static if(writable)
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

    alias Box = ReturnType!(Node.getBoundary);

    auto addObject(Payload)(in Box boundary, Payload payload) @system
    {
        auto payloadId = Node.savePayload(payload);
        Node* leaf = new Node(boundary, payloadId);

        addLeafNode(leaf);

        return payloadId;
    }

    /// Useful for external payload storage
    Payload* addObject(Payload)(in Box boundary, Payload* payloadPtr) @system
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
            foreach(i, c; curr.children)
            {
                auto area = c.boundary.expand(newItemBoundary).volume();

                if( area < minArea )
                {
                    minArea = area;
                    minKey = i;
                }
            }

            curr = curr.children[minKey];
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

            debug assert(node.children[0].isLeafNode == leafs_level);

            if( (leafs_level && node.children.length > maxLeafChildren) // need split on leafs level?
                || (!leafs_level && node.children.length > maxChildren) ) // need split of node?
            {
                if( node.parent is null ) // for root split it is need a new root node
                {
                    Node* old_root = new Node;
                    //*old_root = root; // FIXME: !!!!
                    //root = Node.init;
                    root.assignChild(old_root);
                    depth++;

                    debug(rtptrs) writeln("Added new root ", root, ", depth (without leafs) now is: ", depth);
                }

                Node* n = splitNode( node );
                node.parent.assignChild( n );
            }
            else // just recalculate boundary
            {
                Box boundary = node.children[0].boundary;

                foreach( c; node.children[1..$] )
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

        size_t children_num = n.children.length;

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
        auto capacity = num2bits!BinKey(children_num);
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
            for(size_t bit_num = 0; bit_num < children_num; bit_num++)
            {
                auto boundary = n.children[bit_num].boundary;

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

        // split by places specified by bits of key
        auto oldChildren = n.children.dup;
        n.children.destroy;

        auto newNode = new Node;

        for(auto i = 0; i < children_num; i++)
        {
            auto c = oldChildren[i];

            if(bt(cast(size_t*) &minMetricsKey, i) == 0)
                n.assignChild(c);
            else
                newNode.assignChild(c);
        }

        debug(rtptrs)
        {
            writeln("Split node ", n, " ", n.children, ", new ", newNode, " ", newNode.children);
            stdout.flush();
        }

        return newNode;
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

@system struct RAMNode(Box, Payload) // TODO: add ability to store ptrs
{
    import rtree.box_extensions;

    private RAMNode* parent;
    private Box boundary;
    private static Payload[] payloads;
    debug private const bool isLeafNode = false;

    union
    {
        private RAMNode*[] children;
        size_t payloadId;
    }

    static size_t savePayload(Payload payload)
    {
        payloads ~= payload;

        return payloads.length - 1;
    }

    /// Leaf node
    this(in Box boundary, size_t payloadId)
    {
        this.boundary = boundary;
        this.payloadId = payloadId;
        isLeafNode = true;
    }

    Box getBoundary() const
    {
        return boundary;
    }

    void assignChild(RAMNode* child)
    {
        debug assert(!isLeafNode);

        if(children.length)
            boundary = boundary.expand(child.boundary);
        else
            boundary = child.boundary;

        children ~= child;
        child.parent = &this;
    }
}

unittest
{
    import gfm.math.box;

    alias Node = RAMNode!(box2i, ubyte);

    auto writable = new RTree!(Node, true)(2, 2);
}
