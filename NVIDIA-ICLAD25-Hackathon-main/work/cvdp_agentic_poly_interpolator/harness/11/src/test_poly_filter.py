import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer
import harness_library as hrs_lb
import random
import time
from cocotb.triggers import with_timeout
import cocotb.simulator
import os


cocotb.simulator.dump_enabled = True

@cocotb.test()
async def test_reg_input_valid(dut):
    """
    Test to verify the property p_reg_input_buffer
    """
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await hrs_lb.dut_init(dut)
    
    dut.arst_n.value = 0
    await Timer(50, units="ns")
    dut.arst_n.value = 1
    await RisingEdge(dut.clk)
    
    #Drive valid_in high for one cycle.
    await RisingEdge(dut.clk)
    dut.valid_in.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    if int(dut.poly_dut.valid_stage0.value) != 1:
        raise AssertionError("Test failed: valid_stage0 not asserted on the cycle following valid_in high.")
    else:
        dut._log.info("Test passed: valid_stage0 asserted as expected after valid_in high.")

@cocotb.test()
async def test_coeff_fetch_addr0(dut):
    """
    Test the computed coefficient address for tap 0
    """
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await hrs_lb.dut_init(dut)

    # Reset DUT.
    dut.arst_n.value = 0
    await Timer(50, units="ns")
    dut.arst_n.value = 1
    await RisingEdge(dut.clk)

    await RisingEdge(dut.clk)
    dut.valid_in.value = 1
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    for _ in range(10):
        await RisingEdge(dut.clk)
        if int(dut.poly_dut.valid_stage0.value) == 1:
            break
    else:
        raise AssertionError("Test 2 failed: valid_stage0 never asserted.")
    
    # Read phase_reg and computed address for tap 0.
    phase_reg = int(dut.poly_dut.phase_reg.value)
    TAPS = int(dut.TAPS.value)
    expected_addr0 = phase_reg * TAPS + 0

    computed_addr0 = int(dut.poly_dut.coeff_fetch[0].addr.value)

    if computed_addr0 != expected_addr0:
        raise AssertionError(f"Test 2 failed: Tap 0 address = {computed_addr0}, expected {expected_addr0}.")
    dut._log.info("Test 2 passed: Tap 0 coefficient address is correct.")

@cocotb.test()
async def test_multiply_consistency0(dut):
    """
    Test that once valid_stage1 is asserted, the multiplication for tap 0 is correct.
    """
    # Start a clock with a period of 10 ns.
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await hrs_lb.dut_init(dut)

    dut.arst_n.value = 0
    await Timer(50, units="ns")
    dut.arst_n.value = 1
    await RisingEdge(dut.clk)

    tap_count   = int(dut.poly_dut.TAPS.value)
    phase_count = int(dut.poly_dut.N.value)
    total_coeffs = tap_count * phase_count
    coeff_list = [2 for _ in range(total_coeffs)]
    await hrs_lb.populate_coeff_ram(dut, coeff_list)

    # Drive the sample_buffer with known values.
    for i in range(tap_count):
        dut.poly_dut.sample_buffer[i].value = (i + 1) * 10
    dut.poly_dut.valid_in.value = 1
    await RisingEdge(dut.clk)
    dut.poly_dut.valid_in.value = 0

    # Wait until valid_stage1 is asserted.
    for _ in range(10):
        await RisingEdge(dut.clk)
        if int(dut.poly_dut.valid_stage1.value) == 1:
            break
    else:
        raise AssertionError("Test failed: valid_stage1 not asserted after driving sample_buffer and valid_in.")

    # Now compare the computed product for tap 0.
    sample0 = int(dut.poly_dut.sample_reg[0].value)
    coeff0  = int(dut.poly_dut.coeff[0].value)
    expected_product0 = sample0 * coeff0
    computed_product0 = int(dut.poly_dut.products[0].value)
    
    if computed_product0 != expected_product0:
        raise AssertionError(f"Test failed: products[0]={computed_product0}, expected {expected_product0}.")
    else:
        dut._log.info("Test passed: Multiplication result for tap 0 is correct.")

@cocotb.test()
async def test_sum_latency(dut):
    """
    Test that when valid_stage1 is asserted, the adder tree produces a valid_adder exactly one cycle later.
    """
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await hrs_lb.dut_init(dut)

    # Reset DUT.
    dut.arst_n.value = 0
    await Timer(50, units="ns")
    dut.arst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Drive valid_in to trigger the pipeline.
    dut.valid_in.value = 1
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0

    # Wait until valid_stage1 is high.
    for _ in range(10):
        await RisingEdge(dut.clk)
        if int(dut.poly_dut.valid_stage1.value) == 1:
            break
    else:
        raise AssertionError("Test failed: valid_stage1 not asserted.")
    
    # Capture the cycle when valid_stage1 is true.
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    if int(dut.poly_dut.valid_adder.value) != 1:
        raise AssertionError("Test failed: valid_adder was not asserted one cycle after valid_stage1.")
    dut._log.info("Test passed: valid_adder asserted one cycle after valid_stage1.")

