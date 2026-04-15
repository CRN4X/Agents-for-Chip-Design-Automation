# Polyphase Decimator Module

The `poly_decimator` module takes an input sample stream and produces one decimated output sample every *M* input samples. Instead of generating multiple outputs per input sample (as in interpolation), the decimator collects a full window of samples, decomposes the FIR filtering operation into *M* polyphase branches, and then sums the branch outputs to generate a single filtered, decimated sample. Each branch computes a partial product using a subset of the input window, and an adder tree combines the branch results to form the final output.

---

## Parameters

- **M**  
  **Decimation factor.**  
  Specifies that one output sample is generated for every *M* input samples.  
  **Default Value:** 4

- **TAPS**    
  Defines the length of each FIR sub-filter that computes one partial dot–product in every branch.  
  **Default Value:** 8

- **COEFF_WIDTH**
  Width of the filter coefficients used in the multiplication with input samples.  
  **Default Value:** 16

- **DATA_WIDTH**   
  Bit width of the input samples that are filtered.  
  **Default Value:** 16

- **ACC_WIDTH**    
  The word width computed as:
  
  **ACC_WIDTH = DATA_WIDTH + COEFF_WIDTH + $clog2(TAPS)**

- **TOTAL_TAPS**  
  Total number of stored samples. 
  Defined as: **TOTAL_TAPS = M * TAPS**

---

## Interface

| **Signal Name** | **Direction** | **Width / Type**             | **Description**                          |
|-----------------|---------------|------------------------------|------------------------------------------|
| `clk`           | Input         | 1                            | Clock signal.                            |
| `arst_n`        | Input         | 1                            | Active-low asynchronous reset.           |
| `in_sample`     | Input         | `DATA_WIDTH` bits            | The input sample stream to be decimated. |
| `in_valid`      | Input         | 1                            | Indicates that `in_sample` is valid.     |
| `in_ready`      | Output        | 1                            | Ready to accept a new input sample.      |
| `out_sample`    | Output        | `ACC_WIDTH + $clog2(M)` bits | The decimated output sample.             |
| `out_valid`     | Output        | 1                            | Indicates that `out_sample` is valid.    |


---

## Internal Operation

The polyphase decimator should operate in the following steps:

1. **Input Storage:**  
 - An input shift register (of depth **TOTAL_TAPS = M * TAPS**) captures the most recent input samples.
 - As new samples are accepted (while `in_valid` and `in_ready` are high), the register shifts its contents.
 - A sample counter keeps track of the number of samples received. When the counter reaches *M* (indicating that a complete window has been collected), filtering is triggered.

2. **Polyphase Filtering:**  
 - The shift register output is decomposed into *M* branches. Each branch extracts **TAPS** samples from the window using a stride of *M* (starting from a unique offset).
 - Each branch instantiates a `poly_filter` submodule. The branch's fixed phase (given by its index) is used to fetch the corresponding coefficients from coefficient RAM.
 - In each branch, the `poly_filter` multiplies its sample vector by the set of coefficients and computes a dot–product, outputting a partial result along with a valid signal.

3. **Result Summation and Output:**  
 - A reduction is performed to ensure that all the *M* branches have produced valid results.
 - An adder tree will collect the *M* branch outputs, summing them to form the final decimated output sample.
 - The final sample is registered and presented on the `out_sample` output, while `out_valid` is asserted to indicate its validity.
 - The FSM controlling the decimator will be operating in two primary states:
   - **ACCUMULATE:** Continuously accepts input samples, incrementing the sample counter until *M* samples are collected.
   - **OUTPUT:** Once a complete window is received and all branch outputs are valid, the filtered output is computed, and the decimated sample is released. The counter is reset afterwards.

---

## Submodule Integration

### Shift Register

- **Purpose:**  
Stores the most recent **TOTAL_TAPS** input samples so that each decimation window is complete.
- **Integration:**  
The instance `u_shift_reg_decim` should be implemented as a standard shift register whose depth is parameterized by **TOTAL_TAPS**. It provides an array output (`shift_data`) and a corresponding valid signal (`shift_data_val`).

### Polyphase Filter

- **Purpose:**  
Each `poly_filter` submodule instantiated performs filtering on one polyphase branch. It registers the branch's sample vector, fetches corresponding coefficients using a computed address (based on its phase), multiplies the samples by the coefficients, and sums the products.
- **Integration:**  
A generate block should be used to instantiate *M* branches, each with:
- A dedicated sub-array (`branch_samples`) of **TAPS** samples extracted from the shift register.
- A fixed phase number corresponding to its branch index (used to fetch the proper coefficient set).
- An output (`branch_out`) and a valid flag (`branch_valid`).

### Adder Tree

- **Purpose:**  
Combines the outputs from the *M* polyphase branches to produce a single decimated output sample.
- **Integration:**  
The `adder_tree` module is shared across the design. It accepts the vector of branch outputs and performs a hierarchical sum (with the output width growing by `$clog2(M)` bits) to produce the final filtered result.

