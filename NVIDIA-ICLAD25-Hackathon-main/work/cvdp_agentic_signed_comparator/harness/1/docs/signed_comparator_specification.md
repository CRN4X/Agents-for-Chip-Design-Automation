# Signed Comparator Specification Document

## Introduction

The **Signed Comparator** is a configurable hardware module designed to perform signed comparisons between two input values. It determines whether one value is greater than, less than, or equal to another while supporting optional tolerance-based equality checks and left-shifting of inputs before comparison. The module also provides an optional output register for synchronous operation.

---

## Functional Overview

The Signed Comparator operates based on the following key conditions:

1. **Input Preprocessing:**  
   - Both inputs `a` and `b` are left-shifted by `SHIFT_LEFT` bits before comparison.
   - The shifted values are used for all further computations.

2. **Equality with Tolerance:**  
   - If `ENABLE_TOLERANCE` is set, the module calculates the absolute difference between `a_shifted` and `b_shifted`.
   - If the absolute difference is less than or equal to `TOLERANCE`, the module treats the inputs as equal (`eq = 1`).

3. **Comparison Logic:**  
   - If `bypass` is active, the module forces `eq = 1` while `gt` and `lt` are set to `0`.
   - If `enable` is high:
     - If tolerance-based equality is met, `eq = 1`, `gt = 0`, `lt = 0`.
     - Otherwise, standard signed comparison is performed, setting `gt`, `lt`, and `eq` accordingly.

4. **Registering Output (Optional):**  
   - If `REGISTER_OUTPUT` is enabled, the comparison results (`gt`, `lt`, `eq`) are updated synchronously with `clk` and `rst_n`.
   - If `REGISTER_OUTPUT` is disabled, the outputs are updated combinationally.

---

## Module Interface

The signed comparator module should be defined as follows:

```verilog
module signed_comparator #(
  parameter integer DATA_WIDTH = 16,
  parameter integer REGISTER_OUTPUT = 0,
  parameter integer ENABLE_TOLERANCE = 0,
  parameter integer TOLERANCE = 0,
  parameter integer SHIFT_LEFT = 0
)(
  input  wire clk,
  input  wire rst_n,
  input  wire enable,
  input  wire bypass,
  input  wire signed [DATA_WIDTH-1:0] a,
  input  wire signed [DATA_WIDTH-1:0] b,
  output reg gt,
  output reg lt,
  output reg eq
);
```

### Port Description

- **clk:** Clock signal.
- **rst_n:** Active-low asynchronous reset.
- **enable:** Enables the comparator operation.
- **bypass:** Forces `eq = 1`, ignoring input values.
- **a:** First signed input value.
- **b:** Second signed input value.
- **gt:** High if `a > b` after processing.
- **lt:** High if `a < b` after processing.
- **eq:** High if `a == b` (considering optional tolerance).

---

## Internal Architecture

The internal architecture consists of the following key components:

1. **Shift Logic:**  
   - Both inputs `a` and `b` are left-shifted by `SHIFT_LEFT` bits before comparison.

2. **Tolerance-Based Equality Check:**  
   - If `ENABLE_TOLERANCE` is set, the module computes `abs_diff = |a_shifted - b_shifted|`.
   - If `abs_diff <= TOLERANCE`, the values are considered equal.

3. **Comparison Logic:**  
   - If bypass is active, the module outputs `eq = 1`, `gt = 0`, and `lt = 0`.
   - Otherwise, it compares `a_shifted` and `b_shifted`:
     - If `a_shifted > b_shifted`, `gt = 1`, `lt = 0`, `eq = 0`.
     - If `a_shifted < b_shifted`, `gt = 0`, `lt = 1`, `eq = 0`.
     - If they are equal, `eq = 1`, `gt = 0`, `lt = 0`.

4. **Registering Output (if enabled):**  
   - If `REGISTER_OUTPUT` is enabled, outputs (`gt`, `lt`, `eq`) are updated on the rising clock edge.
   - If disabled, outputs are updated immediately in combinational logic.

---

## Timing and Latency

- When `REGISTER_OUTPUT` is disabled, outputs are computed combinationally with zero-cycle latency.
- If `REGISTER_OUTPUT` is enabled, the comparison results are available one clock cycle after the input values are presented.

---

## Configuration Options

- **DATA_WIDTH**: Configurable bit width of input values.
- **REGISTER_OUTPUT**: Enables or disables registered output.
- **ENABLE_TOLERANCE**: Allows approximate equality comparison.
- **TOLERANCE**: Defines the tolerance range for equality.
- **SHIFT_LEFT**: Left-shift amount applied before comparison.

This design ensures a flexible and configurable signed comparator suitable for various digital logic applications.