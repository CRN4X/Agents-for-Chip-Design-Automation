The `nbit_swizzling` module performs bit rearrangement **(swizzling)** and **Gray code** conversion on an input data bus of variable width. The module offers four swizzling patterns controlled by a **2-bit selection signal**. After the swizzling operation, an additional logic block generates the Gray-coded version of the swizzled output.

## Parameterization

- **DATA_WIDTH**  
  Specifies the width (in bits) of the `data_in` and `data_out` buses. The module can be instantiated with any valid integer `DATA_WIDTH`. Default is 64.

## Interfaces

### Data Inputs

- **`data_in([DATA_WIDTH-1:0])`** : Input data signal of size `DATA_WIDTH`. It serves as the primary input for the swizzling operation.
- **`sel([1:0])`** : 2-bit selection signal that determines the type of bit-swizzling transformation applied to `data_in`.

### Data Outputs

- **`data_out([DATA_WIDTH-1:0])`** : Output data signal of size `DATA_WIDTH`. It holds the transformed version of `data_in` after applying the bit-swizzling operation based on `sel`.
- **`gray_out([DATA_WIDTH-1:0])`** : Output data signal of size `DATA_WIDTH`. It represents the Gray code equivalent of `data_out`, where each bit is computed using the XOR of adjacent bits.


## Detailed Functionality

### Swizzling Patterns
The module implements four distinct rearrangement (swizzling) patterns, selected by the 2-bit `sel` signal.

1. **`sel = 2'b00`: Reverse Bit Order**
   - Each bit in `data_in` is reversed and assigned to `data_out`.  
     - Example: bit 0 of `data_out` will hold bit `DATA_WIDTH-1` of `data_in`, bit 1 of `data_out` will hold bit `DATA_WIDTH-2` of `data_in`, etc.

2. **`sel = 2'b01`: Half-Swizzle**
   - The input is split into two halves.  
     - The first half of `data_out` receives the reversed bits of the lower half of `data_in`.  
     - The second half of `data_out` receives the reversed bits of the upper half of `data_in`.

3. **`sel = 2'b10`: Quarter-Swizzle**
   - The input is split into four quarters.  
     - Each quarter of `data_out` is assigned bits from the reversed bits of each corresponding quarter of `data_in`.

4. **`sel = 2'b11`: Eighth-Swizzle**
   - The input is split into eight segments (eighths).  
     - Each segment of `data_out` is assigned bits from the reversed bits of each corresponding segment of `data_in`.

### Gray Code Conversion
After `data_out` is computed, the module derives the Gray-coded version (`gray_out`) from `data_out`.

1. The most significant bit (MSB) of `gray_out` is the same as the MSB of `data_out`.
2. For every other bit `j` (from `DATA_WIDTH-2` down to 0), `gray_out[j]` is computed as `data_out[j+1] XOR data_out[j]`.  
   - This follows the standard binary-to-Gray code transformation.
   

## Example Usage

### Inputs
- **`data_in([DATA_WIDTH-1:0])`**: Input data signal of size `DATA_WIDTH`. It serves as the primary input for the swizzling operation.  
- **`sel([1:0])`**: 2-bit selection signal that determines the type of bit-swizzling transformation applied to `data_in`.

### Operation
Consider instantiating the **nbit_swizzling** module with a 64-bit data path. Suppose the input bus is `64'hDEADBEEF_12345678` and `sel` is set to **2'b01**.

- **Resulting Behavior**:  
  - The 64 bits are divided into two 32-bit halves.  
  - The lower 32 bits (bits `[31:0]`) are reversed and assigned to `data_out[31:0]`.  
  - The upper 32 bits (bits `[63:32]`) are reversed and assigned to `data_out[63:32]`.  
  - Immediately after computing `data_out`, the Gray code logic transforms `data_out` into `gray_out`.


## Summary

### Functionality
The **nbit_swizzling** module rearranges (swizzles) the bits of its input according to a **2-bit selection signal**, allowing for multiple swizzling patterns. After swizzling, a Gray code transformation is performed on the resultant data.

### Swizzling Patterns
Four swizzling patterns offer flexibility in reversing subsets of bits, suitable for various data manipulation and testing scenarios.

### Gray Code Conversion
The output is immediately converted into a Gray-coded form, a common requirement in many digital systems (e.g., counters, error-checking, and synchronization domains).

### Combinational Logic
All operations are performed in combinational always blocks, so `data_out` and `gray_out` respond immediately to changes in `data_in` or `sel`.

Overall, **nbit_swizzling** is a versatile module for bit manipulation and Gray code conversion, easily customizable via the `DATA_WIDTH` parameter and controlled by the `sel` signal.