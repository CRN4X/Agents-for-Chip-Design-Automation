# Slicer Top-Level Module (`slicer_top.sv`)

## Overview
The `slicer` module is a fully combinational design that classifies an input sample based on predefined thresholds. It determines the appropriate output value based on its relation to the provided threshold levels.

The `slicer_top` module integrates two instances of `slicer` to process the components of a complex sample, represented by **I (phase)** and **Q (quadrature)**.

## Parameters
The parameters for `slicer_top` follow the same structure as `slicer.sv`.

| Parameter  | Description                                  |
|------------|----------------------------------------------|
| `NBW_IN`   | Bit width of input data                      |
| `NBW_TH`   | Bit width of threshold input                 |
| `NBW_REF`  | Bit width of reference values                |
| `NS_TH`    | Fixed at 2                                   |

## Interface

| Signal           | Direction| Width                  | Description                                        |
|------------------|----------|------------------------|----------------------------------------------------|
| `clk`            | Input    | 1 bit                  | System clock (rising edge)                         |
| `rst_async_n`    | Input    | 1 bit                  | Asynchronous reset (active low)                    |
| `i_data_i`       | Input    | `NBW_IN`               | I-phase input data                                 |
| `i_data_q`       | Input    | `NBW_IN`               | Q-phase input data                                 |
| `i_threshold`    | Input    | `NBW_TH * NS_TH`       | Threshold values for comparison                    |
| `i_sample_1_pos` | Input    | `NBW_REF`              | Reference for `+1` classification                  |
| `i_sample_0_pos` | Input    | `NBW_REF`              | Reference for `0+` classification                  |
| `i_sample_0_neg` | Input    | `NBW_REF`              | Reference for `0-` classification                  |
| `i_sample_1_neg` | Input    | `NBW_REF`              | Reference for `-1` classification                  |
| `i_calc_cost`    | Input    | 1 bit                  | Cost calculation enable signal                     |
| `o_calc_cost`    | Output   | 1 bit                  | Delayed cost calculation signal (2-stage pipeline) |
| `o_energy`       | Output   | *Computed width*       | Energy calculation output                          |

## Design Requirements
### Pipeline for `i_calc_cost`
- The signal `i_calc_cost` must be **registered through two pipeline stages** before reaching `o_calc_cost`.
- On reset (`rst_async_n` = 0), both pipeline registers must be set to **zero**.

### Registering Slicer Outputs
- The outputs of `slicer` instances should be **registered** in `slicer_top`.
- If the first pipeline stage of `i_calc_cost` is `1`, the output registers must **update with new slicer results**.
- If the first pipeline stage of `i_calc_cost` is `0`, the output registers must **retain their previous values**.
- On reset (`rst_async_n` = 0), the output registers must be set to **zero**.

### Energy Calculation
- The `o_energy` output represents the energy of the complex sample after slicing.
- It is obtained by computing the sum of the squared values of the outputs from both `slicer` instances.
- This value provides a measure of the signal magnitude after slicing and is useful for subsequent processing steps.
- The bit width of `o_energy` must be large enough to **fully accommodate the squared sum computation**.