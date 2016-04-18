module rtree.ram_node;

struct RAMNode(Box, Payload) // TODO: add ability to store ptrs
{
    RAMNode* parent;
    private Box _boundary;
    static Payload[] _payloads; // TODO: replace by SList
    debug package bool isLeafNode = false;

    this(this){}

    private union
    {
        Children _children_;
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
            Children* childrenStruct;
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

    ref Children children()
    {
        return _children_;
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

        if(_children_.length)
            _boundary = _boundary.expand(child._boundary);
        else
            _boundary = child._boundary;

        _children_.childrenStorage ~= child;
        child.parent = &this;
    }
}
