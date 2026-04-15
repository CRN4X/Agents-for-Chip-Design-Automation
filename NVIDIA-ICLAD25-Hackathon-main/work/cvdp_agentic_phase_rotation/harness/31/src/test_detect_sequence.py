import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import harness_library as hrs_lb
import random
import math
import cmath

@cocotb.test()
async def test_detect_sequence(dut):
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
    NBW_ENERGY  = int(dut.NBW_ENERGY.value)

    if debug:
        cocotb.log.warning(f"NS_PROC: {NS_PROC}, NS_PROC_OVERLAP: {NS_PROC_OVERLAP}, NS_DATA_IN: {NS_DATA_IN}, NBW_PILOT_POS: {NBW_PILOT_POS}, NBW_DATA_IN: {NBW_DATA_IN}, NBI_DATA_IN: {NBI_DATA_IN}, NBW_ENERGY: {NBW_ENERGY}")

    model = hrs_lb.detect_sequence(ns=NS, nbw_pilot_pos=NBW_PILOT_POS, nbw_data_symb=NBW_DATA_IN, nbw_energy=NBW_ENERGY, ns_proc=NS_PROC, ns_proc_overlap=NS_PROC_OVERLAP)

    await hrs_lb.dut_init(dut)
    await hrs_lb.reset_dut(dut.rst_async_n)
    await RisingEdge(dut.clk)

    data_min = int(-2**NBW_DATA_IN / 2)
    data_max = int((2**NBW_DATA_IN / 2) - 1)
    
    num_random_iterations = 100
    min_active_duration = 60
    active_start = random.randint(0, num_random_iterations - min_active_duration)

    dut.uu_cross_correlation.uu_adder_2d_layers.energy_i.value = 0
    dut.uu_cross_correlation.uu_adder_2d_layers.energy_q.value = 0
    for i in range(NS_PROC):
        dut.proc_buffer_i_dff[i].value = 0
        dut.proc_buffer_q_dff[i].value = 0

    visited_states = set()

    hrs_lb.check_instances(dut)
    hrs_lb.check_inteface_changes(dut)
    
    for cycle in range(num_random_iterations):
        if active_start <= cycle < active_start + min_active_duration:
            i_enable = 1
            i_valid = 1
        else:
            i_enable = random.randint(0, 1)
            i_valid = random.randint(0, 1)
    
        dut.i_enable.value = i_enable
        dut.i_valid.value = i_valid

        i_proc_pol  = random.randint(0,1)
        i_proc_pos  = random.randint(0,2**NBW_PILOT_POS - 1)
        dut.i_enable.value    = i_enable
        dut.i_valid.value     = i_valid
        dut.i_proc_pol.value  = i_proc_pol
        dut.i_proc_pos.value  = i_proc_pos

        i_data_i_list = [random.randint(data_min, data_max) for _ in range(NS_DATA_IN)]
        i_data_q_list = [random.randint(data_min, data_max) for _ in range(NS_DATA_IN)]

        i_data_i_value = 0
        i_data_q_value = 0
        for idx in range(NS_DATA_IN):
            i_data_i_value |= (i_data_i_list[idx] & ((1 << NBW_DATA_IN) - 1)) << (NBW_DATA_IN * idx)
            i_data_q_value |= (i_data_q_list[idx] & ((1 << NBW_DATA_IN) - 1)) << (NBW_DATA_IN * idx)

        dut.i_data_i.value = i_data_i_value
        dut.i_data_q.value = i_data_q_value

        model.insert_data_and_process(i_valid, i_enable, i_proc_pol, i_proc_pos, i_data_i_list, i_data_q_list)

        if debug:
            cocotb.log.info(f"[INPUTS] i_data_i: {i_data_i_list}")
            cocotb.log.info(f"[INPUTS] i_data_q: {i_data_q_list}")
            cocotb.log.info(f"[INPUTS] i_valid : {i_valid}")
            cocotb.log.info(f"[INPUTS] i_enable : {i_enable}")
            cocotb.log.info(f"[INPUTS] i_proc_pol: {i_proc_pol}")
            cocotb.log.info(f"[INPUTS] i_proc_pos: {i_proc_pos}")
            cocotb.log.info(f"[DEBUG] start sample: {i_data_i_list[i_proc_pos]}")

        await RisingEdge(dut.clk)

        if debug:
            cocotb.log.info(f"[DUT] buffer i: {dut.proc_buffer_i_dff.value[0].to_signed()}")
            cocotb.log.info(f"[MOD] buffer i: {model.proc_buffer_i_dff_delayed[0]}")
            cocotb.log.info(f"[DUT] energy: {dut.proc_calc_energy.value.to_signed()}")
            cocotb.log.info(f"[MOD] energy: {model.proc_processor.o_energy_delayed}")

        assert dut.proc_buffer_i_dff.value[0].to_signed() == model.proc_buffer_i_dff_delayed[0]
        assert dut.proc_pol_dff.value.to_unsigned() == model.proc_pol_dff_delayed
        assert dut.conj_proc_seq.value[0].to_unsigned() == model.conj_proc_0
        assert dut.conj_proc_seq.value[1].to_unsigned() == model.conj_proc_1
        assert dut.proc_calc_energy.value.to_signed() == model.proc_processor.o_energy_delayed

        if debug:
            cocotb.log.info(f"dut: {dut.o_proc_detected.value.to_unsigned()} , model: {model.proc_detected_dff}")
            cocotb.log.info(f"[DETECTED] dut: {dut.proc_enable_dff.value[2]} , model: {model.proc_enable_dff[3]}")

        assert dut.o_proc_detected.value.to_unsigned() == model.proc_detected_dff

        if debug:
            cocotb.log.info(f"[INPUTS] i_valid : {i_valid}")
            cocotb.log.info(f"[DUT] energy: {dut.proc_calc_energy.value.to_signed()}")
            cocotb.log.info(f"[MOD] energy: {model.proc_processor.o_energy_delayed}")        
            cocotb.log.info(f"[MOD] state = {model.fsm.curr_state}, ts_count = {model.fsm.ts_count_dff}, undetected ts = {model.fsm.ts_undetected_count_dff}")
            cocotb.log.info(f"[DUT] state = {dut.curr_state.value.to_unsigned()}, ts_count = {dut.ts_count_dff.value.to_unsigned()}, undetected ts = {dut.ts_undetected_count_dff.value.to_unsigned()}")

        assert dut.curr_state.value.to_unsigned() == model.fsm.curr_state, f"[FSM MISMATCH] State: DUT={dut.curr_state.value.to_unsigned()} vs MODEL={model.fsm.curr_state}"
        assert dut.ts_count_dff.value.to_unsigned() == model.fsm.ts_count_dff, f"[FSM MISMATCH] ts_count: DUT={dut.ts_count_dff.value.to_unsigned()} vs MODEL={model.fsm.ts_count_dff}"
        assert dut.ts_undetected_count_dff.value.to_unsigned() == model.fsm.ts_undetected_count_dff, f"[FSM MISMATCH] undetected ts: DUT={dut.ts_undetected_count_dff.value.to_unsigned()} vs MODEL={model.fsm.ts_undetected_count_dff}"

        if debug:
            cocotb.log.info(f"Aware mode: DUT={dut.w_aware_mode.value.to_unsigned()} vs MODEL={model.proc_processor.aware_mode}")

        assert dut.w_aware_mode.value.to_unsigned() == model.proc_processor.aware_mode, f"[FSM MISMATCH] Aware mode: DUT={dut.w_aware_mode.value.to_unsigned()} vs MODEL={model.proc_processor.aware_mode}"

        assert dut.o_locked.value.to_unsigned() == model.fsm.o_locked_delayed, f"[FSM MISMATCH] Locked: DUT={dut.o_locked.value.to_unsigned()} vs MODEL={model.fsm.o_locked_delayed}"

        if debug:
         cocotb.log.info(f"Locked: DUT={dut.o_locked.value.to_unsigned()} vs MODEL={model.fsm.o_locked_delayed}")
        visited_states.add(int(dut.curr_state.value.to_unsigned()))

        if debug:
          cocotb.log.info(f"Visited states: {visited_states}")

    assert 0 in visited_states, "FSM did not enter state 0"
    assert 1 in visited_states, "FSM did not enter state 1"

    cocotb.log.info(f"All tests passed finished.")