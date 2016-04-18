module rtree.ram_node;

struct RAMNode(Box, Payload) // TODO: add ability to store ptrs
{
    RAMNode* parent;
    private Box _boundary;
    static Payload[] _payloads; // TODO: replace by SList
    debug package bool isLeafNode = false;

    this(this){}

    union
    {
        RAMNode*[] _children_;
        size_t payloadId;
    }

    RAMNode*[] _children() // FIXME: temporary, remove it
    {
        return _children_;
    }

    void clearChildren()
    {
        _children_.length = 0;
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

        _children_ ~= child;
        child.parent = &this;
    }
}
