module double_tree.ram_node;

import std.container: SList;

struct RAMNode(Payload)
{
    private RAMNode* __parent;
    debug package bool isLeafNode = false;

    private union
    {
        Children __children;
        Payload __payload;
    }

    ref Payload payload() @property
    {
        debug assert(isLeafNode);

        return __payload;
    }

    ref Children children() @property
    {
        return __children;
    }

    struct Children
    {
        private SList!(RAMNode*) childrenStorage;

        void clear()
        {
            childrenStorage.clear;
        }

        Range opSlice()
        {
            return Range(&this);
        }

        alias opSlice this;

        struct Range
        {
            private typeof(childrenStorage).Range curr;
            alias curr this;

            private this(Children* c)
            {
                curr = c.childrenStorage.opSlice();
            }
        }

        debug string toString() const
        {
            import std.conv;

            return childrenStorage.to!string;
        }
    }

    RAMNode* parent()
    {
        return __parent;
    }

    void addPayloadNode(Payload payload)
    {
        debug assert(!isLeafNode);

        auto n = addNode();
        n.isLeafNode = true;
        n.payload = payload;
    }

    RAMNode* addNode()
    {
        debug assert(!isLeafNode);

        RAMNode* child = new RAMNode;
        child.__parent = &this;
        __children.childrenStorage.insert(child);

        return __children.childrenStorage.front();
    }
}
