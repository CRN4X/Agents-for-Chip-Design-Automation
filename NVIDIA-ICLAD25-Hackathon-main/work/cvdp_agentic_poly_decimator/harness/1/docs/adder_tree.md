## Adder Tree Design

The `adder_tree` module takes an array of `NUM_INPUTS` data words (each of width `DATA_WIDTH`) and computes their sum using a pipelined adder tree structure. The design is fully pipelined, meaning that at each clock cycle a new sum can be produced after the pipeline is filled.

The addition process is divided into several stages:
- **Stage 0:** The input data is registered and sign-extended to ensure proper arithmetic addition.
- **Subsequent Stages:** Each stage halves the number of elements by summing adjacent pairs. The number of stages required is calculated as `NUM_STAGES = $clog2(NUM_INPUTS)`.
- **Final Stage:** The final sum is available at the output along with a valid flag (`valid_out`) that propagates through the pipeline.

---

## Parameters

- **NUM_INPUTS**  
  **Type:** Integer  
  **Description:** Number of input data words to be summed.  
  **Default Value:** 8

- **DATA_WIDTH**  
  **Type:** Integer  
  **Description:** Bit width of each input data word.  
  **Default Value:** 32

The output width is automatically computed as `DATA_WIDTH + $clog2(NUM_INPUTS)` to accommodate the growth in bit width due to the summation of multiple inputs.

---

## Interface Table

| Signal Name | Direction | Width                                                       | Description                             |
|-------------|-----------|-------------------------------------------------------------|-----------------------------------------|
| `clk`       | Input     | 1                                                           | Clock signal                            |
| `arst_n`    | Input     | 1                                                           | Active-low asynchronous reset           |
| `valid_in`  | Input     | 1                                                           | Valid signal for the input data         |
| `data_in`   | Input     | Array of `NUM_INPUTS` elements, each `DATA_WIDTH` bits wide | Array of input data words to be summed. |
| `sum_out`   | Output    | `DATA_WIDTH + $clog2(NUM_INPUTS)` bits                      | The computed sum of the data            |
| `valid_out` | Output    | 1                                                           | Valid signal for the output sum         |


---

## Detailed Operation

### Stage 0: Input Registration
- **Function:**  
  On the rising edge of `clk`, if `valid_in` is asserted, each input word from `data_in` is registered into the first stage of the pipeline (`stage_reg[0]`).  
- **Sign Extension:**  
  Each input is sign-extended to a width of `DATA_WIDTH + $clog2(NUM_INPUTS)` bits. This ensures that when negative numbers are involved, the additions are computed correctly.
- **Valid Signal:**  
  If `valid_in` is high, `valid_stage[0]` is set to `1` to indicate that the first stage has valid data.

### Subsequent Pipeline Stages
- **Function:**  
  A generate block creates `NUM_STAGES` pipeline stages. In each stage, the number of data words is halved by adding pairs from the previous stage.  
- **Computation:**  
  For stage `s`, there are `NUM_INPUTS >> s` elements. Each element is computed as:  
  ```
  stage_reg[s][j] = stage_reg[s-1][2*j] + stage_reg[s-1][2*j+1]
  ```
- **Valid Propagation:**  
  The valid flag propagates from one stage to the next. If the previous stage's valid signal (`valid_stage[s-1]`) is high, then `valid_stage[s]` is set high after the addition.

### Final Output
- **Sum Output:**  
  The final sum is taken from `stage_reg[NUM_STAGES][0]` and assigned to `sum_out`.
- **Valid Output:**  
  The final valid signal is available on `valid_out`, which is assigned from `valid_stage[NUM_STAGES]`.