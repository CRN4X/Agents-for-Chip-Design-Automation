# Linear Search Engine Specification Document

## **Introduction**
The **Linear Search Engine** is a parameterized, hierarchical RTL design that performs a **linear search** over a memory array to find all locations where a given key matches stored data. It supports **runtime memory writes**, **search control via a start/pause interface**, and outputs a **buffer of matched indices**, along with **match count** and **overflow detection**.

The design is organized into three main modules:
- `linear_search_top`: The top-level wrapper handling memory, interfaces, and submodule instantiation.
- `linear_search_ctrl`: An FSM-based controller that manages search initiation, pausing, and completion.
- `linear_search_datapath`: The logic responsible for iterating over memory and collecting match results.

---

## **Functional Overview**

### 1. **Search Operation**
- The module accepts a **key input** and performs a linear search over internal memory.
- If any memory entry matches the key, its **address index is recorded** into an internal buffer.
- Once the search completes, the output ports reflect the **total number of matches**, the **list of matched indices**, and whether an **overflow** occurred.

### 2. **Memory Interface**
- Internal memory supports **dual-port behavior**:
  - Port 1: Read-only, used by the datapath during search.
  - Port 2: Write-only, available externally when the search is **not enabled**.

### 3. **Control Logic**
- A **controller FSM** starts the search when `start` is asserted.
- The FSM supports **pausing/resuming** the search using the `pause` input.
- Once the search completes, a `done` signal is asserted.

---

## **Example Scenario**
### **Successful Search**

Memory Contents: [3, 5, 7, 5, 1] Key: 5

Result:

match_count = 2
match_indices = [1, 3]
done = 1
match_overflow = 0


### **Overflow Condition**

If more than MAX_MATCHES entries match the key:
Only first MAX_MATCHES indices are stored.
match_overflow = 1


---

## **Module Interface**

```verilog
module linear_search_top #(
  parameter DATA_WIDTH  = 8,
  parameter ADDR_WIDTH  = 4,
  parameter MEM_DEPTH   = 1 << ADDR_WIDTH,
  parameter MAX_MATCHES = 16
)(
  input  logic                         clk,
  input  logic                         srst,
  input  logic                         start,
  input  logic                         pause,
  input  logic [DATA_WIDTH-1:0]        key,

  input  logic                         mem_write_en,
  input  logic [ADDR_WIDTH-1:0]        mem_write_addr,
  input  logic [DATA_WIDTH-1:0]        mem_write_data,

  output logic                         done,
  output logic [$clog2(MAX_MATCHES+1)-1:0] match_count,
  output logic [(MAX_MATCHES*ADDR_WIDTH)-1:0] match_indices,
  output logic                         match_overflow
);
```
---

## **Module Parameters**

| **Parameter**     | **Type** | **Description**                                                                |
|-------------------|----------|--------------------------------------------------------------------------------|
| `DATA_WIDTH`      | Integer  | Width of each data element in memory.                                          |
| `ADDR_WIDTH`      | Integer  | Width of memory address.                                                       |
| `MEM_DEPTH`       | Integer  | Total number of memory entries. Derived from `ADDR_WIDTH`.                     |
| `MAX_MATCHES`     | Integer  | Maximum number of matched indices that can be stored in the result buffer.     |

---

## **Port Descriptions**

| **Signal**           | **Direction** | **Description**                                                                    |
|----------------------|---------------|------------------------------------------------------------------------------------|
| `clk`                | Input         | Clock signal. All logic operates on the rising edge.                               |
| `srst`               | Input         | Active-high synchronous reset. Resets internal states and outputs.                 |
| `start`              | Input         | Active-high for 1 clock cycle. Begins the search operation.                        |
| `pause`              | Input         | Active-high. Pauses the search when asserted; resumes on deassertion.              |
| `key`                | Input         | The value to be matched against each memory location.                              |
| `mem_write_en`       | Input         | Active-high. Enables memory write access. Only allowed when search is not running. |
| `mem_write_addr`     | Input         | Address to write into memory.                                                      |
| `mem_write_data`     | Input         | Data to be written into memory.                                                    |
| `done`               | Output        | Active-high. Asserted for one clock cycle after search completes.                  |
| `match_count`        | Output        | Number of memory addresses where the data matched the key.                         |
| `match_indices`      | Output        | Flat array of addresses where matches occurred. Width: `MAX_MATCHES * ADDR_WIDTH`. |
| `match_overflow`     | Output        | Active-high. Asserted if the number of matches exceeded `MAX_MATCHES`.             |

---

## **Design Hierarchy**

### `linear_search_top`
- Contains:
  - Local memory array (`memory`)
  - Write logic for external memory access
  - Instantiates:
    - `linear_search_ctrl`: FSM controller
    - `linear_search_datapath`: Match collection and address traversal logic

### `linear_search_ctrl`
- FSM States:
  | **State** | **Description**                          |
  |-----------|------------------------------------------|
  | `IDLE`    | Waiting for start                        |
  | `SEARCH`  | Actively iterating through memory        |
  | `PAUSED`  | Temporarily halts search on `pause`      |
  | `DONE`    | Signals completion, then returns to IDLE |

### `linear_search_datapath`
- Traverses memory addresses from `0` to `MEM_DEPTH - 1`
- Compares each data word with the `key`
- Stores matching addresses in `match_indices` if within buffer limit
- Flags overflow via `match_overflow` if matches exceed `MAX_MATCHES`
- Supports search **pause/resume** with internal state retention

---

## **Timing and Latency**

- The system is **synchronous**, with all operations occurring on the **rising clock edge**.
- `start` must be asserted **for one clock cycle** to initiate the search. It should only be asserted **after** external memory has been initialized with valid data.
- The search becomes **active** when `start` is asserted, and becomes **inactive** when `done` is asserted.
- `done` is asserted **2 clock cycles** after the final memory address is processed.
- `match_count`, `match_indices` and `match_overlow` are updated at search completion and are valid when `done` is asserted.
- External memory writes are allowed only when search is **not active**.
- **Memory Latency:**  
  - The internal memory has a **1-cycle read/write latency**. In read operation, When the datapath sets address, the corresponding read data becomes valid on the **next clock cycle**.


---

## **Edge Cases and Constraints**

- **Pause behavior:**  
  - When `pause` is asserted, the search operation halts on the next clock cycle. Internal counters and buffers retain their current values. The search resumes when `pause` is deasserted.

- **Match overflow:**  
  - If more than `MAX_MATCHES` entries match the key, only the first `MAX_MATCHES` addresses are recorded in `match_indices`. `match_overflow` is asserted alongside `done`.

- **Write protection:**  
  - Memory writes via `mem_write_en` are only valid **when search is inactive** (i.e., before `start` or after `done`). Writes during an active search are ignored to prevent data hazards.

- **Reset behavior:**  
  - Assertion of `srst` clears the FSM, resets internal buffers and counters, and reinitializes the design to a known state.