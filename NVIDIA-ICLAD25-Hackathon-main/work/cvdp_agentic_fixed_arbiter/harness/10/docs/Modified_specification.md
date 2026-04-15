# Fixed Priority Arbiter with Enable, Clear, and Active Grant Tracking  
## Specification Document  

---

## Introduction  

The **Fixed Priority Arbiter** module provides **one-hot grant arbitration** among 8 requesters using a **fixed priority scheme**, where **lower index has higher priority**. It includes the following extended features:

- **External Priority Override** to dynamically control the granted request  
- **Enable signal** to control when arbitration occurs  
- **Clear signal** to forcefully clear all outputs  
- **Active Grant Tracking** using `active_grant`, which always reflects the most recently granted request index  

The arbiter operates synchronously with the system clock and provides a **single-cycle arbitration latency**.

---

## Arbitration Overview  

The arbiter operates with the following priority rules and logic flow:

1. **Reset and Clear Conditions**  
   - On `reset` (active-high), all outputs (`grant`, `valid`, `grant_index`, `active_grant`) are cleared.  
   - On `clear` (active-high), all outputs are forcefully cleared, even if arbitration is enabled.

2. **Enable Check**  
   - Arbitration is performed only when `enable` is high.  
   - If `enable` is low, the current outputs are held.

3. **Priority Override**  
   - If `priority_override` is non-zero, it **overrides the normal request logic**.  
   - The **lowest index active bit** in `priority_override` is granted.

4. **Fixed Priority Arbitration**  
   - If `priority_override` is zero, the arbiter scans `req[0]` to `req[7]`.  
   - The **first active request** (lowest index) is granted.

5. **Grant Output**  
   - The `grant` signal is a **one-hot 8-bit output**, corresponding to the granted request.  
   - The `grant_index` output provides the **binary index** of the granted request.  
   - The `active_grant` output is always updated with the latest grant index.  
   - The `valid` signal is high if any grant is active.

---

## Module Interface  

```verilog
module fixed_priority_arbiter (
    input        clk,               // Clock signal
    input        reset,             // Active-high reset
    input        enable,            // Arbitration enable
    input        clear,             // Manual clear
    input  [7:0] req,               // Request vector
    input  [7:0] priority_override, // External priority control

    output reg [7:0] grant,         // One-hot grant output
    output reg       valid,         // Indicates valid grant
    output reg [2:0] grant_index,   // Binary index of granted request
    output reg [2:0] active_grant   // Tracks latest granted index
);
```

## Port Description

| **Signal**              | **Direction** | **Description**                                                                |
|-------------------------|---------------|--------------------------------------------------------------------------------|
| `clk`                   | Input         | System clock (rising-edge triggered).                                         |
| `reset`                 | Input         | Active-high synchronous reset, clears all outputs.                            |
| `enable`                | Input         | When high, enables arbitration; outputs are held when low.                    |
| `clear`                 | Input         | Synchronous clear signal to reset all outputs regardless of current state.    |
| `req[7:0]`              | Input         | Request vector; each bit represents an independent requester.                |
| `priority_override[7:0]`| Input         | Overrides `req` if non-zero; used for external dynamic priority control.      |
| `grant[7:0]`            | Output        | One-hot grant output corresponding to granted requester.                      |
| `valid`                 | Output        | High if any request is granted.                                               |
| `grant_index[2:0]`      | Output        | Binary-encoded index of the granted request.                                  |
| `active_grant[2:0]`     | Output        | Tracks current/last granted index; useful for monitoring or logging.          |

---

## Internal Architecture

### 1. Priority Override Logic
- When `priority_override` is non-zero, the grant logic selects the **lowest set bit**, ignoring `req`.
- Outputs are derived from `priority_override`.

### 2. Fixed Priority Grant Selection
- If `priority_override` is zero, `req` is scanned from bit 0 to 7.
- The **first active bit** is granted using fixed priority logic.

### 3. Control Logic
- `reset` and `clear` signals take precedence and reset outputs synchronously.
- `enable` must be high for the arbiter to evaluate new grants.
- If no request is active, `valid` is low and all grant-related outputs are cleared.

### 4. Grant Indexing
- `grant_index` and `active_grant` both reflect the binary index of the granted request.
- These are updated alongside `grant`.

---

## Output Behavior

| **Condition**                                     | `grant`       | `grant_index` | `valid` | `active_grant` |
|--------------------------------------------------|---------------|---------------|---------|----------------|
| Reset or Clear                                   | `8'b00000000` | `3'd0`        | `0`     | `3'd0`         |
| `priority_override = 8'b00001000`                | `8'b00001000` | `3'd3`        | `1`     | `3'd3`         |
| `req = 8'b00110000`                              | `8'b00010000` | `3'd4`        | `1`     | `3'd4`         |
| No requests (`req = 0`, `priority_override = 0`) | `8'b00000000` | `3'd0`        | `0`     | `3'd0`         |
| `enable = 0`                                     | Outputs held  | Held          | Held    | Held           |

---

## Timing and Latency

All operations are complete in **one clock cycle** if `enable` is asserted.

| **Operation**        | **Latency (Clock Cycles)** |
|----------------------|----------------------------|
| Request Arbitration  | 1                          |
| Priority Override    | 1                          |
| Reset or Clear       | 1                          |

---

## Summary

The `fixed_priority_arbiter` is a robust, one-cycle arbitration module with support for:

- Fixed-priority one-hot arbitration
- External override control
- Reset and clear synchronization
- Continuous tracking of active grant

It’s suitable for bus arbitration, DMA request selection, or any system requiring deterministic priority-based selection.