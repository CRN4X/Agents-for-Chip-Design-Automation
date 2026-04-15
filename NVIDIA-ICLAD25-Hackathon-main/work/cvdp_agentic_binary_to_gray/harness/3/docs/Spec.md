# Binary to Gray Code Converter Module Specification

## 1. Overview
This module implements a **binary-to-Gray code converter** that takes an `N`-bit binary input and produces an `N`-bit Gray code output. The conversion follows the standard rule where the **most significant bit (MSB) remains unchanged**, while each subsequent bit is computed as the XOR of the corresponding binary bit and the preceding binary bit.

The design is **purely combinational**, ensuring minimal latency and efficient hardware implementation.

---

## 2. Parameterization
The module is parameterized to support different bit widths through the `WIDTH` parameter.

  - `WIDTH`: Defines the number of bits in the binary input and the corresponding Gray code output. (`Default: 6`)

---

## 3. Interfaces

### **Inputs**
  - `binary_in`(`WIDTH-1:0)`:  N-bit binary input to be converted into Gray code. 

### **Outputs**
  - `gray_out`(`WIDTH-1:0)`: N-bit Gray code output corresponding to `binary_in`. 

---

## 4. Detailed Functionality

### **4.1 Gray Code Computation**
The Gray code for an `N`-bit binary number is computed using the formula:

\[
{Gray}[i] = {Binary}[i] XOR {Binary}[i+1]
\]

where:  
- **MSB rule:** `gray_out[WIDTH-1] = binary_in[WIDTH-1]` (unchanged).
- **Remaining bits:** Computed using bitwise XOR with the next higher bit.

This logic ensures that only a **single-bit transition** occurs between consecutive binary numbers, making the Gray code beneficial in applications such as state machines and communication systems.

### **4.2 Combinational Logic Implementation**
The conversion logic is purely **combinational**, allowing for immediate response to changes in `binary_in`. This ensures:
- **No clock dependencies**.
- **Minimal propagation delay**.
- **Low power consumption**.

An `always_comb` block or continuous assignment is used to compute the output efficiently.

### **4.3 Module Behavior**
- **Asynchronous Conversion**: The module operates without a clock and provides an output immediately when the input changes.
- **No Reset Required**: Since there is no internal state, the module does not require reset functionality.

---

## 5. Summary

### **5.1 Architecture**
- The module follows a straightforward **bitwise XOR-based architecture**, where the **MSB remains the same**, and each subsequent bit is the XOR of two adjacent binary bits.
- The design ensures that only **one-bit transitions** occur at a time in the output sequence.

### **5.2 Synchronous vs. Combinational Operation**
- The entire module operates **purely combinationally**, meaning it does **not require a clock** for operation.
- No sequential logic elements (flip-flops or registers) are used.

### **5.3 Advantages**
- **Low-latency** and **high-speed** conversion.
- **Area-efficient** hardware implementation with minimal logic gates.
- **Scalable** due to parameterized bit-width (`WIDTH`).

### **5.4 Applications**
This module is useful in applications where **single-bit changes** in data transitions are critical, including:
- **Communication Protocols** (e.g., error detection in serial transmission).
- **State Machines** (e.g., encoding finite state transitions).
- **Rotary Encoders** (e.g., positioning systems).
- **Memory Addressing** (e.g., minimizing glitches in address decoding).