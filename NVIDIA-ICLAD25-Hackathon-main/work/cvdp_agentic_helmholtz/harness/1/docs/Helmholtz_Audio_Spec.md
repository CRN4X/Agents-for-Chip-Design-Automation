# Helmholtz Resonator Audio Processor Specification

## Overview

The Helmholtz Resonator Audio Processor is a synthesizable, modular SystemVerilog design that emulates acoustic resonance behavior in digital hardware. It features real-time calibration, multi-band filtering, modulation, and output shaping via soft clipping. This system is ideal for audio applications such as equalization, tone shaping, acoustic simulation, and embedded music synthesis.

---

## Top-Level Module: `helmholtz_top_module`

### Port Descriptions

| Signal            | Direction | Width        | Description                                         |
|-------------------|-----------|--------------|-----------------------------------------------------|
| `clk`             | input     | 1            | System clock                                        |
| `rst`             | input     | 1            | Synchronous reset, active high                      |
| `calibrate`       | input     | 1            | Triggers calibration mode across all bands          |
| `audio_in`        | input     | 16 (signed)  | Input audio sample (fixed-point)                   |
| `base_freq`       | input     | 16           | Central target frequency for resonance              |
| `q_factor`        | input     | 8            | Bandwidth control (Q)                               |
| `mod_enable`      | input     | 1            | Enables modulation of target frequency              |
| `cal_done_flags`  | output    | 3            | Calibration done flags for low/mid/high bands       |
| `audio_out`       | output    | 16 (signed)  | Processed and clipped audio output                  |

---

## Submodules and Responsibilities

### `helmholtz_resonator`

- Performs band-pass filtering using a feedback loop.
- Internal calibration loop aligns `current_freq` with `target_freq`.
- Outputs `cal_done` once frequency lock is achieved within `CAL_TOLERANCE`.

**Parameters:**
- `WIDTH = 16`
- `FRAC_BITS = 8`
- `CAL_TOLERANCE = 10` (percentage)

**Ports:**
- Inputs: `clk`, `rst`, `calibrate`, `audio_in`, `target_freq`, `q_factor`
- Outputs: `cal_done`, `audio_out`

---

### `modulator`

- Produces a simple modulation waveform.
- Used to vary `target_freq` for each band dynamically.

**Ports:**
- Inputs: `clk`, `rst`, `enable`
- Output: `mod_signal` (16-bit)

---

### `soft_clipper`

- Applies soft saturation to limit signal peaks without harsh distortion.

**Ports:**
- Input: `in_signal` (signed)
- Output: `out_signal` (signed)

---

### `resonator_bank`

- Instantiates 3 `helmholtz_resonator` modules (low, mid, high).
- Computes target frequencies using `mod_signal` offset:
  - Low: `base_freq + mod_signal[7:0]`
  - Mid: `base_freq + mod_signal[9:2]`
  - High: `base_freq + mod_signal[11:4]`
- Sums the filtered outputs.

**Ports:**
- Inputs: `clk`, `rst`, `calibrate`, `audio_in`, `base_freq`, `q_factor`, `mod_signal`
- Outputs: `cal_done_flags`, `audio_out`

---

## Functional Behavior

### Calibration Flow

- Triggered via `calibrate = 1`
- Each band adjusts its internal frequency (`current_freq`) to match `target_freq`
- Calibration completes when error < `CAL_TOLERANCE` (10%)
- `cal_done_flags[n] = 1` indicates that band `n` has locked on frequency

### Processing Flow

- Begins when `calibrate = 0`
- Audio samples are filtered through each calibrated resonator
- Outputs are combined and passed to the `soft_clipper`

### Modulation

- Enabled via `mod_enable = 1`
- The `modulator` adjusts each band’s `target_freq` offset independently

---

## Reset and Clocking

- `clk`: Global rising-edge clock
- `rst`: Resets all state machines and internal registers
- All modules should respond synchronously to `clk` and `rst`

---

## Output Characteristics

- `audio_out` is zero during calibration
- After calibration, `audio_out` is the result of band-passed, clipped audio
- Output range is limited to ±20480 by the soft clipper

---

## Testbench Requirements

### File: `tb_helmholtz_top.sv`

The testbench must:

- Initialize and apply `clk`, `rst`, and control inputs
- Drive meaningful test patterns into `audio_in` such as:
  - Constant tones
  - Silence (zero input)
  - Square or triangle waves
- Sweep `base_freq` and `q_factor`
- Toggle `mod_enable` during runtime
- Assert `calibrate`, then observe `cal_done_flags` going high
- Monitor `audio_out` for:
  - Signal presence after calibration
  - Clipping within the allowed range
- Include coverage of:
  - All bands calibrating correctly
  - Modulated vs static operation
  - Corner cases: max/min frequency, zero input, long calibration loops

---

