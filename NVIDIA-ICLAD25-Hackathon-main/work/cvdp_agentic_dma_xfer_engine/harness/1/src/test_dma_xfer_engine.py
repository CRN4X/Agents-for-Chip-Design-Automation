import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

async def write_reg(dut, reg_addr, data):
    """
    Replicates the 'write_reg' task from SystemVerilog.
    
    - Drive the signals on a falling edge so they are stable before the next rising edge.
    - Release them after the subsequent rising edge.
    """
    # Wait for falling edge
    await FallingEdge(dut.clk)
    dut.addr.value = reg_addr
    dut.we.value   = 1
    dut.wd.value   = data

    # Wait one rising edge so the DUT can capture
    await RisingEdge(dut.clk)

    # Deassert signals on the next falling edge
    await FallingEdge(dut.clk)
    dut.addr.value = 0
    dut.we.value   = 0
    dut.wd.value   = 0
    dut._log.info(f"WRITE reg 0x{reg_addr:X} <= 0x{data:08X}")


async def read_reg(dut, reg_addr):
    """
    Replicates the 'read_reg' task from SystemVerilog.
    
    - Drive the address on a falling edge, hold it through the rising edge.
    - Capture the read data after the rising edge.
    """
    await FallingEdge(dut.clk)
    dut.addr.value = reg_addr
    dut.we.value   = 0

    await RisingEdge(dut.clk)
    data_out = dut.rd.value.integer

    # Deassert signals
    await FallingEdge(dut.clk)
    dut.addr.value = 0
    dut._log.info(f"READ reg 0x{reg_addr:X} => 0x{data_out:08X}")
    return data_out


async def trigger_dma(dut):
    """
    Replicates the 'trigger_dma' task: Pulse dma_req for one cycle.
    """
    await FallingEdge(dut.clk)
    dut.dma_req.value = 1

    await RisingEdge(dut.clk)
    dut.dma_req.value = 0
    dut._log.info("DMA request triggered")


async def wait_for_dma_done(dut):
    """
    Replicates the 'wait_for_dma_done' task: Wait until bus_req deasserts, then 2 more cycles.
    """
    # Wait until bus_req == 0
    while dut.bus_req.value.integer != 0:
        await RisingEdge(dut.clk)

    # Extra cycles for the FSM to settle
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut._log.info("DMA transfer completed")


def calc_increment(size):
    """
    Same logic as the original 'calc_increment' function in SV.
    """
    if size == 0:  # Byte
        return 1
    elif size == 1:  # Halfword
        return 2
    elif size == 2:  # Word
        return 4
    return 4


async def test_register_rw(dut):
    """Test 1: Register Read/Write"""
    dut._log.info("\n====================\nTest 1: Register Read/Write\n====================")

    # Write 0x123 to the control register's lowest 10 bits
    await write_reg(dut, 0, (0 << 10) | 0x123)  # 0x123 in bits [9:0]
    read_data = await read_reg(dut, 0)
    if (read_data & 0x3FF) == 0x123:
        dut._log.info("TEST 1 PASS: DMA_CR register readback matches")
    else:
        dut._log.error(f"TEST 1 FAIL: DMA_CR mismatch (got 0x{read_data & 0x3FF:X}, expected 0x123)")

    # Write / read source address
    await write_reg(dut, 4, 0x1000_0000)
    read_data = await read_reg(dut, 4)
    if read_data == 0x1000_0000:
        dut._log.info("TEST 1 PASS: DMA_SRC_ADR correct")
    else:
        dut._log.error("TEST 1 FAIL: DMA_SRC_ADR mismatch")

    # Write / read dest address
    await write_reg(dut, 8, 0x2000_0000)
    read_data = await read_reg(dut, 8)
    if read_data == 0x2000_0000:
        dut._log.info("TEST 1 PASS: DMA_DST_ADR correct")
    else:
        dut._log.error("TEST 1 FAIL: DMA_DST_ADR mismatch")


