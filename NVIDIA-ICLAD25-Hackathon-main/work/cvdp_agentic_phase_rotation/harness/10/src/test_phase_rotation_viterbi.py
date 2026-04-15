import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import harness_library as hrs_lb
import random
import math
import cmath

@cocotb.test()
async def test_low_pass_filter(dut):
    """Test the Phase Rotation Viterbi module with edge cases and random data."""

    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    # Debug mode
    debug = 0
    
    ERROR_LIMIT = 5

    # Retrieve parameters from the DUT
    NBW_IN  = int(dut.NBW_IN.value)
    NBW_OUT  = int(dut.NBW_OUT.value)

    # Initialize DUT
    await hrs_lb.dut_init(dut)

    # Apply reset and enable
    await hrs_lb.reset_dut(dut.rst_async_n)

    await RisingEdge(dut.clk)

    # Calculate min and max values for data and coefficients
    data_min = int(-2**NBW_IN / 2)
    data_max = int((2**NBW_IN / 2) - 1)

    # Number of random test iterations
    num_random_iterations = 100

    data_i4 = 0
    data_q4 = 0 
    data_i4_delayed = 0
    data_q4_delayed = 0 

    i_data_i       = 0
    i_data_q       = 0

    i_data_i_delayed = 0
    i_data_q_delayed = 0 

    data_out_i = 0
    data_out_q = 0
    data_out_i_delayed = 0
    data_out_q_delayed = 0

    for _ in range(num_random_iterations):

        i_data_i_delayed = i_data_i
        i_data_q_delayed = i_data_q
        # Randomly generate input data
        i_data_i       = random.randint(data_min, data_max)
        i_data_q       = random.randint(data_min, data_max)

        # Apply input data
        dut.i_data_i.value       = i_data_i
        dut.i_data_q.value       = i_data_q

        await RisingEdge(dut.clk)

        ## Power4 DUT
        dut_data_i4_ff = dut.data_i4_ff.value.to_signed()
        dut_data_q4_ff = dut.data_q4_ff.value.to_signed()

        # EXP
        data_i4_delayed = data_i4
        data_q4_delayed = data_q4

        data_i4 = i_data_i**4
        data_q4 = i_data_q**4

        # Print
        if debug:
            cocotb.log.info(f"[INPUTS] i_data_i = {i_data_i}, i_data_q = {i_data_q}")
            cocotb.log.info(f"[DUT] i^4 = {dut_data_i4_ff}, q^4 = {dut_data_q4_ff}")
            cocotb.log.info(f"[EXP] i^4 = {data_i4_delayed}, q^4 = {data_q4_delayed}")
        assert dut_data_i4_ff == data_i4_delayed, f"Mismatch, expected: {data_i4_delayed}, got: {dut_data_i4_ff}"
        assert dut_data_q4_ff == data_q4_delayed, f"Mismatch, expected: {data_q4_delayed}, got: {dut_data_q4_ff}"

        # SAT Power4
        dut_data_i4_ff_sat = dut.data_i4_ff_sat.value.to_signed()
        dut_data_q4_ff_sat = dut.data_q4_ff_sat.value.to_signed()

        # EXP
        exp_i4_sat = 0
        exp_q4_sat = 0
        if data_i4_delayed > 31:
            exp_i4_sat = 31
        elif data_i4_delayed < -32:
            exp_i4_sat = -32
        else:
            exp_i4_sat = data_i4_delayed

        if data_q4_delayed > 31:
            exp_q4_sat = 31
        elif data_q4_delayed < -32:
            exp_q4_sat = -32
        else:
            exp_q4_sat = data_q4_delayed
        # Print
        if debug:
            cocotb.log.info(f"[DUT] SAT i^4 = {dut_data_i4_ff_sat}, q^4 = {dut_data_q4_ff_sat}")
            cocotb.log.info(f"[EXP] SAT i^4 = {exp_i4_sat}, q^4 = {exp_q4_sat}")
        assert dut_data_i4_ff_sat == exp_i4_sat, f"Mismatch, expected: {exp_i4_sat}, got: {dut_data_i4_ff_sat}"
        assert dut_data_q4_ff_sat == exp_q4_sat, f"Mismatch, expected: {exp_q4_sat}, got: {dut_data_q4_ff_sat}"

        dut_phase = dut.phase.value.to_signed()
        phase = (math.atan2(exp_q4_sat,exp_i4_sat))*256/math.pi

        if debug:
            cocotb.log.info(f"[DUT PHASE] phase = {dut_phase}")
            cocotb.log.info(f"[EXP PHASE] phase = {phase}")
        diff = abs(dut_phase - phase)
        assert diff <= 1, f"Mismatch, expected: {phase}, got: {dut_phase}"

        # Phase/4
        phase_div4 = int((phase) / 4)
        dut_phase_div4 = dut.phase_div4.value.to_signed()
        if debug:
            cocotb.log.info(f"[DUT PHASE/4] phase sat = {dut_phase_div4}")
            cocotb.log.info(f"[EXP PHASE/4] phase sat = {phase_div4}")
        
        phase_div4_sat = 0
        if phase_div4 > 63:
            phase_div4_sat = 63
        elif phase_div4 < -64:
            phase_div4_sat = -64
        else:
            phase_div4_sat = phase_div4        
        
        dut_phase_div4_sat = dut.phase_div4_sat.value.to_signed()
        if debug:
            cocotb.log.info(f"[DUT PHASE SAT] phase sat = {dut_phase_div4_sat}")
            cocotb.log.info(f"[EXP PHASE SAT] phase sat = {phase_div4_sat}")

        data_out_i_delayed = data_out_i
        data_out_q_delayed = data_out_q

        phase_rad = (phase_div4_sat/64)*math.pi

        data_complex = i_data_i_delayed + 1j*i_data_q_delayed
        rotation = (cmath.exp(1j * phase_rad))*data_complex

        data_out_i = rotation.real*256
        data_out_q = rotation.imag*256

        o_dut_data_i = dut.o_data_i.value.to_signed()
        o_dut_data_q = dut.o_data_q.value.to_signed()

        exp_out_phase = math.atan2(data_out_q_delayed, data_out_i_delayed)
        dut_out_phase = math.atan2(o_dut_data_q, o_dut_data_q)
        final_diff = abs(exp_out_phase - dut_out_phase)

        if debug:
            cocotb.log.info(f"[DIFF] diff phase = {final_diff}")
            cocotb.log.info(f"[EXPECTED OUTPUT] o_data = {data_out_i_delayed}, {data_out_q_delayed}")
            cocotb.log.info(f"[DUT      OUTPUT] o_data = {o_dut_data_i}, {o_dut_data_q} \n")
        
        # Check phase
        assert final_diff <= ERROR_LIMIT, f"Diff phase is greater than {ERROR_LIMIT}, got = {final_diff}"


    cocotb.log.info(f"All tests passed successfully.")
