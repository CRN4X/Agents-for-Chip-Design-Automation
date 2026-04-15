import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

import random

################################################################################
# Utility / Setup
################################################################################

async def reset_wr_domain(dut, cycles=5):
    """
    Reset the write domain of the DUT.
    The reset is active low, so set it to 0, wait a few clock cycles, then set it to 1.
    """
    dut.i_wr_rst_n.value = 0
    # Wait for a few rising edges on the write clock
    for i in range(cycles):
        await RisingEdge(dut.i_wr_clk)
    dut.i_wr_rst_n.value = 1
    # Wait one more cycle to let DUT stabilize
    await RisingEdge(dut.i_wr_clk)


async def reset_rd_domain(dut, cycles=5):
    """
    Reset the read domain of the DUT.
    The reset is active low, so set it to 0, wait a few clock cycles, then set it to 1.
    """
    dut.i_rd_rst_n.value = 0
    # Wait for a few rising edges on the read clock
    for i in range(cycles):
        await RisingEdge(dut.i_rd_clk)
    dut.i_rd_rst_n.value = 1
    # Wait one more cycle to let DUT stabilize
    await RisingEdge(dut.i_rd_clk)

async def reset_dut(dut):
    """Reset the DUT (Device Under Test)"""
    # Set all input signals to their default values
    dut.i_wr_clk.value = 0
    dut.i_wr_rst_n.value = 0
    dut.i_wr_en.value = 0
    dut.i_wr_data.value = 0
    dut.i_rd_clk.value = 0
    dut.i_rd_rst_n.value = 0
    dut.i_rd_en.value = 0

    # Wait for a clock cycle before releasing the reset
    await FallingEdge(dut.i_rd_clk)
    dut.i_rd_rst_n.value = 1
    await FallingEdge(dut.i_wr_clk)
    dut.i_wr_rst_n.value = 1
    await RisingEdge(dut.i_wr_clk)


