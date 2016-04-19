module double_tree.ram_node;

import std.container: SList;

struct RAMNode(Payload, bool isWritable) //TODO: rename to havingLength?
{
    private RAMNode* _parent;
    debug package bool isLeafNode = false;

    private union
    {
        Children __children;
        Payload payload;
    }

    ref Children children() @property
    {
        return __children;
    }

    struct Children
    {
        private SList!(RAMNode*) childrenStorage;
        static if(isWritable) private size_t length;

        void clear()
        {
            childrenStorage.clear;
        }

        Range range()
        {
            return Range(&this);
        }

        alias range this;

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
        return _parent;
    }
}

unittest
{
    RAMNode!(ubyte, true) root;
}
