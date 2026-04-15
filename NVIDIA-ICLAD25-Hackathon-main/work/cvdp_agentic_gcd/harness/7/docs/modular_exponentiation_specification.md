# RTL Specification: modular_exponentiation

## 1. Overview
The **modular_exponentiation** module calculates  
[result = (base<sup>exponent</sup>) % mod_val]  
using the square-and-multiply algorithm. It uses a dedicated modular multiplication unit for its arithmetic operations.

The square-and-multiply algorithm, also known as exponentiation by squaring, computes a<sup>b</sup> by first converting b into its binary representation, then iteratively updating an accumulator that starts at 1: for each bit of b, it squares the accumulator and multiplies by a when the bit is 1. Because a<sup>b</sup> can grow very large, apply modular operation at every step to keep the intermediate numbers small and manageable. This method dramatically reduces the number of multiplications compared to a naive approach, making it especially effective for large numbers and widely used in cryptography and modular arithmetic.

## 2. Parameter
- **WIDTH**: Sets the bit width for the operands, modulus, and result (default: 8).

## 3. Interface

### 3.1 Inputs
- **clk**: Clock signal. Design is synchronised to the posedge of clk.
- **rst**: Synchronous reset. Active-high.
- **start**: Initiates the modular exponentiation process. Active-high. All steps of the operation occur sequentially after start is asserted.
- **base**: Base operand, [WIDTH-1:0]. Unsigned integer.
- **exponent**: Exponent operand, [WIDTH-1:0]. Unsigned integer.
- **mod_val**: Modulus, [WIDTH-1:0]. Unsigned integer greater than 0.

### 3.2 Outputs
- **result**: The computed result ((base<sup>exponent</sup>) % mod_val), [WIDTH-1:0].
- **done**: Indicates when the computation is complete. Active-high.

## 4. Internal Architecture
- **Control Logic**: A finite state machine (FSM) governs the overall operation, initiating the process, managing the iterative algorithm, and signaling completion.
- **Modular Multiplier Instance**: The module integrates a separate modular multiplication unit to perform the required modular arithmetic without exposing its internal details.
- **Registers**: Internal registers are used to hold intermediate results, the reduced base, and the exponent as it is processed.

## 5. Remarks
- It leverages the modular multiplication unit to maintain clarity and reusability.