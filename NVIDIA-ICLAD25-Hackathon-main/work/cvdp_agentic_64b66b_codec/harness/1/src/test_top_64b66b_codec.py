import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

# Helper function to initialize DUT inputs
async def dut_initialization(dut):
    """ Initialize all inputs for DUT """
    dut.rst_in.value = 1
    dut.dec_data_valid_in.value = 0
    dut.dec_data_in.value = 0
    dut.enc_data_in.value = 0
    dut.enc_control_in.value = 0
    await RisingEdge(dut.clk_in)  # Wait for one clock cycle
    await RisingEdge(dut.clk_in)  # Wait for one clock cycle
    await RisingEdge(dut.clk_in)  # Wait for one clock cycle

# Helper function to check the output with debug logging
async def check_output_encoder(dut, expected_sync, expected_data):
    await RisingEdge(dut.clk_in)
    actual_output = dut.enc_data_out.value.to_unsigned()
    expected_output = (expected_sync << 64) | expected_data

    # Log the actual and expected outputs
    dut._log.info(f"Checking output:\n"
                  f"  Actual enc_data_out: {hex(actual_output)}\n"
                  f"  Expected enc_data_out: {hex(expected_output)}\n")

    assert actual_output == expected_output, \
        f"Test failed: enc_data_out={hex(actual_output)} (expected {hex(expected_output)})"


# Helper function to check the output with debug logging
async def check_output_decoder(dut, expected_data, expected_dec_sync_error, expected_control_out=0, expected_dec_error_out=0):
    """Check DUT output against expected values"""
    await RisingEdge(dut.clk_in)  # Wait for the output latency of 1 cycle
    actual_data_out = dut.dec_data_out.value.to_unsigned()
    actual_dec_sync_error = dut.dec_sync_error.value.to_unsigned()
    actual_control_out = dut.dec_control_out.value.to_unsigned()
    actual_dec_error_out = dut.dec_error_out.value.to_unsigned()
    dec_data_in = dut.dec_data_in.value.to_unsigned()

    # Log the actual and expected outputs
    dut._log.info(f"Checking output - Input: {hex(dec_data_in)},  Actual dec_data_out: {hex(actual_data_out)}, Expected dec_data_out: {hex(expected_data)}\n"
                  f"  Actual dec_sync_error: {actual_dec_sync_error}, Expected dec_sync_error: {expected_dec_sync_error}\n"
                  f"  Actual dec_control_out: {hex(actual_control_out)}, Expected dec_control_out: {hex(expected_control_out)}\n"
                  f"  Actual dec_error_out: {actual_dec_error_out}, Expected dec_error_out: {expected_dec_error_out}\n")

    # Always check dec_sync_error and dec_error_out
    assert actual_dec_sync_error == expected_dec_sync_error, \
        f"Sync error mismatch: dec_sync_error={actual_dec_sync_error} (expected {expected_dec_sync_error})"
    assert actual_dec_error_out == expected_dec_error_out, \
        f"Decoder error mismatch: dec_error_out={actual_dec_error_out} (expected {expected_dec_error_out})"

    # Check data and control output only if both dec_sync_error and dec_error_out are 0
    if expected_dec_sync_error == 0 and expected_dec_error_out == 0:
        assert actual_data_out == expected_data, \
            f"Data mismatch: dec_data_out={hex(actual_data_out)} (expected {hex(expected_data)})"
        assert actual_control_out == expected_control_out, \
            f"Control output mismatch: dec_control_out={hex(actual_control_out)} (expected {hex(expected_control_out)})"

@cocotb.test()
async def top_reset_test(dut):
    """ Test the reset behavior of the decoder """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())
    
    # Initialize DUT inputs
    await dut_initialization(dut)

    await Timer(20, units="ns")  # hold reset for 20ns
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)
    dut.rst_in.value = 1
    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)

    # Log the output after reset
    dut._log.info(f"Reset Test:\n  dec_data_out: {hex(dut.dec_data_out.value.to_unsigned())}\n  Expected: 0")

    # Check that output is zero after reset
    assert dut.dec_data_out.value == 0, "Reset test failed: dec_data_out should be zero after reset"
    assert dut.dec_sync_error.value == 0, "Reset test failed: dec_sync_error should be zero after reset"
     # Check that output is zero after reset
    assert dut.enc_data_out.value.to_unsigned() == 0, "Reset test failed: enc_data_out should be zero after reset"

