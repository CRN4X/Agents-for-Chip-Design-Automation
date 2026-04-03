import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import math 
import random
import math

def compute_invalid_key(data_width):
    """
    The invalid key is all ones in data_width bits, i.e., (2^data_width) - 1.
    Example: if data_width=6, invalid_key=63.
    """
    return (1 << data_width) - 1

def compute_invalid_pointer(array_size):
    """
    The invalid pointer for the left_child/right_child arrays.
    = 2^(ceil(log2(array_size)) + 1) - 1

    For example, if array_size=5 => ceil(log2(5))=3 => pointer=2^(3+1)-1=15.
    """
    if array_size <= 1:
        # degenerate case
        return 0
    exp = math.ceil(math.log2(array_size))
    return (1 << (exp + 1)) - 1

def find_node_and_parent(keys, left_child, right_child, root_index,
                         pointer_invalid, target_key):
    """
    Find the node that has key == target_key in the BST, along with its parent.
    Returns (node_index, parent_index) or (None, None) if not found.

    'root_index' is the index of the BST root (often 0 if valid).
    'pointer_invalid' indicates an invalid pointer (no child).
    """
    parent_idx = None
    current_idx = root_index
    
    while current_idx != pointer_invalid:
        current_key = keys[current_idx]
        if current_key == target_key:
            return (current_idx, parent_idx)
        elif target_key < current_key:
            parent_idx = current_idx
            current_idx = left_child[current_idx]
        else:
            parent_idx = current_idx
            current_idx = right_child[current_idx]
    
    return (None, None)  # not found

def find_leftmost_index(keys, left_child, right_child, start_index, pointer_invalid):
    """
    Find the index of the leftmost node in the subtree rooted at 'start_index'.
    i.e. 'inorder successor' if 'start_index' is the root of a right subtree.
    """
    current = start_index
    while left_child[current] != pointer_invalid:
        current = left_child[current]
    return current

def replace_parent_pointer(parent_idx, child_idx, new_idx,
                           left_child, right_child):
    """
    Helper to redirect parent_idx’s pointer (left or right) that was referencing child_idx
    to now reference new_idx instead.
    This is used to “bypass” or remove the child_idx from the tree structure.
    """
    if parent_idx is None:
        # No parent => the deleted node was the root.
        # We'll return special info so the caller knows how to fix the root
        return None, new_idx
    
    # If the parent's left pointer was the child_idx, update that
    if left_child[parent_idx] == child_idx:
        left_child[parent_idx] = new_idx
    # Else if the parent's right pointer was the child_idx, update that
    elif right_child[parent_idx] == child_idx:
        right_child[parent_idx] = new_idx
    
    return parent_idx, None  # No change to root; no new root

def delete_node_with_zero_or_one_child(node_idx, parent_idx,
                                       keys, left_child, right_child,
                                       pointer_invalid, key_invalid):
    """
    Handle the case where node_idx has 0 or 1 child.
    Returns (new_root_idx) if node_idx was the root and we replaced it,
    or None if the root is unchanged.
    """
    left_idx = left_child[node_idx]
    right_idx = right_child[node_idx]
    
    # Determine the single child (or none)
    if left_idx == pointer_invalid and right_idx == pointer_invalid:
        # No children (leaf)
        new_idx = pointer_invalid
    elif left_idx != pointer_invalid and right_idx == pointer_invalid:
        # Only left child
        new_idx = left_idx
    elif left_idx == pointer_invalid and right_idx != pointer_invalid:
        # Only right child
        new_idx = right_idx
    else:
        # This function should not be called if there are 2 children
        return None  # logic error if we get here
    
    # Replace parent's pointer from node_idx -> new_idx
    p, new_root = replace_parent_pointer(parent_idx, node_idx, new_idx,
                                         left_child, right_child)
    # Invalidate this node
    keys[node_idx] = key_invalid
    left_child[node_idx] = pointer_invalid
    right_child[node_idx] = pointer_invalid
    
    # If new_root is not None, that means the old node_idx was the root
    return new_root

