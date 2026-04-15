# Equalizer Top Specification

## Overview
The `equalizer_top` module instantiates the `awgn` blocks to add noise to the input data signals and connects the resulting noisy signals to the `dynamic_equalizer` module.

## Interface

### Signals Table
| Signal        | In/Out | Width | Description                          |
|---------------|--------|-------|--------------------------------------|
| clk           | Input  | 1     | System clock                         |
| rst_n         | Input  | 1     | Asynchronous active-low reset        |
| noise_index   | Input  | 4     | Index for pseudo-random noise        |
| noise_scale   | Input  | 16    | Noise gain scaling factor (Q2.13)    |
| data_in_real  | Input  | 16    | Real part of the input signal        |
| data_in_imag  | Input  | 16    | Imaginary part of the input signal   |
| data_out_real | Output | 16    | Real part of the output signal       |
| data_out_imag | Output | 16    | Imaginary part of the output signal  |

### Parameters Table
| Parameter   | Value | Description                   |
|-------------|-------|-------------------------------|
| TAP_NUM     | 7     | Number of taps of the filters |
| DATA_WIDTH  | 16    | Bit width of the data         |
| COEFF_WIDTH | 16    | Bit width of the coefficients |
| MU          | 15    | Learning rate                 |
| LUT_SIZE    | 16    | Size of LUT with AWGN data    |