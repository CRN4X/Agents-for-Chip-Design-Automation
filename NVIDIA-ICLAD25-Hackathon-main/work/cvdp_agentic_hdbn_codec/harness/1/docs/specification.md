# **HDBn (HDB3/HDB2) Codec Specification Document**

## **1. Overview**
The HDBn (High-Density Bipolar) coding scheme was developed to solve critical issues in digital telecommunications transmission. Traditional AMI (Alternate Mark Inversion) coding faced problems with long sequences of zeros, which made clock recovery difficult and could lead to DC bias accumulation. HDBn improves upon AMI by introducing controlled violations that maintain synchronization while preserving DC balance.

he HDBn encoder/decoder implements High-Density Bipolar line coding, specifically HDB3 (used in E1/T1 systems) and HDB2/B3ZS (used in T3 systems). These schemes prevent long sequences of zeros to maintain clock recovery and eliminate DC bias in transmission lines. The encoder converts binary data into bipolar pulses with intentional violations, while the decoder recovers the original data and detects transmission errors.


The key innovation in HDBn is its replacement mechanism for zero sequences:
- **HDB3**: Replaces every 4 consecutive zeros with either "000V" or "B00V"
- **HDB2/B3ZS**: Replaces every 3 consecutive zeros with "B0V"

In HDBn coding schemes, **B** and **V** are special pulse markers used to maintain synchronization and DC balance:

### **V (Violation Pulse)**
- A deliberate **polarity violation** of the AMI (Alternate Mark Inversion) rule.
- Normally, pulses alternate between positive (+) and negative (-). A **V** intentionally repeats the same polarity as the previous pulse to create a detectable event.
- **Purpose**: 
  - Guarantees a signal transition (for clock recovery).
  - Marks the position where zeros were replaced.

### **B (Balance Pulse)**
- A normal pulse (following AMI rules) inserted to maintain **DC balance**.
- **Purpose**: 
  - Ensures the total number of positive and negative pulses remains equal over time (preventing DC buildup).
  - Counts as a valid "1" in the decoded data.

These substitutions guarantee sufficient signal transitions while maintaining the zero-DC property through careful violation polarity selection. The violation patterns are chosen to ensure the overall pulse count remains balanced (equal number of positive and negative pulses).

## **2. Module Descriptions**

### **2.1 Top-Level Module: hdbn_top**
This module integrates both encoding and decoding functionality for complete HDBn processing. The encoder converts NRZ (Non-Return-to-Zero) data into bipolar HDBn pulses, while the decoder performs the reverse operation while also detecting transmission errors.

The dual functionality allows for full-duplex communication systems where both transmission and reception need HDBn processing. The shared parameterization (EncoderType, PulseActiveState) ensures consistent operation across both directions.

#### Configuration Parameters

| Parameter             | Type    | Default | Description                                       |
|-----------------------|---------|---------|---------------------------------------------------|
| `encoder_type`        | integer | 3       | Select encoding type: 3 for HDB3, 2 for HDB2/B3ZS |
| `pulse_active_state`  | logic   | 1'b1    | Defines active state of P and N signals           |

#### I/O Port List

| Port              | Direction | Description                                           |
|-------------------|-----------|-------------------------------------------------------|
| `reset_in`        | input     | Active high asynchronous reset signal                 |
| `clk_in`          | input     | Input clock signal (rising-edge triggered)            |
| `clk_enable_in`   | input     | Clock enable, active high                             |
| `data_in`         | input     | Digital data input to encoder (active high)           |
| `output_gate_in`  | input     | Gate control, '0' disables encoder outputs (P, N)     |
| `p_out`           | output    | Encoder positive pulse output                         |
| `n_out`           | output    | Encoder negative pulse output                         |
| `p_in`            | input     | Decoder positive pulse input                          |
| `n_in`            | input     | Decoder negative pulse input                          |
| `data_out`        | output    | Digital data output from decoder (active high)        |
| `code_error_out`  | output    | Decoder error indication (active high)                |


### **2.2 Encoder Module (hdbn_encoder)**
The encoder implements the complete HDBn substitution algorithm through several coordinated processes:

**Input Processing and Zero Detection**
The input data first passes through a synchronization register to align with the system clock. A zero counter monitors consecutive zero bits, incrementing until either a '1' is encountered or the EncoderType limit (3 or 4) is reached. This counter is the trigger for violation insertion.

