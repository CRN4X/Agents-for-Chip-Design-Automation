import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, Timer
import random

async def dut_init(dut):
    # iterate all the input signals and initialize with 0
    for signal in dut:
        if signal._type == "GPI_NET":
            signal.value = 0

async def populate_coeff_ram(dut, coeff_list):
    """
    Populate all coefficient RAMs in the poly_filter.
    """
    await Timer(1, units='ns')
    tap_count = int(dut.poly_dut.u_poly_filter.TAPS.value)   # Number of taps (TAPS)
    phase_count = int(dut.poly_dut.u_poly_filter.N.value)      # Number of phases (N)
    total_coeffs = tap_count * phase_count
    dut._log.info(f"Populating coefficient RAMs: tap_count = {tap_count}, phase_count = {phase_count}, total_coeffs = {total_coeffs}")

    assert len(coeff_list) == total_coeffs, (
        f"Coefficient list length {len(coeff_list)} does not match expected {total_coeffs}"
    )

    for j in range(tap_count):
        try:
            coeff_ram_inst = dut.poly_dut.u_poly_filter.coeff_fetch[j].u_coeff_ram
        except Exception as e:
            dut._log.error(f"Failed to get coeff_ram instance for tap {j}: {e}")
            continue

        for p in range(phase_count):
            addr = p * tap_count + j
            coeff_value = coeff_list[addr]
            try:
                coeff_ram_inst.mem[addr].value = coeff_value
                dut._log.info(f"Set coefficient for tap {j}, phase {p} (addr {addr}) to {coeff_value}")
            except Exception as e:
                dut._log.error(f"Failed to set coefficient at tap {j}, phase {p} (addr {addr}): {e}")
    await Timer(1, units='ns')
