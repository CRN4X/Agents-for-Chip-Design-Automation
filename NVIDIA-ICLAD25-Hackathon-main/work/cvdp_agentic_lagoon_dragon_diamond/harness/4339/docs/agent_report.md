# Agent Run Report

- Timestamp: 2026-04-02 21:08:40
- RTL files: 5
- VERIF files: 0
- DOCS files: 6
- Problem type: `rtl_debug_bug_fix`
- Handler: `bug_fix_rule_handler`
- Target RTL candidates: `['adder_2d_layers.sv', 'adder_tree_2d.sv', 'correlate.sv', 'cross_correlation.sv', 'detect_sequence.sv']`

## Prompt Preview
```
The **detect_sequence** module must be updated with the following changes to its interface and internal behavior.

#### Interface Modifications

- **Remove** the input signal `i_static_threshold` and its associated parameter.
- **Add** a new **parameter** `NBW_TH_UNLOCK`, default value: `3`.
- **Add** a new **input signal** `i_static_unlock_threshold` with width `NBW_TH_UNLOCK`.
- **Add** a new **1-bit output signal** `o_locked`.

#### Functional Description

- A new **finite state machine (FSM)
```

## NVIDIA Log Context (Preview)
```

```

## Notes
- Generic rule-based patching mode active.
- Patch attempts: 0
