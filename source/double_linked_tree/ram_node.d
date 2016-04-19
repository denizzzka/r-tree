module double_tree.ram_node;

import std.container: SList;
debug import std.stdio;

struct RAMTreeNode(NodePayload, LeafPayload)
{
    private RAMTreeNode* __parent;
    NodePayload nodePayload;
    debug package bool isDeadEndNode = false;

    private union
    {
        Children __children;
        LeafPayload __leafPayload;
    }

    ref LeafPayload leafPayload() @property
    {
        debug assert(isDeadEndNode);

        return __leafPayload;
    }

    ref Children children() @property
    {
        return __children;
    }

    struct Children
    {
        private SList!(RAMTreeNode*) childrenStorage;

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

    RAMTreeNode* parent()
    {
        return __parent;
    }

    RAMTreeNode* addLeafNode(NodePayload nodePayload, LeafPayload leafPayload) @property
    {
        debug assert(!isDeadEndNode);

        auto n = addNode(nodePayload);
        n.isDeadEndNode = true;
        n.__leafPayload = leafPayload;

        return n;
    }

    RAMTreeNode* addNode(NodePayload nodePayload) @property
    {
        debug assert(!isDeadEndNode);

        RAMTreeNode* child = new RAMTreeNode;
        child.__parent = &this;
        child.nodePayload = nodePayload;
        __children.childrenStorage.insert(child);

        return __children.childrenStorage.front();
    }

    debug static void showBranch(RAMTreeNode* from, size_t depth = 0)
    {
        write("Depth=", depth, " Node=", from, " parent=", from.parent, " ");

        if(from.isDeadEndNode)
        {
            writeln("payload=", from.leafPayload);
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

    debug void statistic(
        ref size_t nodesNum,
        ref size_t deadEndsNum,
        size_t currDepth = 0
    ) pure
    {
        RAMTreeNode.statistic(&this, nodesNum, deadEndsNum, currDepth);
    }

    debug static void statistic(
        RAMTreeNode* curr,
        ref size_t nodesNum,
        ref size_t deadEndsNum,
        size_t currDepth = 0
    ) pure
    {
        nodesNum++;

        if(curr.isDeadEndNode)
        {
            deadEndsNum++;
        }
        else
        {
            foreach(ref c; curr.children)
            {
                statistic(c, nodesNum, deadEndsNum, currDepth + 1);
            }
        }
    }
}
