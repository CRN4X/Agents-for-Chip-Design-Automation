import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

def expected_lfsr_next(value):
    """Compute the next LFSR state using the given feedback polynomial."""
    feedback_bit = ((value >> 7) & 1) ^ ((value >> 5) & 1) ^ ((value >> 4) & 1) ^ ((value >> 3) & 1)  # Match Verilog taps
    return ((value << 1) & 0xFF) | feedback_bit  # Shift left and insert feedback bit

@cocotb.test()
async def lfsr_8bit_test(dut):
    """Test the 8-bit LFSR sequence generation"""
    
    # Start the clock with a 10ns period (100MHz)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset the LFSR with a predefined seed
    seed_value = 0b10101010  # Example seed
    dut.seed.value = seed_value
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # Ensure LFSR initializes correctly
    assert dut.lfsr_out.value == seed_value, f"Error: LFSR did not initialize correctly, got {dut.lfsr_out.value}, expected {seed_value}"
    cocotb.log.info(f"Test Case 1 Passed: LFSR initialized with seed {bin(seed_value)}")

    # Check LFSR sequence for a few cycles
    current_value = seed_value
    for i in range(10):  # Check the first 10 LFSR outputs
        current_value = expected_lfsr_next(current_value)
        
        # Allow time for output to stabilize
        await Timer(1, units="ns")

        # Check output correctness

        assert dut.lfsr_out.value == current_value, f"Mismatch at cycle {i+1}: Expected {bin(current_value)}, Got {bin(int(dut.lfsr_out.value))}"
        cocotb.log.info(f"Cycle {i+1}: LFSR Output = {bin(int(dut.lfsr_out.value))} (Expected: {bin(current_value)})")
        await RisingEdge(dut.clk)

    cocotb.log.info("LFSR test completed successfully.")
