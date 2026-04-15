import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import harness_library as hrs_lb
import random
import math
import cmath

@cocotb.test()
async def test_low_pass_filter(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    # Debug mode
    debug = 0
    
    # Retrieve parameters from the DUT
    NS_PROC = int(dut.NS_PROC.value)
    NS_PROC_OVERLAP = NS_PROC - 1
    NS  = int(dut.NS.value)
    NS_DATA_IN = NS + NS_PROC_OVERLAP
    NBW_PILOT_POS = int(dut.NBW_PILOT_POS.value)
    NBW_DATA_IN = int(dut.NBW_DATA_IN.value)
    NBI_DATA_IN = int(dut.NBI_DATA_IN.value)
    NBW_TH_PROC  = int(dut.NBW_TH_PROC.value)
    NBW_ENERGY  = int(dut.NBW_ENERGY.value)

    cocotb.log.warning(f"NS_PROC: {NS_PROC}, NS_PROC_OVERLAP: {NS_PROC_OVERLAP}, NS_DATA_IN: {NS_DATA_IN}, NBW_PILOT_POS: {NBW_PILOT_POS}, NBW_DATA_IN: {NBW_DATA_IN}, NBI_DATA_IN: {NBI_DATA_IN}, NBW_TH_PROC: {NBW_TH_PROC}, NBW_ENERGY: {NBW_ENERGY}")

    #model = hrs_lb.FawSymbolProcessor(ns_data_in=NS_DATA_IN, nbw_adder_tree_out=NBW_ADDER_TREE_OUT, nbw_energy=NBW_ENERGY)
    model = hrs_lb.detect_sequence(ns=NS, nbw_pilot_pos=NBW_PILOT_POS, nbw_data_symb=NBW_DATA_IN, nbw_th_proc=NBW_TH_PROC, nbw_energy=NBW_ENERGY, ns_proc=NS_PROC, ns_proc_overlap=NS_PROC_OVERLAP)
    # Initialize DUT
    await hrs_lb.dut_init(dut)

    # Apply reset and enable
    await hrs_lb.reset_dut(dut.rst_async_n)

    await RisingEdge(dut.clk)

    # Calculate min and max values for data and coefficients
    data_min = int(-2**NBW_DATA_IN / 2)
    data_max = int((2**NBW_DATA_IN / 2) - 1)

    # Number of random test iterations
    num_random_iterations = 15

    # Follow registers does not have reset on DUT, 
    # to prevent X error, 0 is assign to them
    dut.uu_cross_correlation.uu_adder_2d_layers.energy_i.value = 0
    dut.uu_cross_correlation.uu_adder_2d_layers.energy_q.value = 0
    for i in range(NS_PROC):
        dut.proc_buffer_i_dff[i].value = 0
        dut.proc_buffer_q_dff[i].value = 0

    ###########################################################################
    ## Check if all modules exists
    ###########################################################################    
    hrs_lb.check_instances(dut)

    i_static_threshold = random.randint(0,2**NBW_TH_PROC - 1)
    dut.i_static_threshold.value = i_static_threshold

    for _ in range(num_random_iterations):
        
        ###########################################################################
        ## Generate INPUTS
        ###########################################################################

        i_enable  = random.randint(0,1)
        i_valid   = random.randint(0,1)
        i_proc_pol = random.randint(0,1) 
        i_proc_pos = random.randint(0,2**NBW_PILOT_POS - 1)
        dut.i_enable.value = i_enable
        dut.i_valid.value = i_valid
        dut.i_proc_pol.value = i_proc_pol
        dut.i_proc_pos.value = i_proc_pos

        # Gera lista de valores aleatórios
        i_data_i_list = [random.randint(data_min, data_max) for _ in range(NS_DATA_IN)]
        i_data_q_list = [random.randint(data_min, data_max) for _ in range(NS_DATA_IN)]

        i_data_i_value = 0
        i_data_q_value = 0
        for idx in range(NS_DATA_IN):
            i_data_i_value |= (i_data_i_list[idx] & ((1 << NBW_DATA_IN) - 1)) << (NBW_DATA_IN * idx)
            i_data_q_value |= (i_data_q_list[idx] & ((1 << NBW_DATA_IN) - 1)) << (NBW_DATA_IN * idx)

        dut.i_data_i.value = i_data_i_value
        dut.i_data_q.value = i_data_q_value

        model.insert_data_and_process(i_valid, i_enable, i_proc_pol, i_proc_pos, i_static_threshold, i_data_i_list, i_data_q_list)

        if debug:
            cocotb.log.info(f"[INPUTS] i_data_i: {i_data_i_list}")
            cocotb.log.info(f"[INPUTS] i_data_q: {i_data_q_list}")
            cocotb.log.info(f"[INPUTS] i_valid : {i_valid}")
            cocotb.log.info(f"[INPUTS] i_enable : {i_enable}")
            cocotb.log.info(f"[INPUTS] i_proc_pol: {i_proc_pol}")
            cocotb.log.info(f"[INPUTS] i_proc_pos: {i_proc_pos}")
            cocotb.log.info(f"[INPUTS] i_static_threshold: {i_static_threshold}")
            cocotb.log.info(f"[DEBUG] start sample: {i_data_i_list[i_proc_pos]}")

        await RisingEdge(dut.clk)
        
        if debug:
            cocotb.log.info(f"[DUT] buffer i: {dut.proc_buffer_i_dff.value[0].to_signed()}")
            cocotb.log.info(f"[MOD] buffer i: {model.proc_buffer_i_dff_delayed[0]}")
            cocotb.log.info(f"[DUT] energy: {dut.proc_calc_energy.value.to_signed()}")
            cocotb.log.info(f"[MOD] energy: {model.proc_processor.o_energy_delayed}")
        
        # Checking internal signals
        assert dut.proc_buffer_i_dff.value[0].to_signed() == model.proc_buffer_i_dff_delayed[0]
        assert dut.proc_pol_dff.value.to_unsigned() == model.proc_pol_dff_delayed
        assert dut.conj_proc_seq.value[0].to_unsigned() == model.conj_proc_0
        assert dut.conj_proc_seq.value[1].to_unsigned() == model.conj_proc_1
        assert dut.proc_calc_energy.value.to_signed() == model.proc_processor.o_energy_delayed

        if debug:
            cocotb.log.info(f"dut: {dut.o_proc_detected.value.to_unsigned()} , model: {model.proc_detected_dff}")
            cocotb.log.info(f"[DETECTED] dut: {dut.proc_enable_dff.value[2]} , model: {model.proc_enable_dff[3]}")

        # Checking DUT output
        assert dut.o_proc_detected.value.to_unsigned() == model.proc_detected_dff
        
    cocotb.log.info(f"All tests passed finished.")