@cocotb.test()
async def encoder_fixed_pattern_test(dut):
    """ Test encoding when all data octets are pure data """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())
    # Initialize DUT inputs
    await dut_initialization(dut)

    await Timer(20, units="ns")  # hold reset for 20ns
    await RisingEdge(dut.clk_in)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)
    dut.enc_data_in.value = 0xA5A5A5A5A5A5A5A5
    dut.enc_control_in.value = 0x00  # All data

    await RisingEdge(dut.clk_in)
    # Log inputs for data encoding test
    dut._log.info(f"Data Encoding Test:\n"
                  f"  enc_data_in: {hex(dut.enc_data_in.value.to_unsigned())}\n"
                  f"  enc_control_in: {bin(dut.enc_control_in.value.to_unsigned())}")

    # Apply test and check output
    await check_output_encoder(dut, expected_sync=0b01, expected_data=0xA5A5A5A5A5A5A5A5)

@cocotb.test()
async def encoder_control_encoding_test(dut):
    """ Test encoding when control characters are in the last four octets """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())
    # Initialize DUT inputs
    await dut_initialization(dut)
    
    await Timer(20, units="ns")  # hold reset for 20ns
    await RisingEdge(dut.clk_in)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)
    # Set test inputs
    dut.enc_data_in.value = 0xFFFFFFFFFFFFFFFF
    dut.enc_control_in.value = 0x0F  # Control in last four octets

    await RisingEdge(dut.clk_in)
    # Log inputs for control encoding test
    dut._log.info(f"Control Encoding Test:\n"
                  f"  enc_data_in: {hex(dut.enc_data_in.value.to_unsigned())}\n"
                  f"  enc_control_in: {bin(dut.enc_control_in.value.to_unsigned())}")

    # Apply test and check output
    await check_output_encoder(dut, expected_sync=0b10, expected_data=0x0000000000000000)  # Expected data output is zero

@cocotb.test()
async def encoder_mixed_data_control_test(dut):
    """ Test encoding when control characters are mixed in the data """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())

    # Initialize DUT inputs
    await dut_initialization(dut)

    await Timer(20, units="ns")  # hold reset for 20ns
    await RisingEdge(dut.clk_in)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Set test inputs
    dut.enc_data_in.value = 0x123456789ABCDEF0
    dut.enc_control_in.value = 0x81  # Control in first and last octets

    await RisingEdge(dut.clk_in)
    # Log inputs for mixed data and control test
    dut._log.info(f"Mixed Data and Control Test:\n"
                  f"  enc_data_in: {hex(dut.enc_data_in.value.to_unsigned())}\n"
                  f"  enc_control_in: {bin(dut.enc_control_in.value.to_unsigned())}")

    # Apply test and check output
    await RisingEdge(dut.clk_in)
    await check_output_encoder(dut, expected_sync=0b10, expected_data=0x0000000000000000)  # Expected data output is zero

@cocotb.test()
async def encoder_all_control_symbols_test(dut):
    """ Test encoding when all characters are control """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())

    # Initialize DUT inputs
    await dut_initialization(dut)

    await Timer(20, units="ns")  # hold reset for 20ns
    await RisingEdge(dut.clk_in)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Set test inputs
    dut.enc_data_in.value = 0xA5A5A5A5A5A5A5A5
    dut.enc_control_in.value = 0xFF  # All control

    await RisingEdge(dut.clk_in)
    # Log inputs for all control symbols test
    dut._log.info(f"All Control Symbols Test:\n"
                  f"  enc_data_in: {hex(dut.enc_data_in.value.to_unsigned())}\n"
                  f"  enc_control_in: {bin(dut.enc_control_in.value.to_unsigned())}")

    # Apply test and check output
    await check_output_encoder(dut, expected_sync=0b10, expected_data=0x0000000000000000)  # Expected data output is zero

