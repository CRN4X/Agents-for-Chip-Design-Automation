# Conjugate Sequence Specification (`conj_proc_h` and `conj_proc_v`)

## Purpose

This document describes how to derive the conjugate reference sequences used in the `detect_sequence` module, specifically:

- Real part of the horizontal conjugate sequence  
- Imag part of the horizontal conjugate sequence  
- Real part of the vertical conjugate sequence  
- Imag part of the vertical conjugate sequence

These sequences are used for cross-correlation against known pilot symbols in complex form. Each sample is represented by its real (`I`) and imaginary (`Q`) parts, both normalized to `+1` or `-1`.

---

## Generation Process

1. **Start from the ideal complex pilot sequence** (row-wise and column-wise).
2. **Apply complex conjugation**, inverting the imaginary part:
conj(x + j·y) = x - j·y
4. **Normalize** each value to sign-only:
- If real/imag ≥ 0 → `+1`
- If real/imag <  0 → `-1`
4. **Encode** these into two parallel vectors per sequence:
- One for real parts
- One for imag parts
5. These bits are stored as logic vectors of width 23.

---

## Symbol Mapping

Each position in the sequence represents a normalized complex symbol `(Re, Im)`:

| Symbol Value | Encoded as |
|--------------|------------|
| `(+1, +1)`   | Real = 0, Imag = 0 |
| `(+1, -1)`   | Real = 0, Imag = 1 |
| `(-1, +1)`   | Real = 1, Imag = 0 |
| `(-1, -1)`   | Real = 1, Imag = 1 |

---

## Table: Sequence Interpretation

Each row below corresponds to one of the 23 complex samples in the sequence. The real and imag parts are shown as `+1` or `-1`.

### `conj_proc_h` — Horizontal Conjugate Sequence

| Index | Real Part                    | Imag Part                    |
|-------|------------------------------|------------------------------|
| 0     | +1                           | -1                           |
| 1     | -1                           | -1                           |
| 2     | +1                           | +1                           |
| 3     | -1                           | -1                           |
| 4     | +1                           | +1                           |
| 5     | +1                           | -1                           |
| 6     | -1                           | -1                           |
| 7     | -1                           | +1                           |
| 8     | +1                           | -1                           |
| 9     | +1                           | +1                           |
| 10    | +1                           | -1                           |
| 11    | -1                           | -1                           |
| 12    | +1                           | -1                           |
| 13    | -1                           | +1                           |
| 14    | +1                           | -1                           |
| 15    | +1                           | +1                           |
| 16    | -1                           | -1                           |
| 17    | +1                           | +1                           |
| 18    | +1                           | -1                           |
| 19    | -1                           | +1                           |
| 20    | -1                           | +1                           |
| 21    | +1                           | +1                           |
| 22    | +1                           | +1                           |

### `conj_proc_v` — Vertical Conjugate Sequence

| Index | Real Part                    | Imag Part                    |
|-------|------------------------------|------------------------------|
| 0     | -1                           | +1                           |
| 1     | -1                           | -1                           |
| 2     | +1                           | +1                           |
| 3     | -1                           | +1                           |
| 4     | +1                           | -1                           |
| 5     | -1                           | -1                           |
| 6     | -1                           | +1                           |
| 7     | +1                           | -1                           |
| 8     | -1                           | -1                           |
| 9     | +1                           | +1                           |
| 10    | +1                           | -1                           |
| 11    | -1                           | +1                           |
| 12    | +1                           | +1                           |
| 13    | -1                           | -1                           |
| 14    | +1                           | -1                           |
| 15    | +1                           | +1                           |
| 16    | +1                           | -1                           |
| 17    | +1                           | +1                           |
| 18    | -1                           | -1                           |
| 19    | -1                           | +1                           |
| 20    | +1                           | -1                           |
| 21    | +1                           | +1                           |
| 22    | -1                           | +1                           |