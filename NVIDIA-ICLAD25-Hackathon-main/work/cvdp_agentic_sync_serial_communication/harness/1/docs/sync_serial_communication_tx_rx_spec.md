
The `sync_serial_communication_tx_rx` design implements a synchronous serial transmitter (TX) and receiver (RX) for 64-bit data, along with a binary-to-Gray code conversion stage. It enables selective transmission of different portions of the 64-bit input, determined by a 3-bit control signal (`sel`).

## Interface

### Data inputs

1. **clk(1-bit)** : System clock. Design works on the Posedge of the `clk`.

2. **reset_n(1-bit)** : Active-low asynchronous reset; all internal registers reset when `reset_n` is 0.

3. **sel([2:0])**  : Selection for the TX/RX data width operation (e.g., 8, 16, 32, or 64 bits).

4. **data_in([63:0])**  : Parallel input data to be transmitted.

### Data Outputs

1. **data_out([63:0])** : Parallel output reconstructed by the RX block.

2. **done(1-bit)** : Indicates completion of receiving data from the RX block.

3. **gray_out([63:0])** : Gray-coded version of `data_out`, provided by the `binary_to_gray_conversion` module.

## Detailed Functionality

### Parallel-to-Serial Transmission

The top module instantiates `tx_block`, which takes `data_in` and serializes it based on the width selected by `sel`. 
### Serial-to-Parallel Reception

The serialized data routed to `rx_block`, which captures each incoming bit. Once it detects it has received all bits for the chosen width, it asserts `done` and outputs the parallel data on `data_out`.

### Gray Code Conversion

When `done` is asserted, the `binary_to_gray_conversion` submodule captures the final `data_out` and generates a corresponding 64-bit Gray code on `gray_out`.


## Submodule Explanation

### 1. tx_block Submodule

**Function**  
Converts a 64-bit parallel input (`data_in`) into a serial bitstream, governed by `sel`.

**Interface**  
It receives `clk`, `reset_n`, `data_in`, and `sel`, and outputs `serial_out`, `done`, and `serial_clk`.

**Operation**  

1. **Data Width Selection**
     - On each clock cycle, if `done` is high, `sel` is evaluated to determine how many bits (8/16/32/64) to shift out next.

3. **Shifting & Transmission**  
    - The chosen segment is loaded into `data_reg` and shifted right every clock cycle; the LSB goes to `serial_out`.

4. **Done Signaling**  
    - When the required bits have been sent, `bit_count` goes to 0 and `done` is asserted.

5. **Serial Clock**  
     - A gated version of `clk` (`serial_clk`) is provided to synchronize data capture in `rx_block`.


### 2. rx_block Submodule

**Function**  
Reassembles the serial bitstream into parallel form and asserts `done` once complete.

**Interface**  
It receives `clk`, `reset_n`, `data_in`, `serial_clk`, and `sel`, and outputs `done` and `data_out`.

**Operation**  

1. **Serial Capture**  
   - On each rising edge of `serial_clk`, the incoming bit is stored in register.  
   - A local register tracks how many bits have been received.

2. **Data Width Tracking**  
   - Once the expected number of bits (based on `sel`) is captured, `done` is asserted.

3. **Parallel Output**  
   - The bits are loaded into `data_out`, with zero-extension for smaller widths (8/16/32 bits).


### 3. binary_to_gray_conversion Submodule

**Function**  
Converts the parallel binary data into Gray code upon completion of the reception (`en = done`).

**Interface**  
It receives `data` as input and outputs `gray_out`.

**Operation**  
- **Combinational Conversion**  
  - The highest bit is copied directly, and each subsequent bit is computed as `data[j+1] ^ data[j]`.


## Example Usage

### Normal Operation Example

1. **Initial Conditions**  
   - `reset_n` is asserted (1), `sel` is set to select 16 bits (`3'b010`), and valid data is on `data_in`.

2. **Transmission Start**  
   - `tx_block` sees `done = 1` initially, loads the lower 16 bits of `data_in` into a register.  
   - Transmission begins, shifting out each bit on consecutive `clk` cycles.

3. **Reception**  
   - `rx_block` captures bits on each rising edge of `serial_clk`.  
   - When it has received all 16 bits, it asserts `done`.

4. **Gray Code Generation**  
   - With `done = 1`, `binary_to_gray_conversion` converts `data_out` to Gray code on `gray_out`.

### Reset Operation Example

1. **Reset Assertion**  
   - When `reset_n` is driven low (0), both `tx_block` and `rx_block` registers are cleared.

2. **Restart**  
   - Transmission and reception are halted; any ongoing operation restarts once `reset_n` is de-asserted (goes back to 1).


## Summary

- **Functionality**:  
  The `sync_serial_communication_tx_rx` module integrates a transmitter (`tx_block`), a receiver (`rx_block`), and a binary-to-Gray converter to form a complete synchronous serial communication system.

- **Transmission & Reception**:  
  Parallel data is serialized according to the bits selected by `sel`, sent out on `serial_out`, and reassembled in the receiver, which then indicates completion via the `done` signal.

- **Gray Code Output**:  
  When reception is done, the received data is transformed into Gray code for further processing or analysis.

- **Modular Design**:  
  Each block (`tx_block`, `rx_block`, `binary_to_gray_conversion`) handles a distinct function, simplifying code maintainability and reuse.