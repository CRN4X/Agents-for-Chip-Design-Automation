# Crypto Accelerator Module Specification
This module implements a cryptographic accelerator that integrates two essential functions:

1. **Key Validation:**  
   Evaluates a candidate public key component against its corresponding totient using a greatest common divisor (GCD) algorithm to check if they are coprimes. A successful check (i.e., the GCD equals 1) deems the key valid.

2. **Encryption:**  
   When the key is valid, the module performs encryption by executing a modular exponentiation operation on provided plaintext data. If the key check fails, the encryption step is bypassed and a zero is output on the `ciphertext`.

A finite state machine (FSM) governs the sequencing of these operations, ensuring synchronous operation with a system clock and providing reset-based initialization.

## Port List

| Port Name           | Direction | Bit-Width                   | Description                                                                                     |
|---------------------|-----------|-----------------------------|-------------------------------------------------------------------------------------------------|
| **clk**             | Input     | 1                           | System clock that synchronizes all operations.                                                  |
| **rst**             | Input     | 1                           | Initializes the module to a known state; resets the FSM and all outputs. Active-high.           |
| **candidate_e**     | Input     | WIDTH                       | Represents the candidate public key component used in validation.                               |
| **totient**         | Input     | WIDTH                       | Represents Euler’s totient value associated with the key.                                       |
| **start_key_check** | Input     | 1                           | Triggers the key validation process when asserted. Active-high.                                 |
| **key_valid**       | Output    | 1                           | Indicates that the candidate key is valid (if the GCD equals 1). Active-high.                   |
| **done_key_check**  | Output    | 1                           | Signals the completion of the key validation process.  Active-high.                             |
| **plaintext**       | Input     | WIDTH                       | The data to be encrypted if the key is validated.                                               |
| **modulus**         | Input     | WIDTH                       | The modulus used in the encryption operation via modular exponentiation.                        |
| **ciphertext**      | Output    | WIDTH                       | The result of the encryption operation (or a default value if the key is invalid).              |
| **done_encryption** | Output    | 1                           | Indicates that the encryption operation (or its bypass) is completed. Active-high.              |

| Parameter Name | Description                                                     |
|----------------|-----------------------------------------------------------------|
| **WIDTH**      | Determines the bit width of input and output signals. Default:8.|

## Functional Description

### Key Validation

- **Triggering:**  
  The validation process begins when the external start command is asserted.

- **Operation:**  
  Two numeric inputs (the candidate key and totient) are processed via a GCD computation. The output of this computation determines the validity of the candidate key:
  - **Valid Key:** When the GCD equals 1  (the candidate key and totient are coprimes).
  - **Invalid Key:** When the GCD does not equal 1  (the candidate key and totient are not coprimes).

- **Outputs:**  
  - `key_valid` is asserted or deasserted based on the GCD calculation output, and `done_key_check`, which indicates that the key validation process is complete, is asserted.
  - `done_key_check` and `key_valid` are held high till the whole operation is completed, this may or may not include the encryption depending on whether the key is valid.

### Encryption

- **Conditional Execution:**  
  The encryption operation is only initiated if the key validation process confirms that the candidate key is valid.

- **Operation:**  
  Upon successful validation, the module calculates the modular exponentiation based on the provided plaintext, using the candidate key (as the exponent) and the modulus input (to calculate the modulus of the exponentiation operation) .

- **Default Behavior:**  
  If the key is not valid, the module bypasses encryption and outputs a predetermined default value (i.e. zero) as the ciphertext. If the key is valid the module outputs the result from above calculation as ciphertext.

### Sequencing and Control

An internal finite state machine (FSM) coordinates the following steps:
  
1. **Idle/Initialization:**  
   Sets all internal signals (driven sequentially) and outputs to zero and waits for the start command.
  
2. **Key Validation:**  
   Initiates and then waits for the GCD computation to complete.
  
3. **Decision Phase:**  
   Based on the result of the key validation, the FSM either:
   - Proceeds to trigger the encryption operation, or  
   - Immediately outputs the default ciphertext.
  
4. **Encryption Execution:**  
   Activates the modular exponentiation process and awaits its completion.
  
5. **Completion:**  
   Signals the conclusion of both key validation and encryption (or bypass), and holds the final outputs till the start command is deasserted.

## Timing and Reset

- **Synchronous Operation:**  
  All transitions and operations are synchronized to the positive edge of the system clock, ensuring consistent and predictable behavior.

- **Reset Behavior:**  
  The synchronous reset signal reinitializes the FSM and all outputs to IDLE and zeros respectively to allow for error-free start-up and operation.