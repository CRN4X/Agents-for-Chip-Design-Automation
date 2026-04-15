# Cipher Module Description

This module implements a Feistel-based encryption mechanism that processes 32-bit input data using an iterative round function. The design consists of a simple round-based transformation, utilizing a key schedule to derive round-specific subkeys. The cipher operates synchronously with a clock signal and provides an encrypted output after completing the required number of rounds.

---

## Interfaces

### Clock and Reset

- **clk:** Clock signal for synchronous operations.  
- **rst_n:** Active-low asynchronous reset that initializes the system and clears all state variables.  

### Control Signals

- **start:** When asserted, initiates an encryption process.  

### Data Input

- **data_in** (32 bits): The plaintext input that undergoes Feistel-based transformation.  
- **key** (16 bits): The initial key used for deriving round-specific subkeys.  

### Data Output

- **data_out** (32 bits): The resulting ciphertext after completing all Feistel rounds.  
- **done:** A one-cycle pulse indicating that encryption has completed.  

---

## Detailed Functionality

### 1. Feistel Structure and State Management

- **Data Partitioning:**
  - The 32-bit input is divided into two 16-bit halves: `left` and `right`.
  
- **Round Processing:**
  - In each round, the right half is processed through a non-linear transformation (`f_function`) combined with a round-specific subkey.
  - The left half is XORed with this transformed right half, followed by a swap of the halves.
  
- **Finalization:**
  - After the last round, the left and right halves are swapped one last time before forming the final 32-bit output.

### 2. Key Schedule and Round Key Generation

- **Initial Keying:**
  - The `key` input serves as the base key from which round-specific subkeys are derived.
  
- **Key Expansion:**
  - Each round derives a unique subkey using a rotation and XOR operation against the current round index.
  
### 3. State Transitions

- **IDLE:**
  - The system remains in this state until `start` is asserted.
  - On assertion, input data and key are latched, and round processing begins.
  
- **ROUND:**
  - Executes 8 rounds of Feistel transformation.
  - Each round updates internal state variables (`left`, `right`, and `round_key`).
  
- **FINISH:**
  - Once 8 rounds are completed, the final data is assigned to `data_out`, and `done` is asserted for one clock cycle.
  - The system then transitions back to `IDLE`.

### 4. Round Function (f_function)

- The Feistel function (`f_function`) applies a sequence of bitwise operations and modular arithmetic transformations:
  - XOR with the round key.
  - Bitwise rotations.
  - Additive mixing with the round key.

### 5. Synchronization and Output Handling

- **Clocked Operations:**
  - The state machine progresses on each rising edge of `clk`.
  
- **Reset Behavior:**
  - When `rst_n` is asserted low, all internal registers are cleared, and the module returns to `IDLE`.
  
- **Completion Indication:**
  - When encryption completes, `done` is asserted for a single cycle before returning to `IDLE`.

---

## Summary

- **Architecture:**  
  The cipher module follows a Feistel network structure with 8 iterative rounds, a key schedule mechanism, and a simple FSM to manage encryption flow.

- **Key Management:**  
  The system uses a derived round key approach to introduce variation across rounds while maintaining reversibility for decryption.

- **Dynamic Control:**  
  The module dynamically processes input data upon receiving a `start` signal, ensuring pipeline compatibility for hardware applications.

This specification provides a comprehensive overview of the cipher module, emphasizing its structure, operational flow, and internal state transitions.