@cocotb.test()
async def encoder_random_data_control_test(dut):
    """ Test encoding with random data and control inputs """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())

    # Initialize DUT inputs
    await dut_initialization(dut)
    
    await Timer(20, units="ns")  # hold reset for 20ns
    await RisingEdge(dut.clk_in)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    for i in range(500):  # Run 5 random tests
        # Generate random data and control inputs
        random_data = random.getrandbits(64)
        random_control = 0

        dut.enc_data_in.value = random_data
        dut.enc_control_in.value = random_control

        # Determine expected sync word and data based on control input
        expected_sync = 0b01 if random_control == 0 else 0b10
        expected_data = random_data if random_control == 0 else 0x0000000000000000

        await RisingEdge(dut.clk_in)
        # Log inputs for each random test
        dut._log.info(f"Random Test {i+1}:\n"
                      f"  enc_data_in: {hex(dut.enc_data_in.value.to_unsigned())}\n"
                      f"  enc_control_in: {bin(dut.enc_control_in.value.to_unsigned())}")

        await check_output_encoder(dut, expected_sync=expected_sync, expected_data=expected_data)

        await Timer(10, units="ns")  # Wait for next random test

    dut._log.info("Randomized tests completed successfully")

@cocotb.test()
async def encoder_random_data_only_test(dut):
    """ Test encoding with random data and control inputs """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())

    # Initialize DUT inputs
    await dut_initialization(dut)
    
    await Timer(20, units="ns")  # hold reset for 20ns
    await RisingEdge(dut.clk_in)
    dut.rst_in.value = 0
    dut.enc_control_in.value = 0  # All data
    await RisingEdge(dut.clk_in)

    for i in range(50):  # Run 5 random tests
        # Generate random data
        random_data = random.getrandbits(64)
        dut.enc_data_in.value = random_data

        # Determine expected sync word and data
        expected_sync = 0b01
        expected_data = random_data

        await RisingEdge(dut.clk_in)
        # Log inputs for each random test
        dut._log.info(f"Random Test {i+1}:\n"
                      f"  enc_data_in: {hex(dut.enc_data_in.value.to_unsigned())}\n"
                      f"  enc_control_in: {bin(dut.enc_control_in.value.to_unsigned())}")

        await check_output_encoder(dut, expected_sync=expected_sync, expected_data=expected_data)

        await Timer(10, units="ns")  # Wait for next random test

    dut._log.info("Randomized tests completed successfully")

@cocotb.test()
async def encoder_test_all_control_combinations(dut):
    """Cocotb test for 64b/66b encoder with full test cases and expected outputs"""

    # Start the clock
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())
    # Initialize DUT inputs
    await dut_initialization(dut)

    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Test cases with expected values
    test_cases = [
        (0x0707070707070707, 0b11111111, 0x21e00000000000000),
        (0x070707070707FDAE, 0b11111110, 0x299000000000000ae),
        (0x0707070707FDA5A5, 0b11111100, 0x2aa0000000000a5a5),
        (0x07070707FDFEED55, 0b11111000, 0x2b400000000feed55),
        (0x070707FD99887766, 0b11110000, 0x2cc00000099887766),
        (0x0707FDAABBCCDDEE, 0b11100000, 0x2d20000aabbccddee),
        (0x07FDAAAAAA555555, 0b11000000, 0x2e100aaaaaa555555),
        (0xFD773388229911AA, 0b10000000, 0x2ff773388229911aa),
        (0xDDCCBBFB07070707, 0b00011111, 0x233ddccbb00000000),
        (0x0707079C0707079C, 0b00010001, 0x255070707ff070707),
        (0x3456789ABCDEF0FB, 0b00000001, 0x2783456789abcdef0),
        (0x777777FBDEEDDE9C, 0b00010001, 0x2667777770fdeedde),
        (0x07070707ABCDEF9C, 0b11110001, 0x24b0000000abcdeff),
        (0xAAAAAA9C07070707, 0b00011111, 0x22daaaaaaf0000000),
        (0xFEFEFEFEFEFEFEFE, 0b11111111, 0x21e3c78f1e3c78f1e),
        (0x07070707070707FD, 0b11111111, 0x28700000000000000),
    ]

    # Apply test cases and compare DUT output with expected values
    for idx, (data_in, control_in, expected_output) in enumerate(test_cases):
        # Apply inputs
        await RisingEdge(dut.clk_in)
        dut.enc_data_in.value = data_in
        dut.enc_control_in.value = control_in

        # Wait for a clock cycle
        await RisingEdge(dut.clk_in)
        await RisingEdge(dut.clk_in)

        # Get DUT output
        dut_output = int(dut.enc_data_out.value)

        # Compare DUT output with expected output
        assert dut_output == expected_output, (
            f"Test case {idx+1} failed: "
            f"Data: {hex(data_in)}, Control: {bin(control_in)}, "
            f"Expected: {hex(expected_output)}, Got: {hex(dut_output)}"
        )

        dut._log.info(
            f"Test Case {idx + 1}:\n"
            f"  enc_data_in: {hex(data_in)}\n"
            f"  enc_control_in: {bin(control_in)}\n"
            f"  enc_data_out (DUT): {hex(dut_output)}\n"
            f"  Expected: {hex(expected_output)}"
        )

