# Swizzler Specification Document

## Introduction

The Swizzler module is a configurable hardware component designed to perform lane remapping (swizzling) on a multi-lane data bus. It allows for flexible data routing by rearranging the input data lanes according to an encoded swizzle map. This version of the Swizzler adds advanced features including an operation mode input for additional control, invalid mapping detection, a three-stage pipeline with bit reversal processing, and optional parity checking and output registering.

## Functional Overview

1. **Data Unpacking:**  
   The flat input bus (`data_in`) is partitioned into individual data lanes. Each lane is extracted based on the defined data width.

2. **Swizzle Map Unpacking:**  
   The encoded flat swizzle map (`swizzle_map_flat`) is converted into an array of mapping values. The width of each element is defined as `$clog2(NUM_LANES)+1`, which provides extra bits for error detection.

3. **Invalid Mapping Detection:**  
   Each element of the swizzle map is compared against `NUM_LANES` to detect invalid mapping values. If any element is out of the valid range, an invalid mapping flag is raised and later captured by the pipeline.

4. **Lane Remapping:**  
   In normal operation, the module remaps the input lanes based on the swizzle map. When the `bypass` signal is asserted, the input lanes pass through unchanged. The lower bits of each mapping element are used as the valid index for lane selection.

5. **Pipeline Stage 1:**  
   The remapped (or bypassed) lanes are captured into a set of registers. This stage creates a buffered version of the swizzled lanes that can be further processed.

6. **Pipeline Stage 2:**  
   The current `operation_mode` is captured into a register along with the invalid mapping detection signal. This stage isolates control and error status information before final processing.

7. **Bit Reversal:**  
   A bit reversal function processes each lane. In the final pipeline stage, the bits of each captured lane are reversed to produce the final output data.

8. **Pipeline Stage 3:**  
   The bit-reversed lanes are stored in a final set of registers, which are then repacked into the flat output bus (`data_out`). Depending on the configuration, the final output may be registered or directly passed through combinational logic.

9. **Optional Parity Checking:**  
   When parity checking is enabled, the module calculates the parity for each final output lane. If any lane has nonzero parity, the `parity_error` output is asserted.

10. **Invalid Mapping Error Output:**  
    The result of invalid mapping detection is propagated to the top level via the `invalid_mapping_error` output, signaling if any swizzle map element is outside the allowed range.

## Module Interface

### Parameters

- **NUM_LANES**  
  Number of data lanes in the module.

- **DATA_WIDTH**  
  Width of each data lane in bits.

- **REGISTER_OUTPUT**  
  Determines whether the final output data is registered. If set to 1, data is clocked out; if 0, data is passed combinationally.

- **ENABLE_PARITY_CHECK**  
  Enables parity error detection across the output lanes when set to 1.

- **OP_MODE_WIDTH**  
  Defines the width of the operation mode input, used for auxiliary control purposes.

- **SWIZZLE_MAP_WIDTH**  
  Calculated as `$clog2(NUM_LANES)+1`, this defines the width of each element in the swizzle map, allowing for error detection by providing an extra bit.

### Ports

- **clk (input):**  
  Clock signal for synchronizing operations.

- **rst_n (input):**  
  Active-low reset that initializes internal registers.

- **bypass (input):**  
  When asserted, the module bypasses the swizzling logic and forwards the input lanes directly to the output.

- **data_in (input):**  
  Flat data input bus with a width of `NUM_LANES * DATA_WIDTH`.

- **swizzle_map_flat (input):**  
  Flat swizzle map with a width of `NUM_LANES * SWIZZLE_MAP_WIDTH` which specifies the remapping of input lanes.

- **operation_mode (input):**  
  Input specifying the operational mode. Captured and used in pipeline stage 2 for additional control.

- **data_out (output):**  
  Flat data output bus with a width of `NUM_LANES * DATA_WIDTH` that carries the processed (remapped and bit-reversed) data.

- **parity_error (output):**  
  When parity checking is enabled, this output is asserted if any lane’s computed parity is nonzero.

- **invalid_mapping_error (output):**  
  Indicates that one or more elements in the swizzle map contained an invalid mapping (i.e., a mapping value not less than NUM_LANES).

```verilog
module swizzler #(
  parameter integer NUM_LANES           = 4,
  parameter integer DATA_WIDTH          = 8,
  parameter integer REGISTER_OUTPUT     = 0,
  parameter integer ENABLE_PARITY_CHECK = 0,
  parameter integer OP_MODE_WIDTH       = 2,
  parameter integer SWIZZLE_MAP_WIDTH   = $clog2(NUM_LANES)+1
)(
  input  wire                           clk,
  input  wire                           rst_n,
  input  wire                           bypass,
  input  wire [NUM_LANES*DATA_WIDTH-1:0]  data_in,
  input  wire [NUM_LANES*SWIZZLE_MAP_WIDTH-1:0] swizzle_map_flat,
  input  wire [OP_MODE_WIDTH-1:0]         operation_mode,
  output reg  [NUM_LANES*DATA_WIDTH-1:0]  data_out,
  output reg                            parity_error,
  output reg                            invalid_mapping_error
);
  // Internal RTL implementation as described in the functional overview.
endmodule