## UART Top-Level RTL Module Specification

### 1. Module Overview:
- The UART module supports asynchronous serial communication.
- Full duplex operation with independent TX and RX control.
- Configurable parameters for baud rate, parity mode, stop bits.
- Supports internal loopback for testing.

---

### 2. Top-Level Interface Specification:

#### Inputs:
- **clk**: Core clock input (10-100 MHz)
- **rstn**: Active-low asynchronous reset
- **i_rx**: Serial data input

**Control Inputs**:
- **i_baudrate [15:0]**: Baud rate configuration
- **i_parity_mode [1:0]**: Parity mode (00 - None, 01 - Odd, 11 - Even)
- **i_frame_mode**: Number of stop bits (0 - one stop bit, 1 - two stop bits)
- **i_lpbk_mode_en**: Loopback mode enable (0 - disabled, 1 - enabled)
- **i_tx_break_en**: TX break enable
- **i_tx_en**: Transmitter enable
- **i_rx_en**: Receiver enable
- **i_tx_rst**: Active-high reset for transmitter
- **i_rx_rst**: Active-high reset for receiver

**TX Data Interface Inputs**:
- **i_data [7:0]**: Data byte to transmit
- **i_data_valid**: Indicates data byte is valid for transmission

**RX Data Interface Inputs**:
- **i_ready**: Indicates readiness to read received data byte

#### Outputs:
- **o_tx**: Serial data output

**TX Data Interface Output**:
- **o_ready**: Transmitter ready status

**RX Data Interface Outputs**:
- **o_data [7:0]**: Data byte received
- **o_data_valid**: Indicates received data byte is valid

**Status Outputs**:
- **o_tx_state**: Transmitter enable state (1 - enabled, 0 - disabled)
- **o_rx_state**: Receiver enable state (1 - enabled, 0 - disabled)
- **o_rx_break**: Break frame received indicator
- **o_parity_err**: Parity error status
- **o_frame_err**: Frame error status

---

### 3. Functional Requirements:

#### Transmission:
- Transmit least significant bit first, idle state is logic high.
- Configurable 8-bit data, optional parity bit, 1 or 2 stop bits.
- Supports transmission of break frames (all zero bits).

#### Reception:
- RX samples serial data at 8x baud rate oversampling for robustness.
- Detects valid start bit transitions and stop bit errors.
- Reports frame errors (stop bit missing) and parity errors.
- Break frame reception detection (at least 9 or 10 bits of zeros).

---

### 4. Clocking and Reset:
- Core operates on a single clock domain (10-100 MHz).
- Asynchronous active-low reset input (`rstn`).
- Internal reset synchronizers for clean de-assertion.

---

### 5. Baud Rate Generation:
- Internal baud generator with 16-bit prescaler.
- Configurable through input parameter (`i_baudrate`).
- Formula:
   `Baud_div = INT((CoreClockFreq / (BaudRate × 8)) - 1)`


---

### 6. Loopback Mode:
- Internally connects TX output to RX input when enabled (`i_lpbk_mode_en`).
- Primarily intended for self-testing and diagnostics.

---

### 7. Data Interface Handshaking:
- Uses simple valid-ready handshake protocol for both TX and RX.
- Data transfer occurs only when both `valid` and `ready` signals are asserted.

---

### 8. Error Handling:
- Status flags provided for parity and frame errors.
- Sticky error flags until next byte is received.