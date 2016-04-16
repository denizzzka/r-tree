module rtree;

import std.traits;
debug import std.stdio;

class RTree(Node, bool writable)
{
    private Node root;
    private ubyte depth = 0;

    static if(writable)
    {
        immutable size_t maxChildren;
        immutable size_t maxLeafChildren;

        this(size_t maxChildren, size_t maxLeafChildren)
        {
            assert( maxChildren >= 2 );
            assert( maxLeafChildren >= 1 );

            this.maxChildren = maxChildren;
            this.maxLeafChildren = maxLeafChildren;
        }
    }

    alias Box = ReturnType!(Node.getBoundary);

    auto addObject(Payload)(in Box boundary, Payload payload) @system
    {
        auto payloadId = Node.savePayload(payload);
        Node* leaf = new Node(boundary, payloadId);

        addLeafNode(leaf);

        return payloadId;        
    }

    /// Useful with external payload storage
    Payload* addObject(Payload)(in Box boundary, Payload* payloadPtr) @system
    {
        Node* leaf = new Node(boundary, payloadPtr);

        addLeafNode(leaf);

        return payload;        
    }

    private auto addLeafNode(Node* leaf) @system
    {
        debug assert(leaf.isLeafNode);

        auto place = selectLeafPlace(leaf.boundary);

        debug(rtptrs) writeln("Add leaf ", leaf, " to node ", place);     

        place.assignChild(leaf); // unconditional add a leaf
        correct(place); // correction of the tree
    }

    private Node* selectLeafPlace(in Box newItemBoundary) @system
    {
        Node* curr = &root;

        for(auto currDepth = 0; currDepth < depth; currDepth++)
        {
            debug assert( !curr.isLeafNode );
            
            // search for min area of child nodes
            float minArea = float.infinity;
            size_t minKey;
            foreach(i, c; curr.children)
            {
                auto area = c.boundary.expand(newItemBoundary).volume();
                
                if( area < minArea )
                {
                    minArea = area;
                    minKey = i;
                }
            }

            curr = curr.children[minKey];
        }

        return curr;
    }

    private void correct(Node* fromDeepestNode) @system
    {
        auto node = fromDeepestNode;
        bool leafs_level = true;

        debug(rtptrs) writeln("Correcting from node ", fromDeepestNode);

        while(node)
        {
            debug(rtptrs) writeln("Correcting node ", node);

            debug assert(node.children[0].isLeafNode == leafs_level);

            if( (leafs_level && node.children.length > maxLeafChildren) // need split on leafs level?
                || (!leafs_level && node.children.length > maxChildren) ) // need split of node?
            {
                if( node.parent is null ) // for root split it is need a new root node
                {
                    Node* old_root = new Node;
                    *old_root = root;
                    root = Node(Box());
                    root.assignChild(old_root);
                    depth++;

                    debug(rtptrs) writeln("Added new root ", root, ", depth (without leafs) now is: ", depth);
                }

                Node* n = splitNode( node );
                node.parent.assignChild( n );
            }
            else // just recalculate boundary
            {
                Box boundary = node.children[0].boundary;

                foreach( c; node.children[1..$] )
                    boundary.addCircumscribe( c.boundary );

                node.boundary = boundary;
            }

            node = node.parent;
            leafs_level = false;
        }

        debug(rtptrs) writeln( "End of correction" );
    }
}

@system struct RAMNode(Box, Payload) // TODO: add ability to store ptrs
{
    import rtree.box_extensions;

    private RAMNode* parent;
    private Box boundary;
    private static Payload[] payloads;
    debug private const bool isLeafNode = true;

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

    /// Leaf node
    this(in Box boundary, size_t payloadId)
    {
        this.boundary = boundary;
        this.payloadId = payloadId;
    }

    /// Empty node
    this(Box boundary)
    {
        this.boundary = boundary;
        isLeafNode = false;
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

unittest
{
    import gfm.math.box;

    alias Node = RAMNode!(box2i, ubyte);

    auto writable = new RTree!(Node, true)(2, 2);
}
