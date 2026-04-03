## Specification

The BST is a structure formed where each node contains a key, with its `left_child` containing `keys` less than or equal to the node, and its `right_child` containing `keys` greater than the node. The key to be searched and deleted  (`delete_key`) is located based on its **position in the sorted array** (sorted such that the smallest element is at index 0 and the largest element is at index `ARRAY_SIZE`-1). The array is not sorted in this module. However, the BST is constructed in a way that traversing to the nodes results in a sorted array. The module doesn't wait for the complete BST to be traversed. As soon as the `delete_key` is found and its position is located, the module stops its search and transitions to the stage where the key is deleted based on the number of possible children (no, one, or two children). Furthermore, it is expected that the keys are not duplicated. 

---

### Invalid Key and Pointer Values
- **Invalid key value:** `(2^DATA_WIDTH) - 1`
- **Invalid pointer value for left_child and right_child:** `(2^(clog2(ARRAY_SIZE) + 1) - 1`

---

### Inputs:
- `[ARRAY_SIZE*DATA_WIDTH-1:0] keys`: A packed array containing the node values of the BST. 
- `[ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] left_child`: A packed array containing the left child pointers for each node in the BST.
- `[ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] right_child`: A packed array containing the right child pointers for each node in the BST.
- `[$clog2(ARRAY_SIZE):0] root`: The index of the root node (always 0 except for an empty BST, assuming the BST is constructed such that the first element in the arrays corresponds to the root node). For an empty BST, `root` is assigned an invalid index where all bits are set to 1; Eg, 15 (for ARRAY_SIZE = 7).
- `[DATA_WIDTH-1:0] delete_key`: The key to search and delete in the BST.
- `start`: 1-bit active high signal to initiate the search and deletion (1 clock cycle in duration).
- `clk`: Clock Signal. The design is synchronized to the positive edge of this clock.
- `reset`: Asynchronous active high reset to reset all control signal outputs to zero and `key_position`, `modified_keys`. `modified_left_child` and `modified_right_child` to null(invalid) values.

### Outputs
- `[$clog2(ARRAY_SIZE):0] key_position`: The position of the `delete_key` in the BST with respect to its sorted position. If the `delete_key` is not found in the constructed BST or if the tree is empty (indicated by all entries in `left_child`, `right_child` being null pointers, and all `keys` being zero) the module sets all the bits of `key_position` to 1 (null position). Value is also reset to null pointer 1 cycle after a deletion operation is completed.
- `complete_deletion`: 1-bit active high signal that is asserted once the deletion is complete, indicating that the key was found and deleted (1 clock cycle in duration). If the `delete_key` is not found in the constructed BST or if the tree is empty, `complete_deletion` remains at 0.
- `delete_invalid`: 1-bit Active high signal that is asserted when the BST is empty or when the `delete_key` doesn't exist in the given BST (1 clock cycle in duration). 
- `modified_keys`: Updated array of node keys after deletion. Each value in `modified_keys` gets reset to an invalid key value, 1 cycle after the deletion has been completed for a given BST and `delete_key`.
- `modified_left_child`: Updated array of left child pointers after deletion. Each value in `modified_left_child` gets reset to an invalid pointer value, 1 cycle after the deletion has been completed for a given BST and `delete_key`.
- `modified_right_child`: Updated array of right child pointers after deletion. Each value in `modified_right_child` gets reset to an invalid pointer value, 1 cycle after the deletion has been completed for a given BST and `delete_key`.

---

### Deletion Scenarios
1. **Node with Both Left and Right Children:**
   - Find the inorder successor (the leftmost node in the right subtree).
   - Replace the node's key with the in-order successor's key.
   - Delete the inorder successor node.

2. **Node with Only Left Child:**
   - Replace the node's key and pointers with those of its left child.
   - Mark the left child's original position as invalid.

3. **Node with Only Right Child:**
   - Replace the node's key and pointers with those of its right child.
   - Mark the right child's original position as invalid.

4. **Node with No Children:**
   - Mark the node's key and pointers as invalid.

---

### Implementation details 

**FSM (Finite State Machine) Design**:
The search and delete processes must be controlled by an FSM. 

