module rtree.ram_node;

struct RAMNode(Box, Payload) // TODO: add ability to store ptrs
{
    private RAMNode* _parent;
    private Box _boundary;
    private static Payload[] _payloads; // TODO: replace by SList
    debug package bool isLeafNode = false;

    version(unittest) package static size_t payloadsLength()
    {
        return _payloads.length;
    }

    this(this){}

    private union
    {
        Children _children;
        size_t payloadId;
    }

    struct Children
    {
        private RAMNode*[] childrenStorage; // TODO: replace by SList

        void opAssign(Children c)
        {
            childrenStorage = c.childrenStorage.dup;
        }

        void clear()
        {
            childrenStorage.length = 0;
        }

        Range range()
        {
            return Range(&this);
        }

        alias range this;

        struct Range
        {
            private Children* childrenStruct;
            private size_t curr;

            private this(Children* c)
            {
                childrenStruct = c;
            }

            auto front(){ return childrenStruct.childrenStorage[curr]; }
            void popFront(){ ++curr; }
            size_t length(){ return childrenStruct.childrenStorage.length; }
            bool empty(){ return curr >= childrenStruct.childrenStorage.length; }
        }

        debug string toString() const
        {
            import std.conv;

            return childrenStorage.to!string;
        }
    }

    ref Children children() @property
    {
        return _children;
    }

    bool isRoot() const
    {
        return _parent is null;
    }

    RAMNode* parent()
    {
        return _parent;
    }

    static size_t savePayload(Payload payload)
    {
        _payloads ~= payload;

        return _payloads.length - 1; // TODO: replace by range
    }

    Payload* getPayload() const
    {
        debug assert(isLeafNode);

        return &_payloads[payloadId];
    }

    /// Leaf node
    this(in Box boundary, size_t payloadId)
    {
        this._boundary = boundary;
        this.payloadId = payloadId;
        isLeafNode = true;
    }

    Box boundary() const
    {
        return _boundary;
    }

    void boundary(Box b)
    {
        _boundary = b;
    }

    void assignChild(RAMNode* child)
    {
        debug assert(!isLeafNode);

        if(_children.length)
            _boundary = _boundary.expand(child._boundary);
        else
            _boundary = child._boundary;

        _children.childrenStorage ~= child;
        child._parent = &this;
    }
}

unittest
{
    import rtree;
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
