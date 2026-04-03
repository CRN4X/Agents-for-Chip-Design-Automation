###############################################################################
# test_scrambler_descrambler.py
###############################################################################
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles

import random
import os

async def reset_dut(dut, cycles=2):
    """Helper routine to reset the DUT for a specified number of clock cycles."""
    dut.rst.value = 1
    dut.data_in.value = 0
    dut.valid_in.value = 0
    dut.bypass_scrambling.value = 0
    await RisingEdge(dut.clk)
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

# Helper function to generate expected PRBS sequence
def generate_prbs(seed, poly_length, poly_tap, width, num_cycles):
    prbs_reg = [int(x) for x in f'{seed:0{poly_length}b}']
    prbs_out = []

    for _ in range(num_cycles):
        prbs_xor_a = []
        prbs = [prbs_reg]  # Initialize prbs[0] with the current PRBS register

        # Loop through each bit of the output width
        for i in range(width):
            # Perform XOR operation between specified tap and last stage of PRBS
            xor_a = prbs[i][poly_tap - 1] ^ prbs[i][poly_length - 1]
            prbs_xor_a.append(xor_a)

            # Shift the LFSR and insert the new XOR result to generate next state
            prbs_next = [xor_a] + prbs[i][0:poly_length - 1]
            prbs.append(prbs_next)

        # Collect the XOR result as the output for this cycle
        prbs_out.append(int(''.join(map(str, prbs_xor_a[::-1])), 2))

        # Update the PRBS register with the last stage (prbs[width])
        prbs_reg = prbs[width]

    return prbs_out

