import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

###############################################################################
# Global scoreboard / tracking
###############################################################################
write_queue = []  # Stores reference data written to the FIFO

async def report_error(msg):
    """Simple mechanism to raise an assertion error (increments error count)."""
    raise AssertionError(f"[ERROR] {msg}")

###############################################################################
# Utility / Helper Tasks
###############################################################################
async def apply_reset(dut, cycles=2):
    """Apply and release reset."""
    dut.reset.value = 1
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.reset.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)

async def write_data(dut, data_in):
    """Write a byte into the DUT FIFO and store it in the scoreboard."""
    await RisingEdge(dut.clk)
    dut.wr_valid_i.value = 1
    dut.wr_payload_i.value = data_in
    write_queue.append(data_in)
    await RisingEdge(dut.clk)
    dut.wr_valid_i.value = 0
    dut.wr_payload_i.value = 0
    await RisingEdge(dut.clk)

async def read_data_item(dut):
    """Read a byte from the DUT and compare with the scoreboard."""
    if len(write_queue) == 0:
        await report_error("Read requested but scoreboard is empty")
        return

    # Drive read
    await RisingEdge(dut.clk)
    dut.rd_valid_i.value = 1
    await RisingEdge(dut.clk)
    dut.rd_valid_i.value = 0

    # Sample read data
    read_data = dut.rd_payload_o.value.integer

    # Compare with the oldest data in scoreboard
    expected_data = write_queue.pop(0)
    if read_data != expected_data:
        await report_error(
            f"Read data mismatch. Expected 0x{expected_data:02X}, got 0x{read_data:02X}"
        )

    await RisingEdge(dut.clk)

###############################################################################
# Scenarios
###############################################################################
async def scenario1_reset_behavior(dut):
    """
    Scenario #1: Reset Behavior
      - After reset, qacceptn_o == 1, qactive_o == 0, wr_flush_o == 0
    """
    cocotb.log.info("--- SCENARIO 1: Reset Behavior ---")
    await RisingEdge(dut.clk)  # Wait at least one cycle after reset
    if dut.qacceptn_o.value != 1:
        await report_error("qacceptn_o should be 1 after reset")
    if dut.qactive_o.value != 0:
        await report_error("qactive_o should be 0 after reset")
    if dut.wr_flush_o.value != 0:
        await report_error("wr_flush_o should be 0 after reset")

async def scenario2_write_read(dut):
    """
    Scenario #2: Simple Write/Read
      - Data read = Data written (in order).
      - No unexpected assertions of wr_flush_o.
    """
    cocotb.log.info("--- SCENARIO 2: Simple Write/Read ---")
    # Write three bytes
    await write_data(dut, 0xAA)
    await write_data(dut, 0xBB)
    await write_data(dut, 0xCC)

    # Read them back
    await read_data_item(dut)  # expects 0xAA
    await read_data_item(dut)  # expects 0xBB
    await read_data_item(dut)  # expects 0xCC

    # Check no flush triggered
    if dut.wr_flush_o.value != 0:
        await report_error("wr_flush_o should not assert in normal write/read")

async def scenario3_fifo_overflow_attempt(dut):
    """
    Scenario #3: FIFO Overflow Attempt
      - Write more data than FIFO depth, then read it out
      - Check behavior with lost data, ignoring pushes, etc.
    """
    cocotb.log.info("--- SCENARIO 3: FIFO Overflow Attempt ---")
    # Example assumption: FIFO depth is 6. Write 8 consecutive items
    for i in range(8):
        await write_data(dut, i)

    # Now read them back 8 times
    for _ in range(8):
        await read_data_item(dut)
    cocotb.log.info("Check for mismatch errors or stable behavior above.")

