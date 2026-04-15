# RTL Specification Document for UART-to-AXIS Receiver

**Module Name:** `uart_rx_to_axis`  
**Description:**  
This module converts a serial UART input into a parallel data stream presented on an AXI-Stream interface. It supports configurable clock frequency, UART bit rate, word width, optional parity (none, odd, or even), and a configurable number of stop bits. A finite state machine (FSM) detects and synchronizes the UART frame—comprising a start bit, data bits, an optional parity bit, and stop bit(s)—to reconstruct the parallel data. The output is provided in standard AXI-Stream format with a valid strobe and error flag.

---

## 1. Module Overview

The `uart_rx_to_axis` module is designed to:
- Receive a serial UART stream on the `RX` input.
- Detect the start bit and sample the incoming bits based on the UART timing derived from the clock frequency.
- Reconstruct parallel data from the serial input and output the 8-bit data word on the AXI-Stream interface.
- Optionally verify parity (odd or even) and flag any parity errors via the `tuser` signal.
- Assert the data valid signal (`tvalid`) when a complete frame has been received.
- Support configurable stop bits and handle both correct and error conditions.

---

## 2. Parameter Definitions

- **CLK_FREQ (parameter):**  
  Specifies the clock frequency in MHz.  
  **Default:** 100 MHz.

- **BIT_RATE (parameter):**  
  Specifies the UART reception rate in bits per second.  
  **Default:** 115200 bps.

- **BIT_PER_WORD (parameter):**  
  Specifies the number of data bits to be reconstructed from the UART frame.  
  **Default:** 8 bits.

- **PARITY_BIT (parameter):**  
  Selects the parity mode:  
  - **0:** No parity.  
  - **1:** Odd parity.  
  - **2:** Even parity.  
  **Default:** 0.

- **STOP_BITS_NUM (parameter):**  
  Defines the number of stop bits to be expected. Acceptable values are 1 or 2.  
  **Default:** 1.

---

## 3. Module Interface

### 3.1 Inputs

- **aclk:**  
  System clock input that drives the receiver logic.

- **aresetn:**  
  Active low asynchronous reset signal.

- **RX:**  
  Serial UART input signal carrying the UART frame. The line is idle high.

### 3.2 Outputs

- **tdata:**  
  Parallel data output reconstructed from the UART frame.  
  Width is defined by BIT_PER_WORD (8 bits by default).

- **tuser:**  
  A sideband flag that indicates parity error when parity checking is enabled.  
  If no error is detected (or parity is disabled), this signal is low.

- **tvalid:**  
  Asserted when a complete and valid data word is available on `tdata`.

---

## 4. Internal Architecture

### 4.1 State Machine

The module incorporates a finite state machine (FSM) that processes the incoming UART stream. The defined states are as follows:

- **IDLE:**  
  The receiver remains in this state while waiting for the start bit. The `RX` line must be idle (logic high) in this state.

- **START:**  
  Upon detecting a falling edge on the `RX` line (indicating the start bit), the FSM moves to this state and samples the start bit after a half-bit period delay to center-align the signal.

- **DATA:**  
  The FSM transitions to this state after the start bit. A shift register captures the data bits in sequence. A bit counter tracks the number of data bits sampled.

- **PARITY:**  
  If parity checking is enabled (PARITY_BIT ≠ 0), the FSM samples the parity bit in this state. The expected parity is computed from the received data bits and compared with the sampled bit.

- **STOP1:**  
  The first stop bit is sampled in this state. It is expected to be at logic high.

- **STOP2:**  
  If a second stop bit is expected (when STOP_BITS_NUM = 2), the FSM samples it in this state, again expecting a logic high.

- **OUT_RDY:**  
  After receiving and validating the frame (including parity and stop bit checks), the FSM enters this state and asserts `tvalid` along with the reconstructed data on `tdata`. It then returns to IDLE for the next frame.

### 4.2 Clock and Timing

- **Cycle_per_Period Calculation:**  
  The number of clock cycles corresponding to one UART bit period is computed using the following equation:

  ```
  Cycle_per_Period = (CLK_FREQ * 1,000,000) / BIT_RATE
  ```

  This value is used by an internal clock counter to measure bit intervals accurately.

- **Clock Counter:**  
  A counter (`Clk_Count`) is enabled when required by the current state. Once it reaches `(Cycle_per_Period - 1)`, it resets, signaling that one bit period has elapsed.

### 4.3 Data Handling and Parity Calculation

- **Data Sampling:**  
  During the DATA state, incoming serial data bits are sequentially sampled and shifted into a register (`Data_Shift_Reg`) using a right-shift mechanism. This ensures the reconstructed byte is in the correct order (LSB first received ends up at the LSB of the word).

- **Parity Checking:**  
  - When **PARITY_BIT = 0**, the parity check is bypassed.  
  - When **PARITY_BIT = 1** (odd parity), the receiver computes the XOR of all received data bits (even parity) and then inverts the result. This computed parity is compared with the sampled parity bit.  
  - When **PARITY_BIT = 2** (even parity), the receiver directly computes the XOR of the data bits and compares it with the sampled parity bit.  
  Any discrepancy is flagged by setting the `tuser` signal to indicate a parity error.

### 4.4 Data Bit Counter

A counter (`Bit_Count`) tracks the data bits received. It is incremented with each completed bit period while in the DATA state. Once the counter reaches `BIT_PER_WORD - 1` (i.e., all data bits have been received), the FSM transitions to either the PARITY state (if enabled) or the STOP state.

### 4.5 AXI-Stream Output Generation

- **tdata Update:**  
  After a complete UART frame is received and processed, the contents of the data shift register are presented on the `tdata` output.

- **tuser Signal:**  
  Reflects the result of the parity check. It is asserted if a parity error is detected; otherwise, it remains deasserted.

- **tvalid Signal:**  
  The receiver asserts `tvalid` during the OUT_RDY state, indicating that a valid data word is ready on `tdata`.

---

## 5. Summary

The `uart_rx_to_axis` module converts a serial UART stream to a parallel AXI-Stream data format. It utilizes a finite state machine to detect and sample the start bit, data bits, optional parity bit, and stop bit(s). The module supports configurable timing based on the clock frequency and UART bit rate and can optionally detect parity errors. Its AXI-Stream output provides the reconstructed data word (tdata), a valid flag (tvalid), and a parity error flag (tuser) to ensure reliable communication between a UART-based source and an AXI-Stream interface. This flexibility and configurability enable seamless integration into a variety of systems that require UART reception with AXI-Stream connectivity.

---