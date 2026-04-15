# `control_fsm` Specification

This document specifies the behavior, parameters, interface, and control logic of the `control_fsm` module. The FSM is responsible for managing control flow for data acquisition, triggering computation, and handling wait periods after processing in a sequential signal processing system.

---

## Parameter Description

| Parameter   | Description                                                                                                                                                                     | Default Value  | Constraints            |
|-------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------|------------------------|
| `NBW_WAIT`  | Bit width of the wait threshold input (`i_wait`) and internal timeout counter. Determines the maximum number of wait cycles the FSM can handle during the `PROC_WAIT_ST` state. | 32             | Must be greater than 3 |

---

## Interface Signals

| Signal           | Direction | Width        | Description                                                                 |
|------------------|-----------|--------------|-----------------------------------------------------------------------------|
| `clk`            | Input     | 1 bit        | System clock signal.                                                        |
| `rst_async_n`    | Input     | 1 bit        | Asynchronous active-low reset.                                              |
| `i_enable`       | Input     | 1 bit        | Control signal that enables FSM operation.                                  |
| `i_subsampling`  | Input     | 1 bit        | Subsampling mode selection flag. Affects the general counter preload value. |
| `o_subsampling`  | Output    | 1 bit        | Registered version of the subsampling flag, passed to downstream logic.     |
| `i_valid`        | Input     | 1 bit        | Indicates valid input data available for capture.                           |
| `o_valid`        | Output    | 1 bit        | Output indication that data is valid and actively being captured.           |
| `i_calc_valid`   | Input     | 1 bit        | Asserted when the computation process has completed successfully.           |
| `i_calc_fail`    | Input     | 1 bit        | Asserted when the computation process fails and FSM must return to idle.    |
| `i_wait`         | Input     | `NBW_WAIT`   | Value used to preload the timeout counter during `PROC_CALC_ST`.            |
| `o_start_calc`   | Output    | 1 bit        | Signal asserted for one cycle to trigger the start of the calculation step. |

---

## FSM State Transitions

The FSM progresses through five sequential states:

1. **`PROC_CONTROL_CAPTURE_ST`**  
   - Captures initial control signals (`i_wait`, `i_subsampling`).  
   - Transitions to `PROC_DATA_CAPTURE_ST` when `i_enable` is asserted.

2. **`PROC_DATA_CAPTURE_ST`**  
   - A general-purpose counter begins counting down while input data is valid.  
   - The FSM transitions to `PROC_CALC_START_ST` when this counter reaches zero.
   - This counter must be configured to count 256 valid cycles without overflow when subsampling is enabled, or 8 otherwise.

3. **`PROC_CALC_START_ST`**  
   - Triggers `o_start_calc` for one cycle to initiate processing.  
   - Then performs a countdown using the same counter used in the previous state.  
   - In this state, it must count **16 cycles** consecutively down to zero before transitioning to the next state.

4. **`PROC_CALC_ST`**  
   - Waits for either a processing success (`i_calc_valid` deasserted) or a failure (`i_calc_fail` asserted).  
   - On success, transitions to `PROC_WAIT_ST`; on failure, transitions back to `PROC_CONTROL_CAPTURE_ST`.

5. **`PROC_WAIT_ST`**  
   - A timeout counter begins counting down from a preloaded value.
   - The counter must be preloaded with the value of `i_wait`, previously captured.
   - The FSM transitions back to `PROC_CONTROL_CAPTURE_ST` when either the timeout counter reaches zero or the enable signal is deasserted.

---

## Counters

### 1. **General Purpose Counter**

- **Initialization**:  
  - When the FSM enters the data capture phase, the counter must be loaded with a preset value depending on whether subsampling is enabled.  
    - If subsampling is active, the value must be large enough to count 256 cycles.  
    - Otherwise, the counter may use a lower value: 8.

- **Counting Conditions**:  
  - The counter must count down only when input data is valid.  
  - This same counter must also be reused during the calculation start phase to perform a fixed 16-cycle countdown before transitioning.

- **Reset Behavior**:  
  - It should be reset to its preload value each time the FSM enters the data capture or calculation start states.

---

### 2. **Timeout Counter**

- **Initialization**:  
  - The timeout counter must be preloaded with the value received on `i_wait`.  
  - This preload should occur when the FSM begins the `PROC_CALC_ST` state and a valid result is confirmed.

- **Counting Conditions**:  
  - The timeout counter begins decrementing only in the `PROC_WAIT_ST` state.

- **Countdown Behavior**:  
  - The counter decrements by one on each clock cycle.  
  - Once the counter reaches zero, the FSM exits the wait state and goes to the first state.

- **Hold logic**:  
  - A temporary register must store the `i_wait` value to ensure consistent countdown behavior even if the input changes after capture.

---

## Output Behavior

### `o_start_calc`
- Asserted **for exactly one clock cycle** when entering the `PROC_CALC_START_ST` state.
- Used to trigger downstream processing logic.

### `o_valid`
- Asserted when:
  - The FSM is in the data capture state,
  - Input data is valid,
  - And the general-purpose counter has not yet reached zero.

- Indicates that the module is actively capturing valid input data.

### `o_subsampling`
- Reflects the value of `i_subsampling`, but latched at the beginning of the control sequence.

