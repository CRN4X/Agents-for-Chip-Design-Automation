# Branch Control Unit Specification

---

## 1. Overview

The **branch_control_unit** is a combinational logic module designed to generate branch control signals based on two sets of input conditions. It evaluates a 4‑bit branch selection vector (formed from inputs *i_3, i_2, i_1, i_0*) and, within each branch case, further inspects a 4‑bit test condition (formed from *test_3, test_2, test_1, test_0*) to determine the final branch outcome. The resulting 4‑bit output (*o_3, o_2, o_1, o_0*) controls the flow within a processor or similar digital system, ensuring branch decisions are made only when required conditions are met.

---

## 2. Key Features

- **Two-Level Decoding:**
  - **Primary Decoding:** Determines one of 16 possible branch scenarios based on the branch selection inputs.
  - **Secondary Decoding:** Nested evaluation of test conditions refines control decisions.

- **Flexible Pattern Matching with `casex`:**  
  Use of `casex` statements allows “don’t‑care” bits (`x`) for simplified condition evaluation.

- **Purely Combinational Logic:**  
  Implemented using an `always_comb` block, providing instant reaction to input changes.

- **Safe Default Behavior:**  
  Default assignments ensure safe output states when input combinations are unmatched.

---

## 3. Port Descriptions

| Port Name   | Direction | Width | Description                                                 |
|-------------|-----------|-------|-------------------------------------------------------------|
| **Inputs**  |           |       |                                                             |
| `test_0`    | Input     | 1 bit | Test signal bit 0 used for refining branch decisions.       |
| `test_1`    | Input     | 1 bit | Test signal bit 1 used for refining branch decisions.       |
| `test_2`    | Input     | 1 bit | Test signal bit 2 used for refining branch decisions.       |
| `test_3`    | Input     | 1 bit | Test signal bit 3 used for refining branch decisions.       |
| `i_0`       | Input     | 1 bit | Branch selection bit 0, part of the 4‑bit branch selector.  |
| `i_1`       | Input     | 1 bit | Branch selection bit 1, part of the 4‑bit branch selector.  |
| `i_2`       | Input     | 1 bit | Branch selection bit 2, part of the 4‑bit branch selector.  |
| `i_3`       | Input     | 1 bit | Branch selection bit 3, part of the 4‑bit branch selector.  |
| **Outputs** |           |       |                                                             |
| `o_0`       | Output    | 1 bit | Branch control output bit 0.                                |
| `o_1`       | Output    | 1 bit | Branch control output bit 1.                                |
| `o_2`       | Output    | 1 bit | Branch control output bit 2.                                |
| `o_3`       | Output    | 1 bit | Branch control output bit 3.                                |

---

## 4. Functional Flow

1. **Primary Branch Selection:**  
   Inputs `{i_3, i_2, i_1, i_0}` form a vector decoded via a `case` statement into 16 scenarios.

2. **Nested Test Condition Evaluation:**  
   Within each scenario, nested `casex` evaluates `{test_3, test_2, test_1, test_0}`, considering only relevant bits.

3. **Output Determination:**  
   Based on scenario and conditions, outputs `{o_3, o_2, o_1, o_0}` are asserted.

4. **Default Handling:**  
   Unmatched conditions default outputs to `0`.

---

## 5. Comprehensive Function Table

