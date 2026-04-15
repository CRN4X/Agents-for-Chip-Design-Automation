import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.clock import Clock
import logging

async def send_byte(dut, data_in):
    """
    Sends a byte (8 bits) via SPI using bit-banging.

    Args:
        dut: The Device Under Test (DUT) instance.
        data_in (int): The 8-bit data to send via MOSI.

    Usage:
        received_data = []
        await send_byte(dut, 0xA5)
    """
    
    # Ensure CS (Chip Select) is active (low)
    await FallingEdge(dut.spi_sck)  # Wait for a stable clock
    dut.spi_cs_n.value = 0

    for i in range(8):
        # Set MOSI bit (MSB first)
        dut.spi_mosi.value = (data_in >> (7 - i)) & 1
        
        await RisingEdge(dut.spi_sck)  # Wait for clock rising edge
        await FallingEdge(dut.spi_sck)  # Wait for clock falling edge

    # Deactivate CS after transmission
    dut.spi_cs_n.value = 1

async def send_receive_byte(dut, data_in, data_out):
    """
    Sends a byte (8 bits) via SPI using bit-banging and simultaneously reads a byte.

    Args:
        dut: The Device Under Test (DUT) instance.
        data_in (int): The 8-bit data to send via MOSI.
        data_out (list): A mutable list to store the received 8-bit data from MISO.

    Usage:
        received_data = []
        await send_byte(dut, 0xA5, received_data)
        print(f"Received: {hex(received_data[0])}")
    """
    
    # Ensure CS (Chip Select) is active (low)
    await FallingEdge(dut.spi_sck)  # Wait for a stable clock
    dut.spi_cs_n.value = 0

    received = 0  # Variable to store the received byte

    for i in range(8):
        # Set MOSI bit (MSB first)
        dut.spi_mosi.value = (data_in >> (7 - i)) & 1

        # Read MISO bit (MSB first)
        await RisingEdge(dut.spi_sck)  # Wait for clock rising edge
        received = (received << 1) | int(dut.spi_miso.value)

        await FallingEdge(dut.spi_sck)  # Wait for clock falling edge

    # Store the received data in the list (so it can be accessed outside the function)
    data_out.append(received)

    # Deactivate CS after transmission
    dut.spi_cs_n.value = 1

def complex_multiply(msb_Ar, lsb_Ar, msb_Ai, lsb_Ai, msb_Br, lsb_Br, msb_Bi, lsb_Bi):
    """
    Combines two separate bytes into signed 16-bit integers for Ar, Ai, Br, Bi
    and performs complex multiplication.

    Args:
        msb_Ar, lsb_Ar (int): Most and least significant bytes for Ar.
        msb_Ai, lsb_Ai (int): Most and least significant bytes for Ai.
        msb_Br, lsb_Br (int): Most and least significant bytes for Br.
        msb_Bi, lsb_Bi (int): Most and least significant bytes for Bi.

    Returns:
        tuple: (Cr, Ci) - The real and imaginary parts of the complex multiplication result.
    """

    # Combine MSB and LSB into a signed 16-bit integer
    Ar = int.from_bytes([msb_Ar, lsb_Ar], byteorder='big', signed=True)
    Ai = int.from_bytes([msb_Ai, lsb_Ai], byteorder='big', signed=True)
    Br = int.from_bytes([msb_Br, lsb_Br], byteorder='big', signed=True)
    Bi = int.from_bytes([msb_Bi, lsb_Bi], byteorder='big', signed=True)

    # Perform complex multiplication
    Cr = (Ar * Br) - (Ai * Bi)  # Real part
    Ci = (Ar * Bi) + (Ai * Br)  # Imaginary part

    return Cr, Ci  # Return the result as a tuple


def check_condition(condition, fail_msg, pass_msg, test_failures):
    """Helper function to log test results"""
    if not condition:
        logging.getLogger().error(fail_msg)
        test_failures.append(fail_msg)
    else:
        logging.getLogger().info(pass_msg)

