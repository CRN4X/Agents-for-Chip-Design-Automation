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

WAIT_INPUT     = 0
PROCESS_PHASES = 1
OUTPUT_STATE   = 2

@cocotb.test()
async def test_wait_input_in_ready(dut):

    # Start a 5ns period clock.
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Apply asynchronous reset.
    dut.arst_n.value = 0
    await Timer(50, units="ns")
    dut.arst_n.value = 1
    await RisingEdge(dut.clk)
    dut.in_valid.value = 1
    
    # Wait one clock cycle
    await RisingEdge(dut.clk)
    
    # Check that in_ready is asserted when in_valid is high in WAIT_INPUT.
    if int(dut.in_ready.value) != 1:
        raise AssertionError("Test failed: in_ready is not asserted in WAIT_INPUT state when in_valid is high.")
    else:
        dut._log.info("Test passed: in_ready is correctly asserted when in_valid is high in WAIT_INPUT state.")

    dut.in_valid.value = 0

@cocotb.test()
async def test_p_wait_to_process(dut):
    """
    Test Property 2:
    """
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    dut.arst_n.value = 0
    await Timer(50, units="ns")
    dut.arst_n.value = 1
    await RisingEdge(dut.clk)
    
    # With reset, expect WAIT_INPUT.
    dut.in_valid.value = 1
    await RisingEdge(dut.clk)
    dut.in_valid.value = 0

    # Check next_state.
    next_state = int(dut.poly_dut.next_state.value)
    if next_state != PROCESS_PHASES:
        raise AssertionError(f"Test 2 failed: next_state is {next_state} instead of PROCESS_PHASES ({PROCESS_PHASES}).")
    dut._log.info("Test 2 passed: FSM transitions from WAIT_INPUT to PROCESS_PHASES when in_valid is high.")


@cocotb.test()
async def test_p_process_to_output(dut):
    """
    Test Property 3:
    """
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    dut.arst_n.value = 0
    await Timer(50, units="ns")
    dut.arst_n.value = 1
    await RisingEdge(dut.clk)

    dut.in_valid.value = 1
    await RisingEdge(dut.clk)
    dut.in_valid.value = 0

    for _ in range(20):
        await RisingEdge(dut.clk)
        if int(dut.poly_dut.state.value) == PROCESS_PHASES and \
           int(dut.poly_dut.phase_counter.value) == (int(dut.poly_dut.N.value) - 1) and \
           int(dut.poly_dut.valid_filter.value) == 1:
            break
    else:
        raise AssertionError("Test 3 failed: Did not reach PROCESS_PHASES with phase_counter == N-1 and valid_filter high.")

    next_state = int(dut.poly_dut.next_state.value)
    if next_state != OUTPUT_STATE:
        raise AssertionError(f"Test 3 failed: next_state is {next_state} instead of OUTPUT_STATE ({OUTPUT_STATE}).")
    dut._log.info("Test 3 passed: FSM transitions from PROCESS_PHASES to OUTPUT_STATE as expected.")


@cocotb.test()
async def test_p_output_to_wait(dut):
    """
    Test Property 4:
    """
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    dut.arst_n.value = 0
    await Timer(50, units="ns")
    dut.arst_n.value = 1
    await RisingEdge(dut.clk)

    dut.in_valid.value = 1
    await RisingEdge(dut.clk)
    dut.in_valid.value = 0

    for _ in range(50):
        await RisingEdge(dut.clk)
        if int(dut.poly_dut.state.value) == OUTPUT_STATE and int(dut.poly_dut.output_index.value) == int(dut.poly_dut.N.value):
            break
    else:
        raise AssertionError("Test 4 failed: Did not observe output_index==N in OUTPUT_STATE.")

    next_state = int(dut.poly_dut.next_state.value)
    if next_state != WAIT_INPUT:
        raise AssertionError(f"Test 4 failed: next_state is {next_state} instead of WAIT_INPUT (0).")
    dut._log.info("Test 4 passed: FSM transitions from OUTPUT_STATE to WAIT_INPUT when output_index equals N.")


