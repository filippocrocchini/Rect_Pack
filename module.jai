
#scope_export

Rect :: struct
{
    x, y: int;
    w, h: int;
}

Heuristic :: enum 
{
	BEST_SHORT_SIDE_FIT :: 0;
	BEST_AREA_FIT       :: 1;
	BOTTOM_LEFT         :: 2;
	CUSTOM              :: 3;
}

Strategy :: enum
{
	GUILLOTINE           :: 0;
	GUILLOTINE_SLAB_SIZE :: 1;
	SLAB                 :: 2;
}

Node :: struct 
{
	#as rect : Rect;
	
	used   :  bool;
	parent : *Node;
	first  : *Node;
	second : *Node;
};

Rect_Packer :: struct
{
    My_Bucket_Array :: Bucket_Array(Node, 16);
    
	nodes : My_Bucket_Array;
	root  : *Node; // Unused
	
	max_width  : int;
	max_height : int;
	
	split_strategy   : Strategy;
	heuristic        : Heuristic;
	
	custom_heuristic : Heuristic_Callback = null;
	user_data        : *void              = null;
};

Heuristic_Callback :: #type (user_data: *void, node: *Node, width: int, height: int) -> int;

rect_packer_init :: (
	packer     : *Rect_Packer,
	max_width  : int,
	max_height : int,
	split_strategy : Strategy,
	heuristic      : Heuristic,
	custom_heuristic : Heuristic_Callback = null,
	user_data : *void = null)
{
	packer.max_width        = max_width;
	packer.max_height       = max_height;
	packer.split_strategy   = split_strategy;
	packer.heuristic        = heuristic;
	packer.custom_heuristic = custom_heuristic;
	packer.user_data        = user_data;

	_, packer.root = bucket_array_add(*packer.nodes, .{ Rect.{0, 0, max_width, max_height}, false, null, null, null });
}
	
rect_packer_reset :: (packer : *Rect_Packer)
{
    bucket_array_reset(*packer.nodes);
}

rect_packer_add :: (packer: *Rect_Packer, width: int, height: int) -> *Rect
{
    best_node := find_best_match(packer, width, height);

	if (!best_node)
	{
		return null; // Size too big.
	}

	result := insert(packer, best_node, width, height);

	return result;
}

rect_packer_remove :: (packer: *Rect_Packer, rect: *Rect) -> parent: *Rect
{
	node := cast(*Node) rect;

	if (!node) return null;
	
	node.used = false;
	assert(!node.first && !node.second, "You can only evict a leaf.");

	// Merge with siblings
	while true
	{
		assert(!node.used, "We should never be looking at a node that isn't empty.");

		parent := node.parent;
		
		if !parent // We are the root and already empty.
		{
			break;
		}

		if !parent.first.used && !parent.second.used // This should always be true
		{
			merge_children_and_free(packer, parent);
		}

		if !parent.used
		{
			node = parent;
		}
		else break;
	}

	assert(!node.used && !node.first && !node.second, "Best must be free now.");

	return node;
}

#scope_module

split_left_absolute :: (rect: Rect, amount: int) -> left: Rect, right: Rect
{
    left:  Rect;
    right: Rect;
    
    left.x = rect.x;
    left.y = rect.y;
    left.w = amount;
    left.h = rect.h;

    right.x = rect.x + amount;
    right.y = rect.y;
    right.w = rect.w - amount;
    right.h = rect.h;
    
    return left, right;
}

split_bottom_absolute :: (rect: Rect, amount: int) -> top: Rect, bottom: Rect
{
    top:    Rect;
    bottom: Rect;

    bottom.x = rect.x;
    bottom.y = rect.y;
    bottom.h = amount;
    bottom.w = rect.w;

    top.x = rect.x;
    top.y = rect.y + amount;
    top.w = rect.w;
    top.h = rect.h - amount;

    return top, bottom;
}

next_power_of_two :: (n: u64) -> u64 
{
	n = n - 1;
	n = n | (n >> 1);
	n = n | (n >> 2);
	n = n | (n >> 4);
	n = n | (n >> 8);
	n = n | (n >> 16);
	n = n | (n >> 32);
	return n + 1;
}

