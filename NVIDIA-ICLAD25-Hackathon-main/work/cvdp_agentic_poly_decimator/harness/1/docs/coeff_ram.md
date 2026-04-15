# Coefficient RAM

The `coeff_ram` module implements a simple synchronous read-only memory that stores a set of coefficients. It should be used in `polyphase filtering` to fetch the filtering coefficients

When an address is provided at the `addr` input, the module outputs the corresponding coefficient stored in its internal memory array (`mem`).

---

## Parameters

- **NUM_COEFFS**  
  - **Type:** Integer  
  - **Description:** Specifies the total number of coefficients stored in the RAM.  
  - **Default Value:** 32

- **DATA_WIDTH**  
  - **Type:** Integer  
  - **Description:** Specifies the bit width of each coefficient.  
  - **Default Value:** 16

---

## Interface Table

| Signal Name | Direction | Width                     | Description                                                 |
|-------------|-----------|---------------------------|-------------------------------------------------------------|
| `clk`       | Input     | 1                         | Clock signal.                                               |
| `addr`      | Input     | `$clog2(NUM_COEFFS)` bits | Address input used to index the coefficient memory array.   |
| `data_out`  | Output    | `DATA_WIDTH` bits         | Synchronously outputs the coefficient stored at the address |


---

## How the Module Works

1. **Memory Storage:**  
   The module contains an internal memory array `mem` that holds `NUM_COEFFS` coefficients. Each coefficient is `DATA_WIDTH` bits wide.

2. **Synchronous Read Operation:**  
   On every rising edge of the clock (`clk`), the module reads the coefficient at the address specified by `addr` and outputs it on `data_out`.

3. **No Write Capability:**  
   This module is designed as a read-only memory block. Coefficient values are typically preloaded. It should be populated with a testbench.

---


## How to Use This Module in a Polyphase Filter (poly_filter) Design

In a polyphase filter design:
- **Coefficient Arrangement:**  
  Coefficients are usually organized into groups corresponding to the filter's phases and taps. For instance, if the polyphase filter has `N` phases and `TAPS` taps per phase, the total number of coefficients is `N * TAPS`.
  
- **Address Calculation:**  
  The poly_filter computes an address to retrieve the proper coefficient for a given phase and tap index. For example, the address may be calculated as:
  ```
  addr = phase_reg * TAPS + tap_index
  ```
  
- **Integration:**  
  The poly_filter instantiates one or more `coeff_ram` modules (often within a generate loop) to supply coefficients for its multiply-accumulate operations. The coefficient retrieved from `coeff_ram` is then used to multiply against a sample from the shift register, contributing to the final filter output.