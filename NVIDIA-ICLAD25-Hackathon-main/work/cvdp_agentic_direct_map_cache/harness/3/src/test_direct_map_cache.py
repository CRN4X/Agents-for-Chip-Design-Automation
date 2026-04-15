import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
import random

# Global state for read/write comparisons
stored_index = 0
stored_offset = 0
stored_tag = 0
stored_data = 0

@cocotb.test()
async def test_direct_map_cache(dut):
    # Start the clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    await reset_dut(dut)

    await write_access(dut, comp=0)
    await read_access(dut, comp=1)
    await compare_write(dut)
    await read_access(dut, comp=1)
    await miss_test(dut)
    await read_access(dut, comp=0)
    await force_offset_error(dut)
    await corner_case_zero_tag_index(dut)
    await corner_case_max_tag_index(dut)
    await corner_case_toggle_enable(dut)
    await victimway_assertion(dut)

def get_param(dut, name):
    return int(getattr(dut, name).value)

async def reset_dut(dut):
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
    dut._log.info("[RESET] Complete")

async def write_access(dut, comp):
    global stored_index, stored_offset, stored_tag, stored_data
    cache_size   = int(dut.CACHE_SIZE.value)
    data_width   = int(dut.DATA_WIDTH.value)
    tag_width    = int(dut.TAG_WIDTH.value)
    offset_width = int(dut.OFFSET_WIDTH.value)
    index_width  = int(dut.INDEX_WIDTH.value)

    stored_index = random.randint(0, cache_size - 1)
    stored_offset = random.randint(0, (1 << offset_width) - 1) & ~1
    stored_tag = random.randint(0, (1 << tag_width) - 1)
    stored_data = random.randint(0, (1 << data_width) - 1)

    dut.enable.value = 1
    dut.comp.value = comp
    dut.write.value = 1
    dut.valid_in.value = 1
    dut.index.value = stored_index
    dut.offset.value = stored_offset
    dut.tag_in.value = stored_tag
    dut.data_in.value = stored_data

    await RisingEdge(dut.clk)
    dut._log.info(f"[WRITE_COMP{comp}] idx={stored_index}, off={stored_offset}, tag={stored_tag}, data={stored_data:04X}")

async def read_access(dut, comp):
    global stored_index, stored_offset, stored_tag, stored_data

    dut.enable.value = 1
    dut.comp.value = comp
    dut.write.value = 0
    dut.index.value = stored_index
    dut.offset.value = stored_offset
    dut.tag_in.value = stored_tag

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    dout = int(dut.data_out.value)
    hit = dut.hit.value
    valid = dut.valid.value

    dut._log.info(f"[READ_COMP{comp}] idx={stored_index}, off={stored_offset}, tag={stored_tag}, dout={dout:04X}, hit={hit}, valid={valid}")

    if not dut.error.value:
        if hit and valid and dout == stored_data:
            dut._log.info("  [PASS] Data matched on read.")
        else:
            dut._log.error("  [FAIL] Data mismatch or miss.")

async def compare_write(dut):
    global stored_data
    data_width = get_param(dut, "DATA_WIDTH")
    new_data = random.randint(0, (1 << data_width) - 1)
    stored_data = new_data

    dut.enable.value = 1
    dut.comp.value = 1
    dut.write.value = 1
    dut.valid_in.value = 1
    dut.data_in.value = new_data

    await RisingEdge(dut.clk)

    hit = dut.hit.value
    dirty = dut.dirty.value
    dut._log.info(f"[WRITE_COMP1] dirty={dirty}, hit={hit}, data={new_data:04X}")

async def miss_test(dut):
    cache_size = get_param(dut, "CACHE_SIZE")
    offset_width = get_param(dut, "OFFSET_WIDTH")
    tag_width = get_param(dut, "TAG_WIDTH")
    new_index = (stored_index + 1) % cache_size
    new_offset = random.randint(0, (1 << offset_width) - 1) & ~1
    new_tag = random.randint(0, (1 << tag_width) - 1)

    dut.enable.value = 1
    dut.comp.value = 1
    dut.write.value = 0
    dut.index.value = new_index
    dut.offset.value = new_offset
    dut.tag_in.value = new_tag

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    hit = dut.hit.value
    dut._log.info(f"[MISS_TEST] idx={new_index}, off={new_offset}, tag={new_tag}, hit={hit}")
    if hit == 0:
        dut._log.info("  [PASS] Expected miss")
    else:
        dut._log.error("  [FAIL] Unexpected hit on miss test")

