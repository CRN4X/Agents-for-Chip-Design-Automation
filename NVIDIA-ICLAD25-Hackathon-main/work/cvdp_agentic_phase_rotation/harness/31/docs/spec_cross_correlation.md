# Cross Correlation Top-Level Module (`cross_correlation.sv`)

## Overview
The `cross_correlation` module performs energy-based correlation of complex sequences composed of **I (in-phase)** and **Q (quadrature)** components. This top-level module integrates two main functional blocks:

- A **correlation stage**, handled by the existing `correlate` module.
- A **reduction and energy computation stage**, implemented in the existing `adder_2d_layers` module.

The goal is to produce a scalar energy output derived from the correlation between input data and a conjugate reference sequence, while supporting dynamic operation modes and mode-awareness feedback.

---

## Required Modules

### `cross_correlation`
This top-level module instantiates:

- The `correlate` module to compute intermediate correlation terms.
- The `adder_2d_layers` module to perform summation and energy computation.

This module exposes configuration parameters and connects all control and data paths. All internal parameters required by submodules (e.g., widths, number of symbols, levels of the tree, register configurations) are configured through the top-level module.

#### Parameters
| Parameter         | Description                                  | Default Value | Constraints                                              |
|-------------------|----------------------------------------------|---------------|----------------------------------------------------------|
| `NS_DATA_IN`      | Number of input data samples                 | `2`           | ≥ 2                                                      |
| `NBW_DATA_IN`     | Bit width of each input data sample          | `5`           | ≥ 3                                                      |
| `NBI_DATA_IN`     | Number of integer bits in the input data     | `1`           | ≤ `NBW_DATA_IN - 2`                                      |
| `NBW_ENERGY`      | Bit width of the final energy output         | `5`           | Between 3 and `NBW_DATA_IN`, inclusive                   |

#### Interface

| Signal             | Direction | Width                              | Description                                               |
|--------------------|-----------|------------------------------------|-----------------------------------------------------------|
| `clk`              | Input     | 1 bit                              | System clock                                              |
| `rst_async_n`      | Input     | 1 bit                              | Asynchronous active-low reset                             |
| `i_enable`         | Input     | 1 bit                              | Enable signal for pipeline stages                         |
| `i_mode`           | Input     | 2 bits                             | Operation mode selector                                   |
| `i_data_i`         | Input     | `NBW_DATA_IN * NS_DATA_IN`         | Input data (I component)                                  |
| `i_data_q`         | Input     | `NBW_DATA_IN * NS_DATA_IN`         | Input data (Q component)                                  |
| `i_conj_seq_i`     | Input     | `NS_DATA_IN`                       | Conjugate sequence for I                                  |
| `i_conj_seq_q`     | Input     | `NS_DATA_IN`                       | Conjugate sequence for Q                                  |
| `o_energy`         | Output    | `NBW_ENERGY`                       | Computed energy value from cross correlation              |
| `o_aware_mode`     | Output    | 1 bit                              | Indicates if mode is recognized as valid by adder layer   |

#### Signal Propagation
- The signal `i_mode` is connected to both the `correlate` and `adder_2d_layers` submodules.
- The signal `rst_async_n` is connected to the `adder_2d_layers` module.
- The output `o_aware_mode` is driven by the `adder_2d_layers` module and forwarded through this top-level interface.

---

### `adder_2d_layers`
This module sits between `cross_correlation` and `adder_tree_2d`. Its responsibilities include:

1. Instantiating two `adder_tree_2d` modules (for I and Q correlation results) to perform 2D summation of the outputs from `correlate`.
2. Registering the outputs of both adder trees when `i_enable` is asserted.
3. Computing the energy using the squared values of I and Q outputs, and truncating the result according to the `NBW_ENERGY` parameter.
4. Monitoring the `i_mode` signal and comparing it to valid modes (defined externally in `valid_modes.md`). If `i_mode` matches a valid mode, the `o_aware_mode` flag is raised synchronously with the clock.

#### Parameters

| Parameter             | Default Value | Description                                                                |
|-----------------------|---------------|----------------------------------------------------------------------------|
| `NBW_IN`              | 8             | Bit width of each correlation input sample                                 |
| `NS_IN`               | 80            | Number of input samples to the adder tree                                  |
| `N_LEVELS`            | 7             | Number of levels in the adder tree                                         |
| `REGS`                | 8'b100010_0   | Pipeline register mask per level                                           |
| `NBW_ADDER_TREE_OUT`  | 8             | Output bit width of the adder tree                                         |
| `NBW_ENERGY`          | 5             | Output bit width for energy (after truncation)                             |

#### Interface

| Signal           | Direction | Width                                 | Description                                               |
|------------------|-----------|---------------------------------------|-----------------------------------------------------------|
| `clk`            | Input     | 1 bit                                 | System clock                                              |
| `rst_async_n`    | Input     | 1 bit                                 | Asynchronous active-low reset                             |
| `i_enable`       | Input     | 1 bit                                 | Enable signal to control output registration              |
| `i_mode`         | Input     | 2 bits                                | Operation mode selector                                   |
| `i_data_i`       | Input     | `NBW_IN * NS_IN`                      | Input correlation data (I component)                      |
| `i_data_q`       | Input     | `NBW_IN * NS_IN`                      | Input correlation data (Q component)                      |
| `o_data_i`       | Output    | `NBW_IN + N_LEVELS`                   | Accumulated correlation result for I                      |
| `o_data_q`       | Output    | `NBW_IN + N_LEVELS`                   | Accumulated correlation result for Q                      |
| `o_energy`       | Output    | `NBW_ENERGY`                          | Truncated energy result from the squared I and Q results  |
| `o_aware_mode`   | Output    | 1 bit                                 | High when current mode is valid                           |

---

### `correlate`
The `correlate` module has been updated to support a new 2-bit input signal `i_mode`. Its behavior is determined by this mode:

- `i_mode == 2'b00`: operates as originally specified.
- `i_mode == 2'b01`: always subtracts incoming data for correlation index computation.
- `i_mode == 2'b10`: always adds incoming data for correlation index computation.
- `i_mode == 2'b11`: outputs all-zero indices, effectively disabling correlation.

This logic allows dynamic reconfiguration of correlation behavior based on system-level FSM control.

---

## Notes

- The `adder_2d_layers` module includes sequential (pipelining) and combinational (energy calculation) logic as specified.
- Mode-awareness and reset propagation must be handled through the existing interfaces.
- All configuration must be managed through top-level parameters to ensure consistency across submodules.