async def test_dma_word_mode(dut):
    """Test 2: DMA Transfer in Word Mode with Increments"""
    dut._log.info("\n====================\nTest 2: Word Mode (DMA_W) with Increments\n====================")

    # CR: count=2, src_size=2'b10, dst_size=2'b10, inc_src/dst=1
    cr_val = (0b010 << 7) | (2 << 5) | (2 << 3) | (1 << 2) | (1 << 1) | 0
    # However, the bit positions in your actual design may differ; adapt as needed.
    # For instance: {3'b010, 2'b10, 2'b10, 1'b1, 1'b1, 1'b0} => bits: cnt(3) + src/dst(2+2) + inc_src/dst + line_en

    await write_reg(dut, 0, cr_val)
    await write_reg(dut, 4, 0x1000_0000)  # src_base
    await write_reg(dut, 8, 0x2000_0000)  # dst_base

    await trigger_dma(dut)
    await wait_for_dma_done(dut)

    # Check bus_req deassert
    if dut.bus_req.value.integer != 0:
        dut._log.error("TEST 2 FAIL: bus_req not deasserted at end")
    else:
        dut._log.info("TEST 2 PASS: bus_req deasserted as expected")

    inc = calc_increment(2)
    dut._log.info(f"TEST 2 INFO: Word increment = {inc} bytes")


async def test_dma_halfword_mode(dut):
    """Test 3: DMA Transfer in Halfword Mode with Increments"""
    dut._log.info("\n====================\nTest 3: Halfword Mode (DMA_HW) with Increments\n====================")

    # {3'b011, 2'b01, 2'b01, inc_src=1, inc_dst=1, line_en=0}
    # count=3, src_size=01, dst_size=01 => halfword, inc=1
    cr_val = (0b011 << 7) | (1 << 5) | (1 << 3) | (1 << 2) | (1 << 1)

    await write_reg(dut, 0, cr_val)
    await write_reg(dut, 4, 0x3000_0000)  # src_base
    await write_reg(dut, 8, 0x4000_0000)  # dst_base

    await trigger_dma(dut)
    await wait_for_dma_done(dut)

    if dut.bus_req.value.integer != 0:
        dut._log.error("TEST 3 FAIL: bus_req not deasserted at end")
    else:
        dut._log.info("TEST 3 PASS: bus_req deasserted as expected")

    inc = calc_increment(1)
    dut._log.info(f"TEST 3 INFO: Halfword increment = {inc} bytes")


async def test_dma_byte_mode(dut):
    """Test 4: DMA Transfer in Byte Mode with Increments"""
    dut._log.info("\n====================\nTest 4: Byte Mode (DMA_B) with Increments\n====================")

    # {3'b100, 2'b00, 2'b00, inc_src=1, inc_dst=1, line_en=0}
    cr_val = (0b100 << 7) | (0 << 5) | (0 << 3) | (1 << 2) | (1 << 1)

    await write_reg(dut, 0, cr_val)
    await write_reg(dut, 4, 0x5000_0000)  # src_base
    await write_reg(dut, 8, 0x6000_0000)  # dst_base

    await trigger_dma(dut)
    await wait_for_dma_done(dut)

    if dut.bus_req.value.integer != 0:
        dut._log.error("TEST 4 FAIL: bus_req not deasserted at end")
    else:
        dut._log.info("TEST 4 PASS: bus_req deasserted as expected")

    inc = calc_increment(0)
    dut._log.info(f"TEST 4 INFO: Byte increment = {inc} bytes")


async def test_dma_no_increment(dut):
    """Test 5: DMA Transfer with No Increment"""
    dut._log.info("\n====================\nTest 5: No Increments (inc_src=0, inc_dst=0)\n====================")

    # {3'b010, 2'b10, 2'b10, inc_src=0, inc_dst=0, line_en=0}
    cr_val = (0b010 << 7) | (2 << 5) | (2 << 3) | (0 << 2) | (0 << 1)

    await write_reg(dut, 0, cr_val)
    await write_reg(dut, 4, 0x7000_0000)  # src_base
    await write_reg(dut, 8, 0x8000_0000)  # dst_base

    await trigger_dma(dut)
    await wait_for_dma_done(dut)

    if dut.bus_req.value.integer != 0:
        dut._log.error("TEST 5 FAIL: bus_req not deasserted at end")
    else:
        dut._log.info("TEST 5 PASS: bus_req deasserted as expected")


