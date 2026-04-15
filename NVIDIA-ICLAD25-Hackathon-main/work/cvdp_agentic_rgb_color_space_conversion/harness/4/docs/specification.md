# RGB to HSV/HSL/CMYK Conversion Module Specification Document

## Introduction

The **RGB to HSV/HSL/CMYK Conversion Module** is designed to convert RGB (Red, Green, Blue) color space values into HSV (Hue, Saturation, Value), HSL (Hue, Saturation, Lightness), and CMYK (Cyan, Magenta, Yellow, Black Key) color space values. This module is optimized for hardware implementation, leveraging pipelining and fixed-point arithmetic to achieve efficient and accurate conversion. The module supports 8-bit RGB input values and produces 12-bit Hue, 13-bit Saturation, 12-bit Value, 12-bit Lightness, and 16-bit fixed-point CMY outputs (fx8.8 for C, M, Y) and 8-bit Integer output for K.

## Algorithm Overview

The conversion from RGB to HSV/HSL/CMYK involves the following steps:

1. **Scale RGB Values:**  
   The 8-bit RGB values are scaled to 12-bit fixed-point representation to maintain precision during calculations.

2. **Determine Maximum and Minimum Values:**  
   The maximum (`i_max`) and minimum (`i_min`) values among the R, G, and B components are identified. These values are used to calculate the delta (`delta_i`), which is the difference between `i_max` and `i_min`.

3. **Calculate Hue (H):**  
   The Hue value is calculated based on the maximum RGB component:
   - If the maximum component is **Red**, Hue is calculated using the formula:  
     `H = 60 * ((G - B) / delta)`
   - If the maximum component is **Green**, Hue is calculated using the formula:  
     `H = 60 * ((B - R) / delta) + 120`
   - If the maximum component is **Blue**, Hue is calculated using the formula:  
     `H = 60 * ((R - G) / delta) + 240`
   - If `delta_i` is zero, Hue is set to `0`.

4. **Calculate Saturation (S):**  
   - For HSV Channel, Saturation is calculated using the formula:  
   `S = (delta / i_max)`
   - For HSL Channel, Saturation is calculated using the formula:
   If `L == 0` or `L == 1`, `S = 0`.  
   Else:  
      `S = delta_i / (1 - |2L - 1|)`.   

5. **Calculate Value (V):**  
   Value is simply the maximum RGB component:  
   `V = i_max`
   
6. **Calculate Lightness (L):**  
   - `L = (i_max + i_min) / 2`.

7. **Calculate CMYK Channels:**  
   - **Black Key (K)** is calculated as:  
     `K = 255 - i_max`
   - **Cyan (C)**, **Magenta (M)**, and **Yellow (Y)** are calculated using:  
     `C = (i_max - R) * 255 / (i_max)`  
     `M = (i_max - G) * 255 / (i_max)`  
     `Y = (i_max - B) * 255 / (i_max)`   

The module uses precomputed inverse values of `i_max`, `delta_i`, and `(1 - |2L - 1|)` stored in memory to avoid division operations, replacing them with multiplications for efficiency.


## Module Interface

The module is defined as follows:

```verilog
module rgb_color_space_conversion (
    input               clk,
    input               rst,
    
    // Memory ports to initialize (1/delta) values
    input               we,
    input       [7:0]   waddr,
    input      [24:0]   wdata,
    
    // Input data with valid.
    input               valid_in,
    input       [7:0]   r_component,
    input       [7:0]   g_component,
    input       [7:0]   b_component,

    // HSV Output values
    output reg [11:0]   hsv_channel_h,  // fx10.2 format, degree value = (hsv_channel_h)/4
    output reg [12:0]   hsv_channel_s,  // fx1.12 format, % value = (hsv_channel_s/4096)*100
    output reg [11:0]   hsv_channel_v,  // % value = (hsv_channel_v/255) * 100

    // HSL Output values
    output reg [11:0]   hsl_channel_h,  // fx10.2 format, degree value = (hsl_channel_h)/4
    output reg [12:0]   hsl_channel_s,  // fx1.12 format, % value = (hsl_channel_s/4096)*100
    output reg [11:0]   hsl_channel_l,  // % value = (hsl_channel_l/255) * 100

    // CMYK Output values
    output reg [15:0]   cmyk_channel_c,  // % value = (cmyk_channel_c/(256*255)) * 100
    output reg [15:0]   cmyk_channel_m,  // % value = (cmyk_channel_m/(256*255)) * 100
    output reg [15:0]   cmyk_channel_y,  // % value = (cmyk_channel_y/(256*255)) * 100
    output reg [7:0]    cmyk_channel_k,  // % value = (cmyk_channel_k/255) * 100

    output reg          valid_out
);
```