- **S_IDLE**: The system resets intermediate variables and the outputs and waits for the `start` signal.
- **S_INIT**: The search begins by comparing the `delete_key` with the root node and decides the direction of traversal (left or right).
- **S_SEARCH_LEFT**: The FSM traverses the left subtree if the `delete_key` is less than the `root` node.
- **S_SEARCH_LEFT_RIGHT**: The FSM traverses both left and right subtrees if the `delete_key` is greater than the `root` node.
- **S_DELETE**:  The FSM deletes the key based on the number of children and different combinations. It traverses to `S_DELETE_COMPLETE` for completion. But when the `delete_key` has both the children, it traverses to `S_FIND_INORDER_SUCCESSOR` first.
-  **S_DELETE_COMPLETE**: The FSM outputs the signals `complete_deletion`, `key_position`, and  `delete_invalid` and the keys and pointer of the modified tree.
-  **S_FIND_INORDER_SUCCESSOR**: The FSM finds the in-order successor of the `delete_key`. It traverses to the right child and stays in the same state until it encounters a left child that has no key, and then traverses to `S_DELETE_COMPLETE`.

---

**Latency Analysis**:

- **Example 1**: The worst case scenario is for deleting the largest node in the right-skewed tree (every node only consists of a right_child and no left_child.). The design traverses to the left child of every node (which does not exist for a right-skewed tree) and then searches for its right child. The process is repeated for every node except the root node until the key of the node matches the `delete_key` to update the `key_position`. Since the largest node in the right-skewed tree is the last node without any child, this leads to a latency of (`ARRAY_SIZE` - 1) * 2. The updation of the `key_position` takes 1 additional clock cycle. Based on the information of the node determined, the deletion of the node in the `S_DELETE` state is performed which takes 1 clock cycle. Additionally, it takes 2 clock cycles in the **S_INIT** and **S_DELETE_COMPLETE** states and 1 clock cycle to transition from `S_IDLE` to `S_INIT` when `start` is asserted.
     - Total Latency = Start (`1`) + Initialization (`1`)  + Traversal (`(`ARRAY_SIZE` - 1) * 2`)  + Update `key_position` (`1`) +  Deletion (`1`)  + Completion (`1`)
     
- **Example 2**: If the `delete_key` matches the smallest node in the left skewed tree (every node only consists of a left_child and no right_child). The latency for all nodes except the root node to be traversed once until the depth of the left sub-tree (until the smallest key), is equal to `ARRAY_SIZE-1`. The process is then stopped and the `key_position` is updated for the smallest key which takes 1 additional clock cycle. Similar to other cases, it takes 3 clock cycles in the **S_INIT**, **S_DELETE** and **S_DELETE_COMPLETE** states and 1 clock cycle to transition from `S_IDLE` to `S_INIT`when start is asserted.
     - Total Latency = Start (`1`) + Initialization (`1`)  + Traversal (`ARRAY_SIZE - 1`) + Update `key_position` (`1`) +  Deletion (`1`)  + Completion (`1`)

- **Example 3**: To delete a node (15) in the given Binary Search Tree (BST) below that has both left and right children, consider the following example: 

  - **BST Structure**:  
      - `keys = [10, 5, 15, 3, 12, 20]`  
      - `left_child = [1, 3, 4, 15, 15, 15]`  
      - `right_child = [2, 15, 5, 15, 15, 15]`  

  - **Delete Operation**:  
      - The node to delete has the key `delete_key = 15`, which has a right child at index 6 (key = 20) and a left child at index 5 (key = 12).  

  - **Traversal Process**:  
      - Searching for the node with `key = 15` takes **4 clock cycles** to traverse to its left child and backtrack in this BST example. Additional 1 clock cycle to update the position of `delete_key = 15` and to set the `left_done` signal for the left subtree. To determine the position of the `delete_key` in the right subtree, the left subtree must be completely traversed, hence the search algorithm waits for the `left_done` to be set. After the `left_done` is set, it takes 1 clock cycle to transition to the `S_DELETE` state. In total, searching the node requires **6 clock cycles**. 

  - **Deletion Process**:  
      - Deleting the node involves finding its in-order successor (the leftmost node in the right subtree). This process takes **3 clock cycles**:  
          1. **1 clock cycle** to assign the right child of `delete_key` in the `S_DELETE` state.  
          2. **2 clock cycles** to traverse to the leftmost child of the right child of `delete_key` in the `S_FIND_INORDER_SUCCESSOR` state and replace the node with its in-order successor.  

  - **State Transitions**:  
       - Similar to other cases, the `S_INIT` and `S_DELETE_COMPLETE` states each take **2 clock cycles**.  
       - Additional 1 clock cycle to transition from `S_IDLE` to `S_INIT`when start is asserted
  
  - So total latency = Start (`1`) + Initialization (`1`) + Traversal (`6`) +  Deletion (`3`) + Completion (`1`)
 
---