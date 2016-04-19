module double_tree.ram_node;

import std.container: SList;
debug import std.stdio;

struct RAMNode(Payload)
{
    private RAMNode* __parent;
    debug package bool isPayloadNode = false;

    private union
    {
        Children __children;
        Payload __payload;
    }

    ref Payload payload() @property
    {
        debug assert(isPayloadNode);

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

    RAMNode* addPayloadNode(Payload payload) @property
    {
        debug assert(!isPayloadNode);

        auto n = addNode();
        n.isPayloadNode = true;
        n.payload = payload;

        return n;
    }

    RAMNode* addNode() @property
    {
        debug assert(!isPayloadNode);

        RAMNode* child = new RAMNode;
        child.__parent = &this;
        __children.childrenStorage.insert(child);

        return __children.childrenStorage.front();
    }

    debug static void showBranch(RAMNode* from, size_t depth = 0)
    {
        write("Depth=", depth, " Node=", from, " parent=", from.parent, " ");

        if(from.isPayloadNode)
        {
            writeln("payload=", from.payload);
        }
        else
        {
            writeln("parent=", from.parent, " children=", from.children);

            foreach(ref c; from.children[])
            {
                showBranch(c, depth + 1);
            }
        }
    }

    //~ void statistic(
        //~ ref size_t nodesNum,
        //~ ref size_t leafsNum,
        //~ ref size_t leafBlocksNum,
        //~ Node* curr,
        //~ size_t currDepth = 0
    //~ ) pure
    //~ {
        //~ if(currDepth == depth)
        //~ {
            //~ leafBlocksNum++;
            //~ leafsNum += curr.children.length;
        //~ }
        //~ else
        //~ {
            //~ nodesNum += curr.children.length;

            //~ foreach(c; curr.children)
                //~ statistic( nodesNum, leafsNum, leafBlocksNum, c, currDepth+1 );
        //~ }
    //~ }
}