@cocotb.test()
async def encoder_test_all_octets_control(dut):
    """Cocotb test for 64b/66b encoder with full test cases and expected outputs"""

    # Start the clock
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())
    # Initialize DUT inputs
    await dut_initialization(dut)

    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Test cases with expected values
    test_cases = [
        (0x0707070707070707, 0b11111111, 0x21e00000000000000),
        (0xFEFEFEFEFEFEFEFE, 0b11111111, 0x21e3c78f1e3c78f1e),
        (0x07070707070707FD, 0b11111111, 0x28700000000000000),
    ]

    # Apply test cases and compare DUT output with expected values
    for idx, (data_in, control_in, expected_output) in enumerate(test_cases):
        # Apply inputs
        await RisingEdge(dut.clk_in)
        dut.enc_data_in.value = data_in
        dut.enc_control_in.value = control_in

        # Wait for a clock cycle
        await RisingEdge(dut.clk_in)
        await RisingEdge(dut.clk_in)

        # Get DUT output
        dut_output = int(dut.enc_data_out.value)

        # Compare DUT output with expected output
        assert dut_output == expected_output, (
            f"Test case {idx+1} failed: "
            f"Data: {hex(data_in)}, Control: {bin(control_in)}, "
            f"Expected: {hex(expected_output)}, Got: {hex(dut_output)}"
        )

        dut._log.info(
            f"Test Case {idx + 1}:\n"
            f"  enc_data_in: {hex(data_in)}\n"
            f"  enc_control_in: {bin(control_in)}\n"
            f"  enc_data_out (DUT): {hex(dut_output)}\n"
            f"  Expected: {hex(expected_output)}"
        )

@cocotb.test()
async def encoder_test_mixed_data_control_octets(dut):
    """Cocotb test for 64b/66b encoder with full test cases and expected outputs"""

    # Start the clock
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())
    # Initialize DUT inputs
    await dut_initialization(dut)

    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Test cases with expected values
    test_cases = [
        (0x070707070707FDAE, 0b11111110, 0x299000000000000ae),
        (0x0707070707FDA5A5, 0b11111100, 0x2aa0000000000a5a5),
        (0x07070707FDFEED55, 0b11111000, 0x2b400000000feed55),
        (0x070707FD99887766, 0b11110000, 0x2cc00000099887766),
        (0x0707FDAABBCCDDEE, 0b11100000, 0x2d20000aabbccddee),
        (0x07FDAAAAAA555555, 0b11000000, 0x2e100aaaaaa555555),
        (0xFD773388229911AA, 0b10000000, 0x2ff773388229911aa),
        (0xDDCCBBFB07070707, 0b00011111, 0x233ddccbb00000000),
        (0x0707079C0707079C, 0b00010001, 0x255070707ff070707),
        (0x3456789ABCDEF0FB, 0b00000001, 0x2783456789abcdef0),
        (0x777777FBDEEDDE9C, 0b00010001, 0x2667777770fdeedde),
        (0x07070707ABCDEF9C, 0b11110001, 0x24b0000000abcdeff),
        (0xAAAAAA9C07070707, 0b00011111, 0x22daaaaaaf0000000),
    ]


    # Apply test cases and compare DUT output with expected values
    for idx, (data_in, control_in, expected_output) in enumerate(test_cases):
        # Apply inputs
        await RisingEdge(dut.clk_in)
        dut.enc_data_in.value = data_in
        dut.enc_control_in.value = control_in

        # Wait for a clock cycle
        await RisingEdge(dut.clk_in)
        await RisingEdge(dut.clk_in)

        # Get DUT output
        dut_output = int(dut.enc_data_out.value)

        # Compare DUT output with expected output
        assert dut_output == expected_output, (
            f"Test case {idx+1} failed: "
            f"Data: {hex(data_in)}, Control: {bin(control_in)}, "
            f"Expected: {hex(expected_output)}, Got: {hex(dut_output)}"
        )

        dut._log.info(
            f"Test Case {idx + 1}:\n"
            f"  enc_data_in: {hex(data_in)}\n"
            f"  enc_control_in: {bin(control_in)}\n"
            f"  enc_data_out (DUT): {hex(dut_output)}\n"
            f"  Expected: {hex(expected_output)}"
        )
    dut._log.info("All test cases passed!")