@cocotb.test()
async def test_scrambler_descrambler_sequential(dut):
    """
    Perform a single-run test of the scrambler_descrambler module in two phases:
      1) Scrambler Phase:
         - Reset the module
         - Feed incremental data (0, 1, 2, ...)
         - Capture the scrambled output
      2) Descrambler Phase:
         - Reset the same module again (re-initializing the PRBS)
         - Feed the previously captured scrambled data
         - The output should match the original incremental data exactly
    """
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    dut.rst.value = 0
    dut.data_in.value = 0
    dut.valid_in.value = 0
    dut.bypass_scrambling.value = 0
    check_mode = dut.CHECK_MODE.value
    await RisingEdge(dut.clk)
    
    if(check_mode == 0):
        # Start the clock

        ######################################################################
        # PHASE 1: SCRAMBLER
        ######################################################################
        # 1) Reset the DUT so the PRBS starts from its known seed
        await reset_dut(dut,cycles=2)

        # 2) Feed incremental data
        NUM_WORDS = int(dut.WIDTH.value)
        scrambled_data = []
        for i in range(2**NUM_WORDS):
            dut.data_in.value = i
            dut.valid_in.value = 1
            await RisingEdge(dut.clk)

            # Capture the scrambled output
            out_val = int(dut.data_out.value)
            scrambled_data.append(out_val)

        # Stop driving valid
        dut.valid_in.value = 0

        # Let a few cycles pass
        for _ in range(5):
            await RisingEdge(dut.clk)

        ######################################################################
        # PHASE 2: DESCRAMBLER
        ######################################################################
        # 1) Reset again so the PRBS restarts from the *same* seed
        dut.rst.value = 1
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst.value = 0
        await RisingEdge(dut.clk)

        # 2) Feed the scrambled data
        descrambled_data = []
        valid_out = []
        for i in range((2**NUM_WORDS)-1):
            dut.data_in.value = scrambled_data[i+1]
            dut.valid_in.value = 1
            await RisingEdge(dut.clk)

            # Capture the descrambled output
            out_val = int(dut.data_out.value)
            if(dut.valid_out.value.to_unsigned()):
                descrambled_data.append(out_val)
            valid_out.append(dut.valid_out.value)

        # Stop driving valid
        dut.valid_in.value = 0
        for _ in range(5):
            await RisingEdge(dut.clk)

        ######################################################################
        # FINAL CHECK
        ######################################################################
        # Compare the descrambled data with the original incremental data
        mismatches = 0
        for i, data in enumerate(descrambled_data):
            if(i!= 0):
                if ((data != i)):
                    mismatches += 1
                    cocotb.log.error(f"Mismatch at index {i}: expected {i-1}, got {data}")

        assert mismatches == 0, f"Found {mismatches} mismatches!"
        cocotb.log.info("TEST PASSED: Descrambled data matches original incremental data.")

    else:
        
        await reset_dut(dut,cycles=2)
        # Test Parameters
        check_mode  = int(dut.CHECK_MODE.value)   # Select mode: generator or checker
        poly_length = int(dut.POLY_LENGTH.value)  # Length of the polynomial
        poly_tap    = int(dut.POLY_TAP.value)     # Tap position in the polynomial
        width       = int(dut.WIDTH.value)        # Width of the PRBS output
        num_cycles  = 10                          # Number of cycles to run the test

        # Seed value for PRBS generation (all bits set to 1 initially)
        seed = int('1' * poly_length, 2)
        # Reset the DUT (Device Under Test)
        dut.rst.value = 1
        dut.bypass_scrambling.value = 0
        dut.data_in.value = 0  # Initialize data_in to 0
        await ClockCycles(dut.clk, 5)  # Wait for 5 clock cycles

        # Release the reset and enable PRBS checking
        dut.rst.value = 0  # Release reset
        dut.valid_in.value = 1

        # Generate expected PRBS sequence to feed into data_in
        prbs_sequence = generate_prbs(seed, poly_length, poly_tap, width, num_cycles+1)

        cocotb.log.info(f"prbs_sequence: {prbs_sequence}")
        # Initialize error flag
        error_flag = 0

        # Wait for a rising edge of the clock to ensure reset is low
        # await RisingEdge(dut.clk)
        # Apply PRBS data_in
        dut.data_in.value = prbs_sequence[0]

        # Wait for a clock cycle
        await RisingEdge(dut.clk)
        dut.data_in.value = prbs_sequence[1]

        # Wait for a clock cycle
        await RisingEdge(dut.clk)

        # Send the PRBS sequence to the DUT via data_in
        for cycle in range(2,num_cycles):
            # Apply PRBS data_in
            dut.data_in.value = prbs_sequence[cycle]

            # Wait for a clock cycle
            await RisingEdge(dut.clk)

            # Read the error flag from data_out (assuming data_out is the error indicator)
            error_flag = dut.data_out.value.to_unsigned()

            if(cycle>0):
            # Check that error_flag is 0 (no error)
                assert error_flag == 0, f"No error expected, but error detected at cycle {cycle}, data out: {error_flag}"
                assert dut.valid_out.value.to_unsigned() == 1, f"Valid not asserted"

        # Introduce an error in the data_in
        dut.data_in.value = prbs_sequence[num_cycles] ^ 0x1  # Flip one bit to introduce error

        # Wait for a few clock cycles
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        
        # Read the error flag after introducing the error
        error_flag = dut.data_out.value.to_unsigned()

        # Check that error_flag is 1 (error detected)
        assert error_flag >0, f"Error expected, but no error detected"
        assert dut.valid_out.value.to_unsigned() == 1, f"Valid not asserted"

@cocotb.test()
async def test_bypass_mode(dut):
    """
    Test that bypass_scrambling=1 passes input data directly to output,
    without PRBS alteration.
    """
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await RisingEdge(dut.clk)

    await reset_dut(dut, cycles=3)
    dut.bypass_scrambling.value = 1  # Enable bypass

    test_size = 20
    width = int(getattr(dut, "WIDTH", 16).value)

    random_data = [random.randint(0, (1 << width) - 1) for _ in range(test_size)]
    observed_data = []

    for val in random_data:
        dut.data_in.value = val
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
        if(dut.valid_out.value.to_unsigned()):
            out_val = int(dut.data_out.value)
            observed_data.append(out_val)

    # Stop driving valid
    dut.valid_in.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    # Verify output == input
    mismatches = 0
     # Check if observed_data is empty and raise an error if so
    if not observed_data:
        raise cocotb.log.error("No output data was observed!")
    else:
        for idx, (inp, obs) in enumerate(zip(random_data, observed_data)):
            if inp != obs:
                mismatches += 1
                cocotb.log.error(f"Bypass mismatch idx={idx}: sent=0x{inp:X}, got=0x{obs:X}")

    assert mismatches == 0, f"Bypass mode: Found {mismatches} mismatch(es)!"
    cocotb.log.info("TEST PASSED: Bypass mode correctly forwards input to output.")


