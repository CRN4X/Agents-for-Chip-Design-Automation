
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import random

@cocotb.test()
async def test_lfsr_with_Fixed_seed(dut):
    """Test LFSR with a given seed value"""

    # Start the clock
    clock = Clock(dut.clock, 10, units="ns")  # Create a clock with 100MHz frequency
    cocotb.start_soon(clock.start())  # Start the clock
    
    # Seed value
    seed = 0xACE1  # Example seed value for the LFSR
    print(f"Seed value: {hex(seed)}")
    # Apply reset and load seed value
    dut.reset.value = 1  # Assert reset initially
    await RisingEdge(dut.clock)  # Wait for a clock cycle
    
    dut.reset.value = 0  # De-assert reset after some cycles
    dut.lfsr_seed.value = seed  # Load the seed into the LFSR
    
    await RisingEdge(dut.clock)  # Wait for reset to propagate
    dut.reset.value = 1  # De-assert reset after initial seed is loaded

    await RisingEdge(dut.clock)
    
    # Start running the LFSR for 65536 clock cycles and check the sequence
    await run_lfsr_sequence_check(dut, cycles=65536, check_maximal_length=True)


@cocotb.test()
async def test_lfsr_random_seed(dut):
    """Test LFSR with a random seed value"""

    # Start the clock
    clock = Clock(dut.clock, 10, units="ns")  # 100 MHz clock
    cocotb.start_soon(clock.start())

    # Seed value (random)
    seed = random.randint(0, 0xFFFF)  # Generate a random 16-bit seed
    print(f"Seed value: {hex(seed)}")
    # Apply reset and load seed value
    dut.reset.value = 1  # Assert reset
    await RisingEdge(dut.clock)
    
    dut.reset.value = 0  # De-assert reset
    dut.lfsr_seed.value = seed  # Load the random seed into the LFSR
    
    await RisingEdge(dut.clock)
    dut.reset.value = 1  # De-assert reset after seed is loaded

    await RisingEdge(dut.clock)
    
    # Start running the LFSR for 65536 clock cycles and check the sequence
    await run_lfsr_sequence_check(dut, cycles=65536, check_maximal_length=True)


@cocotb.test()
async def test_lfsr_all_bits_set_seed(dut):
    """Test LFSR with all bits set (0xFFFF) seed value"""

    # Start the clock
    clock = Clock(dut.clock, 10, units="ns")  # 100 MHz clock
    cocotb.start_soon(clock.start())

    # Seed value (all bits set)
    seed = 0xFFFF  # All bits set seed
    print(f"Seed value: {hex(seed)}")
    # Apply reset and load seed value
    dut.reset.value = 1  # Assert reset
    await RisingEdge(dut.clock)
    
    dut.reset.value = 0  # De-assert reset
    dut.lfsr_seed.value = seed  # Load the all-bits-set seed into the LFSR
    
    await RisingEdge(dut.clock)
    dut.reset.value = 1  # De-assert reset after seed is loaded

    await RisingEdge(dut.clock)
    
    # Start running the LFSR for 65536 clock cycles and check the sequence
    await run_lfsr_sequence_check(dut, cycles=65536, check_maximal_length=True)


@cocotb.test()
async def test_lfsr_alternating_bits_seed(dut):
    """Test LFSR with alternating bits (0xAAAA) seed value"""

    # Start the clock
    clock = Clock(dut.clock, 10, units="ns")  # 100 MHz clock
    cocotb.start_soon(clock.start())

    # Seed value (alternating bits)
    seed = 0xAAAA  # Alternating bits seed
    print(f"Seed value: {hex(seed)}")
    # Apply reset and load seed value
    dut.reset.value = 1  # Assert reset
    await RisingEdge(dut.clock)
    
    dut.reset.value = 0  # De-assert reset
    dut.lfsr_seed.value = seed  # Load the alternating-bits seed into the LFSR
    
    await RisingEdge(dut.clock)
    dut.reset.value = 1  # De-assert reset after seed is loaded

    await RisingEdge(dut.clock)
    
    # Start running the LFSR for 65536 clock cycles and check the sequence
    await run_lfsr_sequence_check(dut, cycles=65536, check_maximal_length=True)


async def run_lfsr_sequence_check(dut, cycles=65536, check_maximal_length=False):
    """Helper function to run the LFSR sequence check for a given number of clock cycles"""
    first_value = None
    second_value = None
    lfsr_out_computed = None
    last_value = None

    for i in range(cycles):
        await RisingEdge(dut.clock)

        # Print the LFSR output at the first and last cycles
        if i == 0 or i == cycles - 1:
            print(f"LFSR output at cycle {i}: {dut.lfsr_out.value}")
        
        # Capture the first value
        if i == 0:
            first_value = dut.lfsr_out.value.to_unsigned()
            
            # Convert the 16-bit output into an integer and compute the next value
            lfsr_out_value = dut.lfsr_out.value.to_unsigned()

            # Calculate the next value based on the LFSR polynomial x^16 + x^5 + x^4 + x^3 + 1
            feedback = (lfsr_out_value >> 5 & 1) ^ (lfsr_out_value >> 4 & 1) ^ (lfsr_out_value >> 3 & 1) ^ (lfsr_out_value & 1)
            lfsr_out_computed = (feedback << 15) | (lfsr_out_value >> 1)

            print(f"Computed next value (cycle 1): {hex(lfsr_out_computed)}")
        
        # Capture the second value (DUT's output at cycle 1)
        if i == 1:
            second_value = dut.lfsr_out.value.to_unsigned()
            print(f"LFSR output at cycle 1 (DUT): {hex(second_value)}")
        
        # Capture the last value (DUT's output at the last cycle)
        if i == cycles - 1:
            last_value = dut.lfsr_out.value.to_unsigned()

    # Optional: Validate if the first and last values are the same (maximal length sequence)
    if check_maximal_length:
        assert first_value == last_value, f"LFSR does not support maximal length sequence, first value {hex(first_value)} does not match last value {hex(last_value)}"
    
    # Validate if the computed next sequence matches the DUT's next output
    assert second_value == lfsr_out_computed, f"Computed LFSR next value {hex(lfsr_out_computed)} does not match DUT output {hex(second_value)}"
