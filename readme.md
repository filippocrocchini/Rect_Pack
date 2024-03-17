## Rect_Pack

This is a port of my own rect packer, definitely not idiomatic JAI.

### Usage

```jai
packer: Rect_Packer;

rect_packer_init(
    *packer,
    max_width  = 1024,
    max_height = 1024,
    split_strategy = .GUILLOTINE,
    heuristic      = .BEST_SHORT_SIDE_FIT);
```

Other possible values for split strategy are GUILLOTINE, GUILLOTINE_SLAB_SIZE, SLAB.
The supported heuristics are BEST_SHORT_SIDE_FIT, BEST_AREA_FIT, BOTTOM_LEFT or CUSTOM.

To supply a custom heuristic you can pass two additional parameters to rect_packer_init(): custom_heuristic and user_data.

The heuristic is intended to score a node as a possible candidate to contain a rectangle of size width*height, lower is better.

```jai
my_heuristic :: (user_data: *void, node: *Node, width: int, height: int) -> int
{
    // This is the implementation of BEST_SHORT_SIDE_FIT
    
    score := min(node.rect.w - width, node.rect.h - height);
    return score;
}

rect_packer_init(
    *packer,
    max_width  = 1024,
    max_height = 1024,
    split_strategy = .GUILLOTINE,
    heuristic      = .CUSTOM);
    custom_heuristic = my_heuristic,
    user_data = null
    );
    
```

After packing a new 32x15 rectangle, we get back a pointer to a rect.
The pointer is used to identify the rectangle so that it can also be removed, treat this the same way as you would treat malloc. 

```jai
rect := rect_packer_add(*packer, 32, 15);
```

As mentioned previously here's how you can remove a rectangle from the packing.

```jai
rect_packer_remove(*packer, rect);
```

Finally, if you want to fully reset the packer:

```jai
rect_packer_reset(*packer);
```
