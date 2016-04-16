module rtree;

@safe:

class RTree(Node, bool writable)
{
    Node root;

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
}

struct RAMNode(Box)
{
    import rtree.box_extensions;

    private Node* parent;
    private Box boundary;
    debug const bool leafNode;

    union // TODO: is private?
    {
        Node*[] children;
        Payload* payload;
    }

    this(in Box boundary, in Payload* payload)
    {
        debug leafNode = true;

        this.boundary = boundary;
        this.payload = payload;
    }

    Box getBoundary() const
    {
        return boundary;
    }

    void assignChild(Node* child)
    {
        debug assert(!leafNode);

        if(children.length)
            boundary.expand(child.boundary);
        else
            boundary = child.boundary;

        children ~= child;
        child.parent = &this;
    }
}

unittest
{
    import gfm.math.box;

    auto writable = new RTree!(box2i, true)(2, 2);
}
