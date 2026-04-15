# RTL Specification Document for AXIS-to-UART Transmitter

**Module Name:** `axis_to_uart_tx`  
**Description:**  
This module converts parallel data received over an AXI-Stream interface into a serial UART output. It supports configurable clock frequency, UART bit rate, word width, optional parity (none, odd, or even), and a configurable number of stop bits. A finite state machine (FSM) controls the transmission process, which includes transmitting the start bit, data bits, an optional parity bit, and stop bit(s).

---

## 1. Module Overview

The `axis_to_uart_tx` module is designed to:
- Accept data on an AXI-Stream interface with handshake signals (`tdata`, `tvalid`, and `tready`).
- Convert the incoming 8-bit data (or parameterized width) into a UART serial stream.
- Implement a state machine that manages:
  - **Idle:** Waiting for valid data.
  - **Start Bit:** Transmitting a start bit (logic low).
  - **Data Bits:** Sequentially transmitting the data bits.
  - **Parity Bit:** Computing and transmitting an optional parity bit (odd or even).
  - **Stop Bit(s):** Transmitting one or two stop bits (logic high).
- Generate an output `TX` that follows the UART protocol timing based on a configurable clock frequency and bit rate.

---

## 2. Parameter Definitions

- **CLK_FREQ (parameter):**  
  Specifies the clock frequency in MHz.  
  **Default:** 100 MHz.

- **BIT_RATE (parameter):**  
  Specifies the UART transmission rate in bits per second.  
  **Default:** 115200 bps.

- **BIT_PER_WORD (parameter):**  
  Specifies the number of data bits per transmitted word.  
  **Default:** 8 bits.

- **PARITY_BIT (parameter):**  
  Selects the parity mode:  
  - **0:** No parity.  
  - **1:** Odd parity.  
  - **2:** Even parity.  
  **Default:** 0.

- **STOP_BITS_NUM (parameter):**  
  Defines the number of stop bits. Acceptable values are 1 or 2.  
  **Default:** 1.

---

## 3. Module Interface

### 3.1 Inputs

- **aclk:**  
  System clock input that drives the module.

- **aresetn:**  
  Active low asynchronous reset signal.

- **tdata:**  
  AXI-Stream data input. Width is defined by BIT_PER_WORD (8 bits by default).

- **tvalid:**  
  AXI-Stream valid signal, indicating that `tdata` is valid and ready for transmission.

### 3.2 Outputs

- **tready:**  
  Indicates that the module is ready to accept new data. Asserted when the module is idle.

- **TX:**  
  UART serial output which carries the serialized data bits according to the UART protocol.

---

## 4. Internal Architecture

### 4.1 State Machine

The module incorporates a finite state machine (FSM) for the UART transmission process. The FSM states are defined as follows:

- **IDLE:**  
  The module waits in this state until valid data is received on the AXI-Stream interface. The `tready` signal is asserted in this state.

- **START:**  
  On receiving valid data (`tvalid` high), the FSM transitions to the START state to transmit the start bit (logic low) for one bit period.

- **DATA:**  
  The FSM transmits the data bits serially. A shift register holds the incoming data and a bit counter determines which bit is currently transmitted (transmission is LSB first).

- **PARITY:**  
  If parity is enabled, the computed parity bit (odd or even) is transmitted.

- **STOP1:**  
  The first stop bit is transmitted; this is always a logic high.

- **STOP2:**  
  When two stop bits are required (configured by STOP_BITS_NUM), this state transmits the second stop bit.

### 4.2 Clock and Timing

- **Cycle_per_Period Calculation:**  
  The number of clock cycles corresponding to one UART bit period is computed using the following equation:

  ```
  Cycle_per_Period = (CLK_FREQ * 1,000,000) / BIT_RATE
  ```

  This value is used by the clock counter to generate bit period timing.

- **Clock Counter:**  
  A counter (`Clk_Count`) is enabled during transmission to count clock cycles within each bit period. When it reaches `(Cycle_per_Period - 1)`, it resets and declares that one bit period has elapsed.

### 4.3 Data Handling and Parity Calculation

- **Data Latching:**  
  Data is latched from the AXI-Stream input (`tdata`) when both `tvalid` and `tready` are asserted. The data is stored in an internal shift register (`Data`).

- **Parity Computation:**  
  Parity is computed combinationally on the data bits:
  - When **PARITY_BIT = 0**, no parity bit is generated.
  - When **PARITY_BIT = 1** (odd parity), the module computes the even parity (XOR of all bits) and then inverts it.
  - When **PARITY_BIT = 2** (even parity), the module computes the XOR of all data bits directly.

### 4.4 Data Bit Counter

A counter (`Bit_Count`) tracks the number of data bits transmitted. It increments each time a full bit period (as determined by the clock counter) elapses while in the DATA state. Upon transmitting all bits (i.e., `Bit_Count` equals `BIT_PER_WORD - 1`), the counter signals that transmission of the data bits is complete.

### 4.5 UART TX Output Generation

- **TX Register Update:**  
  The output `TX` is driven by a registered signal updated at every clock cycle. The state machine determines the value of `TX`:
  - In **IDLE**, `TX` is held high.
  - In **START**, `TX` is driven low.
  - In **DATA**, `TX` follows the value of the current data bit from the shift register.
  - In **PARITY**, `TX` outputs the computed parity.
  - In **STOP1** and **STOP2**, `TX` is held high.

- **tready Signal:**  
  The `tready` signal is asserted when the FSM is in the IDLE state, indicating that the module is prepared to accept new incoming data.

### 4.6 Next State Logic

The next state of the FSM is determined based on the following conditions:
- Availability of valid data (`tvalid`).
- Completion of a bit period (as indicated by the clock counter, `Clk_Count_Done`).
- Completion of data bit transmission (`Bit_Count_Done`).
- Parity mode selection.
- The number of configured stop bits.

**Transitions:**
- **IDLE → START:** Occurs when valid data is detected.
- **START → DATA:** Occurs after one complete bit period of the start bit.
- **DATA → PARITY or STOP1:** Occurs after all data bits are transmitted; if parity is enabled, transitions to PARITY; otherwise, directly to STOP1.
- **PARITY → STOP1:** Transitions after the parity bit period completes.
- **STOP1 → (IDLE or STOP2):** Transitions after the first stop bit period. Returns to IDLE if one stop bit is configured or moves to STOP2 if two are required.
- **STOP2 → IDLE:** Transitions after the second stop bit period.

---

## 5. Summary

The `axis_to_uart_tx` module is a configurable UART transmitter interfacing with an AXI-Stream input. It utilizes a finite state machine to serialize data by outputting a start bit, data bits, an optional parity bit, and stop bit(s) with precise timing derived from a clock counter. Data latching and parity computation are handled internally, making the design adaptable based on provided parameters. This design enables seamless integration into systems requiring UART communication with customizable timing and configuration.

---