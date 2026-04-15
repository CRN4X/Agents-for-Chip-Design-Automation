import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, with_timeout
from cocotb.result import SimTimeoutError

@cocotb.test()
async def axis_to_uart_tx_test(dut):
    """
    Cocotb test equivalent to the original SystemVerilog testbench for axis_to_uart_tx.
    
    It drives a series of random data words on an AXI-Stream interface and monitors the UART TX output,
    decoding the transmitted frames (start, data, parity, and stop bits) and comparing them to the sent data.
    
    The test uses timeouts to ensure it does not get stuck and waits until all test cases are executed.
    """

    #-------------------------------------------------------------------------
    # Parameters (adjust these to match DUT parameters)
    #-------------------------------------------------------------------------
    CLK_FREQ        = 100         # MHz (used for clock generation; CLK_PERIOD = 10 ns)
    BIT_RATE        = 115200      # UART bit rate in bps
    BIT_PER_WORD    = 8           # Number of data bits
    PARITY_BIT      = 1           # Parity mode: 0-none, 1-odd, 2-even (here only odd is implemented)
    STOP_BITS_NUM   = 1           # Number of stop bits
    DATA_WORDS_NUMB = 10          # Number of test data words
    DATA_MIN_DELAY  = 10          # Minimum interword delay (ns)
    DATA_MAX_DELAY  = 50          # Maximum interword delay (ns)

    # Calculate the UART bit period (in ns) and convert to integer to avoid floating point precision issues.
    bit_period = int(round((1.0 / BIT_RATE) * 1e9))  # e.g. for 115200 baud, ~8681 ns
    half_bit_period = bit_period // 2

    #-------------------------------------------------------------------------
    # Clock and Reset Generation
    #-------------------------------------------------------------------------
    CLK_PERIOD = 10  # ns (100 MHz clock)
    clock = Clock(dut.aclk, CLK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())

    # Reset: Assert aresetn low for 5 clock cycles and then drive it high.
    dut.aresetn.value = 0
    await Timer(CLK_PERIOD * 5, units="ns")
    dut.aresetn.value = 1

    #-------------------------------------------------------------------------
    # Generate Test Data
    #-------------------------------------------------------------------------
    data_array = []
    dut._log.info("Test Stimulus: Generated test data words:")
    for i in range(DATA_WORDS_NUMB):
        value = random.randint(0, (2**BIT_PER_WORD) - 1)
        data_array.append(value)
        dut._log.info("  Word %d: 0x%02x", i, value)

    # Storage for received data and parity error flags.
    result_data_array = [None] * DATA_WORDS_NUMB
    parity_err_array  = [0] * DATA_WORDS_NUMB

    #-------------------------------------------------------------------------
    # AXI Driver Task
    # This coroutine drives each word on the AXI-Stream interface.
    #-------------------------------------------------------------------------
    async def axis_driver():
        for i in range(DATA_WORDS_NUMB):
            delay_ns = random.randint(DATA_MIN_DELAY, DATA_MAX_DELAY)
            await Timer(delay_ns, units="ns")
            dut._log.info("AXI Driver: Preparing word %d with delay %d ns. Data: 0x%02x",
                          i, delay_ns, data_array[i])
            await RisingEdge(dut.aclk)
            while int(dut.tready.value) == 0:
                await RisingEdge(dut.aclk)
            dut.tdata.value = data_array[i]
            dut.tvalid.value = 1
            dut._log.info("AXI Driver: Sending word %d: Data: 0x%02x", i, data_array[i])
            await RisingEdge(dut.aclk)
            dut.tvalid.value = 0

    #-------------------------------------------------------------------------
    # UART Receiver Task
    # This coroutine monitors TX, detects the UART frame (start, data, parity, and stop bits),
    # and reconstructs the received data.
    #-------------------------------------------------------------------------
    async def uart_receiver():
        for i in range(DATA_WORDS_NUMB):
            try:
                # Use a timeout when waiting for the falling edge (start bit) so the test doesn't hang.
                await with_timeout(FallingEdge(dut.TX), 10 * bit_period, "ns")
            except SimTimeoutError:
                dut._log.error("UART Receiver: Timeout waiting for falling edge (start bit) for word %d", i)
                result_data_array[i] = 0
                parity_err_array[i] = 1
                continue

            dut._log.info("UART Receiver: Word %d - Detected falling edge (start bit)", i)

            # Wait half a bit period to sample the center of the start bit.
            await Timer(half_bit_period, units="ns")
            if int(dut.TX.value) != 0:
                dut._log.error("ERROR: Invalid start bit detected at word %d.", i)
            else:
                dut._log.info("UART Receiver: Word %d - Verified start bit is low.", i)

            received = 0
            parity_error = 0

            # Sample each data bit (LSB first).
            for j in range(BIT_PER_WORD):
                await Timer(bit_period, units="ns")
                sample_bit = int(dut.TX.value)
                received |= (sample_bit << j)
                dut._log.info("UART Receiver: Word %d - Sampled bit %d = %d", i, j, sample_bit)

            dut._log.info("UART Receiver: Word %d - Reconstructed data = 0x%02x", i, received)

            # If parity is enabled, sample the parity bit.
            if PARITY_BIT != 0:
                await Timer(bit_period, units="ns")
                sample_bit = int(dut.TX.value)
                computed_parity = 0
                for j in range(BIT_PER_WORD):
                    computed_parity ^= ((received >> j) & 1)
                # For odd parity, invert the computed result.
                if PARITY_BIT == 1:
                    computed_parity = 1 - computed_parity

                dut._log.info("UART Receiver: Word %d - Sampled parity bit = %d, Computed parity = %d",
                              i, sample_bit, computed_parity)
                if sample_bit != computed_parity:
                    parity_error = 1
                    dut._log.error("UART Receiver: Word %d - Parity error detected.", i)
                else:
                    dut._log.info("UART Receiver: Word %d - Parity check passed.", i)

            # Sample the stop bit(s) and verify they are high.
            for j in range(STOP_BITS_NUM):
                await Timer(bit_period, units="ns")
                if int(dut.TX.value) != 1:
                    dut._log.error("ERROR: Invalid stop bit detected at word %d, stop index %d.", i, j)
                else:
                    dut._log.info("UART Receiver: Word %d - Stop bit %d verified high.", i, j)

            result_data_array[i] = received
            parity_err_array[i] = parity_error
            dut._log.info("UART Receiver: Completed word %d - Data: 0x%02x, Parity Error: %d",
                          i, received, parity_error)

    #-------------------------------------------------------------------------
    # Start both tasks concurrently and wait until they complete.
    #-------------------------------------------------------------------------
    axi_task  = cocotb.start_soon(axis_driver())
    uart_task = cocotb.start_soon(uart_receiver())

    # Use generous timeouts when joining tasks so the test does not exit prematurely.
    try:
        await with_timeout(axi_task.join(), 1000 * bit_period, "ns")
    except SimTimeoutError:
        dut._log.error("Timeout waiting for AXI driver task to complete.")

    try:
        await with_timeout(uart_task.join(), 1000 * bit_period, "ns")
    except SimTimeoutError:
        dut._log.error("Timeout waiting for UART receiver task to complete.")

    # Wait a little extra to ensure the last transmissions finish.
    await Timer(bit_period * 5, units="ns")

    #-------------------------------------------------------------------------
    # Test Evaluation: Compare transmitted and received data
    #-------------------------------------------------------------------------
    test_result = True
    for i in range(DATA_WORDS_NUMB):
        if result_data_array[i] != data_array[i]:
            dut._log.error("Data word %d mismatch! Expected: 0x%02x, Received: 0x%02x.",
                           i, data_array[i], result_data_array[i] if result_data_array[i] is not None else 0)
            test_result = False
        if PARITY_BIT != 0 and parity_err_array[i]:
            dut._log.error("Parity error in data word %d!", i)
            test_result = False

    dut._log.info("-------------------------------------")
    if test_result:
        dut._log.info("------------- TEST PASS -------------")
    else:
        dut._log.info("------------- TEST FAIL -------------")
    dut._log.info("-------------------------------------")

    # Optionally, you can also force the simulation to run a bit longer or finish
    # only after all tasks are confirmed finished.
    await Timer(bit_period * 5, units="ns")
