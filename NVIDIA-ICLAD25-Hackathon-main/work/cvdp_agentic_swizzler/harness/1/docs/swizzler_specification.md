# Swizzler Specification Document

## Introduction

The **Swizzler** module is a configurable hardware component designed to perform lane remapping (swizzling) on a multi-lane data bus. This module rearranges input lanes based on an encoded swizzle map, enabling flexible data routing for optimized PCB layout and enhanced system functionality. The design supports an optional bypass mode, optional parity checking for error detection, and optional output registering for synchronous operation.

---

## Functional Overview

The Swizzler operates based on the following key functions:

1. **Data Unpacking:**  
   The flat input bus (`data_in`) containing multiple data lanes is unpacked into an array of individual lanes.

2. **Swizzle Map Unpacking:**  
   The flat encoded swizzle map (`swizzle_map_flat`) is converted into an array, where each element specifies which input lane is routed to the corresponding output lane.

3. **Lane Remapping:**  
   The module rearranges the input lanes based on the swizzle map. If the `bypass` signal is asserted, the input lanes pass through to the output unchanged.

4. **Optional Parity Checking:**  
   When enabled via the `ENABLE_PARITY_CHECK` parameter, the module computes the parity of each remapped lane and asserts a `parity_error` signal if any lane's parity is nonzero.

5. **Output Packing:**  
   The remapped lanes are repacked into a single flat output bus (`data_out`).

6. **Output Registering (Optional):**  
   If `REGISTER_OUTPUT` is enabled, the output data is registered on the rising edge of the clock (`clk`), ensuring improved timing performance and synchronization.

---

## Module Interface

The module should be defined as follows:

```verilog
module swizzler #(
    parameter integer NUM_LANES = 4,
    parameter integer DATA_WIDTH = 8,
    parameter integer REGISTER_OUTPUT = 0,
    parameter integer ENABLE_PARITY_CHECK = 0
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          bypass,
    input  wire [NUM_LANES*DATA_WIDTH-1:0] data_in,
    input  wire [NUM_LANES*$clog2(NUM_LANES)-1:0] swizzle_map_flat,
    output reg  [NUM_LANES*DATA_WIDTH-1:0] data_out,
    output reg                           parity_error
);