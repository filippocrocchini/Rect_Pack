Colored_Rect :: struct 
{
    #as using rect : *Rect_Pack.Rect;
    color : Vector4;
}

my_window: Window_Type;
window_width  : s32 = 1080;
window_height : s32 = 720;

packer : Rect_Pack.Rect_Packer;
rects  : [..] Colored_Rect;

clicked := false;

create_rect_packer :: () 
{
    Rect_Pack.rect_packer_init(
        *packer, 
        max_width  = window_width,
        max_height = window_height,
        .GUILLOTINE,
        .BEST_SHORT_SIDE_FIT
	);
}

add_random_rect :: () -> bool
{
    rect := Rect_Pack.rect_packer_add(*packer, cast(int) random_get_within_range(20, 100), cast(int) random_get_within_range(20, 100));
    
    if !rect then return false;
     
    r, g, b := hsv_to_rgb(random_get_zero_to_one() * 360, 0.4, 0.6);
    
	array_add(*rects, .{rect, Vector4.{r, g, b, 1}});
    
    return true;
}

main :: ()
{
    create_rect_packer();
    	
    for 0..20
    {
        if !add_random_rect() break;
    }
	
    // Visualization

    #if OS == .WINDOWS {
        Windows :: #import "Windows";
        Windows.SetProcessDPIAware();

        // Windows is very bad at thread-switching by default unless you do this. Sad.
        Windows.timeBeginPeriod(1);
    }

    my_window = create_window(window_width, window_height, "A Window");

    // Actual render size in pixels can be different from the window dimensions we specified above (for example on high-resolution displays on macOS/iOS).
    window_width, window_height = Simp.get_render_dimensions(my_window);

    Simp.set_render_target(my_window, .LEFT_HANDED);
        
    quit := false;
    while !quit {
        Input.update_window_events();

        for Input.get_window_resizes() {
            Simp.update_window(it.window);  // Simp will do nothing if it doesn't care about this window.
            
            if it.window == my_window
            {
                window_width  = it.width;
                window_height = it.height;
            }
        }

        clicked = false;

        for Input.events_this_frame {
            if it.type == .QUIT then quit = true;

            if it.type == {
              case .KEYBOARD;
                if it.key_pressed && it.key_code == .ESCAPE
                {
                    quit = true;
                }
                
                if it.key_pressed && it.key_code == .MOUSE_BUTTON_LEFT
                {
                    clicked = true;
                }

                if it.key_pressed && it.key_code == .SPACEBAR
                {
                    add_random_rect();
                }
            }
        }

        draw_one_frame();
        
        sleep_milliseconds(10);
        reset_temporary_storage();
    }
}

draw_one_frame :: ()
{
    Simp.clear_render_target(.08, .08, .08, 1);
    
    Simp.set_shader_for_color(true);

    mouse_x, mouse_y := get_mouse_pointer_position(my_window, false);
 
    for packer.nodes
    {
        min_corner := Vector2.{cast(float) it.rect.x, cast(float) it.rect.y};
        size       := Vector2.{cast(float) it.rect.w, cast(float) it.rect.h};
        
        p0 := min_corner + Vector2.{0, 0};
        p1 := min_corner + Vector2.{size.x, 0};
        p2 := min_corner + Vector2.{size.x, size.y};
        p3 := min_corner + Vector2.{0, size.y};

        r := 0.0;
        if it.used then r = 1;

        c0 := Vector4.{r, 1, 1, 0.1};
        c1 := Vector4.{r, 1, 1, 0.1};
        c2 := Vector4.{r, 1, 1, 0.1};
        c3 := Vector4.{r, 1, 1, 0.1};
        
        Simp.immediate_quad(p0, p1, p2, p3, c0, c1, c2, c3);
    }
        
    for rects
    {
        hovered := mouse_x > it.x && mouse_x < it.x + it.w && mouse_y > it.y && mouse_y < it.y + it.h;
    
        min_corner := Vector2.{cast(float) it.x, cast(float) it.y};
        size       := Vector2.{cast(float) it.w, cast(float) it.h};
        
        p0 := min_corner + Vector2.{0, 0};
        p1 := min_corner + Vector2.{size.x, 0};
        p2 := min_corner + Vector2.{size.x, size.y};
        p3 := min_corner + Vector2.{0, size.y};

        color := it.color;
        
        if hovered 
        {
            color = Vector4.{1, 1, 0, 1};
        }

        if hovered && clicked 
        {
            Rect_Pack.rect_packer_remove(*packer, it.rect);
            remove it;
        }

        Simp.immediate_quad(p0, p1, p2, p3, color, color, color, color);
    }

    Simp.swap_buffers(my_window);
}

fract :: inline (x: float) -> float { return x - floor(x); }

hsv_to_rgb :: (cx: float, cy: float, cz: float) -> (r: float, g: float, b: float) {
    cx /= 360.0;
    p: Vector3;
    p.x = abs(fract(cx + 1)     * 6 - 3) - 1;
    p.y = abs(fract(cx + 2/3.0) * 6 - 3) - 1;
    p.z = abs(fract(cx + 1/3.0) * 6 - 3) - 1;

    Clamp(*p.x, 0, 1);
    Clamp(*p.y, 0, 1);
    Clamp(*p.z, 0, 1);

    p.x = lerp(1, p.x, cy);
    p.y = lerp(1, p.y, cy);
    p.z = lerp(1, p.z, cy);

    return cz * p.x, cz * p.y, cz * p.z;
}

#import "Bucket_Array";
#import "Random";
Rect_Pack :: #import, file "../module.jai";

Simp  :: #import "Simp";
Input :: #import "Input";

#import "Window_Creation";

#import "Basic";
#import "Math";
#import "System";  // For get_path_of_running_executable. @Cleanup.
#import "String";  // For path_strip_filename. @Cleanup.

#run {
    #if OS == .WINDOWS {
        WR :: #import "Windows_Resources";
        WR.disable_runtime_console();
    }
}