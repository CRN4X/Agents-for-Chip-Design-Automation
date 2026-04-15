import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

# Read environment variables on the Python side for consistency
DATA_WIDTH      = int(os.getenv("DATA_WIDTH", "8"))
NUM_INPUTS      = int(os.getenv("NUM_INPUTS", "4"))
REGISTER_OUTPUT = int(os.getenv("REGISTER_OUTPUT", "0"))
HAS_DEFAULT     = int(os.getenv("HAS_DEFAULT", "0"))
# DEFAULT_VALUE can be read similarly if needed, but we'll skip parsing here.

async def reset_dut(dut):
    dut.clk.value = 0
    dut.rst_n.value = 0
    dut.inp.value = 0
    dut.sel.value = 0
    dut.bypass.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    # Wait a couple of cycles after de-asserting reset
    for _ in range(2):
        await RisingEdge(dut.clk)

@cocotb.test()
async def test_basic(dut):
    """Basic Sanity Test"""
    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())
    await reset_dut(dut)

    # If NUM_INPUTS=4 => we have 32 bits for 'inp'
    # Let's provide a known pattern, e.g., 0xDEADBEEF
    # If fewer inputs, mask off the higher bits
    max_bits = 8 * NUM_INPUTS
    test_inp = 0xDEADBEEF & ((1 << max_bits) - 1)
    dut.inp.value = test_inp

    # sel=0, bypass=0 => out should become the lowest 8 bits
    dut.sel.value = 0
    dut.bypass.value = 0

    # If there's a register on output, allow 2 cycles for stable output
    cycles_to_stabilize = 2 if REGISTER_OUTPUT else 1
    for _ in range(cycles_to_stabilize):
        await RisingEdge(dut.clk)

    expected = test_inp & 0xFF
    observed = dut.out.value.integer
    assert observed == expected, f"test_basic sel=0 => expected 0x{expected:02X}, got 0x{observed:02X}"

    # Turn on bypass => always select inp_array[0] (lowest 8 bits)
    dut.bypass.value = 1
    for _ in range(cycles_to_stabilize):
        await RisingEdge(dut.clk)

    observed = dut.out.value.integer
    assert observed == expected, f"test_basic bypass=1 => expected 0x{expected:02X}, got 0x{observed:02X}"

@cocotb.test()
async def test_random(dut):
    """Random Input Test - restrict sel to valid 2-bit range"""
    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())
    await reset_dut(dut)

    max_bits = 8 * NUM_INPUTS
    cycles_to_stabilize = 2 if REGISTER_OUTPUT else 1

    for _ in range(5):
        rand_inp = random.getrandbits(max_bits)
        # Since sel is 2 bits when NUM_INPUTS=4, only use sel=0..3
        # If you'd like to cover out-of-range, widen 'sel' or skip that scenario.
        rand_sel = random.randint(0, NUM_INPUTS - 1)
        rand_bypass = random.randint(0, 1)

        dut.inp.value = rand_inp
        dut.sel.value = rand_sel
        dut.bypass.value = rand_bypass

        # Allow enough clock cycles for output to settle
        for _ in range(cycles_to_stabilize):
            await RisingEdge(dut.clk)

        observed = dut.out.value.integer

        if rand_bypass == 1:
            expected = rand_inp & 0xFF
        else:
            # Valid range => extract the correct byte
            shift_amt = rand_sel * 8
            expected = (rand_inp >> shift_amt) & 0xFF

        assert observed == expected, (
            f"[RANDOM] inp=0x{rand_inp:08X}, sel={rand_sel}, bypass={rand_bypass}, "
            f"expected=0x{expected:02X}, got=0x{observed:02X}"
        )

@cocotb.test()
async def test_edge_cases(dut):
    """Edge / Boundary Conditions"""
    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())
    await reset_dut(dut)

    max_bits = 8 * NUM_INPUTS
    cycles_to_stabilize = 2 if REGISTER_OUTPUT else 1

    # 1) Check highest valid sel => sel=NUM_INPUTS-1
    pattern_inp = 0x12345678 & ((1 << max_bits) - 1)
    dut.inp.value = pattern_inp
    dut.sel.value = NUM_INPUTS - 1
    dut.bypass.value = 0

    for _ in range(cycles_to_stabilize):
        await RisingEdge(dut.clk)

    observed = dut.out.value.integer
    shift_amt = (NUM_INPUTS - 1) * 8
    expected = (pattern_inp >> shift_amt) & 0xFF
    assert observed == expected, (
        f"[EDGE] sel={NUM_INPUTS-1}, expected=0x{expected:02X}, got=0x{observed:02X}"
    )

    # 2) If you truly want to test out-of-range sel, either:
    #    A) Widen 'sel' in the Verilog, or
    #    B) skip it here. This code below is commented out to avoid overflow:
    #
    # dut.sel.value = NUM_INPUTS  # e.g., 4 => out of range for 2-bit
    # for _ in range(cycles_to_stabilize):
    #     await RisingEdge(dut.clk)
    #
    # observed = dut.out.value.integer
    # if HAS_DEFAULT == 1:
    #     # Suppose we expect 0x55 for default
    #     expected = 0x55
    #     assert observed == expected, f"[EDGE] Out-of-range sel => default mismatch"
    # else:
    #     # No default => can't check reliably
    #     pass
