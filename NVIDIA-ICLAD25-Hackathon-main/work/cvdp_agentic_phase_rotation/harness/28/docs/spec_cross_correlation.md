# Cross Correlation Top-Level Module (`cross_correlation.sv`)

## Overview
The `cross_correlation` module must be implemented to perform energy-based correlation of complex sequences composed of **I (in-phase)** and **Q (quadrature)** components. This top-level module is responsible for integrating two main functional blocks:

- A **correlation stage**, performed by an existing module `correlate`.
- A **reduction and energy computation stage**, to be implemented in a new module called `adder_2d_layers`.

The goal is to produce a scalar energy output derived from the correlation between input data and a conjugate reference sequence.

---

## Required Modules

### `cross_correlation` (to be implemented)
This is the top-level module and must instantiate:

- The existing `correlate` module to compute intermediate correlation terms.
- The `adder_2d_layers` module, which will be created to perform summation and energy computation.

This module must expose configuration parameters and connect all data paths accordingly. All internal parameters required by submodules (e.g., widths, number of symbols, levels of the tree, register configurations) must be configured through the top-level module.

#### Parameters
| Parameter         | Description                                  | Default Value | Constraints                                               |
|-------------------|----------------------------------------------|---------------|-----------------------------------------------------------|
| `NS_DATA_IN`      | Number of input data samples                 | `2`           | $\geq$ 2                                                  |
| `NBW_DATA_IN`     | Bit width of each input data sample          | `5`           | $\geq$ 3                                                  |
| `NBI_DATA_IN`     | Number of integer bits in the input data     | `1`           | $\leq$ `NBW_DATA_IN - 2`                                  |
| `NBW_ENERGY`      | Bit width of the final energy output         | `5`           | Between `3` and `NBW_DATA_IN`, inclusive                  |


#### Interface

| Signal           | Direction | Width                               | Description                                               |
|------------------|-----------|-------------------------------------|-----------------------------------------------------------|
| `clk`            | Input     | 1 bit                               | System clock                                              |
| `i_enable`       | Input     | 1 bit                               | Enable signal for pipeline stages                         |
| `i_data_i`       | Input     | `NBW_DATA_IN * NS_DATA_IN`          | Input data (I component)                                  |
| `i_data_q`       | Input     | `NBW_DATA_IN * NS_DATA_IN`          | Input data (Q component)                                  |
| `i_conj_seq_i`   | Input     | `NS_DATA_IN`                        | Conjugate sequence for I                                  |
| `i_conj_seq_q`   | Input     | `NS_DATA_IN`                        | Conjugate sequence for Q                                  |
| `o_energy`       | Output    | `NBW_ENERGY`                        | Computed energy value from cross correlation              |

---

### `adder_2d_layers` (to be implemented)
This module sits between `cross_correlation` and the existing `adder_tree_2d` module. It is responsible for:

1. **Instantiating two `adder_tree_2d` modules** (one for I and one for Q correlation results) to perform 2D summation of the outputs from `correlate`. These modules should be used with no clock cycles for latency.
2. **Aditional Logic**: A pipeline stage must be implemented that **registers the outputs** of both adder trees **only when the enable signal is asserted**. No reset signal is required. After registering the outputs, using combinational logic, the energy must be calculated as the **sum of the squares** of the I and Q results. This energy value must then be **truncated** to retain only the **most significant bits**, based on a top-level parameter defining the energy output width.

All internal parameters must be **configured from the top-level** `cross_correlation` module to ensure flexibility and consistency.

| Parameter             | Default Value | Description                                                                |
|-----------------------|---------------|----------------------------------------------------------------------------|
| `NBW_IN`              | 8             | Bit width of each correlation input sample                                 |
| `NS_IN`               | 80            | Number of input samples to the adder tree                                  |
| `N_LEVELS`            | 7             | Number of levels in the adder tree                                         |
| `REGS`                | 8'b100010_0   | Bitmask that enables pipelining per level: each bit corresponds to a level |
| `NBW_ADDER_TREE_OUT`  | 8             | Output bit width of the adder tree                                         |
| `NBW_ENERGY`          | 5             | Output bit width for energy (after truncation)                             |


#### Interface

| Signal           | Direction | Width                                | Description                                               |
|------------------|-----------|---------------------------------------|-----------------------------------------------------------|
| `clk`            | Input     | 1 bit                                 | System clock                                              |
| `i_enable`       | Input     | 1 bit                                 | Enable signal to control output registration              |
| `i_data_i`       | Input     | `NBW_IN * NS_IN`                      | Input correlation data (I component)                      |
| `i_data_q`       | Input     | `NBW_IN * NS_IN`                      | Input correlation data (Q component)                      |
| `o_data_i`       | Output    | `NBW_IN + N_LEVELS`                   | Accumulated correlation result for I                      |
| `o_data_q`       | Output    | `NBW_IN + N_LEVELS`                   | Accumulated correlation result for Q                      |
| `o_energy`       | Output    | `NBW_ENERGY`                          | Truncated energy result from the squared I and Q results  |

---

## Parameter Inference and Top-Level Propagation

To ensure proper functionality and maintainability of the design, additional internal configuration parameters must be created at the top level to support the submodules — particularly the adder tree components.

The following guidelines describe how these parameters should be inferred:

1. **Tree Depth Parameterization**  
   A parameter must be derived to represent the number of reduction levels in the adder tree structure. This value should be computed based on the total number of input elements and should represent the minimum number of binary reduction stages needed to produce a single accumulated result.

2. **Register Placement Configuration**  
   A configuration mask must be defined to control the placement of pipeline registers across the different summation levels of the tree. Each bit in the mask corresponds to one level, and activating a bit means inserting a register stage at that point. This allows fine-grained control over timing and latency.

3. **Data Width Growth Calculation**  
   Parameters must be created to determine the required width of the signals entering and exiting the adder tree. These widths must account for the growth caused by successive additions and must guarantee that no overflow occurs. This includes the signed bit growth of the accumulated values. All internal signals should be able to perform operations without rounding, saturating, or truncating any bits. Only the output `o_energy` is subject to specific truncation guidelines.

All of these derived values must be determined and set at the top level and passed as parameters to all relevant submodules. These derivations must follow consistent arithmetic rules and must not be hardcoded inside the internal modules to preserve modularity.


## Notes

- The `correlate` and `adder_tree_2d` modules already exist and should **not be reimplemented**.
- The modules `cross_correlation` and `adder_2d_layers` must be developed based on the descriptions above.
- The `adder_2d_layers` module must include both sequential (pipelining) and combinational (energy calculation) logic as specified.
- All configuration must be managed through top-level parameters to ensure consistency across submodules.