import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge, with_timeout
from cocotb.result import SimTimeoutError

@cocotb.test()
async def uart_rx_to_axis_test(dut):
    """
    Cocotb test for the uart_rx_to_axis DUT.
    
    This test generates NUM_FRAMES UART frames that include a start bit, data bits,
    an optional parity bit (with some frames intentionally corrupted), and stop bit(s).
    The DUT is expected to output the reconstructed data on the AXI-Stream interface.
    The scoreboard captures received frames when tvalid is asserted, and then the test 
    compares the received data and parity error flag (tuser) to the expected values.
    """
    #-------------------------------------------------------------------------
    # Parameters (adjust to match DUT parameters)
    #-------------------------------------------------------------------------
    CLK_FREQ        = 100         # MHz (for clock generation; CLK_PERIOD = 10 ns)
    BIT_RATE        = 115200      # UART bit rate in bps
    BIT_PER_WORD    = 8           # Number of data bits per word
    PARITY_BIT      = 1           # Parity mode: 0-none, 1-odd, 2-even (here odd is used)
    STOP_BITS_NUM   = 1           # Number of stop bits: 1 or 2
    NUM_FRAMES      = 20          # Number of UART frames to test
    DATA_MIN_DELAY  = 1000        # Minimum inter-frame delay (ns)
    DATA_MAX_DELAY  = 5000        # Maximum inter-frame delay (ns)
    CLK_PERIOD      = 10          # Clock period in ns (100 MHz)

    # Calculate the UART bit period (in ns) and its half period (to sample start bit)
    bit_period = int(round((1.0 / BIT_RATE) * 1e9))  # e.g., ~8681 ns for 115200 baud
    half_bit_period = bit_period // 2

    #-------------------------------------------------------------------------
    # Clock and Reset Generation
    #-------------------------------------------------------------------------
    clock = Clock(dut.aclk, CLK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())

    dut.aresetn.value = 0
    await Timer(CLK_PERIOD * 5, units="ns")
    dut.aresetn.value = 1

    #-------------------------------------------------------------------------
    # Prepare Test Data
    #-------------------------------------------------------------------------
    transmitted_data = []
    corrupt_parity = []
    for i in range(NUM_FRAMES):
        value = random.randint(0, (2**BIT_PER_WORD)-1)
        transmitted_data.append(value)
        # Randomly corrupt parity on ~20% of frames:
        corrupt_parity.append(random.randint(0, 4) == 0)
        dut._log.info("Frame %d: data=0x%02x, corrupt_parity=%s", i, value, str(corrupt_parity[-1]))

    # Arrays to store DUT output for later evaluation.
    received_data = [None] * NUM_FRAMES
    received_parity_error = [0] * NUM_FRAMES
    rx_frame_index = 0

    #-------------------------------------------------------------------------
    # Scoreboard Task: Capture DUT output when tvalid is asserted.
    #-------------------------------------------------------------------------
    async def scoreboard():
        nonlocal rx_frame_index
        while rx_frame_index < NUM_FRAMES:
            await RisingEdge(dut.aclk)
            if int(dut.tvalid.value) == 1:
                received_data[rx_frame_index] = int(dut.tdata.value)
                received_parity_error[rx_frame_index] = int(dut.tuser.value)
                dut._log.info("Scoreboard: Captured frame %d => Data=0x%02x, ParityErr=%d",
                              rx_frame_index, received_data[rx_frame_index], received_parity_error[rx_frame_index])
                rx_frame_index += 1

    sb_task = cocotb.start_soon(scoreboard())

    #-------------------------------------------------------------------------
    # UART Driver Task: Drive UART frames into RX.
    #-------------------------------------------------------------------------
    async def uart_driver():
        # Ensure RX is idle (logic high) to start.
        dut.RX.value = 1
        for i in range(NUM_FRAMES):
            # Random inter-frame delay.
            delay_ns = random.randint(DATA_MIN_DELAY, DATA_MAX_DELAY)
            await Timer(delay_ns, units="ns")
            data_byte = transmitted_data[i]

            # Prepare data bits (LSB first list)
            shift_bits = [(data_byte >> bit) & 1 for bit in range(BIT_PER_WORD)]

            # Compute even parity (XOR reduction) and then invert for odd parity.
            expected_parity = 0
            for bit_val in shift_bits:
                expected_parity ^= bit_val
            if PARITY_BIT == 1:
                expected_parity = 1 - expected_parity

            # Drive Start Bit: low for one bit period.
            dut.RX.value = 0
            await Timer(bit_period, units="ns")

            # Drive Data Bits: LSB first.
            for j in range(BIT_PER_WORD):
                dut.RX.value = shift_bits[j]
                await Timer(bit_period, units="ns")

            # Drive Parity Bit if enabled.
            if PARITY_BIT != 0:
                parity_bit = expected_parity
                if corrupt_parity[i]:
                    parity_bit = 1 - parity_bit  # Corrupt the parity bit.
                dut.RX.value = parity_bit
                await Timer(bit_period, units="ns")

            # Drive Stop Bit(s): high.
            dut.RX.value = 1
            await Timer(bit_period, units="ns")
            if STOP_BITS_NUM == 2:
                dut.RX.value = 1
                await Timer(bit_period, units="ns")

    uart_task = cocotb.start_soon(uart_driver())

    #-------------------------------------------------------------------------
    # Wait for tasks to complete (with timeouts to avoid hangs)
    #-------------------------------------------------------------------------
    try:
        await with_timeout(uart_task.join(), 1000 * bit_period, "ns")
    except SimTimeoutError:
        dut._log.error("Timeout waiting for UART driver to complete.")

    try:
        await with_timeout(sb_task.join(), 1000 * bit_period, "ns")
    except SimTimeoutError:
        dut._log.error("Timeout waiting for scoreboard task to complete.")

    # Extra delay to ensure all outputs settle.
    await Timer(bit_period * 5, units="ns")

    #-------------------------------------------------------------------------
    # Test Evaluation: Compare transmitted and received data.
    #-------------------------------------------------------------------------
    test_result = True
    for i in range(NUM_FRAMES):
        if received_data[i] != transmitted_data[i]:
            dut._log.error("Frame %d: Data mismatch! Expected: 0x%02x, Received: 0x%02x",
                           i, transmitted_data[i], received_data[i])
            test_result = False

        if PARITY_BIT != 0:
            if corrupt_parity[i] and received_parity_error[i] == 0:
                dut._log.error("Frame %d: Expected parity error, but received none.", i)
                test_result = False
            elif (not corrupt_parity[i]) and (received_parity_error[i] != 0):
                dut._log.error("Frame %d: Correct parity expected, but parity error indicated.", i)
                test_result = False
        else:
            if received_parity_error[i] != 0:
                dut._log.error("Frame %d: Parity error indicated with parity disabled.", i)
                test_result = False

    dut._log.info("-------------------------------------")
    if test_result:
        dut._log.info("------------- TEST PASS -------------")
    else:
        dut._log.info("------------- TEST FAIL -------------")
    dut._log.info("-------------------------------------")

    await Timer(bit_period * 5, units="ns")
