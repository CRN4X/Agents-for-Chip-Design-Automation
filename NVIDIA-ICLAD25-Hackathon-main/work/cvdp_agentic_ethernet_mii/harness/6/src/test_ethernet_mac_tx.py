import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
import random

def safe_int(sig, default=0):
    try:
        return int(sig.value)
    except ValueError:
        return default


async def reset_dut(dut):
    dut.rst_in.value = 1
    dut.cfg_wr_in.value         = 0
    dut.cfg_addr_in.value       = 0
    dut.cfg_data_wr_in.value    = 0
    dut.axis_tready_in.value = 0
    await ClockCycles(dut.clk_in, 5)
    dut.axis_tready_in.value = 1
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in, 5)


async def write_cfg(dut, addr, data):
    print(f"[CFG WRITE] Addr=0x{addr:08X}, Data=0x{data:08X}")
    dut.cfg_addr_in.value = addr
    dut.cfg_data_wr_in.value = data
    dut.cfg_wr_in.value = 1
    await RisingEdge(dut.clk_in)
    dut.cfg_wr_in.value = 0
    await RisingEdge(dut.clk_in)


async def monitor_output(dut, expected_bytes):
    print("\nAXI Stream Output:")
    received = []
    while True:
        await RisingEdge(dut.clk_in)
        if dut.axis_tvalid_out.value:
            data = safe_int(dut.axis_tdata_out)
            strb = safe_int(dut.axis_tstrb_out)
            last = safe_int(dut.axis_tlast_out)
            print(f"[AXI] Data=0x{data:08X}, Valid=1, Strb=0x{strb:X}, Last={last}")

            for i in range(4):
                if (strb >> i) & 1:
                    received.append((data >> (8 * i)) & 0xFF)

            if last:
                break

    if received != expected_bytes:
        print("\nAXI output mismatch!")
        print(f"Expected: {expected_bytes}")
        print(f"Received: {received}")
    assert received == expected_bytes, f"AXI output mismatch!"



async def test_packet(dut, length, enable_irq, dest_mac, payload_data=None):
    base_addr = 0x000C
    len_addr  = 0x07F4
    ctl_addr  = 0x07FC

    print("\n============================================================")
    print(f"--- Starting TX Test ---\nLength: {length}, IRQ: {enable_irq}, Dest MAC: 0x{dest_mac:012X}")

    if enable_irq:
        await write_cfg(dut, 0x07F8, 0x00000001)

    src_mac = 0xAA55AA55AA55
    await write_cfg(dut, 0x0000, dest_mac & 0xFFFFFFFF)
    await write_cfg(dut, 0x0004, ((src_mac & 0xFFFF) << 16) | ((dest_mac >> 32) & 0xFFFF))
    await write_cfg(dut, 0x0008, (src_mac >> 16) & 0xFFFFFFFF)

    words = (length + 3) >> 2
    expected_bytes = [(dest_mac >> (8 * i)) & 0xFF for i in range(6)]
    expected_bytes += [(src_mac >> (8 * i)) & 0xFF for i in range(6)]

    if payload_data is None:
        payload_data = [(i & 0xFF) for i in range(length)]

    for i in range(words):
        word = 0
        for j in range(4):
            index = i * 4 + j
            byte = payload_data[index] if index < length else 0
            word |= (byte & 0xFF) << (8 * j)
        await write_cfg(dut, base_addr + i * 4, word)
        for j in range(4):
            if len(expected_bytes) < length + 12:
                expected_bytes.append((word >> (8 * j)) & 0xFF)

    while len(expected_bytes) < 64:
        expected_bytes.append(0)

    await write_cfg(dut, len_addr, length + 12)
    await write_cfg(dut, ctl_addr, 0x00000001)
    await RisingEdge(dut.clk_in)
    await monitor_output(dut, expected_bytes)
    if enable_irq:
        await RisingEdge(dut.interrupt_out)
        print(f"Interrupt received for frame length {length} \n")
    else:
        print(f"Waiting for LAST (no IRQ)... Frame length: {length}")
        while not dut.axis_tlast_out.value:
            await RisingEdge(dut.clk_in)
        print(f"LAST received for frame length {length} \n")
    await RisingEdge(dut.clk_in)

