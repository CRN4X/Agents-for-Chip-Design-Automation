## Overview
The `top_phase_rotation` module implements **phase rotation** for complex input samples (**I, Q**) using **lookup table-based sine and cosine generation**. The module processes multiple input samples (`NS_IN`) in parallel and applies a **pipeline-based architecture** to compute the rotated outputs.

## Parameters
| Parameter     | Description                                                                       |
|---------------|-----------------------------------------------------------------------------------|
| `NBW_ANG`     | Bit width of the phase angle input (fixed at 7)                                   |
| `NBW_COS`     | Bit width of the cosine/sine values generated from the lookup table (fixed at 10) |
| `NBW_IN_DATA` | Bit width of input data                                                           |
| `NS_IN`       | Number of input samples processed in parallel                                     |
| `NBW_MULT`    | Bit width of the multiplication result (`NBW_IN_DATA + NBW_COS`)                  |
| `NBW_SUM`     | Bit width of the sum operation (`NBW_MULT + 1`)                                   |
| `NBW_OUT_DATA`| Bit width of output data (`NBW_SUM`)                                              |

## Interface
| Signal      | Direction | Width                    | Description                                  |
|-------------|-----------|--------------------------|----------------------------------------------|
| `clk`       | Input     | 1 bit                    | System clock (rising edge)                   |
| `i_data_re` | Input     | `NBW_IN_DATA * NS_IN`    | Real part of the input complex samples       |
| `i_data_im` | Input     | `NBW_IN_DATA * NS_IN`    | Imaginary part of the input complex samples  |
| `i_angle`   | Input     | `NBW_ANG * NS_IN`        | Phase angle input for rotation               |
| `o_data_re` | Output    | `NBW_OUT_DATA * NS_IN`   | Rotated real part of the output samples      |
| `o_data_im` | Output    | `NBW_OUT_DATA * NS_IN`   | Rotated imaginary part of the output samples |

## Design Details
The `top_phase_rotation` module integrates the following submodules:

- **`gen_cos_sin_lut`**:
  - Generates **cosine** and **sine** values based on the input angle using a lookup table (LUT).
  - Each phase angle in `i_angle` is mapped to corresponding cosine (`o_cos`) and sine (`o_sin`) values.
  - Parameters available on interface `NBW_ANG` and `NBW_COS`.

- **`phase_rotation`**:
  - Performs phase rotation using the equation:
  - Multiplies the input signals with cosine and sine values.
  - Parameters available on interface `NBW_IN_DATA`, `NBW_COS`, `NBW_MULT`, `NBW_SUM` and `NBW_OUT_DATA`

The following processes should be performed before and after the modules presented above:
- **Input Data Formatting**:
  - Converts `i_data_re`, `i_data_im`, and `i_angle` from **1D array** format to **2D arrays** (`NS_IN` elements each).
  - Ensures correct signed representation for computations.

- **Output Formatting**:
  - Converts the **2D output arrays** (`o_data_re_2d` and `o_data_im_2d`) back into **1D format**.
  - Uses **unsigned representation** before assigning to `o_data_re` and `o_data_im`.

## Functionality
1. **Receives parallel complex input samples (`NS_IN`)**.
2. **Retrieves cosine and sine values** from the lookup table.
3. **Computes the rotated output** using multiplications and summations.
4. **Formats the output data** into a single vector for efficient transmission.

## Latency and Pipeline
- The **cos/sin LUT** operates combinationally.
- The **phase rotation** module uses **pipeline registers** for multiplication and summation (1 clock cycle).

## Summary
The `top_phase_rotation` module is designed for **efficient phase rotation** of complex signals using LUT-based trigonometric functions. It supports **parametric bit widths** and **parallel input processing** for high-throughput applications.