def _delete_bst_key_inplace(keys, left_child, right_child, delete_key, data_width=6):
    """
    Internal helper that modifies the lists IN-PLACE. 
    Standard BST deletion algorithm:

      1. Find the node containing 'delete_key'.
      2. If not found => done.
      3. If found, apply BST deletion logic:
         - If node has 0 or 1 child => bypass it.
         - If node has 2 children => find the inorder successor from the right subtree,
           copy that key into the node, and then remove the successor using the
           0-or-1 child rule.

    This is the same logic as before, but it is *internal*, so we can do it in place
    after copying in the user-facing function.
    """
    n = len(keys)
    if n == 0:
        return  # Nothing to delete

    key_invalid = compute_invalid_key(data_width)       # e.g. 63
    pointer_invalid = compute_invalid_pointer(n)        # e.g. 15 for array_size=5

    # Assume the BST root is index=0 if valid
    root_index = 0
    if keys[root_index] == key_invalid:
        # Tree is effectively empty
        return

    # 1) Find the node to delete (node_idx) and its parent (parent_idx)
    node_idx, parent_idx = find_node_and_parent(keys, left_child, right_child,
                                                root_index, pointer_invalid, delete_key)
    if node_idx is None:
        return  # Key not found, do nothing

    left_idx = left_child[node_idx]
    right_idx = right_child[node_idx]
    has_left = (left_idx != pointer_invalid)
    has_right = (right_idx != pointer_invalid)

    # 2) If node has 0 or 1 child => remove or bypass it
    # -------------------- CASE 2: ONLY LEFT CHILD -----------------------
    if has_left and not has_right:
        # Copy the left child's data into node_idx
        keys[node_idx]       = keys[left_idx]
        left_child[node_idx] = left_child[left_idx]
        right_child[node_idx]= right_child[left_idx]
        
        # Now invalidate the old child's index
        keys[left_idx]          = key_invalid
        left_child[left_idx]    = pointer_invalid
        right_child[left_idx]   = pointer_invalid

    elif not has_left and has_right:
        # Copy the right child's data into node_idx
        keys[node_idx]       = keys[right_idx]
        left_child[node_idx] = left_child[right_idx]
        right_child[node_idx]= right_child[right_idx]
        
        # Now invalidate the old child's index
        keys[right_idx]          = key_invalid
        left_child[right_idx]    = pointer_invalid
        right_child[right_idx]   = pointer_invalid
       
    elif not has_left and not has_right:
        new_root = delete_node_with_zero_or_one_child(node_idx, parent_idx,
                                                      keys, left_child, right_child,
                                                      pointer_invalid, key_invalid)
        if new_root is not None:
            # If we actually replaced the root with a child or invalid,
            # just note that in case you want to track the new root. 
            pass
    else:
        # 3) Node has 2 children => find inorder successor in right subtree
        successor_idx = find_leftmost_index(keys, left_child, right_child,
                                            right_idx, pointer_invalid)
        successor_key = keys[successor_idx]

        # Overwrite the current node's key with the successor's key
        keys[node_idx] = successor_key

        # Now remove the successor node. The successor is guaranteed to have <=1 child.
        # We still need to find the successor's parent for that operation:

        if successor_idx == right_idx and left_child[successor_idx] == pointer_invalid:
            # The successor is the immediate right child, with no left child
            # => its parent is node_idx
            succ_parent = node_idx
        else:
            # Otherwise, find the successor's parent by searching in the right subtree
            # from node_idx:
            current = right_idx
            prev = node_idx
            while current != successor_idx:
                prev = current
                if keys[successor_idx] < keys[current]:
                    current = left_child[current]
                else:
                    current = right_child[current]
            succ_parent = prev

        delete_node_with_zero_or_one_child(successor_idx, succ_parent,
                                           keys, left_child, right_child,
                                           pointer_invalid, key_invalid)

def delete_bst_key(
    keys, left_child, right_child, delete_key, data_width=6
):
    """
    *USER-FACING FUNCTION* that behaves like call-by-value in other languages:
      - Makes copies of the input arrays.
      - Performs the BST deletion on those copies.
      - Returns the new copies (modified).
    
    The original arrays remain untouched.
    """
    # Copy the arrays locally (shallow copy is enough for lists of ints)
    new_keys = list(keys)
    new_left_child = list(left_child)
    new_right_child = list(right_child)

    # Perform the in-place BST deletion on these copies
    _delete_bst_key_inplace(new_keys, new_left_child, new_right_child,
                            delete_key, data_width)

    # Return the modified copies
    return new_keys, new_left_child, new_right_child


