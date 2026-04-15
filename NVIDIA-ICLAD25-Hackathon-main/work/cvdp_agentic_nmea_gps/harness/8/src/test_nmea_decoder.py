import cocotb
from cocotb.clock import Clock
from cocotb.regression import TestFactory
from cocotb.triggers import RisingEdge, Timer
import harness_library as hrs_lb

@cocotb.test()
async def test_nmea_decoder(dut):
    """
    Testbench for the modified NMEA decoder.
    """

    # Generate clock with 10ns period
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset the DUT
    dut.reset.value = 1                  # Assert reset
    dut.serial_in.value = 0              # Clear input data
    dut.serial_valid.value = 0           # Deassert serial_valid
    dut.watchdog_timeout_en.value = 1    # Enable watchdog logic
    
    # Hold reset for 20ns
    await Timer(20, units="ns")
    dut.reset.value = 0                  # Deassert reset
    await Timer(10, units="ns")          # Wait for DUT to stabilize

    # Helper function to send a single serial byte
    async def send_char(char):
        """ Sends a single character to the DUT. """
        dut.serial_in.value = char
        dut.serial_valid.value = 1
        await Timer(5, units="ns")
        dut.serial_valid.value = 0
        await Timer(5, units="ns")

    # Helper function to send a full NMEA sentence
    async def send_sentence(sentence):
        """ Sends a complete sentence to the DUT. """
        for char in sentence:
            if char == 0:
                break
            await send_char(char)

    # -------------------------------
    # Test Case 1: Valid $GPRMC sentence
    # -------------------------------
    cocotb.log.info("Starting Test Case 1: Valid $GPRMC sentence")

    # $GPRMC sentence with 7th field = "12"
    sentence = [
        0x24, 0x47, 0x50, 0x52, 0x4D, 0x43, 0x2C, 0x31, 0x32, 0x33, 0x35, 0x31,
        0x39, 0x2C, 0x41, 0x2C, 0x34, 0x38, 0x30, 0x37, 0x2E, 0x30, 0x33, 0x38,
        0x2C, 0x4E, 0x2C, 0x30, 0x31, 0x31, 0x33, 0x31, 0x2E, 0x30, 0x30, 0x30,
        0x2C, 0x45, 0x2C, 0x30, 0x32, 0x32, 0x2E, 0x34, 0x2C, 0x30, 0x38, 0x34,
        0x2E, 0x34, 0x2C, 0x32, 0x33, 0x30, 0x33, 0x39, 0x34, 0x2C, 0x30, 0x30,
        0x33, 0x2E, 0x31, 0x2C, 0x57, 0x2A, 0x36, 0x41, 0x0D
    ] + [0] * 15  # Pad to 80 characters

    await send_sentence(sentence)       # Send to DUT

    expected_output = 0x3132            # ASCII for "12"
    assert dut.data_out.value == expected_output, f"ERROR: Expected 0x3132, got {dut.data_out.value}"

    cocotb.log.info(f"Test Case 1 data_out for valid sentence: dut.data_out.value = {dut.data_out.value}")
    cocotb.log.info("SUCCESS: Correct data_out for valid sentence")

    # -------------------------------
    # Test Case 2: Invalid sentence
    # -------------------------------
    cocotb.log.info("Starting Test Case 2: Invalid sentence")

    # Random sentence not starting with $GPRMC
    sentence = [
        0x24, 0x47, 0x50, 0x58, 0x59, 0x5A, 0x2C, 0x49, 0x4E, 0x56, 0x41, 0x4C,
        0x49, 0x44, 0x2C, 0x53, 0x45, 0x4E, 0x54, 0x45, 0x4E, 0x43, 0x45, 0x0D,
        0x0A
    ] + [0] * 57

    await send_sentence(sentence)
    await Timer(50, units="ns")         # Wait for FSM to settle

    assert dut.data_valid.value == 0, f"ERROR: Expected data_valid = 0, got {dut.data_valid.value}"
    cocotb.log.info(f"Test Case 2 Correctly handled invalid sentence with data_valid: dut.data_valid.value = {dut.data_valid.value}")
    cocotb.log.info("SUCCESS: Correctly handled invalid sentence with data_valid = 0")

    # -------------------------------
    # Test Case 3: Buffer Overflow
    # -------------------------------
    cocotb.log.info("Starting Test Case 3: Buffer Overflow")

    # Fill the buffer completely (overflow condition)
    sentence = [0x41] * 80
    sentence[0] = 0x24
    sentence[1] = 0x47
    sentence[2] = 0x50
    sentence[3] = 0x52
    sentence[4] = 0x4D
    sentence[5] = 0x43

    await send_sentence(sentence)
    await Timer(20, units="ns")         # Allow FSM to detect overflow

    assert dut.error_overflow.value == 1, f"ERROR: Expected error_overflow = 1, got {dut.error_overflow.value}"
    cocotb.log.info(f"Test Case 3 Correctly detected overflow with error_overflow: dut.error_overflow.value = {dut.error_overflow.value}")
    cocotb.log.info("SUCCESS: Overflow correctly detected")

    # -------------------------------
    # Test Case 4: Watchdog Timeout
    # -------------------------------
    cocotb.log.info("Starting Test Case 4: Watchdog timeout")

    # Send partial sentence and let watchdog timer expire
    sentence = [0] * 80
    sentence[0] = 0x24
    sentence[1] = 0x47
    sentence[2] = 0x50
    sentence[3] = 0x52
    sentence[4] = 0x4D
    sentence[5] = 0x43
    sentence[6] = 0x2C

    await RisingEdge(dut.clk)
    for i in range(7):
        await send_char(sentence[i])

    await Timer(25000, units="ns")      # Wait for watchdog to trigger

    assert dut.watchdog_timeout.value == 1, f"ERROR: Expected watchdog_timeout = 1, got {dut.watchdog_timeout.value}"
    cocotb.log.info(f"Test Case 4 Watchdog timeout: dut.watchdog_timeout.value = {dut.watchdog_timeout.value}")
    cocotb.log.info("SUCCESS: Watchdog timeout triggered correctly")

    # -------------------------------
    # Test Case 5: Valid $GPRMC with data_bin
    # -------------------------------
    cocotb.log.info("-------------------------------------------------------------------------")
    cocotb.log.info("Starting Test Case 5: Valid $GPRMC sentence and data_bin")

    # Reset again before test
    dut.reset.value = 1
    await Timer(20, units="ns")
    dut.reset.value = 0
    await Timer(10, units="ns")

    # Sentence with field = "34"
    sentence = [
        0x24, 0x47, 0x50, 0x52, 0x4D, 0x43, 0x2C, 0x33, 0x34, 0x33, 0x35, 0x31,
        0x39, 0x2C, 0x41, 0x2C, 0x34, 0x38, 0x30, 0x37, 0x2E, 0x30, 0x33, 0x38,
        0x2C, 0x4E, 0x2C, 0x30, 0x31, 0x31, 0x33, 0x31, 0x2E, 0x30, 0x30, 0x30,
        0x2C, 0x45, 0x2C, 0x30, 0x32, 0x32, 0x2E, 0x34, 0x2C, 0x30, 0x38, 0x34,
        0x2E, 0x34, 0x2C, 0x32, 0x33, 0x30, 0x33, 0x39, 0x34, 0x2C, 0x30, 0x30,
        0x33, 0x2E, 0x31, 0x2C, 0x57, 0x2A, 0x36, 0x41, 0x0D
    ] + [0] * 15

    await send_sentence(sentence)

    # Wait until data_bin_valid is asserted
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.data_bin_valid.value == 1:
            break
    else:
        assert False, "ERROR: data_bin_valid was not asserted within expected time"

    # Capture binary and ASCII outputs
    actual_bin = dut.data_out_bin.value.to_unsigned()
    actual_ascii = dut.data_out.value.to_unsigned()

    cocotb.log.info(f"DEBUG: data_out = 0x{actual_ascii:04X}, data_out_bin = {actual_bin}, data_bin_valid = {dut.data_bin_valid.value}")

    # Check ASCII value = '3''4' => 0x3334
    assert actual_ascii == 0x3334, f"ERROR: Expected data_out = 0x3334, got 0x{actual_ascii:X}"

    # Check binary conversion = 34
    assert actual_bin == 34, f"ERROR: Expected data_out_bin = 34, got {actual_bin}"

    cocotb.log.info(f"SUCCESS: Test Case 5 Passed — ASCII = 0x{actual_ascii:X}, Binary = {actual_bin}")