@cocotb.test()
async def decoder_random_any_sync_header_data_test(dut):
    """ Test decoding with random sync headers and data """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())

    # Initialize DUT inputs
    await dut_initialization(dut)
    await RisingEdge(dut.clk_in)

    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    for i in range(5):  # Run 5 random tests
        random_sync_header = random.choice([0b01, 0b00, 0b11])
        random_data = random.getrandbits(64)

        dut.dec_data_in.value = (random_sync_header << 64) | random_data
        dut.dec_data_valid_in.value = 1

        expected_data = random_data if random_sync_header == 0b01 else 0x0000000000000000
        expected_dec_sync_error = 0 if random_sync_header == 0b01 else 1

        # Apply test and check output
        await Timer(5, units="ns")  # Wait before next random test
        await RisingEdge(dut.clk_in)
        dut.dec_data_valid_in.value = 0
        dut._log.info(f"Random Test {i+1}:\n"
                      f"  dec_data_in: {hex(dut.dec_data_in.value.to_unsigned())}")
        await check_output_decoder(dut, expected_data=expected_data, expected_dec_sync_error=expected_dec_sync_error)

@cocotb.test()
async def decoder_random_valid_data_test(dut):
    """ Test decoding with random sync headers and data """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())

    # Initialize DUT inputs
    await dut_initialization(dut)
    await RisingEdge(dut.clk_in)

    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    for i in range(5):  # Run 5 random tests
        random_sync_header = random.choice([0b01])
        random_data = random.getrandbits(64)

        dut.dec_data_in.value = (random_sync_header << 64) | random_data
        dut.dec_data_valid_in.value = 1

        expected_data = random_data if random_sync_header == 0b01 else 0x0000000000000000
        expected_dec_sync_error = 0 if random_sync_header == 0b01 else 1

        # Apply test and check output
        await Timer(5, units="ns")  # Wait before next random test
        await RisingEdge(dut.clk_in)
        dut.dec_data_valid_in.value = 0
        dut._log.info(f"Random Test {i+1}:\n"
                      f"  dec_data_in: {hex(dut.dec_data_in.value.to_unsigned())}")
        await check_output_decoder(dut, expected_data=expected_data, expected_dec_sync_error=expected_dec_sync_error)

