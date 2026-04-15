# Sigma-Delta Audio Modulator Documentation

## Module: `sigma_delta_audio`

### Overview
The `sigma_delta_audio` module provides a 1-bit sigma-delta output for stereo audio signals, mimicking Amiga’s classic Paula sound hardware. It accumulates left and right sample data, applies basic filtering, and drives one-bit outputs (`left_sig` / `right_sig`) for external DAC or direct PWM use.

### Module Overview
- **Accumulators & Feedback:** Maintains integrators (`l_ac1/l_ac2`, `r_ac1/r_ac2`) that track error terms (`l_er0/r_er0`) and update them each clock cycle.
- **Dithering & Random Seed:** Uses two LFSRs (`seed_1`, `seed_2`) to introduce noise (`s_out`) to reduce quantization errors.
- **Data Handling:** Collects input samples (`load_data_sum/read_data_sum`), scales them, and steps through interpolation using `integer_count`.

### Key Operations
- **Load/Read Accumulation:** Each new sample is latched when `integer_count` rolls over, and partial increments/decrements are added between sample boundaries.
- **Sigma-Delta Modulation:** Determines the 1-bit output based on sign thresholds (`l_er0/r_er0`) and gain conditions (`load_data_gain/read_data_gain`).
- **Seed Updating:** `seed_1` and `seed_2` shift LFSR values each enabled clock cycle, providing randomness to `s_sum` and `s_out`.

---

## **Port Description**
| Port Name       | Direction | Width  | Description                  |
|-----------------|-----------|--------|------------------------------|
| `clk_sig`       | Input     | 1-bit  | Clock signal                 |
| `clk_en_sig`    | Input     | 1-bit  | Clock enable signal          |
| `load_data_sum` | Input     | 15-bit | Input data for left channel  |
| `read_data_sum` | Input     | 15-bit | Input data for right channel |
| `left_sig`      | Output    | 1-bit  | Modulated left audio output  |
| `right_sig`     | Output    | 1-bit  | Modulated right audio output |

---

## **Parameters**
| Parameter     | Value | Description                        |
|---------------|-------|------------------------------------|
| `DATA_WIDTH`  | 15    | Bit width of input data            |
| `CLOCK_WIDTH` | 2     | Clock width constant               |
| `READ_WIDTH`  | 4     | Read width constant                |
| `A1_WIDTH`    | 2     | Width for first accumulator stage  |
| `A2_WIDTH`    | 5     | Width for second accumulator stage |

---

## **Internal Signals & Registers**

### **Registers and Wires**
- **Error Feedback Registers:**
  - `l_er0`, `r_er0`: Current error values for left and right channels.
  - `l_er0_prev`, `r_er0_prev`: Previous error values for feedback.
- **Accumulator Stages:**
  - `l_ac1`, `r_ac1`: First accumulator stage.
  - `l_ac2`, `r_ac2`: Second accumulator stage.
- **Quantization Outputs:**
  - `l_quant`, `r_quant`: Quantized signal for each channel.
- **Noise Shaping Seeds:**
  - `seed_1`, `seed_2`: Pseudo-random number generators for noise shaping.

---

## **Functional Description**

### **1. Pseudo-Random Number Generation**
A **Linear Feedback Shift Register (LFSR)** mechanism generates random noise signals to shape quantization noise.

### **2. Data Processing & Accumulation**
The input signal is **differentiated** and accumulated to implement noise shaping.

### **3. Quantization & Modulation**
The **quantization output** determines the 1-bit modulated audio output.

### **4. Error Feedback & Output Generation**
The final output is generated based on the quantized signal.

---

## **Key Features**
- **Sigma-Delta Modulation:** Converts high-bit-depth signals to **1-bit audio**.
- **Error Feedback:** Uses **two-stage accumulators** for noise shaping.
- **Pseudo-Random Noise Addition:** Improves quantization performance.
- **Efficient Hardware Design:** Optimized with **minimal registers**.

---

## **Summary**
The `sigma_delta_audio` module provides an efficient **Sigma-Delta Modulator** for **high-quality audio processing**. It uses **accumulators, error feedback, and quantization** to generate modulated audio signals while shaping noise effectively. This approach is widely used in **high-fidelity digital audio applications**.
