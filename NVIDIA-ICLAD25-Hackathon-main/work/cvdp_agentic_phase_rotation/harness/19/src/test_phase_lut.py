import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer
import harness_library as hrs_lb
import random
import math
import cmath

@cocotb.test()
async def test_convolution_0(dut):
    
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    debug = 0
    # Retrieve the parameters from the DUT    
    NBW_IN = int(dut.NBW_IN.value)

    max_data = (2 ** NBW_IN)/2 - 1
    min_data = -((2 ** NBW_IN)/2 -1)

    runs = 100
    
    exp_phase = 0
    exp_phase_delayed = 0

    # Initialize DUT
    await hrs_lb.dut_init(dut) 
    await hrs_lb.reset_dut(dut.rst_async_n)

    # Check for interface Changes
    assert hasattr(dut,'clk'), f"Clock signal not found in DUT"
    assert hasattr(dut,'rst_async_n'), f"Reset signal not found in DUT"
    assert hasattr(dut,'NBI_IN'), f"Parameter NBI_IN not found in DUT"
    assert hasattr(dut,'NBI_PHASE'), f"Parameter NBI_PHASE not found in DUT"

    await RisingEdge(dut.clk)

    for i in range(runs):
        i_data_i = random.randint(min_data, max_data)
        i_data_q = random.randint(min_data, max_data)

        dut.i_data_i.value = i_data_i
        dut.i_data_q.value = i_data_q

        exp_phase_delayed = exp_phase
        exp_phase = (math.atan2(i_data_q, i_data_i)*180/math.pi)
        exp_phase = hrs_lb.normalize_angle(exp_phase)*256/180

        await RisingEdge(dut.clk)
        #await Timer(1, units="ns")

        dut_phase = dut.o_phase.value.to_signed()

        if debug == 1:
          cocotb.log.info(f"[INPUTS] i_data_i = {i_data_i}, i_data_q = {i_data_q}")
          cocotb.log.info(f"[DUT] o_phase = {dut_phase}")
          cocotb.log.info(f"[EXP] o_phase = {exp_phase_delayed}")

        abs_diff = abs(dut_phase - exp_phase_delayed)
        if debug == 1:
           cocotb.log.info(f"[DIFF] o_phase = {abs_diff}")

        assert abs_diff < 1, f"Phase mismatch. Expected {exp_phase_delayed} but got {dut_phase}"

    #for item in dir(dut.gen_lut_phase_rot[0].uu_phase_rotation.i_data_re):
    #  print(f"- {item}")      
  