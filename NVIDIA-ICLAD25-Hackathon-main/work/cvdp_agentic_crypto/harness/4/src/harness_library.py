
from cocotb.binary import BinaryValue
from cocotb.triggers import FallingEdge, RisingEdge, Timer

CLK_HALF_PERIOD = 1
CLK_PERIOD = CLK_HALF_PERIOD * 2
CLK_TIME_UNIT = 'ns'

async def dut_init(dut):
    # iterate all the input signals and initialize with 0
    for signal in dut:
        if signal._type == "GPI_NET":
            signal.value = 0

async def init_sim(dut):
    dut.reset_n.value = 1
    dut.init.value = 0
    dut.update.value = 0
    dut.finish.value = 0
    dut.block.value = 0
    dut.blocklen.value = 0

async def reset_dut(dut):
    dut.reset_n.value = 0
    await Timer(2 * CLK_PERIOD, units=CLK_TIME_UNIT)
    dut.reset_n.value = 1
    await Timer(2 * CLK_PERIOD, units=CLK_TIME_UNIT)

async def wait_ready(dut):
    while dut.ready.value.integer != 1:
        await FallingEdge(dut.clk)

async def ready_after_init(dut):
    dut.init.value = 1
    await Timer(CLK_PERIOD, units=CLK_TIME_UNIT)

    dut.init.value = 0
    await wait_ready(dut)

async def one_block_message_test(
        dut, block_len: BinaryValue, block: BinaryValue, expected: BinaryValue):

    dut.init.value = 1
    await Timer(CLK_PERIOD, units=CLK_TIME_UNIT)

    dut.init.value = 0
    await wait_ready(dut)
    # await FallingEdge(dut.clk) # Not required

    dut.blocklen.value = block_len
    dut.block.value = block
    dut.finish.value = 1
    await FallingEdge(dut.clk)

    dut.finish.value = 0
    await wait_ready(dut)
    # await FallingEdge(dut.clk) # Not required

    assert dut.digest.value == expected, "didn't get the expected digest output"

async def multiple_block_message_test(
        dut, block_lengths: list[BinaryValue], blocks: list[BinaryValue], expected: BinaryValue):

    assert len(block_lengths) == len(blocks), "argument lists size mismatch"
    assert len(blocks) > 0, "cannot process an empty list"

    block_index = 0
    while block_index < len(blocks) - 1:
        dut.init.value = 1
        await Timer(CLK_PERIOD, units=CLK_TIME_UNIT)

        dut.init.value = 0
        await wait_ready(dut)
        await FallingEdge(dut.clk) # Not required

        dut.blocklen.value = block_lengths[block_index]
        dut.block.value = blocks[block_index]
        dut.update.value = 1
        await FallingEdge(dut.clk)

        dut.update.value = 0
        await wait_ready(dut)
        await FallingEdge(dut.clk) # Not required

        block_index += 1

    # Final part
    dut.blocklen.value = block_lengths[block_index]
    dut.block.value = blocks[block_index]
    dut.finish.value = 1
    await FallingEdge(dut.clk)

    dut.finish.value = 0
    await wait_ready(dut)
    await FallingEdge(dut.clk) # Not required

    assert dut.digest.value == expected, "didn't get the expected digest output"