def generate_random_with_constraints(data_width, input_array):
    """
    Generate a random number within the range [0, 2^data_width - 1] 
    that is not present in input_array.
    """
    range_limit = (1 << data_width) - 1  # 2^data_width - 1
    input_set = set(input_array)  # Convert array to a set for fast lookups
    
    while True:
        random_number = random.randint(0, range_limit)
        if random_number not in input_set:
            return random_number

@cocotb.test()
async def test_search_bst(dut):
    """Cocotb testbench for the search_binary_search_tree module."""
    left_child = []
    right_child = []
    packed_left_child = 0
    packed_right_child = 0
    packed_keys = 0
    run = 0

    DATA_WIDTH = int(dut.DATA_WIDTH.value)
    ARRAY_SIZE = int(dut.ARRAY_SIZE.value)

    INVALID_KEY = (2**DATA_WIDTH) - 1
    INVALID_POINTER = 2**(math.ceil(math.log2(ARRAY_SIZE)) + 1) - 1

    invalid_key_list = []
    invalid_pointer_list = []

    # Initialize the clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset the DUT
    dut.reset.value = 1
    await Timer(20, units="ns")
    dut.reset.value = 0

    for i in range(4):
        await RisingEdge(dut.clk)

    for i in range(ARRAY_SIZE):
        invalid_key_list.append(INVALID_KEY)
        invalid_pointer_list.append(INVALID_POINTER)

    # Test Case 1: Empty tree
    dut.delete_key.value = 10  # Key to search
    dut.keys.value = 0; 

    for i in range(ARRAY_SIZE):
        left_child.append(2**(math.ceil(math.log2(ARRAY_SIZE)) + 1)-1)
        right_child.append(2**(math.ceil(math.log2(ARRAY_SIZE)) + 1)-1)

    for idx, val in enumerate(left_child):
        packed_left_child |= (val << (idx * (math.ceil(math.log2(ARRAY_SIZE)) + 1)))
    dut.left_child.value = packed_left_child
 

    for idx, val in enumerate(right_child):
        packed_right_child |= (val << (idx * (math.ceil(math.log2(ARRAY_SIZE)) + 1)))
    dut.right_child.value = packed_right_child

    dut.root.value = 2**(math.ceil(math.log2(ARRAY_SIZE)) + 1)-1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    #await RisingEdge(dut.search_invalid.value)

    cycle_count = 0
    while True:
        await RisingEdge(dut.clk)
        cycle_count += 1
        if dut.complete_deletion.value == 1 or dut.delete_invalid.value == 1:
            break

    print('delete_invalid', dut.delete_invalid.value)

    assert (dut.delete_invalid.value == 1) , "Failed: Tree is empty; delete_key should not be found, delete_invalid not set"

    for i in range(2):
        await RisingEdge(dut.clk)

    # Test Case 2: Non-empty BST
    if (ARRAY_SIZE == 10 and DATA_WIDTH == 16):
        keys = [58514, 50092, 48887, 48080, 5485, 5967, 19599, 23938, 34328, 42874]
        right_child = [31, 31, 31, 31, 5, 6, 7, 8, 9, 31]
        left_child = [1, 2, 3, 4, 31, 31, 31, 31, 31, 31]
        run = 1
        expected_latency_smallest = 9 
        expected_latency_largest = (ARRAY_SIZE - 1) * 2 + 2  + 3
    elif (ARRAY_SIZE == 15 and DATA_WIDTH == 6):
        keys = [9, 14, 15, 17, 19, 21, 30, 32, 35, 40, 46, 47, 48, 49, 50]
        left_child = [31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31]
        right_child = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 31]
        run = 1
        expected_latency_smallest = 4
        expected_latency_largest = (ARRAY_SIZE - 1) * 2 + 2 + 3
    elif (ARRAY_SIZE == 15 and DATA_WIDTH == 32):
        keys = [200706183, 259064287, 811616460, 956305578, 987713153, 1057458493, 1425113391, 1512400858, 2157180141, 2322902151, 2683058769, 2918411874, 2982472603, 3530595430, 3599316877]
        keys = sorted(keys, reverse=True)
        right_child = [31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31]
        left_child = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 31]
        run = 1
        expected_latency_smallest = (ARRAY_SIZE - 1) + 2 + 3
        expected_latency_largest = (ARRAY_SIZE - 1) * 2 + 2 + 3
    elif (ARRAY_SIZE == 5 and DATA_WIDTH == 6):
        keys = [1, 20, 0, 61, 5]
        left_child = [2,4,15,15,15]
        right_child = [1,3,15,15,15]
        run = 1
        expected_latency_smallest = 6 
        expected_latency_largest = (ARRAY_SIZE - 1)*2 + 3 

    
    if run == 1:
        print('keys', keys)
        print('left_child', left_child)
        print('right_child', right_child)

        print('----------------------------Test case 2: Random key-----------------------------------')
        dut.start.value = 1
        index = random.randint(1, ARRAY_SIZE-2)
        dut.delete_key.value = sorted(keys)[index]  # Random index
        packed_left_child = 0
        packed_right_child = 0
        
        for idx, val in enumerate(keys):
            packed_keys |= (val << (idx * DATA_WIDTH))
        
        dut.keys.value = packed_keys

        for idx, val in enumerate(left_child):
            packed_left_child |= (val << (idx * (math.ceil(math.log2(ARRAY_SIZE)) + 1)))
    
        dut.left_child.value = packed_left_child

        for idx, val in enumerate(right_child):
            packed_right_child |= (val << (idx * (math.ceil(math.log2(ARRAY_SIZE)) + 1)))
        dut.right_child.value = packed_right_child

    
        dut.root.value = 0
        await RisingEdge(dut.clk)
        dut.start.value = 0

        delete = dut.complete_deletion.value
        
        cycle_count = 0
        while True:
            await RisingEdge(dut.clk)
            cycle_count += 1
            if dut.complete_deletion.value == 1:
                break
        
        print('key_value ', dut.delete_key.value.to_unsigned())
        print('delete_invalid ', dut.delete_invalid.value)

        modified_keys = int(dut.modified_keys.value)
        modified_left = int(dut.modified_left_child.value)
        modified_right = int(dut.modified_right_child.value)

        actual_modified_keys = [ (modified_keys >> (i * DATA_WIDTH)) & ((1 << DATA_WIDTH) - 1) for i in range(ARRAY_SIZE)]
        actual_modified_left = [ (modified_left >> (i * (math.ceil(math.log2(ARRAY_SIZE))+1))) & ((1 <<  (math.ceil(math.log2(ARRAY_SIZE))+1)) - 1) for i in range(ARRAY_SIZE)]
        actual_modified_right = [ (modified_right >> (i * (math.ceil(math.log2(ARRAY_SIZE))+1))) & ((1 << (math.ceil(math.log2(ARRAY_SIZE))+1)) - 1) for i in range(ARRAY_SIZE)]
       
        key_bst, left_child_bst, right_child_bst = delete_bst_key(keys, left_child, right_child, dut.delete_key.value.to_unsigned(), DATA_WIDTH)
  
        print('expected keys', key_bst)
        print('expected left', left_child_bst)
        print('expected right', right_child_bst)

        print('actual keys', actual_modified_keys)
        print('actual left', actual_modified_left)
        print('actual right', actual_modified_right)

        assert ((key_bst == actual_modified_keys)), \
                f"Failed: Key {actual_modified_keys} should be modified as {key_bst}."
        assert ((left_child_bst == actual_modified_left)), \
                f"Failed: Key {actual_modified_left} should be modified as  {left_child_bst}."
        assert ((right_child_bst == actual_modified_right)), \
                f"Failed: Key {actual_modified_right} should be modified as {right_child_bst}."

        assert (dut.delete_invalid.value == 0) , "Failed: delete_invalid  set, but delete_key present"

        expected_position = reference_model(dut.delete_key.value, keys)
        assert dut.complete_deletion.value and dut.key_position.value.to_unsigned() == expected_position, \
            f"Failed: Largest key {dut.delete_key.value} should be at position {expected_position}."


        for i in range(2):
            await RisingEdge(dut.clk)

        #-------------------------------- Test Case 3: Key not in BST -----------------------------------------
        dut.start.value = 1

        print('---------------------------Test case 3: not in key-----------------------------------------')

        dut.delete_key.value = generate_random_with_constraints(DATA_WIDTH, keys)  # Key not in BST
       
        await RisingEdge(dut.clk)
        dut.start.value = 0

        cycle_count = 0
        while True:
            await RisingEdge(dut.clk)
            cycle_count += 1
            if dut.complete_deletion.value == 1 or dut.delete_invalid.value == 1:
                break
        
        print('key_value ', dut.delete_key.value.to_unsigned())
        print('delete_invalid ', dut.delete_invalid.value)

        modified_keys = int(dut.modified_keys.value)
        modified_left = int(dut.modified_left_child.value)
        modified_right = int(dut.modified_right_child.value)

        actual_modified_keys = [ (modified_keys >> (i * DATA_WIDTH)) & ((1 << DATA_WIDTH) - 1) for i in range(ARRAY_SIZE)]
        actual_modified_left = [ (modified_left >> (i * (math.ceil(math.log2(ARRAY_SIZE))+1))) & ((1 <<  (math.ceil(math.log2(ARRAY_SIZE))+1)) - 1) for i in range(ARRAY_SIZE)]
        actual_modified_right = [ (modified_right >> (i * (math.ceil(math.log2(ARRAY_SIZE))+1))) & ((1 << (math.ceil(math.log2(ARRAY_SIZE))+1)) - 1) for i in range(ARRAY_SIZE)]
    
        print('expected keys', key_bst)
        print('expected left', left_child_bst)
        print('expected right', right_child_bst)

        print('actual keys', actual_modified_keys)
        print('actual left', actual_modified_left)
        print('actual right', actual_modified_right)
    
        assert ((invalid_key_list == actual_modified_keys)), \
                f"Failed: Key {actual_modified_keys} should be modified as {invalid_key_list}."
        assert ((invalid_pointer_list == actual_modified_left)), \
                f"Failed: Key {actual_modified_left} should be modified as  {invalid_pointer_list}."
        assert ((invalid_pointer_list == actual_modified_right)), \
                f"Failed: Key {actual_modified_right} should be modified as {invalid_pointer_list}."
     
        assert (dut.delete_invalid.value == 1) , "Failed: delete_key should not be found, delete_invalid not set"

        for i in range(2):
            await RisingEdge(dut.clk)

        # Test Case 4: Smallest key in BST
        print('-------------------------------Test case 4: Smallest key-----------------------------')
        
        dut.start.value = 1
        dut.delete_key.value = sorted(keys)[0]  # Smallest key
       
        await RisingEdge(dut.clk)
        dut.start.value = 0

        cycle_count = 0
        while True:
            await RisingEdge(dut.clk)
            cycle_count += 1
            if dut.complete_deletion.value == 1:
                break

        
        print('key_value ', dut.delete_key.value.to_unsigned())
        print('delete_invalid ', dut.delete_invalid.value)

        modified_keys = int(dut.modified_keys.value)
        modified_left = int(dut.modified_left_child.value)
        modified_right = int(dut.modified_right_child.value)

        actual_modified_keys = [ (modified_keys >> (i * DATA_WIDTH)) & ((1 << DATA_WIDTH) - 1) for i in range(ARRAY_SIZE)]
        actual_modified_left = [ (modified_left >> (i * (math.ceil(math.log2(ARRAY_SIZE))+1))) & ((1 <<  (math.ceil(math.log2(ARRAY_SIZE))+1)) - 1) for i in range(ARRAY_SIZE)]
        actual_modified_right = [ (modified_right >> (i * (math.ceil(math.log2(ARRAY_SIZE))+1))) & ((1 << (math.ceil(math.log2(ARRAY_SIZE))+1)) - 1) for i in range(ARRAY_SIZE)]
    
        key_bst, left_child_bst, right_child_bst = delete_bst_key(keys, left_child, right_child, sorted(keys)[0] , DATA_WIDTH)

        print('expected keys', key_bst)
        print('expected left', left_child_bst)
        print('expected right', right_child_bst)

        print('actual keys', actual_modified_keys)
        print('actual left', actual_modified_left)
        print('actual right', actual_modified_right)

        assert ((key_bst == actual_modified_keys)), \
                f"Failed: Key {actual_modified_keys} should be modified as {key_bst}."
        assert ((left_child_bst == actual_modified_left)), \
                f"Failed: Key {actual_modified_left} should be modified as  {left_child_bst}."
        assert ((right_child_bst == actual_modified_right)), \
                f"Failed: Key {actual_modified_right} should be modified as {right_child_bst}."
        
        assert (dut.delete_invalid.value == 0) , "Failed: delete_invalid  set, but delete_key present"

        cocotb.log.debug(f"Total Latency : {cycle_count}, expected : {expected_latency_smallest}")
        assert expected_latency_smallest == cycle_count, f"Latency incorrect. Got: {cycle_count}, Expected: {expected_latency_smallest}"

        expected_position = reference_model(dut.delete_key.value.to_unsigned(), keys)
        assert dut.complete_deletion.value == 1 and dut.key_position.value.to_unsigned() == expected_position, \
            f"Failed: Smallest key {dut.delete_key.value} should be at position {expected_position}."

        for i in range(2):
            await RisingEdge(dut.clk)

        # Test Case 5: Largest key in BST
        print('---------------------------Test case 5: Largest key-----------------------------------------')
        
        dut.start.value = 1
        dut.delete_key.value = sorted(keys)[ARRAY_SIZE-1]  # Largest key
        
        await RisingEdge(dut.clk)
        dut.start.value = 0

        cycle_count = 0
        while True:
            await RisingEdge(dut.clk)
            cycle_count += 1
            if dut.complete_deletion.value == 1:
                break

        print('key_value ', dut.delete_key.value.to_unsigned())
        print('delete_invalid ', dut.delete_invalid.value)

        modified_keys = int(dut.modified_keys.value)
        modified_left = int(dut.modified_left_child.value)
        modified_right = int(dut.modified_right_child.value)

        actual_modified_keys = [ (modified_keys >> (i * DATA_WIDTH)) & ((1 << DATA_WIDTH) - 1) for i in range(ARRAY_SIZE)]
        actual_modified_left = [ (modified_left >> (i * (math.ceil(math.log2(ARRAY_SIZE))+1))) & ((1 <<  (math.ceil(math.log2(ARRAY_SIZE))+1)) - 1) for i in range(ARRAY_SIZE)]
        actual_modified_right = [ (modified_right >> (i * (math.ceil(math.log2(ARRAY_SIZE))+1))) & ((1 << (math.ceil(math.log2(ARRAY_SIZE))+1)) - 1) for i in range(ARRAY_SIZE)]
    
        key_bst, left_child_bst, right_child_bst = delete_bst_key(keys, left_child, right_child, sorted(keys)[ARRAY_SIZE-1], DATA_WIDTH)

        print('expected keys', key_bst)
        print('expected left', left_child_bst)
        print('expected right', right_child_bst)

        print('actual keys', actual_modified_keys)
        print('actual left', actual_modified_left)
        print('actual right', actual_modified_right)

        assert ((key_bst == actual_modified_keys)), \
                f"Failed: Key {actual_modified_keys} should be modified as {key_bst}."
        assert ((left_child_bst == actual_modified_left)), \
                f"Failed: Key {actual_modified_left} should be modified as  {left_child_bst}."
        assert ((right_child_bst == actual_modified_right)), \
                f"Failed: Key {actual_modified_right} should be modified as {right_child_bst}."
        
        assert (dut.delete_invalid.value == 0) , "Failed: delete_invalid  set, but delete_key present"
        
        cocotb.log.debug(f"Total Latency : {cycle_count}, expected : {expected_latency_largest}")
        assert expected_latency_largest == cycle_count, f"Latency incorrect. Got: {cycle_count}, Expected: {expected_latency_largest}"

        expected_position = reference_model(dut.delete_key.value, keys)
        assert dut.complete_deletion.value and dut.key_position.value.to_unsigned() == expected_position, \
            f"Failed: Largest key {dut.delete_key.value} should be at position {expected_position}."

        cocotb.log.info("---------------------------------All test cases passed!-------------------------------------")

# Reference model
def reference_model(delete_key, keys):
    """Sort the keys and find the position of the search key."""
    sorted_keys = sorted(keys)
    if delete_key in sorted_keys:
        return sorted_keys.index(delete_key)
    else:
        return -1
