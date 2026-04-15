import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge

@cocotb.test()
async def test_sigma_delta_audio(dut):
    """Cocotb testbench replicating paula_audio_sigmadelta_tb logic"""

    # Create a 10ns period clock on dut.clk_sig (matching always #5 toggling => 10ns total period)
    cocotb.start_soon(Clock(dut.clk_sig, 5, units="ns").start())

    # We'll track errors in a local variable
    errors = 0

    # Printing "----- Test Start -----"
    cocotb.log.info("----- Test Start -----")

    # Initialize inputs
    dut.clk_sig.value = 0
    dut.clk_en_sig.value = 0
    dut.load_data_sum.value = 0
    dut.read_data_sum.value = 0
    
    # Apply reset-like condition for 20ns
    await Timer(20, units="ns")
    dut.clk_en_sig.value = 1
    
    # Test Case 1: Zero Input Test
    cocotb.log.info("Running Test Case 1: Zero Input Test")
    dut.load_data_sum.value = 0
    dut.read_data_sum.value = 0
    await Timer(20, units="ns")
    assert dut.left_sig.value == 0 , f"Test case 1 Failed"
    assert dut.right_sig.value == 0 , f"Test case 1 Failed"
    if (dut.left_sig.value != 0) or (dut.right_sig.value != 0):
        cocotb.log.error("Test Case 1 Failed")
        errors += 1
    else:
        cocotb.log.info("Test Case 1 Passed")

    # Test Case 2: Maximum Negative Values
    cocotb.log.info("Running Test Case 2: Maximum Negative Values")
    dut.load_data_sum.value = 0x80   # 15'h80
    dut.read_data_sum.value = 0x80   # 15'h80
    await Timer(20, units="ns")
    assert dut.left_sig.value != 1 , f"Test case 2 Failed"
    assert dut.right_sig.value != 1 , f"Test case 2 Failed"
    if (dut.left_sig.value == 1) or (dut.right_sig.value == 1):
        cocotb.log.error("Test Case 2 Failed")
        errors += 1
    else:
        cocotb.log.info("Test Case 2 Passed")

    # Test Case 3: Small Positive Values
    cocotb.log.info("Running Test Case 3: Small Positive Values")
    dut.load_data_sum.value = 10
    dut.read_data_sum.value = 20
    await Timer(20, units="ns")
    assert dut.left_sig.value != 1 , f"Test case 3 Failed"
    assert dut.right_sig.value != 1 , f"Test case 3 Failed"
    if (dut.left_sig.value == 1) or (dut.right_sig.value == 1):
        cocotb.log.error("Test Case 3 Failed")
        errors += 1
    else:
        cocotb.log.info("Test Case 3 Passed")

    # Test Case 4: Small Negative Values
    cocotb.log.info("Running Test Case 4: Small Negative Values")
    # Because these are signed in Verilog, we can pass negative decimal directly:
    dut.load_data_sum.value = -10 & 0x7FFF  # 15-bit sign extension in SV => here we keep 15 bits
    dut.read_data_sum.value = -20 & 0x7FFF
    await Timer(20, units="ns")
    assert dut.left_sig.value != 1 , f"Test case 4 Failed"
    assert dut.right_sig.value != 1 , f"Test case 4 Failed"
    if (dut.left_sig.value == 1) or (dut.right_sig.value == 1):
        cocotb.log.error("Test Case 4 Failed")
        errors += 1
    else:
        cocotb.log.info("Test Case 4 Passed")

    # Test Case 5: Large Alternating Values
    cocotb.log.info("Running Test Case 5: Large Alternating Values")
    dut.load_data_sum.value = 0x40
    dut.read_data_sum.value = 0xC0
    await Timer(10, units="ns")
    assert dut.left_sig.value != 1 , f"Test case 5 Failed"
    if dut.left_sig.value == 1:
        cocotb.log.error("Test Case 5 Failed")
        errors += 1
    else:
        cocotb.log.info("Test Case 5 Passed")

   

    # Final Test Result
    if errors == 0:
        cocotb.log.info("All tests passed!")
    else:
        cocotb.log.error(f"Some tests failed. Errors: {errors}")

    cocotb.log.info("----- Test Completed -----")
