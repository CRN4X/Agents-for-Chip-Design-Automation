import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

import harness_library as hrs_lb



@cocotb.test()
async def test_direct_map_cache(dut):
    # Global variables for storing the last written cache line address/data
    stored_index = 0
    stored_offset = 0
    stored_tag = 0
    stored_data = 0


    """
    A Cocotb testbench that:
        1) Resets the DUT
        2) Write with comp=0 (write_comp0)
        3) Read with comp=1 (read_comp1) -> expected hit
        4) Write with comp=1 (write_comp1)
        5) Read with comp=1 (read_comp1) -> expected hit
        6) miss_test (random new index -> force a miss)
        7) Write with comp=1 (write_comp1)
        8) Read with comp=0 (read_comp0)
        9) force_offset_error -> sets offset LSB=1 to check error
    """
    # Extract parameters from the DUT
    cache_size   = int(dut.CACHE_SIZE.value)
    data_width   = int(dut.DATA_WIDTH.value)
    tag_width    = int(dut.TAG_WIDTH.value)
    offset_width = int(dut.OFFSET_WIDTH.value)
    index_width  = int(dut.INDEX_WIDTH.value)

    # Log the parameters for debugging
    dut._log.info(f"Detected DUT parameters:")
    dut._log.info(f"  CACHE_SIZE   = {cache_size}")
    dut._log.info(f"  DATA_WIDTH   = {data_width}")
    dut._log.info(f"  TAG_WIDTH    = {tag_width}")
    dut._log.info(f"  OFFSET_WIDTH = {offset_width}")
    dut._log.info(f"  INDEX_WIDTH  = {index_width}")
    
    # Start the clock (10 ns period)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await hrs_lb.dut_init(dut)

    # 1) Reset the DUT
    await reset_dut(dut)

    # 2) Write with comp=0
    await write_comp0(dut, cache_size, data_width, tag_width, offset_width)

    # 3) Read with comp=1 -> expect a hit
    await read_comp1(dut)

    # 4) Write with comp=1
    await write_comp1(dut, cache_size, data_width)

    # 5) Read with comp=1 -> expect a hit
    await read_comp1(dut)

    # 6) Miss test -> force a miss by using a different index
    await miss_test(dut, cache_size, tag_width, offset_width)

    # 7) Write with comp=1
    await write_comp1(dut, cache_size, data_width)

    # 8) Read with comp=0
    await read_comp0(dut)

    # 9) Force offset error
    await force_offset_error(dut)

    dut._log.info("All test steps completed successfully.")


async def reset_dut(dut):
    """Reset the DUT for a few clock cycles."""
    dut.rst.value = 1
    dut.enable.value = 0
    dut.comp.value = 0
    dut.write.value = 0
    dut.index.value = 0
    dut.offset.value = 0
    dut.tag_in.value = 0
    dut.data_in.value = 0
    dut.valid_in.value = 0

    for _ in range(3):
        await RisingEdge(dut.clk)

    dut.rst.value = 0
    await RisingEdge(dut.clk)
    dut._log.info("[RESET] Completed")


async def write_comp0(dut, cache_size, data_width, tag_width, offset_width):
    """
    "Access Write (comp=0, write=1)"
    We'll randomize index, offset (LSB=0), tag, data_in.
    """
    global stored_index, stored_offset, stored_tag, stored_data

    dut.enable.value = 1
    dut.comp.value = 0
    dut.write.value = 1
    dut.valid_in.value = 1

    # Generate random index, offset, tag, data
    index_val  = random.randint(0, cache_size - 1)
    offset_val = random.randint(0, (1 << offset_width) - 1) & ~1  # LSB=0
    tag_val    = random.randint(0, (1 << tag_width) - 1)
    data_val   = random.randint(0, (1 << data_width) - 1)

    # Store for later reads
    stored_index  = index_val
    stored_offset = offset_val
    stored_tag    = tag_val
    stored_data   = data_val

    # Drive signals
    dut.index.value  = index_val
    dut.offset.value = offset_val
    dut.tag_in.value = tag_val
    dut.data_in.value= data_val

    await RisingEdge(dut.clk)
    dut._log.info(f"[WRITE_COMP0] idx={index_val}, off={offset_val}, tag={tag_val:02X}, data={data_val:04X}")

    # Check that no error is triggered
    if dut.error.value == 1:
        dut._log.error("**ERROR**: Unexpected 'error' during write_comp0")


