import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_ttc_counter_lite(dut):
    """
    Cocotb-based testbench for the ttc_counter_lite module.
    """

    # Generate clock (100 MHz -> 10 ns period)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Initialize DUT signals
    #await hrs_lb.dut_init(dut)

    # Reset DUT
    dut.reset.value = 1
    await Timer(20, units="ns")
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    # Helper function to write to AXI
    async def axi_write(addr, data):
        dut.axi_addr.value = addr
        dut.axi_wdata.value = data
        dut.axi_write_en.value = 1
        await RisingEdge(dut.clk)
        dut.axi_write_en.value = 0
        await RisingEdge(dut.clk)

    # Helper function to read from AXI
    async def axi_read(addr):
        dut.axi_addr.value = addr
        dut.axi_read_en.value = 1
        await RisingEdge(dut.clk)
        dut.axi_read_en.value = 0
        await RisingEdge(dut.clk)
        read_value = int(dut.axi_rdata.value)
        dut._log.info(f"[READ] Address: {addr:#x}, Data: {read_value:#x}")
        return read_value

    # *Set register values as per Verilog TB*
    
    # 1. Set match value to 8 (Verilog: axi_wdata = 32'h0000008)
    await axi_write(0x1, 0x8)
    assert dut.match_value.value == 0x8, "[ERROR] Match value not set correctly"

    # 2. Set reload value to 10 (axi_wdata = 32'h0000000A)
    await axi_write(0x2, 0xA)
    assert dut.reload_value.value == 0xA, "[ERROR] Reload value not set correctly"

    # 3. Configure control register (Enable=1, Interval=1, Interrupt Enable=1)
    await axi_write(0x3, 0x7)
    assert dut.enable.value == 1, "[ERROR] Control register enable not set"
    assert dut.interval_mode.value == 1, "[ERROR] Interval mode not set"
    assert dut.interrupt_enable.value == 1, "[ERROR] Interrupt enable not set"

    # 4. Set prescaler value to 3 (axi_wdata = 32'h00000003)
     # Set prescaler value to 3 (counter increments every 4th cycle)
    await axi_write(0x5, 0x3)  # Prescaler set to 3 (counter updates every 4th cycle)

    # Ensure the counter increments only after 4 cycles
    initial_count = int(dut.count.value)

    # Wait for 3 clock cycles (no change should occur)
    for _ in range(3):
        await RisingEdge(dut.clk)
        assert int(dut.count.value) == initial_count, f"[ERROR] Counter updated before 4 cycles. Count: {int(dut.count.value)}"

    # On the 4th clock cycle, the counter should increment
    await RisingEdge(dut.clk)
    assert int(dut.count.value) == initial_count + 1, f"[ERROR] Counter did not increment correctly on 4th cycle. Expected: {initial_count + 1}, Got: {int(dut.count.value)}"

    dut._log.info(f"[CHECK] Counter increments every 4 cycles correctly. Count: {int(dut.count.value)}")    # *Wait for counter to increment*
    await Timer(200, units="ns")

    # 5. Read and verify counter value
    count_val = await axi_read(0x0)
    assert 0x6 <= count_val <= 0x8, f"[ERROR] Counter value out of range: {count_val}"

    # 6. Wait and check interrupt status
    await Timer(50, units="ns")
    assert dut.interrupt.value == 1, "[ERROR] Interrupt not asserted!"
    
    interrupt_status = await axi_read(0x4)
    assert interrupt_status == 1, "[ERROR] Interrupt status mismatch!"

    # 7. Clear interrupt and verify
    dut.axi_addr.value = 0x4
    dut.axi_wdata.value = 0
    dut.axi_write_en.value = 1
    await RisingEdge(dut.clk)
    await Timer(50, units="ns")
 
    dut.axi_write_en.value = 0
   # await RisingEdge(dut.clk)
    assert dut.interrupt.value == 0,f"[ERROR] Interrupt not cleared{dut.interrupt.value}"

    dut._log.info("[INFO] Simulation completed successfully!")