async def scenario4_fifo_underflow_attempt(dut):
    """
    Scenario #4: FIFO Underflow Attempt
      - Attempt reading from empty FIFO
      - Ensure no corruption or invalid flush/hang states
    """
    cocotb.log.info("--- SCENARIO 4: FIFO Underflow Attempt ---")
    for _ in range(3):
        await RisingEdge(dut.clk)
        dut.rd_valid_i.value = 1
        await RisingEdge(dut.clk)
        dut.rd_valid_i.value = 0
        cocotb.log.info(f"Read data = 0x{dut.rd_payload_o.value.integer:02X} (empty FIFO)")

async def scenario5_qreq_flush_handshake(dut):
    """
    Scenario #5: QREQ Handshake and Flush
      - wr_flush_o asserts when qreqn_i goes low, remains until wr_done_i=1 & FIFO empties
      - qacceptn_o goes low once flush completes (ST_Q_STOPPED)
    """
    cocotb.log.info("--- SCENARIO 5: QREQ Handshake and Flush ---")
    # 1) Put some data in FIFO
    await write_data(dut, 0xA0)
    await write_data(dut, 0xB1)

    # 2) Keep wr_done_i low
    dut.wr_done_i.value = 0

    # 3) Pull qreqn_i low => ST_Q_REQUEST => expect wr_flush_o=1
    await RisingEdge(dut.clk)
    dut.qreqn_i.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    if dut.wr_flush_o.value != 1:
        await report_error("wr_flush_o should assert in ST_Q_REQUEST")

    # 4) Now let flush complete: wr_done_i=1, read out data, check flush deassert
    await read_data_item(dut)  # read 0xA0
    await read_data_item(dut)  # read 0xB1

    await RisingEdge(dut.clk)
    dut.wr_done_i.value = 1
    for _ in range(2):
        await RisingEdge(dut.clk)

    if dut.wr_flush_o.value != 0:
        await report_error("wr_flush_o should deassert after flush completes")
    if dut.qacceptn_o.value != 0:
        await report_error("qacceptn_o should be 0 in ST_Q_STOPPED")

    # 5) Re-assert qreqn_i => back to ST_Q_RUN => qacceptn_o=1 eventually
    await RisingEdge(dut.clk)
    dut.qreqn_i.value = 1
    for _ in range(4):
        await RisingEdge(dut.clk)
    if dut.qacceptn_o.value != 1:
        await report_error("qacceptn_o should return to 1 in ST_Q_RUN")

    # Return signals to idle
    dut.wr_done_i.value = 0

async def scenario6_wakeup_signal_test(dut):
    """
    Scenario #6: Wakeup Signal Check
      - if_wakeup_i=1 with empty FIFO => qactive_o=1
      - if_wakeup_i=0 => qactive_o=0 if no FIFO activity
    """
    cocotb.log.info("--- SCENARIO 6: Wakeup Signal Check ---")
    dut.if_wakeup_i.value = 1
    await RisingEdge(dut.clk)
    if dut.qactive_o.value != 1:
        await report_error("qactive_o should be 1 due to wakeup")

    dut.if_wakeup_i.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    if dut.qactive_o.value != 0:
        await report_error("qactive_o should go 0 after wakeup cleared & FIFO idle")

###############################################################################
# Main Test
###############################################################################
@cocotb.test()
async def test_low_power_channel(dut):
    """Top-level cocotb test for low_power_channel."""
    # Create a clock on dut.clk, 10ns period => 100MHz
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Initialize signals
    dut.reset.value        = 0
    dut.if_wakeup_i.value  = 0
    dut.wr_valid_i.value   = 0
    dut.wr_payload_i.value = 0
    dut.wr_done_i.value    = 0
    dut.rd_valid_i.value   = 0
    dut.qreqn_i.value      = 1

    # Apply reset
    await apply_reset(dut)

    # Run scenarios in order
    await scenario1_reset_behavior(dut)
    await scenario2_write_read(dut)
    await scenario3_fifo_overflow_attempt(dut)
    await scenario4_fifo_underflow_attempt(dut)
    await scenario5_qreq_flush_handshake(dut)
    await scenario6_wakeup_signal_test(dut)

    cocotb.log.info("All scenarios completed. If no assertion errors, test PASSED!")