### Port Descriptions

- **clk:** Clock signal. All operations are synchronized to the positive edge of this signal.
- **rst:** Active-high asynchronous reset signal. When asserted, all internal registers and shift registers are initialized to their default values.
- **we:** Active-high write enable signal. Used to initialize the inverse values in the multi-port RAM.
- **waddr:** 8-bit write address signal. Specifies the memory location to be written during initialization.
- **wdata:** 25-bit write data signal. Contains the inverse values to be stored in the RAM during initialization.
- **valid_in:** Active-high input signal. Indicates that the input RGB data (`r_component`, `g_component`, `b_component`) is valid.
- **r_component:** 8-bit input signal. Represents the Red component of the RGB input.
- **g_component:** 8-bit input signal. Represents the Green component of the RGB input.
- **b_component:** 8-bit input signal. Represents the Blue component of the RGB input.
- **hsv_channel_h:** 12-bit output signal. Represents the Hue value in fixed-point format (fx10.2). The degree value is obtained by dividing the decimal value by 4.
- **hsv_channel_s:** 13-bit output signal. Represents the Saturation value in fixed-point format (fx1.12). The percentage value is obtained by multiplying the decimal value by 100 and dividing by 4096.
- **hsv_channel_v:** 12-bit output signal. Represents the Value in integer format. The percentage value is obtained by multiplying the decimal value by 100 and dividing by 255.
- **hsl_channel_h:** 12-bit output signal. Represents the Hue value in fixed-point format (fx10.2). The degree value is obtained by dividing the decimal value by 4.
- **hsl_channel_s:** 13-bit output signal. Represents the Saturation value in fixed-point format (fx1.12). The percentage value is obtained by multiplying the decimal value by 100 and dividing by 4096.
- **hsl_channel_l:** 12-bit output signal. Represents the Lightness in integer format. The percentage value is obtained by multiplying the decimal value by 100 and dividing by 255.
- **cmyk_channel_c:** 16-bit output signal. Represents the Cyan in fixed-point format (fx8.8). The percentage value is obtained by multiplying the decimal value by 100 and dividing by 256*255.
- **cmyk_channel_m:** 16-bit output signal. Represents the Magenta in fixed-point format (fx8.8). The percentage value is obtained by multiplying the decimal value by 100 and dividing by 256*255.
- **cmyk_channel_y:** 16-bit output signal. Represents the Yellow in fixed-point format (fx8.8). The percentage value is obtained by multiplying the decimal value by 100 and dividing by 256*255.
- **cmyk_channel_k:** 8-bit output signal. Represents the Black Key in integer format. The percentage value is obtained by multiplying the decimal value by 100 and dividing by 255.
- **valid_out:** Active-high output signal. Indicates that the output data (`hsv_channel_h`, `hsv_channel_s`, `hsv_channel_v`, `hsl_channel_h`, `hsl_channel_s`, `hsl_channel_l`, `cmyk_channel_c`, `cmyk_channel_m`, `cmyk_channel_y`, `cmyk_channel_k` ) is valid.

## Submodules

### 1. Multi-Port RAM
The Multi-port RAM is used to store precomputed inverse values for `i_max`, `delta_i`, and `(1 - |2L - 1|)`. It supports one write port and three independent read ports. These values are initialized using the `we`, `waddr`, and `wdata` signals. The memory is organized as follows:
- **Address Range:** 0 to 255 (8-bit address).
- **Data Width:** 25 bits (fixed-point representation of inverse values).
- The RAM write operation can occur continuously by updating the write address (`waddr`) on every clock cycle, as long as the `we` signal is asserted HIGH. Each new address and data value is written to the RAM at each clock cycle, allowing continuous memory writes.
- For read operation, when a valid address (`raddr_a`, `raddr_b`, and `raddr_c`) is set, then the corresponding data (`rdata_a`, `rdata_b`, `rdata_c`) will be available after 1 clock cycle.

