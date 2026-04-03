# RTL Specification

## 1. Overview

### 1.1 Purpose
The **`prbs_gen_check`** module operates in two modes:
- **Generation Mode**: Outputs a pseudo-random bit sequence (PRBS).
- **Checker Mode**: Checks incoming data against an internal PRBS reference and flags mismatches.

### 1.2 Scope
- Supports a configurable data path width (`WIDTH`).
- Uses a linear feedback shift register (LFSR) defined by polynomial length (`POLY_LENGTH`) and tap location (`POLY_TAP`).
- Synchronous design with an active-high reset.

---

## 2. Functional Description

### 2.1 Generation Mode (`CHECK_MODE=0`)
1. On reset, the internal PRBS register (`prbs_reg`) is initialized (commonly to all 1’s).  
2. Each clock cycle, the LFSR shifts based on its feedback polynomial, producing the next pseudo-random word on `data_out`.

### 2.2 Checker Mode (`CHECK_MODE=1`)
1. On reset, `prbs_reg` is similarly initialized.  
2. Each clock cycle, the module generates the “expected” PRBS bit(s). It then compares each bit of the incoming data (`data_in`) to the internal PRBS reference.  
3. The output `data_out` is set to `1` on any bit that mismatches, and `0` otherwise.

### 2.3 Reset Behavior
- `rst` is synchronous, active high.
- On reset, `prbs_reg` is re-initialized, and the output may be driven to all 1’s until the reset is released.

---

## 3. Interface Definition

| **Port Name** | **I/O** | **Width**   | **Description**                                                                                  |
|---------------|---------|-------------|--------------------------------------------------------------------------------------------------|
| `clk`         | In      | 1           | Synchronous clock input.                                                                         |
| `rst`         | In      | 1           | Synchronous reset, active high.                                                                  |
| `data_in`     | In      | `WIDTH`     | In checker mode: Data to compare with the PRBS reference. In generator mode: tied to 0.          |
| `data_out`    | Out     | `WIDTH`     | In generator mode: PRBS output. In checker mode: Bitwise error flags (`1` = mismatch).           |

### 3.1 Parameters

| **Parameter**   | **Type** | **Default** | **Description**                                                                             |
|-----------------|----------|-------------|---------------------------------------------------------------------------------------------|
| `CHECK_MODE`    | int      | `0`         | - `0`: Generation Mode <br/> - `1`: Checker Mode                                            |
| `POLY_LENGTH`   | int      | `31`        | Number of shift register stages in the LFSR.                                                |
| `POLY_TAP`      | int      | `3`         | Defines which bit(s) is XORed with the final stage for feedback.                            |
| `WIDTH`         | int      | `16`        | Data path width.                                                                            |


---

## 4. Internal Architecture

### 4.1 LFSR
- A shift register (LFSR) generates the pseudo-random sequence.
- Feedback is formed by XORing selected bits (defined by `POLY_TAP` and the MSB).

### 4.2 Register Update
- On each rising clock edge:
  - If `rst` is asserted, the LFSR is re-initialized.
  - Otherwise, it shifts in the new feedback bit each cycle.

### 4.3 Output Behavior
- **Generator Mode**: `data_out` is the new PRBS word each cycle.  
- **Checker Mode**: `data_out` is the bitwise difference between the incoming data and the expected PRBS sequence.