## Overview
The `phase_rotation_viterbi` module implements **phase estimation and correction** using **fourth-power phase detection**. The module processes complex input samples (**I, Q**) and applies a **pipeline-based architecture** to compute and correct the phase.

## Parameters
| Parameter  | Description                                                                                                                         |
|------------|-------------------------------------------------------------------------------------------------------------------------------------|
| `NBW_IN`   | Bit width of input data (Can be updated by user)                                                                                    |
| `NBW_OUT`  | Sufficient bit width to accommodate fourth-power operations and final phase rotation (Can not be changed by user, only pre-defined) |

## Interface
| Signal        | Direction| Width       | Description                                     |
|---------------|----------|-------------|-------------------------------------------------|
| `clk`         | Input    | 1 bit       | System clock (rising edge)                      |
| `rst_async_n` | Input    | 1 bit       | Asynchronous reset (Async active low)           |
| `i_data_i`    | Input    | `NBW_IN`    | I-phase input data                              |
| `i_data_q`    | Input    | `NBW_IN`    | Q-phase input data                              |
| `o_data_i`    | Output   | `NBW_OUT`   | I-phase output data after phase rotation        |
| `o_data_q`    | Output   | `NBW_OUT`   | Q-phase output data after phase rotation        |

## Design Details
The `phase_rotation_viterbi` module integrates the following submodules in sequence:

- **`power4`**: Computes the **fourth power** of the input signals (`i_data_i`, `i_data_q`).  
  - **Latency:** 1 clock cycle.

- **`saturation` (2 instances)**: 
  - Fully combinational
  - Saturates the **fourth-power outputs** to **6-bit signed values**.

- **`phase_lut`**: Computes the **normalized phase** from the **6-bit complex input (`I/Q`)** that comes from fourth power saturated data.
  - Fully combinational
  - **Output:** 9-bit phase, normalized by PI.

- **Phase division by 4**: 
  - The **9-bit phase** from `phase_lut` is **right-shifted by 2** to obtain a 9-bit divided phase.

- **`saturation` (1 instance)**:
  - Saturates the **divided phase** from **9 bits to 7 bits (signed)**.

- **`top_phase_rotation`**:
  - Applies phase rotation using the **delayed** I/Q signals (1-cycle delay, reset to zero) and the **7-bit phase**.
  - **Outputs:** `o_data_i`, `o_data_q`.