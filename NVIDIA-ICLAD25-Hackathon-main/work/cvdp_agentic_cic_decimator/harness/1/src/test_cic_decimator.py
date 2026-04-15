import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

async def monitor(dut):
    """Monitor task to print key signals at every rising edge."""
    while True:
        await RisingEdge(dut.clk)
        dut._log.info(
            "clk=%s, rst=%s, input_tdata=%s, input_tvalid=%s, input_tready=%s, output_tdata=%s, output_tvalid=%s",
            dut.clk.value,
            dut.rst.value,
            dut.input_tdata.value,
            dut.input_tvalid.value,
            dut.input_tready.value,
            dut.output_tdata.value,
            dut.output_tvalid.value
        )

@cocotb.test()
async def test_cic_decimator(dut):
    """Testbench for the cic_decimator DUT."""
    # Start clock generation with a 10 ns period (5 ns high, 5 ns low)
    clock = Clock(dut.clk, 5, units="ns")
    cocotb.start_soon(clock.start())

    # Start the monitor coroutine to log signal values every rising edge.
    cocotb.start_soon(monitor(dut))

    # Initialize signals
    dut.rst.value           = 1
    dut.input_tdata.value   = 0
    dut.input_tvalid.value  = 0
    dut.output_tready.value = 1  # downstream is always ready
    dut.rate.value          = 1  # start with decimation rate 1

    # Apply reset for 20 ns and then deassert it.
    await Timer(20, units="ns")
    dut.rst.value = 0

    # Wait a couple of clock cycles for stabilization.
    for _ in range(2):
        await RisingEdge(dut.clk)

    #---------------------------------------------------------------------------
    # Test Sequence 1: rate = 1
    #---------------------------------------------------------------------------
    dut._log.info("--- Test Sequence 1: rate = 1 ---")
    for j in range(10):
        await RisingEdge(dut.clk)
        dut.input_tdata.value  = j
        dut.input_tvalid.value = 1
    # Deassert input_tvalid to simulate an idle period.
    await RisingEdge(dut.clk)
    dut.input_tvalid.value = 0

    # Wait a few clock cycles to allow output observation.
    await Timer(50, units="ns")

    #---------------------------------------------------------------------------
    # Test Sequence 2: rate = 2
    #---------------------------------------------------------------------------
    dut._log.info("--- Test Sequence 2: rate = 2 ---")
    dut.rate.value = 2
    for j in range(10):
        await RisingEdge(dut.clk)
        dut.input_tdata.value  = j + 100  # offset pattern
        dut.input_tvalid.value = 1
    await RisingEdge(dut.clk)
    dut.input_tvalid.value = 0

    # Allow simulation to run further to capture final outputs.
    await Timer(100, units="ns")