@cocotb.test()
async def test_p_out_valid_in_output(dut):
    """
    Test Property 5:
    """
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    dut.arst_n.value = 0
    await Timer(50, units="ns")
    dut.arst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Drive a sample to get to OUTPUT_STATE.
    dut.in_valid.value = 1
    await RisingEdge(dut.clk)
    dut.in_valid.value = 0

    # Wait until FSM is in OUTPUT_STATE.
    while int(dut.poly_dut.state.value) != OUTPUT_STATE:
        await RisingEdge(dut.clk)
    await RisingEdge(dut.clk) 
    if int(dut.poly_dut.output_index.value) < int(dut.poly_dut.N.value):
        if int(dut.poly_dut.out_valid.value) != 1:
            raise AssertionError("Test 5 failed: out_valid is not asserted in OUTPUT_STATE when output_index < N.")
        dut._log.info("Test 5 passed: out_valid asserted in OUTPUT_STATE when output_index < N.")
    else:
        dut._log.info("Test 5 skipped: output_index >= N; cannot test property.")

@cocotb.test()
async def test_p_store_filter_result(dut):
    """
    Test Property 6:
    """
    # Start clock.
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Reset DUT.
    dut.arst_n.value = 0
    await Timer(50, units="ns")
    dut.arst_n.value = 1
    await RisingEdge(dut.clk)
    
    tap_count = int(dut.poly_dut.u_poly_filter.TAPS.value)
    phase_count = int(dut.poly_dut.u_poly_filter.N.value)
    coeff_list = [i + 1 for i in range(tap_count * phase_count)]
    await hrs_lb.populate_coeff_ram(dut, coeff_list)
    
    # Drive an input sample with a known value.
    dut.in_sample.value = 10
    dut.in_valid.value = 1
    # Wait until the design samples the input.
    await RisingEdge(dut.clk)
    dut.in_valid.value = 0

    for _ in range(20):
        await RisingEdge(dut.clk)
        if int(dut.poly_dut.state.value) == 1 and int(dut.poly_dut.valid_filter.value) == 1:
            break
    else:
        raise AssertionError("Test 6 failed: Did not observe PROCESS_PHASES with valid_filter high.")

    await RisingEdge(dut.clk)
    current_phase = int(dut.poly_dut.phase_counter.value)
    rb_value = int(dut.poly_dut.result_buffer[current_phase-1].value)
    f_result = int(dut.poly_dut.filter_result.value)

    if rb_value != f_result:
        raise AssertionError(f"Test 6 failed: result_buffer[{current_phase}] = {rb_value} does not equal filter_result = {f_result}.")
    dut._log.info("Test 6 passed: Filter result correctly stored in result_buffer during PROCESS_PHASES.")


@cocotb.test()
async def test_p_filter_val_on_shift_val(dut):
    """
    Test Property 7
    """
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    dut.arst_n.value = 0
    await Timer(50, units="ns")
    dut.arst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.in_valid.value = 1
    await RisingEdge(dut.clk)
    dut.in_valid.value = 0

    while int(dut.poly_dut.state.value) != PROCESS_PHASES:
         await RisingEdge(dut.clk)

    if int(dut.poly_dut.shift_data_val.value) == 1 and int(dut.poly_dut.valid_filter.value) == 0:
        await RisingEdge(dut.clk)
        if int(dut.poly_dut.filter_val_in.value) != 1:
            raise AssertionError("Test 7 failed: filter_val_in not asserted when shift_data_val is high and valid_filter is low in PROCESS_PHASES.")
        dut._log.info("Test 7 passed: filter_val_in correctly asserted under (!valid_filter && shift_data_val) in PROCESS_PHASES.")
    else:
        dut._log.info("Test 7 skipped: Condition (!valid_filter && shift_data_val) not met; cannot test property.")