async def test_packet_no_cfg(dut, length, enable_irq, dest_mac, payload_data=None, only_mac_program=False):

    print("\n============================================================")
    print(f"--- Starting TX Test ---\nLength: {length}, IRQ: {enable_irq}, Dest MAC: 0x{dest_mac:012X}, Only MAC Program: {only_mac_program}")

    if enable_irq:
        await write_cfg(dut, 0x07F8, 0x00000001)

    await write_cfg(dut, 0x07FC, 0x00000001)  # bit[1] = 1 (PROGRAM)
    # Generate expected bytes always (for verification)
    src_mac = 0xAA55AA55AA55
    expected_bytes = [(dest_mac >> (8 * i)) & 0xFF for i in range(6)]
    expected_bytes += [(src_mac >> (8 * i)) & 0xFF for i in range(6)]

    if payload_data is None:
        payload_data = [(i & 0xFF) for i in range(length)]

    for i in range(length):
        expected_bytes.append(payload_data[i])
    
    # Apply padding to minimum Ethernet frame size (64 bytes)
    while len(expected_bytes) < 64:
        expected_bytes.append(0)

    if only_mac_program:
        print("MAC program mode only — skipping frame and payload writes.")
        # Skip all further config
        await RisingEdge(dut.clk_in)
        await monitor_output(dut, expected_bytes)
        if enable_irq:
            await RisingEdge(dut.interrupt_out)
            print(f"Interrupt received for MAC program frame\n")
        else:
            print(f"Waiting for LAST (no IRQ)...")
            while not dut.axis_tlast_out.value:
                await RisingEdge(dut.clk_in)
            print(f"LAST received (MAC program mode)\n")
        return

    
@cocotb.test()
async def test_tx_len_12(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    await reset_dut(dut)
    await test_packet(dut, 12, 1, 0xDDAABBCCDDEE)


@cocotb.test()
async def test_tx_len_64(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    await reset_dut(dut)
    await test_packet(dut, 64, 1, 0xCCCCCCCCCCCC)


@cocotb.test()
async def test_tx_len_1518(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    await reset_dut(dut)
    await test_packet(dut, 1518, 1, 0xDDAABBCCDDEE)


@cocotb.test()
async def test_tx_len_67(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    await reset_dut(dut)
    await test_packet(dut, 67, 1, 0xDDAABBCCDDEE)


@cocotb.test()
async def test_tx_len_66(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    await reset_dut(dut)
    await test_packet(dut, 66, 1, 0xDDAABBCCDDEE)


@cocotb.test()
async def test_tx_len_65(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    await reset_dut(dut)
    await test_packet(dut, 65, 1, 0xDDAABBCCDDEE)


@cocotb.test()
async def test_back_to_back_incr_payloads(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    await reset_dut(dut)
    for i in range(5):
        length = random.randint(12, 1518)
        await test_packet(dut, length, 1, 0xDDAABBCCDDEE)


@cocotb.test()
async def test_back_to_back_random_payloads(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    await reset_dut(dut)
    for i in range(5):
        length = random.randint(12, 1518)
        payload = [random.randint(0, 255) for _ in range(length)]
        await test_packet(dut, length, 1, 0xAABBCCDDEEFF, payload_data=payload)


@cocotb.test()
async def test_back_to_back_incr_payloads_interrupt_disable(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    await reset_dut(dut)
    for i in range(5):
        length = random.randint(12, 1518)
        await test_packet(dut, length, 0, 0xDDAABBCCDDEE)

@cocotb.test()
async def test_mac_program_only_frames(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    await reset_dut(dut)

    # Step 1: Send initial frame with default MAC
    length = 64
    dest_mac = 0x112233445566
    payload = [random.randint(0, 255) for _ in range(length)]
    await test_packet(dut, length, 1, dest_mac, payload)

    # Step 2: Change MAC address only (PROGRAM = 1)
    new_mac = 0xAABBCCDDEEFF
    await write_cfg(dut, 0x0000, new_mac & 0xFFFFFFFF)
    await write_cfg(dut, 0x0004, ((0xAA55 & 0xFFFF) << 16) | ((new_mac >> 32) & 0xFFFF))
    await write_cfg(dut, 0x0008, (0xAA55AA55AA55 >> 16) & 0xFFFFFFFF)
    await write_cfg(dut, 0x07FC, 0x00000003)  # bit[1] = 1 (PROGRAM)
    await RisingEdge(dut.interrupt_out)
    await RisingEdge(dut.clk_in)

    # Step 3: Start a new frame using previous payload (BUSY = 1)
    await test_packet_no_cfg(dut, length, 1, new_mac, payload,1)
 
    