| Function                                | i_3 | i_2 | i_1 | i_0 | test_3 | test_2 | test_1 | test_0 | o_3    | o_2    | o_1    | o_0    |
|-----------------------------------------|:---:|:---:|:---:|:---:|:------:|:------:|:------:|:------:|:------:|:------:|:------:|:------:|
| **No Test**                             |  0  |  0  |  0  |  0  |   X    |   X    |   X    |   X    |   0    |   0    |   0    |   0    |
| **Test test_0**                         |  0  |  0  |  0  |  1  |   X    |   X    |   X    | 0 or 1 |   0    |   0    |   0    | 0 or 1*|
| **Test test_1**                         |  0  |  0  |  1  |  0  |   X    |   X    | 0 or 1 |   X    |   0    |   0    |   0    | 0 or 1*|
| **Test test_0 & test_1**                |  0  |  0  |  1  |  1  |   X    |   X    |   X    |   X    |   0    |   0    | 0 or 1*| 0 or 1*|
| **Test test_2**                         |  0  |  1  |  0  |  0  |   X    |   X    |   X    |   X    |   0    |   0    |   0    | 0 or 1*|
| **Test test_0 & test_2**                |  0  |  1  |  0  |  1  |   X    |   X    |   X    |   X    |   0    |   0    | 0 or 1*| 0 or 1*|
| **Test test_1 & test_2**                |  0  |  1  |  1  |  0  |   X    |   X    |   X    |   X    |   0    |   0    | 0 or 1*| 0 or 1*|
| **Test test_0, test_1 & test_2**        |  0  |  1  |  1  |  1  |   X    |   X    |   X    |   X    |   0    | 0 or 1*| 0 or 1*| 0 or 1*|
| **Test test_3**                         |  1  |  0  |  0  |  0  | 0 or 1 |   X    |   X    |   X    |   0    |   0    |   0    | 0 or 1*|
| **Test test_0 & test_3**                |  1  |  0  |  0  |  1  |   X    |   X    |   X    |   X    |   0    |   0    | 0 or 1*| 0 or 1*|
| **Test test_1 & test_3**                |  1  |  0  |  1  |  0  |   X    |   X    |   X    |   X    |   0    |   0    | 0 or 1*| 0 or 1*|
| **Test test_0, test_1 & test_3**        |  1  |  0  |  1  |  1  |   X    |   X    |   X    |   X    |   0    | 0 or 1*| 0 or 1*| 0 or 1*|
| **Test test_2 & test_3**                |  1  |  1  |  0  |  0  |   X    |   X    |   X    |   X    |   0    |   0    | 0 or 1*| 0 or 1*|
| **Test test_0, test_2 & test_3**        |  1  |  1  |  0  |  1  |   X    |   X    |   X    |   X    |   0    | 0 or 1*| 0 or 1*| 0 or 1*|
| **Test test_1, test_2 & test_3**        |  1  |  1  |  1  |  0  |   X    |   X    |   X    |   X    |   0    | 0 or 1*| 0 or 1*| 0 or 1*|
| **Test test_0, test_1, test_2 & test_3**|  1  |  1  |  1  |  1  |   X    |   X    |   X    |   X    | 0 or 1*| 0 or 1*| 0 or 1*| 0 or 1*|

> **Notes:**  
> - `X` = Don’t care (can be either 0 or 1).  
> - Many rows show “0 or 1” because the output bit is asserted only if the corresponding test bit is `1`.  
> - In cases where a specific test bit is not relevant, it is treated as `X` (don’t care).

---

## 6. Testbench Information

A SystemVerilog testbench (**tb_branch_control_unit**) verifies the logic by:

- **Instantiating** the DUT with the inputs `i_3, i_2, i_1, i_0, test_3, test_2, test_1, test_0` and the outputs `o_3, o_2, o_1, o_0`.
- **Applying Test Vectors:**  
  Various 4‑bit patterns for `{i_3, i_2, i_1, i_0}` (from `4'b0000` through `4'b1111`) are driven. In the sample testbench, the test signals `{test_3, test_2, test_1, test_0}` are often set to `0`, but the structure allows for driving them with different patterns as needed.
- **Checker Task:**  
  A dedicated task computes the **expected** outputs based on the same case logic, then compares them to the **actual** DUT outputs.
- **Simulation Control:**  
  After stepping through the desired input combinations (with delays to allow the combinational logic to settle), the testbench calls `$finish` to end the simulation.

---

## 7. Summary

The **branch_control_unit** employs a two-level decoding scheme:
1. It first identifies which branch scenario is active based on the 4‑bit inputs `{i_3, i_2, i_1, i_0}`.
2. It then refines the branch decision by examining up to four test bits `{test_3, test_2, test_1, test_0}`.

The final outputs `{o_3, o_2, o_1, o_0}` are driven high or low depending on these combined conditions. Comprehensive documentation and a robust testbench confirm that only valid branches are taken (outputs set to 1) when the correct test bits are asserted. This design ensures clean, safe default behavior—outputs default to `0` for any condition that is not explicitly enabled.

---