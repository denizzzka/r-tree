module rtree.ram_node;

struct RAMNode(Box, Payload) // TODO: add ability to store ptrs
{
    private RAMNode* _parent;
    private Box _boundary;
    debug package bool isLeafNode = false;

    this(this){}

    private union
    {
        Children _children;
        Payload payload;
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

    ref Payload getPayload()
    {
        debug assert(isLeafNode);

        return payload;
    }

    /// Leaf node
    this(in Box boundary, Payload payload)
    {
        this._boundary = boundary;
        this.payload = payload;
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
