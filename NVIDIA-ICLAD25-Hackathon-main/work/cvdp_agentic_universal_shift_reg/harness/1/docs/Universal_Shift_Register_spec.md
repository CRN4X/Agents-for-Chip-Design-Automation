# Universal Shift Register Module

The `universal_shift_register` module implements a flexible and parameterized N-bit shift register with support for multiple data manipulation modes. It enables operations such as holding data, shifting left or right, rotating bits, and parallel loading, all within a single compact design. The module operates synchronously using a clock and reset signal and supports both serial and parallel data input/output.

## Parameterization
- `N` :This value determines the width of all internal data operations.Default is 8. A positive integer (≥1) that Defines the bit-width of the shift register.

## Interfaces

### Inputs
- `clk`  : The input clock signal used for synchronous operations.

- `rst`  : Asynchronous active-high reset. When asserted, clears all the output.

- `mode_sel [1:0]`  : Selects the operational mode of the register:
  - `00`: Hold
  - `01`: Shift
  - `10`: Rotate
  - `11`: Parallel Load

- `shift_dir`  : Specifies the direction for Shift and Rotate operations:
  - `0`: Right
  - `1`: Left

- `serial_in`  : Single-bit input used during Shift and Rotate operations as the bit entering the register.

- `parallel_in [N-1:0]`  : Parallel input data used during the Parallel Load operation.

### Outputs
- `q [N-1:0]`  : N-bit output representing the current value stored in the register.

- `serial_out` : Single-bit output representing the bit shifted out from the register. Its value depends on the shift direction.

## Detailed Functionality

### Reset Behavior
- When the reset input is high, the register contents are cleared. All output bits are set to zero.

### Operational Modes

#### Hold Mode (`mode_sel = 00`)
- The register retains its current value. No data is shifted, rotated, or updated.

#### Shift Mode (`mode_sel = 01`)
- Data is shifted by one bit.
- A new bit is inserted from the `serial_in` input based on the specified direction.
- The opposite end bit is shifted out through `serial_out`.

#### Rotate Mode (`mode_sel = 10`)
- Performs a circular shift of the register bits.
- The bit that is shifted out is wrapped around and inserted back at the opposite end.

#### Parallel Load Mode (`mode_sel = 11`)
- The entire register is loaded with the value from the `parallel_in` input.
- All bits in the register are updated simultaneously.

### Serial Output
- The `serial_out` output provides the bit that would be shifted out during a Shift operation.
- The bit selected for output depends on the shift direction, allowing external systems to capture outgoing serial data.

## Example Usage

### Shift Left Operation

**Inputs:**
- Mode: Shift
- Direction: Left
- Serial Input: Logic High
- Initial Register: A defined binary pattern

**Operation:**
- All bits move one position to the left.
- A new bit from `serial_in` is inserted at the least significant position.
- The most significant bit is shifted out and available at `serial_out`.

### Rotate Right Operation

**Inputs:**
- Mode: Rotate
- Direction: Right
- Initial Register: A defined binary pattern

**Operation:**
- All bits rotate one position to the right.
- The least significant bit moves to the most significant position.
- No external input is used during this operation.

### Parallel Load Operation

**Inputs:**
- Mode: Parallel Load
- Parallel Input: A specific binary value

**Operation:**
- The entire register is replaced with the value from the parallel input.

## Summary

### Functionality
- The `universal_shift_register` supports four essential register operations: hold, shift, rotate, and parallel load. Each operation is selectable via the `mode_sel` input and executes on the rising edge of the clock.

### Data Interfaces
- Accepts serial and parallel input
- Provides parallel output and serial data access

### Versatility
- The design is suitable for implementing parallel-to-serial, serial-to-parallel converters, or general-purpose shift-based logic in digital systems.

### Modular Design
- Its parameterized nature allows easy scalability for different data widths, making it reusable across a wide range of RTL applications.