@cocotb.test()
async def test_adder_tree_output(dut):
    """
    Test Property: Adder Tree Output Consistency
    """
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await hrs_lb.dut_init(dut)

    # Reset DUT.
    dut.arst_n.value = 0
    await Timer(50, units="ns")
    dut.arst_n.value = 1
    await RisingEdge(dut.clk)

    # Populate coefficient RAM.
    tap_count   = int(dut.poly_dut.TAPS.value)
    phase_count = int(dut.poly_dut.N.value)
    total_coeffs = tap_count * phase_count
    coeff_list = [1 for _ in range(total_coeffs)]
    await hrs_lb.populate_coeff_ram(dut, coeff_list)

    # Drive the sample_buffer with known values.
    for i in range(tap_count):
        dut.poly_dut.sample_buffer[i].value = (i + 1) * 10
    dut.poly_dut.valid_in.value = 1
    await RisingEdge(dut.clk)
    dut.poly_dut.valid_in.value = 0

    # Wait until the multiplication stage (valid_stage1) is asserted.
    for _ in range(10):
        await RisingEdge(dut.clk)
        if int(dut.poly_dut.valid_stage1.value) == 1:
            break
    else:
        raise AssertionError("Test failed: valid_stage1 not asserted after driving sample_buffer and valid_in.")
    
    # Wait 2 more cycle for the adder tree to produce its output.
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    if int(dut.poly_dut.valid_adder.value) != 1:
        raise AssertionError("Test failed: valid_adder not asserted one cycle after valid_stage1.")
    await RisingEdge(dut.clk)
    if int(dut.poly_dut.filter_out.value) != int(dut.poly_dut.sum_result.value):
        raise AssertionError("Test failed: filter_out does not equal sum_result after valid_adder assertion.")
    
    dut._log.info("Test passed: Adder tree output consistency verified (valid_adder asserted and filter_out equals sum_result).")

@cocotb.test()
async def test_output_reset(dut):
    """
    Test that after asserting reset, the filter_out signal is '0' and valid is 0.
    """
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await hrs_lb.dut_init(dut)

    # Apply reset.
    dut.arst_n.value = 0
    await Timer(50, units="ns")
    # Check immediately after reset is asserted.
    await RisingEdge(dut.clk)
    if int(dut.filter_out.value) != 0 or int(dut.valid.value) != 0:
        raise AssertionError("Test failed: filter_out or valid not cleared during reset.")
    dut._log.info("Test passed: filter_out and valid are cleared upon reset.")

@cocotb.test()
async def test_sum_stability(dut):
    """
    Test that when valid_adder is asserted, the sum_result signal remains stable 
    """
    # Start clock with a 10 ns period.
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Initialize DUT.
    await hrs_lb.dut_init(dut)
    
    dut.arst_n.value = 0
    await Timer(50, units="ns")
    dut.arst_n.value = 1
    await RisingEdge(dut.clk)
    
    tap_count   = int(dut.poly_dut.TAPS.value)
    phase_count = int(dut.poly_dut.N.value)
    total_coeffs = tap_count * phase_count
    coeff_list = [1 for _ in range(total_coeffs)]
    await hrs_lb.populate_coeff_ram(dut, coeff_list)
    
    # Drive the sample_buffer with known values.
    for i in range(tap_count):
        dut.poly_dut.sample_buffer[i].value = (i + 1) * 10
    
    dut.poly_dut.valid_in.value = 1
    await RisingEdge(dut.clk)
    dut.poly_dut.valid_in.value = 0

    for _ in range(10):
        await RisingEdge(dut.clk)
        if int(dut.poly_dut.valid_adder.value) == 1:
            break
    else:
        raise AssertionError("Test failed: valid_adder not asserted after driving sample_buffer and valid_in.")
    
    current_sum = int(dut.poly_dut.sum_result.value)
    await RisingEdge(dut.clk)
    next_sum = int(dut.poly_dut.sum_result.value)
    
    if current_sum != next_sum:
        raise AssertionError(f"Test failed: sum_result changed from {current_sum} to {next_sum} when valid_adder is asserted.")
    dut._log.info("Test passed: sum_result remains stable when valid_adder is asserted.")