insert :: (packer: *Rect_Packer, parent: *Node, width: int, height: int) -> *Node
{
	assert(!parent.used && !parent.first && !parent.second, "Parent must be free.");
	if width == 0 || height == 0 return null;

	if (packer.split_strategy == .SLAB) // parent->rect.w > packer.max_size.x / 32 || parent->rect.h > packer.max_size.x / 32)
	{
		curr_parent := parent;
		split       := true;
		
		while split
		{
			first  := Rect.{};
			second := Rect.{};
	
			split = false;

			if curr_parent.rect.w > curr_parent.rect.h
			{
				if /*curr_parent->rect.w > 16 && */curr_parent.rect.w >= 2 * width
				{
					split = true;
					first, second = split_left_absolute(curr_parent.rect, curr_parent.rect.w / 2);
				}
			} else { 
				if /*curr_parent->rect.h > 16 && */curr_parent.rect.h >= 2 * height
				{
					split = true;
					first, second = split_bottom_absolute(curr_parent.rect, curr_parent.rect.h / 2);
				}
			}
	
			if (split)
			{
				_, first_node  := bucket_array_add(*packer.nodes, .{ first,  false, null, null, null });
				_, second_node := bucket_array_add(*packer.nodes, .{ second, false, null, null, null });
	
				first_node .parent = curr_parent;
				second_node.parent = curr_parent;
	
				curr_parent.first  = first_node;
				curr_parent.second = second_node;
				curr_parent.used   = true;
	
				curr_parent = first_node;
			}
		}
	
		curr_parent.used = true;
	
		return curr_parent;
	} 
	else
	{
		if packer.split_strategy == .GUILLOTINE_SLAB_SIZE
		{
			width  = cast(int) next_power_of_two(cast(u64) width);
			height = cast(int) next_power_of_two(cast(u64) height);
			
			width  = min(width, parent.rect.w);
			height = min(height, parent.rect.h);
		}

		first  := Rect.{};
		second := Rect.{};
		third  := Rect.{};
		target := Rect.{};
	
		if (parent.rect.w - width > parent.rect.h - height)
		{
			first, second = split_left_absolute(parent.rect, width);
			third, target = split_bottom_absolute(first, height);
		} else {
			second, first = split_bottom_absolute(parent.rect, height);
			target, third = split_left_absolute(first, width);
		}
	
		_, result      := bucket_array_add(*packer.nodes, .{ target, true,  null, null, null });
		_, first_node  := bucket_array_add(*packer.nodes, .{ first,  true,  null, null, null });
		_, second_node := bucket_array_add(*packer.nodes, .{ second, false, null, null, null });
		_, third_node  := bucket_array_add(*packer.nodes, .{ third,  false, null, null, null });
	
		// BestNode -> First + Second
		// First    -> Third + Target
	
		parent.used        = true;
		parent.first       = first_node;
		parent.second      = second_node;
		first_node.parent  = parent;
		second_node.parent = parent;
	
		first_node.used   = true;
		first_node.first  = third_node;
		first_node.second = result;
		result.parent     = first_node;
		third_node.parent = first_node;
		
		return result;
	}
}

score_node :: (packer: *Rect_Packer, node: *Node, width: int, height: int) -> int
{
	score := -1;

	if #complete packer.heuristic ==
	{
		case .CUSTOM;
    		if packer.custom_heuristic
    		{
    			score = packer.custom_heuristic(packer.user_data, node, width, height);
    		}
    		#through;
		
		case .BEST_SHORT_SIDE_FIT;
			score = min(node.rect.w - width, node.rect.h - height);

		case .BEST_AREA_FIT;
			score = node.rect.w * node.rect.h;

		case .BOTTOM_LEFT;
			score = node.rect.y * packer.max_width + node.rect.x;
	}

	return score;
}

find_best_match :: (packer: *Rect_Packer, width: int, height: int) -> *Node
{
	best       : *Node = null;
	best_score := S64_MAX;

	for* node : packer.nodes
	{
		if node.used continue;
		if node.first || node.second continue;
		if node.rect.w < width || node.rect.h < height continue;

		// Free leaf.
		score := score_node(packer, node, width, height);

		if score < best_score
		{
			best       = node;
			best_score = score;
		}
	}

	assert(!best || (!best.used && !best.first && !best.second), "We bust be a free leaf.");
	
	return best;
}

merge_children_and_free :: (using packer: *Rect_Packer, node: *Node)
{
    guess_locator :: (bucket_array: *Rect_Packer.My_Bucket_Array, node: *Node) -> bool, Bucket_Locator
    {
        for bucket_array.all_buckets
        {
            index_in_bucket := (cast(*u8) node - cast(*u8) it.data.data) / size_of(Node);
            
            if index_in_bucket >= 0 && index_in_bucket < it.data.count
            {
                return true, .{ cast(u32) it_index, cast(s32) index_in_bucket };
            }
        }
        
        return false, .{};
    }
    

	if node.first
	{
        found, node_locator := guess_locator(*nodes, node.first);
        if !found return;

		assert(!node.first.used, "This node must have been removed already.");
		
		bucket_array_remove(*packer.nodes, node_locator);
		
		node.first = null;
	}

	if node.second
	{
        found, node_locator := guess_locator(*nodes, node.second);
        if !found return;

		assert(!node.second.used, "This node must have been removed already.");
		
		bucket_array_remove(*packer.nodes, node_locator);
		
		node.second = null;
	}

	node.used = false;
}

remove_and_merge_children :: (packer: *Rect_Packer, node: *Node)
{
	if !node return;

	remove_and_merge_children(packer, node.first);
	remove_and_merge_children(packer, node.second);

	merge_children_and_free(packer, node);
}

#import "Bucket_Array";
#import "Basic";
#import "Math";

