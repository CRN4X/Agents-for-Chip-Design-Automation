# Agent Run Report

- Timestamp: 2026-04-02 21:09:19
- RTL files: 4
- VERIF files: 1
- DOCS files: 1
- Problem type: `modify_extend_existing`
- Handler: `generic_noop_handler`
- Target RTL candidates: `['aes_decrypt.sv', 'aes_ke.sv']`

## Prompt Preview
```
Modify the `aes_decrypt` and `aes_ke` modules in the `rtl` directory, which originally perform an AES-128 decryption and AES-128 key expansion, to perform an AES-256 decryption and an AES-256 key expansion. A testbench to test the updated design is provided in the `verif` directory, and the `sbox` and `inv_sbox` modules do not need to be changed. The AES-128 version takes a 128-bit key and a 128-bit data and decrypts it, while the AES-256 version receives a 256-bit key and a 128-bit data and dec
```

## NVIDIA Log Context (Preview)
```

```

## Notes
- Generic rule-based patching mode active.
- Patch attempts: 2
