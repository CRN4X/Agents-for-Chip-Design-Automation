import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer
import harness_library as hrs_lb
import random

@cocotb.test()
async def test_control_logic_0(dut):
   cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
   debug = 0

   double_o_start_calc = 17 * [0]

   # Retrieve the parameters from the DUT    
   NBW_WAIT = int(dut.NBW_WAIT.value)
   model = hrs_lb.ControlFSM(nbw_wait=NBW_WAIT)

   runs = 256

   # Initialize DUT
   await hrs_lb.dut_init(dut) 
   # Reset DUT
   await hrs_lb.reset_dut(dut.rst_async_n)    

   await RisingEdge(dut.clk)

   # Run model once as DUT
   model.tick(0, 0, 0, 0, 0, 0)

   dut_state_ff      = dut.state_ff.value.to_unsigned()
   dut_cnt_ff        = dut.cnt_ff.value.to_unsigned()
   dut_o_subsampling = dut.o_subsampling.value.to_unsigned()
   dut_o_valid       = dut.o_valid.value.to_unsigned()
   dut_cnt_rstctrl   = dut.cnt_rstctrl.value.to_unsigned()

   if debug:
      cocotb.log.info(f"[MOD] state: {model.state}, cnt_ff: {model.cnt_ff}, o_subsampling: {model.o_subsampling}, o_valid: {model.o_valid}, cnt_rstctrl: {model.cnt_rstctrl}, ")
      cocotb.log.info(f"[DUT] state: {dut_state_ff}, cnt_ff: {dut_cnt_ff}, o_subsampling: {dut_o_subsampling}, o_valid: {dut_o_valid}, cnt_rstctrl: {dut_cnt_rstctrl} \n")

   for i in range(runs):
      i_enable      = random.randint(0, 1)
      i_subsampling = random.randint(0, 1)
      i_valid       = random.randint(0, 1)
      i_calc_valid  = random.randint(0, 1)
      i_calc_fail   = random.randint(0, 1)
      i_wait        = random.randint(0, 1)
 
      model.tick(i_enable, i_subsampling, i_valid, i_calc_valid, i_calc_fail, i_wait)
 
      dut.i_enable.value      = i_enable
      dut.i_subsampling.value = i_subsampling
      dut.i_valid.value       = i_valid
      dut.i_calc_valid.value  = i_calc_valid
      dut.i_calc_fail.value   = i_calc_fail
      dut.i_wait.value        = i_wait
 
      await RisingEdge(dut.clk)
      dut_state_ff      = dut.state_ff.value.to_unsigned()
      dut_cnt_ff        = dut.cnt_ff.value.to_unsigned()
      dut_cnt_rstctrl   = dut.cnt_rstctrl.value.to_unsigned()
      dut_o_subsampling = dut.o_subsampling.value.to_unsigned()
      dut_o_valid      = dut.o_valid.value.to_unsigned()
      dut_o_start_calc  = dut.o_start_calc.value.to_unsigned()
 
      if debug:
         cocotb.log.info(f"[DEBUG] inputs: i_enable:{i_enable}, i_subsampling:{i_subsampling}, i_valid:{i_valid}, i_calc_valid:{i_calc_valid}, i_calc_fail:{i_calc_fail}, i_wait:{i_wait}")
         cocotb.log.info(f"[MOD] state: {model.state}, cnt_ff: {model.cnt_ff}, o_subsampling: {model.o_subsampling}, o_valid: {model.o_valid}, cnt_rstctrl: {model.cnt_rstctrl}, o_start_calc: {model.o_start_calc} ")
         cocotb.log.info(f"[DUT] state: {dut_state_ff}, cnt_ff: {dut_cnt_ff}, o_subsampling: {dut_o_subsampling}, o_valid: {dut_o_valid}, cnt_rstctrl: {dut_cnt_rstctrl}, o_start_calc: {dut_o_start_calc} \n")
   
      assert dut_o_subsampling == model.o_subsampling, f"[Mismatch] expected: {model.o_subsampling}, but got: {dut_o_subsampling}"
      assert dut_o_valid == model.o_valid, f"[Mismatch] expected: {model.o_valid}, but got: {dut_o_valid}"
      assert dut_o_start_calc == model.o_start_calc, f"[Mismatch] expected: {model.o_start_calc}, but got: {dut_o_start_calc}"

      double_o_start_calc[1:] = double_o_start_calc[:-1]
      double_o_start_calc[0]  = dut_o_start_calc
      # Check if o_start_calc hold for at most 16 cycles
      assert sum(double_o_start_calc) <= 16, f"[Mismatch] expected: {sum(double_o_start_calc)} <= 16"

@cocotb.test()
async def test_fsm_states(dut):
   cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
   # Retrieve the parameters from the DUT    
   NBW_WAIT = int(dut.NBW_WAIT.value)
   model = hrs_lb.ControlFSM(nbw_wait=NBW_WAIT)

   runs = 256

   fsm_states_seen = set()

   # Initialize DUT
   await hrs_lb.dut_init(dut) 
   # Reset DUT
   await hrs_lb.reset_dut(dut.rst_async_n)    

   await RisingEdge(dut.clk)

   # Run model once as DUT
   model.tick(0, 0, 0, 0, 0, 0)

   for i in range(runs):
      i_enable      = 1 # Should be 1 to test all states in FSM within a short time
      i_subsampling = random.randint(0, 1)
      i_valid       = 1 # Should be 1 to test all states in FSM within a short time
      i_calc_valid  = 1 # Should be 1 to test all states in FSM within a short time
      i_calc_fail   = 0 # Should be 0 to test all states in FSM within a short time
      i_wait        = random.randint(0, 1)
 
      model.tick(i_enable, i_subsampling, i_valid, i_calc_valid, i_calc_fail, i_wait)
 
      dut.i_enable.value      = i_enable
      dut.i_subsampling.value = i_subsampling
      dut.i_valid.value       = i_valid
      dut.i_calc_valid.value  = i_calc_valid
      dut.i_calc_fail.value   = i_calc_fail
      dut.i_wait.value        = i_wait
 
      await RisingEdge(dut.clk)
      dut_state_ff = dut.state_ff.value.to_unsigned()
      dut_cnt_ff   = dut.cnt_ff.value.to_unsigned()
      dut_o_subsampling = dut.o_subsampling.value.to_unsigned()
      dut_o_valid = dut.o_valid.value.to_unsigned()
      dut_cnt_rstctrl = dut.cnt_rstctrl.value.to_unsigned()
 
      # For futher STATE Checker 
      fsm_states_seen.add(dut_state_ff)

   assert 0 in fsm_states_seen, f"FSM did not enter in state 0"
   assert 1 in fsm_states_seen, f"FSM did not enter in state 1"
   assert 2 in fsm_states_seen, f"FSM did not enter in state 2"
   assert 3 in fsm_states_seen, f"FSM did not enter in state 3" 
   assert 4 in fsm_states_seen, f"FSM did not enter in state 4"