async def force_offset_error(dut):
    dut.enable.value = 1
    dut.comp.value = 0
    dut.write.value = 0
    dut.index.value = 0
    dut.offset.value = 0b001  # Misaligned
    dut.tag_in.value = 0
    dut.data_in.value = 0

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    check_error(dut, dut.offset.value, dut.error.value, "OFFSET_ERROR")

async def corner_case_zero_tag_index(dut):
    data_width = get_param(dut, "DATA_WIDTH")
    dut.enable.value = 1
    dut.comp.value = 1
    dut.write.value = 1
    dut.index.value = 0
    dut.offset.value = 0
    dut.tag_in.value = 0
    dut.data_in.value = 0xABCD & ((1 << data_width) - 1)
    dut.valid_in.value = 1
    await RisingEdge(dut.clk)
    dut._log.info("[CORNER] Write with zero index and zero tag")

async def corner_case_max_tag_index(dut):
    cache_size = get_param(dut, "CACHE_SIZE")
    tag_width = get_param(dut, "TAG_WIDTH")
    data_width = get_param(dut, "DATA_WIDTH")
    dut.enable.value = 1
    dut.comp.value = 1
    dut.write.value = 1
    dut.index.value = cache_size - 1
    dut.offset.value = 0
    dut.tag_in.value = (1 << tag_width) - 1
    dut.data_in.value = 0x1234 & ((1 << data_width) - 1)
    dut.valid_in.value = 1
    await RisingEdge(dut.clk)
    dut._log.info("[CORNER] Write with max index and max tag")

async def corner_case_toggle_enable(dut):
    global stored_index, stored_offset, stored_tag
    dut.enable.value = 0
    dut.comp.value = 1
    dut.write.value = 0
    dut.index.value = stored_index
    dut.offset.value = stored_offset
    dut.tag_in.value = stored_tag
    await RisingEdge(dut.clk)
    dut._log.info("[CORNER] Access with enable low")
    if dut.valid.value == 1 or dut.hit.value == 1:
        dut._log.error("  [FAIL] Outputs should be zero when enable is low")
    else:
        dut._log.info("  [PASS] Outputs correctly reset when enable is low")

def check_error(dut, offset_val, err_signal, context=""):
    if int(offset_val) & 0x1:
        if (err_signal):
            dut._log.info(f"  [PASS] ERROR asserted as expected in {context} (offset LSB=1)")
        else:
            dut._log.error(f"  [FAIL] ERROR not asserted in {context} (expected offset LSB=1)")
    else:
        if (err_signal):
            dut._log.error(f"  [FAIL] ERROR incorrectly asserted in {context} (offset LSB=0)")
        else:
            dut._log.info(f"  [PASS] No error in {context} (offset aligned)")

async def victimway_assertion(dut):
    # Select a test index (e.g. 7)
    test_index = 7
    cache_size = get_param(dut, "CACHE_SIZE")
    tag_width = get_param(dut, "TAG_WIDTH")
    data_width = get_param(dut, "DATA_WIDTH")
    # First, perform an access write (comp=0, write=1) to fill the cache for this index.
    # In an "access" mode write, both ways are written.
    dut.enable.value = 1
    dut.comp.value = 0  # access write mode
    dut.write.value = 1
    dut.index.value = test_index
    dut.offset.value = 0  # aligned offset (LSB=0)
    dut.tag_in.value = 0xA  & ((1 << tag_width) - 1)
    dut.data_in.value = 0x1234 & ((1 << data_width) - 1)
    dut.valid_in.value = 1
    await RisingEdge(dut.clk)
    dut._log.info(f"[VICTIM] Filled index {test_index} with tag 0xA (access write updates both ways)")

    # Now, perform a compare write (comp=1, write=1) with a mismatching tag so that a miss occurs.
    prev_victim = int(dut.victimway.value)
    new_tag = 0xB  & ((1 << tag_width) - 1)
    dut.enable.value = 1
    dut.comp.value = 1
    dut.write.value = 1
    dut.index.value = test_index
    dut.offset.value = 0  # aligned offset
    dut.tag_in.value = new_tag
    dut.data_in.value = 0x5678 & ((1 << data_width) - 1)
    dut.valid_in.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    new_victim = int(dut.victimway.value)
    dut._log.info(f"[VICTIM] Compare write at index {test_index} with tag 0xB: previous victim={prev_victim}, new victim={new_victim}")

    # Assert that victimway toggled during the replace.
    assert new_victim == (1 - prev_victim), \
      f"Victimway did not toggle properly: was {prev_victim}, now {new_victim}"
    dut._log.info("  [PASS] Victimway toggled correctly on compare write miss")
