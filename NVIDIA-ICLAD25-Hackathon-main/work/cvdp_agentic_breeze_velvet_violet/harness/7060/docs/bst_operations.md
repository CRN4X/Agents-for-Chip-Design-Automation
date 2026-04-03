## Specification

A **Binary Search Tree (BST)** is a hierarchical data structure where:

- Each node contains a key.
- The left child contains keys less than the parent.
- The right child contains keys greater than the parent.

### Overview

The `bst_operations` module implements **core Binary Search Tree (BST) operations** in hardware. It supports:

- **Search**
- **Delete**
- **Optional sorting** of the BST post-operation

The module constructs a BST from an input array, performs the requested operation (`search` or `delete`), and outputs the resulting BST (and optionally its sorted version).

---

### Module Interface

#### Inputs

| Name                  | Width                                    | Description                                                             |
|-----------------------|------------------------------------------|-------------------------------------------------------------------------|
| `clk`                 | 1 bit                                    | Clock signal. The design is synchronized to the positive edge of this   |
| `reset`               | 1 bit                                    | Asynchronous active high reset                                          |
| `start`               | 1 bit                                    | Active high start signal to begin operation                             |
| `operation_key`       | `DATA_WIDTH`                             | Key to search or delete                                                 |
| `data_in`             | `ARRAY_SIZE × DATA_WIDTH`                | Flattened input array of node values                                    |
| `operation`           | 1 bit                                    | `0`: Search, `1`: Delete                                                |
| `sort_after_operation`| 1 bit                                    | `1`: Sort BST after operation, `0`: Skip sorting                        |

---

#### Outputs

| Name                  | Width                                                | Description                                                                                                                  |
|-----------------------|------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------|
| `key_position`        | `clog2(ARRAY_SIZE)+1`                                | Index of `operation_key` if found during search. For other operations, it is asserted as INVALID.                            |
| `complete_operation`  | 1 bit                                                | High when operation is successfully completed                                                                                |
| `operation_invalid`   | 1 bit                                                | High if the operation was invalid (e.g., key not found)                                                                      |
| `out_sorted_data`     | `(ARRAY_SIZE × DATA_WIDTH)`                          | Sorted BST output (if `sort_after_operation = 1`)                                                                            |
| `out_keys`            | `(ARRAY_SIZE × DATA_WIDTH)`                          | Updated node keys after operation                                                                                            |
| `out_left_child`      | `(ARRAY_SIZE × (clog2(ARRAY_SIZE)+1))`               | Updated left child indices                                                                                                   |
| `out_right_child`     | `(ARRAY_SIZE × (clog2(ARRAY_SIZE)+1))`               | Updated right child indices                                                                                                  |

---

#### Parameters:
- DATA_WIDTH (default 16): Width of a single element, greater than 0.
- ARRAY_SIZE (default 5): Number of elements in the array, will be greater than 0 

### Internal Components

#### Tree Construction

- `bst_tree_construct` constructs the BST from the input `data_in`. No duplicate keys are allowed. 
- Outputs keys, left and right child arrays, and root node.
- Signals the top module `bst_operations` on completion of tree construction.
- If the structure is invalid (any of the data in the input array is invalid), a control signal to flag that the operation is invalid is raised. This terminates all the ations and asserts the `operation_invalid` to 1. 

---

#### Search Operation

- Triggered when `operation == 0` and `start` is asserted.
- Uses `search_binary_search_tree` module.
- If `sort_after_operation == 1`, then sorting logic is also invoked.
- If the key is not found, `operation_invalid` is raised.

---

#### Delete Operation

- Triggered when `operation == 1`.
- Uses `delete_node_binary_search_tree`.
- Updates BST and optionally triggers sort if `sort_after_operation` is high.
- Handles cases where a node has:
  - No child
  - One child
  - Two children (uses in-order successor)

---

#### BST Sorting

- `binary_search_tree_sort` traverses the BST in order.
- Generates `out_sorted_data`.
- If sorting is disabled, `out_sorted_data` is filled with `INVALID_KEY`.

---

### Handling Invalid Keys & Pointers

| Signal              | Value                        | Purpose                                                                                                          |
|---------------------|------------------------------|------------------------------------------------------------------------------------------------------------------|
| `INVALID Key`       | All 1s in `DATA_WIDTH`       | Represents unused or removed keys                                                                                |
| `INVALID Pointer`   | All 1s in child pointer width| Represents NULL pointer in left/right child arrays                                                               |
| `operation_invalid` | 1                            | Raised when operation (search and delete) is not complete, BST structure is invalid, or when sorting is invalid  |
| `out_sorted_data`   | All 1s if invalid            | Filled with `INVALID_KEY` if sorting was skipped                                                                 |

### Successful Completion of Operation

The `bst_operations` module asserts the `complete_operation` signal only after all required processes are finished—specifically, the selected operation (search or delete)  if enabled, the sorting operation (`sort_after_operation` = 1). Since each submodule (search, delete, and sort) asserts its respective done signal for only one clock e, these signals must be latched internally to ensure accurate detection and confirmation of successful completion across multiple cycles.

### Latency Analysis

The total latency from asserting `start` to the `complete_operation` signal being set to `1` depends on the selected operation (**search** or **delete**) and whether sorting nabled using `sort_after_operation`.

It includes the cumulative clock cycles for:
- Constructing the BST,
- Performing the specified operation,
- Optional sorting of the resulting BST.

Each internal module asserts its respective done signal for 1 clock cycle, which is latched and used by the top-level module to trigger subsequent stages.

When sorting is **enabled**, the design requires:
- 1 additional clock cycle each for: construction complete, operation complete, and sort complete  
- **Total overhead = 3 clock cycles**

When sorting is **not enabled**, the design still incurs:
- 1 clock cycle each for construction complete and operation complete  
- +1 additional cycle to latch the `done` or `invalid` signal from the operation module  
- **Total overhead = 3 clock cycles**

This ensures control signal synchronization and consistent behavior regardless of sorting.