# BCD to Excess-3 Converter Specification Document

## Introduction

The `bcd_to_excess_3` module is a simple combinational logic circuit that converts a 4-bit Binary-Coded Decimal (BCD) input into its corresponding Excess-3 encoded output. It includes built-in validation and error indication for out-of-range inputs (i.e., values greater than 9). This module is useful in digital systems where BCD-to-Excess-3 encoding is required for arithmetic or display logic.

---

## Conversion Overview

**Excess-3** is a binary-coded decimal system that represents decimal digits by adding 3 to their standard BCD representation. This is useful in some arithmetic units and display logic (e.g., early digital calculators).

The logic flow for converting BCD to Excess-3 is straightforward:

- For valid BCD values (0 to 9), the output is the input value plus 3.
- For invalid BCD values (10 to 15), the output is set to 0, and error flags are triggered.

---

## Example

| BCD Input (Decimal) | Binary BCD | Excess-3 Output | Binary Excess-3 | `valid` | `error` |
|---------------------|------------|------------------|------------------|---------|----------|
| 0                   | 0000       | 3                | 0011             | 1       | 0        |
| 1                   | 0001       | 4                | 0100             | 1       | 0        |
| 9                   | 1001       | 12               | 1100             | 1       | 0        |
| 10 (Invalid)        | 1010       | 0                | 0000             | 0       | 1        |
| 15 (Invalid)        | 1111       | 0                | 0000             | 0       | 1        |

---

## Module Interface

```Verilog
module bcd_to_excess_3 (
    input  [3:0] bcd,         
    output reg [3:0] excess3,  
    output reg error,         
    output reg valid          
);
```
## Port Description

| Port Name | Direction | Width  | Description                                      |
|-----------|-----------|--------|--------------------------------------------------|
| `bcd`     | Input     | 4 bits | BCD value to be converted (0–9 valid range).     |
| `excess3` | Output    | 4 bits | Excess-3 encoded output (`bcd + 3` if valid).    |
| `error`   | Output    | 1 bit  | High if BCD input is invalid (not 0–9).          |
| `valid`   | Output    | 1 bit  | High if BCD input is valid.                      |

---

## Internal Architecture

The internal logic uses a **combinational `always @(*)` block** with a `case` statement to map BCD input values (0 to 9) directly to their corresponding Excess-3 outputs.

### If `bcd` is between 0 and 9:
- `excess3` is assigned the value `bcd + 3`.
- `valid` is set to `1`, and `error` is set to `0`.

### If `bcd` is outside this range:
- `excess3` is set to `0`.
- `valid` is set to `0`, and `error` is set to `1`.

The design is purely combinational, producing outputs immediately in response to input changes.

---

## Timing and Latency

- This module is **fully combinational** and has **zero-cycle latency**.
- Output signals (`excess3`, `valid`, and `error`) change immediately in response to changes in the input `bcd`.
- **No clock** or **reset** is required.
- **No pipelining** or **state machine** is used.