@cocotb.test()
async def test_async_fifo(dut):
    """
    Top-level test that drives the asynchronous FIFO with multiple scenarios
    to exercise read/write domain resets, empties, full conditions, etc.
    """

    ############################################################################
    # 1. Create asynchronous clocks for write and read domains
    ############################################################################
    # For example, write clock = 10ns period, read clock = 17ns period
    cocotb.start_soon(Clock(dut.i_wr_clk, 10, units='ns').start())
    cocotb.start_soon(Clock(dut.i_rd_clk, 17, units='ns').start())

    ############################################################################
    # 2. Reset both domains
    ############################################################################
    # Initially drive control signals to default
    await reset_dut(dut)

    # Short wait after reset
    await Timer(1, units="ns")

    ############################################################################
    # 3. Test #1: Basic Reset & Empty Test
    ############################################################################
    dut._log.info("=== TEST #1: Basic Reset & Empty Test ===")

    # Confirm FIFO is empty after reset
    assert dut.o_fifo_empty.value == 1, "FIFO should be empty after reset"
    assert dut.o_fifo_full.value == 0,  "FIFO should not be full after reset"

    # Attempt to read from empty FIFO
    dut.i_rd_en.value = 1
    for i in range(3):
        await RisingEdge(dut.i_rd_clk)
    dut.i_rd_en.value = 0

    # FIFO should remain empty
    assert dut.o_fifo_empty.value == 1, "FIFO unexpectedly became non-empty"

    await Timer(1, units="ns")

    ############################################################################
    # 4. Test #2: Single Write & Read
    ############################################################################
    dut._log.info("=== TEST #2: Single Write & Read ===")

    test_data = 0xABCD1234

    # Write a single data word
    dut.i_wr_data.value = test_data
    dut.i_wr_en.value   = 1
    for i in range(2):
        await RisingEdge(dut.i_wr_clk)
    dut.i_wr_en.value   = 0

    # Wait a bit for pointer synchronization
    await Timer(100, units="ns")

    # Now read it back
    dut.i_rd_en.value = 1
    for i in range(2):
        await RisingEdge(dut.i_rd_clk)
    dut.i_rd_en.value = 0

    # Check read data
    read_value = dut.o_rd_data.value.integer
    dut._log.info(f"Read value = 0x{read_value:08X}")
    assert read_value == test_data, f"Data mismatch! Got: 0x{read_value:08X}, Expected: 0x{test_data:08X}"

    # FIFO should be empty again
    await RisingEdge(dut.i_rd_clk)
    assert dut.o_fifo_empty.value == 1, "FIFO should be empty after single read"

    await Timer(2, units="ns")

    ############################################################################
    # 5. Test #3: Fill and Drain (Full → Empty)
    ############################################################################
    dut._log.info("=== TEST #3: Fill and Drain (Full -> Empty) ===")

    write_count = 0
    read_count  = 0
    scoreboard  = []

    # Start writing data until FIFO is full
    await FallingEdge(dut.i_wr_clk)
    dut.i_wr_en.value = 1
    while True:
        dut.i_wr_data.value = write_count
        await RisingEdge(dut.i_wr_clk)
        if dut.o_fifo_full.value == 1:
            # FIFO is full, stop writing
            dut.i_wr_en.value = 0
            dut._log.info(f"FIFO is FULL after writing {write_count+1} words.")
            break
        else:
            scoreboard.append(write_count)
            write_count += 1

    # Now read until empty
    await FallingEdge(dut.i_rd_clk)
    dut.i_rd_en.value = 1
    await FallingEdge(dut.i_rd_clk)
    while True:
        await RisingEdge(dut.i_rd_clk)
        if dut.o_fifo_empty.value == 1:
            dut.i_rd_en.value = 0
            dut._log.info(f"FIFO is EMPTY after reading {read_count} words.")
            break
        expected_data = scoreboard[read_count]
        read_val      = dut.o_rd_data.value
        assert read_val == expected_data, f"Mismatch on read! Expected={expected_data}, Got={read_val}"
        read_count += 1

    await Timer(2, units="ns")



    ############################################################################
    # 6. Test #4: Partial Writes, Then Partial Reads
    ############################################################################
    dut._log.info("=== TEST #5: Partial Writes, Then Partial Reads ===")

    # Re-apply reset to start fresh
    await reset_dut(dut)

    # Step 5a: Write some portion (less than full)
    scoreboard = []
    write_limit = 50  # Arbitrary for partial test
    await FallingEdge(dut.i_wr_clk)
    dut.i_wr_en.value = 1

    for i in range(write_limit):
        dut.i_wr_data.value = i
        await RisingEdge(dut.i_wr_clk)
        scoreboard.append(i)
        if dut.o_fifo_full.value == 1:
            dut._log.info("Reached FIFO full while attempting partial fill.")
            break
    dut.i_wr_en.value = 0

    # Check we are not empty
    assert dut.o_fifo_empty.value == 0, "FIFO unexpectedly empty after partial write"

    # Step 5b: Read only half
    read_amount = write_limit // 2
    await FallingEdge(dut.i_rd_clk)
    dut.i_rd_en.value = 1
    await FallingEdge(dut.i_rd_clk)
    read_count = 0
    for i in range(read_amount):
        await RisingEdge(dut.i_rd_clk)
        if dut.o_fifo_empty.value == 1:
            dut._log.warning("FIFO went empty earlier than expected.")
            break
        got_data = dut.o_rd_data.value.integer
        exp_data = scoreboard[read_count]
        assert got_data == exp_data, f"Mismatch partial read. Got={got_data}, Exp={exp_data}"
        read_count += 1

    dut.i_rd_en.value = 0

    # Ensure we haven't fully emptied unless we read everything
    if read_count < len(scoreboard):
        assert dut.o_fifo_empty.value == 0, "FIFO went empty too soon."

    dut._log.info("Partial write/read scenario completed.")

    ############################################################################
    # 7. Test #5: Mid-Operation Resets
    ############################################################################
    dut._log.info("=== TEST #6: Mid-Operation Resets ===")

    # Start writing some data
    scoreboard_wr = []
    scoreboard_rd = []
    await FallingEdge(dut.i_wr_clk)
    dut.i_wr_en.value = 1

    for i in range(10):
        dut.i_wr_data.value = i
        scoreboard_wr.append(i)
        await RisingEdge(dut.i_wr_clk)

    # Assert reset in the write domain mid-operation
    dut._log.info("Asserting write domain reset mid-operation...")
    dut.i_wr_en.value = 0
    dut.i_wr_rst_n.value = 0
    for i in range(3):
        await RisingEdge(dut.i_wr_clk)
    dut.i_wr_rst_n.value = 1
    await RisingEdge(dut.i_wr_clk)
    dut.i_wr_en.value = 0

    # After write-domain reset, FIFO should not appear empty from the write perspective
    assert dut.o_fifo_empty.value == 0, "FIFO empty after write-domain reset"

    # Write more data so the read side has something
    for i in range(5):
        dut.i_wr_data.value = 100 + i
        dut.i_wr_en.value = 1
        await RisingEdge(dut.i_wr_clk)
    dut.i_wr_en.value = 0

    # Now read a couple words
    await FallingEdge(dut.i_rd_clk)
    dut.i_rd_en.value = 1
    await FallingEdge(dut.i_rd_clk)
    for i in range(2):
        await RisingEdge(dut.i_rd_clk)

    # Reset read domain mid-operation
    dut._log.info("Asserting read domain reset mid-operation...")
    dut.i_rd_rst_n.value = 0
    dut.i_rd_en.value = 0
    for i in range(3):
        await RisingEdge(dut.i_rd_clk)
    dut.i_rd_rst_n.value = 1
    await RisingEdge(dut.i_rd_clk)

    # After read-domain reset, FIFO should appear empty from read perspective
    assert dut.o_fifo_empty.value == 1, "FIFO not empty after read-domain reset"
    dut.i_rd_en.value = 0

    dut._log.info("Mid-operation resets scenario completed.")

    ############################################################################
    # End
    ############################################################################
    dut._log.info("=== All done. All test scenarios completed successfully! ===")
