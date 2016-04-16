module rtree.box_extensions;

bool isOverlappedBy(Box)(in Box b1, in Box b2) pure
{
    auto ld1 = b1.min; // left down
    auto ld2 = b2.min;

    auto ru1 = b1.max; // right upper
    auto ru2 = b2.max;

    foreach(i; 0 .. b1.min.v.length)
    {
        if(b1.min.v[i] > b2.max.v[i]) return false;
        if(b1.max.v[i] < b2.min.v[i]) return false;
    }

    return true;
}

unittest
{
    import gfm.math.box;

    auto b1 = box2i(2, 2, 1, 1);
    auto b2 = box2i(3, 3, 1, 1);
    auto b3 = box2i(4, 4, 1, 1);

    assert(b1.isOverlappedBy(b2));
    assert(!b1.isOverlappedBy(b3));
}