@cocotb.test()
async def decoder_control_only_test(dut):
    """ Test decoding for control-only mode """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())

    # Initialize DUT inputs
    await dut_initialization(dut)
    await RisingEdge(dut.clk_in)

    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Control-only mode test cases
    test_cases = [
        (0b10, 0x1E, 0x3C78F1E3C78F1E, 0xFEFEFEFEFEFEFEFE, 0, 0),  # All control characters
        (0b10, 0x1E, 0x00000000000000, 0x0707070707070707, 0, 0),  # All control characters
        (0b00, 0x1E, 0x00000000000000, 0x0707070707070707, 1, 0),  # All control characters
        (0b10, 0x11, 0x3C78F1E3C78F1E, 0xFEFEFEFEFEFEFEFE, 0, 1),  # All control characters
    ]

    for sync_header, type_field, data_in, expected_data, expected_dec_sync_error, expected_dec_error_out in test_cases:
        dut.dec_data_in.value = (sync_header << 64) | (type_field << 56) | data_in
        dut.dec_data_valid_in.value = 1

        await Timer(5, units="ns")
        await RisingEdge(dut.clk_in)
        dut.dec_data_valid_in.value = 0
        dut._log.info(f"Control-Only Test:\n"
                      f"  dec_data_in: {hex(dut.dec_data_in.value.to_unsigned())}")
        await check_output_decoder(dut, expected_data=expected_data, expected_dec_sync_error=expected_dec_sync_error,
                           expected_control_out=0xFF, expected_dec_error_out=expected_dec_error_out)

@cocotb.test()
async def decoder_mixed_mode_test(dut):
    """ Test decoding for mixed mode """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())

    # Initialize DUT inputs
    await dut_initialization(dut)
    await RisingEdge(dut.clk_in)

    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Mixed mode test cases
    test_cases = [
        # Format: (sync_header, type_field, data_in, expected_data, expected_control_out, expected_dec_sync_error, expected_dec_error_out)
        (0b10, 0x33, 0xDDCCBB00000000, 0xDDCCBBFB07070707, 0x1F, 0, 0),  # Mixed mode example
        (0b10, 0x78, 0x3456789ABCDEF0, 0x3456789ABCDEF0FB, 0x01, 0, 0),  # Mixed mode example
        (0b10, 0x87, 0x00000000000000, 0x07070707070707FD, 0xFE, 0, 0),  # Mixed mode example
        (0b10, 0x99, 0x000000000000AE, 0x070707070707FDAE, 0xFE, 0, 0),  # Mixed mode example
        (0b10, 0xAA, 0x0000000000A5A5, 0x0707070707FDA5A5, 0xFC, 0, 0),  # Mixed mode example
        (0b10, 0xB4, 0x00000000FEED55, 0x07070707FDFEED55, 0xF8, 0, 0),  # Mixed mode example
        (0b10, 0xCC, 0x00000099887766, 0x070707FD99887766, 0xF0, 0, 0),  # Mixed mode example
        (0b10, 0xD2, 0x00001234567890, 0x0707FD1234567890, 0xE0, 0, 0),  # Mixed mode example
        (0b10, 0xE1, 0x00FFEEDDCCBBAA, 0x07FDFFEEDDCCBBAA, 0xC0, 0, 0),  # Mixed mode example
        (0b10, 0xFF, 0x773388229911AA, 0xFD773388229911AA, 0x80, 0, 0),  # Mixed mode example
        (0b10, 0x55, 0x070707FF070707, 0x0707079C0707079C, 0x11, 0, 0),  # Mixed mode example
        (0b10, 0x66, 0x7777770FDEEDDE, 0x777777FBDEEDDE9C, 0x11, 0, 0),  # Mixed mode example
        (0b10, 0x4B, 0x0000000ABCDEFF, 0x0707070755E6F79C, 0xF1, 0, 0),  # Mixed mode example
        (0b10, 0x2D, 0xAAAAAAF0000000, 0xAAAAAA9C07070707, 0x1F, 0, 0),  # Mixed mode example
    ]

    for sync_header, type_field, data_in, expected_data, expected_control_out, expected_dec_sync_error, expected_dec_error_out in test_cases:
        # Set inputs
        dut.dec_data_in.value = (sync_header << 64) | (type_field << 56) | data_in
        dut.dec_data_valid_in.value = 1

        # Wait for the output to stabilize
        await Timer(5, units="ns")
        await RisingEdge(dut.clk_in)

        # Check outputs
        await check_output_decoder(dut, expected_data=expected_data, expected_dec_sync_error=expected_dec_sync_error,
                           expected_control_out=expected_control_out, expected_dec_error_out=expected_dec_error_out)

        # Deassert valid signal
        dut.dec_data_valid_in.value = 0
        await RisingEdge(dut.clk_in)


