module rtree;

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

    import gfm.math.box;
    alias Box = box2i;

    static if(isWritable)
    auto addObject(Payload)(in Box boundary, Payload payload) @system
    {
        size_t payloadId; // = Node.savePayload(payload);
        Node* leaf = new Node; //(boundary, payloadId);

        addLeafNode(leaf);

        return payloadId;
    }

    /// Useful for external payload storage
    static if(isWritable)
    Payload* addObject(Payload)(in Box boundary, Payload* payloadPtr) @system
    {
        Node* leaf = new Node(boundary, payloadPtr);

        addLeafNode(leaf);

        return payload;
    }

    private auto addLeafNode(Node* leaf) @system
    {
        auto bbb = box2i();
        auto place = selectLeafPlace(bbb);

        debug(rtptrs) writeln("Add leaf ", leaf, " to node ", place);

        correct(place); // correction of the tree
    }

    private Node* selectLeafPlace(in Box newItemBoundary) @system
    {
        Node* curr = &root;

        for(auto currDepth = 0; currDepth < depth; currDepth++)
        {
            float minArea = float.infinity;
            size_t minKey;
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
            {
                {
                    Node* old_root = new Node;
                    *old_root = root;
                    root = Node.init;
                    //~ root.assignChild(old_root);
                    depth++;
                    //assert(0);
                }
            }
        }

        debug(rtptrs) writeln( "End of correction" );
    }

    /// Brute force method
    private Node* splitNode(Node* n)
    {
        size_t children_num;// = n.children.length;

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
        //auto oldChildren = n.children.dup;
        //n.children.destroy;

        auto newNode = new Node;

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
    const bool isLeafNode = false;
}

unittest
{
    import gfm.math.box;

    alias NNode = RAMNode!(box2i, ubyte);

    auto writable = new RTree!(NNode, true)(2, 2);

    for(int y = 1; y < 4; y++)
    {
        for(int x = 1; x < 4; x++)
        {
            auto boundary = box2i(x, y, x+1, y+1);
            writable.addObject(boundary, cast(ubyte) (10 * x + y) /*payload*/);
        }
    }
}
