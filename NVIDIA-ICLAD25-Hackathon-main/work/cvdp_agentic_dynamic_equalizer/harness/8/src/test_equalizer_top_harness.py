import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.clock import Clock
import logging
import random

DATA_WIDTH = 16
FRAC_BITS = 13
SHIFT_LUT = 4

# Copy of RTL LUT in decimal
NOISE_LUT = [
    2048,  -1024,   128,  -3072,
    1024,  -2048,  3072,   -128,
       0,    512,  -512,    256,
    -256,    768,  -768,      0
]

def fixed_point_mult(a, b, shift=FRAC_BITS):
    """Multiplies two Q2.13 values ​​and returns Q2.13 with adjustment"""
    return (a * b) >> shift

def fixed_point_shift(val, left_shift):
    """Apply a left shift to simulate << in SV"""
    return val << left_shift

def check_condition(condition, fail_msg, pass_msg, test_failures):
    """Helper function to log test results"""
    if not condition:
        logging.getLogger().error(fail_msg)
        test_failures.append(fail_msg)
    else:
        logging.getLogger().info(pass_msg)

@cocotb.test()
async def test_awgn_real_component(dut):
    """Check that AWGN adds the correct noise to data_in_real"""

    logger = dut._log
    logger.setLevel(logging.INFO)
    logger.info("Check that AWGN adds the correct noise to data_in_real")

    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    dut.rst_n.value = 0
    dut.data_in_real.value = 0
    dut.data_in_imag.value = 0
    dut.noise_index.value = 0
    dut.noise_scale.value = 2048  # 0.25 in Q2.13

    # Initialize list to collect failures
    test_failures = []

    for _ in range(20):
        await RisingEdge(dut.clk)

        # Stimulus
        signal_in = random.choice([8192, -8192])  # ±1.0 in Q2.13
        noise_idx = random.randint(0, 15)
        noise_val = NOISE_LUT[noise_idx]

        # Apply signals
        dut.data_in_real.value = signal_in
        dut.data_in_imag.value = signal_in
        dut.noise_index.value = noise_idx

        await Timer(1, units="ns")  # Wait logic update

        # Expected noise calculation
        noise_scaled = int(noise_val * 0.25)
        noise_scaled_q213 = noise_scaled
        expected = (signal_in + noise_scaled_q213)

        # Reading the result
        out_real = dut.uu_awgn_real.signal_out.value.signed_integer

        # Check Data Output Imaginary
        check_condition(
            out_real == expected,
            f"FAIL: Data Output mismatch. Expected: {expected}, "
            f"Got: {out_real}",
            f"PASS: Data Output value: {out_real}",
            test_failures
        )

    # Report failures if any
    if test_failures:
        failure_message = "\n".join(test_failures)
        logger.error(f"Test AWGN real component completed with failures:\n{failure_message}")
        assert False, f"Some test cases failed. Check the log for details:\n{failure_message}"
    else:
        logger.info("Test AWGN real component completed successfully")

@cocotb.test()
async def test_awgn_imag_component(dut):
    """Check that AWGN adds the correct noise to data_in_imag"""

    logger = dut._log
    logger.setLevel(logging.INFO)
    logger.info("Check that AWGN adds the correct noise to data_in_imag")

    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    dut.rst_n.value = 0
    dut.data_in_real.value = 0
    dut.data_in_imag.value = 0
    dut.noise_index.value = 0
    dut.noise_scale.value = 2048  # 0.25 in Q2.13

    # Initialize list to collect failures
    test_failures = []

    for _ in range(20):
        await RisingEdge(dut.clk)

        # Stimulus
        signal_in = random.choice([8192, -8192])  # ±1.0 in Q2.13
        noise_idx = random.randint(0, 15)
        noise_val = NOISE_LUT[noise_idx]

        # Apply signals
        dut.data_in_real.value = signal_in
        dut.data_in_imag.value = signal_in
        dut.noise_index.value = noise_idx

        await Timer(1, units="ns")  # Wait logic update

        # Expected noise calculation
        noise_scaled = int(noise_val * 0.25)
        noise_scaled_q213 = noise_scaled
        expected = (signal_in + noise_scaled_q213)

        # Reading the result
        out_imag = dut.uu_awgn_imag.signal_out.value.signed_integer

        # Check Data Output Imaginary
        check_condition(
            out_imag == expected,
            f"FAIL: Data Output mismatch. Expected: {expected}, "
            f"Got: {out_imag}",
            f"PASS: Data Output value: {out_imag}",
            test_failures
        )

    # Report failures if any
    if test_failures:
        failure_message = "\n".join(test_failures)
        logger.error(f"Test AWGN imaginary component completed with failures:\n{failure_message}")
        assert False, f"Some test cases failed. Check the log for details:\n{failure_message}"
    else:
        logger.info("Test AWGN imaginary component completed successfully")