async def test_reset_behavior(dut):
    """Test 6: Reset Behavior"""
    dut._log.info("\n====================\nTest 6: Reset Behavior\n====================")

    await FallingEdge(dut.clk)
    dut.rstn.value = 0
    await RisingEdge(dut.clk)
    dut.rstn.value = 1
    await RisingEdge(dut.clk)

    if (dut.bus_req.value.integer != 0) or (dut.bus_lock.value.integer != 0):
        dut._log.error("TEST 6 FAIL: bus_req or bus_lock did not reset properly")
    else:
        dut._log.info("TEST 6 PASS: Reset behavior is correct")


async def test_single_byte_aligned(dut):
    """Test 7: Single Byte Transfer (Aligned)"""
    dut._log.info("\n====================\nTest 7: Single Byte Transfer (Aligned)\n====================")

    # count=1, src_size=dst_size= byte(00), inc_src=inc_dst=1
    cr_val = 0
    # Transfer count in bits [2:0] => 1
    # src_size in bits [4:3] => 0
    # dst_size in bits [6:5] => 0
    # inc_src=bit[7]=1, inc_dst=bit[8]=1
    cr_val |= (1 << 0)   # 1 in cnt
    cr_val |= (1 << 7)   # inc_src
    cr_val |= (1 << 8)   # inc_dst

    # Aligned addresses => lower 2 bits == 0
    src_addr = 0x10
    dst_addr = 0x100

    await write_reg(dut, 0, cr_val)
    await write_reg(dut, 4, src_addr)
    await write_reg(dut, 8, dst_addr)

    await trigger_dma(dut)
    await wait_for_dma_done(dut)

    if dut.bus_req.value.integer != 0:
        dut._log.error("TEST 7 FAIL: bus_req not deasserted at end")
    else:
        dut._log.info("TEST 7 PASS: bus_req deasserted as expected")

    dut._log.info(
        f"TEST 7 INFO: Single byte (aligned) transfer from 0x{src_addr:08X} => 0x{dst_addr:08X} completed."
    )


#
# Main entry point for Cocotb
#
@cocotb.test()
async def run_dma_tests(dut):
    """
    This is the main Cocotb test that replaces the initial block in SystemVerilog.
    It generates a clock, applies reset, and runs each sub-test in sequence.
    """

    # 1) Generate clock (10 ns period)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # 2) Initialize signals
    dut.rstn.value    = 0
    dut.we.value      = 0
    dut.wd.value      = 0
    dut.addr.value    = 0
    dut.dma_req.value = 0
    dut.bus_grant.value = 0

    # 3) Wait 20 ns, then deassert reset
    await Timer(20, units="ns")
    dut.rstn.value = 1
    await Timer(20, units="ns")

    #
    # Optional: a simple approach to replicate "always_ff @posedge clk bus_grant <= bus_req".
    # We can do it in Python by polling bus_req each cycle. Or keep that logic in the HDL if needed.
    #
    # For demonstration, we'll do a lightweight driver that always grants if bus_req is high.
    #
    async def bus_grant_driver():
        while True:
            await RisingEdge(dut.clk)
            if dut.rstn.value == 0:
                dut.bus_grant.value = 0
            else:
                dut.bus_grant.value = dut.bus_req.value

    cocotb.start_soon(bus_grant_driver())

    # 4) Run the individual sub-tests in sequence
    await test_register_rw(dut)
    await test_dma_word_mode(dut)
    await test_dma_halfword_mode(dut)
    await test_dma_byte_mode(dut)
    await test_dma_no_increment(dut)
    await test_reset_behavior(dut)
    await test_single_byte_aligned(dut)

    dut._log.info("\nAll tests completed.")
    # An extra delay
    await Timer(50, units="ns")
