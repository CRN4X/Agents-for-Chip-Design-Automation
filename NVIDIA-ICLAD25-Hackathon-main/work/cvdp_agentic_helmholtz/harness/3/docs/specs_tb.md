# Helmholtz Resonator Audio Processor Specification Document

## Introduction

The **Helmholtz Resonator Audio Processor** is a pipelined and modular Verilog design intended for real-time audio signal processing. It is inspired by acoustic resonance principles and designed to modulate and filter audio inputs through calibrated resonators, frequency modulation, and soft clipping. This design is suited for musical signal synthesis, dynamic audio effects, and real-time DSP systems.

The top-level module `helmholtz_top_module` orchestrates three subcomponents:
- Frequency **modulator**
- **resonator bank** with automatic calibration
- **soft clipper** to manage amplitude non-linearities

## Signal Flow Overview

The audio signal path follows these stages:

1. **Input Audio Feed:**  
   Signed 16-bit audio samples enter the system (`audio_in`).

2. **Modulation (Modulator):**  
   A counter-based modulator generates a dynamic modulation signal (`mod_signal`) that modulates the frequency input to the resonators.

3. **Resonator Bank (3 Helmholtz Resonators):**  
   The modulated base frequency is routed to three parallel Helmholtz resonators (low, mid, high bands), each automatically calibrated and driven by the same input. Their outputs are summed to form a single resonated signal.

4. **Soft Clipper:**  
   The resonated signal is softly clipped to limit amplitude peaks, creating a smoother, distortion-friendly output (`audio_out`).

## Module Interface

```verilog
module helmholtz_top_module (
    input  logic             clk,
    input  logic             rst,
    input  logic             calibrate,
    input  logic signed[15:0] audio_in,
    input  logic [15:0]      base_freq,
    input  logic [7:0]       q_factor,
    input  logic             mod_enable,
    output logic [2:0]       cal_done_flags,
    output logic signed[15:0] audio_out
);
```

### Port Descriptions

| Signal         | Direction | Width   | Description                                        |
|----------------|-----------|---------|----------------------------------------------------|
| `clk`          | Input     | 1 bit   | System clock (positive-edge triggered)             |
| `rst`          | Input     | 1 bit   | Active-high reset                                  |
| `calibrate`    | Input     | 1 bit   | Calibration trigger for all resonators             |
| `audio_in`     | Input     | 16 bits | Signed audio input                                 |
| `base_freq`    | Input     | 16 bits | Base frequency input for modulation                |
| `q_factor`     | Input     | 8 bits  | Q-factor controlling resonance width               |
| `mod_enable`   | Input     | 1 bit   | Enables modulation signal                          |
| `cal_done_flags`| Output   | 3 bits  | Calibration complete flags for 3 resonators        |
| `audio_out`    | Output    | 16 bits | Processed signed audio output                      |

---

## Submodules

### 1. Helmholtz Resonator

Each resonator is a stateful FSM-based filter with internal frequency calibration logic. Calibration iteratively adjusts a `calibration_factor` to match the `target_freq` within a defined tolerance. The resonator also applies feedback-based filtering using the following formula:

```
x <= audio_in - (feedback * coeff_b)
y <= x * coeff_a
```

#### FSM States:
- `IDLE`: Wait for `calibrate` signal
- `CALIBRATING`: Adjusts frequency until error is within tolerance
- `DONE`: Holds calibration
- `PROCESSING`: Actively filters audio

### 2. Modulator

A 16-bit counter that increments on every clock cycle when `mod_enable` is high. It modulates the `base_freq` to generate low/mid/high target frequencies for each resonator by bit-slicing the counter.

#### Output:
- `mod_signal[15:0]`: Fed to resonator bank

### 3. Resonator Bank

Instantiates three `helmholtz_resonator` modules:
- `low`: frequency = `base_freq + mod_signal[7:0]`
- `mid`: frequency = `base_freq + mod_signal[9:2]`
- `high`: frequency = `base_freq + mod_signal[11:4]`

Each resonator processes the same audio input and outputs a filtered result. These are then added together (attenuated by 2 bits) to form `resonated_signal`.

### 4. Soft Clipper

Applies soft saturation to the resonated signal:
```verilog
if (in_signal > 20480)      out = 20480;
else if (in_signal < -20480) out = -20480;
else                         out = in_signal - ((in_signal * in_signal) >>> 10);
```
This reduces harsh clipping while preserving dynamic range.

---

## Timing and Latency

- **Resonator calibration**: FSM-driven, completion time depends on proximity to `target_freq`
- **Modulator**: Continuous counter, affects resonator frequencies
- **Processing Latency**:
  - Resonator processing is pipelined over a few cycles (calibration-to-output)
  - Clipper is combinational
- Full audio pipeline latency: approx. **6–10 cycles** post-calibration

---

## Input Constraints

- Input audio (`audio_in`) must remain valid for at least 2 cycles per transaction
- Calibration must remain high until `cal_done_flags` signal completion
- Inputs should not toggle during reset

---

## Typical Use Case

| Scenario        | Setup                                  |
|-----------------|-----------------------------------------|
| Raw filtering   | `calibrate=0`, `mod_enable=0`          |
| Resonator sync  | `calibrate=1` until `cal_done_flags=3'b111` |
| Modulation FX   | `mod_enable=1`, with dynamic `audio_in` |
| Param sweep     | Sweep `q_factor` or `base_freq`        |

---

## Test Recommendations

To validate the module:
- Run a 150+ stimulus testbench
- Toggle calibration and modulation
- Sweep `base_freq` and `q_factor`
- Inject audio bursts (±32768), sine waves, and silence
- Observe `cal_done_flags`, FSM transitions, and output shaping

---

## Performance Notes

- Tolerance for calibration: ±10%
- Q-factor accuracy relies on input scaling
- The module supports high-frequency responsiveness with minimal CPU intervention

---

## Conclusion

The Helmholtz Resonator Audio Processor is a versatile and modular signal-processing design suitable for music synthesis, effects chains, and adaptive resonance applications. With internal calibration, modulation, and amplitude management, it delivers efficient, real-time filtering of audio signals.