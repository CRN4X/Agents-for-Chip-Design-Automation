# **JPEG Run-Length Encoder Specification Document**

## **1. Overview**

This document describes the design and function of a JPEG-compliant run-length encoder that processes 12-bit quantized DCT coefficients from 8x8 image blocks. The encoder operates in a pipelined fashion and produces output triples of (Run-Length, Size, Amplitude), conforming to JPEG's entropy encoding requirements. 

The architecture features a dedicated initial stage for coefficient analysis and four subsequent zero-run suppression stages. This structured pipeline reduces redundancy in AC coefficient sequences and simplifies downstream Huffman encoding.


## **2. Top-Level Module: `jpeg_runlength_enc`**

### **Function**
The `jpeg_runlength_enc` module manages the full pipeline, receiving serialized DCT coefficients and outputting encoded data along with flags indicating output validity and DC term presence.

It connects five submodules in a sequential pipeline. The first submodule (`jpeg_runlength_stage1`) performs coefficient classification and initial encoding. The outputs of this stage — namely the encoded run-length, size category, amplitude, data-valid flag, and DC-term flag — are then passed through four identical suppression stages (`jpeg_runlength_rzs`). Each suppression stage refines the run-length output by collapsing sequences of maximum-length zero blocks, a common pattern in JPEG AC coefficients.

All submodules operate synchronously under the same clock, reset, and enable signals. The `dstrb_in` signal is used only by the first stage to detect the start of a new block. The final stage outputs the final encoded (R, S, A) values, as well as the validity and DC term indicators.

### **IO Ports**

| Port Name     | Direction | Width | Description                                                              |
|---------------|-----------|-------|--------------------------------------------------------------------------|
| `clk_in`      | input     | 1     | System clock, positive edge triggered.                                   |
| `reset_in`    | input     | 1     | Synchronous active-high reset.                                           |
| `enable_in`   | input     | 1     | Clock enable for gated operation.                                        |
| `dstrb_in`    | input     | 1     | Data strobe to initiate encoding of a new 8x8 block.                     |
| `din_in`      | input     | 12    | Signed 12-bit DCT coefficient input.                                     |
| `rlen_out`    | output    | 4     | Encoded run-length of zeros preceding a non-zero coefficient.            |
| `size_out`    | output    | 4     | Size category representing bit width needed to encode the amplitude.     |
| `amp_out`     | output    | 12    | Adjusted coefficient amplitude.                                          |
| `douten_out`  | output    | 1     | Data output valid signal.                                                |
| `bstart_out`  | output    | 1     | High when output corresponds to the DC coefficient of a new block.       |


## **3. Submodule Descriptions**

### **3.1 Coefficient Analysis Stage (`jpeg_runlength_stage1`)**

#### **Function**
This module identifies and encodes the DC and AC coefficients of a JPEG block. It uses the `dstrb_in` signal to detect the start of a block and to classify the first coefficient as the DC term.

- For the **DC coefficient** (first input after `dstrb_in` is high), it outputs a zero run-length and calculates the size category based on the number of bits required to encode the absolute value of the coefficient. The coefficient is also amplitude-adjusted to match JPEG encoding conventions, preserving the sign and offsetting the value as required.

- For **AC coefficients**, the module tracks sequences of zero-valued inputs. When a non-zero coefficient is detected, it emits the count of preceding zeros as the run-length and calculates the size and amplitude of the current coefficient. If 15 consecutive zeros are encountered, the module emits a special run-length code and resets the count. It also detects the end of block condition when the final coefficient is received and emits an End-of-Block marker if the value is zero.

The output includes the encoded run-length, size, and amplitude fields, a flag indicating data validity, and a flag identifying the DC term.

#### **Ports**

| Port Name     | Direction | Width | Description                                                          |
|---------------|-----------|-------|----------------------------------------------------------------------|
| `clk_in`      | input     | 1     | System clock.                                                        |
| `reset_in`    | input     | 1     | Synchronous reset.                                                   |
| `enable_in`   | input     | 1     | Clock enable.                                                        |
| `go_in`       | input     | 1     | Indicates start of a new block.                                      |
| `din_in`      | input     | 12    | DCT coefficient input.                                               |
| `rlen_out`    | output    | 4     | Run-length of zeros before a non-zero coefficient.                   |
| `size_out`    | output    | 4     | Bit size needed to represent the coefficient.                        |
| `amp_out`     | output    | 12    | JPEG-compliant adjusted amplitude.                                   |
| `den_out`     | output    | 1     | Output valid indicator.                                              |
| `dcterm_out`  | output    | 1     | High when output is the DC coefficient.                              |



### **3.2 Zero-Run Suppression Stage (`jpeg_runlength_rzs`)**

#### **Function**
This module filters out redundant zero-block outputs (e.g., `(15, 0)` pairs) which frequently appear in JPEG AC data. Each instance of this module receives encoded data from a previous stage and decides whether to pass it on or suppress it.

- When a `(15, 0)` encoded value is received (meaning 15 consecutive zeros), it may suppress this value if it is part of a longer zero run.
- If a non-zero coefficient follows one or more `(15, 0)` entries, the module re-emits a single `(15, 0)` followed by the new data.
- If an End-of-Block marker `(0, 0)` is detected, it is always passed through to indicate block completion.

Each stage independently maintains suppression state, which allows efficient filtering of long runs in a distributed and pipelined fashion.

These stages collectively improve compression efficiency by minimizing redundant entries and reducing the size of the output stream.

#### **Ports**

| Port Name     | Direction | Width | Description                                                           |
|---------------|-----------|-------|-----------------------------------------------------------------------|
| `clk_in`      | input     | 1     | System clock.                                                         |
| `reset_in`    | input     | 1     | Synchronous reset.                                                    |
| `enable_in`   | input     | 1     | Clock enable.                                                         |
| `rlen_in`     | input     | 4     | Input run-length.                                                     |
| `size_in`     | input     | 4     | Input size category.                                                  |
| `amp_in`      | input     | 12    | Input amplitude.                                                      |
| `den_in`      | input     | 1     | Input data valid signal.                                              |
| `dc_in`       | input     | 1     | Input flag: high if DC coefficient.                                   |
| `rlen_out`    | output    | 4     | Filtered run-length output.                                           |
| `size_out`    | output    | 4     | Filtered size output.                                                 |
| `amp_out`     | output    | 12    | Filtered amplitude output.                                            |
| `den_out`     | output    | 1     | Output valid flag.                                                    |
| `dc_out`      | output    | 1     | Output DC flag.                                                       |



## **4. Pipeline and Latency Characteristics**

The encoder operates as a 5-stage synchronous pipeline:
- Stage 1: Coefficient analysis
- Stages 2–5: Zero-run suppression

With continuous valid input and `enable_in` asserted, the module produces one encoded output every cycle after a pipeline fill latency of 5 cycles.

- **Latency**: 5 clock cycles from `din_in` to `rlen_out/size_out/amp_out`

