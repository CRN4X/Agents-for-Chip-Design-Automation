# Sequence Detection Module (`detect_sequence.sv`)

## Parameters

| Parameter           | Description                                               | Default | Constraints                                                             |
|---------------------|-----------------------------------------------------------|---------|-------------------------------------------------------------------------|
| `NS`                | Number of pilot symbols                                   | 64      | Minimum 32, maximum 64, must be a multiple of 2                         |
| `NBW_PILOT_POS`     | Bit width to address position within `NS`                 | 6       | Must be equal to `ceil(log2(NS))`                                       |
| `NBW_DATA_SYMB`     | Bit width of each I/Q data sample                         | 8       | Minimum 3                                                               |
| `NBI_DATA_SYMB`     | Number of integer bits within each sample                 | 2       | Must be `NBW_DATA_SYMB - 2`                                             |
| `NBW_TH_UNLOCK`     | Bit width of unlock threshold input                       | 3       | Determines range for FSM unlock threshold                               |
| `NBW_ENERGY`        | Bit width of energy output from correlation               | 10      | Should match cross correlation output width                             |
| `NS_FAW`            | Number of samples used in FAW correlation                 | 23      | Fixed value                                                             |
| `NS_FAW_OVERLAP`    | Overlap used in FAW correlation                           | 22      | Must be equal to `NS_FAW - 1`                                           |

---

## Interfaces

### Inputs

| Signal                     | Width                                    | Description                                        |
|----------------------------|------------------------------------------|----------------------------------------------------|
| `clk`                      | 1                                        | System clock                                       |
| `rst_async_n`              | 1                                        | Asynchronous active-low reset                      |
| `i_valid`                  | 1                                        | Valid signal to indicate valid input window        |
| `i_enable`                 | 1                                        | Global enable for detection                        |
| `i_proc_pol`               | 1                                        | Sequence polarity selector (horizontal/vertical)   |
| `i_proc_pos`               | `NBW_PILOT_POS`                          | Processing start position                          |
| `i_static_unlock_threshold`| `NBW_TH_UNLOCK`                          | Threshold for sequence unlock in FSM               |
| `i_data_i`                 | `NBW_DATA_SYMB * (NS + NS_FAW_OVERLAP)`  | Flattened I input samples for full window          |
| `i_data_q`                 | `NBW_DATA_SYMB * (NS + NS_FAW_OVERLAP)`  | Flattened Q input samples for full window          |

### Outputs

| Signal            | Width  | Description                                |
|-------------------|--------|--------------------------------------------|
| `o_proc_detected` | 1      | Detection flag output (1 = sequence found) |
| `o_locked`        | 1      | Lock status output (1 = tracking active)   |

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

On the rising edge of the clock, when the global enable is active **before** the pipeline, a window of `NS_FAW` samples must be extracted from both `i_data_i` and `i_data_q` starting at position `i_proc_pos`. These samples must be stored in internal registers.

### FSM-Based Detection Logic

A finite state machine (FSM) controls the operation of the module and manages detection locking. It contains two states:

- `ST_DETECT_SEQUENCE`: Initial scanning mode. In this state:
  - The `cross_correlation` mode is forced to 0.
  - `o_locked` output is low.
  - If detection (`o_proc_detected`) is asserted and the mode is valid (`o_aware_mode`), the FSM transitions to `ST_DETECT_PROC`.

- `ST_DETECT_PROC`: Tracking mode. In this state:
  - The module monitors correlation energy for continued detection.
  - A cycle counter counts up to the detection window size.
  - A separate counter increments if detection fails at the end of a window.
  - If detection fails and the undetected counter reaches the configured threshold (`i_static_unlock_threshold`), the FSM transitions back to `ST_DETECT_SEQUENCE`.

The `o_locked` output is high when in the `ST_DETECT_PROC` state and detection is being successfully confirmed.

### Counters

- **Sequence Count**: Tracks the number of cycles in a detection processing window.
- **Undetected Count**: Tracks how many consecutive processing windows failed to detect the sequence.

Both counters must reset when FSM transitions states or when `rst_async_n` is low. The bit-width of these counters must be sufficient to count up to 58 processing windows (based on the reference document `words_counting.md`).

### Cross-Correlation Output Processing

The output energy from the `cross_correlation` module must be compared against an internal threshold. The decision logic varies based on FSM state:

- In `ST_DETECT_SEQUENCE`, detection output is only used to trigger FSM state change.
- In `ST_DETECT_PROC`, detection success resets the undetected counter and maintains lock. Failure increments the counter.

The result is registered and forwarded to `o_proc_detected`.