#### Interface Ports:
- **clk:** Clock signal for synchronization.
- **we:** Active-high write enable signal.
- **waddr:** 8-bit write address for memory initialization.
- **wdata:** 25-bit write data for memory initialization.
- **raddr_a:** 8-bit read address for port A.
- **rdata_a:** 25-bit read data from port A.
- **raddr_b:** 8-bit read address for port B.
- **rdata_b:** 25-bit read data from port B.
- **raddr_c:** 8-bit read address for port C.
- **rdata_c:** 25-bit read data from port C.

### 2. Saturation Multiplier
The saturation multiplier (instantiated twice) performs fixed-point multiplication of the delta value with,
- The inverse of `i_max` to calculate saturation for HSV.
- The inverse of `(1 - |2L - 1|)` to calculate saturation for HSL.

#### Interface Ports:
- **clk:** Clock signal for synchronization.
- **rst:** Active-high reset signal.
- **a:** 25-bit multiplicand. // Inverse of denominator (1/i_max or 1/(1-|2L-1|))
- **b:** 8-bit multiplier (delta value).
- **result:** 13-bit result of the multiplication, representing saturation.

The module computes the multiplication of `a and b`, storing the result in a **31-bit intermediate register**.  
To obtain a fixed-point result in **fx1.12 format**, bits `[30:12]` are selected. **Rounding** is applied by adding the **most significant bit of the discarded portion** (`[11]`).  
This produces a **19-bit rounded result**, from which the **lower 13 bits** are taken to form the final output in fx1.12 format.

### 3. Hue Multiplier
The hue multiplier performs fixed-point multiplication of the precomputed hue value with the inverse of `delta_i` to calculate the hue value before doing hue addition.

#### Interface Ports:
- **clk:** Clock signal for synchronization.
- **rst:** Active-high reset signal.
- **dataa:** 19-bit signed multiplicand (precomputed hue value).
- **datab:** 25-bit multiplier (inverse of `delta_i`).
- **result:** 12-bit signed result of the multiplication, representing hue.

The `hue_mult` module multiplies dataa and datab and the result is **44-bit wide**.This module selects bits `[33:22]`, effectively truncating the lower 22 bits.
**No explicit rounding is performed**

### 4. CMYK Multiplier
The CMYK multiplier module is instantiated three times to compute the **Cyan, Magenta, and Yellow** components. Each instance performs pipelined fixed-point multiplication with rounding.
- It multiplies the **difference between `i_max` and each RGB component** (`R`, `G`, or `B`), which is scaled by `255` with the **inverse of `i_max`**, retrieved from memory.
- This avoids runtime division and produces a fixed-point result in **fx8.8** format.

#### Interface Ports:
- **clk:** Clock signal for synchronization.
- **rst:** Active-high reset signal.
- **a:** 25-bit multiplicand. // Inverse of denominator (1/i_max)
- **b:** 16-bit multiplier
- **result:** 16-bit result of the multiplication, representing C, M, or Y. After rounding.

The module computes the multiplication of inputs, **a and b**, and the result is stored in a 41-bit intermediate register.   
The result is **rounded** by selecting bits `[40:16]` and **adding the most significant bit of the discarded portion** (`[15]`).
This is stored as a 26-bit rounded result. The final 16-bit output (result) is obtained by taking the lower 16 bits of the rounded result (representing the CMY value in fx8.8 format).

## Internal Architecture

The internal architecture is divided into several stages, each implemented using pipelined logic for efficient processing:

1. **Input Scaling and Max/Min Calculation:**  
   - The 8-bit RGB inputs are scaled to 12-bit fixed-point values.
   - The maximum (`i_max`) and minimum (`i_min`) values among the R, G, and B components are determined.
   - The delta (`delta_i`) is calculated as the difference between `i_max` and `i_min`.
   - The `max_plus_min` is calculated as the sum of `i_max` and `i_min`.

2. **Memory Lookup for Inverse Values:**  
   - The inverse values of `i_max`, `delta_i` and `(1-|2L-1|)` are fetched from the multi-port RAM. These values are precomputed and stored to avoid division operations.

3. **Hue Calculation:**  
   - The Hue value is calculated based on the maximum RGB component using precomputed inverse values and fixed-point arithmetic.
   - The result is adjusted based on the maximum component (Red, Green, or Blue) and normalized to the range [0, 360].

