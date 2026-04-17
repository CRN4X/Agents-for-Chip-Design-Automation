# SIMD Datapath Submodule Analysis

The `simd_datapath` module performs **SIMD-style parallel arithmetic processing** across multiple data lanes. It connects and coordinates multiple instances of the `simd_lane` submodule to apply vectorized operations such as addition, subtraction, and multiplication in parallel. This module is typically integrated into larger systems like matrix arithmetic engines, vector processors, or data-parallel accelerators.

---

## Parameterization

- **SIMD_WIDTH:**  
  Specifies the number of parallel SIMD lanes. Each lane operates on one scalar element. This allows the datapath to scale with the desired level of parallelism. Default: 4.

- **DATA_WIDTH:**  
  Defines the bit-width of each operand and result element within a lane. Default: 16.

---

## Interfaces

### Data and Control Inputs

- **a_flat (SIMD_WIDTH × DATA_WIDTH bits):**  
  Packed input vector A. Each segment corresponds to one SIMD lane.

- **b_flat (SIMD_WIDTH × DATA_WIDTH bits):**  
  Packed input vector B. Each segment corresponds to one SIMD lane.

- **valid_lanes (SIMD_WIDTH bits):**  
  Lane mask enabling operation on a per-lane basis. A bit value of `1` enables that lane for computation.

- **op_sel [2:0 bits]:**  
  Operation selector:
  - `3'b000`: ADD
  - `3'b001`: SUB
  - `3'b010`: MUL

### Data Outputs

- **result_flat (SIMD_WIDTH × DATA_WIDTH bits):**  
  Packed result vector. Each segment corresponds to the computed output from a SIMD lane.

- **ready (1 bit):**  
  Global ready signal. Asserted (`1`) when **all enabled lanes** have completed their operation.

---

## Detailed Functionality

### 1. Lane Extraction

- The `a_flat` and `b_flat` input vectors are unpacked into individual lane elements (`a_arr[i]`, `b_arr[i]`) using bit slicing logic.  
- Each lane is sized as `DATA_WIDTH` bits and mapped to a unique SIMD index.

### 2. SIMD Lane Instantiation

- A `for-generate` block creates `SIMD_WIDTH` instances of the `simd_lane` module.
- Each lane is connected to the corresponding elements of `a_arr[i]` and `b_arr[i]`.
- The control signals `valid_lanes[i]` and `op_sel` are passed into each `simd_lane` instance.

### 3. Output Assembly

- Each lane returns a result (`result_arr[i]`) and a lane-local ready flag (`lane_ready[i]`).
- The `result_arr` values are packed into `result_flat` using assign statements.
- The global `ready` output is computed as a bitwise AND (`&lane_ready`) of all lane readiness signals.

---

## Safe and Scalable Design

- If a lane is disabled (`valid_lanes[i] = 0`), the lane outputs `0`, and its ready signal is also considered asserted (`1`), ensuring **correct aggregation** of readiness.

- This approach supports **partial vector operation**, where only a subset of lanes are active.

- Designed with scalability in mind: increasing `SIMD_WIDTH` or `DATA_WIDTH` only requires regenerating the module with new parameters.

---

## Summary

- **Purpose and Function:**  
  The `simd_datapath` module enables parallel execution of arithmetic operations across multiple SIMD lanes using a vector-wide `op_sel`. It abstracts the complexity of individual lane control while preserving full parallelism.

- **Parallelism and Flexibility:**  
  Parameterized for lane count and data width. Allows for efficient implementation of wide vector operations such as vector addition, subtraction, and multiplication.

- **Modular Composition:**  
  Reuses the `simd_lane` submodule to ensure code reuse, scalability, and isolated verification.

- **Latency and Timing:**  
  Entirely combinational. Each operation completes in a single cycle assuming `simd_lane` is fully combinational. Ready signal reflects instant availability of results.
---