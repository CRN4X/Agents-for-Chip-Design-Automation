import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

#
# Helper function to apply asynchronous reset
#
async def apply_reset(dut):
    """Drives rst_n low, waits, then drives it high."""
    dut.rst_n.value = 0
    # Wait 12 ns while reset is low
    await Timer(12, units="ns")
    # Bring reset high
    dut.rst_n.value = 1
    # Wait additional time for the DUT to stabilize
    await Timer(10, units="ns")

#
# Helper function to run a single cipher operation
#
async def run_cipher_operation(
    dut,
    t_data_in: int,
    t_key: int,
    check_expected: bool,
    expected_out: int
):
    """
    Applies the given data_in and key to the DUT, pulses 'start',
    waits for 'done', and optionally checks the output against an expected value.
    """
    # Wait for rising edge before changing inputs
    await RisingEdge(dut.clk)
    dut.data_in.value = t_data_in
    dut.key.value = t_key
    dut.start.value = 1  # Pulse 'start' for 1 cycle

    # Next clock
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait until done is asserted
    while dut.done.value != 1:
        await RisingEdge(dut.clk)

    # Wait one more clock to latch output
    await RisingEdge(dut.clk)

    # If checking a known expected value, compare
    if check_expected:
        actual = dut.data_out.value.integer
        if actual != expected_out:
            dut._log.error(
                f"ERROR: Output mismatch. data_in={t_data_in:08X}, key={t_key:04X}, "
                f"Expected={expected_out:08X}, Got={actual:08X}"
            )
        else:
            dut._log.info(
                f"PASS: data_in={t_data_in:08X}, key={t_key:04X} => data_out={actual:08X} (as expected)"
            )
    else:
        dut._log.info(
            f"INFO: data_in={t_data_in:08X}, key={t_key:04X} => data_out={dut.data_out.value.integer:08X}"
        )


@cocotb.test()
async def test_cipher(dut):
    """
    Main test sequence replicating the original SystemVerilog testbench behavior.
    """
    # Create a 10ns period clock on dut.clk
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Initialize signals
    dut.rst_n.value = 1
    dut.data_in.value = 0
    dut.key.value = 0
    dut.start.value = 0

    dut._log.info("=== Starting cipher_tb simulation under Cocotb ===")

    #
    # 1) Apply async reset
    #
    await apply_reset(dut)

    #
    # 2) Check IDLE hold if start=0
    #
    dut._log.info("Checking IDLE hold with no start...")
    for _ in range(3):
        await RisingEdge(dut.clk)

    #
    # 3) Known test vector with expected result
    #
    dut._log.info("Testing known vector with pass/fail check...")
    await run_cipher_operation(dut,
                               t_data_in=0x12345678,
                               t_key=0xABCD,
                               check_expected=True,
                               expected_out=0x352454F2)

    #
    # 4) Zero data, zero key
    #
    dut._log.info("Testing zero data/key...")
    await run_cipher_operation(dut,
                               t_data_in=0x00000000,
                               t_key=0x0000,
                               check_expected=False,
                               expected_out=0)

    #
    # 5) All-ones data, key
    #
    dut._log.info("Testing all-ones data/key...")
    await run_cipher_operation(dut,
                               t_data_in=0xFFFFFFFF,
                               t_key=0xFFFF,
                               check_expected=False,
                               expected_out=0)

    #
    # 6) Random examples
    #
    dut._log.info("Testing random inputs...")
    await run_cipher_operation(dut, 0xA5A5F0F0, 0x1234, False, 0)
    await run_cipher_operation(dut, 0xDEADBEEF, 0xFFFF, False, 0)

    #
    # 7) Test mid-operation reset
    #
    dut._log.info("Testing mid-operation reset...")
    # Start operation
    dut.data_in.value = 0x11112222
    dut.key.value = 0x3333
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Let the FSM run a few cycles, then reset
    for _ in range(3):
        await RisingEdge(dut.clk)
    await apply_reset(dut)

    #
    # 8) Operation after mid-op reset
    #
    dut._log.info("Operation after mid-op reset...")
    await run_cipher_operation(dut, 0xCAFEBABE, 0xABCD, False, 0)

    #
    # 9) Multiple consecutive operations
    #
    dut._log.info("Testing multiple consecutive ops...")
    await run_cipher_operation(dut, 0xAAAA0000, 0x1234, False, 0)
    await run_cipher_operation(dut, 0xBBBB1111, 0x5555, False, 0)

    dut._log.info("=== All tests completed. Check logs for pass/fail ===")