4. **Saturation Calculation:**  
   - For HSV Channel, Saturation is calculated using the formula `S = (delta / i_max)`, implemented using fixed-point multiplication with the pre-computed inverse of `i_max`.
   - For HSL Channel, Saturation is calculated using the formula `S = delta_i / (1 - |2L - 1|)`, implemented using fixed-point multiplication with the pre-computed inverse of `(1 - |2L - 1|)`.

5. **Value Calculation:**  
   - Value is the maximum RGB component, scaled to the output format.
   
6. **Lightness Calculation:**  
   - Lightness is the `max_plus_min` divided by 2.

7. **CMY (Cyan, Magenta, Yellow) Calculation:**  
   - The preliminary differences `(i_max - R)`, `(i_max - G)`, and `(i_max - B)` are computed.  
   - These values are multiplied by 255 and then multiplied by the inverse of `i_max` to avoid division.  
   - The result is the CMY values in fixed-point fx8.8 format.

8. **Key (K) Calculation:**  
   - The Black Key (`K`) component is calculated as `K = 255 - i_max`.  
   - This value is directly derived from `i_max` and represents the depth of black in integer format.

9. **Output Pipeline:**  
   - The calculated Hue, Saturation, Value, Lightness, and CMYK values are passed through a pipeline to ensure proper timing and synchronization.  
   - The `valid_out` signal is asserted when the output data is ready.

## Timing and Latency

The design is fully pipelined, with a total latency of **8 clock cycles** from the assertion of `valid_in` to the assertion of `valid_out`. Each computational step within the module has a specific processing time, but because the design is **pipelined**, different portions of the input data progress through distinct stages concurrently. 

1. **Subtraction (1 cycle)**  
   - The first stage computes the differences required for Hue calculation: `(G - B)`, `(B - R)`, and `(R - G)`.  
   - These values are passed forward to later stages while new input data enters the pipeline.  

2. **Max/Min Value Calculation (2 cycles)**  
   - The second stage determines the **maximum (`i_max`)** and **minimum (`i_min`)** values among `R`, `G`, and `B`.  

3. **Determine the Maximum Component and Compute Delta (3 cycles)**  
   - This stage identifies which component (`R`, `G`, or `B`) contributed to `i_max`.  
   - It also calculates **delta (`delta_i`)**, which is the difference between `i_max` and `i_min`.
   - For HSL Channel, it also calculates the sum of `i_max` and `i_min`.   

4. **Memory Lookup for Inverse Values (5 cycles from `valid_in`)**  
   - The inverse values of `i_max` and `delta_i` are retrieved from a precomputed lookup table.
   - Memory access itself takes **1 cycle**, but the lookup results become available at different times:
     - The **inverse of `i_max`** is available **3 cycles after `valid_in`**.
     - The **inverse of `delta_i`** and Absolute denominator value, **(1 - |2L - 1|)** is available **4 cycles after `valid_in`**.
	 - The **inverse of `(1 - |2L - 1|)`** is available **5 cycles after `valid_in`**.
	 
5. **Saturation Calculation for HSV (6 cycles from `valid_in`)**  
   - Once `delta_i` and `i_max` are available, the saturation computation is performed using **fixed-point multiplication**.  
   - The **inverse of `i_max`** and `delta_i` become available after 3 cycles. The multiplication takes an additional **3 cycles** for computation and rounding.  
   - The computed saturation value is stored in the pipeline and remains until **valid_out** is asserted at cycle 8.  

6. **Saturation(HSL) and Hue Calculation(HSV/HSL) (8 cycles from `valid_in`)**
   - Saturation calculation for HSL channel:
     1. Once `delta_i` and `(1 - |2L - 1|)` are available, the saturation computation is performed using **fixed-point multiplication**.  
     2. The **inverse of `delta_i`** become available after 3 cycles and **inverse of `(1 - |2L - 1|)`** is available after 5 cycles. The multiplication takes an additional **3 cycles** for computation and rounding.  
   - The hue calculation involves two key computations:
     1. **Precomputed Hue Calculation (`5 cycles`)**  
        - The **subtracted value** used in Hue calculation (`G-B`, `B-R`, or `R-G`) is available **1 cycle after `valid_in`**.  
        - Identifying which component contributed to `i_max` takes **3 cycles**, so the appropriate subtracted value is selected by cycle **4**.  
        - An additional **1 cycle** is required to multiply this value by **60**, making the **precomputed hue** available by cycle **5**.  
     2. **Final Hue Computation (`3 additional cycles`)**  
        - The **inverse of `delta_i`** is available at **cycle 4**.  
        - The **hue multiplication module** receives `precomputed hue` (cycle 5) and `inverse of the delta` (cycle 4) and performs the multiplication, which takes **2 cycles**.  
        - An additional **1 cycle** is required to add the **hue offset** (0, 120, or 240 degrees based on `i_max`).  
        - The final **Hue (`hsv_channel_h, hsl_channel_h`) is available at cycle 8**, aligning with `valid_out`.  

