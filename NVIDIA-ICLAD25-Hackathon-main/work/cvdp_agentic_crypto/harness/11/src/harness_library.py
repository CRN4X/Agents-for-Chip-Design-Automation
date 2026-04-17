
from cocotb.binary import BinaryValue
from cocotb.triggers import FallingEdge, RisingEdge, Timer

CLK_HALF_PERIOD = 1
CLK_PERIOD = CLK_HALF_PERIOD * 2
CLK_TIME_UNIT = 'ns'

ADDR_NAME0       = BinaryValue(0, 8, False)
ADDR_NAME1       = BinaryValue(1, 8, False)
ADDR_VERSION     = BinaryValue(2, 8, False)

ADDR_CTRL        = BinaryValue(8, 8, False)
CTRL_INIT_BIT    = 0
CTRL_UPDATE_BIT  = 1
CTRL_FINISH_BIT  = 2

ADDR_STATUS      = BinaryValue(int('9', 16), 8, False)
STATUS_READY_BIT = 0

ADDR_BLOCKLEN    = BinaryValue(int('0a', 16), 8, False)

ADDR_BLOCK0      = BinaryValue(int('10', 16), 8, False)
ADDR_BLOCK15     = BinaryValue(int('1f', 16), 8, False)

ADDR_DIGEST0     = BinaryValue(int('40', 16), 8, False)
ADDR_DIGEST7     = BinaryValue(int('47', 16), 8, False)

async def dut_init(dut):
    # iterate all the input signals and initialize with 0
    for signal in dut:
        if signal._type == "GPI_NET":
            signal.value = 0

async def init_sim(dut):
    dut.reset_n.value = 1
    dut.cs.value = 0
    dut.we.value = 0
    dut.address.value = 0
    dut.write_data.value = 0

async def reset_dut(dut):
    dut.reset_n.value = 0
    await Timer(2 * CLK_PERIOD, units=CLK_TIME_UNIT)
    dut.reset_n.value = 1
    # await Timer(2 * CLK_PERIOD, units=CLK_TIME_UNIT)

async def write_word(dut, address: BinaryValue, word: BinaryValue):
    dut.address.value = address
    dut.write_data.value = word
    dut.cs.value = 1
    dut.we.value = 1

    await Timer(2 * CLK_PERIOD, units=CLK_TIME_UNIT)
    print(f'written word: {word.value}')
    dut.cs.value = 0
    dut.we.value = 0

async def read_word(dut, address: BinaryValue):
    dut.address.value = address
    dut.cs.value = 1
    dut.we.value = 0

    await Timer(CLK_PERIOD, units=CLK_TIME_UNIT)
    dut.cs.value = 0
    print(f'read word: {dut.read_data.value}')
    return dut.read_data.value

async def wait_ready(dut):
    read_data = await read_word(dut, ADDR_STATUS)
    while read_data == 0:
        read_data = await read_word(dut, ADDR_STATUS)

async def ready_after_init(dut):
    dut.init.value = 1
    await Timer(CLK_PERIOD, units=CLK_TIME_UNIT)

    dut.init.value = 0
    await wait_ready(dut)

async def get_digest(dut):
    digest = BinaryValue(0, 512, False)

    read_data = await read_word(dut, ADDR_DIGEST0)
    digest[255: 224] = read_data.integer

    read_data = await read_word(dut, ADDR_DIGEST0 + 1)
    digest[223: 192] = read_data.integer

    read_data = await read_word(dut, ADDR_DIGEST0 + 2)
    digest[191: 160] = read_data.integer

    read_data = await read_word(dut, ADDR_DIGEST0 + 3)
    digest[159: 128] = read_data.integer

    read_data = await read_word(dut, ADDR_DIGEST0 + 4)
    digest[127: 96] = read_data.integer

    read_data = await read_word(dut, ADDR_DIGEST0 + 5)
    digest[95: 64] = read_data.integer

    read_data = await read_word(dut, ADDR_DIGEST0 + 6)
    digest[63: 32] = read_data.integer

    read_data = await read_word(dut, ADDR_DIGEST0 + 7)
    digest[31: 0] = read_data.integer

    return digest

async def clean_block(dut):
    for i in range(0, 16):
        await write_word(dut, ADDR_BLOCK0 + i, BinaryValue(0, 32, False))

def ctrl_set(bit_pos: int):
    bit_set = 1 << bit_pos
    return BinaryValue(bit_set, 32, False)

async def test_rfc_7693(dut):
    await clean_block(dut)

    await write_word(dut, ADDR_CTRL, ctrl_set(CTRL_INIT_BIT))
    await wait_ready(dut)

    # Set a word for digesting
    word = BinaryValue(int('61626300', 16), 32, False)
    await write_word(dut, ADDR_BLOCK0, word)

    # Set the word length in bytes
    block_len = BinaryValue(3, 32, False)
    await write_word(dut, ADDR_BLOCKLEN, block_len)

    # Set the dut to perform the finish operation
    await write_word(dut, ADDR_CTRL, ctrl_set(CTRL_FINISH_BIT))
    await wait_ready(dut)

    digest_expected = int('508c5e8c327c14e2_e1a72ba34eeb452f_37458b209ed63a29_4d999b4c86675982', 16)
    digest_computed = await get_digest(dut)

    assert digest_computed == digest_expected, f'Mismatched digest, got {int(digest_computed):08X}'
