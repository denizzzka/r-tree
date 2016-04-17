module rtree.ram_node;

struct RAMNode(Box, Payload) // TODO: add ability to store ptrs
{
    private RAMNode* parent;
    private Box boundary;
    private static Payload[] payloads; // TODO: replace by SList
    debug package bool isLeafNode = false;

    this(this){}

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

    Payload* getPayload()
    {
        debug assert(isLeafNode);

        return &payloads[payloadId];
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