async def read_comp1(dut):
    """
    "Compare Read (comp=1, write=0)"
    Expect a hit and correct data if reading the last written address.
    """
    global stored_index, stored_offset, stored_tag, stored_data

    dut.enable.value = 1
    dut.comp.value = 1
    dut.write.value = 0

    # Re-apply the same stored info
    dut.index.value  = stored_index
    dut.offset.value = stored_offset
    dut.tag_in.value = stored_tag

    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    read_data = int(dut.data_out.value)
    hit_val   = dut.hit.value
    valid_val = dut.valid.value

    dut._log.info(f"[READ_COMP1] idx={stored_index}, off={stored_offset}, "
                  f"tag={stored_tag:02X}, dout={read_data:04X}, valid={valid_val}, hit={hit_val}")

    # Check for hit and data match
    if hit_val and valid_val and (read_data == stored_data):
        dut._log.info("  PASS: Read hit and data matched.")
    else:
        dut._log.error("  FAIL: Expected a read hit or data mismatch!")

    # Check no unexpected error
    if dut.error.value == 1:
        dut._log.error("**ERROR**: Unexpected 'error' during read_comp1")


async def write_comp1(dut, cache_size, data_width):
    """
    "Compare Write (comp=1, write=1)"
    If the same index/tag is used, we should see a hit and line become dirty.
    """
    global stored_index, stored_offset, stored_tag, stored_data

    dut.enable.value = 1
    dut.comp.value = 1
    dut.write.value = 1
    dut.valid_in.value = 1

    # Keep the stored index/tag/offset, change data
    new_data = random.randint(0, (1 << data_width) - 1)
    stored_data = new_data

    dut.index.value  = stored_index
    dut.offset.value = stored_offset
    dut.tag_in.value = stored_tag
    dut.data_in.value= new_data

    await FallingEdge(dut.clk)
    hit_val   = dut.hit.value
    dirty_val = dut.dirty.value
    valid_val = dut.valid.value

    dut._log.info(f"[WRITE_COMP1] idx={stored_index}, off={stored_offset}, "
                  f"tag={stored_tag:02X}, data={new_data:04X}, hit={hit_val}, dirty={dirty_val}, valid={valid_val}")

    # If it's the same index/tag, we expect a hit
    if hit_val == 1 and valid_val == 1:
        # The DUT may set dirty=1 on a compare write to an existing line
        if dirty_val == 1:
            dut._log.info("  PASS: Compare write hit, line is now dirty as expected.")
        else:
            dut._log.warning("  WARNING: Compare write hit but dirty bit not set.")
    else:
        dut._log.info("  Miss or newly allocated line (dirty might be 0).")

    # Check no error
    if dut.error.value == 1:
        dut._log.error("**ERROR**: Unexpected 'error' during write_comp1")


async def read_comp0(dut):
    """
    "Access Read (comp=0, write=0)"
    The given DUT logic typically won't compare tags => we usually expect hit=0.
    """
    global stored_index, stored_offset, stored_tag

    dut.enable.value = 1
    dut.comp.value = 0
    dut.write.value = 0

    dut.index.value  = stored_index
    dut.offset.value = stored_offset
    dut.tag_in.value = stored_tag

    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    hit_val   = dut.hit.value
    err_val   = dut.error.value
    dut._log.info(f"[READ_COMP0] idx={stored_index}, off={stored_offset}, tag={stored_tag:02X}, hit={hit_val}")

    if err_val == 1:
        dut._log.error("**ERROR**: Unexpected 'error' during read_comp0")


async def miss_test(dut, cache_size, tag_width, offset_width):
    """
    Force a read miss by picking a new index that differs from the stored one.
    comp=1, write=0 -> read compare -> expect hit=0.
    """
    global stored_index

    dut.enable.value = 1
    dut.comp.value = 1
    dut.write.value = 0

    # Force a different index to guarantee a miss
    new_index = (stored_index + 1) % cache_size
    new_offset = random.randint(0, (1 << offset_width) - 1) & ~1
    new_tag = random.randint(0, (1 << tag_width) - 1)

    dut.index.value  = new_index
    dut.offset.value = new_offset
    dut.tag_in.value = new_tag

    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    hit_val = dut.hit.value

    dut._log.info(f"[MISS_TEST] new_idx={new_index}, off={new_offset}, tag={new_tag:02X}, hit={hit_val}")
    if hit_val == 0:
        dut._log.info("  PASS: Expected miss, got hit=0.")
    else:
        dut._log.error("  FAIL: Unexpected hit=1, expected a miss!")

    if dut.error.value == 1:
        dut._log.error("**ERROR**: Unexpected 'error' during miss_test")


async def force_offset_error(dut):
    """
    Set offset's LSB=1 => should trigger error=1.
    """
    dut.enable.value = 1
    dut.comp.value = 0
    dut.write.value = 0

    # Force offset with LSB=1
    dut.offset.value = 0b001
    dut.index.value  = 0
    dut.tag_in.value = 0
    dut.data_in.value= 0

    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    err_val = dut.error.value
    dut._log.info(f"[OFFSET_ERROR_TEST] offset={dut.offset.value}, error={err_val}")

    if err_val == 1:
        dut._log.info("  PASS: 'error' asserted as expected when offset LSB=1.")
    else:
        dut._log.error("  FAIL: 'error' did not assert with offset LSB=1!")