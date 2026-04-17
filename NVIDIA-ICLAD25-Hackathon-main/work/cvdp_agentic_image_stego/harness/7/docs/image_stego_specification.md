# Image Steganography RTL Specification

## Introduction

The `image_stego` module is a configurable Verilog RTL design that performs image-based steganography — the practice of hiding secret information within digital images. The module supports both **data embedding** and **data extraction** operations, along with additional image manipulation modes such as **inversion**, **XOR masking**, **saturation addition**, and **bit rotation**.

This design is parameterized for flexibility and can handle images of varying dimensions and embedding depths, making it suitable for both simulation and practical applications.

---

## Parameter Definitions

- **`row` (default = 2):** Defines the number of rows in the input image.
- **`col` (default = 2):** Defines the number of columns in the input image.
- **`max_bpp` (default = 8):** Represents the maximum number of bits per pixel that can be embedded or extracted.
- **`KEY_WIDTH` (default = 8):** Specifies the bit width of the secret key used in various transformation modes.
- **`CNT_WIDTH` (default = 16):** Indicates the width of the cycle counter used to measure how many clock cycles the operation took.

The total number of pixels processed is equal to `row * col`.

---

## Module Interface

```verilog
module image_stego #(
  parameter row = 2,
  parameter col = 2,
  parameter max_bpp = 8,
  parameter KEY_WIDTH = 8,
  parameter CNT_WIDTH = 16
)(
  input clk,
  input rst,
  input start,
  input [2:0] mode,
  input [(row*col*8)-1:0] img_in,
  input [(row*col*max_bpp)-1:0] data_in,
  input [2:0] bpp,
  input [KEY_WIDTH-1:0] key,
  output reg [(row*col*8)-1:0] img_out,
  output reg [(row*col*max_bpp)-1:0] data_out,
  output reg busy,
  output reg done,
  output reg [CNT_WIDTH-1:0] cycle_count
);
```

---

## Signal Descriptions

### Inputs

- **clk**: `1 bit` — Main clock signal that synchronizes internal operations.
- **rst**: `1 bit` — Active-high asynchronous reset. Resets the internal state and all outputs.
- **start**: `1 bit` — Start signal to initiate the image processing operation.
- **mode**: `3 bits` — Selects the operational mode. Determines whether to embed, extract, or transform the image.
- **img_in**: `(row * col * 8) bits` — Flattened grayscale image data. Each pixel occupies 8 bits.
- **data_in**: `(row * col * max_bpp) bits` — Secret data to be embedded. The width supports maximum bpp configuration.
- **bpp**: `3 bits` — Number of bits per pixel to embed or extract. Ranges from 0 to 6.
- **key**: `KEY_WIDTH bits` — Secret key used for masking, addition, or rotation. Typically 8 bits wide.

### Outputs

- **img_out**: `(row * col * 8) bits` — Output image after transformation or data embedding/extraction.
- **data_out**: `(row * col * max_bpp) bits` — Output data (only valid in extract mode).
- **busy**: `1 bit` — High when the module is actively processing the image.
- **done**: `1 bit` — Pulses high for one cycle when processing completes.
- **cycle_count**: `CNT_WIDTH bits` — Tracks the number of processing cycles. Useful for performance evaluation.

---

## Supported Operational Modes

The behavior of the module is determined by the `mode` signal. It supports the following modes:

- **Mode 0 (Embed)**:
  - Secret data from `data_in` is embedded into the least significant bits of `img_in` pixels.
  - The number of bits embedded per pixel is defined by `bpp`.
  - The `img_out` contains the modified image with embedded data.
  - The `data_out` is cleared to zero.

- **Mode 1 (Extract)**:
  - Extracts the least significant `bpp` bits from each 8-bit pixel in `img_in`.
  - These extracted bits are right-aligned and stored in `data_out`.
  - The `img_out` is a direct copy of the `img_in`.

- **Mode 2 (Invert)**:
  - Each 8-bit pixel is inverted bitwise.
  - The output image appears as a negative of the original.
  - The `data_out` remains zeroed.

- **Mode 3 (XOR with Key)**:
  - Performs a bitwise XOR between each pixel in `img_in` and the provided `key`.
  - The result is output in `img_out`.
  - The `data_out` is set to zero.

- **Mode 4 (Saturated Add with Key)**:
  - Each pixel is added to the key with saturation logic applied (max value = 255).
  - This avoids wrap-around in pixel values.
  - Only `img_out` is updated.

- **Mode 5 (Rotate Left by Key)**:
  - Each 8-bit pixel is rotated left by the lower 3 bits of `key`.
  - This transforms the pixel data in a reversible way.
  - `data_out` is cleared.

- **Other Values**:
  - For undefined mode values, the `img_out` mirrors the input and `data_out` is zeroed.

---

## Processing Workflow

The module operates using a simple finite state machine (FSM) with three states:

1. **S_IDLE**:
   - Waits for `start` signal.
   - Clears all status and output signals.

2. **S_PROC**:
   - Iterates over each pixel (total `row * col` iterations).
   - Applies the selected mode's logic on each pixel.
   - Updates `cycle_count` and progresses until the last pixel.

3. **S_DONE**:
   - Signals completion by asserting `done`.
   - Returns to `S_IDLE` once `start` is deasserted.

The FSM ensures deterministic behavior and handles one pixel per clock cycle, allowing the total processing duration to be easily predicted.

---

## Summary

This module offers a robust framework for grayscale image steganography, supporting configurable pixel dimensions, flexible data embedding width, and several useful image transformation modes. It is cycle-efficient and fully parameterized, making it suitable for prototyping, FPGA implementation, or even as part of a secure communication pipeline.