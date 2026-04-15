import cocotb
from cocotb.triggers import Timer

# Define our own helper functions for to_unsigned and to_signed.
def to_unsigned(val, nbits):
    """Return the unsigned representation of val as an int with nbits bits."""
    mask = (1 << nbits) - 1
    return val & mask

def to_signed(val, nbits):
    """Return the signed representation of val as an int with nbits bits."""
    mask = (1 << nbits) - 1
    val = val & mask
    if val & (1 << (nbits - 1)):
        return val - (1 << nbits)
    else:
        return val

# Helper coroutine to simulate clock cycles by toggling the clock sequentially.
async def cycle(dut, num_cycles=1):
    for _ in range(num_cycles):
        dut.clk.value = to_unsigned(0, 1)
        await Timer(5, units="ns")
        dut.clk.value = to_unsigned(1, 1)
        await Timer(5, units="ns")

@cocotb.test()
async def test_custom_byte_enable_ram(dut):
    # Constants: XLEN is 32, LINES is 8192, so ADDR_WIDTH is 13.
    ADDR_WIDTH = 13  # since 2^13 = 8192

    # Initialize signals using .value assignments with our to_unsigned helper.
    dut.addr_a.value = to_unsigned(0, ADDR_WIDTH)
    dut.addr_b.value = to_unsigned(0, ADDR_WIDTH)
    dut.en_a.value   = to_unsigned(0, 1)
    dut.en_b.value   = to_unsigned(0, 1)
    dut.be_a.value   = to_unsigned(0, 4)
    dut.be_b.value   = to_unsigned(0, 4)
    dut.data_in_a.value = to_unsigned(0, 32)
    dut.data_in_b.value = to_unsigned(0, 32)

    # Wait for a few clock cycles for initialization.
    await cycle(dut, 2)

    # --------------------------------------------------
    # Test 1: Write from Port A
    # Write 0xDEADBEEF to address 0 using full byte-enable.
    dut.addr_a.value   = to_unsigned(0, ADDR_WIDTH)
    dut.en_a.value     = to_unsigned(1, 1)
    dut.be_a.value     = to_unsigned(0b1111, 4)
    dut.data_in_a.value = to_unsigned(0xDEADBEEF, 32)
    await cycle(dut, 1)  # Wait one cycle for the pipeline stage update.
    dut.en_a.value     = to_unsigned(0, 1)
    await cycle(dut, 3)  # Wait additional cycles for memory update and pipelined read.
    expected_val = to_unsigned(0xDEADBEEF, 32)
    actual_val = int(dut.data_out_a.value)
    dut._log.info("Test 1: Port A read at addr 0 = 0x%X (Expected: 0x%X)" %
                  (actual_val, expected_val))
    assert actual_val == expected_val, "Test 1 failed: expected 0x%X, got 0x%X" % (expected_val, actual_val)

    # --------------------------------------------------
    # Test 2: Write from Port B with Partial Byte Enable
    # Write 0xCAFEBABE to address 1, enabling only the upper 2 bytes.
    dut.addr_b.value   = to_unsigned(1, ADDR_WIDTH)
    dut.en_b.value     = to_unsigned(1, 1)
    dut.be_b.value     = to_unsigned(0b1100, 4)  # Only bytes 2 and 3 will be written.
    dut.data_in_b.value = to_unsigned(0xCAFEBABE, 32)
    await cycle(dut, 1)
    dut.en_b.value     = to_unsigned(0, 1)
    await cycle(dut, 3)
    # Expected result: upper 16 bits (0xCAFE) updated; lower 16 bits remain 0.
    expected_val = to_unsigned(0xCAFE0000, 32)
    actual_val = int(dut.data_out_b.value)
    dut._log.info("Test 2: Port B read at addr 1 = 0x%X (Expected: 0x%X)" %
                  (actual_val, expected_val))
    assert actual_val == expected_val, "Test 2 failed: expected 0x%X, got 0x%X" % (expected_val, actual_val)

    # --------------------------------------------------
    # Test 3: Simultaneous Write (Collision Handling)
    # Both ports write to address 2:
    #   - Port A writes to lower half (byte-enable 0011)
    #   - Port B writes to upper half (byte-enable 1100)
    dut.addr_a.value   = to_unsigned(2, ADDR_WIDTH)
    dut.addr_b.value   = to_unsigned(2, ADDR_WIDTH)
    dut.en_a.value     = to_unsigned(1, 1)
    dut.en_b.value     = to_unsigned(1, 1)
    dut.be_a.value     = to_unsigned(0b0011, 4)  # Write lower two bytes.
    dut.data_in_a.value = to_unsigned(0x00001234, 32)  # Lower half: 0x1234.
    dut.be_b.value     = to_unsigned(0b1100, 4)  # Write upper two bytes.
    dut.data_in_b.value = to_unsigned(0xABCD0000, 32)  # Upper half: 0xABCD.
    await cycle(dut, 1)
    dut.en_a.value = to_unsigned(0, 1)
    dut.en_b.value = to_unsigned(0, 1)
    await cycle(dut, 3)
    expected_val = to_unsigned(0xABCD1234, 32)
    actual_val_a = int(dut.data_out_a.value)
    actual_val_b = int(dut.data_out_b.value)
    dut._log.info("Test 3: Port A read at addr 2 = 0x%X (Expected: 0x%X)" %
                  (actual_val_a, expected_val))
    dut._log.info("Test 3: Port B read at addr 2 = 0x%X (Expected: 0x%X)" %
                  (actual_val_b, expected_val))
    assert actual_val_a == expected_val, "Test 3 failed on Port A: expected 0x%X, got 0x%X" % (expected_val, actual_val_a)
    assert actual_val_b == expected_val, "Test 3 failed on Port B: expected 0x%X, got 0x%X" % (expected_val, actual_val_b)

    # --------------------------------------------------
    # Test 4: Sequential Partial Updates on the Same Address Using Port A
    # Step 1: Write lower half at address 3.
    dut.addr_a.value   = to_unsigned(3, ADDR_WIDTH)
    dut.en_a.value     = to_unsigned(1, 1)
    dut.be_a.value     = to_unsigned(0b0011, 4)  # Write lower two bytes.
    dut.data_in_a.value = to_unsigned(0x00001234, 32)  # Lower half: 0x1234.
    await cycle(dut, 1)
    dut.en_a.value     = to_unsigned(0, 1)
    await cycle(dut, 3)
    # Step 2: Write upper half.
    dut.addr_a.value   = to_unsigned(3, ADDR_WIDTH)
    dut.en_a.value     = to_unsigned(1, 1)
    dut.be_a.value     = to_unsigned(0b1100, 4)  # Write upper two bytes.
    dut.data_in_a.value = to_unsigned(0xABCD0000, 32)  # Upper half: 0xABCD.
    await cycle(dut, 1)
    dut.en_a.value     = to_unsigned(0, 1)
    await cycle(dut, 3)
    expected_val = to_unsigned(0xABCD1234, 32)
    actual_val = int(dut.data_out_a.value)
    dut._log.info("Test 4: Port A read at addr 3 = 0x%X (Expected: 0x%X)" %
                  (actual_val, expected_val))
    assert actual_val == expected_val, "Test 4 failed: expected 0x%X, got 0x%X" % (expected_val, actual_val)

    # --------------------------------------------------
    # Test 5: Independent Writes on Different Addresses Simultaneously
    # Port A writes 0xAAAAAAAA to address 5.
    # Port B writes 0x55555555 to address 6.
    dut.addr_a.value   = to_unsigned(5, ADDR_WIDTH)
    dut.en_a.value     = to_unsigned(1, 1)
    dut.be_a.value     = to_unsigned(0b1111, 4)
    dut.data_in_a.value = to_unsigned(0xAAAAAAAA, 32)
    dut.addr_b.value   = to_unsigned(6, ADDR_WIDTH)
    dut.en_b.value     = to_unsigned(1, 1)
    dut.be_b.value     = to_unsigned(0b1111, 4)
    dut.data_in_b.value = to_unsigned(0x55555555, 32)
    await cycle(dut, 1)
    dut.en_a.value     = to_unsigned(0, 1)
    dut.en_b.value     = to_unsigned(0, 1)
    await cycle(dut, 3)
    expected_val = to_unsigned(0xAAAAAAAA, 32)
    actual_val = int(dut.data_out_a.value)
    dut._log.info("Test 5: Port A read at addr 5 = 0x%X (Expected: 0x%X)" %
                  (actual_val, expected_val))
    assert actual_val == expected_val, "Test 5 failed on Port A: expected 0x%X, got 0x%X" % (expected_val, actual_val)

    expected_val = to_unsigned(0x55555555, 32)
    actual_val = int(dut.data_out_b.value)
    dut._log.info("Test 5: Port B read at addr 6 = 0x%X (Expected: 0x%X)" %
                  (actual_val, expected_val))
    assert actual_val == expected_val, "Test 5 failed on Port B: expected 0x%X, got 0x%X" % (expected_val, actual_val)

    # End simulation after additional cycles.
    await cycle(dut, 5)
