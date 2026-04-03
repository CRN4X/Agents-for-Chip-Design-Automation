import cocotb
from cocotb.triggers import RisingEdge, Timer
import math

# Reference model
def search_reference_model(search_key, keys):
    """Sort the keys and find the position of the search key."""
    sorted_keys = sorted(keys)
    if search_key in sorted_keys:
        return sorted_keys.index(search_key)
    else:
        return -1

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


