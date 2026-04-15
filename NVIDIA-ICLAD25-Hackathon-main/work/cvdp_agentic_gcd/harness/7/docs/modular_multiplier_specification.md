# RTL Specification: modular_multiplier

## 1. Overview
The **modular_multiplier** computes the modular product  

 (A * B\) % mod_val

using a sequential shift-and-add algorithm over a configurable bit width.
The shift-add algorithm for multiplication works by examining each bit of one binary number; for every bit that is 1, 
it adds the other number shifted left by the bit’s position to a running total. This method efficiently decomposes multiplication into simple bit shifts and 
additions, mirroring manual multiplication in binary and optimizing it for digital hardware.

## 2. Parameter
- **WIDTH**: Bit width for operands, result, and intermediate signals (default: 8).

## 3. Interface

### 3.1 Inputs
- **clk**: Clock signal. Design is synchronised to the posedge of clk.
- **rst**: Synchronous reset. Active-high.
- **start**: Initiates the multiplication operation. Active-high. All steps of the operation occur sequentially after start is asserted.
- **A**: Multiplicand, [WIDTH-1:0]. Unsigned integer.
- **B**: Multiplier, [WIDTH-1:0]. Unsigned integer.
- **mod_val**: Modulus, [WIDTH-1:0]. Unsigned integer greater than 0.

### 3.2 Outputs
- **result**: Final computed value ((A * B\) % mod_val), [WIDTH-1:0].
- **done**: Indicates completion of the operation. Active-high.

## 4. Functional Description
When a **start** signal is received, the module:
- Processes the multiplication sequentially.
- Produces the final result when all computations are complete, asserting the **done** flag.

## 5. Remarks
- Keep intermediate values within bounds.