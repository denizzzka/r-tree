module rtree.box_extensions;

@safe:
pure:

bool isOverlappedBy(Box)(in Box b1, in Box b2)
{
    foreach(i; 0 .. Box.min.v.length)
    {
        if(b1.min.v[i] > b2.max.v[i]) return false;
        if(b1.max.v[i] < b2.min.v[i]) return false;
    }

    return true;
}

unittest
{
    import gfm.math.box;

    auto b1 = box2i(2, 2, 3, 3);
    auto b2 = box2i(3, 3, 4, 4);
    auto b3 = box2i(4, 4, 5, 5);

    assert(b1.isOverlappedBy(b2));
    assert(!b1.isOverlappedBy(b3));
}

auto getPerimeter(Box)(in Box b)
if(Box.min.v.length == 2)
{
    auto size = b.size();
    return (size.x + size.y) * 2;
}

unittest
{
    import gfm.math.box;

    auto b = box2i(2, 2, 5, 6);
    assert(b.getPerimeter == 14);
}
