# Sequence Detection Module (`detect_sequence.sv`)

## Parameters

| Parameter         | Description                                               | Default | Constraints                                                             |
|-------------------|-----------------------------------------------------------|---------|-------------------------------------------------------------------------|
| `NS`              | Number of pilot symbols                                   | 64      | Minimum 32, maximum 64, must be a multiple of 2                         |
| `NBW_PILOT_POS`   | Bit width to address position within `NS`                 | 6       | Must be equal to `ceil(log2(NS))`                                       |
| `NBW_DATA_SYMB`   | Bit width of each I/Q data sample                         | 8       | Minimum 3                                                               |
| `NBI_DATA_SYMB`   | Number of integer bits within each sample                 | 2       | Must be `NBW_DATA_SYMB - 2`                                             |
| `NBW_TH_FAW`      | Bit width of static threshold                             | 10      | Must be equal to `NBW_DATA_SYMB + 2`                                    |
| `NBW_ENERGY`      | Bit width of energy output from correlation               | 10      | Must be equal to `NBW_TH_FAW`                                           |
| `NS_FAW`          | Number of samples used in FAW correlation                 | 23      | Fixed value                                                             |
| `NS_FAW_OVERLAP`  | Overlap used in FAW correlation                           | 22      | Must be equal to `NS_FAW - 1`                                           |

---

## Interfaces

### Inputs

| Signal               | Width                                   | Description                                      |
|----------------------|-----------------------------------------|--------------------------------------------------|
| `clk`                | 1                                       | System clock                                     |
| `rst_async_n`        | 1                                       | Asynchronous active-low reset                    |
| `i_valid`            | 1                                       | Valid signal to indicate valid input window      |
| `i_enable`           | 1                                       | Global enable for detection                      |
| `i_proc_pol`         | 1                                       | Sequence polarity selector (horizontal/vertical) |
| `i_proc_pos`         | `NBW_PILOT_POS`                         | Processing start position                        |
| `i_static_threshold` | `NBW_TH_FAW`                            | Threshold to compare with the computed energy    |
| `i_data_i`           | `NBW_DATA_SYMB * (NS + NS_FAW_OVERLAP)` | Flattened I input samples for full window        |
| `i_data_q`           | `NBW_DATA_SYMB * (NS + NS_FAW_OVERLAP)` | Flattened Q input samples for full window        |

### Outputs

| Signal            | Width  | Description                                |
|-------------------|--------|--------------------------------------------|
| `o_proc_detected` | 1      | Detection flag output (1 = sequence found) |

---

## Logic Description

### Conjugate Sequence Setup

Two predefined sequences must be stored to represent conjugate reference signals in the complex plane. These sequences correspond to expected pilot patterns in both horizontal and vertical orientations. The values should be constructed by computing the complex conjugate of the ideal signal, converting it to fixed-point representation, and then encoding the real and imaginary parts as bitstreams.

The module must allow dynamic selection between these two sequences based on a polarity signal. The selected conjugate must be assigned combinationally using the registered version of `i_proc_pol`.

For more information, refer docs/spec_conj.md
### Enable Pipeline

A global `enable` signal must be formed by combining `i_valid` and `i_enable`. This signal must be propagated through a pipeline of flip-flops. The number of stages in the pipeline must match the internal latency of the `cross_correlation` module.

- The **first stage** of the pipeline is used to drive the `i_enable` input of `cross_correlation`.
- The **last stage** must be used to validate the final detection output (`o_proc_detected`).
- When reset is active, all pipeline stages must be cleared to zero.

### Input Data Buffering

On the rising edge of the clock, when the global enable is active **before** the pipeline, a window of `NS_PROC` samples must be extracted from both `i_data_i` and `i_data_q` starting at position `i_proc_pos`. These samples must be stored in internal registers.

### Conjugate Selection

The conjugate sequence to be used must be selected based on the **registered value** of `i_proc_pol`. This selection must occur using combinational logic.

### Cross-Correlation Output Processing

The output energy from the `cross_correlation` module must be compared against the static threshold using the `>=` operator. If the comparison is true **and** the last stage of the enable pipeline is active, the detection result is `1`. Otherwise, it is `0`.

This detection result must be registered and then assigned to `o_proc_detected`.

---