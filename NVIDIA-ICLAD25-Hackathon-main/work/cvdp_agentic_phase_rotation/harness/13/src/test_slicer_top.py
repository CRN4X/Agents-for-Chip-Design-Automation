import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import harness_library as hrs_lb
import random

def slicer(i_data, i_threshold_high, i_sample_pos, NBW_IN=7, NBW_TH=7, NBW_REF=7, NBW_OUT=7, NS_TH=2):
    """
    Implements the slicing logic in Python equivalent to the SystemVerilog design.
    """
    ZERO = 0  # Equivalent to {NBW_IN{1'b0}}
    
    # Extract threshold values
    th_high = i_threshold_high
    
    # Apply slicing logic
    if i_data >= th_high:
        o_data = i_sample_pos + i_threshold_high
    elif ZERO <= i_data < th_high:
        o_data = i_sample_pos
    elif -th_high <= i_data < ZERO:
        o_data = -i_sample_pos
    else:
        o_data = -i_sample_pos - i_threshold_high
    
    return o_data

@cocotb.test()
async def test_low_pass_filter(dut):
    """Test the Slicer Top module with edge cases and random data."""

    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    # Debug mode
    debug = 0

    # Retrieve parameters from the DUT
    NBW_IN  = int(dut.NBW_IN.value)
    NBW_REF = int(dut.NBW_REF.value)
    NBW_TH  = int(dut.NBW_TH.value)

    # Initialize DUT
    await hrs_lb.dut_init(dut)

    # Apply reset and enable
    await hrs_lb.reset_dut(dut.rst_async_n)

    await RisingEdge(dut.clk)

    # Calculate min and max values for data and coefficients
    data_min = int(-2**NBW_IN / 2)
    data_max = int((2**NBW_IN / 2) - 1)

    data_ref_max = int((2**(NBW_REF-1) / 2) - 1)
    data_th_max = int((2**(NBW_TH-1) / 2) - 1)

    calc_cost = [0, 0, 0]
    energy = 0
    energy_delayed = 0
    # Number of random test iterations
    num_random_iterations = 10
    for _ in range(num_random_iterations):
        # Randomly generate input data
        i_calc_cost    = random.randint(0, 1)
        i_data_i       = random.randint(data_min, data_max)
        i_data_q       = random.randint(data_min, data_max)
        i_threshold_1  = random.randint(0, data_th_max)
        i_threshold    = i_threshold_1

        i_sample_pos = random.randint(0, data_ref_max)

        # Apply input data
        dut.i_calc_cost.value    = i_calc_cost
        dut.i_data_i.value       = i_data_i
        dut.i_data_q.value       = i_data_q
        dut.i_threshold.value    = i_threshold
        dut.i_sample_pos.value   = i_sample_pos

        # Check if inner interface is updated
        assert hasattr(dut, "uu_slicer_i.i_data"), "uu_slicer_i has no signal named 'i_data'"
        assert hasattr(dut, "uu_slicer_i.i_threshold"), "uu_slicer_i has no signal named 'i_threshold'"
        assert hasattr(dut, "uu_slicer_i.i_sample_pos"), "uu_slicer_i has no signal named 'i_sample_pos'"

        assert hasattr(dut, "uu_slicer_q.i_data"), "uu_slicer_q has no signal named 'i_data'"
        assert hasattr(dut, "uu_slicer_q.i_threshold"), "uu_slicer_q has no signal named 'i_threshold'"
        assert hasattr(dut, "uu_slicer_q.i_sample_pos"), "uu_slicer_q has no signal named 'i_sample_pos'"

        # Check if bit width of i_threshold is updated
        dut_bit_width_i_static_threshold = len(dut.i_threshold.value)
        assert dut_bit_width_i_static_threshold == NBW_TH, f"Bit-width of dut.i_threshold differs from {NBW_TH}, got:{dut_bit_width_i_static_threshold}"

        # Check if previous inner interface does not exist
        assert not hasattr(dut, "uu_slicer_i.i_sample_1_pos"), "uu_slicer_i has no signal named 'i_sample_1_pos'"
        assert not hasattr(dut, "uu_slicer_i.i_sample_0_pos"), "uu_slicer_i has no signal named 'i_sample_0_pos'"
        assert not hasattr(dut, "uu_slicer_i.i_sample_1_neg"), "uu_slicer_i has no signal named 'i_sample_1_neg'"
        assert not hasattr(dut, "uu_slicer_i.i_sample_0_neg"), "uu_slicer_i has no signal named 'i_sample_0_neg'"

        assert not hasattr(dut, "uu_slicer_q.i_sample_1_pos"), "uu_slicer_q has no signal named 'i_sample_1_pos'"
        assert not hasattr(dut, "uu_slicer_q.i_sample_0_pos"), "uu_slicer_q has no signal named 'i_sample_0_pos'"
        assert not hasattr(dut, "uu_slicer_q.i_sample_1_neg"), "uu_slicer_q has no signal named 'i_sample_1_neg'"
        assert not hasattr(dut, "uu_slicer_q.i_sample_0_neg"), "uu_slicer_q has no signal named 'i_sample_0_neg'"

        await RisingEdge(dut.clk)


        # Calculate expected output
        o_slice_i = slicer(i_data_i, i_threshold_1, i_sample_pos)
        o_slice_q = slicer(i_data_q, i_threshold_1, i_sample_pos)

        o_dut_slice_i = dut.slicer_i.value.to_signed()
        o_dut_slice_q = dut.slicer_q.value.to_signed()

        calc_cost[2] = calc_cost[1]
        calc_cost[1] = calc_cost[0]
        calc_cost[0] = i_calc_cost
        o_dut_calc_cost = dut.o_cost_rdy.value

        energy_delayed = energy
        if calc_cost[1]:
            energy = o_slice_i * o_slice_i + o_slice_q * o_slice_q

        o_dut_energy = dut.o_energy.value.to_signed()

        if debug:
            cocotb.log.info(f"[INPUTS] i_calc_cost = {i_calc_cost}, i_data_i = {i_data_i}, i_data_q = {i_data_q}, i_threshold_1 = {i_threshold_1}, i_sample_pos = {i_sample_pos}")
            cocotb.log.info(f"[EXPECTED OUTPUT] o_calc_cost = {calc_cost[2]}")
            cocotb.log.info(f"[DUT      OUTPUT] o_calc_cost = {o_dut_calc_cost}")
            cocotb.log.info(f"[EXPECTED OUTPUT] o_energy = {energy_delayed}")
            cocotb.log.info(f"[DUT      OUTPUT] o_energy = {o_dut_energy}")
            cocotb.log.info(f"[EXPECTED OUTPUT] o_data = {o_slice_i}, {o_slice_q}")
            cocotb.log.info(f"[DUT      OUTPUT] o_data = {o_dut_slice_i}, {o_dut_slice_q} \n")
        
        # Check output
        assert o_dut_slice_i == o_slice_i, f"Output mismatch: Expected {o_slice_i}, but got {o_dut_slice_i}"
        assert o_dut_slice_q == o_slice_q, f"Output mismatch: Expected {o_slice_q}, but got {o_dut_slice_q}"
        assert o_dut_calc_cost == calc_cost[2], f"Output mismatch: Expected {i_calc_cost}, but got {o_dut_calc_cost}"
        assert o_dut_energy == energy_delayed, f"Output mismatch: Expected {energy_delayed}, but got {o_dut_energy}"
    cocotb.log.info(f"All tests passed successfully.")
