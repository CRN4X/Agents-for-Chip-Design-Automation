## Overview

The `shift_register` module captures a stream of data samples into an internal register array. When a new sample is loaded (when the `load` signal is asserted), the module inserts the new sample at the beginning of the register array (index 0) and shifts the previous samples down the chain. The module also provides a valid flag (`data_out_val`) that indicates when new data has been loaded into the register array.

---

## Parameters

- **TAPS**   
  **Description:** Specifies the number of storage elements (or "taps") in the shift register. 
  **Default Value:** 32

- **DATA_WIDTH**  
  **Description:** Specifies the bit width of each data sample stored in the shift register.  
  **Default Value:** 16

---

## Interface

### Interface Table

| Signal Name    | Direction | Width                                   | Description                                                                                                              |
|----------------|-----------|-----------------------------------------|--------------------------------------------------------------------------------------------------------------------------|
| `clk`          | Input     | 1                                       | Clock signal. The module updates its registers on the rising edge of this clock.                                         |
| `arst_n`       | Input     | 1                                       | Active-low asynchronous reset. When low, all stored samples are reset to 0.                                              |
| `load`         | Input     | 1                                       | Load enable signal. When high, the module loads a new sample and shifts the existing data.                               |
| `new_sample`   | Input     | `DATA_WIDTH` bits                       | The new data sample to be inserted into the shift register at index 0 when `load` is asserted.                           |
| `data_out`     | Output    | Array of `DATA_WIDTH` bits, size `TAPS` | Current content of the shift register; `data_out[0]` is the most recent sample, `data_out[TAPS-1]` is the oldest sample. |
| `data_out_val` | Output    | 1                                       | Valid flag that is asserted for one clock cycle when new data is loaded into the shift register.                         |


---

## Internal Operation

1. **Asynchronous Reset:**  
   - When `arst_n` is deasserted (set to 0), all internal register elements are reset to 0 and the valid flag (`data_out_val`) is cleared.

2. **Loading a New Sample:**  
   - On the rising edge of the `clk`, if the `load` signal is asserted:
     - The new sample from `new_sample` is loaded into the first register (`reg_array[0]`).
     - All previous samples in the register array are shifted down by one index.
     - The valid flag (`data_out_val`) is set to `1` for one clock cycle to indicate that new data is available.
  
3. **No Load Condition:**  
   - When `load` is not asserted, the internal registers retain their current values, and the valid flag remains at 0.

4. **Output Assignment:**  
   - The internal register array (`reg_array`) is continuously assigned to the output array (`data_out`), so the latest sample history is always available at the module outputs.