@cocotb.test()
async def test1(dut):
    """Test 1: Send operands bytes and compare complex multiplication"""

    logger = dut._log
    logger.setLevel(logging.INFO)
    logger.info("Test 1: Send operands bytes and compare complex multiplication")

    # Retrieve IN_WIDTH and OUT_WIDTH from DUT parameters
    IN_WIDTH = int(dut.IN_WIDTH.value)
    OUT_WIDTH = int(dut.OUT_WIDTH.value)

    # Start the clocks
    cocotb.start_soon(Clock(dut.spi_sck, 10, units="ns").start())

    # Reset
    dut.rst_async_n.value = 0
    await Timer(50, units='ns')  # Hold reset low for 50 ns
    dut.rst_async_n.value = 1

    # Wait for reset deassertion
    await RisingEdge(dut.spi_sck)

    # Send the bytes to perform the complex multiplication
    msb_Ar = 0xA5  # Write a byte
    lsb_Ar = 0xF2  # Write a byte
    msb_Ai = 0xB3  # Write a byte
    lsb_Ai = 0x08  # Write a byte
    msb_Br = 0xFF  # Write a byte
    lsb_Br = 0x42  # Write a byte
    msb_Bi = 0x77  # Write a byte
    lsb_Bi = 0x2C  # Write a byte
    await send_byte(dut, msb_Ar)
    await send_byte(dut, lsb_Ar)
    await send_byte(dut, msb_Ai)
    await send_byte(dut, lsb_Ai)
    await send_byte(dut, msb_Br)
    await send_byte(dut, lsb_Br)
    await send_byte(dut, msb_Bi)
    await send_byte(dut, lsb_Bi)

    # Perform complex multiplication
    expected_real, expected_imag = complex_multiply(msb_Ar, lsb_Ar, msb_Ai, lsb_Ai, msb_Br, lsb_Br, msb_Bi, lsb_Bi)

    # Receive the result multiplication while send another bytes
    byte_3_Cr = []
    byte_2_Cr = []
    byte_1_Cr = []
    byte_0_Cr = []
    byte_3_Ci = []
    byte_2_Ci = []
    byte_1_Ci = []
    byte_0_Ci = []
    await send_receive_byte(dut, msb_Ar, byte_3_Cr)
    await send_receive_byte(dut, msb_Ar, byte_2_Cr)
    await send_receive_byte(dut, msb_Ar, byte_1_Cr)
    await send_receive_byte(dut, msb_Ar, byte_0_Cr)
    await send_receive_byte(dut, msb_Ar, byte_3_Ci)
    await send_receive_byte(dut, msb_Ar, byte_2_Ci)
    await send_receive_byte(dut, msb_Ar, byte_1_Ci)
    await send_receive_byte(dut, msb_Ar, byte_0_Ci)

    Cr = int.from_bytes([int(byte_3_Cr[0]), int(byte_2_Cr[0]), int(byte_1_Cr[0]), int(byte_0_Cr[0])], byteorder='big', signed=True)
    Ci = int.from_bytes([int(byte_3_Ci[0]), int(byte_2_Ci[0]), int(byte_1_Ci[0]), int(byte_0_Ci[0])], byteorder='big', signed=True)
    
    # Initialize list to collect failures
    test_failures = []

    # Check Data Output Real
    check_condition(
        Cr == expected_real,
        f"FAIL: Data Output Real mismatch. Expected: 0x{expected_real}, "
        f"Got: 0x{Cr}",
        f"PASS: Data Output Real value: 0x{Cr}",
        test_failures
    )

    # Check Data Output Imaginary
    check_condition(
        Ci == expected_imag,
        f"FAIL: Data Output Imaginary mismatch. Expected: 0x{expected_imag}, "
        f"Got: 0x{Ci}",
        f"PASS: Data Output Imaginary value: 0x{Ci}",
        test_failures
    )
    
    # Report failures if any
    if test_failures:
        failure_message = "\n".join(test_failures)
        logger.error(f"Test 1 completed with failures:\n{failure_message}")
        assert False, f"Some test cases failed. Check the log for details:\n{failure_message}"
    else:
        logger.info("Test 1 completed successfully")