@cocotb.test()
async def decoder_control_mixed_mode_dec_sync_error_test(dut):
    """ Test decoding for mixed mode """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())

    # Initialize DUT inputs
    await dut_initialization(dut)
    await RisingEdge(dut.clk_in)

    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Mixed mode test cases
    test_cases = [
        # Format: (sync_header, type_field, data_in, expected_data, expected_control_out, expected_dec_sync_error, expected_dec_error_out)
        (0b11, 0x33, 0xDDCCBB00000000, 0x0000000000000000, 0x00, 1, 0),  # Mixed mode example
        (0b00, 0x78, 0x3456789ABCDEF0, 0x0000000000000000, 0x00, 1, 0),  # Mixed mode example
        (0b11, 0x87, 0x00000000000000, 0x0000000000000000, 0x00, 1, 0),  # Mixed mode example
        (0b00, 0x99, 0x000000000000AE, 0x0000000000000000, 0x00, 1, 0),  # Mixed mode example
    ]

    for sync_header, type_field, data_in, expected_data, expected_control_out, expected_dec_sync_error, expected_dec_error_out in test_cases:
        # Set inputs
        dut.dec_data_in.value = (sync_header << 64) | (type_field << 56) | data_in
        dut.dec_data_valid_in.value = 1

        # Wait for the output to stabilize
        await Timer(5, units="ns")
        await RisingEdge(dut.clk_in)


        # Check outputs
        await check_output_decoder(dut, expected_data=expected_data, expected_dec_sync_error=expected_dec_sync_error,
                           expected_control_out=expected_control_out, expected_dec_error_out=expected_dec_error_out)

        # Deassert valid signal
        dut.dec_data_valid_in.value = 0
        await RisingEdge(dut.clk_in)


@cocotb.test()
async def decoder_control_mixed_mode_decoder_error_test(dut):
    """ Test decoding for mixed mode """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())

    # Initialize DUT inputs
    await dut_initialization(dut)
    await RisingEdge(dut.clk_in)

    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Mixed mode test cases
    test_cases = [
        # Format: (sync_header, type_field, data_in, expected_data, expected_control_out, expected_dec_sync_error, expected_dec_error_out)
        (0b10, 0x13, 0xDDCCBB00000000, 0x0000000000000000, 0x00, 0, 1),  # Mixed mode example
        (0b10, 0x18, 0x3456789ABCDEF0, 0x0000000000000000, 0x00, 0, 1),  # Mixed mode example
        (0b10, 0x27, 0x00000000000000, 0x0000000000000000, 0x00, 0, 1),  # Mixed mode example
        (0b10, 0x79, 0x000000000000AE, 0x0000000000000000, 0x00, 0, 1),  # Mixed mode example
        (0b10, 0x0A, 0x0000000000A5A5, 0x0000000000000000, 0x00, 0, 1),  # Mixed mode example
        (0b10, 0xD4, 0x00000000FEED55, 0x0000000000000000, 0x00, 0, 1),  # Mixed mode example
        (0b10, 0x0C, 0x00000099887766, 0x0000000000000000, 0x00, 0, 1),  # Mixed mode example
        (0b10, 0x22, 0x00001234567890, 0x0000000000000000, 0x00, 0, 1),  # Mixed mode example
    ]

    for sync_header, type_field, data_in, expected_data, expected_control_out, expected_dec_sync_error, expected_dec_error_out in test_cases:
        # Set inputs
        dut.dec_data_in.value = (sync_header << 64) | (type_field << 56) | data_in
        dut.dec_data_valid_in.value = 1

        # Wait for the output to stabilize
        await Timer(5, units="ns")
        await RisingEdge(dut.clk_in)


        # Check outputs
        await check_output_decoder(dut, expected_data=expected_data, expected_dec_sync_error=expected_dec_sync_error,
                           expected_control_out=expected_control_out, expected_dec_error_out=expected_dec_error_out)

        # Deassert valid signal
        dut.dec_data_valid_in.value = 0
        await RisingEdge(dut.clk_in)


