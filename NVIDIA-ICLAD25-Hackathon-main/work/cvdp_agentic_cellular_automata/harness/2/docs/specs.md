# Cellular Automata Pseudorandom Generator Module Description

This module implements a pseudorandom number generator based on cellular automata (CA). It operates on a fixed 16-bit state that evolves according to one of two cellular automata rules: **Rule 30** or **Rule 110**. The design leverages local three-cell neighborhood operations with wrap-around boundary conditions to compute the next state in a fully parallel, combinational manner. The state is updated synchronously on each clock cycle and can be reset to a predefined seed.

---

## Parameterization

Although the module does not use explicit parameter declarations, its functionality is defined by the following fixed parameters:

- **STATE_WIDTH:**  
  The CA state is 16 bits wide. This implies that the automaton consists of 16 cells, each storing one bit of the state.

- **RULE_SEL_WIDTH:**  
  The rule selection input is 2 bits wide. It determines which CA rule is used:
  - `2'b00` selects **Rule 30**.
  - `2'b01` selects **Rule 110**.
  - Any other value defaults to **Rule 30**.

---

## Interfaces

### Clock and Reset
- **clock:**  
  Synchronous clock input used for state updates.
  
- **reset:**  
  Active-high synchronous reset. When asserted, the module initializes its state to the provided seed.

### Control and Data Inputs
- **CA_seed (16 bits):**  
  The initial seed value for the CA state. On reset, the state is set to this value.

- **rule_sel (2 bits):**  
  The rule selector signal that determines whether Rule 30 or Rule 110 is used for generating the next state.

### Data Output
- **CA_out (16 bits):**  
  The current state of the CA, representing the pseudorandom number output. This state is updated on every clock cycle.

---

## Detailed Functionality

### 1. Next-State Computation Using a Cellular Automata Function

- **Local Function `compute_next_bit`:**  
  A dedicated function calculates the next bit for each cell of the CA. For a given cell indexed by `i`, the function:
  - **Neighborhood Retrieval:**  
    Retrieves the left, center, and right neighbors using wrap-around indexing (i.e., the left neighbor of cell 0 is cell 15, and the right neighbor of cell 15 is cell 0).
  - **Rule Evaluation:**  
    Uses a nested case statement to determine the next bit value based on the chosen rule:
    - **Rule 30:**  
      Implements the mapping:  
      - `111 → 0`  
      - `110 → 0`  
      - `101 → 0`  
      - `100 → 1`  
      - `011 → 1`  
      - `010 → 1`  
      - `001 → 1`  
      - `000 → 0`
    - **Rule 110:**  
      Implements the mapping:  
      - `111 → 0`  
      - `110 → 1`  
      - `101 → 1`  
      - `100 → 0`  
      - `011 → 1`  
      - `010 → 1`  
      - `001 → 1`  
      - `000 → 0`
  - **Default Behavior:**  
    If an unrecognized rule is selected, the function defaults to Rule 30’s behavior.

### 2. Combinational State Update

- **Parallel Bit Computation:**  
  An `always_comb` block iterates over all 16 cells, invoking the `compute_next_bit` function for each cell. This block computes the next state (`next_CA_out`) concurrently for all cells based on the current state (`CA_out`) and the selected rule.

### 3. Synchronous State Update

- **State Register Update:**  
  An `always_ff` block updates the CA state on the positive edge of the clock:
  - **Reset Operation:**  
    When `reset` is asserted, the current state (`CA_out`) is immediately loaded with the seed (`CA_seed`).
  - **Normal Operation:**  
    When reset is deasserted, the state is updated with the computed next state (`next_CA_out`).

---

## Summary

**Architecture:**  
The pseudorandom generator is designed around a 16-bit cellular automata architecture, where each bit of the state is updated simultaneously based on a local three-cell neighborhood.

**Rule Selection:**  
The module supports two well-known cellular automata rules, Rule 30 and Rule 110, selectable via a 2-bit input. This flexibility allows the designer to choose between different pseudorandom characteristics.

**Synchronous Operation:**  
The entire state is updated on every clock cycle. The reset functionality ensures that the generator can be reinitialized to a known seed, which is essential for predictable startup behavior or for restarting the pseudorandom sequence.

**Applications:**  
This module is ideally suited for applications requiring efficient hardware-based pseudorandom number generation, such as in cryptographic systems, stochastic simulations, or for generating test vectors in verification environments.