7. **Value Calculation (2 cycles from `valid_in`)**  
   - The **Value (`V`) component** is assigned the maximum input (`i_max`).  
   - Since `i_max` is computed early in the pipeline, `hsv_channel_v` is ready **by cycle 2** but remains in the pipeline until all outputs are valid.  

8. **Lightness Calculation (4 cycles from `valid_in`)**  
   - The **Lightness (`L`) component** is calculated with `max_plus_min` divided by 2.  
   - Since `max_plus_min` is computed early in the pipeline, `hsl_channel_l` is ready **by cycle 4** but remains in the pipeline until all outputs are valid.

9. **Black Key Calculation (3 cycles from `valid_in`)**
   - The **Black (Key) component (`K`)** in CMYK is calculated as `K = 255 - i_max`.  
   - Since `i_max` is computed within the first few pipeline stages, the `cmyk_channel_k` output is available **by cycle 3** from `valid_in` but remains in the pipeline until all outputs are valid.

10. **Cyan, Magenta, Yellow (CMY) Calculation (7 cycles from `valid_in`)**  
   - CMY components are computed using a series of subtractions and fixed-point multiplications:
     1. **Component Subtraction (`3 cycle`)**
        - `i_max` value is available 2 cycles after `valid_in`.   
        - The differences `(i_max - R)`, `(i_max - G)`, and `(i_max - B)` are computed **3 cycle after `valid_in`**.
     2. **Multiplication by 255 (`1 cycle`)**  
        - These differences are multiplied by 255 to scale them into the full 8-bit range. This step takes **1 additional cycle**.
     3. **Inverse Lookup and Final Multiplication (`3 cycles`)**  
        - The **inverse of `i_max`** is fetched from memory by **cycle 3**.  
        - The product of the scaled difference and the inverse of `i_max` is computed using a pipelined multiplier, which takes **3 cycles** for multiplication and rounding.
     4. **Final Output Available at Cycle 7**  
        - The resulting CMY values are in **fx8.8 format** and become available **7 cycles after `valid_in`**, but remain in the pipeline until all outputs are valid.

## Fixed-Point Formats

- **Hue (hsv_channel_h, hsl_channel_h):**  
  - Format: fx10.2 (10 integer bits, 2 fractional bits).
  - Range: 0 to 360 degrees (scaled by a factor of 4).

- **Saturation (hsv_channel_s, hsl_channel_s):**  
  - Format: fx1.12 (1 integer bit, 12 fractional bits).
  - Range: 0% to 100% (scaled by a factor of 4096).

- **Value (hsv_channel_v):**  
  - Format: 12-bit decimal.
  - Range: 0% to 100% (scaled by a factor of 255).

- **Lightness (hsl_channel_l):**  
  - Format: 12-bit decimal.
  - Range: 0% to 100% (scaled by a factor of 255).  

- **Cyan, Magenta, Yellow (cmyk_channel_c, cmyk_channel_m, cmyk_channel_y):**
  - Format: fx8.8 (8 integer bits, 8 fractional bits).
  - Range: 0% to 100% (scaled by a factor of 256 × 255).

- **Black Key (cmyk_channel_k):**
  - Format: Integer (8 bit).
  - Range: 0% to 100% (scaled by a factor of 255).

## Precision and Error Tolerance

The module is designed to maintain the following error tolerances:
- **Hue:** ±0.25 degree.
- **Saturation:** ±0.25%.
- **Value:** ±0.25%.
- **Lightness:** ±0.25%.
- **Cyan, Magenta, Yellow, Black Key:** ±0.25%.

These tolerances account for precision loss during fixed-point arithmetic and rounding operations.

## Input constraints
- Assume that new inputs are provided to the design only after `valid_out` is asserted, indicating all outputs are valid.