@cocotb.test()
async def test_equalizer_learns_identity(dut):
    """Test if output equals input after 3 cycles when input == desired"""

    logger = dut._log
    logger.setLevel(logging.INFO)
    logger.info("Test if output equals input after 3 cycles when input == desired")

    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    # History buffer
    in_history_real = []
    in_history_imag = []

    for i in range(20):
        # AWGN config
        dut.noise_index.value = 8
        dut.noise_scale.value = 0

        # Random input: 8192 or -8192
        value_real = random.choice([8192, -8192])
        value_imag = random.choice([8192, -8192])
        
        # Apply to input
        dut.data_in_real.value = value_real
        dut.data_in_imag.value = value_imag

        # Store input for comparison later
        in_history_real.append(value_real)
        in_history_imag.append(value_imag)
        
        # Initialize list to collect failures
        test_failures = []

        # After 3 cycles, expect output = input (since input == desired)
        if i >= 5:
            expected_real = in_history_real[i - 5]
            expected_imag = in_history_imag[i - 5]
            out_real = dut.data_out_real.value.signed_integer
            out_imag = dut.data_out_imag.value.signed_integer

            # Check Data Output Real
            check_condition(
                out_real == expected_real,
                f"FAIL: Data Output Real mismatch. Expected: {expected_real}, "
                f"Got: {out_real}",
                f"PASS: Data Output Real value: {out_real}",
                test_failures
            )

            # Check Data Output Imaginary
            check_condition(
                out_imag == expected_imag,
                f"FAIL: Data Output Imaginary mismatch. Expected: {expected_imag}, "
                f"Got: {out_imag}",
                f"PASS: Data Output Imaginary value: {out_imag}",
                test_failures
            )
            
        await RisingEdge(dut.clk)

    # Report failures if any
    if test_failures:
        failure_message = "\n".join(test_failures)
        logger.error(f"Test identity completed with failures:\n{failure_message}")
        assert False, f"Some test cases failed. Check the log for details:\n{failure_message}"
    else:
        logger.info("Test identity completed successfully")

@cocotb.test()
async def test_equalizer_data_quadrant(dut):
    """Test if output data quadrant is the desired"""

    logger = dut._log
    logger.setLevel(logging.INFO)
    logger.info("Test if output data quadrant is the desired")

    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    # History buffer
    in_history_real = []
    in_history_imag = []

    for i in range(20):
        # AWGN config
        dut.noise_index.value = random.randint(0, 15)
        dut.noise_scale.value = 2048 # Equivalent to 0.25 in Q2.13

        # Random input with error
        value_real = random.choice([8390, 8192, 7800, -8390, -8192, -7800])
        value_imag = random.choice([8390, 8192, 7800, -8390, -8192, -7800])
        
        # Apply to input
        dut.data_in_real.value = value_real
        dut.data_in_imag.value = value_imag

        # Store input for comparison later
        in_history_real.append(value_real)
        in_history_imag.append(value_imag)
        
        # Initialize list to collect failures
        test_failures = []

        # After 3 cycles, expect output = input (since input == desired)
        if i >= 5:
            expected_real = in_history_real[i - 5]
            expected_imag = in_history_imag[i - 5]
            out_real = dut.data_out_real.value.signed_integer
            out_imag = dut.data_out_imag.value.signed_integer

            # Check Data Output Real
            check_condition(
                (out_real > 0) == (expected_real > 0),
                f"FAIL: Data Output Real Quadrant mismatch. Expected: {(expected_real > 0)}, "
                f"Got: {(out_real > 0)}",
                f"PASS: Data Output Real Quadrant value: {(out_real > 0)}",
                test_failures
            )

            # Check Data Output Imaginary
            check_condition(
                (out_imag > 0) == (expected_imag > 0),
                f"FAIL: Data Output Imaginary Quadrant mismatch. Expected: {(expected_imag > 0)}, "
                f"Got: {(out_imag > 0)}",
                f"PASS: Data Output Imaginary Quadrant value: {(out_imag > 0)}",
                test_failures
            )
            
        await RisingEdge(dut.clk)

    # Report failures if any
    if test_failures:
        failure_message = "\n".join(test_failures)
        logger.error(f"Test quadrant completed with failures:\n{failure_message}")
        assert False, f"Some test cases failed. Check the log for details:\n{failure_message}"
    else:
        logger.info("Test quadrant completed successfully")
