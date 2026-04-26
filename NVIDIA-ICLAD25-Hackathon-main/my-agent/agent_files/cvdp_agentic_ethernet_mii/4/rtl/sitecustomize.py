"""Local cocotb compatibility shim for harness eval envs."""

try:
    from cocotb.types import Logic

    if not hasattr(Logic, "to_unsigned"):
        def _to_unsigned(self):
            return int(self)

        Logic.to_unsigned = _to_unsigned
except Exception:
    # Keep startup robust if cocotb import path differs.
    pass
