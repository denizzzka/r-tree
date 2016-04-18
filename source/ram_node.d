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
        RAMNode*[] children;
        size_t payloadId;
    }

    static size_t savePayload(Payload payload)
    {
        _payloads ~= payload;

        return _payloads.length - 1; // TODO: replace by range
    }

    Payload* getPayload()
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

        if(children.length)
            _boundary = _boundary.expand(child._boundary);
        else
            _boundary = child._boundary;

        children ~= child;
        child.parent = &this;
    }
}
