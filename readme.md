## Rect_Pack

This is a port of my own rect packer, definitely not idiomatic JAI.

### Usage

```jai
    packer: Rect_Packer;
    
    rect_packer_init(
        *packer,
        max_width  = window_width,
        max_height = window_height,
        .GUILLOTINE,
        .BEST_SHORT_SIDE_FIT);
```

We can now pack a new 32x15 rectangle, we get back a pointer to a rect.
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