**Violation Insertion Logic**
When the zero counter reaches its maximum, the encoder must replace the zero sequence. The replacement pattern depends on two factors:
1. The current polarity state (AMI flip-flop)
2. The number of pulses since the last violation (ViolationType)

For HDB3 (4-zero replacement):
- If the previous violation count is odd: "000V" (same polarity as last pulse)
- If even: "B00V" (B pulse opposite polarity to maintain balance)

The shift registers in the design should properly align these inserted pulses with the original data stream while maintaining the correct timing relationships.

**Pulse Generation and Output Control**
The final stage generates the actual P and N outputs based on the processed data stream. The AMI flip-flop ensures proper alternation of pulse polarities, while the output gate provides a master disable function for transmission control.

#### Configuration Parameters

| Parameter             | Type    | Default | Description                                       |
|-----------------------|---------|---------|---------------------------------------------------|
| `encoder_type`        | integer | 3       | Select encoding type: 3 for HDB3, 2 for HDB2/B3ZS |
| `pulse_active_state`  | logic   | 1'b1    | Defines active state of P and N signals           |

#### I/O Port List

| Port              | Direction | Description                                           |
|-------------------|-----------|-------------------------------------------------------|
| `reset_in`        | input     | Active high asynchronous reset signal                 |
| `clk_in`          | input     | Input clock signal (rising-edge triggered)            |
| `clk_enable_in`   | input     | Clock enable, active high                             |
| `data_in`         | input     | Digital data input (active high)                      |
| `output_gate_in`  | input     | Gate control, '0' disables outputs                    |
| `p_out`           | output    | Positive pulse output                                 |
| `n_out`           | output    | Negative pulse output                                 |

### **2.3 Decoder Module (hdbn_decoder)**
The decoder performs three critical functions: pulse interpretation, violation detection, and error checking.

**Pulse Processing**
Input pulses are first registered and normalized to active-high signaling internally. The decoder tracks the polarity of each pulse to identify violations (consecutive pulses of same polarity). Valid violations are stripped out while maintaining the original data timing.

**Violation Validation**
The decoder verifies that all violations follow HDBn rules:
- Violations must occur at precise intervals (every 3 or 4 zeros)
- The polarity must alternate correctly from previous violations
- Balance pulses (B) must properly offset the DC component

**Error Detection System**
Three distinct error conditions are monitored:
1. **Pulse Errors**: Simultaneous P and N pulses (physically impossible in proper transmission)
2. **Violation Errors**: Incorrect violation polarity or timing
3. **Zero Count Errors**: Missing violations (too many consecutive zeros)

These checks provide robust monitoring of transmission line quality and protocol compliance.

#### Configuration Parameters

| Parameter             | Type    | Default | Description                                       |
|-----------------------|---------|---------|---------------------------------------------------|
| `encoder_type`        | integer | 3       | Select encoding type: 3 for HDB3, 2 for HDB2/B3ZS |
| `pulse_active_state`  | logic   | 1'b1    | Defines active state of P and N signals           |

#### I/O Port List

| Port               | Direction | Description                                           |
|--------------------|-----------|-------------------------------------------------------|
| `reset_in`         | input     | Active high asynchronous reset signal                 |
| `clk_in`           | input     | Input clock signal (rising-edge triggered)            |
| `clk_enable_in`    | input     | Clock enable, active high                             |
| `p_in`             | input     | Positive pulse input                                  |
| `n_in`             | input     | Negative pulse input                                  |
| `data_out`         | output    | Digital data output (active high)                     |
| `code_error_out`   | output    | Error indicator output (active high on errors)        |

## **3. Timing and Performance Characteristics**
The complete processing pipeline introduces predictable latency:
- **Encoder**: 6 clock cycles (input sync + 5-stage processing)
- **Decoder**: 6 clock cycles (input sync + 5-stage processing)

The critical timing path involves the violation detection and AMI toggling logic, which must complete within one clock cycle to maintain proper data alignment.

## **4. Error Handling and Diagnostics**
The decoder's error detection provides valuable system diagnostics:
- **CodeError_o** signals any protocol violation
- Persistent errors indicate line quality issues
- Specific error types help diagnose root causes:
  * Violation errors suggest timing or synchronization problems
  * Pulse errors indicate physical layer faults
  * Zero count errors reveal missing violations


