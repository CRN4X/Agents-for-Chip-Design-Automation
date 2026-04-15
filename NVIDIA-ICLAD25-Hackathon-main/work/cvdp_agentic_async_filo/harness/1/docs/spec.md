# async_filo Module Specification

## 1. Overview

The `async_filo` (First-In-Last-Out) module is an **asynchronous stack** with separate write and read clock domains. It supports simultaneous push and pop operations from independent clock domains and maintains data integrity through synchronization of read/write pointers. The stack implements **Gray-coded pointers** for safe cross-clock-domain operations.

---

## 2. Features

- Asynchronous operation with independent read and write clocks
- Configurable `DATA_WIDTH` and `DEPTH`
- FIFO-style buffer with FILO access pattern
- Gray code synchronization of pointers across domains
- `w_full` and `r_empty` status flags
- Safe handling of full and empty conditions

---

## 3. Ports

| Name      | Direction | Width         | Description                                  |
|-----------|-----------|----------------|----------------------------------------------|
| `w_clk`   | Input     | 1              | Write clock                                   |
| `w_rst`   | Input     | 1              | Active-high synchronous reset for write domain |
| `push`    | Input     | 1              | Push (write) enable signal                    |
| `r_clk`   | Input     | 1              | Read clock                                    |
| `r_rst`   | Input     | 1              | Active-high synchronous reset for read domain |
| `pop`     | Input     | 1              | Pop (read) enable signal                      |
| `w_data`  | Input     | `DATA_WIDTH`   | Data to be pushed into the stack              |
| `r_data`  | Output    | `DATA_WIDTH`   | Data popped from the stack                    |
| `r_empty` | Output    | 1              | High when the stack is empty (read side)      |
| `w_full`  | Output    | 1              | High when the stack is full (write side)      |

---

## 4. Parameters

| Name         | Default | Description                              |
|--------------|---------|------------------------------------------|
| `DATA_WIDTH` | 16      | Bit width of each data word              |
| `DEPTH`      | 8       | Number of entries in the FILO buffer     |

---

## 5. Internal Architecture

### 5.1 Memory

- Internal memory `mem` of size `DEPTH`, each entry is `DATA_WIDTH` wide.
- Indexed by the binary write (`w_count_bin`) and read (`r_count_bin`) pointers.

### 5.2 Pointer Mechanism

- **Write Pointer (`w_ptr`)**: Gray-coded write pointer updated with `w_clk`.
- **Read Pointer (`r_ptr`)**: Gray-coded read pointer updated with `r_clk`.
- **Conversion**: Binary ↔ Gray code conversions done with helper functions `bin2gray()` and `gray2bin()`.

### 5.3 Pointer Synchronization

- Write domain synchronizes read pointer using `wq1_rptr` → `wq2_rptr`
- Read domain synchronizes write pointer using `rq1_wptr` → `rq2_wptr`

### 5.4 Full and Empty Logic

- `w_full` is asserted when write pointer catches up to read pointer from the write domain’s perspective.
- `r_empty` is asserted when read pointer catches up to write pointer from the read domain’s perspective.

---

## 6. Operation

### 6.1 Push

- On rising edge of `w_clk`, if `push` is high and `w_full` is low:
  - Writes `w_data` into `mem` at current write address.
  - Increments write binary counter and updates Gray-coded write pointer.

### 6.2 Pop

- On rising edge of `r_clk`, if `pop` is high and `r_empty` is low:
  - Outputs data from `mem` at current read address (`r_data` is continuously driven).
  - Decrements read binary counter and updates Gray-coded read pointer.

---

## 7. Reset Behavior

| Signal  | Clock   | Effect                                                             |
|---------|---------|--------------------------------------------------------------------|
| `w_rst` | `w_clk` | Resets `w_ptr`, `w_count_bin`, `wq1_rptr`, `wq2_rptr`, and `w_full` |
| `r_rst` | `r_clk` | Resets `r_ptr`, `r_count_bin`, `rq1_wptr`, `rq2_wptr`, and `r_empty`|

---

## 8. Clock Domain Crossing

Gray-coded pointers and two-stage flip-flop synchronizers are used to safely transfer:

- Read pointer to write domain (`r_ptr` → `wq2_rptr`)
- Write pointer to read domain (`w_ptr` → `rq2_wptr`)

This ensures metastability is mitigated when comparing pointers across asynchronous domains.

---
