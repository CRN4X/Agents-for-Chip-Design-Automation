import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from cocotb.result import TestFailure, TestSuccess
import random

@cocotb.test()
async def test_rl_queue(dut):
    """
    Cocotb-based test replicating the original SystemVerilog testbench
    for a parameterized fall-through queue.
    """
    # Create a 10 ns period clock on clk_i
    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Initialize DUT inputs
    dut.rst_ni.value = 0
    dut.clr_i.value  = 0
    dut.ena_i.value  = 1
    dut.we_i.value   = 0
    dut.re_i.value   = 0
    dut.d_i.value    = 0

    # Wait 15 ns, then release reset
    await Timer(15, units="ns")
    dut.rst_ni.value = 1
    await Timer(10, units="ns")

    #--------------------------------------------------------------------------
    # Test 1: Reset Test
    # After reset, the queue should be empty, q_o should be 0
    #--------------------------------------------------------------------------
    if (dut.empty_o.value == 1) and (int(dut.q_o.value) == 0):
        dut._log.info("PASS: Test 1: Reset Test")
    else:
        raise TestFailure(
            f"FAIL: Test 1: Reset Test, expected q_o=0 & empty_o=1. "
            f"Got q_o={int(dut.q_o.value)}, empty_o={dut.empty_o.value}"
        )

    #--------------------------------------------------------------------------
    # Test 2: Single Write Test
    # Write one element and check that the output shows the written data
    #--------------------------------------------------------------------------
    dut.we_i.value = 1
    dut.d_i.value  = 0xA5A5_A5A5
    await Timer(10, units="ns")

    dut.we_i.value = 0
    await Timer(10, units="ns")

    if int(dut.q_o.value) == 0xA5A5_A5A5:
        dut._log.info("PASS: Test 2: Single Write Test")
    else:
        raise TestFailure(
            f"FAIL: Test 2: Single Write Test, expected 0xA5A5A5A5, got 0x{int(dut.q_o.value):08X}"
        )

    #--------------------------------------------------------------------------
    # Test 3: Clear Test
    # Use synchronous clear (clr_i) to reset the queue
    #--------------------------------------------------------------------------
    dut.clr_i.value = 1
    await Timer(10, units="ns")
    dut.clr_i.value = 0
    await Timer(10, units="ns")

    if dut.empty_o.value == 1:
        dut._log.info("PASS: Test 3: Clear Test")
    else:
        raise TestFailure(
            "FAIL: Test 3: Clear Test, expected empty_o=1 after clr_i"
        )

    #--------------------------------------------------------------------------
    # Test 4: Simultaneous Write/Read on an Empty Queue
    #--------------------------------------------------------------------------
    dut.we_i.value = 1
    dut.re_i.value = 1
    dut.d_i.value  = 0xDEAD_BEEF
    await Timer(10, units="ns")

    dut.we_i.value = 0
    dut.re_i.value = 0
    await Timer(10, units="ns")

    if int(dut.q_o.value) == 0xDEADBEEF:
        dut._log.info("PASS: Test 4: Simultaneous Write/Read on Empty Queue")
    else:
        raise TestFailure(
            f"FAIL: Test 4: Simultaneous Write/Read on Empty Queue, expected 0xDEADBEEF, got 0x{int(dut.q_o.value):08X}"
        )

    #--------------------------------------------------------------------------
    # Test 5: Fill the Queue (Write Only)
    # Write DEPTH-1 elements to drive the pointer toward the full condition
    #--------------------------------------------------------------------------
    # (Depth is 4 by default in the example, so we write 3 elements here.)
    depth_val = 4  # Adjust if needed or read from a parameter
    for i in range(depth_val - 1):
        dut.we_i.value = 1
        dut.re_i.value = 0
        dut.d_i.value  = i + 1
        await Timer(10, units="ns")

        dut.we_i.value = 0
        await Timer(10, units="ns")

    if dut.full_o.value == 1:
        dut._log.info("PASS: Test 5: Full Condition Test")
    else:
        raise TestFailure(
            f"FAIL: Test 5: Full Condition Test, expected full_o=1, got {dut.full_o.value}"
        )

    #--------------------------------------------------------------------------
    # Test 6: Read Until Empty
    # Perform read-only operations until the queue is empty
    #--------------------------------------------------------------------------
    while dut.empty_o.value != 1:
        dut.re_i.value = 1
        dut.we_i.value = 0
        await Timer(10, units="ns")

        dut.re_i.value = 0
        await Timer(10, units="ns")

    if dut.empty_o.value == 1:
        dut._log.info("PASS: Test 6: Read Until Empty Test")
    else:
        raise TestFailure(
            f"FAIL: Test 6: Read Until Empty Test, expected empty_o=1, got {dut.empty_o.value}"
        )

    #--------------------------------------------------------------------------
    # Test 7: Simultaneous Write/Read on a Non-Empty Queue
    #--------------------------------------------------------------------------
    # Write two elements
    dut.we_i.value = 1
    dut.re_i.value = 0
    dut.d_i.value  = 0x1111_1111
    await Timer(10, units="ns")

    dut.we_i.value = 0
    await Timer(10, units="ns")

    dut.we_i.value = 1
    dut.d_i.value  = 0x2222_2222
    await Timer(10, units="ns")

    dut.we_i.value = 0
    await Timer(10, units="ns")

    # Now, perform simultaneous read/write
    dut.we_i.value = 1
    dut.re_i.value = 1
    dut.d_i.value  = 0x3333_3333
    await Timer(10, units="ns")

    dut.we_i.value = 0
    dut.re_i.value = 0
    await Timer(10, units="ns")

    if int(dut.q_o.value) == 0x2222_2222:
        dut._log.info("PASS: Test 7: Simultaneous Write/Read on Non-Empty Queue")
    else:
        raise TestFailure(
            f"FAIL: Test 7: Simultaneous Write/Read on Non-Empty Queue, expected 0x2222_2222, got 0x{int(dut.q_o.value):08X}"
        )

    #--------------------------------------------------------------------------
    # Test 8: Check Programmable Thresholds for Almost Empty/Full
    #--------------------------------------------------------------------------
    # Write elements until the almost_full condition is met
    while (dut.almost_full_o.value != 1) and (dut.full_o.value != 1):
        dut.we_i.value = 1
        dut.re_i.value = 0
        # Use random data
        dut.d_i.value  = random.randint(0, (1 << 32) - 1)
        await Timer(10, units="ns")

        dut.we_i.value = 0
        await Timer(10, units="ns")

    if dut.almost_full_o.value == 1:
        dut._log.info("PASS: Test 8a: Almost Full Threshold Test")
    else:
        raise TestFailure(
            f"FAIL: Test 8a: Almost Full Threshold Test, expected almost_full_o=1, got {dut.almost_full_o.value}"
        )

    # Now, read until almost_empty is reached
    while (dut.almost_empty_o.value != 1) and (dut.empty_o.value != 1):
        dut.re_i.value = 1
        dut.we_i.value = 0
        await Timer(10, units="ns")

        dut.re_i.value = 0
        await Timer(10, units="ns")

    if dut.almost_empty_o.value == 1:
        dut._log.info("PASS: Test 8b: Almost Empty Threshold Test")
    else:
        raise TestFailure(
            f"FAIL: Test 8b: Almost Empty Threshold Test, expected almost_empty_o=1, got {dut.almost_empty_o.value}"
        )

    dut._log.info("Testbench simulation complete.")
    raise TestSuccess("All tests passed successfully!")
