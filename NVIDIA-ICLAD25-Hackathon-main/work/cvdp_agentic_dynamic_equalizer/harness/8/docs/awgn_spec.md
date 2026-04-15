# AWGN Specification

## Overview
The `awgn` module selects Additive White Gaussian Noise (AWGN) values to simulate the effect of random noise on a signal — specifically, noise that follows a Gaussian (normal) distribution and has constant power across all frequencies (white noise).

The noise values are stored in a lookup table (LUT), then the selected AWGN value is multiplied by a scale factor, truncated, and added to the original input signal.

## Interface

### Signals Table
| Signal        | In/Out | Width | Description                          |
|---------------|--------|-------|--------------------------------------|
| noise_index   | Input  | 4     | Index for pseudo-random noise        |
| signal_in     | Input  | 16    | Input signal (Q2.13)                 |
| noise_scale   | Input  | 16    | Noise gain scaling factor (Q2.13)    |
| signal_out    | Output | 16    | Output signal (Q2.13)                |

### Parameters Table
| Parameter   | Value | Description                   |
|-------------|-------|-------------------------------|
| DATA_WIDTH  | 16    | Bit width of the data         |
| LUT_SIZE    | 16    | Size of LUT with AWGN data    |