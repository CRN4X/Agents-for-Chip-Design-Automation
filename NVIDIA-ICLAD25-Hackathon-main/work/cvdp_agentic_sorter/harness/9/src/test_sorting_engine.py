import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

def pack_vector(vec, width):
    """
    Pack a list of integers (representing elements A[0] to A[7]) into a flat integer.
    The flat vector is constructed as {A[7], A[6], ..., A[0]} so that A[0] maps to the LSB.
    """
    value = 0
    for x in reversed(vec):  # Reverse order: MSB is A[7]
        value = (value << width) | (x & ((1 << width) - 1))
    return value

async def reset_dut(dut):
    """
    Reset the DUT by asserting rst for a couple of clock cycles.
    """
    dut.rst.value = 1
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

async def run_test(dut, test_name, input_vec, expected_vec, width):
    """
    Apply a test vector to the DUT, check the output, and measure latency.
    Both input_vec and expected_vec are lists of NUM_ELEMS values.
    """
    NUM_ELEMS = len(input_vec)
    dut._log.info("***** Starting Test: %s *****", test_name)

    # Pack the input and expected arrays into flat integers.
    input_flat    = pack_vector(input_vec, width)
    expected_flat = pack_vector(expected_vec, width)

    # Drive the input vector and ensure start is low.
    dut.in_data.value = input_flat
    dut.start.value   = 0

    # Reset the DUT to initialize for this test.
    await reset_dut(dut)

    # Issue a start pulse for one clock cycle.
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Measure latency: count the number of clock cycles from after the start pulse until done is asserted.
    latency = 0
    while True:
        await RisingEdge(dut.clk)
        latency += 1
        if int(dut.done.value) == 1:
            break

    # Expected latency in clock cycles for the provided RTL FSM.
    expected_latency = 17
    if latency != expected_latency:
        dut._log.error("Test %s FAILED: Expected latency %d cycles, got %d cycles", test_name, expected_latency, latency)
        assert False, f"Latency check failed for test {test_name}: expected {expected_latency}, got {latency}"
    else:
        dut._log.info("Latency check passed for test %s: %d cycles", test_name, latency)

    # Compare the DUT's output with the expected flat vector.
    out_val = int(dut.out_data.value)
    if out_val != expected_flat:
        dut._log.error("Test %s FAILED!", test_name)
        dut._log.error("   Input   : 0x%0*x", (NUM_ELEMS * width + 3) // 4, input_flat)
        dut._log.error("   Expected: 0x%0*x", (NUM_ELEMS * width + 3) // 4, expected_flat)
        dut._log.error("   Got     : 0x%0*x", (NUM_ELEMS * width + 3) // 4, out_val)
        assert False, f"Test {test_name} failed: output mismatch!"
    else:
        dut._log.info("Test %s PASSED.", test_name)
    # Small delay between tests
    await Timer(10, units="ns")

@cocotb.test()
async def test_sorting_engine(dut):
    """
    Cocotb Testbench for the sorting_engine module.
    This test applies multiple corner-case test vectors (with each element's width determined by the DUT parameter)
    and performs a latency check on each test.
    """
    # Create and start a clock with a 10 ns period.
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Retrieve the WIDTH parameter from the DUT; default to 8 if not available.
    try:
        width = int(dut.WIDTH.value)
    except Exception as e:
        dut._log.warning("Could not get WIDTH from DUT (defaulting to 8). Error: %s", e)
        width = 8

    NUM_ELEMS = 8
    max_val = (1 << width) - 1

    #--------------------------------------------------------------------------
    # Test 1: Already Sorted
    # Internal array A: [1, 2, 3, 4, 5, 6, 7, 8]
    # Ensure values are within the range of the given width.
    test_in = [min(i, max_val) for i in [1, 2, 3, 4, 5, 6, 7, 8]]
    expected = sorted(test_in)
    await run_test(dut, "Already Sorted", test_in, expected, width)

    #--------------------------------------------------------------------------
    # Test 2: Reverse Sorted
    test_in = [min(i, max_val) for i in [8, 7, 6, 5, 4, 3, 2, 1]]
    expected = sorted(test_in)
    await run_test(dut, "Reverse Sorted", test_in, expected, width)

    #--------------------------------------------------------------------------
    # Test 3: Random Unsorted Data
    test_in = [min(x, max_val) for x in [0x12, 0x34, 0x23, 0x45, 0x67, 0x56, 0x89, 0x78]]
    expected = sorted(test_in)
    await run_test(dut, "Random Unsorted", test_in, expected, width)

    #--------------------------------------------------------------------------
    # Test 4: All Elements Equal
    test_in = [max_val // 2] * NUM_ELEMS
    expected = [max_val // 2] * NUM_ELEMS
    await run_test(dut, "All Equal", test_in, expected, width)

    #--------------------------------------------------------------------------
    # Test 5: Edge Values
    if width == 8:
        # For WIDTH==8, use specific edge values.
        test_in = [0x00, 0xFF, 0x10, 0xF0, 0x01, 0xFE, 0x02, 0xFD]
    else:
        # Scale the 8-bit edge values to the current width.
        test_in = [
            0,
            max_val,
            math.floor(0x10 * max_val / 0xFF),
            math.floor(0xF0 * max_val / 0xFF),
            1 if max_val >= 1 else 0,
            math.floor(0xFE * max_val / 0xFF),
            2 if max_val >= 2 else 0,
            math.floor(0xFD * max_val / 0xFF)
        ]
    expected = sorted(test_in)
    await run_test(dut, "Edge Values", test_in, expected, width)

    #--------------------------------------------------------------------------
    # Test 6: Consecutive Operations
    test_in = [min(x, max_val) for x in [9, 3, 15, 1, 10, 2, 11, 4]]
    expected = sorted(test_in)
    await run_test(dut, "Consecutive Operation 1", test_in, expected, width)

    test_in = [min(x, max_val) for x in [16, 32, 48, 64, 80, 96, 112, 128]]
    expected = sorted(test_in)
    await run_test(dut, "Consecutive Operation 2", test_in, expected, width)