@cocotb.test()
async def test_bit_count(dut):
    """
    Test the DUT's bit counter. We'll do two runs of valid data and
    ensure bit_count increments by (num_words * WIDTH) each time.
    """
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await RisingEdge(dut.clk)
    await reset_dut(dut, cycles=3)

    width = int(getattr(dut, "WIDTH", 16).value)

    # 1) First run
    num_words_1 = 10
    num_words_2 = 15
    poly_length = int(dut.POLY_LENGTH.value)  # Length of the polynomial
    poly_tap    = int(dut.POLY_TAP.value)     # Tap position in the polynomial
    width       = int(dut.WIDTH.value)        # Width of the PRBS output
    check_mode = dut.CHECK_MODE.value
    # Seed value for PRBS generation (all bits set to 1 initially)
    seed = int('1' * poly_length, 2)
    if(check_mode == 0):
        for i in range(num_words_1):
            dut.data_in.value = i
            dut.valid_in.value = 1
            await RisingEdge(dut.clk)
    
        # Flush
        dut.valid_in.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
    
        # Check the counter
        expected_bits_1 = num_words_1 * width
            
        actual_bits_1 = int(dut.bit_count.value)
        cocotb.log.info(f"[BitCount] After first run: bit_count={actual_bits_1}, expected={expected_bits_1}")
        assert actual_bits_1 == expected_bits_1, "Bit count mismatch after first run!"
    
        # 2) Second run
        for i in range(num_words_2):
            dut.data_in.value = i
            dut.valid_in.value = 1
            await RisingEdge(dut.clk)
    
        # Flush
        dut.valid_in.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
    
        # Check the counter
        expected_bits_2 = (num_words_1 + num_words_2) * width
        actual_bits_2 = int(dut.bit_count.value)
        cocotb.log.info(f"[BitCount] After second run: bit_count={actual_bits_2}, expected={expected_bits_2}")
        assert actual_bits_2 == expected_bits_2, "Bit count mismatch after second run!"
    
        cocotb.log.info("TEST PASSED: bit_count increments exactly as expected.")
    else :
        # Reset the DUT (Device Under Test)
        dut.rst.value = 1
        dut.bypass_scrambling.value = 0
        dut.data_in.value = 0  # Initialize data_in to 0
        await ClockCycles(dut.clk, 5)  # Wait for 5 clock cycles

        # Release the reset and enable PRBS checking
        dut.rst.value = 0  # Release reset
        dut.valid_in.value = 1
        # Generate expected PRBS sequence to feed into data_in
        prbs_sequence = generate_prbs(seed, poly_length, poly_tap, width, num_words_1+num_words_2)
        for i in range(num_words_1+num_words_2):
            dut.data_in.value = prbs_sequence[i]
            dut.valid_in.value = 1
            await RisingEdge(dut.clk)
            if(i==num_words_1):
                actual_bits_1 = int(dut.bit_count.value)
        dut.valid_in.value = 0
        await RisingEdge(dut.clk)
        actual_bits_2 = int(dut.bit_count.value)
        
        # Check the counter
        expected_bits_1 = num_words_1 * width
        cocotb.log.info(f"[BitCount] After first run: bit_count={actual_bits_1}, expected={expected_bits_1}")
        assert actual_bits_1 == expected_bits_1, "Bit count mismatch after first run!"
    
        # Check the counter
        expected_bits_2 = (num_words_1 + num_words_2) * width
        cocotb.log.info(f"[BitCount] After second run: bit_count={actual_bits_2}, expected={expected_bits_2}")
        assert actual_bits_2 == expected_bits_2, "Bit count mismatch after second run!"
    
        cocotb.log.info("TEST PASSED: bit_count increments exactly as expected.")
